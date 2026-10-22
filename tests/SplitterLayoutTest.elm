module SplitterLayoutTest exposing (suite)

import Expect exposing (Expectation)
import Fuzz exposing (Fuzzer)
import Klar.Splitter.Layout as Layout exposing (Limits)
import Test exposing (Test, describe, fuzz, fuzz2, fuzz3, test)


suite : Test
suite =
    describe "Splitter: the maths of the sizes"
        [ normaliseTests
        , fitTests
        , resolveTests
        , settleTests
        , dragTests
        , edgeTests
        , collapseTests
        ]



-- FUZZERS


tolerance : Float
tolerance =
    1.0e-9


{-| Sizes that may be anything a program could hand over: negative, not a number,
infinite.
-}
anySize : Fuzzer Float
anySize =
    Fuzz.oneOf
        [ Fuzz.floatRange 0 1
        , Fuzz.floatRange -5 5
        , Fuzz.constant (0 / 0)
        , Fuzz.constant (1 / 0)
        , Fuzz.constant (-1 / 0)
        , Fuzz.constant 0
        ]


anySizes : Fuzzer (List Float)
anySizes =
    Fuzz.list anySize


{-| Sizes that add up to 1.
-}
validSizes : Fuzzer (List Float)
validSizes =
    Fuzz.listOfLengthBetween 1 6 (Fuzz.floatRange 0.01 1) |> Fuzz.map Layout.normalise


{-| Limits for as many panes as sizes: some wide open, some narrow.
-}
limitsFor : Int -> Fuzzer (List Limits)
limitsFor count =
    Fuzz.list (Fuzz.pair (Fuzz.floatRange 0 0.5) (Fuzz.floatRange 0 1))
        |> Fuzz.map
            (\pairs ->
                List.take count
                    (List.map (\( low, high ) -> { min = low, max = Basics.max low high }) pairs
                        ++ List.repeat count { min = 0, max = 1 }
                    )
            )


total : List Float -> Float
total =
    List.sum


sumsToOne : List Float -> Expectation
sumsToOne sizes =
    Expect.within (Expect.Absolute tolerance) 1 (total sizes)


show : List Float -> String
show sizes =
    "[" ++ String.join ", " (List.map String.fromFloat sizes) ++ "]"


{-| The same sizes, to within the rounding of the machine.
-}
sameSizes : List Float -> List Float -> Expectation
sameSizes expected actual =
    if List.length expected == List.length actual && List.all identity (List.map2 (\a b -> abs (a - b) <= tolerance) expected actual) then
        Expect.pass

    else
        Expect.fail (show expected ++ " is not " ++ show actual)


areNumbers : List Float -> Expectation
areNumbers sizes =
    if List.any (\size -> isNaN size || isInfinite size || size < -tolerance) sizes then
        Expect.fail ("not all sizes are sizes: " ++ show sizes)

    else
        Expect.pass



-- NORMALISE


normaliseTests : Test
normaliseTests =
    describe "normalise"
        [ test "keeps the proportions" <|
            \_ -> Expect.equal [ 0.25, 0.75 ] (Layout.normalise [ 1, 3 ])
        , test "thirty and thirty become fifty and fifty" <|
            \_ -> Expect.equal [ 0.5, 0.5 ] (Layout.normalise [ 30, 30 ])
        , test "nothing but zeros: an equal share" <|
            \_ -> Expect.equal [ 0.5, 0.5 ] (Layout.normalise [ 0, 0 ])
        , test "a size that is not a size counts as nothing" <|
            \_ -> Expect.equal [ 0, 1, 0, 0 ] (Layout.normalise [ -3, 2, 0 / 0, 1 / 0 ] |> List.map (\x -> toFloat (round x)))
        , test "no panes, no sizes" <|
            \_ -> Expect.equal [] (Layout.normalise [])
        , fuzz anySizes "always as many sizes that are sizes, adding up to 1 (or none at all)" <|
            \sizes ->
                let
                    result =
                        Layout.normalise sizes
                in
                Expect.all
                    [ \_ -> Expect.equal (List.length sizes) (List.length result)
                    , \_ ->
                        if List.isEmpty sizes then
                            Expect.pass

                        else
                            sumsToOne result
                    , \_ -> areNumbers result
                    ]
                    ()
        ]



-- FIT


fitTests : Test
fitTests =
    describe "fit"
        [ test "the same number of panes: the same proportions" <|
            \_ -> Expect.equal [ 0.4, 0.6 ] (Layout.fit 2 [ 0.4, 0.6 ])
        , test "a new pane gets an equal share and the others keep their proportions" <|
            \_ ->
                Layout.fit 3 [ 0.25, 0.75 ]
                    |> List.map (\x -> toFloat (round (x * 1000)) / 1000)
                    |> Expect.equal [ 0.167, 0.5, 0.333 ]
        , test "a pane that is gone: the others are scaled up" <|
            \_ -> sameSizes [ 0.25, 0.75 ] (Layout.fit 2 [ 0.1, 0.3, 0.6 ])
        , test "no sizes: an equal share" <|
            \_ -> Expect.equal [ 0.5, 0.5 ] (Layout.fit 2 [])
        , test "no panes" <|
            \_ -> Expect.equal [] (Layout.fit 0 [ 0.5, 0.5 ])
        , fuzz2 (Fuzz.intRange -1 8) anySizes "always as many sizes as panes, adding up to 1" <|
            \count sizes ->
                let
                    result =
                        Layout.fit count sizes
                in
                Expect.all
                    [ \_ -> Expect.equal (Basics.max 0 count) (List.length result)
                    , \_ ->
                        if count <= 0 then
                            Expect.pass

                        else
                            sumsToOne result
                    , \_ -> areNumbers result
                    ]
                    ()
        ]



-- RESOLVE


resolveTests : Test
resolveTests =
    let
        request =
            { minShare = 0, maxShare = 1, minPixels = 0, maxPixels = Nothing }
    in
    describe "resolve"
        [ test "shares are used as they are" <|
            \_ ->
                Expect.equal { min = 0.2, max = 0.6 }
                    (Layout.resolve Nothing { request | minShare = 0.2, maxShare = 0.6 })
        , test "pixels become fractions of the room" <|
            \_ ->
                Expect.equal { min = 0.25, max = 0.5 }
                    (Layout.resolve (Just 800) { request | minPixels = 200, maxPixels = Just 400 })
        , test "the stricter of a share and pixels wins" <|
            \_ ->
                Expect.equal { min = 0.3, max = 0.4 }
                    (Layout.resolve (Just 1000) { minShare = 0.1, maxShare = 0.4, minPixels = 300, maxPixels = Just 600 })
        , test "pixels are left out when the room is not known, nothing, or not a number" <|
            \_ ->
                Expect.equal (List.repeat 4 { min = 0, max = 1 })
                    (List.map (\room -> Layout.resolve room { request | minPixels = 200, maxPixels = Just 400 }) [ Nothing, Just 0, Just -50, Just (0 / 0) ])
        , test "a smallest that is above the largest wins" <|
            \_ ->
                Expect.equal { min = 0.7, max = 0.7 }
                    (Layout.resolve Nothing { request | minShare = 0.7, maxShare = 0.3 })
        , fuzz3 (Fuzz.floatRange -2 3) (Fuzz.floatRange -2 3) (Fuzz.floatRange -100 2000) "limits are always inside 0 to 1 with the smallest not above the largest" <|
            \low high room ->
                let
                    limits =
                        Layout.resolve (Just room) { minShare = low, maxShare = high, minPixels = abs room, maxPixels = Just (abs high * 100) }
                in
                Expect.all
                    [ \_ -> Expect.atLeast 0 limits.min
                    , \_ -> Expect.atMost 1 limits.max
                    , \_ -> Expect.atMost limits.max limits.min
                    ]
                    ()
        ]



-- SETTLE


settleTests : Test
settleTests =
    describe "settle"
        [ test "sizes that fit are not touched" <|
            \_ ->
                Expect.equal [ 0.3, 0.7 ] (Layout.settle [ { min = 0.1, max = 0.9 }, { min = 0.1, max = 0.9 } ] [ 0.3, 0.7 ])
        , test "a size below its smallest is raised and the others give way" <|
            \_ ->
                Layout.settle [ { min = 0.1, max = 1 }, { min = 0, max = 1 } ] [ 0.05, 0.95 ]
                    |> List.map (\x -> toFloat (round (x * 1000)) / 1000)
                    |> Expect.equal [ 0.1, 0.9 ]
        , test "a size above its largest is cut and the others take over" <|
            \_ ->
                Layout.settle [ { min = 0, max = 0.3 }, { min = 0, max = 1 }, { min = 0, max = 1 } ] [ 0.6, 0.2, 0.2 ]
                    |> List.map (\x -> toFloat (round (x * 1000)) / 1000)
                    |> Expect.equal [ 0.3, 0.35, 0.35 ]
        , test "smallest sizes that do not fit together: each gets its share of them" <|
            \_ ->
                Layout.settle [ { min = 0.6, max = 1 }, { min = 0.6, max = 1 } ] [ 0.5, 0.5 ]
                    |> Expect.equal [ 0.5, 0.5 ]
        , test "largest sizes that are too small together: each gets its share of them" <|
            \_ ->
                Layout.settle [ { min = 0, max = 0.2 }, { min = 0, max = 0.2 } ] [ 0.5, 0.5 ]
                    |> Expect.equal [ 0.5, 0.5 ]
        , test "a pane that is folded stays at nothing" <|
            \_ ->
                Layout.settle [ { min = 0, max = 0 }, { min = 0, max = 1 } ] [ 0, 1 ]
                    |> Expect.equal [ 0, 1 ]
        , test "a pane with no limit given is not limited" <|
            \_ ->
                Layout.settle [] [ 0.3, 0.7 ] |> Expect.equal [ 0.3, 0.7 ]
        , fuzz anySizes "whatever goes in, sizes come out that add up to 1" <|
            \sizes ->
                let
                    result =
                        Layout.settle [ { min = 0.2, max = 0.4 } ] sizes
                in
                Expect.all
                    [ \_ -> Expect.equal (List.length sizes) (List.length result)
                    , \_ ->
                        if List.isEmpty sizes then
                            Expect.pass

                        else
                            sumsToOne result
                    , \_ -> areNumbers result
                    ]
                    ()
        , fuzz validSizes "if the limits can be met, every size is inside its limits and they add up to 1" <|
            \sizes ->
                let
                    count =
                        List.length sizes

                    -- limits that a layout of equal shares meets: they can be met
                    limits =
                        List.repeat count { min = 0.5 / toFloat count, max = Basics.min 1 (1.5 / toFloat count) }

                    result =
                        Layout.settle limits sizes
                in
                Expect.all
                    [ \_ -> sumsToOne result
                    , \_ ->
                        if List.all identity (List.map2 (\bound size -> size >= bound.min - tolerance && size <= bound.max + tolerance) limits result) then
                            Expect.pass

                        else
                            Expect.fail ("outside the limits: " ++ show result)
                    ]
                    ()
        , fuzz2 validSizes (limitsFor 6) "with any limits that can be met together, they are met" <|
            \sizes allLimits ->
                let
                    limits =
                        List.take (List.length sizes) allLimits

                    feasible =
                        List.sum (List.map .min limits) <= 1 && List.sum (List.map .max limits) >= 1

                    result =
                        Layout.settle limits sizes
                in
                if feasible then
                    Expect.all
                        [ \_ -> sumsToOne result
                        , \_ ->
                            if List.all identity (List.map2 (\bound size -> size >= bound.min - tolerance && size <= bound.max + tolerance) limits result) then
                                Expect.pass

                            else
                                Expect.fail ("outside the limits: " ++ show result)
                        ]
                        ()

                else
                    sumsToOne result
        , fuzz validSizes "settling twice is settling once" <|
            \sizes ->
                let
                    limits =
                        List.repeat (List.length sizes) { min = 0.1, max = 0.6 }

                    once =
                        Layout.settle limits sizes
                in
                sameSizes once (Layout.settle limits once)
        ]



-- DRAG


{-| Two or three panes with sizes inside the limits that the layout meets.
-}
paneSetup : Fuzzer ( List Float, List Limits )
paneSetup =
    validSizes
        |> Fuzz.map
            (\sizes ->
                ( sizes
                , List.map (\size -> { min = size / 2, max = Basics.min 1 (size * 1.5 + 0.1) }) sizes
                )
            )


dragTests : Test
dragTests =
    describe "drag"
        [ test "moving a separator grows one neighbour and shrinks the other" <|
            \_ ->
                Layout.drag 0 0.1 [ open, open ] [ 0.5, 0.5 ]
                    |> List.map (\x -> toFloat (round (x * 1000)) / 1000)
                    |> Expect.equal [ 0.6, 0.4 ]
        , test "only the two panes beside the separator change" <|
            \_ ->
                Layout.drag 1 -0.1 [ open, open, open ] [ 0.3, 0.4, 0.3 ]
                    |> List.map (\x -> toFloat (round (x * 1000)) / 1000)
                    |> Expect.equal [ 0.3, 0.3, 0.4 ]
        , test "a pane stops at its smallest size and the next pane is left alone" <|
            \_ ->
                Layout.drag 1 -0.5 [ open, { min = 0.2, max = 1 }, open ] [ 0.3, 0.4, 0.3 ]
                    |> List.map (\x -> toFloat (round (x * 1000)) / 1000)
                    |> Expect.equal [ 0.3, 0.2, 0.5 ]
        , test "the pane on the other side stops it at its smallest size" <|
            \_ ->
                Layout.drag 0 0.5 [ open, { min = 0.1, max = 1 } ] [ 0.5, 0.5 ]
                    |> List.map (\x -> toFloat (round (x * 1000)) / 1000)
                    |> Expect.equal [ 0.9, 0.1 ]
        , test "a pane that is held at its size keeps its neighbour where it is" <|
            \_ ->
                Layout.drag 0 0.5 [ open, { min = 0.5, max = 0.5 } ] [ 0.5, 0.5 ]
                    |> Expect.equal [ 0.5, 0.5 ]
        , test "a separator that is not there changes nothing" <|
            \_ ->
                Expect.equal [ [ 0.5, 0.5 ], [ 0.5, 0.5 ], [ 0.5, 0.5 ] ]
                    [ Layout.drag 1 0.1 [ open, open ] [ 0.5, 0.5 ]
                    , Layout.drag -1 0.1 [ open, open ] [ 0.5, 0.5 ]
                    , Layout.drag 7 0.1 [ open, open ] [ 0.5, 0.5 ]
                    ]
        , test "a distance that is not a number moves nothing" <|
            \_ ->
                Expect.equal [ 0.5, 0.5 ] (Layout.drag 0 (0 / 0) [ open, open ] [ 0.5, 0.5 ])
        , test "an enormous distance is cut to what is possible" <|
            \_ ->
                Layout.drag 0 (1 / 0) [ open, { min = 0.1, max = 1 } ] [ 0.5, 0.5 ]
                    |> List.map (\x -> toFloat (round (x * 1000)) / 1000)
                    |> Expect.equal [ 0.9, 0.1 ]
        , fuzz2 paneSetup (Fuzz.floatRange -2 2) "the sizes still add up to 1, stay inside their limits, and only the neighbours change" <|
            \( sizes, limits ) delta ->
                let
                    index =
                        0

                    result =
                        Layout.drag index delta limits sizes
                in
                Expect.all
                    [ \_ -> sumsToOne result
                    , \_ -> areNumbers result
                    , \_ -> Expect.equal (List.drop 2 sizes) (List.drop 2 result)
                    , \_ ->
                        if List.length sizes < 2 then
                            Expect.equal sizes result

                        else
                            List.map2 (\bound size -> size >= bound.min - tolerance && size <= bound.max + tolerance) limits result
                                |> List.all identity
                                |> Expect.equal True
                    ]
                    ()
        , fuzz2 paneSetup (Fuzz.floatRange -2 2) "what one neighbour gains the other loses, and no more than was asked" <|
            \( sizes, limits ) delta ->
                let
                    result =
                        Layout.drag 0 delta limits sizes

                    change at =
                        (List.drop at result |> List.head |> Maybe.withDefault 0) - (List.drop at sizes |> List.head |> Maybe.withDefault 0)
                in
                if List.length sizes < 2 then
                    Expect.pass

                else
                    Expect.all
                        [ \_ -> Expect.within (Expect.Absolute tolerance) 0 (change 0 + change 1)
                        , \_ -> Expect.atMost (abs delta + tolerance) (abs (change 0))
                        , \_ ->
                            if change 0 > tolerance then
                                Expect.atLeast 0 delta

                            else if change 0 < -tolerance then
                                Expect.atMost 0 delta

                            else
                                Expect.pass
                        ]
                        ()
        , fuzz2 paneSetup (Fuzz.floatRange -0.05 0.05) "a move that is not cut can be moved back" <|
            \( sizes, limits ) delta ->
                let
                    moved =
                        Layout.drag 0 delta limits sizes

                    applied =
                        (List.head moved |> Maybe.withDefault 0) - (List.head sizes |> Maybe.withDefault 0)
                in
                sameSizes sizes (Layout.drag 0 -applied limits moved)
        , fuzz2 paneSetup (Fuzz.floatRange -2 2) "the range of a pane holds where a drag can take it" <|
            \( sizes, limits ) delta ->
                let
                    ( low, high ) =
                        Layout.range 0 limits sizes

                    after =
                        Layout.drag 0 delta limits sizes |> List.head |> Maybe.withDefault 0
                in
                Expect.all [ \_ -> Expect.atLeast (low - tolerance) after, \_ -> Expect.atMost (high + tolerance) after ] ()
        ]


open : Limits
open =
    { min = 0, max = 1 }



-- EDGE


edgeTests : Test
edgeTests =
    describe "edge"
        [ test "to the smallest and to the largest" <|
            \_ ->
                let
                    limits =
                        [ { min = 0.2, max = 0.7 }, { min = 0.1, max = 0.6 } ]
                in
                Expect.equal
                    [ [ 0.4, 0.6 ], [ 0.7, 0.3 ] ]
                    [ Layout.edge 0 False limits [ 0.5, 0.5 ] |> List.map (\x -> toFloat (round (x * 1000)) / 1000)
                    , Layout.edge 0 True limits [ 0.5, 0.5 ] |> List.map (\x -> toFloat (round (x * 1000)) / 1000)
                    ]
        , fuzz paneSetup "the edges are the ends of the range" <|
            \( sizes, limits ) ->
                let
                    ( low, high ) =
                        Layout.range 0 limits sizes

                    first result =
                        List.head result |> Maybe.withDefault 0
                in
                if List.length sizes < 2 then
                    Expect.pass

                else
                    Expect.all
                        [ \_ -> Expect.within (Expect.Absolute tolerance) low (first (Layout.edge 0 False limits sizes))
                        , \_ -> Expect.within (Expect.Absolute tolerance) high (first (Layout.edge 0 True limits sizes))
                        ]
                        ()
        ]



-- COLLAPSE


collapseTests : Test
collapseTests =
    describe "collapse and expand"
        [ test "a pane folds away and its room goes to the other" <|
            \_ ->
                Expect.equal ( [ 0, 1 ], 0.25 ) (Layout.collapse 0 1 [ 0.25, 0.75 ])
        , test "and comes back with what it had" <|
            \_ ->
                Layout.expand 0 1 0.25 [ open, open ] [ 0, 1 ]
                    |> Expect.equal [ 0.25, 0.75 ]
        , test "it does not take more than the other can spare" <|
            \_ ->
                Layout.expand 0 1 0.5 [ open, { min = 0.8, max = 1 } ] [ 0, 1 ]
                    |> List.map (\x -> toFloat (round (x * 1000)) / 1000)
                    |> Expect.equal [ 0.2, 0.8 ]
        , test "and not less than its own smallest size" <|
            \_ ->
                Layout.expand 0 1 0.05 [ { min = 0.2, max = 1 }, open ] [ 0, 1 ]
                    |> Expect.equal [ 0.2, 0.8 ]
        , test "when the other has nothing to spare, nothing happens" <|
            \_ ->
                Layout.expand 0 1 0.3 [ open, { min = 1, max = 1 } ] [ 0, 1 ]
                    |> Expect.equal [ 0, 1 ]
        , test "panes that are not there change nothing" <|
            \_ ->
                Expect.equal ( [ 0.5, 0.5 ], 0 )
                    (Layout.collapse 3 0 [ 0.5, 0.5 ])
        , fuzz3 validSizes (Fuzz.intRange 0 5) (Fuzz.intRange 0 5) "folding keeps the room and puts all of it on the other pane" <|
            \sizes index into ->
                let
                    ( result, remembered ) =
                        Layout.collapse index into sizes

                    count =
                        List.length sizes
                in
                if index < count && into < count && index /= into then
                    Expect.all
                        [ \_ -> sumsToOne result
                        , \_ -> Expect.equal 0 (List.drop index result |> List.head |> Maybe.withDefault 1)
                        , \_ -> Expect.within (Expect.Absolute tolerance) remembered (List.drop index sizes |> List.head |> Maybe.withDefault 0)
                        , \_ -> areNumbers result
                        ]
                        ()

                else
                    Expect.equal ( sizes, 0 ) ( result, remembered )
        ]
