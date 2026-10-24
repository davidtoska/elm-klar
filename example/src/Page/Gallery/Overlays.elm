module Page.Gallery.Overlays exposing (Model, Msg, init, subscriptions, update, view)

{-| Gallery page: modals, confirmations, drawers, toasts, popovers, tooltips, the
context menu, the command palette and the shortcut sheet.

The overlays are given to `Overlay.host` as a list: it renders them next to the
content and makes the content inert while one is open, without a flag. The application already
listens to `Ctrl K`, `?` and the `g` sequences, so this page wires only `n` and
`Shift T` itself and opens its own palette and shortcut sheet from buttons.

-}

import Api.Types as Types
import Html exposing (Html)
import Klar.Badge as Badge
import Klar.Button as Button
import Klar.Card as Card
import Klar.Checkbox as Checkbox
import Klar.CommandPalette as CommandPalette
import Klar.ConfirmDialog as ConfirmDialog
import Klar.ContextMenu as ContextMenu
import Klar.Drawer as Drawer
import Klar.ErrorState as ErrorState
import Klar.Format as Format
import Klar.Icon as Icon exposing (Icon)
import Klar.Kbd as Kbd
import Klar.Layout as Layout
import Klar.Locale as Locale exposing (Locale)
import Klar.Menu as Menu
import Klar.Modal as Modal
import Klar.Overlay as Overlay exposing (Overlay)
import Klar.Popover as Popover
import Klar.Remote as Remote exposing (Problem, Remote)
import Klar.RemoteView as RemoteView
import Klar.Search as Search
import Klar.Select as Select
import Klar.Shortcut as Shortcut exposing (Shortcut)
import Klar.ShortcutHelp as ShortcutHelp
import Klar.Skeleton as Skeleton
import Klar.Spinner as Spinner
import Klar.Text as Text
import Klar.TextArea as TextArea
import Klar.TextInput as TextInput
import Klar.Theme exposing (Size(..), Tone(..))
import Klar.Toast as Toast
import Klar.Tooltip as Tooltip
import Process
import Showcase.Doc as Doc
import Showcase.Sample as Sample
import Task
import View.Labels as Labels



-- MODEL


type SizeKind
    = SizeSmall
    | SizeMedium
    | SizeLarge
    | SizeTall
    | SizeLongTitle


type alias Form =
    { customer : String
    , reference : String
    , email : String
    , phone : String
    , address : String
    , postalCode : String
    , city : String
    , notes : String
    , accepted : Bool
    , confirmByEmail : Bool
    }


type FormField
    = Customer
    | Reference
    | Email
    | Phone
    | Address
    | PostalCode
    | City
    | Notes


type alias Model =
    { shortcuts : Shortcut.State
    , lastNote : String
    , toasts : Toast.State Msg

    -- modals
    , sizeModal : Modal.State
    , sizeKind : SizeKind
    , formModal : Modal.State
    , form : Form
    , submitted : Bool
    , discard : ConfirmDialog.State
    , menuModal : Modal.State
    , menu : Menu.State
    , menuLower : Menu.State
    , nestedPopover : Popover.State
    , nestedName : String
    , nestedShow : Bool
    , country : Select.State String
    , menuPicked : String

    -- confirmations
    , neutral : ConfirmDialog.State
    , warning : ConfirmDialog.State
    , danger : ConfirmDialog.State
    , lifecycle : ConfirmDialog.State
    , lifecycleTarget : Maybe Types.Order
    , failDelete : Bool
    , deleted : List Types.OrderId

    -- drawers
    , drawerRight : Drawer.State
    , drawerLeft : Drawer.State
    , drawerOrder : Maybe Types.Order
    , drawerData : Remote Types.Order
    , failDrawer : Bool
    , onlyOpen : Bool
    , onlyUrgent : Bool
    , drawerCity : String
    , step : Int
    , noteAdded : Bool
    , cancel : ConfirmDialog.State
    , cancelAck : Bool

    -- popovers
    , filterPopover : Popover.State
    , helpPopover : Popover.State
    , filterCustomer : String
    , filterOpen : Bool
    , appliedFilter : String

    -- context menu
    , context : ContextMenu.State Types.Order

    -- palette
    , palette : CommandPalette.State
    , hits : Remote (List Types.Order)
    , ticket : Int
    , failSearch : Bool
    , recent : List Types.Order

    -- shortcut sheet
    , help : ShortcutHelp.State
    }


emptyForm : Form
emptyForm =
    { customer = ""
    , reference = ""
    , email = ""
    , phone = ""
    , address = ""
    , postalCode = ""
    , city = ""
    , notes = ""
    , accepted = False
    , confirmByEmail = True
    }


type Msg
    = ShortcutMsg Shortcut.Msg
    | Navigated String
    | NoOp
      -- modals
    | SizeMsg Modal.Msg
    | OpenSize SizeKind
    | CloseSize
    | FormMsg Modal.Msg
    | OpenForm
    | FormRequestClose
    | SaveForm
    | FormEdited FormField String
    | AcceptedChanged Bool
    | ConfirmByEmailChanged Bool
    | DiscardMsg ConfirmDialog.Msg
    | DiscardConfirmed
    | DiscardCancelled
    | MenuModalMsg Modal.Msg
    | OpenMenuModal
    | CloseMenuModal
    | MenuMsg Menu.Msg
    | MenuLowerMsg Menu.Msg
    | NestedPopoverMsg Popover.Msg
    | NestedNameChanged String
    | NestedShowChanged Bool
    | CountryMsg (Select.Msg String)
    | MenuPicked String
      -- confirmations
    | NeutralMsg ConfirmDialog.Msg
    | OpenNeutral
    | NeutralConfirmed
    | NeutralCancelled
    | WarningMsg ConfirmDialog.Msg
    | OpenWarning
    | WarningConfirmed
    | WarningCancelled
    | DangerMsg ConfirmDialog.Msg
    | OpenDanger
    | DangerConfirmed
    | DangerCancelled
    | LifecycleMsg ConfirmDialog.Msg
    | AskDelete String Types.Order
    | DeleteConfirmed
    | DeleteCancelled
    | DeleteFinished
    | FailDeleteChanged Bool
    | UndoDelete Types.Order
    | RestoreOrders
      -- drawers
    | RightDrawerMsg Drawer.Msg
    | LeftDrawerMsg Drawer.Msg
    | OpenRightDrawer
    | OpenOrder String Types.Order
    | DrawerLoaded Types.OrderId
    | RetryDrawer
    | FailDrawerChanged Bool
    | CloseRightDrawer
    | OpenLeftDrawer
    | CloseLeftDrawer
    | OnlyOpenChanged Bool
    | OnlyUrgentChanged Bool
    | DrawerCityChanged String
    | AdvanceStep
    | AddNote
    | SaveNote
    | NoteSaveFailed
    | RetrySaveNote
    | AskCancel
    | CancelMsg ConfirmDialog.Msg
    | CancelAckChanged Bool
    | CancelConfirmed
    | CancelFinished
    | CancelCancelled
    | RouteOpen Types.Order
    | RouteOpened Types.Order
      -- toasts
    | ToastMsg Toast.Msg
    | PushToast Tone
    | PushUndoToast
    | UndoArchive
    | PushManyToasts
    | PushLongToast
    | ClearToasts
      -- popovers
    | FilterPopoverMsg Popover.Msg
    | HelpPopoverMsg Popover.Msg
    | FilterCustomerChanged String
    | FilterOpenChanged Bool
    | ApplyFilter
    | ResetFilter
      -- context menu
    | ContextMsg (ContextMenu.Msg Types.Order)
    | OpenRowMenu Types.Order
    | ContextAction String
      -- palette
    | PaletteMsg CommandPalette.Msg
    | OpenPalette String
    | PaletteRan String
    | Debounced Int
    | GotHits Int (Result Problem (List Types.Order))
    | RetryHits
    | FailSearchChanged Bool
      -- shortcut sheet
    | HelpMsg ShortcutHelp.Msg
    | OpenHelp


init : ( Model, Cmd Msg )
init =
    ( { shortcuts = Shortcut.init
      , lastNote = "Nothing chosen yet."
      , toasts = Toast.init
      , sizeModal = Modal.init "size-modal"
      , sizeKind = SizeMedium
      , formModal = Modal.init "form-modal"
      , form = emptyForm
      , submitted = False
      , discard = ConfirmDialog.init "discard-dialog"
      , menuModal = Modal.init "menu-modal"
      , menu = Menu.init "menu-in-modal"
      , menuLower = Menu.init "menu-in-modal-lower"
      , nestedPopover = Popover.init "popover-in-modal"
      , nestedName = ""
      , nestedShow = True
      , country = Select.init "country-in-modal"
      , menuPicked = "Nothing picked yet."
      , neutral = ConfirmDialog.init "neutral-dialog"
      , warning = ConfirmDialog.init "warning-dialog"
      , danger = ConfirmDialog.init "danger-dialog"
      , lifecycle = ConfirmDialog.init "lifecycle-dialog"
      , lifecycleTarget = Nothing
      , failDelete = True
      , deleted = []
      , drawerRight = Drawer.init "drawer-right"
      , drawerLeft = Drawer.init "drawer-left"
      , drawerOrder = Nothing
      , drawerData = Remote.NotAsked
      , failDrawer = False
      , onlyOpen = True
      , onlyUrgent = False
      , drawerCity = ""
      , step = 0
      , noteAdded = False
      , cancel = ConfirmDialog.init "cancel-order-dialog"
      , cancelAck = False
      , filterPopover = Popover.init "filter-popover"
      , helpPopover = Popover.init "help-popover"
      , filterCustomer = ""
      , filterOpen = True
      , appliedFilter = "No filter set."
      , context = ContextMenu.init "row-context"
      , palette = CommandPalette.init "demo-palette"
      , hits = Remote.NotAsked
      , ticket = 0
      , failSearch = False
      , recent = []
      , help = ShortcutHelp.init "demo-shortcut-help"
      }
    , Cmd.none
    )



-- DATA


{-| The orders the delete example lists.
-}
deleteSamples : List Types.Order
deleteSamples =
    List.take 4 Sample.orders


{-| The orders the context menu example lists.
-}
contextSamples : List Types.Order
contextSamples =
    List.take 5 (List.drop 10 Sample.orders)


{-| What is left of a list of orders when the deleted ones are taken out.
-}
remaining : Model -> List Types.Order -> List Types.Order
remaining model samples =
    List.filter (\order -> not (List.member order.id model.deleted)) samples


countryOptions : List (Select.Option String)
countryOptions =
    List.map
        (\country -> Select.option (Types.countryCodeText country.code) country.name |> Select.withGroup country.region)
        Sample.countries



-- SHORTCUTS


{-| What this page listens to. Ctrl K, ? and the g sequences belong to the
application around the page.
-}
pageShortcuts : List (Shortcut Msg)
pageShortcuts =
    [ Shortcut.shortcut (Shortcut.char 'n') "Actions" "Create a new order" OpenForm
    , Shortcut.shortcut (Shortcut.shift (Shortcut.char 't')) "Actions" "Show a notification" (PushToast Info)
    ]


{-| What the sheet of this page lists: the shortcuts of the page and, for the
overview, the ones the application listens to everywhere (they only describe, the
application does the listening).
-}
sheetShortcuts : List (Shortcut Msg)
sheetShortcuts =
    [ Shortcut.shortcut (Shortcut.mod (Shortcut.char 'k')) "Navigation" "Open the command palette" NoOp |> Shortcut.inInputs
    , Shortcut.shortcut (Shortcut.sequence [ Shortcut.char 'g', Shortcut.char 'o' ]) "Navigation" "Go to the orders" NoOp
    , Shortcut.shortcut (Shortcut.sequence [ Shortcut.char 'g', Shortcut.char 'p' ]) "Navigation" "Go to the products" NoOp
    ]
        ++ pageShortcuts
        ++ [ Shortcut.shortcut (Shortcut.char '?') "Help" "Show keyboard shortcuts" NoOp ]



-- UPDATE


andMap : (inner -> Msg) -> (state -> Model) -> ( state, Cmd inner ) -> ( Model, Cmd Msg )
andMap toMsg toModel ( state, cmd ) =
    ( toModel state, Cmd.map toMsg cmd )


withToast : List (Toast.Attribute Msg) -> ( Model, Cmd Msg ) -> ( Model, Cmd Msg )
withToast attributes ( model, cmd ) =
    let
        ( toasts, toastCmd ) =
            Toast.push attributes model.toasts
    in
    ( { model | toasts = toasts }, Cmd.batch [ cmd, Cmd.map ToastMsg toastCmd ] )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        ShortcutMsg inner ->
            let
                ( state, fired ) =
                    Shortcut.update pageShortcuts inner model.shortcuts
            in
            case fired of
                Just next ->
                    update next { model | shortcuts = state }

                Nothing ->
                    ( { model | shortcuts = state }, Cmd.none )

        Navigated place ->
            ( model, Cmd.none )
                |> withToast [ Toast.info, Toast.title "Navigation", Toast.message ("Go to " ++ place ++ " (a demonstration only).") ]

        NoOp ->
            ( model, Cmd.none )

        -- MODALS
        SizeMsg inner ->
            Modal.update inner model.sizeModal |> andMap SizeMsg (\state -> { model | sizeModal = state })

        OpenSize kind ->
            Modal.open (sizeButtonId kind) model.sizeModal
                |> andMap SizeMsg (\state -> { model | sizeModal = state, sizeKind = kind })

        CloseSize ->
            Modal.close model.sizeModal |> andMap SizeMsg (\state -> { model | sizeModal = state })

        FormMsg inner ->
            Modal.update inner model.formModal |> andMap FormMsg (\state -> { model | formModal = state })

        OpenForm ->
            Modal.openWith { opener = "open-form", focus = [ "order-customer" ] } model.formModal
                |> andMap FormMsg (\state -> { model | formModal = state })

        FormRequestClose ->
            if model.form /= emptyForm then
                ConfirmDialog.open (Modal.closeButtonId model.formModal) model.discard
                    |> andMap DiscardMsg (\state -> { model | discard = state })

            else
                Modal.close model.formModal
                    |> andMap FormMsg (\state -> { model | formModal = state, submitted = False })

        SaveForm ->
            if formIsValid model.form then
                Modal.close model.formModal
                    |> andMap FormMsg (\state -> { model | formModal = state, form = emptyForm, submitted = False })
                    |> withToast
                        [ Toast.success
                        , Toast.title "Order saved"
                        , Toast.message ("The order for " ++ String.trim model.form.customer ++ " was created.")
                        ]

            else
                ( { model | submitted = True }, Cmd.none )

        FormEdited field value ->
            ( { model | form = setField field value model.form }, Cmd.none )

        AcceptedChanged value ->
            let
                form =
                    model.form
            in
            ( { model | form = { form | accepted = value } }, Cmd.none )

        ConfirmByEmailChanged value ->
            let
                form =
                    model.form
            in
            ( { model | form = { form | confirmByEmail = value } }, Cmd.none )

        DiscardMsg inner ->
            ConfirmDialog.update inner model.discard |> andMap DiscardMsg (\state -> { model | discard = state })

        DiscardConfirmed ->
            let
                ( discard, discardCmd ) =
                    ConfirmDialog.close model.discard

                ( formState, formCmd ) =
                    Modal.close model.formModal
            in
            ( { model | discard = discard, formModal = formState, form = emptyForm, submitted = False }
            , Cmd.batch [ Cmd.map DiscardMsg discardCmd, Cmd.map FormMsg formCmd ]
            )
                |> withToast [ Toast.warning, Toast.message "The changes were discarded." ]

        DiscardCancelled ->
            ConfirmDialog.close model.discard |> andMap DiscardMsg (\state -> { model | discard = state })

        MenuModalMsg inner ->
            Modal.update inner model.menuModal |> andMap MenuModalMsg (\state -> { model | menuModal = state })

        OpenMenuModal ->
            Modal.open "open-menu-modal" model.menuModal |> andMap MenuModalMsg (\state -> { model | menuModal = state })

        CloseMenuModal ->
            Modal.close model.menuModal |> andMap MenuModalMsg (\state -> { model | menuModal = state })

        MenuMsg inner ->
            Menu.update inner model.menu |> andMap MenuMsg (\state -> { model | menu = state })

        MenuLowerMsg inner ->
            Menu.update inner model.menuLower |> andMap MenuLowerMsg (\state -> { model | menuLower = state })

        NestedPopoverMsg inner ->
            Popover.update inner model.nestedPopover |> andMap NestedPopoverMsg (\state -> { model | nestedPopover = state })

        NestedNameChanged value ->
            ( { model | nestedName = value }, Cmd.none )

        NestedShowChanged value ->
            ( { model | nestedShow = value }, Cmd.none )

        CountryMsg inner ->
            Select.update inner model.country |> andMap CountryMsg (\state -> { model | country = state })

        MenuPicked what ->
            ( { model | menuPicked = "Picked: " ++ what ++ "." }, Cmd.none )

        -- CONFIRMATIONS
        NeutralMsg inner ->
            ConfirmDialog.update inner model.neutral |> andMap NeutralMsg (\state -> { model | neutral = state })

        OpenNeutral ->
            ConfirmDialog.open "open-neutral" model.neutral |> andMap NeutralMsg (\state -> { model | neutral = state })

        NeutralConfirmed ->
            ConfirmDialog.close model.neutral
                |> andMap NeutralMsg (\state -> { model | neutral = state })
                |> withToast [ Toast.success, Toast.title "Sent for approval", Toast.message "The order was sent to the sales manager." ]

        NeutralCancelled ->
            ConfirmDialog.close model.neutral |> andMap NeutralMsg (\state -> { model | neutral = state })

        WarningMsg inner ->
            ConfirmDialog.update inner model.warning |> andMap WarningMsg (\state -> { model | warning = state })

        OpenWarning ->
            ConfirmDialog.open "open-warning" model.warning |> andMap WarningMsg (\state -> { model | warning = state })

        WarningConfirmed ->
            ConfirmDialog.close model.warning
                |> andMap WarningMsg (\state -> { model | warning = state })
                |> withToast [ Toast.info, Toast.message "Order ORD-10001 was archived." ]

        WarningCancelled ->
            ConfirmDialog.close model.warning |> andMap WarningMsg (\state -> { model | warning = state })

        DangerMsg inner ->
            ConfirmDialog.update inner model.danger |> andMap DangerMsg (\state -> { model | danger = state })

        OpenDanger ->
            ConfirmDialog.open "open-danger" model.danger |> andMap DangerMsg (\state -> { model | danger = state })

        DangerConfirmed ->
            ConfirmDialog.close model.danger
                |> andMap DangerMsg (\state -> { model | danger = state })
                |> withToast [ Toast.danger, Toast.title "Customer deleted", Toast.message "Contoso Ltd and all its contracts were removed." ]

        DangerCancelled ->
            ConfirmDialog.close model.danger |> andMap DangerMsg (\state -> { model | danger = state })

        LifecycleMsg inner ->
            ConfirmDialog.update inner model.lifecycle |> andMap LifecycleMsg (\state -> { model | lifecycle = state })

        AskDelete opener order ->
            ConfirmDialog.open opener model.lifecycle
                |> andMap LifecycleMsg (\state -> { model | lifecycle = state, lifecycleTarget = Just order })

        DeleteConfirmed ->
            ( { model | lifecycle = ConfirmDialog.setBusy model.lifecycle }
            , Process.sleep 1500 |> Task.perform (\_ -> DeleteFinished)
            )

        DeleteCancelled ->
            if ConfirmDialog.isBusy model.lifecycle then
                -- The dialog does not offer cancel while busy; this guards
                -- against an event from the frame before it re-rendered.
                ( model, Cmd.none )

            else
                ConfirmDialog.close model.lifecycle
                    |> andMap LifecycleMsg (\state -> { model | lifecycle = state, lifecycleTarget = Nothing })

        DeleteFinished ->
            if not (ConfirmDialog.isOpen model.lifecycle) then
                ( model, Cmd.none )

            else if model.failDelete then
                ( { model
                    | lifecycle =
                        ConfirmDialog.setFailed
                            (Remote.problem Remote.server |> Remote.withCode "HTTP 503")
                            model.lifecycle
                  }
                , Cmd.none
                )

            else
                case model.lifecycleTarget of
                    Just order ->
                        ConfirmDialog.close model.lifecycle
                            |> andMap LifecycleMsg
                                (\state ->
                                    { model
                                        | lifecycle = state
                                        , lifecycleTarget = Nothing
                                        , deleted = order.id :: model.deleted
                                    }
                                )
                            |> withToast
                                [ Toast.success
                                , Toast.title "Order deleted"
                                , Toast.message (Types.orderIdText order.id ++ " was removed.")
                                , Toast.action "Undo" (UndoDelete order)
                                ]

                    Nothing ->
                        ( model, Cmd.none )

        FailDeleteChanged value ->
            ( { model | failDelete = value }, Cmd.none )

        UndoDelete order ->
            ( { model | deleted = List.filter (\id -> id /= order.id) model.deleted }, Cmd.none )
                |> withToast [ Toast.info, Toast.message (Types.orderIdText order.id ++ " was restored.") ]

        RestoreOrders ->
            ( { model | deleted = [] }, Cmd.none )

        -- DRAWERS
        RightDrawerMsg inner ->
            Drawer.update inner model.drawerRight |> andMap RightDrawerMsg (\state -> { model | drawerRight = state })

        LeftDrawerMsg inner ->
            Drawer.update inner model.drawerLeft |> andMap LeftDrawerMsg (\state -> { model | drawerLeft = state })

        OpenRightDrawer ->
            -- The order opened last, or else the first one.
            case ( model.drawerOrder, List.head Sample.orders ) of
                ( Just order, _ ) ->
                    update (OpenOrder "open-right-drawer" order) model

                ( Nothing, Just order ) ->
                    update (OpenOrder "open-right-drawer" order) model

                ( Nothing, Nothing ) ->
                    ( model, Cmd.none )

        OpenOrder opener order ->
            let
                ( drawer, cmd ) =
                    Drawer.open opener model.drawerRight
            in
            ( { model
                | drawerRight = drawer
                , drawerOrder = Just order
                , drawerData = Remote.Loading
                , recent = order :: List.filter (\other -> other.id /= order.id) model.recent |> List.take 4
              }
            , Cmd.batch [ Cmd.map RightDrawerMsg cmd, loadOrder order.id ]
            )

        DrawerLoaded id ->
            case model.drawerOrder of
                Just order ->
                    if order.id == id then
                        ( { model
                            | drawerData =
                                if model.failDrawer then
                                    Remote.Failed (Remote.problem Remote.timeout |> Remote.withCode "ETIMEDOUT")

                                else
                                    Remote.Loaded order
                          }
                        , Cmd.none
                        )

                    else
                        ( model, Cmd.none )

                Nothing ->
                    ( model, Cmd.none )

        RetryDrawer ->
            case model.drawerOrder of
                Just order ->
                    -- The "Try again" button makes way for the skeleton: the drawer
                    -- takes focus by itself, so that Escape still works.
                    ( { model | drawerData = Remote.Loading }, loadOrder order.id )

                Nothing ->
                    ( model, Cmd.none )

        FailDrawerChanged value ->
            ( { model | failDrawer = value }, Cmd.none )

        CloseRightDrawer ->
            Drawer.close model.drawerRight |> andMap RightDrawerMsg (\state -> { model | drawerRight = state })

        OpenLeftDrawer ->
            Drawer.open "open-left-drawer" model.drawerLeft |> andMap LeftDrawerMsg (\state -> { model | drawerLeft = state })

        CloseLeftDrawer ->
            Drawer.close model.drawerLeft |> andMap LeftDrawerMsg (\state -> { model | drawerLeft = state })

        OnlyOpenChanged value ->
            ( { model | onlyOpen = value }, Cmd.none )

        OnlyUrgentChanged value ->
            ( { model | onlyUrgent = value }, Cmd.none )

        DrawerCityChanged value ->
            ( { model | drawerCity = value }, Cmd.none )

        -- What the order drawer does that used to need glue: the button that
        -- was pressed is replaced (AdvanceStep) or disabled (AddNote) and the
        -- drawer keeps the focus by itself; the failure toast has an action
        -- the keyboard reaches while the drawer is open (SaveNote).
        AdvanceStep ->
            ( { model | step = model.step + 1 }, Cmd.none )

        AddNote ->
            ( { model | noteAdded = True }, Cmd.none )

        SaveNote ->
            ( model, Process.sleep 300 |> Task.perform (\_ -> NoteSaveFailed) )

        NoteSaveFailed ->
            ( model, Cmd.none )
                |> withToast
                    [ Toast.danger
                    , Toast.title "Could not save the note"
                    , Toast.message "The server did not answer."
                    , Toast.action "Try again" RetrySaveNote
                    ]

        RetrySaveNote ->
            ( { model | noteAdded = True }, Cmd.none )
                |> withToast [ Toast.success, Toast.message "The note was saved." ]

        AskCancel ->
            -- No opener: the dialog gives focus back to the button that was
            -- pressed, which is inside the drawer.
            ConfirmDialog.open "" model.cancel
                |> andMap CancelMsg (\state -> { model | cancel = state, cancelAck = False })

        CancelMsg inner ->
            ConfirmDialog.update inner model.cancel |> andMap CancelMsg (\state -> { model | cancel = state })

        CancelAckChanged value ->
            -- A failure that was shown is over once the user changes the answer.
            ( { model | cancelAck = value, cancel = ConfirmDialog.clearFailure model.cancel }, Cmd.none )

        CancelConfirmed ->
            ( { model | cancel = ConfirmDialog.setBusy model.cancel }
            , Process.sleep 600 |> Task.perform (\_ -> CancelFinished)
            )

        CancelFinished ->
            ( { model
                | cancel =
                    ConfirmDialog.setFailed
                        (Remote.problem Remote.server |> Remote.withCode "HTTP 503")
                        model.cancel
              }
            , Cmd.none
            )

        CancelCancelled ->
            if ConfirmDialog.isBusy model.cancel then
                ( model, Cmd.none )

            else
                ConfirmDialog.close model.cancel |> andMap CancelMsg (\state -> { model | cancel = state })

        RouteOpen order ->
            -- The palette closed, and the drawer opens one update later, as when
            -- a route change opens it: nothing carries the opener.
            ( model, Process.sleep 0 |> Task.perform (\_ -> RouteOpened order) )

        RouteOpened order ->
            update (OpenOrder "" order) model

        -- TOASTS
        ToastMsg inner ->
            Toast.update inner model.toasts |> andMap ToastMsg (\state -> { model | toasts = state })

        PushToast tone ->
            ( model, Cmd.none ) |> withToast (toastFor tone)

        PushUndoToast ->
            ( model, Cmd.none )
                |> withToast
                    [ Toast.info
                    , Toast.message "Three orders were moved to the archive."
                    , Toast.action "Undo" UndoArchive
                    ]

        UndoArchive ->
            ( model, Cmd.none )
                |> withToast [ Toast.info, Toast.message "The orders were taken out of the archive again." ]

        PushManyToasts ->
            List.range 1 7
                |> List.foldl
                    (\n acc ->
                        withToast
                            [ if modBy 3 n == 0 then
                                Toast.warning

                              else
                                Toast.info
                            , Toast.title ("Notification " ++ String.fromInt n)
                            , Toast.message "Only four are shown at a time. The rest wait in a queue."
                            ]
                            acc
                    )
                    ( model, Cmd.none )

        PushLongToast ->
            ( model, Cmd.none )
                |> withToast
                    [ Toast.warning
                    , Toast.title "The import was stopped because the file contains more rows with invalid values than the limit of fifty"
                    , Toast.message "Row 1,204: The date 2026-02-31 does not exist. Row 1,205: The postal code is missing. Row 1,207: The phone number has too many digits. Fix the file and upload it again."
                    ]

        ClearToasts ->
            ( { model | toasts = Toast.dismissAll model.toasts }, Cmd.none )

        -- POPOVERS
        FilterPopoverMsg inner ->
            Popover.update inner model.filterPopover |> andMap FilterPopoverMsg (\state -> { model | filterPopover = state })

        HelpPopoverMsg inner ->
            Popover.update inner model.helpPopover |> andMap HelpPopoverMsg (\state -> { model | helpPopover = state })

        FilterCustomerChanged value ->
            ( { model | filterCustomer = value }, Cmd.none )

        FilterOpenChanged value ->
            ( { model | filterOpen = value }, Cmd.none )

        ApplyFilter ->
            Popover.close model.filterPopover
                |> andMap FilterPopoverMsg
                    (\state ->
                        { model
                            | filterPopover = state
                            , appliedFilter = describeFilter model.filterCustomer model.filterOpen
                        }
                    )

        ResetFilter ->
            ( { model | filterCustomer = "", filterOpen = False, appliedFilter = describeFilter "" False }, Cmd.none )

        -- CONTEXT MENU
        ContextMsg inner ->
            ContextMenu.update inner model.context |> andMap ContextMsg (\state -> { model | context = state })

        OpenRowMenu order ->
            ContextMenu.openFor (contextRowId order ++ "-more") order model.context
                |> andMap ContextMsg (\state -> { model | context = state })

        ContextAction note ->
            ( { model | lastNote = note }, Cmd.none )

        -- PALETTE
        PaletteMsg inner ->
            let
                ( palette, cmd ) =
                    CommandPalette.update inner model.palette
            in
            if CommandPalette.query palette /= CommandPalette.query model.palette then
                -- The query changed: forget old hits, and ask the "backend"
                -- after a short pause (so typing does not send a request per key).
                let
                    ticket =
                        model.ticket + 1
                in
                ( { model | palette = palette, hits = Remote.NotAsked, ticket = ticket }
                , Cmd.batch
                    [ Cmd.map PaletteMsg cmd
                    , Process.sleep 250 |> Task.perform (\_ -> Debounced ticket)
                    ]
                )

            else
                ( { model | palette = palette }, Cmd.map PaletteMsg cmd )

        OpenPalette opener ->
            -- A new ticket: an answer to a search from the last time the palette
            -- was open must not show up under the empty query.
            CommandPalette.open opener model.palette
                |> andMap PaletteMsg (\state -> { model | palette = state, hits = Remote.NotAsked, ticket = model.ticket + 1 })

        PaletteRan label ->
            ( { model | lastNote = "Command: " ++ label ++ "." }, Cmd.none )
                |> withToast [ Toast.info, Toast.title "Command run", Toast.message label ]

        Debounced ticket ->
            if ticket == model.ticket && paletteArgument model.palette /= "" then
                ( { model | hits = Remote.Loading }
                , searchOrders ticket (paletteArgument model.palette) model.failSearch
                )

            else
                ( model, Cmd.none )

        GotHits ticket result ->
            if ticket == model.ticket then
                ( { model | hits = Remote.fromResult result }, Cmd.none )

            else
                ( model, Cmd.none )

        RetryHits ->
            ( { model | hits = Remote.Loading, ticket = model.ticket + 1 }
            , searchOrders (model.ticket + 1) (paletteArgument model.palette) model.failSearch
            )

        FailSearchChanged value ->
            ( { model | failSearch = value }, Cmd.none )

        -- SHORTCUT SHEET
        HelpMsg inner ->
            ShortcutHelp.update inner model.help |> andMap HelpMsg (\state -> { model | help = state })

        OpenHelp ->
            ShortcutHelp.open "open-help" model.help |> andMap HelpMsg (\state -> { model | help = state })


{-| The pretend backend: fetches one order after 700 ms.
-}
loadOrder : Types.OrderId -> Cmd Msg
loadOrder id =
    Process.sleep 700 |> Task.perform (\_ -> DrawerLoaded id)


{-| The pretend backend: finds orders by customer or number after 700 ms, or
fails.
-}
searchOrders : Int -> String -> Bool -> Cmd Msg
searchOrders ticket text shouldFail =
    Process.sleep 700
        |> Task.map
            (\_ ->
                if shouldFail then
                    Err (Remote.problem Remote.server |> Remote.withCode "HTTP 503")

                else
                    Ok (Search.filter (\order -> order.customer ++ " " ++ Types.orderIdText order.id) text Sample.orders |> List.take 6)
            )
        |> Task.perform (GotHits ticket)


toastFor : Tone -> List (Toast.Attribute Msg)
toastFor tone =
    case tone of
        Success ->
            [ Toast.success, Toast.title "Changes saved", Toast.message "The order was updated." ]

        Warning ->
            [ Toast.warning, Toast.title "Remember to finish", Toast.message "Three orders have no delivery date." ]

        Danger ->
            [ Toast.danger, Toast.title "Could not send", Toast.message "The message was not delivered. This notification stays until you close it." ]

        _ ->
            [ Toast.info, Toast.title "For your information", Toast.message "The report is updated every night at 02:00." ]


describeFilter : String -> Bool -> String
describeFilter customer onlyOpen =
    case ( String.trim customer, onlyOpen ) of
        ( "", False ) ->
            "No filter set."

        ( "", True ) ->
            "Open orders only."

        ( name, False ) ->
            "Customer contains “" ++ name ++ "”."

        ( name, True ) ->
            "Customer contains “" ++ name ++ "”, open orders only."


setField : FormField -> String -> Form -> Form
setField field value form =
    case field of
        Customer ->
            { form | customer = value }

        Reference ->
            { form | reference = value }

        Email ->
            { form | email = value }

        Phone ->
            { form | phone = value }

        Address ->
            { form | address = value }

        PostalCode ->
            { form | postalCode = value }

        City ->
            { form | city = value }

        Notes ->
            { form | notes = value }


formIsValid : Form -> Bool
formIsValid form =
    String.trim form.customer /= "" && String.trim form.reference /= "" && emailError form == Nothing


emailError : Form -> Maybe String
emailError form =
    if form.email /= "" && not (String.contains "@" form.email) then
        Just "The email address must contain @"

    else
        Nothing


sizeButtonId : SizeKind -> String
sizeButtonId kind =
    case kind of
        SizeSmall ->
            "open-size-small"

        SizeMedium ->
            "open-size-medium"

        SizeLarge ->
            "open-size-large"

        SizeTall ->
            "open-size-tall"

        SizeLongTitle ->
            "open-size-long"


subscriptions : Model -> Sub Msg
subscriptions model =
    Shortcut.subscription ShortcutMsg pageShortcuts model.shortcuts



-- VIEW


view : Locale -> Model -> Html Msg
view locale model =
    Overlay.host
        { attributes = [ Shortcut.listen ShortcutMsg pageShortcuts model.shortcuts ]
        , page =
            [ Doc.page
                { title = "Dialogs and overlays"
                , description = "Modals, confirmations, drawers, toasts, popovers, tooltips, the context menu, the command palette and the shortcut sheet. The dialogs open from the buttons in the examples. Once focus is in the page (click anywhere on it), N creates an order and Shift T shows a notification. The language switch in the top bar changes the built-in texts of every component here."
                }
                [ modalSection model
                , confirmSection model
                , drawerSection model
                , toastSection model
                , popoverSection locale model
                , tooltipSection
                , contextSection model
                , paletteSection model
                , helpSection
                , ContextMenu.view ContextMsg [ ContextMenu.items contextItems, ContextMenu.ariaLabel "Order actions", ContextMenu.locale locale ] model.context
                ]
            ]
        , overlays = overlays locale model
        }


statusBadge : Types.Order -> Html msg
statusBadge order =
    Badge.status (Labels.statusTone order.status) (Types.orderStatusLabel order.status)



-- SECTION: MODAL


modalSection : Model -> Html Msg
modalSection model =
    Doc.section "Modal"
        "A dialog that takes over the page when the user has to do something before going on. Tab and Shift+Tab keep focus inside the dialog, Escape and a click outside close it (not a static dialog), and focus returns to the button that opened it. The page behind cannot be scrolled, and the overlay layer also makes it inert, so the keyboard cannot reach it either."
        [ Doc.example
            { title = "Sizes"
            , description = Just "Small (400 px), medium (560 px, the default), large (800 px) and full height. The content scrolls on its own while the header and footer stay put."
            , code = Just modalSizesCode
            }
            (Layout.row [ Layout.gap 2, Layout.wrap ]
                [ Button.view [ Button.id "open-size-small", Button.onClick (OpenSize SizeSmall) ] "Small"
                , Button.view [ Button.id "open-size-medium", Button.onClick (OpenSize SizeMedium) ] "Medium"
                , Button.view [ Button.id "open-size-large", Button.onClick (OpenSize SizeLarge) ] "Large"
                , Button.view [ Button.id "open-size-tall", Button.onClick (OpenSize SizeTall) ] "Full height"
                , Button.view [ Button.id "open-size-long", Button.onClick (OpenSize SizeLongTitle) ] "Long title"
                ]
            )
        , Doc.example
            { title = "Form with unsaved data"
            , description = Just "A static dialog: Escape and a click outside do nothing (the dialog shakes a little). The close button and Cancel ask whether to discard the changes, with a confirmation dialog on top. Saving with a required field empty shows the errors. The form is long enough to scroll. Shortcut: N."
            , code = Just modalFormCode
            }
            (Layout.row [ Layout.gap 2, Layout.wrap, Layout.alignCenter ]
                [ Button.view [ Button.id "open-form", Button.primary, Button.icon Icon.plus, Button.onClick OpenForm ] "New order"
                , Text.caption "Fill in a field and try Escape, a click outside and the close button."
                ]
            )
        , Doc.example
            { title = "Menu, panel and select inside a dialog"
            , description = Just ("A menu, a panel and a select open above the dialog, and Escape closes only the popup. " ++ model.menuPicked)
            , code = Just modalPopupsCode
            }
            (Button.view [ Button.id "open-menu-modal", Button.onClick OpenMenuModal ] "Open a dialog with a menu")
        ]



-- SECTION: CONFIRM


confirmSection : Model -> Html Msg
confirmSection model =
    Doc.section "ConfirmDialog"
        "The question “are you sure?” with everything that belongs to it: a tone (neutral, warning, danger), the consequences, text the user has to type to confirm, and the whole life of the request: waiting, failing and trying again, closing on success. Focus starts on Cancel (or on the typed-confirmation field), so a stray Enter never confirms."
        [ Doc.example
            { title = "Three tones"
            , description = Just "Neutral, warning with a body and consequences, and danger with typed confirmation. “delete” works too, because the dialog ignores case."
            , code = Just confirmTonesCode
            }
            (Layout.row [ Layout.gap 2, Layout.wrap ]
                [ Button.view [ Button.id "open-neutral", Button.onClick OpenNeutral ] "Neutral"
                , Button.view [ Button.id "open-warning", Button.onClick OpenWarning ] "Warning"
                , Button.view [ Button.id "open-danger", Button.danger, Button.icon Icon.trash, Button.onClick OpenDanger ] "Delete customer"
                ]
            )
        , Doc.example
            { title = "Life of a request"
            , description = Just "Confirm the deletion: the button shows a spinner and the dialog cannot be closed while the “server” works for a second and a half. On failure the dialog stays open with the problem and “Try again”. Turn off “Simulate a failure” to let it through; a notification with Undo follows."
            , code = Just confirmLifecycleCode
            }
            (Layout.stack [ Layout.gap 3 ]
                [ Checkbox.view
                    [ Checkbox.label "Simulate a failure from the server"
                    , Checkbox.checked model.failDelete
                    , Checkbox.onCheck FailDeleteChanged
                    ]
                , orderList model deleteSamples deleteRow
                ]
            )
        ]


{-| A card with a row for each order that has not been deleted, or a note and a
way back when none is left.
-}
orderList : Model -> List Types.Order -> (Types.Order -> Html Msg) -> Html Msg
orderList model samples viewRow =
    case remaining model samples of
        [] ->
            Layout.row [ Layout.gap 3, Layout.alignCenter, Layout.wrap ]
                [ Text.caption "All orders are deleted. Use Undo in the notification, or restore the examples."
                , Button.view [ Button.small, Button.icon Icon.undo, Button.onClick RestoreOrders ] "Restore the examples"
                ]

        rows ->
            Card.view [ Card.flush ] (List.intersperse Layout.divider (List.map viewRow rows))


deleteButtonId : Types.Order -> String
deleteButtonId order =
    "delete-" ++ Types.orderIdText order.id


deleteRow : Types.Order -> Html Msg
deleteRow order =
    Layout.row [ Layout.gap 3, Layout.alignCenter, Layout.padding 2 ]
        [ Layout.stack [ Layout.gap 0, Layout.grow ]
            [ Text.strong (Types.orderIdText order.id ++ " · " ++ order.customer)
            , Text.caption (order.email ++ " · " ++ order.city)
            ]
        , statusBadge order
        , Button.iconOnly
            [ Button.ghost
            , Button.id (deleteButtonId order)
            , Button.onClick (AskDelete (deleteButtonId order) order)
            , Button.htmlAttrs (Tooltip.attrs ("Delete " ++ Types.orderIdText order.id))
            ]
            Icon.trash
            ("Delete " ++ Types.orderIdText order.id)
        ]



-- SECTION: DRAWER


drawerSection : Model -> Html Msg
drawerSection model =
    Doc.section "Drawer"
        "A panel from the side for the details of a row in a list, or for filters with many fields. It behaves like the modal: focus moves in, Tab stays inside, Escape and a click outside close it unless it is static, and focus returns to the opener. Widths: 360, 480 (the default) and 720 px."
        [ Doc.example
            { title = "From the right and from the left"
            , description = Just "The details of an order from the right (a skeleton while the data is fetched, and a failure with “Try again”), and filters from the left in a small, static drawer."
            , code = Just drawerCode
            }
            (Layout.stack [ Layout.gap 3 ]
                [ Layout.row [ Layout.gap 2, Layout.wrap ]
                    [ Button.view [ Button.id "open-right-drawer", Button.onClick OpenRightDrawer ] "Open from the right"
                    , Button.view [ Button.id "open-left-drawer", Button.onClick OpenLeftDrawer ] "Filters from the left"
                    ]
                , Checkbox.view
                    [ Checkbox.label "Simulate a failure when the order is fetched"
                    , Checkbox.checked model.failDrawer
                    , Checkbox.onCheck FailDrawerChanged
                    ]
                ]
            )
        ]



-- SECTION: TOAST


toastSection : Model -> Html Msg
toastSection model =
    Doc.section "Toast"
        "Short notifications in the bottom right corner that stack up and disappear by themselves: info and success after a few seconds, warnings a little later, errors stay until they are closed. The timer stops while the pointer is over a notification or focus is inside it. A notification can carry an action, typically Undo. At most four are shown, the rest wait in a queue. Screen readers are told without being interrupted."
        [ Doc.example
            { title = "All tones"
            , description = Just ("Notifications now: " ++ String.fromInt (Toast.count model.toasts) ++ ", of which " ++ String.fromInt (Toast.queued model.toasts) ++ " in the queue.")
            , code = Just toastCode
            }
            (Layout.row [ Layout.gap 2, Layout.wrap ]
                [ Button.view [ Button.icon Icon.info, Button.onClick (PushToast Info) ] "Info"
                , Button.view [ Button.icon Icon.checkCircle, Button.onClick (PushToast Success) ] "Success"
                , Button.view [ Button.icon Icon.warning, Button.onClick (PushToast Warning) ] "Warning"
                , Button.view [ Button.icon Icon.errorCircle, Button.onClick (PushToast Danger) ] "Error"
                , Button.view [ Button.icon Icon.undo, Button.onClick PushUndoToast ] "With Undo"
                , Button.view [ Button.icon Icon.layers, Button.onClick PushManyToasts ] "Seven at once"
                , Button.view [ Button.icon Icon.fileText, Button.onClick PushLongToast ] "Long text"
                , Button.view [ Button.ghost, Button.onClick ClearToasts ] "Clear all"
                ]
            )
        ]



-- SECTION: POPOVER


popoverSection : Locale -> Model -> Html Msg
popoverSection locale model =
    Doc.section "Popover"
        "A small panel next to a button, with anything inside: a quick filter, a few settings, an explanation. It stays open while the user works in it. A click outside, Escape and the close button close it, and so does tabbing out of the panel. The panel is never clipped by tables or dialogs and flips when there is no room."
        [ Doc.example
            { title = "Quick filter and explanation"
            , description = Just model.appliedFilter
            , code = Just popoverCode
            }
            (Layout.row [ Layout.gap 3, Layout.alignCenter, Layout.wrap ]
                [ filterPopover locale model
                , Popover.view HelpPopoverMsg
                    [ Popover.icon Icon.help
                    , Popover.ariaLabel "What is priority?"
                    , Popover.trigger [ Button.ghost ]
                    , Popover.title "Priority levels"
                    , Popover.closeButton
                    , Popover.width 280
                    , Popover.locale locale
                    ]
                    model.helpPopover
                    [ Text.paragraph "Priority is calculated from the due date, the stock level and open issues. Urgent means the order should be picked within one working day."
                    , Text.caption "Last updated overnight."
                    ]
                ]
            )
        ]


filterPopover : Locale -> Model -> Html Msg
filterPopover locale model =
    Popover.view FilterPopoverMsg
        [ Popover.label "Filter"
        , Popover.locale locale
        , Popover.icon Icon.filter
        , Popover.title "Quick filter"
        , Popover.closeButton
        , Popover.initialFocus [ "filter-customer" ]
        ]
        model.filterPopover
        [ TextInput.view
            [ TextInput.id "filter-customer"
            , TextInput.label "Customer"
            , TextInput.placeholder "For example Cobalt"
            , TextInput.value model.filterCustomer
            , TextInput.onInput FilterCustomerChanged
            , TextInput.onEnter ApplyFilter
            , TextInput.clearable
            , TextInput.locale locale
            ]
        , Checkbox.view
            [ Checkbox.label "Open orders only"
            , Checkbox.checked model.filterOpen
            , Checkbox.onCheck FilterOpenChanged
            ]
        , Layout.row [ Layout.gap 2, Layout.justifyEnd ]
            [ Button.view [ Button.ghost, Button.onClick ResetFilter ] "Reset"
            , Button.view [ Button.primary, Button.onClick ApplyFilter ] "Apply"
            ]
        ]



-- SECTION: TOOLTIP


tooltipSection : Html Msg
tooltipSection =
    Doc.section "Tooltip"
        "Short hints without JavaScript. They appear after a short pause with the mouse and at once on keyboard focus, sit above the element and move to the side or below when there is no room. A tooltip is a visual aid: the element needs a name of its own (icon buttons get it from aria-label)."
        [ Doc.example
            { title = "Icon buttons, with and without a shortcut"
            , description = Just "Tooltip.attrs goes on any element. The shortcut is shown after the text."
            , code = Just tooltipAttrsCode
            }
            (Layout.row [ Layout.gap 2, Layout.alignCenter, Layout.wrap ]
                [ Button.iconOnly [ Button.htmlAttrs (Tooltip.attrs "Reload") ] Icon.refresh "Reload"
                , Button.iconOnly [ Button.htmlAttrs (Tooltip.attrs "Download as CSV") ] Icon.download "Download as CSV"
                , Button.iconOnly [ Button.htmlAttrs (Tooltip.attrs "Print" |> Tooltip.withShortcut "Ctrl P") ] Icon.print "Print"
                , Button.iconOnly [ Button.htmlAttrs (Tooltip.attrs "Open search" |> Tooltip.withShortcut "Ctrl K") ] Icon.search "Search"
                , Button.iconOnly [ Button.ghost, Button.htmlAttrs (Tooltip.attrs "Delete order") ] Icon.trash "Delete order"
                , Button.view [ Button.primary, Button.icon Icon.save, Button.htmlAttrs (Tooltip.attrs "Save all changes in the form" |> Tooltip.withShortcut "Ctrl S") ] "Save"
                , Button.view [ Button.htmlAttrs (Tooltip.attrsWith [ Tooltip.below ] "Shown below the button") ] "Below"
                ]
            )
        , Doc.example
            { title = "Around content, and at the edge"
            , description = Just "Tooltip.wrap makes a real tooltip with role=tooltip, linked to the content, and shows the shortcut as key caps. Use it around what cannot take attributes, such as a disabled button. The buttons on the right show that the hint is not cut off by the edge of the window."
            , code = Just tooltipWrapCode
            }
            (Layout.row [ Layout.gap 3, Layout.alignCenter ]
                [ Tooltip.wrap [] "You do not have permission to delete orders" (Button.view [ Button.danger, Button.disabled True ] "Delete")
                , Tooltip.wrap [ Tooltip.shortcut "Ctrl K" ] "Open the command palette" (Button.view [ Button.icon Icon.command ] "Commands")
                , Tooltip.wrap [ Tooltip.focusable ] "This is a long hint that wraps over several lines because it has a maximum width, and it can be reached with the keyboard because the wrapper can take focus." (Badge.view [ Badge.tone Info ] "Hover over me")
                , Layout.spacer
                , Button.iconOnly [ Button.htmlAttrs (Tooltip.attrs "This hint sits right at the edge") ] Icon.settings "Settings"
                , Tooltip.wrap [ Tooltip.shortcut "Ctrl Shift P" ] "Pin to the top" (Button.iconOnly [] Icon.bookmark "Pin")
                ]
            )
        ]



-- SECTION: CONTEXT MENU


contextSection : Model -> Html Msg
contextSection model =
    Doc.section "ContextMenu"
        "The menu that opens where the user right-clicks. One menu serves many elements, and its content is built from the row that was clicked. Arrows, Home, End, Enter and Escape work as in an ordinary menu, and the menu opens towards the free side near the edge of the window. The context menu key (or Shift+F10) works on a row that has focus. A right-click with Shift held, or in a text field, keeps the browser's own menu. The ⋯ button opens the same menu with ContextMenu.openFor."
        [ Doc.example
            { title = "Rows with a right-click menu"
            , description = Just ("Right-click a row, tab to it and press Shift+F10, or press its ⋯ button. " ++ model.lastNote)
            , code = Just contextMenuCode
            }
            (orderList model contextSamples (contextRow model))
        ]


contextRow : Model -> Types.Order -> Html Msg
contextRow model order =
    ContextMenu.area ContextMsg
        model.context
        { id = contextRowId order, target = order }
        [ Layout.row [ Layout.gap 3, Layout.alignCenter, Layout.padding 2 ]
            [ Layout.stack [ Layout.gap 0, Layout.grow ]
                [ Text.strong (Types.orderIdText order.id ++ " · " ++ order.customer)
                , Text.caption (order.email ++ " · " ++ order.city)
                ]
            , statusBadge order
            , Text.caption "Right-click"

            -- the same menu, from a button: `ContextMenu.openFor`
            , Button.iconOnly
                [ Button.ghost
                , Button.small
                , Button.id (contextRowId order ++ "-more")
                , Button.onClick (OpenRowMenu order)
                ]
                Icon.moreVertical
                ("Actions for " ++ Types.orderIdText order.id)
            ]
        ]


{-| Dialogs opened from the menu give focus back to the row (the menu itself is
gone by then).
-}
contextRowId : Types.Order -> String
contextRowId order =
    "context-row-" ++ Types.orderIdText order.id


contextItems : Types.Order -> List (Menu.Item Msg)
contextItems order =
    [ Menu.heading (Types.orderIdText order.id)
    , Menu.item "Open in drawer" (OpenOrder (contextRowId order) order) |> Menu.withIcon Icon.externalLink |> Menu.withHint "Enter"
    , Menu.item "Edit" (ContextAction ("Edit order " ++ Types.orderIdText order.id)) |> Menu.withIcon Icon.edit |> Menu.withHint "E"
    , Menu.item "Copy email address" (ContextAction ("Copied the email address of " ++ order.customer)) |> Menu.withIcon Icon.copy
    , Menu.item "Send message" (ContextAction ("Message sent to " ++ order.customer)) |> Menu.withIcon Icon.mail |> Menu.disabledItem
    , Menu.separator
    , Menu.item "Delete ..." (AskDelete (contextRowId order) order) |> Menu.withIcon Icon.trash |> Menu.danger
    ]



-- SECTION: PALETTE


paletteSection : Model -> Html Msg
paletteSection model =
    Doc.section "CommandPalette"
        "One search box for commands and content. Type to narrow down (case and accents do not matter), use the arrow keys to move, Enter to run and Escape to close. Without a query the recent items are listed. Ctrl K opens the palette of this application (the search field in the top bar); the button below opens the one that belongs to this page. Its “Orders” section is asynchronous: the page watches the query, waits a moment and asks the “server”, and the palette shows a skeleton meanwhile, then a short failure with “Try again”, or “No orders found”."
        [ Doc.example
            { title = "Command palette"
            , description = Just ("Search for a customer or an order number, for example “cobalt” or “ORD-100”. " ++ model.lastNote)
            , code = Just paletteCode
            }
            (Layout.stack [ Layout.gap 3 ]
                [ Layout.row [ Layout.gap 3, Layout.alignCenter, Layout.wrap ]
                    [ Button.view
                        [ Button.id "open-palette"
                        , Button.icon Icon.search
                        , Button.onClick (OpenPalette "open-palette")
                        ]
                        "Open the palette of this page"
                    , Kbd.view [] (Shortcut.mod (Shortcut.char 'k'))
                    , Text.caption "opens the palette of the application"
                    ]
                , Checkbox.view
                    [ Checkbox.label "Simulate a failure in the order search"
                    , Checkbox.hint "The search takes 0.7 seconds. With a failure the palette shows a short message and “Try again”."
                    , Checkbox.checked model.failSearch
                    , Checkbox.onCheck FailSearchChanged
                    ]
                ]
            )
        ]



-- SECTION: SHORTCUT SHEET


helpSection : Html Msg
helpSection =
    Doc.section "ShortcutHelp"
        "The sheet of all keyboard shortcuts of an application, built from the same list as Shortcut.listen: grouped, with key caps and a small filter box. Sequences such as “g o” show as two steps, and a shortcut that also works in text fields is marked. This sheet lists the shortcuts of this page (N and Shift T) next to the ones the application listens to."
        [ Doc.example
            { title = "Keyboard shortcuts"
            , description = Just "Press ? anywhere (not while typing in a field) for the sheet of the application. The button opens the sheet of this page."
            , code = Just helpCode
            }
            (Layout.row [ Layout.gap 3, Layout.alignCenter, Layout.wrap ]
                [ Button.view [ Button.id "open-help", Button.icon Icon.keyboard, Button.onClick OpenHelp ] "Show the shortcuts of this page"
                , Kbd.key [] "?"
                , Text.caption "opens the sheet of the application"
                ]
            )
        ]



-- OVERLAYS


overlays : Locale -> Model -> List (Overlay Msg)
overlays locale model =
    [ sizeModal locale model
    , formModal locale model
    , menuModal locale model
    , discardDialog locale model
    , neutralDialog locale model
    , warningDialog locale model
    , dangerDialog locale model
    , lifecycleDialog locale model
    , drawerRightView locale model
    , cancelDialog locale model
    , drawerLeftView locale model
    , ShortcutHelp.view HelpMsg [ ShortcutHelp.locale locale ] sheetShortcuts model.help
    , CommandPalette.view PaletteMsg
        [ CommandPalette.locale locale
        , CommandPalette.sections (paletteSections model)
        , CommandPalette.recent (List.map orderItem model.recent)
        ]
        model.palette
    , Toast.view ToastMsg [ Toast.locale locale ] model.toasts
    ]


paragraphs : List (Html msg)
paragraphs =
    [ Text.paragraph "Orders are picked in the warehouse closest to the delivery address. If an item is out of stock there, the order is split and the rest ships from the next warehouse."
    , Text.paragraph "A customer can change the delivery address until the order has been picked. After that, changes go through the carrier, and extra costs are invoiced separately."
    , Text.paragraph "Partial deliveries are invoiced when they ship. The payment term starts on the invoice date, and reminders are sent automatically after the due date."
    , Text.paragraph "Returns are accepted within thirty days if the goods are unused and in the original packaging. Refunds are paid to the original payment method within five working days."
    ]


sizeModal : Locale -> Model -> Overlay Msg
sizeModal locale model =
    let
        ( sizeAttrs, name, subtitle ) =
            case model.sizeKind of
                SizeSmall ->
                    ( [ Modal.small ], "Small dialog", "The content scrolls, the header and footer stay put" )

                SizeMedium ->
                    ( [ Modal.medium ], "Medium dialog", "The content scrolls, the header and footer stay put" )

                SizeLarge ->
                    ( [ Modal.large ], "Large dialog", "The content scrolls, the header and footer stay put" )

                SizeTall ->
                    ( [ Modal.medium, Modal.fullHeight ], "Full-height dialog", "The dialog fills the height, whatever the content" )

                SizeLongTitle ->
                    ( [ Modal.small ]
                    , "Consolidated shipment plan for an order with partial deliveries from three warehouses, including backorders and customs documents"
                    , "The title wraps over several lines and never pushes the close button out of the dialog"
                    )

        body =
            case model.sizeKind of
                SizeLongTitle ->
                    Text.paragraph "A long word without spaces must not burst the dialog either:"
                        :: Text.mono "ORD-10001-2026-10-20-000000000000000000000000000000000000000000000000000000"
                        :: paragraphs

                SizeTall ->
                    List.take 1 paragraphs

                SizeSmall ->
                    paragraphs

                _ ->
                    paragraphs ++ paragraphs
    in
    Modal.view SizeMsg
        (sizeAttrs
            ++ [ Modal.title name
               , Modal.subtitle subtitle
               , Modal.locale locale
               , Modal.footer [ Button.view [ Button.primary, Button.onClick CloseSize ] "Done" ]
               ]
        )
        model.sizeModal
        [ Layout.stack [ Layout.gap 3 ] body ]


formModal : Locale -> Model -> Overlay Msg
formModal locale model =
    let
        form =
            model.form

        requiredError label value =
            if model.submitted && String.trim value == "" then
                Just (label ++ " is required")

            else
                Nothing

        field id label fieldName value error =
            TextInput.view
                [ TextInput.id id
                , TextInput.label label
                , TextInput.value value
                , TextInput.onInput (FormEdited fieldName)
                , TextInput.errorMaybe error
                , TextInput.autocomplete "off"
                ]
    in
    Modal.view FormMsg
        [ Modal.title "New order"
        , Modal.subtitle "Fields marked * are required"
        , Modal.static
        , Modal.onRequestClose FormRequestClose
        , Modal.locale locale
        , Modal.footerStart [ Text.caption "Escape and a click outside do not close this dialog." ]
        , Modal.footer
            [ Button.view [ Button.onClick FormRequestClose ] "Cancel"
            , Button.view [ Button.primary, Button.icon Icon.save, Button.onClick SaveForm ] "Save"
            ]
        ]
        model.formModal
        [ Layout.stack [ Layout.gap 4 ]
            [ Layout.grid [ Layout.columns 2, Layout.gap 4 ]
                [ TextInput.view
                    [ TextInput.id "order-customer"
                    , TextInput.label "Customer"
                    , TextInput.required
                    , TextInput.value form.customer
                    , TextInput.onInput (FormEdited Customer)
                    , TextInput.errorMaybe (requiredError "Customer" form.customer)
                    , TextInput.autocomplete "off"
                    ]
                , TextInput.view
                    [ TextInput.id "order-reference"
                    , TextInput.label "Reference"
                    , TextInput.required
                    , TextInput.value form.reference
                    , TextInput.onInput (FormEdited Reference)
                    , TextInput.errorMaybe (requiredError "Reference" form.reference)
                    , TextInput.autocomplete "off"
                    ]
                ]
            , TextInput.view
                [ TextInput.id "order-email"
                , TextInput.label "Contact email"
                , TextInput.email
                , TextInput.value form.email
                , TextInput.onInput (FormEdited Email)
                , TextInput.errorMaybe (emailError form)
                , TextInput.hint "Used for order confirmations and shipping notices."
                ]
            , field "order-phone" "Phone" Phone form.phone Nothing
            , field "order-address" "Delivery address" Address form.address Nothing
            , Layout.grid [ Layout.columns 2, Layout.gap 4 ]
                [ field "order-postal-code" "Postal code" PostalCode form.postalCode Nothing
                , field "order-city" "City" City form.city Nothing
                ]
            , TextArea.view
                [ TextArea.id "order-notes"
                , TextArea.label "Notes"
                , TextArea.optionalText "(optional)"
                , TextArea.rows 5
                , TextArea.value form.notes
                , TextArea.onInput (FormEdited Notes)
                ]
            , Layout.divider
            , Text.subheading "Delivery terms"
            , Layout.stack [ Layout.gap 3 ] paragraphs
            , Checkbox.view
                [ Checkbox.label "The customer has accepted the delivery terms"
                , Checkbox.checked form.accepted
                , Checkbox.onCheck AcceptedChanged
                ]
            , Checkbox.view
                [ Checkbox.label "Send the order confirmation by email"
                , Checkbox.hint "Does not apply to shipping notices."
                , Checkbox.checked form.confirmByEmail
                , Checkbox.onCheck ConfirmByEmailChanged
                ]
            ]
        ]


menuModal : Locale -> Model -> Overlay Msg
menuModal locale model =
    Modal.view MenuModalMsg
        [ Modal.title "Dialog with a menu and a panel"
        , Modal.locale locale
        , Modal.footer [ Button.view [ Button.primary, Button.onClick CloseMenuModal ] "Done" ]
        ]
        model.menuModal
        [ Layout.stack [ Layout.gap 4 ]
            [ Text.paragraph "The menu, the panel and the list of the select open above the dialog and are not cut off by its scrolling content. Escape closes only the popup, never the whole dialog. A second Escape closes the dialog."
            , Layout.row [ Layout.gap 3, Layout.alignCenter, Layout.wrap ]
                [ Menu.view MenuMsg
                    [ Menu.label "Actions"
                    , Menu.items
                        [ Menu.item "Edit" (MenuPicked "Edit") |> Menu.withIcon Icon.edit
                        , Menu.item "Duplicate" (MenuPicked "Duplicate") |> Menu.withIcon Icon.copy
                        , Menu.separator
                        , Menu.item "Delete" (MenuPicked "Delete") |> Menu.withIcon Icon.trash |> Menu.danger
                        ]
                    ]
                    model.menu
                , Popover.view NestedPopoverMsg
                    [ Popover.label "Panel"
                    , Popover.locale locale
                    , Popover.icon Icon.sliders
                    , Popover.title "Settings"
                    , Popover.closeButton
                    , Popover.initialFocus [ "nested-popover-input" ]
                    ]
                    model.nestedPopover
                    [ TextInput.view
                        [ TextInput.id "nested-popover-input"
                        , TextInput.label "Display name"
                        , TextInput.value model.nestedName
                        , TextInput.onInput NestedNameChanged
                        ]
                    , Checkbox.view
                        [ Checkbox.label "Show in the overview"
                        , Checkbox.checked model.nestedShow
                        , Checkbox.onCheck NestedShowChanged
                        ]
                    ]
                , Text.caption model.menuPicked
                ]
            , Select.view CountryMsg
                [ Select.label "Country"
                , Select.clearable
                , Select.locale locale
                , Select.options countryOptions
                ]
                model.country
            , Layout.divider
            , Layout.stack [ Layout.gap 3 ] paragraphs
            , Layout.row [ Layout.gap 3, Layout.alignCenter ]
                [ Menu.view MenuLowerMsg
                    [ Menu.label "Menu at the bottom of the content"
                    , Menu.items
                        [ Menu.item "First" (MenuPicked "First")
                        , Menu.item "Second" (MenuPicked "Second")
                        , Menu.item "Third" (MenuPicked "Third")
                        ]
                    ]
                    model.menuLower
                ]
            ]
        ]


discardDialog : Locale -> Model -> Overlay Msg
discardDialog locale model =
    ConfirmDialog.view DiscardMsg
        [ ConfirmDialog.warning
        , ConfirmDialog.title "Discard the changes?"
        , ConfirmDialog.message "The form has data that is not saved. It is lost if you close it now."
        , ConfirmDialog.confirmLabel "Discard"
        , ConfirmDialog.cancelLabel "Keep editing"
        , ConfirmDialog.onConfirm DiscardConfirmed
        , ConfirmDialog.onCancel DiscardCancelled
        , ConfirmDialog.locale locale
        ]
        model.discard


neutralDialog : Locale -> Model -> Overlay Msg
neutralDialog locale model =
    ConfirmDialog.view NeutralMsg
        [ ConfirmDialog.title "Send the order for approval?"
        , ConfirmDialog.message "The order is sent to the sales manager. You cannot edit it while it is being reviewed."
        , ConfirmDialog.confirmLabel "Send"
        , ConfirmDialog.onConfirm NeutralConfirmed
        , ConfirmDialog.onCancel NeutralCancelled
        , ConfirmDialog.locale locale
        ]
        model.neutral


warningDialog : Locale -> Model -> Overlay Msg
warningDialog locale model =
    ConfirmDialog.view WarningMsg
        [ ConfirmDialog.warning
        , ConfirmDialog.title "Archive the order?"
        , ConfirmDialog.message "The order moves to the archive and no longer shows in open lists."
        , ConfirmDialog.body
            [ Layout.row [ Layout.gap 2, Layout.alignCenter, Layout.wrap ]
                [ Text.strong "ORD-10001"
                , Badge.status Success "Delivered"
                , Text.caption "Customer since 2019"
                ]
            ]
        , ConfirmDialog.consequences
            [ "Open picking tasks are closed"
            , "History and documents are kept for ten years"
            , "You can restore the order from the archive"
            ]
        , ConfirmDialog.confirmLabel "Archive"
        , ConfirmDialog.onConfirm WarningConfirmed
        , ConfirmDialog.onCancel WarningCancelled
        , ConfirmDialog.locale locale
        ]
        model.warning


dangerDialog : Locale -> Model -> Overlay Msg
dangerDialog locale model =
    ConfirmDialog.view DangerMsg
        [ ConfirmDialog.danger
        , ConfirmDialog.icon Icon.trash
        , ConfirmDialog.title "Delete the customer?"
        , ConfirmDialog.message "“Contoso Ltd” and everything that belongs to it is deleted for good."
        , ConfirmDialog.consequences
            [ "142 orders lose their customer"
            , "Contracts and invoice history are deleted"
            , "This cannot be undone"
            ]
        , ConfirmDialog.confirmLabel "Delete customer"
        , ConfirmDialog.typeToConfirm "DELETE"
        , ConfirmDialog.ignoreCase
        , ConfirmDialog.onConfirm DangerConfirmed
        , ConfirmDialog.onCancel DangerCancelled
        , ConfirmDialog.locale locale
        ]
        model.danger


lifecycleDialog : Locale -> Model -> Overlay Msg
lifecycleDialog locale model =
    let
        name =
            case model.lifecycleTarget of
                Just order ->
                    Types.orderIdText order.id ++ " (" ++ order.customer ++ ")"

                Nothing ->
                    ""
    in
    ConfirmDialog.view LifecycleMsg
        [ ConfirmDialog.danger
        , ConfirmDialog.title "Delete the order?"
        , ConfirmDialog.message (name ++ " is removed from all lists and can no longer be found in searches.")
        , ConfirmDialog.confirmLabel "Delete order"
        , ConfirmDialog.onConfirm DeleteConfirmed
        , ConfirmDialog.onCancel DeleteCancelled
        , ConfirmDialog.locale locale
        ]
        model.lifecycle


{-| Asked from inside the drawer, on top of it. The confirm button stays disabled
until the box is ticked; a failure of the server goes away when it changes.
-}
cancelDialog : Locale -> Model -> Overlay Msg
cancelDialog locale model =
    ConfirmDialog.view CancelMsg
        [ ConfirmDialog.danger
        , ConfirmDialog.title "Cancel the order?"
        , ConfirmDialog.message "The customer is told by email."
        , ConfirmDialog.body
            [ Checkbox.view
                [ Checkbox.id "cancel-ack"
                , Checkbox.label "I have checked the shipment"
                , Checkbox.checked model.cancelAck
                , Checkbox.onCheck CancelAckChanged
                ]
            ]
        , ConfirmDialog.confirmLabel "Cancel order"
        , ConfirmDialog.cancelLabel "Keep order"
        , ConfirmDialog.confirmDisabled (not model.cancelAck)
        , ConfirmDialog.onConfirm CancelConfirmed
        , ConfirmDialog.onCancel CancelCancelled
        , ConfirmDialog.locale locale
        ]
        model.cancel


drawerRightView : Locale -> Model -> Overlay Msg
drawerRightView locale model =
    -- Always in the list, even before the first order is chosen: a closed drawer
    -- listens to the focus on the page, to give it back when it closes.
    Drawer.view RightDrawerMsg
        [ Drawer.title (Maybe.map (.id >> Types.orderIdText) model.drawerOrder |> Maybe.withDefault "")
        , Drawer.subtitle (Maybe.map (\order -> order.customer ++ " · " ++ order.email) model.drawerOrder |> Maybe.withDefault "")
        , Drawer.locale locale
        , Drawer.footer
            [ Button.view [ Button.onClick CloseRightDrawer ] "Close"
            , Button.view [ Button.primary, Button.icon Icon.edit, Button.onClick CloseRightDrawer ] "Edit"
            ]
        ]
        model.drawerRight
        (RemoteView.view
            [ RemoteView.locale locale
            , RemoteView.onRetry RetryDrawer
            , RemoteView.loadingLabel "Loading the order ..."
            , RemoteView.skeleton
                (Layout.stack [ Layout.gap 5 ]
                    [ Skeleton.line 35
                    , Skeleton.lines 4
                    , Skeleton.block 72
                    ]
                )
            ]
            model.drawerData
            (\loaded -> [ Layout.stack [ Layout.gap 5 ] [ orderDetails locale loaded, workflow model ] ])
        )


{-| The actions of the order. Pressing one replaces or disables the button that
has focus, and the drawer takes the focus itself.
-}
workflow : Model -> Html Msg
workflow model =
    Layout.stack [ Layout.gap 3 ]
        [ Text.overline "Workflow"
        , case model.step of
            0 ->
                Layout.row [ Layout.gap 2 ]
                    [ Button.view [ Button.id "wf-picking", Button.onClick AdvanceStep ] "Mark as picking" ]

            1 ->
                Layout.stack [ Layout.gap 2 ]
                    [ Text.caption "Picking started."
                    , Button.view [ Button.id "wf-packed", Button.onClick AdvanceStep ] "Mark as packed"
                    ]

            _ ->
                Text.caption "Packed."
        , Layout.row [ Layout.gap 2, Layout.wrap ]
            [ Button.view [ Button.id "wf-note", Button.disabled model.noteAdded, Button.onClick AddNote ] "Add note"
            , Button.view [ Button.id "wf-save", Button.onClick SaveNote ] "Save note (fails)"
            , Button.view [ Button.id "wf-cancel", Button.danger, Button.onClick AskCancel ] "Cancel order ..."
            ]
        ]


orderDetails : Locale -> Types.Order -> Html Msg
orderDetails locale order =
    let
        row label value =
            Layout.stack [ Layout.gap 1 ] [ Text.overline label, Text.text value ]
    in
    Layout.stack [ Layout.gap 5 ]
        [ Layout.row [ Layout.gap 3, Layout.alignCenter ]
            [ statusBadge order
            , Badge.view [ Badge.tone (Labels.priorityTone order.priority) ] ("Priority: " ++ Types.priorityLabel order.priority)
            ]
        , Layout.grid [ Layout.columns 2, Layout.gap 5 ]
            [ row "City" order.city
            , row "Owner" (order.owner |> Maybe.map Sample.ownerName |> Maybe.withDefault "Unassigned")
            , row "Created" (Format.date locale order.created)
            , row "Due" (Format.date locale order.due)
            , row "Lines" (String.fromInt order.lines)
            , row "Total" (Format.currency locale "$" 2 order.total)
            ]
        , Layout.divider
        , Layout.stack [ Layout.gap 1 ]
            [ Text.overline "Note"
            , Text.paragraph
                (if order.note == "" then
                    "No note."

                 else
                    order.note
                )
            ]
        ]


drawerLeftView : Locale -> Model -> Overlay Msg
drawerLeftView locale model =
    Drawer.view LeftDrawerMsg
        [ Drawer.left
        , Drawer.small
        , Drawer.static
        , Drawer.title "Filters"
        , Drawer.subtitle "Static: closes only with the buttons"
        , Drawer.locale locale
        , Drawer.footer
            [ Button.view [ Button.onClick CloseLeftDrawer ] "Cancel"
            , Button.view [ Button.primary, Button.onClick CloseLeftDrawer ] "Apply filters"
            ]
        ]
        model.drawerLeft
        [ Layout.stack [ Layout.gap 4 ]
            [ Checkbox.view [ Checkbox.label "Open orders only", Checkbox.checked model.onlyOpen, Checkbox.onCheck OnlyOpenChanged ]
            , Checkbox.view [ Checkbox.label "Urgent orders only", Checkbox.checked model.onlyUrgent, Checkbox.onCheck OnlyUrgentChanged ]
            , TextInput.view
                [ TextInput.id "drawer-city"
                , TextInput.label "City"
                , TextInput.value model.drawerCity
                , TextInput.onInput DrawerCityChanged
                , TextInput.clearable
                , TextInput.locale locale
                ]
            ]
        ]



-- PALETTE CONTENT


{-| "Go to order ORD-1001" asks the "server" for "ORD-1001": the words of the command
are declared on the item and taken off by `argument`.
-}
goToOrder : CommandPalette.Item Msg
goToOrder =
    command "Go to order ..." Icon.clipboard Nothing [] (Navigated "orders")
        |> CommandPalette.withCommand "go to order"


paletteArgument : CommandPalette.State -> String
paletteArgument palette =
    CommandPalette.argument [ goToOrder ] palette


paletteSections : Model -> List (CommandPalette.Section Msg)
paletteSections model =
    [ CommandPalette.section "Navigation"
        [ command "Go to orders" Icon.clipboard (Just (Shortcut.sequence [ Shortcut.char 'g', Shortcut.char 'o' ])) [ "list", "sales" ] (Navigated "orders")
        , goToOrder
        , command "Go to products" Icon.database (Just (Shortcut.sequence [ Shortcut.char 'g', Shortcut.char 'p' ])) [ "catalog", "items" ] (Navigated "products")
        , command "Go to reports" Icon.barChart Nothing [ "statistics" ] (Navigated "reports")
        , command "Go to settings" Icon.settings Nothing [ "configuration", "preferences" ] (Navigated "settings")
        ]
    , CommandPalette.section "Actions"
        [ command "New order" Icon.plus (Just (Shortcut.char 'n')) [ "create", "add", "register" ] OpenForm
        , command "Download export" Icon.download Nothing [ "csv", "excel" ] (PaletteRan "Download export")
        , command "Print overview" Icon.print (Just (Shortcut.mod (Shortcut.char 'p'))) [ "pdf" ] (PaletteRan "Print overview")
        , command "Show a notification" Icon.bell (Just (Shortcut.shift (Shortcut.char 't'))) [ "toast", "message" ] (PushToast Info)
        ]
    , CommandPalette.section "Help"
        [ command "Show keyboard shortcuts" Icon.keyboard (Just (Shortcut.char '?')) [ "shortcuts", "keys" ] OpenHelp
        , command "Open the documentation" Icon.externalLink Nothing [ "guide", "manual" ] (PaletteRan "Open the documentation")
        ]
    , CommandPalette.remote "Orders" (Remote.map (List.map orderItem) model.hits)
        |> CommandPalette.onRetry RetryHits
        |> CommandPalette.withEmptyText "No orders found"
    ]


command : String -> Icon -> Maybe Shortcut.Keys -> List String -> Msg -> CommandPalette.Item Msg
command label icon keys keywords msg =
    CommandPalette.item label msg
        |> CommandPalette.withIcon icon
        |> CommandPalette.withKeywords keywords
        |> (case keys of
                Just value ->
                    CommandPalette.withShortcut value

                Nothing ->
                    identity
           )


{-| The order opens in its drawer one update after the palette closes, as it would
after a route change, and without an opener: the drawer gives focus back to where
the palette was opened from. Many orders share a customer, so the order number is
the identity.
-}
orderItem : Types.Order -> CommandPalette.Item Msg
orderItem order =
    CommandPalette.item order.customer (RouteOpen order)
        |> CommandPalette.withIcon Icon.clipboard
        |> CommandPalette.withDescription (Types.orderIdText order.id ++ " · " ++ Types.orderStatusLabel order.status)
        |> CommandPalette.withId (Types.orderIdText order.id)



-- CODE SAMPLES


modalSizesCode : String
modalSizesCode =
    """-- model: sizeDialog : Modal.State   (Modal.init "size-dialog")

Modal.view SizeDialogMsg
    [ Modal.title "Order ORD-10001"
    , Modal.subtitle "Contoso Ltd"
    , Modal.large -- or Modal.small, Modal.medium, Modal.fullHeight
    , Modal.footer [ Button.view [ Button.primary, Button.onClick CloseDialog ] "Done" ]
    ]
    model.sizeDialog
    [ content ]

-- open it from a button with an id: focus returns there when the dialog closes
Button.view [ Button.id "open-dialog", Button.onClick OpenDialog ] "Open"

OpenDialog ->
    let
        ( dialog, cmd ) =
            Modal.open "open-dialog" model.sizeDialog
    in
    ( { model | sizeDialog = dialog }, Cmd.map SizeDialogMsg cmd )

-- the dialogs are overlays: the page is inert while any of them is open,
-- and there is no flag to compute
Overlay.host
    { attributes = []
    , page = [ viewPage model ]
    , overlays = [ sizeDialogView model ] -- Modal.view, Drawer.view, Toast.view ...
    }"""


modalFormCode : String
modalFormCode =
    """Modal.view FormMsg
    [ Modal.title "New order"
    , Modal.subtitle "Fields marked * are required"
    , Modal.static
    , Modal.onRequestClose RequestClose
    , Modal.footer [ cancelButton, saveButton ]
    ]
    model.formDialog
    [ orderForm model.form ]

-- the close button asks; the answer decides. The confirmation gets the close
-- button of the dialog as its opener, so focus returns there if the user cancels.
RequestClose ->
    if model.form /= emptyForm then
        let
            ( discard, cmd ) =
                ConfirmDialog.open (Modal.closeButtonId model.formDialog) model.discardDialog
        in
        ( { model | discardDialog = discard }, Cmd.map DiscardMsg cmd )

    else
        closeForm model

-- the shortcut that opens it
Shortcut.shortcut (Shortcut.char 'n') "Actions" "Create a new order" OpenForm

OpenForm ->
    let
        ( dialog, cmd ) =
            Modal.openWith { opener = "open-form", focus = [ "order-customer" ] } model.formDialog
    in
    ( { model | formDialog = dialog }, Cmd.map FormMsg cmd )"""


modalPopupsCode : String
modalPopupsCode =
    """-- A Menu, a Popover or a Select in the body of a dialog opens above the dialog.
-- Escape closes only the popup; a second Escape closes the dialog.
Modal.view MenuDialogMsg
    [ Modal.title "Dialog with a menu and a panel" ]
    model.menuDialog
    [ Menu.view MenuMsg [ Menu.label "Actions", Menu.items actions ] model.menu
    , Select.view CountryMsg
        [ Select.label "Country", Select.options countryOptions ]
        model.country
    ]"""


confirmTonesCode : String
confirmTonesCode =
    """ConfirmDialog.view DialogMsg
    [ ConfirmDialog.danger
    , ConfirmDialog.title "Delete the customer?"
    , ConfirmDialog.message "Contoso Ltd and everything that belongs to it is deleted for good."
    , ConfirmDialog.consequences [ "142 orders lose their customer" ]
    , ConfirmDialog.confirmLabel "Delete customer"
    , ConfirmDialog.typeToConfirm "DELETE"
    , ConfirmDialog.ignoreCase
    , ConfirmDialog.onConfirm Confirmed
    , ConfirmDialog.onCancel Cancelled
    ]
    model.dialog

-- ConfirmDialog.neutral (the default) and ConfirmDialog.warning are the other tones;
-- ConfirmDialog.body takes any HTML, ConfirmDialog.cancelLabel names the other button"""


confirmLifecycleCode : String
confirmLifecycleCode =
    """ConfirmDelete ->
    ( { model | dialog = ConfirmDialog.setBusy model.dialog }, deleteRequest order )

Deleted (Err problem) ->
    ( { model | dialog = ConfirmDialog.setFailed problem model.dialog }, Cmd.none )

Deleted (Ok _) ->
    let
        ( dialog, cmd ) =
            ConfirmDialog.close model.dialog
    in
    ( { model | dialog = dialog }, Cmd.map DialogMsg cmd )

CancelDelete ->
    -- not sent while the request runs; an event from the frame before can still
    -- slip through
    if ConfirmDialog.isBusy model.dialog then
        ( model, Cmd.none )

    else
        closeDialog model"""


drawerCode : String
drawerCode =
    """Drawer.view DrawerMsg
    [ Drawer.title "ORD-10001"
    , Drawer.subtitle "Contoso Ltd"
    , Drawer.large -- 720 px; Drawer.small is 360 px
    , Drawer.footer [ Button.view [ Button.onClick CloseDrawer ] "Close" ]
    ]
    model.drawer
    [ details ]

-- from the left, and only closed by its own buttons
Drawer.view FilterDrawerMsg [ Drawer.left, Drawer.small, Drawer.static, Drawer.title "Filters" ] model.filterDrawer [ filters ]

-- "Try again" makes way for the skeleton: nothing to call, the drawer takes
-- the focus by itself
RetryLoad ->
    ( { model | order = Remote.Loading }, loadOrder )

-- opened one update after a route change, from the palette: no opener needed
UrlChanged url ->
    Drawer.open "" model.drawer"""


toastCode : String
toastCode =
    """Toast.push
    [ Toast.success
    , Toast.title "Order saved"
    , Toast.message "Order ORD-10001 was updated."
    , Toast.action "Undo" UndoSave
    ]
    model.toasts
-- gives ( toasts, cmd ): store the toasts and map the cmd into your own Msg

-- once, among the overlays
Toast.view ToastMsg [] model.toasts"""


popoverCode : String
popoverCode =
    """Popover.view PopoverMsg
    [ Popover.label "Filter"
    , Popover.icon Icon.filter
    , Popover.title "Quick filter"
    , Popover.closeButton
    , Popover.initialFocus [ "filter-customer" ]
    ]
    model.popover
    [ TextInput.view [ TextInput.id "filter-customer", TextInput.label "Customer" ]
    , Button.view [ Button.primary, Button.onClick ApplyFilter ] "Apply"
    ]

-- an icon-only trigger needs a name
Popover.view HelpMsg [ Popover.icon Icon.help, Popover.ariaLabel "What is priority?" ] model.help [ explanation ]"""


tooltipAttrsCode : String
tooltipAttrsCode =
    """Button.iconOnly
    [ Button.htmlAttrs (Tooltip.attrs "Open search" |> Tooltip.withShortcut "Ctrl K") ]
    Icon.search
    "Search"

Button.view [ Button.htmlAttrs (Tooltip.attrsWith [ Tooltip.below ] "Shown below the button") ] "Below"

-- the shortcut follows the text after a middle dot, and is announced as aria-keyshortcuts"""


tooltipWrapCode : String
tooltipWrapCode =
    """Tooltip.wrap [] "You do not have permission to delete orders"
    (Button.view [ Button.danger, Button.disabled True ] "Delete")

Tooltip.wrap [ Tooltip.shortcut "Ctrl K" ] "Open the command palette" child

-- a badge or a truncated text can take focus too
Tooltip.wrap [ Tooltip.focusable ] "A long hint" (Badge.view [ Badge.tone Info ] "Hover over me")"""


contextMenuCode : String
contextMenuCode =
    """ContextMenu.area ContextMsg
    model.context
    { id = "order-" ++ order.id, target = order }
    [ row ]

ContextMenu.view ContextMsg
    [ ContextMenu.items itemsFor, ContextMenu.ariaLabel "Order actions" ]
    model.context

-- the same menu from the row's ⋯ button
OpenRowMenu order ->
    ContextMenu.openFor ("order-" ++ order.id ++ "-more") order model.context

itemsFor : Order -> List (Menu.Item Msg)
itemsFor order =
    [ Menu.heading order.id
    , Menu.item "Open in drawer" (OpenOrder order) |> Menu.withIcon Icon.externalLink |> Menu.withHint "Enter"
    , Menu.item "Send message" (SendMessage order) |> Menu.disabledItem
    , Menu.separator
    , Menu.item "Delete ..." (AskDelete order) |> Menu.withIcon Icon.trash |> Menu.danger
    ]"""


paletteCode : String
paletteCode =
    """CommandPalette.view PaletteMsg
    [ CommandPalette.sections
        [ CommandPalette.section "Navigation"
            [ CommandPalette.item "Go to orders" GoToOrders |> CommandPalette.withShortcut (Shortcut.sequence [ Shortcut.char 'g', Shortcut.char 'o' ]) ]
        , CommandPalette.remote "Orders" model.hits |> CommandPalette.onRetry RetryHits
        ]
    , CommandPalette.recent model.recentItems
    ]
    model.palette

-- the query lives in the state: watch it, wait a moment, ask the server
PaletteMsg inner ->
    let
        ( palette, cmd ) =
            CommandPalette.update inner model.palette
    in
    if CommandPalette.query palette /= CommandPalette.query model.palette then
        ( { model | palette = palette, hits = NotAsked, ticket = model.ticket + 1 }
        , Cmd.batch
            [ Cmd.map PaletteMsg cmd
            , Process.sleep 250 |> Task.perform (\\_ -> Debounced (model.ticket + 1))
            ]
        )

    else
        ( { model | palette = palette }, Cmd.map PaletteMsg cmd )"""


helpCode : String
helpCode =
    """ShortcutHelp.view HelpMsg [] shortcuts model.help

-- the same list that Shortcut.listen, Shortcut.subscription and Shortcut.update get
shortcuts : List (Shortcut Msg)
shortcuts =
    [ Shortcut.shortcut (Shortcut.mod (Shortcut.char 'k')) "Navigation" "Open the command palette" OpenPalette |> Shortcut.inInputs
    , Shortcut.shortcut (Shortcut.sequence [ Shortcut.char 'g', Shortcut.char 'o' ]) "Navigation" "Go to the orders" GoToOrders
    , Shortcut.shortcut (Shortcut.char '?') "Help" "Show keyboard shortcuts" OpenHelp
    ]"""
