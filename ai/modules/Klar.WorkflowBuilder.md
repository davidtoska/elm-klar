# Klar.WorkflowBuilder

A controlled, vertical workflow editor with a node palette, explicit branches, bounded return arrows and an inspector for the selected node.

Import: `import Klar.WorkflowBuilder as Builder` | Group: Processes and state

Types: `Attribute`

## Signatures

```elm
type Attribute id msg  -- opaque: no constructors are exposed
view : Ids.Ids id -> List (Attribute id msg) -> Workflow.Definition id -> Html msg
locale : Locale.Locale -> Attribute id msg
selected : Maybe id -> Attribute id msg
onSelect : (id -> msg) -> Attribute id msg
onAdd : (Workflow.Kind -> msg) -> Attribute id msg
onChange : (Workflow.Definition id -> msg) -> Attribute id msg
readOnly : Bool -> Attribute id msg
id : String -> Attribute id msg
```

## Documentation

A controlled, vertical workflow editor with a node palette, explicit branches,
bounded return arrows and an inspector for the selected node.

Use when: people graphically compose AI/human processes without an infinite canvas.
Do not use when: following an executing instance; use `Klar.WorkflowRun`.

    import Klar.Ids as Ids
    import Klar.WorkflowBuilder as Builder

    Builder.view Ids.string
        [ Builder.selected model.selected
        , Builder.onSelect SelectNode
        , Builder.onAdd AddNode
        , Builder.onChange ChangeDefinition
        ]
        model.definition

The application owns the definition, selection and new identifiers. Changes are
emitted as a complete proposed definition. The editor never repairs invalid
input; validation remains visible and execution can be blocked by the host.
Connection labels, endpoints and loop budgets are editable in the inspector.

### `Attribute`

```elm
type Attribute id msg  -- opaque: no constructors are exposed
```

Controlled editor options. All callbacks are absent by default.

### `view`

```elm
view : Ids.Ids id -> List (Attribute id msg) -> Workflow.Definition id -> Html msg
```

The editor. Each node is an ordinary button; all edits work with a keyboard.
The supplied `Ids` writes/reads the application's own node identifiers.

### `locale`

```elm
locale : Locale.Locale -> Attribute id msg
```

Built-in language, English by default.

### `selected`

```elm
selected : Maybe id -> Attribute id msg
```

Identifier of the inspected step, absent by default.

### `onSelect`

```elm
onSelect : (id -> msg) -> Attribute id msg
```

Receive the identifier of a clicked step or connection destination.

### `onAdd`

```elm
onAdd : (Workflow.Kind -> msg) -> Attribute id msg
```

Receive a kind from the palette. Allocate an identifier in the application.

### `onChange`

```elm
onChange : (Workflow.Definition id -> msg) -> Attribute id msg
```

Receive a complete edited definition. Save/version it in your application.

### `readOnly`

```elm
readOnly : Bool -> Attribute id msg
```

Disable design mutations while keeping inspection available. Default false.

### `id`

```elm
id : String -> Attribute id msg
```

Unique DOM id and prefix for inspector fields. Defaults to `workflow-builder`;
set a distinct id for each editor on the same page. The root can receive focus.
