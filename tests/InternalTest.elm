module InternalTest exposing (suite)

{-| The shared helpers of the components that can be tested without a view.
-}

import Expect
import Fuzz
import Html
import Klar.Internal as Internal
import Test exposing (Test, describe, fuzz, test)
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
