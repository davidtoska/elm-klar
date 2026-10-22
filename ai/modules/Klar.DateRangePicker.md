# Klar.DateRangePicker

A period field: a from date and a to date in one control, with one calendar that shows two months and a list of quick choices.

Import: `import Klar.DateRangePicker as DateRangePicker` | Group: Date and time

Types: `Msg`, `State`, `Attribute`, `Preset`

## Signatures

```elm
-- View
view : (Msg -> msg) -> List Attribute -> State -> Html msg

-- State
type State  -- opaque: no constructors are exposed
type Msg  -- opaque: no constructors are exposed
init : String -> State
update : Msg -> State -> ( State, Cmd Msg )

-- The period
range : State -> Maybe ( Date.Date, Date.Date )
from : State -> Maybe Date.Date
to : State -> Maybe Date.Date
isInvalid : State -> Bool
setRange : Maybe ( Date.Date, Date.Date ) -> State -> State
clear : State -> State
setText : { from : String, to : String } -> State -> State
validate : List Attribute -> State -> State

-- The calendar popup
isOpen : State -> Bool
open : List Attribute -> State -> ( State, Cmd Msg )
close : State -> ( State, Cmd Msg )
visibleMonth : State -> { year : Int, month : Int }

-- Quick choices
type alias Preset = { label : String, from : Date.Date, to : Date.Date }
preset : String -> Date.Date -> Date.Date -> Preset
presets : List Preset -> Attribute
noPresets : Attribute

-- Limits and today
type Attribute  -- opaque: no constructors are exposed
today : Date.Date -> Attribute
min : Date.Date -> Attribute
max : Date.Date -> Attribute
maxRangeDays : Int -> Attribute
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
size : Theme.Size -> Attribute
locale : Locale.Locale -> Attribute
disabled : Bool -> Attribute
readOnly : Bool -> Attribute
clearable : Attribute
```

## Documentation

A period field: a from date and a to date in one control, with one calendar
that shows two months and a list of quick choices.

Use when: the user chooses a period, as in reports, filters and bookings.
Do not use when: the user enters a single date (as `Klar.DatePicker`).
Quick path: `init`, `update`, `view`, `range`

For a single date see [Klar.DatePicker](Klar.DatePicker.md).

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

Here `model.today` is a [Klar.Date](Klar.Date.md) value that the application keeps;
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

The two fields take typed dates like [Klar.DatePicker](Klar.DatePicker.md); the
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
[Klar.Calendar](Klar.Calendar.md). `Escape` closes the popup (inside the month and
year choosers it goes back one step first), and `Tab` out of the popup closes it.

The two inputs sit in a `role="group"` named by the label; the name of each input
adds "from date" or "to date". The line below the calendar ("Choose the start
date", "Choose the end date", or the chosen period and its length in days) is
announced politely. The popup is placed like the one of
[Klar.DatePicker](Klar.DatePicker.md): it needs CSS anchor positioning to escape a
scrolling parent and to open above the field when there is no room below, and
without it a parent that scrolls or hides its overflow can clip it. The built-in
text comes from `locale`; the default is English.

## View

### `view`

```elm
view : (Msg -> msg) -> List Attribute -> State -> Html msg
```

The field: two text inputs (from and to) with a calendar button, and the
popup with the calendar and the quick choices while it is open. The first
argument wraps the picker's messages in one of yours.

    DateRangePicker.view PeriodMsg
        [ DateRangePicker.label "Report period"
        , DateRangePicker.today model.today
        ]
        model.period

## State

### `State`

```elm
type State  -- opaque: no constructors are exposed
```

The state of one period field: the accepted from and to dates, any text
still being typed in the two inputs, whether the calendar is open, and the
calendar itself. Make it with `init`, keep it in your model, and read it with
`range`, `from`, `to` and `isInvalid`.

### `Msg`

```elm
type Msg  -- opaque: no constructors are exposed
```

The messages of a period field. Wrap them in one constructor of your own
`Msg`, give that constructor to `view`, and pass what comes back to `update`.

### `init`

```elm
init : String -> State
```

An empty field. The `String` must be unique on the page: the two text
inputs get the DOM ids `<id>-from` and `<id>-to`, and the calendar button and
the popup get ids derived from it.

    DateRangePicker.init "report-period"

### `update`

```elm
update : Msg -> State -> ( State, Cmd Msg )
```

Handles a message of the field: typing, keys, the calendar button, the
calendar, the quick choices and the clear button. Returns the new state and the
command that moves the browser focus. Map the command with the constructor of
your own `Msg`.

    PeriodMsg m ->
        let
            ( period, cmd ) =
                DateRangePicker.update m model.period
        in
        ( { model | period = period }, Cmd.map PeriodMsg cmd )

## The period

### `range`

```elm
range : State -> Maybe ( Date.Date, Date.Date )
```

The accepted period as `( from, to )`, both days included. It is `Just` only
when both dates are valid, `from` is not after `to`, and the period is not
longer than `maxRangeDays`. While a field is empty or unreadable, or the period
is rejected, it is `Nothing`.

### `from`

```elm
from : State -> Maybe Date.Date
```

The accepted from date, or `Nothing` when that field is empty or unreadable.
It is given even when the period as a whole is not valid yet, for example when
the to date is still missing.

### `to`

```elm
to : State -> Maybe Date.Date
```

The accepted to date, or `Nothing` when that field is empty or unreadable.
Like `from`, it is given even when the period as a whole is not valid yet.

### `isInvalid`

```elm
isInvalid : State -> Bool
```

`True` when the last attempt to read the fields failed: a date is not a date,
lies outside `min` and `max`, or is excluded by `disabledWhen`, or the period is
reversed or longer than `maxRangeDays`. The field shows the first matching
message.

Text is only tried when it looks complete (ten characters, such as `2026-10-20`
or `20.10.2026`), when the user leaves a field or presses `Enter`, and when you
call `validate`, so call `validate` first when you check this on submit.

### `setRange`

```elm
setRange : Maybe ( Date.Date, Date.Date ) -> State -> State
```

Sets the period, or empties both fields with `Nothing`. The two days may be
given in either order, the earlier one becoming the from date. Text that was
being typed is dropped, and the period is not checked against the limits.

    DateRangePicker.setRange (Just ( quarterStart, quarterEnd )) model.period

### `clear`

```elm
clear : State -> State
```

Empties both fields. The same as `setRange Nothing`.

### `setText`

```elm
setText : { from : String, to : String } -> State -> State
```

Fills the two fields with text as if the user had typed it. The texts are
read when the user leaves a field or presses `Enter`, or when you call
`validate`; until then `from`, `to` and `range` keep their old values.

    DateRangePicker.setText { from = "2026-10-01", to = "2026-10-31" } model.period

### `validate`

```elm
validate : List Attribute -> State -> State
```

Reads the pending text of both fields now, as if the user had left them:
readable text becomes the date and is shown formatted, text that cannot be read
sets the problem that `isInvalid` reports. Pass the same attributes as to
`view`, because `today`, the limits, `maxRangeDays` and the locale decide what is
valid.

Use it when a form is submitted: the user may never have left the fields.

    DateRangePicker.validate attributes model.period

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
text. It opens on the from date, or else on the day given with `today`, kept
inside `min` and `max`. Pass the same attributes as to `view`: the limits come
from them.

### `close`

```elm
close : State -> ( State, Cmd Msg )
```

Closes the calendar, throws away a half-made choice, and gives the focus
back to the from field. The focus only moves if the calendar was open.

### `visibleMonth`

```elm
visibleMonth : State -> { year : Int, month : Int }
```

The first of the two months the calendar shows, as `{ year, month }`
(January is 1). For an application that loads marks one month at a time: compare
it before and after `update` and fetch when it changes. It is only meaningful
once the calendar has been opened; see
[DatePicker.visibleMonth](Klar.DatePicker.md#visiblemonth).

## Quick choices

### `Preset`

```elm
type alias Preset = { label : String, from : Date.Date, to : Date.Date }
```

A quick choice in the list beside the calendar: a `label` for its button and
the period it selects, `from` and `to`. Make one with `preset`, which also puts
the two days in order, and give a list of them to `presets`.

### `preset`

```elm
preset : String -> Date.Date -> Date.Date -> Preset
```

A quick choice with a label and a period. The two days may be given in
either order. When the user clicks it, the period is cut to `min` and `max` and
inward to the nearest days that `disabledWhen` allows; the button is disabled if
nothing is left or what is left is longer than `maxRangeDays`.

    DateRangePicker.preset "This quarter" quarterStart quarterEnd

### `presets`

```elm
presets : List Preset -> Attribute
```

Your own quick choices instead of the standard ones. They are shown even
when the field has no `today`, and follow the same rules as the standard ones
(cut to the limits, disabled when nothing is left).

    DateRangePicker.presets
        [ DateRangePicker.preset "This quarter" quarterStart quarterEnd
        , DateRangePicker.preset "Last quarter" previousStart previousEnd
        ]

### `noPresets`

```elm
noPresets : Attribute
```

No list of quick choices: only the calendar is shown.

## Limits and today

### `Attribute`

```elm
type Attribute  -- opaque: no constructors are exposed
```

A setting of a period field. Make them with the functions below and pass a
list to `view`, `validate` or `open`; later attributes win over earlier ones.

### `today`

```elm
today : Date.Date -> Attribute
```

Today, supplied by the application (the library never reads the clock). It
marks the day in the calendar, builds the standard quick choices, completes the
short forms `20.10`, `t`, `+3` and `-7` in the text fields, and decides how a
two-digit year is read.

Without it there are no standard quick choices, the short forms are not
understood, and an empty field opens its calendar on January 2000 (or on the
nearest month inside `min` and `max`).

### `min`

```elm
min : Date.Date -> Attribute
```

The earliest date that can be chosen or typed. A typed date before it shows
"The date cannot be before" followed by the limit, the calendar disables the
earlier days, and the quick choices are cut to it (one that ends before it is
disabled). Default: no limit.

### `max`

```elm
max : Date.Date -> Attribute
```

The latest date that can be chosen or typed. A typed date after it shows
"The date cannot be after" followed by the limit, the calendar disables the
later days, and the quick choices are cut to it (one that starts after it is
disabled). Default: no limit.

### `maxRangeDays`

```elm
maxRangeDays : Int -> Attribute
```

The longest period allowed, in days, counting both end days. In the calendar,
days that would make the period longer are disabled once the first day is
chosen; a typed period that is longer shows "The period cannot be longer than"
followed by the number of days, and quick choices that are longer (after being
cut to the limits) are disabled. Default: no limit.

    DateRangePicker.maxRangeDays 90

### `disabledWhen`

```elm
disabledWhen : (Date.Date -> Bool) -> Attribute
```

Dates that cannot be used, such as weekends or public holidays. The calendar
shows them disabled and a typed one shows "The date is not available". A quick
choice never starts or ends on one: it is cut inward to the nearest allowed day,
and disabled when no day of it is allowed. Default: every date is allowed.

    DateRangePicker.disabledWhen (\day -> Date.weekday day >= 6)

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

The label above the field. It also names the group that holds the two
inputs, and each input adds "from date" or "to date" to it. Give every field a
label, or hide it with `labelHidden`; without one the group is called "Choose
period".

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

A short help text below the field. It is linked to both inputs with
`aria-describedby`, so screen readers read it together with the field.

### `error`

```elm
error : String -> Attribute
```

An error message from your application, shown below the field and announced
to screen readers: a required period that is missing, or a period that
conflicts with another field. While the picker has a complaint of its own about
the dates ("Invalid date", "The start date cannot be after the end date"), that
message is shown instead.

    DateRangePicker.error "Choose a report period"

### `errorMaybe`

```elm
errorMaybe : Maybe String -> Attribute
```

Like `error`, but takes a `Maybe`: `Nothing` means no error. Convenient when
the message lives in a `Maybe` in your model.

    DateRangePicker.errorMaybe model.periodError

### `required`

```elm
required : Attribute
```

Marks the field as required: an asterisk after the label, and
`aria-required` on both inputs. The picker does not enforce it; when the period
is missing, test `range` for `Nothing` yourself and pass an `error`.

### `optionalText`

```elm
optionalText : String -> Attribute
```

Text shown after the label of a field that is not `required`, such as
"(optional)". Default: none.

## Look and behavior

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

The language of the built-in text (placeholder, button labels, quick choices,
error messages, names of months and weekdays) and the format in which the fields
show a date: `2026-10-20` in English, `20.10.2026` in Norwegian. Default:
`Locale.default`, which is English. See [Klar.Locale](Klar.Locale.md).

### `disabled`

```elm
disabled : Bool -> Attribute
```

Disables the field and its calendar button: the two inputs cannot be focused
or changed and the calendar cannot be opened. Takes a `Bool` so that it can come
straight from your model, for example while a form is saving. Default: `False`.

### `readOnly`

```elm
readOnly : Bool -> Attribute
```

The period can be seen, selected and copied but not changed, and the
calendar does not open. Unlike `disabled`, the inputs can still be focused.
Default: `False`.

### `clearable`

```elm
clearable : Attribute
```

Shows a small × button in the field while one of the inputs has text; it
empties both inputs and puts the focus back in the first. The button is not in
the tab order, and its accessible name is "Clear field". Default: no button.
