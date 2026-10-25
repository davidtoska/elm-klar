module Klar.DateRangePicker exposing
    ( view
    , State, init, Msg, update
    , value, from, to, isValid, text, setValue, clear, setText, setLimits
    , isOpen, open, close, visibleMonth
    , Preset, preset, presets, noPresets
    , Attribute, today, min, max, maxRangeDays, disabledWhen
    , markers, weekNumbers, alignEnd
    , label, labelHidden, hint, error, errorMaybe, required, optionalText
    , placeholder, size, locale, disabled, readOnly, clearable, name
    )

{-| A period field: a from date and a to date in one control, with one calendar
that shows two months and a list of quick choices.

Use when: the user chooses a period, as in reports, filters and bookings.
Do not use when: the user enters a single date (as `Klar.DatePicker`).
Quick path: `init`, `update`, `view`, `value`

For a single date see [Klar.DatePicker](Klar-DatePicker).

    import Klar.DateRangePicker as DateRangePicker

    -- model
    { period : DateRangePicker.State }   -- DateRangePicker.init "report-period"

    -- msg
    PeriodMsg DateRangePicker.Msg

    -- the limits of the field, in one place: view and setLimits use the same list
    periodLimits : Date -> List (DateRangePicker.Attribute msg)
    periodLimits today =
        [ DateRangePicker.today today, DateRangePicker.max today, DateRangePicker.maxRangeDays 90 ]

    -- update
    PeriodMsg m ->
        let
            ( period, cmd ) =
                DateRangePicker.update m model.period
        in
        ( { model | period = period }, Cmd.map PeriodMsg cmd )

    -- on submit: read the text the user has not left yet, then ask
    DateRangePicker.setLimits (periodLimits model.today) model.period   -- then isValid and value

    -- view
    DateRangePicker.view PeriodMsg
        (DateRangePicker.label "Report period" :: periodLimits model.today)
        model.period

    -- read
    DateRangePicker.value model.period   -- Maybe ( Date, Date )

Here `model.today` is a [Klar.Date](Klar-Date) value that the application keeps;
the library never reads the clock. The state holds the period, and there are no
out-messages: compare `value` before and after `update` to react to a change.

Choose the period with two clicks in the calendar. The choice applies on the
second click and the popup closes. Between the clicks the days from the first
day to the one under the mouse (or the keyboard focus) are highlighted, the
first field shows the first day, and the second field is empty. `Escape` closes
the popup and throws away a half-made choice.

The quick choices ("Today", "Last 7 days", "Last 30 days", "This week", "This
month", "Last month", "This quarter", "Last quarter" and "This year" in English;
weeks start on the first day of the week of `locale`) are computed from the
`today` the application supplies. Each one gives the part of its period that the user could choose by
hand: it is cut to `min` and `max`, and then inward past the days that
`disabledWhen` excludes, so it starts and ends on a day that is allowed (days in
between may be disabled, as in the calendar). A quick choice is disabled when
nothing is left of it, or when what is left is longer than `maxRangeDays`; its
tooltip then gives the reason. Without `today` the list is empty. Give your own
with `presets`, or turn them off with `noPresets`.

The two fields take typed dates like [Klar.DatePicker](Klar-DatePicker); the
forms it understands are listed there. `value` is `Just` only when both dates
are valid and `from` is not after `to`; `from` and `to` give the single dates,
also when the period as a whole is not valid yet. When a date or the period is
not valid, the field shows a message such as "The start date cannot be after the
end date" or "The period cannot be longer than 90 days", and `isValid` is
`False`. A form should call `setLimits` when it is submitted, because the user
may never have left the fields.

Keyboard: `ArrowDown` or `Alt+ArrowDown` in either text field opens the
calendar. So does `Enter`, unless the user has just typed something that was not
taken yet: then `Enter` takes the text. The keys inside the calendar are those of
[Klar.Calendar](Klar-Calendar). Only one quick choice is in the tab order (the
pressed one, or else the first); the arrow keys, `Home` and `End` move between
them. `Escape` closes the popup (inside the month and year choosers it goes back
one step first), and `Tab` out of the popup closes it.

The two inputs sit in a `role="group"` named by the label; the name of each input
adds "from date" or "to date". The line below the calendar ("Choose the start
date", "Choose the end date", or the chosen period and its length in days) is
announced politely. The popup is placed like the one of
[Klar.DatePicker](Klar-DatePicker): it needs CSS anchor positioning to escape a
scrolling parent and to open above the field when there is no room below, and
without it a parent that scrolls or hides its overflow can clip it. The built-in
text comes from `locale`; the default is English.


# View

@docs view


# State

@docs State, init, Msg, update


# The period

@docs value, from, to, isValid, text, setValue, clear, setText, setLimits


# The calendar popup

@docs isOpen, open, close, visibleMonth


# Quick choices

@docs Preset, preset, presets, noPresets


# Limits and today

@docs Attribute, today, min, max, maxRangeDays, disabledWhen


# Calendar

@docs markers, weekNumbers, alignEnd


# Label, hint and error

@docs label, labelHidden, hint, error, errorMaybe, required, optionalText


# Look and behavior

@docs placeholder, size, locale, disabled, readOnly, clearable, name

-}

import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Events
import Json.Decode as Decode
import Klar.Button as Button
import Klar.Calendar as Calendar
import Klar.Calendar.Core as CalendarCore
import Klar.Calendar.Parse as Parse exposing (Bounds, Problem(..), Reading, Rules)
import Klar.Calendar.Popup as Popup
import Klar.Calendar.Util as Util
import Klar.Date as Date exposing (Date)
import Klar.Field as Field
import Klar.Format as Format
import Klar.Icon as Icon
import Klar.Internal as Internal
import Klar.Locale as Locale exposing (Locale)
import Klar.Theme as Theme exposing (Size(..))



-- STATE


{-| The state of one period field: the accepted from and to dates, any text
still being typed in the two inputs, whether the calendar is open, and the
calendar itself. Make it with `init`, keep it in your model, and read it with
`value`, `from`, `to` and `isValid`.
-}
type State
    = State Inner


type alias Inner =
    { id : String
    , from : Maybe Date
    , to : Maybe Date
    , fromDraft : Maybe String
    , toDraft : Maybe String
    , fromProblem : Maybe Problem
    , toProblem : Maybe Problem
    , rangeProblem : Maybe Problem
    , open : Bool
    , calendar : Calendar.State
    }


{-| An empty field. The `String` must be unique on the page: the two text
inputs get the DOM ids `<id>-from` and `<id>-to`, and the calendar button and
the popup get ids derived from it.

    DateRangePicker.init "report-period"

-}
init : String -> State
init id =
    State
        { id = id
        , from = Nothing
        , to = Nothing
        , fromDraft = Nothing
        , toDraft = Nothing
        , fromProblem = Nothing
        , toProblem = Nothing
        , rangeProblem = Nothing
        , open = False
        , calendar = Calendar.initRange (id ++ "-popup-cal") |> Calendar.setMonths 2
        }


{-| The accepted period as `( from, to )`, both days included. It is `Just` only
when both dates are valid, `from` is not after `to`, and the period is not
longer than `maxRangeDays`. While a field is empty or unreadable, or the period
is rejected, it is `Nothing`.
-}
value : State -> Maybe ( Date, Date )
value (State s) =
    case ( s.from, s.to, s.rangeProblem ) of
        ( Just start, Just finish, Nothing ) ->
            Just ( start, finish )

        _ ->
            Nothing


{-| The accepted from date, or `Nothing` when that field is empty or unreadable.
It is given even when the period as a whole is not valid yet, for example when
the to date is still missing.
-}
from : State -> Maybe Date
from (State s) =
    s.from


{-| The accepted to date, or `Nothing` when that field is empty or unreadable.
Like `from`, it is given even when the period as a whole is not valid yet.
-}
to : State -> Maybe Date
to (State s) =
    s.to


{-| `False` when the last attempt to read the fields failed: a date is not a
date, lies outside `min` and `max`, or is excluded by `disabledWhen`, or the
period is reversed or longer than `maxRangeDays`. The field shows the first
matching message. Empty fields are valid; whether a period is required is for
the application to say.

Text is only tried when it is complete (a day, a month and a four-digit year,
such as `1.2.2026`, `20.10.2026` or `2026-10-20`), when the user leaves a field
or presses `Enter`, and when you call `setLimits`, so call `setLimits` first
when you check this on submit.

-}
isValid : State -> Bool
isValid (State s) =
    s.fromProblem == Nothing && s.toProblem == Nothing && s.rangeProblem == Nothing


{-| The text in the two inputs that has not been replaced by a formatted date
yet: text the user is still typing, or text that could not be read. Each part
is empty when its input shows an accepted date or nothing. Together with `from`
and `to` it tells an empty input from garbage, as
[DatePicker.text](Klar-DatePicker#text) does for one date.
-}
text : State -> { from : String, to : String }
text (State s) =
    { from = Maybe.withDefault "" s.fromDraft
    , to = Maybe.withDefault "" s.toDraft
    }


{-| `True` while the calendar popup is open. A field that is `disabled` or
`readOnly` never draws it.
-}
isOpen : State -> Bool
isOpen (State s) =
    s.open


{-| The first of the two months the calendar shows, as `{ year, month }`
(January is 1). For an application that loads marks one month at a time: compare
it before and after `update` and fetch when it changes. It is only meaningful
once the calendar has been opened; see
[DatePicker.visibleMonth](Klar-DatePicker#visibleMonth).
-}
visibleMonth : State -> { year : Int, month : Int }
visibleMonth (State s) =
    Calendar.visibleMonth s.calendar


{-| Sets the period, or empties both fields with `Nothing`. The two days may be
given in either order, the earlier one becoming the from date. Text that was
being typed is dropped, and the period is not checked against the limits until
`setLimits` is called.

    DateRangePicker.setValue (Just ( quarterStart, quarterEnd )) model.period

-}
setValue : Maybe ( Date, Date ) -> State -> State
setValue maybeRange (State s) =
    let
        ( start, finish ) =
            case maybeRange of
                Just ( a, b ) ->
                    ( Just (Util.earlier a b), Just (Util.later a b) )

                Nothing ->
                    ( Nothing, Nothing )
    in
    State
        { s
            | from = start
            , to = finish
            , fromDraft = Nothing
            , toDraft = Nothing
            , fromProblem = Nothing
            , toProblem = Nothing
            , rangeProblem = Nothing
            , calendar =
                Calendar.setRange
                    (Maybe.map2 Tuple.pair start finish)
                    s.calendar
        }


{-| Empties both fields. The same as `setValue Nothing`.
-}
clear : State -> State
clear =
    setValue Nothing


{-| Fills the two fields with text as if the user had typed it. The texts are
read when the user leaves a field or presses `Enter`, or when you call
`setLimits`; until then `from`, `to` and `value` keep their old values.

    DateRangePicker.setText { from = "2026-10-01", to = "2026-10-31" } model.period

-}
setText : { from : String, to : String } -> State -> State
setText texts (State s) =
    State
        { s
            | fromDraft = Just texts.from
            , toDraft = Just texts.to
            , fromProblem = Nothing
            , toProblem = Nothing
            , rangeProblem = Nothing
        }


{-| Reads both fields again with the limits of these attributes, as if the user
had left them: pending text that can be read becomes the date and is shown
formatted, and text that cannot sets the problem that `isValid` reports. A date
that was accepted before (or set with `setValue`) and that the limits no longer
allow keeps its text in its input, with the message; it is never moved into the
limits. Pass the same attributes as to `view`, because `today`, the limits,
`maxRangeDays` and the locale decide what is valid.

Use it when a form is submitted, since the user may never have left the fields,
and after the limits change.

    DateRangePicker.setLimits periodLimits model.period

-}
setLimits : List (Attribute msg) -> State -> State
setLimits attributes (State s) =
    let
        config =
            configure attributes

        rules =
            rulesOf config

        readings =
            pendingReadings rules s

        committed =
            s
                |> commit FromSide config.maxRangeDays readings.from
                |> commit ToSide config.maxRangeDays readings.to

        recheck side inner =
            case ( draftOf side inner, dateOf side inner ) of
                ( Nothing, Just accepted ) ->
                    case Parse.check rules accepted of
                        Ok _ ->
                            inner

                        Err problem ->
                            setProblem side (Format.date config.locale accepted) problem inner

                _ ->
                    inner
    in
    State
        (committed
            |> recheck FromSide
            |> recheck ToSide
            |> checkPeriod config.maxRangeDays
        )


{-| Opens the calendar and moves the focus into it, after reading any pending
text. It opens on the from date, or else on the day given with `today`, kept
inside `min` and `max`. Pass the same attributes as to `view`: the limits come
from them. A field that is `disabled` or `readOnly` stays closed.
-}
open : List (Attribute msg) -> State -> ( State, Cmd Msg )
open attributes (State s) =
    let
        config =
            configure attributes
    in
    if config.disabled || config.readOnly then
        ( State s, Cmd.none )

    else
        openPopup (limitsOf config) (pendingReadings (rulesOf config) s) s


{-| The pending texts of both fields, read with the rules.
-}
pendingReadings : Rules -> Inner -> Readings
pendingReadings rules s =
    { from = Parse.read rules (Maybe.withDefault "" s.fromDraft)
    , to = Parse.read rules (Maybe.withDefault "" s.toDraft)
    }


{-| Closes the calendar, throws away a half-made choice, and gives the focus
back to the from field. The focus only moves if the calendar was open.
-}
close : State -> ( State, Cmd Msg )
close (State s) =
    closePopup s



-- UPDATE


type Side
    = FromSide
    | ToSide


{-| What the view knows about the limits when it sends a message: plain data,
the same idea as the bounds of `Klar.Calendar`.
-}
type alias Limits =
    { bounds : Bounds
    , maxDays : Maybe Int
    }


{-| The texts of the two inputs, read in the view with the rules of the field.
-}
type alias Readings =
    { from : Reading
    , to : Reading
    }


{-| The messages of a period field. Wrap them in one constructor of your own
`Msg`, give that constructor to `view`, and pass what comes back to `update`.

A message holds plain data only (the view reads the texts with the field's
rules and sends what it found), so messages can be compared with `==`, logged
and kept in the history of the Elm debugger.

-}
type Msg
    = Typed Side Limits Reading
    | Blurred Side Limits Reading
    | Entered Side Limits Readings
    | OpenRequested Limits Readings
    | Toggled Limits Readings
    | Closed
    | Left
    | Escaped
    | CalendarMsg Calendar.Msg
    | PickedPreset Date Date
    | MovedToPreset String
    | Cleared
    | Noop


{-| Handles a message of the field: typing, keys, the calendar button, the
calendar, the quick choices and the clear button. Returns the new state and the
command that moves the browser focus. Map the command with the constructor of
your own `Msg`.

    PeriodMsg m ->
        let
            ( period, cmd ) =
                DateRangePicker.update m model.period
        in
        ( { model | period = period }, Cmd.map PeriodMsg cmd )

-}
update : Msg -> State -> ( State, Cmd Msg )
update msg (State s) =
    case msg of
        Typed side limits reading ->
            let
                draft =
                    setDraft side reading.text s
            in
            ( State
                (if Parse.isComplete reading.text then
                    accept side limits.maxDays reading draft

                 else
                    draft
                )
            , Cmd.none
            )

        Blurred side limits reading ->
            ( State (commit side limits.maxDays reading s), Cmd.none )

        Entered side limits readings ->
            if draftOf side s /= Nothing && problemOf side s == Nothing then
                ( State (commit side limits.maxDays (readingOf side readings) s), Cmd.none )

            else
                openPopup limits readings s

        OpenRequested limits readings ->
            openPopup limits readings s

        Toggled limits readings ->
            if s.open then
                closePopup s

            else
                openPopup limits readings s

        Closed ->
            closePopup s

        Left ->
            ( State { s | open = False }, Cmd.none )

        Escaped ->
            case Calendar.back s.calendar of
                Just ( calendar, cmd ) ->
                    ( State { s | calendar = calendar }, Cmd.map CalendarMsg cmd )

                Nothing ->
                    closePopup s

        CalendarMsg inner ->
            let
                ( calendar, cmd, event ) =
                    CalendarCore.updateWithEvent inner s.calendar
            in
            case event of
                Just (CalendarCore.RangePicked start finish) ->
                    apply start finish { s | calendar = calendar }

                _ ->
                    ( State { s | calendar = calendar }, Cmd.map CalendarMsg cmd )

        PickedPreset start finish ->
            apply start finish s

        MovedToPreset id ->
            ( State s, Internal.focus id Noop )

        Cleared ->
            ( State
                { s
                    | from = Nothing
                    , to = Nothing
                    , fromDraft = Nothing
                    , toDraft = Nothing
                    , fromProblem = Nothing
                    , toProblem = Nothing
                    , rangeProblem = Nothing
                    , calendar = Calendar.setRange Nothing s.calendar
                }
            , Internal.focus (fromId s.id) Noop
            )

        Noop ->
            ( State s, Cmd.none )


draftOf : Side -> Inner -> Maybe String
draftOf side s =
    case side of
        FromSide ->
            s.fromDraft

        ToSide ->
            s.toDraft


problemOf : Side -> Inner -> Maybe Problem
problemOf side s =
    case side of
        FromSide ->
            s.fromProblem

        ToSide ->
            s.toProblem


dateOf : Side -> Inner -> Maybe Date
dateOf side s =
    case side of
        FromSide ->
            s.from

        ToSide ->
            s.to


readingOf : Side -> Readings -> Reading
readingOf side readings =
    case side of
        FromSide ->
            readings.from

        ToSide ->
            readings.to


setDraft : Side -> String -> Inner -> Inner
setDraft side typed s =
    case side of
        FromSide ->
            { s | fromDraft = Just typed, fromProblem = Nothing, rangeProblem = Nothing }

        ToSide ->
            { s | toDraft = Just typed, toProblem = Nothing, rangeProblem = Nothing }


{-| A date that the limits no longer allow: its text stays in its input, with
the problem, and the side has no accepted date.
-}
setProblem : Side -> String -> Problem -> Inner -> Inner
setProblem side shown problem s =
    case side of
        FromSide ->
            { s | from = Nothing, fromDraft = Just shown, fromProblem = Just problem }

        ToSide ->
            { s | to = Nothing, toDraft = Just shown, toProblem = Just problem }


{-| Keeps what the reading of a field's text says, leaving the text as typed. A
reading of another text (the field changed after the view made it) is ignored.
-}
accept : Side -> Maybe Int -> Reading -> Inner -> Inner
accept side maxDays reading s =
    case Parse.apply (draftOf side s) reading of
        Nothing ->
            s

        Just result ->
            checkPeriod maxDays
                (case ( side, result ) of
                    ( FromSide, Ok maybeDate ) ->
                        { s | from = maybeDate, fromProblem = Nothing }

                    ( FromSide, Err problem ) ->
                        { s | from = Nothing, fromProblem = Just problem }

                    ( ToSide, Ok maybeDate ) ->
                        { s | to = maybeDate, toProblem = Nothing }

                    ( ToSide, Err problem ) ->
                        { s | to = Nothing, toProblem = Just problem }
                )


{-| Like `accept`, and replaces the text with the formatted date.
-}
commit : Side -> Maybe Int -> Reading -> Inner -> Inner
commit side maxDays reading s =
    let
        accepted =
            accept side maxDays reading s
    in
    if problemOf side accepted == Nothing && Parse.apply (draftOf side s) reading /= Nothing then
        case side of
            FromSide ->
                { accepted | fromDraft = Nothing }

            ToSide ->
                { accepted | toDraft = Nothing }

    else
        accepted


{-| Compares the two accepted dates.
-}
checkPeriod : Maybe Int -> Inner -> Inner
checkPeriod maxDays s =
    case ( s.from, s.to ) of
        ( Just start, Just finish ) ->
            if Util.after start finish then
                { s | rangeProblem = Just RangeOrder }

            else
                case maxDays of
                    Just limit ->
                        if Date.diffDays start finish + 1 > limit then
                            { s | rangeProblem = Just (RangeTooLong limit) }

                        else
                            { s | rangeProblem = Nothing }

                    Nothing ->
                        { s | rangeProblem = Nothing }

        _ ->
            { s | rangeProblem = Nothing }


openPopup : Limits -> Readings -> Inner -> ( State, Cmd Msg )
openPopup limits readings s =
    let
        committed =
            s
                |> commit FromSide limits.maxDays readings.from
                |> commit ToSide limits.maxDays readings.to

        target =
            (case committed.from of
                Just start ->
                    start

                Nothing ->
                    Maybe.withDefault (Calendar.focusedDay committed.calendar) limits.bounds.today
            )
                |> Util.clampTo limits.bounds.min limits.bounds.max

        calendar =
            committed.calendar
                |> Calendar.setRange (Maybe.map2 Tuple.pair committed.from committed.to)
                |> Calendar.showDate target
    in
    ( State { committed | open = True, calendar = calendar }
    , Cmd.map CalendarMsg (Calendar.focus calendar)
    )


closePopup : Inner -> ( State, Cmd Msg )
closePopup s =
    ( State
        { s
            | open = False
            , calendar = Calendar.setRange (Maybe.map2 Tuple.pair s.from s.to) s.calendar
        }
    , if s.open then
        Internal.focus (fromId s.id) Noop

      else
        Cmd.none
    )


apply : Date -> Date -> Inner -> ( State, Cmd Msg )
apply start finish s =
    ( State
        { s
            | from = Just start
            , to = Just finish
            , fromDraft = Nothing
            , toDraft = Nothing
            , fromProblem = Nothing
            , toProblem = Nothing
            , rangeProblem = Nothing
            , open = False
            , calendar = Calendar.setRange (Just ( start, finish )) s.calendar
        }
    , Internal.focus (fromId s.id) Noop
    )


sideSuffix : Side -> String
sideSuffix side =
    case side of
        FromSide ->
            "-from"

        ToSide ->
            "-to"


fromId : String -> String
fromId id =
    id ++ "-from"


toId : String -> String
toId id =
    id ++ "-to"



-- ATTRIBUTES


{-| A setting of a period field. Make them with the functions below and pass a
list to `view`, `setLimits` or `open`; later attributes win over earlier ones.
-}
type Attribute msg
    = Attribute (Config -> Config)


type PresetChoice
    = DefaultPresets
    | CustomPresets (List Preset)


{-| A quick choice in the list beside the calendar: the label of its button and
the period it selects. Make one with `preset`, which also puts the two days in
order, and give a list of them to `presets`.
-}
type Preset
    = Preset
        { label : String
        , from : Date
        , to : Date
        }


type alias Config =
    { field : Field.Config
    , placeholder : Maybe String
    , name : Maybe String
    , disabled : Bool
    , readOnly : Bool
    , clearable : Bool
    , size : Size
    , locale : Locale
    , today : Maybe Date
    , min : Maybe Date
    , max : Maybe Date
    , disabledWhen : Date -> Bool
    , markers : List Calendar.Marker
    , weekNumbers : Bool
    , alignEnd : Bool
    , maxRangeDays : Maybe Int
    , presets : PresetChoice
    }


configure : List (Attribute msg) -> Config
configure attributes =
    List.foldl (\(Attribute change) config -> change config)
        { field = Field.empty
        , placeholder = Nothing
        , name = Nothing
        , disabled = False
        , readOnly = False
        , clearable = False
        , size = Medium
        , locale = Locale.default
        , today = Nothing
        , min = Nothing
        , max = Nothing
        , disabledWhen = \_ -> False
        , markers = []
        , weekNumbers = False
        , alignEnd = False
        , maxRangeDays = Nothing
        , presets = DefaultPresets
        }
        attributes


updateField : (Field.Config -> Field.Config) -> Attribute msg
updateField change =
    Attribute (\config -> { config | field = change config.field })


{-| The label above the field. It also names the group that holds the two
inputs, and each input adds "from date" or "to date" to it. Give every field a
label, or hide it with `labelHidden`; without one the group is called "Choose
period".
-}
label : String -> Attribute msg
label given =
    updateField (Field.setLabel given)


{-| Keeps the label for screen readers but does not show it, for a field in a
toolbar or a table row. Needs `label`.
-}
labelHidden : Attribute msg
labelHidden =
    updateField Field.setLabelHidden


{-| A short help text below the field. It is linked to both inputs with
`aria-describedby`, so screen readers read it together with the field.
-}
hint : String -> Attribute msg
hint given =
    updateField (Field.setHint given)


{-| An error message from your application, shown below the field and announced
to screen readers: a required period that is missing, or a period that
conflicts with another field. While the picker has a complaint of its own about
the dates ("Invalid date", "The start date cannot be after the end date"), that
message is shown instead.

    DateRangePicker.error "Choose a report period"

-}
error : String -> Attribute msg
error given =
    updateField (Field.setError (Just given))


{-| Like `error`, but takes a `Maybe`: `Nothing` means no error. Convenient when
the message lives in a `Maybe` in your model.

    DateRangePicker.errorMaybe model.periodError

-}
errorMaybe : Maybe String -> Attribute msg
errorMaybe given =
    updateField (Field.setError given)


{-| Marks the field as required: an asterisk after the label, and
`aria-required` on both inputs. The picker does not enforce it; when the period
is missing, test `value` for `Nothing` yourself and pass an `error`.
-}
required : Attribute msg
required =
    updateField (Field.setRequired True)


{-| Text shown after the label of a field that is not `required`, such as
"(optional)". Default: none.
-}
optionalText : String -> Attribute msg
optionalText given =
    updateField (Field.setOptionalText given)


{-| The text shown in the two empty inputs. Default: the format hint of the
locale, `yyyy-mm-dd` in English.
-}
placeholder : String -> Attribute msg
placeholder given =
    Attribute (\config -> { config | placeholder = Just given })


{-| The `name` of the two inputs for a plain HTML `form`: `<name>-from` and
`<name>-to`. The values sent are the texts in the inputs, formatted for the
locale. Default: none.
-}
name : String -> Attribute msg
name given =
    Attribute (\config -> { config | name = Just given })


{-| Disables the field and its calendar button: the two inputs cannot be focused
or changed and the calendar cannot be opened. Takes a `Bool` so that it can come
straight from your model, for example while a form is saving. Default: `False`.
-}
disabled : Bool -> Attribute msg
disabled given =
    Attribute (\config -> { config | disabled = given })


{-| The period can be seen, selected and copied but not changed, and the
calendar does not open. Unlike `disabled`, the inputs can still be focused.
Default: `False`.
-}
readOnly : Bool -> Attribute msg
readOnly given =
    Attribute (\config -> { config | readOnly = given })


{-| Shows a small × button in the field while one of the inputs has text; it
empties both inputs and puts the focus back in the first. The button is not in
the tab order, and its accessible name is "Clear field". Default: no button.
-}
clearable : Attribute msg
clearable =
    Attribute (\config -> { config | clearable = True })


{-| The size of the field, a `Size` from [Klar.Theme](Klar-Theme).
Default: `Medium`.
-}
size : Size -> Attribute msg
size given =
    Attribute (\config -> { config | size = given })


{-| The language of the built-in text (placeholder, button labels, quick choices,
error messages, names of months and weekdays) and the format in which the fields
show a date: `2026-10-20` in English, `20.10.2026` in Norwegian. Default:
`Locale.default`, which is English. See [Klar.Locale](Klar-Locale).
-}
locale : Locale -> Attribute msg
locale given =
    Attribute (\config -> { config | locale = given })


{-| Today, supplied by the application (the library never reads the clock). It
marks the day in the calendar, builds the standard quick choices, completes the
short forms `20.10`, `t`, `+3` and `-7` in the text fields, and decides how a
two-digit year is read.

Without it there are no standard quick choices, the short forms are not
understood, and an empty field opens its calendar on January 2000 (or on the
nearest month inside `min` and `max`).

-}
today : Date -> Attribute msg
today given =
    Attribute (\config -> { config | today = Just given })


{-| The earliest date that can be chosen or typed. A typed date before it shows
"The date cannot be before" followed by the limit, the calendar disables the
earlier days, and the quick choices are cut to it (one that ends before it is
disabled). Default: no limit.
-}
min : Date -> Attribute msg
min given =
    Attribute (\config -> { config | min = Just given })


{-| The latest date that can be chosen or typed. A typed date after it shows
"The date cannot be after" followed by the limit, the calendar disables the
later days, and the quick choices are cut to it (one that starts after it is
disabled). Default: no limit.
-}
max : Date -> Attribute msg
max given =
    Attribute (\config -> { config | max = Just given })


{-| Dates that cannot be used, such as weekends or public holidays. The calendar
shows them disabled and a typed one shows "The date is not available". A quick
choice never starts or ends on one: it is cut inward to the nearest allowed day,
and disabled when no day of it is allowed. Default: every date is allowed.

    DateRangePicker.disabledWhen (\day -> Date.weekday day >= 6)

-}
disabledWhen : (Date -> Bool) -> Attribute msg
disabledWhen predicate =
    Attribute (\config -> { config | disabledWhen = predicate })


{-| The longest period allowed, in days, counting both end days. In the calendar,
days that would make the period longer are disabled once the first day is
chosen; a typed period that is longer shows "The period cannot be longer than"
followed by the number of days, and quick choices that are longer (after being
cut to the limits) are disabled. Default: no limit.

    DateRangePicker.maxRangeDays 90

-}
maxRangeDays : Int -> Attribute msg
maxRangeDays given =
    Attribute (\config -> { config | maxRangeDays = Just given })


{-| Marks on days in the calendar, such as deliveries or deadlines. Make them
with `Calendar.dot` and `Calendar.count` from [Klar.Calendar](Klar-Calendar).
Default: none.
-}
markers : List Calendar.Marker -> Attribute msg
markers given =
    Attribute (\config -> { config | markers = given })


{-| Shows ISO 8601 week numbers in the calendar. Default: off.
-}
weekNumbers : Attribute msg
weekNumbers =
    Attribute (\config -> { config | weekNumbers = True })


{-| Aligns the right edge of the calendar popup with the right edge of the
field, instead of the left edges. Use it for a field near the right side of the
page, so that the popup does not run out of the window.
-}
alignEnd : Attribute msg
alignEnd =
    Attribute (\config -> { config | alignEnd = True })


{-| Your own quick choices instead of the standard ones. They are shown even
when the field has no `today`, and follow the same rules as the standard ones
(cut to the limits, disabled when nothing is left).

    DateRangePicker.presets
        [ DateRangePicker.preset "This quarter" quarterStart quarterEnd
        , DateRangePicker.preset "Last quarter" previousStart previousEnd
        ]

-}
presets : List Preset -> Attribute msg
presets given =
    Attribute (\config -> { config | presets = CustomPresets given })


{-| A quick choice with a label and a period. The two days may be given in
either order. When the user clicks it, the period is cut to `min` and `max` and
inward to the nearest days that `disabledWhen` allows; the button is disabled if
nothing is left or what is left is longer than `maxRangeDays`.

    DateRangePicker.preset "This quarter" quarterStart quarterEnd

-}
preset : String -> Date -> Date -> Preset
preset labelText start finish =
    Preset { label = labelText, from = Util.earlier start finish, to = Util.later start finish }


{-| No list of quick choices: only the calendar is shown.
-}
noPresets : Attribute msg
noPresets =
    Attribute (\config -> { config | presets = CustomPresets [] })


rulesOf : Config -> Rules
rulesOf config =
    { locale = config.locale
    , today = config.today
    , min = config.min
    , max = config.max
    , isDisabled = config.disabledWhen
    }


limitsOf : Config -> Limits
limitsOf config =
    { bounds = Parse.boundsOf (rulesOf config)
    , maxDays = config.maxRangeDays
    }


{-| The attributes of the calendar in the popup. It has no annotation, so that it
fits the type of the calendar's attributes whatever their type parameters are.
-}
calendarAttributes config =
    List.filterMap identity
        [ Maybe.map CalendarCore.today config.today
        , Maybe.map Calendar.min config.min
        , Maybe.map Calendar.max config.max
        , Maybe.map Calendar.maxRangeDays config.maxRangeDays
        , Just (Calendar.disabledWhen config.disabledWhen)
        , Just (Calendar.locale config.locale)
        , Just (Calendar.markers config.markers)
        , Just CalendarCore.silent
        , if config.weekNumbers then
            Just Calendar.weekNumbers

          else
            Nothing
        ]


{-| The quick choices for this configuration.
-}
presetList : Config -> List Preset
presetList config =
    case ( config.presets, config.today ) of
        ( CustomPresets list, _ ) ->
            list

        ( DefaultPresets, Just day ) ->
            defaultPresets config.locale day

        ( DefaultPresets, Nothing ) ->
            []


defaultPresets : Locale -> Date -> List Preset
defaultPresets lang day =
    let
        pick nb en =
            Locale.pick lang { nb = nb, en = en }

        firstDay =
            Locale.firstDayOfWeek lang

        previousMonth =
            Date.addMonths -1 (Date.startOfMonth day)

        previousQuarter =
            Date.addMonths -3 (Date.startOfQuarter day)
    in
    [ preset (pick "I dag" "Today") day day
    , preset (pick "Siste 7 dager" "Last 7 days") (Date.addDays -6 day) day
    , preset (pick "Siste 30 dager" "Last 30 days") (Date.addDays -29 day) day
    , preset (pick "Denne uken" "This week") (Date.startOfWeek firstDay day) (Date.endOfWeek firstDay day)
    , preset (pick "Denne måneden" "This month") (Date.startOfMonth day) (Date.endOfMonth day)
    , preset (pick "Forrige måned" "Last month") previousMonth (Date.endOfMonth previousMonth)
    , preset (pick "Dette kvartalet" "This quarter") (Date.startOfQuarter day) (Date.endOfQuarter day)
    , preset (pick "Forrige kvartal" "Last quarter") previousQuarter (Date.endOfQuarter previousQuarter)
    , preset (pick "Dette året" "This year") (Date.startOfYear day) (Date.endOfYear day)
    ]


{-| The period a quick choice gives, or the reason why it cannot be used.

The period is cut to what the user could choose by hand: to `min` and `max`, and
then inward past the days that `disabledWhen` excludes, so that it starts and
ends on a day that is allowed. Days in between may be disabled, as in the
calendar. The reason is a `Problem`, which has a message in the field's
language: the choice lies before `min` or after `max`, no day of it is left to
choose, or what is left is longer than `maxRangeDays`.

-}
resolvePreset : Config -> Preset -> Result Problem ( Date, Date )
resolvePreset config (Preset option) =
    let
        early =
            Util.earlier option.from option.to

        late =
            Util.later option.from option.to

        -- the choice, cut to min and max
        lowest =
            Util.clampTo config.min config.max early

        highest =
            Util.clampTo config.min config.max late

        beforeMin =
            config.min
                |> Maybe.andThen
                    (\bound ->
                        if Util.before late bound then
                            Just bound

                        else
                            Nothing
                    )

        afterMax =
            config.max
                |> Maybe.andThen
                    (\bound ->
                        if Util.after early bound then
                            Just bound

                        else
                            Nothing
                    )
    in
    case ( beforeMin, afterMax ) of
        ( Just bound, _ ) ->
            Err (TooEarly bound)

        ( Nothing, Just bound ) ->
            Err (TooLate bound)

        ( Nothing, Nothing ) ->
            case firstAllowed config.disabledWhen lowest highest of
                Nothing ->
                    Err Unavailable

                Just start ->
                    let
                        finish =
                            lastAllowed config.disabledWhen start highest
                    in
                    case config.maxRangeDays of
                        Just limit ->
                            if Date.diffDays start finish + 1 > limit then
                                Err (RangeTooLong limit)

                            else
                                Ok ( start, finish )

                        Nothing ->
                            Ok ( start, finish )


{-| The first day from `day` up to `last` that is not disabled. It stops on
`last` itself, so it ends even where a step of one day would not move the date.
-}
firstAllowed : (Date -> Bool) -> Date -> Date -> Maybe Date
firstAllowed isDisabled day last =
    if Util.after day last then
        Nothing

    else if isDisabled day then
        if day == last then
            Nothing

        else
            firstAllowed isDisabled (Date.addDays 1 day) last

    else
        Just day


{-| The last day from `day` down to `first` that is not disabled. `first` itself
is returned when every later day is disabled, so it must be a day that is
allowed.
-}
lastAllowed : (Date -> Bool) -> Date -> Date -> Date
lastAllowed isDisabled first day =
    if Util.after day first && isDisabled day then
        lastAllowed isDisabled first (Date.addDays -1 day)

    else
        day



-- VIEW


type alias Strings =
    { placeholder : String
    , fromDate : String
    , toDate : String
    , openCalendar : String
    , dialog : String
    , presets : String
    , pickStart : String
    , pickEnd : String
    , clear : String
    }


strings : Locale -> Strings
strings lang =
    Locale.pick lang
        { nb =
            { placeholder = "dd.mm.åååå"
            , fromDate = "fra dato"
            , toDate = "til dato"
            , openCalendar = "Åpne kalender"
            , dialog = "Velg periode"
            , presets = "Hurtigvalg"
            , pickStart = "Velg startdato"
            , pickEnd = "Velg sluttdato"
            , clear = "Tøm feltet"
            }
        , en =
            { placeholder = "yyyy-mm-dd"
            , fromDate = "from date"
            , toDate = "to date"
            , openCalendar = "Open calendar"
            , dialog = "Choose period"
            , presets = "Quick choices"
            , pickStart = "Choose the start date"
            , pickEnd = "Choose the end date"
            , clear = "Clear field"
            }
        }


{-| The field: two text inputs (from and to) with a calendar button, and the
popup with the calendar and the quick choices while it is open. The first
argument wraps the picker's messages in one of yours.

    DateRangePicker.view PeriodMsg
        [ DateRangePicker.label "Report period"
        , DateRangePicker.today model.today
        ]
        model.period

-}
view : (Msg -> msg) -> List (Attribute msg) -> State -> Html msg
view toMsg attributes (State s) =
    let
        config =
            configure attributes

        rules =
            rulesOf config

        limits =
            limitsOf config

        -- The texts are read where the rules are known: here, at the moment of
        -- the event (the input's own text), so a message holds plain data. The
        -- other input is read from the state: the user is not typing in it.
        pending =
            pendingReadings rules s

        readingsWith side typed =
            case side of
                FromSide ->
                    { pending | from = Parse.read rules typed }

                ToSide ->
                    { pending | to = Parse.read rules typed }

        isOpen_ =
            s.open && not inactive

        placeholderText =
            Maybe.withDefault words.placeholder config.placeholder

        words =
            strings config.locale

        choosing =
            if s.open then
                Calendar.anchor s.calendar

            else
                Nothing

        format maybeDate =
            maybeDate |> Maybe.map (Format.date config.locale) |> Maybe.withDefault ""

        fromShown =
            case choosing of
                Just begin ->
                    Format.date config.locale begin

                Nothing ->
                    case s.fromDraft of
                        Just typed ->
                            typed

                        Nothing ->
                            format s.from

        toShown =
            case choosing of
                Just _ ->
                    ""

                Nothing ->
                    case s.toDraft of
                        Just typed ->
                            typed

                        Nothing ->
                            format s.to

        problem =
            [ s.fromProblem, s.toProblem, s.rangeProblem ]
                |> List.filterMap identity
                |> List.head

        field =
            config.field
                |> Field.setId (fromId s.id)
                |> (case problem of
                        Just found ->
                            Field.setError (Just (Parse.message config.locale found))

                        Nothing ->
                            identity
                   )

        -- What `Field.controlAttributes` gives the first input, for the second one:
        -- an id of its own (`controlAttributes` would give it the id of the first,
        -- and a second `id` after that one would be a duplicate), described by the
        -- hint and the error message of the field, whose ids come from the first.
        toControlAttributes =
            Attr.id (toId s.id)
                :: Field.describedByAttributes field
                ++ [ Internal.attrIf (field.error /= Nothing) (Attr.attribute "aria-invalid" "true")
                   , Internal.attrIf field.required (Attr.attribute "aria-required" "true")
                   ]

        inactive =
            config.disabled || config.readOnly

        showClear =
            config.clearable && (fromShown /= "" || toShown /= "") && not inactive

        groupLabel =
            Maybe.withDefault words.dialog config.field.label

        input side shown extra =
            Html.input
                (extra
                    ++ [ Internal.cls [ "klar-input__control", "klar-daterange__control" ]
                       , Attr.type_ "text"
                       , Attr.value shown
                       , Attr.placeholder placeholderText
                       , Internal.attrMaybe (\given -> Attr.name (given ++ sideSuffix side)) config.name
                       , Attr.disabled config.disabled
                       , Attr.readonly config.readOnly
                       , Attr.attribute "autocomplete" "off"
                       , Attr.attribute "aria-haspopup" "dialog"
                       , Attr.attribute "aria-keyshortcuts" "Alt+ArrowDown"
                       , Events.onInput (\typed -> toMsg (Typed side limits (Parse.read rules typed)))
                       , Popup.onBlurValue (\typed -> toMsg (Blurred side limits (Parse.read rules typed)))
                       , if inactive then
                            Internal.noAttr

                         else
                            Popup.onFieldKeys
                                [ ( "ArrowDown", \typed -> toMsg (OpenRequested limits (readingsWith side typed)) )
                                , ( "Alt+ArrowDown", \typed -> toMsg (OpenRequested limits (readingsWith side typed)) )
                                , ( "Enter", \typed -> toMsg (Entered side limits (readingsWith side typed)) )
                                ]
                       ]
                )
                []
    in
    -- stable: the field makes messages of its own while the user types
    Field.view field
        (Html.div [ Internal.cls [ "klar-anchor", "klar-anchor--block", "klar-daterange" ] ]
            [ Html.div
                [ Internal.cls
                    [ "klar-input"
                    , "klar-input--" ++ Internal.sizeSuffix config.size
                    , "klar-daterange__box"
                    , if field.error /= Nothing then
                        "klar-input--invalid"

                      else
                        ""
                    , if config.disabled then
                        "klar-input--disabled"

                      else
                        ""
                    , if config.readOnly then
                        "klar-input--readonly"

                      else
                        ""
                    ]
                , Attr.attribute "role" "group"
                , Attr.attribute "aria-label" groupLabel
                ]
                [ input FromSide
                    fromShown
                    (Field.controlAttributes field
                        ++ [ Attr.attribute "aria-label" (groupLabel ++ ", " ++ words.fromDate) ]
                    )
                , Html.span [ Internal.cls [ "klar-daterange__separator" ], Attr.attribute "aria-hidden" "true" ] [ Html.text "–" ]
                , input ToSide
                    toShown
                    (toControlAttributes ++ [ Attr.attribute "aria-label" (groupLabel ++ ", " ++ words.toDate) ])
                , if showClear then
                    Html.button
                        [ Internal.cls [ "klar-input__clear" ]
                        , Attr.type_ "button"
                        , Attr.tabindex -1
                        , Attr.attribute "aria-label" words.clear
                        , Events.onClick (toMsg Cleared)
                        ]
                        [ Icon.view Icon.close ]

                  else
                    Html.text ""
                , Html.button
                    [ Internal.cls [ "klar-daterange__button" ]
                    , Attr.type_ "button"
                    , Attr.id (s.id ++ "-button")
                    , Attr.tabindex -1
                    , Attr.attribute "aria-label" words.openCalendar
                    , Attr.attribute "aria-haspopup" "dialog"
                    , Attr.attribute "aria-expanded" (boolString isOpen_)
                    , Internal.attrIf isOpen_ (Attr.attribute "aria-controls" (s.id ++ "-popup"))
                    , Attr.disabled inactive
                    , Events.onClick (toMsg (Toggled limits pending))
                    ]
                    [ Icon.view Icon.calendar ]
                ]
            , if isOpen_ then
                viewPopup toMsg config words s

              else
                Html.text ""
            ]
        )


viewPopup : (Msg -> msg) -> Config -> Strings -> Inner -> Html msg
viewPopup toMsg config words s =
    let
        current =
            Maybe.map2 Tuple.pair s.from s.to

        options =
            presetList config

        resolvedAll =
            List.map (resolvePreset config) options

        isPressed resolved =
            case resolved of
                Ok period ->
                    Just period == current && not (Calendar.isChoosing s.calendar)

                Err _ ->
                    False

        -- The quick choices that can be used, by index.
        enabled =
            resolvedAll
                |> List.indexedMap Tuple.pair
                |> List.filterMap
                    (\( index, resolved ) ->
                        case resolved of
                            Ok _ ->
                                Just index

                            Err _ ->
                                Nothing
                    )

        -- The one quick choice in the tab order: the pressed one, else the first
        -- that can be used. The arrow keys move between them (`presetKeys`).
        tabStop =
            case List.filter (\( _, resolved ) -> isPressed resolved) (List.indexedMap Tuple.pair resolvedAll) of
                ( index, _ ) :: _ ->
                    Just index

                [] ->
                    List.head enabled

        presetId index =
            s.id ++ "-popup-preset-" ++ String.fromInt index

        presetKeys =
            Events.custom "keydown"
                (Decode.map2 Tuple.pair (Decode.field "key" Decode.string) (Decode.at [ "target", "id" ] Decode.string)
                    |> Decode.andThen
                        (\( key, targetId ) ->
                            case List.head (List.filter (\index -> presetId index == targetId) enabled) of
                                Nothing ->
                                    Decode.fail "not on a quick choice"

                                Just index ->
                                    let
                                        before =
                                            List.filter (\other -> other < index) enabled

                                        after =
                                            List.filter (\other -> other > index) enabled

                                        go target =
                                            Decode.succeed
                                                { message = toMsg (MovedToPreset (presetId (Maybe.withDefault index target)))
                                                , stopPropagation = True
                                                , preventDefault = True
                                                }
                                    in
                                    if key == "ArrowDown" || key == "ArrowRight" then
                                        go (List.head after)

                                    else if key == "ArrowUp" || key == "ArrowLeft" then
                                        go (List.head (List.reverse before))

                                    else if key == "Home" then
                                        go (List.head enabled)

                                    else if key == "End" then
                                        go (List.head (List.reverse enabled))

                                    else
                                        Decode.fail "not a key of the quick choices"
                        )
                )

        viewPreset index ((Preset fields) as option) =
            let
                resolved =
                    resolvePreset config option

                period =
                    Result.toMaybe resolved
            in
            Button.view
                ([ Button.small
                 , Button.ghost
                 , Button.id (presetId index)
                 , Button.disabled (period == Nothing)
                 , Button.pressed (isPressed resolved)
                 , Button.htmlAttrs
                    [ Internal.cls [ "klar-daterange__preset" ]
                    , Attr.tabindex
                        (if tabStop == Just index then
                            0

                         else
                            -1
                        )
                    ]
                 ]
                    ++ (case resolved of
                            Ok ( start, finish ) ->
                                [ Button.onClick (toMsg (PickedPreset start finish)) ]

                            Err problem ->
                                -- The reason is the tooltip of the dimmed button and its
                                -- accessible description.
                                [ Button.title (Parse.message config.locale problem) ]
                       )
                )
                fields.label

        status =
            case ( Calendar.anchor s.calendar, current ) of
                ( Just _, _ ) ->
                    words.pickEnd

                ( Nothing, Just ( start, finish ) ) ->
                    Format.date config.locale start
                        ++ " – "
                        ++ Format.date config.locale finish
                        ++ "  ·  "
                        ++ daysText config.locale (Date.diffDays start finish + 1)

                ( Nothing, Nothing ) ->
                    words.pickStart
    in
    Popup.dialog
        { prefix = s.id ++ "-popup"
        , label = Popup.dialogLabel config.field.label words.dialog
        , describedBy = Just (s.id ++ "-popup-status")
        , classes = [ "klar-daterange__popup" ]
        , alignEnd = config.alignEnd
        , onClose = toMsg Closed
        , onEscape = toMsg Escaped
        , onLeave = toMsg Left
        , noop = toMsg Noop
        }
        [ Html.div [ Internal.cls [ "klar-daterange__layout" ] ]
            [ if List.isEmpty options then
                Html.text ""

              else
                Html.div
                    [ Internal.cls [ "klar-daterange__presets" ]
                    , Attr.attribute "role" "group"
                    , Attr.attribute "aria-label" words.presets
                    , presetKeys
                    ]
                    (List.indexedMap viewPreset options)
            , Html.div [ Internal.cls [ "klar-daterange__main" ] ]
                [ Calendar.view (\inner -> toMsg (CalendarMsg inner)) (calendarAttributes config) s.calendar
                , Html.div
                    [ Internal.cls [ "klar-daterange__status" ]
                    , Attr.id (s.id ++ "-popup-status")
                    , Attr.attribute "aria-live" "polite"
                    ]
                    [ Html.text status ]
                ]
            ]
        ]


daysText : Locale -> Int -> String
daysText lang n =
    String.fromInt n
        ++ " "
        ++ Format.plural lang n (Locale.pick lang { nb = { one = "dag", other = "dager" }, en = { one = "day", other = "days" } })


boolString : Bool -> String
boolString given =
    if given then
        "true"

    else
        "false"
