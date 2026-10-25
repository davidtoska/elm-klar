module Klar.Settings exposing
    ( Settings, default
    , withLocale, withZone, withNow, withDensity, withTheme, withMode
    , locale, zone, now, today, density, theme, mode
    , scope
    , time, dateTime, toDate
    )

{-| What the application says once and every component follows: the language of the
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


# Settings

@docs Settings, default
@docs withLocale, withZone, withNow, withDensity, withTheme, withMode
@docs locale, zone, now, today, density, theme, mode


# Where the density applies

@docs scope


# Writing a time yourself

@docs time, dateTime, toDate

-}

import Html exposing (Html)
import Html.Attributes as Attr
import Klar.Date as Date exposing (Date)
import Klar.Format as Format
import Klar.Internal as Internal
import Klar.Locale as Locale exposing (Locale)
import Klar.Theme as Theme exposing (Density(..), Mode(..), Theme)
import Time



-- SETTINGS


{-| The settings of the application: a language, a time zone, the time now, a density,
a theme and a mode. The type is opaque, so that more settings can be added without
breaking your code. Keep one in your model.
-}
type Settings
    = Settings
        { locale : Maybe Locale
        , zone : Maybe Time.Zone
        , now : Maybe Time.Posix
        , density : Density
        , theme : Theme
        , mode : Mode
        }


{-| English, a time zone and a time that are not known yet (times are written in UTC
and say so, and there is no day today), `Normal` density, the `klar` theme in `Light`.
-}
default : Settings
default =
    Settings
        { locale = Nothing
        , zone = Nothing
        , now = Nothing
        , density = Normal
        , theme = Theme.klar
        , mode = Light
        }


{-| The language of the built-in text of the application: `Locale.en` (the default)
or `Locale.nb`. Read it with `locale` and give it to every component with built-in
text (`Select.locale (Settings.locale model.settings)`). Once it is given, `scope`
also sets the `lang` attribute of its box, which screen readers use to choose the voice.

    Settings.withLocale Locale.nb model.settings

-}
withLocale : Locale -> Settings -> Settings
withLocale value (Settings data) =
    Settings { data | locale = Just value }


{-| The time zone of the people who read the application, as the browser says it
(`Time.here`). From now on the times Klar writes are in this zone and no longer
end in "UTC".

`Time.here` is the offset of the zone today, with no daylight saving changes in
it: a time from the other half of the year is written one hour off (a December time
read in October in Oslo shows +02:00, not +01:00). Where that matters (audit logs,
histories that span a change), let the page give the offsets in its flags and build
the zone with `Time.customZone`, which `withZone` takes the same way.

-}
withZone : Time.Zone -> Settings -> Settings
withZone value (Settings data) =
    Settings { data | zone = Just value }


{-| The time now, as the application last read it: once at start with `Time.now`, or
every minute with `Time.every` for a page that stays open past midnight. `today` is
the day of it in the zone of the settings, so it changes at midnight on the user's wall.

    GotNow posix ->
        ( { model | settings = Settings.withNow posix model.settings }, Cmd.none )

-}
withNow : Time.Posix -> Settings -> Settings
withNow value (Settings data) =
    Settings { data | now = Just value }


{-| How tightly rows, controls and cards are packed: `Compact`, `Normal` or
`Comfortable`.

    Settings.withDensity Compact model.settings

-}
withDensity : Density -> Settings -> Settings
withDensity value (Settings data) =
    Settings { data | density = value }


{-| The theme of the application (one of the ten in [Klar.Theme](Klar-Theme)). It is
drawn only by `Klar.stylesheetFor`: a page that draws `Klar.stylesheet` keeps the
default theme. The default is `Theme.klar`.

    Settings.withTheme Theme.ocean model.settings

-}
withTheme : Theme -> Settings -> Settings
withTheme value (Settings data) =
    Settings { data | theme = value }


{-| Light, dark, or the choice of the operating system. The default is `Light`. Like
the theme, it is drawn by `Klar.stylesheetFor`. Offer it to the person (a switch in
the menu of the user, with `Theme.modes` and `Theme.modeName`), and keep it in the
model (`Theme.modeKey` to store it).

    Settings.withMode Dark model.settings

-}
withMode : Mode -> Settings -> Settings
withMode value (Settings data) =
    Settings { data | mode = value }


{-| The language in the settings: `Locale.default` (English) until `withLocale`.
-}
locale : Settings -> Locale
locale (Settings data) =
    Maybe.withDefault Locale.default data.locale


{-| The time now in the settings, `Nothing` until `withNow` was called.
-}
now : Settings -> Maybe Time.Posix
now (Settings data) =
    data.now


{-| The day today: the day of `now` in the zone of the settings, `Nothing` until
`withNow` was called. Give it to the components that mark today or count from it:

    DatePicker.view DueMsg
        (DatePicker.label "Due date"
            :: List.filterMap identity [ Maybe.map DatePicker.today (Settings.today model.settings) ]
        )
        model.due

-}
today : Settings -> Maybe Date
today ((Settings data) as settings) =
    Maybe.map (toDate settings) data.now


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
`AppShell.settings`). When the settings have a language (`withLocale`), the box also
has its `lang` attribute.

    Settings.scope model.settings
        [ Overlay.host { attributes = [], page = [ Card.view [] [ Table.view TableMsg [ ... ] model.table ] ], overlays = overlays } ]

Put the scope around `Overlay.host`, not inside its page: the dialogs and drawers of
the host are drawn beside the page, and only what is inside the box follows its
density. The box takes no space of its own and has no look.

-}
scope : Settings -> List (Html msg) -> Html msg
scope (Settings data) children =
    Html.div
        [ Internal.cls [ "klar-settings" ]
        , Internal.densityAttr data.density
        , Internal.attrMaybe (\value -> Attr.attribute "lang" (Locale.toCode value)) data.locale
        ]
        children



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

    Settings.dateTime (Settings.locale model.settings) model.settings order.createdAt

-}
dateTime : Locale -> Settings -> Time.Posix -> String
dateTime language (Settings data) posix =
    case data.zone of
        Just value ->
            Format.dateTime language value posix

        Nothing ->
            Format.dateTime language Time.utc posix ++ " UTC"


{-| The calendar day of a time, in the zone of the settings.
-}
toDate : Settings -> Time.Posix -> Date
toDate settings posix =
    Date.fromPosix (zone settings) posix
