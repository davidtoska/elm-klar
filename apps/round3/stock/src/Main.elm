module Main exposing (main)

{-| Stock overview: a tree of regions, warehouses and zones that filters four figures, two charts,
a list of 50 000 movements, the latest transfers and the raw event of a movement.
-}

import Api
import Array exposing (Array)
import Backend exposing (MovementKind(..), NodeId(..))
import Browser
import Html exposing (Html)
import Json.Encode as Encode
import Klar
import Klar.Alert as Alert
import Klar.AppShell as AppShell
import Klar.Button as Button
import Klar.Card as Card
import Klar.Chart as Chart
import Klar.Date as Date
import Klar.DateRangePicker as DateRangePicker
import Klar.EmptyState as EmptyState
import Klar.Format as Format
import Klar.Icon as Icon
import Klar.JsonViewer as JsonViewer
import Klar.Layout as Layout
import Klar.Locale as Locale
import Klar.Money as Money
import Klar.PageHeader as PageHeader
import Klar.Remote as Remote exposing (Remote(..))
import Klar.SegmentedControl as SegmentedControl
import Klar.Stat as Stat
import Klar.Switch as Switch
import Klar.Table as Table
import Klar.Text as Text
import Klar.Theme as Theme exposing (Density(..), Tone(..))
import Klar.Timeline as Timeline
import Klar.Tree as Tree
import Set
import Time



-- MODEL


type TypeGroup
    = AllTypes
    | Receipts
    | Issues
    | Transfers
    | Adjustments


type alias Model =
    { period : DateRangePicker.State
    , query : Backend.Query
    , tree : Tree.State NodeId
    , table : Table.State Int
    , viewer : JsonViewer.State
    , typeGroup : TypeGroup
    , density : Density
    , outage : Bool
    , ticket : Int
    , selected : Maybe Int
    , structure : Remote (List Backend.RegionNode)
    , figures : Remote Backend.Figures
    , levels : Remote Backend.Levels
    , categories : Remote (List Backend.Categories)
    , transfers : Remote (List Backend.TransferRow)
    , movements : Remote (Table.Rows Backend.Movement)
    }


type Msg
    = PeriodMsg DateRangePicker.Msg
    | TreeMsg Tree.Msg
    | TableMsg Table.Msg
    | ViewerMsg JsonViewer.Msg
    | TypePicked String
    | DensityPicked String
    | OutageToggled Bool
    | RowClicked Backend.Movement
    | ResetFilters
    | Refresh
    | Retry Api.Panel
    | Got Int Time.Posix Answer


type Answer
    = GotStructure (Result Remote.Problem (List Backend.RegionNode))
    | GotFigures (Result Remote.Problem Backend.Figures)
    | GotLevels (Result Remote.Problem Backend.Levels)
    | GotCategories (Result Remote.Problem (List Backend.Categories))
    | GotTransfers (Result Remote.Problem (List Backend.TransferRow))
    | GotMovements (Result Remote.Problem (Array Backend.Movement))


main : Program () Model Msg
main =
    Browser.document
        { init = \_ -> init
        , update = update
        , view = view
        , subscriptions = \_ -> Sub.none
        }


nodeIds : Tree.Ids NodeId
nodeIds =
    Tree.nodeIds { toKey = nodeKey, fromKey = nodeFromKey }


nodeKey : NodeId -> String
nodeKey node =
    case node of
        RegionId n ->
            "r" ++ String.fromInt n

        WarehouseId n ->
            "w" ++ String.fromInt n

        ZoneId n ->
            "z" ++ String.fromInt n


nodeFromKey : String -> Maybe NodeId
nodeFromKey key =
    let
        number =
            String.toInt (String.dropLeft 1 key)
    in
    case String.left 1 key of
        "r" ->
            Maybe.map RegionId number

        "w" ->
            Maybe.map WarehouseId number

        "z" ->
            Maybe.map ZoneId number

        _ ->
            Nothing


movementIds : Table.RowIds Int
movementIds =
    Table.intIds


idPeriod : String
idPeriod =
    "period"


init : ( Model, Cmd Msg )
init =
    let
        today =
            Backend.lastDate

        from =
            Date.addDays -29 today

        model =
            { period =
                DateRangePicker.init idPeriod
                    |> DateRangePicker.setRange (Just ( from, today ))
            , query = { selection = Nothing, from = from, to = today }
            , tree =
                Tree.init "locations"
                    |> Tree.setExpanded nodeIds (List.map RegionId (List.range 1 5))
            , table = Table.init "movements" |> Table.setSort [ ( dateColumn, Table.Descending ) ]
            , viewer = JsonViewer.init "movement-json"
            , typeGroup = AllTypes
            , density = Normal
            , outage = False
            , ticket = 0
            , selected = Nothing
            , structure = Loading
            , figures = Loading
            , levels = Loading
            , categories = Loading
            , transfers = Loading
            , movements = Loading
            }
    in
    ( model, Cmd.batch (List.map (send model) allPanels) )


allPanels : List Api.Panel
allPanels =
    [ Api.StructurePanel, Api.FiguresPanel, Api.LevelsPanel, Api.CategoriesPanel, Api.TransfersPanel, Api.MovementsPanel ]


queryPanels : List Api.Panel
queryPanels =
    [ Api.FiguresPanel, Api.LevelsPanel, Api.CategoriesPanel, Api.TransfersPanel ]



-- UPDATE


send : Model -> Api.Panel -> Cmd Msg
send model panel =
    let
        env =
            { outage = model.outage }

        got answer =
            \result at -> Got model.ticket at (answer result)

        q =
            model.query
    in
    case panel of
        Api.StructurePanel ->
            Api.call env panel (\_ -> Backend.structure) (got GotStructure)

        Api.FiguresPanel ->
            Api.call env panel (\_ -> Backend.figures q) (got GotFigures)

        Api.LevelsPanel ->
            Api.call env panel (\_ -> Backend.levels q) (got GotLevels)

        Api.CategoriesPanel ->
            Api.call env panel (\_ -> Backend.categories q) (got GotCategories)

        Api.TransfersPanel ->
            Api.call env panel (\_ -> Backend.transfers q) (got GotTransfers)

        Api.MovementsPanel ->
            Api.call env panel (\_ -> Backend.movements) (got GotMovements)


{-| Data that is there stays (dimmed and busy); a panel with nothing yet shows its skeleton.
-}
refreshPanel : Api.Panel -> Model -> Model
refreshPanel panel model =
    case panel of
        Api.StructurePanel ->
            { model | structure = Remote.refresh model.structure }

        Api.FiguresPanel ->
            { model | figures = Remote.refresh model.figures }

        Api.LevelsPanel ->
            { model | levels = Remote.refresh model.levels }

        Api.CategoriesPanel ->
            { model | categories = Remote.refresh model.categories }

        Api.TransfersPanel ->
            { model | transfers = Remote.refresh model.transfers }

        Api.MovementsPanel ->
            { model | movements = Remote.refresh model.movements }


{-| Another selection or period is another question: the old answers do not apply.
-}
askAgain : Model -> ( Model, Cmd Msg )
askAgain model =
    let
        next =
            { model
                | ticket = model.ticket + 1
                , figures = Loading
                , levels = Loading
                , categories = Loading
                , transfers = Loading
            }
    in
    ( next, Cmd.batch (List.map (send next) queryPanels) )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        PeriodMsg m ->
            let
                ( period, cmd ) =
                    DateRangePicker.update m model.period

                moved =
                    { model | period = period }
            in
            case DateRangePicker.range period of
                Just ( from, to ) ->
                    if from /= model.query.from || to /= model.query.to then
                        let
                            ( next, ask ) =
                                askAgain { moved | query = { selection = model.query.selection, from = from, to = to } }
                        in
                        ( next, Cmd.batch [ Cmd.map PeriodMsg cmd, ask ] )

                    else
                        ( moved, Cmd.map PeriodMsg cmd )

                Nothing ->
                    ( moved, Cmd.map PeriodMsg cmd )

        TreeMsg m ->
            let
                ( tree, cmd ) =
                    Tree.update m model.tree

                selection =
                    Tree.selectedId nodeIds tree

                moved =
                    { model | tree = tree }
            in
            if selection /= model.query.selection then
                let
                    q =
                        model.query

                    ( next, ask ) =
                        askAgain { moved | query = { q | selection = selection } }
                in
                ( next, Cmd.batch [ Cmd.map TreeMsg cmd, ask ] )

            else
                ( moved, Cmd.map TreeMsg cmd )

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

        TypePicked key ->
            ( { model | typeGroup = typeFromKey key }, Cmd.none )

        DensityPicked key ->
            let
                density =
                    if key == "compact" then
                        Compact

                    else
                        Normal
            in
            ( { model | density = density, table = Table.setDensity density model.table }, Cmd.none )

        OutageToggled on ->
            ( { model | outage = on }, Cmd.none )

        RowClicked movement ->
            ( { model | selected = Just movement.id }, Cmd.none )

        ResetFilters ->
            let
                q =
                    model.query

                tree =
                    Tree.setSelected nodeIds [] model.tree

                moved =
                    { model | typeGroup = AllTypes, tree = tree }
            in
            if q.selection /= Nothing then
                askAgain { moved | query = { q | selection = Nothing } }

            else
                ( moved, Cmd.none )

        Refresh ->
            let
                next =
                    List.foldl refreshPanel { model | ticket = model.ticket + 1 } allPanels
            in
            ( next, Cmd.batch (List.map (send next) allPanels) )

        Retry panel ->
            let
                next =
                    refreshPanel panel model
            in
            ( next, send next panel )

        Got ticket at answer ->
            if ticket /= model.ticket && List.member (panelOf answer) queryPanels then
                ( model, Cmd.none )

            else
                ( store at answer model, Cmd.none )


panelOf : Answer -> Api.Panel
panelOf answer =
    case answer of
        GotStructure _ ->
            Api.StructurePanel

        GotFigures _ ->
            Api.FiguresPanel

        GotLevels _ ->
            Api.LevelsPanel

        GotCategories _ ->
            Api.CategoriesPanel

        GotTransfers _ ->
            Api.TransfersPanel

        GotMovements _ ->
            Api.MovementsPanel


store : Time.Posix -> Answer -> Model -> Model
store at answer model =
    case answer of
        GotStructure r ->
            { model | structure = Remote.refreshWith model.structure r at }

        GotFigures r ->
            { model | figures = Remote.refreshWith model.figures r at }

        GotLevels r ->
            { model | levels = Remote.refreshWith model.levels r at }

        GotCategories r ->
            { model | categories = Remote.refreshWith model.categories r at }

        GotTransfers r ->
            { model | transfers = Remote.refreshWith model.transfers r at }

        GotMovements r ->
            { model
                | movements =
                    Remote.refreshWith model.movements
                        (Result.map (Table.prepareRows Locale.en movementColumns) r)
                        at
            }


typeFromKey : String -> TypeGroup
typeFromKey key =
    case key of
        "receipts" ->
            Receipts

        "issues" ->
            Issues

        "transfers" ->
            Transfers

        "adjustments" ->
            Adjustments

        _ ->
            AllTypes


inGroup : TypeGroup -> MovementKind -> Bool
inGroup group kind =
    case ( group, kind ) of
        ( AllTypes, _ ) ->
            True

        ( Receipts, Receipt ) ->
            True

        ( Issues, Issue ) ->
            True

        ( Transfers, TransferOut ) ->
            True

        ( Transfers, TransferIn ) ->
            True

        ( Adjustments, Adjustment ) ->
            True

        _ ->
            False



-- VIEW


view : Model -> Browser.Document Msg
view model =
    { title = "Stock overview"
    , body =
        [ Klar.stylesheet
        , AppShell.view
            [ AppShell.id "shell"
            , AppShell.brand (AppShell.brandLink { name = "Stock overview", href = "#/", logo = Nothing })
            , AppShell.sidebar (viewTree model)
            , AppShell.actions
                [ Switch.view
                    [ Switch.label "Simulate outage"
                    , Switch.checked model.outage
                    , Switch.onToggle OutageToggled
                    , Switch.size Theme.Small
                    ]
                , densityPicker model.density
                ]
            ]
            [ viewPage model ]
        ]
    }


isCompact : Model -> Bool
isCompact model =
    model.density == Compact


selectionLabel : Model -> String
selectionLabel model =
    case model.query.selection of
        Nothing ->
            "All warehouses"

        Just node ->
            Backend.nodeLabel node


viewTree : Model -> Html Msg
viewTree model =
    Layout.stack [ Layout.gap 2, Layout.padding 2 ]
        [ Text.overline "Locations"
        , Tree.viewRemote TreeMsg
            ([ Tree.ariaLabel "Regions, warehouses and zones"
             , Tree.allowEmptySelection
             , Tree.filterBox
             , Tree.onReload (Retry Api.StructurePanel)
             ]
                ++ (if isCompact model then
                        [ Tree.compact ]

                    else
                        []
                   )
            )
            model.tree
            (Remote.map (List.map regionNode) model.structure)
        ]


regionNode : Backend.RegionNode -> Tree.Node NodeId
regionNode r =
    Tree.branch nodeIds (RegionId r.id) r.name (List.map warehouseNode r.warehouses)
        |> Tree.withIcon Icon.map
        |> Tree.withCount r.movements


warehouseNode : Backend.WarehouseNode -> Tree.Node NodeId
warehouseNode w =
    Tree.branch nodeIds (WarehouseId w.id) w.name (List.map zoneNode w.zones)
        |> Tree.withIcon Icon.warehouse
        |> Tree.withCount w.movements
        |> (if w.movements == 0 then
                Tree.withBadge Neutral "No data"

            else
                identity
           )


zoneNode : Backend.ZoneNode -> Tree.Node NodeId
zoneNode z =
    Tree.leaf nodeIds (ZoneId z.id) z.name
        |> Tree.withCount z.movements


densityPicker : Density -> Html Msg
densityPicker density =
    SegmentedControl.view
        [ SegmentedControl.ariaLabel "Density"
        , SegmentedControl.size Theme.Small
        , SegmentedControl.options
            [ SegmentedControl.option "normal" "Normal"
            , SegmentedControl.option "compact" "Compact"
            ]
        , SegmentedControl.selected
            (Just
                (if density == Compact then
                    "compact"

                 else
                    "normal"
                )
            )
        , SegmentedControl.onSelect DensityPicked
        ]


staleNames : Model -> List String
staleNames model =
    List.concat
        [ Remote.staleIn "figures" model.figures
        , Remote.staleIn "stock levels" model.levels
        , Remote.staleIn "movements by category" model.categories
        , Remote.staleIn "transfers" model.transfers
        , Remote.staleIn "movements" model.movements
        , Remote.staleIn "locations" model.structure
        ]


noData : Model -> Bool
noData model =
    case Remote.toMaybe model.figures of
        Just f ->
            not f.hasData

        Nothing ->
            False


viewPage : Model -> Html Msg
viewPage model =
    Layout.stack [ Layout.gap 4, Layout.padding 4 ]
        [ PageHeader.view
            [ PageHeader.title "Stock overview"
            , PageHeader.subtitle (selectionLabel model)
            , PageHeader.actions
                [ DateRangePicker.view PeriodMsg
                    [ DateRangePicker.label "Period"
                    , DateRangePicker.labelHidden
                    , DateRangePicker.today Backend.lastDate
                    , DateRangePicker.min Backend.firstDate
                    , DateRangePicker.max Backend.lastDate
                    , DateRangePicker.maxRangeDays 366
                    , DateRangePicker.size Theme.Small
                    ]
                    model.period
                , Button.view [ Button.icon Icon.refresh, Button.onClick Refresh, Button.small ] "Refresh"
                ]
            ]
        , Alert.stale [] Refresh (staleNames model)
        , if noData model then
            Alert.view [ Alert.tone Info, Alert.title "No stock data" ]
                (selectionLabel model ++ " has no stock and no movements. Choose another location in the tree.")

          else
            Html.text ""
        , Stat.row (viewStats model)
        , Layout.grid [ Layout.minColumn 420, Layout.gap 4 ]
            [ Card.view [ Card.title "Stock level", Card.subtitle "Units in stock, against the previous period" ] [ viewLevels model ]
            , Card.view [ Card.title "Movements by category", Card.subtitle "Inbound and outbound lines in the period" ] [ viewCategories model ]
            ]
        , Card.view [ Card.title "Movements", Card.subtitle (selectionLabel model), Card.flush ]
            [ Layout.stack [ Layout.gap 2 ]
                [ Layout.row [ Layout.padding 2 ] [ typePicker model.typeGroup ]
                , viewMovements model
                ]
            ]
        , Layout.grid [ Layout.minColumn 420, Layout.gap 4 ]
            [ Card.view [ Card.title "Latest transfers" ] [ viewTransfers model ]
            , Card.view [ Card.title "Selected movement", Card.subtitle "The raw event" ] [ viewEvent model ]
            ]
        ]



-- FIGURES


money : Int -> String
money minor =
    Money.fromMinor Money.usd minor
        |> Maybe.map (Money.toSymbolString Locale.en)
        |> Maybe.withDefault "-"


viewStats : Model -> List (Html Msg)
viewStats model =
    let
        common =
            [ Stat.onRetry (Retry Api.FiguresPanel), Stat.deltaLabel "vs. previous period" ]
                ++ (if isCompact model then
                        [ Stat.size Theme.Small ]

                    else
                        []
                   )

        change f current previous =
            if f.hasData && previous > 0 then
                [ Stat.change { current = current, previous = previous } ]

            else
                []
    in
    [ Stat.view
        ([ Stat.label "Stock value"
         , Stat.icon Icon.package
         , Stat.remote model.figures
            (\f ->
                Stat.value (money f.stockValue)
                    :: change f (toFloat f.stockValue) (toFloat f.previousStockValue)
            )
         ]
            ++ common
        )
    , Stat.view
        ([ Stat.label "Below reorder level"
         , Stat.caption "SKUs per zone under their level"
         , Stat.lowerIsBetter
         , Stat.remote model.figures
            (\f ->
                Stat.int f.belowReorder
                    :: change f (toFloat f.belowReorder) (toFloat f.previousBelowReorder)
            )
         ]
            ++ common
        )
    , Stat.view
        ([ Stat.label "Open transfers"
         , Stat.remote model.figures
            (\f ->
                Stat.int f.openTransfers
                    :: change f (toFloat f.openTransfers) (toFloat f.previousOpenTransfers)
            )
         ]
            ++ common
        )
    , Stat.view
        ([ Stat.label "Turnover"
         , Stat.caption "Issued value / stock value"
         , Stat.remote model.figures
            (\f ->
                Stat.decimal 2 f.turnover
                    :: Stat.unit "x"
                    :: change f f.turnover f.previousTurnover
            )
         ]
            ++ common
        )
    ]



-- CHARTS


viewLevels : Model -> Html Msg
viewLevels model =
    let
        levels =
            Remote.withDefault { days = [], current = [], previous = [] } model.levels

        empty =
            List.all (\v -> v == 0) levels.current
    in
    Chart.line
        [ Chart.remote model.levels
        , Chart.onRetry (Retry Api.LevelsPanel)
        , Chart.categories (List.map shortDate levels.days)
        , Chart.maxLabels 8
        , Chart.points False
        , Chart.height 240
        , Chart.valueFormat (\v -> Format.int Locale.en (round v))
        , Chart.emptyText "No stock for this selection"
        ]
        (if empty then
            []

         else
            [ Chart.series "This period" levels.current
            , Chart.seriesMaybe "Previous period" levels.previous |> Chart.dashed
            ]
        )


{-| KLAR GAP: Format has no short date (day and month name), so the chart gets month and day of the ISO date.
-}
shortDate : Date.Date -> String
shortDate date =
    String.dropLeft 5 (Date.toIso date)


viewCategories : Model -> Html Msg
viewCategories model =
    let
        rows =
            Remote.withDefault [] model.categories

        empty =
            List.all (\r -> r.inbound + r.outbound == 0) rows
    in
    Chart.bar
        [ Chart.remote model.categories
        , Chart.onRetry (Retry Api.CategoriesPanel)
        , Chart.categories (List.map .category rows)
        , Chart.height 240
        , Chart.valueFormat (\v -> Format.int Locale.en (round v))
        , Chart.emptyText "No movements for this selection"
        ]
        (if empty then
            []

         else
            [ Chart.series "Inbound" (List.map (.inbound >> toFloat) rows)
            , Chart.series "Outbound" (List.map (.outbound >> toFloat) rows)
            ]
        )



-- MOVEMENTS


dateColumn : Table.ColumnId
dateColumn =
    Table.columnId "date"


movementColumns : List (Table.Column Backend.Movement Msg)
movementColumns =
    [ Table.int (Table.columnId "id") "No." .id [ Table.width 84, Table.pinned ]
    , Table.date dateColumn "Date" .date [ Table.width 110 ]
    , Table.badge (Table.columnId "type") "Type" (\m -> ( kindTone m.kind, Backend.kindLabel m.kind )) [ Table.width 130 ]
    , Table.text (Table.columnId "sku") "SKU" .skuCode [ Table.width 100 ]
    , Table.text (Table.columnId "product") "Product" .product [ Table.minWidth 150 ]
    , Table.text (Table.columnId "category") "Category" .category [ Table.hiddenByDefault, Table.filterSelect ]
    , Table.text (Table.columnId "warehouse") "Warehouse" .warehouse [ Table.minWidth 130 ]
    , Table.text (Table.columnId "zone") "Zone" .zoneName [ Table.width 110 ]
    , Table.int (Table.columnId "quantity") "Quantity" .quantity [ Table.width 100, Table.alignRight ]
    , Table.text (Table.columnId "reference") "Reference" .reference [ Table.hiddenByDefault ]
    ]


kindTone : MovementKind -> Tone
kindTone kind =
    case kind of
        Receipt ->
            Success

        Issue ->
            Warning

        TransferOut ->
            Info

        TransferIn ->
            Info

        Adjustment ->
            Neutral


typePicker : TypeGroup -> Html Msg
typePicker group =
    SegmentedControl.view
        [ SegmentedControl.ariaLabel "Movement type"
        , SegmentedControl.size Theme.Small
        , SegmentedControl.options
            [ SegmentedControl.option "all" "All types"
            , SegmentedControl.option "receipts" "Receipts"
            , SegmentedControl.option "issues" "Issues"
            , SegmentedControl.option "transfers" "Transfers"
            , SegmentedControl.option "adjustments" "Adjustments"
            ]
        , SegmentedControl.selected (Just (typeKey group))
        , SegmentedControl.onSelect TypePicked
        ]


typeKey : TypeGroup -> String
typeKey group =
    case group of
        AllTypes ->
            "all"

        Receipts ->
            "receipts"

        Issues ->
            "issues"

        Transfers ->
            "transfers"

        Adjustments ->
            "adjustments"


viewMovements : Model -> Html Msg
viewMovements model =
    let
        zones =
            Backend.zonesOf model.query.selection

        outside =
            (if model.query.selection /= Nothing then
                1

             else
                0
            )
                + (if model.typeGroup /= AllTypes then
                    1

                   else
                    0
                  )
    in
    Table.view TableMsg
        ([ Table.columns movementColumns
        , Table.preparedRows model.movements
        , Table.rowId movementIds .id
        , Table.label "Movements"
        , Table.searchable
        , Table.searchPlaceholder "Search movements"
        , Table.virtual
        , Table.maxHeight 420
        , Table.columnChooser
        , Table.activeExternalFilters outside
        , Table.onResetFilters ResetFilters
        , Table.onRetry (Retry Api.MovementsPanel)
        , Table.onRowClick RowClicked
        , Table.rowTone
            (\m ->
                if Just m.id == model.selected then
                    Just Primary

                else
                    Nothing
            )
        , Table.rowLabel (\m -> "movement " ++ String.fromInt m.id)
        , Table.zone Time.utc
        ]
            ++ (if outside > 0 then
                    [ Table.rowFilter (\m -> Set.member m.zone zones && inGroup model.typeGroup m.kind) ]

                else
                    []
               )
        )
        model.table



-- TRANSFERS AND EVENT


viewTransfers : Model -> Html Msg
viewTransfers model =
    Timeline.view
        ([ Timeline.zone Time.utc
         , Timeline.now (Date.toPosix Time.utc Backend.lastDate)
         , Timeline.remote model.transfers
         , Timeline.onRetry (Retry Api.TransfersPanel)
         , Timeline.ariaLabel "Latest transfers"
         , Timeline.emptyTitle "No transfers"
         , Timeline.emptyDescription "Nothing has been moved to or from this selection yet."
         , Timeline.maxHeight 360
         ]
            ++ (if isCompact model then
                    [ Timeline.compact ]

                else
                    []
               )
        )
        (List.map toEvent (Remote.withDefault [] model.transfers))


toEvent : Backend.TransferRow -> Timeline.Event Msg
toEvent t =
    Timeline.event t.id (Date.toPosix Time.utc t.at) t.title
        |> Timeline.withDescription t.description
        |> Timeline.withTone
            (if t.done then
                Success

             else if t.late then
                Warning

             else
                Info
            )


viewEvent : Model -> Html Msg
viewEvent model =
    case model.selected |> Maybe.andThen (\id -> Array.get (id - 1) Backend.movements) of
        Just m ->
            JsonViewer.view ViewerMsg
                [ JsonViewer.toolbar, JsonViewer.rootLabel "movement", JsonViewer.ariaLabel "Raw event", JsonViewer.maxHeight 360 ]
                model.viewer
                (encodeMovement m)

        Nothing ->
            EmptyState.view
                [ EmptyState.icon Icon.search
                , EmptyState.title "No movement selected"
                , EmptyState.description "Click a row in the list to see its raw event."
                , EmptyState.compact
                ]


encodeMovement : Backend.Movement -> Encode.Value
encodeMovement m =
    let
        place =
            Backend.locate m.zone

        sku =
            Backend.skuOf m.sku
    in
    Encode.object
        ([ ( "id", Encode.int m.id )
         , ( "type", Encode.string (String.toLower (Backend.kindLabel m.kind)) )
         , ( "occurredOn", Encode.string (Date.toIso m.date) )
         , ( "location"
           , Encode.object
                [ ( "region", Encode.string place.region )
                , ( "warehouse", Encode.string place.warehouse )
                , ( "zone", Encode.string place.zone )
                ]
           )
         , ( "sku"
           , Encode.object
                [ ( "code", Encode.string sku.code )
                , ( "name", Encode.string sku.name )
                , ( "category", Encode.string sku.category )
                , ( "unitCostMinor", Encode.int sku.unitCost )
                , ( "reorderLevel", Encode.int sku.reorder )
                ]
           )
         , ( "quantity", Encode.int m.quantity )
         , ( "reference", Encode.string m.reference )
         , ( "source", Encode.object [ ( "system", Encode.string "wms" ), ( "batch", Encode.int (m.day * 7 + 3) ) ] )
         ]
        )
