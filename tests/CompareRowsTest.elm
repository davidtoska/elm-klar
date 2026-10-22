module CompareRowsTest exposing (suite)

import Expect
import Fuzz exposing (Fuzzer)
import Klar.Compare.Rows as Rows exposing (Mark(..), Value(..))
import Test exposing (Test, describe, fuzz, fuzz2, test)


suite : Test
suite =
    describe "Klar.Compare.Rows"
        [ values
        , rows
        , baselines
        , keys
        , visibility
        ]


values : Test
values =
    describe "values"
        [ test "a text is a value" <|
            \_ -> Expect.equal (Value "12.50") (Rows.value "12.50")
        , test "an empty text is no value" <|
            \_ -> Expect.equal Missing (Rows.value "")
        , test "a blank text is no value" <|
            \_ -> Expect.equal Missing (Rows.value " \t\n")
        , test "a text with spaces around it keeps them" <|
            \_ -> Expect.equal (Value " a ") (Rows.value " a ")
        , test "a zero is a value" <|
            \_ -> Expect.equal (Value "0") (Rows.value "0")
        ]


rows : Test
rows =
    describe "comparing a row"
        [ test "all equal" <|
            \_ ->
                Rows.compareRow 0 [ Value "a", Value "a", Value "a" ]
                    |> Expect.equal { marks = [ Baseline, Same, Same ], allEqual = True }
        , test "one differs" <|
            \_ ->
                Rows.compareRow 0 [ Value "a", Value "a", Value "b" ]
                    |> Expect.equal { marks = [ Baseline, Same, Differs ], allEqual = False }
        , test "all differ" <|
            \_ ->
                Rows.compareRow 0 [ Value "a", Value "b", Value "c" ]
                    |> Expect.equal { marks = [ Baseline, Differs, Differs ], allEqual = False }
        , test "two records that have no value are the same" <|
            \_ ->
                Rows.compareRow 0 [ Missing, Missing ]
                    |> Expect.equal { marks = [ Baseline, Same ], allEqual = True }
        , test "a value and no value differ" <|
            \_ ->
                Rows.compareRow 0 [ Value "a", Missing ]
                    |> Expect.equal { marks = [ Baseline, Differs ], allEqual = False }
        , test "no value and a value differ" <|
            \_ ->
                Rows.compareRow 0 [ Missing, Value "a" ]
                    |> Expect.equal { marks = [ Baseline, Differs ], allEqual = False }
        , test "texts that differ in case or space differ" <|
            \_ ->
                Rows.compareRow 0 [ Value "a", Value "A", Value "a " ]
                    |> Expect.equal { marks = [ Baseline, Differs, Differs ], allEqual = False }
        , test "a single record has nothing to compare with" <|
            \_ ->
                Rows.compareRow 0 [ Value "a" ]
                    |> Expect.equal { marks = [ Alone ], allEqual = True }
        , test "no records, no marks" <|
            \_ ->
                Rows.compareRow 0 []
                    |> Expect.equal { marks = [], allEqual = True }
        , test "another record can be the baseline" <|
            \_ ->
                Rows.compareRow 2 [ Value "a", Value "b", Value "b" ]
                    |> Expect.equal { marks = [ Differs, Same, Baseline ], allEqual = False }
        , test "a baseline outside the records is the first record" <|
            \_ ->
                Expect.equal
                    (Rows.compareRow 0 [ Value "a", Value "b" ])
                    (Rows.compareRow 7 [ Value "a", Value "b" ])
        , test "a negative baseline is the first record" <|
            \_ ->
                Expect.equal
                    (Rows.compareRow 0 [ Value "a", Value "b" ])
                    (Rows.compareRow -1 [ Value "a", Value "b" ])
        , test "a hundred records, one differs" <|
            \_ ->
                let
                    hundred =
                        List.range 0 99
                            |> List.map
                                (\i ->
                                    if i == 57 then
                                        Value "other"

                                    else
                                        Value "same"
                                )

                    row =
                        Rows.compareRow 0 hundred
                in
                Expect.equal
                    { allEqual = False, marks = 100, differs = 1, same = 98 }
                    { allEqual = row.allEqual
                    , marks = List.length row.marks
                    , differs = List.length (List.filter ((==) Differs) row.marks)
                    , same = List.length (List.filter ((==) Same) row.marks)
                    }
        , test "a hundred equal records" <|
            \_ ->
                Rows.compareRow 0 (List.repeat 100 (Value "x"))
                    |> .allEqual
                    |> Expect.equal True
        , fuzz2 (Fuzz.intRange -3 12) (Fuzz.listOfLengthBetween 0 10 valueFuzzer) "there is one baseline mark, and one mark for every record, when there are two or more" <|
            \baseline found ->
                let
                    row =
                        Rows.compareRow baseline found
                in
                if List.length found >= 2 then
                    Expect.equal ( List.length found, 1 ) ( List.length row.marks, List.length (List.filter ((==) Baseline) row.marks) )

                else
                    Expect.equal (List.length found) (List.length row.marks)
        , fuzz (Fuzz.listOfLengthBetween 2 10 valueFuzzer) "a row is all equal exactly when every value is that of the first record" <|
            \found ->
                Expect.equal (List.all (\v -> v == (List.head found |> Maybe.withDefault Missing)) found) (Rows.compareRow 0 found).allEqual
        ]


valueFuzzer : Fuzzer Value
valueFuzzer =
    Fuzz.oneOfValues [ Missing, Value "a", Value "b", Value "c" ]


baselines : Test
baselines =
    describe "the baseline"
        [ test "the first record when none is wanted" <|
            \_ -> Expect.equal 0 (Rows.baselineIndex [ "a", "b", "c" ] Nothing)
        , test "the record with the wanted key" <|
            \_ -> Expect.equal 2 (Rows.baselineIndex [ "a", "b", "c" ] (Just "c"))
        , test "the first record when no record has the key" <|
            \_ -> Expect.equal 0 (Rows.baselineIndex [ "a", "b", "c" ] (Just "z"))
        , test "no records" <|
            \_ -> Expect.equal 0 (Rows.baselineIndex [] (Just "a"))
        ]


keys : Test
keys =
    describe "keys"
        [ test "different keys stay" <|
            \_ -> Expect.equal [ "a", "b", "c" ] (Rows.uniqueKeys [ "a", "b", "c" ])
        , test "a repeated key gets a number" <|
            \_ -> Expect.equal [ "a", "b", "a~2" ] (Rows.uniqueKeys [ "a", "b", "a" ])
        , test "a key that comes three times" <|
            \_ -> Expect.equal [ "a", "a~2", "a~3" ] (Rows.uniqueKeys [ "a", "a", "a" ])
        , test "no keys" <|
            \_ -> Expect.equal [] (Rows.uniqueKeys [])
        , fuzz (Fuzz.listOfLengthBetween 0 12 (Fuzz.oneOfValues [ "a", "b", "c" ])) "the keys are as many as before and all different" <|
            \found ->
                let
                    unique =
                        Rows.uniqueKeys found
                in
                Expect.all
                    [ \u -> Expect.equal (List.length found) (List.length u)
                    , \u -> Expect.equal [] (duplicates u)
                    ]
                    unique
        ]


duplicates : List String -> List String
duplicates found =
    List.filter (\key -> List.length (List.filter ((==) key) found) > 1) found


visibility : Test
visibility =
    let
        equalRow =
            Just { marks = [ Baseline, Same ], allEqual = True }

        differingRow =
            Just { marks = [ Baseline, Differs ], allEqual = False }

        labels items =
            List.map Tuple.first items
    in
    describe "which rows are drawn"
        [ test "all rows are drawn when the differences are not the only wanted" <|
            \_ ->
                Rows.visible False Tuple.second [ ( "Pricing", Nothing ), ( "SKU", equalRow ), ( "Price", differingRow ) ]
                    |> labels
                    |> Expect.equal [ "Pricing", "SKU", "Price" ]
        , test "rows that are equal are left out" <|
            \_ ->
                Rows.visible True Tuple.second [ ( "SKU", equalRow ), ( "Price", differingRow ) ]
                    |> labels
                    |> Expect.equal [ "Price" ]
        , test "a heading with no row left is left out" <|
            \_ ->
                Rows.visible True Tuple.second [ ( "Identity", Nothing ), ( "SKU", equalRow ), ( "Pricing", Nothing ), ( "Price", differingRow ) ]
                    |> labels
                    |> Expect.equal [ "Pricing", "Price" ]
        , test "a heading at the end is left out" <|
            \_ ->
                Rows.visible True Tuple.second [ ( "Price", differingRow ), ( "Notes", Nothing ), ( "Note", equalRow ) ]
                    |> labels
                    |> Expect.equal [ "Price" ]
        , test "when everything is equal nothing is left" <|
            \_ ->
                Rows.visible True Tuple.second [ ( "Identity", Nothing ), ( "SKU", equalRow ), ( "Name", equalRow ) ]
                    |> Expect.equal []
        , test "no rows" <|
            \_ -> Expect.equal [] (Rows.visible True Tuple.second [])
        ]
