module Klar.ServerList exposing
    ( State, Msg, Step, init, update, gotPage
    , viewTable, viewFilterBar, viewSavedViews
    , Request, Page, Ticket
    , refresh, clearFilters, setViews, applyView, startSaveView
    , rows, total, rule, query, savedViews, activeView
    , table, mapTable, focus
    , Target(..), target
    )

{-| A list whose rows live on a server: a table, a filter bar and saved views that
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
    import Klar.FilterBar as FilterBar
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
            , ServerList.viewFilterBar OrdersMsg [ FilterBar.fields fields ] model.orders
            , ServerList.viewTable OrdersMsg
                [ Table.columns columns
                , Table.rowId Ids.string .id
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

@docs State, Msg, Step, init, update, gotPage


# View

Put the three parts where you want them: the saved views and the filter bar above the
table. Each takes the attributes of its component (`Table.columns`, `FilterBar.fields`,
a `locale`...) and adds the ones that this module owns: the rows, the total, the retry,
the match count, the saved views' current rule and query.

@docs viewTable, viewFilterBar, viewSavedViews


# The request

@docs Request, Page, Ticket


# Other changes

Each returns a `Step` like `update`.

@docs refresh, clearFilters, setViews, applyView, startSaveView


# Reading the state

@docs rows, total, rule, query, savedViews, activeView


# The table

@docs table, mapTable, focus


# Selected rows

@docs Target, target

-}

import Html exposing (Html)
import Klar.FilterBar as FilterBar
import Klar.Ids as Ids exposing (Ids)
import Klar.Remote as Remote exposing (Remote(..))
import Klar.Rule as Rule exposing (Rule)
import Klar.SavedViews as SavedViews exposing (SavedView)
import Klar.Table as Table
import Time



-- STATE


{-| The table, the filter bar and the saved views, the current page of rows with its
total, and the ticket of the latest request. The type parameters are the type of a row's
id (see `Table.rowId`) and of a row. Make it with `init`.
-}
type State id row
    = State (Inner id row)


type alias Inner id row =
    { table : Table.State id
    , filterBar : FilterBar.State
    , views : SavedViews.State
    , rows : Remote (List row)
    , total : Int
    , ticket : Int
    }


{-| The messages of the three parts and of the answer. Wrap it in a constructor of your
own message type and give it to `update`; make the answer with `gotPage`.
-}
type Msg row
    = TableMsg Table.Msg
    | FilterBarMsg FilterBar.Msg
    | ViewsMsg SavedViews.Msg
    | GotPage Ticket Time.Posix (Result Remote.Problem (Page row))
    | Refresh
    | ClearFilters


{-| What happened: the new `state`, a command (to map into your message with `Cmd.map`),
the `request` to send now (`Nothing` when nothing changed that the server must answer), and
the saved `views` to store (`Nothing` while the list is as it was).

An application has one place that turns a `Step` into a command. Send the request even
when the step came from `init`: it is the first page.

-}
type alias Step id row =
    { state : State id row
    , cmd : Cmd (Msg row)
    , request : Maybe Request
    , save : Maybe (List SavedView)
    }


{-| What the server is asked: the table's query (search, sort, column filters, the
page and the page size) and the filter bar's rule. Answer with `gotPage request`; the
ticket inside it lets the list drop an answer that is no longer wanted.
-}
type alias Request =
    { query : Table.Query
    , rule : Rule
    , ticket : Ticket
    }


{-| One page of the answer: the rows of the page and how many rows match in all.
-}
type alias Page row =
    { rows : List row
    , total : Int
    }


{-| Tells a request from the ones before it. You never make one: it is in the
`Request` and goes back with `gotPage`.
-}
type Ticket
    = Ticket Int


{-| A list with nothing loaded yet, called `id` (the ids of the three parts are made
from it: `"orders"`, `"orders-filters"`, `"orders-views"`), and the first request. The
saved views are the ones you have stored; the one marked as default is applied (its
rule goes into the filter bar and its query into the table).
-}
init : String -> List SavedView -> Step id row
init id views =
    setViews views
        (State
            { table = Table.init id
            , filterBar = FilterBar.init (id ++ "-filters")
            , views = SavedViews.init (id ++ "-views")
            , rows = NotAsked
            , total = 0
            , ticket = 0
            }
        )



-- UPDATE


{-| Applies a message of the table, the filter bar, the saved views or the answer.
A change of the query or the rule asks again (with page 1 when the rule changed); an
answer to an old request is dropped.
-}
update : Msg row -> State id row -> Step id row
update msg (State before) =
    case msg of
        TableMsg m ->
            let
                ( next, cmd ) =
                    Table.update m before.table
            in
            settle before { before | table = next } (Cmd.map TableMsg cmd)

        FilterBarMsg m ->
            let
                ( next, cmd ) =
                    FilterBar.update m before.filterBar
            in
            settle before { before | filterBar = next } (Cmd.map FilterBarMsg cmd)

        ViewsMsg m ->
            let
                ( next, cmd ) =
                    SavedViews.update m before.views

                updated =
                    { before | views = next }
            in
            settle before
                (if SavedViews.revision next /= SavedViews.revision before.views then
                    loadActiveView updated

                 else
                    updated
                )
                (Cmd.map ViewsMsg cmd)

        GotPage ticket at result ->
            if ticket /= Ticket before.ticket then
                idle before

            else
                case result of
                    Ok page ->
                        idle { before | rows = Remote.refreshWith before.rows (Ok page.rows) at, total = page.total }

                    Err problem ->
                        idle { before | rows = Remote.refreshWith before.rows (Err problem) at }

        Refresh ->
            ask before Cmd.none

        ClearFilters ->
            clearFilters (State before)


{-| The message for the answer to a `Request`: the rows of the page and the total, or
the problem. `at` is when the answer came (`Time.now` in the task that sends the
request). An answer to a request that is not the latest is dropped by `update`.
-}
gotPage : Request -> Result Remote.Problem (Page row) -> Time.Posix -> Msg row
gotPage request result at =
    GotPage request.ticket at result


{-| Nothing to ask, nothing to store.
-}
idle : Inner id row -> Step id row
idle inner =
    { state = State inner, cmd = Cmd.none, request = Nothing, save = Nothing }


{-| One message was applied (`before` to `after`): ask again if the query or the rule
changed, and say whether the views are to be stored.
-}
settle : Inner id row -> Inner id row -> Cmd (Msg row) -> Step id row
settle before after cmd =
    let
        ruleChanged =
            FilterBar.rule after.filterBar /= FilterBar.rule before.filterBar

        -- a new rule starts at page 1, and "all matching" would mean other rows
        next =
            if ruleChanged then
                { after | table = after.table |> Table.setPage 1 |> Table.dropAllMatching }

            else
                after

        step =
            if ruleChanged || Table.query next.table /= Table.query before.table then
                ask next cmd

            else
                { state = State next, cmd = cmd, request = Nothing, save = Nothing }
    in
    if SavedViews.views next.views /= SavedViews.views before.views then
        { step | save = Just (SavedViews.views next.views) }

    else
        step


{-| Ask now: a new ticket, and the rows that are on the screen stay (dimmed and busy)
until the answer comes.
-}
ask : Inner id row -> Cmd (Msg row) -> Step id row
ask inner cmd =
    let
        ticket =
            inner.ticket + 1

        next =
            { inner | ticket = ticket, rows = Remote.refresh inner.rows }
    in
    { state = State next
    , cmd = cmd
    , request = Just { query = Table.query next.table, rule = FilterBar.rule next.filterBar, ticket = Ticket ticket }
    , save = Nothing
    }


forceRequest : Step id row -> Step id row
forceRequest step =
    case ( step.request, step.state ) of
        ( Nothing, State inner ) ->
            let
                asked =
                    ask inner step.cmd
            in
            { asked | save = step.save }

        _ ->
            step


{-| The user applied a view (or "Reset", or a link named one): its rule goes into the
filter bar, and the query it holds, if any, into the table.
-}
loadActiveView : Inner id row -> Inner id row
loadActiveView inner =
    let
        active =
            SavedViews.active inner.views

        newRule =
            active |> Maybe.map .rule |> Maybe.withDefault Rule.emptyGroup
    in
    { inner
        | filterBar = FilterBar.setRule newRule inner.filterBar
        , table =
            case active |> Maybe.andThen .query of
                Just q ->
                    Table.setQuery q inner.table

                Nothing ->
                    inner.table
    }



-- OTHER CHANGES


{-| Asks again with the same query, for a refresh button or after the application
changed rows on the server (a bulk action). The rows on the screen stay while the
answer comes.
-}
refresh : State id row -> Step id row
refresh (State inner) =
    ask inner Cmd.none


{-| Takes away every filter: the chips of the filter bar, the column filters and the
search of the table. The table's own "Reset filters" button does it too; use this for a
command or a shortcut ("Clear filters").
-}
clearFilters : State id row -> Step id row
clearFilters (State before) =
    settle before { before | filterBar = FilterBar.clear before.filterBar, table = Table.clearFilters before.table } Cmd.none


{-| Replaces the saved views, for example when they came from the backend after the
list was made. When the user has applied no view, the one marked as default is applied.
-}
setViews : List SavedView -> State id row -> Step id row
setViews views (State before) =
    let
        withViews =
            { before | views = SavedViews.setViews views before.views }

        applied =
            case ( SavedViews.active withViews.views, SavedViews.defaultView withViews.views ) of
                ( Nothing, Just defaultView ) ->
                    let
                        picked =
                            { withViews | views = SavedViews.apply defaultView.name withViews.views }
                    in
                    loadActiveView picked

                _ ->
                    withViews

        settled =
            settle before applied Cmd.none

        step =
            case before.rows of
                NotAsked ->
                    forceRequest settled

                _ ->
                    settled
    in
    -- the views came from the application: nothing to store
    { step | save = Nothing }


{-| Applies the view with this name as if the user had picked it: a link that names a
view (`#/orders?view=Open`) calls it. A name that is not in the list changes nothing.
-}
applyView : String -> State id row -> Step id row
applyView name (State before) =
    let
        picked =
            { before | views = SavedViews.apply name before.views }
    in
    settle before
        (if SavedViews.revision picked.views /= SavedViews.revision before.views then
            loadActiveView picked

         else
            picked
        )
        Cmd.none


{-| Opens the saved views with the form for a new view open ("New saved view", from a
button or a shortcut). The form saves the current rule and query.
-}
startSaveView : State id row -> Step id row
startSaveView (State before) =
    let
        ( views, cmd ) =
            SavedViews.startSave before.views
    in
    { state = State { before | views = views }, cmd = Cmd.map ViewsMsg cmd, request = Nothing, save = Nothing }



-- READING


{-| The page of rows, as a `Remote`: loading, failed, the rows, or the rows with the
note that they are old or being refreshed. Give it to the parts of the page that
show the rows too.
-}
rows : State id row -> Remote (List row)
rows (State inner) =
    inner.rows


{-| How many rows match the query in all, from the last answer; 0 before the first.
-}
total : State id row -> Int
total (State inner) =
    inner.total


{-| The rule of the filter bar as plain data.
-}
rule : State id row -> Rule
rule (State inner) =
    FilterBar.rule inner.filterBar


{-| The query of the table as plain data.
-}
query : State id row -> Table.Query
query (State inner) =
    Table.query inner.table


{-| The saved views, in the order of the list.
-}
savedViews : State id row -> List SavedView
savedViews (State inner) =
    SavedViews.views inner.views


{-| The view the user applied last, if it still exists.
-}
activeView : State id row -> Maybe SavedView
activeView (State inner) =
    SavedViews.active inner.views


{-| The state of the table, to read what the module does not give (`Table.selection`,
`Table.density`).
-}
table : State id row -> Table.State id
table (State inner) =
    inner.table


{-| Changes the table with a function of `Table`: the page size, the density, the
selection after a bulk action, the focus. A change of the query this way is not
noticed; use it for what is not part of the query.

    ServerList.mapTable Table.clearSelection model.orders

-}
mapTable : (Table.State id -> Table.State id) -> State id row -> State id row
mapTable change (State inner) =
    State { inner | table = change inner.table }


{-| Moves keyboard focus to the table. Use it when whatever had focus is gone: a bulk
action that removed the selected rows takes the bulk bar and its buttons with it.

    Cmd.map OrdersMsg (ServerList.focus model.orders)

-}
focus : State id row -> Cmd (Msg row)
focus (State inner) =
    Cmd.map TableMsg (Table.focus inner.table)



-- SELECTED ROWS


{-| What the user selected, for a request the application fulfils: rows picked one by
one (they can be on several pages), or every row that matches the query and the rule
except the ones taken out. The table cannot list the second: your backend does it.
-}
type Target id
    = Picked (List id)
    | Matching { query : Table.Query, rule : Rule, except : List id }


{-| The selection as a `Target`, or `Nothing` when nothing is selected. Needs the
`RowIds` that the table was given with `rowId`.

    case ServerList.target orderIds model.orders of
        Just (ServerList.Picked ids) ->
            packOrders ids

        Just (ServerList.Matching { query, rule, except }) ->
            packAllMatching query rule except

        Nothing ->
            ( model, Cmd.none )

-}
target : Ids id -> State id row -> Maybe (Target id)
target ids (State inner) =
    case Table.selection ids inner.table of
        Table.Selected [] ->
            Nothing

        Table.Selected picked ->
            Just (Picked picked)

        Table.AllMatching { except } ->
            Just (Matching { query = Table.query inner.table, rule = FilterBar.rule inner.filterBar, except = except })



-- VIEW


{-| The table. It gets `Table.server`, the rows, the retry and refresh buttons, the
count of filters from the filter bar and the button that clears them; give it the rest
(`Table.columns`, `Table.rowId`, `Table.searchable` ...).
-}
viewTable : (Msg row -> msg) -> List (Table.Attribute id row msg) -> State id row -> Html msg
viewTable toMsg attributes (State inner) =
    Table.view (TableMsg >> toMsg)
        ([ Table.server { total = inner.total }
         , Table.remote inner.rows
         , Table.onRetry (toMsg Refresh)
         , Table.onRefresh (toMsg Refresh)
         , Table.activeExternalFilters (Rule.conditionCount (FilterBar.rule inner.filterBar))
         , Table.onResetFilters (toMsg ClearFilters)
         ]
            ++ attributes
        )
        inner.table


{-| The filter bar. It gets the match count (while the answer is fresh) and the
"counting" mark (while it is on its way); give it `FilterBar.fields` and the rest.
-}
viewFilterBar : (Msg row -> msg) -> List (FilterBar.Attribute r msg) -> State id row -> Html msg
viewFilterBar toMsg attributes (State inner) =
    FilterBar.view (FilterBarMsg >> toMsg)
        ([ FilterBar.matchCount
            (if Remote.isLoaded inner.rows then
                Just inner.total

             else
                Nothing
            )
         , FilterBar.counting (Remote.isRefreshing inner.rows || Remote.isLoading inner.rows)
         ]
            ++ attributes
        )
        inner.filterBar


{-| The saved views button. It gets the current rule and query, which is what "Save
current view ..." saves and what a view is compared with.
-}
viewSavedViews : (Msg row -> msg) -> List (SavedViews.Attribute msg) -> State id row -> Html msg
viewSavedViews toMsg attributes (State inner) =
    SavedViews.view (ViewsMsg >> toMsg)
        ([ SavedViews.current (FilterBar.rule inner.filterBar)
         , SavedViews.currentQuery (Table.query inner.table)
         ]
            ++ attributes
        )
        inner.views
