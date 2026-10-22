# Klar.ButtonGroup

Buttons that belong together, joined into one block: shared borders, only the outer corners rounded, and one focus ring per button that always stays in view.

Import: `import Klar.ButtonGroup as ButtonGroup` | Group: Actions

Types: `Attribute`

## Signatures

```elm
-- View
view : List Attribute -> String -> List (Html msg) -> Html msg

-- Attributes
type Attribute  -- opaque: no constructors are exposed
size : Theme.Size -> Attribute
disabled : Bool -> Attribute
```

## Documentation

Buttons that belong together, joined into one block: shared borders, only the
outer corners rounded, and one focus ring per button that always stays in view.

    import Klar.Button as Button
    import Klar.ButtonGroup as ButtonGroup
    import Klar.Icon as Icon

    ButtonGroup.view [] "Order actions"
        [ Button.view [ Button.icon Icon.edit, Button.onClick Edit ] "Edit"
        , Button.view [ Button.icon Icon.copy, Button.onClick Duplicate ] "Duplicate"
        , Button.iconOnly [ Button.onClick Print ] Icon.print "Print"
        ]

The children are ordinary [Klar.Button](Klar.Button.md) buttons (a button with an
`href` too, and the button of a [Klar.Menu](Klar.Menu.md) as the last one), so
everything a button can do still works. Each one is a separate button, reached with
Tab and activated with Enter or Space. The group is named by its first argument
(`role="group"` with that `aria-label`), because screen readers announce it when
the focus enters it.

Use it for actions that are close in meaning and that you want to read as one
control, such as "Edit / Duplicate / Print". For a choice between views use
[Klar.SegmentedControl](Klar.SegmentedControl.md), for options that are on or off
use [Klar.ToggleGroup](Klar.ToggleGroup.md), and for a main action with a few
alternatives [Klar.SplitButton](Klar.SplitButton.md). In a
[Klar.Toolbar](Klar.Toolbar.md) the group takes the size of the bar, like a button.

The group never wraps. It is a `fieldset` that is also `inert` while it is
`disabled`, so `disabled` turns off every button in it at once, links that look
like buttons (`Button.href`) included: nothing in a disabled group can be clicked,
focused or activated with the keyboard. As with all inert content, screen readers
skip a disabled group instead of announcing its buttons as dimmed, so say in text
why an action is not available if that matters to the user. The buttons keep the
size they have (`size` sets it for the buttons that have none of their own).

## View

### `view`

```elm
view : List Attribute -> String -> List (Html msg) -> Html msg
```

The group: its accessible name, then the buttons. The name is not shown; put a
visible label next to the group yourself if the page needs one.

    ButtonGroup.view [ ButtonGroup.size Small ] "Text alignment" [ left, center, right ]

## Attributes

### `Attribute`

```elm
type Attribute  -- opaque: no constructors are exposed
```

A setting of the group. Make them with `size` and `disabled` and pass a list
to `view`; later attributes win over earlier ones. A group sends no messages, so
the type has no `msg` parameter.

### `size`

```elm
size : Theme.Size -> Attribute
```

The size of the buttons that have none of their own: `Small`, `Medium` (the
default) or `Large` (see [Klar.Theme](Klar.Theme.md)). A button made with `Button.small`
or `Button.large` keeps its size.

### `disabled`

```elm
disabled : Bool -> Attribute
```

Turns off every button and link in the group (`fieldset` with `disabled` and
`inert`): they are dimmed, cannot be clicked, are skipped by Tab and cannot be
activated with the keyboard. A screen reader does not read inert content. The
default is `False`. Pass a value from your model.
