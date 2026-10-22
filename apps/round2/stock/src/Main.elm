module Main exposing (main)

import Array exposing (Array)
import Backend.Api as Api
import Backend.Data as Data exposing (Kind(..), Place(..))
import Browser
import Browser.Navigation as Nav
import Feed exposing (Feed)
import Html exposing (Html)
import Klar
import Klar.Alert as Alert
import Klar.AppShell as AppShell
import Klar.Badge as Badge
import Klar.Button as Button
import Klar.Card as Card
import Klar.Chart as Chart
import Klar.Date as Date exposing (Date)
import Klar.DateRangePicker as DateRangePicker
import Klar.EmptyState as EmptyState
import Klar.Format as Format
import Klar.Icon as Icon
import Klar.JsonViewer as JsonViewer
import Klar.Layout as Layout
import Klar.Locale as Locale
import Klar.PageHeader as PageHeader
import Klar.Remote as Remote exposing (Remote(..))
import Klar.SegmentedControl as SegmentedControl
import Klar.SideNav as SideNav
import Klar.Stat as Stat
import Klar.Switch as Switch
import Klar.Table as Table
import Klar.Text as Text
import Klar.Theme as Theme exposing (Density(..), Tone(..))
import Klar.Timeline as Timeline
import Klar.Toast as Toast
import Klar.Tree as Tree
import Task
import Time
import Url exposing (Url)



-- MODEL


type Page
    = Overview


type alias Model =
    { key : Nav.Key
    , zone : Time.Zone
    , now : Time.Posix
    , mode : Api.Mode
    , density : Density
    , scrolling : Bool
    , sideNav : SideNav.State Page
    , drawerOpen : Bool
    , period : DateRangePicker.State
    , tree : Tree.State Place
    , query : Data.Query
    , regions : Feed (List Data.Region)
    , summary : Feed Data.Summary
    , levels : Feed Data.Levels
    , categories : Feed (List Data.Category)
    , transfers : Feed { items : List Data.TransferOrder, hasMore : Bool }
    , transferLimit : Int
    , movements : Feed (Table.Rows Data.Movement)
    , table : Table.State Int
    , selected : Maybe Data.Movement
    , viewer : JsonViewer.State
    , toasts : Toast.State Msg
    }


type Msg
    = LinkClicked Browser.UrlRequest
    | UrlChanged Url
    | SideNavMsg SideNav.Msg
    | ToggleDrawer
    | CloseDrawer
    | SkipToContent
    | NoOp
    | GotZone Time.Zone
    | TreeMsg Tree.Msg
    | PeriodMsg DateRangePicker.Msg
    | TableMsg Table.Msg
    | ViewerMsg JsonViewer.Msg
    | ToastMsg Toast.Msg
    | GotRegions (Api.Response (List Data.Region))
    | GotSummary (Api.Response Data.Summary)
    | GotLevels (Api.Response Data.Levels)
    | GotCategories (Api.Response (List Data.Category))
    | GotTransfers (Api.Response { items : List Data.TransferOrder, hasMore : Bool })
    | GotMovements (Api.Response (Array Data.Movement))
    | SelectMovement Data.Movement
    | ClearMovement
    | LoadMoreTransfers
    | SimulateFailure Bool
    | DensityChanged String
    | ListModeChanged String
    | Refresh
    | RetryRegions
    | RetrySummary
    | RetryLevels
    | RetryCategories
    | RetryTransfers
    | RetryMovements
    | ResetFilters


main : Program () Model Msg
main =
    Browser.application
        { init = init
        , update = update
        , view = view
        , subscriptions = \_ -> Sub.none
        , onUrlRequest = LinkClicked
        , onUrlChange = UrlChanged
        }


defaultPeriod : ( Date, Date )
defaultPeriod =
    ( Date.addDays -29 Data.dataEnd, Data.dataEnd )


init : () -> Url -> Nav.Key -> ( Model, Cmd Msg )
init _ url key =
    let
        query =
            { place = Nothing, from = Tuple.first defaultPeriod, to = Tuple.second defaultPeriod }

        model =
            { key = key
            , zone = Time.utc
            , now = Time.millisToPosix 0
            , mode =
                if url.fragment == Just "/fail" then
                    Api.Failing

                else
                    Api.Healthy
            , density = Normal
            , scrolling = True
            , sideNav = SideNav.init "main-nav"
            , drawerOpen = False
            , period = DateRangePicker.init "period" |> DateRangePicker.setRange (Just defaultPeriod)
            , tree =
                Tree.init "locations"
                    |> Tree.setExpanded placeIds [ InRegion "north", InRegion "south", InRegion "east", InRegion "west" ]
            , query = query
            , regions = Feed.init
            , summary = Feed.init
            , levels = Feed.init
            , categories = Feed.init
            , transfers = Feed.init
            , transferLimit = transferPage
            , movements = Feed.init
            , table = Table.init "movements"
            , selected = Nothing
            , viewer = JsonViewer.init "raw-event"
            , toasts = Toast.init
            }
    in
    ( model
    , Cmd.batch
        [ Task.perform GotZone Time.here
        , Api.regions model.mode GotRegions
        , Api.movements model.mode GotMovements
        , fetchQuery model
        ]
    )


transferPage : Int
transferPage =
    8


placeIds : Tree.Ids Place
placeIds =
    Tree.nodeIds { toKey = Data.placeKey, fromKey = Data.placeFromKey }


{-| The four requests that depend on the place and the period.
-}
fetchQuery : Model -> Cmd Msg
fetchQuery model =
    Cmd.batch
        [ Api.summary model.mode model.query GotSummary
        , Api.levels model.mode model.query GotLevels
        , Api.categories model.mode model.query GotCategories
        , Api.transfers model.mode model.query model.transferLimit GotTransfers
        ]


{-| A new place or period: forget the old answers and ask again.
-}
requery : Data.Query -> Model -> ( Model, Cmd Msg )
requery query model =
    let
        next =
            { model
                | query = query
                , transferLimit = transferPage
                , summary = Feed.restart model.summary
                , levels = Feed.restart model.levels
                , categories = Feed.restart model.categories
                , transfers = Feed.restart model.transfers
            }
    in
    ( next, fetchQuery next )



-- UPDATE


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        LinkClicked (Browser.Internal url) ->
            ( model, Nav.pushUrl model.key (Url.toString url) )

        LinkClicked (Browser.External href) ->
            ( model, Nav.load href )

        UrlChanged _ ->
            ( { model | drawerOpen = False }, AppShell.resetScroll shellId NoOp )

        SideNavMsg m ->
            let
                ( sideNav, cmd ) =
                    SideNav.update m model.sideNav
            in
            ( { model | sideNav = sideNav }, Cmd.map SideNavMsg cmd )

        ToggleDrawer ->
            if model.drawerOpen then
                ( { model | drawerOpen = False }, AppShell.focusMenuButton shellId NoOp )

            else
                ( { model | drawerOpen = True }, SideNav.focusLink pageKeys Overview model.sideNav NoOp )

        CloseDrawer ->
            ( { model | drawerOpen = False }, AppShell.focusMenuButton shellId NoOp )

        SkipToContent ->
            ( model, AppShell.focusContent shellId NoOp )

        NoOp ->
            ( model, Cmd.none )

        GotZone zone ->
            ( { model | zone = zone }, Cmd.none )

        TreeMsg m ->
            let
                ( tree, cmd ) =
                    Tree.update m model.tree

                placed =
                    { model | tree = tree }

                treeCmd =
                    Cmd.map TreeMsg cmd
            in
            if Tree.selectedId placeIds tree /= Tree.selectedId placeIds model.tree then
                let
                    ( next, fetch ) =
                        requery (withPlace (Tree.selectedId placeIds tree) model.query) placed
                in
                ( next, Cmd.batch [ treeCmd, fetch ] )

            else
                ( placed, treeCmd )

        PeriodMsg m ->
            let
                ( period, cmd ) =
                    DateRangePicker.update m model.period

                placed =
                    { model | period = period }

                periodCmd =
                    Cmd.map PeriodMsg cmd
            in
            case DateRangePicker.range period of
                Just ( from, to ) ->
                    if from /= model.query.from || to /= model.query.to then
                        let
                            ( next, fetch ) =
                                requery (withPeriod from to model.query) placed
                        in
                        ( next, Cmd.batch [ periodCmd, fetch ] )

                    else
                        ( placed, periodCmd )

                Nothing ->
                    ( placed, periodCmd )

        TableMsg m ->
            let
                ( table, cmd ) =
                    Table.update m model.table
            in
            ( { model | table = table }, Cmd.map TableMsg cmd )

        ViewerMsg m ->
            let
                ( viewer, cmd ) =
                    JsonViewer.update m model.viewer
            in
            ( { model | viewer = viewer }, Cmd.map ViewerMsg cmd )

        ToastMsg m ->
            let
                ( toasts, cmd ) =
                    Toast.update m model.toasts
            in
            ( { model | toasts = toasts }, Cmd.map ToastMsg cmd )

        GotRegions response ->
            settle "locations" response .regions (\feed m -> { m | regions = feed }) model

        GotSummary response ->
            settle "figures" response .summary (\feed m -> { m | summary = feed }) model

        GotLevels response ->
            settle "stock level chart" response .levels (\feed m -> { m | levels = feed }) model

        GotCategories response ->
            settle "movement chart" response .categories (\feed m -> { m | categories = feed }) model

        GotTransfers response ->
            settle "transfers" response .transfers (\feed m -> { m | transfers = feed }) model

        GotMovements response ->
            let
                -- the work that makes 50 000 rows quick, once, when they arrive
                prepared =
                    { at = response.at
                    , result = Result.map (Table.prepareRows Locale.en columns) response.result
                    }
            in
            settle "movements" prepared .movements (\feed m -> { m | movements = feed }) model

        SelectMovement movement ->
            ( { model | selected = Just movement }, Cmd.none )

        ClearMovement ->
            ( { model | selected = Nothing }, Cmd.none )

        LoadMoreTransfers ->
            let
                next =
                    { model
                        | transferLimit = model.transferLimit + transferPage
                        , transfers = Feed.refresh model.transfers
                    }
            in
            ( next, Api.transfers next.mode next.query next.transferLimit GotTransfers )

        SimulateFailure failing ->
            ( { model
                | mode =
                    if failing then
                        Api.Failing

                    else
                        Api.Healthy
              }
            , Cmd.none
            )

        DensityChanged "compact" ->
            ( { model | density = Compact, table = Table.setDensity Compact model.table }, Cmd.none )

        ListModeChanged mode ->
            ( { model | scrolling = mode == "scroll", table = Table.setPage 1 model.table }, Cmd.none )

        DensityChanged _ ->
            ( { model | density = Normal, table = Table.setDensity Normal model.table }, Cmd.none )

        Refresh ->
            let
                next =
                    { model
                        | regions = Feed.refresh model.regions
                        , summary = Feed.refresh model.summary
                        , levels = Feed.refresh model.levels
                        , categories = Feed.refresh model.categories
                        , transfers = Feed.refresh model.transfers
                        , movements = Feed.refresh model.movements
                    }
            in
            ( next
            , Cmd.batch
                [ Api.regions next.mode GotRegions
                , Api.movements next.mode GotMovements
                , fetchQuery next
                ]
            )

        RetryRegions ->
            ( { model | regions = Feed.refresh model.regions }, Api.regions model.mode GotRegions )

        RetrySummary ->
            ( { model | summary = Feed.refresh model.summary }, Api.summary model.mode model.query GotSummary )

        RetryLevels ->
            ( { model | levels = Feed.refresh model.levels }, Api.levels model.mode model.query GotLevels )

        RetryCategories ->
            ( { model | categories = Feed.refresh model.categories }, Api.categories model.mode model.query GotCategories )

        RetryTransfers ->
            ( { model | transfers = Feed.refresh model.transfers }
            , Api.transfers model.mode model.query model.transferLimit GotTransfers
            )

        RetryMovements ->
            ( { model | movements = Feed.refresh model.movements }, Api.movements model.mode GotMovements )

        ResetFilters ->
            let
                ( from, to ) =
                    defaultPeriod

                reset =
                    { model
                        | tree = Tree.setSelected placeIds [] model.tree
                        , period = DateRangePicker.setRange (Just defaultPeriod) model.period
                        , table = Table.clearFilters model.table
                    }
            in
            requery { place = Nothing, from = from, to = to } reset


{-| Take an answer into its feed, and say so with a toast when it turned good data into old data.

-- KLAR GAP: stale data (R2S-002): the toast, `anyStale`, and the notice below are all mine.

-}
settle :
    String
    -> Api.Response a
    -> (Model -> Feed a)
    -> (Feed a -> Model -> Model)
    -> Model
    -> ( Model, Cmd Msg )
settle name response get set model =
    let
        before =
            get model

        after =
            Feed.receive response before

        next =
            set after { model | now = response.at }
    in
    if Feed.failedWhileHolding before after && not (anyStale model) then
        let
            ( toasts, cmd ) =
                Toast.push
                    [ Toast.danger
                    , Toast.title ("Could not refresh the " ++ name)
                    , Toast.message "The previous data stays on the screen and is marked as old. Other parts may fail the same way."
                    ]
                    next.toasts
        in
        ( { next | toasts = toasts }, Cmd.map ToastMsg cmd )

    else
        ( next, Cmd.none )


withPlace : Maybe Place -> Data.Query -> Data.Query
withPlace place query =
    { query | place = place }


withPeriod : Date -> Date -> Data.Query -> Data.Query
withPeriod from to query =
    { query | from = from, to = to }


anyStale : Model -> Bool
anyStale model =
    List.any identity
        [ Feed.staleError model.regions /= Nothing
        , Feed.staleError model.summary /= Nothing
        , Feed.staleError model.levels /= Nothing
        , Feed.staleError model.categories /= Nothing
        , Feed.staleError model.transfers /= Nothing
        , Feed.staleError model.movements /= Nothing
        ]



-- COLUMNS


movementTone : Data.Kind -> Tone
movementTone kind =
    case kind of
        Receipt ->
            Success

        Issue ->
            Primary

        Transfer ->
            Info

        Adjustment ->
            Warning

        Return ->
            Neutral


columns : List (Table.Column Data.Movement Msg)
columns =
    [ Table.text (Table.columnId "id") "Movement" .id [ Table.pinned, Table.width 108 ]
    , Table.date (Table.columnId "day") "Date" .day [ Table.width 104 ]
    , Table.badge (Table.columnId "type") "Type" (\m -> ( movementTone m.kind, Data.kindLabel m.kind )) [ Table.filterSelect, Table.width 124 ]
    , Table.text (Table.columnId "warehouse") "Warehouse" .warehouse [ Table.filterSelect, Table.minWidth 100 ]
    , Table.text (Table.columnId "zone") "Zone" .zone [ Table.filterSelect, Table.minWidth 90, Table.hiddenByDefault ]
    , Table.text (Table.columnId "sku") "SKU" .sku [ Table.width 96 ]
    , Table.text (Table.columnId "item") "Item" .item [ Table.minWidth 120 ]
    , Table.text (Table.columnId "category") "Category" .category [ Table.filterSelect, Table.hiddenByDefault ]
    , Table.int (Table.columnId "quantity") "Quantity" .quantity [ Table.footerSum, Table.filterRange, Table.width 100 ]
    , Table.float (Table.columnId "value") "Value" 2 .value [ Table.footerSum, Table.width 120 ]
    , Table.text (Table.columnId "reference") "Reference" .reference [ Table.hiddenByDefault ]
    ]


rowVisible : Data.Query -> Data.Movement -> Bool
rowVisible query movement =
    Data.placeMatches query.place movement && Data.inPeriod query movement



-- VIEW


shellId : String
shellId =
    "app-shell"


pageKeys : SideNav.Keys Page
pageKeys =
    SideNav.keys (\_ -> "overview")


view : Model -> Browser.Document Msg
view model =
    { title = "Stock overview"
    , body =
        [ Klar.stylesheet
        , AppShell.view
            [ AppShell.id shellId
            , AppShell.brand
                (AppShell.brandLink
                    { name = "Stock overview"
                    , href = "#/"
                    , logo = Just (Icon.sized Icon.Large Icon.warehouse)
                    }
                )
            , AppShell.sidebar (viewSidebar model)
            , AppShell.drawerOpen model.drawerOpen
            , AppShell.onToggleDrawer ToggleDrawer
            , AppShell.onCloseDrawer CloseDrawer
            , AppShell.onSkipToContent SkipToContent
            , AppShell.actions
                [ Switch.view
                    [ Switch.label "Simulate backend failure"
                    , Switch.checked (model.mode == Api.Failing)
                    , Switch.onToggle SimulateFailure
                    ]
                ]
            , AppShell.contentPadding
                (case model.density of
                    Compact ->
                        3

                    _ ->
                        5
                )
            , AppShell.overlays [ Toast.view ToastMsg [] model.toasts ]
            ]
            [ viewPage model ]
        ]
    }


viewSidebar : Model -> Html Msg
viewSidebar model =
    Layout.stack [ Layout.gap 3 ]
        [ SideNav.view SideNavMsg
            [ SideNav.entries
                [ SideNav.item pageKeys { key = Overview, label = "Stock overview", href = "#/" }
                    |> SideNav.withIcon Icon.dashboard
                ]
            , SideNav.current Overview
            ]
            model.sideNav
        , Layout.divider
        , Text.overline "Locations"
        , Button.view [ Button.ghost, Button.small, Button.icon Icon.globe, Button.onClick ResetFilters ] "All locations"
        , Tree.viewRemote TreeMsg
            ([ Tree.ariaLabel "Regions, warehouses and zones"
             , Tree.filterBox
             , Tree.onReload RetryRegions
             ]
                ++ (if model.density == Compact then
                        [ Tree.compact ]

                    else
                        []
                   )
            )
            model.tree
            (Remote.map (List.map regionNode) model.regions.remote)
        ]


regionNode : Data.Region -> Tree.Node Place
regionNode region =
    Tree.branch placeIds (InRegion region.id) region.name (List.map warehouseNode region.warehouses)
        |> Tree.withCount region.movements


warehouseNode : Data.Warehouse -> Tree.Node Place
warehouseNode warehouse =
    Tree.branch placeIds (InWarehouse warehouse.id) warehouse.name (List.map zoneNode warehouse.zones)
        |> Tree.withIcon Icon.warehouse
        |> (if warehouse.active then
                Tree.withCount warehouse.movements

            else
                Tree.withBadge Warning "No data"
           )


zoneNode : Data.Zone -> Tree.Node Place
zoneNode zone =
    Tree.leaf placeIds (InZone zone.id) zone.name
        |> Tree.withCount zone.movements


viewPage : Model -> Html Msg
viewPage model =
    Layout.stack [ Layout.gap 4 ]
        [ viewHeader model
        , viewNotices model
        , if hasNoData model then
            viewNoData model

          else
            viewContent model
        ]


hasNoData : Model -> Bool
hasNoData model =
    case model.summary.remote of
        Loaded summary ->
            not summary.hasData

        _ ->
            False


viewHeader : Model -> Html Msg
viewHeader model =
    let
        where_ =
            model.query.place |> Maybe.map Data.placeName |> Maybe.withDefault "All locations"
    in
    PageHeader.view
        [ PageHeader.title "Stock overview"
        , PageHeader.subtitle (where_ ++ ", " ++ Format.date Locale.en model.query.from ++ " to " ++ Format.date Locale.en model.query.to)
        , PageHeader.actions
            [ DateRangePicker.view PeriodMsg
                [ DateRangePicker.label "Period"
                , DateRangePicker.today Data.dataEnd
                , DateRangePicker.min Data.dataStart
                , DateRangePicker.max Data.dataEnd
                , DateRangePicker.maxRangeDays 120
                , DateRangePicker.alignEnd
                ]
                model.period
            , SegmentedControl.view
                [ SegmentedControl.ariaLabel "Density"
                , SegmentedControl.options
                    [ SegmentedControl.option "normal" "Normal"
                    , SegmentedControl.option "compact" "Compact"
                    ]
                , SegmentedControl.selected
                    (Just
                        (if model.density == Compact then
                            "compact"

                         else
                            "normal"
                        )
                    )
                , SegmentedControl.onSelect DensityChanged
                ]
            , Button.view
                [ Button.icon Icon.refresh
                , Button.onClick Refresh
                , Button.loading (anyBusy model)
                ]
                "Refresh"
            ]
        ]


anyBusy : Model -> Bool
anyBusy model =
    Feed.isBusy model.summary
        || Feed.isBusy model.levels
        || Feed.isBusy model.categories
        || Feed.isBusy model.transfers
        || Feed.isBusy model.movements


{-| One notice for everything that is old, so nobody reads old numbers by mistake.

-- KLAR GAP: stale data (R2S-002), see Feed.elm

-}
viewNotices : Model -> Html Msg
viewNotices model =
    let
        old =
            List.filterMap identity
                [ stale "locations" model.regions
                , stale "figures" model.summary
                , stale "stock level chart" model.levels
                , stale "movement chart" model.categories
                , stale "transfers" model.transfers
                , stale "movements" model.movements
                ]

        stale name feed =
            Maybe.map (\_ -> name) (Feed.staleError feed)
    in
    if List.isEmpty old then
        Html.text ""

    else
        Alert.view
            [ Alert.tone Warning
            , Alert.title "Some data is out of date"
            , Alert.actions [ Button.view [ Button.small, Button.onClick Refresh ] "Try again" ]
            ]
            ("The last refresh failed. Showing the previous data for: " ++ String.join ", " old ++ ".")


viewNoData : Model -> Html Msg
viewNoData model =
    EmptyState.view
        [ EmptyState.icon Icon.warehouse
        , EmptyState.title
            ((model.query.place |> Maybe.map Data.placeName |> Maybe.withDefault "This location") ++ " has no stock data")
        , EmptyState.description "No stock positions and no movements have been recorded here yet."
        , EmptyState.action (Button.view [ Button.onClick ResetFilters ] "Show all locations")
        ]


viewContent : Model -> Html Msg
viewContent model =
    Layout.stack [ Layout.gap 4 ]
        [ viewFigures model
        , Layout.grid [ Layout.minColumn 480, Layout.gap 4 ]
            [ viewLevels model
            , viewCategories model
            ]
        , viewMovements model
        , Layout.grid [ Layout.minColumn 420, Layout.gap 4 ]
            [ viewTransfers model
            , viewEvent model
            ]
        ]



-- FIGURES


periodLabel : Model -> String
periodLabel model =
    "vs. previous " ++ String.fromInt (Date.diffDays model.query.from model.query.to + 1) ++ " days"


viewFigures : Model -> Html Msg
viewFigures model =
    let
        feed =
            model.summary

        size =
            if model.density == Compact then
                Theme.Small

            else
                Theme.Medium

        tile label body =
            Stat.view
                [ Stat.label label
                , Stat.size size
                , Stat.onRetry RetrySummary
                , Stat.remote feed.remote
                    (\summary ->
                        body summary
                            ++ (case Feed.staleError feed of
                                    Just _ ->
                                        [ Stat.caption "Old data" ]

                                    Nothing ->
                                        []
                               )
                    )
                ]

        change metric =
            [ Stat.change { current = metric.current, previous = metric.previous }
            , Stat.deltaLabel (periodLabel model)
            , Stat.trend metric.trend
            ]
    in
    Stat.row
        [ tile "Stock value"
            (\s -> [ Stat.compact s.stockValue.current, Stat.unit "USD" ] ++ change s.stockValue)
        , tile "Items below reorder level"
            (\s -> [ Stat.int (round s.belowReorder.current), Stat.lowerIsBetter ] ++ change s.belowReorder)
        , tile "Open transfers"
            (\s -> [ Stat.int (round s.openTransfers.current), Stat.lowerIsBetter ] ++ change s.openTransfers)
        , tile "Turnover"
            (\s -> [ Stat.decimal 2 s.turnover.current, Stat.unit "x" ] ++ change s.turnover)
        ]



-- CHARTS


viewLevels : Model -> Html Msg
viewLevels model =
    let
        levels =
            Remote.withDefault { labels = [], onHand = [], reorder = [] } model.levels.remote
    in
    Card.view
        [ Card.headingLevel 2
        , Card.title "Stock level over time"
        , Card.subtitle "Units on hand, all items in the selection"
        , Card.actions (Feed.badge model.zone model.levels)
        ]
        [ Chart.line
            [ Chart.remote model.levels.remote
            , Chart.onRetry RetryLevels
            , Chart.ariaLabel "Stock level over time"
            , Chart.categories levels.labels
            , Chart.height 240
            ]
            [ Chart.series "On hand" levels.onHand
            , Chart.series "Reorder level" levels.reorder |> Chart.dashed
            ]
        ]


viewCategories : Model -> Html Msg
viewCategories model =
    let
        categories =
            Remote.withDefault [] model.categories.remote

        count kind category =
            category.counts
                |> List.filter (\( k, _ ) -> k == kind)
                |> List.head
                |> Maybe.map (Tuple.second >> toFloat)
                |> Maybe.withDefault 0
    in
    Card.view
        [ Card.headingLevel 2
        , Card.title "Movements by category"
        , Card.subtitle "Number of movements by type"
        , Card.actions (Feed.badge model.zone model.categories)
        ]
        [ Chart.bar
            [ Chart.remote model.categories.remote
            , Chart.onRetry RetryCategories
            , Chart.ariaLabel "Movements by category"
            , Chart.categories (List.map .name categories)
            , Chart.stacked
            , Chart.height 240
            ]
            (List.map (\kind -> Chart.series (Data.kindLabel kind) (List.map (count kind) categories)) Data.allKinds)
        ]



-- MOVEMENTS


viewMovements : Model -> Html Msg
viewMovements model =
    let
        feed =
            model.movements

        active =
            (if model.query.place == Nothing then
                0

             else
                1
            )
                + 1
    in
    Card.view
        [ Card.headingLevel 2
        , Card.title "Movements"
        , Card.subtitle
            (case feed.remote of
                Loaded rows ->
                    Format.int Locale.en (Array.length (Table.rowsArray rows)) ++ " movements in all"

                _ ->
                    "Loading ..."
            )
        , Card.actions
            (Feed.badge model.zone feed
                ++ [ SegmentedControl.view
                        [ SegmentedControl.ariaLabel "How to read the movements"
                        , SegmentedControl.size Theme.Small
                        , SegmentedControl.options
                            [ SegmentedControl.option "scroll" "Scroll"
                            , SegmentedControl.option "pages" "Pages"
                            ]
                        , SegmentedControl.selected
                            (Just
                                (if model.scrolling then
                                    "scroll"

                                 else
                                    "pages"
                                )
                            )
                        , SegmentedControl.onSelect ListModeChanged
                        ]
                   ]
            )
        , Card.flush
        ]
        [ Table.view TableMsg
            [ Table.label "Movements"
            , Table.columns columns
            , Table.preparedRows feed.remote
            , Table.rowId Table.intIds .number
            , Table.rowLabel .id
            , Table.searchable
            , if model.scrolling then
                Table.virtual

              else
                Table.pageSizes [ 25, 50, 100 ]
            , Table.maxHeight 520
            , Table.rowFilter (rowVisible model.query)
            , Table.activeExternalFilters active
            , Table.onResetFilters ResetFilters
            , Table.onRowClick SelectMovement
            , Table.onRetry RetryMovements
            , Table.refreshing feed.refreshing
            , Table.columnChooser
            , Table.exportCsv "movements.csv"
            ]
            model.table
        ]



-- TRANSFERS AND THE RAW EVENT


transferTone : Data.TransferStatus -> Tone
transferTone status =
    case status of
        Data.Requested ->
            Neutral

        Data.InTransit ->
            Info

        Data.Delayed ->
            Warning

        Data.Received ->
            Success


transferWord : Data.TransferStatus -> String
transferWord status =
    case status of
        Data.Requested ->
            "requested"

        Data.InTransit ->
            "in transit"

        Data.Delayed ->
            "delayed"

        Data.Received ->
            "received"


viewTransfers : Model -> Html Msg
viewTransfers model =
    let
        transfers =
            Remote.withDefault { items = [], hasMore = False } model.transfers.remote

        event transfer =
            let
                status =
                    Data.transferStatus model.query.to transfer
            in
            Timeline.event transfer.id
                transfer.requestedAt
                (transfer.id ++ " " ++ transferWord status)
                |> Timeline.withTone (transferTone status)
                |> Timeline.withIcon Icon.truck
                |> Timeline.withDescription
                    (String.fromInt transfer.quantity ++ " x " ++ transfer.item ++ " from " ++ transfer.from ++ " to " ++ transfer.to)
    in
    Card.view
        [ Card.headingLevel 2
        , Card.title "Latest transfers"
        , Card.subtitle "Between warehouses, up to the end of the period"
        , Card.actions (Feed.badge model.zone model.transfers)
        ]
        [ Timeline.view
            ([ Timeline.remote model.transfers.remote
             , Timeline.zone model.zone
             , Timeline.now model.now
             , Timeline.ariaLabel "Latest transfers"
             , Timeline.maxHeight 420
             , Timeline.onRetry RetryTransfers
             , Timeline.onLoadMore LoadMoreTransfers
             , Timeline.loadingMore model.transfers.refreshing
             , Timeline.hasMore transfers.hasMore
             , Timeline.emptyTitle "No transfers in this selection"
             ]
                ++ (case Feed.staleError model.transfers of
                        Just problem ->
                            [ Timeline.moreFailed problem ]

                        Nothing ->
                            []
                   )
                ++ (if model.density == Compact then
                        [ Timeline.compact ]

                    else
                        []
                   )
            )
            (List.map event transfers.items)
        ]


viewEvent : Model -> Html Msg
viewEvent model =
    Card.view
        [ Card.headingLevel 2
        , Card.title "Raw event"
        , Card.subtitle
            (case model.selected of
                Just movement ->
                    movement.id

                Nothing ->
                    "Select a movement in the table"
            )
        , Card.actions
            (case model.selected of
                Just _ ->
                    [ Button.view [ Button.ghost, Button.small, Button.onClick ClearMovement ] "Clear" ]

                Nothing ->
                    []
            )
        ]
        [ case model.selected of
            Just movement ->
                JsonViewer.view ViewerMsg
                    [ JsonViewer.toolbar
                    , JsonViewer.rootLabel "event"
                    , JsonViewer.ariaLabel "Raw event of the selected movement"
                    , JsonViewer.maxHeight 420
                    ]
                    model.viewer
                    (Data.encodeMovement movement)

            Nothing ->
                EmptyState.view
                    [ EmptyState.compact
                    , EmptyState.icon Icon.braces
                    , EmptyState.title "No movement selected"
                    , EmptyState.description "Click a row in the movements table to see the event as the warehouse system recorded it."
                    ]
        ]
