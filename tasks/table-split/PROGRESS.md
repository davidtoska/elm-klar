# Table split progress

## Baseline

- Branch: codex/table-split, separate managed worktree, base c84c57d.
- npm ci succeeded; npm run check passed before edits.
- 11,357 tests passed, zero failures (151 Elm test/support files).
- Full log and docs-before.json: C:/Users/DavidToska/AppData/Local/Temp/klar-table-split-baseline/.
- Test-file inventory saved alongside the baseline.
- DOM baseline: 22 tables on 36 showcase/example pages, saved in dom-before/.
- f999e2f: Harness and plan committed.
- dcb2f9a: Identity extraction is green: format and full check passed (11,359 tests), docs
  byte-identical, all 22 table roots identical on the eight routes with tables.
- 0b62c30: Public boundary is green: 11,359 tests, byte-identical docs, 22 identical table
  roots. Original union constructor/payload shapes are retained, including Msg.
- Next: extract Types, Numeric, Filter, Selection and DomIds in dependency order.

## Decisions

Execution notes for resuming a long run:

- Original task: C:/Users/DavidToska/code/elm-klar/tasks/codex-split-table.md.
- Scratch automation and logs live alongside docs-before.json. split.mjs moves
  named groups from temporary Core, preserving declaration bodies. pipeline.mjs
  adds focused new tests, runs validate.mjs, commits only on success, and stops on
  failure. verify-original.mjs confirms all 312 original declarations have one
  unchanged internal implementation and checks the dependency graph.
- All logic groups through Processing are complete. The second pipeline (84947)
  stopped on syntax in the new ColumnLogic test; its second validation passed.
  The resumed pipeline (6175) completed Rows, Config, Window, Update and Processing.
  CsvRows is complete. Rendering pipeline 11692 runs Popup, Layout, Keyboard,
  Export, Bulk, HeaderFilters, Header, Toolbar, Body and Footer. Inspect its active
  result before further edits. Completion hashes are appended below.
- After that: CsvRows, Popup, Layout, Keyboard, Export, Bulk, HeaderFilters, Header,
  Toolbar, Body, Footer, then rename remaining Core composition to View and clean
  imports. Recheck dependencies before each move; Toolbar depends on HeaderFilters.
- Table must satisfy every done condition and have its REPORT.md committed before
  starting the separately requested Chart split.

- Preserve opaque public unions rather than replacing them with aliases, because the
  required byte-identical documentation JSON distinguishes these representations.
- Preserve their original payload shapes too: existing CSV tests stringify opaque
  messages, so Msg maps constructor-for-constructor rather than adding a wrapper.
- Subsequent full checks limit elm-test to four workers through an external Node
  preload, retaining all tests and the default 100 fuzz runs; this avoids spawning
  28 large test workers on this machine. No repository check scripts are changed.
- No user changes copied from the main checkout; its unrelated work stays there.
- Chrome can fast-forward its virtual clock before Elm's final animation frame.
  The harness holds page load open for three real seconds, then extracts table
  roots from Chrome's final dump. Recaptured the original compiled source with
  this harness before comparing the identity extraction. Stable baseline is now
  dom-before-settled/; earlier exploratory captures are not the oracle.

- Types: format, full check, byte-identical docs and 22 identical table roots passed.
- Commit 34a21d8: Types complete.
- Next: Numeric validation, then Filter, Selection and DomIds.

- Numeric: format, full check, byte-identical docs and 22 identical table roots passed.
- Commit a785bd8: Numeric complete.
- Next: Filter validation, then Selection and DomIds.

- Filter: format, full check, byte-identical docs and 22 identical table roots passed.
- Commit 6ae8b7e: Filter complete.

- Selection: format, full check, byte-identical docs and 22 identical table roots passed.
- Commit f53a76f: Selection complete.
- Next: DomIds validation. Then State, Query, Columns, ColumnLogic, Rows, Config,
  Window, Update and Processing (tests that need column/config builders follow them).

- DomIds: format, full check, byte-identical docs and 22 identical table roots passed.
- Commit b852c59: DomIds complete.
- Next: State, Query, Columns, ColumnLogic, Rows, Config, Window, Update, Processing.

- State: format, full check, byte-identical docs and 22 identical table roots passed.
- Commit 602c859: State complete.
- Next: Query.

- Query: format, full check, byte-identical docs and 22 identical table roots passed.
- Commit 3f653c2: Query complete.
- Next: Columns.

- Columns: format, full check, byte-identical docs and 22 identical table roots passed.
- Commit cffe11d: Columns complete.
- Next: ColumnLogic.
- ColumnLogic attempt 1: fixed syntax in the newly added test's let-pattern;
  no existing test changed. Revalidating the step before continuing.
- ColumnLogic attempt 2 passed: 11,367 tests, identical docs and all 22 table roots.
- Commit 834f944: ColumnLogic complete.
- Next: Rows, Config, Window, Update, Processing.

- Rows: format, full check, byte-identical docs and 22 identical table roots passed.
- Commit e1d6d51: Rows complete.
- Next: Config.

- Config: format, full check, byte-identical docs and 22 identical table roots passed.
- Commit abf10bb: Config complete.
- Next: Window.

- Window: format, full check, byte-identical docs and 22 identical table roots passed.
- Commit 517c3eb: Window complete.
- Next: Update.

- Update: format, full check, byte-identical docs and 22 identical table roots passed.
- Commit 4ad231b: Update complete.
- Next: Processing.

- Processing: format, full check, byte-identical docs and 22 identical table roots passed.
- Commit ad3e39e: Processing complete.
- Next: inspect the remaining dependency groups before the next move.

- CsvRows: format, full check, byte-identical docs and 22 identical table roots passed.
- Commit 07c2796: CsvRows complete.
- Next: Popup.

- Popup: format, full check, byte-identical docs and 22 identical table roots passed.
- Commit 038ce88: Popup complete.
- Next: Layout.

- Layout: format, full check, byte-identical docs and 22 identical table roots passed.
- Commit 47cd0ba: Layout complete.
- Next: Keyboard.

- Keyboard: format, full check, byte-identical docs and 22 identical table roots passed.
- Commit f34e06f: Keyboard complete.
- Next: Export.

- Export: format, full check, byte-identical docs and 22 identical table roots passed.
- Commit 1215b70: Export complete.
- Next: Bulk.

- Bulk: format, full check, byte-identical docs and 22 identical table roots passed.
- Commit 5d992c1: Bulk complete.
- Next: HeaderFilters.

- HeaderFilters: format, full check, byte-identical docs and 22 identical table roots passed.
- Commit 3e711b8: HeaderFilters complete.
- Next: Header.

- Header: format, full check, byte-identical docs and 22 identical table roots passed.
- Commit ef6b697: Header complete.
- Next: Toolbar.

- Toolbar: format, full check, byte-identical docs and 22 identical table roots passed.
- Commit 889970f: Toolbar complete.
- Next: Body.

- Body: format, full check, byte-identical docs and 22 identical table roots passed.
- Commit b6cb4eb: Body complete.
- Next: Footer.

- Footer: format, full check, byte-identical docs and 22 identical table roots passed.
