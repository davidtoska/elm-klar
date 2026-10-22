module Main exposing (main)

{-| Fulfilment desk: an inbox of orders that live on a (dummy) server, with filters and saved
views, bulk actions, a drawer with the order, a command palette and keyboard shortcuts.
-}

import Api
import Backend exposing (Db, Target(..))
import Browser
import Browser.Navigation as Nav
import Domain exposing (Detail, OrderId, Status(..), Summary)
import File.Download
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
import Klar.FilterBar as FilterBar
import Klar.Form as Form
import Klar.Form.Layout as FormLayout
import Klar.Form.Spec as Spec
import Klar.Format as Format
import Klar.Icon as Icon
import Klar.Layout as Layout
import Klar.Locale as Locale
import Klar.Menu as Menu
import Klar.Money as Money
import Klar.Overlay exposing (Overlay)
import Klar.PageHeader as PageHeader
import Klar.Remote as Remote exposing (Remote(..))
import Klar.RemoteView as RemoteView
import Klar.Rule as Rule exposing (Rule)
import Klar.SavedViews as SavedViews
import Klar.Select as Select
import Klar.Shortcut as Shortcut
import Klar.ShortcutHelp as ShortcutHelp
import Klar.SideNav as SideNav
import Klar.Table as Table
import Klar.Text as Text
import Klar.Theme exposing (Tone(..))
import Klar.Timeline as Timeline
import Klar.Toast as Toast
import Klar.Validate as Validate
import Process
import Task
import Time
import Url exposing (Url)



-- ROUTES


type Page
    = Orders


{-| `#/orders`, `#/orders/SO-1042` (the drawer) and `#/orders?view=Late` (a saved view by name).
`#/orders?sim=list,slow` starts with the next list request failing and a slow network.
-}
type alias Route =
    { order : Maybe String
    , view : Maybe String
    , sim : List String
    }


parseRoute : Url -> Route
parseRoute url =
    let
        fragment =
            Maybe.withDefault "" url.fragment

        ( path, query ) =
            case String.split "?" fragment of
                [ p ] ->
                    ( p, "" )

                p :: rest ->
                    ( p, String.join "?" rest )

                [] ->
                    ( "", "" )

        segments =
            String.split "/" path |> List.filter (not << String.isEmpty)

        param name =
            query
                |> String.split "&"
                |> List.filterMap
                    (\pair ->
                        case String.split "=" pair of
                            [ key, value ] ->
                                if key == name then
                                    Url.percentDecode value

                                else
                                    Nothing

                            _ ->
                                Nothing
                    )
                |> List.head
    in
    { order =
        case segments of
            [ "orders", number ] ->
                Just number

            _ ->
                Nothing
    , view = param "view"
    , sim = param "sim" |> Maybe.map (String.split ",") |> Maybe.withDefault []
    }


orderUrl : Summary -> String
orderUrl order =
    "#/orders/" ++ order.number


ordersUrl : String
ordersUrl =
    "#/orders"


idFromNumber : String -> OrderId
idFromNumber number =
    String.dropLeft 3 number
        |> String.toInt
        |> Maybe.withDefault 0
        |> (\n -> Domain.OrderId (n - 1000))



-- MODEL


type alias Model =
    { key : Nav.Key
    , route : Route
    , shell : AppShell.State Page
    , ready : Bool
    , zone : Time.Zone
    , now : Time.Posix
    , db : Db
    , sim : Api.Sim
    , simMenu : Menu.State

    -- the inbox
    , table : Table.State OrderId
    , filterBar : FilterBar.State
    , views : SavedViews.State
    , rows : Remote (List Summary)
    , total : Int
    , ticket : Int

    -- bulk actions
    , bulkBusy : Bool
    , assignDialog : ConfirmDialog.State
    , assignee : Select.State String
    , bulkTarget : Maybe Target

    -- the drawer
    , drawer : Drawer.State
    , detail : Remote Detail
    , openId : Maybe OrderId
    , lines : Table.State String
    , statusBusy : Bool
    , stepDialog : ConfirmDialog.State
    , pendingStep : Maybe Status
    , discardDialog : ConfirmDialog.State
    , note : Form.State ()
    , noteStatus : FormLayout.Status

    -- palette, help, shortcuts, toasts
    , palette : CommandPalette.State
    , hits : Remote (List Summary)
    , paletteTicket : Int
    , help : ShortcutHelp.State
    , shortcuts : Shortcut.State
    , toasts : Toast.State Msg
    }


type Msg
    = ShellMsg AppShell.Msg
    | GotClock ( Time.Zone, Time.Posix )
    | Tick Time.Posix
    | SimMenuMsg Menu.Msg
    | ToggleFailure Api.Kind
    | ToggleSlow
      -- the inbox
    | TableMsg Table.Msg
    | FilterBarMsg FilterBar.Msg
    | ViewsMsg SavedViews.Msg
    | NewView
    | ShareView
    | GotViewsSaved (Result Remote.Problem ()) Time.Posix
    | RetrySaveViews
    | GotPage Int (Result Remote.Problem Domain.Page) Time.Posix
    | Refresh
    | ResetFilters
      -- bulk actions
    | PackSelected
    | ExportSelected
    | GotExport (Result Remote.Problem ( Int, String )) Time.Posix
    | AskAssign
    | AssigneeMsg (Select.Msg String)
    | ConfirmAssign
    | CancelAssign
    | AssignDialogMsg ConfirmDialog.Msg
    | GotBulk BulkKind (Result Remote.Problem Backend.BulkOutcome) Time.Posix
      -- the drawer
    | OpenOrder Summary
    | DrawerMsg Drawer.Msg
    | RequestCloseDrawer
    | GotDetail OrderId (Result Remote.Problem Detail) Time.Posix
    | ReloadDetail
    | LinesMsg Table.Msg
    | StepRequested Status
    | ConfirmStep
    | CancelStep
    | StepDialogMsg ConfirmDialog.Msg
    | GotStep Status Status (Result Remote.Problem Detail) Time.Posix
    | DiscardDialogMsg ConfirmDialog.Msg
    | ConfirmDiscard
    | CancelDiscard
    | NoteMsg Form.Msg
    | SaveNote
    | RetrySaveNote
    | GotNote (Result Remote.Problem Detail) Time.Posix
      -- palette, help, shortcuts, toasts
    | PaletteMsg CommandPalette.Msg
    | OpenPalette
    | PaletteDebounced Int
    | GotHits Int (Result Remote.Problem (List Summary)) Time.Posix
    | GoToOrder Summary
    | GoToOrders
    | HelpMsg ShortcutHelp.Msg
    | OpenHelp
    | ShortcutMsg Shortcut.Msg
    | ToastMsg Toast.Msg
    | NoOp


type BulkKind
    = Packing
    | Assigning String


main : Program () Model Msg
main =
    Browser.application
        { init = init
        , update = update
        , view = view
        , subscriptions = subscriptions
        , onUrlRequest = AppShell.onUrlRequest ShellMsg
        , onUrlChange = AppShell.onUrlChange ShellMsg
        }


init : () -> Url -> Nav.Key -> ( Model, Cmd Msg )
init _ url key =
    ( { key = key
      , route = parseRoute url
      , shell = AppShell.init { id = shellId, key = key } |> AppShell.setPage navigation Orders
      , ready = False
      , zone = Time.utc
      , now = Time.millisToPosix 0
      , db = Backend.empty
      , sim = Api.initialSim
      , simMenu = Menu.init "simulate-menu"
      , table = Table.init "orders" |> Table.setPageSize 200
      , filterBar = FilterBar.init "order-filters"
      , views = SavedViews.init "order-views"
      , rows = Loading
      , total = 0
      , ticket = 0
      , bulkBusy = False
      , assignDialog = ConfirmDialog.init "assign-dialog"
      , assignee = Select.init "assignee-select"
      , bulkTarget = Nothing
      , drawer = Drawer.init "order-drawer"
      , detail = NotAsked
      , openId = Nothing
      , lines = Table.init "order-lines"
      , statusBusy = False
      , stepDialog = ConfirmDialog.init "step-dialog"
      , pendingStep = Nothing
      , discardDialog = ConfirmDialog.init "discard-dialog"
      , note = Form.init noteForm
      , noteStatus = FormLayout.Idle
      , palette = CommandPalette.init "palette"
      , hits = NotAsked
      , paletteTicket = 0
      , help = ShortcutHelp.init "shortcut-help"
      , shortcuts = Shortcut.init
      , toasts = Toast.init
      }
    , Task.map2 Tuple.pair Time.here Time.now |> Task.perform GotClock
    )


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        [ Shortcut.subscription ShortcutMsg shortcuts model.shortcuts
        , Time.every 30000 Tick
        ]


today : Model -> Date
today model =
    Date.fromPosix model.zone model.now



-- THE NOTE FORM


type alias NoteFields =
    { text : Form.Field String
    }


noteForm : Form.Form () NoteFields String
noteForm =
    Spec.define "note" NoteFields identity
        |> Spec.with (Spec.text "Note" |> Spec.required |> Spec.rules [ Validate.minLength 3, Validate.maxLength 400 ])
        |> Spec.build


noteFields : NoteFields
noteFields =
    Form.fields noteForm



-- SAVED VIEWS THAT COME WITH THE DESK


statusRule : List Status -> Rule.Rule
statusRule statuses =
    Rule.ConditionRule
        { id = 0
        , field = "status"
        , operator = Rule.IsAnyOf
        , values = List.map Domain.statusKey statuses
        }


allOf : List Rule -> Rule
allOf conditions =
    Rule.GroupRule
        { id = 0
        , combinator = Rule.All
        , negated = False
        , children = conditions
        }


condition : String -> Rule.Operator -> List String -> Rule
condition field operator values =
    Rule.ConditionRule { id = 0, field = field, operator = operator, values = values }


openStatuses : List Status
openStatuses =
    [ Received, Picking, Packed ]


dueColumn : Table.ColumnId
dueColumn =
    Table.columnId "due"


totalColumn : Table.ColumnId
totalColumn =
    Table.columnId "total"


defaultViews : Date -> List SavedViews.SavedView
defaultViews day =
    [ SavedViews.savedView "My open orders"
        (allOf [ condition "assignee" Rule.Is [ Domain.currentUser ], statusRule openStatuses ])
        |> SavedViews.withNote "Assigned to you and not shipped yet"
        |> SavedViews.asDefault
    , SavedViews.savedView "Late"
        (allOf [ condition "due" Rule.Before [ Date.toIso day ], statusRule openStatuses ])
        |> SavedViews.withNote "Due before today and not shipped"
        |> SavedViews.withQuery { search = "", sort = [ ( dueColumn, Table.Ascending ) ], filters = [], page = 1, pageSize = 200 }
    , SavedViews.savedView "High value"
        (allOf [ condition "total" Rule.GreaterOrEqual [ "5000" ] ])
        |> SavedViews.withNote "Totals of 5,000 or more"
        |> SavedViews.withQuery { search = "", sort = [ ( totalColumn, Table.Descending ) ], filters = [], page = 1, pageSize = 200 }
        |> SavedViews.asShared
    ]



-- UPDATE


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        ShellMsg m ->
            let
                ( shell, cmd, address ) =
                    AppShell.update m model.shell

                next =
                    { model | shell = shell }
            in
            case address of
                Just url ->
                    enter (parseRoute url) next |> addCmd (Cmd.map ShellMsg cmd)

                Nothing ->
                    ( next, Cmd.map ShellMsg cmd )

        GotClock ( zone, now ) ->
            let
                day =
                    Date.fromPosix zone now

                db =
                    Backend.generate day |> Backend.withViews (defaultViews day)

                views =
                    SavedViews.init "order-views" |> SavedViews.setViews (Backend.savedViews db)

                defaultView =
                    SavedViews.defaultView views

                ready =
                    { model
                        | ready = True
                        , zone = zone
                        , now = now
                        , db = db
                        , sim = Api.fromNames model.route.sim
                        , views = SavedViews.setActive (Maybe.map .name defaultView) views
                        , filterBar = FilterBar.setRule (defaultView |> Maybe.map .rule |> Maybe.withDefault Rule.emptyGroup) model.filterBar
                    }
            in
            enter model.route ready
                |> andThen fetchNow

        Tick now ->
            ( { model | now = now }, Cmd.none )

        SimMenuMsg m ->
            let
                ( simMenu, cmd ) =
                    Menu.update m model.simMenu
            in
            ( { model | simMenu = simMenu }, Cmd.map SimMenuMsg cmd )

        ToggleFailure kind ->
            ( { model | sim = Api.arm kind model.sim }, Cmd.none )

        ToggleSlow ->
            ( { model | sim = Api.toggleSlow model.sim }, Cmd.none )

        -- THE INBOX
        TableMsg m ->
            let
                ( table, cmd ) =
                    Table.update m model.table
            in
            changed model { model | table = table } (Cmd.map TableMsg cmd)

        FilterBarMsg m ->
            let
                ( filterBar, cmd ) =
                    FilterBar.update m model.filterBar
            in
            changed model { model | filterBar = filterBar } (Cmd.map FilterBarMsg cmd)

        ViewsMsg m ->
            let
                ( views, cmd ) =
                    SavedViews.update m model.views

                next =
                    { model | views = views }
            in
            viewsChanged model next (Cmd.map ViewsMsg cmd)

        NewView ->
            let
                ( views, cmd ) =
                    SavedViews.startSave model.views
            in
            ( { model | views = views }, Cmd.map ViewsMsg cmd )

        ShareView ->
            case SavedViews.active model.views of
                Just view_ ->
                    let
                        shared =
                            SavedViews.views model.views
                                |> List.map
                                    (\v ->
                                        if v.name == view_.name then
                                            { v | isShared = True }

                                        else
                                            v
                                    )

                        next =
                            { model | views = SavedViews.setViews shared model.views }
                    in
                    viewsChanged model next Cmd.none
                        |> andThen
                            (pushToast
                                [ Toast.success
                                , Toast.title ("\"" ++ view_.name ++ "\" is shared")
                                , Toast.message ("Colleagues open it with #/orders?view=" ++ Url.percentEncode view_.name)
                                ]
                            )

                Nothing ->
                    ( model, Cmd.none )

        GotViewsSaved (Ok ()) _ ->
            ( model, Cmd.none )

        GotViewsSaved (Err problem) _ ->
            pushToast
                [ Toast.danger
                , Toast.title "Could not save your views"
                , Toast.message (Remote.title Locale.en problem)
                , Toast.action "Try again" RetrySaveViews
                ]
                model

        RetrySaveViews ->
            saveViews model

        GotPage ticket result at ->
            if ticket /= model.ticket then
                ( model, Cmd.none )

            else
                case result of
                    Ok page ->
                        ( { model | rows = Remote.refreshWith model.rows (Ok page.rows) at, total = page.total, now = at }, Cmd.none )

                    Err problem ->
                        ( { model | rows = Remote.refreshWith model.rows (Err problem) at, now = at }, Cmd.none )

        Refresh ->
            fetchNow { model | ticket = model.ticket + 1 }

        ResetFilters ->
            let
                cleared =
                    { model | filterBar = FilterBar.clear model.filterBar, table = Table.clearFilters model.table }
            in
            changed model cleared Cmd.none

        -- BULK ACTIONS
        PackSelected ->
            case currentTarget model of
                Just target ->
                    bulk Packing target { model | bulkBusy = True }

                Nothing ->
                    ( model, Cmd.none )

        ExportSelected ->
            case currentTarget model of
                Just target ->
                    let
                        ( sim, cmd ) =
                            Api.read Api.BulkRequest model.sim model.db (Backend.exportCsv (today model) target) GotExport
                    in
                    ( { model | sim = sim, bulkBusy = True }, cmd )

                Nothing ->
                    ( model, Cmd.none )

        GotExport (Ok ( count, csv )) at ->
            pushToast
                [ Toast.success
                , Toast.title (Format.int Locale.en count ++ " orders exported")
                , Toast.message "orders-selected.csv was downloaded."
                ]
                { model | bulkBusy = False, now = at }
                |> addCmd (File.Download.string "orders-selected.csv" "text/csv" csv)

        GotExport (Err problem) at ->
            pushToast
                [ Toast.danger
                , Toast.title "Could not export the selection"
                , Toast.message (Remote.title Locale.en problem)
                , Toast.action "Try again" ExportSelected
                ]
                { model | bulkBusy = False, now = at }

        AskAssign ->
            let
                ( dialog, cmd ) =
                    ConfirmDialog.open "" model.assignDialog
            in
            ( { model
                | assignDialog = dialog
                , assignee = Select.init "assignee-select"
                , bulkTarget = currentTarget model
              }
            , Cmd.map AssignDialogMsg cmd
            )

        AssigneeMsg m ->
            let
                ( assignee, cmd ) =
                    Select.update m model.assignee
            in
            ( { model | assignee = assignee }, Cmd.map AssigneeMsg cmd )

        ConfirmAssign ->
            case ( model.bulkTarget, Select.value model.assignee ) of
                ( Just target, Just person ) ->
                    bulk (Assigning person) target { model | assignDialog = ConfirmDialog.setBusy model.assignDialog }

                _ ->
                    ( model, Cmd.none )

        CancelAssign ->
            if ConfirmDialog.isBusy model.assignDialog then
                ( model, Cmd.none )

            else
                closeAssign model

        AssignDialogMsg m ->
            let
                ( dialog, cmd ) =
                    ConfirmDialog.update m model.assignDialog
            in
            ( { model | assignDialog = dialog }, Cmd.map AssignDialogMsg cmd )

        GotBulk kind result at ->
            let
                base =
                    { model | now = at, bulkBusy = False }
            in
            case result of
                Ok outcome ->
                    let
                        ( closed, closeCmd ) =
                            case kind of
                                Packing ->
                                    ( base, Cmd.none )

                                Assigning _ ->
                                    closeAssign base

                        cleared =
                            { closed | table = Table.clearSelection closed.table, bulkTarget = Nothing }
                    in
                    ( cleared, closeCmd )
                        |> andThen
                            (pushToast
                                [ if outcome.changed == 0 then
                                    Toast.warning

                                  else
                                    Toast.success
                                , Toast.title (bulkTitle kind outcome)
                                , Toast.message (bulkMessage kind outcome)
                                ]
                            )
                        |> andThen (\m -> fetchNow { m | ticket = m.ticket + 1 })
                        |> addCmd (Cmd.map TableMsg (Table.focus cleared.table))

                Err problem ->
                    case kind of
                        Packing ->
                            pushToast
                                [ Toast.danger
                                , Toast.title "Could not mark the orders as packed"
                                , Toast.message (Remote.title Locale.en problem ++ ". Nothing was changed.")
                                , Toast.action "Try again" PackSelected
                                ]
                                base

                        Assigning _ ->
                            ( { base | assignDialog = ConfirmDialog.setFailed problem model.assignDialog }, Cmd.none )

        -- THE DRAWER
        OpenOrder order ->
            ( model, Nav.pushUrl model.key (orderUrl order) )

        DrawerMsg m ->
            let
                ( drawer, cmd ) =
                    Drawer.update m model.drawer
            in
            ( { model | drawer = drawer }, Cmd.map DrawerMsg cmd )

        RequestCloseDrawer ->
            if Form.isDirty model.note && not model.statusBusy then
                let
                    ( dialog, cmd ) =
                        ConfirmDialog.open (Drawer.closeButtonId model.drawer) model.discardDialog
                in
                ( { model | discardDialog = dialog }, Cmd.map DiscardDialogMsg cmd )

            else
                ( model, Nav.pushUrl model.key ordersUrl )

        GotDetail id result at ->
            if model.openId /= Just id then
                ( model, Cmd.none )

            else
                case result of
                    Ok detail ->
                        ( { model | detail = Remote.refreshWith model.detail (Ok detail) at, now = at }, Cmd.none )

                    Err problem ->
                        ( { model | detail = Remote.refreshWith model.detail (Err problem) at, now = at }, Cmd.none )

        ReloadDetail ->
            case model.openId of
                Just id ->
                    fetchDetail id { model | detail = Remote.refresh model.detail }

                Nothing ->
                    ( model, Cmd.none )

        LinesMsg m ->
            let
                ( lines, cmd ) =
                    Table.update m model.lines
            in
            ( { model | lines = lines }, Cmd.map LinesMsg cmd )

        StepRequested to ->
            case Remote.toMaybe model.detail of
                Just detail ->
                    if Domain.undoable detail.summary.status to then
                        changeStep detail.summary.status to model

                    else
                        let
                            ( dialog, cmd ) =
                                ConfirmDialog.open (stepButtonId to) model.stepDialog
                        in
                        ( { model | stepDialog = dialog, pendingStep = Just to }, Cmd.map StepDialogMsg cmd )

                Nothing ->
                    ( model, Cmd.none )

        ConfirmStep ->
            case ( Remote.toMaybe model.detail, model.pendingStep ) of
                ( Just detail, Just to ) ->
                    changeStep detail.summary.status to { model | stepDialog = ConfirmDialog.setBusy model.stepDialog }

                _ ->
                    ( model, Cmd.none )

        CancelStep ->
            if ConfirmDialog.isBusy model.stepDialog then
                ( model, Cmd.none )

            else
                closeStepDialog model

        StepDialogMsg m ->
            let
                ( dialog, cmd ) =
                    ConfirmDialog.update m model.stepDialog
            in
            ( { model | stepDialog = dialog }, Cmd.map StepDialogMsg cmd )

        GotStep from to result at ->
            let
                base =
                    { model | statusBusy = False, now = at }
            in
            case result of
                Ok detail ->
                    let
                        ( closed, closeCmd ) =
                            closeStepDialog (showDetail detail at base)

                        toast =
                            if Domain.undoable from to then
                                [ Toast.success
                                , Toast.title (Domain.orderNumber detail.summary.id ++ " is " ++ Domain.statusLabel to)
                                , Toast.action "Undo" (StepRequested from)
                                ]

                            else
                                [ Toast.success
                                , Toast.title (Domain.orderNumber detail.summary.id ++ " is " ++ Domain.statusLabel to)
                                , Toast.message "This step cannot be taken back."
                                ]
                    in
                    ( closed, closeCmd )
                        |> andThen (pushToast toast)
                        |> andThen (\m -> fetchNow { m | ticket = m.ticket + 1 })

                Err problem ->
                    if ConfirmDialog.isOpen base.stepDialog then
                        ( { base | stepDialog = ConfirmDialog.setFailed problem base.stepDialog }, Cmd.none )

                    else
                        pushToast
                            [ Toast.danger
                            , Toast.title ("Could not move the order to " ++ Domain.statusLabel to)
                            , Toast.message (Remote.title Locale.en problem)
                            , Toast.action "Try again" (StepRequested to)
                            ]
                            base

        DiscardDialogMsg m ->
            let
                ( dialog, cmd ) =
                    ConfirmDialog.update m model.discardDialog
            in
            ( { model | discardDialog = dialog }, Cmd.map DiscardDialogMsg cmd )

        ConfirmDiscard ->
            let
                ( dialog, cmd ) =
                    ConfirmDialog.close model.discardDialog
            in
            ( { model | discardDialog = dialog, note = Form.init noteForm, noteStatus = FormLayout.Idle }
            , Cmd.batch [ Cmd.map DiscardDialogMsg cmd, Nav.pushUrl model.key ordersUrl ]
            )

        CancelDiscard ->
            let
                ( dialog, cmd ) =
                    ConfirmDialog.close model.discardDialog
            in
            ( { model | discardDialog = dialog }, Cmd.map DiscardDialogMsg cmd )

        NoteMsg m ->
            let
                ( note, cmd ) =
                    Form.update noteForm m model.note
            in
            ( { model | note = note }, Cmd.map NoteMsg cmd )

        SaveNote ->
            case ( model.openId, Form.toValues Locale.en noteForm model.note ) of
                ( Just id, Ok text ) ->
                    if model.noteStatus == FormLayout.Submitting then
                        ( model, Cmd.none )

                    else
                        let
                            ( sim, db, cmd ) =
                                Api.write Api.SaveRequest model.sim model.db (Backend.addNote model.now id text) GotNote
                        in
                        ( { model | sim = sim, db = db, noteStatus = FormLayout.Submitting }, cmd )

                ( _, Err _ ) ->
                    let
                        ( note, cmd ) =
                            Form.reveal noteForm model.note
                    in
                    ( { model | note = note }, Cmd.map NoteMsg cmd )

                ( Nothing, _ ) ->
                    ( model, Cmd.none )

        RetrySaveNote ->
            update SaveNote model

        GotNote result at ->
            let
                base =
                    { model | now = at }
            in
            case result of
                Ok detail ->
                    pushToast [ Toast.success, Toast.message "Note added." ]
                        ({ base
                            | note = Form.set noteFields.text "" base.note |> Form.markClean
                            , noteStatus = FormLayout.Idle
                         }
                            |> showDetail detail at
                        )

                Err problem ->
                    -- the text stays in the form
                    pushToast
                        [ Toast.danger
                        , Toast.title "Could not save the note"
                        , Toast.message "What you wrote is still in the form."
                        , Toast.action "Try again" RetrySaveNote
                        ]
                        { base | noteStatus = FormLayout.Failed problem }

        -- PALETTE, HELP, SHORTCUTS, TOASTS
        OpenPalette ->
            let
                ( palette, cmd ) =
                    CommandPalette.open "" model.palette
            in
            ( { model | palette = palette, hits = NotAsked, paletteTicket = model.paletteTicket + 1 }
            , Cmd.map PaletteMsg cmd
            )

        -- KLAR GAP: the palette search is the same compare / debounce / ticket pattern by hand (`CommandPalette.remote` draws the answer but does not ask for it)
        PaletteMsg m ->
            let
                ( palette, cmd ) =
                    CommandPalette.update m model.palette
            in
            if CommandPalette.query palette /= CommandPalette.query model.palette then
                let
                    ticket =
                        model.paletteTicket + 1

                    hits =
                        if orderSearch (CommandPalette.query palette) == "" then
                            NotAsked

                        else
                            Loading
                in
                ( { model | palette = palette, hits = hits, paletteTicket = ticket }
                , Cmd.batch
                    [ Cmd.map PaletteMsg cmd
                    , Process.sleep 250 |> Task.perform (\_ -> PaletteDebounced ticket)
                    ]
                )

            else
                ( { model | palette = palette }, Cmd.map PaletteMsg cmd )

        PaletteDebounced ticket ->
            let
                text =
                    orderSearch (CommandPalette.query model.palette)
            in
            if ticket == model.paletteTicket && text /= "" then
                let
                    ( sim, cmd ) =
                        Api.read Api.PaletteRequest model.sim model.db (\db -> Backend.searchOrders db text) (GotHits ticket)
                in
                ( { model | sim = sim, hits = Remote.refresh model.hits }, cmd )

            else
                ( model, Cmd.none )

        GotHits ticket result at ->
            if ticket /= model.paletteTicket then
                ( model, Cmd.none )

            else
                ( { model | hits = Remote.refreshWith model.hits result at }, Cmd.none )

        GoToOrder order ->
            ( model, Nav.pushUrl model.key (orderUrl order) )

        GoToOrders ->
            ( model, Nav.pushUrl model.key ordersUrl )

        HelpMsg m ->
            let
                ( help, cmd ) =
                    ShortcutHelp.update m model.help
            in
            ( { model | help = help }, Cmd.map HelpMsg cmd )

        OpenHelp ->
            let
                ( help, cmd ) =
                    ShortcutHelp.open "" model.help
            in
            ( { model | help = help }, Cmd.map HelpMsg cmd )

        ShortcutMsg m ->
            let
                ( state, fired ) =
                    Shortcut.update shortcuts m model.shortcuts

                next =
                    { model | shortcuts = state }
            in
            case fired of
                Just message ->
                    update message next

                Nothing ->
                    ( next, Cmd.none )

        ToastMsg m ->
            let
                ( toasts, cmd ) =
                    Toast.update m model.toasts
            in
            ( { model | toasts = toasts }, Cmd.map ToastMsg cmd )

        NoOp ->
            ( model, Cmd.none )


{-| An answer for an order that is no longer the open one is dropped.
-}
showDetail : Detail -> Time.Posix -> Model -> Model
showDetail detail at model =
    if model.openId == Just detail.summary.id then
        { model | detail = Remote.refreshWith model.detail (Ok detail) at }

    else
        model


addCmd : Cmd Msg -> ( Model, Cmd Msg ) -> ( Model, Cmd Msg )
addCmd extra ( model, cmd ) =
    ( model, Cmd.batch [ cmd, extra ] )


andThen : (Model -> ( Model, Cmd Msg )) -> ( Model, Cmd Msg ) -> ( Model, Cmd Msg )
andThen next ( model, cmd ) =
    let
        ( after, more ) =
            next model
    in
    ( after, Cmd.batch [ cmd, more ] )


pushToast : List (Toast.Attribute Msg) -> Model -> ( Model, Cmd Msg )
pushToast attributes model =
    let
        ( toasts, cmd ) =
            Toast.push attributes model.toasts
    in
    ( { model | toasts = toasts }, Cmd.map ToastMsg cmd )



-- ROUTE CHANGES


enter : Route -> Model -> ( Model, Cmd Msg )
enter route model =
    if not model.ready then
        ( { model | route = route }, Cmd.none )

    else
        { model | route = route }
            |> enterView route.view
            |> andThen (enterOrder route.order)


enterView : Maybe String -> Model -> ( Model, Cmd Msg )
enterView name model =
    case name of
        Just viewName ->
            if Maybe.map .name (SavedViews.active model.views) == Just viewName then
                ( model, Cmd.none )

            else
                viewsChanged model { model | views = SavedViews.apply viewName model.views } Cmd.none

        Nothing ->
            ( model, Cmd.none )


enterOrder : Maybe String -> Model -> ( Model, Cmd Msg )
enterOrder number model =
    case number of
        Just n ->
            let
                id =
                    idFromNumber n
            in
            if model.openId == Just id && Drawer.isOpen model.drawer then
                ( model, Cmd.none )

            else
                let
                    ( drawer, drawerCmd ) =
                        if Drawer.isOpen model.drawer then
                            ( model.drawer, Cmd.none )

                        else
                            Drawer.open "" model.drawer |> Tuple.mapSecond (Cmd.map DrawerMsg)

                    fresh =
                        if model.openId == Just id then
                            model

                        else
                            { model | note = Form.init noteForm, noteStatus = FormLayout.Idle, lines = Table.init "order-lines" }
                in
                fetchDetail id { fresh | drawer = drawer, openId = Just id, detail = Loading }
                    |> addCmd drawerCmd

        Nothing ->
            if Drawer.isOpen model.drawer then
                let
                    ( drawer, cmd ) =
                        Drawer.close model.drawer
                in
                ( { model | drawer = drawer, openId = Nothing }, Cmd.map DrawerMsg cmd )

            else
                ( model, Cmd.none )



-- REQUESTS


fetchDetail : OrderId -> Model -> ( Model, Cmd Msg )
fetchDetail id model =
    let
        ( sim, cmd ) =
            Api.read Api.DetailRequest model.sim model.db (\db -> Backend.detail db id) (GotDetail id)
    in
    ( { model | sim = sim }, cmd )


request : Model -> Domain.Request
request model =
    { query = Table.query model.table, rule = FilterBar.rule model.filterBar }


fetchNow : Model -> ( Model, Cmd Msg )
fetchNow model =
    let
        req =
            request model

        ( sim, cmd ) =
            Api.read Api.ListRequest model.sim model.db (\db -> Backend.list (today model) db req) (GotPage model.ticket)
    in
    ( { model | sim = sim, rows = Remote.refresh model.rows }, cmd )



-- KLAR GAP: no server-mode helper; comparing query and rule, resetting the page, the debounce and the ticket are the same in every server-mode list (copied from recipes/inbox)


{-| Compare before and after. If the query or the rule changed, ask again, after a pause. A new
rule starts at page 1.
-}
changed : Model -> Model -> Cmd Msg -> ( Model, Cmd Msg )
changed before after cmd =
    let
        ruleChanged =
            FilterBar.rule after.filterBar /= FilterBar.rule before.filterBar

        next =
            if ruleChanged then
                { after | table = Table.setPage 1 after.table }

            else
                after
    in
    if ruleChanged || Table.query next.table /= Table.query before.table then
        -- the table waits for typing to pause and the filter bar waits for "Add", so no debounce here
        fetchNow { next | ticket = next.ticket + 1 } |> addCmd cmd

    else
        ( next, cmd )


{-| The saved views changed: load the rule and query of an applied view, and store the list.
-}
viewsChanged : Model -> Model -> Cmd Msg -> ( Model, Cmd Msg )
viewsChanged before after cmd =
    let
        applied =
            if SavedViews.revision after.views /= SavedViews.revision before.views then
                let
                    active =
                        SavedViews.active after.views

                    rule =
                        active |> Maybe.map .rule |> Maybe.withDefault Rule.emptyGroup

                    table =
                        case active |> Maybe.andThen .query of
                            Just q ->
                                Table.setQuery q after.table

                            Nothing ->
                                after.table
                in
                { after | filterBar = FilterBar.setRule rule after.filterBar, table = table }

            else
                after

        ( next, fetchCmd ) =
            changed before applied cmd
    in
    if SavedViews.views after.views /= SavedViews.views before.views then
        saveViews next |> addCmd fetchCmd

    else
        ( next, fetchCmd )


saveViews : Model -> ( Model, Cmd Msg )
saveViews model =
    let
        ( sim, db, cmd ) =
            Api.write Api.ViewsRequest model.sim model.db (Backend.saveViews (SavedViews.views model.views)) GotViewsSaved
    in
    ( { model | sim = sim, db = db }, cmd )


currentTarget : Model -> Maybe Target
currentTarget model =
    case Table.selection Domain.orderIds model.table of
        Table.Selected [] ->
            Nothing

        Table.Selected ids ->
            Just (Ids ids)

        Table.AllMatching { except } ->
            Just (AllMatching (request model) except)


bulk : BulkKind -> Target -> Model -> ( Model, Cmd Msg )
bulk kind target model =
    let
        run =
            case kind of
                Packing ->
                    Backend.pack (today model) model.now target

                Assigning person ->
                    Backend.assign (today model) model.now target person

        ( sim, db, cmd ) =
            Api.write Api.BulkRequest model.sim model.db run (GotBulk kind)
    in
    ( { model | sim = sim, db = db }, cmd )


bulkTitle : BulkKind -> Backend.BulkOutcome -> String
bulkTitle kind outcome =
    case kind of
        Packing ->
            Format.plural Locale.en outcome.changed { one = "1 order packed", other = Format.int Locale.en outcome.changed ++ " orders packed" }

        Assigning person ->
            Format.plural Locale.en outcome.changed { one = "1 order assigned to " ++ person, other = Format.int Locale.en outcome.changed ++ " orders assigned to " ++ person }


bulkMessage : BulkKind -> Backend.BulkOutcome -> String
bulkMessage kind outcome =
    if outcome.skipped == 0 then
        "Nothing was skipped."

    else
        case kind of
            Packing ->
                Format.int Locale.en outcome.skipped ++ " skipped: only orders in Picking can be packed."

            Assigning _ ->
                Format.int Locale.en outcome.skipped ++ " skipped: already theirs, delivered or cancelled."


closeAssign : Model -> ( Model, Cmd Msg )
closeAssign model =
    let
        ( dialog, cmd ) =
            ConfirmDialog.close model.assignDialog
    in
    ( { model | assignDialog = dialog }, Cmd.map AssignDialogMsg cmd )


changeStep : Status -> Status -> Model -> ( Model, Cmd Msg )
changeStep from to model =
    case model.openId of
        Just id ->
            let
                ( sim, db, cmd ) =
                    Api.write Api.SaveRequest model.sim model.db (Backend.changeStatus model.now id to) (GotStep from to)
            in
            ( { model | sim = sim, db = db, statusBusy = True }, cmd )

        Nothing ->
            ( model, Cmd.none )


closeStepDialog : Model -> ( Model, Cmd Msg )
closeStepDialog model =
    if ConfirmDialog.isOpen model.stepDialog then
        let
            ( dialog, cmd ) =
                ConfirmDialog.close model.stepDialog
        in
        ( { model | stepDialog = dialog, pendingStep = Nothing }, Cmd.map StepDialogMsg cmd )

    else
        ( { model | pendingStep = Nothing }, Cmd.none )


{-| "go to order 1042" and "order 1042" search for "1042".
-}
orderSearch : String -> String
orderSearch query =
    query
        |> String.words
        |> List.filter (\w -> not (List.member (String.toLower w) [ "go", "to", "order", "orders" ]))
        |> String.join " "



-- VIEW


view : Model -> Browser.Document Msg
view model =
    { title = "Fulfilment desk"
    , body =
        [ Klar.stylesheet
        , AppShell.view
            [ AppShell.state ShellMsg model.shell
            , AppShell.brand (AppShell.brandLink { name = "Fulfilment desk", href = "#/orders", logo = Just (Icon.sized Icon.Large Icon.package) })
            , AppShell.sidebar (AppShell.sideNav ShellMsg [ SideNav.entries navigation ] model.shell)
            , AppShell.onSearch OpenPalette
            , AppShell.searchPlaceholder "Search commands and orders"
            , AppShell.searchShortcut [ "Ctrl", "K" ]
            , AppShell.userName Domain.currentUser
            , AppShell.userRole "Fulfilment"
            , AppShell.actions [ simulateMenu model ]
            , AppShell.shortcuts (Shortcut.listen ShortcutMsg shortcuts model.shortcuts)
            , AppShell.onStrayDrop NoOp
            , AppShell.overlays (overlays model)
            ]
            [ viewOrders model ]
        ]
    }


shellId : String
shellId =
    "shell"


pageKeys : SideNav.Keys Page
pageKeys =
    SideNav.keys (\_ -> "orders")


navigation : List (SideNav.Entry Page msg)
navigation =
    [ SideNav.item pageKeys { key = Orders, label = "Orders", href = ordersUrl }
        |> SideNav.withIcon Icon.clipboardCheck
    ]


simulateMenu : Model -> Html Msg
simulateMenu model =
    let
        mark on label =
            if on then
                label ++ " (on)"

            else
                label
    in
    Menu.view SimMenuMsg
        [ Menu.label "Simulate"
        , Menu.trigger [ Button.ghost, Button.icon Icon.wrench ]
        , Menu.alignEnd
        , Menu.items
            [ Menu.heading "Make the server misbehave"
            , Menu.item (mark (Api.isArmed Api.ListRequest model.sim) "Next list request fails") (ToggleFailure Api.ListRequest)
            , Menu.item (mark (Api.isArmed Api.DetailRequest model.sim) "Next order request fails") (ToggleFailure Api.DetailRequest)
            , Menu.item (mark (Api.isArmed Api.SaveRequest model.sim) "Next save fails") (ToggleFailure Api.SaveRequest)
            , Menu.item (mark (Api.isArmed Api.BulkRequest model.sim) "Next bulk action fails") (ToggleFailure Api.BulkRequest)
            , Menu.item (mark (Api.isArmed Api.PaletteRequest model.sim) "Next palette search fails") (ToggleFailure Api.PaletteRequest)
            , Menu.item (mark (Api.isArmed Api.ViewsRequest model.sim) "Next saved view save fails") (ToggleFailure Api.ViewsRequest)
            , Menu.separator
            , Menu.item (mark model.sim.slow "Slow network (+3 s)") ToggleSlow
            ]
        ]
        model.simMenu


{-| Every overlay, always, also while it is closed.
-}
overlays : Model -> List (Overlay Msg)
overlays model =
    [ Drawer.view DrawerMsg
        [ Drawer.title (drawerTitle model)
        , Drawer.subtitle (drawerSubtitle model)
        , Drawer.large
        , Drawer.onRequestClose RequestCloseDrawer
        , Drawer.busy model.statusBusy
        , Drawer.footer [ Button.view [ Button.onClick RequestCloseDrawer ] "Close" ]
        ]
        model.drawer
        (RemoteView.view
            [ RemoteView.onRetry ReloadDetail, RemoteView.loadingLabel "Loading order", RemoteView.zone model.zone ]
            model.detail
            (viewDetail model)
        )
    , ConfirmDialog.view StepDialogMsg
        (stepDialogAttributes model)
        model.stepDialog
    , ConfirmDialog.view DiscardDialogMsg
        [ ConfirmDialog.warning
        , ConfirmDialog.title "Discard the note?"
        , ConfirmDialog.message "What you wrote has not been saved."
        , ConfirmDialog.confirmLabel "Discard note"
        , ConfirmDialog.cancelLabel "Keep writing"
        , ConfirmDialog.onConfirm ConfirmDiscard
        , ConfirmDialog.onCancel CancelDiscard
        ]
        model.discardDialog
    , ConfirmDialog.view AssignDialogMsg
        [ ConfirmDialog.neutral
        , ConfirmDialog.title "Assign orders"
        , ConfirmDialog.message (bulkCountText model ++ " will be assigned to the person you choose.")
        , ConfirmDialog.body
            [ Select.view AssigneeMsg
                [ Select.label "Assign to"
                , Select.options (List.map (\name -> Select.option name name) Domain.assignees)
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
    , CommandPalette.view PaletteMsg
        [ CommandPalette.sections (paletteSections model)
        , CommandPalette.placeholder "Type a command or an order number"
        , CommandPalette.zone model.zone
        ]
        model.palette
    , ShortcutHelp.view HelpMsg [] shortcuts model.help
    , Toast.view ToastMsg [] model.toasts
    ]


bulkCountText : Model -> String
bulkCountText model =
    case model.bulkTarget of
        Just (Ids ids) ->
            Format.plural Locale.en (List.length ids) { one = "1 order", other = Format.int Locale.en (List.length ids) ++ " orders" }

        Just (AllMatching _ except) ->
            Format.int Locale.en (model.total - List.length except) ++ " orders"

        Nothing ->
            "The selected orders"


drawerTitle : Model -> String
drawerTitle model =
    case model.openId of
        Just id ->
            "Order " ++ Domain.orderNumber id

        Nothing ->
            "Order"


drawerSubtitle : Model -> String
drawerSubtitle model =
    case Remote.toMaybe model.detail of
        Just detail ->
            detail.summary.customer

        Nothing ->
            ""


stepDialogAttributes : Model -> List (ConfirmDialog.Attribute Msg)
stepDialogAttributes model =
    let
        label =
            model.pendingStep |> Maybe.map Domain.statusLabel |> Maybe.withDefault ""

        ( title, message, consequences ) =
            case model.pendingStep of
                Just Cancelled ->
                    ( "Cancel this order?"
                    , "The customer is told and the stock is released."
                    , [ "The order stays in the list as Cancelled", "It cannot be reopened" ]
                    )

                Just Shipped ->
                    ( "Ship this order?"
                    , "Once shipped the order cannot go back to the warehouse."
                    , [ "The carrier is booked", "The customer gets a tracking message" ]
                    )

                _ ->
                    ( "Move to " ++ label ++ "?", "This step cannot be taken back.", [] )
    in
    [ if model.pendingStep == Just Cancelled then
        ConfirmDialog.danger

      else
        ConfirmDialog.warning
    , ConfirmDialog.title title
    , ConfirmDialog.message message
    , ConfirmDialog.consequences consequences
    , ConfirmDialog.confirmLabel (stepVerb (Maybe.withDefault Received model.pendingStep))
    , ConfirmDialog.onConfirm ConfirmStep
    , ConfirmDialog.onCancel CancelStep
    ]


paletteSections : Model -> List (CommandPalette.Section Msg)
paletteSections model =
    [ CommandPalette.section "Commands"
        [ CommandPalette.item "Go to orders" GoToOrders
            |> CommandPalette.withIcon Icon.clipboardCheck
            |> CommandPalette.withShortcut (Shortcut.sequence [ Shortcut.char 'g', Shortcut.char 'o' ])
        , CommandPalette.item "New saved view" NewView
            |> CommandPalette.withIcon Icon.bookmark
            |> CommandPalette.withKeywords [ "save", "filter", "create" ]
            |> CommandPalette.withShortcut (Shortcut.char 'n')
        , CommandPalette.item "Refresh orders" Refresh
            |> CommandPalette.withIcon Icon.refresh
            |> CommandPalette.withShortcut (Shortcut.char 'r')
        , CommandPalette.item "Clear filters" ResetFilters
            |> CommandPalette.withIcon Icon.filter
        , CommandPalette.item "Show keyboard shortcuts" OpenHelp
            |> CommandPalette.withIcon Icon.keyboard
            |> CommandPalette.withShortcut (Shortcut.char '?')
        ]
    , CommandPalette.remote "Go to order"
        (Remote.map (List.map orderItem) model.hits)
        |> CommandPalette.emptyText "No order matches"
        |> CommandPalette.onRetry (PaletteDebounced model.paletteTicket)
    ]


orderItem : Summary -> CommandPalette.Item Msg
orderItem order =
    CommandPalette.item order.number (GoToOrder order)
        |> CommandPalette.withDescription (order.customer ++ " - " ++ Domain.statusLabel order.status)
        |> CommandPalette.withIcon Icon.package
        |> CommandPalette.withId order.number


shortcuts : List (Shortcut.Shortcut Msg)
shortcuts =
    [ Shortcut.shortcut (Shortcut.mod (Shortcut.char 'k')) "Navigation" "Open the command palette" OpenPalette
        |> Shortcut.inInputs
    , Shortcut.shortcut (Shortcut.sequence [ Shortcut.char 'g', Shortcut.char 'o' ]) "Navigation" "Go to the orders" GoToOrders
    , Shortcut.shortcut (Shortcut.char 'r') "Orders" "Refresh the list" Refresh
    , Shortcut.shortcut (Shortcut.char 'n') "Orders" "Save the current filters as a view" NewView
    , Shortcut.shortcut (Shortcut.char '?') "Help" "Show the keyboard shortcuts" OpenHelp
    ]



-- THE INBOX


viewOrders : Model -> Html Msg
viewOrders model =
    let
        rule =
            FilterBar.rule model.filterBar

        activeView =
            SavedViews.active model.views
    in
    Layout.stack [ Layout.gap 3, Layout.fillRest ]
        [ PageHeader.view
            [ PageHeader.title "Orders"
            , PageHeader.subtitle "Work through the orders that are waiting for you"
            , PageHeader.actions
                [ Button.view [ Button.secondary, Button.icon Icon.bookmark, Button.onClick NewView ] "New saved view"
                , Button.view
                    [ Button.secondary
                    , Button.icon Icon.share
                    , Button.disabled (activeView == Nothing)
                    , Button.onClick ShareView
                    ]
                    "Share view"
                ]
            ]
        , Layout.row [ Layout.gap 2, Layout.alignStart ]
            [ SavedViews.view ViewsMsg
                [ SavedViews.current rule
                , SavedViews.currentQuery (Table.query model.table)
                , SavedViews.size Klar.Theme.Small
                ]
                model.views
            , Layout.stack [ Layout.grow ]
                [ FilterBar.view FilterBarMsg
                    [ FilterBar.fields Domain.fields
                    , FilterBar.totalCount (Backend.totalOrders model.db)
                    , FilterBar.matchCount (Just model.total |> keepIf (Remote.isLoaded model.rows))
                    , FilterBar.counting (Remote.isRefreshing model.rows || Remote.isLoading model.rows)
                    , FilterBar.today (today model)
                    ]
                    model.filterBar
                ]
            ]
        , Layout.stack [ Layout.fillRest ]
            [ Table.view TableMsg
                [ Table.columns columns
                , Table.server { total = model.total }
                , Table.rows model.rows
                , Table.rowId Domain.orderIds .id
                , Table.rowLabel .number
                , Table.label "Orders"
                , Table.zone model.zone
                , Table.searchable
                , Table.searchPlaceholder "Search orders"
                , Table.selectable
                , Table.bulkActions
                    [ Button.view [ Button.small, Button.icon Icon.package, Button.loading model.bulkBusy, Button.onClick PackSelected ] "Mark as packed"
                    , Button.view [ Button.small, Button.icon Icon.userPlus, Button.onClick AskAssign ] "Assign to ..."
                    , -- KLAR GAP: server-mode `Table.exportCsv` offers the selection only while every selected row is on the page
                      Button.view [ Button.small, Button.icon Icon.download, Button.loading model.bulkBusy, Button.onClick ExportSelected ] "Export all selected"
                    ]
                , Table.exportCsv "orders.csv"
                , Table.pageSizes [ 50, 100, 200 ]
                , Table.onRowClick OpenOrder
                , Table.rowTone (rowTone (today model))
                , Table.onRefresh Refresh
                , Table.onRetry Refresh
                , Table.activeExternalFilters (Rule.conditionCount rule)
                , Table.onResetFilters ResetFilters
                , Table.emptyState [ EmptyState.title "No orders yet" ]
                , Table.fillHeight
                ]
                model.table
            ]
        ]


keepIf : Bool -> Maybe a -> Maybe a
keepIf keep value =
    if keep then
        value

    else
        Nothing


rowTone : Date -> Summary -> Maybe Tone
rowTone day order =
    if List.member order.status openStatuses && Date.compare order.due day == LT then
        Just Warning

    else
        Nothing


columns : List (Table.Column Summary Msg)
columns =
    [ Table.text (Table.columnId "number") "Order" .number [ Table.pinned, Table.width 110 ]
    , Table.text (Table.columnId "customer") "Customer" .customer [ Table.minWidth 160 ]
    , Table.badge (Table.columnId "status") "Status" (\o -> ( Domain.statusTone o.status, Domain.statusLabel o.status )) [ Table.width 130 ]
    , Table.text (Table.columnId "assignee") "Assigned to" (.assignee >> Maybe.withDefault "") [ Table.minWidth 140 ]
    , Table.date (Table.columnId "created") "Created" .created [ Table.width 120 ]
    , Table.date dueColumn "Due" .due [ Table.width 120 ]
    , Table.float totalColumn "Total" 2 (\o -> toFloat o.totalMinor / 100) [ Table.footerSum, Table.width 130 ]
    ]



-- THE DRAWER


viewDetail : Model -> Detail -> List (Html Msg)
viewDetail model detail =
    let
        summary =
            detail.summary

        order =
            [ DescriptionList.html "Status" (Badge.view [ Badge.tone (Domain.statusTone summary.status) ] (Domain.statusLabel summary.status))
            , DescriptionList.text "Customer" summary.customer
            , DescriptionList.maybe "Assigned to" summary.assignee
            , DescriptionList.text "Created" (Format.date Locale.en summary.created)
            , DescriptionList.text "Due" (Format.date Locale.en summary.due)
            , DescriptionList.text "Total" (moneyText summary.totalMinor)
            ]
    in
    [ Layout.stack [ Layout.gap 4 ]
        [ DescriptionList.view [ DescriptionList.columns 2 ] order
        , Layout.stack [ Layout.gap 2 ]
            [ Text.subheading "Change status"
            , statusActions model summary.status
            ]
        , Layout.stack [ Layout.gap 2 ]
            [ Text.subheading "Lines"
            , linesTable model detail
            ]
        , Layout.stack [ Layout.gap 2 ]
            [ Text.subheading "History"
            , Timeline.view
                [ Timeline.zone model.zone
                , Timeline.now model.now
                , Timeline.ariaLabel "History of the order"
                , Timeline.compact
                ]
                (List.map historyEvent detail.history)
            ]
        , Layout.stack [ Layout.gap 2 ]
            [ Text.subheading "Notes"
            , notes model detail
            ]
        ]
    ]


statusActions : Model -> Status -> Html Msg
statusActions model status =
    case Domain.nextSteps status of
        [] ->
            Text.secondary ("This order is " ++ String.toLower (Domain.statusLabel status) ++ "; there are no further steps.")

        steps ->
            Layout.row [ Layout.gap 2, Layout.wrap ]
                (List.map
                    (\to ->
                        Button.view
                            [ Button.id (stepButtonId to)
                            , if to == Cancelled then
                                Button.danger

                              else
                                Button.secondary
                            , Button.size Klar.Theme.Small
                            , Button.disabled model.statusBusy
                            , Button.onClick (StepRequested to)
                            ]
                            (stepVerb to)
                    )
                    steps
                )


stepButtonId : Status -> String
stepButtonId to =
    "step-" ++ Domain.statusKey to


stepVerb : Status -> String
stepVerb to =
    case to of
        Received ->
            "Back to Received"

        Picking ->
            "Start picking"

        Packed ->
            "Mark as packed"

        Shipped ->
            "Ship"

        Delivered ->
            "Mark as delivered"

        Cancelled ->
            "Cancel order"


linesTable : Model -> Detail -> Html Msg
linesTable model detail =
    Table.view LinesMsg
        [ Table.columns
            [ Table.text (Table.columnId "sku") "SKU" .sku [ Table.width 100 ]
            , Table.text (Table.columnId "name") "Product" .name [ Table.minWidth 160 ]
            , Table.int (Table.columnId "quantity") "Qty" .quantity [ Table.width 80 ]
            , Table.float (Table.columnId "unit") "Unit price" 2 (\l -> toFloat l.unitMinor / 100) [ Table.width 110 ]
            , Table.float (Table.columnId "line") "Line total" 2 (\l -> toFloat (l.unitMinor * l.quantity) / 100) [ Table.footerSum, Table.width 120 ]
            ]
        , Table.rows (Loaded detail.lines)
        , Table.rowId Table.stringIds .sku
        , Table.label "Lines"
        , Table.unpaged
        ]
        model.lines


historyEvent : Domain.HistoryEntry -> Timeline.Event Msg
historyEvent entry =
    Timeline.event entry.id entry.at entry.text
        |> Timeline.withTone entry.tone
        |> Timeline.withAuthor entry.by


notes : Model -> Detail -> Html Msg
notes model detail =
    let
        v =
            Form.bind Locale.en NoteMsg noteForm model.note

        attributes =
            [ FormLayout.id "note-form", FormLayout.onSubmit SaveNote, FormLayout.onRetry RetrySaveNote ]
    in
    Layout.stack [ Layout.gap 3 ]
        [ if List.isEmpty detail.notes then
            Text.secondary "No notes yet."

          else
            Layout.stack [ Layout.gap 2 ]
                (List.map
                    (\note ->
                        Layout.stack [ Layout.gap 1 ]
                            [ Text.paragraph note.text
                            , Text.caption (note.by ++ ", " ++ Format.dateTime Locale.en model.zone note.at)
                            ]
                    )
                    detail.notes
                )
        , FormLayout.view attributes
            [ Form.summary v
            , Form.textArea v noteFields.text []
            , FormLayout.actions
                [ FormLayout.status attributes model.noteStatus
                , Layout.spacer
                , Button.view [ Button.primary, Button.submit, Button.loading (model.noteStatus == FormLayout.Submitting) ] "Add note"
                ]
            ]
        ]


moneyText : Int -> String
moneyText minor =
    Money.fromMinor Money.eur minor
        |> Maybe.map (Money.toString Locale.en)
        |> Maybe.withDefault (String.fromInt minor)
