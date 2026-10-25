# Klar.Workflow.Engine

Pure, deterministic execution state for an ordered workflow.

Import: `import Klar.Workflow.Engine as Engine` | Group: Processes and state

Types: `Status`, `Run`, `Attempt`

## Signatures

```elm
type alias Run id =
    { id : String
    , startedBy : String
    , definition : Workflow.Definition id
    , active : Maybe id
    , status : Status
    , previousStatus : Status
    , context : Dict String Json.Encode.Value
    , nodeStates : List { node : id, config : Json.Encode.Value, output : Maybe Json.Encode.Value }
    , attempts : List (Attempt id)
    , traversals : List { from : id, label : String, count : Int }
    , error : Maybe String
    , revision : Int
    }
type Status = Running | AwaitingInput | Waiting | Paused | Succeeded | Failed | Cancelled
type alias Attempt id =
    { node : id
    , number : Int
    , outcome : String
    , result : Json.Encode.Value
    , actor : Maybe String
    }
start :
    String
    -> Workflow.Definition id
    -> Dict String Json.Encode.Value
    -> Result (List (Workflow.Issue id)) (Run id)
complete : Json.Encode.Value -> Run id -> Run id
choose : String -> String -> Run id -> Run id
fail : String -> Run id -> Run id
retry : Run id -> Run id
pause : Run id -> Run id
resume : Run id -> Run id
cancel : Run id -> Run id
available : Run id -> List (Workflow.Edge id)
current : Run id -> Maybe (Workflow.Node id)
```

## Documentation

Pure, deterministic execution state for an ordered workflow.

Use when: implementing or simulating a workflow server with explicit human decisions.
Do not use when: rendering a process; use `Klar.WorkflowRun`.

    import Klar.Workflow.Engine as Engine

    -- Start validates the definition and freezes it into this run.
    started =
        Engine.start "run-42" definition initialContext

Backward transitions clear downstream context bindings and latest outputs while
retaining all attempts. Each node must own its output binding. Missing input blocks
human and worker steps alike.

The server owns time, authorization and AI calls. `complete` accepts the worker's
result, `choose` accepts a labelled human/condition decision. No function performs
effects. Pause and terminal states reject late completions. Retry records a new
attempt; previous failures and outputs remain in history.

### `Run`

```elm
type alias Run id =
    { id : String
    , startedBy : String
    , definition : Workflow.Definition id
    , active : Maybe id
    , status : Status
    , previousStatus : Status
    , context : Dict String Json.Encode.Value
    , nodeStates : List { node : id, config : Json.Encode.Value, output : Maybe Json.Encode.Value }
    , attempts : List (Attempt id)
    , traversals : List { from : id, label : String, count : Int }
    , error : Maybe String
    , revision : Int
    }
```

A run's snapshot, current context, attempt history and edge traversal counts.
Use the transition functions to mutate it so invariants remain consistent.

### `Status`

```elm
type Status = Running | AwaitingInput | Waiting | Paused | Succeeded | Failed | Cancelled
```

Closed execution states. A paused run retains its previous phase internally.

### `Attempt`

```elm
type alias Attempt id =
    { node : id
    , number : Int
    , outcome : String
    , result : Json.Encode.Value
    , actor : Maybe String
    }
```

Immutable record of an attempt's output, decision or failure. Newest is last.

### `start`

```elm
start :
    String
    -> Workflow.Definition id
    -> Dict String Json.Encode.Value
    -> Result (List (Workflow.Issue id)) (Run id)
```

Validate and snapshot a definition. Initial context is supplied by the person
starting the process and may contain uploaded asset references.

### `complete`

```elm
complete : Json.Encode.Value -> Run id -> Run id
```

Accept one worker result while running/waiting. Named input must exist.
Multiple exits are left for an explicit `choose`, never silently selected.

### `choose`

```elm
choose : String -> String -> Run id -> Run id
```

Choose an available labelled branch, attaching feedback to the context.
Invalid labels, exhausted loops and decisions outside a review phase are ignored.

### `fail`

```elm
fail : String -> Run id -> Run id
```

Record a step failure. Only live execution phases accept it.

### `retry`

```elm
retry : Run id -> Run id
```

Retry a failed node with retained context and complete attempt history.
An exhausted transition budget cannot be reset by retrying.

### `pause`

```elm
pause : Run id -> Run id
```

Pause an active run. The server must invalidate outstanding worker tickets.

### `resume`

```elm
resume : Run id -> Run id
```

Restore the phase that was paused.

### `cancel`

```elm
cancel : Run id -> Run id
```

Cancel an unfinished run; late replies cannot complete it.

### `available`

```elm
available : Run id -> List (Workflow.Edge id)
```

Exits whose individual traversal budgets are not exhausted.

### `current`

```elm
current : Run id -> Maybe (Workflow.Node id)
```

The active node of the run's frozen definition.
