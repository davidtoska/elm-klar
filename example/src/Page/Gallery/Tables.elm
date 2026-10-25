module Page.Gallery.Tables exposing (Model, Msg, init, subscriptions, update, view)

{-| Gallery page: the data table (client and server mode, every state) and
pagination on its own.

Each example keeps its own part of the model, and each section is drawn with
`Html.Lazy`: a message for one table does not make the page process the 3,000
rows of another. Do the same on application pages with big client-side tables.

-}

import Api.Types exposing (Order, OrderId, OrderStatus(..), Priority(..), allOrderStatuses, allPriorities, allowedNextStatuses, isEditable, orderId, orderIdText, orderStatusLabel, priorityLabel)
import Html exposing (Html)
import Html.Lazy
import Klar.Badge as Badge
import Klar.Button as Button
import Klar.Date as Date
import Klar.DescriptionList as DescriptionList
import Klar.EmptyState as EmptyState
import Klar.Format as Format
import Klar.Icon as Icon
import Klar.Ids as Ids exposing (Ids)
import Klar.Layout as Layout
import Klar.Locale as Locale exposing (Locale)
import Klar.Menu as Menu
import Klar.Pagination as Pagination
import Klar.Progress as Progress
import Klar.Remote as Remote exposing (Remote)
import Klar.Search as Search
import Klar.SegmentedControl as SegmentedControl
import Klar.Switch as Switch
import Klar.Table as Table
import Klar.Text as Text
import Klar.Theme as Theme exposing (Tone(..))
import Page.Gallery.Tables.Large as Large
import Process
import Set
import Showcase.Doc as Doc
import Showcase.Sample as Sample
import Task
import View.Ids exposing (orderRows)
import View.Labels as Labels



-- MODEL


type alias Model =
    { client : Client
    , server : Server
    , columns : Columns
    , views : Views
    , simple : Simple
    , states : States
    , narrow : Table.State OrderId
    , norwegian : Table.State OrderId
    , pagers : Pagers
    , large : Large.Model
    }


type alias Client =
    { orders : Remote (List Order)
    , table : Table.State OrderId
    , urgentOnly : Bool
    , refreshing : Bool
    , refreshes : Int
    , lastEvent : String
    }


type alias Server =
    { table : Table.State OrderId
    , rows : Remote (List Order)
    , total : Int
    , refreshing : Bool
    , request : Int
    , query : Table.Query
    , simulateError : Bool
    , slowServer : Bool
    , lastEvent : String
    }


type alias Columns =
    { kinds : Table.State OrderId
    , sorting : Table.State OrderId
    , lastEvent : String
    }


type alias Views =
    { table : Table.State OrderId
    , applied : String
    }


type alias Simple =
    { owners : Table.State String
    , picking : Table.State String
    , lastEvent : String
    }


type alias States =
    { empty : Table.State OrderId
    , noMatch : Table.State OrderId
    , loading : Table.State OrderId
    , failed : Table.State OrderId
    , lifecycle : Lifecycle
    , lastEvent : String
    }


{-| The table that fails and is tried again: what it shows now, what kind of
failure it is, how often it was tried, and whether the "service" is back.
-}
type alias Lifecycle =
    { rows : Remote (List Order)
    , kind : Remote.Kind
    , attempts : Int
    , serviceBack : Bool
    }


type alias Pagers =
    { full : { page : Int, pageSize : Int }
    , compact : Int
    , few : Int
    , many : Int
    }


type SavedView
    = AllOrders
    | OpenAndUrgent
    | LargeOrders
    | DeliveredInRotterdam
    | ReviewOrders


type Msg
    = NoOp
      -- client mode
    | ClientTable Table.Msg
    | UrgentOnlyToggled Bool
    | ExternalFilterCleared
    | Refresh
    | Refreshed Int
    | Opened Order
    | Edit Order
    | CancelOrder Order
    | Delete Order
    | CancelSelected
    | RemindSelected
    | DeleteSelected
    | NewOrder
      -- server mode
    | ServerTable Table.Msg
    | GotPage Int (Result Remote.Problem { rows : List Order, total : Int })
    | ServerRetry
    | ServerRefresh
    | ServerExportSelected
    | SimulateErrorToggled Bool
    | SlowServerToggled Bool
      -- columns
    | KindsTable Table.Msg
    | SortingTable Table.Msg
    | ColumnAction String
      -- saved views
    | ViewsTable Table.Msg
    | ViewApplied SavedView
    | ViewFiltersCleared
    | ViewPageThree
      -- simple tables
    | OwnersTable Table.Msg
    | PickingTable Table.Msg
    | PickingNotified
      -- states
    | EmptyTable Table.Msg
    | CreateOrder
    | NoMatchTable Table.Msg
    | LoadingTable Table.Msg
    | FailedTable Table.Msg
    | FailedRetry
    | FailedAnswered Int
    | ServiceBackToggled Bool
    | FailureKindChosen String
      -- narrow container and locale
    | NarrowTable Table.Msg
    | NorwegianTable Table.Msg
      -- pagination
    | FullPage Int
    | FullPageSize Int
    | CompactPage Int
    | FewPage Int
    | ManyPage Int
      -- 50 000 rows
    | LargeMsg Large.Msg


init : ( Model, Cmd Msg )
init =
    let
        serverTable =
            Table.init "server-orders"

        ( server, fetchCmd ) =
            fetch
                { table = serverTable
                , rows = Remote.Loading
                , total = 0
                , refreshing = False
                , request = 0
                , query = Table.query serverTable
                , simulateError = False
                , slowServer = False
                , lastEvent = "No events yet."
                }
    in
    ( { client =
            { orders = allOrders
            , table = Table.init "client-orders" |> Table.setSort [ ( columnIds.priority, Table.Descending ), ( columnIds.status, Table.Ascending ) ]
            , urgentOnly = False
            , refreshing = False
            , refreshes = 0
            , lastEvent = "Click a row, use a row menu or select rows."
            }
      , server = server
      , columns =
            { kinds = Table.init "kinds-orders" |> Table.setPageSize 10
            , sorting = Table.init "sorting-orders" |> Table.setPageSize 10
            , lastEvent = "Use the buttons in the last column."
            }
      , views = { table = applyView AllOrders, applied = "none yet" }
      , simple =
            { owners = Table.init "owners-summary" |> Table.setSort [ ( columnIds.orders, Table.Descending ) ]
            , picking = Table.init "owners-picking"
            , lastEvent = "Select owners and send the summary."
            }
      , states =
            { empty = Table.init "empty-orders"
            , noMatch = Table.init "no-match-orders" |> Table.setSearch "Zyxwv"
            , loading = Table.init "loading-orders" |> Table.setPageSize 5
            , failed = Table.init "failed-orders"
            , lifecycle =
                { rows = Remote.Failed (failedProblem Remote.network)
                , kind = Remote.network
                , attempts = 0
                , serviceBack = False
                }
            , lastEvent = "Press the button in the empty state."
            }
      , narrow = Table.init "narrow-orders" |> Table.setDensity Theme.Compact |> Table.setPageSize 50
      , norwegian = Table.init "norwegian-orders" |> Table.setPageSize 10
      , pagers = { full = { page = 6, pageSize = 25 }, compact = 1, few = 2, many = 1234 }
      , large = Large.init
      }
    , fetchCmd
    )


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none



-- UPDATE


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        NoOp ->
            ( model, Cmd.none )

        -- CLIENT MODE
        ClientTable inner ->
            Table.update inner model.client.table
                |> tableStep (\table -> withClient (\c -> { c | table = table }) model) ClientTable

        UrgentOnlyToggled value ->
            ( withClient (\c -> { c | urgentOnly = value }) model, Cmd.none )

        ExternalFilterCleared ->
            ( withClient (\c -> { c | urgentOnly = False }) model, Cmd.none )

        Refresh ->
            let
                n =
                    model.client.refreshes + 1
            in
            ( withClient (\c -> { c | refreshing = True, refreshes = n }) model
            , Process.sleep 1200 |> Task.perform (\_ -> Refreshed n)
            )

        Refreshed n ->
            if n == model.client.refreshes then
                ( withClient (\c -> { c | refreshing = False, lastEvent = "The data is refreshed." }) model, Cmd.none )

            else
                ( model, Cmd.none )

        Opened order ->
            ( clientEvent ("Opened " ++ orderIdText order.id ++ " (" ++ order.customer ++ ").") model, Cmd.none )

        Edit order ->
            ( clientEvent ("Edit " ++ orderIdText order.id ++ ".") model, Cmd.none )

        CancelOrder order ->
            ( withClient
                (\c ->
                    { c
                        | orders = Remote.map (List.map (cancelIf (\o -> o.id == order.id))) c.orders

                        -- a disabled row keeps its selection and its open details until told otherwise
                        , table = c.table |> Table.setSelected orderRows [ order.id ] False |> Table.setExpanded orderRows order.id False
                        , lastEvent = "Order " ++ orderIdText order.id ++ " is cancelled. The row is now disabled."
                    }
                )
                model
              -- the row's menu button is disabled now: keep the focus in the table
            , Cmd.map ClientTable (Table.focus model.client.table)
            )

        Delete order ->
            ( withClient
                (\c ->
                    { c
                        | orders = Remote.map (List.filter (\o -> o.id /= order.id)) c.orders
                        , table = c.table |> Table.setSelected orderRows [ order.id ] False |> Table.setExpanded orderRows order.id False
                        , lastEvent = "Order " ++ orderIdText order.id ++ " is deleted."
                    }
                )
                model
            , Cmd.none
            )

        CancelSelected ->
            let
                ids =
                    Set.fromList (List.map orderIdText (Table.selectedIds orderRows model.client.table))

                chosen =
                    Remote.withDefault [] model.client.orders
                        |> List.filter (\o -> Set.member (orderIdText o.id) ids)

                cancellable =
                    List.filter canCancel chosen

                skipped =
                    List.length chosen - List.length cancellable
            in
            ( withClient
                (\c ->
                    { c
                        | orders = Remote.map (List.map (cancelIf (\o -> Set.member (orderIdText o.id) ids))) c.orders
                        , table =
                            List.foldl (\o table -> Table.setExpanded orderRows o.id False table) (Table.clearSelection c.table) cancellable
                        , lastEvent =
                            countText (List.length cancellable) "order" "orders"
                                ++ " cancelled"
                                ++ (if skipped > 0 then
                                        ", " ++ countText skipped "order" "orders" ++ " could not be cancelled (already shipped or delivered)."

                                    else
                                        "."
                                   )
                    }
                )
                model
              -- the bulk bar, and the button that was pressed, are gone
            , Cmd.map ClientTable (Table.focus model.client.table)
            )

        RemindSelected ->
            ( clientEvent
                ("Reminder sent to the customers of "
                    ++ countText (List.length (Table.selectedIds orderRows model.client.table)) "order" "orders"
                    ++ " (a bulk action of the application's own)."
                )
                model
            , Cmd.none
            )

        DeleteSelected ->
            let
                ids =
                    Set.fromList (List.map orderIdText (Table.selectedIds orderRows model.client.table))
            in
            ( withClient
                (\c ->
                    { c
                        | orders = Remote.map (List.filter (\o -> not (Set.member (orderIdText o.id) ids))) c.orders
                        , table = Table.clearSelection c.table
                        , lastEvent = countText (Set.size ids) "order" "orders" ++ " deleted."
                    }
                )
                model
              -- the bulk bar, and the button that was pressed, are gone
            , Cmd.map ClientTable (Table.focus model.client.table)
            )

        NewOrder ->
            ( clientEvent "“New order” is a button of the application's own, in the toolbar." model, Cmd.none )

        -- SERVER MODE
        ServerTable inner ->
            let
                server =
                    model.server

                ( table, cmd ) =
                    Table.update inner server.table
            in
            if Table.query table /= Table.query server.table then
                let
                    ( fetched, fetchCmd ) =
                        fetch { server | table = table }
                in
                ( { model | server = fetched }, Cmd.batch [ Cmd.map ServerTable cmd, fetchCmd ] )

            else
                ( { model | server = { server | table = table } }, Cmd.map ServerTable cmd )

        GotPage requestId result ->
            let
                server =
                    model.server
            in
            if requestId /= server.request then
                -- an older request answered after a newer one was sent
                ( model, Cmd.none )

            else
                case result of
                    Ok answer ->
                        ( { model | server = { server | rows = Remote.Loaded answer.rows, total = answer.total, refreshing = False } }, Cmd.none )

                    Err problem ->
                        ( { model | server = { server | rows = Remote.Failed problem, refreshing = False } }, Cmd.none )

        ServerRetry ->
            let
                server =
                    model.server
            in
            fetch { server | rows = Remote.Loading }
                |> Tuple.mapFirst (\s -> { model | server = s })

        ServerRefresh ->
            fetch model.server
                |> Tuple.mapFirst (\s -> { model | server = s })

        ServerExportSelected ->
            let
                server =
                    model.server

                count =
                    Table.selectedCount server.total server.table

                how =
                    case Table.selection orderRows server.table of
                        Table.AllMatching { except } ->
                            if List.isEmpty except then
                                "all rows matching the query"

                            else
                                "all rows matching the query, except " ++ countText (List.length except) "row" "rows"

                        Table.Selected _ ->
                            "the selected ids"
            in
            ( { model | server = { server | lastEvent = "The server exports " ++ countText count "row" "rows" ++ " (" ++ how ++ ")." } }
            , Cmd.none
            )

        SimulateErrorToggled value ->
            let
                server =
                    model.server
            in
            ( { model | server = { server | simulateError = value } }, Cmd.none )

        SlowServerToggled value ->
            let
                server =
                    model.server
            in
            ( { model | server = { server | slowServer = value } }, Cmd.none )

        -- COLUMNS
        KindsTable inner ->
            Table.update inner model.columns.kinds
                |> tableStep (\table -> withColumns (\c -> { c | kinds = table }) model) KindsTable

        SortingTable inner ->
            Table.update inner model.columns.sorting
                |> tableStep (\table -> withColumns (\c -> { c | sorting = table }) model) SortingTable

        ColumnAction text ->
            ( withColumns (\c -> { c | lastEvent = text }) model, Cmd.none )

        -- SAVED VIEWS
        ViewsTable inner ->
            Table.update inner model.views.table
                |> tableStep (\table -> withViews (\v -> { v | table = table }) model) ViewsTable

        ViewApplied saved ->
            ( withViews (\v -> { v | table = applyView saved, applied = savedViewName saved }) model, Cmd.none )

        ViewFiltersCleared ->
            ( withViews (\v -> { v | table = Table.clearFilters v.table, applied = "Search and filters cleared" }) model, Cmd.none )

        ViewPageThree ->
            ( withViews (\v -> { v | table = Table.setPage 3 v.table, applied = "Page 3" }) model, Cmd.none )

        -- SIMPLE TABLES
        OwnersTable inner ->
            Table.update inner model.simple.owners
                |> tableStep (\table -> withSimple (\s -> { s | owners = table }) model) OwnersTable

        PickingTable inner ->
            Table.update inner model.simple.picking
                |> tableStep (\table -> withSimple (\s -> { s | picking = table }) model) PickingTable

        PickingNotified ->
            let
                names =
                    Table.selectedIds Ids.string model.simple.picking
            in
            -- the selection is over, and the bar with the button that was pressed with it
            ( withSimple
                (\s ->
                    { s
                        | picking = Table.clearSelection s.picking
                        , lastEvent = "Summary sent to " ++ String.join ", " names ++ "."
                    }
                )
                model
            , Cmd.map PickingTable (Table.focus model.simple.picking)
            )

        -- STATES
        EmptyTable inner ->
            Table.update inner model.states.empty
                |> tableStep (\table -> withStates (\s -> { s | empty = table }) model) EmptyTable

        CreateOrder ->
            ( withStates (\s -> { s | lastEvent = "“Create order” is a button of the application's own, in the empty state." }) model, Cmd.none )

        NoMatchTable inner ->
            Table.update inner model.states.noMatch
                |> tableStep (\table -> withStates (\s -> { s | noMatch = table }) model) NoMatchTable

        LoadingTable inner ->
            Table.update inner model.states.loading
                |> tableStep (\table -> withStates (\s -> { s | loading = table }) model) LoadingTable

        FailedTable inner ->
            Table.update inner model.states.failed
                |> tableStep (\table -> withStates (\s -> { s | failed = table }) model) FailedTable

        FailedRetry ->
            let
                attempt =
                    model.states.lifecycle.attempts + 1
            in
            ( withLifecycle (\l -> { l | rows = Remote.Loading, attempts = attempt }) model
            , Process.sleep 900 |> Task.perform (\_ -> FailedAnswered attempt)
            )

        FailedAnswered attempt ->
            if attempt /= model.states.lifecycle.attempts then
                -- an older attempt answered after a newer one was started
                ( model, Cmd.none )

            else
                ( withLifecycle
                    (\l ->
                        { l
                            | rows =
                                if l.serviceBack then
                                    Remote.Loaded (List.take 8 mixedOrders)

                                else
                                    Remote.Failed (failedProblem l.kind)
                        }
                    )
                    model
                , Cmd.none
                )

        ServiceBackToggled value ->
            ( withLifecycle (\l -> { l | serviceBack = value }) model, Cmd.none )

        FailureKindChosen value ->
            case failureKindFromValue value of
                Just kind ->
                    ( withLifecycle
                        (\l ->
                            { l
                                | kind = kind
                                , rows =
                                    if Remote.isFailed l.rows then
                                        Remote.Failed (failedProblem kind)

                                    else
                                        l.rows
                            }
                        )
                        model
                    , Cmd.none
                    )

                Nothing ->
                    ( model, Cmd.none )

        -- NARROW CONTAINER AND LOCALE
        NarrowTable inner ->
            Table.update inner model.narrow
                |> tableStep (\table -> { model | narrow = table }) NarrowTable

        NorwegianTable inner ->
            Table.update inner model.norwegian
                |> tableStep (\table -> { model | norwegian = table }) NorwegianTable

        -- PAGINATION
        FullPage n ->
            ( withPagers (\p -> { p | full = { page = n, pageSize = p.full.pageSize } }) model, Cmd.none )

        FullPageSize size ->
            ( withPagers (\p -> { p | full = { page = 1, pageSize = size } }) model, Cmd.none )

        CompactPage n ->
            ( withPagers (\p -> { p | compact = n }) model, Cmd.none )

        FewPage n ->
            ( withPagers (\p -> { p | few = n }) model, Cmd.none )

        ManyPage n ->
            ( withPagers (\p -> { p | many = n }) model, Cmd.none )

        LargeMsg inner ->
            Large.update inner model.large
                |> Tuple.mapBoth (\large -> { model | large = large }) (Cmd.map LargeMsg)


{-| Stores the new state of a table and maps its commands.
-}
tableStep : (Table.State id -> Model) -> (Table.Msg -> Msg) -> ( Table.State id, Cmd Table.Msg ) -> ( Model, Cmd Msg )
tableStep store toMsg =
    Tuple.mapBoth store (Cmd.map toMsg)


withClient : (Client -> Client) -> Model -> Model
withClient change model =
    { model | client = change model.client }


clientEvent : String -> Model -> Model
clientEvent text =
    withClient (\c -> { c | lastEvent = text })


withColumns : (Columns -> Columns) -> Model -> Model
withColumns change model =
    { model | columns = change model.columns }


withViews : (Views -> Views) -> Model -> Model
withViews change model =
    { model | views = change model.views }


withSimple : (Simple -> Simple) -> Model -> Model
withSimple change model =
    { model | simple = change model.simple }


withStates : (States -> States) -> Model -> Model
withStates change model =
    { model | states = change model.states }


withLifecycle : (Lifecycle -> Lifecycle) -> Model -> Model
withLifecycle change =
    withStates (\s -> { s | lifecycle = change s.lifecycle })


withPagers : (Pagers -> Pagers) -> Model -> Model
withPagers change model =
    { model | pagers = change model.pagers }


{-| Cancels the order if the test says so and the order can still be cancelled.
-}
cancelIf : (Order -> Bool) -> Order -> Order
cancelIf test order =
    if test order && canCancel order then
        { order | status = Cancelled }

    else
        order


countText : Int -> String -> String -> String
countText n one other =
    Format.int Locale.default n ++ " " ++ Format.plural Locale.default n { one = one, other = other }



-- FAKE BACKEND


{-| Sends the server table's current query to the "backend": a pure function
over `Showcase.Sample.orders` behind `Process.sleep`. Old rows stay (dimmed)
while a new page loads; without rows the table shows skeleton rows.
-}
fetch : Server -> ( Server, Cmd Msg )
fetch server =
    let
        requestId =
            server.request + 1

        q =
            Table.query server.table

        latency =
            400 + modBy 501 (requestId * 7919)

        delay =
            if server.slowServer then
                latency + 2200

            else
                latency

        hasRows =
            Remote.isLoaded server.rows

        failing =
            server.simulateError
    in
    ( { server
        | request = requestId
        , query = q
        , rows =
            if hasRows then
                server.rows

            else
                Remote.Loading
        , refreshing = hasRows
      }
    , Process.sleep (toFloat delay)
        |> Task.andThen
            (\_ ->
                if failing then
                    Task.fail (failedProblem Remote.server)

                else
                    Task.succeed (serve q)
            )
        |> Task.attempt (GotPage requestId)
    )


{-| What a real backend does with a `Table.Query`: search, filter by column
id, sort by the listed columns (primary first), cut out the page.
-}
serve : Table.Query -> { rows : List Order, total : Int }
serve q =
    let
        words =
            Search.normalize q.search |> String.words

        searched =
            if List.isEmpty words then
                Sample.orders

            else
                List.filter
                    (\o ->
                        let
                            haystack =
                                searchText o
                        in
                        List.all (\word -> String.contains word haystack) words
                    )
                    Sample.orders

        matching =
            searched
                |> List.filter (\o -> List.all (matchesFilter o) q.filters)
                |> List.sortWith (compareBy q.sort)

        total =
            List.length matching

        size =
            max 1 q.pageSize

        current =
            clamp 1 (Pagination.pageCount size total) q.page
    in
    { rows = matching |> List.drop ((current - 1) * size) |> List.take size
    , total = total
    }


searchText : Order -> String
searchText o =
    Search.normalize (String.join "\n" [ orderIdText o.id, o.customer, o.city, orderStatusLabel o.status, ownerName o ])


matchesFilter : Order -> ( Table.ColumnId, Table.Filter ) -> Bool
matchesFilter o ( column, filter ) =
    case ( Table.columnName column, filter ) of
        ( "id", Table.Contains text ) ->
            contains text (orderIdText o.id)

        ( "customer", Table.Contains text ) ->
            contains text o.customer

        ( "city", Table.OneOf values ) ->
            List.member o.city values

        ( "status", Table.OneOf values ) ->
            List.member (orderStatusLabel o.status) values

        ( "owner", Table.OneOf values ) ->
            List.member (ownerName o) values

        ( "total", Table.Between low high ) ->
            Maybe.withDefault True (Maybe.map (\bound -> o.total >= bound) low)
                && Maybe.withDefault True (Maybe.map (\bound -> o.total <= bound) high)

        _ ->
            True


contains : String -> String -> Bool
contains needle haystack =
    String.contains (Search.normalize needle) (Search.normalize haystack)


compareBy : List ( Table.ColumnId, Table.Direction ) -> Order -> Order -> Basics.Order
compareBy levels a b =
    case levels of
        [] ->
            compare (orderIdText a.id) (orderIdText b.id)

        ( column, direction ) :: rest ->
            let
                order =
                    case Table.columnName column of
                        "id" ->
                            compare (orderIdText a.id) (orderIdText b.id)

                        "customer" ->
                            alphabetical direction a.customer b.customer

                        "city" ->
                            alphabetical direction a.city b.city

                        "status" ->
                            directed direction (compare (statusRank a.status) (statusRank b.status))

                        "owner" ->
                            alphabetical direction (ownerName a) (ownerName b)

                        "due" ->
                            directed direction (Date.compare a.due b.due)

                        "total" ->
                            directed direction (compare a.total b.total)

                        _ ->
                            EQ
            in
            if order == EQ then
                compareBy rest a b

            else
                order


{-| Alphabetical order without regard to case or accents. A missing value goes
last whichever way the column is sorted, like in the table's own sorting.
-}
alphabetical : Table.Direction -> String -> String -> Basics.Order
alphabetical direction x y =
    case ( String.isEmpty x, String.isEmpty y ) of
        ( True, True ) ->
            EQ

        ( True, False ) ->
            GT

        ( False, True ) ->
            LT

        ( False, False ) ->
            directed direction (compare (Search.normalize x) (Search.normalize y))


directed : Table.Direction -> Basics.Order -> Basics.Order
directed direction order =
    case direction of
        Table.Ascending ->
            order

        Table.Descending ->
            flip order


flip : Basics.Order -> Basics.Order
flip order =
    case order of
        LT ->
            GT

        EQ ->
            EQ

        GT ->
            LT



-- A PROBLEM FOR THE FAILED TABLES


failedProblem : Remote.Kind -> Remote.Problem
failedProblem kind =
    Remote.problem kind
        |> Remote.withCode
            (if kind == Remote.network then
                "ERR_NETWORK"

             else if kind == Remote.server then
                "HTTP 503"

             else if kind == Remote.forbidden then
                "HTTP 403"

             else
                "ERR_UNKNOWN"
            )


failureKindValue : Remote.Kind -> String
failureKindValue kind =
    if kind == Remote.server then
        "server"

    else if kind == Remote.forbidden then
        "forbidden"

    else
        "network"


failureKindFromValue : String -> Maybe Remote.Kind
failureKindFromValue value =
    case value of
        "network" ->
            Just Remote.network

        "server" ->
            Just Remote.server

        "forbidden" ->
            Just Remote.forbidden

        _ ->
            Nothing


{-| The ids of the columns of the examples on this page, each named once: a sort,
a filter or a column choice refers to the same value as the column it talks
about, so a misspelled id is a compile error and not a table that quietly does
nothing.
-}
columnIds :
    { actions : Table.ColumnId
    , assigned : Table.ColumnId
    , averageTotal : Table.ColumnId
    , city : Table.ColumnId
    , created : Table.ColumnId
    , customer : Table.ColumnId
    , delivered : Table.ColumnId
    , delivery : Table.ColumnId
    , due : Table.ColumnId
    , email : Table.ColumnId
    , id : Table.ColumnId
    , lines : Table.ColumnId
    , name : Table.ColumnId
    , note : Table.ColumnId
    , open : Table.ColumnId
    , orders : Table.ColumnId
    , overdue : Table.ColumnId
    , owner : Table.ColumnId
    , priority : Table.ColumnId
    , progress : Table.ColumnId
    , status : Table.ColumnId
    , total : Table.ColumnId
    , urgent : Table.ColumnId
    , warehouse : Table.ColumnId
    }
columnIds =
    { actions = Table.columnId "actions"
    , assigned = Table.columnId "assigned"
    , averageTotal = Table.columnId "averageTotal"
    , city = Table.columnId "city"
    , created = Table.columnId "created"
    , customer = Table.columnId "customer"
    , delivered = Table.columnId "delivered"
    , delivery = Table.columnId "delivery"
    , due = Table.columnId "due"
    , email = Table.columnId "email"
    , id = Table.columnId "id"
    , lines = Table.columnId "lines"
    , name = Table.columnId "name"
    , note = Table.columnId "note"
    , open = Table.columnId "open"
    , orders = Table.columnId "orders"
    , overdue = Table.columnId "overdue"
    , owner = Table.columnId "owner"
    , priority = Table.columnId "priority"
    , progress = Table.columnId "progress"
    , status = Table.columnId "status"
    , total = Table.columnId "total"
    , urgent = Table.columnId "urgent"
    , warehouse = Table.columnId "warehouse"
    }



-- ORDER HELPERS
-- Defined at the top level, so the table gets the same values on every render.


allOrders : Remote (List Order)
allOrders =
    Remote.Loaded Sample.orders


noOrders : Remote (List Order)
noOrders =
    Remote.Loaded []


{-| 300 orders for the examples that show how columns behave rather than how
many rows a table can hold. They are mixed so that the first page of an example
has an overdue order and one of every status.
-}
mixedOrders : List Order
mixedOrders =
    let
        tests =
            isOverdue :: List.map (\status o -> o.status == status) allOrderStatuses
    in
    Sample.orders
        |> List.take 1500
        |> apart tests
        |> roundRobin
        |> List.take 300


someOrders : Remote (List Order)
someOrders =
    Remote.Loaded (List.take 240 mixedOrders)


{-| Splits a list in the rows that pass the first test, those of the rest that
pass the second, and so on.
-}
apart : List (a -> Bool) -> List a -> List (List a)
apart tests items =
    case tests of
        [] ->
            [ items ]

        test :: rest ->
            let
                ( matching, others ) =
                    List.partition test items
            in
            matching :: apart rest others


{-| One from each list in turn.
-}
roundRobin : List (List a) -> List a
roundRobin lists =
    case List.filter (\list -> not (List.isEmpty list)) lists of
        [] ->
            []

        remaining ->
            List.filterMap List.head remaining ++ roundRobin (List.filterMap List.tail remaining)


isOpen : Order -> Bool
isOpen o =
    o.status /= Delivered && o.status /= Cancelled


isCancelled : Order -> Bool
isCancelled o =
    o.status == Cancelled


isUrgent : Order -> Bool
isUrgent o =
    o.priority == Urgent


isOverdue : Order -> Bool
isOverdue o =
    isOpen o && Date.compare o.due Sample.today == LT


canCancel : Order -> Bool
canCancel o =
    List.member Cancelled (allowedNextStatuses o.status)


ownerName : Order -> String
ownerName o =
    o.owner |> Maybe.map Sample.ownerName |> Maybe.withDefault ""


orderLabel : Order -> String
orderLabel o =
    orderIdText o.id ++ ", " ++ o.customer


orderTone : Order -> Maybe Tone
orderTone o =
    if o.priority == Urgent && isOpen o then
        Just Danger

    else
        Nothing


statusRank : OrderStatus -> Float
statusRank status =
    case status of
        Draft ->
            1

        Confirmed ->
            2

        Picking ->
            3

        Shipped ->
            4

        Delivered ->
            5

        Cancelled ->
            6


priorityRank : Priority -> Float
priorityRank priority =
    case priority of
        Low ->
            1

        Normal ->
            2

        High ->
            3

        Urgent ->
            4


statusEntry : Order -> ( Tone, String )
statusEntry o =
    ( Labels.statusTone o.status, orderStatusLabel o.status )


priorityEntry : Order -> ( Tone, String )
priorityEntry o =
    ( Labels.priorityTone o.priority, priorityLabel o.priority )


statusLabels : List String
statusLabels =
    List.map orderStatusLabel allOrderStatuses


priorityLabels : List String
priorityLabels =
    List.map priorityLabel allPriorities


{-| How far an order has come on its way from draft to delivered (0 to 4).
-}
steps : Order -> Int
steps o =
    case o.status of
        Draft ->
            0

        Confirmed ->
            1

        Picking ->
            2

        Shipped ->
            3

        Delivered ->
            4

        Cancelled ->
            0


ownerSurname : Order -> String
ownerSurname o =
    o.owner
        |> Maybe.map Sample.ownerName
        |> Maybe.map (String.words >> List.reverse >> List.head >> Maybe.withDefault "")
        |> Maybe.withDefault ""


{-| Days from the due date to the day of delivery: negative when the order came
early.
-}
daysLate : Order -> Maybe Int
daysLate o =
    Maybe.map (Date.diffDays o.due) o.delivered


deliveryText : Order -> String
deliveryText o =
    case daysLate o of
        Nothing ->
            ""

        Just 0 ->
            "On time"

        Just days ->
            if days > 0 then
                daysText days ++ " late"

            else
                daysText (abs days) ++ " early"


daysText : Int -> String
daysText n =
    String.fromInt n
        ++ (if n == 1 then
                " day"

            else
                " days"
           )


compareByPriority : Order -> Order -> Basics.Order
compareByPriority a b =
    compare (priorityRank a.priority) (priorityRank b.priority)


orderActions : Order -> List (Menu.Item Msg)
orderActions o =
    [ Menu.item "Open" (Opened o) |> Menu.withIcon Icon.externalLink
    , Menu.item "Edit" (Edit o) |> Menu.withIcon Icon.edit |> disabledUnless (isEditable o.status)
    , Menu.item "Cancel order" (CancelOrder o) |> Menu.withIcon Icon.ban |> disabledUnless (canCancel o)
    , Menu.separator
    , Menu.item "Delete" (Delete o) |> Menu.withIcon Icon.trash |> Menu.danger
    ]


disabledUnless : Bool -> Menu.Item msg -> Menu.Item msg
disabledUnless allowed item =
    if allowed then
        item

    else
        Menu.disabledItem item


orderDetail : Locale -> Order -> Html Msg
orderDetail locale o =
    DescriptionList.view [ DescriptionList.columns 3, DescriptionList.compact, DescriptionList.locale locale ]
        [ DescriptionList.text "Warehouse" (Sample.warehouseName o.warehouse)
        , DescriptionList.text "Created" (Format.date locale o.created)
        , DescriptionList.text "Due" (Format.dateLong locale o.due)
        , DescriptionList.maybe "Delivered" (Maybe.map (Format.dateLong locale) o.delivered)
        , DescriptionList.maybe "Owner" (Maybe.map Sample.ownerName o.owner)
        , DescriptionList.text "Total" (Format.currency locale "$" 2 o.total)
        , DescriptionList.text "Note" o.note |> DescriptionList.fullWidth
        ]



-- COLUMNS


clientColumns : List (Table.Column Order Msg)
clientColumns =
    [ Table.text columnIds.id "Order" (.id >> orderIdText) [ Table.pinned, Table.width 112, Table.filterText, Table.alwaysVisible ]
    , Table.text columnIds.customer "Customer" .customer [ Table.minWidth 190, Table.filterText ]
    , Table.text columnIds.email "Email" .email [ Table.minWidth 240, Table.filterText ]
    , Table.text columnIds.city "City" .city [ Table.width 132, Table.filterSelect ]
    , Table.badge columnIds.status "Status" statusEntry [ Table.width 120, Table.filterOptions statusLabels, Table.sortNumber (.status >> statusRank) ]
    , Table.status columnIds.priority "Priority" priorityEntry [ Table.width 112, Table.filterOptions priorityLabels, Table.sortNumber (.priority >> priorityRank) ]
    , Table.text columnIds.owner "Owner" ownerName [ Table.minWidth 150, Table.filterSelect ]
    , Table.date columnIds.due "Due" .due [ Table.width 124, Table.hint "The day the order is due. Click to sort." ]
    , Table.int columnIds.lines "Lines" .lines [ Table.width 100, Table.filterRange, Table.footerAverage ]
    , Table.float columnIds.total "Total" 2 .total [ Table.width 124, Table.filterRange, Table.footerSum, Table.hint "The order total in US dollars. Click to sort." ]
    , Table.text columnIds.warehouse "Warehouse" (.warehouse >> Api.Types.warehouseIdText) [ Table.width 116, Table.hiddenByDefault, Table.notSearchable ]
    , Table.text columnIds.note "Note" .note [ Table.minWidth 240, Table.hiddenByDefault ]
    ]


serverColumns : List (Table.Column Order Msg)
serverColumns =
    [ Table.text columnIds.id "Order" (.id >> orderIdText) [ Table.width 112, Table.filterText ]
    , Table.text columnIds.customer "Customer" .customer [ Table.minWidth 190, Table.filterText ]
    , Table.text columnIds.city "City" .city [ Table.width 132, Table.filterOptions (List.sort Sample.cities) ]
    , Table.badge columnIds.status "Status" statusEntry [ Table.width 120, Table.filterOptions statusLabels ]
    , Table.text columnIds.owner "Owner" ownerName [ Table.minWidth 150, Table.filterOptions Sample.owners ]
    , Table.date columnIds.due "Due" .due [ Table.width 124 ]
    , Table.float columnIds.total "Total" 2 .total [ Table.width 124, Table.filterRange ]
    ]


{-| One helper for each kind of value. The columns depend on the locale because
the cell of the total and the footer of the id write a currency and a count.
-}
kindColumns : Locale -> List (Table.Column Order Msg)
kindColumns locale =
    [ Table.text columnIds.id "Order" (.id >> orderIdText) [ Table.width 108, Table.cell (.id >> orderIdText >> Text.mono), Table.footer (orderCount locale) ]
    , Table.status columnIds.priority "Priority" priorityEntry [ Table.width 104, Table.sortNumber (.priority >> priorityRank) ]
    , Table.badge columnIds.status "Status" statusEntry [ Table.width 108, Table.sortNumber (.status >> statusRank) ]
    , Table.bool columnIds.overdue "Overdue" isOverdue [ Table.filterSelect ]
    , Table.date columnIds.created "Created" .created [ Table.width 100 ]
    , Table.maybeDate columnIds.delivered "Delivered" .delivered [ Table.width 112 ]
    , Table.int columnIds.lines "Lines" .lines [ Table.width 96, Table.footerSum ]
    , Table.float columnIds.total "Total" 2 .total [ Table.width 108, Table.cell (viewTotal locale), Table.footer (totalFooter locale) ]
    , Table.custom columnIds.progress "Progress" (viewProgress locale) [ Table.width 112, Table.sortNumber (steps >> toFloat), Table.exportAs progressText ]
    , Table.actions columnIds.actions "Actions" orderButtons []
    ]


orderCount : Locale -> List Order -> String
orderCount locale orders =
    let
        n =
            List.length orders
    in
    Format.int locale n ++ " " ++ Format.plural locale n { one = "order", other = "orders" }


viewTotal : Locale -> Order -> Html Msg
viewTotal locale o =
    Text.text (Format.currency locale "$" 2 o.total)


totalFooter : Locale -> List Order -> String
totalFooter locale orders =
    Format.currency locale "$" 2 (List.sum (List.map .total orders))


viewProgress : Locale -> Order -> Html Msg
viewProgress locale o =
    Progress.view
        [ Progress.ariaLabel ("Progress of " ++ orderIdText o.id)
        , Progress.locale locale
        , Progress.outOf (steps o) 4
        , Progress.segments 4
        , Progress.size Theme.Small
        , Progress.tone
            (if o.status == Cancelled then
                Danger

             else
                Primary
            )
        ]


progressText : Order -> String
progressText o =
    String.fromInt (steps o * 25) ++ "%"


orderButtons : Order -> List (Html Msg)
orderButtons o =
    [ Button.iconOnly [ Button.ghost, Button.small, Button.onClick (ColumnAction ("Opened " ++ orderIdText o.id ++ ".")) ] Icon.externalLink ("Open " ++ orderIdText o.id)
    , Button.iconOnly [ Button.ghost, Button.small, Button.onClick (ColumnAction ("A label for " ++ orderIdText o.id ++ " is on its way to the printer.")) ] Icon.print ("Print a label for " ++ orderIdText o.id)
    ]


{-| Columns that sort, search and export in their own way.
-}
sortingColumns : Locale -> List (Table.Column Order Msg)
sortingColumns locale =
    [ Table.text columnIds.id "Order" (.id >> orderIdText) [ Table.width 112, Table.filterText ]
    , Table.text columnIds.owner "Owner" ownerName [ Table.minWidth 140, Table.sortText ownerSurname, Table.hint "Sorted by last name" ]
    , Table.text columnIds.due "Due" (.due >> Format.dateLong locale) [ Table.width 146, Table.sortDate .due, Table.exportAs (.due >> Date.toIso), Table.hint "Shown in full, sorted by date, exported as an ISO date" ]
    , Table.text columnIds.delivery "Delivery" deliveryText [ Table.width 124, Table.alignRight, Table.sortMaybeNumber (daysLate >> Maybe.map toFloat), Table.hint "Early or late compared with the due date. Orders that are not delivered yet sort last." ]
    , Table.status columnIds.priority "Priority" priorityEntry [ Table.width 112, Table.sortWith compareByPriority ]
    , Table.int columnIds.lines "Lines" .lines [ Table.width 100, Table.includeInSearch ]
    , Table.text columnIds.warehouse "Warehouse" (.warehouse >> Api.Types.warehouseIdText) [ Table.width 120, Table.alignCenter, Table.notSearchable ]
    , Table.text columnIds.note "Note" .note [ Table.width 200, Table.wrap, Table.unsortable, Table.notExported ]
    ]


type alias OwnerRow =
    { name : String
    , orders : Int
    , open : Int
    , urgent : Int
    , averageTotal : Float
    }


ownerRows : Remote (List OwnerRow)
ownerRows =
    Sample.owners
        |> List.map
            (\name ->
                let
                    theirs =
                        List.filter (\o -> Maybe.map Sample.ownerName o.owner == Just name) Sample.orders

                    count =
                        List.length theirs
                in
                { name = name
                , orders = count
                , open = List.length (List.filter isOpen theirs)
                , urgent = List.length (List.filter isUrgent theirs)
                , averageTotal = List.sum (List.map .total theirs) / toFloat (max 1 count)
                }
            )
        |> Remote.Loaded


ownerColumns : List (Table.Column OwnerRow Msg)
ownerColumns =
    -- as narrow as the headers allow, so the table fits the card without a
    -- scrollbar for a few pixels of overflow
    [ Table.text columnIds.name "Owner" .name []
    , Table.int columnIds.orders "Orders" .orders [ Table.footerSum ]
    , Table.int columnIds.open "Open" .open [ Table.width 90, Table.footerSum ]
    , Table.int columnIds.urgent "Urgent" .urgent [ Table.footerSum ]
    , Table.float columnIds.averageTotal "Average total" 2 .averageTotal [ Table.width 140 ]
    ]


{-| Few and narrow columns: the examples of empty, loading and failed tables
fit their card, so no scrollbar sits under a message.
-}
smallColumns : List (Table.Column Order Msg)
smallColumns =
    [ Table.text columnIds.id "Order" (.id >> orderIdText) [ Table.minWidth 110 ]
    , Table.text columnIds.city "City" .city [ Table.width 110, Table.filterSelect ]
    , Table.badge columnIds.status "Status" statusEntry [ Table.width 120 ]
    , Table.float columnIds.total "Total" 2 .total [ Table.width 110 ]
    ]


narrowColumns : List (Table.Column Order Msg)
narrowColumns =
    [ Table.text columnIds.customer "Customer" .customer [ Table.pinned, Table.width 200 ]
    , Table.text columnIds.email "Email" .email [ Table.width 240 ]
    , Table.text columnIds.note "Note" .note [ Table.width 260 ]
    , Table.text columnIds.city "City" .city [ Table.width 120 ]
    , Table.status columnIds.status "Status" statusEntry [ Table.width 112 ]
    , Table.status columnIds.priority "Priority" priorityEntry [ Table.width 104 ]
    , Table.text columnIds.owner "Owner" ownerName [ Table.width 150 ]
    , Table.date columnIds.due "Due" .due [ Table.width 120 ]
    , Table.float columnIds.total "Total" 2 .total [ Table.width 100 ]
    , Table.bool columnIds.assigned "Assigned" (\o -> o.owner /= Nothing) [ Table.width 100, Table.filterSelect ]
    , Table.text columnIds.warehouse "Warehouse" (.warehouse >> Api.Types.warehouseIdText) [ Table.width 116 ]
    ]


{-| The first order has values that do not fit any cell.
-}
narrowOrders : Remote (List Order)
narrowOrders =
    case mixedOrders of
        first :: rest ->
            Remote.Loaded
                ({ first
                    | customer = "Aurora Intercontinental Freight and Logistics Holding Company Ltd"
                    , email = "accounts-payable.department@aurora-intercontinental-freight.example"
                    , note = "A very long note that does not fit in the cell: call before delivery, the pallet must stay below 1.8 m, and the invoice goes to the head office as agreed in the \"framework contract\"."
                    , warehouse = Api.Types.warehouseId "RTM"
                 }
                    :: List.take 299 rest
                )

        [] ->
            noOrders


norwegianColumns : List (Table.Column Order Msg)
norwegianColumns =
    [ Table.text columnIds.id "Order" (.id >> orderIdText) [ Table.width 112 ]
    , Table.text columnIds.customer "Customer" .customer [ Table.minWidth 190, Table.filterText ]
    , Table.date columnIds.due "Due" .due [ Table.width 124 ]
    , Table.int columnIds.lines "Lines" .lines [ Table.width 100, Table.filterRange, Table.footerAverage ]
    , Table.float columnIds.total "Total" 2 .total [ Table.width 150, Table.cell (viewTotal Locale.nb), Table.filterRange, Table.footerSum ]
    ]



-- SAVED VIEWS


viewsTableId : String
viewsTableId =
    "saved-views-orders"


savedViewName : SavedView -> String
savedViewName saved =
    case saved of
        AllOrders ->
            "All orders"

        OpenAndUrgent ->
            "Open and urgent"

        LargeOrders ->
            "Large orders"

        DeliveredInRotterdam ->
            "Delivered in Rotterdam"

        ReviewOrders ->
            "Review three orders"


{-| A view is a table state built with the setters, as it could be read from a
saved view or the URL.
-}
applyView : SavedView -> Table.State OrderId
applyView saved =
    let
        fresh =
            Table.init viewsTableId |> Table.setPageSize 10
    in
    case saved of
        AllOrders ->
            fresh

        OpenAndUrgent ->
            Table.setQuery
                { search = ""
                , sort = [ ( columnIds.due, Table.Ascending ) ]
                , filters =
                    [ ( columnIds.priority, Table.OneOf [ "Urgent", "High" ] )
                    , ( columnIds.status, Table.OneOf [ "Draft", "Confirmed", "Picking" ] )
                    ]
                , page = 1
                , pageSize = 10
                }
                fresh

        LargeOrders ->
            fresh
                |> Table.setSort [ ( columnIds.total, Table.Descending ) ]
                |> Table.setFilter columnIds.total (Just (Table.Between (Just 6000) Nothing))
                |> Table.setPage 2
                |> Table.setColumnVisible columnIds.note True
                |> Table.setDensity Theme.Compact

        DeliveredInRotterdam ->
            fresh
                |> Table.setSearch "rotterdam"
                |> Table.setFilter columnIds.status (Just (Table.OneOf [ "Delivered" ]))
                |> Table.setSort [ ( columnIds.due, Table.Descending ) ]

        ReviewOrders ->
            fresh
                |> Table.setExpanded orderRows (orderId "ORD-10001") True
                |> Table.setSelected orderRows [ orderId "ORD-10002", orderId "ORD-10003" ] True


densityText : Theme.Density -> String
densityText density =
    case density of
        Theme.Compact ->
            "Compact"

        Theme.Normal ->
            "Normal"

        Theme.Comfortable ->
            "Comfortable"


columnText : Table.ColumnId -> Table.State OrderId -> String
columnText id table =
    case Table.isColumnVisible id table of
        Just True ->
            "shown"

        Just False ->
            "hidden"

        Nothing ->
            "default"


{-| The state of the table read back with the accessors.
-}
stateBlock : Table.State OrderId -> String
stateBlock table =
    String.join "\n"
        [ queryBlock (Table.query table)
        , "selectedIds = " ++ stringList (List.map orderIdText (Table.selectedIds orderRows table))
        , "expandedIds = " ++ stringList (List.map orderIdText (Table.expandedIds orderRows table))
        , "density = " ++ densityText (Table.density table)
        , "note column = " ++ columnText columnIds.note table
        ]


{-| A list of ids as Elm code, cut short when it is long (all 3,000 orders can
be selected).
-}
stringList : List String -> String
stringList items =
    if List.isEmpty items then
        "[]"

    else
        let
            shown =
                List.take 5 items

            more =
                List.length items - List.length shown
        in
        "[ "
            ++ String.join ", " (List.map (\item -> "\"" ++ item ++ "\"") shown)
            ++ (if more > 0 then
                    ", ... " ++ countText more "more" "more"

                else
                    ""
               )
            ++ " ]"



-- VIEW


view : Locale -> Model -> Html Msg
view locale model =
    Doc.page
        { title = "Tables"
        , description = "The data table for large amounts of data: search, column filters, sorting, selection with bulk actions, row actions, expandable rows, CSV export and pagination, in client mode (all rows in the browser) and server mode (one page at a time). Pagination also works on its own."
        }
        [ Html.Lazy.lazy2 clientSection locale model.client
        , Html.Lazy.lazy2 serverSection locale model.server
        , Html.Lazy.lazy2 columnsSection locale model.columns
        , Html.Lazy.lazy2 viewsSection locale model.views
        , Html.Lazy.lazy2 simpleSection locale model.simple
        , Html.Lazy.lazy2 statesSection locale model.states
        , Html.Lazy.lazy2 narrowSection locale model.narrow
        , Html.Lazy.lazy norwegianSection model.norwegian
        , Html.Lazy.lazy2 paginationSection locale model.pagers
        , Html.Lazy.lazy2 largeSection locale model.large
        ]


largeSection : Locale -> Large.Model -> Html Msg
largeSection locale large =
    Html.map LargeMsg (Large.view locale large)


eventRow : String -> String -> Html Msg
eventRow label text =
    Layout.row [ Layout.gap 2, Layout.alignCenter, Layout.wrap ]
        [ Badge.view [ Badge.tone Info ] label
        , Text.secondary text
        ]



-- VIEW: CLIENT MODE


{-| Rows that are on their way again: the old ones stay, dimmed. The tables in
this showcase keep a flag in their model; an application keeps the state in the
`Remote` itself (`Remote.refresh` when it asks, `Remote.refreshWith` with the answer).
-}
whileRefreshing : Bool -> Remote a -> Remote a
whileRefreshing busy rows =
    if busy then
        Remote.refresh rows

    else
        rows


clientSection : Locale -> Client -> Html Msg
clientSection locale client =
    Doc.section "Client mode: everything on"
        "The table gets all 3,000 orders and searches, filters, sorts and pages them itself, building HTML only for the page on screen. Keyboard: the rows are one tab stop, not fifty. Tab goes to the row that last had focus, and on to its checkbox and its menu button. ArrowUp, ArrowDown, PageUp, PageDown, Home and End move between rows, Enter opens a row, Space selects it, ArrowRight and ArrowLeft show and hide its details, and Shift+F10 (or the menu key) opens its menu. Enter or Space on a column header sorts (with Shift to sort by more than one column). Escape closes filters and menus and clears the search box."
        [ Doc.example
            { title = "Orders"
            , description = Just "Try: search for “rotterdam urgent”, filter on status, city and total, Shift-click a header to add a sort level, select rows and use the bulk actions, export CSV, hide columns, change the density, expand a row. Urgent open orders have a red accent, cancelled orders are disabled."
            , code = Just clientCode
            }
            (Layout.stack [ Layout.gap 3 ]
                [ Switch.view
                    [ Switch.label "Urgent orders only"
                    , Switch.hint "A filter outside the table, applied with Table.rowFilter."
                    , Switch.checked client.urgentOnly
                    , Switch.onCheck UrgentOnlyToggled
                    ]
                , Table.view ClientTable
                    ([ Table.columns clientColumns
                     , Table.rows (whileRefreshing client.refreshing client.orders)
                     , Table.rowId orderRows .id
                     , Table.rowLabel orderLabel
                     , Table.label "Orders"
                     , Table.locale locale
                     , Table.searchable
                     , Table.searchDebounce 120
                     , Table.multiSort
                     , Table.bulkActions
                        [ Button.view [ Button.small, Button.icon Icon.ban, Button.onClick CancelSelected ] "Cancel orders"
                        , Button.view [ Button.small, Button.icon Icon.send, Button.onClick RemindSelected ] "Send reminder"
                        , Button.view [ Button.small, Button.danger, Button.icon Icon.trash, Button.onClick DeleteSelected ] "Delete"
                        ]
                     , Table.rowActions orderActions
                     , Table.onRowClick Opened
                     , Table.expandedRow (orderDetail locale)
                     , Table.rowTone orderTone
                     , Table.rowDisabled isCancelled
                     , Table.toolbarActions [ Button.view [ Button.primary, Button.icon Icon.plus, Button.onClick NewOrder ] "New order" ]
                     , Table.onRefresh Refresh
                     , Table.exportCsv "orders.csv"
                     , Table.columnChooser
                     , Table.densityToggle
                     , Table.maxHeight 560
                     , Table.onResetFilters ExternalFilterCleared
                     ]
                        ++ (if client.urgentOnly then
                                [ Table.rowFilter isUrgent, Table.activeExternalFilters 1 ]

                            else
                                []
                           )
                    )
                    client.table
                , eventRow "Event" client.lastEvent
                , Layout.row [ Layout.gap 2, Layout.alignCenter, Layout.wrap ]
                    [ Text.caption ("Selected: " ++ Format.int locale (List.length (Table.selectedIds orderRows client.table)) ++ " · Query:")
                    , Text.code (queryText (Table.query client.table))
                    ]
                ]
            )
        ]


clientCode : String
clientCode =
    """Table.view TableMsg
    [ Table.columns
        [ Table.text (columnIds.id) "Order" .id [ Table.pinned, Table.filterText, Table.alwaysVisible ]
        , Table.text (columnIds.city) "City" .city [ Table.width 132, Table.filterSelect ]
        , Table.badge (columnIds.status) "Status" statusEntry [ Table.filterOptions statusLabels ]
        , Table.date (columnIds.due) "Due" .due []
        , Table.float (columnIds.total) "Total" 2 .total [ Table.filterRange, Table.footerSum ]
        , Table.text (columnIds.warehouse) "Warehouse" (.warehouse >> Api.Types.warehouseIdText) [ Table.hiddenByDefault ]
        ]
    , Table.rows model.orders -- Remote (List Order), kept in the model; Remote.refresh dims the rows
    , Table.rowId orderRows .id
    , Table.rowLabel (.id >> orderIdText)
    , Table.searchable
    , Table.multiSort
    , Table.bulkActions [ Button.view [ Button.small, Button.onClick DeleteSelected ] "Delete" ]
    , Table.rowActions orderActions -- Order -> List (Menu.Item Msg)
    , Table.onRowClick Open
    , Table.expandedRow orderDetail
    , Table.rowTone orderTone -- Order -> Maybe Tone
    , Table.rowDisabled isCancelled
    , Table.rowFilter isUrgent -- a filter from outside the table
    , Table.activeExternalFilters 1
    , Table.toolbarActions [ newOrderButton ]
    , Table.onRefresh Refresh
    , Table.exportCsv "orders.csv"
    , Table.columnChooser
    , Table.densityToggle
    , Table.maxHeight 560
    ]
    model.table

-- update: DeleteSelected -> remove (Table.selectedIds orderRows model.table),
-- then Table.clearSelection, and Cmd.map TableMsg (Table.focus model.table)"""



-- VIEW: SERVER MODE


serverSection : Locale -> Server -> Html Msg
serverSection locale server =
    let
        status =
            case server.rows of
                Remote.Loading ->
                    "Loading the first page ..."

                Remote.Failed _ ->
                    "The request failed."

                _ ->
                    if server.refreshing then
                        "Fetching a new page: the old rows are dimmed meanwhile."

                    else
                        "Ready. " ++ server.lastEvent
    in
    Doc.section "Server mode"
        "The application gives the table only the page to show and the total; the table records what the user asks for. The application compares Table.query before and after update and fetches when the query changed. The “server” here is a pure function over Showcase.Sample.orders behind Process.sleep (400–900 ms). The search and the text filters wait 350 ms after the last key press before the query changes. “Select all N matching” gives Table.AllMatching, which the server uses together with the query."
        [ Doc.example
            { title = "Page by page from a slow service"
            , description = Just "Page, sort, search and filter: the first load shows skeleton rows, later loads keep the rows dimmed under a progress line. Switch on “Simulate failure” and change the page to see the failure with “Try again”."
            , code = Just serverCode
            }
            (Layout.stack [ Layout.gap 3 ]
                [ Layout.row [ Layout.gap 5, Layout.wrap, Layout.alignCenter ]
                    [ Switch.view
                        [ Switch.label "Simulate failure (HTTP 503)"
                        , Switch.checked server.simulateError
                        , Switch.onCheck SimulateErrorToggled
                        ]
                    , Switch.view
                        [ Switch.label "Slow server (+2.2 s)"
                        , Switch.checked server.slowServer
                        , Switch.onCheck SlowServerToggled
                        ]
                    , Layout.spacer
                    , Text.caption ("Requests: " ++ String.fromInt server.request)
                    ]
                , Table.view ServerTable
                    [ Table.columns serverColumns
                    , Table.server { total = server.total }
                    , Table.rows (whileRefreshing server.refreshing server.rows)
                    , Table.rowId orderRows .id
                    , Table.rowLabel orderLabel
                    , Table.label "Orders from the server"
                    , Table.locale locale
                    , Table.searchable
                    , Table.multiSort
                    , Table.bulkActions [ Button.view [ Button.small, Button.icon Icon.download, Button.onClick ServerExportSelected ] "Export on the server" ]
                    , Table.onRetry ServerRetry
                    , Table.onRefresh ServerRefresh
                    , Table.exportCsv "orders-server.csv"
                    , Table.columnChooser
                    , Table.maxHeight 480
                    ]
                    server.table
                , eventRow "Status" status
                , Layout.stack [ Layout.gap 1 ]
                    [ Text.caption ("The last query sent to the server (#" ++ String.fromInt server.request ++ "):")
                    , Text.codeBlock (queryBlock server.query)
                    ]
                ]
            )
        ]


serverCode : String
serverCode =
    """-- update
TableMsg m ->
    let
        ( table, cmd ) =
            Table.update m model.table

        refetch =
            Table.query table /= Table.query model.table
    in
    ( { model | table = table, fetching = refetch || model.fetching }
    , Cmd.batch
        [ Cmd.map TableMsg cmd
        , if refetch then
            fetchOrders (Table.query table)

          else
            Cmd.none
        ]
    )

-- view
Table.view TableMsg
    [ Table.columns columns -- give filterOptions in server mode
    , Table.server { total = model.total }
    , Table.rows model.page -- Remote (List Order): only this page; Remote.refresh keeps the old rows, dimmed
    , Table.onRetry Retry
    , Table.searchable
    ]
    model.table

-- the backend gets a plain record, Table.Query:
-- { search : String, sort : List ( String, Direction )
-- , filters : List ( String, Filter ), page : Int, pageSize : Int }"""



-- VIEW: COLUMNS


columnsSection : Locale -> Columns -> Html Msg
columnsSection locale columns =
    Doc.section "Columns"
        "A column is data: an id, a title and a function that reads a value from the row. The helpers (text, int, float, date, maybeDate, badge, status, bool, custom and actions) set sensible defaults for each kind of value, and attributes refine them: width and alignment, pinning, hiding, tooltips, your own cell, how the column sorts, whether it is searched and exported, its filter and its footer."
        [ Doc.example
            { title = "One helper for each kind of value"
            , description = Just "Order is text drawn with your own cell and counted in the footer, Priority a status dot, Status a badge, Overdue a yes / no column, Created a date, Delivered a date that may be missing, Lines an integer, Total a decimal number drawn as money, Progress your own content with a sort and an export value (see the CSV file), and the last column holds inline buttons that never trigger a row click and are left out of the CSV file."
            , code = Just kindsCode
            }
            (Layout.stack [ Layout.gap 3 ]
                [ Table.view KindsTable
                    [ Table.columns (kindColumns locale)
                    , Table.rows someOrders
                    , Table.rowId orderRows .id
                    , Table.rowLabel (.id >> orderIdText)
                    , Table.label "Order columns"
                    , Table.locale locale
                    , Table.exportCsv "orders-kinds.csv"
                    , Table.pageSizes [ 10, 25, 50 ]
                    ]
                    columns.kinds
                , eventRow "Event" columns.lastEvent
                ]
            )
        , Doc.example
            { title = "Sorting, search and export"
            , description = Just "Sort by the headers, type a search such as “berg” or “18”, open the export menu. Each column has something set that differs from the default; the list under the table explains what."
            , code = Just sortingCode
            }
            (Layout.stack [ Layout.gap 4 ]
                [ Table.view SortingTable
                    [ Table.columns (sortingColumns locale)
                    , Table.rows someOrders
                    , Table.rowId orderRows .id
                    , Table.rowLabel (.id >> orderIdText)
                    , Table.label "Order sorting and export"
                    , Table.locale locale
                    , Table.searchable
                    , Table.searchPlaceholder "Search orders, owners, notes ..."
                    , Table.exportCsv "orders-columns.csv"
                    , Table.csvSeparator ';'
                    , Table.pageSizes [ 10, 25, 50 ]
                    ]
                    columns.sorting
                , sortingNotes
                ]
            )
        ]


sortingNotes : Html Msg
sortingNotes =
    let
        note title attributes explanation =
            DescriptionList.html title
                (Text.paragraphWith
                    [ Text.code attributes
                    , Text.text " "
                    , Text.secondary explanation
                    ]
                )
    in
    DescriptionList.view [ DescriptionList.labelBeside, DescriptionList.labelWidth 110, DescriptionList.bordered, DescriptionList.compact ]
        [ note "Owner" "sortText" "Sorts by last name, not by the first name that is shown. Orders without an owner come last."
        , note "Due" "sortDate, exportAs" "Shown as “20 October 2026”, sorted by date, exported as an ISO date."
        , note "Delivery" "sortMaybeNumber, alignRight" "Sorts by days early or late. Orders that are not delivered yet are a dash and come last, whichever way you sort."
        , note "Priority" "sortWith" "Sorts with your own comparison, written for the ascending order."
        , note "Lines" "includeInSearch" "Numbers are not searched by default; this one is."
        , note "Warehouse" "notSearchable, alignCenter" "The search box skips it."
        , note "Note" "wrap, unsortable, notExported" "Long text wraps instead of being cut, the header is not a button, and the column is left out of the CSV file."
        , note "Table" "searchPlaceholder, csvSeparator" "Your own placeholder, and semicolons in the CSV file."
        ]


kindsCode : String
kindsCode =
    """Table.view TableMsg
    [ Table.columns
        [ Table.text (columnIds.id) "Order" .id [ Table.cell viewOrderNumber, Table.footer orderCount ]
        , Table.status (columnIds.priority) "Priority" priorityEntry []
        , Table.badge (columnIds.status) "Status" statusEntry []
        , Table.bool (columnIds.overdue) "Overdue" isOverdue [ Table.filterSelect ]
        , Table.date (columnIds.created) "Created" .created []
        , Table.maybeDate (columnIds.delivered) "Delivered" .delivered []
        , Table.int (columnIds.lines) "Lines" .lines [ Table.footerSum ]
        , Table.float (columnIds.total) "Total" 2 .total [ Table.cell viewMoney, Table.footer moneyFooter ]
        , Table.custom (columnIds.progress) "Progress" viewProgress
            [ Table.width 130, Table.sortNumber progressSteps, Table.exportAs progressText ]
        , Table.actions (columnIds.actions) "Actions" orderButtons []
        ]
    , Table.rows model.orders
    , Table.exportCsv "orders.csv"
    ]
    model.table

orderButtons : Order -> List (Html Msg)
orderButtons order =
    [ Button.iconOnly [ Button.ghost, Button.small, Button.onClick (OpenOrder order.id) ]
        Icon.externalLink
        "Open order"
    ]"""


sortingCode : String
sortingCode =
    """Table.view TableMsg
    [ Table.columns
        [ Table.text (columnIds.owner) "Owner" ownerName [ Table.sortText ownerSurname ]
        , Table.text (columnIds.due) "Due" dueLong
            [ Table.sortDate .due, Table.exportAs dueIso ]
        , Table.text (columnIds.delivery) "Delivery" deliveryText
            [ Table.alignRight, Table.sortMaybeNumber daysLate ]
        , Table.status (columnIds.priority) "Priority" priorityEntry
            [ Table.sortWith compareByPriority ]
        , Table.int (columnIds.lines) "Lines" .lines [ Table.includeInSearch ]
        , Table.text (columnIds.warehouse) "Warehouse" (.warehouse >> Api.Types.warehouseIdText)
            [ Table.alignCenter, Table.notSearchable ]
        , Table.text (columnIds.note) "Note" .note
            [ Table.wrap, Table.unsortable, Table.notExported ]
        ]
    , Table.rows model.orders
    , Table.searchable
    , Table.searchPlaceholder "Search orders, owners, notes ..."
    , Table.exportCsv "orders.csv"
    , Table.csvSeparator ';'
    ]
    model.table"""



-- VIEW: SAVED VIEWS


viewsSection : Locale -> Views -> Html Msg
viewsSection locale views =
    Doc.section "State: read it and restore it"
        "Everything the user can change lives in the table's State: sort, page, page size, search, filters, selection, expanded rows, hidden columns and density. Read it with the accessors, and set it with the setters to restore a view, one the user saved or one taken from the URL. There are no out-messages: compare the state before and after update to react to a change."
        [ Doc.example
            { title = "Saved views"
            , description = Just "Each view button builds a state with the setters and puts it in the model. The search box, the filter popovers, the column chooser and the density buttons show it at once, and the last view opens one order and selects two others. The two buttons below change the state the user has now: they keep the sort, the density and the selection. The block under the table is the state read back with the accessors."
            , code = Just viewsCode
            }
            (Layout.stack [ Layout.gap 3 ]
                [ Layout.row [ Layout.gap 2, Layout.wrap, Layout.alignCenter ]
                    [ Text.caption "Views:"
                    , Button.view [ Button.small, Button.onClick (ViewApplied AllOrders) ] (savedViewName AllOrders)
                    , Button.view [ Button.small, Button.onClick (ViewApplied OpenAndUrgent) ] (savedViewName OpenAndUrgent)
                    , Button.view [ Button.small, Button.onClick (ViewApplied LargeOrders) ] (savedViewName LargeOrders)
                    , Button.view [ Button.small, Button.onClick (ViewApplied DeliveredInRotterdam) ] (savedViewName DeliveredInRotterdam)
                    , Button.view [ Button.small, Button.onClick (ViewApplied ReviewOrders) ] (savedViewName ReviewOrders)
                    , Layout.spacer
                    , Text.caption ("Last applied: " ++ views.applied)
                    ]
                , Layout.row [ Layout.gap 2, Layout.wrap, Layout.alignCenter ]
                    [ Text.caption "On the live state:"
                    , Button.view [ Button.small, Button.ghost, Button.onClick ViewFiltersCleared ] "Clear search and filters"
                    , Button.view [ Button.small, Button.ghost, Button.onClick ViewPageThree ] "Go to page 3"
                    ]
                , Table.view ViewsTable
                    [ Table.columns clientColumns
                    , Table.rows allOrders
                    , Table.rowId orderRows .id
                    , Table.rowLabel orderLabel
                    , Table.label "Orders with saved views"
                    , Table.locale locale
                    , Table.searchable
                    , Table.selectable
                    , Table.expandedRow (orderDetail locale)
                    , Table.columnChooser
                    , Table.densityToggle
                    ]
                    views.table
                , Text.codeBlock (stateBlock views.table)
                ]
            )
        ]


viewsCode : String
viewsCode =
    """-- a view is a state, built with the setters
largeOrders : Table.State OrderId
largeOrders =
    Table.init "orders"
        |> Table.setSort [ ( columnIds.total, Table.Descending ) ]
        |> Table.setFilter (columnIds.total) (Just (Table.Between (Just 6000) Nothing))
        |> Table.setPage 2
        |> Table.setColumnVisible (columnIds.note) True
        |> Table.setDensity Theme.Compact

-- or all at once, from a saved query or the URL
openAndUrgent : Table.State OrderId
openAndUrgent =
    Table.setQuery
        { search = ""
        , sort = [ ( columnIds.due, Table.Ascending ) ]
        , filters = [ ( columnIds.priority, Table.OneOf [ "Urgent", "High" ] ) ]
        , page = 1
        , pageSize = 10
        }
        (Table.init "orders")

-- rows can be opened and selected too
reviewOrders : Table.State OrderId
reviewOrders =
    Table.init "orders"
        |> Table.setExpanded orderRows (orderId "ORD-10001") True
        |> Table.setSelected orderRows [ (orderId "ORD-10002"), (orderId "ORD-10003") ] True

-- change the state the user has now
Table.clearFilters model.table -- the search and the column filters
Table.setPage 3 model.table

-- and read it back
Table.query model.table -- search, sort, filters, page and page size
Table.selectedIds orderRows model.table
Table.isSelected orderRows (orderId "ORD-10002") model.table
Table.expandedIds orderRows model.table
Table.isExpanded orderRows (orderId "ORD-10001") model.table
Table.isColumnVisible (columnIds.note) model.table -- Maybe Bool
Table.density model.table"""



-- VIEW: SIMPLE TABLES


simpleSection : Locale -> Simple -> Html Msg
simpleSection locale simple =
    Doc.section "Simple tables"
        "A short table without toolbar or paging: columns, rows and sorting. Numbers are right-aligned with tabular digits. The totals in the bottom row are computed by the table."
        [ Doc.example
            { title = "Owners"
            , description = Just "Sorted by the number of orders, descending. Click a column header to sort; a third click removes the sort."
            , code = Just ownersCode
            }
            (Table.view OwnersTable
                [ Table.columns ownerColumns
                , Table.rows ownerRows
                , Table.rowId Ids.string .name
                , Table.label "Owners"
                , Table.locale locale
                , Table.unpaged
                , Table.zebra
                ]
                simple.owners
            )
        , Doc.example
            { title = "Selection without a toolbar"
            , description = Just "A table with only checkboxes. The band above the table is always there and says “No rows selected”, so the rows do not jump down under the pointer when the first row is selected; then it is replaced by the bar with the bulk actions."
            , code = Just pickingCode
            }
            (Layout.stack [ Layout.gap 3 ]
                [ Table.view PickingTable
                    [ Table.columns ownerColumns
                    , Table.rows ownerRows
                    , Table.rowId Ids.string .name
                    , Table.label "Owners with selection"
                    , Table.locale locale
                    , Table.unpaged
                    , Table.bulkActions [ Button.view [ Button.small, Button.icon Icon.send, Button.onClick PickingNotified ] "Send summary" ]
                    ]
                    simple.picking
                , eventRow "Event" simple.lastEvent
                ]
            )
        ]


ownersCode : String
ownersCode =
    """Table.view TableMsg
    [ Table.columns
        [ Table.text (columnIds.name) "Owner" .name []
        , Table.int (columnIds.orders) "Orders" .orders [ Table.footerSum ]
        , Table.float (columnIds.averageTotal) "Average total" 2 .averageTotal []
        ]
    , Table.rows model.rows
    , Table.rowId Ids.string .name
    , Table.unpaged
    , Table.zebra
    ]
    model.table"""


pickingCode : String
pickingCode =
    """Table.view TableMsg
    [ Table.columns columns
    , Table.rows model.owners
    , Table.rowId Ids.string .name
    , Table.unpaged
    , Table.bulkActions [ Button.view [ Button.small, Button.onClick SendSummary ] "Send summary" ]
    ]
    model.table

-- after an action that ends the selection (and takes the button that was pressed with it):
( { model | table = Table.clearSelection model.table }
, Cmd.map TableMsg (Table.focus model.table)
)"""



-- VIEW: STATES


statesSection : Locale -> States -> Html Msg
statesSection locale states =
    let
        lifecycle =
            states.lifecycle
    in
    Doc.section "Empty states, loading and failure"
        "No data and no matches are different states: with no matches the user gets “Clear search and filters”. The header is always there, the skeleton rows are as tall as real rows, and a failure is shown inside the table with “Try again” when that can help."
        [ Doc.example
            { title = "No data"
            , description = Just "Table.rows (Remote.Loaded []) with the application's own empty state."
            , code = Just emptyCode
            }
            (Layout.stack [ Layout.gap 3 ]
                [ Table.view EmptyTable
                    [ Table.columns smallColumns
                    , Table.rows noOrders
                    , Table.rowId orderRows .id
                    , Table.label "No orders"
                    , Table.locale locale
                    , Table.searchable
                    , Table.emptyState
                        [ EmptyState.title "No orders yet"
                        , EmptyState.description "Orders you create show up here."
                        , EmptyState.actions [ Button.view [ Button.primary, Button.icon Icon.plus, Button.onClick CreateOrder ] "Create order" ]
                        ]
                    ]
                    states.empty
                , eventRow "Event" states.lastEvent
                ]
            )
        , Doc.example
            { title = "No matches"
            , description = Just "3,000 rows, but the search “Zyxwv” matches none. “Clear search and filters” empties the search box and the filters."
            , code = Just noMatchCode
            }
            (Table.view NoMatchTable
                [ Table.columns smallColumns
                , Table.rows allOrders
                , Table.rowId orderRows .id
                , Table.label "Orders without matches"
                , Table.locale locale
                , Table.searchable
                , Table.maxHeight 360
                ]
                states.noMatch
            )
        , Doc.example
            { title = "Loading"
            , description = Just "Remote.Loading: skeleton rows with the right number of columns under the header, and aria-busy on the table."
            , code = Just loadingCode
            }
            (Table.view LoadingTable
                [ Table.columns smallColumns
                , Table.rows Remote.Loading
                , Table.rowId orderRows .id
                , Table.label "Orders that are loading"
                , Table.locale locale
                , Table.searchable
                , Table.selectable
                ]
                states.loading
            )
        , Doc.example
            { title = "Failed, and trying again"
            , description = Just ("Remote.Failed with Table.onRetry (and onRefresh). “Try again” is only offered when trying again could help: choose “No access” to see it go. An attempt takes a second and fails again until the service is back. Attempts so far: " ++ String.fromInt lifecycle.attempts ++ ".")
            , code = Just failedCode
            }
            (Layout.stack [ Layout.gap 3 ]
                [ Layout.row [ Layout.gap 5, Layout.wrap, Layout.alignCenter ]
                    [ SegmentedControl.view
                        [ SegmentedControl.label "Kind of failure"
                        , SegmentedControl.labelHidden
                        , SegmentedControl.options
                            [ SegmentedControl.option "network" "No connection"
                            , SegmentedControl.option "server" "Server error"
                            , SegmentedControl.option "forbidden" "No access"
                            ]
                        , SegmentedControl.selected (failureKindValue lifecycle.kind)
                        , SegmentedControl.onChange FailureKindChosen
                        ]
                    , Switch.view
                        [ Switch.label "The service is back"
                        , Switch.checked lifecycle.serviceBack
                        , Switch.onCheck ServiceBackToggled
                        ]
                    ]
                , Table.view FailedTable
                    [ Table.columns smallColumns
                    , Table.rows lifecycle.rows
                    , Table.rowId orderRows .id
                    , Table.label "Orders that failed to load"
                    , Table.locale locale
                    , Table.onRetry FailedRetry
                    , Table.onRefresh FailedRetry
                    , Table.unpaged
                    ]
                    states.failed
                ]
            )
        ]


emptyCode : String
emptyCode =
    """Table.view TableMsg
    [ Table.columns columns
    , Table.rows (Remote.Loaded [])
    , Table.emptyState
        [ EmptyState.title "No orders yet"
        , EmptyState.description "Orders you create show up here."
        , EmptyState.actions [ Button.view [ Button.primary, Button.onClick CreateOrder ] "Create order" ]
        ]
    ]
    model.table"""


noMatchCode : String
noMatchCode =
    """-- in init: all the rows, and a search that matches none of them
{ orders = Remote.Loaded allOrders
, table = Table.init "orders" |> Table.setSearch "Zyxwv"
}"""


loadingCode : String
loadingCode =
    """Table.view TableMsg
    [ Table.columns columns
    , Table.rows Remote.Loading
    ]
    model.table"""


failedCode : String
failedCode =
    """Table.view TableMsg
    [ Table.columns columns
    , Table.rows (Remote.Failed problem) -- Remote.problem Remote.network
    , Table.onRetry Retry -- the button only shows for problems worth retrying
    , Table.onRefresh Retry
    ]
    model.table"""



-- VIEW: NARROW CONTAINER


narrowSection : Locale -> Table.State OrderId -> Html Msg
narrowSection locale table =
    Doc.section "Narrow and long"
        "Many columns in a narrow container: the table scrolls sideways with a discreet shadow at the edge, the first column stays in place, and the header stays put while the rows scroll. Long values are cut with … and shown in full as a tooltip."
        [ Doc.example
            { title = "11 columns in 640 px, compact density, 300 rows"
            , description = Just "The first row has very long values. Scroll sideways and down."
            , code = Just narrowCode
            }
            (Layout.container [ Layout.maxWidth 640, Layout.alignStart ]
                [ Table.view NarrowTable
                    [ Table.columns narrowColumns
                    , Table.rows narrowOrders
                    , Table.rowId orderRows .id
                    , Table.rowLabel orderLabel
                    , Table.label "Orders in a narrow container"
                    , Table.locale locale
                    , Table.searchable
                    , Table.densityToggle
                    , Table.exportCsv "orders-narrow.csv"
                    , Table.maxHeight 320
                    , Table.pageSizes [ 25, 50, 100 ]
                    ]
                    table
                ]
            )
        ]


narrowCode : String
narrowCode =
    """Table.view TableMsg
    [ Table.columns
        [ Table.text (columnIds.customer) "Customer" .customer [ Table.pinned, Table.width 200 ]
        , Table.text (columnIds.email) "Email" .email [ Table.width 240 ]
        , Table.text (columnIds.note) "Note" .note [ Table.width 260 ]
        , Table.date (columnIds.due) "Due" .due [ Table.width 120 ]
        -- ... more columns, each with a width
        ]
    , Table.rows model.orders
    , Table.densityToggle
    , Table.maxHeight 320
    , Table.pageSizes [ 25, 50, 100 ]
    ]
    (Table.init "orders" |> Table.setDensity Theme.Compact |> Table.setPageSize 50)

-- in a parent that has a height of its own (a panel, a drawer),
-- Table.fillHeight makes the table fill it, instead of Table.maxHeight"""



-- VIEW: LOCALE


norwegianSection : Table.State OrderId -> Html Msg
norwegianSection table =
    Doc.section "Locale"
        "The built-in text (the search placeholder, the filter popovers, the footer, what screen readers hear), the number and date formats, the alphabetical order of text and the CSV separator follow the table's locale. The titles of your columns, and everything else you pass in, are your own text."
        [ Doc.example
            { title = "The same table in Norwegian"
            , description = Just "Table.locale Locale.nb, whatever the language of the page: the search box, the filters, the footer and the pagination speak Norwegian, numbers get a decimal comma and a space between thousands (1 234,50 $), dates are written 20.10.2026, and the CSV file uses semicolons."
            , code = Just norwegianCode
            }
            (Table.view NorwegianTable
                [ Table.columns norwegianColumns
                , Table.rows allOrders
                , Table.rowId orderRows .id
                , Table.label "Orders in Norwegian"
                , Table.locale Locale.nb
                , Table.searchable
                , Table.exportCsv "orders-nb.csv"
                , Table.maxHeight 420
                ]
                table
            )
        ]


norwegianCode : String
norwegianCode =
    """Table.view TableMsg
    [ Table.columns columns
    , Table.rows model.orders
    , Table.locale Locale.nb -- text, formats, sort order and CSV separator
    , Table.exportCsv "orders.csv"
    ]
    model.table"""



-- VIEW: PAGINATION


paginationSection : Locale -> Pagers -> Html Msg
paginationSection locale pagers =
    Doc.section "Pagination"
        "Klar.Pagination is used by the table, but works on its own too. It is controlled: the application owns the page and the page size and changes them in onPage and onPageSize. The number of buttons is always the same, so nothing jumps while paging. Keyboard: every control is an ordinary button; type a page number in “Go to page” and press Enter."
        [ Doc.example
            { title = "Full"
            , description = Just "The range, rows per page, first / previous / page numbers / next / last, and go to page. The block under it is the same arithmetic as plain functions, for fetching and showing pages yourself."
            , code = Just fullPagerCode
            }
            (Layout.stack [ Layout.gap 3 ]
                [ Pagination.view
                    [ Pagination.id "pager-full"
                    , Pagination.label "Order pages"
                    , Pagination.onPage FullPage
                    , Pagination.onPageSize FullPageSize
                    , Pagination.jumpToPage
                    , Pagination.locale locale
                    ]
                    { page = pagers.full.page, pageSize = pagers.full.pageSize, total = 3000 }
                , Text.codeBlock (pageMath { page = pagers.full.page, pageSize = pagers.full.pageSize, total = 3000 })
                ]
            )
        , Doc.example
            { title = "Compact"
            , description = Just "For cards and side panels."
            , code = Just "Pagination.view [ Pagination.compact, Pagination.onPage PageChanged ] { page = model.page, pageSize = 25, total = 3000 }"
            }
            (Pagination.view
                [ Pagination.id "pager-compact"
                , Pagination.label "Compact order pages"
                , Pagination.compact
                , Pagination.onPage CompactPage
                , Pagination.locale locale
                ]
                { page = pagers.compact, pageSize = 25, total = 3000 }
            )
        , Doc.example
            { title = "Few pages and very many pages"
            , description = Just "42 rows make 5 pages without an ellipsis. 1,000,000 rows make 40,000 pages, with two neighbors on each side of the current page."
            , code = Just "Pagination.view [ Pagination.siblings 2, Pagination.onPage PageChanged, Pagination.jumpToPage ] { page = model.page, pageSize = 25, total = 1000000 }"
            }
            (Layout.stack [ Layout.gap 4 ]
                [ Pagination.view
                    [ Pagination.id "pager-few"
                    , Pagination.label "Few order pages"
                    , Pagination.onPage FewPage
                    , Pagination.locale locale
                    ]
                    { page = pagers.few, pageSize = 10, total = 42 }
                , Pagination.view
                    [ Pagination.id "pager-many"
                    , Pagination.label "Many order pages"
                    , Pagination.onPage ManyPage
                    , Pagination.siblings 2
                    , Pagination.jumpToPage
                    , Pagination.locale locale
                    ]
                    { page = pagers.many, pageSize = 25, total = 1000000 }
                ]
            )
        , Doc.example
            { title = "Empty and disabled"
            , description = Just "No rows, and disabled with a message of its own in place of the range while a page loads."
            , code = Just "Pagination.view [ Pagination.disabled True, Pagination.summary [ Text.text \"Loading orders ...\" ] ] { page = 3, pageSize = 25, total = 3000 }"
            }
            (Layout.stack [ Layout.gap 4 ]
                [ Pagination.view
                    [ Pagination.id "pager-empty"
                    , Pagination.label "Empty order pages"
                    , Pagination.onPage (\_ -> NoOp)
                    , Pagination.onPageSize (\_ -> NoOp)
                    , Pagination.locale locale
                    ]
                    { page = 1, pageSize = 25, total = 0 }
                , Pagination.view
                    [ Pagination.id "pager-disabled"
                    , Pagination.label "Disabled order pages"
                    , Pagination.disabled True
                    , Pagination.summary [ Text.text "Loading orders ..." ]
                    , Pagination.onPage (\_ -> NoOp)
                    , Pagination.onPageSize (\_ -> NoOp)
                    , Pagination.jumpToPage
                    , Pagination.locale locale
                    ]
                    { page = 3, pageSize = 25, total = 3000 }
                ]
            )
        , Layout.stack [ Layout.gap 2 ]
            [ Text.subheading "Attributes"
            , Doc.props
                [ { name = "onPage", type_ = "Int -> msg", description = "The page the user chose, counted from 1 and always valid. Sent by the page buttons, first / previous / next / last and “Go to page”." }
                , { name = "onPageSize", type_ = "Int -> msg", description = "Shows “Rows per page” and sends the new size. Set the page again too, usually back to 1." }
                , { name = "pageSizes", type_ = "List Int", description = "The sizes on offer. The default is 10, 25, 50 and 100; the current size is always there." }
                , { name = "compact", type_ = "Attribute msg", description = "Only the range and previous / next." }
                , { name = "jumpToPage", type_ = "Attribute msg", description = "Adds “Go to page”: type a number and press Enter." }
                , { name = "siblings", type_ = "Int", description = "How many page numbers to show on each side of the current page. The default is 1." }
                , { name = "summary", type_ = "List (Html msg)", description = "Replaces the range, for example with “Loading ...”. An empty list shows nothing." }
                , { name = "disabled", type_ = "Bool", description = "Disables every control, for example while a page loads." }
                , { name = "id", type_ = "String", description = "The DOM id of the navigation. Give every pagination on a page its own." }
                , { name = "label", type_ = "String", description = "The accessible name of the navigation, for pages with more than one." }
                , { name = "locale", type_ = "Locale", description = "The language of the built-in text. The default is English." }
                ]
            ]
        ]


fullPagerCode : String
fullPagerCode =
    """Pagination.view
    [ Pagination.id "order-pages"
    , Pagination.label "Order pages"
    , Pagination.onPage PageChanged
    , Pagination.onPageSize PageSizeChanged
    , Pagination.jumpToPage
    ]
    { page = model.page, pageSize = model.pageSize, total = 3000 }

-- the arithmetic behind it
Pagination.pageCount 25 3000 -- 120
Pagination.range { page = 6, pageSize = 25, total = 3000 } -- ( 126, 150 )
Pagination.pageItems { siblings = 1, page = 6, pageCount = 120 }"""


pageMath : { page : Int, pageSize : Int, total : Int } -> String
pageMath state =
    let
        count =
            Pagination.pageCount state.pageSize state.total

        current =
            clamp 1 count state.page

        slots =
            Pagination.pageItems { siblings = 1, page = current, pageCount = count }
    in
    String.join "\n"
        [ "Pagination.pageCount " ++ String.fromInt state.pageSize ++ " " ++ String.fromInt state.total ++ " --> " ++ String.fromInt count
        , "Pagination.range { page = " ++ String.fromInt current ++ ", pageSize = " ++ String.fromInt state.pageSize ++ ", total = " ++ String.fromInt state.total ++ " } --> " ++ rangeText (Pagination.range { state | page = current })
        , "Pagination.pageItems { siblings = 1, page = " ++ String.fromInt current ++ ", pageCount = " ++ String.fromInt count ++ " }"
        , "    --> [ " ++ String.join ", " (List.map slotText slots) ++ " ]"
        ]


rangeText : ( Int, Int ) -> String
rangeText ( first, last ) =
    "( " ++ String.fromInt first ++ ", " ++ String.fromInt last ++ " )"


slotText : Pagination.Item -> String
slotText item =
    case item of
        Pagination.Page n ->
            "Page " ++ String.fromInt n

        Pagination.Ellipsis ->
            "Ellipsis"



-- QUERY AS TEXT


queryText : Table.Query -> String
queryText q =
    String.join ", "
        (List.filterMap identity
            [ if String.isEmpty q.search then
                Nothing

              else
                Just ("search “" ++ q.search ++ "”")
            , if List.isEmpty q.sort then
                Nothing

              else
                Just ("sort " ++ String.join " > " (List.map sortLevelText q.sort))
            , if List.isEmpty q.filters then
                Nothing

              else
                Just (countText (List.length q.filters) "filter" "filters")
            , Just ("page " ++ String.fromInt q.page)
            , Just (String.fromInt q.pageSize ++ " per page")
            ]
        )


queryBlock : Table.Query -> String
queryBlock q =
    let
        list items =
            if List.isEmpty items then
                "[]"

            else
                "[ " ++ String.join ", " items ++ " ]"
    in
    String.join "\n"
        [ "{ search = \"" ++ q.search ++ "\""
        , ", sort = " ++ list (List.map (\( column, direction ) -> "( \"" ++ Table.columnName column ++ "\", " ++ directionText direction ++ " )") q.sort)
        , ", filters = " ++ list (List.map filterEntryText q.filters)
        , ", page = " ++ String.fromInt q.page
        , ", pageSize = " ++ String.fromInt q.pageSize
        , "}"
        ]


sortLevelText : ( Table.ColumnId, Table.Direction ) -> String
sortLevelText ( column, direction ) =
    Table.columnName column
        ++ (case direction of
                Table.Ascending ->
                    " ↑"

                Table.Descending ->
                    " ↓"
           )


directionText : Table.Direction -> String
directionText direction =
    case direction of
        Table.Ascending ->
            "Ascending"

        Table.Descending ->
            "Descending"


filterEntryText : ( Table.ColumnId, Table.Filter ) -> String
filterEntryText ( column, filter ) =
    "( \""
        ++ Table.columnName column
        ++ "\", "
        ++ (case filter of
                Table.Contains text ->
                    "Contains \"" ++ text ++ "\""

                Table.OneOf values ->
                    "OneOf [ " ++ String.join ", " (List.map (\v -> "\"" ++ v ++ "\"") values) ++ " ]"

                Table.Between low high ->
                    "Between " ++ maybeNumber low ++ " " ++ maybeNumber high
           )
        ++ " )"


maybeNumber : Maybe Float -> String
maybeNumber value =
    case value of
        Just n ->
            "(Just " ++ String.fromFloat n ++ ")"

        Nothing ->
            "Nothing"
