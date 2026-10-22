# Klar.Menu

A dropdown menu opened from a button.

Import: `import Klar.Menu as Menu` | Group: Actions

Types: `Msg`, `Item`, `State`, `Attribute`

## Signatures

```elm
-- View
view : (Msg -> msg) -> List (Attribute msg) -> State -> Html msg

-- State
type State  -- opaque: no constructors are exposed
type Msg  -- opaque: no constructors are exposed
init : String -> State
update : Msg -> State -> ( State, Cmd Msg )
isOpen : State -> Bool
open : State -> ( State, Cmd Msg )
close : State -> ( State, Cmd Msg )

-- Items
type Item msg  -- opaque: no constructors are exposed
item : String -> msg -> Item msg
separator : Item msg
heading : String -> Item msg
withIcon : Icon.Icon -> Item msg -> Item msg
withHint : String -> Item msg -> Item msg
danger : Item msg -> Item msg
disabledItem : Item msg -> Item msg

-- Attributes
type Attribute msg  -- opaque: no constructors are exposed
items : List (Item msg) -> Attribute msg
label : String -> Attribute msg
kebab : String -> Attribute msg
trigger : List (Button.Attribute msg) -> Attribute msg
alignEnd : Attribute msg
```

## Documentation

A dropdown menu opened from a button. Used for actions that do not deserve
their own button: row actions, "more", user menus.

Use when: a few actions do not deserve their own buttons: row actions, "more", user menus.
Do not use when: the popup holds any content (as `Klar.Popover`), opens on right-click (as `Klar.ContextMenu`) or has a main action (as `Klar.SplitButton`).
Quick path: `init`, `update`, `view`, `isOpen`

Where a [Klar.Popover](Klar.Popover.md) holds any content, a menu is a list of
actions that closes as soon as one is picked. For a menu that opens where the
user right-clicks, use a [Klar.ContextMenu](Klar.ContextMenu.md).

    import Klar.Icon as Icon
    import Klar.Menu as Menu

    -- model:   rowMenu : Menu.State        (Menu.init "order-actions")

    -- update
    MenuMsg m ->
        let
            ( menu, cmd ) =
                Menu.update m model.rowMenu
        in
        ( { model | rowMenu = menu }, Cmd.map MenuMsg cmd )

    -- view
    Menu.view MenuMsg
        [ Menu.label "Actions"
        , Menu.items
            [ Menu.item "Edit" EditOrder |> Menu.withIcon Icon.edit
            , Menu.separator
            , Menu.item "Delete" DeleteOrder |> Menu.danger |> Menu.withIcon Icon.trash
            ]
        ]
        model.rowMenu

Clicking an item sends the item's own message and closes the menu. The button
opens the menu with a click, `Enter`, `Space` or `ArrowDown`, and focus moves
into the menu. Keyboard: the arrow keys move the highlight (and wrap around),
`Home` and `End` jump to the first and last item, `Enter` or `Space` pick the
highlighted item, and `Escape` or `Tab` close the menu. A click anywhere outside
the menu closes it too. When the menu closes, it gives focus back to its button,
except after `Tab` and `Shift+Tab`: they leave the menu like any other element,
`Tab` for the next element on the page and `Shift+Tab` for the button. Disabled
items are skipped. A long menu scrolls, and the keys scroll the highlighted item
into view (the pointer does not: an item under it can be seen). Screen readers
get a `menu` with `menuitem` entries.

Every menu needs a `State` and an id of its own. The menu has no built-in text,
so there is no `locale`: the labels come from your application.
[Klar.Modal](Klar.Modal.md) describes the rules that all popups share.

If an item opens a dialog, give the dialog to
[`Overlay.host`](Klar.Overlay.md#host): the page behind it is then `inert`, so closing
the menu, which gives focus back to its button, cannot take focus away from the
dialog.

## View

### `view`

```elm
view : (Msg -> msg) -> List (Attribute msg) -> State -> Html msg
```

The button and, while open, the menu; `toMsg` wraps the messages of the menu.
Where the browser supports CSS anchor positioning, the menu is never clipped by a
table or a dialog and flips above the button when there is no room below; other
browsers get plain positioning. Picking an item sends its own message and closes
the menu.

## State

### `State`

```elm
type State  -- opaque: no constructors are exposed
```

The state of one menu: whether it is open and which item is highlighted.
Create it with `init`, keep it in your model (one per menu), and change it with
`open`, `close` and `update`.

### `Msg`

```elm
type Msg  -- opaque: no constructors are exposed
```

The messages of the menu (opening, closing, moving the highlight). Wrap it in
a constructor of your own message type, such as `MenuMsg Menu.Msg`, and hand it
to `update`.

### `init`

```elm
init : String -> State
```

A closed menu. The id must be unique on the page; the ids of the button, the
popup and the items start with it.

### `update`

```elm
update : Msg -> State -> ( State, Cmd Msg )
```

Handles opening and closing the menu and moving the highlight, and scrolls a
long menu to the highlighted item. Map its command into your own message with
`Cmd.map`. Picking an item does not go through here: it sends the message of the
item.

### `isOpen`

```elm
isOpen : State -> Bool
```

Is the menu open?

### `open`

```elm
open : State -> ( State, Cmd Msg )
```

Opens the menu and moves keyboard focus into it, with no item highlighted
yet. Use it to open the menu from your own code, from a keyboard shortcut for
example.

### `close`

```elm
close : State -> ( State, Cmd Msg )
```

Closes the menu and gives focus back to its button. The menu closes by itself
when the user picks an item, clicks outside it or presses `Escape`; `Tab` closes
it too, but lets focus move on to the next element instead.

## Items

### `Item`

```elm
type Item msg  -- opaque: no constructors are exposed
```

One entry of the menu: an action, a separator or a heading. Make them with
`item`, `separator` and `heading`, and refine an action with `withIcon`,
`withHint`, `danger` and `disabledItem`.

### `item`

```elm
item : String -> msg -> Item msg
```

A menu entry that sends `msg` when picked: `Menu.item "Edit" EditOrder`. Keep
labels short; a long one is cut off with an ellipsis.

### `separator`

```elm
separator : Item msg
```

A thin line between two groups of items.

### `heading`

```elm
heading : String -> Item msg
```

A small caption above a group of items. It cannot be picked or highlighted.

### `withIcon`

```elm
withIcon : Icon.Icon -> Item msg -> Item msg
```

An icon before the label of an action. This function and `withHint`,
`danger` and `disabledItem` change an action and leave a separator or a heading
as it is.

    Menu.item "Edit" EditOrder |> Menu.withIcon Icon.edit

### `withHint`

```elm
withHint : String -> Item msg -> Item msg
```

Right-aligned gray text, typically a keyboard shortcut:
`Menu.withHint "Ctrl D"`. It is only shown; it does not install the shortcut
(see [Klar.Shortcut](Klar.Shortcut.md) for that).

### `danger`

```elm
danger : Item msg -> Item msg
```

Red text, for destructive actions.

### `disabledItem`

```elm
disabledItem : Item msg -> Item msg
```

Visible but not pickable: the arrow keys skip it, it is never highlighted,
and a click on it does nothing (the menu stays open).

## Attributes

### `Attribute`

```elm
type Attribute msg  -- opaque: no constructors are exposed
```

A setting of a menu. Make them with the functions below and pass a list to
`view`; later attributes win over earlier ones.

### `items`

```elm
items : List (Item msg) -> Attribute msg
```

The entries of the menu, from top to bottom. The default is an empty menu. A
menu taller than 26rem (or than the window) scrolls.

### `label`

```elm
label : String -> Attribute msg
```

Text on the button that opens the menu, followed by a small down arrow. It is
not used with `kebab`; without a label or `kebab` the button has no accessible
name.

### `kebab`

```elm
kebab : String -> Attribute msg
```

An icon-only "more" button with three vertical dots instead of the text
button. The `String` is its accessible name and its native tooltip, so it must
say what the menu is for, such as "Order actions". The button looks like a
`ghost` button unless you style it with `trigger`.

### `trigger`

```elm
trigger : List (Button.Attribute msg) -> Attribute msg
```

Style the button: `Menu.trigger [ Button.ghost, Button.small ]`. The
attributes add up when you use it more than once. The id, the expanded state and
the click handler of the button belong to the menu and cannot be overridden.

### `alignEnd`

```elm
alignEnd : Attribute msg
```

Align the menu's right edge with the button's right edge, so that the menu
extends to the left. Use it for a button near the right edge of the window or of
a table.
