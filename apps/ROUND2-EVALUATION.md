# A0 round 2: evaluation

The same three applications, rebuilt from the documentation alone on the corrected Klar
(after A8: the sure fixes, the overlay layer, the performance work, and the first version of
the form model). Results: `apps/round2/*/RESULT.md` and `FRICTION.md`; round 1 is
[EVALUATION.md](EVALUATION.md).

## Round 1 against round 2

| | Round 1 (F / S / O) | Round 2 (F / S / O) |
|---|---|---|
| All 7 tasks working | yes / yes / yes | yes / yes / yes |
| Friction rows | 20 / 23 / 22 = 65 | 14 / 11 / 19 = 44 |
| Compile errors caused by Klar's API | 9 sites / 8 sites / 2 | 0 / 0 / 0 (one scaffold dependency) |
| `KLAR GAP` code (lines) | 190 (+200 boilerplate) / 150 / 270 | 110 / 147 / 110 |
| Unexposed module needed | 0 / 0 / 0 | 0 / 0 / 0 |
| `class` / `style` / CSS | 0 / 0 / 0 | 0 / 0 / 0 |
| Behaviour wrong after it compiled | 6 / 10 / 8 | 3 / 6 / 6 |
| axe violations left | 3 / 0 / 2 rules | 0 on 17 states / 0 (one best-practice `region`) / 0 on 21 states |
| 50 000 rows: search key, sort, page | about 1 000 ms each | 30 to 47, 40 to 60, 42 to 51 ms |
| Hand-written focus code | 6 places (`refocus`, opener) | 1 (`/` shortcut) / 0 / 14 `focusField` calls with typed-in ids |

Caveats: the same model builds and judges; times are rough and not comparable (round 2 spent
15 to 45 minutes on reading the documentation, see below); only Chromium; the browser pane was
hidden, so some checks used headless Chrome.

## What improved, and what it proves

- **The overlay layer works.** Focus after actions, the opener, a toast with an action over a
  drawer, `modalOpen`, landmarks: none of round 1's overlay problems came back. Fulfilment
  needed one `Browser.Dom.focus` call.
- **50 000 rows are a normal case** (targets met, in an application, not only in a test).
- **The glue fell** by 40 to 60 % in two of three applications, and no builder made a type
  mistake. The form model removed roughly 30 `Msg` branches, per-field states and ids in
  Onboarding.
- **The documentation examples compile**, and the rename of `Remote` removed the `Success`
  clash.

## What did not improve, or is new

1. **The builders cannot read the documentation.** Two of three wrote a script to turn
   `docs.json` into text (R2F-001, R2S-001), 15 to 45 minutes each. This is exactly A1 (a
   readable `AI.md`, per-module text, `klar-index.json`), and it is now the largest single
   cost of using Klar.
2. **Stale data has no home** (R2S-002, R2F-011): 147 lines in Stock, the same gap as in
   round 1. It was on the A8 list ("`Remote`-aware containers and a stale state") and has not
   been built.
3. **The form model works but ends at a seam.** What it covers is good; what it does not
   cover costs the most. In priority order: server problems are invisible to the application
   after `rejected` (R2O-007, the largest single piece, 79 lines); the summary and the review
   list cannot include fields outside the model (R2O-005); no way to focus a field by handle
   (R2O-006, 14 call sites with hand-typed ids); no wizard state (R2O-016, about 90 lines);
   repeating rows (R2O-003, R2O-013); tags, files, `textArea` (R2O-014, R2O-017); `Fm.ids` and
   the rule builder need the same key function twice (R2O-001, R2O-011).
4. **`LeaveGuard` has a wrong recipe** (R2O-010): the Back-button recipe in its docs loops
   forever and froze the tab. Also: focus after Stay only works if the asker has an id
   (R2O-008).
5. **`SavedViews` stops short** (R2F-002 to R2F-004): it cannot open its own save form from a
   command, it has no sharing, and it saves only the rule, not the search and sort.
6. **Silent traps remain.** `Chart.loading` after `Chart.remote` silently cancels `remote`
   (R2S-005; `Stat` has the same pair); `Fm.rules` docs say empty text passes every validator
   but `Validate.custom` sees it (R2O-004); `Format.currency` prints `USD645.15` (R2F-006).
7. **Defaults that axe flags on every page:** `Card` is an `h3` under an `h1` (R2S-006, seen
   again by Onboarding); the sidebar content is outside any landmark (R2S-007).
8. **Small things that repeat in every application:** about 45 lines of `AppShell` wiring
   (R2S-010); a filter tree cannot be cleared by clicking (R2S-008); no fixed-width column in
   `Layout` (R2S-003); a table with 11 columns does not fit at 1280 (R2S-009); a CSV export
   in server mode silently drops selected rows on other pages (R2F-008); toasts cover the
   drawer title (R2F-013); focus falls to `body` when the palette opened a drawer from
   nothing (R2F-014); `FilterBar` Enter does not apply in a date field (R2F-012).
9. **The scaffold listed `elm/url` as indirect** and cost an iteration (R2S-004).

## Verdict

Klar got clearly better where it was fixed, and the numbers show it. Using it is now a
question of finding things and of the seams, not of fighting it: no type errors, no CSS, no
internals, 0 axe violations on 38 states. The two items that decide the next step are the
documentation (A1) and the stale/refresh state.

## What to do next, in this order

1. **A1, the AI documentation**, now: a readable text per module (or `llms.txt`), `AI.md`
   (the mental model and the twenty recipes), `klar-index.json`, generated by script and
   checked in `npm run check`. It would have saved 15 to 45 minutes in two runs out of three,
   and it makes round 3 a test of the documentation and not of reading `docs.json`.
2. **Stale and refreshing data** as a `Remote` capability, used by `Stat`, `Chart`,
   `Timeline`, `Tree`, `Table` and the containers (R2S-002, R2F-011, F-012).
3. **Finish the form model's seam**: `Fm.problems` (everything showing, server problems
   included), `Fm.focus`, a `Fm.summary` that takes extra problems, `textArea`, tags, files,
   a wizard state, rows. Decide the module rename and split at the same time.
4. **Repair `LeaveGuard`** (R2O-010 first, then R2O-008, R2O-009).
5. **One batch of small fixes**: `SavedViews` (open the form, sharing, the whole query),
   `Chart`/`Stat` loading trap, `Format.currency`, `Card` default level, sidebar landmark,
   `Tree` deselect, `AppShell` wiring, `Layout` width, the `Fm.rules` doc, the scaffold.
6. **Round 3** after 1 to 5, one application (Onboarding: it has the most seams), and the
   benchmark of A3 with a fresh builder that gets `AI.md` and the index.
