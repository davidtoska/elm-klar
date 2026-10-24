# Klar.Sortable

A list the user can put in a new order: by dragging an item by its handle, or with the keyboard.

Import: `import Klar.Sortable as Sortable` | Group: Arranging

Types: `Msg`, `Item`, `State`, `Attribute`

## Signatures

```elm
-- View
type Item id msg  -- opaque: no constructors are exposed
view : Ids.Ids id -> (Msg -> msg) -> List Attribute -> State id -> List (Item id msg) -> Html msg
item : id -> String -> Html msg -> Item id msg
fixed : Item id msg -> Item id msg

-- State and messages
type State id  -- opaque: no constructors are exposed
type Msg  -- opaque: no constructors are exposed
init : String -> State id
update : Msg -> State id -> ( State id, Cmd Msg )
lifted : Ids.Ids id -> State id -> Maybe id

-- Putting the list in the new order
reorder : Ids.Ids id -> (a -> id) -> State id -> State id -> List a -> List a
move : { from : Int, to : Int } -> List a -> List a

-- Attributes
type Attribute  -- opaque: no constructors are exposed
ariaLabel : String -> Attribute
horizontal : Attribute
wholeItem : Attribute
disabled : Bool -> Attribute
emptyText : String -> Attribute
locale : Locale.Locale -> Attribute
```

## Documentation

A list the user can put in a new order: by dragging an item by its handle, or
with the keyboard.

Use when: a short list has an order that matters, such as the steps of a pick sequence or the filters of a saved view.
Do not use when: the user only chooses which columns of a table to show (use `Table.columnChooser`); a table has no way to reorder its columns.
Quick path: `init`, `update`, `view`, `reorder`

    import Klar.Ids as Ids exposing (Ids)
    import Klar.Sortable as Sortable

    -- model: steps : List Step, sortable : Sortable.State StepId
    -- init:  Sortable.init "pick-steps"
    stepIds : Ids StepId
    stepIds =
        Ids.make { toKey = StepId.toString, fromKey = StepId.fromString }

    -- update
    SortableMsg m ->
        let
            ( sortable, cmd ) =
                Sortable.update m model.sortable
        in
        ( { model
            | sortable = sortable
            , steps = Sortable.reorder stepIds .id model.sortable sortable model.steps
          }
        , Cmd.map SortableMsg cmd
        )

    -- view
    Sortable.view stepIds
        SortableMsg
        [ Sortable.ariaLabel "Pick sequence" ]
        model.sortable
        (List.map (\step -> Sortable.item step.id step.title (viewStep step)) model.steps)

Your list stays yours. You draw it in your own order, and the component only
remembers what the user is doing right now (which item is held and where it would
land). When the user lets go, `reorder` puts the item in its new place in your list,
in the same `update` that handled the message; if you do not call it, nothing has
moved, and the list springs back to what you draw. Items carry the id type of your
own (`StepId`), written as text once as a [Klar.Ids](Klar.Ids.md), so no `String` ids leak into
your code. Draw the items with whatever `Html` you like: the component wraps each in
a list item with a handle.

Dragging is not for everybody, and the guidelines for accessibility ask for another way
than a movement with the pointer (WCAG 2.5.7). The keyboard is one. For a person who
uses a pointer and cannot drag, give each item "Move up" and "Move down" buttons that
use `move`, which moves an item the same way and keeps it inside the list:

    MoveUp index ->
        ( { model | steps = Sortable.move { from = index, to = index - 1 } model.steps }
        , Cmd.none
        )

Use it for a short list whose order matters: the steps of a pick sequence, the
filters of a saved view, a chip list. For a table whose columns can be moved, use
[Klar.Table](Klar.Table.md); for a tree, [Klar.Tree](Klar.Tree.md). An item that is
[fixed](#fixed) stays where it is and cannot be passed, so a "Scan the tote" step can
stay first. A list with `disabled True` cannot be changed.

Keyboard: every item has a handle, which is a button and a tab stop of its own.
`Space` or `Enter` picks the item up. Then the `Up` and `Down` arrow keys move it one
place (`Left` and `Right` in a `horizontal` list), `Home` and `End` jump to the ends,
`Space` or `Enter` drops it and `Escape` cancels. Leaving the handle with `Tab`
cancels too. While the item is held the list does not change: a line shows where the
item would land, and the page scrolls to it. Only when it is dropped does the list
move, and the handle keeps focus.

Pointer: press the handle and drag. A press that does not move 4 pixels is a plain
click and does nothing. The item stays where it is and is drawn as lifted, a line
shows where it would land, and its label follows the pointer. Let go to drop;
`Escape` cancels. The component uses pointer events, not the HTML5 drag and drop of
the browser, so it works in Firefox and with a finger or a pen. It needs no
subscription: while the mouse drags, a transparent layer over the window receives
the events (and gives the window one cursor and no text selection), and a mouse that
is let go outside the window cancels the drag when it comes back. With `wholeItem` the
mouse can also take hold of the item anywhere except on buttons, links and fields; a
finger or a pen always uses the handle, so the rest of the item still scrolls the page.

Screen readers: the handle is named after the item (the label you give to `item`),
described as "sortable item" and told how to use it. A live region owned by the
component says what happens: "Scan the tote picked up, position 2 of 5", "Moved to
position 3 of 5", "Scan the tote dropped at position 3 of 5", "Cancelled". The text is
English or Norwegian Bokmål (see `locale`).

What the state remembers: the item that is held, the list as it was when the user
picked it up, where it would land, and, until the next drop, where the last drop put
its item (the keys of its neighbours, which `reorder` reads). Nothing else; the order
is yours, and `reorder` also works on a list that is not the one that was drawn.

Limits: lists are drawn in full (there is no windowing), so keep them to a few
hundred items. A drag with the pointer does not scroll the page or a box around the
list; the keyboard path scrolls the window, not a scrolling box. Right-to-left
languages are not mirrored yet. If the list that is drawn changes while an item is
held, the drop is cancelled instead of moving the item to a place that no longer
means the same; an item that is taken out of the list while it is held is let go
(the next time a handle gets the focus or is pressed, the state forgets it).

## View

### `Item`

```elm
type Item id msg  -- opaque: no constructors are exposed
```

One item of the list. Make it with `item` and, if it must stay in its place,
`fixed`.

### `view`

```elm
view : Ids.Ids id -> (Msg -> msg) -> List Attribute -> State id -> List (Item id msg) -> Html msg
```

The list. It takes the `Ids` of your item type, the constructor that wraps the
messages, the attributes, the state and the items in the order you want them
drawn.

    Sortable.view steps
        SortableMsg
        [ Sortable.ariaLabel "Pick sequence" ]
        model.sortable
        (List.map viewStep model.steps)

An empty list draws the `emptyText`. Reordering needs the same `Ids` in `reorder`.

### `item`

```elm
item : id -> String -> Html msg -> Item id msg
```

An item: its id, its label and what to draw.

    Sortable.item step.id step.title (Html.text step.title)

The label names the item for screen readers (the handle is called after it, and the
announcements use it: "Scan the tote picked up"), so it is required and should be
plain text that tells the items apart. The `Html` is drawn as it is next to the
handle.

### `fixed`

```elm
fixed : Item id msg -> Item id msg
```

An item that stays where it is. It has no handle (a small lock takes its
place), the user cannot move it and no other item can be moved past it: it splits
the list in two parts that are arranged on their own. Put it first or last to keep
a step at the start or the end.

## State and messages

### `State`

```elm
type State id  -- opaque: no constructors are exposed
```

What the user is doing with a list right now: which item is held and where it
would land. Make one with `init`, keep it in your model, pass every `Msg` through
`update`, and read the result with `reorder`. The items and their order are not part
of it.

### `Msg`

```elm
type Msg  -- opaque: no constructors are exposed
```

A message of the list. Wrap it in a constructor of your own message type
(`SortableMsg`), pass that to `view`, and hand the messages you get back to
`update`.

### `init`

```elm
init : String -> State id
```

A list in which nothing is held. The `String` is a DOM id prefix and must be
unique on the page: the items, the handles and the instructions get ids that start
with it.

    Sortable.init "pick-steps"

### `update`

```elm
update : Msg -> State id -> ( State id, Cmd Msg )
```

Follows the user: picking an item up, moving it, dropping it or cancelling.
The command measures the items when a press begins, brings the target into view
while the keyboard moves it and puts the focus back on the handle after a drop, so
map it with `Cmd.map` like any other child. To react to a drop, call `reorder`.

### `lifted`

```elm
lifted : Ids.Ids id -> State id -> Maybe id
```

The id of the item that is held (picked up with the keyboard, or dragged past
the first few pixels), or `Nothing`. Use it to show that something is going on, or
to hold back a refresh of the list. When the item has been taken out of your list
meanwhile it is still named here until the state forgets it (see the limits above),
though the page no longer shows it as held.

## Ids

The id type of your items (a `StepId`, plain text ...) is written as a key once, as a
[Klar.Ids](Klar.Ids.md), and given to `view`, `reorder` and `lifted`. The state is typed by
the id (`Sortable.State StepId`). The key becomes part of the DOM ids, so `toKey` must give
every id its own key; a list that holds the same key twice shows the first item only.

## Putting the list in the new order

### `reorder`

```elm
reorder : Ids.Ids id -> (a -> id) -> State id -> State id -> List a -> List a
```

Puts your list in the order the user just chose. Give it the state before and
the state after the same `update` call, and your list.

    Sortable.reorder steps .id model.sortable sortable model.steps

When the user dropped an item in that `update`, the item moves to its new place and
the rest of the list stays as it is; otherwise the list is returned unchanged. The
two states must be those of one call: a drop is only applied when exactly one drop
happened between them, so a state that you kept from an earlier `update`, or the
same state twice, changes nothing and cannot move an item twice.

The list does not have to be the list that was drawn. The item is found by the id
function you give (`.id`; the first one when a list holds the same id twice). It is
put right behind the item that is above its new place among the items that were
drawn, or, at the top, right in front of the one below it. Items that were not
drawn (a filter hides them) keep their places in relation to each other, and an
item that has gone from your list in the meantime is skipped for the nearest one
that is still there. So hiding some items with a filter, or adding and removing
items while the user holds one, never puts the dropped item somewhere else than
among its new neighbours.

### `move`

```elm
move : { from : Int, to : Int } -> List a -> List a
```

Moves one element of a list from one place to another, counting from 0. The
place `to` is where the element ends up. A `to` beyond the ends counts as the
nearest end, and a `from` that is not in the list changes nothing. Use it for the
same move without dragging, for example for "Move up" and "Move down" buttons in a
menu, so that people who cannot drag have another way. A button inside the item goes
with the item to its new place, and the browser takes the focus from an element that is
moved in the page: give the button an `id` and send the focus back to it in the same
`update`, with `Klar.focus`, or a keyboard user starts again from the top of the
page after every press.

    Sortable.move { from = 0, to = 2 } [ "a", "b", "c", "d" ] --> [ "b", "c", "a", "d" ]

## Attributes

### `Attribute`

```elm
type Attribute  -- opaque: no constructors are exposed
```

A setting of the list. Make them with the functions below and pass a list to
`view`; later attributes win over earlier ones.

### `ariaLabel`

```elm
ariaLabel : String -> Attribute
```

The accessible name of the list, for example "Pick sequence". Give every list
on a page its own name; without it the list has none.

### `horizontal`

```elm
horizontal : Attribute
```

The items run side by side (a chip list) instead of one below the other, and
wrap onto more lines when they do not fit. The keyboard moves an item with the
`Left` and `Right` arrow keys instead of `Up` and `Down`. The default is a
vertical list.

### `wholeItem`

```elm
wholeItem : Attribute
```

Lets the mouse take hold of an item anywhere, not only by its handle, except
on buttons, links, fields and other things that react to a press themselves. A
finger or pen still uses the handle only, so that the rest of the item scrolls the
page. The handle stays: it is how the keyboard and screen readers reach the item.
The default is the handle only.

### `disabled`

```elm
disabled : Bool -> Attribute
```

Makes the whole list unchangeable: the handles are dimmed and cannot be used.
The default is `False`.

### `emptyText`

```elm
emptyText : String -> Attribute
```

The text drawn when there are no items. The default is "No items".

### `locale`

```elm
locale : Locale.Locale -> Attribute
```

The language of the built-in text: the description of the handle, the
announcements, "Fixed position" and the empty text. The default is
`Locale.default`, which is English. See [Klar.Locale](Klar.Locale.md).
