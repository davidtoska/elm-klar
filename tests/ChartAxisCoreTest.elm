module ChartAxisCoreTest exposing (suite)

import Expect
import Klar.Chart.Axis as Axis
import Test exposing (Test, test)


suite : Test
suite =
    test "reversed fixed limits fall back to an axis containing the data" <|
        \_ ->
            let
                axis =
                    Axis.axisFor 5 True (Just 10) (Just -10) [ -7, 3 ]
            in
            Expect.equal True (axis.lo <= -7 && axis.hi >= 3 && axis.hi > axis.lo && axis.ticks == List.sort axis.ticks)
