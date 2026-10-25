# Klar.Recurrence

A rule for dates that repeat ("every second Tuesday", "the last day of the month, ten times").

Import: `import Klar.Recurrence as Recurrence` | Group: Date and time

Types: `End`, `Rule`, `Option`, `Ordinal`, `Pattern`, `Problem`

## Signatures

```elm
-- Building a rule
type Rule  -- opaque: no constructors are exposed
type Problem  -- opaque: no constructors are exposed
rule : Pattern -> List Option -> Result Problem Rule
problemText : Locale.Locale -> Problem -> String

-- What repeats
type Pattern  -- opaque: no constructors are exposed
daily : Pattern
weekly : Time.Weekday -> List Time.Weekday -> Pattern
monthlyOnDay : Int -> Pattern
monthlyOnWeekday : Ordinal -> Time.Weekday -> Pattern
yearlyOnDate : Time.Month -> Int -> Pattern
yearlyOnWeekday : Ordinal -> Time.Weekday -> Time.Month -> Pattern

-- The first, second ... last
type Ordinal  -- opaque: no constructors are exposed
first : Ordinal
second : Ordinal
third : Ordinal
fourth : Ordinal
last : Ordinal

-- Days that are missing
skippingMissingDays : Pattern -> Pattern

-- Options
type Option  -- opaque: no constructors are exposed
every : Int -> Option
ends : End -> Option
except : List Date.Date -> Option

-- When it ends
type End  -- opaque: no constructors are exposed
never : End
after : Int -> End
until : Date.Date -> End

-- Skipped dates
exceptions : Rule -> List Date.Date
withExceptions : List Date.Date -> Rule -> Rule

-- The dates
occurrences : { start : Date.Date, from : Date.Date, limit : Int } -> Rule -> List Date.Date
between :
    { start : Date.Date, from : Date.Date, to : Date.Date }
    -> Rule
    -> { dates : List Date.Date, truncated : Bool }
next : { start : Date.Date, after : Date.Date } -> Rule -> Maybe Date.Date
isOccurrence : { start : Date.Date, date : Date.Date } -> Rule -> Bool
count : { start : Date.Date } -> Rule -> Maybe Int
lastOccurrence : { start : Date.Date } -> Rule -> Maybe Date.Date
isEndless : Rule -> Bool
endsAfter : Rule -> Maybe Int
endsOn : Rule -> Maybe Date.Date
maxOccurrences : Int

-- In words
describe : Locale.Locale -> Rule -> String

-- Exchanging rules
toRRule : Rule -> String
fromRRule : { start : Date.Date } -> String -> Result Problem Rule
```

## Documentation

A rule for dates that repeat ("every second Tuesday", "the last day of the
month, ten times"): build it, ask it for its dates, describe it in words, and
exchange it with a backend as an iCalendar RRULE.

Use when: the application needs the dates of a repeating schedule, a description of it in words or an RRULE for the backend.
Do not use when: a person builds the rule in a form (as `Klar.RecurrencePicker`).

This module only does the arithmetic. To draw the dates on a month, give them
to [Klar.Calendar](Klar.Calendar.md) as markers.

    import Klar.Date as Date exposing (Date)
    import Klar.Locale as Locale
    import Klar.Recurrence as Recurrence exposing (Rule)
    import Time exposing (Weekday(..))

    -- every second week on Monday and Thursday, ten times
    biweekly : Result Recurrence.Problem Rule
    biweekly =
        Recurrence.rule (Recurrence.weekly Mon [ Thu ])
            [ Recurrence.every 2
            , Recurrence.ends (Recurrence.after 10)
            ]

    -- the first dates, counting from a start date
    Result.map (Recurrence.occurrences { start = start, from = start, limit = 5 }) biweekly

    Result.map (Recurrence.describe Locale.en) biweekly
    --> Ok "Every 2 weeks on Monday and Thursday, 10 times"

    Result.map Recurrence.toRRule biweekly
    --> Ok "FREQ=WEEKLY;INTERVAL=2;BYDAY=MO,TH;COUNT=10"

**A rule cannot be wrong.** `Rule` is opaque and `rule` is the only way to make
one. A rule that makes no sense (every 0 days, the 32nd of the month, no
weekday) is a `Problem`, never quietly corrected. Failure is a value, so
`rule` returns a `Result`.

**The rule has no start date.** The start is given to the functions that need
it, like the `DTSTART` of iCalendar. It is the anchor: weeks, months and years
are counted from the one that holds the start, so "every second week" means
the start's week, the week after next, and so on. A date before the start is
never an occurrence, and the start itself is one only if it fits the rule (a
weekly rule on Mondays started on a Tuesday begins on the next Monday). The
count of "after 10 occurrences" starts at the first date that fits.

**Months that are too short.** "Monthly on the 31st" has no 31st in April. By
default the rule then uses the last day of that month, which is what an
invoice run on "the 31st" wants; `skippingMissingDays` skips such months
instead, as RFC 5545 does. The same choice covers "yearly on 29 February" in
years that are not leap years (28 February, or skip the year). "The last
Friday" (`monthlyOnWeekday last Fri`) always exists, and so does "the fourth"
but not "the fifth", which is why there is no fifth.

**Skipped dates.** `except` removes single dates (a public holiday, one
cancelled delivery) without changing the rule. A skipped date still counts
towards "after 10 occurrences", as in iCalendar.

**Weeks start on Monday**, like the rest of the library.

**Dates, not moments.** A rule works on calendar dates ([Klar.Date](Klar.Date.md)).
There are no time zones in the official Elm packages, and a date does not
shift between them. If the repeating thing has a time of day, your application
attaches the time and its zone to each date the rule gives.

**Limits.** No date after 31 December 9999 is ever produced (an `until` after
that year is a `Problem`), a result holds at most `maxOccurrences` dates, an
interval or a number of occurrences is at most 2 147 483 647 (a `Problem` above
it, and when an RRULE gives a longer number), and the work is done period by
period, not day by day: a yearly rule across a century is a hundred steps.

## Building a rule

### `Rule`

```elm
type Rule  -- opaque: no constructors are exposed
```

A rule for dates that repeat. It is always valid: make one with `rule` or
`fromRRule`. Rules are compared with `==`: the order of the options, of the
weekdays and of the skipped dates does not matter, but two rules built from
different patterns are different even when they give the same dates (every
weekday of the week is not `daily`).

### `Problem`

```elm
type Problem  -- opaque: no constructors are exposed
```

What was wrong with a rule or with the text of one: an interval below 1, a
day that does not exist, a part of an RRULE that this library does not read.
It is opaque, so more kinds can come; `problemText` says it in words.

### `rule`

```elm
rule : Pattern -> List Option -> Result Problem Rule
```

Makes a rule from what repeats and a list of options. Without options the
rule repeats every time (every day, every week ...) and never ends.

    Recurrence.rule Recurrence.daily []

    Recurrence.rule (Recurrence.monthlyOnWeekday Recurrence.last Fri)
        [ Recurrence.ends (Recurrence.until lastDayOf2027) ]

A rule that cannot exist is an `Err` with the reason: `every 0`, `after 0`, a
`monthlyOnDay 32`, a `yearlyOnDate Apr 31`, an `every` or `after` above
2 147 483 647, an `until` in a year after 9999. Nothing is clamped.

The rule does not know its start date, and a start date that does not fit the
rule (a weekly rule on Mondays started on a Tuesday) is not an occurrence here:
the first date is the first one that fits. RFC 5545 says that `DTSTART` is the
first instance even then, and leaves such a rule undefined, so a calendar that
reads the RRULE of this rule with such a `DTSTART` may show one more date.
Start the series on a date that fits, and the two agree.

### `problemText`

```elm
problemText : Locale.Locale -> Problem -> String
```

The problem in a sentence, in the language of the locale.

    Recurrence.rule Recurrence.daily [ Recurrence.every 0 ]
        |> Result.mapError (Recurrence.problemText Locale.en)
    --> Err "How often it repeats must be a whole number, 1 or more, not 0."

## What repeats

### `Pattern`

```elm
type Pattern  -- opaque: no constructors are exposed
```

What repeats: every day, certain weekdays, a day of the month ... Make one
with `daily`, `weekly`, `monthlyOnDay`, `monthlyOnWeekday`, `yearlyOnDate` or
`yearlyOnWeekday`, and give it to `rule`.

### `daily`

```elm
daily : Pattern
```

Every day (or every n-th day with `every`).

### `weekly`

```elm
weekly : Time.Weekday -> List Time.Weekday -> Pattern
```

On these weekdays of every week (or every n-th week with `every`). The first
weekday is a separate argument so that the list can never be empty.

    Recurrence.weekly Mon [ Thu ]

### `monthlyOnDay`

```elm
monthlyOnDay : Int -> Pattern
```

On a day of the month, 1 to 31. In a month without that day the rule uses
the last day of the month; `skippingMissingDays` skips the month instead. A
day outside 1 to 31 makes `rule` return a `Problem`.

    Recurrence.monthlyOnDay 15

    Recurrence.monthlyOnDay 31 -- the last day of every month

### `monthlyOnWeekday`

```elm
monthlyOnWeekday : Ordinal -> Time.Weekday -> Pattern
```

On the first, second, third, fourth or last weekday of the month.

    Recurrence.monthlyOnWeekday Recurrence.second Tue

### `yearlyOnDate`

```elm
yearlyOnDate : Time.Month -> Int -> Pattern
```

On a month and day of the year. A day that the month never has (31 April)
makes `rule` return a `Problem`. For 29 February the rule uses 28 February in
years that are not leap years; `skippingMissingDays` skips those years instead.

    Recurrence.yearlyOnDate Time.Oct 20

### `yearlyOnWeekday`

```elm
yearlyOnWeekday : Ordinal -> Time.Weekday -> Time.Month -> Pattern
```

On the first, second, third, fourth or last weekday of a month, every
year.

    Recurrence.yearlyOnWeekday Recurrence.third Tue Time.Oct

## The first, second ... last

### `Ordinal`

```elm
type Ordinal  -- opaque: no constructors are exposed
```

Which weekday of the month: the first, second, third, fourth or the last.
There is no fifth, because not every month has one.

### `first`

```elm
first : Ordinal
```

The first weekday of the month.

### `second`

```elm
second : Ordinal
```

The second weekday of the month.

### `third`

```elm
third : Ordinal
```

The third weekday of the month.

### `fourth`

```elm
fourth : Ordinal
```

The fourth weekday of the month.

### `last`

```elm
last : Ordinal
```

The last weekday of the month, whether it is the fourth or the fifth.

## Days that are missing

### `skippingMissingDays`

```elm
skippingMissingDays : Pattern -> Pattern
```

Skips a month (or, for 29 February, a year) that does not have the day,
instead of using the last day. It changes `monthlyOnDay` and `yearlyOnDate`, and
leaves every other pattern as it is, because they cannot lack a day.

    Recurrence.monthlyOnDay 31 |> Recurrence.skippingMissingDays

## Options

### `Option`

```elm
type Option  -- opaque: no constructors are exposed
```

One of the options of `rule`: how often (`every`), when it ends (`ends`) and
which dates are skipped (`except`). The order does not matter; if an option is
given twice, the last one wins.

### `every`

```elm
every : Int -> Option
```

Repeat every n-th day, week, month or year instead of every one. The
default is 1. A number below 1, or above 2 147 483 647, makes `rule` return a
`Problem`.

    Recurrence.every 2

### `ends`

```elm
ends : End -> Option
```

When the rule ends. The default is `never`.

### `except`

```elm
except : List Date.Date -> Option
```

Dates that are skipped, such as a public holiday. They stay in the rule
and still count towards "after 10 occurrences". The default is none.

## When it ends

### `End`

```elm
type End  -- opaque: no constructors are exposed
```

How a rule ends: `never`, `after` a number of occurrences, or `until` a
date. They exclude each other, so they are one type.

### `never`

```elm
never : End
```

The rule goes on for ever (in practice until 31 December 9999).

### `after`

```elm
after : Int -> End
```

The rule ends after this many occurrences, counting the first. A number
below 1, or above 2 147 483 647, makes `rule` return a `Problem`.

    Recurrence.after 10

### `until`

```elm
until : Date.Date -> End
```

The rule ends on this date, which is still an occurrence if it fits the
rule ("through" that day). A date after the year 9999 makes `rule` return a
`Problem`, because no date after 31 December 9999 is ever given.

## Skipped dates

### `exceptions`

```elm
exceptions : Rule -> List Date.Date
```

The skipped dates of a rule, earliest first.

### `withExceptions`

```elm
withExceptions : List Date.Date -> Rule -> Rule
```

The same rule with these dates skipped instead of the ones it had. For a
rule that `fromRRule` read: the `EXDATE` of an iCalendar event is not part of
the RRULE, so it comes from elsewhere.

    Recurrence.fromRRule { start = firstDelivery } text
        |> Result.map (Recurrence.withExceptions skippedDates)

## The dates

### `occurrences`

```elm
occurrences : { start : Date.Date, from : Date.Date, limit : Int } -> Rule -> List Date.Date
```

The first dates on or after `from`, at most `limit`, in order. The dates
are counted from `start`: "after 10 occurrences" ends with the tenth date from
`start`, also when `from` is later.

    Recurrence.occurrences { start = october20, from = october20, limit = 3 } rule
    --> the first three dates of the rule, counted from October 20

A `limit` of 0 or less gives no dates, and more than `maxOccurrences` counts as
`maxOccurrences`. Nothing after 31 December 9999 is returned.

### `between`

```elm
between :
    { start : Date.Date, from : Date.Date, to : Date.Date }
    -> Rule
    -> { dates : List Date.Date, truncated : Bool }
```

All dates from `from` to `to`, both inclusive, counted from `start`. When
there are more than `maxOccurrences`, `dates` holds the first ones and
`truncated` is `True`, so that a screen can say it shows a part.

    Recurrence.between { start = start, from = firstOfMonth, to = endOfMonth } rule
        |> .dates

### `next`

```elm
next : { start : Date.Date, after : Date.Date } -> Rule -> Maybe Date.Date
```

The first occurrence after a date (the date itself does not count), or
`Nothing` when the rule has ended or reaches the last day.

### `isOccurrence`

```elm
isOccurrence : { start : Date.Date, date : Date.Date } -> Rule -> Bool
```

Whether the date is an occurrence of the rule counted from `start`. A
skipped date, a date before the start and a date after the end are not.

### `count`

```elm
count : { start : Date.Date } -> Rule -> Maybe Int
```

How many occurrences a rule that ends has in all, skipped dates left out.
`Nothing` when there is no number to give: the rule never ends (`isEndless`
says so), or it has more than `maxOccurrences` dates.

### `lastOccurrence`

```elm
lastOccurrence : { start : Date.Date } -> Rule -> Maybe Date.Date
```

The date of the last occurrence of a rule that ends, counted from `start`
and with skipped dates left out, such as "Last delivery 14 October". `Nothing`
when the rule never ends or has no dates at all.

    Recurrence.lastOccurrence { start = firstDelivery } rule

### `isEndless`

```elm
isEndless : Rule -> Bool
```

Whether the rule never ends (the end is `never`), however far its dates
reach.

    Recurrence.rule Recurrence.daily [] |> Result.map Recurrence.isEndless
    --> Ok True

### `endsAfter`

```elm
endsAfter : Rule -> Maybe Int
```

The number of a rule that ends after a number of occurrences (`after 10`
gives `Just 10`), for a column such as "10 times". `Nothing` for the other ends.

### `endsOn`

```elm
endsOn : Rule -> Maybe Date.Date
```

The last day of a rule that ends on a date (`until`), for a column such as
"Ends 31 Dec 2027". `Nothing` for the other ends. The day itself is only an
occurrence when it fits the rule; `lastOccurrence` gives the last date there is.

### `maxOccurrences`

```elm
maxOccurrences : Int
```

The most dates one call of `occurrences` or `between` returns: 10 000. It
is a hard limit that keeps a daily rule over a thousand years from freezing a
page.

## In words

### `describe`

```elm
describe : Locale.Locale -> Rule -> String
```

The rule in plain language, in the language of the locale: "Every day",
"Every 2 weeks on Monday and Thursday", "On the last Friday of every month through
31 December 2027", "Hver andre uke på mandag og torsdag". The last day of a rule
that ends on a date is part of it, so the words say "through" and "til og med".
Weekday and month names and dates follow `Klar.Locale` and `Klar.Format`.

## Exchanging rules

### `toRRule`

```elm
toRRule : Rule -> String
```

The rule as the value of an iCalendar RRULE (RFC 5545), for a backend or a
calendar file: `FREQ=MONTHLY;BYDAY=-1FR;UNTIL=20271231`. The start date is not
part of an RRULE (it is the `DTSTART` of the event), and neither are the
skipped dates (`EXDATE`), so `exceptions` gives those separately.

"The 31st, or the last day of a shorter month" is written the way the RFC asks
for it, `BYMONTHDAY=-1` or `BYMONTHDAY=28,29,30;BYSETPOS=-1`.

`fromRRule { start = start } (toRRule rule)` is `Ok rule` for every rule without skipped dates and any start.

Two things to know before the text goes to a calendar. RFC 5545 counts the
`DTSTART` of an event as its first instance even when it does not fit the rule
(and calls the result undefined), but this library skips a start that does not
fit: start the event on a date that is an occurrence, or the calendar may show
one date more than `occurrences` does. And a date-only `UNTIL` is valid only
when `DTSTART` is a date too: some calendars read `UNTIL=20271231` on an event
with a time as midnight, which drops the last day. Give those the end as a
moment yourself.

### `fromRRule`

```elm
fromRRule : { start : Date.Date } -> String -> Result Problem Rule
```

Reads the value of an RRULE (with or without `RRULE:` in front, parts in any
order). It reads `FREQ` (`DAILY`, `WEEKLY`, `MONTHLY`, `YEARLY`), `INTERVAL`,
`COUNT`, `UNTIL` as a date (`20271231`), `BYDAY` (with a number as in `2TU` and
`-1FR`, from the first to the fourth and the last), `BYMONTHDAY`, `BYMONTH` and
the two forms of `BYSETPOS=-1` that `toRRule` writes. Every number is at most
2 147 483 647, and an `UNTIL` is a date before the year 10 000.

Two forms are read as the rule they mean: `FREQ=DAILY;BYDAY=MO,TU,WE,TH,FR` (any
list of plain weekdays, without an interval) as a weekly rule on those days, and
`BYMONTH=3;BYMONTHDAY=-1` as the last day of March every year. Both come out in
their usual form when written again.

The `start` is the first date of the series (the `DTSTART` of the event), and
the parts a rule leaves out are taken from it, as RFC 5545 says: a weekly rule
without `BYDAY` repeats on the start's weekday, a monthly rule without
`BYMONTHDAY` or `BYDAY` on its day of the month, and `FREQ=YEARLY` alone (how
Google Calendar writes "every year on 20 October") on its date. The rule that
comes back has those parts, and `toRRule` writes them.

Everything else is a `Problem` that names it and nothing is guessed: `HOURLY`,
`BYWEEKNO`, a fifth Tuesday, several days of the month, `UNTIL` with a time (the
problem says to give the last day as a date). `WKST` is accepted when it cannot
change the dates, and refused for a weekly rule every second week or less often
unless it is Monday, because weeks are counted from Monday here.

    Recurrence.fromRRule { start = firstDelivery } "FREQ=WEEKLY;INTERVAL=2;BYDAY=MO,TH"

    Recurrence.fromRRule { start = firstDelivery } "FREQ=HOURLY"
        |> Result.mapError (Recurrence.problemText Locale.en)
    --> Err "Not supported in a recurrence rule: FREQ=HOURLY."
