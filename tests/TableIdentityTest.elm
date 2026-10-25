module TableIdentityTest exposing (suite)

import Expect
import Klar.Table.Identity as Identity
import Test exposing (Test, describe, test)


suite : Test
suite =
    describe "Table row key ranges"
        [ test "a reverse range keeps the displayed order" <|
            \_ ->
                Expect.equal (Just [ "b", "c", "d" ])
                    (Identity.keysBetween "d" "b" [ "a", "b", "c", "d", "e" ])
        , test "an anchor on another page has no range" <|
            \_ ->
                Expect.equal Nothing
                    (Identity.keysBetween "missing" "b" [ "a", "b", "c" ])
        ]
