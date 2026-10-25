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
2. Types: internal data vocabulary; Identity: row/column keys and small helpers.
3. Filter, Selection, Window, ColumnLogic: pure filtering, selection, geometry and column decisions.
4. State and Query: state accessors, setters and JSON; Columns: constructors/attributes;
   Rows: preparation and source access; Config: table attributes.
5. Update: state transitions and commands; Processing: client/server row pipeline.
6. ViewTypes and DomIds: view context and stable element names; Popup and Keyboard:
   event decoding and focus helpers; Layout: shared geometry and cell attributes.
7. Export, Bulk, Toolbar, HeaderFilters, Header, Body, Footer: separate view jobs.
8. View: composition of toolbar, frame and footer.
9. Klar.Table: documented public boundary.

The exact assignments may be refined from the actual function dependency graph before
each move. Every new dependency must point down this order; record refinements here.
Pure logic modules do not import Html or a table view. Columns may reference Html in
their cell descriptions but must not import table rendering.

## Steps and verification

Capture the full check log, docs JSON, test-file inventory and count, and all showcase
table roots outside the repository before moving code. Commit the capture harness and
this plan. Then move one cohesive group per commit, starting with leaf logic, and run
format, the full check, byte comparison of docs JSON and DOM snapshots after each step.
Record commit hashes, validation and the next step in PROGRESS.md after every commit.

Do not change existing tests, elm.json, check scripts, CLAUDE.md, ROADMAP.md or .github.
Record any discovered bugs in FINDINGS.md without fixing them. Stop on the task's
specified conditions. Only begin Chart after Table meets every completion condition.
