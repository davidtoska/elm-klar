# Roadmap

Where Klar goes next. One package, not published yet, built to be used by an AI.

Sizes: S = days, M = 1 to 2 weeks, L = several weeks, XL = a project of its own.

## Premises

- **One package.** `davidtoska/elm-klar`, no companion packages. Everything is in one place
  and versioned together.
- **Not published yet.** Until the first `elm publish` the API may still change freely.
  This is the cheapest time to get the shape right. The freeze point is a checklist at the
  end of this file.
- **Maximal in components, minimal in dependencies and in API.** Many components, few
  packages, few functions per component, and the API as type safe as Elm allows.
- **An application is Klar plus its own code.** It imports Klar and its own modules, and
  nothing else: no CSS, no JavaScript, no assets.
- **Size and speed of the compiled program are not goals.** The applications are business
  applications; clarity and correctness come first. `elm make --optimize` removes code that
  is not used, so a large package does not make a small application large.
- **The main user is an AI.** An AI builds the application, a person reviews it. The
  documentation, the names and the types are made for that reader (`AI.md`, `ai/`).
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
   that makes no sense cannot be built.
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
    typed pieces.

### The admission test

A component joins Klar only when it can say yes to all of these:

- Does it take the application's own types (ids, `Remote`, `Date`) and hide the rest?
- Does it draw every state: loading, failure, empty, stale, data?
- Is it complete with the keyboard, and announced to a screen reader?
- Is every piece of built-in text in `Klar.Locale` (English and Norwegian Bokmål)?
- Are the pure parts (parsing, filtering, layout maths) tested?
- Does it have a showcase page and a module doc an AI can build from (Use when, Do not use
  when, Quick path)?
- Does it follow the conventions in `CLAUDE.md`?
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

## Before the first release

Built so far: more than a hundred components, the form model, the overlay layer, the stale
data state, server lists, one `Klar.Ids` per id type, ten themes with a light and a dark
mode, the AI documentation (`AI.md`, `ai/`) and seven example programs. Left before the freeze:

| Item | Size |
|---|---|
| Firefox and Safari, a screen reader, touch and pen, Windows high contrast and a Mac keyboard (only Chromium is tested) | M |
| Split `Table.elm` (about 7 000 lines) and `Chart.elm` (about 3 100 lines) into internal modules | L |
| 100 000 rows in `Table`, `Tree` and `Select` as a test in `npm run check` | M |
| `Autocomplete` values are still `String`, not the application's own type | M |
| No "old data" marker yet in `Cascader`, `TreeSelect`, `Transfer`, `PermissionMatrix`, `ApprovalFlow` and `Compare`: they show `Kept` data as if it were `Loaded` | M |
| `Select.Popup` and `Picking.View` hold the same popup code twice, and `Select` chooses an option on the `Enter` that confirms an IME composition | M |
| `Menu` cannot open with the first item highlighted from the keyboard; `Tag` cannot name its remove button differently | S |
| The avatar and chart palettes are not tuned per theme | S |
| axe in `npm run check` on every showcase page | S |
| A naming pass over every module against the conventions in `CLAUDE.md` | M |

Left for later on purpose, because they build on the overlay layer: Popconfirm, HoverCard,
Tour, `Menubar` and `NavigationMenu`. Kanban and the comment thread build on `Sortable`
and `Markdown`. Built ahead of the plan: `CardList`, `WorkQueue`, `AuditLog`,
`ConflictResolver` and `NotificationCenter`, exercised together in the ReviewDesk
example. The notification centre is an inline inbox that can also be placed in a
drawer; a global bell remains an application concern. `CardList` has its own small
field API; sharing columns with the table family remains future work.

## Technical rules

- Official `elm/*` packages from the Elm team. The package depends on `core`, `html`,
  `browser`, `json`, `time`, `url` and `file` today. Allowed when a component needs them:
  `svg`, `bytes`, `parser`, `regex`, `random`. Anything else needs a reason written in this file.
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

## Phase B: interaction

*"I can arrange my workspace."* Built already, and listed in "Built ahead of the plan" above: `Sortable`, `Splitter`, `Link`, `SplitButton`,
`ButtonGroup`, `ToggleGroup`, `BulkBar`, `StatusPage`, `LeaveGuard`, `Kbd`, and the form error summary
(`Form.summary`).

| Component | Size |
|---|---|
| Navigation completion: `Menubar`, `NavigationMenu` (panels), `Tabs` overflow with closable and reorderable tabs, `Breadcrumbs` collapse, cursor `Pagination`, tenant / workspace switcher, favourites and recent items, skip links, focus and title on route change | L |
| Notification centre (the bell, history next to `Toast`) | M |
| Popconfirm and HoverCard | S |
| Tour (guided walkthrough that points at real elements) | M |
| Anchor (table of contents) and Affix | S |
| Divider, Flex and Grid helpers | S |

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

Also: conditional formatting and sparklines in cells (all tables), Stat v2 (trend, target against
actual). M each or less. Built already: `Klar.Compare`, `TreeSelect`, `Cascader`, `Transfer`.

## Phase D: text, change and review

*"I can see what changed, and decide."* The base of the AI interface. Built already, and listed in "Built ahead of the plan" above: `Markdown`,
`MarkdownEditor`, `Diff`, `PermissionMatrix`, `ApprovalFlow`, `History` (undo and redo).

| Component | Size |
|---|---|
| Read-only code block with highlighting | M |
| Query language for `FilterBar`: `status = open and total > 100` becomes a typed `Rule` | L |
| Comment thread and mentions (`@` at the end of the text) | M |
| Audit log and activity feed with diffs | M |
| Conflict resolver (your version against theirs after a 409) | M |
| Work queue: a list with `j` / `k`, a detail pane, approve / reject, comments | L |
| User and role picker, sharing dialog (next to `PermissionMatrix`) | M |

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

Built already, and listed in "Built ahead of the plan" above: `MaskedInput`, `Money` and `MoneyInput`, `Recurrence` and
`RecurrencePicker`, and the field arrays and steps of `Klar.Form`.

| Component | Size |
|---|---|
| Unit and percent input | M |
| A draft for a wizard form | M |
| ColorPicker (also used by the theme lab) | M |
| `Field` groups with conditional visibility | M |
| Date and time: time zone aware field | L |
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
| Chart additions: curves, area, stacked, treemap, heatmap (gauge, meter and sparkline exist) | L |

On demand (each is a product of its own, started only when a real application needs it):
Scheduler / resource view, Gantt (dependencies, critical path, baselines), diagram and flow
editor and process builder, sankey, org chart, QR code and Code128 barcode with PNG
encoding, spreadsheet with formulas on top of `Klar.Grid`.

## Cross-cutting, alongside every phase

- More locales (Swedish, Danish, German, Finnish, French) and right-to-left support with
  CSS logical properties.
- The accessibility check in `npm run check` (axe on every showcase page).
- A print stylesheet for reports.
- Every phase ends with: `npm run check` and `npm run check:compat` green, and the AI
  documentation regenerated.

## Left out, on purpose

WYSIWYG editor, maps, PDF viewer, signature pad, image crop output: they need JavaScript,
canvas or `iframe`. Everything else once on the list is now in a phase above.

## The freeze point

Before the first `elm publish` (1.0.0 is permanent):

- The list "Before the first release" is done.
- An AI has built a real application from `AI.md` alone, and what it lacked is fixed.
- Firefox, Safari and a screen reader have been tried.
- README, AI.md and the changelog have been read once more.

The decision to publish is the owner's.
