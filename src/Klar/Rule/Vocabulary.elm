module Klar.Rule.Vocabulary exposing
    ( Choice
    , FieldKind(..)
    , isPeriod
    , periodKeys
    , periodLabel
    , periodRange
    )

{-| The parts of the rule vocabulary that `Klar.Rule` keeps opaque, so that they
can grow without a breaking change: the kinds of fields, and the calendar
periods of `InPeriod`.

Internal to the rules group. Applications make kinds with `Rule.textKind` and the
other kind functions, and name periods by their keys.

-}

import Klar.Date as Date exposing (Date)
import Klar.Locale as Locale exposing (Locale)


{-| The kind of value a field holds.
-}
type FieldKind
    = TextKind
    | NumberKind
    | DateKind
    | BooleanKind
    | ChoiceKind (List Choice)


{-| One of the values of a choice field.
-}
type alias Choice =
    { value : String
    , label : String
    }



-- PERIODS


{-| The periods `InPeriod` understands, in the order a picker lists them.
-}
periodKeys : List String
periodKeys =
    [ "today"
    , "yesterday"
    , "tomorrow"
    , "thisWeek"
    , "lastWeek"
    , "nextWeek"
    , "thisMonth"
    , "lastMonth"
    , "nextMonth"
    , "thisQuarter"
    , "lastQuarter"
    , "nextQuarter"
    , "thisYear"
    , "lastYear"
    , "nextYear"
    ]


isPeriod : String -> Bool
isPeriod key =
    List.member key periodKeys


{-| The words for a period, as they follow "is within": "this month".
Unknown keys are written as they are.
-}
periodLabel : Locale -> String -> String
periodLabel locale key =
    let
        pick nb en =
            Locale.pick locale { nb = nb, en = en }
    in
    case key of
        "today" ->
            pick "i dag" "today"

        "yesterday" ->
            pick "i går" "yesterday"

        "tomorrow" ->
            pick "i morgen" "tomorrow"

        "thisWeek" ->
            pick "denne uken" "this week"

        "lastWeek" ->
            pick "forrige uke" "last week"

        "nextWeek" ->
            pick "neste uke" "next week"

        "thisMonth" ->
            pick "denne måneden" "this month"

        "lastMonth" ->
            pick "forrige måned" "last month"

        "nextMonth" ->
            pick "neste måned" "next month"

        "thisQuarter" ->
            pick "dette kvartalet" "this quarter"

        "lastQuarter" ->
            pick "forrige kvartal" "last quarter"

        "nextQuarter" ->
            pick "neste kvartal" "next quarter"

        "thisYear" ->
            pick "i år" "this year"

        "lastYear" ->
            pick "i fjor" "last year"

        "nextYear" ->
            pick "neste år" "next year"

        other ->
            other


{-| The first and the last day of a period (both included), as epoch days,
counted from `today`. Weeks start on Monday (ISO 8601); quarters are January to
March, April to June and so on.
-}
periodRange : Date -> String -> Maybe { first : Int, last : Int }
periodRange today key =
    let
        day =
            Date.toEpochDay today

        days first last =
            Just { first = first, last = last }

        -- 0 for Monday ... 6 for Sunday
        sinceMonday =
            modBy 7 (Date.weekday today - 1)

        monday =
            day - sinceMonday

        week offset =
            days (monday + 7 * offset) (monday + 7 * offset + 6)

        monthsFrom start count =
            days (Date.toEpochDay start) (Date.toEpochDay (Date.addMonths count start) - 1)

        month offset =
            monthsFrom (Date.addMonths offset (Date.startOfMonth today)) 1

        quarterStart =
            Date.addMonths (negate (modBy 3 (Date.month today - 1))) (Date.startOfMonth today)

        quarter offset =
            monthsFrom (Date.addMonths (3 * offset) quarterStart) 3

        yearStart =
            Date.addMonths (negate (Date.month today - 1)) (Date.startOfMonth today)

        year offset =
            monthsFrom (Date.addMonths (12 * offset) yearStart) 12
    in
    case key of
        "today" ->
            days day day

        "yesterday" ->
            days (day - 1) (day - 1)

        "tomorrow" ->
            days (day + 1) (day + 1)

        "thisWeek" ->
            week 0

        "lastWeek" ->
            week -1

        "nextWeek" ->
            week 1

        "thisMonth" ->
            month 0

        "lastMonth" ->
            month -1

        "nextMonth" ->
            month 1

        "thisQuarter" ->
            quarter 0

        "lastQuarter" ->
            quarter -1

        "nextQuarter" ->
            quarter 1

        "thisYear" ->
            year 0

        "lastYear" ->
            year -1

        "nextYear" ->
            year 1

        _ ->
            Nothing
