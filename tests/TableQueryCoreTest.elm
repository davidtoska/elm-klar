module TableQueryCoreTest exposing (suite)

import Expect
import Json.Decode as Decode
import Klar.Table.Query as Query
import Test exposing (Test, test)


suite : Test
suite =
    test "an unknown saved filter does not discard the rest of a query" <|
        \_ ->
            Decode.decodeString Query.queryDecoder "{\"v\":1,\"search\":\"invoice\",\"page\":3,\"filters\":[{\"column\":\"x\",\"futureFilter\":true}]}"
                |> Result.map (\q -> ( q.search, q.page, List.length q.filters ))
                |> Expect.equal (Ok ( "invoice", 3, 0 ))
