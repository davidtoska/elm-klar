# Task: design `Klar.Grid` (no production code)

You work alone for a few hours in the repository `davidtoska/elm-klar`. Read `CLAUDE.md`,
then `ROADMAP.md` (the admission test, "Phase C: the table family"), then `AI.md`. Read
`src/Klar/Table.elm`'s module doc and `src/Klar/Table/*.elm`, `src/Klar/Form/` (the form
model), `src/Klar/History.elm` (undo and redo), `src/Klar/Rule.elm`, `src/Klar/Money*.elm`
and `src/Klar/NumberInput.elm` for what already exists.

## Goal

Write a design document, `docs-design/GRID.md`, for `Klar.Grid`: editing like a
spreadsheet. A person reviews it before any code is written. The roadmap row says: "cell
editing with validation, range selection, fill, paste from Excel, undo, pinned and resizable
columns". It is an XL item and must be cut into slices of about one day each that can be
built, tested and merged one at a time.

## What the document must contain

1. **The user's job.** Three or four concrete scenarios in a business application (edit a
   price list; fix 200 imported rows; enter an order's lines), and what the keyboard does in
   each. What is deliberately not supported, and why (no formulas, no cell merge, and so on).
2. **The API, as Elm code.** The exact exposed types and function signatures, written as it
   would appear in the module, with the stateful-component shape of `CLAUDE.md` (opaque
   `State` and `Msg`, `init`, `update`, `view`, accessors). One complete example program
   fragment an AI could copy. Count the exposed names; justify each; remove what can be
   removed. Check each point of the admission test in `ROADMAP.md` and answer it.
3. **Types that make misuse impossible.** Typed columns (text, number, money, date, select,
   toggle) where the cell editor and the parser follow from the column type, the
   application's own row and column id types, and what a state that makes no sense would be
   and how the types rule it out. Rule 7: never change what the user typed; a cell that does
   not parse keeps the raw text and shows a problem.
4. **State and ownership.** Who owns the rows (the application), what the grid owns (cursor,
   selection range, draft text, undo stack), and the exact change the grid reports back and
   how the application applies, rejects or defers it (a server can refuse an edit: what does
   the cell show, and where does focus go?). The `Remote` states for server-backed rows.
5. **Keyboard map and ARIA.** A table of every key (arrows, Tab, Enter, Esc, F2, Ctrl+C/V/X/Z/Y,
   Shift+arrows, Home/End, PageUp/PageDown, Delete) and its action in each mode (navigating,
   editing). The ARIA grid pattern, concretely: roles, `aria-rowindex`, `aria-colindex`,
   `aria-selected`, `aria-readonly`, `aria-invalid`, live announcements. Say where focus
   lives (one tab stop, roving) and how it survives a re-render, a sort and a refresh.
6. **Large data.** How it works with 100 000 rows (reuse the virtual window of `Klar.Table`;
   say what is shared and what must be extracted first, which depends on the split of
   `Table.elm` done in `tasks/codex-split-table.md`).
7. **Paste and fill.** What the browser lets pure Elm do (no clipboard API without
   JavaScript: say honestly what is possible with a paste event decoder and what is not),
   the exact text format accepted (tab and newline separated, quoted cells), how a failed
   paste is reported cell by cell, and how fill-down is shown before it is applied.
8. **Locale.** Every piece of built-in text in English and Norwegian Bokmål, listed.
9. **Slices.** An ordered list of 8 to 15 slices, each with: what it adds, files, the tests
   (pure logic first), the browser checks, size, and what the showcase page shows at that
   point. Slice 1 must be useful alone (a read-only grid with the cursor and the keyboard
   map, no editing).
10. **Risks and open questions.** What you are unsure of, and the cheapest experiment that
    would settle each. Do not hide uncertainty.

## Method

- Prototype only to answer a question, in a scratch folder outside `src/`: for example a
  small Elm program that proves a paste decoder reads `clipboardData` from a `paste` event, or
  that focus survives a keyed re-render of a grid. Put what you learn in the document;
  delete the prototype. Nothing under `src/`, `tests/` or `example/` changes.
- Compare against the best grids you know (AG Grid, Glide Data Grid, Excel, Google Sheets,
  the ARIA Authoring Practices grid pattern) and say what you take and what you leave. Keep
  this to what changes a decision.
- Write for a reader who will approve or reject it in 20 minutes: the API section and the
  slice list first, the rest after. Under 600 lines.

## Keeping state across a long run

Keep `docs-design/GRID-PROGRESS.md` current: what is decided, what is open, what you tried.
Start every session by reading it.

## Done when

`docs-design/GRID.md` has all ten sections, the example program fragment type-checks (check
it by compiling a scratch module against stubs, outside the repo), and the document ends with
"Decisions I need from the owner" as a short numbered list of real questions. Commit on the
branch `codex/grid-design` in its own worktree. Do not merge, push or publish.
