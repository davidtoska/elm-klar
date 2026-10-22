# Klar.Pagination

Page navigation for long lists and tables: the range shown ("1–25 of 3,000"), rows per page, first / previous / page numbers with ellipsis / next / last, and "Go to page".

Import: `import Klar.Pagination as Pagination` | Group: Tables and lists

Types: `Item`, `Attribute`

## Signatures

```elm
-- View
view : List (Attribute msg) -> { page : Int, pageSize : Int, total : Int } -> Html msg

-- Attributes
type Attribute msg  -- opaque: no constructors are exposed
onPage : (Int -> msg) -> Attribute msg
onPageSize : (Int -> msg) -> Attribute msg
pageSizes : List Int -> Attribute msg
compact : Attribute msg
jumpToPage : Attribute msg
siblings : Int -> Attribute msg
summary : List (Html msg) -> Attribute msg
disabled : Bool -> Attribute msg
id : String -> Attribute msg
label : String -> Attribute msg
locale : Locale.Locale -> Attribute msg

-- Page math
type Item = Page Int | Ellipsis
pageCount : Int -> Int -> Int
range : { page : Int, pageSize : Int, total : Int } -> ( Int, Int )
pageItems : { siblings : Int, page : Int, pageCount : Int } -> List Item
```

## Documentation

Page navigation for long lists and tables: the range shown ("1–25 of
3,000"), rows per page, first / previous / page numbers with ellipsis / next /
last, and "Go to page".

Use when: you page a list that you fetch or show yourself, outside `Klar.Table`.
Do not use when: the list is a `Klar.Table`, which has its own page controls.

    import Klar.Pagination as Pagination

    Pagination.view
        [ Pagination.id "order-pages"
        , Pagination.onPage PageChanged
        , Pagination.onPageSize PageSizeChanged
        , Pagination.jumpToPage
        ]
        { page = model.page, pageSize = model.pageSize, total = 3000 }

    -- compact: "1–25 of 3,000  ‹ ›"
    Pagination.view [ Pagination.compact, Pagination.onPage PageChanged ]
        { page = model.page, pageSize = 25, total = 3000 }

It is **controlled**: the application owns `page` and `pageSize` and changes
them when `onPage` and `onPageSize` fire. The first page is 1. A page outside the
valid range is shown clamped, and `onPage` only ever sends a page between 1 and
the last page.

    PageChanged page ->
        ( { model | page = page }, loadOrders page model.pageSize )

    PageSizeChanged size ->
        ( { model | pageSize = size, page = 1 }, loadOrders 1 size )

[Klar.Table](Klar.Table.md) uses this component in its footer and keeps the page in
its own state.

The page buttons always use the same number of slots (first page, last page, the
current page with `siblings` neighbours on each side, and ellipses), so the
controls do not jump around while paging.

Keyboard and accessibility: every control is a native button, select or input.
In "Go to page", type a number and press Enter. The component is a `nav`
landmark; the current page has `aria-current="page"`, and the buttons that are
not available at the first or last page stay in the tab order, so the keyboard
focus is not lost when the user reaches that page. The built-in texts ("Rows per
page", "Next page" ...) follow `locale` and are English by default (see
[Klar.Locale](Klar.Locale.md)).

## View

### `view`

```elm
view : List (Attribute msg) -> { page : Int, pageSize : Int, total : Int } -> Html msg
```

The pagination. It takes the attributes and where the list stands: `page`
(the first page is 1), `pageSize` (items per page) and `total` (all items, not
only the loaded ones). A page outside the valid range is shown as the nearest
valid page.

    Pagination.view
        [ Pagination.id "order-pages", Pagination.onPage PageChanged ]
        { page = model.page, pageSize = 25, total = model.orderCount }

## Attributes

### `Attribute`

```elm
type Attribute msg  -- opaque: no constructors are exposed
```

A setting of a pagination. Make them with the functions below and pass a list
to `view`; later attributes win over earlier ones.

### `onPage`

```elm
onPage : (Int -> msg) -> Attribute msg
```

The message to send when the user chooses a page, with the page number. It is
1-based and always valid: between 1 and the last page. It is sent by the page
buttons, by first / previous / next / last, and by "Go to page". Without
`onPage` the buttons do nothing.

    Pagination.onPage PageChanged

### `onPageSize`

```elm
onPageSize : (Int -> msg) -> Attribute msg
```

Shows the "Rows per page" choice (full variant only) and sends the new size
when the user picks one. The sizes on offer come from `pageSizes`. The current
page may no longer exist with a new size, so change `page` too, usually back to 1.

    Pagination.onPageSize PageSizeChanged

### `pageSizes`

```elm
pageSizes : List Int -> Attribute msg
```

The sizes offered in the "Rows per page" choice. The default is
`[ 10, 25, 50, 100 ]`. The current page size is always offered, even if it is
not in the list. Sizes below 1 are dropped.

### `compact`

```elm
compact : Attribute msg
```

Only the range and previous / next: "1–25 of 3,000 ‹ ›". For narrow places
like cards and side panels. The compact variant has no page numbers, no
"Rows per page" choice and no "Go to page".

### `jumpToPage`

```elm
jumpToPage : Attribute msg
```

Adds a "Go to page" number input after the page buttons. It is shown in the
full variant when there is more than one page and an `onPage` message. The user
types a page and presses Enter (or leaves the field); a number outside the range
goes to the nearest page.

### `siblings`

```elm
siblings : Int -> Attribute msg
```

How many page numbers to show on each side of the current page. The default
is 1.

### `summary`

```elm
summary : List (Html msg) -> Attribute msg
```

Replaces the range text ("1–25 of 3,000") with your own content, for
example a "Loading ..." message while a page is on its way, or nothing (an empty
list) when the range would describe rows that are not on screen. The controls
stay.

    Pagination.summary [ Html.text "Loading ..." ]

### `disabled`

```elm
disabled : Bool -> Attribute msg
```

While `True` every control is disabled, for example while a page is loading.
The default is `False`.

### `id`

```elm
id : String -> Attribute msg
```

The DOM id of the navigation. The default is `"klar-pagination"`. The
"Rows per page" select and the "Go to page" input get ids derived from it
(`order-pages-size` and `order-pages-jump`), so give every pagination on a page
its own id.

    Pagination.id "order-pages"

### `label`

```elm
label : String -> Attribute msg
```

The accessible name of the navigation landmark. The default is "Pagination"
(in the language of `locale`). Name it more closely when a page has several
paginations, such as "Orders pages".

### `locale`

```elm
locale : Locale.Locale -> Attribute msg
```

The language of the built-in text: the range, "Rows per page", the button
labels and "Go to page", with numbers grouped the way the language does it. The
default is `Locale.default`, which is English. See [Klar.Locale](Klar.Locale.md).

    Pagination.locale Locale.nb

## Page math

The same arithmetic the view uses, for fetching and showing pages yourself.

### `Item`

```elm
type Item = Page Int | Ellipsis
```

A slot in the row of page buttons: `Page n` is a numbered button, and
`Ellipsis` is a gap ("…") that stands for the pages in between.

### `pageCount`

```elm
pageCount : Int -> Int -> Int
```

The number of pages for a page size and a total number of items, in that
order. It is at least 1, also when there are no items.

    Pagination.pageCount 25 3000 --> 120

    Pagination.pageCount 25 0 --> 1

### `range`

```elm
range : { page : Int, pageSize : Int, total : Int } -> ( Int, Int )
```

The 1-based numbers of the first and last item on a page, or `( 0, 0 )` when
there are no items. The page is clamped to the valid range. Use it to show the
range yourself, or to work out which items belong on a page.

    Pagination.range { page = 2, pageSize = 25, total = 30 } --> ( 26, 30 )

### `pageItems`

```elm
pageItems : { siblings : Int, page : Int, pageCount : Int } -> List Item
```

The slots of the row of page buttons for the current `page`, with `siblings`
page numbers on each side of it. The first and last page are always there. The
number of slots stays the same once there are enough pages (7 with one sibling),
so the row does not change width while paging.

    Pagination.pageItems { siblings = 1, page = 6, pageCount = 120 }
    --> [ Page 1, Ellipsis, Page 5, Page 6, Page 7, Ellipsis, Page 120 ]

    Pagination.pageItems { siblings = 1, page = 1, pageCount = 120 }
    --> [ Page 1, Page 2, Page 3, Page 4, Page 5, Ellipsis, Page 120 ]
