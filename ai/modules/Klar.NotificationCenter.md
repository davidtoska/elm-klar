# Klar.NotificationCenter

Persistent notifications with an unread filter and explicit read and dismiss actions.

Import: `import Klar.NotificationCenter as Notifications` | Group: Status and feedback

Types: `Attribute`, `Notification`

## Signatures

```elm
view :
    List (Attribute id msg)
    -> { label : String, ids : Ids.Ids id, items : Remote.Remote (List (Notification id)) }
    -> Html msg

-- Notifications
type Notification id  -- opaque: no constructors are exposed
notification :
    { id : id, title : String, body : String, at : Time.Posix, unread : Bool }
    -> Notification id

-- Attributes
type Attribute id msg  -- opaque: no constructors are exposed
id : String -> Attribute id msg
unreadOnly : Bool -> (Bool -> msg) -> Attribute id msg
onOpen : (id -> msg) -> Attribute id msg
onRead : (id -> msg) -> Attribute id msg
onDismiss : (id -> msg) -> Attribute id msg
onReadAll : (List id -> msg) -> Attribute id msg
onLoadMore : msg -> Attribute id msg
onRetry : msg -> Attribute id msg
locale : Locale.Locale -> Attribute id msg
settings : Settings.Settings -> Attribute id msg
```

## Documentation

Persistent notifications with an unread filter and explicit read and dismiss
actions. Merely viewing a notification never marks it read.

Use when: people need a durable inbox of notifications, alongside transient toasts.
Do not use when: feedback should disappear after a few seconds; use `Klar.Toast`.

    import Klar.Ids as Ids
    import Klar.NotificationCenter as Notifications
    import Klar.Remote as Remote
    import Time

    Notifications.view []
        { label = "Notifications"
        , ids = Ids.int
        , items = Remote.Loaded
            [ Notifications.notification
                { id = 1, title = "Export ready", body = "42 orders exported."
                , at = Time.millisToPosix 0, unread = True
                }
            ]
        }

Items remain in the supplied order. All counts and the read-all action refer only
to loaded notifications; the application owns paging, persistence and mutations.
Keep dismissed items in the list until the server confirms removal if a failure
must be recoverable. `Remote.Kept` retains the inbox during refresh and failed
refresh, with the shared old-data notice and retry.

### `view`

```elm
view :
    List (Attribute id msg)
    -> { label : String, ids : Ids.Ids id, items : Remote.Remote (List (Notification id)) }
    -> Html msg
```

A named inbox with unique application ids. Read and dismissed states are
supplied by the application; the component never hides or acknowledges data itself.

## Notifications

### `Notification`

```elm
type Notification id  -- opaque: no constructors are exposed
```

One notification, with an application-owned id and explicit unread state.

### `notification`

```elm
notification :
    { id : id, title : String, body : String, at : Time.Posix, unread : Bool }
    -> Notification id
```

Creates a notification. Its timestamp is an instant, formatted in `settings`.

## Attributes

### `Attribute`

```elm
type Attribute id msg  -- opaque: no constructors are exposed
```

Optional inbox behaviour. All mutations are absent by default.

### `id`

```elm
id : String -> Attribute id msg
```

A DOM id unique on the page, also a stable focus target after removing an
item or retrying. The unread switch uses this id too, so supply it for multiple
inboxes on one page. Absent by default.

### `unreadOnly`

```elm
unreadOnly : Bool -> (Bool -> msg) -> Attribute id msg
```

Controlled unread filter and its change handler. Without it all items appear.

### `onOpen`

```elm
onOpen : (id -> msg) -> Attribute id msg
```

Opens a notification by id. Opening does not also send `onRead`.

### `onRead`

```elm
onRead : (id -> msg) -> Attribute id msg
```

Adds a mark-as-read action to unread notifications.

### `onDismiss`

```elm
onDismiss : (id -> msg) -> Attribute id msg
```

Adds an explicit dismiss action. The application decides when to remove data.

### `onReadAll`

```elm
onReadAll : (List id -> msg) -> Attribute id msg
```

Adds "Mark loaded as read", sending only the ids of loaded unread items.
The action is disabled when there are none.

### `onLoadMore`

```elm
onLoadMore : msg -> Attribute id msg
```

Adds a load-more button, even when the unread filter has no matches.

### `onRetry`

```elm
onRetry : msg -> Attribute id msg
```

Retry for initial failures and failed refreshes. Absent by default.

### `locale`

```elm
locale : Locale.Locale -> Attribute id msg
```

Language of built-in text. Defaults to English.

### `settings`

```elm
settings : Settings.Settings -> Attribute id msg
```

Time zone and date formatting. Defaults to `Settings.default`, explicitly UTC.
