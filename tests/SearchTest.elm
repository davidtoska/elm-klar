module SearchTest exposing (suite)

import Expect
import Fuzz
import Html
import Klar.Search as Search
import Test exposing (Test, describe, fuzz, test)
import Test.Html.Query as Query
import Test.Html.Selector as Selector


suite : Test
suite =
    describe "Klar.Search"
        [ scoring
        , normalizing
        , prepared
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
        ]
