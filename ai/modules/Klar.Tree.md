# Klar.Tree

A tree view for hierarchies: regions and warehouses, folders, product categories, code lists.

Import: `import Klar.Tree as Tree` | Group: Tables and lists

Types: `Msg`, `Node`, `State`, `Attribute`

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
leaf : Ids.Ids id -> id -> String -> Node id
branch : Ids.Ids id -> id -> String -> List (Node id) -> Node id
lazy : Ids.Ids id -> id -> String -> Remote.Remote (List (Node id)) -> Node id
unloaded : Ids.Ids id -> id -> String -> Node id
withIcon : Icon.Icon -> Node id -> Node id
withCount : Int -> Node id -> Node id
withBadge : Theme.Tone -> String -> Node id -> Node id
withDescription : String -> Node id -> Node id
withKeywords : List String -> Node id -> Node id
disabled : Node id -> Node id

-- State and messages
type State id  -- opaque: no constructors are exposed
type Msg  -- opaque: no constructors are exposed
init : String -> State id
update : Msg -> State id -> ( State id, Cmd Msg )

-- Open and closed
expandedIds : Ids.Ids id -> State id -> List id
isExpanded : Ids.Ids id -> id -> State id -> Bool
setExpandedIds : Ids.Ids id -> List id -> State id -> State id
expand : Ids.Ids id -> id -> State id -> State id
collapse : Ids.Ids id -> id -> State id -> State id
toggle : Ids.Ids id -> id -> State id -> State id
expandAll : List (Node id) -> State id -> State id
collapseAll : State id -> State id
newlyExpanded : Ids.Ids id -> State id -> State id -> List id

-- Selection and checkboxes
selectedIds : Ids.Ids id -> State id -> List id
selectedId : Ids.Ids id -> State id -> Maybe id
select : Ids.Ids id -> id -> State id -> State id
setSelectedIds : Ids.Ids id -> List id -> State id -> State id
checkedIds : Ids.Ids id -> State id -> List id
setCheckedIds : Ids.Ids id -> List id -> State id -> State id
clearChecked : State id -> State id

-- Focus and filter
focused : Ids.Ids id -> State id -> Maybe id
focusNode : Ids.Ids id -> id -> State id -> Cmd Msg
query : State id -> String
setQuery : String -> State id -> State id

-- Lazy loading
loadRequests : Ids.Ids id -> State id -> List id
onRetry : msg -> Attribute id msg
onRetryChildren : (id -> msg) -> Attribute id msg

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
emptyState : List (EmptyState.Attribute msg) -> Attribute id msg
locale : Locale.Locale -> Attribute id msg
settings : Settings.Settings -> Attribute id msg
```

## Documentation

A tree view for hierarchies: regions and warehouses, folders, product
categories, code lists.

Use when: a hierarchy is shown on the page itself, with open and closed branches.
Do not use when: the user picks a node in a form field (use `Klar.TreeSelect`), or the data is flat with columns (use `Klar.Table`).
Quick path: `init`, `update`, `view`, `selectedId`

It follows the WAI-ARIA tree pattern (`tree`, `treeitem`, `group`, `aria-expanded`,
`aria-selected`, `aria-level`) and is fully usable from the keyboard. The nodes are one
tab stop; the filter box and the buttons inside the tree ("Try again", "Show 300 more")
are tab stops of their own.

    import Html exposing (Html)
    import Klar.Ids as Ids
    import Klar.Theme exposing (Tone(..))
    import Klar.Tree as Tree

    type alias Model =
        { tree : Tree.State String, warehouse : Maybe String }

    init : Model
    init =
        { tree = Tree.init "warehouse-tree", warehouse = Nothing }

    type Msg
        = TreeMsg Tree.Msg

    update : Msg -> Model -> ( Model, Cmd Msg )
    update msg model =
        case msg of
            TreeMsg m ->
                let
                    ( tree, cmd ) =
                        Tree.update m model.tree
                in
                -- The tree sends no messages of its own: read the state after update.
                ( { model | tree = tree, warehouse = Tree.selectedId Ids.string tree }
                , Cmd.map TreeMsg cmd
                )

    view : Model -> Html Msg
    view model =
        Tree.view TreeMsg
            [ Tree.ariaLabel "Warehouses", Tree.filterBox ]
            model.tree
            [ Tree.branch Ids.string
                "north"
                "Northern region"
                [ Tree.leaf Ids.string "wh-3b" "Warehouse 3B" |> Tree.withCount 24
                , Tree.leaf Ids.string "wh-4a" "Warehouse 4A" |> Tree.withBadge Warning "Closed"
                ]
            ]

For a flat list with columns use [Klar.Table](Klar.Table.md), and for a few
collapsible sections [Klar.Accordion](Klar.Accordion.md).

Nodes are plain data (`leaf`, `branch`, `lazy`) that you build from your own
data on every render; the state only remembers what the user did: which nodes
are open, which are selected or checked, which has the focus, the filter text.
Read it with `selectedId`, `selectedIds`, `expandedIds` and `checkedIds` after
`update`, and compare with the state before to react to a change. There are no
out-messages. The state refers to nodes by id, so every node id must be unique
in the whole tree.

Keyboard: `Tab` enters and leaves the nodes. `Up` and `Down` move, `Right`
opens a closed node and then moves to its first child, `Left` closes an open node
and then moves to the parent, `Home` and `End` jump to the first and last visible
node, `PageUp` and `PageDown` move ten nodes, `Enter` calls `onActivate` (without
it, `Enter` does what `Space` does), `Space` selects (toggles in a `multiSelect`
tree, checks in a tree with `checkboxes`) and `*` opens all closed nodes on the
current level. In a `multiSelect` tree `Shift` with `Up`, `Down`, `PageUp`,
`PageDown`, `Home` or `End` extends the selection, and `Ctrl`+`A` (`Cmd`+`A`)
selects every visible node. Typing
letters jumps to the next visible node whose label starts with them. In the filter
box, `Down` moves into the tree and `Escape` clears the filter. With the mouse, a
click selects, the arrow in front of a node opens and closes it, and a double
click activates (or, without `onActivate`, opens or closes the node).

Selection: single by default (a tree that filters something else adds
`allowEmptySelection`, so that a click on the selected node clears it);
`multiSelect` allows `Ctrl`+click to add and `Shift`+click for a range. With
`checkboxes` every node has a tri-state checkbox, and a click on a row toggles it:
checking a parent checks every leaf below it, and a parent with some of them
checked shows a dash. `checkedIds` returns the checked leaves. A node that is
`disabled` can be neither selected nor checked, and checking an ancestor passes it
and everything below it by.

Filter: with `filterBox` the tree has a search field (or call `setQuery`). The
tree then shows the nodes whose label, description (`withDescription`) or
keywords (`withKeywords`) contain every word typed (case and accents are
ignored), with every ancestor of a match opened and the matching text
highlighted. Checking a parent while a filter is active still checks every leaf
below it, also the ones the filter hides, and its checkbox shows all of them.
Only nodes that are in your data are searched, so the children of a lazy node
that has not been loaded are not: for a lazy tree, watch `query` (compare it
before and after `update`), ask the backend for the matching nodes with their
ancestors and put them in your data, or load every branch first. Nodes that the
user opens or closes while a filter is active are forgotten when the text changes.

Lazy loading: a `lazy` node carries a `Remote` of its children. A lazy node that is
open while its children are `NotAsked` asks for them once: when the user opens it,
or when it first shows up open (after `expand`, `setExpandedIds` or `expandAll`).
`loadRequests` after `update` names the nodes that asked; set their children to
`Loading`, fetch them, and put `Loaded` or `Failed` in the node on the next render.
The tree shows a spinner row while loading and a short failure with a retry button
(`onRetryChildren`); focus goes back to the node when the button is pressed. The
children of a lazy node may be lazy nodes too. The tree keeps no copy of your
nodes, so each level has its own `Remote` in your model: store what was loaded by
node id and build the nodes from it in every `view`.

    TreeMsg m ->
        let
            ( tree, cmd ) =
                Tree.update m model.tree

            requests =
                Tree.loadRequests Ids.string tree
        in
        ( { model | tree = tree, regions = markLoading requests model.regions }
        , Cmd.batch (Cmd.map TreeMsg cmd :: List.map fetchChildren requests)
        )

Here `markLoading` sets the children of the requested nodes to `Loading` in your
data and `fetchChildren` starts the request for one node id; both are yours. If
the whole top level comes from the backend, give it to `viewRemote`.

Large trees: only open branches are rendered (with keyed nodes), and a branch
with more than `maxChildren` children (default 300) shows the first ones and a
"Show 300 more" row. Every row on the screen is drawn again after each message, so
keep the number of open rows in the hundreds; when the nodes of a big tree are kept
in your model, draw it with `Html.Lazy.lazy2` on the state and the nodes: a message
that changes nothing gives back the very same state, so the tree is then not drawn
again for it.

The built-in text (the filter box, "Loading ...", "No matches" and so on) is
English unless you set `locale`. Labels, descriptions, counts and badges come from you.

## Views

### `view`

```elm
view : (Msg -> msg) -> List (Attribute id msg) -> State id -> List (Node id) -> Html msg
```

The tree. The arguments are the wrapper for the tree's messages, the
attributes, the state and the top-level nodes.

    Tree.view TreeMsg [ Tree.ariaLabel "Warehouses" ] model.tree nodes

With no nodes the tree shows an empty state ("No nodes", or your `emptyState`),
and while a filter matches nothing it says "No matches".

### `viewRemote`

```elm
viewRemote :
    (Msg -> msg)
    -> List (Attribute id msg)
    -> State id
    -> Remote.Remote (List (Node id))
    -> Html msg
```

The same tree for a top level that comes from the backend. `NotAsked` and
`Loading` show a skeleton, `Failed` shows the problem with a "Try again" button
(`onRetry`), and `Loaded` shows the tree. Nodes that are `Kept` stay on the
screen: dimmed and busy while they are refreshed, and with "Old data from 14:05"
and a retry above them when the last refresh failed (`settings` gives the time
zone). The element with the id of `init`, the filter box and the tree are the same
elements in every state, so the focus in the filter box or on a node survives a
refresh.

    Tree.viewRemote TreeMsg [ Tree.onRetry ReloadRegions ] model.tree model.regions

For the children of a single node use `lazy` instead.

## Nodes

### `Node`

```elm
type Node id  -- opaque: no constructors are exposed
```

One node of the tree. Build it with `leaf`, `branch`, `lazy` or `unloaded`,
and add an icon, a count, a badge, a description or search keywords with the
`with...` functions. Nodes are plain data: build them from your own data on every
render.

### `leaf`

```elm
leaf : Ids.Ids id -> id -> String -> Node id
```

A node without children. The first `String` is the id, the second the label.

    Tree.leaf Ids.string "wh-3b" "Warehouse 3B"

The id must be unique in the whole tree, not only among its siblings: it is how
the state remembers what is open, selected and checked, and what the callbacks
receive. Use a stable id from your data. The label is written on one line and
cut with an ellipsis when it does not fit (the full label is the tooltip).

### `branch`

```elm
branch : Ids.Ids id -> id -> String -> List (Node id) -> Node id
```

A node with children. The arguments are the id, the label and the child
nodes. The id must be unique in the whole tree.

    Tree.branch Ids.string "north" "Northern region" [ Tree.leaf Ids.string "wh-3b" "Warehouse 3B" ]

The children are only rendered while the node is open. A branch with an empty
list of children has no arrow and looks like a leaf; use `lazy` for children that
you do not have yet.

### `lazy`

```elm
lazy : Ids.Ids id -> id -> String -> Remote.Remote (List (Node id)) -> Node id
```

A node whose children come from the backend and are fetched when the node
is first opened. Until then the `Remote` is `NotAsked`; while the request is on
its way you pass `Loading`, and then `Loaded` with the children or `Failed`
with a problem.

    Tree.lazy Ids.string "south" "Southern region" model.southWarehouses

See `loadRequests` for how to find out when to fetch. A lazy node always has an
arrow. When it is open the tree shows a spinner row while the children load, the
problem with a retry button when they failed (`onRetryChildren`), and "No items"
when the list is empty. Children that are `Kept` stay on the screen: dimmed while
they are refreshed, and with "Old data from 14:05" and a retry above them when the
last refresh failed.

### `unloaded`

```elm
unloaded : Ids.Ids id -> id -> String -> Node id
```

A node whose children have not been asked for yet: `lazy` with `NotAsked`.
The arguments are the id and the label.

    Tree.unloaded Ids.string "south" "Southern region"

### `withIcon`

```elm
withIcon : Icon.Icon -> Node id -> Node id
```

An icon in front of the label.

    Tree.leaf Ids.string "wh-3b" "Warehouse 3B" |> Tree.withIcon Icon.building

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

    Tree.leaf Ids.string "wh-4a" "Warehouse 4A" |> Tree.withBadge Warning "Closed"

### `withDescription`

```elm
withDescription : String -> Node id -> Node id
```

A short secondary text, shown dimmed after the label and searched too: a code,
a city, a short note. It takes at most 40% of the row and is cut with an ellipsis.
On a row it comes before the count and the badge.

    Tree.leaf Ids.string "wh-3b" "Warehouse 3B" |> Tree.withDescription "OSL-3B"

### `withKeywords`

```elm
withKeywords : List String -> Node id -> Node id
```

Extra words that also find the node in the filter box: synonyms, codes, old
names. They are searched but never shown. Calling it again adds to the words.

    Tree.leaf Ids.string "wh-3b" "Warehouse 3B" |> Tree.withKeywords [ "Oslo", "cold store" ]

### `disabled`

```elm
disabled : Node id -> Node id
```

A node that is shown but cannot be selected, checked or activated: a click,
`Space` and `Enter` leave it as it is. It can still be opened and closed. Its
children are not disabled with it: in a tree with `checkboxes` the leaves below a
disabled branch can still be checked one by one, and its own checkbox shows them.
Checking an ancestor passes the disabled node and everything below it by, and the
ancestor's checkbox does not count them.

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
(`TreeMsg`) and hand it to `update`.

### `init`

```elm
init : String -> State id
```

A tree state with nothing open, selected or checked. The `String` is the DOM
id of the tree and must be unique on the page. It goes on an element that lies
over the filter box and the nodes (it takes no clicks), in every state of
`viewRemote` too, so `Klar.focus "warehouse-tree" NoOp` puts the keyboard focus on
the node that has the tab stop (or on that element, which then outlines the tree,
while nothing is loaded). The nodes get ids that start with it, and the filter box
gets this id followed by `-filter`.

    Tree.init "warehouse-tree"

### `update`

```elm
update : Msg -> State id -> ( State id, Cmd Msg )
```

Handles opening and closing, selecting, checking, the filter box, keyboard
focus and type-ahead. The command moves the keyboard focus and clears the
type-ahead letters after a short pause, so map it with `Cmd.map` like any other
child. To react to what the user did, compare the state before and after, and
read `loadRequests` from the new state.

The `id` of `State id` and `Node id` is the type of your node ids (`Tree.State
RegionId`). Say once how it is written as a key, as a [Klar.Ids](Klar.Ids.md), and pass it
to the node constructors and the functions that speak ids; the open, selected and checked
nodes come back in your own type:

    regions : Ids RegionId

    -- import Klar.Ids as Ids exposing (Ids)
    regions =
        Ids.make { toKey = RegionId.toString, fromKey = RegionId.fromString }

A key `fromKey` rejects (it can come from a saved view that holds an old id) is left out
of the lists you get. The lists are ordered by key, as text.

## Open and closed

### `expandedIds`

```elm
expandedIds : Ids.Ids id -> State id -> List id
```

The ids of the open nodes, in alphabetical order. While a filter is active the
tree opens the ancestors of the matches by itself, and nodes that the user opens
or closes meanwhile are temporary: they are not recorded here (see `setQuery`).

### `isExpanded`

```elm
isExpanded : Ids.Ids id -> id -> State id -> Bool
```

Is the node with this id open, in the sense of `expandedIds`?

### `setExpandedIds`

```elm
setExpandedIds : Ids.Ids id -> List id -> State id -> State id
```

Opens exactly the nodes with these ids and closes all others: for example to
restore a saved view. A node is only on screen when its parents are open too. A
lazy node it opens asks for its children when it shows up (see `loadRequests`).

### `expand`

```elm
expand : Ids.Ids id -> id -> State id -> State id
```

Opens the node with this id. Its parents are not opened, so it stays out of
sight while one of them is closed. A lazy node opened this way asks for its
children when it shows up (see `loadRequests`).

### `collapse`

```elm
collapse : Ids.Ids id -> id -> State id -> State id
```

Closes the node with this id.

### `toggle`

```elm
toggle : Ids.Ids id -> id -> State id -> State id
```

Opens the node with this id when it is closed, and closes it when it is open
(in the sense of `isExpanded`).

### `expandAll`

```elm
expandAll : List (Node id) -> State id -> State id
```

Opens every node that has children, at every depth; nodes that are already
open stay open. Give it the same nodes that you give to `view`.

    Tree.expandAll nodes model.tree

The lazy nodes it opens ask for their children when they show up, one message
each: `loadRequests` after `update` names them, as when the user opens them.

### `collapseAll`

```elm
collapseAll : State id -> State id
```

Closes every node.

### `newlyExpanded`

```elm
newlyExpanded : Ids.Ids id -> State id -> State id -> List id
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
                Tree.newlyExpanded Ids.string model.tree tree
        in
        ( { model | tree = tree }
        , Cmd.batch (Cmd.map TreeMsg cmd :: List.map loadDetails opened)
        )

## Selection and checkboxes

### `selectedIds`

```elm
selectedIds : Ids.Ids id -> State id -> List id
```

The ids of the selected nodes, in alphabetical order. A single-select tree has
at most one; a tree with `multiSelect` can have any number.

### `selectedId`

```elm
selectedId : Ids.Ids id -> State id -> Maybe id
```

The selected id of a single-select tree, or `Nothing` when nothing is
selected. If several nodes are selected (`multiSelect`) it is the one that comes
first in alphabetical order.

### `select`

```elm
select : Ids.Ids id -> id -> State id -> State id
```

Selects exactly the node with this id, and makes it the start of a
`Shift`+click range. The parents are not opened, so the node can stay out of
sight: `expand` them as well.

### `setSelectedIds`

```elm
setSelectedIds : Ids.Ids id -> List id -> State id -> State id
```

Selects exactly the nodes with these ids: for example to restore a saved
selection in a `multiSelect` tree. An empty list selects nothing.

### `checkedIds`

```elm
checkedIds : Ids.Ids id -> State id -> List id
```

The ids of the checked leaves, in alphabetical order (see `checkboxes`). A
parent is never in the list: its checkbox shows whether the leaves below it are
checked. A `disabled` leaf is never checked by a click.

### `setCheckedIds`

```elm
setCheckedIds : Ids.Ids id -> List id -> State id -> State id
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
focused : Ids.Ids id -> State id -> Maybe id
```

The id of the node that has (or last had) the keyboard focus, or `Nothing`
before the user has focused any node.

### `focusNode`

```elm
focusNode : Ids.Ids id -> id -> State id -> Cmd Msg
```

A command that moves the keyboard focus to the node with this id: for example
when a button of yours next to the tree goes away and the user should go on in the
tree. The buttons inside the tree ("Try again", "Show 300 more") move the focus
themselves.

    ClearCategory ->
        ( { model | category = Nothing }
        , Cmd.map TreeMsg (Tree.focusNode Ids.string "hardware" model.tree)
        )

The node has to be on screen (all its parents open) when the command runs. To put
the focus on whichever node has the tab stop, use `Klar.focus` with the id of `init`.

### `query`

```elm
query : State id -> String
```

The filter text: what the user typed in the filter box, or what `setQuery`
set. Empty when the tree is not filtered. The tree filters its own nodes at once; this
text follows the box after a pause of 300 ms in the typing, so a lazy tree that asks the
backend when it changes needs no debounce of its own.

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
loadRequests : Ids.Ids id -> State id -> List id
```

The lazy nodes whose children the last `update` asked for: the ones the user
just opened while their children were `NotAsked`, and an open node that showed up
with `NotAsked` children (after `expand`, `setExpandedIds` or `expandAll`, or after
you set a node back to `NotAsked` to load it again). Usually zero or one id; `*`
on the keyboard can open several nodes at once.

Call it after every `update`, with the new state. Set the children of those nodes
to `Loading` in that same update, fetch them, and later put `Loaded` or `Failed`
in the node. An open node asks while its children are `NotAsked`: when it opens,
and again whenever its row is drawn anew (a hidden panel with the tree is shown
again), so a node left `NotAsked` can be asked for twice. If the automatic
request never comes (a stylesheet that switches every animation off), a "Load"
button appears under the node after a second. After a failure the user retries
with the button that `onRetryChildren` adds. The lazy loading example in the
introduction above shows the whole flow.

### `onRetry`

```elm
onRetry : msg -> Attribute id msg
```

The message sent by the "Try again" button of `viewRemote`: when the top level
failed to load, and in the "Old data from 14:05" marker when a refresh of it
failed. The button is only shown when the problem is worth retrying (see
`Klar.Remote.isRetryable`). The tree moves the keyboard focus to its filter box,
or to the element with the id of `init`, before the button goes away.

    Tree.viewRemote TreeMsg [ Tree.onRetry ReloadRegions ] model.tree model.regions

### `onRetryChildren`

```elm
onRetryChildren : (id -> msg) -> Attribute id msg
```

The message to send, given the node id, when the user presses "Try again" on
a lazy node whose children failed to load (or in its "Old data" marker when a
refresh of them failed). The button is only shown when the problem is worth
retrying (see `Klar.Remote.isRetryable`). Set the children to `Loading` again (or
`Remote.refresh` them) and fetch them; the tree puts the keyboard focus back on the
node itself.

    Tree.onRetryChildren ReloadBranch

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
skipped), `Shift` with an arrow, `PageUp`, `PageDown`, `Home` or `End` extends the
range, `Ctrl`+`A` (`Cmd`+`A`) selects every visible node, and `Space` toggles.
Read the result with `selectedIds`. It does not change how clicks work in a tree
with `checkboxes`.

### `allowEmptySelection`

```elm
allowEmptySelection : Attribute id msg
```

A click on the selected node (or `Space`, or `Enter` without `onActivate`) selects
nothing, so the selection can go back to "no node", the normal state of a tree that
filters something else ("all locations"). Without it a selected node stays selected
until another is chosen (or `setSelectedIds` with no ids clears it). In a `multiSelect`
tree a plain click on the only selected node clears it too; `Ctrl`+click toggles as
before. The node loses `aria-selected="true"` and its highlight, and keeps the focus.

    Tree.view TreeMsg [ Tree.allowEmptySelection, Tree.ariaLabel "Locations" ] model.tree nodes

### `checkboxes`

```elm
checkboxes : Attribute id msg
```

A tri-state checkbox on every node. Checking a parent checks all the leaves
below it; a parent with some of them checked shows a dash. A click anywhere on a
row toggles its checkbox, and so do `Space` and (without `onActivate`) `Enter`.
Rows are not highlighted as selected in this mode. Lazy nodes can be checked once
their children have loaded. A `disabled` node stops the cascade: its own checkbox
cannot be changed, checking an ancestor leaves it and everything below it as it
is, and the ancestor's checkbox does not count them (the leaves below a disabled
branch can still be checked one by one). While a filter is active a parent still
stands for every leaf below it, also the hidden ones. Read the result with
`checkedIds`.

### `filterBox`

```elm
filterBox : Attribute id msg
```

A search field above the tree that filters it as the user types. The nodes
whose label, description or keywords contain every typed word are kept, together
with their ancestors (which are opened), and the matching text of the label and
the description is highlighted. A hidden status line tells screen readers how many
nodes match. The text is part of the state: see `query` and `setQuery`. In
`viewRemote` the box stays while the nodes load or fail, so a search that asks the
backend keeps the focus in the box.

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

### `emptyState`

```elm
emptyState : List (EmptyState.Attribute msg) -> Attribute id msg
```

Changes the empty state shown when there are no nodes at all (titled "No
nodes" by default, with a folder icon). The attributes are those of
[Klar.EmptyState](Klar.EmptyState.md), applied after the built-in ones, so yours win.
While a filter matches nothing the tree says "No matches" instead, which this does
not change.

    Tree.emptyState [ EmptyState.title "No warehouses yet", EmptyState.action addButton ]

### `locale`

```elm
locale : Locale.Locale -> Attribute id msg
```

The language of the built-in text (the filter box, "Loading ...", "Try again",
"No items", "No matches", "Show N more", "Old data") and of the numbers. The
default is `Locale.default`, which is English. See [Klar.Locale](Klar.Locale.md).

### `settings`

```elm
settings : Settings.Settings -> Attribute id msg
```

The settings of the application (`Klar.Settings`): the time zone of the time in
"Old data from 14:05". Without it the time is written in UTC and ends in "UTC".

    Tree.settings model.settings
