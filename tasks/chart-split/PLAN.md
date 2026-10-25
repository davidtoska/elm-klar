# Chart split plan

Pure refactor on codex/chart-split in its own worktree, based on the completed
Table split at 103db76. Follow the same constraints as tasks/codex-split-table.md
in the main checkout: no public API/docs/default/markup/event/CSS changes, no
existing test edits, dependencies or protected-file changes. Commit one cohesive
group only after format, full check, byte-identical docs and identical DOM.

## Dependency order

1. Types: series, segments, configuration, prepared data and geometry contracts.
2. Numbers and Colors: finite values, numeric text and color-class choices.
3. Axis, Data, Config, Masks: axis geometry, constructors, attributes/defaults,
   threshold decisions and pure SVG-mask strings.
4. Texts: localized vocabulary and accessible summaries.
5. Preparation: series arrays, gaps/runs, stacked pieces, tooltips and table values.
6. Shared: state shells, headers, legends, category interaction and plot pieces.
7. Line, Bar, Donut, Scalar and Sparkline: each concrete chart renderer.
8. RemoteView: remote adapters over the concrete renderers and coordinated Data.
9. Klar.Chart: documented public compatibility facade.

No lower module imports a higher one. Pure modules do not import Html or chart
renderers. Keep all original declaration bodies verbatim and audit them afterwards.
No module may exceed about 1,200 lines.

## Public boundary

Keep the public opaque unions and their original payload shapes, comments and
signatures. Convert their payloads at the boundary rather than replacing unions
with aliases, which would change the compiler's documentation JSON. A temporary
Core holds implementations while groups are extracted; it is removed at the end.

## Verification and stopping

Before any code move, save the green full baseline, docs JSON, test inventory and
chart/sparkline DOM outside the repository. Capture all chart-bearing routes using
headless Chrome, including .klar-chart-fresh containers and .klar-chart-spark.

After every group: format, full check, docs byte comparison and DOM comparison.
Stop on unrelated check failures, unexplained docs/DOM drift, required edits to an
existing test/public doc comment, or a step that cannot be green in three attempts.
Record reasons in PROGRESS.md, and behavior bugs in FINDINGS.md without fixing them.

Keep PROGRESS.md current with hashes, next steps and decisions. Finish with the
module/job/line-count report, all checks green, committed branch, no merge/push/tag
or publication. The main checkout and completed Table implementation stay untouched.
