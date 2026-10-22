# Inbox: a server-mode list

**Task:** a list of orders that lives on the server, with search, sorting, paging, a filter bar and saved views.

Klar modules: `Klar.Table` (server mode), `Klar.FilterBar`, `Klar.SavedViews`, `Klar.Rule`, `Klar.Remote`, `Klar.Layout`, `Klar.PageHeader`, `Klar.Date`.

The pattern, all in `update`:

1. `Table`, `FilterBar` and `SavedViews` only record what the user asked for. After each of their `update` calls, compare `Table.query` and `FilterBar.rule` with the values before (`changed`).
2. When the rule changed, `Table.setPage 1`.
3. When anything changed, bump `ticket` and start `Process.sleep 250 |> Task.perform (\_ -> Debounced ticket)`. Only the `Debounced` message that carries the latest ticket sends the request.
4. The answer `GotPage ticket result` is dropped when its ticket is not the latest one.
5. `SavedViews.revision` changed means a view was applied: `FilterBar.setRule` with `SavedViews.active`.
6. `Table.refreshing` keeps the old rows (dimmed) while the next page comes; `Table.onRetry` handles a failure.

The server is the function `search`; type `fail` in the search box to see the failure state.
