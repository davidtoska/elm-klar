# Chart split progress

Status: COMPLETE. Final code validation commit: 250ad91. Both the Table and Chart
tasks are complete; REPORT.md records the Chart module map and verification.
No active process remains. Branches are committed locally; no merge/push/tag/publication.

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
- Extraction pipeline 41660 completed all groups. RemoteView retired the empty
  Core and passed final validation: 11,383 tests, byte-identical documentation,
  all 71 diagram/sparkline roots identical. No additional import-only code changes
  were made after that validated final state. Report evidence is in
  check-remoteview.log, dom-remoteview/ and source-audit-final.log.
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
- Commit f2dec0f: Colors complete.
- Next: Data.

- Data: format, full check, byte-identical docs and identical chart/sparkline roots passed.
- Commit 5772425: Data complete.
- Next: Config.

- Config: format, full check, byte-identical docs and identical chart/sparkline roots passed.
- Commit 10719fc: Config complete.
- Next: Texts.

- Texts: format, full check, byte-identical docs and identical chart/sparkline roots passed.
- Commit 7697e48: Texts complete.
- Next: Masks.

- Masks: format, full check, byte-identical docs and identical chart/sparkline roots passed.
- Commit acab8e7: Masks complete.
- Next: Preparation.

- Preparation: format, full check, byte-identical docs and identical chart/sparkline roots passed.
- Commit 1f16972: Preparation complete.
- Next: Shared.

- Shared: format, full check, byte-identical docs and identical chart/sparkline roots passed.
- Commit d7e3273: Shared complete.
- Next: Line.

- Line: format, full check, byte-identical docs and identical chart/sparkline roots passed.
- Commit 713dbb7: Line complete.
- Next: Bar.

- Bar: format, full check, byte-identical docs and identical chart/sparkline roots passed.
- Commit 5b1ca13: Bar complete.
- Next: Donut.

- Donut: format, full check, byte-identical docs and identical chart/sparkline roots passed.
- Commit 6e3c9e2: Donut complete.
- Next: Scalar.

- Scalar: format, full check, byte-identical docs and identical chart/sparkline roots passed.
- Commit b8d47c1: Scalar complete.
- Next: Sparkline.

- Sparkline: format, full check, byte-identical docs and identical chart/sparkline roots passed.
- Commit 93c9bce: Sparkline complete.
- Next: RemoteView.

- RemoteView: format, full check, byte-identical docs and identical chart/sparkline roots passed.
- Commit 250ad91: RemoteView complete.
- Next: inspect the remaining dependency groups before the next move.
- Final audit passed: all 141 original declarations have one unchanged internal
  implementation; dependency graph acyclic; nine pure modules do not import Html.
- Final sizes: public facade 890 lines; 16 internal modules, largest 448 lines.
- Test inventory: 164 original files unchanged; eight new files add ten cases.
- Completed Table sources and all protected files are unchanged from 103db76.
- Next: none. Commit this completion report and leave both branches for review.
