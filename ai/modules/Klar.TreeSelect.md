# Klar.TreeSelect

A field that opens a popup with a tree and lets the user choose one node, or several with check boxes.

Import: `import Klar.TreeSelect as TreeSelect` | Group: Choosing

Types: `Msg`, `Mode`, `State`, `Single`, `Multiple`, `Attribute`

## Signatures

```elm
-- State
type State mode id  -- opaque: no constructors are exposed
type Msg id  -- opaque: no constructors are exposed
init : String -> Mode mode -> State mode id
update : Msg id -> State mode id -> ( State mode id, Cmd (Msg id) )
view : (Msg id -> msg) -> List (Attribute id msg) -> State mode id -> Html msg

-- Single or multiple
type Mode mode  -- opaque: no constructors are exposed
type Single  -- opaque: no constructors are exposed
type Multiple  -- opaque: no constructors are exposed
single : Mode Single
multiple : Mode Multiple

-- Value
value : State Single id -> Maybe id
setValue : Ids.Ids id -> Maybe id -> State Single id -> State Single id
setNode : Picking.Node id -> State Single id -> State Single id
values : State Multiple id -> List id
setValues : Ids.Ids id -> List id -> State Multiple id -> State Multiple id
setNodes : List (Picking.Node id) -> State Multiple id -> State Multiple id
leaves : List (Picking.Node id) -> State Multiple id -> List id
clear : State mode id -> State mode id

-- Popup and lazy nodes
query : State mode id -> String
isOpen : State mode id -> Bool
open : State mode id -> ( State mode id, Cmd (Msg id) )
close : State mode id -> ( State mode id, Cmd (Msg id) )
loadRequests : State mode id -> List id

-- Attributes
type Attribute id msg  -- opaque: no constructors are exposed
nodes : List (Picking.Node id) -> Attribute id msg
remote : Remote.Remote (List (Picking.Node id)) -> Attribute id msg
onRetry : msg -> Attribute id msg
onRetryChildren : (id -> msg) -> Attribute id msg

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
maxVisibleChips : Int -> Attribute id msg
locale : Locale.Locale -> Attribute id msg
settings : Settings.Settings -> Attribute id msg
```

## Documentation

A field that opens a popup with a tree and lets the user choose one node, or
several with check boxes.

Use when: the user picks from a hierarchy that is too big for a plain list (regions and warehouses, product categories, an organisation).
Do not use when: the list is short and flat (as `Klar.Select` or `Klar.MultiSelect`), the user drills down through levels (as `Klar.Cascader`) or the tree is shown on the page itself (as `Klar.Tree`).
Quick path: `init`, `update`, `view`, `nodes`, `value`

See also [Klar.Select](Klar.Select.md), [Klar.MultiSelect](Klar.MultiSelect.md),
[Klar.Cascader](Klar.Cascader.md) and [Klar.Tree](Klar.Tree.md).

    import Klar.Picking as Picking
    import Klar.TreeSelect as TreeSelect

    -- how a SiteId is written as a key, once
    siteIds : Ids SiteId
    siteIds =
        Ids.make { toKey = SiteId.toString, fromKey = SiteId.fromString }

    -- model: one State per field; the String is a DOM id, unique on the page
    type alias Model =
        { site : TreeSelect.State TreeSelect.Single SiteId }

    init =
        { site = TreeSelect.init "site" TreeSelect.single }

    -- update
    SiteMsg inner ->
        let
            ( site, cmd ) =
                TreeSelect.update inner model.site
        in
        ( { model | site = site }, Cmd.map SiteMsg cmd )

    -- view
    TreeSelect.view SiteMsg
        [ TreeSelect.label "Warehouse"
        , TreeSelect.nodes
            [ Picking.branch siteIds oslo "Oslo" [ Picking.leaf siteIds hall3 "Hall 3" ] ]
        , TreeSelect.clearable
        ]
        model.site

    -- reading the value
    TreeSelect.value model.site --> Maybe SiteId

The mode is the one choice you make when you create the field: `single` for one
node, `multiple` for any number. It is part of the type, so `value` only works on
a single field and `values` on a multiple one. As in every Klar field, the state
holds the value, and there are no out-messages: compare the value before and after
`update` to react (`TreeSelect.value new /= TreeSelect.value old`).

**What a checked box means** (`multiple`). Checking a node chooses it and
everything below it, so checking "Europe" puts one id, `europe`, in the value, also
when Europe holds a thousand warehouses and some of them are not loaded yet. A node
with only some of its nodes checked shows a dash. The value is kept as short as it
can be: when all the children of a node are checked they are replaced by the node,
and when the user unchecks one node of a checked branch, the branch is replaced by
what is left of it. A node that is `disabled` is never chosen: checking its parent
chooses the nodes around it one by one, and the parent shows a check when all of
them are chosen. To get the warehouses and not the regions, ask for `leaves`.

That promise has one price: with a `disabled` node somewhere under "Europe", checking
"Europe" cannot say `europe` (it would include the disabled node), so the value is
one id for each part of Europe that has nothing disabled inside it, which can be
many. Without disabled nodes below it, a checked branch is always one id.

Typing in the search box filters the tree: it keeps the nodes that contain every
word, with the nodes above them, opened and with the matching text highlighted.
When the text is cleared the tree is as the user left it. Only nodes that are in
your data are searched, so the children of a lazy node that is not loaded are not.
Only the rows on screen are drawn (see [Klar.VirtualList](Klar.VirtualList.md)), so
a tree of many thousands of nodes stays fast.

Nodes can come from the backend: the top level as a `Remote` (`remote`), and the
children of a node with `Picking.lazy`. When the user opens a lazy node that is
`NotAsked`, `loadRequests` names it once (call it after every update), so that you
can mark it `Loading` and fetch it; a failed branch shows the problem and a "Try
again" button (`onRetryChildren`) and does not block the rest of the tree. Data
that is `Kept` stays on screen: a node whose children are refreshed is busy, and
children that are old after a failed refresh sit under a row that says "Old data
from 14:05" with "Try again" (the top level says it above the tree; give `settings`
for the time zone). Nothing else is loaded behind your back.

Keyboard: on the closed field Enter, Space, ArrowDown, ArrowUp or a printable
character open the popup (the character starts the search). The keyboard focus
stays in the search box while the popup is open, and the arrow keys move a
highlight (`aria-activedescendant`): ArrowDown and ArrowUp, PageUp and PageDown,
and Home and End (in a text Home and End move the caret, and Ctrl or Cmd with them
move the highlight). ArrowRight opens a closed node and then moves into it, ArrowLeft
closes an open node and then moves to its parent; in a text they move the caret
instead, until it is at the end (right) or the start (left). Enter chooses the
highlighted node (in a multiple field it checks or unchecks it and the popup stays
open), and Space does the same while the search box is empty. `*` opens all nodes
on the highlighted level while the search box is empty. Escape closes the popup and
returns to the field, and Tab closes it and moves on. Typing letters searches
instead of jumping to the next node whose name starts with them: the search is the
type-ahead.

Accessibility: the field is a button with `role="combobox"` and
`aria-haspopup="tree"`. The open popup is a `tree` of `treeitem` rows with
`aria-level`, `aria-setsize`, `aria-posinset` and `aria-expanded`, and
`aria-selected` (single) or `aria-checked` (multiple, with `mixed` for the dash, and
`aria-multiselectable` on the tree). The counts under the tree are announced politely. The built-in text follows
`locale` and is English by default (see [Klar.Locale](Klar.Locale.md)).

Limits: a node must have a unique id in the whole tree, ids are compared through
their key (see [Klar.Picking](Klar.Picking.md)), and a value that is not in the tree
you give is shown as "Unknown value" unless you say how to write it (`valueText`)
or give the component its node (`setNode`, `setNodes`). On the closed field of a
multiple field Backspace removes the last chosen id, which can be a whole branch
(the Select family does the same for its chips). Right-to-left languages are not
supported: the arrow keys and the indents assume left-to-right text.

## State

### `State`

```elm
type State mode id  -- opaque: no constructors are exposed
```

Everything one field keeps track of: the chosen nodes, whether the popup is
open, the search text, which nodes are open and which row is highlighted. Make
it with `init`, keep it in your model and pass it to `view` and `update`. The
`mode` is `Single` or `Multiple`, and `id` the type of your ids.

### `Msg`

```elm
type Msg id  -- opaque: no constructors are exposed
```

The messages a field sends. Wrap it in a constructor of your own message type
(`SiteMsg TreeSelect.Msg`), give that constructor to `view`, and pass the messages
you get back to `update`.

### `init`

```elm
init : String -> Mode mode -> State mode id
```

A closed field with nothing chosen. The `String` is the DOM id of the field
and must be unique on the page: the label points to it, and the ids of the popup
are derived from it (`site-search`, `site-tree`, `site-popup`). The second
argument is `single` or `multiple`.

    TreeSelect.init "site" TreeSelect.single

### `update`

```elm
update : Msg id -> State mode id -> ( State mode id, Cmd (Msg id) )
```

Handles a message of the field and returns the new state with a command
(moving focus, scrolling the list). Map the command into your own message type
with `Cmd.map`.

    SiteMsg inner ->
        let
            ( site, cmd ) =
                TreeSelect.update inner model.site
        in
        ( { model | site = site }, Cmd.map SiteMsg cmd )

### `view`

```elm
view : (Msg id -> msg) -> List (Attribute id msg) -> State mode id -> Html msg
```

The field. It takes the constructor that wraps the component's `Msg` in your
own message type, a list of attributes, and the state.

    TreeSelect.view SiteMsg
        [ TreeSelect.label "Warehouse"
        , TreeSelect.nodes sites
        , TreeSelect.required
        ]
        model.site

Always give the field a `label`; `labelHidden` keeps it off the screen but
available to screen readers.

## Single or multiple

### `Mode`

```elm
type Mode mode  -- opaque: no constructors are exposed
```

Whether the field chooses one node or several, given once to `init`. Make it
with `single` or `multiple`. It is a type of its own rather than a flag, so that
the functions that only make sense for one kind do not compile for the other.

### `Single`

```elm
type Single  -- opaque: no constructors are exposed
```

The kind of a field that chooses one node. It only exists as the first
argument of `State`: `TreeSelect.State TreeSelect.Single SiteId`.

### `Multiple`

```elm
type Multiple  -- opaque: no constructors are exposed
```

The kind of a field that chooses any number of nodes with check boxes:
`TreeSelect.State TreeSelect.Multiple SiteId`.

### `single`

```elm
single : Mode Single
```

The field chooses one node, or none. Read it with `value`.

### `multiple`

```elm
multiple : Mode Multiple
```

The field chooses any number of nodes, each with a check box. Read it with
`values`.

## Value

### `value`

```elm
value : State Single id -> Maybe id
```

The chosen node of a single field, or `Nothing` when nothing is chosen. A
value set with `setValue` is returned at once, also while the nodes are still
loading.

### `setValue`

```elm
setValue : Ids.Ids id -> Maybe id -> State Single id -> State Single id
```

Chooses a node of a single field from your code, for example to show a saved
record; `Nothing` empties the field, so `setValue ids (value state)` changes
nothing. The label is looked up in the nodes when they are shown; use `setNode`
when the node may not be among them (it is inside a branch that is not loaded).

    TreeSelect.setValue siteIds (Just hall3) model.site

### `setNode`

```elm
setNode : Picking.Node id -> State Single id -> State Single id
```

Chooses a node of a single field and remembers its label, so the field shows
it even when the nodes you give do not contain it. Only the node itself is used,
not its children.

### `values`

```elm
values : State Multiple id -> List id
```

The chosen nodes of a multiple field, in the order they were chosen. A node
that stands for a branch is one id: see "What a checked box means" above. Ids set
with `setValues` are returned at once, also while the nodes are still loading.

### `setValues`

```elm
setValues : Ids.Ids id -> List id -> State Multiple id -> State Multiple id
```

Replaces the chosen nodes of a multiple field from your code. Duplicates are
dropped. The labels are looked up in the nodes when they are shown; use `setNodes`
when they may not be among them. The value is taken as you give it as long as the
field does not know the nodes (`europe` and `oslo` together are two ids, and the
field draws what that means: Oslo inside a checked Europe is simply checked, and
Norway with Oslo and Bergen checked is checked); once the field has seen the nodes
(its popup has been open) it puts what you set in its shortest form, like what the
user checks.

    TreeSelect.setValues siteIds [ europe, asia ] model.sites

### `setNodes`

```elm
setNodes : List (Picking.Node id) -> State Multiple id -> State Multiple id
```

Replaces the chosen nodes of a multiple field with these nodes and remembers
their labels. Only the nodes themselves are used, not their children.

### `leaves`

```elm
leaves : List (Picking.Node id) -> State Multiple id -> List id
```

The chosen nodes of a multiple field written out as the nodes that have no
children: every node below a chosen branch, in the order of the tree, without the
ones that are `disabled`. A node whose children are not loaded stays as it is, and
so does a chosen id that is not in the nodes. Give it the same nodes that you give
to `view`.

    TreeSelect.leaves nodes model.sites --> the halls, not the regions

### `clear`

```elm
clear : State mode id -> State mode id
```

Removes the chosen node or nodes, so that `value` is `Nothing` and `values`
is empty again.

## Popup and lazy nodes

### `query`

```elm
query : State mode id -> String
```

The text in the search box while the popup is open, and `""` when it is
closed.

### `isOpen`

```elm
isOpen : State mode id -> Bool
```

Whether the popup is open.

### `open`

```elm
open : State mode id -> ( State mode id, Cmd (Msg id) )
```

Opens the popup with an empty search and moves focus into its search box, for
example from a button of your own. Map the command like the one from `update`.

### `close`

```elm
close : State mode id -> ( State mode id, Cmd (Msg id) )
```

Closes the popup, forgets the search text, and gives focus back to the field
if the popup was open. Map the command like the one from `update`.

### `loadRequests`

```elm
loadRequests : State mode id -> List id
```

The lazy nodes that the last `update` opened while their children are
`NotAsked`: the user opened them, `*` opened several, or the popup opened on a
value inside them. Usually zero or one. Call it after every `update` of the field,
set the children of the nodes it names to `Loading` in your data and fetch them;
the next time you build the nodes they hold the answer. Each node is named once
(scrolling, hovering or another message does not name it again), so the wiring
below never fetches twice and needs no guard of its own.

    SiteMsg inner ->
        let
            ( site, cmd ) =
                TreeSelect.update inner model.site

            requested =
                TreeSelect.loadRequests site
        in
        ( { model | site = site, zones = markLoading requested model.zones }
        , Cmd.batch (Cmd.map SiteMsg cmd :: List.map fetchZones requested)
        )

A node that you leave `NotAsked` is named again the next time the popup opens. If
you set an open node back to `NotAsked` yourself (to load it again), fetch it
yourself too. After a failure the user retries with the button that
`onRetryChildren` adds.

## Attributes

Pass attributes to `view` in a list; later ones win over earlier ones.

### `Attribute`

```elm
type Attribute id msg  -- opaque: no constructors are exposed
```

A setting of a field. Make them with the functions below and pass a list to
`view`; later attributes win over earlier ones.

### `nodes`

```elm
nodes : List (Picking.Node id) -> Attribute id msg
```

The top level of the tree, built with `Picking.leaf`, `Picking.branch` and
`Picking.lazy`. The default is no nodes. Use `nodes` or `remote`, not both: the
later one wins.

    TreeSelect.nodes [ Picking.branch siteIds oslo "Oslo" [ Picking.leaf siteIds hall3 "Hall 3" ] ]

### `remote`

```elm
remote : Remote.Remote (List (Picking.Node id)) -> Attribute id msg
```

The top level of the tree from the backend, as a `Remote` (see
[Klar.Remote](Klar.Remote.md)). The popup shows loading rows while the data is
`Loading` or `NotAsked`, a compact error with a retry button on `Failed` (see
`onRetry`), the empty state on `Loaded []`, and the tree on `Loaded`. A tree that is
`Kept` stays on screen and can be used: dimmed and busy while it is refreshed, and
with "Old data from 14:05" and a retry (`onRetry`) above it when the last refresh
failed (the time is written in the zone of `settings`).

    TreeSelect.remote model.sites

### `onRetry`

```elm
onRetry : msg -> Attribute id msg
```

The message to send when the user presses the "Try again" button of the error
shown when the top level (`remote`) failed to load. The button appears only for
problems that are worth retrying (network trouble, timeouts, server errors); while
it is shown, Enter in the search box sends the message as well.

    TreeSelect.onRetry ReloadSites

### `onRetryChildren`

```elm
onRetryChildren : (id -> msg) -> Attribute id msg
```

The message to send, given the node id, when the user presses "Try again" on
a lazy node whose children failed to load (Enter does the same while that row is
highlighted). The button is only shown for problems that are worth retrying. Set
the children of that node to `Loading` again and fetch them; the rest of the tree
keeps working meanwhile.

    TreeSelect.onRetryChildren ReloadZones

## Field

The label, hint and error around the field work the same in every Klar form
control.

### `label`

```elm
label : String -> Attribute id msg
```

The label above the field. It names the field for screen readers.

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

Shows a small x in the field that removes the chosen node or nodes. In a
single field Backspace and Delete do the same on the focused field. Nothing is
shown while nothing is chosen.

### `valueText`

```elm
valueText : (id -> String) -> Attribute id msg
```

How to write an id that is in none of the nodes you give, for example a saved
value inside a branch that is not loaded. Without it the field says "Unknown
value". The label of a node the field knows about is always its own.

    TreeSelect.valueText SiteId.toString

### `disabled`

```elm
disabled : Bool -> Attribute id msg
```

While `True` the field is dimmed, cannot be focused or opened, and has no
clear button. The value is kept. Pass a field of your model, for example while a
form is saving. The default is `False`.

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

How many rows the open popup shows before it scrolls. The default is 8;
numbers below 3 or above 20 are brought into that range.

### `maxVisibleChips`

```elm
maxVisibleChips : Int -> Attribute id msg
```

How many chosen nodes a multiple field writes out as chips. The default is 3.
When more nodes are chosen, the field shows one chip "40 selected" instead, which
has the remove button of the whole choice, so that the field does not grow with the
choice. The most is 20.

### `locale`

```elm
locale : Locale.Locale -> Attribute id msg
```

The language of the built-in text: the placeholders, the search box, the
counts, the loading and error states and the labels for screen readers. The
default is `Locale.default`, which is English. See [Klar.Locale](Klar.Locale.md).

    TreeSelect.locale Locale.nb

### `settings`

```elm
settings : Settings.Settings -> Attribute id msg
```

The settings of the application (`Klar.Settings`): the time zone of the time in
"Old data from 14:05", for the top level (`remote`) and for lazy nodes. Without
it the time is written in UTC and ends in "UTC".

    TreeSelect.settings model.settings
