# Klar.Workflow

Ordered workflow definitions shared by a builder, a runner and a server.

Import: `import Klar.Workflow as Workflow` | Group: Processes and state

Types: `Kind`, `Issue`, `Edge`, `Node`, `Definition`

## Signatures

```elm
type alias Definition id =
    { title : String
    , nodes : List (Node id)
    , edges : List (Edge id)
    , ownerRole : String
    }
type alias Node id =
    { id : id
    , kind : Kind
    , title : String
    , instructions : String
    , inputKey : String
    , outputKey : String
    , waitSeconds : Int
    , state : String
    , performerRole : String
    , approverRole : String
    }
type alias Edge id = { from : id, to : id, label : String, maxVisits : Maybe Int }
type Kind  -- opaque: no constructors are exposed
type Issue id  -- opaque: no constructors are exposed
node : id -> Kind -> String -> Node id
edge : id -> id -> String -> Edge id
loop : Int -> id -> id -> String -> Edge id
input : Kind
ai : Kind
human : Kind
task : Kind
decision : Kind
wait : Kind
output : Kind
kinds : List Kind
kindKey : Kind -> String
kindLabel : Locale.Locale -> Kind -> String
kindIcon : Kind -> Icon.Icon
validate : Definition id -> List (Issue id)
issueText : Locale.Locale -> Definition id -> Issue id -> String
find : id -> Definition id -> Maybe (Node id)
outgoing : id -> Definition id -> List (Edge id)
```

## Documentation

Ordered workflow definitions shared by a builder, a runner and a server.

Use when: people design processes with AI work, review, branches and bounded returns.
Do not use when: only a form's progress is needed; use `Klar.Stepper`.

    import Klar.Workflow as Workflow

    draft =
        { title = "Illustration"
        , ownerRole = "designer"
        , nodes =
            [ Workflow.node "brief" Workflow.input "Collect a brief"
            , Workflow.node "draw" Workflow.ai "Draw a character"
            , Workflow.node "done" Workflow.output "Deliver artwork"
            ]
        , edges =
            [ Workflow.edge "brief" "draw" "Continue"
            , Workflow.edge "draw" "done" "Continue"
            ]
        }

The list of nodes is the visual order. Every connection is explicit. A return
must have a positive traversal limit; this makes every accepted cycle bounded.
Definitions are plain data, suitable for encoding in your own API.

### `Definition`

```elm
type alias Definition id =
    { title : String
    , nodes : List (Node id)
    , edges : List (Edge id)
    , ownerRole : String
    }
```

A versionable design. Running instances should keep their own snapshot.

### `Node`

```elm
type alias Node id =
    { id : id
    , kind : Kind
    , title : String
    , instructions : String
    , inputKey : String
    , outputKey : String
    , waitSeconds : Int
    , state : String
    , performerRole : String
    , approverRole : String
    }
```

A step's instructions, input binding, output binding and simulated wait in seconds.
An empty input binding means that no named input is required.

### `Edge`

```elm
type alias Edge id = { from : id, to : id, label : String, maxVisits : Maybe Int }
```

An explicitly labelled transition. `maxVisits` limits traversals of this edge,
not attempts at the destination. `Nothing` is only valid for forward edges.

### `Kind`

```elm
type Kind  -- opaque: no constructors are exposed
```

Extensible vocabulary of standard steps; compare values or use `kindKey`.

### `Issue`

```elm
type Issue id  -- opaque: no constructors are exposed
```

One structural problem, scoped to a node when possible.

### `node`

```elm
node : id -> Kind -> String -> Node id
```

Standard node with blank instructions and bindings and a two-second wait.

### `edge`

```elm
edge : id -> id -> String -> Edge id
```

A forward transition, chosen by its unique label at a branch.

### `loop`

```elm
loop : Int -> id -> id -> String -> Edge id
```

A bounded return. Invalid limits remain visible to `validate`.

### `input`

```elm
input : Kind
```

A person supplies the initial context.

### `ai`

```elm
ai : Kind
```

Server-side AI work with instructions and named input/output.

### `human`

```elm
human : Kind
```

A person reviews artifacts and chooses a transition.

### `task`

```elm
task : Kind
```

A manual task performed by its assigned role, such as an interview or enrollment.

### `decision`

```elm
decision : Kind
```

An explicit choice between labelled paths. The host evaluates its condition.

### `wait`

```elm
wait : Kind
```

A server-owned delay or external wait.

### `output`

```elm
output : Kind
```

A terminal step which delivers the resulting context.

### `kinds`

```elm
kinds : List Kind
```

All standard kinds in palette order.

### `kindKey`

```elm
kindKey : Kind -> String
```

Stable machine name, suitable for your JSON protocol.

### `kindLabel`

```elm
kindLabel : Locale.Locale -> Kind -> String
```

Localized palette label.

### `kindIcon`

```elm
kindIcon : Kind -> Icon.Icon
```

Icon matching the standard kind.

### `validate`

```elm
validate : Definition id -> List (Issue id)
```

Check start/end nodes, reachability, labels, bindings and bounded cycles.
No repair or clamping is performed. An empty list means the design is executable.

### `issueText`

```elm
issueText : Locale.Locale -> Definition id -> Issue id -> String
```

Localized structural error. Node titles are included in the message.

### `find`

```elm
find : id -> Definition id -> Maybe (Node id)
```

Find a step using the application's own identifier.

### `outgoing`

```elm
outgoing : id -> Definition id -> List (Edge id)
```

Connections in declaration order, which is also the order of branch buttons.
