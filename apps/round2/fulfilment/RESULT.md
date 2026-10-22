# Round 2: Fulfilment desk

All seven tasks work in the browser (`node scripts/build-app.mjs round2/fulfilment --optimize`, served over http, checked in the Browser pane at 1366 and 1024 px). `check-app.mjs` passes. 14 frictions are in [FRICTION.md](FRICTION.md).

| Measure | Result |
|---|---|
| Compile errors before the first working build | **0** (wrong type 0, missing import 0, argument order 0, misunderstood option 0). Two slips of mine were fixed before the first `elm make`: a local type named `Order` clashing with `Basics.Order` (renamed `OrderSummary`) and a placeholder I had left in `Table.emptyState`. After a first read of ~15 module docs the code compiled as written. |
| Fix iterations per task | 1 inbox: 0 · 2 saved views/chips: 1 (focus the name field with `Modal.openWith`) · 3 bulk: 0 · 4 drawer: 1 (a failed background refresh replaced the page by an error) · 5 states: 0 · 6 keyboard/palette: 0 · 7 toasts: 0 |
| Application lines per task (approximate; `Main.elm` 1 682 lines incl. views, `Domain` 254, `Api` 183, dummy backend `Backend/Db` 600) | 1 inbox ~260 · 2 views and filters ~200 (of which ~110 `KLAR GAP`) · 3 bulk ~190 · 4 drawer ~480 · 5 states ~60 in the app plus the 183-line `Api` layer · 6 palette, shortcuts, help ~170 · 7 toasts ~60 spread over the others. `KLAR GAP` code: ~110 lines in 5 marked places (new-view modal, share, view by name in the URL, focus the table search by id). |
| Unexposed module or internal needed | **0** |
| Hand-written focus, popup, date, scroll, layout code | One `Browser.Dom.focus "orders-search"` for the `/` shortcut. No popup code, no scroll code, no CSS or layout code (`Layout.*` only). Date: one `Date.fromPosix` for today. |
| `class` / `style` / inline CSS | **0** (grep) |
| Behaviour wrong after it compiled (inbox page) | None found: server sort, search, paging 200/page, filters, chips, views, selection, failure + retry, loading, empty, "No matches" all behaved. Dummy data repeats (my hash is poor); not Klar. |
| Behaviour wrong after it compiled (drawer) | (1) a failed refetch after a status change/note replaced the order by an error page; fixed (R2F-011). (2) Palette opens drawer; closing leaves focus on `BODY` when nothing with an id had focus (R2F-014). (3) The new-view modal did not focus its field; fixed (R2F-009). |
| Accessibility | axe-core 4.14 (wcag2a, 2aa, 21aa, 22aa, best-practice) on 17 states: inbox, table failed, loading/slow, No orders, no-matches + toast, selection bar, assign dialog, saved views list, filter editor, drawer loading, details, lines, history, notes, status menu, confirm dialog (also with a failure and retry), palette with remote hits, shortcut help, new-view modal: **0 violations**. `color-contrast` came back "incomplete" (202 nodes) because the pane is hidden/over backgrounds, so contrast was not measured by me. Keyboard run: `/` search, Tab to the rows (one tab stop), arrows, Space, Enter opens the drawer, Escape returns focus to the row; Ctrl+K, palette Enter, `?`, `n v` all worked. Not tested with a screen reader. Known open point: loading skeleton in the drawer has no busy label (R2F-010). |
| Time start to working application | About 2 h of work: ~45 min reading docs, ~40 min writing the code, ~35 min in the browser (first build compiled). |

## Caveats of the test

The Browser pane was hidden, so Elm's `requestAnimationFrame` rendering lagged: screenshots and DOM reads showed the previous state until I waited or took another screenshot. I always re-read after a wait. Fast key sequences from the tool come in one tick and the 1.2 s window of `g o`/`n v` is shorter than the tool's round trip; I sent "n v" in one call.

## What was easy

- `Table` in server mode: `Table.query` compared before/after, `server`, `refreshing`, `onRetry`, `fillHeight`, `selectable` + `bulkActions` + the count bar, `exportCsv`, row keyboard and tab stop: all worked from the doc example, 0 errors.
- `FilterBar` + `Rule`: the same `Rule.Field` list drives the chips, the backend (`Rule.matches` in the dummy backend) and the saved views. Date, number, choice and bool fields with the right operators came for free.
- `SavedViews`: create, rename, delete, default, "modified" mark and reset with no code; comparing `revision` and `views` is a clear contract.
- Overlays: Drawer + ConfirmDialog (with failure + retry built in) + Toast + palette + help in one `AppShell.overlays` list. Focus returns to the right row; a toast with an action while a drawer is open worked with no code.
- `Remote` + `ErrorState` / `Table.onRetry`: loading, failure, empty states needed no per-screen code. `Problem` kinds gave different texts for free.
- `CommandPalette.remote` with the ticket pattern from the docs; `Shortcut` + `ShortcutHelp` from one list.
- Zero class names, zero CSS, 0 axe violations on the first try.
