# How a benchmark run is done

One run builds the twelve tasks of [tasks.md](tasks.md) with a **fresh AI session that has only
the documentation**, then scores the result. Each run fills in `results/<release>.md` (the first is
[results/run-1.md](results/run-1.md)) and is compared with [results/baseline.md](results/baseline.md).

## 1. Prepare the workspace

```bash
npm run check                                   # the documentation is current and every recipe compiles
node scripts/bench-workspace.mjs ../klar-bench-1.0.0        # a new, empty directory
```

The script writes two folders:

- `klar/`: `src/` (the compiler needs it), `elm.json`, `AI.md`, `llms.txt`, `ai/`, `USING.md`,
  `recipes/`, `template/` and `scripts/check-app.mjs`. **Not** `apps/`, `example/`, `design/`,
  `tests/`, `ROADMAP.md`, `CHANGELOG.md`, the friction logs or the doc example report.
- `app/`: `BRIEF.md` (the tasks without the scorer's reference modules), `CLAUDE.md` (the
  paragraph from `USING.md` section 4), `elm.json` (with `elm/url` as a **direct** dependency),
  `index.html` and `klar.lock`.

## 2. Brief the session

Start a new session (no memory, no earlier conversation, no access to the Klar repository, only
this directory) with exactly this message, and nothing else:

> Build the tasks in `app/BRIEF.md`, one folder per task (`t01`, `t02` ...). Klar is in `klar/`;
> start with `klar/AI.md`. Follow `app/CLAUDE.md`. Each task must compile with
> `elm make src/Main.elm --optimize` and work in a browser. Check every acceptance line in the
> browser and run axe-core on the states the task names. Keep a log in `app/LOG.md`: for every
> compile error its kind, for every fix what you did, for every `-- KLAR GAP:` what was missing,
> and the time you spent reading documentation, writing and testing.

Do not answer questions about Klar. If the builder asks, the answer is "the documentation says".
If it is blocked for more than 30 minutes on one task, mark the task failed and let it go on.

Run twelve tasks in one session, or four sessions of three tasks (T01 to T03, T04 to T06 ...) if
the context would not hold. Say which in the result. The model and its settings are the same in
every run that is compared.

## 3. What is recorded

Per task (one row in `results/<release>.md`):

| Column | How it is found |
|---|---|
| Passes | Every acceptance line true in the browser (scorer, not the builder). Lines that fail are listed |
| Compiles first time | The first `elm make` of the task, from `LOG.md` |
| Compile errors, by kind | **wrong type**, **missing import or dependency**, **wrong argument order**, **misunderstood option**, **the builder's own Elm**. Only the first four count against Klar |
| Iterations | Number of `elm make` runs until the task compiles and works |
| `KLAR GAP` lines | `grep -c "KLAR GAP"` in `app/tNN/src`, and the lines of code under each gap |
| Unexposed module | `node klar/scripts/check-app.mjs klar tNN/src` fails, or an import of `Klar.Internal` |
| Hand-written focus, popup, date code | See the grep list below |
| CSS, class, style | `grep -rnE "Html\.Attributes\.(class\|style)|\bclass \"|\bstyle \"|Html\.node \"style\"" tNN/src` |
| Behaviour bugs | Wrong behaviour found in the browser **after** the task compiled, each with a one-line cause (Klar, the builder, the documentation) |
| axe | axe-core 4.x, tags `wcag2a wcag2aa wcag21aa wcag22aa best-practice`, on the states the task names: number of violations |
| Reading, writing, testing time | From `LOG.md` |
| Application lines | Non-blank, non-comment lines in `tNN/src` after `elm-format` |

Per run: whether the session opened `klar/src` (it should not; count the reads from the
transcript), how many of the documentation files it read, total time, and a one-paragraph
verdict with the three costliest problems.

**Grep list for hand-written code that Klar should have hidden** (count the matches in `tNN/src`):

```
Browser.Dom.focus  Browser.Dom.blur  Browser.Dom.getElement  Browser.Dom.setViewport
Browser.Events.onClick  Browser.Events.onMouseDown  Browser.Events.onKeyDown  Browser.Events.onResize
Time.toYear  Time.toMonth  Time.toDay  Time.toWeekday  Time.posixToMillis (outside Date.fromPosix)
getBoundingClientRect  scrollIntoView  Html.Attributes.tabindex  Html.Attributes.attribute "aria-
Html.Events.on "keydown"  Html.Events.preventDefaultOn
```

A `Browser.Dom.focus` that is documented as the way to do it (for example a shortcut that
focuses the table search) is counted, but listed separately as "documented".

## 4. The score

Two numbers per release, both from the rows above:

1. **Tasks passed** out of twelve.
2. **Friction points**: the sum over all tasks of compile errors that count against Klar, plus
   `KLAR GAP` places, plus unexposed-module uses, plus hand-written focus / popup / date places
   (not documented), plus CSS / class / style uses, plus behaviour bugs whose cause is Klar or
   its documentation, plus axe violations.

**The rule:** tasks passed may not go down and friction points may not go up between releases. A
release that breaks the rule is not released until the cause is found: a regression in Klar, a
documentation page that is wrong, or a noisy run (repeat the run once; a different result in two
runs is noise and is recorded as a range).

## 5. After the run

1. Save the filled table as `results/<release>.md`, with `LOG.md` of the run next to it.
2. Compare with the previous result and with the baseline; write the verdict at the top.
3. Every `KLAR GAP` and every friction that is a defect of Klar or of its documentation becomes
   a row in the friction log of the next planning round (same columns as `apps/FRICTION.md`).
4. Do not change `tasks.md` between releases that are compared. A change is a new benchmark
   version, with a new baseline.
