module Main exposing (main)

import Api
import Backend exposing (Behaviour, Db)
import Browser
import Browser.Navigation as Nav
import Detail
import Domain exposing (..)
import Flow
import Html exposing (Html)
import Klar
import Klar.Alert as Alert
import Klar.AppShell as AppShell
import Klar.Button as Button
import Klar.Card as Card
import Klar.Form as Form
import Klar.Icon as Icon
import Klar.Layout as Layout
import Klar.LeaveGuard as LeaveGuard exposing (Answer(..))
import Klar.Overlay as Overlay exposing (Overlay)
import Klar.PageHeader as PageHeader
import Klar.Remote as Remote exposing (Remote(..))
import Klar.SideNav as SideNav
import Klar.Switch as Switch
import Klar.Table as Table
import Klar.Text as Text
import Klar.Theme exposing (Tone(..))
import Klar.Toast as Toast
import Url exposing (Url)



-- ROUTES


type Route
    = Suppliers
    | NewSupplier
    | SupplierRoute SupplierId
    | EditSupplier SupplierId
    | NotFound


routeFromUrl : Url -> Route
routeFromUrl url =
    case url.fragment |> Maybe.withDefault "/" |> String.split "/" |> List.filter (not << String.isEmpty) of
        [] ->
            Suppliers

        [ "suppliers" ] ->
            Suppliers

        [ "suppliers", "new" ] ->
            NewSupplier

        [ "suppliers", id ] ->
            supplierIdFromString id |> Maybe.map SupplierRoute |> Maybe.withDefault NotFound

        [ "suppliers", id, "edit" ] ->
            supplierIdFromString id |> Maybe.map EditSupplier |> Maybe.withDefault NotFound

        _ ->
            NotFound


routeToUrl : Route -> String
routeToUrl route =
    case route of
        Suppliers ->
            "#/suppliers"

        NewSupplier ->
            "#/suppliers/new"

        SupplierRoute id ->
            "#/suppliers/" ++ supplierIdToString id

        EditSupplier id ->
            "#/suppliers/" ++ supplierIdToString id ++ "/edit"

        NotFound ->
            "#/suppliers"


type NavKey
    = NavSuppliers
    | NavNew


navKeys : SideNav.Keys NavKey
navKeys =
    SideNav.keys
        (\key ->
            case key of
                NavSuppliers ->
                    "suppliers"

                NavNew ->
                    "new"
        )


navKeyOf : Route -> NavKey
navKeyOf route =
    case route of
        NewSupplier ->
            NavNew

        EditSupplier _ ->
            NavNew

        _ ->
            NavSuppliers


navigation : List (SideNav.Entry NavKey msg)
navigation =
    [ SideNav.section "Procurement"
        [ SideNav.item navKeys { key = NavSuppliers, label = "Suppliers", href = "#/suppliers" }
            |> SideNav.withIcon Icon.truck
        , SideNav.item navKeys { key = NavNew, label = "Onboard a supplier", href = "#/suppliers/new" }
            |> SideNav.withIcon Icon.userPlus
        ]
    ]


{-| What the leave guard holds while it asks: where the user wanted to go.
-}
type Target
    = Go Route
    | GoBack


type Source
    = FlowSource



-- MODEL


type Page
    = ListPage
    | FlowPage Flow.Model
    | DetailPage Detail.Model
    | MissingPage


type alias Model =
    { key : Nav.Key
    , route : Route
    , page : Page
    , pushing : Maybe Route
    , restoring : Maybe Route -- KLAR GAP: Back-button recipe of LeaveGuard (R2O-009, R2O-010)
    , sideNav : SideNav.State NavKey
    , guard : LeaveGuard.Guard Source Target
    , toasts : Toast.State Msg
    , db : Db
    , behaviour : Behaviour
    , lookups : Remote Lookups
    , suppliers : Remote (List Supplier)
    , table : Table.State SupplierId
    }


type Msg
    = LinkClicked Browser.UrlRequest
    | UrlChanged Url
    | SideNavMsg SideNav.Msg
    | TableMsg Table.Msg
    | GuardMsg LeaveGuard.Msg
    | ToastMsg Toast.Msg
    | FlowMsg Flow.Msg
    | DetailMsg Detail.Msg
    | GotLookups (Result Remote.Problem Lookups)
    | GotSuppliers (Result Remote.Problem (List Supplier))
    | ReloadLookups
    | OpenSupplier SupplierId
    | SetOffline Bool
    | SetSomeoneElse Bool
    | NoOp


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


shellId : String
shellId =
    "app-shell"


init : () -> Url -> Nav.Key -> ( Model, Cmd Msg )
init _ url key =
    let
        route =
            routeFromUrl url

        base =
            { key = key
            , route = route
            , page = ListPage
            , pushing = Nothing
            , restoring = Nothing
            , sideNav = SideNav.init "main-nav" |> SideNav.reveal (navKeyOf route) navigation
            , guard = LeaveGuard.init "leave-dialog"
            , toasts = Toast.init
            , db = Backend.seed
            , behaviour = Backend.calm
            , lookups = Loading
            , suppliers = Loading
            , table = Table.init "suppliers"
            }

        ( model, cmd ) =
            enterRoute route base
    in
    ( model
    , Cmd.batch
        [ cmd
        , Api.loadLookups GotLookups
        , Api.loadSuppliers Backend.seed GotSuppliers
        ]
    )


enterRoute : Route -> Model -> ( Model, Cmd Msg )
enterRoute route model =
    let
        base =
            { model
                | route = route
                , sideNav = SideNav.reveal (navKeyOf route) navigation model.sideNav
            }

        resetScroll =
            AppShell.resetScroll shellId NoOp
    in
    case route of
        Suppliers ->
            ( { base | page = ListPage }, Cmd.batch [ resetScroll, AppShell.focusContent shellId NoOp ] )

        NewSupplier ->
            ( { base | page = FlowPage Flow.init }
            , Cmd.batch [ resetScroll, Form.focusField "company-name" NoOp ]
            )

        EditSupplier id ->
            case Backend.supplierById model.db id of
                Just supplier ->
                    ( { base | page = FlowPage (Flow.initEditing supplier) }
                    , Cmd.batch [ resetScroll, Form.focusField "company-name" NoOp ]
                    )

                Nothing ->
                    ( { base | page = MissingPage }, resetScroll )

        SupplierRoute id ->
            case Backend.supplierById model.db id of
                Just supplier ->
                    ( { base | page = DetailPage (Detail.init supplier) }
                    , Cmd.batch [ resetScroll, AppShell.focusContent shellId NoOp ]
                    )

                Nothing ->
                    ( { base | page = MissingPage }, resetScroll )

        NotFound ->
            ( { base | page = MissingPage }, resetScroll )




{-| Every navigation goes through the guard.
-}
navigate : Target -> Model -> ( Model, Cmd Msg )
navigate target model =
    case LeaveGuard.request target model.guard of
        Proceed (Go route) ->
            go route model

        Proceed GoBack ->
            ( model, Nav.back model.key 1 )

        Hold guard cmd ->
            ( { model | guard = guard }, Cmd.map GuardMsg cmd )


go : Route -> Model -> ( Model, Cmd Msg )
go route model =
    if route == model.route then
        ( model, AppShell.focusContent shellId NoOp )

    else
        ( { model | pushing = Just route }, Nav.pushUrl model.key (routeToUrl route) )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        LinkClicked (Browser.Internal url) ->
            navigate (Go (routeFromUrl url)) model

        LinkClicked (Browser.External href) ->
            ( model, Nav.load href )

        UrlChanged url ->
            let
                route =
                    routeFromUrl url
            in
            if Just route == model.pushing then
                enterRoute route { model | pushing = Nothing }

            else if route == model.route then
                ( { model | restoring = Nothing }, Cmd.none )

            else if Just route == model.restoring then
                -- Nav.forward reports the address it is leaving, once more
                ( model, Cmd.none )

            else if LeaveGuard.isDirty model.guard then
                -- The Back button: put the address back, then ask.
                case LeaveGuard.request GoBack model.guard of
                    Hold guard cmd ->
                        ( { model | guard = guard, restoring = Just route }, Cmd.batch [ Nav.forward model.key 1, Cmd.map GuardMsg cmd ] )

                    Proceed _ ->
                        enterRoute route model

            else
                enterRoute route model

        SideNavMsg m ->
            let
                ( sideNav, cmd ) =
                    SideNav.update m model.sideNav
            in
            ( { model | sideNav = sideNav }, Cmd.map SideNavMsg cmd )

        TableMsg m ->
            let
                ( table, cmd ) =
                    Table.update m model.table
            in
            ( { model | table = table }, Cmd.map TableMsg cmd )

        GuardMsg m ->
            let
                ( guard, cmd, decision ) =
                    LeaveGuard.update m model.guard

                next =
                    { model | guard = guard }
            in
            case decision of
                Nothing ->
                    ( next
                    , Cmd.batch
                        [ Cmd.map GuardMsg cmd
                        , if LeaveGuard.isOpen model.guard && not (LeaveGuard.isOpen guard) then
                            AppShell.focusContent shellId NoOp

                          else
                            Cmd.none
                        ]
                    )

                Just answer ->
                    case LeaveGuard.destination answer of
                        Go route ->
                            let
                                ( moved, goCmd ) =
                                    go route next
                            in
                            ( moved, Cmd.batch [ Cmd.map GuardMsg cmd, goCmd ] )

                        GoBack ->
                            ( next, Cmd.batch [ Cmd.map GuardMsg cmd, Nav.back model.key 1 ] )

        ToastMsg m ->
            let
                ( toasts, cmd ) =
                    Toast.update m model.toasts
            in
            ( { model | toasts = toasts }, Cmd.map ToastMsg cmd )

        GotLookups result ->
            ( { model | lookups = Remote.fromResult result }, Cmd.none )

        GotSuppliers result ->
            ( { model | suppliers = Remote.fromResult result }, Cmd.none )

        ReloadLookups ->
            ( { model | lookups = Loading }, Api.loadLookups GotLookups )

        OpenSupplier id ->
            navigate (Go (SupplierRoute id)) model

        SetOffline flag ->
            let
                b =
                    model.behaviour
            in
            ( { model | behaviour = { b | offline = flag } }, Cmd.none )

        SetSomeoneElse flag ->
            let
                b =
                    model.behaviour
            in
            ( { model | behaviour = { b | someoneElseSaved = flag } }, Cmd.none )

        FlowMsg m ->
            case model.page of
                FlowPage flow ->
                    let
                        ( flow2, cmd, fx ) =
                            Flow.update { behaviour = model.behaviour, db = model.db, lookups = model.lookups } m flow

                        withDb =
                            case fx.db of
                                Just db ->
                                    { model | db = db, suppliers = Loaded db.suppliers, behaviour = Backend.calm }

                                Nothing ->
                                    model

                        guard =
                            LeaveGuard.setDirty FlowSource (Flow.isDirty flow2) withDb.guard

                        next =
                            { withDb | page = FlowPage flow2, guard = guard }
                    in
                    case ( fx.saved, fx.reloadLookups ) of
                        ( Just supplier, _ ) ->
                            let
                                ( toasts, toastCmd ) =
                                    Toast.push
                                        [ Toast.success, Toast.message ("Saved " ++ supplier.data.company.name ++ ".") ]
                                        next.toasts

                                ( moved, goCmd ) =
                                    go (SupplierRoute supplier.id) { next | toasts = toasts }
                            in
                            ( moved, Cmd.batch [ Cmd.map FlowMsg cmd, Cmd.map ToastMsg toastCmd, goCmd ] )

                        ( Nothing, True ) ->
                            ( { next | lookups = Loading }, Cmd.batch [ Cmd.map FlowMsg cmd, Api.loadLookups GotLookups ] )

                        _ ->
                            ( next, Cmd.map FlowMsg cmd )

                _ ->
                    ( model, Cmd.none )

        DetailMsg m ->
            case model.page of
                DetailPage detail ->
                    let
                        ( detail2, cmd, fx ) =
                            Detail.update { behaviour = model.behaviour, db = model.db, lookups = model.lookups } m detail

                        withDb =
                            case fx.db of
                                Just db ->
                                    { model | db = db, suppliers = Loaded db.suppliers, behaviour = Backend.calm }

                                Nothing ->
                                    model
                    in
                    ( { withDb | page = DetailPage detail2 }, Cmd.map DetailMsg cmd )

                _ ->
                    ( model, Cmd.none )

        NoOp ->
            ( model, Cmd.none )



-- VIEW


view : Model -> Browser.Document Msg
view model =
    { title = "Supplier onboarding"
    , body =
        [ Klar.stylesheet
        , AppShell.view
            [ AppShell.id shellId
            , AppShell.brand (AppShell.brandLink { name = "Supplier onboarding", href = "#/suppliers", logo = Nothing })
            , AppShell.sidebar
                (SideNav.view SideNavMsg
                    [ SideNav.entries navigation, SideNav.current (navKeyOf model.route) ]
                    model.sideNav
                )
            , AppShell.userName "Ada Lovelace"
            , AppShell.userRole "Procurement"
            , AppShell.contentMaxWidth 1100
            , AppShell.onStrayDrop NoOp
            , AppShell.overlays (overlays model)
            ]
            [ viewPage model ]
        ]
    }


overlays : Model -> List (Overlay Msg)
overlays model =
    (case model.page of
        FlowPage flow ->
            List.map (Overlay.map FlowMsg) (Flow.overlays flow)

        _ ->
            []
    )
        ++ [ LeaveGuard.view GuardMsg
                [ LeaveGuard.title "Leave without saving?"
                , LeaveGuard.message "The supplier you are onboarding is not saved. If you leave now, everything you entered is lost."
                ]
                model.guard
           , Toast.view ToastMsg [] model.toasts
           ]


viewPage : Model -> Html Msg
viewPage model =
    case model.page of
        ListPage ->
            viewList model

        FlowPage flow ->
            Html.map FlowMsg (Flow.view model.lookups flow)

        DetailPage detail ->
            Html.map DetailMsg (Detail.view model.lookups detail)

        MissingPage ->
            Layout.stack [ Layout.gap 4 ]
                [ PageHeader.view [ PageHeader.title "Not found" ]
                , Text.paragraph "There is no such page or supplier."
                , Layout.row [] [ Button.view [ Button.href "#/suppliers" ] "All suppliers" ]
                ]


supplierRows : Table.RowIds SupplierId
supplierRows =
    Table.rowIds { toKey = supplierIdToString, fromKey = supplierIdFromString }


viewList : Model -> Html Msg
viewList model =
    let
        names =
            Remote.withDefault { countries = [], categories = [], paymentTerms = [] } model.lookups

        countryName id =
            names.countries |> List.filter (\c -> c.id == id) |> List.head |> Maybe.map .name |> Maybe.withDefault (countryKey id)
    in
    Layout.stack [ Layout.gap 4 ]
        [ PageHeader.view
            [ PageHeader.title "Suppliers"
            , PageHeader.subtitle "Companies we buy from."
            , PageHeader.actions
                [ Button.view [ Button.primary, Button.icon Icon.plus, Button.href "#/suppliers/new" ] "Onboard a supplier" ]
            ]
        , Table.view TableMsg
            [ Table.label "Suppliers"
            , Table.columns
                [ Table.custom (Table.columnId "name")
                    "Name"
                    (\s -> Text.link { href = routeToUrl (SupplierRoute s.id), label = s.data.company.name })
                    [ Table.pinned ]
                , Table.text (Table.columnId "country") "Country" (.data >> .company >> .country >> countryName) []
                , Table.text (Table.columnId "orgnr") "Organisation number" (.data >> .company >> .orgNumber) []
                , Table.int (Table.columnId "lead") "Lead time (days)" (.data >> .delivery >> .leadTimeDays >> round) []
                , Table.status (Table.columnId "preferred")
                    "Tier"
                    (\s ->
                        if s.data.company.preferred then
                            ( Success, "Preferred" )

                        else
                            ( Neutral, "Standard" )
                    )
                    []
                , Table.int (Table.columnId "version") "Version" .version []
                ]
            , Table.rows model.suppliers
            , Table.rowId supplierRows .id
            , Table.rowLabel (.data >> .company >> .name)
            , Table.searchable
            , Table.onRowClick (\s -> OpenSupplier s.id)
            ]
            model.table
        , Card.view
            [ Card.headingLevel 2
            , Card.title "Pretend network"
            , Card.subtitle "Makes the next save behave badly, so you can see how the screens cope."
            ]
            [ Layout.stack [ Layout.gap 3 ]
                [ Switch.view
                    [ Switch.label "The next save fails: no contact with the server"
                    , Switch.checked model.behaviour.offline
                    , Switch.onToggle SetOffline
                    ]
                , Switch.view
                    [ Switch.label "Someone else saves the record first (editing only)"
                    , Switch.checked model.behaviour.someoneElseSaved
                    , Switch.onToggle SetSomeoneElse
                    ]
                , Text.muted "Try: organisation number 912345678, a contact at mailinator.com, perishables with a lead time over 14 days, a discount over 25%, the certification \"XYZ\"."
                ]
            ]
        ]
