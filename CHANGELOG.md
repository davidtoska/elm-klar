# Changelog

All notable changes to this package are written here. Elm enforces
[semantic versioning](https://semver.org) on package.elm-lang.org: `elm bump`
computes the next version from the changes in the public API.

## 1.0.0

The first release.

- About 90 components for data-intensive applications: a data table with client
  and server mode, searchable selects, pickers for dates, periods and times, a rule
  builder and filter bar, dialogs, drawers, toasts, a command palette, charts,
  trees, timelines and the pieces of an application shell.
- Components for working with data, arranging a workspace, and seeing what changed:
  `Klar.Sortable` (drag or key a list into a new order, with announcements) and
  `Klar.Splitter` (resizable panes); `Klar.ButtonGroup`, `Klar.ToggleGroup`,
  `Klar.SplitButton`, `Klar.Link` (a link that cannot lead anywhere unsafe) and
  `Klar.Kbd`; `Klar.StatusPage` (403, 404, 500, offline), `Klar.BulkBar`,
  `Klar.LeaveGuard` (unsaved changes inside the application) and `Klar.History`
  (undo and redo); `Klar.Markdown` (a safe renderer that tolerates unfinished text) and
  `Klar.MarkdownEditor`; `Klar.Diff` (text, JSON and field diffs) and `Klar.Compare`
  (records side by side); `Klar.Money`, `Klar.MoneyInput` (exact money in minor units,
  never rounded behind the user's back) and `Klar.MaskedInput` (IBAN, organisation
  number, bank account, postal code, phone, with check digits); `Klar.TreeSelect`,
  `Klar.Cascader`, `Klar.Transfer` (typed ids, lazy children, thousands of nodes);
  `Klar.Recurrence` and `Klar.RecurrencePicker` (every second Tuesday, with RFC 5545
  RRULE in and out); `Klar.PermissionMatrix` and `Klar.ApprovalFlow`. No new package
  dependency was added for any of them.
- Built-in text in English and Norwegian Bokmål (`Klar.Locale`).
- `Klar.Form.Model` (a prototype, see `design/FORM-MODEL.md`): a form declared once, with
  one state that owns every field's value, knows when it is dirty, loads and returns a
  record, and ties problems from the server to fields. Text, number, one choice, several
  choices and switches so far. `Select.mapOption` gives an option another kind of value.
- An icon library of 500 line icons in one style (24 by 24 grid, 2 pixel stroke, round
  ends), every one an Elm value that carries its own drawing: `Klar.Icon` has the
  everyday icons and `Klar.Icon.Arrows`, `Business`, `Calendar`, `Communication`,
  `Data`, `Developer`, `Devices`, `Documents`, `Editor`, `Interface`, `Logistics`,
  `Media`, `Nature`, `People` and `Science` the rest. `elm make --optimize` leaves out
  the icons an application does not use. `Icon.fromSvg` draws your own icon the same
  way, and `Klar.Icon.Library` lists everything for galleries. See `ICONS.md`.
- One stylesheet, delivered with the package (`Klar.stylesheet`), built on design
  tokens (CSS custom properties).
- Pure helpers with unit tests: dates (`Klar.Date`), formatting (`Klar.Format`),
  search (`Klar.Search`), validation (`Klar.Validate`), the rule engine (`Klar.Rule`).
- A showcase application (`example/`) with a component gallery and a dummy backend.
- Made for applications with very little code of their own: a select hands back
  your own id type (`Select.State CustomerId`), a date can never be invalid
  (`Klar.Date` is opaque), columns, keyboard shortcuts and problems are values and
  not free text (`Table.columnId`, `Shortcut.mod (Shortcut.char 'k')`,
  `Remote.problem Remote.timeout`), a rule field offers only the operators you
  choose (`Rule.withOperators`), and a table speaks your row id type
  (`Table.State OrderId`, `Table.rowIds`, `Table.selectedIds orderRows state`), and so do trees and the side menu
  (`Tree.State RegionId`, `Tree.nodeIds`, `SideNav.State Page`, `SideNav.keys`).
- A guide for building an application, also before the package is published
  ([USING.md](USING.md)), and `scripts/check-app.mjs` to keep a copy of Klar frozen.

### The overlay layer (A8)

What the three applications had to write around dialogs, drawers and toasts is
now done by the library. Nothing was released before this, so it changes the first
API and not a published one.

- New module `Klar.Overlay`: `Overlay msg` (what the `view` of every dialog-like
  component returns), `host` (the root of a page with overlays, replaces
  `Modal.host`) and `map`. `Modal.view`, `Drawer.view`, `ConfirmDialog.view`,
  `CommandPalette.view`, `ShortcutHelp.view` and `Toast.view` return an `Overlay`.
  The page is `inert` while any dialog in the list is open (F-013): `Modal.host`'s
  `blocked` and `AppShell.modalOpen` are gone, and so is the `isBlocking` helper
  every page had to write. A dialog cannot be drawn outside the list, so it cannot
  be forgotten. `ContextMenu.view` stays plain `Html`: it is a popup, not a dialog.
- Removed: `Modal.host`, `AppShell.modalOpen`, `Modal.refocus` and `Drawer.refocus`.
- Focus ownership (F-005): when the element that has focus in the dialog on top is
  removed or disabled (a button replaced after an action, a confirm button that
  becomes disabled), focus moves to the dialog itself. Browsers send no event for
  that; an invisible element in the dialog runs a CSS animation exactly while no
  overlay contains focus, and `animationstart` is the signal. Nothing to call.
- The opener (F-006): a closed dialog remembers the last elements of the page that
  had focus. `open ""`, or an opener that is gone, returns focus to the most recent
  of them that still exists, so a drawer opened by a route change or by a command of
  the palette needs no opener carried by the application. An explicit opener is
  still tried first.
- Toasts (F-010, O-011): while a dialog is open the stack moves to the top of the
  window, so that it never covers the footer buttons, and it is the last stop of the
  dialog's `Tab` loop: footer, then the buttons of the toasts, then the first element
  of the dialog. The stack is `role="log"` and no longer `role="region"`, so two
  stacks (the application's and a page's) are not two landmarks with one name.
- Landmarks (F-020): the header and the footer of a dialog are `div`s, not
  `header` and `footer`, so two open dialogs no longer give axe duplicate banner and
  contentinfo landmarks.
- `ConfirmDialog.confirmDisabled : Bool -> Attribute msg` and
  `ConfirmDialog.clearFailure : State -> State`; the documentation of `setFailed`
  says it is for the answer of the server, not for checking input (F-011).

### Fixes from the first three applications (A8, the sure fixes)

Three applications were built from the documentation alone (`apps/`); these are the
cheap, certain fixes from that evaluation. Nothing was released before them, so they
change the first API and not a published one.

- `Remote` is `NotAsked | Loading | Loaded a | Failed Problem` (it was `Success` and
  `Failure`), and `Remote.isLoaded` and `Remote.isFailed` follow. `Success` was also a
  `Theme.Tone`, so an application that used both had to qualify one of them; `Tone`
  keeps `Success` and `Remote` has its own words. (`Autocomplete` matches on
  `Remote.Failed` and `Remote.Loaded` because its internal content type has a `Failed`
  of its own.)
- Documentation examples that did not compile are fixed: the `Klar.Table` module
  doc and its comments gave plain strings where a `Table.ColumnId` is needed (F-001,
  S-001, O-006), and the `Klar.AppShell` doc used `SideNav.item` without `Keys` and
  `SideNav.State` without its key type (F-002, O-007). `npm run check:docs` now also
  fails on these patterns (a string literal as the id of a `Table` column
  constructor, `SideNav.item` or `group` with a record as the first argument,
  `Remote.Success`, `Remote.Failure`) in the exposed modules, the README, USING.md
  and CONTRIBUTING.md. Compiling every example is still a later task.
- USING.md starts with "Start here": a complete `Browser.application` with an
  `AppShell`, a `SideNav` typed by a `Page`, a `Remote` and a `Table`, and the
  `index.html`. It compiles. It says which `main` is mounted how (`Browser.sandbox`
  and `element` with `{ node: ... }`, `Browser.document` and `application` with
  plain `init()`, and the latter for an `AppShell`) and lists `elm/url` as a direct
  dependency of an application (F-003, S-006, O-008). The README says the same in a
  paragraph.
- New: `Date.toPosix : Time.Zone -> Date -> Time.Posix`, the start of the day in
  that zone (F-014).
- New: `Format.iso8601 : Time.Posix -> String`, UTC to the second, as
  `2026-10-22T14:05:00Z` (S-020).
- New: `Stat.change { current, previous }`, which works out the percentage for you
  and shows no change, never `NaN`, when the previous value is 0 (S-018). It reuses
  the delta of the tile, so `lowerIsBetter`, `deltaTone` and `deltaLabel` still apply.
- `Layout.grid [ Layout.minColumn n ]` uses `auto-fit`: two children in a wide grid
  share the whole row instead of leaving empty tracks (S-011). The default grid
  changes the same way.
- New: `Layout.fillRest`, for a `stack`: it is as tall as the room left in its
  parent (inside an `AppShell`, the content area) and hands that height on to
  its children, so a `Table.fillHeight` table fills the rest of the page under its
  heading (F-017). The one new attribute, because without it the application had to
  guess a `Table.maxHeight`.
- `Form.section` draws its title as an `h2`, not an `h3`: under the `h1` of a page
  the outline passes the `heading-order` check of axe (O-015). It takes no level
  argument, to keep the function as it is; `Card` keeps `headingLevel` (default 3).
- The links of the form error summary are at least 24 by 24 CSS pixels (WCAG 2.2
  target size, O-016).
- A `Timeline` with `maxHeight` and no `onLoadMore` takes the keyboard focus
  (`tabindex="0"`) and is a region named by `ariaLabel` ("Events" without one), so it
  can be scrolled without a mouse (S-012).
- `InlineEdit` leaves out "Try again" after a failed save when `Remote.isRetryable`
  says no (a conflict, a validation problem), as `Form.status` and `Select` do (O-014).
- The `Select` popup is as wide as its longest option up to 36rem (at least the field
  and 260 pixels), so descriptions are no longer cut (O-013).
- In `Form.actions` the status takes the free space and wraps inside itself, so a
  long message never pushes the buttons onto a second line (O-012).
- `Klar.Text` documents which functions are blocks and which are inline (O-020).

**Status of the sure fixes of A8.** Fixed: F-001, F-002, F-003, F-014, F-017, S-001,
S-006, S-011, S-012 (for `Timeline`), S-018, S-020, O-006, O-007, O-008, O-012,
O-013, O-014, O-015, O-016, O-020. Skipped, with the reason: the same scroll-area check
for `Tree.maxHeight` and `ListItem.maxHeight` (S-012 suggested it): the tree has
focusable nodes inside it, a list may or may not, and which rule fits needs a
decision. Compiling every doc example (A1) and the larger items of A8 (the form
model, the overlay layer) are later work. A decision for the owner to check: the
`Form.section` default of `h2` (inside a `Card`, whose title is an `h3`, an `h2` is
legal for axe, but a purist would want `h4`).

### Data-dense performance (A8)

50 000 rows are a normal case now. The cause of the slowness, found by profiling in
Chrome, was not the sorting but the work around it: each message turned every row into
text again (the search text of all columns, the sort keys, number formatting), and a page
change sorted the 50 000 rows again. Measured in headless Chrome on a development build
(median of three, including two animation frames, which are about 33 ms of every
number) with 50 000 generated rows of 7 columns, before and after on the same machine:

| | before | after |
|---|---|---|
| a key in the search box of a client-mode `Table` | 200 to 220 ms | 60 to 75 ms |
| a sort click (text column, number column) | 110 to 180, 70 to 120 ms | 25 to 45 ms |
| a page change in a sorted table | 105 to 150 ms | 27 to 30 ms |
| `Search.scorePrepared` over 50 000 texts of 230 characters, any query | 80 to 200 ms | 30 to 115 ms |
| preparing the rows, once, when they arrive | none | 0.4 to 0.6 s |

- New: `Table.prepareRows : Locale -> List (Column row msg) -> Array row -> Rows row`
  and `Table.preparedRows : Remote (Rows row) -> Attribute id row msg`. The rows are
  prepared once, when they arrive: the table keeps for each row the text that the search
  looks in, for each sortable column the rows in ascending and descending order, and the
  sums of the footers. It no longer turns every value into text on every message, and a
  page change no longer sorts again (S-008). `Table.rowsArray : Rows row -> Array row`
  gives the same `Array` to the rest of the page, so that the application holds one
  collection for the table and for a `VirtualList` (S-019). `Table.rows` with a `List` is
  unchanged and as fast as before. Rows prepared for other columns or another locale are
  shown correctly, and as slowly as a `List`. While a search or a filter is active the
  table still goes through the search texts of every row on each view (a few
  milliseconds at 50 000 rows); with none, a view costs the page.
- New: `Table.virtual`. A long table scrolls instead of paging and draws only the
  rows in view, one height (the density's), with the header and the totals in view
  (S-009). Client mode has no pages then; server mode keeps its pagination and draws
  the rows of the page that are in view. The rows come and go in chunks of 16, each a
  `tbody` of its own, so that scrolling a few rows moves none and the keyboard focus
  stays. Arrow keys, PageUp and PageDown (a screenful), Home, End and Space work over all
  the rows; the scroll area is a tab stop while the row with the tab stop is not
  drawn. The checkbox in the header selects all matching rows. There are no expanded
  rows and no wrapped text in such a table. The docs say when to page and when to scroll.
- New: `VirtualList.list`, with `VirtualList.density`, `VirtualList.onSelect`,
  `VirtualList.selected` and `VirtualList.active`. The list makes its own `ul` and `li`,
  with the row height from the density (so the application writes no style and needs
  no height, S-002 and S-007), `aria-posinset` and `aria-setsize` on every row, and the
  keys of a list box over `aria-activedescendant`: one tab stop, not one for every row,
  ArrowDown and ArrowUp, Home, End, PageDown and PageUp, Enter and Space (S-014).
  `ListItem.content` is a `ListItem` row without the `li` and without anything to
  click, for the rows of such a list. `VirtualList.view` and `viewGrouped` remain
  for the select components, which draw their own options.
- `Search`: every exact match is a match of the word inside the text, so that is asked
  first and a text that lacks the word is not asked about its start and its words; a text
  that lacks one of the letters of a query cannot match loosely, and `String.contains`
  tests that natively before the typo-tolerant walk, so a rare word no longer costs a
  walk per text (S-010). Scores and ranking are unchanged (fuzz tests compare them with
  the plain scoring on random corpora).
- A footer sum is no longer cut with an ellipsis: the label stays on one line and the sum
  goes on the next when they do not fit (F-009).
- S-023 (a column that is hidden in a narrow table): not added. The table already
  scrolls sideways with a shadow at the cut edge; the docs now say how to arrange the
  columns for a narrow place (`pinned`, `minWidth`, `hiddenByDefault` with
  `columnChooser`) instead of a new attribute.
- The bulk bar no longer goes through every matching row on each view of a client-mode
  table: it needs the keys of the matching rows only when the selection is as large as
  the matching rows, or when the user asks for them, and it counts the selected rows
  that a search or a filter hides only when the search or a filter leaves rows out.
