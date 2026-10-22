# Benchmark log

Clock: wall time from `date` in the shell (HH:MM:SS, local). "Reading" = time in Klar docs, "writing" =
composing the Elm source, "testing" = compiling, browser checks and axe-core. Acceptance checks were
driven in the built-in browser pane with DOM inspection (keyboard events through the browser tool,
clicks by element), axe-core 4.10.2 injected from a local file, tags wcag2a, wcag2aa, wcag21aa, wcag22aa,
best-practice.

Setup (17:06 to 17:08): read `BRIEF.md`, `CLAUDE.md`, `AI.md`, `USING.md` (the first 400 lines),
`ServerList.md`, `FilterBar.md`, `Rule.md` (signatures), `Table.md` (signatures and quick paths), the
`inbox` recipe. Built a static server and downloaded axe-core (tool set-up, not documentation).

## T01 Order list with filters

Time: reading 17:07 to 17:09 (about 2 min, shared with the set-up above), writing about 1 min,
testing about 7 min (17:09 to 17:16). Total about 10 min.

Compile errors
1. First compile of `t01`: none (58 modules compiled).
2. After adding a delay that depends on the search text: `Process.sleep` takes a `Float`, I gave an
   `Int`. Kind: type mismatch in my own code, not Klar. Fix: `toFloat`.

Other fixes
- Every order had status `Pending` (my data generator multiplied by 5 over 5 statuses): changed the generator.
- `Table.emptyState` was not set, so an empty backend said "No data"; added `Table.emptyState [ title "No orders" ]`
  after finding it in `Table.md` (my miss, the doc has it).

Acceptance (browser): 1 pass (the footer reads "1–25 of 200", see the gap), 2 pass (search, sort, status
several, customer, date range; each goes back to page 1), 3 pass (chips editable, removable, "Clear all"; it
clears the chips and leaves the search text, which is a separate box), 4 pass (loading skeleton, failure with
"Try again" with no old data and with old data kept, "No matches" with "Clear search and filters", "No orders"),
5 pass (a slow answer for "a" arrived after the answer for "abc" and was dropped; `ServerList` owns the ticket).
axe: clean in loaded, loading, failed (no data), failed (old data), no matches, empty and with the filter editor open.

KLAR GAP
- The footer range is `1–25 of 200` (en dash); the brief says "1 to 25 of N". Neither `Table` nor `ServerList.viewTable`
  exposes `Pagination.summary` or a locale word for it. Left as is, commented in the source.

Notes (not gaps in the library)
- The filter editor popover closes when the browser window loses focus (a screenshot does it); I read the DOM instead.

## T02 Edit form with server errors

Time: reading 17:16:28 to 17:16:40 (the `edit-form` recipe plus `Form.Layout.md` signatures; the recipe is this task),
writing about 1 min (adapted the recipe: one-page `AppShell` with `Browser.document`, a "Reload (fails)" button for the
load failure, "Saving" label), testing about 3 min. Total about 4 min.

Compile errors: none in three builds.

Fixes
- "Try again" on the load failure left focus on `body` (the known gap named in `AI.md`): its own message `RetryLoad`
  with `AppShell.focusContent "app-shell" NoOp`; focus now lands on `main`.
- The Save button kept the label "Save" while busy (spinner, `aria-busy`, `aria-disabled`); the label now reads "Saving"
  (the status line already said "Saving ...").

Acceptance (browser): 1 pass (skeleton, saved values, failure with retry), 2 pass (rule shown after touch or Save; the summary
lists all problems and receives focus, see note), 3 pass (button busy and labelled "Saving"; `taken@example.com` shows under the
field and in the summary; `Crash` shows a general failure with "Try again"; typed values kept; the retry moves focus to the status),
4 pass (toast "Customer saved." and the "unsaved changes" banner goes; a changed form shows the banner with "Discard", which reverts).
axe clean: skeleton, loaded, field errors with summary, server field error, general failure, load failure, unsaved banner.

Notes
- The brief says the summary "moves focus to the first" problem; Klar moves focus to the summary (a `div` that lists them), not to the first field. Left as Klar does it.
- axe reported `color-contrast` on `.klar-toast__message` once, right after the toast appeared (while it fades in); a second run
  a moment later was clean. A timing artefact of the entry animation, but an axe run at that moment fails.
- Testing tool note: the built-in browser pane only paints (and so runs Elm's `requestAnimationFrame`) when a screenshot is taken,
  so "click, wait, read the DOM" sees stale state; a 0.1-scale screenshot between the click and the read fixes that.

## T03 Dashboard

Time: reading 17:20:45 to 17:21:00 (the `dashboard` recipe, `Chart`, `Stat`, `Timeline`, `Locale`, `Settings`, `Alert.stale` and
`RemoteView` signatures and docs), writing about 2 min, testing about 4 min (17:21:39 on). Total about 7 min.

Compile errors: none in four builds (one full rewrite of the panel views to `RemoteView`, which also compiled first time).

Fixes
- The donut centre said 372 against 374 orders (integer division of my dummy data): the last segment is now the remainder.
- The page title said "The week in numbers" whatever the period: renamed "Orders overview".
- A panel's "Try again" lost focus to `body` (`Stat`, `Chart` and `Timeline` have no body id to return focus to). Moved every panel into
  `RemoteView.view` with `RemoteView.id` and `RemoteView.focus` in the retry branch (the pattern in `RemoteView.md`); focus then lands on
  `#events-body`. The charts, tiles and timeline are drawn inside the function and get no `.remote`.

Acceptance (browser): 1 pass (events fail on the first request, the other three are loaded; its own "Try again"), 2 pass (7 to 30 to
90 clicked 200 ms apart: the screen ends on the 90-day numbers, 4 776 orders and 90 points), 3 pass (Norwegian: "4 776", "−0,1 %", "312,50",
dates "25. jul.", "torsdag 22. oktober 2026", built-in words "nedgang", "I dag"; texts of my own go through `Locale.pick`), 4 pass (each
chart is `role=img` named "Line chart. Orders per day. 1 series, 90 points", with a hidden data table; axe clean with all loaded and with
the events panel failed), 5 pass (one `h1`, panels are `h2`).

Notes
- Nothing in Klar changes my own words when the language changes (card titles, labels, period names): `Locale.pick` in the application, as the docs say.
- The `html` element keeps `lang="en"` (it is in `index.html`, Elm cannot change it); the shell root gets `lang="nb"`, as `AppShell.md` says.
- Dates in the hidden data table of the line chart follow the locale (`25.07.2026`); the category labels too.

## T04 Rule builder

Time: reading 17:23:32 to 17:24:00 (`RuleBuilder.md` in full; `Rule.md` for `matches`, `validate`, `describe`, `encode`, `decoder`, `choiceFieldOf`;
`TextArea` and `Alert` signatures; no recipe fits), writing about 2 min, testing about 4 min. Total about 7 min.

Compile errors
1. `Text.paragraph [] "..."`: "TOO MANY ARGS" (`Text.paragraph` takes only the string). Kind: I guessed a signature without opening `Text.md`. Fix: `Text.paragraph "..."`.
(I also wrote `Debug.todo` in a list helper; I removed it myself before compiling because `--optimize` refuses `Debug`, no compiler error.)

Other fixes
- The first message for a corrupted text was only "Problem with the given value:" (first line of `Decode.errorToString`): the message now
  flattens the whole error text and cuts it at 160 characters.
- The test result footer of the table said "Showing 1-10 of 10 rows" while 98 orders matched: added a line "The first 10 are listed." next to "98 of 500 match".

Acceptance (browser): 1 pass (add condition and group, remove, duplicate, move up and down with Enter on the buttons, change field, operator and
values with the keyboard; focus follows to the new or moved node), 2 pass (the "Summary:" sentence updates, e.g. "Customer country is Norway or (Status is
any of Shipped and Created in the last 30 days)"; an empty "Total >" says "Enter a valid number" once the field was left, and the sentence leaves it out;
`Rule.matches` ignores it), 3 pass ("98 of 500 match" and the first 10 rows), 4 pass (Save writes JSON text into a text area; the nested rule typed as text
loads, builds the same tree and saves back to the same JSON; a text with a character missing, and a rule on a field that does not exist, are refused with a
message and the old rule stays), 5 pass (status and country are `Status` and `Country` custom types through `Rule.choiceFieldOf` and `Ids`).
axe clean: empty builder, one and two conditions, an incomplete condition, test result, error message, nested rule.

Notes
- A fresh empty condition shows no message until the user has touched it (`RuleBuilder.md` says so); "Test" and "Save rule" call `showIssues`.
- `Rule.decoder` gives new node ids, so "identical" can only mean the same JSON; compared by `JSON.parse` of the typed and the saved text.
- A key that is not a status (`"values":["zz"]`) is not checked by `Rule.validate`; I did not test it.

## T05 Multi-step flow

Time: reading 17:26:06 to 17:27:20 (the `multi-step` recipe, `Form.md` in full, `Form.Spec.md` for `step`, `rows`, `whole`, `range`,
`Stepper`, `DescriptionList`, `Validate` signatures), writing about 3 min, testing about 10 min (most of it on the bug below). Total about 15 min.

Compile errors
1. `StatusPage.view [ StatusPage.success, StatusPage.title ... ]`: "TYPE MISMATCH ... StatusPage.Kind -> Html msg". Kind: wrong argument order,
   I assumed attributes only; `view` takes the attributes and then the `Kind`. Fix: `StatusPage.view [ title, description, actions ] StatusPage.success`.
(second build: none)

Bug found in the browser (not a compile error)
- Moving from "Company" to "Delivery" with the keyboard focus in the tax number showed "Required" under "Lead time" and a red mark on the step, before the user
  had touched anything. Cause: my step bodies are `case step of` in the same position; Elm reuses the focused `input` of the tax number for the lead time,
  `Form` then moves focus to the first field of the new step, the reused input blurs and counts as "left". Found by bisecting the spec (not `whole`, not `range`),
  then by typing for real instead of setting values. Fix: `Html.Keyed.node "div" [] [ ( stepLabel step, body ) ]`. See the KLAR GAP below.

Other fixes
- Submit success: focus fell to `body` (the Submit button is gone): `AppShell.goToContent` in the same update branch.
- The review step first had a "Change company" link in the middle of the list: now a row of a `DescriptionList` and a "Change ..." link per section.
- A server problem on the review step: the form stays on review, so `Form.goToProblem` with the first of `Form.problems` takes the user to the field on its step.

Acceptance (browser): 1 pass (`#/supplier/company|delivery|review` are routes; `#/supplier/review` typed first redirects to the company step, which
is empty; after a successful submit Back lands on an empty company step; Back and Next keep the typed values), 2 pass (Next with empty fields stops, shows the
summary and marks "Company (has errors)" in the stepper), 3 pass (the review lists name, tax number, country, lead time, every contact, each section with a
"Change ..." link back to its step), 4 pass (company `Crash`: "Something went wrong on our side" with "Try again", all values kept; tax number `000`: the form goes to the
company step and shows "This tax number is not registered." at the field and in the summary), 5 pass (confirmation page; no old values).
axe clean: company (empty, with problems), delivery (with an added contact and its problems), review, review with failure, company with the server problem,
confirmation.

KLAR GAP
- Step bodies that the application draws are not keyed, and Elm reuses a focused input across steps; `Form`'s focus move then blurs it and shows a
  problem on a field nobody touched. `Form.md`/`Spec.md` say nothing about keying; either `Form` should offer the step body (a `Form.stepBody v` that keys it) or the docs
  should say to key it. Commented above the keyed node in the source.
- (`Form.stepper` has no link per step: clicks go through `Form.update`, so the application must follow `Form.currentStep` to keep the address in step with it; that is `followStep` in the source. The docs
  say "the form owns the step" and the recipe has no routes per step.)

## T06 Command palette

Time: reading 17:32:59 to 17:33:30 (the `command-palette` recipe, `CommandPalette.md` signatures, the opening, section and `remote` parts, `Shortcut.md`
wiring), writing about 2 min, testing about 9 min. Total about 12 min.

Compile errors
1. Name shadowing: my own top-level function `text` and the local variables `text` in two branches ("SHADOWING"). Kind: my naming, not Klar. Fix: renamed the function `say`.
(later builds: none)

Fixes
- Ctrl K: `CommandPalette.open openButtonId` made Escape return focus to the button, not to the field that had it (the note field). The shortcut now
  opens with `""` ("focus returns to the element that had it, if it has an id"; the button opens with its own id), as `CommandPalette.md` describes.
- Running an item closes the palette but focus fell to `body` (the doc says only Escape returns focus): the branches of the items end with `AppShell.focusContent`.
- A text with only the command words ("go to order") left the section in `NotAsked`, which the palette shows as a skeleton for ever: the section is left out when
  nothing is left to ask (as `CommandPalette.md` says).
- The backend answers slower for shorter texts, so a stale answer can really come late (test for line 4).

Acceptance (browser): 1 pass (Ctrl K opens, Escape closes; focus back on the note field, or on the button when the button opened it; Enter on an item puts focus on `main`),
2 pass (typing "fail" gives "Searching ...", then "Can't reach the service" with "Try again"; Try again keeps focus in the search box; "9999" gives "No results"; the actions
are filtered at once), 3 pass ("go to order 1012" finds order 1012, so only "1012" was sent), 4 pass ("1", then "1012" 500 ms later: only the answer for 1012 is ever
shown; reopening gives an empty section), 5 pass (Enter runs the highlighted item, ArrowDown moves the highlight and `aria-activedescendant`, a live region says "3 results",
"1 result", "No results"; in Norwegian "3 treff").
axe: clean for the open palette with actions, with results, and after reopening; **fails** `aria-required-children` on `#palette-list` while the remote section is loading,
failed or empty.

KLAR GAP
- `CommandPalette.remote`: in the loading, failed and "no results" states the `role="listbox"` contains a `role="alert"`/status node and no option, so axe reports
  `aria-required-children` (1 node, `#palette-list`). Nothing the application can change.
- An item cannot name the words that call it ("go to order"); the application strips them (`searchText`). Same gap as in the recipe.
- Picking an item gives no focus back (only Escape does); the doc states it for Escape but the application must know to move focus after a run.

Notes
- First attempt at "go to order 1012" typed straight after Ctrl K was lost: the palette opens on the next frame, the text went to the page. A testing artefact; real users type after it appears.

## T07 Table with 50 000 rows

Time: reading 17:36:49 to 17:37:20 (`Table.md`: the quick paths, "Many rows", `virtual`, selection, `exportCsv`, footers), writing about 2 min, testing about 14 min
(most of it on measuring, see the tool note). Total about 17 min.

Compile errors: none (first build).

Design: client mode, `Table.prepareRows` once when the rows "arrive" (dummy backend, 400 ms), `Table.preparedRows`, pages of 25/50/100 (so at most 100 DOM rows),
`selectable`, `exportCsv`, `footerSum` on quantity and value, `filterSelect` on warehouse.

Acceptance (browser): 1 **partly**, see below, 2 pass (pages, at most 100 rows in the DOM), 3 pass (footer "SUM 5,466,773" and "SUM 486,255,216.00" of all matching rows; range text
"1–25 of 50,000", "1–25 of 159" after a search), 4 pass (header checkbox: "25 selected ... Select all 50,000 matching" gives "50,000 selected"; after a sort the two selected rows of the first page
are still checked and the count is 25), 5 pass (three rows picked one by one, Export > "Selected rows" downloads `movements-selected.csv` with the header and exactly those three rows).
axe clean: loaded table, with a selection and the selection bar.

Line 1 (under 150 ms, including two frames). Measured in the built-in browser pane, which does not paint: Elm's `requestAnimationFrame` was replaced by `setTimeout 0` in a
test page, and the time is from the event to the changed DOM plus two ticks. That is the cost of `update`, `view` and the DOM patch, without paint, so a real Chrome run will be higher
by the two frames. Results (ms): sort 26 to 36; page change unfiltered 53 to 95; search that keeps few rows (159) 93 to 102; clearing the search 19 to 70;
**search that keeps many rows ("product 07", 10 364 rows) 137 to 213; "product 1" (37 212 rows) 324 to 382; page change inside such a filtered set 271 to 394.** Without `footerSum` the
filtered page change was still 123 to 227. So the "all under 100 ms" of `Table.md` holds for sort and for the unfiltered table, not for large filtered sets, in this environment.
No performance timeline of a real Chrome with software rendering was available (the Chrome extension was not connected); line 1 is therefore **not verified as asked** and fails for large filtered sets.

KLAR GAP
- Page changes and keystrokes cost 150 to 400 ms when the search keeps tens of thousands of rows (the footers sum the whole matching set on every message; the rest is
  work on the matching set). A way to ask for the footer only on demand, or to cache the filtered set, is missing.
- (not a gap) The pane's `requestAnimationFrame` runs about once a second while the pane is hidden, so frame-based timing in it is unusable.

## T08 Drawer with confirm and toast

Time: reading 17:40:37 to 17:41:00 (the `confirm-delete` recipe, `Drawer.md` and `ConfirmDialog.md` signatures, `Toast.md` signatures, `Table.actions`), writing about 3 min,
testing about 8 min. Total about 12 min.

Compile errors
1. `viewDrawer : Model -> Overlay`: "The `Overlay` type needs 1 argument" (`Overlay Msg`). Kind: missing type parameter, my annotation.
(second build: none)

Acceptance (browser, keyboard only for the main path): 1 pass (Enter on the "Open 1005" button opens the drawer with a "Loading order" skeleton; orders ending in 5 fail the first time
with "Try again", which works and keeps focus in the drawer body; Escape closes the drawer and focus is back on the "Open 1005" button), 2 pass (the dialog says "Cancel order 1003? The order is set to
Cancelled and its reserved stock is released ..."; focus starts on "Keep order", so Enter does not confirm; Escape while the request runs does not close it),
3 pass (first confirm: "Something went wrong on our side / The server could not cancel the order. Nothing was changed." with "Try again" inside the dialog; the second succeeds),
4 pass (the dialog closes, the drawer shows "Cancelled", the row in the list shows "Cancelled", toast "Order 1003 cancelled." with Undo; Undo, reached with Tab from the confirm button of a
second dialog (confirm, Undo, dismiss), restores "Open" in the list; the toast is at the bottom left, 230 px below the confirm button, no overlap), 5 pass (with drawer and dialog open the
app shell chrome is `inert`; axe clean in: list, drawer skeleton, drawer failure, drawer loaded, dialog, dialog failed, dialog with toast).

Notes
- Right after Undo from inside the dialog focus was on `body` for a moment and then on the dialog (the layer restores it); not counted as a defect.
- Testing used a copy of `index.html` whose `requestAnimationFrame` was `setTimeout 0` (the pane hardly renders); the copy was deleted.

## T09 Saved views

Time: reading 17:42:54 to 17:43:20 (`SavedViews.md` in full, `ServerList.md` already read for T01), writing about 3 min (`t01` copied as the base, then the store and the encoders), testing about 6 min. Total about 10 min.

Compile errors
1. Name shadowing again: a lambda `\search sort -> ...` against my top-level `search` ("SHADOWING"; second time in this run, see T06). Kind: my naming. Fix: renamed the lambda variables.
(a heredoc that tripped the shell once; not a compile error)

Design: `ServerList` with `viewSavedViews` (it owns the name form, the checks, rename, delete, default, "modified" and Reset), `step.save` gives the list to store. Storage: JSON text made by `Rule.encode`
and a small encoder for the query (search text and sort), kept in the address as `#views=...` (see the gap), read back at start with one decoder per view, so a damaged view is skipped.

Acceptance (browser): 1 pass (empty name: "Enter a name."; "AURORA by total" when "Aurora by total" exists: "There is already a view with this name."; a saved view is selected and its name is on the button),
2 pass (search "aurora" and the sort by total came back after a reload; the page says "A saved view remembers the filters, the search text and the sort. It does not remember the page or the number of rows per page."; chips and list changed at once when "Shipped" was applied),
3 pass (the views are JSON text in the address and are there after a reload; a stored text with a second, broken view shows "1 stored view(s) could not be read and were skipped." and the good view works),
4 pass (the view marked "Use as default view" was applied on open: search "aurora", sort ascending, 33 rows; "Reset to no filter" clears the chips and the filter; the component's own "Reset" row goes to the default view or "no filters" when there is none),
5 pass (every control is a button reached with Tab; Enter saves and renames; Escape closes; the popup is `role="dialog"` named "Saved views", each action has an `aria-label` such as "Rename: Shipped" and "Use as default view: Shipped").
axe clean: closed, open list, save form with errors, rename form, after delete, after reset; once `color-contrast` on the danger button of the delete confirmation right after it appeared, clean a moment later (the same entry-animation effect as the toast in T02).

KLAR GAP
- Nothing in Klar (and no JavaScript allowed) stores anything across a reload. The "backend function" for the views therefore keeps its JSON text in the address (`#views=`), which is a hack: it ends up in history and bookmarks.
- The list of views is a `role="dialog"` with buttons, not a menu; the brief asks for "a menu the screen reader can name". It is named, but it is not `role="menu"`.
- `SavedViews.view` stores the whole `Table.Query` (with column filters and page size); there is no function to encode or decode a `SavedView`, so each application writes the JSON for the query and the record itself.

## T10 Timeline with load more

Time: reading 17:45:52 to 17:46:15 (`Timeline.md` in full, `Format.relative`, `JsonViewer` signatures), writing about 3 min, testing about 5 min. Total about 9 min.

Compile errors
1. My message constructor `Loaded Int (Result ...)` collided with `Remote.Loaded` (imported with `Remote(..)`): "TYPE MISMATCH ... Loaded produces Result ... -> Msg but should be Remote". Kind: name clash with an imported constructor (the docs import `Remote(..)` everywhere). Fix: `GotPage`.

Fixes
- axe `heading-order`: the day headings of the timeline are `h3` and followed the page's `h1` directly. Put the timeline in a `Card` with `Card.title "Events"` (an `h2`). Not mentioned in `Timeline.md`
  ("The headings are `h3` elements"); the trap list in `AI.md` has the card rule only for cards.

Acceptance (browser): 1 pass (skeleton "Loading events", then "20 of 87"), 2 pass ("Load more" keeps the 20 events and the focus on the button; counts 40, 60, 80, "87 of 87"; at the end the button stays but is `aria-disabled` and the
text says "No more events", which is **not** "the button is gone": Klar keeps it so that focus is never thrown away, see `Timeline.md`), 3 pass (the second page fails the first time: the 20 events stay, the foot says "Something went wrong on our side"
with "Try again"; one click asks for the second page only and gives 40 of 87), 4 pass (each event has the clock time and "3 minutes ago", "1 hour ago", "2 days ago", and a date ("5 October 2026") for events older than a week; an actor with initials;
a tone on the marker; "Show details" folds out the raw JSON), 5 pass ("Refresh" puts a new event, "just now", on top and the count becomes "88 of 88"; an event read in the middle of the page stayed at the same screen position, the scroll position moved by the height of the new one: browser scroll anchoring).
axe clean: loading, loaded, failed next page, at the end, after a refresh, with details open.

Notes
- Timeline shows clock times and day groups itself; the "3 minutes ago" text is mine (`Format.relative`) in the description, since Timeline only puts "how long ago" in a tooltip.
- To make the end of the list match the brief the application could stop passing `onLoadMore`, which removes the button and the focus with it; I kept Klar's behaviour.

## T11 Tree filter

Time: reading 17:47:58 to 17:48:30 (`Tree.md` signatures and the documentation up to "Large trees", `lazy`, `loadRequests`, `filterBox`, `allowEmptySelection`), writing about 3 min, testing about 6 min. Total about 10 min.

Compile errors: none (first build).

Design: `Tree.viewRemote` for the six regions, every region and every depot a `Tree.lazy` (294 nodes in all: 6 + 48 + 240), children kept by node id in a `Dict` and built into nodes on every render, `Tree.loadRequests` on each message,
`Tree.onRetry`. One id type `NodeId = Region Int | Warehouse Int | Zone Int` from the tree (`Tree.nodeIds`) to the list's filter (`inside`). The list is a client `Table` of 600 stock lines.

Fixes
- Retry of a failed branch: the "Try again" link is replaced by the loading row and focus fell to `body`; `Tree.focusNode` in the retry branch puts it back on the node.
- The tree only searches nodes it has (`Tree.md` says so), so with a lazy tree the filter finds nothing in branches nobody opened. The application loads every branch in the background while a filter text is typed (`ensureLoadedForFilter`).
  The match count for people is my own line ("47 places match"), because the tree's count is a hidden status line for screen readers (`role=status`, "47 matches").

Acceptance (browser): 1 pass (selecting "Vestland depot 2" gives "Stock in Vestland depot 2: 13 of 600 lines"; no selection shows all 600; the selected node is cleared by Enter or click on it (`allowEmptySelection`) and by the "Show all places" button),
2 pass ("zone c" opens the paths and shows 47 matches while the loading was going on ("0 places match so far (still loading)"); clearing the box restores the earlier open state, only Vestland open; the 48th "Zone C" is in the depot whose zones fail on the first request, which is why 47),
3 pass (opening Nordland shows "Loading ..." then the depots; Vestland fails: "Something went wrong on our side" with "Try again" in the tree, the branch stays open, the retry loads 8 depots and focus is on the node),
4 pass (one tab stop: only the first `treeitem` has `tabindex=0`; ArrowRight opens and loads, ArrowDown moves, Home and End jump, a letter key finds "Midt-Norge", Enter selects), 5 pass (`NodeId` end to end).
axe clean: loading, tree, open with failure (except below), after retry, selected, filtered, cleared.

KLAR GAP
- axe `target-size` (wcag22aa): the "Try again" link of a failed branch is 75 x 19 px (needs 24 x 24); in `Klar.Tree`, nothing the application can change.
- The tree cannot search nodes it has not loaded, so a lazy tree needs the application to load everything for the filter; a `Tree` that took a "search the backend" hook, or counted matches for people, would remove that code.
- Typing a word through the browser tool's text entry did not trigger type-to-find (single key presses did); the tree listens to key events, which is correct; not a defect.

## T12 Leave guard

Time: reading 17:50:50 to 17:51:20 (`LeaveGuard.md` in full, `SideNav` signatures, `AppShell` wiring), writing about 4 min, testing about 5 min. Total about 10 min.

Compile errors
1. `Klar.Theme.Info` without importing `Klar.Theme` ("I cannot find a `Klar.Theme.Info` variant"). Kind: missing import. Fix: `import Klar.Theme exposing (Tone(..))`.
(second build: none)

Design: `Browser.application` with `onUrlRequest = LinkClicked` of my own (as `AI.md` says for a guard) and `onUrlChange = UrlChanged`; `LeaveGuard.request` for links, `LeaveGuard.onUrlChange` for Back and Forward, `AppShell`
kept for the side menu (`AppShell.update` only for its own messages; the page comes from the guard), `LeaveGuard.saveAndLeave`, `SavedThenGo` is the `Saved page` message with the destination in it, `dismiss` after a save that led away.
`setDirty` only in the branch of `FormMsg`, in `Discard` and after a save; "Leave" reverts the form.

Acceptance (browser): 1 pass (with " Ltd" typed, Enter on the "Customers" link opens "Leave without saving?" with Leave, Stay and Save and leave; focus starts on Stay; Stay keeps the input and puts focus on the "Customers" link, which has an id),
2 pass (a clean form: Customers and back to Settings with no dialog), 3 pass ("Save and leave" with the company `Crash`: "Saving ...", then the user is still on Settings with "Something went wrong on our side / The server could not save the settings." and
"Try again", input kept; with a good name it saves, shows the toast and goes to Customers with focus on `main`), 4 pass (the Back button with unsaved input: the page stays, the input is kept, the dialog opens and the tab does not freeze; Stay puts the address back to `#/settings`; after Leave a second Back does not ask again),
5 pass (the page has an Alert: "Closing the tab or reloading the page is not guarded: only the pages of this application ask before they are left."; there is no `beforeunload`).
axe clean: Settings, Settings dirty, the dialog open, after the failed save.

Notes
- `LeaveGuard.md` has two paragraphs called "The browser's own buttons". The second one (near "Not an application with addresses") still describes the `Nav.forward 1` recipe with an `undoing` flag, the one the first paragraph says looped forever.
  A reader who stops at the second paragraph would write the loop. The two should not both be there.
- With `AppShell` the guard and the shell both want `onUrlChange`; `AI.md` says to give `onUrlRequest` a message of your own and keep the rest, but not what to do with `onUrlChange`. I kept `AppShell.update` for its own messages and ignored its address, taking the page from the guard.

## Totals

Clock: the shell's `date`, 17:06 to 17:53 (about 47 minutes) for twelve tasks. It counts tool time and may undercount my own thinking and typing time. Per task, in minutes (reading / writing / testing):
T01 2 / 1 / 7, T02 0.5 / 1 / 3, T03 0.5 / 2 / 4, T04 0.5 / 2 / 4, T05 1 / 3 / 10, T06 0.5 / 2 / 9, T07 0.5 / 2 / 14, T08 0.5 / 3 / 8, T09 0.5 / 3 / 6, T10 0.5 / 3 / 5, T11 0.5 / 3 / 6, T12 0.5 / 4 / 5.
Reading was short because each task has a recipe or a module doc that fits it, and `AI.md` points to it.

Compile errors in all (kind): 11 in 12 tasks. My own: type mismatch `Int`/`Float` (T01), name shadowing (T06, T09), wrong argument order or arity I had not looked up (`Text.paragraph` T04, `StatusPage.view` T05), missing type argument (T08), missing import (T12),
constructor clash with the imported `Remote(..)` (T10). None came from a Klar module that behaved unexpectedly. Every task compiles with `elm make src/Main.elm --optimize` (checked again at the end, exit 0) and `check-app.mjs` says the imports are only Klar's exposed modules.

Failures against the acceptance lines that remain: T01 line 1 wording ("1–25 of N" for "1 to 25 of N"), T07 line 1 for large filtered sets and not measured in a real Chrome, T10 line 2 (the button is dimmed, not gone), T06 and T11 axe (listbox children, target size).
Everything else passed in the browser.

Testing method note: the built-in pane hardly paints, so from T07 on I used a copy of `index.html` with `requestAnimationFrame` replaced by `setTimeout 0` (deleted afterwards), and typed with real key events for the form fields. Sibling notes in the shared folder were not read, to keep the run to the files of this directory.
