module Klar.Recurrence.RRule exposing (fromText, toText, withStart)

{-| Reading and writing the value of an iCalendar RRULE (RFC 5545, section
3.3.10) for the rules `Klar.Recurrence` can express.

Written: `FREQ`, `INTERVAL`, `BYMONTH`, `BYDAY` (with the number before the day,
as in `2TU` and `-1FR`), `BYMONTHDAY`, `BYSETPOS` (only as `-1`, see below),
`COUNT` and `UNTIL` in the date form (`20271231`).

"The 31st, or the last day of a shorter month" has no short form in RRULE. It is
written the way the RFC says to ask for it: `BYMONTHDAY=-1` for the last day,
and `BYMONTHDAY=28,29,30;BYSETPOS=-1` for "the 30th, or the last day of a month
that is shorter". The same two forms are read back.

Read: the same parts, in any order and in upper or lower case, with an optional
`RRULE:` in front. A part that is outside this subset gives a `Problem` that
names it, and a rule that depends on a start date that the text does not have
(a weekly rule without `BYDAY`) gives a `Problem` too.

Not meant for application code.

-}

import Dict exposing (Dict)
import Klar.Date as Date
import Klar.Recurrence.Spec as Spec
    exposing
        ( End(..)
        , Missing(..)
        , Ordinal(..)
        , Pattern(..)
        , Problem(..)
        , Reason(..)
        , Spec
        )



-- WRITING


{-| The value of the RRULE of a rule, such as
`FREQ=WEEKLY;INTERVAL=2;BYDAY=MO,TH;COUNT=10`. The skipped dates of the rule
are not part of an RRULE (iCalendar keeps them in `EXDATE`), so they are not
written.
-}
toText : Spec -> String
toText spec =
    let
        interval =
            if spec.every > 1 then
                [ "INTERVAL=" ++ String.fromInt spec.every ]

            else
                []

        ending =
            case spec.end of
                Never ->
                    []

                After n ->
                    [ "COUNT=" ++ String.fromInt n ]

                Until date ->
                    [ "UNTIL=" ++ String.replace "-" "" (Date.toIso date) ]
    in
    String.join ";" (frequency spec.pattern :: interval ++ patternParts spec.pattern ++ ending)


frequency : Pattern -> String
frequency pattern =
    "FREQ="
        ++ (case pattern of
                Daily ->
                    "DAILY"

                Weekly _ ->
                    "WEEKLY"

                MonthlyDay _ _ ->
                    "MONTHLY"

                MonthlyWeekday _ _ ->
                    "MONTHLY"

                YearlyDate _ _ _ ->
                    "YEARLY"

                YearlyWeekday _ _ _ ->
                    "YEARLY"
           )


patternParts : Pattern -> List String
patternParts pattern =
    case pattern of
        Daily ->
            []

        Weekly days ->
            [ "BYDAY=" ++ String.join "," (List.map dayCode days) ]

        MonthlyDay day missing ->
            monthDayParts day missing

        MonthlyWeekday ordinal weekday ->
            [ "BYDAY=" ++ ordinalDay ordinal weekday ]

        YearlyDate month day missing ->
            ("BYMONTH=" ++ String.fromInt month) :: monthDayParts day missing

        YearlyWeekday ordinal weekday month ->
            [ "BYMONTH=" ++ String.fromInt month
            , "BYDAY=" ++ ordinalDay ordinal weekday
            ]


monthDayParts : Int -> Missing -> List String
monthDayParts day missing =
    case missing of
        Skip ->
            [ "BYMONTHDAY=" ++ String.fromInt day ]

        UseLastDay ->
            if day == 31 then
                [ "BYMONTHDAY=-1" ]

            else
                [ "BYMONTHDAY=" ++ String.join "," (List.map String.fromInt (List.range 28 day))
                , "BYSETPOS=-1"
                ]


ordinalDay : Ordinal -> Int -> String
ordinalDay ordinal weekday =
    String.fromInt (Spec.ordinalNumber ordinal) ++ dayCode weekday


dayCode : Int -> String
dayCode weekday =
    case weekday of
        1 ->
            "MO"

        2 ->
            "TU"

        3 ->
            "WE"

        4 ->
            "TH"

        5 ->
            "FR"

        6 ->
            "SA"

        _ ->
            "SU"



-- READING


{-| Fills in the parts that RFC 5545 (3.3.10) takes from `DTSTART` when a rule
leaves them out, so that the rule says its days itself: the weekday of a weekly
rule, the day of the month of a monthly rule, and the month and day of a yearly
rule (`FREQ=YEARLY` alone is how many calendars write "every year on this
day"). A part that is there is never touched, and a yearly rule with a day but
no month stays as it is (it means every month), for `fromText` to name. A text
of several lines is left alone too.
-}
withStart : Date.Date -> String -> String
withStart start text =
    let
        trimmed =
            String.trim text

        body =
            if String.toUpper (String.left 6 trimmed) == "RRULE:" then
                String.dropLeft 6 trimmed

            else
                trimmed

        given =
            String.split ";" body
                |> List.map String.trim
                |> List.filter (\part -> part /= "")

        keyOf part =
            String.split "=" part |> List.head |> Maybe.withDefault part |> String.trim |> String.toUpper

        has name =
            List.any (\part -> keyOf part == name) given

        freqValue =
            given
                |> List.filter (\part -> keyOf part == "FREQ")
                |> List.head
                |> Maybe.map (String.split "=" >> List.drop 1 >> String.join "=" >> String.trim >> String.toUpper)

        hasDay =
            has "BYDAY" || has "BYMONTHDAY"

        day =
            "BYMONTHDAY=" ++ String.fromInt (Date.day start)

        extra =
            case freqValue of
                Just "WEEKLY" ->
                    if has "BYDAY" then
                        []

                    else
                        [ "BYDAY=" ++ dayCode (Date.weekday start) ]

                Just "MONTHLY" ->
                    if hasDay then
                        []

                    else
                        [ day ]

                Just "YEARLY" ->
                    if hasDay then
                        []

                    else if has "BYMONTH" then
                        [ day ]

                    else
                        [ "BYMONTH=" ++ String.fromInt (Date.month start), day ]

                _ ->
                    []
    in
    if List.isEmpty extra || String.contains "\n" trimmed then
        text

    else
        String.join ";" (given ++ extra)


{-| Reads the value of an RRULE. See the module documentation for what is
accepted; everything else is a `Problem`.
-}
fromText : String -> Result Problem Spec
fromText text =
    oneLine text
        |> Result.andThen parts
        |> Result.andThen build


oneLine : String -> Result Problem String
oneLine text =
    case List.filter (\line -> line /= "") (List.map String.trim (String.lines text)) of
        [] ->
            Err EmptyText

        [ line ] ->
            let
                value =
                    if String.toUpper (String.left 6 line) == "RRULE:" then
                        String.trim (String.dropLeft 6 line)

                    else
                        line
            in
            case List.filter (\name -> String.startsWith name (String.toUpper value)) [ "DTSTART", "DTEND", "EXDATE", "RDATE", "EXRULE" ] of
                name :: _ ->
                    Err (Unsupported name OutsideRule)

                [] ->
                    if value == "" then
                        Err EmptyText

                    else
                        Ok value

        _ ->
            Err (Unsupported "" SeveralLines)


knownParts : List String
knownParts =
    [ "FREQ", "INTERVAL", "COUNT", "UNTIL", "BYDAY", "BYMONTHDAY", "BYMONTH", "BYSETPOS", "WKST" ]


parts : String -> Result Problem (Dict String String)
parts value =
    String.split ";" value
        |> List.map String.trim
        |> List.filter (\part -> part /= "")
        |> List.foldl addPart (Ok Dict.empty)


addPart : String -> Result Problem (Dict String String) -> Result Problem (Dict String String)
addPart part result =
    result
        |> Result.andThen
            (\found ->
                case String.split "=" part of
                    [ rawKey, rawValue ] ->
                        let
                            key =
                                String.toUpper (String.trim rawKey)

                            content =
                                String.trim rawValue
                        in
                        if key == "" || content == "" then
                            Err (CannotRead part)

                        else if not (List.member key knownParts) then
                            Err (Unsupported key Plain)

                        else if Dict.member key found then
                            Err (RepeatedPart key)

                        else
                            Ok (Dict.insert key content found)

                    _ ->
                        Err (CannotRead part)
            )


build : Dict String String -> Result Problem Spec
build found =
    Result.map3
        (\freq every end -> { freq = freq, every = every, end = end })
        (frequencyOf found)
        (intervalOf found)
        (endOf found)
        |> Result.andThen
            (\common ->
                patternOf common.freq common.every found
                    |> Result.andThen
                        (\pattern ->
                            Spec.make
                                { every = common.every
                                , pattern = pattern
                                , end = common.end
                                , except = []
                                }
                        )
            )


type Frequency
    = FDaily
    | FWeekly
    | FMonthly
    | FYearly


frequencyOf : Dict String String -> Result Problem Frequency
frequencyOf found =
    case Dict.get "FREQ" found of
        Nothing ->
            Err (MissingPart "FREQ")

        Just raw ->
            case String.toUpper raw of
                "DAILY" ->
                    Ok FDaily

                "WEEKLY" ->
                    Ok FWeekly

                "MONTHLY" ->
                    Ok FMonthly

                "YEARLY" ->
                    Ok FYearly

                other ->
                    if List.member other [ "SECONDLY", "MINUTELY", "HOURLY" ] then
                        Err (Unsupported ("FREQ=" ++ other) Plain)

                    else
                        Err (CannotRead ("FREQ=" ++ raw))


intervalOf : Dict String String -> Result Problem Int
intervalOf found =
    case Dict.get "INTERVAL" found of
        Nothing ->
            Ok 1

        Just raw ->
            case digits raw of
                Just n ->
                    if n < 1 then
                        Err (IntervalTooSmall n)

                    else
                        Ok n

                Nothing ->
                    Err (CannotRead ("INTERVAL=" ++ raw))


endOf : Dict String String -> Result Problem End
endOf found =
    case ( Dict.get "COUNT" found, Dict.get "UNTIL" found ) of
        ( Just _, Just _ ) ->
            Err (Conflict "COUNT and UNTIL")

        ( Just raw, Nothing ) ->
            case digits raw of
                Just n ->
                    if n < 1 then
                        Err (CountTooSmall n)

                    else
                        Ok (After n)

                Nothing ->
                    Err (CannotRead ("COUNT=" ++ raw))

        ( Nothing, Just raw ) ->
            untilDate raw

        ( Nothing, Nothing ) ->
            Ok Never


untilDate : String -> Result Problem End
untilDate raw =
    if String.length raw > 8 && String.all (\c -> Char.isDigit c || c == 'T' || c == 'Z' || c == 't' || c == 'z') raw then
        Err (Unsupported ("UNTIL=" ++ raw) UntilWithTime)

    else if String.length raw == 8 && String.all Char.isDigit raw then
        case
            Maybe.map3 Date.fromParts
                (String.toInt (String.left 4 raw))
                (String.toInt (String.slice 4 6 raw))
                (String.toInt (String.dropLeft 6 raw))
                |> Maybe.andThen identity
        of
            Just date ->
                Ok (Until date)

            Nothing ->
                Err (CannotRead ("UNTIL=" ++ raw))

    else
        Err (CannotRead ("UNTIL=" ++ raw))


patternOf : Frequency -> Int -> Dict String String -> Result Problem Pattern
patternOf freq every found =
    let
        byDay =
            Dict.get "BYDAY" found

        byMonthDay =
            Dict.get "BYMONTHDAY" found

        byMonth =
            Dict.get "BYMONTH" found

        bySetPos =
            Dict.get "BYSETPOS" found

        wkst =
            Dict.get "WKST" found
    in
    wkstProblem freq every wkst
        |> Result.andThen
            (\_ ->
                case freq of
                    FDaily ->
                        noParts "FREQ=DAILY" [ ( "BYMONTHDAY", byMonthDay ), ( "BYMONTH", byMonth ), ( "BYSETPOS", bySetPos ) ]
                            |> Result.andThen (\_ -> dailyPattern every byDay)

                    FWeekly ->
                        noParts "FREQ=WEEKLY" [ ( "BYMONTHDAY", byMonthDay ), ( "BYMONTH", byMonth ), ( "BYSETPOS", bySetPos ) ]
                            |> Result.andThen (\_ -> weeklyPattern "FREQ=WEEKLY" byDay)

                    FMonthly ->
                        noParts "FREQ=MONTHLY" [ ( "BYMONTH", byMonth ) ]
                            |> Result.andThen (\_ -> monthlyPattern byDay byMonthDay bySetPos)

                    FYearly ->
                        yearlyPattern byMonth byDay byMonthDay bySetPos
            )


{-| WKST only changes the dates of a weekly rule that repeats every second week
or less often, so it is ignored when it cannot matter and refused when it can,
unless it is Monday, which is the week this library counts in.
-}
wkstProblem : Frequency -> Int -> Maybe String -> Result Problem ()
wkstProblem freq every wkst =
    case wkst of
        Nothing ->
            Ok ()

        Just raw ->
            let
                day =
                    String.toUpper raw
            in
            if not (List.member day [ "MO", "TU", "WE", "TH", "FR", "SA", "SU" ]) then
                Err (CannotRead ("WKST=" ++ raw))

            else if day /= "MO" && freq == FWeekly && every > 1 then
                Err (Unsupported ("WKST=" ++ day) WeekStartWithInterval)

            else
                Ok ()


noParts : String -> List ( String, Maybe String ) -> Result Problem ()
noParts context checks =
    case List.filter (\( _, value ) -> value /= Nothing) checks of
        ( key, _ ) :: _ ->
            Err (Unsupported key (With context))

        [] ->
            Ok ()


{-| `FREQ=DAILY` is every day. With `BYDAY` and no interval it is "every day
that is one of these weekdays", which is the same as a weekly rule on them
(Google writes "every weekday" this way), so that is what it is read as. With an
interval above 1 it would be "every n-th day, but only if it is one of these",
which a weekly rule cannot say.
-}
dailyPattern : Int -> Maybe String -> Result Problem Pattern
dailyPattern every byDay =
    case byDay of
        Nothing ->
            Ok Daily

        Just raw ->
            if every > 1 then
                Err (Unsupported "BYDAY" DaysWithDailyInterval)

            else
                weeklyPattern "FREQ=DAILY" (Just raw)


weeklyPattern : String -> Maybe String -> Result Problem Pattern
weeklyPattern context byDay =
    case byDay of
        Nothing ->
            Err (MissingPart "BYDAY")

        Just raw ->
            dayTokens raw
                |> Result.andThen
                    (\tokens ->
                        case List.filter (\( ordinal, _, _ ) -> ordinal /= Nothing) tokens of
                            ( _, _, text ) :: _ ->
                                Err (Unsupported ("BYDAY=" ++ text) (With context))

                            [] ->
                                Ok (Weekly (List.map (\( _, weekday, _ ) -> weekday) tokens))
                    )


monthlyPattern : Maybe String -> Maybe String -> Maybe String -> Result Problem Pattern
monthlyPattern byDay byMonthDay bySetPos =
    case ( byDay, byMonthDay ) of
        ( Just _, Just _ ) ->
            Err (Unsupported "BYMONTHDAY" (With "BYDAY"))

        ( Nothing, Nothing ) ->
            Err (MissingPart "BYMONTHDAY or BYDAY")

        ( Just raw, Nothing ) ->
            nthWeekdayOf "FREQ=MONTHLY" bySetPos raw
                |> Result.map (\( ordinal, weekday ) -> MonthlyWeekday ordinal weekday)

        ( Nothing, Just raw ) ->
            monthDayOf bySetPos raw
                |> Result.map (\( day, missing ) -> MonthlyDay day missing)


yearlyPattern : Maybe String -> Maybe String -> Maybe String -> Maybe String -> Result Problem Pattern
yearlyPattern byMonth byDay byMonthDay bySetPos =
    case byMonth of
        Nothing ->
            Err (MissingPart "BYMONTH")

        Just rawMonth ->
            monthOf rawMonth
                |> Result.andThen
                    (\month ->
                        case ( byDay, byMonthDay ) of
                            ( Just _, Just _ ) ->
                                Err (Unsupported "BYMONTHDAY" (With "BYDAY"))

                            ( Nothing, Nothing ) ->
                                Err (MissingPart "BYMONTHDAY or BYDAY")

                            ( Just raw, Nothing ) ->
                                nthWeekdayOf "FREQ=YEARLY" bySetPos raw
                                    |> Result.map (\( ordinal, weekday ) -> YearlyWeekday ordinal weekday month)

                            ( Nothing, Just raw ) ->
                                monthDayOf bySetPos raw
                                    |> Result.andThen
                                        (\( day, missing ) -> Ok (yearlyDay month day missing))
                    )


{-| The date of a yearly rule. "The last day of the month" (`BYMONTHDAY=-1`, or
the `BYSETPOS=-1` form of it) is the same date every year, except in February: the
last day of a month that is always as long as it is, and 29 February in a leap year
and 28 February otherwise, which is what the missing-day choice of the rule says.
-}
yearlyDay : Int -> Int -> Missing -> Pattern
yearlyDay month day missing =
    case missing of
        Skip ->
            YearlyDate month day Skip

        UseLastDay ->
            if month == 2 then
                YearlyDate 2 29 UseLastDay

            else
                YearlyDate month (min day (Date.daysInMonth 2001 month)) Skip


monthOf : String -> Result Problem Int
monthOf raw =
    case signed raw of
        Just n ->
            if n >= 1 && n <= 12 then
                Ok n

            else
                Err (MonthOutOfRange n)

        Nothing ->
            if String.contains "," raw && List.all (\token -> signed token /= Nothing) (String.split "," raw) then
                Err (Unsupported "BYMONTH" SeveralMonths)

            else
                Err (CannotRead ("BYMONTH=" ++ raw))


{-| The day of the month of `BYMONTHDAY`, and what to do in a month without it.
-}
monthDayOf : Maybe String -> String -> Result Problem ( Int, Missing )
monthDayOf bySetPos raw =
    let
        tokens =
            String.split "," raw |> List.map String.trim

        numbers =
            List.filterMap signed tokens
    in
    if List.length numbers /= List.length tokens then
        Err (CannotRead ("BYMONTHDAY=" ++ raw))

    else
        case ( numbers, bySetPos ) of
            ( [ day ], Nothing ) ->
                if day == -1 then
                    Ok ( 31, UseLastDay )

                else if day < 0 then
                    Err (Unsupported ("BYMONTHDAY=" ++ String.fromInt day) Plain)

                else if day < 1 || day > 31 then
                    Err (DayOutOfRange day)

                else
                    Ok ( day, Skip )

            ( _, Nothing ) ->
                Err (Unsupported "BYMONTHDAY" SeveralDays)

            ( _, Just position ) ->
                let
                    sorted =
                        List.sort numbers

                    last =
                        List.maximum sorted |> Maybe.withDefault 0
                in
                if String.trim position /= "-1" then
                    Err (Unsupported ("BYSETPOS=" ++ position) Plain)

                else if last >= 29 && last <= 31 && sorted == List.range 28 last then
                    Ok ( last, UseLastDay )

                else
                    Err (Unsupported ("BYMONTHDAY=" ++ raw) LastFromDay28)


{-| The single `2TU` of a monthly or yearly `BYDAY`.
-}
nthWeekdayOf : String -> Maybe String -> String -> Result Problem ( Ordinal, Int )
nthWeekdayOf context bySetPos raw =
    case bySetPos of
        Just position ->
            Err (Unsupported ("BYSETPOS=" ++ position) (With "BYDAY"))

        Nothing ->
            dayTokens raw
                |> Result.andThen
                    (\tokens ->
                        case tokens of
                            [ ( Just ordinal, weekday, _ ) ] ->
                                Ok ( ordinal, weekday )

                            [ ( Nothing, _, text ) ] ->
                                Err (Unsupported ("BYDAY=" ++ text) (EveryWeekdayOf context ("2" ++ String.right 2 text)))

                            _ ->
                                Err (Unsupported "BYDAY" (SeveralDaysWith context))
                    )


{-| The tokens of a `BYDAY`: the ordinal if there is one, the ISO weekday and
the text of the token.
-}
dayTokens : String -> Result Problem (List ( Maybe Ordinal, Int, String ))
dayTokens raw =
    String.split "," raw
        |> List.map String.trim
        |> List.foldr
            (\token result ->
                Result.map2 (::) (dayToken token) result
            )
            (Ok [])


dayToken : String -> Result Problem ( Maybe Ordinal, Int, String )
dayToken token =
    let
        upper =
            String.toUpper token

        prefix =
            String.dropRight 2 upper
    in
    case weekdayOfCode (String.right 2 upper) of
        Nothing ->
            Err (CannotRead ("BYDAY=" ++ token))

        Just weekday ->
            if prefix == "" then
                Ok ( Nothing, weekday, upper )

            else
                case signed prefix of
                    Just 1 ->
                        Ok ( Just First, weekday, upper )

                    Just 2 ->
                        Ok ( Just Second, weekday, upper )

                    Just 3 ->
                        Ok ( Just Third, weekday, upper )

                    Just 4 ->
                        Ok ( Just Fourth, weekday, upper )

                    Just n ->
                        if n == -1 then
                            Ok ( Just Last, weekday, upper )

                        else if n == 0 || abs n > 53 then
                            Err (CannotRead ("BYDAY=" ++ token))

                        else
                            Err (Unsupported ("BYDAY=" ++ upper) OrdinalBeyondFourth)

                    Nothing ->
                        Err (CannotRead ("BYDAY=" ++ token))


weekdayOfCode : String -> Maybe Int
weekdayOfCode code =
    case code of
        "MO" ->
            Just 1

        "TU" ->
            Just 2

        "WE" ->
            Just 3

        "TH" ->
            Just 4

        "FR" ->
            Just 5

        "SA" ->
            Just 6

        "SU" ->
            Just 7

        _ ->
            Nothing



-- NUMBERS


{-| A whole number written with digits only. `String.toInt` is not exact for a
number of more than about fifteen digits, so a longer one is read as a number
that is certainly too large (and a rule says so), not as a different number.
-}
digits : String -> Maybe Int
digits raw =
    if raw /= "" && String.all Char.isDigit raw then
        if String.length (dropZeros raw) > 12 then
            Just 999999999999

        else
            String.toInt raw

    else
        Nothing


dropZeros : String -> String
dropZeros raw =
    if String.startsWith "0" raw && String.length raw > 1 then
        dropZeros (String.dropLeft 1 raw)

    else
        raw


{-| A whole number with an optional sign, as RFC 5545 writes them.
-}
signed : String -> Maybe Int
signed raw =
    case String.uncons raw of
        Just ( '-', rest ) ->
            digits rest |> Maybe.map negate

        Just ( '+', rest ) ->
            digits rest

        _ ->
            digits raw
