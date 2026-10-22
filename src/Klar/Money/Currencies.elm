module Klar.Money.Currencies exposing
    ( Entry
    , decimalsOf
    , entries
    , isActive
    , marks
    , symbolOf
    , withdrawn
    )

{-| The table of ISO 4217 currencies: the active alphabetic codes with the number of
digits of their minor unit (the "exponent"), the codes that were withdrawn recently
enough to be in data that is still used, and the symbols people write for the most
common currencies.

The active list follows "List one" of ISO 4217 as the maintenance agency (SIX)
published it on 2026-09-17. Not in it, on purpose: the precious metals (XAU, XAG, XPD,
XPT), the test code XTS, the "no currency" code XXX, the bond market units (XBA, XBB,
XBC, XBD), and the units of account that have no minor unit (XDR, XSU, XUA). They are
not money that anyone enters into a field. A currency that ISO has withdrawn is not in
`entries`; the two that ended most recently (ANG and BGN) are in `withdrawn`, so that
data that still has them can be read.

The tables are data in this file. `tests/MoneyTest.elm` checks that no code is there
twice and that every exponent is between 0 and 4.

-}

import Dict exposing (Dict)


{-| One currency: its code and the digits after the decimal point.
-}
type alias Entry =
    { code : String
    , decimals : Int
    }


{-| Every active currency, in the order of the codes.
-}
entries : List Entry
entries =
    (List.map (\code -> { code = code, decimals = 0 }) noDecimals
        ++ List.map (\code -> { code = code, decimals = 2 }) twoDecimals
        ++ List.map (\code -> { code = code, decimals = 3 }) threeDecimals
        ++ List.map (\code -> { code = code, decimals = 4 }) fourDecimals
    )
        |> List.sortBy .code


{-| Currencies that ISO 4217 has withdrawn, kept so that old data can be read: the
Netherlands Antillean guilder was replaced by the Caribbean guilder (XCG) on
2025-03-31, and Bulgaria joined the euro on 2026-01-01 (the lev ended 2025-12-31).
-}
withdrawn : List Entry
withdrawn =
    [ { code = "ANG", decimals = 2 }
    , { code = "BGN", decimals = 2 }
    ]


{-| The digits of the minor unit of a currency, active or withdrawn.
-}
decimalsOf : String -> Maybe Int
decimalsOf code =
    Dict.get code decimalTable


{-| Is the code on the active list?
-}
isActive : String -> Bool
isActive code =
    Dict.member code activeTable


decimalTable : Dict String Int
decimalTable =
    (entries ++ withdrawn)
        |> List.map (\entry -> ( entry.code, entry.decimals ))
        |> Dict.fromList


activeTable : Dict String Int
activeTable =
    entries
        |> List.map (\entry -> ( entry.code, entry.decimals ))
        |> Dict.fromList


{-| Currencies without a minor unit, or whose minor unit nobody uses.
-}
noDecimals : List String
noDecimals =
    [ "BIF", "CLP", "DJF", "GNF", "ISK", "JPY", "KMF", "KRW", "PYG", "RWF", "UGX", "UYI", "VND", "VUV", "XAF", "XOF", "XPF" ]


{-| HUF, MGA and MRU are listed with the exponent 2 that ISO 4217 gives them, although
their small units are not in use. XAD is the Arab Accounting Dinar.
-}
twoDecimals : List String
twoDecimals =
    [ "AED"
    , "AFN"
    , "ALL"
    , "AMD"
    , "AOA"
    , "ARS"
    , "AUD"
    , "AWG"
    , "AZN"
    , "BAM"
    , "BBD"
    , "BDT"
    , "BMD"
    , "BND"
    , "BOB"
    , "BOV"
    , "BRL"
    , "BSD"
    , "BTN"
    , "BWP"
    , "BYN"
    , "BZD"
    , "CAD"
    , "CDF"
    , "CHE"
    , "CHF"
    , "CHW"
    , "CNY"
    , "COP"
    , "COU"
    , "CRC"
    , "CUP"
    , "CVE"
    , "CZK"
    , "DKK"
    , "DOP"
    , "DZD"
    , "EGP"
    , "ERN"
    , "ETB"
    , "EUR"
    , "FJD"
    , "FKP"
    , "GBP"
    , "GEL"
    , "GHS"
    , "GIP"
    , "GMD"
    , "GTQ"
    , "GYD"
    , "HKD"
    , "HNL"
    , "HTG"
    , "HUF"
    , "IDR"
    , "ILS"
    , "INR"
    , "IRR"
    , "JMD"
    , "KES"
    , "KGS"
    , "KHR"
    , "KPW"
    , "KYD"
    , "KZT"
    , "LAK"
    , "LBP"
    , "LKR"
    , "LRD"
    , "LSL"
    , "MAD"
    , "MDL"
    , "MGA"
    , "MKD"
    , "MMK"
    , "MNT"
    , "MOP"
    , "MRU"
    , "MUR"
    , "MVR"
    , "MWK"
    , "MXN"
    , "MXV"
    , "MYR"
    , "MZN"
    , "NAD"
    , "NGN"
    , "NIO"
    , "NOK"
    , "NPR"
    , "NZD"
    , "PAB"
    , "PEN"
    , "PGK"
    , "PHP"
    , "PKR"
    , "PLN"
    , "QAR"
    , "RON"
    , "RSD"
    , "RUB"
    , "SAR"
    , "SBD"
    , "SCR"
    , "SDG"
    , "SEK"
    , "SGD"
    , "SHP"
    , "SLE"
    , "SOS"
    , "SRD"
    , "SSP"
    , "STN"
    , "SVC"
    , "SYP"
    , "SZL"
    , "THB"
    , "TJS"
    , "TMT"
    , "TOP"
    , "TRY"
    , "TTD"
    , "TWD"
    , "TZS"
    , "UAH"
    , "USD"
    , "USN"
    , "UYU"
    , "UZS"
    , "VED"
    , "VES"
    , "WST"
    , "XAD"
    , "XCD"
    , "XCG"
    , "YER"
    , "ZAR"
    , "ZMW"
    , "ZWG"
    ]


threeDecimals : List String
threeDecimals =
    [ "BHD", "IQD", "JOD", "KWD", "LYD", "OMR", "TND" ]


fourDecimals : List String
fourDecimals =
    [ "CLF", "UYW" ]



-- SYMBOLS


{-| The symbol a currency is written with, when there is one that people know. The
code is used otherwise.
-}
symbolOf : String -> String
symbolOf code =
    Dict.get code symbolTable |> Maybe.withDefault code


symbolTable : Dict String String
symbolTable =
    Dict.fromList
        [ ( "AUD", "A$" )
        , ( "BRL", "R$" )
        , ( "CAD", "CA$" )
        , ( "CNY", "CN¥" )
        , ( "CZK", "Kč" )
        , ( "DKK", "kr" )
        , ( "EUR", "€" )
        , ( "GBP", "£" )
        , ( "HKD", "HK$" )
        , ( "HUF", "Ft" )
        , ( "ILS", "₪" )
        , ( "INR", "₹" )
        , ( "ISK", "kr" )
        , ( "JPY", "¥" )
        , ( "KRW", "₩" )
        , ( "MXN", "MX$" )
        , ( "NGN", "₦" )
        , ( "NOK", "kr" )
        , ( "NZD", "NZ$" )
        , ( "PHP", "₱" )
        , ( "PLN", "zł" )
        , ( "RUB", "₽" )
        , ( "SEK", "kr" )
        , ( "SGD", "S$" )
        , ( "THB", "฿" )
        , ( "TRY", "₺" )
        , ( "TWD", "NT$" )
        , ( "UAH", "₴" )
        , ( "USD", "$" )
        , ( "VND", "₫" )
        , ( "ZAR", "R" )
        ]


{-| The strings that may stand around an amount that was pasted into a field of this
currency, longest first: the code, the symbol and the other ways it is written. Only
these are taken away when text is read, so an amount in another currency ("$100" in a
field for NOK) is never taken for one in this.
-}
marks : String -> List String
marks code =
    let
        symbol =
            symbolOf code

        others =
            Dict.get code alsoWritten |> Maybe.withDefault []
    in
    (code :: symbol :: others)
        |> List.filter (\mark -> mark /= "")
        |> List.sortBy (\mark -> negate (String.length mark))


alsoWritten : Dict String (List String)
alsoWritten =
    Dict.fromList
        [ ( "AUD", [ "AU$", "$" ] )
        , ( "CAD", [ "C$", "$" ] )
        , ( "CNY", [ "¥", "元", "RMB" ] )
        , ( "DKK", [ "kr.", "Kr.", "DKr" ] )
        , ( "HKD", [ "$" ] )
        , ( "ISK", [ "kr.", "ISKr" ] )
        , ( "JPY", [ "円", "￥" ] )
        , ( "MXN", [ "$", "Mex$" ] )
        , ( "NOK", [ "kr.", "NKr" ] )
        , ( "NZD", [ "$" ] )
        , ( "SEK", [ "kr.", "SKr" ] )
        , ( "SGD", [ "$" ] )
        , ( "USD", [ "US$" ] )
        ]
