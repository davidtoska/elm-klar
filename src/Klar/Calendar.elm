module Klar.Calendar exposing
    ( view
    , State, init, initRange, Msg, update
    , value, setValue, range, setRange, isChoosing, anchor, clear
    , visibleRange, visibleMonth, focusedDay, setMonths, showDate, showMonth, focus, back
    , Attribute, today, min, max, disabledWhen, maxRangeDays
    , weekNumbers, todayButton, size, locale, ariaLabel
    , markers, remote, onRetry, settings, Marker, dot, count
    )

{-| A month calendar for choosing a day or a period, with small marks on days.

Use when: the calendar should always be visible, such as a delivery schedule or a day chooser beside a list of orders.
Do not use when: you need a form field with a popup (use `Klar.DatePicker` or `Klar.DateRangePicker`).
Quick path: `init`, `update`, `view`, `value`

This is the grid behind [Klar.DatePicker](Klar-DatePicker) and
[Klar.DateRangePicker](Klar-DateRangePicker).

    import Klar.Calendar as Calendar
    import Klar.Remote as Remote exposing (Remote)
    import Klar.Theme exposing (Tone(..))

    -- model
    { schedule : Calendar.State     -- Calendar.init "schedule" |> Calendar.showDate today
    , due : Remote (List Order)     -- the orders due in the visible month
    }

    -- msg
    ScheduleMsg Calendar.Msg

    -- update: load the marks again when the visible month changes
    ScheduleMsg m ->
        let
            ( schedule, cmd ) =
                Calendar.update m model.schedule

            shown =
                Calendar.visibleRange schedule
        in
        if shown /= Calendar.visibleRange model.schedule then
            ( { model | schedule = schedule, due = Remote.refresh model.due }
            , Cmd.batch [ Cmd.map ScheduleMsg cmd, fetchDue shown.from shown.to ]
            )

        else
            ( { model | schedule = schedule }, Cmd.map ScheduleMsg cmd )

    -- view
    Calendar.view ScheduleMsg
        [ Calendar.today model.today
        , Calendar.weekNumbers
        , Calendar.remote (Remote.map (List.map dueMark) model.due)
        , Calendar.onRetry RetryDue
        ]
        model.schedule

    dueMark : Order -> Calendar.Marker
    dueMark order =
        Calendar.dot order.dueOn Warning ("Order " ++ order.number ++ " due")

    -- read
    Calendar.value model.schedule   -- Maybe Date

The state holds the visible months, the keyboard focus and the selection. There
are no out-messages: read the selection with `value` (or `range`) and compare it
before and after `update` to react to a choice.

The application supplies "today" with `today`; the library never reads the
clock. The calendar marks that day and, until the user navigates or something is
chosen, shows its month. The state cannot know today before the first message,
so `visibleRange`, `visibleMonth` and `focusedDay` of an untouched calendar
report January 2000: start it with `showDate today` when you read them (to load
the first marks, for example). A start outside `min` and `max` is moved to the
nearest month that has days to choose. Without `min` and `max` the calendar runs
from 1 January of year 1 to 31 December 9999.

Marks are `dot`s and `count`s. Give a list that is always there with `markers`,
or marks that come from a backend with `remote`: while they load the grid is
busy and says "Loading" under the days, a failure says why with a "Try again"
button (`onRetry`), and marks that are refreshed stay, dimmed. Only the marks of
the visible months (and the days around them) are drawn, so a long list costs
little.

Keyboard, with focus on a day: the arrow keys move by day and week, `Home` and
`End` go to the start and end of the week (the week starts on the first day of
the locale), `PageUp` and `PageDown` change month, `Shift+PageUp` and
`Shift+PageDown` change year, and `Enter` or `Space` picks the day. The heading
opens a month chooser, and the heading of that a year chooser; both are
navigated with the arrow keys, `Home` and `End`, and `Escape` goes back one
step. Only one day is in the tab order, so `Tab` does not step through every day
of the month.

Every day is a button with a spoken label such as "Tuesday 20 October 2026",
followed by the text of its marks. Today is marked with `aria-current`, and days
that cannot be chosen with `aria-disabled`. A change of the selection is
announced politely ("Selected: Tuesday 20 October 2026"; on a range calendar
"Start: … Choose the end date." and then the period). The built-in text (month
and weekday names, "Previous month", "Today") comes from `locale`; the default
is English.

A calendar made with `initRange` selects a period with two clicks and shows a
preview while the mouse (or the keyboard focus) moves over the second day.


# View

@docs view


# State

@docs State, init, initRange, Msg, update


# The selection

@docs value, setValue, range, setRange, isChoosing, anchor, clear


# The visible months and the focus

@docs visibleRange, visibleMonth, focusedDay, setMonths, showDate, showMonth, focus, back


# Limits and today

@docs Attribute, today, min, max, disabledWhen, maxRangeDays


# Look

@docs weekNumbers, todayButton, size, locale, ariaLabel


# Marks

@docs markers, remote, onRetry, settings, Marker, dot, count

-}

import Html exposing (Html)
import Klar.Calendar.Core as Core
import Klar.Date exposing (Date)
import Klar.Locale exposing (Locale)
import Klar.Remote exposing (Remote)
import Klar.Settings exposing (Settings)
import Klar.Theme exposing (Size, Tone)



-- STATE


{-| The state of one calendar: the visible months, the focused day and the
selection. Make it with `init` or `initRange`, keep it in your model, and give
it to `view` and `update`.
-}
type alias State =
    Core.State


{-| A calendar that selects one day. The `String` is the DOM id of the
calendar and the prefix of the ids of its day and navigation buttons; it must be
unique on the page. It shows one month; see `setMonths`.

    Calendar.init "schedule" |> Calendar.showDate model.today

-}
init : String -> State
init =
    Core.init


{-| A calendar that selects a period with two clicks: the first click starts
the period, the second ends it (whichever of the two days is earlier becomes the
start). The `String` is the DOM id, as for `init`. Read the result with `range`.

    Calendar.initRange "report-period" |> Calendar.setMonths 2

-}
initRange : String -> State
initRange =
    Core.initRange


{-| The messages of a calendar. Wrap them in one constructor of your own `Msg`,
give that constructor to `view`, and pass what comes back to `update`.
-}
type alias Msg =
    Core.Msg


{-| Handles a message of the calendar: navigation, picking a day, the month and
year choosers. Returns the new state and the command that moves the browser
focus. Map the command with the constructor of your own `Msg`.

    ScheduleMsg m ->
        let
            ( schedule, cmd ) =
                Calendar.update m model.schedule
        in
        ( { model | schedule = schedule }, Cmd.map ScheduleMsg cmd )

-}
update : Msg -> State -> ( State, Cmd Msg )
update =
    Core.update



-- THE SELECTION


{-| The chosen day of a calendar made with `init`. `Nothing` before the first
choice, and always `Nothing` for a calendar made with `initRange` (read `range`).
-}
value : State -> Maybe Date
value =
    Core.value


{-| Chooses a day on a calendar made with `init` and shows its month. `Nothing`
clears the choice and leaves the visible month alone. The day is not checked
against the limits, and a range calendar ignores the call: use `setRange`.
-}
setValue : Maybe Date -> State -> State
setValue =
    Core.setValue


{-| The chosen period of a calendar made with `initRange`, the earlier day
first and both days included. `Nothing` until the second day is chosen (see
`isChoosing`), and always `Nothing` for a calendar made with `init`.
-}
range : State -> Maybe ( Date, Date )
range =
    Core.range


{-| Chooses a period on a calendar made with `initRange` and shows the month of
its first day; the two days may be given in either order. `Nothing` clears the
period and any half-made choice. The period is not checked against the limits,
and a calendar made with `init` ignores the call: use `setValue`.
-}
setRange : Maybe ( Date, Date ) -> State -> State
setRange =
    Core.setRange


{-| `True` on a range calendar after the first click, while it waits for the
second. Use it to show a hint such as "Choose the end date".
-}
isChoosing : State -> Bool
isChoosing =
    Core.isChoosing


{-| The first day of a period the user is still choosing, that is the day that
was clicked first. `Nothing` when no period is half-made.
-}
anchor : State -> Maybe Date
anchor =
    Core.anchor


{-| Forgets the choice, a day or a period (also a half-made one). The visible
month stays where it is.
-}
clear : State -> State
clear =
    Core.clear



-- THE VISIBLE MONTHS AND THE FOCUS


{-| The days of the visible months, from the first day of the first month to the
last day of the last one: the period to load marks for. Compare it before and
after `update` and fetch when it changes (see the module example). The days of
the neighbouring months that a one-month calendar shows around its weeks are
not in it; their marks are drawn when you have them.

An untouched calendar reports January 2000 although `view` shows the month of
`today`: start it with `showDate today`.

-}
visibleRange : State -> { from : Date, to : Date }
visibleRange =
    Core.visibleRange


{-| The first visible month (January is 1). An untouched calendar reports the
placeholder `{ year = 2000, month = 1 }`, as for `visibleRange`; to load marks,
use `visibleRange`, which also covers the second and third month of
`setMonths`.
-}
visibleMonth : State -> { year : Int, month : Int }
visibleMonth =
    Core.visibleMonth


{-| The day that holds the keyboard focus, the one a key press moves from.
Until the calendar has been used or told what to show it is the placeholder
2000-01-01, not today.
-}
focusedDay : State -> Date
focusedDay =
    Core.focusedDay


{-| How many months sit side by side, from 1 to 3 (other numbers are moved into
that range). Days of the neighbouring months are only shown when it is 1, and
the buttons for the previous and next month move by one month. The state holds
it, so `visibleRange` and the keyboard know every visible month. Default: 1.

    Calendar.initRange "report-period" |> Calendar.setMonths 2

-}
setMonths : Int -> State -> State
setMonths =
    Core.setMonths


{-| Shows the month of a day and makes it the focused day, so key presses start
from there. Does not change the selection, and does not move the browser focus
(see `focus`). Leaves a month or year chooser.
-}
showDate : Date -> State -> State
showDate =
    Core.showDate


{-| Shows a month, given as the year and the month number (January is 1), and
moves the focused day into it, keeping its day of the month where that exists
(31 January becomes 28 February). Does not change the selection. Leaves a month
or year chooser.

    Calendar.showMonth 2026 10 calendar

-}
showMonth : Int -> Int -> State -> State
showMonth =
    Core.showMonth


{-| Moves the browser focus into the calendar: to the focused day, or to the
current cell of a month or year chooser. Use it when the calendar has just
appeared, or after the "Try again" button of the marks (which goes away while
they load). Map the command with the constructor of your own message, as for
`update`.
-}
focus : State -> Cmd Msg
focus =
    Core.focus


{-| Leaves the month and year choosers one step at a time: from the year
chooser back to the month chooser, from the month chooser back to the days, and
the browser focus follows. `Nothing` when the calendar already shows days.
`Escape` in a chooser does the same.

A component that puts a calendar in a popup uses it for the Escape key: when it
returns `Nothing`, Escape closes the popup instead.

-}
back : State -> Maybe ( State, Cmd Msg )
back =
    Core.back



-- ATTRIBUTES


{-| A setting of a calendar. Make them with the functions below and pass a list
to `view`; later attributes win over earlier ones.
-}
type alias Attribute msg =
    Core.Attribute msg


{-| Today, supplied by the application (the library never reads the clock; get
it with `Time.now` and `Date.fromPosix` from [Klar.Date](Klar-Date)). The day
is marked, and an untouched calendar shows its month, which is January 2000
without `today`; a month outside `min` and `max` is replaced by the nearest one
inside them. Needed for `todayButton`.
-}
today : Date -> Attribute msg
today =
    Core.today


{-| The earliest day that can be chosen. Earlier days are disabled, keyboard
movement stops at the limit, and the button for the previous month is disabled
once no day of that month can be chosen. Default: 1 January of year 1.
-}
min : Date -> Attribute msg
min =
    Core.min


{-| The latest day that can be chosen. Later days are disabled, keyboard
movement stops at the limit, and the button for the next month is disabled once
no day of that month can be chosen. Default: 31 December 9999.
-}
max : Date -> Attribute msg
max =
    Core.max


{-| Days the user cannot choose, such as weekends or days a warehouse is
closed. They are drawn dimmed, announced as disabled, and cannot be picked; the
arrow keys can still move onto them. Default: no day is disabled.

    Calendar.disabledWhen (\day -> Date.weekday day >= 6)

-}
disabledWhen : (Date -> Bool) -> Attribute msg
disabledWhen =
    Core.disabledWhen


{-| The longest period a range calendar accepts, in days, counting both end
days: once the first day is chosen, days that would make the period longer are
disabled. It has no effect on a calendar made with `init`. Default: no limit.
-}
maxRangeDays : Int -> Attribute msg
maxRangeDays =
    Core.maxRangeDays


{-| Shows a column with the ISO 8601 week number of every row (the week with
the year's first Thursday is week 1; a row has the number of its Thursday).
Default: off.
-}
weekNumbers : Attribute msg
weekNumbers =
    Core.weekNumbers


{-| Shows a "Today" button below the days that takes the calendar back to the
month of today and puts the focus on today; it does not choose the day. It needs
`today`, and is disabled when today is outside `min` and `max` or excluded by
`disabledWhen`. Default: no button.
-}
todayButton : Attribute msg
todayButton =
    Core.todayButton


{-| The size of the calendar, a `Size` from [Klar.Theme](Klar-Theme).
Default: `Medium`.
-}
size : Size -> Attribute msg
size =
    Core.size


{-| The language of the built-in text: month and weekday names, button labels,
the spoken label of every day and the announcements. The columns, `Home` and
`End` follow its first day of the week (`Locale.firstDayOfWeek`; Monday in both
languages). Saturday and Sunday are drawn as the weekend. The default is
`Locale.default`, which is English; see [Klar.Locale](Klar-Locale).
-}
locale : Locale -> Attribute msg
locale =
    Core.locale


{-| The accessible name of the calendar, read by screen readers when the focus
enters it; nothing is drawn. Default: "Calendar".
-}
ariaLabel : String -> Attribute msg
ariaLabel =
    Core.ariaLabel



-- MARKS


{-| Marks that are always there, such as holidays, or the dates of a
[Klar.Recurrence](Klar-Recurrence) rule; see `dot` and `count`. For marks from
a backend use `remote` instead (the last of the two wins). The list may be long:
only the marks of the visible months are drawn. Default: none.

    Calendar.markers
        (Recurrence.between { start = firstDelivery, from = shown.from, to = shown.to } rule
            |> .dates
            |> List.map (\day -> Calendar.dot day Info "Delivery")
        )

-}
markers : List Marker -> Attribute msg
markers =
    Core.markers


{-| Marks from a backend, as a `Remote` (see [Klar.Remote](Klar-Remote)); use it
instead of `markers`. The days can be chosen in every state. While the marks are
`NotAsked` or `Loading` the grid is busy (`aria-busy`) and the line under the
days says "Loading". `Failed` says why there, with a "Try again" button when
`onRetry` is set and trying again could help. Marks that are `Kept` stay: dimmed
while they are refreshed, and with "Old data from 14:05" and a retry when the
last refresh failed. `Loaded []` is a calendar without marks.

    Calendar.remote (Remote.map (List.map dueMark) model.due)

-}
remote : Remote (List Marker) -> Attribute msg
remote =
    Core.remote


{-| The message of the "Try again" button shown when the marks of `remote`
failed. The button goes away while the marks load again, so give the focus back
with `focus` in the same `update` branch:

    RetryDue ->
        ( { model | due = Remote.Loading }
        , Cmd.batch [ fetchDue shown.from shown.to, Cmd.map ScheduleMsg (Calendar.focus model.schedule) ]
        )

-}
onRetry : msg -> Attribute msg
onRetry =
    Core.onRetry


{-| The settings of the application (see [Klar.Settings](Klar-Settings)), for the
time zone of "Old data from 14:05". Default: `Settings.default`.
-}
settings : Settings -> Attribute msg
settings =
    Core.settings


{-| A mark on a day, made with `dot` or `count` and given to the calendar with
`markers` or `remote`.
-}
type alias Marker =
    Core.Marker


{-| A colored dot on a day. The `Tone` sets the color (see
[Klar.Theme](Klar-Theme)); at most three dots are drawn on one day. The text is
the tooltip of the day and is read out by screen readers after the date, so say
what the dot means.

    Calendar.dot deliveredOn Success "Order 1042 delivered"

-}
dot : Date -> Tone -> String -> Marker
dot =
    Core.dot


{-| A small number on a day, such as the number of invoices due. Counts on the
same day are added up, and anything above nine is shown as "9+". The text is the
tooltip of the day and is read out after the date, like the text of `dot`.

    Calendar.count dueOn 3 "3 invoices due"

-}
count : Date -> Int -> String -> Marker
count =
    Core.count



-- VIEW


{-| The calendar. The first argument wraps the calendar's messages in one of
yours; the list holds the attributes (limits, marks, look), and the last
argument is the state from your model.

    Calendar.view ScheduleMsg [ Calendar.today model.today ] model.schedule

-}
view : (Msg -> msg) -> List (Attribute msg) -> State -> Html msg
view =
    Core.view
