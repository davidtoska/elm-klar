# Benchmark run 1 (2026-10-22), `main` at 82c6782

The first run of the twelve tasks, and so the real baseline for them (see
[baseline.md](baseline.md): the A0 numbers are not comparable task by task). The builder's own
`LOG.md` and `LIBRARY-REQUESTS.md` are in [run-1/](run-1).

**Verdict.** Nothing to compare against yet; this run defines the baseline. Seven of twelve
tasks pass every acceptance line; the five that do not each miss one or two lines, and four of
those five are defects in Klar or its documentation, not in the builder. No compile error came from
Klar, no CSS, no internal module, no hand-written focus code.

## How the run was done and scored

- Workspace by `scripts/bench-workspace.mjs`; one fresh session (with one neutral sentence of
  background: "work only from the files in this directory"), all twelve tasks in one session,
  using sub-agents. The builder and the scorer are the same model.
- **Verified by the scorer** (re-run on the delivered folders): the build of every task
  (`elm make --optimize`), `check-app.mjs`, the count of `KLAR GAP` markers, the grep for CSS /
  class / style and for hand-written focus, popup and date code, and the application lines.
- **Taken from the builder's log, not re-checked in a browser by the scorer**: every acceptance
  line, axe results, behaviour bugs, compile-error kinds and times. This is the weak point of the
  run; a second pair of eyes (a person, or a second session that only checks the acceptance
  lines) should confirm the seven passes.
- Per-task times in `LOG.md` add up to about 118 minutes (reading 8, writing 29, testing 81)
  while the wall clock of the whole session was 47 minutes (17:06 to 17:53); the builder says
  the clock undercounts, but the gap is more likely sub-agents working in parallel. Treat the
  times as rough.

## Per task

| Task | Passes | Compiles | `KLAR GAP` | CSS / focus-DOM | Lines | Failing line or open point |
|---|---|---|---|---|---|---|
| T01 Order list with filters | no | yes | 1 | 0 / 0 | 337 | footer says "1–25 of 200", the brief "1 to 25 of N" (no way to word it in `Table`/`ServerList`) |
| T02 Edit form with server errors | yes | yes | 0 | 0 / 0 | 299 | |
| T03 Dashboard | yes | yes | 0 | 0 / 0 | 488 | |
| T04 Rule builder | yes | yes | 0 | 0 / 0 | 337 | |
| T05 Multi-step flow | yes | yes | 1 | 0 / 0 | 472 | steps: the application had to key the step body (`Html.Keyed`) or Elm reuses the focused input and shows "Required" on an untouched field |
| T06 Command palette | no | yes | 2 | 0 / 0 | 294 | axe `aria-required-children`: the remote section puts a `role=alert` inside the `listbox`; no way to declare the words that call an item |
| T07 Table with 50 000 rows | no | yes | 1 | 0 / 0 | 188 | line 1 for large filtered sets: 150 to 400 ms per keystroke or page change against the documented under 100 ms (not measured in a real Chrome) |
| T08 Drawer with confirm and toast | yes | yes | 0 | 0 / 0 | 401 | |
| T09 Saved views | yes | yes | 1 | 0 / 0 | 502 | no storage across a reload (by design); no encoder/decoder for `SavedView`/`Table.Query` (the builder kept views in the address) |
| T10 Timeline with load more | no | yes | 1 | 0 / 0 | 275 | line 2: at the end the "Load more" button is dimmed, not gone; day headings are `h3` and need an `h2` above |
| T11 Tree filter | no | yes | 1 | 0 / 0 | 365 | axe `target-size`: the "Try again" link of a failed branch is 19 px high; a lazy tree cannot search nodes it has not loaded |
| T12 Leave guard | yes | yes | 0 | 0 / 0 | 386 | |
| **Total** | **7 of 12** | **12 of 12** | **8** | **0 / 0** | **4 344** | |

## The two numbers of the benchmark

1. **Tasks passed: 7 of 12.**
2. **Friction points: 14** (counted by the rule in [../run.md](../run.md), section 4):
   compile errors against Klar 0, plus `KLAR GAP` places 8, plus unexposed modules 0, plus
   hand-written focus / popup / date places 0, plus CSS / class / style 0, plus behaviour bugs
   caused by Klar or its documentation not already counted as a gap 4 (T05 steps focus is a
   gap; T02 retry focus on `body` was the known gap and fixed by the builder with a documented
   call; T03 and T11 retry focus in `Stat`, `Chart`, `Timeline`, `Tree`; the `LeaveGuard.md`
   contradiction; the `AppShell` plus `LeaveGuard` `onUrlChange` question), plus axe violations
   still open 2 (T06, T11). The count is approximate in the "behaviour bugs" term, because the
   builder's list mixes defects and documentation points; the rest is exact.

## What was easy

- 11 compile errors in 12 tasks, every one the builder's own Elm (an `Int`/`Float`, a name clash,
  a missing import); none from a Klar module that behaved unexpectedly.
- Reading was short because each task has a recipe or a module page that fits it and `AI.md` points
  to it; the builder's reading time is about 8 minutes in all.
- Server lists, forms with server problems, dashboards with stale data, the rule builder, drawers
  with a confirmation and a toast, saved views and the leave guard (including the Back button)
  worked from the recipes.

## The costliest problems (for the next planning round)

1. **Real defects in components, found by axe or by the browser:** `CommandPalette.remote`
   (listbox with an alert inside it), `Tree` retry link target size, `Timeline`'s end-of-list
   button and heading level, retry focus in `Stat`/`Chart`/`Timeline`/`Tree` (only `RemoteView`
   and `ErrorState` are covered in `AI.md`).
2. **`Table` with a large filtered set** is slower than documented (T07): the footers sum the whole
   matching set on every message. Either cache it or correct the claim in `Table.md` and
   `AI.md`. (Round 3 measured 40 to 90 ms on 50 000 rows without a footer sum.)
3. **Documentation that the editing pass missed:** `LeaveGuard.md` still has two paragraphs "The
   browser's own buttons", and the second describes the `Nav.forward 1` recipe the first says
   loops forever; nothing says how `AppShell` and `LeaveGuard` share `onUrlChange`.
4. **Steps in forms (T05):** a step body drawn by the application needs a keyed element, or focus and
   "Required" go wrong. Klar should key it (the form knows the step).
5. **Small gaps:** footer wording in `Table`/`ServerList`; command words on a palette item; an
   encoder/decoder for `SavedView`/`Table.Query` (the library has no storage and must not have);
   `Tree` search on unloaded nodes.

Every `KLAR GAP` and defect above is also in [run-1/LIBRARY-REQUESTS.md](run-1/LIBRARY-REQUESTS.md)
(14 items) and goes into the friction log of the next round.

## Not checked

An independent browser pass over the acceptance lines; Firefox and Safari; a screen reader;
a second run to see the noise (run.md asks for one before a regression is declared).
