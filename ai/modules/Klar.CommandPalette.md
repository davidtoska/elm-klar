# Klar.CommandPalette

A command palette: one search box, usually opened with `Ctrl K`, for commands ("New order", "Go to invoices") and for content ("Ada Lovelace").

Import: `import Klar.CommandPalette as CommandPalette` | Group: Overlays

Types: `Msg`, `Item`, `State`, `Section`, `Attribute`

## Signatures

```elm
-- View
view : (Msg -> msg) -> List (Attribute msg) -> State -> Overlay.Overlay msg

-- State
type State  -- opaque: no constructors are exposed
type Msg  -- opaque: no constructors are exposed
init : String -> State
update : Msg -> State -> ( State, Cmd Msg )

-- Opening, closing and the query
open : String -> State -> ( State, Cmd Msg )
close : State -> ( State, Cmd Msg )
isOpen : State -> Bool
openedFrom : State -> String
query : State -> String
setQuery : String -> State -> State

-- Items
type Item msg  -- opaque: no constructors are exposed
item : String -> msg -> Item msg
withDescription : String -> Item msg -> Item msg
withIcon : Icon.Icon -> Item msg -> Item msg
withShortcut : Shortcut.Keys -> Item msg -> Item msg
withKeywords : List String -> Item msg -> Item msg
withId : String -> Item msg -> Item msg

-- Sections
type Section msg  -- opaque: no constructors are exposed
section : String -> List (Item msg) -> Section msg
remote : String -> Remote.Remote (List (Item msg)) -> Section msg
onRetry : msg -> Section msg -> Section msg
emptyText : String -> Section msg -> Section msg

-- Attributes
type Attribute msg  -- opaque: no constructors are exposed
sections : List (Section msg) -> Attribute msg
recent : List (Item msg) -> Attribute msg
placeholder : String -> Attribute msg
label : String -> Attribute msg
noResults : String -> Attribute msg
locale : Locale.Locale -> Attribute msg
settings : Settings.Settings -> Attribute msg
```

## Documentation

A command palette: one search box, usually opened with `Ctrl K`, for commands
("New order", "Go to invoices") and for content ("Ada Lovelace"). Type to narrow
the list, use the arrow keys to move, `Enter` to run and `Escape` to close.

Use when: the application needs one search box for its commands and places, usually opened with Ctrl K.
Do not use when: the user chooses one value in a form (use `Klar.Select`) or searches inside a page (use `Klar.SearchInput`).
Quick path: `init`, `open`, `update`, `view`, `close`, `isOpen`

    import Klar.CommandPalette as CommandPalette
    import Klar.Icon as Icon
    import Klar.Shortcut as Shortcut

    -- model
    { palette : CommandPalette.State } -- CommandPalette.init "palette"

    -- the shortcut (see Klar.Shortcut)
    Shortcut.shortcut (Shortcut.mod (Shortcut.char 'k')) "Navigation" "Open the command palette" OpenPalette
        |> Shortcut.inInputs

    -- update
    OpenPalette ->
        let
            ( palette, cmd ) =
                CommandPalette.open "" model.palette
        in
        ( { model | palette = palette }, Cmd.map PaletteMsg cmd )

    PaletteMsg m ->
        let
            ( palette, cmd ) =
                CommandPalette.update m model.palette
        in
        ( { model | palette = palette }, Cmd.map PaletteMsg cmd )

    -- view
    CommandPalette.view PaletteMsg
        [ CommandPalette.sections
            [ CommandPalette.section "Navigation"
                [ CommandPalette.item "Go to orders" (GoTo Orders)
                    |> CommandPalette.withIcon Icon.table
                    |> CommandPalette.withShortcut (Shortcut.sequence [ Shortcut.char 'g', Shortcut.char 'o' ])
                , CommandPalette.item "New order" NewOrder
                    |> CommandPalette.withIcon Icon.plus
                    |> CommandPalette.withKeywords [ "create", "add" ]
                ]
            , CommandPalette.remote "Customers" model.customerHits
                |> CommandPalette.onRetry SearchCustomers
            ]
        , CommandPalette.recent model.recentItems
        ]
        model.palette

Picking an item sends the item's own message and closes the palette. `Escape`
and a click outside close it without running anything. The palette is a modal
dialog: `view` returns an [`Overlay`](Klar.Overlay.md#overlay), and while it is open
the page behind it is inert.
Pressing the shortcut again while the palette is open starts over with an empty
query; call `close` instead if you want the shortcut to toggle.

**Keyboard and screen readers**: the search box keeps focus. `ArrowDown` and
`ArrowUp` move the highlight (and wrap around), `PageDown` and `PageUp` move six
items, `Enter` runs the highlighted item. The highlighted item is the
`aria-activedescendant` of the search box, which is a combobox, and a polite
live region announces the number of results. Focus cannot leave the palette:
`Tab` only moves between the search box and the "Try again" button of a failed
section. `Escape` gives focus back to the element that had it before the palette
opened (if it has an id), or to the `opener` given to `open`.

**Text**: the built-in text (placeholder, headings, hints, the announcement of
the number of results) follows `locale`, which is English by default. The labels
of items and sections are yours.

## View

### `view`

```elm
view : (Msg -> msg) -> List (Attribute msg) -> State -> Overlay.Overlay msg
```

The palette, centered near the top of the window above everything else.
Renders nothing while closed. Put it in the list of overlays of
[`Overlay.host`](Klar.Overlay.md#host) (or `AppShell.overlays`) so the page behind it
becomes inert. The first argument turns the palette's messages
into yours.

    CommandPalette.view PaletteMsg
        [ CommandPalette.sections [ navigation ] ]
        model.palette

## State

### `State`

```elm
type State  -- opaque: no constructors are exposed
```

The state of the palette: whether it is open, what the user has typed, which
item is highlighted and where focus goes back to. Make one with `init`, keep it
in your model and pass it to `view` and `update`.

### `Msg`

```elm
type Msg  -- opaque: no constructors are exposed
```

A message from the palette. Wrap it in one of your own messages and pass it to
`update`.

### `init`

```elm
init : String -> State
```

A closed palette. The `String` is the DOM id of the palette and must be
unique on the page; the ids of its parts (search box, list ...) start with it.

    CommandPalette.init "palette"

### `update`

```elm
update : Msg -> State -> ( State, Cmd Msg )
```

Handles typing, the highlight, closing and scrolling. The command moves focus
and scrolls the list, so map it with `Cmd.map`. Compare `query` before and after
to start searches.

## Opening, closing and the query

### `open`

```elm
open : String -> State -> ( State, Cmd Msg )
```

Opens the palette with an empty query and focuses the search box. `opener`
is the DOM id of the element that gets focus back when the palette is closed
with `Escape`. With `""` (the usual case when it was opened with a shortcut)
focus returns to the element that had it, if that element has an id.

    CommandPalette.open "search-button" model.palette

### `close`

```elm
close : State -> ( State, Cmd Msg )
```

Closes the palette without running anything and returns focus to its opener
(see `openedFrom`). Picking an item closes the palette by itself.

### `isOpen`

```elm
isOpen : State -> Bool
```

Is the palette open? The page is made inert by the overlay `view` returns;
this is for your own logic (a shortcut that toggles the palette, say).

### `openedFrom`

```elm
openedFrom : State -> String
```

The DOM id of the element the palette was opened from: the `opener` given to
`open`, or the element that had focus. It is `""` if there is none. `Escape`
gives focus back to it. Pass it as the opener of a dialog that an item opens:
the palette is gone by then, and the dialog should return to where the user was.

### `query`

```elm
query : State -> String
```

What the user has typed. Compare it before and after `update` to start
searches in the backend.

### `setQuery`

```elm
setQuery : String -> State -> State
```

Replaces the query and clears the highlight, for example to open the palette
with a prefix. It does not open the palette, and `open` clears the query, so call
it after `open`.

    CommandPalette.open "" model.palette
        |> Tuple.mapFirst (CommandPalette.setQuery "customer ")

## Items

An item is a command or a piece of content: a label, the message to send when it
is picked and, if you like, an icon, a description, the keys of its shortcut and
extra words it is found by. The palette keeps track of the highlighted item by
identity, so a result that arrives above it does not move the highlight. Give
items with identical labels a `withId`.

### `Item`

```elm
type Item msg  -- opaque: no constructors are exposed
```

One entry of the palette: a command or a piece of content, with the message
it sends when picked. Make one with `item` and add details with the `with...`
functions.

### `item`

```elm
item : String -> msg -> Item msg
```

A command or a piece of content. The first argument is the label that is
shown and searched, the second the message that is sent when the item is picked.

    CommandPalette.item "New order" NewOrder

### `withDescription`

```elm
withDescription : String -> Item msg -> Item msg
```

A second, quieter line of text after the label. It is searched too.

    CommandPalette.item "Order A-1001" (GoToOrder "A-1001")
        |> CommandPalette.withDescription "Ada Lovelace, 2026-10-20"

### `withIcon`

```elm
withIcon : Icon.Icon -> Item msg -> Item msg
```

An icon before the label.

### `withShortcut`

```elm
withShortcut : Shortcut.Keys -> Item msg -> Item msg
```

The shortcut of the command, shown as key caps at the right. Write it in the
keys of [Klar.Shortcut](Klar.Shortcut.md): `mod (char 'k')`, `char '?'`. It is only
a hint: the palette does not listen for the keys, a `Shortcut` in your list does.

### `withKeywords`

```elm
withKeywords : List String -> Item msg -> Item msg
```

Extra words the item is found by, without showing them. A match on a
keyword ranks below a match on the label.

    CommandPalette.item "New order" NewOrder
        |> CommandPalette.withKeywords [ "create", "add" ]

### `withId`

```elm
withId : String -> Item msg -> Item msg
```

A stable identity, for items with the same label (two customers called "Ada
Lovelace"). It keeps the highlight on the right item when the results change.

## Sections

A section is a titled group of items. There are two kinds.

`section` takes items that you know in advance, such as the commands of the
application. The palette filters and ranks them with
[Klar.Search](Klar.Search.md) as the user types: case, diacritics and word order do
not matter, and every word has to match somewhere ("ne ord" finds "New order").
Sections without matches disappear. With an empty query everything is listed,
preceded by `recent` if you gave any.

`remote` takes a `Remote (List Item)` ([Klar.Remote](Klar.Remote.md)) that the
application fills, for example with the result of a search in the backend. The
palette shows a skeleton while it is `Loading`, a short failure message when it
is `Failed` (with a "Try again" button if the section has an `onRetry` and the
problem can be retried), "No results" when it is `Loaded []` (see `emptyText`),
and nothing while it is `NotAsked` and the search box is empty. Once the user has
typed, `NotAsked` also shows the skeleton (the request is about to start), so the
palette never says "No results" before the answer is there: set the section to
`Loading` or `NotAsked` only while a request is pending, and leave the section
out for a text that is too short to search for. Items that are `Kept` stay in the
list; when the last refresh failed a line "Old data from 14:05" stands above
them. The items of a remote section are not filtered again: the backend already
did that.

The query lives in the state, so the application watches it and starts the
request. Compare before and after the update, and debounce with a counter:

    PaletteMsg m ->
        let
            ( palette, cmd ) =
                CommandPalette.update m model.palette

            changed =
                CommandPalette.query palette /= CommandPalette.query model.palette
        in
        if changed then
            ( { model | palette = palette, hits = NotAsked, ticket = model.ticket + 1 }
            , Cmd.batch
                [ Cmd.map PaletteMsg cmd
                , Process.sleep 250 |> Task.perform (\_ -> Debounced (model.ticket + 1))
                ]
            )

        else
            ( { model | palette = palette }, Cmd.map PaletteMsg cmd )

    Debounced ticket ->
        if ticket == model.ticket && CommandPalette.query model.palette /= "" then
            ( { model | hits = Loading }, searchCustomers ticket (CommandPalette.query model.palette) )

        else
            ( model, Cmd.none )

    GotHits ticket result ->
        if ticket == model.ticket then
            ( { model | hits = Remote.fromResult result }, Cmd.none )

        else
            ( model, Cmd.none )

Results that arrive late for an old query are dropped by the ticket. Take a new
ticket when you open the palette too (`OpenPalette -> ... ticket = model.ticket + 1`,
and `hits = NotAsked`): a search that was still running when the palette was
closed would otherwise answer into the next opening, under an empty query.

### `Section`

```elm
type Section msg  -- opaque: no constructors are exposed
```

A titled group of items. Make one with `section` (items the palette filters
itself) or `remote` (items the application provides).

### `section`

```elm
section : String -> List (Item msg) -> Section msg
```

A titled group of items that the palette filters and ranks itself as the
user types. The section is left out while no item matches.

    CommandPalette.section "Navigation" [ goToOrders, goToInvoices ]

### `remote`

```elm
remote : String -> Remote.Remote (List (Item msg)) -> Section msg
```

A titled group of items that the application provides, for example the result
of a search in the backend. It is not filtered again. Pair it with `onRetry`
and `emptyText`.

    CommandPalette.remote "Customers" model.customerHits
        |> CommandPalette.onRetry SearchCustomers

### `onRetry`

```elm
onRetry : msg -> Section msg -> Section msg
```

The message that the "Try again" button of a failed remote section sends. The
button is only shown for a problem that is worth retrying (see
`Remote.isRetryable`). Does nothing to a section made with `section`.

### `emptyText`

```elm
emptyText : String -> Section msg -> Section msg
```

What a remote section says when it has no items, for example "No customers
found". The default is "No results". Does nothing to a section made with
`section`.

## Attributes

### `Attribute`

```elm
type Attribute msg  -- opaque: no constructors are exposed
```

A setting of the palette. Make them with the functions below and pass a list
to `view`; later attributes win over earlier ones.

### `sections`

```elm
sections : List (Section msg) -> Attribute msg
```

The sections, in the order they are shown. The default is none.

### `recent`

```elm
recent : List (Item msg) -> Attribute msg
```

Items shown first, under the heading "Recent", while the query is empty:
the commands the user ran last, for example. The default is none.

### `placeholder`

```elm
placeholder : String -> Attribute msg
```

The hint in the empty search box. The default is "Search commands and
content ...".

### `label`

```elm
label : String -> Attribute msg
```

The accessible name of the dialog and of its list. The default is "Command
palette".

### `noResults`

```elm
noResults : String -> Attribute msg
```

The text shown when nothing matches at all. The default is "No results". A
remote section that is empty has its own text, see `emptyText`.

### `locale`

```elm
locale : Locale.Locale -> Attribute msg
```

The language of the built-in texts: the placeholder, the footer, the heading
of the recent items and the announcement of the number of results. The default
is `Locale.default`, which is `Locale.en`.

### `settings`

```elm
settings : Settings.Settings -> Attribute msg
```

The settings of the application (`Klar.Settings`): the time zone of the time in
"Old data from 14:05". Without it the time is written in UTC and ends in "UTC".

    CommandPalette.settings model.settings
