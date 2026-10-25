module TableColumnLogicTest exposing (suite)

import Dict
import Expect
import Klar.Table.ColumnLogic as Logic
import Klar.Table.Columns as Columns
import Klar.Table.State as State
import Klar.Table.Types exposing (State(..))
import Test exposing (Test, test)


suite : Test
suite =
    test "hiding every column still leaves the first column visible" <|
        \_ ->
            let
                (State model) =
                    State.init "orders"

                columns =
                    [ Columns.baseColumn "a" "A" (\_ row -> row), Columns.baseColumn "b" "B" (\_ row -> row) ]

                hidden =
                    { model | visibility = Dict.fromList [ ( "a", False ), ( "b", False ) ] }
            in
            Logic.visibleColumns hidden columns |> List.map .id |> Expect.equal [ "a" ]
