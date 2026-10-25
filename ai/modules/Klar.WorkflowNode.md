# Klar.WorkflowNode

A compact, selectable workflow step with a kind, status and input/output ports.

Import: `import Klar.WorkflowNode as Node` | Group: Processes and state

Types: `Attribute`

## Signatures

```elm
type Attribute msg  -- opaque: no constructors are exposed
view : List (Attribute msg) -> Workflow.Node id -> Html msg
locale : Locale.Locale -> Attribute msg
onSelect : msg -> Attribute msg
selected : Bool -> Attribute msg
status : String -> Attribute msg
detail : String -> Attribute msg
```

## Documentation

A compact, selectable workflow step with a kind, status and input/output ports.

Use when: composing process diagrams or a palette of reusable nodes.
Do not use when: editing a whole workflow; use `Klar.WorkflowBuilder`.

    import Klar.Workflow as Workflow
    import Klar.WorkflowNode as Node

    Node.view [ Node.onSelect SelectStep ]
        (Workflow.node "draw" Workflow.ai "Generate illustrations")

### `Attribute`

```elm
type Attribute msg  -- opaque: no constructors are exposed
```

Node appearance and selection handler. Later settings win.

### `view`

```elm
view : List (Attribute msg) -> Workflow.Node id -> Html msg
```

Render a node. Kind and status are written in words as well as shown visually.

### `locale`

```elm
locale : Locale.Locale -> Attribute msg
```

Built-in language, English by default.

### `onSelect`

```elm
onSelect : msg -> Attribute msg
```

Make the node a keyboard-accessible button that sends this message.

### `selected`

```elm
selected : Bool -> Attribute msg
```

Mark the inspected node, false by default.

### `status`

```elm
status : String -> Attribute msg
```

Host-supplied, localized status text, empty by default.

### `detail`

```elm
detail : String -> Attribute msg
```

Host-supplied summary, such as attempt or artifact count.
