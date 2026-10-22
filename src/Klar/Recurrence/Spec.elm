module Klar.Recurrence.Spec exposing
    ( End(..)
    , Missing(..)
    , Ordinal(..)
    , Pattern(..)
    , Problem(..)
    , Spec
    , make
    , ordinalNumber
    , weekdayNumbers
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


{-| Everything that can be wrong with a rule or with the text of one.
-}
type Problem
    = IntervalTooSmall Int
    | CountTooSmall Int
    | DayOutOfRange Int
    | MonthOutOfRange Int
    | NoSuchDate Int Int
    | NoWeekdays
    | EmptyText
    | MissingPart String
    | RepeatedPart String
    | CannotRead String
    | Unsupported String
    | Conflict String


{-| The one way to get a `Spec`: checks the numbers, puts the lists in order
and the missing-day choice in its canonical form.
-}
make : Spec -> Result Problem Spec
make spec =
    if spec.every < 1 then
        Err (IntervalTooSmall spec.every)

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


endProblem : End -> Maybe Problem
endProblem end =
    case end of
        After n ->
            if n < 1 then
                Just (CountTooSmall n)

            else
                Nothing

        _ ->
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


dedupeWith : (a -> a -> Bool) -> List a -> List a
dedupeWith same sorted =
    case sorted of
        a :: b :: rest ->
            if same a b then
                dedupeWith same (b :: rest)

            else
                a :: dedupeWith same (b :: rest)

        _ ->
            sorted


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
