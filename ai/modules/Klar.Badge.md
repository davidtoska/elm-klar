# Klar.Badge

Small read-only labels for state and metadata, such as "Paid" or "Overdue", and round number badges.

Import: `import Klar.Badge as Badge` | Group: Status and feedback

Types: `Attribute`

## Signatures

```elm
-- Views
view : List Attribute -> String -> Html msg
status : Theme.Tone -> String -> Html msg
count : Int -> Html msg

-- Attributes
type Attribute  -- opaque: no constructors are exposed
tone : Theme.Tone -> Attribute
solid : Attribute
outline : Attribute
dot : Attribute
icon : Icon.Icon -> Attribute
size : Theme.Size -> Attribute
```

## Documentation

Small read-only labels for state and metadata, such as "Paid" or
"Overdue", and round number badges.

Use when: the user must read a state or a count, such as "Paid", "Overdue" or a number.
Do not use when: the label is something the user picked and can remove (as `Klar.Tag`).

    import Klar.Badge as Badge
    import Klar.Theme exposing (Tone(..))

    Badge.view [ Badge.tone Success ] "Paid"

    Badge.view [ Badge.tone Warning, Badge.dot ] "Pending"

    Badge.status Danger "Overdue"

    Badge.count 128

A badge shows a state that the user reads but does not change. For something
the user picked and can take away, use [Klar.Tag](Klar.Tag.md). There are three
forms: `view` is a small box with a tinted background (or a `solid` or `outline`
one), `status` is a colored dot with text and no box, which fits well in table
cells, and `count` is a round number.

The color is not announced by screen readers, so put the meaning in the text
("Overdue", not just a red badge). A label that does not fit its container is
cut with an ellipsis; labels longer than 18 characters (24 for `status`) carry
the whole text as a tooltip. Badges never send messages, so `Attribute` has no
`msg` parameter.

## Views

### `view`

```elm
view : List Attribute -> String -> Html msg
```

A badge with the given text. Name the state in the text: the color is only a
hint.

    Badge.view [ Badge.tone Success, Badge.solid ] "Shipped"

### `status`

```elm
status : Theme.Tone -> String -> Html msg
```

A plain status: a colored dot and text, without a box. Good inside tables
and lists, where a column of boxes would be noisy.

    Badge.status Success "In stock"

### `count`

```elm
count : Int -> Html msg
```

A round number badge, such as a count of unread messages. It shows `99+` for
every number above 99.

    Badge.count 128 -- shows "99+"

## Attributes

### `Attribute`

```elm
type Attribute  -- opaque: no constructors are exposed
```

A setting of a badge. Make them with the functions below and pass a list to
`view`; later attributes win over earlier ones.

### `tone`

```elm
tone : Theme.Tone -> Attribute
```

The color of the badge: `Neutral` (gray, the default), `Primary` or `Info`
(blue), `Success`, `Warning` or `Danger`.

### `solid`

```elm
solid : Attribute
```

A background filled with the color of the tone instead of the default light
tint, for a badge that has to stand out.

### `outline`

```elm
outline : Attribute
```

A border in the color of the tone and no fill, instead of the default light
tint.

### `dot`

```elm
dot : Attribute
```

A small dot before the text, in the color of the text.

### `icon`

```elm
icon : Icon.Icon -> Attribute
```

A small icon before the text (after the `dot`, if there is one).

### `size`

```elm
size : Theme.Size -> Attribute
```

The size of the badge: `Small` (16px high), `Medium` (20px, the default) or
`Large` (24px).
