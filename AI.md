# Klar for an AI that builds an application

Klar is an Elm package (`davidtoska/elm-klar`, modules `Klar.*`) for precise, data-dense
applications: tables with 50 000 rows, filters, forms, dialogs, dashboards. You build the
application, a person reviews it. An application is **Klar plus your own Elm code**: no CSS, no
JavaScript, no class names, no `style`.

Read in this order, and stop when you can write the screen:

1. This file (about 10 minutes).
2. `ai/klar-index.json`: search `keywords`, `purpose`, `whenToUse`, `whenNot`, `related` before you open anything.
3. `ai/modules/<Module>.md`: every signature first, then the documentation. `ai/modules/README.md` lists them.
4. `recipes/<name>/src/Main.elm`: a complete compiled program for the six common screens. `template/`: the starting application.
5. `USING.md`: getting Klar into a project, `elm.json`, `index.html`, talking to a backend.

Do not read `docs.json`, `src/`, `example/` or `apps/`. Everything you need is in the files above.

## The mental model

- **A component is `State` + `Msg` + `update` + `view`**, wired like any child in the Elm
  Architecture. Keep `Foo.State` in your model, a `FooMsg Foo.Msg` in your `Msg`, call
  `Foo.update m model.foo` and `Cmd.map FooMsg`, and `Foo.view FooMsg [ attributes ] model.foo`.
  The state holds the value: read it with `Foo.value model.foo` and compare before and after
  `update` to react. There are no out-messages.
- **A view-only component is one function with a list of attributes**: `Button.view [ Button.primary, Button.onClick Save ] "Save"`.
  Attributes are opaque values of the module; their order does not matter; the last one of a kind wins.
- **The `String` you give to `init` is the DOM id** and must be unique on the page. Keep them as named values in one place.
- **Data from a backend is a `Remote a`**: `NotAsked | Loading | Loaded a | Failed Problem`. Give it to
  `Table.rows`, `Stat.remote`, `Chart.remote`, `Tree.viewRemote`, `Timeline.remote`,
  `Select.options` ... and they draw the skeleton, the failure with retry and the empty state.
  Klar never sends a request. You turn the result into a `Remote` (`Remote.fromResult`).
- **Your ids are your own types.** `Table.rowIds { toKey, fromKey }` once, then `Table.selectedIds`
  returns `List OrderId`. The same for `Tree.nodeIds`, `SideNav.keys`, `Select.option id label`,
  `Picking.ids`, `Klar.Ids` (`Ids.make`, once). Never pass a bare `String` where an id belongs. A table column is a
  `Table.columnId "total"`, named once.
- **Overlays go in one list.** `Modal`, `Drawer`, `ConfirmDialog`, `CommandPalette`, `ShortcutHelp` and `Toast`
  return an `Overlay`. Give the list to `AppShell.overlays` (or `Overlay.host`). The layer makes the page inert, keeps
  the toasts reachable and returns focus to the opener. You write no focus code.
- **Dates are `Klar.Date`** (no time zone, no 31 February), money is `Klar.Money` (minor units), text you write
  yourself is plain `String`, built-in text follows `Locale.en` or `Locale.nb`.
- **A form is `Klar.Form`**: declare it once with `Klar.Form.Spec`, keep one `Form.State` and one `Form.Msg`, get the record back with `Form.toValues`.
- **Navigation is hash routes** in a `Browser.application`: `AppShell` + `SideNav`, a `Page` type of your own.

## The standard application

This compiles as it stands (`npm run check:ai-docs` compiles it). `elm.json` needs `elm/browser`, `elm/core`,
`elm/html`, `elm/json`, `elm/time` and **`elm/url` as direct dependencies**; mount it with `Elm.Main.init()` (no
`node`). The full version with a confirmation dialog is `template/src/Main.elm`.

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
    { key : Nav.Key
    , page : Page
    , sideNav : SideNav.State Page
    , table : Table.State String
    , orders : Remote (List Order)
    , toasts : Toast.State Msg
    }


type Msg
    = LinkClicked Browser.UrlRequest
    | UrlChanged Url
    | SideNavMsg SideNav.Msg
    | TableMsg Table.Msg
    | ToastMsg Toast.Msg
    | GotOrders (Result Remote.Problem (List Order))
    | Reload
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


init : () -> Url -> Nav.Key -> ( Model, Cmd Msg )
init _ url key =
    let
        page =
            pageFromUrl url
    in
    ( { key = key
      , page = page
      , sideNav = SideNav.init "main-nav" |> SideNav.reveal page navigation
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
        LinkClicked (Browser.Internal url) ->
            ( model, Nav.pushUrl model.key (Url.toString url) )

        LinkClicked (Browser.External href) ->
            ( model, Nav.load href )

        UrlChanged url ->
            let
                page =
                    pageFromUrl url
            in
            ( { model | page = page, sideNav = SideNav.reveal page navigation model.sideNav }
            , AppShell.resetScroll "shell" NoOp
            )

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

        NoOp ->
            ( model, Cmd.none )


view : Model -> Browser.Document Msg
view model =
    { title = "Acme Operations"
    , body =
        [ Klar.stylesheet
        , AppShell.view
            [ AppShell.id "shell"
            , AppShell.brand (AppShell.brandLink { name = "Acme Operations", href = "#/", logo = Nothing })
            , AppShell.sidebar (SideNav.view SideNavMsg [ SideNav.entries navigation, SideNav.current model.page ] model.sideNav)
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
4. **Backend data is a `Remote`.** Do not write the four cases; give the `Remote` to the component. Turn your error into `Remote.problem Remote.timeout` (or `network`, `notFound`, `forbidden`, `server` ...).
5. **Overlays go in the overlay list**, always, also while closed. Give the opener an id (`Button.id`) and pass it to `open`.
6. **Never write focus, popup, scroll, date or keyboard code.** No `Browser.Dom.focus` for a dialog, no click-outside, no positioning, no `Time` arithmetic. If you feel you need it, find the module in the table below.
7. **Dates are `Klar.Date`, money is `Klar.Money`, numbers and dates for people come from `Klar.Format`.** A `Time.Posix` is needed once, for today.
8. **Forms use `Klar.Form`** (declared with `Klar.Form.Spec`, framed with `Klar.Form.Layout`). Server problems go in with `Form.rejected`, steps with `Form.advance`; do not keep a second copy of field values or of the problems.
9. **Server mode is the same four steps everywhere**: compare the query before and after `update`, reset the page to 1 when a filter changed, debounce, and ticket the answer so a late one is dropped. See `recipes/inbox`.
10. **When Klar lacks something, say so.** Write the best honest version, put a comment `-- KLAR GAP: what is missing` above it, and carry on. Do not copy a component, wrap it in your own CSS or import an internal module.

## I need X, use module Y

Each module is `Klar.<Name>`; details in `ai/modules/Klar.<Name>.md`.

**Foundations and structure**
- Whole-application frame, top bar, sidebar, scrolling content, overlay list: `AppShell`. Side menu typed by your pages: `SideNav`. Title, actions, tabs of a page: `PageHeader`. Path to the page: `Breadcrumbs`.
- Density and time zone of the whole application, stated once: `Settings` (`AppShell.settings model.settings` for the density; `X.settings model.settings` on a component that writes a time, with `Time.here` at the start; without a zone a time ends in "UTC"). Tone, size, density types shared by all components: `Theme`. Language (`Locale.en`, `Locale.nb`): `Locale`. Stack, row, grid, spacing, fill the rest: `Layout`. A bordered group: `Card`. Titles and paragraphs: `Text`. An icon: `Icon` (everyday set) and `Icon.Library` (all of them) and by category `Icon.Arrows`, `Icon.Business`, `Icon.Calendar`, `Icon.Communication`, `Icon.Data`, `Icon.Developer`, `Icon.Devices`, `Icon.Documents`, `Icon.Editor`, `Icon.Interface`, `Icon.Logistics`, `Icon.Media`, `Icon.Nature`, `Icon.People`, `Icon.Science`.
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
- A condition tree as data (encode, decode, run on rows, describe): `Rule`. Edit one: `RuleBuilder`. Chips above a table: `FilterBar`. Named filters: `SavedViews`.
- Text diff, JSON diff, record diff: `Diff`. Records side by side: `Compare`. Safe Markdown to HTML: `Markdown`. Edit Markdown with preview: `MarkdownEditor`.
- Roles by permissions grid: `PermissionMatrix`. Approval steps and decisions: `ApprovalFlow`.

**Forms and inputs**
- The whole form (fields, dirty, server problems, steps, rows): `Form`; its declaration: `Form.Spec`; its tests: `Form.Check`. The frame (sections, grid, buttons, submit state): `Form.Layout`. The wrapper of one control (label, hint, error): `Field`. Validators: `Validate`. How your id type is written as text, once: `Ids`.
- Text: `TextInput`, `TextArea`, `PasswordInput`, `SearchInput` (waits for a pause), `TagInput`, `InlineEdit` (click to edit), `MaskedInput` (IBAN, postal code, phone). Number: `NumberInput`, `Slider`. Money: `Money`, `MoneyInput`. Files: `FileDrop`.
- Choose: `Checkbox`, `CheckboxGroup`, `Radio`, `Switch`, `SegmentedControl` (one of a few). `Select` (one of many, searchable; `Select.Option` is its option type), `MultiSelect`, `Autocomplete` (suggestions), `TreeSelect`, `Cascader` (a path through levels), `Transfer` (two lists), `Picking` (the node type the last three share).

**Date and time**
- The date type: `Date`. A date field: `DatePicker`. A period: `DateRangePicker`. Time: `TimePicker`. Both: `DateTimePicker`. A month with marks: `Calendar`. "Every second Tuesday": `Recurrence` with `RecurrencePicker`.

## Common traps
## Common traps

Found while building three applications twice. Those the library has fixed since are gone; each one left is checked against the current source.

- **Attribute order is free, but the last of a kind wins.** Give a component its data once: `Chart.remote`, `Stat.remote`, `Table.rows` take a `Remote`, including its old data (`Kept`). Do not add `loading` or `failed` next to them.
- **`Remote` has a fifth constructor, `Kept`** (old data while a refresh runs or after it failed). A `case` on a `Remote` needs a branch for it, or use `Remote.toMaybe` / `RemoteView.view`. Start a refresh with `Remote.refresh` and finish it with `Remote.refreshWith old result now`; do not write a failed refresh over good data.
- **A `Modal` with a text field opens with focus on the dialog.** Use `Modal.openWith { opener = id, focus = [ fieldId ] }`.
- **Focus returns to an opener only if it has an id.** `Button.id` for a button that opens a dialog; a link or row without an id returns focus to the last element that had one, which may be elsewhere (`LeaveGuard` "Stay" too).
- **Server-mode `Table.exportCsv` offers the selection only while every selected row is on the page.** Export from the backend for a selection that spans pages.
- **`Table.activeExternalFilters n`** only tells "no matches" from "no data"; wire `onResetFilters` once to clear the filter bar and the table's own filters.
- **11 columns do not fit next to the sidebar at 1280 px**; the footer sums can end up behind a scroll. Set `minWidth`, `hiddenByDefault` or a narrower column.
- **`Klar.Form` is the form model**, and its layout functions are in `Klar.Form.Layout`. Declare in `Klar.Form.Spec` once at the top of a file; the first type parameter of `Form` and `State` is the step type (`()` for a form without steps).
- **`Rule.choiceField` values are `String`s.** For your own id type use `Rule.choiceFieldOf` with `Klar.Ids`.
- **Toasts move to the top while a dialog or drawer is open** and cover the drawer title for a few seconds.
- **`Time.Posix` is needed once**, for today (`Date.fromPosix`); `Remote.refreshWith` also takes the time of the answer.
- **`import Url` needs `elm/url` as a direct dependency**, and `Elm.Main.init()` for `Browser.application` takes no `node` (`Browser.element` does).

## Links

[llms.txt](llms.txt) | [ai/klar-index.json](ai/klar-index.json) | [ai/modules/README.md](ai/modules/README.md) | [USING.md](USING.md) | [recipes/README.md](recipes/README.md) | [template/README.md](template/README.md) | [bench/README.md](bench/README.md) | [CONTRIBUTING.md](CONTRIBUTING.md)
