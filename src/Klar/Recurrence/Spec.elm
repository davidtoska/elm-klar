module Klar.Recurrence.Spec exposing
    ( End(..)
    , Missing(..)
    , Ordinal(..)
    , Pattern(..)
    , Problem(..)
    , Reason(..)
    , Spec
    , largest
    , lastYear
    , make
    , ordinalNumber
    , weekdayNumbers
    , withExceptions
    )

{-| The open data model behind `Klar.Recurrence`: a rule as plain data, and the
one place that decides whether a rule is valid.

Not meant for application code. `Klar.Recurrence` wraps a `Spec` in an opaque
type, so that every `Rule` an application holds went through `make`. The
siblings in this folder (the dates, the words and the RRULE text) work on
`Spec`, and so do the tests.

-}

import Klar.Date as Date exposing (Date)


{-| A valid rule in its canonical form: two rules that mean the same are equal
with `==`. Make one with `make`.
-}
type alias Spec =
    { every : Int
    , pattern : Pattern
    , end : End
    , except : List Date
    }


{-| What repeats. Weekdays are ISO numbers (1 = Monday ... 7 = Sunday), months
1 to 12.
-}
type Pattern
    = Daily
    | Weekly (List Int)
    | MonthlyDay Int Missing
    | MonthlyWeekday Ordinal Int
    | YearlyDate Int Int Missing
    | YearlyWeekday Ordinal Int Int


{-| What happens in a month (or year) that does not have the day: the rule
uses the last day of that month, or it skips the month. Only 29 to 31 of a
month, and 29 February, can be missing; for every other day the choice is
`Skip`, which is its canonical form.
-}
type Missing
    = UseLastDay
    | Skip


type Ordinal
    = First
    | Second
    | Third
    | Fourth
    | Last


type End
    = Never
    | After Int
    | Until Date


{-| Everything that can be wrong with a rule or with the text of one. The
`String`s are parts of an RRULE (data, as the text has them); the words around
them come from `Words.problemText`.

  - `MissingPart names`: none of these parts is there (`[ "BYMONTHDAY", "BYDAY" ]`
    means one of the two is needed).
  - `Conflict first second`: two parts that cannot be used together.
  - `StartDayNotInMonth month day`: the rule names a month but no day, the day
    comes from the start date, and that month never has it (30 February).

-}
type Problem
    = IntervalTooSmall Int
    | IntervalTooLarge
    | CountTooSmall Int
    | CountTooLarge
    | EndTooLate
    | DayOutOfRange Int
    | MonthOutOfRange Int
    | NoSuchDate Int Int
    | NoWeekdays
    | EmptyText
    | MissingPart (List String)
    | RepeatedPart String
    | CannotRead String
    | Unsupported String Reason
    | Conflict String String
    | StartDayNotInMonth Int Int


{-| Why a part of an RRULE is not read. The `String` of `Unsupported` is the
part itself (data, written as the RRULE has it); the reason is turned into
words in the language of the locale by `Words.problemText`.

  - `Plain`: the part says it all (`FREQ=HOURLY`, `BYHOUR`).
  - `With other`: the part together with another one (`BYMONTH` with `FREQ=DAILY`).
  - `OutsideRule`: a line around the rule (`DTSTART`, `EXDATE`).
  - `SeveralLines`: more than one line.
  - `UntilWithTime`: an `UNTIL` with a time.
  - `WeekStartWithInterval`: a `WKST` other than Monday with an interval above 1.
  - `DaysWithDailyInterval`: `BYDAY` with `FREQ=DAILY` and an interval above 1.
  - `SeveralMonths`, `SeveralDays`: more than one month or day of the month.
  - `LastFromDay28`: `BYSETPOS=-1` with days of the month that do not run from 28.
  - `EveryWeekdayOf context example`: a weekday without a number in a monthly or yearly rule.
  - `SeveralDaysWith context`: several weekdays in a monthly or yearly rule.
  - `OrdinalBeyondFourth`: a weekday number other than 1 to 4 and -1.

-}
type Reason
    = Plain
    | With String
    | OutsideRule
    | SeveralLines
    | UntilWithTime
    | WeekStartWithInterval
    | DaysWithDailyInterval
    | SeveralMonths
    | SeveralDays
    | LastFromDay28
    | EveryWeekdayOf String String
    | SeveralDaysWith String
    | OrdinalBeyondFourth


{-| The largest interval and the largest number of occurrences: 2 147 483 647,
the largest 32-bit integer. A number that a person or a backend gives is never
far from that, and every number up to it is exact in every Elm runtime, which
`String.toInt` is not for a longer string of digits.
-}
largest : Int
largest =
    2147483647


{-| The last year a date can have in a rule: 9999. It is the last year of the
four-digit ISO form, and the dates a rule gives never go past its last day.
-}
lastYear : Int
lastYear =
    9999


{-| The one way to get a `Spec`: checks the numbers, puts the lists in order
and the missing-day choice in its canonical form.
-}
make : Spec -> Result Problem Spec
make spec =
    if spec.every < 1 then
        Err (IntervalTooSmall spec.every)

    else if spec.every > largest then
        Err IntervalTooLarge

    else
        case ( endProblem spec.end, patternProblem spec.pattern ) of
            ( Just problem, _ ) ->
                Err problem

            ( Nothing, Just problem ) ->
                Err problem

            ( Nothing, Nothing ) ->
                Ok
                    { every = spec.every
                    , pattern = canonicalPattern spec.pattern
                    , end = spec.end
                    , except = sortedUnique spec.except
                    }


{-| The same rule with other skipped dates, in order and without duplicates.
-}
withExceptions : List Date -> Spec -> Spec
withExceptions dates spec =
    { spec | except = sortedUnique dates }


endProblem : End -> Maybe Problem
endProblem end =
    case end of
        After n ->
            if n < 1 then
                Just (CountTooSmall n)

            else if n > largest then
                Just CountTooLarge

            else
                Nothing

        Until date ->
            if Date.year date > lastYear then
                Just EndTooLate

            else
                Nothing

        Never ->
            Nothing


patternProblem : Pattern -> Maybe Problem
patternProblem pattern =
    case pattern of
        Daily ->
            Nothing

        Weekly days ->
            if List.isEmpty days then
                Just NoWeekdays

            else
                Nothing

        MonthlyDay day _ ->
            dayProblem day

        MonthlyWeekday _ _ ->
            Nothing

        YearlyDate month day _ ->
            if month < 1 || month > 12 then
                Just (MonthOutOfRange month)

            else if day < 1 || day > Date.daysInMonth 2024 month then
                Just (NoSuchDate month day)

            else
                Nothing

        YearlyWeekday _ _ month ->
            if month < 1 || month > 12 then
                Just (MonthOutOfRange month)

            else
                Nothing


dayProblem : Int -> Maybe Problem
dayProblem day =
    if day < 1 || day > 31 then
        Just (DayOutOfRange day)

    else
        Nothing


canonicalPattern : Pattern -> Pattern
canonicalPattern pattern =
    case pattern of
        Weekly days ->
            Weekly (List.sort days |> dedupe)

        MonthlyDay day missing ->
            MonthlyDay day
                (if day <= 28 then
                    Skip

                 else
                    missing
                )

        YearlyDate month day missing ->
            YearlyDate month
                day
                (if month == 2 && day == 29 then
                    missing

                 else
                    Skip
                )

        _ ->
            pattern


sortedUnique : List Date -> List Date
sortedUnique dates =
    dates
        |> List.sortWith Date.compare
        |> dedupeWith (\a b -> Date.compare a b == EQ)


dedupe : List Int -> List Int
dedupe =
    dedupeWith (==)


{-| Drops the neighbours that are the same. It keeps what it found in an
accumulator, so tens of thousands of skipped dates do not overflow the stack.
-}
dedupeWith : (a -> a -> Bool) -> List a -> List a
dedupeWith same sorted =
    dedupeHelp same sorted []


dedupeHelp : (a -> a -> Bool) -> List a -> List a -> List a
dedupeHelp same sorted kept =
    case sorted of
        a :: b :: rest ->
            if same a b then
                dedupeHelp same (b :: rest) kept

            else
                dedupeHelp same (b :: rest) (a :: kept)

        [ a ] ->
            List.reverse (a :: kept)

        [] ->
            List.reverse kept


{-| The ISO weekday numbers (1 to 7) of a weekly rule, in order.
-}
weekdayNumbers : Pattern -> List Int
weekdayNumbers pattern =
    case pattern of
        Weekly days ->
            days

        _ ->
            []


{-| 1 to 4 for the first to the fourth, -1 for the last: the number RFC 5545
puts before the day.
-}
ordinalNumber : Ordinal -> Int
ordinalNumber ordinal =
    case ordinal of
        First ->
            1

        Second ->
            2

        Third ->
            3

        Fourth ->
            4

        Last ->
            -1
