# Klar.DateTimePicker

A date and a time in one control: a Klar.DatePicker and a Klar.TimePicker side by side under one label.

Import: `import Klar.DateTimePicker as DateTimePicker` | Group: Date and time

Types: `Msg`, `State`, `Attribute`, `DateTime`

## Signatures

```elm
-- View
view : (Msg -> msg) -> List Attribute -> State -> Html msg

-- State
type State  -- opaque: no constructors are exposed
type Msg  -- opaque: no constructors are exposed
init : String -> State
update : Msg -> State -> ( State, Cmd Msg )

-- The value
type alias DateTime = { date : Date.Date, time : TimePicker.Time }
dateTime : State -> Maybe DateTime
isInvalid : State -> Bool
text : State -> { date : String, time : String }
setDateTime : Maybe DateTime -> State -> State
clear : State -> State
setText : { date : String, time : String } -> State -> State
validate : List Attribute -> State -> State

-- Date limits and today
type Attribute  -- opaque: no constructors are exposed
today : Date.Date -> Attribute
min : Date.Date -> Attribute
max : Date.Date -> Attribute
disabledWhen : (Date.Date -> Bool) -> Attribute
markers : List Calendar.Marker -> Attribute
weekNumbers : Attribute

-- Time limits and steps
minTime : TimePicker.Time -> Attribute
maxTime : TimePicker.Time -> Attribute
step : Int -> Attribute

-- Label, hint and error
label : String -> Attribute
labelHidden : Attribute
hint : String -> Attribute
error : String -> Attribute
errorMaybe : Maybe String -> Attribute
required : Attribute
optionalText : String -> Attribute

-- Look and behavior
size : Theme.Size -> Attribute
locale : Locale.Locale -> Attribute
disabled : Bool -> Attribute
readOnly : Bool -> Attribute
clearable : Attribute
```

## Documentation

A date and a time in one control: a [Klar.DatePicker](Klar.DatePicker.md) and a
[Klar.TimePicker](Klar.TimePicker.md) side by side under one label.

Use it when the two belong together, such as the moment of a pick-up. For a date
alone or a time alone use the pickers themselves.

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
    DateTimePicker.dateTime model.pickup   -- Maybe { date : Date, time : Time }

Here `model.today` is a [Klar.Date](Klar.Date.md) value that the application keeps;
the library never reads the clock.

The state holds both parts, and there are no out-messages: compare `dateTime`
before and after `update` to react to a change. `dateTime` is `Just` only when
both parts hold an accepted value. When one part is empty or its text cannot be
read it is `Nothing`, and `isInvalid` tells unreadable from empty.

The two parts behave as described for [Klar.DatePicker](Klar.DatePicker.md) (typed
dates, the calendar, its keyboard support) and
[Klar.TimePicker](Klar.TimePicker.md) (typed times, the list, its keyboard support).
Their text inputs have the DOM ids `<id>-date` and `<id>-time`. Each part shows
its own message below its input when its text cannot be read, such as "Invalid
date" or "The time cannot be before 08:00". A text is read when the user leaves
its input, presses `Enter`, or has typed a complete date or time. A form should
also call `validate` when it is submitted, because the user may never have left
the inputs; `text` and `setText` give and set the text of both inputs, for
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
view : (Msg -> msg) -> List Attribute -> State -> Html msg
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
it with `init`, keep it in your model, and read it with `dateTime` and
`isInvalid`.

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

### `dateTime`

```elm
dateTime : State -> Maybe DateTime
```

The date and the time, when both parts hold an accepted value. `Nothing`
when either part is empty or its text could not be read.

### `isInvalid`

```elm
isInvalid : State -> Bool
```

`True` when either part could not be read: the date is not a date, lies
outside `min` and `max` or is excluded by `disabledWhen`, or the time is not a
time or lies outside `minTime` and `maxTime`. Each part shows its own message
below its input.

Text is only tried when it looks complete (a full `hh:mm`, or a date of ten
characters such as `2026-10-20`), when the user leaves its input or presses
`Enter`, and when you call `validate`, so call `validate` first when you check
this on submit.

### `text`

```elm
text : State -> { date : String, time : String }
```

The text in the two inputs that has not been replaced by a formatted value
yet: text the user is still typing, or text that could not be read. Each part is
empty when its input shows an accepted value or nothing. Together with
`dateTime` it tells empty inputs from garbage: `dateTime == Nothing` and a
`text` that is not empty means there is text that is not (yet) a date or a time.
Use `isInvalid` to ask whether the text was tried and rejected; see also
[DatePicker.text](Klar.DatePicker.md#text) and
[TimePicker.text](Klar.TimePicker.md#text).

### `setDateTime`

```elm
setDateTime : Maybe DateTime -> State -> State
```

Sets both parts, or empties both with `Nothing`. The fields show the date
and the time formatted for the locale; text that was being typed is dropped. The
values are not checked against the limits.

    DateTimePicker.setDateTime (Just shipment.pickup) model.pickup

### `clear`

```elm
clear : State -> State
```

Empties both parts. The same as `setDateTime Nothing`.

### `setText`

```elm
setText : { date : String, time : String } -> State -> State
```

Fills the two inputs with text as if the user had typed it, for example to
pre-fill them from text that you stored. The texts are read when the user leaves
an input or presses `Enter`, or when you call `validate`; until then `dateTime`
keeps its old value.

    DateTimePicker.setText { date = "2026-10-20", time = "14:30" } model.pickup

### `validate`

```elm
validate : List Attribute -> State -> State
```

Reads the pending text of both inputs now, as if the user had left them:
readable text becomes the date or the time and is shown formatted, text that
cannot be read sets the problem that `isInvalid` reports. Pass the same
attributes as to `view`, because `today`, the limits and the locale decide what
is valid.

Use it when a form is submitted: the user may never have left the inputs.

    DateTimePicker.validate attributes model.pickup

## Date limits and today

### `Attribute`

```elm
type Attribute  -- opaque: no constructors are exposed
```

A setting of a date and time control. Make them with the functions below and
pass a list to `view`; later attributes win over earlier ones.

### `today`

```elm
today : Date.Date -> Attribute
```

Today, supplied by the application (the library never reads the clock). It
marks the day in the calendar, powers the "Today" button, and completes the short
forms `20.10`, `t`, `+3` and `-7` in the date field.

Without it there is no "Today" button, the short forms are not understood, and an
empty date field opens its calendar on January 2000 (or on the nearest month
inside `min` and `max`).

### `min`

```elm
min : Date.Date -> Attribute
```

The earliest date that can be chosen or typed: a typed date before it shows
"The date cannot be before" followed by the limit, and the calendar disables the
earlier days. The time of day has its own limit, `minTime`. Default: no limit.

### `max`

```elm
max : Date.Date -> Attribute
```

The latest date that can be chosen or typed: a typed date after it shows
"The date cannot be after" followed by the limit, and the calendar disables the
later days. The time of day has its own limit, `maxTime`. Default: no limit.

### `disabledWhen`

```elm
disabledWhen : (Date.Date -> Bool) -> Attribute
```

Dates that cannot be used, such as weekends or public holidays. The
calendar shows them disabled, and a typed one shows "The date is not available".
Default: every date is allowed.

    DateTimePicker.disabledWhen (\day -> Date.weekday day >= 6)

### `markers`

```elm
markers : List Calendar.Marker -> Attribute
```

Marks on days in the calendar, such as deliveries or deadlines. Make them
with `Calendar.dot` and `Calendar.count` from [Klar.Calendar](Klar.Calendar.md).
Default: none.

### `weekNumbers`

```elm
weekNumbers : Attribute
```

Shows ISO 8601 week numbers in the calendar. Default: off.

## Time limits and steps

### `minTime`

```elm
minTime : TimePicker.Time -> Attribute
```

The earliest time of day that can be chosen or typed, on every date. Default:
00:00.

    DateTimePicker.minTime { hour = 8, minute = 0 }

### `maxTime`

```elm
maxTime : TimePicker.Time -> Attribute
```

The latest time of day that can be chosen or typed, on every date. Default:
23:59.

    DateTimePicker.maxTime { hour = 16, minute = 0 }

### `step`

```elm
step : Int -> Attribute
```

Minutes between the times in the list, from 1 to 60 (other numbers are cut to
that range). A divisor of 60 (5, 10, 15, 20, 30 or 60) lines the list up with
the hour, and typed times between the steps are accepted whatever the step is.
The default is 15; see [TimePicker.step](Klar.TimePicker.md#step).

## Label, hint and error

### `label`

```elm
label : String -> Attribute
```

The label above the two fields. It names the group that holds them; the two
inputs are named "Date" and "Time" for screen readers. Give the control a label,
or hide it with `labelHidden`.

### `labelHidden`

```elm
labelHidden : Attribute
```

Keeps the label for screen readers but does not show it, for a control in a
toolbar or a table row. Needs `label`.

### `hint`

```elm
hint : String -> Attribute
```

A short help text below the two fields. It describes the group that holds
them (`aria-describedby`), so screen readers read it when the focus enters.

### `error`

```elm
error : String -> Attribute
```

An error message from your application, shown below the two fields and
announced to screen readers (`role="alert"`): a required date and time that is
missing, or one that conflicts with another field. It also describes the group
that holds the fields, and it does not replace the messages of the parts about
unreadable text, which appear below their own inputs.

    DateTimePicker.error "Choose a pick-up time"

### `errorMaybe`

```elm
errorMaybe : Maybe String -> Attribute
```

Like `error`, but takes a `Maybe`: `Nothing` means no error. Convenient when
the message lives in a `Maybe` in your model.

    DateTimePicker.errorMaybe model.pickupError

### `required`

```elm
required : Attribute
```

Marks the control as required: an asterisk after the label, and
`aria-required` on both inputs. The control does not enforce it; when the date or
the time is missing, test `dateTime` for `Nothing` yourself and pass an `error`.

### `optionalText`

```elm
optionalText : String -> Attribute
```

Text shown after the label of a control that is not `required`, such as
"(optional)". Default: none.

## Look and behavior

### `size`

```elm
size : Theme.Size -> Attribute
```

The size of both fields, a `Size` from [Klar.Theme](Klar.Theme.md).
Default: `Medium`.

### `locale`

```elm
locale : Locale.Locale -> Attribute
```

The language of the built-in text of both fields (placeholders, button
labels, error messages, names of months and weekdays) and the format in which
the date is shown: `2026-10-20` in English, `20.10.2026` in Norwegian. Default:
`Locale.default`, which is English. See [Klar.Locale](Klar.Locale.md).

### `disabled`

```elm
disabled : Bool -> Attribute
```

Disables both fields and their buttons: they cannot be focused or changed
and the popups cannot be opened. Takes a `Bool` so that it can come straight
from your model, for example while a form is saving. Default: `False`.

### `readOnly`

```elm
readOnly : Bool -> Attribute
```

The date and the time can be seen, selected and copied but not changed, and
the popups do not open. Unlike `disabled`, the inputs can still be focused.
Default: `False`.

### `clearable`

```elm
clearable : Attribute
```

Shows a small × button in each field while it has text; a button empties its
own field and puts the focus back in it. The buttons are not in the tab order,
and their accessible name is "Clear field". Default: no buttons.
