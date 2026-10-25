function scenarios({add,state,extraImports}) {
  for(const i of ['Klar.Form.Spec as Spec','Klar.Form.Layout as FormLayout','Klar.Form.Submission as Submission','Klar.Form.Check as FormCheck','Klar.Validate as Validate','Klar.Rule as Rule','Klar.Workflow as Workflow','Klar.Workflow.Engine as Engine','Klar.Workflow.Codec as WorkflowCodec','Klar.Recurrence as Recurrence','Klar.Search as Search','Klar.Field as Field']) extraImports.add(i);
  add('Icons','Icons','Layout.stack [ Layout.gap 4 ] (List.map (\\group -> Card.view [ Card.title group.title, Card.subtitle group.moduleName ] [ Layout.row [ Layout.gap 4, Layout.wrap ] (List.map (\\icon -> Tooltip.wrap [] (Icon.name icon) (\\attrs -> Button.iconOnly [ Button.htmlAttrs attrs, Button.onClick (Notify (Icon.name icon)) ] icon (Icon.name icon))) (Search.filter Icon.name (SearchInput.committed model.searchInput) group.icons)) ]) IconLibrary.groups)');
  state('Budget','Data','Budget.State','Budget.init "budget" Money.nok |> Budget.setColumns [ Budget.textColumn "item" "Item", Budget.numberColumn "quantity" "Quantity", Budget.moneyColumn "price" "Price" ] |> Budget.setFormula (Budget.multiply "quantity" (Budget.amount "price")) |> Budget.setRows [ Budget.row [ ( "item", "Packaging" ), ( "quantity", "4" ), ( "price", "125.50" ) ] ]','Layout.stack [ Layout.gap 2 ] [ Budget.view BudgetMsg [ Budget.title "Dispatch budget", Budget.locale locale ] model.budget, Button.view [ Button.onClick SaveBudget ] "Save budget to SQLite" ]');
  add('CardList','Data','CardList.view [ CardList.id "card-list", CardList.onOpen (recordKey >> Notify), CardList.onRetry RetryCards ] { label = "Sample order cards (first six)", items = Remote.map (List.take 6) model.orders, ids = recordIds, id = .id, title = .customer, fields = [ CardList.field "Order" (\\r -> Text.mono (recordKey r.id)), CardList.field "Total" (\\r -> Text.text (Money.toString locale (money r.total))) ] }');
  state('WorkQueue','Data','WorkQueue.State','WorkQueue.init "work-queue"','WorkQueue.view WorkQueueMsg [ WorkQueue.searchable, WorkQueue.onRetry RetryWorkQueue ] { label = "Orders to review", items = model.orders, ids = recordIds, id = .id, title = .customer, summary = (\\r -> recordKey r.id), detail = (\\r -> DescriptionList.view [] [ DescriptionList.text "Customer" r.customer, DescriptionList.text "Order" (recordKey r.id) ]) } model.workQueue');
  state('Kanban','Collaboration','Kanban.State','Kanban.init "kanban"','Kanban.view KanbanMsg [ Kanban.onOpen (choiceKey >> Notify) ] { label = "Dispatch board", columns = Loaded model.board, columnIds = choiceIds, cardIds = choiceIds, cardId = .id, title = .name, content = (\\c -> Text.secondary c.description) } model.kanban',`let
    ( next, cmd ) = Kanban.update inner model.kanban
    moved = Kanban.move choiceIds choiceIds model.kanban next
    result = Maybe.map (\\move -> Kanban.applyMove choiceIds choiceIds .id move model.board) moved
in
case result of
    Just (Ok board) -> ( { model | kanban = next, board = board }, Cmd.batch [ Cmd.map KanbanMsg cmd, request "board" "PUT" "/api/documents/board" (Encode.list encodeColumn board) ] )
    Just (Err problem) -> update (Notify (Kanban.problemText (Settings.locale model.settings) problem)) { model | kanban = next }
    Nothing -> ( { model | kanban = next }, Cmd.map KanbanMsg cmd )`);
  add('NotificationCenter','Collaboration','NotificationCenter.view [ NotificationCenter.id "notifications", NotificationCenter.settings model.settings, NotificationCenter.onRead (SetRead True), NotificationCenter.onDismiss DismissNotification, NotificationCenter.onOpen (choiceKey >> Notify), NotificationCenter.onReadAll (\\_ -> ReadAll) ] { label = "Notification history", ids = choiceIds, items = Loaded (List.map (\\n -> NotificationCenter.notification { id = n.id, title = n.title, body = n.body, at = Time.millisToPosix 0, unread = n.unread }) model.notifications) }');
  add('AuditLog','Collaboration','Layout.stack [ Layout.gap 2 ] [ Button.view [ Button.onClick LoadAudit ] "Load server audit trail", AuditLog.view [ AuditLog.id "audit", AuditLog.onRetry LoadAudit ] { label = "Server events", ids = choiceIds, entries = Remote.map (List.map (\\e -> AuditLog.entry { id = Choice e.id, actor = "Playground user", action = e.action, at = Time.millisToPosix e.at })) model.audit } ]');
  state('ConflictResolver','Collaboration','ConflictResolver.State','ConflictResolver.init "conflicts"','ConflictResolver.view ConflictResolverMsg [ ConflictResolver.onApply ApplyMerge ] { label = "Concurrent customer edit", ids = choiceIds, fields = Loaded [ ConflictResolver.field (Choice "name") "Customer name" { base = Just "Aurora", yours = Just "Aurora Logistics", theirs = Just "Aurora Ltd" }, ConflictResolver.field (Choice "city") "City" { base = Just "Oslo", yours = Just "Bergen", theirs = Just "Trondheim" } ] } model.conflictResolver');
  state('CommentThread','Collaboration','CommentThread.State','CommentThread.init "comments"','CommentThread.view CommentThreadMsg [ CommentThread.onSubmit PostComment, CommentThread.sending model.commentSending, CommentThread.errorMaybe model.commentError ] { label = "Dispatch discussion", ids = choiceIds, comments = Loaded model.comments } model.commentThread');
  state('PermissionMatrix','Access','PermissionMatrix.State','PermissionMatrix.init "permissions"','PermissionMatrix.view PermissionMatrixMsg [ PermissionMatrix.ariaLabel "Role access", PermissionMatrix.onChange SetPermissions ] model.permissionMatrix (permissionData model.grants)');
  add('ApprovalFlow','Access','ApprovalFlow.view Avatar.entry [ ApprovalFlow.id "approval", ApprovalFlow.viewer (Just "Alex Morgan"), ApprovalFlow.onApprove (DecideApproval True), ApprovalFlow.onReject (DecideApproval False) ] (ApprovalFlow.flow [ ApprovalFlow.step "Dispatch approval" ApprovalFlow.all (ApprovalFlow.approver "Alex Morgan" model.approval) [] ])');
  state('AiReview','AI','AiReview.State','AiReview.init "ai-review"','Layout.stack [ Layout.gap 2 ] [ Alert.view [ Alert.tone Warning ] "Fixture proposal: review decisions are persisted as a demo record; no order is modified.", AiReview.view AiReviewMsg [ AiReview.onSubmit SubmitReview, AiReview.saving model.reviewSaving, AiReview.errorMaybe model.reviewError ] { label = "Review a suggested customer correction", ids = choiceIds, proposals = Loaded proposals } model.aiReview ]');
  state('AiChat','AI','AiChat.State','AiChat.init "ai-chat"','Layout.stack [ Layout.gap 2 ] [ Alert.view [ Alert.tone Info ] "Deterministic Go simulator. No AI provider or API key is connected.", AiChat.view AiChatMsg [ AiChat.onSend SendChat, AiChat.onStop StopChat, AiChat.onRetry RetryChat ] { label = "Operations assistant simulator", ids = choiceIds, messages = Loaded (List.map (\\m -> AiChat.message { id = Choice m.id, role = if m.role == "user" then AiChat.User else AiChat.Assistant, author = if m.role == "user" then "You" else "Simulator", body = m.body }) model.chatMessages), status = model.chatStatus } model.aiChat ]');
  state('UploadQueue','Files','UploadQueue.State','UploadQueue.init "upload-queue"','UploadQueue.view UploadQueueMsg [ UploadQueue.maxSize 5242880, UploadQueue.onStart StartUpload, UploadQueue.onRetry StartUpload, UploadQueue.onStartAll StartUploads, UploadQueue.onCancel CancelUpload, UploadQueue.onRemove RemoveUpload ] { label = "Files stored in SQLite", ids = choiceIds, uploads = List.map (\\u -> UploadQueue.upload { id = u.id, file = { name = File.name u.file, size = File.size u.file, mime = File.mime u.file } } |> UploadQueue.withStatus u.status) model.uploads, onAdd = AddUploads } model.uploadQueue');
  state('RuleBuilder','Rules','RuleBuilder.State','RuleBuilder.init "rules" |> RuleBuilder.setRule (Rule.allOf [ Rule.when "total" Rule.GreaterOrEqual [ "50000" ] ])','Layout.stack [ Layout.gap 2 ] [ RuleBuilder.view RuleBuilderMsg [ RuleBuilder.fields orderFields, RuleBuilder.today sampleDate, RuleBuilder.json, RuleBuilder.importJson ] model.ruleBuilder, Text.paragraph (Rule.describe locale orderFields (RuleBuilder.rule model.ruleBuilder)), Text.paragraph (String.fromInt (List.length (List.filter (Rule.matches sampleDate orderFields (RuleBuilder.rule model.ruleBuilder)) (Remote.withDefault [] model.orders))) ++ " matching loaded orders") ]');
  state('FilterBar','Rules','FilterBar.State','FilterBar.init "filter-bar"','Layout.stack [ Layout.gap 2 ] [ FilterBar.view FilterBarMsg [ FilterBar.fields orderFields, FilterBar.today sampleDate ] model.filterBar, Text.paragraph (Rule.describe locale orderFields (FilterBar.rule model.filterBar)) ]');
  state('SavedViews','Rules','SavedViews.State','SavedViews.init "saved-views" |> SavedViews.setViews [ SavedViews.savedView "Large orders" (Rule.allOf [ Rule.when "total" Rule.GreaterOrEqual [ "50000" ] ]) ]','SavedViews.view SavedViewsMsg [ SavedViews.currentRule (RuleBuilder.rule model.ruleBuilder) ] model.savedViews',`let
    ( next, cmd ) = SavedViews.update inner model.savedViews
    changed = SavedViews.views next /= SavedViews.views model.savedViews
    activeRule = SavedViews.active next |> Maybe.map .rule |> Maybe.withDefault (RuleBuilder.rule model.ruleBuilder)
in
( { model | savedViews = next, ruleBuilder = RuleBuilder.setRule activeRule model.ruleBuilder }, Cmd.batch [ Cmd.map SavedViewsMsg cmd, if changed then request "views" "PUT" "/api/documents/views" (Encode.list SavedViews.encode (SavedViews.views next)) else Cmd.none ] )`);
  add('ServerList','Rules','Layout.stack [ Layout.gap 3 ] [ ServerList.viewSavedViews ServerMsg [] model.serverList, ServerList.viewFilterBar ServerMsg [ FilterBar.fields orderFields, FilterBar.today sampleDate ] model.serverList, ServerList.viewTable ServerMsg [ Table.ariaLabel "Server-side orders", Table.columns [ Table.text (Table.columnId "id") "Order" (\\r -> recordKey r.id) [], Table.text (Table.columnId "customer") "Customer" .customer [ Table.filterText ], Table.int (Table.columnId "total") "Minor units" .total [] ], Table.rowId recordIds .id, Table.searchable, Table.selectable ] model.serverList ]');
  add('Form','Forms',`let
      bound = Form.bind locale FormMsg customerForm model.form
      fields = Form.fields customerForm
  in
  FormLayout.view [ FormLayout.onSubmit SubmitForm ] [ Text.paragraph "Use taken@example.com for field rejection, or name Crash for a server failure.", Form.summary bound, FormLayout.grid 2 [ Form.textInput bound fields.name [], Form.textInput bound fields.email [], Form.select bound fields.warehouse (Loaded choices) [], Form.moneyInput bound fields.credit [], Form.checkbox bound fields.active [] ], FormLayout.unsavedChanges [] (Form.isDirty model.form), Submission.view [ FormLayout.onRetry SubmitForm ] (Form.submission model.form), FormLayout.actions [ Button.view [ Button.submit, Button.primary ] "Save customer", Button.view [ Button.onClick ResetForm ] "Discard changes" ], Text.caption ("Hidden-field check: " ++ String.fromInt (List.length (FormCheck.failingWhenHidden customerForm)) ++ " issues") ]`);
  add('Field','Forms','let config = Field.empty |> Field.setId "wrapped-control" |> Field.setLabel "Custom labelled value" |> Field.setHint "Example wrapper for a semantic output" in Field.view config (Html.output (Field.controlAttributes config) [ Text.text model.text ])');
  add('Validate','Forms','TextInput.view [ TextInput.label "Email validation", TextInput.value model.email, TextInput.onInput SetEmail, TextInput.errorMaybe (Validate.firstError locale [ Validate.required, Validate.email ] model.email) ]');
  add('Recurrence','Dates','Text.paragraph (RecurrencePicker.value model.recurrencePicker |> Maybe.map (\\rule -> Recurrence.describe locale rule ++ " · " ++ Recurrence.toRRule rule) |> Maybe.withDefault "Choose a recurrence above to inspect its description and RFC rule.")');
  add('LeaveGuard','Structure','Layout.stack [ Layout.gap 2 ] [ Text.paragraph "An isolated leave-draft exercise. This guard protects this simulated action.", Switch.view [ Switch.label "Mark the sample draft dirty", Switch.checked (LeaveGuard.isDirty model.guard), Switch.onCheck DirtyGuard ], Button.view [ Button.onClick TryLeave ] "Try leaving the sample draft" ]');
  add('WorkflowBuilder','Processes','WorkflowBuilder.view choiceIds [ WorkflowBuilder.selected model.selectedNode, WorkflowBuilder.onSelect SelectNode, WorkflowBuilder.onAdd AddWorkflowNode, WorkflowBuilder.onChange ChangeWorkflow ] model.workflow');
  add('WorkflowNode','Processes','Layout.row [ Layout.gap 3, Layout.wrap ] (List.map (\\node -> WorkflowNode.view [ WorkflowNode.onSelect (SelectNode node.id), WorkflowNode.selected (model.selectedNode == Just node.id) ] node) model.workflow.nodes)');
  add('WorkflowRun','Processes','Layout.stack [ Layout.gap 3 ] [ Layout.row [ Layout.gap 2, Layout.wrap ] [ Button.view [ Button.onClick StartWorkflow ] "Start run", Button.view [ Button.onClick CompleteNode, Button.disabled (model.run == Nothing) ] "Complete current node", Button.view [ Button.onClick PauseRun ] "Pause", Button.view [ Button.onClick ResumeRun ] "Resume", Button.view [ Button.onClick CancelRun ] "Cancel", Button.view [ Button.onClick SaveWorkflow ] "Save definition" ], case model.run of Just run -> WorkflowRun.view [ WorkflowRun.onSelect SelectNode ] run; Nothing -> Text.paragraph "Start a run to inspect its active node." ]'.replace('Just run -> WorkflowRun.view [ WorkflowRun.onSelect SelectNode ] run; Nothing -> Text.paragraph "Start a run to inspect its active node."','\n        Just run -> WorkflowRun.view [ WorkflowRun.onSelect SelectNode ] run\n        Nothing -> Text.paragraph "Start a run to inspect its active node."\n      '));
  add('StateMachine','Processes','StateMachine.view [ StateMachine.onTransition TransitionState ] model.machine');

  scenarios.fields = `    , board : List (Kanban.Column Choice BoardCard)
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
    , machine : StateMachine.Machine Choice`;
  scenarios.initial = `      , board = [ Kanban.column (Choice "todo") "To do" [ { id = Choice "pick", name = "Pick order", description = "Aurora Logistics" } ], Kanban.column (Choice "doing") "In progress" [ { id = Choice "pack", name = "Pack order", description = "Fjord Foods" } ], Kanban.column (Choice "done") "Done" [] ]
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
      , machine = initialMachine`;
  scenarios.messages = `    | SaveBudget
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
    | TransitionState String`;
  scenarios.initCommands = ', Task.perform (\\_ -> InitServer) (Task.succeed ()), request "chat-history" "GET" "/api/chat" Encode.null, request "comments-history" "GET" "/api/comments" Encode.null, Cmd.batch (List.map (\\documentKey -> request ("restore-" ++ documentKey) "GET" ("/api/documents/" ++ documentKey) Encode.null) [ "views", "server-views", "notifications", "budget", "board", "permissions", "customer", "workflow" ])';
  scenarios.initCommands += ', request "restore-inline" "GET" "/api/documents/inline" Encode.null, request "audit" "GET" "/api/events" Encode.null';
  scenarios.update = `        SaveBudget -> ( model, request "budget" "PUT" "/api/documents/budget" (Encode.list (\\row -> Encode.object (List.map (\\key -> ( key, Encode.string (Budget.cellValue key row) )) [ "item", "quantity", "price" ])) (Budget.rows model.budget)) )
        SetRead _ id ->
            let
                next = List.map (\\n -> if n.id == id then { n | unread = False } else n) model.notifications
            in
            ( { model | notifications = next }, Cmd.batch [ request "notifications" "PUT" "/api/documents/notifications" (Encode.list encodeNotice next), Klar.focus "notifications" NoOp ] )
        DismissNotification id ->
            let
                next = List.filter (\\n -> n.id /= id) model.notifications
            in
            ( { model | notifications = next }, Cmd.batch [ request "notifications" "PUT" "/api/documents/notifications" (Encode.list encodeNotice next), Klar.focus "notifications" NoOp ] )
        ReadAll ->
            let
                next = List.map (\\n -> { n | unread = False }) model.notifications
            in
            ( { model | notifications = next }, Cmd.batch [ request "notifications" "PUT" "/api/documents/notifications" (Encode.list encodeNotice next), Klar.focus "notifications" NoOp ] )
        LoadAudit -> ( { model | audit = Remote.refresh model.audit }, Cmd.batch [ request "audit" "GET" "/api/events" Encode.null, Klar.focus "audit" NoOp ] )
        ApplyMerge fields -> ( model, request "merge" "PUT" "/api/documents/merge" (Encode.object (List.map (\\( id, value ) -> ( choiceKey id, Maybe.map Encode.string value |> Maybe.withDefault Encode.null )) fields)) )
        PostComment submission ->
            if model.commentSending then ( model, Cmd.none ) else
            ( { model | commentSending = True, commentError = Nothing, commentPending = Just submission }, request "comment" "POST" "/api/events" (Encode.object [ ( "action", Encode.string "Posted comment" ), ( "body", Encode.string (CommentThread.submissionBody submission) ), ( "parent", CommentThread.submissionParent submission |> Maybe.map (choiceKey >> Encode.string) |> Maybe.withDefault Encode.null ) ]) )
        SetPermissions changes ->
            let
                apply change grants =
                    let
                        key = ( PermissionMatrix.changedRole change, PermissionMatrix.changedPermission change )
                        rest = List.filter ((/=) key) grants
                    in
                    if Maybe.map PermissionMatrix.isGranted (PermissionMatrix.newAccess change) |> Maybe.withDefault False then key :: rest else rest
                next = List.foldl apply model.grants changes
            in
            ( { model | grants = next }, request "permissions" "PUT" "/api/documents/permissions" (Encode.list (\\( role, permission ) -> Encode.list Encode.string [ role, permission ]) next) )
        DecideApproval approved -> ( { model | approval = if approved then ApprovalFlow.approved { at = Settings.now model.settings, comment = Just "Approved in playground" } else ApprovalFlow.rejected { at = Settings.now model.settings, comment = Just "Rejected in playground" } }, Cmd.batch [ request "approval" "POST" "/api/events" (Encode.object [ ( "action", Encode.string (if approved then "Approved dispatch" else "Rejected dispatch") ) ]), Klar.focus "approval" NoOp ] )
        SubmitReview decisions -> ( { model | reviewSaving = True, reviewError = Nothing }, request "review" "PUT" "/api/documents/review" (Encode.list (\\d -> Encode.object [ ( "id", Encode.string (choiceKey d.id) ), ( "revision", Encode.string d.revision ), ( "approved", Encode.bool d.approved ), ( "reason", Encode.string d.reason ) ]) decisions) )
        SendChat submission -> startChat False (AiChat.submissionText submission) (Just submission) model
        RetryChat -> startChat True model.chatPrompt model.chatPending model
        StopChat -> ( { model | chatTicket = model.chatTicket + 1, chatStatus = AiChat.Interrupted, chatPending = Nothing }, request ("chat:" ++ String.fromInt model.chatTicket) "CANCEL" "/api/chat" Encode.null )
        AddUploads files ->
            let
                entries = List.indexedMap (\\i file -> { id = Choice (String.fromInt (model.nextUpload + i)), file = file, status = UploadQueue.pending, ticket = 0 }) files
            in
            ( { model | uploads = model.uploads ++ entries, nextUpload = model.nextUpload + List.length files, uploadQueue = UploadQueue.clear model.uploadQueue }, Cmd.none )
        StartUploads ids ->
            List.foldl (\\id ( current, commands ) -> let
                ( next, cmd ) = update (StartUpload id) current
              in ( next, cmd :: commands )) ( model, [] ) ids |> (\\( next, commands ) -> ( next, Cmd.batch commands ))
        StartUpload id ->
            case List.filter (\\u -> u.id == id) model.uploads |> List.head of
                Nothing -> ( model, Cmd.none )
                Just entry ->
                    let
                        ticket = entry.ticket + 1
                        uploads = List.map (\\u -> if u.id == id then { u | status = UploadQueue.transferring { sent = 0, total = Just (File.size u.file) }, ticket = ticket } else u) model.uploads
                    in
                    ( { model | uploads = uploads }, Cmd.batch [ Http.request { method = "POST", headers = [], url = "/api/uploads", body = Http.multipartBody [ Http.filePart "file" entry.file ], expect = Http.expectString (Uploaded id ticket), timeout = Just 30000, tracker = Just ("upload-" ++ choiceKey id) }, Klar.focus "upload-queue" NoOp ] )
        UploadProgress id ticket progress ->
            case progress of
                Http.Sending sending -> ( { model | uploads = List.map (\\u -> if u.id == id && u.ticket == ticket then { u | status = UploadQueue.transferring { sent = sending.sent, total = Just sending.size } } else u) model.uploads }, Cmd.none )
                Http.Receiving _ -> ( model, Cmd.none )
        Uploaded id ticket result ->
            ( { model | uploads = List.map (\\u -> if u.id == id && u.ticket == ticket then { u | status = case result of
                    Ok _ -> UploadQueue.completed
                    Err _ -> UploadQueue.failed (Remote.problem Remote.network)
                } else u) model.uploads }, Cmd.none )
        CancelUpload id -> ( { model | uploads = List.map (\\u -> if u.id == id then { u | status = UploadQueue.cancelled, ticket = u.ticket + 1 } else u) model.uploads }, Cmd.batch [ Http.cancel ("upload-" ++ choiceKey id), Klar.focus "upload-queue" NoOp ] )
        RemoveUpload id -> ( { model | uploads = List.filter (\\u -> u.id /= id) model.uploads }, Cmd.batch [ Http.cancel ("upload-" ++ choiceKey id), Klar.focus "upload-queue" NoOp ] )
        InitServer -> followServer model (ServerList.init "server-orders" [])
        ServerMsg inner -> followServer model (ServerList.update inner model.serverList)
        FormMsg inner ->
            let
                ( next, cmd ) = Form.update customerForm inner model.form
            in
            ( { model | form = next }, Cmd.map FormMsg cmd )
        SubmitForm ->
            let
                step = Form.submit (Settings.locale model.settings) customerForm model.form
            in
            ( { model | form = step.state, formTicket = Maybe.map .ticket step.request |> (\\ticket -> if ticket == Nothing then model.formTicket else ticket) }, Cmd.batch [ Cmd.map FormMsg step.cmd, case step.request of
                Just send -> request "customer" "POST" "/api/customers" (Encode.object [ ( "name", Encode.string send.values.name ), ( "email", Encode.string send.values.email ), ( "warehouse", Encode.string (choiceKey send.values.warehouse) ), ( "credit", Maybe.map Money.encodeMinor send.values.credit |> Maybe.withDefault Encode.null ), ( "active", Encode.bool send.values.active ) ])
                Nothing -> Cmd.none
              ] )
        ResetForm -> ( { model | form = Form.revert customerForm model.form }, Cmd.none )
        SetEmail value -> ( { model | email = value }, Cmd.none )
        DirtyGuard value -> ( { model | guard = LeaveGuard.setDirty (Choice "sample") value model.guard }, Cmd.none )
        TryLeave ->
            case LeaveGuard.request (Choice "destination") model.guard of
                LeaveGuard.Proceed _ -> update (Notify "Sample departure allowed") model
                LeaveGuard.Hold guard cmd -> ( { model | guard = guard }, Cmd.map GuardMsg cmd )
        GuardMsg inner ->
            let
                ( guard, cmd, decision ) = LeaveGuard.update inner model.guard
            in
            ( { model | guard = guard, response = if decision /= Nothing then "Left the sample draft" else model.response }, Cmd.map GuardMsg cmd )
        SelectNode id -> ( { model | selectedNode = Just id }, Cmd.none )
        AddWorkflowNode kind ->
            let
                definition = model.workflow
                next = { definition | nodes = definition.nodes ++ [ Workflow.node (Choice ("step-" ++ String.fromInt (List.length definition.nodes))) kind (Workflow.kindLabel Locale.en kind) ] }
            in
            ( { model | workflow = next }, Cmd.none )
        ChangeWorkflow definition -> ( { model | workflow = definition }, Cmd.none )
        StartWorkflow ->
            case Engine.start "playground-run" model.workflow Dict.empty of
                Ok run -> ( { model | run = Just run }, Cmd.none )
                Err issues -> update (Notify (String.join "; " (List.map (Workflow.issueText (Settings.locale model.settings) model.workflow) issues))) model
        CompleteNode -> ( { model | run = Maybe.map (Engine.complete (Encode.string "Completed by playground user")) model.run }, Cmd.none )
        PauseRun -> ( { model | run = Maybe.map Engine.pause model.run }, Cmd.none )
        ResumeRun -> ( { model | run = Maybe.map Engine.resume model.run }, Cmd.none )
        CancelRun -> ( { model | run = Maybe.map Engine.cancel model.run }, Cmd.none )
        SaveWorkflow -> ( model, request "workflow" "PUT" "/api/documents/workflow" (WorkflowCodec.encode choiceIds model.workflow) )
        TransitionState event -> ( { model | machine = StateMachine.transition event model.machine |> Maybe.withDefault model.machine }, Cmd.none )`;

  scenarios.receive = `    else if id == "audit" then
        let
            decoder = Decode.list (Decode.map3 AuditEntry (Decode.field "id" Decode.string) (Decode.field "action" Decode.string) (Decode.field "at" Decode.int))
            result = if ok then Decode.decodeValue decoder body |> Result.mapError (\\_ -> Remote.problem Remote.unknown) else Err (Remote.problem Remote.server)
        in
        ( { model | audit = Remote.refreshWith model.audit result at }, Cmd.none )
    else if id == "comment" then
        case ( ok, model.commentPending ) of
            ( True, Just pending ) ->
                let
                    comment = CommentThread.comment { id = Choice ("comment-" ++ read "id" Decode.string (String.fromInt (Time.posixToMillis at))), author = "You", body = CommentThread.submissionBody pending, at = at }
                    nested = Maybe.map (\\parent -> CommentThread.replyTo parent comment) (CommentThread.submissionParent pending) |> Maybe.withDefault comment
                in
                ( { model | comments = model.comments ++ [ nested ], commentThread = CommentThread.acknowledge pending model.commentThread, commentPending = Nothing, commentSending = False }, Cmd.none )
            _ -> ( { model | commentSending = False, commentError = Just "Could not post comment. The draft is retained." }, Cmd.none )
    else if id == "review" then
        ( { model | reviewSaving = False, reviewError = if ok then Nothing else Just "The server could not save these decisions." }, Cmd.none )
    else if id == "comments-history" then
        if ok && model.commentPending == Nothing then ( { model | comments = List.take 1 model.comments ++ (Decode.decodeValue (Decode.list commentDecoder) body |> Result.withDefault []) }, Cmd.none ) else ( model, Cmd.none )
    else if id == "chat-history" then
        ( { model | chatMessages = if model.chatTicket == 0 && ok then Decode.decodeValue (Decode.list chatDecoder) body |> Result.withDefault [] else model.chatMessages }, Cmd.none )
    else if String.startsWith "chat:" id then
        if id /= "chat:" ++ String.fromInt model.chatTicket then ( model, Cmd.none ) else
        let
            phase = read "phase" Decode.string "failed"
            assistantId = "assistant-" ++ String.fromInt model.chatTicket
        in
        if not ok then ( { model | chatStatus = AiChat.Failed "Generation failed. Retry keeps the conversation." }, Cmd.none )
        else if phase == "accepted" then ( { model | aiChat = Maybe.map (\\submission -> AiChat.acknowledge submission model.aiChat) model.chatPending |> Maybe.withDefault model.aiChat, chatPending = Nothing }, Cmd.none )
        else if phase == "chunk" then ( { model | chatMessages = List.map (\\m -> if m.id == assistantId then { m | body = m.body ++ read "text" Decode.string "" } else m) model.chatMessages }, Cmd.none )
        else if phase == "done" then ( { model | chatStatus = AiChat.Idle }, Cmd.none )
        else ( model, Cmd.none )
    else if String.startsWith "server:" id then
        case Dict.get id model.serverPending of
            Just pending ->
                let
                    decoder = Decode.map2 (\\rows total -> { rows = rows, total = total }) (Decode.field "rows" (Decode.list orderDecoder)) (Decode.field "total" Decode.int)
                    result = if ok then Decode.decodeValue decoder body |> Result.mapError (\\_ -> Remote.problem Remote.unknown) else Err (Remote.problem Remote.server)
                in
                followServer { model | serverPending = Dict.remove id model.serverPending } (ServerList.update (ServerList.gotPage pending result) model.serverList)
            Nothing -> ( model, Cmd.none )
    else if id == "restore-notifications" then
        ( { model | notifications = if ok then Decode.decodeValue (Decode.list noticeDecoder) body |> Result.withDefault model.notifications else model.notifications }, Cmd.none )
    else if id == "restore-budget" then
        ( { model | budget = if ok then Decode.decodeValue (Decode.list (Decode.dict Decode.string |> Decode.map (Dict.toList >> Budget.row))) body |> Result.map (\\rows -> Budget.setRows rows model.budget) |> Result.withDefault model.budget else model.budget }, Cmd.none )
    else if id == "restore-board" then
        let
            board = Decode.decodeValue (Decode.list (Decode.list boardCardDecoder)) body |> Result.map (\\columns -> List.map2 (\\( key, title ) cards -> Kanban.column (Choice key) title cards) [ ( "todo", "To do" ), ( "doing", "In progress" ), ( "done", "Done" ) ] columns) |> Result.withDefault model.board
        in
        ( { model | board = if ok then board else model.board }, Cmd.none )
    else if id == "restore-permissions" then
        ( { model | grants = if ok then Decode.decodeValue (Decode.list (Decode.map2 Tuple.pair (Decode.index 0 Decode.string) (Decode.index 1 Decode.string))) body |> Result.withDefault model.grants else model.grants }, Cmd.none )
    else if id == "restore-workflow" then
        ( { model | workflow = if ok then Decode.decodeValue (WorkflowCodec.decoder choiceIds) body |> Result.withDefault model.workflow else model.workflow }, Cmd.none )
    else if id == "restore-inline" then
        ( { model | inlineEdit = if ok && not (InlineEdit.isEditing model.inlineEdit) then InlineEdit.setValue (read "text" Decode.string (InlineEdit.value model.inlineEdit)) model.inlineEdit else model.inlineEdit }, Cmd.none )
    else if id == "restore-customer" then
        if ok && not (Form.isDirty model.form) then
            let
                fields = Form.fields customerForm
                next =
                    model.form
                        |> Form.set fields.name (read "name" Decode.string "")
                        |> Form.set fields.email (read "email" Decode.string "")
                        |> Form.set fields.warehouse (read "warehouse" Decode.string "" |> (\\key -> if key == "" then Nothing else Just (Choice key)))
                        |> Form.set fields.credit (read "credit" (Decode.nullable (Money.minorDecoder Money.nok)) Nothing)
                        |> Form.set fields.active (read "active" Decode.bool False)
                        |> Form.markClean
            in
            ( { model | form = next }, Cmd.none )
        else ( model, Cmd.none )
    else if id == "restore-server-views" then
        if ok then followServer model (ServerList.setViews (Decode.decodeValue (Decode.list SavedViews.decoder) body |> Result.withDefault []) model.serverList) else ( model, Cmd.none )
    else if id == "restore-views" then
        if ok then
            let
                views = Decode.decodeValue (Decode.list SavedViews.decoder) body |> Result.withDefault []
            in
            ( { model | savedViews = SavedViews.setViews views model.savedViews }, Cmd.none )
        else ( model, Cmd.none )
    else if id == "customer" then
        case model.formTicket of
            Nothing -> ( model, Cmd.none )
            Just ticket ->
                let
                    errors = read "problems" (Decode.list (Decode.map2 (\\field message -> { field = field, message = message }) (Decode.field "field" Decode.string) (Decode.field "message" Decode.string))) []
                    result = if ok then Ok "Customer saved to SQLite" else if List.isEmpty errors then Err (Submission.Failed (Remote.problem Remote.server)) else Err (Submission.Rejected errors)
                    ( next, cmd ) = Form.finish ticket result customerForm model.form
                in
                ( { model | form = next, formTicket = Nothing }, Cmd.map FormMsg cmd )`;
  scenarios.overlays = ', LeaveGuard.view GuardMsg [] model.guard';
  scenarios.declarations = `type alias BoardCard = { id : Choice, name : String, description : String }
type alias Notice = { id : Choice, title : String, body : String, unread : Bool }
type alias AuditEntry = { id : String, action : String, at : Int }
type alias ChatEntry = { id : String, role : String, body : String }
type alias UploadEntry = { id : Choice, file : File.File, status : UploadQueue.Status, ticket : Int }

encodeNotice n = Encode.object [ ( "id", Encode.string (choiceKey n.id) ), ( "title", Encode.string n.title ), ( "body", Encode.string n.body ), ( "unread", Encode.bool n.unread ) ]
encodeColumn c = Encode.list (\\card -> Encode.object [ ( "id", Encode.string (choiceKey card.id) ), ( "name", Encode.string card.name ), ( "description", Encode.string card.description ) ]) (Kanban.cards c)

permissionData grants = PermissionMatrix.matrix { roles = [ PermissionMatrix.role "admin" "Administrator", PermissionMatrix.role "viewer" "Viewer" ], roleKey = identity, permissions = [ PermissionMatrix.permission "read" "Read orders", PermissionMatrix.permission "write" "Edit orders" ], permissionKey = identity, cell = (\\role permission -> PermissionMatrix.direct (PermissionMatrix.fromBool (List.member ( role, permission ) grants))) }

proposals = [ AiReview.proposal { id = Choice "customer-name", revision = "1", title = "Normalize customer name", before = "Aurora", after = "Aurora Logistics", rationale = "The shipping record uses the full legal name.", sources = [ AiReview.source { label = "Fixture record", url = "#/Data", excerpt = "Customer: Aurora Logistics" } ] } ]

startChat isRetry prompt pending model =
    let
        ticket = model.chatTicket + 1
        suffix = String.fromInt ticket
        messages = if not isRetry then model.chatMessages ++ [ { id = "user-" ++ suffix, role = "user", body = prompt } ] else model.chatMessages
    in
    ( { model | chatTicket = ticket, chatPending = pending, chatPrompt = prompt, chatStatus = AiChat.Generating, chatMessages = messages ++ [ { id = "assistant-" ++ suffix, role = "assistant", body = "" } ] }, request ("chat:" ++ suffix) "POST" "/api/chat" (Encode.object [ ( "text", Encode.string prompt ), ( "retry", Encode.bool isRetry ) ]) )

orderDecoder = Decode.map3 Order (Decode.field "id" (Decode.map RecordId Decode.string)) (Decode.field "customer" Decode.string) (Decode.field "total" Decode.int)
chatDecoder = Decode.map3 ChatEntry (Decode.field "id" Decode.string) (Decode.field "role" Decode.string) (Decode.field "body" Decode.string)
noticeDecoder = Decode.map4 Notice (Decode.field "id" (Decode.map Choice Decode.string)) (Decode.field "title" Decode.string) (Decode.field "body" Decode.string) (Decode.field "unread" Decode.bool)
boardCardDecoder = Decode.map3 BoardCard (Decode.field "id" (Decode.map Choice Decode.string)) (Decode.field "name" Decode.string) (Decode.field "description" Decode.string)
commentDecoder = Decode.map5 (\\id author body at parent -> let comment = CommentThread.comment { id = Choice id, author = author, body = body, at = Time.millisToPosix at } in Maybe.map (\\p -> CommentThread.replyTo (Choice p) comment) parent |> Maybe.withDefault comment) (Decode.field "id" Decode.string) (Decode.field "author" Decode.string) (Decode.field "body" Decode.string) (Decode.field "at" Decode.int) (Decode.field "parent" (Decode.nullable Decode.string))
orderFields = [ Rule.textField "customer" "Customer" .customer |> Rule.withOperators [ Rule.Is, Rule.IsNot, Rule.Contains, Rule.NotContains, Rule.StartsWith, Rule.EndsWith, Rule.IsEmpty, Rule.IsNotEmpty ], Rule.numberField "total" "Total (minor units)" (.total >> toFloat >> Just) |> Rule.withOperators [ Rule.Is, Rule.IsNot, Rule.LessThan, Rule.LessOrEqual, Rule.GreaterThan, Rule.GreaterOrEqual, Rule.Between, Rule.NotBetween ] ]

followServer model step =
    let
        counter = model.serverCounter + 1
        key = "server:" ++ String.fromInt counter
        pending = Maybe.map (\\r -> Dict.insert key r model.serverPending) step.request |> Maybe.withDefault model.serverPending
    in
    ( { model | serverList = step.state, serverCounter = counter, serverPending = pending }, Cmd.batch [ Cmd.map ServerMsg step.cmd, Maybe.map (\\r -> request key "POST" "/api/orders/query" (encodeServerQuery r)) step.request |> Maybe.withDefault Cmd.none, Maybe.map (\\views -> request "server-views" "PUT" "/api/documents/server-views" (Encode.list SavedViews.encode views)) step.save |> Maybe.withDefault Cmd.none ] )

encodeServerQuery r =
    Encode.object [ ( "search", Encode.string r.query.search ), ( "page", Encode.int r.query.page ), ( "pageSize", Encode.int r.query.pageSize ), ( "sort", Encode.list (\\( column, direction ) -> Encode.object [ ( "field", Encode.string (Table.columnName column) ), ( "descending", Encode.bool (direction == Table.Descending)) ]) r.query.sort ), ( "filters", Encode.list (\\( column, filter ) -> Encode.object [ ( "field", Encode.string (Table.columnName column) ), ( "contains", Encode.string (case filter of
            Table.Contains text -> text
            _ -> ""
        )) ]) r.query.filters ), ( "rule", encodeServerRule r.rule ) ]

encodeServerRule rule =
    case rule of
        Rule.GroupRule group -> Encode.object [ ( "combinator", Encode.string (if group.combinator == Rule.All then "all" else "any") ), ( "negated", Encode.bool group.negated ), ( "children", Encode.list encodeServerRule group.children ) ]
        Rule.ConditionRule c -> Encode.object [ ( "field", Encode.string c.field ), ( "operator", Encode.string (operatorKey c.operator) ), ( "values", Encode.list Encode.string c.values ) ]

operatorKey operator =
    case operator of
        Rule.Is -> "is"
        Rule.IsNot -> "isNot"
        Rule.Contains -> "contains"
        Rule.NotContains -> "notContains"
        Rule.StartsWith -> "starts"
        Rule.EndsWith -> "ends"
        Rule.GreaterThan -> "greater"
        Rule.GreaterOrEqual -> "atLeast"
        Rule.LessThan -> "less"
        Rule.LessOrEqual -> "atMost"
        Rule.Between -> "between"
        Rule.NotBetween -> "notBetween"
        Rule.IsEmpty -> "empty"
        Rule.IsNotEmpty -> "notEmpty"
        _ -> "unsupported"

type alias CustomerFields = { name : Form.Field String, email : Form.Field String, warehouse : Form.Field (Maybe Choice), credit : Form.Field (Maybe Money.Money), active : Form.Field Bool }
type alias Customer = { name : String, email : String, warehouse : Choice, credit : Maybe Money.Money, active : Bool }
customerForm : Form.Form () CustomerFields Customer
customerForm = Spec.define "customer-form" CustomerFields Customer |> Spec.with (Spec.text "Name" |> Spec.required) |> Spec.with (Spec.text "Email" |> Spec.required |> Spec.rules [ Validate.email ] |> Spec.serverKey "email_address") |> Spec.with (Spec.choice choiceIds "Warehouse" |> Spec.required) |> Spec.with (Spec.money Money.nok "Credit limit") |> Spec.with (Spec.toggle "Active") |> Spec.build

initialWorkflow : Workflow.Definition Choice
initialWorkflow = { title = "Dispatch process", ownerRole = "operator", nodes = [ Workflow.node (Choice "input") Workflow.input "Receive order", Workflow.node (Choice "check") Workflow.human "Check dispatch", Workflow.node (Choice "output") Workflow.output "Order dispatched" ], edges = [ Workflow.edge (Choice "input") (Choice "check") "Continue", Workflow.edge (Choice "check") (Choice "output") "Continue" ] }

initialMachine : StateMachine.Machine Choice
initialMachine = { current = Choice "draft", states = [ { id = Choice "draft", label = "Draft", terminal = False }, { id = Choice "ready", label = "Ready", terminal = False }, { id = Choice "done", label = "Done", terminal = True } ], transitions = [ { from = Choice "draft", to = Choice "ready", event = "Prepare" }, { from = Choice "ready", to = Choice "done", event = "Dispatch" } ] }
`;
  scenarios.covered = ['Klar.Form.Spec','Klar.Form.Layout','Klar.Form.Submission','Klar.Form.Check','Klar.Search','Klar.Rule','Klar.Workflow','Klar.Workflow.Engine','Klar.Workflow.Codec',...['Arrows','Business','Calendar','Communication','Data','Developer','Devices','Documents','Editor','Interface','Logistics','Media','Nature','People','Science'].map(s=>'Klar.Icon.'+s)];
}
module.exports = scenarios;
