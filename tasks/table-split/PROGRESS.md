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
