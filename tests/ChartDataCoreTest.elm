module ChartDataCoreTest exposing (suite)

import Expect
import Klar.Chart.Data as Data
import Klar.Chart.Types exposing (Series(..))
import Test exposing (Test, test)


suite : Test
suite =
    test "series customization preserves explicit and non-finite gaps" <|
        \_ ->
            let
                (Series series) =
                    Data.seriesMaybe "Trend" [ Just 1, Nothing, Just (1 / 0) ] |> Data.withSlot 3 |> Data.dashed
            in
            Expect.equal ( [ Just 1, Nothing, Nothing ], ( Just 3, True ) ) ( series.values, ( series.color, series.dashed ) )
