# Klar.VirtualList

A list of thousands of rows that draws only the rows in view, and is a list box for the keyboard.

Import: `import Klar.VirtualList as VirtualList` | Group: Choosing

Types: `Msg`, `State`, `Attribute`, `Geometry`

## Signatures

```elm
-- State
type State  -- opaque: no constructors are exposed
type Msg  -- opaque: no constructors are exposed
init : String -> State
update : Msg -> State -> ( State, Cmd Msg )
list :
    (Msg -> msg)
    -> List (Attribute msg)
    -> { label : String, items : Array a, viewRow : a -> Html msg }
    -> State
    -> Html msg

-- Reading the state
id : State -> String
scrollTop : State -> Float
active : State -> Maybe Int
reveal : List (Attribute msg) -> { row : Int, count : Int } -> State -> ( State, Cmd Msg )

-- Attributes
type Attribute msg  -- opaque: no constructors are exposed
density : Theme.Density -> Attribute msg
onSelect : (Int -> msg) -> Attribute msg
selected : Maybe Int -> Attribute msg
height : Int -> Attribute msg
htmlAttrs : List (Html.Attribute msg) -> Attribute msg

-- Rows of your own
view :
    (Msg -> msg)
    -> List (Attribute msg)
    -> { items : Array a, viewRow : Int -> a -> Html msg }
    -> State
    -> Html msg
viewGrouped :
    (Msg -> msg)
    -> List (Attribute msg)
    -> { items : Array a, viewRow : Int -> a -> Html msg, viewHeader : a -> Maybe (Html msg) }
    -> State
    -> Html msg
rowHeight : Int -> Attribute msg
overscan : Int -> Attribute msg

-- Scrolling
type alias Geometry = { rowHeight : Int, height : Int, count : Int, inset : Int }
ensureVisible : Geometry -> Int -> State -> ( State, Cmd Msg )
center : Geometry -> Int -> State -> ( State, Cmd Msg )
scrollTo : Float -> State -> ( State, Cmd Msg )
reset : State -> State
viewportHeight : { a | rowHeight : Int, height : Int, count : Int } -> Int
isDrawn : Geometry -> Int -> State -> Bool
```

## Documentation

A list of thousands of rows that draws only the rows in view, and is a
list box for the keyboard.

Use when: a long, plain list of equal rows that people scan and pick from, such as a search result or 50 000 products.
Do not use when: the records have columns to sort, filter and compare (`Klar.Table` with `virtual`) or the list is short (`Klar.ListItem`).
Quick path: `init`, `update`, `list`, `active`

Use it for a long, plain list of equal rows that people scan and pick from: a
search result, an inbox, 50 000 products. For records with columns that people
sort, filter and compare, use [Klar.Table](Klar.Table.md) with `virtual`; for a short
list of things to open, [Klar.ListItem](Klar.ListItem.md).

    import Array exposing (Array)
    import Klar.ListItem as ListItem
    import Klar.VirtualList as VirtualList

    -- model: { orders : Array Order, picked : Maybe Int, list : VirtualList.State }
    init =
        { orders = Array.fromList allOrders
        , picked = Nothing
        , list = VirtualList.init "order-list"
        }

    -- update
    ListMsg inner ->
        let
            ( list, cmd ) =
                VirtualList.update inner model.list
        in
        ( { model | list = list }, Cmd.map ListMsg cmd )

    OrderPicked index ->
        ( { model | picked = Just index }, Cmd.none )

    -- view
    VirtualList.list ListMsg
        [ VirtualList.onSelect OrderPicked, VirtualList.selected model.picked ]
        { label = "Orders", items = model.orders, viewRow = viewOrder }
        model.list

    viewOrder : Order -> Html msg
    viewOrder order =
        ListItem.content [ ListItem.secondary order.customer, ListItem.meta order.date ] order.number

The list owns its rows: it makes the `ul` and the `li` of every row, gives every row
the same height (from the `density`, so you never write a height or a style) and
tells assistive technology which row of how many it is, although only the rows in
view are on the page. `viewRow` only says what is inside a row, and the content
should not be a button or a link, because the row itself is what is clicked.

**Keyboard.** With `onSelect` the list is a list box and one tab stop, not one for
every row: Tab reaches it, ArrowDown and ArrowUp move the active row, Home and End
go to the first and the last, PageDown and PageUp move by a screenful, and Enter
or Space picks the active row. The active row is marked and scrolled into view.
Without `onSelect` the list is just a scrolling list, and the keys scroll it.

The state holds the scroll offset and the active row, and reports every scroll
through the message you give to `list`. Read the active row with `active`, and
bring a row into view with `reveal` (for example the `selected` row, 40 000 rows
down, when the list is shown).

Components that draw their own rows (the options of [Klar.Select](Klar.Select.md)) use
the low-level `view` instead, where each row is a `div` of your own that must be
exactly `rowHeight` pixels high and the component handles the keys itself.

## State

### `State`

```elm
type State  -- opaque: no constructors are exposed
```

What one virtual list keeps track of: the DOM id of its scrolling element, its
scroll offset and the active row. Make it with `init`, keep it in your model and
pass it to `list` and `update`.

### `Msg`

```elm
type Msg  -- opaque: no constructors are exposed
```

The messages a virtual list sends; it reports every scroll. Wrap it in a
constructor of your own message type (`ListMsg VirtualList.Msg`), give that
constructor to `view`, and pass the messages you get back to `update`.

### `init`

```elm
init : String -> State
```

A list scrolled to the top. The `String` is the DOM id of the scrolling
element and must be unique on the page: the scrolling commands find the element
by it.

    VirtualList.init "order-list"

### `update`

```elm
update : Msg -> State -> ( State, Cmd Msg )
```

Handles a message of the list by storing the scroll offset. Like every
`update` of the package it returns a command, which you map into your own
message type with `Cmd.map`.

    ListMsg inner ->
        let
            ( list, cmd ) =
                VirtualList.update inner model.list
        in
        ( { model | list = list }, Cmd.map ListMsg cmd )

### `list`

```elm
list :
    (Msg -> msg)
    -> List (Attribute msg)
    -> { label : String, items : Array a, viewRow : a -> Html msg }
    -> State
    -> Html msg
```

The list: `ul` and `li` of its own, a height from the `density`, the window of
rows in view, and the keys of a list box when there is an `onSelect`. `toMsg` wraps
the list's messages into your own message type, `label` names the list for screen
readers, `items` are all the rows (an `Array`, so that the slice in view is cheap to
take) and `viewRow` makes what is inside one row.

    VirtualList.list ListMsg
        [ VirtualList.onSelect OrderPicked ]
        { label = "Orders", items = model.orders, viewRow = viewOrder }
        model.list

## Reading the state

### `id`

```elm
id : State -> String
```

The DOM id of the scrolling element, as given to `init`.

### `scrollTop`

```elm
scrollTop : State -> Float
```

The current scroll offset in pixels, as last reported by the browser or set
by `scrollTo`, `ensureVisible` and `center`.

### `active`

```elm
active : State -> Maybe Int
```

The row (counting from 0) that the keyboard is on, or that the user last
pressed with the mouse. `Nothing` until the user has moved or pressed. A list with
`onSelect` shows it as the active row; it starts on the `selected` row, or the first.

### `reveal`

```elm
reveal : List (Attribute msg) -> { row : Int, count : Int } -> State -> ( State, Cmd Msg )
```

Scrolls a `list` so that row `row` (counting from 0) is in view, to the middle
of the list when it was out of view, and makes it the active row, so the keys go on
from there. Give it the attributes and the number of rows you give `list`: the
height of the rows comes from the same `density`, so there is no height to repeat.
Use it when a list opens on its `selected` row, or to show a row the application
found. Like `scrollTo`, it needs the list on the page by the time the command runs.

    ShowOrder index ->
        let
            ( list, cmd ) =
                VirtualList.reveal listAttributes { row = index, count = Array.length model.orders } model.list
        in
        ( { model | list = list }, Cmd.map ListMsg cmd )

## Attributes

### `Attribute`

```elm
type Attribute msg  -- opaque: no constructors are exposed
```

A setting of a virtual list. Make them with the functions below and pass a
list to `view` or `viewGrouped`; later attributes win over earlier ones, except
that `htmlAttrs` adds up.

### `density`

```elm
density : Theme.Density -> Attribute msg
```

The height of the rows of a `list`: `Compact` 32 pixels, `Normal` 44 (the
default, the height of a `ListItem.content` row with a second line) or
`Comfortable` 56. A row is exactly this high, and what does not fit is cut.

### `onSelect`

```elm
onSelect : (Int -> msg) -> Attribute msg
```

Makes a `list` a list box that the keyboard moves through, and says what to
tell when the user picks a row (clicks it, or presses Enter or Space on the active
row). The message gets the number of the row, counting from 0, in the `Array` you
gave to `list`.

### `selected`

```elm
selected : Maybe Int -> Attribute msg
```

The row that is picked now (it is marked, and is where the active row starts), or
`Nothing`. The list does not keep it: you set it from the message of `onSelect`.

### `height`

```elm
height : Int -> Attribute msg
```

The maximum height of the list in pixels. The default is 320. A list with
fewer rows is only as high as its rows.

### `htmlAttrs`

```elm
htmlAttrs : List (Html.Attribute msg) -> Attribute msg
```

Extra attributes for the scrolling element: a `role`, `aria-*` attributes,
key handlers, an extra class. They are added to the ones the list sets itself,
and using `htmlAttrs` more than once adds all of them.

    VirtualList.htmlAttrs
        [ Attr.attribute "role" "listbox"
        , Attr.attribute "aria-label" "Orders"
        ]

## Rows of your own

`view` and `viewGrouped` draw a list whose rows you make yourself. Every row must
be exactly `rowHeight` pixels high and the list has no keyboard handling of its own:
the component that owns it handles the keys and calls `ensureVisible` to keep the
active row on screen, which works out the new offset from the row heights, without
measuring the page, so that the right rows are drawn in the same frame. A list with a
`role` should tell assistive technology how many rows there are: give every row
`aria-posinset` and `aria-setsize`, as the select components do, and point
`aria-activedescendant` only at a row that `isDrawn`. Add the `role` and the other
attributes with `htmlAttrs`.

### `view`

```elm
view :
    (Msg -> msg)
    -> List (Attribute msg)
    -> { items : Array a, viewRow : Int -> a -> Html msg }
    -> State
    -> Html msg
```

A list whose rows you make yourself, for a component that draws its own
options (see "Rows of your own" above; for a list of records, use `list`).
`toMsg` wraps the scroll messages into your own message type, `items` are all the
rows (an `Array`, so that the visible slice is cheap to take) and `viewRow` turns the
absolute index of a row and its item into HTML that is exactly `rowHeight` pixels high.

    VirtualList.view ListMsg
        [ VirtualList.rowHeight 32, VirtualList.height 320 ]
        { items = model.orders, viewRow = viewOrder }
        model.list

### `viewGrouped`

```elm
viewGrouped :
    (Msg -> msg)
    -> List (Attribute msg)
    -> { items : Array a, viewRow : Int -> a -> Html msg, viewHeader : a -> Maybe (Html msg) }
    -> State
    -> Html msg
```

Like `view`, for lists with section headings. `viewHeader` returns the
pinned version of a heading row (and `Nothing` for ordinary rows); it is shown
on top of the list for the section the first visible row belongs to. Give the
pinned copy no `id`: it is a visual duplicate, hidden from screen readers.

    VirtualList.viewGrouped ListMsg
        [ VirtualList.rowHeight 32 ]
        { items = model.rows
        , viewRow = viewRow
        , viewHeader = pinnedHeading
        }
        model.list

    pinnedHeading : Row -> Maybe (Html msg)
    pinnedHeading row =
        case row of
            Heading name ->
                Just (Html.div [] [ Html.text name ])

            Item _ ->
                Nothing

### `rowHeight`

```elm
rowHeight : Int -> Attribute msg
```

The height of every row in pixels (at least 1), for `view` and `viewGrouped`.
The default is 32, the `--klar-option-h` token. The rows that `viewRow` returns must
be exactly this high. `list` takes the height of its rows from the `density`.

### `overscan`

```elm
overscan : Int -> Attribute msg
```

How many rows are rendered above and below the visible ones. The default is
6, so that fast scrolling does not show empty space.

## Scrolling

### `Geometry`

```elm
type alias Geometry = { rowHeight : Int, height : Int, count : Int, inset : Int }
```

What the scroll helpers need to know about a list, the same numbers you give
to `view`: `rowHeight` is the height of a row in pixels, `height` the maximum
height of the list, `count` the number of rows, and `inset` the number of pixels
at the top that are covered by a pinned heading (see `viewGrouped`), else 0.

### `ensureVisible`

```elm
ensureVisible : Geometry -> Int -> State -> ( State, Cmd Msg )
```

Scrolls as little as possible so that row `index` (counting from 0) is fully
visible, for example the row a keyboard user has just moved to. The new offset is
known right away, so the rows around it are rendered in the same frame.

    VirtualList.ensureVisible
        { rowHeight = 32, height = 320, count = 500, inset = 0 }
        42
        model.list

### `center`

```elm
center : Geometry -> Int -> State -> ( State, Cmd Msg )
```

Scrolls so that row `index` (counting from 0) is in the middle of the list,
as far as the ends of the list allow. The select components use it when the list
opens on the chosen option. Like `scrollTo`, it needs the element on the page by
the time the command runs.

### `scrollTo`

```elm
scrollTo : Float -> State -> ( State, Cmd Msg )
```

Scrolls to an offset in pixels (a negative offset counts as 0). The offset is
stored at once, and the command scrolls the element, which has to be on the page
by then.

### `reset`

```elm
reset : State -> State
```

Goes back to the top without touching the page. Use it when the list
element is about to be created again, such as a popup that opens: the new
element starts at the top, and the state has to agree.

### `viewportHeight`

```elm
viewportHeight : { a | rowHeight : Int, height : Int, count : Int } -> Int
```

The height in pixels that the list takes: the height of all rows, but at most
`height`. It works on a `Geometry` or any record with these three fields.

    VirtualList.viewportHeight { rowHeight = 32, height = 320, count = 3 } --> 96

### `isDrawn`

```elm
isDrawn : Geometry -> Int -> State -> Bool
```

Whether row `index` (counting from 0) is on the page now, for any `overscan`:
`view` and `viewGrouped` draw the rows in view and a few around them, so after the
user scrolled away with the wheel a row the keyboard was on may be gone. Point
`aria-activedescendant` at a row only while it is drawn, since an id that is not
on the page names nothing. Give it the same numbers as `view`.

    VirtualList.isDrawn { rowHeight = 32, height = 320, count = 500, inset = 0 } 42 model.list
