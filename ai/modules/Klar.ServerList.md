# Klar.ServerList

A list whose rows live on a server: a table, a filter bar and saved views that edit one query, and the glue that every such list needs, in one place.

Import: `import Klar.ServerList as ServerList` | Group: Rules and filters

Types: `Msg`, `State`, `Target`, `Ticket`, `Page`, `Step`, `Request`

## Signatures

```elm
type State id row  -- opaque: no constructors are exposed
type Msg row  -- opaque: no constructors are exposed
type alias Step id row =
    { state : State id row
    , cmd : Cmd (Msg row)
    , request : Maybe Request
    , save : Maybe (List SavedViews.SavedView)
    }
init : String -> List SavedViews.SavedView -> Step id row
update : Msg row -> State id row -> Step id row
gotPage : Request -> Result Remote.Problem (Page row) -> Msg row

-- View
viewTable : (Msg row -> msg) -> List (Table.Attribute id row msg) -> State id row -> Html msg
viewFilterBar : (Msg row -> msg) -> List (FilterBar.Attribute r msg) -> State id row -> Html msg
viewSavedViews : (Msg row -> msg) -> List (SavedViews.Attribute msg) -> State id row -> Html msg

-- The request
type alias Request = { query : Table.Query, rule : Rule.Rule, ticket : Ticket }
type alias Page row = { rows : List row, total : Int }
type Ticket  -- opaque: no constructors are exposed

-- Other changes
refresh : State id row -> Step id row
clearFilters : State id row -> Step id row
setRule : Rule.Rule -> State id row -> Step id row
setViews : List SavedViews.SavedView -> State id row -> Step id row
applyView : String -> State id row -> Step id row
startSaveView : State id row -> Step id row

-- The list in the address
toQueryString : State id row -> String
fromQueryString : String -> State id row -> Step id row

-- Reading the state
rows : State id row -> Remote.Remote (List row)
total : State id row -> Int
rule : State id row -> Rule.Rule
query : State id row -> Table.Query
savedViews : State id row -> List SavedViews.SavedView
activeView : State id row -> Maybe SavedViews.SavedView

-- The table and the rows
table : State id row -> Table.State id
mapTable : (Table.State id -> Table.State id) -> State id row -> Step id row
mapRows : (row -> row) -> State id row -> State id row
focus : State id row -> Cmd (Msg row)

-- Selected rows
type Target id
    = Picked (List id)
    | Matching { query : Table.Query, rule : Rule.Rule, except : List id }
target : Ids.Ids id -> State id row -> Maybe (Target id)
```

## Documentation

A list whose rows live on a server: a table, a filter bar and saved views that
edit one query, and the glue that every such list needs, in one place.

Use when: a screen is a table of rows that the server searches, filters, sorts and pages, with a filter bar and saved views.
Do not use when: you have all the rows (use `Klar.Table` in client mode) or only one of the parts (use `Klar.Table` with `server`).
Quick path: `init`, `update`, `gotPage`, `viewTable`, `viewFilterBar`, `viewSavedViews`

The state owns the three components and what ties them together: the current
query, a ticket for every request, the page of rows and its total. It does what the
application would otherwise write by hand: compare the query and the rule before
and after every message, go back to page 1 when the rule changed, drop an "all
matching" selection that would now mean other rows, load a saved view into the
filter bar and the table, ask again, ask for the last page when rows were removed
and the page is past the end, and ignore an answer to a question that is no longer
asked. The text that the user types is already waited for by the table (its search
and its filter fields) and the filter bar changes only on "Add", so there is no
second timer here.

The application keeps the part that is its own: the request to the server, the
columns, the fields and where the saved views are stored. The library never knows how
the request is sent.

    module Main exposing (main)

    import Browser
    import Html exposing (Html)
    import Klar.FilterBar as FilterBar
    import Klar.Ids as Ids
    import Klar.Rule as Rule
    import Klar.SavedViews as SavedViews
    import Klar.ServerList as ServerList
    import Klar.Table as Table
    import Process
    import Task

    type alias Order =
        { id : String, customer : String, status : String }

    type alias Model =
        { orders : ServerList.State String Order }

    type Msg
        = OrdersMsg (ServerList.Msg Order)

    fields : List (Rule.Field Order)
    fields =
        [ Rule.textField "customer" "Customer" .customer
        , Rule.textField "status" "Status" .status
        ]

    columns : List (Table.Column Order Msg)
    columns =
        [ Table.text (Table.columnId "id") "Order" .id []
        , Table.text (Table.columnId "customer") "Customer" .customer []
        , Table.text (Table.columnId "status") "Status" .status []
        ]

    main : Program () Model Msg
    main =
        Browser.element
            { init = \_ -> follow (ServerList.init "orders" [ SavedViews.savedView "Open" (Rule.is "status" "open") ])
            , update = \(OrdersMsg m) model -> follow (ServerList.update m model.orders)
            , view = view
            , subscriptions = \_ -> Sub.none
            }

    -- the one place that turns what the list asks for into commands
    follow : ServerList.Step String Order -> ( Model, Cmd Msg )
    follow step =
        ( { orders = step.state }
        , Cmd.batch
            [ Cmd.map OrdersMsg step.cmd
            , case step.request of
                Just request ->
                    fetchOrders request

                Nothing ->
                    Cmd.none

            -- and step.save, when it is `Just views`: store them in your backend
            ]
        )

    -- the application's backend: here a pause and an answer, there an HTTP request
    fetchOrders : ServerList.Request -> Cmd Msg
    fetchOrders request =
        Process.sleep 300
            |> Task.perform
                (\_ ->
                    OrdersMsg
                        (ServerList.gotPage request
                            (Ok { rows = [ { id = "SO-1", customer = "Fjord Foods", status = "open" } ], total = 1 })
                        )
                )

    view : Model -> Html Msg
    view model =
        Html.div []
            [ ServerList.viewSavedViews OrdersMsg [] model.orders
            , ServerList.viewFilterBar OrdersMsg [ FilterBar.fields fields ] model.orders
            , ServerList.viewTable OrdersMsg
                [ Table.columns columns
                , Table.rowId Ids.string .id
                , Table.searchable
                ]
                model.orders
            ]

The request has the table's `Query` (search, sort, page, page size) and the filter bar's
`Rule`: send both, and answer with `gotPage request result`. With `elm/http` that is
`Http.expectJson (\result -> OrdersMsg (ServerList.gotPage request (Result.mapError toProblem result))) pageDecoder`;
the list notes the time of the answer itself. A failed answer keeps the rows that are on
the screen as old data, with a retry; with no rows yet the table shows the failure.

**One filter language.** In a server list the filters are the filter bar's: your backend
reads `request.rule` for them and `request.query` for the search, the sort and the page.
Give the columns no filter of their own (`Table.filterText`, `Table.filterSelect` ...):
`request.query.filters` would carry them in a second language, and a backend that
forgets them shows filter chips that filter nothing.

`update` returns a `Step`: the new state, a command to map into your own message, the
request to send (when the query changed), and the list of saved views to store (when
the user saved, renamed, deleted or changed the default). Nothing here is a function in a
`Msg` or in the state.

**After an edit.** When the user changed one row (in a drawer, say) and the server
accepted it, `mapRows` puts the change on the screen at once; `refresh` asks the server
again, for a change that can move the row to another page or out of the list.

**Selecting across pages.** A table in server mode only knows the rows on its page.
`Table.exportCsv` offers the selected rows while every one of them is on the page. A
selection that reaches over several pages, or "Select all N matching", is a `target`:
the ids picked, or the query, the rule and the exceptions, for the application to
fulfil in its backend (a bulk action, a CSV file of all the matching rows).

### `State`

```elm
type State id row  -- opaque: no constructors are exposed
```

The table, the filter bar and the saved views, the current page of rows with its
total, and the ticket of the latest request. The type parameters are the type of a row's
id (see `Table.rowId`) and of a row. Make it with `init`.

### `Msg`

```elm
type Msg row  -- opaque: no constructors are exposed
```

The messages of the three parts and of the answer. Wrap it in a constructor of your
own message type and give it to `update`; make the answer with `gotPage`.

### `Step`

```elm
type alias Step id row =
    { state : State id row
    , cmd : Cmd (Msg row)
    , request : Maybe Request
    , save : Maybe (List SavedViews.SavedView)
    }
```

What happened: the new `state`, a command (to map into your message with `Cmd.map`),
the `request` to send now (`Nothing` when nothing changed that the server must answer), and
the saved `views` to store (`Nothing` while the list is as it was).

An application has one place that turns a `Step` into a command. Send the request even
when the step came from `init`: it is the first page. A backend that keeps the list as
one setting stores `save` as it is; one that keeps each view by its key sends
`SavedViews.changes (ServerList.savedViews model.orders) views` (the views before, and
the ones to save).

### `init`

```elm
init : String -> List SavedViews.SavedView -> Step id row
```

A list with nothing loaded yet, called `id` (the ids of the three parts are made
from it: `"orders"`, `"orders-filters"`, `"orders-views"`), and the first request. The
saved views are the ones you have stored; the one marked as default is applied (its
rule goes into the filter bar and its query into the table).

To start somewhere else (the view the user had, the address of a link), give the state
of this step to `applyView`, `fromQueryString` or `setRule` and follow that step instead:
it carries the first request. A view named before the views came from the backend waits
for them: `setViews` applies it then, ahead of the default view.

### `update`

```elm
update : Msg row -> State id row -> Step id row
```

Applies a message of the table, the filter bar, the saved views or the answer.
A change of the query or the rule asks again (with page 1 when the rule changed); an
answer to an old request is dropped.

### `gotPage`

```elm
gotPage : Request -> Result Remote.Problem (Page row) -> Msg row
```

The message for the answer to a `Request`: the rows of the page and the total, or
the problem. The list notes when the answer came (for "Old data from 14:05" after a
later refresh fails), so there is no `Time.now` to chain. An answer to a request that is
not the latest is dropped by `update`.

## View

Put the three parts where you want them: the saved views and the filter bar above the
table. Each takes the attributes of its component (`Table.columns`, `FilterBar.fields`,
a `locale`...) and adds the ones that this module owns: the rows, the total, the retry,
the match count, the saved views' current rule and query.

### `viewTable`

```elm
viewTable : (Msg row -> msg) -> List (Table.Attribute id row msg) -> State id row -> Html msg
```

The table. It gets `Table.server`, the rows, the retry and refresh buttons, the
count of filters from the filter bar and the button that clears them; give it the rest
(`Table.columns`, `Table.rowId`, `Table.searchable` ...).

### `viewFilterBar`

```elm
viewFilterBar : (Msg row -> msg) -> List (FilterBar.Attribute r msg) -> State id row -> Html msg
```

The filter bar. It gets the match count, in the state of the rows (counting
while the first answer is on its way, the old count dimmed while a new one is,
a retry when it failed); give it `FilterBar.fields` and the rest.

### `viewSavedViews`

```elm
viewSavedViews : (Msg row -> msg) -> List (SavedViews.Attribute msg) -> State id row -> Html msg
```

The saved views button. It gets the current rule and query, which is what "Save
current view ..." saves and what a view is compared with.

## The request

### `Request`

```elm
type alias Request = { query : Table.Query, rule : Rule.Rule, ticket : Ticket }
```

What the server is asked: the table's query (the search, the sort, the page and the
page size, and the column filters if the columns have any) and the filter bar's rule.
Answer with `gotPage request`; the ticket inside it lets the list drop an answer that is
no longer wanted.

### `Page`

```elm
type alias Page row = { rows : List row, total : Int }
```

One page of the answer: the rows of the page and how many rows match in all.

### `Ticket`

```elm
type Ticket  -- opaque: no constructors are exposed
```

Tells a request from the ones before it. You never make one: it is in the
`Request` and goes back with `gotPage`.

## Other changes

Each returns a `Step` like `update`. Before the first answer has come, `setRule`,
`applyView`, `fromQueryString` and `mapTable` always ask (again): so the application can
make the list with `init`, change it at once (a stored view, the address, a page size)
and follow only the last step.

### `refresh`

```elm
refresh : State id row -> Step id row
```

Asks again with the same query, for a refresh button or after the application
changed rows on the server (a bulk action). The rows on the screen stay while the
answer comes.

### `clearFilters`

```elm
clearFilters : State id row -> Step id row
```

Takes away every filter: the chips of the filter bar, the column filters and the
search of the table. The table's own "Reset filters" button does it too; use this for a
command or a shortcut ("Clear filters").

### `setRule`

```elm
setRule : Rule.Rule -> State id row -> Step id row
```

Puts a rule into the filter bar and asks from page 1, for a link from elsewhere
("the orders of this customer" on a dashboard) or a command. A rule that the filter bar
shows already asks for nothing.

    ServerList.setRule (Rule.allOf [ Rule.is "customer" customer.id ]) model.orders

### `setViews`

```elm
setViews : List SavedViews.SavedView -> State id row -> Step id row
```

Replaces the saved views, for example when they came from the backend after the
list was made. When the views arrive for the first time, a view named before they came
(by `applyView`, or the `view` of an address given to `fromQueryString`) is applied; else
the default view is, if the user has not filtered or paged the list yet. A later list
(the echo of a store, another tab) only replaces the views, so the filters that are on
the screen stay.

### `applyView`

```elm
applyView : String -> State id row -> Step id row
```

Applies the view with this name as if the user had picked it: a link that names a
view (`#/orders?view=Open`) or the view the user had last time calls it. Before the views
came from the backend the name waits for them, and `setViews` applies it when they come
(ahead of the default view). A name that is not in the list changes nothing.

### `startSaveView`

```elm
startSaveView : State id row -> Step id row
```

Opens the saved views with the form for a new view open ("New saved view", from a
button or a shortcut). The form saves the current rule and query.

## The list in the address

A link to the list as the user sees it (`#/orders?view=Open&search=fjord&page=3`), and
Back and Forward that bring the list back: write the address after every step that asks,
and read it when the address changes.

    -- in `follow`, when the step has a request
    Nav.replaceUrl key ("#/orders?" ++ ServerList.toQueryString step.state)

    -- when the address changes (a link, Back): the part after the `?`
    UrlChanged url ->
        follow model (ServerList.fromQueryString (queryOf url) model.orders)

An address that says what the list already shows asks for nothing, so writing the address
does not ask the server twice.

### `toQueryString`

```elm
toQueryString : State id row -> String
```

The list as the query of an address, without the `?`: the active view (`view`),
the search, the sort (`sort=-total,customer`, a `-` for descending), the filter bar's
rule and the column filters (as JSON), the page (when it is not 1) and the page size.
Every text is percent-encoded, so any name or search is safe in a link.

    ServerList.toQueryString model.orders -- "view=Open&search=fjord&page=3&size=25"

### `fromQueryString`

```elm
fromQueryString : String -> State id row -> Step id row
```

Puts the list where an address says (the part after the `?`, as `toQueryString`
writes it) and asks when that is not what the list shows. A parameter that is missing
takes the value of an empty list (no search, no sort, no filters, page 1), except the page
size, which stays (a size above 500 counts as missing). An address with only `view=Name` applies that view; an address with
none of these parameters is "Reset": the default view, or no filters. A parameter that
cannot be read counts as missing.

    ServerList.fromQueryString "view=Open&page=2" model.orders

## Reading the state

### `rows`

```elm
rows : State id row -> Remote.Remote (List row)
```

The page of rows, as a `Remote`: loading, failed, the rows, or the rows with the
note that they are old or being refreshed. Give it to the parts of the page that
show the rows too.

### `total`

```elm
total : State id row -> Int
```

How many rows match the query in all, from the last answer; 0 before the first.

### `rule`

```elm
rule : State id row -> Rule.Rule
```

The rule of the filter bar as plain data.

### `query`

```elm
query : State id row -> Table.Query
```

The query of the table as plain data.

### `savedViews`

```elm
savedViews : State id row -> List SavedViews.SavedView
```

The saved views, in the order of the list.

### `activeView`

```elm
activeView : State id row -> Maybe SavedViews.SavedView
```

The view the user applied last, if it still exists. Keep its name with the views
to bring the user back to it next time (`applyView`).

## The table and the rows

### `table`

```elm
table : State id row -> Table.State id
```

The state of the table, to read what the module does not give (`Table.selection`,
`Table.density`).

### `mapTable`

```elm
mapTable : (Table.State id -> Table.State id) -> State id row -> Step id row
```

Changes the table with a function of `Table` and asks again when that changed the
query: the page size from a stored setting, the sort, the selection after a bulk
action, the density. A change that leaves the query alone (the density, the selection)
asks for nothing, also before the first answer: follow the step of `init` too.

    ServerList.mapTable (Table.setPageSize 50) model.orders

### `mapRows`

```elm
mapRows : (row -> row) -> State id row -> State id row
```

Changes the rows on the screen without asking the server: the row the user just
edited, as the server accepted it, with no round trip and no flicker. The total, the
page and the freshness of the rows stay.

    ServerList.mapRows
        (\order ->
            if order.id == saved.id then
                saved

            else
                order
        )
        model.orders

### `focus`

```elm
focus : State id row -> Cmd (Msg row)
```

Moves keyboard focus to the table. Use it when whatever had focus is gone: a bulk
action that removed the selected rows takes the bulk bar and its buttons with it.

    Cmd.map OrdersMsg (ServerList.focus model.orders)

## Selected rows

### `Target`

```elm
type Target id
    = Picked (List id)
    | Matching { query : Table.Query, rule : Rule.Rule, except : List id }
```

What the user selected, for a request the application fulfils: rows picked one by
one (they can be on several pages), or every row that matches the query and the rule
except the ones taken out. The table cannot list the second: your backend does it.

### `target`

```elm
target : Ids.Ids id -> State id row -> Maybe (Target id)
```

The selection as a `Target`, or `Nothing` when nothing is selected. Needs the
`Klar.Ids` of the row ids that the table was given with `rowId`.

    case ServerList.target Ids.string model.orders of
        Just (ServerList.Picked ids) ->
            packOrders ids

        Just (ServerList.Matching { query, rule, except }) ->
            packAllMatching query rule except

        Nothing ->
            ( model, Cmd.none )
