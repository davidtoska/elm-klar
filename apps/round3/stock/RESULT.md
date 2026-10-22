# Stock overview (round 3, experiment A0): result

Built with `node scripts/build-app.mjs round3/stock --optimize` (succeeds) from the documentation only. `node ../../../scripts/check-app.mjs ../../.. src` prints `app: ok`. Friction log: [FRICTION.md](FRICTION.md) (R3S-001 to R3S-014).

## What was built

All seven tasks work; none is blocked.

| # | Task | State | Klar modules |
|---|---|---|---|
| 1 | Tree of regions, warehouses, zones; selecting a node filters everything | works (click or Space; Space again clears; tree filter box) | `Tree` (`viewRemote`, `allowEmptySelection`, `withCount`, `withBadge`) |
| 2 | Four figures with trend vs previous period, period from a date range | works | `Stat` (`remote`, `change`, `lowerIsBetter`), `DateRangePicker` (presets, `maxRangeDays`), `Money` |
| 3 | Stock level over time, movements by category | works | `Chart.line` (with a dashed previous-period series), `Chart.bar` |
| 4 | 50 000 movements, search, type filter | works, virtual scrolling | `Table` (`prepareRows`, `preparedRows`, `virtual`, `searchable`, `rowFilter`), `SegmentedControl` |
| 5 | Timeline of latest transfers, raw event as JSON | works (click or Enter on a row) | `Timeline`, `JsonViewer`, `EmptyState` |
| 6 | Skeletons, empty warehouse, old data when a refresh fails | works, see below | `Remote` (`refresh`, `refreshWith`, `staleIn`), `Alert.stale`, the components' own states |
| 7 | 1280 and 1920 wide, compact density | works | `AppShell`, `Layout`, `Card`, `PageHeader`; density by hand (R3S-004) |

The backend (`src/Backend.elm`, `src/Api.elm`) is dummy data in Elm: 5 regions, 13 warehouses, 41 zones, 120 SKUs, 50 000 movements and 2 800 transfers generated the same way on each run, one warehouse (Overflow depot) with no data. `Api.call` answers a `Cmd` after a pause (450 to 1400 ms) and fails with a 503 while the "Simulate outage" switch in the top bar is on, so loading, failure with retry, "no data" and stale are real. Stale: switch on, press Refresh (all panels keep their data, "Old data from ..." with retry and one page notice). Failed: switch on, choose another node (a new question, so skeletons, then a failure with retry on every panel).

## Measures

| Measure | Result |
|---|---|
| Compile errors before the first working build, by kind | Klar-related: **0** (wrong type 0, missing import 0, wrong argument order 0, misunderstood option 0). Own code: 1 compile run of `Backend.elm` with 3 NAME CLASH errors (my constructors `RegionNode` etc. clashed with my own record aliases). `Main.elm` and `Api.elm` compiled first time. |
| Fix iterations per task (changes after it first worked) | 1: 0, 2: 0, 3: 1 (x-axis labels cut, own short date helper), 4: 1 (`rowFilter` only while a filter is active, measured, no effect), 5: 0, 6: 0, 7: 0 |
| Application lines (non-blank, approximate) per task | 1 tree ~90, 2 figures + period ~105, 3 charts ~70, 4 movements ~140, 5 timeline + JSON ~100, 6 states, refresh, stale, retry, ticket ~120, 7 layout + density ~60. Plus dummy backend ~750 (`Backend` 697, `Api` 52), which is not a Klar matter. `Main.elm` is 836 non-blank lines in all. |
| `KLAR GAP` code | 1 helper, 5 lines (`shortDate`, R3S-005) |
| Unexposed module or Klar internal needed | 0 |
| Hand-written focus, popup, date, scroll or layout code | none. Dates only through `Klar.Date` (`addDays`, `toEpochDay`, `fromEpochDay`, `toPosix`). No `Browser.Dom`, no ports, no JavaScript. The density switch (R3S-004) is hand-wired state, not DOM code. |
| `class`, `style`, inline CSS in the application | **0** (`grep` over `src/`) |
| Behaviour wrong after it compiled | 0 functional bugs found. Cosmetic: tree rows of long warehouse names are cut ("Overflo...") next to the "No data" badge; a double border where the table sits in a flush `Card`; "Old data from" in UTC (R3S-012); every event in the timeline reads 00:00 (R3S-011); the empty warehouse's table says "No matches" (R3S-008). |
| Accessibility | axe-core 4.x (wcag2a, wcag2aa, wcag21aa, wcag22aa, best-practice) on 8 states: skeleton loading, loaded 1280, Southbank + Receipts + selected row, compact, warehouse with no data, failed (outage + new selection), stale, stale at 1920. **0 violations in every state.** One "incomplete" each: colour contrast of tree counts, "background could not be determined due to a pseudo element" (axe cannot decide; not checked by hand). Keyboard-only run: Tab reaches skip link, outage switch, density, tree filter, tree (one tab stop), period fields, Refresh, type radios (arrows), table (Columns, sort headers, one row stop); Space selects a tree node, ArrowRight moves to Receipts, Down/Enter on a row shows its JSON and focus stays on the row. Worked without a mouse. |
| Time from start to the working application | about 25 minutes on the machine clock (13:13 to 13:36 incl. reading, backend, app, measuring, QA) |

## Performance (task 4), 50 000 rows, optimized build

Headless Chrome 62 fps, 1280 x 900, `Table` client mode with `prepareRows` + `preparedRows` + `virtual`, synthetic input event until two animation frames later (so about +16 ms of frame rounding), median of 3 to 8 runs:

| Action | Time |
|---|---|
| Search keystroke (first characters, many matches) | 38 to 90 ms, median ~58 ms |
| Clear search | 11 ms |
| Sort click (any column, prepared) | 4 to 11 ms |
| "Page change" (virtual list has no pages: scroll jump to the end and back) | 30 to 45 ms |
| Type filter click (rowFilter, 50 000 rows) | ~55 ms |
| Density switch | ~50 ms |
| Selecting a node: all four panels reloaded (includes the 450 to 1100 ms simulated delays) | ~1.15 s |
| Startup until the table shows: ~3.3 s of which 1.4 s is the simulated delay; the rest is generating 50 000 movements and `prepareRows` | |
| JS heap | 40 to 70 MB |

Smooth scrolling was not measured with frame timing, only that a jump redraws within about 40 ms. The documentation says "a few milliseconds" for a keystroke, sort and page change; sorting matches, the search is about ten times slower (R3S-002).

## Reading log

Order: `llms.txt` (1 min), `AI.md` (whole, ~3 min; it names the next step), `ai/klar-index.json` (searched with a script for the modules I wanted, 36 entries read, not the whole file), then the module files: `Remote`, `Table` (first 400 lines and the sections on rowFilter, preparedRows, virtual, density), `Tree`, `Stat`, `Chart`, `DateRangePicker`, `Timeline`, `JsonViewer`, `Layout`, `Card`, `Theme`, `AppShell` (head), `Date`, `Format`, `Alert` (stale), `Money`, `SegmentedControl`, `PageHeader`, `Button`, `Switch`, `EmptyState`, `Text`; then `USING.md` (first 400 lines), `recipes/README.md`, `recipes/dashboard` (README and all code), `template/README.md`; the plan sections of `apps/PLAN.md` as told. Total about 10 minutes of reading before the first line of code. Not read: any `src/`, `example/`, other apps, design, ROADMAP, CHANGELOG, bench, docs.json. A sibling note in the notes folder about round 2 of this app was deliberately not read.

## What was easy

- The dashboard recipe was the app's skeleton: one `Remote` per panel, `Remote.refresh` / `refreshWith`, ticket against late answers, `Alert.stale` with `staleIn`. Copying that pattern gave stale data and failure+retry for free.
- `Table.prepareRows` + `preparedRows` + `virtual` for 50 000 rows is one paragraph in the docs and worked at once: sort in 5 ms.
- `Tree` with `allowEmptySelection`, counts and a badge, and `Tree.selectedId`, as the filter of the whole page.
- Zero Klar compile errors: signatures first in every module file, opaque types with named constructors, the index's quick path.
- Accessibility needed no work: axe clean on all states, keyboard run clean.

## What was not
See FRICTION.md. The biggest: no global density (R3S-004), the "a few milliseconds" claim for search (R3S-002), four stat tiles repeating one failure (R3S-006), no short date format (R3S-005), no way to word the "No matches" state of a table (R3S-008).
