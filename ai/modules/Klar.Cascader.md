# Klar.Cascader

A field for choosing a path through levels: Region, Country, City; Category, Subcategory, Product.

Import: `import Klar.Cascader as Cascader` | Group: Choosing

Types: `Msg`, `State`, `Attribute`

## Signatures

```elm
-- State
type State id  -- opaque: no constructors are exposed
type Msg id  -- opaque: no constructors are exposed
init : String -> State id
update : Msg id -> State id -> ( State id, Cmd (Msg id) )
view : (Msg id -> msg) -> List (Attribute id msg) -> State id -> Html msg

-- Value
value : State id -> Maybe (List id)
setValue : Picking.Ids id -> List id -> State id -> State id
setPath : List (Picking.Node id) -> State id -> State id
clear : State id -> State id

-- Popup and lazy nodes
query : State id -> String
isOpen : State id -> Bool
open : State id -> ( State id, Cmd (Msg id) )
close : State id -> ( State id, Cmd (Msg id) )
loadRequests : State id -> List id

-- Attributes
type Attribute id msg  -- opaque: no constructors are exposed
nodes : List (Picking.Node id) -> Attribute id msg
remote : Remote.Remote (List (Picking.Node id)) -> Attribute id msg
onRetry : msg -> Attribute id msg
onRetryChildren : (id -> msg) -> Attribute id msg
anyNode : Attribute id msg
separator : String -> Attribute id msg

-- Field
label : String -> Attribute id msg
labelHidden : Attribute id msg
hint : String -> Attribute id msg
error : String -> Attribute id msg
errorMaybe : Maybe String -> Attribute id msg
required : Attribute id msg
optionalText : String -> Attribute id msg

-- Behavior and looks
placeholder : String -> Attribute id msg
searchPlaceholder : String -> Attribute id msg
clearable : Attribute id msg
valueText : (id -> String) -> Attribute id msg
disabled : Bool -> Attribute id msg
readOnly : Bool -> Attribute id msg
size : Theme.Size -> Attribute id msg
visibleRows : Int -> Attribute id msg
locale : Locale.Locale -> Attribute id msg
```

## Documentation

A field for choosing a path through levels: Region, Country, City; Category,
Subcategory, Product. The popup shows one column for each level, like a file
browser, and the closed field shows the path ("Europe / Norway / Oslo").

Use when: the user thinks in levels and knows where to look.
Do not use when: the user picks from a tree with check boxes (as `Klar.TreeSelect`) or from one flat list (as `Klar.Select`).
Quick path: `init`, `update`, `view`, `nodes`, `value`

See also [Klar.TreeSelect](Klar.TreeSelect.md) and [Klar.Select](Klar.Select.md).

    import Klar.Cascader as Cascader
    import Klar.Picking as Picking

    -- model: one State per field; the String is a DOM id, unique on the page
    type alias Model =
        { place : Cascader.State PlaceId }

    init =
        { place = Cascader.init "place" }

    -- update
    PlaceMsg inner ->
        let
            ( place, cmd ) =
                Cascader.update inner model.place
        in
        ( { model | place = place }, Cmd.map PlaceMsg cmd )

    -- view
    Cascader.view PlaceMsg
        [ Cascader.label "Place"
        , Cascader.nodes
            [ Picking.branch placeIds europe
                "Europe"
                [ Picking.branch placeIds norway "Norway" [ Picking.leaf placeIds oslo "Oslo" ] ]
            ]
        , Cascader.clearable
        ]
        model.place

    -- reading the value: the path from the top down
    Cascader.value model.place --> Maybe (List PlaceId)

The nodes are built with [Klar.Picking](Klar.Picking.md), the same as for a
[Klar.TreeSelect](Klar.TreeSelect.md), so one hierarchy serves both. The value is the
path of ids from the top level down to the node that was chosen: `Just [ europe,
norway, oslo ]`, or `Nothing` when nothing is chosen (an empty path cannot exist).
By default only a node without children can be chosen; `anyNode` also lets the user
choose a branch. As in every Klar field, the state holds the value and there are no
out-messages: compare `Cascader.value` before and after `update` to react.

A path that is not a path of the nodes you give (a place that was removed, a saved
path through a branch that is not loaded) is not dropped: the field shows the
labels it remembers from when the path was chosen or set with `setPath`, and
otherwise "Unknown value" (or what `valueText` writes).

Typing in the search box leaves the columns and shows a flat list of the full paths
that match ("oslo" finds "Europe / Norway / Oslo"), best match first; clearing the
text brings the columns back as they were. Only the rows on screen are drawn, in
every column and in the list of results (see [Klar.VirtualList](Klar.VirtualList.md)),
so a level with thousands of nodes stays fast.

Nodes can come from the backend, the top level as a `Remote` (`remote`) and the
children of a node with `Picking.lazy`. When the user opens a lazy node whose
children are `NotAsked`, `loadRequests` names it (call it after every update); mark it `Loading`,
fetch it, and put the answer in the node the next time you build the tree. A branch
that failed shows the problem with a "Try again" button (`onRetryChildren`).

Keyboard: on the closed field Enter, Space, ArrowDown, ArrowUp or a printable
character open the popup. The keyboard focus stays in the search box, and the
highlight is shown with `aria-activedescendant`. ArrowDown and ArrowUp move in the
column, Home and End go to its first and last node, PageUp and PageDown move a
page. ArrowRight opens the highlighted branch and then moves into its column,
ArrowLeft closes the open branch and then moves back to its parent (in a text they
move the caret instead, until it is at the end or the start). Enter chooses the
highlighted node when it can be chosen, and otherwise opens the branch like
ArrowRight. Escape closes the popup and returns to the field, and Tab closes it and
moves on. In the list of search results ArrowDown, ArrowUp, Home, End and Enter
work on the results. Typing searches, so there is no separate type-ahead.

Accessibility: no standard pattern describes columns, so a cascader is a tree that
is drawn in columns. The field is a button with `role="combobox"` and
`aria-haspopup="tree"`; the popup is a `tree` whose `treeitem` rows have
`aria-level` (the column), `aria-setsize` and `aria-posinset` (among the nodes of
their column), `aria-expanded` (the opened branch) and `aria-selected` (the path
that is chosen). The list of search results is a `listbox`. The field also lists
the whole path for a screen reader when the visible path is shortened. The
built-in text follows `locale` and is English by default (see
[Klar.Locale](Klar.Locale.md)).

On a narrow screen the columns do not wrap: the popup scrolls sideways, and
opening a branch scrolls to its column. Right-to-left languages are not supported:
the arrow keys and the order of the columns assume left-to-right text.

## State

### `State`

```elm
type State id  -- opaque: no constructors are exposed
```

Everything one cascader keeps track of: the chosen path, whether the popup is
open, the search text, which branches are open and which row is highlighted. Make
it with `init`, keep it in your model and pass it to `view` and `update`. The
`id` is the type of your ids.

### `Msg`

```elm
type Msg id  -- opaque: no constructors are exposed
```

The messages a cascader sends. Wrap it in a constructor of your own message
type (`PlaceMsg Cascader.Msg`), give that constructor to `view`, and pass the
messages you get back to `update`.

### `init`

```elm
init : String -> State id
```

A closed cascader with nothing chosen. The `String` is the DOM id of the
field and must be unique on the page: the label points to it, and the ids of the
popup are derived from it (`place-search`, `place-tree`, `place-popup`).

    Cascader.init "place"

### `update`

```elm
update : Msg id -> State id -> ( State id, Cmd (Msg id) )
```

Handles a message of the cascader and returns the new state with a command
(moving focus, scrolling the columns). Map the command into your own message type
with `Cmd.map`.

    PlaceMsg inner ->
        let
            ( place, cmd ) =
                Cascader.update inner model.place
        in
        ( { model | place = place }, Cmd.map PlaceMsg cmd )

### `view`

```elm
view : (Msg id -> msg) -> List (Attribute id msg) -> State id -> Html msg
```

The cascader. It takes the constructor that wraps the component's `Msg` in
your own message type, a list of attributes, and the state.

    Cascader.view PlaceMsg
        [ Cascader.label "Place"
        , Cascader.nodes places
        , Cascader.required
        ]
        model.place

Always give the field a `label`; `labelHidden` keeps it off the screen but
available to screen readers.

## Value

### `value`

```elm
value : State id -> Maybe (List id)
```

The chosen path from the top down, or `Nothing` when nothing is chosen. A path
set with `setValue` is returned at once, also while the nodes are still loading.

### `setValue`

```elm
setValue : Picking.Ids id -> List id -> State id -> State id
```

Chooses a path from your code, for example to show a saved record. The labels
are looked up in the nodes when the field is shown; use `setPath` when the nodes
may not contain them (a branch that is not loaded). An empty list clears the
value.

    Cascader.setValue placeIds [ europe, norway, oslo ] model.place

### `setPath`

```elm
setPath : List (Picking.Node id) -> State id -> State id
```

Chooses a path of nodes and remembers their labels, so the field shows the
path even when the nodes you give do not contain it. Only the nodes themselves are
used, not their children. An empty list clears the value.

    Cascader.setPath [ europeNode, norwayNode, osloNode ] model.place

### `clear`

```elm
clear : State id -> State id
```

Removes the chosen path, so `value` is `Nothing` again.

## Popup and lazy nodes

### `query`

```elm
query : State id -> String
```

The text in the search box while the popup is open, and `""` when it is
closed.

### `isOpen`

```elm
isOpen : State id -> Bool
```

Whether the popup is open.

### `open`

```elm
open : State id -> ( State id, Cmd (Msg id) )
```

Opens the popup with an empty search and moves focus into its search box, for
example from a button of your own. Map the command like the one from `update`.

### `close`

```elm
close : State id -> ( State id, Cmd (Msg id) )
```

Closes the popup, forgets the search text, and gives focus back to the field
if the popup was open. Map the command like the one from `update`.

### `loadRequests`

```elm
loadRequests : State id -> List id
```

The lazy nodes whose children somebody is waiting for: the open branches of the
open popup whose children are `NotAsked`. Usually zero or one. Call it after every
`update` of the field. Set the children of the nodes it names to `Loading` in your
data and fetch them; the next time you build the nodes they hold the answer.
Asking again is harmless, because a node you have marked `Loading` is not named
any more.

    PlaceMsg inner ->
        let
            ( place, cmd ) =
                Cascader.update inner model.place

            requested =
                Cascader.loadRequests place
        in
        ( { model | place = place, areas = markLoading requested model.areas }
        , Cmd.batch (Cmd.map PlaceMsg cmd :: List.map fetchAreas requested)
        )

The answer is worked out from the nodes of the last message the field got, so if
you set a node back to `NotAsked` yourself (to load it again), you also fetch it
yourself: the field asks again only after its next message. After a failure the
user retries with the button that `onRetryChildren` adds.

## Attributes

Pass attributes to `view` in a list; later ones win over earlier ones.

### `Attribute`

```elm
type Attribute id msg  -- opaque: no constructors are exposed
```

A setting of a cascader. Make them with the functions below and pass a list to
`view`; later attributes win over earlier ones.

### `nodes`

```elm
nodes : List (Picking.Node id) -> Attribute id msg
```

The top level of the hierarchy, built with `Picking.leaf`, `Picking.branch` and
`Picking.lazy`. The default is no nodes. Use `nodes` or `remote`, not both: the
later one wins.

    Cascader.nodes [ Picking.branch placeIds europe "Europe" [ Picking.leaf placeIds oslo "Oslo" ] ]

### `remote`

```elm
remote : Remote.Remote (List (Picking.Node id)) -> Attribute id msg
```

The top level of the hierarchy from the backend, as a `Remote` (see
[Klar.Remote](Klar.Remote.md)). The popup shows loading rows while the data is
`Loading` or `NotAsked`, a compact error with a retry button on `Failed` (see
`onRetry`), the empty state on `Loaded []`, and the columns on `Loaded`.

    Cascader.remote model.places

### `onRetry`

```elm
onRetry : msg -> Attribute id msg
```

The message to send when the user presses the "Try again" button of the error
shown when the top level (`remote`) failed to load. The button appears only for
problems that are worth retrying (network trouble, timeouts, server errors); while
it is shown, Enter in the search box sends the message as well.

### `onRetryChildren`

```elm
onRetryChildren : (id -> msg) -> Attribute id msg
```

The message to send, given the node id, when the user presses "Try again" on a
branch whose children failed to load (Enter does the same while that row is
highlighted). The button is only shown for problems that are worth retrying. Set
the children of that node to `Loading` again and fetch them.

    Cascader.onRetryChildren ReloadAreas

### `anyNode`

```elm
anyNode : Attribute id msg
```

Lets the user choose a node that has children as well as a node without. The
default is that only a node without children can be chosen, which is what a path of
levels usually means (a city, not a country). With `anyNode`, ArrowRight and a
click open a branch and Enter, a double click or the button under the columns
choose it; the value is then a shorter path.

### `separator`

```elm
separator : String -> Attribute id msg
```

The text between the labels of a path, in the field and in the list of search
results. The default is `" / "`.

    Cascader.separator " > "

## Field

The label, hint and error around the field work the same in every Klar form
control.

### `label`

```elm
label : String -> Attribute id msg
```

The label above the field. It names the cascader for screen readers.

### `labelHidden`

```elm
labelHidden : Attribute id msg
```

Keeps the label for screen readers but does not draw it. It needs a `label`.

### `hint`

```elm
hint : String -> Attribute id msg
```

A short help text under the field. Screen readers read it with the field.

### `error`

```elm
error : String -> Attribute id msg
```

Shows an error message under the field and marks the field invalid
(`aria-invalid`). The message is announced to screen readers when it appears.

### `errorMaybe`

```elm
errorMaybe : Maybe String -> Attribute id msg
```

Like `error`, but takes a `Maybe`: `Nothing` shows no error. Handy with a
validation result.

### `required`

```elm
required : Attribute id msg
```

Marks the field as required: an asterisk after the label and `aria-required`.
It does not validate anything; show a problem with `error`.

### `optionalText`

```elm
optionalText : String -> Attribute id msg
```

A text after the label of a field that is not `required`, such as
"(optional)".

## Behavior and looks

### `placeholder`

```elm
placeholder : String -> Attribute id msg
```

The text shown while nothing is chosen. Default "Select ..." (in the language
of `locale`).

### `searchPlaceholder`

```elm
searchPlaceholder : String -> Attribute id msg
```

The placeholder of the search box in the open popup. Default "Search ...".

### `clearable`

```elm
clearable : Attribute id msg
```

Shows a small x in the field that removes the chosen path. Backspace and
Delete do the same on the focused field. Nothing is shown while no path is chosen.

### `valueText`

```elm
valueText : (id -> String) -> Attribute id msg
```

How to write an id when the field cannot find the labels of the chosen path:
the path is not a path of the nodes you give and the field has not seen the nodes
itself. The ids are written with this function and joined by the `separator`.
Without it the field says "Unknown value".

    Cascader.valueText PlaceId.toString

### `disabled`

```elm
disabled : Bool -> Attribute id msg
```

While `True` the field is dimmed, cannot be focused or opened, and has no
clear button. The value is kept. The default is `False`.

### `readOnly`

```elm
readOnly : Bool -> Attribute id msg
```

While `True` the field shows its value but does not let the user change it:
the popup does not open, and there is no chevron or clear button. Unlike
`disabled`, a read-only field can be focused. The two are independent; with both
set the field is disabled. The default is `False`.

### `size`

```elm
size : Theme.Size -> Attribute id msg
```

The height of the field: `Small`, `Medium` or `Large` from
[Klar.Theme](Klar.Theme.md). The default is `Medium`.

### `visibleRows`

```elm
visibleRows : Int -> Attribute id msg
```

How many rows a column shows before it scrolls. The default is 8; numbers
below 3 or above 20 are brought into that range.

### `locale`

```elm
locale : Locale.Locale -> Attribute id msg
```

The language of the built-in text: the placeholders, the search box, the
counts, the loading and error states and the labels for screen readers. The
default is `Locale.default`, which is English. See [Klar.Locale](Klar.Locale.md).

    Cascader.locale Locale.nb
