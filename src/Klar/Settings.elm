module Klar.Settings exposing
    ( Settings, default, withDensity, withZone, density, zone
    , scope
    , Moment, at, toPosix, toDate, time, dateTime
    )

{-| What the application says once and every component follows: how tightly
things are packed (the density) and the time zone of the times people read.

Use when: the application chooses a density or knows the time zone of its users, which is every application with a clock in it.
Do not use when: you want the look of the components changed (colors, fonts, radius), which is done with the CSS custom properties described in `Klar.Theme`.
Quick path: `default`, `withZone`, `withDensity`, `at`

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

That is all. A `Table`, a `Card`, a `Stat`, a `Timeline`, a button and an input
follow the density with no attribute of their own (a component that is given its
own density, such as `Table.setDensity`, keeps it). The times Klar writes follow
the zone, because a time that Klar shows is a `Moment` and a `Moment` is made
with the settings:

    Remote.refreshWith model.orders result (Settings.at model.settings answeredAt)

**Density** is carried by the page, not by Elm: the shell (or `scope`) marks its
element and the stylesheet follows. Nothing is passed to a component.

**The zone is never UTC by accident.** Until the application has given the zone,
every time Klar writes ends in "UTC" (`14:05 UTC`), so a missing zone is seen at
once and not found by a user two hours off. With the zone given, the times are
written as they are on the user's wall (`16:05`).


# Settings

@docs Settings, default, withDensity, withZone, density, zone


# Where the density applies

@docs scope


# A time and its zone

@docs Moment, at, toPosix, toDate, time, dateTime

-}

import Html exposing (Html)
import Klar.Date as Date exposing (Date)
import Klar.Format as Format
import Klar.Internal as Internal
import Klar.Locale exposing (Locale)
import Klar.Theme exposing (Density(..))
import Time



-- SETTINGS


{-| The settings of the application: a density and a time zone. The type is
opaque, so that more settings can be added without breaking your code. Keep one
in your model.
-}
type Settings
    = Settings
        { density : Density
        , zone : Maybe Time.Zone
        }


{-| `Normal` density and a time zone that is not known yet: times are written in
UTC and say so.
-}
default : Settings
default =
    Settings { density = Normal, zone = Nothing }


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


{-| The density in the settings.
-}
density : Settings -> Density
density (Settings data) =
    data.density


{-| The time zone to format with, for the places where you write a time yourself
(`Format.time (Settings.zone model.settings) posix`). It is UTC until `withZone`
was called; prefer `at` and `time`, which also say when the zone is not known.
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



-- MOMENTS


{-| A point in time together with the zone it is shown in. Klar components that
show a time ask for a `Moment` and not for a `Time.Posix`: that is how the zone
cannot be forgotten. Make one with `at`.
-}
type Moment
    = Moment Time.Posix (Maybe Time.Zone)


{-| A time, shown in the zone of the settings.

    Settings.at model.settings answeredAt

-}
at : Settings -> Time.Posix -> Moment
at (Settings data) posix =
    Moment posix data.zone


{-| The point in time, to compare or sort or send back to a server.
-}
toPosix : Moment -> Time.Posix
toPosix (Moment posix _) =
    posix


{-| The calendar day of the moment, in its zone.
-}
toDate : Moment -> Date
toDate (Moment posix maybeZone) =
    Date.fromPosix (Maybe.withDefault Time.utc maybeZone) posix


{-| The time of day on a 24-hour clock: `14:05`, or `14:05 UTC` while the zone is
not known.
-}
time : Moment -> String
time (Moment posix maybeZone) =
    case maybeZone of
        Just value ->
            Format.time value posix

        Nothing ->
            Format.time Time.utc posix ++ " UTC"


{-| The date and the time: `2026-10-20 14:05` in English, `20.10.2026 14:05` in
Norwegian, with " UTC" added while the zone is not known.
-}
dateTime : Locale -> Moment -> String
dateTime locale (Moment posix maybeZone) =
    case maybeZone of
        Just value ->
            Format.dateTime locale value posix

        Nothing ->
            Format.dateTime locale Time.utc posix ++ " UTC"
