# A0: use Klar before freezing it

Phase A0 of [ROADMAP.md](../ROADMAP.md). Three small but real applications are built with
Klar by an AI that has only the documentation. Every friction is written down in
[FRICTION.md](FRICTION.md) and decides what changes in A1 to A7, while a breaking change is
still free.

## Why these three

`example/` is the showcase and was written by the people who wrote Klar, so it proves little
about how Klar is to *use*. The three applications below differ in shape and together touch
the modules that the showcase only demonstrates once or twice (`Rule`, `RuleBuilder`,
`SavedViews`, `Calendar`, `Timeline`, `Tree`, `VirtualList`, `Field`, `Form`, `InlineEdit`,
`JsonViewer`, `MultiSelect`).

| App | Shape | What it stresses |
|---|---|---|
| **Fulfilment desk** (`apps/fulfilment`) | List and detail, a work queue | Table in server mode, filters and saved views, selection and bulk actions, drawer, shortcuts, command palette, toasts, failure and retry |
| **Stock overview** (`apps/stock`) | Dashboard and exploration | Tree of warehouses, charts and stats, periods, a very long list, timeline of movements, skeletons, empty and stale data |
| **Supplier onboarding** (`apps/onboarding`) | Form-heavy flow | Stepper, forms with validation, selects over the app's own id types, tags, file drop, pricing rules in the rule builder, dirty state, server errors on save, conflicts |

Each has its own `elm.json` (source directories `src` and `../../src`), its own dummy
backend written in Elm behind a `Remote`-returning layer, as in `example/`, and imports only
exposed `Klar.*` modules (`scripts/check-app.mjs` checks it). Domain-neutral names only.

## The tasks (acceptance, not instructions)

The builder is given the tasks as a user would state them. It decides which Klar modules to
use. Tasks must be doable with Klar alone.

### Fulfilment desk

1. An inbox of orders, 200 per page from the "server", sortable and filterable by status,
   customer, date range and total, with free text search.
2. Saved views ("My open orders", "Late", "High value") that can be created, renamed and
   shared by name; the current filter is visible as chips and editable.
3. Select several rows and act on them: mark as packed, assign to a person, export the
   selection as CSV. A bar says how many are selected.
4. Open an order in a drawer: lines, history as a timeline, notes. The status can change
   only along allowed steps, and the change asks for confirmation when it cannot be undone.
5. Every request can fail or be slow: the user sees loading, a clear failure with retry,
   an empty result, and never a blank screen.
6. Keyboard: move between rows, open with Enter, a command palette (`Ctrl+K`) with
   "go to order ...", "new saved view", and a help sheet for the shortcuts.
7. Toast on success and on a failed save; the failed save keeps what the user typed.

### Stock overview

1. A tree of regions, warehouses and zones; selecting a node filters everything on the page.
2. Four figures at the top (stock value, items below reorder level, open transfers,
   turnover) with trend against the previous period, for a period chosen with a date range.
3. Two charts: stock level over time for the selection, and movements by category.
4. A movements list with 50 000 rows that scrolls smoothly, with search and a type filter.
5. A timeline of the latest transfers, and the raw event of a selected movement shown as
   JSON.
6. Loading uses skeletons, a warehouse with no data says so, and old data is marked as
   old when the refresh fails.
7. Works at 1280 and 1920 pixels wide, with a compact density.

### Supplier onboarding

1. A five-step flow: company, contacts, delivery terms, pricing rules, review.
2. Selects and multi-selects over the application's own types (country, category, payment
   terms), a tag field for certifications, a file area for the contract.
3. Each step validates before the next and shows all problems at once; the review step
   lists every problem with a way to go to it.
4. Pricing rules are built with the rule builder ("if category is X and quantity above Y,
   discount Z") and shown in readable form.
5. Saving can fail with problems from the server tied to fields, and with a conflict
   because someone else changed the record; the user's input is never lost.
6. Leaving a half-filled flow asks for confirmation.
7. After saving, the same record can be opened for editing, with some fields editable
   in place.

## How an application is built

- **Who builds:** a fresh AI session per application, in its own folder, so nothing is
  shared and the three can run at the same time.
- **What it may read:** `README.md`, `USING.md`, `CONTRIBUTING.md`, and the doc comments of
  the exposed `Klar.*` modules (through `docs.json`). It may **not** read `example/` or
  anything under `src/Klar/Internal`. This is the point: Klar before the AI documentation of
  A1 exists, so missing documentation shows up as friction.
- **What it may do:** use only exposed modules; write its own helper code when Klar has no
  answer, and mark that code `-- KLAR GAP:` with a reason.
- **What it records, while it works:** every stuck moment in FRICTION.md (see below), in the
  moment, not afterwards.
- **Order:** the Fulfilment desk first, alone, to test the method and the log. When it is
  done the plan is adjusted, and Stock and Onboarding run in parallel.

## What is measured

Per application, in `apps/<app>/RESULT.md`:

| Measure | How |
|---|---|
| Compile errors before the first working build, by kind (wrong type, missing import, wrong argument order, misunderstood option) | Count from the session |
| Number of fix iterations per feature | Count |
| Lines of application code per task, and how many are `KLAR GAP` code | Count |
| Times an unexposed module or a Klar internal was needed | Count; each is a bug in the API |
| Hand-written focus, popup, date, scroll or layout code | List; each is something Klar should hide |
| `class`, `style` or inline CSS in the application | Count; should be 0 (principle 11) |
| Behaviour wrong after it compiled | Found by a person in the browser pane, one list per page |
| Accessibility | axe on every page, and one keyboard-only run through the main task |
| Time from start to the working application | Rough |

## The friction log

One row per problem in [FRICTION.md](FRICTION.md), written in the moment:

| Field | Meaning |
|---|---|
| id | `F-001`, running number |
| app | fulfilment, stock or onboarding |
| module | The Klar module involved |
| kind | `find` (could not find it), `understand` (docs unclear), `type` (the types got in the way), `missing` (Klar has no answer), `boilerplate` (too much code), `bug` (Klar is wrong), `doc-wrong` |
| what happened | One or two sentences, with the compile error if there was one |
| cost | Iterations or minutes lost |
| fix | What would have prevented it: a doc, a rename, a type, a new function, a new component |
| severity | `block` (stopped the work), `slow`, `annoy` |

After the three apps: group the rows by fix, count, and let the counts order the work in
A1 to A7. A problem seen in two applications is fixed first.

## The instructions to the building AI

```
You are building <app name> with the Elm package Klar, in the folder apps/<app>/.
Read README.md, USING.md and CONTRIBUTING.md at the repository root, and the doc
comments of the exposed Klar modules (docs.json). Do not read example/ and do not read
src/Klar/Internal. The tasks are in apps/PLAN.md under "<app name>".

Rules: import only exposed Klar.* modules. Write no CSS and no class names. Use no
ports, no JavaScript, no third-party packages. When Klar has no answer, write the
smallest helper you can and mark it "-- KLAR GAP: <reason>".

While you work, append to apps/FRICTION.md every time you were stuck, wasted an
iteration, wrote code you think Klar should have hidden, or found a bug. Write it when it
happens. At the end write apps/<app>/RESULT.md with the measures from apps/PLAN.md. Build
with `elm make --optimize` and check the imports with
`cd apps/<app> && node ../../scripts/check-app.mjs ../.. src` (the lock in the app folder
freezes Klar for the run; it is not to be edited).
```

## Order of work

1. Scaffold `apps/fulfilment` (elm.json, index.html, dummy backend, build script), no UI.
2. Run the building AI on the Fulfilment desk. Review the result in the browser together.
3. Adjust this plan and the instructions from what the first run taught.
4. Run Stock and Onboarding in parallel.
5. Group the friction, write the A1 to A7 work list, and update the roadmap.

## Open choices

- Whether one of the three should be replaced by (or checked against) one of the owner's
  real applications, kept outside this repository. A real application finds problems that a
  made-up one cannot.
- Whether a fourth, small application (an admin console with users, roles and an audit log)
  is worth adding for the permission and audit parts of Phase D.
