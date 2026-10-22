# Supplier onboarding, round 2: result

Built from `README.md`, `USING.md`, `CONTRIBUTING.md` and the doc comments (`docs.json`) only.
Build: `node scripts/build-app.mjs round2/onboarding --optimize` (passes). `check-app.mjs` passes.
Run: static server on `apps/round2/onboarding`, `#/suppliers`. All seven tasks work.

## Tasks

| # | Task | State |
|---|---|---|
| 1 | Five-step flow (company, contacts, delivery terms, pricing rules, review) | works |
| 2 | Own-type selects/multi-selects, certification tags, contract file | works (ids as own types; rule builder gets text keys, see R2O-011) |
| 3 | Each step validates before the next, all problems at once; review lists every problem with "Go to field" | works; review list needed a hand-kept copy of server problems (R2O-007) |
| 4 | Pricing rules with the rule builder, shown in readable form | works (builder + `Rule.describe` sentence per rule, also on review and detail) |
| 5 | Save can fail with field problems from the server and with a version conflict; input never lost | works: 7 server problems at once, offline failure with retry, conflict with `Compare` and three choices |
| 6 | Leaving a half-filled flow asks for confirmation | works for links, programmatic navigation and the Back button (after fixing R2O-010) |
| 7 | Saved record opened for editing; some fields editable in place | works: detail page with `InlineEdit` (name, website) and `Switch` (preferred), each saved separately with its own failure/retry/conflict; "Edit all details" reuses the flow |

## Measures

| Measure | Result |
|---|---|
| Compile errors before first working build, by kind | **1 in total.** 0 wrong type, 0 missing import, 0 wrong argument order, 0 misunderstood option. The one error was mine, not Klar's: a recursive `type alias` (`ServerIssue` held a function over `Model`, `Model` held `ServerIssue`); fixed with a `Probe` union. (A second failed build came from my own shell escaping eating a backslash, not from Klar.) The very first build of ~3,000 lines compiled. |
| Fix iterations per task | T1 flow: 3 (empty-text validator, focus when only non-form problems exist, focus on Review). T2 selects/tags/file: 1 (seed data had no contract, so editing a seeded record was blocked). T3 validation/review: 3 (R2O-005, R2O-007, stepper marks). T4 rule builder: 1. T5 server/conflict: 3 (server issues not in `toValues`, Save allowed while issues stood, focus). T6 leave guard: 3 (focus after Stay, Back loop R2O-010, Back target). T7 in place: 1 (seed org number of 10 digits failed my own 9-digit rule). |
| Application lines per task (non-blank, non-comment) and KLAR GAP lines | Whole app 1,700 lines of UI code: `Flow` 1,645 incl. everything of tasks 1-6, `Detail` (task 7) 345, `Main` (shell, routes, guard, list, toasts) 494. Dummy backend: `Backend` 262, `Domain` 186, `Api` 26. Rough split of `Flow`: form declarations ~85, model/issues ~420, update ~460, step attempt/server problems ~300, views ~370 (company 61, contacts 42, delivery 19, pricing 65, review 96, conflict 53). **KLAR GAP lines: about 110**: the copy of server problems (79, R2O-007), the Back-button recipe and `restoring` (about 25, R2O-009/010), focus after guard (8, R2O-008), hand-written DOM ids for `focusField` (12 call sites, R2O-006). |
| Times an unexposed module or internal was needed | 0 (`check-app.mjs`: only exposed modules). |
| Hand-written focus, popup, date, scroll or layout code | Focus: 14 `Form.focusField` calls (after add/remove row, entering a step, going to an issue, after server rejection, after conflict, after Stay), each with a hand-typed DOM id. `Form.focusStatus` once. Popup: 0. Date: 0 (no date field in this app). Scroll: `AppShell.resetScroll` once (documented recipe). Layout: 0 (only `Layout`, `Form.grid`, `Card`). |
| `class`, `style`, inline CSS | **0** (no `Html.Attributes` import at all). |
| Behaviour wrong after it compiled (list per page) | **Flow:** (1) optional Website field showed an error when empty: `Fm.rules` doc says empty passes all validators but `Validate.custom` does not (R2O-004). (2) Stepper "failed" marks and review list missed server problems on form-model fields (R2O-007). (3) After Next to a clean Review, focus fell to BODY (my id did not exist). (4) Save was possible while a server problem still stood. **Leave guard:** (5) Back button froze the tab: infinite loop from `Nav.forward` calling `onUrlChange` with the old address (R2O-010, doc is wrong). (6) After Stay/Escape focus went to BODY because the asker was a `SideNav` link (R2O-008). **List:** none found. **Detail:** none found after the seed fix. |
| Accessibility | axe-core (wcag2a, wcag2aa, wcag21aa, wcag22aa, best-practice) on 21 states: list, every step empty and with errors, the open multi-select, a rule card, review, leave dialog, detail, inline edit open and failed, review in edit mode, conflict view, confirm dialog. First run: one best-practice finding, `heading-order` (card titles are `h3` under the page `h1`), on 6 states; fixed with `Card.headingLevel 2`. Now **0 violations on all states.** Keyboard: Tab order through the company step is logical (name, legal name, org number, website, country, payment terms, categories, switch, tags, file, Cancel, Next); typing plus Enter submits the step and puts focus on the error summary; add/remove row, step change, server rejection, conflict and guard all move focus to something sensible except R2O-008. The full main task was **not** done with the keyboard only (selects and the rule builder were driven with clicks through script); only Tab traversal, typing, Enter, Escape and the Back key were done with real key events. Screen reader: not tested. |
| Time from start to working application | About 1 h 10 min, of which about 25 min reading the docs, 25 min writing, 20 min browser verification. A further 35 min went on the test harness: the built-in browser pane is hidden here, so `requestAnimationFrame` never ran and Elm did not render; I drove headless Chrome over DevTools instead, and one script hung the page (that was R2O-010). |

## The seam: what the form model removed, and what it did not

**Removed (the form model did this and I wrote none of it):**
- one `State` and one `Msg` per form instead of one per field (company 8 fields, delivery 5, each contact 4);
- the DOM ids, label, hint, required mark, error wiring and `Field` wrapper of every control;
- "validate everything, show all at once, put focus on the summary" (`toValues`, `reveal`, `summary`) for form-model fields;
- typed ids in selects and multi-selects (`Fm.ids` once per type, `Fm.choice`/`choices`);
- dirty tracking per form (`isDirty`, `markClean`) and loading a saved record (`Fm.set`);
- server problems tied to a field (`problem`, `rejected`) shown at the field, in the summary, and cleared when the field is edited.
Roughly 30 hand-written `Msg` branches, `Validate.collect` lists and `Select.State`s I would have written in round 1 are not there.

**Still hand-written (not covered):**
- *Steps and the stepper:* current step, visited/tried, forward clicks that validate the steps on the way, "failed" marks, focus on the new step (R2O-016).
- *Repeating rows (contacts):* a form per row built by a function of the row key, one summary and one `reveal` per row, `allJust` over rows (R2O-003, R2O-013).
- *Tags, file:* `TagInput` and `FileDrop` used directly; required checks, server problems and their error text by hand; not in the summary (R2O-005, R2O-017).
- *Rule builder:* a `RuleBuilder` plus a discount `NumberInput` per rule, their validation, and the focus to a broken condition (R2O-011, R2O-012).
- *Seeing server problems again:* a second copy of the server problems with a value snapshot, because `toValues` does not return them (R2O-007, the biggest single piece).
- *Combined summary and review list:* my own `Issue` record; `Fm.Problem` has no label and there is no way to focus a field by handle (R2O-005, R2O-006).
- *Leave guard:* dirty bookkeeping across all forms and non-form parts (R2O-015), plus the Back-button dance (R2O-009, R2O-010) and focus after Stay (R2O-008).
- *Long note:* no `textArea` in the form model (R2O-014).

## Pretend network and test data

The list page has a "Pretend network" card: the next save fails with no contact, or someone else saves the record first (edits only). Try: organisation number `912345678`, a contact at `mailinator.com`, perishables with lead time over 14 days, a discount over 25%, the certification `XYZ`, a file name with "draft", a preferred supplier paid in advance.

## What was easy and good

- The first build of about 3,000 lines of Klar-heavy code compiled; there were zero API-misuse errors. The module docs with their examples were enough.
- `Fm.define ... |> Fm.with ...` read well; the "compiler refuses a field missing from `Fields` or `Values`" claim is real and I relied on it.
- `Fm.reveal` plus `Fm.summary` gave "all problems at once with focus on the summary" in one line per step. `Fm.rejected` with `Fm.problem` made server problems appear at the right fields in about 25 lines.
- `Fm.select`/`multiSelect` with `Remote` options: loading and failure of the lookups came for free, with the application's own id types.
- `InlineEdit` with `saved`/`failed` and `Remote.isRetryable` handled retry versus conflict correctly without code from me.
- `Compare` made the conflict view (mine against theirs, only differences) a 30-line component.
- `ConfirmDialog` plus `Overlay`/`AppShell.overlays`: no inert flags, no focus return code; the leave guard and the confirm dialog worked and passed axe at once.
- `Stepper`, `Card`, `DescriptionList`, `PageHeader`, `Form.section`/`grid`: a complete, calm layout with zero CSS.
- `RuleBuilder` with `bareField` and `withOperators`, plus `Rule.describe` for the readable sentence: task 4 took minutes.
- `Toast` after save and `AppShell.focusContent` after navigation were one line each.

## What I would change in Klar first

1. `Fm.toValues`/a new `Fm.problems` must return everything that is showing, server problems included (R2O-007); with it, the stepper marks and the review list need no second copy.
2. Bring the non-form parts into the model: `Fm.tags`, `Fm.files`, rows (`Fm.rows`), and a `Fm.focus`/`Fm.domId` (R2O-005, 006, 013, 017).
3. Fix the `LeaveGuard` Back-button docs, or give it a helper that handles `onUrlChange` (R2O-010, R2O-009), and let it remember the focused element (R2O-008).
4. A stepper/wizard state that owns "visited / failed / validate on the way" (R2O-016).
5. Correct the `Fm.rules` sentence about empty text and `Validate.custom` (R2O-004).
