module Main exposing (main)

import Api
import Array exposing (Array)
import Backend.Db as Db exposing (Db)
import Browser
import Domain
    exposing
        ( Category(..)
        , Figures
        , MovementKind(..)
        , MovementRow
        , NodeId(..)
        , Overview
        , Period
        , Scope(..)
        , Transfer
        , TransferStatus(..)
        , TreeRegion
        , TreeWarehouse
        , TreeZone
        , WarehouseStatus(..)
        )
import Event
import Html exposing (Html)
import Html.Attributes
import Ids
import Klar
import Klar.Alert as Alert
import Klar.AppShell as AppShell
import Klar.Badge as Badge
import Klar.Button as Button
import Klar.Card as Card
import Klar.Chart as Chart
import Klar.Date as Date exposing (Date)
import Klar.DateRangePicker as DateRangePicker
import Klar.DescriptionList as DescriptionList
import Klar.EmptyState as EmptyState
import Klar.ErrorState as ErrorState
import Klar.Format as Format
import Klar.Icon as Icon
import Klar.JsonViewer as JsonViewer
import Klar.Layout as Layout
import Klar.ListItem as ListItem
import Klar.Locale as Locale
import Klar.PageHeader as PageHeader
import Klar.Remote as Remote exposing (Problem, Remote)
import Klar.Search as Search
import Klar.SearchInput as SearchInput
import Klar.Select as Select
import Klar.Skeleton as Skeleton
import Klar.Stat as Stat
import Klar.Switch as Switch
import Klar.Text as Text
import Klar.Tabs as Tabs
import Klar.Table as Table
import Klar.Theme as Theme exposing (Size(..), Tone(..))
import Klar.Timeline as Timeline
import Klar.Toast as Toast
import Klar.Tree as Tree
import Klar.VirtualList as VirtualList
import Task
import Time



-- MODEL


{-| KLAR GAP: Remote has no "stale" state (data that is there but whose refresh failed, or
is being refreshed); only Table has `refreshing`. This Panel, `startLoading`, `receive`,
`freshness`, `staleAlert` and `failedPanels` are the page's own stale-data model.

A piece of the page that has its own request: the data, when it arrived, and
what happened to the last refresh.
-}
type alias Panel a =
    { data : Remote a
    , loadedAt : Maybe Time.Posix
    , refreshing : Bool
    , refreshFailed : Maybe Problem
    }


type alias Model =
    { zone : Time.Zone
    , now : Time.Posix
    , today : Maybe Date
    , db : Maybe Db
    , net : Api.Net
    , compact : Bool
    , shell : { collapsed : Bool, drawerOpen : Bool }
    , tree : Tree.State NodeId
    , treeData : Remote (List TreeRegion)
    , period : DateRangePicker.State
    , overview : Panel Overview
    , transfers : Panel (List Transfer)
    , movements : Panel (Array MovementRow)
    , tableRows : Remote (List MovementRow)
    , transferLimit : Int
    , tabs : Tabs.State
    , table : Table.State Int
    , haystack : Array Search.Prepared
    , visible : Array MovementRow
    , search : SearchInput.State
    , kind : Select.State MovementKind
    , list : VirtualList.State
    , selected : Maybe MovementRow
    , viewer : JsonViewer.State
    , toasts : Toast.State Msg
    , treeTicket : Int
    , overviewTicket : Int
    , transfersTicket : Int
    , movementsTicket : Int
    }


type Msg
    = GotClock ( Time.Zone, Time.Posix )
    | Tick Time.Posix
    | TreeMsg Tree.Msg
    | ShowAll
    | ReloadTree
    | GotTree Int (Result Problem (List TreeRegion))
    | PeriodMsg DateRangePicker.Msg
    | GotOverview Int Bool (Result Problem Overview)
    | GotTransfers Int Bool (Result Problem (List Transfer))
    | GotMovements Int Bool (Result Problem (Array MovementRow))
    | RetryOverview
    | RetryTransfers
    | LoadMoreTransfers
    | RetryMovements
    | RefreshAll
    | SearchMsg SearchInput.Msg
    | KindMsg (Select.Msg MovementKind)
    | ListMsg VirtualList.Msg
    | TabsMsg Tabs.Msg
    | TableMsg Table.Msg
    | RowChosen MovementRow
    | ViewerMsg JsonViewer.Msg
    | CompactToggled Bool
    | SlowToggled Bool
    | FailingToggled Bool
    | ToastMsg Toast.Msg
    | ToggleSidebar
    | ToggleDrawer
    | CloseDrawer
    | SkipToContent
    | NoOp


emptyPanel : Panel a
emptyPanel =
    { data = Remote.Loading, loadedAt = Nothing, refreshing = False, refreshFailed = Nothing }


main : Program () Model Msg
main =
    Browser.document
        { init = init
        , update = update
        , view = view
        , subscriptions = \_ -> Time.every 60000 Tick
        }


init : () -> ( Model, Cmd Msg )
init _ =
    ( { zone = Time.utc
      , now = Time.millisToPosix 0
      , today = Nothing
      , db = Nothing
      , net = { slow = False, failing = False }
      , compact = False
      , shell = { collapsed = False, drawerOpen = False }
      , tree = Tree.init Ids.tree
      , treeData = Remote.Loading
      , period = DateRangePicker.init Ids.period
      , overview = emptyPanel
      , transfers = emptyPanel
      , movements = emptyPanel
      , tableRows = Remote.Loading
      , transferLimit = 12
      , tabs = Tabs.init Ids.tabs "stream"
      , table = Table.init Ids.table
      , haystack = Array.empty
      , visible = Array.empty
      , search = SearchInput.init Ids.movementSearch
      , kind = Select.init Ids.kindFilter
      , list = VirtualList.init Ids.movementList
      , selected = Nothing
      , viewer = JsonViewer.init Ids.movementViewer
      , toasts = Toast.init
      , treeTicket = 0
      , overviewTicket = 0
      , transfersTicket = 0
      , movementsTicket = 0
      }
    , Task.map2 Tuple.pair Time.here Time.now |> Task.perform GotClock
    )



-- UPDATE


currentScope : Model -> Scope
currentScope model =
    Domain.scopeOfNode (Tree.selectedId Domain.nodeIds model.tree)


currentPeriod : Model -> Maybe Period
currentPeriod model =
    DateRangePicker.range model.period |> Maybe.map (\( from, to ) -> { from = from, to = to })


{-| Starts a request on a panel. A refresh keeps the data that is there (and marks
the panel as refreshing); anything else goes back to the skeleton.
-}
startLoading : Bool -> Panel a -> Panel a
startLoading refresh panel =
    if refresh && Remote.isSuccess panel.data then
        { panel | refreshing = True }

    else
        { panel | data = Remote.Loading, refreshing = False, refreshFailed = Nothing }


{-| The answer of a request. Returns the new panel and whether a refresh failed
(so the page can say so in a toast).
-}
receive : Time.Posix -> Bool -> Result Problem a -> Panel a -> ( Panel a, Maybe Problem )
receive now refresh result panel =
    case result of
        Ok data ->
            ( { data = Remote.Success data, loadedAt = Just now, refreshing = False, refreshFailed = Nothing }, Nothing )

        Err problem ->
            if refresh && Remote.isSuccess panel.data then
                ( { panel | refreshing = False, refreshFailed = Just problem }, Just problem )

            else
                ( { panel | data = Remote.Failure problem, refreshing = False, refreshFailed = Nothing }, Nothing )


fetchTree : Model -> ( Model, Cmd Msg )
fetchTree model =
    case model.db of
        Just db ->
            let
                ticket =
                    model.treeTicket + 1
            in
            ( { model | treeTicket = ticket, treeData = Remote.Loading }
            , Api.tree model.net db (GotTree ticket)
            )

        Nothing ->
            ( model, Cmd.none )


fetchOverview : Bool -> Model -> ( Model, Cmd Msg )
fetchOverview refresh model =
    case ( model.db, currentPeriod model ) of
        ( Just db, Just period ) ->
            let
                ticket =
                    model.overviewTicket + 1
            in
            ( { model | overviewTicket = ticket, overview = startLoading refresh model.overview }
            , Api.overview model.net db (currentScope model) period (GotOverview ticket refresh)
            )

        _ ->
            ( model, Cmd.none )


fetchTransfers : Bool -> Model -> ( Model, Cmd Msg )
fetchTransfers refresh model =
    case model.db of
        Just db ->
            let
                ticket =
                    model.transfersTicket + 1
            in
            ( { model | transfersTicket = ticket, transfers = startLoading refresh model.transfers }
            , Api.transfers model.net db (currentScope model) (GotTransfers ticket refresh)
            )

        Nothing ->
            ( model, Cmd.none )


fetchMovements : Bool -> Model -> ( Model, Cmd Msg )
fetchMovements refresh model =
    case model.db of
        Just db ->
            let
                ticket =
                    model.movementsTicket + 1
            in
            ( { model | movementsTicket = ticket, movements = startLoading refresh model.movements }
            , Api.movements model.net db (currentScope model) (GotMovements ticket refresh)
            )

        Nothing ->
            ( model, Cmd.none )


{-| Runs the fetches one after the other and batches their commands.
-}
andThen : (Model -> ( Model, Cmd Msg )) -> ( Model, Cmd Msg ) -> ( Model, Cmd Msg )
andThen step ( model, cmd ) =
    let
        ( next, nextCmd ) =
            step model
    in
    ( next, Cmd.batch [ cmd, nextCmd ] )


fetchScoped : Bool -> Model -> ( Model, Cmd Msg )
fetchScoped refresh model =
    ( model, Cmd.none )
        |> andThen (fetchOverview refresh)
        |> andThen (fetchTransfers refresh)
        |> andThen (fetchMovements refresh)


{-| KLAR GAP: VirtualList has no search and no filter. This and `searchText` search 50 000
rows with `Search.prepareMany` and keep the result in `visible`.

Applies the search text and the type filter to the movements.
-}
applyFilters : Model -> Model
applyFilters model =
    case model.movements.data of
        Remote.Success rows ->
            let
                query =
                    Search.query (SearchInput.committed model.search)

                kind =
                    Select.value model.kind

                keep i row =
                    (kind == Nothing || Just row.kind == kind)
                        && (Array.get i model.haystack
                                |> Maybe.andThen (Search.scorePrepared query)
                                |> (/=) Nothing
                           )

                visible =
                    rows
                        |> Array.indexedMap Tuple.pair
                        |> Array.filter (\( i, row ) -> keep i row)
                        |> Array.map Tuple.second
            in
            { model | visible = visible, list = VirtualList.reset model.list }

        _ ->
            { model | visible = Array.empty }


searchText : MovementRow -> String
searchText row =
    String.join " "
        [ row.reference, row.skuCode, row.skuName, Domain.kindName row.kind, row.warehouse, row.zone, row.actor ]


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        GotClock ( zone, now ) ->
            let
                today =
                    Date.fromPosix zone now

                db =
                    Db.generate (Date.toEpochDay today) (utcOffsetMs zone now)

                period =
                    DateRangePicker.setRange (Just ( Date.addDays -29 today, today )) model.period
            in
            ( { model | zone = zone, now = now, today = Just today, db = Just db, period = period }, Cmd.none )
                |> andThen fetchTree
                |> andThen (fetchScoped False)

        Tick now ->
            ( { model | now = now }, Cmd.none )

        TreeMsg inner ->
            let
                ( tree, cmd ) =
                    Tree.update inner model.tree

                changed =
                    Tree.selectedId Domain.nodeIds tree /= Tree.selectedId Domain.nodeIds model.tree

                next =
                    { model | tree = tree, selected = Nothing }
            in
            if changed then
                ( next, Cmd.map TreeMsg cmd ) |> andThen (fetchScoped False)

            else
                ( { model | tree = tree }, Cmd.map TreeMsg cmd )

        ShowAll ->
            ( { model | tree = Tree.setSelected Domain.nodeIds [] model.tree, selected = Nothing }, Cmd.none )
                |> andThen (fetchScoped False)

        ReloadTree ->
            fetchTree model

        GotTree ticket result ->
            if ticket /= model.treeTicket then
                ( model, Cmd.none )

            else
                ( { model | treeData = Remote.fromResult result }, Cmd.none )

        PeriodMsg inner ->
            let
                ( period, cmd ) =
                    DateRangePicker.update inner model.period

                changed =
                    DateRangePicker.range period /= DateRangePicker.range model.period

                next =
                    { model | period = period }
            in
            if changed then
                ( next, Cmd.map PeriodMsg cmd ) |> andThen (fetchOverview False)

            else
                ( next, Cmd.map PeriodMsg cmd )

        GotOverview ticket refresh result ->
            if ticket /= model.overviewTicket then
                ( model, Cmd.none )

            else
                let
                    ( panel, failed ) =
                        receive model.now refresh result model.overview
                in
                refreshToast failed { model | overview = panel }

        GotTransfers ticket refresh result ->
            if ticket /= model.transfersTicket then
                ( model, Cmd.none )

            else
                let
                    ( panel, failed ) =
                        receive model.now refresh result model.transfers
                in
                refreshToast failed { model | transfers = panel }

        GotMovements ticket refresh result ->
            if ticket /= model.movementsTicket then
                ( model, Cmd.none )

            else
                let
                    ( panel, failed ) =
                        receive model.now refresh result model.movements

                    withPanel =
                        { model | movements = panel }

                    movementList =
                        Remote.toMaybe panel.data |> Maybe.map Array.toList |> Maybe.withDefault []

                    prepared =
                        movementList |> List.map searchText |> Search.prepareMany |> Array.fromList
                in
                refreshToast failed (applyFilters { withPanel | haystack = prepared, tableRows = Remote.map Array.toList panel.data })

        RetryOverview ->
            fetchOverview (Remote.isSuccess model.overview.data) model

        RetryTransfers ->
            fetchTransfers (Remote.isSuccess model.transfers.data) model

        LoadMoreTransfers ->
            ( { model | transferLimit = model.transferLimit + 12 }, Cmd.none )

        RetryMovements ->
            fetchMovements (Remote.isSuccess model.movements.data) model

        RefreshAll ->
            fetchScoped True model

        SearchMsg inner ->
            let
                ( search, cmd ) =
                    SearchInput.update inner model.search

                changed =
                    SearchInput.committed search /= SearchInput.committed model.search

                next =
                    { model | search = search }
            in
            ( if changed then
                applyFilters next

              else
                next
            , Cmd.map SearchMsg cmd
            )

        KindMsg inner ->
            let
                ( kind, cmd ) =
                    Select.update inner model.kind

                changed =
                    Select.value kind /= Select.value model.kind

                next =
                    { model | kind = kind }
            in
            ( if changed then
                applyFilters next

              else
                next
            , Cmd.map KindMsg cmd
            )

        ListMsg inner ->
            let
                ( list, cmd ) =
                    VirtualList.update inner model.list
            in
            ( { model | list = list }, Cmd.map ListMsg cmd )

        TabsMsg inner ->
            let
                ( tabs, cmd ) =
                    Tabs.update inner model.tabs
            in
            ( { model | tabs = tabs }, Cmd.map TabsMsg cmd )

        TableMsg inner ->
            let
                ( table, cmd ) =
                    Table.update inner model.table
            in
            ( { model | table = table }, Cmd.map TableMsg cmd )

        RowChosen row ->
            ( { model | selected = Just row }, Cmd.none )

        ViewerMsg inner ->
            let
                ( viewer, cmd ) =
                    JsonViewer.update inner model.viewer
            in
            ( { model | viewer = viewer }, Cmd.map ViewerMsg cmd )

        CompactToggled on ->
            ( { model
                | compact = on
                , table =
                    Table.setDensity
                        (if on then
                            Theme.Compact

                         else
                            Theme.Normal
                        )
                        model.table
              }
            , Cmd.none
            )

        SlowToggled on ->
            let
                net =
                    model.net
            in
            ( { model | net = { net | slow = on } }, Cmd.none )

        FailingToggled on ->
            let
                net =
                    model.net
            in
            ( { model | net = { net | failing = on } }, Cmd.none )

        ToastMsg inner ->
            let
                ( toasts, cmd ) =
                    Toast.update inner model.toasts
            in
            ( { model | toasts = toasts }, Cmd.map ToastMsg cmd )

        ToggleSidebar ->
            ( { model | shell = { collapsed = not model.shell.collapsed, drawerOpen = model.shell.drawerOpen } }, Cmd.none )

        ToggleDrawer ->
            ( { model | shell = { collapsed = model.shell.collapsed, drawerOpen = not model.shell.drawerOpen } }
            , if model.shell.drawerOpen then
                AppShell.focusMenuButton Ids.appShell NoOp

              else
                Cmd.none
            )

        CloseDrawer ->
            ( { model | shell = { collapsed = model.shell.collapsed, drawerOpen = False } }
            , AppShell.focusMenuButton Ids.appShell NoOp
            )

        SkipToContent ->
            ( model, AppShell.focusContent Ids.appShell NoOp )

        NoOp ->
            ( model, Cmd.none )


refreshToast : Maybe Problem -> Model -> ( Model, Cmd Msg )
refreshToast failed model =
    case failed of
        Nothing ->
            ( model, Cmd.none )

        Just problem ->
            if failedPanels model > 1 then
                ( model, Cmd.none )

            else
                let
                    ( toasts, cmd ) =
                        Toast.push
                            [ Toast.danger
                            , Toast.title "Refresh failed"
                            , Toast.message (Remote.title Locale.en problem ++ ". The page shows the old data.")
                            ]
                            model.toasts
                in
                ( { model | toasts = toasts }, Cmd.map ToastMsg cmd )


{-| How many panels hold old data because their last refresh failed: one toast
is enough for a refresh that fails everywhere.
-}
failedPanels : Model -> Int
failedPanels model =
    [ model.overview.refreshFailed, model.transfers.refreshFailed, model.movements.refreshFailed ]
        |> List.filter ((/=) Nothing)
        |> List.length



-- VIEW


view : Model -> Browser.Document Msg
view model =
    { title = "Stock overview"
    , body =
        [ Klar.stylesheet
        , AppShell.view
            [ AppShell.id Ids.appShell
            , AppShell.brand
                (AppShell.brandLink
                    { name = "Stock overview"
                    , href = "#/"
                    , logo = Just (Icon.sized Icon.Large Icon.warehouse)
                    }
                )
            , AppShell.sidebar (viewSidebar model)
            , AppShell.sidebarCollapsed model.shell.collapsed
            , AppShell.onToggleSidebar ToggleSidebar
            , AppShell.drawerOpen model.shell.drawerOpen
            , AppShell.onToggleDrawer ToggleDrawer
            , AppShell.onCloseDrawer CloseDrawer
            , AppShell.onSkipToContent SkipToContent
            , AppShell.onStrayDrop NoOp
            , AppShell.overlays [ Toast.view ToastMsg [] model.toasts ]
            ]
            [ viewPage model ]
        ]
    }


viewSidebar : Model -> Html Msg
viewSidebar model =
    Layout.stack [ Layout.gap 2, Layout.padding 2 ]
        [ Button.view
            [ Button.small
            , Button.icon Icon.globe
            , Button.pressed (currentScope model == Everything)
            , Button.onClick ShowAll
            ]
            "All locations"
        , Tree.viewRemote TreeMsg
            ([ Tree.ariaLabel "Locations"
             , Tree.filterBox
             , Tree.filterPlaceholder "Find a location ..."
             , Tree.onReload ReloadTree
             ]
                ++ (if model.compact then
                        [ Tree.compact ]

                    else
                        []
                   )
            )
            model.tree
            (Remote.map (List.map regionNode) model.treeData)
        ]


regionNode : TreeRegion -> Tree.Node NodeId
regionNode region =
    Tree.branch Domain.nodeIds (RegionNode region.id) region.name (List.map warehouseNode region.warehouses)
        |> Tree.withIcon Icon.map


warehouseNode : TreeWarehouse -> Tree.Node NodeId
warehouseNode warehouse =
    let
        node =
            Tree.branch Domain.nodeIds (WarehouseNode warehouse.id) warehouse.name (List.map zoneNode warehouse.zones)
                |> Tree.withIcon Icon.warehouse
    in
    case warehouse.status of
        Active ->
            node |> Tree.withCount warehouse.movementCount

        OpeningSoon ->
            node |> Tree.withBadge Warning "Opening"


zoneNode : TreeZone -> Tree.Node NodeId
zoneNode zone =
    Tree.leaf Domain.nodeIds (ZoneNode zone.id) zone.name
        |> Tree.withHint zone.code


scopeName : Model -> String
scopeName model =
    let
        regions =
            Remote.withDefault [] model.treeData

        warehouses =
            List.concatMap .warehouses regions

        zones =
            List.concatMap .zones warehouses
    in
    case Domain.scopeOfNode (Tree.selectedId Domain.nodeIds model.tree) of
        Everything ->
            "All locations"

        InRegion id ->
            regions |> List.filter (\r -> r.id == id) |> List.head |> Maybe.map (\r -> r.name ++ " region") |> Maybe.withDefault "Region"

        InWarehouse id ->
            warehouses |> List.filter (\w -> w.id == id) |> List.head |> Maybe.map .name |> Maybe.withDefault "Warehouse"

        InZone id ->
            zones |> List.filter (\z -> z.id == id) |> List.head |> Maybe.map (\z -> z.code ++ " " ++ z.name) |> Maybe.withDefault "Zone"


viewPage : Model -> Html Msg
viewPage model =
    Layout.stack [ Layout.gap 4 ]
        ([ PageHeader.view
            [ PageHeader.title "Stock overview"
            , PageHeader.subtitle (scopeName model)
            , PageHeader.actions
                [ Switch.view
                    [ Switch.label "Compact"
                    , Switch.checked model.compact
                    , Switch.onToggle CompactToggled
                    ]
                , Switch.view
                    [ Switch.label "Slow network"
                    , Switch.checked model.net.slow
                    , Switch.onToggle SlowToggled
                    ]
                , Switch.view
                    [ Switch.label "Failing network"
                    , Switch.checked model.net.failing
                    , Switch.onToggle FailingToggled
                    ]
                , Button.view
                    [ Button.icon Icon.refresh
                    , Button.onClick RefreshAll
                    , Button.loading (isRefreshing model)
                    ]
                    "Refresh"
                ]
            ]
         ]
            ++ staleAlert model
            ++ [ viewPeriod model
               , viewBody model
               ]
        )


isRefreshing : Model -> Bool
isRefreshing model =
    model.overview.refreshing || model.transfers.refreshing || model.movements.refreshing


{-| The first thing a person must see when the page is showing old data.
-}
staleAlert : Model -> List (Html Msg)
staleAlert model =
    let
        problems =
            List.filterMap identity
                [ model.overview.refreshFailed
                , model.transfers.refreshFailed
                , model.movements.refreshFailed
                ]
    in
    case problems of
        [] ->
            []

        problem :: _ ->
            [ Alert.view
                [ Alert.tone Warning
                , Alert.title "Showing old data"
                , Alert.actions [ Button.view [ Button.small, Button.onClick RefreshAll ] "Try again" ]
                ]
                (Remote.title Locale.en problem
                    ++ ". The figures below are from "
                    ++ oldestLoad model
                    ++ "."
                )
            ]


oldestLoad : Model -> String
oldestLoad model =
    [ model.overview.loadedAt, model.transfers.loadedAt, model.movements.loadedAt ]
        |> List.filterMap identity
        |> List.map Time.posixToMillis
        |> List.minimum
        |> Maybe.map (\ms -> Format.time model.zone (Time.millisToPosix ms))
        |> Maybe.withDefault "an earlier time"


viewPeriod : Model -> Html Msg
viewPeriod model =
    let
        limits =
            case ( model.today, model.db ) of
                ( Just today, Just db ) ->
                    [ DateRangePicker.today today
                    , DateRangePicker.min (Date.fromEpochDay db.startDay)
                    , DateRangePicker.max today
                    ]

                _ ->
                    []
    in
    Layout.row [ Layout.gap 3, Layout.alignEnd, Layout.wrap ]
        [ DateRangePicker.view PeriodMsg
            ([ DateRangePicker.label "Period"
             , DateRangePicker.hint "Figures and charts compare with the period before."
             ]
                ++ limits
            )
            model.period
        ]


viewBody : Model -> Html Msg
viewBody model =
    case model.overview.data of
        Remote.Success overview ->
            if overview.hasData then
                viewDashboard model

            else
                Layout.stack [ Layout.gap 4 ]
                    [ EmptyState.view
                        [ EmptyState.icon Icon.warehouse
                        , EmptyState.title ("No stock data for " ++ scopeName model)
                        , EmptyState.description "Nothing has been received or moved here yet. Pick another location to see its stock."
                        , EmptyState.action (Button.view [ Button.onClick ShowAll ] "Show all locations")
                        ]
                    ]

        _ ->
            viewDashboard model


viewDashboard : Model -> Html Msg
viewDashboard model =
    Layout.stack [ Layout.gap 4 ]
        [ viewFigures model
        , Layout.grid [ Layout.columns 2, Layout.gap 4 ]
            [ viewLevelChart model
            , viewFlowChart model
            ]
        , Layout.grid [ Layout.minColumn 460, Layout.gap 4 ]
            [ viewMovements model
            , viewTransfers model
            , viewDetail model
            ]
        ]


sizeAttr : Model -> List (Stat.Attribute msg)
sizeAttr model =
    if model.compact then
        [ Stat.size Small ]

    else
        []


change : Float -> Float -> List (Stat.Attribute msg)
change current previous =
    if previous == 0 then
        []

    else
        [ Stat.delta ((current - previous) / previous * 100), Stat.deltaLabel "vs previous period" ]


viewFigures : Model -> Html Msg
viewFigures model =
    let
        tile label attrs =
            Stat.view
                ([ Stat.label label
                 , Stat.onRetry RetryOverview
                 ]
                    ++ sizeAttr model
                    ++ attrs
                )
    in
    Stat.row
        [ tile "Stock value"
            [ Stat.remote model.overview.data
                (\o ->
                    [ Stat.compact o.figures.stockValue
                    , Stat.unit "USD"
                    , Stat.trend (List.map .units o.levels)
                    ]
                        ++ change o.figures.stockValue o.previous.stockValue
                )
            ]
        , tile "Items below reorder level"
            [ Stat.remote model.overview.data
                (\o ->
                    [ Stat.int o.figures.belowReorder, Stat.lowerIsBetter ]
                        ++ change (toFloat o.figures.belowReorder) (toFloat o.previous.belowReorder)
                )
            ]
        , tile "Open transfers"
            [ Stat.remote model.overview.data
                (\o ->
                    [ Stat.int o.figures.openTransfers, Stat.lowerIsBetter ]
                        ++ change (toFloat o.figures.openTransfers) (toFloat o.previous.openTransfers)
                )
            ]
        , tile "Turnover"
            [ Stat.remote model.overview.data
                (\o ->
                    [ Stat.decimal 2 o.figures.turnover
                    , Stat.unit "turns / year"
                    ]
                        ++ change o.figures.turnover o.previous.turnover
                )
            ]
        ]


{-| "Updated 14:05" or, when the last refresh failed, "Old data from 14:05".
-}
freshness : Model -> Panel a -> List (Html Msg)
freshness model panel =
    case ( panel.refreshFailed, panel.loadedAt, Remote.isSuccess panel.data ) of
        ( Just _, Just at, True ) ->
            [ Badge.view [ Badge.tone Warning, Badge.icon Icon.clock ] ("Old data from " ++ Format.time model.zone at) ]

        ( Nothing, Just at, True ) ->
            [ Text.caption ("Updated " ++ Format.time model.zone at) ]

        _ ->
            []


overviewOr : (Overview -> List a) -> Model -> List a
overviewOr pick model =
    Remote.toMaybe model.overview.data |> Maybe.map pick |> Maybe.withDefault []


viewLevelChart : Model -> Html Msg
viewLevelChart model =
    Card.view
        [ Card.title "Stock level over time"
        , Card.subtitle (scopeName model)
        , Card.actions (freshness model model.overview)
        ]
        [ Chart.line
            [ Chart.ariaLabel "Stock level over time"
            , Chart.categories (overviewOr (.levels >> List.map .label) model)
            , Chart.remote model.overview.data
            , Chart.onRetry RetryOverview
            , Chart.unit "units"
            , Chart.points True
            ]
            [ Chart.series "Units on hand" (overviewOr (.levels >> List.map .units) model)
            , Chart.series "Reorder level (all items)" (overviewOr (.levels >> List.map .reorder) model) |> Chart.dashed
            ]
        ]


viewFlowChart : Model -> Html Msg
viewFlowChart model =
    Card.view
        [ Card.title "Movements by category"
        , Card.subtitle "Units received and shipped in the period"
        , Card.actions (freshness model model.overview)
        ]
        [ Chart.bar
            [ Chart.ariaLabel "Movements by category"
            , Chart.categories (List.map (.category >> Domain.categoryName) (overviewOr .flows model))
            , Chart.remote model.overview.data
            , Chart.onRetry RetryOverview
            , Chart.unit "units"
            ]
            [ Chart.series "Received" (overviewOr (.flows >> List.map .received) model)
            , Chart.series "Shipped" (overviewOr (.flows >> List.map .shipped) model)
            ]
        ]



-- MOVEMENTS


viewMovements : Model -> Html Msg
viewMovements model =
    Card.view
        [ Card.title "Movements"
        , Card.subtitle "All time, for the selected location"
        , Card.actions (freshness model model.movements)
        ]
        [ Layout.stack [ Layout.gap 3 ]
            [ Tabs.view TabsMsg
                [ Tabs.ariaLabel "Movements view"
                , Tabs.small
                , Tabs.tabs [ Tabs.tab "stream" "Stream", Tabs.tab "table" "Table" ]
                ]
                model.tabs
            , Tabs.panel model.tabs "stream" (\_ -> viewStream model)
            , Tabs.panel model.tabs "table" (\_ -> viewMovementTable model)
            ]
        ]


viewStream : Model -> Html Msg
viewStream model =
    Layout.stack [ Layout.gap 3 ]
        [ Layout.row [ Layout.gap 2, Layout.wrap ]
            [ SearchInput.view SearchMsg
                [ SearchInput.ariaLabel "Search movements"
                , SearchInput.placeholder "Search SKU, reference, person ..."
                , SearchInput.size Small
                ]
                model.search
            , Select.view KindMsg
                [ Select.label "Type"
                , Select.labelHidden
                , Select.placeholder "All types"
                , Select.clearable
                , Select.size Small
                , Select.options (List.map (\kind -> Select.option kind (Domain.kindName kind)) Domain.allKinds)
                ]
                model.kind
            ]
        , viewMovementList model
        ]


colWhen : Table.ColumnId
colWhen =
    Table.columnId "when"


colType : Table.ColumnId
colType =
    Table.columnId "type"


colSku : Table.ColumnId
colSku =
    Table.columnId "sku"


colQuantity : Table.ColumnId
colQuantity =
    Table.columnId "quantity"


colLocation : Table.ColumnId
colLocation =
    Table.columnId "location"


viewMovementTable : Model -> Html Msg
viewMovementTable model =
    Table.view TableMsg
        [ Table.columns
            [ Table.text colWhen
                "When"
                (\row -> Format.dateTime Locale.en model.zone row.at)
                [ Table.width 150
                , Table.sortWith (\a b -> compare (Time.posixToMillis a.at) (Time.posixToMillis b.at))
                ]
            , Table.status colType "Type" (\row -> ( kindTone row.kind, Domain.kindName row.kind )) [ Table.filterSelect ]
            , Table.text colSku "SKU" (\row -> row.skuCode ++ " " ++ row.skuName) [ Table.filterText ]
            , Table.int colQuantity "Quantity" .quantity [ Table.filterRange ]
            , Table.text colLocation "Location" (\row -> row.warehouse ++ ", " ++ row.zone) [ Table.filterSelect ]
            ]
        , Table.rows model.tableRows
        , Table.rowId Table.intIds .id
        , Table.label "Movements"
        , Table.searchable
        , Table.onRowClick RowChosen
        , Table.onRetry RetryMovements
        , Table.maxHeight 480
        , Table.pageSizes [ 25, 50, 100 ]
        ]
        model.table


viewMovementList : Model -> Html Msg
viewMovementList model =
    case model.movements.data of
        Remote.NotAsked ->
            Skeleton.lines 8

        Remote.Loading ->
            Skeleton.lines 8

        Remote.Failure problem ->
            ErrorState.view [ ErrorState.compact, ErrorState.onRetry RetryMovements ] problem

        Remote.Success rows ->
            if Array.isEmpty rows then
                EmptyState.view
                    [ EmptyState.compact
                    , EmptyState.icon Icon.package
                    , EmptyState.title "No movements here"
                    , EmptyState.description "No stock has moved in this location yet."
                    ]

            else if Array.isEmpty model.visible then
                EmptyState.view
                    [ EmptyState.compact
                    , EmptyState.icon Icon.search
                    , EmptyState.title "No movements match"
                    , EmptyState.description "Try another search or a different type."
                    ]

            else
                Layout.stack [ Layout.gap 2 ]
                    [ Text.muted
                        (Format.int Locale.en (Array.length model.visible)
                            ++ " of "
                            ++ Format.int Locale.en (Array.length rows)
                            ++ " movements"
                        )
                    , VirtualList.view ListMsg
                        [ VirtualList.rowHeight rowHeight
                        , VirtualList.height 520
                        , VirtualList.htmlAttrs [ Html.Attributes.attribute "role" "list", Html.Attributes.attribute "aria-label" "Movements" ]
                        ]
                        { items = model.visible, viewRow = viewMovementRow model }
                        model.list
                    ]


-- KLAR GAP: the height of a ListItem is not documented (measured in the browser: 44px).
rowHeight : Int
rowHeight =
    44


viewMovementRow : Model -> Int -> MovementRow -> Html Msg
viewMovementRow model _ row =
    ListItem.view
        [ ListItem.meta (Format.dateTime Locale.en model.zone row.at)
        , ListItem.accent (kindTone row.kind)
        , ListItem.selected (Maybe.map .id model.selected == Just row.id)
        , ListItem.onClick (RowChosen row)
        ]
        (Domain.kindName row.kind
            ++ " "
            ++ signed row.quantity
            ++ " × "
            ++ row.skuName
            ++ " · "
            ++ row.zone
        )


signed : Int -> String
signed n =
    if n > 0 then
        "+" ++ String.fromInt n

    else
        String.fromInt n


kindTone : MovementKind -> Tone
kindTone kind =
    case kind of
        Receipt ->
            Success

        Return ->
            Info

        Pick ->
            Neutral

        TransferIn ->
            Primary

        TransferOut ->
            Primary

        Adjustment ->
            Warning



-- TRANSFERS


viewTransfers : Model -> Html Msg
viewTransfers model =
    Card.view
        [ Card.title "Latest transfers"
        , Card.subtitle "Between zones"
        , Card.actions (freshness model model.transfers)
        ]
        [ Timeline.view
            ([ Timeline.ariaLabel "Latest transfers"
             , Timeline.zone model.zone
             , Timeline.now model.now
             , Timeline.remote model.transfers.data
             , Timeline.onRetry RetryTransfers
             , Timeline.emptyTitle "No transfers here"
             , Timeline.emptyDescription "No stock has been moved to or from this location."
             , Timeline.onLoadMore LoadMoreTransfers
             , Timeline.hasMore (transferTotal model > model.transferLimit)
             ]
                ++ (if model.compact then
                        [ Timeline.compact ]

                    else
                        []
                   )
            )
            (Remote.toMaybe model.transfers.data |> Maybe.withDefault [] |> List.take model.transferLimit |> List.map transferEvent)
        ]


transferTotal : Model -> Int
transferTotal model =
    Remote.toMaybe model.transfers.data |> Maybe.map List.length |> Maybe.withDefault 0


transferEvent : Transfer -> Timeline.Event msg
transferEvent transfer =
    Timeline.event (String.fromInt transfer.id)
        transfer.at
        (transfer.reference ++ " · " ++ statusText transfer.status ++ ": " ++ transfer.from ++ " to " ++ transfer.to)
        |> Timeline.withTone (statusTone transfer.status)
        |> Timeline.withDescription (Format.int Locale.en transfer.units ++ " units")


statusText : TransferStatus -> String
statusText status =
    case status of
        Requested ->
            "Requested"

        InTransit ->
            "In transit"

        Received ->
            "Received"

        Cancelled ->
            "Cancelled"


statusTone : TransferStatus -> Tone
statusTone status =
    case status of
        Requested ->
            Warning

        InTransit ->
            Primary

        Received ->
            Success

        Cancelled ->
            Danger



-- DETAIL


viewDetail : Model -> Html Msg
viewDetail model =
    Card.view
        [ Card.title "Selected movement"
        , Card.subtitle "The raw event"
        ]
        [ case model.selected of
            Nothing ->
                EmptyState.view
                    [ EmptyState.compact
                    , EmptyState.icon Icon.braces
                    , EmptyState.title "No movement selected"
                    , EmptyState.description "Choose a movement in the list to see the event as it was received."
                    ]

            Just row ->
                Layout.stack [ Layout.gap 3 ]
                    [ DescriptionList.view
                        [ DescriptionList.compact, DescriptionList.columns 2 ]
                        [ DescriptionList.text "Reference" row.reference
                        , DescriptionList.text "Type" (Domain.kindName row.kind)
                        , DescriptionList.text "SKU" (row.skuCode ++ " " ++ row.skuName)
                        , DescriptionList.text "Quantity" (signed row.quantity)
                        , DescriptionList.text "Location" (row.warehouse ++ ", " ++ row.zone)
                        , DescriptionList.text "When" (Format.dateTime Locale.en model.zone row.at)
                        ]
                    , JsonViewer.view ViewerMsg
                        [ JsonViewer.toolbar
                        , JsonViewer.rootLabel "event"
                        , JsonViewer.ariaLabel "Raw event"
                        ]
                        model.viewer
                        (Event.encode row)
                    ]
        ]


{-| How far the clock of the user is from UTC, in milliseconds. The dummy backend
needs it to put its timestamps on the right local day.
-}
utcOffsetMs : Time.Zone -> Time.Posix -> Int
utcOffsetMs zone now =
    let
        msOfDay z =
            (Time.toHour z now * 60 + Time.toMinute z now) * 60000
    in
    modBy 86400000 (msOfDay zone - msOfDay Time.utc + 43200000) - 43200000
