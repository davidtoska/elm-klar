# Klar.ConflictResolver

A three-way field merge that makes concurrent edits explicit and requires a decision for every conflicting value before the result can be applied.

Import: `import Klar.ConflictResolver as Conflict` | Group: Text and change

Types: `Msg`, `Field`, `State`, `Attribute`

## Signatures

```elm
view :
    (Msg -> msg)
    -> List (Attribute id msg)
    -> { label : String, ids : Ids.Ids id, fields : Remote.Remote (List (Field id)) }
    -> State
    -> Html msg

-- Fields
type Field id  -- opaque: no constructors are exposed
field :
    id
    -> String
    -> { base : Maybe String, yours : Maybe String, theirs : Maybe String }
    -> Field id

-- State
type State  -- opaque: no constructors are exposed
type Msg  -- opaque: no constructors are exposed
init : String -> State
update : Msg -> State -> ( State, Cmd Msg )
resolved : Ids.Ids id -> List (Field id) -> State -> Result (List id) (List ( id, Maybe String ))
reset : State -> State

-- Attributes
type Attribute id msg  -- opaque: no constructors are exposed
onApply : (List ( id, Maybe String ) -> msg) -> Attribute id msg
saving : Bool -> Attribute id msg
onRetry : msg -> Attribute id msg
locale : Locale.Locale -> Attribute id msg
settings : Settings.Settings -> Attribute id msg
```

## Documentation

A three-way field merge that makes concurrent edits explicit and requires
a decision for every conflicting value before the result can be applied.

Use when: saving a record failed because someone else edited the same version.
Do not use when: a person only needs to inspect changes; use `Klar.Diff` or `Klar.Compare`.
Quick path: `field`, `init`, `update`, `view`, `resolved`

    import Klar.ConflictResolver as Conflict

    -- model: { conflict : Conflict.State } -- Conflict.init "order-conflict"
    -- update:
    ConflictMsg inner ->
        let
            ( conflict, cmd ) =
                Conflict.update inner model.conflict
        in
        ( { model | conflict = conflict }, Cmd.map ConflictMsg cmd )

    -- view:
    Conflict.view ConflictMsg [ Conflict.onApply ApplyMergedFields ]
        { label = "Resolve order changes", ids = fieldIds, fields = model.conflictingFields }
        model.conflict

`field` receives the common base, your edit and their latest edit. Equal edits
agree automatically. If only one side changed from the base, that change is kept.
When both changed differently, neither wins until the person chooses. Values are
compared exactly, including spaces; `Nothing` and `Just ""` are distinct.

Decisions remember all three versions they were made against. If refreshed data
changes any version, the decision no longer resolves that field. Reset the state
when beginning a different record, even when it has the same field ids. Applying
is disabled during refresh, with stale data, while saving, and until every field
is resolved. The application saves the result with its server revision token;
the component performs no writes. A failed save belongs beside this component
as an `Alert` or a form error. Unique field ids are required.

### `view`

```elm
view :
    (Msg -> msg)
    -> List (Attribute id msg)
    -> { label : String, ids : Ids.Ids id, fields : Remote.Remote (List (Field id)) }
    -> State
    -> Html msg
```

The three versions and per-field choices. Radio groups are named by the
resolver id and field id; two resolvers on a page must have distinct `init` ids.
The root is a stable focus target for retry handlers.

## Fields

### `Field`

```elm
type Field id  -- opaque: no constructors are exposed
```

One field with an application id, label and three exact optional text values.

### `field`

```elm
field :
    id
    -> String
    -> { base : Maybe String, yours : Maybe String, theirs : Maybe String }
    -> Field id
```

Creates a three-way comparison. `Nothing` means absent, `Just ""` means empty.

## State

### `State`

```elm
type State  -- opaque: no constructors are exposed
```

Decisions tied to the exact versions reviewed; contains no functions.

### `Msg`

```elm
type Msg  -- opaque: no constructors are exposed
```

Internal choice messages, handled by `update`.

### `init`

```elm
init : String -> State
```

Creates an empty resolver. The string is a DOM id unique on the page.

### `update`

```elm
update : Msg -> State -> ( State, Cmd Msg )
```

Records an individual or explicit bulk choice. No commands are needed.

### `resolved`

```elm
resolved : Ids.Ids id -> List (Field id) -> State -> Result (List id) (List ( id, Maybe String ))
```

Returns all field ids and resolved values in input order, or every unresolved
id. Choices against old versions are rejected. This pure function does not inspect
remote freshness; save only from current, authoritative server data.

### `reset`

```elm
reset : State -> State
```

Clears all choices, keeping the DOM id. Use when starting a different record.

## Attributes

### `Attribute`

```elm
type Attribute id msg  -- opaque: no constructors are exposed
```

Optional resolver behaviour. By default there is no apply action.

### `onApply`

```elm
onApply : (List ( id, Maybe String ) -> msg) -> Attribute id msg
```

Adds an apply button. Receives the complete resolved field list only after
an explicit click. Disabled for stale, refreshing, empty or unresolved data.

### `saving`

```elm
saving : Bool -> Attribute id msg
```

Disables choices and shows the apply button busy while a save is pending.
Defaults to `False`.

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

Formatting of retained-data timestamps. Defaults to `Settings.default`.
