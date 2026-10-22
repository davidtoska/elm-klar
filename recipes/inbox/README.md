# Inbox: a server-mode list

**Task:** a list of orders that lives on the server, with search, sorting, paging, a filter bar and saved views that hold the filter and the table's query; old rows stay on the screen while the next page comes.

Klar modules: `Klar.Table` (server mode), `Klar.FilterBar`, `Klar.SavedViews`, `Klar.Rule`, `Klar.Remote`, `Klar.Button`, `Klar.Layout`, `Klar.PageHeader`, `Klar.Date`.

The pattern, all in `update`:

1. `Table`, `FilterBar` and `SavedViews` only record what the user asked for. After each of their `update` calls, compare `Table.query` and `FilterBar.rule` with the values before (`changed`).
2. When the rule changed, `Table.setPage 1`.
3. When anything changed, bump `ticket` and start `Process.sleep 250 |> Task.perform (\_ -> Debounced ticket)`. Only the `Debounced` message that carries the latest ticket sends the request.
4. The answer `GotPage ticket result` is dropped when its ticket is not the latest one.
5. `SavedViews.revision` changed means a view was applied: `FilterBar.setRule` with the rule of `SavedViews.active`, and `Table.setQuery` with its `query` when it has one (`SavedViews.currentQuery` makes saved views hold search, sort and filters). A button calls `SavedViews.startSave` to open the save form; `asShared` marks a view as the team's.
6. `Remote.refresh` when the request leaves and `Remote.refreshWith` when the answer comes keep the old rows (dimmed and busy) and, if the request fails, show them as old data with a retry; `Table.onRetry` handles a failure with no rows, `Table.onRefresh` adds a refresh button.

The server is the function `search`; type `fail` in the search box to see the failure state.
