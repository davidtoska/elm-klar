# Klar.Layout

Layout primitives: vertical stacks, horizontal rows and grids, with spacing from a fixed scale.

Import: `import Klar.Layout as Layout` | Group: Foundations

Types: `Attribute`

## Signatures

```elm
-- Layouts
stack : List (Attribute msg) -> List (Html msg) -> Html msg
row : List (Attribute msg) -> List (Html msg) -> Html msg
grid : List (Attribute msg) -> List (Html msg) -> Html msg
container : List (Attribute msg) -> List (Html msg) -> Html msg

-- Spacing and size
type Attribute msg  -- opaque: no constructors are exposed
gap : Int -> Attribute msg
padding : Int -> Attribute msg
fill : Attribute msg
grow : Attribute msg
width : Int -> Attribute msg
fillRest : Attribute msg
maxWidth : Int -> Attribute msg
maxHeight : Int -> Attribute msg

-- Alignment
alignStart : Attribute msg
alignCenter : Attribute msg
alignEnd : Attribute msg
alignStretch : Attribute msg
alignBaseline : Attribute msg
justifyCenter : Attribute msg
justifyEnd : Attribute msg
justifyBetween : Attribute msg
wrap : Attribute msg

-- Grid columns
columns : Int -> Attribute msg
minColumn : Int -> Attribute msg

-- Separators
spacer : Html msg
divider : Html msg
dividerLabelled : String -> Html msg
```

## Documentation

Layout primitives: vertical stacks, horizontal rows and grids, with spacing
from a fixed scale.

Use when: you arrange content in stacks, rows, grids or a page column with spacing from the design scale.
Do not use when: you need a frame for a whole application (as `Klar.AppShell`) or a grouped surface (as `Klar.Card`).

    import Klar.Layout as Layout
    import Klar.Text as Text

    Layout.stack [ Layout.gap 4 ]
        [ Text.title "Orders"
        , Layout.row [ Layout.gap 2, Layout.alignCenter ]
            [ searchField, Layout.spacer, newOrderButton ]
        , Layout.grid [ Layout.minColumn 240 ] (List.map viewOrderCard orders)
        ]

A `stack` puts its children below each other, a `row` next to each other and a
`grid` in columns. A `container` is a centered page column with a maximum width.
They are plain `div` elements that you configure with a list of attributes.
Not every attribute applies to every layout: `wrap` and `alignBaseline` are for
rows, `justifyCenter`, `justifyEnd` and `justifyBetween` for rows and stacks,
`columns` and `minColumn` for grids and `maxWidth` for containers. An attribute
that does not apply is ignored.

Spacing uses the 4px scale of the design tokens in the stylesheet: step `n` is
the custom property `--klar-space-n`, so `gap 2` is 8px, `gap 4` is 16px and
`gap 6` is 24px. Valid steps are 0, 1, 2, 3, 4, 5, 6, 8, 10 and 12. Other
numbers are rounded down to the step below (7 becomes 6, 9 becomes 8, 11 becomes
10), numbers above 12 become 12 and numbers below 1 become 0.

## Layouts

### `stack`

```elm
stack : List (Attribute msg) -> List (Html msg) -> Html msg
```

Lays the children out vertically, one below the other. By default the
children are stretched to the width of the stack; `alignStart`, `alignCenter`
and `alignEnd` let them keep their natural width.

    Layout.stack [ Layout.gap 2 ] [ Text.heading "Shipping", Text.paragraph "Two days." ]

### `row`

```elm
row : List (Attribute msg) -> List (Html msg) -> Html msg
```

Lays the children out next to each other, centered vertically unless you say
otherwise. Add `wrap` to let them continue on the next line.

    Layout.row [ Layout.gap 2 ] [ Button.view [] "Cancel", Button.view [ Button.primary ] "Save" ]

### `grid`

```elm
grid : List (Attribute msg) -> List (Html msg) -> Html msg
```

Lays the children out in a CSS grid. Use `columns n` for a fixed number of
equal columns or `minColumn px` for a responsive grid that adds and removes
columns as the space changes.

    Layout.grid [ Layout.columns 3, Layout.gap 4 ] cards

### `container`

```elm
container : List (Attribute msg) -> List (Html msg) -> Html msg
```

A centered page column with a maximum width (`maxWidth`, 1440px by default)
and 24px of padding on both sides.

    Layout.container [] [ pageContent ]

With `alignStart` it sits at the left edge of its parent instead, without side
padding: a narrow column of limited width.

    Layout.container [ Layout.maxWidth 640, Layout.alignStart ] [ form ]

## Spacing and size

### `Attribute`

```elm
type Attribute msg  -- opaque: no constructors are exposed
```

A setting of a layout. Make them with the functions below and pass a list to
`stack`, `row`, `grid` or `container`; later attributes win over earlier ones.

### `gap`

```elm
gap : Int -> Attribute msg
```

The space between the children, on the 4px scale: `gap 2` is 8px. The
default is 3 (12px). It applies to `stack`, `row` and `grid`.

### `padding`

```elm
padding : Int -> Attribute msg
```

The space between the edge of the element and its children, on the same
scale as `gap`. The default is 0 (none).

### `fill`

```elm
fill : Attribute msg
```

Makes the element as wide as its parent.

### `grow`

```elm
grow : Attribute msg
```

Lets the element take the space that is left over in the `row` or `stack`
it sits in. Give it to the part that should flex, such as the main column next
to a fixed sidebar.

    Layout.row [ Layout.gap 4, Layout.alignStart ]
        [ sidebar
        , Layout.stack [ Layout.grow ] [ content ]
        ]

### `width`

```elm
width : Int -> Attribute msg
```

Gives the element a fixed width in pixels, and lets it keep that width in a `row`
(it does not grow or shrink), so that the part next to it can `grow`: a tree, a filter
panel or a list beside the main area. On a screen narrower than the width it shrinks
to the width of its parent. At least 16 pixels.

    Layout.row [ Layout.gap 4, Layout.alignStart ]
        [ Layout.stack [ Layout.width 240 ] [ locationTree ]
        , Layout.stack [ Layout.grow ] [ table ]
        ]

### `fillRest`

```elm
fillRest : Attribute msg
```

Makes a `stack` as tall as the room that is left in its parent, and hands
that height on to its children: the way to give a `Table.fillHeight` a table
that fills the rest of the page. Inside an `AppShell` the parent is the content
area, so the stack is as tall as the window under the top bar; in a flex column
of your own it takes what the other children leave. The stack can still grow
beyond that when its content cannot be squeezed.

    AppShell.view attributes
        [ Layout.stack [ Layout.fillRest ]
            [ PageHeader.view [ PageHeader.title "Inbox" ]
            , Table.view TableMsg [ Table.fillHeight, Table.columns columns, Table.remote model.orders ] model.table
            ]
        ]

Stacks only. Without it a stack is as tall as its content.

### `maxWidth`

```elm
maxWidth : Int -> Attribute msg
```

The maximum width of a `container`, in pixels. The default is 1440. Other
layouts ignore it.

### `maxHeight`

```elm
maxHeight : Int -> Attribute msg
```

Limits the height to this many pixels and scrolls the content that does not
fit: a scroll area for lists and panels. It works on every layout. By default
the layout grows with its content.

A scroll area can take the keyboard focus (`tabindex="0"`), so that keyboard
users can scroll it with the arrow keys. Layouts without `maxHeight` are not
focusable.

## Alignment

### `alignStart`

```elm
alignStart : Attribute msg
```

Aligns the children at the start of the cross axis: at the top of a row, at
the left edge of a stack. On a `container` it makes a narrow column at the left
edge of its parent (see `container`).

### `alignCenter`

```elm
alignCenter : Attribute msg
```

Centers the children on the cross axis: vertically in a row, horizontally
in a stack. This is the default of a `row`.

### `alignEnd`

```elm
alignEnd : Attribute msg
```

Aligns the children at the end of the cross axis: at the bottom of a row,
at the right edge of a stack.

### `alignStretch`

```elm
alignStretch : Attribute msg
```

Stretches the children to fill the cross axis: as tall as the row, as wide as
the stack. This is the default of a `stack`.

### `alignBaseline`

```elm
alignBaseline : Attribute msg
```

Lines up the first line of text of every child, which looks right when the
children have different sizes. Rows only.

### `justifyCenter`

```elm
justifyCenter : Attribute msg
```

Centers the children along the main axis: horizontally in a row, vertically
in a stack that is taller than its content. Rows and stacks only.

### `justifyEnd`

```elm
justifyEnd : Attribute msg
```

Packs the children at the end of the main axis: at the right end of a row,
at the bottom of a stack that is taller than its content. Rows and stacks only.

### `justifyBetween`

```elm
justifyBetween : Attribute msg
```

Spreads the children along the main axis, with the first at the start, the
last at the end and the free space shared between them. Rows and stacks only.
To push just one child away, use `spacer`.

### `wrap`

```elm
wrap : Attribute msg
```

Lets the children of a row continue on a new line when they do not fit
instead of being squeezed. Rows only.

## Grid columns

### `columns`

```elm
columns : Int -> Attribute msg
```

A `grid` with this many equal columns. There is always at least one column:
0 and negative numbers count as 1. If a grid has both `columns` and `minColumn`,
`columns` wins.

### `minColumn`

```elm
minColumn : Int -> Attribute msg
```

A responsive `grid`: as many columns as fit, each at least this many pixels
wide, sharing the free space between them. Columns that would be empty collapse
(`auto-fit`), so two children in a wide grid share the whole row. On a screen narrower than one column
there is a single column of full width. A grid with neither `columns` nor
`minColumn` behaves like `minColumn 240`. The smallest width is 16 pixels:
smaller numbers (and 0 and negative numbers) count as 16.

## Separators

### `spacer`

```elm
spacer : Html msg
```

An empty, flexible element that pushes the elements after it to the far end
of a `row`.

    Layout.row [] [ Text.heading "Orders", Layout.spacer, newOrderButton ]

### `divider`

```elm
divider : Html msg
```

A thin horizontal line (an `hr` element) across the full width.

### `dividerLabelled`

```elm
dividerLabelled : String -> Html msg
```

A thin horizontal line with a label in the middle, such as "or" between two
groups of options.

    Layout.dividerLabelled "or"
