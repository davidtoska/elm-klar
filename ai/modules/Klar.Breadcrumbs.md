# Klar.Breadcrumbs

The path to the current page: links separated by chevrons, where the last item is the current page.

Import: `import Klar.Breadcrumbs as Breadcrumbs` | Group: Navigation

Types: `Msg`, `Crumb`, `State`, `Attribute`

## Signatures

```elm
-- Views
view : (Msg -> msg) -> List (Attribute msg) -> State -> Html msg
viewStatic : List (Attribute msg) -> Html msg

-- Crumbs
type Crumb msg  -- opaque: no constructors are exposed
link : { label : String, href : String } -> Crumb msg
button : String -> msg -> Crumb msg
text : String -> Crumb msg
withIcon : Icon.Icon -> Crumb msg -> Crumb msg

-- Attributes
type Attribute msg  -- opaque: no constructors are exposed
items : List (Crumb msg) -> Attribute msg
maxItems : Int -> Attribute msg
ariaLabel : String -> Attribute msg
locale : Locale.Locale -> Attribute msg

-- State
type State  -- opaque: no constructors are exposed
type Msg  -- opaque: no constructors are exposed
init : String -> State
isOpen : State -> Bool
close : State -> ( State, Cmd Msg )
update : Msg -> State -> ( State, Cmd Msg )
```

## Documentation

The path to the current page: links separated by chevrons, where the last item
is the current page.

Use when: the user must see where the current page sits in the application, as a trail of links.
Do not use when: you need the main navigation (use `Klar.SideNav`) or sections within one page (use `Klar.Tabs`).
Quick path: `viewStatic` for a trail of at most `maxItems` levels; `init`, `update`, `view` for a trail that can grow deeper

Which one: a trail with a fixed depth of two or three levels (Orders, then an order)
is `viewStatic`, with no state. A trail built from a path that can be deep (folders,
regions, a category tree) is `view`, which folds its middle into a "more" button and
keeps whether that list is open in a `State`:

    import Klar.Breadcrumbs as Breadcrumbs

    -- model: crumbs : Breadcrumbs.State
    -- init:  Breadcrumbs.init "page-crumbs"

    -- update
    CrumbsMsg m ->
        let
            ( crumbs, cmd ) =
                Breadcrumbs.update m model.crumbs
        in
        ( { model | crumbs = crumbs }, Cmd.map CrumbsMsg cmd )

    -- view
    Breadcrumbs.view CrumbsMsg
        [ Breadcrumbs.items
            [ Breadcrumbs.link { label = "Home", href = "#/" }
            , Breadcrumbs.link { label = "Customers", href = "#/customers" }
            , Breadcrumbs.text "Ada Lovelace"
            ]
        ]
        model.crumbs

When there are at least two crumbs more than `maxItems`, the first crumb and the last
`maxItems - 1` crumbs stay visible and the ones in between fold into a "more" button
that opens a small list of them (Escape closes it and gives focus back to the button,
the arrow keys move between the levels, Tab moves on). A trail only one crumb longer
is shown whole: a button for a single crumb would save no room. The list closes by
itself when the trail changes under it (Back, a shortcut).

The last crumb is always the current page: it is shown as plain text and marked
with `aria-current="page"`, even if it was made with `link`. Every other crumb
that has a link is a real link, so routing, middle click and "open in new tab"
work as usual; a `button` crumb sends a message instead, for a trail that is not made
of addresses (the levels of a folder browser or a drill-down inside one page). The
built-in text (the name of the navigation landmark and of the "more" button) follows
`locale`, English by default.

## Views

### `view`

```elm
view : (Msg -> msg) -> List (Attribute msg) -> State -> Html msg
```

A trail that folds its middle into a "more" button when it has at least two crumbs
more than `maxItems`. The button opens a list of the hidden levels. The first argument
wraps the trail's `Msg` in your own message type.

### `viewStatic`

```elm
viewStatic : List (Attribute msg) -> Html msg
```

A trail that always shows every level, however many. No state and no messages of
its own; a trail that does not fit on one line wraps onto more lines.

    Breadcrumbs.viewStatic
        [ Breadcrumbs.items
            [ Breadcrumbs.link { label = "Orders", href = "#/orders" }
            , Breadcrumbs.text "Order 10482"
            ]
        ]

## Crumbs

### `Crumb`

```elm
type Crumb msg  -- opaque: no constructors are exposed
```

One level of the trail. Make it with `link`, `button` or `text` and refine it with
`withIcon`. The `msg` is your message type, sent by a `button` crumb.

### `link`

```elm
link : { label : String, href : String } -> Crumb msg
```

A level with a link. Use `#/path` for navigation inside a single page application.
The last crumb of a trail is always shown as the current page, as plain text, whether
or not it has a link.

    Breadcrumbs.link { label = "Customers", href = "#/customers" }

### `button`

```elm
button : String -> msg -> Crumb msg
```

A level that sends a message instead of following an address: the label, then the
message. For trails that are not routes, such as the folders of a file browser or the
levels of a drill-down in a chart; it looks like a link. As the last crumb it is the
current level and plain text, like any last crumb.

    Breadcrumbs.button "2025" (DrillUpTo Year)

### `text`

```elm
text : String -> Crumb msg
```

A level without a link, just the label. The current page is always shown as
plain text, so the last crumb normally uses this. A level in the middle of the
trail that has no page of its own can use it too.

    Breadcrumbs.text "Ada Lovelace"

### `withIcon`

```elm
withIcon : Icon.Icon -> Crumb msg -> Crumb msg
```

An icon before the label, for example `Icon.home` on the first level. The icon
is decorative: the label still names the crumb.

    Breadcrumbs.link { label = "Home", href = "#/" }
        |> Breadcrumbs.withIcon Icon.home

## Attributes

### `Attribute`

```elm
type Attribute msg  -- opaque: no constructors are exposed
```

A setting of the trail. Make them with the functions below and pass a list to
`view` or `viewStatic`; later attributes win over earlier ones. The `msg` is your
message type, of the `button` crumbs.

### `items`

```elm
items : List (Crumb msg) -> Attribute msg
```

The trail, from the top level to the current page, which comes last.

### `maxItems`

```elm
maxItems : Int -> Attribute msg
```

The most crumbs shown at once by `view`. Default 4; a smaller number counts as 2.
When the trail has at least two crumbs more, the first crumb and the last `n - 1`
crumbs stay visible and the ones between fold into the "more" button; a trail only
one crumb longer is shown whole. `viewStatic` shows every crumb.

### `ariaLabel`

```elm
ariaLabel : String -> Attribute msg
```

The accessible name of the `nav` landmark. Default "Breadcrumb" (in the
language of `locale`).

### `locale`

```elm
locale : Locale.Locale -> Attribute msg
```

The language of the built-in text: the name of the `nav` landmark and of the
"more" button ("Show 3 hidden levels"). Default `Locale.en`.

## State

### `State`

```elm
type State  -- opaque: no constructors are exposed
```

The state of a trail: whether the list of hidden levels is open. Make one
with `init`, keep it in your model, and give it to `view`. A trail shown with
`viewStatic` needs none.

### `Msg`

```elm
type Msg  -- opaque: no constructors are exposed
```

The messages of a trail: the "more" button was used, a key was pressed in the
list of hidden levels. Wrap it in a constructor of your own message type, pass
that constructor to `view`, and hand the messages you get back to `update`.

### `init`

```elm
init : String -> State
```

A trail with its list of hidden levels closed. The id must be unique on the
page: it is the prefix of the DOM ids of the "more" button and of the list that
it opens.

    Breadcrumbs.init "page-crumbs"

### `isOpen`

```elm
isOpen : State -> Bool
```

Whether the list of hidden levels has been opened and not closed since. The list
is only drawn while the trail still folds the same levels.

### `close`

```elm
close : State -> ( State, Cmd Msg )
```

Closes the list of hidden levels and gives keyboard focus back to the "more"
button (only when the list was open). The list also closes by itself when the trail
changes, so this is for closing it from your own code, such as a shortcut.

### `update`

```elm
update : Msg -> State -> ( State, Cmd Msg )
```

Opens and closes the list of hidden levels and moves keyboard focus into and
out of it. The `Cmd` does the focus move, so map it with your message
constructor.
