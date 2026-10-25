# Klar Kitchen Sink

A documentation-only consumer of Klar, with an Elm frontend, a Go HTTP server and a real SQLite database. There are 108 component scenarios across 19 pages, covering all 151 exposed modules, including utilities and all icon groups.

## Run

Install Node.js, Go 1.26 or newer, and Google Chrome for the browser tests. From this directory:

```sh
npm ci
npm start
```

Open [http://127.0.0.1:8090](http://127.0.0.1:8090). The server binds to loopback. Stop it with Ctrl+C. `scripts/go.cjs` uses Go on PATH, or the app-local `.tools/go` toolchain when present. The portable toolchain used during development is ignored by Git.

This checkout uses the pre-publication installation documented by `AI.md`: `../../src` is a compiler source directory, but the app imports only exposed modules. Once Klar is published, replace that directory with the `davidtoska/elm-klar` package dependency. This exercise does not pretend that the current unpublished checkout was downloaded from the Elm package registry.

## Try it

- **Foundations:** themes, dark mode, component locale and density.
- **Actions / Feedback:** buttons, menus, status and error presentations, removable tags and dismissible alerts.
- **Inputs / Choosing / Dates:** controlled fields, validation, searchable and hierarchical choices, transfer lists, date/time fields, calendars and recurrence.
- **Data:** a SQLite-backed table, a 10,000-row virtual list, card and queue views, hierarchy, pagination and an editable exact-money budget.
- **Overlays / Structure:** dialogs, drawer, popover, tooltip, context menu, Ctrl+K palette, shortcut help, tabs, accordion, sortable list, splitter, undo/redo and an isolated leave-draft guard.
- **Dashboard / Content:** statistics, six chart forms, timeline, avatars, Markdown editing/preview, diff, comparison, JSON inspection and source download.
- **Rules:** rule editing and evaluation, filter chips, saved views, and a ServerList whose search, sort, pagination and filters run through Go.
- **Forms:** a declared form with validation, dirty state, ticketed saves, server field rejection and request failure. Try `taken@example.com`, or the name `Crash`.
- **Collaboration / Access:** Kanban moves, notifications, audit events, conflict decisions, threaded comments, role permissions and approval.
- **AI:** revision-bound proposal review and a streaming, deterministic assistant simulator with Stop and Retry. No AI provider is connected. Proposal review stores demo decisions and does not modify orders.
- **Files:** select files, explicitly add them to the queue, then start, cancel or retry real multipart uploads. SQLite stores the actual bytes.
- **Processes / Icons:** workflow definition editing, a local pure-engine run, a state machine, and every icon in the public library groups.

The remote scenario buttons exercise the order-backed regions: initial/empty/data, a delayed refresh and a deliberate failure with old rows retained. Static fixtures such as charts, warehouse choices and workflow definitions remain independent examples. **Clear remote data**, followed by **Slow refresh** or **Failure / old data**, exercises loading or failure without previous rows. `fail` in the ServerList search intentionally fails that independent endpoint.

## Persistence and boundaries

`data/kitchen-sink.sqlite` is created and seeded with 250 orders on first start. It persists across restarts. The app saves customer records, inline edits, budgets, Kanban changes, permissions, notifications, saved views, workflow definitions, comments, audit events, chat history and uploaded file bytes through Go. Saved resources are restored on startup where they have an editor; unsaved component drafts and browser `File` handles remain local.

**Save snapshot** stores the shared text field, checkbox, slider, undoable note, theme and mode. It does not serialize every opaque component state. The leave-draft guard protects its labelled sandbox action; the entire gallery does not ask before navigation. Workflow runs execute the library's pure engine locally; saving a definition persists its versioned JSON in Go. The AI simulator is explicitly a test fixture, not a deployed AI service. This is a local kitchen sink, without an authentication/account system.

Go exposes `/api/health`, `/api/orders`, `/api/orders/query`, `/api/documents/{id}`, `/api/customers`, `/api/events`, `/api/comments`, `/api/chat` and `/api/uploads`. A missing optional document returns JSON `null`. Uploaded bytes can be downloaded at `/api/uploads/{id}`. Queries use an explicit application protocol derived from the public `Table.Query` and `Rule` types; the server validates its supported vocabulary, and the UI offers that same subset.

The JavaScript adapter only handles HTTP transport, streamed JSON and cancellation. Multipart files use `elm/http` directly. There is no application CSS, private Klar import, custom popup positioning or custom keyboard/focus implementation.

## Verify

```sh
npm run verify
```

This checks exposed imports and formatting, builds optimized Elm, runs Go integration tests, and starts a temporary Go server on port 8091 with a fresh SQLite database for Playwright. It tests all pages at 1440 and 1024 px, scans IDs and ARIA references, and exercises keyboard selection/focus, overlays, forms, uploads, persistence, collaboration and streaming. Reports and screenshots are in ignored `test-results/`. The main database on port 8090 is not used by `verify`.

Google Chrome is the default browser. Alternatively install Playwright Chromium (`npx playwright install chromium`) and set `PLAYWRIGHT_CHANNEL=chromium`. Set `KITCHEN_SINK_TEST_PORT` to change the isolated test port. `npm run test:browser` instead tests an already running server (`KITCHEN_SINK_URL`, default port 8090).

[`coverage.json`](coverage.json) records per-module implementation and verification. Rendering a module's scenario is tracked separately from testing an interaction; this is not a claim to exhaustively test every API attribute or every icon click.

## Working on this app

`src/Main.elm` is generated application code. Edit `scripts/generate.cjs` and `scripts/scenarios.cjs`, then run:

```sh
npm run generate
npm run verify
```

The generator assembles application scenarios authored against the public documentation. It reads only generated module documentation and package metadata, never the Klar implementation or showcase. `scripts/docs.cjs Select Table` prints just the documented signatures needed for a task.

Read [`FINDINGS.md`](FINDINGS.md) for the experiment log, confirmed documentation issues, consumer mistakes, suggestions and verification limits. Library changes are intentionally deferred.
