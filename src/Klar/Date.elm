module Klar.Date exposing
    ( Date, fromParts, year, month, day
    , fromIso, toIso, fromPosix, toPosix
    , compare, diffDays, weekday, isLeapYear, daysInMonth
    , addDays, addMonths, startOfMonth, endOfMonth
    , addYears, startOfWeek, endOfWeek, isoWeek, isoWeekYear
    , quarter, startOfQuarter, endOfQuarter, startOfYear, endOfYear
    , monthGrid
    , toEpochDay, fromEpochDay
    )

{-| Calendar dates without a time or a time zone: a year, a month and a day.

Use when: the application holds a due date, a delivery date or a birthday, a day that is not a moment in time.
Do not use when: you mean an exact moment (use `Time.Posix` from `elm/time`).

A due date or a delivery date is not a moment in time, and treating it as
`Time.Posix` makes it shift by a day in the wrong time zone. A `Date` is always
a day that exists (there is no way to make 31 February): make one with
`fromParts` or `fromIso`, compare with `Date.compare`, store as text with `toIso`
and read the parts with `year`, `month` and `day`.

    import Klar.Date as Date

    Date.fromIso "2026-10-20" -- Date.fromParts 2026 10 20

    Date.fromParts 2026 10 20 |> Maybe.map (Date.addDays 30 >> Date.toIso) -- Just "2026-11-19"

    Date.fromParts 2026 10 20 |> Maybe.map Date.weekday -- Just 2, a Tuesday

All calculations are pure arithmetic on the proleptic Gregorian calendar and
are exact. A `Date` is a day in year 1 or later: arithmetic that would go
before it (`addDays`, `addMonths`, `fromEpochDay`) stops at 1 January of year 1,
and it never stops at the other end, so a later date always counts on and two
dates are as many days apart as their day numbers differ. `toIso` and `fromIso`
cover the four-digit years 1 to 9999; `toIso` writes a later year with all its
digits, which `fromIso` does not read. A `Time.Posix` is
only needed once, to get today's date with `fromPosix`.

Store and send a date as the text of `toIso`, never as the moment of its
midnight: a moment shifts the day when it is read in another time zone.

The date components of the library (`Klar.DatePicker`, `Klar.Calendar` ...)
use this type, and so does `Klar.Format` when it writes dates.


# The type

@docs Date, fromParts, year, month, day


# Reading and writing text

@docs fromIso, toIso, fromPosix, toPosix


# Comparing and counting

@docs compare, diffDays, weekday, isLeapYear, daysInMonth


# Moving around

@docs addDays, addMonths, startOfMonth, endOfMonth


# Weeks, quarters and years

For reports and quick choices such as "This week" or "Last quarter".

    Date.fromIso "2026-11-04" |> Maybe.map (Date.startOfQuarter >> Date.toIso) -- Just "2026-10-01"

    Date.fromIso "2027-01-01" |> Maybe.map Date.isoWeek -- Just 53, a week of 2026

@docs addYears, startOfWeek, endOfWeek, isoWeek, isoWeekYear
@docs quarter, startOfQuarter, endOfQuarter, startOfYear, endOfYear


# Calendars

@docs monthGrid


# Day numbers

@docs toEpochDay, fromEpochDay

-}

import Time


{-| A calendar date: a day that exists, in year 1 or later. The type is opaque,
so a date can never be 31 February or
month 13. Make one with
`fromParts` or `fromIso`, and read it with `year`, `month` and `day`.
-}
type Date
    = Date Parts


type alias Parts =
    { year : Int
    , month : Int
    , day : Int
    }


{-| Whether a year is a leap year in the Gregorian calendar: divisible by 4,
except centuries, except centuries divisible by 400.

    Date.isLeapYear 2024 -- True

    Date.isLeapYear 1900 -- False

    Date.isLeapYear 2000 -- True

-}
isLeapYear : Int -> Bool
isLeapYear y =
    (modBy 4 y == 0 && modBy 100 y /= 0) || modBy 400 y == 0


{-| The number of days in a month of a year (28 to 31). A month outside 1 to 12
counts as 31.

    Date.daysInMonth 2024 2 -- 29

    Date.daysInMonth 2026 4 -- 30

-}
daysInMonth : Int -> Int -> Int
daysInMonth y m =
    case m of
        2 ->
            if isLeapYear y then
                29

            else
                28

        4 ->
            30

        6 ->
            30

        9 ->
            30

        11 ->
            30

        _ ->
            31


{-| Builds a date from a year (1 or later), a month (1 to 12) and a day, or
`Nothing` if that day does not exist (like 31 February, or a year before 1). A
year after 9999 is accepted, for code that counts day numbers past the end of
the range, but `toIso` writes it with five digits, which `fromIso` does not read.

    Date.fromParts 2026 2 30 -- Nothing

    Date.fromParts 2024 2 29 -- Just a date

-}
fromParts : Int -> Int -> Int -> Maybe Date
fromParts y m d =
    if y >= 1 && m >= 1 && m <= 12 && d >= 1 && d <= daysInMonth y m then
        Just (Date { year = y, month = m, day = d })

    else
        Nothing


{-| The year of a date, 1 or later.

    Date.fromIso "2026-10-20" |> Maybe.map Date.year -- Just 2026

-}
year : Date -> Int
year (Date parts) =
    parts.year


{-| The month of a date, 1 (January) to 12 (December).
-}
month : Date -> Int
month (Date parts) =
    parts.month


{-| The day of the month of a date, from 1.
-}
day : Date -> Int
day (Date parts) =
    parts.day


{-| Reads `YYYY-MM-DD`: exactly four digits, a dash, two digits, a dash, two
digits. Surrounding spaces are ignored. A date that does not exist is
`Nothing`, and so is anything with a sign, a space or other characters inside.

    Date.fromIso "2026-02-28" -- Date.fromParts 2026 2 28

    Date.fromIso "2026-02-30" -- Nothing

    Date.fromIso "2026-2-3" -- Nothing

-}
fromIso : String -> Maybe Date
fromIso text =
    case String.split "-" (String.trim text) of
        [ y, m, d ] ->
            if isDigits 4 y && isDigits 2 m && isDigits 2 d then
                Maybe.map3 fromParts (String.toInt y) (String.toInt m) (String.toInt d)
                    |> Maybe.andThen identity

            else
                Nothing

        _ ->
            Nothing


isDigits : Int -> String -> Bool
isDigits count text =
    String.length text == count && String.all Char.isDigit text


{-| Writes `YYYY-MM-DD`, with the year padded to four digits, so that `fromIso`
reads back every date up to 31 December 9999. A later year is written with all
its digits (`10000-01-01`), which `fromIso` does not read.

    Date.fromParts 2026 3 5 |> Maybe.map Date.toIso -- Just "2026-03-05"

-}
toIso : Date -> String
toIso (Date date) =
    String.padLeft 4 '0' (String.fromInt date.year)
        ++ "-"
        ++ String.padLeft 2 '0' (String.fromInt date.month)
        ++ "-"
        ++ String.padLeft 2 '0' (String.fromInt date.day)


{-| Which of two dates is earlier. Use it with `List.sortWith`.

    List.sortWith Date.compare dates

-}
compare : Date -> Date -> Order
compare (Date a) (Date b) =
    Basics.compare ( a.year, a.month, a.day ) ( b.year, b.month, b.day )


floorDiv : Int -> Int -> Int
floorDiv a b =
    if a >= 0 then
        a // b

    else
        -((-a + b - 1) // b)


{-| The number of days since 1970-01-01, which is day 0. Earlier dates give
negative numbers. Two dates are the same number of days apart as their day
numbers differ, which is how `addDays` and `diffDays` work.

    Date.fromParts 1970 1 2 |> Maybe.map Date.toEpochDay -- Just 1

-}
toEpochDay : Date -> Int
toEpochDay (Date date) =
    let
        y =
            if date.month <= 2 then
                date.year - 1

            else
                date.year

        era =
            floorDiv y 400

        yoe =
            y - era * 400

        monthShift =
            if date.month > 2 then
                date.month - 3

            else
                date.month + 9

        doy =
            (153 * monthShift + 2) // 5 + date.day - 1

        doe =
            yoe * 365 + yoe // 4 - yoe // 100 + doy
    in
    era * 146097 + doe - 719468


{-| The date of a day number: the inverse of `toEpochDay`. A number before
1 January of year 1 (-719162) gives that day.

    Date.fromEpochDay 0 -- 1 January 1970

-}
fromEpochDay : Int -> Date
fromEpochDay days =
    let
        z =
            max firstEpochDay days + 719468

        era =
            floorDiv z 146097

        doe =
            z - era * 146097

        yoe =
            (doe - doe // 1460 + doe // 36524 - doe // 146096) // 365

        y =
            yoe + era * 400

        doy =
            doe - (365 * yoe + yoe // 4 - yoe // 100)

        mp =
            (5 * doy + 2) // 153

        d =
            doy - (153 * mp + 2) // 5 + 1

        m =
            if mp < 10 then
                mp + 3

            else
                mp - 9
    in
    Date
        { year =
            if m <= 2 then
                y + 1

            else
                y
        , month = m
        , day = d
        }


{-| Moves a date by a number of days, forwards or backwards, across months and
years. It stops at 1 January of year 1.

    Date.fromIso "2026-01-01" |> Maybe.map (Date.addDays -1 >> Date.toIso) -- Just "2025-12-31"

-}
addDays : Int -> Date -> Date
addDays n date =
    fromEpochDay (toEpochDay date + n)


{-| Adds months, clamping the day to the end of the target month: 31 January
plus one month is 28 February (29 in a leap year). It stops at January of year 1.

    Date.fromIso "2026-01-31" |> Maybe.map (Date.addMonths 1 >> Date.toIso) -- Just "2026-02-28"

    Date.fromIso "2026-10-15" |> Maybe.map (Date.addMonths -10 >> Date.toIso) -- Just "2025-12-15"

-}
addMonths : Int -> Date -> Date
addMonths n (Date date) =
    let
        total =
            max 12 (date.year * 12 + (date.month - 1) + n)

        newYear =
            floorDiv total 12

        newMonth =
            modBy 12 total + 1
    in
    Date
        { year = newYear
        , month = newMonth
        , day = min date.day (daysInMonth newYear newMonth)
        }


{-| Adds years, keeping the month and the day; 29 February becomes 28 February
in a year that is not a leap year. It stops at year 1.

    Date.fromIso "2024-02-29" |> Maybe.map (Date.addYears 1 >> Date.toIso) -- Just "2025-02-28"

-}
addYears : Int -> Date -> Date
addYears n date =
    addMonths (12 * n) date


{-| The first day of the week that holds the date, for weeks that start on
`firstDay` (1 = Monday ... 7 = Sunday; `Locale.firstDayOfWeek` gives the one of
a locale).

    Date.fromIso "2026-11-04" |> Maybe.map (Date.startOfWeek 1 >> Date.toIso) -- Just "2026-11-02", a Monday

-}
startOfWeek : Int -> Date -> Date
startOfWeek firstDay date =
    addDays (negate (modBy 7 (weekday date - firstDay))) date


{-| The last day of the week that holds the date, for weeks that start on
`firstDay` (1 = Monday ... 7 = Sunday): six days after `startOfWeek`.
-}
endOfWeek : Int -> Date -> Date
endOfWeek firstDay date =
    addDays 6 (startOfWeek firstDay date)


{-| The week number of ISO 8601, 1 to 53: weeks start on Monday, and week 1 is
the week that holds the first Thursday of the year. The first days of January
can belong to the last week of the year before, and the last days of December to
week 1 of the next; `isoWeekYear` gives the year a week belongs to.

    Date.fromIso "2026-12-31" |> Maybe.map Date.isoWeek -- Just 53

-}
isoWeek : Date -> Int
isoWeek date =
    let
        thursday =
            addDays (4 - weekday date) date
    in
    diffDays (startOfYear thursday) thursday // 7 + 1


{-| The year that the ISO 8601 week of the date belongs to, for labels such as
"2026-W53": the year of its Thursday.

    Date.fromIso "2027-01-01" |> Maybe.map Date.isoWeekYear -- Just 2026

-}
isoWeekYear : Date -> Int
isoWeekYear date =
    year (addDays (4 - weekday date) date)


{-| The quarter of the year that holds the date: 1 (January to March) to 4
(October to December).
-}
quarter : Date -> Int
quarter (Date date) =
    (date.month - 1) // 3 + 1


{-| The first day of the date's quarter: 1 January, 1 April, 1 July or
1 October.
-}
startOfQuarter : Date -> Date
startOfQuarter ((Date date) as whole) =
    Date { year = date.year, month = (quarter whole - 1) * 3 + 1, day = 1 }


{-| The last day of the date's quarter: 31 March, 30 June, 30 September or
31 December.
-}
endOfQuarter : Date -> Date
endOfQuarter date =
    endOfMonth (addMonths 2 (startOfQuarter date))


{-| 1 January of the date's year.
-}
startOfYear : Date -> Date
startOfYear (Date date) =
    Date { year = date.year, month = 1, day = 1 }


{-| 31 December of the date's year.
-}
endOfYear : Date -> Date
endOfYear (Date date) =
    Date { year = date.year, month = 12, day = 31 }


{-| Whole days from `a` to `b`: positive when `b` is later, negative when it is
earlier.

    Maybe.map2 Date.diffDays (Date.fromIso "2026-01-01") (Date.fromIso "2027-01-01") -- Just 365

-}
diffDays : Date -> Date -> Int
diffDays a b =
    toEpochDay b - toEpochDay a


{-| The day of the week, from 1 (Monday) to 7 (Sunday).

    Date.fromIso "2026-10-20" |> Maybe.map Date.weekday -- Just 2, a Tuesday

-}
weekday : Date -> Int
weekday date =
    modBy 7 (toEpochDay date + 3) + 1


{-| The first day of the date's month.
-}
startOfMonth : Date -> Date
startOfMonth (Date date) =
    Date { date | day = 1 }


{-| The last day of the date's month.

    Date.fromIso "2024-02-10" |> Maybe.map (Date.endOfMonth >> Date.toIso) -- Just "2024-02-29"

-}
endOfMonth : Date -> Date
endOfMonth (Date date) =
    Date { date | day = daysInMonth date.year date.month }


{-| The dates for a month calendar: six weeks of seven days, starting on
`firstDay` (1 = Monday ... 7 = Sunday), padded with days from the neighboring
months. Six rows are always returned, so a calendar keeps its height from
month to month. The arguments are the first day of the week, the year and the
month, in that order; a year before 1 is moved to year 1 and a month outside 1
to 12 to the nearest one. Every cell is a different day (only January of year 1,
in weeks that do not start on Monday, repeats its first day as the padding
before it).

    -- weeks starting on Monday, for October 2026
    Date.monthGrid 1 2026 10

-}
monthGrid : Int -> Int -> Int -> List (List Date)
monthGrid firstDay y m =
    let
        first =
            Date { year = max 1 y, month = clamp 1 12 m, day = 1 }

        offset =
            modBy 7 (weekday first - firstDay)

        start =
            toEpochDay first - offset
    in
    List.range 0 5
        |> List.map
            (\week ->
                List.range 0 6
                    |> List.map (\offsetDay -> fromEpochDay (start + week * 7 + offsetDay))
            )


{-| The calendar date of a `Time.Posix` in a time zone. Use it once to get
"today" from the clock of the browser:

    Task.map2 Date.fromPosix Time.here Time.now

A moment before year 1 gives 1 January of year 1.

-}
fromPosix : Time.Zone -> Time.Posix -> Date
fromPosix zone posix =
    let
        y =
            Time.toYear zone posix
    in
    if y < 1 then
        fromEpochDay firstEpochDay

    else
        Date
            { year = y
            , month = monthNumber (Time.toMonth zone posix)
            , day = Time.toDay zone posix
            }


{-| The day number of 1 January of year 1.
-}
firstEpochDay : Int
firstEpochDay =
    -719162


{-| The first moment of a date in a time zone: the inverse of `fromPosix`, for the
timestamps of events that happen on a day (the history of an order, the events of
a `Timeline`).

    Date.fromParts 2026 10 20 |> Maybe.map (Date.toPosix Time.utc) -- Just 2026-10-20T00:00:00Z

    Date.toPosix zone date |> Date.fromPosix zone -- date

In a time zone that skips midnight (a clock that jumps forward at 00:00) it is the
first moment of the date that exists.

The moment is only as right as the zone. `Time.here` from `elm/time` gives the
offset of the browser now, one fixed offset without the rules of summer time, so
for a date on the other side of a change of the clock the moment is an hour off
(in Oslo in October, 1 December comes out as 22:00 on 30 November UTC instead of
23:00). Store and send dates as the text of `toIso`, and use `toPosix` only with
a zone that has the rules, or for dates with the same offset as today.

-}
toPosix : Time.Zone -> Date -> Time.Posix
toPosix zone date =
    let
        wall =
            toEpochDay date * 86400000

        offsetAt millis =
            localMillis zone (Time.millisToPosix millis) - millis

        first =
            wall - offsetAt wall

        second =
            wall - offsetAt first

        onTheDay millis =
            fromPosix zone (Time.millisToPosix millis) == date
    in
    [ first, second ]
        |> List.filter onTheDay
        |> List.minimum
        |> Maybe.withDefault second
        |> Time.millisToPosix


localMillis : Time.Zone -> Time.Posix -> Int
localMillis zone posix =
    toEpochDay (fromPosix zone posix)
        * 86400000
        + Time.toHour zone posix
        * 3600000
        + Time.toMinute zone posix
        * 60000
        + Time.toSecond zone posix
        * 1000
        + Time.toMillis zone posix


monthNumber : Time.Month -> Int
monthNumber m =
    case m of
        Time.Jan ->
            1

        Time.Feb ->
            2

        Time.Mar ->
            3

        Time.Apr ->
            4

        Time.May ->
            5

        Time.Jun ->
            6

        Time.Jul ->
            7

        Time.Aug ->
            8

        Time.Sep ->
            9

        Time.Oct ->
            10

        Time.Nov ->
            11

        Time.Dec ->
            12
