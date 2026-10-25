port module Main exposing (main)

import Array
import Browser
import Browser.Navigation as Nav
import Dict exposing (Dict)
import File
import Html exposing (Html)
import Html.Attributes as Attr
import Http
import Json.Decode as Decode
import Json.Encode as Encode
import Klar
import Klar.Accordion as Accordion
import Klar.AiChat as AiChat
import Klar.AiReview as AiReview
import Klar.Alert as Alert
import Klar.AppShell as AppShell
import Klar.ApprovalFlow as ApprovalFlow
import Klar.AuditLog as AuditLog
import Klar.Autocomplete as Autocomplete
import Klar.Avatar as Avatar
import Klar.Badge as Badge
import Klar.Breadcrumbs as Breadcrumbs
import Klar.Budget as Budget
import Klar.BulkBar as BulkBar
import Klar.Button as Button
import Klar.ButtonGroup as ButtonGroup
import Klar.Calendar as Calendar
import Klar.Card as Card
import Klar.CardList as CardList
import Klar.Cascader as Cascader
import Klar.Chart as Chart
import Klar.Checkbox as Checkbox
import Klar.CheckboxGroup as CheckboxGroup
import Klar.CodeBlock as CodeBlock
import Klar.Color as Color
import Klar.CommandPalette as CommandPalette
import Klar.CommentThread as CommentThread
import Klar.Compare as Compare
import Klar.ConfirmDialog as ConfirmDialog
import Klar.ConflictResolver as ConflictResolver
import Klar.ContextMenu as ContextMenu
import Klar.Date as Date
import Klar.DatePicker as DatePicker
import Klar.DateRangePicker as DateRangePicker
import Klar.DateTimePicker as DateTimePicker
import Klar.DescriptionList as DescriptionList
import Klar.Diff as Diff
import Klar.Drawer as Drawer
import Klar.EmptyState as EmptyState
import Klar.ErrorState as ErrorState
import Klar.Field as Field
import Klar.FileDrop as FileDrop
import Klar.FilterBar as FilterBar
import Klar.Form as Form
import Klar.Form.Check as FormCheck
import Klar.Form.Layout as FormLayout
import Klar.Form.Spec as Spec
import Klar.Form.Submission as Submission
import Klar.Format as Format
import Klar.History as History
import Klar.Icon as Icon
import Klar.Icon.Library as IconLibrary
import Klar.Ids as Ids
import Klar.InlineEdit as InlineEdit
import Klar.JsonViewer as JsonViewer
import Klar.Kanban as Kanban
import Klar.Kbd as Kbd
import Klar.Layout as Layout
import Klar.LeaveGuard as LeaveGuard
import Klar.Link as Link
import Klar.ListItem as ListItem
import Klar.Locale as Locale
import Klar.Markdown as Markdown
import Klar.MarkdownEditor as MarkdownEditor
import Klar.MaskedInput as MaskedInput
import Klar.Menu as Menu
import Klar.Modal as Modal
import Klar.Money as Money
import Klar.MoneyInput as MoneyInput
import Klar.MultiSelect as MultiSelect
import Klar.NotificationCenter as NotificationCenter
import Klar.NumberInput as NumberInput
import Klar.Overlay as Overlay
import Klar.PageHeader as PageHeader
import Klar.Pagination as Pagination
import Klar.PasswordInput as PasswordInput
import Klar.PermissionMatrix as PermissionMatrix
import Klar.Picking as Picking
import Klar.Popover as Popover
import Klar.Progress as Progress
import Klar.QuantityInput as QuantityInput
import Klar.Radio as Radio
import Klar.Recurrence as Recurrence
import Klar.RecurrencePicker as RecurrencePicker
import Klar.Remote as Remote exposing (Remote(..))
import Klar.RemoteView as RemoteView
import Klar.Rule as Rule
import Klar.RuleBuilder as RuleBuilder
import Klar.SavedViews as SavedViews
import Klar.Search as Search
import Klar.SearchInput as SearchInput
import Klar.SegmentedControl as SegmentedControl
import Klar.Select as Select
import Klar.ServerList as ServerList
import Klar.Settings as Settings
import Klar.Shortcut as Shortcut
import Klar.ShortcutHelp as ShortcutHelp
import Klar.SideNav as SideNav
import Klar.Skeleton as Skeleton
import Klar.Slider as Slider
import Klar.Sortable as Sortable
import Klar.Spinner as Spinner
import Klar.SplitButton as SplitButton
import Klar.Splitter as Splitter
import Klar.Stat as Stat
import Klar.StateMachine as StateMachine
import Klar.StatusPage as StatusPage
import Klar.Stepper as Stepper
import Klar.Switch as Switch
import Klar.Table as Table
import Klar.Tabs as Tabs
import Klar.Tag as Tag
import Klar.TagInput as TagInput
import Klar.Text as Text
import Klar.TextArea as TextArea
import Klar.TextInput as TextInput
import Klar.Theme as Theme exposing (Tone(..))
import Klar.TimePicker as TimePicker
import Klar.Timeline as Timeline
import Klar.Toast as Toast
import Klar.ToggleGroup as ToggleGroup
import Klar.Toolbar as Toolbar
import Klar.Tooltip as Tooltip
import Klar.Transfer as Transfer
import Klar.Tree as Tree
import Klar.TreeSelect as TreeSelect
import Klar.UploadQueue as UploadQueue
import Klar.Validate as Validate
import Klar.VirtualList as VirtualList
import Klar.WorkQueue as WorkQueue
import Klar.Workflow as Workflow
import Klar.Workflow.Codec as WorkflowCodec
import Klar.Workflow.Engine as Engine
import Klar.WorkflowBuilder as WorkflowBuilder
import Klar.WorkflowNode as WorkflowNode
import Klar.WorkflowRun as WorkflowRun
import Task
import Time
import Url exposing (Url)


port outgoing : Encode.Value -> Cmd msg


port incoming : (Decode.Value -> msg) -> Sub msg


type Page
    = Page String


type Choice
    = Choice String


type RecordId
    = RecordId String


choiceKey (Choice value) =
    value


recordKey (RecordId value) =
    value


choiceIds =
    Ids.make { toKey = choiceKey, fromKey = Choice >> Just }


recordIds =
    Ids.make { toKey = recordKey, fromKey = RecordId >> Just }


pageIds =
    Ids.list (\(Page key) -> key) (List.map Page pages)


pages =
    [ "Foundations", "Actions", "Feedback", "Inputs", "Choosing", "Dates", "Data", "Content", "Overlays", "Structure", "Dashboard", "Icons", "Collaboration", "Access", "AI", "Files", "Rules", "Forms", "Processes" ]


type alias Order =
    { id : RecordId, customer : String, total : Int }


type alias Model =
    { page : Page
    , shell : AppShell.State Page
    , settings : Settings.Settings
    , orders : Remote (List Order)
    , toasts : Toast.State Msg
    , text : String
    , checked : Bool
    , choice : String
    , choices : List Choice
    , slider : Float
    , pageNumber : Int
    , step : Int
    , sortOrder : List Choice
    , history : History.History String String
    , shortcut : Shortcut.State
    , response : String
    , epoch : Int
    , scenario : String
    , tagVisible : Bool
    , alertVisible : Bool
    , splitButton : SplitButton.State
    , menu : Menu.State
    , numberInput : NumberInput.State
    , passwordInput : PasswordInput.State
    , searchInput : SearchInput.State
    , tagInput : TagInput.State
    , fileDrop : FileDrop.State
    , inlineEdit : InlineEdit.State
    , maskedInput : MaskedInput.State
    , moneyInput : MoneyInput.State
    , quantityInput : QuantityInput.State
    , select : Select.State Choice
    , multiSelect : MultiSelect.State Choice
    , autocomplete : Autocomplete.State Choice
    , treeSelect : TreeSelect.State TreeSelect.Single Choice
    , cascader : Cascader.State Choice
    , transfer : Transfer.State Choice
    , datePicker : DatePicker.State
    , dateRangePicker : DateRangePicker.State
    , timePicker : TimePicker.State
    , dateTimePicker : DateTimePicker.State
    , calendar : Calendar.State
    , recurrencePicker : RecurrencePicker.State
    , tree : Tree.State Choice
    , virtualList : VirtualList.State
    , table : Table.State RecordId
    , jsonViewer : JsonViewer.State
    , markdownEditor : MarkdownEditor.State
    , diff : Diff.State
    , modal : Modal.State
    , drawer : Drawer.State
    , confirmDialog : ConfirmDialog.State
    , popover : Popover.State
    , contextMenu : ContextMenu.State Choice
    , commandPalette : CommandPalette.State
    , shortcutHelp : ShortcutHelp.State
    , breadcrumbs : Breadcrumbs.State
    , tabs : Tabs.State Choice
    , accordion : Accordion.State Choice
    , sortable : Sortable.State Choice
    , splitter : Splitter.State
    , budget : Budget.State
    , workQueue : WorkQueue.State
    , kanban : Kanban.State
    , conflictResolver : ConflictResolver.State
    , commentThread : CommentThread.State
    , permissionMatrix : PermissionMatrix.State
    , aiReview : AiReview.State
    , aiChat : AiChat.State
    , uploadQueue : UploadQueue.State
    , ruleBuilder : RuleBuilder.State
    , filterBar : FilterBar.State
    , savedViews : SavedViews.State
    , board : List (Kanban.Column Choice BoardCard)
    , notifications : List Notice
    , audit : Remote (List AuditEntry)
    , comments : List (CommentThread.Comment Choice)
    , commentSending : Bool
    , commentError : Maybe String
    , commentPending : Maybe (CommentThread.Submission Choice)
    , grants : List ( String, String )
    , approval : ApprovalFlow.Decision
    , reviewSaving : Bool
    , reviewError : Maybe String
    , chatMessages : List ChatEntry
    , chatStatus : AiChat.Status
    , chatTicket : Int
    , chatPending : Maybe AiChat.Submission
    , chatPrompt : String
    , uploads : List UploadEntry
    , nextUpload : Int
    , serverList : ServerList.State RecordId Order
    , serverPending : Dict String ServerList.Request
    , serverCounter : Int
    , form : Form.State ()
    , formTicket : Maybe Submission.Ticket
    , email : String
    , guard : LeaveGuard.Guard Choice Choice
    , workflow : Workflow.Definition Choice
    , selectedNode : Maybe Choice
    , run : Maybe (Engine.Run Choice)
    , machine : StateMachine.Machine Choice
    }


type Msg
    = ShellMsg AppShell.Msg
    | ToastMsg Toast.Msg
    | ShortcutMsg Shortcut.Msg
    | GotZone Time.Zone
    | GotNow Time.Posix
    | Received Decode.Value
    | Reload
    | LoadScenario String
    | SetText String
    | SetChecked Bool
    | SetChoice String
    | SetChoices (List Choice)
    | SetSlider Float
    | SetPageNumber Int
    | SetStep Int
    | SetHistory String
    | Undo
    | Redo
    | Notify String
    | SaveSnapshot
    | SetTheme Theme.Theme
    | SetDark Bool
    | SetNorwegian Bool
    | SetDensity Theme.Density
    | OpenModal
    | OpenDrawer
    | OpenConfirm
    | ConfirmAction
    | OpenPalette
    | OpenHelp
    | NoOp
    | DismissTag
    | RestoreTag
    | DismissAlert
    | RestoreAlert
    | ResetRemote
    | RetryStat
    | RetryRemoteView
    | RetryCards
    | RetryWorkQueue
    | SplitButtonMsg SplitButton.Msg
    | MenuMsg Menu.Msg
    | NumberInputMsg NumberInput.Msg
    | PasswordInputMsg PasswordInput.Msg
    | SearchInputMsg SearchInput.Msg
    | TagInputMsg TagInput.Msg
    | FileDropMsg FileDrop.Msg
    | InlineEditMsg InlineEdit.Msg
    | MaskedInputMsg MaskedInput.Msg
    | MoneyInputMsg MoneyInput.Msg
    | QuantityInputMsg QuantityInput.Msg
    | SelectMsg (Select.Msg Choice)
    | MultiSelectMsg (MultiSelect.Msg Choice)
    | AutocompleteMsg (Autocomplete.Msg Choice)
    | TreeSelectMsg (TreeSelect.Msg Choice)
    | CascaderMsg (Cascader.Msg Choice)
    | TransferMsg (Transfer.Msg Choice)
    | DatePickerMsg DatePicker.Msg
    | DateRangePickerMsg DateRangePicker.Msg
    | TimePickerMsg TimePicker.Msg
    | DateTimePickerMsg DateTimePicker.Msg
    | CalendarMsg Calendar.Msg
    | RecurrencePickerMsg RecurrencePicker.Msg
    | TreeMsg Tree.Msg
    | VirtualListMsg VirtualList.Msg
    | TableMsg Table.Msg
    | JsonViewerMsg JsonViewer.Msg
    | MarkdownEditorMsg MarkdownEditor.Msg
    | DiffMsg Diff.Msg
    | ModalMsg Modal.Msg
    | DrawerMsg Drawer.Msg
    | ConfirmDialogMsg ConfirmDialog.Msg
    | PopoverMsg Popover.Msg
    | ContextMenuMsg (ContextMenu.Msg Choice)
    | CommandPaletteMsg CommandPalette.Msg
    | ShortcutHelpMsg ShortcutHelp.Msg
    | BreadcrumbsMsg Breadcrumbs.Msg
    | TabsMsg (Tabs.Msg Choice)
    | AccordionMsg (Accordion.Msg Choice)
    | SortableMsg Sortable.Msg
    | SplitterMsg Splitter.Msg
    | BudgetMsg Budget.Msg
    | WorkQueueMsg WorkQueue.Msg
    | KanbanMsg Kanban.Msg
    | ConflictResolverMsg ConflictResolver.Msg
    | CommentThreadMsg CommentThread.Msg
    | PermissionMatrixMsg PermissionMatrix.Msg
    | AiReviewMsg AiReview.Msg
    | AiChatMsg AiChat.Msg
    | UploadQueueMsg UploadQueue.Msg
    | RuleBuilderMsg RuleBuilder.Msg
    | FilterBarMsg FilterBar.Msg
    | SavedViewsMsg SavedViews.Msg
    | SaveBudget
    | SetRead Bool Choice
    | DismissNotification Choice
    | ReadAll
    | LoadAudit
    | ApplyMerge (List ( Choice, Maybe String ))
    | PostComment (CommentThread.Submission Choice)
    | SetPermissions (List (PermissionMatrix.Change String String))
    | DecideApproval Bool
    | SubmitReview (List (AiReview.Decision Choice))
    | SendChat AiChat.Submission
    | StopChat
    | RetryChat
    | AddUploads (List File.File)
    | StartUpload Choice
    | StartUploads (List Choice)
    | CancelUpload Choice
    | RemoveUpload Choice
    | Uploaded Choice Int (Result Http.Error String)
    | UploadProgress Choice Int Http.Progress
    | ServerMsg (ServerList.Msg Order)
    | InitServer
    | FormMsg Form.Msg
    | SubmitForm
    | ResetForm
    | SetEmail String
    | GuardMsg LeaveGuard.Msg
    | DirtyGuard Bool
    | TryLeave
    | SelectNode Choice
    | AddWorkflowNode Workflow.Kind
    | ChangeWorkflow (Workflow.Definition Choice)
    | StartWorkflow
    | CompleteNode
    | PauseRun
    | ResumeRun
    | CancelRun
    | SaveWorkflow
    | TransitionState String


main =
    Browser.application { init = init, update = update, view = view, subscriptions = subscriptions, onUrlRequest = AppShell.onUrlRequest ShellMsg, onUrlChange = AppShell.onUrlChange ShellMsg }


init : () -> Url -> Nav.Key -> ( Model, Cmd Msg )
init _ url key =
    ( { page = pageFromUrl url
      , shell = AppShell.init { id = "kitchen-shell", key = key, url = url } |> AppShell.setPage navigation (pageFromUrl url)
      , settings = Settings.default
      , orders = Loading
      , toasts = Toast.init "toasts"
      , text = "Aurora Logistics"
      , checked = False
      , choice = "table"
      , choices = []
      , slider = 65
      , pageNumber = 1
      , step = 0
      , sortOrder = [ Choice "Oslo", Choice "Bergen", Choice "Trondheim" ]
      , history = History.init "Try editing, undoing and redoing."
      , shortcut = Shortcut.init
      , response = "Connecting to Go / SQLite…"
      , epoch = 0
      , scenario = "data"
      , tagVisible = True
      , alertVisible = True
      , splitButton = SplitButton.init "split"
      , menu = Menu.init "menu"
      , numberInput = NumberInput.init "demo-numberinput"
      , passwordInput = PasswordInput.init "demo-passwordinput"
      , searchInput = SearchInput.init "demo-searchinput"
      , tagInput = TagInput.init "demo-taginput"
      , fileDrop = FileDrop.init "demo-filedrop"
      , inlineEdit = InlineEdit.init "inline" "Warehouse label"
      , maskedInput = MaskedInput.init "masked" MaskedInput.phone
      , moneyInput = MoneyInput.init "money" Money.nok
      , quantityInput = QuantityInput.init "quantity"
      , select = Select.init "select"
      , multiSelect = MultiSelect.init "multiselect"
      , autocomplete = Autocomplete.init "autocomplete"
      , treeSelect = TreeSelect.init "tree-select" TreeSelect.single
      , cascader = Cascader.init "cascader"
      , transfer = Transfer.init "transfer"
      , datePicker = DatePicker.init "demo-datepicker"
      , dateRangePicker = DateRangePicker.init "demo-daterangepicker"
      , timePicker = TimePicker.init "demo-timepicker"
      , dateTimePicker = DateTimePicker.init "demo-datetimepicker"
      , calendar = Calendar.init "calendar" |> Calendar.showDate sampleDate
      , recurrencePicker = RecurrencePicker.init "recurrence" sampleDate
      , tree = Tree.init "tree"
      , virtualList = VirtualList.init "virtual"
      , table = Table.init "orders"
      , jsonViewer = JsonViewer.init "json"
      , markdownEditor = MarkdownEditor.init "markdown-editor" |> MarkdownEditor.setValue "## Dispatch notes\n\n**Ready** for review."
      , diff = Diff.init "diff"
      , modal = Modal.init "modal"
      , drawer = Drawer.init "drawer"
      , confirmDialog = ConfirmDialog.init "confirm"
      , popover = Popover.init "popover"
      , contextMenu = ContextMenu.init "context"
      , commandPalette = CommandPalette.init "palette"
      , shortcutHelp = ShortcutHelp.init "shortcut-help"
      , breadcrumbs = Breadcrumbs.init "crumbs"
      , tabs = Tabs.init "tabs" (Choice "details")
      , accordion = Accordion.init "accordion"
      , sortable = Sortable.init "sortable"
      , splitter = Splitter.init "splitter" [ Splitter.percent 35, Splitter.percent 65 ]
      , budget = Budget.init "budget" Money.nok |> Budget.setColumns [ Budget.textColumn "item" "Item", Budget.numberColumn "quantity" "Quantity", Budget.moneyColumn "price" "Price" ] |> Budget.setFormula (Budget.multiply "quantity" (Budget.amount "price")) |> Budget.setRows [ Budget.row [ ( "item", "Packaging" ), ( "quantity", "4" ), ( "price", "125.50" ) ] ]
      , workQueue = WorkQueue.init "work-queue"
      , kanban = Kanban.init "kanban"
      , conflictResolver = ConflictResolver.init "conflicts"
      , commentThread = CommentThread.init "comments"
      , permissionMatrix = PermissionMatrix.init "permissions"
      , aiReview = AiReview.init "ai-review"
      , aiChat = AiChat.init "ai-chat"
      , uploadQueue = UploadQueue.init "upload-queue"
      , ruleBuilder = RuleBuilder.init "rules" |> RuleBuilder.setRule (Rule.allOf [ Rule.when "total" Rule.GreaterOrEqual [ "50000" ] ])
      , filterBar = FilterBar.init "filter-bar"
      , savedViews = SavedViews.init "saved-views" |> SavedViews.setViews [ SavedViews.savedView "Large orders" (Rule.allOf [ Rule.when "total" Rule.GreaterOrEqual [ "50000" ] ]) ]
      , board = [ Kanban.column (Choice "todo") "To do" [ { id = Choice "pick", name = "Pick order", description = "Aurora Logistics" } ], Kanban.column (Choice "doing") "In progress" [ { id = Choice "pack", name = "Pack order", description = "Fjord Foods" } ], Kanban.column (Choice "done") "Done" [] ]
      , notifications = [ { id = Choice "n1", title = "Order ready", body = "Aurora Logistics is ready for dispatch.", unread = True }, { id = Choice "n2", title = "Stock updated", body = "The Oslo warehouse reported new stock.", unread = False } ]
      , audit = NotAsked
      , comments = [ CommentThread.comment { id = Choice "welcome", author = "Alex Morgan", body = "Please check the **dispatch address** before approval.", at = Time.millisToPosix 0 } ]
      , commentSending = False
      , commentError = Nothing
      , commentPending = Nothing
      , grants = [ ( "admin", "read" ), ( "admin", "write" ), ( "viewer", "read" ) ]
      , approval = ApprovalFlow.pending
      , reviewSaving = False
      , reviewError = Nothing
      , chatMessages = []
      , chatStatus = AiChat.Idle
      , chatTicket = 0
      , chatPending = Nothing
      , chatPrompt = ""
      , uploads = []
      , nextUpload = 0
      , serverList = (ServerList.init "server-orders" []).state
      , serverPending = Dict.empty
      , serverCounter = 0
      , form = Form.init customerForm
      , formTicket = Nothing
      , email = ""
      , guard = LeaveGuard.init "leave-guard"
      , workflow = initialWorkflow
      , selectedNode = Nothing
      , run = Nothing
      , machine = initialMachine
      }
    , Cmd.batch [ request "orders:0" "GET" "/api/orders" Encode.null, request "restore" "GET" "/api/documents/playground" Encode.null, Task.perform GotZone Time.here, Task.perform GotNow Time.now, Task.perform (\_ -> InitServer) (Task.succeed ()), request "chat-history" "GET" "/api/chat" Encode.null, request "comments-history" "GET" "/api/comments" Encode.null, Cmd.batch (List.map (\documentKey -> request ("restore-" ++ documentKey) "GET" ("/api/documents/" ++ documentKey) Encode.null) [ "views", "server-views", "notifications", "budget", "board", "permissions", "customer", "workflow" ]), request "restore-inline" "GET" "/api/documents/inline" Encode.null, request "audit" "GET" "/api/events" Encode.null ]
    )


subscriptions model =
    Sub.batch ([ incoming Received, Shortcut.subscription ShortcutMsg shortcuts model.shortcut ] ++ List.map (\u -> Http.track ("upload-" ++ choiceKey u.id) (UploadProgress u.id u.ticket)) model.uploads)


shortcuts =
    [ Shortcut.shortcut (Shortcut.mod (Shortcut.char 'k')) "Navigation" "Open command palette" OpenPalette |> Shortcut.inInputs, Shortcut.shortcut (Shortcut.char '?') "Help" "Keyboard help" OpenHelp ]


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        ShellMsg inner ->
            let
                ( shell, cmd, address ) =
                    AppShell.update inner model.shell

                page =
                    Maybe.map pageFromUrl address |> Maybe.withDefault model.page
            in
            ( { model | shell = AppShell.setPage navigation page shell, page = page }, Cmd.map ShellMsg cmd )

        ToastMsg inner ->
            let
                ( next, cmd ) =
                    Toast.update inner model.toasts
            in
            ( { model | toasts = next }, Cmd.map ToastMsg cmd )

        ShortcutMsg inner ->
            let
                ( next, action ) =
                    Shortcut.update shortcuts inner model.shortcut

                updated =
                    { model | shortcut = next }
            in
            Maybe.map (\a -> update a updated) action |> Maybe.withDefault ( updated, Cmd.none )

        GotZone zone ->
            let
                settings =
                    Settings.withZone zone model.settings
            in
            ( { model | settings = settings, calendar = setCalendarToday settings model.calendar }, Cmd.none )

        GotNow now ->
            let
                settings =
                    Settings.withNow now model.settings
            in
            ( { model | settings = settings, calendar = setCalendarToday settings model.calendar }, Cmd.none )

        Reload ->
            update (LoadScenario model.scenario) model

        RetryStat ->
            retryRegion "orders-stat" model

        RetryRemoteView ->
            retryRegion "remote-view" model

        RetryCards ->
            retryRegion "card-list" model

        RetryWorkQueue ->
            retryRegion "work-queue" model

        ResetRemote ->
            ( { model | orders = NotAsked, epoch = model.epoch + 1 }, Cmd.none )

        DismissTag ->
            ( { model | tagVisible = False }, Klar.focus "restore-tag" NoOp )

        RestoreTag ->
            ( { model | tagVisible = True }, Cmd.none )

        DismissAlert ->
            ( { model | alertVisible = False }, Klar.focus "restore-alert" NoOp )

        RestoreAlert ->
            ( { model | alertVisible = True }, Cmd.none )

        LoadScenario scenario ->
            let
                ticket =
                    model.epoch + 1
            in
            ( { model | orders = Remote.refresh model.orders, epoch = ticket, scenario = scenario }, request ("orders:" ++ String.fromInt ticket) "GET" ("/api/orders?scenario=" ++ scenario) Encode.null )

        Received value ->
            receive value model

        SetText value ->
            ( { model | text = value }, Cmd.none )

        SetChecked value ->
            ( { model | checked = value }, Cmd.none )

        SetChoice value ->
            ( { model | choice = value }, Cmd.none )

        SetChoices value ->
            ( { model | choices = value }, Cmd.none )

        SetSlider value ->
            ( { model | slider = value }, Cmd.none )

        SetPageNumber value ->
            ( { model | pageNumber = value }, Cmd.none )

        SetStep value ->
            ( { model | step = value }, Cmd.none )

        SetHistory value ->
            ( { model | history = History.record [ History.label "Edit note" ] value model.history }, Cmd.none )

        Undo ->
            ( { model | history = History.undo model.history }, Cmd.none )

        Redo ->
            ( { model | history = History.redo model.history }, Cmd.none )

        SetTheme value ->
            ( { model | settings = Settings.withTheme value model.settings }, Cmd.none )

        SetDark value ->
            ( { model
                | settings =
                    Settings.withMode
                        (if value then
                            Theme.Dark

                         else
                            Theme.Light
                        )
                        model.settings
              }
            , Cmd.none
            )

        SetNorwegian value ->
            ( { model
                | settings =
                    Settings.withLocale
                        (if value then
                            Locale.nb

                         else
                            Locale.en
                        )
                        model.settings
              }
            , Cmd.none
            )

        SetDensity value ->
            ( { model | settings = Settings.withDensity value model.settings }, Cmd.none )

        SaveSnapshot ->
            ( model, request "save" "PUT" "/api/documents/playground" (snapshot model) )

        Notify text ->
            let
                ( next, cmd ) =
                    Toast.push [ Toast.message text, Toast.tone Success ] model.toasts
            in
            ( { model | toasts = next, response = text }, Cmd.map ToastMsg cmd )

        OpenModal ->
            let
                ( next, cmd ) =
                    Modal.open "open-modal" model.modal
            in
            ( { model | modal = next }, Cmd.map ModalMsg cmd )

        OpenDrawer ->
            let
                ( next, cmd ) =
                    Drawer.open "open-drawer" model.drawer
            in
            ( { model | drawer = next }, Cmd.map DrawerMsg cmd )

        OpenConfirm ->
            let
                ( next, cmd ) =
                    ConfirmDialog.open "open-confirm" model.confirmDialog
            in
            ( { model | confirmDialog = next }, Cmd.map ConfirmDialogMsg cmd )

        OpenPalette ->
            let
                ( next, cmd ) =
                    CommandPalette.open "open-palette" model.commandPalette
            in
            ( { model | commandPalette = next }, Cmd.map CommandPaletteMsg cmd )

        OpenHelp ->
            let
                ( next, cmd ) =
                    ShortcutHelp.open "open-help" model.shortcutHelp
            in
            ( { model | shortcutHelp = next }, Cmd.map ShortcutHelpMsg cmd )

        ConfirmAction ->
            ( { model | confirmDialog = ConfirmDialog.setBusy model.confirmDialog }, request "confirm" "POST" "/api/events" (Encode.object [ ( "action", Encode.string "Confirmed sample action" ) ]) )

        SplitButtonMsg inner ->
            let
                ( next, cmd ) =
                    SplitButton.update inner model.splitButton
            in
            ( { model | splitButton = next }, Cmd.map SplitButtonMsg cmd )

        MenuMsg inner ->
            let
                ( next, cmd ) =
                    Menu.update inner model.menu
            in
            ( { model | menu = next }, Cmd.map MenuMsg cmd )

        NumberInputMsg inner ->
            let
                ( next, cmd ) =
                    NumberInput.update inner model.numberInput
            in
            ( { model | numberInput = next }, Cmd.map NumberInputMsg cmd )

        PasswordInputMsg inner ->
            let
                ( next, cmd ) =
                    PasswordInput.update inner model.passwordInput
            in
            ( { model | passwordInput = next }, Cmd.map PasswordInputMsg cmd )

        SearchInputMsg inner ->
            let
                ( next, cmd ) =
                    SearchInput.update inner model.searchInput
            in
            ( { model | searchInput = next }, Cmd.map SearchInputMsg cmd )

        TagInputMsg inner ->
            let
                ( next, cmd ) =
                    TagInput.update inner model.tagInput
            in
            ( { model | tagInput = next }, Cmd.map TagInputMsg cmd )

        FileDropMsg inner ->
            let
                ( next, cmd ) =
                    FileDrop.update inner model.fileDrop
            in
            ( { model | fileDrop = next }, Cmd.map FileDropMsg cmd )

        InlineEditMsg inner ->
            let
                ( next, cmd ) =
                    InlineEdit.update inner model.inlineEdit
            in
            ( { model | inlineEdit = next }
            , Cmd.batch
                [ Cmd.map InlineEditMsg cmd
                , case InlineEdit.pending next of
                    Just value ->
                        request "inline" "PUT" "/api/documents/inline" (Encode.object [ ( "text", Encode.string value ) ])

                    Nothing ->
                        Cmd.none
                ]
            )

        MaskedInputMsg inner ->
            let
                ( next, cmd ) =
                    MaskedInput.update inner model.maskedInput
            in
            ( { model | maskedInput = next }, Cmd.map MaskedInputMsg cmd )

        MoneyInputMsg inner ->
            let
                ( next, cmd ) =
                    MoneyInput.update inner model.moneyInput
            in
            ( { model | moneyInput = next }, Cmd.map MoneyInputMsg cmd )

        QuantityInputMsg inner ->
            let
                ( next, cmd ) =
                    QuantityInput.update inner model.quantityInput
            in
            ( { model | quantityInput = next }, Cmd.map QuantityInputMsg cmd )

        SelectMsg inner ->
            let
                ( next, cmd ) =
                    Select.update inner model.select
            in
            ( { model | select = next }, Cmd.map SelectMsg cmd )

        MultiSelectMsg inner ->
            let
                ( next, cmd ) =
                    MultiSelect.update inner model.multiSelect
            in
            ( { model | multiSelect = next }, Cmd.map MultiSelectMsg cmd )

        AutocompleteMsg inner ->
            let
                ( next, cmd ) =
                    Autocomplete.update inner model.autocomplete
            in
            ( { model | autocomplete = next }, Cmd.map AutocompleteMsg cmd )

        TreeSelectMsg inner ->
            let
                ( next, cmd ) =
                    TreeSelect.update inner model.treeSelect
            in
            ( { model | treeSelect = next }, Cmd.map TreeSelectMsg cmd )

        CascaderMsg inner ->
            let
                ( next, cmd ) =
                    Cascader.update inner model.cascader
            in
            ( { model | cascader = next }, Cmd.map CascaderMsg cmd )

        TransferMsg inner ->
            let
                ( next, cmd ) =
                    Transfer.update inner model.transfer
            in
            ( { model | transfer = next }, Cmd.map TransferMsg cmd )

        DatePickerMsg inner ->
            let
                ( next, cmd ) =
                    DatePicker.update inner model.datePicker
            in
            ( { model | datePicker = next }, Cmd.map DatePickerMsg cmd )

        DateRangePickerMsg inner ->
            let
                ( next, cmd ) =
                    DateRangePicker.update inner model.dateRangePicker
            in
            ( { model | dateRangePicker = next }, Cmd.map DateRangePickerMsg cmd )

        TimePickerMsg inner ->
            let
                ( next, cmd ) =
                    TimePicker.update inner model.timePicker
            in
            ( { model | timePicker = next }, Cmd.map TimePickerMsg cmd )

        DateTimePickerMsg inner ->
            let
                ( next, cmd ) =
                    DateTimePicker.update inner model.dateTimePicker
            in
            ( { model | dateTimePicker = next }, Cmd.map DateTimePickerMsg cmd )

        CalendarMsg inner ->
            let
                ( next, cmd ) =
                    Calendar.update inner model.calendar
            in
            ( { model | calendar = next }, Cmd.map CalendarMsg cmd )

        RecurrencePickerMsg inner ->
            let
                ( next, cmd ) =
                    RecurrencePicker.update inner model.recurrencePicker
            in
            ( { model | recurrencePicker = next }, Cmd.map RecurrencePickerMsg cmd )

        TreeMsg inner ->
            let
                ( next, cmd ) =
                    Tree.update inner model.tree
            in
            ( { model | tree = next }, Cmd.map TreeMsg cmd )

        VirtualListMsg inner ->
            let
                ( next, cmd ) =
                    VirtualList.update inner model.virtualList
            in
            ( { model | virtualList = next }, Cmd.map VirtualListMsg cmd )

        TableMsg inner ->
            let
                ( next, cmd ) =
                    Table.update inner model.table
            in
            ( { model | table = next }, Cmd.map TableMsg cmd )

        JsonViewerMsg inner ->
            let
                ( next, cmd ) =
                    JsonViewer.update inner model.jsonViewer
            in
            ( { model | jsonViewer = next }, Cmd.map JsonViewerMsg cmd )

        MarkdownEditorMsg inner ->
            let
                ( next, cmd ) =
                    MarkdownEditor.update inner model.markdownEditor
            in
            ( { model | markdownEditor = next }, Cmd.map MarkdownEditorMsg cmd )

        DiffMsg inner ->
            let
                ( next, cmd ) =
                    Diff.update inner model.diff
            in
            ( { model | diff = next }, Cmd.map DiffMsg cmd )

        ModalMsg inner ->
            let
                ( next, cmd ) =
                    Modal.update inner model.modal
            in
            ( { model | modal = next }, Cmd.map ModalMsg cmd )

        DrawerMsg inner ->
            let
                ( next, cmd ) =
                    Drawer.update inner model.drawer
            in
            ( { model | drawer = next }, Cmd.map DrawerMsg cmd )

        ConfirmDialogMsg inner ->
            let
                ( next, cmd ) =
                    ConfirmDialog.update inner model.confirmDialog
            in
            ( { model | confirmDialog = next }, Cmd.map ConfirmDialogMsg cmd )

        PopoverMsg inner ->
            let
                ( next, cmd ) =
                    Popover.update inner model.popover
            in
            ( { model | popover = next }, Cmd.map PopoverMsg cmd )

        ContextMenuMsg inner ->
            let
                ( next, cmd ) =
                    ContextMenu.update inner model.contextMenu
            in
            ( { model | contextMenu = next }, Cmd.map ContextMenuMsg cmd )

        CommandPaletteMsg inner ->
            let
                ( next, cmd ) =
                    CommandPalette.update inner model.commandPalette
            in
            ( { model | commandPalette = next }, Cmd.map CommandPaletteMsg cmd )

        ShortcutHelpMsg inner ->
            let
                ( next, cmd ) =
                    ShortcutHelp.update inner model.shortcutHelp
            in
            ( { model | shortcutHelp = next }, Cmd.map ShortcutHelpMsg cmd )

        BreadcrumbsMsg inner ->
            let
                ( next, cmd ) =
                    Breadcrumbs.update inner model.breadcrumbs
            in
            ( { model | breadcrumbs = next }, Cmd.map BreadcrumbsMsg cmd )

        TabsMsg inner ->
            let
                ( next, cmd ) =
                    Tabs.update inner model.tabs
            in
            ( { model | tabs = next }, Cmd.map TabsMsg cmd )

        AccordionMsg inner ->
            let
                ( next, cmd ) =
                    Accordion.update inner model.accordion
            in
            ( { model | accordion = next }, Cmd.map AccordionMsg cmd )

        SortableMsg inner ->
            let
                ( next, cmd ) =
                    Sortable.update inner model.sortable
            in
            ( { model | sortable = next, sortOrder = Sortable.reorder choiceIds identity model.sortable next model.sortOrder }, Cmd.map SortableMsg cmd )

        SplitterMsg inner ->
            let
                ( next, cmd ) =
                    Splitter.update inner model.splitter
            in
            ( { model | splitter = next }, Cmd.map SplitterMsg cmd )

        BudgetMsg inner ->
            let
                ( next, cmd ) =
                    Budget.update inner model.budget
            in
            ( { model | budget = next }, Cmd.map BudgetMsg cmd )

        WorkQueueMsg inner ->
            let
                ( next, cmd ) =
                    WorkQueue.update inner model.workQueue
            in
            ( { model | workQueue = next }, Cmd.map WorkQueueMsg cmd )

        KanbanMsg inner ->
            let
                ( next, cmd ) =
                    Kanban.update inner model.kanban

                moved =
                    Kanban.move choiceIds choiceIds model.kanban next

                result =
                    Maybe.map (\move -> Kanban.applyMove choiceIds choiceIds .id move model.board) moved
            in
            case result of
                Just (Ok board) ->
                    ( { model | kanban = next, board = board }, Cmd.batch [ Cmd.map KanbanMsg cmd, request "board" "PUT" "/api/documents/board" (Encode.list encodeColumn board) ] )

                Just (Err problem) ->
                    update (Notify (Kanban.problemText (Settings.locale model.settings) problem)) { model | kanban = next }

                Nothing ->
                    ( { model | kanban = next }, Cmd.map KanbanMsg cmd )

        ConflictResolverMsg inner ->
            let
                ( next, cmd ) =
                    ConflictResolver.update inner model.conflictResolver
            in
            ( { model | conflictResolver = next }, Cmd.map ConflictResolverMsg cmd )

        CommentThreadMsg inner ->
            let
                ( next, cmd ) =
                    CommentThread.update inner model.commentThread
            in
            ( { model | commentThread = next }, Cmd.map CommentThreadMsg cmd )

        PermissionMatrixMsg inner ->
            let
                ( next, cmd ) =
                    PermissionMatrix.update inner model.permissionMatrix
            in
            ( { model | permissionMatrix = next }, Cmd.map PermissionMatrixMsg cmd )

        AiReviewMsg inner ->
            let
                ( next, cmd ) =
                    AiReview.update inner model.aiReview
            in
            ( { model | aiReview = next }, Cmd.map AiReviewMsg cmd )

        AiChatMsg inner ->
            let
                ( next, cmd ) =
                    AiChat.update inner model.aiChat
            in
            ( { model | aiChat = next }, Cmd.map AiChatMsg cmd )

        UploadQueueMsg inner ->
            let
                ( next, cmd ) =
                    UploadQueue.update inner model.uploadQueue
            in
            ( { model | uploadQueue = next }, Cmd.map UploadQueueMsg cmd )

        RuleBuilderMsg inner ->
            let
                ( next, cmd ) =
                    RuleBuilder.update inner model.ruleBuilder
            in
            ( { model | ruleBuilder = next }, Cmd.map RuleBuilderMsg cmd )

        FilterBarMsg inner ->
            let
                ( next, cmd ) =
                    FilterBar.update inner model.filterBar
            in
            ( { model | filterBar = next }, Cmd.map FilterBarMsg cmd )

        SavedViewsMsg inner ->
            let
                ( next, cmd ) =
                    SavedViews.update inner model.savedViews

                changed =
                    SavedViews.views next /= SavedViews.views model.savedViews

                activeRule =
                    SavedViews.active next |> Maybe.map .rule |> Maybe.withDefault (RuleBuilder.rule model.ruleBuilder)
            in
            ( { model | savedViews = next, ruleBuilder = RuleBuilder.setRule activeRule model.ruleBuilder }
            , Cmd.batch
                [ Cmd.map SavedViewsMsg cmd
                , if changed then
                    request "views" "PUT" "/api/documents/views" (Encode.list SavedViews.encode (SavedViews.views next))

                  else
                    Cmd.none
                ]
            )

        SaveBudget ->
            ( model, request "budget" "PUT" "/api/documents/budget" (Encode.list (\row -> Encode.object (List.map (\key -> ( key, Encode.string (Budget.cellValue key row) )) [ "item", "quantity", "price" ])) (Budget.rows model.budget)) )

        SetRead _ id ->
            let
                next =
                    List.map
                        (\n ->
                            if n.id == id then
                                { n | unread = False }

                            else
                                n
                        )
                        model.notifications
            in
            ( { model | notifications = next }, Cmd.batch [ request "notifications" "PUT" "/api/documents/notifications" (Encode.list encodeNotice next), Klar.focus "notifications" NoOp ] )

        DismissNotification id ->
            let
                next =
                    List.filter (\n -> n.id /= id) model.notifications
            in
            ( { model | notifications = next }, Cmd.batch [ request "notifications" "PUT" "/api/documents/notifications" (Encode.list encodeNotice next), Klar.focus "notifications" NoOp ] )

        ReadAll ->
            let
                next =
                    List.map (\n -> { n | unread = False }) model.notifications
            in
            ( { model | notifications = next }, Cmd.batch [ request "notifications" "PUT" "/api/documents/notifications" (Encode.list encodeNotice next), Klar.focus "notifications" NoOp ] )

        LoadAudit ->
            ( { model | audit = Remote.refresh model.audit }, Cmd.batch [ request "audit" "GET" "/api/events" Encode.null, Klar.focus "audit" NoOp ] )

        ApplyMerge fields ->
            ( model, request "merge" "PUT" "/api/documents/merge" (Encode.object (List.map (\( id, value ) -> ( choiceKey id, Maybe.map Encode.string value |> Maybe.withDefault Encode.null )) fields)) )

        PostComment submission ->
            if model.commentSending then
                ( model, Cmd.none )

            else
                ( { model | commentSending = True, commentError = Nothing, commentPending = Just submission }, request "comment" "POST" "/api/events" (Encode.object [ ( "action", Encode.string "Posted comment" ), ( "body", Encode.string (CommentThread.submissionBody submission) ), ( "parent", CommentThread.submissionParent submission |> Maybe.map (choiceKey >> Encode.string) |> Maybe.withDefault Encode.null ) ]) )

        SetPermissions changes ->
            let
                apply change grants =
                    let
                        key =
                            ( PermissionMatrix.changedRole change, PermissionMatrix.changedPermission change )

                        rest =
                            List.filter ((/=) key) grants
                    in
                    if Maybe.map PermissionMatrix.isGranted (PermissionMatrix.newAccess change) |> Maybe.withDefault False then
                        key :: rest

                    else
                        rest

                next =
                    List.foldl apply model.grants changes
            in
            ( { model | grants = next }, request "permissions" "PUT" "/api/documents/permissions" (Encode.list (\( role, permission ) -> Encode.list Encode.string [ role, permission ]) next) )

        DecideApproval approved ->
            ( { model
                | approval =
                    if approved then
                        ApprovalFlow.approved { at = Settings.now model.settings, comment = Just "Approved in playground" }

                    else
                        ApprovalFlow.rejected { at = Settings.now model.settings, comment = Just "Rejected in playground" }
              }
            , Cmd.batch
                [ request "approval"
                    "POST"
                    "/api/events"
                    (Encode.object
                        [ ( "action"
                          , Encode.string
                                (if approved then
                                    "Approved dispatch"

                                 else
                                    "Rejected dispatch"
                                )
                          )
                        ]
                    )
                , Klar.focus "approval" NoOp
                ]
            )

        SubmitReview decisions ->
            ( { model | reviewSaving = True, reviewError = Nothing }, request "review" "PUT" "/api/documents/review" (Encode.list (\d -> Encode.object [ ( "id", Encode.string (choiceKey d.id) ), ( "revision", Encode.string d.revision ), ( "approved", Encode.bool d.approved ), ( "reason", Encode.string d.reason ) ]) decisions) )

        SendChat submission ->
            startChat False (AiChat.submissionText submission) (Just submission) model

        RetryChat ->
            startChat True model.chatPrompt model.chatPending model

        StopChat ->
            ( { model | chatTicket = model.chatTicket + 1, chatStatus = AiChat.Interrupted, chatPending = Nothing }, request ("chat:" ++ String.fromInt model.chatTicket) "CANCEL" "/api/chat" Encode.null )

        AddUploads files ->
            let
                entries =
                    List.indexedMap (\i file -> { id = Choice (String.fromInt (model.nextUpload + i)), file = file, status = UploadQueue.pending, ticket = 0 }) files
            in
            ( { model | uploads = model.uploads ++ entries, nextUpload = model.nextUpload + List.length files, uploadQueue = UploadQueue.clear model.uploadQueue }, Cmd.none )

        StartUploads ids ->
            List.foldl
                (\id ( current, commands ) ->
                    let
                        ( next, cmd ) =
                            update (StartUpload id) current
                    in
                    ( next, cmd :: commands )
                )
                ( model, [] )
                ids
                |> (\( next, commands ) -> ( next, Cmd.batch commands ))

        StartUpload id ->
            case List.filter (\u -> u.id == id) model.uploads |> List.head of
                Nothing ->
                    ( model, Cmd.none )

                Just entry ->
                    let
                        ticket =
                            entry.ticket + 1

                        uploads =
                            List.map
                                (\u ->
                                    if u.id == id then
                                        { u | status = UploadQueue.transferring { sent = 0, total = Just (File.size u.file) }, ticket = ticket }

                                    else
                                        u
                                )
                                model.uploads
                    in
                    ( { model | uploads = uploads }, Cmd.batch [ Http.request { method = "POST", headers = [], url = "/api/uploads", body = Http.multipartBody [ Http.filePart "file" entry.file ], expect = Http.expectString (Uploaded id ticket), timeout = Just 30000, tracker = Just ("upload-" ++ choiceKey id) }, Klar.focus "upload-queue" NoOp ] )

        UploadProgress id ticket progress ->
            case progress of
                Http.Sending sending ->
                    ( { model
                        | uploads =
                            List.map
                                (\u ->
                                    if u.id == id && u.ticket == ticket then
                                        { u | status = UploadQueue.transferring { sent = sending.sent, total = Just sending.size } }

                                    else
                                        u
                                )
                                model.uploads
                      }
                    , Cmd.none
                    )

                Http.Receiving _ ->
                    ( model, Cmd.none )

        Uploaded id ticket result ->
            ( { model
                | uploads =
                    List.map
                        (\u ->
                            if u.id == id && u.ticket == ticket then
                                { u
                                    | status =
                                        case result of
                                            Ok _ ->
                                                UploadQueue.completed

                                            Err _ ->
                                                UploadQueue.failed (Remote.problem Remote.network)
                                }

                            else
                                u
                        )
                        model.uploads
              }
            , Cmd.none
            )

        CancelUpload id ->
            ( { model
                | uploads =
                    List.map
                        (\u ->
                            if u.id == id then
                                { u | status = UploadQueue.cancelled, ticket = u.ticket + 1 }

                            else
                                u
                        )
                        model.uploads
              }
            , Cmd.batch [ Http.cancel ("upload-" ++ choiceKey id), Klar.focus "upload-queue" NoOp ]
            )

        RemoveUpload id ->
            ( { model | uploads = List.filter (\u -> u.id /= id) model.uploads }, Cmd.batch [ Http.cancel ("upload-" ++ choiceKey id), Klar.focus "upload-queue" NoOp ] )

        InitServer ->
            followServer model (ServerList.init "server-orders" [])

        ServerMsg inner ->
            followServer model (ServerList.update inner model.serverList)

        FormMsg inner ->
            let
                ( next, cmd ) =
                    Form.update customerForm inner model.form
            in
            ( { model | form = next }, Cmd.map FormMsg cmd )

        SubmitForm ->
            let
                step =
                    Form.submit (Settings.locale model.settings) customerForm model.form
            in
            ( { model
                | form = step.state
                , formTicket =
                    Maybe.map .ticket step.request
                        |> (\ticket ->
                                if ticket == Nothing then
                                    model.formTicket

                                else
                                    ticket
                           )
              }
            , Cmd.batch
                [ Cmd.map FormMsg step.cmd
                , case step.request of
                    Just send ->
                        request "customer" "POST" "/api/customers" (Encode.object [ ( "name", Encode.string send.values.name ), ( "email", Encode.string send.values.email ), ( "warehouse", Encode.string (choiceKey send.values.warehouse) ), ( "credit", Maybe.map Money.encodeMinor send.values.credit |> Maybe.withDefault Encode.null ), ( "active", Encode.bool send.values.active ) ])

                    Nothing ->
                        Cmd.none
                ]
            )

        ResetForm ->
            ( { model | form = Form.revert customerForm model.form }, Cmd.none )

        SetEmail value ->
            ( { model | email = value }, Cmd.none )

        DirtyGuard value ->
            ( { model | guard = LeaveGuard.setDirty (Choice "sample") value model.guard }, Cmd.none )

        TryLeave ->
            case LeaveGuard.request (Choice "destination") model.guard of
                LeaveGuard.Proceed _ ->
                    update (Notify "Sample departure allowed") model

                LeaveGuard.Hold guard cmd ->
                    ( { model | guard = guard }, Cmd.map GuardMsg cmd )

        GuardMsg inner ->
            let
                ( guard, cmd, decision ) =
                    LeaveGuard.update inner model.guard
            in
            ( { model
                | guard = guard
                , response =
                    if decision /= Nothing then
                        "Left the sample draft"

                    else
                        model.response
              }
            , Cmd.map GuardMsg cmd
            )

        SelectNode id ->
            ( { model | selectedNode = Just id }, Cmd.none )

        AddWorkflowNode kind ->
            let
                definition =
                    model.workflow

                next =
                    { definition | nodes = definition.nodes ++ [ Workflow.node (Choice ("step-" ++ String.fromInt (List.length definition.nodes))) kind (Workflow.kindLabel Locale.en kind) ] }
            in
            ( { model | workflow = next }, Cmd.none )

        ChangeWorkflow definition ->
            ( { model | workflow = definition }, Cmd.none )

        StartWorkflow ->
            case Engine.start "playground-run" model.workflow Dict.empty of
                Ok run ->
                    ( { model | run = Just run }, Cmd.none )

                Err issues ->
                    update (Notify (String.join "; " (List.map (Workflow.issueText (Settings.locale model.settings) model.workflow) issues))) model

        CompleteNode ->
            ( { model | run = Maybe.map (Engine.complete (Encode.string "Completed by playground user")) model.run }, Cmd.none )

        PauseRun ->
            ( { model | run = Maybe.map Engine.pause model.run }, Cmd.none )

        ResumeRun ->
            ( { model | run = Maybe.map Engine.resume model.run }, Cmd.none )

        CancelRun ->
            ( { model | run = Maybe.map Engine.cancel model.run }, Cmd.none )

        SaveWorkflow ->
            ( model, request "workflow" "PUT" "/api/documents/workflow" (WorkflowCodec.encode choiceIds model.workflow) )

        TransitionState event ->
            ( { model | machine = StateMachine.transition event model.machine |> Maybe.withDefault model.machine }, Cmd.none )

        NoOp ->
            ( model, Cmd.none )


request id method url body =
    outgoing (Encode.object [ ( "id", Encode.string id ), ( "method", Encode.string method ), ( "url", Encode.string url ), ( "body", body ) ])


retryRegion id model =
    let
        ( next, cmd ) =
            update Reload model
    in
    ( next, Cmd.batch [ cmd, Klar.focus id NoOp ] )


snapshot model =
    Encode.object [ ( "text", Encode.string model.text ), ( "checked", Encode.bool model.checked ), ( "slider", Encode.float model.slider ), ( "note", Encode.string (History.present model.history) ), ( "theme", Encode.string (Theme.key (Settings.theme model.settings)) ), ( "mode", Encode.string (Theme.modeKey (Settings.mode model.settings)) ) ]


receive value model =
    let
        id =
            Decode.decodeValue (Decode.field "id" Decode.string) value |> Result.withDefault ""

        ok =
            Decode.decodeValue (Decode.field "ok" Decode.bool) value |> Result.withDefault False

        body =
            Decode.decodeValue (Decode.field "body" Decode.value) value |> Result.withDefault Encode.null

        read key decoder fallback =
            Decode.decodeValue (Decode.field key decoder) body |> Result.withDefault fallback

        at =
            Decode.decodeValue (Decode.field "at" Decode.int) value |> Result.withDefault 0 |> Time.millisToPosix
    in
    if String.startsWith "orders:" id then
        if id /= "orders:" ++ String.fromInt model.epoch then
            ( model, Cmd.none )

        else
            let
                result =
                    if ok then
                        Decode.decodeValue (Decode.list (Decode.map3 Order (Decode.field "id" (Decode.map RecordId Decode.string)) (Decode.field "customer" Decode.string) (Decode.field "total" Decode.int))) body |> Result.mapError (\_ -> Remote.problem Remote.unknown)

                    else
                        Err (Remote.problem Remote.server)
            in
            ( { model
                | orders = Remote.refreshWith model.orders result at
                , response =
                    if ok then
                        "Loaded from Go / SQLite"

                    else
                        "Request failed; previous data is retained"
              }
            , Cmd.none
            )

    else if id == "restore" then
        if ok then
            ( { model | text = read "text" Decode.string model.text, checked = read "checked" Decode.bool model.checked, slider = read "slider" Decode.float model.slider, history = History.init (read "note" Decode.string (History.present model.history)), settings = model.settings |> Settings.withTheme (read "theme" Decode.string "klar" |> Theme.fromKey |> Maybe.withDefault Theme.klar) |> Settings.withMode (read "mode" Decode.string "light" |> Theme.modeFromKey |> Maybe.withDefault Theme.Light) }, Cmd.none )

        else
            ( model, Cmd.none )

    else if id == "inline" then
        ( { model
            | inlineEdit =
                if ok then
                    InlineEdit.saved model.inlineEdit

                else
                    InlineEdit.failed (Remote.problem Remote.server) model.inlineEdit
          }
        , Cmd.none
        )

    else if id == "confirm" then
        if ok then
            let
                ( next, cmd ) =
                    ConfirmDialog.close model.confirmDialog
            in
            ( { model | confirmDialog = next, response = "Event persisted in SQLite" }, Cmd.map ConfirmDialogMsg cmd )

        else
            ( { model | confirmDialog = ConfirmDialog.setFailed (Remote.problem Remote.server) model.confirmDialog }, Cmd.none )

    else if id == "audit" then
        let
            decoder =
                Decode.list (Decode.map3 AuditEntry (Decode.field "id" Decode.string) (Decode.field "action" Decode.string) (Decode.field "at" Decode.int))

            result =
                if ok then
                    Decode.decodeValue decoder body |> Result.mapError (\_ -> Remote.problem Remote.unknown)

                else
                    Err (Remote.problem Remote.server)
        in
        ( { model | audit = Remote.refreshWith model.audit result at }, Cmd.none )

    else if id == "comment" then
        case ( ok, model.commentPending ) of
            ( True, Just pending ) ->
                let
                    comment =
                        CommentThread.comment { id = Choice ("comment-" ++ read "id" Decode.string (String.fromInt (Time.posixToMillis at))), author = "You", body = CommentThread.submissionBody pending, at = at }

                    nested =
                        Maybe.map (\parent -> CommentThread.replyTo parent comment) (CommentThread.submissionParent pending) |> Maybe.withDefault comment
                in
                ( { model | comments = model.comments ++ [ nested ], commentThread = CommentThread.acknowledge pending model.commentThread, commentPending = Nothing, commentSending = False }, Cmd.none )

            _ ->
                ( { model | commentSending = False, commentError = Just "Could not post comment. The draft is retained." }, Cmd.none )

    else if id == "review" then
        ( { model
            | reviewSaving = False
            , reviewError =
                if ok then
                    Nothing

                else
                    Just "The server could not save these decisions."
          }
        , Cmd.none
        )

    else if id == "comments-history" then
        if ok && model.commentPending == Nothing then
            ( { model | comments = List.take 1 model.comments ++ (Decode.decodeValue (Decode.list commentDecoder) body |> Result.withDefault []) }, Cmd.none )

        else
            ( model, Cmd.none )

    else if id == "chat-history" then
        ( { model
            | chatMessages =
                if model.chatTicket == 0 && ok then
                    Decode.decodeValue (Decode.list chatDecoder) body |> Result.withDefault []

                else
                    model.chatMessages
          }
        , Cmd.none
        )

    else if String.startsWith "chat:" id then
        if id /= "chat:" ++ String.fromInt model.chatTicket then
            ( model, Cmd.none )

        else
            let
                phase =
                    read "phase" Decode.string "failed"

                assistantId =
                    "assistant-" ++ String.fromInt model.chatTicket
            in
            if not ok then
                ( { model | chatStatus = AiChat.Failed "Generation failed. Retry keeps the conversation." }, Cmd.none )

            else if phase == "accepted" then
                ( { model | aiChat = Maybe.map (\submission -> AiChat.acknowledge submission model.aiChat) model.chatPending |> Maybe.withDefault model.aiChat, chatPending = Nothing }, Cmd.none )

            else if phase == "chunk" then
                ( { model
                    | chatMessages =
                        List.map
                            (\m ->
                                if m.id == assistantId then
                                    { m | body = m.body ++ read "text" Decode.string "" }

                                else
                                    m
                            )
                            model.chatMessages
                  }
                , Cmd.none
                )

            else if phase == "done" then
                ( { model | chatStatus = AiChat.Idle }, Cmd.none )

            else
                ( model, Cmd.none )

    else if String.startsWith "server:" id then
        case Dict.get id model.serverPending of
            Just pending ->
                let
                    decoder =
                        Decode.map2 (\rows total -> { rows = rows, total = total }) (Decode.field "rows" (Decode.list orderDecoder)) (Decode.field "total" Decode.int)

                    result =
                        if ok then
                            Decode.decodeValue decoder body |> Result.mapError (\_ -> Remote.problem Remote.unknown)

                        else
                            Err (Remote.problem Remote.server)
                in
                followServer { model | serverPending = Dict.remove id model.serverPending } (ServerList.update (ServerList.gotPage pending result) model.serverList)

            Nothing ->
                ( model, Cmd.none )

    else if id == "restore-notifications" then
        ( { model
            | notifications =
                if ok then
                    Decode.decodeValue (Decode.list noticeDecoder) body |> Result.withDefault model.notifications

                else
                    model.notifications
          }
        , Cmd.none
        )

    else if id == "restore-budget" then
        ( { model
            | budget =
                if ok then
                    Decode.decodeValue (Decode.list (Decode.dict Decode.string |> Decode.map (Dict.toList >> Budget.row))) body |> Result.map (\rows -> Budget.setRows rows model.budget) |> Result.withDefault model.budget

                else
                    model.budget
          }
        , Cmd.none
        )

    else if id == "restore-board" then
        let
            board =
                Decode.decodeValue (Decode.list (Decode.list boardCardDecoder)) body |> Result.map (\columns -> List.map2 (\( key, title ) cards -> Kanban.column (Choice key) title cards) [ ( "todo", "To do" ), ( "doing", "In progress" ), ( "done", "Done" ) ] columns) |> Result.withDefault model.board
        in
        ( { model
            | board =
                if ok then
                    board

                else
                    model.board
          }
        , Cmd.none
        )

    else if id == "restore-permissions" then
        ( { model
            | grants =
                if ok then
                    Decode.decodeValue (Decode.list (Decode.map2 Tuple.pair (Decode.index 0 Decode.string) (Decode.index 1 Decode.string))) body |> Result.withDefault model.grants

                else
                    model.grants
          }
        , Cmd.none
        )

    else if id == "restore-workflow" then
        ( { model
            | workflow =
                if ok then
                    Decode.decodeValue (WorkflowCodec.decoder choiceIds) body |> Result.withDefault model.workflow

                else
                    model.workflow
          }
        , Cmd.none
        )

    else if id == "restore-inline" then
        ( { model
            | inlineEdit =
                if ok && not (InlineEdit.isEditing model.inlineEdit) then
                    InlineEdit.setValue (read "text" Decode.string (InlineEdit.value model.inlineEdit)) model.inlineEdit

                else
                    model.inlineEdit
          }
        , Cmd.none
        )

    else if id == "restore-customer" then
        if ok && not (Form.isDirty model.form) then
            let
                fields =
                    Form.fields customerForm

                next =
                    model.form
                        |> Form.set fields.name (read "name" Decode.string "")
                        |> Form.set fields.email (read "email" Decode.string "")
                        |> Form.set fields.warehouse
                            (read "warehouse" Decode.string ""
                                |> (\key ->
                                        if key == "" then
                                            Nothing

                                        else
                                            Just (Choice key)
                                   )
                            )
                        |> Form.set fields.credit (read "credit" (Decode.nullable (Money.minorDecoder Money.nok)) Nothing)
                        |> Form.set fields.active (read "active" Decode.bool False)
                        |> Form.markClean
            in
            ( { model | form = next }, Cmd.none )

        else
            ( model, Cmd.none )

    else if id == "restore-server-views" then
        if ok then
            followServer model (ServerList.setViews (Decode.decodeValue (Decode.list SavedViews.decoder) body |> Result.withDefault []) model.serverList)

        else
            ( model, Cmd.none )

    else if id == "restore-views" then
        if ok then
            let
                views =
                    Decode.decodeValue (Decode.list SavedViews.decoder) body |> Result.withDefault []
            in
            ( { model | savedViews = SavedViews.setViews views model.savedViews }, Cmd.none )

        else
            ( model, Cmd.none )

    else if id == "customer" then
        case model.formTicket of
            Nothing ->
                ( model, Cmd.none )

            Just ticket ->
                let
                    errors =
                        read "problems" (Decode.list (Decode.map2 (\field message -> { field = field, message = message }) (Decode.field "field" Decode.string) (Decode.field "message" Decode.string))) []

                    result =
                        if ok then
                            Ok "Customer saved to SQLite"

                        else if List.isEmpty errors then
                            Err (Submission.Failed (Remote.problem Remote.server))

                        else
                            Err (Submission.Rejected errors)

                    ( next, cmd ) =
                        Form.finish ticket result customerForm model.form
                in
                ( { model | form = next, formTicket = Nothing }, Cmd.map FormMsg cmd )

    else
        update
            (Notify
                (if ok then
                    "Saved to SQLite"

                 else
                    "Server request failed"
                )
            )
            model


navigation =
    List.map (\page -> SideNav.item pageIds { key = Page page, label = page, href = "#/" ++ page }) pages


pageFromUrl url =
    let
        route =
            String.dropLeft 1 (Maybe.withDefault "/Foundations" url.fragment)
    in
    Page
        (if List.member route pages then
            route

         else
            "Foundations"
        )


money minor =
    Money.fromMinor Money.nok minor |> Maybe.withDefault (Money.zero Money.nok)


sampleDate =
    Date.fromEpochDay 20751


setCalendarToday settings calendar =
    Settings.today settings |> Maybe.map (\today -> Calendar.setToday today calendar) |> Maybe.withDefault calendar


choices =
    List.map (\name -> Select.option (Choice name) name) [ "Oslo", "Bergen", "Trondheim", "Stavanger", "Tromsø" ]


nodes =
    [ Picking.branch choiceIds (Choice "north") "Norway" (List.map (\name -> Picking.leaf choiceIds (Choice name) name) [ "Oslo", "Bergen", "Trondheim" ]) ]


menuItems =
    [ Menu.item "Save snapshot" SaveSnapshot, Menu.item "Reload orders" Reload, Menu.separator, Menu.item "Show message" (Notify "Menu action") ]


view model =
    let
        (Page page) =
            model.page
    in
    { title = "Klar Kitchen Sink · " ++ page
    , body = [ Klar.stylesheetFor model.settings, AppShell.view [ AppShell.state ShellMsg model.shell, AppShell.settings model.settings, AppShell.shortcuts (Shortcut.listen ShortcutMsg shortcuts model.shortcut), AppShell.onStrayDrop NoOp, AppShell.pageTitle page, AppShell.brand (AppShell.brandLink { name = "Klar Kitchen Sink", href = "#/Foundations", logo = Nothing }), AppShell.sidebar (AppShell.sideNav ShellMsg [ SideNav.entries navigation ] model.shell), AppShell.overlays (overlays model) ] [ Layout.stack [ Layout.gap 6 ] [ PageHeader.view [ PageHeader.title page, PageHeader.subtitle "Elm + Go + SQLite · documentation-only consumer", PageHeader.actions [ Button.view [ Button.onClick SaveSnapshot ] "Save snapshot", Button.view [ Button.onClick OpenPalette ] "Commands" ] ], Text.secondary model.response, scenarioControls, viewPage model ] ] ]
    }


scenarioControls =
    Layout.row [ Layout.gap 2, Layout.wrap ] [ Text.caption "Data and Dashboard remote state", Button.view [ Button.onClick ResetRemote ] "Clear remote data", Button.view [ Button.onClick (LoadScenario "data") ] "Data", Button.view [ Button.onClick (LoadScenario "empty") ] "Empty", Button.view [ Button.onClick (LoadScenario "slow") ] "Slow refresh", Button.view [ Button.onClick (LoadScenario "fail") ] "Failure / old data" ]


overlays model =
    let
        locale =
            Settings.locale model.settings
    in
    [ Toast.view ToastMsg [ Toast.locale locale ] model.toasts, Modal.view ModalMsg [ Modal.locale locale ] model.modal "Edit customer" [ TextInput.view [ TextInput.label "Customer name", TextInput.value model.text, TextInput.onInput SetText ], Button.view [ Button.onClick SaveSnapshot ] "Save snapshot" ], Drawer.view DrawerMsg [ Drawer.locale locale ] model.drawer "Order details" [ Text.paragraph "Details stay beside the main page." ], ConfirmDialog.view ConfirmDialogMsg [ ConfirmDialog.locale locale, ConfirmDialog.message "Persist a sample event?", ConfirmDialog.onConfirm ConfirmAction ] model.confirmDialog "Confirm action", CommandPalette.view CommandPaletteMsg [ CommandPalette.locale locale, CommandPalette.sections [ CommandPalette.section "Actions" [ CommandPalette.item "Save snapshot" SaveSnapshot, CommandPalette.item "Refresh orders" Reload ] ] ] model.commandPalette, ShortcutHelp.view ShortcutHelpMsg [ ShortcutHelp.locale locale ] shortcuts model.shortcutHelp, LeaveGuard.view GuardMsg [ LeaveGuard.locale locale ] model.guard ]


viewPage model =
    let
        (Page page) =
            model.page

        locale =
            Settings.locale model.settings
    in
    case page of
        "Foundations" ->
            Layout.stack [ Layout.gap 4 ] [ Card.view [ Card.title "Foundations", Card.id "component-Foundations" ] [ Layout.stack [ Layout.gap 4 ] [ Text.lead "A complete consumer application built from the AI documentation.", DescriptionList.view [] [ DescriptionList.text "Stack" "Elm / Go / SQLite", DescriptionList.text "Library access" "Public API and generated documentation only", DescriptionList.text "Persistence" "Use Save snapshot; reload to restore" ], Layout.row [ Layout.gap 2, Layout.wrap ] (List.map (\theme -> Button.view [ Button.onClick (SetTheme theme) ] (Theme.name locale theme)) Theme.all), Switch.view [ Switch.label "Dark mode", Switch.checked (Settings.mode model.settings == Theme.Dark), Switch.onCheck SetDark ], Switch.view [ Switch.label "Norwegian component text", Switch.checked (Settings.locale model.settings == Locale.nb), Switch.onCheck SetNorwegian ], SegmentedControl.view [ SegmentedControl.label "Density", SegmentedControl.options [ SegmentedControl.option Theme.Compact "Compact", SegmentedControl.option Theme.Normal "Normal", SegmentedControl.option Theme.Comfortable "Comfortable" ], SegmentedControl.selected (Settings.density model.settings), SegmentedControl.onChange SetDensity ], Layout.row [ Layout.gap 2 ] [ Tag.view [ Tag.color (Color.rgb 30 120 160) ] "Custom data color", Text.code (Format.int locale 1234567) ] ] ] ]

        "Actions" ->
            Layout.stack [ Layout.gap 4 ]
                [ Card.view [ Card.title "Button", Card.id "component-Button" ] [ Layout.row [ Layout.gap 2, Layout.wrap ] [ Button.view [ Button.locale locale, Button.primary, Button.onClick (Notify "Primary action") ] "Primary", Button.view [ Button.locale locale, Button.secondary, Button.onClick (Notify "Secondary action") ] "Secondary", Button.view [ Button.locale locale, Button.danger, Button.onClick OpenConfirm ] "Delete", Button.view [ Button.locale locale, Button.loading True ] "Working", Button.view [ Button.locale locale, Button.disabled True ] "Disabled", Button.iconOnly [ Button.onClick (Notify "Settings") ] Icon.settings "Settings" ] ]
                , Card.view [ Card.title "ButtonGroup", Card.id "component-ButtonGroup" ] [ ButtonGroup.view [] "Export format" [ Button.view [ Button.onClick (Notify "CSV selected") ] "CSV", Button.view [ Button.onClick (Notify "JSON selected") ] "JSON" ] ]
                , Card.view [ Card.title "ToggleGroup", Card.id "component-ToggleGroup" ] [ ToggleGroup.single [ ToggleGroup.label "View mode" ] { selected = Just (Choice model.choice), onChange = Maybe.map choiceKey >> Maybe.withDefault "table" >> SetChoice } [ ToggleGroup.option (Choice "table") "Table", ToggleGroup.option (Choice "cards") "Cards" ] ]
                , Card.view [ Card.title "SplitButton", Card.id "component-SplitButton" ] [ SplitButton.view SplitButtonMsg [ SplitButton.locale locale ] { label = "Save", onClick = SaveSnapshot, items = menuItems } model.splitButton ]
                , Card.view [ Card.title "Menu", Card.id "component-Menu" ] [ Menu.view MenuMsg [ Menu.label "Actions", Menu.items menuItems ] model.menu ]
                , Card.view [ Card.title "Link", Card.id "component-Link" ] [ Layout.row [ Layout.gap 4 ] [ Link.view [ Link.locale locale ] (Link.internal "#/Data") "Open data", Link.view [ Link.locale locale ] (Link.download { fileName = "sample.txt", mimeType = "text/plain", content = model.text }) "Download text" ] ]
                , Card.view [ Card.title "Kbd", Card.id "component-Kbd" ] [ Layout.row [ Layout.gap 2 ] [ Kbd.view [ Kbd.locale locale ] (Shortcut.mod (Shortcut.char 'k')), Kbd.key [ Kbd.locale locale ] "Esc" ] ]
                ]

        "Feedback" ->
            Layout.stack [ Layout.gap 4 ]
                [ Card.view [ Card.title "Badge", Card.id "component-Badge" ] [ Layout.row [ Layout.gap 2 ] (List.map (\tone -> Badge.view [ Badge.locale locale, Badge.tone tone, Badge.dot ] "Status") [ Neutral, Primary, Info, Success, Warning, Danger ]) ]
                , Card.view [ Card.title "Tag", Card.id "component-Tag" ]
                    [ if model.tagVisible then
                        Tag.view [ Tag.locale locale, Tag.onRemove DismissTag, Tag.tone Info ] "Removable tag"

                      else
                        Button.view [ Button.id "restore-tag", Button.onClick RestoreTag ] "Restore tag"
                    ]
                , Card.view [ Card.title "Alert", Card.id "component-Alert" ]
                    [ if model.alertVisible then
                        Alert.view [ Alert.locale locale, Alert.tone Info, Alert.title "Documentation-only exercise", Alert.onDismiss DismissAlert ] "Every sample uses only the public API."

                      else
                        Button.view [ Button.id "restore-alert", Button.onClick RestoreAlert ] "Restore alert"
                    ]
                , Card.view [ Card.title "Spinner", Card.id "component-Spinner" ] [ Spinner.panel [ Spinner.compact ] "Loading sample" ]
                , Card.view [ Card.title "Skeleton", Card.id "component-Skeleton" ] [ Layout.stack [ Layout.gap 2 ] [ Skeleton.lines 2, Skeleton.block 48, Skeleton.circle 32 ] ]
                , Card.view [ Card.title "Progress", Card.id "component-Progress" ] [ Layout.row [ Layout.gap 4 ] [ Progress.view [ Progress.locale locale, Progress.value model.slider, Progress.label "Completion", Progress.showValue ], Progress.ring [ Progress.locale locale, Progress.value model.slider, Progress.ariaLabel "Completion" ] ] ]
                , Card.view [ Card.title "EmptyState", Card.id "component-EmptyState" ] [ EmptyState.view [ EmptyState.locale locale, EmptyState.title "No matching orders", EmptyState.description "Adjust the filter to try again.", EmptyState.actions [ Button.view [ Button.onClick Reload ] "Reload" ] ] ]
                , Card.view [ Card.title "ErrorState", Card.id "component-ErrorState" ] [ ErrorState.view [ ErrorState.locale locale, ErrorState.onRetry Reload ] (Remote.problem Remote.network) ]
                , Card.view [ Card.title "StatusPage", Card.id "component-StatusPage" ] [ StatusPage.view [ StatusPage.locale locale, StatusPage.title "Sample operation complete", StatusPage.description "This is an embedded result page." ] StatusPage.success ]
                ]

        "Inputs" ->
            Layout.stack [ Layout.gap 4 ]
                [ Card.view [ Card.title "TextInput", Card.id "component-TextInput" ] [ TextInput.view [ TextInput.locale locale, TextInput.id "text", TextInput.label "Customer name", TextInput.value model.text, TextInput.onInput SetText, TextInput.clearable ] ]
                , Card.view [ Card.title "TextArea", Card.id "component-TextArea" ] [ TextArea.view [ TextArea.locale locale, TextArea.label "Notes", TextArea.value model.text, TextArea.onInput SetText, TextArea.rows 3 ] ]
                , Card.view [ Card.title "NumberInput", Card.id "component-NumberInput" ] [ NumberInput.view NumberInputMsg [ NumberInput.locale locale, NumberInput.label "NumberInput", NumberInput.locale locale ] model.numberInput ]
                , Card.view [ Card.title "PasswordInput", Card.id "component-PasswordInput" ] [ PasswordInput.view PasswordInputMsg [ PasswordInput.locale locale, PasswordInput.label "PasswordInput", PasswordInput.locale locale ] model.passwordInput ]
                , Card.view [ Card.title "SearchInput", Card.id "component-SearchInput" ] [ SearchInput.view SearchInputMsg [ SearchInput.locale locale, SearchInput.label "SearchInput", SearchInput.locale locale ] model.searchInput ]
                , Card.view [ Card.title "TagInput", Card.id "component-TagInput" ] [ TagInput.view TagInputMsg [ TagInput.locale locale, TagInput.label "TagInput", TagInput.locale locale ] model.tagInput ]
                , Card.view [ Card.title "FileDrop", Card.id "component-FileDrop" ] [ FileDrop.view FileDropMsg [ FileDrop.locale locale, FileDrop.label "FileDrop", FileDrop.locale locale ] model.fileDrop ]
                , Card.view [ Card.title "InlineEdit", Card.id "component-InlineEdit" ] [ InlineEdit.view InlineEditMsg [ InlineEdit.locale locale, InlineEdit.ariaLabel "Warehouse label" ] model.inlineEdit ]
                , Card.view [ Card.title "MaskedInput", Card.id "component-MaskedInput" ] [ MaskedInput.view MaskedInputMsg [ MaskedInput.locale locale, MaskedInput.label "MaskedInput", MaskedInput.locale locale ] model.maskedInput ]
                , Card.view [ Card.title "MoneyInput", Card.id "component-MoneyInput" ] [ MoneyInput.view MoneyInputMsg [ MoneyInput.locale locale, MoneyInput.label "MoneyInput", MoneyInput.locale locale ] model.moneyInput ]
                , Card.view [ Card.title "QuantityInput", Card.id "component-QuantityInput" ] [ QuantityInput.view QuantityInputMsg [ QuantityInput.locale locale, QuantityInput.label "Weight" ] { ids = choiceIds, units = [ QuantityInput.unit (Choice "kg") "Kilograms" "kg", QuantityInput.unit (Choice "g") "Grams" "g" ] } model.quantityInput ]
                , Card.view [ Card.title "Checkbox", Card.id "component-Checkbox" ] [ Checkbox.view [ Checkbox.label "Accept terms", Checkbox.checked model.checked, Checkbox.onCheck SetChecked ] ]
                , Card.view [ Card.title "Switch", Card.id "component-Switch" ] [ Switch.view [ Switch.locale locale, Switch.label "Enable notifications", Switch.checked model.checked, Switch.onCheck SetChecked ] ]
                , Card.view [ Card.title "CheckboxGroup", Card.id "component-CheckboxGroup" ] [ CheckboxGroup.view [ CheckboxGroup.locale locale, CheckboxGroup.label "Warehouses", CheckboxGroup.options [ CheckboxGroup.option (Choice "oslo") "Oslo", CheckboxGroup.option (Choice "bergen") "Bergen" ], CheckboxGroup.selected model.choices, CheckboxGroup.onChange SetChoices, CheckboxGroup.selectAll ] ]
                , Card.view [ Card.title "Radio", Card.id "component-Radio" ] [ Radio.view [ Radio.label "Delivery", Radio.options [ Radio.option (Choice "standard") "Standard", Radio.option (Choice "express") "Express" ], Radio.selected (Just (Choice model.choice)), Radio.onChange (choiceKey >> SetChoice) ] ]
                , Card.view [ Card.title "SegmentedControl", Card.id "component-SegmentedControl" ] [ SegmentedControl.view [ SegmentedControl.label "Display", SegmentedControl.options [ SegmentedControl.option "table" "Table", SegmentedControl.option "cards" "Cards" ], SegmentedControl.selected model.choice, SegmentedControl.onChange SetChoice ] ]
                , Card.view [ Card.title "Slider", Card.id "component-Slider" ] [ Slider.view [ Slider.locale locale, Slider.label "Completion", Slider.value model.slider, Slider.onInput SetSlider, Slider.min 0, Slider.max 100, Slider.unit "%" ] ]
                ]

        "Choosing" ->
            Layout.stack [ Layout.gap 4 ]
                [ Card.view [ Card.title "Select", Card.id "component-Select" ] [ Select.view SelectMsg [ Select.locale locale, Select.label "Select", Select.options choices, Select.locale locale, Select.clearable ] model.select ]
                , Card.view [ Card.title "MultiSelect", Card.id "component-MultiSelect" ] [ MultiSelect.view MultiSelectMsg [ MultiSelect.locale locale, MultiSelect.label "MultiSelect", MultiSelect.options choices, MultiSelect.locale locale, MultiSelect.clearable ] model.multiSelect ]
                , Card.view [ Card.title "Autocomplete", Card.id "component-Autocomplete" ] [ Autocomplete.view AutocompleteMsg [ Autocomplete.locale locale, Autocomplete.label "Autocomplete", Autocomplete.options choices, Autocomplete.locale locale, Autocomplete.clearable ] model.autocomplete ]
                , Card.view [ Card.title "TreeSelect", Card.id "component-TreeSelect" ] [ TreeSelect.view TreeSelectMsg [ TreeSelect.locale locale, TreeSelect.label "Warehouse", TreeSelect.nodes nodes, TreeSelect.clearable ] model.treeSelect ]
                , Card.view [ Card.title "Cascader", Card.id "component-Cascader" ] [ Cascader.view CascaderMsg [ Cascader.locale locale, Cascader.label "Location path", Cascader.nodes nodes ] model.cascader ]
                , Card.view [ Card.title "Transfer", Card.id "component-Transfer" ] [ Transfer.view TransferMsg [ Transfer.locale locale, Transfer.label "Assign warehouses", Transfer.options choiceIds choices ] model.transfer ]
                ]

        "Dates" ->
            Layout.stack [ Layout.gap 4 ]
                [ Card.view [ Card.title "DatePicker", Card.id "component-DatePicker" ] [ DatePicker.view DatePickerMsg ([ DatePicker.label "DatePicker", DatePicker.locale locale, DatePicker.clearable ] ++ List.filterMap identity [ Maybe.map DatePicker.today (Settings.today model.settings) ]) model.datePicker ]
                , Card.view [ Card.title "DateRangePicker", Card.id "component-DateRangePicker" ] [ DateRangePicker.view DateRangePickerMsg ([ DateRangePicker.label "DateRangePicker", DateRangePicker.locale locale, DateRangePicker.clearable ] ++ List.filterMap identity [ Maybe.map DateRangePicker.today (Settings.today model.settings) ]) model.dateRangePicker ]
                , Card.view [ Card.title "TimePicker", Card.id "component-TimePicker" ] [ TimePicker.view TimePickerMsg [ TimePicker.locale locale, TimePicker.label "TimePicker", TimePicker.locale locale ] model.timePicker ]
                , Card.view [ Card.title "DateTimePicker", Card.id "component-DateTimePicker" ] [ DateTimePicker.view DateTimePickerMsg ([ DateTimePicker.label "DateTimePicker", DateTimePicker.locale locale, DateTimePicker.clearable ] ++ List.filterMap identity [ Maybe.map DateTimePicker.today (Settings.today model.settings) ]) model.dateTimePicker ]
                , Card.view [ Card.title "Calendar", Card.id "component-Calendar" ] [ Calendar.view CalendarMsg [ Calendar.locale locale, Calendar.weekNumbers, Calendar.todayButton, Calendar.markers [ Calendar.dot sampleDate Success "Dispatch" ] ] model.calendar ]
                , Card.view [ Card.title "RecurrencePicker", Card.id "component-RecurrencePicker" ] [ RecurrencePicker.view RecurrencePickerMsg [ RecurrencePicker.locale locale, RecurrencePicker.label "RecurrencePicker", RecurrencePicker.locale locale ] model.recurrencePicker ]
                , Card.view [ Card.title "Recurrence", Card.id "component-Recurrence" ] [ Text.paragraph (RecurrencePicker.value model.recurrencePicker |> Maybe.map (\rule -> Recurrence.describe locale rule ++ " · " ++ Recurrence.toRRule rule) |> Maybe.withDefault "Choose a recurrence above to inspect its description and RFC rule.") ]
                ]

        "Data" ->
            Layout.stack [ Layout.gap 4 ]
                [ Card.view [ Card.title "Tree", Card.id "component-Tree" ] [ Tree.view TreeMsg [ Tree.locale locale, Tree.ariaLabel "Warehouses", Tree.checkboxes, Tree.filterBox ] model.tree [ Tree.branch choiceIds (Choice "north") "Northern region" [ Tree.leaf choiceIds (Choice "oslo") "Oslo", Tree.leaf choiceIds (Choice "bergen") "Bergen" ] ] ]
                , Card.view [ Card.title "VirtualList", Card.id "component-VirtualList" ] [ VirtualList.list VirtualListMsg [ VirtualList.height 240, VirtualList.onSelect (String.fromInt >> Notify) ] { label = "Ten thousand locations", items = Array.fromList (List.range 1 10000), viewRow = \n -> Text.text ("Location " ++ String.fromInt n) } model.virtualList ]
                , Card.view [ Card.title "Table", Card.id "component-Table" ] [ Table.view TableMsg [ Table.locale locale, Table.columns [ Table.text (Table.columnId "id") "Order" (\r -> recordKey r.id) [], Table.text (Table.columnId "customer") "Customer" .customer [ Table.filterText ], Table.money (Table.columnId "total") "Total" (\r -> money r.total) [ Table.footerSum ] ], Table.rowId recordIds .id, Table.remote model.orders, Table.onRetry Reload, Table.ariaLabel "Orders from SQLite", Table.settings model.settings ] model.table ]
                , Card.view [ Card.title "Pagination", Card.id "component-Pagination" ] [ Pagination.view [ Pagination.locale locale, Pagination.onPage SetPageNumber, Pagination.jumpToPage ] { page = model.pageNumber, pageSize = 20, total = 500 } ]
                , Card.view [ Card.title "ListItem", Card.id "component-ListItem" ] [ ListItem.list [ ListItem.locale locale, ListItem.ariaLabel "Recent activity", ListItem.bordered ] [ ListItem.view [ ListItem.avatar "Aurora Logistics", ListItem.secondary "Order ready", ListItem.onClick (Notify "Order selected") ] "Aurora Logistics", ListItem.view [ ListItem.meta "Pending" ] "Fjord Foods" ] ]
                , Card.view [ Card.title "Budget", Card.id "component-Budget" ] [ Layout.stack [ Layout.gap 2 ] [ Budget.view BudgetMsg [ Budget.locale locale, Budget.title "Dispatch budget", Budget.locale locale ] model.budget, Button.view [ Button.onClick SaveBudget ] "Save budget to SQLite" ] ]
                , Card.view [ Card.title "CardList", Card.id "component-CardList" ] [ CardList.view [ CardList.locale locale, CardList.id "card-list", CardList.onOpen (recordKey >> Notify), CardList.onRetry RetryCards ] { label = "Sample order cards (first six)", items = Remote.map (List.take 6) model.orders, ids = recordIds, id = .id, title = .customer, fields = [ CardList.field "Order" (\r -> Text.mono (recordKey r.id)), CardList.field "Total" (\r -> Text.text (Money.toString locale (money r.total))) ] } ]
                , Card.view [ Card.title "WorkQueue", Card.id "component-WorkQueue" ] [ WorkQueue.view WorkQueueMsg [ WorkQueue.locale locale, WorkQueue.searchable, WorkQueue.onRetry RetryWorkQueue ] { label = "Orders to review", items = model.orders, ids = recordIds, id = .id, title = .customer, summary = \r -> recordKey r.id, detail = \r -> DescriptionList.view [] [ DescriptionList.text "Customer" r.customer, DescriptionList.text "Order" (recordKey r.id) ] } model.workQueue ]
                ]

        "Content" ->
            Layout.stack [ Layout.gap 4 ]
                [ Card.view [ Card.title "JsonViewer", Card.id "component-JsonViewer" ] [ JsonViewer.view JsonViewerMsg [ JsonViewer.locale locale, JsonViewer.toolbar ] model.jsonViewer (Encode.object [ ( "customer", Encode.string model.text ), ( "completion", Encode.float model.slider ) ]) ]
                , Card.view [ Card.title "MarkdownEditor", Card.id "component-MarkdownEditor" ] [ MarkdownEditor.view MarkdownEditorMsg [ MarkdownEditor.locale locale, MarkdownEditor.label "MarkdownEditor", MarkdownEditor.locale locale ] model.markdownEditor ]
                , Card.view [ Card.title "Markdown", Card.id "component-Markdown" ] [ Markdown.view [ Markdown.locale locale ] (MarkdownEditor.value model.markdownEditor) ]
                , Card.view [ Card.title "Diff", Card.id "component-Diff" ] [ Diff.view DiffMsg [ Diff.locale locale, Diff.ariaLabel "Customer changes" ] model.diff (Diff.lines [] "Customer: Aurora\nStatus: Draft" "Customer: Aurora Logistics\nStatus: Ready") ]
                , Card.view [ Card.title "CodeBlock", Card.id "component-CodeBlock" ] [ CodeBlock.view [ CodeBlock.locale locale, CodeBlock.language CodeBlock.json, CodeBlock.download "payload.json" ] { id = "code", label = "Request payload", source = Encode.encode 2 (snapshot model) } ]
                , Card.view [ Card.title "Compare", Card.id "component-Compare" ] [ Compare.view [ Compare.locale locale ] { ariaLabel = "Warehouse comparison", ids = choiceIds, id = .id, header = \r -> Text.strong r.name, fields = [ Compare.text "City" .name, Compare.text "Capacity" .capacity ] } [ { id = Choice "oslo", name = "Oslo", capacity = "2,000" }, { id = Choice "bergen", name = "Bergen", capacity = "1,400" } ] ]
                ]

        "Overlays" ->
            Layout.stack [ Layout.gap 4 ]
                [ Card.view [ Card.title "Modal", Card.id "component-Modal" ] [ Button.view [ Button.id "open-modal", Button.onClick OpenModal ] "Open modal" ]
                , Card.view [ Card.title "Drawer", Card.id "component-Drawer" ] [ Button.view [ Button.id "open-drawer", Button.onClick OpenDrawer ] "Open drawer" ]
                , Card.view [ Card.title "ConfirmDialog", Card.id "component-ConfirmDialog" ] [ Button.view [ Button.id "open-confirm", Button.danger, Button.onClick OpenConfirm ] "Confirm a change" ]
                , Card.view [ Card.title "Popover", Card.id "component-Popover" ] [ Popover.view PopoverMsg [ Popover.locale locale, Popover.title "Quick actions", Popover.closeButton ] model.popover "Open popover" [ Text.paragraph "This panel uses Klar positioning.", Button.view [ Button.onClick SaveSnapshot ] "Save snapshot" ] ]
                , Card.view [ Card.title "Tooltip", Card.id "component-Tooltip" ] [ Tooltip.wrap [ Tooltip.id "tip" ] "Save this playground state to SQLite" (\attrs -> Button.view [ Button.htmlAttrs attrs, Button.onClick SaveSnapshot ] "Hover or focus me") ]
                , Card.view [ Card.title "ContextMenu", Card.id "component-ContextMenu" ] [ Layout.stack [] [ ContextMenu.area ContextMenuMsg model.contextMenu { id = "context-target", target = Choice "order" } [ Text.paragraph "Right-click here, or press the context-menu key." ], ContextMenu.view ContextMenuMsg [ ContextMenu.locale locale, ContextMenu.ariaLabel "Record actions" ] (\_ -> menuItems) model.contextMenu ] ]
                , Card.view [ Card.title "CommandPalette", Card.id "component-CommandPalette" ] [ Button.view [ Button.id "open-palette", Button.onClick OpenPalette ] "Command palette (Ctrl K)" ]
                , Card.view [ Card.title "ShortcutHelp", Card.id "component-ShortcutHelp" ] [ Button.view [ Button.id "open-help", Button.onClick OpenHelp ] "Keyboard shortcuts" ]
                , Card.view [ Card.title "Toast", Card.id "component-Toast" ] [ Button.view [ Button.onClick (Notify "A toast from the playground") ] "Show toast" ]
                ]

        "Structure" ->
            Layout.stack [ Layout.gap 4 ]
                [ Card.view [ Card.title "Breadcrumbs", Card.id "component-Breadcrumbs" ] [ Breadcrumbs.view BreadcrumbsMsg [ Breadcrumbs.locale locale, Breadcrumbs.maxItems 3, Breadcrumbs.items [ Breadcrumbs.link { label = "Home", href = "#/Foundations" }, Breadcrumbs.text "Operations", Breadcrumbs.text "Warehouses", Breadcrumbs.text "Oslo" ] ] model.breadcrumbs ]
                , Card.view [ Card.title "Tabs", Card.id "component-Tabs" ] [ Tabs.view TabsMsg [ Tabs.locale locale, Tabs.ariaLabel "Order panels", Tabs.tabs [ Tabs.tab (Choice "details") "Details" |> Tabs.withPanel (\_ -> Text.paragraph "Order details"), Tabs.tab (Choice "history") "History" |> Tabs.withPanel (\_ -> Text.paragraph "Shipment history") ] ] model.tabs ]
                , Card.view [ Card.title "Stepper", Card.id "component-Stepper" ] [ Stepper.view [ Stepper.locale locale, Stepper.current model.step, Stepper.nonLinear, Stepper.onSelect SetStep ] [ Stepper.step "Details", Stepper.step "Review", Stepper.step "Complete" ] ]
                , Card.view [ Card.title "Accordion", Card.id "component-Accordion" ] [ Accordion.view AccordionMsg [ Accordion.bordered ] model.accordion [ Accordion.section choiceIds (Choice "shipping") "Shipping" [ Text.paragraph "Delivery in two days." ], Accordion.section choiceIds (Choice "billing") "Billing" [ Text.paragraph "Invoice due in 30 days." ] ] ]
                , Card.view [ Card.title "Toolbar", Card.id "component-Toolbar" ] [ Toolbar.view [ Toolbar.ariaLabel "Document actions" ] [ Toolbar.label "Document", Toolbar.spacer, Button.view [ Button.onClick SaveSnapshot ] "Save", Toolbar.separator, Button.view [ Button.onClick Reload ] "Refresh" ] ]
                , Card.view [ Card.title "DescriptionList", Card.id "component-DescriptionList" ] [ DescriptionList.view [ DescriptionList.locale locale, DescriptionList.columns 2, DescriptionList.bordered ] [ DescriptionList.text "Customer" "Aurora Logistics", DescriptionList.text "Location" "Oslo", DescriptionList.html "Status" (Badge.status Success "Ready") ] ]
                , Card.view [ Card.title "Sortable", Card.id "component-Sortable" ] [ Sortable.view SortableMsg [ Sortable.locale locale, Sortable.ariaLabel "Dispatch priority", Sortable.moveButtons ] model.sortable (List.map (\id -> Sortable.item choiceIds id (choiceKey id) (Text.text (choiceKey id))) model.sortOrder) ]
                , Card.view [ Card.title "Splitter", Card.id "component-Splitter" ] [ Splitter.view SplitterMsg [ Splitter.locale locale, Splitter.height 180 ] model.splitter [ Splitter.pane "List" (Text.paragraph "Resize the separator with mouse or arrow keys."), Splitter.pane "Detail" (Text.paragraph "Warehouse details") ] ]
                , Card.view [ Card.title "BulkBar", Card.id "component-BulkBar" ] [ BulkBar.view [ BulkBar.locale locale ] { toolbar = Text.text "Order actions", selected = List.length model.choices, onClear = SetChoices [] } [ Button.view [ Button.onClick (Notify "Export selection") ] "Export selection" ] ]
                , Card.view [ Card.title "History", Card.id "component-History" ] [ Layout.stack [ Layout.gap 2 ] [ TextInput.view [ TextInput.label "Undoable note", TextInput.value (History.present model.history), TextInput.onInput SetHistory ], History.controls [ History.showShortcuts ] { onUndo = Undo, onRedo = Redo } model.history ] ]
                , Card.view [ Card.title "LeaveGuard", Card.id "component-LeaveGuard" ] [ Layout.stack [ Layout.gap 2 ] [ Text.paragraph "An isolated leave-draft exercise. This guard protects this simulated action.", Switch.view [ Switch.label "Mark the sample draft dirty", Switch.checked (LeaveGuard.isDirty model.guard), Switch.onCheck DirtyGuard ], Button.view [ Button.onClick TryLeave ] "Try leaving the sample draft" ] ]
                ]

        "Dashboard" ->
            Layout.stack [ Layout.gap 4 ]
                [ Card.view [ Card.title "Stat", Card.id "component-Stat" ] [ Stat.view [ Stat.locale locale, Stat.id "orders-stat", Stat.label "Orders in SQLite", Stat.remote model.orders (\rows -> [ Stat.int (List.length rows) ]), Stat.onRetry RetryStat, Stat.delta 12.5, Stat.trend [ 4, 6, 5, 8, 12 ] ] ]
                , Card.view [ Card.title "Chart", Card.id "component-Chart" ] [ Layout.grid [ Layout.minColumn 300, Layout.gap 4 ] [ Chart.line [ Chart.locale locale, Chart.title "Weekly orders", Chart.categories [ "Mon", "Tue", "Wed", "Thu", "Fri" ], Chart.area ] [ Chart.series "Orders" [ 12, 18, 13, 24, 32 ] ], Chart.bar [ Chart.locale locale, Chart.title "Warehouse stock" ] [ Chart.series "Stock" [ 40, 60, 30 ] ], Chart.donut [ Chart.locale locale, Chart.title "Order status" ] [ Chart.segment "Ready" 64, Chart.segment "Pending" 36 ], Chart.gauge [ Chart.locale locale, Chart.title "Capacity" ] model.slider, Chart.meter [ Chart.locale locale, Chart.title "Fulfilment" ] model.slider, Chart.sparkline [ Chart.locale locale, Chart.ariaLabel "Trend" ] [ 3, 5, 4, 7, 9 ] ] ]
                , Card.view [ Card.title "Timeline", Card.id "component-Timeline" ] [ Timeline.view [ Timeline.locale locale, Timeline.settings model.settings, Timeline.ariaLabel "Dispatch history" ] [ Timeline.dayEvent "created" sampleDate "Order created" |> Timeline.withAuthor "Alex Morgan", Timeline.dayEvent "approved" (Date.addDays 1 sampleDate) "Approved" |> Timeline.withTone Success ] ]
                , Card.view [ Card.title "Avatar", Card.id "component-Avatar" ] [ Avatar.group [ Avatar.locale locale, Avatar.maxShown 3 ] (List.map Avatar.entry [ "Alex Morgan", "Sam Rivera", "Taylor Chen", "Jordan Lee" ]) ]
                , Card.view [ Card.title "RemoteView", Card.id "component-RemoteView" ] [ Layout.stack [] (RemoteView.view [ RemoteView.locale locale, RemoteView.id "remote-view", RemoteView.onRetry RetryRemoteView ] model.orders (\rows -> [ Text.paragraph (String.fromInt (List.length rows) ++ " orders received from Go / SQLite.") ])) ]
                ]

        "Icons" ->
            Layout.stack [ Layout.gap 4 ] [ Card.view [ Card.title "Icons", Card.id "component-Icons" ] [ Layout.stack [ Layout.gap 4 ] (List.map (\group -> Card.view [ Card.title group.title, Card.subtitle group.moduleName ] [ Layout.row [ Layout.gap 4, Layout.wrap ] (List.map (\icon -> Tooltip.wrap [] (Icon.name icon) (\attrs -> Button.iconOnly [ Button.htmlAttrs attrs, Button.onClick (Notify (Icon.name icon)) ] icon (Icon.name icon))) (Search.filter Icon.name (SearchInput.committed model.searchInput) group.icons)) ]) IconLibrary.groups) ] ]

        "Collaboration" ->
            Layout.stack [ Layout.gap 4 ]
                [ Card.view [ Card.title "Kanban", Card.id "component-Kanban" ] [ Kanban.view KanbanMsg [ Kanban.locale locale, Kanban.onOpen (choiceKey >> Notify) ] { label = "Dispatch board", columns = Loaded model.board, columnIds = choiceIds, cardIds = choiceIds, cardId = .id, title = .name, content = \c -> Text.secondary c.description } model.kanban ]
                , Card.view [ Card.title "NotificationCenter", Card.id "component-NotificationCenter" ] [ NotificationCenter.view [ NotificationCenter.locale locale, NotificationCenter.id "notifications", NotificationCenter.settings model.settings, NotificationCenter.onRead (SetRead True), NotificationCenter.onDismiss DismissNotification, NotificationCenter.onOpen (choiceKey >> Notify), NotificationCenter.onReadAll (\_ -> ReadAll) ] { label = "Notification history", ids = choiceIds, items = Loaded (List.map (\n -> NotificationCenter.notification { id = n.id, title = n.title, body = n.body, at = Time.millisToPosix 0, unread = n.unread }) model.notifications) } ]
                , Card.view [ Card.title "AuditLog", Card.id "component-AuditLog" ] [ Layout.stack [ Layout.gap 2 ] [ Button.view [ Button.onClick LoadAudit ] "Load server audit trail", AuditLog.view [ AuditLog.locale locale, AuditLog.id "audit", AuditLog.onRetry LoadAudit ] { label = "Server events", ids = choiceIds, entries = Remote.map (List.map (\e -> AuditLog.entry { id = Choice e.id, actor = "Playground user", action = e.action, at = Time.millisToPosix e.at })) model.audit } ] ]
                , Card.view [ Card.title "ConflictResolver", Card.id "component-ConflictResolver" ] [ ConflictResolver.view ConflictResolverMsg [ ConflictResolver.locale locale, ConflictResolver.onApply ApplyMerge ] { label = "Concurrent customer edit", ids = choiceIds, fields = Loaded [ ConflictResolver.field (Choice "name") "Customer name" { base = Just "Aurora", yours = Just "Aurora Logistics", theirs = Just "Aurora Ltd" }, ConflictResolver.field (Choice "city") "City" { base = Just "Oslo", yours = Just "Bergen", theirs = Just "Trondheim" } ] } model.conflictResolver ]
                , Card.view [ Card.title "CommentThread", Card.id "component-CommentThread" ] [ CommentThread.view CommentThreadMsg [ CommentThread.locale locale, CommentThread.onSubmit PostComment, CommentThread.sending model.commentSending, CommentThread.errorMaybe model.commentError ] { label = "Dispatch discussion", ids = choiceIds, comments = Loaded model.comments } model.commentThread ]
                ]

        "Access" ->
            Layout.stack [ Layout.gap 4 ]
                [ Card.view [ Card.title "PermissionMatrix", Card.id "component-PermissionMatrix" ] [ PermissionMatrix.view PermissionMatrixMsg [ PermissionMatrix.locale locale, PermissionMatrix.ariaLabel "Role access", PermissionMatrix.onChange SetPermissions ] model.permissionMatrix (permissionData model.grants) ]
                , Card.view [ Card.title "ApprovalFlow", Card.id "component-ApprovalFlow" ] [ ApprovalFlow.view Avatar.entry [ ApprovalFlow.locale locale, ApprovalFlow.id "approval", ApprovalFlow.viewer (Just "Alex Morgan"), ApprovalFlow.onApprove (DecideApproval True), ApprovalFlow.onReject (DecideApproval False) ] (ApprovalFlow.flow [ ApprovalFlow.step "Dispatch approval" ApprovalFlow.all (ApprovalFlow.approver "Alex Morgan" model.approval) [] ]) ]
                ]

        "AI" ->
            Layout.stack [ Layout.gap 4 ]
                [ Card.view [ Card.title "AiReview", Card.id "component-AiReview" ] [ Layout.stack [ Layout.gap 2 ] [ Alert.view [ Alert.tone Warning ] "Fixture proposal: review decisions are persisted as a demo record; no order is modified.", AiReview.view AiReviewMsg [ AiReview.locale locale, AiReview.onSubmit SubmitReview, AiReview.saving model.reviewSaving, AiReview.errorMaybe model.reviewError ] { label = "Review a suggested customer correction", ids = choiceIds, proposals = Loaded proposals } model.aiReview ] ]
                , Card.view [ Card.title "AiChat", Card.id "component-AiChat" ]
                    [ Layout.stack [ Layout.gap 2 ]
                        [ Alert.view [ Alert.tone Info ] "Deterministic Go simulator. No AI provider or API key is connected."
                        , AiChat.view AiChatMsg
                            [ AiChat.locale locale, AiChat.onSend SendChat, AiChat.onStop StopChat, AiChat.onRetry RetryChat ]
                            { label = "Operations assistant simulator"
                            , ids = choiceIds
                            , messages =
                                Loaded
                                    (List.map
                                        (\m ->
                                            AiChat.message
                                                { id = Choice m.id
                                                , role =
                                                    if m.role == "user" then
                                                        AiChat.User

                                                    else
                                                        AiChat.Assistant
                                                , author =
                                                    if m.role == "user" then
                                                        "You"

                                                    else
                                                        "Simulator"
                                                , body = m.body
                                                }
                                        )
                                        model.chatMessages
                                    )
                            , status = model.chatStatus
                            }
                            model.aiChat
                        ]
                    ]
                ]

        "Files" ->
            Layout.stack [ Layout.gap 4 ] [ Card.view [ Card.title "UploadQueue", Card.id "component-UploadQueue" ] [ UploadQueue.view UploadQueueMsg [ UploadQueue.locale locale, UploadQueue.maxSize 5242880, UploadQueue.onStart StartUpload, UploadQueue.onRetry StartUpload, UploadQueue.onStartAll StartUploads, UploadQueue.onCancel CancelUpload, UploadQueue.onRemove RemoveUpload ] { label = "Files stored in SQLite", ids = choiceIds, uploads = List.map (\u -> UploadQueue.upload { id = u.id, file = { name = File.name u.file, size = File.size u.file, mime = File.mime u.file } } |> UploadQueue.withStatus u.status) model.uploads, onAdd = AddUploads } model.uploadQueue ] ]

        "Rules" ->
            Layout.stack [ Layout.gap 4 ]
                [ Card.view [ Card.title "RuleBuilder", Card.id "component-RuleBuilder" ] [ Layout.stack [ Layout.gap 2 ] [ RuleBuilder.view RuleBuilderMsg [ RuleBuilder.locale locale, RuleBuilder.fields orderFields, RuleBuilder.today sampleDate, RuleBuilder.json, RuleBuilder.importJson ] model.ruleBuilder, Text.paragraph (Rule.describe locale orderFields (RuleBuilder.rule model.ruleBuilder)), Text.paragraph (String.fromInt (List.length (List.filter (Rule.matches sampleDate orderFields (RuleBuilder.rule model.ruleBuilder)) (Remote.withDefault [] model.orders))) ++ " matching loaded orders") ] ]
                , Card.view [ Card.title "FilterBar", Card.id "component-FilterBar" ] [ Layout.stack [ Layout.gap 2 ] [ FilterBar.view FilterBarMsg [ FilterBar.locale locale, FilterBar.fields orderFields, FilterBar.today sampleDate ] model.filterBar, Text.paragraph (Rule.describe locale orderFields (FilterBar.rule model.filterBar)) ] ]
                , Card.view [ Card.title "SavedViews", Card.id "component-SavedViews" ] [ SavedViews.view SavedViewsMsg [ SavedViews.locale locale, SavedViews.currentRule (RuleBuilder.rule model.ruleBuilder) ] model.savedViews ]
                , Card.view [ Card.title "ServerList", Card.id "component-ServerList" ] [ Layout.stack [ Layout.gap 3 ] [ ServerList.viewSavedViews ServerMsg [] model.serverList, ServerList.viewFilterBar ServerMsg [ FilterBar.fields orderFields, FilterBar.today sampleDate ] model.serverList, ServerList.viewTable ServerMsg [ Table.ariaLabel "Server-side orders", Table.columns [ Table.text (Table.columnId "id") "Order" (\r -> recordKey r.id) [], Table.text (Table.columnId "customer") "Customer" .customer [ Table.filterText ], Table.int (Table.columnId "total") "Minor units" .total [] ], Table.rowId recordIds .id, Table.searchable, Table.selectable ] model.serverList ] ]
                ]

        "Forms" ->
            Layout.stack [ Layout.gap 4 ]
                [ Card.view [ Card.title "Form", Card.id "component-Form" ]
                    [ let
                        bound =
                            Form.bind locale FormMsg customerForm model.form

                        fields =
                            Form.fields customerForm
                      in
                      FormLayout.view [ FormLayout.onSubmit SubmitForm ] [ Text.paragraph "Use taken@example.com for field rejection, or name Crash for a server failure.", Form.summary bound, FormLayout.grid 2 [ Form.textInput bound fields.name [], Form.textInput bound fields.email [], Form.select bound fields.warehouse (Loaded choices) [], Form.moneyInput bound fields.credit [], Form.checkbox bound fields.active [] ], FormLayout.unsavedChanges [] (Form.isDirty model.form), Submission.view [ FormLayout.onRetry SubmitForm ] (Form.submission model.form), FormLayout.actions [ Button.view [ Button.submit, Button.primary ] "Save customer", Button.view [ Button.onClick ResetForm ] "Discard changes" ], Text.caption ("Hidden-field check: " ++ String.fromInt (List.length (FormCheck.failingWhenHidden customerForm)) ++ " issues") ]
                    ]
                , Card.view [ Card.title "Field", Card.id "component-Field" ]
                    [ let
                        config =
                            Field.empty |> Field.setId "wrapped-control" |> Field.setLabel "Custom labelled value" |> Field.setHint "Example wrapper for a semantic output"
                      in
                      Field.view config (Html.output (Field.controlAttributes config) [ Text.text model.text ])
                    ]
                , Card.view [ Card.title "Validate", Card.id "component-Validate" ] [ TextInput.view [ TextInput.label "Email validation", TextInput.value model.email, TextInput.onInput SetEmail, TextInput.errorMaybe (Validate.firstError locale [ Validate.required, Validate.email ] model.email) ] ]
                ]

        "Processes" ->
            Layout.stack [ Layout.gap 4 ]
                [ Card.view [ Card.title "WorkflowBuilder", Card.id "component-WorkflowBuilder" ] [ WorkflowBuilder.view choiceIds [ WorkflowBuilder.selected model.selectedNode, WorkflowBuilder.onSelect SelectNode, WorkflowBuilder.onAdd AddWorkflowNode, WorkflowBuilder.onChange ChangeWorkflow ] model.workflow ]
                , Card.view [ Card.title "WorkflowNode", Card.id "component-WorkflowNode" ] [ Layout.row [ Layout.gap 3, Layout.wrap ] (List.map (\node -> WorkflowNode.view [ WorkflowNode.locale locale, WorkflowNode.onSelect (SelectNode node.id), WorkflowNode.selected (model.selectedNode == Just node.id) ] node) model.workflow.nodes) ]
                , Card.view [ Card.title "WorkflowRun", Card.id "component-WorkflowRun" ]
                    [ Layout.stack [ Layout.gap 3 ]
                        [ Layout.row [ Layout.gap 2, Layout.wrap ] [ Button.view [ Button.onClick StartWorkflow ] "Start run", Button.view [ Button.onClick CompleteNode, Button.disabled (model.run == Nothing) ] "Complete current node", Button.view [ Button.onClick PauseRun ] "Pause", Button.view [ Button.onClick ResumeRun ] "Resume", Button.view [ Button.onClick CancelRun ] "Cancel", Button.view [ Button.onClick SaveWorkflow ] "Save definition" ]
                        , case model.run of
                            Just run ->
                                WorkflowRun.view [ WorkflowRun.locale locale, WorkflowRun.onSelect SelectNode ] run

                            Nothing ->
                                Text.paragraph "Start a run to inspect its active node."
                        ]
                    ]
                , Card.view [ Card.title "StateMachine", Card.id "component-StateMachine" ] [ StateMachine.view [ StateMachine.locale locale, StateMachine.onTransition TransitionState ] model.machine ]
                ]

        _ ->
            Text.paragraph "Choose a section."


type alias BoardCard =
    { id : Choice, name : String, description : String }


type alias Notice =
    { id : Choice, title : String, body : String, unread : Bool }


type alias AuditEntry =
    { id : String, action : String, at : Int }


type alias ChatEntry =
    { id : String, role : String, body : String }


type alias UploadEntry =
    { id : Choice, file : File.File, status : UploadQueue.Status, ticket : Int }


encodeNotice n =
    Encode.object [ ( "id", Encode.string (choiceKey n.id) ), ( "title", Encode.string n.title ), ( "body", Encode.string n.body ), ( "unread", Encode.bool n.unread ) ]


encodeColumn c =
    Encode.list (\card -> Encode.object [ ( "id", Encode.string (choiceKey card.id) ), ( "name", Encode.string card.name ), ( "description", Encode.string card.description ) ]) (Kanban.cards c)


permissionData grants =
    PermissionMatrix.matrix { roles = [ PermissionMatrix.role "admin" "Administrator", PermissionMatrix.role "viewer" "Viewer" ], roleKey = identity, permissions = [ PermissionMatrix.permission "read" "Read orders", PermissionMatrix.permission "write" "Edit orders" ], permissionKey = identity, cell = \role permission -> PermissionMatrix.direct (PermissionMatrix.fromBool (List.member ( role, permission ) grants)) }


proposals =
    [ AiReview.proposal { id = Choice "customer-name", revision = "1", title = "Normalize customer name", before = "Aurora", after = "Aurora Logistics", rationale = "The shipping record uses the full legal name.", sources = [ AiReview.source { label = "Fixture record", url = "#/Data", excerpt = "Customer: Aurora Logistics" } ] } ]


startChat isRetry prompt pending model =
    let
        ticket =
            model.chatTicket + 1

        suffix =
            String.fromInt ticket

        messages =
            if not isRetry then
                model.chatMessages ++ [ { id = "user-" ++ suffix, role = "user", body = prompt } ]

            else
                model.chatMessages
    in
    ( { model | chatTicket = ticket, chatPending = pending, chatPrompt = prompt, chatStatus = AiChat.Generating, chatMessages = messages ++ [ { id = "assistant-" ++ suffix, role = "assistant", body = "" } ] }, request ("chat:" ++ suffix) "POST" "/api/chat" (Encode.object [ ( "text", Encode.string prompt ), ( "retry", Encode.bool isRetry ) ]) )


orderDecoder =
    Decode.map3 Order (Decode.field "id" (Decode.map RecordId Decode.string)) (Decode.field "customer" Decode.string) (Decode.field "total" Decode.int)


chatDecoder =
    Decode.map3 ChatEntry (Decode.field "id" Decode.string) (Decode.field "role" Decode.string) (Decode.field "body" Decode.string)


noticeDecoder =
    Decode.map4 Notice (Decode.field "id" (Decode.map Choice Decode.string)) (Decode.field "title" Decode.string) (Decode.field "body" Decode.string) (Decode.field "unread" Decode.bool)


boardCardDecoder =
    Decode.map3 BoardCard (Decode.field "id" (Decode.map Choice Decode.string)) (Decode.field "name" Decode.string) (Decode.field "description" Decode.string)


commentDecoder =
    Decode.map5
        (\id author body at parent ->
            let
                comment =
                    CommentThread.comment { id = Choice id, author = author, body = body, at = Time.millisToPosix at }
            in
            Maybe.map (\p -> CommentThread.replyTo (Choice p) comment) parent |> Maybe.withDefault comment
        )
        (Decode.field "id" Decode.string)
        (Decode.field "author" Decode.string)
        (Decode.field "body" Decode.string)
        (Decode.field "at" Decode.int)
        (Decode.field "parent" (Decode.nullable Decode.string))


orderFields =
    [ Rule.textField "customer" "Customer" .customer |> Rule.withOperators [ Rule.Is, Rule.IsNot, Rule.Contains, Rule.NotContains, Rule.StartsWith, Rule.EndsWith, Rule.IsEmpty, Rule.IsNotEmpty ], Rule.numberField "total" "Total (minor units)" (.total >> toFloat >> Just) |> Rule.withOperators [ Rule.Is, Rule.IsNot, Rule.LessThan, Rule.LessOrEqual, Rule.GreaterThan, Rule.GreaterOrEqual, Rule.Between, Rule.NotBetween ] ]


followServer model step =
    let
        counter =
            model.serverCounter + 1

        key =
            "server:" ++ String.fromInt counter

        pending =
            Maybe.map (\r -> Dict.insert key r model.serverPending) step.request |> Maybe.withDefault model.serverPending
    in
    ( { model | serverList = step.state, serverCounter = counter, serverPending = pending }, Cmd.batch [ Cmd.map ServerMsg step.cmd, Maybe.map (\r -> request key "POST" "/api/orders/query" (encodeServerQuery r)) step.request |> Maybe.withDefault Cmd.none, Maybe.map (\views -> request "server-views" "PUT" "/api/documents/server-views" (Encode.list SavedViews.encode views)) step.save |> Maybe.withDefault Cmd.none ] )


encodeServerQuery r =
    Encode.object
        [ ( "search", Encode.string r.query.search )
        , ( "page", Encode.int r.query.page )
        , ( "pageSize", Encode.int r.query.pageSize )
        , ( "sort", Encode.list (\( column, direction ) -> Encode.object [ ( "field", Encode.string (Table.columnName column) ), ( "descending", Encode.bool (direction == Table.Descending) ) ]) r.query.sort )
        , ( "filters"
          , Encode.list
                (\( column, filter ) ->
                    Encode.object
                        [ ( "field", Encode.string (Table.columnName column) )
                        , ( "contains"
                          , Encode.string
                                (case filter of
                                    Table.Contains text ->
                                        text

                                    _ ->
                                        ""
                                )
                          )
                        ]
                )
                r.query.filters
          )
        , ( "rule", encodeServerRule r.rule )
        ]


encodeServerRule rule =
    case rule of
        Rule.GroupRule group ->
            Encode.object
                [ ( "combinator"
                  , Encode.string
                        (if group.combinator == Rule.All then
                            "all"

                         else
                            "any"
                        )
                  )
                , ( "negated", Encode.bool group.negated )
                , ( "children", Encode.list encodeServerRule group.children )
                ]

        Rule.ConditionRule c ->
            Encode.object [ ( "field", Encode.string c.field ), ( "operator", Encode.string (operatorKey c.operator) ), ( "values", Encode.list Encode.string c.values ) ]


operatorKey operator =
    case operator of
        Rule.Is ->
            "is"

        Rule.IsNot ->
            "isNot"

        Rule.Contains ->
            "contains"

        Rule.NotContains ->
            "notContains"

        Rule.StartsWith ->
            "starts"

        Rule.EndsWith ->
            "ends"

        Rule.GreaterThan ->
            "greater"

        Rule.GreaterOrEqual ->
            "atLeast"

        Rule.LessThan ->
            "less"

        Rule.LessOrEqual ->
            "atMost"

        Rule.Between ->
            "between"

        Rule.NotBetween ->
            "notBetween"

        Rule.IsEmpty ->
            "empty"

        Rule.IsNotEmpty ->
            "notEmpty"

        _ ->
            "unsupported"


type alias CustomerFields =
    { name : Form.Field String, email : Form.Field String, warehouse : Form.Field (Maybe Choice), credit : Form.Field (Maybe Money.Money), active : Form.Field Bool }


type alias Customer =
    { name : String, email : String, warehouse : Choice, credit : Maybe Money.Money, active : Bool }


customerForm : Form.Form () CustomerFields Customer
customerForm =
    Spec.define "customer-form" CustomerFields Customer |> Spec.with (Spec.text "Name" |> Spec.required) |> Spec.with (Spec.text "Email" |> Spec.required |> Spec.rules [ Validate.email ] |> Spec.serverKey "email_address") |> Spec.with (Spec.choice choiceIds "Warehouse" |> Spec.required) |> Spec.with (Spec.money Money.nok "Credit limit") |> Spec.with (Spec.toggle "Active") |> Spec.build


initialWorkflow : Workflow.Definition Choice
initialWorkflow =
    { title = "Dispatch process", ownerRole = "operator", nodes = [ Workflow.node (Choice "input") Workflow.input "Receive order", Workflow.node (Choice "check") Workflow.human "Check dispatch", Workflow.node (Choice "output") Workflow.output "Order dispatched" ], edges = [ Workflow.edge (Choice "input") (Choice "check") "Continue", Workflow.edge (Choice "check") (Choice "output") "Continue" ] }


initialMachine : StateMachine.Machine Choice
initialMachine =
    { current = Choice "draft", states = [ { id = Choice "draft", label = "Draft", terminal = False }, { id = Choice "ready", label = "Ready", terminal = False }, { id = Choice "done", label = "Done", terminal = True } ], transitions = [ { from = Choice "draft", to = Choice "ready", event = "Prepare" }, { from = Choice "ready", to = Choice "done", event = "Dispatch" } ] }
