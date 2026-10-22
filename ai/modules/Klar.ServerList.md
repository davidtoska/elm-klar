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
gotPage : Request -> Result Remote.Problem (Page row) -> Time.Posix -> Msg row

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
setViews : List SavedViews.SavedView -> State id row -> Step id row
applyView : String -> State id row -> Step id row
startSaveView : State id row -> Step id row

-- Reading the state
rows : State id row -> Remote.Remote (List row)
total : State id row -> Int
rule : State id row -> Rule.Rule
query : State id row -> Table.Query
savedViews : State id row -> List SavedViews.SavedView
activeView : State id row -> Maybe SavedViews.SavedView

-- The table
table : State id row -> Table.State id
mapTable : (Table.State id -> Table.State id) -> State id row -> State id row
focus : State id row -> Cmd (Msg row)

-- Selected rows
type Target id
    = Picked (List id)
    | Matching { query : Table.Query, rule : Rule.Rule, except : List id }
target : Table.RowIds id -> State id row -> Maybe (Target id)
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
filter bar and the table, ask again, and ignore an answer to a question that is no
longer asked. The text that the user types is already waited for by the table (its
search and its filter fields) and the filter bar changes only on "Add", so there is
no second timer here.

The application keeps the part that is its own: the request to the server, the
columns, the fields and where the saved views are stored. The library never knows how
the request is sent.

    module Main exposing (main)

    import Browser
    import Html exposing (Html)
    import Klar.Remote as Remote
    import Klar.Rule as Rule
    import Klar.SavedViews as SavedViews
    import Klar.ServerList as ServerList
    import Klar.Table as Table
    import Process
    import Task
    import Time

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
            { init = \_ -> startOrders (ServerList.init "orders" [ SavedViews.savedView "Open" (Rule.is "status" "open") ])
            , update = \(OrdersMsg m) model -> startOrders (ServerList.update m model.orders)
            , view = view
            , subscriptions = \_ -> Sub.none
            }

    -- the one place that turns what the list asks for into a command
    startOrders : ServerList.Step String Order -> ( Model, Cmd Msg )
    startOrders step =
        ( { orders = step.state }
        , Cmd.batch
            [ Cmd.map OrdersMsg step.cmd
            , case step.request of
                Just request ->
                    fetchOrders request

                Nothing ->
                    Cmd.none
            ]
        )

    -- the application's backend: here a pause and an answer, there an HTTP request
    fetchOrders : ServerList.Request -> Cmd Msg
    fetchOrders request =
        Process.sleep 300
            |> Task.andThen (\_ -> Time.now)
            |> Task.perform
                (\at ->
                    OrdersMsg
                        (ServerList.gotPage request
                            (Ok { rows = [ { id = "SO-1", customer = "Fjord Foods", status = "open" } ], total = 1 })
                            at
                        )
                )

    view : Model -> Html Msg
    view model =
        Html.div []
            [ ServerList.viewSavedViews OrdersMsg [] model.orders
            , ServerList.viewFilterBar OrdersMsg [] model.orders
            , ServerList.viewTable OrdersMsg
                [ Table.columns columns
                , Table.rowId Table.stringIds .id
                , Table.searchable
                ]
                model.orders
            ]

The request has the table's `Query` (search, sort, column filters, page, page size) and the
filter bar's `Rule`: send both, and answer with `gotPage request result at`. A failed
answer keeps the rows that are on the screen as old data, with a retry; with no rows
yet the table shows the failure.

`update` returns a `Step`: the new state, a command to map into your own message, the
request to send (when the query changed), and the list of saved views to store (when
the user saved, renamed, deleted or changed the default). Nothing here is a function in a
`Msg` or in the state.

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
when the step came from `init`: it is the first page.

### `init`

```elm
init : String -> List SavedViews.SavedView -> Step id row
```

A list with nothing loaded yet, called `id` (the ids of the three parts are made
from it: `"orders"`, `"orders-filters"`, `"orders-views"`), and the first request. The
saved views are the ones you have stored; the one marked as default is applied (its
rule goes into the filter bar and its query into the table).

### `update`

```elm
update : Msg row -> State id row -> Step id row
```

Applies a message of the table, the filter bar, the saved views or the answer.
A change of the query or the rule asks again (with page 1 when the rule changed); an
answer to an old request is dropped.

### `gotPage`

```elm
gotPage : Request -> Result Remote.Problem (Page row) -> Time.Posix -> Msg row
```

The message for the answer to a `Request`: the rows of the page and the total, or
the problem. `at` is when the answer came (`Time.now` in the task that sends the
request). An answer to a request that is not the latest is dropped by `update`.

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

The filter bar. It gets the match count (while the answer is fresh) and the
"counting" mark (while it is on its way); give it `FilterBar.fields` and the rest.

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

What the server is asked: the table's query (search, sort, column filters, the
page and the page size) and the filter bar's rule. Answer with `gotPage request`; the
ticket inside it lets the list drop an answer that is no longer wanted.

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

Each returns a `Step` like `update`.

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

### `setViews`

```elm
setViews : List SavedViews.SavedView -> State id row -> Step id row
```

Replaces the saved views, for example when they came from the backend after the
list was made. When the user has applied no view, the one marked as default is applied.

### `applyView`

```elm
applyView : String -> State id row -> Step id row
```

Applies the view with this name as if the user had picked it: a link that names a
view (`#/orders?view=Open`) calls it. A name that is not in the list changes nothing.

### `startSaveView`

```elm
startSaveView : State id row -> Step id row
```

Opens the saved views with the form for a new view open ("New saved view", from a
button or a shortcut). The form saves the current rule and query.

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

The view the user applied last, if it still exists.

## The table

### `table`

```elm
table : State id row -> Table.State id
```

The state of the table, to read what the module does not give (`Table.selection`,
`Table.density`).

### `mapTable`

```elm
mapTable : (Table.State id -> Table.State id) -> State id row -> State id row
```

Changes the table with a function of `Table`: the page size, the density, the
selection after a bulk action, the focus. A change of the query this way is not
noticed; use it for what is not part of the query.

    ServerList.mapTable Table.clearSelection model.orders

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
target : Table.RowIds id -> State id row -> Maybe (Target id)
```

The selection as a `Target`, or `Nothing` when nothing is selected. Needs the
`RowIds` that the table was given with `rowId`.

    case ServerList.target orderIds model.orders of
        Just (ServerList.Picked ids) ->
            packOrders ids

        Just (ServerList.Matching { query, rule, except }) ->
            packAllMatching query rule except

        Nothing ->
            ( model, Cmd.none )
