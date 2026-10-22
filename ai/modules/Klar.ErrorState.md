# Klar.ErrorState

What to show when a request failed: a clear title, the reason, and a button to try again when trying again can help.

Import: `import Klar.ErrorState as ErrorState` | Group: Status and feedback

Types: `Attribute`

## Signatures

```elm
-- View
view : List (Attribute msg) -> Remote.Problem -> Html msg

-- Attributes
type Attribute msg  -- opaque: no constructors are exposed
onRetry : msg -> Attribute msg
compact : Attribute msg
locale : Locale.Locale -> Attribute msg
```

## Documentation

What to show when a request failed: a clear title, the reason, and a
button to try again when trying again can help.

    import Klar.ErrorState as ErrorState
    import Klar.Locale as Locale
    import Klar.Remote as Remote exposing (Remote(..))
    import Klar.Spinner as Spinner

    viewOrders : Remote (List Order) -> Html Msg
    viewOrders orders =
        case orders of
            Loaded list ->
                viewOrderList list

            Failed problem ->
                ErrorState.view [ ErrorState.onRetry ReloadOrders ] problem

            _ ->
                Spinner.panel "Loading orders ..."

    -- inside a table or small panel
    ErrorState.view [ ErrorState.compact, ErrorState.onRetry ReloadOrders ] problem

Pair it with [Klar.Remote](Klar.Remote.md): when the data is `Failed problem`,
show this. A `Problem` is plain data. Make one for each failed request with
`Remote.problem`, which has ready-made texts for the kind of failure, and adjust
it with `Remote.withTitle`, `Remote.withDetail` or `Remote.withCode`:

    Remote.problem Remote.server
        |> Remote.withCode "503"

The icon follows the kind of the problem (`Icon.wifiOff` for `Remote.network`,
`Icon.clock` for `Remote.timeout`, `Icon.lock` for `Remote.forbidden` ...). The state is
announced to screen readers at once (`role="alert"`). The retry button is shown
only when you gave an `onRetry` message and the problem is worth retrying
(`Remote.isRetryable`: network trouble, timeouts, server errors and unknown
errors). The other kinds, such as a missing resource or a permission problem,
would fail the same way again, so there is no button for them. The components
that show remote data ([Klar.Table](Klar.Table.md), [Klar.Tree](Klar.Tree.md),
[Klar.ListItem](Klar.ListItem.md) ...) use this module themselves.

## View

### `view`

```elm
view : List (Attribute msg) -> Remote.Problem -> Html msg
```

An error state for a `Problem`: an icon for its kind, its title, its detail
and its code (when it has them), and the retry button. A problem with an empty
title renders no headline element.

    ErrorState.view [ ErrorState.onRetry ReloadOrders ] problem

## Attributes

### `Attribute`

```elm
type Attribute msg  -- opaque: no constructors are exposed
```

A setting of an error state. Make them with the functions below and pass a
list to `view`; later attributes win over earlier ones.

### `onRetry`

```elm
onRetry : msg -> Attribute msg
```

The message sent when the user presses the "Try again" button. Without
`onRetry` there is no button. With it, the button is still hidden when trying
again would not help (see `Klar.Remote.isRetryable`).

### `compact`

```elm
compact : Attribute msg
```

Less vertical space and a smaller icon, for use inside tables and small
panels.

### `locale`

```elm
locale : Locale.Locale -> Attribute msg
```

The language of the built-in text, which is the label of the retry button
("Try again" in English). The default is `Locale.default`, which is English. The
title and the detail come from the `Problem`: the texts the problem has of its
own, or the ready-made ones for its kind in this language.
