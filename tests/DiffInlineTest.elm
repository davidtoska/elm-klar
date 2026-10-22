module DiffInlineTest exposing (suite)

import Expect
import Fuzz exposing (Fuzzer)
import Klar.Diff.Inline as Inline exposing (Segment(..))
import Test exposing (Test, describe, fuzz2, test)


suite : Test
suite =
    describe "Klar.Diff.Inline"
        [ describe "tokens"
            [ test "words, white space and punctuation" <|
                \_ -> Expect.equal [ "Total", ":", " ", "12", ".", "50" ] (Inline.tokens "Total: 12.50")
            , test "a run of white space is one token" <|
                \_ -> Expect.equal [ "a", "  \t", "b" ] (Inline.tokens "a  \tb")
            , test "every punctuation character is a token of its own" <|
                \_ -> Expect.equal [ "(", "(", "x", ")", ")" ] (Inline.tokens "((x))")
            , test "letters outside ASCII belong to words" <|
                \_ -> Expect.equal [ "ørret", " ", "på", " ", "Ålesund" ] (Inline.tokens "ørret på Ålesund")
            , test "typographic punctuation is punctuation" <|
                \_ -> Expect.equal [ "“", "ja", "”" ] (Inline.tokens "“ja”")
            , test "an emoji stays whole" <|
                \_ -> Expect.equal [ "😀", " ", "ok" ] (Inline.tokens "😀 ok")
            , test "no text, no tokens" <|
                \_ -> Expect.equal [] (Inline.tokens "")
            , fuzz2 anyText anyText "the tokens make the text again" <|
                \a b ->
                    Expect.equal (a ++ b) (String.concat (Inline.tokens (a ++ b)))
            ]
        , describe "the segments"
            [ test "equal texts are kept" <|
                \_ -> Expect.equal [ Keep "same" ] (Inline.diff "same" "same")
            , test "two empty texts have no segments" <|
                \_ -> Expect.equal [] (Inline.diff "" "")
            , test "a changed digit in a long number is marked alone" <|
                \_ ->
                    Expect.equal [ Keep "Total: 12", Replace "3" "8", Keep "4.50" ]
                        (Inline.diff "Total: 1234.50" "Total: 1284.50")
            , test "a changed short number is marked as a whole" <|
                \_ ->
                    Expect.equal [ Keep "Price ", Replace "12" "14", Keep ".", Replace "50" "00" ]
                        (Inline.diff "Price 12.50" "Price 14.00")
            , test "a replaced word is marked as a whole when the words have little in common" <|
                \_ ->
                    Expect.equal [ Keep "ship to the ", Replace "warehouse" "depot" ]
                        (Inline.diff "ship to the warehouse" "ship to the depot")
            , test "words of ordinary length are marked as a whole" <|
                \_ ->
                    Expect.equal [ Replace "Shipping" "Shipment", Keep " policy" ]
                        (Inline.diff "Shipping policy" "Shipment policy")
            , test "very long words are marked from where they differ" <|
                \_ ->
                    Expect.equal [ Keep "internationali", Replace "z" "s", Keep "ation" ]
                        (Inline.diff "internationalization" "internationalisation")
            , test "an order number that differs in its last digit" <|
                \_ ->
                    Expect.equal [ Keep "order-100", Replace "1" "2" ]
                        (Inline.diff "order-1001" "order-1002")
            , test "an added word" <|
                \_ ->
                    Inline.diff "free shipping" "free express shipping"
                        |> Inline.addedText
                        |> Expect.equal "free express shipping"
            , test "white space between two replacements joins them" <|
                \_ ->
                    Expect.equal [ Replace "foo bar" "baz qux" ]
                        (Inline.diff "foo bar" "baz qux")
            , test "two texts with nothing in common are one replacement" <|
                \_ -> Expect.equal [ Replace "alpha one" "gamma two" ] (Inline.diff "alpha one" "gamma two")
            , test "a change in the white space" <|
                \_ -> Expect.equal [ Keep "a", Replace "  " " ", Keep "b" ] (Inline.diff "a  b" "a b")
            , test "a missing text is added whole" <|
                \_ -> Expect.equal [ Replace "" "new" ] (Inline.diff "" "new")
            , test "a very long text is not compared in detail" <|
                \_ ->
                    let
                        long =
                            String.repeat 5000 "a"
                    in
                    Expect.equal [ Replace long (long ++ "b") ] (Inline.diff long (long ++ "b"))
            , test "an emoji is never cut in the middle" <|
                \_ ->
                    Inline.diff "😀 one" "😁 one"
                        |> Expect.all
                            [ \segments -> Expect.equal "😀 one" (Inline.removedText segments)
                            , \segments -> Expect.equal "😁 one" (Inline.addedText segments)
                            , \segments -> Expect.equal False (List.any hasLoneSurrogate (List.concatMap texts segments))
                            ]
            ]
        , describe "properties"
            [ fuzz2 anyText anyText "the old texts of the segments make the old text, the new texts the new text" <|
                \old new ->
                    Inline.diff old new
                        |> Expect.all
                            [ \segments -> Expect.equal old (Inline.removedText segments)
                            , \segments -> Expect.equal new (Inline.addedText segments)
                            ]
            , fuzz2 anyText anyText "no segment is empty and no replacement replaces nothing with nothing" <|
                \old new ->
                    Inline.diff old new
                        |> List.filter
                            (\segment ->
                                case segment of
                                    Keep "" ->
                                        True

                                    Replace "" "" ->
                                        True

                                    _ ->
                                        False
                            )
                        |> Expect.equal []
            , fuzz2 anyText anyText "text without lone surrogates comes back without them" <|
                \old new ->
                    Inline.diff old new
                        |> List.concatMap texts
                        |> List.filter hasLoneSurrogate
                        |> Expect.equal []
            ]
        ]


texts : Segment -> List String
texts segment =
    case segment of
        Keep text ->
            [ text ]

        Replace removed added ->
            [ removed, added ]


{-| A UTF-16 unit of half an emoji, on its own.
-}
hasLoneSurrogate : String -> Bool
hasLoneSurrogate text =
    String.toList text
        |> List.any
            (\char ->
                let
                    code =
                        Char.toCode char
                in
                (code >= 0xD800 && code <= 0xDFFF) || isNaN (toFloat code)
            )


anyText : Fuzzer String
anyText =
    Fuzz.listOfLengthBetween 0
        14
        (Fuzz.oneOfValues [ "a", "b", "ab", " ", "  ", "12", "1234", "1284", ".", ",", "😀", "😁", "æ", "word", "words", "\t" ])
        |> Fuzz.map String.concat
