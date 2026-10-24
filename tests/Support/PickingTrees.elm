module Support.PickingTrees exposing
    ( Spec
    , cities
    , indexOf
    , keysOf
    , nodesOf
    , specFuzzer
    , subtree
    , wide
    )

{-| Trees for the tests of the picking components: random ones from a small
description (each node says which earlier node is its parent and whether it is
disabled), and a few fixed ones.
-}

import Dict exposing (Dict)
import Fuzz exposing (Fuzzer)
import Klar.Ids as Ids exposing (Ids)
import Klar.Picking as Picking exposing (Node)
import Klar.Picking.Index as Index exposing (Index)
import Klar.Remote as Remote


{-| One entry per node, named `n0`, `n1` ...: the parent is the index of an earlier
node, or -1 for a node at the top.
-}
type alias Spec =
    List { parent : Int, disabled : Bool }


specFuzzer : Fuzzer Spec
specFuzzer =
    Fuzz.listOfLengthBetween 0 30 (Fuzz.map2 Tuple.pair (Fuzz.intRange 0 1000) (Fuzz.intRange 0 9))
        |> Fuzz.map
            (List.indexedMap
                (\i ( r, d ) ->
                    { parent =
                        if i == 0 || modBy (i + 1) r == i then
                            -1

                        else
                            modBy (i + 1) r
                    , disabled = d == 0
                    }
                )
            )


nodesOf : Spec -> List (Node String)
nodesOf spec =
    let
        childrenOf : Dict Int (List Int)
        childrenOf =
            spec
                |> List.indexedMap Tuple.pair
                |> List.foldr
                    (\( i, s ) dict -> Dict.update s.parent (\old -> Just (i :: Maybe.withDefault [] old)) dict)
                    Dict.empty

        disabledAt =
            spec |> List.indexedMap (\i s -> ( i, s.disabled )) |> Dict.fromList

        build i =
            let
                kids =
                    Dict.get i childrenOf |> Maybe.withDefault []

                name =
                    "n" ++ String.fromInt i

                base =
                    Picking.branch Ids.string name ("Node " ++ String.fromInt i) (List.map build kids)
            in
            if Dict.get i disabledAt == Just True then
                Picking.disabled base

            else
                base
    in
    Dict.get -1 childrenOf |> Maybe.withDefault [] |> List.map build


indexOf : Spec -> Index String
indexOf spec =
    Index.build (nodesOf spec)


keysOf : Index String -> List String
keysOf index =
    index.order


{-| Europe > Norway > Oslo, Bergen; Sweden > Stockholm; Asia > Japan (lazy, not
loaded); Africa (leaf).
-}
cities : List (Node String)
cities =
    let
        ids =
            Ids.string
    in
    [ Picking.branch ids
        "europe"
        "Europe"
        [ Picking.branch ids
            "norway"
            "Norway"
            [ Picking.leaf ids "oslo" "Oslo" |> Picking.withDescription "OSL"
            , Picking.leaf ids "bergen" "Bergen" |> Picking.withKeywords [ "Bjørgvin" ]
            ]
        , Picking.branch ids "sweden" "Sweden" [ Picking.leaf ids "stockholm" "Stockholm" ]
        ]
    , Picking.branch ids "asia" "Asia" [ Picking.lazy ids "japan" "Japan" Remote.NotAsked ]
    , Picking.leaf ids "africa" "Africa"
    ]


{-| A top level with `n` leaves.
-}
wide : Int -> List (Node String)
wide n =
    List.range 1 n
        |> List.map (\i -> Picking.leaf Ids.string ("w" ++ String.fromInt i) ("Warehouse " ++ String.fromInt i))


{-| A node and everything below it, parents before children.
-}
subtree : String -> Index String -> List String
subtree key index =
    case Index.get key index of
        Just entry ->
            key
                :: (case entry.kids of
                        Index.Kids keys ->
                            List.concatMap (\k -> subtree k index) keys

                        _ ->
                            []
                   )

        Nothing ->
            []
