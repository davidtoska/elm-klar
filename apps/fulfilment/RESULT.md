# Fulfilment desk: result of the A0 run

First of the three A0 applications ([../PLAN.md](../PLAN.md)). Built by an AI with only
`README.md`, `USING.md`, `CONTRIBUTING.md` and the doc comments of the exposed modules
(`docs.json`, rendered to text). Klar was frozen (`klar.lock`); nothing under `src/`,
`css/`, `tests/` or `example/` was changed. The friction is in
[../FRICTION.md](../FRICTION.md) (F-001 to F-020).

**One slip to declare.** I started a static server on port 8123, a server for the showcase
was already running there, and a screenshot of its start page ("Overview", "Orders per
day") came back before I noticed. I did not open `example/` or its source and did not use
it for anything; the app was served from port 8765 afterwards.

## How to run it

```bash
node scripts/build-app.mjs fulfilment --optimize        # from the repository root
cd apps/fulfilment && python -m http.server 8765         # any static server
# open http://127.0.0.1:8765/index.html
```

The page must be served over `http` (a known Elm limit, not tested here: a `Browser.application` does not start from `file://`; the app is one, for the order links,
`#/orders/ORD-10482`, and the shared view links, `#/orders?view=Late`). The "Simulated network" menu in the top bar makes loading slow, makes loading
fail, or makes saving fail. The data lives in memory, so a reload gives a new database.

## The seven tasks

| # | Task | State | Notes |
|---|---|---|---|
| 1 | Inbox, 200 per page, sort, filter, search | works | `Table` in server mode (1 200 orders; 200 per page, sizes 50/100/200). Filter by status, customer, created, due, total, assignee and "late" in `FilterBar`; free text in the table's search; sort by clicking a header (server side). Footer sum removed: in server mode it sums only the visible page. |
| 2 | Saved views: create, rename, share by name; chips | works, with workarounds | Three seeded views, create/rename/default/delete come with `SavedViews`; the filter is shown as editable chips (`FilterBar`). "New saved view" (button, `n`, palette) is my own dialog (KLAR GAP). "Shared by name" is a link `#/orders?view=Name` that opens the view; the link is shown in a dialog for copying by hand (no clipboard). Views are saved to the dummy backend. |
| 3 | Select, mark as packed, assign, CSV, count bar | works | `Table.selectable` + `bulkActions` + `exportCsv`; "Select all 216 matching" works through `Table.selection`; assign asks for the person in a `ConfirmDialog` with a `Select`. A failed pack keeps the selection and offers "Try again". |
| 4 | Order in a drawer: lines, history, notes, status steps | works | `Drawer`, `DescriptionList`, `Tabs`, a client-mode `Table` for the lines, `Timeline`, `TextArea`. Only the allowed next steps are offered; shipped, delivered and cancelled ask first (`ConfirmDialog` with consequences). An order can be opened by its address, also at start-up. |
| 5 | Loading, failure with retry, empty, never blank | works | Skeleton, "Can't reach the service" with "Try again", "No matches" / "No orders", and for the drawer a not-found state; all except the drawer's come from `Table` without code. Slow answers keep the old rows dimmed. |
| 6 | Keyboard: rows, Enter, palette, help sheet | works | Arrow keys and Enter on rows (`Table`), `Ctrl+K` palette with "Go to the inbox", "New saved view", "Reload", "Show the keyboard shortcuts" and a server search "Go to order ...", `?` help sheet, `g i`, `/`, `r`, `n`. The help sheet cannot list the keys that the table handles itself (F-007). |
| 7 | Toasts; a failed save keeps what was typed | works, with a workaround | Success and failure toasts for every write, with "Try again". A failed note save keeps the text. While the drawer is open a toast cannot be reached with the keyboard (F-010), so the failure is also shown in the drawer. |

## The measures

| Measure | Result |
|---|---|
| Compile errors before the first working build, by kind | 3 failed builds, 9 error sites. Missing import / dependency: 1 build (2 sites: `Url` is an indirect dependency in the scaffold). Name clash: 2 builds (6 sites: `Success` is a constructor of both `Theme.Tone` and `Remote`; 1 site: my own record alias `Failure` against `Remote.Failure`). Wrong type: 0. Wrong argument order: 0. Misunderstood option: 0. About 3 400 lines of Elm compiled with no type error on the first full build, which says the types and the documentation of the components are good. |
| Fix iterations per feature (a rebuild after something found in the browser) | T1: 1 (footer sum misleading). T2: 0. T3: 1 (stale validation text in the assign dialog). T4: 1 (focus lost after a status change). T5: 0. T6: 2 (focus after the drawer closed; one wrong conclusion, corrected). T7: 1 (toast unreachable in the drawer). In all, 14 builds. |
| Lines of application code, per task (rough; includes formatting by elm-format) | Dummy backend, domain and API layer (not Klar code): 1 055. T1 inbox and filters: 330. T2 saved views: 215. T3 bulk actions: 185. T4 drawer: 580. T5 failure and slow states (network menu, delay and failures): 105. T6 shortcuts, palette, help: 170. T7 toasts and notes: 215 (tasks overlap; the files total 3 486 lines: Main 807, Inbox 813, Detail 630, Backend 667, Domain 260, Ids 137, Api 128, Effect 44). |
| `KLAR GAP` code | 5 marked places, about 190 lines: the new-view form (about 95), the share dialog (35), the in-drawer failure alert (45), the hand-written four states of a `Remote` in the drawer (12), `Date` to `Posix` (3). A further 200 lines are boilerplate that Klar has an answer for but makes me write (F-013, F-015, F-016, F-018). |
| Unexposed module or internal needed | 0 times (`check-app.mjs`: ok). `Klar.Internal.percentEncode` is what CLAUDE.md names for links, but it is not reachable, so I used `Url.percentEncode` from `elm/url` (F-003). |
| Hand-written focus, popup, date, scroll or layout code | Focus: `Browser.Dom.focus` for `/` (1), `Table.focus` after a bulk action and after a palette-opened drawer closed (2), `Drawer.refocus` after retry, a status change and a note (3). Popups: none. Date: `Date` to `Posix` (3 lines), `Time.here`/`Time.every` plumbing for `Timeline` and "today" (25 lines). Scroll: `AppShell.resetScroll` and `focusContent` (documented calls). Layout: a guessed `Table.maxHeight 620` (F-017). |
| `class`, `style` or inline CSS | 0 (no `Html.Attributes` import anywhere). |
| Behaviour wrong after it compiled, per page | **Inbox:** footer sum covered only the page (removed); footer sum of a `float` column truncated, "SUM 390,771..." (Klar, F-009); assign dialog kept a "Choose a person" error after the choice (mine, fixed, F-011); the palette says "No orders found" under a command query (mine, left); the side menu marks "Orders" current on the not-found page (mine, left); a created saved view is lost on reload (dummy backend, by design). **Drawer:** focus fell to the page after a status change (fixed, F-005); focus fell to the page after closing a drawer opened from the palette (fixed, F-006); a toast action cannot be reached with the keyboard (Klar, F-010; worked around); the toast covers the drawer's Close button for a while (Klar layering, left); the top bar (network menu) is inert while the drawer is open (by design). **Palette and help:** none found. |
| Accessibility | axe-core 4.10.2 (WCAG 2.0, 2.1, 2.2 A and AA, plus best practices), run in the browser pane: inbox 0 violations; drawer alone 0; new-view dialog 0; command palette 0; help sheet 0; drawer **with** a confirm dialog open: 3 (duplicate banner, duplicate contentinfo, landmarks not unique; F-020). Colour contrast was reported as "needs review" (not decided by axe). Keyboard-only run: `g i` (search), Tab to a row, arrows, Enter opens the order, Escape closes it and focus returns to the row, `Ctrl+K`, `?`; found F-010. Not done: screen reader, high-contrast mode, touch, other browsers. |
| Time from start to a working application | About 25 minutes by the system clock (02:33 to 02:57), of which roughly 5 reading the documentation, 10 writing, and 10 in the browser pane (it only renders while visible, so each check needed a wait and a screenshot). |

## What worked

- The first full build compiled with no type error. Every component was used from its doc
  comment alone: `Table` (server mode, selection, bulk bar, CSV, retry, empty and "no
  matches"), `FilterBar` and `SavedViews` on one `Rule`, `Drawer`, `ConfirmDialog` with
  consequences, `Timeline`, `Toast` with an action, `CommandPalette` with a remote
  section, `Shortcut`/`ShortcutHelp`, `AppShell` with the shell commands.
- States came for free in the table: loading skeleton, failure with a retry that keeps
  focus, "no matches" that resets my filters through `onResetFilters`.
- axe found nothing on every single overlay.
- Row ids and focus return to the row when a drawer closes work without code.

## The five biggest frictions

1. **Overlays and focus** (F-005, F-006, F-010, F-013, F-020): focus is lost whenever the
   focused control is replaced, a toast action is unreachable inside a modal, and
   `modalOpen` has to be assembled by hand from every overlay. All found in the browser, none
   by the compiler.
2. **The server-mode list glue** (F-016, F-015): about 140 lines (table, filters, saved
   views, palette search) of "compare before and after, reset the page, ticket the
   answer" that every list will repeat.
3. **Missing escape hatches around SavedViews and ShortcutHelp** (F-008, F-007): a view
   cannot be saved from a command, and the help sheet cannot document the keys a
   component handles itself.
4. **Names that clash** (F-004): `Success` in both `Theme.Tone` and `Remote`, in every
   page that shows a loaded result and a green toast.
5. **Docs that do not compile** (F-001, F-002, F-003): the Table and AppShell examples use
   string column ids and `SideNav.item` without `Keys`; USING.md does not say that a
   `Browser.application` needs `elm/url`.

## What I would change in Klar first

1. Make the overlay layer own focus: move focus to the dialog when the focused element
   disappears, put the toast region inside the focus trap, derive `modalOpen` from the
   overlays, and fix the duplicate landmarks (F-005, F-010, F-013, F-020).
2. Fix the documentation examples so they compile (F-001, F-002) and add one recipe
   ("a server-mode inbox") that shows the whole `Table` + `FilterBar` + `SavedViews` +
   debounce + ticket pattern, or hide it in a small module (F-016, F-015).
3. Rename one of the two `Success` constructors (F-004), and add `Date.toPosix`,
   `SavedViews.askToSave` and a `ShortcutHelp` list for keys that components handle
   (F-014, F-008, F-007).
