module Klar.ServerList exposing
    ( State, Msg, Step, init, update, gotPage
    , viewTable, viewFilterBar, viewSavedViews
    , Request, Page, Ticket
    , refresh, clearFilters, setRule, setViews, applyView, startSaveView
    , toQueryString, fromQueryString
    , rows, total, rule, query, savedViews, activeView
    , table, mapTable, mapRows, focus
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

Each returns a `Step` like `update`. Before the first answer has come, each of them asks
(again): so the application can make the list with `init`, change it at once (a stored
view, the address, a page size) and follow only the last step.

@docs refresh, clearFilters, setRule, setViews, applyView, startSaveView


# The list in the address

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

@docs toQueryString, fromQueryString


# Reading the state

@docs rows, total, rule, query, savedViews, activeView


# The table and the rows

@docs table, mapTable, mapRows, focus


# Selected rows

@docs Target, target

-}

import Html exposing (Html)
import Json.Decode as Decode
import Json.Encode as Encode
import Klar.FilterBar as FilterBar
import Klar.Ids exposing (Ids)
import Klar.Internal as Internal
import Klar.Remote as Remote exposing (Remote(..))
import Klar.Rule as Rule exposing (Rule)
import Klar.RuleBuilder.Support as Support
import Klar.SavedViews as SavedViews exposing (SavedView)
import Klar.Table as Table
import Task
import Time
import Url



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
    , viewsArrived : Bool
    }


{-| The messages of the three parts and of the answer. Wrap it in a constructor of your
own message type and give it to `update`; make the answer with `gotPage`.
-}
type Msg row
    = TableMsg Table.Msg
    | FilterBarMsg FilterBar.Msg
    | ViewsMsg SavedViews.Msg
    | GotPage Ticket (Result Remote.Problem (Page row))
    | Stamped Ticket Time.Posix
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


{-| What the server is asked: the table's query (the search, the sort, the page and the
page size, and the column filters if the columns have any) and the filter bar's rule.
Answer with `gotPage request`; the ticket inside it lets the list drop an answer that is
no longer wanted.
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

To start somewhere else (the view the user had, the address of a link), give the state
of this step to `applyView` or `fromQueryString` and follow that step instead: it
carries the first request.

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
            , viewsArrived = False
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

        GotPage ticket result ->
            if ticket /= Ticket before.ticket then
                idle before

            else
                case result of
                    Ok page ->
                        let
                            asked =
                                Table.query before.table

                            lastPage =
                                max 1 (ceiling (toFloat page.total / toFloat (max 1 asked.pageSize)))
                        in
                        if List.isEmpty page.rows && page.total > 0 && asked.page > lastPage then
                            -- rows were removed and the page is past the end: ask for the last one
                            ask { before | table = Table.setPage lastPage before.table, total = page.total } Cmd.none

                        else
                            { state = State { before | rows = Loaded page.rows, total = page.total }
                            , cmd = Task.perform (Stamped ticket) Time.now
                            , request = Nothing
                            , save = Nothing
                            }

                    Err problem ->
                        -- the time is only kept for data that came
                        idle { before | rows = Remote.refreshWith before.rows (Err problem) (Time.millisToPosix 0) }

        Stamped ticket at ->
            case before.rows of
                Loaded data ->
                    if ticket == Ticket before.ticket then
                        idle { before | rows = Remote.refreshWith before.rows (Ok data) at }

                    else
                        idle before

                _ ->
                    idle before

        Refresh ->
            ask before Cmd.none

        ClearFilters ->
            clearFilters (State before)


{-| The message for the answer to a `Request`: the rows of the page and the total, or
the problem. The list notes when the answer came (for "Old data from 14:05" after a
later refresh fails), so there is no `Time.now` to chain. An answer to a request that is
not the latest is dropped by `update`.
-}
gotPage : Request -> Result Remote.Problem (Page row) -> Msg row
gotPage request result =
    GotPage request.ticket result


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


{-| Before the first answer, a change from the application always asks: the step of
`init` may not have been followed.
-}
whileWaiting : Inner id row -> Step id row -> Step id row
whileWaiting before step =
    case before.rows of
        NotAsked ->
            forceRequest step

        Loading ->
            forceRequest step

        _ ->
            step


{-| The user applied a view (or "Reset", or a link named one): its rule goes into the
filter bar, and the query it holds into the table. A view without a query, and "Reset"
to no view, take away the search and the column filters; the sort and the page size
stay.
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
                    Table.clearFilters inner.table
    }


{-| Whether the user has filtered or paged the list yet: a default view that arrives
later must not replace what they did.
-}
untouched : Inner id row -> Bool
untouched inner =
    let
        q =
            Table.query inner.table
    in
    Rule.isEmpty (FilterBar.rule inner.filterBar)
        && (q.search == "")
        && List.isEmpty q.filters
        && (q.page == 1)
        && (SavedViews.active inner.views == Nothing)



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


{-| Puts a rule into the filter bar and asks from page 1, for a link from elsewhere
("the orders of this customer" on a dashboard) or a command. A rule that the filter bar
shows already asks for nothing.

    ServerList.setRule (Rule.allOf [ Rule.is "customer" customer.id ]) model.orders

-}
setRule : Rule -> State id row -> Step id row
setRule newRule (State before) =
    whileWaiting before
        (settle before
            (if Support.same newRule (FilterBar.rule before.filterBar) then
                before

             else
                { before | filterBar = FilterBar.setRule newRule before.filterBar }
            )
            Cmd.none
        )


{-| Replaces the saved views, for example when they came from the backend after the
list was made. The default view is applied when the views arrive for the first time
and the user has not filtered or paged the list yet; a later list (the echo of a store,
another tab) only replaces the views, so the filters that are on the screen stay.
-}
setViews : List SavedView -> State id row -> Step id row
setViews views (State before) =
    let
        withViews =
            { before
                | views = SavedViews.setViews views before.views
                , viewsArrived = before.viewsArrived || not (List.isEmpty views)
            }

        applied =
            case SavedViews.defaultView withViews.views of
                Just defaultView ->
                    if not before.viewsArrived && untouched before then
                        loadActiveView { withViews | views = SavedViews.apply defaultView.name withViews.views }

                    else
                        withViews

                Nothing ->
                    withViews

        step =
            whileWaiting before (settle before applied Cmd.none)
    in
    -- the views came from the application: nothing to store
    { step | save = Nothing }


{-| Applies the view with this name as if the user had picked it: a link that names a
view (`#/orders?view=Open`) or the view the user had last time calls it. A name that is
not in the list changes nothing.
-}
applyView : String -> State id row -> Step id row
applyView name (State before) =
    let
        picked =
            { before | views = SavedViews.apply name before.views }
    in
    whileWaiting before
        (settle before
            (if SavedViews.revision picked.views /= SavedViews.revision before.views then
                loadActiveView picked

             else
                picked
            )
            Cmd.none
        )


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



-- THE ADDRESS


{-| The list as the query of an address, without the `?`: the active view (`view`),
the search, the sort (`sort=-total,customer`, a `-` for descending), the filter bar's
rule and the column filters (as JSON), the page (when it is not 1) and the page size.
Every text is percent-encoded, so any name or search is safe in a link.

    ServerList.toQueryString model.orders -- "view=Open&search=fjord&page=3&size=25"

-}
toQueryString : State id row -> String
toQueryString (State inner) =
    let
        q =
            Table.query inner.table

        current =
            FilterBar.rule inner.filterBar

        param key value =
            key ++ "=" ++ Internal.percentEncode value
    in
    String.join "&"
        (List.concat
            [ SavedViews.active inner.views |> Maybe.map (\saved -> [ param "view" saved.name ]) |> Maybe.withDefault []
            , if String.isEmpty q.search then
                []

              else
                [ param "search" q.search ]
            , if List.isEmpty q.sort then
                []

              else
                [ "sort=" ++ String.join "," (List.map sortText q.sort) ]
            , if Rule.isEmpty current then
                []

              else
                [ param "rule" (Encode.encode 0 (Rule.encode current)) ]
            , if List.isEmpty q.filters then
                []

              else
                [ param "filters" (filtersText q) ]
            , if q.page > 1 then
                [ "page=" ++ String.fromInt q.page ]

              else
                []
            , [ "size=" ++ String.fromInt q.pageSize ]
            ]
        )


{-| Puts the list where an address says (the part after the `?`, as `toQueryString`
writes it) and asks when that is not what the list shows. A parameter that is missing
takes the value of an empty list (no search, no sort, no filters, page 1), except the page
size, which stays. An address with only `view=Name` applies that view; an address with
none of these parameters is "Reset": the default view, or no filters. A parameter that
cannot be read counts as missing.

    ServerList.fromQueryString "view=Open&page=2" model.orders

-}
fromQueryString : String -> State id row -> Step id row
fromQueryString text (State before) =
    let
        params =
            parseParams text

        raw key =
            params |> List.filter (\( name, _ ) -> name == key) |> List.head |> Maybe.map Tuple.second

        decoded key =
            raw key |> Maybe.andThen decode

        viewName =
            decoded "view"

        listed =
            List.any (\key -> raw key /= Nothing) [ "search", "sort", "rule", "filters", "page", "size" ]
    in
    if listed then
        let
            q =
                Table.query before.table

            wanted =
                { search = decoded "search" |> Maybe.withDefault ""
                , sort = raw "sort" |> Maybe.map parseSort |> Maybe.withDefault []
                , filters = decoded "filters" |> Maybe.map parseFilters |> Maybe.withDefault []
                , page = raw "page" |> Maybe.andThen String.toInt |> Maybe.withDefault 1 |> max 1
                , pageSize = raw "size" |> Maybe.andThen String.toInt |> Maybe.withDefault q.pageSize |> max 1
                }

            newRule =
                decoded "rule"
                    |> Maybe.andThen (Decode.decodeString Rule.decoder >> Result.toMaybe)
                    |> Maybe.withDefault Rule.emptyGroup

            -- node ids do not count: the rule of an address is the rule on the screen
            ruleChanged =
                not (Support.same newRule (FilterBar.rule before.filterBar))

            -- the address gives the page, also when the rule changed; "all matching"
            -- would mean other rows under another rule
            after =
                { before
                    | views = SavedViews.setActive viewName before.views
                    , filterBar =
                        if ruleChanged then
                            FilterBar.setRule newRule before.filterBar

                        else
                            before.filterBar
                    , table =
                        (if wanted == q then
                            before.table

                         else
                            Table.setQuery wanted before.table
                        )
                            |> (if ruleChanged then
                                    Table.dropAllMatching

                                else
                                    identity
                               )
                }
        in
        whileWaiting before
            (if ruleChanged || Table.query after.table /= q then
                ask after Cmd.none

             else
                idle after
            )

    else
        case ( viewName, SavedViews.defaultView before.views ) of
            ( Just name, _ ) ->
                applyView name (State before)

            ( Nothing, Just defaultView ) ->
                applyView defaultView.name (State before)

            ( Nothing, Nothing ) ->
                whileWaiting before
                    (settle before (loadActiveView { before | views = SavedViews.setActive Nothing before.views }) Cmd.none)


sortText : ( Table.ColumnId, Table.Direction ) -> String
sortText ( column, direction ) =
    let
        name =
            Internal.percentEncode (Table.columnName column)

        -- a name that starts with "-" must not read as descending
        safe =
            if String.startsWith "-" name then
                "%2D" ++ String.dropLeft 1 name

            else
                name
    in
    case direction of
        Table.Descending ->
            "-" ++ safe

        Table.Ascending ->
            safe


parseSort : String -> List ( Table.ColumnId, Table.Direction )
parseSort value =
    String.split "," value
        |> List.filterMap
            (\part ->
                if String.startsWith "-" part then
                    decode (String.dropLeft 1 part) |> Maybe.map (\name -> ( Table.columnId name, Table.Descending ))

                else
                    decode part |> Maybe.map (\name -> ( Table.columnId name, Table.Ascending ))
            )
        |> List.filter (\( column, _ ) -> Table.columnName column /= "")


filtersText : Table.Query -> String
filtersText q =
    Table.encodeQuery q
        |> Decode.decodeValue (Decode.field "filters" Decode.value)
        |> Result.map (Encode.encode 0)
        |> Result.withDefault "[]"


parseFilters : String -> List ( Table.ColumnId, Table.Filter )
parseFilters value =
    case Decode.decodeString (Decode.list Decode.value) value of
        Ok filters ->
            Encode.object [ ( "filters", Encode.list identity filters ) ]
                |> Decode.decodeValue Table.queryDecoder
                |> Result.map .filters
                |> Result.withDefault []

        Err _ ->
            []


parseParams : String -> List ( String, String )
parseParams text =
    (if String.startsWith "?" text then
        String.dropLeft 1 text

     else
        text
    )
        |> String.split "&"
        |> List.filterMap
            (\pair ->
                case String.indexes "=" pair of
                    at :: _ ->
                        Just ( String.left at pair, String.dropLeft (at + 1) pair )

                    [] ->
                        if String.isEmpty pair then
                            Nothing

                        else
                            Just ( pair, "" )
            )


decode : String -> Maybe String
decode value =
    Url.percentDecode (String.replace "+" " " value)



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


{-| The view the user applied last, if it still exists. Keep its name with the views
to bring the user back to it next time (`applyView`).
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


{-| Changes the table with a function of `Table` and asks again when that changed the
query: the page size from a stored setting, the sort, the selection after a bulk
action, the density.

    ServerList.mapTable (Table.setPageSize 50) model.orders

-}
mapTable : (Table.State id -> Table.State id) -> State id row -> Step id row
mapTable change (State before) =
    whileWaiting before (settle before { before | table = change before.table } Cmd.none)


{-| Changes the rows on the screen without asking the server: the row the user just
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

-}
mapRows : (row -> row) -> State id row -> State id row
mapRows change (State inner) =
    State { inner | rows = Remote.map (List.map change) inner.rows }


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
`Klar.Ids` of the row ids that the table was given with `rowId`.

    case ServerList.target Ids.string model.orders of
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
         , Table.rows inner.rows
         , Table.onRetry (toMsg Refresh)
         , Table.onRefresh (toMsg Refresh)
         , Table.activeExternalFilters (Rule.conditionCount (FilterBar.rule inner.filterBar))
         , Table.onResetFilters (toMsg ClearFilters)
         ]
            ++ attributes
        )
        inner.table


{-| The filter bar. It gets the match count (while the answer is fresh: after a failed
refresh the count would be the one of the rule before) and the "counting" mark (while
it is on its way); give it `FilterBar.fields` and the rest.
-}
viewFilterBar : (Msg row -> msg) -> List (FilterBar.Attribute r msg) -> State id row -> Html msg
viewFilterBar toMsg attributes (State inner) =
    FilterBar.view (FilterBarMsg >> toMsg)
        ([ FilterBar.matchCount
            (if Remote.isLoaded inner.rows && not (Remote.isStale inner.rows) then
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
        ([ SavedViews.currentRule (FilterBar.rule inner.filterBar)
         , SavedViews.currentQuery (Table.query inner.table)
         ]
            ++ attributes
        )
        inner.views
