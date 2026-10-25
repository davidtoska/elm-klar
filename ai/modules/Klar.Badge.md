# Klar.Badge

Small read-only labels for state and metadata, such as "Paid" or "Overdue", and round number badges.

Import: `import Klar.Badge as Badge` | Group: Status and feedback

Types: `Attribute`

## Signatures

```elm
-- Views
view : List Attribute -> String -> Html msg
status : Theme.Tone -> String -> Html msg
count : List Attribute -> Int -> Html msg

-- Attributes
type Attribute  -- opaque: no constructors are exposed
tone : Theme.Tone -> Attribute
solid : Attribute
outline : Attribute
dot : Attribute
icon : Icon.Icon -> Attribute
size : Theme.Size -> Attribute
max : Int -> Attribute
locale : Locale.Locale -> Attribute
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

    Badge.count [ Badge.tone Danger ] 128

A badge shows a state that the user reads but does not change. For something
the user picked and can take away, use [Klar.Tag](Klar.Tag.md). There are three
forms: `view` is a small box with a tinted background (or a `solid` or `outline`
one), `status` is a colored dot with text and no box, which fits well in table
cells, and `count` is a round number.

The color is not announced by screen readers, so put the meaning in the text
("Overdue", not just a red badge). A label that does not fit its container is
cut with an ellipsis; a label longer than 12 characters carries the whole text
as a tooltip. Every tone keeps WCAG AA contrast in every theme, the `solid` ones
included, and the dots stay visible in Windows high contrast. Badges never send
messages, so `Attribute` has no `msg` parameter.

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
and lists, where a column of boxes would be noisy. The dot has at least 3 : 1
contrast against the page, so a column of statuses can be scanned by color.

    Badge.status Success "In stock"

### `count`

```elm
count : List Attribute -> Int -> Html msg
```

A round number badge, such as a count of unread messages or of the errors in
a form. It is `Primary` and `solid` by default; `tone`, `outline`, `size` and
`max` change it, and `locale` how the number is written. A number above `max`
(99 by default) shows as "99+", while the tooltip and screen readers get the
exact number. A count of zero or less shows
nothing, so a badge for "nothing new" goes away by itself.

    Badge.count [] 7

    Badge.count [ Badge.tone Danger, Badge.size Small ] model.errorCount

## Attributes

### `Attribute`

```elm
type Attribute  -- opaque: no constructors are exposed
```

A setting of a badge. Make them with the functions below and pass a list to
`view` or `count`; later attributes win over earlier ones.

### `tone`

```elm
tone : Theme.Tone -> Attribute
```

The color of the badge: `Neutral` (gray, the default of `view`), `Primary`
(the default of `count`) or `Info` (the accent color), `Success`, `Warning` or
`Danger`.

### `solid`

```elm
solid : Attribute
```

A background filled with the color of the tone instead of the default light
tint, for a badge that has to stand out. A `count` is solid by default.

### `outline`

```elm
outline : Attribute
```

A border in the color of the tone and no fill, instead of the default light
tint (or, on a `count`, the solid fill).

### `dot`

```elm
dot : Attribute
```

A small dot before the text, in the color of the text. It has no effect on a
`count`.

### `icon`

```elm
icon : Icon.Icon -> Attribute
```

A small icon before the text (after the `dot`, if there is one). It has no
effect on a `count`.

### `size`

```elm
size : Theme.Size -> Attribute
```

The size of the badge: `Small` (16px high), `Medium` (20px, the default) or
`Large` (24px). A `count` is 16px, 18px or 22px.

### `max`

```elm
max : Int -> Attribute
```

The largest number a `count` writes out. A larger number shows as this number
with a plus ("99+"), while the tooltip and screen readers get the exact number.
The default is 99, and the smallest value is 1. It has no effect on `view`.

    Badge.count [ Badge.max 999 ] 1280 -- shows "999+"

### `locale`

```elm
locale : Locale.Locale -> Attribute
```

How a `count` writes its number: with the thousands separator of the locale
("1,280" in English, "1 280" in Norwegian), in the badge, its tooltip and what
screen readers hear. The default is `Locale.default`, which is English. It has
no effect on `view` and `status`, whose text is yours.

    Badge.count [ Badge.max 9999, Badge.locale Locale.nb ] 1280 -- shows "1 280"
