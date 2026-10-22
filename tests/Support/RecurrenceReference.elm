module Support.RecurrenceReference exposing
    ( Ending(..)
    , Kind(..)
    , Params
    , build
    , date
    , dayAfter
    , reference
    , referenceAll
    , scanLimit
    )

{-| The slow, obvious reading of a recurrence rule, for the tests to compare the
real implementation with.

It walks every single day from the start and asks a plain question of each:
"is this day part of the rule?". It uses only `Klar.Date` (year, month, day,
weekday, month lengths) and none of the period arithmetic the real thing is
built on, so a mistake in one is unlikely to be in the other.

-}

import Klar.Date as Date exposing (Date)
import Klar.Recurrence as Recurrence exposing (Rule)
import Time


{-| A rule as plain numbers. Weekdays are 1 (Monday) to 7, ordinals 1 to 4 and
-1 for the last, months 1 to 12.
-}
type alias Params =
    { every : Int
    , kind : Kind
    , ending : Ending
    , skipped : List Int
    }


type Kind
    = KDaily
    | KWeekly (List Int)
    | KMonthDay Int Bool
    | KMonthNth Int Int
    | KYearDate Int Int Bool
    | KYearNth Int Int Int


{-| The end; `EndOn` counts days after the start. `skipped` in `Params` are days
after the start too.
-}
type Ending
    = EndNever
    | EndAfter Int
    | EndOn Int


date : Int -> Int -> Int -> Date
date year month day =
    Date.fromParts year month day |> Maybe.withDefault (Date.fromEpochDay 0)


dayAfter : Int -> Date -> Date
dayAfter =
    Date.addDays



-- BUILDING THE REAL RULE


build : Date -> Params -> Result Recurrence.Problem Rule
build start params =
    Recurrence.rule (patternOf params.kind)
        [ Recurrence.every params.every
        , Recurrence.ends
            (case params.ending of
                EndNever ->
                    Recurrence.never

                EndAfter n ->
                    Recurrence.after n

                EndOn offset ->
                    Recurrence.until (Date.addDays offset start)
            )
        , Recurrence.except (List.map (\offset -> Date.addDays offset start) params.skipped)
        ]


patternOf : Kind -> Recurrence.Pattern
patternOf kind =
    case kind of
        KDaily ->
            Recurrence.daily

        KWeekly days ->
            case List.map weekday days of
                firstDay :: rest ->
                    Recurrence.weekly firstDay rest

                [] ->
                    Recurrence.weekly Time.Mon []

        KMonthDay day skip ->
            skipIf skip (Recurrence.monthlyOnDay day)

        KMonthNth ordinal day ->
            Recurrence.monthlyOnWeekday (ordinalOf ordinal) (weekday day)

        KYearDate month day skip ->
            skipIf skip (Recurrence.yearlyOnDate (month_ month) day)

        KYearNth ordinal day month ->
            Recurrence.yearlyOnWeekday (ordinalOf ordinal) (weekday day) (month_ month)


skipIf : Bool -> Recurrence.Pattern -> Recurrence.Pattern
skipIf skip pattern =
    if skip then
        Recurrence.skippingMissingDays pattern

    else
        pattern


ordinalOf : Int -> Recurrence.Ordinal
ordinalOf n =
    case n of
        1 ->
            Recurrence.first

        2 ->
            Recurrence.second

        3 ->
            Recurrence.third

        4 ->
            Recurrence.fourth

        _ ->
            Recurrence.last


weekday : Int -> Time.Weekday
weekday n =
    case n of
        1 ->
            Time.Mon

        2 ->
            Time.Tue

        3 ->
            Time.Wed

        4 ->
            Time.Thu

        5 ->
            Time.Fri

        6 ->
            Time.Sat

        _ ->
            Time.Sun


month_ : Int -> Time.Month
month_ n =
    case n of
        1 ->
            Time.Jan

        2 ->
            Time.Feb

        3 ->
            Time.Mar

        4 ->
            Time.Apr

        5 ->
            Time.May

        6 ->
            Time.Jun

        7 ->
            Time.Jul

        8 ->
            Time.Aug

        9 ->
            Time.Sep

        10 ->
            Time.Oct

        11 ->
            Time.Nov

        _ ->
            Time.Dec



-- THE REFERENCE


{-| How many days after the start the reference looks.
-}
scanLimit : Int
scanLimit =
    6000


{-| Every occurrence of the rule from `start` to the last day given, skipped
dates left out, found by testing each day.
-}
reference : Date -> Params -> Date -> List Date
reference start params lastDay =
    referenceAll start params lastDay
        |> List.filter (\day -> not (List.member day (skippedDates start params)))


{-| The same before the skipped dates are taken away: the series that the
count of "after n" runs over.
-}
referenceAll : Date -> Params -> Date -> List Date
referenceAll start params lastDay =
    let
        days =
            List.range 0 (Date.diffDays start lastDay)
                |> List.map (\offset -> Date.addDays offset start)
                |> List.filter (matches start params)
    in
    case params.ending of
        EndNever ->
            days

        EndAfter n ->
            List.take n days

        EndOn offset ->
            List.filter (\day -> Date.compare day (Date.addDays offset start) /= GT) days


skippedDates : Date -> Params -> List Date
skippedDates start params =
    List.map (\offset -> Date.addDays offset start) params.skipped


matches : Date -> Params -> Date -> Bool
matches start params day =
    case params.kind of
        KDaily ->
            modBy params.every (Date.diffDays start day) == 0

        KWeekly days ->
            List.member (Date.weekday day) days
                && modBy params.every (weeksBetween start day)
                == 0

        KMonthDay wanted skip ->
            modBy params.every (monthsBetween start day)
                == 0
                && dayHit (Date.year day) (Date.month day) wanted skip day

        KMonthNth ordinal wanted ->
            modBy params.every (monthsBetween start day)
                == 0
                && isNth ordinal wanted day

        KYearDate month wanted skip ->
            modBy params.every (Date.year day - Date.year start)
                == 0
                && Date.month day
                == month
                && dayHit (Date.year day) month wanted skip day

        KYearNth ordinal wanted month ->
            modBy params.every (Date.year day - Date.year start)
                == 0
                && Date.month day
                == month
                && isNth ordinal wanted day


{-| The day is the wanted day of the month; in a month that is too short, the
last day, unless the rule skips such months.
-}
dayHit : Int -> Int -> Int -> Bool -> Date -> Bool
dayHit year month wanted skip day =
    let
        length =
            Date.daysInMonth year month
    in
    if wanted <= length then
        Date.day day == wanted

    else
        not skip && Date.day day == length


isNth : Int -> Int -> Date -> Bool
isNth ordinal wanted day =
    Date.weekday day
        == wanted
        && (if ordinal == -1 then
                Date.day day + 7 > Date.daysInMonth (Date.year day) (Date.month day)

            else
                (Date.day day - 1) // 7 + 1 == ordinal
           )


mondayOf : Date -> Date
mondayOf day =
    Date.addDays (1 - Date.weekday day) day


weeksBetween : Date -> Date -> Int
weeksBetween a b =
    Date.diffDays (mondayOf a) (mondayOf b) // 7


monthsBetween : Date -> Date -> Int
monthsBetween a b =
    (Date.year b - Date.year a) * 12 + Date.month b - Date.month a
