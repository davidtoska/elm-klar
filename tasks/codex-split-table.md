# Task: split Klar.Table into internal modules, public API unchanged

You work alone for several hours in the repository `davidtoska/elm-klar` (an Elm 0.19 UI
package). Read `CLAUDE.md` first and follow it. Read `ROADMAP.md` (the "Before the first
release" table and "Phase C: the table family") for the reason behind this task.

## Goal

`src/Klar/Table.elm` is about 7 700 lines. Split it into unexposed modules under
`src/Klar/Table/` so that each module has one clear job and `Klar.Table` itself is a thin
module that exposes the same API. Later work (`Klar.Grid`, `Klar.TreeTable`,
`Klar.PivotTable`) will be built on the shared parts, so the split must make the shared core
(columns, `ColumnId`, row ids, sorting, filtering, selection, virtual rows, locale texts,
CSV) importable on its own without importing the table's view.

`src/Klar/Table/` already holds `Csv`, `Index`, `Sort` and `Texts`. Keep them, extend the
same idea. Follow "One implementation, several modules" in `CLAUDE.md`: aliases and
`name = Core.name` with the signature and the doc comment written out in the public module.

## This is a pure refactor

Nothing observable changes. That is the whole point and the whole safety net.

- No change to any exposed name, type, signature, doc comment text or default.
- No change to rendered markup, class names, ids, ARIA, key handling or CSS.
- No change to any file under `tests/`, except an import line if a test imports an
  internal module (there should be none). A test that needs editing means you changed
  behaviour: stop and undo.
- No new feature, no bug fix, no rename, no "while I am here". If you find a bug, write it
  to `tasks/table-split/FINDINGS.md` and leave it.
- No new dependency; `elm.json` is untouched.
- Do not touch `scripts/check-*`, `CLAUDE.md`, `ROADMAP.md` or `.github/`.

## How to prove it is unchanged (do this before the first edit)

1. Create the branch `codex/table-split` in a worktree of its own. Never work in the main
   checkout. Run `npm ci` there.
2. Run `npm run check` and confirm it is green before you change anything. Save the output
   of `elm make --docs=<scratch>/docs-before.json` (a scratch folder outside the repo) and the
   list of tests with their count.
3. Capture a baseline of the rendered markup of the Table in the showcase: build the
   example (`npm run build:example`), open each showcase page that shows a Table in headless
   Chrome (`--headless=new --dump-dom` with `--virtual-time-budget`; Elm draws in
   requestAnimationFrame, so give it time), and save the DOM of the `.klar-table` elements to
   a folder outside the repo. Write the small Node script that does this to
   `tasks/table-split/dom-snapshot.mjs` (no dependencies) so it can be rerun.
4. After every step below: `npm run format`, `npm run check`, then
   `elm make --docs=...docs-after.json` must be byte-identical to the baseline (compare with
   a script), and the DOM snapshot must be identical. If either differs, the step is wrong:
   fix or revert it. Do not continue on red.

## Method

Work in small steps, one commit each, each leaving everything green. A step moves one
cohesive group (for example: column definitions and ids; row identity and keys; sorting
state and its update; filter model and its update; selection; the virtual-rows window;
keyboard handling; header view; body and cell view; footer and pagination; toolbar and
column menu; export). Prefer moving code verbatim over rewriting it. Order the steps so that
the modules lower in the dependency order (pure logic) come first and the views last.

Rules for the new modules:

- Unexposed (not in `exposed-modules`). They may import each other only in one direction;
  draw the dependency order in `tasks/table-split/PLAN.md` before the first move and keep it
  acyclic.
- The pure logic (sorting, filtering, selection, windowing, key maps) must not import
  `Html`. A reader should see which parts can be tested without a view.
- Target size: no module over about 1 200 lines. If a group is bigger, split it by job,
  not by line count.
- Every new module has a short module comment saying what it is for. They are not exposed,
  so they are not subject to `check:docs`, but keep the style.
- `npm run check:api` must still pass: no public signature may name a type a user cannot
  name. Aliases in `Klar.Table` must be written so this holds.
- Do not add tests for the sake of it, but where a pure module became importable on its own
  and has no direct test, add a small test file for its main function. That is the only
  allowed change under `tests/`, and only as new files.

## Keeping state across a long run

Your context will be cut. Keep `tasks/table-split/PROGRESS.md` current after every commit:
the plan, which steps are done (with commit hashes), what the next step is, and any
decision and why. Start every session by reading it. Do not rely on memory.

## Stop conditions

Stop and write the reason at the top of `PROGRESS.md` if: a step cannot be made green in
three attempts; the docs JSON or the DOM snapshot differs and you cannot see why; you would
have to change a test or a doc comment; or `npm run check` fails for a reason that has
nothing to do with your change (report it, do not fix it).

## Done when

- `Klar.Table` is a thin module and no file in `src/Klar/Table/` is over about 1 200 lines.
- `npm run check` green; `docs-after.json` identical to `docs-before.json`; DOM snapshots
  identical; the test list the same plus any new files.
- `tasks/table-split/REPORT.md` says what moved where (a table: module, job, lines), the
  dependency order, what you left alone on purpose, and anything in `FINDINGS.md`.
- The branch is committed. Do not merge, push, tag or publish.
- Then, as a second task and only if all of the above is done: the same for
  `src/Klar/Chart.elm` (about 3 500 lines), with its own `tasks/chart-split/` folder.
