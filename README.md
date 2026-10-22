# Klar

**Precise, data-dense interface components for data-intensive Elm applications.**

*Klar* is Norwegian for "clear" and "ready". The idea is a user interface for
applications where people work with a lot of data all day: tables with thousands of
rows, searchable lists with thousands of options, filters, rules, dates, forms,
dialogs. It is calm, small-typed and exact, and it never makes the user wonder what
state the data is in.

```elm
Table.view TableMsg
    [ Table.columns
        [ Table.text (Table.columnId "id") "Order" .id [ Table.pinned ]
        , Table.text (Table.columnId "customer") "Customer" .customer [ Table.filterText ]
        , Table.float (Table.columnId "total") "Total" 2 .total [ Table.footerSum ]
        ]
    , Table.rows model.orders -- a Remote (List Order): loading, failure and empty are drawn for you
    , Table.rowId orderRows .id -- your own OrderId; see Table.rowIds
    , Table.searchable
    , Table.selectable
    , Table.onRetry Reload
    ]
    model.table
```

* **A complete toolkit.** About ninety components: a data table (client and server
  mode), searchable selects and tree pickers, date, time and recurrence pickers, exact
  money and checksum-checked identifiers, a rule builder and filter bar, dialogs and
  drawers, toasts, a command palette, charts, trees, timelines, drag-to-reorder lists,
  resizable panes, diffs, a safe Markdown renderer and the frame of an application.
* **Plain Elm, plain CSS.** The package depends only on official `elm/*` packages:
  `core`, `html`, `browser`, `json`, `time`, `url` and `file` (`file` only for
  `Klar.FileDrop`). No ports, no JavaScript, no `elm/svg`, no `elm/http`, no external
  fonts, no CDN.
* **Zero setup.** The stylesheet is part of the package: put `Klar.stylesheet` in your
  view and you are done.
* **Every state, always.** Components that show data from a backend take a `Remote`
  and draw loading, failure (with retry), empty and data themselves.
* **Keyboard first, accessible by design.** Roles, `aria-*` wiring, focus that never
  disappears, announcements for async changes.
* **Honest with input.** A number outside its range is shown with an error, never
  quietly changed. Formatting rounds the way a person would by hand.
* **Built-in text in English and Norwegian Bokmål** (`Klar.Locale`).

## Install

```bash
elm install davidtoska/elm-klar
```

Klar works with Elm 0.19.x (developed and tested with 0.19.3). To use it before it
is published, or to keep an exact, untouched copy in an application, see
[USING.md](USING.md).

An AI that builds the application starts with [AI.md](AI.md) (and [llms.txt](llms.txt)):
the mental model, the ten rules, which module to use for what, and complete programs in
[recipes/](recipes/README.md) and [template/](template/README.md).

## A first program

```elm
module Main exposing (main)

import Browser
import Html exposing (Html)
import Klar
import Klar.Button as Button
import Klar.Card as Card
import Klar.Icon as Icon
import Klar.Layout as Layout
import Klar.TextInput as TextInput


type alias Model =
    { customer : String }


type Msg
    = CustomerChanged String
    | Save


main : Program () Model Msg
main =
    Browser.sandbox
        { init = { customer = "" }
        , update = update
        , view = view
        }


update : Msg -> Model -> Model
update msg model =
    case msg of
        CustomerChanged customer ->
            { model | customer = customer }

        Save ->
            model


view : Model -> Html Msg
view model =
    Layout.stack [ Layout.gap 4 ]
        [ -- once, anywhere in the view: the stylesheet of the package
          Klar.stylesheet
        , Card.view [ Card.title "New order" ]
            [ TextInput.view
                [ TextInput.label "Customer"
                , TextInput.value model.customer
                , TextInput.onInput CustomerChanged
                , TextInput.required
                ]
            , Button.view [ Button.primary, Button.icon Icon.save, Button.onClick Save ] "Save"
            ]
        ]
```

This program is mounted with `Elm.Main.init({ node: document.getElementById("app") })`,
because `Browser.sandbox` and `Browser.element` need a node. A whole application with
the `AppShell` is a `Browser.application` (or `Browser.document`) and is mounted with
plain `Elm.Main.init()`; it also needs `elm/url` as a direct dependency. The shell keeps
its sidebar, drawer, side menu and skip link in one `AppShell.State`, so the wiring in
your `update` is one `ShellMsg` branch that tells you when the route changed. The complete
recipe, with `index.html`, is "Start here" in [USING.md](USING.md).

Components are configured with a list of attributes, like `Html`. A component that
has state of its own (a select that is open, a table that is sorted) comes with
`State`, `Msg`, `update` and `view`, and is wired like any child in the Elm
Architecture. The conventions are described in the [`Klar`
module](https://package.elm-lang.org/packages/davidtoska/elm-klar/latest/Klar) and
every module has an example.

## What is in it

| | Modules |
| --- | --- |
| **Foundations** | `Theme`, `Settings`, `Locale`, `Layout`, `Card`, `Text`, `Icon` |
| **Icon library** | 500 icons in one style: `Icon` and `Icon.Library`, plus `Icon.Arrows`, `Icon.Business`, `Icon.Data`, `Icon.Documents`, `Icon.Logistics` and more (see [ICONS.md](ICONS.md)) |
| **Actions** | `Button`, `Menu`, `ButtonGroup`, `ToggleGroup`, `SplitButton`, `Link`, `Kbd` |
| **Status and feedback** | `Badge`, `Tag`, `Alert`, `Spinner`, `Skeleton`, `Progress`, `EmptyState`, `ErrorState` |
| **Forms** | `Form` (the form model), `Form.Spec` (declaring a form), `Form.Layout` (the frame), `Form.Check` (tests), `Ids`, `Field`, `Validate` |
| **Inputs** | `TextInput`, `TextArea`, `NumberInput`, `PasswordInput`, `SearchInput`, `TagInput`, `FileDrop`, `InlineEdit`, `Checkbox`, `CheckboxGroup`, `Radio`, `Switch`, `Slider`, `SegmentedControl`, `MaskedInput`, `Money`, `MoneyInput` |
| **Choosing** | `Select`, `MultiSelect`, `Autocomplete`, `VirtualList`, `TreeSelect`, `Cascader`, `Transfer`, `Picking` |
| **Date and time** | `Date`, `DatePicker`, `DateRangePicker`, `TimePicker`, `DateTimePicker`, `Calendar`, `Recurrence`, `RecurrencePicker` |
| **Tables and lists** | `Table`, `ServerList`, `Pagination`, `ListItem`, `Tree` |
| **Overlays** | `Overlay`, `Modal`, `ConfirmDialog`, `Drawer`, `Toast`, `Popover`, `Tooltip`, `ContextMenu`, `CommandPalette`, `ShortcutHelp` |
| **Navigation** | `AppShell`, `SideNav`, `PageHeader`, `Breadcrumbs`, `Tabs`, `Stepper` |
| **Structure** | `Accordion`, `Toolbar`, `DescriptionList` |
| **Arranging** | `Sortable`, `Splitter` |
| **Pages and flow** | `StatusPage`, `BulkBar`, `LeaveGuard`, `History` |
| **Text and change** | `Markdown`, `MarkdownEditor`, `Diff`, `Compare` |
| **Access and approval** | `PermissionMatrix`, `ApprovalFlow` |
| **Data display** | `Stat`, `Chart` (line, bar, donut, gauge, meter, sparkline), `Timeline`, `Avatar`, `JsonViewer` |
| **Rules and filters** | `Rule`, `RuleBuilder`, `FilterBar`, `SavedViews` |
| **Data and utilities** | `Remote`, `RemoteView`, `Search`, `Format`, `Shortcut` |

All of them are under `Klar.`, for example `Klar.Table`. The API reference is on
[package.elm-lang.org](https://package.elm-lang.org/packages/davidtoska/elm-klar/latest/).

Some of the pure modules are useful on their own:

* `Klar.Date`: calendar dates without a time zone, exact arithmetic.
* `Klar.Format`: numbers, currency, percentages, sizes, durations and relative times.
  Rounding works on the shortest decimal text, so `Format.decimal Locale.en 2 1.005` is
  `"1.01"`, not `"1.00"`.
* `Klar.Search`: search that ignores case and diacritics and ranks results.
* `Klar.Validate`: composable validators with messages in two languages.
* `Klar.Rule`: a tree of conditions, evaluated against your own records, with JSON.
* `Klar.Remote`: `NotAsked | Loading | Loaded a | Failed Problem | Kept (Kept a)`.

## The showcase

[`example/`](example) is a complete application built only with this package: an
operations console with a dashboard, orders (a server-mode table with a drawer
editor), products, and a gallery with live examples of every component and state.
Its backend is a dummy written in Elm, behind a request/response layer, with
developer tools that make the pretend network fail so you can see how the interface
behaves.

```bash
npm install     # once; installs elm-test and elm-format, nothing else
npm start       # builds the showcase and serves it on http://localhost:8000
```

Press `Ctrl K` for the command palette and `?` for the keyboard shortcuts.

## Styling

`Klar.stylesheet` renders a `<style>` element with every rule of the library. It
includes a small reset (box sizing, the page font and background, links, tables,
focus rings), so Klar assumes that it owns the page. If your content security policy
forbids inline styles, link the same file instead:
[`css/klar.css`](css/klar.css) (copy it to your static files, or serve it from
the tagged release), and leave out `Klar.stylesheet`.

The look is made of design tokens, CSS custom properties that components use instead
of fixed colors, sizes and radii. Redefine them after the library's CSS to restyle
everything at once:

```css
:root {
  --klar-primary: #0b7285;
  --klar-primary-hover: #095c6b;
  --klar-font: "Inter", system-ui, sans-serif;
}
```

The tokens are listed in the documentation of `Klar.Theme`.

## Browsers

Klar is built for current evergreen browsers. Popups (selects, menus, date pickers)
use CSS anchor positioning where the browser has it, so they are never clipped by a
scrolling parent and flip when there is no room, and fall back to plain positioning
where it does not. It was developed and tested in Chromium, with real key presses and
pointer events. Firefox and Safari, touch screens, screen readers, high-contrast mode
and a dark theme have not been tested systematically (there is no dark theme yet).

## Accessibility

Components follow the WAI-ARIA authoring practices: roles and properties, keyboard
operation, focus that goes back to where it came from, live regions for changes that
arrive later. The colors of the default look meet the WCAG 2.2 AA contrast ratios, and
the application pages of the showcase pass the automated
[axe-core](https://github.com/dequelabs/axe-core) checks for WCAG 2.2 AA. Automated
checks find only a part of the problems, and the library has not been tested with
screen readers yet; reports are welcome.

## Stability

Elm checks the version number of every release against its public API. Klar keeps the
API small on purpose: sets that will grow, such as the icons and the languages, are
values of an opaque type, so adding to them is never a breaking change.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for the conventions, the documentation style and
the checks (`npm run check`), and [RELEASING.md](RELEASING.md) for how a version is
published.

## License

[BSD 3-Clause](LICENSE). The icons are based on [Feather](https://feathericons.com)
and [Lucide](https://lucide.dev); see [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md).
