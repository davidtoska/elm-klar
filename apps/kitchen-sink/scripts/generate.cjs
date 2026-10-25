// Application scaffolding authored from ai/modules/*.md signatures only.
// This does not inspect, copy, or transform the Klar implementation.
const fs = require('node:fs');
const path = require('node:path');
const dir = path.resolve(__dirname, '..');
const demos = [];
const states = [];
const extraImports = new Set();
const add = (name, group, body) => demos.push({ name, group, body });
function state(name, group, type, init, body, update) {
  const field = name[0].toLowerCase() + name.slice(1);
  states.push({ name, field, type, init, update });
  add(name, group, body || `${name}.view ${name}Msg [ ${name}.label "${name}", ${name}.locale locale ] model.${field}`);
}
const ordinary = (names, group) => names.forEach(name => state(name, group, `${name}.State`, `${name}.init "demo-${name.toLowerCase()}"`, `${name}.view ${name}Msg ${group==='Dates' && name!=='TimePicker' ? `([ ${name}.label "${name}", ${name}.locale locale, ${name}.clearable ] ++ List.filterMap identity [ Maybe.map ${name}.today (Settings.today model.settings) ])` : `[ ${name}.label "${name}", ${name}.locale locale ]`} model.${name[0].toLowerCase()+name.slice(1)}`));
add('Button', 'Actions', 'Layout.row [ Layout.gap 2, Layout.wrap ] [ Button.view [ Button.primary, Button.onClick (Notify "Primary action") ] "Primary", Button.view [ Button.secondary, Button.onClick (Notify "Secondary action") ] "Secondary", Button.view [ Button.danger, Button.onClick OpenConfirm ] "Delete", Button.view [ Button.loading True ] "Working", Button.view [ Button.disabled True ] "Disabled", Button.iconOnly [ Button.onClick (Notify "Settings") ] Icon.settings "Settings" ]');
add('ButtonGroup', 'Actions', 'ButtonGroup.view [] "Export format" [ Button.view [ Button.onClick (Notify "CSV selected") ] "CSV", Button.view [ Button.onClick (Notify "JSON selected") ] "JSON" ]');
add('ToggleGroup', 'Actions', 'ToggleGroup.single [ ToggleGroup.label "View mode" ] { selected = Just (Choice model.choice), onChange = (Maybe.map choiceKey >> Maybe.withDefault "table" >> SetChoice) } [ ToggleGroup.option (Choice "table") "Table", ToggleGroup.option (Choice "cards") "Cards" ]');
state('SplitButton','Actions','SplitButton.State','SplitButton.init "split"','SplitButton.view SplitButtonMsg [] { label = "Save", onClick = SaveSnapshot, items = menuItems } model.splitButton');
state('Menu','Actions','Menu.State','Menu.init "menu"','Menu.view MenuMsg [ Menu.label "Actions", Menu.items menuItems ] model.menu');
add('Link','Actions','Layout.row [ Layout.gap 4 ] [ Link.view [] (Link.internal "#/Data") "Open data", Link.view [] (Link.download { fileName = "sample.txt", mimeType = "text/plain", content = model.text }) "Download text" ]');
add('Kbd','Actions','Layout.row [ Layout.gap 2 ] [ Kbd.view [] (Shortcut.mod (Shortcut.char \'k\')), Kbd.key [] "Esc" ]');
add('Badge','Feedback','Layout.row [ Layout.gap 2 ] (List.map (\\tone -> Badge.view [ Badge.tone tone, Badge.dot ] "Status") [ Neutral, Primary, Info, Success, Warning, Danger ])');
add('Tag','Feedback','if model.tagVisible then Tag.view [ Tag.onRemove DismissTag, Tag.tone Info ] "Removable tag" else Button.view [ Button.id "restore-tag", Button.onClick RestoreTag ] "Restore tag"');
add('Alert','Feedback','if model.alertVisible then Alert.view [ Alert.tone Info, Alert.title "Documentation-only exercise", Alert.onDismiss DismissAlert ] "Every sample uses only the public API." else Button.view [ Button.id "restore-alert", Button.onClick RestoreAlert ] "Restore alert"');
add('Spinner','Feedback','Spinner.panel [ Spinner.compact ] "Loading sample"');
add('Skeleton','Feedback','Layout.stack [ Layout.gap 2 ] [ Skeleton.lines 2, Skeleton.block 48, Skeleton.circle 32 ]');
add('Progress','Feedback','Layout.row [ Layout.gap 4 ] [ Progress.view [ Progress.value model.slider, Progress.label "Completion", Progress.showValue ], Progress.ring [ Progress.value model.slider, Progress.ariaLabel "Completion" ] ]');
add('EmptyState','Feedback','EmptyState.view [ EmptyState.title "No matching orders", EmptyState.description "Adjust the filter to try again.", EmptyState.actions [ Button.view [ Button.onClick Reload ] "Reload" ] ]');
add('ErrorState','Feedback','ErrorState.view [ ErrorState.onRetry Reload ] (Remote.problem Remote.network)');
add('StatusPage','Feedback','StatusPage.view [ StatusPage.title "Sample operation complete", StatusPage.description "This is an embedded result page." ] StatusPage.success');
add('TextInput','Inputs','TextInput.view [ TextInput.id "text", TextInput.label "Customer name", TextInput.value model.text, TextInput.onInput SetText, TextInput.clearable ]');
add('TextArea','Inputs','TextArea.view [ TextArea.label "Notes", TextArea.value model.text, TextArea.onInput SetText, TextArea.rows 3 ]');
ordinary(['NumberInput','PasswordInput','SearchInput','TagInput','FileDrop'],'Inputs');
state('InlineEdit','Inputs','InlineEdit.State','InlineEdit.init "inline" "Warehouse label"','InlineEdit.view InlineEditMsg [ InlineEdit.ariaLabel "Warehouse label" ] model.inlineEdit',`let
    ( next, cmd ) = InlineEdit.update inner model.inlineEdit
in
( { model | inlineEdit = next }, Cmd.batch [ Cmd.map InlineEditMsg cmd, case InlineEdit.pending next of
    Just value -> request "inline" "PUT" "/api/documents/inline" (Encode.object [ ( "text", Encode.string value ) ])
    Nothing -> Cmd.none
  ] )`);
state('MaskedInput','Inputs','MaskedInput.State','MaskedInput.init "masked" MaskedInput.phone');
state('MoneyInput','Inputs','MoneyInput.State','MoneyInput.init "money" Money.nok');
state('QuantityInput','Inputs','QuantityInput.State','QuantityInput.init "quantity"','QuantityInput.view QuantityInputMsg [ QuantityInput.label "Weight" ] { ids = choiceIds, units = [ QuantityInput.unit (Choice "kg") "Kilograms" "kg", QuantityInput.unit (Choice "g") "Grams" "g" ] } model.quantityInput');
add('Checkbox','Inputs','Checkbox.view [ Checkbox.label "Accept terms", Checkbox.checked model.checked, Checkbox.onCheck SetChecked ]');
add('Switch','Inputs','Switch.view [ Switch.label "Enable notifications", Switch.checked model.checked, Switch.onCheck SetChecked ]');
add('CheckboxGroup','Inputs','CheckboxGroup.view [ CheckboxGroup.label "Warehouses", CheckboxGroup.options [ CheckboxGroup.option (Choice "oslo") "Oslo", CheckboxGroup.option (Choice "bergen") "Bergen" ], CheckboxGroup.selected model.choices, CheckboxGroup.onChange SetChoices, CheckboxGroup.selectAll ]');
add('Radio','Inputs','Radio.view [ Radio.label "Delivery", Radio.options [ Radio.option (Choice "standard") "Standard", Radio.option (Choice "express") "Express" ], Radio.selected (Just (Choice model.choice)), Radio.onChange (choiceKey >> SetChoice) ]');
add('SegmentedControl','Inputs','SegmentedControl.view [ SegmentedControl.label "Display", SegmentedControl.options [ SegmentedControl.option "table" "Table", SegmentedControl.option "cards" "Cards" ], SegmentedControl.selected model.choice, SegmentedControl.onChange SetChoice ]');
add('Slider','Inputs','Slider.view [ Slider.label "Completion", Slider.value model.slider, Slider.onInput SetSlider, Slider.min 0, Slider.max 100, Slider.unit "%" ]');
for(const name of ['Select','MultiSelect','Autocomplete']) state(name,'Choosing',`${name}.State Choice`,`${name}.init "${name.toLowerCase()}"`,`${name}.view ${name}Msg [ ${name}.label "${name}", ${name}.options choices, ${name}.locale locale, ${name}.clearable ] model.${name[0].toLowerCase()+name.slice(1)}`);
state('TreeSelect','Choosing','TreeSelect.State TreeSelect.Single Choice','TreeSelect.init "tree-select" TreeSelect.single','TreeSelect.view TreeSelectMsg [ TreeSelect.label "Warehouse", TreeSelect.nodes nodes, TreeSelect.clearable ] model.treeSelect');
state('Cascader','Choosing','Cascader.State Choice','Cascader.init "cascader"','Cascader.view CascaderMsg [ Cascader.label "Location path", Cascader.nodes nodes ] model.cascader');
state('Transfer','Choosing','Transfer.State Choice','Transfer.init "transfer"','Transfer.view TransferMsg [ Transfer.label "Assign warehouses", Transfer.options choiceIds choices ] model.transfer');
ordinary(['DatePicker','DateRangePicker','TimePicker','DateTimePicker'],'Dates');
state('Calendar','Dates','Calendar.State','Calendar.init "calendar" |> Calendar.showDate sampleDate','Calendar.view CalendarMsg [ Calendar.weekNumbers, Calendar.todayButton, Calendar.markers [ Calendar.dot sampleDate Success "Dispatch" ] ] model.calendar');
state('RecurrencePicker','Dates','RecurrencePicker.State','RecurrencePicker.init "recurrence" sampleDate');
state('Tree','Data','Tree.State Choice','Tree.init "tree"','Tree.view TreeMsg [ Tree.ariaLabel "Warehouses", Tree.checkboxes, Tree.filterBox ] model.tree [ Tree.branch choiceIds (Choice "north") "Northern region" [ Tree.leaf choiceIds (Choice "oslo") "Oslo", Tree.leaf choiceIds (Choice "bergen") "Bergen" ] ]');
state('VirtualList','Data','VirtualList.State','VirtualList.init "virtual"','VirtualList.list VirtualListMsg [ VirtualList.height 240, VirtualList.onSelect (String.fromInt >> Notify) ] { label = "Ten thousand locations", items = Array.fromList (List.range 1 10000), viewRow = (\\n -> Text.text ("Location " ++ String.fromInt n)) } model.virtualList');
state('Table','Data','Table.State RecordId','Table.init "orders"','Table.view TableMsg [ Table.columns [ Table.text (Table.columnId "id") "Order" (\\r -> recordKey r.id) [], Table.text (Table.columnId "customer") "Customer" .customer [ Table.filterText ], Table.money (Table.columnId "total") "Total" (\\r -> money r.total) [ Table.footerSum ] ], Table.rowId recordIds .id, Table.remote model.orders, Table.onRetry Reload, Table.ariaLabel "Orders from SQLite", Table.settings model.settings ] model.table');
add('Pagination','Data','Pagination.view [ Pagination.onPage SetPageNumber, Pagination.jumpToPage ] { page = model.pageNumber, pageSize = 20, total = 500 }');
add('ListItem','Data','ListItem.list [ ListItem.ariaLabel "Recent activity", ListItem.bordered ] [ ListItem.view [ ListItem.avatar "Aurora Logistics", ListItem.secondary "Order ready", ListItem.onClick (Notify "Order selected") ] "Aurora Logistics", ListItem.view [ ListItem.meta "Pending" ] "Fjord Foods" ]');
state('JsonViewer','Content','JsonViewer.State','JsonViewer.init "json"','JsonViewer.view JsonViewerMsg [ JsonViewer.toolbar ] model.jsonViewer (Encode.object [ ( "customer", Encode.string model.text ), ( "completion", Encode.float model.slider ) ])');
state('MarkdownEditor','Content','MarkdownEditor.State','MarkdownEditor.init "markdown-editor" |> MarkdownEditor.setValue "## Dispatch notes\\n\\n**Ready** for review."');
add('Markdown','Content','Markdown.view [] (MarkdownEditor.value model.markdownEditor)');
state('Diff','Content','Diff.State','Diff.init "diff"','Diff.view DiffMsg [ Diff.ariaLabel "Customer changes" ] model.diff (Diff.lines [] "Customer: Aurora\\nStatus: Draft" "Customer: Aurora Logistics\\nStatus: Ready")');
add('CodeBlock','Content','CodeBlock.view [ CodeBlock.language CodeBlock.json, CodeBlock.download "payload.json" ] { id = "code", label = "Request payload", source = Encode.encode 2 (snapshot model) }');
add('Compare','Content','Compare.view [] { ariaLabel = "Warehouse comparison", ids = choiceIds, id = .id, header = (\\r -> Text.strong r.name), fields = [ Compare.text "City" .name, Compare.text "Capacity" .capacity ] } [ { id = Choice "oslo", name = "Oslo", capacity = "2,000" }, { id = Choice "bergen", name = "Bergen", capacity = "1,400" } ]');
state('Modal','Overlays','Modal.State','Modal.init "modal"','Button.view [ Button.id "open-modal", Button.onClick OpenModal ] "Open modal"');
state('Drawer','Overlays','Drawer.State','Drawer.init "drawer"','Button.view [ Button.id "open-drawer", Button.onClick OpenDrawer ] "Open drawer"');
state('ConfirmDialog','Overlays','ConfirmDialog.State','ConfirmDialog.init "confirm"','Button.view [ Button.id "open-confirm", Button.danger, Button.onClick OpenConfirm ] "Confirm a change"');
state('Popover','Overlays','Popover.State','Popover.init "popover"','Popover.view PopoverMsg [ Popover.title "Quick actions", Popover.closeButton ] model.popover "Open popover" [ Text.paragraph "This panel uses Klar positioning.", Button.view [ Button.onClick SaveSnapshot ] "Save snapshot" ]');
add('Tooltip','Overlays','Tooltip.wrap [ Tooltip.id "tip" ] "Save this playground state to SQLite" (\\attrs -> Button.view [ Button.htmlAttrs attrs, Button.onClick SaveSnapshot ] "Hover or focus me")');
state('ContextMenu','Overlays','ContextMenu.State Choice','ContextMenu.init "context"','Layout.stack [] [ ContextMenu.area ContextMenuMsg model.contextMenu { id = "context-target", target = Choice "order" } [ Text.paragraph "Right-click here, or press the context-menu key." ], ContextMenu.view ContextMenuMsg [ ContextMenu.ariaLabel "Record actions" ] (\\_ -> menuItems) model.contextMenu ]');
state('CommandPalette','Overlays','CommandPalette.State','CommandPalette.init "palette"','Button.view [ Button.id "open-palette", Button.onClick OpenPalette ] "Command palette (Ctrl K)"');
state('ShortcutHelp','Overlays','ShortcutHelp.State','ShortcutHelp.init "shortcut-help"','Button.view [ Button.id "open-help", Button.onClick OpenHelp ] "Keyboard shortcuts"');
add('Toast','Overlays','Button.view [ Button.onClick (Notify "A toast from the playground") ] "Show toast"');
state('Breadcrumbs','Structure','Breadcrumbs.State','Breadcrumbs.init "crumbs"','Breadcrumbs.view BreadcrumbsMsg [ Breadcrumbs.maxItems 3, Breadcrumbs.items [ Breadcrumbs.link { label = "Home", href = "#/Foundations" }, Breadcrumbs.text "Operations", Breadcrumbs.text "Warehouses", Breadcrumbs.text "Oslo" ] ] model.breadcrumbs');
state('Tabs','Structure','Tabs.State Choice','Tabs.init "tabs" (Choice "details")','Tabs.view TabsMsg [ Tabs.ariaLabel "Order panels", Tabs.tabs [ Tabs.tab (Choice "details") "Details" |> Tabs.withPanel (\\_ -> Text.paragraph "Order details"), Tabs.tab (Choice "history") "History" |> Tabs.withPanel (\\_ -> Text.paragraph "Shipment history") ] ] model.tabs');
add('Stepper','Structure','Stepper.view [ Stepper.current model.step, Stepper.nonLinear, Stepper.onSelect SetStep ] [ Stepper.step "Details", Stepper.step "Review", Stepper.step "Complete" ]');
state('Accordion','Structure','Accordion.State Choice','Accordion.init "accordion"','Accordion.view AccordionMsg [ Accordion.bordered ] model.accordion [ Accordion.section choiceIds (Choice "shipping") "Shipping" [ Text.paragraph "Delivery in two days." ], Accordion.section choiceIds (Choice "billing") "Billing" [ Text.paragraph "Invoice due in 30 days." ] ]');
add('Toolbar','Structure','Toolbar.view [ Toolbar.ariaLabel "Document actions" ] [ Toolbar.label "Document", Toolbar.spacer, Button.view [ Button.onClick SaveSnapshot ] "Save", Toolbar.separator, Button.view [ Button.onClick Reload ] "Refresh" ]');
add('DescriptionList','Structure','DescriptionList.view [ DescriptionList.columns 2, DescriptionList.bordered ] [ DescriptionList.text "Customer" "Aurora Logistics", DescriptionList.text "Location" "Oslo", DescriptionList.html "Status" (Badge.status Success "Ready") ]');
state('Sortable','Structure','Sortable.State Choice','Sortable.init "sortable"','Sortable.view SortableMsg [ Sortable.ariaLabel "Dispatch priority", Sortable.moveButtons ] model.sortable (List.map (\\id -> Sortable.item choiceIds id (choiceKey id) (Text.text (choiceKey id))) model.sortOrder)',`let
    ( next, cmd ) = Sortable.update inner model.sortable
in
( { model | sortable = next, sortOrder = Sortable.reorder choiceIds identity model.sortable next model.sortOrder }, Cmd.map SortableMsg cmd )`);
state('Splitter','Structure','Splitter.State','Splitter.init "splitter" [ Splitter.percent 35, Splitter.percent 65 ]','Splitter.view SplitterMsg [ Splitter.height 180 ] model.splitter [ Splitter.pane "List" (Text.paragraph "Resize the separator with mouse or arrow keys."), Splitter.pane "Detail" (Text.paragraph "Warehouse details") ]');
add('BulkBar','Structure','BulkBar.view [] { toolbar = Text.text "Order actions", selected = List.length model.choices, onClear = SetChoices [] } [ Button.view [ Button.onClick (Notify "Export selection") ] "Export selection" ]');
add('History','Structure','Layout.stack [ Layout.gap 2 ] [ TextInput.view [ TextInput.label "Undoable note", TextInput.value (History.present model.history), TextInput.onInput SetHistory ], History.controls [ History.showShortcuts ] { onUndo = Undo, onRedo = Redo } model.history ]');
add('Stat','Dashboard','Stat.view [ Stat.id "orders-stat", Stat.label "Orders in SQLite", Stat.remote model.orders (\\rows -> [ Stat.int (List.length rows) ]), Stat.onRetry RetryStat, Stat.delta 12.5, Stat.trend [ 4, 6, 5, 8, 12 ] ]');
add('Chart','Dashboard','Layout.grid [ Layout.minColumn 300, Layout.gap 4 ] [ Chart.line [ Chart.title "Weekly orders", Chart.categories [ "Mon", "Tue", "Wed", "Thu", "Fri" ], Chart.area ] [ Chart.series "Orders" [ 12, 18, 13, 24, 32 ] ], Chart.bar [ Chart.title "Warehouse stock" ] [ Chart.series "Stock" [ 40, 60, 30 ] ], Chart.donut [ Chart.title "Order status" ] [ Chart.segment "Ready" 64, Chart.segment "Pending" 36 ], Chart.gauge [ Chart.title "Capacity" ] model.slider, Chart.meter [ Chart.title "Fulfilment" ] model.slider, Chart.sparkline [ Chart.ariaLabel "Trend" ] [ 3, 5, 4, 7, 9 ] ]');
add('Timeline','Dashboard','Timeline.view [ Timeline.settings model.settings, Timeline.ariaLabel "Dispatch history" ] [ Timeline.dayEvent "created" sampleDate "Order created" |> Timeline.withAuthor "Alex Morgan", Timeline.dayEvent "approved" (Date.addDays 1 sampleDate) "Approved" |> Timeline.withTone Success ]');
add('Avatar','Dashboard','Avatar.group [ Avatar.maxShown 3 ] (List.map Avatar.entry [ "Alex Morgan", "Sam Rivera", "Taylor Chen", "Jordan Lee" ])');
add('RemoteView','Dashboard','Layout.stack [] (RemoteView.view [ RemoteView.id "remote-view", RemoteView.onRetry RetryRemoteView ] model.orders (\\rows -> [ Text.paragraph (String.fromInt (List.length rows) ++ " orders received from Go / SQLite.") ]))');
add('Foundations','Foundations',`Layout.stack [ Layout.gap 4 ] [ Text.lead "A complete consumer application built from the AI documentation.", DescriptionList.view [] [ DescriptionList.text "Stack" "Elm / Go / SQLite", DescriptionList.text "Library access" "Public API and generated documentation only", DescriptionList.text "Persistence" "Use Save snapshot; reload to restore" ], Layout.row [ Layout.gap 2, Layout.wrap ] (List.map (\\theme -> Button.view [ Button.onClick (SetTheme theme) ] (Theme.name locale theme)) Theme.all), Switch.view [ Switch.label "Dark mode", Switch.checked (Settings.mode model.settings == Theme.Dark), Switch.onCheck SetDark ], Switch.view [ Switch.label "Norwegian component text", Switch.checked (Settings.locale model.settings == Locale.nb), Switch.onCheck SetNorwegian ], SegmentedControl.view [ SegmentedControl.label "Density", SegmentedControl.options [ SegmentedControl.option Theme.Compact "Compact", SegmentedControl.option Theme.Normal "Normal", SegmentedControl.option Theme.Comfortable "Comfortable" ], SegmentedControl.selected (Settings.density model.settings), SegmentedControl.onChange SetDensity ], Layout.row [ Layout.gap 2 ] [ Tag.view [ Tag.color (Color.rgb 30 120 160) ] "Custom data color", Text.code (Format.int locale 1234567) ] ]`);

// More complex component scenarios are described in a second application-owned file.
const advanced = require('./scenarios.cjs');
advanced({ add, state, ordinary, extraImports });

// Apply the locale only where the consumer documentation exposes it.
for (const demo of demos) {
  if (demo.name === 'ListItem') { demo.body = demo.body.replace('ListItem.list [', 'ListItem.list [ ListItem.locale locale,'); continue; }
  const reference = path.resolve(dir, '../../ai/modules/Klar.' + demo.name + '.md');
  if (fs.existsSync(reference) && /^locale :/m.test(fs.readFileSync(reference,'utf8').split('```elm')[1] || '')) {
    const pattern = new RegExp('\\b' + demo.name + '\\.(view|viewRemote|line|bar|donut|gauge|meter|sparkline|panel|ring|group|key)\\s+(?:(?:' + demo.name + 'Msg|Avatar\\.entry)\\s+)?\\[', 'g');
    demo.body = demo.body.replace(pattern, match => match + ' ' + demo.name + '.locale locale,').replace(/\.locale locale,\s*\]/g, '.locale locale ]');
  }
}

const groups = ['Foundations', ...new Set(demos.map(d => d.group).filter(g=>g!=='Foundations'))];
const imports = new Set(['Klar','Klar.AppShell as AppShell','Klar.SideNav as SideNav','Klar.PageHeader as PageHeader','Klar.Layout as Layout','Klar.Card as Card','Klar.Text as Text','Klar.Icon as Icon','Klar.Icon.Library as IconLibrary','Klar.Settings as Settings','Klar.Theme as Theme exposing (Tone(..))','Klar.Color as Color','Klar.Locale as Locale','Klar.Ids as Ids','Klar.Money as Money','Klar.Date as Date','Klar.Format as Format','Klar.Remote as Remote exposing (Remote(..))','Klar.RemoteView as RemoteView','Klar.Picking as Picking','Klar.Shortcut as Shortcut','Klar.History as History','Klar.Toast as Toast','Klar.Overlay as Overlay','Klar.Select as Select',...extraImports]);
for (const d of demos) if(!['Foundations','Icons'].includes(d.name)) imports.add(`Klar.${d.name} as ${d.name}`);
let main = `port module Main exposing (main)

import Array
import Browser
import Browser.Navigation as Nav
import Html exposing (Html)
import Html.Attributes as Attr
import Http
import File
import Dict exposing (Dict)
import Json.Decode as Decode
import Json.Encode as Encode
import Task
import Time
import Url exposing (Url)
${[...imports].map(s => 'import '+s).join('\n')}

port outgoing : Encode.Value -> Cmd msg
port incoming : (Decode.Value -> msg) -> Sub msg

type Page = Page String
type Choice = Choice String
type RecordId = RecordId String

choiceKey (Choice value) = value
recordKey (RecordId value) = value
choiceIds = Ids.make { toKey = choiceKey, fromKey = Choice >> Just }
recordIds = Ids.make { toKey = recordKey, fromKey = RecordId >> Just }
pageIds = Ids.list (\\(Page key) -> key) (List.map Page pages)
pages = ${JSON.stringify(groups).replaceAll(',', ', ')}

type alias Order = { id : RecordId, customer : String, total : Int }

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
${states.map(s=>'    , '+s.field+' : '+s.type).join('\n')}
${advanced.fields || ''}
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
${states.map(s=>'    | '+s.name+'Msg ('+s.name+'.Msg'+(s.type.includes('Choice') && !['Tree','Sortable','QuantityInput'].includes(s.name)?' Choice':'')+')').join('\n')}
${advanced.messages || ''}

main = Browser.application { init = init, update = update, view = view, subscriptions = subscriptions, onUrlRequest = AppShell.onUrlRequest ShellMsg, onUrlChange = AppShell.onUrlChange ShellMsg }

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
${states.map(s=>'      , '+s.field+' = '+s.init).join('\n')}
${advanced.initial || ''}
      }
    , Cmd.batch [ request "orders:0" "GET" "/api/orders" Encode.null, request "restore" "GET" "/api/documents/playground" Encode.null, Task.perform GotZone Time.here, Task.perform GotNow Time.now${advanced.initCommands || ''} ]
    )

subscriptions model = Sub.batch ([ incoming Received, Shortcut.subscription ShortcutMsg shortcuts model.shortcut ] ++ List.map (\\u -> Http.track ("upload-" ++ choiceKey u.id) (UploadProgress u.id u.ticket)) model.uploads)

shortcuts = [ Shortcut.shortcut (Shortcut.mod (Shortcut.char 'k')) "Navigation" "Open command palette" OpenPalette |> Shortcut.inInputs, Shortcut.shortcut (Shortcut.char '?') "Help" "Keyboard help" OpenHelp ]

update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        ShellMsg inner ->
            let
                ( shell, cmd, address ) = AppShell.update inner model.shell
                page = Maybe.map pageFromUrl address |> Maybe.withDefault model.page
            in
            ( { model | shell = AppShell.setPage navigation page shell, page = page }, Cmd.map ShellMsg cmd )
        ToastMsg inner ->
            let
                ( next, cmd ) = Toast.update inner model.toasts
            in
            ( { model | toasts = next }, Cmd.map ToastMsg cmd )
        ShortcutMsg inner ->
            let
                ( next, action ) = Shortcut.update shortcuts inner model.shortcut
                updated = { model | shortcut = next }
            in
            Maybe.map (\\a -> update a updated) action |> Maybe.withDefault ( updated, Cmd.none )
        GotZone zone ->
            let
                settings = Settings.withZone zone model.settings
            in
            ( { model | settings = settings, calendar = setCalendarToday settings model.calendar }, Cmd.none )
        GotNow now ->
            let
                settings = Settings.withNow now model.settings
            in
            ( { model | settings = settings, calendar = setCalendarToday settings model.calendar }, Cmd.none )
        Reload -> update (LoadScenario model.scenario) model
        RetryStat -> retryRegion "orders-stat" model
        RetryRemoteView -> retryRegion "remote-view" model
        RetryCards -> retryRegion "card-list" model
        RetryWorkQueue -> retryRegion "work-queue" model
        ResetRemote -> ( { model | orders = NotAsked, epoch = model.epoch + 1 }, Cmd.none )
        DismissTag -> ( { model | tagVisible = False }, Klar.focus "restore-tag" NoOp )
        RestoreTag -> ( { model | tagVisible = True }, Cmd.none )
        DismissAlert -> ( { model | alertVisible = False }, Klar.focus "restore-alert" NoOp )
        RestoreAlert -> ( { model | alertVisible = True }, Cmd.none )
        LoadScenario scenario ->
            let
                ticket = model.epoch + 1
            in
            ( { model | orders = Remote.refresh model.orders, epoch = ticket, scenario = scenario }, request ("orders:" ++ String.fromInt ticket) "GET" ("/api/orders?scenario=" ++ scenario) Encode.null )
        Received value -> receive value model
        SetText value -> ( { model | text = value }, Cmd.none )
        SetChecked value -> ( { model | checked = value }, Cmd.none )
        SetChoice value -> ( { model | choice = value }, Cmd.none )
        SetChoices value -> ( { model | choices = value }, Cmd.none )
        SetSlider value -> ( { model | slider = value }, Cmd.none )
        SetPageNumber value -> ( { model | pageNumber = value }, Cmd.none )
        SetStep value -> ( { model | step = value }, Cmd.none )
        SetHistory value -> ( { model | history = History.record [ History.label "Edit note" ] value model.history }, Cmd.none )
        Undo -> ( { model | history = History.undo model.history }, Cmd.none )
        Redo -> ( { model | history = History.redo model.history }, Cmd.none )
        SetTheme value -> ( { model | settings = Settings.withTheme value model.settings }, Cmd.none )
        SetDark value -> ( { model | settings = Settings.withMode (if value then Theme.Dark else Theme.Light) model.settings }, Cmd.none )
        SetNorwegian value -> ( { model | settings = Settings.withLocale (if value then Locale.nb else Locale.en) model.settings }, Cmd.none )
        SetDensity value -> ( { model | settings = Settings.withDensity value model.settings }, Cmd.none )
        SaveSnapshot -> ( model, request "save" "PUT" "/api/documents/playground" (snapshot model) )
        Notify text ->
            let
                ( next, cmd ) = Toast.push [ Toast.message text, Toast.tone Success ] model.toasts
            in
            ( { model | toasts = next, response = text }, Cmd.map ToastMsg cmd )
${[['Modal','modal','OpenModal','open-modal'],['Drawer','drawer','OpenDrawer','open-drawer'],['ConfirmDialog','confirmDialog','OpenConfirm','open-confirm'],['CommandPalette','commandPalette','OpenPalette','open-palette'],['ShortcutHelp','shortcutHelp','OpenHelp','open-help']].map(([module,field,msg,id])=>`        ${msg} ->
            let
                ( next, cmd ) = ${module}.open "${id}" model.${field}
            in
            ( { model | ${field} = next }, Cmd.map ${module}Msg cmd )`).join('\n')}
        ConfirmAction -> ( { model | confirmDialog = ConfirmDialog.setBusy model.confirmDialog }, request "confirm" "POST" "/api/events" (Encode.object [ ( "action", Encode.string "Confirmed sample action" ) ]) )
${states.map(s=>`        ${s.name}Msg inner ->
            ${s.update ? s.update.replaceAll('\n','\n            ') : `let
                ( next, cmd ) = ${s.name}.update inner model.${s.field}
            in
            ( { model | ${s.field} = next }, Cmd.map ${s.name}Msg cmd )`}`).join('\n')}
${advanced.update || ''}
        NoOp -> ( model, Cmd.none )

request id method url body = outgoing (Encode.object [ ( "id", Encode.string id ), ( "method", Encode.string method ), ( "url", Encode.string url ), ( "body", body ) ])

retryRegion id model =
    let
        ( next, cmd ) = update Reload model
    in
    ( next, Cmd.batch [ cmd, Klar.focus id NoOp ] )

snapshot model = Encode.object [ ( "text", Encode.string model.text ), ( "checked", Encode.bool model.checked ), ( "slider", Encode.float model.slider ), ( "note", Encode.string (History.present model.history) ), ( "theme", Encode.string (Theme.key (Settings.theme model.settings)) ), ( "mode", Encode.string (Theme.modeKey (Settings.mode model.settings)) ) ]

receive value model =
    let
        id = Decode.decodeValue (Decode.field "id" Decode.string) value |> Result.withDefault ""
        ok = Decode.decodeValue (Decode.field "ok" Decode.bool) value |> Result.withDefault False
        body = Decode.decodeValue (Decode.field "body" Decode.value) value |> Result.withDefault Encode.null
        read key decoder fallback = Decode.decodeValue (Decode.field key decoder) body |> Result.withDefault fallback
        at = Decode.decodeValue (Decode.field "at" Decode.int) value |> Result.withDefault 0 |> Time.millisToPosix
    in
    if String.startsWith "orders:" id then
        if id /= "orders:" ++ String.fromInt model.epoch then ( model, Cmd.none ) else
        let
            result = if ok then Decode.decodeValue (Decode.list (Decode.map3 Order (Decode.field "id" (Decode.map RecordId Decode.string)) (Decode.field "customer" Decode.string) (Decode.field "total" Decode.int))) body |> Result.mapError (\\_ -> Remote.problem Remote.unknown) else Err (Remote.problem Remote.server)
        in
        ( { model | orders = Remote.refreshWith model.orders result at, response = if ok then "Loaded from Go / SQLite" else "Request failed; previous data is retained" }, Cmd.none )
    else if id == "restore" then
        if ok then
            ( { model | text = read "text" Decode.string model.text, checked = read "checked" Decode.bool model.checked, slider = read "slider" Decode.float model.slider, history = History.init (read "note" Decode.string (History.present model.history)), settings = model.settings |> Settings.withTheme (read "theme" Decode.string "klar" |> Theme.fromKey |> Maybe.withDefault Theme.klar) |> Settings.withMode (read "mode" Decode.string "light" |> Theme.modeFromKey |> Maybe.withDefault Theme.Light) }, Cmd.none )
        else ( model, Cmd.none )
    else if id == "inline" then
        ( { model | inlineEdit = if ok then InlineEdit.saved model.inlineEdit else InlineEdit.failed (Remote.problem Remote.server) model.inlineEdit }, Cmd.none )
    else if id == "confirm" then
        if ok then
            let
                ( next, cmd ) = ConfirmDialog.close model.confirmDialog
            in
            ( { model | confirmDialog = next, response = "Event persisted in SQLite" }, Cmd.map ConfirmDialogMsg cmd )
        else ( { model | confirmDialog = ConfirmDialog.setFailed (Remote.problem Remote.server) model.confirmDialog }, Cmd.none )
${advanced.receive || ''}
    else update (Notify (if ok then "Saved to SQLite" else "Server request failed")) model

navigation = List.map (\\page -> SideNav.item pageIds { key = Page page, label = page, href = "#/" ++ page }) pages
pageFromUrl url =
    let
        route = String.dropLeft 1 (Maybe.withDefault "/Foundations" url.fragment)
    in
    Page (if List.member route pages then route else "Foundations")
money minor = Money.fromMinor Money.nok minor |> Maybe.withDefault (Money.zero Money.nok)
sampleDate = Date.fromEpochDay 20751
setCalendarToday settings calendar = Settings.today settings |> Maybe.map (\\today -> Calendar.setToday today calendar) |> Maybe.withDefault calendar
choices = List.map (\\name -> Select.option (Choice name) name) [ "Oslo", "Bergen", "Trondheim", "Stavanger", "Tromsø" ]
nodes = [ Picking.branch choiceIds (Choice "north") "Norway" (List.map (\\name -> Picking.leaf choiceIds (Choice name) name) [ "Oslo", "Bergen", "Trondheim" ]) ]
menuItems = [ Menu.item "Save snapshot" SaveSnapshot, Menu.item "Reload orders" Reload, Menu.separator, Menu.item "Show message" (Notify "Menu action") ]

view model =
    let
        (Page page) = model.page
    in
    { title = "Klar Kitchen Sink · " ++ page
    , body = [ Klar.stylesheetFor model.settings, AppShell.view [ AppShell.state ShellMsg model.shell, AppShell.settings model.settings, AppShell.shortcuts (Shortcut.listen ShortcutMsg shortcuts model.shortcut), AppShell.onStrayDrop NoOp, AppShell.pageTitle page, AppShell.brand (AppShell.brandLink { name = "Klar Kitchen Sink", href = "#/Foundations", logo = Nothing }), AppShell.sidebar (AppShell.sideNav ShellMsg [ SideNav.entries navigation ] model.shell), AppShell.overlays (overlays model) ] [ Layout.stack [ Layout.gap 6 ] [ PageHeader.view [ PageHeader.title page, PageHeader.subtitle "Elm + Go + SQLite · documentation-only consumer", PageHeader.actions [ Button.view [ Button.onClick SaveSnapshot ] "Save snapshot", Button.view [ Button.onClick OpenPalette ] "Commands" ] ], Text.secondary model.response, scenarioControls, viewPage model ] ] ]
    }

scenarioControls = Layout.row [ Layout.gap 2, Layout.wrap ] [ Text.caption "Data and Dashboard remote state", Button.view [ Button.onClick ResetRemote ] "Clear remote data", Button.view [ Button.onClick (LoadScenario "data") ] "Data", Button.view [ Button.onClick (LoadScenario "empty") ] "Empty", Button.view [ Button.onClick (LoadScenario "slow") ] "Slow refresh", Button.view [ Button.onClick (LoadScenario "fail") ] "Failure / old data" ]

overlays model = [ Toast.view ToastMsg [] model.toasts, Modal.view ModalMsg [] model.modal "Edit customer" [ TextInput.view [ TextInput.label "Customer name", TextInput.value model.text, TextInput.onInput SetText ], Button.view [ Button.onClick SaveSnapshot ] "Save snapshot" ], Drawer.view DrawerMsg [] model.drawer "Order details" [ Text.paragraph "Details stay beside the main page." ], ConfirmDialog.view ConfirmDialogMsg [ ConfirmDialog.message "Persist a sample event?", ConfirmDialog.onConfirm ConfirmAction ] model.confirmDialog "Confirm action", CommandPalette.view CommandPaletteMsg [ CommandPalette.sections [ CommandPalette.section "Actions" [ CommandPalette.item "Save snapshot" SaveSnapshot, CommandPalette.item "Refresh orders" Reload ] ] ] model.commandPalette, ShortcutHelp.view ShortcutHelpMsg [] shortcuts model.shortcutHelp${advanced.overlays || ''} ]

viewPage model =
    let
        (Page page) = model.page
        locale = Settings.locale model.settings
    in
    case page of
${groups.map(g=>`        "${g}" -> Layout.stack [ Layout.gap 4 ] [ ${demos.filter(d=>d.group===g).map(d=>`Card.view [ Card.title "${d.name}", Card.id "component-${d.name}" ] [ ${d.body} ]`).join(',\n            ')} ]`).join('\n')}
        _ -> Text.paragraph "Choose a section."

${advanced.declarations || ''}
`;
main = main.replace('overlays model = [', 'overlays model = let locale = Settings.locale model.settings in [');
for (const name of ['Toast','Modal','Drawer','ConfirmDialog','CommandPalette','ShortcutHelp','LeaveGuard']) {
  const prefix = name + '.view ' + (name==='LeaveGuard'?'GuardMsg':name+'Msg') + ' [';
  main = main.replace(prefix, prefix + ' ' + name + '.locale locale,').replace(/\.locale locale,\s*\]/g,'.locale locale ]');
}
fs.mkdirSync(path.join(dir,'src'),{recursive:true});
fs.writeFileSync(path.join(dir,'src/Main.elm'),main);
const index = JSON.parse(fs.readFileSync(path.resolve(dir,'../../ai/klar-index.json')));
const helpers = ['Klar','Klar.AppShell','Klar.SideNav','Klar.PageHeader','Klar.Layout','Klar.Card','Klar.Text','Klar.Icon','Klar.Icon.Library','Klar.Settings','Klar.Theme','Klar.Color','Klar.Locale','Klar.Ids','Klar.Money','Klar.Date','Klar.Format','Klar.Remote','Klar.Picking','Klar.Shortcut','Klar.Overlay'];
helpers.push(...(advanced.covered || []));
const coverage = index.modules.map(m=>({module:m.name, group:m.group, scenario:demos.find(d=>'Klar.'+d.name===m.name)?.group || (helpers.includes(m.name)?'Shared scenarios / infrastructure':'Pending'), implemented:helpers.includes(m.name)||demos.some(d=>'Klar.'+d.name===m.name), browserRenderVerified:false, interactionVerified:false}));
fs.writeFileSync(path.join(dir,'coverage.json'),JSON.stringify(coverage,null,2)+'\n');
console.log('Generated '+demos.length+' scenarios, '+states.length+' stateful components.');
