# Klar.Card

A bordered surface that groups related content, with an optional header and footer.

Import: `import Klar.Card as Card` | Group: Foundations

Types: `Attribute`

## Signatures

```elm
-- View
view : List (Attribute msg) -> List (Html msg) -> Html msg

-- Header and footer
type Attribute msg  -- opaque: no constructors are exposed
title : String -> Attribute msg
headingLevel : Int -> Attribute msg
subtitle : String -> Attribute msg
actions : List (Html msg) -> Attribute msg
footer : List (Html msg) -> Attribute msg

-- Look
flush : Attribute msg
sunken : Attribute msg
raised : Attribute msg
accent : Theme.Tone -> Attribute msg

-- HTML
id : String -> Attribute msg
```

## Documentation

A bordered surface that groups related content, with an optional header and
footer.

Use when: related content belongs together on a bordered surface with an optional title, actions and footer.
Do not use when: the content is a whole page region with its own header (as `Klar.PageHeader`) or an overlay (as `Klar.Modal`).
Quick path: `view`, `title`, `actions`, `footer`, `RemoteView.view`

    import Klar.Button as Button
    import Klar.Card as Card

    Card.view
        [ Card.title "Recent activity"
        , Card.subtitle "Last 30 days"
        , Card.actions [ Button.view [ Button.small ] "Export" ]
        ]
        [ content ]

The header is shown when the card has a title, a subtitle or actions. The card
is a `section` element and its title is an `h2`, the level under the `h1` of a
`PageHeader`, unless you choose another level
with `headingLevel`, so that the title fits the outline of the page (see
[Klar.Text](Klar.Text.md) for the other headings). `flush` removes the padding of
the body, for tables and lists that go edge to edge; `accent`, `sunken` and
`raised` change the look.

A card with an `id` and a title is a named region: a landmark that screen readers
list with the other landmarks of the page, named by its title, so a person can jump
from card to card on a dashboard. Give an `id` to the few cards that are the main
parts of a page, not to every card: twelve landmarks are as hard to use as none. A
card needs no id for focus; focus goes to its body (`RemoteView.id` below).

A card that shows one piece of remote data takes its body from
[Klar.RemoteView](Klar.RemoteView.md): the loading skeleton, the failure with a
retry, and old or refreshing data, without a `case` of your own. Give the body an
`id` and move focus to it when the retry starts, because the "Try again" button that
had the focus is replaced by the skeleton:

    -- view: `settings` gives the time zone of "Old data from 14:05", `locale` the language
    Card.view [ Card.title "Order 1042" ]
        (RemoteView.view
            [ RemoteView.id "order-body"
            , RemoteView.onRetry ReloadOrder
            , RemoteView.settings model.settings
            , RemoteView.locale (Settings.locale model.settings)
            ]
            model.order
            viewOrder
        )

    -- update
    ReloadOrder ->
        ( { model | order = Remote.refresh model.order }
        , Cmd.batch [ fetchOrder, Klar.focus "order-body" NoOp ]
        )

## View

### `view`

```elm
view : List (Attribute msg) -> List (Html msg) -> Html msg
```

A card with the given content in its body. The attributes decide on the
header, the footer and the look of the card.

    Card.view [ Card.title "Shipping address" ] [ Text.paragraph "12 Main Street" ]

## Header and footer

### `Attribute`

```elm
type Attribute msg  -- opaque: no constructors are exposed
```

A setting of a card. Make them with the functions below and pass a list to
`view`; later attributes win over earlier ones.

### `title`

```elm
title : String -> Attribute msg
```

The title in the header, an `h2` unless you set another level with
`headingLevel`. A card without a title, a subtitle or actions has no header.

### `headingLevel`

```elm
headingLevel : Int -> Attribute msg
```

The level of the heading element of the title, from 1 to 6: `headingLevel 3`
makes it an `h3`. The default is 2, the level under the `h1` of a
[PageHeader](Klar.PageHeader.md). A number outside the range counts as the nearest
level. Choose another level for a card inside a section that has its own `h2`
(the card then takes 3): one below the heading of the section the card is in. The
level changes the element, not the look of the title.

    Card.view [ Card.title "Recent activity", Card.headingLevel 3 ] [ content ]

### `subtitle`

```elm
subtitle : String -> Attribute msg
```

A smaller line under the title, such as a period or a count. An empty text is no
subtitle.

### `actions`

```elm
actions : List (Html msg) -> Attribute msg
```

Buttons or links at the right end of the header. On a narrow card they move
below the title.

### `footer`

```elm
footer : List (Html msg) -> Attribute msg
```

A tinted strip below the body, such as a summary or a few buttons, laid out in a
row that wraps. It starts at the left; a `Layout.spacer` pushes what comes after it
to the right end. An empty list is no footer.

    Card.footer [ Text.caption "Updated 3 minutes ago", Layout.spacer, Button.view [ Button.small ] "View all" ]

## Look

### `flush`

```elm
flush : Attribute msg
```

No padding around the body, so that a table, a list or a picture goes edge to
edge. The header and the footer keep their padding.

### `sunken`

```elm
sunken : Attribute msg
```

A light gray background instead of white, for less prominent content.

### `raised`

```elm
raised : Attribute msg
```

A subtle shadow, to lift the card off the page.

### `accent`

```elm
accent : Theme.Tone -> Attribute msg
```

A colored strip along the left edge, to mark a status. `Neutral` is gray,
`Primary` and `Info` are blue, and `Success`, `Warning` and `Danger` have colors
of their own.

    Card.view [ Card.title "Payment failed", Card.accent Danger ] [ details ]

## HTML

### `id`

```elm
id : String -> Attribute msg
```

The DOM id of the card. With a title, it also makes the card a named region, a
landmark of the page: the title gets the id `<id>-title` and the card points at it
with `aria-labelledby`. So give it only to the main cards of a page, the ones a person
jumps between; a card does not need an id to be scrolled to or focused inside.
