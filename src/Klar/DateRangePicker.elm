module Klar.DateRangePicker exposing
    ( view
    , State, init, Msg, update
    , range, from, to, isInvalid, setRange, clear, setText, validate
    , isOpen, open, close, visibleMonth
    , Preset, preset, presets, noPresets
    , Attribute, today, min, max, maxRangeDays, disabledWhen
    , markers, weekNumbers, alignEnd
    , label, labelHidden, hint, error, errorMaybe, required, optionalText
    , size, locale, disabled, readOnly, clearable
    )

{-| A period field: a from date and a to date in one control, with one calendar
that shows two months and a list of quick choices.

Use when: the user chooses a period, as in reports, filters and bookings.
Do not use when: the user enters a single date (as `Klar.DatePicker`).
Quick path: `init`, `update`, `view`, `range`

For a single date see [Klar.DatePicker](Klar-DatePicker).

    import Klar.DateRangePicker as DateRangePicker

    -- model
    { period : DateRangePicker.State }   -- DateRangePicker.init "report-period"

    -- msg
    PeriodMsg DateRangePicker.Msg

    -- update
    PeriodMsg m ->
        let
            ( period, cmd ) =
                DateRangePicker.update m model.period
        in
        ( { model | period = period }, Cmd.map PeriodMsg cmd )

    -- view
    DateRangePicker.view PeriodMsg
        [ DateRangePicker.label "Report period"
        , DateRangePicker.today model.today
        , DateRangePicker.maxRangeDays 90
        ]
        model.period

    -- read
    DateRangePicker.range model.period   -- Maybe ( Date, Date )

Here `model.today` is a [Klar.Date](Klar-Date) value that the application keeps;
the library never reads the clock. The state holds the period, and there are no
out-messages: compare `range` before and after `update` to react to a change.

Choose the period with two clicks in the calendar. The choice applies on the
second click and the popup closes. Between the clicks the days from the first
day to the one under the mouse (or the keyboard focus) are highlighted, the
first field shows the first day, and the second field is empty. `Escape` closes
the popup and throws away a half-made choice.

The quick choices ("Today", "Last 7 days", "Last 30 days", "This month", "Last
month" and "This year" in English) are computed from the `today` the application
supplies. Each one gives the part of its period that the user could choose by
hand: it is cut to `min` and `max`, and then inward past the days that
`disabledWhen` excludes, so it starts and ends on a day that is allowed (days in
between may be disabled, as in the calendar). A quick choice is disabled when
nothing is left of it, or when what is left is longer than `maxRangeDays`; its
tooltip then gives the reason. Without `today` the list is empty. Give your own
with `presets`, or turn them off with `noPresets`.

The two fields take typed dates like [Klar.DatePicker](Klar-DatePicker); the
forms it understands are listed there. `range` is `Just` only when both dates
are valid and `from` is not after `to`; `from` and `to` give the single dates,
also when the period as a whole is not valid yet. When a date or the period is
not valid, the field shows a message such as "The start date cannot be after the
end date" or "The period cannot be longer than 90 days", and `isInvalid` is
`True`. A form should call `validate` when it is submitted, because the user may
never have left the fields.

Keyboard: `ArrowDown` or `Alt+ArrowDown` in either text field opens the
calendar. So does `Enter`, unless the user has just typed something that was not
taken yet: then `Enter` takes the text. The keys inside the calendar are those of
[Klar.Calendar](Klar-Calendar). `Escape` closes the popup (inside the month and
year choosers it goes back one step first), and `Tab` out of the popup closes it.

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

@docs range, from, to, isInvalid, setRange, clear, setText, validate


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

@docs size, locale, disabled, readOnly, clearable

-}

import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Events
import Klar.Button as Button
import Klar.Calendar as Calendar
import Klar.Calendar.Parse as Parse exposing (Problem(..), Rules)
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
`range`, `from`, `to` and `isInvalid`.
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
        , calendar = Calendar.initRange (id ++ "-popup-cal")
        }


{-| The accepted period as `( from, to )`, both days included. It is `Just` only
when both dates are valid, `from` is not after `to`, and the period is not
longer than `maxRangeDays`. While a field is empty or unreadable, or the period
is rejected, it is `Nothing`.
-}
range : State -> Maybe ( Date, Date )
range (State s) =
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


{-| `True` when the last attempt to read the fields failed: a date is not a date,
lies outside `min` and `max`, or is excluded by `disabledWhen`, or the period is
reversed or longer than `maxRangeDays`. The field shows the first matching
message.

Text is only tried when it looks complete (ten characters, such as `2026-10-20`
or `20.10.2026`), when the user leaves a field or presses `Enter`, and when you
call `validate`, so call `validate` first when you check this on submit.

-}
isInvalid : State -> Bool
isInvalid (State s) =
    s.fromProblem /= Nothing || s.toProblem /= Nothing || s.rangeProblem /= Nothing


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
being typed is dropped, and the period is not checked against the limits.

    DateRangePicker.setRange (Just ( quarterStart, quarterEnd )) model.period

-}
setRange : Maybe ( Date, Date ) -> State -> State
setRange maybeRange (State s) =
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


{-| Empties both fields. The same as `setRange Nothing`.
-}
clear : State -> State
clear =
    setRange Nothing


{-| Fills the two fields with text as if the user had typed it. The texts are
read when the user leaves a field or presses `Enter`, or when you call
`validate`; until then `from`, `to` and `range` keep their old values.

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


{-| Reads the pending text of both fields now, as if the user had left them:
readable text becomes the date and is shown formatted, text that cannot be read
sets the problem that `isInvalid` reports. Pass the same attributes as to
`view`, because `today`, the limits, `maxRangeDays` and the locale decide what is
valid.

Use it when a form is submitted: the user may never have left the fields.

    DateRangePicker.validate attributes model.period

-}
validate : List Attribute -> State -> State
validate attributes (State s) =
    let
        check =
            checkOf (configure attributes)
    in
    State (s |> commit FromSide check |> commit ToSide check)


{-| Opens the calendar and moves the focus into it, after reading any pending
text. It opens on the from date, or else on the day given with `today`, kept
inside `min` and `max`. Pass the same attributes as to `view`: the limits come
from them.
-}
open : List Attribute -> State -> ( State, Cmd Msg )
open attributes (State s) =
    openPopup (checkOf (configure attributes)) s


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


{-| What the view knows about the limits when it sends a message.
-}
type alias Check =
    { rules : Rules
    , maxDays : Maybe Int
    }


{-| The messages of a period field. Wrap them in one constructor of your own
`Msg`, give that constructor to `view`, and pass what comes back to `update`.
-}
type Msg
    = Typed Side Check String
    | Blurred Side Check
    | Entered Side Check
    | OpenRequested Check
    | Toggled Check
    | Closed
    | Left
    | Escaped
    | CalendarMsg Calendar.Msg
    | PickedPreset Date Date
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
        Typed side check typed ->
            let
                draft =
                    setDraft side typed s
            in
            ( State
                (if Parse.isComplete typed then
                    accept side check draft

                 else
                    draft
                )
            , Cmd.none
            )

        Blurred side check ->
            ( State (commit side check s), Cmd.none )

        Entered side check ->
            if draftOf side s /= Nothing && problemOf side s == Nothing then
                ( State (commit side check s), Cmd.none )

            else
                openPopup check s

        OpenRequested check ->
            openPopup check s

        Toggled check ->
            if s.open then
                closePopup s

            else
                openPopup check s

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
                    Calendar.updateWithEvent inner s.calendar
            in
            case event of
                Just (Calendar.RangePicked start finish) ->
                    apply start finish { s | calendar = calendar }

                _ ->
                    ( State { s | calendar = calendar }, Cmd.map CalendarMsg cmd )

        PickedPreset start finish ->
            apply start finish s

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


setDraft : Side -> String -> Inner -> Inner
setDraft side typed s =
    case side of
        FromSide ->
            { s | fromDraft = Just typed, fromProblem = Nothing, rangeProblem = Nothing }

        ToSide ->
            { s | toDraft = Just typed, toProblem = Nothing, rangeProblem = Nothing }


{-| Reads a field's text and keeps what it says, leaving the text as typed.
-}
accept : Side -> Check -> Inner -> Inner
accept side check s =
    case draftOf side s of
        Nothing ->
            s

        Just typed ->
            let
                result =
                    Parse.date check.rules typed
            in
            checkPeriod check.maxDays
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
commit : Side -> Check -> Inner -> Inner
commit side check s =
    let
        accepted =
            accept side check s
    in
    if problemOf side accepted == Nothing then
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


openPopup : Check -> Inner -> ( State, Cmd Msg )
openPopup check s =
    let
        committed =
            s |> commit FromSide check |> commit ToSide check

        target =
            (case committed.from of
                Just start ->
                    start

                Nothing ->
                    Maybe.withDefault (Calendar.focusedDay committed.calendar) check.rules.today
            )
                |> Util.clampTo check.rules.min check.rules.max

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


fromId : String -> String
fromId id =
    id ++ "-from"


toId : String -> String
toId id =
    id ++ "-to"



-- ATTRIBUTES


{-| A setting of a period field. Make them with the functions below and pass a
list to `view`, `validate` or `open`; later attributes win over earlier ones.
-}
type Attribute
    = Attribute (Config -> Config)


type PresetChoice
    = DefaultPresets
    | CustomPresets (List Preset)


{-| A quick choice in the list beside the calendar: a `label` for its button and
the period it selects, `from` and `to`. Make one with `preset`, which also puts
the two days in order, and give a list of them to `presets`.
-}
type alias Preset =
    { label : String
    , from : Date
    , to : Date
    }


type alias Config =
    { field : Field.Config
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


configure : List Attribute -> Config
configure attributes =
    List.foldl (\(Attribute change) config -> change config)
        { field = Field.empty
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


updateField : (Field.Config -> Field.Config) -> Attribute
updateField change =
    Attribute (\config -> { config | field = change config.field })


{-| The label above the field. It also names the group that holds the two
inputs, and each input adds "from date" or "to date" to it. Give every field a
label, or hide it with `labelHidden`; without one the group is called "Choose
period".
-}
label : String -> Attribute
label value =
    updateField (Field.setLabel value)


{-| Keeps the label for screen readers but does not show it, for a field in a
toolbar or a table row. Needs `label`.
-}
labelHidden : Attribute
labelHidden =
    updateField Field.setLabelHidden


{-| A short help text below the field. It is linked to both inputs with
`aria-describedby`, so screen readers read it together with the field.
-}
hint : String -> Attribute
hint value =
    updateField (Field.setHint value)


{-| An error message from your application, shown below the field and announced
to screen readers: a required period that is missing, or a period that
conflicts with another field. While the picker has a complaint of its own about
the dates ("Invalid date", "The start date cannot be after the end date"), that
message is shown instead.

    DateRangePicker.error "Choose a report period"

-}
error : String -> Attribute
error value =
    updateField (Field.setError (Just value))


{-| Like `error`, but takes a `Maybe`: `Nothing` means no error. Convenient when
the message lives in a `Maybe` in your model.

    DateRangePicker.errorMaybe model.periodError

-}
errorMaybe : Maybe String -> Attribute
errorMaybe value =
    updateField (Field.setError value)


{-| Marks the field as required: an asterisk after the label, and
`aria-required` on both inputs. The picker does not enforce it; when the period
is missing, test `range` for `Nothing` yourself and pass an `error`.
-}
required : Attribute
required =
    updateField (Field.setRequired True)


{-| Text shown after the label of a field that is not `required`, such as
"(optional)". Default: none.
-}
optionalText : String -> Attribute
optionalText value =
    updateField (Field.setOptionalText value)


{-| Disables the field and its calendar button: the two inputs cannot be focused
or changed and the calendar cannot be opened. Takes a `Bool` so that it can come
straight from your model, for example while a form is saving. Default: `False`.
-}
disabled : Bool -> Attribute
disabled value =
    Attribute (\config -> { config | disabled = value })


{-| The period can be seen, selected and copied but not changed, and the
calendar does not open. Unlike `disabled`, the inputs can still be focused.
Default: `False`.
-}
readOnly : Bool -> Attribute
readOnly value =
    Attribute (\config -> { config | readOnly = value })


{-| Shows a small × button in the field while one of the inputs has text; it
empties both inputs and puts the focus back in the first. The button is not in
the tab order, and its accessible name is "Clear field". Default: no button.
-}
clearable : Attribute
clearable =
    Attribute (\config -> { config | clearable = True })


{-| The size of the field, a `Size` from [Klar.Theme](Klar-Theme).
Default: `Medium`.
-}
size : Size -> Attribute
size value =
    Attribute (\config -> { config | size = value })


{-| The language of the built-in text (placeholder, button labels, quick choices,
error messages, names of months and weekdays) and the format in which the fields
show a date: `2026-10-20` in English, `20.10.2026` in Norwegian. Default:
`Locale.default`, which is English. See [Klar.Locale](Klar-Locale).
-}
locale : Locale -> Attribute
locale value =
    Attribute (\config -> { config | locale = value })


{-| Today, supplied by the application (the library never reads the clock). It
marks the day in the calendar, builds the standard quick choices, completes the
short forms `20.10`, `t`, `+3` and `-7` in the text fields, and decides how a
two-digit year is read.

Without it there are no standard quick choices, the short forms are not
understood, and an empty field opens its calendar on January 2000 (or on the
nearest month inside `min` and `max`).

-}
today : Date -> Attribute
today value =
    Attribute (\config -> { config | today = Just value })


{-| The earliest date that can be chosen or typed. A typed date before it shows
"The date cannot be before" followed by the limit, the calendar disables the
earlier days, and the quick choices are cut to it (one that ends before it is
disabled). Default: no limit.
-}
min : Date -> Attribute
min value =
    Attribute (\config -> { config | min = Just value })


{-| The latest date that can be chosen or typed. A typed date after it shows
"The date cannot be after" followed by the limit, the calendar disables the
later days, and the quick choices are cut to it (one that starts after it is
disabled). Default: no limit.
-}
max : Date -> Attribute
max value =
    Attribute (\config -> { config | max = Just value })


{-| Dates that cannot be used, such as weekends or public holidays. The calendar
shows them disabled and a typed one shows "The date is not available". A quick
choice never starts or ends on one: it is cut inward to the nearest allowed day,
and disabled when no day of it is allowed. Default: every date is allowed.

    DateRangePicker.disabledWhen (\day -> Date.weekday day >= 6)

-}
disabledWhen : (Date -> Bool) -> Attribute
disabledWhen predicate =
    Attribute (\config -> { config | disabledWhen = predicate })


{-| The longest period allowed, in days, counting both end days. In the calendar,
days that would make the period longer are disabled once the first day is
chosen; a typed period that is longer shows "The period cannot be longer than"
followed by the number of days, and quick choices that are longer (after being
cut to the limits) are disabled. Default: no limit.

    DateRangePicker.maxRangeDays 90

-}
maxRangeDays : Int -> Attribute
maxRangeDays value =
    Attribute (\config -> { config | maxRangeDays = Just value })


{-| Marks on days in the calendar, such as deliveries or deadlines. Make them
with `Calendar.dot` and `Calendar.count` from [Klar.Calendar](Klar-Calendar).
Default: none.
-}
markers : List Calendar.Marker -> Attribute
markers value =
    Attribute (\config -> { config | markers = value })


{-| Shows ISO 8601 week numbers in the calendar. Default: off.
-}
weekNumbers : Attribute
weekNumbers =
    Attribute (\config -> { config | weekNumbers = True })


{-| Aligns the right edge of the calendar popup with the right edge of the
field, instead of the left edges. Use it for a field near the right side of the
page, so that the popup does not run out of the window.
-}
alignEnd : Attribute
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
presets : List Preset -> Attribute
presets value =
    Attribute (\config -> { config | presets = CustomPresets value })


{-| A quick choice with a label and a period. The two days may be given in
either order. When the user clicks it, the period is cut to `min` and `max` and
inward to the nearest days that `disabledWhen` allows; the button is disabled if
nothing is left or what is left is longer than `maxRangeDays`.

    DateRangePicker.preset "This quarter" quarterStart quarterEnd

-}
preset : String -> Date -> Date -> Preset
preset text start finish =
    { label = text, from = Util.earlier start finish, to = Util.later start finish }


{-| No list of quick choices: only the calendar is shown.
-}
noPresets : Attribute
noPresets =
    Attribute (\config -> { config | presets = CustomPresets [] })


checkOf : Config -> Check
checkOf config =
    { rules =
        { locale = config.locale
        , today = config.today
        , min = config.min
        , max = config.max
        , isDisabled = config.disabledWhen
        }
    , maxDays = config.maxRangeDays
    }


calendarAttributes : Config -> List Calendar.Attribute
calendarAttributes config =
    List.filterMap identity
        [ Maybe.map Calendar.today config.today
        , Maybe.map Calendar.min config.min
        , Maybe.map Calendar.max config.max
        , Maybe.map Calendar.maxRangeDays config.maxRangeDays
        , Just (Calendar.disabledWhen config.disabledWhen)
        , Just (Calendar.locale config.locale)
        , Just (Calendar.markers config.markers)
        , Just (Calendar.months 2)
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

        monthStart =
            Date.startOfMonth day

        previousStart =
            Date.addMonths -1 monthStart
    in
    [ { label = pick "I dag" "Today", from = day, to = day }
    , { label = pick "Siste 7 dager" "Last 7 days", from = Date.addDays -6 day, to = day }
    , { label = pick "Siste 30 dager" "Last 30 days", from = Date.addDays -29 day, to = day }
    , { label = pick "Denne måneden" "This month", from = monthStart, to = Date.endOfMonth day }
    , { label = pick "Forrige måned" "Last month", from = previousStart, to = Date.endOfMonth previousStart }
    , { label = pick "Dette året" "This year", from = Date.startOfMonth (Date.addMonths (1 - Date.month day) day), to = Date.endOfMonth (Date.addMonths (12 - Date.month day) day) }
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
resolvePreset config option =
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


{-| The first day from `day` up to `last` that is not disabled.
-}
firstAllowed : (Date -> Bool) -> Date -> Date -> Maybe Date
firstAllowed isDisabled day last =
    if Util.after day last then
        Nothing

    else if isDisabled day then
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
view : (Msg -> msg) -> List Attribute -> State -> Html msg
view toMsg attributes (State s) =
    let
        config =
            configure attributes

        check =
            checkOf config

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

        input side shown placeholderText extra =
            Html.input
                (extra
                    ++ [ Internal.cls [ "klar-input__control", "klar-daterange__control" ]
                       , Attr.type_ "text"
                       , Attr.value shown
                       , Attr.placeholder placeholderText
                       , Attr.disabled config.disabled
                       , Attr.readonly config.readOnly
                       , Attr.attribute "autocomplete" "off"
                       , Attr.attribute "aria-haspopup" "dialog"
                       , Attr.attribute "aria-keyshortcuts" "Alt+ArrowDown"
                       , Events.onInput (\typed -> toMsg (Typed side check typed))
                       , Events.onBlur (toMsg (Blurred side check))
                       , if inactive then
                            Internal.noAttr

                         else
                            Internal.onKeys
                                [ ( "ArrowDown", toMsg (OpenRequested check) )
                                , ( "Alt+ArrowDown", toMsg (OpenRequested check) )
                                , ( "Enter", toMsg (Entered side check) )
                                ]
                       ]
                )
                []
    in
    -- stable: the field makes messages of its own while the user types
    Field.viewStable field
        (Html.div [ Internal.cls [ "klar-anchor", "klar-anchor--block", "klar-daterange" ] ]
            [ Html.div
                [ Internal.cls
                    [ "klar-input"
                    , "klar-input--" ++ Theme.sizeSuffix config.size
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
                    words.placeholder
                    (Field.controlAttributes field
                        ++ [ Attr.attribute "aria-label" (groupLabel ++ ", " ++ words.fromDate) ]
                    )
                , Html.span [ Internal.cls [ "klar-daterange__separator" ], Attr.attribute "aria-hidden" "true" ] [ Html.text "–" ]
                , input ToSide
                    toShown
                    words.placeholder
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
                    [ Internal.cls [ "klar-datepicker__button" ]
                    , Attr.type_ "button"
                    , Attr.id (s.id ++ "-button")
                    , Attr.tabindex -1
                    , Attr.attribute "aria-label" words.openCalendar
                    , Attr.attribute "aria-haspopup" "dialog"
                    , Attr.attribute "aria-expanded" (boolString s.open)
                    , Internal.attrIf s.open (Attr.attribute "aria-controls" (s.id ++ "-popup"))
                    , Attr.disabled inactive
                    , Events.onClick (toMsg (Toggled check))
                    ]
                    [ Icon.view Icon.calendar ]
                ]
            , if s.open && not inactive then
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

        viewPreset index option =
            let
                resolved =
                    resolvePreset config option

                period =
                    Result.toMaybe resolved
            in
            Button.view
                ([ Button.small
                 , Button.ghost
                 , Button.id (s.id ++ "-popup-preset-" ++ String.fromInt index)
                 , Button.disabled (period == Nothing)
                 , Button.pressed (period /= Nothing && period == current && not (Calendar.isChoosing s.calendar))
                 , Button.htmlAttrs [ Internal.cls [ "klar-daterange__preset" ] ]
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
                option.label

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
        , label = words.dialog
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
                    ]
                    (List.indexedMap viewPreset options)
            , Html.div [ Internal.cls [ "klar-daterange__main" ] ]
                [ Calendar.view (\inner -> toMsg (CalendarMsg inner)) (calendarAttributes config) s.calendar
                , Html.div
                    [ Internal.cls [ "klar-daterange__status" ]
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
boolString value =
    if value then
        "true"

    else
        "false"
