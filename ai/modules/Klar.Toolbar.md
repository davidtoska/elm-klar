# Klar.Toolbar

A horizontal bar of grouped controls for a whole view: the strip above a table or a list (new, export, search, view switches) or the actions of an editor.

Import: `import Klar.Toolbar as Toolbar` | Group: Structure

Types: `Attribute`

## Signatures

```elm
-- View
view : List Attribute -> List (Html msg) -> Html msg

-- Content
group : List (Html msg) -> Html msg
groupLabelled : String -> List (Html msg) -> Html msg
label : String -> Html msg
separator : Html msg
spacer : Html msg

-- Attributes
type Attribute  -- opaque: no constructors are exposed
ariaLabel : String -> Attribute
size : Theme.Size -> Attribute
small : Attribute
large : Attribute
plain : Attribute
scroll : Attribute
```

## Documentation

A horizontal bar of grouped controls for a whole view: the strip above a
table or a list (new, export, search, view switches) or the actions of an editor.

Use when: a row of grouped controls for the whole view is needed above a table, a list or an editor.
Do not use when: the actions are for the items the user has selected (use `Klar.BulkBar`, which covers this bar while something is selected; a `Klar.Table` draws its own with `Table.bulkActions`), or the actions belong in one dropdown (use `Klar.Menu`).

    import Klar.Button as Button
    import Klar.Icon as Icon
    import Klar.TextInput as TextInput
    import Klar.Toolbar as Toolbar

    Toolbar.view [ Toolbar.ariaLabel "Orders" ]
        [ Toolbar.group
            [ Button.view [ Button.primary, Button.icon Icon.plus, Button.onClick NewOrder ] "New order"
            , Button.view [ Button.icon Icon.download, Button.onClick Export ] "Export"
            ]
        , Toolbar.separator
        , Toolbar.groupLabelled "Layout"
            [ Button.iconOnly [ Button.ghost, Button.pressed (model.layout == Rows), Button.onClick (LayoutPicked Rows) ] Icon.list "Rows"
            , Button.iconOnly [ Button.ghost, Button.pressed (model.layout == Cards), Button.onClick (LayoutPicked Cards) ] Icon.grid "Cards"
            ]
        , Toolbar.spacer
        , Toolbar.label (String.fromInt model.matching ++ " orders")
        , TextInput.view
            [ TextInput.search
            , TextInput.label "Search orders"
            , TextInput.labelHidden
            , TextInput.value model.query
            , TextInput.onInput QueryChanged
            ]
        ]

The bar lays out whatever buttons, inputs and menus you give it in a row, and
keeps no state. When the user selects items of the list below it, hand this bar
to [Klar.BulkBar](Klar.BulkBar.md): the bar of actions for the selection takes its
place, in the same box, so nothing below moves. It wraps onto a second line when there is no room; `scroll` keeps
one line and scrolls sideways instead. The size (`size`, or `small` and `large`)
sets the height of every control inside the bar, so plain buttons and inputs line up
without extra work (a control with a size of its own keeps it). A text input
placed straight into the bar, or into a group, is 240px wide and can shrink to
140px.

The bar is a `group` of controls (`role="group"`), not an ARIA `toolbar`: it does
not manage focus, so every control is reached with Tab, in order, and the arrow
keys are not used, which is what a `toolbar` would promise to assistive
technology. Name the bar with `ariaLabel`, especially when a page has more than
one.

## View

### `view`

```elm
view : List Attribute -> List (Html msg) -> Html msg
```

The bar. The children are buttons, inputs, menus and the helpers below
(`group`, `separator`, `spacer`, `label`), laid out in a row in the order given.

## Content

### `group`

```elm
group : List (Html msg) -> Html msg
```

Controls that belong together. They sit close to each other and, when the
bar wraps, move to the next line as one block. Use `groupLabelled` when the group
needs a name for screen readers.

### `groupLabelled`

```elm
groupLabelled : String -> List (Html msg) -> Html msg
```

Like `group`, but the group is announced as a named group (`role="group"`)
by screen readers. The name is not shown.

    Toolbar.groupLabelled "Layout"
        [ Button.iconOnly [ Button.ghost ] Icon.list "List"
        , Button.iconOnly [ Button.ghost ] Icon.grid "Grid"
        ]

### `label`

```elm
label : String -> Html msg
```

Quiet gray text inside the bar, such as a count or a status.

    Toolbar.label "3 selected"

### `separator`

```elm
separator : Html msg
```

A thin vertical line between groups (`role="separator"`).

### `spacer`

```elm
spacer : Html msg
```

Flexible empty space that takes up the room left over on its line, so that
everything after it moves to the far end of the bar.

## Attributes

### `Attribute`

```elm
type Attribute  -- opaque: no constructors are exposed
```

A setting of the bar. Make them with the functions below and pass a list to
`view`; later attributes win over earlier ones. A toolbar sends no messages, so
the type has no `msg` parameter.

### `ariaLabel`

```elm
ariaLabel : String -> Attribute
```

The accessible name of the bar (`aria-label`): what the group of controls is
for, for example "Orders". There is no default; without it the bar has no name.

### `size`

```elm
size : Theme.Size -> Attribute
```

The height of the controls inside the bar, from a value (for example the
size the user picked in the settings): `Small` 26px, `Medium` 32px (the
default) or `Large` 40px, with the padding to match. Buttons and inputs inside
the bar follow, unless they have a size of their own. `small` and `large` are
shorthands.

    Toolbar.size model.toolbarSize

### `small`

```elm
small : Attribute
```

A compact bar: 26px controls instead of the usual 32px, and less padding.
The same as `size Small`.

### `large`

```elm
large : Attribute
```

A roomy bar: 40px controls and more padding. The same as `size Large`.

### `plain`

```elm
plain : Attribute
```

No border, no background and no padding, for a toolbar that sits inside
another surface such as a card header.

### `scroll`

```elm
scroll : Attribute
```

Keeps every control on one line and scrolls the bar sideways when they do not
fit, instead of wrapping onto more lines.
