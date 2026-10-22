module SortableOrderTest exposing (suite)

import Expect
import Fuzz exposing (Fuzzer)
import Klar.Sortable as Sortable
import Klar.Sortable.Order as Order exposing (Rect)
import Test exposing (Test, describe, fuzz, fuzz2, fuzz3, test)


suite : Test
suite =
    describe "Sortable: the pure part (order, limits, gaps)"
        [ moveTests
        , publicMoveTests
        , boundsTests
        , fixedTests
        , gapTests
        , finalIndexTests
        , indicatorTests
        ]



-- FUZZERS


{-| Letters, so that the lists can hold the same element twice.
-}
letters : Fuzzer (List Int)
letters =
    Fuzz.list (Fuzz.intRange 0 4)


{-| A list of different numbers, so that a moved element can be followed.
-}
distinct : Fuzzer (List Int)
distinct =
    Fuzz.intRange 0 12 |> Fuzz.map (\n -> List.range 0 (n - 1))


{-| Positions, some of them outside any list.
-}
position : Fuzzer Int
position =
    Fuzz.intRange -4 16



-- MOVE


moveTests : Test
moveTests =
    describe "move"
        [ test "an element goes down" <|
            \_ -> Expect.equal [ "b", "c", "a", "d" ] (Order.move 0 2 [ "a", "b", "c", "d" ])
        , test "an element goes up" <|
            \_ -> Expect.equal [ "d", "a", "b", "c" ] (Order.move 3 0 [ "a", "b", "c", "d" ])
        , test "next to each other" <|
            \_ -> Expect.equal [ "b", "a", "c" ] (Order.move 0 1 [ "a", "b", "c" ])
        , test "a target past the end counts as the end" <|
            \_ -> Expect.equal [ "b", "c", "a" ] (Order.move 0 99 [ "a", "b", "c" ])
        , test "a target before the start counts as the start" <|
            \_ -> Expect.equal [ "c", "a", "b" ] (Order.move 2 -7 [ "a", "b", "c" ])
        , test "a source outside the list changes nothing" <|
            \_ ->
                Expect.equal [ [ "a", "b" ], [ "a", "b" ] ]
                    [ Order.move 5 0 [ "a", "b" ], Order.move -1 1 [ "a", "b" ] ]
        , test "the empty list and the list of one" <|
            \_ ->
                Expect.equal ( [], [ 1 ] ) ( Order.move 0 3 [], Order.move 0 3 [ 1 ] )
        , fuzz3 letters position position "keeps the length and every element, also when elements repeat" <|
            \list from to ->
                Order.move from to list
                    |> List.sort
                    |> Expect.equal (List.sort list)
        , fuzz2 distinct position "moving an element to where it is changes nothing" <|
            \list index ->
                Order.move index index list |> Expect.equal list
        , fuzz3 distinct position position "the moved element ends up at the (clamped) target and the others keep their order" <|
            \list from to ->
                let
                    moved =
                        Order.move from to list

                    target =
                        clamp 0 (List.length list - 1) to
                in
                if from < 0 || from >= List.length list then
                    Expect.equal list moved

                else
                    -- the list is 0, 1, 2 ...: the element is its own number
                    Expect.equal
                        ( Just from, List.filter (\other -> other /= from) list )
                        ( List.head (List.drop target moved), List.filter (\other -> other /= from) moved )
        , fuzz3 distinct position position "moving back undoes a move" <|
            \list from to ->
                let
                    length =
                        List.length list
                in
                if from >= 0 && from < length && to >= 0 && to < length then
                    Order.move from to list
                        |> Order.move to from
                        |> Expect.equal list

                else
                    Expect.pass
        , fuzz3 letters position position "dropping again at the same target is a no-op" <|
            \list from to ->
                let
                    once =
                        Order.move from to list

                    target =
                        clamp 0 (List.length list - 1) to
                in
                if from >= 0 && from < List.length list then
                    Order.move target target once |> Expect.equal once

                else
                    Expect.equal list once
        ]


publicMoveTests : Test
publicMoveTests =
    describe "Sortable.move"
        [ test "is the same move, with named places" <|
            \_ ->
                Sortable.move { from = 0, to = 2 } [ "a", "b", "c", "d" ]
                    |> Expect.equal [ "b", "c", "a", "d" ]
        , fuzz3 letters position position "never loses an element" <|
            \list from to ->
                Sortable.move { from = from, to = to } list
                    |> List.sort
                    |> Expect.equal (List.sort list)
        ]



-- LIMITS SET BY FIXED ELEMENTS


flags : Fuzzer (List Bool)
flags =
    Fuzz.list Fuzz.bool


boundsTests : Test
boundsTests =
    describe "bounds"
        [ test "no fixed element: the whole list" <|
            \_ -> Expect.equal ( 0, 3 ) (Order.bounds [ False, False, False, False ] 1)
        , test "a fixed element in the middle splits the list" <|
            \_ ->
                Expect.equal [ ( 0, 1 ), ( 0, 1 ), ( 2, 2 ), ( 3, 4 ), ( 3, 4 ) ]
                    (List.map (Order.bounds [ False, False, True, False, False ]) (List.range 0 4))
        , test "a fixed element at the start keeps the rest below it" <|
            \_ -> Expect.equal [ ( 0, 0 ), ( 1, 3 ), ( 1, 3 ), ( 1, 3 ) ] (List.map (Order.bounds [ True, False, False, False ]) (List.range 0 3))
        , test "a fixed element at the end" <|
            \_ -> Expect.equal [ ( 0, 1 ), ( 0, 1 ), ( 2, 2 ) ] (List.map (Order.bounds [ False, False, True ]) (List.range 0 2))
        , test "an index outside the list can only stay" <|
            \_ -> Expect.equal [ ( -1, -1 ), ( 3, 3 ) ] [ Order.bounds [ False, False, False ] -1, Order.bounds [ False, False, False ] 3 ]
        , fuzz2 flags position "a loose element is inside its own bounds, which hold no fixed element" <|
            \list index ->
                let
                    ( low, high ) =
                        Order.bounds list index

                    isFixedAt i =
                        list |> List.drop i |> List.head |> Maybe.withDefault False

                    loose =
                        index >= 0 && index < List.length list && not (isFixedAt index)
                in
                if loose then
                    Expect.all
                        [ \_ -> Expect.atMost index low
                        , \_ -> Expect.atLeast index high
                        , \_ -> Expect.equal [] (List.filter isFixedAt (List.range low high))
                        , \_ -> Expect.equal True (low == 0 || isFixedAt (low - 1))
                        , \_ -> Expect.equal True (high == List.length list - 1 || isFixedAt (high + 1))
                        ]
                        ()

                else
                    Expect.equal ( index, index ) ( low, high )
        ]


fixedTests : Test
fixedTests =
    describe "moving with fixed elements"
        [ fuzz3 flags position position "a fixed element is never moved and never passed" <|
            \list from to ->
                let
                    elements =
                        List.range 0 (List.length list - 1)

                    moved =
                        Order.move from (Order.clampTarget list from to) elements

                    stillThere ( index, isFixed ) =
                        not isFixed || (List.drop index moved |> List.head) == Just index
                in
                List.indexedMap Tuple.pair list
                    |> List.filter (not << stillThere)
                    |> Expect.equal []
        , fuzz3 flags position position "a clamped target is always a place inside the bounds" <|
            \list from to ->
                let
                    ( low, high ) =
                        Order.bounds list from

                    target =
                        Order.clampTarget list from to
                in
                Expect.all [ \_ -> Expect.atLeast low target, \_ -> Expect.atMost high target ] ()
        , test "the barrier in an example" <|
            \_ ->
                Order.move 0 (Order.clampTarget [ False, False, True, False ] 0 3) [ "a", "b", "fixed", "c" ]
                    |> Expect.equal [ "b", "a", "fixed", "c" ]
        ]



-- THE GAP UNDER THE POINTER


{-| Boxes stacked without a gap: item k is the band from 10 k to 10 k + 10.
-}
stack : Int -> List Rect
stack n =
    List.range 0 (n - 1) |> List.map (\k -> { x = 0, y = toFloat k * 10, width = 100, height = 10 })


row : Int -> List Rect
row n =
    List.range 0 (n - 1) |> List.map (\k -> { x = toFloat k * 10, y = 0, width = 10, height = 20 })


gapTests : Test
gapTests =
    describe "gapAt"
        [ test "the upper half of an item is the gap before it, the lower half the gap after it" <|
            \_ ->
                Expect.equal [ 0, 1, 1, 2 ]
                    [ Order.gapAt False (stack 3) 50 2, Order.gapAt False (stack 3) 50 8, Order.gapAt False (stack 3) 50 12, Order.gapAt False (stack 3) 50 19 ]
        , test "above the first and below the last item" <|
            \_ ->
                Expect.equal [ 0, 3 ]
                    [ Order.gapAt False (stack 3) 50 -500, Order.gapAt False (stack 3) 50 500 ]
        , test "sideways in a vertical list does not matter" <|
            \_ ->
                Expect.equal (Order.gapAt False (stack 3) 50 14) (Order.gapAt False (stack 3) 5000 14)
        , test "a row of chips uses the left and the right half" <|
            \_ ->
                Expect.equal [ 0, 1, 1, 4 ]
                    [ Order.gapAt True (row 4) 2 10, Order.gapAt True (row 4) 8 10, Order.gapAt True (row 4) 12 10, Order.gapAt True (row 4) 900 10 ]
        , test "chips that wrap onto a second line" <|
            \_ ->
                let
                    -- two lines of three chips
                    wrapped =
                        List.range 0 5
                            |> List.map
                                (\k ->
                                    { x = toFloat (modBy 3 k) * 10
                                    , y = toFloat (k // 3) * 30
                                    , width = 10
                                    , height = 20
                                    }
                                )
                in
                Expect.equal [ 3, 6, 0 ]
                    [ Order.gapAt True wrapped 2 40, Order.gapAt True wrapped 100 40, Order.gapAt True wrapped 1 -40 ]
        , test "no boxes, gap 0" <|
            \_ -> Expect.equal 0 (Order.gapAt False [] 10 10)
        , fuzz2 (Fuzz.intRange 1 30) (Fuzz.intRange -50 400) "in a stack the gap is where the pointer is, rounded to the nearest edge" <|
            \n y ->
                Order.gapAt False (stack n) 40 (toFloat y)
                    |> Expect.equal (clamp 0 n (floor (toFloat y / 10 + 0.5)))
        , fuzz2 (Fuzz.intRange 0 30) (Fuzz.floatRange -1000 1000) "always a gap from 0 to the number of boxes" <|
            \n x ->
                Order.gapAt True (stack n) x x
                    |> Expect.all [ Expect.atLeast 0, Expect.atMost n ]
        ]


finalIndexTests : Test
finalIndexTests =
    describe "finalIndex"
        [ test "the gaps next to the element mean where it was" <|
            \_ -> Expect.equal [ 2, 2 ] [ Order.finalIndex 2 2, Order.finalIndex 2 3 ]
        , test "a gap above and a gap below" <|
            \_ -> Expect.equal [ 0, 4 ] [ Order.finalIndex 2 0, Order.finalIndex 2 5 ]
        , fuzz2 (Fuzz.intRange 0 20) (Fuzz.intRange 0 21) "moving there puts the element in front of the one that was behind the gap" <|
            \from gap ->
                let
                    elements =
                        List.range 0 20

                    result =
                        Order.move from (Order.finalIndex from gap) elements

                    placeOf element =
                        Order.indexOf element result
                in
                if gap == from || gap == from + 1 then
                    Expect.equal elements result

                else if gap == 21 then
                    Expect.equal (Just 20) (placeOf from)

                else
                    Expect.equal (placeOf gap) (Maybe.map ((+) 1) (placeOf from))
        ]


indicatorTests : Test
indicatorTests =
    describe "indicator"
        [ test "moving up draws the line before the element now at the target" <|
            \_ -> Expect.equal (Just { index = 1, after = False }) (Order.indicator 3 1)
        , test "moving down draws it after" <|
            \_ -> Expect.equal (Just { index = 4, after = True }) (Order.indicator 1 4)
        , test "no move, no line" <|
            \_ -> Expect.equal Nothing (Order.indicator 2 2)
        ]
