module TypedIdsTest exposing (suite)

import Expect
import Klar.SideNav as SideNav
import Klar.Tree as Tree
import Test exposing (Test, describe, test)


type RegionId
    = RegionId Int


type Page
    = Orders
    | Reports


regions : Tree.Ids RegionId
regions =
    Tree.nodeIds
        { toKey = \(RegionId n) -> "region-" ++ String.fromInt n
        , fromKey = \key -> String.toInt (String.dropLeft 7 key) |> Maybe.map RegionId
        }


pages : SideNav.Keys Page
pages =
    SideNav.keys
        (\page ->
            case page of
                Orders ->
                    "orders"

                Reports ->
                    "reports"
        )


suite : Test
suite =
    describe "ids and keys of the app's own type (Tree, SideNav)"
        [ test "Tree: open nodes come back in the app's type" <|
            \_ ->
                (Tree.init "regions" |> Tree.setExpanded regions [ RegionId 2, RegionId 10 ])
                    |> Tree.expanded regions
                    |> Expect.equal [ RegionId 10, RegionId 2 ]
        , test "Tree: isExpanded takes the app's type" <|
            \_ ->
                let
                    state =
                        Tree.init "regions" |> Tree.expand regions (RegionId 3)
                in
                Expect.equal ( True, False ) ( Tree.isExpanded regions (RegionId 3) state, Tree.isExpanded regions (RegionId 4) state )
        , test "Tree: select, selectedId and checked" <|
            \_ ->
                let
                    state =
                        Tree.init "regions" |> Tree.select regions (RegionId 7) |> Tree.setChecked regions [ RegionId 1 ]
                in
                Expect.equal ( Just (RegionId 7), [ RegionId 1 ] ) ( Tree.selectedId regions state, Tree.checked regions state )
        , test "Tree: a state of the app's type compares with ==" <|
            \_ ->
                Expect.equal (Tree.init "r" |> Tree.expand regions (RegionId 1)) (Tree.init "r" |> Tree.expand regions (RegionId 1))
        , test "SideNav: groups open and close by the app's key" <|
            \_ ->
                let
                    open =
                        SideNav.init "nav" |> SideNav.expandGroup pages Reports
                in
                Expect.equal
                    ( True, False, False )
                    ( SideNav.isExpanded pages Reports open
                    , SideNav.isExpanded pages Orders open
                    , SideNav.isExpanded pages Reports (SideNav.collapseGroup pages Reports open)
                    )
        , test "SideNav: reveal opens the groups around a key" <|
            \_ ->
                let
                    menu =
                        [ SideNav.group pages { key = Reports, label = "Reports" } [ SideNav.item pages { key = Orders, label = "Orders", href = "#/o" } ] ]
                in
                SideNav.init "nav"
                    |> SideNav.reveal Orders menu
                    |> SideNav.isExpanded pages Reports
                    |> Expect.equal True
        ]
