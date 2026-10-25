module ChartNumbersCoreTest exposing (suite)

import Expect
import Klar.Chart.Numbers as Numbers
import Test exposing (Test, describe, test)


suite : Test
suite =
    describe "Pure chart finite values"
        [ test "non-finite measurements become gaps and finite extremes are bounded" <|
            \_ ->
                Expect.equal [ Nothing, Nothing, Nothing, Just 1.0e15 ] (List.map Numbers.sanitize [ 0 / 0, 1 / 0, -1 / 0, 2.0e15 ])
        , test "SVG numeric text cannot contain NaN" <|
            \_ ->
                Expect.equal "0" (Numbers.num (0 / 0))
        ]
