module Klar.Calendar.Parse exposing
    ( Problem(..)
    , Rules
    , Time
    , TimeProblem(..)
    , TimeRules
    , check
    , date
    , formatTime
    , fromMinutes
    , isComplete
    , message
    , time
    , timeMessage
    , toMinutes
    )

{-| Parsing and validating typed dates and times for the pickers.

Accepted dates, with `today` known:

    20.1 . 2026 20 / 10 / 2026 20 - 10 - 2026 2026 - 10 - 20

    20102026 201026 20.1 . 26 20.1 2010

    t i dag + 3 -7

Two-digit years are resolved against the bounds and `today` (a field with
`max = today`, such as an invoice date, reads `01.01.30` as 1930 in 2026).

Not meant for application code.

-}

import Klar.Calendar.Util as Util
import Klar.Date as Date exposing (Date)
import Klar.Format as Format
import Klar.Locale as Locale exposing (Locale)



-- DATES


{-| What a picker knows about the field when it validates typed text.
-}
type alias Rules =
    { locale : Locale
    , today : Maybe Date
    , min : Maybe Date
    , max : Maybe Date
    , isDisabled : Date -> Bool
    }


type Problem
    = Unparseable
    | TooEarly Date
    | TooLate Date
    | Unavailable
    | RangeOrder
    | RangeTooLong Int


{-| Blank text is `Ok Nothing`. Anything else is a date inside the rules or a
`Problem`.
-}
date : Rules -> String -> Result Problem (Maybe Date)
date rules raw =
    if String.isEmpty (String.trim raw) then
        Ok Nothing

    else
        case syntax rules raw of
            Nothing ->
                Err Unparseable

            Just parsed ->
                check rules parsed
                    |> Result.map Just


{-| Is a date allowed by the rules?
-}
check : Rules -> Date -> Result Problem Date
check rules value =
    case ( rules.min, rules.max ) of
        ( Just lower, _ ) ->
            if Util.before value lower then
                Err (TooEarly lower)

            else
                validateUpper rules value

        _ ->
            validateUpper rules value


validateUpper : Rules -> Date -> Result Problem Date
validateUpper rules value =
    case rules.max of
        Just upper ->
            if Util.after value upper then
                Err (TooLate upper)

            else
                validateDisabled rules value

        Nothing ->
            validateDisabled rules value


validateDisabled : Rules -> Date -> Result Problem Date
validateDisabled rules value =
    if rules.isDisabled value then
        Err Unavailable

    else
        Ok value


{-| True when the text has a day, month and a four digit year, so a picker can
accept it while the user is still in the field: `20.10.2026` and `1.2.2026`
(a day and a month of one or two digits, then the year), or `2026-10-20` (the
year, then a month and a day of two digits each, since a day of one digit may
still get its second digit).
-}
isComplete : String -> Bool
isComplete raw =
    let
        text =
            String.trim raw
    in
    if text == "" || not (String.all isDateChar text) then
        False

    else
        case segments text of
            [ a, b, c ] ->
                (oneOrTwo a && oneOrTwo b && String.length c == 4)
                    || (String.length a == 4 && String.length b == 2 && String.length c == 2)

            _ ->
                False


syntax : Rules -> String -> Maybe Date
syntax rules raw =
    let
        text =
            raw |> String.trim |> String.toLower
    in
    case relative rules.today text of
        Just resolved ->
            Just resolved

        Nothing ->
            numeric rules text


relative : Maybe Date -> String -> Maybe Date
relative maybeToday text =
    case maybeToday of
        Nothing ->
            Nothing

        Just today ->
            if List.member text [ "t", "i dag", "idag", "today" ] then
                Just today

            else if String.startsWith "+" text || String.startsWith "-" text then
                String.toInt text
                    |> Maybe.andThen
                        (\n ->
                            if abs n <= 36500 then
                                Just (Date.addDays n today)

                            else
                                Nothing
                        )

            else
                Nothing


isDateChar : Char -> Bool
isDateChar c =
    Char.isDigit c || c == '.' || c == '/' || c == '-' || c == ' ' || c == ','


{-| The digit groups of a text, split on any run of separators.
-}
segments : String -> List String
segments text =
    let
        step c ( current, done ) =
            if Char.isDigit c then
                ( String.cons c current, done )

            else if current == "" then
                ( current, done )

            else
                ( "", current :: done )

        ( last, groups ) =
            String.foldr step ( "", [] ) text
    in
    if last == "" then
        groups

    else
        last :: groups


numeric : Rules -> String -> Maybe Date
numeric rules text =
    if text == "" || not (String.all isDateChar text) then
        Nothing

    else if String.all Char.isDigit text then
        compact rules text

    else
        case segments text of
            [ a, b ] ->
                dayMonth rules a b

            [ a, b, c ] ->
                threeParts rules a b c

            _ ->
                Nothing


oneOrTwo : String -> Bool
oneOrTwo part =
    String.length part == 1 || String.length part == 2


plausibleYear : Int -> Bool
plausibleYear year =
    year >= 1000 && year <= 2999


dayMonth : Rules -> String -> String -> Maybe Date
dayMonth rules a b =
    case ( rules.today, oneOrTwo a && oneOrTwo b ) of
        ( Just today, True ) ->
            Maybe.andThen identity
                (Maybe.map2 (\day month -> Date.fromParts (Date.year today) month day) (String.toInt a) (String.toInt b))

        _ ->
            Nothing


threeParts : Rules -> String -> String -> String -> Maybe Date
threeParts rules a b c =
    if String.length a == 4 && oneOrTwo b && oneOrTwo c then
        Maybe.andThen identity
            (Maybe.map3 (\year month day -> yearFirst year month day) (String.toInt a) (String.toInt b) (String.toInt c))

    else if oneOrTwo a && oneOrTwo b then
        case ( String.toInt a, String.toInt b, String.length c ) of
            ( Just day, Just month, 4 ) ->
                String.toInt c |> Maybe.andThen (\year -> yearFirst year month day)

            ( Just day, Just month, 2 ) ->
                String.toInt c |> Maybe.andThen (\short -> shortYear rules short month day)

            _ ->
                Nothing

    else
        Nothing


yearFirst : Int -> Int -> Int -> Maybe Date
yearFirst year month day =
    if plausibleYear year then
        Date.fromParts year month day

    else
        Nothing


{-| Digits only: `20102026`, `20262010`, `201026` or `2010`.
-}
compact : Rules -> String -> Maybe Date
compact rules digits =
    let
        part from to =
            String.slice from to digits |> String.toInt

        dayFirst8 =
            Maybe.map3 (\day month year -> yearFirst year month day) (part 0 2) (part 2 4) (part 4 8)
                |> Maybe.andThen identity

        yearFirst8 =
            Maybe.map3 (\year month day -> yearFirst year month day) (part 0 4) (part 4 6) (part 6 8)
                |> Maybe.andThen identity
    in
    case String.length digits of
        8 ->
            let
                ( preferred, fallback ) =
                    Locale.pick rules.locale
                        { nb = ( dayFirst8, yearFirst8 )
                        , en = ( yearFirst8, dayFirst8 )
                        }
            in
            case preferred of
                Just found ->
                    Just found

                Nothing ->
                    fallback

        6 ->
            case Locale.pick rules.locale { nb = ( part 0 2, part 2 4, part 4 6 ), en = ( part 4 6, part 2 4, part 0 2 ) } of
                ( Just day, Just month, Just short ) ->
                    shortYear rules short month day

                _ ->
                    Nothing

        4 ->
            case ( rules.today, part 0 2, part 2 4 ) of
                ( Just today, Just day, Just month ) ->
                    Date.fromParts (Date.year today) month day

                _ ->
                    Nothing

        _ ->
            Nothing


{-| Picks the century for `20.10.26`: the reading inside the bounds wins, else
the one within ten years ahead of today (or 20xx up to 49 without a today).
-}
shortYear : Rules -> Int -> Int -> Int -> Maybe Date
shortYear rules short month day =
    let
        ( century, pivot ) =
            case rules.today of
                Just today ->
                    ( Date.year today // 100 * 100, modBy 100 (Date.year today) + 10 )

                Nothing ->
                    ( 2000, 49 )

        recent =
            Date.fromParts (century + short) month day

        older =
            Date.fromParts (century - 100 + short) month day

        ( preferred, alternative ) =
            if short <= pivot then
                ( recent, older )

            else
                ( older, recent )

        inBounds candidate =
            not (Maybe.map (Util.before candidate) rules.min |> Maybe.withDefault False)
                && not (Maybe.map (Util.after candidate) rules.max |> Maybe.withDefault False)
    in
    case ( preferred, alternative ) of
        ( Just first, Just second ) ->
            if inBounds first then
                Just first

            else if inBounds second then
                Just second

            else
                Just first

        ( Just first, Nothing ) ->
            Just first

        ( Nothing, other ) ->
            other



-- MESSAGES


{-| The error text for a problem, in the field's language.
-}
message : Locale -> Problem -> String
message locale problem =
    case problem of
        Unparseable ->
            Locale.pick locale { nb = "Ugyldig dato", en = "Invalid date" }

        TooEarly bound ->
            Locale.pick locale
                { nb = "Datoen kan ikke være før " ++ Format.date locale bound
                , en = "The date cannot be before " ++ Format.date locale bound
                }

        TooLate bound ->
            Locale.pick locale
                { nb = "Datoen kan ikke være etter " ++ Format.date locale bound
                , en = "The date cannot be after " ++ Format.date locale bound
                }

        Unavailable ->
            Locale.pick locale { nb = "Datoen er ikke tilgjengelig", en = "The date is not available" }

        RangeOrder ->
            Locale.pick locale
                { nb = "Fra-datoen kan ikke være etter til-datoen"
                , en = "The start date cannot be after the end date"
                }

        RangeTooLong days ->
            Locale.pick locale
                { nb = "Perioden kan ikke være lengre enn " ++ String.fromInt days ++ " dager"
                , en = "The period cannot be longer than " ++ String.fromInt days ++ " days"
                }



-- TIMES


type alias Time =
    { hour : Int
    , minute : Int
    }


type alias TimeRules =
    { min : Maybe Time
    , max : Maybe Time
    }


type TimeProblem
    = TimeUnparseable
    | TimeTooEarly Time
    | TimeTooLate Time


toMinutes : Time -> Int
toMinutes value =
    value.hour * 60 + value.minute


{-| Minutes since midnight, wrapped into one day.
-}
fromMinutes : Int -> Time
fromMinutes total =
    let
        wrapped =
            modBy 1440 total
    in
    { hour = wrapped // 60, minute = modBy 60 wrapped }


{-| 08:05
-}
formatTime : Time -> String
formatTime value =
    pad2 value.hour ++ ":" ++ pad2 value.minute


pad2 : Int -> String
pad2 n =
    String.padLeft 2 '0' (String.fromInt n)


{-| Accepts `14:30`, `14.30`, `1430`, `930`, `9:5`, `14` and `kl 14:30`.
-}
time : TimeRules -> String -> Result TimeProblem (Maybe Time)
time rules raw =
    if String.isEmpty (String.trim raw) then
        Ok Nothing

    else
        case timeSyntax raw of
            Nothing ->
                Err TimeUnparseable

            Just parsed ->
                if toMinutes parsed < (rules.min |> Maybe.map toMinutes |> Maybe.withDefault 0) then
                    Err (TimeTooEarly (Maybe.withDefault parsed rules.min))

                else if toMinutes parsed > (rules.max |> Maybe.map toMinutes |> Maybe.withDefault 1439) then
                    Err (TimeTooLate (Maybe.withDefault parsed rules.max))

                else
                    Ok (Just parsed)


timeSyntax : String -> Maybe Time
timeSyntax raw =
    let
        text =
            raw
                |> String.trim
                |> String.toLower
                |> String.replace "kl." ""
                |> String.replace "kl" ""
                |> String.trim

        build hour minute =
            if hour >= 0 && hour <= 23 && minute >= 0 && minute <= 59 then
                Just { hour = hour, minute = minute }

            else
                Nothing

        isTimeChar c =
            Char.isDigit c || c == ':' || c == '.' || c == ',' || c == ' '
    in
    if text == "" || not (String.all isTimeChar text) then
        Nothing

    else
        case segments text of
            [ digits ] ->
                if String.contains ":" text || String.contains "." text || String.contains "," text || String.contains " " text then
                    -- a lone group with a separator, like "14:"
                    String.toInt digits |> Maybe.andThen (\hour -> build hour 0)

                else
                    case String.length digits of
                        1 ->
                            String.toInt digits |> Maybe.andThen (\hour -> build hour 0)

                        2 ->
                            String.toInt digits |> Maybe.andThen (\hour -> build hour 0)

                        3 ->
                            Maybe.andThen identity
                                (Maybe.map2 build (String.toInt (String.left 1 digits)) (String.toInt (String.dropLeft 1 digits)))

                        4 ->
                            Maybe.andThen identity
                                (Maybe.map2 build (String.toInt (String.left 2 digits)) (String.toInt (String.dropLeft 2 digits)))

                        _ ->
                            Nothing

            [ hour, minute ] ->
                if oneOrTwo hour && oneOrTwo minute then
                    Maybe.andThen identity (Maybe.map2 build (String.toInt hour) (String.toInt minute))

                else
                    Nothing

            _ ->
                Nothing


timeMessage : Locale -> TimeProblem -> String
timeMessage locale problem =
    case problem of
        TimeUnparseable ->
            Locale.pick locale { nb = "Ugyldig klokkeslett", en = "Invalid time" }

        TimeTooEarly bound ->
            Locale.pick locale
                { nb = "Klokkeslettet kan ikke være før " ++ formatTime bound
                , en = "The time cannot be before " ++ formatTime bound
                }

        TimeTooLate bound ->
            Locale.pick locale
                { nb = "Klokkeslettet kan ikke være etter " ++ formatTime bound
                , en = "The time cannot be after " ++ formatTime bound
                }
