module Klar.Money exposing
    ( Money, fromMinor, fromMajorAndMinor, zero, toMinor, currencyOf
    , Currency, currency, currencyCode, decimals, symbol, isActive, allCurrencies
    , nok, sek, dkk, isk, eur, usd, gbp, chf, jpy, cad, aud, cny
    , add, subtract, sum, multiply, percentOf, fraction, allocate, split, negate, abs
    , compare, isZero, isPositive, isNegative
    , parse, parseRounded, toString, toSymbolString, toAmountString, toDecimalString, fromDecimalString
    , Problem, problemText
    )

{-| An exact amount of money: a whole number of minor units (øre, cents, yen)
together with its currency. There is no `Float` in it, so there is no 0.1 + 0.2.

    import Klar.Locale as Locale
    import Klar.Money as Money exposing (Money)

    price : Money
    price =
        Money.fromMinor Money.nok 123450
            |> Maybe.withDefault (Money.zero Money.nok)

    Money.toString Locale.nb price -- "1 234,50 NOK"

    Money.toString Locale.en price -- "NOK 1,234.50"

    Money.percentOf 25 price -- Ok 308.63 NOK: 308.625 rounded half away from zero

    Money.split 3 price -- Ok [ 411.50, 411.50, 411.50 ]

Use this module for every amount an application keeps, adds or splits, and
[Klar.MoneyInput](Klar-MoneyInput) to let a person type one. Use
[Klar.NumberInput](Klar-NumberInput) for a quantity, a percentage or a weight: a
number that is not money.

**The currency is part of the amount.** `Money.add` of 10 NOK and 10 EUR is an
`Err`, not 20 of something. The currency is a value (`Money.nok`, or
`Money.currency "KWD"` for a code that comes from data) and not a phantom type,
because the currency of an invoice is only known when the program runs. Every
currency of the active ISO 4217 list is there (`allCurrencies`), with its number of
decimals, which is two for NOK and USD, none for JPY and three for KWD. The two that ended most
recently, the Netherlands Antillean guilder (ANG) and the Bulgarian lev (BGN), can
still be read from old data with `currency` and are not active (`isActive`).

**Rounding is what a person does by hand.** Whenever an amount has to be rounded
(a percentage of an amount, a ratio) a half goes away from zero: 0.5 øre becomes 1,
and -0.5 becomes -1. The function says so by its name; nothing is rounded behind
your back. Text with too many decimals (`parse`) is refused, and `parseRounded`
rounds it when you ask.

**Splitting never loses a unit.** `allocate` and `split` give out the minor units
that do not divide evenly one by one, so the parts add up to the amount. They, and
`fraction`, are exact for any numbers in the range below: the working never leaves it.

**Whole numbers up to 9 007 199 254 740 991 minor units** (90 trillion in the main
unit of a currency with two decimals) are exact in every browser. Beyond that
Elm's `Int` silently gives wrong answers, so an amount outside that range cannot be
made: `fromMinor` says `Nothing`, and a calculation that leaves the range says
`Err`.

Amounts can be compared with `==`: two amounts are equal when the currency and the
number of minor units are. A `Money` is not `comparable`, so it cannot be a `Dict` key
or a `Set` member; use `( currencyCode (currencyOf amount), toMinor amount )` for that.
Sort with `List.sortWith Money.compare`.

The built-in texts (`problemText`, the number format) follow a
[Klar.Locale](Klar-Locale).


# Amounts

@docs Money, fromMinor, fromMajorAndMinor, zero, toMinor, currencyOf


# Currencies

@docs Currency, currency, currencyCode, decimals, symbol, isActive, allCurrencies

@docs nok, sek, dkk, isk, eur, usd, gbp, chf, jpy, cad, aud, cny


# Calculating

@docs add, subtract, sum, multiply, percentOf, fraction, allocate, split, negate, abs


# Comparing

@docs compare, isZero, isPositive, isNegative


# Reading and writing

@docs parse, parseRounded, toString, toSymbolString, toAmountString, toDecimalString, fromDecimalString


# Problems

@docs Problem, problemText

-}

import Klar.Format as Format
import Klar.Locale as Locale exposing (Locale)
import Klar.Money.Arithmetic as Arithmetic
import Klar.Money.Currencies as Currencies
import Klar.Money.Reading as Reading exposing (Reading)



-- AMOUNTS


{-| An amount of money in one currency. Make one with `fromMinor`,
`fromMajorAndMinor`, `zero` or `parse`.
-}
type Money
    = Money Currency Int


{-| The amount `minor` of the smallest unit of a currency: `Money.fromMinor
Money.nok 12550` is 125.50 NOK, and `Money.fromMinor Money.jpy 500` is 500 yen.
`Nothing` when the number is beyond 9 007 199 254 740 991 in either direction,
where whole numbers stop being exact.
-}
fromMinor : Currency -> Int -> Maybe Money
fromMinor cur minor =
    if Basics.abs minor <= Arithmetic.maxMinor then
        Just (Money cur (noNegativeZero minor))

    else
        Nothing


{-| An amount from its main and its minor part: `Money.fromMajorAndMinor
Money.nok 125 50` is 125.50 NOK. Neither part may be negative (use `negate` for a
negative amount) and the minor part must be smaller than a main unit: below 100 for
NOK, 1 000 for KWD, and 0 for JPY. `Nothing` otherwise, and when the amount is too
large.
-}
fromMajorAndMinor : Currency -> Int -> Int -> Maybe Money
fromMajorAndMinor ((Currency details) as cur) major minor =
    let
        unit =
            10 ^ details.decimals
    in
    if major < 0 || minor < 0 || minor >= unit then
        Nothing

    else
        fromMinor cur (major * unit + minor)


{-| No money in a currency.
-}
zero : Currency -> Money
zero cur =
    Money cur 0


{-| The number of minor units: 12550 for 125.50 NOK, negative for a debt. Use it
to store an amount or to send it to a server; `Money.fromMinor` reads it back.
-}
toMinor : Money -> Int
toMinor (Money _ minor) =
    minor


{-| The currency of an amount.
-}
currencyOf : Money -> Currency
currencyOf (Money cur _) =
    cur


noNegativeZero : Int -> Int
noNegativeZero n =
    if n == 0 then
        0

    else
        n



-- CURRENCIES


{-| A currency: its ISO 4217 code and the number of decimals of its minor unit.
Make one with `currency`, or take a common one such as `nok`.
-}
type Currency
    = Currency { code : String, decimals : Int }


{-| The currency with an ISO 4217 code such as `"NOK"`; lower case and spaces around
the code are fine. `Nothing` for a code that is not an ISO 4217 currency. The active
currencies (`allCurrencies`) are found, and so are the two that ended most recently,
the Netherlands Antillean guilder (`"ANG"`, replaced by `"XCG"` on 2025-03-31) and the
Bulgarian lev (`"BGN"`, ended with Bulgaria's joining of the euro on 2026-01-01), so
that old data can be read. Check `isActive` before you offer one of them in a choice.

    Money.currency "kwd" |> Maybe.map Money.decimals -- Just 3

    Money.currency "BTC" -- Nothing

-}
currency : String -> Maybe Currency
currency code =
    let
        upper =
            String.toUpper (String.trim code)
    in
    Currencies.decimalsOf upper
        |> Maybe.map (\places -> Currency { code = upper, decimals = places })


{-| The three-letter ISO 4217 code: `"NOK"`.
-}
currencyCode : Currency -> String
currencyCode (Currency details) =
    details.code


{-| How many digits the minor unit of the currency has: 2 for NOK, USD and EUR
(100 øre, 100 cents), 0 for JPY, 3 for KWD.
-}
decimals : Currency -> Int
decimals (Currency details) =
    details.decimals


{-| The symbol people write for the currency (`"kr"`, `"$"`, `"€"`), or its code when
there is no symbol they all know. A symbol can be shared (`kr` is NOK, SEK, DKK and
ISK), so in a list of amounts in several currencies use the code.
-}
symbol : Currency -> String
symbol (Currency details) =
    Currencies.symbolOf details.code


{-| Every currency of the active ISO 4217 list, sorted by code, for a list to choose a
currency from. It follows the list that SIX, the maintenance agency, published on
2026-09-17. Withdrawn currencies, precious metals, test codes and units of account that
have no minor unit are not in it.
-}
allCurrencies : List Currency
allCurrencies =
    List.map (\entry -> Currency { code = entry.code, decimals = entry.decimals }) Currencies.entries


{-| Is the currency on the active ISO 4217 list? `False` for a currency that was
withdrawn and can only be read from old data: `Money.currency "BGN"` gives one.
-}
isActive : Currency -> Bool
isActive (Currency details) =
    Currencies.isActive details.code


{-| Norwegian krone.
-}
nok : Currency
nok =
    Currency { code = "NOK", decimals = 2 }


{-| Swedish krona.
-}
sek : Currency
sek =
    Currency { code = "SEK", decimals = 2 }


{-| Danish krone.
-}
dkk : Currency
dkk =
    Currency { code = "DKK", decimals = 2 }


{-| Icelandic króna, which has no minor unit in use.
-}
isk : Currency
isk =
    Currency { code = "ISK", decimals = 0 }


{-| Euro.
-}
eur : Currency
eur =
    Currency { code = "EUR", decimals = 2 }


{-| United States dollar.
-}
usd : Currency
usd =
    Currency { code = "USD", decimals = 2 }


{-| Pound sterling.
-}
gbp : Currency
gbp =
    Currency { code = "GBP", decimals = 2 }


{-| Swiss franc.
-}
chf : Currency
chf =
    Currency { code = "CHF", decimals = 2 }


{-| Japanese yen, which has no minor unit.
-}
jpy : Currency
jpy =
    Currency { code = "JPY", decimals = 0 }


{-| Canadian dollar.
-}
cad : Currency
cad =
    Currency { code = "CAD", decimals = 2 }


{-| Australian dollar.
-}
aud : Currency
aud =
    Currency { code = "AUD", decimals = 2 }


{-| Chinese yuan (renminbi).
-}
cny : Currency
cny =
    Currency { code = "CNY", decimals = 2 }



-- CALCULATING


{-| Two amounts added. `Err` when they are in different currencies, or when the sum
is beyond what whole numbers hold exactly.

    Money.add a b -- Ok (a and b added)

    Money.add tenNok tenEur -- Err (Cannot mix NOK and EUR)

-}
add : Money -> Money -> Result Problem Money
add (Money first x) (Money second y) =
    if first /= second then
        Err (DifferentCurrencies first second)

    else
        checked first (x + y)


{-| The second amount taken from the first. `Err` when they are in different
currencies, or when the result is beyond what whole numbers hold exactly.
-}
subtract : Money -> Money -> Result Problem Money
subtract (Money first x) (Money second y) =
    if first /= second then
        Err (DifferentCurrencies first second)

    else
        checked first (x - y)


{-| The total of a list of amounts in the given currency, which is also the answer
for an empty list. `Err` when one of the amounts is in another currency, or when the
total is out of range.

    Money.sum Money.nok (List.map .price lines)

-}
sum : Currency -> List Money -> Result Problem Money
sum cur amounts =
    List.foldl (\amount total -> Result.andThen (\running -> add running amount) total) (Ok (zero cur)) amounts


{-| An amount times a whole number: three of a 125.50 NOK article. A negative factor
gives a negative amount. `Err` when the result is out of range.
-}
multiply : Int -> Money -> Result Problem Money
multiply factor (Money cur minor) =
    checked cur (minor * factor)


{-| A whole number of percent of an amount, rounded half away from zero to the
minor unit: 25 percent of 1 234.50 NOK is 308.63 NOK (308.625 rounds up). Use it
for VAT and discounts. For a percentage with decimals use `fraction`: 12.5 percent
is `Money.fraction 125 1000`. `Err` when the result is out of range.

    Money.percentOf 25 price

-}
percentOf : Int -> Money -> Result Problem Money
percentOf percent amount =
    fraction percent 100 amount


{-| A fraction of an amount: `Money.fraction 3 8 amount` is three eighths of it. It
is rounded half away from zero to the minor unit, so 2.5 øre becomes 3 and -2.5
becomes -3. The numerator may be negative; the denominator must be above zero.

The working keeps everything exact: it never forms the product of the amount and the
numerator, which could be far beyond the range of whole numbers, so any numerator and
denominator in that range work, such as an exchange rate written as a ratio of two
large whole numbers, and only the result must stay inside the range. The VAT inside a
price that includes it, at 25 percent, is `Money.fraction 25 125 price`.

`Err` when the denominator is not above zero, or when a number is out of range.

-}
fraction : Int -> Int -> Money -> Result Problem Money
fraction numerator denominator (Money cur minor) =
    if denominator < 1 then
        Err BadFraction

    else
        case Arithmetic.mulDivRound (Basics.abs minor) (Basics.abs numerator) denominator of
            Nothing ->
                Err OutOfRange

            Just magnitude ->
                if (minor < 0) /= (numerator < 0) then
                    checked cur (Basics.negate magnitude)

                else
                    checked cur magnitude


{-| Divides an amount into parts in proportion to the weights, so that the parts
always add up to the amount. 100.00 NOK with the weights `[ 1, 1, 1 ]` is 33.34,
33.33 and 33.33. With `[ 50, 30, 20 ]` it is 50.00, 30.00 and 20.00.

Each part is the share rounded down to the minor unit. The units left over go, one
each, to the parts with the biggest fractions, and to the earlier part when two are
equal. A part with the weight 0 gets nothing. A negative amount is divided the same
way, so the parts of -100.00 are -33.34, -33.33 and -33.33.

The shares are exact for any weights, however large, as long as the weights add up to
no more than 9 007 199 254 740 991 (the range of whole numbers, 90 trillion in the main
unit of a currency with two decimals); they are scaled with exact arithmetic, never by
a product that could leave the range. `Err` when there are no weights, when one is
negative, when they all are 0, or when they add up to more than that.

-}
allocate : List Int -> Money -> Result Problem (List Money)
allocate weights (Money cur minor) =
    case Arithmetic.allocate (Basics.abs minor) weights of
        Just parts ->
            parts
                |> List.map
                    (\part ->
                        if minor < 0 then
                            Money cur (noNegativeZero (Basics.negate part))

                        else
                            Money cur part
                    )
                |> Ok

        Nothing ->
            if List.isEmpty weights || List.any (\weight -> weight < 0) weights || List.sum weights <= 0 then
                Err NoShares

            else
                Err SharesTooLarge


{-| An amount in equal parts, the first parts a minor unit larger when it does not
divide: `Money.split 3` of 100.00 NOK is 33.34, 33.33 and 33.33. It is
`allocate` with equal weights. `Err` when the number of parts is below 1 or above
100 000.
-}
split : Int -> Money -> Result Problem (List Money)
split parts amount =
    if parts < 1 || parts > 100000 then
        Err NoShares

    else
        allocate (List.repeat parts 1) amount


{-| The same amount with the opposite sign.
-}
negate : Money -> Money
negate (Money cur minor) =
    Money cur (noNegativeZero (Basics.negate minor))


{-| The amount without its sign.
-}
abs : Money -> Money
abs (Money cur minor) =
    Money cur (Basics.abs minor)


checked : Currency -> Int -> Result Problem Money
checked cur minor =
    if Basics.abs minor <= Arithmetic.maxMinor then
        Ok (Money cur (noNegativeZero minor))

    else
        Err OutOfRange



-- COMPARING


{-| An order for sorting. Amounts in the same currency are ordered by their value.
Amounts in different currencies are ordered by the currency code, so a mixed list
sorts into groups; it says nothing about which is worth more. Use it as
`List.sortWith Money.compare`.
-}
compare : Money -> Money -> Order
compare (Money first x) (Money second y) =
    if first == second then
        Basics.compare x y

    else
        Basics.compare (currencyCode first) (currencyCode second)


{-| Is this no money at all?
-}
isZero : Money -> Bool
isZero (Money _ minor) =
    minor == 0


{-| Is this more than nothing?
-}
isPositive : Money -> Bool
isPositive (Money _ minor) =
    minor > 0


{-| Is this less than nothing, a debt or a credit?
-}
isNegative : Money -> Bool
isNegative (Money _ minor) =
    minor < 0



-- READING


{-| Reads an amount the way a person writes it, in a currency. It reads like
[`NumberInput.parseIn`](Klar-NumberInput#parseIn): `,` and `.` are both a decimal
separator, spaces and no-break spaces are ignored, and `1.234,56` and `1,234.56` are
both 1234.56. The language decides what a lone comma before three digits means:
`1,234` is 1234 in English and 1.234 in Norwegian.

On top of that it takes away the code and the symbol of the currency (`NOK 1 234`,
`1 234,50 kr`, `$100` in a field for USD), a leading `-`, `−` or `+`, parentheses for
a negative amount (`(100,00)`), and the Norwegian ending `,-`.

It never rounds and never guesses. The result is an `Err` for text that is not an
amount, for more decimals than the currency has (`100,505` NOK: use `parseRounded`
to round it; `100,500` is fine, it is the same amount), for separators that cannot
be read (`1.2.3`), for a comma before three digits in English in a currency with
three decimals (`1,234` KWD could be a thousand or one and a bit), for an amount of
another currency (`$100` in a NOK field) and for an amount out of range. Thousands are
grouped by three: the Indian grouping `1,23,456` is not read, and is refused as unclear
(write `123456` or `123,456`).

    Money.parse Locale.nb Money.nok "1 234,50" -- Ok 1234.50 NOK

    Money.parse Locale.en Money.nok "1,234.50" -- Ok 1234.50 NOK

    Money.parse Locale.en Money.jpy "¥1,500" -- Ok 1500 JPY

    Money.parse Locale.nb Money.nok "(100)" -- Ok -100.00 NOK

    Money.parse Locale.en Money.nok "12.505" -- Err (NOK has 2 decimals)

-}
parse : Locale -> Currency -> String -> Result Problem Money
parse locale cur text =
    readAmount False locale cur text


{-| Like `parse`, but text with more decimals than the currency has is rounded to
the minor unit, half away from zero (`12.505` NOK is 12.51 and `-12.505` is -12.51).
Use it where rounding is what you want, such as an import of prices from a
spreadsheet; use `parse` where a person types and must be told.
-}
parseRounded : Locale -> Currency -> String -> Result Problem Money
parseRounded locale cur text =
    readAmount True locale cur text


readAmount : Bool -> Locale -> Currency -> String -> Result Problem Money
readAmount rounded locale ((Currency details) as cur) text =
    Reading.read
        { grouping = groupingCharacter locale
        , decimals = details.decimals
        , marks = Currencies.marks details.code
        }
        text
        |> Result.mapError
            (\failure ->
                case failure of
                    Reading.Blank ->
                        Empty

                    Reading.NotAnAmount ->
                        NotAnAmount

                    Reading.UnclearSeparators ->
                        UnclearSeparators
            )
        |> Result.andThen (fromReading rounded cur)


{-| The thousands separator of a language when it is a comma or a point: the
character that `1,234` is split at.
-}
groupingCharacter : Locale -> Maybe Char
groupingCharacter locale =
    case String.uncons (Locale.thousandSeparator locale) of
        Just ( c, "" ) ->
            if c == ',' || c == '.' then
                Just c

            else
                Nothing

        _ ->
            Nothing


fromReading : Bool -> Currency -> Reading -> Result Problem Money
fromReading rounded ((Currency details) as cur) reading =
    let
        -- the digits beyond the decimals of the currency; zeros change nothing (`12.100`)
        extra =
            String.dropLeft details.decimals reading.fraction

        digits =
            withoutLeadingZeros (reading.whole ++ String.padRight details.decimals '0' (String.left details.decimals reading.fraction))
    in
    if String.any (\c -> c /= '0') extra && not rounded then
        Err (TooManyDecimals cur)

    else if String.length digits > 16 then
        Err OutOfRange

    else
        case Arithmetic.fromDigits digits of
            Nothing ->
                Err NotAnAmount

            Just magnitude ->
                let
                    rounded_ =
                        if String.left 1 extra >= "5" then
                            magnitude + 1

                        else
                            magnitude
                in
                checked cur
                    (if reading.negative then
                        Basics.negate rounded_

                     else
                        rounded_
                    )


withoutLeadingZeros : String -> String
withoutLeadingZeros digits =
    case String.uncons digits of
        Just ( '0', rest ) ->
            withoutLeadingZeros rest

        Just _ ->
            digits

        Nothing ->
            "0"


{-| Reads an amount that a machine wrote: an optional `-`, digits, and an optional
`.` with digits, nothing else (`"1234.50"`, `"-0.5"`, `"1500"`): what `toDecimalString`
writes. No thousands separators, no currency, no leniency. Use it for a field of a
JSON document or a CSV file; use `parse` for text a person typed.
-}
fromDecimalString : Currency -> String -> Result Problem Money
fromDecimalString cur text =
    let
        ( negative, body ) =
            case String.uncons text of
                Just ( '-', rest ) ->
                    ( True, rest )

                _ ->
                    ( False, text )

        digitsOnly digits =
            digits /= "" && String.all Char.isDigit digits
    in
    case String.split "." body of
        [ whole ] ->
            if digitsOnly whole then
                fromReading False cur { negative = negative, whole = whole, fraction = "" }

            else
                Err NotAnAmount

        [ whole, afterPoint ] ->
            if digitsOnly whole && digitsOnly afterPoint then
                fromReading False cur { negative = negative, whole = whole, fraction = afterPoint }

            else
                Err NotAnAmount

        _ ->
            Err NotAnAmount



-- WRITING


type alias Parts =
    { negative : Bool
    , whole : Int
    , fraction : String
    }


partsOf : Money -> Parts
partsOf (Money (Currency details) minor) =
    let
        digits =
            String.padLeft (details.decimals + 1) '0' (String.fromInt (Basics.abs minor))
    in
    { negative = minor < 0
    , whole = Arithmetic.fromDigits (String.dropRight details.decimals digits) |> Maybe.withDefault 0
    , fraction = String.right details.decimals digits
    }


amountText : Locale -> Parts -> String
amountText locale parts =
    Format.int locale parts.whole
        ++ (if parts.fraction == "" then
                ""

            else
                Locale.decimalSeparator locale ++ parts.fraction
           )


{-| The amount with its code, the way `Klar.Format.currency` writes an amount: the
number format of the language, a real minus sign, and no-break spaces so that an
amount never breaks over two lines. The code is the same in every language, so it
cannot be mistaken for another currency.

    Money.toString Locale.nb price -- "1 234,50 NOK"

    Money.toString Locale.en price -- "NOK 1,234.50"

    Money.toString Locale.en (Money.negate price) -- "−NOK 1,234.50"

-}
toString : Locale -> Money -> String
toString locale ((Money cur _) as amount) =
    write locale (currencyCode cur) amount


{-| Like `toString`, with the symbol of the currency instead of its code, when it
has one that people know (`1 234,50 kr`, `$1,234.50`, `€1,234.50`). A symbol can
stand for several currencies (`kr`), so use `toString` where more than one currency
is on the page.
-}
toSymbolString : Locale -> Money -> String
toSymbolString locale ((Money cur _) as amount) =
    write locale (symbol cur) amount


write : Locale -> String -> Money -> String
write locale mark amount =
    let
        parts =
            partsOf amount

        sign =
            if parts.negative then
                "−"

            else
                ""

        text =
            amountText locale parts
    in
    Locale.pick locale
        { nb = sign ++ text ++ "\u{00A0}" ++ mark
        , en =
            sign
                ++ mark
                ++ (if endsInSign mark then
                        ""

                    else
                        "\u{00A0}"
                   )
                ++ text
        }


endsInSign : String -> Bool
endsInSign mark =
    String.right 1 mark |> String.all (\c -> String.contains (String.fromChar c) "$€£¥₹₩₽₺₪₫₱₴₦฿")


{-| Only the number, with the grouping and decimals of the language and no currency:
for a column of a table whose header says which currency it is, or for a field.

    Money.toAmountString Locale.nb price -- "1 234,50"

    Money.toAmountString Locale.en price -- "1,234.50"

-}
toAmountString : Locale -> Money -> String
toAmountString locale amount =
    let
        parts =
            partsOf amount
    in
    (if parts.negative then
        "−"

     else
        ""
    )
        ++ amountText locale parts


{-| The amount as a machine reads it, whatever the language: no thousands
separators, a `.` before the decimals, a `-` for a negative amount, and exactly as
many decimals as the currency has. Use it for a JSON document or a CSV file;
`fromDecimalString` reads it back.

    Money.toDecimalString price -- "1234.50"

-}
toDecimalString : Money -> String
toDecimalString (Money (Currency details) minor) =
    let
        digits =
            String.padLeft (details.decimals + 1) '0' (String.fromInt (Basics.abs minor))
    in
    (if minor < 0 then
        "-"

     else
        ""
    )
        ++ String.dropRight details.decimals digits
        ++ (if details.decimals == 0 then
                ""

            else
                "." ++ String.right details.decimals digits
           )



-- PROBLEMS


{-| Why an amount could not be made or a calculation could not be done: the text is
not an amount, it has more decimals than the currency, the currencies are mixed, the
number is too large. It is opaque so that a new kind of problem is not a breaking
change; `problemText` says it in words.
-}
type Problem
    = Empty
    | NotAnAmount
    | TooManyDecimals Currency
    | UnclearSeparators
    | OutOfRange
    | DifferentCurrencies Currency Currency
    | NoShares
    | SharesTooLarge
    | BadFraction


{-| A problem in words, in the language: "NOK has 2 decimals", "Cannot mix NOK and
EUR". It is meant for a person who typed an amount and for a log.

    Money.parse Locale.en Money.nok "12.505"
        |> Result.mapError (Money.problemText Locale.en)
    -- Err "NOK has 2 decimals"

-}
problemText : Locale -> Problem -> String
problemText locale problem =
    case problem of
        Empty ->
            Locale.pick locale { nb = "Skriv inn et beløp", en = "Enter an amount" }

        NotAnAmount ->
            Locale.pick locale { nb = "Må være et gyldig beløp", en = "Must be an amount" }

        TooManyDecimals cur ->
            let
                code =
                    currencyCode cur
            in
            case decimals cur of
                0 ->
                    Locale.pick locale { nb = code ++ " har ingen desimaler", en = code ++ " has no decimals" }

                1 ->
                    Locale.pick locale { nb = code ++ " har 1 desimal", en = code ++ " has 1 decimal" }

                places ->
                    Locale.pick locale
                        { nb = code ++ " har " ++ String.fromInt places ++ " desimaler"
                        , en = code ++ " has " ++ String.fromInt places ++ " decimals"
                        }

        UnclearSeparators ->
            Locale.pick locale
                { nb = "Uklare skilletegn: skriv beløpet med ett desimalskilletegn"
                , en = "The separators are unclear: write the amount with one decimal separator"
                }

        OutOfRange ->
            Locale.pick locale { nb = "Beløpet er for stort", en = "The amount is too large" }

        DifferentCurrencies first second ->
            Locale.pick locale
                { nb = "Kan ikke legge sammen " ++ currencyCode first ++ " og " ++ currencyCode second
                , en = "Cannot mix " ++ currencyCode first ++ " and " ++ currencyCode second
                }

        NoShares ->
            Locale.pick locale
                { nb = "Trenger minst én andel, ingen negative og ikke alle lik 0"
                , en = "Needs at least one share, none negative, and not all 0"
                }

        SharesTooLarge ->
            Locale.pick locale
                { nb = "Andelene summerer til mer enn det som kan deles nøyaktig"
                , en = "The shares add up to more than can be divided exactly"
                }

        BadFraction ->
            Locale.pick locale
                { nb = "Nevneren må være over 0"
                , en = "The denominator must be above 0"
                }
