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
- State, Query and Columns are complete. The second pipeline (84947) stopped on
  syntax in the new ColumnLogic test; its second validation passed. Resume with
  Rows, Config, Window, Update and Processing; inspect the active pipeline's
  result before further edits. Completion hashes are appended below.
- After that: Popup, Layout, Keyboard, Export, Bulk, HeaderFilters, Header,
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
