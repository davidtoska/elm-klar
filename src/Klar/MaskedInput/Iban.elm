module Klar.MaskedInput.Iban exposing
    ( countries
    , lengthOf
    )

{-| The countries that use IBANs, and how many characters an IBAN of each has.

The table follows the IBAN registry of SWIFT (ISO 13616): the country, then two check
digits, then the national account number, so the length is fixed for each country. A
country that joins the registry later is not here until this table is updated; an
IBAN from it is then reported as "no IBAN country".

French overseas territories use the code FR, and the Isle of Man, Jersey and
Guernsey use GB.

-}

import Dict exposing (Dict)


{-| The characters in an IBAN of a country, or `Nothing` for a country that has none.
-}
lengthOf : String -> Maybe Int
lengthOf country =
    Dict.get country lengths


lengths : Dict String Int
lengths =
    Dict.fromList countries


{-| Every country with its code and the length of its IBANs, sorted by code.
-}
countries : List ( String, Int )
countries =
    [ ( "AD", 24 )
    , ( "AE", 23 )
    , ( "AL", 28 )
    , ( "AT", 20 )
    , ( "AZ", 28 )
    , ( "BA", 20 )
    , ( "BE", 16 )
    , ( "BG", 22 )
    , ( "BH", 22 )
    , ( "BR", 29 )
    , ( "BY", 28 )
    , ( "CH", 21 )
    , ( "CR", 22 )
    , ( "CY", 28 )
    , ( "CZ", 24 )
    , ( "DE", 22 )
    , ( "DJ", 27 )
    , ( "DK", 18 )
    , ( "DO", 28 )
    , ( "DZ", 26 )
    , ( "EE", 20 )
    , ( "EG", 29 )
    , ( "ES", 24 )
    , ( "FI", 18 )
    , ( "FK", 18 )
    , ( "FO", 18 )
    , ( "FR", 27 )
    , ( "GB", 22 )
    , ( "GE", 22 )
    , ( "GI", 23 )
    , ( "GL", 18 )
    , ( "GR", 27 )
    , ( "GT", 28 )
    , ( "HR", 21 )
    , ( "HU", 28 )
    , ( "IE", 22 )
    , ( "IL", 23 )
    , ( "IQ", 23 )
    , ( "IS", 26 )
    , ( "IT", 27 )
    , ( "JO", 30 )
    , ( "KW", 30 )
    , ( "KZ", 20 )
    , ( "LB", 28 )
    , ( "LC", 32 )
    , ( "LI", 21 )
    , ( "LT", 20 )
    , ( "LU", 20 )
    , ( "LV", 21 )
    , ( "LY", 25 )
    , ( "MC", 27 )
    , ( "MD", 24 )
    , ( "ME", 22 )
    , ( "MK", 19 )
    , ( "MN", 20 )
    , ( "MR", 27 )
    , ( "MT", 31 )
    , ( "MU", 30 )
    , ( "NI", 28 )
    , ( "NL", 18 )
    , ( "NO", 15 )
    , ( "OM", 23 )
    , ( "PK", 24 )
    , ( "PL", 28 )
    , ( "PS", 29 )
    , ( "PT", 25 )
    , ( "QA", 29 )
    , ( "RO", 24 )
    , ( "RS", 22 )
    , ( "RU", 33 )
    , ( "SA", 24 )
    , ( "SC", 31 )
    , ( "SD", 18 )
    , ( "SE", 24 )
    , ( "SI", 19 )
    , ( "SK", 24 )
    , ( "SM", 27 )
    , ( "SO", 23 )
    , ( "ST", 25 )
    , ( "SV", 28 )
    , ( "TL", 23 )
    , ( "TN", 24 )
    , ( "TR", 26 )
    , ( "UA", 29 )
    , ( "VA", 22 )
    , ( "VG", 24 )
    , ( "XK", 20 )
    ]
