# Roadmap

Where Klar goes next. One package, not published yet, built to be used by an AI.

Sizes: S = days, M = 1 to 2 weeks, L = several weeks, XL = a project of its own.

## Premises

- **One package.** `davidtoska/elm-klar`, no companion packages. Everything is in one place
  and versioned together.
- **Not published yet.** Until the first `elm publish` the API may still change freely.
  This is the cheapest time to get the shape right, so Phase A uses it. The freeze point is
  a checklist at the end of this file.
- **Maximal in components, minimal in dependencies and in API.** Many components, few
  packages, few functions per component, and the API as type safe as Elm allows.
- **An application is Klar plus its own code.** It imports Klar and its own modules, and
  nothing else: no CSS, no JavaScript, no assets.
- **Size and speed of the compiled program are not goals.** The applications are business
  applications; clarity and correctness come first. `elm make --optimize` removes code that
  is not used, so a large package does not make a small application large.
- **The main user is an AI.** An AI builds the application, a person reviews it. The
  documentation, the names and the types are made for that reader. See Phase A.
- **Built for people who work with data all day.** The look stays as it is today: calm,
  small-typed, exact.

## What Klar is for

Klar is for applications where people work with a lot of data all day and must be able to
trust what they see. Eleven principles, and what each one means for a component:

1. **Clear.** The user never wonders what state the data is in. A component that shows
   data from a backend draws loading, failure (with retry), empty and data itself
   (`Remote`). Anything that is cut off says so: "200 of 12 340".
2. **Exact, honest with input.** Nothing is changed quietly: a number outside its range
   shows an error, rounding is done as a person does by hand, a date can never be invalid.
   The same holds for AI: generated content is marked as generated, and nothing it
   proposes is applied before a person has seen it.
3. **Calm and dense.** Small type, no decoration, no motion that moves content around,
   `prefers-reduced-motion` respected.
4. **Complexity inside, business logic outside.** The application (or the AI that writes
   it) handles orders, customers and rules. It never handles focus, popups, virtual
   scrolling, ARIA, keyboard maps, date arithmetic or layout.
5. **Impossible to misuse.** The API is as type safe as Elm allows: a mistake is a compile
   error, not a bug found in use. Opaque types, the application's own id types, no
   `String` where a value belongs (ids, colors, dates, sizes, keys, urls), no functions in
   `Msg` or `State`, required things are required arguments and cannot be forgotten,
   options that exclude each other are one type and cannot be given together, and a state
   that makes no sense cannot be built. See A5.
6. **Keyboard first, accessible by design.** Roles, `aria-*`, visible focus,
   announcements for asynchronous changes.
7. **Pure and robust.** No ports, no JavaScript, no `iframe`. Official `elm/*` packages
   only. The pure parts are unit tested, Elm 0.19.1 and the oldest allowed dependencies are
   checked.
8. **Honest about limits.** If something cannot be done well in pure Elm, Klar does not
   fake it.
9. **Transport neutral.** Klar never knows about HTTP, WebSockets or an AI provider. The
   application moves the data; Klar shows it and asks for decisions.
10. **Small to hold in your head.** The API surface is as small as it can be, because the
    complexity lives inside the component. One obvious way to do each thing, the same name
    for the same idea in every module, a short path for the common case. A reader with
    only the documentation can build a correct application.
11. **Only Elm.** An application that uses Klar imports Klar and its own modules. No CSS
    file, no JavaScript, no class names, no style strings, no setup. Looks come from a
    typed `Theme`, layout from `Klar.Layout`, and a custom component is built from the same
    typed pieces. See A6.

### The admission test

A component joins Klar only when it can say yes to all of these:

- Does it take the application's own types (ids, `Remote`, `Date`) and hide the rest?
- Does it draw every state: loading, failure, empty, stale, data?
- Is it complete with the keyboard, and announced to a screen reader?
- Is every piece of built-in text in `Klar.Locale` (English and Norwegian Bokmål)?
- Are the pure parts (parsing, filtering, layout maths) tested?
- Does it have a showcase page, an entry in the AI index (Phase A) and a recipe?
- Does it follow the naming table and the API budget (Phase A)?
- Does it avoid glue code that every application would repeat?
- Can it not be put into a state that makes no sense? Can two options that contradict each
  other not be given together? Can a required thing not be forgotten?
- Is the exposed surface the smallest that still does the job, with the complexity inside?
- Can an application use it with zero CSS and zero class names?
- Can it grow without breaking anyone? In Elm, adding a variant to an exposed custom type
  is a breaking change. A type that will grow (message parts, kinds, formats) is opaque
  and built with functions; an exposed union is only for a closed set the application
  must match on.
- Has it been used in a real application, not only in the showcase?

## How the plan is read

- **Committed** items are what we build, in order.
- **On demand** items are real wishes, but each is a product of its own. They are started
  when a real application needs them, never because they are on the list. Depth before
  breadth: fewer components that all pass the admission test are worth more than many that
  nearly do.
- A phase is finished before the next one starts, except where it says otherwise.

## Built ahead of the plan (October 2026)

A first wave of components was built in parallel with Phase A, on top of the existing
core and without touching it. Each was reviewed by a second pair of eyes (logic against an
independent reference, accessibility, safety, API against the rules above) and fixed. None
has been used in a real application yet, so the last admission question is still open for
all of them, and the A0 second round should include them.

| Roadmap row | Built as |
|---|---|
| B: Sortable | `Klar.Sortable` (pointer and keyboard, announcements; no subscription) |
| B: Splitter / Resizable panels | `Klar.Splitter` |
| B: `Link`, Kbd | `Klar.Link` (a typed target that cannot leave the application by accident), `Klar.Kbd` |
| B: SplitButton, ButtonGroup, ToggleGroup | `Klar.SplitButton`, `Klar.ButtonGroup`, `Klar.ToggleGroup` |
| B: Bulk action bar, Result pages, Leave-guard | `Klar.BulkBar`, `Klar.StatusPage`, `Klar.LeaveGuard` |
| C: TreeSelect, Cascader, Transfer | `Klar.TreeSelect`, `Klar.Cascader`, `Klar.Transfer`, with `Klar.Picking` for the shared node |
| D: Markdown parser and renderer, editor | `Klar.Markdown` (hand written, no new dependency), `Klar.MarkdownEditor` |
| D: Diff viewer (text, JSON, records) | `Klar.Diff`, and `Klar.Compare` from Phase C. The read-only code block with highlighting is not built |
| D: Permission matrix, Approval flow, Undo / redo | `Klar.PermissionMatrix`, `Klar.ApprovalFlow`, `Klar.History` |
| F: Masked input, Currency input | `Klar.MaskedInput`, `Klar.Money` and `Klar.MoneyInput` (exact, in minor units) |
| F: Recurring rule | `Klar.Recurrence`, `Klar.RecurrencePicker` (calendar dates only; time zones need a tz database that the official packages do not have) |

Left for later on purpose, because they sit on the overlay layer of A8 and should be built
on it: Popconfirm, HoverCard, Tour, the notification centre, `Menubar` and
`NavigationMenu`. Kanban, the comment thread, the audit log with diffs and the conflict
resolver build on `Sortable`, `Markdown` and `Diff` and can start now.

Findings that belong to Phase A and A8 and are listed here so they are not lost:

- Three id helpers say the same thing in three shapes: `Tree.nodeIds` and `Table.rowIds`
  take `{ toKey, fromKey }`, `SideNav.keys` and `Picking.ids` take only `toKey`. One shared
  shape would be simpler.
- `Select.Popup` and `Picking.View` hold the same popup code twice, and neither checks
  `isComposing`, so a key that confirms an IME composition can choose an option.
- `Button.group` and `Klar.ButtonGroup` do the same thing, and `Text.kbd` and `Klar.Kbd`
  overlap.
- `Menu` cannot open with the first item highlighted from the keyboard, and `Tag` cannot name
  its remove button differently, which the new components work around.
- `Remote` has no stale state (all new data components say so in their admission answer).

## Technical rules

- Official `elm/*` packages from the Elm team. The package depends on `core`, `html`,
  `browser`, `json` and `time` today. Allowed when a component needs them: `svg`, `file`,
  `bytes`, `parser`. Anything else needs a reason written in this file.
- `elm/http` stays out: Klar is transport neutral, so `File` values and progress numbers
  pass through the application.
- No ports, no JavaScript, no `iframe`, no third-party packages, no `elm-explorations/*`.
- Each addition to `elm.json` is justified in the changelog.

## What cannot be done, and what we do instead

| Wanted | Why not | Instead |
|---|---|---|
| Copy to clipboard button | Needs JavaScript | `user-select: all` on code and values: one click selects it all, then Ctrl+C. Plus download as a file |
| Real token streaming from an AI | `elm/http` hands over the body when the request is done | The application shows partial text as it receives it, or Klar polls a partial message (`Time`); a typewriter reveal on a finished answer |
| `play()`, `pause()`, fullscreen on video | Method calls | Keep the native controls; build the rest around them |
| WYSIWYG editor | `contenteditable` needs JavaScript | Markdown editor with preview |
| Maps, PDF viewer, signature, image crop output | Canvas, `iframe`, JavaScript or a tile server | Not in Klar |
| Resumable chunked upload | `elm/file` cannot slice a file | One request per file; the application owns retry |
| Blocking the tab from closing | `beforeunload` | Leave-guard for navigation inside the application |

## Phase A: made for an AI, themed, and in order

Nothing else starts before this. It decides how every later component is shaped. The order
inside it matters: A0 first, because what it finds changes A1 to A7.

### A0. Use it first

**Status: three rounds done.** The applications were built three times (`apps/`, `apps/round2`,
`apps/round3`); the evaluations are [apps/EVALUATION.md](apps/EVALUATION.md),
[apps/ROUND2-EVALUATION.md](apps/ROUND2-EVALUATION.md) and
[apps/ROUND3-EVALUATION.md](apps/ROUND3-EVALUATION.md). A1 (the AI documentation), A5 (types),
A6 (no CSS), A7 (debts: overlay layer, performance, stale data, the form model, LeaveGuard)
and most of A8 are built and merged; what is left is listed under "Next" in the round 3
evaluation: one editing pass over the AI documents, global density and time zone, the
server-mode helper, `RemoteView` focus, the last seams of the form model and the rule
builder. After that the benchmark of A3 (`bench/`) is run once more and Phase B can start.

The first step, before any documentation or renaming: build two or three real
applications with Klar as it is, written by an AI from the documentation. Write down every
friction: a function that was hard to find, a type that was awkward, code the application
had to write that Klar should have hidden. That list drives A1 to A7 and decides what to
change while a breaking change is still free. After a publish nothing can be removed, and
80 modules that have never been used in a real application should not be frozen.

| Piece | Size |
|---|---|
| Two or three real applications (different shapes: list and detail, a dashboard, a form-heavy flow) | L |
| `FRICTION.md`: one line per problem, with the module and the fix | S |
| Review the exposed custom types against the rule "opaque if it can grow" | M |

### A1. Documentation for an AI reader

**Status: done, except the expression fragments and the other recipes.** `AI.md` and `llms.txt`,
`ai/klar-index.json` and `ai/modules/*.md` (generated by `npm run gen:ai-docs`, checked for staleness
in `npm run check`), six recipes and the application template (compiled by `npm run check:recipes`),
the paragraph for a consumer's `CLAUDE.md` in USING.md. Every module doc opens with its purpose, a
`Use when:` and a `Do not use when:` line, and (for a module with a State and Msg) a `Quick path:`
line; `check:ai-docs` fails when one is missing. `npm run check:doc-examples` compiles the complete
examples of the module docs and runs with `--strict` in `check` (none fails; 21 need the application's
own types and are listed in `ai/doc-example-report.md`). Not done: compiling the expression fragments
that make most of the doc examples, and the recipes beyond the six (the "twenty").

| Piece | What it is | Size |
|---|---|---|
| `AI.md` and `llms.txt` | One short entry point: the mental model (a `State`, a `view`, an `update`), the ten rules, the standard application architecture, the twenty most common recipes. Under 400 lines | M |
| `klar-index.json` | Generated from the doc comments and `docs.json`, never edited by hand, so there is one source of truth. For each module: one-line purpose, when to use it, when not, its `State`, `Msg` and ids, the minimal snippet, related modules, keywords. The first file an AI reads | M |
| Quick path in every module doc | At the top of each module: "Use when / Do not use when / Minimal example / Options". The 90% case in at most six functions; everything else below it | L |
| Recipes | "A searchable order table with paging on the server", "An edit form with validation and a save that can fail", "A confirmation before delete". Each is a complete, compiled program | L |
| Application template | A small working application with the standard architecture that an AI copies as its start | M |
| Snippet for the consumer's `CLAUDE.md` | A paragraph an application drops into its own project instructions: use only exposed modules, read `klar-index.json` first, never write your own popup / focus / date code | S |
| Verified docs | A script compiles every example in the docs and every recipe in the check. A stale example fails `npm run check`. The index is regenerated by a script and checked for staleness | M |

### A2. A small, consistent API

| Piece | What it is | Size |
|---|---|---|
| Naming table | One table in `CONTRIBUTING.md`: `init`, `update`, `view`, `State`, `Msg`, `onX` for events, attributes named after the thing they set. The same name always means the same thing | M |
| Naming audit | Read every module against the table and fix the differences now, while a breaking change is free | L |
| API budget | A script lists each module's exposed values and flags modules where the common path is long. The aim is a short way for the usual case (a few functions, the rest as attributes under their own heading), not a hard number | M |
| Errors that teach | Types named so a compile error explains itself; no `String` where a value belongs; typed `Result` errors with a readable message | M |
| Defaults that are right | Every option has a default that is the best choice. A component with no options is correct | M |

### A3. An AI benchmark

**Status: set up, not run.** `bench/` has the twelve tasks, `bench/run.md` (briefing, what is
recorded, the score and the rule that it may not drop), the baseline from A0 and
`scripts/bench-workspace.mjs`, which builds the folder a fresh session is given. The first run
comes after the Quick path.

Twelve fixed tasks (an order list with filters, an edit form, a dashboard, a rule builder,
...). For each release, a fresh AI with only the documentation builds them. Record: compiles
on the first try, number of fixes, any use of an unexposed module, any hand-written
focus / popup / date code. The score is stored in `bench/` and may not drop between
releases. M to set up, S to run.

### A4. Theming from the outside

The look today is liked and stays the default. What is new is that an application can
change it with a typed value instead of hand-written CSS. The tokens (`--klar-*`) stay a
documented, stable part of the API.

- **`Theme` value.** `Theme.make` takes the color roles: primary, secondary, success,
  warning, danger, info and neutral, plus mode (light, dark, auto), corner radius and
  font. `Klar.Theme.view theme` renders the style element. Scope: the whole page, or one
  container.
- **Typed colors.** `Theme.hex "#0b7285"` returns a `Result`, not a string, so a bad color
  is a clear error, not a silent fallback (principle 2).
- **Derived automatically, in Elm.** From one primary color the theme computes hover,
  active, subtle, border and the text color on top of it. The text color is chosen by
  measured contrast. `Theme.contrastProblems` lists any pair that falls under WCAG AA, so a
  theme can be checked in a test.
- **Ten presets**, each with light and dark: Klar (today's blue), Ocean (teal), Forest
  (green), Indigo, Violet, Rose, Sunrise (amber), Slate, Graphite (neutral), Contrast
  (high contrast for accessibility). That is twenty palettes; a test runs
  `contrastProblems` on all of them.
- **Component tokens.** Buttons first: `--klar-button-bg`, `--klar-button-text`, and so on,
  each falling back to the role tokens, so one button style can differ without a fork. The
  other components follow as they are touched.
- **Theme lab** in the example: pick a preset or colors, see every component, and see the
  contrast warnings. It is built from Klar's own components, so it tests them.
- Work: M for the theme value and presets, L for dark mode (the tokens are drawn for a
  light surface, and every component must be checked), M for the component tokens, S for
  the lab.

### A5. Types that cannot be misused

The aim is concrete: a wrong program does not compile. For every module, the audit asks
the same questions and fixes what it finds, while a breaking change is free.

| Technique | Example |
|---|---|
| Exclusive options are one type, not several flags | A table is in client mode or server mode: `Table.rows (Client rows)` or `Table.rows (Server remote)`, never both, never neither |
| Required means required | Things a component cannot work without are arguments or fields of a required record, not optional attributes |
| A value type, not a `String` | `Theme.Color`, `Klar.Date`, a size in a `Space` type, a key as `Keys`, an id as the application's own type |
| Impossible states do not exist | A selection that must have one item is a non-empty type; a range cannot end before it starts; a page number cannot be 0 |
| Failure is a value | A parse that can fail returns `Result` or `Maybe`, never a default that hides the mistake |
| One name, one place | DOM ids and keys come from one declared type in the application, never from scattered strings |
| Exhaustive by design | Messages the component sends are a closed set the application can map; no catch-all string events |
| No hidden order | Setting options in a different order gives the same result |

The result is checked in two ways: a test per module that tries to build a nonsensical
state and fails to compile (a "must not compile" list kept in `tests/`), and the benchmark in
A3, where any invented workaround counts against the score.

### A6. No CSS, no JavaScript, no setup

The stylesheet is already delivered as Elm (`Klar.stylesheet`). This step finishes the
promise so an application never touches styling.

| Piece | What it is | Size |
|---|---|---|
| One entry point | The stylesheet and the theme are rendered by one call, so there is a single thing to put in the view and nothing else to import or configure | S |
| Authoring stays vanilla CSS, inside the package | `css/src/*.css` is built into an Elm module. The application sees only Elm. Moving the sources into Elm values is possible later but gives nothing the application can see, so it is not planned | - |
| Typed building blocks for custom components | A custom component is built from `Klar.Layout`, `Klar.Text`, `Klar.Card` and typed spacing, size and tone values, so it matches without a class name or a style string. A small `Klar.Custom` module exposes only what is missing | M |
| A lint for applications | `scripts/check-app.mjs` also flags `Html.Attributes.class`, `style` and `Html.node "style"` outside a folder the application marks as custom components | S |
| No external assets | No font, icon file, image or CDN link is needed; icons are Elm values | - |

### A7. Debts that outweigh new features

| Item | Size |
|---|---|
| Split `Table.elm` (5 870 lines) and `Chart.elm` (2 988 lines) into internal modules, with the shared column / sort / filter core ready for the table family in Phase C | L |
| Firefox and Safari pass, not only Chromium | M |
| Screen reader pass | M |
| 100 000 rows in Table, Tree and Select as a test in `npm run check` | M |
| Finish the typed ids that remain: `Autocomplete`, and a decision on `Rule`'s operators | M |
| Commit the work that is waiting | S |

### A8. Fixes from the real applications

From [apps/EVALUATION.md](apps/EVALUATION.md). They come before the rest of Phase A and
before every later phase: what hurt was the glue between existing components, not a lack of
new ones.

| Item | Size |
|---|---|
| Sure fixes: rename the clashing `Success` (`Theme.Tone` against `Remote`), fix every doc example that does not compile (and compile them in `check:docs`), the mounting and `elm/url` recipe, and about twenty small gaps (`Date.toPosix`, `Format.iso8601`, `Stat.change`, `Layout.fillRest`, heading levels, target sizes, ...) | M |
| **Form model**: one `Form.State` that owns every field's value, knows when it is dirty, loads and returns a record, takes server problems per field, and knows steps and their status | XL |
| **Overlay layer** (done: `Klar.Overlay`, see CHANGELOG): it owns focus, derives `modalOpen`, keeps toasts reachable and out of the way of dialogs, fixes the duplicate landmarks | L |
| **Data-dense performance**: cache the sorted and filtered rows in `Table`, virtual rows, `Search` pre-filtering, one row type for `Table` and `VirtualList`, keyboard model for `VirtualList`; tested at 50 000 rows | L |
| **Server-mode helper**: "compare, reset the page, ticket the answer, debounce" in one place, shared by `Table`, `FilterBar`, `SavedViews` and the palette section | L |
| `Remote`-aware containers (`Drawer`, `Modal`, `Card`) and a stale state for refreshes that fail | M |
| Typed ids where they are still strings: `Rule` choices over `Select.Option`, `Radio`, validators over any value, DOM ids derived from state | L |
| Layout and density: a fixed width, fill the rest, `auto-fit`, one density that every component follows, sidebar width | M |
| axe in `npm run check` on every showcase page | S |

**Status of density and time zone: done** (see `design/SETTINGS.md`). `Klar.Settings` holds both; the shell
(`AppShell.settings`) makes everything inside follow the density through the stylesheet, and the components
that write a time take `settings` (the old `zone` attributes are gone); a time without a zone says "UTC".
Locale is not in it (decision left open in the design note); a fixed width, `auto-fit` and the sidebar width
of the A8 row were already there.

**Status of the stale state and the `Remote`-aware containers: done** (see
`design/STALE-DATA.md` and the CHANGELOG). `Remote` has a fifth state, `Kept`, made by
`Remote.refresh` and `Remote.refreshWith`; `Table`, `Stat`, `Chart`, `Timeline`, `Tree`, the
select family, `ListItem.remote` and the command palette draw refreshing and old data with
no attribute; `Klar.RemoteView` is the body of a card, dialog or drawer; `Alert.stale` is
the notice of a page; `loading` can no longer cancel `remote`. The Stock application of
round 2, rewritten on it, lost its `Feed` module, `settle`, `anyStale` and `viewNotices`.
Not done: a focus that survives a successful retry outside `Table` and the overlays (it needs
a `Cmd`, see CONTRIBUTING), and a marker in `Cascader`, `TreeSelect`, `Transfer`,
`PermissionMatrix`, `ApprovalFlow` and `Compare`, which show `Kept` data as if it were `Loaded`.

**Status of data-dense performance: done in the library, to be measured again in the
second round.** Cause found by profiling in Chrome: every message turned every row into
text again (the search text, the sort keys, number formatting), and a page change sorted
the 50 000 rows again. Now `Table.prepareRows` keeps the search texts, the sorted order of
each sortable column and the footer sums with the rows, `Table.virtual` scrolls instead of
paging and draws only the rows in view, `VirtualList.list` owns its rows and is a list box
for the keyboard, and `Search` tests the letters of a typo-tolerant query natively before
it walks a text. 50 000 rows of 7 columns: search, sort and page each under 100 ms
including two animation frames (see CHANGELOG.md for the numbers). Not done: S-023 (a
column hidden below a width) became documentation, and the filtered rows are still found
again on each view while a search is active (a scan of the search texts, a few
milliseconds at 50 000 rows).

**Status of the form model: built, seam closed.** `Klar.Form` (using a form), `Klar.Form.Spec`
(declaring it), `Klar.Form.Check` (tests), `Klar.Form.Layout` (the frame) and `Klar.Ids`:
text, long text, number, choices, switches, tags, files, steps with a stepper and a review
list, repeating rows, server problems and problems from outside the model, focus by handle,
one dirty flag. The onboarding flow of round 2 shrinks from 1 631 to 1 030 code lines and from
110 `KLAR GAP` lines to 45, all for the price rules (`custom` is not built). See
[design/FORM-MODEL.md](design/FORM-MODEL.md) section 10.

Second round of A0 after these: rebuild the three applications and compare compile errors,
iterations, `KLAR GAP` lines and behaviour bugs with the first round.

## Phase B: interaction

*"I can arrange my workspace."*

| Component | Size |
|---|---|
| Sortable (drag to reorder, keyboard moves, announcements) | L |
| Splitter / Resizable panels | M |
| `Link` (typed route, active state, external marker) | S |
| Navigation completion: `Menubar`, `NavigationMenu` (panels), `SplitButton`, `ButtonGroup`, `ToggleGroup`, `Tabs` overflow with closable and reorderable tabs, `Breadcrumbs` collapse, cursor `Pagination`, tenant / workspace switcher, favourites and recent items, skip links, focus and title on route change | L |
| Notification centre (the bell, history next to `Toast`) | M |
| Bulk action bar ("12 selected: Export, Delete") | S |
| Form error summary with jump to the field | S |
| Popconfirm and HoverCard | S |
| Result pages (success, denied, 404, 500) | S |
| Leave-guard for unsaved changes inside the application | S |
| Tour (guided walkthrough that points at real elements) | M |
| Anchor (table of contents) and Affix | S |
| Kbd, Divider, Flex and Grid helpers | S |

## Phase C: the table family

`Klar.Table` stays as it is: the data table, only fixed and refined. New tables are new
modules, each for a purpose, all built on the same shared core (columns, `ColumnId`, row
ids, sorting, filtering, virtual rows, locale). Changing from one table to another changes
a module name and a few attributes, not the way you think.

| Module | Purpose | Size |
|---|---|---|
| `Klar.Table` | Read, sort, filter, select, page. Existing | fixes only |
| `Klar.Grid` | Edit like a spreadsheet: cell editing with validation, range selection, fill, paste from Excel, undo, pinned and resizable columns | XL |
| `Klar.TreeTable` | Hierarchy: tree rows, grouping, aggregates (sum, average, count), master/detail rows | XL |
| `Klar.PivotTable` | Choose rows, columns and values; totals; drill down | L |
| `Klar.CardList` | The same columns as cards or a gallery, for narrow screens and overviews | M |
| `Klar.Compare` | Records side by side with the differences marked | M |

Also: conditional formatting and sparklines in cells (all tables), TreeSelect, Cascader,
Transfer (dual list), Stat v2 (trend, target against actual). M each or less.

## Phase D: text, change and review

*"I can see what changed, and decide."* The base of the AI interface.

| Component | Size |
|---|---|
| Markdown parser and renderer (`elm/parser`), tolerant of unfinished text | L |
| Markdown editor with preview | M |
| Diff viewer (text, JSON, records) and read-only code block with highlighting | M |
| Query language for `FilterBar`: `status = open and total > 100` becomes a typed `Rule` | L |
| Comment thread and mentions (`@` at the end of the text) | M |
| Audit log and activity feed with diffs | M |
| Conflict resolver (your version against theirs after a 409) | M |
| Work queue: a list with `j` / `k`, a detail pane, approve / reject, comments | L |
| Permission matrix, user and role picker, sharing dialog | M |
| Approval flow (steps, owners, status) | M |
| Undo / redo history for forms and editors | M |

The query language is the contract between a person, an AI and a backend: a person types
it, an AI writes it, `Rule` is the typed result, the server runs it.

## Phase E: AI interface (`Klar.Ai.*`)

*"The assistant is in the application, and I stay in charge."*

Klar does not talk to an AI. The application does, and hands Klar typed values, the same
split as `Remote`. A `Turn` is pending, running, done, failed or cancelled and consists of
typed parts. **Never trust silently**: generated content is marked, traceable and applied
only after a person has accepted it.

AI is the fastest-moving area, and a published API cannot lose anything. So the parts of a
`Turn` (text, reasoning, tool call, citation, attachment, approval, proposal) are opaque
and built with functions, and Klar draws them; an application does not match on them. A new
kind of part is then a new function, not a breaking change. Keep this module family small
and add to it slowly.

First slice:

| Component | Size |
|---|---|
| Conversation (roles, grouping, date separators, follows the newest message, "jump to latest", virtualised) | L |
| Composer (grows with the text, Enter sends, Shift+Enter newline, IME safe, attachments, slash commands, send / stop, length meter) | L |
| `Turn` states and typed parts | M |
| Reasoning panel and tool call card (arguments in `JsonViewer`, status, duration, retry) | M |
| **Approval request**: what the AI wants to do, why, risk level; approve, deny, edit; keyboard | M |
| Citations (numbered chips, hover card with the source) | M |
| Provenance badge ("AI generated", model, time) and "AI summary" card with sources | S |
| Usage meter (tokens, cost, context window) | S |
| **Ask in words**: natural language gives an editable `Rule`, shown as chips, applied only on confirmation | M |
| `Poll`: cadence and backoff for a partial message; typewriter reveal | S |

Second slice:

| Component | Size |
|---|---|
| Proposal with diff: accept / reject per hunk; AI-suggested field values as ghost values in a `Form` | L |
| Regenerate, edit a message, branches ("2 / 3"), feedback with reasons | M |
| Schema form: a JSON Schema subset becomes a typed `Form` (tool arguments, structured answers) | L |
| Prompt library with `{variables}` as a typed form, model picker with capability badges | M |
| Conversation history | M |
| Review queue of AI outputs (an instance of the work queue) | S |
| Redaction display (masked values, reveal with a recorded reason) | M |

## Phase F: forms and inputs

| Component | Size |
|---|---|
| Masked input (phone, IBAN, organisation number, postal code), `elm/parser` | M |
| Currency, unit and percent input | M |
| Field arrays and Wizard form with a draft | L |
| ColorPicker (also used by the theme lab) | M |
| `Field` groups with conditional visibility | M |
| Date and time: time zone aware field, recurring rule (every second Tuesday) | L |
| Session timeout | S |

On demand: OTP / PIN input, Rate, Watermark.

## Phase G: files and media

*"I can bring files in, and get data out."* `elm/file` and `elm/bytes`.

| Component | Size |
|---|---|
| Upload: select or drop, mime and size validation, queue, image preview, progress given by the application | L |
| Import wizard: CSV, column mapping, row-by-row validation, error report | L |
| Media upload for audio and video (duration read through a hidden media element) | M |
| `Video` and `Audio`: native controls kept, plus our own seek bar with chapters and markers, speed, loop and A to B repeat, subtitle tracks, transcript that follows the playback, playlist | L |
| ICS and vCard export | S |

On demand (each is a product): Zip writer and `.xlsx` export on top of it; PDF generation
for reports from tables and text (standard fonts with Norwegian letters), until then a print
stylesheet and the browser's "Save as PDF"; file manager; carousel and lightbox.

## Phase H: planning and visual

`elm/svg` is added to `elm.json` when the first item that needs it starts, for curves,
arcs and edges only.

| Component | Size |
|---|---|
| Kanban (columns, swimlanes, WIP limits), built on Sortable | L |
| Calendar week and day views with events, drag to move and resize | L |
| Chart additions: curves, area, stacked, treemap, gauge, heatmap, sparkline | L |

On demand (each is a product of its own, started only when a real application needs it):
Scheduler / resource view, Gantt (dependencies, critical path, baselines), diagram and flow
editor and process builder, sankey, org chart, QR code and Code128 barcode with PNG
encoding, spreadsheet with formulas on top of `Klar.Grid`.

## Cross-cutting, alongside every phase

- More locales (Swedish, Danish, German, Finnish, French) and right-to-left support with
  CSS logical properties.
- The accessibility check in `npm run check` (axe on every showcase page).
- A print stylesheet for reports.
- Every phase ends with: `npm run check` and `npm run check:compat` green, the AI index
  regenerated, the benchmark run.

## Left out, on purpose

WYSIWYG editor, maps, PDF viewer, signature pad, image crop output: they need JavaScript,
canvas or `iframe`. Everything else once on the list is now in a phase above.

## The freeze point

Before the first `elm publish` (1.0.0 is permanent):

- Phase A is finished: real applications built (A0) and their friction fixed, the AI
  documentation, the naming audit, the API budget, theming, the type-safety audit (A5),
  and an application that needs no CSS (A6).
- The benchmark passes on a clean run.
- Firefox, Safari and a screen reader have been tried.
- The changelog and `RELEASING.md` have been walked through once.

The decision to publish is the owner's.
