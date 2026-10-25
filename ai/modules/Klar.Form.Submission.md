# Klar.Form.Submission

A transport-neutral save lifecycle, shared by declared and hand-wired forms.

Import: `import Klar.Form.Submission as Submission` | Group: Forms

Types: `Msg`, `Error`, `State`, `Ticket`, `Problem`

## Signatures

```elm
-- Display
view : List (Form.Layout.Attribute msg) -> State -> Html msg

-- State
type State  -- opaque: no constructors are exposed
type Msg  -- opaque: no constructors are exposed
type Ticket  -- opaque: no constructors are exposed
type Error = Rejected (List Problem) | Failed Remote.Problem
type alias Problem = { field : String, message : String }
init : String -> State
update : Msg -> State -> ( State, Cmd Msg )

-- Requests
begin :
    Result (List Problem) values
    -> State
    -> { state : State, cmd : Cmd Msg, request : Maybe { ticket : Ticket, values : values } }
finish : Ticket -> Result Error String -> State -> ( State, Cmd Msg )
edited : String -> State -> State
reset : State -> State
status : State -> Form.Layout.Status
problems : State -> List Problem
```

## Documentation

A transport-neutral save lifecycle, shared by declared and hand-wired forms.

Use when: a hand-wired form needs a save lifecycle, or you draw the submission status kept inside a declared form.
Do not use when: you are loading records (use `Klar.Remote`), or adding a second state to a declared form (use `Klar.Form.submit`, `finish` and `submission`).
Quick path: `init`, `begin`, send the returned request, `finish`, `view`.

    import Klar.Form.Layout as FormLayout

    type alias Model =
        { draft : String, submission : Submission.State }

    type Msg
        = Save
        | SubmissionMsg Submission.Msg
        | Replied Submission.Ticket (Result Submission.Error String)

    initial : Model
    initial =
        { draft = "", submission = Submission.init "order-form" }

    -- In your Save branch:
    save : Model -> ( Model, Cmd Msg )
    save model =
        let
            attempt =
                Submission.begin (Ok model.draft) model.submission
        in
        ( { model | submission = attempt.state }
        , Cmd.batch
            [ Cmd.map SubmissionMsg attempt.cmd
            , attempt.request |> Maybe.map (\request -> send request.ticket request.values) |> Maybe.withDefault Cmd.none
            ]
        )

    update : Msg -> Model -> ( Model, Cmd Msg )
    update msg model =
        case msg of
            Save ->
                save model

            SubmissionMsg inner ->
                Submission.update inner model.submission
                    |> Tuple.mapBoth (\state -> { model | submission = state }) (Cmd.map SubmissionMsg)

            Replied ticket result ->
                Submission.finish ticket result model.submission
                    |> Tuple.mapBoth (\state -> { model | submission = state }) (Cmd.map SubmissionMsg)

    -- The application supplies its transport here:
    send : Submission.Ticket -> String -> Cmd Msg
    send _ _ =
        Cmd.none

    -- In the view, keep this region even when idle:
    viewStatus : Model -> Html.Html Msg
    viewStatus model =
        Submission.view [ FormLayout.onRetry Save ] model.submission

`SubmissionMsg` wraps `Msg`, and `send` is the application's request function.
`Error` is a closed distinction between field rejection and request failure;
additional server error kinds belong in `Remote.Problem`, not more constructors.

Tickets reject duplicate and older replies within a state. Keep the state when
starting another attempt. The application must also correlate replies with the
record or editor session when it replaces that state with a new `init`.

## Display

### `view`

```elm
view : List (Form.Layout.Attribute msg) -> State -> Html msg
```

A stable status region using `Form.Layout`'s locale and retry attributes.
Its id comes from `init`; the caller supplies `Form.Layout.onRetry` to request
another attempt. Keep this region in the view even while idle.

## State

### `State`

```elm
type State  -- opaque: no constructors are exposed
```

Save state. It holds no field values or functions. Initially idle.

### `Msg`

```elm
type Msg  -- opaque: no constructors are exposed
```

Internal focus acknowledgement. Wrap it in your application's message type.

### `Ticket`

```elm
type Ticket  -- opaque: no constructors are exposed
```

An attempt's identity. Return it unchanged with the server response.

### `Error`

```elm
type Error = Rejected (List Problem) | Failed Remote.Problem
```

A server rejection with field problems, or a request failure such as a timeout.
An unrecognized field must remain visible in the form's error summary.

### `Problem`

```elm
type alias Problem = { field : String, message : String }
```

A server field key and its message. An empty field identifies a form-wide problem.

### `init`

```elm
init : String -> State
```

Starts idle. The string is the form's DOM id, also used by its summary and status region.

### `update`

```elm
update : Msg -> State -> ( State, Cmd Msg )
```

Handles focus acknowledgements; does not change values or issue requests.

## Requests

### `begin`

```elm
begin :
    Result (List Problem) values
    -> State
    -> { state : State, cmd : Cmd Msg, request : Maybe { ticket : Ticket, values : values } }
```

Validates an attempt and returns at most one request with its ticket and values.
While submitting, returns no request. Invalid input focuses the summary; retrying
a failed request focuses the stable status region before its button disappears.
The caller sends the request and maps `cmd` through its message constructor.

### `finish`

```elm
finish : Ticket -> Result Error String -> State -> ( State, Cmd Msg )
```

Settles the matching pending request. `Ok` carries the success text to show.
Field rejections focus the summary; request failures keep the draft available for
retry. Duplicate, older and non-pending replies leave the state untouched.

### `edited`

```elm
edited : String -> State -> State
```

Clears only this field's problems after its value changes, preserving all others.
Does nothing while a request is pending. Opening a picker is not a value change.

### `reset`

```elm
reset : State -> State
```

Clears status and problems and invalidates any outstanding reply without
reusing tickets. Use for an explicit discard or when loading another record.

### `status`

```elm
status : State -> Form.Layout.Status
```

Current presentation status, initially `Form.Layout.Idle`.
Compare with `Form.Layout.Submitting` for read-only controls and `aria-busy`.

### `problems`

```elm
problems : State -> List Problem
```

Validation or server field problems, initially empty. Unknown keys are retained.
