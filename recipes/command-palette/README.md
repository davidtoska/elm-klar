# Command palette with a search-as-you-type section

**Task:** a palette (Ctrl K) with a static section of actions and a section "Go to order ..." that asks the backend while the user types.

Klar modules: `Klar.CommandPalette` (`remote`, `onRetry`, `emptyText`), `Klar.Shortcut`, `Klar.Overlay` (`host`), `Klar.Remote`, `Klar.Button`, `Klar.Alert`, `Klar.Layout`, `Klar.PageHeader`, `Klar.Text`, `Klar.Icon`.

The pattern:

1. Open: `CommandPalette.open openerId`, set the section to `NotAsked` and bump the ticket, so answers on their way are dropped.
2. After `CommandPalette.update`, compare `CommandPalette.query` before and after. If it changed: `NotAsked`, bump the ticket, `Process.sleep 250` then `Debounced ticket`.
3. `Debounced ticket` asks the backend only when the ticket is the latest and the text is not empty (`Loading`).
4. `GotHits ticket result` is dropped when the ticket is old; otherwise `Remote.fromResult`.
5. `CommandPalette.onRetry` sends `RetryHits`, which repeats step 3.
6. The words of the command ("go to order") are stripped from the query before it is sent (`searchText`).

The palette is an overlay, so it goes in the list of `Overlay.host` (or `AppShell.overlays`). Type `fail` to see the failure and the retry button.
