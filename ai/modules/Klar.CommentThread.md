# Klar.CommentThread

A reply thread with safe Markdown, exact timestamps and a draft that survives failed posting, refreshes and late acknowledgements.

Import: `import Klar.CommentThread as Thread` | Group: Text and change

Types: `Msg`, `State`, `Comment`, `Attribute`, `Submission`

## Signatures

```elm
view :
    (Msg -> msg)
    -> List (Attribute id msg)
    -> { label : String, ids : Ids.Ids id, comments : Remote.Remote (List (Comment id)) }
    -> State
    -> Html msg

-- Comments
type Comment id  -- opaque: no constructors are exposed
comment : { id : id, author : String, body : String, at : Time.Posix } -> Comment id
replyTo : id -> Comment id -> Comment id
edited : Time.Posix -> Comment id -> Comment id
removed : Comment id -> Comment id
resolved : Bool -> Comment id -> Comment id

-- Local state
type State  -- opaque: no constructors are exposed
type Msg  -- opaque: no constructors are exposed
init : String -> State
update : Msg -> State -> ( State, Cmd Msg )
draft : State -> String
setDraft : String -> State -> State
setReplyTo : Ids.Ids id -> Maybe id -> State -> State
reset : State -> State

-- Posting
type Submission id  -- opaque: no constructors are exposed
submission : Ids.Ids id -> State -> Maybe (Submission id)
submissionBody : Submission id -> String
submissionParent : Submission id -> Maybe id
acknowledge : Submission id -> State -> State

-- Attributes
type Attribute id msg  -- opaque: no constructors are exposed
onSubmit : (Submission id -> msg) -> Attribute id msg
sending : Bool -> Attribute id msg
errorMaybe : Maybe String -> Attribute id msg
maxLength : Int -> Attribute id msg
onResolve : (id -> Bool -> msg) -> Attribute id msg
actions : (id -> List (Html msg)) -> Attribute id msg
onLoadMore : msg -> Attribute id msg
onRetry : msg -> Attribute id msg
locale : Locale.Locale -> Attribute id msg
settings : Settings.Settings -> Attribute id msg
```

## Documentation

A reply thread with safe Markdown, exact timestamps and a draft that survives
failed posting, refreshes and late acknowledgements.

Use when: people discuss a case, order or document and need replies in context.
Do not use when: the content records immutable system changes; use `Klar.AuditLog`.
Quick path: `comment`, `init`, `update`, `view`, `acknowledge`

    import Klar.CommentThread as Thread

    -- model: { thread : Thread.State } -- Thread.init "order-discussion"
    -- update:
    ThreadMsg inner ->
        let
            ( thread, cmd ) =
                Thread.update inner model.thread
        in
        ( { model | thread = thread }, Cmd.map ThreadMsg cmd )

    -- view:
    Thread.view ThreadMsg [ Thread.onSubmit PostComment ]
        { label = "Order discussion", ids = commentIds, comments = model.comments }
        model.thread

`PostComment` receives an opaque `Submission`: send `submissionBody` and
`submissionParent` to your backend. On failure keep the draft and show `errorMaybe`.
On success append the server's comment and call `acknowledge sentSubmission`.
It clears only the exact draft that was sent. A person may keep writing while a
post is pending; a late answer never clears that newer work. Use `sending True`
to prevent a second post while the first is outstanding. The application owns
request tickets and permissions; this component never sends anything itself.

Comments arrive as a flat list. `replyTo` groups replies beneath their parents;
roots and siblings retain input order. Missing parents are labelled. Cycles and
duplicate ids are visibly reported and every record remains visible. Deep chains
stop indenting after three levels, keeping the reply context readable on narrow
screens. Supply unique ids in normal use. Markdown cannot load images or run HTML.
Removed comments keep their place and replies but their body is never rendered.
Markdown headings start at h3, fitting a discussion under a page or card's h2.

The optional composer stays mounted in every remote state. It keeps raw input,
including whitespace and text over the limit; invalid text is never truncated.
Posting needs nonblank, valid-length text and current data. A reply to a comment
that disappeared is blocked until the person changes its target. Plain Enter
always inserts a newline: only clicking Post submits. Mentions are ordinary text;
the library does not infer recipients or notify anyone.

Give each thread a unique `init` id. Use `reset` when switching to another record:
it invalidates outstanding draft acknowledgements. The root id is a stable focus
target for the application's retry/load-more handlers (`Klar.focus`).

### `view`

```elm
view :
    (Msg -> msg)
    -> List (Attribute id msg)
    -> { label : String, ids : Ids.Ids id, comments : Remote.Remote (List (Comment id)) }
    -> State
    -> Html msg
```

A named remote history and optional composer. The root id from `init` is
stable in every remote state. Replies and Markdown heading ids are scoped to it.

## Comments

### `Comment`

```elm
type Comment id  -- opaque: no constructors are exposed
```

A comment's content, context and moderation state. Build it with `comment`.

### `comment`

```elm
comment : { id : id, author : String, body : String, at : Time.Posix } -> Comment id
```

A top-level comment with exact source text and an instant. No text is parsed
or changed until it is rendered; raw HTML remains text.

### `replyTo`

```elm
replyTo : id -> Comment id -> Comment id
```

Marks a comment as a reply to an application id. Missing parents stay visible.

### `edited`

```elm
edited : Time.Posix -> Comment id -> Comment id
```

Shows when the comment was edited, without changing its creation time.

### `removed`

```elm
removed : Comment id -> Comment id
```

Hides a removed comment's body and keeps its identity and replies in place.
The author and timestamps remain; remove those upstream if they must be redacted.

### `resolved`

```elm
resolved : Bool -> Comment id -> Comment id
```

The application's resolved state. It adds a visible label and never hides replies.
False by default; `onResolve` asks the application to change it.

## Local state

### `State`

```elm
type State  -- opaque: no constructors are exposed
```

A raw draft, optional reply key and acknowledgement revision. No records or
functions are stored in the state.

### `Msg`

```elm
type Msg  -- opaque: no constructors are exposed
```

Internal draft, preview and focus interactions. Route through `update`.

### `init`

```elm
init : String -> State
```

An empty draft. The string is a DOM id unique on the page.

### `update`

```elm
update : Msg -> State -> ( State, Cmd Msg )
```

Updates the local draft or reply target. Reply controls move focus to the
composer; returning to a parent moves focus to that comment's stable article.

### `draft`

```elm
draft : State -> String
```

Exactly the draft text, including leading/trailing spaces and incomplete Markdown.

### `setDraft`

```elm
setDraft : String -> State -> State
```

Sets draft text explicitly and invalidates acknowledgements for an earlier draft.
Setting the same text leaves its revision alone.

### `setReplyTo`

```elm
setReplyTo : Ids.Ids id -> Maybe id -> State -> State
```

Sets or clears the reply target without changing the text or moving focus.
Changing the target invalidates an earlier submission's acknowledgement.

### `reset`

```elm
reset : State -> State
```

Clears the draft and target, preserving the DOM id and invalidating pending
acknowledgements. Use when beginning a different record's discussion.

## Posting

### `Submission`

```elm
type Submission id  -- opaque: no constructors are exposed
```

An immutable snapshot of the body, parent and draft revision that was posted.

### `submission`

```elm
submission : Ids.Ids id -> State -> Maybe (Submission id)
```

Captures a nonblank draft and decodes its parent with your ids. Returns
Nothing for blank text or an undecodable parent. This pure accessor does not check
the current catalogue, length limit or remote freshness; `view` checks those too.

### `submissionBody`

```elm
submissionBody : Submission id -> String
```

The exact submitted text. It is not trimmed or reformatted.

### `submissionParent`

```elm
submissionParent : Submission id -> Maybe id
```

The parent application id; Nothing means a top-level comment.

### `acknowledge`

```elm
acknowledge : Submission id -> State -> State
```

Clears a successfully posted draft only when its instance and revision still
match. If the person typed or changed target meanwhile, their newer draft survives.

## Attributes

### `Attribute`

```elm
type Attribute id msg  -- opaque: no constructors are exposed
```

Optional thread interactions. Reading is enabled by default; posting is opt-in.

### `onSubmit`

```elm
onSubmit : (Submission id -> msg) -> Attribute id msg
```

Adds the draft composer and explicit post button. Receives an exact snapshot;
the application sends it, updates comments and acknowledges success. Absent by default.

### `sending`

```elm
sending : Bool -> Attribute id msg
```

Marks a pending post and blocks another submit. The draft stays editable so
the next comment can be written while the current one is sent. False by default.

### `errorMaybe`

```elm
errorMaybe : Maybe String -> Attribute id msg
```

A posting error announced above the composer. The draft is kept for retry.
Nothing by default. This is separate from failures to load comment history.

### `maxLength`

```elm
maxLength : Int -> Attribute id msg
```

The draft limit, default 10,000 UTF-16 code units, matching native text controls.
Over-limit text remains editable and is shown with an error, never truncated.
Configuration below zero means zero.

### `onResolve`

```elm
onResolve : (id -> Bool -> msg) -> Attribute id msg
```

Adds Resolve/Reopen controls. Receives the comment id and requested new state;
the application supplies `resolved` data and handles permissions/persistence.
These controls are disabled while history is stale or refreshing.

### `actions`

```elm
actions : (id -> List (Html msg)) -> Attribute id msg
```

Additional per-comment actions, keyed by your own id. Empty by default.
Permission checks and edit/delete confirmation belong to the application.

### `onLoadMore`

```elm
onLoadMore : msg -> Attribute id msg
```

Adds a load-more action, including when no comments are loaded. Append the
response and focus the thread root in its handler if the button will disappear.

### `onRetry`

```elm
onRetry : msg -> Attribute id msg
```

Retry for loading failures and stale history. Absent by default.

### `locale`

```elm
locale : Locale.Locale -> Attribute id msg
```

Built-in text language. Defaults to English.

### `settings`

```elm
settings : Settings.Settings -> Attribute id msg
```

Time zone for creation/edit times and retained-data notices. Defaults to UTC.
