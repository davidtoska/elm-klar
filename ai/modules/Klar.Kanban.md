# Klar.Kanban

A dense board of ordered work columns, with explicit card moves, work-in-progress limits and keyboard operation that does not depend on dragging.

Import: `import Klar.Kanban as Kanban` | Group: Arranging

Types: `Msg`, `Move`, `Limit`, `State`, `Column`, `Problem`, `Attribute`

## Signatures

```elm
view :
    (Msg -> msg)
    -> List (Attribute cardId msg)
    -> { label : String, columns : Remote.Remote (List (Column columnId card)), columnIds : Ids.Ids columnId, cardIds : Ids.Ids cardId, cardId : card -> cardId, title : card -> String, content : card -> Html msg }
    -> State
    -> Html msg

-- Columns
type Column columnId card  -- opaque: no constructors are exposed
type Limit  -- opaque: no constructors are exposed
column : columnId -> String -> List card -> Column columnId card
cards : Column columnId card -> List card
limit : Int -> Maybe Limit
withLimit : Limit -> Column columnId card -> Column columnId card

-- State
type State  -- opaque: no constructors are exposed
type Msg  -- opaque: no constructors are exposed
init : String -> State
update : Msg -> State -> ( State, Cmd Msg )
focusCard : Ids.Ids cardId -> cardId -> State -> Cmd Msg

-- Move requests
type Move cardId columnId  -- opaque: no constructors are exposed
type Problem  -- opaque: no constructors are exposed
move : Ids.Ids cardId -> Ids.Ids columnId -> State -> State -> Maybe (Move cardId columnId)
cardId : Move cardId columnId -> cardId
source : Move cardId columnId -> columnId
target : Move cardId columnId -> columnId
position : Move cardId columnId -> Int
applyMove :
    Ids.Ids cardId
    -> Ids.Ids columnId
    -> (card -> cardId)
    -> Move cardId columnId
    -> List (Column columnId card)
    -> Result Problem (List (Column columnId card))
problemText : Locale.Locale -> Problem -> String

-- Attributes
type Attribute cardId msg  -- opaque: no constructors are exposed
onOpen : (cardId -> msg) -> Attribute cardId msg
disabled : Bool -> Attribute cardId msg
headingLevel : Int -> Attribute cardId msg
onRetry : msg -> Attribute cardId msg
locale : Locale.Locale -> Attribute cardId msg
settings : Settings.Settings -> Attribute cardId msg
```

## Documentation

A dense board of ordered work columns, with explicit card moves, work-in-progress
limits and keyboard operation that does not depend on dragging.

Use when: work moves between stages and the order inside a stage matters.
Do not use when: one list only needs reordering; use `Klar.Sortable`, or `Klar.WorkQueue` for reviewing one record beside its details.
Quick path: `column`, `init`, `update`, `move`, `applyMove`, `view`

    import Klar.Kanban as Kanban

    -- model: board : Kanban.State, columns : List (Kanban.Column StageId Order)
    --        moveProblem : Maybe Kanban.Problem
    -- init: Kanban.init "orders-board"
    BoardMsg inner ->
        let
            ( board, cmd ) =
                Kanban.update inner model.board

            next =
                { model | board = board }
        in
        case Kanban.move orderIds stageIds model.board board of
            Just change ->
                case Kanban.applyMove orderIds stageIds .id change model.columns of
                    Ok columns ->
                        ( { next | columns = columns, moveProblem = Nothing }, Cmd.map BoardMsg cmd )

                    Err problem ->
                        ( { next | moveProblem = Just problem }, Cmd.map BoardMsg cmd )

            Nothing ->
                ( next, Cmd.map BoardMsg cmd )

    -- view:
    Kanban.view BoardMsg []
        { label = "Order fulfilment", columns = Remote.Loaded model.columns
        , columnIds = stageIds, cardIds = orderIds, cardId = .id
        , title = .number, content = viewOrderSummary
        }
        model.board

Make columns with `column`; `limit` validates a non-negative capacity and `withLimit`
attaches it. A full column refuses incoming cards, while cards already there may
be reordered or moved out, even if a server update put the count over the limit.
The board never truncates or silently removes cards.

Press a card's move button, then use Up/Down or Home/End to choose its position and
Left/Right to choose the next available column. Enter or Space confirms; Escape or Tab
cancels. Pointer users use the same button and the native destination/position
selectors. A move is a request: only the application applies or persists it.
`applyMove` rejects a request when column order, card ids/order or limits changed
since the move began. Editing only card content does not invalidate a move.
Show a rejected move with `problemText` in the page; do not silently discard an `Err`.

Column ids must be unique; card ids must be unique across the whole board. Bad data
is still shown, with a warning and all movement disabled. Unknown ids or stale
requests produce an explicit `Problem`, never a guessed destination. The board
draws all loaded cards, so page large boards in the application. There is no drag
gesture, virtualisation or swimlane model; all operations have ordinary controls.

Keep the command from `update`: it restores focus to the moved card after a local
move. For a server-confirmed move, call `focusCard` after applying the answer.
Use the root id from `init` with `Klar.focus` in a retry handler. Every `Remote`
state is drawn; stale or refreshing data remains visible but cannot be moved.

### `view`

```elm
view :
    (Msg -> msg)
    -> List (Attribute cardId msg)
    -> { label : String, columns : Remote.Remote (List (Column columnId card)), columnIds : Ids.Ids columnId, cardIds : Ids.Ids cardId, cardId : card -> cardId, title : card -> String, content : card -> Html msg }
    -> State
    -> Html msg
```

Draws the supplied stages and records without truncation. Ids are your types;
`title` names each card and `content` supplies its body without wrapping its actions.
Stale and refreshing boards cannot be moved; inspect or retry them first.

## Columns

### `Column`

```elm
type Column columnId card  -- opaque: no constructors are exposed
```

One stage, containing your records in their displayed order.

### `Limit`

```elm
type Limit  -- opaque: no constructors are exposed
```

A validated maximum number of cards permitted to enter a stage.

### `column`

```elm
column : columnId -> String -> List card -> Column columnId card
```

Creates a stage without a WIP limit. The label is your text; empty stages stay visible.

### `cards`

```elm
cards : Column columnId card -> List card
```

Records in a stage, in order. The application owns these values.

### `limit`

```elm
limit : Int -> Maybe Limit
```

Validates a capacity. Zero accepts no incoming cards; negatives return `Nothing`.

### `withLimit`

```elm
withLimit : Limit -> Column columnId card -> Column columnId card
```

Attaches a capacity to a stage. Existing cards are never removed or hidden.

## State

### `State`

```elm
type State  -- opaque: no constructors are exposed
```

Interaction state only: the current move proposal, not your application records.

### `Msg`

```elm
type Msg  -- opaque: no constructors are exposed
```

Internal move controls. Route every message through `update`.

### `init`

```elm
init : String -> State
```

Creates a board with no card being moved. The DOM id must be unique on the page.

### `update`

```elm
update : Msg -> State -> ( State, Cmd Msg )
```

Changes only the proposal until confirmation, then records one request and
restores focus to the card's move button. The application still decides what to save.

### `focusCard`

```elm
focusCard : Ids.Ids cardId -> cardId -> State -> Cmd Msg
```

Restores focus after an asynchronous server answer moves a card. Map the command
with the same message constructor used for `update`.

## Move requests

### `Move`

```elm
type Move cardId columnId  -- opaque: no constructors are exposed
```

A request tied to the exact board order and limits the person reviewed.

### `Problem`

```elm
type Problem  -- opaque: no constructors are exposed
```

A rejected request. Read its localised explanation with `problemText`.

### `move`

```elm
move : Ids.Ids cardId -> Ids.Ids columnId -> State -> State -> Maybe (Move cardId columnId)
```

Reads a confirmation from the states immediately before and after one `update`.
The same pair cannot describe multiple moves; unknown keys return `Nothing`.

### `cardId`

```elm
cardId : Move cardId columnId -> cardId
```

Application id of the card that should move.

### `source`

```elm
source : Move cardId columnId -> columnId
```

Application id of the stage the card came from.

### `target`

```elm
target : Move cardId columnId -> columnId
```

Application id of the destination stage.

### `position`

```elm
position : Move cardId columnId -> Int
```

Zero-based insertion index in the destination after removing the card from its
source. A move within one stage uses this same rule and never counts the card twice.

### `applyMove`

```elm
applyMove :
    Ids.Ids cardId
    -> Ids.Ids columnId
    -> (card -> cardId)
    -> Move cardId columnId
    -> List (Column columnId card)
    -> Result Problem (List (Column columnId card))
```

Applies one request to current application data, or returns a problem without
changing it. Uses exact ids/order/limits as a revision guard; card content may change.
Reordering an already over-limit stage is allowed because it does not increase WIP.

### `problemText`

```elm
problemText : Locale.Locale -> Problem -> String
```

A human explanation of an invalid board, changed snapshot, full stage or unknown
destination. No application data is changed when `applyMove` returns a problem.

## Attributes

### `Attribute`

```elm
type Attribute cardId msg  -- opaque: no constructors are exposed
```

Optional board behaviour. Later attributes win; the board is movable by default.

### `onOpen`

```elm
onOpen : (cardId -> msg) -> Attribute cardId msg
```

Turns card titles into buttons sending their application id. Absent by default.

### `disabled`

```elm
disabled : Bool -> Attribute cardId msg
```

Prevents new moves and confirmation. Existing cards remain readable. Defaults to `False`.

### `headingLevel`

```elm
headingLevel : Int -> Attribute cardId msg
```

Level of column headings, from 1 through 6. Defaults to 3; other values use 3.

### `onRetry`

```elm
onRetry : msg -> Attribute cardId msg
```

Retry message for initial errors and failed refreshes. Absent by default.

### `locale`

```elm
locale : Locale.Locale -> Attribute cardId msg
```

Built-in text language. Defaults to English.

### `settings`

```elm
settings : Settings.Settings -> Attribute cardId msg
```

Formats retained-data timestamps in the application's zone. Defaults to `Settings.default`.
