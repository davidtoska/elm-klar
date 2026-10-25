module Klar.Picking exposing
    ( Node, leaf, branch, lazy, fromFlat, withDescription, withIcon, withKeywords, disabled
    , key, id, label, description, icon, keywords, isDisabled, children
    )

{-| The nodes of a hierarchy that [Klar.TreeSelect](Klar-TreeSelect) and
[Klar.Cascader](Klar-Cascader) choose from, with ids of your own type (a
`RegionId`, a `ProductId`, plain text ...) that a [Klar.Ids](Klar-Ids) writes as
keys. The components give your ids back as they are, so you never write the way
back from a key to an id.

Use when: you build the nodes for `Klar.TreeSelect` or `Klar.Cascader`, from nested data or from flat rows that name their parent (`fromFlat`).
Do not use when: you show a hierarchy on the page itself with open and closed branches (as `Klar.Tree`, which has its own nodes), or the items have no hierarchy (as the options of `Klar.Select`, `Klar.MultiSelect` and `Klar.Transfer`).

    import Klar.Ids as Ids exposing (Ids)
    import Klar.Picking as Picking
    import Klar.Remote as Remote exposing (Remote(..))


    -- how a RegionId is written as a key, once for the pickers
    regionIds : Ids RegionId
    regionIds =
        Ids.make { toKey = RegionId.toString, fromKey = RegionId.fromString }

    -- a hierarchy: Europe holds Oslo, and the zones of Bergen come from the backend
    regions : Remote (List Zone) -> List (Picking.Node RegionId)
    regions bergenZones =
        [ Picking.branch regionIds
            europe
            "Europe"
            [ Picking.leaf regionIds oslo "Oslo" |> Picking.withDescription "OSL"
            , Picking.lazy regionIds bergen "Bergen" (Remote.map (List.map zoneNode) bergenZones)
            ]
        ]

    -- the nodes go to the field
    TreeSelect.view RegionMsg [ TreeSelect.label "Region", TreeSelect.nodes (regions model.bergenZones) ] model.region

A backend that sends the hierarchy as flat rows with a parent id needs no code of
your own: `Picking.fromFlat` builds the nodes.

Nodes are plain data that you build from your own data on every render; the
components only remember what the user did (which nodes are open, which are
chosen), by key. A node has the id you gave it, a label that the user sees and
searches, and optionally a description, an icon and extra search words. Its
children are a `Remote` list: a `leaf` has none, a `branch` has the list you give
it, and a `lazy` node has children that come from the backend, shown as loading,
failed or loaded. Only the nodes of an open branch are drawn.

Every id must be unique in the whole tree, not only among its siblings, and its
key (what its `Ids` makes of it) must be different for different ids. A node
whose key was already used by an earlier node is left out of the choice list.

The ids are a [Klar.Ids](Klar-Ids), the same value the table and the tree of that id
type take. The picking components keep the ids themselves next to their keys and use
only `toKey`, so they cannot restore a value from keys alone (a saved view that stores
keys): store your own ids and give them to `TreeSelect.setValues`, `Cascader.setValue`
or `Transfer.setValues`.

The functions that read a node (`key`, `id`, `label`, `description`, `icon`,
`keywords`, `isDisabled`, `children`) are for building your own components on these
nodes, or one tree from another (the components of this package use them for
exactly that); an application rarely needs them.


# Nodes

@docs Node, leaf, branch, lazy, fromFlat, withDescription, withIcon, withKeywords, disabled


# Reading a node

@docs key, id, label, description, icon, keywords, isDisabled, children

-}

import Dict exposing (Dict)
import Klar.Icon exposing (Icon)
import Klar.Ids as Ids exposing (Ids)
import Klar.Remote as Remote exposing (Remote)
import Set exposing (Set)



-- NODES


{-| One node of a hierarchy: a region, a warehouse, a category. Make it with
`leaf`, `branch` or `lazy`, and add a description, an icon or search words with
the `with...` functions. A node is plain data and the type is opaque, so that
it can get more settings without breaking anything.
-}
type Node id
    = Node (Data id)


type alias Data id =
    { key : String
    , id : id
    , label : String
    , description : Maybe String
    , icon : Maybe Icon
    , keywords : List String
    , disabled : Bool
    , children : Remote (List (Node id))
    }


make : Ids id -> id -> String -> Remote (List (Node id)) -> Node id
make ids nodeId nodeLabel givenKids =
    Node
        { key = Ids.toKey ids nodeId
        , id = nodeId
        , label = nodeLabel
        , description = Nothing
        , icon = Nothing
        , keywords = []
        , disabled = False
        , children = givenKids
        }


{-| A node without children. The arguments are the ids of your application, the
id of the node and its label.

    Picking.leaf regionIds oslo "Oslo"

The label is what the user sees and searches. It is written on one line and cut
with an ellipsis when it does not fit (the whole label is the tooltip).

-}
leaf : Ids id -> id -> String -> Node id
leaf node nodeId nodeLabel =
    make node nodeId nodeLabel (Remote.Loaded [])


{-| A node with children: the ids, the id and the label of the node, and its
child nodes. A branch with an empty list of children looks like a leaf.

    Picking.branch regionIds europe "Europe" [ Picking.leaf regionIds oslo "Oslo" ]

-}
branch : Ids id -> id -> String -> List (Node id) -> Node id
branch node nodeId nodeLabel kids =
    make node nodeId nodeLabel (Remote.Loaded kids)


{-| A node whose children come from the backend. Until the user opens it, the
`Remote` is `NotAsked`; while the request is on its way you pass `Loading`, and
then `Loaded` with the children or `Failed` with a problem. A lazy node always
looks like something that can be opened, until its children arrive empty.

    Picking.lazy regionIds bergen "Bergen" model.bergenZones

The component tells you which node was opened first (`TreeSelect.loadRequests`,
`Cascader.loadRequests`); you set its children to `Loading`, fetch them, and put
the answer in the node the next time you build the tree. Children that are `Kept`
stay on screen and can be chosen: while they are refreshed the branch is marked
busy, and when the last refresh failed a row under the branch says "Old data from
14:05" with a "Try again" button (`onRetryChildren`).

-}
lazy : Ids id -> id -> String -> Remote (List (Node id)) -> Node id
lazy =
    make


{-| The nodes of a hierarchy that comes as flat rows, each naming its parent: the
way most backends send one (`{ id, parentId, name }`). Give the ids, how to read
the id, the parent (`Nothing` at the top) and the label of a row, and `decorate`
for what more a node gets (`\_ node -> node` for nothing).

    Picking.fromFlat warehouseIds
        { id = .id
        , parent = .parentId
        , label = .name
        , decorate = \row node -> Picking.withDescription row.code node
        }
        rows

Siblings keep the order of the rows; a row with children is a `branch` and one
without a `leaf`. Nothing is dropped quietly: a row whose parent is not among the
rows is put at the top level, and so is a row in a loop of parents (a row that is
its own parent or ancestor), with the loop cut where it closes. Rows with the same
id are the same node to the components (the first one wins, see above). The rows
are grouped once, so a hierarchy of many thousands of rows is quick.

-}
fromFlat :
    Ids id
    -> { id : row -> id, parent : row -> Maybe id, label : row -> String, decorate : row -> Node id -> Node id }
    -> List row
    -> List (Node id)
fromFlat ids config rows =
    let
        keyOf row =
            Ids.toKey ids (config.id row)

        known =
            Set.fromList (List.map keyOf rows)

        parentKey row =
            case config.parent row of
                Just parent ->
                    let
                        k =
                            Ids.toKey ids parent
                    in
                    if Set.member k known then
                        Just k

                    else
                        Nothing

                Nothing ->
                    Nothing

        -- the children of each parent, in the order of the rows
        byParent =
            List.foldr
                (\row dict ->
                    case parentKey row of
                        Just p ->
                            Dict.update p (\kids -> Just (row :: Maybe.withDefault [] kids)) dict

                        Nothing ->
                            dict
                )
                Dict.empty
                rows

        ( fromTop, visited ) =
            buildAll ids config byParent (List.filter (\row -> parentKey row == Nothing) rows) Set.empty

        -- rows in a loop of parents are never reached from the top: they are put there
        ( fromLoops, _ ) =
            buildAll ids config byParent (List.filter (\row -> not (Set.member (keyOf row) visited)) rows) visited
    in
    fromTop ++ fromLoops


buildAll :
    Ids id
    -> { id : row -> id, parent : row -> Maybe id, label : row -> String, decorate : row -> Node id -> Node id }
    -> Dict String (List row)
    -> List row
    -> Set String
    -> ( List (Node id), Set String )
buildAll ids config byParent rows visited =
    let
        ( reversed, final ) =
            List.foldl
                (\row ( built, seen ) ->
                    case buildOne ids config byParent row seen of
                        Just ( node, after ) ->
                            ( node :: built, after )

                        Nothing ->
                            ( built, seen )
                )
                ( [], visited )
                rows
    in
    ( List.reverse reversed, final )


buildOne :
    Ids id
    -> { id : row -> id, parent : row -> Maybe id, label : row -> String, decorate : row -> Node id -> Node id }
    -> Dict String (List row)
    -> row
    -> Set String
    -> Maybe ( Node id, Set String )
buildOne ids config byParent row visited =
    let
        rowId =
            config.id row

        k =
            Ids.toKey ids rowId
    in
    if Set.member k visited then
        Nothing

    else
        let
            ( kids, after ) =
                buildAll ids config byParent (Dict.get k byParent |> Maybe.withDefault []) (Set.insert k visited)

            node =
                if List.isEmpty kids then
                    leaf ids rowId (config.label row)

                else
                    branch ids rowId (config.label row) kids
        in
        Just ( config.decorate row node, after )


{-| A short secondary text, shown dimmed after the label and searched too: a
code, a city, a unit.

    Picking.leaf regionIds oslo "Oslo" |> Picking.withDescription "OSL"

-}
withDescription : String -> Node id -> Node id
withDescription text (Node data) =
    Node { data | description = Just text }


{-| An icon drawn before the label of the node.
-}
withIcon : Icon -> Node id -> Node id
withIcon icon_ (Node data) =
    Node { data | icon = Just icon_ }


{-| Extra words that also match the node when the user searches: synonyms, codes,
old names. They are searched but never shown. Calling it again adds to the words.
-}
withKeywords : List String -> Node id -> Node id
withKeywords words (Node data) =
    Node { data | keywords = data.keywords ++ words }


{-| A node that is shown but cannot be chosen. Its children are not affected: the
user can still open it and choose what is inside, so a disabled branch works as a
heading. In a field that lets the user check boxes, checking a parent checks the
nodes inside it that are not disabled.
-}
disabled : Node id -> Node id
disabled (Node data) =
    Node { data | disabled = True }



-- READING


{-| The key of the node's id (what `toKey` made of it when the node was built).
-}
key : Node id -> String
key (Node data) =
    data.key


{-| The id of the node, as you gave it.
-}
id : Node id -> id
id (Node data) =
    data.id


{-| The label of the node.
-}
label : Node id -> String
label (Node data) =
    data.label


{-| The description of the node, if it has one.
-}
description : Node id -> Maybe String
description (Node data) =
    data.description


{-| The icon of the node, if it has one.
-}
icon : Node id -> Maybe Icon
icon (Node data) =
    data.icon


{-| The extra search words of the node.
-}
keywords : Node id -> List String
keywords (Node data) =
    data.keywords


{-| Whether the node was made `disabled`.
-}
isDisabled : Node id -> Bool
isDisabled (Node data) =
    data.disabled


{-| The children of the node as a `Remote`: `Loaded []` for a leaf, the list for
a branch, and for a lazy node the `Remote` as you gave it (`Kept` included).
-}
children : Node id -> Remote (List (Node id))
children (Node data) =
    data.children
