# Table split plan

Pure refactor, based on c84c57d. Work only on codex/table-split in its own worktree.
The main checkout has unrelated, uncommitted AI component work and is left untouched.

## Compatibility boundary

Keep the public module comment, every public declaration's comment and signature, and
all public unions (including opaque unions) in Klar.Table. Turn opaque implementation
payloads into internal values; translate the three public, open unions and Query at
the boundary. This keeps the compiler's documentation JSON identical, including its
distinction between opaque unions and aliases. An alias alone would change that JSON.
Internal implementations keep their original bodies. No markup or styles change.

## Dependency order (low to high)

1. Existing Csv, Index, Sort, Texts remain independent.
2. Types: internal data vocabulary (including the view context); Identity: row/column
   keys and small helpers; DomIds: stable element names.
3. Numeric, Filter, Selection, ColumnLogic: pure numeric values, filtering,
   selection and column decisions.
4. Query and State: JSON, accessors and setters; Columns: constructors/attributes;
   Window: pagination and virtual geometry (uses ColumnLogic.hasFooter).
5. Rows: preparation and source access; Config: table attributes; Update: transitions
   and focus, timer, scroll and download commands.
6. Processing: the client/server row pipeline.
7. Popup and Keyboard: markup/event decoding and focus helpers; Layout: shared
   geometry, column sizing and cell attributes.
8. Export, HeaderFilters, Footer: separate export, filter-input and footer view jobs.
9. Bulk, Header: bulk selection controls and table headings.
10. Toolbar: search, summaries, density and column choices (uses HeaderFilters).
11. Body: states, keyed rows, detail rows and cells (uses Toolbar's reset action).
12. View: composition of toolbar, frame and footer.
13. Klar.Table: documented public boundary.

The exact assignments may be refined from the actual function dependency graph before
each move. Every new dependency must point down this order; record refinements here.
Pure logic modules do not import Html or a table view. Columns may reference Html in
their cell descriptions but must not import table rendering.

## Steps and verification

After the initial Identity extraction, establish the public boundary in one
isolated step. A temporary Core module holds the original implementation while
the public facade preserves its types and comments. Then extract its data types
and one cohesive logic/view group per step. Core may temporarily exceed the size
target; it must disappear into the smaller modules before completion. This avoids
rewriting function bodies to alternate between public and internal type names
throughout the monolith during every subsequent move.

Capture the full check log, docs JSON, test-file inventory and count, and all showcase
table roots outside the repository before moving code. Commit the capture harness and
this plan. Then move one cohesive group per commit, starting with leaf logic, and run
format, the full check, byte comparison of docs JSON and DOM snapshots after each step.
Record commit hashes, validation and the next step in PROGRESS.md after every commit.

Do not change existing tests, elm.json, check scripts, CLAUDE.md, ROADMAP.md or .github.
Record any discovered bugs in FINDINGS.md without fixing them. Stop on the task's
specified conditions. Only begin Chart after Table meets every completion condition.
