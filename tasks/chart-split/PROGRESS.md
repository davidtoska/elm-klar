# Chart split progress

## Baseline

- Branch codex/chart-split, separate managed worktree, base 103db76.
- Table was completely verified and committed before Chart work started.
- npm ci and npm run check passed before edits: 11,373 tests, zero failures.
- docs-before.json, Chart-before.elm, logs and the 164-file test inventory are in
  C:/Users/DavidToska/AppData/Local/Temp/klar-chart-split-baseline/.
- Chart/sparkline DOM discovery completed: 71 roots across four chart-bearing
  routes, discovered from all 36 showcase/example pages. Saved in dom-before/.
  Uses the proven Table settling guard; exec 73480 completed successfully.
- Next: finish DOM baseline, commit plan/harness, establish public facade, then
  extract Types, Numbers, Axis, Colors, Data, Config, Texts, Masks, Preparation,
  Shared, Line, Bar, Donut, Scalar, Sparkline and RemoteView in dependency order.

## Execution notes

- Original task: C:/Users/DavidToska/code/elm-klar/tasks/codex-split-table.md.
- CLAUDE.md and ROADMAP.md were read; protected files remain unchanged.
- Scratch tools: facade.mjs establishes opaque payload-preserving adapters;
  split.mjs moves named groups and redirects public forwards; validate.mjs runs
  format/check/docs/DOM; verify-original.mjs audits original implementations and
  dependencies; cleanup-imports.mjs removes unneeded imports at completion.
- Limit later elm-test checks to four workers via the external preload, retaining
  every test and the default 100 fuzz runs. Baseline used the unmodified command.
- No agent delegation. No main-checkout or Table-source edits. No new dependency.
- Public Series, Segment, Attribute and Data remain opaque unions with the same
  documentation and runtime constructor/payload shapes.

- Commit 1673c89: plan and DOM harness.
- Public facade validation (94844) passed: 11,373 tests, byte-identical docs and
  71 identical chart/sparkline roots. Original opaque constructor/payload shapes
  are preserved without any existing test changes.
- Next: Types, Numbers, Axis, Colors, Data, Config, Texts, Masks, Preparation,
  Shared, Line, Bar, Donut, Scalar, Sparkline, RemoteView; then remove empty Core,
  clean imports, final full validation, size/dependency audit and report.
- Commit bcbebf7: public facade complete.

- Types: format, full check, byte-identical docs and identical chart/sparkline roots passed.
- Commit 114310f: Types complete.
- Next: Numbers.

- Numbers: format, full check, byte-identical docs and identical chart/sparkline roots passed.
- Commit aaac395: Numbers complete.
- Next: Axis.

- Axis: format, full check, byte-identical docs and identical chart/sparkline roots passed.
- Commit e17437e: Axis complete.
- Next: Colors.

- Colors: format, full check, byte-identical docs and identical chart/sparkline roots passed.
