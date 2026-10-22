module Klar.Settings exposing
    ( Settings, default, withDensity, withZone, withTheme, withMode, density, zone, theme, mode
    , scope
    , time, dateTime, toDate
    )

{-| What the application says once and every component follows: how tightly
things are packed (the density), the time zone of the times people read, and the
theme and mode (light or dark) of the look.

Use when: the application chooses a density or knows the time zone of its users, which is every application with a clock in it.
Do not use when: you want colors of your own; the application picks one of the ten themes of `Klar.Theme`, and nothing else.
Quick path: `default`, `withZone`, `withDensity`, `withTheme`, `withMode`, `AppShell.settings`, `Klar.stylesheetFor`

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


# Settings

@docs Settings, default, withDensity, withZone, withTheme, withMode, density, zone, theme, mode


# Where the density applies

@docs scope


# Writing a time yourself

@docs time, dateTime, toDate

-}

import Html exposing (Html)
import Klar.Date as Date exposing (Date)
import Klar.Format as Format
import Klar.Internal as Internal
import Klar.Locale exposing (Locale)
import Klar.Theme as Theme exposing (Density(..), Mode(..), Theme)
import Time



-- SETTINGS


{-| The settings of the application: a density, a time zone, a theme and a mode. The type is
opaque, so that more settings can be added without breaking your code. Keep one
in your model.
-}
type Settings
    = Settings
        { density : Density
        , zone : Maybe Time.Zone
        , theme : Theme
        , mode : Mode
        }


{-| `Normal` density and a time zone that is not known yet: times are written in
UTC and say so.
-}
default : Settings
default =
    Settings { density = Normal, zone = Nothing, theme = Theme.klar, mode = Light }


{-| How tightly rows, controls and cards are packed: `Compact`, `Normal` or
`Comfortable`.

    Settings.withDensity Compact model.settings

-}
withDensity : Density -> Settings -> Settings
withDensity value (Settings data) =
    Settings { data | density = value }


{-| The time zone of the people who read the application, as the browser says it
(`Time.here`). From now on the times Klar writes are in this zone and no longer
end in "UTC".
-}
withZone : Time.Zone -> Settings -> Settings
withZone value (Settings data) =
    Settings { data | zone = Just value }


{-| The theme of the application (one of the ten in [Klar.Theme](Klar-Theme)); the
stylesheet is drawn with it by `Klar.stylesheetFor`. The default is `Theme.klar`.

    Settings.withTheme Theme.ocean model.settings

-}
withTheme : Theme -> Settings -> Settings
withTheme value (Settings data) =
    Settings { data | theme = value }


{-| Light, dark, or the choice of the operating system. The default is `Light`.
Offer it to the person (a switch in the menu of the user), and keep it in the model.

    Settings.withMode Dark model.settings

-}
withMode : Mode -> Settings -> Settings
withMode value (Settings data) =
    Settings { data | mode = value }


{-| The theme in the settings.
-}
theme : Settings -> Theme
theme (Settings data) =
    data.theme


{-| The mode in the settings.
-}
mode : Settings -> Mode
mode (Settings data) =
    data.mode


{-| The density in the settings.
-}
density : Settings -> Density
density (Settings data) =
    data.density


{-| The time zone to format with, for the places where you write a time yourself
(`Format.time (Settings.zone model.settings) posix`). It is UTC until `withZone`
was called; prefer `time` and `dateTime`, which also say when the zone is not known.
-}
zone : Settings -> Time.Zone
zone (Settings data) =
    Maybe.withDefault Time.utc data.zone



-- SCOPE


{-| A box that carries the density of the settings to everything inside it, for
a page that is not inside `AppShell` (the shell does the same when it is given
`AppShell.settings`).

    Settings.scope model.settings
        [ Card.view [] [ Table.view [] ... ] ]

The box takes no space of its own and has no look.

-}
scope : Settings -> List (Html msg) -> Html msg
scope (Settings data) children =
    Html.div [ Internal.cls [ "klar-settings" ], Internal.densityAttr data.density ] children



-- TIMES


{-| The time of day on a 24-hour clock in the zone of the settings: `14:05`, or
`14:05 UTC` while the zone is not known.

    Settings.time model.settings model.loadedAt

-}
time : Settings -> Time.Posix -> String
time (Settings data) posix =
    case data.zone of
        Just value ->
            Format.time value posix

        Nothing ->
            Format.time Time.utc posix ++ " UTC"


{-| The date and the time: `2026-10-20 14:05` in English, `20.10.2026 14:05` in
Norwegian, with " UTC" added while the zone is not known.
-}
dateTime : Locale -> Settings -> Time.Posix -> String
dateTime locale (Settings data) posix =
    case data.zone of
        Just value ->
            Format.dateTime locale value posix

        Nothing ->
            Format.dateTime locale Time.utc posix ++ " UTC"


{-| The calendar day of a time, in the zone of the settings.
-}
toDate : Settings -> Time.Posix -> Date
toDate settings posix =
    Date.fromPosix (zone settings) posix
