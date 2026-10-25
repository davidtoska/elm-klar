# Chart split report

Klar.Chart's 3499-line implementation is split into internal modules.
Its public module is a 890-line documentation and compatibility facade.
Public API, comments, defaults, markup, CSS, category events and remote states are unchanged.

Branch: codex/chart-split. Base: 103db76 (the completed Table split).
Final code validation commit: 250ad91. No merge, push, tag or publication.

## What moved

| Module | Job | Lines |
|---|---|---:|
| Klar.Chart.Axis | Pure nice axis limits, ticks and percentage coordinates | 186 |
| Klar.Chart.Bar | Grouped/stacked horizontal and vertical bar rendering | 404 |
| Klar.Chart.Colors | Pure series-slot and semantic-tone class selection | 43 |
| Klar.Chart.Config | Chart attributes, defaults, legend and threshold decisions | 448 |
| Klar.Chart.Data | Series, segments and coordinated category/date data constructors | 125 |
| Klar.Chart.Donut | Donut slice grouping, legend and rendering | 204 |
| Klar.Chart.Line | Line/area plots, axes and category interaction | 208 |
| Klar.Chart.Masks | Pure SVG-mask strings and ring geometry | 93 |
| Klar.Chart.Numbers | Finite-value handling, numeric measurements and locale-aware formatting | 256 |
| Klar.Chart.Preparation | Series arrays, line runs, stacked pieces, tooltips and data-table values | 269 |
| Klar.Chart.RemoteView | Remote adapters over concrete chart renderers | 161 |
| Klar.Chart.Scalar | Gauge and meter rendering over configured ranges | 247 |
| Klar.Chart.Shared | Remote/state shells, headers, legends, category interaction and plot pieces | 372 |
| Klar.Chart.Sparkline | Compact trends with loading, failure, empty and freshness states | 217 |
| Klar.Chart.Texts | Localized vocabulary and accessible chart summaries | 69 |
| Klar.Chart.Types | Internal series, configuration, prepared-data and axis contracts | 178 |

All 16 internal modules are below 1,200 lines; the largest is
448 lines. The temporary Core is removed. Public Series, Segment,
Attribute and Data remain opaque unions with their original constructor/payload
shapes; thin adapters retain byte-identical docs rather than turning those unions
into aliases. Every original algorithm has one implementation.

## Dependency order

1. Types.
2. Numbers, Colors.
3. Axis, Data, Config, Masks.
4. Texts.
5. Preparation.
6. Shared.
7. Line, Bar, Donut, Scalar, Sparkline.
8. RemoteView.
9. Klar.Chart.

The actual import graph was checked for cycles. Types, Numbers, Axis, Colors,
Data, Config, Texts, Masks and Preparation do not import Html. Concrete renderers
depend on those contracts/helpers and Shared; the remote adapters depend on the
concrete renderers. Nothing imports the public facade internally.

## Verification

- Table was fully completed and committed before this second task began.
- npm ci and npm run check passed before Chart edits: 11,373 tests, zero failures.
- Each code extraction passed format, full check, docs byte comparison and
  chart/sparkline DOM comparison before being committed.
- Final npm run check: 11,383 tests, zero failures; strict doc examples,
  API checks and every showcase/example build included.
- Original test/support files: 164; final files: 172.
  Existing files are unchanged. 8 new files add 10 cases
  for independently importable pure helpers.
- docs-after.json is byte-identical to docs-before.json for all 141 public modules.
  SHA-256: 48e636772509fd0553580cd2994408fb0b1f4f64af27375b3355ca538430c861.
- DOM: all 71 chart/sparkline roots identical on 4 chart-bearing
  routes. Discovery visited all 36 showcase/example pages. Captures include the
  fresh/refresh/old-data containers and sparklines as well as chart figures.
- Chrome: 1440x1000 window, 6,000 ms virtual-time budget, three-second real settling guard.
- All 141 original declarations have exactly one unchanged internal implementation,
  comparing source tokens while ignoring comments and formatting.
- No new module is exposed in elm.json, and no dependency was added.

Baseline and logs are outside the repository:
C:/Users/DavidToska/AppData/Local/Temp/klar-chart-split-baseline/.
Authoritative snapshots: dom-before/ and dom-remoteview/; inventories:
test-files-before.txt and test-files-after.txt. The committed
tasks/chart-split/dom-snapshot.mjs reproduces captures from a fresh example build;
its optional second directory argument compares a baseline.

## Left alone

The completed Table code, original tests, elm.json, dependencies, CSS, showcase
sources, check scripts, CLAUDE.md, ROADMAP.md and .github are unchanged from 103db76.
The main checkout remains untouched. Existing report-only check warnings were
left alone. No feature, behavior fix or public rename was added.

FINDINGS.md records no newly discovered behavior bugs.
