module Klar.Recurrence.Words exposing (describe, ordinalDay, problemText)

{-| The words of a rule: the description in plain language and the text of a
problem, in English and Norwegian Bokmål.

Weekday and month names come from `Klar.Locale`, dates from `Klar.Format`.

Not meant for application code.

-}

import Klar.Format as Format
import Klar.Locale as Locale exposing (Locale)
import Klar.Recurrence.Spec exposing (End(..), Missing(..), Ordinal(..), Pattern(..), Problem(..), Spec)



-- DESCRIPTION


{-| "Every 2 weeks on Monday and Thursday", "On the last Friday of every month
until 31 December 2027", "Hver andre uke på mandag og torsdag".
-}
describe : Locale -> Spec -> String
describe locale spec =
    String.concat
        [ patternText locale spec.every spec.pattern
        , ending locale spec.end
        , skipped locale (List.length spec.except)
        ]


patternText : Locale -> Int -> Pattern -> String
patternText locale every pattern =
    case pattern of
        Daily ->
            Locale.pick locale
                { nb =
                    if every == 1 then
                        "Hver dag"

                    else
                        "Hver " ++ nbCount every ++ " dag"
                , en =
                    if every == 1 then
                        "Every day"

                    else
                        "Every " ++ String.fromInt every ++ " days"
                }

        Weekly days ->
            weekly locale every days

        MonthlyDay day missing ->
            monthlyDay locale every day missing

        MonthlyWeekday ordinal weekday ->
            let
                phrase =
                    ordinalDay locale ordinal weekday
            in
            Locale.pick locale
                { nb =
                    if every == 1 then
                        "Den " ++ phrase ++ " i hver måned"

                    else
                        "Hver " ++ nbCount every ++ " måned den " ++ phrase
                , en =
                    if every == 1 then
                        "On the " ++ phrase ++ " of every month"

                    else
                        "Every " ++ String.fromInt every ++ " months on the " ++ phrase
                }

        YearlyDate month day missing ->
            yearlyDate locale every month day missing

        YearlyWeekday ordinal weekday month ->
            let
                phrase =
                    ordinalDay locale ordinal weekday

                monthText =
                    Locale.monthName locale month
            in
            Locale.pick locale
                { nb =
                    if every == 1 then
                        "Den " ++ phrase ++ " i " ++ monthText ++ " hvert år"

                    else
                        "Hvert " ++ nbCount every ++ " år den " ++ phrase ++ " i " ++ monthText
                , en =
                    if every == 1 then
                        "On the " ++ phrase ++ " of " ++ monthText ++ " every year"

                    else
                        "Every " ++ String.fromInt every ++ " years on the " ++ phrase ++ " of " ++ monthText
                }


weekly : Locale -> Int -> List Int -> String
weekly locale every days =
    let
        allDays =
            days == List.range 1 7

        weekdays =
            days == List.range 1 5

        names =
            List.map (Locale.weekdayLong locale) days
    in
    Locale.pick locale
        { nb =
            if every == 1 && allDays then
                "Hver dag"

            else if every == 1 && weekdays then
                "Hver ukedag"

            else
                (if every == 1 then
                    "Ukentlig på "

                 else
                    "Hver " ++ nbCount every ++ " uke på "
                )
                    ++ (if allDays then
                            "alle dager"

                        else if weekdays then
                            "ukedager"

                        else
                            joinList "og" names
                       )
        , en =
            if every == 1 && allDays then
                "Every day"

            else if every == 1 && weekdays then
                "Every weekday"

            else
                (if every == 1 then
                    "Weekly on "

                 else
                    "Every " ++ String.fromInt every ++ " weeks on "
                )
                    ++ (if allDays then
                            "all days"

                        else if weekdays then
                            "weekdays"

                        else
                            joinList "and" names
                       )
        }


monthlyDay : Locale -> Int -> Int -> Missing -> String
monthlyDay locale every day missing =
    if day == 31 && missing == UseLastDay then
        Locale.pick locale
            { nb =
                if every == 1 then
                    "Siste dag i hver måned"

                else
                    "Hver " ++ nbCount every ++ " måned på siste dag"
            , en =
                if every == 1 then
                    "On the last day of every month"

                else
                    "Every " ++ String.fromInt every ++ " months on the last day"
            }

    else
        Locale.pick locale
            { nb =
                (if every == 1 then
                    "Månedlig den "

                 else
                    "Hver " ++ nbCount every ++ " måned den "
                )
                    ++ String.fromInt day
                    ++ "."
                    ++ (if day < 29 then
                            ""

                        else if missing == UseLastDay then
                            " (siste dag i kortere måneder)"

                        else
                            " (måneder uten denne dagen hoppes over)"
                       )
            , en =
                (if every == 1 then
                    "Monthly on the "

                 else
                    "Every " ++ String.fromInt every ++ " months on the "
                )
                    ++ enOrdinalNumber day
                    ++ (if day < 29 then
                            ""

                        else if missing == UseLastDay then
                            " (the last day in shorter months)"

                        else
                            " (months without it are skipped)"
                       )
            }


yearlyDate : Locale -> Int -> Int -> Int -> Missing -> String
yearlyDate locale every month day missing =
    let
        leapDay =
            month == 2 && day == 29

        monthText =
            Locale.monthName locale month
    in
    Locale.pick locale
        { nb =
            (if every == 1 then
                "Årlig "

             else
                "Hvert " ++ nbCount every ++ " år "
            )
                ++ String.fromInt day
                ++ ". "
                ++ monthText
                ++ (if not leapDay then
                        ""

                    else if missing == UseLastDay then
                        " (28. februar andre år)"

                    else
                        " (bare skuddår)"
                   )
        , en =
            (if every == 1 then
                "Yearly on "

             else
                "Every " ++ String.fromInt every ++ " years on "
            )
                ++ String.fromInt day
                ++ " "
                ++ monthText
                ++ (if not leapDay then
                        ""

                    else if missing == UseLastDay then
                        " (28 February in other years)"

                    else
                        " (leap years only)"
                   )
        }


ending : Locale -> End -> String
ending locale end =
    case end of
        Never ->
            ""

        After 1 ->
            Locale.pick locale { nb = ", én gang", en = ", once" }

        After n ->
            Locale.pick locale
                { nb = ", " ++ String.fromInt n ++ " ganger"
                , en = ", " ++ String.fromInt n ++ " times"
                }

        Until date ->
            Locale.pick locale
                { nb = " til " ++ Format.dateLong locale date
                , en = " until " ++ Format.dateLong locale date
                }


skipped : Locale -> Int -> String
skipped locale count =
    if count == 0 then
        ""

    else
        Locale.pick locale
            { nb =
                ", unntatt "
                    ++ String.fromInt count
                    ++ (if count == 1 then
                            " dato"

                        else
                            " datoer"
                       )
            , en =
                ", except "
                    ++ String.fromInt count
                    ++ (if count == 1 then
                            " date"

                        else
                            " dates"
                       )
            }



-- PIECES


{-| "second Tuesday" and "siste fredagen" (the Norwegian weekday is in the
definite form).
-}
ordinalDay : Locale -> Ordinal -> Int -> String
ordinalDay locale ordinal weekday =
    Locale.pick locale
        { nb = nbOrdinalWord ordinal ++ " " ++ Locale.weekdayLong locale weekday ++ "en"
        , en = enOrdinalWord ordinal ++ " " ++ Locale.weekdayLong locale weekday
        }


enOrdinalWord : Ordinal -> String
enOrdinalWord ordinal =
    case ordinal of
        First ->
            "first"

        Second ->
            "second"

        Third ->
            "third"

        Fourth ->
            "fourth"

        Last ->
            "last"


nbOrdinalWord : Ordinal -> String
nbOrdinalWord ordinal =
    case ordinal of
        First ->
            "første"

        Second ->
            "andre"

        Third ->
            "tredje"

        Fourth ->
            "fjerde"

        Last ->
            "siste"


{-| "andre", "tredje" ... for the interval of a Norwegian phrase ("Hver andre
uke"), and "13." from there on.
-}
nbCount : Int -> String
nbCount n =
    case n of
        2 ->
            "andre"

        3 ->
            "tredje"

        4 ->
            "fjerde"

        5 ->
            "femte"

        6 ->
            "sjette"

        7 ->
            "sjuende"

        8 ->
            "åttende"

        9 ->
            "niende"

        10 ->
            "tiende"

        11 ->
            "ellevte"

        12 ->
            "tolvte"

        _ ->
            String.fromInt n ++ "."


{-| 1st, 2nd, 3rd, 4th ... 11th, 12th, 13th ... 21st, 22nd, 23rd.
-}
enOrdinalNumber : Int -> String
enOrdinalNumber n =
    String.fromInt n
        ++ (if modBy 100 n >= 11 && modBy 100 n <= 13 then
                "th"

            else
                case modBy 10 n of
                    1 ->
                        "st"

                    2 ->
                        "nd"

                    3 ->
                        "rd"

                    _ ->
                        "th"
           )


{-| "Monday", "Monday and Thursday", "Monday, Wednesday and Friday".
-}
joinList : String -> List String -> String
joinList conjunction items =
    case List.reverse items of
        [] ->
            ""

        [ only ] ->
            only

        last :: before ->
            String.join ", " (List.reverse before) ++ " " ++ conjunction ++ " " ++ last



-- PROBLEMS


{-| What is wrong, in a sentence.
-}
problemText : Locale -> Problem -> String
problemText locale problem =
    case problem of
        IntervalTooSmall n ->
            Locale.pick locale
                { nb = "Hvor ofte den gjentas må være et helt tall på 1 eller mer, ikke " ++ String.fromInt n ++ "."
                , en = "How often it repeats must be a whole number, 1 or more, not " ++ String.fromInt n ++ "."
                }

        CountTooSmall n ->
            Locale.pick locale
                { nb = "Antall ganger må være 1 eller mer, ikke " ++ String.fromInt n ++ "."
                , en = "The number of occurrences must be 1 or more, not " ++ String.fromInt n ++ "."
                }

        DayOutOfRange n ->
            Locale.pick locale
                { nb = "Dagen i måneden må være fra 1 til 31, ikke " ++ String.fromInt n ++ "."
                , en = "The day of the month must be from 1 to 31, not " ++ String.fromInt n ++ "."
                }

        MonthOutOfRange n ->
            Locale.pick locale
                { nb = "Måneden må være fra 1 til 12, ikke " ++ String.fromInt n ++ "."
                , en = "The month must be from 1 to 12, not " ++ String.fromInt n ++ "."
                }

        NoSuchDate month day ->
            Locale.pick locale
                { nb = "Datoen finnes ikke: " ++ String.fromInt day ++ ". " ++ Locale.monthName locale month ++ "."
                , en = "That date does not exist: " ++ String.fromInt day ++ " " ++ Locale.monthName locale month ++ "."
                }

        NoWeekdays ->
            Locale.pick locale
                { nb = "Velg minst én ukedag."
                , en = "Choose at least one weekday."
                }

        EmptyText ->
            Locale.pick locale
                { nb = "Teksten er tom."
                , en = "The text is empty."
                }

        MissingPart name ->
            Locale.pick locale
                { nb =
                    name
                        ++ " mangler."
                        ++ (if name == "FREQ" then
                                ""

                            else
                                " En regel kjenner ikke startdatoen, så den må stå i teksten."
                           )
                , en =
                    name
                        ++ " is missing."
                        ++ (if name == "FREQ" then
                                ""

                            else
                                " A rule does not know its start date, so it has to be in the text."
                           )
                }

        RepeatedPart name ->
            Locale.pick locale
                { nb = name ++ " står mer enn én gang."
                , en = name ++ " appears more than once."
                }

        CannotRead part ->
            Locale.pick locale
                { nb = "Kan ikke lese «" ++ part ++ "»."
                , en = "Cannot read \"" ++ part ++ "\"."
                }

        Unsupported what ->
            Locale.pick locale
                { nb = "Støttes ikke i en gjentakelsesregel: " ++ what ++ "."
                , en = "Not supported in a recurrence rule: " ++ what ++ "."
                }

        Conflict what ->
            Locale.pick locale
                { nb = what ++ " kan ikke brukes sammen."
                , en = what ++ " cannot be used together."
                }
