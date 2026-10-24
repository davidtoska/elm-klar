# Klar.SplitButton

A main action with a few alternatives: a button joined to a small arrow that opens a menu. "Save" with "Save and close" and "Save as draft" behind the arrow.

Import: `import Klar.SplitButton as SplitButton` | Group: Actions

Types: `Msg`, `State`, `Attribute`

## Signatures

```elm
-- View
view :
    (Msg -> msg)
    -> List (Attribute msg)
    -> { label : String, onClick : msg, items : List (Menu.Item msg) }
    -> State
    -> Html msg

-- State
type State  -- opaque: no constructors are exposed
type Msg  -- opaque: no constructors are exposed
init : String -> State
update : Msg -> State -> ( State, Cmd Msg )
isOpen : State -> Bool
open : State -> ( State, Cmd Msg )
close : State -> ( State, Cmd Msg )
mainId : State -> String
triggerId : State -> String

-- Attributes
type Attribute msg  -- opaque: no constructors are exposed
primary : Attribute msg
secondary : Attribute msg
ghost : Attribute msg
danger : Attribute msg
small : Attribute msg
large : Attribute msg
size : Theme.Size -> Attribute msg
icon : Icon.Icon -> Attribute msg
loading : Bool -> Attribute msg
disabled : Bool -> Attribute msg
menuLabel : String -> Attribute msg
locale : Locale.Locale -> Attribute msg
```

## Documentation

A main action with a few alternatives: a button joined to a small arrow that
opens a menu. "Save" with "Save and close" and "Save as draft" behind the arrow.

Use when: one main action has a few alternatives behind an arrow, such as "Save" and "Save and close".
Do not use when: the actions are equal (as `Klar.ButtonGroup`) or there is no main action (as `Klar.Menu`).
Quick path: `init`, `update`, `view`, `isOpen`

    import Klar.Menu as Menu
    import Klar.SplitButton as SplitButton

    -- model:   saveSplit : SplitButton.State   (SplitButton.init "order-save")

    -- update
    SaveSplitMsg m ->
        let
            ( split, cmd ) =
                SplitButton.update m model.saveSplit
        in
        ( { model | saveSplit = split }, Cmd.map SaveSplitMsg cmd )

    -- view
    SplitButton.view SaveSplitMsg
        [ SplitButton.primary, SplitButton.loading model.saving ]
        { label = "Save"
        , onClick = Save
        , items =
            [ Menu.item "Save and close" SaveAndClose
            , Menu.item "Save as draft" SaveDraft
            , Menu.separator
            , Menu.item "Discard changes" Discard |> Menu.danger
            ]
        }
        model.saveSplit

The main part sends `onClick`, the one message that every split button must
have. The arrow opens a [Klar.Menu](Klar.Menu.md): the items are made with
`Menu.item`, `Menu.separator`, `Menu.withIcon`, `Menu.danger` and the other
functions of that module, and picking one sends its own message and closes the
menu. The menu is the menu of that module, so it opens below the button with its
right edge level with the button's (it flips above when there is no room), is
never cut off by a table or a dialog, and shuts when the user clicks outside it.
A split button without items has no arrow and looks like an ordinary button, and
the main button stays the same element when items arrive later (remote data), so
it keeps the keyboard focus.

**Keyboard.** The two parts are two buttons in the Tab order. Enter and Space on the
main part send `onClick`; on the arrow they open the menu with the first item
highlighted. `ArrowDown` on either part opens the menu at the first item, and so
does `Alt+ArrowDown` (the key that opens a list in most programs); `ArrowUp` on
the arrow opens it at the last item. The focus moves into the menu: `ArrowDown`
and `ArrowUp` move the highlight, a letter jumps to the next item that starts
with it, Enter or Space picks it, `Home` and `End` jump to the first and last,
`Escape` closes the menu and gives focus back to the arrow, and `Tab` leaves the
menu. Screen readers get a button, and a second button named "More options for
Save" that has a menu (`aria-haspopup`) and says whether it is open
(`aria-expanded`); the arrow shows that name as its tooltip.

While the button is `loading` the main part shows a spinner and does nothing, and
the arrow cannot open the menu; with `disabled` both parts are dimmed and do
nothing. In both cases the parts are `aria-disabled` and stay in the tab order, so
a user who has just picked an item (or pressed the main part) keeps the keyboard
focus. A menu that is open when this happens stays open and working until it is
closed (`close`, `Escape`, a click outside): the state is never faked. If the
items go away while the menu is open, the empty menu stays until it is closed,
and focus then goes to the main part. The look (`primary`, `secondary`, `ghost`,
`danger`, the sizes) is the look of a [Klar.Button](Klar.Button.md), and the same for
both parts. Each split button needs a `State` and an id of its own. The built-in
text ("More options for") follows `locale`.

A dialog opened from the main part or from an item names its opener, so that
focus goes back there when it closes: `mainId` for the main part, `triggerId`
for the arrow.

For two buttons that are separate actions, side by side, use a
[Klar.ButtonGroup](Klar.ButtonGroup.md); for a menu with no main action
[Klar.Menu](Klar.Menu.md) itself.

## View

### `view`

```elm
view :
    (Msg -> msg)
    -> List (Attribute msg)
    -> { label : String, onClick : msg, items : List (Menu.Item msg) }
    -> State
    -> Html msg
```

The main button and the arrow with its menu. The first argument turns the
messages of the menu into yours. The record is what every split button needs: the
text of the main part, the message it sends, and the items of the menu (see
`Menu.item`).

## State

### `State`

```elm
type State  -- opaque: no constructors are exposed
```

The state of one split button: whether its menu is open and which item is
highlighted. Make it with `init` and keep it in your model.

### `Msg`

```elm
type Msg  -- opaque: no constructors are exposed
```

The messages of the split button: opening and closing the menu and moving the
highlight. Wrap it in a constructor of your own message type and hand it to
`update`. The click on the main part is not one of them: it sends your `onClick`.

### `init`

```elm
init : String -> State
```

A split button with a closed menu. The `String` is a DOM id that must be
unique on the page; the ids of the main part (`mainId`), the arrow (`triggerId`),
the menu and its items start with it.

    SplitButton.init "order-save"

### `update`

```elm
update : Msg -> State -> ( State, Cmd Msg )
```

Handles the menu and moves keyboard focus into it and back to the arrow.
Map its command into your own message with `Cmd.map`. Picking an item does not go
through here: it sends the message of the item.

### `isOpen`

```elm
isOpen : State -> Bool
```

Is the menu open?

### `open`

```elm
open : State -> ( State, Cmd Msg )
```

Opens the menu with the first item highlighted and moves keyboard focus into
it, for example from a keyboard shortcut.

### `close`

```elm
close : State -> ( State, Cmd Msg )
```

Closes the menu and gives focus back to the arrow. The menu closes by itself
when the user picks an item, clicks outside it or presses `Escape`.

### `mainId`

```elm
mainId : State -> String
```

The DOM id of the main part. Give it to `Modal.open` (or `ConfirmDialog.open`)
when the main action opens a dialog ("Save..."), so that focus goes back to it
when the dialog closes.

### `triggerId`

```elm
triggerId : State -> String
```

The DOM id of the arrow that opens the menu. Give it to `Modal.open` when an
item of the menu opens a dialog.

## Attributes

### `Attribute`

```elm
type Attribute msg  -- opaque: no constructors are exposed
```

A setting of a split button. Make them with the functions below and pass a
list to `view`; later attributes win over earlier ones. What the button does is in
the arguments of `view`.

### `primary`

```elm
primary : Attribute msg
```

The one main action of a page or dialog: solid blue. Use it once per view.

### `secondary`

```elm
secondary : Attribute msg
```

The default look: white with a thin gray border.

### `ghost`

```elm
ghost : Attribute msg
```

A quiet button with no border until the pointer is over it, for toolbars.

### `danger`

```elm
danger : Attribute msg
```

A destructive action. On its own (or with `primary`) the button is solid red;
with `secondary` or `ghost` it keeps that look and only the text (and the border
of a `secondary` button) turns red, exactly as with
[`Button.danger`](Klar.Button.md#danger).

### `small`

```elm
small : Attribute msg
```

A compact button, 26px high.

### `large`

```elm
large : Attribute msg
```

A large button, 40px high.

### `size`

```elm
size : Theme.Size -> Attribute msg
```

Sets the size from a variable. The default is `Medium` (32px). `small` and
`large` are shorthands.

### `icon`

```elm
icon : Icon.Icon -> Attribute msg
```

An icon before the text of the main part.

### `loading`

```elm
loading : Bool -> Attribute msg
```

While `True` the main part shows a spinner instead of its icon, announces
`aria-busy` and ignores clicks, and the arrow cannot open the menu. Both parts
stay in the tab order (`aria-disabled`, not `disabled`), so a user who has just
picked an item from the menu keeps the keyboard focus. Pass a field of your
model, so the button cannot be clicked twice while a request is on its way.

### `disabled`

```elm
disabled : Bool -> Attribute msg
```

Turns both parts off: they are dimmed, send nothing and cannot open the menu,
and screen readers hear that they are unavailable (`aria-disabled`). They stay in
the tab order, so a split button that is disabled while the user is on it keeps
the focus. A menu that is open stays open until it is closed. The default is
`False`.

### `menuLabel`

```elm
menuLabel : String -> Attribute msg
```

The accessible name of the arrow, which has no text. The default is "More
options for" and the text of the main part ("More options for Save"), in the
language of `locale`. Set it when the default does not fit, for example "Save options".

### `locale`

```elm
locale : Locale.Locale -> Attribute msg
```

The language of the built-in text, the accessible name of the arrow. The
default is `Locale.default`, which is `Locale.en`.
