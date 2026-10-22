module Klar.Tree exposing
    ( view, viewRemote
    , Node, leaf, branch, lazy, unloaded, withIcon, withCount, withBadge, withHint, disabled
    , State, Msg, init, update
    , Ids, nodeIds, stringIds, intIds
    , expanded, isExpanded, setExpanded, expand, collapse, expandAll, collapseAll, newlyExpanded
    , selected, selectedId, select, setSelected, checked, setChecked, clearChecked
    , focused, focusNode, query, setQuery
    , loadRequests, onLoadChildren, onRetry, onReload
    , Attribute, ariaLabel, multiSelect, allowEmptySelection, checkboxes, filterBox, filterPlaceholder, onActivate, compact, maxHeight, maxChildren, emptyText, locale, settings
    )

{-| A tree view for hierarchies: regions and warehouses, folders, product
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
[Klar.Table](Klar-Table), and for a few collapsible sections
[Klar.Accordion](Klar-Accordion).

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
of a lazy node that has not been loaded are not. Nodes that the user opens or
closes while a filter is active are forgotten when the text changes.

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


# Views

@docs view, viewRemote


# Nodes

@docs Node, leaf, branch, lazy, unloaded, withIcon, withCount, withBadge, withHint, disabled


# State and messages

@docs State, Msg, init, update

The `id` of `State id` and `Node id` is the type of your node ids (`Tree.State
RegionId`). Say once how it is written as a key (see `nodeIds`), and the open,
selected and checked nodes come back in your own type:

@docs Ids, nodeIds, stringIds, intIds


# Open and closed

@docs expanded, isExpanded, setExpanded, expand, collapse, expandAll, collapseAll, newlyExpanded


# Selection and checkboxes

@docs selected, selectedId, select, setSelected, checked, setChecked, clearChecked


# Focus and filter

@docs focused, focusNode, query, setQuery


# Lazy loading

@docs loadRequests, onLoadChildren, onRetry, onReload


# Attributes

@docs Attribute, ariaLabel, multiSelect, allowEmptySelection, checkboxes, filterBox, filterPlaceholder, onActivate, compact, maxHeight, maxChildren, emptyText, locale, settings

-}

import Dict exposing (Dict)
import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Events
import Html.Keyed as Keyed
import Json.Decode as Decode
import Klar.Badge as Badge
import Klar.Button as Button
import Klar.Checkbox as Checkbox
import Klar.EmptyState as EmptyState
import Klar.ErrorState as ErrorState
import Klar.Format as Format
import Klar.Icon as Icon exposing (Icon)
import Klar.Internal as Internal
import Klar.Internal.Freshness as Freshness exposing (Freshness)
import Klar.Locale as Locale exposing (Locale)
import Klar.Remote as Remote exposing (Problem, Remote)
import Klar.Search as Search
import Klar.Settings as Settings exposing (Settings)
import Klar.Skeleton as Skeleton
import Klar.Spinner as Spinner
import Klar.TextInput as TextInput
import Klar.Theme as Theme exposing (Size(..), Tone)
import Process
import Set exposing (Set)
import Task



-- IDS


{-| How the id type of your nodes (a `RegionId`, a `FolderId`, plain text ...) is
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

-}
type Ids id
    = Ids
        { toKey : id -> String
        , fromKey : String -> Maybe id
        }


{-| Makes the `Ids` of an id type, see there.
-}
nodeIds : { toKey : id -> String, fromKey : String -> Maybe id } -> Ids id
nodeIds =
    Ids


{-| Ids that are plain text, used as they are.
-}
stringIds : Ids String
stringIds =
    Ids { toKey = identity, fromKey = Just }


{-| Ids that are whole numbers.
-}
intIds : Ids Int
intIds =
    Ids { toKey = String.fromInt, fromKey = String.toInt }


idOf : Ids id -> String -> Maybe id
idOf (Ids i) key =
    i.fromKey key


idsOf : Ids id -> Set String -> List id
idsOf (Ids i) keys =
    List.filterMap i.fromKey (Set.toList keys)


keysOf : Ids id -> List id -> List String
keysOf (Ids i) =
    List.map i.toKey



-- NODES


{-| One node of the tree. Build it with `leaf`, `branch`, `lazy` or `unloaded`,
and add an icon, a count, a badge or a hint with the `with...` functions. Nodes
are plain data: build them from your own data on every render.
-}
type Node id
    = Node (NodeData id)


type alias NodeData id =
    { id : String
    , value : id
    , label : String
    , icon : Maybe Icon
    , hint : Maybe String
    , count : Maybe Int
    , badge : Maybe ( Tone, String )
    , disabled : Bool
    , children : Children id
    }


type Children id
    = Leaf
    | Branch (List (Node id))
    | Lazy (Remote (List (Node id)))
    | LazyKept Freshness (List (Node id))


make : Ids id -> id -> String -> Children id -> Node id
make (Ids ids) id label children =
    Node
        { id = ids.toKey id
        , value = id
        , label = label
        , icon = Nothing
        , hint = Nothing
        , count = Nothing
        , badge = Nothing
        , disabled = False
        , children = children
        }


{-| A node without children. The first `String` is the id, the second the label.

    Tree.leaf Tree.stringIds "wh-3b" "Warehouse 3B"

The id must be unique in the whole tree, not only among its siblings: it is how
the state remembers what is open, selected and checked, and what the callbacks
receive. Use a stable id from your data. The label is written on one line and
cut with an ellipsis when it does not fit (the full label is the tooltip).

-}
leaf : Ids id -> id -> String -> Node id
leaf ids id label =
    make ids id label Leaf


{-| A node with children. The arguments are the id, the label and the child
nodes. The id must be unique in the whole tree.

    Tree.branch Tree.stringIds "north" "Northern region" [ Tree.leaf Tree.stringIds "wh-3b" "Warehouse 3B" ]

The children are only rendered while the node is open. A branch with an empty
list of children has no arrow and looks like a leaf; use `lazy` for children that
you do not have yet.

-}
branch : Ids id -> id -> String -> List (Node id) -> Node id
branch ids id label children =
    make ids id label (Branch children)


{-| A node whose children come from the backend and are fetched when the node
is first opened. Until then the `Remote` is `NotAsked`; while the request is on
its way you pass `Loading`, and then `Loaded` with the children or `Failed`
with a problem.

    Tree.lazy Tree.stringIds "south" "Southern region" model.southWarehouses

See `loadRequests` for how to find out when to fetch. A lazy node always has an
arrow. When it is open the tree shows a spinner row while the children load, the
problem with a retry button when they failed (`onRetry`), and "No items" when
the list is empty.

-}
lazy : Ids id -> id -> String -> Remote (List (Node id)) -> Node id
lazy ids id label children =
    make ids
        id
        label
        (case Freshness.settle children of
            ( Remote.Loaded nodes, Freshness.Fresh ) ->
                Lazy (Remote.Loaded nodes)

            ( Remote.Loaded nodes, freshness ) ->
                LazyKept freshness nodes

            ( settled, _ ) ->
                Lazy settled
        )


{-| A node whose children have not been asked for yet: `lazy` with `NotAsked`.
The arguments are the id and the label.

    Tree.unloaded Tree.stringIds "south" "Southern region"

-}
unloaded : Ids id -> id -> String -> Node id
unloaded ids id label =
    make ids id label (Lazy Remote.NotAsked)


{-| An icon in front of the label.

    Tree.leaf Tree.stringIds "wh-3b" "Warehouse 3B" |> Tree.withIcon Icon.building

-}
withIcon : Icon -> Node id -> Node id
withIcon icon (Node data) =
    Node { data | icon = Just icon }


{-| A muted number after the label: open orders, items in stock. It is written
with the thousands separator of the tree's `locale`.
-}
withCount : Int -> Node id -> Node id
withCount n (Node data) =
    Node { data | count = Just n }


{-| A small colored label after the label, for a status. The `Tone` (from
[Klar.Theme](Klar-Theme)) sets the color, the `String` is the text.

    Tree.leaf Tree.stringIds "wh-4a" "Warehouse 4A" |> Tree.withBadge Warning "Closed"

-}
withBadge : Tone -> String -> Node id -> Node id
withBadge tone text (Node data) =
    Node { data | badge = Just ( tone, text ) }


{-| Muted text after the label: a code or a short note. It takes at most 40% of
the row and is cut with an ellipsis. On a row it comes before the count and the
badge.
-}
withHint : String -> Node id -> Node id
withHint text (Node data) =
    Node { data | hint = Just text }


{-| A node that is shown but cannot be selected, checked or activated. It can
still be opened and closed, and its children are not affected.
-}
disabled : Node id -> Node id
disabled (Node data) =
    Node { data | disabled = True }


childNodes : Children id -> List (Node id)
childNodes children =
    case children of
        Branch nodes ->
            nodes

        Lazy (Remote.Loaded nodes) ->
            nodes

        LazyKept _ nodes ->
            nodes

        _ ->
            []


isExpandable : Children id -> Bool
isExpandable children =
    case children of
        Leaf ->
            False

        Branch nodes ->
            not (List.isEmpty nodes)

        Lazy _ ->
            True

        LazyKept _ _ ->
            True


lazyBusy : Children id -> Bool
lazyBusy children =
    case children of
        LazyKept freshness _ ->
            Freshness.busy freshness

        _ ->
            False


isUnloaded : Children id -> Bool
isUnloaded children =
    children == Lazy Remote.NotAsked



-- STATE


{-| What the user has done to a tree: which nodes are open, selected or checked,
which has the keyboard focus, the filter text. Make one with `init`, keep it in
your model, pass every `Msg` through `update` and read it with the functions
below. The tree itself (the nodes) is not part of it.
-}
type State id
    = State StateData


type alias StateData =
    { id : String
    , expanded : Set String
    , selected : Set String
    , anchor : Maybe String
    , checked : Set String
    , focused : Maybe String
    , pendingFocus : Maybe String
    , query : String
    , flips : Set String
    , extra : Dict String Int
    , typeahead : String
    , typeaheadSeq : Int
    }


{-| A tree state with nothing open, selected or checked. The `String` is a DOM
id prefix and must be unique on the page: the rows get ids that start with it,
and the filter box gets this id followed by `-filter`.

    Tree.init "warehouse-tree"

-}
init : String -> State id
init id =
    State
        { id = id
        , expanded = Set.empty
        , selected = Set.empty
        , anchor = Nothing
        , checked = Set.empty
        , focused = Nothing
        , pendingFocus = Nothing
        , query = ""
        , flips = Set.empty
        , extra = Dict.empty
        , typeahead = ""
        , typeaheadSeq = 0
        }


{-| The ids of the open nodes, in alphabetical order. While a filter is active the
tree opens the ancestors of the matches by itself, and nodes that the user opens
or closes meanwhile are temporary: they are not recorded here (see `setQuery`).
-}
expanded : Ids id -> State id -> List id
expanded ids (State s) =
    idsOf ids s.expanded


{-| Is the node with this id open, in the sense of `expanded`?
-}
isExpanded : Ids id -> id -> State id -> Bool
isExpanded (Ids ids) id (State s) =
    Set.member (ids.toKey id) s.expanded


{-| Opens exactly the nodes with these ids and closes all others: for example to
restore a saved view. A node is only on screen when its parents are open too.
-}
setExpanded : Ids id -> List id -> State id -> State id
setExpanded ids values (State s) =
    State { s | expanded = Set.fromList (keysOf ids values) }


{-| Opens the node with this id. Its parents are not opened, so it stays out of
sight while one of them is closed. Opening a lazy node this way does not ask for
its children (see `loadRequests`).
-}
expand : Ids id -> id -> State id -> State id
expand (Ids ids) id (State s) =
    State { s | expanded = Set.insert (ids.toKey id) s.expanded }


{-| Closes the node with this id.
-}
collapse : Ids id -> id -> State id -> State id
collapse (Ids ids) id (State s) =
    State { s | expanded = Set.remove (ids.toKey id) s.expanded }


{-| Opens every node that has children, at every depth; nodes that are already
open stay open. Give it the same nodes that you give to `view`.

    Tree.expandAll nodes model.tree

Lazy nodes are opened too, but that does not make the tree ask for their
children: no `loadRequests` come out of it. Use `newlyExpanded` to find out which
nodes were opened and load them yourself, or set `onLoadChildren` so that the
user can start the loading with a "Load" link.

-}
expandAll : List (Node id) -> State id -> State id
expandAll nodes (State s) =
    State { s | expanded = Set.union s.expanded (Set.fromList (expandableIds nodes)) }


{-| Closes every node.
-}
collapseAll : State id -> State id
collapseAll (State s) =
    State { s | expanded = Set.empty, flips = Set.empty }


expandableIds : List (Node id) -> List String
expandableIds nodes =
    List.concatMap
        (\(Node n) ->
            if isExpandable n.children then
                n.id :: expandableIds (childNodes n.children)

            else
                []
        )
        nodes


{-| The ids of the nodes that were opened between two states: give it the state
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

-}
newlyExpanded : Ids id -> State id -> State id -> List id
newlyExpanded ids (State before) (State after) =
    Set.diff after.expanded before.expanded |> idsOf ids


{-| The ids of the selected nodes, in alphabetical order. A single-select tree has
at most one; a tree with `multiSelect` can have any number.
-}
selected : Ids id -> State id -> List id
selected ids (State s) =
    idsOf ids s.selected


{-| The selected id of a single-select tree, or `Nothing` when nothing is
selected. If several nodes are selected (`multiSelect`) it is the one that comes
first in alphabetical order.
-}
selectedId : Ids id -> State id -> Maybe id
selectedId ids (State s) =
    idsOf ids s.selected |> List.head


{-| Selects exactly the node with this id, and makes it the start of a
`Shift`+click range. The parents are not opened, so the node can stay out of
sight: `expand` them as well.
-}
select : Ids id -> id -> State id -> State id
select (Ids ids) id (State s) =
    State { s | selected = Set.singleton (ids.toKey id), anchor = Just (ids.toKey id) }


{-| Selects exactly the nodes with these ids: for example to restore a saved
selection in a `multiSelect` tree.
-}
setSelected : Ids id -> List id -> State id -> State id
setSelected ids values (State s) =
    State { s | selected = Set.fromList (keysOf ids values) }


{-| The ids of the checked leaves, in alphabetical order (see `checkboxes`). A
parent is never in the list: its checkbox shows whether the leaves below it are
checked. A `disabled` leaf is never checked by a click.
-}
checked : Ids id -> State id -> List id
checked ids (State s) =
    idsOf ids s.checked


{-| Checks exactly the leaves with these ids and unchecks all others. Give it
leaves, not parents: a parent always shows what its leaves say.
-}
setChecked : Ids id -> List id -> State id -> State id
setChecked ids values (State s) =
    State { s | checked = Set.fromList (keysOf ids values) }


{-| Unchecks every leaf.
-}
clearChecked : State id -> State id
clearChecked (State s) =
    State { s | checked = Set.empty }


{-| The id of the node that has (or last had) the keyboard focus, or `Nothing`
before the user has focused any node.
-}
focused : Ids id -> State id -> Maybe id
focused (Ids ids) (State s) =
    s.focused |> Maybe.andThen ids.fromKey


{-| A command that moves the keyboard focus to the node with this id. Use it
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

-}
focusNode : Ids id -> State id -> id -> Cmd Msg
focusNode (Ids ids) (State s) id =
    Internal.focus (rowDomId s.id (ids.toKey id)) Noop


{-| The filter text: what the user typed in the filter box, or what `setQuery`
set. Empty when the tree is not filtered.
-}
query : State id -> String
query (State s) =
    s.query


{-| Sets the filter text, as if the user had typed it in the filter box. It also
works without `filterBox`. It forgets the nodes that the user opened or closed by
hand while the previous filter was active, and an empty (or blank) text shows the
whole tree again.
-}
setQuery : String -> State id -> State id
setQuery text (State s) =
    State { s | query = text, flips = Set.empty, extra = Dict.empty }



-- MESSAGES


type ClickMode
    = Replace
    | ReplaceOrClear
    | Toggle
    | Range


type alias OpenRequest =
    { id : String
    , open : Bool
    , forced : Bool
    , load : Bool
    , focus : Bool
    }


{-| A message of the tree. Wrap it in a constructor of your own message type
(`TreeMsg`), hand it to `update`, and give it to `loadRequests` to find out which
lazy nodes the user just opened.
-}
type Msg
    = SetOpen OpenRequest
    | OpenMany (List OpenRequest)
    | Click String ClickMode (List String)
    | ToggleCheck (List String) Bool String
    | Focused String
    | FocusDone String
    | MoveFocus String
    | Step Int (List String)
    | StepRange Int (List String) (List String)
    | Guard String Msg
    | QueryChanged String
    | ClearQuery
    | ShowMore String Int String
    | TypeAhead String (List ( String, String ))
    | ClearTypeahead Int
    | Noop


{-| The ids of the lazy nodes that this message asks children for: the ones the
user just opened while their children were `NotAsked`. Usually it is zero or one
id; `*` on the keyboard can open several nodes at once.

Call it with the message you are about to hand to `update`. Set the children of
those nodes to `Loading`, fetch them, and later put `Loaded` or `Failed` in the
node. Once a node is no longer `NotAsked` it is not requested again: after a
failure the user retries with the button that `onRetry` adds. The lazy loading
example in the introduction above shows the whole flow.

-}
loadRequests : Ids id -> Msg -> List id
loadRequests ids msg =
    case msg of
        SetOpen request ->
            requestIds ids [ request ]

        OpenMany requests ->
            requestIds ids requests

        Guard _ inner ->
            loadRequests ids inner

        _ ->
            []


requestIds : Ids id -> List OpenRequest -> List id
requestIds ids requests =
    requests
        |> List.filter (\request -> request.open && request.load)
        |> List.filterMap (\request -> idOf ids request.id)


{-| Handles opening and closing, selecting, checking, the filter box, keyboard
focus and type-ahead. The command moves the keyboard focus and clears the
type-ahead letters after a short pause, so map it with `Cmd.map` like any other
child. To react to what the user did, compare the state before and after.
-}
update : Msg -> State id -> ( State id, Cmd Msg )
update msg (State s) =
    case msg of
        SetOpen request ->
            if request.focus then
                focusRow request.id (applyOpen request s)

            else
                ( State (applyOpen request s), Cmd.none )

        OpenMany requests ->
            ( State (List.foldl applyOpen s requests), Cmd.none )

        Click id mode visible ->
            focusRow id (applyClick id mode visible s)

        ToggleCheck ids target id ->
            -- A click on the checkbox does not focus the row by itself.
            focusRow id
                { s
                    | checked =
                        if target then
                            List.foldl Set.insert s.checked ids

                        else
                            List.foldl Set.remove s.checked ids
                }

        Focused id ->
            case s.pendingFocus of
                Just pending ->
                    if pending == id then
                        ( State { s | focused = Just id, pendingFocus = Nothing }, Cmd.none )

                    else
                        -- The browser is still catching up with a focus the
                        -- model has moved past: do not move the model back.
                        ( State s, Cmd.none )

                Nothing ->
                    ( State { s | focused = Just id }, Cmd.none )

        FocusDone id ->
            ( State
                (if s.pendingFocus == Just id then
                    { s | pendingFocus = Nothing }

                 else
                    s
                )
            , Cmd.none
            )

        MoveFocus id ->
            focusRow id s

        -- A key that was meant for a row that no longer has the focus (it
        -- arrived before the page was redrawn after the focus moved) is
        -- dropped instead of acting on the wrong row.
        Guard id inner ->
            if s.focused == Just id || s.focused == Nothing then
                update inner (State s)

            else
                ( State s, Cmd.none )

        -- The arrow keys move relative to where the focus is in the model, not
        -- relative to the row that had it when the page was last drawn: keys
        -- that arrive faster than the screen is redrawn still add up.
        Step delta visible ->
            case stepTarget s delta visible of
                Just id ->
                    focusRow id s

                Nothing ->
                    ( State s, Cmd.none )

        StepRange delta visible selectable ->
            case stepTarget s delta visible of
                Just id ->
                    focusRow id
                        (if List.member id selectable then
                            applyClick id Range selectable s

                         else
                            s
                        )

                Nothing ->
                    ( State s, Cmd.none )

        QueryChanged text ->
            ( State { s | query = text, flips = Set.empty, extra = Dict.empty }, Cmd.none )

        ClearQuery ->
            ( State { s | query = "", flips = Set.empty, extra = Dict.empty }, Cmd.none )

        ShowMore key count firstNew ->
            -- The button that was pressed moves down (or goes away): keyboard
            -- focus goes to the first row that was just revealed.
            focusRow firstNew
                { s | extra = Dict.update key (\current -> Just (Maybe.withDefault 0 current + count)) s.extra }

        TypeAhead char visible ->
            let
                buffer =
                    s.typeahead ++ Search.normalize char

                position =
                    s.focused
                        |> Maybe.andThen (\id -> visible |> List.map Tuple.first |> indexOf id)
                        |> Maybe.withDefault -1

                -- One typed letter looks after the current node; more letters
                -- may keep the current node if it still matches.
                start =
                    if String.length buffer <= 1 then
                        position + 1

                    else
                        max 0 position

                ordered =
                    List.drop start visible ++ List.take start visible

                match =
                    ordered
                        |> List.filter (\( _, label ) -> String.startsWith buffer (Search.normalize label))
                        |> List.head

                sequence =
                    s.typeaheadSeq + 1
            in
            case match of
                Just ( id, _ ) ->
                    let
                        ( moved, focusCmd ) =
                            focusRow id { s | typeahead = buffer, typeaheadSeq = sequence }
                    in
                    ( moved
                    , Cmd.batch
                        [ focusCmd
                        , Process.sleep 700 |> Task.perform (\_ -> ClearTypeahead sequence)
                        ]
                    )

                Nothing ->
                    ( State { s | typeahead = "", typeaheadSeq = sequence }, Cmd.none )

        ClearTypeahead sequence ->
            ( if sequence == s.typeaheadSeq then
                State { s | typeahead = "" }

              else
                State s
            , Cmd.none
            )

        Noop ->
            ( State s, Cmd.none )


{-| Move the keyboard focus to a row from the program. The model says at once
which row has the focus; the browser follows a moment later, and the `focus`
events of the rows it passes on the way (when keys come faster than the page is
redrawn) must not move the model back. `pendingFocus` is the row the browser is
on its way to.
-}
focusRow : String -> StateData -> ( State id, Cmd Msg )
focusRow id s =
    ( State { s | focused = Just id, pendingFocus = Just id }
    , Internal.focus (rowDomId s.id id) (FocusDone id)
    )


applyOpen : OpenRequest -> StateData -> StateData
applyOpen request s =
    if String.trim s.query /= "" then
        -- While filtering the nodes with matches below are open by default;
        -- the user's toggles are remembered as differences from that.
        { s
            | flips =
                if request.open == request.forced then
                    Set.remove request.id s.flips

                else
                    Set.insert request.id s.flips
        }

    else
        { s
            | expanded =
                if request.open then
                    Set.insert request.id s.expanded

                else
                    Set.remove request.id s.expanded
        }


applyClick : String -> ClickMode -> List String -> StateData -> StateData
applyClick id mode visible s =
    case mode of
        Replace ->
            { s | selected = Set.singleton id, anchor = Just id, focused = Just id }

        ReplaceOrClear ->
            if s.selected == Set.singleton id then
                { s | selected = Set.empty, anchor = Just id, focused = Just id }

            else
                { s | selected = Set.singleton id, anchor = Just id, focused = Just id }

        Toggle ->
            { s
                | selected =
                    if Set.member id s.selected then
                        Set.remove id s.selected

                    else
                        Set.insert id s.selected
                , anchor = Just id
                , focused = Just id
            }

        Range ->
            case ( Maybe.andThen (\from -> indexOf from visible) s.anchor, indexOf id visible ) of
                ( Just a, Just b ) ->
                    let
                        ( low, high ) =
                            ( min a b, max a b )
                    in
                    { s
                        | selected = visible |> List.drop low |> List.take (high - low + 1) |> Set.fromList
                        , focused = Just id
                    }

                _ ->
                    -- The anchor is not on screen (or cannot be selected):
                    -- start a new range here.
                    { s | selected = Set.singleton id, anchor = Just id, focused = Just id }


{-| The row `delta` steps from the one that has the focus (the first or the last
row when nothing has it yet), never beyond the ends.
-}
stepTarget : StateData -> Int -> List String -> Maybe String
stepTarget s delta visible =
    let
        count =
            List.length visible

        index =
            case s.focused |> Maybe.andThen (\id -> indexOf id visible) of
                Just current ->
                    clamp 0 (count - 1) (current + delta)

                Nothing ->
                    if delta > 0 then
                        0

                    else
                        count - 1
    in
    visible |> List.drop index |> List.head


indexOf : a -> List a -> Maybe Int
indexOf target items =
    items
        |> List.indexedMap Tuple.pair
        |> List.filter (\( _, item ) -> item == target)
        |> List.head
        |> Maybe.map Tuple.first



-- ATTRIBUTES


{-| A setting of a tree. Make them with the functions below and pass a list to
`view` or `viewRemote`; later attributes win over earlier ones.
-}
type Attribute id msg
    = Attribute (Config id msg -> Config id msg)


type alias Config id msg =
    { label : Maybe String
    , multiSelect : Bool
    , allowEmptySelection : Bool
    , checkboxes : Bool
    , filterBox : Bool
    , filterPlaceholder : Maybe String
    , onActivate : Maybe (id -> msg)
    , onRetry : Maybe (id -> msg)
    , onLoadChildren : Maybe (id -> msg)
    , onReload : Maybe msg
    , compact : Bool
    , maxHeight : Maybe Int
    , maxChildren : Int
    , emptyText : Maybe String
    , locale : Locale
    , settings : Settings
    }


configure : List (Attribute id msg) -> Config id msg
configure attributes =
    List.foldl (\(Attribute change) config -> change config)
        { label = Nothing
        , multiSelect = False
        , allowEmptySelection = False
        , checkboxes = False
        , filterBox = False
        , filterPlaceholder = Nothing
        , onActivate = Nothing
        , onRetry = Nothing
        , onLoadChildren = Nothing
        , onReload = Nothing
        , compact = False
        , maxHeight = Nothing
        , maxChildren = 300
        , emptyText = Nothing
        , locale = Locale.default
        , settings = Settings.default
        }
        attributes


{-| The accessible name of the tree, for example "Warehouses". Give every tree
on a page its own name.
-}
ariaLabel : String -> Attribute id msg
ariaLabel text =
    Attribute (\config -> { config | label = Just text })


{-| Several nodes can be selected: `Ctrl` or `Cmd`+click toggles a node,
`Shift`+click selects a range of the visible nodes (nodes that are `disabled` are
skipped), `Shift`+`Up` and `Shift`+`Down` extend the range, and `Space` toggles.
Read the result with `selected`. It does not change how clicks work in a tree with
`checkboxes`.
-}
multiSelect : Attribute id msg
multiSelect =
    Attribute (\config -> { config | multiSelect = True })


{-| A click on the selected node (or `Space`, or `Enter` without `onActivate`) selects
nothing, so the selection can go back to "no node", the normal state of a tree that
filters something else ("all locations"). Without it a selected node stays selected
until another is chosen (or `setSelected` clears it). In a `multiSelect` tree a plain
click on the only selected node clears it too; `Ctrl`+click toggles as before. The
node loses `aria-selected="true"` and its highlight, and keeps the focus.

    Tree.view TreeMsg [ Tree.allowEmptySelection, Tree.ariaLabel "Locations" ] nodes state

-}
allowEmptySelection : Attribute id msg
allowEmptySelection =
    Attribute (\config -> { config | allowEmptySelection = True })


{-| A tri-state checkbox on every node. Checking a parent checks all the leaves
below it; a parent with some of them checked shows a dash. A click anywhere on a
row toggles its checkbox, and so do `Space` and (without `onActivate`) `Enter`.
Rows are not highlighted as selected in this mode. Lazy nodes can be checked once
their children have loaded, and `disabled` nodes are skipped. Read the result with
`checked`.
-}
checkboxes : Attribute id msg
checkboxes =
    Attribute (\config -> { config | checkboxes = True })


{-| A search field above the tree that filters it as the user types. The nodes
whose label contains every typed word are kept, together with their ancestors
(which are opened), and the matching text is highlighted. A hidden status line
tells screen readers how many nodes match. The text is part of the state: see
`query` and `setQuery`.
-}
filterBox : Attribute id msg
filterBox =
    Attribute (\config -> { config | filterBox = True })


{-| The placeholder of the filter box. The default is "Search the tree ...".
-}
filterPlaceholder : String -> Attribute id msg
filterPlaceholder text =
    Attribute (\config -> { config | filterPlaceholder = Just text })


{-| The message to send, given the node id, when the user presses `Enter` on a
node or double-clicks it: open the record, navigate. Without it `Enter` selects
and a double click opens or closes. Nodes that are `disabled` are not activated.
-}
onActivate : (id -> msg) -> Attribute id msg
onActivate toMsg =
    Attribute (\config -> { config | onActivate = Just toMsg })


{-| The message to send, given the node id, when the user presses "Try again" on
a lazy node whose children failed to load. The button is only shown when the
problem is worth retrying (see `Klar.Remote.isRetryable`). Set the children to
`Loading` again and fetch them; `focusNode` keeps the keyboard focus on the node.
-}
onRetry : (id -> msg) -> Attribute id msg
onRetry toMsg =
    Attribute (\config -> { config | onRetry = Just toMsg })


{-| The message to send, given the node id, when the user presses the "Load"
link that the tree shows under an open lazy node that is still `NotAsked`
(nobody has started loading it). A node ends up like that when it was opened
without a request, with `expand`, `setExpanded` or `expandAll`, or when your
`update` did not act on its `loadRequests`. The link lets the user start the
loading by hand. Without this attribute such a node shows a spinner and nothing
loads.
-}
onLoadChildren : (id -> msg) -> Attribute id msg
onLoadChildren toMsg =
    Attribute (\config -> { config | onLoadChildren = Just toMsg })


{-| The message sent by the "Try again" button of `viewRemote` when the top level
failed to load. The button is only shown when the problem is worth retrying.
-}
onReload : msg -> Attribute id msg
onReload msg =
    Attribute (\config -> { config | onReload = Just msg })


{-| Shorter rows (24px instead of 28px): for dense layouts and side panels. A tree
in an application with a compact density (`Klar.Settings`) is already compact; this
makes just this tree compact.
-}
compact : Attribute id msg
compact =
    Attribute (\config -> { config | compact = True })


{-| Makes the tree scroll inside itself when it is taller than this many pixels.
The filter box stays above the scrolling part. Default: no limit.
-}
maxHeight : Int -> Attribute id msg
maxHeight pixels =
    Attribute (\config -> { config | maxHeight = Just pixels })


{-| How many children of one node are rendered before a "Show N more" row. The
default is 300; the value is kept between 10 and 10000. Each press on the row
shows up to that many more and moves the keyboard focus to the first new row.
-}
maxChildren : Int -> Attribute id msg
maxChildren n =
    Attribute (\config -> { config | maxChildren = clamp 10 10000 n })


{-| The text of the empty state when there are no nodes at all. The default is
"No nodes". While a filter matches nothing the tree says "No matches" instead.
-}
emptyText : String -> Attribute id msg
emptyText text =
    Attribute (\config -> { config | emptyText = Just text })


{-| The settings of the application (`Klar.Settings`): the time zone of the time in
"Old data from 14:05". Without it the time is written in UTC and ends in "UTC".

    Tree.settings model.settings

-}
settings : Settings -> Attribute id msg
settings given =
    Attribute (\config -> { config | settings = given })


{-| The language of the built-in text (the filter box, "Loading ...", "Load",
"Try again", "No items", "No matches", "Show N more") and of the numbers. The
default is `Locale.default`, which is English. See [Klar.Locale](Klar-Locale).
-}
locale : Locale -> Attribute id msg
locale value =
    Attribute (\config -> { config | locale = value })



-- TEXT


type alias Texts =
    { filterLabel : String
    , filterPlaceholder : String
    , loading : String
    , loadChildren : String
    , retry : String
    , emptyBranch : String
    , noMatches : String
    , matches : Int -> String
    , showMore : Int -> String
    , noNodes : String
    }


texts : Locale -> Texts
texts loc =
    let
        pick nb en =
            Locale.pick loc { nb = nb, en = en }
    in
    { filterLabel = pick "Filtrer treet" "Filter the tree"
    , filterPlaceholder = pick "Søk i treet ..." "Search the tree ..."
    , loading = pick "Henter ..." "Loading ..."
    , loadChildren = pick "Last inn" "Load"
    , retry = pick "Prøv igjen" "Try again"
    , emptyBranch = pick "Ingen elementer" "No items"
    , noMatches = pick "Ingen treff" "No matches"
    , matches = \n -> Format.int loc n ++ " " ++ Format.plural loc n { one = pick "treff" "match", other = pick "treff" "matches" }
    , showMore = \n -> pick ("Vis " ++ Format.int loc n ++ " flere") ("Show " ++ Format.int loc n ++ " more")
    , noNodes = pick "Ingen noder" "No nodes"
    }



-- FILTERING


type alias Filtered id =
    { nodes : List (Node id)
    , forced : Set String
    , matched : Set String
    }


emptyFiltered : Filtered id
emptyFiltered =
    { nodes = [], forced = Set.empty, matched = Set.empty }


{-| Keep the nodes that match and the ancestors of the nodes that match.
`forced` are the ancestors (opened by the filter), `matched` the matches.
-}
filterNodes : String -> List (Node id) -> Filtered id
filterNodes text nodes =
    filterWith (queryWords text) nodes


{-| The words of the filter text, normalized (case and diacritics ignored).
A node matches when its label contains every word: exactly what the
highlighting marks, so a row is never listed without a visible reason.
-}
queryWords : String -> List String
queryWords text =
    Search.normalize text
        |> String.words
        |> List.filter (\word -> word /= "")


matchesWords : List String -> String -> Bool
matchesWords words label =
    let
        haystack =
            Search.normalize label
    in
    List.all (\word -> String.contains word haystack) words


filterWith : List String -> List (Node id) -> Filtered id
filterWith words nodes =
    List.foldr
        (\node acc ->
            let
                one =
                    filterNode words node
            in
            { nodes = one.nodes ++ acc.nodes
            , forced = Set.union one.forced acc.forced
            , matched = Set.union one.matched acc.matched
            }
        )
        emptyFiltered
        nodes


filterNode : List String -> Node id -> Filtered id
filterNode words (Node n) =
    let
        selfMatch =
            matchesWords words n.label

        inner =
            filterWith words (childNodes n.children)

        belowMatches =
            not (List.isEmpty inner.nodes)

        children =
            if belowMatches then
                case n.children of
                    Branch _ ->
                        Branch inner.nodes

                    Lazy (Remote.Loaded _) ->
                        Lazy (Remote.Loaded inner.nodes)

                    LazyKept freshness _ ->
                        LazyKept freshness inner.nodes

                    other ->
                        other

            else
                n.children
    in
    if selfMatch || belowMatches then
        { nodes = [ Node { n | children = children } ]
        , forced =
            if belowMatches then
                Set.insert n.id inner.forced

            else
                inner.forced
        , matched =
            if selfMatch then
                Set.insert n.id inner.matched

            else
                inner.matched
        }

    else
        emptyFiltered



-- VISIBLE ROWS


{-| What the view and the keyboard need to know about a rendered row.
-}
type alias Row id =
    { id : String
    , value : id
    , depth : Int
    , parent : Maybe String
    , label : String
    , expandable : Bool
    , open : Bool
    , load : Bool
    , forced : Bool
    , disabled : Bool
    }


type alias Env id msg =
    { toMsg : Msg -> msg
    , config : Config id msg
    , t : Texts
    , state : StateData
    , filtering : Bool
    , forced : Set String
    , matched : Set String
    , visibleIds : List String
    , selectableIds : List String
    , tabStop : Maybe String
    , rows : List (Row id)
    , rootNodes : List (Node id)
    }


isOpenIn : StateData -> Bool -> Set String -> String -> Bool -> Bool
isOpenIn s filtering forcedIds id _ =
    if filtering then
        Set.member id forcedIds /= Set.member id s.flips

    else
        Set.member id s.expanded


limitFor : StateData -> Int -> String -> Int
limitFor s base key =
    base + Maybe.withDefault 0 (Dict.get key s.extra)


{-| The rows that are on screen, in order: open branches only, and only the
first children of long branches.
-}
visibleRows : StateData -> Config id msg -> Bool -> Set String -> List (Node id) -> List (Row id)
visibleRows s config filtering forcedIds nodes =
    walk s config filtering forcedIds 0 Nothing nodes


walk : StateData -> Config id msg -> Bool -> Set String -> Int -> Maybe String -> List (Node id) -> List (Row id)
walk s config filtering forcedIds depth parent nodes =
    nodes
        |> List.take (limitFor s config.maxChildren (Maybe.withDefault "" parent))
        |> List.concatMap
            (\(Node n) ->
                let
                    expandable =
                        isExpandable n.children

                    forced =
                        Set.member n.id forcedIds

                    open =
                        expandable && isOpenIn s filtering forcedIds n.id forced

                    row =
                        { id = n.id
                        , value = n.value
                        , depth = depth
                        , parent = parent
                        , label = n.label
                        , expandable = expandable
                        , open = open
                        , load = isUnloaded n.children
                        , forced = forced
                        , disabled = n.disabled
                        }
                in
                row
                    :: (if open then
                            walk s config filtering forcedIds (depth + 1) (Just n.id) (childNodes n.children)

                        else
                            []
                       )
            )



-- IDS


{-| The DOM id of the element of a node: the `li` with `role="treeitem"`, which
is what takes the keyboard focus. It is the id of the tree, `-n-` and the encoded
node id.
-}
rowDomId : String -> String -> String
rowDomId treeId nodeId =
    treeId ++ "-n-" ++ encodeId nodeId


{-| The DOM id of the row inside the element of a node, the part that names the
node (`aria-labelledby`). It is the id of the tree, `-l-` and the encoded node
id. The element of a node has `-n-` in the same place, so the two kinds of id
can never be mistaken for each other, whatever the node ids look like. (A check
on how an id ends, such as `_row`, would not be safe: an encoded node id can end
in the same letters.)
-}
nameDomId : String -> String -> String
nameDomId treeId nodeId =
    treeId ++ "-l-" ++ encodeId nodeId


{-| A node id as something that is safe in a DOM id: letters, digits and "-"
stay; every other character becomes `_` + its code point + `_`. Two different
node ids never give the same result, because `_` only ever starts or ends such a
code.
-}
encodeId : String -> String
encodeId raw =
    raw
        |> String.toList
        |> List.map
            (\c ->
                if (Char.isAlphaNum c && Char.toCode c < 128) || c == '-' then
                    String.fromChar c

                else
                    "_" ++ String.fromInt (Char.toCode c) ++ "_"
            )
        |> String.concat



-- VIEW


{-| The tree. The arguments are the wrapper for the tree's messages, the
attributes, the state and the top-level nodes.

    Tree.view TreeMsg [ Tree.ariaLabel "Warehouses" ] model.tree nodes

With no nodes the tree shows an empty state ("No nodes", or the `emptyText`), and
while a filter matches nothing it says "No matches".

-}
view : (Msg -> msg) -> List (Attribute id msg) -> State id -> List (Node id) -> Html msg
view toMsg attributes (State s) nodes =
    let
        config =
            configure attributes

        t =
            texts config.locale

        filtering =
            String.trim s.query /= ""

        filtered =
            if filtering then
                filterNodes s.query nodes

            else
                { nodes = nodes, forced = Set.empty, matched = Set.empty }

        rows =
            visibleRows s config filtering filtered.forced filtered.nodes

        visibleIds =
            List.map .id rows

        -- A range selection skips the nodes that cannot be selected.
        selectableIds =
            rows |> List.filter (\row -> not row.disabled) |> List.map .id

        tabStop =
            case s.focused of
                Just id ->
                    if List.member id visibleIds then
                        Just id

                    else
                        fallbackStop s visibleIds

                Nothing ->
                    fallbackStop s visibleIds

        env =
            { toMsg = toMsg
            , config = config
            , t = t
            , state = s
            , filtering = filtering
            , forced = filtered.forced
            , matched = filtered.matched
            , visibleIds = visibleIds
            , selectableIds = selectableIds
            , tabStop = tabStop
            , rows = rows
            , rootNodes = filtered.nodes
            }

        filterId =
            s.id ++ "-filter"

        filterView =
            if config.filterBox then
                Html.div
                    [ Internal.cls [ "klar-tree__filter" ]
                    , Internal.onKeys
                        (List.filterMap identity
                            [ Maybe.map (\id -> ( "ArrowDown", toMsg (MoveFocus id) )) tabStop
                            , if s.query /= "" then
                                Just ( "Escape", toMsg ClearQuery )

                              else
                                Nothing
                            ]
                        )
                    ]
                    [ TextInput.view
                        [ TextInput.id filterId
                        , TextInput.label t.filterLabel
                        , TextInput.labelHidden
                        , TextInput.search
                        , TextInput.clearable
                        , TextInput.size Small
                        , TextInput.placeholder (Maybe.withDefault t.filterPlaceholder config.filterPlaceholder)
                        , TextInput.value s.query
                        , TextInput.onInput (\text -> toMsg (QueryChanged text))
                        , TextInput.locale config.locale
                        ]
                    , Html.span [ Internal.cls [ "klar-sr-only" ], Attr.attribute "role" "status" ]
                        [ Html.text
                            (if not filtering then
                                ""

                             else if Set.isEmpty filtered.matched then
                                t.noMatches

                             else
                                t.matches (Set.size filtered.matched)
                            )
                        ]
                    ]

            else
                Html.text ""

        body =
            if List.isEmpty filtered.nodes then
                EmptyState.view
                    [ EmptyState.compact
                    , EmptyState.icon
                        (if filtering then
                            Icon.search

                         else
                            Icon.folder
                        )
                    , EmptyState.title
                        (if filtering then
                            t.noMatches

                         else
                            Maybe.withDefault t.noNodes config.emptyText
                        )
                    ]

            else
                Html.div
                    [ Internal.cls [ "klar-tree__scroll" ]
                    , case config.maxHeight of
                        Just pixels ->
                            Internal.styleVars [ ( "max-height", Internal.px pixels ) ]

                        Nothing ->
                            Internal.noAttr
                    ]
                    [ viewGroup env True 0 Nothing filtered.nodes ]
    in
    Html.div
        [ Internal.cls
            [ "klar-tree-wrap"
            , if config.compact then
                "klar-tree--compact"

              else
                ""
            ]
        ]
        [ filterView, body ]


fallbackStop : StateData -> List String -> Maybe String
fallbackStop s visibleIds =
    case List.filter (\id -> Set.member id s.selected) visibleIds |> List.head of
        Just id ->
            Just id

        Nothing ->
            List.head visibleIds


{-| The same tree for a top level that comes from the backend. `Loaded` shows
the tree, `Failed` shows the problem with a "Try again" button (`onReload`), and
`NotAsked` and `Loading` show a skeleton.

    Tree.viewRemote TreeMsg [ Tree.onReload Reload ] model.tree model.regions

For the children of a single node use `lazy` instead.

-}
viewRemote : (Msg -> msg) -> List (Attribute id msg) -> State id -> Remote (List (Node id)) -> Html msg
viewRemote toMsg attributes state data =
    let
        config =
            configure attributes
    in
    case Freshness.settle data of
        ( Remote.Loaded nodes, Freshness.Fresh ) ->
            view toMsg attributes state nodes

        ( Remote.Loaded nodes, freshness ) ->
            Html.div
                [ Internal.cls [ "klar-tree-fresh", Freshness.className freshness ]
                , Freshness.busyAttr freshness
                ]
                [ Freshness.notice
                    { locale = config.locale, settings = config.settings, onRetry = config.onReload, inline = False }
                    freshness
                , view toMsg attributes state nodes
                ]

        ( Remote.Failed problem, _ ) ->
            ErrorState.view
                (List.filterMap identity
                    [ Just ErrorState.compact
                    , Just (ErrorState.locale config.locale)
                    , Maybe.map ErrorState.onRetry config.onReload
                    ]
                )
                problem

        _ ->
            Html.div [ Internal.cls [ "klar-tree__skeleton" ], Attr.attribute "aria-busy" "true" ]
                (Html.span [ Internal.cls [ "klar-sr-only" ], Attr.attribute "role" "status" ]
                    [ Html.text (texts config.locale).loading ]
                    :: List.map
                        (\( level, width ) ->
                            Html.div
                                [ Internal.cls [ "klar-tree__skeleton-row" ]
                                , Internal.styleVars [ ( "--klar-level", String.fromInt level ) ]
                                , Attr.attribute "aria-hidden" "true"
                                ]
                                [ Skeleton.line width ]
                        )
                        [ ( 0, 55 ), ( 1, 42 ), ( 1, 60 ), ( 2, 38 ), ( 0, 48 ), ( 1, 52 ) ]
                )


{-| One level of the tree: a `ul` with the nodes, plus the "Show N more" row.
-}
viewGroup : Env id msg -> Bool -> Int -> Maybe String -> List (Node id) -> Html msg
viewGroup env isRoot depth parent nodes =
    let
        key =
            Maybe.withDefault "" parent

        limit =
            limitFor env.state env.config.maxChildren key

        shown =
            List.take limit nodes

        hidden =
            List.length nodes - List.length shown

        total =
            List.length nodes

        firstRevealed =
            nodes
                |> List.drop (List.length shown)
                |> List.head
                |> Maybe.map (\(Node n) -> n.id)
                |> Maybe.withDefault ""

        items =
            List.indexedMap
                (\index ((Node n) as node) ->
                    ( n.id, viewNode env depth parent index total node )
                )
                shown

        moreRow =
            if hidden > 0 then
                [ ( "__more"
                  , Html.li [ Internal.cls [ "klar-tree__status" ], Attr.attribute "role" "none", Internal.styleVars [ ( "--klar-level", String.fromInt depth ) ] ]
                        [ Button.view
                            [ Button.link
                            , Button.onClick (env.toMsg (ShowMore key (min hidden env.config.maxChildren) firstRevealed))
                            ]
                            (if hidden <= env.config.maxChildren then
                                env.t.showMore hidden

                             else
                                env.t.showMore env.config.maxChildren ++ " (" ++ Format.int env.config.locale hidden ++ ")"
                            )
                        ]
                  )
                ]

            else
                []
    in
    Keyed.ul
        ([ Internal.cls
            [ if isRoot then
                "klar-tree"

              else
                "klar-tree__group"
            ]
         , Attr.attribute "role"
            (if isRoot then
                "tree"

             else
                "group"
            )
         ]
            ++ (if isRoot then
                    [ Internal.attrMaybe (Attr.attribute "aria-label") env.config.label
                    , Internal.attrMaybe (\stop -> keyHandler env stop (keyBindings env stop)) env.tabStop
                    , Internal.attrIf env.config.multiSelect (Attr.attribute "aria-multiselectable" "true")
                    ]

                else
                    []
               )
        )
        (items ++ moreRow)


viewNode : Env id msg -> Int -> Maybe String -> Int -> Int -> Node id -> Html msg
viewNode env depth parent index total ((Node n) as node) =
    let
        s =
            env.state

        config =
            env.config

        expandable =
            isExpandable n.children

        forced =
            Set.member n.id env.forced

        open =
            expandable && isOpenIn s env.filtering env.forced n.id forced

        isSelected =
            Set.member n.id s.selected

        isTabStop =
            env.tabStop == Just n.id

        -- Only a tree with checkboxes needs to know the leaves below a node.
        terminals =
            if config.checkboxes then
                terminalsOf node

            else
                []

        checkedCount =
            terminals |> List.filter (\id -> Set.member id s.checked) |> List.length

        allChecked =
            if List.isEmpty terminals then
                n.disabled && Set.member n.id s.checked

            else
                checkedCount > 0 && checkedCount == List.length terminals

        someChecked =
            checkedCount > 0 && not allChecked

        -- A lazy node that has not loaded cannot be checked as a whole.
        checkDisabled =
            n.disabled
                || List.isEmpty terminals
                || (case n.children of
                        Lazy (Remote.Loaded _) ->
                            False

                        LazyKept _ _ ->
                            False

                        Lazy _ ->
                            True

                        _ ->
                            False
                   )

        openRequest wantOpen focusAfter =
            { id = n.id
            , open = wantOpen
            , forced = forced
            , load = isUnloaded n.children
            , focus = focusAfter
            }

        selectMsg mode =
            if n.disabled then
                Noop

            else
                Click n.id mode env.selectableIds

        plainClick =
            if config.allowEmptySelection then
                ReplaceOrClear

            else
                Replace

        clickDecoder =
            Decode.map3
                (\ctrl meta shift ->
                    if config.checkboxes then
                        env.toMsg (ToggleCheck terminals (not allChecked) n.id)

                    else if not config.multiSelect then
                        env.toMsg (selectMsg plainClick)

                    else if shift then
                        env.toMsg (selectMsg Range)

                    else if ctrl || meta then
                        env.toMsg (selectMsg Toggle)

                    else
                        env.toMsg (selectMsg plainClick)
                )
                (Decode.field "ctrlKey" Decode.bool)
                (Decode.field "metaKey" Decode.bool)
                (Decode.field "shiftKey" Decode.bool)

        -- A node that cannot be selected cannot be activated either; it can
        -- still be opened and closed.
        doubleClickMsg =
            case ( config.onActivate, n.disabled ) of
                ( Just toApp, False ) ->
                    Just (toApp n.value)

                _ ->
                    if expandable then
                        Just (env.toMsg (SetOpen (openRequest (not open) False)))

                    else
                        Nothing

        label =
            if env.filtering && Set.member n.id env.matched then
                Html.span [ Internal.cls [ "klar-tree__label" ], Attr.title n.label ] (Search.highlight s.query n.label)

            else
                Html.span [ Internal.cls [ "klar-tree__label" ], Attr.title n.label ] [ Html.text n.label ]

        toggle =
            if expandable then
                Html.button
                    [ Internal.cls [ "klar-tree__toggle" ]
                    , Attr.type_ "button"
                    , Attr.tabindex -1
                    , Attr.attribute "aria-hidden" "true"
                    , Internal.onMouseDownPrevent (env.toMsg Noop)
                    , Internal.onClickStop (env.toMsg (SetOpen (openRequest (not open) True)))
                    ]
                    [ Icon.sized Icon.Small Icon.chevronRight ]

            else
                Html.span [ Internal.cls [ "klar-tree__spacer" ] ] []

        checkbox =
            if config.checkboxes then
                Html.span
                    [ Internal.cls [ "klar-tree__check" ]
                    , Internal.onMouseDownPrevent (env.toMsg Noop)
                    , if checkDisabled then
                        Internal.onClickStop (env.toMsg Noop)

                      else
                        Internal.onClickStop (env.toMsg (ToggleCheck terminals (not allChecked) n.id))
                    ]
                    [ Html.span [ Attr.attribute "inert" "" ]
                        [ Checkbox.view
                            [ Checkbox.ariaLabel n.label
                            , Checkbox.checked allChecked
                            , Checkbox.indeterminate someChecked
                            , Checkbox.disabled checkDisabled
                            ]
                        ]
                    ]

            else
                Html.text ""

        trailing =
            [ Internal.viewMaybe (\hint -> Html.span [ Internal.cls [ "klar-tree__hint" ] ] [ Html.text hint ]) n.hint
            , Internal.viewMaybe
                (\count -> Html.span [ Internal.cls [ "klar-tree__count", "klar-tabular" ] ] [ Html.text (Format.int config.locale count) ])
                n.count
            , Internal.viewMaybe
                (\( tone, text ) -> Html.span [ Internal.cls [ "klar-tree__badge" ] ] [ Badge.view [ Badge.tone tone, Badge.size Small ] text ])
                n.badge
            ]

        rowEl =
            Html.div
                ([ Internal.cls
                    [ "klar-tree__row"
                    , if isSelected && not config.checkboxes then
                        "klar-tree__row--selected"

                      else
                        ""
                    , if n.disabled then
                        "klar-tree__row--disabled"

                      else
                        ""
                    ]
                 , Attr.id (nameDomId s.id n.id)
                 , Internal.styleVars [ ( "--klar-level", String.fromInt depth ) ]
                 , Events.on "click" clickDecoder
                 ]
                    ++ (case doubleClickMsg of
                            Just msg ->
                                [ Events.on "dblclick" (Decode.succeed msg) ]

                            Nothing ->
                                []
                       )
                )
                ([ toggle
                 , checkbox
                 , case n.icon of
                    Just glyph ->
                        Html.span [ Internal.cls [ "klar-tree__icon" ] ] [ Icon.view glyph ]

                    Nothing ->
                        Html.text ""
                 , label
                 ]
                    ++ trailing
                )

        childGroup =
            if open then
                [ viewChildren env depth n.id n.value n.children ]

            else
                []
    in
    Html.li
        ([ Internal.cls [ "klar-tree__item" ]
         , Attr.id (rowDomId s.id n.id)
         , Attr.attribute "role" "treeitem"

         -- The name of a node is its own row (label, count, badge), not the
         -- text of everything below it.
         , Attr.attribute "aria-labelledby" (nameDomId s.id n.id)
         , Attr.tabindex
            (if isTabStop then
                0

             else
                -1
            )
         , Attr.attribute "aria-level" (String.fromInt (depth + 1))
         , Attr.attribute "aria-setsize" (String.fromInt total)
         , Attr.attribute "aria-posinset" (String.fromInt (index + 1))
         , Events.on "focus" (Decode.succeed (env.toMsg (Focused n.id)))
         ]
            ++ (if expandable then
                    [ Attr.attribute "aria-expanded"
                        (if open then
                            "true"

                         else
                            "false"
                        )
                    ]

                else
                    []
               )
            ++ (if config.checkboxes then
                    [ Attr.attribute "aria-checked"
                        (if allChecked then
                            "true"

                         else if someChecked then
                            "mixed"

                         else
                            "false"
                        )
                    ]

                else
                    [ Attr.attribute "aria-selected"
                        (if isSelected then
                            "true"

                         else
                            "false"
                        )
                    ]
               )
            ++ (if n.disabled then
                    [ Attr.attribute "aria-disabled" "true" ]

                else
                    []
               )
            ++ (if open && (n.children == Lazy Remote.Loading || lazyBusy n.children) then
                    [ Attr.attribute "aria-busy" "true" ]

                else
                    []
               )
        )
        (rowEl :: childGroup)


{-| The children of an open node: a group, or a status row for lazy nodes.
-}
viewChildren : Env id msg -> Int -> String -> id -> Children id -> Html msg
viewChildren env depth parentId parentValue children =
    let
        statusRow content =
            Html.ul [ Internal.cls [ "klar-tree__group" ], Attr.attribute "role" "group" ]
                [ Html.li
                    [ Internal.cls [ "klar-tree__status" ]
                    , Attr.attribute "role" "none"
                    , Internal.styleVars [ ( "--klar-level", String.fromInt (depth + 1) ) ]
                    ]
                    [ content ]
                ]
    in
    case children of
        Lazy Remote.Loading ->
            statusRow
                (Html.span [ Internal.cls [ "klar-tree__status-text" ], Attr.attribute "role" "status" ]
                    [ Spinner.view [ Spinner.size Small ], Html.text env.t.loading ]
                )

        Lazy Remote.NotAsked ->
            statusRow
                (case env.config.onLoadChildren of
                    Just toApp ->
                        Button.view [ Button.link, Button.onClick (toApp parentValue) ] env.t.loadChildren

                    Nothing ->
                        Html.span [ Internal.cls [ "klar-tree__status-text" ], Attr.attribute "role" "status" ]
                            [ Spinner.view [ Spinner.size Small ], Html.text env.t.loading ]
                )

        Lazy (Remote.Failed problem) ->
            statusRow
                (Html.span [ Internal.cls [ "klar-tree__status-text", "klar-tree__status-text--error" ], Attr.attribute "role" "alert" ]
                    [ Icon.view Icon.errorCircle
                    , Html.span [ Attr.title (Maybe.withDefault (Remote.title env.config.locale problem) (Remote.detail env.config.locale problem)) ] [ Html.text (Remote.title env.config.locale problem) ]
                    , case ( env.config.onRetry, Remote.isRetryable problem ) of
                        ( Just toApp, True ) ->
                            Button.view [ Button.link, Button.icon Icon.refresh, Button.onClick (toApp parentValue) ] env.t.retry

                        _ ->
                            Html.text ""
                    ]
                )

        Lazy (Remote.Loaded []) ->
            statusRow (Html.span [ Internal.cls [ "klar-tree__status-text" ] ] [ Html.text env.t.emptyBranch ])

        LazyKept freshness nodes ->
            let
                notice =
                    Freshness.notice
                        { locale = env.config.locale
                        , settings = env.config.settings
                        , onRetry = Maybe.map (\toApp -> toApp parentValue) env.config.onRetry
                        , inline = True
                        }
                        freshness
            in
            case freshness of
                Freshness.Stale _ ->
                    Html.ul [ Internal.cls [ "klar-tree__group" ], Attr.attribute "role" "group" ]
                        (Html.li
                            [ Internal.cls [ "klar-tree__status" ]
                            , Attr.attribute "role" "none"
                            , Internal.styleVars [ ( "--klar-level", String.fromInt (depth + 1) ) ]
                            ]
                            [ notice ]
                            :: [ viewGroup env False (depth + 1) (Just parentId) nodes ]
                        )

                _ ->
                    viewGroup env False (depth + 1) (Just parentId) nodes

        _ ->
            viewGroup env False (depth + 1) (Just parentId) (childNodes children)


{-| The leaves under a node, as far as they are known: what a checkbox on
the node stands for.
-}
terminalsOf : Node id -> List String
terminalsOf (Node n) =
    let
        own =
            if n.disabled then
                []

            else
                [ n.id ]
    in
    case n.children of
        Leaf ->
            own

        Branch [] ->
            own

        Branch nodes ->
            List.concatMap terminalsOf nodes

        Lazy (Remote.Loaded []) ->
            own

        Lazy (Remote.Loaded nodes) ->
            List.concatMap terminalsOf nodes

        LazyKept _ nodes ->
            List.concatMap terminalsOf nodes

        Lazy _ ->
            -- Children that have not loaded yet: nothing below can be checked
            -- (the node itself is not a leaf, so it is not reported as one).
            []



-- KEYBOARD


{-| The keys of the tree. One handler on the tree itself, made for the row that
is the tab stop (the row the model says has the focus). It sits on the tree, not
on that row: when the focus has just moved, the browser needs a moment to follow,
and a key pressed in between would otherwise land on a row without a handler and
be lost. It ignores keys that come from controls inside a row (buttons, the
checkbox).
-}
keyHandler : Env id msg -> String -> List ( String, msg ) -> Html.Attribute msg
keyHandler env nodeId bindings =
    let
        visible =
            List.map (\row -> ( row.id, row.label )) env.rows
    in
    Events.preventDefaultOn "keydown"
        (Decode.at [ "target", "id" ] Decode.string
            |> Decode.andThen
                (\targetId ->
                    if not (isRowId env.state.id targetId) then
                        Decode.fail "from inside the row"

                    else
                        Internal.keyEvent
                            |> Decode.andThen
                                (\event ->
                                    let
                                        name =
                                            keyName event
                                    in
                                    case List.filter (\( key, _ ) -> key == name) bindings |> List.head of
                                        Just ( _, msg ) ->
                                            Decode.succeed ( msg, True )

                                        Nothing ->
                                            if String.length event.key == 1 && event.key /= " " && not event.ctrl && not event.meta && not event.alt then
                                                Decode.succeed ( env.toMsg (TypeAhead event.key visible), True )

                                            else
                                                Decode.fail "unhandled key"
                                )
                )
        )


{-| Is this DOM id the id of a node (and not of something inside it)? Only the
element of a node has an id that starts with the id of the tree and `-n-` (see
`rowDomId`); the row inside it starts with `-l-` (see `nameDomId`), and the
controls inside a row have no id of this kind at all.
-}
isRowId : String -> String -> Bool
isRowId treeId domId =
    String.startsWith (treeId ++ "-n-") domId


keyName : Internal.KeyEvent -> String
keyName event =
    (if event.ctrl then
        "Ctrl+"

     else
        ""
    )
        ++ (if event.meta then
                "Meta+"

            else
                ""
           )
        ++ (if event.alt then
                "Alt+"

            else
                ""
           )
        ++ (if event.shift && String.length event.key > 1 then
                "Shift+"

            else
                ""
           )
        ++ event.key


keyBindings : Env id msg -> String -> List ( String, msg )
keyBindings env nodeId =
    let
        rows =
            env.rows

        position =
            indexOf nodeId (List.map .id rows) |> Maybe.withDefault 0

        at index =
            rows |> List.drop index |> List.head

        current =
            at position

        move target =
            env.toMsg (MoveFocus target.id)

        -- For the keys that act on this very row.
        held msg =
            env.toMsg (Guard nodeId msg)

        first =
            List.head rows

        last =
            List.head (List.reverse rows)

        request row wantOpen =
            { id = row.id
            , open = wantOpen
            , forced = row.forced
            , load = row.load
            , focus = False
            }

        parentRow row =
            row.parent |> Maybe.andThen (\pid -> rows |> List.filter (\r -> r.id == pid) |> List.head)

        siblings row =
            rows |> List.filter (\r -> r.parent == row.parent && r.expandable && not r.open)

        node =
            current

        isDisabled =
            current |> Maybe.map .disabled |> Maybe.withDefault False

        activate =
            case ( env.config.onActivate, isDisabled ) of
                ( Just toApp, False ) ->
                    current |> Maybe.map (\row -> toApp row.value)

                _ ->
                    Nothing

        plainSelect =
            if env.config.allowEmptySelection then
                ReplaceOrClear

            else
                Replace

        selectKey mode =
            if env.config.checkboxes then
                held (ToggleCheck (checkTargets env nodeId) (not (allCheckedFor env nodeId)) nodeId)

            else if isDisabled then
                env.toMsg Noop

            else
                held (Click nodeId mode env.selectableIds)

        -- Enter: open the record, or select. A node that cannot be selected
        -- is only opened or closed.
        enterMsg =
            case ( activate, current ) of
                ( Just msg, _ ) ->
                    msg

                ( Nothing, Just row ) ->
                    if isDisabled && not env.config.checkboxes then
                        if row.expandable then
                            held (SetOpen (request row (not row.open)))

                        else
                            env.toMsg Noop

                    else
                        selectKey plainSelect

                ( Nothing, Nothing ) ->
                    selectKey plainSelect
    in
    List.filterMap identity
        [ Just ( "ArrowDown", env.toMsg (Step 1 env.visibleIds) )
        , Just ( "ArrowUp", env.toMsg (Step -1 env.visibleIds) )
        , Maybe.map (\row -> ( "Home", move row )) first
        , Maybe.map (\row -> ( "End", move row )) last
        , node
            |> Maybe.andThen
                (\row ->
                    if row.expandable && not row.open then
                        Just ( "ArrowRight", held (SetOpen (request row True)) )

                    else if row.open then
                        Just ( "ArrowRight", held (Step 1 env.visibleIds) )

                    else
                        Nothing
                )
        , node
            |> Maybe.andThen
                (\row ->
                    if row.open then
                        Just ( "ArrowLeft", held (SetOpen (request row False)) )

                    else
                        parentRow row |> Maybe.map (\parent -> ( "ArrowLeft", held (MoveFocus parent.id) ))
                )
        , node
            |> Maybe.andThen
                (\row ->
                    case siblings row of
                        [] ->
                            Nothing

                        closed ->
                            Just ( "*", held (OpenMany (List.map (\r -> request r True) closed)) )
                )
        , Just ( "Enter", enterMsg )
        , Just
            ( " "
            , selectKey
                (if env.config.multiSelect then
                    Toggle

                 else
                    plainSelect
                )
            )
        , if env.config.multiSelect && not env.config.checkboxes then
            Just ( "Shift+ArrowDown", env.toMsg (StepRange 1 env.visibleIds env.selectableIds) )

          else
            Nothing
        , if env.config.multiSelect && not env.config.checkboxes then
            Just ( "Shift+ArrowUp", env.toMsg (StepRange -1 env.visibleIds env.selectableIds) )

          else
            Nothing
        ]


{-| In a tree with checkboxes `Space` and `Enter` toggle the checkbox: these
look the node up again to know what it stands for.
-}
checkTargets : Env id msg -> String -> List String
checkTargets env nodeId =
    case findNode nodeId env.rootNodes of
        Just node ->
            terminalsOf node

        Nothing ->
            [ nodeId ]


allCheckedFor : Env id msg -> String -> Bool
allCheckedFor env nodeId =
    let
        targets =
            checkTargets env nodeId

        count =
            targets |> List.filter (\id -> Set.member id env.state.checked) |> List.length
    in
    count > 0 && count == List.length targets


findNode : String -> List (Node id) -> Maybe (Node id)
findNode id nodes =
    case nodes of
        [] ->
            Nothing

        ((Node n) as node) :: rest ->
            if n.id == id then
                Just node

            else
                case findNode id (childNodes n.children) of
                    Just found ->
                        Just found

                    Nothing ->
                        findNode id rest
