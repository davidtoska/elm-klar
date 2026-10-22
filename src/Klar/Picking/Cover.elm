module Klar.Picking.Cover exposing
    ( Check(..)
    , Cover
    , Derived
    , check
    , derive
    , dropNested
    , isCovered
    , leaves
    , normalize
    , stateOf
    , toggle
    , uncheck
    , unitsOf
    )

{-| The meaning of a checked box in a tree of choices.

A **cover** is a set of keys. A key in the cover stands for the node and
everything below it, so checking "Europe" puts one key in the value, also when
Europe holds thousands of warehouses and some of them are not loaded yet. The
cover is kept in its shortest form:

  - no member has another member above it;
  - when every child of a node is a member (and nothing inside the node is
    disabled), the children are replaced by the node;
  - a node that is disabled, or has a disabled node below it, is never a member:
    checking it checks the nodes inside it that are not disabled, one by one (its
    "units"), so a disabled node is never part of what was chosen.

The state of a box is derived from the cover: `Checked` when the node or a node
above it is a member (or, for a node that cannot be a member, when all its units
are checked), `Partial` when something below it is checked, otherwise
`Unchecked`.

Not for application code.

-}

import Dict exposing (Dict)
import Klar.Picking.Index as Index exposing (Entry, Index, Kids(..))
import Set exposing (Set)


type Check
    = Unchecked
    | Partial
    | Checked


type alias Cover =
    Set String


{-| What the cover says about the nodes of one tree: the ancestors of the
members (`partial`), the nodes that are not members but have all their children
checked (`complete`, which only happens for a cover that was set from the code
and is not in its shortest form), and the state of every node that cannot be a
member itself. Work it out again when the cover or the tree changes, and not on
every draw.
-}
type alias Derived =
    { partial : Set String
    , complete : Set String
    , groups : Dict String Check
    }


{-| A node that can be a member of the cover: not disabled, and no disabled node
below it.
-}
isClean : Entry id -> Bool
isClean entry =
    not entry.disabled && not entry.blocked


{-| The largest nodes that can be members and lie inside (or are) the node:
the node itself when it is clean, otherwise the units of its children.
-}
unitsOf : Index id -> String -> List String
unitsOf index key =
    case Index.get key index of
        Nothing ->
            []

        Just entry ->
            if isClean entry then
                [ key ]

            else
                case entry.kids of
                    Kids keys ->
                        List.concatMap (unitsOf index) keys

                    _ ->
                        []


{-| Is the node a member, or below a member?
-}
isCovered : Index id -> Cover -> String -> Bool
isCovered index cover key =
    Set.member key cover || List.any (\a -> Set.member a cover) (Index.ancestors key index)


{-| Removes the members that lie below another member.
-}
dropNested : Index id -> Cover -> Cover
dropNested index cover =
    Set.filter (\key -> not (List.any (\a -> Set.member a cover) (Index.ancestors key index))) cover


derive : Index id -> Cover -> Derived
derive index cover =
    let
        partial =
            Set.foldl (\key found -> addAncestors index key found) Set.empty cover

        complete =
            completeNodes index cover partial

        groups =
            if Set.isEmpty cover then
                Dict.empty

            else
                List.foldl
                    (\key found ->
                        case Index.get key index of
                            Just entry ->
                                if isClean entry then
                                    found

                                else
                                    case groupState index cover partial complete found entry of
                                        Just state ->
                                            Dict.insert key state found

                                        Nothing ->
                                            found

                            Nothing ->
                                found
                    )
                    Dict.empty
                    (List.reverse index.order)
    in
    { partial = partial, complete = complete, groups = groups }


{-| The clean nodes that are not members but have every child checked (a member,
or complete themselves): the deepest first, so that the children are known.
-}
completeNodes : Index id -> Cover -> Set String -> Set String
completeNodes index cover partial =
    partial
        |> Set.toList
        |> List.filterMap (\key -> Index.get key index)
        |> List.sortBy (\entry -> negate entry.depth)
        |> List.foldl
            (\entry found ->
                case entry.kids of
                    Kids keys ->
                        if isClean entry && not (Set.member entry.key cover) && List.all (\k -> Set.member k cover || Set.member k found) keys then
                            Set.insert entry.key found

                        else
                            found

                    _ ->
                        found
            )
            Set.empty


addAncestors : Index id -> String -> Set String -> Set String
addAncestors index key found =
    case Index.get key index |> Maybe.andThen .parent of
        Just parent ->
            if Set.member parent found then
                found

            else
                addAncestors index parent (Set.insert parent found)

        Nothing ->
            found


{-| The state of a node that cannot be a member, from the states of its
children. `Nothing` when nothing below it can be chosen.
-}
groupState : Index id -> Cover -> Set String -> Set String -> Dict String Check -> Entry id -> Maybe Check
groupState index cover partial complete groups entry =
    case entry.kids of
        Kids keys ->
            let
                states =
                    List.filterMap (childState index cover partial complete groups) keys
            in
            if List.isEmpty states then
                Nothing

            else if List.all (\s -> s == Checked) states then
                Just Checked

            else if List.any (\s -> s /= Unchecked) states then
                Just Partial

            else
                Just Unchecked

        _ ->
            Nothing


childState : Index id -> Cover -> Set String -> Set String -> Dict String Check -> String -> Maybe Check
childState index cover partial complete groups key =
    if Set.member key cover || Set.member key complete then
        Just Checked

    else
        case Index.get key index of
            Just entry ->
                if isClean entry then
                    if Set.member key partial then
                        Just Partial

                    else
                        Just Unchecked

                else
                    Dict.get key groups

            Nothing ->
                Nothing


stateOf : Index id -> Cover -> Derived -> String -> Check
stateOf index cover derived key =
    if isCovered index cover key || Set.member key derived.complete then
        Checked

    else
        case Index.get key index of
            Just entry ->
                if isClean entry then
                    if Set.member key derived.partial then
                        Partial

                    else
                        Unchecked

                else
                    Dict.get key derived.groups |> Maybe.withDefault Unchecked

            Nothing ->
                Unchecked


{-| The cover in its shortest form: no member inside another, and the children
of a node that can be a member replaced by the node.
-}
normalize : Index id -> Cover -> Cover
normalize index cover0 =
    let
        cover =
            dropNested index cover0

        parents =
            Set.foldl
                (\key found ->
                    case Index.get key index |> Maybe.andThen .parent of
                        Just parent ->
                            Set.insert parent found

                        Nothing ->
                            found
                )
                Set.empty
                cover
    in
    collapse index cover parents


{-| Checks the node: everything below it is now chosen. A node that is covered
already stays as it is.
-}
check : Index id -> Cover -> String -> Cover
check index cover0 key =
    let
        cover =
            dropNested index cover0
    in
    if isCovered index cover key then
        cover

    else
        let
            without =
                Set.filter (\member -> not (Index.isAncestorOf key member index)) (Set.remove key cover)

            units =
                unitsOf index key

            added =
                List.foldl Set.insert without units

            parents =
                units
                    |> List.filterMap (\unit -> Index.get unit index |> Maybe.andThen .parent)
                    |> Set.fromList
        in
        collapse index added parents


{-| Replaces the children of a node by the node, when all of them are members
and the node can be one; then does the same one level up. `pending` are the
nodes to look at.
-}
collapse : Index id -> Cover -> Set String -> Cover
collapse index cover pending =
    if Set.isEmpty pending then
        cover

    else
        let
            ( covered, next ) =
                Set.foldl
                    (\key ( current, up ) ->
                        case Index.get key index of
                            Just entry ->
                                case entry.kids of
                                    Kids keys ->
                                        if isClean entry && List.all (\k -> Set.member k current) keys then
                                            ( List.foldl Set.remove current keys |> Set.insert key
                                            , case entry.parent of
                                                Just parent ->
                                                    Set.insert parent up

                                                Nothing ->
                                                    up
                                            )

                                        else
                                            ( current, up )

                                    _ ->
                                        ( current, up )

                            Nothing ->
                                ( current, up )
                    )
                    ( cover, Set.empty )
                    pending
        in
        collapse index covered next


{-| Unchecks the node: nothing below it is chosen any more. When the node is
only chosen because a node above it is, that node is split into the nodes that
stay chosen.
-}
uncheck : Index id -> Cover -> String -> Cover
uncheck index cover0 key =
    let
        cover =
            dropNested index cover0
    in
    if Set.member key cover then
        Set.remove key cover

    else
        case coveringAncestor index cover key of
            Just top ->
                split index cover top key

            Nothing ->
                Set.filter (\member -> not (Index.isAncestorOf key member index)) cover


coveringAncestor : Index id -> Cover -> String -> Maybe String
coveringAncestor index cover key =
    Index.ancestors key index
        |> List.filter (\a -> Set.member a cover)
        |> List.head


{-| Removes `top` from the cover and adds everything that was inside it except
the node `key` and what is below it.
-}
split : Index id -> Cover -> String -> String -> Cover
split index cover top key =
    let
        path =
            Index.pathTo key index
                |> dropUntil top

        -- the nodes on the way from `top` down to `key`, with the child that
        -- is on the way for each of them
        steps =
            List.map2 Tuple.pair path (List.drop 1 path)

        others ( parent, onTheWay ) =
            case Index.get parent index of
                Just entry ->
                    case entry.kids of
                        Kids keys ->
                            keys |> List.filter (\k -> k /= onTheWay) |> List.concatMap (unitsOf index)

                        _ ->
                            []

                Nothing ->
                    []
    in
    List.foldl
        (\step current -> List.foldl Set.insert current (others step))
        (Set.remove top cover)
        steps


dropUntil : String -> List String -> List String
dropUntil first keys =
    case keys of
        [] ->
            []

        k :: rest ->
            if k == first then
                keys

            else
                dropUntil first rest


{-| Checks the node, or unchecks it when it is checked completely.
-}
toggle : Index id -> Cover -> Derived -> String -> Cover
toggle index cover derived key =
    case stateOf index cover derived key of
        Checked ->
            uncheck index cover key

        _ ->
            check index cover key


{-| The members written out as the nodes that cannot be split further, in the
order of the tree: every node below a member that has no children we know of
(a leaf, or a lazy node that is not loaded), unless it is disabled. Members that
are not in the tree are kept as they are, after the others.
-}
leaves : Index id -> Cover -> List String
leaves index cover =
    let
        known =
            leavesOf index cover index.roots

        unknown =
            Set.toList cover |> List.filter (\key -> Index.get key index == Nothing)
    in
    known ++ unknown


leavesOf : Index id -> Cover -> List String -> List String
leavesOf index cover keys =
    List.concatMap
        (\key ->
            if Set.member key cover then
                allLeaves index key

            else
                case Index.get key index |> Maybe.map .kids of
                    Just (Kids below) ->
                        leavesOf index cover below

                    _ ->
                        []
        )
        keys


allLeaves : Index id -> String -> List String
allLeaves index key =
    case Index.get key index of
        Just entry ->
            case entry.kids of
                Kids keys ->
                    List.concatMap (allLeaves index) keys

                _ ->
                    if entry.disabled then
                        []

                    else
                        [ key ]

        Nothing ->
            []
