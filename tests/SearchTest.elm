module SearchTest exposing (suite)

import Expect
import Fuzz exposing (Fuzzer)
import Html
import Klar.Search as Search
import Test exposing (Test, describe, fuzz, fuzz2, test)
import Test.Html.Query as Query
import Test.Html.Selector as Selector


suite : Test
suite =
    describe "Klar.Search"
        [ scoring
        , normalizing
        , prepared
        , equivalence
        , filtering
        , highlighting
        ]


scoring : Test
scoring =
    describe "score"
        [ test "the same text scores 0" <|
            \_ -> Expect.equal (Just 0) (Search.score "ada" "Ada")
        , test "a prefix scores 1" <|
            \_ -> Expect.equal (Just 1) (Search.score "ada" "Ada Lovelace")
        , test "a word inside the text scores 2" <|
            \_ -> Expect.equal (Just 2) (Search.score "lovelace" "Ada Lovelace")
        , test "a word after a hyphen scores 2" <|
            \_ -> Expect.equal (Just 2) (Search.score "lovelace" "Ada-Lovelace")
        , test "a word after a slash scores 2" <|
            \_ -> Expect.equal (Just 2) (Search.score "b" "a/b")
        , test "a part of a word scores 3" <|
            \_ -> Expect.equal (Just 3) (Search.score "ovel" "Ada Lovelace")
        , test "all words must match, and the scores are added" <|
            \_ -> Expect.equal (Just 3) (Search.score "lovelace ada" "Ada Lovelace")
        , test "one missing word is no match" <|
            \_ -> Expect.equal Nothing (Search.score "ada xyz" "Ada Lovelace")
        , test "no match" <|
            \_ -> Expect.equal Nothing (Search.score "xyz" "Ada Lovelace")
        , test "an empty query matches everything" <|
            \_ -> Expect.equal (Just 0) (Search.score "" "anything")
        , test "a query of spaces matches everything" <|
            \_ -> Expect.equal (Just 0) (Search.score "   " "anything")
        , test "diacritics are ignored (ø and o)" <|
            \_ -> Expect.equal (Just 0) (Search.score "orsted" "Ørsted")
        , test "diacritics are ignored in the query too" <|
            \_ -> Expect.equal (Just 0) (Search.score "Ørsted" "orsted")
        , test "case is ignored" <|
            \_ -> Expect.equal (Just 1) (Search.score "BERGEN" "bergen kommune")
        , test "letters in order and close together match loosely" <|
            \_ -> Expect.equal (Just 6) (Search.score "brgn" "Bergen")
        , test "letters far apart do not" <|
            \_ -> Expect.equal Nothing (Search.score "aron" "Navigation and structure")
        , test "two letters are never fuzzy" <|
            \_ -> Expect.equal Nothing (Search.score "bn" "Bergen")
        , test "a close match further on is found when an earlier word has the first letter" <|
            \_ -> Expect.equal (Just 6) (Search.score "brgn" "Bob's Bergen")
        , test "the walk tries the next start when the first window is too wide" <|
            \_ -> Expect.equal (Just 6) (Search.score "lvlc" "Lars Ada Lovelace")
        , test "letters within 2n + 2 characters match" <|
            \_ -> Expect.equal (Just 6) (Search.score "abc" "axxxxxbc")
        , test "letters one character wider than 2n + 2 do not" <|
            \_ -> Expect.equal Nothing (Search.score "abc" "axxxxxxbc")
        , test "a swapped letter is not forgiven" <|
            \_ -> Expect.equal Nothing (Search.score "lvoelace" "Ada Lovelace")
        , test "matches" <|
            \_ -> Expect.equal [ True, False ] [ Search.matches "ber" "Bergen", Search.matches "ber" "Oslo" ]
        ]


normalizing : Test
normalizing =
    describe "normalize"
        [ test "folds accents and case" <|
            \_ -> Expect.equal "aoaeun" (Search.normalize "ÆØÅéüñ")
        , test "keeps the length, so match positions line up" <|
            \_ -> Expect.equal 13 (String.length (Search.normalize "ÆØÅéüñ ÀÁÂÃÄÅ"))
        , fuzz Fuzz.string "never changes the length of plain text" <|
            \text ->
                let
                    plain =
                        String.filter (\c -> Char.toCode c < 128) text
                in
                Expect.equal (String.length plain) (String.length (Search.normalize plain))
        , fuzz Fuzz.string "is idempotent" <|
            \text -> Expect.equal (Search.normalize text) (Search.normalize (Search.normalize text))
        ]


prepared : Test
prepared =
    let
        texts =
            [ "a", "Bergen", "Ørsted", "Ada Lovelace", "", "x-y/z" ]

        queries =
            [ "a", "ber", "orsted", "lovelace ada", "", "z", "brgn" ]
    in
    describe "prepared texts"
        [ test "prepareMany gives one entry for every text" <|
            \_ -> Expect.equal (List.length texts) (List.length (Search.prepareMany texts))
        , test "prepareMany of nothing is nothing" <|
            \_ -> Expect.equal 0 (List.length (Search.prepareMany []))
        , test "prepared and plain scoring agree on every combination" <|
            \_ ->
                let
                    plain =
                        List.concatMap (\q -> List.map (Search.score q) texts) queries

                    fast =
                        List.concatMap
                            (\q -> List.map (Search.scorePrepared (Search.query q)) (Search.prepareMany texts))
                            queries

                    single =
                        List.concatMap
                            (\q -> List.map (\t -> Search.scorePrepared (Search.query q) (Search.prepare t)) texts)
                            queries
                in
                Expect.equal ( plain, plain ) ( fast, single )
        , test "texts that contain the separator character still work" <|
            \_ ->
                Expect.equal [ Just 0, Just 0 ]
                    (Search.prepareMany [ "a\u{0001}b", "c" ]
                        |> List.map2 (\q p -> Search.scorePrepared (Search.query q) p) [ "a\u{0001}b", "c" ]
                    )
        ]



-- EQUIVALENCE


{-| The scoring as it was before the cheap letter test, written out on plain
strings: the pre-filter may only make it faster, never change an answer.
-}
referenceScore : String -> String -> Maybe Int
referenceScore queryText text =
    let
        haystack =
            Search.normalize text

        spaced =
            " " ++ String.replace "-" " " (String.replace "/" " " haystack)

        words =
            Search.normalize queryText |> String.words |> List.filter (\w -> w /= "")

        scoreWord word =
            if haystack == word then
                Just 0

            else if String.startsWith word haystack then
                Just 1

            else if String.contains (" " ++ word) spaced then
                Just 2

            else if String.contains word haystack then
                Just 3

            else if String.length word >= 3 && loose (String.split "" word) haystack then
                Just 6

            else
                Nothing
    in
    List.foldl (\word total -> Maybe.map2 (+) total (scoreWord word)) (Just 0) words


{-| The letters in order within `2n + 2` characters, from any place where the first
letter occurs (the corpus is short, so the limit of starts never applies).
-}
loose : List String -> String -> Bool
loose letters haystack =
    case letters of
        first :: _ ->
            List.any (\start -> looseFrom letters (String.dropLeft start haystack) start) (String.indexes first haystack)

        [] ->
            False


looseFrom : List String -> String -> Int -> Bool
looseFrom letters haystack origin =
    let
        step letter ( rest, offset, first ) =
            case ( rest, first ) of
                ( Nothing, _ ) ->
                    ( Nothing, offset, first )

                ( Just text, _ ) ->
                    case String.indexes letter text of
                        position :: _ ->
                            ( Just (String.dropLeft (position + String.length letter) text)
                            , offset + position + String.length letter
                            , Maybe.withDefault (offset + position) first |> Just
                            )

                        [] ->
                            ( Nothing, offset, first )

        ( outcome, end, start ) =
            List.foldl step ( Just haystack, origin, Nothing ) letters
    in
    case ( outcome, start ) of
        ( Just _, Just from ) ->
            end - from <= 2 * List.length letters + 2

        _ ->
            False


{-| Short texts over a small alphabet, so loose matches, exact matches and
misses all happen often.
-}
corpusText : Fuzzer String
corpusText =
    Fuzz.listOfLengthBetween 0 14 (Fuzz.oneOfValues [ "a", "b", "c", "d", "e", " ", "-", "/", "A", "Ø" ])
        |> Fuzz.map String.concat


corpusQuery : Fuzzer String
corpusQuery =
    Fuzz.listOfLengthBetween 0 6 (Fuzz.oneOfValues [ "a", "b", "c", "d", "e", " ", "A" ])
        |> Fuzz.map String.concat


equivalence : Test
equivalence =
    describe "the pre-filter changes no score"
        [ fuzz2 corpusQuery (Fuzz.listOfLengthBetween 0 40 corpusText) "scorePrepared equals the plain scoring on a random corpus" <|
            \queryText texts ->
                let
                    query =
                        Search.query queryText
                in
                Expect.equal
                    (List.map (referenceScore queryText) texts)
                    (List.map (Search.scorePrepared query) (Search.prepareMany texts))
        , fuzz2 corpusQuery (Fuzz.listOfLengthBetween 0 40 corpusText) "rank keeps the same texts and scores" <|
            \queryText texts ->
                let
                    expected =
                        texts
                            |> List.filterMap (\text -> referenceScore queryText text |> Maybe.map (\points -> ( points, text )))
                            |> List.sortBy Tuple.first
                in
                if String.isEmpty (String.trim queryText) then
                    Expect.pass

                else
                    Expect.equal expected (Search.rank identity queryText texts)
        ]


filtering : Test
filtering =
    describe "filter and rank"
        [ test "best matches first" <|
            \_ -> Expect.equal [ "Bergen", "Åsberg" ] (Search.filter identity "ber" [ "Åsberg", "Oslo", "Bergen" ])
        , test "equal scores keep their order" <|
            \_ -> Expect.equal [ "b1", "b2", "b3" ] (Search.filter identity "b" [ "b1", "b2", "b3" ])
        , test "an empty query leaves the list alone" <|
            \_ -> Expect.equal [ "b", "a" ] (Search.filter identity "  " [ "b", "a" ])
        , test "works on records" <|
            \_ -> Expect.equal [ 2 ] (Search.filter .name "lov" [ { id = 1, name = "Alan" }, { id = 2, name = "Lovelace" } ] |> List.map .id)
        , test "rank keeps the scores" <|
            \_ -> Expect.equal [ ( 1, "Bergen" ), ( 3, "Åsberg" ) ] (Search.rank identity "ber" [ "Åsberg", "Oslo", "Bergen" ])
        ]


highlighting : Test
highlighting =
    let
        markCount query text =
            Html.span [] (Search.highlight query text)
                |> Query.fromHtml
                |> Query.findAll [ Selector.tag "mark" ]
                |> Query.count (Expect.equal 1)
    in
    describe "highlight"
        [ test "marks the match" <|
            \_ -> markCount "ber" "Bergen"
        , test "marks only the match and keeps the rest of the text" <|
            \_ ->
                Html.span [] (Search.highlight "ber" "Bergen")
                    |> Query.fromHtml
                    |> Expect.all
                        [ Query.find [ Selector.tag "mark" ] >> Query.has [ Selector.text "Ber" ]
                        , Query.has [ Selector.text "gen" ]
                        ]
        , test "marks through accents" <|
            \_ ->
                Html.span [] (Search.highlight "orsted" "Ørsted")
                    |> Query.fromHtml
                    |> Query.find [ Selector.tag "mark" ]
                    |> Query.has [ Selector.text "Ørsted" ]
        , test "an empty query marks nothing" <|
            \_ ->
                Html.span [] (Search.highlight "" "Bergen")
                    |> Query.fromHtml
                    |> Query.findAll [ Selector.tag "mark" ]
                    |> Query.count (Expect.equal 0)
        , test "overlapping words are merged into one mark" <|
            \_ -> markCount "ber erg" "Bergen"
        , test "the mark has the class of a highlight, not of a colour dot" <|
            \_ ->
                Html.span [] (Search.highlight "ber" "Bergen")
                    |> Query.fromHtml
                    |> Query.find [ Selector.tag "mark" ]
                    |> Expect.all
                        [ Query.has [ Selector.class "klar-highlight" ]
                        , Query.hasNot [ Selector.class "klar-mark" ]
                        ]
        , test "marks the word start that the score used, not an earlier part of a word" <|
            \_ ->
                Html.span [] (Search.highlight "ber" "Åsberg Bergen")
                    |> Query.fromHtml
                    |> Expect.all
                        [ Query.findAll [ Selector.tag "mark" ] >> Query.count (Expect.equal 1)
                        , Query.find [ Selector.tag "mark" ] >> Query.has [ Selector.text "Ber" ]
                        , Query.has [ Selector.text "Åsberg " ]
                        ]
        , test "marks each letter of a match of letters in order" <|
            \_ ->
                Html.span [] (Search.highlight "lvlc" "Ada Lovelace")
                    |> Query.fromHtml
                    |> Query.findAll [ Selector.tag "mark" ]
                    |> Expect.all
                        [ Query.count (Expect.equal 4)
                        , Query.first >> Query.has [ Selector.text "L" ]
                        , Query.index 3 >> Query.has [ Selector.text "c" ]
                        ]
        , test "marks the letters of the close match, not the first letter of an earlier word" <|
            \_ ->
                Html.span [] (Search.highlight "brgn" "Bob's Bergen")
                    |> Query.fromHtml
                    |> Query.findAll [ Selector.tag "mark" ]
                    |> Expect.all
                        [ Query.count (Expect.equal 3)
                        , Query.first >> Query.has [ Selector.text "B" ]
                        , Query.index 1 >> Query.has [ Selector.text "rg" ]
                        ]
        , test "a word that does not match marks nothing and keeps the text" <|
            \_ ->
                Html.span [] (Search.highlight "xyz" "Bergen")
                    |> Query.fromHtml
                    |> Expect.all
                        [ Query.findAll [ Selector.tag "mark" ] >> Query.count (Expect.equal 0)
                        , Query.has [ Selector.text "Bergen" ]
                        ]
        ]
