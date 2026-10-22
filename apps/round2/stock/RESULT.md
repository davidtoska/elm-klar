# Stock overview, round 2 (A0): result

Built with Klar from the documentation only (README, USING, CONTRIBUTING, the generated
`docs.json`). `node scripts/build-app.mjs round2/stock --optimize` builds, and
`check-app.mjs` passes ("only exposed Klar modules, and Klar is the locked version").
All seven tasks work. Frictions: [FRICTION.md](FRICTION.md) (R2S-001 to R2S-011).

## Measures

| Measure | Result |
|---|---|
| Compile errors before the first working build, by kind | 6 failed compiles, **0 caused by a Klar API**. By the plan's kinds: wrong type 0, missing import 1 (scaffold `elm/url` was indirect, R2S-004), wrong argument order 0, misunderstood option 0. The other 5 were my own Elm: a name clash (`Transfer` type and constructor), a shadowed `i`, an undefined variable, a wrong type name from a bad `sed`, and `{ model.query \| ... }` (not allowed in Elm). |
| Fix iterations per task (after the first working build) | 1 tree filter: 0. 2 figures and period: 0. 3 charts: 1 (R2S-005, `loading` cancels `remote`). 4 movements list: 1 (columns did not fit at 1280, R2S-009). 5 timeline and raw event: 0. 6 states: 2 (six toasts at once; the notice forgot the locations). 7 widths and density: 1 (axe `heading-order`, R2S-006). Total 5. |
| Lines of application code per task (non-blank, non-comment, after `elm-format`; `Main.elm` unless said) | 1 tree and filtering: ~92. 2 four figures and period: ~96. 3 charts: 51. 4 movements list: ~111. 5 timeline and raw event: ~130. 6 loading, empty, failed, stale: ~207 (of which 147 `KLAR GAP`, see below). 7 widths and density: ~40. Frame, model, update wiring, routing: ~230. Total `Main.elm` 916. `Feed.elm` 84 (all `KLAR GAP`). **Dummy backend** (`Backend/Data.elm` 1 000, `Backend/Api.elm` 62) is the other 1 062 lines and is not application code. |
| `KLAR GAP` lines | 147: `Feed.elm` (84: a `Remote` that remembers the last good answer and the time), `settle` (29), `anyStale` (10), `viewNotices` (24, the "some data is out of date" alert). One gap, stale data (R2S-002), takes about 16% of the application. |
| Times an unexposed module or a Klar internal was needed | **0** |
| Hand-written focus, popup, date, scroll or layout code | None. The only imperative calls are the documented `AppShell.resetScroll`, `focusMenuButton`, `focusContent` and `SideNav.focusLink`, which the app must wire itself (R2S-010). No date arithmetic beyond `Klar.Date`. No layout beyond `Layout.stack/grid/row`. |
| `class`, `style` or inline CSS in the application | **0** (`grep` for `class`, `style`, `Html.Attributes`: only `Klar.stylesheet`). No ports, no JavaScript, only `elm/browser`, `core`, `html`, `json`, `time`, `url`. |
| Behaviour wrong after it compiled, by page (one page) | (1) **Charts showed "No data to show" while loading, after a failure and after success** because `Chart.loading` after `Chart.remote` overrides it (R2S-005, Klar, fixed in my code). (2) Six toasts at once on a refresh failure (mine, fixed). (3) The stale notice did not name the locations tree (mine, fixed). (4) Value and Quantity columns were behind a horizontal scroll at 1280 (mine, R2S-009, fixed). (5) A tree selection cannot be cleared by clicking it (Klar, worked around with a button, R2S-008). (6) A port clash: my first static server on 8472 was another session's Fulfilment app, and the first screenshot was of that app; found because the title said so. |
| Accessibility | axe-core 4.x, tags wcag2a, wcag2aa, wcag21aa, wcag22aa, best-practice, headless Chrome, on **10 states**: loaded 1280, compact density, row selected with the JSON viewer, date range popup open, paged table, warehouse without data, loading skeletons, stale (refresh failed) with toast, failed (new selection while backend fails), loaded 1920. **No violation of any WCAG tag, no contrast problem.** One best-practice rule, `region` (moderate), on every state: 4 nodes (the "Locations" caption, the tree filter and its label) in the sidebar are outside any landmark (R2S-007). The first run also had `heading-order` (Card is `h3` under the `h1`), fixed with `Card.headingLevel 2` (R2S-006). **Keyboard-only run** through the main task, no mouse: Tab to the tree (7 stops), Down Down Space selects Ridge and the page reloads, Tab to the search box (6 stops), type "carton" (30 rows), 16 Tab stops to the first row (all header sort and filter buttons are stops), Down Down Enter selects a movement, the raw event appears with focus staying on the row, Tab to "Expand all" and Enter. Everything reachable; the order is logical; focus is never lost. |
| Performance (task 4, 50 000 rows, headless Chrome 1280x900, software rendering; every number includes two animation frames, about 33 ms floor) | Search keystroke: **30 to 47 ms** (median 33), also for the 6 prefixes of "carton", clear and no-match. Sort click: **40 to 60 ms** (one 87 ms; first sort of each column is not slower because rows are prepared). Page change (paged mode): **42 to 51 ms**. Scroll step of 700 px in virtual mode: 23 to 74 ms. Start: data generation blocks the main thread for 193 ms at load (my backend), `Table.prepareRows` for 50 000 rows blocks 355 to 524 ms when the movements arrive, summary queries 87 to 96 ms. The table is `Table.virtual` by default with a Scroll / Pages switch; filters are `Table.rowFilter` for the tree and the period plus the built-in search and `filterSelect` type filter. |
| Time from start to the working application (rough) | About 25 min reading the docs, about 25 min to the first working build (backend 40% of it), about 30 min verifying and fixing, about 80 min in all. |

## The seven tasks

1. **Tree.** `Klar.Tree` in the sidebar under the `SideNav`: 4 regions, 12 warehouses, 36 zones, with counts, a "No data" badge, a filter box. Selecting any node refilters the figures, both charts, the timeline and the table (`rowFilter`). Works.
2. **Four figures** (`Stat.row`): stock value, items below reorder level, open transfers, turnover, each with `Stat.change` against the previous period of the same length, a sparkline (not for turnover) and the delta label. The period is a `DateRangePicker` (quick choices, `maxRangeDays 120`, its own error message for a longer period). Works.
3. **Charts.** `Chart.line` (units on hand, with the reorder level as a dashed series) and a stacked `Chart.bar` (movements by product category and type). Works.
4. **Movements list.** 50 000 generated movements, `Table.prepareRows` once, `Table.virtual` (or pages), search, `filterSelect` on type, warehouse, zone and category, range filter on quantity, column chooser, CSV export, sums in the footer. Works and is quick (above).
5. **Timeline and raw event.** `Timeline` of the latest transfers with "Load more", status tone per transfer; clicking (or Enter on) a table row shows the raw event as `JsonViewer`. Works.
6. **States.** Skeletons in tiles, charts, tree, timeline and table (verified at 200 ms after a selection). Failure with retry on every part (backend switch in the top bar, "Simulate backend failure", or open `#/fail` to start with a failing backend; verified: 9 error states with retry on first load, including the tree and the table, and all recovered after "Try again"): a Klar error state in each chart and tile, a retry in the timeline footer, a retry in the tree and the table. Empty: the warehouse "Haven" has no stock; the page says so with an `EmptyState` instead of empty charts. **Stale**: when a refresh fails the old data stays, every card shows an "Old data from 11:16" badge, the tiles say "Old data", the timeline footer says why it could not load more, one alert lists what is out of date, and a toast announces it once. All of that is my code (R2S-002).
7. **Widths and density.** Checked at 1280 and 1920 (screenshots, no overflow, charts and cards reflow, table gets room). Compact density (a `SegmentedControl`) shrinks the table rows, tree rows, timeline, tiles and the page padding.

## What was easy

- **Zero compile errors from Klar's API in 6 compiles**, for about 60 Klar functions. Every doc example compiled as written; the types (`Table.State Int`, `Tree.Ids Place`, `SideNav.Keys`) caught nothing wrong because there was nothing wrong.
- **Remote everywhere.** Tile, chart, tree, timeline and table all take a `Remote` and draw skeleton, failure with retry and empty without code. Tasks 6 (without stale) and 3 were nearly free.
- **`Table.prepareRows` plus `preparedRows`, `rowFilter`, `filterSelect` and `virtual`** worked on the first try, and the "many rows" section told exactly what to do. 50 000 rows is a non-event.
- **`DateRangePicker`**: presets, validation text, `maxRangeDays`, calendar anchored correctly, all from five attributes; reacting to a change by comparing `range` before and after was clear.
- **`Stat.change`** computing the percentage and its colour, `lowerIsBetter`, sparklines inside the tile.
- **`Timeline`** with day headings, "Yesterday", folded footer and a failed next page (`moreFailed`) that keeps the events.
- **`JsonViewer`**: one call, with toolbar and keyboard; `Toast`, `AppShell.overlays`, `SegmentedControl`, `Format` all worked as documented.
- **Accessibility out of the box**: the only axe findings in 10 states were one default heading level and one missing landmark.
- **No class, no style, no CSS, no internal module**: the page looks finished at 1280 and 1920 with `Layout.stack/grid`, `Card` and `PageHeader` alone.

## Compared with what a person would want next

The five biggest frictions, in the order I would fix them:

1. **Stale data has no home** (R2S-002). The task asks for it, Klar draws every other state, and 147 lines are mine.
2. **`Chart.loading` silently cancels `Chart.remote`** (R2S-005; `Stat` has the same pair). A silent wrong screen, no compile error.
3. **Sidebar content outside a landmark** (R2S-007) and **Card heading level h3** (R2S-006): both axe findings, both are defaults.
4. **A filter tree cannot be cleared** (R2S-008) and **the shell wiring is 45 lines in every app** (R2S-010).
5. **Table columns and tab stops** (R2S-009): nothing tells you how many columns fit; 15 header tab stops before the first row.
