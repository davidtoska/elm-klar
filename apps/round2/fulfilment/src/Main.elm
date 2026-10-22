module Main exposing (main)

import Api
import Backend.Db as Db exposing (Db)
import Browser
import Browser.Dom
import Browser.Navigation as Nav
import Domain exposing (..)
import Html exposing (Html)
import Klar
import Klar.AppShell as AppShell
import Klar.Badge as Badge
import Klar.Button as Button
import Klar.CommandPalette as CommandPalette
import Klar.ConfirmDialog as ConfirmDialog
import Klar.Date as Date exposing (Date)
import Klar.DescriptionList as DescriptionList
import Klar.Drawer as Drawer
import Klar.EmptyState as EmptyState
import Klar.ErrorState as ErrorState
import Klar.FilterBar as FilterBar
import Klar.Format as Format
import Klar.Icon as Icon
import Klar.Layout as Layout
import Klar.Locale as Locale
import Klar.Menu as Menu
import Klar.Modal as Modal
import Klar.Overlay as Overlay
import Klar.PageHeader as PageHeader
import Klar.Remote as Remote exposing (Remote(..))
import Klar.Rule as Rule
import Klar.SavedViews as SavedViews
import Klar.Select as Select
import Klar.Shortcut as Shortcut
import Klar.ShortcutHelp as ShortcutHelp
import Klar.Skeleton as Skeleton
import Klar.Table as Table
import Klar.Tabs as Tabs
import Klar.Text as Text
import Klar.TextArea as TextArea
import Klar.TextInput as TextInput
import Klar.Theme
import Klar.Timeline as Timeline
import Klar.Toast as Toast
import Process
import Task
import Time
import Url exposing (Url)



-- MODEL


type alias Route =
    { order : Maybe OrderId
    , view : Maybe String
    }


type alias Model =
    { key : Nav.Key
    , route : Route
    , zone : Time.Zone
    , now : Time.Posix
    , today : Date
    , db : Db
    , net : Api.Net

    -- the inbox
    , ticket : Int
    , orders : Remote (List OrderSummary)
    , total : Int
    , fetching : Bool
    , table : Table.State OrderId
    , filters : FilterBar.State
    , views : SavedViews.State
    , newView : Modal.State
    , newViewName : String
    , newViewError : Maybe String

    -- bulk actions
    , packing : Bool
    , assignDialog : ConfirmDialog.State
    , assignee : Select.State String

    -- the order drawer
    , drawer : Drawer.State
    , openOrder : Maybe OrderId
    , detail : Remote Detail
    , tabs : Tabs.State
    , lines : Table.State Int
    , statusMenu : Menu.State
    , statusDialog : ConfirmDialog.State
    , pendingStatus : Maybe Status
    , statusBusy : Bool
    , noteDraft : String
    , noteSaving : Bool
    , noteError : Maybe String

    -- the whole application
    , toasts : Toast.State Msg
    , shortcuts : Shortcut.State
    , help : ShortcutHelp.State
    , palette : CommandPalette.State
    , paletteTicket : Int
    , hits : Remote (List OrderSummary)
    , recent : List OrderSummary
    , netMenu : Menu.State
    }


type Msg
    = NoOp
    | LinkClicked Browser.UrlRequest
    | UrlChanged Url
    | GotClock Time.Zone Time.Posix
    | Tick Time.Posix
    | SkipToContent
    | ShortcutMsg Shortcut.Msg
    | ToastMsg Toast.Msg
    | OpenHelp
    | HelpMsg ShortcutHelp.Msg
    | OpenPalette
    | PaletteMsg CommandPalette.Msg
    | PaletteDebounced Int
    | GotHits Int (Result Remote.Problem (List OrderSummary))
    | RetryHits
    | GoToOrder OrderId
    | GoToInbox
    | FocusSearch
    | NetMenuMsg Menu.Msg
    | SetMode Api.Mode
      -- inbox
    | TableMsg Table.Msg
    | FiltersMsg FilterBar.Msg
    | ViewsMsg SavedViews.Msg
    | GotOrders Int (Result Remote.Problem { total : Int, rows : List OrderSummary })
    | Reload
    | ResetFilters
    | ShareView
    | GotShared String (Result Remote.Problem Db)
    | GotViewsSaved (Result Remote.Problem Db)
    | SaveViewsAgain
    | OpenNewView
    | NewViewMsg Modal.Msg
    | NewViewName String
    | SaveNewView
    | CancelNewView
      -- bulk actions
    | PackSelected
    | GotPacked (Result Remote.Problem ( Db, { packed : List OrderId, skipped : Int } ))
    | UndoPack (List OrderId)
    | GotUndo (Result Remote.Problem Db)
    | AskAssign
    | AssignDialogMsg ConfirmDialog.Msg
    | AssigneeMsg (Select.Msg String)
    | ConfirmAssign
    | CancelAssign
    | GotAssigned String Int (Result Remote.Problem Db)
      -- the drawer
    | DrawerMsg Drawer.Msg
    | CloseOrder
    | GotDetail OrderId (Result Remote.Problem Detail)
    | ReloadDetail
    | TabsMsg Tabs.Msg
    | LinesMsg Table.Msg
    | StatusMenuMsg Menu.Msg
    | AskStatus Status
    | StatusDialogMsg ConfirmDialog.Msg
    | ConfirmStatus
    | CancelStatus
    | GotStatus Status (Result Remote.Problem Db)
    | NoteInput String
    | SaveNote
    | GotNote (Result Remote.Problem Db)


main : Program () Model Msg
main =
    Browser.application
        { init = init
        , update = update
        , view = view
        , subscriptions = subscriptions
        , onUrlRequest = LinkClicked
        , onUrlChange = UrlChanged
        }


ids :
    { table : String
    , filters : String
    , views : String
    , newView : String
    , assignDialog : String
    , assignee : String
    , drawer : String
    , tabs : String
    , lines : String
    , statusMenu : String
    , statusDialog : String
    , help : String
    , palette : String
    , netMenu : String
    , shell : String
    }
ids =
    { table = "orders"
    , filters = "order-filters"
    , views = "order-views"
    , newView = "new-view"
    , assignDialog = "assign-dialog"
    , assignee = "assignee"
    , drawer = "order-drawer"
    , tabs = "order-tabs"
    , lines = "order-lines"
    , statusMenu = "status-menu"
    , statusDialog = "status-dialog"
    , help = "shortcut-help"
    , palette = "palette"
    , netMenu = "net-menu"
    , shell = "app-shell"
    }


init : () -> Url -> Nav.Key -> ( Model, Cmd Msg )
init _ url key =
    let
        db =
            Db.init

        route =
            parseRoute url

        model =
            { key = key
            , route = route
            , zone = Time.utc
            , now = Time.millisToPosix 0
            , today = Db.today
            , db = db
            , net = Api.init
            , ticket = 0
            , orders = Loading
            , total = 0
            , fetching = False
            , table = Table.init ids.table |> Table.setPageSize 200
            , filters = FilterBar.init ids.filters
            , views = SavedViews.init ids.views |> SavedViews.setViews db.views
            , newView = Modal.init ids.newView
            , newViewName = ""
            , newViewError = Nothing
            , packing = False
            , assignDialog = ConfirmDialog.init ids.assignDialog
            , assignee = Select.init ids.assignee
            , drawer = Drawer.init ids.drawer
            , openOrder = Nothing
            , detail = NotAsked
            , tabs = Tabs.init ids.tabs "details"
            , lines = Table.init ids.lines
            , statusMenu = Menu.init ids.statusMenu
            , statusDialog = ConfirmDialog.init ids.statusDialog
            , pendingStatus = Nothing
            , statusBusy = False
            , noteDraft = ""
            , noteSaving = False
            , noteError = Nothing
            , toasts = Toast.init
            , shortcuts = Shortcut.init
            , help = ShortcutHelp.init ids.help
            , palette = CommandPalette.init ids.palette
            , paletteTicket = 0
            , hits = NotAsked
            , recent = []
            , netMenu = Menu.init ids.netMenu
            }
                |> applyViewByName route.view

        ( withOrders, ordersCmd ) =
            fetchOrders model

        ( withRoute, routeCmd ) =
            showRoute route withOrders
    in
    ( withRoute
    , Cmd.batch
        [ Task.map2 Tuple.pair Time.here Time.now |> Task.perform (\( zone, now ) -> GotClock zone now)
        , ordersCmd
        , routeCmd
        ]
    )


-- KLAR GAP: SavedViews has no shared views or apply-by-name; this route and `applyViewByName` stand in for it
parseRoute : Url -> Route
parseRoute url =
    let
        fragment =
            url.fragment |> Maybe.withDefault ""

        ( path, query ) =
            case String.split "?" fragment of
                p :: q :: _ ->
                    ( p, Just q )

                p :: [] ->
                    ( p, Nothing )

                [] ->
                    ( "", Nothing )
    in
    { order =
        case String.split "/" path of
            [ "", "orders", n ] ->
                String.toInt n |> Maybe.map OrderId

            _ ->
                Nothing
    , view =
        query
            |> Maybe.andThen
                (\q ->
                    if String.startsWith "view=" q then
                        Url.percentDecode (String.dropLeft 5 q)

                    else
                        Nothing
                )
    }


orderUrl : OrderId -> String
orderUrl (OrderId n) =
    "#/orders/" ++ String.fromInt n


viewUrl : String -> String
viewUrl name =
    "#/orders?view=" ++ Url.percentEncode name



-- THE QUERY


currentQuery : Model -> Query
currentQuery model =
    let
        q =
            Table.query model.table
    in
    { search = q.search
    , sort = q.sort |> List.map (\( column, direction ) -> ( Table.columnName column, direction ))
    , page = q.page
    , pageSize = q.pageSize
    , rule = FilterBar.rule model.filters
    }


bump : Model -> Model
bump model =
    let
        net =
            model.net
    in
    { model | net = { net | counter = net.counter + 1 } }


fetchOrders : Model -> ( Model, Cmd Msg )
fetchOrders model0 =
    let
        model =
            bump model0

        ticket =
            model.ticket + 1
    in
    ( { model
        | ticket = ticket
        , fetching = True
        , orders =
            if Remote.isLoaded model.orders then
                model.orders

            else
                Loading
      }
    , Api.orders model.net model.today (currentQuery model) model.db (GotOrders ticket)
    )


{-| Fetch again when what the user asked for has changed.
-}
withFetch : Model -> ( Model, Cmd Msg ) -> ( Model, Cmd Msg )
withFetch old ( new, cmd ) =
    if currentQuery new /= currentQuery old then
        let
            ( fetching, fetchCmd ) =
                fetchOrders new
        in
        ( fetching, Cmd.batch [ cmd, fetchCmd ] )

    else
        ( new, cmd )


-- KLAR GAP: SavedViews has no way to apply a view by name from outside
applyViewByName : Maybe String -> Model -> Model
applyViewByName name model =
    case name |> Maybe.andThen (\n -> SavedViews.views model.views |> List.filter (\v -> v.name == n) |> List.head) of
        Just saved ->
            { model
                | views = SavedViews.setActive (Just saved.name) model.views
                , filters = FilterBar.setRule saved.rule model.filters
                , table = Table.setPage 1 model.table
            }

        Nothing ->
            model



-- ROUTE


showRoute : Route -> Model -> ( Model, Cmd Msg )
showRoute route model =
    case route.order of
        Just id ->
            if model.openOrder == Just id && Drawer.isOpen model.drawer then
                ( model, Cmd.none )

            else
                let
                    ( drawer, drawerCmd ) =
                        Drawer.open "" model.drawer

                    ( loading, detailCmd ) =
                        fetchDetail id { model | drawer = drawer, openOrder = Just id, detail = Loading, tabs = Tabs.setActive "details" model.tabs, noteDraft = "", noteError = Nothing }
                in
                ( loading, Cmd.batch [ Cmd.map DrawerMsg drawerCmd, detailCmd ] )

        Nothing ->
            if Drawer.isOpen model.drawer then
                let
                    ( drawer, cmd ) =
                        Drawer.close model.drawer
                in
                ( { model | drawer = drawer, openOrder = Nothing }, Cmd.map DrawerMsg cmd )

            else
                ( model, Cmd.none )


fetchDetail : OrderId -> Model -> ( Model, Cmd Msg )
fetchDetail id model0 =
    let
        model =
            bump model0
    in
    ( model, Api.detail model.net id model.db (GotDetail id) )



-- UPDATE


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        NoOp ->
            ( model, Cmd.none )

        LinkClicked (Browser.Internal url) ->
            ( model, Nav.pushUrl model.key (Url.toString url) )

        LinkClicked (Browser.External href) ->
            ( model, Nav.load href )

        UrlChanged url ->
            let
                route =
                    parseRoute url

                applied =
                    if route.view /= model.route.view then
                        applyViewByName route.view model

                    else
                        model
            in
            showRoute route { applied | route = route }
                |> withFetch model

        GotClock zone now ->
            ( { model | zone = zone, now = now, today = Date.fromPosix zone now }, Cmd.none )

        Tick now ->
            ( { model | now = now }, Cmd.none )

        SkipToContent ->
            ( model, AppShell.focusContent ids.shell NoOp )

        ShortcutMsg m ->
            let
                ( state, fired ) =
                    Shortcut.update shortcuts m model.shortcuts

                next =
                    { model | shortcuts = state }
            in
            case fired of
                Just fire ->
                    update fire next

                Nothing ->
                    ( next, Cmd.none )

        ToastMsg m ->
            let
                ( toasts, cmd ) =
                    Toast.update m model.toasts
            in
            ( { model | toasts = toasts }, Cmd.map ToastMsg cmd )

        OpenHelp ->
            let
                ( help, cmd ) =
                    ShortcutHelp.open "" model.help
            in
            ( { model | help = help }, Cmd.map HelpMsg cmd )

        HelpMsg m ->
            let
                ( help, cmd ) =
                    ShortcutHelp.update m model.help
            in
            ( { model | help = help }, Cmd.map HelpMsg cmd )

        OpenPalette ->
            let
                ( palette, cmd ) =
                    CommandPalette.open "" model.palette
            in
            ( { model | palette = palette, hits = NotAsked, paletteTicket = model.paletteTicket + 1 }
            , Cmd.map PaletteMsg cmd
            )

        PaletteMsg m ->
            let
                ( palette, cmd ) =
                    CommandPalette.update m model.palette

                changed =
                    CommandPalette.query palette /= CommandPalette.query model.palette
            in
            if changed then
                ( { model | palette = palette, hits = NotAsked, paletteTicket = model.paletteTicket + 1 }
                , Cmd.batch
                    [ Cmd.map PaletteMsg cmd
                    , Process.sleep 250 |> Task.perform (\_ -> PaletteDebounced (model.paletteTicket + 1))
                    ]
                )

            else
                ( { model | palette = palette }, Cmd.map PaletteMsg cmd )

        PaletteDebounced ticket ->
            if ticket == model.paletteTicket && paletteSearchText model /= "" then
                let
                    asked =
                        bump model
                in
                ( { asked | hits = Loading }
                , Api.lookup asked.net (paletteSearchText model) asked.db (GotHits ticket)
                )

            else
                ( model, Cmd.none )

        GotHits ticket result ->
            if ticket == model.paletteTicket then
                ( { model | hits = Remote.fromResult result }, Cmd.none )

            else
                ( model, Cmd.none )

        RetryHits ->
            update (PaletteDebounced model.paletteTicket) model

        GoToOrder id ->
            ( model, Nav.pushUrl model.key (orderUrl id) )

        GoToInbox ->
            ( model, Nav.pushUrl model.key "#/orders" )

        FocusSearch ->
            -- KLAR GAP: no Table.focusSearch; the id "orders-search" comes from the Table docs
            ( model, Task.attempt (\_ -> NoOp) (Browser.Dom.focus (ids.table ++ "-search")) )

        NetMenuMsg m ->
            let
                ( menu, cmd ) =
                    Menu.update m model.netMenu
            in
            ( { model | netMenu = menu }, Cmd.map NetMenuMsg cmd )

        SetMode mode ->
            let
                net =
                    model.net
            in
            fetchOrders { model | net = { net | mode = mode } }

        TableMsg m ->
            let
                ( table, cmd ) =
                    Table.update m model.table
            in
            ( { model | table = table }, Cmd.map TableMsg cmd )
                |> withFetch model

        FiltersMsg m ->
            let
                ( filters, cmd ) =
                    FilterBar.update m model.filters

                filtersChanged =
                    FilterBar.rule filters /= FilterBar.rule model.filters
            in
            ( { model
                | filters = filters
                , table =
                    if filtersChanged then
                        Table.setPage 1 model.table

                    else
                        model.table
              }
            , Cmd.map FiltersMsg cmd
            )
                |> withFetch model

        ViewsMsg m ->
            let
                ( views, cmd ) =
                    SavedViews.update m model.views

                next =
                    { model | views = views }

                applied =
                    if SavedViews.revision views /= SavedViews.revision model.views then
                        { next
                            | filters =
                                FilterBar.setRule
                                    (SavedViews.active views |> Maybe.map .rule |> Maybe.withDefault Rule.emptyGroup)
                                    model.filters
                            , table = Table.setPage 1 model.table
                        }

                    else
                        next
            in
            ( applied, Cmd.map ViewsMsg cmd )
                |> withFetch model
                |> persistViews model

        GotOrders ticket result ->
            if ticket /= model.ticket then
                ( model, Cmd.none )

            else
                case result of
                    Ok found ->
                        ( { model | orders = Loaded found.rows, total = found.total, fetching = False }, Cmd.none )

                    Err problem ->
                        ( { model | orders = Failed problem, fetching = False }, Cmd.none )

        Reload ->
            fetchOrders { model | orders = Loading }

        ResetFilters ->
            ( { model | filters = FilterBar.clear model.filters, views = SavedViews.setActive Nothing model.views }
            , Cmd.none
            )
                |> withFetch model

        ShareView ->
            case SavedViews.active model.views of
                Just saved ->
                    let
                        asked =
                            bump model
                    in
                    ( asked, Api.share asked.net saved.name asked.db (GotShared saved.name) )

                Nothing ->
                    ( model, Cmd.none )

        GotShared name result ->
            case result of
                Ok db ->
                    toast
                        [ Toast.success
                        , Toast.title "View shared"
                        , Toast.message ("Anyone can open \"" ++ name ++ "\" with " ++ viewUrl name)
                        ]
                        { model | db = db }

                Err problem ->
                    toast
                        [ Toast.danger
                        , Toast.title "Could not share the view"
                        , Toast.message (Remote.title Locale.en problem)
                        , Toast.action "Try again" ShareView
                        ]
                        model

        GotViewsSaved result ->
            case result of
                Ok db ->
                    ( { model | db = db }, Cmd.none )

                Err problem ->
                    toast
                        [ Toast.danger
                        , Toast.title "Your views were not saved"
                        , Toast.message (Remote.title Locale.en problem)
                        , Toast.action "Try again" SaveViewsAgain
                        ]
                        model

        SaveViewsAgain ->
            let
                asked =
                    bump model
            in
            ( asked, Api.saveViews asked.net (SavedViews.views asked.views) asked.db GotViewsSaved )

        OpenNewView ->
            -- KLAR GAP: SavedViews cannot open its own save form, so the palette command needs this modal
            let
                ( modal, cmd ) =
                    Modal.openWith { opener = "", focus = [ "new-view-name" ] } model.newView
            in
            ( { model | newView = modal, newViewName = "", newViewError = Nothing }, Cmd.map NewViewMsg cmd )

        NewViewMsg m ->
            let
                ( modal, cmd ) =
                    Modal.update m model.newView
            in
            ( { model | newView = modal }, Cmd.map NewViewMsg cmd )

        NewViewName name ->
            ( { model | newViewName = name, newViewError = Nothing }, Cmd.none )

        CancelNewView ->
            let
                ( modal, cmd ) =
                    Modal.close model.newView
            in
            ( { model | newView = modal }, Cmd.map NewViewMsg cmd )

        SaveNewView ->
            let
                name =
                    String.trim model.newViewName

                taken =
                    SavedViews.views model.views
                        |> List.any (\v -> String.toLower v.name == String.toLower name)
            in
            if name == "" then
                ( { model | newViewError = Just "Give the view a name." }, Cmd.none )

            else if taken then
                ( { model | newViewError = Just "A view with this name exists." }, Cmd.none )

            else
                let
                    views =
                        model.views
                            |> SavedViews.setViews (SavedViews.views model.views ++ [ SavedViews.savedView name (FilterBar.rule model.filters) ])
                            |> SavedViews.setActive (Just name)

                    ( modal, cmd ) =
                        Modal.close model.newView
                in
                ( { model | views = views, newView = modal }, Cmd.map NewViewMsg cmd )
                    |> persistViews model

        PackSelected ->
            let
                selected =
                    Table.selectedIds orderRows model.table
            in
            if List.isEmpty selected || model.packing then
                ( model, Cmd.none )

            else
                let
                    asked =
                        bump model
                in
                ( { asked | packing = True }, Api.pack asked.net asked.now selected asked.db GotPacked )

        GotPacked result ->
            case result of
                Ok ( db, report ) ->
                    let
                        cleared =
                            { model | db = db, packing = False, table = Table.clearSelection model.table }

                        n =
                            List.length report.packed

                        ( withToast, toastCmd ) =
                            if n == 0 then
                                toast
                                    [ Toast.warning
                                    , Toast.title "Nothing was packed"
                                    , Toast.message "Only orders that are being picked can be marked as packed."
                                    ]
                                    cleared

                            else
                                toast
                                    [ Toast.success
                                    , Toast.title (Format.plural Locale.en n { one = "1 order packed", other = String.fromInt n ++ " orders packed" })
                                    , Toast.message
                                        (if report.skipped > 0 then
                                            String.fromInt report.skipped ++ " skipped: they are not being picked."

                                         else
                                            ""
                                        )
                                    , Toast.action "Undo" (UndoPack report.packed)
                                    ]
                                    cleared

                        ( refreshed, fetchCmd ) =
                            fetchOrders withToast
                    in
                    ( refreshed
                    , Cmd.batch [ toastCmd, fetchCmd, Cmd.map TableMsg (Table.focus model.table) ]
                    )

                Err problem ->
                    toast
                        [ Toast.danger
                        , Toast.title "Could not mark the orders as packed"
                        , Toast.message (Remote.title Locale.en problem)
                        , Toast.action "Try again" PackSelected
                        ]
                        { model | packing = False }

        UndoPack packed ->
            let
                asked =
                    bump model
            in
            ( asked, Api.undoPack asked.net asked.now packed asked.db GotUndo )

        GotUndo result ->
            case result of
                Ok db ->
                    let
                        ( withToast, toastCmd ) =
                            toast [ Toast.info, Toast.message "Packing undone." ] { model | db = db }

                        ( refreshed, fetchCmd ) =
                            fetchOrders withToast
                    in
                    ( refreshed, Cmd.batch [ toastCmd, fetchCmd ] )

                Err problem ->
                    toast [ Toast.danger, Toast.title "Could not undo", Toast.message (Remote.title Locale.en problem) ] model

        AskAssign ->
            if List.isEmpty (Table.selectedIds orderRows model.table) then
                ( model, Cmd.none )

            else
                let
                    ( dialog, cmd ) =
                        ConfirmDialog.open "" model.assignDialog
                in
                ( { model | assignDialog = dialog, assignee = Select.clear model.assignee }, Cmd.map AssignDialogMsg cmd )

        AssignDialogMsg m ->
            let
                ( dialog, cmd ) =
                    ConfirmDialog.update m model.assignDialog
            in
            ( { model | assignDialog = dialog }, Cmd.map AssignDialogMsg cmd )

        AssigneeMsg m ->
            let
                ( assignee, cmd ) =
                    Select.update m model.assignee
            in
            ( { model | assignee = assignee }, Cmd.map AssigneeMsg cmd )

        ConfirmAssign ->
            case Select.value model.assignee of
                Just person ->
                    let
                        selected =
                            Table.selectedIds orderRows model.table

                        asked =
                            bump model
                    in
                    ( { asked | assignDialog = ConfirmDialog.setBusy asked.assignDialog }
                    , Api.assign asked.net asked.now person selected asked.db (GotAssigned person (List.length selected))
                    )

                Nothing ->
                    ( model, Cmd.none )

        CancelAssign ->
            let
                ( dialog, cmd ) =
                    ConfirmDialog.close model.assignDialog
            in
            ( { model | assignDialog = dialog }, Cmd.map AssignDialogMsg cmd )

        GotAssigned person count result ->
            case result of
                Ok db ->
                    let
                        ( dialog, dialogCmd ) =
                            ConfirmDialog.close model.assignDialog

                        ( withToast, toastCmd ) =
                            toast
                                [ Toast.success
                                , Toast.message (Format.plural Locale.en count { one = "1 order assigned to ", other = String.fromInt count ++ " orders assigned to " } ++ person ++ ".")
                                ]
                                { model | db = db, assignDialog = dialog, table = Table.clearSelection model.table }

                        ( refreshed, fetchCmd ) =
                            fetchOrders withToast
                    in
                    ( refreshed
                    , Cmd.batch [ Cmd.map AssignDialogMsg dialogCmd, toastCmd, fetchCmd, Cmd.map TableMsg (Table.focus model.table) ]
                    )

                Err problem ->
                    ( { model | assignDialog = ConfirmDialog.setFailed problem model.assignDialog }, Cmd.none )

        DrawerMsg m ->
            let
                ( drawer, cmd ) =
                    Drawer.update m model.drawer
            in
            ( { model | drawer = drawer }, Cmd.map DrawerMsg cmd )

        CloseOrder ->
            ( model, Nav.pushUrl model.key "#/orders" )

        GotDetail id result ->
            if model.openOrder /= Just id then
                ( model, Cmd.none )

            else
                case result of
                    Ok detail ->
                        ( { model | detail = Loaded detail, recent = rememberRecent detail.order model.recent }, Cmd.none )

                    Err problem ->
                        if Remote.isLoaded model.detail then
                            -- a refresh failed: keep what is on screen
                            toast
                                [ Toast.danger
                                , Toast.title "The order could not be refreshed"
                                , Toast.message (Remote.title Locale.en problem)
                                , Toast.action "Try again" ReloadDetail
                                ]
                                model

                        else
                            ( { model | detail = Failed problem }, Cmd.none )

        ReloadDetail ->
            case model.openOrder of
                Just id ->
                    fetchDetail id { model | detail = Loading }

                Nothing ->
                    ( model, Cmd.none )

        TabsMsg m ->
            let
                ( tabs, cmd ) =
                    Tabs.update m model.tabs
            in
            ( { model | tabs = tabs }, Cmd.map TabsMsg cmd )

        LinesMsg m ->
            let
                ( lines, cmd ) =
                    Table.update m model.lines
            in
            ( { model | lines = lines }, Cmd.map LinesMsg cmd )

        StatusMenuMsg m ->
            let
                ( menu, cmd ) =
                    Menu.update m model.statusMenu
            in
            ( { model | statusMenu = menu }, Cmd.map StatusMenuMsg cmd )

        AskStatus target ->
            if isIrreversible target then
                let
                    ( dialog, cmd ) =
                        ConfirmDialog.open "" model.statusDialog
                in
                ( { model | statusDialog = dialog, pendingStatus = Just target }, Cmd.map StatusDialogMsg cmd )

            else
                changeStatus target model

        StatusDialogMsg m ->
            let
                ( dialog, cmd ) =
                    ConfirmDialog.update m model.statusDialog
            in
            ( { model | statusDialog = dialog }, Cmd.map StatusDialogMsg cmd )

        ConfirmStatus ->
            case model.pendingStatus of
                Just target ->
                    changeStatus target { model | statusDialog = ConfirmDialog.setBusy model.statusDialog }

                Nothing ->
                    ( model, Cmd.none )

        CancelStatus ->
            let
                ( dialog, cmd ) =
                    ConfirmDialog.close model.statusDialog
            in
            ( { model | statusDialog = dialog, pendingStatus = Nothing }, Cmd.map StatusDialogMsg cmd )

        GotStatus target result ->
            case result of
                Ok db ->
                    let
                        ( dialog, dialogCmd ) =
                            ConfirmDialog.close model.statusDialog

                        ( withToast, toastCmd ) =
                            toast
                                [ Toast.success
                                , Toast.message
                                    ((model.openOrder |> Maybe.map orderIdToString |> Maybe.withDefault "The order")
                                        ++ " is now "
                                        ++ String.toLower (statusLabel target)
                                        ++ "."
                                    )
                                ]
                                { model | db = db, statusDialog = dialog, pendingStatus = Nothing, statusBusy = False }

                        ( reloading, detailCmd ) =
                            case model.openOrder of
                                Just id ->
                                    fetchDetail id withToast

                                Nothing ->
                                    ( withToast, Cmd.none )

                        ( refreshed, fetchCmd ) =
                            fetchOrders reloading
                    in
                    ( refreshed, Cmd.batch [ Cmd.map StatusDialogMsg dialogCmd, toastCmd, detailCmd, fetchCmd ] )

                Err problem ->
                    if ConfirmDialog.isOpen model.statusDialog then
                        ( { model | statusDialog = ConfirmDialog.setFailed problem model.statusDialog, statusBusy = False }, Cmd.none )

                    else
                        toast
                            [ Toast.danger
                            , Toast.title "The status was not changed"
                            , Toast.message (Remote.title Locale.en problem)
                            ]
                            { model | statusBusy = False }

        NoteInput text ->
            ( { model | noteDraft = text, noteError = Nothing }, Cmd.none )

        SaveNote ->
            case model.openOrder of
                Just id ->
                    if model.noteSaving then
                        ( model, Cmd.none )

                    else
                        let
                            asked =
                                bump model
                        in
                        ( { asked | noteSaving = True }
                        , Api.addNote asked.net asked.now id asked.noteDraft asked.db GotNote
                        )

                Nothing ->
                    ( model, Cmd.none )

        GotNote result ->
            case result of
                Ok db ->
                    let
                        ( withToast, toastCmd ) =
                            toast [ Toast.success, Toast.message "Note saved." ]
                                { model | db = db, noteDraft = "", noteSaving = False, noteError = Nothing }

                        ( reloading, detailCmd ) =
                            case model.openOrder of
                                Just id ->
                                    fetchDetail id withToast

                                Nothing ->
                                    ( withToast, Cmd.none )
                    in
                    ( reloading, Cmd.batch [ toastCmd, detailCmd ] )

                Err problem ->
                    -- the draft stays in the field
                    toast
                        [ Toast.danger
                        , Toast.title "The note was not saved"
                        , Toast.message "What you typed is still in the field."
                        , Toast.action "Try again" SaveNote
                        ]
                        { model | noteSaving = False, noteError = Just (Remote.title Locale.en problem) }


changeStatus : Status -> Model -> ( Model, Cmd Msg )
changeStatus target model0 =
    case model0.openOrder of
        Just id ->
            let
                model =
                    bump model0
            in
            ( { model | statusBusy = True }, Api.setStatus model.net model.now id target model.db (GotStatus target) )

        Nothing ->
            ( model0, Cmd.none )


toast : List (Toast.Attribute Msg) -> Model -> ( Model, Cmd Msg )
toast attributes model =
    let
        ( toasts, cmd ) =
            Toast.push attributes model.toasts
    in
    ( { model | toasts = toasts }, Cmd.map ToastMsg cmd )


{-| Save the saved views to the backend when the list changed.
-}
persistViews : Model -> ( Model, Cmd Msg ) -> ( Model, Cmd Msg )
persistViews old ( new, cmd ) =
    if SavedViews.views new.views /= SavedViews.views old.views then
        let
            asked =
                bump new
        in
        ( asked
        , Cmd.batch [ cmd, Api.saveViews asked.net (SavedViews.views asked.views) asked.db GotViewsSaved ]
        )

    else
        ( new, cmd )


rememberRecent : OrderSummary -> List OrderSummary -> List OrderSummary
rememberRecent order recent =
    order :: List.filter (\o -> o.id /= order.id) recent |> List.take 5


{-| The palette query without a leading "go to order".
-}
paletteSearchText : Model -> String
paletteSearchText model =
    let
        query =
            CommandPalette.query model.palette |> String.trim |> String.toLower

        stripped =
            [ "go to order", "go to", "order" ]
                |> List.filter (\prefix -> String.startsWith prefix query)
                |> List.head
                |> Maybe.map (\prefix -> String.dropLeft (String.length prefix) query)
                |> Maybe.withDefault query
    in
    String.trim stripped



-- SHORTCUTS


shortcuts : List (Shortcut.Shortcut Msg)
shortcuts =
    [ Shortcut.shortcut (Shortcut.mod (Shortcut.char 'k')) "Navigation" "Open the command palette" OpenPalette
        |> Shortcut.inInputs
    , Shortcut.shortcut (Shortcut.sequence [ Shortcut.char 'g', Shortcut.char 'o' ]) "Navigation" "Go to the order list" GoToInbox
    , Shortcut.shortcut (Shortcut.sequence [ Shortcut.char 'n', Shortcut.char 'v' ]) "Saved views" "New saved view" OpenNewView
    , Shortcut.shortcut (Shortcut.char '/') "Orders" "Search the orders" FocusSearch
    , Shortcut.shortcut (Shortcut.char '?') "Help" "Show the keyboard shortcuts" OpenHelp
    ]


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        [ Shortcut.subscription ShortcutMsg shortcuts model.shortcuts
        , Time.every 60000 Tick
        ]



-- VIEW


view : Model -> Browser.Document Msg
view model =
    { title = "Fulfilment desk"
    , body =
        [ Klar.stylesheet
        , AppShell.view
            [ AppShell.id ids.shell
            , AppShell.brand
                (AppShell.brandLink
                    { name = "Fulfilment desk"
                    , href = "#/orders"
                    , logo = Just (Icon.sized Icon.Large Icon.package)
                    }
                )
            , AppShell.onSearch OpenPalette
            , AppShell.searchPlaceholder "Go to an order or run a command ..."
            , AppShell.actions
                [ Menu.view NetMenuMsg
                    [ Menu.label ("Network: " ++ Api.modeLabel model.net.mode)
                    , Menu.trigger [ Button.ghost, Button.small ]
                    , Menu.alignEnd
                    , Menu.items
                        (List.map
                            (\mode ->
                                Menu.item (Api.modeLabel mode) (SetMode mode)
                                    |> (if mode == model.net.mode then
                                            Menu.withHint "current"

                                        else
                                            identity
                                       )
                            )
                            [ Api.Normal, Api.Slow, Api.Failing, Api.Flaky, Api.NoData ]
                        )
                    ]
                    model.netMenu
                , Button.iconOnly [ Button.ghost, Button.onClick OpenHelp ] Icon.keyboard "Keyboard shortcuts"
                ]
            , AppShell.userName currentUser
            , AppShell.userRole "Fulfilment"
            , AppShell.shortcuts (Shortcut.listen ShortcutMsg shortcuts model.shortcuts)
            , AppShell.onSkipToContent SkipToContent
            , AppShell.onStrayDrop NoOp
            , AppShell.overlays (overlays model)
            ]
            [ viewInbox model ]
        ]
    }


overlays : Model -> List (Overlay.Overlay Msg)
overlays model =
    [ viewDrawer model
    , Modal.view NewViewMsg
        [ Modal.title "New saved view"
        , Modal.small
        , Modal.footer
            [ Button.view [ Button.onClick CancelNewView ] "Cancel"
            , Button.view [ Button.primary, Button.onClick SaveNewView ] "Save view"
            ]
        ]
        model.newView
        [ Layout.stack [ Layout.gap 3 ]
            [ Text.paragraph "The view keeps the filters that are on now."
            , TextInput.view
                [ TextInput.label "Name"
                , TextInput.value model.newViewName
                , TextInput.onInput NewViewName
                , TextInput.onEnter SaveNewView
                , TextInput.errorMaybe model.newViewError
                , TextInput.id "new-view-name"
                ]
            ]
        ]
    , ConfirmDialog.view AssignDialogMsg
        [ ConfirmDialog.title "Assign orders"
        , ConfirmDialog.message (Format.plural Locale.en (List.length (Table.selectedIds orderRows model.table)) { one = "1 selected order gets a new owner.", other = String.fromInt (List.length (Table.selectedIds orderRows model.table)) ++ " selected orders get a new owner." })
        , ConfirmDialog.body
            [ Select.view AssigneeMsg
                [ Select.label "Assign to"
                , Select.options (List.map (\p -> Select.option p p) people)
                , Select.placeholder "Choose a person"
                ]
                model.assignee
            ]
        , ConfirmDialog.confirmLabel "Assign"
        , ConfirmDialog.confirmDisabled (Select.value model.assignee == Nothing)
        , ConfirmDialog.onConfirm ConfirmAssign
        , ConfirmDialog.onCancel CancelAssign
        ]
        model.assignDialog
    , ConfirmDialog.view StatusDialogMsg
        (case model.pendingStatus of
            Just target ->
                [ ConfirmDialog.title ("Mark the order as " ++ String.toLower (statusLabel target) ++ "?")
                , ConfirmDialog.message "This cannot be undone."
                , ConfirmDialog.consequences (statusConsequences target)
                , if target == Cancelled then
                    ConfirmDialog.danger

                  else
                    ConfirmDialog.warning
                , ConfirmDialog.confirmLabel ("Mark as " ++ String.toLower (statusLabel target))
                , ConfirmDialog.onConfirm ConfirmStatus
                , ConfirmDialog.onCancel CancelStatus
                ]

            Nothing ->
                [ ConfirmDialog.title "Change status" ]
        )
        model.statusDialog
    , CommandPalette.view PaletteMsg
        [ CommandPalette.sections
            [ CommandPalette.section "Commands"
                [ CommandPalette.item "Go to the order list" GoToInbox
                    |> CommandPalette.withIcon Icon.clipboardCheck
                    |> CommandPalette.withShortcut (Shortcut.sequence [ Shortcut.char 'g', Shortcut.char 'o' ])
                , CommandPalette.item "New saved view" OpenNewView
                    |> CommandPalette.withIcon Icon.plus
                    |> CommandPalette.withShortcut (Shortcut.sequence [ Shortcut.char 'n', Shortcut.char 'v' ])
                    |> CommandPalette.withKeywords [ "create", "filter" ]
                , CommandPalette.item "Show the keyboard shortcuts" OpenHelp
                    |> CommandPalette.withIcon Icon.keyboard
                    |> CommandPalette.withShortcut (Shortcut.char '?')
                , CommandPalette.item "Reload the orders" Reload
                    |> CommandPalette.withIcon Icon.refresh
                ]
            , CommandPalette.remote "Go to order" (Remote.map (List.map orderItem) model.hits)
                |> CommandPalette.onRetry RetryHits
                |> CommandPalette.emptyText "No order found"
            ]
        , CommandPalette.recent (List.map orderItem model.recent)
        , CommandPalette.placeholder "Go to order ... or run a command"
        ]
        model.palette
    , ShortcutHelp.view HelpMsg [] shortcuts model.help
    , Toast.view ToastMsg [] model.toasts
    ]


orderItem : OrderSummary -> CommandPalette.Item Msg
orderItem order =
    CommandPalette.item ("Go to order " ++ orderIdToString order.id) (GoToOrder order.id)
        |> CommandPalette.withDescription (order.customer ++ ", " ++ String.toLower (statusLabel order.status))
        |> CommandPalette.withId (orderIdToString order.id)
        |> CommandPalette.withIcon Icon.package


statusConsequences : Status -> List String
statusConsequences target =
    case target of
        Shipped ->
            [ "The customer gets a shipping notice", "The lines can no longer be changed" ]

        Delivered ->
            [ "The order is closed" ]

        Cancelled ->
            [ "The reserved stock is released", "The customer is told" ]

        _ ->
            []



-- THE INBOX


viewInbox : Model -> Html Msg
viewInbox model =
    Layout.stack [ Layout.gap 3, Layout.fillRest ]
        [ PageHeader.view
            [ PageHeader.title "Orders"
            , PageHeader.subtitle "Everything that has to be picked, packed and sent"
            , PageHeader.actions
                [ Button.view [ Button.icon Icon.plus, Button.onClick OpenNewView ] "New saved view" ]
            ]
        , Layout.row [ Layout.gap 2, Layout.wrap, Layout.alignCenter ]
            [ SavedViews.view ViewsMsg
                [ SavedViews.current (FilterBar.rule model.filters), SavedViews.size Klar.Theme.Small ]
                model.views
            , viewShare model
            ]
        , FilterBar.view FiltersMsg
            [ FilterBar.fields fields
            , FilterBar.today model.today
            , FilterBar.matchCount
                (if Remote.isLoaded model.orders then
                    Just model.total

                 else
                    Nothing
                )
            , FilterBar.counting (model.fetching && not (Remote.isLoaded model.orders))
            ]
            model.filters
        , Layout.stack [ Layout.fillRest ]
            [ Table.view TableMsg (tableAttributes model) model.table ]
        ]


-- KLAR GAP: SavedViews has no share action
viewShare : Model -> Html Msg
viewShare model =
    case SavedViews.active model.views of
        Just saved ->
            if List.member saved.name model.db.shared then
                Badge.view [ Badge.tone Klar.Theme.Success, Badge.icon Icon.share ] "Shared"

            else
                Button.view [ Button.ghost, Button.small, Button.icon Icon.share, Button.onClick ShareView ] "Share view"

        Nothing ->
            Html.text ""


tableAttributes : Model -> List (Table.Attribute OrderId OrderSummary Msg)
tableAttributes model =
    [ Table.label "Orders"
    , Table.columns
        [ Table.text (Table.columnId "number") "Order" (.id >> orderIdToString) [ Table.pinned, Table.width 120 ]
        , Table.text (Table.columnId "customer") "Customer" .customer []
        , Table.status (Table.columnId "status") "Status" (\o -> ( statusTone o.status, statusLabel o.status )) [ Table.width 130 ]
        , Table.date (Table.columnId "created") "Created" .created []
        , Table.date (Table.columnId "due") "Due" .due []
        , Table.float (Table.columnId "total") "Total" 2 .total [ Table.footerSum ]
        , Table.int (Table.columnId "items") "Items" .items []
        , Table.text (Table.columnId "assignee") "Assignee" (.assignee >> Maybe.withDefault "") []
        ]
    , Table.rows model.orders
    , Table.rowId orderRows .id
    , Table.rowLabel (.id >> orderIdToString)
    , Table.server { total = model.total }
    , Table.refreshing model.fetching
    , Table.searchable
    , Table.searchPlaceholder "Search by order, customer or person ..."
    , Table.pageSizes [ 50, 100, 200 ]
    , Table.fillHeight
    , Table.onRowClick (\order -> GoToOrder order.id)
    , Table.rowTone
        (\order ->
            if order.late then
                Just Klar.Theme.Danger

            else
                Nothing
        )
    , Table.bulkActions
        [ Button.view [ Button.small, Button.icon Icon.checkCheck, Button.loading model.packing, Button.onClick PackSelected ] "Mark as packed"
        , Button.view [ Button.small, Button.icon Icon.userPlus, Button.onClick AskAssign ] "Assign ..."
        ]
    , Table.exportCsv "orders.csv"
    , Table.onRetry Reload
    , Table.onRefresh Reload
    , Table.activeExternalFilters (Rule.conditionCount (FilterBar.rule model.filters))
    , Table.onResetFilters ResetFilters
    , Table.emptyState [ EmptyState.title "No orders yet", EmptyState.description "Orders show up here when customers place them." ]
    ]



-- THE DRAWER


viewDrawer : Model -> Overlay.Overlay Msg
viewDrawer model =
    Drawer.view DrawerMsg
        [ Drawer.title (model.openOrder |> Maybe.map orderIdToString |> Maybe.withDefault "Order")
        , Drawer.subtitle
            (case model.detail of
                Loaded detail ->
                    detail.order.customer

                _ ->
                    ""
            )
        , Drawer.large
        , Drawer.onRequestClose CloseOrder
        , Drawer.busy model.noteSaving
        , Drawer.footer [ Button.view [ Button.onClick CloseOrder ] "Close" ]
        ]
        model.drawer
        [ case model.detail of
            Loaded detail ->
                viewDetail model detail

            Failed problem ->
                ErrorState.view [ ErrorState.onRetry ReloadDetail ] problem

            _ ->
                Layout.stack [ Layout.gap 3 ]
                    [ Skeleton.line 40, Skeleton.paragraph 3, Skeleton.block 120 ]
        ]


viewDetail : Model -> Detail -> Html Msg
viewDetail model detail =
    let
        order =
            detail.order

        steps =
            nextSteps order.status
    in
    Layout.stack [ Layout.gap 4 ]
        [ Layout.row [ Layout.gap 2, Layout.alignCenter, Layout.wrap ]
            [ Badge.view [ Badge.tone (statusTone order.status) ] (statusLabel order.status)
            , if order.late then
                Badge.view [ Badge.tone Klar.Theme.Danger, Badge.icon Icon.clock ] "Late"

              else
                Html.text ""
            , Layout.spacer
            , if List.isEmpty steps then
                Text.muted "No further steps"

              else
                Menu.view StatusMenuMsg
                    [ Menu.label "Change status"
                    , Menu.trigger [ Button.small, Button.loading model.statusBusy ]
                    , Menu.alignEnd
                    , Menu.items
                        (List.map
                            (\step ->
                                Menu.item ("Mark as " ++ String.toLower (statusLabel step)) (AskStatus step)
                                    |> (if isIrreversible step then
                                            Menu.withHint "final"

                                        else
                                            identity
                                       )
                            )
                            steps
                        )
                    ]
                    model.statusMenu
            ]
        , let
            resolved =
                model.tabs
          in
          Layout.stack [ Layout.gap 3 ]
            [ Tabs.view TabsMsg
                [ Tabs.ariaLabel "Order sections"
                , Tabs.tabs
                    [ Tabs.tab "details" "Details"
                    , Tabs.tab "lines" "Lines" |> Tabs.withCount (List.length detail.lines)
                    , Tabs.tab "history" "History" |> Tabs.withCount (List.length detail.history)
                    , Tabs.tab "notes" "Notes" |> Tabs.withCount (List.length detail.notes)
                    ]
                ]
                resolved
            , Tabs.panel resolved "details" (\_ -> viewFacts detail)
            , Tabs.panel resolved "lines" (\_ -> viewLines model detail)
            , Tabs.panel resolved "history" (\_ -> viewHistory model detail)
            , Tabs.panel resolved "notes" (\_ -> viewNotes model detail)
            ]
        ]


viewFacts : Detail -> Html Msg
viewFacts detail =
    let
        order =
            detail.order
    in
    DescriptionList.view [ DescriptionList.columns 2, DescriptionList.bordered ]
        [ DescriptionList.text "Customer" order.customer
        , DescriptionList.text "Contact" detail.email
        , DescriptionList.text "Ship to" detail.shipTo
        , DescriptionList.maybe "Assignee" order.assignee
        , DescriptionList.text "Created" (Format.date Locale.en order.created)
        , DescriptionList.text "Due" (Format.date Locale.en order.due)
        , DescriptionList.text "Items" (String.fromInt order.items)
        , DescriptionList.text "Total" (Format.currency Locale.en "USD" 2 order.total)
        ]


viewLines : Model -> Detail -> Html Msg
viewLines model detail =
    Table.view LinesMsg
        [ Table.label "Order lines"
        , Table.columns
            [ Table.text (Table.columnId "sku") "SKU" .sku [ Table.width 110 ]
            , Table.text (Table.columnId "product") "Product" .product []
            , Table.int (Table.columnId "quantity") "Qty" .quantity [ Table.footerSum ]
            , Table.float (Table.columnId "unit") "Unit price" 2 .unitPrice []
            , Table.float (Table.columnId "line") "Line total" 2 (\l -> toFloat l.quantity * l.unitPrice) [ Table.footerSum ]
            ]
        , Table.rows (Loaded detail.lines)
        , Table.unpaged
        ]
        model.lines


viewHistory : Model -> Detail -> Html Msg
viewHistory model detail =
    Timeline.view
        [ Timeline.zone model.zone
        , Timeline.now model.now
        , Timeline.ariaLabel "Order history"
        ]
        (List.map
            (\event ->
                Timeline.event event.id event.at event.title
                    |> Timeline.withTone event.tone
                    |> Timeline.withAuthor event.by
            )
            detail.history
        )


viewNotes : Model -> Detail -> Html Msg
viewNotes model detail =
    Layout.stack [ Layout.gap 3 ]
        [ TextArea.view
            [ TextArea.label "New note"
            , TextArea.value model.noteDraft
            , TextArea.onInput NoteInput
            , TextArea.rows 3
            , TextArea.errorMaybe model.noteError
            , TextArea.disabled model.noteSaving
            , TextArea.id "note-draft"
            ]
        , Layout.row [ Layout.justifyEnd ]
            [ Button.view
                [ Button.primary
                , Button.loading model.noteSaving
                , Button.onClick SaveNote
                ]
                "Save note"
            ]
        , Layout.divider
        , if List.isEmpty detail.notes then
            Text.muted "No notes yet."

          else
            Layout.stack [ Layout.gap 3 ]
                (List.map
                    (\note ->
                        Layout.stack [ Layout.gap 1 ]
                            [ Text.paragraph note.text
                            , Text.muted (note.by ++ ", " ++ Format.dateTime Locale.en model.zone note.at)
                            ]
                    )
                    detail.notes
                )
        ]
