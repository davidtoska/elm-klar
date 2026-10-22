module Page.Gallery.StaleData exposing (Model, Msg, init, subscriptions, update, view)

{-| Gallery page: old and refreshing data.

One `Remote World` stands for what an application loads (the real one has a
`Remote` for each request, see `apps/round2/stock`). A switch of states puts it
in every state at once (loading, empty, fresh, refreshing, old, retrying,
failed), so each component can be looked at in each state, and "Refresh" runs
the real thing: `Remote.refresh` when the request leaves, `Remote.refreshWith`
with the answer, which fails while "Simulate failing refresh" is on. No
component here has an attribute for any of it: they all draw what the `Remote`
says.

-}

import Html exposing (Html)
import Klar.Alert as Alert
import Klar.Autocomplete as Autocomplete
import Klar.Button as Button
import Klar.Card as Card
import Klar.Chart as Chart
import Klar.CommandPalette as CommandPalette
import Klar.Drawer as Drawer
import Klar.Icon as Icon
import Klar.Layout as Layout
import Klar.Locale exposing (Locale)
import Klar.Modal as Modal
import Klar.MultiSelect as MultiSelect
import Klar.Overlay as Overlay exposing (Overlay)
import Klar.Remote as Remote exposing (Remote(..))
import Klar.RemoteView as RemoteView
import Klar.SegmentedControl as SegmentedControl
import Klar.Select as Select
import Klar.Settings exposing (Settings)
import Klar.Stat as Stat
import Klar.Switch as Switch
import Klar.Table as Table
import Klar.Text as Text
import Klar.Timeline as Timeline
import Klar.Tree as Tree
import Process
import Showcase.Doc as Doc
import Task
import Time



-- DATA


type alias Order =
    { id : String, customer : String, total : Float }


type alias World =
    { revision : Int
    , orders : List Order
    , open : Int
    , change : Float
    , sales : List Float
    , events : List ( String, Int, String )
    , regions : List ( String, List String )
    , warehouses : List ( String, String )
    }


{-| What the backend answers on its n-th request. Every answer is a little
different, so a refresh can be seen to change something.
-}
world : Int -> World
world revision =
    { revision = revision
    , orders =
        [ { id = "ORD-1042", customer = "Ada Lovelace", total = 1280.5 + toFloat revision }
        , { id = "ORD-1043", customer = "Grace Hopper", total = 342 }
        , { id = "ORD-1044", customer = "Edsger Dijkstra", total = 87.25 }
        , { id = "ORD-1045", customer = "Barbara Liskov", total = 2210 }
        ]
    , open = 128 + 3 * revision
    , change = 4.2 - toFloat revision
    , sales = [ 12, 18, 9, 22, 17, 25 + toFloat revision * 3 ]
    , events =
        [ ( "e1", 1, "Order placed" )
        , ( "e2", 2, "Payment received" )
        , ( "e3", 3, "Picked in Rotterdam" )
        , ( "e4", 4 + revision, "Shipped" )
        ]
    , regions = [ ( "North", [ "Oslo", "Bergen" ] ), ( "South", [ "Rotterdam", "Antwerp" ] ) ]
    , warehouses = [ ( "oslo", "Oslo" ), ( "bergen", "Bergen" ), ( "rotterdam", "Rotterdam" ) ]
    }


emptyWorld : World
emptyWorld =
    { revision = 0, orders = [], open = 0, change = 0, sales = [], events = [], regions = [], warehouses = [] }


failure : Remote.Problem
failure =
    Remote.problem Remote.network


loadedAt : Time.Posix
loadedAt =
    Time.millisToPosix (14 * 3600 * 1000 + 5 * 60 * 1000)


laterAt : Time.Posix
laterAt =
    Time.millisToPosix (14 * 3600 * 1000 + 20 * 60 * 1000)



-- MODEL


type Mode
    = Loading_
    | Empty
    | Fresh
    | Refreshing
    | Old
    | Retrying
    | Failed_


modes : List ( String, Mode, String )
modes =
    [ ( "loading", Loading_, "Loading" )
    , ( "empty", Empty, "Empty" )
    , ( "fresh", Fresh, "Fresh" )
    , ( "refreshing", Refreshing, "Refreshing" )
    , ( "old", Old, "Old data" )
    , ( "retrying", Retrying, "Retrying old data" )
    , ( "failed", Failed_, "Failed" )
    ]


type alias Model =
    { data : Remote World
    , mode : Maybe Mode
    , failing : Bool
    , table : Table.State String
    , tree : Tree.State String
    , select : Select.State String
    , multi : MultiSelect.State String
    , auto : Autocomplete.State
    , drawer : Drawer.State
    , modal : Modal.State
    , palette : CommandPalette.State
    , lastPick : String
    }


type Msg
    = ModeChosen String
    | FailingToggled Bool
    | Refresh
    | Answered Time.Posix
    | TableMsg Table.Msg
    | TreeMsg Tree.Msg
    | SelectMsg (Select.Msg String)
    | MultiMsg (MultiSelect.Msg String)
    | AutoMsg Autocomplete.Msg
    | DrawerMsg Drawer.Msg
    | ModalMsg Modal.Msg
    | PaletteMsg CommandPalette.Msg
    | OpenDrawer
    | CloseDrawer
    | OpenModal
    | CloseModal
    | OpenPalette
    | Picked String


init : ( Model, Cmd Msg )
init =
    ( { data = settle Fresh
      , mode = Just Fresh
      , failing = False
      , table = Table.init "stale-orders"
      , tree = Tree.init "stale-regions" |> Tree.setExpanded Tree.stringIds [ "North", "South" ]
      , select = Select.init "stale-select"
      , multi = MultiSelect.init "stale-multi"
      , auto = Autocomplete.init "stale-auto"
      , drawer = Drawer.init "stale-drawer"
      , modal = Modal.init "stale-modal"
      , palette = CommandPalette.init "stale-palette"
      , lastPick = ""
      }
    , Cmd.none
    )


{-| The `Remote` for each state, made with the functions an application uses.
-}
settle : Mode -> Remote World
settle mode =
    let
        fresh =
            Remote.refreshWith Loading (Ok (world 0)) loadedAt

        old =
            Remote.refreshWith fresh (Err failure) laterAt
    in
    case mode of
        Loading_ ->
            Loading

        Empty ->
            Loaded emptyWorld

        Fresh ->
            fresh

        Refreshing ->
            Remote.refresh fresh

        Old ->
            old

        Retrying ->
            Remote.refresh old

        Failed_ ->
            Failed failure


modeFromValue : String -> Maybe Mode
modeFromValue value =
    modes
        |> List.filter (\( name, _, _ ) -> name == value)
        |> List.head
        |> Maybe.map (\( _, mode, _ ) -> mode)


modeValue : Mode -> String
modeValue mode =
    modes
        |> List.filter (\( _, other, _ ) -> other == mode)
        |> List.head
        |> Maybe.map (\( name, _, _ ) -> name)
        |> Maybe.withDefault ""



-- UPDATE


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        ModeChosen value ->
            case modeFromValue value of
                Just mode ->
                    ( { model | data = settle mode, mode = Just mode }, Cmd.none )

                Nothing ->
                    ( model, Cmd.none )

        FailingToggled on ->
            ( { model | failing = on }, Cmd.none )

        Refresh ->
            ( { model | data = Remote.refresh model.data, mode = Nothing }
            , Process.sleep 900 |> Task.andThen (\_ -> Time.now) |> Task.perform Answered
            )

        Answered now ->
            let
                revision =
                    Remote.toMaybe model.data |> Maybe.map .revision |> Maybe.withDefault 0

                answer =
                    if model.failing then
                        Err failure

                    else
                        Ok (world (revision + 1))
            in
            ( { model | data = Remote.refreshWith model.data answer now, mode = Nothing }, Cmd.none )

        TableMsg inner ->
            let
                ( table, cmd ) =
                    Table.update inner model.table
            in
            ( { model | table = table }, Cmd.map TableMsg cmd )

        TreeMsg inner ->
            let
                ( tree, cmd ) =
                    Tree.update inner model.tree
            in
            ( { model | tree = tree }, Cmd.map TreeMsg cmd )

        SelectMsg inner ->
            let
                ( select, cmd ) =
                    Select.update inner model.select
            in
            ( { model | select = select }, Cmd.map SelectMsg cmd )

        MultiMsg inner ->
            let
                ( multi, cmd ) =
                    MultiSelect.update inner model.multi
            in
            ( { model | multi = multi }, Cmd.map MultiMsg cmd )

        AutoMsg inner ->
            let
                ( auto, cmd ) =
                    Autocomplete.update inner model.auto
            in
            ( { model | auto = auto }, Cmd.map AutoMsg cmd )

        DrawerMsg inner ->
            let
                ( drawer, cmd ) =
                    Drawer.update inner model.drawer
            in
            ( { model | drawer = drawer }, Cmd.map DrawerMsg cmd )

        ModalMsg inner ->
            let
                ( modal, cmd ) =
                    Modal.update inner model.modal
            in
            ( { model | modal = modal }, Cmd.map ModalMsg cmd )

        PaletteMsg inner ->
            let
                ( palette, cmd ) =
                    CommandPalette.update inner model.palette
            in
            ( { model | palette = palette }, Cmd.map PaletteMsg cmd )

        OpenDrawer ->
            let
                ( drawer, cmd ) =
                    Drawer.open "stale-open-drawer" model.drawer
            in
            ( { model | drawer = drawer }, Cmd.map DrawerMsg cmd )

        CloseDrawer ->
            let
                ( drawer, cmd ) =
                    Drawer.close model.drawer
            in
            ( { model | drawer = drawer }, Cmd.map DrawerMsg cmd )

        OpenModal ->
            let
                ( modal, cmd ) =
                    Modal.open "stale-open-modal" model.modal
            in
            ( { model | modal = modal }, Cmd.map ModalMsg cmd )

        CloseModal ->
            let
                ( modal, cmd ) =
                    Modal.close model.modal
            in
            ( { model | modal = modal }, Cmd.map ModalMsg cmd )

        OpenPalette ->
            let
                ( palette, cmd ) =
                    CommandPalette.open "stale-open-palette" model.palette
            in
            ( { model | palette = palette }, Cmd.map PaletteMsg cmd )

        Picked id ->
            let
                ( palette, cmd ) =
                    CommandPalette.close model.palette
            in
            ( { model | palette = palette, lastPick = id }, Cmd.map PaletteMsg cmd )


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none



-- VIEW


view : Settings -> Locale -> Model -> Html Msg
view settings locale model =
    Overlay.host
        { attributes = []
        , page =
            [ Doc.page
                { title = "Old and refreshing data"
                , description = "A Remote that is Kept: the data stays on the screen while it is refreshed, and when the last refresh failed it is marked as old, with the time and a retry. Choose a state, or press Refresh (and switch on the failing refresh to see the real flow). No component has an attribute for this."
                }
                [ controls model
                , Alert.stale [ Alert.locale locale ] Refresh (Remote.staleIn "orders, figures, chart, history, regions and options" model.data)
                , Doc.section "Tables and tiles" "" [ tableExample settings locale model, tilesExample settings locale model ]
                , Doc.section "Charts and history" "" [ chartExample settings locale model, timelineExample settings locale model ]
                , Doc.section "Trees and lists of options" "" [ treeExample settings locale model, optionsExample settings locale model ]
                , Doc.section "Cards, drawers, dialogs and the palette" "" [ cardExample settings locale model, overlayButtons ]
                ]
            ]
        , overlays = overlays settings locale model
        }


controls : Model -> Html Msg
controls model =
    Layout.row [ Layout.gap 4, Layout.wrap, Layout.alignCenter ]
        [ SegmentedControl.view
            [ SegmentedControl.ariaLabel "State of the data"
            , SegmentedControl.options (List.map (\( name, _, text ) -> SegmentedControl.option name text) modes)
            , SegmentedControl.selected (Maybe.map modeValue model.mode)
            , SegmentedControl.onSelect ModeChosen
            ]
        , Button.view [ Button.icon Icon.refresh, Button.onClick Refresh ] "Refresh"
        , Switch.view
            [ Switch.label "Simulate failing refresh"
            , Switch.checked model.failing
            , Switch.onToggle FailingToggled
            ]
        ]


card : String -> Html msg -> Html msg
card title content =
    Doc.example { title = title, description = Nothing, code = Nothing } content


tableExample : Settings -> Locale -> Model -> Html Msg
tableExample settings locale model =
    card "Table"
        (Table.view TableMsg
            [ Table.label "Orders"
            , Table.locale locale
            , Table.settings settings
            , Table.columns
                [ Table.text (Table.columnId "id") "Order" .id []
                , Table.text (Table.columnId "customer") "Customer" .customer []
                , Table.float (Table.columnId "total") "Total" 2 .total []
                ]
            , Table.rows (Remote.map .orders model.data)
            , Table.rowId Table.stringIds .id
            , Table.onRetry Refresh
            , Table.onRefresh Refresh
            ]
            model.table
        )


tilesExample : Settings -> Locale -> Model -> Html Msg
tilesExample settings locale model =
    let
        tile label toAttributes =
            Stat.view
                [ Stat.label label
                , Stat.locale locale
                , Stat.settings settings
                , Stat.onRetry Refresh
                , Stat.remote model.data toAttributes
                ]
    in
    card "Stat"
        (Layout.grid [ Layout.minColumn 200, Layout.gap 3 ]
            [ tile "Open orders" (\w -> [ Stat.int w.open, Stat.delta w.change ])
            , tile "Revenue" (\w -> [ Stat.decimal 2 (List.sum (List.map .total w.orders)), Stat.caption "this week" ])
            ]
        )


chartExample : Settings -> Locale -> Model -> Html Msg
chartExample settings locale model =
    let
        remoteChart =
            Chart.remote model.data

        values =
            Remote.map .sales model.data |> Remote.withDefault []
    in
    card "Chart"
        (Layout.stack [ Layout.gap 3 ]
            [ Chart.line
                [ Chart.title "Sales per day"
                , Chart.locale locale
                , Chart.settings settings
                , Chart.onRetry Refresh
                , Chart.height 160
                , remoteChart
                ]
                [ Chart.series "Sales" values ]
            , Chart.sparkline [ Chart.ariaLabel "Sales trend", Chart.locale locale, Chart.settings settings, remoteChart ] values
            ]
        )


timelineExample : Settings -> Locale -> Model -> Html Msg
timelineExample settings locale model =
    card "Timeline"
        (Timeline.view
            [ Timeline.ariaLabel "Order history"
            , Timeline.locale locale
            , Timeline.settings settings
            , Timeline.onRetry Refresh
            , Timeline.remote model.data
            , Timeline.compact
            ]
            (Remote.map .events model.data
                |> Remote.withDefault []
                |> List.map (\( id, hour, title ) -> Timeline.event id (Time.millisToPosix (hour * 3600 * 1000)) title)
            )
        )


treeExample : Settings -> Locale -> Model -> Html Msg
treeExample settings locale model =
    card "Tree"
        (Tree.viewRemote TreeMsg
            [ Tree.ariaLabel "Regions"
            , Tree.locale locale
            , Tree.settings settings
            , Tree.onReload Refresh
            ]
            model.tree
            (Remote.map
                (\w ->
                    List.map
                        (\( region, places ) -> Tree.branch Tree.stringIds region region (List.map (\place -> Tree.leaf Tree.stringIds place place) places))
                        w.regions
                )
                model.data
            )
        )


optionsExample : Settings -> Locale -> Model -> Html Msg
optionsExample settings locale model =
    let
        options =
            Remote.map (\w -> List.map (\( value, label ) -> Select.option value label) w.warehouses) model.data
    in
    card "Select, MultiSelect and Autocomplete"
        (Layout.stack [ Layout.gap 3 ]
            [ Select.view SelectMsg
                [ Select.label "Warehouse"
                , Select.locale locale
                , Select.settings settings
                , Select.remote options
                , Select.onRetry Refresh
                ]
                model.select
            , MultiSelect.view MultiMsg
                [ MultiSelect.label "Warehouses"
                , MultiSelect.locale locale
                , MultiSelect.settings settings
                , MultiSelect.remote options
                , MultiSelect.onRetry Refresh
                ]
                model.multi
            , Autocomplete.view AutoMsg
                [ Autocomplete.label "Find a warehouse"
                , Autocomplete.locale locale
                , Autocomplete.settings settings
                , Autocomplete.suggestions options
                , Autocomplete.onRetry Refresh
                ]
                model.auto
            ]
        )


{-| The body is one line: no `case`, no skeleton.
-}
detail : Settings -> Locale -> Model -> List (Html Msg)
detail settings locale model =
    RemoteView.view
        [ RemoteView.locale locale
        , RemoteView.settings settings
        , RemoteView.onRetry Refresh
        , RemoteView.loadingLabel "Loading order"
        ]
        (Remote.map .orders model.data)
        (\orders ->
            case orders of
                [] ->
                    [ Text.paragraph "There are no orders." ]

                first :: _ ->
                    [ Text.paragraph (first.id ++ " for " ++ first.customer)
                    , Text.secondary ("Total " ++ String.fromFloat first.total)
                    ]
        )


cardExample : Settings -> Locale -> Model -> Html Msg
cardExample settings locale model =
    card "Card"
        (Card.view [ Card.title "Order", Card.headingLevel 3 ] (detail settings locale model))


overlayButtons : Html Msg
overlayButtons =
    card "Drawer, dialog and command palette"
        (Layout.row [ Layout.gap 3, Layout.wrap ]
            [ Button.view [ Button.id "stale-open-drawer", Button.onClick OpenDrawer ] "Open drawer"
            , Button.view [ Button.id "stale-open-modal", Button.onClick OpenModal ] "Open dialog"
            , Button.view [ Button.id "stale-open-palette", Button.onClick OpenPalette ] "Open palette"
            ]
        )


overlays : Settings -> Locale -> Model -> List (Overlay Msg)
overlays settings locale model =
    [ Drawer.view DrawerMsg
        [ Drawer.title "Order"
        , Drawer.locale locale
        , Drawer.footer [ Button.view [ Button.onClick CloseDrawer ] "Close" ]
        ]
        model.drawer
        (detail settings locale model)
    , Modal.view ModalMsg
        [ Modal.title "Order"
        , Modal.locale locale
        , Modal.footer [ Button.view [ Button.onClick CloseModal ] "Close" ]
        ]
        model.modal
        (detail settings locale model)
    , CommandPalette.view PaletteMsg
        [ CommandPalette.locale locale
        , CommandPalette.settings settings
        , CommandPalette.sections
            [ CommandPalette.remote "Orders"
                (Remote.map (\w -> List.map (\order -> CommandPalette.item order.id (Picked order.id)) w.orders) model.data)
                |> CommandPalette.onRetry Refresh
            ]
        ]
        model.palette
    ]
