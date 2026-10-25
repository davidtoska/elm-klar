# Klar for an AI that builds an application

Klar is an Elm package (`davidtoska/elm-klar`, modules `Klar.*`) for precise, data-dense applications: tables with 50 000 rows, filters, forms, dialogs, dashboards. You build the application, a person reviews it. An application is **Klar plus your own Elm code**: no CSS, no JavaScript, no class names, no `style`.

Read in this order, and stop when you can write the screen: this file; `ai/klar-index.json` (search `keywords`, `purpose`, `whenToUse`, `whenNot`, `quickPath`, `related` before you open anything); `ai/modules/<Module>.md` (every signature, then the documentation; the long ones start with a Quick path); `example/src/Examples/<Name>.elm` (seven complete programs: `Inbox`, `EditForm`, `ConfirmDelete`, `Dashboard`, `MultiStep`, `CommandPalette`, `ReviewDesk`). Do not read `src/` or the rest of `example/`: they are the library's own source and its showcase, not guidance.

## Start here

**The model.**

- **A component is `State` + `Msg` + `update` + `view`**, wired like any child in the Elm Architecture:
  `Foo.State` in your model, a `FooMsg Foo.Msg` in your `Msg`, `Foo.update m model.foo` with `Cmd.map FooMsg`,
  `Foo.view FooMsg [ attributes ] model.foo`. Read the value with the module's reader (`Select.value`, `DatePicker.value` ...) and compare before and
  after `update` to react. There are no out-messages.
- **A view-only component is one function and a list of attributes**: `Button.view [ Button.primary, Button.onClick Save ] "Save"`.
  Attributes are opaque. Their order matters only when the same attribute is given twice: the last one wins (state flags such as `loading`, `failed` and `remote` add up instead).
- **The `String` you give to `init` is the DOM id**, unique on the page. Keep them as named values in one place.
- **Backend data is a `Remote a`** (`NotAsked | Loading | Loaded a | Failed Problem | Kept (Kept a)`; `Kept` is old data during or after a refresh, see the traps). Give it to
  `Table.remote`, `Stat.remote`, `Chart.lineRemote`, `Timeline.viewRemote`, `Tree.viewRemote`, `Select.remote` ...: they draw the skeleton, the failure
  with retry and the empty state. Klar never sends a request: `Remote.refresh` when it leaves, `Remote.settle model.orders result` when the answer comes (a failed refresh keeps the data, marked old).
- **Your ids are your own types**, written as text once per type as a `Klar.Ids` (`Ids.make { toKey, fromKey }`; `Ids.list` for a closed set such as your pages; `Ids.string`, `Ids.int`) and given to every component that holds them: `Table.rowId`, `Tree.leaf`, `Picking.leaf`, `Sortable.item`, `Accordion.section`, `SideNav.item`, `Spec.choice`, `Rule.choiceFieldOf`.
  A table column is a `Table.columnId "total"`, named once.
- **Overlays go in one list**: `Modal`, `Drawer`, `ConfirmDialog`, `CommandPalette`, `ShortcutHelp`, `Toast`, `LeaveGuard` return an
  `Overlay`; give the list to `AppShell.overlays` (or `Overlay.host`). The layer makes the page inert and returns focus.
- **Dates are `Klar.Date`, money is `Klar.Money`; the language, the zone, the time now, the density and the theme live in one `Settings`** (built-in text follows `Locale.en` or `Locale.nb`: give `X.locale (Settings.locale model.settings)`).

**The frame.** There is one way to wire the application frame: `AppShell` keeps the sidebar, the drawer, the current link and
the key. The model holds `page : Page` and `shell : AppShell.State Page`; the messages hold one `ShellMsg AppShell.Msg`; `main` passes
`AppShell.onUrlRequest ShellMsg` and `AppShell.onUrlChange ShellMsg`; `init` makes the shell with `AppShell.init { id, key, url }` and
`AppShell.setPage navigation page`; `update` calls `AppShell.update` and gets `( shell, cmd, address )`. The **address** is the only place
that learns of a new route (a link, Back, a `pushUrl`, also a new query): set `page` from it and call `AppShell.setPage` again. Following links
(`replaceUrl` for the current page; a route in the fragment starts with `/`, as `#/orders`, and any other fragment such as `#field-id` scrolls to that element), scroll to the top of a new page, focus on its content after a followed link, the drawer and its focus are done for you; give `AppShell.pageTitle` the title of the page and a screen reader announces it. A `Nav.pushUrl` of yours keeps focus where it is (route tabs stay usable); when the control that pushed goes with the page (a Save button), add `AppShell.goToContent model.shell |> Cmd.map ShellMsg`. You write no `LinkClicked`, `UrlChanged` or `SideNav.init`. Only
when a click must be held back (`LeaveGuard`) give `Browser.application` an `onUrlRequest` message of your own and hand the request to `AppShell.follow` when
it may go on; `onUrlChange` stays the shell's, and the `address` that `AppShell.update` returns goes to `LeaveGuard.onUrlChange pageFromUrl url
model.guard` (Back and Forward; the wiring is in the `LeaveGuard` doc, tried in Chrome); everything else stays. `elm.json` needs `elm/url` as a **direct** dependency, and `Elm.Main.init()` takes no `node`.

**The three rules that matter most.** (1) Backend data is a `Remote` given to the component, and ids are your own types.
(2) Every overlay is in the one overlay list, also while closed, and an opener has an id (`Button.id`). (3) You write no CSS, focus,
popup, scroll, date or keyboard code: if you feel you need it, a module does it (the table at the end).

## The standard application

This compiles as it stands (`npm run check:ai-names` compiles it). How to set up `elm.json` and `index.html` around it is in
"Getting Klar into a project" below.

```elm
module Main exposing (main)

import Browser
import Browser.Navigation as Nav
import Html exposing (Html)
import Klar
import Klar.AppShell as AppShell
import Klar.Button as Button
import Klar.Icon as Icon
import Klar.Ids as Ids exposing (Ids)
import Klar.Money as Money exposing (Money)
import Klar.PageHeader as PageHeader
import Klar.Remote as Remote exposing (Remote(..))
import Klar.Settings as Settings exposing (Settings)
import Klar.SideNav as SideNav
import Klar.Table as Table
import Klar.Theme exposing (Tone(..))
import Klar.Toast as Toast
import Process
import Task
import Time
import Url exposing (Url)


type Page
    = Orders
    | Settings


type alias Order =
    { id : String, customer : String, total : Money }


type alias Model =
    { page : Page
    , shell : AppShell.State Page
    , settings : Settings
    , table : Table.State String
    , orders : Remote (List Order)
    , toasts : Toast.State Msg
    }


type Msg
    = ShellMsg AppShell.Msg
    | TableMsg Table.Msg
    | ToastMsg Toast.Msg
    | GotZone Time.Zone
    | GotOrders (Result Remote.Problem (List Order)) Time.Posix
    | Reload


main : Program () Model Msg
main =
    Browser.application
        { init = init
        , update = update
        , view = view
        , subscriptions = \_ -> Sub.none
        , onUrlRequest = AppShell.onUrlRequest ShellMsg
        , onUrlChange = AppShell.onUrlChange ShellMsg
        }


init : () -> Url -> Nav.Key -> ( Model, Cmd Msg )
init _ url key =
    let
        page =
            pageFromUrl url
    in
    ( { page = page
      , shell = AppShell.init { id = "app-shell", key = key, url = url } |> AppShell.setPage navigation page
      , settings = Settings.default
      , table = Table.init "orders"
      , orders = Loading
      , toasts = Toast.init "toasts"
      }
    , Cmd.batch [ fetchOrders, Task.perform GotZone Time.here ]
    )


fetchOrders : Cmd Msg
fetchOrders =
    -- the first two lines stand for: Http.task { ... } |> Task.mapError toProblem |> Task.map Ok |> Task.onError (Err >> Task.succeed)
    Process.sleep 600
        |> Task.map (\_ -> Ok [ Order "1042" "Aurora Logistics" (kroner 125050), Order "1043" "Fjord Foods" (kroner 31000) ])
        |> Task.andThen (\result -> Task.map (GotOrders result) Time.now)
        |> Task.perform identity


kroner : Int -> Money
kroner ore =
    Money.fromMinor Money.nok ore |> Maybe.withDefault (Money.zero Money.nok)


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        ShellMsg m ->
            let
                ( shell, cmd, address ) =
                    AppShell.update m model.shell
            in
            case address of
                Just url ->
                    -- the one place that learns of a new route
                    let
                        page =
                            pageFromUrl url
                    in
                    ( { model | page = page, shell = AppShell.setPage navigation page shell }
                    , Cmd.map ShellMsg cmd
                    )

                Nothing ->
                    ( { model | shell = shell }, Cmd.map ShellMsg cmd )

        TableMsg m ->
            let
                ( table, cmd ) =
                    Table.update m model.table
            in
            ( { model | table = table }, Cmd.map TableMsg cmd )

        ToastMsg m ->
            let
                ( toasts, cmd ) =
                    Toast.update m model.toasts
            in
            ( { model | toasts = toasts }, Cmd.map ToastMsg cmd )

        GotZone zone ->
            ( { model | settings = Settings.withZone zone model.settings }, Cmd.none )

        GotOrders result at ->
            -- a failed reload keeps the rows ("Old data from 14:05"); the table shows a failure itself
            case ( result, Remote.isRefreshing model.orders ) of
                ( Ok _, True ) ->
                    Toast.push [ Toast.tone Success, Toast.message "Orders updated." ] model.toasts
                        |> (\( toasts, cmd ) -> ( { model | orders = Remote.refreshWith model.orders result at, toasts = toasts }, Cmd.map ToastMsg cmd ))

                _ ->
                    ( { model | orders = Remote.refreshWith model.orders result at }, Cmd.none )

        Reload ->
            -- the rows stay on the screen, dimmed, until the answer comes
            ( { model | orders = Remote.refresh model.orders }, fetchOrders )


view : Model -> Browser.Document Msg
view model =
    { title = "Acme Operations"
    , body =
        [ Klar.stylesheetFor model.settings
        , AppShell.view
            [ AppShell.state ShellMsg model.shell
            , AppShell.settings model.settings
            , AppShell.brand (AppShell.brandLink { name = "Acme Operations", href = "#/", logo = Nothing })
            , AppShell.sidebar (AppShell.sideNav ShellMsg [ SideNav.entries navigation ] model.shell)
            , AppShell.overlays [ Toast.view ToastMsg [] model.toasts ]
            ]
            [ viewPage model ]
        ]
    }


viewPage : Model -> Html Msg
viewPage model =
    case model.page of
        Orders ->
            Html.div []
                [ PageHeader.view [ PageHeader.title "Orders", PageHeader.actions [ Button.view [ Button.onClick Reload ] "Reload" ] ]
                , Table.view TableMsg
                    [ Table.columns
                        [ Table.text (Table.columnId "id") "Order" .id [ Table.pinned ]
                        , Table.text (Table.columnId "customer") "Customer" .customer [ Table.filterText ]
                        , Table.money (Table.columnId "total") "Total" .total [ Table.footerSum ]
                        ]
                    , Table.remote model.orders
                    , Table.rowId Ids.string .id
                    , Table.ariaLabel "Orders"
                    , Table.onRetry Reload
                    , Table.settings model.settings
                    ]
                    model.table
                ]

        Settings ->
            PageHeader.view [ PageHeader.title "Settings" ]


pageKeys : Ids Page
pageKeys =
    Ids.list
        (\page ->
            case page of
                Orders ->
                    "orders"

                Settings ->
                    "settings"
        )
        [ Orders, Settings ]


navigation : List (SideNav.Entry Page msg)
navigation =
    [ SideNav.item pageKeys { key = Orders, label = "Orders", href = "#/orders" } |> SideNav.withIcon Icon.clipboardCheck
    , SideNav.item pageKeys { key = Settings, label = "Settings", href = "#/settings" } |> SideNav.withIcon Icon.settings
    ]


pageFromUrl : Url -> Page
pageFromUrl url =
    case url.fragment of
        Just "/settings" ->
            Settings

        _ ->
            Orders
```

## The ten rules

1. **Import only exposed modules** (`Klar`, `Klar.Button`, ...; the list is in `elm.json`). Never `Klar.Internal.*`, `Klar.Table.Sort` or a copy of a component.
2. **No CSS, no class, no `style`, no `Html.node "style"`.** Put `Klar.stylesheetFor model.settings` once in the view (it draws the theme; `Klar.stylesheet` is the default theme only). Looks come from `Theme` values, layout from `Klar.Layout`, text from `Klar.Text`.
3. **Your own id types.** A `type OrderId = OrderId Int`, with `toKey` and `fromKey` given once; DOM ids and column ids are named values.
4. **Backend data is a `Remote`.** Do not write its cases; give it to the component. Turn your error into `Remote.problem Remote.timeout` (or `network`, `notFound`, `forbidden`, `server` ...).
5. **Overlays go in the overlay list**, always, also while closed. Give a button that opens one an id (`Button.id`) and pass it to `open`; an overlay that a route, the palette or a key opens takes `open ""`, and the layer finds the element to give focus back to.
6. **Never write focus, popup, scroll, date or keyboard code.** No `Browser.Dom.focus` for a dialog, no click-outside, no positioning, no `Time` arithmetic. Find the module in the table below. To put focus on an element of your page by its id (after a retry, on a stateless control), use `Klar.focus id NoOp`.
7. **Dates are `Klar.Date`, money is `Klar.Money`, numbers and dates for people come from `Klar.Format`.** Read `Time.here` and `Time.now` once into the settings (`Settings.withZone`, `Settings.withNow`); the day today is `Settings.today model.settings`, for `DatePicker.today` and the like. `Remote.refreshWith` takes the time of each answer (the request chains `Time.now`, as in the standard application). A time of day you write yourself is `Settings.time model.settings posix` (it knows the zone, and says "UTC" until it does).
8. **Forms use `Klar.Form`** (declared with `Klar.Form.Spec`, framed with `Klar.Form.Layout`). Server problems go in with `Form.rejected`, steps with `Form.advance`; do not keep a second copy of field values or of the problems. Every value has its kind, on Klar's own types: `Spec.date` (`Form.datePicker`), `Spec.money` (`Form.moneyInput`), `Spec.masked` (`Form.maskedInput`), a choice drawn as `Form.radio`, a toggle as `Form.checkbox`. A field that depends on another is `Spec.shownWhen` / `Spec.requiredWhen` (declared without `Spec.required`; `Check.failingWhenHidden` in a test); a choice among thousands is `Form.select` with `Select.serverSearch` and `Form.query`.
9. **A list on a server is `ServerList`** (`Examples/Inbox.elm`): one `State` and one `Msg` for the table, the filter bar and the saved views; `ServerList.update` returns the `request` to send and drops old answers, so you write no comparison, page reset or ticket. Only a server-mode `Table` on its own (no filter bar, no saved views) takes the four steps in the `Klar.Table` doc: compare `Table.query` before and after `update`, `Table.setPage 1` when an outside filter changed, ask with a new ticket, drop an answer whose ticket is not the latest. **Do not debounce** what Klar already waits for: the table waits 350 ms after typing in its search box and filter fields in server mode (`Table.searchDebounce`), the filter bar changes its rule only when the user applies a filter, and a sort click or a page change must ask at once. The server searches of `Select.serverSearch`, `MultiSelect.serverSearch`, `Autocomplete.serverSearch`, a lazy `Tree.query` and `CommandPalette.query` (for a `CommandPalette.remote` section) wait 300 ms too: fetch when the query changes and drop an answer whose query is no longer the current one. Debounce only what Klar does not: text you read from a field of your own (use `SearchInput`, which waits 300 ms).
10. **When Klar lacks something, say so.** Write the best honest version, put a comment `-- KLAR GAP: what is missing` above it, and carry on. Do not copy a component, wrap it in your own CSS or import an internal module.

## Small things that come up

- **A day count from a data set to a date and back**: `Date.fromEpochDay (baseDay + n)` and `Date.toEpochDay date - baseDay` (day 0 is 1 January 1970); `Date.addDays` and `Date.diffDays` do the rest.
- **A price rule ("if the category is X and the quantity above Y, take Z off")**: `Rule` and `RuleBuilder` hold only the condition. Inside a `Klar.Form` the list of rules is `Spec.rows` with `Spec.conditions` for the condition (see `ai/modules/Klar.Form.md`). On a page without a form the outcome is yours: one record per rule with a key that stays with it when others are removed, `{ key : Int, when : RuleBuilder.State, discountPercent : Float }`, the builder made with `RuleBuilder.init ("price-rule-" ++ String.fromInt key)` and its message carrying the key, and `Rule.matches today fields (RuleBuilder.rule r.when) row` to ask a row. The example is in `ai/modules/Klar.RuleBuilder.md`.
- **A failed save with "Try again"**: `FormLayout.onRetry` gets its own message, and that branch runs the save and `FormLayout.focusStatus`; "Try again" is replaced by "Saving ..." and focus would fall to the page. Server problems per field are `Form.rejected`, which also focuses the summary (`Examples/EditForm.elm`).
- **"Try again" of any region** (`RemoteView`, `Stat`, `Chart`, `Timeline`, `ApprovalFlow`, `PermissionMatrix`; `Table` and `Tree` do it themselves): give the region an id (`RemoteView.id`, `Stat.id`, `Chart.id`, `Timeline.id`, `ApprovalFlow.id`; a `PermissionMatrix` has the id of its `init`) and, in the update branch of **its own** retry message, `Klar.focus id NoOp`. Do it in a message of its own, so a "Reload" button elsewhere keeps its focus.
- **A wizard draws the step fields inside `Form.stepBody v [ ... ]`**, or Elm reuses the focused input of one step for the next and "Required" shows on a field nobody touched.
- **Words that call a palette item** ("go to order 1001"): `CommandPalette.withCommand "go to order"` on the item and `CommandPalette.argument items palette` for the text to send to the backend.
- **Keep saved views** with `SavedViews.encode` / `SavedViews.decoder` (and `Table.encodeQuery` / `Table.queryDecoder`); the library stores nothing, you choose where the JSON goes.
- **A footer range worded your way** ("1 to 25 of 200"): `Table.rangeText` (same in `ServerList.viewTable`), `Pagination.rangeText`.
- **Leaving a page with unsaved work**: `LeaveGuard`, six functions, one complete program at the top of its doc. Call `setDirty` in the branches of the messages that edit a form, never in a wrapper after every message, and reset the form you leave in the branch that gets the decision of "Leave" (every Leave gives one, after a link and after Back), then go with `LeaveGuard.follow toPath answer guard` (`Examples/MultiStep.elm`); with `saveAndLeave` that branch also gets "Save and leave": check `LeaveGuard.savesFirst answer` before you reset anything. `onUrlChange` answers `Enter route` (show it), `SamePage url` (the page you show at another address: apply its query, keep the work) or `Unchanged`.
- **A sidebar that is not a `SideNav`**: `AppShell.sidebar` takes any `Html` (a `Tree`, a list of saved views).

## Common traps

Each is checked against the current source; the ones the library has fixed are gone.

- **Give a component its data once.** `Chart.lineRemote` (and its sisters), `Timeline.viewRemote`, `Stat.remote`, `Table.remote` take a `Remote`, including its old data; shape it with `Remote.map`, never with a `case`.
- **`Remote` has a fifth constructor, `Kept`** (old data while a refresh runs, or after it failed). A `case` of your own needs a branch for it, or use `Remote.toMaybe` / `RemoteView.view`. Start a request with `Remote.refresh`, finish it with `Remote.settle old result` (`Remote.refreshWith old result at` when you have the time of the answer); never write a failed refresh over good data with `Remote.fromResult`.
- **A `Modal` with a text field opens with focus on the dialog.** Give its state `Modal.setInitialFocus [ fieldId ]` (at `init`); `Drawer` and `Popover` have the same function.
- **Focus returns to an opener only if it has an id** (`Button.id`, a `SideNav` link, a field). Without one it goes to the last element that had an id, which may be elsewhere (`LeaveGuard` "Stay" too).
- **A `ConfirmDialog` may hold one or two controls in `body`** (a reason, a target); a real form is a `Modal`. **Server-mode `Table.exportCsv`** offers the selection only while every selected row is on the page; export from the backend for a selection that spans pages. A bulk action of a server table reads `Table.selection`: after "Select all N matching" it is `AllMatching { except }` and `selectedIds` is `[]`.
- **`Table.activeExternalFilters n`** tells "no matches" from "no data" for filters outside the table; wire `onResetFilters` once to clear the filter bar and the table's own filters.
- **The first type parameter of `Form` and `Form.State` is the step type** (`()` for a form without steps). Declare the form in `Klar.Form.Spec` once, at the top of a file.
- **`Rule.choiceField` values are `String`s.** For your own id type use `Rule.choiceFieldOf` with `Klar.Ids`.
- **`Card.title` is an `h2`, and so is a `Form.Layout.section` title.** A card inside a section, or under any `h2`, needs `Card.headingLevel 3`.
- **The page needs an `h1` in every state.** A `RemoteView` or `ErrorState` draws none while it loads or has failed, so keep the `PageHeader` outside it. For the focus after their "Try again" see "Try again of any region" above (a page that is only an `ErrorState` has no body to focus: `AppShell.goToContent model.shell |> Cmd.map ShellMsg`).
- **`Timeline` day headings are `h3`** (right in a card with an `h2` title): directly under a page `h1` say `Timeline.headingLevel 2`. "Load more" is `Timeline.loadMore msg model.morePages`, a `Remote Bool` of the next page (`True`: there is more); keep it in the model, never loading or failed flags.
- **A lazy `Tree` searches only the nodes it has**: for the rest watch `Tree.query` and ask the backend (see its doc).

## I need X, use module Y

Each module is `Klar.<Name>`; details in `ai/modules/Klar.<Name>.md`.

**Foundations and structure**
- Whole-application frame, top bar, sidebar, scrolling content, overlay list: `AppShell`. Side menu typed by your pages: `SideNav`. Title, actions, tabs of a page: `PageHeader`. Path to the page: `Breadcrumbs`.
- Language, time zone, time now and density of the whole application, stated once: `Settings` (`AppShell.settings model.settings` for the density and the shell's language; `X.settings model.settings` on a component that writes a time, with `Time.here` at the start, and without a zone a time ends in "UTC"; `X.locale (Settings.locale model.settings)` for the language). Tone, size, density types shared by all components, and the ten themes with light and dark mode (`Settings.withTheme Theme.ocean`, `Settings.withMode Theme.System`, `Klar.stylesheetFor settings`; no colors of your own): `Theme`. A color that is a value of your data (a color code on a database row) on an option or a tag: `Color` (`Color.hex` is checked and gives a `Maybe`) and `Select.withColor`, `Tag.color`; a status color that follows the theme: `Select.withTone`. Language (`Locale.en`, `Locale.nb`): `Locale`. Stack, row, grid, spacing, fill the rest: `Layout`. A bordered group: `Card`. Titles and paragraphs: `Text`. An icon: `Icon` (everyday set) and `Icon.Library` (all of them) and by category `Icon.Arrows`, `Icon.Business`, `Icon.Calendar`, `Icon.Communication`, `Icon.Data`, `Icon.Developer`, `Icon.Devices`, `Icon.Documents`, `Icon.Editor`, `Icon.Interface`, `Icon.Logistics`, `Icon.Media`, `Icon.Nature`, `Icon.People`, `Icon.Science`.
- Sections that open and close: `Accordion`. The bar of controls above a view: `Toolbar` (actions for selected items: `BulkBar`, or `Table.bulkActions` in a table). Label and value pairs: `DescriptionList`. Switch views of one thing: `Tabs`. Wizard steps (draws only): `Stepper`.
- Resize panes: `Splitter`. Reorder a list: `Sortable`. `Klar` itself is `Klar.stylesheetFor model.settings` (put it in the view once).

**Actions and feedback**
- Button or link-looking button: `Button`. Group of buttons: `ButtonGroup`. Main action plus alternatives: `SplitButton`. Choose on/off options: `ToggleGroup`. Actions in a dropdown: `Menu`. Right-click menu: `ContextMenu`. A real link that cannot leave the app by accident: `Link`. Key caps ("Ctrl K"): `Kbd`.
- State label ("Paid"): `Badge`. Chip the user can remove: `Tag`. Inline message: `Alert`. Message that goes away: `Toast`. Loading: `Spinner` (inline) or `Skeleton` (shape of the content) or `Progress`. Nothing to show: `EmptyState`. A request failed: `ErrorState`. A whole result page ("Not found", "Order created"): `StatusPage`.

**Overlays**
- The layer itself (focus, inert page, toasts): `Overlay`. Dialog with a form: `Modal`. "Are you sure?" with busy and failure: `ConfirmDialog`. Details beside a list: `Drawer`. Small anchored panel: `Popover`. Hint on hover or focus: `Tooltip`. One search box for commands and content (`Ctrl K`): `CommandPalette`. Shortcut cheat sheet: `ShortcutHelp`. Global keys, sequences: `Shortcut`. "12 selected: Export, Delete": `BulkBar`.
- Ask before leaving with unsaved input: `LeaveGuard`. Undo and redo of a value: `History`.

**Tables, lists and data**
- Editable budgets with up to six columns, exact line amounts and a grand total: `Budget`. Configure `Budget.setColumns` and `Budget.setFormula`; read `Budget.total` and `Budget.rows` to save.
- Records with search, sort, filters, selection, paging, 50 000 rows, server mode: `Table` (`Table.virtual` for scrolling). Page controls alone: `Pagination`. A dense row with title, meta, actions: `ListItem`. A very long plain list: `VirtualList`. Hierarchy: `Tree`.
- KPI number: `Stat`. Line, bar, donut, gauge, sparkline: `Chart`. History of events: `Timeline`. Person or system badge: `Avatar`. A JSON value: `JsonViewer`.
- Data state from a backend, with old data kept while it refreshes: `Remote`. The body of a card, dialog or drawer from a `Remote`: `RemoteView`. Forgiving text matching and ranking: `Search`. Numbers, sizes, dates, money text: `Format`.

**Rules, filters, change**
- A condition tree as data (encode, decode, run on rows, describe): `Rule`. Edit one: `RuleBuilder`. Chips above a table: `FilterBar`. Named filters: `SavedViews`. A server-side list with all three and no glue: `ServerList`.
- Text diff, JSON diff, record diff: `Diff`. Records side by side: `Compare`. Safe Markdown to HTML: `Markdown`. Edit Markdown with preview: `MarkdownEditor`.
- Responsive record cards with selection: `CardList`. Keyboard work list with a detail pane: `WorkQueue`. Actor, timestamp and expandable change history: `AuditLog`. Three-way field merge with decisions bound to the reviewed versions: `ConflictResolver`. Persistent unread/read notification history: `NotificationCenter`. See `Examples/ReviewDesk.elm` for all five in one application. Ordered work stages with validated moves and WIP limits: `Kanban`. Threaded safe-Markdown discussion with revision-bound draft acknowledgement: `CommentThread`. Exact source inspection/download with bounded JSON/Elm highlighting: `CodeBlock`. Local file staging and explicit transfer statuses: `UploadQueue` (the application sends files). Raw number text plus an application's own unit id: `QuantityInput` (no implicit conversion).
- Roles by permissions grid: `PermissionMatrix`. Approval steps and decisions: `ApprovalFlow`.
- Graphical processes: `Workflow` definitions, `WorkflowBuilder`, `WorkflowNode`, `WorkflowRun`, `Workflow.Engine`, `Workflow.Codec` and `StateMachine`. See [WORKFLOWS.md](WORKFLOWS.md) for the studio, roles and server boundary.
**Forms and inputs**
- The whole form (fields, dirty, server problems, steps, rows): `Form`; its declaration: `Form.Spec`; its tests: `Form.Check`. The frame (sections, grid, buttons, submit state): `Form.Layout`. The wrapper of one control (label, hint, error): `Field`. Validators: `Validate`. How your id type is written as text, once, for every component: `Ids`.
- Text: `TextInput`, `TextArea`, `PasswordInput`, `SearchInput` (waits for a pause), `TagInput`, `InlineEdit` (click to edit), `MaskedInput` (IBAN, postal code, phone). Number: `NumberInput`, `Slider`. Money: `Money`, `MoneyInput`. Files: `FileDrop`.
- Choose: `Checkbox`, `CheckboxGroup`, `Radio`, `Switch`, `SegmentedControl` (one of a few). `Select` (one of many, searchable; `Select.Option` is its option type), `MultiSelect`, `Autocomplete` (suggestions), `TreeSelect`, `Cascader` (a path through levels), `Transfer` (two lists), `Picking` (the nodes of `TreeSelect` and `Cascader`; `Picking.fromFlat` builds them from rows that name their parent).
**Date and time**
- The date type: `Date`. A date field: `DatePicker`. A period: `DateRangePicker`. Time: `TimePicker`. Both: `DateTimePicker`. A month with marks: `Calendar`. "Every second Tuesday": `Recurrence` with `RecurrencePicker`.

## Getting Klar into a project

**Published:** `elm install davidtoska/elm-klar`. **Before it is published, or to keep an exact copy:** a git
submodule pinned to a tag or a commit, with its `src` in your `source-directories`. Elm reads the dependencies of
the application, not of a folder, so list Klar's too:

```json
{
    "type": "application",
    "source-directories": ["src", "vendor/klar/src"],
    "dependencies": {
        "direct": { "elm/browser": "1.0.2", "elm/core": "1.0.5", "elm/file": "1.0.5", "elm/html": "1.0.1",
                    "elm/json": "1.1.4", "elm/time": "1.0.0", "elm/url": "1.0.0" },
        "indirect": { "elm/bytes": "1.0.8", "elm/virtual-dom": "1.0.5" }
    }
}
```

`index.html` for a `Browser.application` (every application with an `AppShell`) mounts with `Elm.Main.init()`, no
`node`; a `Browser.element` takes `{ node: document.getElementById("app") }`. The stylesheet removes the margin of
the `body`, so the page needs no CSS. The routes are the part of the address after `#`, so any static server works.

**A backend.** Klar never sends a request. With `elm/http` in the application, turn the error into a problem once:

```elm
toProblem : Http.Error -> Remote.Problem
toProblem error =
    case error of
        Http.Timeout -> Remote.problem Remote.timeout
        Http.NetworkError -> Remote.problem Remote.network
        Http.BadStatus 404 -> Remote.problem Remote.notFound
        Http.BadStatus 403 -> Remote.problem Remote.forbidden
        _ -> Remote.problem Remote.unknown
```

and `Remote.settle model.orders (Result.mapError toProblem result)` is the `Remote` you give the component.

**For the `CLAUDE.md` of the application** (with the path where Klar lives):

> This application uses Klar (`vendor/klar`), a UI toolkit for Elm. Use only the modules Klar exposes (`Klar.*`,
> listed in `vendor/klar/elm.json`), never `Klar.Internal.*`, and never copy or edit a Klar file. Before you write a
> screen, read `vendor/klar/AI.md` and search `vendor/klar/ai/klar-index.json`; then read
> `vendor/klar/ai/modules/<Module>.md` for the modules you use and the nearest program in
> `vendor/klar/example/src/Examples/`. Never write your own popup, dialog, focus, scroll, date, keyboard or
> virtual-list code, no CSS, no `class`, no `style`, no JavaScript. Keep ids as your own types and backend data as
> `Remote`. If Klar lacks something, write the best honest version with `-- KLAR GAP: <what is missing>` above it.

## Links

[ai/klar-index.json](ai/klar-index.json) | [ai/modules/README.md](ai/modules/README.md) | [example/src/Examples/](example/src/Examples)
