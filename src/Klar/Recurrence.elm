module Klar.Recurrence exposing
    ( Rule, rule, Problem, problemText
    , Pattern, daily, weekly, monthlyOnDay, monthlyOnWeekday, yearlyOnDate, yearlyOnWeekday
    , Ordinal, first, second, third, fourth, last
    , skippingMissingDays
    , Option, every, ends, except
    , End, never, after, until
    , exceptions, withExceptions
    , occurrences, between, next, isOccurrence, count, isEndless, maxOccurrences
    , describe
    , toRRule, fromRRule
    )

{-| A rule for dates that repeat ("every second Tuesday", "the last day of the
month, ten times"): build it, ask it for its dates, describe it in words, and
exchange it with a backend as an iCalendar RRULE.

This module only does the arithmetic. For a form field that lets a person build
a rule, use [Klar.RecurrencePicker](Klar-RecurrencePicker); to draw the dates on
a month, give them to [Klar.Calendar](Klar-Calendar) as markers.

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

**Dates, not moments.** A rule works on calendar dates ([Klar.Date](Klar-Date)).
There are no time zones in the official Elm packages, and a date does not
shift between them. If the repeating thing has a time of day, your application
attaches the time and its zone to each date the rule gives.

**Limits.** No date after 31 December 9999 is ever produced, a result holds at
most `maxOccurrences` dates, and the work is done period by period, not day by
day: a yearly rule across a century is a hundred steps.


# Building a rule

@docs Rule, rule, Problem, problemText


# What repeats

@docs Pattern, daily, weekly, monthlyOnDay, monthlyOnWeekday, yearlyOnDate, yearlyOnWeekday


# The first, second ... last

@docs Ordinal, first, second, third, fourth, last


# Days that are missing

@docs skippingMissingDays


# Options

@docs Option, every, ends, except


# When it ends

@docs End, never, after, until


# Skipped dates

@docs exceptions, withExceptions


# The dates

@docs occurrences, between, next, isOccurrence, count, isEndless, maxOccurrences


# In words

@docs describe


# Exchanging rules

@docs toRRule, fromRRule

-}

import Klar.Date as Date exposing (Date)
import Klar.Locale exposing (Locale)
import Klar.Recurrence.Engine as Engine
import Klar.Recurrence.RRule as RRule
import Klar.Recurrence.Spec as Spec exposing (Spec)
import Klar.Recurrence.Words as Words
import Time



-- RULE


{-| A rule for dates that repeat. It is always valid: make one with `rule` or
`fromRRule`. Rules are compared with `==`: the order of the options, of the
weekdays and of the skipped dates does not matter, but two rules built from
different patterns are different even when they give the same dates (every
weekday of the week is not `daily`).
-}
type Rule
    = Rule Spec


{-| What was wrong with a rule or with the text of one: an interval below 1, a
day that does not exist, a part of an RRULE that this library does not read.
It is opaque, so more kinds can come; `problemText` says it in words.
-}
type Problem
    = Problem Spec.Problem


{-| What repeats: every day, certain weekdays, a day of the month ... Make one
with `daily`, `weekly`, `monthlyOnDay`, `monthlyOnWeekday`, `yearlyOnDate` or
`yearlyOnWeekday`, and give it to `rule`.
-}
type Pattern
    = Pattern Spec.Pattern


{-| One of the options of `rule`: how often (`every`), when it ends (`ends`) and
which dates are skipped (`except`). The order does not matter; if an option is
given twice, the last one wins.
-}
type Option
    = Option (Config -> Config)


type alias Config =
    { every : Int
    , end : Spec.End
    , except : List Date
    }


{-| Makes a rule from what repeats and a list of options. Without options the
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

-}
rule : Pattern -> List Option -> Result Problem Rule
rule (Pattern pattern) options =
    let
        config =
            List.foldl (\(Option change) current -> change current) { every = 1, end = Spec.Never, except = [] } options
    in
    Spec.make { every = config.every, pattern = pattern, end = config.end, except = config.except }
        |> Result.map Rule
        |> Result.mapError Problem


{-| The problem in a sentence, in the language of the locale.

    Recurrence.rule Recurrence.daily [ Recurrence.every 0 ]
        |> Result.mapError (Recurrence.problemText Locale.en)
    --> Err "How often it repeats must be a whole number, 1 or more, not 0."

-}
problemText : Locale -> Problem -> String
problemText locale (Problem problem) =
    Words.problemText locale problem



-- PATTERNS


{-| Every day (or every n-th day with `every`).
-}
daily : Pattern
daily =
    Pattern Spec.Daily


{-| On these weekdays of every week (or every n-th week with `every`). The first
weekday is a separate argument so that the list can never be empty.

    Recurrence.weekly Mon [ Thu ]

-}
weekly : Time.Weekday -> List Time.Weekday -> Pattern
weekly firstDay otherDays =
    Pattern (Spec.Weekly (List.map weekdayNumber (firstDay :: otherDays)))


{-| On a day of the month, 1 to 31. In a month without that day the rule uses
the last day of the month; `skippingMissingDays` skips the month instead. A
day outside 1 to 31 makes `rule` return a `Problem`.

    Recurrence.monthlyOnDay 15

    Recurrence.monthlyOnDay 31 -- the last day of every month

-}
monthlyOnDay : Int -> Pattern
monthlyOnDay day =
    Pattern (Spec.MonthlyDay day Spec.UseLastDay)


{-| On the first, second, third, fourth or last weekday of the month.

    Recurrence.monthlyOnWeekday Recurrence.second Tue

-}
monthlyOnWeekday : Ordinal -> Time.Weekday -> Pattern
monthlyOnWeekday (Ordinal ordinal) weekday =
    Pattern (Spec.MonthlyWeekday ordinal (weekdayNumber weekday))


{-| On a month and day of the year. A day that the month never has (31 April)
makes `rule` return a `Problem`. For 29 February the rule uses 28 February in
years that are not leap years; `skippingMissingDays` skips those years instead.

    Recurrence.yearlyOnDate Time.Oct 20

-}
yearlyOnDate : Time.Month -> Int -> Pattern
yearlyOnDate month day =
    Pattern (Spec.YearlyDate (monthNumber month) day Spec.UseLastDay)


{-| On the first, second, third, fourth or last weekday of a month, every
year.

    Recurrence.yearlyOnWeekday Recurrence.third Tue Time.Oct

-}
yearlyOnWeekday : Ordinal -> Time.Weekday -> Time.Month -> Pattern
yearlyOnWeekday (Ordinal ordinal) weekday month =
    Pattern (Spec.YearlyWeekday ordinal (weekdayNumber weekday) (monthNumber month))


{-| Skips a month (or, for 29 February, a year) that does not have the day,
instead of using the last day. It changes `monthlyOnDay` and `yearlyOnDate`, and
leaves every other pattern as it is, because they cannot lack a day.

    Recurrence.monthlyOnDay 31 |> Recurrence.skippingMissingDays

-}
skippingMissingDays : Pattern -> Pattern
skippingMissingDays (Pattern pattern) =
    case pattern of
        Spec.MonthlyDay day _ ->
            Pattern (Spec.MonthlyDay day Spec.Skip)

        Spec.YearlyDate month day _ ->
            Pattern (Spec.YearlyDate month day Spec.Skip)

        _ ->
            Pattern pattern


weekdayNumber : Time.Weekday -> Int
weekdayNumber weekday =
    case weekday of
        Time.Mon ->
            1

        Time.Tue ->
            2

        Time.Wed ->
            3

        Time.Thu ->
            4

        Time.Fri ->
            5

        Time.Sat ->
            6

        Time.Sun ->
            7


monthNumber : Time.Month -> Int
monthNumber month =
    case month of
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



-- ORDINALS


{-| Which weekday of the month: the first, second, third, fourth or the last.
There is no fifth, because not every month has one.
-}
type Ordinal
    = Ordinal Spec.Ordinal


{-| The first weekday of the month.
-}
first : Ordinal
first =
    Ordinal Spec.First


{-| The second weekday of the month.
-}
second : Ordinal
second =
    Ordinal Spec.Second


{-| The third weekday of the month.
-}
third : Ordinal
third =
    Ordinal Spec.Third


{-| The fourth weekday of the month.
-}
fourth : Ordinal
fourth =
    Ordinal Spec.Fourth


{-| The last weekday of the month, whether it is the fourth or the fifth.
-}
last : Ordinal
last =
    Ordinal Spec.Last



-- OPTIONS


{-| Repeat every n-th day, week, month or year instead of every one. The
default is 1. A number below 1, or above 2 147 483 647, makes `rule` return a
`Problem`.

    Recurrence.every 2

-}
every : Int -> Option
every n =
    Option (\config -> { config | every = n })


{-| When the rule ends. The default is `never`.
-}
ends : End -> Option
ends end =
    Option (\config -> { config | end = unEnd end })


{-| Dates that are skipped, such as a public holiday. They stay in the rule
and still count towards "after 10 occurrences". The default is none.
-}
except : List Date -> Option
except dates =
    Option (\config -> { config | except = dates })



-- END


{-| How a rule ends: `never`, `after` a number of occurrences, or `until` a
date. They exclude each other, so they are one type.
-}
type End
    = End Spec.End


unEnd : End -> Spec.End
unEnd (End end) =
    end


{-| The rule goes on for ever (in practice until 31 December 9999).
-}
never : End
never =
    End Spec.Never


{-| The rule ends after this many occurrences, counting the first. A number
below 1, or above 2 147 483 647, makes `rule` return a `Problem`.

    Recurrence.after 10

-}
after : Int -> End
after n =
    End (Spec.After n)


{-| The rule ends on this date, which is still an occurrence if it fits the
rule ("through" that day). A date after the year 9999 makes `rule` return a
`Problem`, because no date after 31 December 9999 is ever given.
-}
until : Date -> End
until date =
    End (Spec.Until date)



-- SKIPPED DATES


{-| The skipped dates of a rule, earliest first.
-}
exceptions : Rule -> List Date
exceptions (Rule spec) =
    spec.except


{-| The same rule with these dates skipped instead of the ones it had. For a
rule that `fromRRule` read: the `EXDATE` of an iCalendar event is not part of
the RRULE, so it comes from elsewhere.

    Recurrence.fromRRule text
        |> Result.map (Recurrence.withExceptions skippedDates)

-}
withExceptions : List Date -> Rule -> Rule
withExceptions dates (Rule spec) =
    Rule (Spec.withExceptions dates spec)



-- DATES


{-| The most dates one call of `occurrences` or `between` returns: 10 000. It
is a hard limit that keeps a daily rule over a thousand years from freezing a
page.
-}
maxOccurrences : Int
maxOccurrences =
    Engine.maxResults


{-| The first dates on or after `from`, at most `limit`, in order. The dates
are counted from `start`: "after 10 occurrences" ends with the tenth date from
`start`, also when `from` is later.

    Recurrence.occurrences { start = october20, from = october20, limit = 3 } rule
    --> the first three dates of the rule, counted from October 20

A `limit` of 0 or less gives no dates, and more than `maxOccurrences` counts as
`maxOccurrences`. Nothing after 31 December 9999 is returned.

-}
occurrences : { start : Date, from : Date, limit : Int } -> Rule -> List Date
occurrences window (Rule spec) =
    Engine.collect
        { start = Date.toEpochDay window.start
        , from = Date.toEpochDay window.from
        , to = Engine.lastEpochDay
        , limit = min maxOccurrences window.limit
        }
        spec
        |> List.map Date.fromEpochDay


{-| All dates from `from` to `to`, both inclusive, counted from `start`. When
there are more than `maxOccurrences`, `dates` holds the first ones and
`truncated` is `True`, so that a screen can say it shows a part.

    Recurrence.between { start = start, from = firstOfMonth, to = endOfMonth } rule
        |> .dates

-}
between : { start : Date, from : Date, to : Date } -> Rule -> { dates : List Date, truncated : Bool }
between window (Rule spec) =
    let
        found =
            Engine.collect
                { start = Date.toEpochDay window.start
                , from = Date.toEpochDay window.from
                , to = Date.toEpochDay window.to
                , limit = maxOccurrences + 1
                }
                spec
    in
    { dates = List.map Date.fromEpochDay (List.take maxOccurrences found)
    , truncated = List.length found > maxOccurrences
    }


{-| The first occurrence after a date (the date itself does not count), or
`Nothing` when the rule has ended or reaches the last day.
-}
next : { start : Date, after : Date } -> Rule -> Maybe Date
next window (Rule spec) =
    Engine.collect
        { start = Date.toEpochDay window.start
        , from = Date.toEpochDay window.after + 1
        , to = Engine.lastEpochDay
        , limit = 1
        }
        spec
        |> List.head
        |> Maybe.map Date.fromEpochDay


{-| Whether the date is an occurrence of the rule counted from `start`. A
skipped date, a date before the start and a date after the end are not.
-}
isOccurrence : { start : Date, date : Date } -> Rule -> Bool
isOccurrence window (Rule spec) =
    let
        day =
            Date.toEpochDay window.date
    in
    Engine.collect
        { start = Date.toEpochDay window.start
        , from = day
        , to = day
        , limit = 1
        }
        spec
        == [ day ]


{-| How many occurrences a rule that ends has in all, skipped dates left out.
`Nothing` when there is no number to give: the rule never ends (`isEndless`
says so), or it has more than `maxOccurrences` dates.
-}
count : { start : Date } -> Rule -> Maybe Int
count window (Rule spec) =
    case spec.end of
        Spec.Never ->
            Nothing

        _ ->
            let
                found =
                    Engine.collect
                        { start = Date.toEpochDay window.start
                        , from = Date.toEpochDay window.start
                        , to = Engine.lastEpochDay
                        , limit = maxOccurrences + 1
                        }
                        spec
                        |> List.length
            in
            if found > maxOccurrences then
                Nothing

            else
                Just found



{-| Whether the rule never ends (the end is `never`), however far its dates
reach.

    Recurrence.rule Recurrence.daily [] |> Result.map Recurrence.isEndless
    --> Ok True

-}
isEndless : Rule -> Bool
isEndless (Rule spec) =
    spec.end == Spec.Never



-- WORDS


{-| The rule in plain language, in the language of the locale: "Every day",
"Every 2 weeks on Monday and Thursday", "On the last Friday of every month through
31 December 2027", "Hver andre uke på mandag og torsdag". The last day of a rule
that ends on a date is part of it, so the words say "through" and "til og med".
Weekday and month names and dates follow `Klar.Locale` and `Klar.Format`.
-}
describe : Locale -> Rule -> String
describe locale (Rule spec) =
    Words.describe locale spec



-- RRULE


{-| The rule as the value of an iCalendar RRULE (RFC 5545), for a backend or a
calendar file: `FREQ=MONTHLY;BYDAY=-1FR;UNTIL=20271231`. The start date is not
part of an RRULE (it is the `DTSTART` of the event), and neither are the
skipped dates (`EXDATE`), so `exceptions` gives those separately.

"The 31st, or the last day of a shorter month" is written the way the RFC asks
for it, `BYMONTHDAY=-1` or `BYMONTHDAY=28,29,30;BYSETPOS=-1`.

`fromRRule (toRRule rule)` is `Ok rule` for every rule without skipped dates.

Two things to know before the text goes to a calendar. RFC 5545 counts the
`DTSTART` of an event as its first instance even when it does not fit the rule
(and calls the result undefined), but this library skips a start that does not
fit: start the event on a date that is an occurrence, or the calendar may show
one date more than `occurrences` does. And a date-only `UNTIL` is valid only
when `DTSTART` is a date too: some calendars read `UNTIL=20271231` on an event
with a time as midnight, which drops the last day. Give those the end as a
moment yourself.

-}
toRRule : Rule -> String
toRRule (Rule spec) =
    RRule.toText spec


{-| Reads the value of an RRULE (with or without `RRULE:` in front, parts in any
order). It reads `FREQ` (`DAILY`, `WEEKLY`, `MONTHLY`, `YEARLY`), `INTERVAL`,
`COUNT`, `UNTIL` as a date (`20271231`), `BYDAY` (with a number as in `2TU` and
`-1FR`, from the first to the fourth and the last), `BYMONTHDAY`, `BYMONTH` and
the two forms of `BYSETPOS=-1` that `toRRule` writes. Every number is at most
2 147 483 647, and an `UNTIL` is a date before the year 10 000.

Two forms are read as the rule they mean: `FREQ=DAILY;BYDAY=MO,TU,WE,TH,FR` (any
list of plain weekdays, without an interval) as a weekly rule on those days, and
`BYMONTH=3;BYMONTHDAY=-1` as the last day of March every year. Both come out in
their usual form when written again.

Everything else is a `Problem` that names it and nothing is guessed: `HOURLY`,
`BYWEEKNO`, a fifth Tuesday, several days of the month, `UNTIL` with a time (the
problem says to give the last day as a date). A
rule needs the days in the text, since it has no start date to take them from,
so a weekly rule without `BYDAY` is a `Problem` too. `WKST` is accepted when it
cannot change the dates, and refused for a weekly rule every second week or
less often unless it is Monday, because weeks are counted from Monday here.

    Recurrence.fromRRule "FREQ=WEEKLY;INTERVAL=2;BYDAY=MO,TH"

    Recurrence.fromRRule "FREQ=HOURLY"
        |> Result.mapError (Recurrence.problemText Locale.en)
    --> Err "Not supported in a recurrence rule: FREQ=HOURLY."

-}
fromRRule : String -> Result Problem Rule
fromRRule text =
    RRule.fromText text
        |> Result.map Rule
        |> Result.mapError Problem
