# One density, one time zone (`Klar.Settings`)

A0 round 3 found that density and time zone were settings of each component (R3S-004, S-022,
R3S-012): `Table.setDensity`, `Tree.compact`, `Timeline.compact`, `Stat.size Small` each had their
own switch, `Card`, `Chart` and `Alert` none, and `zone` defaulted to UTC on every component, so
"Old data from 11:32" was two hours off in Norway unless each of `Stat`, `Chart`, `Table` and
`Timeline` was told. The application should say both **once**.

## The two are different problems

**Density is style, and style has a channel that needs no Elm argument: the page.** The shell
(or `Settings.scope`) puts `data-klar-density="compact"` (or `comfortable`; nothing for normal)
on its element. The stylesheet does the rest, in two ways:

- the control tokens (`--klar-control`, `-sm`, `-lg`, `--klar-control-px`, `--klar-option-h`) are
  redefined inside the marked element, and every button, input, select and option already reads
  them;
- every component that already had a compact or comfortable look gets a second selector for the
  same rule, written as `:where([data-klar-density=compact]) .klar-x:where(:not(.klar-x--compact,
  .klar-x--comfortable))`. It has the specificity of the component's own class, and it leaves out
  a component that was given a density of its own, so `Table.setDensity Compact` inside a
  comfortable shell is still compact. (Table, Compare, PermissionMatrix, Tree, Alert, EmptyState,
  ListItem, DescriptionList; `Card` and `Stat` got density rules of their own.)

`Timeline.compact` is a different layout (a dot, one line, the time at the right), not a density, so
it stays an attribute; the density only changes the space between the events of the usual layout.

**A time zone is data, and data has only the arguments.** The zone decides which characters
`Format.time` returns, so a CSS route cannot carry it, and Elm has no context a value can be
handed down through.

## Designs for the zone that were weighed

1. **A zone stamped into the data** (`Remote.refreshWith model.orders result (Settings.at
   settings now)`, a `Moment` that carries its zone). Required argument, cannot be forgotten, no
   attribute on any component. **Rejected after building it:** the zone is fixed when the answer
   is written into the model, so it is wrong when `Time.here` answers after the first response (a
   race that real applications have) and when the user changes the zone later; the showcase's
   zone switch showed it at once. The zone has to be read when the view is drawn.
2. **A bound helper** (`Settings.bind settings` returning pre-applied `table`, `stat`, ...). One
   function per component and every attribute type of every component repeated in `Settings`: the
   API would double (principle 10) and never be complete.
3. **One attribute with one value, on each component that writes a time** (chosen).
   `Table.settings model.settings`, replacing `Table.zone model.zone`. The attribute is the same
   everywhere, takes the whole `Settings` (so a later setting needs no new attribute), and reads
   the zone at view time, so it follows a late or a changed zone.

Design 3 can still be forgotten, so the default is the part that matters: **a time is never UTC by
accident.** Without a zone the time is written in UTC and ends in "UTC" (`Old data from 14:05
UTC`; `Settings.default` has no zone, and `Settings.withZone Time.utc` is the application that
does mean UTC). A forgotten zone is therefore visible in the first browser run and not found by a
user two hours off. This is the honest limit of pure Elm: no hole that cannot be forgotten without
a context value, and no context value without a framework.

## What the application writes

```elm
-- init
( { settings = Settings.default }, Task.perform GotZone Time.here )
-- update
GotZone zone -> ( { model | settings = Settings.withZone zone model.settings }, Cmd.none )
-- view
AppShell.view [ AppShell.settings model.settings ] [ page ]       -- density, for everything inside
Table.view msg [ Table.settings model.settings, ... ]             -- zone, where a time is written
```

The density switch of an application is `Settings.withDensity` on one field. Nothing is passed to
a component for it.

## Not done, and why

- **Locale is not in the settings.** Every component has a `locale` attribute for its own text and
  has the same "give it to every component" cost, but it is not a style (no CSS route) and not
  data with a safe default (the default, English, is silent). Folding it in means replacing
  `locale` on about a hundred components with `settings`; that is a decision for the owner, not a
  side effect of this change.
- **Chart height** does not follow the density: the plot is drawn in pixels from `Chart.height`.
- **`Settings.scope`** is a `div` with `display: contents`; a dialog that the application renders
  outside the shell and outside a scope does not follow the density.
