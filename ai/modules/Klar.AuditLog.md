# Klar.AuditLog

An immutable activity history with actors, exact times and expandable diffs.

Import: `import Klar.AuditLog as AuditLog` | Group: Text and change

Types: `Entry`, `Attribute`

## Signatures

```elm
view :
    List (Attribute msg)
    -> { label : String, ids : Ids.Ids id, entries : Remote.Remote (List (Entry id)) }
    -> Html msg

-- Entries
type Entry id  -- opaque: no constructors are exposed
entry : { id : id, actor : String, action : String, at : Time.Posix } -> Entry id
withDetail : String -> Entry id -> Entry id
withDiff : Diff.Diff -> Entry id -> Entry id

-- Attributes
type Attribute msg  -- opaque: no constructors are exposed
id : String -> Attribute msg
search : String -> (String -> msg) -> Attribute msg
onLoadMore : msg -> Attribute msg
onRetry : msg -> Attribute msg
locale : Locale.Locale -> Attribute msg
settings : Settings.Settings -> Attribute msg
```

## Documentation

An immutable activity history with actors, exact times and expandable diffs.

Use when: people need to trace who changed a record and inspect the change.
Do not use when: the events describe a schedule or milestones; use `Klar.Timeline`.

    import Klar.AuditLog as AuditLog
    import Klar.Diff as Diff
    import Klar.Ids as Ids
    import Klar.Remote as Remote
    import Time

    AuditLog.view []
        { label = "Order history"
        , ids = Ids.int
        , entries = Remote.Loaded
            [ AuditLog.entry
                { id = 1, actor = "Ada", action = "Changed delivery address"
                , at = Time.millisToPosix 0
                }
                |> AuditLog.withDiff (Diff.lines [] "Bergen" "Oslo")
            ]
        }

The supplied order is preserved: the application decides chronology and paging.
Search filters only loaded entries and says how many remain. Diffs are built when
data arrives, then revealed with native keyboard-accessible `details`; opening a
diff does not request or mutate data. Unique ids keep an expanded entry attached to
the same event when more entries are added. Exact timestamps use the application's
zone, or explicitly UTC until one is supplied. All `Remote` states are handled.

### `view`

```elm
view :
    List (Attribute msg)
    -> { label : String, ids : Ids.Ids id, entries : Remote.Remote (List (Entry id)) }
    -> Html msg
```

A named history of uniquely identified entries. Neither events nor their
order are changed by the component.

## Entries

### `Entry`

```elm
type Entry id  -- opaque: no constructors are exposed
```

An event with an application id, actor, action and exact instant.

### `entry`

```elm
entry : { id : id, actor : String, action : String, at : Time.Posix } -> Entry id
```

Creates an event without a description or diff. Actor and action are your text.

### `withDetail`

```elm
withDetail : String -> Entry id -> Entry id
```

Adds a plain-text description, also included in search. Replaces an earlier detail.

### `withDiff`

```elm
withDiff : Diff.Diff -> Entry id -> Entry id
```

Attaches a precomputed diff, collapsed initially. Replaces an earlier diff.

## Attributes

### `Attribute`

```elm
type Attribute msg  -- opaque: no constructors are exposed
```

Optional history behaviour. Later attributes win.

### `id`

```elm
id : String -> Attribute msg
```

A DOM id unique on the page, and a stable focus target after retry. It also
names the search input, so use it when two histories appear on the same page.
Absent by default; then the search field derives its id from its label.

### `search`

```elm
search : String -> (String -> msg) -> Attribute msg
```

Adds a controlled search of actor, action and detail in loaded entries.
Search ignores case and accents. No search field by default.

### `onLoadMore`

```elm
onLoadMore : msg -> Attribute msg
```

Adds a load-more button; it also appears when search has no matches.

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

Time zone and timestamp formatting. Defaults to `Settings.default`, explicitly UTC.
