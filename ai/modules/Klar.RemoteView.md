# Klar.RemoteView

The body of a card, a dialog or a drawer that shows one piece of remote data: a loading skeleton that screen readers hear, the failure with a retry, and the data, old or being refreshed.

Import: `import Klar.RemoteView as RemoteView` | Group: Data and utilities

Types: `Attribute`

## Signatures

```elm
view : List (Attribute msg) -> Remote.Remote a -> (a -> List (Html msg)) -> List (Html msg)

-- Attributes
type Attribute msg  -- opaque: no constructors are exposed
onRetry : msg -> Attribute msg
loadingLabel : String -> Attribute msg
skeleton : Html msg -> Attribute msg
locale : Locale.Locale -> Attribute msg
settings : Settings.Settings -> Attribute msg
```

## Documentation

The body of a card, a dialog or a drawer that shows one piece of remote data:
a loading skeleton that screen readers hear, the failure with a retry, and the
data, old or being refreshed. You write only what the data looks like.

Use when: the body of a card, a dialog or a drawer shows one piece of remote data.
Do not use when: the data is a table or a list (use `Klar.Table` or `Klar.ListItem`, which take a `Remote` themselves).

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
        [ Drawer.title "Order 1042" ]
        model.drawer
        (RemoteView.view [ RemoteView.onRetry ReloadOrder ] model.order viewOrder)

`NotAsked` and `Loading` show a skeleton and set the body busy, with a polite
"Loading" for screen readers (`loadingLabel` says what is loading). `Failed` shows
the problem with a "Try again" button (`onRetry`). `Loaded` calls your function.
Data that is `Kept` ([Klar.Remote](Klar.Remote.md)) stays on the screen: dimmed and
busy while it is refreshed, and with "Old data from 14:05" and a retry when the
last refresh failed. An empty result is yours to draw, with
[Klar.EmptyState](Klar.EmptyState.md), inside the function.

The body is a list of nodes, so it fits wherever a list of children goes: the body
of a `Card`, a `Modal` or a `Drawer`, or any `Html.div`. Inside a `Modal` or
`Drawer`, focus that was on the retry button when the data reloads goes back into
the dialog by itself; in a `Card` it falls to the page, so move it yourself
(`Browser.Dom.focus`) if that matters.

### `view`

```elm
view : List (Attribute msg) -> Remote.Remote a -> (a -> List (Html msg)) -> List (Html msg)
```

The body for a `Remote`: the skeleton, the failure, or what your function
makes of the data.

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

### `locale`

```elm
locale : Locale.Locale -> Attribute msg
```

The language of the built-in text ("Loading", "Try again", "Old data from").
The default is `Locale.default`, which is English.

### `settings`

```elm
settings : Settings.Settings -> Attribute msg
```

The settings of the application (`Klar.Settings`): the time zone of the time in
"Old data from 14:05". Without it the time is written in UTC and ends in "UTC".

    RemoteView.settings model.settings
