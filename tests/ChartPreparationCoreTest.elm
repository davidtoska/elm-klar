module ChartPreparationCoreTest exposing (suite)

import Array
import Expect
import Klar.Chart.Config as Config
import Klar.Chart.Data as Data
import Klar.Chart.Preparation as Preparation
import Test exposing (Test, describe, test)


suite : Test
suite =
    describe "Pure chart preparation"
        [ test "a longer series extends category names with one-based fallback labels" <|
            \_ ->
                let
                    prepared =
                        Preparation.prepare (Config.configure [ Config.categories [ "Only" ] ]) [ Data.seriesMaybe "Trend" [ Just 2, Nothing, Just 5 ] ]
                in
                Expect.equal ( 3, [ "Only", "2", "3" ] ) ( prepared.n, Array.toList prepared.cats )
        , test "a gap ends a line run without introducing empty runs" <|
            \_ ->
                Expect.equal [ [ ( 0, 1 ) ], [ ( 2, 3 ), ( 3, 4 ) ] ] (Preparation.runs 5 (Array.fromList [ Just 1, Nothing, Just 3, Just 4, Nothing ]))
        ]
