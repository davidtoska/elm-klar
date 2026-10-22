# Klar.Skeleton

Shimmering placeholders that stand in for content while it loads.

Import: `import Klar.Skeleton as Skeleton` | Group: Status and feedback

## Signatures

```elm
-- Text
line : Int -> Html msg
lines : Int -> Html msg
paragraph : Int -> Html msg

-- Shapes
block : Int -> Html msg
circle : Int -> Html msg
```

## Documentation

Shimmering placeholders that stand in for content while it loads.

    import Klar.Layout as Layout
    import Klar.Skeleton as Skeleton

    Layout.stack [ Layout.gap 2 ]
        [ Skeleton.line 40
        , Skeleton.paragraph 3
        , Skeleton.block 120
        ]

Use a skeleton when you can sketch what the content will look like: a title and
a few lines of text, a picture, an avatar. When you cannot, show a
[Klar.Spinner](Klar.Spinner.md) instead. [Klar.Table](Klar.Table.md) and the other
components that load remote data draw their own skeletons.

Widths are percentages of the parent (`line 60` is 60% wide) and heights and
diameters are pixels, so a skeleton fills the space it is put in. Skeletons are
hidden from screen readers (`aria-hidden`), so the area that shows them should
say that content is on its way, for example with `aria-busy="true"` or a
spinner that has a label. The shimmer stands still for users who prefer reduced
motion.

## Text

### `line`

```elm
line : Int -> Html msg
```

One line of text, `percent` wide: a percentage of the parent, kept between
5 and 100. The line is 10px high.

    Skeleton.line 60

### `lines`

```elm
lines : Int -> Html msg
```

This many lines of text, one below the other, with the last one shorter
(60% wide) when there is more than one. There is always at least one line.

### `paragraph`

```elm
paragraph : Int -> Html msg
```

The same as `lines`: a paragraph of this many placeholder lines.

## Shapes

### `block`

```elm
block : Int -> Html msg
```

A rectangle as wide as its parent and `height` pixels high, for a picture,
a chart or a card.

    Skeleton.block 160

### `circle`

```elm
circle : Int -> Html msg
```

A round placeholder, `diameter` pixels wide and high, for an avatar.

    Skeleton.circle 30
