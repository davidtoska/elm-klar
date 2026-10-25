module ValidateTest exposing (suite)

import Expect
import Klar.Date as Date
import Klar.Locale as Locale exposing (Locale)
import Klar.Validate as Validate
import Test exposing (Test, describe, test)


suite : Test
suite =
    describe "Klar.Validate"
        [ required
        , lengths
        , email
        , phones
        , numbersAndChoices
        , dates
        , combining
        , forms
        ]


ok : Validate.Validator -> String -> Test
ok validator value =
    test ("accepts \"" ++ value ++ "\"") <|
        \_ -> Expect.equal Nothing (Validate.run Locale.en validator value)


bad : Validate.Validator -> String -> Test
bad validator value =
    test ("rejects \"" ++ value ++ "\"") <|
        \_ -> Expect.notEqual Nothing (Validate.run Locale.en validator value)


required : Test
required =
    describe "required"
        [ ok Validate.required "x"
        , bad Validate.required ""
        , bad Validate.required "   "
        , test "says so in English" <|
            \_ -> Expect.equal (Just "Required") (Validate.run Locale.en Validate.required "")
        , test "says so in Norwegian" <|
            \_ -> Expect.equal (Just "Må fylles ut") (Validate.run Locale.nb Validate.required "")
        ]


lengths : Test
lengths =
    describe "lengths"
        [ describe "minLength 3"
            [ ok (Validate.minLength 3) "abc"
            , bad (Validate.minLength 3) "ab"
            , ok (Validate.minLength 3) ""
            , test "the message says how many" <|
                \_ -> Expect.equal (Just "Must be at least 3 characters") (Validate.run Locale.en (Validate.minLength 3) "ab")
            ]
        , describe "maxLength 3"
            [ ok (Validate.maxLength 3) "abc"
            , bad (Validate.maxLength 3) "abcd"
            , ok (Validate.maxLength 3) ""
            , describe "an emoji is one character, as a database counts it"
                [ ok (Validate.maxLength 3) "a😀b"
                , ok (Validate.maxLength 3) "😀😀😀"
                , bad (Validate.maxLength 3) "😀😀😀😀"
                ]
            , describe "the spaces around the text do not count, as the form trims what it saves"
                [ ok (Validate.maxLength 3) "abc "
                , bad (Validate.minLength 3) "ab "
                ]
            ]
        , test "digits ignores the spaces around a pasted number" <|
            \_ -> Expect.equal Nothing (Validate.run Locale.en (Validate.digits 9) " 912345678 ")
        , test "numbers in messages are written as the locale writes them" <|
            \_ ->
                ( Validate.run Locale.nb (Validate.integerBetween 1 100000) "0"
                , Validate.run Locale.en (Validate.maxLength 1000) (String.repeat 1001 "a")
                )
                    |> Expect.equal
                        ( Just "Må være et heltall mellom 1 og 100\u{00A0}000"
                        , Just "Must be at most 1,000 characters"
                        )
        ]


email : Test
email =
    describe "email"
        [ ok Validate.email "ada@example.com"
        , ok Validate.email "  ada@example.com  "
        , ok Validate.email "first.last+tag@sub.example.co.uk"
        , ok Validate.email "o'brien@example.org"
        , ok Validate.email "ål@exämple.no"
        , ok Validate.email ""
        , bad Validate.email "ada@"
        , bad Validate.email "@example.com"
        , bad Validate.email "ada"
        , bad Validate.email "ada@example"
        , bad Validate.email "ada@@example.com"
        , bad Validate.email "ada@exam ple.com"
        , bad Validate.email ".ada@example.com"
        , bad Validate.email "ada.@example.com"
        , bad Validate.email "a..da@example.com"
        , bad Validate.email "ada@-example.com"
        , bad Validate.email "ada@example-.com"
        , bad Validate.email "ada@example.c"
        , bad Validate.email "ada@.com"
        , bad Validate.email (String.repeat 65 "a" ++ "@example.com")
        ]


phones : Test
phones =
    describe "phone numbers"
        [ ok Validate.phone "+44 20 7946 0958"
        , ok Validate.phone "(555) 123-4567"
        , ok Validate.phone "0047 12345678"
        , ok Validate.phone ""
        , bad Validate.phone "12345"
        , bad Validate.phone "1234567890123456"
        , bad Validate.phone "555-CALL-NOW"
        , bad Validate.phone "++4412345678"
        , ok Validate.norwegianPhone "12345678"
        , ok Validate.norwegianPhone "12 34 56 78"
        , ok Validate.norwegianPhone "+47 123 45 678"
        , ok Validate.norwegianPhone "004712345678"
        , bad Validate.norwegianPhone "1234567"
        , bad Validate.norwegianPhone "123456789"
        , bad Validate.norwegianPhone "+4712345"
        ]


numbersAndChoices : Test
numbersAndChoices =
    describe "numbers, sameAs and choices"
        [ ok (Validate.integerBetween 1 10) "1"
        , ok (Validate.integerBetween 1 10) " 10 "
        , bad (Validate.integerBetween 1 10) "0"
        , bad (Validate.integerBetween 1 10) "11"
        , bad (Validate.integerBetween 1 10) "1.5"
        , bad (Validate.integerBetween 1 10) "ten"
        , ok (Validate.integerBetween 1 10) ""
        , ok (Validate.sameAs "secret") "secret"
        , bad (Validate.sameAs "secret") "Secret"
        , ok (Validate.digits 9) "912345678"
        , bad (Validate.digits 9) "91234567"
        , bad (Validate.digits 9) "9123456789"
        , bad (Validate.digits 9) "912 345 678"
        , bad (Validate.digits 9) "91234567a"
        , test "digits says how many, in both languages" <|
            \_ ->
                Expect.equal [ Just "Enter 9 digits", Just "Oppgi 9 siffer" ]
                    [ Validate.run Locale.en (Validate.digits 9) "1", Validate.run Locale.nb (Validate.digits 9) "1" ]
        , ok Validate.url "https://example.com"
        , ok Validate.url "http://example.com/a/b?c=d#e"
        , ok Validate.url "https://sub.example.co.uk:8080/x"
        , ok Validate.url "http://localhost:8000"
        , ok Validate.url " https://example.com "
        , test "digits and url let a blank value pass, as every validator but required" <|
            \_ -> Expect.equal [ Nothing, Nothing ] [ Validate.run Locale.en (Validate.digits 9) "", Validate.run Locale.en Validate.url "" ]
        , bad Validate.url "example.com"
        , bad Validate.url "ftp://example.com"
        , bad Validate.url "https://"
        , bad Validate.url "https://example"
        , bad Validate.url "https://exa mple.com"
        , bad Validate.url "https://example.com:abc"
        , bad Validate.url "https://example.com:123456"
        , bad Validate.url "https://-example.com"
        , ok (Validate.oneOf [ "open", "paid" ]) "paid"
        , bad (Validate.oneOf [ "open", "paid" ]) "void"
        ]


dates : Test
dates =
    let
        today =
            Date.fromEpochDay 20746
    in
    describe "dates"
        [ ok Validate.date "20.10.2026"
        , ok Validate.date "1.2.1990"
        , ok Validate.date "2026-10-20"
        , ok Validate.date "29.02.2024"
        , bad Validate.date "29.02.2026"
        , bad Validate.date "31.04.2026"
        , bad Validate.date "20.10.26"
        , bad Validate.date "2026/10/20"
        , bad Validate.date "20-10-2026"
        , bad Validate.date "+1.1.2026"
        , bad Validate.date "tomorrow"
        , test "parseDate reads day.month.year" <|
            \_ -> Expect.equal (Date.fromParts 1990 2 1) (Validate.parseDate "1.2.1990")
        , test "parseDate reads ISO" <|
            \_ -> Expect.equal (Just today) (Validate.parseDate " 2026-10-20 ")
        , describe "notInFuture"
            [ ok (Validate.notInFuture today) "20.10.2026"
            , ok (Validate.notInFuture today) "2020-01-01"
            , bad (Validate.notInFuture today) "21.10.2026"
            , ok (Validate.notInFuture today) "not a date"
            , test "the message names the day" <|
                \_ -> Expect.equal (Just "The date cannot be after 2026-10-20") (Validate.run Locale.en (Validate.notInFuture today) "2026-10-21")
            , test "and in Norwegian" <|
                \_ -> Expect.equal (Just "Datoen kan ikke være etter 20.10.2026") (Validate.run Locale.nb (Validate.notInFuture today) "21.10.2026")
            ]
        ]


combining : Test
combining =
    describe "combining"
        [ test "all returns the first problem" <|
            \_ ->
                Expect.equal (Just "Required")
                    (Validate.run Locale.en (Validate.all [ Validate.required, Validate.email ]) "")
        , test "when False checks nothing" <|
            \_ -> Expect.equal Nothing (Validate.run Locale.en (Validate.when False Validate.required) "")
        , test "when True checks" <|
            \_ -> Expect.equal (Just "Required") (Validate.run Locale.en (Validate.when True Validate.required) "")
        , test "withMessage replaces the message in both languages" <|
            \_ ->
                let
                    validator =
                        Validate.required |> Validate.withMessage (\locale -> Locale.pick locale { nb = "Oppgi navn", en = "Enter a name" })
                in
                Expect.equal [ Just "Enter a name", Just "Oppgi navn" ] [ Validate.run Locale.en validator "", Validate.run Locale.nb validator "" ]
        , test "withMessage keeps a passing value passing" <|
            \_ ->
                Expect.equal Nothing
                    (Validate.run Locale.en (Validate.required |> Validate.withMessage (always "y")) "ok")
        , test "custom sees the empty value" <|
            \_ ->
                Expect.equal (Just "Must start with ORD-")
                    (Validate.run Locale.en (Validate.custom (String.startsWith "ORD-") (\locale -> Locale.pick locale { nb = "Må starte med ORD-", en = "Must start with ORD-" })) "")
        , test "customWith builds its own message" <|
            \_ ->
                Expect.equal (Just "en:3")
                    (Validate.run Locale.en (Validate.customWith (\locale value -> Just (Locale.toCode locale ++ ":" ++ String.fromInt (String.length value)))) "abc")
        , test "firstError of nothing is nothing" <|
            \_ -> Expect.equal Nothing (Validate.firstError Locale.en [] "x")
        ]


forms : Test
forms =
    let
        errors =
            Validate.collect Locale.en
                [ ( "name", [ Validate.required ], "" )
                , ( "email", [ Validate.required, Validate.email ], "ada@" )
                , ( "city", [ Validate.required ], "Oslo" )
                ]
    in
    describe "whole forms"
        [ test "one error per field with a problem, in order" <|
            \_ -> Expect.equal [ "name", "email" ] (List.map .field errors)
        , test "errorFor finds the message of a field" <|
            \_ -> Expect.equal (Just "Invalid email address") (Validate.errorFor "email" errors)
        , test "errorFor is Nothing for a field without a problem" <|
            \_ -> Expect.equal Nothing (Validate.errorFor "city" errors)
        ]
