module ChartMasksCoreTest exposing (suite)

import Expect
import Klar.Chart.Masks as Masks
import Test exposing (Test, test)


suite : Test
suite =
    test "line masks keep screen-space strokes and apply dashes only when requested" <|
        \_ ->
            let
                dashed =
                    Masks.polylineShape 2 True "0,0 100,100"

                solid =
                    Masks.polylineShape 2 False "0,0 100,100"
            in
            Expect.equal ( True, True, False ) ( String.contains "vector-effect='non-scaling-stroke'" dashed, String.contains "stroke-dasharray=" dashed, String.contains "stroke-dasharray=" solid )
