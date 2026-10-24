# Klar.Tree

A tree view for hierarchies: regions and warehouses, folders, product categories, code lists.

Import: `import Klar.Tree as Tree` | Group: Tables and lists

Types: `Ids`, `Msg`, `Node`, `State`, `Attribute`

## Signatures

```elm
-- Views
view : (Msg -> msg) -> List (Attribute id msg) -> State id -> List (Node id) -> Html msg
viewRemote :
    (Msg -> msg)
    -> List (Attribute id msg)
    -> State id
    -> Remote.Remote (List (Node id))
    -> Html msg

-- Nodes
type Node id  -- opaque: no constructors are exposed
leaf : Ids id -> id -> String -> Node id
branch : Ids id -> id -> String -> List (Node id) -> Node id
lazy : Ids id -> id -> String -> Remote.Remote (List (Node id)) -> Node id
unloaded : Ids id -> id -> String -> Node id
withIcon : Icon.Icon -> Node id -> Node id
withCount : Int -> Node id -> Node id
withBadge : Theme.Tone -> String -> Node id -> Node id
withHint : String -> Node id -> Node id
disabled : Node id -> Node id

-- State and messages
type State id  -- opaque: no constructors are exposed
type Msg  -- opaque: no constructors are exposed
init : String -> State id
update : Msg -> State id -> ( State id, Cmd Msg )
type Ids id  -- opaque: no constructors are exposed
nodeIds : { toKey : id -> String, fromKey : String -> Maybe id } -> Ids id
stringIds : Ids String
intIds : Ids Int

-- Open and closed
expanded : Ids id -> State id -> List id
isExpanded : Ids id -> id -> State id -> Bool
setExpanded : Ids id -> List id -> State id -> State id
expand : Ids id -> id -> State id -> State id
collapse : Ids id -> id -> State id -> State id
expandAll : List (Node id) -> State id -> State id
collapseAll : State id -> State id
newlyExpanded : Ids id -> State id -> State id -> List id

-- Selection and checkboxes
selected : Ids id -> State id -> List id
selectedId : Ids id -> State id -> Maybe id
select : Ids id -> id -> State id -> State id
setSelected : Ids id -> List id -> State id -> State id
checked : Ids id -> State id -> List id
setChecked : Ids id -> List id -> State id -> State id
clearChecked : State id -> State id

-- Focus and filter
focused : Ids id -> State id -> Maybe id
focusNode : Ids id -> State id -> id -> Cmd Msg
query : State id -> String
setQuery : String -> State id -> State id

-- Lazy loading
loadRequests : Ids id -> Msg -> List id
onLoadChildren : (id -> msg) -> Attribute id msg
onRetry : (id -> msg) -> Attribute id msg
onReload : msg -> Attribute id msg

-- Attributes
type Attribute id msg  -- opaque: no constructors are exposed
ariaLabel : String -> Attribute id msg
multiSelect : Attribute id msg
allowEmptySelection : Attribute id msg
checkboxes : Attribute id msg
filterBox : Attribute id msg
filterPlaceholder : String -> Attribute id msg
onActivate : (id -> msg) -> Attribute id msg
compact : Attribute id msg
maxHeight : Int -> Attribute id msg
maxChildren : Int -> Attribute id msg
emptyText : String -> Attribute id msg
locale : Locale.Locale -> Attribute id msg
settings : Settings.Settings -> Attribute id msg
```

## Documentation

A tree view for hierarchies: regions and warehouses, folders, product
categories, code lists.

Use when: a hierarchy is shown on the page itself, with open and closed branches.
Do not use when: the user picks a node in a form field (as `Klar.TreeSelect`).
Quick path: `init`, `update`, `view`, `selected`

It follows the WAI-ARIA tree pattern (`tree`,
`treeitem`, `group`, `aria-expanded`, `aria-selected`, `aria-level`), keeps one
tab stop for the whole tree and is fully usable from the keyboard.

    import Klar.Theme exposing (Tone(..))
    import Klar.Tree as Tree

    -- model
    { tree : Tree.State String }    -- Tree.init "warehouse-tree"

    -- update
    TreeMsg m ->
        let
            ( tree, cmd ) =
                Tree.update m model.tree
        in
        ( { model | tree = tree }, Cmd.map TreeMsg cmd )

    -- view
    Tree.view TreeMsg
        [ Tree.ariaLabel "Warehouses", Tree.filterBox ]
        model.tree
        [ Tree.branch Tree.stringIds "north" "Northern region"
            [ Tree.leaf Tree.stringIds "wh-3b" "Warehouse 3B" |> Tree.withCount 24
            , Tree.leaf Tree.stringIds "wh-4a" "Warehouse 4A" |> Tree.withBadge Warning "Closed"
            ]
        ]

Use a tree for data that is nested; for a flat list with columns use
[Klar.Table](Klar.Table.md), and for a few collapsible sections
[Klar.Accordion](Klar.Accordion.md).

Nodes are plain data (`leaf`, `branch`, `lazy`) that you build from your own
data on every render; the state only remembers what the user did: which nodes
are open, which are selected or checked, which has the focus, the filter text.
Read it with `selected`, `expanded`, `checked` and compare before and after an
update to react (`Tree.selected Tree.stringIds new /= Tree.selected Tree.stringIds old`). There are no
out-messages. The state refers to nodes by id, so every node id must be unique
in the whole tree.

Keyboard: `Tab` enters and leaves the tree. `Up` and `Down` move, `Right`
opens a closed node and then moves into it, `Left` closes an open node and then
moves to the parent, `Home` and `End` jump to the first and last visible node,
`Enter` calls `onActivate` (without it, `Enter` does what `Space` does), `Space`
selects (toggles in a `multiSelect` tree, checks in a tree with `checkboxes`)
and `*` opens all closed nodes on the current level. In a `multiSelect` tree
`Shift`+`Up` and `Shift`+`Down` extend the selection. Typing letters jumps to the
next visible node whose label starts with them. In the filter box, `Down` moves
into the tree and `Escape` clears the filter. With the mouse, a click selects, the
arrow in front of a node opens and closes it, and a double click activates (or,
without `onActivate`, opens or closes the node).

Selection: single by default (a tree that filters something else adds
`allowEmptySelection`, so that a click on the selected node clears it); `multiSelect`
allows `Ctrl`+click to add and
`Shift`+click for a range. With `checkboxes` every node has a tri-state
checkbox, and a click on a row toggles it: checking a parent checks everything
below it, and a parent with some children checked shows a dash. `checked`
returns the checked leaves. A node that is `disabled` can be neither selected
nor checked.

Filter: with `filterBox` the tree has a search field (or call `setQuery`). The
tree then shows the nodes whose label contains every word typed (case and
accents are ignored), with every ancestor of a match opened and the matching
text highlighted. Only nodes that are in your data are searched, so the children
of a lazy node that has not been loaded are not: for a lazy tree, watch `query`
(compare it before and after `update`), ask the backend for the matching nodes
with their ancestors and put them in your data, or load every branch first.
Nodes that the user opens or closes while a filter is active are forgotten when
the text changes.

Lazy loading: a `lazy` node carries a `Remote` of its children. When the user
opens one that is `NotAsked`, `loadRequests` on the message tells you which node
asked; set its children to `Loading`, fetch them, and put `Loaded` or `Failed`
in the node on the next render. The tree shows a spinner row while loading and a
short failure with a retry button (`onRetry`). The children of a lazy node may be
lazy nodes too. The tree keeps no copy of your nodes, so each level has its own
`Remote` in your model: store what was loaded by node id and build the nodes from
it in every `view`.

    TreeMsg m ->
        let
            ( tree, cmd ) =
                Tree.update m model.tree

            requests =
                Tree.loadRequests Tree.stringIds m
        in
        ( { model | tree = tree, regions = markLoading requests model.regions }
        , Cmd.batch (Cmd.map TreeMsg cmd :: List.map fetchChildren requests)
        )

Here `markLoading` sets the children of the requested nodes to `Loading` in your
data and `fetchChildren` starts the request for one node id; both are yours. If
the whole top level comes from the backend, give it to `viewRemote`.

Large trees: only open branches are rendered (with keyed nodes), and a branch
with more than `maxChildren` children (default 300) shows the first ones and a
"Show 300 more" row.

The built-in text (the filter box, "Loading ...", "No matches" and so on) is
English unless you set `locale`. Labels, hints, counts and badges come from you.

## Views

### `view`

```elm
view : (Msg -> msg) -> List (Attribute id msg) -> State id -> List (Node id) -> Html msg
```

The tree. The arguments are the wrapper for the tree's messages, the
attributes, the state and the top-level nodes.

    Tree.view TreeMsg [ Tree.ariaLabel "Warehouses" ] model.tree nodes

With no nodes the tree shows an empty state ("No nodes", or the `emptyText`), and
while a filter matches nothing it says "No matches".

### `viewRemote`

```elm
viewRemote :
    (Msg -> msg)
    -> List (Attribute id msg)
    -> State id
    -> Remote.Remote (List (Node id))
    -> Html msg
```

The same tree for a top level that comes from the backend. `Loaded` shows
the tree, `Failed` shows the problem with a "Try again" button (`onReload`), and
`NotAsked` and `Loading` show a skeleton.

    Tree.viewRemote TreeMsg [ Tree.onReload Reload ] model.tree model.regions

For the children of a single node use `lazy` instead.

## Nodes

### `Node`

```elm
type Node id  -- opaque: no constructors are exposed
```

One node of the tree. Build it with `leaf`, `branch`, `lazy` or `unloaded`,
and add an icon, a count, a badge or a hint with the `with...` functions. Nodes
are plain data: build them from your own data on every render.

### `leaf`

```elm
leaf : Ids id -> id -> String -> Node id
```

A node without children. The first `String` is the id, the second the label.

    Tree.leaf Tree.stringIds "wh-3b" "Warehouse 3B"

The id must be unique in the whole tree, not only among its siblings: it is how
the state remembers what is open, selected and checked, and what the callbacks
receive. Use a stable id from your data. The label is written on one line and
cut with an ellipsis when it does not fit (the full label is the tooltip).

### `branch`

```elm
branch : Ids id -> id -> String -> List (Node id) -> Node id
```

A node with children. The arguments are the id, the label and the child
nodes. The id must be unique in the whole tree.

    Tree.branch Tree.stringIds "north" "Northern region" [ Tree.leaf Tree.stringIds "wh-3b" "Warehouse 3B" ]

The children are only rendered while the node is open. A branch with an empty
list of children has no arrow and looks like a leaf; use `lazy` for children that
you do not have yet.

### `lazy`

```elm
lazy : Ids id -> id -> String -> Remote.Remote (List (Node id)) -> Node id
```

A node whose children come from the backend and are fetched when the node
is first opened. Until then the `Remote` is `NotAsked`; while the request is on
its way you pass `Loading`, and then `Loaded` with the children or `Failed`
with a problem.

    Tree.lazy Tree.stringIds "south" "Southern region" model.southWarehouses

See `loadRequests` for how to find out when to fetch. A lazy node always has an
arrow. When it is open the tree shows a spinner row while the children load, the
problem with a retry button when they failed (`onRetry`), and "No items" when
the list is empty.

### `unloaded`

```elm
unloaded : Ids id -> id -> String -> Node id
```

A node whose children have not been asked for yet: `lazy` with `NotAsked`.
The arguments are the id and the label.

    Tree.unloaded Tree.stringIds "south" "Southern region"

### `withIcon`

```elm
withIcon : Icon.Icon -> Node id -> Node id
```

An icon in front of the label.

    Tree.leaf Tree.stringIds "wh-3b" "Warehouse 3B" |> Tree.withIcon Icon.building

### `withCount`

```elm
withCount : Int -> Node id -> Node id
```

A muted number after the label: open orders, items in stock. It is written
with the thousands separator of the tree's `locale`.

### `withBadge`

```elm
withBadge : Theme.Tone -> String -> Node id -> Node id
```

A small colored label after the label, for a status. The `Tone` (from
[Klar.Theme](Klar.Theme.md)) sets the color, the `String` is the text.

    Tree.leaf Tree.stringIds "wh-4a" "Warehouse 4A" |> Tree.withBadge Warning "Closed"

### `withHint`

```elm
withHint : String -> Node id -> Node id
```

Muted text after the label: a code or a short note. It takes at most 40% of
the row and is cut with an ellipsis. On a row it comes before the count and the
badge.

### `disabled`

```elm
disabled : Node id -> Node id
```

A node that is shown but cannot be selected, checked or activated. It can
still be opened and closed, and its children are not affected.

## State and messages

### `State`

```elm
type State id  -- opaque: no constructors are exposed
```

What the user has done to a tree: which nodes are open, selected or checked,
which has the keyboard focus, the filter text. Make one with `init`, keep it in
your model, pass every `Msg` through `update` and read it with the functions
below. The tree itself (the nodes) is not part of it.

### `Msg`

```elm
type Msg  -- opaque: no constructors are exposed
```

A message of the tree. Wrap it in a constructor of your own message type
(`TreeMsg`), hand it to `update`, and give it to `loadRequests` to find out which
lazy nodes the user just opened.

### `init`

```elm
init : String -> State id
```

A tree state with nothing open, selected or checked. The `String` is a DOM
id prefix and must be unique on the page: the rows get ids that start with it,
and the filter box gets this id followed by `-filter`.

    Tree.init "warehouse-tree"

### `update`

```elm
update : Msg -> State id -> ( State id, Cmd Msg )
```

Handles opening and closing, selecting, checking, the filter box, keyboard
focus and type-ahead. The command moves the keyboard focus and clears the
type-ahead letters after a short pause, so map it with `Cmd.map` like any other
child. To react to what the user did, compare the state before and after.

The `id` of `State id` and `Node id` is the type of your node ids (`Tree.State
RegionId`). Say once how it is written as a key (see `nodeIds`), and the open,
selected and checked nodes come back in your own type:

### `Ids`

```elm
type Ids id  -- opaque: no constructors are exposed
```

How the id type of your nodes (a `RegionId`, a `FolderId`, plain text ...) is
written as a key and read back. Declare one value for each kind of tree, once,
and pass it to the node constructors and to the functions that speak ids. The
tree is typed by the id (`Tree.State RegionId`), so a tree of regions cannot be
asked about folder ids.

    regions : Tree.Ids RegionId
    regions =
        Tree.nodeIds { toKey = RegionId.toString, fromKey = RegionId.fromString }

The key is what the tree keeps inside its `State`, so `toKey` must give every id
its own key and `fromKey` must give the id back. A key `fromKey` rejects (it can
come from a saved view that holds an old id) is left out of the lists you get.
The lists are ordered by key, as text.

### `nodeIds`

```elm
nodeIds : { toKey : id -> String, fromKey : String -> Maybe id } -> Ids id
```

Makes the `Ids` of an id type, see there.

### `stringIds`

```elm
stringIds : Ids String
```

Ids that are plain text, used as they are.

### `intIds`

```elm
intIds : Ids Int
```

Ids that are whole numbers.

## Open and closed

### `expanded`

```elm
expanded : Ids id -> State id -> List id
```

The ids of the open nodes, in alphabetical order. While a filter is active the
tree opens the ancestors of the matches by itself, and nodes that the user opens
or closes meanwhile are temporary: they are not recorded here (see `setQuery`).

### `isExpanded`

```elm
isExpanded : Ids id -> id -> State id -> Bool
```

Is the node with this id open, in the sense of `expanded`?

### `setExpanded`

```elm
setExpanded : Ids id -> List id -> State id -> State id
```

Opens exactly the nodes with these ids and closes all others: for example to
restore a saved view. A node is only on screen when its parents are open too.

### `expand`

```elm
expand : Ids id -> id -> State id -> State id
```

Opens the node with this id. Its parents are not opened, so it stays out of
sight while one of them is closed. Opening a lazy node this way does not ask for
its children (see `loadRequests`).

### `collapse`

```elm
collapse : Ids id -> id -> State id -> State id
```

Closes the node with this id.

### `expandAll`

```elm
expandAll : List (Node id) -> State id -> State id
```

Opens every node that has children, at every depth; nodes that are already
open stay open. Give it the same nodes that you give to `view`.

    Tree.expandAll nodes model.tree

Lazy nodes are opened too, but that does not make the tree ask for their
children: no `loadRequests` come out of it. Use `newlyExpanded` to find out which
nodes were opened and load them yourself, or set `onLoadChildren` so that the
user can start the loading with a "Load" link.

### `collapseAll`

```elm
collapseAll : State id -> State id
```

Closes every node.

### `newlyExpanded`

```elm
newlyExpanded : Ids id -> State id -> State id -> List id
```

The ids of the nodes that were opened between two states: give it the state
before and the state after an update. Use it to react to nodes being opened, for
example to load something for them (`loadDetails` is a function of yours that
returns a `Cmd`).

    TreeMsg m ->
        let
            ( tree, cmd ) =
                Tree.update m model.tree

            opened =
                Tree.newlyExpanded Tree.stringIds model.tree tree
        in
        ( { model | tree = tree }
        , Cmd.batch (Cmd.map TreeMsg cmd :: List.map loadDetails opened)
        )

## Selection and checkboxes

### `selected`

```elm
selected : Ids id -> State id -> List id
```

The ids of the selected nodes, in alphabetical order. A single-select tree has
at most one; a tree with `multiSelect` can have any number.

### `selectedId`

```elm
selectedId : Ids id -> State id -> Maybe id
```

The selected id of a single-select tree, or `Nothing` when nothing is
selected. If several nodes are selected (`multiSelect`) it is the one that comes
first in alphabetical order.

### `select`

```elm
select : Ids id -> id -> State id -> State id
```

Selects exactly the node with this id, and makes it the start of a
`Shift`+click range. The parents are not opened, so the node can stay out of
sight: `expand` them as well.

### `setSelected`

```elm
setSelected : Ids id -> List id -> State id -> State id
```

Selects exactly the nodes with these ids: for example to restore a saved
selection in a `multiSelect` tree.

### `checked`

```elm
checked : Ids id -> State id -> List id
```

The ids of the checked leaves, in alphabetical order (see `checkboxes`). A
parent is never in the list: its checkbox shows whether the leaves below it are
checked. A `disabled` leaf is never checked by a click.

### `setChecked`

```elm
setChecked : Ids id -> List id -> State id -> State id
```

Checks exactly the leaves with these ids and unchecks all others. Give it
leaves, not parents: a parent always shows what its leaves say.

### `clearChecked`

```elm
clearChecked : State id -> State id
```

Unchecks every leaf.

## Focus and filter

### `focused`

```elm
focused : Ids id -> State id -> Maybe id
```

The id of the node that has (or last had) the keyboard focus, or `Nothing`
before the user has focused any node.

### `focusNode`

```elm
focusNode : Ids id -> State id -> id -> Cmd Msg
```

A command that moves the keyboard focus to the node with this id. Use it
when a button inside the tree (`onRetry`, `onLoadChildren`) was pressed: that
button is replaced by the loading row, and the focus would otherwise fall back to
the page.

    LoadBranch id ->
        ( startLoading id model
        , Cmd.map TreeMsg (Tree.focusNode Tree.stringIds model.tree id)
        )

Here `LoadBranch` is the message you gave to `onRetry` or `onLoadChildren`, and
`startLoading` marks the children of that node as `Loading` in your data. The
node has to be on screen (all its parents open) when the command runs.

### `query`

```elm
query : State id -> String
```

The filter text: what the user typed in the filter box, or what `setQuery`
set. Empty when the tree is not filtered.

### `setQuery`

```elm
setQuery : String -> State id -> State id
```

Sets the filter text, as if the user had typed it in the filter box. It also
works without `filterBox`. It forgets the nodes that the user opened or closed by
hand while the previous filter was active, and an empty (or blank) text shows the
whole tree again.

## Lazy loading

### `loadRequests`

```elm
loadRequests : Ids id -> Msg -> List id
```

The ids of the lazy nodes that this message asks children for: the ones the
user just opened while their children were `NotAsked`. Usually it is zero or one
id; `*` on the keyboard can open several nodes at once.

Call it with the message you are about to hand to `update`. Set the children of
those nodes to `Loading`, fetch them, and later put `Loaded` or `Failed` in the
node. Once a node is no longer `NotAsked` it is not requested again: after a
failure the user retries with the button that `onRetry` adds. The lazy loading
example in the introduction above shows the whole flow.

### `onLoadChildren`

```elm
onLoadChildren : (id -> msg) -> Attribute id msg
```

The message to send, given the node id, when the user presses the "Load"
link that the tree shows under an open lazy node that is still `NotAsked`
(nobody has started loading it). A node ends up like that when it was opened
without a request, with `expand`, `setExpanded` or `expandAll`, or when your
`update` did not act on its `loadRequests`. The link lets the user start the
loading by hand. Without this attribute such a node shows a spinner and nothing
loads.

### `onRetry`

```elm
onRetry : (id -> msg) -> Attribute id msg
```

The message to send, given the node id, when the user presses "Try again" on
a lazy node whose children failed to load. The button is only shown when the
problem is worth retrying (see `Klar.Remote.isRetryable`). Set the children to
`Loading` again and fetch them; `focusNode` keeps the keyboard focus on the node.

### `onReload`

```elm
onReload : msg -> Attribute id msg
```

The message sent by the "Try again" button of `viewRemote` when the top level
failed to load. The button is only shown when the problem is worth retrying.

## Attributes

### `Attribute`

```elm
type Attribute id msg  -- opaque: no constructors are exposed
```

A setting of a tree. Make them with the functions below and pass a list to
`view` or `viewRemote`; later attributes win over earlier ones.

### `ariaLabel`

```elm
ariaLabel : String -> Attribute id msg
```

The accessible name of the tree, for example "Warehouses". Give every tree
on a page its own name.

### `multiSelect`

```elm
multiSelect : Attribute id msg
```

Several nodes can be selected: `Ctrl` or `Cmd`+click toggles a node,
`Shift`+click selects a range of the visible nodes (nodes that are `disabled` are
skipped), `Shift`+`Up` and `Shift`+`Down` extend the range, and `Space` toggles.
Read the result with `selected`. It does not change how clicks work in a tree with
`checkboxes`.

### `allowEmptySelection`

```elm
allowEmptySelection : Attribute id msg
```

A click on the selected node (or `Space`, or `Enter` without `onActivate`) selects
nothing, so the selection can go back to "no node", the normal state of a tree that
filters something else ("all locations"). Without it a selected node stays selected
until another is chosen (or `setSelected` clears it). In a `multiSelect` tree a plain
click on the only selected node clears it too; `Ctrl`+click toggles as before. The
node loses `aria-selected="true"` and its highlight, and keeps the focus.

    Tree.view TreeMsg [ Tree.allowEmptySelection, Tree.ariaLabel "Locations" ] nodes state

### `checkboxes`

```elm
checkboxes : Attribute id msg
```

A tri-state checkbox on every node. Checking a parent checks all the leaves
below it; a parent with some of them checked shows a dash. A click anywhere on a
row toggles its checkbox, and so do `Space` and (without `onActivate`) `Enter`.
Rows are not highlighted as selected in this mode. Lazy nodes can be checked once
their children have loaded, and `disabled` nodes are skipped. Read the result with
`checked`.

### `filterBox`

```elm
filterBox : Attribute id msg
```

A search field above the tree that filters it as the user types. The nodes
whose label contains every typed word are kept, together with their ancestors
(which are opened), and the matching text is highlighted. A hidden status line
tells screen readers how many nodes match. The text is part of the state: see
`query` and `setQuery`.

### `filterPlaceholder`

```elm
filterPlaceholder : String -> Attribute id msg
```

The placeholder of the filter box. The default is "Search the tree ...".

### `onActivate`

```elm
onActivate : (id -> msg) -> Attribute id msg
```

The message to send, given the node id, when the user presses `Enter` on a
node or double-clicks it: open the record, navigate. Without it `Enter` selects
and a double click opens or closes. Nodes that are `disabled` are not activated.

### `compact`

```elm
compact : Attribute id msg
```

Shorter rows (24px instead of 28px): for dense layouts and side panels. A tree
in an application with a compact density (`Klar.Settings`) is already compact; this
makes just this tree compact.

### `maxHeight`

```elm
maxHeight : Int -> Attribute id msg
```

Makes the tree scroll inside itself when it is taller than this many pixels.
The filter box stays above the scrolling part. Default: no limit.

### `maxChildren`

```elm
maxChildren : Int -> Attribute id msg
```

How many children of one node are rendered before a "Show N more" row. The
default is 300; the value is kept between 10 and 10000. Each press on the row
shows up to that many more and moves the keyboard focus to the first new row.

### `emptyText`

```elm
emptyText : String -> Attribute id msg
```

The text of the empty state when there are no nodes at all. The default is
"No nodes". While a filter matches nothing the tree says "No matches" instead.

### `locale`

```elm
locale : Locale.Locale -> Attribute id msg
```

The language of the built-in text (the filter box, "Loading ...", "Load",
"Try again", "No items", "No matches", "Show N more") and of the numbers. The
default is `Locale.default`, which is English. See [Klar.Locale](Klar.Locale.md).

### `settings`

```elm
settings : Settings.Settings -> Attribute id msg
```

The settings of the application (`Klar.Settings`): the time zone of the time in
"Old data from 14:05". Without it the time is written in UTC and ends in "UTC".

    Tree.settings model.settings
