# Klar.Picking

The vocabulary that Klar.TreeSelect, Klar.Cascader and Klar.Transfer share.

Import: `import Klar.Picking as Picking` | Group: Choosing

Types: `Node`

## Signatures

```elm
-- Nodes
type Node id  -- opaque: no constructors are exposed
leaf : Ids.Ids id -> id -> String -> Node id
branch : Ids.Ids id -> id -> String -> List (Node id) -> Node id
lazy : Ids.Ids id -> id -> String -> Remote.Remote (List (Node id)) -> Node id
withDescription : String -> Node id -> Node id
withIcon : Icon.Icon -> Node id -> Node id
withKeywords : List String -> Node id -> Node id
disabled : Node id -> Node id

-- Reading a node
key : Node id -> String
id : Node id -> id
label : Node id -> String
description : Node id -> Maybe String
icon : Node id -> Maybe Icon.Icon
keywords : Node id -> List String
isDisabled : Node id -> Bool
children : Node id -> Remote.Remote (List (Node id))
```

## Documentation

The vocabulary that [Klar.TreeSelect](Klar.TreeSelect.md),
[Klar.Cascader](Klar.Cascader.md) and [Klar.Transfer](Klar.Transfer.md) share: how your
own id type (a `RegionId`, a `ProductId`, plain text ...) is written as a key,
and the nodes of a hierarchy to choose from. The components give your ids back
as they are, so you never write the way back from a key to an id.

Use when: you build the nodes for `Klar.TreeSelect`, `Klar.Cascader` or `Klar.Transfer`, or need one way to write your ids as keys.
Do not use when: you show a hierarchy on the page itself with open and closed branches (as `Klar.Tree`, which has its own nodes).

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

The ids are a [Klar.Ids](Klar.Ids.md), the same value the table and the tree of that id
type take. The picking components keep the ids themselves next to their keys and use
only `toKey`, so they cannot restore a value from keys alone (a saved view that stores
keys): store your own ids and give them to `TreeSelect.setValues`, `Cascader.setValue`
or `Transfer.setValues`.

The functions that read a node (`key`, `id`, `label`, `description`, `icon`,
`keywords`, `isDisabled`, `children`) are for building your own components on these
nodes, or one tree from another (the components of this package use them for
exactly that); an application rarely needs them.

## Nodes

### `Node`

```elm
type Node id  -- opaque: no constructors are exposed
```

One node of a hierarchy: a region, a warehouse, a category. Make it with
`leaf`, `branch` or `lazy`, and add a description, an icon or search words with
the `with...` functions. A node is plain data and the type is opaque, so that
it can get more settings without breaking anything.

### `leaf`

```elm
leaf : Ids.Ids id -> id -> String -> Node id
```

A node without children. The arguments are the ids of your application, the
id of the node and its label.

    Picking.leaf regionIds oslo "Oslo"

The label is what the user sees and searches. It is written on one line and cut
with an ellipsis when it does not fit (the whole label is the tooltip).

### `branch`

```elm
branch : Ids.Ids id -> id -> String -> List (Node id) -> Node id
```

A node with children: the ids, the id and the label of the node, and its
child nodes. A branch with an empty list of children looks like a leaf.

    Picking.branch regionIds europe "Europe" [ Picking.leaf regionIds oslo "Oslo" ]

### `lazy`

```elm
lazy : Ids.Ids id -> id -> String -> Remote.Remote (List (Node id)) -> Node id
```

A node whose children come from the backend. Until the user opens it, the
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

### `withDescription`

```elm
withDescription : String -> Node id -> Node id
```

A short secondary text, shown dimmed after the label and searched too: a
code, a city, a unit.

    Picking.leaf regionIds oslo "Oslo" |> Picking.withDescription "OSL"

### `withIcon`

```elm
withIcon : Icon.Icon -> Node id -> Node id
```

An icon drawn before the label of the node.

### `withKeywords`

```elm
withKeywords : List String -> Node id -> Node id
```

Extra words that also match the node when the user searches: synonyms, codes,
old names. They are searched but never shown. Calling it again adds to the words.

### `disabled`

```elm
disabled : Node id -> Node id
```

A node that is shown but cannot be chosen. Its children are not affected: the
user can still open it and choose what is inside, so a disabled branch works as a
heading. In a field that lets the user check boxes, checking a parent checks the
nodes inside it that are not disabled.

## Reading a node

### `key`

```elm
key : Node id -> String
```

The key of the node's id (what `toKey` made of it when the node was built).

### `id`

```elm
id : Node id -> id
```

The id of the node, as you gave it.

### `label`

```elm
label : Node id -> String
```

The label of the node.

### `description`

```elm
description : Node id -> Maybe String
```

The description of the node, if it has one.

### `icon`

```elm
icon : Node id -> Maybe Icon.Icon
```

The icon of the node, if it has one.

### `keywords`

```elm
keywords : Node id -> List String
```

The extra search words of the node.

### `isDisabled`

```elm
isDisabled : Node id -> Bool
```

Whether the node was made `disabled`.

### `children`

```elm
children : Node id -> Remote.Remote (List (Node id))
```

The children of the node as a `Remote`: `Loaded []` for a leaf, the list for
a branch, and for a lazy node the `Remote` as you gave it (`Kept` included).
