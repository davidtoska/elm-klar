module MoneyTest exposing (suite)

{-| `Klar.Money`: exact amounts. The table of currencies, reading and writing text in
both languages, the rounding of a half, the splitting of an amount without losing a
minor unit, and the refusal to leave the range where whole numbers are exact.
-}

import Expect exposing (Expectation)
import Fuzz exposing (Fuzzer)
import Klar.Locale as Locale exposing (Locale)
import Klar.Money as Money exposing (Currency, Money)
import Klar.Money.Arithmetic as Arithmetic
import Klar.Money.Currencies as Currencies
import Set
import Test exposing (Test, describe, fuzz, fuzz2, fuzz3, test)


suite : Test
suite =
    describe "Klar.Money"
        [ tableTests
        , constructionTests
        , writingTests
        , parsingTests
        , roundingParseTests
        , roundTripTests
        , machineTextTests
        , arithmeticTests
        , fractionTests
        , allocationTests
        , comparingTests
        , rangeTests
        , problemTextTests
        ]



-- HELPERS


{-| An amount from minor units, for a number that is known to be in range.
-}
amount : Currency -> Int -> Money
amount cur minor =
    Money.fromMinor cur minor |> Maybe.withDefault (Money.zero cur)


minorOf : Result Money.Problem Money -> Result String Int
minorOf result =
    result |> Result.map Money.toMinor |> Result.mapError (Money.problemText Locale.en)


nbsp : String
nbsp =
    "\u{00A0}"


maxMinor : Int
maxMinor =
    9007199254740991


{-| Every amount that can exist, positive and negative, the large ones too (the fuzzers
of the test library do not reach beyond 32 bits by themselves).
-}
anyMinor : Fuzzer Int
anyMinor =
    Fuzz.map3
        (\negative high low ->
            let
                magnitude =
                    high * 1000000 + low
            in
            if negative then
                Basics.negate magnitude

            else
                magnitude
        )
        Fuzz.bool
        (Fuzz.intRange 0 9007199253)
        (Fuzz.intRange 0 999999)


smallMinor : Fuzzer Int
smallMinor =
    Fuzz.intRange -100000000000 100000000000


currencies : List Currency
currencies =
    [ Money.nok, Money.jpy, kwd, Money.usd, clf, Money.eur ]


currencyFuzzer : Fuzzer Currency
currencyFuzzer =
    Fuzz.oneOf (List.map Fuzz.constant currencies)


localeFuzzer : Fuzzer Locale
localeFuzzer =
    Fuzz.oneOf [ Fuzz.constant Locale.en, Fuzz.constant Locale.nb ]



-- THE TABLE


tableTests : Test
tableTests =
    describe "the table of currencies"
        [ test "no code is there twice" <|
            \_ ->
                let
                    codes =
                        List.map .code Currencies.entries
                in
                Expect.equal (List.length codes) (Set.size (Set.fromList codes))
        , test "every exponent is between 0 and 4" <|
            \_ ->
                Currencies.entries
                    |> List.filter (\entry -> entry.decimals < 0 || entry.decimals > 4)
                    |> Expect.equal []
        , test "every code is three capital letters" <|
            \_ ->
                Currencies.entries
                    |> List.filter (\entry -> String.length entry.code /= 3 || not (String.all (\c -> Char.isUpper c && Char.isAlpha c) entry.code))
                    |> Expect.equal []
        , test "the table is sorted by code" <|
            \_ ->
                let
                    codes =
                        List.map .code Currencies.entries
                in
                Expect.equal (List.sort codes) codes
        , test "there are more than 150 currencies" <|
            \_ -> Expect.atLeast 150 (List.length Money.allCurrencies)
        , test "the exponents of the currencies people know" <|
            \_ ->
                [ "NOK", "SEK", "DKK", "EUR", "USD", "GBP", "CHF", "JPY", "ISK", "KWD", "BHD", "OMR", "JOD", "TND", "IQD", "LYD", "KRW", "CLP", "CLF", "UYW", "UGX", "VND", "XOF", "XAF", "XPF", "HUF", "BTN" ]
                    |> List.map (\code -> ( code, Money.currency code |> Maybe.map Money.decimals ))
                    |> Expect.equal
                        [ ( "NOK", Just 2 )
                        , ( "SEK", Just 2 )
                        , ( "DKK", Just 2 )
                        , ( "EUR", Just 2 )
                        , ( "USD", Just 2 )
                        , ( "GBP", Just 2 )
                        , ( "CHF", Just 2 )
                        , ( "JPY", Just 0 )
                        , ( "ISK", Just 0 )
                        , ( "KWD", Just 3 )
                        , ( "BHD", Just 3 )
                        , ( "OMR", Just 3 )
                        , ( "JOD", Just 3 )
                        , ( "TND", Just 3 )
                        , ( "IQD", Just 3 )
                        , ( "LYD", Just 3 )
                        , ( "KRW", Just 0 )
                        , ( "CLP", Just 0 )
                        , ( "CLF", Just 4 )
                        , ( "UYW", Just 4 )
                        , ( "UGX", Just 0 )
                        , ( "VND", Just 0 )
                        , ( "XOF", Just 0 )
                        , ( "XAF", Just 0 )
                        , ( "XPF", Just 0 )
                        , ( "HUF", Just 2 )
                        , ( "BTN", Just 2 )
                        ]
        , test "every currency is found again by its code" <|
            \_ ->
                Money.allCurrencies
                    |> List.filter (\cur -> Money.currency (Money.currencyCode cur) /= Just cur)
                    |> Expect.equal []
        , test "the named currencies are the ones in the table" <|
            \_ ->
                [ ( "NOK", Money.nok ), ( "SEK", Money.sek ), ( "DKK", Money.dkk ), ( "ISK", Money.isk ), ( "EUR", Money.eur ), ( "USD", Money.usd ), ( "GBP", Money.gbp ), ( "CHF", Money.chf ), ( "JPY", Money.jpy ), ( "CAD", Money.cad ), ( "AUD", Money.aud ), ( "CNY", Money.cny ) ]
                    |> List.filter (\( code, cur ) -> Money.currency code /= Just cur)
                    |> List.map Tuple.first
                    |> Expect.equal []
        , test "a code in lower case, with spaces around it, is found" <|
            \_ -> Expect.equal (Just Money.nok) (Money.currency "  nok ")
        , test "codes that are not active currencies are not found" <|
            \_ ->
                [ "", "NO", "NORK", "XXX", "XAU", "BTC", "HRK", "LTL", "ZWL", "CUC", "SLL" ]
                    |> List.filterMap Money.currency
                    |> List.length
                    |> Expect.equal 0
        , test "a symbol is a symbol, and a code is the symbol of a currency that has none" <|
            \_ ->
                Expect.equal [ "kr", "$", "€", "£", "¥", "CHF", "BHD" ]
                    [ Money.symbol Money.nok
                    , Money.symbol Money.usd
                    , Money.symbol Money.eur
                    , Money.symbol Money.gbp
                    , Money.symbol Money.jpy
                    , Money.symbol Money.chf
                    , Money.currency "BHD" |> Maybe.map Money.symbol |> Maybe.withDefault ""
                    ]
        ]



-- CONSTRUCTION


constructionTests : Test
constructionTests =
    describe "making an amount"
        [ test "fromMinor keeps the number of minor units" <|
            \_ -> Expect.equal (Just 12550) (Money.fromMinor Money.nok 12550 |> Maybe.map Money.toMinor)
        , test "the largest exact amount, and its negative, can be made" <|
            \_ ->
                Expect.equal [ True, True ]
                    [ Money.fromMinor Money.nok maxMinor /= Nothing
                    , Money.fromMinor Money.nok -maxMinor /= Nothing
                    ]
        , test "one more than the largest exact amount can not" <|
            \_ ->
                Expect.equal [ Nothing, Nothing ]
                    [ Money.fromMinor Money.nok (maxMinor + 1)
                    , Money.fromMinor Money.nok (Basics.negate maxMinor - 1)
                    ]
        , test "numbers that are no numbers can not be made into an amount" <|
            \_ ->
                Expect.equal [ Nothing, Nothing, Nothing ]
                    [ Money.fromMinor Money.nok (round (0 / 0))
                    , Money.fromMinor Money.nok (round (1 / 0))
                    , Money.fromMinor Money.nok (round (-1 / 0))
                    ]
        , test "the currency of an amount is the one it was made with" <|
            \_ -> Expect.equal Money.jpy (Money.currencyOf (amount Money.jpy 500))
        , test "zero is nothing, in a currency" <|
            \_ ->
                Expect.equal [ True, False, False ]
                    [ Money.isZero (Money.zero Money.nok)
                    , Money.isPositive (Money.zero Money.nok)
                    , Money.isNegative (Money.zero Money.nok)
                    ]
        , test "zero has no minor units" <|
            \_ -> Expect.equal 0 (Money.toMinor (Money.zero Money.nok))
        , test "fromMajorAndMinor puts the parts together" <|
            \_ ->
                Expect.equal [ Just 12550, Just 5, Just 500, Just 1234567 ]
                    [ Money.fromMajorAndMinor Money.nok 125 50 |> Maybe.map Money.toMinor
                    , Money.fromMajorAndMinor Money.nok 0 5 |> Maybe.map Money.toMinor
                    , Money.fromMajorAndMinor Money.jpy 500 0 |> Maybe.map Money.toMinor
                    , Money.fromMajorAndMinor kwd 1234 567 |> Maybe.map Money.toMinor
                    ]
        , test "fromMajorAndMinor refuses a minor part that is a whole unit or more, and negative parts" <|
            \_ ->
                Expect.equal [ Nothing, Nothing, Nothing, Nothing ]
                    [ Money.fromMajorAndMinor Money.nok 1 100 |> Maybe.map Money.toMinor
                    , Money.fromMajorAndMinor Money.jpy 1 1 |> Maybe.map Money.toMinor
                    , Money.fromMajorAndMinor Money.nok -1 50 |> Maybe.map Money.toMinor
                    , Money.fromMajorAndMinor Money.nok 1 -50 |> Maybe.map Money.toMinor
                    ]
        , test "fromMajorAndMinor refuses an amount that is too large" <|
            \_ -> Expect.equal Nothing (Money.fromMajorAndMinor Money.nok 90071992547410 0)
        , test "the amount nearest to the limit can be made from its parts" <|
            \_ -> Expect.equal (Just maxMinor) (Money.fromMajorAndMinor Money.nok 90071992547409 91 |> Maybe.map Money.toMinor)
        ]



-- WRITING


writingTests : Test
writingTests =
    describe "writing an amount"
        [ describe "toString: with the code"
            [ writing Money.toString Locale.nb Money.nok 123450 ("1" ++ nbsp ++ "234,50" ++ nbsp ++ "NOK")
            , writing Money.toString Locale.en Money.nok 123450 ("NOK" ++ nbsp ++ "1,234.50")
            , writing Money.toString Locale.en Money.nok -123450 ("−NOK" ++ nbsp ++ "1,234.50")
            , writing Money.toString Locale.nb Money.nok -123450 ("−1" ++ nbsp ++ "234,50" ++ nbsp ++ "NOK")
            , writing Money.toString Locale.nb Money.nok 0 ("0,00" ++ nbsp ++ "NOK")
            , writing Money.toString Locale.nb Money.nok 5 ("0,05" ++ nbsp ++ "NOK")
            , writing Money.toString Locale.nb Money.nok -5 ("−0,05" ++ nbsp ++ "NOK")
            , writing Money.toString Locale.en Money.jpy 1500 ("JPY" ++ nbsp ++ "1,500")
            , writing Money.toString Locale.nb Money.jpy 1234567 ("1" ++ nbsp ++ "234" ++ nbsp ++ "567" ++ nbsp ++ "JPY")
            , writing Money.toString Locale.nb kwd 1234567 ("1" ++ nbsp ++ "234,567" ++ nbsp ++ "KWD")
            , writing Money.toString Locale.en kwd 7 ("KWD" ++ nbsp ++ "0.007")
            , writing Money.toString Locale.en clf 123456 ("CLF" ++ nbsp ++ "12.3456")
            , writing Money.toString Locale.en Money.nok 100 ("NOK" ++ nbsp ++ "1.00")
            , writing Money.toString Locale.en Money.nok maxMinor ("NOK" ++ nbsp ++ "90,071,992,547,409.91")
            ]
        , describe "toSymbolString: with the symbol"
            [ writing Money.toSymbolString Locale.nb Money.nok 123450 ("1" ++ nbsp ++ "234,50" ++ nbsp ++ "kr")
            , writing Money.toSymbolString Locale.en Money.usd 123450 "$1,234.50"
            , writing Money.toSymbolString Locale.en Money.usd -123450 "−$1,234.50"
            , writing Money.toSymbolString Locale.en Money.eur 123450 "€1,234.50"
            , writing Money.toSymbolString Locale.nb Money.eur 123450 ("1" ++ nbsp ++ "234,50" ++ nbsp ++ "€")
            , writing Money.toSymbolString Locale.en Money.nok 123450 ("kr" ++ nbsp ++ "1,234.50")
            , writing Money.toSymbolString Locale.en Money.chf 123450 ("CHF" ++ nbsp ++ "1,234.50")
            , writing Money.toSymbolString Locale.en Money.cny 123450 "CN¥1,234.50"
            ]
        , describe "toAmountString: only the number"
            [ writing Money.toAmountString Locale.nb Money.nok 123450 ("1" ++ nbsp ++ "234,50")
            , writing Money.toAmountString Locale.en Money.nok 123450 "1,234.50"
            , writing Money.toAmountString Locale.en Money.nok -123450 "−1,234.50"
            , writing Money.toAmountString Locale.en Money.jpy 1500 "1,500"
            , writing Money.toAmountString Locale.nb Money.nok 99 "0,99"
            ]
        , describe "toDecimalString: for machines"
            [ test "two decimals, a point, no grouping" <|
                \_ -> Expect.equal "1234.50" (Money.toDecimalString (amount Money.nok 123450))
            , test "a negative amount has an ASCII minus" <|
                \_ -> Expect.equal "-0.05" (Money.toDecimalString (amount Money.nok -5))
            , test "no decimals, no point" <|
                \_ -> Expect.equal "1500" (Money.toDecimalString (amount Money.jpy 1500))
            , test "three decimals" <|
                \_ -> Expect.equal "0.007" (Money.toDecimalString (amount kwd 7))
            , test "zero" <|
                \_ -> Expect.equal "0.00" (Money.toDecimalString (Money.zero Money.nok))
            ]
        ]


kwd : Currency
kwd =
    Money.currency "KWD" |> Maybe.withDefault Money.nok


clf : Currency
clf =
    Money.currency "CLF" |> Maybe.withDefault Money.nok


writing : (Locale -> Money -> String) -> Locale -> Currency -> Int -> String -> Test
writing write locale cur minor expected =
    test (Money.currencyCode cur ++ " " ++ String.fromInt minor ++ " in " ++ Locale.toCode locale) <|
        \_ -> Expect.equal expected (write locale (amount cur minor))



-- READING


parsingTests : Test
parsingTests =
    describe "parse"
        [ describe "Norwegian"
            [ reads Locale.nb Money.nok "1 234,50" 123450
            , reads Locale.nb Money.nok ("1" ++ nbsp ++ "234,50") 123450
            , reads Locale.nb Money.nok "1234,5" 123450
            , reads Locale.nb Money.nok "1234" 123400
            , reads Locale.nb Money.nok "1 234" 123400
            , reads Locale.nb Money.nok "1.234,50" 123450
            , reads Locale.nb Money.nok "1.234.567,89" 123456789
            , reads Locale.nb Money.nok "1234.5" 123450
            , reads Locale.nb Money.nok "0,5" 50
            , reads Locale.nb Money.nok ",5" 50
            , reads Locale.nb Money.nok "12," 1200
            , reads Locale.nb Money.nok "12." 1200
            , reads Locale.nb Money.nok "0" 0
            , reads Locale.nb Money.nok "0,00" 0
            , reads Locale.nb Money.nok "  50  " 5000
            , reads Locale.nb Money.nok "+50" 5000
            , reads Locale.nb Money.nok "1'234.50" 123450
            , reads Locale.nb Money.nok "0,05" 5
            , reads Locale.nb Money.nok "007" 700
            ]
        , describe "English"
            [ reads Locale.en Money.nok "1,234.50" 123450
            , reads Locale.en Money.nok "1,234" 123400
            , reads Locale.en Money.nok "1,234,567" 123456700
            , reads Locale.en Money.nok "1234.5" 123450
            , reads Locale.en Money.nok "1,5" 150
            , reads Locale.en Money.nok "12,34" 1234
            , reads Locale.en Money.nok "0,500" 50
            , reads Locale.en Money.nok "1.234,50" 123450
            , reads Locale.en Money.nok "1 234.50" 123450
            , reads Locale.en Money.nok "12.100" 1210
            , reads Locale.en Money.nok "12.000" 1200
            , reads Locale.en Money.jpy "12.0" 12
            ]
        , describe "negative amounts"
            [ reads Locale.nb Money.nok "-5,25" -525
            , reads Locale.nb Money.nok "−5,25" -525
            , reads Locale.nb Money.nok "–5,25" -525
            , reads Locale.nb Money.nok "- 5,25" -525
            , reads Locale.nb Money.nok "(100)" -10000
            , reads Locale.nb Money.nok "(1 234,50)" -123450
            , reads Locale.en Money.nok "(1,234.50)" -123450
            , reads Locale.nb Money.nok "-0" 0
            , refuses Locale.en Money.nok "--5" "Must be an amount"
            , refuses Locale.en Money.nok "(-5)" "Must be an amount"
            , refuses Locale.en Money.nok "-(5)" "Must be an amount"
            , refuses Locale.en Money.nok "(5" "Must be an amount"
            , refuses Locale.en Money.nok "+-5" "Must be an amount"
            ]
        , describe "the currency around the amount"
            [ reads Locale.nb Money.nok "NOK 1 234,50" 123450
            , reads Locale.nb Money.nok "1 234,50 NOK" 123450
            , reads Locale.nb Money.nok "nok1234,5" 123450
            , reads Locale.nb Money.nok "kr 100" 10000
            , reads Locale.nb Money.nok "100 kr" 10000
            , reads Locale.nb Money.nok "100 KR" 10000
            , reads Locale.nb Money.nok "kr. 100" 10000
            , reads Locale.nb Money.nok "100,-" 10000
            , reads Locale.nb Money.nok "1 234,-" 123400
            , reads Locale.nb Money.nok "1.234,-" 123400
            , reads Locale.nb Money.nok "kr 1 234,-" 123400
            , reads Locale.nb Money.nok "1 234,- kr" 123400
            , reads Locale.nb Money.nok "-kr 100" -10000
            , reads Locale.nb Money.nok "kr -100" -10000
            , reads Locale.nb Money.nok "(kr 100)" -10000
            , reads Locale.en Money.usd "$1,234.50" 123450
            , reads Locale.en Money.usd "US$ 1,234.50" 123450
            , reads Locale.en Money.usd "-$5" -500
            , reads Locale.en Money.eur "€5" 500
            , reads Locale.en Money.eur "5 €" 500
            , reads Locale.en Money.jpy "¥1,500" 1500
            , reads Locale.en Money.jpy "1500円" 1500
            , reads Locale.en Money.cad "$5" 500
            , reads Locale.en Money.cad "CA$5" 500
            , refuses Locale.en Money.nok "$100" "Must be an amount"
            , refuses Locale.en Money.usd "100 NOK" "Must be an amount"
            , refuses Locale.en Money.nok "100 EUR" "Must be an amount"
            , refuses Locale.en Money.nok "€100" "Must be an amount"
            , refuses Locale.en Money.nok "NOK 100 NOK" "Must be an amount"
            , refuses Locale.en Money.nok "kr 100 kr" "Must be an amount"
            , refuses Locale.en Money.nok "NOK" "Must be an amount"
            ]
        , describe "text that is not an amount"
            [ refuses Locale.nb Money.nok "" "Enter an amount"
            , refuses Locale.nb Money.nok "   " "Enter an amount"
            , refuses Locale.en Money.nok "abc" "Must be an amount"
            , refuses Locale.en Money.nok "12abc" "Must be an amount"
            , refuses Locale.en Money.nok "1e5" "Must be an amount"
            , refuses Locale.en Money.nok "-" "Must be an amount"
            , refuses Locale.en Money.nok "," "Must be an amount"
            , refuses Locale.en Money.nok "." "Must be an amount"
            , refuses Locale.en Money.nok "(" "Must be an amount"
            , refuses Locale.en Money.nok "12-5" "Must be an amount"
            , refuses Locale.en Money.nok "NaN" "Must be an amount"
            , refuses Locale.en Money.nok "Infinity" "Must be an amount"
            , refuses Locale.en Money.nok "0x10" "Must be an amount"
            , refuses Locale.en Money.nok "١٢٣" "Must be an amount"
            ]
        , describe "separators that can not be read"
            [ refuses Locale.en Money.nok "1.2.3" "The separators are unclear: write the amount with one decimal separator"
            , refuses Locale.en Money.nok "1,2,3" "The separators are unclear: write the amount with one decimal separator"
            , refuses Locale.en Money.nok "1,234,56" "The separators are unclear: write the amount with one decimal separator"
            , refuses Locale.en Money.nok "1.23.456" "The separators are unclear: write the amount with one decimal separator"
            , refuses Locale.en Money.nok "12.345,67.8" "The separators are unclear: write the amount with one decimal separator"
            , refuses Locale.en Money.nok "1,23.45" "The separators are unclear: write the amount with one decimal separator"
            , refuses Locale.en Money.nok "1.234.5,-" "The separators are unclear: write the amount with one decimal separator"
            ]
        , describe "more decimals than the currency has: never rounded"
            [ refuses Locale.en Money.nok "12.505" "NOK has 2 decimals"
            , refuses Locale.nb Money.nok "12,505" "NOK has 2 decimals"
            , refuses Locale.nb Money.nok "1,234" "NOK has 2 decimals"
            , refuses Locale.en Money.nok "0.001" "NOK has 2 decimals"
            , refuses Locale.en Money.jpy "1.5" "JPY has no decimals"
            , refuses Locale.nb Money.jpy "1,500" "JPY has no decimals"
            , refuses Locale.en kwd "1.2345" "KWD has 3 decimals"
            , refuses Locale.en clf "1.23456" "CLF has 4 decimals"
            , test "in Norwegian the same problem has a Norwegian text" <|
                \_ ->
                    Money.parse Locale.nb Money.nok "12,505"
                        |> Result.mapError (Money.problemText Locale.nb)
                        |> Expect.equal (Err "NOK har 2 desimaler")
            ]
        , describe "a currency with three decimals"
            [ reads Locale.en kwd "1234.567" 1234567
            , reads Locale.en kwd "1,234.567" 1234567
            , reads Locale.nb kwd "1 234,567" 1234567
            , reads Locale.nb kwd "1.234,567" 1234567
            , reads Locale.nb kwd "12,5" 12500
            , reads Locale.en kwd "12.5" 12500
            , reads Locale.en kwd "0,500" 500
            , reads Locale.en kwd "1.234" 1234
            , reads Locale.nb kwd "1,234" 1234
            , reads Locale.en kwd "1234" 1234000
            , reads Locale.en kwd "1,234,567" 1234567000
            , refuses Locale.en kwd "1,234" "The separators are unclear: write the amount with one decimal separator"
            , refuses Locale.en kwd "12,345" "The separators are unclear: write the amount with one decimal separator"
            , refuses Locale.en kwd "123,456" "The separators are unclear: write the amount with one decimal separator"
            ]
        , describe "no decimals"
            [ reads Locale.en Money.jpy "1500" 1500
            , reads Locale.en Money.jpy "1,500" 1500
            , reads Locale.nb Money.jpy "1 500" 1500
            , reads Locale.en Money.jpy "1,500,000" 1500000
            , reads Locale.en Money.jpy "1500." 1500
            ]
        , describe "out of range"
            [ reads Locale.en Money.nok "90071992547409.91" maxMinor
            , reads Locale.en Money.nok "-90071992547409.91" -maxMinor
            , refuses Locale.en Money.nok "90071992547409.92" "The amount is too large"
            , refuses Locale.en Money.nok "-90071992547409.92" "The amount is too large"
            , refuses Locale.en Money.nok "123456789012345678" "The amount is too large"
            , refuses Locale.en Money.nok "999999999999999999999999999999" "The amount is too large"
            , refuses Locale.en Money.jpy "9007199254740992" "The amount is too large"
            , reads Locale.en Money.jpy "9007199254740991" maxMinor
            , reads Locale.en Money.nok "0000000000000000000000000012.50" 1250
            ]
        , fuzz Fuzz.string "reading any text never crashes, and an amount that is read is inside the range" <|
            \text ->
                case Money.parse Locale.en Money.nok text of
                    Ok money ->
                        Expect.atMost maxMinor (Basics.abs (Money.toMinor money))

                    Err _ ->
                        Expect.pass
        ]


reads : Locale -> Currency -> String -> Int -> Test
reads locale cur text expected =
    test (Locale.toCode locale ++ " " ++ Money.currencyCode cur ++ " " ++ quote text ++ " is " ++ String.fromInt expected) <|
        \_ -> Expect.equal (Ok expected) (minorOf (Money.parse locale cur text))


refuses : Locale -> Currency -> String -> String -> Test
refuses locale cur text message =
    test (Locale.toCode locale ++ " " ++ Money.currencyCode cur ++ " " ++ quote text ++ " is refused") <|
        \_ ->
            Money.parse locale cur text
                |> Result.map Money.toMinor
                |> Result.mapError (Money.problemText Locale.en)
                |> Expect.equal (Err message)


quote : String -> String
quote text =
    "\"" ++ text ++ "\""


roundingParseTests : Test
roundingParseTests =
    describe "parseRounded: half away from zero"
        [ rounds Locale.en Money.nok "12.505" 1251
        , rounds Locale.en Money.nok "12.504" 1250
        , rounds Locale.en Money.nok "12.5049999" 1250
        , rounds Locale.en Money.nok "12.5050001" 1251
        , rounds Locale.en Money.nok "-12.505" -1251
        , rounds Locale.en Money.nok "-12.504" -1250
        , rounds Locale.en Money.nok "0.005" 1
        , rounds Locale.en Money.nok "0.004" 0
        , rounds Locale.en Money.nok "-0.005" -1
        , rounds Locale.en Money.nok "-0.004" 0
        , rounds Locale.en Money.nok "99.995" 10000
        , rounds Locale.en Money.nok "99.994" 9999
        , rounds Locale.nb Money.nok "12,5" 1250
        , rounds Locale.nb Money.nok "1 234,5678" 123457
        , rounds Locale.en Money.jpy "0.5" 1
        , rounds Locale.en Money.jpy "0.49" 0
        , rounds Locale.en Money.jpy "-2.5" -3
        , rounds Locale.en kwd "1.2345" 1235
        , test "rounding up past the limit is refused, not wrapped" <|
            \_ ->
                Money.parseRounded Locale.en Money.nok "90071992547409.915"
                    |> Result.mapError (Money.problemText Locale.en)
                    |> Result.map Money.toMinor
                    |> Expect.equal (Err "The amount is too large")
        , test "what is not an amount is still refused" <|
            \_ ->
                Expect.equal
                    (Money.parse Locale.en Money.nok "abc" |> Result.map Money.toMinor)
                    (Money.parseRounded Locale.en Money.nok "abc" |> Result.map Money.toMinor)
        ]


rounds : Locale -> Currency -> String -> Int -> Test
rounds locale cur text expected =
    test (Locale.toCode locale ++ " " ++ Money.currencyCode cur ++ " " ++ quote text ++ " rounds to " ++ String.fromInt expected) <|
        \_ -> Expect.equal (Ok expected) (minorOf (Money.parseRounded locale cur text))



-- ROUND TRIPS


roundTripTests : Test
roundTripTests =
    describe "what is written is read again"
        [ fuzz3 localeFuzzer currencyFuzzer anyMinor "toAmountString" <|
            \locale cur minor ->
                Money.parse locale cur (Money.toAmountString locale (amount cur minor))
                    |> Expect.equal (Ok (amount cur minor))
        , fuzz3 localeFuzzer currencyFuzzer anyMinor "toString, with the code" <|
            \locale cur minor ->
                Money.parse locale cur (Money.toString locale (amount cur minor))
                    |> Expect.equal (Ok (amount cur minor))
        , fuzz3 localeFuzzer currencyFuzzer anyMinor "toSymbolString, with the symbol" <|
            \locale cur minor ->
                Money.parse locale cur (Money.toSymbolString locale (amount cur minor))
                    |> Expect.equal (Ok (amount cur minor))
        , fuzz2 currencyFuzzer anyMinor "toDecimalString and fromDecimalString" <|
            \cur minor ->
                Money.fromDecimalString cur (Money.toDecimalString (amount cur minor))
                    |> Expect.equal (Ok (amount cur minor))
        , fuzz2 currencyFuzzer anyMinor "toDecimalString is read by parse in English" <|
            \cur minor ->
                Money.parse Locale.en cur (Money.toDecimalString (amount cur minor))
                    |> Expect.equal (Ok (amount cur minor))
        , fuzz2 currencyFuzzer smallMinor "the amount written in English is the one in Norwegian with the separators swapped" <|
            \cur minor ->
                let
                    swapped =
                        Money.toAmountString Locale.en (amount cur minor)
                            |> String.map
                                (\c ->
                                    if c == ',' then
                                        '\u{00A0}'

                                    else
                                        c
                                )
                            |> String.replace "." ","
                in
                Expect.equal swapped (Money.toAmountString Locale.nb (amount cur minor))
        ]



-- MACHINE TEXT


machineTextTests : Test
machineTextTests =
    describe "fromDecimalString"
        [ test "reads what a machine writes" <|
            \_ ->
                Expect.equal [ Ok 123450, Ok 123450, Ok -50, Ok 5, Ok 100, Ok 0 ]
                    [ minorOf (Money.fromDecimalString Money.nok "1234.50")
                    , minorOf (Money.fromDecimalString Money.nok "1234.5")
                    , minorOf (Money.fromDecimalString Money.nok "-0.5")
                    , minorOf (Money.fromDecimalString Money.nok "0.05")
                    , minorOf (Money.fromDecimalString Money.nok "1")
                    , minorOf (Money.fromDecimalString Money.nok "-0")
                    ]
        , test "is strict: no grouping, no comma, no sign but a minus, no currency, no spaces" <|
            \_ ->
                [ "1,234.50", "1 234.50", "1234,50", "+5", "NOK 5", " 5", "5 ", "", "-", ".", "5.", ".5", "1.2.3", "--5", "1e3", "٣" ]
                    |> List.filterMap (\text -> Money.fromDecimalString Money.nok text |> Result.toMaybe)
                    |> List.length
                    |> Expect.equal 0
        , test "does not round" <|
            \_ ->
                Money.fromDecimalString Money.nok "1.005"
                    |> Result.mapError (Money.problemText Locale.en)
                    |> Result.map Money.toMinor
                    |> Expect.equal (Err "NOK has 2 decimals")
        , test "refuses what is too large" <|
            \_ ->
                Money.fromDecimalString Money.nok "90071992547409.92"
                    |> Result.mapError (Money.problemText Locale.en)
                    |> Result.map Money.toMinor
                    |> Expect.equal (Err "The amount is too large")
        ]



-- ARITHMETIC


arithmeticTests : Test
arithmeticTests =
    describe "adding and subtracting"
        [ test "add" <|
            \_ -> Expect.equal (Ok 15000) (minorOf (Money.add (amount Money.nok 12550) (amount Money.nok 2450)))
        , test "add a negative amount" <|
            \_ -> Expect.equal (Ok 10100) (minorOf (Money.add (amount Money.nok 12550) (amount Money.nok -2450)))
        , test "subtract" <|
            \_ -> Expect.equal (Ok -5000) (minorOf (Money.subtract (amount Money.nok 7550) (amount Money.nok 12550)))
        , test "the result of add is in the currency of its arguments" <|
            \_ ->
                Money.add (amount Money.jpy 5) (amount Money.jpy 6)
                    |> Result.map Money.currencyOf
                    |> Expect.equal (Ok Money.jpy)
        , test "adding amounts in different currencies is refused, in both orders and for subtract" <|
            \_ ->
                Expect.equal
                    [ Err "Can not mix NOK and EUR", Err "Can not mix EUR and NOK", Err "Can not mix NOK and EUR" ]
                    [ minorOf (Money.add (amount Money.nok 1000) (amount Money.eur 1000))
                    , minorOf (Money.add (amount Money.eur 1000) (amount Money.nok 1000))
                    , minorOf (Money.subtract (amount Money.nok 1000) (amount Money.eur 1000))
                    ]
        , test "the refusal is in Norwegian when asked in Norwegian" <|
            \_ ->
                Money.add (amount Money.nok 1000) (amount Money.eur 1000)
                    |> Result.mapError (Money.problemText Locale.nb)
                    |> Result.map Money.toMinor
                    |> Expect.equal (Err "Kan ikke blande NOK og EUR")
        , test "two currencies with the same decimals are still different" <|
            \_ ->
                Expect.equal True (Result.toMaybe (Money.add (amount Money.usd 1) (amount Money.eur 1)) == Nothing)
        , test "a sum beyond the exact range is refused" <|
            \_ ->
                Expect.equal [ Err "The amount is too large", Err "The amount is too large", Ok maxMinor ]
                    [ minorOf (Money.add (amount Money.nok maxMinor) (amount Money.nok 1))
                    , minorOf (Money.subtract (amount Money.nok -maxMinor) (amount Money.nok 1))
                    , minorOf (Money.add (amount Money.nok (maxMinor - 1)) (amount Money.nok 1))
                    ]
        , test "a difference that is zero is exactly zero" <|
            \_ ->
                Money.subtract (amount Money.nok 5) (amount Money.nok 5)
                    |> Expect.equal (Ok (Money.zero Money.nok))
        , fuzz2 smallMinor smallMinor "add and subtract undo each other" <|
            \a b ->
                Money.add (amount Money.nok a) (amount Money.nok b)
                    |> Result.andThen (\total -> Money.subtract total (amount Money.nok b))
                    |> Expect.equal (Ok (amount Money.nok a))
        , fuzz2 smallMinor smallMinor "add is commutative" <|
            \a b ->
                Expect.equal (Money.add (amount Money.nok a) (amount Money.nok b)) (Money.add (amount Money.nok b) (amount Money.nok a))
        , describe "sum"
            [ test "of nothing is zero in the given currency" <|
                \_ -> Expect.equal (Ok (Money.zero Money.eur)) (Money.sum Money.eur [])
            , test "of several amounts" <|
                \_ -> Expect.equal (Ok 600) (minorOf (Money.sum Money.nok [ amount Money.nok 100, amount Money.nok 200, amount Money.nok 300 ]))
            , test "is refused when one amount is in another currency" <|
                \_ -> Expect.equal (Err "Can not mix NOK and EUR") (minorOf (Money.sum Money.nok [ amount Money.nok 100, amount Money.eur 200 ]))
            , test "of amounts in another currency than the one given is refused" <|
                \_ -> Expect.equal True (Result.toMaybe (Money.sum Money.nok [ amount Money.eur 200 ]) == Nothing)
            , fuzz (Fuzz.list smallMinor) "equals the sum of the minor units" <|
                \minors ->
                    Money.sum Money.nok (List.map (amount Money.nok) minors)
                        |> Result.map Money.toMinor
                        |> Expect.equal (Ok (List.sum minors))
            ]
        , describe "multiply"
            [ test "three of an article" <|
                \_ -> Expect.equal (Ok 37650) (minorOf (Money.multiply 3 (amount Money.nok 12550)))
            , test "zero times is zero, and not negative zero" <|
                \_ ->
                    Expect.equal [ "0", "0" ]
                        [ minorOf (Money.multiply 0 (amount Money.nok -5)) |> Result.map String.fromInt |> Result.withDefault "?"
                        , Money.multiply 0 (amount Money.nok -5) |> Result.map (\money -> String.fromInt (Money.toMinor money)) |> Result.withDefault "?"
                        ]
            , test "a negative factor" <|
                \_ -> Expect.equal (Ok -2500) (minorOf (Money.multiply -5 (amount Money.nok 500)))
            , test "a result beyond the exact range is refused" <|
                \_ ->
                    Expect.equal [ Err "The amount is too large", Err "The amount is too large", Ok maxMinor ]
                        [ minorOf (Money.multiply 2 (amount Money.nok maxMinor))
                        , minorOf (Money.multiply 1000000000 (amount Money.nok 1000000000000))
                        , minorOf (Money.multiply 1 (amount Money.nok maxMinor))
                        ]
            ]
        , describe "negate and abs"
            [ test "negate" <|
                \_ -> Expect.equal [ -5, 5, 0 ] (List.map (Money.negate >> Money.toMinor) [ amount Money.nok 5, amount Money.nok -5, Money.zero Money.nok ])
            , test "negating zero gives zero" <|
                \_ -> Expect.equal (Money.zero Money.nok) (Money.negate (Money.zero Money.nok))
            , test "abs" <|
                \_ -> Expect.equal [ 5, 5, 0 ] (List.map (Money.abs >> Money.toMinor) [ amount Money.nok 5, amount Money.nok -5, Money.zero Money.nok ])
            , test "the signs" <|
                \_ ->
                    Expect.equal [ ( True, False, False ), ( False, True, False ), ( False, False, True ) ]
                        (List.map (\money -> ( Money.isPositive money, Money.isNegative money, Money.isZero money ))
                            [ amount Money.nok 1, amount Money.nok -1, amount Money.nok 0 ]
                        )
            ]
        ]



-- FRACTIONS


fractionTests : Test
fractionTests =
    describe "percentOf and fraction"
        [ describe "a half goes away from zero"
            [ fractionOf (Money.percentOf 25) 123450 30863
            , fractionOf (Money.percentOf 25) -123450 -30863
            , fractionOf (Money.percentOf 25) 123449 30862
            , fractionOf (Money.percentOf 25) 123451 30863
            , fractionOf (Money.percentOf 50) 1 1
            , fractionOf (Money.percentOf 50) -1 -1
            , fractionOf (Money.percentOf 50) 3 2
            , fractionOf (Money.percentOf 50) 2 1
            , fractionOf (Money.percentOf 1) 49 0
            , fractionOf (Money.percentOf 1) 50 1
            , fractionOf (Money.percentOf 1) -49 0
            , fractionOf (Money.percentOf 1) -50 -1
            , fractionOf (Money.percentOf 100) 12345 12345
            , fractionOf (Money.percentOf 0) 12345 0
            , fractionOf (Money.percentOf 15) 1000 150
            , fractionOf (Money.fraction 3 8) 100 38
            , fractionOf (Money.fraction 3 8) 101 38
            , fractionOf (Money.fraction 3 8) 99 37
            , fractionOf (Money.fraction 3 8) -100 -38
            , fractionOf (Money.fraction 125 1000) 1000 125
            , fractionOf (Money.fraction 125 1000) 12345 1543
            , fractionOf (Money.fraction 1 3) 100 33
            , fractionOf (Money.fraction 2 3) 100 67
            , fractionOf (Money.fraction 2 3) -100 -67
            , fractionOf (Money.fraction -1 2) 5 -3
            , fractionOf (Money.fraction -1 2) -5 3
            , fractionOf (Money.fraction 1 2) 0 0
            ]
        , test "the VAT inside a price that includes 25 percent VAT" <|
            \_ -> Expect.equal (Ok 2500) (minorOf (Money.fraction 25 125 (amount Money.nok 12500)))
        , test "a denominator that is not above zero is refused" <|
            \_ ->
                Expect.equal [ Err "The denominator must be above 0", Err "The denominator must be above 0" ]
                    [ minorOf (Money.fraction 1 0 (amount Money.nok 5))
                    , minorOf (Money.fraction 1 -2 (amount Money.nok 5))
                    ]
        , test "the largest amount, halved, rounds the half up" <|
            \_ -> Expect.equal (Ok 4503599627370496) (minorOf (Money.fraction 1 2 (amount Money.nok maxMinor)))
        , test "a quarter of the largest amount is exact where the product would not be" <|
            \_ -> Expect.equal (Ok 2251799813685248) (minorOf (Money.percentOf 25 (amount Money.nok maxMinor)))
        , test "the whole of it, and the same with a negative amount" <|
            \_ ->
                Expect.equal [ Ok maxMinor, Ok -maxMinor ]
                    [ minorOf (Money.percentOf 100 (amount Money.nok maxMinor))
                    , minorOf (Money.percentOf 100 (amount Money.nok -maxMinor))
                    ]
        , test "more than the whole of the largest amount is refused" <|
            \_ ->
                Expect.equal [ Err "The amount is too large", Err "The amount is too large" ]
                    [ minorOf (Money.percentOf 101 (amount Money.nok maxMinor))
                    , minorOf (Money.fraction 3 2 (amount Money.nok -maxMinor))
                    ]
        , test "a numerator and denominator whose product leaves the exact range are refused" <|
            \_ -> Expect.equal (Err "The amount is too large") (minorOf (Money.fraction 4000000000000 5000000000000 (amount Money.nok 99999999999)))
        , fuzz3 (Fuzz.intRange 0 1000000000) (Fuzz.intRange 0 1000) (Fuzz.intRange 1 1000) "equals the exact value rounded half up, for amounts with a known answer" <|
            \minor numerator denominator ->
                let
                    -- floor ((2 * product + denominator) / (2 * denominator)), in one go
                    top =
                        2 * (minor * numerator) + denominator

                    bottom =
                        2 * denominator

                    expected =
                        round (toFloat (top - remainderBy bottom top) / toFloat bottom)
                in
                Money.fraction numerator denominator (amount Money.nok minor)
                    |> minorOf
                    |> Expect.equal (Ok expected)
        , fuzz3 (Fuzz.intRange 0 1000000000) (Fuzz.intRange -1000 1000) (Fuzz.intRange 1 1000) "is the same size for a negative amount and a positive one" <|
            \minor numerator denominator ->
                let
                    positive =
                        Money.fraction numerator denominator (amount Money.nok minor) |> Result.map Money.toMinor

                    negative =
                        Money.fraction numerator denominator (amount Money.nok (Basics.negate minor)) |> Result.map Money.toMinor
                in
                Expect.equal (Result.map Basics.negate positive) negative
        , test "the arithmetic itself: a * n / d without leaving the range" <|
            \_ ->
                Expect.equal [ Just 2251799813685248, Just 0, Just 1, Nothing ]
                    [ Arithmetic.mulDivRound maxMinor 25 100
                    , Arithmetic.mulDivRound 0 5 3
                    , Arithmetic.mulDivRound 1 1 2
                    , Arithmetic.mulDivRound maxMinor 2 1
                    ]
        ]


fractionOf : (Money -> Result Money.Problem Money) -> Int -> Int -> Test
fractionOf calculate minor expected =
    test (String.fromInt minor ++ " gives " ++ String.fromInt expected) <|
        \_ -> Expect.equal (Ok expected) (minorOf (calculate (amount Money.nok minor)))



-- ALLOCATION


allocationTests : Test
allocationTests =
    describe "allocate and split"
        [ describe "known answers"
            [ splits [ 1, 1, 1 ] 10000 [ 3334, 3333, 3333 ]
            , splits [ 1, 1, 1 ] -10000 [ -3334, -3333, -3333 ]
            , splits [ 50, 30, 20 ] 10000 [ 5000, 3000, 2000 ]
            , splits [ 1, 2 ] 10 [ 3, 7 ]
            , splits [ 2, 1 ] 10 [ 7, 3 ]
            , splits [ 1, 1 ] 5 [ 3, 2 ]
            , splits [ 1, 1, 1 ] 1 [ 1, 0, 0 ]
            , splits [ 1, 1, 1 ] 2 [ 1, 1, 0 ]
            , splits [ 1, 1, 1 ] 0 [ 0, 0, 0 ]
            , splits [ 5 ] 12345 [ 12345 ]
            , splits [ 0, 1, 0 ] 100 [ 0, 100, 0 ]
            , splits [ 0, 1, 1 ] 101 [ 0, 51, 50 ]
            , splits [ 3, 7 ] 99 [ 30, 69 ]
            , splits [ 1, 1, 1, 1, 1, 1, 1 ] 100 [ 15, 15, 14, 14, 14, 14, 14 ]
            , splits [ 33, 33, 34 ] 100 [ 33, 33, 34 ]
            , splits [ 1, 1, 1 ] maxMinor [ 3002399751580331, 3002399751580330, 3002399751580330 ]
            , splits [ 1, 1 ] maxMinor [ 4503599627370496, 4503599627370495 ]
            , splits [ 1, 1 ] -maxMinor [ -4503599627370496, -4503599627370495 ]
            ]
        , test "split is allocate with equal weights" <|
            \_ ->
                Expect.equal
                    (Money.allocate [ 1, 1, 1, 1 ] (amount Money.nok 1001) |> Result.map (List.map Money.toMinor))
                    (Money.split 4 (amount Money.nok 1001) |> Result.map (List.map Money.toMinor))
        , test "100.00 in three" <|
            \_ ->
                Money.split 3 (amount Money.nok 10000)
                    |> Result.map (List.map (Money.toAmountString Locale.en))
                    |> Expect.equal (Ok [ "33.34", "33.33", "33.33" ])
        , test "the parts are in the currency of the amount" <|
            \_ ->
                Money.split 3 (amount Money.jpy 100)
                    |> Result.map (List.map Money.currencyOf)
                    |> Expect.equal (Ok [ Money.jpy, Money.jpy, Money.jpy ])
        , test "no weights, a negative weight and weights that are all zero are refused" <|
            \_ ->
                Expect.equal (List.repeat 4 (Err "Needs at least one share, none negative, and not all 0"))
                    [ allocated [] 100
                    , allocated [ 1, -1 ] 100
                    , allocated [ 0, 0 ] 100
                    , allocated [ -1 ] 100
                    ]
        , test "split into no parts, or too many, is refused" <|
            \_ ->
                Expect.equal [ True, True, True ]
                    [ Result.toMaybe (Money.split 0 (amount Money.nok 100)) == Nothing
                    , Result.toMaybe (Money.split -3 (amount Money.nok 100)) == Nothing
                    , Result.toMaybe (Money.split 100001 (amount Money.nok 100)) == Nothing
                    ]
        , test "weights so large that the working leaves the exact range are refused" <|
            \_ ->
                Expect.equal [ Err "The amount is too large", Err "The amount is too large" ]
                    [ allocated [ 5000000000000000, 5000000000000000 ] 100
                    , allocated [ 1000000000, 1000000000 ] 99999999999999
                    ]
        , test "many parts" <|
            \_ ->
                case Money.split 10000 (amount Money.nok 1234567) of
                    Ok parts ->
                        Expect.equal ( 10000, 1234567 ) ( List.length parts, List.sum (List.map Money.toMinor parts) )

                    Err _ ->
                        Expect.fail "10000 parts should be possible"
        , fuzz2 smallMinor (Fuzz.listOfLengthBetween 1 8 (Fuzz.intRange 0 1000)) "the parts add up to the amount, and no unit is lost or made" <|
            \minor weights ->
                case Money.allocate weights (amount Money.nok minor) of
                    Ok parts ->
                        Expect.equal minor (List.sum (List.map Money.toMinor parts))

                    Err _ ->
                        -- only weights that are all zero
                        Expect.equal 0 (List.sum weights)
        , fuzz2 smallMinor (Fuzz.listOfLengthBetween 1 8 (Fuzz.intRange 0 1000)) "there is a part for each weight, and a part is never further than one unit from its exact share" <|
            \minor weights ->
                case Money.allocate weights (amount Money.nok minor) of
                    Ok parts ->
                        let
                            total =
                                List.sum weights

                            -- the exact share is minor * weight / total: the error of a part is
                            -- below one unit when |part * total - minor * weight| < total
                            fits ( part, weight ) =
                                Basics.abs (Money.toMinor part * total - minor * weight) < total
                        in
                        Expect.all
                            [ \_ -> Expect.equal (List.length weights) (List.length parts)
                            , \_ -> Expect.equal [] (List.filter (not << fits) (List.map2 Tuple.pair parts weights))
                            ]
                            ()

                    Err _ ->
                        Expect.equal 0 (List.sum weights)
        , fuzz2 smallMinor (Fuzz.listOfLengthBetween 1 8 (Fuzz.intRange 0 1000)) "a part with the weight 0 is 0, and no part has the opposite sign" <|
            \minor weights ->
                case Money.allocate weights (amount Money.nok minor) of
                    Ok parts ->
                        let
                            wrongSign part =
                                (minor >= 0 && Money.toMinor part < 0) || (minor <= 0 && Money.toMinor part > 0)

                            zeroWeightGotSomething ( part, weight ) =
                                weight == 0 && Money.toMinor part /= 0
                        in
                        Expect.equal ( [], [] )
                            ( List.filter wrongSign parts, List.filter zeroWeightGotSomething (List.map2 Tuple.pair parts weights) )

                    Err _ ->
                        Expect.equal 0 (List.sum weights)
        , fuzz2 smallMinor (Fuzz.intRange 1 50) "equal parts differ by at most one unit, the larger ones first" <|
            \minor count ->
                case Money.split count (amount Money.nok minor) of
                    Ok parts ->
                        let
                            minors =
                                List.map Money.toMinor parts

                            magnitudes =
                                List.map Basics.abs minors
                        in
                        Expect.all
                            [ \_ -> Expect.atMost 1 (Maybe.withDefault 0 (List.maximum magnitudes) - Maybe.withDefault 0 (List.minimum magnitudes))
                            , \_ -> Expect.equal (List.reverse (List.sort magnitudes)) magnitudes
                            ]
                            ()

                    Err _ ->
                        Expect.fail "a split into 1 to 50 parts is possible"
        , fuzz2 anyMinor (Fuzz.listOfLengthBetween 1 5 (Fuzz.intRange 1 100000)) "the parts add up also for the largest amounts" <|
            \minor weights ->
                case Money.allocate weights (amount Money.nok minor) of
                    Ok parts ->
                        Expect.equal minor (List.sum (List.map Money.toMinor parts))

                    Err _ ->
                        Expect.fail "weights of this size are possible"
        , fuzz2 (Fuzz.intRange 0 100000000) (Fuzz.listOfLengthBetween 1 6 (Fuzz.intRange 0 100)) "the arithmetic agrees with the amounts" <|
            \total weights ->
                Expect.equal
                    (Arithmetic.allocate total weights)
                    (Money.allocate weights (amount Money.nok total) |> Result.map (List.map Money.toMinor) |> Result.toMaybe)
        ]


splits : List Int -> Int -> List Int -> Test
splits weights minor expected =
    test ("[" ++ String.join ", " (List.map String.fromInt weights) ++ "] of " ++ String.fromInt minor) <|
        \_ -> Expect.equal (Ok expected) (allocated weights minor)


allocated : List Int -> Int -> Result String (List Int)
allocated weights minor =
    Money.allocate weights (amount Money.nok minor)
        |> Result.map (List.map Money.toMinor)
        |> Result.mapError (Money.problemText Locale.en)



-- COMPARING


comparingTests : Test
comparingTests =
    describe "compare"
        [ test "amounts in one currency are ordered by value" <|
            \_ ->
                [ amount Money.nok 500, amount Money.nok -5, amount Money.nok 0, amount Money.nok 20 ]
                    |> List.sortWith Money.compare
                    |> List.map Money.toMinor
                    |> Expect.equal [ -5, 0, 20, 500 ]
        , test "amounts in different currencies are ordered by code, and not by value" <|
            \_ ->
                [ amount Money.usd 1, amount Money.eur 1000, amount Money.nok 50, amount Money.eur 5 ]
                    |> List.sortWith Money.compare
                    |> List.map (\money -> ( Money.currencyCode (Money.currencyOf money), Money.toMinor money ))
                    |> Expect.equal [ ( "EUR", 5 ), ( "EUR", 1000 ), ( "NOK", 50 ), ( "USD", 1 ) ]
        , test "equal amounts are equal" <|
            \_ -> Expect.equal EQ (Money.compare (amount Money.nok 5) (amount Money.nok 5))
        , test "== means the same currency and the same amount" <|
            \_ ->
                Expect.equal [ True, False, False ]
                    [ amount Money.nok 5 == amount Money.nok 5
                    , amount Money.nok 5 == amount Money.eur 5
                    , amount Money.nok 5 == amount Money.nok 6
                    ]
        ]



-- RANGE


rangeTests : Test
rangeTests =
    describe "the exact range"
        [ test "the quotient of large numbers is exact where // would cut at 32 bits" <|
            \_ ->
                Expect.equal [ 90071992547409, 3002399751580330, 4503599627370495, 0 ]
                    [ Arithmetic.quotient maxMinor 100
                    , Arithmetic.quotient maxMinor 3
                    , Arithmetic.quotient maxMinor 2
                    , Arithmetic.quotient 5 7
                    ]
        , test "digits are read exactly right up to the largest exact number, where String.toInt is not" <|
            \_ ->
                Expect.equal [ Just 9007199254740991, Just 9007199254740992, Just 0, Just 12, Nothing, Nothing, Nothing, Nothing ]
                    [ Arithmetic.fromDigits "9007199254740991"
                    , Arithmetic.fromDigits "9007199254740992"
                    , Arithmetic.fromDigits "0000000000000000"
                    , Arithmetic.fromDigits "12"
                    , Arithmetic.fromDigits ""
                    , Arithmetic.fromDigits "12a"
                    , Arithmetic.fromDigits "-12"
                    , Arithmetic.fromDigits "12345678901234567"
                    ]
        , fuzz anyMinor "fromDigits agrees with the number it was written from" <|
            \minor ->
                Expect.equal (Just (Basics.abs minor)) (Arithmetic.fromDigits (String.fromInt (Basics.abs minor)))
        , fuzz2 (Fuzz.map Basics.abs anyMinor) (Fuzz.intRange 1 100000) "quotient and remainder put the number together again" <|
            \a b ->
                Expect.equal a (Arithmetic.quotient a b * b + remainderBy b a)
        , test "large amounts keep every digit when written" <|
            \_ ->
                Expect.equal "90071992547409.91" (Money.toDecimalString (amount Money.nok maxMinor))
        ]



-- TEXTS


problemTextTests : Test
problemTextTests =
    describe "problemText"
        [ test "every problem has a text in each language" <|
            \_ ->
                let
                    problems =
                        [ Money.parse Locale.en Money.nok ""
                        , Money.parse Locale.en Money.nok "x"
                        , Money.parse Locale.en Money.nok "1.234"
                        , Money.parse Locale.en Money.nok "1.2.3"
                        , Money.parse Locale.en Money.nok "999999999999999999"
                        , Money.add (Money.zero Money.nok) (Money.zero Money.eur)
                        , Money.split 0 (Money.zero Money.nok) |> Result.map List.head |> Result.map (Maybe.withDefault (Money.zero Money.nok))
                        , Money.fraction 1 0 (Money.zero Money.nok)
                        ]
                            |> List.filterMap
                                (\result ->
                                    case result of
                                        Err problem ->
                                            Just problem

                                        Ok _ ->
                                            Nothing
                                )

                    texts locale =
                        List.map (Money.problemText locale) problems
                in
                Expect.all
                    [ \_ -> Expect.equal 8 (List.length problems)
                    , \_ -> Expect.equal [] (List.filter ((==) "") (texts Locale.en ++ texts Locale.nb))
                    , \_ -> Expect.equal (List.length (texts Locale.en)) (Set.size (Set.fromList (texts Locale.en)))
                    , \_ -> Expect.equal (List.length (texts Locale.nb)) (Set.size (Set.fromList (texts Locale.nb)))
                    , \_ -> Expect.equal [] (List.filter identity (List.map2 (==) (texts Locale.en) (texts Locale.nb)))
                    ]
                    ()
        , test "the number of decimals is said right" <|
            \_ ->
                [ Money.jpy, Money.nok, kwd, clf ]
                    |> List.map (\cur -> Money.parse Locale.en cur "0.12345" |> Result.mapError (Money.problemText Locale.en))
                    |> List.map (Result.map Money.toMinor)
                    |> Expect.equal
                        [ Err "JPY has no decimals"
                        , Err "NOK has 2 decimals"
                        , Err "KWD has 3 decimals"
                        , Err "CLF has 4 decimals"
                        ]
        ]
