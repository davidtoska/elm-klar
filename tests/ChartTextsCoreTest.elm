module ChartTextsCoreTest exposing (suite)

import Expect
import Klar.Chart.Config as Config
import Klar.Chart.Texts as Texts
import Test exposing (Test, test)


suite : Test
suite =
    test "an explicit accessible name takes priority over the visual chart title" <|
        \_ ->
            let
                config =
                    Config.configure [ Config.title "Visual title", Config.ariaLabel "Spoken name" ]

                summary =
                    Texts.summaryLine config "Line" 2 3
            in
            Expect.equal True (String.contains "Spoken name" summary && not (String.contains "Visual title" summary))
