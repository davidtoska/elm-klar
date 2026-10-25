module TableWindowCoreTest exposing (suite)

import Expect
import Klar.Table.Config as Config
import Klar.Table.State as State
import Klar.Table.Types exposing (State(..))
import Klar.Table.Window as Window
import Test exposing (Test, test)


suite : Test
suite =
    test "a page past the new total clamps its offset to the last page" <|
        \_ ->
            let
                (State model) =
                    State.init "orders" |> State.setPageSize 10 |> State.setPage 99
            in
            Expect.equal ( 3, 3, 20 ) (Window.pageWindow (Config.configure []) model 23)
