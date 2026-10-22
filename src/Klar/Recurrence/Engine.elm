module Klar.Recurrence.Engine exposing
    ( Window
    , collect
    , lastEpochDay
    , maxResults
    )

{-| The dates of a rule, worked out by periods and not day by day.

A rule is a sequence of periods (every n-th day, week, month or year from the
start), and each period holds at most a few matching dates. `collect` jumps to
the first period that can hold a date on or after `from`, and walks forward
period by period until it has enough dates, the rule ends, or it reaches the
last day the library handles (31 December 9999). A yearly rule over a hundred
years is a hundred steps, not 36 500.

All arithmetic is on day numbers (`Date.toEpochDay`), and only the dates that
are returned are turned back into `Date`s.

Not meant for application code.

-}

import Klar.Calendar.Util as Util
import Klar.Date as Date
import Klar.Recurrence.Spec exposing (End(..), Missing(..), Ordinal(..), Pattern(..), Spec)
import Set


{-| What to collect, as day numbers: the dates are counted from `start`, the
result holds those between `from` and `to` (both inclusive), at most `limit`.
-}
type alias Window =
    { start : Int
    , from : Int
    , to : Int
    , limit : Int
    }


{-| The most dates a public function returns. `collect` itself gathers one more,
so that a caller can tell that the result was cut.
-}
maxResults : Int
maxResults =
    10000


{-| The day number of 31 December 9999, the last day any rule reaches.
-}
lastEpochDay : Int
lastEpochDay =
    epochOf 9999 12 31


{-| The day numbers of the dates of a rule in a window, ascending.

A date counts towards "after n occurrences" when it matches the rule, also
when it is skipped (an exception) or before `from`; skipped dates are left out
of the result.

-}
collect : Window -> Spec -> List Int
collect window spec =
    let
        limit =
            clamp 0 (maxResults + 1) window.limit

        startE =
            window.start

        fromE =
            max window.from startE

        ruleEnd =
            case spec.end of
                Until date ->
                    min lastEpochDay (Date.toEpochDay date)

                _ ->
                    lastEpochDay

        endE =
            min window.to ruleEnd

        maxCount =
            case spec.end of
                After n ->
                    n

                _ ->
                    -1

        skipped =
            Set.fromList (List.map Date.toEpochDay spec.except)

        stepper =
            periods spec startE

        firstPeriod =
            case spec.end of
                -- the count starts at the first date, so every period is visited
                After _ ->
                    0

                _ ->
                    stepper.first fromE

        walk k seen emitted found =
            let
                period =
                    stepper.at k
            in
            if period.begin > endE then
                List.reverse found

            else
                case visit period.dates seen emitted found of
                    Done done ->
                        List.reverse done

                    More seen2 emitted2 found2 ->
                        walk (k + 1) seen2 emitted2 found2

        visit dates seen emitted found =
            case dates of
                [] ->
                    More seen emitted found

                day :: rest ->
                    if day < startE then
                        visit rest seen emitted found

                    else if day > endE || (maxCount >= 0 && seen >= maxCount) then
                        Done found

                    else if day >= fromE && not (Set.member day skipped) then
                        if emitted + 1 >= limit then
                            Done (day :: found)

                        else
                            visit rest (seen + 1) (emitted + 1) (day :: found)

                    else
                        visit rest (seen + 1) emitted found
    in
    if limit == 0 || fromE > endE then
        []

    else
        walk firstPeriod 0 0 []


type Step
    = More Int Int (List Int)
    | Done (List Int)


type alias Period =
    { begin : Int
    , dates : List Int
    }


type alias Periods =
    { first : Int -> Int
    , at : Int -> Period
    }


{-| The periods of a rule: `at k` is the k-th period (from 0) with the day
number of its first day and the dates in it that match, in order, and
`first from` the number of the first period that can hold a date on or after
`from` (a day number not before the start).
-}
periods : Spec -> Int -> Periods
periods spec startE =
    let
        every =
            spec.every

        startDate =
            Date.fromEpochDay startE

        startMonth =
            monthIndex (Date.year startDate) (Date.month startDate)

        startYear =
            Date.year startDate

        weekOfStart =
            weekIndex startE

        monthPeriod k =
            let
                index =
                    startMonth + k * every
            in
            ( floorDiv index 12, modBy 12 index + 1 )
    in
    case spec.pattern of
        Daily ->
            { first = \fromE -> max 0 (ceilDiv (fromE - startE) every)
            , at =
                \k ->
                    let
                        day =
                            startE + k * every
                    in
                    { begin = day, dates = [ day ] }
            }

        Weekly days ->
            { first = \fromE -> max 0 (ceilDiv (weekIndex fromE - weekOfStart) every)
            , at =
                \k ->
                    let
                        monday =
                            (weekOfStart + k * every) * 7 - 3
                    in
                    { begin = monday
                    , dates = List.map (\weekday -> monday + weekday - 1) days
                    }
            }

        MonthlyDay day missing ->
            { first = \fromE -> max 0 (ceilDiv (monthIndexOf fromE - startMonth) every)
            , at =
                \k ->
                    let
                        ( y, m ) =
                            monthPeriod k
                    in
                    { begin = epochOf y m 1
                    , dates = dayOrMissing y m day missing
                    }
            }

        MonthlyWeekday ordinal weekday ->
            { first = \fromE -> max 0 (ceilDiv (monthIndexOf fromE - startMonth) every)
            , at =
                \k ->
                    let
                        ( y, m ) =
                            monthPeriod k
                    in
                    { begin = epochOf y m 1
                    , dates = [ nthWeekday ordinal weekday y m ]
                    }
            }

        YearlyDate month day missing ->
            { first = \fromE -> max 0 (ceilDiv (yearOf fromE - startYear) every)
            , at =
                \k ->
                    let
                        y =
                            startYear + k * every
                    in
                    { begin = epochOf y 1 1
                    , dates = dayOrMissing y month day missing
                    }
            }

        YearlyWeekday ordinal weekday month ->
            { first = \fromE -> max 0 (ceilDiv (yearOf fromE - startYear) every)
            , at =
                \k ->
                    let
                        y =
                            startYear + k * every
                    in
                    { begin = epochOf y 1 1
                    , dates = [ nthWeekday ordinal weekday y month ]
                    }
            }


{-| The date of a day number in a month, or what the rule does when the month
is too short.
-}
dayOrMissing : Int -> Int -> Int -> Missing -> List Int
dayOrMissing y m day missing =
    let
        length =
            Date.daysInMonth y m
    in
    if day <= length then
        [ epochOf y m day ]

    else
        case missing of
            UseLastDay ->
                [ epochOf y m length ]

            Skip ->
                []


{-| The day number of the first, second ... or last weekday (1 = Monday) of a
month.
-}
nthWeekday : Ordinal -> Int -> Int -> Int -> Int
nthWeekday ordinal weekday y m =
    case ordinal of
        Last ->
            let
                lastDay =
                    epochOf y m (Date.daysInMonth y m)
            in
            lastDay - modBy 7 (weekdayOf lastDay - weekday)

        _ ->
            let
                firstDay =
                    epochOf y m 1

                position =
                    case ordinal of
                        First ->
                            0

                        Second ->
                            1

                        Third ->
                            2

                        _ ->
                            3
            in
            firstDay + modBy 7 (weekday - weekdayOf firstDay) + 7 * position



-- DAY NUMBERS


epochOf : Int -> Int -> Int -> Int
epochOf y m d =
    Date.toEpochDay (Util.dateOf y m d)


weekdayOf : Int -> Int
weekdayOf day =
    modBy 7 (day + 3) + 1


{-| The number of the week (Monday to Sunday) a day is in; the weeks are
counted from the Monday before 1 January 1970.
-}
weekIndex : Int -> Int
weekIndex day =
    floorDiv (day + 3) 7


monthIndex : Int -> Int -> Int
monthIndex y m =
    y * 12 + m - 1


monthIndexOf : Int -> Int
monthIndexOf day =
    let
        date =
            Date.fromEpochDay day
    in
    monthIndex (Date.year date) (Date.month date)


yearOf : Int -> Int
yearOf day =
    Date.year (Date.fromEpochDay day)


floorDiv : Int -> Int -> Int
floorDiv a b =
    if a >= 0 then
        a // b

    else
        -((-a + b - 1) // b)


ceilDiv : Int -> Int -> Int
ceilDiv a b =
    -(floorDiv -a b)
