# Klar.RemoteView

The body of a card, a dialog or a drawer that shows one piece of remote data.

Import: `import Klar.RemoteView as RemoteView` | Group: Data and utilities

Types: `Attribute`

## Signatures

```elm
view : List (Attribute msg) -> Remote.Remote a -> (a -> List (Html msg)) -> List (Html msg)

-- Attributes
type Attribute msg  -- opaque: no constructors are exposed
onRetry : msg -> Attribute msg
id : String -> Attribute msg
loadingLabel : String -> Attribute msg
skeleton : Html msg -> Attribute msg
emptyState : List (EmptyState.Attribute msg) -> Attribute msg
locale : Locale.Locale -> Attribute msg
settings : Settings.Settings -> Attribute msg
```

## Documentation

The body of a card, a dialog or a drawer that shows one piece of remote data:
a loading skeleton that screen readers hear, the failure with a retry, nothing to
show, and the data, old or being refreshed. You write only what the data looks like.

Use when: the body of a card, a dialog or a drawer shows one piece of remote data.
Do not use when: the data is a table or a list (use `Klar.Table` or `Klar.ListItem`, which take a `Remote` themselves).
Quick path: `view` with `onRetry`; `id` for focus after a retry, `emptyState` for an empty answer

    import Klar.Card as Card
    import Klar.RemoteView as RemoteView

    Card.view [ Card.title "Order 1042" ]
        (RemoteView.view
            [ RemoteView.onRetry ReloadOrder, RemoteView.loadingLabel "Loading order" ]
            model.order
            viewOrder
        )

    -- the same for a drawer or a dialog
    Drawer.view DrawerMsg
        []
        model.drawer
        "Order 1042"
        (RemoteView.view [ RemoteView.onRetry ReloadOrder ] model.order viewOrder)

`NotAsked` and `Loading` show a skeleton, with a polite "Loading" for screen readers
(`loadingLabel` says what is loading). `Failed` shows the problem with a "Try again"
button (`onRetry`) when trying again can help. The data calls your function, and when
your function returns no nodes at all the body says "Nothing to show"
(`emptyState` says it your way). Data that is `Kept` ([Klar.Remote](Klar.Remote.md)) stays
on the screen: dimmed and busy while it is refreshed, and with "Old data from 14:05"
and a retry when the last refresh failed.

**One element in every state.** The body is always one `div` that holds a live region
and then the content of the state, so that a refresh never rebuilds your nodes: a
button inside the body that starts a refresh keeps focus while the refresh is on its
way and when it ends, and so do the caret of a field, an open `<details>` and the
scroll position of an inner pane. The live region is the same element from loading to
data, and only its text changes, which is what screen readers announce reliably.

The body is a list with that one node, so it fits wherever a list of children goes:
the body of a `Card`, a `Modal` or a `Drawer`, or any `Html.div`. Inside, the content
is a column with the small gap of the library. When fresh data replaces a failure or
the marker of old data, the "Try again" button that had focus is gone with it: inside a `Modal` or `Drawer` focus goes back
into the dialog by itself; in a `Card` or on a page it falls to the page, unless the body
has an `id` and you move focus to it when you start the new request:

    RemoteView.view [ RemoteView.id "supplier", RemoteView.onRetry Retry ] model.supplier viewSupplier

    Retry ->
        ( { model | supplier = Remote.refresh model.supplier }
        , Cmd.batch [ fetchSupplier, Klar.focus "supplier" NoOp ]
        )

**A page that is only a `RemoteView`** has no heading while the data loads or when the
request failed, if the heading is part of the data. Draw the title of the page outside
the body, from what you know before the data is there, and give the body no heading of
its own: there is then one `h1` in every state.

    Layout.stack []
        [ PageHeader.view [ PageHeader.title (Remote.toMaybe model.supplier |> Maybe.map .name |> Maybe.withDefault "Supplier") ]
        , Layout.stack [] (RemoteView.view [ RemoteView.onRetry Retry ] model.supplier viewDetails)
        ]

### `view`

```elm
view : List (Attribute msg) -> Remote.Remote a -> (a -> List (Html msg)) -> List (Html msg)
```

The body for a `Remote`: the skeleton, the failure, the empty state, or what your
function makes of the data. The result is a list with one element, the same element in
every state.

## Attributes

### `Attribute`

```elm
type Attribute msg  -- opaque: no constructors are exposed
```

A setting of the body. Make them with the functions below and pass a list to
`view`; later attributes win over earlier ones.

### `onRetry`

```elm
onRetry : msg -> Attribute msg
```

The message sent by the "Try again" button, in the failure and in the marker
of old data. The button is only shown for problems worth retrying (see
`Remote.isRetryable`).

### `id`

```elm
id : String -> Attribute msg
```

The DOM id of the body, which must be unique on the page. The body is one element
in every state (loading, failed, nothing to show, old data, data); with an id it can
take focus, so that `Klar.focus` has a place to put it. There is no id by default.

### `loadingLabel`

```elm
loadingLabel : String -> Attribute msg
```

What is loading, as screen readers should hear it: "Loading order". The
default is "Loading".

### `skeleton`

```elm
skeleton : Html msg -> Attribute msg
```

The placeholder shown while loading, drawn with [Klar.Skeleton](Klar.Skeleton.md).
The default is a title line and a few lines of text.

### `emptyState`

```elm
emptyState : List (EmptyState.Attribute msg) -> Attribute msg
```

What the body shows when the data is there but your function draws nothing for
it (returns `[]`): an [Klar.EmptyState](Klar.EmptyState.md). The default is a compact
one that says "Nothing to show"; your attributes are applied after it, so yours win.
Return `[]` for an empty result and let the body say so:

    RemoteView.view
        [ RemoteView.emptyState [ EmptyState.title "No notes yet", EmptyState.actions [ addNoteButton ] ] ]
        model.notes
        (List.map viewNote)

### `locale`

```elm
locale : Locale.Locale -> Attribute msg
```

The language of the built-in text ("Loading", "Try again", "Old data from",
"Nothing to show"). The default is `Locale.default`, which is English.

### `settings`

```elm
settings : Settings.Settings -> Attribute msg
```

The settings of the application (`Klar.Settings`): the time zone of the time in
"Old data from 14:05". Without it the time is written in UTC and ends in "UTC".

    RemoteView.settings model.settings
