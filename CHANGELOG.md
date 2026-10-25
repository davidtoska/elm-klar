# Changelog

Elm checks the version of every release against its public API (`elm bump`, `elm diff`):
adding is a minor release, changing or removing is a major one.

## Unreleased

### Complete component gallery
- Give every exposed module an address in the component gallery, including `Klar`, `Picking`, the icon index and all themed icon groups. Icon-group pages show the selected group's searchable icons.
- Restore the icon browser on the Icon page and add a working custom-control example for `Field`, whose page previously showed only an empty validation heading.
- Check the full exposed-module manifest against the gallery, and verify rendered examples rather than section headings. Include the completed Table and Chart module splits without changing their public APIs.

### Processes and state
- Add `Workflow`, `Workflow.Engine` and `Workflow.Codec`: validated ordered definitions, named bindings, per-node JSON state, bounded returns, deterministic execution and versioned definition exchange.
- Add `WorkflowNode`, `WorkflowBuilder`, `WorkflowRun` and `StateMachine`, each with a dedicated component page. The editor includes a node palette, role assignments, connection editing and keyboard-accessible reordering; the runner retains intermediate results and attempt history.
- Add a process studio with four templates and an Elm request/server simulator. Membership admission demonstrates interviews, coordinator recommendations, managing-director approval and registrar-only enrollment. Server checks gate human actions by session roles; cancellation and stale revisions reject late replies.

### Connected application examples
- Nine routed application screens cover Google/Microsoft/email sign-in, account creation, password recovery/reset, connected apps, GitHub repository access, Drive/Calendar imports, AI provider credentials and a simulated JEV classification queue with human review.
- A typed registry drives sidebar navigation, command search and the examples index. Copyable larger compositions use only public Klar components, with no new stylesheet or package API.
- Feature lifecycles clear credential drafts and ignore cancelled or late simulated responses. The application-pattern guide documents server boundaries and the JEV Choice request shape.

### AI workspace
- New `AiReview`: source excerpts, full before/after values, explanations, revision-bound approve/reject decisions, required rejection reasons and per-statement discussion slots. Stale data, duplicate ids and changed content cannot be submitted.
- New `AiChat`: role-labelled safe Markdown, server-driven streaming status, stop/retry actions, structured content slots and draft acknowledgements that preserve newer writing.
- A dedicated AI gallery demonstrates revision conflicts, failed writes, comments by revision, partial responses and cancellation tickets. Provider credentials and execution stay on the application's server.

Every group of modules was audited against the best in its class, improved, reviewed and fixed
on its own branch, with shared decisions: `ariaLabel` is a name only a screen reader hears and
`label` is visible text, a main value is `value` / `setValue`, remote data comes once as a
`Remote`, components take the application's own types, no `Msg` holds a function, a shown
shortcut is a `Shortcut.Keys`, Escape is layered, and `Klar.focus` is the one way to move focus.

### Core (shared internals and stylesheet)
- Every key handler built on the shared key decoder ignores the Enter or Escape that ends an input-method composition (`isComposing`, key code 229).
- Ids made from labels and keys no longer collide: two different texts give two different ids.
- The freshness wrapper keeps the same elements in every state, with a live region that is always there and the failure reason as text; `RemoteView` and `ListItem` use it.
- One reduced-motion list, a print block, a forced-colors focus outline for every element, option rows of 32 px at every density, and a warning amber that passes AA as text.
- Search highlights are no longer drawn as 8 px grey dots (`klar-mark` was defined twice).
- `check-classes` expands the size, tone and density suffixes; new `check:rules` (report only) lists a `Msg` or `State` that holds a function and every place that drops freshness.

#### Breaking
- Implicit DOM ids made from a label or key change their encoding: a space -> `__`, `_` -> `_5f_`, other characters -> `_<hex>_` (was `-`). Form ids keep `-` between the words of a label.
- `--klar-option-h` is 32 px at every density.

### Foundations (Klar, Settings, Locale, Theme, Color, Text, Layout, Card, Icon)
- Settings holds the language and the time now: `Settings.withLocale`, `locale`, `withNow`, `now`, `today`. `AppShell.settings` gives the shell its language; other components still take `locale` themselves.
- `Locale.fromCode` reads browser codes such as `en-US`, `nb-NO`, `no-NO` and `nn`.
- `Theme.name` speaks Norwegian; new `Theme.modes`, `modeName`, `modeKey`, `modeFromKey`; the System mode follows `prefers-contrast: more`.
- Warning text passes WCAG AA in every light theme; `ThemeTest` measures the colors on the page and fails on a missing one.
- New `Color.toRgb`, `Text.headingAt`, `Text.truncated`, `Layout.id`, `Layout.ariaLabel`, `Layout.scroll`, `Layout.columnSpan` (a grid inside a grid spans the outer columns) and `Layout.dividerVertical`.
- A Card with an id and a title is a named region; an empty subtitle draws no header. A blank `Icon.labelled` label is decorative; a multi-line `Icon.fromSvg` draws.
- `check-classes` fails when two stylesheet modules style the same bare class. AI.md's standard application keeps its rows on reload and no longer reports success on a failure.

#### Breaking
- `Locale.monthName` -> `Locale.monthLong`. `Theme.name : Theme -> String` -> `Theme.name : Locale -> Theme -> String`.
- `Settings.dateTime : Locale -> Settings -> Time.Posix -> String` -> `Settings.dateTime : Settings -> Time.Posix -> String`. `Text.link` removed -> `Link.view`.
- `Card.footer : Html msg -> Attribute msg` -> `Card.footer : List (Html msg) -> Attribute msg`.
- CSS: the color dot `klar-mark` -> `klar-dot`; `klar-icon--xs/sm/lg/xl/xxl` -> `klar-icon--size-12/14/20/24/32`; `--klar-amber-700` is `#7a4a04`.

### Actions (Button, Link, Menu, SplitButton, ToggleGroup, ButtonGroup, Kbd)
- Menu opens with the first item highlighted from Enter, Space or ArrowDown and the last from ArrowUp; a pointer click highlights nothing. It gained typeahead, group headings, a name from its button, `aria-controls`, `Menu.withShortcut` with `aria-keyshortcuts`, and `Menu.triggerId`.
- The open menu prevents the default of Escape, and of Enter and Space when they close it. Disabled ToggleGroup options, disabled SplitButtons and inactive link buttons keep focus.
- A disabled `Klar.Link` no longer reloads a `Browser.application`; new `Link.download`. Focus, pressed state and highlight show in Windows high contrast.
- ToggleGroup has `label`, `required` and `optionalText` like the other choice controls.

#### Breaking
- `Button.href : String -> Attribute msg` -> `Button.href : Link.Target -> Attribute msg`. `Button.iconOnly` shows its label as a Klar tooltip, not a native `title`.
- `ToggleGroup.single` / `multiple`: `{ label, selected, onChange }` -> `{ selected, onChange }` plus `ToggleGroup.label`; `ToggleGroup.Attribute` -> `ToggleGroup.Attribute msg`.
- `SplitButton.Attribute` -> `SplitButton.Attribute msg`; its main part has the id `<id>-main`. `Menu.open` highlights the first item; `Link.internal` keeps `./` and `../` paths.

### Feedback (Alert, Badge, Tag, EmptyState, ErrorState, Spinner, Skeleton, Progress, Avatar)
- AA contrast wherever text sits on color; avatar and chart colors are computed per theme and mode and tested in all ten themes, light and dark.
- `Tag.removeLabel`, a pure `Tag.nextFocus`, and Delete or Backspace on the remove button. `Alert.id`; the close button is named after the alert's title.
- `actions : List (Html msg)` on Alert, EmptyState and ErrorState; `ErrorState.headingLevel`, `ErrorState.polite`, `EmptyState.headingLevel`, `EmptyState.locale`.
- `Badge.max` (default 99) and `Badge.locale`; `Spinner.loading` keeps the live region in the page. Progress no longer shows 100% at 99.5.

#### Breaking
- `Badge.count : Int -> Html msg` -> `Badge.count : List Badge.Attribute -> Int -> Html msg`. `EmptyState.action : Html msg` -> `EmptyState.actions : List (Html msg)`.
- `Spinner.panel : String -> Html msg` -> `Spinner.panel : List Spinner.Attribute -> String -> Html msg`. `Skeleton.paragraph` removed -> `Skeleton.lines`.
- `Avatar.Status(..)` -> opaque `Avatar.Status` with `Avatar.online`, `away`, `busy`, `offline`. `Avatar.Entry` record -> opaque, with `Avatar.withImage : Maybe String -> Entry -> Entry`.
- CSS: `klar-state__action` -> `klar-state__actions`; `klar-spinner-idle` removed.

### Text inputs (TextInput, TextArea, TagInput, SearchInput, PasswordInput, NumberInput)
- TagInput: its messages hold data only; chips are not Tab stops (arrow keys between them, Backspace and Delete remove one); IME-safe delimiters; refused pieces of a paste stay.
- TextInput and TextArea share one counter that never cuts the text and marks it invalid past the limit. PasswordInput keeps its value in its State and warns about Caps Lock.
- NumberInput rounds as `Klar.Format` does, snaps to the step grid, reverts with Escape, reads a pasted unit and, in Norwegian, reads `10.000` as 10000.
- New `TextArea.onCtrlEnter`, `TextArea.autofocus`, `TextArea.verbatim`, `TextInput.verbatim`.

#### Breaking
- `TagInput.tags` / `setTags` -> `values` / `setValues`; `TagInput.addOnBlur : Bool` -> `keepDraftOnBlur`. `TextInput.password` removed -> `Klar.PasswordInput`; `TextInput.type_` removed.
- `TextArea.Resize(..)` and `TextArea.resize` -> `TextArea.noResize`.
- `SearchInput.shortcutHint : String` -> `SearchInput.shortcut : Shortcut.Keys`; `SearchInput.loading : Bool` -> `SearchInput.remote : Remote a`; `SearchInput.focus` removed; `SearchInput.text` / `setText` -> `value` / `setValue`.
- `PasswordInput.value : String -> Attribute` and `PasswordInput.onInput` -> `PasswordInput.value : State -> String`, `setValue`, `clear`.
- `NumberInput.reset` -> `clear`; `NumberInput.steppers : Bool` -> `NumberInput.noSteppers`.

### Choice inputs (Checkbox, CheckboxGroup, Radio, Switch, Slider, SegmentedControl)
- All six show checked, chosen, focus and invalid in Windows high contrast; Checkbox sizes draw. Radio, SegmentedControl and CheckboxGroup take the application's own value type.
- `readOnly` on all six: Tab still reaches the control and nothing changes it; with a handler, Checkbox, Switch and Slider keep their native input, so focus stays when it turns on or off.
- `Checkbox.errorMaybe`, `Checkbox.required`, `Switch.errorMaybe`; a saving Switch keeps focus. `Slider.onCommit`, `Slider.onRangeCommit`; range thumbs are named after the label.

#### Breaking
- `Radio`: `Option` -> `Option value`, `option : String -> String -> Option` -> `option : value -> String -> Option value`, `selected : Maybe String` -> `Maybe value`, `onSelect` -> `onChange`, `Attribute msg` -> `Attribute value msg`.
- `SegmentedControl`: the same, plus `selected : value`, `iconOnly` -> `iconOption`, and `ariaLabel` -> `label` with `labelHidden`.
- `CheckboxGroup`: `Option value`, `selected : List value`, `onChange : (List value -> msg)`. `Switch.onToggle` -> `onCheck`; `Switch.description` -> `hint`.

### Special inputs (InlineEdit, FileDrop, MoneyInput, MaskedInput, Money)
- InlineEdit: no function in its `Msg`; Alt+Tab no longer saves; a late answer never closes an open edit; a refused text can be corrected in place; new `edit` and `multiline`.
- FileDrop: keyed rows, paste, a disabled zone cancels drops and keeps focus, and `chosen` pairs each `FileInfo` with its `File`.
- Money: `totals`, `convert`, `toFloat`, JSON decoders and encoders.
- MaskedInput and MoneyInput share `text`, `problem` and `clear`; `MaskedInput.setMask`; new masks `ean13`, `swedishOrganisationNumber`, `danishCvrNumber`, `finnishBusinessId`.

#### Breaking
- `InlineEdit.label` -> `InlineEdit.ariaLabel`.
- `FileDrop.files` / `setFiles` -> `values` / `setValues`; `FileDrop.Problem(..)` -> opaque, with `problemText`, `isWrongType`, `isTooLarge`, `isTooMany`, `isDuplicate`.
- `MaskedInput.reset` / `MoneyInput.reset` -> `clear`; their `setValue` does nothing while the user types. `Money.convert` refuses a negative rate.

### Select (Select, MultiSelect, Autocomplete, VirtualList, Ids)
- Input-method keys never act on the list; Home and End move the caret once there is text; Tab reaches Try again of old data; Alt+ArrowDown and Alt+ArrowUp open and close.
- No function in `Msg`; forced colors for highlighted and selected rows. `Select.withMeta` (a value at the end of the row), `VirtualList.reveal`, `VirtualList.isDrawn`, `Ids.map`.
- Autocomplete has `remote`, `serverSearch`, `setOption`, `clear`, `open` and `close`.

#### Breaking
- `Select.setValue : id -> State id -> State id` -> `Select.setValue : Maybe id -> State id -> State id`.
- `Klar.Select.Option` is no longer exposed; the `Select.Option` record gained `meta : Maybe String`.
- Autocomplete: `State` -> `State id`, `Msg` -> `Msg id`, `Attribute msg` -> `Attribute id msg`, `picked : State -> Maybe String` -> `State id -> Maybe id`, `options : List (Option String)` -> `List (Option id)`, `suggestions` -> `remote`.
- `Ids.int` refuses keys that are not canonical (`007`, `+7`, `-0`).

### Picking (TreeSelect, Cascader, Transfer, Picking)
- Refreshing and old data at the top level and in lazy branches, with "Old data from 14:05" and a Try again that the keyboard reaches; focus survives a refresh; `settings` on all three.
- `loadRequests` names a lazy node once. Transfer's Chosen list can be rearranged. Cascader's ARIA tree reads in the right order; new `Picking.fromFlat` for parent-id rows.

#### Breaking
- `TreeSelect.init : Mode mode -> String` -> `TreeSelect.init : String -> Mode mode`. `TreeSelect.setValue : Ids id -> id` -> `TreeSelect.setValue : Ids id -> Maybe id`.
- `Picking.children` returns the `Remote` as given, `Kept` included. The Transfer init id is the id of its Available filter box (was `<id>-available-filter`).

### Tree
- The same element tree in every Remote state, so focus survives; Try again moves focus on purpose.
- `Tree.loadRequests` also names lazy nodes opened by `expand`, `setExpandedIds` and `expandAll`; a disabled branch stops the checkbox cascade.

#### Breaking
- `Tree.onReload` -> `Tree.onRetry`; `Tree.onRetry : (id -> msg)` -> `Tree.onRetryChildren`; `Tree.onLoadChildren` removed; `Tree.loadRequests : Ids id -> Msg -> List id` -> `Ids id -> State id -> List id`.
- `expanded` / `setExpanded` -> `expandedIds` / `setExpandedIds`; `selected` / `setSelected` -> `selectedIds` / `setSelectedIds`; `checked` / `setChecked` -> `checkedIds` / `setCheckedIds`.
- `Tree.withHint` -> `withDescription`; `Tree.emptyText` -> `emptyState`. `Tree.focusNode : Ids id -> State id -> id` -> `Tree.focusNode : Ids id -> id -> State id`.
- CSS `klar-tree__hint` -> `klar-tree__description`.

### Date (Date, DatePicker, DateRangePicker, TimePicker, DateTimePicker)
- No message holds a function; one field vocabulary for all four pickers.
- DateTimePicker: `date`, `time`, `setDate`, `setTime`, DST-correct `toPosix` and `fromPosix`, `toIso`, `fromIso`, `isOpen`, `open`, `close`, `alignEnd`, `name`.
- Klar.Date: `addYears`, `startOfWeek`, `endOfWeek`, `isoWeek`, `isoWeekYear`, `quarter`, `startOfQuarter`, `endOfQuarter`, `startOfYear`, `endOfYear`.
- DateRangePicker: This week, This quarter and Last quarter; quick choices are one tab stop.

#### Breaking
- DatePicker: `date` -> `value`, `setDate` -> `setValue`, `isInvalid` -> `isValid`, `validate` -> `setLimits`, `Attribute` -> `Attribute msg`.
- DateRangePicker: `range` -> `value`, `setRange` -> `setValue`, the same three, and the `Preset` record -> opaque `Preset`.
- TimePicker: `time` -> `value`, `setTime` -> `setValue`, the same three. DateTimePicker: `dateTime` -> `value`, `setDateTime` -> `setValue`, the same three.
- `Date.addDays`, `addMonths` and `fromEpochDay` stop at 1 January of year 1. CSS `klar-datepicker__button` -> `klar-timepicker__button` and `klar-daterange__button`.

### Calendar (Calendar, Recurrence, RecurrencePicker)
- Marks from a backend: `remote` and `onRetry`, the same grid in every state. `visibleRange` gives the days of every visible month; dates stay between years 1 and 9999.
- Escape steps out of the month and year choosers; selection changes are announced.
- Recurrence writes its problems in real Norwegian and reads rules that take their day from DTSTART; new `endsAfter`, `endsOn`, `lastOccurrence`. RecurrencePicker has `isValid`.

#### Breaking
- `Calendar.label` -> `ariaLabel`; `Calendar.selected` / `select` -> `value` / `setValue`. `Calendar.updateWithEvent` and `Calendar.Event(..)` removed.
- `Calendar.months` attribute -> `Calendar.setMonths : Int -> State -> State`; `Calendar.today` attribute -> `Calendar.setToday : Date -> State -> State`.
- `Calendar.Attribute` -> `Attribute msg`; `min` and `max` default to 0001-01-01 and 9999-12-31. `RecurrencePicker.setRule` -> `setValue`; `RecurrencePicker.Attribute` -> `Attribute msg`.
- `Recurrence.fromRRule : String` -> `Recurrence.fromRRule : { start : Date } -> String`.

### Forms (Form, Form.Spec, Form.Layout, Field, Validate)
- New kinds: `Spec.date`, `Spec.dateRange`, `Spec.money`, `Spec.masked`, with `Form.datePicker`, `dateRangePicker`, `moneyInput`, `maskedInput`, `radio` and `checkbox`.
- `Spec.minDate`, `maxDate`, `minMoney`, `maxMoney`, checked by the form and given to the controls.
- Conditional fields (`Spec.shownWhen`, `Spec.requiredWhen`) and cross-field `Spec.checkFields`. `Form.query` and `Form.setOption` for a select with server search; `Form.domId`.
- A field's control is never rebuilt when its first error comes; a typed field shows a rule's problem once it is left.
- A hidden field is empty for every reader (its own rules, other conditions, `checkFields`, the values); new `Form.Check.failingWhenHidden`. `Form.Layout.status` keeps one live line in every state.

#### Breaking
- `Field.viewStable` removed -> `Field.view`, which always wraps. `Validate.Error` -> `Validate.Problem`; lengths count code points of the trimmed text.
- `Form.Layout.focusField` removed -> `Klar.focus`. A blank error or hint (`Just ""`) counts as none.

### Table
- The CSV export is built when chosen and saved with `File.Download` (no size limit). A table whose rows expand is a treegrid; forced colors for focused, selected and current rows.
- New `Table.money` (exact sums, one total per currency), `Table.currentRow`, `Table.filterValue`. Shift ranges, Ctrl or Cmd+A, and an announced selection count.

#### Breaking
- `Table.rows` -> `remote`; `Table.preparedRows` -> `remotePrepared`; `Table.label` -> `ariaLabel`.
- `Table.setExpanded` removed -> `expand`, `collapse`, `toggle`, `setExpandedIds`, `collapseAll`. `Table.setSelected` removed -> `select`, `deselect`, `setSelectedIds`.
- `Table.filterOptions : List String` -> `List { value : String, label : String }`. `selectable` and `expandedRow` draw nothing without `rowId`.

### Server lists (ServerList, SavedViews, Search, Format)
- ServerList needs no `Time.now`; new `mapRows`, `setRule`, `toQueryString`, `fromQueryString`. SavedViews has `remote` and `onRetry`, backend keys, `changes` and locked team views.
- Search tries every start of a letters-in-order match; new `Search.filterBy`. Format: `decimalUpTo`, `abbreviated`, `signed`; Norwegian "1. mai" without a stray point.

#### Breaking
- `ServerList.gotPage : Request -> Result Problem (Page row) -> Time.Posix -> Msg row` -> `gotPage : Request -> Result Problem (Page row) -> Msg row`.
- `ServerList.mapTable` returns a `Step id row` (was a `State id row`). `SavedViews.current` -> `currentRule`; `SavedView` gained `key` and `isLocked`.
- CSS: the search highlight `klar-mark` -> `klar-highlight`.

### Rules (Rule, RuleBuilder, FilterBar)
- `Rule.matches` reads the fields once per rule; new `Rule.settled` and `Rule.fieldChoices`. New operators `NotBetween`, `MoreThanDaysAgo`, `MoreThanDaysAhead`, `InPeriod`.
- RuleBuilder works as a form field (`label`, `hint`, `error`, `required`). FilterBar: undo for Clear all, Ctrl or Cmd+Enter applies, one tab stop for the chips.

#### Breaking
- `Rule.FieldKind(..)` -> opaque, built with `textKind`, `numberKind`, `dateKind`, `booleanKind`, `choiceKind`.
- `Rule.Equals` / `NotEquals` removed -> `Is` / `IsNot`; `Rule.Issue` -> `Rule.Problem`. `RuleBuilder.label` -> `ariaLabel` (`label` is now visible); `FilterBar.label` -> `ariaLabel`.
- `matchCount : Maybe Int` -> `matchCount : Remote Int` in RuleBuilder and FilterBar; `counting` removed.
- `FilterBar.close : State -> State` -> `FilterBar.close : State -> ( State, Cmd Msg )`.

### Data display (Chart, Stat, Timeline, JsonViewer)
- Data comes once, as a `Remote`; `Chart.onSelect` makes categories reachable by keyboard. JsonViewer is an ARIA tree with one tab stop; new `path`, `expand`, `collapse`, `expandedIds`.
- Timeline: `loadMore`, `total`, `withHref`, `withOnClick`. Stat: `deltaBy`, `deltaPoints`.

#### Breaking
- `Chart.size` -> `width`; `points : Bool` -> `pointsOnHover`; `legend : Bool` -> `legend` and `hideLegend`; `includeZero : Bool` -> the flag `includeZero`.
- `Chart.loading`, `failed`, `remote` removed -> `lineRemote`, `barRemote` (both take `Chart.Data` from `byCategory` or `byDate`), `donutRemote`, `gaugeRemote`, `meterRemote`, `sparklineRemote`.
- `Stat.compact` -> `abbreviated`; `Stat.loading` and `failed` removed -> `Stat.remote`.
- `Timeline.loading`, `failed`, `remote` removed -> `Timeline.viewRemote`; `onLoadMore`, `loadingMore`, `moreFailed`, `hasMore` -> `Timeline.loadMore : msg -> Remote Bool -> Attribute msg`.
- `JsonViewer.Attribute` -> `Attribute msg`; `JsonViewer.setExpanded` -> `setExpandedIds`.

### Structure (ListItem, Accordion, Sortable, Splitter, Toolbar, DescriptionList)
- ListItem rows are keyed and keep focus through a refresh; new `keyedList` and `listId`. Accordion keeps closed bodies as `hidden="until-found"`, so find-in-page opens them.
- `Sortable.moveButtons` (WCAG 2.5.7); `Splitter.fold`, `unfold`, `isFolded`, `separatorId`; `Toolbar.size`.

#### Breaking
- `ListItem.remote` -> `ListItem.viewRemote : List (ListAttribute msg) -> Remote (List ( String, Html msg )) -> Html msg`.
- `ListItem.listLabel` -> `ariaLabel`; `ListItem.label` -> `rowAriaLabel`; `compact` -> `density`; `emptyTitle`, `emptyDescription`, `emptyIcon` -> `emptyState`.
- Accordion: `State` -> `State key`, `Section msg` -> `Section key msg`, `section` takes `Ids key -> key`, `view` takes the sections, `multiple` removed (`setMultiple`), `isOpen` -> `isExpanded`, `openKeys` -> `expandedIds`, `open` -> `expand`, `close` -> `collapse`, `closeAll` -> `collapseAll`, `openMany` -> `setExpandedIds`.
- Sortable: `view : Ids id -> (Msg -> msg)` -> `view : (Msg -> msg)`, `item : id` -> `item : Ids id -> id`, `Attribute` -> `Attribute msg`, `move` removed -> `moveButtons`.
- `Splitter.Attribute` -> `Attribute msg`; `DescriptionList.compact` -> `density`.

### Navigation (AppShell, Tabs, Breadcrumbs, Pagination, SideNav, Stepper)
- AppShell remembers the address: a click on the current page replaces the history entry, a `#id` link focuses its element, only a link to a new page moves focus to the content, and `pageTitle` announces each new page. New `follow`, `isSidebarCollapsed`, `setSidebarCollapsed`, `isDrawerOpen`, `closeDrawer`.
- Tabs draws the strip and the active panel from one `view` (`Tabs.withPanel`). Breadcrumbs gets button crumbs; Pagination keeps focus while disabled and announces paging.

#### Breaking
- `AppShell.init : { id, key }` -> `AppShell.init : { id, key, url }`.
- Tabs: `State` -> `State key`, `Tab` -> `Tab key msg`, `Attribute` -> `Attribute key msg`, `init : String -> key -> State key`; `panel`, `panels`, `resolve`, `withoutPanels` removed -> `withPanel`.
- `Breadcrumbs.link : String -> String -> Crumb` -> `link : { label : String, href : String } -> Crumb msg`; `Breadcrumbs.static` -> `viewStatic`.
- `Pagination.label` -> `ariaLabel`; `Stepper.onSelect` is linear by default (`Stepper.nonLinear`).

### Overlays (Modal, Drawer, ConfirmDialog, Popover, Toast, Tooltip, Overlay)
- Escape is layered and IME-safe; focus that falls to the body comes back in every surface. The toast stack is keyed, F6 reaches its Undo (`Toast.focus`), and a removed toast hands focus on.
- Shift+Tab in a dialog reaches the footer; ConfirmDialog is an `alertdialog`.

#### Breaking
- `Modal.view`, `Drawer.view` take the title, `ConfirmDialog.view` the question and `Popover.view` the label as a required `String`; `Modal.title`, `Drawer.title`, `ConfirmDialog.title`, `Popover.label` and `Popover.ariaLabel` removed.
- `Modal.openWith`, `Drawer.openWith`, `Popover.openFocusing` and `Popover.initialFocus` -> `setInitialFocus` on all three. `Modal.Side(..)` and `Modal.side` removed -> `Klar.Drawer`.
- `ConfirmDialog.neutral` / `warning` / `danger` and `Toast.info` / `success` / `warning` / `danger` -> `tone`.
- `Toast.init : State msg` -> `Toast.init : String -> State msg`; `Toast.maxVisible` -> `setMaxVisible`.
- `Tooltip.attrs : String` -> `attrs : List Option -> String`; `attrsWith`, `withShortcut`, `placeBelow` removed; `Tooltip.shortcut : String` -> `Shortcut.Keys`; `Tooltip.wrap` takes a function of the `aria-describedby` attributes.

### Commands (Shortcut, CommandPalette, ContextMenu, ShortcutHelp)
- Shortcut ignores keys a component handled, keys of an input method and keys in open popups; it finds Ctrl, Alt and Cmd letters by key position (Russian, Greek, AZERTY, Mac Option). New `Shortcut.conflicts` and `Shortcut.repeats`.
- CommandPalette waits 300 ms on its query itself, keeps focus in its search box, shows old data, and has `withDisabled` and `platform`.
- ContextMenu keeps the browser's menu in text fields and on Shift+right-click; new `openFor`. ShortcutHelp has group headings, spoken key names, a match count and `extra`.

#### Breaking
- `Shortcut.keycaps` removed (keys are shown through `Klar.Kbd`).
- `CommandPalette.noResults` -> `emptyText`; the section's `emptyText` -> `withEmptyText`; `CommandPalette.label` -> `ariaLabel`; `withKeywords` adds instead of replacing.
- `ContextMenu.view toMsg itemsFor state` -> `ContextMenu.view toMsg attributes itemsFor state`.

### Flow (Remote, RemoteView, LeaveGuard, StatusPage, BulkBar, History)
- RemoteView draws one element in every state, so focus survives a refresh; `RemoteView.emptyState`. `Remote.settle` (no time needed), `Remote.map2` and the kind `tooManyRequests`.
- LeaveGuard gives a decision after Back too, `follow` performs it, and an address of the page that is shown (a sort in the query) is applied without a question.
- StatusPage: `retrying`, `backAt`, `settings`. BulkBar: `itemName`. History: `markSavedAs`, `movedAt`.

#### Breaking
- `RemoteView.view` always returns one `div.klar-remote-body`, also for fresh data.
- StatusPage: `denied` -> `forbidden`, `sessionExpired` -> `unauthorized`, `serverError` -> `server`, `offline` -> `network`, `notFound` -> `pageNotFound`.
- `StatusPage.focusTitle` and `BulkBar.focus` removed -> `Klar.focus`.
- `LeaveGuard.onUrlChange` returns `( Guard source target, Cmd Msg, Change target )` (was a `Maybe target`); `LeaveGuard.initAt` takes `(Url -> target)` and the `Url`; `LeaveGuard.Attribute` -> `Attribute msg`.
- `History.Attribute` -> `Attribute msg`; `History.shortcuts : Locale` -> `shortcuts : List (Attribute msg)`.

### Access (PermissionMatrix, ApprovalFlow)
- Both draw every Remote state, with "Old data from 14:05" and a retry, and a focusable root. An arrow key in a 200 x 25 matrix went from about 135-150 ms to about 55-63 ms (lazy cells).
- `PermissionMatrix.unsavedChanges` and `settings`; `ApprovalFlow.deciding`, `headingLevel` and the quorum `atLeast`.

#### Breaking
- ApprovalFlow's root is a `div` with `role="group"` (was a `section`); step titles are `h3`.

### Text change (Compare, Diff, Markdown, MarkdownEditor)
- Compare shows refreshing and old data, and gets `viewRemote`, `onBaseline`, `id`, `settings`.
- Diff no longer shows the new text in the old column when it ignores white space or case; new `Diff.currentHunk` and `Diff.goToHunk`.
- Markdown links to its own headings reach them, character references are decoded, and new `Markdown.customLink` and `customCodeBlock` draw links and code blocks.
- MarkdownEditor announces its limit once, and its shortcuts work on non-Latin layouts.

#### Breaking
- `Compare.view` takes `{ ariaLabel, ids, id, header, fields }` and a `List record` (was a record with `label`, `records`, `toKey`); `Compare.refreshing` removed -> `Compare.viewRemote`.
- `Compare.onlyDifferences : Bool -> (Bool -> msg)` -> `onlyDifferences : Bool` and `onOnlyDifferences`. `Diff.Attribute` -> `Attribute msg`; `Markdown.Attribute` -> `Attribute msg`.

## 1.0.0

Added `Kanban` with version-checked moves and WIP limits, `CommentThread` with
safe Markdown replies and acknowledgements that preserve newer drafts,
`UploadQueue` with validated staging and honest byte progress, `CodeBlock` with
exact source/download and bounded JSON/Elm highlighting, and `QuantityInput` with
typed units and unchanged raw input. The Workflow toolkit gallery exercises their
edge cases. No new dependencies, ports, JavaScript or network layer were added.

Added five workbench components: `CardList` with page-safe selection, `WorkQueue`
with keyboard navigation and a detail pane, `AuditLog` with expandable diffs,
`ConflictResolver` with exact three-way merging and version-bound decisions, and
`NotificationCenter` with explicit read/dismiss actions. All handle every `Remote`
state and English/Norwegian text, use the existing theme tokens and add no dependencies.
The gallery and standalone `ReviewDesk` example demonstrate them together.

The first release: more than a hundred components for data-intensive applications in plain
Elm, with built-in text in English and Norwegian Bokmål, ten themes with a light and a dark
mode, and 500 icons as Elm values.
