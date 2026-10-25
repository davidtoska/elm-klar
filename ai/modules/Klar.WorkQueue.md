# Klar.WorkQueue

A keyboard-driven work list beside a detail pane, for processing one record at a time without losing the surrounding queue.

Import: `import Klar.WorkQueue as WorkQueue` | Group: Tables and lists

Types: `Msg`, `State`, `Attribute`

## Signatures

```elm
view :
    (Msg -> msg)
    -> List (Attribute msg)
    -> { label : String, items : Remote.Remote (List record), ids : Ids.Ids id, id : record -> id, title : record -> String, summary : record -> String, detail : record -> Html msg }
    -> State
    -> Html msg

-- State
type State  -- opaque: no constructors are exposed
type Msg  -- opaque: no constructors are exposed
init : String -> State
update : Msg -> State -> ( State, Cmd Msg )
selected : Ids.Ids id -> State -> Maybe id
setSelected : Ids.Ids id -> Maybe id -> State -> State
query : State -> String

-- Attributes
type Attribute msg  -- opaque: no constructors are exposed
searchable : Attribute msg
onLoadMore : msg -> Attribute msg
onRetry : msg -> Attribute msg
locale : Locale.Locale -> Attribute msg
settings : Settings.Settings -> Attribute msg
```

## Documentation

A keyboard-driven work list beside a detail pane, for processing one record
at a time without losing the surrounding queue.

Use when: a person works through cases, approvals or incoming orders one by one.
Do not use when: the main task is comparing rows and columns; use `Klar.Table`.
Quick path: `init`, `update`, `view`, `selected`

    import Klar.WorkQueue as WorkQueue

    -- model: { queue : WorkQueue.State } -- WorkQueue.init "orders-queue"
    -- update:
    QueueMsg inner ->
        let
            ( queue, cmd ) =
                WorkQueue.update inner model.queue
        in
        ( { model | queue = queue }, Cmd.map QueueMsg cmd )

    -- view:
    WorkQueue.view QueueMsg [ WorkQueue.searchable ]
        { label = "Orders to review", items = model.orders
        , ids = orderIds, id = .id, title = .number, summary = .customer
        , detail = viewOrder
        }
        model.queue

Read `selected orderIds queue` before and after update to fetch extra detail when
selection changes. Actions such as approve and reject belong in `detail`, so they
retain the application's business rules and busy/error states. The queue never
approves anything on a navigation key.

Arrow keys, j/k, Home and End move selection and focus inside the list. Tab leaves
the list for the detail pane. Search matches loaded titles and summaries, preserves
their order and does not erase the selection. A selected record missing after a
refresh is reported, never silently replaced with another record. The detail pane
is keyed by id, so native form state cannot leak between records. All remote states,
including retained empty data, are drawn. This queue renders the loaded page;
use paging for very large queues, or `Klar.Table` with virtual rows.

### `view`

```elm
view :
    (Msg -> msg)
    -> List (Attribute msg)
    -> { label : String, items : Remote.Remote (List record), ids : Ids.Ids id, id : record -> id, title : record -> String, summary : record -> String, detail : record -> Html msg }
    -> State
    -> Html msg
```

Draws a named queue of uniquely identified records and the selected record's
detail. The stable region id from `init` is also a focus target for retry handlers.

## State

### `State`

```elm
type State  -- opaque: no constructors are exposed
```

Queue-local selection and search text; no application records are kept here.

### `Msg`

```elm
type Msg  -- opaque: no constructors are exposed
```

Internal queue interactions. Route them through `update`.

### `init`

```elm
init : String -> State
```

Creates an unselected queue. The string is a DOM id unique on the page.

### `update`

```elm
update : Msg -> State -> ( State, Cmd Msg )
```

Applies selection and search changes and moves focus on keyboard navigation.

### `selected`

```elm
selected : Ids.Ids id -> State -> Maybe id
```

The selected application id, or `Nothing` before selection or for an unknown key.
It may refer to a record outside the loaded page; the view reports that separately.

### `setSelected`

```elm
setSelected : Ids.Ids id -> Maybe id -> State -> State
```

Sets or clears selection without moving focus. Search is preserved.

### `query`

```elm
query : State -> String
```

Current search text. Initially empty; search is local to the loaded page.

## Attributes

### `Attribute`

```elm
type Attribute msg  -- opaque: no constructors are exposed
```

Queue settings. No search or load-more action is shown by default.

### `searchable`

```elm
searchable : Attribute msg
```

Adds a search field for loaded titles and summaries. Off by default.

### `onLoadMore`

```elm
onLoadMore : msg -> Attribute msg
```

Adds a load-more button. The application appends or replaces the loaded page.

### `onRetry`

```elm
onRetry : msg -> Attribute msg
```

Retry for initial failures and failed refreshes. Absent by default.

### `locale`

```elm
locale : Locale.Locale -> Attribute msg
```

Built-in text language. Defaults to English.

### `settings`

```elm
settings : Settings.Settings -> Attribute msg
```

Formatting of retained-data timestamps. Defaults to `Settings.default`.
