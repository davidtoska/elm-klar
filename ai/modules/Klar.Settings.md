# Klar.Settings

What the application says once and every component follows: how tightly things are packed (the density) and the time zone of the times people read.

Import: `import Klar.Settings as Settings` | Group: Foundations

Types: `Settings`

## Signatures

```elm
-- Settings
type Settings  -- opaque: no constructors are exposed
default : Settings
withDensity : Theme.Density -> Settings -> Settings
withZone : Time.Zone -> Settings -> Settings
density : Settings -> Theme.Density
zone : Settings -> Time.Zone

-- Where the density applies
scope : Settings -> List (Html msg) -> Html msg

-- Writing a time yourself
time : Settings -> Time.Posix -> String
dateTime : Locale.Locale -> Settings -> Time.Posix -> String
toDate : Settings -> Time.Posix -> Date.Date
```

## Documentation

What the application says once and every component follows: how tightly
things are packed (the density) and the time zone of the times people read.

Use when: the application chooses a density or knows the time zone of its users, which is every application with a clock in it.
Do not use when: you want the look of the components changed (colors, fonts, radius), which is done with the CSS custom properties described in `Klar.Theme`.
Quick path: `default`, `withZone`, `withDensity`, `AppShell.settings`

    import Klar.AppShell as AppShell
    import Klar.Settings as Settings exposing (Settings)
    import Task
    import Time

    type alias Model =
        { settings : Settings }

    -- init: ask the browser for the zone of the user, once
    ( { settings = Settings.default }, Task.perform GotZone Time.here )

    -- update
    GotZone zone ->
        ( { model | settings = Settings.withZone zone model.settings }, Cmd.none )

    -- view: the shell carries the density to everything inside it
    AppShell.view [ AppShell.settings model.settings ] [ page ]

**Density** is carried by the page, not by Elm: the shell (or `scope`) marks its
element and the stylesheet follows, so a `Table`, a `Card`, a `Stat`, a list, a
tree, a button and an input are packed as the settings say, with no attribute on
any of them. A component that is given its own density (`Table.setDensity`,
`Tree.compact`) keeps it.

**The time zone** has to reach the components that write a time (`Table`, `Stat`,
`Chart`, `Tree`, `ListItem`, `Select`, `MultiSelect`, `Autocomplete`,
`CommandPalette`, `RemoteView` for "Old data from 14:05", and `Timeline` and
`ApprovalFlow` for the times of their events). Elm has no way to hand a value down to
everything inside a view, and a zone written into the data at update time would be
wrong when it arrives late or changes. So each of them takes the same one value, at
view time:

    Table.view [ Table.settings model.settings, ... ] ...

    Stat.view [ Stat.settings model.settings, ... ]

**The zone is never UTC by accident.** Until the application has given the zone, and
in a component that was not given the settings, every time Klar writes ends in "UTC"
(`14:05 UTC`), so a missing zone is seen at once and not found by a user two hours
off. With the zone given, the times are written as they are on the user's wall
(`16:05`).

## Settings

### `Settings`

```elm
type Settings  -- opaque: no constructors are exposed
```

The settings of the application: a density and a time zone. The type is
opaque, so that more settings can be added without breaking your code. Keep one
in your model.

### `default`

```elm
default : Settings
```

`Normal` density and a time zone that is not known yet: times are written in
UTC and say so.

### `withDensity`

```elm
withDensity : Theme.Density -> Settings -> Settings
```

How tightly rows, controls and cards are packed: `Compact`, `Normal` or
`Comfortable`.

    Settings.withDensity Compact model.settings

### `withZone`

```elm
withZone : Time.Zone -> Settings -> Settings
```

The time zone of the people who read the application, as the browser says it
(`Time.here`). From now on the times Klar writes are in this zone and no longer
end in "UTC".

### `density`

```elm
density : Settings -> Theme.Density
```

The density in the settings.

### `zone`

```elm
zone : Settings -> Time.Zone
```

The time zone to format with, for the places where you write a time yourself
(`Format.time (Settings.zone model.settings) posix`). It is UTC until `withZone`
was called; prefer `time` and `dateTime`, which also say when the zone is not known.

## Where the density applies

### `scope`

```elm
scope : Settings -> List (Html msg) -> Html msg
```

A box that carries the density of the settings to everything inside it, for
a page that is not inside `AppShell` (the shell does the same when it is given
`AppShell.settings`).

    Settings.scope model.settings
        [ Card.view [] [ Table.view [] ... ] ]

The box takes no space of its own and has no look.

## Writing a time yourself

### `time`

```elm
time : Settings -> Time.Posix -> String
```

The time of day on a 24-hour clock in the zone of the settings: `14:05`, or
`14:05 UTC` while the zone is not known.

    Settings.time model.settings model.loadedAt

### `dateTime`

```elm
dateTime : Locale.Locale -> Settings -> Time.Posix -> String
```

The date and the time: `2026-10-20 14:05` in English, `20.10.2026 14:05` in
Norwegian, with " UTC" added while the zone is not known.

### `toDate`

```elm
toDate : Settings -> Time.Posix -> Date.Date
```

The calendar day of a time, in the zone of the settings.
