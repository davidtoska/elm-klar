# Klar.TimePicker

A 24-hour time field: type `14:30` or pick a time from a list.

Import: `import Klar.TimePicker as TimePicker` | Group: Date and time

Types: `Msg`, `State`, `Attribute`, `Time`

## Signatures

```elm
-- View
view : (Msg -> msg) -> List Attribute -> State -> Html msg

-- State
type State  -- opaque: no constructors are exposed
type Msg  -- opaque: no constructors are exposed
init : String -> State
update : Msg -> State -> ( State, Cmd Msg )

-- Times
type alias Time = { hour : Int, minute : Int }
toString : Time -> String
toMinutes : Time -> Int
fromMinutes : Int -> Time

-- The chosen time
time : State -> Maybe Time
isInvalid : State -> Bool
text : State -> String
setTime : Maybe Time -> State -> State
clear : State -> State
setText : String -> State -> State
validate : List Attribute -> State -> State

-- The list popup
isOpen : State -> Bool
open : List Attribute -> State -> ( State, Cmd Msg )
close : State -> ( State, Cmd Msg )

-- Limits and steps
type Attribute  -- opaque: no constructors are exposed
min : Time -> Attribute
max : Time -> Attribute
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
placeholder : String -> Attribute
size : Theme.Size -> Attribute
locale : Locale.Locale -> Attribute
disabled : Bool -> Attribute
readOnly : Bool -> Attribute
clearable : Attribute
alignEnd : Attribute
name : String -> Attribute
```

## Documentation

A 24-hour time field: type `14:30` or pick a time from a list.

Use when: the user enters a time of day only, such as an order cut-off.
Do not use when: the user enters a date and a time together (as `Klar.DateTimePicker`).
Quick path: `init`, `update`, `view`, `time`

It holds a time of day only. For a date and a time together see
[Klar.DateTimePicker](Klar.DateTimePicker.md).

    import Klar.TimePicker as TimePicker

    -- model
    { cutoff : TimePicker.State }   -- TimePicker.init "cutoff"

    -- msg
    CutoffMsg TimePicker.Msg

    -- update
    CutoffMsg m ->
        let
            ( cutoff, cmd ) =
                TimePicker.update m model.cutoff
        in
        ( { model | cutoff = cutoff }, Cmd.map CutoffMsg cmd )

    -- view
    TimePicker.view CutoffMsg
        [ TimePicker.label "Order cut-off"
        , TimePicker.step 15
        , TimePicker.min { hour = 8, minute = 0 }
        , TimePicker.max { hour = 16, minute = 0 }
        ]
        model.cutoff

    -- read
    TimePicker.time model.cutoff   -- Maybe { hour : Int, minute : Int }

The state holds the chosen time, and there are no out-messages: compare
`TimePicker.time` before and after `update` to react to a change. The time is
accepted when the user leaves the field, presses `Enter`, types a full `hh:mm`,
or picks a time from the list. Until then `time` keeps the last accepted value.
When the text cannot be read, `time` is `Nothing`, `isInvalid` is `True`, and
the field shows a message such as "Invalid time" or "The time cannot be before
08:00". A form should call `validate` when it is submitted, because the user may
never have left the field.

The list offers a time every `step` minutes (15 by default) between `min` and
`max`. The field itself also accepts times between the steps, such as 09:37, as
long as they are inside `min` and `max`. Typed text is read like `14:30`,
`14.30`, `1430`, `930` and `14`; the Norwegian prefix `kl`, as in `kl 14:30`, is
ignored in every locale. There is no AM or PM: hours run from 0 to 23.

The list opens when the field is clicked, with `ArrowDown`, `ArrowUp` or
`Alt+ArrowDown`, or from the clock button. The keyboard focus stays in the
field, which is a combobox with a listbox popup: `ArrowUp` and `ArrowDown` move
through the list, `PageUp` and `PageDown` move by eight, `Enter` chooses, and
`Escape` or `Alt+ArrowUp` closes it. When the field holds a time that is not in
the list, nothing is highlighted as the list opens, so `Enter` never changes it
by itself. Typing while the list is open scrolls it to the nearest time.

The list closes on a press outside it, and `Escape` closes only the list, not an
enclosing [Klar.Modal](Klar.Modal.md). It is placed like the calendar of
[Klar.DatePicker](Klar.DatePicker.md): CSS anchor positioning keeps it from being
clipped by a scrolling parent, and without it such a parent can clip it. The
built-in text (placeholder, button label and error messages) comes from
`locale`; the default is English. To work with the chosen time, `toString`,
`toMinutes` and `fromMinutes` convert between a `Time` and text or minutes.

## View

### `view`

```elm
view : (Msg -> msg) -> List Attribute -> State -> Html msg
```

The field: a text input with a clock button, and the list of times while it
is open. The first argument wraps the picker's messages in one of yours.

    TimePicker.view CutoffMsg
        [ TimePicker.label "Order cut-off", TimePicker.step 30 ]
        model.cutoff

## State

### `State`

```elm
type State  -- opaque: no constructors are exposed
```

The state of one time field: the accepted time, any text that is still being
typed, whether the list is open, and the highlighted entry. Make it with `init`,
keep it in your model, and read it with `time`, `text` and `isInvalid`.

### `Msg`

```elm
type Msg  -- opaque: no constructors are exposed
```

The messages of a time field. Wrap them in one constructor of your own `Msg`,
give that constructor to `view`, and pass what comes back to `update`.

### `init`

```elm
init : String -> State
```

An empty field. The `String` is the DOM id of the text input and must be
unique on the page; the clock button and the list get ids derived from it
(`<id>-button`, `<id>-popup` and `<id>-popup-list`).

    TimePicker.init "cutoff"

### `update`

```elm
update : Msg -> State -> ( State, Cmd Msg )
```

Handles a message of the field: typing, keys, the clock button, the list and
the clear button. Returns the new state and the command that moves the browser
focus or scrolls the list. Map the command with the constructor of your own
`Msg`.

    CutoffMsg m ->
        let
            ( cutoff, cmd ) =
                TimePicker.update m model.cutoff
        in
        ( { model | cutoff = cutoff }, Cmd.map CutoffMsg cmd )

## Times

### `Time`

```elm
type alias Time = { hour : Int, minute : Int }
```

A time of day in 24-hour time, as a record with two fields: `hour` (0 to 23)
and `minute` (0 to 59). Write the record yourself or make one with
`fromMinutes`.

    { hour = 14, minute = 30 }

### `toString`

```elm
toString : Time -> String
```

A time as `hh:mm`, with two digits for each part.

    TimePicker.toString { hour = 8, minute = 5 } -- "08:05"

### `toMinutes`

```elm
toMinutes : Time -> Int
```

Minutes since midnight, to compare or calculate with times.

    TimePicker.toMinutes { hour = 14, minute = 30 } -- 870

### `fromMinutes`

```elm
fromMinutes : Int -> Time
```

A time from minutes since midnight. It wraps around midnight, in both
directions.

    TimePicker.fromMinutes 870 -- { hour = 14, minute = 30 }

    TimePicker.fromMinutes 1500 -- { hour = 1, minute = 0 }

    TimePicker.fromMinutes -60 -- { hour = 23, minute = 0 }

## The chosen time

### `time`

```elm
time : State -> Maybe Time
```

The accepted time, or `Nothing` when the field is empty or its text could not
be read. While the user is typing it keeps the previous value until the text is
a full `hh:mm` or confirmed (see the module documentation).

### `isInvalid`

```elm
isInvalid : State -> Bool
```

`True` when the last attempt to read the field failed: the text is not a
time, or the time is outside `min` and `max`. The field then shows the matching
message.

Text is only tried when the user has typed a full `hh:mm`, leaves the field or
presses `Enter`, and when you call `validate`, so call `validate` first when you
check this on submit.

### `text`

```elm
text : State -> String
```

The text in the field that has not been replaced by the formatted time yet:
text the user is still typing, or text that could not be read. Together with
`time` it tells an empty field from garbage: `time == Nothing && text /= ""`
means there is text that is not a time (yet). Use `isInvalid` to ask whether the
text was tried and rejected; see also [DatePicker.text](Klar.DatePicker.md#text).

### `setTime`

```elm
setTime : Maybe Time -> State -> State
```

Sets the time, or empties the field with `Nothing`. The field shows the time
as `hh:mm`; text that was being typed is dropped. The time is not checked
against `min` and `max`.

    TimePicker.setTime (Just { hour = 16, minute = 0 }) model.cutoff

### `clear`

```elm
clear : State -> State
```

Empties the field. The same as `setTime Nothing`.

### `setText`

```elm
setText : String -> State -> State
```

Fills the field with text as if the user had typed it. The text is read when
the user leaves the field or presses `Enter`, or when you call `validate`; until
then `time` keeps its old value.

    TimePicker.setText "14:30" model.cutoff

### `validate`

```elm
validate : List Attribute -> State -> State
```

Reads the pending text now, as if the user had left the field: readable text
becomes the time and is shown as `hh:mm`, text that cannot be read sets the
problem that `isInvalid` reports. Pass the same attributes as to `view`, because
`min` and `max` decide what is valid.

Use it when a form is submitted: the user may never have left the field.

    TimePicker.validate attributes model.cutoff

## The list popup

### `isOpen`

```elm
isOpen : State -> Bool
```

`True` while the list of times is open. A field that is `disabled` or
`readOnly` never draws it.

### `open`

```elm
open : List Attribute -> State -> ( State, Cmd Msg )
```

Opens the list and moves the focus to the text input, where it stays.
Pending text is read first, and the list scrolls to the time closest to the
chosen one (or to 08:00). The limits and the step come from the attributes, so
pass the same list as to `view`.

### `close`

```elm
close : State -> ( State, Cmd Msg )
```

Closes the list and gives the focus back to the field. Does nothing when the
list is already closed.

## Limits and steps

### `Attribute`

```elm
type Attribute  -- opaque: no constructors are exposed
```

A setting of a time field. Make them with the functions below and pass a
list to `view`, `validate` or `open`; later attributes win over earlier ones.

### `min`

```elm
min : Time -> Attribute
```

The earliest time that can be chosen or typed. The list starts at the first
time of its step at or after it, and a typed time before it shows "The time
cannot be before" followed by the limit. Default: 00:00.

    TimePicker.min { hour = 8, minute = 0 }

### `max`

```elm
max : Time -> Attribute
```

The latest time that can be chosen or typed. The list stops at the last time
of its step at or before it, and a typed time after it shows "The time cannot be
after" followed by the limit. Default: 23:59.

    TimePicker.max { hour = 16, minute = 0 }

### `step`

```elm
step : Int -> Attribute
```

Minutes between the times in the list, from 1 to 60 (other numbers are cut to
that range). Default: 15.

The times are multiples of the step counted from midnight, so a step that divides
60 (5, 10, 15, 20, 30 or 60) lines the list up with the hour. Typed times
between the steps are accepted whatever the step is.

## Label, hint and error

### `label`

```elm
label : String -> Attribute
```

The label above the field, tied to the text input. Give every field a label,
or hide it with `labelHidden`: it is the name that screen readers announce.

### `labelHidden`

```elm
labelHidden : Attribute
```

Keeps the label for screen readers but does not show it, for a field in a
toolbar or a table row. Needs `label`.

### `hint`

```elm
hint : String -> Attribute
```

A short help text below the field. It is linked to the input with
`aria-describedby`, so screen readers read it together with the field.

### `error`

```elm
error : String -> Attribute
```

An error message from your application, shown below the field and announced
to screen readers: a required time that is missing, or a time that conflicts
with another field. While the picker has a complaint of its own about the typed
text ("Invalid time"), that message is shown instead.

    TimePicker.error "Choose a cut-off time"

### `errorMaybe`

```elm
errorMaybe : Maybe String -> Attribute
```

Like `error`, but takes a `Maybe`: `Nothing` means no error. Convenient when
the message lives in a `Maybe` in your model.

    TimePicker.errorMaybe model.cutoffError

### `required`

```elm
required : Attribute
```

Marks the field as required: an asterisk after the label, and
`aria-required` on the input. The picker does not enforce it; when the time is
missing, test `time` for `Nothing` yourself and pass an `error`.

### `optionalText`

```elm
optionalText : String -> Attribute
```

Text shown after the label of a field that is not `required`, such as
"(optional)". Default: none.

## Look and behavior

### `placeholder`

```elm
placeholder : String -> Attribute
```

The text shown in the empty field. Default: the format hint of the locale,
`hh:mm` in English.

### `size`

```elm
size : Theme.Size -> Attribute
```

The size of the field, a `Size` from [Klar.Theme](Klar.Theme.md).
Default: `Medium`.

### `locale`

```elm
locale : Locale.Locale -> Attribute
```

The language of the built-in text: placeholder, button and list labels, the
"No times to choose" notice and the error messages. The time format is always
24-hour `hh:mm`. The default is `Locale.default`, which is English; see
[Klar.Locale](Klar.Locale.md).

### `disabled`

```elm
disabled : Bool -> Attribute
```

Disables the field and its clock button: the text cannot be focused or
changed and the list cannot be opened. Takes a `Bool` so that it can come
straight from your model, for example while a form is saving. Default: `False`.

### `readOnly`

```elm
readOnly : Bool -> Attribute
```

The time can be seen, selected and copied but not changed, and the list does
not open. Unlike `disabled`, the field can still be focused. Default: `False`.

### `clearable`

```elm
clearable : Attribute
```

Shows a small × button in the field while it has text; it empties the field
and puts the focus back in it. The button is not in the tab order, and its
accessible name is "Clear field". Default: no button.

### `alignEnd`

```elm
alignEnd : Attribute
```

Aligns the right edge of the list with the right edge of the field, instead
of the left edges. Use it for a field near the right side of the page, so that
the list does not run out of the window.

### `name`

```elm
name : String -> Attribute
```

The `name` attribute of the text input, for a plain HTML `form`. The value
that is sent is the text in the field. Default: none.
