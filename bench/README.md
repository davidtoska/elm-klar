# The Klar benchmark

Roadmap item A3. Can an AI that has only the documentation build the usual screens of a
data-dense application with Klar, correctly, without inventing workarounds? The benchmark answers
with twelve fixed tasks and two numbers per release, and it may not get worse.

| File | What it is |
|---|---|
| [tasks.md](tasks.md) | The twelve tasks, each with acceptance criteria and, for the scorer, its reference modules |
| [run.md](run.md) | How a fresh session is briefed, what is recorded, how the score is made, the rule that it may not drop |
| [results/baseline.md](results/baseline.md) | The reference: the numbers of A0 round 1 and round 2 (different tasks, so a guide, not a comparison) |
| [results/run-1.md](results/run-1.md) | Run 1, the real baseline for the twelve tasks; the builder's log and library requests are in `results/run-1/` |
| `results/<release>.md` | One file per later run |
| [../scripts/bench-workspace.mjs](../scripts/bench-workspace.mjs) | Builds the folder the builder gets: the documentation and nothing else |

## What the builder gets

`AI.md`, `llms.txt`, `ai/` (the index and one text file per module), `USING.md`, `recipes/` and
`template/`, plus `src/` because the compiler must read it. Not `apps/`, `example/`, `design/`,
the roadmap, the changelog or any friction log. If the benchmark needs a file that is not in this
list to succeed, the documentation has a hole, and that is the finding.

## Status

Run 1 is done (2026-10-22, [results/run-1.md](results/run-1.md)): seven of twelve tasks pass every
acceptance line, and it is the baseline the next runs may not fall below. The fixes it led to are
on `main` (merge `fix-bench-1`).

## Commands

```bash
node scripts/bench-workspace.mjs <new empty directory> [T01 T02 ...]   # the builder's folder
npm run check                                                           # first: docs current, recipes compile
```
