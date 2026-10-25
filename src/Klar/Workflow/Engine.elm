module Klar.Workflow.Engine exposing (Run, Status(..), Attempt, start, complete, choose, fail, retry, pause, resume, cancel, available, current)

{-| Pure, deterministic execution state for an ordered workflow.

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

@docs Run, Status, Attempt, start, complete, choose, fail, retry, pause, resume, cancel, available, current

-}

import Dict exposing (Dict)
import Json.Decode as Decode
import Json.Encode as Encode exposing (Value)
import Klar.Workflow as Workflow exposing (Definition, Edge, Node)


{-| Closed execution states. A paused run retains its previous phase internally.
-}
type Status
    = Running
    | AwaitingInput
    | Waiting
    | Paused
    | Succeeded
    | Failed
    | Cancelled


{-| Immutable record of an attempt's output, decision or failure. Newest is last.
-}
type alias Attempt id =
    { node : id, number : Int, outcome : String, result : Value, actor : Maybe String }


{-| A run's snapshot, current context, attempt history and edge traversal counts.
Use the transition functions to mutate it so invariants remain consistent.
-}
type alias Run id =
    { id : String
    , startedBy : String
    , definition : Definition id
    , active : Maybe id
    , status : Status
    , previousStatus : Status
    , context : Dict String Value
    , nodeStates : List { node : id, config : Value, output : Maybe Value }
    , attempts : List (Attempt id)
    , traversals : List { from : id, label : String, count : Int }
    , error : Maybe String
    , revision : Int
    }


{-| Validate and snapshot a definition. Initial context is supplied by the person
starting the process and may contain uploaded asset references.
-}
start : String -> Definition id -> Dict String Value -> Result (List (Workflow.Issue id)) (Run id)
start id definition context =
    case Workflow.validate definition of
        [] ->
            Ok { id = id, startedBy = "", definition = definition, active = List.head definition.nodes |> Maybe.map .id, status = Running, previousStatus = Running, context = context, nodeStates = List.map (\n -> { node = n.id, config = Decode.decodeString Decode.value n.state |> Result.withDefault Encode.null, output = Nothing }) definition.nodes, attempts = [], traversals = [], error = Nothing, revision = 0 }

        issues ->
            Err issues


{-| The active node of the run's frozen definition.
-}
current : Run id -> Maybe (Node id)
current run =
    run.active |> Maybe.andThen (\id -> Workflow.find id run.definition)


phase : Node id -> Status
phase n =
    if n.kind == Workflow.human || n.kind == Workflow.task || n.kind == Workflow.decision then
        AwaitingInput

    else if n.kind == Workflow.wait then
        Waiting

    else
        Running


{-| Exits whose individual traversal budgets are not exhausted.
-}
available : Run id -> List (Edge id)
available run =
    let
        count e =
            List.filter (\t -> t.from == e.from && t.label == e.label) run.traversals |> List.head |> Maybe.map .count |> Maybe.withDefault 0
    in
    run.active |> Maybe.map (\id -> Workflow.outgoing id run.definition |> List.filter (\e -> Maybe.withDefault True (Maybe.map (\limit -> count e < limit) e.maxVisits))) |> Maybe.withDefault []


record : String -> Value -> Run id -> Run id
record outcome result run =
    case run.active of
        Nothing ->
            run

        Just id ->
            { run | attempts = run.attempts ++ [ { node = id, number = 1 + List.length (List.filter (\a -> a.node == id) run.attempts), outcome = outcome, result = result, actor = Nothing } ], revision = run.revision + 1 }


missingInput : Run id -> Maybe String
missingInput run =
    current run
        |> Maybe.andThen
            (\n ->
                if n.inputKey /= "" && not (Dict.member n.inputKey run.context) then
                    Just n.inputKey

                else
                    Nothing
            )


enter : Node id -> Run id -> Run id
enter n run =
    let
        next =
            { run | status = phase n, error = Nothing }
    in
    case missingInput next of
        Just key ->
            { next | status = Failed, error = Just ("Missing input: " ++ key) }

        Nothing ->
            if n.kind /= Workflow.output && List.isEmpty (available next) then
                { next | status = Failed, error = Just "No available transition. The traversal budget is exhausted." }

            else
                next


follow : Edge id -> Run id -> Run id
follow e run =
    let
        oldCount =
            List.filter (\t -> t.from == e.from && t.label == e.label) run.traversals |> List.head |> Maybe.map .count |> Maybe.withDefault 0

        index id =
            run.definition.nodes |> List.indexedMap Tuple.pair |> List.filter (Tuple.second >> .id >> (==) id) |> List.head |> Maybe.map Tuple.first |> Maybe.withDefault 0

        -- A return invalidates downstream outputs, not their audit history.
        invalidated =
            if index e.to <= index e.from then
                List.drop (index e.to) run.definition.nodes

            else
                []

        outputKeys =
            List.map .outputKey invalidated |> List.filter ((/=) "")

        next =
            { run
                | active = Just e.to
                , context = List.foldl Dict.remove run.context outputKeys
                , nodeStates =
                    List.map
                        (\s ->
                            if List.any (\n -> n.id == s.node) invalidated then
                                { s | output = Nothing }

                            else
                                s
                        )
                        run.nodeStates
                , traversals = List.filter (\t -> not (t.from == e.from && t.label == e.label)) run.traversals ++ [ { from = e.from, label = e.label, count = oldCount + 1 } ]
            }
    in
    case Workflow.find e.to run.definition of
        Just n ->
            enter n next

        Nothing ->
            { next | status = Failed, error = Just "Transition destination not found." }


{-| Accept one worker result while running/waiting. Named input must exist.
Multiple exits are left for an explicit `choose`, never silently selected.
-}
complete : Value -> Run id -> Run id
complete result run =
    if run.status /= Running && run.status /= Waiting then
        run

    else
        case current run of
            Nothing ->
                run

            Just n ->
                if n.inputKey /= "" && not (Dict.member n.inputKey run.context) then
                    fail ("Missing input: " ++ n.inputKey) run

                else
                    let
                        recorded =
                            record "completed" result run

                        settled =
                            { recorded
                                | nodeStates =
                                    List.map
                                        (\s ->
                                            if s.node == n.id then
                                                { s | output = Just result }

                                            else
                                                s
                                        )
                                        run.nodeStates
                                , context =
                                    if n.outputKey == "" then
                                        run.context

                                    else
                                        Dict.insert n.outputKey result run.context
                            }
                    in
                    if n.kind == Workflow.output then
                        { settled | status = Succeeded, active = Nothing }

                    else
                        case available settled of
                            [ next ] ->
                                follow next settled

                            [] ->
                                { settled | status = Failed, error = Just "No available transition. The traversal budget is exhausted." }

                            _ ->
                                { settled | status = AwaitingInput }


{-| Choose an available labelled branch, attaching feedback to the context.
Invalid labels, exhausted loops and decisions outside a review phase are ignored.
-}
choose : String -> String -> Run id -> Run id
choose label feedback run =
    if run.status /= AwaitingInput then
        run

    else if missingInput run /= Nothing then
        fail ("Missing input: " ++ (missingInput run |> Maybe.withDefault "")) run

    else
        case List.filter (\e -> e.label == label) (available run) |> List.head of
            Nothing ->
                run

            Just next ->
                let
                    result =
                        Encode.object [ ( "decision", Encode.string label ), ( "feedback", Encode.string feedback ) ]

                    recorded =
                        record label result run

                    binding =
                        current run
                            |> Maybe.map
                                (\n ->
                                    if List.member n.kind [ Workflow.human, Workflow.task, Workflow.decision ] then
                                        n.outputKey

                                    else
                                        ""
                                )
                            |> Maybe.withDefault ""

                    context =
                        Dict.insert "feedback" (Encode.string feedback) run.context
                in
                follow next
                    { recorded
                        | context =
                            if binding == "" then
                                context

                            else
                                Dict.insert binding result context
                        , nodeStates =
                            List.map
                                (\s ->
                                    if Just s.node == run.active && (current run |> Maybe.map (\n -> List.member n.kind [ Workflow.human, Workflow.task, Workflow.decision ]) |> Maybe.withDefault False) then
                                        { s | output = Just result }

                                    else
                                        s
                                )
                                run.nodeStates
                    }


{-| Record a step failure. Only live execution phases accept it.
-}
fail : String -> Run id -> Run id
fail message run =
    if List.member run.status [ Running, Waiting, AwaitingInput ] then
        let
            recorded =
                record "failed" (Encode.string message) run
        in
        { recorded | status = Failed, error = Just message }

    else
        run


{-| Retry a failed node with retained context and complete attempt history.
An exhausted transition budget cannot be reset by retrying.
-}
retry : Run id -> Run id
retry run =
    if run.status == Failed then
        case current run of
            Just n ->
                enter n { run | revision = run.revision + 1 }

            Nothing ->
                run

    else
        run


{-| Pause an active run. The server must invalidate outstanding worker tickets.
-}
pause : Run id -> Run id
pause run =
    if List.member run.status [ Running, Waiting, AwaitingInput ] then
        { run | previousStatus = run.status, status = Paused, revision = run.revision + 1 }

    else
        run


{-| Restore the phase that was paused.
-}
resume : Run id -> Run id
resume run =
    if run.status == Paused then
        { run | status = run.previousStatus, revision = run.revision + 1 }

    else
        run


{-| Cancel an unfinished run; late replies cannot complete it.
-}
cancel : Run id -> Run id
cancel run =
    if List.member run.status [ Succeeded, Cancelled ] then
        run

    else
        { run | status = Cancelled, revision = run.revision + 1 }
