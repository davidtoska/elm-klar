# Klar for an AI that builds an application

Klar is an Elm package (`davidtoska/elm-klar`, modules `Klar.*`) for precise, data-dense
applications: tables with 50 000 rows, filters, forms, dialogs, dashboards. You build the
application, a person reviews it. An application is **Klar plus your own Elm code**: no CSS, no
JavaScript, no class names, no `style`.

Read in this order, and stop when you can write the screen: this file; `ai/klar-index.json` (search
`keywords`, `purpose`, `whenToUse`, `whenNot`, `quickPath`, `related` before you open anything);
`ai/modules/<Module>.md` (every signature, then the documentation; the long ones start with a Quick
path); `recipes/<name>/src/Main.elm` (six compiled screens) and `template/` (the starting
application); `USING.md` (project set-up, a backend). Do not read `docs.json`, `src/`, `example/` or `apps/`.

## Start here

**The model.**

- **A component is `State` + `Msg` + `update` + `view`**, wired like any child in the Elm Architecture:
  `Foo.State` in your model, a `FooMsg Foo.Msg` in your `Msg`, `Foo.update m model.foo` with `Cmd.map FooMsg`,
  `Foo.view FooMsg [ attributes ] model.foo`. Read the value with `Foo.value model.foo` and compare before and
  after `update` to react. There are no out-messages.
- **A view-only component is one function and a list of attributes**: `Button.view [ Button.primary, Button.onClick Save ] "Save"`.
  Attributes are opaque; their order does not matter; the last one of a kind wins.
- **The `String` you give to `init` is the DOM id**, unique on the page. Keep them as named values in one place.
- **Backend data is a `Remote a`** (`NotAsked | Loading | Loaded a | Failed Problem`, and `Kept`, see the traps). Give it to
  `Table.rows`, `Stat.remote`, `Chart.remote`, `Tree.viewRemote`, `Select.options` ...: they draw the skeleton, the failure
  with retry and the empty state. Klar never sends a request; you turn the result into a `Remote` with `Remote.fromResult`.
- **Your ids are your own types**, given once: `Table.rowIds { toKey, fromKey }`, `Tree.nodeIds`, `SideNav.keys`, `Klar.Ids`.
  A table column is a `Table.columnId "total"`, named once.
- **Overlays go in one list**: `Modal`, `Drawer`, `ConfirmDialog`, `CommandPalette`, `ShortcutHelp`, `Toast`, `LeaveGuard` return an
  `Overlay`; give the list to `AppShell.overlays` (or `Overlay.host`). The layer makes the page inert and returns focus.
- **Dates are `Klar.Date`, money is `Klar.Money`, built-in text follows `Locale.en` or `Locale.nb`.**

**The frame.** There is one way to wire the application frame: `AppShell` keeps the sidebar, the drawer, the current link and
the key. The model holds `page : Page` and `shell : AppShell.State Page`; the messages hold one `ShellMsg AppShell.Msg`; `main` passes
`AppShell.onUrlRequest ShellMsg` and `AppShell.onUrlChange ShellMsg`; `init` makes the shell with `AppShell.init { id, key }` and
`AppShell.setPage navigation page`; `update` calls `AppShell.update` and gets `( shell, cmd, address )`. The **address** is the only place
that learns of a new route (a link, Back, a `pushUrl`): set `page` from it and call `AppShell.setPage` again. Following links,
`pushUrl`, scroll to the top, the drawer and its focus are done for you. You write no `LinkClicked`, `UrlChanged` or `SideNav.init`. Only
when a click must be held back (`LeaveGuard`) give `Browser.application` a `onUrlRequest` message of your own and call `Nav.pushUrl` when
it may go on; everything else stays. `elm.json` needs `elm/url` as a **direct** dependency, and `Elm.Main.init()` takes no `node`.

**The three rules that matter most.** (1) Backend data is a `Remote` given to the component, and ids are your own types.
(2) Every overlay is in the one overlay list, also while closed, and an opener has an id (`Button.id`). (3) You write no CSS, focus,
popup, scroll, date or keyboard code: if you feel you need it, a module does it (the table at the end).

## The standard application

This compiles as it stands (`npm run check:ai-names` compiles it). The full version with a confirmation dialog is `template/src/Main.elm`.

```elm
module Main exposing (main)

import Browser
import Browser.Navigation as Nav
import Html exposing (Html)
import Klar
import Klar.AppShell as AppShell
import Klar.Button as Button
import Klar.Icon as Icon
import Klar.PageHeader as PageHeader
import Klar.Remote as Remote exposing (Remote(..))
import Klar.SideNav as SideNav
import Klar.Table as Table
import Klar.Toast as Toast
import Process
import Task
import Url exposing (Url)


type Page
    = Orders
    | Settings


type alias Order =
    { id : String, customer : String, total : Float }


type alias Model =
    { page : Page
    , shell : AppShell.State Page
    , table : Table.State String
    , orders : Remote (List Order)
    , toasts : Toast.State Msg
    }


type Msg
    = ShellMsg AppShell.Msg
    | TableMsg Table.Msg
    | ToastMsg Toast.Msg
    | GotOrders (Result Remote.Problem (List Order))
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
      , shell = AppShell.init { id = "app-shell", key = key } |> AppShell.setPage navigation page
      , table = Table.init "orders"
      , orders = Loading
      , toasts = Toast.init
      }
    , fetchOrders
    )


fetchOrders : Cmd Msg
fetchOrders =
    -- stands for a request: Http.get, then Result.mapError toProblem
    Process.sleep 600
        |> Task.map (\_ -> Ok [ Order "1042" "Aurora Logistics" 1250.5, Order "1043" "Fjord Foods" 310 ])
        |> Task.perform GotOrders


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

        GotOrders result ->
            let
                ( toasts, cmd ) =
                    Toast.push [ Toast.success, Toast.message "Orders loaded." ] model.toasts
            in
            ( { model | orders = Remote.fromResult result, toasts = toasts }, Cmd.map ToastMsg cmd )

        Reload ->
            ( { model | orders = Loading }, fetchOrders )


view : Model -> Browser.Document Msg
view model =
    { title = "Acme Operations"
    , body =
        [ Klar.stylesheet
        , AppShell.view
            [ AppShell.state ShellMsg model.shell
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
                        , Table.float (Table.columnId "total") "Total" 2 .total [ Table.footerSum ]
                        ]
                    , Table.rows model.orders
                    , Table.rowId Table.stringIds .id
                    , Table.onRetry Reload
                    ]
                    model.table
                ]

        Settings ->
            PageHeader.view [ PageHeader.title "Settings" ]


pageKeys : SideNav.Keys Page
pageKeys =
    SideNav.keys
        (\page ->
            case page of
                Orders ->
                    "orders"

                Settings ->
                    "settings"
        )


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
2. **No CSS, no class, no `style`, no `Html.node "style"`.** Put `Klar.stylesheet` once in the view. Looks come from `Theme` values, layout from `Klar.Layout`, text from `Klar.Text`.
3. **Your own id types.** A `type OrderId = OrderId Int`, with `toKey` and `fromKey` given once; DOM ids and column ids are named values.
4. **Backend data is a `Remote`.** Do not write its cases; give it to the component. Turn your error into `Remote.problem Remote.timeout` (or `network`, `notFound`, `forbidden`, `server` ...).
5. **Overlays go in the overlay list**, always, also while closed. Give the opener an id (`Button.id`) and pass it to `open`.
6. **Never write focus, popup, scroll, date or keyboard code.** No `Browser.Dom.focus` for a dialog, no click-outside, no positioning, no `Time` arithmetic. Find the module in the table below.
7. **Dates are `Klar.Date`, money is `Klar.Money`, numbers and dates for people come from `Klar.Format`.** A `Time.Posix` is needed once, for today.
8. **Forms use `Klar.Form`** (declared with `Klar.Form.Spec`, framed with `Klar.Form.Layout`). Server problems go in with `Form.rejected`, steps with `Form.advance`; do not keep a second copy of field values or of the problems.
9. **Server mode is four steps**: compare `Table.query` (and the `FilterBar` rule) before and after `update`; `Table.setPage 1` when the rule changed; ask with a new ticket; drop an answer whose ticket is not the latest (`recipes/inbox`). **Do not debounce** what Klar already waits for: the table waits 350 ms after typing in its search box and filter fields in server mode (`Table.searchDebounce`), the filter bar changes its rule only when the user applies a filter, and a sort click or a page change must ask at once. Debounce only what Klar does not: the query of a `CommandPalette.remote` section (a counter, see its doc) and text you read from a field of your own (use `SearchInput`, which waits 300 ms).
10. **When Klar lacks something, say so.** Write the best honest version, put a comment `-- KLAR GAP: what is missing` above it, and carry on. Do not copy a component, wrap it in your own CSS or import an internal module.

## Small things that come up

- **A day count from a data set to a date and back**: `Date.fromEpochDay (baseDay + n)` and `Date.toEpochDay date - baseDay` (day 0 is 1 January 1970); `Date.addDays` and `Date.diffDays` do the rest.
- **A price rule ("if the category is X and the quantity above Y, take Z off")**: `Rule` and `RuleBuilder` hold only the condition. The outcome is yours: one `RuleBuilder.State` per outcome in a list, `{ when : RuleBuilder.State, discountPercent : Float }`, and `Rule.matches today fields (RuleBuilder.rule r.when) row` to ask a row. The example is in `ai/modules/Klar.RuleBuilder.md`.
- **A failed save with "Try again"**: `FormLayout.onRetry` gets its own message, and that branch runs the save and `FormLayout.focusStatus`; "Try again" is replaced by "Saving ..." and focus would fall to the page. Server problems per field are `Form.rejected`, which also focuses the summary (`recipes/edit-form`).
- **Leaving a page with unsaved work**: `LeaveGuard`, six functions, one complete program at the top of its doc. Call `setDirty` in the branches of the messages that edit a form, never in a wrapper after every message, and reset the form you leave when the user answers "Leave" (`recipes/multi-step`).
- **A sidebar that is not a `SideNav`**: `AppShell.sidebar` takes any `Html` (a `Tree`, a list of saved views).

## Common traps

Each is checked against the current source; the ones the library has fixed are gone.

- **Give a component its data once.** `Chart.remote`, `Stat.remote`, `Table.rows` take a `Remote`, including its old data; do not add `loading` or `failed` next to them.
- **`Remote` has a fifth constructor, `Kept`** (old data while a refresh runs, or after it failed). A `case` of your own needs a branch for it, or use `Remote.toMaybe` / `RemoteView.view`. Start a refresh with `Remote.refresh`, finish it with `Remote.refreshWith old result now`; never write a failed refresh over good data.
- **A `Modal` with a text field opens with focus on the dialog.** Use `Modal.openWith { opener = id, focus = [ fieldId ] }`.
- **Focus returns to an opener only if it has an id** (`Button.id`, a `SideNav` link, a field). Without one it goes to the last element that had an id, which may be elsewhere (`LeaveGuard` "Stay" too).
- **A `ConfirmDialog` may hold one or two controls in `body`** (a reason, a target); a real form is a `Modal`. **Server-mode `Table.exportCsv`** offers the selection only while every selected row is on the page; export from the backend for a selection that spans pages.
- **`Table.activeExternalFilters n`** tells "no matches" from "no data" for filters outside the table; wire `onResetFilters` once to clear the filter bar and the table's own filters.
- **The first type parameter of `Form` and `Form.State` is the step type** (`()` for a form without steps). Declare the form in `Klar.Form.Spec` once, at the top of a file.
- **`Rule.choiceField` values are `String`s.** For your own id type use `Rule.choiceFieldOf` with `Klar.Ids`.
- **Toasts move to the top while a dialog or drawer is open** and can cover the drawer title for a few seconds.
- **`Card.title` is an `h2`, and so is a `Form.Layout.section` title.** A card inside a section, or under any `h2`, needs `Card.headingLevel 3`.
- **The page needs an `h1` in every state.** A `RemoteView` or `ErrorState` draws none while it loads or has failed, so keep the `PageHeader` outside it. Their "Try again" also loses keyboard focus (a known gap): follow the retry with `AppShell.goToContent model.shell |> Cmd.map ShellMsg`.
- **`Time.Posix` is needed once**, for today (`Date.fromPosix`); `Remote.refreshWith` also takes the time of the answer.

## I need X, use module Y

Each module is `Klar.<Name>`; details in `ai/modules/Klar.<Name>.md`.

**Foundations and structure**
- Whole-application frame, top bar, sidebar, scrolling content, overlay list: `AppShell`. Side menu typed by your pages: `SideNav`. Title, actions, tabs of a page: `PageHeader`. Path to the page: `Breadcrumbs`.
- Tone, size, density shared by all components: `Theme`. Language (`Locale.en`, `Locale.nb`): `Locale`. Stack, row, grid, spacing, fill the rest: `Layout`. A bordered group: `Card`. Titles and paragraphs: `Text`. An icon: `Icon` (everyday set) and `Icon.Library` (all of them) and by category `Icon.Arrows`, `Icon.Business`, `Icon.Calendar`, `Icon.Communication`, `Icon.Data`, `Icon.Developer`, `Icon.Devices`, `Icon.Documents`, `Icon.Editor`, `Icon.Interface`, `Icon.Logistics`, `Icon.Media`, `Icon.Nature`, `Icon.People`, `Icon.Science`.
- Sections that open and close: `Accordion`. A row of grouped actions: `Toolbar`. Label and value pairs: `DescriptionList`. Switch views of one thing: `Tabs`. Wizard steps (draws only): `Stepper`.
- Resize panes: `Splitter`. Reorder a list: `Sortable`. `Klar` itself is `Klar.stylesheet` (put it in the view once).

**Actions and feedback**
- Button or link-looking button: `Button`. Group of buttons: `ButtonGroup`. Main action plus alternatives: `SplitButton`. Choose on/off options: `ToggleGroup`. Actions in a dropdown: `Menu`. Right-click menu: `ContextMenu`. A real link that cannot leave the app by accident: `Link`. Key caps ("Ctrl K"): `Kbd`.
- State label ("Paid"): `Badge`. Chip the user can remove: `Tag`. Inline message: `Alert`. Message that goes away: `Toast`. Loading: `Spinner` (inline) or `Skeleton` (shape of the content) or `Progress`. Nothing to show: `EmptyState`. A request failed: `ErrorState`. A whole result page ("Not found", "Order created"): `StatusPage`.

**Overlays**
- The layer itself (focus, inert page, toasts): `Overlay`. Dialog with a form: `Modal`. "Are you sure?" with busy and failure: `ConfirmDialog`. Details beside a list: `Drawer`. Small anchored panel: `Popover`. Hint on hover or focus: `Tooltip`. One search box for commands and content (`Ctrl K`): `CommandPalette`. Shortcut cheat sheet: `ShortcutHelp`. Global keys, sequences: `Shortcut`. "12 selected: Export, Delete": `BulkBar`.
- Ask before leaving with unsaved input: `LeaveGuard`. Undo and redo of a value: `History`.

**Tables, lists and data**
- Records with search, sort, filters, selection, paging, 50 000 rows, server mode: `Table` (`Table.virtual` for scrolling). Page controls alone: `Pagination`. A dense row with title, meta, actions: `ListItem`. A very long plain list: `VirtualList`. Hierarchy: `Tree`.
- KPI number: `Stat`. Line, bar, donut, gauge, sparkline: `Chart`. History of events: `Timeline`. Person or system badge: `Avatar`. A JSON value: `JsonViewer`.
- Data state from a backend, with old data kept while it refreshes: `Remote`. The body of a card, dialog or drawer from a `Remote`: `RemoteView`. Forgiving text matching and ranking: `Search`. Numbers, sizes, dates, money text: `Format`.

**Rules, filters, change**
- A condition tree as data (encode, decode, run on rows, describe): `Rule`. Edit one: `RuleBuilder`. Chips above a table: `FilterBar`. Named filters: `SavedViews`. A server-side list with all three and no glue: `ServerList`.
- Text diff, JSON diff, record diff: `Diff`. Records side by side: `Compare`. Safe Markdown to HTML: `Markdown`. Edit Markdown with preview: `MarkdownEditor`.
- Roles by permissions grid: `PermissionMatrix`. Approval steps and decisions: `ApprovalFlow`.

**Forms and inputs**
- The whole form (fields, dirty, server problems, steps, rows): `Form`; its declaration: `Form.Spec`; its tests: `Form.Check`. The frame (sections, grid, buttons, submit state): `Form.Layout`. The wrapper of one control (label, hint, error): `Field`. Validators: `Validate`. How your id type is written as text, once: `Ids`.
- Text: `TextInput`, `TextArea`, `PasswordInput`, `SearchInput` (waits for a pause), `TagInput`, `InlineEdit` (click to edit), `MaskedInput` (IBAN, postal code, phone). Number: `NumberInput`, `Slider`. Money: `Money`, `MoneyInput`. Files: `FileDrop`.
- Choose: `Checkbox`, `CheckboxGroup`, `Radio`, `Switch`, `SegmentedControl` (one of a few). `Select` (one of many, searchable; `Select.Option` is its option type), `MultiSelect`, `Autocomplete` (suggestions), `TreeSelect`, `Cascader` (a path through levels), `Transfer` (two lists), `Picking` (the node type the last three share).

**Date and time**
- The date type: `Date`. A date field: `DatePicker`. A period: `DateRangePicker`. Time: `TimePicker`. Both: `DateTimePicker`. A month with marks: `Calendar`. "Every second Tuesday": `Recurrence` with `RecurrencePicker`.

## Links

[llms.txt](llms.txt) | [ai/klar-index.json](ai/klar-index.json) | [ai/modules/README.md](ai/modules/README.md) | [USING.md](USING.md) | [recipes/README.md](recipes/README.md) | [template/README.md](template/README.md) | [bench/README.md](bench/README.md) | [CONTRIBUTING.md](CONTRIBUTING.md)
