module Klar.DateTimePicker exposing
    ( view
    , State, init, Msg, update
    , value, isValid, text, setValue, clear, setText, setLimits
    , date, time, setDate, setTime
    , DateTime, toPosix, fromPosix, toIso, fromIso
    , isOpen, open, close, visibleMonth
    , Attribute, today, min, max, disabledWhen, markers, weekNumbers
    , minTime, maxTime, step
    , label, labelHidden, hint, error, errorMaybe, required, optionalText
    , size, locale, disabled, readOnly, clearable, alignEnd, name
    )

{-| A date and a time in one control: a [Klar.DatePicker](Klar-DatePicker) and a
[Klar.TimePicker](Klar-TimePicker) side by side under one label.

Use when: the date and the time belong together, such as the moment of a pick-up.
Do not use when: you need a date alone (as `Klar.DatePicker`) or a time alone (as `Klar.TimePicker`).
Quick path: `init`, `update`, `view`, `value`

    import Klar.DateTimePicker as DateTimePicker

    -- model
    { pickup : DateTimePicker.State }   -- DateTimePicker.init "pickup"

    -- msg
    PickupMsg DateTimePicker.Msg

    -- update
    PickupMsg m ->
        let
            ( pickup, cmd ) =
                DateTimePicker.update m model.pickup
        in
        ( { model | pickup = pickup }, Cmd.map PickupMsg cmd )

    -- view
    DateTimePicker.view PickupMsg
        [ DateTimePicker.label "Pick-up time"
        , DateTimePicker.today model.today
        , DateTimePicker.min model.today
        , DateTimePicker.step 15
        ]
        model.pickup

    -- read
    DateTimePicker.value model.pickup   -- Maybe { date : Date, time : Time }

    -- store or send it as local text, with the zone name your backend knows
    Maybe.map DateTimePicker.toIso (DateTimePicker.value model.pickup)   -- Just "2026-10-20T14:30"

Here `model.today` is a [Klar.Date](Klar-Date) value that the application keeps;
the library never reads the clock.

The state holds both parts, and there are no out-messages: compare `value`
before and after `update` to react to a change. `value` is `Just` only when
both parts hold an accepted value. When one part is empty or its text cannot be
read it is `Nothing`, and `isValid` tells unreadable from empty. `date` and
`time` read the parts on their own, for example to load the free slots of the
chosen day.

A `DateTime` is a wall-clock time without a time zone. `toIso` and `fromIso`
write and read it as `2026-10-20T14:30`, the transport-neutral form to store and
send. `toPosix` turns it into a moment in a `Time.Zone`, `fromPosix` the other
way; do not add minutes to `Date.toPosix` yourself, which is an hour off on the
days the clock changes.

The two parts behave as described for [Klar.DatePicker](Klar-DatePicker) (typed
dates, the calendar, its keyboard support) and
[Klar.TimePicker](Klar-TimePicker) (typed times, the list, its keyboard support).
Their text inputs have the DOM ids `<id>-date` and `<id>-time`. Each part shows
its own message below its input when its text cannot be read, such as "Invalid
date" or "The time cannot be before 08:00". A text is read when the user leaves
its input, presses `Enter`, or has typed a complete date or time. A form should
also call `setLimits` when it is submitted, because the user may never have
left the inputs; `text` and `setText` give and set the text of both inputs, for
example to pre-fill them from a stored value.

The label, the hint and the error of your application belong to the pair: the
label sits above both inputs and names the group that holds them, the hint and
the error below, and both describe the group (`aria-describedby`, with the ids
`<id>-hint` and `<id>-error` as in [Klar.Field](Klar-Field)). The error is
announced when it appears, and `required` sets `aria-required` on both inputs.
`size`, `locale`, `disabled`, `readOnly` and `clearable` apply to both parts.
The limits are separate: `min`, `max` and `disabledWhen` restrict the date,
`minTime` and `maxTime` the time of day, on every date. The built-in text comes
from `locale`; the default is English.


# View

@docs view


# State

@docs State, init, Msg, update


# The value

@docs value, isValid, text, setValue, clear, setText, setLimits


# The two parts

@docs date, time, setDate, setTime


# Moments and text

@docs DateTime, toPosix, fromPosix, toIso, fromIso


# The popups

@docs isOpen, open, close, visibleMonth


# Date limits and today

@docs Attribute, today, min, max, disabledWhen, markers, weekNumbers


# Time limits and steps

@docs minTime, maxTime, step


# Label, hint and error

@docs label, labelHidden, hint, error, errorMaybe, required, optionalText


# Look and behavior

@docs size, locale, disabled, readOnly, clearable, alignEnd, name

-}

import Html exposing (Html)
import Html.Attributes as Attr
import Klar.Calendar as Calendar
import Klar.Date as Date exposing (Date)
import Klar.DatePicker as DatePicker
import Klar.Field as Field
import Klar.Internal as Internal
import Klar.Locale as Locale exposing (Locale)
import Klar.Theme exposing (Size(..))
import Klar.TimePicker as TimePicker exposing (Time)
import Time



-- STATE


{-| The state of one date and time control: a date field and a time field. Make
it with `init`, keep it in your model, and read it with `value` and
`isValid`.
-}
type State
    = State
        { id : String
        , date : DatePicker.State
        , time : TimePicker.State
        }


{-| A date and a time of day together, as a record. The `date` is a
[Klar.Date](Klar-Date) and the `time` a `Time` from
[Klar.TimePicker](Klar-TimePicker). There is no time zone: both are what the
user sees in the fields.

    { date = october20 -- from Date.fromParts 2026 10 20
    , time = { hour = 14, minute = 30 }
    }

-}
type alias DateTime =
    { date : Date
    , time : Time
    }


{-| The moment a date and time of day stand for in a time zone. On the day the
clock is put back, a time that happens twice is the first of the two; on the day
it is put forward, a time that does not exist (02:30 when the clock jumps from
02:00 to 03:00) is moved forward by the jump (03:30).

    DateTimePicker.toPosix Time.utc { date = october20, time = { hour = 14, minute = 30 } }
    -- 2026-10-20T14:30:00Z

`Time.here` from `elm/time` gives the offset of the browser now, as one fixed
offset without the rules of summer time, so a moment on the other side of a
change of the clock is an hour off with it. Prefer to store and send the local
text of `toIso` together with the name of the zone (such as "Europe/Oslo"), and
let the backend, which knows the rules, make the moment.

-}
toPosix : Time.Zone -> DateTime -> Time.Posix
toPosix zone local =
    let
        wall =
            Date.toEpochDay local.date * 86400000 + (local.time.hour * 60 + local.time.minute) * 60000

        offsetAt millis =
            localMillis zone millis - millis

        -- The offsets on either side of the time (a change of the clock is rarer
        -- than once a day): in an overlap both give the time, in a gap neither.
        before =
            wall - offsetAt (wall - 86400000)

        after =
            wall - offsetAt (wall + 86400000)

        existing =
            List.filter (\millis -> localMillis zone millis == wall) [ before, after ]
    in
    Time.millisToPosix
        (case List.minimum existing of
            Just millis ->
                millis

            Nothing ->
                -- In a gap: the offset from before the jump moves the time forward.
                before
        )


{-| The local date and time of day of a moment in a time zone, to the minute
(seconds are dropped). The inverse of `toPosix` for every time that exists.

    DateTimePicker.fromPosix Time.utc (Time.millisToPosix 0)
    -- { date = 1970-01-01, time = { hour = 0, minute = 0 } }

-}
fromPosix : Time.Zone -> Time.Posix -> DateTime
fromPosix zone posix =
    { date = Date.fromPosix zone posix
    , time = { hour = Time.toHour zone posix, minute = Time.toMinute zone posix }
    }


localMillis : Time.Zone -> Int -> Int
localMillis zone millis =
    let
        posix =
            Time.millisToPosix millis
    in
    Date.toEpochDay (Date.fromPosix zone posix)
        * 86400000
        + Time.toHour zone posix
        * 3600000
        + Time.toMinute zone posix
        * 60000
        + Time.toSecond zone posix
        * 1000
        + Time.toMillis zone posix


{-| Writes `YYYY-MM-DDTHH:MM`, the local date and time of ISO 8601 without a
zone: the form to store and send, transport neutral and sortable as text.

    DateTimePicker.toIso { date = october20, time = { hour = 9, minute = 5 } }
    -- "2026-10-20T09:05"

-}
toIso : DateTime -> String
toIso local =
    Date.toIso local.date ++ "T" ++ TimePicker.toString local.time


{-| Reads `YYYY-MM-DDTHH:MM`, the form `toIso` writes, and the forms backends
often send: a lowercase `t` or a space in place of the `T`, and seconds with or
without a fraction (`T14:30:00`, `T14:30:00.000`), which are dropped. Text with
a zone (`Z` or `+02:00`) is a moment rather than a wall-clock time and gives
`Nothing`, and so does a date or a time that does not exist.

    DateTimePicker.fromIso "2026-10-20T14:30" -- Just { date = 2026-10-20, time = 14:30 }

    DateTimePicker.fromIso "2026-10-20 14:30:00.000" -- the same

    DateTimePicker.fromIso "2026-10-20T14:30Z" -- Nothing

-}
fromIso : String -> Maybe DateTime
fromIso raw =
    let
        text =
            String.trim raw
    in
    if List.member (String.slice 10 11 text) [ "T", "t", " " ] then
        Maybe.map2 DateTime (Date.fromIso (String.left 10 text)) (isoTime (String.dropLeft 11 text))

    else
        Nothing


isoTime : String -> Maybe Time
isoTime raw =
    let
        twoDigits part =
            if String.length part == 2 && String.all Char.isDigit part then
                String.toInt part

            else
                Nothing

        build hour minute =
            if hour <= 23 && minute <= 59 then
                Just { hour = hour, minute = minute }

            else
                Nothing
    in
    case String.split ":" raw of
        [ h, m ] ->
            Maybe.map2 build (twoDigits h) (twoDigits m) |> Maybe.andThen identity

        [ h, m, sec ] ->
            let
                whole =
                    case String.split "." sec of
                        [ seconds ] ->
                            twoDigits seconds

                        [ seconds, fraction ] ->
                            if fraction /= "" && String.all Char.isDigit fraction then
                                twoDigits seconds

                            else
                                Nothing

                        _ ->
                            Nothing
            in
            if Maybe.withDefault 60 whole <= 59 then
                Maybe.map2 build (twoDigits h) (twoDigits m) |> Maybe.andThen identity

            else
                Nothing

        _ ->
            Nothing


{-| An empty control. The `String` must be unique on the page: the date input
gets the DOM id `<id>-date`, the time input `<id>-time`, and the label
`<id>-label`.

    DateTimePicker.init "pickup"

-}
init : String -> State
init id =
    State
        { id = id
        , date = DatePicker.init (id ++ "-date")
        , time = TimePicker.init (id ++ "-time")
        }


{-| The date and the time, when both parts hold an accepted value. `Nothing`
when either part is empty or its text could not be read.
-}
value : State -> Maybe DateTime
value (State s) =
    Maybe.map2 DateTime (DatePicker.value s.date) (TimePicker.value s.time)


{-| The accepted date of the date part, also while the time is still missing.
Use it to load what depends on the day, such as the free slots of that day.
-}
date : State -> Maybe Date
date (State s) =
    DatePicker.value s.date


{-| The accepted time of the time part, also while the date is still missing.
-}
time : State -> Maybe Time
time (State s) =
    TimePicker.value s.time


{-| Sets the date part alone, or empties it with `Nothing`; the time stays as
it is. Text that was being typed in the date input is dropped.
-}
setDate : Maybe Date -> State -> State
setDate maybeDate (State s) =
    State { s | date = DatePicker.setValue maybeDate s.date }


{-| Sets the time part alone, or empties it with `Nothing`; the date stays as
it is. Text that was being typed in the time input is dropped.
-}
setTime : Maybe Time -> State -> State
setTime maybeTime (State s) =
    State { s | time = TimePicker.setValue maybeTime s.time }


{-| `False` when either part could not be read: the date is not a date, lies
outside `min` and `max` or is excluded by `disabledWhen`, or the time is not a
time or lies outside `minTime` and `maxTime`. Each part shows its own message
below its input. Empty parts are valid; whether they are required is for the
application to say.

Text is only tried when it is complete (a full `hh:mm`, or a date with a day, a
month and a four-digit year such as `20.10.2026` or `2026-10-20`), when the user
leaves its input or presses `Enter`, and when you call `setLimits`, so call
`setLimits` first when you check this on submit.

-}
isValid : State -> Bool
isValid (State s) =
    DatePicker.isValid s.date && TimePicker.isValid s.time


{-| The text in the two inputs that has not been replaced by a formatted value
yet: text the user is still typing, or text that could not be read. Each part is
empty when its input shows an accepted value or nothing. Together with
`value` it tells empty inputs from garbage: `value == Nothing` and a
`text` that is not empty means there is text that is not (yet) a date or a time.
Use `isValid` to ask whether the text was tried and rejected; see also
[DatePicker.text](Klar-DatePicker#text) and
[TimePicker.text](Klar-TimePicker#text).
-}
text : State -> { date : String, time : String }
text (State s) =
    { date = DatePicker.text s.date
    , time = TimePicker.text s.time
    }


{-| Sets both parts, or empties both with `Nothing`. The fields show the date
and the time formatted for the locale; text that was being typed is dropped. The
values are not checked against the limits until `setLimits` is called.

    DateTimePicker.setValue (Just shipment.pickup) model.pickup

-}
setValue : Maybe DateTime -> State -> State
setValue maybeValue (State s) =
    State
        { s
            | date = DatePicker.setValue (Maybe.map .date maybeValue) s.date
            , time = TimePicker.setValue (Maybe.map .time maybeValue) s.time
        }


{-| Empties both parts. The same as `setValue Nothing`.
-}
clear : State -> State
clear =
    setValue Nothing


{-| Fills the two inputs with text as if the user had typed it, for example to
pre-fill them from text that you stored. The texts are read when the user leaves
an input or presses `Enter`, or when you call `setLimits`; until then `value`
keeps its old value.

    DateTimePicker.setText { date = "2026-10-20", time = "14:30" } model.pickup

-}
setText : { date : String, time : String } -> State -> State
setText texts (State s) =
    State
        { s
            | date = DatePicker.setText texts.date s.date
            , time = TimePicker.setText texts.time s.time
        }


{-| Reads both inputs again with the limits of these attributes, as if the
user had left them: pending text that can be read becomes the date or the time
and is shown formatted, and text that cannot sets the problem that `isValid`
reports. A part that was accepted before and that the limits no longer allow
keeps its text, with the message; it is never moved into the limits. Pass the
same attributes as to `view`, because `today`, the limits and the locale decide
what is valid.

Use it when a form is submitted, since the user may never have left the inputs,
and after the limits change.

    DateTimePicker.setLimits pickupLimits model.pickup

-}
setLimits : List (Attribute msg) -> State -> State
setLimits attributes (State s) =
    let
        config =
            configure attributes
    in
    State
        { s
            | date = DatePicker.setLimits (dateAttributesOf config) s.date
            , time = TimePicker.setLimits (timeAttributesOf config) s.time
        }


{-| `True` while the calendar of the date part or the list of the time part is
open. A control that is `disabled` or `readOnly` never draws them.
-}
isOpen : State -> Bool
isOpen (State s) =
    DatePicker.isOpen s.date || TimePicker.isOpen s.time


{-| Opens the calendar of the date part and moves the focus into it, after
reading any pending text, as [DatePicker.open](Klar-DatePicker#open) does. Pass
the same attributes as to `view`. A control that is `disabled` or `readOnly`
stays closed.
-}
open : List (Attribute msg) -> State -> ( State, Cmd Msg )
open attributes (State s) =
    let
        ( datePart, cmd ) =
            DatePicker.open (dateAttributesOf (configure attributes)) s.date
    in
    ( State { s | date = datePart }, Cmd.map DateMsg cmd )


{-| Closes the calendar or the list, whichever is open, and gives the focus back
to its input. Does nothing when both are closed.
-}
close : State -> ( State, Cmd Msg )
close (State s) =
    let
        ( datePart, dateCmd ) =
            DatePicker.close s.date

        ( timePart, timeCmd ) =
            TimePicker.close s.time
    in
    ( State { s | date = datePart, time = timePart }
    , Cmd.batch [ Cmd.map DateMsg dateCmd, Cmd.map TimeMsg timeCmd ]
    )


{-| The first month the calendar of the date part shows, as `{ year, month }`
(January is 1). For an application that loads marks one month at a time: compare
it before and after `update` and fetch when it changes; see
[DatePicker.visibleMonth](Klar-DatePicker#visibleMonth).
-}
visibleMonth : State -> { year : Int, month : Int }
visibleMonth (State s) =
    DatePicker.visibleMonth s.date



-- UPDATE


{-| The messages of a date and time control. Wrap them in one constructor of
your own `Msg`, give that constructor to `view`, and pass what comes back to
`update`.
-}
type Msg
    = DateMsg DatePicker.Msg
    | TimeMsg TimePicker.Msg


{-| Handles a message of the control: everything the date field and the time
field do. Returns the new state and the command that moves the browser focus.
Map the command with the constructor of your own `Msg`.

    PickupMsg m ->
        let
            ( pickup, cmd ) =
                DateTimePicker.update m model.pickup
        in
        ( { model | pickup = pickup }, Cmd.map PickupMsg cmd )

-}
update : Msg -> State -> ( State, Cmd Msg )
update msg (State s) =
    case msg of
        DateMsg inner ->
            let
                ( datePart, cmd ) =
                    DatePicker.update inner s.date
            in
            ( State { s | date = datePart }, Cmd.map DateMsg cmd )

        TimeMsg inner ->
            let
                ( timePart, cmd ) =
                    TimePicker.update inner s.time
            in
            ( State { s | time = timePart }, Cmd.map TimeMsg cmd )



-- ATTRIBUTES


{-| A setting of a date and time control. Make them with the functions below and
pass a list to `view`; later attributes win over earlier ones.
-}
type Attribute msg
    = Attribute (Config -> Config)


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
    , name : Maybe String
    , step : Int
    , minTime : Maybe Time
    , maxTime : Maybe Time
    }


configure : List (Attribute msg) -> Config
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
        , name = Nothing
        , step = 15
        , minTime = Nothing
        , maxTime = Nothing
        }
        attributes


updateField : (Field.Config -> Field.Config) -> Attribute msg
updateField change =
    Attribute (\config -> { config | field = change config.field })


{-| The label above the two fields. It names the group that holds them, and the
two inputs are named after it for screen readers ("Pick-up time, date" and
"Pick-up time, time"; "Date" and "Time" without a label). Give the control a
label, or hide it with `labelHidden`.
-}
label : String -> Attribute msg
label given =
    updateField (Field.setLabel given)


{-| Keeps the label for screen readers but does not show it, for a control in a
toolbar or a table row. Needs `label`.
-}
labelHidden : Attribute msg
labelHidden =
    updateField Field.setLabelHidden


{-| A short help text below the two fields. It describes the group that holds
them (`aria-describedby`), so screen readers read it when the focus enters.
-}
hint : String -> Attribute msg
hint given =
    updateField (Field.setHint given)


{-| An error message from your application, shown below the two fields and
announced to screen readers (`role="alert"`): a required date and time that is
missing, or one that conflicts with another field. It also describes the group
that holds the fields and marks both inputs `aria-invalid`, and it does not
replace the messages of the parts about unreadable text, which appear below
their own inputs.

    DateTimePicker.error "Choose a pick-up time"

-}
error : String -> Attribute msg
error given =
    updateField (Field.setError (Just given))


{-| Like `error`, but takes a `Maybe`: `Nothing` means no error. Convenient when
the message lives in a `Maybe` in your model.

    DateTimePicker.errorMaybe model.pickupError

-}
errorMaybe : Maybe String -> Attribute msg
errorMaybe given =
    updateField (Field.setError given)


{-| Marks the control as required: an asterisk after the label, and
`aria-required` on both inputs. The control does not enforce it; when the date or
the time is missing, test `value` for `Nothing` yourself and pass an `error`.
-}
required : Attribute msg
required =
    updateField (Field.setRequired True)


{-| Text shown after the label of a control that is not `required`, such as
"(optional)". Default: none.
-}
optionalText : String -> Attribute msg
optionalText given =
    updateField (Field.setOptionalText given)


{-| Disables both fields and their buttons: they cannot be focused or changed
and the popups cannot be opened. Takes a `Bool` so that it can come straight
from your model, for example while a form is saving. Default: `False`.
-}
disabled : Bool -> Attribute msg
disabled given =
    Attribute (\config -> { config | disabled = given })


{-| The date and the time can be seen, selected and copied but not changed, and
the popups do not open. Unlike `disabled`, the inputs can still be focused.
Default: `False`.
-}
readOnly : Bool -> Attribute msg
readOnly given =
    Attribute (\config -> { config | readOnly = given })


{-| Shows a small × button in each field while it has text; a button empties its
own field and puts the focus back in it. The buttons are not in the tab order,
and their accessible name is "Clear field". Default: no buttons.
-}
clearable : Attribute msg
clearable =
    Attribute (\config -> { config | clearable = True })


{-| The size of both fields, a `Size` from [Klar.Theme](Klar-Theme).
Default: `Medium`.
-}
size : Size -> Attribute msg
size given =
    Attribute (\config -> { config | size = given })


{-| The language of the built-in text of both fields (placeholders, button
labels, error messages, names of months and weekdays) and the format in which
the date is shown: `2026-10-20` in English, `20.10.2026` in Norwegian. Default:
`Locale.default`, which is English. See [Klar.Locale](Klar-Locale).
-}
locale : Locale -> Attribute msg
locale given =
    Attribute (\config -> { config | locale = given })


{-| Today, supplied by the application (the library never reads the clock). It
marks the day in the calendar, powers the "Today" button, and completes the short
forms `20.10`, `t`, `+3` and `-7` in the date field.

Without it there is no "Today" button, the short forms are not understood, and an
empty date field opens its calendar on January 2000 (or on the nearest month
inside `min` and `max`).

-}
today : Date -> Attribute msg
today given =
    Attribute (\config -> { config | today = Just given })


{-| The earliest date that can be chosen or typed: a typed date before it shows
"The date cannot be before" followed by the limit, and the calendar disables the
earlier days. The time of day has its own limit, `minTime`. Default: no limit.
-}
min : Date -> Attribute msg
min given =
    Attribute (\config -> { config | min = Just given })


{-| The latest date that can be chosen or typed: a typed date after it shows
"The date cannot be after" followed by the limit, and the calendar disables the
later days. The time of day has its own limit, `maxTime`. Default: no limit.
-}
max : Date -> Attribute msg
max given =
    Attribute (\config -> { config | max = Just given })


{-| Dates that cannot be used, such as weekends or public holidays. The
calendar shows them disabled, and a typed one shows "The date is not available".
Default: every date is allowed.

    DateTimePicker.disabledWhen (\day -> Date.weekday day >= 6)

-}
disabledWhen : (Date -> Bool) -> Attribute msg
disabledWhen predicate =
    Attribute (\config -> { config | disabledWhen = predicate })


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


{-| Aligns the right edges of the calendar and of the list of times with the right
edges of their inputs, instead of the left edges. Use it for a control near the
right side of the page, so that the popups do not run out of the window.
-}
alignEnd : Attribute msg
alignEnd =
    Attribute (\config -> { config | alignEnd = True })


{-| The `name` of the two inputs for a plain HTML `form`: `<name>-date` and
`<name>-time`. The values sent are the texts in the inputs. Default: none.
-}
name : String -> Attribute msg
name given =
    Attribute (\config -> { config | name = Just given })


{-| Minutes between the times in the list, from 1 to 60 (other numbers are cut to
that range). A divisor of 60 (5, 10, 15, 20, 30 or 60) lines the list up with
the hour, and typed times between the steps are accepted whatever the step is.
The default is 15; see [TimePicker.step](Klar-TimePicker#step).
-}
step : Int -> Attribute msg
step given =
    Attribute (\config -> { config | step = given })


{-| The earliest time of day that can be chosen or typed, on every date. Default:
00:00.

    DateTimePicker.minTime { hour = 8, minute = 0 }

-}
minTime : Time -> Attribute msg
minTime given =
    Attribute (\config -> { config | minTime = Just given })


{-| The latest time of day that can be chosen or typed, on every date. Default:
23:59.

    DateTimePicker.maxTime { hour = 16, minute = 0 }

-}
maxTime : Time -> Attribute msg
maxTime given =
    Attribute (\config -> { config | maxTime = Just given })



-- VIEW


{-| The control: a date field and a time field side by side under one label. The
first argument wraps the picker's messages in one of yours.

    DateTimePicker.view PickupMsg
        [ DateTimePicker.label "Pick-up time"
        , DateTimePicker.today model.today
        ]
        model.pickup

-}
view : (Msg -> msg) -> List (Attribute msg) -> State -> Html msg
view toMsg attributes (State s) =
    let
        config =
            configure attributes

        -- The label belongs to the pair, not to one input: the pair is a labelled
        -- group (the label is a plain text, not a `<label for>` that would point
        -- at nothing), and the two inputs keep their own (hidden) labels. The hint
        -- and the error belong to the pair too: `Field.viewGroup` draws them, and
        -- the group is described by them (below). The inputs are `aria-required`
        -- through their own `required` (see `dateAttributesOf`).
        field =
            Field.setId s.id config.field

        labelNode =
            case field.label of
                Just labelText ->
                    [ Html.span
                        [ Internal.cls
                            [ "klar-field__label"
                            , if field.labelHidden then
                                "klar-sr-only"

                              else
                                ""
                            ]
                        , Attr.id (Field.labelId field)
                        ]
                        [ Html.text labelText
                        , Internal.viewIf field.required
                            (Html.span [ Internal.cls [ "klar-field__required" ], Attr.attribute "aria-hidden" "true" ] [ Html.text "*" ])
                        , case ( field.required, field.optionalText ) of
                            ( False, Just optional ) ->
                                Html.span [ Internal.cls [ "klar-field__optional" ] ] [ Html.text optional ]

                            _ ->
                                Html.text ""
                        ]
                    ]

                Nothing ->
                    []
    in
    Field.viewGroup field
        (Html.div [ Internal.cls [ "klar-datetimepicker-field" ] ]
            (labelNode
                ++ [ Html.div
                        ([ Internal.cls [ "klar-datetimepicker" ]
                         , Attr.attribute "role" "group"
                         ]
                            ++ (case field.label of
                                    Just _ ->
                                        [ Attr.attribute "aria-labelledby" (Field.labelId field) ]

                                    Nothing ->
                                        []
                               )
                            ++ Field.describedByAttributes field
                        )
                        [ Html.div [ Internal.cls [ "klar-datetimepicker__date" ] ]
                            [ DatePicker.view (\inner -> toMsg (DateMsg inner)) (dateAttributesOf config) s.date ]
                        , Html.div [ Internal.cls [ "klar-datetimepicker__time" ] ]
                            [ TimePicker.view (\inner -> toMsg (TimeMsg inner)) (timeAttributesOf config) s.time ]
                        ]
                   ]
            )
        )


{-| The built-in names of the two inputs, for screen readers (their labels are
hidden).
-}
partNames : Locale -> { date : String, time : String }
partNames lang =
    Locale.pick lang
        { nb = { date = "dato", time = "klokkeslett" }
        , en = { date = "date", time = "time" }
        }


{-| The hidden label of one input: the label of the control and the part, such
as "Pick-up time, date", so that a list of the form's fields tells two controls
apart; the part alone, capitalized, without a label.
-}
partLabel : Config -> String -> String
partLabel config part =
    case config.field.label of
        Just labelText ->
            labelText ++ ", " ++ part

        Nothing ->
            String.toUpper (String.left 1 part) ++ String.dropLeft 1 part


{-| What the date field gets from the attributes of the control. `view` draws it
with these, and `setLimits` reads the text by the same rules. The field is
`required` when the control is, which puts `aria-required` on the input (the
asterisk is in the hidden label, which nobody sees).
-}
dateAttributesOf : Config -> List (DatePicker.Attribute msg)
dateAttributesOf config =
    List.filterMap identity
        [ Just (DatePicker.label (partLabel config (partNames config.locale).date))
        , Just DatePicker.labelHidden
        , Just (DatePicker.locale config.locale)
        , Just (DatePicker.size config.size)
        , Just (DatePicker.disabled config.disabled)
        , Just (DatePicker.readOnly config.readOnly)
        , Just (DatePicker.disabledWhen config.disabledWhen)
        , Just (DatePicker.invalid (config.field.error /= Nothing))
        , Just (DatePicker.markers config.markers)
        , Maybe.map DatePicker.today config.today
        , Maybe.map DatePicker.min config.min
        , Maybe.map DatePicker.max config.max
        , if config.clearable then
            Just DatePicker.clearable

          else
            Nothing
        , if config.alignEnd then
            Just DatePicker.alignEnd

          else
            Nothing
        , Maybe.map (\given -> DatePicker.name (given ++ "-date")) config.name
        , if config.weekNumbers then
            Just DatePicker.weekNumbers

          else
            Nothing
        , if config.field.required then
            Just DatePicker.required

          else
            Nothing
        ]


{-| What the time field gets from the attributes of the control, like
`dateAttributesOf`.
-}
timeAttributesOf : Config -> List (TimePicker.Attribute msg)
timeAttributesOf config =
    List.filterMap identity
        [ Just (TimePicker.label (partLabel config (partNames config.locale).time))
        , Just TimePicker.labelHidden
        , Just (TimePicker.locale config.locale)
        , Just (TimePicker.size config.size)
        , Just (TimePicker.disabled config.disabled)
        , Just (TimePicker.readOnly config.readOnly)
        , Just (TimePicker.step config.step)
        , Just (TimePicker.invalid (config.field.error /= Nothing))
        , Maybe.map TimePicker.min config.minTime
        , if config.alignEnd then
            Just TimePicker.alignEnd

          else
            Nothing
        , Maybe.map (\given -> TimePicker.name (given ++ "-time")) config.name
        , Maybe.map TimePicker.max config.maxTime
        , if config.clearable then
            Just TimePicker.clearable

          else
            Nothing
        , if config.field.required then
            Just TimePicker.required

          else
            Nothing
        ]
