# Old and refreshing data

The gap (R2S-002, S-013, F-012, R2F-010, R2F-011): "refresh failed, showing the old data
from 14:05" and "refreshing, showing the old data" are the most common states of a data
screen after the first load, and `Remote` had no place for them. The Stock builder wrote a
`Feed` type, `settle`, `anyStale` and `viewNotices` (about 147 lines) and drew the marker in
each card by hand.

## What an application needs

1. Say when a request leaves: the data on the screen stays.
2. Take the answer in one line, good or bad, with the time it came.
3. Every data component draws it, with no attribute: the old data stays, calm marker with
   the time and a retry; dimmed and busy while refreshing.
4. One notice for the whole page.
5. Cannot be got wrong: no flag that can say "stale" without data, no data that is stale
   without a reason, no time that is missing when the marker needs it.

## Designs compared

**A. Two more constructors, `Refreshing a` and `Stale a Problem Posix`.** Matches the way
people already think about `Remote`. But the states are not exclusive: data can be old *and*
refreshing (the user pressed "Try again"), so a third constructor is needed, or the retry
loses the marker. And fresh data has no time, so after the first failure the marker has no
time to show unless `Loaded` carries one too.

**B. A wrapper, `Feed a = { remote : Remote a, error, at, refreshing }`** (what Stock wrote).
The four-state `Remote` stays untouched. But every component then needs two inputs, or a
second parallel API (`Table.feed`, `Stat.feed` ...), and the fields can contradict each other
(`error` set on a `Remote` that is `Loading`; `refreshing` on `NotAsked`). This is the design
that costs the application the most lines and lets it say impossible things.

**C. A record on the loaded data, `Loaded { data, at, ... }`.** One state, no contradictions,
but every existing `Loaded orders` match and every `Remote (List Order)` in an application
breaks, and `Table.rows (Loaded rows)` stops being the simplest thing.

**D (chosen). One more constructor with an opaque payload: `Kept (Kept a)`.**
`Kept` holds the data, when it was loaded, whether a refresh is on its way and why the last
refresh failed. It can only be made by `Remote.refresh` and `Remote.refreshWith`, so the
impossible combinations cannot be written: old data always has data and a reason, and
`refreshing` always has data. Fresh data from `refreshWith` is also `Kept`, so the time is
there when the first failure arrives. `Loaded a` keeps its meaning (data of no particular age,
for tests and simple screens) and `fromResult` still makes it.

The application writes:

```elm
-- the request leaves
( { model | orders = Remote.refresh model.orders }, fetchOrders )

-- the answer comes back, good or bad
GotOrders result at ->
    ( { model | orders = Remote.refreshWith model.orders result at }, Cmd.none )

-- the page
Alert.stale [] Refresh (Remote.staleIn "orders" model.orders)
```

and `Table.rows model.orders`, `Stat.remote model.orders ...`, `Chart.remote`,
`Timeline.remote`, `Tree.viewRemote`, `Select.remote` and the others draw the rest.

## Costs, and what we did about them

- **A `case` on `Remote` in application code has a fifth branch.** Exhaustive matches fail to
  compile (good); matches with a wildcard treat refreshed data as "not loaded" (bad).
  `Remote.toMaybe`, `withDefault`, `map` and `isLoaded` work for both constructors, and the
  docs say to use them. Klar's own components settle a `Kept` into `Loaded` once, on the
  way in (`Klar.Internal.Freshness.settle`), and draw the rest as before.
- **Posix in the answer.** The application has the time of the answer (a `Time.now` task or
  its own clock). The time is only used for `Ok`; for an error the data keeps the time it
  already had. The time zone for "14:05" is a `zone` attribute on the components that show
  it, as `Timeline` already had.
- **Retry button focus.** When a retry succeeds the marker, and the button in it, go away.
  `Table` keeps focus on itself (as it does for its failure retry); a `Modal`, `Drawer` and
  the palette take it back by themselves; the other components cannot move focus without a
  `Cmd`, so it falls to the page (see CONTRIBUTING, "Tricks").

## What is not in `Remote`

The marker, the dimming and the busy state are drawn by one internal module
(`Klar.Internal.Freshness`) so that all components say the same thing in the same way, with
texts in `Klar.Locale`. Dimming is limited to what keeps muted text at 4.5:1 (about 92 %);
the rest is a thin moving line at the top and `aria-busy`.
