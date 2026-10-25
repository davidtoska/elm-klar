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
actions : List (Html msg) -> Attribute msg
compact : Attribute msg
headingLevel : Int -> Attribute msg
polite : Attribute msg
locale : Locale.Locale -> Attribute msg
```

## Documentation

What to show when a request failed: a clear title, the reason, and a
button to try again when trying again can help.

Use when: a request failed and the user should see why, with a button to try again.
Do not use when: a list is simply empty (use `Klar.EmptyState`), or the failed request is the body of a card, a dialog or a page (use `Klar.RemoteView`, which draws this for you).

    import Klar.Button as Button
    import Klar.ErrorState as ErrorState
    import Klar.RemoteView as RemoteView

    -- one piece of remote data: RemoteView shows this error state when the
    -- request failed, and keeps old (Kept) data on the screen while it reloads
    RemoteView.view [ RemoteView.onRetry ReloadOrders ] model.orders viewOrderList

    -- a failure of your own, outside a body of remote data
    ErrorState.view
        [ ErrorState.onRetry RetryExport
        , ErrorState.actions [ Button.view [ Button.onClick CancelExport ] "Cancel export" ]
        ]
        problem

    -- inside a table or small panel
    ErrorState.view [ ErrorState.compact, ErrorState.onRetry ReloadOrders ] problem

Never write your own `case` on a `Remote` that sends every other state to a
spinner (`_ -> Spinner.panel ...`): `Kept` data, old data that is being
refreshed, would vanish behind it. [Klar.RemoteView](Klar.RemoteView.md) and the
components that take a `Remote` ([Klar.Table](Klar.Table.md),
[Klar.Tree](Klar.Tree.md), [Klar.ListItem](Klar.ListItem.md) ...) draw every state and
use this module themselves.

A `Problem` is plain data. Make one for each failed request with
`Remote.problem`, which has ready-made texts for the kind of failure, and adjust
it with `Remote.withTitle`, `Remote.withDetail` or `Remote.withCode`:

    Remote.problem Remote.server
        |> Remote.withCode "503"

The icon follows the kind of the problem (`Icon.wifiOff` for `Remote.network`,
`Icon.clock` for `Remote.timeout`, `Icon.lock` for `Remote.forbidden` ...). The
code, if there is one, is selected whole with one click, for a support request.
The retry button is shown only when you gave an `onRetry` message and the
problem is worth retrying (`Remote.isRetryable`: network trouble, timeouts,
server errors and unknown errors). The other kinds, such as a missing resource
or a permission problem, would fail the same way again, so there is no button
for them: give those a way forward with `actions` ("Sign in", "Back to orders").

The state is announced to screen readers at once when it appears (`role="alert"`);
`polite` waits for a pause, for the many small regions of a dashboard that fail
together. A polite state that arrives together with its text is missed by some
screen readers, so use `polite` where something else on the page speaks up: the
one assertive notice of the page, or a region that stays (`Klar.RemoteView`).
The retry button is replaced when the request starts again, and keyboard focus
falls to the page with it. For the body of a card, a dialog or a page use
[Klar.RemoteView](Klar.RemoteView.md), which has a body that keeps focus (`id`,
`focus`); a page that is only an error state draws its title outside it
(see "A page that is only a `RemoteView`" there).

## View

### `view`

```elm
view : List (Attribute msg) -> Remote.Problem -> Html msg
```

An error state for a `Problem`: an icon for its kind, its title, its detail
and its code (when it has them), the retry button and your `actions`. A problem
with an empty title renders no headline element.

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

### `actions`

```elm
actions : List (Html msg) -> Attribute msg
```

Buttons or links for another way forward, shown after the retry button (or
alone, when there is none): "Sign in" for `Remote.unauthorized`, "Request access"
for `Remote.forbidden`, "Back to orders" for `Remote.notFound`. There are none
by default.

    ErrorState.view
        [ ErrorState.actions [ Button.view [ Button.href (Link.internal "#/orders") ] "Back to orders" ] ]
        problem

### `compact`

```elm
compact : Attribute msg
```

Less vertical space and a smaller icon, for use inside tables and small
panels. It follows a compact density of the application (`Klar.Settings`) without it.

### `headingLevel`

```elm
headingLevel : Int -> Attribute msg
```

Makes the title a heading of this level (1 to 6), for an error state that is
the main content of a page or a section. The default is no heading: a plain line,
right inside a table cell or a small panel.

### `polite`

```elm
polite : Attribute msg
```

Announce it politely (`role="status"`) instead of at once (`role="alert"`), so
a screen reader finishes what it is reading first. Use it for the small regions
of a dashboard, which tend to fail together: one assertive message for the page
is enough.

### `locale`

```elm
locale : Locale.Locale -> Attribute msg
```

The language of the built-in text, which is the label of the retry button
("Try again" in English). The default is `Locale.default`, which is English. The
title and the detail come from the `Problem`: the texts the problem has of its
own, or the ready-made ones for its kind in this language.
