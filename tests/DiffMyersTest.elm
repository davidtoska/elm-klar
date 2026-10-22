module DiffMyersTest exposing (suite)

import Array exposing (Array)
import Expect
import Fuzz exposing (Fuzzer)
import Klar.Diff.Myers as Myers exposing (Run(..))
import Test exposing (Test, describe, fuzz2, test)


suite : Test
suite =
    describe "Klar.Diff.Myers"
        [ describe "known cases"
            [ test "equal sequences are one run" <|
                \_ -> Expect.equal (Just [ Same 3 ]) (run [ 1, 2, 3 ] [ 1, 2, 3 ])
            , test "two empty sequences have no runs" <|
                \_ -> Expect.equal (Just []) (run [] [])
            , test "everything is inserted into an empty sequence" <|
                \_ -> Expect.equal (Just [ Insert 2 ]) (run [] [ 1, 2 ])
            , test "everything is removed when the new sequence is empty" <|
                \_ -> Expect.equal (Just [ Remove 2 ]) (run [ 1, 2 ] [])
            , test "a change in the middle" <|
                \_ -> Expect.equal (Just [ Same 1, Remove 1, Insert 1, Same 1 ]) (run [ 1, 2, 3 ] [ 1, 9, 3 ])
            , test "an insertion at the start" <|
                \_ -> Expect.equal (Just [ Insert 1, Same 2 ]) (run [ 1, 2 ] [ 0, 1, 2 ])
            , test "an insertion at the end" <|
                \_ -> Expect.equal (Just [ Same 2, Insert 1 ]) (run [ 1, 2 ] [ 1, 2, 3 ])
            , test "a removal at the start and at the end" <|
                \_ -> Expect.equal (Just [ Remove 1, Same 1, Remove 1 ]) (run [ 1, 2, 3 ] [ 2 ])
            , test "the example of the paper (ABCABBA to CBABAC) needs five edits" <|
                \_ ->
                    run [ 1, 2, 3, 1, 2, 2, 1 ] [ 3, 2, 1, 2, 1, 3 ]
                        |> Maybe.map editCount
                        |> Expect.equal (Just 5)
            , test "the removals of a stretch of changes come before its insertions" <|
                \_ -> Expect.equal (Just [ Remove 2, Insert 3, Same 1 ]) (run [ 1, 2, 7 ] [ 4, 5, 6, 7 ])
            , test "completely different sequences are removed and inserted" <|
                \_ -> Expect.equal (Just [ Remove 3, Insert 2 ]) (run [ 1, 2, 3 ] [ 4, 5 ])
            ]
        , describe "the budget"
            [ test "a diff that needs more work than the budget gives up" <|
                \_ ->
                    Myers.diff 50 (Array.fromList (List.range 0 399)) (Array.fromList (List.range 1000 1399))
                        |> Expect.equal Nothing
            , test "the same texts are found with a larger budget" <|
                \_ ->
                    Myers.diff 10000000 (Array.fromList (List.range 0 199)) (Array.fromList (List.range 1000 1199))
                        |> Expect.equal (Just [ Remove 200, Insert 200 ])
            , test "a long text with a few changes is cheap because the ends are cut off" <|
                \_ ->
                    let
                        old =
                            List.range 0 99999

                        new =
                            List.range 0 49999 ++ [ -1 ] ++ List.range 50001 99999
                    in
                    Myers.diff 1000 (Array.fromList old) (Array.fromList new)
                        |> Expect.equal (Just [ Same 50000, Remove 1, Insert 1, Same 49999 ])
            ]
        , describe "properties"
            [ fuzz2 smallSequence smallSequence "the runs cover both sequences exactly" <|
                \old new ->
                    case run old new of
                        Just runs ->
                            Expect.equal ( List.length old, List.length new ) (covered runs)

                        Nothing ->
                            Expect.fail "the budget was not enough"
            , fuzz2 smallSequence smallSequence "the runs turn the old sequence into the new one" <|
                \old new ->
                    case run old new of
                        Just runs ->
                            Expect.equal new (apply old new runs)

                        Nothing ->
                            Expect.fail "the budget was not enough"
            , fuzz2 smallSequence smallSequence "the runs are the shortest possible (old + new - 2 * the longest common subsequence)" <|
                \old new ->
                    case run old new of
                        Just runs ->
                            Expect.equal (List.length old + List.length new - 2 * lcs old new) (editCount runs)

                        Nothing ->
                            Expect.fail "the budget was not enough"
            , fuzz2 smallSequence smallSequence "the runs are in the normal form" <|
                \old new ->
                    case run old new of
                        Just runs ->
                            Expect.equal [] (normalFormProblems runs)

                        Nothing ->
                            Expect.fail "the budget was not enough"
            , fuzz2 smallSequence smallSequence "the diff of a sequence with itself has no edits" <|
                \old _ ->
                    run old old
                        |> Maybe.map editCount
                        |> Expect.equal (Just 0)
            , fuzz2 smallSequence smallSequence "swapping the sequences swaps removals and insertions" <|
                \old new ->
                    Maybe.map2 (\forward backward -> ( editCount forward, editCount backward ))
                        (run old new)
                        (run new old)
                        |> Maybe.map (\( a, b ) -> a == b)
                        |> Expect.equal (Just True)
            ]
        ]


smallSequence : Fuzzer (List Int)
smallSequence =
    Fuzz.listOfLengthBetween 0 24 (Fuzz.intRange 0 4)


run : List Int -> List Int -> Maybe (List Run)
run old new =
    Myers.diff 1000000 (Array.fromList old) (Array.fromList new)


editCount : List Run -> Int
editCount runs =
    List.sum
        (List.map
            (\r ->
                case r of
                    Same _ ->
                        0

                    Remove n ->
                        n

                    Insert n ->
                        n
            )
            runs
        )


{-| How many elements of the old and of the new sequence the runs cover.
-}
covered : List Run -> ( Int, Int )
covered runs =
    List.foldl
        (\r ( o, n ) ->
            case r of
                Same count ->
                    ( o + count, n + count )

                Remove count ->
                    ( o + count, n )

                Insert count ->
                    ( o, n + count )
        )
        ( 0, 0 )
        runs


{-| Walks the runs over the old sequence and builds the new one from them. A run
of `Same` must really be equal in both.
-}
apply : List Int -> List Int -> List Run -> List Int
apply old new runs =
    let
        step r ( oldRest, newRest, built ) =
            case r of
                Same count ->
                    let
                        shared =
                            List.take count oldRest
                    in
                    if shared == List.take count newRest then
                        ( List.drop count oldRest, List.drop count newRest, built ++ shared )

                    else
                        ( [], [], built ++ [ -999 ] )

                Remove count ->
                    ( List.drop count oldRest, newRest, built )

                Insert count ->
                    ( oldRest, List.drop count newRest, built ++ List.take count newRest )
    in
    List.foldl step ( old, new, [] ) runs
        |> (\( _, _, built ) -> built)


normalFormProblems : List Run -> List String
normalFormProblems runs =
    let
        empty r =
            case r of
                Same 0 ->
                    True

                Remove 0 ->
                    True

                Insert 0 ->
                    True

                _ ->
                    False

        adjacent pair =
            case pair of
                ( Same _, Same _ ) ->
                    Just "two runs of Same"

                ( Remove _, Remove _ ) ->
                    Just "two runs of Remove"

                ( Insert _, Insert _ ) ->
                    Just "two runs of Insert"

                ( Insert _, Remove _ ) ->
                    Just "an insertion before a removal"

                _ ->
                    Nothing
    in
    (if List.any empty runs then
        [ "a run of length 0" ]

     else
        []
    )
        ++ List.filterMap adjacent (List.map2 Tuple.pair runs (List.drop 1 runs))


{-| The length of the longest common subsequence, the slow way.
-}
lcs : List Int -> List Int -> Int
lcs old new =
    let
        newArray =
            Array.fromList new

        row oldItem previous =
            let
                go j left built =
                    case Array.get j newArray of
                        Nothing ->
                            List.reverse built

                        Just newItem ->
                            let
                                diagonal =
                                    Array.get j previous |> Maybe.withDefault 0

                                up =
                                    Array.get (j + 1) previous |> Maybe.withDefault 0

                                value =
                                    if oldItem == newItem then
                                        diagonal + 1

                                    else
                                        max left up
                            in
                            go (j + 1) value (value :: built)
            in
            Array.fromList (0 :: go 0 0 [])
    in
    List.foldl row (Array.repeat (List.length new + 1) 0) old
        |> Array.get (List.length new)
        |> Maybe.withDefault 0
