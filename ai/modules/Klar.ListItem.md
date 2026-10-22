# Klar.ListItem

A dense list row, and the list that holds the rows.

Import: `import Klar.ListItem as ListItem` | Group: Tables and lists

Types: `Attribute`, `ListAttribute`

## Signatures

```elm
-- Rows
type Attribute msg  -- opaque: no constructors are exposed
view : List (Attribute msg) -> String -> Html msg
content : List (Attribute msg) -> String -> Html msg
heading : String -> Html msg

-- Row content
secondary : String -> Attribute msg
meta : String -> Attribute msg
icon : Icon.Icon -> Attribute msg
avatar : String -> Attribute msg
leading : Html msg -> Attribute msg
trailing : List (Html msg) -> Attribute msg
accent : Theme.Tone -> Attribute msg

-- Row behavior
onClick : msg -> Attribute msg
href : String -> Attribute msg
selected : Bool -> Attribute msg
disabled : Bool -> Attribute msg
id : String -> Attribute msg
label : String -> Attribute msg

-- Lists
type ListAttribute msg  -- opaque: no constructors are exposed
list : List (ListAttribute msg) -> List (Html msg) -> Html msg
listLabel : String -> ListAttribute msg
undivided : ListAttribute msg
compact : ListAttribute msg
bordered : ListAttribute msg
maxHeight : Int -> ListAttribute msg

-- Data from a backend
remote : List (ListAttribute msg) -> (a -> Html msg) -> Remote.Remote (List a) -> Html msg
skeleton : Int -> Html msg
skeletonRows : Int -> ListAttribute msg
onRetry : msg -> ListAttribute msg
emptyTitle : String -> ListAttribute msg
emptyDescription : String -> ListAttribute msg
emptyIcon : Icon.Icon -> ListAttribute msg
locale : Locale.Locale -> ListAttribute msg
zone : Time.Zone -> ListAttribute msg
```

## Documentation

A dense list row, and the list that holds the rows.

Use when: the application shows records such as orders, tickets and files, a menu of things to open, or a master list next to a detail pane.
Do not use when: people must search, sort and act on many rows of one kind (as `Klar.Table`).

    import Klar.ListItem as ListItem

    ListItem.list [ ListItem.listLabel "Tickets" ]
        [ ListItem.view
            [ ListItem.avatar "Ada Lovelace"
            , ListItem.secondary "Order 1042 arrived damaged"
            , ListItem.meta "Today 14:05"
            , ListItem.selected (model.selected == Just 1042)
            , ListItem.onClick (TicketSelected 1042)
            , ListItem.trailing [ ticketMenu ]
            ]
            "Ada Lovelace"
        ]

    -- from the backend: skeleton, failure with retry, empty state and rows
    ListItem.remote
        [ ListItem.onRetry ReloadTickets, ListItem.emptyTitle "No tickets" ]
        viewTicket
        model.tickets

A row is made of a leading element (an icon, an avatar or any HTML), a title
with a secondary line, a meta text on the right and trailing actions. A row with
`onClick` or `href` is one button or link, so the whole row is the click target
and `Tab` moves between rows; the trailing actions are separate controls and do
not trigger the row. A row with both is a link that also sends the `onClick`
message when it is followed with a plain click. The selected row is marked with
`aria-current`. The title, the secondary line and the meta text are each cut with
an ellipsis when they do not fit; the whole text is the tooltip.

When the rows have several columns that the user compares or sorts, use
[Klar.Table](Klar.Table.md) instead.

There are two kinds of attributes: `Attribute` configures a row and goes to
`view`, `ListAttribute` configures the list and goes to `list` and `remote`.

## Rows

### `Attribute`

```elm
type Attribute msg  -- opaque: no constructors are exposed
```

A setting of a row. Make them with the functions below and pass a list to
`view`; later attributes win over earlier ones.

### `view`

```elm
view : List (Attribute msg) -> String -> Html msg
```

One row of a list. The text is the title. The row is an `li`, so put it in a
`list`.

    ListItem.view [ ListItem.icon Icon.fileText, ListItem.meta "2 MB" ] "invoice-2041.pdf"

### `content`

```elm
content : List (Attribute msg) -> String -> Html msg
```

What is in a row, for a place that makes the `li` itself, such as a
[Klar.VirtualList](Klar.VirtualList.md): the same look as `view` (a title, a second
line, a meta text, an icon or an avatar, a colored edge) in a `div`. It is not a
button or a link, so `onClick`, `href`, `label` and `trailing` do nothing in it:
the row around it is what is clicked.

    ListItem.content [ ListItem.secondary "Ada Lovelace", ListItem.meta "Today" ] "Order 1042"

### `heading`

```elm
heading : String -> Html msg
```

A small caption between groups of rows, such as "Today" and "Earlier",
shown in capital letters. Put it among the rows in the list.

    ListItem.list []
        [ ListItem.heading "Today"
        , ListItem.view [] "Order 1042"
        , ListItem.heading "Earlier"
        , ListItem.view [] "Order 1017"
        ]

A row of a [Klar.VirtualList](Klar.VirtualList.md) is an `li` of the list's own, so what
goes into it is `content`, the row without the `li` and without anything to click.

## Row content

### `secondary`

```elm
secondary : String -> Attribute msg
```

A second line under the title, in gray: a customer, an address or a short
description.

### `meta`

```elm
meta : String -> Attribute msg
```

Small gray text at the right end of the row: a date, a count or a status.
The digits are tabular, so numbers line up from row to row.

### `icon`

```elm
icon : Icon.Icon -> Attribute msg
```

An icon in a quiet box in front of the title.

### `avatar`

```elm
avatar : String -> Attribute msg
```

An avatar for this name in front of the title. The avatar is decorative
(hidden from screen readers), so the name should also be in the text of the row.

### `leading`

```elm
leading : Html msg -> Attribute msg
```

Anything else in front of the title, such as a thumbnail. It sits inside the
button or link of the row, so it should not contain buttons or links of its own:
use `trailing` for those.

### `trailing`

```elm
trailing : List (Html msg) -> Attribute msg
```

Buttons, menus or badges at the end of the row. They are separate
controls: clicking them does not click the row.

### `accent`

```elm
accent : Theme.Tone -> Attribute msg
```

A colored strip at the left edge: a status the user should see in a long
list. `Neutral` is gray, `Primary` and `Info` are blue, and `Success`, `Warning`
and `Danger` have colors of their own.

## Row behavior

### `onClick`

```elm
onClick : msg -> Attribute msg
```

Makes the row a button that sends this message when it is clicked or
activated with the keyboard. If the row also has an `href`, it is a link, and
the message is sent when the link is followed with a plain click: the main mouse
button or the keyboard, without Ctrl, Cmd, Shift or Alt. A click that opens the
link elsewhere sends nothing, and the link works as usual.

### `href`

```elm
href : String -> Attribute msg
```

Makes the row a link to this URL. Use `#/path` for links inside a single page
application. If the row also has an `onClick` message, it is sent when the link
is followed with a plain click (see `onClick`).

### `selected`

```elm
selected : Bool -> Attribute msg
```

Marks the current row of a master list: tinted, with a bar at the left, and
`aria-current` for screen readers. The default is `False`.

### `disabled`

```elm
disabled : Bool -> Attribute msg
```

Visible but dimmed and not clickable: `onClick` and `href` are ignored, and
the row is marked `aria-disabled`. The default is `False`.

### `id`

```elm
id : String -> Attribute msg
```

The DOM id of the row (its `li` element).

### `label`

```elm
label : String -> Attribute msg
```

An accessible name (`aria-label`) for the button or link of the row. It
replaces the text of the row when a screen reader reads it, so use it only when
the title and the secondary text would not make sense out of context. A row that
is neither a button nor a link (it has no `onClick` or `href`, or it is
`disabled`) is plain content and ignores the label.

## Lists

### `ListAttribute`

```elm
type ListAttribute msg  -- opaque: no constructors are exposed
```

A setting of a list. Make them with the functions below and pass a list to
`list` or `remote`; later attributes win over earlier ones. Settings of a single
row are `Attribute`s, which go to `view`.

### `list`

```elm
list : List (ListAttribute msg) -> List (Html msg) -> Html msg
```

The container of the rows: a `ul` with the role `list`. Its children are rows
made with `view` and, between groups, `heading`s.

    ListItem.list [ ListItem.bordered, ListItem.compact ]
        [ ListItem.view [] "Order 1042"
        , ListItem.view [] "Order 1043"
        ]

### `listLabel`

```elm
listLabel : String -> ListAttribute msg
```

The accessible name of the list (`aria-label`), such as "Tickets".

### `undivided`

```elm
undivided : ListAttribute msg
```

No thin lines between the rows. By default the rows are divided.

### `compact`

```elm
compact : ListAttribute msg
```

Tighter rows: less padding and a smaller box around the `icon`.

### `bordered`

```elm
bordered : ListAttribute msg
```

A border and rounded corners around the list, on a white background.

### `maxHeight`

```elm
maxHeight : Int -> ListAttribute msg
```

Scrolls inside the list when it is taller than this many pixels: for long
lists in a panel. By default the list grows with its rows.

A list that scrolls can take the keyboard focus (`tabindex="0"`), so that
keyboard users can scroll it with the arrow keys. It stays a `list`; give it a
`listLabel` to name it.

## Data from a backend

### `remote`

```elm
remote : List (ListAttribute msg) -> (a -> Html msg) -> Remote.Remote (List a) -> Html msg
```

A list of records from the backend. `toRow` turns one record into a row,
usually with `view`. While the data is `NotAsked` or `Loading` the list shows
placeholder rows (`skeletonRows`), a `Failed` shows an error state with a retry
button (`onRetry`), an empty list shows an empty state (`emptyTitle`) and
otherwise the rows are shown in a `list`. Data that is `Kept` stays: dimmed and
busy while it is refreshed, and under "Old data from 14:05" with a retry
(`onRetry`) when the last refresh failed.

    ListItem.remote [ ListItem.onRetry ReloadOrders ] viewOrder model.orders

### `skeleton`

```elm
skeleton : Int -> Html msg
```

One placeholder row for data that is on its way. The number only varies the
widths of the two text lines, so that a stack of placeholders does not look
uniform: pass the index of the row. `remote` shows placeholder rows by itself.

### `skeletonRows`

```elm
skeletonRows : Int -> ListAttribute msg
```

How many placeholder rows `remote` shows while the data is loading. The
default is 4, and the value is kept between 1 and 20.

### `onRetry`

```elm
onRetry : msg -> ListAttribute msg
```

The message sent by the "Try again" button in the failure state of `remote`.
Without it there is no button. The button is also hidden when trying again would
not help (see [Klar.ErrorState](Klar.ErrorState.md)).

### `emptyTitle`

```elm
emptyTitle : String -> ListAttribute msg
```

The title of the empty state of `remote`. The default is the built-in
"Nothing to show".

### `emptyDescription`

```elm
emptyDescription : String -> ListAttribute msg
```

The text under the title of the empty state of `remote`. There is none by
default.

### `emptyIcon`

```elm
emptyIcon : Icon.Icon -> ListAttribute msg
```

The icon of the empty state of `remote`. The default is `Icon.inbox`.

### `locale`

```elm
locale : Locale.Locale -> ListAttribute msg
```

The language of the built-in text of `remote`: the default title of the empty
state ("Nothing to show" in English) and the "Try again" button. The default is
`Locale.default`, which is English.

### `zone`

```elm
zone : Time.Zone -> ListAttribute msg
```

The time zone of the time in "Old data from 14:05". The default is UTC.
