module TableStateCoreTest exposing (suite)

import Expect
import Klar.Ids as Ids
import Klar.Table.Selection as Selection
import Klar.Table.State as State
import Test exposing (Test, test)


suite : Test
suite =
    test "restoring a query normalizes paging while preserving explicit row picks" <|
        \_ ->
            let
                before =
                    State.init "orders" |> Selection.select Ids.string [ "a" ]

                query =
                    State.query before

                after =
                    State.setQuery { query | search = "  next  ", page = 0, pageSize = 0 } before

                restored =
                    State.query after
            in
            Expect.equal ( ( "next", 1, 1 ), [ "a" ] ) ( ( restored.search, restored.page, restored.pageSize ), Selection.selectedIds Ids.string after )
