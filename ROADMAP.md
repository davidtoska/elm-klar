# Roadmap

Klar is in development before its first publication. The API can still change.
This file tracks future decisions, not completed work or a second component catalog.
Development rules live in [AGENTS.md](AGENTS.md); current public contracts live in
the [module reference](ai/modules/README.md).

## Before the first release

Work through these priorities before freezing the API. Investigate existing reports
against the current code before fixing them; a roadmap item is not a confirmed test.

### 1. Input, remote state and API consistency

- Resolve inconsistent number parsing: `NumberInput` accepts Norwegian `10.000`
  as 10000 while `Money` refuses the ambiguity; `Rule.parseNumber` has no locale
  and reads English `1,234` as 1.234. Define one explicit rule and refusal text.
- Decide the retry lifecycle of `Remote.Failed`: refreshing it becomes `Loading`
  and removes the initial retry control. Resolve `StatusPage.retrying` alongside
  the design of freshness on loaded data, keeping stable retry focus targets.
- Make `Settings` the shared source of language, today, now and keyboard platform.
  Audit `X.settings` and remove redundant per-component platform configuration.
- Use shared keyboard helpers throughout; add IME guards to remaining direct key
  decoders. Resolve function-bearing `State`/`Msg` and freshness warnings before
  making `check:rules` strict.
- Audit growing exposed records/unions (`Select.Option`, `Field.Config`, table
  filters). Move composition-only `DatePicker.invalid` and `TimePicker.invalid`
  behind the public boundary. Finish naming consistency (`onSelect`/`onActivate`,
  tree/picking node vocabulary) before the API is published.
- Finish the form audit of control-specific refusal texts in error summaries,
  including repeating rows and custom controls. Application record/session
  correlation remains separate from the shared submission lifecycle.

### 2. Accessibility and focus

- Try Firefox, Safari, a screen reader, touch/pen, Windows high contrast and a Mac
  keyboard. Chromium checks alone do not establish support for these combinations.
- Extend real browser checks beyond Orders/customer forms: lost-focus guards,
  toast recovery and shell focus after route changes. Run axe on showcase pages
  as part of the normal check.
- Design a persistent page-level announcer. Newly inserted status regions may not
  be read, and several failing dashboard panels can announce over one another.
- Use roving focus where Tab currently visits every item: selectable chart
  categories, `ListItem`, `ToggleGroup`, `MultiSelect` chips and table cells.

### 3. Scale and shared internals

- Add large-data checks for Table, Tree and Select, including a 100 000-row case.
  Investigate Tree navigation with many open nodes and PermissionMatrix's full
  grid traversal; prepare or virtualize where necessary.
- Audit per-file upload failure/retry/cancel presentation in `FileDrop` and its
  composition with `UploadQueue`; keep transport and actual uploading in the app.

### Release gate

- Resolve the priorities above, then run `npm run check` and `npm run check:compat`.
- Review the independent [kitchen-sink trial](apps/kitchen-sink/FINDINGS.md),
  resolve confirmed gaps and preserve its distinction between rendering and
  interaction coverage. Keep the [HTTP integration guide](example/HTTP.md) tied
  to the runnable consumer when its application protocol changes.
- Review README, AI.md, public contracts and the first-release changelog.
- Publish only at the owner's request, following [AGENTS.md](AGENTS.md#releasing).

## On demand

Start these when a real application needs them. Each is a scope decision, not a
commitment to build the whole list before publication.

| Area | Possible work |
| --- | --- |
| Navigation and overlays | Menubar, NavigationMenu, Popconfirm, HoverCard, Tour; tab overflow/closing/reordering, breadcrumb collapse, cursor pagination, workspace switching, favourites/recent items, Anchor/Affix and a notification bell |
| Table family | Grid, TreeTable and PivotTable; shared typed column concepts where useful, card/table interoperability, conditional formatting, sparklines and Stat trend/target views |
| Review and rules | Typed query language for FilterBar, mention suggestions in CommentThread, user/role pickers and sharing dialogs |
| Existing interaction components | Menu submenus/checkable items, non-modal Drawer, hoverable/Escape-dismissable Tooltip, Kanban dragging/swimlanes, MarkdownEditor typing history |
| AI conversation | Grouping, date separators, jump-to-latest, virtualization, composer attachments/slash commands, typed turn parts, tool/reasoning cards, citations, provenance and usage displays |
| AI editing | Natural language to a reviewable Rule, per-hunk proposals, suggested form values, message regeneration/branches/feedback, schema forms, prompt variables, history and recorded redaction reveals |
| Forms | Persistable wizard drafts, ColorPicker, remaining conditional field-group needs, time-zone-aware fields, session timeout; OTP/PIN, ratings and watermarks only when needed |
| Files and media | Upload previews, CSV import/mapping/validation, media metadata, native audio/video compositions, ICS/vCard export; ZIP/XLSX/PDF generation, file management and lightboxes are separate projects |
| Planning and graphics | Library day/week event grids, moving/resizing calendar events, chart time scales/curves/treemaps/heatmaps; Scheduler, Gantt, Sankey, org charts and barcodes are separate projects |
| Cross-cutting | More locales, right-to-left CSS/keyboard behavior and report printing refinements |

Before implementing Grid, write a reviewable design: price-list editing, bulk
correction and order lines; typed columns and validation; range selection,
fill/paste, undo and pinned/resizable columns. Define a minimal public API,
keyboard/focus behavior and performance limits, and divide the work into small
testable slices. Keep formulas and merged cells outside the initial scope.

Rich-text editing, maps, embedded PDF viewers, signature pads and image cropping
remain outside the library's current scope. Application integrations may supply
capabilities that require JavaScript, canvas or an iframe at the app boundary.
