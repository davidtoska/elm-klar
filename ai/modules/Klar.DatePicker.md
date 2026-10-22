# Klar.DatePicker

A date field: type the date or pick it in a calendar.

Import: `import Klar.DatePicker as DatePicker` | Group: Date and time

Types: `Msg`, `State`, `Attribute`

## Signatures

```elm
-- View
view : (Msg -> msg) -> List Attribute -> State -> Html msg

-- State
type State  -- opaque: no constructors are exposed
type Msg  -- opaque: no constructors are exposed
init : String -> State
update : Msg -> State -> ( State, Cmd Msg )

-- The date
date : State -> Maybe Date.Date
isInvalid : State -> Bool
text : State -> String
setDate : Maybe Date.Date -> State -> State
clear : State -> State
setText : String -> State -> State
validate : List Attribute -> State -> State

-- The calendar popup
isOpen : State -> Bool
open : List Attribute -> State -> ( State, Cmd Msg )
close : State -> ( State, Cmd Msg )
visibleMonth : State -> { year : Int, month : Int }

-- Limits and today
type Attribute  -- opaque: no constructors are exposed
today : Date.Date -> Attribute
min : Date.Date -> Attribute
max : Date.Date -> Attribute
disabledWhen : (Date.Date -> Bool) -> Attribute

-- Calendar
markers : List Calendar.Marker -> Attribute
weekNumbers : Attribute
alignEnd : Attribute

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
name : String -> Attribute
```

## Documentation

A date field: type the date or pick it in a calendar.

Use when: the user enters one date in a form (a due date, a delivery date).
Do not use when: the user chooses a period (as `Klar.DateRangePicker`), a date with a time of day (as `Klar.DateTimePicker`) or the calendar should always be visible (as `Klar.Calendar`).
Quick path: `init`, `update`, `view`, `date`

See also [Klar.DateRangePicker](Klar.DateRangePicker.md),
[Klar.DateTimePicker](Klar.DateTimePicker.md) and [Klar.Calendar](Klar.Calendar.md).

    import Klar.DatePicker as DatePicker

    -- model
    { dueDate : DatePicker.State }   -- DatePicker.init "due-date"

    -- msg
    DueDateMsg DatePicker.Msg

    -- update
    DueDateMsg m ->
        let
            ( dueDate, cmd ) =
                DatePicker.update m model.dueDate
        in
        ( { model | dueDate = dueDate }, Cmd.map DueDateMsg cmd )

    -- view
    DatePicker.view DueDateMsg
        [ DatePicker.label "Due date"
        , DatePicker.today model.today
        , DatePicker.min model.today
        , DatePicker.clearable
        ]
        model.dueDate

    -- read
    DatePicker.date model.dueDate   -- Maybe Date

Here `model.today` is a [Klar.Date](Klar.Date.md) value that the application keeps.
The library never reads the clock: get the time with `Time.now` and turn it into
a date with `Date.fromPosix`.

The state holds the chosen date, and there are no out-messages: compare
`DatePicker.date` before and after `update` to react to a change. The date is
accepted when the user leaves the field, presses `Enter`, types a complete
date, or picks a day. Until then `date` keeps the last accepted value. When the
text cannot be read, `date` is `Nothing`, `isInvalid` is `True`, and the field
shows a message such as "Invalid date" or "The date cannot be before
2026-01-01". That message replaces an `error` of your own for as long as it
lasts. A form should call `validate` when it is submitted, because the user may
never have left the field.

Typed dates are read leniently. With the default English locale the field shows
`2026-10-20`, and with the Norwegian locale (`Locale.nb`) `20.10.2026`; both forms are
understood whatever the locale, and so are `20/10/2026` (slash dates are day
first, never month first), `20.10.26` (a two-digit year), `20102026` or
`20261020` (digits only), `20.10` (this year), `t` or `today`, and `+3` or `-7`
(days from today). The Norwegian shortcuts `i dag` and `idag` also mean today,
and work in every locale. A two-digit year counts as 20xx up to ten years after
the current year and as 19xx beyond that, unless only the other century fits
`min` and `max`: in a field with `max` set to today, a year that would lie in the
future counts as 19xx, so `01.01.30` is 1930 in 2026.

The application gives the field `today` (for the marker in the calendar, the
"Today" button and the short forms above) and, when needed, `min`, `max` and
`disabledWhen`.

Keyboard: `ArrowDown` or `Alt+ArrowDown` in the field opens the calendar. So
does `Enter`, unless the user has just typed something that was not taken yet:
then `Enter` takes the text as the date. In the calendar the arrow keys,
`PageUp`, `PageDown`, `Home` and `End` move, `Enter` picks, and `Escape` closes
the calendar and returns to the field (inside the month and year choosers it
goes back one step first). `Tab` out of the calendar closes it. The keys of the
calendar are described in [Klar.Calendar](Klar.Calendar.md).

The calendar is a `role="dialog"` popup. Where the browser supports CSS anchor
positioning, it is never clipped by a table, card or modal body and opens above
the field when there is no room below. Other browsers draw it just below the
field with plain positioning: a parent that scrolls or hides its overflow can
clip it there, and it does not move above the field. It closes on a press
outside it. `Escape` closes only the calendar, not an enclosing
[Klar.Modal](Klar.Modal.md). The built-in text (placeholder, button labels, error
messages, month and weekday names) comes from `locale`; the default is English.

## View

### `view`

```elm
view : (Msg -> msg) -> List Attribute -> State -> Html msg
```

The field: a text input with a calendar button, and the calendar popup while
it is open. The first argument wraps the picker's messages in one of yours.

    DatePicker.view DueDateMsg
        [ DatePicker.label "Due date", DatePicker.today model.today ]
        model.dueDate

## State

### `State`

```elm
type State  -- opaque: no constructors are exposed
```

The state of one date field: the accepted date, any text that is still
being typed, whether the calendar is open, and the calendar itself. Make it with
`init`, keep it in your model, and read it with `date`, `text` and `isInvalid`.

### `Msg`

```elm
type Msg  -- opaque: no constructors are exposed
```

The messages of a date field. Wrap them in one constructor of your own `Msg`,
give that constructor to `view`, and pass what comes back to `update`.

### `init`

```elm
init : String -> State
```

An empty field. The `String` is the DOM id of the text input and must be
unique on the page; the calendar button and the popup get ids derived from it
(`<id>-button` and `<id>-popup`).

    DatePicker.init "due-date"

### `update`

```elm
update : Msg -> State -> ( State, Cmd Msg )
```

Handles a message of the field: typing, keys, the calendar button, the
calendar and the clear button. Returns the new state and the command that moves
the browser focus. Map the command with the constructor of your own `Msg`.

    DueDateMsg m ->
        let
            ( dueDate, cmd ) =
                DatePicker.update m model.dueDate
        in
        ( { model | dueDate = dueDate }, Cmd.map DueDateMsg cmd )

## The date

### `date`

```elm
date : State -> Maybe Date.Date
```

The accepted date, or `Nothing` when the field is empty or its text could not
be read. While the user is typing it keeps the previous value until the text is
complete or confirmed (see the module documentation).

### `isInvalid`

```elm
isInvalid : State -> Bool
```

`True` when the last attempt to read the field failed: the text is not a
date, the date is outside `min` and `max`, or the day is excluded by
`disabledWhen`. The field then shows the matching message.

Text is only tried when it looks complete (ten characters, such as `2026-10-20`
or `20.10.2026`), when the user leaves the field or presses `Enter`, and when
you call `validate`, so call `validate` first when you check this on submit.

### `text`

```elm
text : State -> String
```

The text in the field that has not been replaced by the formatted date yet:
text the user is still typing, or text that could not be read. Together with
`date` it tells an empty field from garbage: `date == Nothing && text /= ""`
means there is text that is not a date (yet). Use `isInvalid` to ask whether the
text was tried and rejected.

### `setDate`

```elm
setDate : Maybe Date.Date -> State -> State
```

Sets the date, or empties the field with `Nothing`. The field shows the
date formatted for the locale; text that was being typed is dropped. The date is
not checked against `min`, `max` or `disabledWhen`.

    DatePicker.setDate (Just invoice.dueDate) model.dueDate

### `clear`

```elm
clear : State -> State
```

Empties the field. The same as `setDate Nothing`.

### `setText`

```elm
setText : String -> State -> State
```

Fills the field with text as if the user had typed it. The text is read when
the user leaves the field or presses `Enter`, or when you call `validate`; until
then `date` keeps its old value.

    DatePicker.setText "2026-10-20" model.dueDate

### `validate`

```elm
validate : List Attribute -> State -> State
```

Reads the pending text now, as if the user had left the field: readable text
becomes the date and is shown formatted, text that cannot be read sets the
problem that `isInvalid` reports. Pass the same attributes as to `view`, because
`today`, the limits and the locale decide what is valid.

Use it when a form is submitted: the user may never have left the field.

    DatePicker.validate attributes model.dueDate

## The calendar popup

### `isOpen`

```elm
isOpen : State -> Bool
```

`True` while the calendar popup is open. A field that is `disabled` or
`readOnly` never draws it.

### `open`

```elm
open : List Attribute -> State -> ( State, Cmd Msg )
```

Opens the calendar and moves the focus into it, after reading any pending
text. It opens on the chosen date, or else on the day given with `today`, kept
inside `min` and `max`. Pass the same attributes as to `view`: the limits come
from them.

### `close`

```elm
close : State -> ( State, Cmd Msg )
```

Closes the calendar and gives the focus back to the field. Does nothing when
the calendar is already closed.

### `visibleMonth`

```elm
visibleMonth : State -> { year : Int, month : Int }
```

The first month the calendar shows, as `{ year, month }` (January is 1).
For an application that loads marks (deliveries, public holidays) one month at a
time: compare it before and after `update` and fetch when it changes. Only
meaningful once the calendar has been opened; before that it is a placeholder.

## Limits and today

### `Attribute`

```elm
type Attribute  -- opaque: no constructors are exposed
```

A setting of a date field. Make them with the functions below and pass a
list to `view`, `validate` or `open`; later attributes win over earlier ones.

### `today`

```elm
today : Date.Date -> Attribute
```

Today, supplied by the application (the library never reads the clock). It
marks the day in the calendar, powers the "Today" button (which picks today and
closes the calendar), completes the short forms `20.10`, `t`, `+3` and `-7`, and
decides how a two-digit year is read.

Without it there is no "Today" button, the short forms are not understood, and an
empty field opens its calendar on January 2000 (or on the nearest month inside
`min` and `max`).

### `min`

```elm
min : Date.Date -> Attribute
```

The earliest date that can be chosen or typed. A typed date before it shows
"The date cannot be before" followed by the limit, and the calendar disables the
earlier days. Default: no limit.

### `max`

```elm
max : Date.Date -> Attribute
```

The latest date that can be chosen or typed. A typed date after it shows
"The date cannot be after" followed by the limit, and the calendar disables the
later days. Default: no limit.

### `disabledWhen`

```elm
disabledWhen : (Date.Date -> Bool) -> Attribute
```

Dates that cannot be used, such as weekends or public holidays. The
calendar shows them disabled, and a typed one shows "The date is not available".
Default: every date is allowed.

    DatePicker.disabledWhen (\day -> Date.weekday day >= 6)

## Calendar

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

### `alignEnd`

```elm
alignEnd : Attribute
```

Aligns the right edge of the calendar popup with the right edge of the
field, instead of the left edges. Use it for a field near the right side of the
page, so that the popup does not run out of the window.

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
to screen readers: a required date that is missing, or a date that conflicts
with another field. While the picker has a complaint of its own about the typed
text ("Invalid date"), that message is shown instead.

    DatePicker.error "Choose a due date"

### `errorMaybe`

```elm
errorMaybe : Maybe String -> Attribute
```

Like `error`, but takes a `Maybe`: `Nothing` means no error. Convenient when
the message lives in a `Maybe` in your model.

    DatePicker.errorMaybe model.dueDateError

### `required`

```elm
required : Attribute
```

Marks the field as required: an asterisk after the label, and
`aria-required` on the input. The picker does not enforce it; when the date is
missing, test `date` for `Nothing` yourself and pass an `error`.

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
`yyyy-mm-dd` in English.

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

The language of the built-in text (placeholder, button labels, error
messages, names of months and weekdays) and the format in which the field shows
a date: `2026-10-20` in English, `20.10.2026` in Norwegian. It also decides which
order is tried first for digits-only input such as `20102026`. The default is
`Locale.default`, which is English; see [Klar.Locale](Klar.Locale.md).

### `disabled`

```elm
disabled : Bool -> Attribute
```

Disables the field and its calendar button: the text cannot be focused or
changed and the calendar cannot be opened. Takes a `Bool` so that it can come
straight from your model, for example while a form is saving. Default: `False`.

### `readOnly`

```elm
readOnly : Bool -> Attribute
```

The date can be seen, selected and copied but not changed, and the calendar
does not open. Unlike `disabled`, the field can still be focused. Default:
`False`.

### `clearable`

```elm
clearable : Attribute
```

Shows a small × button in the field while it has text; it empties the field
and puts the focus back in it. The button is not in the tab order, and its
accessible name is "Clear field". Default: no button.

### `name`

```elm
name : String -> Attribute
```

The `name` attribute of the text input, for a plain HTML `form`. The value
that is sent is the text in the field, formatted for the locale. Default: none.
