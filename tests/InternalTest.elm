module InternalTest exposing (suite)

{-| The shared helpers of the components that can be tested without a view.
-}

import Expect
import Fuzz exposing (Fuzzer)
import Html exposing (Html)
import Html.Events as Events
import Json.Decode
import Json.Encode as Encode
import Klar.Internal as Internal
import Test exposing (Test, describe, fuzz, fuzz2, test)
import Test.Html.Event as Event
import Test.Html.Query as Query
import Test.Html.Selector as Selector
import Url


suite : Test
suite =
    describe "Klar.Internal"
        [ percentEncodeTests
        , hasLatinLettersTests
        , normalizeTests
        , headingTests
        , keyTests
        , unhandledTests
        , sanitizeIdTests
        , focusChainTests
        ]


type Msg
    = Saved
    | Closed



-- KEYS


{-| A keydown with the given key and extra fields, as a browser sends it.
-}
keydown : String -> List ( String, Encode.Value ) -> ( String, Encode.Value )
keydown key extra =
    Event.custom "keydown"
        (Encode.object
            ([ ( "key", Encode.string key )
             , ( "ctrlKey", Encode.bool False )
             , ( "metaKey", Encode.bool False )
             , ( "shiftKey", Encode.bool False )
             , ( "altKey", Encode.bool False )
             ]
                ++ extra
            )
        )


press : ( String, Encode.Value ) -> Html Msg -> Result String Msg
press event html =
    Query.fromHtml html |> Event.simulate event |> Event.toResult


keyTests : Test
keyTests =
    let
        field =
            Html.input [ Internal.onKeys [ ( "Enter", Saved ), ( "Escape", Closed ) ] ] []

        passive =
            Html.div [ Internal.onKeysPassive [ ( "Enter", Saved ), ( "Escape", Closed ) ] ] []

        composing =
            [ ( "isComposing", Encode.bool True ) ]

        safari =
            [ ( "isComposing", Encode.bool False ), ( "keyCode", Encode.int 229 ) ]
    in
    describe "keys and input method composition"
        [ test "Enter and Escape are acted on" <|
            \_ -> Expect.equal ( Ok Saved, Ok Closed ) ( press (keydown "Enter" []) field, press (keydown "Escape" []) field )
        , test "the Enter that confirms a composition is not" <|
            \_ -> Expect.err (press (keydown "Enter" composing) field)
        , test "the Escape that cancels a composition is not" <|
            \_ -> Expect.err (press (keydown "Escape" composing) field)
        , test "the Enter that ends a composition in Safari (key code 229) is not" <|
            \_ -> Expect.err (press (keydown "Enter" safari) field)
        , test "another key code is a plain key" <|
            \_ -> Expect.equal (Ok Saved) (press (keydown "Enter" [ ( "isComposing", Encode.bool False ), ( "keyCode", Encode.int 13 ) ]) field)
        , test "the passive bindings have the same guard" <|
            \_ ->
                Expect.equal ( Ok Saved, True, True )
                    ( press (keydown "Enter" []) passive
                    , Result.toMaybe (press (keydown "Enter" composing) passive) == Nothing
                    , Result.toMaybe (press (keydown "Escape" safari) passive) == Nothing
                    )
        , test "a handled key prevents the default (a composing one sends nothing, so its default happens)" <|
            \_ -> Query.fromHtml field |> Event.simulate (keydown "Enter" []) |> Event.expectPreventDefault
        , test "keyEvent reads a composing key as nothing" <|
            \_ ->
                Html.div [ Events.on "keydown" (Internal.keyEvent |> Json.Decode.map (\_ -> Saved)) ] []
                    |> press (keydown "a" composing)
                    |> Expect.err
        ]


unhandledTests : Test
unhandledTests =
    let
        dialog =
            Html.div
                [ Events.preventDefaultOn "keydown"
                    (Internal.unhandled Internal.keyEvent
                        |> Json.Decode.andThen
                            (\event ->
                                if event.key == "Escape" then
                                    Json.Decode.succeed ( Closed, True )

                                else
                                    Json.Decode.fail "another key"
                            )
                    )
                ]
                []
    in
    describe "unhandled"
        [ test "a key nothing inside took reaches the container" <|
            \_ -> Expect.equal (Ok Closed) (press (keydown "Escape" [ ( "defaultPrevented", Encode.bool False ) ]) dialog)
        , test "a key a control inside took does not" <|
            \_ -> Expect.err (press (keydown "Escape" [ ( "defaultPrevented", Encode.bool True ) ]) dialog)
        , test "an event without the field counts as not handled" <|
            \_ -> Expect.equal (Ok Closed) (press (keydown "Escape" []) dialog)
        ]



-- IDS


{-| The inverse of `sanitizeId`, to show that nothing is lost.
-}
readId : String -> String
readId id =
    readIdHelp (String.toList id) []


readIdHelp : List Char -> List Char -> String
readIdHelp chars done =
    case chars of
        [] ->
            String.fromList (List.reverse done)

        '_' :: '_' :: rest ->
            readIdHelp rest (' ' :: done)

        '_' :: rest ->
            let
                digits =
                    List.filter Char.isHexDigit (takeUntilUnderscore rest)

                code =
                    List.foldl (\digit sum -> sum * 16 + hexValue digit) 0 digits
            in
            readIdHelp (List.drop (List.length digits + 1) rest) (Char.fromCode code :: done)

        char :: rest ->
            readIdHelp rest (char :: done)


takeUntilUnderscore : List Char -> List Char
takeUntilUnderscore chars =
    case chars of
        '_' :: _ ->
            []

        char :: rest ->
            char :: takeUntilUnderscore rest

        [] ->
            []


hexValue : Char -> Int
hexValue digit =
    if Char.isDigit digit then
        Char.toCode digit - 48

    else
        Char.toCode (Char.toLower digit) - 87


{-| Texts of ASCII, Norwegian letters, other scripts, an emoji and the characters
the encoding uses itself.
-}
idText : Fuzzer String
idText =
    Fuzz.list (Fuzz.oneOf [ Fuzz.asciiChar, Fuzz.oneOfValues [ 'ø', 'Æ', 'å', 'é', '漢', 'Ж', '📦', ' ', '_', '-', '.', '#' ] ])
        |> Fuzz.map String.fromList


sanitizeIdTests : Test
sanitizeIdTests =
    describe "sanitizeId"
        [ test "letters, digits and dashes stay as they are" <|
            \_ -> Expect.equal "billing-address-2" (Internal.sanitizeId "billing-address-2")
        , test "a space is two underscores" <|
            \_ -> Expect.equal "Customer__name" (Internal.sanitizeId "Customer name")
        , test "an underscore and a dot are written as their codes" <|
            \_ -> Expect.equal [ "order_5f_id", "v1_2e_2" ] (List.map Internal.sanitizeId [ "order_id", "v1.2" ])
        , test "letters outside ASCII are written as their codes" <|
            \_ -> Expect.equal [ "_d8_rsta", "_c6_rsta", "_6f22_" ] (List.map Internal.sanitizeId [ "Ørsta", "Ærsta", "漢" ])
        , test "an emoji is one code point" <|
            \_ -> Expect.equal "box_1f4e6_" (Internal.sanitizeId "box📦")
        , test "keys that used to give one id give two" <|
            \_ ->
                Expect.equal [ False, False, False ]
                    [ Internal.sanitizeId "a b" == Internal.sanitizeId "a-b"
                    , Internal.sanitizeId "Ørsta" == Internal.sanitizeId "Ærsta"
                    , Internal.sanitizeId "a_b" == Internal.sanitizeId "a b"
                    ]
        , test "half of an emoji does not crash" <|
            \_ -> Expect.equal "Order___fffd_" (Internal.sanitizeId (String.dropRight 1 "Order 📦"))
        , test "nothing in, nothing out" <|
            \_ -> Expect.equal "" (Internal.sanitizeId "")
        , fuzz idText "gives only letters, digits, dashes and underscores" <|
            \text ->
                Internal.sanitizeId text
                    |> String.all (\char -> Char.isAlphaNum char && Char.toCode char < 128 || char == '-' || char == '_')
                    |> Expect.equal True
        , fuzz idText "can be read back" <|
            \text -> Expect.equal text (readId (Internal.sanitizeId text))
        , fuzz2 idText idText "two texts give two ids" <|
            \one other ->
                if one == other then
                    Expect.pass

                else
                    Expect.notEqual (Internal.sanitizeId one) (Internal.sanitizeId other)
        ]



-- FOCUS


focusChainTests : Test
focusChainTests =
    describe "focusChain (the ids focusFirst tries)"
        [ test "the given ids, then the start of the page" <|
            \_ -> Expect.equal [ "opener", "list", Internal.pageStartId ] (Internal.focusChain [ "opener", "list" ])
        , test "the start of the page is not tried twice" <|
            \_ -> Expect.equal [ "opener", Internal.pageStartId ] (Internal.focusChain [ "opener", Internal.pageStartId ])
        , test "empty ids are skipped" <|
            \_ -> Expect.equal [ "list", Internal.pageStartId ] (Internal.focusChain [ "", "list", "" ])
        , test "with nothing given, the start of the page" <|
            \_ -> Expect.equal [ Internal.pageStartId ] (Internal.focusChain [])
        ]


percentEncodeTests : Test
percentEncodeTests =
    describe "percentEncode"
        [ test "plain text and the characters that stay" <|
            \_ -> Expect.equal "Orders-2026_ok.csv~!*'()" (Internal.percentEncode "Orders-2026_ok.csv~!*'()")
        , test "a space, a comma, a semicolon and a line break" <|
            \_ -> Expect.equal "a%20b%2Cc%3Bd%0D%0A" (Internal.percentEncode "a b,c;d\u{000D}\n")
        , test "characters that mean something in a URL" <|
            \_ -> Expect.equal "%23%25%26%2B%2F%3D%3F%40" (Internal.percentEncode "#%&+/=?@")
        , test "Norwegian letters take two bytes" <|
            \_ -> Expect.equal "%C3%A6%C3%B8%C3%A5%C3%86%C3%98%C3%85" (Internal.percentEncode "æøåÆØÅ")
        , test "a euro sign takes three bytes" <|
            \_ -> Expect.equal "%E2%82%AC" (Internal.percentEncode "€")
        , test "the byte order mark that opens an Excel file" <|
            \_ -> Expect.equal "%EF%BB%BF" (Internal.percentEncode "\u{FEFF}")
        , test "an emoji takes four bytes" <|
            \_ -> Expect.equal "%F0%9F%93%A6" (Internal.percentEncode "📦")
        , test "half of an emoji does not crash and becomes the replacement character" <|
            \_ -> Expect.equal "Order%20%EF%BF%BD" (Internal.percentEncode (String.dropRight 1 "Order 📦"))
        , test "nothing in, nothing out" <|
            \_ -> Expect.equal "" (Internal.percentEncode "")
        , fuzz Fuzz.string "gives what Url.percentEncode gives for any text it can encode" <|
            \text -> Expect.equal (Url.percentEncode text) (Internal.percentEncode text)
        ]


hasLatinLettersTests : Test
hasLatinLettersTests =
    describe "hasLatinLetters"
        [ test "plain text has none" <|
            \_ -> Expect.equal False (Internal.hasLatinLetters "Order ORD-10482, Oslo 0150")
        , test "Norwegian letters" <|
            \_ -> Expect.equal True (Internal.hasLatinLetters "Tromsø")
        , test "accents" <|
            \_ -> Expect.equal True (Internal.hasLatinLetters "Zürich")
        , test "Latin Extended-A letters" <|
            \_ -> Expect.equal ( True, True, True ) ( Internal.hasLatinLetters "Škoda", Internal.hasLatinLetters "Łódź", Internal.hasLatinLetters "čapek" )
        , test "the first and the last letter of the range" <|
            \_ -> Expect.equal ( True, True ) ( Internal.hasLatinLetters "À", Internal.hasLatinLetters "ſ" )
        , test "characters just outside the range" <|
            \_ -> Expect.equal ( False, False ) ( Internal.hasLatinLetters "¿", Internal.hasLatinLetters "ƀ" )
        , test "half of an emoji does not crash" <|
            \_ -> Expect.equal False (Internal.hasLatinLetters (String.dropRight 1 "Order 📦"))
        ]


normalizeTests : Test
normalizeTests =
    describe "normalize"
        [ test "plain text is only lowercased" <|
            \_ -> Expect.equal "order ord-10482, oslo" (Internal.normalize "Order ORD-10482, Oslo")
        , test "Norwegian letters, as a Norwegian types them on a foreign keyboard" <|
            \_ -> Expect.equal "aoa aoa" (Internal.normalize "ÆØÅ æøå")
        , test "Latin-1 letters" <|
            \_ -> Expect.equal "creme brulee zurich munchen n" (Internal.normalize "Crème Brûlée Zürich München ñ")
        , test "Latin Extended-A letters: Czech, Polish, Turkish, Hungarian" <|
            \_ -> Expect.equal "skoda zilina capek dvorak lodz" (Internal.normalize "Škoda Žilina Čapek Dvořák Łódź")
        , test "a capital I with a dot keeps one character, so a match position is the same in the original" <|
            \_ -> Expect.equal ( "istanbul", 8 ) ( Internal.normalize "İstanbul", String.length (Internal.normalize "İstanbul") )
        , test "Icelandic eth and thorn, and the sharp s" <|
            \_ -> Expect.equal "dts" (Internal.normalize "ðþß")
        , test "letters of other scripts stay as they are" <|
            \_ -> Expect.equal "αβγ жук" (Internal.normalize "ΑΒΓ ЖУК")
        , fuzz Fuzz.string "never changes the number of characters" <|
            \text -> Expect.equal (String.length text) (String.length (Internal.normalize text))
        ]


headingTests : Test
headingTests =
    let
        hasTag level tag =
            Internal.heading level [] [ Html.text "Title" ]
                |> Query.fromHtml
                |> Query.has [ Selector.tag tag ]
    in
    describe "heading"
        [ describe "levels one to six"
            (List.map
                (\level ->
                    test ("level " ++ String.fromInt level) <|
                        \_ -> hasTag level ("h" ++ String.fromInt level)
                )
                (List.range 1 6)
            )
        , test "a number below one is a level three" <|
            \_ -> hasTag 0 "h3"
        , test "a number above six is a level three" <|
            \_ -> hasTag 7 "h3"
        ]
