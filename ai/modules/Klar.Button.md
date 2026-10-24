# Klar.Button

Buttons and button-looking links.

Import: `import Klar.Button as Button` | Group: Actions

Types: `Attribute`

## Signatures

```elm
-- Views
view : List (Attribute msg) -> String -> Html msg
iconOnly : List (Attribute msg) -> Icon.Icon -> String -> Html msg

-- Look and size
type Attribute msg  -- opaque: no constructors are exposed
primary : Attribute msg
secondary : Attribute msg
ghost : Attribute msg
link : Attribute msg
danger : Attribute msg
small : Attribute msg
large : Attribute msg
size : Theme.Size -> Attribute msg
block : Attribute msg

-- Content
icon : Icon.Icon -> Attribute msg
iconRight : Icon.Icon -> Attribute msg
loading : Bool -> Attribute msg

-- Behavior
onClick : msg -> Attribute msg
submit : Attribute msg
href : String -> Attribute msg
newTab : Attribute msg
disabled : Bool -> Attribute msg
ariaDisabled : Bool -> Attribute msg

-- Accessibility and HTML
id : String -> Attribute msg
title : String -> Attribute msg
ariaLabel : String -> Attribute msg
pressed : Bool -> Attribute msg
expanded : Bool -> Attribute msg
htmlAttrs : List (Html.Attribute msg) -> Attribute msg
```

## Documentation

Buttons and button-looking links.

Use when: the user must trigger an action, or follow a link that should look like a button.
Do not use when: you need a plain link in running text (as `Klar.Link`) or a choice between options (as `Klar.SegmentedControl`).

    import Klar.Button as Button
    import Klar.Icon as Icon

    Button.view [ Button.primary, Button.onClick SaveOrder ] "Save order"

    Button.view [ Button.danger, Button.icon Icon.trash, Button.loading model.deleting ] "Delete"

    Button.iconOnly [ Button.ghost, Button.onClick Reload ] Icon.refresh "Reload"

    Button.view [ Button.href "#/orders" ] "Open orders"

There are four looks: `primary` (the one main action on a page), `secondary`
(the default), `ghost` (quiet, for toolbars and table rows) and `link` (looks
like a link). A button with `href` is rendered as an anchor, so it can be opened
in a new tab, but it keeps the look of the other buttons.

`danger` marks a destructive action. On its own (or with `primary`) it is the
solid red button. Combined with `secondary`, `ghost` or `link` it keeps that
look and only changes the tone: red text and, for `secondary`, a red border. The
order of the attributes does not matter.

    Button.view [ Button.danger ] "Delete" -- solid red

    Button.view [ Button.ghost, Button.danger ] "Delete" -- quiet, red text

    Button.view [ Button.secondary, Button.danger ] "Delete" -- white, red text and border

A button that is `loading` or `disabled` does not send its message and never
submits a form.

## Views

### `view`

```elm
view : List (Attribute msg) -> String -> Html msg
```

A button with a text label.

    Button.view [ Button.primary, Button.onClick Save ] "Save"

### `iconOnly`

```elm
iconOnly : List (Attribute msg) -> Icon.Icon -> String -> Html msg
```

A square button with only an icon. The label is the accessible name and the
native tooltip, so it must say what the button does.

    Button.iconOnly [ Button.ghost, Button.onClick Close ] Icon.close "Close"

## Look and size

### `Attribute`

```elm
type Attribute msg  -- opaque: no constructors are exposed
```

A setting of a button. Make them with the functions below and pass a list
to `view`; later attributes win over earlier ones.

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

A quiet button with no border until the pointer is over it. Good for
toolbars, table rows and icon-only buttons.

### `link`

```elm
link : Attribute msg
```

A button that looks like a link, for actions inside running text.

### `danger`

```elm
danger : Attribute msg
```

A destructive action. On its own (or with `primary`) the button is solid
red; with `secondary`, `ghost` or `link` it keeps that look and only the text
(and the border of a `secondary` button) turns red.

### `small`

```elm
small : Attribute msg
```

A compact button, 26px high.

### `large`

```elm
large : Attribute msg
```

A large button, 40px high, for the main action of an empty page or a form.

### `size`

```elm
size : Theme.Size -> Attribute msg
```

Sets the size from a variable. The default is `Medium` (32px). `small` and
`large` are shorthands.

### `block`

```elm
block : Attribute msg
```

Full width: the button fills its container.

## Content

### `icon`

```elm
icon : Icon.Icon -> Attribute msg
```

An icon before the label.

    Button.view [ Button.icon Icon.plus ] "New order"

### `iconRight`

```elm
iconRight : Icon.Icon -> Attribute msg
```

An icon after the label, such as a chevron on a button that opens a menu.

### `loading`

```elm
loading : Bool -> Attribute msg
```

While `True` the button shows a spinner instead of its icon, announces
`aria-busy`, and ignores clicks. Pass a field of your model, so the button
cannot be clicked twice while a request is on its way.

## Behavior

### `onClick`

```elm
onClick : msg -> Attribute msg
```

The message sent when the button is clicked (or activated with the
keyboard). Nothing is sent while the button is `loading`, `disabled` or
`ariaDisabled`.

### `submit`

```elm
submit : Attribute msg
```

Makes this the submit button of the surrounding `form`. Without it a button
has the type `button` and never submits anything.

### `href`

```elm
href : String -> Attribute msg
```

Makes the button an anchor that navigates to the URL. Use `#/path` for links
inside a single page application.

### `newTab`

```elm
newTab : Attribute msg
```

Opens a link made with `href` in a new tab (`target="_blank"`, with
`rel="noopener noreferrer"`).

### `disabled`

```elm
disabled : Bool -> Attribute msg
```

Disables the button with the HTML `disabled` attribute. A disabled button
cannot be focused, so keyboard users skip it; use `ariaDisabled` when it should
keep its place in the tab order.

### `ariaDisabled`

```elm
ariaDisabled : Bool -> Attribute msg
```

Dimmed and unclickable like `disabled`, but the button stays in the tab
order and keeps the keyboard focus (`aria-disabled`). Use it for a button that
becomes unavailable while the user is on it, such as "Load more" after the last
page. A button with the real `disabled` attribute loses its focus.

## Accessibility and HTML

### `id`

```elm
id : String -> Attribute msg
```

The DOM id of the button. Needed to return focus to it, for example with
`Modal.open`.

### `title`

```elm
title : String -> Attribute msg
```

The native tooltip (the `title` attribute). For a keyboard-friendly hint use
`Klar.Tooltip` instead.

### `ariaLabel`

```elm
ariaLabel : String -> Attribute msg
```

The accessible name, when it differs from the visible label.

### `pressed`

```elm
pressed : Bool -> Attribute msg
```

Makes the button a toggle and says whether it is on (`aria-pressed`).

    Button.view [ Button.pressed model.showArchived, Button.onClick ToggleArchived ] "Archived"

### `expanded`

```elm
expanded : Bool -> Attribute msg
```

For buttons that open a menu or a popup: says whether it is open
(`aria-expanded`).

### `htmlAttrs`

```elm
htmlAttrs : List (Html.Attribute msg) -> Attribute msg
```

An escape hatch for raw HTML attributes such as extra event handlers or
`data-` attributes. Other components that build on buttons use it.
