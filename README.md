# Klar

**Precise, data-dense UI components for data-intensive Elm applications.**

*Klar* is Norwegian for "clear" and "ready". It is a toolkit for applications
where people work with tables, filters, forms, dates, dialogs and dashboards all
day. Complexity belongs inside the components; applications keep their own data,
identities and business logic.

The package is in active development before its first publication. The public
API may change until then. See [ROADMAP.md](ROADMAP.md) for remaining work.

## Start here

- Building an application: [AI.md](AI.md).
- Full module reference: [generated documentation](ai/modules/README.md).
- Complete programs: [example/src/Examples/](example/src/Examples/).
- Developing the library: [AGENTS.md](AGENTS.md).

After publication, install with `elm install davidtoska/elm-klar`. For now,
use the source-directory setup in [AI.md](AI.md#getting-klar-into-a-project).
Klar supports Elm 0.19.x and is developed with 0.19.3.

## A small example

```elm
Table.view TableMsg
    [ Table.columns
        [ Table.text (Table.columnId "id") "Order" .id [ Table.pinned ]
        , Table.text (Table.columnId "customer") "Customer" .customer [ Table.filterText ]
        , Table.money (Table.columnId "total") "Total" .total [ Table.footerSum ]
        ]
    , Table.remote model.orders
    , Table.rowId orderIds .id
    , Table.searchable
    , Table.selectable
    , Table.onRetry Reload
    ]
    model.table
```

The application owns the rows and requests. `Table.remote` presents loading,
failure, empty, refreshing and retained old data. Stateful components follow the
Elm Architecture with `State`, `Msg`, `update` and `view`.
The [application starter](example/src/Examples/Application.elm) shows complete
wiring for the shell, settings, table, requests and overlays.

## What Klar provides

The toolkit includes tables and server lists, searchable and hierarchical
pickers, forms and validation, exact money, dates and recurrence, charts,
overlays, keyboard navigation, Markdown, diffs and review workflows.
Use the [generated module index](ai/modules/README.md) for the complete catalog.

- **Plain Elm.** The library depends only on official `elm/*` packages. It has
  no ports, JavaScript, external fonts, CDN or transport dependency.
- **Styles included.** Put `Klar.stylesheet` in the view, or use
  `Klar.stylesheetFor model.settings` for a theme and density. Layout comes from
  typed components rather than application CSS.
- **Honest data and input.** Remote state travels with the data; invalid input
  remains visible rather than being silently changed.
- **Localized built-in text.** English and Norwegian Bokmål through `Klar.Locale`.
- **Application-owned integration.** Applications may use HTTP, ports and
  JavaScript adapters for persistence and external data at their boundary.

## Run the showcase

```bash
npm install
npm start
```

Open `http://localhost:8000`. The showcase has live component examples, an
attribute inspector, complete programs and simulated backend failures.
Component pages link to the generated API reference instead of separate API tables.
Press `Ctrl K` for the command palette and `?` for shortcuts.

Useful walkthroughs:

- [Orders: failure, editing, retry and focus](example/ORDERS.md).
- [Connected application patterns](example/APPLICATIONS.md).
- [Real Elm/Go/SQLite consumer and its findings](apps/kitchen-sink/README.md).
- [Go HTTP query and upload contracts](example/HTTP.md).
- [Process studio and its simulated server](example/WORKFLOWS.md).
- [Calendar application and its Go/SQLite backend](apps/calendar/README.md).

Run `npm run check` for the repository checks, tests and builds. Browser checks
require Node 22+ and Chromium, Chrome or Edge; `KLAR_BROWSER` selects the executable.
The calendar backend also needs Go 1.26+ on PATH (or `KLAR_GO` pointing to Go).

## Styling, browsers and accessibility

The stylesheet includes a small page reset, so Klar assumes it owns the page.
With a content security policy that requires a nonce, put `Klar.css` in a style
element with your nonce. Themes, modes and design tokens are documented in
[Klar.Theme](ai/modules/Klar.Theme.md).

Klar targets current evergreen browsers. Popups use CSS anchor positioning where
available, with a positioning fallback. Development and browser regression tests
use Chromium. Firefox, Safari, touch, screen readers and Windows high contrast
have not been tested systematically.

Components include keyboard handling, ARIA wiring, focus management and live
regions. Theme color pairs have automated contrast tests. These checks do not
replace testing with assistive technology; see the remaining accessibility work
in [ROADMAP.md](ROADMAP.md).

## License

BSD-3-Clause. Feather and Lucide icon license texts are included in [LICENSE](LICENSE).
