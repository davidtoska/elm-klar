module PermissionMatrixGridTest exposing (suite)

{-| The pure parts of Klar.PermissionMatrix: which rows are shown (groups, the filter,
folded groups, the cap), where the keys lead, what a header checkbox means, and that
two cells never share a DOM id.
-}

import Expect
import Fuzz exposing (Fuzzer)
import Klar.PermissionMatrix.Grid as Grid exposing (ColumnKey(..), Key(..), Row(..), RowKey(..), Summary(..))
import Set
import Test exposing (Test, describe, fuzz, fuzz2, fuzz3, test)


suite : Test
suite =
    describe "Klar.PermissionMatrix.Grid"
        [ layoutTests
        , layoutProperties
        , moveTests
        , moveProperties
        , summaryTests
        , idTests
        ]



-- LAYOUT


item : Int -> String -> Maybe String -> Grid.Item
item index label group =
    { index = index, label = label, group = group }


items : List Grid.Item
items =
    [ item 0 "View orders" (Just "Orders")
    , item 1 "Edit orders" (Just "Orders")
    , item 2 "Cancel orders" (Just "Orders")
    , item 3 "View stock" (Just "Stock")
    , item 4 "Adjust stock" (Just "Stock")
    , item 5 "Export reports" Nothing
    ]


plain : { query : String, collapsed : Set.Set String, maxRows : Int }
plain =
    { query = "", collapsed = Set.empty, maxRows = 500 }


layoutTests : Test
layoutTests =
    describe "layout"
        [ test "groups have a row, followed by their permissions; permissions without a group have none" <|
            \_ ->
                (Grid.layout plain items).rows
                    |> Expect.equal
                        [ GroupRow "Orders" [ 0, 1, 2 ]
                        , PermissionRow 0
                        , PermissionRow 1
                        , PermissionRow 2
                        , GroupRow "Stock" [ 3, 4 ]
                        , PermissionRow 3
                        , PermissionRow 4
                        , PermissionRow 5
                        ]
        , test "permissions of a group that are apart are gathered, groups in the order of first appearance" <|
            \_ ->
                (Grid.layout plain
                    [ item 0 "A" (Just "Two")
                    , item 1 "B" (Just "One")
                    , item 2 "C" (Just "Two")
                    , item 3 "D" Nothing
                    , item 4 "E" (Just "One")
                    , item 5 "F" Nothing
                    ]
                ).rows
                    |> Expect.equal
                        [ GroupRow "Two" [ 0, 2 ]
                        , PermissionRow 0
                        , PermissionRow 2
                        , GroupRow "One" [ 1, 4 ]
                        , PermissionRow 1
                        , PermissionRow 4
                        , PermissionRow 3
                        , PermissionRow 5
                        ]
        , test "a folded group keeps its row and loses its permissions" <|
            \_ ->
                (Grid.layout { plain | collapsed = Set.fromList [ "Orders" ] } items).rows
                    |> Expect.equal
                        [ GroupRow "Orders" [ 0, 1, 2 ]
                        , GroupRow "Stock" [ 3, 4 ]
                        , PermissionRow 3
                        , PermissionRow 4
                        , PermissionRow 5
                        ]
        , test "the filter keeps permissions that contain every word, with their group" <|
            \_ ->
                (Grid.layout { plain | query = "orders view" } items).rows
                    |> Expect.equal [ GroupRow "Orders" [ 0 ], PermissionRow 0 ]
        , test "the filter ignores case and accents" <|
            \_ ->
                (Grid.layout { plain | query = "  CANCEL " } items).matches
                    |> Expect.equal [ 2 ]
        , test "accents fold both ways" <|
            \_ ->
                (Grid.layout { plain | query = "kansellér" } [ item 0 "Kansellere ordre" Nothing ]).matches
                    |> Expect.equal [ 0 ]
        , test "the filter also matches the name of the group" <|
            \_ ->
                (Grid.layout { plain | query = "stock" } items).matches
                    |> Expect.equal [ 3, 4 ]
        , test "while filtering, groups with a match are open even when folded" <|
            \_ ->
                (Grid.layout { plain | query = "view", collapsed = Set.fromList [ "Orders", "Stock" ] } items).rows
                    |> Expect.equal
                        [ GroupRow "Orders" [ 0 ]
                        , PermissionRow 0
                        , GroupRow "Stock" [ 3 ]
                        , PermissionRow 3
                        ]
        , test "nothing matches: no rows, no matches" <|
            \_ ->
                let
                    result =
                        Grid.layout { plain | query = "zzz" } items
                in
                Expect.equal ( result.rows, result.matches, result.total ) ( [], [], 6 )
        , test "matches include permissions in folded groups and beyond the cap" <|
            \_ ->
                let
                    result =
                        Grid.layout { plain | collapsed = Set.fromList [ "Orders" ], maxRows = 1 } items
                in
                Expect.equal ( List.length result.matches, result.truncated ) ( 6, True )
        , test "rows are cut at the cap and say so" <|
            \_ ->
                let
                    result =
                        Grid.layout { plain | maxRows = 4 } items

                    permissionRows =
                        List.filter isPermissionRow result.rows
                in
                Expect.equal ( List.length permissionRows, result.truncated ) ( 4, True )
        , test "exactly at the cap is not truncated" <|
            \_ ->
                (Grid.layout { plain | maxRows = 6 } items).truncated |> Expect.equal False
        , test "no permissions, no rows" <|
            \_ ->
                (Grid.layout plain []).rows |> Expect.equal []
        , test "a blank group counts as none: that is decided where the group is set" <|
            \_ ->
                (Grid.layout plain [ item 0 "A" Nothing ]).rows |> Expect.equal [ PermissionRow 0 ]
        ]


isPermissionRow : Row -> Bool
isPermissionRow row =
    case row of
        PermissionRow _ ->
            True

        GroupRow _ _ ->
            False


itemFuzz : Fuzzer (List Grid.Item)
itemFuzz =
    Fuzz.listOfLengthBetween 0
        30
        (Fuzz.map2 (\label group -> ( label, group ))
            (Fuzz.oneOfValues [ "View orders", "Edit orders", "Adjust stock", "Cancel", "Export", "Ångström", "" ])
            (Fuzz.oneOfValues [ Nothing, Just "Orders", Just "Stock", Just "Reports" ])
        )
        |> Fuzz.map (List.indexedMap (\index ( label, group ) -> item index label group))


queryFuzz : Fuzzer String
queryFuzz =
    Fuzz.oneOfValues [ "", " ", "view", "ORDERS", "stock adjust", "angstrom", "zzz", "o" ]


layoutProperties : Test
layoutProperties =
    describe "layout: properties"
        [ fuzz2 itemFuzz queryFuzz "every permission is drawn at most once, and only if it matches" <|
            \list query ->
                let
                    result =
                        Grid.layout { plain | query = query } list

                    drawn =
                        List.filterMap
                            (\row ->
                                case row of
                                    PermissionRow index ->
                                        Just index

                                    GroupRow _ _ ->
                                        Nothing
                            )
                            result.rows
                in
                Expect.all
                    [ \_ -> List.length drawn |> Expect.equal (Set.size (Set.fromList drawn))
                    , \_ -> List.all (\index -> List.member index result.matches) drawn |> Expect.equal True
                    ]
                    ()
        , fuzz itemFuzz "without a query or a fold, every permission is drawn" <|
            \list ->
                let
                    drawn =
                        (Grid.layout plain list).rows
                            |> List.filter isPermissionRow
                            |> List.length
                in
                Expect.equal drawn (List.length list)
        , fuzz2 itemFuzz queryFuzz "the group row of a group lists the matches of that group" <|
            \list query ->
                (Grid.layout { plain | query = query } list).rows
                    |> List.all
                        (\row ->
                            case row of
                                GroupRow name members ->
                                    List.all
                                        (\index ->
                                            list
                                                |> List.filter (\each -> each.index == index)
                                                |> List.all (\each -> each.group == Just name)
                                        )
                                        members
                                        && not (List.isEmpty members)

                                PermissionRow _ ->
                                    True
                        )
                    |> Expect.equal True
        , fuzz3 itemFuzz queryFuzz (Fuzz.intRange 0 12) "the cap is never exceeded, and rows are cut only when something was left out" <|
            \list query cap ->
                let
                    uncapped =
                        Grid.layout { plain | query = query, maxRows = 1000 } list

                    capped =
                        Grid.layout { plain | query = query, maxRows = cap } list

                    drawn =
                        List.length (List.filter isPermissionRow capped.rows)
                in
                Expect.all
                    [ \_ -> Expect.atMost cap drawn
                    , \_ -> capped.truncated |> Expect.equal (List.length uncapped.rows > List.length capped.rows)
                    , \_ -> capped.matches |> Expect.equal uncapped.matches
                    ]
                    ()
        ]



-- MOVING


size : Grid.Size
size =
    { rows = 6, columns = 5, page = 3 }


moveTests : Test
moveTests =
    describe "keys"
        [ test "arrows move one cell" <|
            \_ ->
                List.map (\key -> Grid.move size key ( 3, 2 )) [ Up, Down, Left, Right ]
                    |> Expect.equal [ ( 2, 2 ), ( 4, 2 ), ( 3, 1 ), ( 3, 3 ) ]
        , test "arrows stay at the edge" <|
            \_ ->
                Expect.equal
                    [ Grid.move size Down ( 5, 2 ), Grid.move size Right ( 3, 4 ), Grid.move size Up ( 0, 2 ), Grid.move size Left ( 3, 0 ) ]
                    [ ( 5, 2 ), ( 3, 4 ), ( 0, 2 ), ( 3, 0 ) ]
        , test "Home and End go to the first and last cell of the row" <|
            \_ ->
                Expect.equal [ Grid.move size Home ( 3, 2 ), Grid.move size End ( 3, 2 ) ] [ ( 3, 0 ), ( 3, 4 ) ]
        , test "Ctrl+Home and Ctrl+End go to the first and last cell of the matrix" <|
            \_ ->
                Expect.equal [ Grid.move size CtrlHome ( 3, 2 ), Grid.move size CtrlEnd ( 3, 2 ) ] [ ( 0, 1 ), ( 5, 4 ) ]
        , test "a page is the number of rows given, and stops at the ends" <|
            \_ ->
                Expect.equal
                    [ Grid.move size PageDown ( 1, 2 ), Grid.move size PageDown ( 4, 2 ), Grid.move size PageUp ( 4, 2 ), Grid.move size PageUp ( 2, 2 ) ]
                    [ ( 4, 2 ), ( 5, 2 ), ( 1, 2 ), ( 0, 2 ) ]
        , test "the empty corner is never a stop: up from the first row stays, left from the first role stays" <|
            \_ ->
                Expect.equal
                    [ Grid.move size Up ( 1, 0 ), Grid.move size Left ( 0, 1 ), Grid.move size Home ( 0, 3 ), Grid.move size PageUp ( 2, 0 ) ]
                    [ ( 1, 0 ), ( 0, 1 ), ( 0, 1 ), ( 1, 0 ) ]
        , test "the header row is reached from the first row" <|
            \_ ->
                Grid.move size Up ( 1, 3 ) |> Expect.equal ( 0, 3 )
        ]


keyFuzz : Fuzzer Key
keyFuzz =
    Fuzz.oneOfValues [ Up, Down, Left, Right, Home, End, CtrlHome, CtrlEnd, PageUp, PageDown ]


moveProperties : Test
moveProperties =
    describe "keys: properties"
        [ fuzz3 (Fuzz.intRange 2 40) (Fuzz.intRange 2 30) keyFuzz "a move stays in the grid and is never the corner" <|
            \rows columns key ->
                let
                    start =
                        ( 1, 1 )

                    ( r, c ) =
                        Grid.move { rows = rows, columns = columns, page = 10 } key start
                in
                Expect.all
                    [ \_ -> Expect.atLeast 0 r
                    , \_ -> Expect.atMost (rows - 1) r
                    , \_ -> Expect.atLeast 0 c
                    , \_ -> Expect.atMost (columns - 1) c
                    , \_ -> ( r, c ) |> Expect.notEqual ( 0, 0 )
                    ]
                    ()
        , fuzz3 (Fuzz.intRange 2 20) (Fuzz.intRange 2 20) (Fuzz.list keyFuzz) "any series of keys stays in the grid and off the corner" <|
            \rows columns keys ->
                let
                    walk key position =
                        Grid.move { rows = rows, columns = columns, page = 4 } key position

                    ( r, c ) =
                        List.foldl walk ( 1, 1 ) keys
                in
                Expect.all
                    [ \_ -> r >= 0 && r < rows |> Expect.equal True
                    , \_ -> c >= 0 && c < columns |> Expect.equal True
                    , \_ -> ( r, c ) |> Expect.notEqual ( 0, 0 )
                    ]
                    ()
        , fuzz3 (Fuzz.intRange 2 20) (Fuzz.intRange 2 20) keyFuzz "Home, End and the Ctrl keys land at the same place from anywhere" <|
            \rows columns key ->
                let
                    s =
                        { rows = rows, columns = columns, page = 5 }

                    from a b =
                        Grid.move s key ( a, b )
                in
                case key of
                    CtrlHome ->
                        Expect.equal (from 1 1) (from (rows - 1) (columns - 1))

                    CtrlEnd ->
                        Expect.equal (from 1 1) (from (rows - 1) (columns - 1))

                    End ->
                        Expect.equal (Tuple.second (from 1 0)) (columns - 1)

                    _ ->
                        Expect.pass
        ]



-- WHAT A HEADER CHECKBOX MEANS


summaryTests : Test
summaryTests =
    describe "summary"
        [ test "nothing, none, some, all" <|
            \_ ->
                Expect.equal
                    (List.map Grid.summarize [ [], [ False, False ], [ True, False ], [ True, True ] ])
                    [ NoCells, NoneGranted, SomeGranted, AllGranted ]
        , test "a click grants what is not granted, unless everything is, then it denies all" <|
            \_ ->
                Expect.equal
                    (List.map Grid.shouldGrant [ [], [ False, False ], [ True, False ], [ True, True ] ])
                    [ Nothing, Just True, Just True, Just False ]
        , fuzz (Fuzz.list Fuzz.bool) "a click always leads toward all or none, never stays" <|
            \cells ->
                case Grid.shouldGrant cells of
                    Nothing ->
                        List.isEmpty cells |> Expect.equal True

                    Just True ->
                        List.all identity cells |> Expect.equal False

                    Just False ->
                        List.all identity cells |> Expect.equal True
        ]



-- DOM IDS


idTests : Test
idTests =
    describe "ids"
        [ test "the id has the matrix, the row and the column" <|
            \_ ->
                Grid.domId "roles" (PermissionKey "cancel-orders") (RoleKey "supervisor")
                    |> Expect.equal "roles/pcancel-orders/rsupervisor"
        , test "the header and the labels have a place of their own" <|
            \_ ->
                Expect.equal
                    [ Grid.domId "m" HeaderKey LabelKey, Grid.domId "m" (GroupKey "Orders") LabelKey ]
                    [ "m/h/l", "m/gOrders/l" ]
        , fuzz2 keyTextFuzz keyTextFuzz "different cells never share an id, whatever the keys contain" <|
            \a b ->
                let
                    ids =
                        [ Grid.domId "m" (PermissionKey a) (RoleKey b)
                        , Grid.domId "m" (PermissionKey (a ++ "/" ++ b)) LabelKey
                        , Grid.domId "m" (GroupKey a) (RoleKey b)
                        , Grid.domId "m" (PermissionKey b) (RoleKey a)
                        ]
                in
                if a == b then
                    -- the first and the fourth are the same cell then
                    Expect.equal (List.length (List.sort (List.map identity ids |> uniqueList))) 3

                else
                    Expect.equal (List.length (uniqueList ids)) 4
        ]


keyTextFuzz : Fuzzer String
keyTextFuzz =
    Fuzz.oneOfValues [ "a", "b", "a/b", "a%2Fb", "", "p", "r", "x y", "ø", "a-b", "a.b" ]


uniqueList : List String -> List String
uniqueList list =
    Set.toList (Set.fromList list)
