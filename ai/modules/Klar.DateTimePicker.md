# Klar.DateTimePicker

A date and a time in one control: a Klar.DatePicker and a Klar.TimePicker side by side under one label.

Import: `import Klar.DateTimePicker as DateTimePicker` | Group: Date and time

Types: `Msg`, `State`, `Attribute`, `DateTime`

## Signatures

```elm
-- View
view : (Msg -> msg) -> List (Attribute msg) -> State -> Html msg

-- State
type State  -- opaque: no constructors are exposed
type Msg  -- opaque: no constructors are exposed
init : String -> State
update : Msg -> State -> ( State, Cmd Msg )

-- The value
value : State -> Maybe DateTime
isValid : State -> Bool
text : State -> { date : String, time : String }
setValue : Maybe DateTime -> State -> State
clear : State -> State
setText : { date : String, time : String } -> State -> State
setLimits : List (Attribute msg) -> State -> State

-- The two parts
date : State -> Maybe Date.Date
time : State -> Maybe TimePicker.Time
setDate : Maybe Date.Date -> State -> State
setTime : Maybe TimePicker.Time -> State -> State

-- Moments and text
type alias DateTime = { date : Date.Date, time : TimePicker.Time }
toPosix : Time.Zone -> DateTime -> Time.Posix
fromPosix : Time.Zone -> Time.Posix -> DateTime
toIso : DateTime -> String
fromIso : String -> Maybe DateTime

-- Date limits and today
type Attribute msg  -- opaque: no constructors are exposed
today : Date.Date -> Attribute msg
min : Date.Date -> Attribute msg
max : Date.Date -> Attribute msg
disabledWhen : (Date.Date -> Bool) -> Attribute msg
markers : List Calendar.Marker -> Attribute msg
weekNumbers : Attribute msg

-- Time limits and steps
minTime : TimePicker.Time -> Attribute msg
maxTime : TimePicker.Time -> Attribute msg
step : Int -> Attribute msg

-- Label, hint and error
label : String -> Attribute msg
labelHidden : Attribute msg
hint : String -> Attribute msg
error : String -> Attribute msg
errorMaybe : Maybe String -> Attribute msg
required : Attribute msg
optionalText : String -> Attribute msg

-- Look and behavior
size : Theme.Size -> Attribute msg
locale : Locale.Locale -> Attribute msg
disabled : Bool -> Attribute msg
readOnly : Bool -> Attribute msg
clearable : Attribute msg
```

## Documentation

A date and a time in one control: a [Klar.DatePicker](Klar.DatePicker.md) and a
[Klar.TimePicker](Klar.TimePicker.md) side by side under one label.

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

Here `model.today` is a [Klar.Date](Klar.Date.md) value that the application keeps;
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

The two parts behave as described for [Klar.DatePicker](Klar.DatePicker.md) (typed
dates, the calendar, its keyboard support) and
[Klar.TimePicker](Klar.TimePicker.md) (typed times, the list, its keyboard support).
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
`<id>-hint` and `<id>-error` as in [Klar.Field](Klar.Field.md)). The error is
announced when it appears, and `required` sets `aria-required` on both inputs.
`size`, `locale`, `disabled`, `readOnly` and `clearable` apply to both parts.
The limits are separate: `min`, `max` and `disabledWhen` restrict the date,
`minTime` and `maxTime` the time of day, on every date. The built-in text comes
from `locale`; the default is English.

## View

### `view`

```elm
view : (Msg -> msg) -> List (Attribute msg) -> State -> Html msg
```

The control: a date field and a time field side by side under one label. The
first argument wraps the picker's messages in one of yours.

    DateTimePicker.view PickupMsg
        [ DateTimePicker.label "Pick-up time"
        , DateTimePicker.today model.today
        ]
        model.pickup

## State

### `State`

```elm
type State  -- opaque: no constructors are exposed
```

The state of one date and time control: a date field and a time field. Make
it with `init`, keep it in your model, and read it with `value` and
`isValid`.

### `Msg`

```elm
type Msg  -- opaque: no constructors are exposed
```

The messages of a date and time control. Wrap them in one constructor of
your own `Msg`, give that constructor to `view`, and pass what comes back to
`update`.

### `init`

```elm
init : String -> State
```

An empty control. The `String` must be unique on the page: the date input
gets the DOM id `<id>-date`, the time input `<id>-time`, and the label
`<id>-label`.

    DateTimePicker.init "pickup"

### `update`

```elm
update : Msg -> State -> ( State, Cmd Msg )
```

Handles a message of the control: everything the date field and the time
field do. Returns the new state and the command that moves the browser focus.
Map the command with the constructor of your own `Msg`.

    PickupMsg m ->
        let
            ( pickup, cmd ) =
                DateTimePicker.update m model.pickup
        in
        ( { model | pickup = pickup }, Cmd.map PickupMsg cmd )

## The value

### `value`

```elm
value : State -> Maybe DateTime
```

The date and the time, when both parts hold an accepted value. `Nothing`
when either part is empty or its text could not be read.

### `isValid`

```elm
isValid : State -> Bool
```

`False` when either part could not be read: the date is not a date, lies
outside `min` and `max` or is excluded by `disabledWhen`, or the time is not a
time or lies outside `minTime` and `maxTime`. Each part shows its own message
below its input. Empty parts are valid; whether they are required is for the
application to say.

Text is only tried when it is complete (a full `hh:mm`, or a date with a day, a
month and a four-digit year such as `20.10.2026` or `2026-10-20`), when the user
leaves its input or presses `Enter`, and when you call `setLimits`, so call
`setLimits` first when you check this on submit.

### `text`

```elm
text : State -> { date : String, time : String }
```

The text in the two inputs that has not been replaced by a formatted value
yet: text the user is still typing, or text that could not be read. Each part is
empty when its input shows an accepted value or nothing. Together with
`value` it tells empty inputs from garbage: `value == Nothing` and a
`text` that is not empty means there is text that is not (yet) a date or a time.
Use `isValid` to ask whether the text was tried and rejected; see also
[DatePicker.text](Klar.DatePicker.md#text) and
[TimePicker.text](Klar.TimePicker.md#text).

### `setValue`

```elm
setValue : Maybe DateTime -> State -> State
```

Sets both parts, or empties both with `Nothing`. The fields show the date
and the time formatted for the locale; text that was being typed is dropped. The
values are not checked against the limits until `setLimits` is called.

    DateTimePicker.setValue (Just shipment.pickup) model.pickup

### `clear`

```elm
clear : State -> State
```

Empties both parts. The same as `setValue Nothing`.

### `setText`

```elm
setText : { date : String, time : String } -> State -> State
```

Fills the two inputs with text as if the user had typed it, for example to
pre-fill them from text that you stored. The texts are read when the user leaves
an input or presses `Enter`, or when you call `setLimits`; until then `value`
keeps its old value.

    DateTimePicker.setText { date = "2026-10-20", time = "14:30" } model.pickup

### `setLimits`

```elm
setLimits : List (Attribute msg) -> State -> State
```

Reads both inputs again with the limits of these attributes, as if the
user had left them: pending text that can be read becomes the date or the time
and is shown formatted, and text that cannot sets the problem that `isValid`
reports. A part that was accepted before and that the limits no longer allow
keeps its text, with the message; it is never moved into the limits. Pass the
same attributes as to `view`, because `today`, the limits and the locale decide
what is valid.

Use it when a form is submitted, since the user may never have left the inputs,
and after the limits change.

    DateTimePicker.setLimits pickupLimits model.pickup

## The two parts

### `date`

```elm
date : State -> Maybe Date.Date
```

The accepted date of the date part, also while the time is still missing.
Use it to load what depends on the day, such as the free slots of that day.

### `time`

```elm
time : State -> Maybe TimePicker.Time
```

The accepted time of the time part, also while the date is still missing.

### `setDate`

```elm
setDate : Maybe Date.Date -> State -> State
```

Sets the date part alone, or empties it with `Nothing`; the time stays as
it is. Text that was being typed in the date input is dropped.

### `setTime`

```elm
setTime : Maybe TimePicker.Time -> State -> State
```

Sets the time part alone, or empties it with `Nothing`; the date stays as
it is. Text that was being typed in the time input is dropped.

## Moments and text

### `DateTime`

```elm
type alias DateTime = { date : Date.Date, time : TimePicker.Time }
```

A date and a time of day together, as a record. The `date` is a
[Klar.Date](Klar.Date.md) and the `time` a `Time` from
[Klar.TimePicker](Klar.TimePicker.md). There is no time zone: both are what the
user sees in the fields.

    { date = october20 -- from Date.fromParts 2026 10 20
    , time = { hour = 14, minute = 30 }
    }

### `toPosix`

```elm
toPosix : Time.Zone -> DateTime -> Time.Posix
```

The moment a date and time of day stand for in a time zone. On the day the
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

### `fromPosix`

```elm
fromPosix : Time.Zone -> Time.Posix -> DateTime
```

The local date and time of day of a moment in a time zone, to the minute
(seconds are dropped). The inverse of `toPosix` for every time that exists.

    DateTimePicker.fromPosix Time.utc (Time.millisToPosix 0)
    -- { date = 1970-01-01, time = { hour = 0, minute = 0 } }

### `toIso`

```elm
toIso : DateTime -> String
```

Writes `YYYY-MM-DDTHH:MM`, the local date and time of ISO 8601 without a
zone: the form to store and send, transport neutral and sortable as text.

    DateTimePicker.toIso { date = october20, time = { hour = 9, minute = 5 } }
    -- "2026-10-20T09:05"

### `fromIso`

```elm
fromIso : String -> Maybe DateTime
```

Reads `YYYY-MM-DDTHH:MM`, the form `toIso` writes. Seconds (`T14:30:00`) are
accepted and dropped. Text with a zone (`Z` or `+02:00`) is a moment rather than
a wall-clock time and gives `Nothing`, and so does a date or a time that does
not exist.

    DateTimePicker.fromIso "2026-10-20T14:30" -- Just { date = 2026-10-20, time = 14:30 }

    DateTimePicker.fromIso "2026-10-20T14:30Z" -- Nothing

## Date limits and today

### `Attribute`

```elm
type Attribute msg  -- opaque: no constructors are exposed
```

A setting of a date and time control. Make them with the functions below and
pass a list to `view`; later attributes win over earlier ones.

### `today`

```elm
today : Date.Date -> Attribute msg
```

Today, supplied by the application (the library never reads the clock). It
marks the day in the calendar, powers the "Today" button, and completes the short
forms `20.10`, `t`, `+3` and `-7` in the date field.

Without it there is no "Today" button, the short forms are not understood, and an
empty date field opens its calendar on January 2000 (or on the nearest month
inside `min` and `max`).

### `min`

```elm
min : Date.Date -> Attribute msg
```

The earliest date that can be chosen or typed: a typed date before it shows
"The date cannot be before" followed by the limit, and the calendar disables the
earlier days. The time of day has its own limit, `minTime`. Default: no limit.

### `max`

```elm
max : Date.Date -> Attribute msg
```

The latest date that can be chosen or typed: a typed date after it shows
"The date cannot be after" followed by the limit, and the calendar disables the
later days. The time of day has its own limit, `maxTime`. Default: no limit.

### `disabledWhen`

```elm
disabledWhen : (Date.Date -> Bool) -> Attribute msg
```

Dates that cannot be used, such as weekends or public holidays. The
calendar shows them disabled, and a typed one shows "The date is not available".
Default: every date is allowed.

    DateTimePicker.disabledWhen (\day -> Date.weekday day >= 6)

### `markers`

```elm
markers : List Calendar.Marker -> Attribute msg
```

Marks on days in the calendar, such as deliveries or deadlines. Make them
with `Calendar.dot` and `Calendar.count` from [Klar.Calendar](Klar.Calendar.md).
Default: none.

### `weekNumbers`

```elm
weekNumbers : Attribute msg
```

Shows ISO 8601 week numbers in the calendar. Default: off.

## Time limits and steps

### `minTime`

```elm
minTime : TimePicker.Time -> Attribute msg
```

The earliest time of day that can be chosen or typed, on every date. Default:
00:00.

    DateTimePicker.minTime { hour = 8, minute = 0 }

### `maxTime`

```elm
maxTime : TimePicker.Time -> Attribute msg
```

The latest time of day that can be chosen or typed, on every date. Default:
23:59.

    DateTimePicker.maxTime { hour = 16, minute = 0 }

### `step`

```elm
step : Int -> Attribute msg
```

Minutes between the times in the list, from 1 to 60 (other numbers are cut to
that range). A divisor of 60 (5, 10, 15, 20, 30 or 60) lines the list up with
the hour, and typed times between the steps are accepted whatever the step is.
The default is 15; see [TimePicker.step](Klar.TimePicker.md#step).

## Label, hint and error

### `label`

```elm
label : String -> Attribute msg
```

The label above the two fields. It names the group that holds them, and the
two inputs are named after it for screen readers ("Pick-up time, date" and
"Pick-up time, time"; "Date" and "Time" without a label). Give the control a
label, or hide it with `labelHidden`.

### `labelHidden`

```elm
labelHidden : Attribute msg
```

Keeps the label for screen readers but does not show it, for a control in a
toolbar or a table row. Needs `label`.

### `hint`

```elm
hint : String -> Attribute msg
```

A short help text below the two fields. It describes the group that holds
them (`aria-describedby`), so screen readers read it when the focus enters.

### `error`

```elm
error : String -> Attribute msg
```

An error message from your application, shown below the two fields and
announced to screen readers (`role="alert"`): a required date and time that is
missing, or one that conflicts with another field. It also describes the group
that holds the fields, and it does not replace the messages of the parts about
unreadable text, which appear below their own inputs.

    DateTimePicker.error "Choose a pick-up time"

### `errorMaybe`

```elm
errorMaybe : Maybe String -> Attribute msg
```

Like `error`, but takes a `Maybe`: `Nothing` means no error. Convenient when
the message lives in a `Maybe` in your model.

    DateTimePicker.errorMaybe model.pickupError

### `required`

```elm
required : Attribute msg
```

Marks the control as required: an asterisk after the label, and
`aria-required` on both inputs. The control does not enforce it; when the date or
the time is missing, test `dateTime` for `Nothing` yourself and pass an `error`.

### `optionalText`

```elm
optionalText : String -> Attribute msg
```

Text shown after the label of a control that is not `required`, such as
"(optional)". Default: none.

## Look and behavior

### `size`

```elm
size : Theme.Size -> Attribute msg
```

The size of both fields, a `Size` from [Klar.Theme](Klar.Theme.md).
Default: `Medium`.

### `locale`

```elm
locale : Locale.Locale -> Attribute msg
```

The language of the built-in text of both fields (placeholders, button
labels, error messages, names of months and weekdays) and the format in which
the date is shown: `2026-10-20` in English, `20.10.2026` in Norwegian. Default:
`Locale.default`, which is English. See [Klar.Locale](Klar.Locale.md).

### `disabled`

```elm
disabled : Bool -> Attribute msg
```

Disables both fields and their buttons: they cannot be focused or changed
and the popups cannot be opened. Takes a `Bool` so that it can come straight
from your model, for example while a form is saving. Default: `False`.

### `readOnly`

```elm
readOnly : Bool -> Attribute msg
```

The date and the time can be seen, selected and copied but not changed, and
the popups do not open. Unlike `disabled`, the inputs can still be focused.
Default: `False`.

### `clearable`

```elm
clearable : Attribute msg
```

Shows a small × button in each field while it has text; a button empties its
own field and puts the focus back in it. The buttons are not in the tab order,
and their accessible name is "Clear field". Default: no buttons.
