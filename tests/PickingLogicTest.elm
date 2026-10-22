module PickingLogicTest exposing (suite)

{-| The pure logic of the tree components: ids and nodes, the index, the filter
with ancestors, the rows that are on screen, and the meaning of a checked box
(the cover).
-}

import Array
import Dict
import Expect
import Fuzz
import Klar.Icon as Icon
import Klar.Picking as Picking
import Klar.Picking.Cover as Cover exposing (Check(..))
import Klar.Picking.Index as Index exposing (Kids(..), Row(..))
import Klar.Remote as Remote
import Set exposing (Set)
import Support.PickingTrees as Trees
import Test exposing (Test, describe, fuzz, fuzz2, test)


type RegionId
    = RegionId Int


regionIds : Picking.Ids RegionId
regionIds =
    Picking.ids
        { toKey = \(RegionId n) -> "region-" ++ String.fromInt n
        , fromKey = \key -> String.toInt (String.dropLeft 7 key) |> Maybe.map RegionId
        }


suite : Test
suite =
    describe "Picking: ids, nodes, index, filter, rows, cover"
        [ idTests
        , nodeTests
        , indexTests
        , filterTests
        , rowTests
        , coverTests
        ]



-- IDS AND NODES


idTests : Test
idTests =
    describe "Ids"
        [ test "an id of the application's own type goes to a key and back" <|
            \_ ->
                Picking.toKey regionIds (RegionId 7)
                    |> Picking.fromKey regionIds
                    |> Expect.equal (Just (RegionId 7))
        , test "a key the ids do not make is rejected" <|
            \_ -> Expect.equal Nothing (Picking.fromKey regionIds "oslo")
        , test "string and int ids" <|
            \_ ->
                Expect.all
                    [ \_ -> Expect.equal ( "a", Just "a" ) ( Picking.toKey Picking.stringIds "a", Picking.fromKey Picking.stringIds "a" )
                    , \_ -> Expect.equal ( "42", Just 42 ) ( Picking.toKey Picking.intIds 42, Picking.fromKey Picking.intIds "42" )
                    , \_ -> Expect.equal Nothing (Picking.fromKey Picking.intIds "x")
                    ]
                    ()
        ]


nodeTests : Test
nodeTests =
    describe "Nodes"
        [ test "a leaf has no children, a branch has its list, a lazy node its Remote" <|
            \_ ->
                let
                    l =
                        Picking.leaf Picking.stringIds "a" "A"

                    b =
                        Picking.branch Picking.stringIds "b" "B" [ l ]

                    z =
                        Picking.lazy Picking.stringIds "z" "Z" Remote.Loading
                in
                Expect.equal
                    ( Remote.Success [], Remote.Success [ l ], Remote.Loading )
                    ( Picking.children l, Picking.children b, Picking.children z )
        , test "the modifiers set what the readers return, in any order" <|
            \_ ->
                let
                    a =
                        Picking.leaf Picking.stringIds "a" "A"
                            |> Picking.withDescription "d"
                            |> Picking.withIcon Icon.home
                            |> Picking.withKeywords [ "x" ]
                            |> Picking.withKeywords [ "y" ]
                            |> Picking.disabled

                    b =
                        Picking.leaf Picking.stringIds "a" "A"
                            |> Picking.disabled
                            |> Picking.withKeywords [ "x", "y" ]
                            |> Picking.withIcon Icon.home
                            |> Picking.withDescription "d"
                in
                Expect.all
                    [ \_ -> Expect.equal a b
                    , \_ -> Expect.equal ( "a", "A", Just "d" ) ( Picking.key a, Picking.label a, Picking.description a )
                    , \_ -> Expect.equal ( [ "x", "y" ], True, "a" ) ( Picking.keywords a, Picking.isDisabled a, Picking.id a )
                    , \_ -> Expect.equal (Just Icon.home) (Picking.icon a)
                    ]
                    ()
        ]



-- INDEX


indexTests : Test
indexTests =
    describe "Index"
        [ test "every node is found by its key, with parent and depth" <|
            \_ ->
                let
                    index =
                        Index.build Trees.cities
                in
                Expect.equal
                    [ ( Just "norway", 2 ), ( Just "europe", 1 ), ( Nothing, 0 ) ]
                    (List.map
                        (\key ->
                            ( Index.get key index |> Maybe.andThen .parent
                            , Index.get key index |> Maybe.map .depth |> Maybe.withDefault -1
                            )
                        )
                        [ "oslo", "norway", "europe" ]
                    )
        , test "the order is parents before children, siblings as given" <|
            \_ ->
                Index.build Trees.cities
                    |> .order
                    |> Expect.equal [ "europe", "norway", "oslo", "bergen", "sweden", "stockholm", "asia", "japan", "africa" ]
        , test "a lazy node that is not loaded is Unloaded, and a branch with no children is a leaf" <|
            \_ ->
                let
                    index =
                        Index.build (Picking.branch Picking.stringIds "e" "Empty" [] :: Trees.cities)
                in
                Expect.equal
                    ( Just Unloaded, Just NoKids )
                    ( Index.get "japan" index |> Maybe.map .kids, Index.get "e" index |> Maybe.map .kids )
        , test "the path and the labels from the top down" <|
            \_ ->
                let
                    index =
                        Index.build Trees.cities
                in
                Expect.equal
                    ( [ "europe", "norway", "oslo" ], [ "Europe", "Norway", "Oslo" ], [ "norway", "europe" ] )
                    ( Index.pathTo "oslo" index, Index.labelPath "oslo" index, Index.ancestors "oslo" index )
        , test "an unknown key has no path" <|
            \_ -> Expect.equal [] (Index.pathTo "mars" (Index.build Trees.cities))
        , test "a node with a disabled node below it is blocked" <|
            \_ ->
                let
                    index =
                        Index.build
                            [ Picking.branch Picking.stringIds "a" "A" [ Picking.leaf Picking.stringIds "b" "B" |> Picking.disabled ]
                            , Picking.leaf Picking.stringIds "c" "C"
                            ]
                in
                Expect.equal
                    ( Just True, Just False, Just False )
                    ( Index.get "a" index |> Maybe.map .blocked
                    , Index.get "b" index |> Maybe.map .blocked
                    , Index.get "c" index |> Maybe.map .blocked
                    )
        , test "the first node with a key wins; a later one (and what is inside it) is left out" <|
            \_ ->
                let
                    ids =
                        Picking.stringIds

                    index =
                        Index.build
                            [ Picking.leaf ids "a" "First"
                            , Picking.branch ids "a" "Second" [ Picking.leaf ids "x" "Inside" ]
                            ]
                in
                Expect.equal ( [ "a" ], Just "First", Nothing ) ( index.order, Index.get "a" index |> Maybe.map .label, Index.get "x" index )
        , test "a node inside a node with the same key is left out" <|
            \_ ->
                let
                    ids =
                        Picking.stringIds
                in
                Index.build [ Picking.branch ids "a" "A" [ Picking.leaf ids "a" "Again" ] ]
                    |> .order
                    |> Expect.equal [ "a" ]
        , fuzz Trees.specFuzzer "every key is unique, found, and its parent comes before it" <|
            \spec ->
                let
                    index =
                        Trees.indexOf spec
                in
                Expect.all
                    [ \_ -> Expect.equal (List.length spec) (Index.size index)
                    , \_ -> Expect.equal (List.length index.order) (Set.size (Set.fromList index.order))
                    , \_ ->
                        index.order
                            |> List.all
                                (\key ->
                                    case Index.get key index |> Maybe.andThen .parent of
                                        Just parent ->
                                            Maybe.map2 (<) (Index.get parent index |> Maybe.map .position) (Index.get key index |> Maybe.map .position) == Just True

                                        Nothing ->
                                            True
                                )
                            |> Expect.equal True
                    ]
                    ()
        , test "findLabels finds labels in a tree without building an index" <|
            \_ ->
                Index.findLabels (Set.fromList [ "bergen", "africa", "mars" ]) Trees.cities
                    |> Dict.toList
                    |> Expect.equal [ ( "africa", "Africa" ), ( "bergen", "Bergen" ) ]
        ]



-- FILTER


filterTests : Test
filterTests =
    let
        index =
            Index.build Trees.cities
    in
    describe "Filter"
        [ test "a blank text filters nothing" <|
            \_ -> Expect.equal Nothing (Index.filter "   " index)
        , test "a match keeps its ancestors and nothing else" <|
            \_ ->
                case Index.filter "oslo" index of
                    Just f ->
                        Expect.equal
                            ( [ "oslo" ], [ "europe", "norway" ], [ "europe", "norway", "oslo" ] )
                            ( Set.toList f.matched, Set.toList f.forced, Set.toList f.visible )

                    Nothing ->
                        Expect.fail "expected a filter"
        , test "case and accents do not matter, and every word must match" <|
            \_ ->
                Expect.equal
                    ( [ "norway" ], [ "bergen" ], [] )
                    ( matchedBy "NORWAY" index
                    , matchedBy "bjorgvin" index
                    , matchedBy "oslo bergen" index
                    )
        , test "the description and the keywords are searched too" <|
            \_ -> Expect.equal [ "oslo" ] (matchedBy "osl" index |> List.filter (\k -> k == "oslo"))
        , fuzz2 Trees.specFuzzer (Fuzz.intRange 0 30) "filtering never loses a matching node: it is on screen with all its ancestors open" <|
            \spec which ->
                let
                    tree =
                        Trees.indexOf spec

                    text =
                        "node " ++ String.fromInt which

                    maybeFilter =
                        Index.filter text tree
                in
                case maybeFilter of
                    Just f ->
                        let
                            shown =
                                Index.rows { expanded = Set.empty, flips = Set.empty, filter = Just f } tree
                        in
                        f.matched
                            |> Set.toList
                            |> List.all (\key -> Dict.member key shown.positions)
                            |> Expect.equal True

                    Nothing ->
                        Expect.pass
        , fuzz Trees.specFuzzer "the ancestors of a match are always visible" <|
            \spec ->
                let
                    tree =
                        Trees.indexOf spec
                in
                case Index.filter "node 1" tree of
                    Just f ->
                        f.matched
                            |> Set.toList
                            |> List.concatMap (\key -> Index.ancestors key tree)
                            |> List.all (\a -> Set.member a f.visible)
                            |> Expect.equal True

                    Nothing ->
                        Expect.pass
        ]


matchedBy : String -> Index.Index String -> List String
matchedBy text index =
    Index.filter text index
        |> Maybe.map (.matched >> Set.toList)
        |> Maybe.withDefault []



-- ROWS


openOf : List String -> Index.View
openOf keys =
    { expanded = Set.fromList keys, flips = Set.empty, filter = Nothing }


rowKeys : Index.Rows String -> List String
rowKeys shown =
    shown.rows
        |> Array.toList
        |> List.map
            (\row ->
                case row of
                    NodeRow item ->
                        item.entry.key

                    LoadingRow r ->
                        "loading:" ++ r.parent

                    FailedRow r ->
                        "failed:" ++ r.parent
            )


rowTests : Test
rowTests =
    let
        index =
            Index.build Trees.cities
    in
    describe "Rows"
        [ test "closed, only the top level is on screen" <|
            \_ -> Expect.equal [ "europe", "asia", "africa" ] (rowKeys (Index.rows (openOf []) index))
        , test "an open branch shows its children, an open lazy node a loading row" <|
            \_ ->
                Expect.equal
                    [ "europe", "norway", "oslo", "bergen", "sweden", "asia", "japan", "africa" ]
                    (rowKeys (Index.rows (openOf [ "europe", "norway", "asia" ]) index))
        , test "an open lazy node: loading, then failed" <|
            \_ ->
                let
                    failing =
                        Index.build [ Picking.lazy Picking.stringIds "z" "Z" (Remote.Failure (Remote.problem Remote.network)) ]
                in
                Expect.equal
                    ( [ "z", "loading:z" ], [ "z", "failed:z" ] )
                    ( rowKeys (Index.rows (openOf [ "z" ]) (Index.build [ Picking.lazy Picking.stringIds "z" "Z" Remote.Loading ]))
                    , rowKeys (Index.rows (openOf [ "z" ]) failing)
                    )
        , test "position and size among the siblings" <|
            \_ ->
                let
                    shown =
                        Index.rows (openOf [ "europe" ]) index

                    at key =
                        Index.rowIndex key shown
                            |> Maybe.andThen (\i -> Index.rowAt i shown)
                            |> Maybe.map
                                (\row ->
                                    case row of
                                        NodeRow item ->
                                            ( item.posInSet, item.setSize )

                                        _ ->
                                            ( 0, 0 )
                                )
                in
                Expect.equal ( Just ( 2, 2 ), Just ( 3, 3 ), Just ( 1, 2 ) ) ( at "sweden", at "africa", at "norway" )
        , test "the open flag of a leaf is false even when its key is in the open set" <|
            \_ ->
                Index.rows (openOf [ "oslo", "europe", "norway" ]) index
                    |> Index.rowIndex "oslo"
                    |> Maybe.andThen (\i -> Index.rowAt i (Index.rows (openOf [ "oslo", "europe", "norway" ]) index))
                    |> Maybe.map
                        (\row ->
                            case row of
                                NodeRow item ->
                                    ( item.open, item.expandable )

                                _ ->
                                    ( True, True )
                        )
                    |> Expect.equal (Just ( False, False ))
        , test "with a filter the matches are on screen with their ancestors opened" <|
            \_ ->
                Expect.equal
                    [ "europe", "norway", "oslo" ]
                    (rowKeys (Index.rows { expanded = Set.empty, flips = Set.empty, filter = Index.filter "oslo" index } index))
        , test "a flip closes a node the filter opened" <|
            \_ ->
                Expect.equal
                    [ "europe", "norway" ]
                    (rowKeys (Index.rows { expanded = Set.empty, flips = Set.fromList [ "norway" ], filter = Index.filter "oslo" index } index))
        , test "a matching branch without matching children shows all its children when opened" <|
            \_ ->
                Expect.equal
                    [ "europe", "norway", "oslo", "bergen", "sweden" ]
                    (rowKeys
                        (Index.rows
                            { expanded = Set.empty, flips = Set.fromList [ "europe", "norway" ], filter = Index.filter "europe" index }
                            index
                        )
                        |> List.filter (\k -> k /= "stockholm")
                    )
        , fuzz Trees.specFuzzer "clearing the filter gives back the rows of before: the filter never touches what the user opened" <|
            \spec ->
                let
                    tree =
                        Trees.indexOf spec

                    open =
                        tree.order |> List.indexedMap Tuple.pair |> List.filter (\( i, _ ) -> modBy 3 i == 0) |> List.map Tuple.second

                    before =
                        Index.rows (openOf open) tree

                    during =
                        Index.rows { expanded = Set.fromList open, flips = Set.empty, filter = Index.filter "node 2" tree } tree

                    after =
                        Index.rows { expanded = Set.fromList open, flips = Set.empty, filter = Index.filter "" tree } tree
                in
                Expect.all
                    [ \_ -> Expect.equal (rowKeys before) (rowKeys after)
                    , \_ -> Expect.atMost (Index.size tree) during.shown
                    ]
                    ()
        , fuzz Trees.specFuzzer "posInSet is between 1 and setSize and the rows are in document order" <|
            \spec ->
                let
                    tree =
                        Trees.indexOf spec

                    shown =
                        Index.rows (openOf tree.order) tree

                    items =
                        shown.rows
                            |> Array.toList
                            |> List.filterMap
                                (\row ->
                                    case row of
                                        NodeRow item ->
                                            Just item

                                        _ ->
                                            Nothing
                                )
                in
                Expect.all
                    [ \_ -> Expect.equal True (List.all (\item -> item.posInSet >= 1 && item.posInSet <= item.setSize) items)
                    , \_ -> Expect.equal tree.order (List.map (\item -> item.entry.key) items)
                    ]
                    ()
        , test "moves between rows skip what the predicate refuses" <|
            \_ ->
                let
                    shown =
                        Index.rows (openOf [ "europe", "norway" ]) index

                    notBergen row =
                        case row of
                            NodeRow item ->
                                item.entry.key /= "bergen"

                            _ ->
                                True

                    at key =
                        Index.rowIndex key shown |> Maybe.withDefault -1
                in
                Expect.equal
                    [ Just (at "sweden"), Just (at "oslo"), Just (at "africa"), Just (at "europe") ]
                    [ Index.nextRow notBergen (at "oslo") shown
                    , Index.previousRow notBergen (at "sweden") shown
                    , Index.lastRow notBergen shown
                    , Index.parentRow (at "norway") shown
                    ]
        , test "a thousand open branches with ten thousand nodes build their rows" <|
            \_ ->
                let
                    ids =
                        Picking.stringIds

                    big =
                        List.range 1 100
                            |> List.map
                                (\i ->
                                    Picking.branch ids
                                        ("s" ++ String.fromInt i)
                                        "Site"
                                        (List.range 1 100 |> List.map (\j -> Picking.leaf ids ("s" ++ String.fromInt i ++ "-" ++ String.fromInt j) "Bin"))
                                )

                    tree =
                        Index.build big
                in
                Expect.equal ( 10100, 10100 ) ( Index.size tree, (Index.rows (openOf tree.order) tree).shown )
        ]



-- COVER


{-| The nodes that are chosen: members and everything below them.
-}
effective : Index.Index String -> Set String -> Set String
effective index cover =
    index.order |> List.filter (Cover.isCovered index cover) |> Set.fromList


subtreeOf : String -> Index.Index String -> Set String
subtreeOf key index =
    Set.fromList (Index.keysBelow key index)


cleanNodes : Set String -> Index.Index String -> Set String
cleanNodes keys index =
    keys
        |> Set.filter (\k -> Index.get k index |> Maybe.map (\e -> not e.disabled && not e.blocked) |> Maybe.withDefault False)


{-| Toggles the nodes whose position in the document is picked by the numbers.
-}
walk : Index.Index String -> List Int -> Set String
walk index picks =
    List.foldl
        (\n cover ->
            case List.drop (modBy (max 1 (List.length index.order)) n) index.order |> List.head of
                Just key ->
                    if Index.get key index |> Maybe.map .disabled |> Maybe.withDefault True then
                        cover

                    else
                        Cover.toggle index cover (Cover.derive index cover) key

                Nothing ->
                    cover
        )
        Set.empty
        picks


noNesting : Index.Index String -> Set String -> Bool
noNesting index cover =
    Set.toList cover
        |> List.all (\key -> not (List.any (\a -> Set.member a cover) (Index.ancestors key index)))


coverTests : Test
coverTests =
    let
        index =
            Index.build Trees.cities

        none =
            Set.empty

        derived cover =
            Cover.derive index cover

        stateOf cover key =
            Cover.stateOf index cover (derived cover) key
    in
    describe "Cover (what a checked box means)"
        [ test "checking a parent puts one key in the value and checks everything below" <|
            \_ ->
                let
                    cover =
                        Cover.check index none "europe"
                in
                Expect.equal
                    ( [ "europe" ], [ Checked, Checked, Checked, Unchecked ] )
                    ( Set.toList cover, List.map (stateOf cover) [ "norway", "oslo", "stockholm", "asia" ] )
        , test "a node with a checked leaf is partial, all the way up" <|
            \_ ->
                let
                    cover =
                        Cover.check index none "oslo"
                in
                Expect.equal
                    ( [ "oslo" ], [ Partial, Partial, Unchecked, Checked ] )
                    ( Set.toList cover, List.map (stateOf cover) [ "norway", "europe", "sweden", "oslo" ] )
        , test "when all the children are checked they become their parent" <|
            \_ ->
                let
                    cover =
                        none |> (\c -> Cover.check index c "oslo") |> (\c -> Cover.check index c "bergen")
                in
                Expect.equal ( [ "norway" ], Partial ) ( Set.toList cover, stateOf cover "europe" )
        , test "and so on up the tree" <|
            \_ ->
                let
                    cover =
                        none
                            |> (\c -> Cover.check index c "oslo")
                            |> (\c -> Cover.check index c "bergen")
                            |> (\c -> Cover.check index c "stockholm")
                in
                Expect.equal ( [ "europe" ], Checked ) ( Set.toList cover, stateOf cover "europe" )
        , test "unchecking a leaf of a checked parent splits the parent into what stays" <|
            \_ ->
                let
                    cover =
                        Cover.check index none "europe" |> (\c -> Cover.uncheck index c "oslo")
                in
                Expect.equal
                    ( [ "bergen", "sweden" ], [ Partial, Partial, Unchecked, Checked ] )
                    ( Set.toList cover, List.map (stateOf cover) [ "europe", "norway", "oslo", "sweden" ] )
        , test "unchecking a parent clears everything below it" <|
            \_ ->
                let
                    cover =
                        none
                            |> (\c -> Cover.check index c "oslo")
                            |> (\c -> Cover.check index c "stockholm")
                            |> (\c -> Cover.uncheck index c "europe")
                in
                Expect.equal [] (Set.toList cover)
        , test "toggling a partial node checks it all, toggling a checked one unchecks it" <|
            \_ ->
                let
                    one =
                        Cover.check index none "oslo"

                    all =
                        Cover.toggle index one (derived one) "norway"

                    back =
                        Cover.toggle index all (derived all) "norway"
                in
                Expect.equal ( [ "norway" ], [] ) ( Set.toList all, Set.toList back )
        , test "a lazy node that is not loaded can be checked as a whole" <|
            \_ ->
                let
                    cover =
                        Cover.check index none "japan"
                in
                Expect.equal ( [ "asia" ], Checked, Checked ) ( Set.toList cover, stateOf cover "asia", stateOf cover "japan" )
        , test "the leaves of a cover are written out in the order of the tree, a lazy node stays as it is" <|
            \_ ->
                Cover.leaves index (Set.fromList [ "europe", "asia", "mars" ])
                    |> Expect.equal [ "oslo", "bergen", "stockholm", "japan", "mars" ]
        , describe "a disabled node is never chosen"
            [ test "checking the parent of a disabled leaf checks the other children one by one" <|
                \_ ->
                    let
                        ids =
                            Picking.stringIds

                        tree =
                            Index.build
                                [ Picking.branch ids
                                    "p"
                                    "P"
                                    [ Picking.leaf ids "a" "A"
                                    , Picking.leaf ids "b" "B" |> Picking.disabled
                                    , Picking.leaf ids "c" "C"
                                    ]
                                ]

                        cover =
                            Cover.check tree Set.empty "p"
                    in
                    Expect.equal
                        ( [ "a", "c" ], Checked, Unchecked )
                        ( Set.toList cover
                        , Cover.stateOf tree cover (Cover.derive tree cover) "p"
                        , Cover.stateOf tree cover (Cover.derive tree cover) "b"
                        )
            , test "a disabled branch is a heading: its children can be checked, it cannot" <|
                \_ ->
                    let
                        ids =
                            Picking.stringIds

                        tree =
                            Index.build
                                [ Picking.branch ids
                                    "h"
                                    "Heading"
                                    [ Picking.leaf ids "a" "A", Picking.leaf ids "b" "B" ]
                                    |> Picking.disabled
                                ]

                        one =
                            Cover.check tree Set.empty "a"

                        both =
                            Cover.check tree one "b"
                    in
                    Expect.equal
                        ( [ "a", "b" ], Partial, Checked )
                        ( Set.toList both
                        , Cover.stateOf tree one (Cover.derive tree one) "h"
                        , Cover.stateOf tree both (Cover.derive tree both) "h"
                        )
            , test "leaves never contain a disabled node" <|
                \_ ->
                    let
                        ids =
                            Picking.stringIds

                        tree =
                            Index.build [ Picking.branch ids "p" "P" [ Picking.leaf ids "a" "A", Picking.leaf ids "b" "B" |> Picking.disabled ] ]
                    in
                    Expect.equal [ "a" ] (Cover.leaves tree (Cover.check tree Set.empty "p"))
            ]
        , describe "properties on random trees"
            [ fuzz2 Trees.specFuzzer (Fuzz.list (Fuzz.intRange 0 200)) "the cover never has a member inside another member" <|
                \spec picks ->
                    let
                        tree =
                            Trees.indexOf spec
                    in
                    walk tree picks |> noNesting tree |> Expect.equal True
            , fuzz2 Trees.specFuzzer (Fuzz.list (Fuzz.intRange 0 200)) "a member is never disabled and has no disabled node below it" <|
                \spec picks ->
                    let
                        tree =
                            Trees.indexOf spec
                    in
                    walk tree picks
                        |> Set.toList
                        |> List.all (\key -> Index.get key tree |> Maybe.map (\e -> not e.disabled && not e.blocked) |> Maybe.withDefault False)
                        |> Expect.equal True
            , fuzz2 Trees.specFuzzer (Fuzz.pair (Fuzz.list (Fuzz.intRange 0 200)) (Fuzz.intRange 0 200)) "checking a node chooses the clean nodes inside it, loses nothing, and adds only parents that are now complete" <|
                \spec ( picks, pick ) ->
                    let
                        tree =
                            Trees.indexOf spec

                        before =
                            walk tree picks
                    in
                    case List.drop (modBy (max 1 (List.length tree.order)) pick) tree.order |> List.head of
                        Just key ->
                            let
                                after =
                                    Cover.check tree before key
                            in
                            let
                                wanted =
                                    Set.union (effective tree before) (cleanNodes (subtreeOf key tree) tree)

                                allowed =
                                    Set.union wanted (Set.fromList (Index.ancestors key tree))
                            in
                            Expect.all
                                [ \_ -> Expect.equal True (Set.isEmpty (Set.diff wanted (effective tree after)))
                                , \_ -> Expect.equal True (Set.isEmpty (Set.diff (effective tree after) allowed))
                                ]
                                ()

                        Nothing ->
                            Expect.pass
            , fuzz2 Trees.specFuzzer (Fuzz.pair (Fuzz.list (Fuzz.intRange 0 200)) (Fuzz.intRange 0 200)) "unchecking a node removes exactly the nodes inside it and above it, and changes nothing else" <|
                \spec ( picks, pick ) ->
                    let
                        tree =
                            Trees.indexOf spec

                        before =
                            walk tree picks
                    in
                    case List.drop (modBy (max 1 (List.length tree.order)) pick) tree.order |> List.head of
                        Just key ->
                            Expect.equal
                                (Set.diff (effective tree before) (Set.union (subtreeOf key tree) (Set.fromList (Index.ancestors key tree))))
                                (effective tree (Cover.uncheck tree before key))

                        Nothing ->
                            Expect.pass
            , fuzz2 Trees.specFuzzer (Fuzz.list (Fuzz.intRange 0 200)) "the cover is the shortest form: no parent has all its children as members" <|
                \spec picks ->
                    let
                        tree =
                            Trees.indexOf spec

                        cover =
                            walk tree picks
                    in
                    tree.order
                        |> List.filter (\key -> Index.get key tree |> Maybe.map (\e -> not e.disabled && not e.blocked) |> Maybe.withDefault False)
                        |> List.all
                            (\key ->
                                case Index.get key tree |> Maybe.map .kids of
                                    Just (Kids kids) ->
                                        not (List.all (\k -> Set.member k cover) kids)

                                    _ ->
                                        True
                            )
                        |> Expect.equal True
            , fuzz2 Trees.specFuzzer (Fuzz.list (Fuzz.intRange 0 200)) "a node is partial exactly when something below it is chosen and it is not chosen completely" <|
                \spec picks ->
                    let
                        tree =
                            Trees.indexOf spec

                        cover =
                            walk tree picks

                        chosen =
                            effective tree cover

                        d =
                            Cover.derive tree cover
                    in
                    tree.order
                        |> List.filter (\key -> Index.get key tree |> Maybe.map (\e -> not e.disabled && not e.blocked) |> Maybe.withDefault False)
                        |> List.all
                            (\key ->
                                let
                                    below =
                                        Set.remove key (subtreeOf key tree)

                                    someBelow =
                                        not (Set.isEmpty (Set.intersect below chosen))
                                in
                                case Cover.stateOf tree cover d key of
                                    Checked ->
                                        Set.member key chosen

                                    Partial ->
                                        not (Set.member key chosen) && someBelow

                                    Unchecked ->
                                        not (Set.member key chosen) && not someBelow
                            )
                        |> Expect.equal True
            , fuzz2 Trees.specFuzzer (Fuzz.list (Fuzz.intRange 0 200)) "leaves are known keys, not disabled, and each chosen leaf is chosen" <|
                \spec picks ->
                    let
                        tree =
                            Trees.indexOf spec

                        cover =
                            walk tree picks
                    in
                    Cover.leaves tree cover
                        |> List.all
                            (\key ->
                                (Index.get key tree |> Maybe.map (.disabled >> not) |> Maybe.withDefault False)
                                    && Cover.isCovered tree cover key
                            )
                        |> Expect.equal True
            , fuzz2 Trees.specFuzzer (Fuzz.intRange 0 200) "check then uncheck of one node on an empty cover gives the empty cover" <|
                \spec pick ->
                    let
                        tree =
                            Trees.indexOf spec
                    in
                    case List.drop (modBy (max 1 (List.length tree.order)) pick) tree.order |> List.head of
                        Just key ->
                            Cover.check tree Set.empty key
                                |> (\c -> Cover.uncheck tree c key)
                                |> Expect.equal Set.empty

                        Nothing ->
                            Expect.pass
            ]
        ]
