# Klar.Date

Calendar dates without a time or a time zone: a year, a month and a day.

Import: `import Klar.Date as Date` | Group: Date and time

Types: `Date`

## Signatures

```elm
-- The type
type Date  -- opaque: no constructors are exposed
fromParts : Int -> Int -> Int -> Maybe Date
year : Date -> Int
month : Date -> Int
day : Date -> Int

-- Reading and writing text
fromIso : String -> Maybe Date
toIso : Date -> String
fromPosix : Time.Zone -> Time.Posix -> Date
toPosix : Time.Zone -> Date -> Time.Posix

-- Comparing and counting
compare : Date -> Date -> Order
diffDays : Date -> Date -> Int
weekday : Date -> Int
isLeapYear : Int -> Bool
daysInMonth : Int -> Int -> Int

-- Moving around
addDays : Int -> Date -> Date
addMonths : Int -> Date -> Date
startOfMonth : Date -> Date
endOfMonth : Date -> Date

-- Weeks, quarters and years
addYears : Int -> Date -> Date
startOfWeek : Int -> Date -> Date
endOfWeek : Int -> Date -> Date
isoWeek : Date -> Int
isoWeekYear : Date -> Int
quarter : Date -> Int
startOfQuarter : Date -> Date
endOfQuarter : Date -> Date
startOfYear : Date -> Date
endOfYear : Date -> Date

-- Calendars
monthGrid : Int -> Int -> Int -> List (List Date)

-- Day numbers
toEpochDay : Date -> Int
fromEpochDay : Int -> Date
```

## Documentation

Calendar dates without a time or a time zone: a year, a month and a day.

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
are exact. A `Date` lies between 1 January of year 1 and 31 December 9999, the
range of the four-digit years of `toIso`: `fromIso` gives `Nothing` outside it,
and arithmetic that would leave it (`addDays`, `addMonths`, `fromEpochDay`)
stops at its first or last day. A `Time.Posix` is
only needed once, to get today's date with `fromPosix`.

Store and send a date as the text of `toIso`, never as the moment of its
midnight: a moment shifts the day when it is read in another time zone.

The date components of the library (`Klar.DatePicker`, `Klar.Calendar` ...)
use this type, and so does `Klar.Format` when it writes dates.

## The type

### `Date`

```elm
type Date  -- opaque: no constructors are exposed
```

A calendar date: a day that exists, in year 1 or later (the arithmetic stays
within year 9999). The type is opaque, so a date can never be 31 February or
month 13. Make one with
`fromParts` or `fromIso`, and read it with `year`, `month` and `day`.

### `fromParts`

```elm
fromParts : Int -> Int -> Int -> Maybe Date
```

Builds a date from a year (1 or later), a month (1 to 12) and a day, or
`Nothing` if that day does not exist (like 31 February, or a year before 1). A
year after 9999 is accepted, for code that counts day numbers past the end of
the range, but `toIso` writes it with five digits, which `fromIso` does not read.

    Date.fromParts 2026 2 30 -- Nothing

    Date.fromParts 2024 2 29 -- Just a date

### `year`

```elm
year : Date -> Int
```

The year of a date, 1 or later.

    Date.fromIso "2026-10-20" |> Maybe.map Date.year -- Just 2026

### `month`

```elm
month : Date -> Int
```

The month of a date, 1 (January) to 12 (December).

### `day`

```elm
day : Date -> Int
```

The day of the month of a date, from 1.

## Reading and writing text

### `fromIso`

```elm
fromIso : String -> Maybe Date
```

Reads `YYYY-MM-DD`: exactly four digits, a dash, two digits, a dash, two
digits. Surrounding spaces are ignored. A date that does not exist is
`Nothing`, and so is anything with a sign, a space or other characters inside.

    Date.fromIso "2026-02-28" -- Date.fromParts 2026 2 28

    Date.fromIso "2026-02-30" -- Nothing

    Date.fromIso "2026-2-3" -- Nothing

### `toIso`

```elm
toIso : Date -> String
```

Writes `YYYY-MM-DD`, with the year padded to four digits, so that `fromIso`
reads every date back.

    Date.fromParts 2026 3 5 |> Maybe.map Date.toIso -- Just "2026-03-05"

### `fromPosix`

```elm
fromPosix : Time.Zone -> Time.Posix -> Date
```

The calendar date of a `Time.Posix` in a time zone. Use it once to get
"today" from the clock of the browser:

    Task.map2 Date.fromPosix Time.here Time.now

A moment before year 1 gives 1 January of year 1, and one after 9999 gives
31 December 9999.

### `toPosix`

```elm
toPosix : Time.Zone -> Date -> Time.Posix
```

The first moment of a date in a time zone: the inverse of `fromPosix`, for the
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

## Comparing and counting

### `compare`

```elm
compare : Date -> Date -> Order
```

Which of two dates is earlier. Use it with `List.sortWith`.

    List.sortWith Date.compare dates

### `diffDays`

```elm
diffDays : Date -> Date -> Int
```

Whole days from `a` to `b`: positive when `b` is later, negative when it is
earlier.

    Maybe.map2 Date.diffDays (Date.fromIso "2026-01-01") (Date.fromIso "2027-01-01") -- Just 365

### `weekday`

```elm
weekday : Date -> Int
```

The day of the week, from 1 (Monday) to 7 (Sunday).

    Date.fromIso "2026-10-20" |> Maybe.map Date.weekday -- Just 2, a Tuesday

### `isLeapYear`

```elm
isLeapYear : Int -> Bool
```

Whether a year is a leap year in the Gregorian calendar: divisible by 4,
except centuries, except centuries divisible by 400.

    Date.isLeapYear 2024 -- True

    Date.isLeapYear 1900 -- False

    Date.isLeapYear 2000 -- True

### `daysInMonth`

```elm
daysInMonth : Int -> Int -> Int
```

The number of days in a month of a year (28 to 31). A month outside 1 to 12
counts as 31.

    Date.daysInMonth 2024 2 -- 29

    Date.daysInMonth 2026 4 -- 30

## Moving around

### `addDays`

```elm
addDays : Int -> Date -> Date
```

Moves a date by a number of days, forwards or backwards, across months and
years. It stops at 1 January of year 1 and at 31 December 9999.

    Date.fromIso "2026-01-01" |> Maybe.map (Date.addDays -1 >> Date.toIso) -- Just "2025-12-31"

### `addMonths`

```elm
addMonths : Int -> Date -> Date
```

Adds months, clamping the day to the end of the target month: 31 January
plus one month is 28 February (29 in a leap year). It stops at January of year 1
and at December 9999.

    Date.fromIso "2026-01-31" |> Maybe.map (Date.addMonths 1 >> Date.toIso) -- Just "2026-02-28"

    Date.fromIso "2026-10-15" |> Maybe.map (Date.addMonths -10 >> Date.toIso) -- Just "2025-12-15"

### `startOfMonth`

```elm
startOfMonth : Date -> Date
```

The first day of the date's month.

### `endOfMonth`

```elm
endOfMonth : Date -> Date
```

The last day of the date's month.

    Date.fromIso "2024-02-10" |> Maybe.map (Date.endOfMonth >> Date.toIso) -- Just "2024-02-29"

## Weeks, quarters and years

For reports and quick choices such as "This week" or "Last quarter".

    Date.fromIso "2026-11-04" |> Maybe.map (Date.startOfQuarter >> Date.toIso) -- Just "2026-10-01"

    Date.fromIso "2027-01-01" |> Maybe.map Date.isoWeek -- Just 53, a week of 2026

### `addYears`

```elm
addYears : Int -> Date -> Date
```

Adds years, keeping the month and the day; 29 February becomes 28 February
in a year that is not a leap year. It stops at year 1 and at 9999.

    Date.fromIso "2024-02-29" |> Maybe.map (Date.addYears 1 >> Date.toIso) -- Just "2025-02-28"

### `startOfWeek`

```elm
startOfWeek : Int -> Date -> Date
```

The first day of the week that holds the date, for weeks that start on
`firstDay` (1 = Monday ... 7 = Sunday; `Locale.firstDayOfWeek` gives the one of
a locale).

    Date.fromIso "2026-11-04" |> Maybe.map (Date.startOfWeek 1 >> Date.toIso) -- Just "2026-11-02", a Monday

### `endOfWeek`

```elm
endOfWeek : Int -> Date -> Date
```

The last day of the week that holds the date, for weeks that start on
`firstDay` (1 = Monday ... 7 = Sunday): six days after `startOfWeek`.

### `isoWeek`

```elm
isoWeek : Date -> Int
```

The week number of ISO 8601, 1 to 53: weeks start on Monday, and week 1 is
the week that holds the first Thursday of the year. The first days of January
can belong to the last week of the year before, and the last days of December to
week 1 of the next; `isoWeekYear` gives the year a week belongs to.

    Date.fromIso "2026-12-31" |> Maybe.map Date.isoWeek -- Just 53

### `isoWeekYear`

```elm
isoWeekYear : Date -> Int
```

The year that the ISO 8601 week of the date belongs to, for labels such as
"2026-W53": the year of its Thursday.

    Date.fromIso "2027-01-01" |> Maybe.map Date.isoWeekYear -- Just 2026

### `quarter`

```elm
quarter : Date -> Int
```

The quarter of the year that holds the date: 1 (January to March) to 4
(October to December).

### `startOfQuarter`

```elm
startOfQuarter : Date -> Date
```

The first day of the date's quarter: 1 January, 1 April, 1 July or
1 October.

### `endOfQuarter`

```elm
endOfQuarter : Date -> Date
```

The last day of the date's quarter: 31 March, 30 June, 30 September or
31 December.

### `startOfYear`

```elm
startOfYear : Date -> Date
```

1 January of the date's year.

### `endOfYear`

```elm
endOfYear : Date -> Date
```

31 December of the date's year.

## Calendars

### `monthGrid`

```elm
monthGrid : Int -> Int -> Int -> List (List Date)
```

The dates for a month calendar: six weeks of seven days, starting on
`firstDay` (1 = Monday ... 7 = Sunday), padded with days from the neighboring
months. Six rows are always returned, so a calendar keeps its height from
month to month. The arguments are the first day of the week, the year and the
month, in that order; a year outside 1 to 9999 or a month outside 1 to 12 is
moved to the nearest one, and padding beyond 31 December 9999 repeats that day.

    -- weeks starting on Monday, for October 2026
    Date.monthGrid 1 2026 10

## Day numbers

### `toEpochDay`

```elm
toEpochDay : Date -> Int
```

The number of days since 1970-01-01, which is day 0. Earlier dates give
negative numbers. Two dates are the same number of days apart as their day
numbers differ, which is how `addDays` and `diffDays` work.

    Date.fromParts 1970 1 2 |> Maybe.map Date.toEpochDay -- Just 1

### `fromEpochDay`

```elm
fromEpochDay : Int -> Date
```

The date of a day number: the inverse of `toEpochDay`. A number before
1 January of year 1 (-719162) gives that day, and one after 31 December 9999
(2932896) gives that day.

    Date.fromEpochDay 0 -- 1 January 1970
