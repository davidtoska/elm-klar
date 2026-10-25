module Page.Gallery.StaleData exposing (Model, Msg, init, subscriptions, update, view)

{-| Gallery page: old and refreshing data.

One `Remote World` stands for what an application loads (the real one has a
`Remote` for each request). A switch of states puts it
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
import Klar.EmptyState as EmptyState
import Klar.Icon as Icon
import Klar.Ids as Ids exposing (Ids)
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
import Showcase.Config as Config
import Showcase.Doc as Doc
import Showcase.Options as Options
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
    , auto : Autocomplete.State String
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
    | AutoMsg (Autocomplete.Msg String)
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
      , tree = Tree.init "stale-regions" |> Tree.setExpandedIds Ids.string [ "North", "South" ]
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


view : Config.Config -> Settings -> Locale -> Model -> Html Msg
view playground settings locale model =
    Overlay.host
        { attributes = []
        , page =
            [ Doc.configuredPage playground
                { title = "Old and refreshing data"
                , description = "A Remote that is Kept: the data stays on the screen while it is refreshed, and when the last refresh failed it is marked as old, with the time and a retry. Choose a state, or press Refresh (and switch on the failing refresh to see the real flow). No component has an attribute for this."
                }
                [ controls playground model
                , Alert.stale (Options.klarAlert playground (List.concat [ Config.keep playground "Alert" "locale" (Alert.locale locale) ])) Refresh (Remote.staleIn "orders, figures, chart, history, regions and options" model.data)
                , Doc.configuredSection playground [] "Tables and tiles" "" [ tableExample playground settings locale model, tilesExample playground settings locale model ]
                , Doc.configuredSection playground [] "Charts and history" "" [ chartExample playground settings locale model, timelineExample playground settings locale model ]
                , Doc.configuredSection playground [] "Trees and lists of options" "" [ treeExample playground settings locale model, optionsExample playground settings locale model ]
                , Doc.configuredSection playground [] "Cards, drawers, dialogs and the palette" "" [ cardExample playground settings locale model, overlayButtons playground ]
                ]
            ]
        , overlays = overlays playground settings locale model
        }


controls : Config.Config -> Model -> Html Msg
controls playground model =
    Layout.row (Options.klarLayout playground (List.concat [ Config.keep playground "Layout" "gap" (Layout.gap 4), Config.keep playground "Layout" "wrap" Layout.wrap, Config.keep playground "Layout" "alignCenter" Layout.alignCenter ]))
        [ SegmentedControl.view
            (Options.klarSegmentedControl playground
                (List.concat
                    [ Config.keep playground "SegmentedControl" "label" (SegmentedControl.label "State of the data")
                    , Config.keep playground "SegmentedControl" "labelHidden" SegmentedControl.labelHidden
                    , Config.keep playground "SegmentedControl" "options" (SegmentedControl.options (List.map (\( name, _, text ) -> SegmentedControl.option name text) modes))

                    -- while the data refreshes no preset matches, and no segment is chosen
                    , Config.keep playground "SegmentedControl" "selected" (SegmentedControl.selected (Maybe.map modeValue model.mode |> Maybe.withDefault ""))
                    , Config.keep playground "SegmentedControl" "onChange" (SegmentedControl.onChange ModeChosen)
                    ]
                )
            )
        , Options.buttonView playground (Options.klarButton playground (List.concat [ Config.keep playground "Button" "icon" (Button.icon Icon.refresh), Config.keep playground "Button" "onClick" (Button.onClick Refresh) ])) "Refresh"
        , Switch.view
            (Options.klarSwitch playground
                (List.concat
                    [ Config.keep playground "Switch" "label" (Switch.label "Simulate failing refresh")
                    , Config.keep playground "Switch" "checked" (Switch.checked model.failing)
                    , Config.keep playground "Switch" "onCheck" (Switch.onCheck FailingToggled)
                    ]
                )
            )
        ]


card : String -> Html msg -> Html msg
card title content =
    Doc.example { title = title, description = Nothing, code = Nothing } content


tableExample : Config.Config -> Settings -> Locale -> Model -> Html Msg
tableExample playground settings locale model =
    card "Table"
        (Table.view TableMsg
            (Options.klarTable playground
                (List.concat
                    [ Config.keep playground "Table" "ariaLabel" (Table.ariaLabel "Orders")
                    , Config.keep playground "Table" "locale" (Table.locale locale)
                    , Config.keep playground "Table" "settings" (Table.settings settings)
                    , Config.keep playground
                        "Table"
                        "columns"
                        (Table.columns
                            [ Table.text (Table.columnId "id") "Order" .id []
                            , Table.text (Table.columnId "customer") "Customer" .customer []
                            , Table.float (Table.columnId "total") "Total" 2 .total []
                            ]
                        )
                    , Config.keep playground "Table" "remote" (Table.remote (Config.remote playground "Table" "remote" (Remote.map .orders model.data)))
                    , Config.keep playground "Table" "rowId" (Table.rowId Ids.string .id)
                    , Config.keep playground "Table" "onRetry" (Table.onRetry Refresh)
                    , Config.keep playground "Table" "onRefresh" (Table.onRefresh Refresh)
                    ]
                )
            )
            model.table
        )


tilesExample : Config.Config -> Settings -> Locale -> Model -> Html Msg
tilesExample playground settings locale model =
    let
        tile label toAttributes =
            Stat.view
                (Options.klarStat playground
                    (List.concat
                        [ Config.keep playground "Stat" "label" (Stat.label label)
                        , Config.keep playground "Stat" "locale" (Stat.locale locale)
                        , Config.keep playground "Stat" "settings" (Stat.settings settings)
                        , Config.keep playground "Stat" "onRetry" (Stat.onRetry Refresh)
                        , Config.keep playground "Stat" "remote" (Stat.remote model.data toAttributes)
                        ]
                    )
                )
    in
    card "Stat"
        (Layout.grid (Options.klarLayout playground (List.concat [ Config.keep playground "Layout" "minColumn" (Layout.minColumn 200), Config.keep playground "Layout" "gap" (Layout.gap 3) ]))
            [ tile "Open orders" (\w -> Options.klarStat playground (List.concat [ Config.keep playground "Stat" "int" (Stat.int w.open), Config.keep playground "Stat" "delta" (Stat.delta w.change) ]))
            , tile "Revenue" (\w -> Options.klarStat playground (List.concat [ Config.keep playground "Stat" "decimal" (Stat.decimal 2 (List.sum (List.map .total w.orders))), Config.keep playground "Stat" "caption" (Stat.caption "this week") ]))
            ]
        )


chartExample : Config.Config -> Settings -> Locale -> Model -> Html Msg
chartExample playground settings locale model =
    let
        sales =
            Remote.map .sales model.data
    in
    card "Chart"
        (Layout.stack (Options.klarLayout playground (List.concat [ Config.keep playground "Layout" "gap" (Layout.gap 3) ]))
            [ Chart.lineRemote
                (Options.klarChart playground
                    (List.concat
                        [ Config.keep playground "Chart" "title" (Chart.title "Sales per day")
                        , Config.keep playground "Chart" "locale" (Chart.locale locale)
                        , Config.keep playground "Chart" "settings" (Chart.settings settings)
                        , Config.keep playground "Chart" "onRetry" (Chart.onRetry Refresh)
                        , Config.keep playground "Chart" "height" (Chart.height 160)
                        ]
                    )
                )
                (Remote.map (\values -> Chart.byCategory [] [ Chart.series "Sales" values ]) sales)
            , Chart.sparklineRemote (Options.klarChart playground (List.concat [ Config.keep playground "Chart" "ariaLabel" (Chart.ariaLabel "Sales trend"), Config.keep playground "Chart" "locale" (Chart.locale locale), Config.keep playground "Chart" "settings" (Chart.settings settings) ])) sales
            ]
        )


timelineExample : Config.Config -> Settings -> Locale -> Model -> Html Msg
timelineExample playground settings locale model =
    card "Timeline"
        (Timeline.viewRemote
            (Options.klarTimeline playground
                (List.concat
                    [ Config.keep playground "Timeline" "ariaLabel" (Timeline.ariaLabel "Order history")
                    , Config.keep playground "Timeline" "locale" (Timeline.locale locale)
                    , Config.keep playground "Timeline" "settings" (Timeline.settings settings)
                    , Config.keep playground "Timeline" "onRetry" (Timeline.onRetry Refresh)
                    , Config.keep playground "Timeline" "compact" Timeline.compact
                    ]
                )
            )
            (Remote.map
                (.events >> List.map (\( id, hour, title ) -> Timeline.event id (Time.millisToPosix (hour * 3600 * 1000)) title))
                model.data
            )
        )


treeExample : Config.Config -> Settings -> Locale -> Model -> Html Msg
treeExample playground settings locale model =
    card "Tree"
        (Tree.viewRemote TreeMsg
            (Options.klarTree playground
                (List.concat
                    [ Config.keep playground "Tree" "ariaLabel" (Tree.ariaLabel "Regions")
                    , Config.keep playground "Tree" "locale" (Tree.locale locale)
                    , Config.keep playground "Tree" "settings" (Tree.settings settings)
                    , Config.keep playground "Tree" "onRetry" (Tree.onRetry Refresh)
                    ]
                )
            )
            model.tree
            (Remote.map
                (\w ->
                    List.map
                        (\( region, places ) -> Tree.branch Ids.string region region (List.map (\place -> Tree.leaf Ids.string place place) places))
                        w.regions
                )
                model.data
            )
        )


optionsExample : Config.Config -> Settings -> Locale -> Model -> Html Msg
optionsExample playground settings locale model =
    let
        options =
            Remote.map (\w -> List.map (\( value, label ) -> Select.option value label) w.warehouses) model.data
    in
    card "Select, MultiSelect and Autocomplete"
        (Layout.stack (Options.klarLayout playground (List.concat [ Config.keep playground "Layout" "gap" (Layout.gap 3) ]))
            [ Select.view SelectMsg
                (Options.klarSelect playground
                    (List.concat
                        [ Config.keep playground "Select" "label" (Select.label "Warehouse")
                        , Config.keep playground "Select" "locale" (Select.locale locale)
                        , Config.keep playground "Select" "settings" (Select.settings settings)
                        , Config.keep playground "Select" "remote" (Select.remote (Config.remote playground "Select" "remote" options))
                        , Config.keep playground "Select" "onRetry" (Select.onRetry Refresh)
                        ]
                    )
                )
                model.select
            , MultiSelect.view MultiMsg
                (Options.klarMultiSelect playground
                    (List.concat
                        [ Config.keep playground "MultiSelect" "label" (MultiSelect.label "Warehouses")
                        , Config.keep playground "MultiSelect" "locale" (MultiSelect.locale locale)
                        , Config.keep playground "MultiSelect" "settings" (MultiSelect.settings settings)
                        , Config.keep playground "MultiSelect" "remote" (MultiSelect.remote (Config.remote playground "MultiSelect" "remote" options))
                        , Config.keep playground "MultiSelect" "onRetry" (MultiSelect.onRetry Refresh)
                        ]
                    )
                )
                model.multi
            , Autocomplete.view AutoMsg
                (Options.klarAutocomplete playground
                    (List.concat
                        [ Config.keep playground "Autocomplete" "label" (Autocomplete.label "Find a warehouse")
                        , Config.keep playground "Autocomplete" "locale" (Autocomplete.locale locale)
                        , Config.keep playground "Autocomplete" "settings" (Autocomplete.settings settings)
                        , Config.keep playground "Autocomplete" "remote" (Autocomplete.remote (Config.remote playground "Autocomplete" "remote" options))
                        , Config.keep playground "Autocomplete" "onRetry" (Autocomplete.onRetry Refresh)
                        ]
                    )
                )
                model.auto
            ]
        )


{-| The body is one line: no `case`, no skeleton. An empty answer draws nothing and the
body says so (`emptyState`); the Refresh button inside the body keeps focus while the
refresh starts and ends, because the body is the same element in every state.
-}
detail : Config.Config -> Settings -> Locale -> Model -> List (Html Msg)
detail playground settings locale model =
    RemoteView.view
        (Options.klarRemoteView playground
            (List.concat
                [ Config.keep playground "RemoteView" "locale" (RemoteView.locale locale)
                , Config.keep playground "RemoteView" "settings" (RemoteView.settings settings)
                , Config.keep playground "RemoteView" "onRetry" (RemoteView.onRetry Refresh)
                , Config.keep playground "RemoteView" "loadingLabel" (RemoteView.loadingLabel "Loading order")
                , Config.keep playground "RemoteView" "emptyState" (RemoteView.emptyState (Options.klarEmptyState playground (List.concat [ Config.keep playground "EmptyState" "title" (EmptyState.title "No orders") ])))
                ]
            )
        )
        (Remote.map .orders model.data)
        (\orders ->
            case orders of
                [] ->
                    []

                first :: _ ->
                    [ Text.paragraph (first.id ++ " for " ++ first.customer)
                    , Text.secondary ("Total " ++ String.fromFloat first.total)
                    , Layout.row (Options.klarLayout playground []) [ Options.buttonView playground (Options.klarButton playground (List.concat [ Config.keep playground "Button" "small" Button.small, Config.keep playground "Button" "icon" (Button.icon Icon.refresh), Config.keep playground "Button" "onClick" (Button.onClick Refresh) ])) "Refresh" ]
                    ]
        )


cardExample : Config.Config -> Settings -> Locale -> Model -> Html Msg
cardExample playground settings locale model =
    card "Card"
        (Card.view (Options.klarCard playground (List.concat [ Config.keep playground "Card" "title" (Card.title "Order"), Config.keep playground "Card" "headingLevel" (Card.headingLevel 3) ])) (detail playground settings locale model))


overlayButtons : Config.Config -> Html Msg
overlayButtons playground =
    card "Drawer, dialog and command palette"
        (Layout.row (Options.klarLayout playground (List.concat [ Config.keep playground "Layout" "gap" (Layout.gap 3), Config.keep playground "Layout" "wrap" Layout.wrap ]))
            [ Options.buttonView playground (Options.klarButton playground (List.concat [ Config.keep playground "Button" "id" (Button.id "stale-open-drawer"), Config.keep playground "Button" "onClick" (Button.onClick OpenDrawer) ])) "Open drawer"
            , Options.buttonView playground (Options.klarButton playground (List.concat [ Config.keep playground "Button" "id" (Button.id "stale-open-modal"), Config.keep playground "Button" "onClick" (Button.onClick OpenModal) ])) "Open dialog"
            , Options.buttonView playground (Options.klarButton playground (List.concat [ Config.keep playground "Button" "id" (Button.id "stale-open-palette"), Config.keep playground "Button" "onClick" (Button.onClick OpenPalette) ])) "Open palette"
            ]
        )


overlays : Config.Config -> Settings -> Locale -> Model -> List (Overlay Msg)
overlays playground settings locale model =
    [ Drawer.view DrawerMsg
        (Options.klarDrawer playground
            (List.concat
                [ Config.keep playground "Drawer" "locale" (Drawer.locale locale)
                , Config.keep playground "Drawer" "footer" (Drawer.footer [ Options.buttonView playground (Options.klarButton playground (List.concat [ Config.keep playground "Button" "onClick" (Button.onClick CloseDrawer) ])) "Close" ])
                ]
            )
        )
        model.drawer
        "Order"
        (detail playground settings locale model)
    , Modal.view ModalMsg
        (Options.klarModal playground
            (List.concat
                [ Config.keep playground "Modal" "locale" (Modal.locale locale)
                , Config.keep playground "Modal" "footer" (Modal.footer [ Options.buttonView playground (Options.klarButton playground (List.concat [ Config.keep playground "Button" "onClick" (Button.onClick CloseModal) ])) "Close" ])
                ]
            )
        )
        model.modal
        "Order"
        (detail playground settings locale model)
    , CommandPalette.view PaletteMsg
        (Options.klarCommandPalette playground
            (List.concat
                [ Config.keep playground "CommandPalette" "locale" (CommandPalette.locale locale)
                , Config.keep playground "CommandPalette" "settings" (CommandPalette.settings settings)
                , Config.keep playground
                    "CommandPalette"
                    "sections"
                    (CommandPalette.sections
                        [ CommandPalette.remote "Orders"
                            (Remote.map (\w -> List.map (\order -> CommandPalette.item order.id (Picked order.id)) w.orders) model.data)
                            |> CommandPalette.onRetry Refresh
                        ]
                    )
                ]
            )
        )
        model.palette
    ]
