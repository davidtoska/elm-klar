module ChartConfigCoreTest exposing (suite)

import Expect
import Klar.Chart.Config as Config
import Klar.Theme exposing (Tone(..))
import Test exposing (Test, test)


suite : Test
suite =
    test "unsorted threshold input chooses the first containing zone and extends the last zone" <|
        \_ ->
            let
                config =
                    Config.configure [ Config.thresholds [ ( 100, Danger ), ( 70, Success ), ( 90, Warning ) ] ]
            in
            Expect.equal [ Just Warning, Just Danger ] (List.map (Config.zoneToneFor config) [ 75, 150 ])
