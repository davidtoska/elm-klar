module Klar.Cascader.Columns exposing
    ( Cell(..)
    , Column
    , Result
    , Searchable
    , choosable
    , columns
    , firstItem
    , indexOfKey
    , isValidPath
    , lastItem
    , nextItem
    , previousItem
    , results
    , searchables
    )

{-| The pure side of `Klar.Cascader`: the columns that are on screen for a trail
of opened nodes, the moves inside a column, the check that a path is a path of the
tree, and the search over the full paths of the nodes that can be chosen.

Not for application code.

-}

import Array exposing (Array)
import Klar.Internal.Freshness as Freshness
import Klar.Picking as Picking
import Klar.Picking.Index as Index exposing (Index, Kids(..))
import Klar.Remote as Remote
import Klar.Search as Search


{-| One row of a column: a node (its key, its place among its siblings and how
many siblings there are), or what stands in for children that are on their way
or failed to load.
-}
type Cell
    = ItemCell String Int Int
    | PendingCell String
    | FailedCell String Remote.Problem
    | StaleCell String Index.Stale


{-| The nodes of one level: the children of `parent` (the top level for
`Nothing`).
-}
type alias Column =
    { depth : Int
    , parent : Maybe String
    , cells : Array Cell
    }


{-| The columns for a trail of opened nodes (the top first): the top level, then
the children of each opened node. A key that is not in the tree ends the trail.
-}
columns : Index id -> List String -> List Column
columns index trail =
    column index 0 Nothing index.roots :: trailColumns index 1 trail


trailColumns : Index id -> Int -> List String -> List Column
trailColumns index depth trail =
    case trail of
        [] ->
            []

        key :: rest ->
            case Index.get key index of
                Just entry ->
                    case childrenOf entry.kids of
                        Just cells ->
                            { depth = depth, parent = Just key, cells = cellsFor key cells entry }
                                :: trailColumns index (depth + 1) rest

                        Nothing ->
                            []

                Nothing ->
                    []


childrenOf : Kids -> Maybe (List String)
childrenOf kids =
    case kids of
        Kids keys ->
            Just keys

        NoKids ->
            Nothing

        _ ->
            Just []


{-| The cells of a column: its nodes (under the marker for old data when the last
refresh of them failed), or what stands in for them.
-}
cellsFor : String -> List String -> Index.Entry id -> Array Cell
cellsFor parent keys entry =
    case entry.kids of
        Kids _ ->
            case entry.freshness of
                Freshness.Stale stale ->
                    Array.append (Array.fromList [ StaleCell parent stale ]) (itemCells keys)

                _ ->
                    itemCells keys

        LoadFailed problem ->
            Array.fromList [ FailedCell parent problem ]

        _ ->
            Array.fromList [ PendingCell parent ]


column : Index id -> Int -> Maybe String -> List String -> Column
column _ depth parent keys =
    { depth = depth, parent = parent, cells = itemCells keys }


itemCells : List String -> Array Cell
itemCells keys =
    let
        count =
            List.length keys
    in
    keys |> List.indexedMap (\i key -> ItemCell key (i + 1) count) |> Array.fromList


cellKey : Cell -> Maybe String
cellKey cell =
    case cell of
        ItemCell key _ _ ->
            Just key

        _ ->
            Nothing


{-| Where a node is in a column.
-}
indexOfKey : String -> Column -> Maybe Int
indexOfKey key col =
    col.cells
        |> Array.toList
        |> List.indexedMap Tuple.pair
        |> List.filter (\( _, cell ) -> cellKey cell == Just key)
        |> List.head
        |> Maybe.map Tuple.first


seek : (Cell -> Bool) -> Int -> Int -> Column -> Maybe Int
seek accept direction from col =
    case Array.get from col.cells of
        Nothing ->
            Nothing

        Just cell ->
            if accept cell then
                Just from

            else
                seek accept direction (from + direction) col


firstItem : (Cell -> Bool) -> Column -> Maybe Int
firstItem accept col =
    seek accept 1 0 col


lastItem : (Cell -> Bool) -> Column -> Maybe Int
lastItem accept col =
    seek accept -1 (Array.length col.cells - 1) col


nextItem : (Cell -> Bool) -> Int -> Column -> Maybe Int
nextItem accept from col =
    seek accept 1 (from + 1) col


previousItem : (Cell -> Bool) -> Int -> Column -> Maybe Int
previousItem accept from col =
    seek accept -1 (from - 1) col


{-| Is this list of keys a path of the tree, from a node at the top down to a node
below it, each the child of the one before? An empty list is not.
-}
isValidPath : Index id -> List String -> Bool
isValidPath index keys =
    case List.reverse keys of
        [] ->
            False

        lastKey :: _ ->
            Index.pathTo lastKey index == keys



-- SEARCH


{-| A node that can be chosen, with its full path written out and prepared for
matching.
-}
type alias Searchable =
    { key : String
    , text : String
    , prepared : Search.Prepared
    }


{-| A node that matched, with the score of the match (lower is better).
-}
type alias Result =
    { key : String
    , text : String
    , score : Int
    }


{-| Can the node be chosen? Not when it is disabled, and (unless any node may be
chosen) only a node without children.
-}
choosable : Bool -> Index.Entry id -> Bool
choosable anyNode entry =
    not entry.disabled && (anyNode || entry.kids == NoKids)


{-| The nodes that can be chosen, in the order of the tree, with the full path of
each joined by the separator, and its extra search words.
-}
searchables : Bool -> String -> Index id -> Array Searchable
searchables anyNode separator index =
    index.order
        |> List.filterMap
            (\key ->
                case Index.get key index of
                    Just entry ->
                        if choosable anyNode entry then
                            let
                                text =
                                    String.join separator (Index.labelPath key index)
                            in
                            Just
                                { key = key
                                , text = text
                                , prepared =
                                    Search.prepare
                                        (String.join " "
                                            (text :: Maybe.withDefault "" (Picking.description entry.node) :: Picking.keywords entry.node)
                                        )
                                }

                        else
                            Nothing

                    Nothing ->
                        Nothing
            )
        |> Array.fromList


{-| The paths that match the text, best first (equal scores keep the order of
the tree). A text without words matches nothing here: the cascader shows its
columns then.
-}
results : String -> Array Searchable -> Array Result
results text items =
    if String.isEmpty (String.trim text) then
        Array.empty

    else
        let
            q =
                Search.query text
        in
        items
            |> Array.toList
            |> List.filterMap
                (\item ->
                    Search.scorePrepared q item.prepared
                        |> Maybe.map (\score -> { key = item.key, text = item.text, score = score })
                )
            |> List.sortBy .score
            |> Array.fromList
