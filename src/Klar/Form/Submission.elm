module Klar.Form.Submission exposing
    ( view
    , State, Msg, Ticket, Error(..), Problem, init, update
    , begin, finish, edited, reset, status, problems
    )

{-| A transport-neutral save lifecycle, shared by declared and hand-wired forms.

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


# Display

@docs view


# State

@docs State, Msg, Ticket, Error, Problem, init, update


# Requests

@docs begin, finish, edited, reset, status, problems

-}

import Html exposing (Html)
import Klar.Form.Layout as FormLayout
import Klar.Remote as Remote


{-| Save state. It holds no field values or functions. Initially idle.
-}
type State
    = State
        { id : String
        , serial : Int
        , pending : Maybe Ticket
        , status : FormLayout.Status
        , problems : List Problem
        }


{-| Internal focus acknowledgement. Wrap it in your application's message type.
-}
type Msg
    = NoOp


{-| An attempt's identity. Return it unchanged with the server response.
-}
type Ticket
    = Ticket String Int


{-| A server rejection with field problems, or a request failure such as a timeout.
An unrecognized field must remain visible in the form's error summary.
-}
type Error
    = Rejected (List Problem)
    | Failed Remote.Problem


{-| A server field key and its message. An empty field identifies a form-wide problem.
-}
type alias Problem =
    { field : String, message : String }


{-| Starts idle. The string is the form's DOM id, also used by its summary and status region.
-}
init : String -> State
init id =
    State { id = id, serial = 0, pending = Nothing, status = FormLayout.Idle, problems = [] }


{-| Handles focus acknowledgements; does not change values or issue requests.
-}
update : Msg -> State -> ( State, Cmd Msg )
update _ state =
    ( state, Cmd.none )


{-| Validates an attempt and returns at most one request with its ticket and values.
While submitting, returns no request. Invalid input focuses the summary; retrying
a failed request focuses the stable status region before its button disappears.
The caller sends the request and maps `cmd` through its message constructor.
-}
begin : Result (List Problem) values -> State -> { state : State, cmd : Cmd Msg, request : Maybe { ticket : Ticket, values : values } }
begin validation ((State state) as current) =
    if state.pending /= Nothing then
        { state = current, cmd = Cmd.none, request = Nothing }

    else
        case validation of
            Err found ->
                { state = State { state | status = FormLayout.Idle, problems = found }
                , cmd = FormLayout.focusSummary state.id NoOp
                , request = Nothing
                }

            Ok values ->
                let
                    ticket =
                        Ticket state.id (state.serial + 1)
                in
                { state = State { state | serial = state.serial + 1, pending = Just ticket, status = FormLayout.Submitting, problems = [] }
                , cmd =
                    case state.status of
                        FormLayout.Failed _ ->
                            FormLayout.focusStatus state.id NoOp

                        _ ->
                            Cmd.none
                , request = Just { ticket = ticket, values = values }
                }


{-| Settles the matching pending request. `Ok` carries the success text to show.
Field rejections focus the summary; request failures keep the draft available for
retry. Duplicate, older and non-pending replies leave the state untouched.
-}
finish : Ticket -> Result Error String -> State -> ( State, Cmd Msg )
finish ticket result ((State state) as current) =
    if state.pending /= Just ticket then
        ( current, Cmd.none )

    else
        case result of
            Ok message ->
                ( State { state | pending = Nothing, status = FormLayout.Succeeded message, problems = [] }, Cmd.none )

            Err (Failed problem) ->
                ( State { state | pending = Nothing, status = FormLayout.Failed problem, problems = [] }, Cmd.none )

            Err (Rejected found) ->
                ( State { state | pending = Nothing, status = FormLayout.Idle, problems = found }, FormLayout.focusSummary state.id NoOp )


{-| Clears only this field's problems after its value changes, preserving all others.
Does nothing while a request is pending. Opening a picker is not a value change.
-}
edited : String -> State -> State
edited field ((State state) as current) =
    if state.pending /= Nothing then
        current

    else
        State { state | problems = List.filter (\problem -> problem.field /= field) state.problems }


{-| Clears status and problems and invalidates any outstanding reply without
reusing tickets. Use for an explicit discard or when loading another record.
-}
reset : State -> State
reset (State state) =
    State { state | pending = Nothing, status = FormLayout.Idle, problems = [] }


{-| Current presentation status, initially `Form.Layout.Idle`.
Compare with `Form.Layout.Submitting` for read-only controls and `aria-busy`.
-}
status : State -> FormLayout.Status
status (State state) =
    state.status


{-| Validation or server field problems, initially empty. Unknown keys are retained.
-}
problems : State -> List Problem
problems (State state) =
    state.problems


{-| A stable status region using `Form.Layout`'s locale and retry attributes.
Its id comes from `init`; the caller supplies `Form.Layout.onRetry` to request
another attempt. Keep this region in the view even while idle.
-}
view : List (FormLayout.Attribute msg) -> State -> Html msg
view attributes (State state) =
    FormLayout.status (attributes ++ [ FormLayout.id state.id ]) state.status
