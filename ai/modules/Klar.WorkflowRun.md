# Klar.WorkflowRun

Live execution diagram, context and attempt history for a workflow snapshot.

Import: `import Klar.WorkflowRun as Runner` | Group: Processes and state

Types: `Attribute`

## Signatures

```elm
type Attribute id msg  -- opaque: no constructors are exposed
view : List (Attribute id msg) -> Workflow.Engine.Run id -> Html msg
viewRemote : List (Attribute id msg) -> Remote.Remote (Workflow.Engine.Run id) -> Html msg
locale : Locale.Locale -> Attribute id msg
selected : Maybe id -> Attribute id msg
onSelect : (id -> msg) -> Attribute id msg
onRetry : msg -> Attribute id msg
id : String -> Attribute id msg
```

## Documentation

Live execution diagram, context and attempt history for a workflow snapshot.

Use when: a person needs to see which step is active and inspect intermediate results.
Do not use when: editing a definition; use `Klar.WorkflowBuilder`.

    import Klar.WorkflowRun as Runner

    Runner.view [ Runner.onSelect InspectStep ] run

The host owns decisions and server commands. This component only inspects data.
`viewRemote` also retains existing nodes through refreshing and failed refreshes.

### `Attribute`

```elm
type Attribute id msg  -- opaque: no constructors are exposed
```

Inspector selection, language and remote retry settings.

### `view`

```elm
view : List (Attribute id msg) -> Workflow.Engine.Run id -> Html msg
```

Draw the actual snapshot, attempts and named context. Revisited nodes retain
all their outputs and the active node is marked with `aria-current`.

### `viewRemote`

```elm
viewRemote : List (Attribute id msg) -> Remote.Remote (Workflow.Engine.Run id) -> Html msg
```

A remote run, with loading, failure, data, refreshing and old-data states.

### `locale`

```elm
locale : Locale.Locale -> Attribute id msg
```

Built-in language, English by default.

### `selected`

```elm
selected : Maybe id -> Attribute id msg
```

Node whose attempt results are expanded. The active node is used by default.

### `onSelect`

```elm
onSelect : (id -> msg) -> Attribute id msg
```

Receive the inspected node identifier.

### `onRetry`

```elm
onRetry : msg -> Attribute id msg
```

Retry a failed remote request; the host reloads the snapshot.

### `id`

```elm
id : String -> Attribute id msg
```

Unique focus target, including remote loading and failure states.
