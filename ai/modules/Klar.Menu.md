# Klar.Menu

A dropdown menu opened from a button.

Import: `import Klar.Menu as Menu` | Group: Actions

Types: `Item`, `Attribute`, `Msg`, `State`

## Signatures

```elm
-- View
view : (Msg -> msg) -> List (Attribute msg) -> State -> Html msg

-- State
type alias State = Menu.Core.MenuState
type alias Msg = Menu.Core.MenuMsg
init : String -> State
update : Msg -> State -> ( State, Cmd Msg )
isOpen : State -> Bool
open : State -> ( State, Cmd Msg )
close : State -> ( State, Cmd Msg )
triggerId : State -> String

-- Items
type Item msg  -- opaque: no constructors are exposed
item : String -> msg -> Item msg
separator : Item msg
heading : String -> Item msg
withIcon : Icon.Icon -> Item msg -> Item msg
withShortcut : Shortcut.Keys -> Item msg -> Item msg
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
platform : Kbd.Platform -> Attribute msg
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
    import Klar.Shortcut as Shortcut

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
            , Menu.item "Duplicate" DuplicateOrder |> Menu.withShortcut (Shortcut.mod (Shortcut.char 'd'))
            , Menu.separator
            , Menu.item "Delete" DeleteOrder |> Menu.danger |> Menu.withIcon Icon.trash
            ]
        ]
        model.rowMenu

Clicking an item sends the item's own message and closes the menu.

**Keyboard.** The button opens the menu with `Enter`, `Space` or `ArrowDown` with
the first item highlighted, and with `ArrowUp` with the last one; a click with
the pointer opens it with nothing highlighted. Focus moves into the menu: the
arrow keys move the highlight (and wrap around), `Home` and `End` jump to the
first and last item, typing a letter jumps to the next item whose label starts
with the letters typed (a space typed right after letters is part of the text),
`Enter` or `Space` pick the highlighted item, and `Escape` or `Tab` close the
menu. The menu prevents the default of the `Escape` it handles, so a drawer
around it or an `Escape` shortcut can ignore that key. A click anywhere outside the menu closes it
too. When the menu closes, it gives focus back to its button, except after `Tab`
and `Shift+Tab`: they leave the menu like any other element, `Tab` for the next
element on the page and `Shift+Tab` for the button. Disabled items are skipped. A
long menu scrolls, and the keys scroll the highlighted item into view (the
pointer does not: an item under it can be seen).

**Screen readers** get a `menu` named after its button, with `menuitem` entries;
the items under a `heading` are a `group` named after the heading, and a
shortcut (`withShortcut`) is announced as `aria-keyshortcuts`.

Every menu needs a `State` and an id of its own. The menu has no built-in text,
so there is no `locale`: the labels come from your application.
[Klar.Modal](Klar.Modal.md) describes the rules that all popups share.

If an item opens a dialog, give the dialog to
[`Overlay.host`](Klar.Overlay.md#host) and name the menu's button as the opener
(`Modal.open (Menu.triggerId model.rowMenu)`): the page behind the dialog is then
`inert`, so closing the menu, which gives focus back to its button, cannot take
focus away from the dialog, and focus goes back to the button when the dialog
closes.

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
type alias State = Menu.Core.MenuState
```

The state of one menu: whether it is open and which item is highlighted.
Create it with `init`, keep it in your model (one per menu), and change it with
`open`, `close` and `update`. It is opaque; a compiler message may call it
`Klar.Menu.Core.MenuState`, which is this same type.

### `Msg`

```elm
type alias Msg = Menu.Core.MenuMsg
```

The messages of the menu (opening, closing, moving the highlight). Wrap it in
a constructor of your own message type, such as `MenuMsg Menu.Msg`, and hand it
to `update`. A compiler message may call it `Klar.Menu.Core.MenuMsg`, which is
this same type.

### `init`

```elm
init : String -> State
```

A closed menu. The id must be unique on the page; the ids of the button, the
popup and the items start with it (the button's is `triggerId`).

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

Opens the menu with the first item that can be picked highlighted, as the
keyboard opens it, and moves keyboard focus into it. Use it to open the menu from
your own code, from a keyboard shortcut for example.

### `close`

```elm
close : State -> ( State, Cmd Msg )
```

Closes the menu and gives focus back to its button. The menu closes by itself
when the user picks an item, clicks outside it or presses `Escape`; `Tab` closes
it too, but lets focus move on to the next element instead.

### `triggerId`

```elm
triggerId : State -> String
```

The DOM id of the button that opens the menu. Give it to `Modal.open` (or
`Drawer.open`, `ConfirmDialog.open`) when an item opens a dialog, so that focus
goes back to the button when the dialog closes.

    OpenDeleteDialog ->
        ( { model | confirm = ConfirmDialog.open (Menu.triggerId model.rowMenu) model.confirm }, Cmd.none )

## Items

### `Item`

```elm
type Item msg  -- opaque: no constructors are exposed
```

One entry of the menu: an action, a separator or a heading. Make them with
`item`, `separator` and `heading`, and refine an action with `withIcon`,
`withShortcut`, `withHint`, `danger` and `disabledItem`.

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
The items after it, up to the next heading or separator, are a `group` that
screen readers name after it ("Danger zone").

### `withIcon`

```elm
withIcon : Icon.Icon -> Item msg -> Item msg
```

An icon before the label of an action. This function and `withShortcut`,
`withHint`, `danger` and `disabledItem` change an action and leave a separator
or a heading as it is.

    Menu.item "Edit" EditOrder |> Menu.withIcon Icon.edit

### `withShortcut`

```elm
withShortcut : Shortcut.Keys -> Item msg -> Item msg
```

The keyboard shortcut of the action, drawn as small key caps at the right of
the item, for the keyboard of `platform`, and announced to screen readers as
`aria-keyshortcuts`. It is the same typed value that
[Klar.Shortcut](Klar.Shortcut.md) listens to, so the hint cannot disagree with the
shortcut; the menu only shows it, the application installs the shortcut.

    Menu.item "Duplicate" DuplicateOrder
        |> Menu.withShortcut (Shortcut.mod (Shortcut.char 'd'))

### `withHint`

```elm
withHint : String -> Item msg -> Item msg
```

Right-aligned gray text after the label, for a short note that is not a
shortcut ("3 left", "Beta"). It is part of the item's name for screen readers.
Use `withShortcut` for a keyboard shortcut.

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
name. The menu is named after its button for screen readers.

### `kebab`

```elm
kebab : String -> Attribute msg
```

An icon-only "more" button with three vertical dots instead of the text
button. The `String` is its accessible name and its tooltip, so it must say what
the menu is for, such as "Order actions". The button looks like a `ghost` button
unless you style it with `trigger`.

### `trigger`

```elm
trigger : List (Button.Attribute msg) -> Attribute msg
```

Style the button: `Menu.trigger [ Button.ghost, Button.small ]`. The
attributes add up when you use it more than once. The id, the expanded state and
the click and key handlers of the button belong to the menu; do not give it a
`Button.onClick`, which would take the click from the menu. A button made
`Button.ariaDisabled`, `Button.loading` or `Button.disabled` does not open the
menu, with the pointer or the keyboard.

### `alignEnd`

```elm
alignEnd : Attribute msg
```

Align the menu's right edge with the button's right edge, so that the menu
extends to the left. Use it for a button near the right edge of the window or of
a table.

### `platform`

```elm
platform : Kbd.Platform -> Attribute msg
```

The keyboard that the shortcuts of `withShortcut` are drawn for: `Kbd.pc` (the
default: Ctrl, Alt, Shift) or `Kbd.mac` (⌘ ⌥ ⇧). See
[`Kbd.platformFromUserAgent`](Klar.Kbd.md#platformfromuseragent).
