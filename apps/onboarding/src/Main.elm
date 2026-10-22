module Main exposing (main)

import Api
import Backend exposing (Store)
import Browser
import Browser.Navigation as Nav
import Detail
import Domain exposing (..)
import Flow
import Ids
import Html exposing (Html)
import Klar
import Klar.AppShell as AppShell
import Klar.Button as Button
import Klar.Card as Card
import Klar.ConfirmDialog as ConfirmDialog
import Klar.Icon as Icon
import Klar.Layout as Layout
import Klar.PageHeader as PageHeader
import Klar.Remote as Remote exposing (Remote)
import Klar.SegmentedControl as SegmentedControl
import Klar.SideNav as SideNav
import Klar.Table as Table
import Klar.Text as Text
import Klar.Theme as Theme
import Klar.Toast as Toast
import Url exposing (Url)


main : Program () Model Msg
main =
    Browser.application
        { init = init
        , update = update
        , view = view
        , subscriptions = \_ -> Sub.none
        , onUrlChange = UrlChanged
        , onUrlRequest = LinkClicked
        }



-- MODEL


type Route
    = ListRoute
    | NewRoute
    | DetailRoute SupplierId
    | EditRoute SupplierId
    | NotFoundRoute


type Page
    = ListPage ListModel
    | FlowPage Flow.Model
    | DetailPage Detail.Model
    | NotFoundPage


type alias ListModel =
    { suppliers : Remote (List Supplier)
    , table : Table.State SupplierId
    }


type alias Model =
    { key : Nav.Key
    , url : Url
    , store : Store
    , sim : Api.Sim
    , countries : Remote (List Country)
    , categories : Remote (List Category)
    , terms : Remote (List PaymentTerms)
    , page : Page
    , toasts : Toast.State Msg
    , sideNav : SideNav.State String
    , sidebarCollapsed : Bool
    , drawerOpen : Bool
    , leave : ConfirmDialog.State
    , pendingLeave : Maybe String
    , bypassGuard : Bool
    }


type Msg
    = LinkClicked Browser.UrlRequest
    | UrlChanged Url
    | CountriesLoaded (Result Remote.Problem ())
    | CategoriesLoaded (Result Remote.Problem ())
    | TermsLoaded (Result Remote.Problem ())
    | SuppliersLoaded (Result Remote.Problem ())
    | ListMsg ListMsg
    | DetailMsg Detail.Msg
    | FlowMsg Flow.Msg
    | ToastMsg Toast.Msg
    | SideNavMsg SideNav.Msg
    | ToggleSidebar
    | ToggleDrawer
    | CloseDrawer
    | SkipToContent
    | LeaveMsg ConfirmDialog.Msg
    | ConfirmLeave
    | CancelLeave
    | NextFault String
    | ReloadReferenceData
    | OtherUserEdits SupplierId
    | NoOp


type ListMsg
    = TableMsg Table.Msg
    | RetryList
    | OpenSupplier Supplier


init : () -> Url -> Nav.Key -> ( Model, Cmd Msg )
init _ url key =
    let
        model =
            { key = key
            , url = url
            , store = Backend.initialStore
            , sim = Api.initialSim
            , countries = Remote.Loading
            , categories = Remote.Loading
            , terms = Remote.Loading
            , page = NotFoundPage
            , toasts = Toast.init
            , sideNav = SideNav.init "main-nav"
            , sidebarCollapsed = False
            , drawerOpen = False
            , leave = ConfirmDialog.init Ids.leaveDialog
            , pendingLeave = Nothing
            , bypassGuard = False
            }

        ( routed, routeCmd ) =
            enterRoute (parseRoute url) model
    in
    ( routed, Cmd.batch [ routeCmd, loadReference model.sim ] )


loadReference : Api.Sim -> Cmd Msg
loadReference _ =
    Cmd.batch
        [ Api.call Api.initialSim CountriesLoaded
        , Api.call Api.initialSim CategoriesLoaded
        , Api.call Api.initialSim TermsLoaded
        ]


reloadReference : Model -> ( Model, Cmd Msg )
reloadReference model =
    -- the next request of the pretend network decides whether the reference data arrives
    ( { model | countries = Remote.Loading, categories = Remote.Loading, terms = Remote.Loading, sim = consume model.sim }
    , Cmd.batch
        [ Api.call model.sim CountriesLoaded
        , Api.call Api.initialSim CategoriesLoaded
        , Api.call Api.initialSim TermsLoaded
        ]
    )


consume : Api.Sim -> Api.Sim
consume sim =
    { sim | next = Api.Works }



-- ROUTES


parseRoute : Url -> Route
parseRoute url =
    case String.split "/" (Maybe.withDefault "/" url.fragment) |> List.filter (\s -> s /= "") of
        [] ->
            ListRoute

        [ "suppliers" ] ->
            ListRoute

        [ "new" ] ->
            NewRoute

        [ "suppliers", id ] ->
            String.toInt id |> Maybe.map (SupplierId >> DetailRoute) |> Maybe.withDefault NotFoundRoute

        [ "suppliers", id, "edit" ] ->
            String.toInt id |> Maybe.map (SupplierId >> EditRoute) |> Maybe.withDefault NotFoundRoute

        _ ->
            NotFoundRoute


supplierRows : Table.RowIds SupplierId
supplierRows =
    Table.rowIds
        { toKey = supplierIdToString
        , fromKey = \key -> String.toInt key |> Maybe.map SupplierId
        }


ctxOf : Model -> Flow.Ctx
ctxOf model =
    { countries = model.countries
    , categories = model.categories
    , terms = model.terms
    , store = model.store
    , sim = model.sim
    }


enterRoute : Route -> Model -> ( Model, Cmd Msg )
enterRoute route model =
    case route of
        ListRoute ->
            ( { model | page = ListPage { suppliers = Remote.Loading, table = Table.init "supplier-table" }, sim = consume model.sim }
            , Api.call model.sim SuppliersLoaded
            )

        NewRoute ->
            ( { model | page = FlowPage (Flow.init Nothing) }, Cmd.none )

        EditRoute id ->
            case Backend.supplierById model.store id of
                Just s ->
                    ( { model | page = FlowPage (Flow.init (Just s)) }, Cmd.none )

                Nothing ->
                    ( { model | page = NotFoundPage }, Cmd.none )

        DetailRoute id ->
            let
                ( detail, cmd, _ ) =
                    Detail.load (ctxOf model) (Detail.init id)
            in
            ( { model | page = DetailPage detail, sim = consume model.sim }, Cmd.map DetailMsg cmd )

        NotFoundRoute ->
            ( { model | page = NotFoundPage }, Cmd.none )


-- KLAR GAP: route guard for unsaved input, LinkClicked + UrlChanged + ConfirmDialog (O-017)
{-| Leaving the flow with unsaved input asks first.
-}
guarded : Model -> Bool
guarded model =
    case model.page of
        FlowPage flow ->
            Flow.isDirty flow

        _ ->
            False


navigate : String -> Model -> ( Model, Cmd Msg )
navigate target model =
    if guarded model then
        let
            ( dialog, cmd ) =
                ConfirmDialog.open "" model.leave
        in
        ( { model | leave = dialog, pendingLeave = Just target }, Cmd.map LeaveMsg cmd )

    else
        ( model, Nav.pushUrl model.key target )



-- UPDATE


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        NoOp ->
            ( model, Cmd.none )

        LinkClicked (Browser.External href) ->
            ( model, Nav.load href )

        LinkClicked (Browser.Internal url) ->
            if url.fragment == model.url.fragment then
                ( model, Cmd.none )

            else
                navigate (Url.toString url) model

        UrlChanged url ->
            if guarded model && not model.bypassGuard && parseRoute url /= parseRoute model.url then
                -- the browser's back button already moved the address: put it back and ask
                let
                    ( dialog, cmd ) =
                        ConfirmDialog.open "" model.leave
                in
                ( { model | leave = dialog, pendingLeave = Just (Url.toString url) }
                , Cmd.batch [ Cmd.map LeaveMsg cmd, Nav.pushUrl model.key (Url.toString model.url) ]
                )

            else
                let
                    ( entered, cmd ) =
                        enterRoute (parseRoute url) { model | url = url, bypassGuard = False, drawerOpen = False }
                in
                ( entered, Cmd.batch [ cmd, AppShell.resetScroll shellId NoOp ] )

        LeaveMsg inner ->
            let
                ( dialog, cmd ) =
                    ConfirmDialog.update inner model.leave
            in
            ( { model | leave = dialog }, Cmd.map LeaveMsg cmd )

        CancelLeave ->
            let
                ( dialog, cmd ) =
                    ConfirmDialog.close model.leave
            in
            ( { model | leave = dialog, pendingLeave = Nothing }, Cmd.map LeaveMsg cmd )

        ConfirmLeave ->
            let
                ( dialog, cmd ) =
                    ConfirmDialog.close model.leave
            in
            case model.pendingLeave of
                Just target ->
                    ( { model | leave = dialog, pendingLeave = Nothing, bypassGuard = True }
                    , Cmd.batch [ Cmd.map LeaveMsg cmd, Nav.pushUrl model.key target ]
                    )

                Nothing ->
                    ( { model | leave = dialog }, Cmd.map LeaveMsg cmd )

        CountriesLoaded result ->
            ( { model | countries = Result.map (\_ -> Backend.countries) result |> Remote.fromResult }, Cmd.none )

        CategoriesLoaded result ->
            ( { model | categories = Result.map (\_ -> Backend.categories) result |> Remote.fromResult }, Cmd.none )

        TermsLoaded result ->
            ( { model | terms = Result.map (\_ -> Backend.paymentTerms) result |> Remote.fromResult }, Cmd.none )

        SuppliersLoaded result ->
            case model.page of
                ListPage list ->
                    ( { model
                        | page =
                            ListPage
                                { list | suppliers = Result.map (\_ -> Backend.list model.store) result |> Remote.fromResult }
                      }
                    , Cmd.none
                    )

                _ ->
                    ( model, Cmd.none )

        ListMsg listMsg ->
            case model.page of
                ListPage list ->
                    case listMsg of
                        TableMsg inner ->
                            let
                                ( table, cmd ) =
                                    Table.update inner list.table
                            in
                            ( { model | page = ListPage { list | table = table } }, Cmd.map (TableMsg >> ListMsg) cmd )

                        RetryList ->
                            enterRoute ListRoute model

                        OpenSupplier s ->
                            navigate ("#/suppliers/" ++ supplierIdToString s.id) model

                _ ->
                    ( model, Cmd.none )

        DetailMsg inner ->
            case model.page of
                DetailPage detail ->
                    let
                        ( d, cmd, outs ) =
                            Detail.update (ctxOf model) inner detail
                    in
                    applyOuts outs { model | page = DetailPage d } (Cmd.map DetailMsg cmd)

                _ ->
                    ( model, Cmd.none )

        FlowMsg inner ->
            case model.page of
                FlowPage flow ->
                    let
                        ( f, cmd, outs ) =
                            Flow.update (ctxOf model) inner flow
                    in
                    applyOuts outs { model | page = FlowPage f } (Cmd.map FlowMsg cmd)

                _ ->
                    ( model, Cmd.none )

        ToastMsg inner ->
            let
                ( toasts, cmd ) =
                    Toast.update inner model.toasts
            in
            ( { model | toasts = toasts }, Cmd.map ToastMsg cmd )

        SideNavMsg inner ->
            let
                ( nav, cmd ) =
                    SideNav.update inner model.sideNav
            in
            ( { model | sideNav = nav }, Cmd.map SideNavMsg cmd )

        ToggleSidebar ->
            ( { model | sidebarCollapsed = not model.sidebarCollapsed }, Cmd.none )

        ToggleDrawer ->
            if model.drawerOpen then
                ( { model | drawerOpen = False }, AppShell.focusMenuButton shellId NoOp )

            else
                ( { model | drawerOpen = True }, SideNav.focusLink navKeys (navKey model.page) model.sideNav NoOp )

        CloseDrawer ->
            ( { model | drawerOpen = False }, AppShell.focusMenuButton shellId NoOp )

        SkipToContent ->
            ( model, AppShell.focusContent shellId NoOp )

        NextFault key ->
            let
                sim =
                    model.sim

                next =
                    case key of
                        "network" ->
                            Api.NetworkDown

                        "timeout" ->
                            Api.TimesOut

                        "server" ->
                            Api.ServerFails

                        _ ->
                            Api.Works
            in
            ( { model | sim = { sim | next = next } }, Cmd.none )

        ReloadReferenceData ->
            reloadReference model

        OtherUserEdits id ->
            ( { model | store = Backend.otherUserEdits id model.store }
            , Cmd.none
            )
                |> addToast Theme.Info "Another user saved a change to this supplier."


addToast : Theme.Tone -> String -> ( Model, Cmd Msg ) -> ( Model, Cmd Msg )
addToast tone text ( model, cmd ) =
    let
        ( toasts, toastCmd ) =
            Toast.push [ Toast.tone tone, Toast.message text ] model.toasts
    in
    ( { model | toasts = toasts }, Cmd.batch [ cmd, Cmd.map ToastMsg toastCmd ] )


applyOuts : List Flow.Out -> Model -> Cmd Msg -> ( Model, Cmd Msg )
applyOuts outs model cmd =
    List.foldl
        (\out ( m, c ) ->
            case out of
                Flow.StoreChanged store ->
                    ( { m | store = store }, c )

                Flow.ToastOut tone text ->
                    addToast tone text ( m, c )

                Flow.Navigate target ->
                    let
                        ( nm, nc ) =
                            navigate target m
                    in
                    ( nm, Cmd.batch [ c, nc ] )

                Flow.ReloadReference ->
                    let
                        ( nm, nc ) =
                            reloadReference m
                    in
                    ( nm, Cmd.batch [ c, nc ] )

                Flow.FaultUsed ->
                    ( { m | sim = consume m.sim }, c )
        )
        ( model, cmd )
        outs



-- VIEW


shellId : String
shellId =
    "app-shell"


navKeys : SideNav.Keys String
navKeys =
    SideNav.stringKeys


navKey : Page -> String
navKey page =
    case page of
        FlowPage flow ->
            if Flow.editingId flow == Nothing then
                "new"

            else
                "suppliers"

        _ ->
            "suppliers"


view : Model -> Browser.Document Msg
view model =
    let
        ctx =
            ctxOf model

        flowOverlays =
            case model.page of
                FlowPage flow ->
                    List.map (Html.map FlowMsg) (Flow.overlays ctx flow)

                _ ->
                    []

        flowModal =
            case model.page of
                FlowPage flow ->
                    Flow.modalOpen flow

                _ ->
                    False
    in
    { title = "Supplier onboarding"
    , body =
        [ AppShell.view
            [ AppShell.id shellId
            , AppShell.brand
                (AppShell.brandLink
                    { name = "Supplier onboarding"
                    , href = "#/"
                    , logo = Just (Icon.sized Icon.Large Icon.truck)
                    }
                )
            , AppShell.sidebar
                (SideNav.view SideNavMsg
                    [ SideNav.entries
                        [ SideNav.section "Suppliers"
                            [ SideNav.item navKeys { key = "suppliers", label = "All suppliers", href = "#/" }
                                |> SideNav.withIcon Icon.building
                            , SideNav.item navKeys { key = "new", label = "New supplier", href = "#/new" }
                                |> SideNav.withIcon Icon.plusCircle
                            ]
                        ]
                    , SideNav.current (navKey model.page)
                    ]
                    model.sideNav
                )
            , AppShell.sidebarCollapsed model.sidebarCollapsed
            , AppShell.onToggleSidebar ToggleSidebar
            , AppShell.drawerOpen model.drawerOpen
            , AppShell.onToggleDrawer ToggleDrawer
            , AppShell.onCloseDrawer CloseDrawer
            , AppShell.onSkipToContent SkipToContent
            , AppShell.onStrayDrop NoOp
            , AppShell.contentMaxWidth 1100
            , AppShell.modalOpen (flowModal || ConfirmDialog.isOpen model.leave)
            , AppShell.overlays
                (flowOverlays
                    ++ [ ConfirmDialog.view LeaveMsg
                            [ ConfirmDialog.warning
                            , ConfirmDialog.title "Leave without saving?"
                            , ConfirmDialog.message "The supplier you are filling in has not been saved."
                            , ConfirmDialog.consequences [ "Everything you entered is lost" ]
                            , ConfirmDialog.confirmLabel "Leave"
                            , ConfirmDialog.cancelLabel "Keep editing"
                            , ConfirmDialog.onConfirm ConfirmLeave
                            , ConfirmDialog.onCancel CancelLeave
                            ]
                            model.leave
                       , Toast.view ToastMsg [] model.toasts
                       ]
                )
            ]
            [ Layout.stack [ Layout.gap 6 ]
                [ Klar.stylesheet
                , viewPage ctx model
                , devPanel model
                ]
            ]
        ]
    }


viewPage : Flow.Ctx -> Model -> Html Msg
viewPage ctx model =
    case model.page of
        ListPage list ->
            viewList list

        FlowPage flow ->
            Html.map FlowMsg (Flow.view ctx flow)

        DetailPage detail ->
            Html.map DetailMsg (Detail.view ctx detail)

        NotFoundPage ->
            Text.paragraph "There is nothing here."


viewList : ListModel -> Html Msg
viewList list =
    Layout.stack [ Layout.gap 4 ]
        [ PageHeader.view
            [ PageHeader.title "Suppliers"
            , PageHeader.actions
                [ Button.view [ Button.primary, Button.icon Icon.plus, Button.href "#/new" ] "New supplier" ]
            ]
        , Html.map ListMsg
            (Table.view TableMsg
                [ Table.columns
                    [ Table.text (Table.columnId "name") "Name" .name [ Table.filterText ]
                    , Table.text (Table.columnId "reg") "Registration" .registrationNumber []
                    , Table.int (Table.columnId "contacts") "Contacts" (.contacts >> List.length) []
                    , Table.int (Table.columnId "rules") "Pricing rules" (.priceRules >> List.length) []
                    , Table.int (Table.columnId "version") "Version" .version []
                    ]
                , Table.rows list.suppliers
                , Table.rowId supplierRows .id
                , Table.searchable
                , Table.label "Suppliers"
                , Table.rowLabel .name
                , Table.onRowClick OpenSupplier
                , Table.onRetry RetryList
                ]
                list.table
            )
        ]


devPanel : Model -> Html Msg
devPanel model =
    let
        current =
            case model.sim.next of
                Api.Works ->
                    "works"

                Api.NetworkDown ->
                    "network"

                Api.TimesOut ->
                    "timeout"

                Api.ServerFails ->
                    "server"

        supplierId =
            case model.page of
                DetailPage d ->
                    Just d.id

                FlowPage f ->
                    Flow.editingId f

                _ ->
                    Nothing
    in
    Card.view [ Card.title "Developer controls", Card.headingLevel 2, Card.subtitle "Make the pretend backend misbehave", Card.sunken ]
        [ Layout.row [ Layout.gap 4, Layout.wrap, Layout.alignEnd ]
            [ SegmentedControl.view
                [ SegmentedControl.id "dev-next-request"
                , SegmentedControl.label "Next request"
                , SegmentedControl.selected (Just current)
                , SegmentedControl.onSelect NextFault
                , SegmentedControl.options
                    [ SegmentedControl.option "works" "Works"
                    , SegmentedControl.option "network" "Network error"
                    , SegmentedControl.option "timeout" "Timeout"
                    , SegmentedControl.option "server" "Server error"
                    ]
                ]
            , Button.view [ Button.id "dev-reload-reference", Button.onClick ReloadReferenceData ] "Reload reference data"
            , case supplierId of
                Just id ->
                    Button.view [ Button.id "dev-other-user", Button.onClick (OtherUserEdits id) ] "Another user edits this supplier"

                Nothing ->
                    Html.text ""
            ]
        , Text.muted "Server rules to try: registration number 12345678 is taken; contact emails ending in @blocked.example are refused; lead time above 90 days; discount above 25%; country Eastland."
        ]
