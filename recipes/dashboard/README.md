# Dashboard with Remote everywhere

A dashboard of Stat tiles, two charts, a tree and a timeline, each panel loading, failing and
retrying on its own, all reloaded by a period picker.

Modules: `Klar.Stat`, `Klar.Chart`, `Klar.Tree` (`nodeIds`, `viewRemote`), `Klar.Timeline`,
`Klar.SegmentedControl`, `Klar.Card`, `Klar.Layout`, `Klar.PageHeader`, `Klar.Remote`.

The pattern:

1. One `Remote` per panel in the model, never one for the page.
2. Every component takes its `Remote` (`Stat.remote`, `Chart.remote`, `Timeline.remote`,
   `Tree.viewRemote`) and an `onRetry` message for that panel only.
3. Changing the period sets every panel to `Loading` and sends the requests. The message carries
   the period it was asked for, and an answer for another period is dropped.
4. Use `Chart.remote` alone: `Chart.loading` after it silently cancels it.

The Activity panel fails on its first request on purpose.
