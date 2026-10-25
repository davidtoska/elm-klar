module Klar.Calendar.Core exposing (..)

{-| The implementation of the calendar. It is not exposed: `Klar.Calendar` is
its public face and carries the documentation, and its types are aliases of the
types defined here. Klar.DatePicker and Klar.DateRangePicker use
`updateWithEvent`, which also says what the user just picked, so that a popup
can close on a pick (picking the day that is already chosen changes nothing an
application could compare). An application compares `value` or `range` before
and after `update` instead, so the event is not part of the public API.
-}

import Dict exposing (Dict)
import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Events
import Html.Keyed as Keyed
import Klar.Button as Button
import Klar.Calendar.Popup as Popup
import Klar.Calendar.Util as Util
import Klar.Date as Date exposing (Date)
import Klar.Format as Format
import Klar.Icon as Icon exposing (Icon)
import Klar.Internal as Internal
import Klar.Internal.Freshness as Freshness exposing (Freshness)
import Klar.Locale as Locale exposing (Locale)
import Klar.Remote as Remote exposing (Remote)
import Klar.Settings as Settings exposing (Settings)
import Klar.Theme as Theme exposing (Size(..), Tone)



-- STATE


type State
    = State Inner


type alias Inner =
    { id : String
    , year : Int
    , month : Int
    , months : Int
    , focus : Date
    , positioned : Bool
    , panel : Panel
    , cursor : Int
    , selection : Selection
    , hover : Maybe Date
    , today : Maybe Date
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
    , min : Date
    , max : Date
    , firstDay : Int
    }


fallbackDate : Date
fallbackDate =
    Util.dateOf 2000 1 1


{-| The first day a calendar can show: Klar.Date has no year 0.
-}
lowest : Date
lowest =
    Util.dateOf 1 1 1


{-| The last day a calendar can show, the same last day as Klar.Recurrence:
a later year would need five digits.
-}
highest : Date
highest =
    Util.dateOf 9999 12 31


blank : String -> Selection -> State
blank id selection =
    State
        { id = id
        , year = Date.year fallbackDate
        , month = Date.month fallbackDate
        , months = 1
        , focus = fallbackDate
        , positioned = False
        , panel = DaysPanel
        , cursor = 1
        , selection = selection
        , hover = Nothing
        , today = Nothing
        }


init : String -> State
init id =
    blank id (SingleSelection Nothing)


initRange : String -> State
initRange id =
    blank id (RangeSelection RangeNone)


setMonths : Int -> State -> State
setMonths shown (State s) =
    State { s | months = Basics.max 1 (Basics.min 3 shown) }


value : State -> Maybe Date
value (State s) =
    case s.selection of
        SingleSelection day ->
            day

        RangeSelection _ ->
            Nothing


range : State -> Maybe ( Date, Date )
range (State s) =
    case s.selection of
        RangeSelection (RangeDone from to) ->
            Just ( from, to )

        _ ->
            Nothing


isChoosing : State -> Bool
isChoosing state =
    anchor state /= Nothing


anchor : State -> Maybe Date
anchor (State s) =
    case s.selection of
        RangeSelection (RangeChoosing first) ->
            Just first

        _ ->
            Nothing


setToday : Date -> State -> State
setToday day (State s) =
    State { s | today = Just day }


{-| Where an untouched calendar starts, as far as the state knows: the month of
today (`setToday`), or January 2000 without it. The view also moves it inside
`min` and `max` (see `effective`), which the state does not know.
-}
started : Inner -> Inner
started s =
    if s.positioned then
        s

    else
        let
            day =
                Util.clampTo (Just lowest) (Just highest) (Maybe.withDefault fallbackDate s.today)
        in
        { s | year = Date.year day, month = Date.month day, focus = day }


visibleMonth : State -> { year : Int, month : Int }
visibleMonth (State raw) =
    let
        s =
            started raw
    in
    { year = s.year, month = s.month }


visibleRange : State -> { from : Date, to : Date }
visibleRange (State raw) =
    let
        s =
            started raw

        ( lastYear, lastMonth ) =
            Util.addMonthsTo (s.months - 1) ( s.year, s.month )
    in
    { from = Util.dateOf s.year s.month 1
    , to = Util.dateOf lastYear lastMonth (Date.daysInMonth lastYear lastMonth)
    }


focusedDay : State -> Date
focusedDay (State s) =
    (started s).focus


setValue : Maybe Date -> State -> State
setValue maybeDay ((State s) as current) =
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


clear : State -> State
clear (State s) =
    case s.selection of
        SingleSelection _ ->
            State { s | selection = SingleSelection Nothing }

        RangeSelection _ ->
            State { s | selection = RangeSelection RangeNone, hover = Nothing }


showDate : Date -> State -> State
showDate day (State s) =
    State { s | year = Date.year day, month = Date.month day, focus = day, positioned = True, panel = DaysPanel, hover = Nothing }


showMonth : Int -> Int -> State -> State
showMonth year month (State raw) =
    let
        s =
            started raw

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


back : State -> Maybe ( State, Cmd Msg )
back (State s) =
    backInner s


backInner : Inner -> Maybe ( State, Cmd Msg )
backInner s =
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


focus : State -> Cmd Msg
focus (State s) =
    Internal.focus (focusTarget (started s)) Noop


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
    | Back


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


{-| What the user just picked, as reported by `updateWithEvent`, for the
components that wrap a calendar (a date picker closes its popup on `DayPicked`).

  - `DayPicked day`: a day was chosen on a calendar made with `init`.
  - `RangeStarted day`: the first click on a calendar made with `initRange`.
  - `RangePicked from to`: the second click. The period is complete, and `from`
    is not after `to`.

-}
type Event
    = DayPicked Date
    | RangeStarted Date
    | RangePicked Date Date


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
                        |> showing day

                -- A day of a neighbouring month moves the visible month, and the
                -- button that was clicked now shows another date: the browser
                -- focus follows the picked day instead.
                follow =
                    if base.year /= settled.year || base.month /= settled.month then
                        Internal.focus (dayId s.id day) Noop

                    else
                        Cmd.none
            in
            case s.selection of
                SingleSelection _ ->
                    ( State { base | selection = SingleSelection (Just day) }
                    , follow
                    , Just (DayPicked day)
                    )

                RangeSelection (RangeChoosing begin) ->
                    let
                        ( from, to ) =
                            ordered begin day
                    in
                    ( State { base | selection = RangeSelection (RangeDone from to) }
                    , follow
                    , Just (RangePicked from to)
                    )

                RangeSelection _ ->
                    ( State { base | selection = RangeSelection (RangeChoosing day) }
                    , follow
                    , Just (RangeStarted day)
                    )

        Back ->
            case backInner s of
                Just ( next, cmd ) ->
                    ( next, cmd, Nothing )

                Nothing ->
                    ( current, Cmd.none, Nothing )

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
                    { settled | panel = YearsPanel (yearPage year), cursor = year }
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
                                    clampYear (s.cursor + delta)
                            in
                            { s | panel = YearsPanel (yearPage year), cursor = year }

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
                                        clampYear (start + yearsPerPage - 1)

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
                    ( State { s | panel = MonthsPanel (clampYear (year + direction)) }, Cmd.none, Nothing )

                YearsPanel start ->
                    ( State
                        { s
                            | panel = YearsPanel (yearPage (clampYear (start + direction * yearsPerPage)))
                            , cursor = clampYear (s.cursor + direction * yearsPerPage)
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
                    clampDay bounds (Date.addMonths delta settled.focus)

                next =
                    { settled | panel = DaysPanel, year = year, month = month, focus = target }
            in
            ( State next, Internal.focus (dayId s.id target) Noop, Nothing )


yearsPerPage : Int
yearsPerPage =
    20


{-| The first year of the page of the year chooser that holds a year: pages run
from 1 to 20, 21 to 40 ... 2021 to 2040, so there is never a year 0.
-}
yearPage : Int -> Int
yearPage year =
    year - modBy yearsPerPage (year - 1)


clampYear : Int -> Int
clampYear year =
    Basics.max (Date.year lowest) (Basics.min (Date.year highest) year)


clampDay : Bounds -> Date -> Date
clampDay bounds day =
    Util.clampTo (Just bounds.min) (Just bounds.max) day


{-| The limits of a calendar: `min` and `max` when they are given, and never
outside 0001-01-01 and 9999-12-31.
-}
limits : Maybe Date -> Maybe Date -> { min : Date, max : Date }
limits lower upper =
    { min = Maybe.withDefault lowest (Maybe.map (Util.later lowest) lower)
    , max = Maybe.withDefault highest (Maybe.map (Util.earlier highest) upper)
    }


{-| The day an untouched calendar starts on: today, or the placeholder date when
the application gave none, moved into `min` and `max` so that the first month
shown always has days that can be chosen. The library has no clock, so the
placeholder is all it can offer without `today`.
-}
startDay : Maybe Date -> Date -> Date -> Date
startDay maybeToday lower upper =
    Util.clampTo (Just lower) (Just upper) (Maybe.withDefault fallbackDate maybeToday)


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
            clampDay bounds day
    in
    case step of
        Page by ->
            let
                -- The buttons are disabled at the limits, so the first visible
                -- month stays between the month of `min` and the one that puts
                -- the month of `max` last.
                lowestFirst =
                    Util.monthIndex (Date.year bounds.min) (Date.month bounds.min)

                highestFirst =
                    Basics.max lowestFirst (Util.monthIndex (Date.year bounds.max) (Date.month bounds.max) - (s.months - 1))

                ( year, month ) =
                    Util.monthOfIndex (Basics.max lowestFirst (Basics.min highestFirst (Util.monthIndex s.year s.month + by)))
            in
            { s
                | year = year
                , month = month
                , focus = clamped (Date.addMonths (Util.monthIndex year month - Util.monthIndex s.year s.month) s.focus)
            }

        ByDays n ->
            showing (clamped (Date.addDays n s.focus)) s

        WeekStart ->
            showing (clamped (Util.startOfWeek bounds.firstDay s.focus)) s

        WeekEnd ->
            showing (clamped (Util.endOfWeek bounds.firstDay s.focus)) s

        ByMonths n ->
            showing (clamped (Date.addMonths n s.focus)) s

        GoTo day ->
            showing (clamped day) s


{-| Focus on a day, scrolling the visible months just far enough to show it.
-}
showing : Date -> Inner -> Inner
showing target s =
    let
        span =
            s.months

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


type Attribute msg
    = Attribute (Config msg -> Config msg)


type alias Config msg =
    { today : Maybe Date
    , min : Maybe Date
    , max : Maybe Date
    , disabledWhen : Date -> Bool
    , weekNumbers : Bool
    , todayButton : Bool
    , marks : Remote (List Marker)
    , fromBackend : Bool
    , freshness : Freshness
    , onRetry : Maybe msg
    , settings : Settings
    , locale : Locale
    , size : Size
    , ariaLabel : Maybe String
    , maxRangeDays : Maybe Int
    , announce : Bool
    }


configure : List (Attribute msg) -> Config msg
configure attributes =
    List.foldl (\(Attribute change) config -> change config)
        { today = Nothing
        , min = Nothing
        , max = Nothing
        , disabledWhen = \_ -> False
        , weekNumbers = False
        , todayButton = False
        , marks = Remote.Loaded []
        , fromBackend = False
        , freshness = Freshness.Fresh
        , onRetry = Nothing
        , settings = Settings.default
        , locale = Locale.default
        , size = Medium
        , ariaLabel = Nothing
        , maxRangeDays = Nothing
        , announce = True
        }
        attributes


{-| For a component that announces the selection itself (Klar.DateRangePicker
has a status line of its own): the calendar's own spoken status stays silent.
-}
silent : Attribute msg
silent =
    Attribute (\config -> { config | announce = False })


{-| Today for a component that wraps a calendar and takes today as an attribute
of its own (Klar.DatePicker, Klar.DateRangePicker): it wins over the `setToday`
of the state. An application gives today with `setToday`.
-}
today : Date -> Attribute msg
today day =
    Attribute (\config -> { config | today = Just day })


min : Date -> Attribute msg
min day =
    Attribute (\config -> { config | min = Just day })


max : Date -> Attribute msg
max day =
    Attribute (\config -> { config | max = Just day })


disabledWhen : (Date -> Bool) -> Attribute msg
disabledWhen predicate =
    Attribute (\config -> { config | disabledWhen = predicate })


weekNumbers : Attribute msg
weekNumbers =
    Attribute (\config -> { config | weekNumbers = True })


todayButton : Attribute msg
todayButton =
    Attribute (\config -> { config | todayButton = True })


locale : Locale -> Attribute msg
locale lang =
    Attribute (\config -> { config | locale = lang })


size : Size -> Attribute msg
size option =
    Attribute (\config -> { config | size = option })


ariaLabel : String -> Attribute msg
ariaLabel text =
    Attribute (\config -> { config | ariaLabel = Just text })


maxRangeDays : Int -> Attribute msg
maxRangeDays days =
    Attribute (\config -> { config | maxRangeDays = Just days })


markers : List Marker -> Attribute msg
markers list =
    Attribute (\config -> { config | marks = Remote.Loaded list, fromBackend = False, freshness = Freshness.Fresh })


remote : Remote (List Marker) -> Attribute msg
remote data =
    let
        ( current, freshness ) =
            Freshness.settle data
    in
    Attribute (\config -> { config | marks = current, fromBackend = True, freshness = freshness })


onRetry : msg -> Attribute msg
onRetry msg =
    Attribute (\config -> { config | onRetry = Just msg })


settings : Settings -> Attribute msg
settings value_ =
    Attribute (\config -> { config | settings = value_ })


type Marker
    = Marker Date MarkKind String


type MarkKind
    = Dot Tone
    | Count Int


dot : Date -> Tone -> String -> Marker
dot day tone tooltip =
    Marker day (Dot tone) tooltip


count : Date -> Int -> String -> Marker
count day n tooltip =
    Marker day (Count n) tooltip


{-| Only the marks that can be seen (the visible months and the days of the
weeks around them), so thousands of marks cost almost nothing per render.
-}
visibleMarkers : List Marker -> Inner -> List Marker
visibleMarkers all s =
    let
        ( lastYear, lastMonth ) =
            Util.addMonthsTo (s.months - 1) ( s.year, s.month )

        low =
            Date.toEpochDay (Util.dateOf s.year s.month 1) - 7

        high =
            Date.toEpochDay (Util.dateOf lastYear lastMonth (Date.daysInMonth lastYear lastMonth)) + 14
    in
    case all of
        [] ->
            []

        _ ->
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
    , weekNumber : String
    , today : String
    , loading : String
    , retry : String
    , selected : String -> String
    , started : String -> String
    , period : String -> String -> String
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
            , weekNumber = "Ukenummer"
            , today = "I dag"
            , loading = "Laster"
            , retry = "Prøv igjen"
            , selected = \day -> "Valgt: " ++ day
            , started = \day -> "Start: " ++ day ++ ". Velg sluttdato."
            , period = \from to -> "Valgt periode: " ++ from ++ " til " ++ to
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
            , weekNumber = "Week number"
            , today = "Today"
            , loading = "Loading"
            , retry = "Try again"
            , selected = \day -> "Selected: " ++ day
            , started = \day -> "Start: " ++ day ++ ". Choose the end date."
            , period = \from to -> "Selected period: " ++ from ++ " to " ++ to
            }
        }



-- VIEW


type alias Ctx msg =
    { toMsg : Msg -> msg
    , config : Config msg
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


view : (Msg -> msg) -> List (Attribute msg) -> State -> Html msg
view toMsg attributes (State raw) =
    let
        given =
            configure attributes

        edges =
            limits given.min given.max

        -- Every check below sees the limits with 0001-01-01 and 9999-12-31 in
        -- them, and today from the state unless a wrapping component gives it.
        config =
            { given
                | min = Just edges.min
                , max = Just edges.max
                , today =
                    case given.today of
                        Just _ ->
                            given.today

                        Nothing ->
                            raw.today
            }

        s =
            effective config raw

        ctx =
            { toMsg = toMsg
            , config = config
            , bounds =
                { today = config.today
                , min = edges.min
                , max = edges.max
                , firstDay = Locale.firstDayOfWeek config.locale
                }
            , s = s
            , text = strings config.locale
            , marks = markerIndex (visibleMarkers (Remote.withDefault [] config.marks) s)
            , span = selectionSpan s
            }
    in
    Html.div
        [ Internal.cls
            [ "klar-calendar"
            , "klar-calendar--" ++ Internal.sizeSuffix config.size
            , if s.months > 1 then
                "klar-calendar--multi"

              else
                ""
            , if config.weekNumbers then
                "klar-calendar--weeks"

              else
                ""
            , if Freshness.busy config.freshness then
                "klar-calendar--refreshing"

              else
                ""
            ]
        , Attr.id s.id
        , Attr.attribute "role" "group"
        , Attr.attribute "aria-label" (Maybe.withDefault ctx.text.calendar config.ariaLabel)
        ]
        [ case s.panel of
            DaysPanel ->
                Html.div [ Internal.cls [ "klar-calendar__body" ] ]
                    [ viewDays ctx
                    , viewTodayButton ctx
                    , if config.fromBackend then
                        viewMarksStatus ctx

                      else
                        Html.text ""
                    ]

            MonthsPanel year ->
                viewMonths ctx year

            YearsPanel start ->
                viewYears ctx start
        , if config.announce then
            Html.div
                [ Internal.cls [ "klar-sr-only" ]
                , Attr.id (s.id ++ "-announce")
                , Attr.attribute "aria-live" "polite"
                , Attr.attribute "aria-atomic" "true"
                ]
                [ Html.text (announcement config.locale ctx.text s) ]

          else
            Html.text ""
        ]


{-| What a screen reader hears when the selection changes: the chosen day, the
first day of a period with the hint to choose the end, or the whole period.
-}
announcement : Locale -> Strings -> Inner -> String
announcement lang text s =
    case s.selection of
        SingleSelection (Just day) ->
            text.selected (dayLabel lang day)

        SingleSelection Nothing ->
            ""

        RangeSelection (RangeChoosing begin) ->
            text.started (dayLabel lang begin)

        RangeSelection (RangeDone from to) ->
            text.period (Format.dateLong lang from) (Format.dateLong lang to)

        RangeSelection RangeNone ->
            ""


{-| The line under the days that says how the marks are doing: loading, failed
(with a retry when trying again could help), or old after a failed refresh.
It is always there, so a screen reader hears each change; it is empty while the
marks are fine.
-}
viewMarksStatus : Ctx msg -> Html msg
viewMarksStatus ctx =
    let
        config =
            ctx.config

        content =
            case config.marks of
                Remote.Failed problem ->
                    [ Html.span [ Internal.cls [ "klar-calendar__status-text" ] ]
                        [ Icon.view Icon.warning
                        , Html.text (Remote.title config.locale problem)
                        ]
                    , case ( config.onRetry, Remote.isRetryable problem ) of
                        ( Just msg, True ) ->
                            Button.view
                                [ Button.small
                                , Button.ghost
                                , Button.icon Icon.refresh
                                , Button.id (ctx.s.id ++ "-retry")
                                , Button.onClick msg
                                ]
                                ctx.text.retry

                        _ ->
                            Html.text ""
                    ]

                _ ->
                    if Freshness.waiting config.marks then
                        [ Html.span [ Internal.cls [ "klar-calendar__status-text" ] ]
                            [ Html.span [ Internal.cls [ "klar-spinner", "klar-spinner--sm" ], Attr.attribute "aria-hidden" "true" ] []
                            , Html.text ctx.text.loading
                            ]
                        ]

                    else
                        [ Freshness.notice
                            { locale = config.locale, settings = config.settings, onRetry = config.onRetry, inline = True }
                            config.freshness
                        ]
    in
    Html.div
        [ Internal.cls [ "klar-calendar__status" ]
        , Attr.id (ctx.s.id ++ "-marks")
        , Attr.attribute "aria-live" "polite"
        ]
        content


{-| An untouched calendar follows `startDay`: the month of `today`, or the nearest
month inside `min` and `max` when today is outside them, or January 2000 when
there is neither.
-}
effective : Config msg -> Inner -> Inner
effective config s =
    if s.positioned then
        s

    else
        let
            edges =
                limits config.min config.max

            day =
                startDay config.today edges.min edges.max
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


outOfBounds : Config msg -> Date -> Bool
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
monthOutOfBounds : Config msg -> Int -> Int -> Bool
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
boolString flag =
    if flag then
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
        (List.map (viewMonth ctx) (List.range 0 (ctx.s.months - 1)))


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
            index == s.months - 1

        titleId =
            s.id ++ "-title-" ++ String.fromInt index

        previousEnabled =
            case config.min of
                Just bound ->
                    let
                        ( py, pm ) =
                            Util.addMonthsTo -1 ( s.year, s.month )
                    in
                    py >= 1 && Util.atOrAfter (Util.dateOf py pm (Date.daysInMonth py pm)) bound

                Nothing ->
                    True

        nextEnabled =
            case config.max of
                Just bound ->
                    let
                        ( ny, nm ) =
                            Util.addMonthsTo s.months ( s.year, s.month )
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

        isRange =
            case ctx.s.selection of
                RangeSelection _ ->
                    True

                SingleSelection _ ->
                    False
    in
    Html.table
        [ Internal.cls [ "klar-calendar__grid" ]
        , Attr.attribute "role" "grid"
        , Attr.attribute "aria-labelledby" titleId
        , Internal.attrIf isRange (Attr.attribute "aria-multiselectable" "true")
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
                        , Attr.attribute "abbr" ctx.text.weekNumber
                        , Attr.title ctx.text.weekNumber
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
        -- The ISO week of a row is the week of its Thursday, whatever day the
        -- weeks of the locale start on.
        ((case ( ctx.config.weekNumbers, List.filter (\day -> Date.weekday day == 4) days ) of
            ( True, thursday :: _ ) ->
                [ Html.th
                    [ Internal.cls [ "klar-calendar__week" ]
                    , Attr.attribute "scope" "row"
                    ]
                    [ Html.text (String.fromInt (Util.isoWeek thursday)) ]
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
    if not inMonth && s.months > 1 then
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

            spoken =
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
                , Attr.attribute "aria-label" spoken
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
                                    [ Internal.cls [ "klar-calendar__dot", "klar-calendar__dot--" ++ Internal.toneSuffix tone ] ]
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
                    year > 1 && Util.atOrAfter (Util.dateOf (year - 1) 12 31) bound

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
                , Internal.attrIf (Maybe.map (\day -> Date.year day == year && Date.month day == m) config.today == Just True) (Attr.attribute "aria-current" "date")
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
    Html.div [ Internal.cls [ "klar-calendar__panel" ], Popup.onKeys [ ( "Escape", ctx.toMsg Back ) ] ]
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
            yearsPerPage

        previousEnabled =
            case config.min of
                Just bound ->
                    start > 1 && Util.atOrAfter (Util.dateOf (start - 1) 12 31) bound

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
                , Internal.attrIf (Maybe.map Date.year config.today == Just y) (Attr.attribute "aria-current" "date")
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
    Html.div [ Internal.cls [ "klar-calendar__panel" ], Popup.onKeys [ ( "Escape", ctx.toMsg Back ) ] ]
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
                [ Html.text (String.fromInt start ++ "\u{00A0}–\u{00A0}" ++ String.fromInt (Basics.min (Date.year highest) (start + pageSize - 1))) ]
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
            (List.map pick (List.range start (Basics.min (Date.year highest) (start + pageSize - 1))))
        ]
