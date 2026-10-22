# Stock overview: result of the A0 run

Built with Klar (frozen, `klar.lock`) from `README.md`, `USING.md`, `CONTRIBUTING.md` and the
doc comments in `docs.json` only. Nothing under `example/`, `src/Klar/Internal*`,
`apps/fulfilment` or `apps/onboarding` was read. The friction log is
[FRICTION.md](FRICTION.md) (S-001 to S-023).

Build: `node scripts/build-app.mjs stock --optimize`. Imports:
`cd apps/stock && node ../../scripts/check-app.mjs ../.. src` passes.

## The seven tasks

| # | Task | State | How |
|---|---|---|---|
| 1 | Tree of regions, warehouses, zones; selection filters the page | done | `Tree` in `AppShell.sidebar` (typed `NodeId`, `Tree.nodeIds`), button "All locations" clears the selection (S-015); all four requests restart on a change |
| 2 | Four figures with trend against the previous period, period from a date range | done | `Stat.row` with `Stat.remote`, `DateRangePicker` (min, max, today, presets) |
| 3 | Stock level over time, movements by category | done | `Chart.line` (dashed reorder level), `Chart.bar`; `Chart.remote` gives skeleton and failure |
| 4 | 50 000 movements, scrolls smoothly, search, type filter | done | `VirtualList` + `ListItem` rows (25 rendered), `SearchInput` + `Search.prepareMany` (hand-written filter, KLAR GAP), `Select` for the type. A second tab shows the same rows in `Table`: it works, but is about 1 s per click (S-008) |
| 5 | Timeline of the latest transfers, raw event of the selected movement as JSON | done | `Timeline` (with `onLoadMore`, see S-012), `JsonViewer` + `DescriptionList` in a card |
| 6 | Skeletons, empty warehouse, old data marked old when the refresh fails | done | Skeletons come from the components. "Slow network" and "Failing network" switches drive the dummy API. Empty: `EmptyState` for the warehouse that has no data. Stale: `Alert`, a "Old data from 14:05" `Badge` per card, one `Toast`; hand-written stale model (S-013, KLAR GAP) |
| 7 | 1280 and 1920 wide, compact density | done | Looked at in the browser pane at 1280 and 1920 (3 columns at 1920, charts side by side). Compact is a switch that sets `Table` density, `Tree.compact`, `Timeline.compact`, `Stat.size Small`; charts, cards and list rows do not follow (S-022) |

Not done / not verified: the type `Select` was opened and used with the mouse, but axe was not run with its
popup open (a script click does not open it). Nothing was tested at narrow phone widths. No
screen reader.

## Measures

| Measure | Result |
|---|---|
| Compile errors before the first working build, by kind | 1 failed build because of Klar: **8 `AMBIGUOUS NAME` errors** for one cause, `Success` is exported by both `Klar.Theme.Tone` and `Klar.Remote.Remote` (kind: misunderstood import, S-005). 2 more failed builds were my own shell escaping while editing (`\row` lost in a command), not Klar. No wrong-type, wrong-argument-order or missing-import errors at all: once it compiled, the first working build ran |
| Fix iterations per task | 1: 1 (keys) · 2: 1 · 3: 2 (palette colours) · 4: 4 (row height 44 vs 36, newest first, table speed, keyboard) · 5: 2 (Timeline axe error, timestamps ahead of today because of the time zone) · 6: 2 (three toasts for one refresh, "Updated" caption while loading) · 7: 2 (grid left half empty, compact). Plus 1 for the mount (blank page, S-006). Total about 15 |
| Lines of application code per task (`Main.elm` is 1 378 lines in all) | 1 tree ≈ 110 · 2 figures and period ≈ 150 · 3 charts ≈ 60 · 4 movements ≈ 260 · 5 timeline and JSON ≈ 130 (+48 `Event.elm`) · 6 states ≈ 120 · 7 layout and density ≈ 80 (the rest is model, update, shell). The dummy backend and domain are 1 310 more (`Domain`, `Api`, `Backend/Db`, `Backend/Query`, `Ids`) and are not Klar code |
| `KLAR GAP` code | 3 marked blocks, ≈ 150 lines: stale-data model (≈ 100, S-013), search and filter for the virtual list (≈ 50, S-009/S-010), row height constant (S-007) |
| Unexposed module or Klar internal needed | **0** |
| Hand-written focus, popup, date, scroll or layout code | None for focus, popup, scroll or layout. Date and time: `utcOffsetMs` (puts the dummy backend's timestamps on the user's local day) and an ISO timestamp built from `Date.toIso` and `Format.time` (S-020). One raw attribute: `VirtualList.htmlAttrs [ role "list", aria-label ]` |
| `class`, `style` or inline CSS | **0** (`Html.Attributes` is imported only for `attribute "role"` and `attribute "aria-label"`) |
| Behaviour wrong after it compiled | One page. 1) blank page: `Browser.sandbox` plus `Elm.Main.init()` (S-006). 2) list rows 44px but `rowHeight` 36 (S-007). 3) oldest movements first. 4) times after "now" (zone). 5) three identical toasts per refresh. 6) "Updated 02:44" stayed on a card that was loading. 7) two charts in the left half at 1920 (S-011). 8) `Timeline.maxHeight` scroll area not focusable, axe serious (S-012). 9) two greens in the category chart (S-016). 10) Table with 50 000 rows takes 1 s per click (S-008). 11) `Select` text list popup overlapped the rows below for a moment while it animated (not a bug, a screenshot in mid-animation) |
| Accessibility | axe-core 4.10.2 (wcag2a, 2aa, 21aa, 22aa) in these states: default, a row selected with the JSON viewer, Table tab, stale alert with toast and "Old data" badges, date range popup open: **0 violations** after the Timeline fix; 1 serious (`scrollable-region-focusable`) before it. Keyboard-only run through the main task (Tab: skip link, toggle, brand, "All locations", tree filter, tree; Space/Enter select a node; Tab to the three switches, Refresh, the two period fields, the Stream tab, the search, the type filter, a list row; Enter shows its JSON): works, with the problems in S-014 (every row is a tab stop, no arrow keys in the list) and S-021 |
| Time from start to the working application | about 2.5 hours of session time: ≈ 35 min reading the docs, ≈ 40 min writing the backend, ≈ 30 min for the first page, the rest verifying and fixing |

## What worked

The first page that compiled showed all four stat tiles, both charts, the tree, the timeline, the JSON
viewer and the skeleton, loading and failure states of every component, with no CSS, no class
name and no style. The `Remote` model is the best part: `Stat.remote`, `Chart.remote`, `Timeline.remote`,
`Tree.viewRemote` and `Table.rows` all drew skeleton, failure with retry (kind-aware text) and empty
state from the same value. The typed ids of `Tree` (`Tree.nodeIds`) and `Table.rowIds` worked
at the first try, and the API of the stateful components is regular enough that I wrote the update
branches for nine of them without looking back at the docs.

## The five biggest frictions

1. **Table cannot be the 50 000 row answer (S-008, S-009).** Client mode costs about 1 s for every click
   (search, sort, page) at 50 000 rows, and there is no virtual scrolling. `VirtualList` is smooth but
   has no columns, no search and no filter (S-010 shows the search I wrote is slow too).
2. **No stale/refreshing model (S-013).** Only `Table` knows `refreshing`. The task "old data is marked as
   old when the refresh fails" meant a hand-made `Panel` record, an `Alert`, badges and toast logic around
   data components that cannot say it themselves.
3. **VirtualList row contract (S-002, S-007, S-014).** The row must be exactly `rowHeight`, no Klar row
   says what height it has (I measured 44px in the browser), `ListItem.compact` cannot reach a row inside a
   `VirtualList`, and there is no keyboard model.
4. **Density and layout reach (S-022, S-011, S-004, S-017).** No page-level density, `Layout.grid`
   leaves empty columns, no fixed-width column, the sidebar width cannot be set.
5. **Orientation and small traps (S-003, S-005, S-006, S-001).** No "which component for what" page; `Success`
   clashes between `Theme` and `Remote` (8 compile errors); nothing says how to mount an application
   (`Browser.document`); the Table example uses a `String` where a `ColumnId` is needed.

## What I would change in Klar first

1. Fix Table performance for big client tables (cache the filtered and sorted index, test at 50 000 rows) and
   give `Table` a `virtual` mode: that decides whether a data-dense list can be Klar's.
2. Add a `Remote` that can be stale (or a `stale` attribute on `Stat`, `Chart`, `Timeline`, `Tree`) plus one
   helper to update a panel from a result; then "refresh failed, showing old data" is one line.
3. Make `VirtualList` own its row (height from the density, roving tabindex and arrow keys, `ul` markup).
4. Put density and the shell width on `AppShell`; make `Layout.minColumn` auto-fit.
5. A "Start here" recipe in `USING.md` (`Browser.document` + `AppShell` + a tree in the sidebar + `Remote`), and
   rename `Remote.Success` or `Tone.Success`; add the `scrollable-region-focusable` check for every
   `maxHeight` in Klar.
