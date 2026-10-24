# A0: the applications built to find the friction

History, not guidance. These are the applications an AI built from Klar's documentation in the three
rounds of roadmap item A0 (round 1 here, then `round2/` and `round3/`), with what each builder wrote
down. Their findings drove the work on Klar that followed, and most of them are fixed.

**The sources do not build against today's `src/`.** Their `elm.json` reads the live `../src` (or
`../../src`), while the Klar they were written for is the one fingerprinted in their `klar.lock`;
many names they use are gone (`Klar.Form.Model`, `Table.zone`, `Remote.isSuccess` ...). Do not copy
code from here: start from `template/`, `recipes/` and `AI.md`. (`scripts/build-app.mjs`, which the `RESULT.md` files
name, is removed for that reason; the history has the version that built them.)

| File | What it is |
|---|---|
| [PLAN.md](PLAN.md) | How the rounds were run (its brief predates `AI.md`) |
| [FRICTION.md](FRICTION.md), `*/FRICTION.md` | One line per problem a builder met, with the module and the proposed fix |
| `*/RESULT.md` | What each application does and the numbers of its round |
| [EVALUATION.md](EVALUATION.md), [ROUND2-EVALUATION.md](ROUND2-EVALUATION.md), [ROUND3-EVALUATION.md](ROUND3-EVALUATION.md) | The evaluation of each round |

The benchmark that replaced these rounds is in [../bench/](../bench/README.md).
