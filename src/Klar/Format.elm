module Klar.Format exposing
    ( int, decimal, percent, currency, plural
    , bytes, duration
    , date, dateLong, time, dateTime, iso8601, relative
    )

{-| Formatting numbers, sizes, dates and times for people, in the conventions of
a `Locale`.

Use when: the application shows numbers, sizes, dates or times to people.
Do not use when: the text is a machine format (use `iso8601` for a date in data, or the plain value).

    import Klar.Format as Format
    import Klar.Locale exposing (Locale(..))

    Format.int Locale.en 1234567 -- "1,234,567"

    Format.decimal Locale.en 2 1234.5 -- "1,234.50"

    Format.percent Locale.en 1 0.127 -- "12.7%"

    Format.currency Locale.en "$" 2 1234.5 -- "$1,234.50"

    Format.bytes Locale.en 1536000 -- "1.5 MB"

    Format.duration Locale.en 125000 -- "2 min 5 s"

    Format.date Locale.en october20 -- "2026-10-20" (the date 20 October 2026)

    Format.int Locale.nb 1234567 -- "1 234 567" (with non-breaking spaces)

    Format.decimal Locale.nb 2 1234.5 -- "1 234,50"

Numbers are formatted from their shortest decimal text, not by multiplying and
rounding floating point numbers, so what you see is what a person would round
by hand: `Format.decimal Locale.en 2 1.005` is `"1.01"` and `Format.percent Locale.en 0 0.145`
is `"15%"`. Rounding is half away from zero. Negative numbers get a real minus
sign (U+2212), and a number that rounds to zero is never shown as negative.

Numbers and units are separated by non-breaking spaces, so a value never breaks
over two lines.

Text a person reads that depends on the language ("minutes ago", "Jan") comes
in English and Norwegian Bokmål; the rest of the world gets the English text
until more languages are added.


# Numbers

@docs int, decimal, percent, currency, plural


# Sizes and durations

@docs bytes, duration


# Dates and times

@docs date, dateLong, time, dateTime, iso8601, relative

-}

import Klar.Date as Date exposing (Date)
import Klar.Locale as Locale exposing (Locale)
import Klar.Money.Currencies as Currencies
import Time


nbsp : String
nbsp =
    "\u{00A0}"



-- NUMBERS


{-| A whole number with thousands separators: a comma in English, a
non-breaking space in Norwegian.

    Format.int Locale.en 1234567 -- "1,234,567"

    Format.int Locale.en -1000 -- "−1,000"

-}
int : Locale -> Int -> String
int locale n =
    let
        grouped =
            groupThousands (Locale.thousandSeparator locale) (String.fromInt (abs n))
    in
    if n < 0 then
        "−" ++ grouped

    else
        grouped


groupThousands : String -> String -> String
groupThousands separator digits =
    let
        length =
            String.length digits

        chunks =
            List.range 0 ((length - 1) // 3)
                |> List.map
                    (\i ->
                        String.slice (max 0 (length - (i + 1) * 3)) (length - i * 3) digits
                    )
                |> List.reverse
    in
    String.join separator chunks


{-| A number with a fixed count of decimals (0 to 20), rounded half away from
zero.

    Format.decimal Locale.en 2 1234.5 -- "1,234.50"

    Format.decimal Locale.en 0 2.5 -- "3"

    Format.decimal Locale.en 1 -0.04 -- "0.0"

    Format.decimal Locale.nb 2 1234.5 -- "1 234,50"

`NaN` is written `NaN` and the infinities `∞` and `−∞`.

-}
decimal : Locale -> Int -> Float -> String
decimal locale decimals value =
    let
        parts =
            formatParts locale 0 decimals value
    in
    signOf parts ++ parts.text


{-| A ratio as a percentage: `0.127` is 12.7 percent. The decimals are those of
the percentage. The English text has no space before the percent sign, the
Norwegian one a non-breaking space.

    Format.percent Locale.en 0 0.127 -- "13%"

    Format.percent Locale.en 1 0.127 -- "12.7%"

    Format.percent Locale.nb 1 0.127 -- "12,7 %"

-}
percent : Locale -> Int -> Float -> String
percent locale decimals ratio =
    let
        parts =
            formatParts locale 2 decimals ratio

        suffix =
            Locale.pick locale { nb = nbsp ++ "%", en = "%" }
    in
    signOf parts ++ parts.text ++ suffix


{-| An amount of money. The first argument after the locale is what to show for
the currency, a symbol or a code, as you want it written. English puts it in
front of the number, Norwegian after it.

An ISO 4217 code that has a well-known symbol is written with the symbol (`"USD"`
becomes `$`, `"EUR"` `€`, `"NOK"` `kr`; the table is the one `Klar.Money` uses). Any other
text is written as given, and a text that ends in a letter (a code, `"kr"`) is
separated from the number by a non-breaking space, so that it never reads
`USD645.15`.

    Format.currency Locale.en "$" 2 1234.5 -- "$1,234.50"

    Format.currency Locale.en "USD" 2 645.15 -- "$645.15"

    Format.currency Locale.en "CHF" 2 645.15 -- "CHF 645.15" (non-breaking space)

    Format.currency Locale.en "$" 2 -3 -- "−$3.00"

    Format.currency Locale.nb "kr" 2 1234.5 -- "1 234,50 kr"

    Format.currency Locale.nb "NOK" 2 1234.5 -- "1 234,50 kr"

    Format.currency Locale.en "JPY " 0 1500 -- "JPY 1,500"

-}
currency : Locale -> String -> Int -> Float -> String
currency locale mark decimals value =
    let
        parts =
            formatParts locale 0 decimals value

        symbol =
            if isCode mark then
                Currencies.symbolOf mark

            else
                mark

        apart =
            if endsInLetter symbol then
                nbsp

            else
                ""
    in
    Locale.pick locale
        { nb = signOf parts ++ parts.text ++ nbsp ++ symbol
        , en = signOf parts ++ symbol ++ apart ++ parts.text
        }


isCode : String -> Bool
isCode text =
    String.length text == 3 && String.all Char.isUpper text


endsInLetter : String -> Bool
endsInLetter text =
    case String.right 1 text |> String.toList of
        [ c ] ->
            Char.isAlpha c

        _ ->
            False


{-| Chooses the singular or plural form for a count.

    Format.int Locale.en 3 ++ " " ++ Format.plural Locale.en 3 { one = "order", other = "orders" } -- "3 orders"

-}
plural : Locale -> Int -> { one : String, other : String } -> String
plural _ n forms =
    if n == 1 then
        forms.one

    else
        forms.other


type alias Parts =
    { negative : Bool
    , text : String
    }


signOf : Parts -> String
signOf parts =
    if parts.negative then
        "−"

    else
        ""


{-| The digits of a number as text, split at the decimal point, never in
exponent form. Works for every finite number.
-}
type alias Digits =
    { whole : String
    , fraction : String
    }


{-| Writes a number with `places` decimals. `shift` moves the decimal point
first (2 turns a ratio into a percentage) without any floating point
arithmetic.
-}
formatParts : Locale -> Int -> Int -> Float -> Parts
formatParts locale shift decimals value =
    if isNaN value then
        { negative = False, text = "NaN" }

    else if isInfinite value then
        { negative = value < 0, text = "∞" }

    else
        let
            places =
                clamp 0 20 decimals

            rounded =
                roundTo places (digitsOf shift value)

            isZero =
                String.all (\c -> c == '0') (rounded.whole ++ rounded.fraction)

            whole =
                groupThousands (Locale.thousandSeparator locale) rounded.whole
        in
        { negative = value < 0 && not isZero
        , text =
            if places > 0 then
                whole ++ Locale.decimalSeparator locale ++ rounded.fraction

            else
                whole
        }


digitsOf : Int -> Float -> Digits
digitsOf shift value =
    let
        text =
            String.fromFloat (abs value)

        ( mantissa, exponent ) =
            case String.split "e" text of
                [ m, e ] ->
                    ( m, Maybe.withDefault 0 (String.toInt e) )

                _ ->
                    ( text, 0 )

        ( wholePart, fractionPart ) =
            case String.split "." mantissa of
                [ w, f ] ->
                    ( w, f )

                _ ->
                    ( mantissa, "" )

        digits =
            wholePart ++ fractionPart

        point =
            String.length wholePart + exponent + shift
    in
    if point <= 0 then
        { whole = "0", fraction = String.repeat (negate point) "0" ++ digits }

    else if point >= String.length digits then
        { whole = withoutLeadingZeros (digits ++ String.repeat (point - String.length digits) "0")
        , fraction = ""
        }

    else
        { whole = withoutLeadingZeros (String.left point digits)
        , fraction = String.dropLeft point digits
        }


withoutLeadingZeros : String -> String
withoutLeadingZeros digits =
    case String.uncons digits of
        Just ( '0', rest ) ->
            if rest == "" then
                "0"

            else
                withoutLeadingZeros rest

        _ ->
            if digits == "" then
                "0"

            else
                digits


roundTo : Int -> Digits -> Digits
roundTo places digits =
    if String.length digits.fraction <= places then
        { digits | fraction = String.padRight places '0' digits.fraction }

    else
        let
            kept =
                digits.whole ++ String.left places digits.fraction

            nextDigit =
                String.slice places (places + 1) digits.fraction

            rounded =
                if nextDigit >= "5" then
                    incrementDigits kept

                else
                    kept
        in
        { whole = String.dropRight places rounded
        , fraction = String.right places rounded
        }


{-| Adds one to a number written as digits.
-}
incrementDigits : String -> String
incrementDigits digits =
    let
        step c ( carry, out ) =
            if not carry then
                ( False, c :: out )

            else if c == '9' then
                ( True, '0' :: out )

            else
                ( False, Char.fromCode (Char.toCode c + 1) :: out )

        ( overflow, result ) =
            List.foldr step ( True, [] ) (String.toList digits)
    in
    String.fromList
        (if overflow then
            '1' :: result

         else
            result
        )



-- SIZES AND DURATIONS


{-| A size in bytes, with the decimal prefixes (1 kB is 1000 bytes), one decimal
above a kilobyte.

    Format.bytes Locale.en 512 -- "512 B"

    Format.bytes Locale.en 1536000 -- "1.5 MB"

    Format.bytes Locale.nb 2400 -- "2,4 kB"

-}
bytes : Locale -> Int -> String
bytes locale n =
    let
        units =
            [ "B", "kB", "MB", "GB", "TB", "PB" ]

        lastUnit =
            List.length units - 1

        settle value index =
            if index >= lastUnit then
                ( value, index )

            else if index == 0 && value >= 1000 then
                settle (value / 1000) 1

            else if index > 0 && String.length (roundTo 1 (digitsOf 0 value)).whole > 3 then
                settle (value / 1000) (index + 1)

            else
                ( value, index )

        ( scaled, unitIndex ) =
            settle (toFloat (abs n)) 0

        unit =
            units |> List.drop unitIndex |> List.head |> Maybe.withDefault "B"

        sign =
            if n < 0 then
                "−"

            else
                ""
    in
    if unitIndex == 0 then
        sign ++ String.fromInt (abs n) ++ nbsp ++ unit

    else
        sign ++ (formatParts locale 0 1 scaled).text ++ nbsp ++ unit


{-| A length of time in milliseconds, written with the two largest units that
matter.

    Format.duration Locale.en 340 -- "340 ms"

    Format.duration Locale.en 1200 -- "1.2 s"

    Format.duration Locale.en 125000 -- "2 min 5 s"

    Format.duration Locale.en 3720000 -- "1 h 2 min"

    Format.duration Locale.en 200000000 -- "2 d 7 h"

Negative durations are written with a minus sign.

-}
duration : Locale -> Int -> String
duration locale millis =
    let
        absolute =
            abs millis

        -- 59 960 ms is "60.0 s" with one decimal: call it a minute instead
        magnitude =
            if absolute < 60000 && (roundTo 1 (digitsOf 0 (toFloat absolute / 1000))).whole == "60" then
                60000

            else
                absolute

        sign =
            if millis < 0 then
                "−"

            else
                ""

        hourUnit =
            Locale.pick locale { nb = "t", en = "h" }

        -- Float arithmetic: milliseconds do not fit in the 32 bits `//` works with
        total unitMillis =
            floor (toFloat magnitude / unitMillis)

        seconds =
            total 1000

        minutes =
            total 60000

        hours =
            total 3600000

        days =
            total 86400000

        part value unit =
            String.fromInt value ++ nbsp ++ unit

        pair bigValue bigUnit smallValue smallUnit =
            if smallValue == 0 then
                part bigValue bigUnit

            else
                part bigValue bigUnit ++ " " ++ part smallValue smallUnit
    in
    sign
        ++ (if magnitude < 1000 then
                part magnitude "ms"

            else if seconds < 60 then
                (formatParts locale 0 1 (toFloat magnitude / 1000)).text ++ nbsp ++ "s"

            else if minutes < 60 then
                pair minutes "min" (seconds - minutes * 60) "s"

            else if hours < 24 then
                pair hours hourUnit (minutes - hours * 60) "min"

            else
                pair days "d" (hours - days * 24) hourUnit
           )



-- DATES AND TIMES


{-| A date in the short numeric form of the language: `20.10.2026` in
Norwegian, and the unambiguous ISO form `2026-10-20` in English.

    Format.date Locale.en october20 -- "2026-10-20"

    Format.date Locale.nb october20 -- "20.10.2026"

-}
date : Locale -> Date -> String
date locale value =
    Locale.pick locale
        { nb = pad2 (Date.day value) ++ "." ++ pad2 (Date.month value) ++ "." ++ String.padLeft 4 '0' (String.fromInt (Date.year value))
        , en = Date.toIso value
        }


{-| The date with the month spelled out: `20 October 2026` in English and
`20. oktober 2026` in Norwegian.
-}
dateLong : Locale -> Date -> String
dateLong locale value =
    Locale.pick locale
        { nb = String.fromInt (Date.day value) ++ ". " ++ Locale.monthName locale (Date.month value) ++ " " ++ String.fromInt (Date.year value)
        , en = String.fromInt (Date.day value) ++ " " ++ Locale.monthName locale (Date.month value) ++ " " ++ String.fromInt (Date.year value)
        }


{-| The time of day on a 24-hour clock, in a time zone: `14:05`.

    Time.here |> Task.andThen (\zone -> Task.map (Format.time zone) Time.now)

-}
time : Time.Zone -> Time.Posix -> String
time zone posix =
    pad2 (Time.toHour zone posix) ++ ":" ++ pad2 (Time.toMinute zone posix)


{-| The date and the time: `2026-10-20 14:05` in English, `20.10.2026 14:05` in
Norwegian.
-}
dateTime : Locale -> Time.Zone -> Time.Posix -> String
dateTime locale zone posix =
    date locale (Date.fromPosix zone posix) ++ " " ++ time zone posix


{-| A moment as the text that APIs and logs use: ISO 8601 in UTC, to the second,
`2026-10-22T14:05:00Z`. It does not depend on a locale or a time zone. Milliseconds
are left out.

    Format.iso8601 (Time.millisToPosix 0) -- "1970-01-01T00:00:00Z"

-}
iso8601 : Time.Posix -> String
iso8601 posix =
    Date.toIso (Date.fromPosix Time.utc posix)
        ++ "T"
        ++ pad2 (Time.toHour Time.utc posix)
        ++ ":"
        ++ pad2 (Time.toMinute Time.utc posix)
        ++ ":"
        ++ pad2 (Time.toSecond Time.utc posix)
        ++ "Z"


{-| How long ago something happened, or how long until it does, relative to
the current time. Pass the current time first, then the time of the event.

    Format.relative Locale.en now fiveMinutesAgo -- "5 minutes ago"

    Format.relative Locale.en now threeDaysAgo -- "3 days ago"

    Format.relative Locale.en now inTwoHours -- "in 2 hours"

    Format.relative Locale.nb now fiveMinutesAgo -- "for 5 minutter siden"

Within the same 45 seconds the answer is "just now" (or "in a moment"); beyond
that the largest fitting unit is used, rounded down: minutes, hours, days,
months of 30 days, years of 365 days.

-}
relative : Locale -> Time.Posix -> Time.Posix -> String
relative locale now then_ =
    let
        -- Milliseconds do not fit in the 32 bits Elm's `//` works with
        -- (about 24 days), so the steps are taken on Floats.
        elapsed =
            toFloat (Time.posixToMillis now - Time.posixToMillis then_)

        future =
            elapsed < 0

        distance =
            abs elapsed

        seconds =
            floor (distance / 1000)

        minutes =
            floor (distance / 60000)

        hours =
            floor (distance / 3600000)

        days =
            floor (distance / 86400000)

        pick nb en =
            Locale.pick locale { nb = nb, en = en }

        span n nb1 nbN en1 enN =
            if future then
                if n == 1 then
                    pick ("om 1 " ++ nb1) ("in 1 " ++ en1)

                else
                    pick ("om " ++ String.fromInt n ++ " " ++ nbN) ("in " ++ String.fromInt n ++ " " ++ enN)

            else if n == 1 then
                pick ("for 1 " ++ nb1 ++ " siden") ("1 " ++ en1 ++ " ago")

            else
                pick ("for " ++ String.fromInt n ++ " " ++ nbN ++ " siden") (String.fromInt n ++ " " ++ enN ++ " ago")
    in
    if seconds < 45 then
        if future then
            pick "om et øyeblikk" "in a moment"

        else
            pick "nå nettopp" "just now"

    else if minutes < 60 then
        span (max 1 minutes) "minutt" "minutter" "minute" "minutes"

    else if hours < 24 then
        span hours "time" "timer" "hour" "hours"

    else if days < 30 then
        span days "dag" "dager" "day" "days"

    else if days < 365 then
        span (days // 30) "måned" "måneder" "month" "months"

    else
        span (days // 365) "år" "år" "year" "years"


pad2 : Int -> String
pad2 n =
    String.padLeft 2 '0' (String.fromInt n)
