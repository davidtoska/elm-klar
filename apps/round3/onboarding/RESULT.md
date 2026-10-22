# Supplier onboarding, round 3 (experiment A0)

Built with Klar only, from the AI documentation (llms.txt, AI.md, ai/, recipes/, USING.md). Build:
`node scripts/build-app.mjs round3/onboarding --optimize`; `check-app.mjs` passes
(only exposed `Klar.*` modules, Klar unchanged). All seven tasks work. Friction: [FRICTION.md](FRICTION.md) (19 rows, R3O-001..019).

## The application

| File | What |
|---|---|
| `src/SupplierForm.elm` | the form declared once: 5 steps, contacts as rows, selects/multi-selects over `CountryId`/`CategoryId`/`PaymentTermsId`, tags, a file, rules |
| `src/PriceRules.elm` | price rules: one `RuleBuilder` + discount per rule, their problems for `Form.outside`, the sentence |
| `src/Main.elm` | routes, `AppShell`, list, flow, detail with `InlineEdit`, conflict handling, leave guard |
| `src/Backend.elm`, `src/Api.elm` | dummy backend (synchronous functions over a `Db`) and the layer that returns `Cmd`s with delay and failures |
| `src/Domain.elm` | the application's own types and `Ids` |

Server behaviour to try: org number `912345678` taken, website containing `blocked`, e-mail
`ingrid@aurora-fasteners.example` taken (a problem in a contact row), a discount above 40 (price rule),
legal name `Crash` (500, "Try again"), the switch "Simulate a server outage" on the list, and
"Simulate: someone else edits this supplier" on the detail and edit pages (version conflict).

## Measures

| Measure | Result |
|---|---|
| Compile errors before the first working build, by kind | **0** from Klar (wrong type 0, missing import 0, wrong argument order 0, misunderstood option 0): the first `elm make` of 2 500 lines succeeded. 3 further errors came from my own shell edits (a tab and a form feed made by `\t`/`\f` in `sed`/`node -e`), not from Klar. |
| Fix iterations per task (changes made after a browser run) | 1 five-step flow (R3O-004 `Validate.matches` is equality); 2 selects/tags/file: 0; 3 validation + review: 2 (focus target of the rule builder R3O-007, heading order on review); 4 price rules: 1 (same focus target); 5 server problems + conflict: 3 (focus after a failed save, focus after Retry R3O-009, `withTitle` R3O-008); 6 leave guard: 1 but expensive (R3O-011, ~25 min); 7 edit in place: 3 (focus after "Load their version", clipped "Open" button, h1 of the not-found page R3O-015). |
| Application lines per task (non-blank, rough; includes the dummy backend where marked) | 1 flow: ~380 (SupplierForm 126, flow update/view in Main ~250). 2 selects/tags/file: ~60 on top (Domain ids 92 incl. types). 3 validation/review: ~110 (review view 72, problem mapping 18, `syncFlow` 15). 4 price rules: ~350 (PriceRules.elm 336, pricing view 14). 5 server problems and conflict: ~210 in the UI (`savedReply` 63, conflict alert and diff 48, take-theirs 30, rest) plus the dummy backend 355 (Backend 289, Api 66). 6 leave guard: ~45. 7 edit in place: ~190. List, routing, shell: ~150. Total: Main 1 228, PriceRules 336, SupplierForm 126, Domain 92, Backend 289, Api 66 = 2 137 non-blank lines. |
| `KLAR GAP` lines | 1 marker, ~25 lines: `focusTarget`/`isGroupNode` in PriceRules.elm (R3O-007) |
| Unexposed module or Klar internal needed | 0 |
| Hand-written focus, popup, date, scroll or layout code | focus: 0 lines of `Browser.Dom`; 9 calls of `FormLayout.focusField` / `focusStatus` / `AppShell.focusContent` for things outside the form (new price rule, after removing the last one, conflict button, after Retry, after "Load their version") (R3O-006). Popup 0, date 0, scroll 0 (`AppShell.resetScroll`), layout 0 (`Layout`, `Card`, `FormLayout.grid`). |
| `class`, `style`, inline CSS | 0 |
| Behaviour wrong after it compiled (found in headless Chrome) | List: `Validate.matches` refused every input (my misreading); rule builder problem could not move the focus (container not focusable); "Leave" after browser Back asked again (guard re-armed by my `setDirty` after every message); retry button lost focus after "Try again" (form status, RemoteView); failed save left focus on a button that is gone; inline edit showed the title, not my message; focus lost after "Load their version"; the "Open" button of the table clipped at 1280 px (my label too long). Detail: not-found page without `h1`. Review: heading order. Nothing found open at the end. |
| Accessibility | axe-core 4.10.2, wcag2a, wcag2aa, wcag21aa, wcag22aa, best-practice, on: list, detail, flow steps 1 to 5 empty and with all problems showing, price rule builder open, select popup open, review, leave dialog, edit step 1 and review, conflict alert, confirm dialog, inline edit with an error, detail failed, detail not found, 375 px edit page: **0 violations** at the end (2 found and fixed: heading order on review, no h1 while the detail loads or fails). Keyboard-only run through step 1 (skip link, Tab to every field, Enter/arrows in the country and category selects, tag with Enter, Next with Enter) works and lands on the first field of step 2; the rest was driven with the same controls by mouse. The file input cannot be driven by CDP key events. |
| Rough time | about 35 minutes by the shell clock, of which reading ~8 minutes, writing the 2 100 lines ~10, browser verification and fixes ~15 (25 min of it for R3O-011). |

## The seam: what Klar.Form carried and what I still wrote

Klar.Form carried: state of every field (text, number, selects, multi-selects, tags, file), DOM ids
and labels, required marks, validation, the five steps and their order, "Next checks the step",
the stepper with red marks, the review summary with go-to buttons, the rows of the contacts with
stable numbers, add/remove buttons and the focus after them, dirty (`isDirty`), the server's problems
per field (`rejected`) and their removal when the field is edited, focus to the summary, to the first
field of the next step, to the first field of a new row. No state, message, DOM id or dirty test per
field in the application.

I still wrote for forms:

1. **The price rules, completely** (336 lines): list, add/remove, dirty flag, their own problems and
   server problems, attempted flag for the builder issues, focus. They enter the form only through
   `Form.outside` (works: the stepper mark, the summary, `toValues` all count them). `Spec.rows`
   cannot hold a rule builder (R3O-013).
2. `fill`: loading a record into the form (30 lines, `Form.set` per field, `fillRows`). `Check.roundTrip` is made for it; I did not write the test.
3. Mapping the server's problems to handles (18 lines) and the rows/price-rule special cases (R3O-018).
4. Wiring: `Next`/`Back`/`GoToStep`, `Submitting` status and `Failed`, `Retry` with `focusStatus`
   (R3O-009), `Saved` with the four outcomes, and the choice of what to do when the server refuses
   (`rejected`, or `goToProblem` when only a price rule is refused).
5. Choosing what to draw per step (`case Form.currentStep`), the review page content (72 lines), the
   conflict UI (alert, list of fields changed by the other user, overwrite, load theirs with a
   confirm) and the `LeaveGuard` wiring with the rule about when to call `setDirty` (R3O-011).
6. `syncFlow`: after every message recompute the outside problems and "attempted" for the rule builder.

What I would still want from the form model: stay on the review step after a refused save (R3O-005),
a key for rows so a custom control can follow its row (R3O-013), a helper for row problems from a
server (R3O-018).

## Reading log (documents in order)

1. `llms.txt`, 2. `AI.md` (full), 3. `PLAN.md` sections: tasks, what is measured, friction log,
4. `ai/klar-index.json` (head only; I searched the group list in AI.md and llms.txt instead of the
140 KB file), 5. `ai/modules/`: Form, Form.Spec, Rule, RuleBuilder, LeaveGuard, InlineEdit in full;
signature blocks of Form.Layout, Select, Select.Option, MultiSelect, TagInput, FileDrop, Remote,
Overlay, ConfirmDialog, Toast, Alert, DescriptionList, PageHeader, Badge, Button, Layout, Card, Text,
Stepper, NumberInput, Switch, Date, Validate, Locale, Table, AppShell, SideNav, Link, EmptyState,
ErrorState, RemoteView, Skeleton, Modal, Ids, Form.Check; the body of Form.Layout (one example). 6. `USING.md` (sections 3 and the start),
7. `recipes/multi-step/src/Main.elm`, `recipes/edit-form/src/Main.elm` read in full; `recipes/README.md`,
`template/README.md`; `template/src/Main.elm` not read (AI.md's standard application was enough).
Reading took about 8 minutes of wall clock. I did not read `confirm-delete` fully (only grep for
`ConfirmDialog`).

## What was easy

- The form: declaring 14 fields with the types of the application's own ids, rows, tags, a file, steps
  and rules in 70 lines, and getting a correct summary, stepper marks, focus and dirty state for free.
  The compiler errors table in Form.Spec.md was never needed because nothing went wrong.
- Server problems tied to fields (`Form.problem`, `rejected`): the field shows the message at once and
  clears it when edited; the summary lists it.
- `Form.advance` as the whole of Next/Save; `Form.goToProblem` for a problem that is not in the form.
- `LeaveGuard` once its one trap is known: the Back button, the sidebar link, Stay, Leave all work and
  the dialog returns focus to the right element.
- `RuleBuilder` + `Rule.choiceFieldOf` with the same `Ids` as the form's selects; `Rule.describe`
  gave the readable sentence for free.
- `InlineEdit` with the save/fail cycle and `Remote.conflict`.
- axe: 0 violations in every state after two small fixes.

## The five biggest frictions

1. R3O-011 `LeaveGuard.setDirty` after every message re-arms the guard after "Leave" (docs gap, ~25 min).
2. R3O-013 / R3O-003 a rule builder with an outcome per rule does not fit `Spec.rows`; the model, dirty,
   problems and server errors of the price rules are a second implementation next to the form.
3. R3O-007 no documented focus target for the rule builder (read the DOM ids in the browser; KLAR GAP).
4. R3O-005 a refused save moves the form off the review step, so the review list of all problems
   cannot show server problems.
5. R3O-016/R3O-009/R3O-006 focus: retry buttons in `RemoteView`/`ErrorState`/`FormLayout.status` lose
   focus, and there is no named generic "focus this id" (only `FormLayout.focusField`).

(R3O-017, `FileDrop` gives no `File`, is the one that stops a real upload.)

## What I would change first

1. LeaveGuard.md: "call `setDirty` after messages that change the form, never after every message"
   (and the same in the multi-step recipe), and a test in `scripts/test-leave-guard.mjs` for
   Back + Leave with a form that stays dirty.
2. A recipe "form with an outside list" (price rules): `Form.outside`, `RuleBuilder.focusId`, dirty,
   server problems; or `Spec.rows` with a custom control slot.
3. RemoteView/ErrorState/FormLayout.status: move focus to the region after a retry, like `Table`.
4. `FileDrop` hands over the `File` values (or documents how).
5. `Validate`: a pattern validator and one message type (R3O-004, R3O-010).
