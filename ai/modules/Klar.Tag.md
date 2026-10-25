# Klar.Tag

A chip: a short label for a value, a filter or a selection, optionally with a remove button.

Import: `import Klar.Tag as Tag` | Group: Status and feedback

Types: `Attribute`

## Signatures

```elm
-- View
view : List (Attribute msg) -> String -> Html msg

-- Attributes
type Attribute msg  -- opaque: no constructors are exposed
tone : Theme.Tone -> Attribute msg
color : Color.Color -> Attribute msg
outline : Attribute msg
size : Theme.Size -> Attribute msg
icon : Icon.Icon -> Attribute msg

-- Removing
onRemove : msg -> Attribute msg
removeId : String -> Attribute msg
removeLabel : String -> Attribute msg
nextFocus : { removed : a, tags : List a, toId : a -> String, otherwise : String } -> String
locale : Locale.Locale -> Attribute msg
```

## Documentation

A chip: a short label for a value, a filter or a selection, optionally
with a remove button.

Use when: a chip shows a value, filter or selection that the user chose and can take away.
Do not use when: the label is a read-only state (as `Klar.Badge`).

    import Klar.Tag as Tag
    import Klar.Theme exposing (Tone(..))

    Tag.view [] "Warehouse A"

    Tag.view [ Tag.tone Primary, Tag.onRemove (TagRemoved "a") ] "Warehouse A"

Unlike [Klar.Badge](Klar.Badge.md) (state, read-only) a tag represents something
the user chose and can take away. The tag does not remove itself: `onRemove`
sends your message, and you take the value out of your model.

The remove button is a real button with a 24px target whose accessible name is
"Remove" followed by the label ("Remove Warehouse A"); `removeLabel` names it
yourself ("Remove filter Amount > 100"). A tag that is removed with the keyboard
takes the focus with it, and the focus is lost. Give every button an id with
`removeId`, and when your message arrives focus the tag that took its place:
`nextFocus` picks it (see the example there). A label that does not fit its
container is cut with an ellipsis; a label longer than 12 characters carries the
whole text as a tooltip.

## View

### `view`

```elm
view : List (Attribute msg) -> String -> Html msg
```

A tag with the given label. Add `onRemove` to make it removable.

    Tag.view [ Tag.outline, Tag.icon Icon.mapPin ] "Oslo warehouse"

## Attributes

### `Attribute`

```elm
type Attribute msg  -- opaque: no constructors are exposed
```

A setting of a tag. Make them with the functions below and pass a list to
`view`; later attributes win over earlier ones.

### `tone`

```elm
tone : Theme.Tone -> Attribute msg
```

The color of the tag: `Neutral` (gray, the default), `Primary` or `Info`
(blue), `Success`, `Warning` or `Danger`.

### `color`

```elm
color : Color.Color -> Attribute msg
```

A small dot in a color from your data before the label, for a tag that stands
for a row with a color (a status, a team). The tag keeps its tone; the label must
say what the color says.

### `outline`

```elm
outline : Attribute msg
```

No fill: the tag keeps its border and text color but gets a transparent
background.

### `size`

```elm
size : Theme.Size -> Attribute msg
```

The size of the tag: `Small` (18px high), `Medium` (22px, the default) or
`Large` (26px).

### `icon`

```elm
icon : Icon.Icon -> Attribute msg
```

A small icon before the label.

## Removing

### `onRemove`

```elm
onRemove : msg -> Attribute msg
```

Shows a small × button after the label that sends this message when it is
pressed: a click, `Enter` or `Space`, or a fresh press of `Delete` or `Backspace`
while the button has the focus. A held `Delete` or `Backspace` does not repeat:
after the focus has moved to the next tag (`nextFocus`), the repeats would remove
that one too, and the next, until the list is empty. The tag does not remove
itself: take the value out of your model when the message arrives.

### `removeId`

```elm
removeId : String -> Attribute msg
```

The DOM id of the remove button, for moving the focus to it from your
application (`Klar.focus`), for example to the next tag after one was
removed, so that keyboard users do not lose their place (see `nextFocus`).

### `removeLabel`

```elm
removeLabel : String -> Attribute msg
```

The accessible name and the tooltip of the remove button, instead of
"Remove" followed by the label. Use it when the label alone does not say what
goes away, such as a filter chip whose label is a value:

    Tag.view
        [ Tag.onRemove (FilterRemoved "amount")
        , Tag.removeLabel "Remove filter Amount > 100"
        ]
        "Amount > 100"

### `nextFocus`

```elm
nextFocus : { removed : a, tags : List a, toId : a -> String, otherwise : String } -> String
```

The id to focus after a tag was removed with its button, so that keyboard
users keep their place: the remove button of the tag after it, else of the tag
before it, else `otherwise` (the control that adds tags, or a heading). Give it
the tags as they were before the removal, and the same id function as
`removeId`. The tags must be unique (`==`), as their ids are: with two equal
values the first one is taken as the removed one.

    viewTag : Warehouse -> Html Msg
    viewTag warehouse =
        Tag.view
            [ Tag.onRemove (WarehouseRemoved warehouse)
            , Tag.removeId (removeIdOf warehouse)
            ]
            warehouse.name

    removeIdOf : Warehouse -> String
    removeIdOf warehouse =
        "remove-" ++ warehouse.code

    -- in update
    WarehouseRemoved warehouse ->
        ( { model | warehouses = List.filter (\w -> w /= warehouse) model.warehouses }
        , Klar.focus
            (Tag.nextFocus
                { removed = warehouse
                , tags = model.warehouses
                , toId = removeIdOf
                , otherwise = "add-warehouse"
                }
            )
            NoOp
        )

### `locale`

```elm
locale : Locale.Locale -> Attribute msg
```

The language of the built-in text, which is the accessible name and the
tooltip of the remove button ("Remove Warehouse A" in English). The default is
`Locale.default`, which is English.
