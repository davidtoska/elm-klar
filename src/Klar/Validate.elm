module Klar.Validate exposing
    ( Validator, Error, run, firstError, collect, errorFor
    , required, minLength, maxLength, email, phone, norwegianPhone, integerBetween, matches, oneOf, date, notInFuture
    , all, when, withMessage, custom, customWith
    , parseDate
    )

{-| Pure, composable validators for text values. A validator returns the
problem as a message in the given `Locale`, or `Nothing` when the value is fine.

    import Klar.Locale exposing (Locale(..))
    import Klar.Validate as Validate

    Validate.run Locale.en Validate.email "ada@" -- Just "Invalid email address"

    Validate.firstError Locale.en [ Validate.required, Validate.minLength 3 ] "ab"
    -- Just "Must be at least 3 characters"

Every validator except `required` and `custom` accepts an empty value: a field is
optional unless you add `required`. That keeps "optional, but valid when filled
in" fields simple.

Validate a whole form at once with `collect`, which turns
`( fieldId, validators, value )` triples into the list of problems, one per field,
in the order given:

    Validate.collect model.locale
        [ ( "customer-name", [ Validate.required ], model.name )
        , ( "customer-email", [ Validate.required, Validate.email ], model.email )
        ]

The `field` of an `Error` is the DOM id of the control, so
[`Form.errorSummary`](Klar-Form) can move focus to it.

The messages are built in; use `withMessage` to say it your way. Lengths are
counted the way Elm counts them (`String.length`), in UTF-16 units.


# Running validators

@docs Validator, Error, run, firstError, collect, errorFor


# Checks

@docs required, minLength, maxLength, email, phone, norwegianPhone, integerBetween, matches, oneOf, date, notInFuture


# Combining and customizing

@docs all, when, withMessage, custom, customWith


# Dates as text

@docs parseDate

-}

import Klar.Date as Date exposing (Date)
import Klar.Format as Format
import Klar.Locale as Locale exposing (Locale)



-- TYPES


{-| Something that checks a text value. Build one with the functions below.
-}
type Validator
    = Validator (Locale -> String -> Maybe String)


{-| A problem found in a field: the DOM id of the control (`field`) and what to
tell the user (`message`).
-}
type alias Error =
    { field : String
    , message : String
    }



-- RUNNING


{-| Runs one validator and returns its message, or `Nothing` when the value is
fine.

    Validate.run Locale.en Validate.required "  " -- Just "Required"

-}
run : Locale -> Validator -> String -> Maybe String
run locale (Validator check) value =
    check locale value


{-| Runs a list of validators in order and returns the first problem.

    Validate.firstError Locale.en [ Validate.required, Validate.email ] ""
    -- Just "Required"

-}
firstError : Locale -> List Validator -> String -> Maybe String
firstError locale validators value =
    case validators of
        [] ->
            Nothing

        (Validator check) :: rest ->
            case check locale value of
                Just message ->
                    Just message

                Nothing ->
                    firstError locale rest value


{-| Validates several fields. Returns at most one `Error` per field (the first
problem), in the order the fields were given.
-}
collect : Locale -> List ( String, List Validator, String ) -> List Error
collect locale fields =
    List.filterMap
        (\( field, validators, value ) ->
            firstError locale validators value
                |> Maybe.map (\message -> { field = field, message = message })
        )
        fields


{-| The message for one field, if it has a problem. Use it to show the error
under the field.

    Validate.errorFor "customer-email" errors -- Maybe String

-}
errorFor : String -> List Error -> Maybe String
errorFor field errors =
    errors
        |> List.filter (\error -> error.field == field)
        |> List.head
        |> Maybe.map .message



-- COMBINATORS


{-| Several validators as one; the first problem wins.

    Validate.all [ Validate.required, Validate.maxLength 40 ]

-}
all : List Validator -> Validator
all validators =
    Validator (\locale value -> firstError locale validators value)


{-| Only checks when the condition holds, like a phone number that is only
required when SMS notifications are switched on.

    Validate.when model.smsNotifications Validate.required

-}
when : Bool -> Validator -> Validator
when condition validator =
    if condition then
        validator

    else
        Validator (\_ _ -> Nothing)


{-| Replaces the message of a validator, in both languages.

    Validate.required |> Validate.withMessage { nb = "Oppgi navn", en = "Enter a name" }

-}
withMessage : { nb : String, en : String } -> Validator -> Validator
withMessage texts (Validator check) =
    Validator
        (\locale value ->
            check locale value
                |> Maybe.map (\_ -> Locale.pick locale texts)
        )


{-| A validator from a yes/no test and a message in both languages. The test
sees the value as typed, also when it is empty.

    Validate.custom (String.startsWith "ORD-") { nb = "Må starte med ORD-", en = "Must start with ORD-" }

-}
custom : (String -> Bool) -> { nb : String, en : String } -> Validator
custom isValid texts =
    Validator
        (\locale value ->
            if isValid value then
                Nothing

            else
                Just (Locale.pick locale texts)
        )


{-| A validator that builds its own message, for messages that depend on the
value or on the language in ways `custom` cannot say.
-}
customWith : (Locale -> String -> Maybe String) -> Validator
customWith =
    Validator



-- VALIDATORS


{-| The value must not be empty. Spaces only count as empty.
-}
required : Validator
required =
    Validator
        (\locale value ->
            if isBlank value then
                Just (Locale.pick locale { nb = "Må fylles ut", en = "Required" })

            else
                Nothing
        )


{-| At least this many characters.
-}
minLength : Int -> Validator
minLength n =
    optional
        (\locale value ->
            if String.length value < n then
                Just
                    (Locale.pick locale
                        { nb = "Må være minst " ++ String.fromInt n ++ " tegn"
                        , en = "Must be at least " ++ String.fromInt n ++ " characters"
                        }
                    )

            else
                Nothing
        )


{-| At most this many characters.
-}
maxLength : Int -> Validator
maxLength n =
    optional
        (\locale value ->
            if String.length value > n then
                Just
                    (Locale.pick locale
                        { nb = "Kan ikke være lengre enn " ++ String.fromInt n ++ " tegn"
                        , en = "Must be at most " ++ String.fromInt n ++ " characters"
                        }
                    )

            else
                Nothing
        )


{-| A plausible email address: one `@`, a local part, and a domain with at least
one dot. It cannot know whether the mailbox exists.
-}
email : Validator
email =
    optional
        (\locale value ->
            if isEmail (String.trim value) then
                Nothing

            else
                Just (Locale.pick locale { nb = "Ugyldig e-postadresse", en = "Invalid email address" })
        )


{-| A phone number written for people: an optional `+`, then 7 to 15 digits.
Spaces, dashes, dots and parentheses are fine anywhere. It checks the shape, not
whether the number exists.

    Validate.run Locale.en Validate.phone "+44 20 7946 0958" -- Nothing

-}
phone : Validator
phone =
    optional
        (\locale value ->
            if isPhone value then
                Nothing

            else
                Just (Locale.pick locale { nb = "Ugyldig telefonnummer", en = "Invalid phone number" })
        )


{-| A Norwegian phone number: 8 digits. Spaces and dashes are fine, and so is a
`+47` or `0047` prefix.
-}
norwegianPhone : Validator
norwegianPhone =
    optional
        (\locale value ->
            case norwegianDigits value of
                Just _ ->
                    Nothing

                Nothing ->
                    Just (Locale.pick locale { nb = "Telefonnummer må ha 8 siffer", en = "Phone number must have 8 digits" })
        )


{-| A whole number from `low` to `high`, both included.

    Validate.integerBetween 1 99

-}
integerBetween : Int -> Int -> Validator
integerBetween low high =
    optional
        (\locale value ->
            case String.toInt (String.trim value) of
                Just n ->
                    if n >= low && n <= high then
                        Nothing

                    else
                        Just (integerMessage locale low high)

                Nothing ->
                    Just (integerMessage locale low high)
        )


integerMessage : Locale -> Int -> Int -> String
integerMessage locale low high =
    Locale.pick locale
        { nb = "Må være et heltall mellom " ++ String.fromInt low ++ " og " ++ String.fromInt high
        , en = "Must be a whole number between " ++ String.fromInt low ++ " and " ++ String.fromInt high
        }


{-| The value must equal another value, like "repeat password".

    Validate.matches model.password

-}
matches : String -> Validator
matches other =
    optional
        (\locale value ->
            if value == other then
                Nothing

            else
                Just (Locale.pick locale { nb = "Verdiene må være like", en = "The values must match" })
        )


{-| The value must be one of these.

    Validate.oneOf [ "open", "paid", "void" ]

-}
oneOf : List String -> Validator
oneOf allowed =
    optional
        (\locale value ->
            if List.member value allowed then
                Nothing

            else
                Just (Locale.pick locale { nb = "Ugyldig verdi", en = "Invalid value" })
        )


{-| A calendar date written as `dd.mm.yyyy` or `yyyy-mm-dd`. 31 February is not
a date. The message names the form of the language, as `Klar.Format.date` writes
it: `yyyy-mm-dd` in English and `dd.mm.åååå` in Norwegian. See `parseDate` for
everything that is accepted.
-}
date : Validator
date =
    optional
        (\locale value ->
            case parseDate value of
                Just _ ->
                    Nothing

                Nothing ->
                    Just (Locale.pick locale { nb = "Ugyldig dato (dd.mm.åååå)", en = "Invalid date (yyyy-mm-dd)" })
        )


{-| The date may not be after the given day ("today", from the application).
Text that is not a date passes, so combine it with `date`.

    Validate.all [ Validate.date, Validate.notInFuture model.today ]

-}
notInFuture : Date -> Validator
notInFuture today =
    optional
        (\locale value ->
            case parseDate value of
                Just parsed ->
                    if Date.compare parsed today == GT then
                        Just
                            (Locale.pick locale
                                { nb = "Datoen kan ikke være etter " ++ Format.date locale today
                                , en = "The date cannot be after " ++ Format.date locale today
                                }
                            )

                    else
                        Nothing

                Nothing ->
                    Nothing
        )


{-| Reads `20.10.2026`, `1.2.1990` (day, month, four-digit year, separated by
dots) or `2026-10-20` into a `Date`. Anything else, and every date that does not
exist, is `Nothing`.
-}
parseDate : String -> Maybe Date
parseDate raw =
    let
        text =
            String.trim raw
    in
    case String.split "." text of
        [ day, month, year ] ->
            if List.all isDigits [ day, month, year ] && String.length year == 4 then
                Maybe.map3 Date.fromParts (String.toInt year) (String.toInt month) (String.toInt day)
                    |> Maybe.andThen identity

            else
                Nothing

        _ ->
            Date.fromIso text



-- HELPERS


optional : (Locale -> String -> Maybe String) -> Validator
optional check =
    Validator
        (\locale value ->
            if isBlank value then
                Nothing

            else
                check locale value
        )


isBlank : String -> Bool
isBlank value =
    String.trim value == ""


isDigits : String -> Bool
isDigits text =
    text /= "" && String.all Char.isDigit text


isPhone : String -> Bool
isPhone raw =
    let
        compact =
            String.trim raw
                |> String.filter (\c -> not (List.member c [ ' ', '-', '.', '(', ')', '\u{00A0}' ]))

        digits =
            if String.startsWith "+" compact then
                String.dropLeft 1 compact

            else
                compact
    in
    String.all Char.isDigit digits && String.length digits >= 7 && String.length digits <= 15


norwegianDigits : String -> Maybe String
norwegianDigits raw =
    let
        compact =
            String.trim raw
                |> String.filter (\c -> c /= ' ' && c /= '-' && c /= '.' && c /= '\u{00A0}')

        number =
            if String.startsWith "+47" compact then
                String.dropLeft 3 compact

            else if String.startsWith "0047" compact then
                String.dropLeft 4 compact

            else
                compact
    in
    if String.length number == 8 && String.all Char.isDigit number then
        Just number

    else
        Nothing


isEmail : String -> Bool
isEmail value =
    case String.split "@" value of
        [ local, domain ] ->
            validLocalPart local && validDomain domain

        _ ->
            False


validLocalPart : String -> Bool
validLocalPart local =
    local
        /= ""
        && String.length local
        <= 64
        && String.all localChar local
        && not (String.startsWith "." local)
        && not (String.endsWith "." local)
        && not (String.contains ".." local)


localChar : Char -> Bool
localChar c =
    Char.isAlphaNum c || Char.toCode c > 127 || String.contains (String.fromChar c) ".!#$%&'*+/=?^_`{|}~-"


validDomain : String -> Bool
validDomain domain =
    let
        labels =
            String.split "." domain

        topLevel =
            labels |> List.reverse |> List.head |> Maybe.withDefault ""
    in
    List.length labels
        >= 2
        && List.all validLabel labels
        && String.length topLevel
        >= 2


validLabel : String -> Bool
validLabel label =
    label
        /= ""
        && String.all (\c -> Char.isAlphaNum c || Char.toCode c > 127 || c == '-') label
        && not (String.startsWith "-" label)
        && not (String.endsWith "-" label)
