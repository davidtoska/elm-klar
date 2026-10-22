# A0 round 3: evaluation

The same three applications, built a third time, now by builders that were given only the AI
documentation (`llms.txt`, `AI.md`, `ai/klar-index.json`, `ai/modules/*.md`, `USING.md`,
`recipes/`, `template/`), on a Klar that has stale data, the finished form model, the repaired
`LeaveGuard` and the small fixes. Results: `apps/round3/*/RESULT.md`, `FRICTION.md`. Earlier:
[EVALUATION.md](EVALUATION.md) (round 1) and [ROUND2-EVALUATION.md](ROUND2-EVALUATION.md).

## The three rounds

| | Round 1 (F / S / O) | Round 2 (F / S / O) | Round 3 (F / S / O) |
|---|---|---|---|
| All 7 tasks working | yes | yes | yes |
| Friction rows | 20 / 23 / 22 | 14 / 11 / 19 | 14 / 14 / 19 |
| Compile errors caused by Klar's API | 9 sites / 8 / 2 | 0 / 0 / 0 | 0 / 0 / 0 (one shadowing copied from two docs) |
| `KLAR GAP` lines | 190+200 / 150 / 270 | 110 / 147 / 110 | 130 / **5** / **25** |
| Unexposed module needed | 0 | 0 | 0 |
| `class` / `style` / CSS | 0 | 0 | 0 |
| Hand-written focus code | 6 places | 1 / 0 / 14 | 0 / 0 / 9 (all outside the form model) |
| Functional bugs after it compiled | 6 / 10 / 8 | 3 / 6 / 6 | 4 / 0 / 8 (none in a Klar component except two focus cases) |
| axe violations left | 3 / 0 / 2 rules | 0 / 0 / 0 | 0 on 19, 8 and 20+ states |
| Time to a working application | 25 min / 2.5 h / 4 h | 2 h / 80 min / 70 min | **27 min / 25 min / n.r.** |
| Time spent reading the documentation | n.r. | 15 to 45 min, with own scripts | about 4 min |

(F = Fulfilment, S = Stock, O = Onboarding. `n.r.` = not reported in the same way.)
Caveats: the same model builds and judges; one run per application; only Chromium; the builders
wrote their own dummy backends, which are not counted as application code.

## What the three rounds show

- **The documentation for an AI works.** Reading fell from 15 to 45 minutes (with the builder's
  own conversion scripts) to about 4; two applications were done in about 25 minutes, in one the
  first build compiled with no error from Klar. Stock's builder wrote: the index, `AI.md` and
  `recipes/dashboard` "were enough for all seven tasks".
- **Stale data is solved** (Stock: 147 `KLAR GAP` lines to 5). **The form model closed the seam**
  (Onboarding: 270 to 110 to 25 lines; the 25 that remain are the focus of the rule builder).
  **Performance holds in a real application** (search key 40 to 90 ms, sort 4 to 10 ms in the
  optimized build; the docs promise "a few milliseconds" for a keystroke and that is not exact,
  R3S-002).
- **No builder needed CSS, an internal module or a type workaround in any of the nine builds.**

## What the third round found

**1. The documentation contradicts itself (the new, main cost).** The friction of round 3 is
mostly in the AI documents themselves:

| Problem | Rows |
|---|---|
| Two wirings of the application frame: `AI.md` and `template/` use `SideNav.init` and a hand-written `LinkClicked`; `USING.md` and the `AppShell` doc use `AppShell.init`/`AppShell.update` (a triple). Two builders chose differently and one copied both into one file | R3F-001, R3S-010 |
| The names in the docs' examples collide when combined (`changed` in `AppShell` and the inbox recipe: a shadowing error) | R3F-004 |
| `LeaveGuard.md` names things that are not in the API (`Modal.host`, `AppShell.modalOpen`, `SaveFirst`, `Form.focusField`) | R3O-002 |
| "Do not use when" lines that contradict the module (`ConfirmDialog`: "needs form fields: use Modal") | R3F-005 |
| `AI.md` rule 9 tells the builder to debounce a query that `Table` already debounces | R3F-006 |
| `Table.md` is 60 KB; the Quick path does not list what a server-mode inbox needs | R3F-003 |
| `AI.md` has a duplicated `## Common traps` heading (found by all three) | R3F-002, R3S-001, R3O-001 |
| The `LeaveGuard` quick path says "call `setDirty` after every message", which re-arms the guard after Back | R3O-011 |
| `AI.md` says nothing of where the discount of a price rule lives (the builder only expresses the condition) | R3O-003 |
| `Table.md` promises "a few milliseconds"; measured 40 to 90 ms for a search key | R3S-002 |

**2. Real Klar gaps that came back or are new:**

- **Server-mode glue** is still written by hand in Fulfilment (compare query and rule, reset the
  page, ticket, route a saved view's query back): R3F-008, 22 lines copied from the recipe.
  Named in A8; not built.
- **No application-wide density** (R3S-004; also S-022 in round 1). Each component has its own
  switch, `Chart`, `Card` and `Alert` none.
- **Time zone defaults to UTC per component**, so "Old data from 11:32" is two hours off in
  Norway unless each of `Stat`, `Chart`, `Table`, `Timeline` is given a zone (R3S-012).
  `Timeline` draws "00:00" for a day-only event (R3S-011); `Format` has no short date for chart
  labels (R3S-005).
- **`RemoteView`/`ErrorState`:** "Try again" drops focus to `body` (R3O-016, a bug), and a page
  that is only a `RemoteView` has no `h1` while loading or failed (R3O-015).
- **Form model:** `Form.rejected` jumps to the first step with a problem, so the review step that
  lists them cannot be reached (R3O-005); rows cannot hold a `RuleBuilder` (R3O-013); a problem in
  a row needs a `List.drop` (R3O-018); `Validate.matches` means equality, and the validators use
  `{ nb, en }` while `Spec` uses `Locale -> String` (R3O-004, R3O-010); `FileDrop` does not hand
  over the `File` values, so a real upload cannot be built (R3O-017).
- **Rule builder:** focus and the DOM ids of its controls are undocumented, so a form problem
  cannot be pointed at a condition (R3O-006, R3O-007; 25 lines of `KLAR GAP`).
- **Smaller:** a failed-save toast cannot be dismissed from `update` (R3F-013); CSV export of a
  selection across pages in server mode (R3F-007, needs `elm/file`); saved views cannot be
  "shared" without an application-side action (R3F-010); `Rule` values are written by hand as
  records (R3F-009); `Stat` has no `Money` (R3S-007); four `Stat` tiles repeat the same retry
  (R3S-006); the empty-warehouse table says "No matches" (R3S-008); `Card` and `Form.section`
  heading levels are still a trap (R3O-014); `InlineEdit` shows only a problem's title
  (R3O-008).

## Verdict

Using Klar is now fast and clean: 25 to 30 minutes for a seven-task application, no type
errors, no CSS, no internals, no axe violations. What is left is of two kinds, and neither is
large: **the AI documents need one editing pass** so that they agree with each other (one frame
wiring, true "do not use when" lines, no names that collide, a shorter `Table.md`), and **a
short list of real gaps** (server-mode helper, global density and time zone, `RemoteView`
focus, the review step after a rejection, the rule builder's focus).

## Next, in this order

1. **One editing pass over `AI.md`, `USING.md`, the module Quick paths and the recipes** so
   that there is one way to wire the frame, and every claim is checked against the code (the
   doc-example check should also run over `AI.md` and `USING.md`). Cheap; it fixes ten rows.
2. **A shared `Klar.Settings` or equivalent for density and time zone**, given once to
   `AppShell`, followed by all components (R3S-004, R3S-012, S-022).
3. **Server-mode helper** (R3F-008), finally; and the `RemoteView`/`ErrorState` focus and heading
   (R3O-015, R3O-016).
4. **Form model:** review reachable after a rejection, rows that can hold a rule builder, row
   problems by index, `FileDrop` handing over the `File` (this brings `elm/file` into the
   package, which the rules allow).
5. **Rule builder:** documented, focusable controls and an outcome per rule.
6. **The rest of the roadmap** (Phases B to H) can now start on a base that has been used three
   times. The benchmark of A3 is ready (`bench/`) for a fresh run once step 1 is done.
