# Klar.AiReview

Review server-generated AI proposals one statement or change at a time, with evidence, exact before/after values, a reason and explicit approval or rejection.

Import: `import Klar.AiReview as Review` | Group: AI

Types: `Msg`, `State`, `Source`, `Proposal`, `Attribute`, `Decision`

## Signatures

```elm
view :
    (Msg -> msg)
    -> List (Attribute id msg)
    -> { label : String, ids : Ids.Ids id, proposals : Remote.Remote (List (Proposal id)) }
    -> State
    -> Html msg

-- Proposals and evidence
type Proposal id  -- opaque: no constructors are exposed
type Source  -- opaque: no constructors are exposed
proposal :
    { id : id, revision : String, title : String, before : String, after : String, rationale : String, sources : List Source }
    -> Proposal id
source : { label : String, url : String, excerpt : String } -> Source

-- Local review
type State  -- opaque: no constructors are exposed
type Msg  -- opaque: no constructors are exposed
init : String -> State
update : Msg -> State -> ( State, Cmd Msg )
reset : State -> State

-- Saving
type alias Decision id = { id : id, revision : String, approved : Bool, reason : String }
decisions : Ids.Ids id -> Remote.Remote (List (Proposal id)) -> State -> Maybe (List (Decision id))

-- Attributes
type Attribute id msg  -- opaque: no constructors are exposed
onSubmit : (List (Decision id) -> msg) -> Attribute id msg
saving : Bool -> Attribute id msg
errorMaybe : Maybe String -> Attribute id msg
discussion : (id -> String -> Html msg) -> Attribute id msg
onRetry : msg -> Attribute id msg
locale : Locale.Locale -> Attribute id msg
settings : Settings.Settings -> Attribute id msg
```

## Documentation

Review server-generated AI proposals one statement or change at a time, with
evidence, exact before/after values, a reason and explicit approval or rejection.

Use when: a person must understand and decide on AI suggestions before a server applies them.
Do not use when: approving ordinary workflow stages; use `Klar.ApprovalFlow`.
Quick path: `proposal`, `init`, `update`, `view`, `onSubmit`

    import Klar.AiReview as Review

    -- model: { review : Review.State } -- Review.init "ai-review"
    -- update:
    ReviewMsg inner ->
        let
            ( review, cmd ) =
                Review.update inner model.review
        in
        ( { model | review = review }, Cmd.map ReviewMsg cmd )

    -- view:
    Review.view ReviewMsg [ Review.onSubmit SaveDecisions ]
        { label = "Review AI suggestions", ids = proposalIds, proposals = model.proposals }
        model.review

Every decision remembers the complete displayed proposal, including sources. A
changed revision, explanation, source or value requires a new decision. Duplicate
ids block submission. Empty, loading, failed, refreshing and stale data cannot be
submitted. Rejection requires a nonblank reason; approval may include one.

The application sends decisions to its own server, which must authorize the user,
compare each revision with the current proposal and target-record revision, and
apply only approved changes atomically. A click is a request, never a successful
save. Keep `saving True` until acknowledgement, show `errorMaybe` on failure, and
replace the proposals with the server result on success. Use request tickets to
ignore late responses. Reset when changing case or tenant, even with identical ids.

`discussion` embeds [Klar.CommentThread](Klar.CommentThread.md) or custom structured
evidence beside each statement. Its callback receives id and revision; store threads
by both so a comment never silently moves to a revised statement. Source excerpts
are plain text and URLs are checked. Evidence is supplied by the application; the
component does not verify claims or manufacture confidence scores. All proposal
text is shown in full as plain text, including unusually long values.

### `view`

```elm
view :
    (Msg -> msg)
    -> List (Attribute id msg)
    -> { label : String, ids : Ids.Ids id, proposals : Remote.Remote (List (Proposal id)) }
    -> State
    -> Html msg
```

Exact proposal text, evidence, version-bound radio decisions and optional
discussion. The root is a stable focus target in every remote state.

## Proposals and evidence

### `Proposal`

```elm
type Proposal id  -- opaque: no constructors are exposed
```

A server proposal with an application id and an opaque server revision token.

### `Source`

```elm
type Source  -- opaque: no constructors are exposed
```

A source label, URL and exact excerpt. This is evidence to inspect, not verified truth.

### `proposal`

```elm
proposal :
    { id : id, revision : String, title : String, before : String, after : String, rationale : String, sources : List Source }
    -> Proposal id
```

One independently reviewable statement or change. For a new statement, use an
empty `before`. Include assumptions and limitations in `rationale`.

### `source`

```elm
source : { label : String, url : String, excerpt : String } -> Source
```

Creates evidence. Unsafe URLs remain visible text without a link.

## Local review

### `State`

```elm
type State  -- opaque: no constructors are exposed
```

Local decisions bound to exact reviewed content; no server writes or functions.

### `Msg`

```elm
type Msg  -- opaque: no constructors are exposed
```

Internal choices and raw review notes. Route through `update`.

### `init`

```elm
init : String -> State
```

Empty review. The string is a DOM id unique on the page.

### `update`

```elm
update : Msg -> State -> ( State, Cmd Msg )
```

Updates a version-bound choice or reason. No commands are needed.

### `reset`

```elm
reset : State -> State
```

Clears decisions when moving to another case, preserving the DOM id.

## Saving

### `Decision`

```elm
type alias Decision id = { id : id, revision : String, approved : Bool, reason : String }
```

A request to record a decision against this exact server revision. The server
must validate the revision and permissions before applying an approved proposal.

### `decisions`

```elm
decisions : Ids.Ids id -> Remote.Remote (List (Proposal id)) -> State -> Maybe (List (Decision id))
```

Complete, nonempty decisions, or `Nothing` for missing/invalid decisions,
duplicate ids or unavailable/stale/refreshing proposals. Rejections need a reason.

## Attributes

### `Attribute`

```elm
type Attribute id msg  -- opaque: no constructors are exposed
```

Review behaviour; no submit action or discussion by default.

### `onSubmit`

```elm
onSubmit : (List (Decision id) -> msg) -> Attribute id msg
```

Adds the explicit save action, receiving all decisions, including rejections.

### `saving`

```elm
saving : Bool -> Attribute id msg
```

Disables editing and submission during a server write. Defaults to `False`.

### `errorMaybe`

```elm
errorMaybe : Maybe String -> Attribute id msg
```

A failed server write. Keeps every local choice and note. Absent by default.

### `discussion`

```elm
discussion : (id -> String -> Html msg) -> Attribute id msg
```

Content beneath each proposal, receiving its application id and revision.
Use a separate CommentThread state for each pair. Absent by default.

### `onRetry`

```elm
onRetry : msg -> Attribute id msg
```

Retries initial load or refresh failures. Absent by default.

### `locale`

```elm
locale : Locale.Locale -> Attribute id msg
```

Language of built-in text. Defaults to English.

### `settings`

```elm
settings : Settings.Settings -> Attribute id msg
```

Timestamp formatting of retained data. Defaults to `Settings.default`.
