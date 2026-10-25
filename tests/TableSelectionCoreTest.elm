module TableSelectionCoreTest exposing (suite)

import Expect
import Klar.Table.Selection as Selection
import Klar.Table.Types exposing (Picked(..))
import Set
import Test exposing (Test, test)


suite : Test
suite =
    test "selecting an all-matching exception again preserves the other exclusions" <|
        \_ ->
            let
                picked =
                    AllPicked (Set.singleton "a") |> Selection.pick [ "b" ] False |> Selection.pick [ "b" ] True
            in
            Expect.equal [ False, True, True ] (List.map (Selection.isPicked picked) [ "a", "b", "c" ])
