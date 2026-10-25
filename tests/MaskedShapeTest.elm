module MaskedShapeTest exposing (suite)

{-| The logic behind `Klar.MaskedInput`, without a field around it: the check digits
against known numbers and numbers made by the algorithm, reading and writing in groups,
what typing does to the text, and the tiny pattern language.
-}

import Expect exposing (Expectation)
import Fuzz exposing (Fuzzer)
import Klar.MaskedInput.Checksum as Checksum
import Klar.MaskedInput.Iban as IbanTable
import Klar.MaskedInput.Phone as Phone
import Klar.MaskedInput.Shape as Shape exposing (Checksum(..), Shape(..), Slot(..))
import Set
import Test exposing (Test, describe, fuzz, fuzz2, test)


suite : Test
suite =
    describe "the logic of the masks"
        [ organisationNumberTests
        , bankAccountTests
        , ibanChecksumTests
        , gtinTests
        , nordicTests
        , ibanTableTests
        , readingTests
        , writingTests
        , phoneTests
        , typingTests
        , neverLosesTests
        , issueTests
        , patternTests
        , postalTests
        ]



-- THE SHAPES


organisation : Shape
organisation =
    Slots (digits 3 ++ [ Literal ' ' ] ++ digits 3 ++ [ Literal ' ' ] ++ digits 3) OrganisationNumber


account : Shape
account =
    Slots (digits 4 ++ [ Literal '.' ] ++ digits 2 ++ [ Literal '.' ] ++ digits 5) BankAccount


postalNo : Shape
postalNo =
    Slots (digits 4) NoChecksum


sku : Shape
sku =
    Slots [ Letter, Letter, Literal '-', Digit, Digit, Digit, Digit ] NoChecksum


digits : Int -> List Slot
digits n =
    List.repeat n Digit


{-| Writes a text the way the field would after typing it all at the end.
-}
typedAtEnd : Shape -> String -> String
typedAtEnd shape typed =
    Shape.afterTyping shape { typed = typed, caret = String.length typed }


{-| What the field shows after the value was typed one character at a time at the end.
-}
typeOneByOne : Shape -> String -> List String
typeOneByOne shape value =
    String.toList value
        |> List.foldl
            (\c ( shown, steps ) ->
                let
                    next =
                        typedAtEnd shape (shown ++ String.fromChar c)
                in
                ( next, steps ++ [ next ] )
            )
            ( "", [] )
        |> Tuple.second


{-| What the field shows after the value was deleted one character at a time from the
end, starting with the value written in its groups.
-}
deleteOneByOne : Shape -> String -> List String
deleteOneByOne shape value =
    List.foldl
        (\_ ( shown, steps ) ->
            let
                next =
                    typedAtEnd shape (String.dropRight 1 shown)
            in
            ( next, steps ++ [ next ] )
        )
        ( Shape.display shape value, [] )
        (String.toList value)
        |> Tuple.second



-- GENERATORS


digitString : Int -> Fuzzer String
digitString n =
    Fuzz.listOfLength n (Fuzz.intRange 0 9) |> Fuzz.map (List.map String.fromInt >> String.concat)


{-| The check digit that the weights give, made in the way the standard describes: the
sum of the products, 11 minus its remainder, 0 for a remainder of 0, none for 1.
-}
checkDigit : List Int -> String -> Maybe String
checkDigit weights body =
    let
        numbers =
            String.toList body |> List.map (\c -> Char.toCode c - 48)

        remainder =
            modBy 11 (List.sum (List.map2 (*) weights numbers))
    in
    if remainder == 0 then
        Just "0"

    else if remainder == 1 then
        Nothing

    else
        Just (String.fromInt (11 - remainder))


organisationNumbers : Fuzzer String
organisationNumbers =
    digitString 8
        |> Fuzz.map
            (\body ->
                checkDigit [ 3, 2, 7, 6, 5, 4, 3, 2 ] body |> Maybe.map ((++) body)
            )
        |> Fuzz.andThen
            (\maybe ->
                case maybe of
                    Just number ->
                        Fuzz.constant number

                    Nothing ->
                        Fuzz.constant "974760673"
            )


bankAccounts : Fuzzer String
bankAccounts =
    digitString 10
        |> Fuzz.map
            (\body ->
                checkDigit [ 5, 4, 3, 2, 7, 6, 5, 4, 3, 2 ] body |> Maybe.map ((++) body) |> Maybe.withDefault "86011117947"
            )


{-| An IBAN made for a country and a national account number, with the check digits
that the standard calls for: the remainder of the number (account, country, 00) by 97
is taken from 98.
-}
ibanFor : String -> String -> String
ibanFor country bban =
    let
        asNumbers text =
            String.toList text
                |> List.map
                    (\c ->
                        if Char.isDigit c then
                            String.fromChar c

                        else
                            String.fromInt (Char.toCode c - 55)
                    )
                |> String.concat

        remainder =
            String.foldl (\c r -> modBy 97 (r * 10 + (Char.toCode c - 48))) 0 (asNumbers (bban ++ country) ++ "00")

        check =
            98 - remainder
    in
    country ++ String.padLeft 2 '0' (String.fromInt check) ++ bban


{-| IBANs made for Norway and Germany from random national account numbers.
-}
madeIbans : Fuzzer String
madeIbans =
    Fuzz.oneOf
        [ digitString 11 |> Fuzz.map (ibanFor "NO")
        , digitString 18 |> Fuzz.map (ibanFor "DE")
        , digitString 13 |> Fuzz.map (\digitsOnly -> ibanFor "FR" (digitsOnly ++ "ABC1234567"))
        , digitString 6 |> Fuzz.map (\digitsOnly -> ibanFor "GB" ("NWBK" ++ digitsOnly ++ "12345678"))
        ]


phoneNumbers : Fuzzer String
phoneNumbers =
    Fuzz.oneOf
        [ digitString 7 |> Fuzz.map (\rest -> "+479" ++ rest)
        , digitString 7 |> Fuzz.map (\rest -> "+472" ++ rest)
        , digitString 10 |> Fuzz.map (\rest -> "+1" ++ rest)
        , digitString 8 |> Fuzz.map (\rest -> "+45" ++ rest)
        , digitString 9 |> Fuzz.map (\rest -> "+358" ++ rest)
        , digitString 9 |> Fuzz.map (\rest -> "+44" ++ rest)
        ]



-- ORGANISATION NUMBERS


organisationNumberTests : Test
organisationNumberTests =
    let
        known =
            [ ( "Brønnøysundregistrene", "974760673" )
            , ( "NAV", "889640782" )
            , ( "Skatteetaten", "974761076" )
            , ( "Equinor", "923609016" )
            , ( "DNB Bank", "984851006" )
            ]

        weights =
            [ 3, 2, 7, 6, 5, 4, 3, 2 ]
    in
    describe "the Norwegian organisation number (modulus 11)"
        [ describe "numbers of public organisations are right"
            (List.map (\( who, number ) -> test who <| \_ -> Expect.equal True (Checksum.mod11 weights number)) known)
        , describe "and a different last digit is wrong"
            (List.map
                (\( who, number ) ->
                    test who <|
                        \_ ->
                            List.range 0 9
                                |> List.map (\last -> String.dropRight 1 number ++ String.fromInt last)
                                |> List.filter (Checksum.mod11 weights)
                                |> Expect.equal [ number ]
                )
                known
            )
        , describe "and one wrong digit anywhere is wrong"
            (List.map
                (\( who, number ) ->
                    test who <|
                        \_ ->
                            List.range 0 8
                                |> List.concatMap
                                    (\position ->
                                        List.range 1 9
                                            |> List.map (\change -> alter position change number)
                                    )
                                |> List.filter (Checksum.mod11 weights)
                                |> Expect.equal []
                )
                known
            )
        , test "a number whose sum leaves 1 has no check digit at all" <|
            \_ ->
                -- 8 digits with a remainder of 1 for the weights (3 2 7 6 5 4 3 2): 1 * 3 = 3 ... find one
                let
                    bodies =
                        List.range 0 99999
                            |> List.map (\n -> String.padLeft 8 '0' (String.fromInt n))
                            |> List.filter (\body -> checkDigit weights body == Nothing)
                            |> List.take 20
                in
                Expect.all
                    [ \_ -> Expect.equal 20 (List.length bodies)
                    , \_ ->
                        bodies
                            |> List.concatMap (\body -> List.map (\last -> body ++ String.fromInt last) (List.range 0 9))
                            |> List.filter (Checksum.mod11 weights)
                            |> Expect.equal []
                    ]
                    ()
        , test "the wrong length, and text that is not digits, is wrong" <|
            \_ ->
                [ "", "97476067", "9747606733", "97476067a", " 974760673", "974-760-673" ]
                    |> List.filter (Checksum.mod11 weights)
                    |> Expect.equal []
        , fuzz organisationNumbers "a number made with the algorithm is right, in the mask too" <|
            \number ->
                Expect.equal [ True, True ]
                    [ Checksum.mod11 weights number
                    , Shape.issue organisation (Shape.read organisation number) == Nothing
                    ]
        ]


{-| The same digits with one changed by adding `change` (1 to 9) to it, modulo 10.
-}
alter : Int -> Int -> String -> String
alter position change number =
    number
        |> String.toList
        |> List.indexedMap
            (\index c ->
                if index == position then
                    Char.fromCode (48 + modBy 10 (Char.toCode c - 48 + change))

                else
                    c
            )
        |> String.fromList



-- BANK ACCOUNTS


bankAccountTests : Test
bankAccountTests =
    let
        weights =
            [ 5, 4, 3, 2, 7, 6, 5, 4, 3, 2 ]
    in
    describe "the Norwegian bank account number (modulus 11)"
        [ test "a published test account is right" <|
            \_ -> Expect.equal True (Checksum.mod11 weights "86011117947")
        , test "and a different last digit is wrong" <|
            \_ ->
                List.range 0 9
                    |> List.map (\last -> "8601111794" ++ String.fromInt last)
                    |> List.filter (Checksum.mod11 weights)
                    |> Expect.equal [ "86011117947" ]
        , fuzz bankAccounts "an account made with the algorithm is right, in the mask too" <|
            \number ->
                Expect.equal [ True, True ]
                    [ Checksum.mod11 weights number
                    , Shape.issue account (Shape.read account number) == Nothing
                    ]
        , fuzz2 bankAccounts (Fuzz.intRange 0 9) "one wrong digit in the account is wrong" <|
            \number position ->
                Expect.equal False (Checksum.mod11 weights (alter position 1 number |> String.left 11))
        ]



-- IBAN CHECK DIGITS


{-| The IBANs that the registry of SWIFT publishes as examples, written as they are
printed.
-}
publishedIbans : List String
publishedIbans =
    [ "NO93 8601 1117 947"
    , "DE89 3704 0044 0532 0130 00"
    , "GB29 NWBK 6016 1331 9268 19"
    , "FR14 2004 1010 0505 0001 3M02 606"
    , "ES91 2100 0418 4502 0005 1332"
    , "IT60 X054 2811 1010 0000 0123 456"
    , "NL91 ABNA 0417 1643 00"
    , "SE45 5000 0000 0583 9825 7466"
    , "DK50 0040 0440 1162 43"
    , "FI21 1234 5600 0007 85"
    , "CH93 0076 2011 6238 5295 7"
    , "AT61 1904 3002 3457 3201"
    , "BE68 5390 0754 7034"
    , "PL61 1090 1014 0000 0712 1981 2874"
    , "PT50 0002 0123 1234 5678 9015 4"
    , "IE29 AIBK 9311 5212 3456 78"
    , "LU28 0019 4006 4475 0000"
    , "CZ65 0800 0000 1920 0014 5399"
    , "HU42 1177 3016 1111 1018 0000 0000"
    , "GR16 0110 1250 0000 0001 2300 695"
    , "IS14 0159 2600 7654 5510 7303 39"
    , "LT12 1000 0111 0100 1000"
    , "LV80 BANK 0000 4351 9500 1"
    , "EE38 2200 2210 2014 5685"
    , "SA03 8000 0000 6080 1016 7519"
    , "AE07 0331 2345 6789 0123 456"
    , "TR33 0006 1005 1978 6457 8413 26"
    , "HR12 1001 0051 8630 0016 0"
    , "SI56 2633 0001 2039 086"
    , "SK31 1200 0000 1987 4263 7541"
    , "RO49 AAAA 1B31 0075 9384 0000"
    , "BG80 BNBG 9661 1020 3456 78"
    , "MT84 MALT 0110 0001 2345 MTLC AST0 01S"
    , "CY17 0020 0128 0000 0012 0052 7600"
    , "MC58 1122 2000 0101 2345 6789 030"
    , "LI21 0881 0000 2324 013A A"
    , "BA39 1290 0794 0102 8494"
    , "RS35 2600 0560 1001 6113 79"
    , "ME25 5050 0001 2345 6789 51"
    , "MK07 2501 2000 0058 984"
    , "AL47 2121 1009 0000 0002 3569 8741"
    , "GE29 NB00 0000 0101 9049 17"
    , "IL62 0108 0000 0009 9999 999"
    , "KW81 CBKU 0000 0000 0000 1234 5601 01"
    , "QA58 DOHB 0000 1234 5678 90AB CDEF G"
    , "BH67 BMAG 0000 1299 1234 56"
    , "JO94 CBJO 0010 0000 0000 0131 0003 02"
    , "LB62 0999 0000 0001 0019 0122 9114"
    , "PK36 SCBL 0000 0011 2345 6702"
    , "EG38 0019 0005 0000 0000 2631 8000 2"
    , "BR18 0036 0305 0000 1000 9795 493C 1"
    , "DO28 BAGR 0000 0001 2124 5361 1324"
    , "FO62 6460 0001 6316 34"
    , "GL89 6471 0001 0002 06"
    , "GI75 NWBK 0000 0000 7099 453"
    , "AD12 0001 2030 2003 5910 0100"
    , "SM86 U032 2509 8000 0000 0270 100"
    , "VA59 0011 2300 0012 3456 78"
    , "AZ21 NABZ 0000 0000 1370 1000 1944"
    , "BY13 NBRB 3600 9000 0000 2Z00 AB00"
    , "CR05 0152 0200 1026 2840 66"
    , "GT82 TRAJ 0102 0000 0012 1002 9690"
    , "IQ98 NBIQ 8501 2345 6789 012"
    , "KZ86 125K ZT50 0410 0100"
    , "LY83 0020 4800 0020 1001 2036 1"
    , "LC55 HEMM 0001 0001 0012 0012 0002 3015"
    , "MD24 AG00 0225 1000 1310 4168"
    , "MR13 0002 0001 0100 0012 3456 753"
    , "MU17 BOMM 0101 1010 3030 0200 000M UR"
    , "PS92 PALS 0000 0000 0400 1234 5670 2"
    , "SC18 SSCB 1101 0000 0000 0000 1497 USD"
    , "ST23 0001 0001 0051 8453 1014 6"
    , "SV62 CENR 0000 0000 0000 0070 0025"
    , "TL38 0080 0123 4567 8910 157"
    , "TN59 1000 6035 1835 9847 8831"
    , "UA21 3223 1300 0002 6007 2335 6600 1"
    , "VG96 VPVG 0000 0123 4567 8901"
    , "XK05 1212 0123 4567 8906"
    , "RU02 0445 2560 0407 0281 0412 3456 7890 1"
    , "SD21 2901 0501 2340 01"
    , "SO21 1000 0010 0100 0100 141"
    , "DJ21 0001 0000 0001 5400 0100 186"
    , "NI45 BAPR 0000 0013 0000 0355 8124"
    , "FK88 SC12 3456 7890 12"
    , "MN12 1234 1234 5678 9123"
    , "OM81 0180 0000 0129 9123 456"
    , "BI42 1000 0100 0100 0033 2045 181"
    , "HN88 CABF 0000 0000 0002 5000 5469"
    , "YE15 CBYE 0001 0188 6123 4567 8912 34"
    ]


unspaced : String -> String
unspaced text =
    String.filter (\c -> c /= ' ') text


ibanChecksumTests : Test
ibanChecksumTests =
    describe "the IBAN check digits (modulus 97)"
        [ test "there are more than 80 published examples" <|
            \_ -> Expect.atLeast 80 (List.length publishedIbans)
        , test "every published example is right" <|
            \_ ->
                publishedIbans
                    |> List.map unspaced
                    |> List.filter (\iban -> not (Checksum.mod97 iban))
                    |> Expect.equal []
        , test "every published example is right also through the mask, written as printed" <|
            \_ ->
                publishedIbans
                    |> List.filter (\printed -> Shape.issue Iban (Shape.read Iban printed) /= Nothing)
                    |> Expect.equal []
        , test "and the mask writes it as it is printed" <|
            \_ ->
                publishedIbans
                    |> List.filter (\printed -> Shape.display Iban (unspaced printed) /= printed)
                    |> Expect.equal []
        , test "the first example is the Norwegian IBAN of the bank account 8601.11.17947" <|
            \_ -> Expect.equal "NO9386011117947" ("NO93" ++ "86011117947")
        , test "a single changed digit in any place is found, in every example" <|
            \_ ->
                publishedIbans
                    |> List.map unspaced
                    |> List.concatMap
                        (\iban ->
                            List.range 0 (String.length iban - 1)
                                |> List.filterMap
                                    (\position ->
                                        let
                                            changed =
                                                String.toList iban
                                                    |> List.indexedMap
                                                        (\index c ->
                                                            if index == position && Char.isDigit c then
                                                                Char.fromCode (48 + modBy 10 (Char.toCode c - 48 + 1))

                                                            else
                                                                c
                                                        )
                                                    |> String.fromList
                                        in
                                        if changed /= iban && Checksum.mod97 changed then
                                            Just changed

                                        else
                                            Nothing
                                    )
                        )
                    |> Expect.equal []
        , test "two neighbouring characters that were swapped are found" <|
            \_ ->
                publishedIbans
                    |> List.map unspaced
                    |> List.concatMap
                        (\iban ->
                            List.range 4 (String.length iban - 2)
                                |> List.filterMap
                                    (\position ->
                                        let
                                            characters =
                                                String.toList iban

                                            swapped =
                                                List.indexedMap
                                                    (\index c ->
                                                        if index == position then
                                                            characters |> List.drop (position + 1) |> List.head |> Maybe.withDefault c

                                                        else if index == position + 1 then
                                                            characters |> List.drop position |> List.head |> Maybe.withDefault c

                                                        else
                                                            c
                                                    )
                                                    characters
                                                    |> String.fromList
                                        in
                                        -- swapping two digits that differ by 7 passes modulus 97
                                        -- only by chance, so very few may pass
                                        if swapped /= iban && Checksum.mod97 swapped then
                                            Just swapped

                                        else
                                            Nothing
                                    )
                        )
                    |> List.length
                    |> Expect.atMost 2
        , test "the check digits 00, 01 and 99 are refused: ISO 13616 uses 02 to 98, and modulo 97 those three are 97, 98 and 02" <|
            \_ ->
                let
                    made =
                        List.range 0 3000
                            |> List.map (\n -> ibanFor "NO" (String.padLeft 11 '0' (String.fromInt n)))

                    aliasOf iban =
                        case String.slice 2 4 iban of
                            "97" ->
                                Just ("NO00" ++ String.dropLeft 4 iban)

                            "98" ->
                                Just ("NO01" ++ String.dropLeft 4 iban)

                            "02" ->
                                Just ("NO99" ++ String.dropLeft 4 iban)

                            _ ->
                                Nothing

                    aliases =
                        List.filterMap aliasOf made

                    -- the plain calculation, as the standard describes it, without the rule about the check digits
                    remainderIsOne iban =
                        String.foldl
                            (\c remainder ->
                                if Char.isDigit c then
                                    modBy 97 (remainder * 10 + (Char.toCode c - 48))

                                else
                                    modBy 97 (remainder * 100 + (Char.toCode c - 55))
                            )
                            0
                            (String.dropLeft 4 iban ++ String.left 4 iban)
                            == 1
                in
                Expect.all
                    [ \_ -> Expect.equal [] (List.filter (not << Checksum.mod97) made)
                    , \_ -> Expect.atLeast 30 (List.length aliases)
                    , \_ -> Expect.equal [] (List.filter (not << remainderIsOne) aliases)
                    , \_ -> Expect.equal [] (List.filter Checksum.mod97 aliases)
                    , \_ -> Expect.equal True (List.all (\iban -> issueOf Iban iban /= Nothing) aliases)
                    ]
                    ()
        , test "text that is not capital letters and digits is wrong" <|
            \_ ->
                [ "", "NO93", "no9386011117947", "NO93 8601 1117 947", "NO9386011117947!", "NO93860111179é7" ]
                    |> List.filter Checksum.mod97
                    |> Expect.equal []
        , fuzz madeIbans "an IBAN made with the algorithm is right, and of the length of its country" <|
            \iban ->
                Expect.equal [ True, True, True ]
                    [ Checksum.mod97 iban
                    , IbanTable.lengthOf (String.left 2 iban) == Just (String.length iban)
                    , Shape.issue Iban (Shape.read Iban iban) == Nothing
                    ]
        ]


ibanTableTests : Test
ibanTableTests =
    describe "the countries with IBANs"
        [ test "no country is there twice" <|
            \_ ->
                let
                    codes =
                        List.map Tuple.first IbanTable.countries
                in
                Expect.equal (List.length codes) (Set.size (Set.fromList codes))
        , test "sorted by code, two capital letters each" <|
            \_ ->
                let
                    codes =
                        List.map Tuple.first IbanTable.countries
                in
                Expect.equal ( List.sort codes, [] )
                    ( codes, List.filter (\code -> String.length code /= 2 || not (String.all Char.isUpper code)) codes )
        , test "lengths are between 15 and 34" <|
            \_ ->
                IbanTable.countries
                    |> List.filter (\( _, length ) -> length < 15 || length > 34)
                    |> Expect.equal []
        , test "the length of every published example is the length in the table" <|
            \_ ->
                publishedIbans
                    |> List.map unspaced
                    |> List.filter (\iban -> IbanTable.lengthOf (String.left 2 iban) /= Just (String.length iban))
                    |> Expect.equal []
        , test "every country in the table has a published example" <|
            \_ ->
                let
                    withExample =
                        publishedIbans |> List.map (unspaced >> String.left 2) |> Set.fromList
                in
                IbanTable.countries
                    |> List.map Tuple.first
                    |> List.filter (\code -> not (Set.member code withExample))
                    |> Expect.equal []
        , test "the countries a Norwegian company deals with" <|
            \_ ->
                Expect.equal [ Just 15, Just 22, Just 24, Just 18, Just 18, Just 22, Nothing, Nothing ]
                    (List.map IbanTable.lengthOf [ "NO", "DE", "SE", "DK", "FI", "GB", "US", "XX" ])
        , test "Burundi, Honduras and Yemen are in the registry, and Algeria is not" <|
            \_ ->
                Expect.equal [ Just 27, Just 28, Just 30, Nothing ]
                    (List.map IbanTable.lengthOf [ "BI", "HN", "YE", "DZ" ])
        , test "the registry has 89 countries" <|
            \_ -> Expect.equal 89 (List.length IbanTable.countries)
        ]



-- READING


readingTests : Test
readingTests =
    describe "reading what was typed"
        [ test "separators are dropped and letters are written in capitals" <|
            \_ ->
                Expect.equal [ "NO9386011117947", "NO9386011117947", "NO9386011117947" ]
                    [ (Shape.read Iban "no93 8601 1117 947").value
                    , (Shape.read Iban " NO93-8601.1117/947 ").value
                    , (Shape.read Iban "no93\u{00A0}8601\u{00A0}1117\u{00A0}947").value
                    ]
        , test "a text with only separators is nothing" <|
            \_ ->
                Expect.equal [ "", "" ] [ (Shape.read Iban " - . ").value, (Shape.read organisation "   ").value ]
        , test "a letter in a field for digits is not dropped: it is remembered" <|
            \_ ->
                Expect.equal { value = "974760673", rejected = Just ( 'x', Shape.ExpectDigit ), trunkZero = False } (Shape.read organisation "974 760 67x3")
        , test "only the first character that does not belong is remembered" <|
            \_ ->
                (Shape.read organisation "9a7b").rejected
                    |> Expect.equal (Just ( 'a', Shape.ExpectDigit ))
        , test "a digit where an IBAN has its country is not accepted" <|
            \_ ->
                Expect.equal (Just ( '1', Shape.ExpectLetter )) (Shape.read Iban "1O93").rejected
        , test "a letter where an IBAN has its check digits is not accepted" <|
            \_ ->
                Expect.equal (Just ( 'A', Shape.ExpectDigit )) (Shape.read Iban "NOA3").rejected
        , test "after the check digits an IBAN takes letters and digits" <|
            \_ ->
                Expect.equal ( "DE89370400440532013000", Nothing )
                    (let
                        reading =
                            Shape.read Iban "de89 3704 0044 0532 0130 00"
                     in
                     ( reading.value, reading.rejected )
                    )
        , test "a character outside A to Z and 0 to 9 does not belong, whatever it looks like" <|
            \_ ->
                [ "é", "ø", "Å", "٣", "²", "ß", "😀", "_", "#", "+" ]
                    |> List.map (\text -> (Shape.read postalNo text).rejected /= Nothing)
                    |> Expect.equal (List.repeat 10 True)
        , test "the full-width digits and letters of an IME are the ordinary ones" <|
            \_ ->
                Expect.equal ( "0150", Nothing )
                    (let
                        reading =
                            Shape.read postalNo "０１５０"
                     in
                     ( reading.value, reading.rejected )
                    )
        , test "the fixed characters of a pattern may be typed, and are dropped" <|
            \_ ->
                Expect.equal ( "AB1234", Nothing )
                    (let
                        reading =
                            Shape.read sku "ab-1234"
                     in
                     ( reading.value, reading.rejected )
                    )
        , test "and the pattern also reads the text without them" <|
            \_ ->
                Expect.equal "AB1234" (Shape.read sku "ab1234").value
        , test "characters past the end of a pattern of digits are digits" <|
            \_ ->
                Expect.equal ( "12345", Just ( 'x', Shape.ExpectDigit ) )
                    (let
                        reading =
                            Shape.read postalNo "12345 x"
                     in
                     ( reading.value, reading.rejected )
                    )
        , test "characters past the end of a pattern with letters are letters or digits" <|
            \_ ->
                Expect.equal ( "AB1234XY", Nothing )
                    (let
                        reading =
                            Shape.read sku "ab-1234-xy"
                     in
                     ( reading.value, reading.rejected )
                    )
        , fuzz Fuzz.string "reading any text never crashes, and keeps only capital letters, digits and +" <|
            \text ->
                (Shape.read Iban text).value
                    |> String.all (\c -> Char.isDigit c || (Char.isAlpha c && Char.isUpper c))
                    |> Expect.equal True
        ]



-- WRITING


writingTests : Test
writingTests =
    describe "writing a value in its groups"
        [ test "an IBAN in groups of four" <|
            \_ ->
                Expect.equal [ "NO93 8601 1117 947", "NO93 8", "NO93", "N", "" ]
                    [ Shape.display Iban "NO9386011117947"
                    , Shape.display Iban "NO938"
                    , Shape.display Iban "NO93"
                    , Shape.display Iban "N"
                    , Shape.display Iban ""
                    ]
        , test "an organisation number in threes" <|
            \_ ->
                Expect.equal [ "974 760 673", "974 760 6", "974", "9", "" ]
                    [ Shape.display organisation "974760673"
                    , Shape.display organisation "9747606"
                    , Shape.display organisation "974"
                    , Shape.display organisation "9"
                    , Shape.display organisation ""
                    ]
        , test "a bank account with points" <|
            \_ ->
                Expect.equal [ "8601.11.17947", "8601.1", "8601", "860" ]
                    [ Shape.display account "86011117947"
                    , Shape.display account "86011"
                    , Shape.display account "8601"
                    , Shape.display account "860"
                    ]
        , test "a pattern puts a fixed character in front of the character that follows it, and not before" <|
            \_ ->
                Expect.equal [ "", "A", "AB", "AB-1", "AB-1234" ]
                    [ Shape.display sku ""
                    , Shape.display sku "A"
                    , Shape.display sku "AB"
                    , Shape.display sku "AB1"
                    , Shape.display sku "AB1234"
                    ]
        , test "a fixed character at the start of a pattern shows with the first character" <|
            \_ ->
                let
                    withPrefix =
                        Slots [ Literal '(', Digit, Digit, Literal ')', Literal ' ', Digit, Digit ] NoChecksum
                in
                Expect.equal [ "", "(1", "(12", "(12) 3" ]
                    [ Shape.display withPrefix "", Shape.display withPrefix "1", Shape.display withPrefix "12", Shape.display withPrefix "123" ]
        , test "characters beyond the end of the shape go in a last group" <|
            \_ ->
                Expect.equal [ "974 760 673 1", "1234 5", "AB-1234 XY" ]
                    [ Shape.display organisation "9747606731", Shape.display postalNo "12345", Shape.display sku "AB1234XY" ]
        , fuzz organisationNumbers "writing and reading an organisation number is the identity" <|
            \number ->
                Expect.equal number (Shape.read organisation (Shape.display organisation number)).value
        , fuzz madeIbans "writing and reading an IBAN is the identity" <|
            \iban ->
                Expect.equal iban (Shape.read Iban (Shape.display Iban iban)).value
        , fuzz bankAccounts "writing and reading a bank account is the identity" <|
            \number ->
                Expect.equal number (Shape.read account (Shape.display account number)).value
        , fuzz madeIbans "writing twice is writing once" <|
            \iban ->
                Expect.equal (Shape.display Iban iban) (Shape.display Iban (Shape.read Iban (Shape.display Iban iban)).value)
        , fuzz madeIbans "the text of a prefix of a value is a prefix of the text of the value" <|
            \iban ->
                List.range 0 (String.length iban)
                    |> List.filter (\length -> not (String.startsWith (Shape.display Iban (String.left length iban)) (Shape.display Iban iban)))
                    |> Expect.equal []
        , fuzz phoneNumbers "the text of a prefix of a phone number is a prefix of its text" <|
            \number ->
                List.range 0 (String.length number)
                    |> List.filter (\length -> not (String.startsWith (Shape.display Phone (String.left length number)) (Shape.display Phone number)))
                    |> Expect.equal []
        ]



-- PHONE NUMBERS


phoneTests : Test
phoneTests =
    describe "phone numbers"
        [ test "Norwegian mobile numbers in 3, 2 and 3" <|
            \_ ->
                Expect.equal [ "+47 912 34 567", "+47 412 34 567", "+47 912 34", "+47 91", "+47", "+4" ]
                    [ Shape.display Phone "+4791234567"
                    , Shape.display Phone "+4741234567"
                    , Shape.display Phone "+4791234"
                    , Shape.display Phone "+4791"
                    , Shape.display Phone "+47"
                    , Shape.display Phone "+4"
                    ]
        , test "Norwegian service numbers, which begin with 8, are written like mobile numbers" <|
            \_ ->
                Expect.equal [ "+47 800 30 000", "+47 800 3", "+47 22 12 34 56" ]
                    [ Shape.display Phone "+4780030000", Shape.display Phone "+478003", Shape.display Phone "+4722123456" ]
        , test "the national zero in parentheses is not read: a (0) after the country code is an error, and the text stays as typed" <|
            \_ ->
                let
                    british =
                        "+44 (0)20 7946 0958"
                in
                Expect.all
                    [ \_ -> Expect.equal True (Shape.read Phone british).trunkZero
                    , \_ -> Expect.equal (Just Shape.LeaveOutTrunkZero) (issueOf Phone british)
                    , \_ -> Expect.equal british (Shape.afterTyping Phone { typed = british, caret = String.length british })
                    , \_ -> Expect.equal british (Shape.afterLeaving Phone british)
                    , \_ -> Expect.equal False (complete Phone british)
                    , \_ -> Expect.equal True (Shape.isFinal Shape.LeaveOutTrunkZero)
                    ]
                    ()
        , test "also when it is written with other spaces, or after a Norwegian code" <|
            \_ ->
                [ "+47 (0) 912 34 567", "+47(0)91234567", "+47 ( 0 ) 912 34 567", "+44 (0)", "+358 (0)40 123 4567" ]
                    |> List.filter (\text -> issueOf Phone text /= Just Shape.LeaveOutTrunkZero)
                    |> Expect.equal []
        , test "without the (0) the same number is fine" <|
            \_ ->
                Expect.equal [ Nothing, Nothing, Nothing ]
                    [ issueOf Phone "+44 20 7946 0958", issueOf Phone "+44 (20) 7946 0958", issueOf Phone "+47 (912) 34 567" ]
        , test "a (0) is only a problem in a phone number" <|
            \_ ->
                Expect.equal [ False, False ] [ (Shape.read organisation "(0)").trunkZero, (Shape.read Iban "NO(0)").trunkZero ]
        , test "the other Norwegian numbers in pairs" <|
            \_ ->
                Expect.equal [ "+47 22 12 34 56", "+47 22 1" ] [ Shape.display Phone "+4722123456", Shape.display Phone "+47221" ]
        , test "numbers of Denmark and North America" <|
            \_ ->
                Expect.equal [ "+45 12 34 56 78", "+1 202 555 0123" ] [ Shape.display Phone "+4512345678", Shape.display Phone "+12025550123" ]
        , test "the rest in threes, with the country code of one, two or three digits apart" <|
            \_ ->
                Expect.equal [ "+358 401 234 567", "+44 791 112 345 6", "+7 912 345 678 9", "+81 345 678 901" ]
                    [ Shape.display Phone "+358401234567"
                    , Shape.display Phone "+447911123456"
                    , Shape.display Phone "+79123456789"
                    , Shape.display Phone "+81345678901"
                    ]
        , test "the length of the country code" <|
            \_ ->
                Expect.equal [ 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 3, 2, 2, 2, 3, 3 ]
                    (List.map Phone.callingCodeLength [ "1234", "7123", "47123", "46123", "45123", "49123", "35812", "42012", "50123", "59123", "21212", "20123", "27123", "81123", "85212", "99412" ])
        , test "a number without + is written in threes, and is not valid" <|
            \_ ->
                Expect.equal ( "912 345 67", Just Shape.NeedsCountryCode )
                    ( Shape.display Phone "91234567", Shape.issue Phone (Shape.read Phone "91234567") )
        , test "a + belongs at the start only" <|
            \_ ->
                Expect.equal [ Just ( '+', Shape.ExpectDigit ), Just ( '+', Shape.ExpectDigit ), Nothing ]
                    [ (Shape.read Phone "+47+9").rejected
                    , (Shape.read Phone "47+9").rejected
                    , (Shape.read Phone "+47 9").rejected
                    ]
        , test "a country code does not start with 0" <|
            \_ ->
                Expect.equal (Just ( '0', Shape.ExpectNonZeroDigit )) (Shape.read Phone "+0123").rejected
        , test "nothing but digits after the +" <|
            \_ ->
                Expect.equal (Just ( 'x', Shape.ExpectDigit )) (Shape.read Phone "+47 91x").rejected
        , test "a Norwegian number has eight digits after +47" <|
            \_ ->
                Expect.equal
                    [ Nothing
                    , Just (Shape.WrongNationalLength { callingCode = "47", want = 8, have = 7 })
                    , Just (Shape.WrongNationalLength { callingCode = "47", want = 8, have = 9 })
                    ]
                    [ issueOf Phone "+47 912 34 567"
                    , issueOf Phone "+47 912 34 56"
                    , issueOf Phone "+47 912 34 5678"
                    ]
        , test "other numbers have 7 to 15 digits in all" <|
            \_ ->
                Expect.equal
                    [ Just (Shape.TooShort { have = 6, want = 7, exact = False, unit = Shape.Digits })
                    , Nothing
                    , Nothing
                    , Just (Shape.TooLong { have = 16, want = 15, exact = False, unit = Shape.Digits })
                    ]
                    [ issueOf Phone "+358 40 1"
                    , issueOf Phone "+358 401 234"
                    , issueOf Phone "+358 4012 3456 7890"
                    , issueOf Phone "+358 4012 3456 78901"
                    ]
        , fuzz phoneNumbers "a phone number is read back as it was" <|
            \number ->
                Expect.equal number (Shape.read Phone (Shape.display Phone number)).value
        ]


issueOf : Shape -> String -> Maybe Shape.Issue
issueOf shape text =
    Shape.issue shape (Shape.read shape text)



-- TYPING


typingTests : Test
typingTests =
    describe "typing"
        [ fuzz madeIbans "an IBAN typed one character at a time ends in its groups, and every step is the groups so far" <|
            \iban ->
                Expect.equal (List.map (\length -> Shape.display Iban (String.left length iban)) (List.range 1 (String.length iban)))
                    (typeOneByOne Iban iban)
        , fuzz organisationNumbers "an organisation number typed one character at a time" <|
            \number ->
                Expect.equal (List.map (\length -> Shape.display organisation (String.left length number)) (List.range 1 9))
                    (typeOneByOne organisation number)
        , fuzz bankAccounts "a bank account typed one character at a time" <|
            \number ->
                Expect.equal (List.map (\length -> Shape.display account (String.left length number)) (List.range 1 11))
                    (typeOneByOne account number)
        , fuzz phoneNumbers "a phone number typed one character at a time" <|
            \number ->
                Expect.equal (List.map (\length -> Shape.display Phone (String.left length number)) (List.range 1 (String.length number)))
                    (typeOneByOne Phone number)
        , fuzz madeIbans "typing the characters of the written text, separators and all, gives the same" <|
            \iban ->
                Expect.equal (Shape.display Iban iban |> typeOneByOne Iban |> List.reverse |> List.head)
                    (Just (Shape.display Iban iban))
        , fuzz madeIbans "deleting from the end is typing backwards: every step is the groups so far" <|
            \iban ->
                Expect.equal (List.map (\length -> Shape.display Iban (String.left length iban)) (List.range 0 (String.length iban - 1) |> List.reverse))
                    (deleteOneByOne Iban iban)
        , fuzz organisationNumbers "deleting an organisation number from the end" <|
            \number ->
                Expect.equal (List.map (\length -> Shape.display organisation (String.left length number)) (List.range 0 8 |> List.reverse))
                    (deleteOneByOne organisation number)
        , fuzz madeIbans "pasting the whole value at the end of an empty field gives its groups, however it is written" <|
            \iban ->
                Expect.equal
                    (List.repeat 4 (Shape.display Iban iban))
                    [ typedAtEnd Iban iban
                    , typedAtEnd Iban (Shape.display Iban iban)
                    , typedAtEnd Iban (String.toLower iban)
                    , typedAtEnd Iban (String.join "-" (chunksOf 4 iban))
                    ]
        , test "typing a separator at the end gives nothing, the next character brings it" <|
            \_ ->
                Expect.equal [ "974 7", "974 7", "974" ] [ typedAtEnd organisation "9747", typedAtEnd organisation "974 7", typedAtEnd organisation "974 " ]
        , test "an edit in the middle is kept exactly as typed" <|
            \_ ->
                -- a character typed after the first '9' of "974 760 673", the caret just behind it
                Expect.equal "9 8974 760 673" (Shape.afterTyping organisation { typed = "9 8974 760 673", caret = 3 })
        , test "an edit in the middle that is already in groups changes nothing either way" <|
            \_ ->
                -- the 5 of "974 760 673" replaced by a 5, caret behind it
                Expect.equal "974 560 673" (Shape.afterTyping organisation { typed = "974 560 673", caret = 5 })
        , test "an edit in the middle that is not in groups is written when the field is left" <|
            \_ ->
                Expect.equal "974 856 067 3" (Shape.afterLeaving organisation "97485 6067 3")
        , test "typing at the end of such text writes it all in groups" <|
            \_ ->
                Expect.equal "974 856 067 3" (Shape.afterTyping organisation { typed = "9748560673", caret = 10 })
        , test "an unknown caret counts as the end" <|
            \_ ->
                Expect.equal "974 76" (Shape.afterTyping organisation { typed = "97476", caret = -1 })
        , test "text with a character that does not belong is left as typed, wherever the caret is" <|
            \_ ->
                Expect.equal [ "974760x", "9 7 4 x", "97a" ]
                    [ Shape.afterTyping organisation { typed = "974760x", caret = 7 }
                    , Shape.afterTyping organisation { typed = "9 7 4 x", caret = 7 }
                    , Shape.afterLeaving organisation "97a"
                    ]
        , test "leaving writes the groups" <|
            \_ ->
                Expect.equal [ "974 760 673", "NO93 8601 1117 947", "" ]
                    [ Shape.afterLeaving organisation "974760673", Shape.afterLeaving Iban "no93860111179 47", Shape.afterLeaving Iban "" ]
        , fuzz Fuzz.string "typing any text at the end never loses a letter or a digit that belongs, or changes text with one that does not" <|
            \typed ->
                let
                    shown =
                        typedAtEnd Iban typed

                    letters text =
                        String.filter (\c -> Char.isAlphaNum c) text |> String.toUpper
                in
                if (Shape.read Iban typed).rejected /= Nothing then
                    Expect.equal typed shown

                else
                    Expect.equal (letters typed) (letters shown)
        ]


chunksOf : Int -> String -> List String
chunksOf size text =
    if text == "" then
        []

    else
        String.left size text :: chunksOf size (String.dropLeft size text)



-- NOTHING IS LOST


neverLosesTests : Test
neverLosesTests =
    describe "nothing is lost behind the user's back"
        [ fuzz2 (Fuzz.intRange 0 40) Fuzz.string "after any edit the letters and digits typed are all still there, or the text is as typed" <|
            \caret typed ->
                let
                    shapes =
                        [ organisation, account, Iban, Phone, sku, postalNo ]

                    keptAll shape =
                        let
                            shown =
                                Shape.afterTyping shape { typed = typed, caret = caret }

                            significant text =
                                String.filter Char.isAlphaNum text |> String.toUpper
                        in
                        shown == typed || significant shown == significant typed
                in
                shapes
                    |> List.filter (not << keptAll)
                    |> List.length
                    |> Expect.equal 0
        ]



-- WHAT IS WRONG


issueTests : Test
issueTests =
    describe "what is wrong"
        [ test "nothing is wrong with an empty text" <|
            \_ -> Expect.equal [ Nothing, Nothing, Nothing, Nothing ] (List.map (\shape -> issueOf shape "") [ Iban, organisation, Phone, sku ])
        , test "an organisation number" <|
            \_ ->
                Expect.equal
                    [ Nothing
                    , Just (Shape.TooShort { have = 6, want = 9, exact = True, unit = Shape.Digits })
                    , Just (Shape.TooLong { have = 10, want = 9, exact = True, unit = Shape.Digits })
                    , Just Shape.WrongCheckDigit
                    , Just (Shape.Unexpected 'x' Shape.ExpectDigit)
                    ]
                    [ issueOf organisation "974 760 673"
                    , issueOf organisation "974 760"
                    , issueOf organisation "974 760 673 1"
                    , issueOf organisation "974 760 674"
                    , issueOf organisation "974 76x"
                    ]
        , test "a bank account" <|
            \_ ->
                Expect.equal [ Nothing, Just Shape.WrongCheckDigit, Just (Shape.TooShort { have = 10, want = 11, exact = True, unit = Shape.Digits }) ]
                    [ issueOf account "8601.11.17947", issueOf account "8601.11.17948", issueOf account "8601.11.1794" ]
        , test "an IBAN" <|
            \_ ->
                Expect.equal
                    [ Nothing
                    , Just (Shape.WrongIbanLength { country = "NO", want = 15, have = 12 })
                    , Just (Shape.WrongIbanLength { country = "NO", want = 15, have = 16 })
                    , Just Shape.WrongIbanCheck
                    , Just (Shape.UnknownIbanCountry "XX")
                    , Just (Shape.TooShort { have = 1, want = 15, exact = False, unit = Shape.Characters })
                    , Just (Shape.Unexpected '1' Shape.ExpectLetter)
                    ]
                    [ issueOf Iban "NO93 8601 1117 947"
                    , issueOf Iban "NO93 8601 1117"
                    , issueOf Iban "NO93 8601 1117 9471"
                    , issueOf Iban "NO94 8601 1117 947"
                    , issueOf Iban "XX00 0000"
                    , issueOf Iban "N"
                    , issueOf Iban "1"
                    ]
        , test "what more typing cannot fix is final, and what is only unfinished is not" <|
            \_ ->
                Expect.equal [ True, True, True, True, True, False, False, False, True, False, True ]
                    [ Shape.isFinal (Shape.Unexpected 'x' Shape.ExpectDigit)
                    , Shape.isFinal (Shape.TooLong { have = 10, want = 9, exact = True, unit = Shape.Digits })
                    , Shape.isFinal Shape.WrongCheckDigit
                    , Shape.isFinal Shape.WrongIbanCheck
                    , Shape.isFinal (Shape.UnknownIbanCountry "XX")
                    , Shape.isFinal (Shape.TooShort { have = 1, want = 9, exact = True, unit = Shape.Digits })
                    , Shape.isFinal (Shape.WrongIbanLength { country = "NO", want = 15, have = 12 })
                    , Shape.isFinal Shape.NeedsCountryCode
                    , Shape.isFinal (Shape.WrongIbanLength { country = "NO", want = 15, have = 16 })
                    , Shape.isFinal (Shape.WrongNationalLength { callingCode = "47", want = 8, have = 7 })
                    , Shape.isFinal (Shape.WrongNationalLength { callingCode = "47", want = 8, have = 9 })
                    ]
        , test "a text is complete when it has all its characters, right or not" <|
            \_ ->
                Expect.equal [ True, True, False, False, False, True, False ]
                    [ complete organisation "974 760 673"
                    , complete organisation "974 760 674"
                    , complete organisation "974 760"
                    , complete organisation ""
                    , complete organisation "974 760 67x"
                    , complete Iban "NO93 8601 1117 947"
                    , complete Iban "NO93 8601 1117"
                    ]
        ]


complete : Shape -> String -> Bool
complete shape text =
    Shape.isComplete shape (Shape.read shape text)



-- PATTERNS


patternTests : Test
patternTests =
    describe "the pattern language"
        [ test "digit, letter, letter or digit, and fixed characters" <|
            \_ ->
                Expect.equal (Just [ Letter, Letter, Literal '-', Digit, Digit, Digit, Digit, LetterOrDigit ]) (Shape.parsePattern "@@-####*")
        , test "a backslash makes the next character a fixed one" <|
            \_ ->
                Expect.equal (Just [ Literal '#', Digit, Literal '@', Literal '*', Literal '\\' ]) (Shape.parsePattern "\\##\\@\\*\\\\")
        , test "separators of every kind may be fixed characters" <|
            \_ ->
                Expect.equal (Just [ Digit, Literal ' ', Digit, Literal '.', Digit, Literal '/', Digit, Literal ':', Digit, Literal '(', Digit, Literal '+' ]) (Shape.parsePattern "# #.#/#:#(#+")
        , test "a pattern without a slot is nothing" <|
            \_ ->
                [ "", "-", " - ", "\\#", "\\@\\*" ]
                    |> List.filterMap Shape.parsePattern
                    |> Expect.equal []
        , test "a backslash at the end is nothing" <|
            \_ ->
                Expect.equal [ Nothing, Nothing ] [ Shape.parsePattern "##\\", Shape.parsePattern "\\" ]
        , test "a letter or a digit that is not a slot is nothing: the user would have to type it" <|
            \_ ->
                [ "AB-####", "SKU-####", "##1", "#a", "\\A#", "\\1#" ]
                    |> List.filterMap Shape.parsePattern
                    |> Expect.equal []
        , test "a letter of any alphabet that has capitals is nothing, as a fixed character: the user would have to type it" <|
            \_ ->
                [ "å#", "#Å", "é-#", "#ß", "ж#", "ø##", "#ñ", "Ω#" ]
                    |> List.filterMap Shape.parsePattern
                    |> Expect.equal []
        , test "but signs and punctuation of any kind are fixed characters" <|
            \_ ->
                Expect.equal (List.repeat 6 True)
                    (List.map (\pattern -> Shape.parsePattern pattern /= Nothing) [ "§#", "€#", "#·#", "#–#", "(#)", "#%" ])
        , test "a control character is nothing" <|
            \_ ->
                Expect.equal [ Nothing, Nothing ] [ Shape.parsePattern "#\t#", Shape.parsePattern "#\n#" ]
        , test "64 characters are fine, 65 are not" <|
            \_ ->
                Expect.equal [ True, False ]
                    [ Shape.parsePattern (String.repeat 64 "#") /= Nothing
                    , Shape.parsePattern (String.repeat 65 "#") /= Nothing
                    ]
        , test "the example of a shape shows its slots" <|
            \_ ->
                Expect.equal [ "000 000 000", "0000.00.00000", "AA-0000", "0000", "NO00 0000 0000 000", "+47 000 00 000" ]
                    [ Shape.example organisation, Shape.example account, Shape.example sku, Shape.example postalNo, Shape.example Iban, Shape.example Phone ]
        , test "the keyboard of a shape" <|
            \_ ->
                Expect.equal [ Just "numeric", Just "numeric", Nothing, Nothing, Just "tel" ]
                    (List.map Shape.keyboard [ organisation, postalNo, sku, Iban, Phone ])
        , test "the length a shape expects" <|
            \_ ->
                Expect.equal [ Just 9, Just 4, Just 6, Just 15, Nothing, Nothing ]
                    [ Shape.expectedLength organisation ""
                    , Shape.expectedLength postalNo ""
                    , Shape.expectedLength sku ""
                    , Shape.expectedLength Iban "NO93"
                    , Shape.expectedLength Iban "N"
                    , Shape.expectedLength Phone "+47"
                    ]
        ]



-- POSTAL CODES


postalTests : Test
postalTests =
    describe "postal codes"
        [ test "every pattern in the list is a pattern" <|
            \_ ->
                [ "NO", "SE", "DK", "FI", "IS", "DE", "AT", "CH", "LI", "NL", "BE", "LU", "FR", "ES", "IT", "PT", "PL", "CZ", "SK", "EE", "US", "JP", "AU", "NZ" ]
                    |> List.filter (\country -> Shape.postalPattern country |> Maybe.andThen Shape.parsePattern |> (==) Nothing)
                    |> Expect.equal []
        , test "countries that are not in the list" <|
            \_ ->
                Expect.equal [ Nothing, Nothing, Nothing ] (List.map Shape.postalPattern [ "GB", "", "no" ])
        , test "the patterns of some countries, written while typing" <|
            \_ ->
                Expect.equal [ "0150", "123 45", "1234 AB", "12-345", "1234-567", "123-4567" ]
                    [ postalTyped "NO" "0150"
                    , postalTyped "SE" "12345"
                    , postalTyped "NL" "1234ab"
                    , postalTyped "PL" "12345"
                    , postalTyped "PT" "1234567"
                    , postalTyped "JP" "1234567"
                    ]
        ]


postalTyped : String -> String -> String
postalTyped country text =
    case Shape.postalPattern country |> Maybe.andThen Shape.parsePattern of
        Just slots ->
            typedAtEnd (Slots slots NoChecksum) text

        Nothing ->
            "?"


gtinTests : Test
gtinTests =
    describe "the GTIN check digit (modulus 10)"
        [ test "known product numbers are right" <|
            \_ ->
                [ "5901234123457", "4006381333931", "7038010069307", "0012345678905" ]
                    |> List.filter (\gtin -> not (Checksum.mod10 gtin))
                    |> Expect.equal []
        , test "every other last digit is wrong" <|
            \_ ->
                List.range 0 9
                    |> List.map (\d -> "590123412345" ++ String.fromInt d)
                    |> List.filter Checksum.mod10
                    |> Expect.equal [ "5901234123457" ]
        , test "two neighbours swapped are found" <|
            \_ -> Expect.equal False (Checksum.mod10 "5901234213457")
        , test "text that is not digits is wrong" <|
            \_ -> Expect.equal False (Checksum.mod10 "59012341234A7")
        , test "a single digit is not a number with a check digit" <|
            \_ -> Expect.equal False (Checksum.mod10 "0")
        ]


nordicTests : Test
nordicTests =
    describe "the Nordic business numbers"
        [ test "the Luhn digit of a Swedish organisation number" <|
            \_ -> Expect.equal [ True, False ] [ Checksum.luhn "5560125790", Checksum.luhn "5560125791" ]
        , test "the Luhn digit finds two neighbours swapped" <|
            \_ -> Expect.equal False (Checksum.luhn "5561025790")
        , test "a Danish CVR number" <|
            \_ -> Expect.equal [ True, False ] [ Checksum.mod11 [ 2, 7, 6, 5, 4, 3, 2 ] "24256790", Checksum.mod11 [ 2, 7, 6, 5, 4, 3, 2 ] "24256791" ]
        , test "a Finnish business ID" <|
            \_ -> Expect.equal [ True, False ] [ Checksum.mod11 [ 7, 9, 10, 5, 8, 4, 2 ] "01120389", Checksum.mod11 [ 7, 9, 10, 5, 8, 4, 2 ] "01120388" ]
        ]
