# Klar.StateMachine

A small state machine diagram with enabled event buttons and explicit returns.

Import: `import Klar.StateMachine as Machine` | Group: Processes and state

Types: `Attribute`, `State`, `Machine`, `Transition`

## Signatures

```elm
type alias Machine id =
    { states : List (State id)
    , transitions : List (Transition id)
    , current : id
    }
type alias State id = { id : id, label : String, terminal : Bool }
type alias Transition id = { from : id, to : id, event : String }
type Attribute msg  -- opaque: no constructors are exposed
transition : String -> Machine id -> Maybe (Machine id)
view : List (Attribute msg) -> Machine id -> Html msg
locale : Locale.Locale -> Attribute msg
onTransition : (String -> msg) -> Attribute msg
```

## Documentation

A small state machine diagram with enabled event buttons and explicit returns.

Use when: inspecting a step's lifecycle or letting a person trigger valid state events.
Do not use when: modelling a multi-step process; use `Klar.Workflow`.

    import Klar.StateMachine as Machine

    lifecycle =
        { states = [ { id = "draft", label = "Draft", terminal = False }, { id = "ready", label = "Ready", terminal = True } ]
        , transitions = [ { from = "draft", to = "ready", event = "Approve" } ]
        , current = "draft"
        }

    Machine.view [ Machine.onTransition SendEvent ] lifecycle

The host owns state and persistence. `transition` only accepts events from the
current nonterminal state with exactly one matching transition to a known state.

### `Machine`

```elm
type alias Machine id =
    { states : List (State id)
    , transitions : List (Transition id)
    , current : id
    }
```

Application-owned states, transitions and the current state identifier.

### `State`

```elm
type alias State id = { id : id, label : String, terminal : Bool }
```

A named state. Terminal states do not offer events.

### `Transition`

```elm
type alias Transition id = { from : id, to : id, event : String }
```

An event-labelled arrow between states.

### `Attribute`

```elm
type Attribute msg  -- opaque: no constructors are exposed
```

Language and event callback settings.

### `transition`

```elm
transition : String -> Machine id -> Maybe (Machine id)
```

Return the new machine for a valid, unambiguous event, otherwise `Nothing`.

### `view`

```elm
view : List (Attribute msg) -> Machine id -> Html msg
```

Draw the states in a wrapping strip, outgoing arrows and enabled events.
State names, arrow destinations and current/terminal markers are visible text.

### `locale`

```elm
locale : Locale.Locale -> Attribute msg
```

Built-in language, English by default.

### `onTransition`

```elm
onTransition : (String -> msg) -> Attribute msg
```

Receive an enabled event name. The host validates and applies it.
