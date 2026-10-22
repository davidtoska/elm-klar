module DiffJsonTest exposing (suite)

import Expect
import Json.Encode as Encode exposing (Value)
import Klar.Diff.Json as Json exposing (Step(..))
import Klar.Diff.Types exposing (Entry, Kind(..), Shown(..))
import Test exposing (Test, describe, test)


suite : Test
suite =
    describe "Klar.Diff.Json"
        [ paths
        , comparing
        , arrays
        , matching
        , showing
        , limits
        ]


position : Json.Options
position =
    { matchBy = Nothing }


run : Value -> Value -> List ( String, Kind )
run old new =
    Json.diff position old new
        |> List.map (\entry -> ( entry.label, entry.kind ))


obj : List ( String, Value ) -> Value
obj =
    Encode.object


list : List Value -> Value
list =
    Encode.list identity


text : Shown -> String
text shown =
    case shown of
        Text { parts } ->
            String.concat (List.map .text parts)

        NotJson ->
            "<not json>"

        TooDeep ->
            "<too deep>"


beforeAfter : Entry -> ( Maybe String, Maybe String )
beforeAfter entry =
    ( Maybe.map text entry.before, Maybe.map text entry.after )


paths : Test
paths =
    describe "paths"
        [ test "a key at the top" <|
            \_ -> Expect.equal "status" (Json.pathLabel [ Key "status" ])
        , test "keys and positions" <|
            \_ -> Expect.equal "items[2].price" (Json.pathLabel [ Key "items", Index 2, Key "price" ])
        , test "nested keys" <|
            \_ -> Expect.equal "customer.address.city" (Json.pathLabel [ Key "customer", Key "address", Key "city" ])
        , test "a key that is not a plain name is written in brackets" <|
            \_ -> Expect.equal "[\"ship to\"].name" (Json.pathLabel [ Key "ship to", Key "name" ])
        , test "a key with a dot is written in brackets" <|
            \_ -> Expect.equal "a[\"b.c\"]" (Json.pathLabel [ Key "a", Key "b.c" ])
        , test "a key with a quote is escaped" <|
            \_ -> Expect.equal "[\"say \\\"hi\\\"\"]" (Json.pathLabel [ Key "say \"hi\"" ])
        , test "a key with a hyphen or a dollar is a plain name" <|
            \_ -> Expect.equal "ship-to.$id" (Json.pathLabel [ Key "ship-to", Key "$id" ])
        , test "an empty key is written in brackets" <|
            \_ -> Expect.equal "a[\"\"]" (Json.pathLabel [ Key "a", Key "" ])
        , test "a key that starts with a digit is written in brackets" <|
            \_ -> Expect.equal "[\"1st\"]" (Json.pathLabel [ Key "1st" ])
        , test "a letter outside ASCII is part of a name" <|
            \_ -> Expect.equal "kunde.fødselsår" (Json.pathLabel [ Key "kunde", Key "fødselsår" ])
        , test "a record matched by a key" <|
            \_ -> Expect.equal "items[sku=A-100].qty" (Json.pathLabel [ Key "items", Match "sku" "A-100", Key "qty" ])
        , test "an array at the root" <|
            \_ -> Expect.equal "[0].price" (Json.pathLabel [ Index 0, Key "price" ])
        , test "the root itself" <|
            \_ -> Expect.equal "$" (Json.pathLabel [])
        ]


comparing : Test
comparing =
    describe "comparing values"
        [ test "equal values have no entries" <|
            \_ ->
                let
                    value =
                        obj [ ( "a", Encode.int 1 ), ( "b", list [ Encode.string "x", Encode.null ] ), ( "c", obj [ ( "d", Encode.bool True ) ] ) ]
                in
                Expect.equal [] (run value value)
        , test "a changed number" <|
            \_ -> Expect.equal [ ( "price", Changed ) ] (run (obj [ ( "price", Encode.float 12.5 ) ]) (obj [ ( "price", Encode.float 14 ) ]))
        , test "an added and a removed key, in order" <|
            \_ ->
                run (obj [ ( "b", Encode.int 1 ), ( "a", Encode.int 1 ), ( "z", Encode.int 1 ) ])
                    (obj [ ( "c", Encode.int 1 ), ( "a", Encode.int 1 ), ( "z", Encode.int 2 ) ])
                    |> Expect.equal [ ( "b", Removed ), ( "c", Added ), ( "z", Changed ) ]
        , test "the order does not depend on the order of the keys in the objects" <|
            \_ ->
                Expect.equal
                    (run (obj [ ( "x", Encode.int 1 ), ( "y", Encode.int 2 ) ]) (obj [ ( "y", Encode.int 3 ), ( "x", Encode.int 4 ) ]))
                    (run (obj [ ( "y", Encode.int 2 ), ( "x", Encode.int 1 ) ]) (obj [ ( "x", Encode.int 4 ), ( "y", Encode.int 3 ) ]))
        , test "numbers are compared exactly" <|
            \_ -> Expect.equal [ ( "n", Changed ) ] (run (obj [ ( "n", Encode.float (0.1 + 0.2) ) ]) (obj [ ( "n", Encode.float 0.3 ) ]))
        , test "1 and 1.0 are the same number" <|
            \_ -> Expect.equal [] (run (obj [ ( "n", Encode.int 1 ) ]) (obj [ ( "n", Encode.float 1.0 ) ]))
        , test "a very large number is compared as the number it is" <|
            \_ -> Expect.equal [ ( "n", Changed ) ] (run (obj [ ( "n", Encode.float 1.0e21 ) ]) (obj [ ( "n", Encode.float 1.0e22 ) ]))
        , test "NaN is equal to NaN" <|
            \_ -> Expect.equal [] (run (obj [ ( "n", Encode.float (0 / 0) ) ]) (obj [ ( "n", Encode.float (0 / 0) ) ]))
        , test "a string and a number are different" <|
            \_ -> Expect.equal [ ( "n", Changed ) ] (run (obj [ ( "n", Encode.string "1" ) ]) (obj [ ( "n", Encode.int 1 ) ]))
        , test "null and a missing key are different" <|
            \_ -> Expect.equal [ ( "n", Removed ) ] (run (obj [ ( "n", Encode.null ) ]) (obj []))
        , test "null and false are different" <|
            \_ -> Expect.equal [ ( "n", Changed ) ] (run (obj [ ( "n", Encode.null ) ]) (obj [ ( "n", Encode.bool False ) ]))
        , test "an object that becomes an array is one change" <|
            \_ -> Expect.equal [ ( "n", Changed ) ] (run (obj [ ( "n", obj [ ( "a", Encode.int 1 ) ] ) ]) (obj [ ( "n", list [ Encode.int 1 ] ) ]))
        , test "an added object is one entry" <|
            \_ ->
                Json.diff position (obj []) (obj [ ( "address", obj [ ( "city", Encode.string "Oslo" ), ( "zip", Encode.string "0150" ) ] ) ])
                    |> List.map (\entry -> ( entry.label, entry.kind, Maybe.map text entry.after ))
                    |> Expect.equal [ ( "address", Added, Just "{\"city\": \"Oslo\", \"zip\": \"0150\"}" ) ]
        , test "two scalars at the root" <|
            \_ -> Expect.equal [ ( "$", Changed ) ] (run (Encode.int 1) (Encode.int 2))
        , test "the key of an entry is its path" <|
            \_ ->
                Json.diff position (obj [ ( "a", obj [ ( "b", Encode.int 1 ) ] ) ]) (obj [ ( "a", obj [ ( "b", Encode.int 2 ) ] ) ])
                    |> List.map .key
                    |> Expect.equal [ "a.b" ]
        , test "the keys of the entries are all different" <|
            \_ ->
                let
                    old =
                        obj [ ( "a.b", Encode.int 1 ), ( "a", obj [ ( "b", Encode.int 1 ) ] ), ( "c", list [ Encode.int 1, Encode.int 2 ] ) ]

                    new =
                        obj [ ( "a.b", Encode.int 2 ), ( "a", obj [ ( "b", Encode.int 2 ) ] ), ( "c", list [ Encode.int 2, Encode.int 1, Encode.int 5 ] ) ]

                    keys =
                        List.map .key (Json.diff position old new)
                in
                Expect.equal (List.length keys) (List.length (List.sort keys |> dedupe))
        ]


dedupe : List String -> List String
dedupe sorted =
    case sorted of
        a :: b :: rest ->
            if a == b then
                dedupe (b :: rest)

            else
                a :: dedupe (b :: rest)

        _ ->
            sorted


arrays : Test
arrays =
    describe "arrays by position"
        [ test "a changed item" <|
            \_ ->
                run (list [ Encode.int 1, Encode.int 2, Encode.int 3 ]) (list [ Encode.int 1, Encode.int 9, Encode.int 3 ])
                    |> Expect.equal [ ( "[1]", Changed ) ]
        , test "added items at the end" <|
            \_ ->
                run (obj [ ( "tags", list [ Encode.string "a" ] ) ]) (obj [ ( "tags", list [ Encode.string "a", Encode.string "b", Encode.string "c" ] ) ])
                    |> Expect.equal [ ( "tags[1]", Added ), ( "tags[2]", Added ) ]
        , test "removed items at the end" <|
            \_ ->
                run (obj [ ( "tags", list [ Encode.string "a", Encode.string "b" ] ) ]) (obj [ ( "tags", list [ Encode.string "a" ] ) ])
                    |> Expect.equal [ ( "tags[1]", Removed ) ]
        , test "a field of an item" <|
            \_ ->
                run
                    (obj [ ( "items", list [ obj [ ( "price", Encode.int 1 ) ], obj [ ( "price", Encode.int 2 ) ], obj [ ( "price", Encode.int 3 ) ] ] ) ])
                    (obj [ ( "items", list [ obj [ ( "price", Encode.int 1 ) ], obj [ ( "price", Encode.int 2 ) ], obj [ ( "price", Encode.int 4 ) ] ] ) ])
                    |> Expect.equal [ ( "items[2].price", Changed ) ]
        , test "an item inserted at the start shifts the rest" <|
            \_ ->
                run (list [ Encode.string "a", Encode.string "b" ]) (list [ Encode.string "x", Encode.string "a", Encode.string "b" ])
                    |> Expect.equal [ ( "[0]", Changed ), ( "[1]", Changed ), ( "[2]", Added ) ]
        , test "an empty array and an empty object are no entries" <|
            \_ -> Expect.equal [] (run (obj [ ( "a", list [] ), ( "b", obj [] ) ]) (obj [ ( "a", list [] ), ( "b", obj [] ) ]))
        ]


matching : Test
matching =
    let
        item sku qty =
            obj [ ( "sku", Encode.string sku ), ( "qty", Encode.int qty ) ]

        bySku =
            { matchBy = Just "sku" }

        lines items =
            obj [ ( "lines", list items ) ]
    in
    describe "arrays of records matched by a key"
        [ test "records that moved are not a change" <|
            \_ ->
                Json.diff bySku (lines [ item "A" 1, item "B" 2 ]) (lines [ item "B" 2, item "A" 1 ])
                    |> Expect.equal []
        , test "a changed field is found by the key, not the position" <|
            \_ ->
                Json.diff bySku (lines [ item "A" 1, item "B" 2 ]) (lines [ item "B" 5, item "A" 1 ])
                    |> List.map (\entry -> ( entry.label, entry.kind ))
                    |> Expect.equal [ ( "lines[sku=B].qty", Changed ) ]
        , test "added and removed records" <|
            \_ ->
                Json.diff bySku (lines [ item "A" 1, item "B" 2 ]) (lines [ item "C" 3, item "A" 1 ])
                    |> List.map (\entry -> ( entry.label, entry.kind ))
                    |> Expect.equal [ ( "lines[sku=C]", Added ), ( "lines[sku=B]", Removed ) ]
        , test "a numeric key" <|
            \_ ->
                Json.diff { matchBy = Just "id" }
                    (list [ obj [ ( "id", Encode.int 7 ), ( "n", Encode.int 1 ) ] ])
                    (list [ obj [ ( "id", Encode.int 7 ), ( "n", Encode.int 2 ) ] ])
                    |> List.map .label
                    |> Expect.equal [ "[id=7].n" ]
        , test "arrays whose items have no key are compared by position" <|
            \_ ->
                Json.diff bySku (list [ Encode.int 1, Encode.int 2 ]) (list [ Encode.int 1, Encode.int 3 ])
                    |> List.map .label
                    |> Expect.equal [ "[1]" ]
        , test "arrays with two records of the same key are compared by position" <|
            \_ ->
                Json.diff bySku (lines [ item "A" 1, item "A" 2 ]) (lines [ item "A" 1, item "A" 3 ])
                    |> List.map .label
                    |> Expect.equal [ "lines[1].qty" ]
        , test "one record without the key makes the array compared by position" <|
            \_ ->
                Json.diff bySku (lines [ item "A" 1, obj [ ( "qty", Encode.int 2 ) ] ]) (lines [ item "A" 1, obj [ ( "qty", Encode.int 3 ) ] ])
                    |> List.map .label
                    |> Expect.equal [ "lines[1].qty" ]
        , test "the key applies to arrays at every depth" <|
            \_ ->
                Json.diff bySku
                    (obj [ ( "orders", list [ obj [ ( "sku", Encode.string "O1" ), ( "lines", list [ item "A" 1 ] ) ] ] ) ])
                    (obj [ ( "orders", list [ obj [ ( "sku", Encode.string "O1" ), ( "lines", list [ item "A" 2 ] ) ] ] ) ])
                    |> List.map .label
                    |> Expect.equal [ "orders[sku=O1].lines[sku=A].qty" ]
        ]


showing : Test
showing =
    describe "the text of the values"
        [ test "a changed number shows both numbers" <|
            \_ ->
                Json.diff position (obj [ ( "n", Encode.float 12.5 ) ]) (obj [ ( "n", Encode.int 14 ) ])
                    |> List.map beforeAfter
                    |> Expect.equal [ ( Just "12.5", Just "14" ) ]
        , test "a string is written as JSON" <|
            \_ ->
                Json.diff position (obj [ ( "s", Encode.string "a\"b" ) ]) (obj [ ( "s", Encode.null ) ])
                    |> List.map beforeAfter
                    |> Expect.equal [ ( Just "\"a\\\"b\"", Just "null" ) ]
        , test "a changed string marks what changed inside it" <|
            \_ ->
                Json.diff position (obj [ ( "id", Encode.string "order-1001" ) ]) (obj [ ( "id", Encode.string "order-1002" ) ])
                    |> List.map (\entry -> ( entry.before, entry.after ))
                    |> Expect.equal
                        [ ( Just (Text { parts = [ { text = "\"order-100", changed = False }, { text = "1", changed = True }, { text = "\"", changed = False } ], truncated = False })
                          , Just (Text { parts = [ { text = "\"order-100", changed = False }, { text = "2", changed = True }, { text = "\"", changed = False } ], truncated = False })
                          )
                        ]
        , test "a long value is cut and says so" <|
            \_ ->
                Json.diff position (obj []) (obj [ ( "s", list (List.repeat 500 (Encode.string "abc")) ) ])
                    |> List.filterMap .after
                    |> List.map
                        (\shown ->
                            case shown of
                                Text { parts, truncated } ->
                                    ( String.length (String.concat (List.map .text parts)) <= 400, truncated )

                                _ ->
                                    ( False, False )
                        )
                    |> Expect.equal [ ( True, True ) ]
        , test "a short value is not cut" <|
            \_ ->
                Json.diff position (obj []) (obj [ ( "s", list [ Encode.int 1, Encode.int 2 ] ) ])
                    |> List.filterMap .after
                    |> Expect.equal [ Text { parts = [ { text = "[1, 2]", changed = False } ], truncated = False } ]
        , test "the keys of an added object are written in order" <|
            \_ ->
                Json.diff position (obj []) (obj [ ( "o", obj [ ( "b", Encode.int 1 ), ( "a", Encode.int 2 ) ] ) ])
                    |> List.filterMap .after
                    |> List.map text
                    |> Expect.equal [ "{\"a\": 2, \"b\": 1}" ]
        ]


limits : Test
limits =
    describe "values that cannot be compared"
        [ test "nesting deeper than 64 levels is reported, not compared" <|
            \_ ->
                let
                    deep n =
                        if n == 0 then
                            Encode.int 1

                        else
                            list [ deep (n - 1) ]
                in
                Json.diff position (deep 100) (deep 100)
                    |> List.map (\entry -> ( entry.kind, entry.before, entry.after ))
                    |> Expect.equal [ ( Changed, Just TooDeep, Just TooDeep ) ]
        , test "nesting of 60 levels is compared" <|
            \_ ->
                let
                    deep n leaf =
                        if n == 0 then
                            leaf

                        else
                            list [ deep (n - 1) leaf ]
                in
                Json.diff position (deep 60 (Encode.int 1)) (deep 60 (Encode.int 2))
                    |> List.map .kind
                    |> Expect.equal [ Changed ]
        ]
