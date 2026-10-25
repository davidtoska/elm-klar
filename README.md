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
    , Table.rowId orderIds .id -- your own OrderId, written as text once with Klar.Ids
    , Table.searchable
    , Table.selectable
    , Table.onRetry Reload
    ]
    model.table
```

* **A complete toolkit.** More than a hundred components: a data table (client and server
  mode), searchable selects and tree pickers, date, time and recurrence pickers, exact
  money and checksum-checked identifiers, a rule builder and filter bar, dialogs and
  drawers, toasts, a command palette, charts, trees, timelines, drag-to-reorder lists,
  resizable panes, diffs, a safe Markdown renderer and the frame of an application.
* **Plain Elm, plain CSS.** The package depends only on official `elm/*` packages:
  `core`, `html`, `browser`, `json`, `time`, `url` and `file` (`file` only for
  `Klar.FileDrop` and the file fields of `Klar.Form`). No ports, no JavaScript, no `elm/svg`, no `elm/http`, no external
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
is published, see "Getting Klar into a project" in [AI.md](AI.md).

An AI that builds the application starts with [AI.md](AI.md): the mental model, the ten
rules, which module to use for what, and six complete programs in
[example/src/Examples/](example/src/Examples).

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
program, with `index.html`, is "The standard application" in [AI.md](AI.md).

Components are configured with a list of attributes, like `Html`. A component that
has state of its own (a select that is open, a table that is sorted) comes with
`State`, `Msg`, `update` and `view`, and is wired like any child in the Elm
Architecture. The conventions are described in the [`Klar`
module](https://package.elm-lang.org/packages/davidtoska/elm-klar/latest/Klar) and
every module has an example.

## What is in it

| | Modules |
| --- | --- |
| **Foundations** | `Theme`, `Color`, `Settings`, `Locale`, `Layout`, `Card`, `Text`, `Icon` |
| **Icon library** | 500 icons in one style: `Icon` and `Icon.Library`, plus `Icon.Arrows`, `Icon.Business`, `Icon.Data`, `Icon.Documents`, `Icon.Logistics` and more |
| **Actions** | `Button`, `Menu`, `ButtonGroup`, `ToggleGroup`, `SplitButton`, `Link`, `Kbd` |
| **Status and feedback** | `Badge`, `Tag`, `Alert`, `Spinner`, `Skeleton`, `Progress`, `EmptyState`, `ErrorState` |
| **Forms** | `Form` (the form model), `Form.Spec` (declaring a form), `Form.Layout` (the frame), `Form.Check` (tests), `Field`, `Validate` |
| **Inputs** | `TextInput`, `TextArea`, `NumberInput`, `PasswordInput`, `SearchInput`, `TagInput`, `FileDrop`, `InlineEdit`, `Checkbox`, `CheckboxGroup`, `Radio`, `Switch`, `Slider`, `SegmentedControl`, `MaskedInput`, `Money`, `MoneyInput` |
| **Choosing** | `Select`, `Select.Option`, `Ids` (your id type as text, once), `MultiSelect`, `Autocomplete`, `VirtualList`, `TreeSelect`, `Cascader`, `Transfer`, `Picking` |
| **Date and time** | `Date`, `DatePicker`, `DateRangePicker`, `TimePicker`, `DateTimePicker`, `Calendar`, `Recurrence`, `RecurrencePicker` |
| **Tables and lists** | `Table`, `Pagination`, `ListItem`, `Tree` |
| **Overlays** | `Overlay`, `Modal`, `ConfirmDialog`, `Drawer`, `Toast`, `Popover`, `Tooltip`, `ContextMenu`, `CommandPalette`, `ShortcutHelp` |
| **Navigation** | `AppShell`, `SideNav`, `PageHeader`, `Breadcrumbs`, `Tabs`, `Stepper` |
| **Structure** | `Accordion`, `Toolbar`, `DescriptionList` |
| **Arranging** | `Sortable`, `Splitter` |
| **Pages and flow** | `StatusPage`, `BulkBar`, `LeaveGuard`, `History` |
| **Text and change** | `Markdown`, `MarkdownEditor`, `Diff`, `Compare` |
| **Access and approval** | `PermissionMatrix`, `ApprovalFlow` |
| **Data display** | `Stat`, `Chart` (line, bar, donut, gauge, meter, sparkline), `Timeline`, `Avatar`, `JsonViewer` |
| **Rules and filters** | `Rule`, `RuleBuilder`, `FilterBar`, `SavedViews`, `ServerList` (a server-side list with all three) |
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
behaves. Its Examples page opens six small complete applications (an inbox, an edit
form, delete with confirmation, a dashboard, a multi-step flow, a command palette),
each one Elm file in `example/src/Examples/`.

```bash
npm install     # once; installs elm-test and elm-format, nothing else
npm start       # builds the showcase and serves it on http://localhost:8000
```

Press `Ctrl K` for the command palette and `?` for the keyboard shortcuts.

## Themes

There are ten themes, each in a light and a dark mode, and an application picks one
(an internal application usually picks one for the company and leaves it):

```elm
Klar.stylesheetFor
    (Settings.default
        |> Settings.withTheme Theme.ocean
        |> Settings.withMode Theme.System -- Light, Dark, or what the operating system says
    )
```

Klar, Ocean, Teal, Indigo, Violet, Plum, Slate, Graphite, Sand and Contrast (high
contrast). None is green, amber or red, so an accent is never mistaken for success,
a warning or an error. The colors are computed in Elm, and a test checks WCAG AA
contrast for the pairs of the library with the colors that are on the page, in every
theme and mode (the default light look, which is the stylesheet itself, included). There
are no colors of your own on purpose: a color picked by hand cannot be promised to keep
the contrast. `Theme.name` and `Theme.modeName` give the names for a picker in both
languages, `Theme.key` and `Theme.modeKey` the text to store a choice with.

## Styling

`Klar.stylesheet` renders a `<style>` element with every rule of the library. It
includes a small reset (box sizing, the page font and background, links, tables,
focus rings), so Klar assumes that it owns the page. If your content security policy
forbids inline styles without a nonce, draw `Klar.css` in a `<style>` element with your
own `nonce`.

The look is made of design tokens, CSS custom properties that components use instead
of fixed colors, sizes and radii, listed in the documentation of `Klar.Theme`. An
application picks a theme and writes no CSS; a token redefined by hand is outside the
contrast that the themes are checked for.

## Browsers

Klar is built for current evergreen browsers. Popups (selects, menus, date pickers)
use CSS anchor positioning where the browser has it, so they are never clipped by a
scrolling parent and flip when there is no room, and fall back to plain positioning
where it does not. It was developed and tested in Chromium, with real key presses and
pointer events. Firefox and Safari, touch screens, screen readers, high-contrast mode
and the dark modes have not been tested systematically (only in Chromium, on the showcase).

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

[CLAUDE.md](CLAUDE.md) has the conventions, the documentation style, the checks
(`npm run check`) and how a version is published.

## License

[BSD 3-Clause](LICENSE). The icons are based on [Feather](https://feathericons.com)
and [Lucide](https://lucide.dev); their license texts are at the end of [LICENSE](LICENSE).
