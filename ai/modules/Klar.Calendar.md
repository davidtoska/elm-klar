# Klar.Calendar

A month calendar for choosing a day or a period, with small marks on days.

Import: `import Klar.Calendar as Calendar` | Group: Date and time

Types: `Msg`, `Event`, `State`, `Marker`, `Attribute`

## Signatures

```elm
-- View
view : (Msg -> msg) -> List Attribute -> State -> Html msg

-- State
type State  -- opaque: no constructors are exposed
type Msg  -- opaque: no constructors are exposed
type Event = DayPicked Date.Date | RangeStarted Date.Date | RangePicked Date.Date Date.Date
init : String -> State
initRange : String -> State
update : Msg -> State -> ( State, Cmd Msg )
updateWithEvent : Msg -> State -> ( State, Cmd Msg, Maybe Event )

-- The selection
selected : State -> Maybe Date.Date
range : State -> Maybe ( Date.Date, Date.Date )
isChoosing : State -> Bool
anchor : State -> Maybe Date.Date
select : Maybe Date.Date -> State -> State
setRange : Maybe ( Date.Date, Date.Date ) -> State -> State
clear : State -> State

-- The visible month and the focus
visibleMonth : State -> { year : Int, month : Int }
focusedDay : State -> Date.Date
showDate : Date.Date -> State -> State
showMonth : Int -> Int -> State -> State
focus : State -> Cmd Msg
back : State -> Maybe ( State, Cmd Msg )

-- Limits and today
type Attribute  -- opaque: no constructors are exposed
today : Date.Date -> Attribute
min : Date.Date -> Attribute
max : Date.Date -> Attribute
disabledWhen : (Date.Date -> Bool) -> Attribute
maxRangeDays : Int -> Attribute

-- Look
weekNumbers : Attribute
todayButton : Attribute
months : Int -> Attribute
size : Theme.Size -> Attribute
locale : Locale.Locale -> Attribute
label : String -> Attribute

-- Marks
type Marker  -- opaque: no constructors are exposed
markers : List Marker -> Attribute
dot : Date.Date -> Theme.Tone -> String -> Marker
count : Date.Date -> Int -> String -> Marker
```

## Documentation

A month calendar for choosing a day or a period, with small marks on days.

Use when: the calendar should always be visible, such as a delivery schedule or a day chooser beside a list of orders.
Do not use when: you need a form field with a popup (as `Klar.DatePicker` or `Klar.DateRangePicker`).
Quick path: `init`, `update`, `view`, `selected`

This is the grid behind [Klar.DatePicker](Klar.DatePicker.md) and
[Klar.DateRangePicker](Klar.DateRangePicker.md).

    import Klar.Calendar as Calendar
    import Klar.Theme exposing (Tone(..))

    -- model
    { schedule : Calendar.State }   -- Calendar.init "schedule"

    -- msg
    ScheduleMsg Calendar.Msg

    -- update
    ScheduleMsg m ->
        let
            ( schedule, cmd ) =
                Calendar.update m model.schedule
        in
        ( { model | schedule = schedule }, Cmd.map ScheduleMsg cmd )

    -- view
    Calendar.view ScheduleMsg
        [ Calendar.today model.today
        , Calendar.weekNumbers
        , Calendar.markers
            [ Calendar.dot deliveredOn Success "Order 1042 delivered"
            , Calendar.count dueOn 3 "3 invoices due"
            ]
        ]
        model.schedule

    -- read
    Calendar.selected model.schedule   -- Maybe Date

The state holds the visible month, the keyboard focus and the selection. There
are no out-messages: read the selection with `selected` (or `range`) and compare
it before and after `update` to react to a choice. A component that wraps a
calendar can use `updateWithEvent`, which also reports what the user just
picked.

The application supplies "today" with `today`; the library never reads the
clock. The calendar marks that day and, until the user navigates or something is
selected, shows its month. Without `today` an untouched calendar shows January
2000, so give it `today` or call `showDate`. A start outside `min` and `max`
(today, or January 2000) is moved to the nearest month that has days to choose.

Marks (`markers`) can be many: only those in the visible months are drawn. An
application that loads them month by month compares `visibleMonth` before and
after `update` and fetches when it changes.

Keyboard, with focus on a day: the arrow keys move by day and week, `Home` and
`End` go to the start and end of the week, `PageUp` and `PageDown` change month,
`Shift+PageUp` and `Shift+PageDown` change year, and `Enter` or `Space` picks the
day. The heading opens a month chooser, and the heading of that a year chooser;
both are navigated with the arrow keys, `Home` and `End`. Only one day is in the
tab order, so `Tab` does not step through every day of the month.

Every day is a button with a spoken label such as "Tuesday 20 October 2026",
followed by the text of its marks. Today is marked with `aria-current`, and days
that cannot be chosen with `aria-disabled`. The built-in text (month and weekday
names, "Previous month", "Today") comes from `locale`; the default is English.

A calendar made with `initRange` selects a period with two clicks and shows a
preview while the mouse (or the keyboard focus) moves over the second day.

## View

### `view`

```elm
view : (Msg -> msg) -> List Attribute -> State -> Html msg
```

The calendar. The first argument wraps the calendar's messages in one of
yours; the list holds the attributes (limits, marks, look), and the last
argument is the state from your model.

    Calendar.view ScheduleMsg [ Calendar.today model.today ] model.schedule

## State

### `State`

```elm
type State  -- opaque: no constructors are exposed
```

The state of one calendar: the visible month, the focused day and the
selection. Make it with `init` or `initRange`, keep it in your model, and give
it to `view` and `update`.

### `Msg`

```elm
type Msg  -- opaque: no constructors are exposed
```

The messages of a calendar. Wrap them in one constructor of your own `Msg`,
give that constructor to `view`, and pass what comes back to `update`.

### `Event`

```elm
type Event = DayPicked Date.Date | RangeStarted Date.Date | RangePicked Date.Date Date.Date
```

What the user just picked, as reported by `updateWithEvent`. This is meant
for components that wrap a calendar (a date picker closes its popup on
`DayPicked`); an application normally compares `selected` or `range` before and
after `update` instead.

  - `DayPicked day`: a day was chosen on a calendar made with `init`.
  - `RangeStarted day`: the first click on a calendar made with `initRange`.
  - `RangePicked from to`: the second click. The period is complete, and `from`
    is not after `to`.

### `init`

```elm
init : String -> State
```

A calendar that selects one day. The `String` is the DOM id of the
calendar and the prefix of the ids of its day and navigation buttons; it must be
unique on the page.

    Calendar.init "schedule"

### `initRange`

```elm
initRange : String -> State
```

A calendar that selects a period with two clicks: the first click starts
the period, the second ends it (whichever of the two days is earlier becomes the
start). The `String` is the DOM id, as for `init`. Read the result with `range`.

    Calendar.initRange "report-period"

### `update`

```elm
update : Msg -> State -> ( State, Cmd Msg )
```

Handles a message of the calendar: navigation, picking a day, the month and
year choosers. Returns the new state and the command that moves the browser
focus. Map the command with the constructor of your own `Msg`.

    ScheduleMsg m ->
        let
            ( schedule, cmd ) =
                Calendar.update m model.schedule
        in
        ( { model | schedule = schedule }, Cmd.map ScheduleMsg cmd )

### `updateWithEvent`

```elm
updateWithEvent : Msg -> State -> ( State, Cmd Msg, Maybe Event )
```

Like `update`, and also reports what the user just picked. The `Maybe Event`
is `Nothing` for every message that is not a pick (navigation, hovering, the
choosers).

## The selection

### `selected`

```elm
selected : State -> Maybe Date.Date
```

The chosen day of a calendar made with `init`. `Nothing` before the first
choice, and always `Nothing` for a calendar made with `initRange`.

### `range`

```elm
range : State -> Maybe ( Date.Date, Date.Date )
```

The chosen period of a calendar made with `initRange`, the earlier day
first and both days included. `Nothing` until the second day is chosen (see
`isChoosing`), and always `Nothing` for a calendar made with `init`.

### `isChoosing`

```elm
isChoosing : State -> Bool
```

`True` on a range calendar after the first click, while it waits for the
second. Use it to show a hint such as "Choose the end date".

### `anchor`

```elm
anchor : State -> Maybe Date.Date
```

The first day of a period the user is still choosing, that is the day that
was clicked first. `Nothing` when no period is half-made.

### `select`

```elm
select : Maybe Date.Date -> State -> State
```

Chooses a day on a calendar made with `init` and shows its month. `Nothing`
clears the choice and leaves the visible month alone. The day is not checked
against the limits, and a range calendar ignores the call: use `setRange`.

### `setRange`

```elm
setRange : Maybe ( Date.Date, Date.Date ) -> State -> State
```

Chooses a period on a calendar made with `initRange` and shows the month of
its first day; the two days may be given in either order. `Nothing` clears the
period and any half-made choice. The period is not checked against the limits,
and a calendar made with `init` ignores the call: use `select`.

### `clear`

```elm
clear : State -> State
```

Forgets the choice, a day or a period (also a half-made one). The visible
month stays where it is.

## The visible month and the focus

### `visibleMonth`

```elm
visibleMonth : State -> { year : Int, month : Int }
```

The first visible month (January is 1); compare it before and after `update`
to load marks one month at a time. An untouched calendar reports the placeholder
`{ year = 2000, month = 1 }` although `view` shows the month of `today` (or the
nearest month inside `min` and `max`): the value is real once the user has
navigated, or after `select` or `setRange` with a value, `showDate` or
`showMonth`.

### `focusedDay`

```elm
focusedDay : State -> Date.Date
```

The day that holds the keyboard focus, the one a key press moves from.
Until the calendar has been used or told what to show it is the placeholder
2000-01-01, not today.

### `showDate`

```elm
showDate : Date.Date -> State -> State
```

Shows the month of a day and makes it the focused day, so key presses start
from there. Does not change the selection, and does not move the browser focus
(see `focus`). Leaves a month or year chooser.

### `showMonth`

```elm
showMonth : Int -> Int -> State -> State
```

Shows a month, given as the year and the month number (January is 1), and
moves the focused day into it, keeping its day of the month where that exists
(31 January becomes 28 February). Does not change the selection. Leaves a month
or year chooser.

    Calendar.showMonth 2026 10 calendar

### `focus`

```elm
focus : State -> Cmd Msg
```

Moves the browser focus into the calendar: to the focused day, or to the
current cell of a month or year chooser. Use it when the calendar has just
appeared, for example when the popup that holds it opens. Map the command with
the constructor of your own message, as for `update`.

### `back`

```elm
back : State -> Maybe ( State, Cmd Msg )
```

Leaves the month and year choosers one step at a time: from the year
chooser back to the month chooser, from the month chooser back to the days, and
the browser focus follows. `Nothing` when the calendar already shows days.

A component that puts a calendar in a popup uses it for the Escape key: when it
returns `Nothing`, Escape closes the popup instead.

## Limits and today

### `Attribute`

```elm
type Attribute  -- opaque: no constructors are exposed
```

A setting of a calendar. Make them with the functions below and pass a list
to `view`; later attributes win over earlier ones.

### `today`

```elm
today : Date.Date -> Attribute
```

Today, supplied by the application (the library never reads the clock; get
it with `Time.now` and `Date.fromPosix` from [Klar.Date](Klar.Date.md)). The day
is marked, and an untouched calendar shows its month, which is January 2000
without `today`; a month outside `min` and `max` is replaced by the nearest one
inside them. Needed for `todayButton`.

### `min`

```elm
min : Date.Date -> Attribute
```

The earliest day that can be chosen. Earlier days are disabled, keyboard
movement stops at the limit, and the button for the previous month is disabled
once no day of that month can be chosen. Default: no limit.

### `max`

```elm
max : Date.Date -> Attribute
```

The latest day that can be chosen. Later days are disabled, keyboard
movement stops at the limit, and the button for the next month is disabled once
no day of that month can be chosen. Default: no limit.

### `disabledWhen`

```elm
disabledWhen : (Date.Date -> Bool) -> Attribute
```

Days the user cannot choose, such as weekends or days a warehouse is
closed. They are drawn dimmed, announced as disabled, and cannot be picked; the
arrow keys can still move onto them. Default: no day is disabled.

    Calendar.disabledWhen (\day -> Date.weekday day >= 6)

### `maxRangeDays`

```elm
maxRangeDays : Int -> Attribute
```

The longest period a range calendar accepts, in days, counting both end
days: once the first day is chosen, days that would make the period longer are
disabled. It has no effect on a calendar made with `init`. Default: no limit.

## Look

### `weekNumbers`

```elm
weekNumbers : Attribute
```

Shows a column with the ISO 8601 week number of every row (the week with
the year's first Thursday is week 1). Weeks start on Monday. Default: off.

### `todayButton`

```elm
todayButton : Attribute
```

Shows a "Today" button below the days that takes the calendar back to the
month of today and puts the focus on today; it does not choose the day. It needs
`today`, and is disabled when today is outside `min` and `max` or excluded by
`disabledWhen`. Default: no button.

### `months`

```elm
months : Int -> Attribute
```

How many months sit side by side, from 1 to 3 (other numbers are cut to that
range); days of the neighbouring months are only shown when it is 1. The buttons
for the previous and next month move by one month. Default: 1.

### `size`

```elm
size : Theme.Size -> Attribute
```

The size of the calendar, a `Size` from [Klar.Theme](Klar.Theme.md).
Default: `Medium`.

### `locale`

```elm
locale : Locale.Locale -> Attribute
```

The language of the built-in text: month and weekday names, button labels
and the spoken label of every day. Weeks start on Monday in both languages. The
default is `Locale.default`, which is English; see [Klar.Locale](Klar.Locale.md).

### `label`

```elm
label : String -> Attribute
```

The accessible name of the calendar, read by screen readers when the focus
enters it. Default: "Calendar".

## Marks

### `Marker`

```elm
type Marker  -- opaque: no constructors are exposed
```

A mark on a day, made with `dot` or `count` and given to the calendar with
`markers`.

### `markers`

```elm
markers : List Marker -> Attribute
```

The marks to draw on days; see `dot` and `count`. The list may be long:
only the marks in the visible months are drawn. Default: none.

### `dot`

```elm
dot : Date.Date -> Theme.Tone -> String -> Marker
```

A colored dot on a day. The `Tone` sets the color (see
[Klar.Theme](Klar.Theme.md)); at most three dots are drawn on one day. The text is
the tooltip of the day and is read out by screen readers after the date, so say
what the dot means.

    Calendar.dot deliveredOn Success "Order 1042 delivered"

### `count`

```elm
count : Date.Date -> Int -> String -> Marker
```

A small number on a day, such as the number of invoices due. Counts on the
same day are added up, and anything above nine is shown as "9+". The text is the
tooltip of the day and is read out after the date, like the text of `dot`.

    Calendar.count dueOn 3 "3 invoices due"
