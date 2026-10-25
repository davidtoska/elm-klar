module ChartColorsCoreTest exposing (suite)

import Expect
import Klar.Chart.Colors as Colors
import Klar.Theme exposing (Tone(..))
import Test exposing (Test, test)


suite : Test
suite =
    test "series meaning outranks its slot, and a chart tone applies only to its first series" <|
        \_ ->
            Expect.equal [ Colors.toneClass Danger, "klar-chart-s3", "klar-chart-s1" ]
                [ Colors.colorClass (Just Success) 0 (Just 4) (Just Danger)
                , Colors.colorClass (Just Success) 0 (Just 4) Nothing
                , Colors.colorClass (Just Success) 1 Nothing Nothing
                ]
