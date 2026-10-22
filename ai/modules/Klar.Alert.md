# Klar.Alert

Inline messages that tell the user something important in the context where it matters: information, success, a warning or an error.

Import: `import Klar.Alert as Alert` | Group: Status and feedback

Types: `Attribute`

## Signatures

```elm
-- Views
view : List (Attribute msg) -> String -> Html msg
viewWith : List (Attribute msg) -> List (Html msg) -> Html msg
stale : List (Attribute msg) -> msg -> List String -> Html msg

-- Content
type Attribute msg  -- opaque: no constructors are exposed
tone : Theme.Tone -> Attribute msg
title : String -> Attribute msg
icon : Icon.Icon -> Attribute msg
actions : List (Html msg) -> Attribute msg
onDismiss : msg -> Attribute msg

-- Look
banner : Attribute msg
compact : Attribute msg

-- Accessibility and text
polite : Attribute msg
locale : Locale.Locale -> Attribute msg
```

## Documentation

Inline messages that tell the user something important in the context where
it matters: information, success, a warning or an error.

Use when: the user must see an important message in the place where it matters.
Do not use when: the message should disappear by itself (as `Klar.Toast`).

    import Html
    import Klar.Alert as Alert
    import Klar.Theme exposing (Tone(..))

    Alert.view
        [ Alert.tone Warning, Alert.title "Unsaved changes" ]
        "Your changes to this order are not saved yet."

    Alert.viewWith
        [ Alert.tone Danger, Alert.onDismiss ErrorDismissed, Alert.actions [ retryButton ] ]
        [ Html.text "The order could not be saved. " ]

The tone sets the color and the icon; `Info` is the default. An alert stays
where you put it until you stop showing it. `onDismiss` adds a close button, but
it only sends your message: hide the alert in your `update` function. For a
message that goes away by itself use [Klar.Toast](Klar.Toast.md).

Errors and warnings use `role="alert"` so screen readers announce them at once,
even in the middle of a sentence; the other tones use `role="status"`. For a
message that appears while the user is typing (an "unsaved changes" notice), add
`Alert.polite`: it waits for a pause.

## Views

### `view`

```elm
view : List (Attribute msg) -> String -> Html msg
```

An alert with a plain text message.

    Alert.view [ Alert.tone Success ] "The order was shipped."

### `viewWith`

```elm
viewWith : List (Attribute msg) -> List (Html msg) -> Html msg
```

An alert whose message is HTML, for a link or some emphasis inside the
text.

    Alert.viewWith [ Alert.tone Info ]
        [ Html.text "See the "
        , Text.link { href = "#/shipping", label = "shipping rules" }
        , Html.text " for details."
        ]

### `stale`

```elm
stale : List (Attribute msg) -> msg -> List String -> Html msg
```

One notice for a page whose data is old because a refresh failed, so that
nobody reads old numbers by mistake. Give it the names of the stale parts
(`Remote.staleIn` makes them) and the message that tries again. With no names it
shows nothing.

    Alert.stale [ Alert.locale model.locale ]
        Refresh
        (List.concat
            [ Remote.staleIn "orders" model.orders
            , Remote.staleIn "figures" model.summary
            ]
        )

The notice is a warning that screen readers announce politely. The attributes
that make sense here are `locale`, `banner`, `compact` and `onDismiss`; the tone,
the title, the icon and the actions are set by the notice.

## Content

### `Attribute`

```elm
type Attribute msg  -- opaque: no constructors are exposed
```

A setting of an alert. Make them with the functions below and pass a list
to `view` or `viewWith`; later attributes win over earlier ones.

### `tone`

```elm
tone : Theme.Tone -> Attribute msg
```

The kind of message, which sets its color, its icon and how screen readers
announce it. The default is `Info`. `Success`, `Warning` and `Danger` have colors
and icons of their own; `Primary` looks like `Info` and `Neutral` is gray.

### `title`

```elm
title : String -> Attribute msg
```

A short bold line above the message. There is no title by default.

### `icon`

```elm
icon : Icon.Icon -> Attribute msg
```

Replaces the icon that comes with the tone: `Icon.info` for `Neutral`,
`Primary` and `Info`, `Icon.checkCircle` for `Success`, `Icon.warning` for
`Warning` and `Icon.errorCircle` for `Danger`.

### `actions`

```elm
actions : List (Html msg) -> Attribute msg
```

Buttons or links shown below the message, for the next step the user can
take, such as "Try again".

### `onDismiss`

```elm
onDismiss : msg -> Attribute msg
```

Shows a close button that sends this message. The alert does not hide
itself: stop showing it when the message arrives in your `update` function.

## Look

### `banner`

```elm
banner : Attribute msg
```

A flat style for the top of a page or a panel: square corners, a border only
along the bottom edge and a colored bar at the left edge.

### `compact`

```elm
compact : Attribute msg
```

Tighter padding and smaller text, for alerts inside forms and tables.

## Accessibility and text

### `polite`

```elm
polite : Attribute msg
```

Announce it politely (`role="status"`) even for a warning or an error, so
a screen reader finishes what it is reading first. Use it for notices that show
up by themselves while the user works, never for the result of an action.

### `locale`

```elm
locale : Locale.Locale -> Attribute msg
```

The language of the built-in text, which is the accessible name of the close
button ("Close" in English). The default is `Locale.default`, which is English.
