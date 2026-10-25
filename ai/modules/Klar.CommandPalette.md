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
withCommand : String -> Item msg -> Item msg
withId : String -> Item msg -> Item msg
withDisabled : String -> Item msg -> Item msg

-- Command words
argument : List (Item msg) -> State -> String

-- Sections
type Section msg  -- opaque: no constructors are exposed
section : String -> List (Item msg) -> Section msg
remote : String -> Remote.Remote (List (Item msg)) -> Section msg
onRetry : msg -> Section msg -> Section msg
withEmptyText : String -> Section msg -> Section msg

-- Attributes
type Attribute msg  -- opaque: no constructors are exposed
sections : List (Section msg) -> Attribute msg
recent : List (Item msg) -> Attribute msg
placeholder : String -> Attribute msg
ariaLabel : String -> Attribute msg
emptyText : String -> Attribute msg
platform : Kbd.Platform -> Attribute msg
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
        ( { model | palette = palette, customerHits = Remote.NotAsked }, Cmd.map PaletteMsg cmd )

    PaletteMsg m ->
        let
            ( palette, cmd ) =
                CommandPalette.update m model.palette

            text =
                CommandPalette.query palette
        in
        if text /= CommandPalette.query model.palette then
            -- the query settled on a new text: ask the backend (see "Sections")
            ( { model
                | palette = palette
                , customerHits =
                    if text == "" then
                        Remote.NotAsked

                    else
                        Remote.Loading
              }
            , Cmd.batch
                [ Cmd.map PaletteMsg cmd
                , if text == "" then
                    Cmd.none

                  else
                    searchCustomers text
                ]
            )

        else
            ( { model | palette = palette }, Cmd.map PaletteMsg cmd )

    GotCustomers asked result ->
        -- an answer to a query that is no longer the palette's comes too late
        if asked == CommandPalette.query model.palette then
            ( { model | customerHits = Remote.fromResult (Result.map (List.map customerItem) result) }, Cmd.none )

        else
            ( model, Cmd.none )

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
                |> CommandPalette.onRetry RetryCustomers
            ]
        , CommandPalette.recent model.recentItems
        , CommandPalette.platform model.platform -- Kbd.pc or Kbd.mac, for the key caps
        ]
        model.palette

Picking an item closes the palette, gives focus back to its opener and sends the
item's own message (a message that moves focus, such as one that opens a drawer,
wins). `Escape` and a click outside close it without running anything. The palette is a modal
dialog: `view` returns an [`Overlay`](Klar.Overlay.md#overlay), and while it is open
the page behind it is inert.
Pressing the shortcut again while the palette is open starts over with an empty
query; call `close` instead if you want the shortcut to toggle.

**Keyboard and screen readers**: the search box keeps focus, also when the user
clicks the frame of the palette, and takes it back if the focused element goes
away. `ArrowDown` and `ArrowUp` move the highlight (and wrap around),
`PageDown` and `PageUp` move six items, `Enter` runs the highlighted item. The
`Enter` that confirms the text of an input method (Japanese, Chinese) runs
nothing. The highlighted item is the `aria-activedescendant` of the search box,
which is a combobox, and a polite live region announces the number of results.
Focus cannot leave the palette: `Tab` only moves between the search box and the
"Try again" button of a failed section. `Escape` gives focus back to the element
that had it before the palette opened (if it has an id), or to the `opener`
given to `open`. The shortcut of an item is drawn by [Klar.Kbd](Klar.Kbd.md) for the
`platform` (Ctrl on a PC, ⌘ on a Mac) and read out as a phrase ("Control plus
K").

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

Handles typing, the pause before `query` changes, the highlight, closing and
scrolling. The command moves focus, scrolls the list and waits for the pause, so
map it with `Cmd.map`. Compare `query` before and after to start searches.

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
(see `openedFrom`). Picking an item closes the palette by itself. The query is
emptied, so `query` is `""` while the palette is closed.

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

What the user has typed, trimmed, once the typing pauses for 300 ms: the text
to search the backend for. Compare it before and after `update` and ask when it
changes; write no debounce of your own. An emptied box, `setQuery` and `open`
change it at once, and it is `""` while the palette is closed. The sections made
with `section` filter as the user types and do not wait.

### `setQuery`

```elm
setQuery : String -> State -> State
```

Replaces the query and clears the highlight, for example to open the palette
with a prefix. `query` reports it at once, without the pause. It does not open
the palette and does nothing to a closed one (`open` starts with an empty query),
so call it after `open`.

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

The shortcut of the command, shown as key caps at the right (drawn by
[Klar.Kbd](Klar.Kbd.md) for the `platform`). Write it in the keys of
[Klar.Shortcut](Klar.Shortcut.md): `mod (char 'k')`, `char '?'`. It is only a
hint: the palette does not listen for the keys, a `Shortcut` in your list does.

### `withKeywords`

```elm
withKeywords : List String -> Item msg -> Item msg
```

Extra words the item is found by, without showing them. A match on a
keyword ranks below a match on the label. Called twice, the words add up (as
with `withCommand`).

    CommandPalette.item "New order" NewOrder
        |> CommandPalette.withKeywords [ "create", "add" ]

### `withCommand`

```elm
withCommand : String -> Item msg -> Item msg
```

The words that call the item, for an item that takes an argument: "go to
order" in "go to order 1001". The item matches while the query starts with these
words (any case, any accents), also after an argument has been typed. Use
`argument` to get the part of the query after the words. An item can have several
commands (one for each language, say); the words are not shown.

    CommandPalette.item "Go to order ..." (GoTo Orders)
        |> CommandPalette.withCommand "go to order"

### `withId`

```elm
withId : String -> Item msg -> Item msg
```

A stable identity, for items with the same label (two customers called "Ada
Lovelace"). It keeps the highlight on the right item when the results change.

### `withDisabled`

```elm
withDisabled : String -> Item msg -> Item msg
```

An item that cannot run now, with the reason in place of its description:
the user still finds the command and learns why it is not there yet. The arrow
keys skip it, `Enter` and a click do nothing, and a screen reader hears it as
unavailable (`aria-disabled`).

    CommandPalette.item "Export the selection" ExportSelection
        |> CommandPalette.withDisabled "Select some rows first"

### Command words

A palette often has a section that searches the backend next to the commands:
the user types "go to order 1001" and the section should ask for "1001", not for
the words of the command. Declare the words on the item with `withCommand` and ask
`argument` for what follows them. The item stays in the list while its words are
followed by an argument (without `withCommand` no item matches "go to order
1001", as "1001" is nowhere in "Go to order").

### `argument`

```elm
argument : List (Item msg) -> State -> String
```

The `query` without the command words of the items that are called by them,
for the request to the backend. When the query starts with the `withCommand`
words of one of the items (the longest wins), the rest of the query is returned,
trimmed; otherwise the whole query. Like `query` it waits for a pause in the
typing, so compare `query` to know when to ask. Give it the same items as the
view, so a function that makes them can be shared.

    CommandPalette.argument [ goToOrder ] palette -- "1001", for "Go to order 1001"

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
problem can be retried), "No results" when it is `Loaded []` (see
`withEmptyText`). A section that is `NotAsked` shows the skeleton while the user
is typing (the request is about to start), so the palette never says "No
results" before the answer is there, and is left out once the typing has paused:
that is how the application says there is nothing to ask for this text. Data
that is `Kept` stays in the list, empty or not: dimmed and busy while it is
refreshed (`Remote.refresh`), and with "Old data from 14:05" next to the title
of the section when the last refresh failed. The items of a remote section are
not filtered again: the backend already did that.

The search is the wiring at the top of this page, and it needs **no debounce and
no ticket of your own**. `query` waits for a pause of 300 ms in the typing (an
empty text comes at once), so ask the backend whenever `query` changes from
before `update` to after it. Send the text with the request and drop an answer
whose text is no longer `CommandPalette.query model.palette`: it answers an old
question. `query` is `""` while the palette is closed, so an answer that arrives
after the palette closed is dropped too. Set the section to `NotAsked` when you
`open` the palette, so the results of the last opening do not show under the new
empty query. For a text that is too short to search for, or a command that has no
argument yet ("go to order"), set the section to `NotAsked` and send nothing: the
section goes away when the typing pauses.

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
and `withEmptyText`.

    CommandPalette.remote "Customers" model.customerHits
        |> CommandPalette.onRetry SearchCustomers

### `onRetry`

```elm
onRetry : msg -> Section msg -> Section msg
```

The message that the "Try again" button of a failed remote section sends. The
button is only shown for a problem that is worth retrying (see
`Remote.isRetryable`). Does nothing to a section made with `section`.

### `withEmptyText`

```elm
withEmptyText : String -> Section msg -> Section msg
```

What a remote section says when it has no items, for example "No customers
found". The default is the palette's `emptyText`, "No results". Does nothing to a
section made with `section`.

    CommandPalette.remote "Customers" model.customerHits
        |> CommandPalette.withEmptyText "No customers found"

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

### `ariaLabel`

```elm
ariaLabel : String -> Attribute msg
```

The accessible name of the dialog and of its list, which only a screen reader
hears. The default is "Command palette".

### `emptyText`

```elm
emptyText : String -> Attribute msg
```

The text shown when nothing matches at all, and what an empty remote section
says unless it has a `withEmptyText` of its own. The default is "No results".

### `platform`

```elm
platform : Kbd.Platform -> Attribute msg
```

The keyboard to write the shortcuts of the items for, as in
[Klar.Kbd](Klar.Kbd.md): `Kbd.pc` (the default: Ctrl, Alt, Shift) or `Kbd.mac`
(⌘, ⌥, ⇧). Read it once from the user agent with `Kbd.platformFromUserAgent`.
[Klar.Shortcut](Klar.Shortcut.md) finds a Mac by itself, a view cannot: without
this a Mac user reads "Ctrl K" for a shortcut that fires on ⌘ K.

    CommandPalette.platform (Kbd.platformFromUserAgent flags.userAgent)

### `locale`

```elm
locale : Locale.Locale -> Attribute msg
```

The language of the built-in texts: the placeholder, the footer, the heading
of the recent items, the spoken names of the keys and the announcement of the
number of results. The default is `Locale.default`, which is `Locale.en`.

### `settings`

```elm
settings : Settings.Settings -> Attribute msg
```

The settings of the application (`Klar.Settings`): the time zone of the time in
"Old data from 14:05". Without it the time is written in UTC and ends in "UTC".

    CommandPalette.settings model.settings
