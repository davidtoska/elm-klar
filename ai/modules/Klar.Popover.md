# Klar.Popover

A small panel anchored to a button, with any content: a quick filter, a few settings, a short form, an explanation with a link.

Import: `import Klar.Popover as Popover` | Group: Overlays

Types: `Msg`, `State`, `Attribute`

## Signatures

```elm
-- View
view : (Msg -> msg) -> List (Attribute msg) -> State -> String -> List (Html msg) -> Html msg

-- State
type State  -- opaque: no constructors are exposed
type Msg  -- opaque: no constructors are exposed
init : String -> State
update : Msg -> State -> ( State, Cmd Msg )
isOpen : State -> Bool

-- Opening and closing
open : State -> ( State, Cmd Msg )
openFocusing : List String -> State -> ( State, Cmd Msg )
close : State -> ( State, Cmd Msg )
toggle : State -> ( State, Cmd Msg )

-- The button
type Attribute msg  -- opaque: no constructors are exposed
icon : Icon.Icon -> Attribute msg
iconOnly : Attribute msg
trigger : List (Button.Attribute msg) -> Attribute msg
customTrigger : (List (Html.Attribute msg) -> Html msg) -> Attribute msg

-- The panel
title : String -> Attribute msg
closeButton : Attribute msg
width : Int -> Attribute msg
alignEnd : Attribute msg
noPadding : Attribute msg
initialFocus : List String -> Attribute msg

-- Texts
locale : Locale.Locale -> Attribute msg
```

## Documentation

A small panel anchored to a button, with any content: a quick filter, a few
settings, a short form, an explanation with a link.

Use when: a small panel next to a button must hold any content, such as a quick filter or a few settings, and stay open while the user works in it.
Do not use when: you only need a list of actions (use `Klar.Menu`) or the work needs the full attention of the user (use `Klar.Modal`).
Quick path: `init`, `update`, `view`, `open`, `close`, `isOpen`

    -- model:   popover : Popover.State        (Popover.init "filter-popover")

    -- update
    PopoverMsg m ->
        let
            ( popover, cmd ) =
                Popover.update m model.popover
        in
        ( { model | popover = popover }, Cmd.map PopoverMsg cmd )

    ApplyFilter ->
        let
            ( popover, cmd ) =
                Popover.close model.popover
        in
        ( { model | popover = popover }
        , Cmd.batch [ loadOrders model.customer, Cmd.map PopoverMsg cmd ]
        )

    -- view
    Popover.view PopoverMsg
        [ Popover.icon Icon.filter
        , Popover.title "Quick filter"
        , Popover.closeButton
        , Popover.initialFocus [ "filter-customer" ]
        ]
        model.popover
        "Filter"
        [ TextInput.view
            [ TextInput.id "filter-customer"
            , TextInput.label "Customer"
            , TextInput.value model.customer
            , TextInput.onInput CustomerChanged
            ]
        , Button.view [ Button.primary, Button.onClick ApplyFilter ] "Apply"
        ]

The button opens the panel with a click, `Enter`, `Space` or `ArrowDown`. Where
the browser supports CSS anchor positioning, the panel is drawn next to the
button, is never clipped by a table or a dialog and flips above the button when
there is no room below; other browsers get plain positioning. Clicks inside the
panel do not close it. A click outside, `Escape` or the close button do, and
focus returns to the button. `Tab` out of the panel closes it too, and focus
goes where the user was heading. `Escape` pressed in a select or a menu that is
open inside the panel closes only that popup, and so does an `Escape` that a
control in the panel handled itself (a search field that cleared its text) or that
ends an IME composition. If the element that has focus in the panel is removed or
disabled (an "Apply" that becomes "Applying ..."), focus moves to the panel, so that
`Escape` and `Tab` keep working. [Klar.Modal](Klar.Modal.md) describes these rules,
shared by all popups and dialogs, in one place.

The label (`"Filter"` above) is a required argument of `view`: it is the text of
the button, or the name of an `iconOnly` button, and it names the panel when the
panel has no `title`. The panel is announced as a dialog. The only built-in text
is the label of the close button; it follows `locale`.
If a button in the panel opens a dialog, give the dialog to
[`Overlay.host`](Klar.Overlay.md#host): the page is then `inert`, so closing the panel,
which gives focus back to its button, cannot take focus away from the dialog.

## View

### `view`

```elm
view : (Msg -> msg) -> List (Attribute msg) -> State -> String -> List (Html msg) -> Html msg
```

The button labelled `label` and, while open, the panel with `content`. The
label is the text of the button (its accessible name with `iconOnly`), and it
names the panel when the panel has no `title`. `toMsg` wraps the messages of the
popover. The content is laid out in a column, one item below the other.

## State

### `State`

```elm
type State  -- opaque: no constructors are exposed
```

The state of one popover: whether its panel is open. Create it with `init`,
keep it in your model, and change it with `open`, `close`, `toggle` and
`update`.

### `Msg`

```elm
type Msg  -- opaque: no constructors are exposed
```

The messages of the popover (opening, closing, focus). Wrap it in a
constructor of your own message type, such as `PopoverMsg Popover.Msg`, and hand
it to `update`.

### `init`

```elm
init : String -> State
```

A closed popover. The id must be unique on the page; the ids of the button
and of the panel start with it.

### `update`

```elm
update : Msg -> State -> ( State, Cmd Msg )
```

Handles opening, closing and focus. Map its command into your own message
with `Cmd.map`.

### `isOpen`

```elm
isOpen : State -> Bool
```

Is the panel open? It follows the user (the button, a click outside the panel,
`Escape`) as well as your calls to `open` and `close`.

## Opening and closing

The button opens and closes the panel by itself. These functions are for the
rest: closing the panel when the work in it is done, or opening it from a
keyboard shortcut.

### `open`

```elm
open : State -> ( State, Cmd Msg )
```

Opens the panel and moves focus into it (to the panel itself; use
`openFocusing` to focus a field). It ignores the `initialFocus` attribute, which
applies when the user opens the panel with the button.

### `openFocusing`

```elm
openFocusing : List String -> State -> ( State, Cmd Msg )
```

Opens the panel and focuses the first of these elements that exists (ids of
fields inside the panel). If none exists, the panel itself gets focus.

### `close`

```elm
close : State -> ( State, Cmd Msg )
```

Closes the panel and gives focus back to its button. Call it from a button
inside the panel when the work is done, such as "Apply".

### `toggle`

```elm
toggle : State -> ( State, Cmd Msg )
```

Opens the panel if it is closed, closes it if it is open. Like `open`, it
ignores the `initialFocus` attribute.

## The button

### `Attribute`

```elm
type Attribute msg  -- opaque: no constructors are exposed
```

A setting of a popover. Make them with the functions below and pass a list to
`view`; later attributes win over earlier ones.

### `icon`

```elm
icon : Icon.Icon -> Attribute msg
```

An icon on the button, before the label.

### `iconOnly`

```elm
iconOnly : Attribute msg
```

The button shows only its icon (three dots if you give no `icon`), and the
label of `view` becomes its accessible name.

    Popover.view HelpMsg [ Popover.icon Icon.help, Popover.iconOnly ] model.help "What is priority?" [ explanation ]

### `trigger`

```elm
trigger : List (Button.Attribute msg) -> Attribute msg
```

Style the button: `Popover.trigger [ Button.ghost, Button.small ]`. The
attributes add up when you use it more than once. It has no effect with
`customTrigger`.

### `customTrigger`

```elm
customTrigger : (List (Html.Attribute msg) -> Html msg) -> Attribute msg
```

Use your own element as the button. The function receives the attributes it
must put on that element (`id`, `aria-haspopup`, `aria-expanded`, the click
handler and the `ArrowDown` handler); without them the panel cannot open and
focus cannot return to the element. Your element shows its own text; the label of
`view` still names the panel when it has no `title`.

    Popover.customTrigger (\attrs -> Button.view [ Button.htmlAttrs attrs ] "Filter")

## The panel

### `title`

```elm
title : String -> Attribute msg
```

A heading in the panel; it is also the accessible name of the panel, instead
of the label.

### `closeButton`

```elm
closeButton : Attribute msg
```

A close button in the header of the panel. Its label follows `locale`. The
header is shown when the panel has a `title` or a close button.

### `width`

```elm
width : Int -> Attribute msg
```

Width of the panel in pixels. The default is 320. The panel is never wider
than 520px or the window.

### `alignEnd`

```elm
alignEnd : Attribute msg
```

Align the right edge of the panel with the right edge of the button, so that
the panel extends to the left. Use it for a button near the right edge of the
window.

### `noPadding`

```elm
noPadding : Attribute msg
```

No padding around the content, for lists and tables that go edge to edge.
Content taller than 70% of the window (at most 520px) scrolls.

### `initialFocus`

```elm
initialFocus : List String -> Attribute msg
```

Ids of elements inside the panel that should get focus when the user opens
it with the button (the first one that exists). Without it the panel itself gets
focus. `open` and `toggle` ignore this attribute; when you open the panel from
your own code, use `openFocusing`.

## Texts

### `locale`

```elm
locale : Locale.Locale -> Attribute msg
```

The language of the built-in text, which is the label of the close button
("Close" by default). The default language is
[`Locale.default`](Klar.Locale.md#default), which is English.
