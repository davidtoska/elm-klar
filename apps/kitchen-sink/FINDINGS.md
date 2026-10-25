# Documentation-only consumer log

This application is built using `AI.md`, `ai/klar-index.json`, and the generated module documentation. No library source or showcase implementation is opened. Compiler diagnostics are allowed, but are not used to navigate into library implementation. The compiler necessarily reads the installed package.

The existing uncommitted library changes belong to the owner and are left untouched. Findings are recorded here for a later library pass; this exercise does not repair Klar.

## Findings

### F001 — Development installation differs from the published-package scenario

`AI.md` documents `elm install davidtoska/elm-klar` and a source-directory fallback before publication. This exercise uses the documented fallback (`../../src`) so the local, current version can compile. The application only imports exposed modules. A production consumer should replace this source directory with the published package dependency when available. This distinction should be explicit in any assessment of the exercise.

### F002 — Toolchain prerequisite

Go is not on PATH in this environment. The app will include an explicit setup/run command and use an app-local portable Go toolchain for verification. This is an environment issue, not a Klar defect.

### F003 — Shortcut docs refer to a removed public name

`ai/modules/Klar.Shortcut.md`, in its introductory documentation, says “with the `host` of Klar.Modal put it in the `attributes` of the host”. The documented `Klar.Modal` signatures expose no `host`. `Klar.Overlay.host` and `Klar.AppShell.shortcuts` are the available APIs.

Impact: a consumer can wire `subscription` alone, compile successfully, and still have Ctrl+K fail whenever an element has focus. This happened in the first browser pass. Reading the complete Shortcut wiring instructions and AppShell signatures was sufficient to repair the application: give `Shortcut.listen` to `AppShell.shortcuts` and keep `subscription` as well. Recommend updating the reference to `Overlay.host` and showing the AppShell wiring directly.

### F004 — Setup JSON is missing the required compiler version

The `elm.json` example under “Getting Klar into a project” in `AI.md` omits `elm-version`. An Elm application requires that field. Set it to the compiler being used (`0.19.3` here). Our first attempt used `0.19.1` from the compatibility range and the installed `0.19.3` compiler rejected it; that choice was a consumer error, while the missing field in the example is a documentation improvement.

### F005 — Consumer mistakes are not library defects

The first app draft guessed `Money.format`; compilation correctly rejected it. The documented function is `Money.toString`. Early browser tests also used overly broad selectors (`Oslo` existed in both Select and Transfer), expected a native searchbox where Table exposes a labelled text input, and omitted the required-marker suffix from form labels. These were fixed in the app/tests. Keep them separate from confirmed library findings.

### F006 — Production integration examples would help for Go consumers

The Inbox example clearly documents ServerList tickets, requests and saved-view changes, but its server is Elm. This app demonstrates a real Go endpoint, a deliberately explicit query/rule wire format, and SQLite persistence. A compact documented cross-language contract/example would reduce work for the next consumer. This is an enhancement suggestion, not an API defect.

### F007 — Upload cancellation and retry focus require application work

UploadQueue accurately documents that the application owns transfer status, cancellation confirmation and focus when a disappearing action was focused. The app uses actual `elm/http` multipart requests and request tickets to discard late completions. A complete HTTP upload example would help cover tracker cancellation, progress subscriptions and stable-region focus together. Browser file objects cannot be restored by persisting queue metadata; the docs state this correctly.

## Verification

The app now has 108 scenario cards on 19 pages, covering 151 exposed modules. Helpers and icon modules are used by shared scenarios; they are not claimed as 151 separate UI components. `coverage.json` separates implementation, browser rendering and interaction checks. An import alone does not establish an interaction test.

The verification command builds optimized Elm, checks that every Klar import is exposed and that app code contains no CSS/private imports/custom focus code, runs Go integration tests, and launches a separate Go server with a fresh SQLite database for browser tests. The main development database is not used by this command.

The browser suite checks page rendering, ID uniqueness and ARIA references; all pages at 1024 px; keyboard selection and returned focus; modal/drawer/confirm/palette behavior; remote refresh/failure recovery; server search; form validation/server rejection/save; multipart uploads; streamed response cancellation; typed inputs; dates; undo/redo; dirty-draft confirmation; persisted comments and conflict decisions; and AI review submission. It records screenshots and a JSON report under ignored `test-results/`. This is not an exhaustive attribute, browser or screen-reader audit.

### Visual follow-up

On the NotificationCenter fixture, the timestamp and the “Read” text appear directly adjacent (`UTCRead`) for a read item. This was observed in the rendered screenshot and body text, without consulting implementation. Check spacing/separation in a later library pass. The fixture timestamp itself is intentionally synthetic; using a representative recent timestamp would make the sample more realistic.

### Consumer assessment

The public documentation was sufficient to compile every scenario without opening library implementation. Stateful update wiring, opaque typed IDs, Remote refresh retention, the single overlay host, ServerList request tickets, Form submission and draft acknowledgement all worked in the exercised paths. The main friction was composing modules across documentation pages and distinguishing a complete production transport example from a focused pure-Elm demonstration. The app preserves these boundaries explicitly in its README.

### Final verification — 25 October 2026

- `npm run verify`: passed (optimized Elm build, exposed-module and formatting checks, Go tests and isolated browser suite).
- 9 Go integration tests passed, including persistence across reopening SQLite, server filtering/paging/sorting, validation, byte-exact upload/download, comments/audit history, streamed chat and retry without duplicate user messages.
- 46 browser checks passed. All 19 pages rendered at desktop and 1024 px; no unexpected console errors, uncaught page errors, duplicate IDs or missing ARIA targets were found in the checked states.
- All 151 modules are represented in running scenarios; 44 modules have an explicit interaction check recorded in `coverage.json`. The remaining entries have rendering/integration coverage, not exhaustive interaction coverage.
- Only application files under `apps/kitchen-sink/` were written. Other repository changes visible during this run were left untouched. No commit, tag, push or publication was performed.
