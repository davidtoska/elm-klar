module WorkflowTest exposing (suite)

import Dict
import Expect
import Fuzz
import Html
import Html.Attributes as Attr
import Json.Decode as Decode
import Json.Encode as Encode
import Klar.Ids as Ids
import Klar.Locale as Locale
import Klar.Remote as Remote
import Klar.StateMachine as Machine
import Klar.Workflow as W
import Klar.Workflow.Codec as Codec
import Klar.Workflow.Engine as E exposing (Status(..))
import Klar.WorkflowBuilder as Builder
import Klar.WorkflowNode as Node
import Klar.WorkflowRun as Runner
import Test exposing (Test, describe, fuzz, test)
import Test.Html.Event as Event
import Test.Html.Query as Query
import Test.Html.Selector as S


definition : W.Definition String
definition =
    let
        ai =
            W.node "ai" W.ai "Draw"
    in
    { ownerRole = "designer"
    , title = "Studio"
    , nodes = [ W.node "start" W.input "Brief", { ai | inputKey = "brief", outputKey = "sheet", state = "{\"count\":12}" }, W.node "review" W.human "Review", W.node "wait" W.wait "Package", W.node "end" W.output "Deliver" ]
    , edges = [ W.edge "start" "ai" "Go", W.edge "ai" "review" "Inspect", W.edge "review" "wait" "Approve", W.loop 2 "review" "ai" "Revise", W.edge "wait" "end" "Done" ]
    }


started : Result (List (W.Issue String)) (E.Run String)
started =
    E.start "r1" definition (Dict.singleton "brief" (Encode.string "Explorer"))


withRun : (E.Run String -> Expect.Expectation) -> Expect.Expectation
withRun assertion =
    case started of
        Ok run ->
            assertion run

        Err _ ->
            Expect.fail "The valid fixture must start."


review : E.Run String -> E.Run String
review =
    E.complete Encode.null >> E.complete (Encode.string "sheet-v1")


change : (W.Definition String -> W.Definition String) -> Bool
change transform =
    not (List.isEmpty (W.validate (transform definition)))


machine : Machine.Machine String
machine =
    { states = [ { id = "ready", label = "Ready", terminal = False }, { id = "done", label = "Done", terminal = True } ], transitions = [ { from = "ready", to = "done", event = "Finish" } ], current = "ready" }


suite : Test
suite =
    describe "Workflow universe"
        [ describe "Definition validation"
            [ test "accepts explicit bounded returns" <| \_ -> Expect.equal 0 (List.length (W.validate definition))
            , test "rejects no start" <| \_ -> Expect.equal True (change (\d -> { d | nodes = List.drop 1 d.nodes }))
            , test "rejects a second input" <| \_ -> Expect.equal True (change (\d -> { d | nodes = d.nodes ++ [ W.node "extra" W.input "Extra" ] }))
            , test "rejects duplicate identifiers" <| \_ -> Expect.equal True (change (\d -> { d | nodes = d.nodes ++ List.take 1 d.nodes }))
            , test "rejects dangling destinations" <| \_ -> Expect.equal True (change (\d -> { d | edges = d.edges ++ [ W.edge "ai" "missing" "Missing" ] }))
            , test "rejects unreachable nodes" <| \_ -> Expect.equal True (change (\d -> { d | nodes = d.nodes ++ [ W.node "orphan" W.output "Orphan" ] }))
            , test "rejects unbounded backward edges" <| \_ -> Expect.equal True (change (\d -> { d | edges = List.map (\e -> { e | maxVisits = Nothing }) d.edges }))
            , test "rejects zero budgets" <| \_ -> Expect.equal True (change (\d -> { d | edges = d.edges ++ [ W.loop 0 "review" "ai" "Invalid" ] }))
            , test "rejects duplicate exit labels" <| \_ -> Expect.equal True (change (\d -> { d | edges = d.edges ++ [ W.edge "review" "end" "Approve" ] }))
            , test "rejects nonterminal sinks" <| \_ -> Expect.equal True (change (\d -> { d | edges = List.filter (\e -> e.from /= "ai") d.edges }))
            , test "rejects exits from outputs" <| \_ -> Expect.equal True (change (\d -> { d | edges = d.edges ++ [ W.loop 1 "end" "ai" "Bad" ] }))
            , test "rejects malformed state without repairing it" <| \_ -> Expect.equal True (change (\d -> { d | nodes = List.map (\n -> { n | state = "{unfinished" }) d.nodes }))
            , test "requires state objects" <| \_ -> Expect.equal True (change (\d -> { d | nodes = List.map (\n -> { n | state = "[]" }) d.nodes }))
            , test "rejects AI without named output" <| \_ -> Expect.equal True (change (\d -> { d | nodes = List.map (\n -> { n | outputKey = "" }) d.nodes }))
            , test "localizes validation errors" <|
                \_ ->
                    let
                        empty =
                            { ownerRole = "designer", title = "Empty", nodes = [], edges = [] }
                    in
                    W.validate empty |> List.map (W.issueText Locale.nb empty) |> String.join " " |> String.contains "menneskelig" |> Expect.equal True
            ]
        , describe "Review regressions"
            [ test "node outputs cannot overwrite the engine's feedback binding" <|
                \_ ->
                    Expect.equal True
                        (change
                            (\d ->
                                { d
                                    | nodes =
                                        List.map
                                            (\n ->
                                                if n.id == "ai" then
                                                    { n | outputKey = "feedback" }

                                                else
                                                    n
                                            )
                                            d.nodes
                                }
                            )
                        )
            , test "initial input cannot be silently reused by a return" <| \_ -> Expect.equal True (change (\d -> { d | edges = d.edges ++ [ W.loop 1 "review" "start" "New application" ] }))
            , test "manual input bindings are checked before a person can act" <|
                \_ ->
                    let
                        d =
                            { definition
                                | nodes =
                                    List.map
                                        (\n ->
                                            if n.id == "review" then
                                                { n | inputKey = "missing_evidence" }

                                            else
                                                n
                                        )
                                        definition.nodes
                            }
                    in
                    E.start "missing" d (Dict.singleton "brief" Encode.null) |> Result.map (review >> E.choose "Approve" "" >> (\r -> ( r.status, r.active ))) |> Expect.equal (Ok ( Failed, Just "review" ))
            , test "return clears obsolete output bindings but retains audit history" <|
                \_ ->
                    withRun
                        (\run ->
                            let
                                revised =
                                    review run |> E.choose "Revise" "new feedback"
                            in
                            Expect.equal ( False, 3 ) ( Dict.member "sheet" revised.context, List.length revised.attempts )
                        )
            , test "return clears the node's previous displayed output" <| \_ -> withRun (\run -> review run |> E.choose "Revise" "" |> .nodeStates |> List.filter (\s -> s.node == "ai") |> List.head |> Maybe.andThen .output |> Maybe.map (Encode.encode 0) |> Expect.equal Nothing)
            , test "cannot retry a missing input into a bypassable manual phase" <|
                \_ ->
                    let
                        d =
                            { definition
                                | nodes =
                                    List.map
                                        (\n ->
                                            if n.id == "review" then
                                                { n | inputKey = "missing" }

                                            else
                                                n
                                        )
                                        definition.nodes
                            }
                    in
                    E.start "retry" d (Dict.singleton "brief" Encode.null) |> Result.map (review >> E.retry >> .status) |> Expect.equal (Ok Failed)
            , test "outputs have unique owners so returns cannot erase another node's state" <|
                \_ ->
                    Expect.equal True
                        (change
                            (\d ->
                                { d
                                    | nodes =
                                        List.map
                                            (\n ->
                                                if n.id == "end" then
                                                    { n | outputKey = "sheet" }

                                                else
                                                    n
                                            )
                                            d.nodes
                                }
                            )
                        )
            , test "reachable traps without a path to any output are rejected" <|
                \_ ->
                    Expect.equal True (change (\d -> { d | edges = [ W.edge "start" "ai" "Work", W.edge "start" "end" "Finish", W.loop 2 "ai" "ai" "Again", W.edge "start" "review" "Other", W.edge "review" "wait" "Next", W.edge "wait" "end" "Finish" ] }))
            , test "a duplicate current state is ambiguous even if one copy is terminal" <| \_ -> Machine.transition "Finish" { machine | states = machine.states ++ [ { id = "ready", label = "Conflicting terminal", terminal = True } ] } |> Expect.equal Nothing
            , test "an exhausted human checkpoint fails instead of waiting without actions" <|
                \_ ->
                    let
                        d =
                            { definition | edges = [ W.edge "start" "ai" "Go", W.edge "ai" "review" "Inspect", W.edge "ai" "end" "Finish", W.loop 1 "review" "ai" "Revise", W.edge "start" "wait" "Package", W.edge "wait" "end" "Done" ] }
                    in
                    E.start "exhausted" d (Dict.singleton "brief" Encode.null) |> Result.map (E.complete Encode.null >> E.choose "Go" "" >> E.complete Encode.null >> E.choose "Inspect" "" >> E.choose "Revise" "" >> E.complete Encode.null >> E.choose "Inspect" "" >> .status) |> Expect.equal (Ok Failed)
            , test "two workflow editors use distinct field namespaces" <|
                \_ ->
                    Html.div [] [ Builder.view Ids.string [ Builder.id "first", Builder.selected (Just "ai") ] definition, Builder.view Ids.string [ Builder.id "second", Builder.selected (Just "ai") ] definition ] |> Query.fromHtml |> Expect.all [ Query.has [ S.id "first-state" ], Query.has [ S.id "second-state" ], Query.has [ S.id "first-instructions" ], Query.has [ S.id "second-instructions" ] ]
            ]
        , describe "Execution invariants"
            [ test "stops at human review with the AI result in context" <|
                \_ ->
                    withRun
                        (\run ->
                            let
                                r =
                                    review run
                            in
                            Expect.equal ( AwaitingInput, Just "review", Just "\"sheet-v1\"" ) ( r.status, r.active, Dict.get "sheet" r.context |> Maybe.map (Encode.encode 0) )
                        )
            , test "human input is never auto-completed" <| \_ -> withRun (\run -> Expect.equal (review run) (E.complete Encode.null (review run)))
            , test "invalid decisions have no effect" <| \_ -> withRun (\run -> Expect.equal (review run) (E.choose "Unknown" "" (review run)))
            , test "loop retains feedback and history" <|
                \_ ->
                    withRun
                        (\run ->
                            let
                                r =
                                    review run |> E.choose "Revise" "Use a teal jacket"
                            in
                            Expect.equal ( Just "ai", 3, Just "\"Use a teal jacket\"" ) ( r.active, List.length r.attempts, Dict.get "feedback" r.context |> Maybe.map (Encode.encode 0) )
                        )
            , test "loop attempts have distinct ordinal numbers" <|
                \_ ->
                    withRun
                        (\run ->
                            let
                                r =
                                    review run |> E.choose "Revise" "" |> E.complete (Encode.string "v2")
                            in
                            Expect.equal [ 1, 2 ] (r.attempts |> List.filter (\a -> a.node == "ai") |> List.map .number)
                        )
            , test "exhausted return disappears while approval remains" <|
                \_ ->
                    withRun
                        (\run ->
                            let
                                r =
                                    review run |> E.choose "Revise" "" |> E.complete Encode.null |> E.choose "Revise" "" |> E.complete Encode.null
                            in
                            Expect.equal [ "Approve" ] (List.map .label (E.available r))
                        )
            , test "forged exhausted return is ignored" <|
                \_ ->
                    withRun
                        (\run ->
                            let
                                r =
                                    review run |> E.choose "Revise" "" |> E.complete Encode.null |> E.choose "Revise" "" |> E.complete Encode.null
                            in
                            Expect.equal r (E.choose "Revise" "" r)
                        )
            , test "approve enters a real wait phase" <| \_ -> withRun (\run -> review run |> E.choose "Approve" "" |> .status |> Expect.equal Waiting)
            , test "output finishes only after work completes" <|
                \_ ->
                    withRun
                        (\run ->
                            let
                                r =
                                    review run |> E.choose "Approve" "" |> E.complete Encode.null |> E.complete Encode.null
                            in
                            Expect.equal ( Succeeded, Nothing ) ( r.status, r.active )
                        )
            , test "paused runs ignore late worker output" <|
                \_ ->
                    withRun
                        (\run ->
                            let
                                r =
                                    run |> E.complete Encode.null |> E.pause
                            in
                            Expect.equal r (E.complete (Encode.string "late") r)
                        )
            , test "resuming a review preserves its phase" <| \_ -> withRun (\run -> review run |> E.pause |> E.resume |> .status |> Expect.equal AwaitingInput)
            , test "cancelled runs ignore late worker output and retry" <|
                \_ ->
                    withRun
                        (\run ->
                            let
                                r =
                                    E.cancel run
                            in
                            Expect.equal r (r |> E.complete Encode.null |> E.retry |> E.resume)
                        )
            , test "worker errors remain in history through retry" <|
                \_ ->
                    withRun
                        (\run ->
                            let
                                r =
                                    run |> E.complete Encode.null |> E.fail "timeout" |> E.retry |> E.complete Encode.null
                            in
                            Expect.equal [ "failed", "completed" ] (r.attempts |> List.filter (\a -> a.node == "ai") |> List.map .outcome)
                        )
            , test "missing bound input fails explicitly" <|
                \_ ->
                    withRun
                        (\run ->
                            let
                                r =
                                    { run | context = Dict.empty } |> E.complete Encode.null |> E.complete Encode.null
                            in
                            Expect.equal ( Failed, Just "Missing input: brief" ) ( r.status, r.error )
                        )
            , test "initial configuration and latest output are separate" <|
                \_ ->
                    withRun
                        (\run ->
                            let
                                r =
                                    review run
                            in
                            Expect.equal (Just ( "{\"count\":12}", Just "\"sheet-v1\"" )) (r.nodeStates |> List.filter (\s -> s.node == "ai") |> List.head |> Maybe.map (\s -> ( Encode.encode 0 s.config, Maybe.map (Encode.encode 0) s.output )))
                        )
            , fuzz (Fuzz.intRange 0 40) "arbitrary repeat requests never exceed the budget" <|
                \count ->
                    withRun
                        (\run ->
                            let
                                r =
                                    List.range 1 count |> List.foldl (\_ acc -> acc |> E.choose "Revise" "" |> E.complete Encode.null) (review run)
                            in
                            Expect.atMost 2 (r.traversals |> List.filter (\t -> t.label == "Revise") |> List.map .count |> List.sum)
                        )
            ]
        , describe "Persistence and states"
            [ test "JSON round-trips instructions, initial state and loops" <| \_ -> Codec.encode Ids.string definition |> Decode.decodeValue (Codec.decoder Ids.string) |> Expect.equal (Ok definition)
            , test "incomplete drafts can be restored and validated" <|
                \_ ->
                    let
                        draft =
                            { ownerRole = "designer", title = "Draft", nodes = [], edges = [] }
                    in
                    Codec.encode Ids.string draft |> Decode.decodeValue (Codec.decoder Ids.string) |> Expect.equal (Ok draft)
            , test "unknown schema versions fail decoding" <| \_ -> Decode.decodeString (Codec.decoder Ids.string) "{\"version\":2}" |> Result.toMaybe |> Expect.equal Nothing
            , test "valid state events move the machine" <| \_ -> Machine.transition "Finish" machine |> Maybe.map .current |> Expect.equal (Just "done")
            , test "unknown state events are rejected" <| \_ -> Machine.transition "Unknown" machine |> Expect.equal Nothing
            , test "terminal states reject outgoing transitions" <| \_ -> Machine.transition "Finish" { machine | current = "done", transitions = [ { from = "done", to = "ready", event = "Finish" } ] } |> Expect.equal Nothing
            , test "ambiguous events are rejected" <| \_ -> Machine.transition "Finish" { machine | transitions = machine.transitions ++ machine.transitions } |> Expect.equal Nothing
            , test "missing state destinations are rejected" <| \_ -> Machine.transition "Finish" { machine | states = List.take 1 machine.states } |> Expect.equal Nothing
            ]
        , describe "Accessible rendering"
            [ test "node uses a real keyboard button" <| \_ -> Node.view [ Node.onSelect "select" ] (W.node "a" W.ai "Draw") |> Query.fromHtml |> Event.simulate Event.click |> Event.expect "select"
            , test "builder preserves malformed JSON in the editor" <|
                \_ ->
                    let
                        d =
                            { definition | nodes = List.map (\n -> { n | state = "{unfinished" }) definition.nodes }
                    in
                    Builder.view Ids.string [ Builder.selected (Just "ai") ] d |> Query.fromHtml |> Query.has [ S.tag "textarea", S.attribute (Attr.value "{unfinished") ]
            , test "runner marks the active step" <| \_ -> withRun (\run -> Runner.view [] (review run) |> Query.fromHtml |> Query.has [ S.attribute (Attr.attribute "aria-current" "step"), S.containing [ S.text "Review" ] ])
            , test "remote failure offers retry" <| \_ -> Runner.viewRemote [ Runner.onRetry "retry" ] (Remote.Failed (Remote.problem Remote.network)) |> Query.fromHtml |> Query.find [ S.tag "button" ] |> Event.simulate Event.click |> Event.expect "retry"
            , test "remote focus id occurs once in a loaded run" <| \_ -> withRun (\run -> Runner.viewRemote [ Runner.id "run-view" ] (Remote.Loaded run) |> Query.fromHtml |> Query.findAll [ S.id "run-view" ] |> Query.count (Expect.equal 1))
            , test "choosing a worker branch preserves its produced output" <|
                \_ ->
                    let
                        d =
                            { definition | edges = definition.edges ++ [ W.edge "ai" "end" "Skip review" ] }
                    in
                    E.start "branch" d (Dict.singleton "brief" Encode.null) |> Result.map (review >> E.choose "Inspect" "" >> .context >> Dict.get "sheet" >> Maybe.map (Encode.encode 0)) |> Expect.equal (Ok (Just "\"sheet-v1\""))
            , test "worker completion cannot bypass a manual task" <|
                \_ ->
                    let
                        d =
                            { definition
                                | nodes =
                                    List.map
                                        (\n ->
                                            if n.id == "review" then
                                                { n | kind = W.task }

                                            else
                                                n
                                        )
                                        definition.nodes
                            }
                    in
                    E.start "manual" d (Dict.singleton "brief" Encode.null) |> Result.map (review >> E.complete Encode.null >> .status) |> Expect.equal (Ok AwaitingInput)
            , test "Norwegian palette is localized" <| \_ -> Node.view [ Node.locale Locale.nb ] (W.node "a" W.human "Review") |> Query.fromHtml |> Query.has [ S.text "Menneskelig vurdering" ]
            ]
        ]
