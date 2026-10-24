module Klar.Picking exposing
    ( Ids, ids, stringIds, intIds, toKey
    , Node, leaf, branch, lazy, withDescription, withIcon, withKeywords, disabled
    , key, id, label, description, icon, keywords, isDisabled, children
    )

{-| The vocabulary that [Klar.TreeSelect](Klar-TreeSelect),
[Klar.Cascader](Klar-Cascader) and [Klar.Transfer](Klar-Transfer) share: how your
own id type (a `RegionId`, a `ProductId`, plain text ...) is written as a key,
and the nodes of a hierarchy to choose from. The components give your ids back
as they are, so you never write the way back from a key to an id.

Use when: you build the nodes for `Klar.TreeSelect`, `Klar.Cascader` or `Klar.Transfer`, or need one way to write your ids as keys.
Do not use when: you show a hierarchy on the page itself with open and closed branches (as `Klar.Tree`, which has its own nodes).

    import Klar.Picking as Picking
    import Klar.Remote as Remote exposing (Remote(..))


    -- how a RegionId is written as a key, once for the pickers
    regionIds : Picking.Ids RegionId
    regionIds =
        Picking.ids RegionId.toString

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

Nodes are plain data that you build from your own data on every render; the
components only remember what the user did (which nodes are open, which are
chosen), by key. A node has the id you gave it, a label that the user sees and
searches, and optionally a description, an icon and extra search words. Its
children are a `Remote` list: a `leaf` has none, a `branch` has the list you give
it, and a `lazy` node has children that come from the backend, shown as loading,
failed or loaded. Only the nodes of an open branch are drawn.

Every id must be unique in the whole tree, not only among its siblings, and its
key (what `ids` was told to make of it) must be different for different ids. A node
whose key was already used by an earlier node is left out of the choice list.

`Picking.ids` takes only the function that writes an id as a key. That differs from
`Tree.nodeIds` and `Table.rowIds`, which also ask for the way back from a key to an
id (`fromKey`), and is the same as `SideNav.keys`: the picking components keep the
ids themselves next to their keys, so nothing is ever read back from a key, and an
application with an opaque id type does not have to write a parser for it. The
price is that these components cannot restore a value from keys alone (a saved view
that stores keys): store your own ids and give them to `TreeSelect.setValues`,
`Cascader.setValue` or `Transfer.setValues`.

The functions that read a node (`key`, `id`, `label`, `description`, `icon`,
`keywords`, `isDisabled`, `children`) are for building your own components on these
nodes, or one tree from another (the components of this package use them for
exactly that); an application rarely needs them.


# Ids

@docs Ids, ids, stringIds, intIds, toKey


# Nodes

@docs Node, leaf, branch, lazy, withDescription, withIcon, withKeywords, disabled


# Reading a node

@docs key, id, label, description, icon, keywords, isDisabled, children

-}

import Klar.Icon exposing (Icon)
import Klar.Internal.Freshness as Freshness
import Klar.Remote as Remote exposing (Remote)



-- IDS


{-| How the id type of your nodes (a `RegionId`, a `ProductId`, plain text ...) is
written as a key. Declare one value for each kind of id, once, and pass it to the
node constructors and to the functions that set ids from your code
(`TreeSelect.setValues`, `Cascader.setValue`, `Transfer.setValues` ...). The
components are typed by the id (`TreeSelect.State TreeSelect.Multiple RegionId`),
so a field for regions cannot be asked about product ids.

    regionIds : Picking.Ids RegionId
    regionIds =
        Picking.ids RegionId.toString

The key is what the components use to look an id up quickly, so it must give
every id its own text. The ids come back as you gave them: nothing is converted
back from a key.

-}
type Ids id
    = Ids (id -> String)


{-| Makes the `Ids` of an id type from the function that writes an id as a key,
see there.
-}
ids : (id -> String) -> Ids id
ids =
    Ids


{-| Ids that are plain text (a code, a SKU), used as they are.
-}
stringIds : Ids String
stringIds =
    Ids identity


{-| Ids that are whole numbers (a database id).
-}
intIds : Ids Int
intIds =
    Ids String.fromInt


{-| The key of an id: what `ids` was told to make of it.

    Picking.toKey Picking.intIds 42 --> "42"

-}
toKey : Ids id -> id -> String
toKey (Ids write) =
    write



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
make (Ids write) nodeId nodeLabel givenKids =
    let
        -- children that are `Kept` are shown as they are; the pickers have no room for a marker
        kids =
            Tuple.first (Freshness.settle givenKids)
    in
    Node
        { key = write nodeId
        , id = nodeId
        , label = nodeLabel
        , description = Nothing
        , icon = Nothing
        , keywords = []
        , disabled = False
        , children = kids
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
(refreshed, or old after a failed refresh) are shown as if they were `Loaded`.

-}
lazy : Ids id -> id -> String -> Remote (List (Node id)) -> Node id
lazy =
    make


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
a branch, and whatever state the backend request is in for a lazy node.
-}
children : Node id -> Remote (List (Node id))
children (Node data) =
    data.children
