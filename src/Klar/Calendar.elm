module Klar.Calendar exposing
    ( view
    , State, init, initRange, Msg, update, updateWithEvent, Event(..)
    , selected, range, isChoosing, anchor, select, setRange, clear
    , visibleMonth, focusedDay, showDate, showMonth, focus, back
    , Attribute, today, min, max, disabledWhen, maxRangeDays
    , weekNumbers, todayButton, months, size, locale, label
    , markers, Marker, dot, count
    )

{-| A month calendar for choosing a day or a period, with small marks on days.

This is the grid behind [Klar.DatePicker](Klar-DatePicker) and
[Klar.DateRangePicker](Klar-DateRangePicker). Use it on its own when the
calendar should always be visible: a delivery schedule, or a day chooser beside
a list of orders. When you need a form field with a popup, use one of the
pickers instead.

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


# View

@docs view


# State

@docs State, init, initRange, Msg, update, updateWithEvent, Event


# The selection

@docs selected, range, isChoosing, anchor, select, setRange, clear


# The visible month and the focus

@docs visibleMonth, focusedDay, showDate, showMonth, focus, back


# Limits and today

@docs Attribute, today, min, max, disabledWhen, maxRangeDays


# Look

@docs weekNumbers, todayButton, months, size, locale, label


# Marks

@docs markers, Marker, dot, count

-}

import Dict exposing (Dict)
import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Events
import Klar.Calendar.Popup as Popup
import Klar.Calendar.Util as Util
import Klar.Date as Date exposing (Date)
import Klar.Format as Format
import Klar.Icon as Icon exposing (Icon)
import Klar.Internal as Internal
import Klar.Locale as Locale exposing (Locale)
import Klar.Theme as Theme exposing (Size(..), Tone)



-- STATE


{-| The state of one calendar: the visible month, the focused day and the
selection. Make it with `init` or `initRange`, keep it in your model, and give
it to `view` and `update`.
-}
type State
    = State Inner


type alias Inner =
    { id : String
    , year : Int
    , month : Int
    , focus : Date
    , positioned : Bool
    , panel : Panel
    , cursor : Int
    , selection : Selection
    , hover : Maybe Date
    }


type Panel
    = DaysPanel
    | MonthsPanel Int
    | YearsPanel Int


type Selection
    = SingleSelection (Maybe Date)
    | RangeSelection RangeState


type RangeState
    = RangeNone
    | RangeChoosing Date
    | RangeDone Date Date


{-| The part of the configuration `update` needs. The view puts it in the
messages it sends, so `update` always works from the latest state (key presses
that arrive before the next render still add up) and never needs the
attributes.
-}
type alias Bounds =
    { today : Maybe Date
    , min : Maybe Date
    , max : Maybe Date
    , months : Int
    }


fallbackDate : Date
fallbackDate =
    Util.dateOf 2000 1 1


blank : String -> Selection -> State
blank id selection =
    State
        { id = id
        , year = Date.year fallbackDate
        , month = Date.month fallbackDate
        , focus = fallbackDate
        , positioned = False
        , panel = DaysPanel
        , cursor = 1
        , selection = selection
        , hover = Nothing
        }


{-| A calendar that selects one day. The `String` is the DOM id of the
calendar and the prefix of the ids of its day and navigation buttons; it must be
unique on the page.

    Calendar.init "schedule"

-}
init : String -> State
init id =
    blank id (SingleSelection Nothing)


{-| A calendar that selects a period with two clicks: the first click starts
the period, the second ends it (whichever of the two days is earlier becomes the
start). The `String` is the DOM id, as for `init`. Read the result with `range`.

    Calendar.initRange "report-period"

-}
initRange : String -> State
initRange id =
    blank id (RangeSelection RangeNone)


{-| The chosen day of a calendar made with `init`. `Nothing` before the first
choice, and always `Nothing` for a calendar made with `initRange`.
-}
selected : State -> Maybe Date
selected (State s) =
    case s.selection of
        SingleSelection day ->
            day

        RangeSelection _ ->
            Nothing


{-| The chosen period of a calendar made with `initRange`, the earlier day
first and both days included. `Nothing` until the second day is chosen (see
`isChoosing`), and always `Nothing` for a calendar made with `init`.
-}
range : State -> Maybe ( Date, Date )
range (State s) =
    case s.selection of
        RangeSelection (RangeDone from to) ->
            Just ( from, to )

        _ ->
            Nothing


{-| `True` on a range calendar after the first click, while it waits for the
second. Use it to show a hint such as "Choose the end date".
-}
isChoosing : State -> Bool
isChoosing state =
    anchor state /= Nothing


{-| The first day of a period the user is still choosing, that is the day that
was clicked first. `Nothing` when no period is half-made.
-}
anchor : State -> Maybe Date
anchor (State s) =
    case s.selection of
        RangeSelection (RangeChoosing first) ->
            Just first

        _ ->
            Nothing


{-| The first visible month (January is 1); compare it before and after `update`
to load marks one month at a time. An untouched calendar reports the placeholder
`{ year = 2000, month = 1 }` although `view` shows the month of `today` (or the
nearest month inside `min` and `max`): the value is real once the user has
navigated, or after `select` or `setRange` with a value, `showDate` or
`showMonth`.
-}
visibleMonth : State -> { year : Int, month : Int }
visibleMonth (State s) =
    { year = s.year, month = s.month }


{-| The day that holds the keyboard focus, the one a key press moves from.
Until the calendar has been used or told what to show it is the placeholder
2000-01-01, not today.
-}
focusedDay : State -> Date
focusedDay (State s) =
    s.focus


{-| Chooses a day on a calendar made with `init` and shows its month. `Nothing`
clears the choice and leaves the visible month alone. The day is not checked
against the limits, and a range calendar ignores the call: use `setRange`.
-}
select : Maybe Date -> State -> State
select maybeDay ((State s) as current) =
    case ( s.selection, maybeDay ) of
        ( SingleSelection _, Just day ) ->
            State
                { s
                    | selection = SingleSelection (Just day)
                    , year = Date.year day
                    , month = Date.month day
                    , focus = day
                    , positioned = True
                    , panel = DaysPanel
                }

        ( SingleSelection _, Nothing ) ->
            State { s | selection = SingleSelection Nothing }

        _ ->
            current


{-| Chooses a period on a calendar made with `initRange` and shows the month of
its first day; the two days may be given in either order. `Nothing` clears the
period and any half-made choice. The period is not checked against the limits,
and a calendar made with `init` ignores the call: use `select`.
-}
setRange : Maybe ( Date, Date ) -> State -> State
setRange maybeRange ((State s) as current) =
    case ( s.selection, maybeRange ) of
        ( RangeSelection _, Just ( a, b ) ) ->
            let
                ( from, to ) =
                    ordered a b
            in
            State
                { s
                    | selection = RangeSelection (RangeDone from to)
                    , year = Date.year from
                    , month = Date.month from
                    , focus = from
                    , positioned = True
                    , panel = DaysPanel
                    , hover = Nothing
                }

        ( RangeSelection _, Nothing ) ->
            State { s | selection = RangeSelection RangeNone, hover = Nothing }

        _ ->
            current


{-| Forgets the choice, a day or a period (also a half-made one). The visible
month stays where it is.
-}
clear : State -> State
clear (State s) =
    case s.selection of
        SingleSelection _ ->
            State { s | selection = SingleSelection Nothing }

        RangeSelection _ ->
            State { s | selection = RangeSelection RangeNone, hover = Nothing }


{-| Shows the month of a day and makes it the focused day, so key presses start
from there. Does not change the selection, and does not move the browser focus
(see `focus`). Leaves a month or year chooser.
-}
showDate : Date -> State -> State
showDate day (State s) =
    State { s | year = Date.year day, month = Date.month day, focus = day, positioned = True, panel = DaysPanel, hover = Nothing }


{-| Shows a month, given as the year and the month number (January is 1), and
moves the focused day into it, keeping its day of the month where that exists
(31 January becomes 28 February). Does not change the selection. Leaves a month
or year chooser.

    Calendar.showMonth 2026 10 calendar

-}
showMonth : Int -> Int -> State -> State
showMonth year month (State s) =
    let
        day =
            Basics.min (Date.day s.focus) (Date.daysInMonth year month)
    in
    State
        { s
            | year = year
            , month = month
            , focus = Util.dateOf year month day
            , positioned = True
            , panel = DaysPanel
        }


{-| Leaves the month and year choosers one step at a time: from the year
chooser back to the month chooser, from the month chooser back to the days, and
the browser focus follows. `Nothing` when the calendar already shows days.

A component that puts a calendar in a popup uses it for the Escape key: when it
returns `Nothing`, Escape closes the popup instead.

-}
back : State -> Maybe ( State, Cmd Msg )
back (State s) =
    case s.panel of
        DaysPanel ->
            Nothing

        MonthsPanel _ ->
            Just
                ( State { s | panel = DaysPanel }
                , Internal.focus (dayId s.id s.focus) Noop
                )

        YearsPanel _ ->
            Just
                ( State { s | panel = MonthsPanel s.year, cursor = s.month }
                , Internal.focus (monthPickId s.id s.month) Noop
                )


{-| Moves the browser focus into the calendar: to the focused day, or to the
current cell of a month or year chooser. Use it when the calendar has just
appeared, for example when the popup that holds it opens. Map the command with
the constructor of your own message, as for `update`.
-}
focus : State -> Cmd Msg
focus (State s) =
    Internal.focus (focusTarget s) Noop


focusTarget : Inner -> String
focusTarget s =
    case s.panel of
        DaysPanel ->
            dayId s.id s.focus

        MonthsPanel _ ->
            monthPickId s.id s.cursor

        YearsPanel _ ->
            yearPickId s.id s.cursor


dayId : String -> Date -> String
dayId id day =
    id ++ "-d-" ++ Date.toIso day


monthPickId : String -> Int -> String
monthPickId id month =
    id ++ "-m-" ++ String.fromInt month


yearPickId : String -> Int -> String
yearPickId id year =
    id ++ "-y-" ++ String.fromInt year


ordered : Date -> Date -> ( Date, Date )
ordered a b =
    ( Util.earlier a b, Util.later a b )



-- UPDATE


{-| The messages of a calendar. Wrap them in one constructor of your own `Msg`,
give that constructor to `view`, and pass what comes back to `update`.
-}
type Msg
    = Noop
    | Move Bounds Step Bool
    | Pick Bounds Date
    | Hover (Maybe Date)
    | OpenMonths Bounds Int Int
    | OpenYears Bounds Int
    | PanelStep Int
    | PanelEdge Bool
    | PanelPage Int
    | PickYear Int
    | ChooseMonth Bounds Int Int


{-| A move of the focused day. The `Bool` of `Move` says whether the browser
focus follows it (keyboard) or stays on the button that was clicked.
-}
type Step
    = ByDays Int
    | WeekStart
    | WeekEnd
    | ByMonths Int
    | Page Int
    | GoTo Date


{-| What the user just picked, as reported by `updateWithEvent`. This is meant
for components that wrap a calendar (a date picker closes its popup on
`DayPicked`); an application normally compares `selected` or `range` before and
after `update` instead.

  - `DayPicked day`: a day was chosen on a calendar made with `init`.
  - `RangeStarted day`: the first click on a calendar made with `initRange`.
  - `RangePicked from to`: the second click. The period is complete, and `from`
    is not after `to`.

-}
type Event
    = DayPicked Date
    | RangeStarted Date
    | RangePicked Date Date


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
update msg state =
    let
        ( next, cmd, _ ) =
            updateWithEvent msg state
    in
    ( next, cmd )


{-| Like `update`, and also reports what the user just picked. The `Maybe Event`
is `Nothing` for every message that is not a pick (navigation, hovering, the
choosers).
-}
updateWithEvent : Msg -> State -> ( State, Cmd Msg, Maybe Event )
updateWithEvent msg ((State s) as current) =
    case msg of
        Noop ->
            ( current, Cmd.none, Nothing )

        Move bounds step moveFocus ->
            let
                moved =
                    applyStep bounds step (settle bounds s)
            in
            ( State { moved | hover = Nothing }
            , if moveFocus then
                Internal.focus (dayId s.id moved.focus) Noop

              else
                Cmd.none
            , Nothing
            )

        Pick bounds day ->
            let
                settled =
                    settle bounds s

                base =
                    { settled | hover = Nothing }
                        |> showing bounds.months day
            in
            case s.selection of
                SingleSelection _ ->
                    ( State { base | selection = SingleSelection (Just day) }
                    , Cmd.none
                    , Just (DayPicked day)
                    )

                RangeSelection (RangeChoosing begin) ->
                    let
                        ( from, to ) =
                            ordered begin day
                    in
                    ( State { base | selection = RangeSelection (RangeDone from to) }
                    , Cmd.none
                    , Just (RangePicked from to)
                    )

                RangeSelection _ ->
                    ( State { base | selection = RangeSelection (RangeChoosing day) }
                    , Cmd.none
                    , Just (RangeStarted day)
                    )

        Hover day ->
            ( State { s | hover = day }, Cmd.none, Nothing )

        OpenMonths bounds year month ->
            let
                settled =
                    settle bounds s

                next =
                    { settled | panel = MonthsPanel year, cursor = month }
            in
            ( State next, Internal.focus (focusTarget next) Noop, Nothing )

        OpenYears bounds year ->
            let
                settled =
                    settle bounds s

                next =
                    { settled | panel = YearsPanel (year - modBy 20 year), cursor = year }
            in
            ( State next, Internal.focus (focusTarget next) Noop, Nothing )

        PanelStep delta ->
            let
                next =
                    case s.panel of
                        MonthsPanel _ ->
                            { s | cursor = Basics.max 1 (Basics.min 12 (s.cursor + delta)) }

                        YearsPanel _ ->
                            let
                                year =
                                    Basics.max 1 (s.cursor + delta)
                            in
                            { s | panel = YearsPanel (year - modBy 20 year), cursor = year }

                        DaysPanel ->
                            s
            in
            ( State next, Internal.focus (focusTarget next) Noop, Nothing )

        PanelEdge toEnd ->
            let
                next =
                    case s.panel of
                        MonthsPanel _ ->
                            { s
                                | cursor =
                                    if toEnd then
                                        12

                                    else
                                        1
                            }

                        YearsPanel start ->
                            { s
                                | cursor =
                                    if toEnd then
                                        start + 19

                                    else
                                        start
                            }

                        DaysPanel ->
                            s
            in
            ( State next, Internal.focus (focusTarget next) Noop, Nothing )

        PanelPage direction ->
            -- The previous and next buttons of a chooser: the browser focus stays on the button.
            case s.panel of
                MonthsPanel year ->
                    ( State { s | panel = MonthsPanel (Basics.max 1 (year + direction)) }, Cmd.none, Nothing )

                YearsPanel start ->
                    ( State
                        { s
                            | panel = YearsPanel (Basics.max 0 (start + direction * 20))
                            , cursor = Basics.max 1 (s.cursor + direction * 20)
                        }
                    , Cmd.none
                    , Nothing
                    )

                DaysPanel ->
                    ( current, Cmd.none, Nothing )

        PickYear year ->
            let
                next =
                    { s | panel = MonthsPanel year, cursor = s.month }
            in
            ( State next, Internal.focus (focusTarget next) Noop, Nothing )

        ChooseMonth bounds year month ->
            let
                settled =
                    settle bounds s

                delta =
                    Util.monthIndex year month - Util.monthIndex (Date.year settled.focus) (Date.month settled.focus)

                target =
                    Util.clampTo bounds.min bounds.max (Date.addMonths delta settled.focus)

                next =
                    { settled | panel = DaysPanel, year = year, month = month, focus = target }
            in
            ( State next, Internal.focus (dayId s.id target) Noop, Nothing )


{-| The day an untouched calendar starts on: today, or the placeholder date when
the application gave none, moved into `min` and `max` so that the first month
shown always has days that can be chosen. The library has no clock, so the
placeholder is all it can offer without `today`.
-}
startDay : Maybe Date -> Maybe Date -> Maybe Date -> Date
startDay maybeToday lower upper =
    Util.clampTo lower upper (Maybe.withDefault fallbackDate maybeToday)


{-| An untouched calendar starts at `startDay`. The first message settles it.
-}
settle : Bounds -> Inner -> Inner
settle bounds s =
    if s.positioned then
        s

    else
        let
            day =
                startDay bounds.today bounds.min bounds.max
        in
        { s | year = Date.year day, month = Date.month day, focus = day, positioned = True }


applyStep : Bounds -> Step -> Inner -> Inner
applyStep bounds step s =
    let
        clamped day =
            Util.clampTo bounds.min bounds.max day
    in
    case step of
        Page by ->
            let
                ( year, month ) =
                    Util.addMonthsTo by ( s.year, s.month )
            in
            { s
                | year = year
                , month = month
                , focus = clamped (Date.addMonths by s.focus)
            }

        ByDays n ->
            showing bounds.months (clamped (Date.addDays n s.focus)) s

        WeekStart ->
            showing bounds.months (clamped (Util.startOfWeek s.focus)) s

        WeekEnd ->
            showing bounds.months (clamped (Util.endOfWeek s.focus)) s

        ByMonths n ->
            showing bounds.months (clamped (Date.addMonths n s.focus)) s

        GoTo day ->
            showing bounds.months (clamped day) s


{-| Focus on a day, scrolling the visible months just far enough to show it.
-}
showing : Int -> Date -> Inner -> Inner
showing span target s =
    let
        first =
            Util.monthIndex s.year s.month

        wanted =
            Util.monthIndex (Date.year target) (Date.month target)

        newFirst =
            if wanted < first then
                wanted

            else if wanted > first + span - 1 then
                wanted - (span - 1)

            else
                first

        ( year, month ) =
            Util.monthOfIndex newFirst
    in
    { s | year = year, month = month, focus = target, positioned = True }



-- ATTRIBUTES


{-| A setting of a calendar. Make them with the functions below and pass a list
to `view`; later attributes win over earlier ones.
-}
type Attribute
    = Attribute (Config -> Config)


type alias Config =
    { today : Maybe Date
    , min : Maybe Date
    , max : Maybe Date
    , disabledWhen : Date -> Bool
    , weekNumbers : Bool
    , todayButton : Bool
    , markers : List Marker
    , months : Int
    , locale : Locale
    , size : Size
    , label : Maybe String
    , maxRangeDays : Maybe Int
    }


configure : List Attribute -> Config
configure attributes =
    List.foldl (\(Attribute change) config -> change config)
        { today = Nothing
        , min = Nothing
        , max = Nothing
        , disabledWhen = \_ -> False
        , weekNumbers = False
        , todayButton = False
        , markers = []
        , months = 1
        , locale = Locale.default
        , size = Medium
        , label = Nothing
        , maxRangeDays = Nothing
        }
        attributes


{-| Today, supplied by the application (the library never reads the clock; get
it with `Time.now` and `Date.fromPosix` from [Klar.Date](Klar-Date)). The day
is marked, and an untouched calendar shows its month, which is January 2000
without `today`; a month outside `min` and `max` is replaced by the nearest one
inside them. Needed for `todayButton`.
-}
today : Date -> Attribute
today value =
    Attribute (\config -> { config | today = Just value })


{-| The earliest day that can be chosen. Earlier days are disabled, keyboard
movement stops at the limit, and the button for the previous month is disabled
once no day of that month can be chosen. Default: no limit.
-}
min : Date -> Attribute
min value =
    Attribute (\config -> { config | min = Just value })


{-| The latest day that can be chosen. Later days are disabled, keyboard
movement stops at the limit, and the button for the next month is disabled once
no day of that month can be chosen. Default: no limit.
-}
max : Date -> Attribute
max value =
    Attribute (\config -> { config | max = Just value })


{-| Days the user cannot choose, such as weekends or days a warehouse is
closed. They are drawn dimmed, announced as disabled, and cannot be picked; the
arrow keys can still move onto them. Default: no day is disabled.

    Calendar.disabledWhen (\day -> Date.weekday day >= 6)

-}
disabledWhen : (Date -> Bool) -> Attribute
disabledWhen predicate =
    Attribute (\config -> { config | disabledWhen = predicate })


{-| Shows a column with the ISO 8601 week number of every row (the week with
the year's first Thursday is week 1). Weeks start on Monday. Default: off.
-}
weekNumbers : Attribute
weekNumbers =
    Attribute (\config -> { config | weekNumbers = True })


{-| Shows a "Today" button below the days that takes the calendar back to the
month of today and puts the focus on today; it does not choose the day. It needs
`today`, and is disabled when today is outside `min` and `max` or excluded by
`disabledWhen`. Default: no button.
-}
todayButton : Attribute
todayButton =
    Attribute (\config -> { config | todayButton = True })


{-| How many months sit side by side, from 1 to 3 (other numbers are cut to that
range); days of the neighbouring months are only shown when it is 1. The buttons
for the previous and next month move by one month. Default: 1.
-}
months : Int -> Attribute
months value =
    Attribute (\config -> { config | months = Basics.max 1 (Basics.min 3 value) })


{-| The language of the built-in text: month and weekday names, button labels
and the spoken label of every day. Weeks start on Monday in both languages. The
default is `Locale.default`, which is English; see [Klar.Locale](Klar-Locale).
-}
locale : Locale -> Attribute
locale value =
    Attribute (\config -> { config | locale = value })


{-| The size of the calendar, a `Size` from [Klar.Theme](Klar-Theme).
Default: `Medium`.
-}
size : Size -> Attribute
size value =
    Attribute (\config -> { config | size = value })


{-| The accessible name of the calendar, read by screen readers when the focus
enters it. Default: "Calendar".
-}
label : String -> Attribute
label value =
    Attribute (\config -> { config | label = Just value })


{-| The longest period a range calendar accepts, in days, counting both end
days: once the first day is chosen, days that would make the period longer are
disabled. It has no effect on a calendar made with `init`. Default: no limit.
-}
maxRangeDays : Int -> Attribute
maxRangeDays value =
    Attribute (\config -> { config | maxRangeDays = Just value })


{-| The marks to draw on days; see `dot` and `count`. The list may be long:
only the marks in the visible months are drawn. Default: none.
-}
markers : List Marker -> Attribute
markers value =
    Attribute (\config -> { config | markers = value })


{-| A mark on a day, made with `dot` or `count` and given to the calendar with
`markers`.
-}
type Marker
    = Marker Date MarkKind String


type MarkKind
    = Dot Tone
    | Count Int


{-| A colored dot on a day. The `Tone` sets the color (see
[Klar.Theme](Klar-Theme)); at most three dots are drawn on one day. The text is
the tooltip of the day and is read out by screen readers after the date, so say
what the dot means.

    Calendar.dot deliveredOn Success "Order 1042 delivered"

-}
dot : Date -> Tone -> String -> Marker
dot day tone tooltip =
    Marker day (Dot tone) tooltip


{-| A small number on a day, such as the number of invoices due. Counts on the
same day are added up, and anything above nine is shown as "9+". The text is the
tooltip of the day and is read out after the date, like the text of `dot`.

    Calendar.count dueOn 3 "3 invoices due"

-}
count : Date -> Int -> String -> Marker
count day n tooltip =
    Marker day (Count n) tooltip


{-| Only the marks that can be seen (the visible months and the days of the
weeks around them), so thousands of marks cost almost nothing per render.
-}
visibleMarkers : Config -> Inner -> List Marker
visibleMarkers config s =
    let
        ( lastYear, lastMonth ) =
            Util.addMonthsTo (config.months - 1) ( s.year, s.month )

        low =
            Date.toEpochDay (Util.dateOf s.year s.month 1) - 7

        high =
            Date.toEpochDay (Util.dateOf lastYear lastMonth (Date.daysInMonth lastYear lastMonth)) + 7
    in
    case config.markers of
        [] ->
            []

        all ->
            List.filter
                (\(Marker day _ _) ->
                    let
                        number =
                            Date.toEpochDay day
                    in
                    number >= low && number <= high
                )
                all


markerIndex : List Marker -> Dict Int (List Marker)
markerIndex list =
    List.foldr
        (\((Marker day _ _) as marker) index ->
            Dict.update (Date.toEpochDay day)
                (\existing -> Just (marker :: Maybe.withDefault [] existing))
                index
        )
        Dict.empty
        list



-- STRINGS


type alias Strings =
    { calendar : String
    , previousMonth : String
    , nextMonth : String
    , previousYear : String
    , nextYear : String
    , previousYears : String
    , nextYears : String
    , chooseMonth : String
    , chooseYear : String
    , week : String
    , today : String
    }


strings : Locale -> Strings
strings lang =
    Locale.pick lang
        { nb =
            { calendar = "Kalender"
            , previousMonth = "Forrige måned"
            , nextMonth = "Neste måned"
            , previousYear = "Forrige år"
            , nextYear = "Neste år"
            , previousYears = "Forrige 20 år"
            , nextYears = "Neste 20 år"
            , chooseMonth = "Velg måned og år"
            , chooseYear = "Velg år"
            , week = "Uke"
            , today = "I dag"
            }
        , en =
            { calendar = "Calendar"
            , previousMonth = "Previous month"
            , nextMonth = "Next month"
            , previousYear = "Previous year"
            , nextYear = "Next year"
            , previousYears = "Previous 20 years"
            , nextYears = "Next 20 years"
            , chooseMonth = "Choose month and year"
            , chooseYear = "Choose year"
            , week = "Wk"
            , today = "Today"
            }
        }



-- VIEW


type alias Ctx msg =
    { toMsg : Msg -> msg
    , config : Config
    , bounds : Bounds
    , s : Inner
    , text : Strings
    , marks : Dict Int (List Marker)
    , span : Maybe Span
    }


type alias Span =
    { from : Date
    , to : Date
    , preview : Bool
    }


{-| The calendar. The first argument wraps the calendar's messages in one of
yours; the list holds the attributes (limits, marks, look), and the last
argument is the state from your model.

    Calendar.view ScheduleMsg [ Calendar.today model.today ] model.schedule

-}
view : (Msg -> msg) -> List Attribute -> State -> Html msg
view toMsg attributes (State raw) =
    let
        config =
            configure attributes

        s =
            effective config raw

        ctx =
            { toMsg = toMsg
            , config = config
            , bounds =
                { today = config.today
                , min = config.min
                , max = config.max
                , months = config.months
                }
            , s = s
            , text = strings config.locale
            , marks = markerIndex (visibleMarkers config s)
            , span = selectionSpan s
            }
    in
    Html.div
        [ Internal.cls
            [ "klar-calendar"
            , "klar-calendar--" ++ Theme.sizeSuffix config.size
            , if config.months > 1 then
                "klar-calendar--multi"

              else
                ""
            , if config.weekNumbers then
                "klar-calendar--weeks"

              else
                ""
            ]
        , Attr.id s.id
        , Attr.attribute "role" "group"
        , Attr.attribute "aria-label" (Maybe.withDefault ctx.text.calendar config.label)
        ]
        [ case s.panel of
            DaysPanel ->
                Html.div [ Internal.cls [ "klar-calendar__body" ] ]
                    [ viewDays ctx
                    , viewTodayButton ctx
                    ]

            MonthsPanel year ->
                viewMonths ctx year

            YearsPanel start ->
                viewYears ctx start
        ]


{-| An untouched calendar follows `startDay`: the month of `today`, or the nearest
month inside `min` and `max` when today is outside them, or January 2000 when
there is neither.
-}
effective : Config -> Inner -> Inner
effective config s =
    if s.positioned then
        s

    else
        let
            day =
                startDay config.today config.min config.max
        in
        { s | year = Date.year day, month = Date.month day, focus = day }


selectionSpan : Inner -> Maybe Span
selectionSpan s =
    case s.selection of
        RangeSelection (RangeDone from to) ->
            Just { from = from, to = to, preview = False }

        RangeSelection (RangeChoosing begin) ->
            let
                ( from, to ) =
                    ordered begin (Maybe.withDefault s.focus s.hover)
            in
            Just { from = from, to = to, preview = True }

        _ ->
            Nothing


outOfBounds : Config -> Date -> Bool
outOfBounds config day =
    (case config.min of
        Just bound ->
            Util.before day bound

        Nothing ->
            False
    )
        || (case config.max of
                Just bound ->
                    Util.after day bound

                Nothing ->
                    False
           )


isDisabled : Ctx msg -> Date -> Bool
isDisabled ctx day =
    outOfBounds ctx.config day
        || ctx.config.disabledWhen day
        || tooFar ctx day


tooFar : Ctx msg -> Date -> Bool
tooFar ctx day =
    case ( ctx.s.selection, ctx.config.maxRangeDays ) of
        ( RangeSelection (RangeChoosing begin), Just limit ) ->
            abs (Date.diffDays begin day) + 1 > limit

        _ ->
            False


{-| A month with no selectable day at all.
-}
monthOutOfBounds : Config -> Int -> Int -> Bool
monthOutOfBounds config year month =
    (case config.min of
        Just bound ->
            Util.before (Util.dateOf year month (Date.daysInMonth year month)) bound

        Nothing ->
            False
    )
        || (case config.max of
                Just bound ->
                    Util.after (Util.dateOf year month 1) bound

                Nothing ->
                    False
           )


boolString : Bool -> String
boolString value =
    if value then
        "true"

    else
        "false"


capitalize : String -> String
capitalize text =
    case String.uncons text of
        Just ( first, rest ) ->
            String.cons (Char.toUpper first) rest

        Nothing ->
            text


heading : Locale -> Int -> Int -> String
heading lang year month =
    capitalize (Locale.monthName lang month) ++ "\u{00A0}" ++ String.fromInt year



-- VIEW: header buttons


navButton : { id : String, icon : Icon, label : String, enabled : Bool, msg : msg } -> Html msg
navButton options =
    Html.button
        [ Internal.cls
            [ "klar-calendar__nav"
            , if options.enabled then
                ""

              else
                "klar-calendar__nav--disabled"
            ]
        , Attr.type_ "button"
        , Attr.id options.id
        , Attr.attribute "aria-label" options.label
        , Attr.title options.label
        , Internal.attrIf (not options.enabled) (Attr.attribute "aria-disabled" "true")
        , if options.enabled then
            Events.onClick options.msg

          else
            Internal.noAttr
        ]
        [ Icon.view options.icon ]


navSpace : Html msg
navSpace =
    Html.span [ Internal.cls [ "klar-calendar__nav-space" ] ] []


titleButton : { id : String, text : String, hint : String, msg : msg } -> Html msg
titleButton options =
    Html.button
        [ Internal.cls [ "klar-calendar__title" ]
        , Attr.type_ "button"
        , Attr.id options.id
        , Attr.title options.hint
        , Events.onClick options.msg
        ]
        [ Html.span [ Attr.attribute "aria-live" "polite" ] [ Html.text options.text ] ]



-- VIEW: days


viewTodayButton : Ctx msg -> Html msg
viewTodayButton ctx =
    case ( ctx.config.todayButton, ctx.config.today ) of
        ( True, Just day ) ->
            let
                blocked =
                    outOfBounds ctx.config day || ctx.config.disabledWhen day
            in
            Html.div [ Internal.cls [ "klar-calendar__footer" ] ]
                [ Html.button
                    [ Internal.cls [ "klar-calendar__today" ]
                    , Attr.type_ "button"
                    , Attr.id (ctx.s.id ++ "-today")
                    , Internal.attrIf blocked (Attr.attribute "aria-disabled" "true")
                    , if blocked then
                        Internal.noAttr

                      else
                        Events.onClick (ctx.toMsg (Move ctx.bounds (GoTo day) True))
                    ]
                    [ Html.text ctx.text.today ]
                ]

        _ ->
            Html.text ""


viewDays : Ctx msg -> Html msg
viewDays ctx =
    Html.div [ Internal.cls [ "klar-calendar__months" ] ]
        (List.map (viewMonth ctx) (List.range 0 (ctx.config.months - 1)))


viewMonth : Ctx msg -> Int -> Html msg
viewMonth ctx index =
    let
        s =
            ctx.s

        config =
            ctx.config

        ( year, month ) =
            Util.addMonthsTo index ( s.year, s.month )

        isFirst =
            index == 0

        isLast =
            index == config.months - 1

        titleId =
            s.id ++ "-title-" ++ String.fromInt index

        previousEnabled =
            case config.min of
                Just bound ->
                    let
                        ( py, pm ) =
                            Util.addMonthsTo -1 ( s.year, s.month )
                    in
                    Util.atOrAfter (Util.dateOf py pm (Date.daysInMonth py pm)) bound

                Nothing ->
                    True

        nextEnabled =
            case config.max of
                Just bound ->
                    let
                        ( ny, nm ) =
                            Util.addMonthsTo config.months ( s.year, s.month )
                    in
                    Util.atOrBefore (Util.dateOf ny nm 1) bound

                Nothing ->
                    True
    in
    Html.div [ Internal.cls [ "klar-calendar__month" ] ]
        [ Html.div [ Internal.cls [ "klar-calendar__header" ] ]
            [ if isFirst then
                navButton
                    { id = s.id ++ "-prev"
                    , icon = Icon.chevronLeft
                    , label = ctx.text.previousMonth
                    , enabled = previousEnabled
                    , msg = ctx.toMsg (Move ctx.bounds (Page -1) False)
                    }

              else
                navSpace
            , titleButton
                { id = titleId
                , text = heading config.locale year month
                , hint = ctx.text.chooseMonth
                , msg = ctx.toMsg (OpenMonths ctx.bounds year month)
                }
            , if isLast then
                navButton
                    { id = s.id ++ "-next"
                    , icon = Icon.chevronRight
                    , label = ctx.text.nextMonth
                    , enabled = nextEnabled
                    , msg = ctx.toMsg (Move ctx.bounds (Page 1) False)
                    }

              else
                navSpace
            ]
        , viewGrid ctx year month titleId
        ]


viewGrid : Ctx msg -> Int -> Int -> String -> Html msg
viewGrid ctx year month titleId =
    let
        config =
            ctx.config

        firstDay =
            Locale.firstDayOfWeek config.locale

        weeks =
            Date.monthGrid firstDay year month

        weekdayHead offset =
            let
                weekday =
                    modBy 7 (firstDay - 1 + offset) + 1
            in
            Html.th
                [ Internal.cls
                    [ "klar-calendar__weekday"
                    , if weekday >= 6 then
                        "klar-calendar__weekday--weekend"

                      else
                        ""
                    ]
                , Attr.attribute "scope" "col"
                , Attr.attribute "abbr" (Locale.weekdayLong config.locale weekday)
                , Attr.title (Locale.weekdayLong config.locale weekday)
                ]
                [ Html.text (Locale.weekdayShort config.locale weekday) ]

        choosing =
            case ctx.s.selection of
                RangeSelection (RangeChoosing _) ->
                    True

                _ ->
                    False
    in
    Html.table
        [ Internal.cls [ "klar-calendar__grid" ]
        , Attr.attribute "role" "grid"
        , Attr.attribute "aria-labelledby" titleId
        , Popup.onKeys (dayKeys ctx)
        , if choosing then
            Events.onMouseLeave (ctx.toMsg (Hover Nothing))

          else
            Internal.noAttr
        ]
        [ Html.thead []
            [ Html.tr []
                ((if config.weekNumbers then
                    [ Html.th
                        [ Internal.cls [ "klar-calendar__weekday", "klar-calendar__week-head" ]
                        , Attr.attribute "scope" "col"
                        ]
                        [ Html.text ctx.text.week ]
                    ]

                  else
                    []
                 )
                    ++ List.map weekdayHead (List.range 0 6)
                )
            ]
        , Html.tbody [] (List.map (viewWeek ctx year month) weeks)
        ]


viewWeek : Ctx msg -> Int -> Int -> List Date -> Html msg
viewWeek ctx year month days =
    Html.tr []
        ((case ( ctx.config.weekNumbers, List.head days ) of
            ( True, Just first ) ->
                [ Html.th
                    [ Internal.cls [ "klar-calendar__week" ]
                    , Attr.attribute "scope" "row"
                    ]
                    [ Html.text (String.fromInt (Util.isoWeek first)) ]
                ]

            _ ->
                []
         )
            ++ List.map (viewDay ctx year month) days
        )


dayKeys : Ctx msg -> List ( String, msg )
dayKeys ctx =
    let
        go step =
            ctx.toMsg (Move ctx.bounds step True)
    in
    [ ( "ArrowLeft", go (ByDays -1) )
    , ( "ArrowRight", go (ByDays 1) )
    , ( "ArrowUp", go (ByDays -7) )
    , ( "ArrowDown", go (ByDays 7) )
    , ( "Home", go WeekStart )
    , ( "End", go WeekEnd )
    , ( "PageUp", go (ByMonths -1) )
    , ( "PageDown", go (ByMonths 1) )
    , ( "Shift+PageUp", go (ByMonths -12) )
    , ( "Shift+PageDown", go (ByMonths 12) )
    ]


viewDay : Ctx msg -> Int -> Int -> Date -> Html msg
viewDay ctx year month day =
    let
        s =
            ctx.s

        config =
            ctx.config

        inMonth =
            Date.year day == year && Date.month day == month
    in
    if not inMonth && config.months > 1 then
        Html.td
            [ Internal.cls [ "klar-calendar__cell", "klar-calendar__cell--empty" ]
            , Attr.attribute "aria-hidden" "true"
            ]
            []

    else
        let
            disabled =
                isDisabled ctx day

            isToday =
                config.today == Just day

            marks =
                Dict.get (Date.toEpochDay day) ctx.marks |> Maybe.withDefault []

            labels =
                marks
                    |> List.filterMap (\(Marker _ _ text) -> Internal.nonEmpty text)

            tooltip =
                String.join "\n" labels

            choosing =
                case s.selection of
                    RangeSelection (RangeChoosing _) ->
                        True

                    _ ->
                        False

            isEndpoint =
                case s.selection of
                    SingleSelection (Just chosen) ->
                        chosen == day

                    RangeSelection (RangeDone from to) ->
                        day == from || day == to

                    RangeSelection (RangeChoosing begin) ->
                        day == begin

                    _ ->
                        False

            previewEnd =
                case s.selection of
                    RangeSelection (RangeChoosing begin) ->
                        day /= begin && day == Maybe.withDefault s.focus s.hover

                    _ ->
                        False

            inside =
                case ctx.span of
                    Just span ->
                        Util.atOrAfter day span.from && Util.atOrBefore day span.to

                    Nothing ->
                        False

            isSpanStart =
                inside && (ctx.span |> Maybe.map (\span -> span.from == day) |> Maybe.withDefault False)

            isSpanEnd =
                inside && (ctx.span |> Maybe.map (\span -> span.to == day) |> Maybe.withDefault False)

            isPreview =
                inside && (ctx.span |> Maybe.map .preview |> Maybe.withDefault False)

            totalCount =
                marks
                    |> List.filterMap
                        (\(Marker _ kind _) ->
                            case kind of
                                Count n ->
                                    Just n

                                Dot _ ->
                                    Nothing
                        )
                    |> List.sum

            tones =
                marks
                    |> List.filterMap
                        (\(Marker _ kind _) ->
                            case kind of
                                Dot tone ->
                                    Just tone

                                Count _ ->
                                    Nothing
                        )
                    |> List.take 3

            ariaLabel =
                String.join ", "
                    (dayLabel config.locale day :: labels)
        in
        Html.td
            [ Internal.cls
                [ "klar-calendar__cell"
                , if inside then
                    "klar-calendar__cell--band"

                  else
                    ""
                , if isSpanStart then
                    "klar-calendar__cell--band-start"

                  else
                    ""
                , if isSpanEnd then
                    "klar-calendar__cell--band-end"

                  else
                    ""
                , if isPreview then
                    "klar-calendar__cell--preview"

                  else
                    ""
                ]
            , Attr.attribute "role" "gridcell"
            , Attr.attribute "aria-selected" (boolString (isEndpoint || (inside && not isPreview)))
            ]
            [ Html.button
                [ Internal.cls
                    [ "klar-calendar__day"
                    , if not inMonth then
                        "klar-calendar__day--outside"

                      else
                        ""
                    , if isToday then
                        "klar-calendar__day--today"

                      else
                        ""
                    , if isEndpoint then
                        "klar-calendar__day--selected"

                      else
                        ""
                    , if previewEnd then
                        "klar-calendar__day--preview-end"

                      else
                        ""
                    , if disabled then
                        "klar-calendar__day--disabled"

                      else
                        ""
                    , if Date.weekday day >= 6 then
                        "klar-calendar__day--weekend"

                      else
                        ""
                    ]
                , Attr.type_ "button"
                , Attr.id (dayId s.id day)
                , Attr.tabindex
                    (if day == s.focus then
                        0

                     else
                        -1
                    )
                , Attr.attribute "aria-label" ariaLabel
                , Internal.attrIf isToday (Attr.attribute "aria-current" "date")
                , Internal.attrIf disabled (Attr.attribute "aria-disabled" "true")
                , Internal.attrIf (tooltip /= "") (Attr.title tooltip)
                , if disabled then
                    Internal.noAttr

                  else
                    Events.onClick (ctx.toMsg (Pick ctx.bounds day))
                , if choosing && not disabled then
                    Events.onMouseEnter (ctx.toMsg (Hover (Just day)))

                  else
                    Internal.noAttr
                ]
                [ Html.span [ Internal.cls [ "klar-calendar__num" ] ] [ Html.text (String.fromInt (Date.day day)) ]
                , if List.isEmpty tones then
                    Html.text ""

                  else
                    Html.span [ Internal.cls [ "klar-calendar__dots" ], Attr.attribute "aria-hidden" "true" ]
                        (List.map
                            (\tone ->
                                Html.span
                                    [ Internal.cls [ "klar-calendar__dot", "klar-calendar__dot--" ++ Theme.toneSuffix tone ] ]
                                    []
                            )
                            tones
                        )
                , if totalCount > 0 then
                    Html.span [ Internal.cls [ "klar-calendar__count" ], Attr.attribute "aria-hidden" "true" ]
                        [ Html.text
                            (if totalCount > 9 then
                                "9+"

                             else
                                String.fromInt totalCount
                            )
                        ]

                  else
                    Html.text ""
                ]
            ]


{-| The spoken label of a day, such as "Tuesday 20 October 2026".
-}
dayLabel : Locale -> Date -> String
dayLabel lang day =
    Locale.weekdayLong lang (Date.weekday day) ++ " " ++ Format.dateLong lang day



-- VIEW: months


viewMonths : Ctx msg -> Int -> Html msg
viewMonths ctx year =
    let
        s =
            ctx.s

        config =
            ctx.config

        previousEnabled =
            case config.min of
                Just bound ->
                    Util.atOrAfter (Util.dateOf (year - 1) 12 31) bound

                Nothing ->
                    True

        nextEnabled =
            case config.max of
                Just bound ->
                    Util.atOrBefore (Util.dateOf (year + 1) 1 1) bound

                Nothing ->
                    True

        pick m =
            let
                unavailable =
                    monthOutOfBounds config year m
            in
            Html.button
                [ Internal.cls
                    [ "klar-calendar__pick"
                    , if year == s.year && m == s.month then
                        "klar-calendar__pick--current"

                      else
                        ""
                    , if Maybe.map (\day -> Date.year day == year && Date.month day == m) config.today == Just True then
                        "klar-calendar__pick--today"

                      else
                        ""
                    , if unavailable then
                        "klar-calendar__pick--disabled"

                      else
                        ""
                    ]
                , Attr.type_ "button"
                , Attr.id (monthPickId s.id m)
                , Attr.tabindex
                    (if m == s.cursor then
                        0

                     else
                        -1
                    )
                , Internal.attrIf unavailable (Attr.attribute "aria-disabled" "true")
                , if unavailable then
                    Internal.noAttr

                  else
                    Events.onClick (ctx.toMsg (ChooseMonth ctx.bounds year m))
                ]
                [ Html.text (capitalize (Locale.monthName config.locale m)) ]
    in
    Html.div [ Internal.cls [ "klar-calendar__panel" ] ]
        [ Html.div [ Internal.cls [ "klar-calendar__header" ] ]
            [ navButton
                { id = s.id ++ "-prev"
                , icon = Icon.chevronLeft
                , label = ctx.text.previousYear
                , enabled = previousEnabled
                , msg = ctx.toMsg (PanelPage -1)
                }
            , titleButton
                { id = s.id ++ "-title-0"
                , text = String.fromInt year
                , hint = ctx.text.chooseYear
                , msg = ctx.toMsg (OpenYears ctx.bounds year)
                }
            , navButton
                { id = s.id ++ "-next"
                , icon = Icon.chevronRight
                , label = ctx.text.nextYear
                , enabled = nextEnabled
                , msg = ctx.toMsg (PanelPage 1)
                }
            ]
        , Html.div
            [ Internal.cls [ "klar-calendar__picks", "klar-calendar__picks--months" ]
            , Attr.attribute "role" "group"
            , Attr.attribute "aria-label" ctx.text.chooseMonth
            , Popup.onKeys
                [ ( "ArrowLeft", ctx.toMsg (PanelStep -1) )
                , ( "ArrowRight", ctx.toMsg (PanelStep 1) )
                , ( "ArrowUp", ctx.toMsg (PanelStep -3) )
                , ( "ArrowDown", ctx.toMsg (PanelStep 3) )
                , ( "Home", ctx.toMsg (PanelEdge False) )
                , ( "End", ctx.toMsg (PanelEdge True) )
                ]
            ]
            (List.map pick (List.range 1 12))
        ]



-- VIEW: years


viewYears : Ctx msg -> Int -> Html msg
viewYears ctx start =
    let
        s =
            ctx.s

        config =
            ctx.config

        pageSize =
            20

        previousEnabled =
            case config.min of
                Just bound ->
                    Util.atOrAfter (Util.dateOf (start - 1) 12 31) bound

                Nothing ->
                    True

        nextEnabled =
            case config.max of
                Just bound ->
                    Util.atOrBefore (Util.dateOf (start + pageSize) 1 1) bound

                Nothing ->
                    True

        yearOutOfBounds y =
            (case config.min of
                Just bound ->
                    Util.before (Util.dateOf y 12 31) bound

                Nothing ->
                    False
            )
                || (case config.max of
                        Just bound ->
                            Util.after (Util.dateOf y 1 1) bound

                        Nothing ->
                            False
                   )

        pick y =
            let
                unavailable =
                    yearOutOfBounds y
            in
            Html.button
                [ Internal.cls
                    [ "klar-calendar__pick"
                    , if y == s.year then
                        "klar-calendar__pick--current"

                      else
                        ""
                    , if Maybe.map Date.year config.today == Just y then
                        "klar-calendar__pick--today"

                      else
                        ""
                    , if unavailable then
                        "klar-calendar__pick--disabled"

                      else
                        ""
                    ]
                , Attr.type_ "button"
                , Attr.id (yearPickId s.id y)
                , Attr.tabindex
                    (if y == s.cursor then
                        0

                     else
                        -1
                    )
                , Internal.attrIf unavailable (Attr.attribute "aria-disabled" "true")
                , if unavailable then
                    Internal.noAttr

                  else
                    Events.onClick (ctx.toMsg (PickYear y))
                ]
                [ Html.text (String.fromInt y) ]
    in
    Html.div [ Internal.cls [ "klar-calendar__panel" ] ]
        [ Html.div [ Internal.cls [ "klar-calendar__header" ] ]
            [ navButton
                { id = s.id ++ "-prev"
                , icon = Icon.chevronLeft
                , label = ctx.text.previousYears
                , enabled = previousEnabled
                , msg = ctx.toMsg (PanelPage -1)
                }
            , Html.span
                [ Internal.cls [ "klar-calendar__title", "klar-calendar__title--static" ]
                , Attr.id (s.id ++ "-title-0")
                , Attr.attribute "aria-live" "polite"
                ]
                [ Html.text (String.fromInt start ++ "\u{00A0}–\u{00A0}" ++ String.fromInt (start + pageSize - 1)) ]
            , navButton
                { id = s.id ++ "-next"
                , icon = Icon.chevronRight
                , label = ctx.text.nextYears
                , enabled = nextEnabled
                , msg = ctx.toMsg (PanelPage 1)
                }
            ]
        , Html.div
            [ Internal.cls [ "klar-calendar__picks", "klar-calendar__picks--years" ]
            , Attr.attribute "role" "group"
            , Attr.attribute "aria-label" ctx.text.chooseYear
            , Popup.onKeys
                [ ( "ArrowLeft", ctx.toMsg (PanelStep -1) )
                , ( "ArrowRight", ctx.toMsg (PanelStep 1) )
                , ( "ArrowUp", ctx.toMsg (PanelStep -5) )
                , ( "ArrowDown", ctx.toMsg (PanelStep 5) )
                , ( "Home", ctx.toMsg (PanelEdge False) )
                , ( "End", ctx.toMsg (PanelEdge True) )
                , ( "PageUp", ctx.toMsg (PanelStep -pageSize) )
                , ( "PageDown", ctx.toMsg (PanelStep pageSize) )
                ]
            ]
            (List.map pick (List.range start (start + pageSize - 1)))
        ]
