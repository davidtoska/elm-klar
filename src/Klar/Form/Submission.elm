module Klar.Form.Submission exposing
    ( State, Msg, Ticket, Error(..), Problem, init, update
    , begin, finish, edited, reset, status, problems
    , view
    )

{-| A transport-neutral save lifecycle, shared by declared and hand-wired forms.

Use when: a hand-wired form needs validation, one request at a time, server field errors and retry focus.
Do not use when: the form uses `Klar.Form` (use its `submit`, `finish` and `submission`), or you are loading records (use `Klar.Remote`).
Quick path: `init`, `begin`, send the returned request, `finish`, `view`.


    save =
        Submission.begin (Ok draft) model.submission

    -- Keep save.state and map save.cmd through your SubmissionMsg constructor.
    -- Send only save.request, carrying its ticket into the server reply.
    -- Submission.finish ticket (Ok "Saved.") model.submission acknowledges it.

Tickets reject duplicate and older replies within a state. Keep the state when
starting another attempt. The application must also correlate replies with the
record or editor session when it replaces that state with a new `init`.


# State

@docs State, Msg, Ticket, Error, Problem, init, update


# Requests

@docs begin, finish, edited, reset, status, problems


# Display

@docs view

-}

import Html exposing (Html)
import Klar.Form.Layout as Layout
import Klar.Remote as Remote


{-| Save state. It holds no field values or functions. Initially idle.
-}
type State
    = State
        { id : String
        , serial : Int
        , pending : Maybe Ticket
        , status : Layout.Status
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
    State { id = id, serial = 0, pending = Nothing, status = Layout.Idle, problems = [] }


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
                { state = State { state | status = Layout.Idle, problems = found }
                , cmd = Layout.focusSummary state.id NoOp
                , request = Nothing
                }

            Ok values ->
                let
                    ticket =
                        Ticket state.id (state.serial + 1)
                in
                { state = State { state | serial = state.serial + 1, pending = Just ticket, status = Layout.Submitting, problems = [] }
                , cmd =
                    case state.status of
                        Layout.Failed _ ->
                            Layout.focusStatus state.id NoOp

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
                ( State { state | pending = Nothing, status = Layout.Succeeded message, problems = [] }, Cmd.none )

            Err (Failed problem) ->
                ( State { state | pending = Nothing, status = Layout.Failed problem, problems = [] }, Cmd.none )

            Err (Rejected found) ->
                ( State { state | pending = Nothing, status = Layout.Idle, problems = found }, Layout.focusSummary state.id NoOp )


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
    State { state | pending = Nothing, status = Layout.Idle, problems = [] }


{-| Current presentation status, initially `Form.Layout.Idle`.
Compare with `Form.Layout.Submitting` for read-only controls and `aria-busy`.
-}
status : State -> Layout.Status
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
view : List (Layout.Attribute msg) -> State -> Html msg
view attributes (State state) =
    Layout.status (attributes ++ [ Layout.id state.id ]) state.status
