# Klar.ContextMenu

The menu that opens where the user right-clicks.

Import: `import Klar.ContextMenu as ContextMenu` | Group: Overlays

Types: `Msg`, `State`

## Signatures

```elm
-- View
view : (Msg a -> msg) -> (a -> List (Menu.Item msg)) -> State a -> Html msg

-- Elements that open the menu
area : (Msg a -> msg) -> State a -> { id : String, target : a } -> List (Html msg) -> Html msg
attrs : (Msg a -> msg) -> a -> List (Html.Attribute msg)

-- State
type State a  -- opaque: no constructors are exposed
type Msg a  -- opaque: no constructors are exposed
init : String -> State a
update : Msg a -> State a -> ( State a, Cmd (Msg a) )
isOpen : State a -> Bool
target : State a -> Maybe a
close : State a -> ( State a, Cmd (Msg a) )
```

## Documentation

The menu that opens where the user right-clicks. One menu serves many
elements (the rows of a table): each element says what it stands for, and the
menu is built from that.

Use a [Klar.Menu](Klar.Menu.md) when the menu opens from a button instead.

    import Klar.ContextMenu as ContextMenu
    import Klar.Menu as Menu

    -- model:   context : ContextMenu.State Order      (ContextMenu.init "order-context")

    -- every row (right click, or the context menu key, opens the menu)
    ContextMenu.area ContextMsg model.context { id = "order-" ++ order.id, target = order } [ rowContent ]

    -- or, on an element you build yourself
    Html.tr (ContextMenu.attrs ContextMsg order) (orderCells order)

    -- once, anywhere: the menu. The items come from the order that was clicked.
    ContextMenu.view ContextMsg
        (\order ->
            [ Menu.item "Open" (OpenOrder order) |> Menu.withIcon Icon.externalLink
            , Menu.item "Edit" (EditOrder order) |> Menu.withIcon Icon.edit
            , Menu.separator
            , Menu.item "Delete" (AskDelete order) |> Menu.withIcon Icon.trash |> Menu.danger
            ]
        )
        model.context

    -- update
    ContextMsg m ->
        let
            ( context, cmd ) =
                ContextMenu.update m model.context
        in
        ( { model | context = context }, Cmd.map ContextMsg cmd )

The items are the ones of [Klar.Menu](Klar.Menu.md) (`Menu.item`, `Menu.separator`,
`Menu.heading`, `Menu.danger`, `Menu.withIcon`, `Menu.withHint` ...), and the
keyboard works as in a menu: arrows, `Home`, `End`, `Enter` or `Space` to pick,
`Escape` to close. A long menu scrolls, and the keys keep the highlighted item in
view. A click outside closes it (a right-click too, without opening another
menu), and so does the mouse wheel, except over a menu that scrolls. Where the browser supports CSS anchor
positioning, the menu opens towards the free side near the edges of the window.
The menu has no built-in text, so there is no `locale`.
[Klar.Modal](Klar.Modal.md) describes the rules that all popups share.

The value `a` identifies the element (a record, an id). It is compared with
`==` to mark the right-clicked element as active, so it must not contain
functions.

For the keyboard, an `area` can take focus (`Tab`, so each one is one more tab
stop); the context menu key or `Shift+F10` opens the menu for it and focus
returns to it when the menu closes.

When a menu item opens a dialog, give the dialog to
[`Overlay.host`](Klar.Overlay.md#host): the page behind it is then `inert`, so closing
the menu cannot take focus back from the dialog (the same holds for
[Klar.Menu](Klar.Menu.md)).

## View

### `view`

```elm
view : (Msg a -> msg) -> (a -> List (Menu.Item msg)) -> State a -> Html msg
```

The menu: render it once, anywhere (it shows nothing while closed). The
function turns what was right-clicked into the menu items. The menu opens at the
pointer; where the browser supports CSS anchor positioning it flips towards the
free side near the edges of the window.

## Elements that open the menu

### `area`

```elm
area : (Msg a -> msg) -> State a -> { id : String, target : a } -> List (Html msg) -> Html msg
```

A box that opens the menu for `target` when it, or anything inside it, is
right-clicked. It can take focus with `Tab` (the context menu key or `Shift+F10`
then opens the menu), and it is highlighted while the menu is open for it. The
`id` must be unique on the page: it lets the box take focus back when the menu
closes.

### `attrs`

```elm
attrs : (Msg a -> msg) -> a -> List (Html.Attribute msg)
```

Attributes that make an element open the menu for `what` when it is
right-clicked, or when the context menu key (or `Shift+F10`) is pressed on it;
the browser's own context menu is suppressed. When the menu closes, focus goes
back to the element that had focus when it opened, or else to the element that
carries these attributes, provided that element has an `id`. For the keyboard
the element must be able to take focus (add `tabindex` yourself; an `area` has
it already), and with nested elements only the innermost one opens its menu.

## State

### `State`

```elm
type State a  -- opaque: no constructors are exposed
```

The state of the context menu: whether it is open, which element it was
opened for (the `a`) and where on the screen. Create it with `init`, keep it in
your model, and change it with `close` and `update`.

### `Msg`

```elm
type Msg a  -- opaque: no constructors are exposed
```

The messages of the context menu. Wrap it in a constructor of your own
message type, such as `ContextMsg (ContextMenu.Msg Order)`, and hand it to
`update`.

### `init`

```elm
init : String -> State a
```

A closed menu. The id must be unique on the page; the ids of the parts of the
menu start with it.

### `update`

```elm
update : Msg a -> State a -> ( State a, Cmd (Msg a) )
```

Handles opening at the pointer, the menu keys and closing. Map its command
into your own message with `Cmd.map`.

### `isOpen`

```elm
isOpen : State a -> Bool
```

Is the menu open?

### `target`

```elm
target : State a -> Maybe a
```

What the menu was opened for (the `target` of the `area`, or the value given
to `attrs`), while it is open; `Nothing` when it is closed.

### `close`

```elm
close : State a -> ( State a, Cmd (Msg a) )
```

Closes the menu and gives focus back to the element it was opened from, if
that element has an id. The menu closes by itself when the user picks an item,
clicks outside it or presses `Escape`; call this when something else should
close it.
