module TableProcessingCoreTest exposing (suite)

import Expect
import Klar.Remote as Remote
import Klar.Table.Columns as Columns
import Klar.Table.Config as Config
import Klar.Table.Processing as Processing
import Klar.Table.State as State
import Klar.Table.Types exposing (Column(..), ColumnId(..), Direction(..), State(..))
import Test exposing (Test, test)


suite : Test
suite =
    test "server processing preserves the supplied page order and total" <|
        \_ ->
            let
                (Column column) =
                    Columns.int (ColumnId "number") "Number" identity []

                config =
                    Config.configure [ Config.columns [ Column column ], Config.remote (Remote.Loaded [ 9, 2 ]), Config.server { total = 100 } ]

                (State model) =
                    State.init "orders" |> State.setSort [ ( ColumnId "number", Ascending ) ] |> State.setSearch "no local match"

                data =
                    Processing.process config model [ column ] [ column ]
            in
            Expect.equal ( [ 9, 2 ], 100 ) ( data.pageRows, data.total )
