module Klar.Picking.Index exposing
    ( Entry
    , Filter
    , Index
    , Item
    , Kids(..)
    , Row(..)
    , Rows
    , View
    , ancestors
    , build
    , descendantKeys
    , empty
    , failureIndex
    , filter
    , findLabels
    , get
    , isAncestorOf
    , isOpen
    , keysBelow
    , labelPath
    , lastRow
    , matches
    , nextRow
    , parentRow
    , pathTo
    , previousRow
    , rowAt
    , rowIndex
    , rows
    , size
    )

{-| The pure side of the tree components: an index of a hierarchy of
`Klar.Picking.Node`s by key, the filter that keeps matches with their ancestors,
the list of rows that are on screen for a set of open nodes, and the moves
between rows.

Not for application code.

-}

import Array exposing (Array)
import Dict exposing (Dict)
import Klar.Picking as Picking exposing (Node)
import Klar.Remote as Remote
import Klar.Search as Search
import Set exposing (Set)



-- INDEX


{-| What is known of the children of a node.
-}
type Kids
    = NoKids
    | Unloaded
    | Loading
    | LoadFailed Remote.Problem
    | Kids (List String)


{-| One node of the hierarchy, looked up by its key. `position` is its place in
the document order (parents before children, siblings in the given order),
`blocked` says that a node somewhere below it is disabled, and `haystack` is the
normalized text that the filter looks in.
-}
type alias Entry id =
    { key : String
    , node : Node id
    , label : String
    , parent : Maybe String
    , depth : Int
    , kids : Kids
    , disabled : Bool
    , blocked : Bool
    , haystack : String
    , position : Int
    }


type alias Index id =
    { entries : Dict String (Entry id)
    , roots : List String
    , order : List String
    }


empty : Index id
empty =
    { entries = Dict.empty, roots = [], order = [] }


size : Index id -> Int
size index =
    Dict.size index.entries


get : String -> Index id -> Maybe (Entry id)
get key index =
    Dict.get key index.entries


type alias Acc id =
    { entries : Dict String (Entry id)
    , next : Int
    , order : List String
    }


{-| Indexes a hierarchy. A node whose key was already used (the first node wins)
is left out together with everything inside it.
-}
build : List (Node id) -> Index id
build nodes =
    let
        ( roots, _, acc ) =
            addAll Nothing 0 nodes { entries = Dict.empty, next = 0, order = [] }
    in
    { entries = acc.entries
    , roots = roots
    , order = List.reverse acc.order
    }


{-| The keys that were added, whether one of them is disabled or has a disabled
node below it, and the new accumulator.
-}
addAll : Maybe String -> Int -> List (Node id) -> Acc id -> ( List String, Bool, Acc id )
addAll parent depth nodes acc =
    let
        ( keysReversed, flagged, final ) =
            List.foldl
                (\node ( keys, anyFlag, current ) ->
                    case addOne parent depth node current of
                        Just ( key, flag, next ) ->
                            ( key :: keys, anyFlag || flag, next )

                        Nothing ->
                            ( keys, anyFlag, current )
                )
                ( [], False, acc )
                nodes
    in
    ( List.reverse keysReversed, flagged, final )


addOne : Maybe String -> Int -> Node id -> Acc id -> Maybe ( String, Bool, Acc id )
addOne parent depth node acc =
    let
        key =
            Picking.key node
    in
    if Dict.member key acc.entries then
        Nothing

    else
        let
            position =
                acc.next

            started =
                { acc | next = acc.next + 1, order = key :: acc.order, entries = Dict.insert key (placeholder key node) acc.entries }

            ( kids, below, finished ) =
                case Picking.children node of
                    Remote.Loaded [] ->
                        ( NoKids, False, started )

                    Remote.Loaded list ->
                        let
                            ( keys, flagged, after ) =
                                addAll (Just key) (depth + 1) list started
                        in
                        if List.isEmpty keys then
                            ( NoKids, False, after )

                        else
                            ( Kids keys, flagged, after )

                    Remote.NotAsked ->
                        ( Unloaded, False, started )

                    Remote.Loading ->
                        ( Loading, False, started )

                    Remote.Failed problem ->
                        ( LoadFailed problem, False, started )

            disabled =
                Picking.isDisabled node

            entry =
                { key = key
                , node = node
                , label = Picking.label node
                , parent = parent
                , depth = depth
                , kids = kids
                , disabled = disabled
                , blocked = below
                , haystack = haystackOf node
                , position = position
                }
        in
        Just ( key, disabled || below, { finished | entries = Dict.insert key entry finished.entries } )


placeholder : String -> Node id -> Entry id
placeholder key node =
    { key = key
    , node = node
    , label = Picking.label node
    , parent = Nothing
    , depth = 0
    , kids = NoKids
    , disabled = Picking.isDisabled node
    , blocked = False
    , haystack = ""
    , position = 0
    }


haystackOf : Node id -> String
haystackOf node =
    Search.normalize
        (String.join " "
            (Picking.label node
                :: Maybe.withDefault "" (Picking.description node)
                :: Picking.keywords node
            )
        )


{-| The labels of some keys, found by walking the hierarchy once (and stopping
when all are found). For a closed field that only needs the label of its value.
-}
findLabels : Set String -> List (Node id) -> Dict String String
findLabels wanted nodes =
    if Set.isEmpty wanted then
        Dict.empty

    else
        findLabelsIn wanted nodes Dict.empty


findLabelsIn : Set String -> List (Node id) -> Dict String String -> Dict String String
findLabelsIn wanted nodes found =
    case nodes of
        [] ->
            found

        node :: rest ->
            if Dict.size found >= Set.size wanted then
                found

            else
                let
                    key =
                        Picking.key node

                    here =
                        if Set.member key wanted then
                            Dict.insert key (Picking.label node) found

                        else
                            found

                    below =
                        case Picking.children node of
                            Remote.Loaded kids ->
                                findLabelsIn wanted kids here

                            _ ->
                                here
                in
                findLabelsIn wanted rest below



-- RELATIONS


{-| The keys above a node, nearest first.
-}
ancestors : String -> Index id -> List String
ancestors key index =
    case get key index |> Maybe.andThen .parent of
        Just parent ->
            parent :: ancestors parent index

        Nothing ->
            []


{-| The keys from the top down to the node, the node last. Empty when the key
is unknown.
-}
pathTo : String -> Index id -> List String
pathTo key index =
    case get key index of
        Just _ ->
            List.reverse (key :: ancestors key index)

        Nothing ->
            []


{-| The labels from the top down to the node.
-}
labelPath : String -> Index id -> List String
labelPath key index =
    pathTo key index |> List.filterMap (\k -> get k index |> Maybe.map .label)


isAncestorOf : String -> String -> Index id -> Bool
isAncestorOf ancestor key index =
    List.member ancestor (ancestors key index)


childKeys : Entry id -> List String
childKeys entry =
    case entry.kids of
        Kids keys ->
            keys

        _ ->
            []


{-| Every key below a node (not the node itself), parents before children.
-}
descendantKeys : String -> Index id -> List String
descendantKeys key index =
    case get key index of
        Just entry ->
            List.concatMap (\child -> child :: descendantKeys child index) (childKeys entry)

        Nothing ->
            []


{-| The key itself and every key below it.
-}
keysBelow : String -> Index id -> List String
keysBelow key index =
    key :: descendantKeys key index



-- FILTER


{-| The result of a filter text. `matched` are the nodes that contain every word,
`forced` the ancestors of a match (opened by the filter), `visible` both.
-}
type alias Filter =
    { words : List String
    , matched : Set String
    , forced : Set String
    , visible : Set String
    }


{-| The words of a filter text, normalized (case and diacritics ignored).
-}
words : String -> List String
words text =
    Search.normalize text
        |> String.words
        |> List.filter (\word -> word /= "")


{-| Whether a normalized text contains every word.
-}
matches : List String -> String -> Bool
matches queryWords haystack =
    List.all (\word -> String.contains word haystack) queryWords


{-| Keeps the nodes that contain every word of the text, together with their
ancestors. `Nothing` for a text without words: nothing is filtered.
-}
filter : String -> Index id -> Maybe Filter
filter text index =
    case words text of
        [] ->
            Nothing

        queryWords ->
            let
                matched =
                    Dict.foldl
                        (\key entry found ->
                            if matches queryWords entry.haystack then
                                Set.insert key found

                            else
                                found
                        )
                        Set.empty
                        index.entries

                forced =
                    Set.foldl (\key found -> addAncestors key index found) Set.empty matched
            in
            Just
                { words = queryWords
                , matched = matched
                , forced = forced
                , visible = Set.union matched forced
                }


{-| Adds the ancestors of a key, stopping at one that is already in the set (its
own ancestors are in it too).
-}
addAncestors : String -> Index id -> Set String -> Set String
addAncestors key index found =
    case get key index |> Maybe.andThen .parent of
        Just parent ->
            if Set.member parent found then
                found

            else
                addAncestors parent index (Set.insert parent found)

        Nothing ->
            found



-- ROWS


{-| How the hierarchy is looked at: the nodes the user opened, the nodes the
user flipped while a filter was active, and the filter.
-}
type alias View =
    { expanded : Set String
    , flips : Set String
    , filter : Maybe Filter
    }


{-| A node on screen. `posInSet` and `setSize` count the siblings that are shown.
-}
type alias Item id =
    { entry : Entry id
    , setSize : Int
    , posInSet : Int
    , expandable : Bool
    , open : Bool
    , matched : Bool
    }


type Row id
    = NodeRow (Item id)
    | LoadingRow { parent : String, depth : Int }
    | FailedRow { parent : String, depth : Int, problem : Remote.Problem }


type alias Rows id =
    { rows : Array (Row id)
    , positions : Dict String Int
    , failures : Dict String Int
    , shown : Int
    , matchCount : Int
    , total : Int
    , filtering : Bool
    }


isExpandable : Kids -> Bool
isExpandable kids =
    case kids of
        NoKids ->
            False

        _ ->
            True


{-| Is the node open? While a filter is active the nodes with matches below are
open and the user's flips turn that around; without a filter it is what the user
opened.
-}
isOpen : View -> String -> Bool
isOpen view key =
    case view.filter of
        Just f ->
            Set.member key f.forced /= Set.member key view.flips

        Nothing ->
            Set.member key view.expanded


{-| The rows that are on screen: the open branches only, and with a filter only
the matches and the nodes around them.
-}
rows : View -> Index id -> Rows id
rows view index =
    let
        top =
            case view.filter of
                Just f ->
                    List.filter (\key -> Set.member key f.visible) index.roots

                Nothing ->
                    index.roots

        reversed =
            emit view index top []

        ordered =
            List.reverse reversed

        positions =
            ordered
                |> List.indexedMap Tuple.pair
                |> List.foldl
                    (\( i, row ) dict ->
                        case row of
                            NodeRow r ->
                                Dict.insert r.entry.key i dict

                            _ ->
                                dict
                    )
                    Dict.empty

        failures =
            ordered
                |> List.indexedMap Tuple.pair
                |> List.foldl
                    (\( i, row ) dict ->
                        case row of
                            FailedRow r ->
                                Dict.insert r.parent i dict

                            _ ->
                                dict
                    )
                    Dict.empty

        matchCount =
            case view.filter of
                Just f ->
                    Set.size f.matched

                Nothing ->
                    size index
    in
    { rows = Array.fromList ordered
    , positions = positions
    , failures = failures
    , shown = Dict.size positions
    , matchCount = matchCount
    , total = size index
    , filtering = view.filter /= Nothing
    }


emit : View -> Index id -> List String -> List (Row id) -> List (Row id)
emit view index keys acc =
    let
        count =
            List.length keys
    in
    List.foldl
        (\key ( position, current ) ->
            ( position + 1, emitOne view index count position key current )
        )
        ( 1, acc )
        keys
        |> Tuple.second


emitOne : View -> Index id -> Int -> Int -> String -> List (Row id) -> List (Row id)
emitOne view index count position key acc =
    case get key index of
        Nothing ->
            acc

        Just entry ->
            let
                expandable =
                    isExpandable entry.kids

                open =
                    expandable && isOpen view key

                row =
                    NodeRow
                        { entry = entry
                        , setSize = count
                        , posInSet = position
                        , expandable = expandable
                        , open = open
                        , matched =
                            case view.filter of
                                Just f ->
                                    Set.member key f.matched

                                Nothing ->
                                    False
                        }

                withRow =
                    row :: acc
            in
            if open then
                case entry.kids of
                    Kids keys ->
                        emit view index (shownKids view key keys) withRow

                    Unloaded ->
                        LoadingRow { parent = key, depth = entry.depth + 1 } :: withRow

                    Loading ->
                        LoadingRow { parent = key, depth = entry.depth + 1 } :: withRow

                    LoadFailed problem ->
                        FailedRow { parent = key, depth = entry.depth + 1, problem = problem } :: withRow

                    NoKids ->
                        withRow

            else
                withRow


{-| The children of a node that are shown. While filtering, a node with matches
below shows only the children that lead to a match; a node that matches itself
and has no matches below shows all its children when the user opens it.
-}
shownKids : View -> String -> List String -> List String
shownKids view key keys =
    case view.filter of
        Just f ->
            if Set.member key f.forced then
                List.filter (\k -> Set.member k f.visible) keys

            else
                keys

        Nothing ->
            keys


rowAt : Int -> Rows id -> Maybe (Row id)
rowAt i r =
    Array.get i r.rows


rowIndex : String -> Rows id -> Maybe Int
rowIndex key r =
    Dict.get key r.positions


{-| The row of the failure under a node, when it is on screen.
-}
failureIndex : String -> Rows id -> Maybe Int
failureIndex parent r =
    Dict.get parent r.failures



-- MOVES


{-| The next row after `from` (towards the end for `1`, the start for `-1`) that
the predicate accepts.
-}
seek : (Row id -> Bool) -> Int -> Int -> Rows id -> Maybe Int
seek accept step from r =
    case Array.get from r.rows of
        Nothing ->
            Nothing

        Just row ->
            if accept row then
                Just from

            else
                seek accept step (from + step) r


nextRow : (Row id -> Bool) -> Int -> Rows id -> Maybe Int
nextRow accept from r =
    seek accept 1 (from + 1) r


previousRow : (Row id -> Bool) -> Int -> Rows id -> Maybe Int
previousRow accept from r =
    seek accept -1 (from - 1) r


lastRow : (Row id -> Bool) -> Rows id -> Maybe Int
lastRow accept r =
    seek accept -1 (Array.length r.rows - 1) r


{-| The row of the parent of the node at a row, when it is on screen.
-}
parentRow : Int -> Rows id -> Maybe Int
parentRow from r =
    case Array.get from r.rows of
        Just (NodeRow row) ->
            row.entry.parent |> Maybe.andThen (\parent -> rowIndex parent r)

        Just (LoadingRow { parent }) ->
            rowIndex parent r

        Just (FailedRow { parent }) ->
            rowIndex parent r

        Nothing ->
            Nothing
