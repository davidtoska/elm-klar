# Klar.Settings

What the application says once and every component follows.

Import: `import Klar.Settings as Settings` | Group: Foundations

Types: `Settings`

## Signatures

```elm
-- Settings
type Settings  -- opaque: no constructors are exposed
default : Settings
withLocale : Locale.Locale -> Settings -> Settings
withZone : Time.Zone -> Settings -> Settings
withNow : Time.Posix -> Settings -> Settings
withDensity : Theme.Density -> Settings -> Settings
withTheme : Theme.Theme -> Settings -> Settings
withMode : Theme.Mode -> Settings -> Settings
locale : Settings -> Locale.Locale
zone : Settings -> Time.Zone
now : Settings -> Maybe Time.Posix
today : Settings -> Maybe Date.Date
density : Settings -> Theme.Density
theme : Settings -> Theme.Theme
mode : Settings -> Theme.Mode

-- Where the density applies
scope : Settings -> List (Html msg) -> Html msg

-- Writing a time yourself
time : Settings -> Time.Posix -> String
dateTime : Locale.Locale -> Settings -> Time.Posix -> String
toDate : Settings -> Time.Posix -> Date.Date
```

## Documentation

What the application says once and every component follows: the language of the
built-in text, the time zone of the times people read, the time now (and so the day
today), how tightly things are packed (the density), and the theme and mode (light or
dark) of the look. Keep one `Settings` in the model; it is the one place these values
live.

Use when: the application has a language, a clock or a density of its own, which is every application: keep one `Settings` in the model and draw the page from it.
Do not use when: you want colors of your own; the application picks one of the ten themes of `Klar.Theme`, and nothing else.
Quick path: `default`, `withLocale`, `withZone`, `withNow`, `withDensity`, `withTheme`, `withMode`, `AppShell.settings`, `Klar.stylesheetFor`

    import Klar
    import Klar.AppShell as AppShell
    import Klar.Locale as Locale
    import Klar.Settings as Settings exposing (Settings)
    import Task
    import Time

    type alias Model =
        { settings : Settings }

    -- init: the language from the flags, then ask the browser for the zone and the time, once
    ( { settings = Settings.withLocale (Locale.fromCode flags.language |> Maybe.withDefault Locale.default) Settings.default }
    , Cmd.batch [ Task.perform GotZone Time.here, Task.perform GotNow Time.now ]
    )

    -- update
    GotZone zone ->
        ( { model | settings = Settings.withZone zone model.settings }, Cmd.none )

    GotNow posix ->
        ( { model | settings = Settings.withNow posix model.settings }, Cmd.none )

    -- view: the stylesheet with the theme, the shell with the density
    Html.div []
        [ Klar.stylesheetFor model.settings
        , AppShell.view [ AppShell.settings model.settings, AppShell.locale (Settings.locale model.settings) ] [ page ]
        ]

**Each value reaches the page in one way:**

  - The theme and the mode are drawn by `Klar.stylesheetFor model.settings`, in place of
    `Klar.stylesheet` (which draws only the default theme in light mode).
  - The density is carried by the page, not by Elm: the shell (`AppShell.settings`) or
    `scope` marks its element and the stylesheet follows, so a `Table`, a `Card`, a `Stat`,
    a list, a tree, a button and an input are packed as the settings say, with no attribute
    on any of them. A component that is given its own density (`Table.setDensity`,
    `Tree.compact`) keeps it.
  - The zone goes to the components that write a time, with their `settings` attribute
    (below).
  - The language goes to the components with built-in text, with their `locale`
    attribute: `Select.locale (Settings.locale model.settings)`. Reading it from the
    settings, and not from a second field of the model, keeps one language on the page.
  - The day today goes to the components that mark it or count from it, with their
    `today` attribute: `DatePicker.today`, `FilterBar.today`, `RuleBuilder.today`
    (read it with `today`). The time now goes to `Timeline.now` and `ApprovalFlow.now`.

**The time zone** has to reach the components that write a time (`Table`, `Stat`,
`Chart`, `Tree`, `ListItem`, `Select`, `MultiSelect`, `Autocomplete`,
`CommandPalette`, `RemoteView` for "Old data from 14:05", and `Timeline` and
`ApprovalFlow` for the times of their events). Elm has no way to hand a value down to
everything inside a view, and a zone written into the data at update time would be
wrong when it arrives late or changes. So each of them takes the same one value, at
view time:

    Table.view TableMsg [ Table.settings model.settings, ... ] model.table

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

The settings of the application: a language, a time zone, the time now, a density,
a theme and a mode. The type is opaque, so that more settings can be added without
breaking your code. Keep one in your model.

### `default`

```elm
default : Settings
```

English, a time zone and a time that are not known yet (times are written in UTC
and say so, and there is no day today), `Normal` density, the `klar` theme in `Light`.

### `withLocale`

```elm
withLocale : Locale.Locale -> Settings -> Settings
```

The language of the built-in text of the application: `Locale.en` (the default)
or `Locale.nb`. Read it with `locale` and give it to every component with built-in
text (`Select.locale (Settings.locale model.settings)`). Once it is given, `scope`
also sets the `lang` attribute of its box, which screen readers use to choose the voice.

    Settings.withLocale Locale.nb model.settings

### `withZone`

```elm
withZone : Time.Zone -> Settings -> Settings
```

The time zone of the people who read the application, as the browser says it
(`Time.here`). From now on the times Klar writes are in this zone and no longer
end in "UTC".

`Time.here` is the offset of the zone today, with no daylight saving changes in
it: a time from the other half of the year is written one hour off (a December time
read in October in Oslo shows +02:00, not +01:00). Where that matters (audit logs,
histories that span a change), let the page give the offsets in its flags and build
the zone with `Time.customZone`, which `withZone` takes the same way.

### `withNow`

```elm
withNow : Time.Posix -> Settings -> Settings
```

The time now, as the application last read it: once at start with `Time.now`, or
every minute with `Time.every` for a page that stays open past midnight. `today` is
the day of it in the zone of the settings, so it changes at midnight on the user's wall.

    GotNow posix ->
        ( { model | settings = Settings.withNow posix model.settings }, Cmd.none )

### `withDensity`

```elm
withDensity : Theme.Density -> Settings -> Settings
```

How tightly rows, controls and cards are packed: `Compact`, `Normal` or
`Comfortable`.

    Settings.withDensity Compact model.settings

### `withTheme`

```elm
withTheme : Theme.Theme -> Settings -> Settings
```

The theme of the application (one of the ten in [Klar.Theme](Klar.Theme.md)). It is
drawn only by `Klar.stylesheetFor`: a page that draws `Klar.stylesheet` keeps the
default theme. The default is `Theme.klar`.

    Settings.withTheme Theme.ocean model.settings

### `withMode`

```elm
withMode : Theme.Mode -> Settings -> Settings
```

Light, dark, or the choice of the operating system. The default is `Light`. Like
the theme, it is drawn by `Klar.stylesheetFor`. Offer it to the person (a switch in
the menu of the user, with `Theme.modes` and `Theme.modeName`), and keep it in the
model (`Theme.modeKey` to store it).

    Settings.withMode Dark model.settings

### `locale`

```elm
locale : Settings -> Locale.Locale
```

The language in the settings: `Locale.default` (English) until `withLocale`.

### `zone`

```elm
zone : Settings -> Time.Zone
```

The time zone to format with, for the places where you write a time yourself
(`Format.time (Settings.zone model.settings) posix`). It is UTC until `withZone`
was called; prefer `time` and `dateTime`, which also say when the zone is not known.

### `now`

```elm
now : Settings -> Maybe Time.Posix
```

The time now in the settings, `Nothing` until `withNow` was called.

### `today`

```elm
today : Settings -> Maybe Date.Date
```

The day today: the day of `now` in the zone of the settings, `Nothing` until
`withNow` was called. Give it to the components that mark today or count from it:

    DatePicker.view DueMsg
        (DatePicker.label "Due date"
            :: List.filterMap identity [ Maybe.map DatePicker.today (Settings.today model.settings) ]
        )
        model.due

### `density`

```elm
density : Settings -> Theme.Density
```

The density in the settings.

### `theme`

```elm
theme : Settings -> Theme.Theme
```

The theme in the settings.

### `mode`

```elm
mode : Settings -> Theme.Mode
```

The mode in the settings.

## Where the density applies

### `scope`

```elm
scope : Settings -> List (Html msg) -> Html msg
```

A box that carries the density of the settings to everything inside it, for
a page that is not inside `AppShell` (the shell does the same when it is given
`AppShell.settings`). When the settings have a language (`withLocale`), the box also
has its `lang` attribute.

    Settings.scope model.settings
        [ Overlay.host { attributes = [], page = [ Card.view [] [ Table.view TableMsg [ ... ] model.table ] ], overlays = overlays } ]

Put the scope around `Overlay.host`, not inside its page: the dialogs and drawers of
the host are drawn beside the page, and only what is inside the box follows its
density. The box takes no space of its own and has no look.

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

    Settings.dateTime (Settings.locale model.settings) model.settings order.createdAt

### `toDate`

```elm
toDate : Settings -> Time.Posix -> Date.Date
```

The calendar day of a time, in the zone of the settings.
