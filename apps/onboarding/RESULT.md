# Result: Supplier onboarding (A0)

Built with Klar only, from README, USING, CONTRIBUTING and the module docs (`docs.json`
turned into one text file per module). `example/`, `src/Klar/Internal*`, `apps/fulfilment`
and `apps/stock` were not read. `node scripts/build-app.mjs onboarding --optimize` builds;
`node ../../scripts/check-app.mjs ../.. src` prints `app: ok`. The friction is in
[FRICTION.md](FRICTION.md) (O-001 to O-022).

## The seven tasks

| # | Task | State | Notes |
|---|---|---|---|
| 1 | Five-step flow | works | Stepper, one `Form.view` per step, Back/Next, Enter submits, focus goes to the first field of the new step |
| 2 | Selects over own id types, tags, file | works | `Select`/`MultiSelect` over `CountryId`, `CategoryId`, `PaymentTermsId`; `TagInput` for certifications; `FileDrop` for the contract (only by a synthesized drop event in the test: the file dialog cannot be driven from the pane) |
| 3 | Validation before Next, all problems at once, review lists them | works | Error summary + per-field errors; summary links on the review step jump to the step and focus the field (checked: server error on a contact email on step 2 opened from the review) |
| 4 | Pricing rules in the rule builder, readable form | works, with workarounds | `RuleBuilder` in a `Modal`; the rule is shown with `Rule.describe`; category ids written as string keys (O-002) |
| 5 | Server problems tied to fields, conflict, input never lost | works | 4 server problems at once (registration, contact email, lead time, discount), cleared per field on edit; network error with retry; a version conflict dialog (keep editing / load theirs, with a confirmation naming the sections / save mine over theirs); inline edits conflict too |
| 6 | Leave confirmation | works for in-app links, Cancel and the back button | Closing or reloading the tab is not guarded (needs JavaScript, O-017) |
| 7 | Edit after save, some fields in place | works | Detail page: name, website, lead time, notes with `InlineEdit` (validation, saving, failure); "Edit full record" reopens the five steps |

## Measures

| Measure | Result |
|---|---|
| Compile errors before the first working build, by kind | **2**: 1 missing package (`elm/url` for `Browser.application`, O-008), 1 missing import (my slip). 0 wrong type, 0 wrong argument order, 0 misunderstood option. Caveat: I turned `docs.json` into a signature index first and read every type before writing, which is where the doc errors O-006 and O-007 were caught instead of compiled. The 1950-line `Flow.elm` compiled at the first attempt |
| Fix iterations per task (rebuilds after seeing it in the browser) | T1 0, T2 0, T3 0, T4 0, T5 1 (stacked inline text, O-020), T6 0, T7 2 (all steps open when editing; wrong side-nav highlight) + 2 cosmetic (a label, heading level) |
| Lines of application code per task (non-blank, rough, from `Flow.elm` sections, `Main.elm`, `Detail.elm`) | T1 ~330 (model, init, update of steps, frame, actions); T2 ~150 (company + delivery views); T3 ~410 (problems 276, review 132); T4 ~210 (step 47, editor modal ~110, `RuleFields` 30, keys); T5 ~330 (server problems, send/arrive, conflict dialog, `Api`, `Backend` 288 is the dummy server and not counted as application code); T6 ~45 (`Main` guard + confirm dialog); T7 ~290 (`Detail`). Total application code ~3100 of 3780 lines incl. the dummy backend (`Backend`, `Api`, 330) and ids (120) |
| `KLAR GAP` code | 8 marked sites (~270 lines): `requiredValue`/`nonEmptyList` (O-001), rule keys in `Domain` and `RuleFields` (O-002), `Draft`/`toDraft`/`load` (O-018), server-problem merge and `edited` (O-019), route guard in `Main` (O-017). About 9% of the application code |
| Unexposed module or Klar internal needed | **0**. (`check-app.mjs` passes) |
| Hand-written focus, popup, date, scroll or layout code | **0** popup/date/scroll/layout code. Focus: `Form.focusField` / `Form.focusSummary` / `Form.focusStatus` only (Klar's own); after a step change `Form.focusField` worked in the same update, no delay needed. Hand-written *flow* code instead: step guard, problem-to-step map, leave guard, dirty detection (listed above) |
| `class`, `style` or inline CSS in the application | **0** (`grep` for `class`, `style`, `Html.Attributes` finds nothing; no CSS file) |
| Behaviour wrong after it compiled | See below |
| Accessibility | axe-core 4.10.2 (wcag2a, 2aa, 21aa, 22aa, best-practice) on the list, all five steps (step 1 also with errors showing), the rule modal and the detail page: **no violation on the rule modal; `heading-order` (moderate) on every page with a Form section or a Card (O-015); `target-size` (serious) on the error summary links (O-016)**. Not run on the conflict dialog and the inline-edit failure state. Keyboard: Tab and Enter through the first three steps worked (text, selects by typing and Enter, Escape closing lists, Enter submitting the step, the summary links focusing fields, focus returning to the select trigger). Not completed keyboard-only: file choice (needs the OS dialog) and the rule builder (done with the mouse). The pane could not be trusted for fast key sequences (it was hidden between my calls, so rendering and my readings lagged), so some of it was checked with single presses and reading `document.activeElement` |
| Time from start to the working application | Rough: ~1.5 h reading docs, ~1.5 h writing, ~1 h in the browser. Writing the five steps was fast; the time went to the parts Klar does not cover: server-tied problems, dirty/baseline, the route guard, conflict handling |

### Behaviour wrong after it compiled (one list per page)

**New / edit flow**
- Conflict dialog listed the differing sections without line breaks (`Text.text` is inline, O-020). Fixed.
- When editing an existing record only step 1 was open (the stepper disabled the others). Fixed (`furthest = lastStep` when a record is loaded).
- The side nav marked "New supplier" while editing. Fixed.
- Klar: the sticky danger toast covers the footer of the open rule dialog (O-011); the status message wraps the Back/Save buttons (O-012); the `Select` popup cuts descriptions (O-013).
- Not verified: pressing Tab immediately after Escape in the multi select left focus on the trigger (it may be a race with focus return, or an artefact of the test tool). Not logged as a bug.

**Detail page**
- A stray empty breadcrumbs element left a gap above the title. Fixed.
- Inline conflict shows "Try again" although retrying cannot help (O-014).
- A button label was cut ("Load version "). Fixed.

**List page**: no problem found (client-mode `Table`, search, row click open the detail not exercised by hand beyond rendering).

## What worked well (worth keeping)

- `Select`/`MultiSelect` over the application's own ids with `valueText` and `Select.remote`: the failure of reference data ("Could not be loaded", retry in the list, the saved value kept) is better than I would have built.
- `Form.errorSummary` + `onFocusField` + `Form.focusField`; `Form.status` with `Failed`/retry; `Form.unsavedFlag`.
- `ConfirmDialog` for the leave question and the "load their version" question.
- `InlineEdit` saving/failed cycle and `RuleBuilder` + `Rule.describe` gave the rule UI with about 110 lines.
- Zero CSS, zero class names, zero popup or focus code; keyboard behaviour of the pickers was right in every case I could test.
