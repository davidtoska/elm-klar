# Fulfilment desk, round 3 (experiment A0): result

Built with Klar and the AI documentation only (llms.txt, AI.md, ai/, recipes/, template/, USING.md).
Source: `src/Main.elm` (the page), `src/Domain.elm`, `src/Backend.elm` (dummy server, 1 200 orders),
`src/Api.elm` (request layer: delay, slow mode, failures that can be switched on). Friction rows:
[FRICTION.md](FRICTION.md) (R3F-001 .. R3F-014).

All seven tasks work. `node scripts/build-app.mjs round3/fulfilment --optimize` builds, and
`check-app.mjs` passes ("only exposed Klar modules, and Klar is the locked version").

## What was verified, and how

Served over http from a static server, driven with headless Chrome over DevTools (real key and
mouse events), axe-core 4.x with `wcag2a, wcag2aa, wcag21aa, wcag22aa, best-practice`.

| Task | Checked in the browser |
|---|---|
| 1 Inbox, 200 per page, sort, filter, search | 1 200 orders, 200 per page (6 pages); sort by Total, Due; filter chips for status, customer, order number, assignee, created / due date range (`between`, 120 matches in a test), total; table search; the answer is a page from the server |
| 2 Saved views | three views come with the desk (My open orders = default, Late, High value = shared); create (button, palette command, `n`), rename, apply, "modified" mark, share (`#/orders?view=Name` opens it), failed save with "Try again" |
| 3 Bulk | select rows, "N selected" bar, Mark as packed (counts packed and skipped), Assign to (dialog with a Select, busy, failure, retry), Select all 1 200 matching then Assign (541 changed, 659 skipped), CSV of the selection (the table's own Export, and my "Export all selected" across pages) |
| 4 Drawer | route `#/orders/SO-1068`; lines (table), history (timeline), notes (form); only allowed steps are offered; reversible step has a toast with Undo, irreversible ones (Ship, Deliver, Cancel) open a confirm dialog with consequences; failure inside the dialog and "Try again"; Close with an unsaved note asks "Discard the note?" |
| 5 Loading, failure, empty | skeleton while loading (slow mode), first-load failure with retry (`?sim=list`), failed refresh keeps old rows ("Old data from ... Refresh failed" + Try again), "No matches" with "Clear search and filters", drawer failure with retry, unknown order (`SO-9999`) |
| 6 Keyboard | Tab into the table is one stop, Arrow Up/Down move rows, Enter opens the drawer, Escape / Back return focus to the row; Ctrl+K palette with commands and a "Go to order" section (backend search with debounce and ticket, "go to order 1042" works), `?` help sheet, `g o`, `r`, `n`; a full keyboard-only pass (palette -> drawer -> Start picking -> Tab to the toast -> Undo -> Escape) |
| 7 Toasts | success toasts for note, status change (with Undo), bulk, export, share; danger toast with "Try again" for a failed note (the text stays in the form), failed status step, failed bulk action, failed export, failed saved view save; toast with action while the drawer is open is the last Tab stop of the drawer |
| Back button | opening an order pushes the route; Back closes the drawer and focus returns to the row; Forward reopens it |

## The measures

| Measure | Result |
|---|---|
| Compile errors before the first working build, by kind | **1**. Wrong type 0, missing import 0, wrong argument order 0, misunderstood option 0, other 1: a SHADOWING error (`changed` is the third part of `AppShell.update` in the AppShell doc and the helper name in the inbox recipe; I copied both; R3F-004). Two builds in total to the first working one. After it, one more error (NAMING) caused by an edit script of mine that did not apply (shell backslash handling), not by Klar |
| Fix iterations per task | 1 inbox (removed the redundant debounce, R3F-006), 2 saved views 0, 3 bulk 1 (own CSV for a selection across pages, R3F-007; and the toast tone for "0 packed"), 4 drawer 1 (late answers for a drawer that has moved on are dropped), 5 failure states 1 (`?sim=` so a first-load failure can be reached), 6 keyboard 0, 7 toasts 0 |
| Application lines per task (code lines, no blanks or comments) | 1 inbox 369; 2 saved views 140; 3 bulk 155; 4 drawer 433; 5 failure/slow menu 36 (+ the `Api` layer 143); 6 keyboard and palette 122; 7 toasts 6 (toasts are a call at the place of use); shared: overlay list 56, Model/Msg 106, imports 49; the dummy server 498 and the domain types 165. Total 2 281, of which about 1 140 are the dummy backend, domain and request layer and about 1 140 are the Klar-facing page |
| `KLAR GAP` code | 3 markers, about 130 lines (about 6 % of 2 281): the server-mode compare / reset page / ticket glue (`changed`, about 22 lines, copied from the inbox recipe), the palette search by hand (about 45), the CSV of a selection across pages (`Backend.exportCsv` and the button and handlers, about 65, needs `elm/file`) |
| Unexposed module or Klar internal needed | **0** |
| Hand-written focus, popup, date, scroll or layout code | **None.** No `Browser.Dom`, no key decoders, no positioning. Dates only through `Klar.Date` / `Format`; `Time.now` and `Time.here` once, in `init`. The only timers are the palette's debounce and the response delay of the dummy server |
| `class`, `style`, inline CSS | **0** (grep: no `class`, `style`, `Html.Attributes`, `Html.Events` in `src/`) |
| Behaviour wrong after it compiled, per page | Inbox: a second 250 ms wait on every sort or page click (R3F-006, fixed); the toast for "0 orders packed" was green (fixed, warning). Drawer: an answer for an order that was no longer open could overwrite the shown order (found by review, guarded); a failed-save toast stays after a later successful retry through the other button (R3F-013, Klar has no dismiss for one toast). Saved views, palette, help, filter editor, dialogs: none found. Nothing found in the Klar components that was a bug |
| Accessibility | axe (wcag2a, 2aa, 21aa, 22aa, best-practice): **0 violations in 19 states** at 1440 px (list loaded, first-load failure, loading, empty, drawer, confirm dialog over the drawer, toast with action over the drawer, failed drawer, invalid note, discard dialog, palette empty and with hits, shortcut help, filter editor, saved views list, rows selected, assign dialog, assign dialog with the Select open, simulate menu) and on the list at 390 px (no horizontal page scroll). I checked that axe sees faults by adding an image without alt and an unnamed button (it reported both). One `color-contrast` "incomplete" (axe could not decide, behind an overlay). Keyboard-only run through the main task: passes, see above |
| Time | about 27 minutes from the first document to the end of verification (13:13 - 13:41). Reading about 4 minutes of tool time, first working build after about 10 minutes, the rest was verification and fixes |

## Reading log (in order)

1. `llms.txt`: the map. 2. `AI.md` (all of it, including the standard application). 3. `apps/PLAN.md`: the seven
tasks, "What is measured", "The friction log". 4. `ai/klar-index.json`: not opened whole (140 KB); I printed
`name`, `purpose` and `whenToUse` of every module with a one-line node script and chose from that.
5. Module docs: Table (all 60 KB), FilterBar, SavedViews, Rule (signatures, intro, dates, operators,
`matches`), Drawer, ConfirmDialog, Overlay, Toast, BulkBar (not needed: the Table has its own bar), CommandPalette,
Shortcut, ShortcutHelp, Timeline (first 140 lines), Remote and RemoteView (first part), AppShell (the wiring part),
Form, Form.Spec and Form.Layout (signatures and intro), and the signature blocks of PageHeader, Button, Layout, Text,
DescriptionList, Badge, Date, Format, Money, Menu, Alert, Tag, Icon, Toolbar, Select, EmptyState, Validate, TextArea,
SideNav, Modal, Search, Theme. 6. `recipes/README.md`, `recipes/inbox`, `recipes/edit-form`, `recipes/confirm-delete`
(the code), `template/README.md` and `template/src/Main.elm`. 7. `USING.md` (first 400 lines: start-here application,
getting Klar in, backend, refresh). Not read: `recipes/command-palette`, `dashboard`, `multi-step`, LeaveGuard, Tabs.
Not read on purpose: everything on the DO NOT READ list, and the hand-over notes of other sessions in the shared notes folder
(they concern earlier rounds).

## What was easy

- The first full build of 2 900 lines compiled after one shadowing error. No type, import or argument-order mistakes:
  the signature blocks at the top of every module file were enough to write calls blind, and the `Quick path` lines found the entry points.
- The inbox recipe is the right size: its `Request` / `changed` / ticket shape became my list code almost unchanged.
- The overlay layer did what it says: drawer, a confirm dialog on top of it, toasts over both, the palette over the
  drawer, focus back to the row, Back button, all without a line of focus code, and axe is clean in every state.
- `Table.Selection` (`AllMatching { except }`) gave "select all 1 200 matching" and a correct bulk target.
- `Remote` everywhere: loading, failure, retry, old data and empty states came for free in the table, drawer, palette and timeline.
- `ConfirmDialog` (busy, failed, retry) and `Form` (server problem, text stays) matched tasks 4 and 7 exactly.

## What I would change first

1. A server-mode helper (or a block in AI.md) for compare / reset page / ticket / apply a saved view, for the list and for the palette (R3F-008).
2. A way to download text (CSV of a selection across pages) without discovering `elm/file` (R3F-007).
3. A "share" action for `SavedViews` and `Rule` constructors for the usual presets (R3F-010, R3F-009).
4. Make AI.md, the template and USING.md use one wiring for the frame; remove the contradictions about `ConfirmDialog` with a control and about debouncing (R3F-001, 005, 006).
5. `Toast` dismiss of one toast (R3F-013).

## Notes on the work environment (not Klar)

The Write tool of this session saves files with CRLF line endings and the shell tools collapse backslashes in
arguments and heredocs; `elm-format --yes` fixes the first, and I used Edit for anything with a regular expression.
The page is served with `scripts`-free tools from a scratch folder; nothing outside `apps/round3/fulfilment/` was changed
(`elm.json` gained `elm/file` and `elm/bytes`, both official packages, for the CSV download).
