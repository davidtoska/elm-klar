# Baseline: A0 round 1 and round 2

The numbers from building three applications from the documentation, twice. They are the
reference for the benchmark, with three caveats:

- A0 had 21 tasks in three applications (seven each, [apps/PLAN.md](../../apps/PLAN.md)); the
  benchmark has twelve different ones. The numbers say where the cost was, not what a first run
  has to reach. The first benchmark run is the real baseline for the twelve tasks.
- The builder and the judge were the same model, in an environment with some help from the plan.
  Round 2 spent 15 to 45 minutes turning `docs.json` into text (R2F-001, R2S-001), which the AI
  documentation now provides; round 3 and the benchmark remove that cost.
- Only Chromium; times are rough.

Sources: [apps/EVALUATION.md](../../apps/EVALUATION.md), [apps/ROUND2-EVALUATION.md](../../apps/ROUND2-EVALUATION.md),
`apps/round2/*/RESULT.md`, `apps/round2/*/FRICTION.md`.

## The score in the benchmark's terms

| | Round 1 (F / S / O) | Round 2 (F / S / O) |
|---|---|---|
| Tasks working at the end | 7 / 7 / 7 (21 of 21) | 7 / 7 / 7 (21 of 21) |
| Compile errors counted against Klar's API | 9 sites in 3 builds / 8 sites in 1 build / 2 | 0 / 0 / 0 (one scaffold dependency, `elm/url` indirect) |
| Other compile errors (builder's own Elm) | not counted | 0 (2 slips before the first build) / 5 / 1 |
| Wrong type or wrong argument order | 0 / 0 / 0 | 0 / 0 / 0 |
| `KLAR GAP` code (lines) | about 190 (+ 200 boilerplate) / 150 / 270 | about 110 / 147 / 110 |
| Unexposed module or internal needed | 0 / 0 / 0 | 0 / 0 / 0 |
| `class`, `style` or CSS | 0 / 0 / 0 | 0 / 0 / 0 |
| Hand-written focus code | 6 places in total (`refocus`, the opener) | 1 / 0 / 14 `focusField` calls with typed-in ids |
| Behaviour wrong after it compiled | 6 / 10 / 8 (24) | 3 / 6 / 6 (15) |
| axe violations left | 3 / 0 / 2 rules | 0 on 17 states / 0 (one best-practice `region`) / 0 on 21 states |
| 50 000 rows: search, sort, page | about 1 000 ms each | 30 to 47 ms, 40 to 60 ms, 42 to 51 ms (Stock) |
| Friction rows logged | 20 / 23 / 22 (65) | 14 / 11 / 19 (44) |
| Time to a working application | about 25 min / 2.5 h / 4 h | about 2 h / 80 min / 1 h 10 min (of which 25 to 45 min reading docs) |

## Friction rows by kind

Counted from the logs (`apps/FRICTION.md`, `apps/*/FRICTION.md`, `apps/round2/*/FRICTION.md`). The
benchmark's own friction score (see [../run.md](../run.md)) is made from a run's rows and not
from these, so only the first real run gives its baseline.

| Kind | Round 1 | Round 2 |
|---|---|---|
| `missing` (a gap, a `KLAR GAP`) | 20 | 19 |
| `boilerplate` (glue every application repeats) | 8 | 4 |
| `bug` (including `bug?`) | 12 | 2 |
| `doc-wrong` | 5 | 3 |
| `understand` | 10 | 13 |
| `find` (could not find it) | 4 | 2 |
| `type` | 4 | 1 |
| `annoy` | 2 | 0 |
| **Total** | **65** | **44** |

## The costs that decide the next steps

From [ROUND2-EVALUATION.md](../../apps/ROUND2-EVALUATION.md):

1. **Reading the documentation**: two of three builders wrote a script to read `docs.json`
   (15 to 45 minutes). The benchmark starts after this is fixed, with `AI.md` and `ai/`.
2. **Stale data has no home** (147 lines in Stock, R2S-002, R2F-011).
3. **The form model's seam**: server problems invisible after `rejected`, focus by handle, steps,
   rows (R2O-005 to 007, 013, 016).
4. **`LeaveGuard`**: a Back-button recipe that loops forever (R2O-010).
5. **Small repeats**: `SavedViews` (R2F-002 to 004), `Chart.loading` after `Chart.remote`
   (R2S-005), `Card` heading level, sidebar landmark, `AppShell` wiring (45 lines).

## Mapping of the old tasks to the new ones

| Benchmark task | A0 task it covers |
|---|---|
| T01 order list with filters | Fulfilment 1, 2, 5 |
| T02 edit form with server errors | Onboarding 5, 7 |
| T03 dashboard | Stock 2, 3, 6 |
| T04 rule builder | Onboarding 4 |
| T05 multi-step flow | Onboarding 1, 3 |
| T06 command palette | Fulfilment 6 |
| T07 table with 50 000 rows | Stock 4 |
| T08 drawer with confirm and toast | Fulfilment 4, 7 |
| T09 saved views | Fulfilment 2 |
| T10 timeline with load more | Stock 5 (new: load more) |
| T11 tree filter | Stock 1 |
| T12 leave guard | Onboarding 6 |

New in the benchmark, not covered by A0 at all: the "load more" of the timeline (T10), the
language switch of the dashboard (T03), the saved views surviving a reload (T09).
