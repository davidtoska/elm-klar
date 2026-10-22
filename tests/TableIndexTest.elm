module TableIndexTest exposing (suite)

import Array exposing (Array)
import Expect
import Fuzz exposing (Fuzzer)
import Klar.Table.Index as Index exposing (Index, Level(..))
import Klar.Table.Sort as Sorting
import Test exposing (Test, describe, fuzz, fuzz2, test)


{-| A row for these tests: a number that is sometimes missing, and a word.
-}
type alias Row =
    { size : Maybe Int
    , word : String
    }


rowFuzzer : Fuzzer Row
rowFuzzer =
    Fuzz.map2 Row
        (Fuzz.oneOf [ Fuzz.constant Nothing, Fuzz.map Just (Fuzz.intRange 0 5) ])
        (Fuzz.oneOfValues [ "ada", "alan", "grace", "edsger", "barbara", "ada lovelace" ])


rowsFuzzer : Fuzzer (List Row)
rowsFuzzer =
    Fuzz.listOfLengthBetween 0 60 rowFuzzer


sizeKey : Row -> Sorting.Key
sizeKey row =
    Sorting.numberKey (Maybe.map toFloat row.size)


wordKey : Row -> Sorting.Key
wordKey row =
    Sorting.Text row.word


indexOf : List Row -> Index
indexOf rows =
    Index.build (Array.fromList rows)
        { search = Just .word
        , sorts = [ ( "size", sizeKey ), ( "word", wordKey ) ]
        }


{-| The plain way: filter the rows, then sort them with the generic stable sort.
-}
reference : List Row -> List String -> (Row -> Bool) -> List (Sorting.Level ( Int, Row )) -> List Int
reference rows words test levels =
    rows
        |> List.indexedMap Tuple.pair
        |> List.filter (\( _, row ) -> List.all (\word -> String.contains word row.word) words && test row)
        |> Sorting.sort levels
        |> List.map Tuple.first


fast : List Row -> Index -> List String -> (Row -> Bool) -> List Level -> Index.Matches
fast rows index words test levels =
    let
        array =
            Array.fromList rows

        rowAt position =
            Array.get position array
    in
    Index.matching (Just index)
        { count = Array.length array
        , words = words
        , tests = [ \position -> rowAt position |> Maybe.map test |> Maybe.withDefault False ]
        , levels = levels
        }


suite : Test
suite =
    describe "Klar.Table.Index"
        [ describe "sorted order"
            [ fuzz2 rowsFuzzer Fuzz.bool "a ranked column matches the stable sort, in both directions" <|
                \rows descending ->
                    let
                        index =
                            indexOf rows
                    in
                    fast rows index [] (always True) [ Ranked "size" descending ]
                        |> Index.allIndices
                        |> Expect.equal (reference rows [] (always True) [ Sorting.ByKey descending (\( _, row ) -> sizeKey row) ])
            , fuzz2 rowsFuzzer Fuzz.bool "text keys too" <|
                \rows descending ->
                    fast rows (indexOf rows) [] (always True) [ Ranked "word" descending ]
                        |> Index.allIndices
                        |> Expect.equal (reference rows [] (always True) [ Sorting.ByKey descending (\( _, row ) -> wordKey row) ])
            , test "rows without a value come last in both directions" <|
                \_ ->
                    let
                        rows =
                            [ Row Nothing "a", Row (Just 2) "b", Row (Just 1) "c", Row Nothing "d" ]
                    in
                    Expect.equal ( [ 2, 1, 0, 3 ], [ 1, 2, 0, 3 ] )
                        ( fast rows (indexOf rows) [] (always True) [ Ranked "size" False ] |> Index.allIndices
                        , fast rows (indexOf rows) [] (always True) [ Ranked "size" True ] |> Index.allIndices
                        )
            ]
        , describe "filtering and sorting"
            [ fuzz2 rowsFuzzer (Fuzz.oneOfValues [ [], [ "a" ], [ "ad", "lo" ], [ "zz" ] ]) "search words and a test, then a ranked sort" <|
                \rows words ->
                    let
                        test row =
                            row.size /= Just 3
                    in
                    fast rows (indexOf rows) words test [ Ranked "size" True ]
                        |> Index.allIndices
                        |> Expect.equal (reference rows words test [ Sorting.ByKey True (\( _, row ) -> sizeKey row) ])
            , fuzz2 rowsFuzzer Fuzz.bool "levels worked out from the rows give the same answer as ranked ones" <|
                \rows descending ->
                    let
                        array =
                            Array.fromList rows

                        keyOf position =
                            Array.get position array |> Maybe.map sizeKey |> Maybe.withDefault Sorting.Missing
                    in
                    fast rows (indexOf rows) [ "a" ] (always True) [ Keyed descending keyOf ]
                        |> Index.allIndices
                        |> Expect.equal (reference rows [ "a" ] (always True) [ Sorting.ByKey descending (\( _, row ) -> sizeKey row) ])
            , fuzz2 rowsFuzzer (Fuzz.pair Fuzz.bool Fuzz.bool) "two levels, one of them a comparator" <|
                \rows ( first, second ) ->
                    let
                        array =
                            Array.fromList rows

                        rowAt position =
                            Array.get position array |> Maybe.withDefault (Row Nothing "")

                        byWord a b =
                            compare (rowAt a).word (rowAt b).word
                    in
                    fast rows (indexOf rows) [] (always True)
                        [ Keyed first (rowAt >> sizeKey)
                        , Compared second byWord
                        ]
                        |> Index.allIndices
                        |> Expect.equal
                            (reference rows
                                []
                                (always True)
                                [ Sorting.ByKey first (\( _, row ) -> sizeKey row)
                                , Sorting.ByComparator second (\( _, a ) ( _, b ) -> compare a.word b.word)
                                ]
                            )
            , test "searching without a search text in the index matches nothing" <|
                \_ ->
                    let
                        rows =
                            [ Row Nothing "ada" ]

                        bare =
                            Index.build (Array.fromList rows) { search = Nothing, sorts = [] }
                    in
                    Index.matching (Just bare) { count = 1, words = [ "ada" ], tests = [], levels = [] }
                        |> Index.matchCount
                        |> Expect.equal 0
            ]
        , describe "pages"
            [ fuzz2 rowsFuzzer (Fuzz.pair (Fuzz.intRange -3 70) (Fuzz.intRange 0 30)) "a page is a slice of the matches, whatever the offset and size" <|
                \rows ( offset, size ) ->
                    let
                        matches =
                            fast rows (indexOf rows) [] (always True) [ Ranked "size" False ]
                    in
                    Index.pageIndices offset size matches
                        |> Expect.equal (Index.allIndices matches |> List.drop (max 0 offset) |> List.take size)
            , test "the count is the number of matches" <|
                \_ ->
                    let
                        rows =
                            List.map (\n -> Row (Just n) "ada") (List.range 1 10)
                    in
                    fast rows (indexOf rows) [] (\row -> row.size /= Just 4) []
                        |> Index.matchCount
                        |> Expect.equal 9
            ]
        ]
