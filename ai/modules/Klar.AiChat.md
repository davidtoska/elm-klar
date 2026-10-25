# Klar.AiChat

A transport-neutral AI conversation with safe Markdown, streamed answers, explicit generation status and a composer that preserves newer drafts.

Import: `import Klar.AiChat as Chat` | Group: AI

Types: `Msg`, `Role`, `State`, `Status`, `Message`, `Attribute`, `Submission`

## Signatures

```elm
view :
    (Msg -> msg)
    -> List (Attribute id msg)
    -> { label : String, ids : Ids.Ids id, messages : Remote.Remote (List (Message id)), status : Status }
    -> State
    -> Html msg

-- Conversation
type Message id  -- opaque: no constructors are exposed
type Role = User | Assistant | Tool
type Status = Idle | Generating | Interrupted | Failed String
message : { id : id, role : Role, author : String, body : String } -> Message id

-- Composer
type State  -- opaque: no constructors are exposed
type Msg  -- opaque: no constructors are exposed
init : String -> State
update : Msg -> State -> ( State, Cmd Msg )
draft : State -> String
setDraft : String -> State -> State
reset : State -> State

-- Server acknowledgement
type Submission  -- opaque: no constructors are exposed
submissionText : Submission -> String
acknowledge : Submission -> State -> State

-- Attributes
type Attribute id msg  -- opaque: no constructors are exposed
onSend : (Submission -> msg) -> Attribute id msg
onStop : msg -> Attribute id msg
onRetry : msg -> Attribute id msg
maxLength : Int -> Attribute id msg
content : (id -> Html msg) -> Attribute id msg
locale : Locale.Locale -> Attribute id msg
settings : Settings.Settings -> Attribute id msg
```

## Documentation

A transport-neutral AI conversation with safe Markdown, streamed answers,
explicit generation status and a composer that preserves newer drafts.

Use when: an application talks to AI on its own server and needs a conversation UI.
Do not use when: discussing an ordinary record; use `Klar.CommentThread`.
Quick path: `message`, `init`, `update`, `view`, `onSend`, `acknowledge`

    import Klar.AiChat as Chat

    -- model: { chat : Chat.State } -- Chat.init "assistant"
    -- update:
    ChatMsg inner ->
        let
            ( chat, cmd ) =
                Chat.update inner model.chat
        in
        ( { model | chat = chat }, Cmd.map ChatMsg cmd )

    -- view:
    Chat.view ChatMsg [ Chat.onSend SendPrompt, Chat.onStop StopGeneration ]
        { label = "Operations assistant", ids = messageIds, messages = model.messages, status = model.status }
        model.chat

Send `submissionText` to your application server. Keep provider keys, tool execution,
authorization and retrieval on the server. Set `Generating` while awaiting/streaming
a response. Append chunks to the same assistant message id. Acknowledge the captured
submission only when the server accepts the prompt; a newer draft survives a late
acknowledgement. Failed requests preserve the draft. Keep request tickets in the
application and discard chunks/completions from stopped or replaced runs.

Stop is an explicit request to the application, which cancels the transport and sets
`Interrupted`; partial text stays visible. `Failed` also retains the conversation.
Retry reissues the failed generation, rather than posting the draft again. Do not
persist `Generating` indefinitely after a connection loss. `reset` invalidates draft
acknowledgements when switching conversations. Send is blocked during generation,
unavailable/stale/refreshing history, blank or over-limit input, and duplicate ids.

Enter inserts a newline; only the Send button submits. No automatic scrolling steals
the reader's place. Streamed text is not a live region; only concise status changes
are announced. Tool messages are plain reported results, never executable commands.
Embed proposal review, tables or JSON through `content`. Markdown cannot run HTML or
load images; truncated Markdown is visibly marked by the renderer.

### `view`

```elm
view :
    (Msg -> msg)
    -> List (Attribute id msg)
    -> { label : String, ids : Ids.Ids id, messages : Remote.Remote (List (Message id)), status : Status }
    -> State
    -> Html msg
```

Conversation history, stable stream status and optional composer. The root
remains a focus target while history loads or fails. Message ids must be unique.

## Conversation

### `Message`

```elm
type Message id  -- opaque: no constructors are exposed
```

A stable application id, role, display name and raw Markdown body.

### `Role`

```elm
type Role = User | Assistant | Tool
```

Who produced a message. Tool results are display data and execute nothing.

### `Status`

```elm
type Status = Idle | Generating | Interrupted | Failed String
```

State of the server generation, independent of loading conversation history.
Interrupted and failed generations keep all partial messages visible.

### `message`

```elm
message : { id : id, role : Role, author : String, body : String } -> Message id
```

Creates a message. During streaming replace its body, keeping its id stable.

## Composer

### `State`

```elm
type State  -- opaque: no constructors are exposed
```

A raw composer and monotonically increasing acknowledgement revision.

### `Msg`

```elm
type Msg  -- opaque: no constructors are exposed
```

Internal text input. Route through `update`.

### `init`

```elm
init : String -> State
```

Empty composer. The string is a unique DOM id for this conversation.

### `update`

```elm
update : Msg -> State -> ( State, Cmd Msg )
```

Preserves exactly the input text. No commands are needed.

### `draft`

```elm
draft : State -> String
```

Raw draft including spaces and incomplete Markdown.

### `setDraft`

```elm
setDraft : String -> State -> State
```

Sets raw text, invalidating earlier acknowledgements only when it changes.

### `reset`

```elm
reset : State -> State
```

Clears the composer and invalidates outstanding acknowledgements. Use when
switching conversations, even when the new conversation has the same draft.

## Server acknowledgement

### `Submission`

```elm
type Submission  -- opaque: no constructors are exposed
```

Exact submitted draft, bound to its composer and editing revision.

### `submissionText`

```elm
submissionText : Submission -> String
```

Exact prompt text to send to your own server.

### `acknowledge`

```elm
acknowledge : Submission -> State -> State
```

Clears only the accepted draft. Late responses never erase newer writing.

## Attributes

### `Attribute`

```elm
type Attribute id msg  -- opaque: no constructors are exposed
```

Optional actions and embedded structured message content.

### `onSend`

```elm
onSend : (Submission -> msg) -> Attribute id msg
```

Adds the composer and an explicit Send button. Receives an immutable draft.

### `onStop`

```elm
onStop : msg -> Attribute id msg
```

Requests that the application cancel the active server run. Absent by default.

### `onRetry`

```elm
onRetry : msg -> Attribute id msg
```

Retry action for failed history or a failed/interrupted generation.
The application decides which request to repeat. Absent by default.

### `maxLength`

```elm
maxLength : Int -> Attribute id msg
```

Maximum prompt length, at least one character. Defaults to 8000.
Over-limit input remains visible and is never truncated.

### `content`

```elm
content : (id -> Html msg) -> Attribute id msg
```

Structured content beneath a message, receiving its application id. Embed
AiReview, tables, charts or JsonViewer here. Absent by default.

### `locale`

```elm
locale : Locale.Locale -> Attribute id msg
```

Language of built-in text. Defaults to English.

### `settings`

```elm
settings : Settings.Settings -> Attribute id msg
```

Retained-data timestamp formatting. Defaults to `Settings.default`.
