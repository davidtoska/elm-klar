# Klar.PageHeader

The top of a page: the title, a line of explanation, where the page sits in the application, the state of the thing you are looking at, and what you can do with it.

Import: `import Klar.PageHeader as PageHeader` | Group: Navigation

Types: `Attribute`

## Signatures

```elm
-- View
type Attribute msg  -- opaque: no constructors are exposed
view : List (Attribute msg) -> Html msg

-- Title
title : String -> Attribute msg
headingLevel : Int -> Attribute msg
subtitle : String -> Attribute msg
badges : List (Html msg) -> Attribute msg
meta : List (Html msg) -> Attribute msg
metaItem : String -> String -> Html msg

-- Navigation and actions
breadcrumbs : Html msg -> Attribute msg
backLink : { href : String, label : String } -> Attribute msg
actions : List (Html msg) -> Attribute msg
tabs : Html msg -> Attribute msg

-- Look
band : Attribute msg
sticky : Attribute msg
```

## Documentation

The top of a page: the title, a line of explanation, where the page sits in
the application, the state of the thing you are looking at, and what you can do
with it.

    import Klar.Badge as Badge
    import Klar.Breadcrumbs as Breadcrumbs
    import Klar.Button as Button
    import Klar.Icon as Icon
    import Klar.Menu as Menu
    import Klar.PageHeader as PageHeader
    import Klar.Tabs as Tabs
    import Klar.Theme exposing (Tone(..))

    PageHeader.view
        [ PageHeader.breadcrumbs
            (Breadcrumbs.static
                [ Breadcrumbs.items
                    [ Breadcrumbs.link "Orders" "#/orders"
                    , Breadcrumbs.text "Order 10482"
                    ]
                ]
            )
        , PageHeader.title "Order 10482"
        , PageHeader.subtitle "Placed by Ada Lovelace on 12 March 2025"
        , PageHeader.badges [ Badge.view [ Badge.tone Success ] "Shipped" ]
        , PageHeader.meta
            [ PageHeader.metaItem "Customer number" "100482"
            , PageHeader.metaItem "Last changed" "2 hours ago"
            ]
        , PageHeader.actions
            [ Button.view [ Button.primary, Button.icon Icon.edit ] "Edit"
            , Menu.view MenuMsg
                [ Menu.kebab "More actions"
                , Menu.alignEnd
                , Menu.items [ Menu.item "Duplicate order" Duplicate ]
                ]
                model.menu
            ]
        , PageHeader.tabs
            (Tabs.view TabsMsg
                [ Tabs.withoutPanels
                , Tabs.tabs [ Tabs.tab "details" "Details", Tabs.tab "items" "Items" ]
                ]
                model.tabs
            )
        ]

Everything but the title is optional, and a part you leave out takes no space.
The title is the `h1` of the page, so use one header per page (or choose another
level with `headingLevel`); without a title (or with a blank one) the header
renders no heading at all. The header keeps no
state and has no text of its own: the breadcrumbs, tabs and menus you pass in are
built by you and keep their state in your model.

The header is an ordinary block inside the page. `band` turns it into a
full-width white band with a line underneath, which cancels the padding of the
content area of [Klar.AppShell](Klar.AppShell.md), and `sticky` keeps that band at
the top of the scrolling area while the page scrolls. The actions move below the
title when there is no room beside it.

## View

### `Attribute`

```elm
type Attribute msg  -- opaque: no constructors are exposed
```

A part or a setting of the header. Make them with the functions below and
pass a list to `view`; later attributes win over earlier ones, and the parts can
come in any order.

### `view`

```elm
view : List (Attribute msg) -> Html msg
```

The header block. Everything but the title is optional and left out when
empty. The order of the attributes does not matter: the parts always appear in
the same places.

## Title

### `title`

```elm
title : String -> Attribute msg
```

The page title, rendered as the `h1` of the page. Without a title, or with a
blank one, the header renders no heading at all, so another element of the page
must be its `h1`.

### `headingLevel`

```elm
headingLevel : Int -> Attribute msg
```

The level of the heading element of the title, from 1 to 6. The default is 1,
because the header is normally the top of the page. Use another level when the
header sits inside a page that already has an `h1`, such as a header in a panel or
a dialog, or a page with several headers (a gallery of examples). A number outside
the range counts as the nearest level. The level changes the element, not the look
of the title.

    PageHeader.view [ PageHeader.title "Order lines", PageHeader.headingLevel 2 ]

### `subtitle`

```elm
subtitle : String -> Attribute msg
```

A line of gray text under the title, for a short explanation of the page.

### `badges`

```elm
badges : List (Html msg) -> Attribute msg
```

Status badges on the same line as the title, after it (they wrap below the
title when there is no room). Pass [Klar.Badge](Klar.Badge.md) views.

### `meta`

```elm
meta : List (Html msg) -> Attribute msg
```

A row of small facts under the subtitle, such as an identifier or the time of
the last change. Make each fact with `metaItem`.

### `metaItem`

```elm
metaItem : String -> String -> Html msg
```

One fact for `meta`: a gray label and its value, in that order.

    PageHeader.metaItem "Customer number" "100482"

## Navigation and actions

### `breadcrumbs`

```elm
breadcrumbs : Html msg -> Attribute msg
```

Where the page sits in the application, above the title. Pass a
[Klar.Breadcrumbs](Klar.Breadcrumbs.md) trail, made with `Breadcrumbs.view` or
`Breadcrumbs.static`. Together with a `backLink` the link comes first, then the
trail, on the same line.

### `backLink`

```elm
backLink : { href : String, label : String } -> Attribute msg
```

A link with a left arrow back to the list the page came from, above the title.
`href` is where it goes (`#/path` for navigation inside a single page
application) and `label` its text.

    PageHeader.backLink { href = "#/orders", label = "All orders" }

### `actions`

```elm
actions : List (Html msg) -> Attribute msg
```

Buttons and menus at the right end of the header, level with the title. Put
the primary action first. They move below the title when there is no room beside
it.

### `tabs`

```elm
tabs : Html msg -> Attribute msg
```

A row of tabs along the bottom edge of the header. Pass the tab strip made by
`Tabs.view` from [Klar.Tabs](Klar.Tabs.md). The panels, if there are any
(`Tabs.panel`), belong in the body of the page below the header; when the tabs
choose a route and have no panels, give the strip `Tabs.withoutPanels`.

## Look

### `band`

```elm
band : Attribute msg
```

A white band across the full width with a line underneath, instead of a plain
block. Inside [Klar.AppShell](Klar.AppShell.md) it cancels the padding of the content
area so that the band touches the edges, so use it for the first element of a
page. Anywhere else it is a white block with padding and a line under it.

### `sticky`

```elm
sticky : Attribute msg
```

Keeps the header at the top of the scrolling area while the page scrolls.
Implies `band`.
