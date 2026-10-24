# Dashboard with Remote everywhere

A dashboard of Stat tiles, two charts, a tree and a timeline, each panel loading, failing and
retrying on its own, all reloaded by a period picker. A reload keeps the old numbers, dimmed, and a failed one marks them as old.

Modules: `Klar.Stat`, `Klar.Chart`, `Klar.Tree` (`nodeIds`, `viewRemote`), `Klar.Timeline`,
`Klar.SegmentedControl`, `Klar.Card`, `Klar.Layout`, `Klar.PageHeader`, `Klar.Alert` (`stale`), `Klar.Remote` (`refresh`, `refreshWith`, `staleIn`), `Klar.Settings` (`withZone`).

The pattern:

1. One `Remote` per panel in the model, never one for the page.
2. Every component takes its `Remote` (`Stat.remote`, `Chart.remote`, `Timeline.remote`,
   `Tree.viewRemote`) and an `onRetry` message for that panel only.
3. Changing the period or retrying calls `Remote.refresh` on the panel and sends the request; the answer goes in with `Remote.refreshWith panel result time`. Data that is there stays (dimmed), a failed refresh keeps it as old data ("Old data from 14:05"), and a panel with no data shows its skeleton or failure. `Alert.stale` with `Remote.staleIn` gives one notice for the page. The message carries
   the period it was asked for, and an answer for another period is dropped.
4. The zone of "Old data from 14:05" is in the model's `Klar.Settings` (`Time.here` at the start, `Settings.withZone`) and each panel is given it (`Stat.settings`, `Chart.settings`, `Timeline.settings`).
5. Use `Chart.remote` alone: `Chart.loading` after it silently cancels it. Read data with `Remote.toMaybe`, not a `case` on `Loaded`, so old data counts.

The Activity panel fails on its first request and the order status panel fails for 90 days, on purpose.
