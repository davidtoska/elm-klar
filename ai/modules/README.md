# Klar modules

One file per exposed module, generated from the doc comments by `npm run gen:ai-docs`. Start with [../klar-index.json](../klar-index.json) or [../../AI.md](../../AI.md).

## Start here

- [Klar](Klar.md): Klar (Norwegian for "clear" and "ready") is a toolkit of interface components for data-intensive applications.
## Foundations

- [Klar.Theme](Klar.Theme.md): The look of the application: ten themes, each in a light and a dark mode, and the small shared vocabulary of the components: the color of a message (`Tone`), the size of a control (`Size`) and how ...
- [Klar.Color](Klar.Color.md): A color that comes from data: the color of a status, a category, a team, a customer.
- [Klar.Settings](Klar.Settings.md): What the application says once: the language of the built-in text, the time zone of the times people read, the time now (and so the day today), how tightly things are packed (the density), and the ...
- [Klar.Locale](Klar.Locale.md): The language and the regional conventions of the text the library writes itself: placeholders such as "Search ...", the labels of icon buttons, month names, validation messages, number separators.
- [Klar.Layout](Klar.Layout.md): Layout primitives: vertical stacks, horizontal rows and grids, with spacing from a fixed scale.
- [Klar.Card](Klar.Card.md): A bordered surface that groups related content, with an optional header and footer.
- [Klar.Text](Klar.Text.md): Typography: titles, paragraphs, small print and code.
- [Klar.Icon](Klar.Icon.md): Line icons.
## Actions

- [Klar.Button](Klar.Button.md): Buttons and button-looking links.
- [Klar.Menu](Klar.Menu.md): A dropdown menu opened from a button.
- [Klar.ButtonGroup](Klar.ButtonGroup.md): Buttons that belong together, joined into one block: shared borders, only the outer corners rounded, and one focus ring per button that always stays in view.
- [Klar.ToggleGroup](Klar.ToggleGroup.md): A row of toggle buttons for choices that can be on or off: "Bold / Italic / Underline", the statuses to show in a list, the days of the week.
- [Klar.SplitButton](Klar.SplitButton.md): A main action with a few alternatives: a button joined to a small arrow that opens a menu. "Save" with "Save and close" and "Save as draft" behind the arrow.
- [Klar.Link](Klar.Link.md): A real link (`<a href>`) that cannot be built wrong: for a page of the application, for another site, for an email address or a telephone number.
- [Klar.Kbd](Klar.Kbd.md): Keyboard keys as key caps, for hints and documentation: "Ctrl K", "Shift Enter", or a sequence such as "G then O".
## Status and feedback

- [Klar.Badge](Klar.Badge.md): Small read-only labels for state and metadata, such as "Paid" or "Overdue", and round number badges.
- [Klar.Tag](Klar.Tag.md): A chip: a short label for a value, a filter or a selection, optionally with a remove button.
- [Klar.Alert](Klar.Alert.md): Inline messages that tell the user something important in the context where it matters: information, success, a warning or an error.
- [Klar.Spinner](Klar.Spinner.md): Loading indicators: a small spinner for inline use and a centered panel for a region that is still loading.
- [Klar.Skeleton](Klar.Skeleton.md): Shimmering placeholders that stand in for content while it loads.
- [Klar.Progress](Klar.Progress.md): Progress: a linear bar, a bar divided into steps, and a ring.
- [Klar.EmptyState](Klar.EmptyState.md): What to show when there is nothing to show: an empty list, no search results, a first-run screen.
- [Klar.ErrorState](Klar.ErrorState.md): What to show when a request failed: a clear title, the reason, and a button to try again when trying again can help.
- [Klar.NotificationCenter](Klar.NotificationCenter.md): Persistent notifications with an unread filter and explicit read and dismiss actions.
## Forms

- [Klar.Form](Klar.Form.md): A form as one value: the text and choices of every field, which fields the user has left, what the server refused, the rows of a repeating group, the step the user is on, and whether anything has ...
- [Klar.Form.Spec](Klar.Form.Spec.md): The declaration of a form: its fields in order, each with a label and its rules, grouped in steps.
- [Klar.Form.Layout](Klar.Form.Layout.md): The layout of a form and the parts around it.
- [Klar.Form.Check](Klar.Form.Check.md): Tests for a form: what an `elm-test` file needs to be sure that a declaration is right, in one line each.
- [Klar.Field](Klar.Field.md): The wrapper around a form control: a label, a required or optional mark, a hint and an error message, joined to the control for screen readers.
- [Klar.Validate](Klar.Validate.md): Pure, composable validators for text values.
## Inputs

- [Klar.TextInput](Klar.TextInput.md): A single-line text input with a label, a hint and an error message.
- [Klar.TextArea](Klar.TextArea.md): A multi-line text field with a label, a hint and an error message.
- [Klar.NumberInput](Klar.NumberInput.md): A number field that understands how people write numbers.
- [Klar.PasswordInput](Klar.PasswordInput.md): A password field with a "show password" button, a Caps Lock warning and an optional strength meter.
- [Klar.SearchInput](Klar.SearchInput.md): A search field that waits until the user stops typing.
- [Klar.TagInput](Klar.TagInput.md): Free-form tags: type a word, press Enter or comma, get a chip.
- [Klar.FileDrop](Klar.FileDrop.md): Choose files by dropping them on a zone or with a "Choose files" button.
- [Klar.InlineEdit](Klar.InlineEdit.md): Click-to-edit text.
- [Klar.Checkbox](Klar.Checkbox.md): A checkbox, with a label or bare.
- [Klar.CheckboxGroup](Klar.CheckboxGroup.md): A group of checkboxes: choose any number of the options.
- [Klar.Radio](Klar.Radio.md): A group of radio buttons: choose exactly one of a few options.
- [Klar.Switch](Klar.Switch.md): An on/off switch for a setting that takes effect at once ("Email notifications").
- [Klar.Slider](Klar.Slider.md): A slider for a number in a range, and a range slider with two thumbs.
- [Klar.SegmentedControl](Klar.SegmentedControl.md): A row of joined options where exactly one is chosen: a switch between views ("List" / "Grid"), periods ("Day" / "Week" / "Month") or modes.
- [Klar.MaskedInput](Klar.MaskedInput.md): A field for an identifier that has a fixed shape and, often, a check digit: an IBAN, an organisation number, a bank account, a postal code, a phone number, or a code of your own such as `AB-1234`.
- [Klar.Money](Klar.Money.md): An exact amount of money: a whole number of minor units (øre, cents, yen) together with its currency.
- [Klar.MoneyInput](Klar.MoneyInput.md): A field for an amount of money in one currency.
- [Klar.QuantityInput](Klar.QuantityInput.md): A quantity with an application's own unit type, keeping exactly the number text entered until the application explicitly changes it.
## Choosing

- [Klar.Select](Klar.Select.md): A single select with a search box, for lists from a handful to many thousands of options.
- [Klar.Ids](Klar.Ids.md): How the application's own id type is written as text and read back, once.
- [Klar.MultiSelect](Klar.MultiSelect.md): Choose several values from a searchable list.
- [Klar.Autocomplete](Klar.Autocomplete.md): A text field with suggestions.
- [Klar.VirtualList](Klar.VirtualList.md): A list of thousands of rows that draws only the rows in view, and is a list box for the keyboard.
- [Klar.Picking](Klar.Picking.md): The nodes of a hierarchy that Klar.TreeSelect and Klar.Cascader choose from, with ids of your own type (a `RegionId`, a `ProductId`, plain text ...) that a Klar.Ids writes as keys.
- [Klar.TreeSelect](Klar.TreeSelect.md): A field that opens a popup with a tree and lets the user choose one node, or several with check boxes.
- [Klar.Cascader](Klar.Cascader.md): A field for choosing a path through levels: Region, Country, City; Category, Subcategory, Product.
- [Klar.Transfer](Klar.Transfer.md): Two lists side by side, "Available" and "Chosen", and a way to move items from one to the other.
## Date and time

- [Klar.Date](Klar.Date.md): Calendar dates without a time or a time zone: a year, a month and a day.
- [Klar.DatePicker](Klar.DatePicker.md): A date field: type the date or pick it in a calendar.
- [Klar.DateRangePicker](Klar.DateRangePicker.md): A period field: a from date and a to date in one control, with one calendar that shows two months and a list of quick choices.
- [Klar.TimePicker](Klar.TimePicker.md): A 24-hour time field: type `14:30` or pick a time from a list.
- [Klar.DateTimePicker](Klar.DateTimePicker.md): A date and a time in one control: a Klar.DatePicker and a Klar.TimePicker side by side under one label.
- [Klar.Calendar](Klar.Calendar.md): A month calendar for choosing a day or a period, with small marks on days.
- [Klar.Recurrence](Klar.Recurrence.md): A rule for dates that repeat ("every second Tuesday", "the last day of the month, ten times").
- [Klar.RecurrencePicker](Klar.RecurrencePicker.md): A form field that builds a repeating Klar.Recurrence rule.
## Tables and lists

- [Klar.Table](Klar.Table.md): A data table for records: search, column filters, sorting, selection with bulk actions, row actions, expandable rows, CSV export and pagination.
- [Klar.Budget](Klar.Budget.md): An editable budget sheet with up to six columns, calculated line amounts and an exact grand total.
- [Klar.Pagination](Klar.Pagination.md): Page navigation for long lists and tables: the range shown ("1–25 of 3,000"), rows per page, first / previous / page numbers with ellipsis / next / last, and "Go to page".
- [Klar.ListItem](Klar.ListItem.md): A dense list row, and the list that holds the rows.
- [Klar.Tree](Klar.Tree.md): A tree view for hierarchies: regions and warehouses, folders, product categories, code lists.
- [Klar.CardList](Klar.CardList.md): A responsive collection of records as compact cards, with labelled fields, selection and actions that remain ordinary keyboard controls.
- [Klar.WorkQueue](Klar.WorkQueue.md): A keyboard-driven work list beside a detail pane, for processing one record at a time without losing the surrounding queue.
## Overlays

- [Klar.Overlay](Klar.Overlay.md): The layer above the page: dialogs, drawers, the command palette, the shortcut sheet and the toasts.
- [Klar.Modal](Klar.Modal.md): A dialog on top of the page, for work that needs the user's full attention: editing a record, a form with several fields, a step of a wizard.
- [Klar.ConfirmDialog](Klar.ConfirmDialog.md): The "are you sure?" dialog, with the whole life of the request it guards.
- [Klar.Drawer](Klar.Drawer.md): A panel that slides in from the side of the window: the details of a row in a list, a form with many filters, anything the user wants to see next to the page they came from.
- [Klar.Toast](Klar.Toast.md): Short notifications that appear in a corner of the window, stack up and go away by themselves: "Order saved", "Could not send the invoice".
- [Klar.Popover](Klar.Popover.md): A small panel anchored to a button, with any content: a quick filter, a few settings, a short form, an explanation with a link.
- [Klar.Tooltip](Klar.Tooltip.md): Short hints that appear when the pointer rests on an element or the keyboard focuses it.
- [Klar.ContextMenu](Klar.ContextMenu.md): The menu that opens where the user right-clicks.
- [Klar.CommandPalette](Klar.CommandPalette.md): A command palette: one search box, usually opened with `Ctrl K`, for commands ("New order", "Go to invoices") and for content ("Ada Lovelace").
- [Klar.ShortcutHelp](Klar.ShortcutHelp.md): The cheat sheet of keyboard shortcuts: a dialog that lists every shortcut of the application, grouped, with key caps and a small filter box.
## Navigation

- [Klar.AppShell](Klar.AppShell.md): The frame of a whole application: a top bar, a sidebar and a content area that scrolls on its own.
- [Klar.SideNav](Klar.SideNav.md): Vertical navigation for the sidebar of an application: sections, links with icons and counts, and groups that open and close.
- [Klar.PageHeader](Klar.PageHeader.md): The top of a page: the title, a line of explanation, where the page sits in the application, the state of the thing you are looking at, and what you can do with it.
- [Klar.Breadcrumbs](Klar.Breadcrumbs.md): The path to the current page: links separated by chevrons, where the last item is the current page.
- [Klar.Tabs](Klar.Tabs.md): Tabs that switch between views of the same thing: the overview of an order, its history and its files.
- [Klar.Stepper](Klar.Stepper.md): The steps of a wizard or a checkout flow, laid out horizontally or vertically.
## Structure

- [Klar.Accordion](Klar.Accordion.md): Sections that open and close in place: the details of a record, groups of settings, advanced filters.
- [Klar.Toolbar](Klar.Toolbar.md): A horizontal bar of grouped controls for a whole view: the strip above a table or a list (new, export, search, view switches) or the actions of an editor.
- [Klar.DescriptionList](Klar.DescriptionList.md): Label and value pairs for detail views, rendered as a semantic `dl`.
## Arranging

- [Klar.Sortable](Klar.Sortable.md): A list the user can put in a new order: by dragging an item by its handle, or with the keyboard.
- [Klar.Splitter](Klar.Splitter.md): Two or more panes side by side (or one above the other) that the user can make larger and smaller by moving the separators between them, with the mouse, a finger or the keyboard.
- [Klar.Kanban](Klar.Kanban.md): A dense board of ordered work columns, with explicit card moves, work-in-progress limits and keyboard operation that does not depend on dragging.
## Pages and flow

- [Klar.StatusPage](Klar.StatusPage.md): A page that stands for a whole result: "Order created", "No access", "Page not found", "Something went wrong on our side", "Down for maintenance".
- [Klar.BulkBar](Klar.BulkBar.md): The bar of actions for the items the user has selected: "12 selected: Export, Delete".
- [Klar.LeaveGuard](Klar.LeaveGuard.md): Asks "Leave without saving?" when the user leaves a page with unsaved work: by a link, by your own code and by the browser's Back and Forward buttons.
- [Klar.History](Klar.History.md): Undo and redo for a form or an editor: a value, the values it had before and the values it had before you undid them.
## Text and change

- [Klar.Markdown](Klar.Markdown.md): Markdown as safe, calm HTML: for the text of a note, a description, a help page, or the answer of a language model that is still being written.
- [Klar.MarkdownEditor](Klar.MarkdownEditor.md): A text area for Markdown with a toolbar and a live preview: the editor of a note, a description, a comment, or the instruction to a language model.
- [Klar.Diff](Klar.Diff.md): What changed between two versions of a text, of a JSON document or of a record, shown so that a person can see it and decide.
- [Klar.Compare](Klar.Compare.md): Records side by side, with the differences marked: two or more products, two versions of an order, "your version" against "theirs".
- [Klar.AuditLog](Klar.AuditLog.md): An immutable activity history with actors, exact times and expandable diffs.
- [Klar.ConflictResolver](Klar.ConflictResolver.md): A three-way field merge that makes concurrent edits explicit and requires a decision for every conflicting value before the result can be applied.
- [Klar.CodeBlock](Klar.CodeBlock.md): Read-only source code with lexical highlighting, line numbers and an honest preview limit; source is always escaped text and is never executed.
- [Klar.CommentThread](Klar.CommentThread.md): A reply thread with safe Markdown, exact timestamps and a draft that survives failed posting, refreshes and late acknowledgements.
## Access and approval

- [Klar.PermissionMatrix](Klar.PermissionMatrix.md): A grid of roles and permissions that says what each role may do, and lets an administrator change it: the classic screen of an application with users.
- [Klar.ApprovalFlow](Klar.ApprovalFlow.md): The approval process of one item: an ordered list of steps, each with one or several approvers and a decision from each, and where the item stands.
## Data display

- [Klar.Stat](Klar.Stat.md): A KPI tile: one number with its label, the change since last time, a short note and optionally a trend line.
- [Klar.Chart](Klar.Chart.md): Line, bar, donut, gauge, meter and sparkline charts, drawn without any chart or SVG package.
- [Klar.Timeline](Klar.Timeline.md): A vertical history of events: an audit trail, an order log, an activity feed.
- [Klar.Avatar](Klar.Avatar.md): Avatars: a person, an organization or a system shown as a small badge with initials, a picture or an icon.
- [Klar.JsonViewer](Klar.JsonViewer.md): A collapsible tree for looking at JSON: an API response, a stored document, a request body.
## Rules and filters

- [Klar.Rule](Klar.Rule.md): Rules as plain data: a tree of conditions and groups that you can edit, check, run against your rows, describe in words and store as JSON.
- [Klar.RuleBuilder](Klar.RuleBuilder.md): A visual editor for rules: groups of conditions that the user builds, rearranges and reads as a sentence, drawn with thin gray connector lines.
- [Klar.FilterBar](Klar.FilterBar.md): Quick filters above a table: the conditions that are on, shown as chips ("Status is Paid"), an "Add filter" button that opens a small editor (field, operator, value), and optional preset pills like ...
- [Klar.SavedViews](Klar.SavedViews.md): Named, saved filters ("views"): a dropdown button that lists the saved views and lets the user apply one, save the current filter under a new name, rename and delete views (after an inline ...
- [Klar.ServerList](Klar.ServerList.md): A list whose rows live on a server: a table, a filter bar and saved views that edit one query, and the glue that every such list needs, in one place.
## Data and utilities

- [Klar.Remote](Klar.Remote.md): The state of data that comes from a backend: not asked for yet, loading, failed, here, or kept (old data while it is refreshed, or after a refresh failed).
- [Klar.RemoteView](Klar.RemoteView.md): The body of a card, a dialog or a drawer that shows one piece of remote data.
- [Klar.Search](Klar.Search.md): Text matching for search fields, selects and command palettes: forgiving about case and accents, and ranked, so the best match comes first.
- [Klar.Format](Klar.Format.md): Formatting numbers, sizes, dates and times for people, in the conventions of a `Locale`.
- [Klar.Shortcut](Klar.Shortcut.md): Global keyboard shortcuts for the whole application, including sequences of two keys such as `g` then `m`.
## Icon library

- [Klar.Icon.Library](Klar.Icon.Library.md): The whole icon library in one place, for galleries, pickers and tests.
- [Klar.Icon.Arrows](Klar.Icon.Arrows.md): Arrows and movement: 20 icons.
- [Klar.Icon.Business](Klar.Icon.Business.md): Business and finance: 22 icons.
- [Klar.Icon.Calendar](Klar.Icon.Calendar.md): Calendar and time: 12 icons.
- [Klar.Icon.Communication](Klar.Icon.Communication.md): Communication: 20 icons.
- [Klar.Icon.Data](Klar.Icon.Data.md): Data and charts: 28 icons.
- [Klar.Icon.Developer](Klar.Icon.Developer.md): Developer tools: 16 icons.
- [Klar.Icon.Devices](Klar.Icon.Devices.md): Devices and hardware: 20 icons.
- [Klar.Icon.Documents](Klar.Icon.Documents.md): Files, folders and documents: 34 icons.
- [Klar.Icon.Editor](Klar.Icon.Editor.md): Text editing: 22 icons.
- [Klar.Icon.Interface](Klar.Icon.Interface.md): Interface and controls: 32 icons.
- [Klar.Icon.Logistics](Klar.Icon.Logistics.md): Logistics, transport and places: 26 icons.
- [Klar.Icon.Media](Klar.Icon.Media.md): Media and sound: 14 icons.
- [Klar.Icon.Nature](Klar.Icon.Nature.md): Nature, weather and animals: 16 icons.
- [Klar.Icon.People](Klar.Icon.People.md): People and expressions: 16 icons.
- [Klar.Icon.Science](Klar.Icon.Science.md): Science, health and everyday objects: 16 icons.
## AI

- [Klar.AiReview](Klar.AiReview.md): Review server-generated AI proposals one statement or change at a time, with evidence, exact before/after values, a reason and explicit approval or rejection.
- [Klar.AiChat](Klar.AiChat.md): A transport-neutral AI conversation with safe Markdown, streamed answers, explicit generation status and a composer that preserves newer drafts.
## Files and media

- [Klar.UploadQueue](Klar.UploadQueue.md): A local file-transfer workbench: validated file staging, an explicit add action, and an application-controlled queue with exact byte progress.
## Processes and state

- [Klar.Workflow](Klar.Workflow.md): Ordered workflow definitions shared by a builder, a runner and a server.
- [Klar.Workflow.Engine](Klar.Workflow.Engine.md): Pure, deterministic execution state for an ordered workflow.
- [Klar.Workflow.Codec](Klar.Workflow.Codec.md): Versioned JSON for workflow definitions, suitable for file exchange and APIs.
- [Klar.WorkflowNode](Klar.WorkflowNode.md): A compact, selectable workflow step with a kind, status and input/output ports.
- [Klar.WorkflowBuilder](Klar.WorkflowBuilder.md): A controlled, vertical workflow editor with a node palette, explicit branches, bounded return arrows and an inspector for the selected node.
- [Klar.WorkflowRun](Klar.WorkflowRun.md): Live execution diagram, context and attempt history for a workflow snapshot.
- [Klar.StateMachine](Klar.StateMachine.md): A small state machine diagram with enabled event buttons and explicit returns.
