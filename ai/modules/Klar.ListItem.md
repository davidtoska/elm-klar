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
rowAriaLabel : String -> Attribute msg

-- Lists
type ListAttribute msg  -- opaque: no constructors are exposed
list : List (ListAttribute msg) -> List (Html msg) -> Html msg
keyedList : List (ListAttribute msg) -> List ( String, Html msg ) -> Html msg
ariaLabel : String -> ListAttribute msg
undivided : ListAttribute msg
density : Theme.Density -> ListAttribute msg
bordered : ListAttribute msg
maxHeight : Int -> ListAttribute msg

-- Data from a backend
viewRemote : List (ListAttribute msg) -> Remote.Remote (List ( String, Html msg )) -> Html msg
listId : String -> ListAttribute msg
skeleton : Int -> Html msg
skeletonRows : Int -> ListAttribute msg
onRetry : msg -> ListAttribute msg
emptyState : List (EmptyState.Attribute msg) -> ListAttribute msg
locale : Locale.Locale -> ListAttribute msg
settings : Settings.Settings -> ListAttribute msg
```

## Documentation

A dense list row, and the list that holds the rows.

Use when: the application shows records such as orders, tickets and files, a menu of things to open, or a master list next to a detail pane.
Do not use when: people must search, sort and act on many rows of one kind (use `Klar.Table`), or the list has thousands of rows (use `Klar.VirtualList` with `ListItem.content`).

    import Klar.ListItem as ListItem
    import Klar.Remote as Remote

    -- a list that never changes while the user is on it
    ListItem.list [ ListItem.ariaLabel "Settings" ]
        [ ListItem.view [ ListItem.icon Icon.user, ListItem.href "#/settings/profile" ] "Profile"
        , ListItem.view [ ListItem.icon Icon.lock, ListItem.href "#/settings/security" ] "Security"
        ]

    -- records from the backend: every row keyed by the id of its record
    ListItem.viewRemote
        [ ListItem.ariaLabel "Tickets", ListItem.onRetry ReloadTickets ]
        (Remote.map (List.map (\ticket -> ( ticket.id, viewTicket model ticket ))) model.tickets)

    viewTicket : Model -> Ticket -> Html Msg
    viewTicket model ticket =
        ListItem.view
            [ ListItem.avatar ticket.customer
            , ListItem.secondary ticket.subject
            , ListItem.meta ticket.received
            , ListItem.selected (model.selected == Just ticket.id)
            , ListItem.onClick (TicketSelected ticket.id)
            , ListItem.trailing [ ticketMenu ticket ]
            ]
            ticket.customer

A row is made of a leading element (an icon, an avatar or any HTML), a title
with a secondary line, a meta text on the right and trailing actions. A row with
`onClick` or `href` is one button or link, so the whole row is the click target
and `Tab` moves between rows; the trailing actions are separate controls and do
not trigger the row. A row with both is a link that also sends the `onClick`
message when it is followed with a plain click. The selected row is marked with
`aria-current`. The title, the secondary line and the meta text are each cut with
an ellipsis when they do not fit; the whole text is the tooltip.

Rows that can come, go or move while the user is on them (records from the
backend, a polled queue) go into a `keyedList`, or `viewRemote`, with the id of
the record as the key. Then a new row at the top never moves the keyboard focus
or the next `Enter` onto another record, which is what happens with a `list`,
whose rows are matched by their place. A refresh, a failed refresh and old data
(`Remote.Kept`) keep the rows where they are, so the focus stays on its row.

When the rows have several columns that the user compares or sorts, use
[Klar.Table](Klar.Table.md) instead.

There are two kinds of attributes: `Attribute` configures a row and goes to
`view`, `ListAttribute` configures the list and goes to `list`, `keyedList` and
`viewRemote`.

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
`list`, a `keyedList` or `viewRemote`.

    ListItem.view [ ListItem.icon Icon.fileText, ListItem.meta "2 MB" ] "invoice-2041.pdf"

### `content`

```elm
content : List (Attribute msg) -> String -> Html msg
```

What is in a row, for a place that makes the `li` itself, such as a
[Klar.VirtualList](Klar.VirtualList.md): the same look as `view` (a title, a second
line, a meta text, an icon or an avatar, a colored edge) in a `div`. It is not a
button or a link, so `onClick`, `href`, `rowAriaLabel` and `trailing` do nothing in
it: the row around it is what is clicked.

    ListItem.content [ ListItem.secondary "Ada Lovelace", ListItem.meta "Today" ] "Order 1042"

### `heading`

```elm
heading : String -> Html msg
```

A small caption between groups of rows, such as "Today" and "Earlier",
shown in capital letters. Put it among the rows in the list (in a `keyedList`,
with a key of its own).

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
and `Danger` have colors of their own. A color says nothing to a screen reader,
so the status must also be in the text of the row (the `meta` or the
`secondary` line); in the high-contrast mode of Windows the strip is drawn in
the color of the text.

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

A row with `onClick` or `href` stays the same button or link while it is
disabled, without the click and out of the `Tab` order, so a row that is disabled
while it has the focus (during a save) keeps the focus.

### `id`

```elm
id : String -> Attribute msg
```

The DOM id of the row. A row with `onClick` or `href` puts it on its button
or link, the element that takes the focus, so `Klar.focus` with this id brings
the keyboard back to the row (after a delete or a retry); any other row puts it on
its `li`.

    ListItem.id ("order-" ++ order.id)

### `rowAriaLabel`

```elm
rowAriaLabel : String -> Attribute msg
```

An accessible name (`aria-label`) for the button or link of the row, which
only screen readers hear. It replaces the text of the row when a screen reader
reads it, so use it only when the title and the secondary text would not make
sense out of context. A row that is neither a button nor a link (it has no
`onClick` or `href`) is plain content and ignores it.

## Lists

### `ListAttribute`

```elm
type ListAttribute msg  -- opaque: no constructors are exposed
```

A setting of a list. Make them with the functions below and pass a list to
`list`, `keyedList` or `viewRemote`; later attributes win over earlier ones.
Settings of a single row are `Attribute`s, which go to `view`.

### `list`

```elm
list : List (ListAttribute msg) -> List (Html msg) -> Html msg
```

The container of the rows: a `ul` with the role `list`. Its children are rows
made with `view` and, between groups, `heading`s. The rows are matched by their
place when the list is drawn again, so use it for rows that do not come and go
while the user is on them; otherwise use `keyedList`.

    ListItem.list [ ListItem.bordered, ListItem.density Compact ]
        [ ListItem.view [] "Order 1042"
        , ListItem.view [] "Order 1043"
        ]

### `keyedList`

```elm
keyedList : List (ListAttribute msg) -> List ( String, Html msg ) -> Html msg
```

A `list` whose rows are each given with a key that names their record, such
as the id of an order. When a row is added, removed or moved, the other rows keep
their elements, so the keyboard focus stays on its record and the next `Enter`
does not open another one. Every key must be unique in the list; a `heading` needs
one too.

    ListItem.keyedList [ ListItem.ariaLabel "Orders" ]
        (List.map (\order -> ( order.id, viewOrder order )) model.orders)

### `ariaLabel`

```elm
ariaLabel : String -> ListAttribute msg
```

The accessible name of the list (`aria-label`), which only screen readers
hear, such as "Tickets". There is none by default; give one to every list when
a page has more than one.

### `undivided`

```elm
undivided : ListAttribute msg
```

No thin lines between the rows. By default the rows are divided.

### `density`

```elm
density : Theme.Density -> ListAttribute msg
```

How tightly the rows are packed: `Compact` (32 pixels, less padding and a
smaller box around the `icon`), `Normal` (44 pixels) or `Comfortable` (52
pixels). Without it the list follows the density of the application
(`Klar.Settings`), so give it only to a list that must differ from the rest.

    ListItem.density Compact

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
keyboard users can scroll it with the arrow keys. It stays a `list`; give it an
`ariaLabel` to name it.

## Data from a backend

### `viewRemote`

```elm
viewRemote : List (ListAttribute msg) -> Remote.Remote (List ( String, Html msg )) -> Html msg
```

A `keyedList` of records from the backend, in every state of the `Remote`.
Shape the records into keyed rows with `Remote.map`; the key is the id of the
record.

    ListItem.viewRemote [ ListItem.ariaLabel "Orders", ListItem.onRetry ReloadOrders ]
        (Remote.map (List.map (\order -> ( order.id, viewOrder order ))) model.orders)

While the data is `NotAsked` or `Loading` the list shows placeholder rows
(`skeletonRows`) and says "Loading" to screen readers, a `Failed` shows an error
state with a retry button (`onRetry`), no rows show the empty state
(`emptyState`), and otherwise the rows are shown. Data that is `Kept` stays:
dimmed and busy while it is refreshed, and under "Old data from 14:05" with a
retry (`onRetry`) when the last refresh failed, also when it has no rows.

Every state is drawn inside one element that stays (`listId` gives it an id), and
the rows inside the same elements whether the data is fresh, refreshing or old, so
a refresh that starts or ends never takes the focus from a row. "Loading" is said
by a polite status that is always in the page, empty in the other states.

### `listId`

```elm
listId : String -> ListAttribute msg
```

The DOM id of `viewRemote`, on the element around the list that is the same in
every state (loading, failed, empty, rows, old data) and can take the focus
(`tabindex="-1"`). It gives `Klar.focus` a place to put the focus back when the
element that had it goes away, such as the "Try again" button of the failure state
after a press. The id must be unique on the page. There is none by default.

    ListItem.viewRemote [ ListItem.listId "orders", ListItem.onRetry ReloadOrders ] rows

    -- update
    ReloadOrders ->
        ( { model | orders = Remote.Loading }
        , Cmd.batch [ fetchOrders, Klar.focus "orders" NoOp ]
        )

### `skeleton`

```elm
skeleton : Int -> Html msg
```

One placeholder row for data that is on its way. The number only varies the
widths of the two text lines, so that a stack of placeholders does not look
uniform: pass the index of the row. `viewRemote` shows placeholder rows by
itself.

### `skeletonRows`

```elm
skeletonRows : Int -> ListAttribute msg
```

How many placeholder rows `viewRemote` shows while the data is loading. The
default is 4, and the value is kept between 1 and 20.

### `onRetry`

```elm
onRetry : msg -> ListAttribute msg
```

The message sent by the "Try again" button of `viewRemote`: in the failure
state, and beside "Old data from 14:05" when a refresh failed. Without it there
is no button. The button is also hidden when trying again would not help (see
[Klar.ErrorState](Klar.ErrorState.md)).

### `emptyState`

```elm
emptyState : List (EmptyState.Attribute msg) -> ListAttribute msg
```

Changes the empty state of `viewRemote`, which shows when the list has no
rows: by default a small inbox icon and the title "Nothing to show". These
attributes are applied after the defaults, so yours win. Use it to say why the
list is empty and what to do next.

    ListItem.emptyState
        [ EmptyState.title "No orders"
        , EmptyState.description "No order matches the filter."
        , EmptyState.icon Icon.search
        ]

### `locale`

```elm
locale : Locale.Locale -> ListAttribute msg
```

The language of the built-in text of `viewRemote`: "Loading" for screen
readers, the default title of the empty state ("Nothing to show" in English), the
marker for old data and the "Try again" button. The default is `Locale.default`,
which is English.

### `settings`

```elm
settings : Settings.Settings -> ListAttribute msg
```

The settings of the application (`Klar.Settings`): the time zone of the time in
"Old data from 14:05". Without it the time is written in UTC and ends in "UTC".

    ListItem.settings model.settings
