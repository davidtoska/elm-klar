# Server list

*Status: built. A decision record; the current API is in `ai/modules/Klar.ServerList.md`.*

`Klar.ServerList`: the glue of a server-mode list in one module. Findings: R3F-008, F-015 and F-016
(`apps/FRICTION.md`, `apps/round3/fulfilment/FRICTION.md`), A8 in the roadmap.

## The problem

A list on a server is a `Table` (server mode), a `FilterBar` and `SavedViews` that edit one query. After
each message the application had to: compare `Table.query` and `FilterBar.rule` before and after, go
back to page 1 when the rule changed, compare `SavedViews.revision` and load the applied view into the
filter bar and the table, ask the server, give each request a ticket and drop an answer that is not for
the latest one, keep the old rows (`Remote.refresh`, `Remote.refreshWith`), and map all of it to the
request type of the backend. About 55 lines in Fulfilment (`changed`, `viewsChanged`, `fetchNow`,
the ticket, five fields in the model, the `GotPage` branch), copied from `recipes/inbox`. Every
server-mode list repeats them, and a mistake (a forgotten page reset, a missing ticket) is a bug
that shows only with a slow server.

## Two designs

**A. A state that owns the three components.** `ServerList.State id row` holds the table, the filter
bar, the saved views, the rows and total of the last answer and a ticket. `update` returns a `Step`:
the new state, a command, a `request` when the server must be asked, and the `save` list when the
saved views changed. The application turns the request into its own call and answers with
`gotPage request result at`.

**B. A comparing helper, the application keeps the components.** `ServerList.sync before after`
returns what changed, and the application still holds the three states, the rows and the ticket,
and still routes the saved view back.

Chosen: **A**. B leaves the model, the three `update` branches, the rows and the ticket in the
application, which is most of the 55 lines, and leaves the ways to get it wrong: forgetting to call
`sync` in one branch (the filter bar then changes and nothing is asked), giving it the wrong
`before`, or keeping a ticket of its own. In A there is one `update`, one `Msg`, and one place
(`Step`) where a request can come from; the page reset, the dropping of "all matching", the view routing
and the ticket check cannot be skipped because the application never sees them. The price is that
the three components are reached through the module (`mapTable`, `table`, the `view*` functions); the
accessors that applications needed (`rule`, `query`, `rows`, `total`, `target`, `activeView`,
`savedViews`) are there.

## What the module owns

- The query and the rule are the ones in the table and in the filter bar; nothing is copied.
- **Compare and ask.** After a message of the table, the filter bar or the saved views, if
  `Table.query` or `FilterBar.rule` changed, `update` asks (new ticket, `Remote.refresh` of the rows).
- **Page reset.** When the rule changed the table goes to page 1. A sort or a column filter already did
  (`Table`). The saved view's query is always page 1 (`SavedViews`).
- **"All matching" selection.** When the rule changed, an "all matching" selection would mean other rows,
  so it is dropped (`Table.dropAllMatching`, new); rows picked one by one stay. (`Table` already
  drops it for its own search and filters.)
- **View routing.** `SavedViews.revision` changed: the view's rule goes into the filter bar and its query
  into the table, and one request follows. `applyView name` does the same for a link, and `setViews` for
  views that came from a backend later (the default view is applied when none is).
- **Ticket.** Every request carries a `Ticket` (opaque). `gotPage request result at` goes back with it;
  an answer whose ticket is not the latest is ignored. The application cannot answer with a ticket of its
  own because it can only hand the `Request` back.
- **Rows.** `Remote (List row)` and the total of the last good answer: a failed answer keeps the rows as
  old data with a retry (`Remote.refreshWith`); with no rows it is a failure. The three `view*` functions
  add the rows, the total, the retry and refresh buttons, the count of filters and the button that clears
  them, the match count and the "counting" mark, and the saved views' `current` rule and query.
- **Selection.** `target ids state` gives the picked ids or, after "Select all N matching", the query,
  the rule and the exceptions (`Matching`), so a bulk action or an export of everything that matches is a
  request the application fulfils (R3F-007, R3F-014). `Table.exportCsv` still offers the selected rows
  while every one is on the page; a selection across pages is exported by the backend.

## What it does not own

- The request (`Request -> Cmd msg` in the application), the columns, the fields, the attributes of the
  three components (locale, labels, `Table.rowId`...), and the storage of saved views (`Step.save`).
- **The debounce.** The text typed into the table's search and its filter fields already waits
  (`Table.searchDebounce`, 350 ms) and the filter bar changes only on "Add", so every change that reaches
  `update` is deliberate. A second timer would delay clicks (pages, sorts) and need a message of its own
  for no gain; the ticket protects the answer. Rapid clicks on "Next page" can send several requests, and
  only the last one is shown. If a backend needs fewer requests, the application can wait in its own
  request function.
- **The palette's remote section.** `CommandPalette` keeps its own query, and its pattern (query, wait,
  ask, ticket) has a different state (one text, hits as a list). It does not share state with a table, so
  a shared module would be a second, unrelated helper. Left as it is (F-015 stays open).
- Time: the application hands `at` to `gotPage`, as everywhere in Klar (`Remote.refreshWith`).

## Result

The model of Fulfilment loses `table`, `filterBar`, `views`, `rows`, `total` and `ticket` for one
`orders : ServerList.State OrderId Summary`; `Msg` loses `TableMsg`, `FilterBarMsg`, `ViewsMsg`,
`GotPage`; `changed`, `viewsChanged`, `fetchNow` and `request` are gone. Their place is
`listStep`, 25 lines that turn a `Step` into commands (and are the same in every application). The
recipe `inbox` goes from 277 lines of model, update and view to 141. Measured in `Main.elm` of the
Fulfilment application: 1 852 to 1 702 lines.

## Types

`Request` is a record (`query`, `rule`, `ticket`), `Page row` is a record (`rows`, `total`), `Step` is
a record. `Target id` is an exposed union with two constructors (`Picked`, `Matching`): the application
matches on it to run a bulk action, and it is closed (a selection is ids, or everything that matches
minus some), so it joins `Table.Selection` in the list of exposed unions in `CONTRIBUTING.md`. No
function is held in a `Msg` or in the state. The module imports no HTTP and no JSON.
