# Inbox: a server-mode list

**Task:** a list of orders that lives on the server, with search, sorting, paging, a filter bar and saved views that hold the filter and the table's query; old rows stay on the screen while the next page comes.

Klar modules: `Klar.ServerList` (it owns the table, the filter bar and the saved views), `Klar.Table`, `Klar.FilterBar`, `Klar.SavedViews`, `Klar.Rule`, `Klar.Remote`, `Klar.Button`, `Klar.Layout`, `Klar.PageHeader`, `Klar.Date`.

The pattern:

1. Keep one `ServerList.State id row` in the model. `ServerList.init "orders" views` makes it and the first request; the saved views are the ones you have stored.
2. Every message of the list is one constructor: `OrdersMsg (ServerList.Msg row)`, handled with `ServerList.update`. It returns a `Step`: the new `state`, a `cmd` to map, the `request` to send when the query or the rule changed, and the `save` list when the saved views changed.
3. One function (`follow`) turns a `Step` into commands. The request has the table's `Query` and the filter bar's `Rule`; the application sends it however it likes and answers with `ServerList.gotPage request result at`. The list drops an answer to an old request.
4. The three parts are drawn with `ServerList.viewSavedViews`, `ServerList.viewFilterBar` and `ServerList.viewTable`, which add what they own (the rows, the total, the retry, the match count) to the attributes you give them (`Table.columns`, `FilterBar.fields`, ...).
5. For bulk actions on a selection, `ServerList.target` gives the ids that were picked or, after "Select all N matching", the query, the rule and the exceptions.

Nothing here compares a query, resets a page or counts tickets: the list does. Type `fail` in the search box to see the failure state.
