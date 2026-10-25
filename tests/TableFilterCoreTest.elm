module TableFilterCoreTest exposing (suite)

import Expect
import Klar.Table.Filter as Filter
import Klar.Table.Types exposing (Draft(..), Filter(..))
import Test exposing (Test, describe, test)


suite : Test
suite =
    describe "Pure table filter input"
        [ test "a reversed typed range retains both bounds in ascending order" <|
            \_ ->
                Expect.equal (Just (Between (Just 20) (Just 80))) (Filter.toFilter (RangeDraft "80" "20"))
        , test "localized input accepts Unicode minus but refuses a non-finite number" <|
            \_ ->
                Expect.equal [ Just -1234.5, Nothing ] (List.map Filter.parseNumber [ "−1 234,5", "1e999" ])
        ]
