# Table split report

Klar.Table's 7742-line implementation is split into internal modules with
one implementation of every original declaration. The public module is a
2370-line documentation and compatibility facade. API, defaults, rendered
markup and event behavior remain unchanged.

Branch: codex/table-split. Base: c84c57d. Final code validation commit: 06c509c.
No merge, push, tag or publication was performed.

## What moved

| Module | Job | Lines |
|---|---|---:|
| Klar.Table.Body | Loading, failure, empty and keyed data bodies, detail rows and cells | 719 |
| Klar.Table.Bulk | Bulk-selection controls and actions | 150 |
| Klar.Table.ColumnLogic | Pure column visibility, sort keys and export values | 107 |
| Klar.Table.Columns | Column constructors and column attributes | 653 |
| Klar.Table.Config | Table attributes and their default/final configuration | 570 |
| Klar.Table.Csv | Spreadsheet-safe CSV field and matrix encoding (unchanged) | 99 |
| Klar.Table.CsvRows | Pure column/row CSV assembly and filename suffixes | 37 |
| Klar.Table.DomIds | Stable table, row, popup and trigger element names | 67 |
| Klar.Table.Export | Matching/page/selection export menus | 174 |
| Klar.Table.Filter | Pure filter drafts, choices, numeric bounds and normalized search | 318 |
| Klar.Table.Footer | Column totals, result range and pagination | 233 |
| Klar.Table.Header | Header cells, sorting buttons and system columns | 271 |
| Klar.Table.HeaderFilters | Filter buttons, input popups, option counts and numeric precision | 413 |
| Klar.Table.Identity | Typed row keys, ranges, set toggles and value lookups | 73 |
| Klar.Table.Index | Prepared row indexes and aggregates (unchanged) | 780 |
| Klar.Table.Keyboard | Pure row/range message decisions and event-target decoders | 257 |
| Klar.Table.Layout | Column geometry, pinned cells, scroll geometry and cell attributes | 405 |
| Klar.Table.Numeric | Exact monetary aggregates and locale-aware numeric values | 67 |
| Klar.Table.Popup | Popup markup and outside-click/focus decoding | 106 |
| Klar.Table.Processing | Client/server filtering, indexed sorting, paging and windowing | 356 |
| Klar.Table.Query | Versioned JSON encoding and tolerant query decoding | 138 |
| Klar.Table.Rows | Prepared row creation and access to row sources | 126 |
| Klar.Table.Selection | Pure picks, all-matching exceptions, disabled-row decisions and counts | 234 |
| Klar.Table.Sort | Stable sort keys and comparisons (unchanged) | 373 |
| Klar.Table.State | Initialization, query accessors and explicit state setters | 304 |
| Klar.Table.Texts | Localized table texts (unchanged) | 367 |
| Klar.Table.Toolbar | Search, active filters, density controls and column choices | 430 |
| Klar.Table.Types | Shared internal data vocabulary, including column/model/view contracts | 425 |
| Klar.Table.Update | State transitions and focus, scroll, debounce and download commands | 478 |
| Klar.Table.View | Composition of toolbar, frame, header, bodies and footer | 374 |
| Klar.Table.Window | Pure pagination and virtual-row geometry | 106 |

All internal modules are below 1,200 lines; the largest is
780 lines. Existing Csv, Index, Sort and Texts remain unchanged.

The public facade retains every original doc comment, signature and union shape.
Opaque payloads and messages are converted at the boundary instead of replacing
opaque unions with aliases: aliases would change the required documentation JSON.
Constructor-for-constructor message conversion also preserves existing CSV tests
that stringify opaque messages. All algorithms remain in the internal modules.

## Dependency order

Dependencies come first in each group; the complete import graph was checked for cycles.

1. Csv, Sort, Index, Texts.
2. Types, Identity, DomIds.
3. Numeric, Filter, Selection, ColumnLogic.
4. Query, State, Columns, Window.
5. Rows, Config, Update, CsvRows.
6. Processing.
7. Popup, Layout, Keyboard.
8. Export, HeaderFilters, Footer.
9. Bulk, Header.
10. Toolbar.
11. Body.
12. View.
13. Klar.Table.

No internal module imports View. The pure logic modules do not import Html.
Column descriptions retain their Html-valued cell callbacks, but Columns and the
shared Types contracts do not import the table view. Keyboard decoding is independent
of Html; Body owns the HTML range-click attribute.

## Verification

- npm ci and npm run check passed before the first edit.
- Each extraction was formatted, fully checked, compared against the original docs
  JSON and compared against the original showcase table DOM before being committed.
- Final npm run check passed: 11,373 tests, zero failures,
  strict doc examples, public API audit and all showcase/example builds included.
- Original test files: 151; final test files: 164.
  All original test files are unchanged; 13 focused new files add
  16 cases for newly importable logic.
- docs-after.json is byte-identical to docs-before.json for all 141 public modules.
  SHA-256: 48e636772509fd0553580cd2994408fb0b1f4f64af27375b3355ca538430c861.
- DOM: 22 identical table roots across 8 table-bearing routes.
  Discovery visited all 36 showcase and example pages. Chrome used a 1440x1000 window,
  a 6,000 ms virtual-time budget and a three-second real page-load settling guard.
- All 312 original declarations have exactly one unchanged internal implementation,
  comparing source tokens while ignoring comments and formatting.
- Import graph is acyclic. No internal module is exposed in elm.json.

Baseline and full logs are outside the repository:
C:/Users/DavidToska/AppData/Local/Temp/klar-table-split-baseline/.
The authoritative DOM baseline is dom-before-settled/; the final comparison is
dom-final-view/. Test inventories are test-files-before.txt and test-files-after.txt.
Run the committed tasks/table-split/dom-snapshot.mjs against a fresh example build
to reproduce captures; its optional second directory argument compares a baseline.

## Left alone

Existing tests, elm.json, dependencies, CSS, showcase sources, check scripts,
CLAUDE.md, ROADMAP.md and .github are unchanged. The main checkout's unrelated work
was not copied or modified. Existing report-only check warnings were not fixed.
No features, behavior fixes or public renames were added.

FINDINGS.md contains no newly discovered behavior bugs. Chart work may begin only
after this report and the final Table state are committed.
