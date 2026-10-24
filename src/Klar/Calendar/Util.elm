module Klar.Calendar.Util exposing
    ( addMonthsTo
    , after
    , atOrAfter
    , atOrBefore
    , before
    , clampTo
    , dateOf
    , earlier
    , endOfWeek
    , isoWeek
    , later
    , monthIndex
    , monthOfIndex
    , startOfWeek
    )

{-| Small pure helpers shared by the date and time components: date
comparison, clamping, ISO week numbers and month arithmetic.

Not meant for application code; use `Klar.Date` for dates.

-}

import Klar.Date as Date exposing (Date)


{-| A date from a year, a month and a day that are pulled into range: the year
to 1 or later, the month to 1 to 12 and the day to the days of that month.
Callers pass numbers that are valid by construction (the last day of a month,
the first of the next year); this keeps the type total without a `Maybe`.
-}
dateOf : Int -> Int -> Int -> Date
dateOf y m d =
    let
        year =
            max 1 y

        month =
            clamp 1 12 m
    in
    Date.fromParts year month (clamp 1 (Date.daysInMonth year month) d)
        |> Maybe.withDefault (Date.fromEpochDay 0)


before : Date -> Date -> Bool
before a b =
    Date.compare a b == LT


after : Date -> Date -> Bool
after a b =
    Date.compare a b == GT


atOrBefore : Date -> Date -> Bool
atOrBefore a b =
    Date.compare a b /= GT


atOrAfter : Date -> Date -> Bool
atOrAfter a b =
    Date.compare a b /= LT


earlier : Date -> Date -> Date
earlier a b =
    if before b a then
        b

    else
        a


later : Date -> Date -> Date
later a b =
    if after b a then
        b

    else
        a


{-| Keeps a date inside optional bounds.
-}
clampTo : Maybe Date -> Maybe Date -> Date -> Date
clampTo lower upper date =
    let
        floorApplied =
            case lower of
                Just bound ->
                    later bound date

                Nothing ->
                    date
    in
    case upper of
        Just bound ->
            earlier bound floorApplied

        Nothing ->
            floorApplied


{-| ISO 8601 week number (the week with the year's first Thursday is week 1).
-}
isoWeek : Date -> Int
isoWeek date =
    let
        thursday =
            Date.addDays (4 - Date.weekday date) date

        januaryFirst =
            Date.startOfMonth (Date.addMonths (1 - Date.month thursday) thursday)
    in
    Date.diffDays januaryFirst thursday // 7 + 1


{-| The first day of the week a date is in, for weeks that start on
`firstDay` (1 is Monday, 7 is Sunday, as `Locale.firstDayOfWeek` gives it).
-}
startOfWeek : Int -> Date -> Date
startOfWeek firstDay date =
    Date.addDays -(modBy 7 (Date.weekday date - firstDay)) date


{-| The last day of the week a date is in, six days after `startOfWeek`.
-}
endOfWeek : Int -> Date -> Date
endOfWeek firstDay date =
    Date.addDays 6 (startOfWeek firstDay date)


{-| A single number for a month, so months can be added and compared.
-}
monthIndex : Int -> Int -> Int
monthIndex year month =
    year * 12 + month - 1


monthOfIndex : Int -> ( Int, Int )
monthOfIndex index =
    let
        month =
            modBy 12 index
    in
    -- `//` rounds towards zero, so the year is divided after the rest is taken
    -- away; the months before the year 0 come out in the right year too
    ( (index - month) // 12, month + 1 )


{-| `addMonthsTo 2 ( 2026, 11 )` is `( 2027, 1 )`.
-}
addMonthsTo : Int -> ( Int, Int ) -> ( Int, Int )
addMonthsTo n ( year, month ) =
    monthOfIndex (monthIndex year month + n)
