# The twelve tasks

Fixed. Domain-neutral: orders, customers, products, warehouses. A task is stated the way a
user would state it; the builder decides which Klar modules to use and writes its own dummy
backend in Elm (synchronous functions, answered after a short `Process.sleep`, one of them
failing on purpose where a task says so). A task passes only when **every** acceptance line is
true in a browser, not when it compiles.

Common to all tasks (the builder is told once, see [run.md](run.md)):

- One `Browser.application` or `Browser.element` per task, in its own folder.
- Every request can be slow or fail: loading, failure with retry and empty are visible, never a
  blank screen.
- The keyboard reaches everything; focus is never lost to `body` after an action.
- The page passes axe-core (wcag2a, wcag2aa, wcag21aa, wcag22aa, best-practice) in every state
  listed in the task.

Each task lists, for the person who scores, the **reference modules**. The builder is not given
this list: finding the right module is part of what is measured.

## T01. Order list with filters

*As a dispatcher I want to find orders fast.* A list of 200 orders (number, customer, status,
date, total) from a backend that pages, sorts and filters on the server.

Acceptance:

1. 25 rows per page; the footer says "1 to 25 of N" and paging works.
2. Search by free text, sort by any column, and filter by status (several), customer (text) and
   date range. Changing any of them goes back to page 1.
3. Active filters are visible as chips that can be edited and removed; "Clear all" works.
4. A slow answer shows loading; a failed answer shows the problem with a retry button; no match
   says "no matches" and offers to clear the filters; an empty backend says "no orders".
5. An answer to an old query never replaces the answer to the newer one (type fast, then check).

Reference modules: `Table` (server mode), `FilterBar`, `Rule`, `Remote`, `Date`. Recipe: inbox.

## T02. Edit form with server errors

*As a clerk I want to correct a customer record.* Name, email, country, credit limit (a number
from 0 to 100 000), "active" switch.

Acceptance:

1. The form opens with the saved values; while loading it shows a skeleton, on failure a retry.
2. Required and range rules show next to the field only after the field was touched or the
   user pressed Save; a summary lists all problems and moves focus to the first.
3. Save disables the button and says "Saving"; the backend rejects the email `taken@example.com`
   with a message for that field and the name `Crash` with a general failure. The field message
   appears under the field and in the summary; the general failure has a retry; what the user
   typed is kept.
4. A saved form shows a toast and is no longer "unsaved"; a changed form shows that it has
   unsaved changes and can be reverted.

Reference modules: `Form`, `Form.Spec`, `Form.Layout`, `Validate`, `Remote`, `Toast`. Recipe: edit-form.

## T03. Dashboard

*As a manager I want the numbers of the week.* Four figures with change against the last period,
a line chart of orders per day, a donut of orders per status, a list of the last ten events, and
a period choice (7, 30, 90 days).

Acceptance:

1. Each panel loads and fails on its own; one failing panel (the events list, on its first
   request) does not blank the others and has its own retry.
2. Changing the period reloads every panel; an answer for the old period is never shown.
3. Numbers are written with the separators of the language; changing the language to
   Norwegian Bokmål changes the built-in texts and the number format.
4. Charts have a text alternative, and the page passes axe with all panels loaded and with one
   panel failed.
5. The heading order is correct (one `h1`, panels below it).

Reference modules: `Stat`, `Chart`, `Timeline`, `SegmentedControl`, `Remote`, `Locale`. Recipe: dashboard.

## T04. Rule builder

*As an analyst I want to define which orders count as "high risk".* A rule over order fields:
status (one of), total (greater than, between), customer country (is, is not), created date
(in the last N days), combined with AND / OR groups to any depth.

Acceptance:

1. Conditions and groups can be added, removed, moved and changed with mouse and keyboard.
2. A sentence in words describes the rule and updates as it is built; an incomplete condition
   says what is missing and is not applied.
3. "Test" runs the rule against 500 local orders and shows "37 of 500 match" and the first rows.
4. The rule is saved as JSON text and loaded back to an identical rule; a corrupted text is
   refused with a clear message and the old rule is kept.
5. The choices of status and country are the application's own types, not strings.

Reference modules: `Rule`, `RuleBuilder`, `Select.Option`, `Date`. No recipe.

## T05. Multi-step flow

*As a buyer I want to register a supplier in three steps.* Company (name, tax number), delivery
(country, lead time in days, contacts), review.

Acceptance:

1. The steps are routes; a step the user has not reached cannot be opened; Back and Next keep
   what was typed.
2. Next validates the current step, shows its problems and stops; the step list marks a step
   with problems.
3. The review lists every value with a way to go back to the step it came from.
4. Submit can fail (company `Crash`): the failure keeps everything and offers a retry; a
   problem the server ties to a field (tax number `000`) is shown at that field, on its step.
5. Success shows a confirmation page; no step can be re-entered with old values afterwards.

Reference modules: `Form` (its steps and `Form.stepper`), `Form.Spec`, `Form.Layout`, `DescriptionList`, `Remote`. Recipe: multi-step.

## T06. Command palette

*As an operator I want to jump to things from the keyboard.* `Ctrl K` opens a palette with
actions ("New order", "Go to customers", "Toggle language") and a section "Go to order ..." that
asks the backend as the user types.

Acceptance:

1. `Ctrl K` opens, `Escape` closes, and focus returns to where it was; opening and closing never
   leaves focus on `body`.
2. Typing filters the actions at once and asks the backend after a short pause; the section
   shows a skeleton while it asks, a failure with retry (query `fail`), and "no results".
3. The words of the command ("go to order") are not sent to the backend; only the number is.
4. An answer to an old query is never shown; reopening the palette clears the section.
5. `Enter` runs the highlighted item; the arrow keys move without a mouse; a screen reader hears
   the number of results.

Reference modules: `CommandPalette`, `Shortcut`, `Overlay`, `Remote`. Recipe: command-palette.

## T07. Table with 50 000 rows

*As an analyst I want to look through all stock movements.* 50 000 rows, 7 columns (id, product,
warehouse, type, quantity, value, date), all in the browser.

Acceptance:

1. Search (typing), sort (click) and page change each respond in under 150 ms in Chrome with
   software rendering, measured with the performance timeline, including two animation frames.
2. Scrolling is smooth, either through pages or through a scrolling list that draws only the
   rows in view; the number of DOM rows stays under 200.
3. The footer shows the sum of quantity and value for the filtered rows; "200 of 50 000" style
   counts are honest about what is cut off.
4. Select several rows, select all matching, and see the count; the selection survives sorting.
5. CSV export of the selection works and the file has the rows that were selected.

Reference modules: `Table` (`prepareRows`, `virtual`), `Format`, `Remote`. No recipe.

## T08. Drawer with confirm and toast

*As a clerk I want to look at an order and cancel it.* Click a row: a drawer shows the order
(lines, customer, status); "Cancel order" asks for confirmation; the cancel can fail.

Acceptance:

1. The drawer loads the order (skeleton, failure with retry); opening it from the keyboard and
   closing it returns focus to the row's button.
2. "Cancel order" opens a confirmation that says what will happen; `Enter` on the dialog's
   opening does not confirm; while the request runs nothing can close the dialog.
3. The first request fails on purpose: the problem is shown inside the dialog with "Try again";
   the second succeeds.
4. A success closes the dialog, updates the status in the drawer and the list, and shows a toast
   with an Undo that works; the toast does not hide the confirm button and can be reached with
   `Tab` while the dialog is open.
5. With the drawer and the confirmation open, the page behind is inert and axe is clean.

Reference modules: `Drawer`, `ConfirmDialog`, `Toast`, `Overlay`, `Table`, `Remote`. Recipe: confirm-delete.

## T09. Saved views

*As a dispatcher I want to keep my filters.* On the list of T01: save the current filter as a
named view, apply, rename, delete, mark one as the default.

Acceptance:

1. Saving asks for a name, refuses an empty name and a name that exists, and selects the new
   view; applying a view changes the list and the chips at once.
2. A view remembers the filter and, when the application stores it, the search text and sort;
   what a view does not remember is stated in the interface.
3. The views survive a reload (the application stores them as JSON text in its own backend
   function); a corrupted stored view is skipped with a message and does not break the list.
4. The default view is applied when the page opens; "reset" returns to no filter.
5. Everything works with the keyboard; the list of views is a menu the screen reader can name.

Reference modules: `SavedViews`, `FilterBar`, `Rule`, `Table`. Recipe: inbox.

## T10. Timeline with load more

*As a support agent I want to read the history of an order.* A timeline of events, newest first,
20 at a time, from a backend that has 87 events.

Acceptance:

1. The first 20 load with a skeleton; the header says "20 of 87".
2. "Load more" fetches the next 20 and keeps the focus where the user was; at the end the
   button is gone and the count says "87 of 87".
3. A failed "load more" keeps the events already shown, shows the problem with a retry at the
   end of the list, and a second click retries only that page.
4. Each event has a time written for people ("3 min ago" for recent ones, a date for old
   ones), an actor and a tone; an event can be expanded to show its raw JSON.
5. A new event pushed by a refresh appears on top without moving what the user reads.

Reference modules: `Timeline`, `JsonViewer`, `Format`, `Remote`, `Avatar`. No recipe.

## T11. Tree filter

*As a warehouse planner I want to see stock for a place.* A tree of regions, warehouses and
zones (about 300 nodes, branches load their children when opened) next to a list that follows
the selection.

Acceptance:

1. Selecting a node filters the list to that node and everything below it; with no node
   selected the list shows everything, and a selected node can be cleared (by a click or a
   button).
2. A filter box above the tree finds nodes by name, opens the path to each and says how many
   match; clearing it restores the earlier open state.
3. Opening a branch that has not loaded shows a loading row, a failed load shows a retry in
   place and does not close the branch.
4. The keyboard model of a tree works (arrows, Home, End, type to find, Enter to select) with a
   single tab stop.
5. The node ids are the application's own type end to end.

Reference modules: `Tree` (`lazy`, with a `Klar.Ids`), `Remote`, `Table`. Partly in the dashboard recipe.

## T12. Leave guard

*As a clerk I do not want to lose what I typed.* A form with five fields and three pages
(Orders, Customers, Settings); the form is on Settings.

Acceptance:

1. With unsaved input, clicking another page asks "Leave without saving?" with Stay and Leave;
   Stay keeps the input and returns focus to the link that was clicked; Leave goes there.
2. With a clean form, navigation is not interrupted.
3. "Save and leave" is offered when the save can run first; if the save fails the user stays
   and sees why.
4. The browser's Back button during unsaved input does not lose the input and does not freeze
   the tab (it may leave the question out and keep the input).
5. Closing the tab is not guarded (Klar says it cannot be); the interface does not claim it is.

Reference modules: `LeaveGuard`, `Form`, `Form.Spec`, `Modal` or `ConfirmDialog`, `AppShell`. Recipe: multi-step.
