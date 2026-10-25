module DateTest exposing (suite)

import Expect
import Fuzz
import Klar.Date as Date exposing (Date)
import Test exposing (Test, describe, fuzz, fuzz2, test)
import Time


date : Int -> Int -> Int -> Date
date year month day =
    Date.fromParts year month day |> Maybe.withDefault (Date.fromEpochDay 0)


iso : Maybe Date -> String
iso maybeDate =
    case maybeDate of
        Just value ->
            "Just " ++ Date.toIso value

        Nothing ->
            "Nothing"


suite : Test
suite =
    describe "Klar.Date"
        [ dayNumbers
        , weekdays
        , arithmetic
        , parsing
        , calendar
        , range
        , periods
        , posix
        ]


dayNumbers : Test
dayNumbers =
    describe "day numbers"
        [ test "1970-01-01 is day 0" <|
            \_ -> Expect.equal 0 (Date.toEpochDay (date 1970 1 1))
        , test "day 0 is 1970-01-01" <|
            \_ -> Expect.equal (date 1970 1 1) (Date.fromEpochDay 0)
        , test "the day before the epoch" <|
            \_ -> Expect.equal "1969-12-31" (Date.toIso (Date.fromEpochDay -1))
        , test "year 1" <|
            \_ -> Expect.equal -719162 (Date.toEpochDay (date 1 1 1))
        , fuzz (Fuzz.intRange -719162 2932896) "a day number survives the round trip" <|
            \n -> Expect.equal n (Date.toEpochDay (Date.fromEpochDay n))
        , fuzz (Fuzz.intRange -3000000 6000000) "every day number gives a valid date" <|
            \n -> Expect.equal True (isValid (Date.fromEpochDay n))
        , fuzz (Fuzz.intRange -719162 2932895) "consecutive days are consecutive dates" <|
            \n -> Expect.equal 1 (Date.diffDays (Date.fromEpochDay n) (Date.fromEpochDay (n + 1)))
        ]


weekdays : Test
weekdays =
    describe "weekday"
        [ test "20 October 2026 is a Tuesday" <|
            \_ -> Expect.equal 2 (Date.weekday (date 2026 10 20))
        , test "1 January 2000 was a Saturday" <|
            \_ -> Expect.equal 6 (Date.weekday (date 2000 1 1))
        , test "1 January 1970 was a Thursday" <|
            \_ -> Expect.equal 4 (Date.weekday (date 1970 1 1))
        , test "a Sunday is 7" <|
            \_ -> Expect.equal 7 (Date.weekday (date 2026 10 25))
        , fuzz (Fuzz.intRange -719162 2932889) "the week repeats" <|
            \n -> Expect.equal (Date.weekday (Date.fromEpochDay n)) (Date.weekday (Date.fromEpochDay (n + 7)))
        ]


arithmetic : Test
arithmetic =
    describe "arithmetic"
        [ test "30 days ahead" <|
            \_ -> Expect.equal "2026-11-19" (Date.toIso (Date.addDays 30 (date 2026 10 20)))
        , test "backwards over a new year" <|
            \_ -> Expect.equal "2025-12-31" (Date.toIso (Date.addDays -1 (date 2026 1 1)))
        , test "31 January plus a month is 28 February" <|
            \_ -> Expect.equal "2026-02-28" (Date.toIso (Date.addMonths 1 (date 2026 1 31)))
        , test "in a leap year it is 29 February" <|
            \_ -> Expect.equal "2024-02-29" (Date.toIso (Date.addMonths 1 (date 2024 1 31)))
        , test "months over a new year" <|
            \_ -> Expect.equal "2027-02-15" (Date.toIso (Date.addMonths 4 (date 2026 10 15)))
        , test "negative months" <|
            \_ -> Expect.equal "2025-12-15" (Date.toIso (Date.addMonths -10 (date 2026 10 15)))
        , test "twelve months is a year" <|
            \_ -> Expect.equal "2027-03-31" (Date.toIso (Date.addMonths 12 (date 2026 3 31)))
        , test "days between two dates" <|
            \_ -> Expect.equal 365 (Date.diffDays (date 2026 1 1) (date 2027 1 1))
        , test "days between, backwards" <|
            \_ -> Expect.equal -365 (Date.diffDays (date 2027 1 1) (date 2026 1 1))
        , test "a leap year has 29 days in February" <|
            \_ -> Expect.equal 29 (Date.daysInMonth 2024 2)
        , test "1900 is not a leap year" <|
            \_ -> Expect.equal False (Date.isLeapYear 1900)
        , test "2000 is a leap year" <|
            \_ -> Expect.equal True (Date.isLeapYear 2000)
        , test "the end of a month" <|
            \_ -> Expect.equal "2024-02-29" (Date.toIso (Date.endOfMonth (date 2024 2 10)))
        , test "the start of a month" <|
            \_ -> Expect.equal "2024-02-01" (Date.toIso (Date.startOfMonth (date 2024 2 10)))
        , test "comparing" <|
            \_ -> Expect.equal [ LT, EQ, GT ] [ Date.compare (date 2026 1 1) (date 2026 1 2), Date.compare (date 2026 1 1) (date 2026 1 1), Date.compare (date 2027 1 1) (date 2026 12 31) ]
        , fuzz2 (Fuzz.intRange -715000 2928000) (Fuzz.intRange -4000 4000) "addDays and diffDays agree" <|
            \n k ->
                let
                    start =
                        Date.fromEpochDay n
                in
                Expect.equal k (Date.diffDays start (Date.addDays k start))
        , fuzz2 (Fuzz.intRange 0 800000) (Fuzz.intRange -1000 1000) "addMonths always gives a valid date" <|
            \n k -> Expect.equal True (isValid (Date.addMonths k (Date.fromEpochDay n)))
        ]


parsing : Test
parsing =
    describe "ISO dates"
        [ test "a valid date" <|
            \_ -> Expect.equal "Just 2026-02-28" (iso (Date.fromIso "2026-02-28"))
        , test "surrounding spaces are ignored" <|
            \_ -> Expect.equal "Just 2026-02-28" (iso (Date.fromIso "  2026-02-28 "))
        , test "30 February does not exist" <|
            \_ -> Expect.equal "Nothing" (iso (Date.fromIso "2026-02-30"))
        , test "29 February in a leap year does" <|
            \_ -> Expect.equal "Just 2024-02-29" (iso (Date.fromIso "2024-02-29"))
        , test "month 13 does not exist" <|
            \_ -> Expect.equal "Nothing" (iso (Date.fromIso "2026-13-01"))
        , test "day 0 does not exist" <|
            \_ -> Expect.equal "Nothing" (iso (Date.fromIso "2026-01-00"))
        , test "two digits are required" <|
            \_ -> Expect.equal "Nothing" (iso (Date.fromIso "2026-2-3"))
        , test "four digits are required for the year" <|
            \_ -> Expect.equal "Nothing" (iso (Date.fromIso "26-02-03"))
        , test "a sign is not a digit" <|
            \_ -> Expect.equal "Nothing" (iso (Date.fromIso "2026-+1-01"))
        , test "a sign in the year" <|
            \_ -> Expect.equal "Nothing" (iso (Date.fromIso "+202-01-01"))
        , test "year 0 does not exist" <|
            \_ -> Expect.equal "Nothing" (iso (Date.fromIso "0000-01-01"))
        , test "other separators" <|
            \_ -> Expect.equal "Nothing" (iso (Date.fromIso "2026/02/28"))
        , test "empty text" <|
            \_ -> Expect.equal "Nothing" (iso (Date.fromIso ""))
        , test "writing pads the year" <|
            \_ -> Expect.equal "0042-03-05" (Date.toIso (date 42 3 5))
        , fuzz (Fuzz.intRange -3000000 6000000) "writing and reading agree for every date" <|
            \n ->
                let
                    d =
                        Date.fromEpochDay n
                in
                Expect.equal (Just d) (Date.fromIso (Date.toIso d))
        , fuzz2 (Fuzz.intRange -719162 2932896) (Fuzz.intRange -200000 200000) "addMonths always gives a date that toIso can write" <|
            \n k ->
                let
                    d =
                        Date.addMonths k (Date.fromEpochDay n)
                in
                Expect.equal (Just d) (Date.fromIso (Date.toIso d))
        , test "fromParts rejects what does not exist" <|
            \_ -> Expect.equal [ Nothing, Nothing, Just (date 2024 2 29) ] [ Date.fromParts 2026 2 29, Date.fromParts 2026 0 1, Date.fromParts 2024 2 29 ]
        ]


calendar : Test
calendar =
    let
        grid firstDay year month =
            Date.monthGrid firstDay year month
    in
    describe "month grid"
        [ test "always six weeks of seven days" <|
            \_ ->
                Expect.equal ( 6, [ 7, 7, 7, 7, 7, 7 ] )
                    ( List.length (grid 1 2026 2), List.map List.length (grid 1 2026 2) )
        , test "October 2026 starts on Monday 28 September" <|
            \_ ->
                Expect.equal "2026-09-28"
                    (grid 1 2026 10 |> List.head |> Maybe.andThen List.head |> Maybe.map Date.toIso |> Maybe.withDefault "")
        , test "weeks that start on Sunday" <|
            \_ ->
                Expect.equal "2026-09-27"
                    (grid 7 2026 10 |> List.head |> Maybe.andThen List.head |> Maybe.map Date.toIso |> Maybe.withDefault "")
        , test "a month that starts on the first weekday has no padding before it" <|
            \_ ->
                Expect.equal "2026-06-01"
                    (grid 1 2026 6 |> List.head |> Maybe.andThen List.head |> Maybe.map Date.toIso |> Maybe.withDefault "")
        , fuzz (Fuzz.intRange 1 7) "the days are consecutive and the first column is the first weekday" <|
            \firstDay ->
                let
                    days =
                        List.concat (grid firstDay 2026 10)

                    consecutive =
                        List.map2 (\a b -> Date.diffDays a b) days (List.drop 1 days)
                in
                Expect.equal ( True, firstDay ) ( List.all ((==) 1) consecutive, days |> List.head |> Maybe.map Date.weekday |> Maybe.withDefault 0 )
        , test "the month is inside the grid" <|
            \_ ->
                let
                    days =
                        List.concat (grid 1 2024 2)
                in
                Expect.equal 29 (List.length (List.filter (\d -> Date.month d == 2) days))
        ]


range : Test
range =
    describe "the supported range, years 1 to 9999"
        [ test "fromParts gives Nothing before year 1, and keeps a later year for day counting" <|
            \_ ->
                Expect.equal [ Nothing, Just "0001-01-01", Just "9999-12-31" ]
                    (List.map (Maybe.map Date.toIso) [ Date.fromParts 0 12 31, Date.fromParts 1 1 1, Date.fromParts 9999 12 31 ])
        , test "a day after the range still counts past its last day (the Recurrence engine stops on it)" <|
            \_ ->
                Expect.equal (Just True)
                    (Date.fromParts 10000 1 1 |> Maybe.map (\d -> Date.toEpochDay d > Date.toEpochDay (date 9999 12 31)))
        , test "addDays stops at the first and the last day" <|
            \_ ->
                Expect.equal [ "0001-01-01", "9999-12-31" ]
                    [ Date.toIso (Date.addDays -1 (date 1 1 1)), Date.toIso (Date.addDays 1 (date 9999 12 31)) ]
        , test "addMonths stops at January of year 1 and December 9999, keeping the day" <|
            \_ ->
                Expect.equal [ "0001-01-20", "9999-12-20", "0001-01-15" ]
                    [ Date.toIso (Date.addMonths -30000 (date 2026 10 20))
                    , Date.toIso (Date.addMonths 100000 (date 2026 10 20))
                    , Date.toIso (Date.addMonths -1 (date 1 1 15))
                    ]
        , test "fromEpochDay stops at the edges" <|
            \_ ->
                Expect.equal [ "0001-01-01", "9999-12-31" ]
                    [ Date.toIso (Date.fromEpochDay -800000), Date.toIso (Date.fromEpochDay 3000000) ]
        , test "a moment outside the range gives the first or the last day" <|
            \_ ->
                Expect.equal [ "0001-01-01", "9999-12-31" ]
                    [ Date.toIso (Date.fromPosix Time.utc (Time.millisToPosix -70000000000000))
                    , Date.toIso (Date.fromPosix Time.utc (Time.millisToPosix 300000000000000))
                    ]
        , test "monthGrid moves a month outside 1 to 12 inside, so every day is a real date" <|
            \_ ->
                Expect.equal True (List.all isValid (List.concat (Date.monthGrid 1 2026 13)))
        , test "1 January of year 1 is a Monday, so the first grid has no padding before it" <|
            \_ ->
                Expect.equal "0001-01-01"
                    (Date.monthGrid 1 1 1 |> List.head |> Maybe.andThen List.head |> Maybe.map Date.toIso |> Maybe.withDefault "")
        ]


periods : Test
periods =
    describe "weeks, quarters and years"
        [ test "startOfWeek and endOfWeek for weeks that start on Monday" <|
            \_ ->
                Expect.equal [ "2026-11-02", "2026-11-08", "2026-11-02", "2026-11-08" ]
                    [ Date.toIso (Date.startOfWeek 1 (date 2026 11 4))
                    , Date.toIso (Date.endOfWeek 1 (date 2026 11 4))
                    , Date.toIso (Date.startOfWeek 1 (date 2026 11 2))
                    , Date.toIso (Date.endOfWeek 1 (date 2026 11 8))
                    ]
        , test "weeks that start on Sunday" <|
            \_ ->
                Expect.equal [ "2026-11-01", "2026-11-07" ]
                    [ Date.toIso (Date.startOfWeek 7 (date 2026 11 4)), Date.toIso (Date.endOfWeek 7 (date 2026 11 4)) ]
        , fuzz2 (Fuzz.intRange -700000 2900000) (Fuzz.intRange 1 7) "a week holds the date, starts on its first day and has seven days" <|
            \n firstDay ->
                let
                    d =
                        Date.fromEpochDay n

                    start =
                        Date.startOfWeek firstDay d
                in
                Expect.equal ( firstDay, True, 6 )
                    ( Date.weekday start, Date.diffDays start d >= 0 && Date.diffDays start d <= 6, Date.diffDays start (Date.endOfWeek firstDay d) )
        , test "ISO weeks around new year" <|
            \_ ->
                Expect.equal [ ( 1, 2026 ), ( 53, 2026 ), ( 53, 2026 ), ( 1, 2025 ), ( 1, 2026 ), ( 43, 2026 ) ]
                    (List.map (\d -> ( Date.isoWeek d, Date.isoWeekYear d ))
                        [ date 2026 1 1, date 2026 12 31, date 2027 1 3, date 2024 12 30, date 2025 12 29, date 2026 10 20 ]
                    )
        , test "quarters" <|
            \_ ->
                Expect.equal [ 1, 1, 2, 3, 4 ]
                    (List.map Date.quarter [ date 2026 1 1, date 2026 3 31, date 2026 4 1, date 2026 9 30, date 2026 12 31 ])
        , test "startOfQuarter and endOfQuarter" <|
            \_ ->
                Expect.equal [ "2026-10-01", "2026-12-31", "2024-01-01", "2024-03-31", "2026-04-01", "2026-06-30" ]
                    [ Date.toIso (Date.startOfQuarter (date 2026 11 4))
                    , Date.toIso (Date.endOfQuarter (date 2026 11 4))
                    , Date.toIso (Date.startOfQuarter (date 2024 2 29))
                    , Date.toIso (Date.endOfQuarter (date 2024 2 29))
                    , Date.toIso (Date.startOfQuarter (date 2026 5 31))
                    , Date.toIso (Date.endOfQuarter (date 2026 5 31))
                    ]
        , test "startOfYear, endOfYear and addYears" <|
            \_ ->
                Expect.equal [ "2026-01-01", "2026-12-31", "2025-02-28", "2028-02-29", "2016-10-20" ]
                    [ Date.toIso (Date.startOfYear (date 2026 11 4))
                    , Date.toIso (Date.endOfYear (date 2026 11 4))
                    , Date.toIso (Date.addYears 1 (date 2024 2 29))
                    , Date.toIso (Date.addYears 4 (date 2024 2 29))
                    , Date.toIso (Date.addYears -10 (date 2026 10 20))
                    ]
        ]


posix : Test
posix =
    describe "from a Posix time"
        [ test "the epoch" <|
            \_ -> Expect.equal (date 1970 1 1) (Date.fromPosix Time.utc (Time.millisToPosix 0))
        , test "a late evening is still the same day in UTC" <|
            \_ -> Expect.equal (date 1970 1 1) (Date.fromPosix Time.utc (Time.millisToPosix (23 * 3600 * 1000)))
        , test "the time zone moves the date" <|
            \_ ->
                Expect.equal (date 1970 1 2)
                    (Date.fromPosix (Time.customZone 120 []) (Time.millisToPosix (23 * 3600 * 1000)))
        , test "toPosix is midnight UTC" <|
            \_ -> Expect.equal 86400000 (Time.posixToMillis (Date.toPosix Time.utc (date 1970 1 2)))
        , test "toPosix is the start of the day in the zone" <|
            \_ ->
                -- two hours ahead of UTC: the day starts at 22:00 the evening before
                Expect.equal (86400000 - 2 * 3600 * 1000) (Time.posixToMillis (Date.toPosix (Time.customZone 120 []) (date 1970 1 2)))
        , test "toPosix is the start of the day west of UTC" <|
            \_ -> Expect.equal (5 * 3600 * 1000) (Time.posixToMillis (Date.toPosix (Time.customZone -300 []) (date 1970 1 1)))
        , test "toPosix and fromPosix are inverses" <|
            \_ ->
                let
                    zone =
                        Time.customZone 90 []
                in
                Expect.equal (date 2026 10 22) (Date.fromPosix zone (Date.toPosix zone (date 2026 10 22)))
        ]


{-| Every `Date` is a day that exists; reading the parts back must give the same date.
-}
isValid : Date -> Bool
isValid d =
    Date.fromParts (Date.year d) (Date.month d) (Date.day d) == Just d
