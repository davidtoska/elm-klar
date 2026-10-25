module ProcessesTest exposing (suite)

import Backend.WorkflowServer as Server
import Dict
import Expect
import Json.Encode as Encode
import Klar.Ids as Ids
import Klar.Remote as Remote
import Klar.Workflow as W
import Klar.Workflow.Codec as Codec
import Klar.Workflow.Engine as Engine exposing (Status(..))
import Page.Applications.Processes as Studio
import Showcase.Workflows as Samples
import Test exposing (Test, describe, test)


start : ( Server.Server, Result String (Engine.Run String) )
start =
    Server.handle (Server.Start Samples.character (Dict.singleton "brief" (Encode.string "Explorer"))) Server.init


withRun : (Server.Server -> Engine.Run String -> Expect.Expectation) -> Expect.Expectation
withRun check =
    case start of
        ( server, Ok run ) ->
            check server run

        ( _, Err message ) ->
            Expect.fail message


step : String -> (Engine.Run String -> Server.Request) -> ( Server.Server, Result String (Engine.Run String) ) -> ( Server.Server, Result String (Engine.Run String) )
step actor request ( server, result ) =
    case result of
        Ok run ->
            Server.handle (request run) (Server.signIn actor server)

        Err _ ->
            ( server, result )


atDirector : ( Server.Server, Result String (Engine.Run String) )
atDirector =
    Server.handle (Server.Start Samples.membership (Dict.singleton "brief" (Encode.string "A fictional applicant"))) (Server.signIn "coordinator" Server.init)
        |> step "coordinator" (\r -> Server.Work r.id r.revision False)
        |> step "interviewer" (\r -> Server.Decide r.id r.revision "Submit interview" "Interview completed. The applicant wishes to join.")
        |> step "coordinator" (\r -> Server.Decide r.id r.revision "Recommend admission" "Interview evidence supports admission.")


suite : Test
suite =
    describe "Process server and studio"
        [ test "all four shipped templates validate" <| \_ -> [ Samples.character, Samples.document, Samples.publication, Samples.membership ] |> List.map (W.validate >> List.length) |> Expect.equal [ 0, 0, 0, 0 ]
        , test "server rejects a stale work revision" <| \_ -> withRun (\server run -> Server.handle (Server.Work run.id -1 False) server |> Tuple.second |> Result.toMaybe |> Expect.equal Nothing)
        , test "duplicate work cannot advance twice" <|
            \_ ->
                withRun
                    (\server run ->
                        let
                            ( next, _ ) =
                                Server.handle (Server.Work run.id run.revision False) server
                        in
                        Server.handle (Server.Work run.id run.revision False) next |> Tuple.second |> Result.toMaybe |> Expect.equal Nothing
                    )
        , test "cancel invalidates work already in flight" <|
            \_ ->
                withRun
                    (\server run ->
                        let
                            ( next, _ ) =
                                Server.handle (Server.Cancel run.id run.revision) server
                        in
                        Server.handle (Server.Work run.id run.revision False) next |> Tuple.second |> Result.toMaybe |> Expect.equal Nothing
                    )
        , test "missing run ids fail" <| \_ -> Server.handle (Server.Load "missing") Server.init |> Tuple.second |> Expect.equal (Err "Run not found.")
        , test "character work produces twelve inspectable artifacts" <|
            \_ ->
                withRun
                    (\server run ->
                        case Server.handle (Server.Work run.id run.revision False) server of
                            ( next, Ok ai ) ->
                                case Server.handle (Server.Work ai.id ai.revision False) next of
                                    ( _, Ok reviewed ) ->
                                        Expect.equal ( AwaitingInput, 12 ) ( reviewed.status, List.length (Server.artifacts reviewed) )

                                    ( _, Err error ) ->
                                        Expect.fail error

                            ( _, Err error ) ->
                                Expect.fail error
                    )
        , test "simulated AI can fail and be retried" <|
            \_ ->
                withRun
                    (\server run ->
                        case Server.handle (Server.Work run.id run.revision False) server of
                            ( next, Ok ai ) ->
                                case Server.handle (Server.Work ai.id ai.revision True) next of
                                    ( failedServer, Ok failed ) ->
                                        case Server.handle (Server.Retry failed.id failed.revision) failedServer of
                                            ( _, Ok retried ) ->
                                                Expect.equal ( Failed, Running, 2 ) ( failed.status, retried.status, List.length retried.attempts )

                                            ( _, Err error ) ->
                                                Expect.fail error

                                    ( _, Err error ) ->
                                        Expect.fail error

                            ( _, Err error ) ->
                                Expect.fail error
                    )
        , test "late page replies cannot mutate a newer session" <|
            \_ ->
                let
                    ( pending, _ ) =
                        Studio.update Studio.Start Studio.init

                    leaving =
                        Studio.leave pending

                    ( arrived, _ ) =
                        Studio.update (Studio.Arrived pending.ticket pending.server.actor (Server.Start Samples.character Dict.empty)) leaving
                in
                Expect.equal ( leaving.ticket, Dict.size leaving.server.runs ) ( arrived.ticket, Dict.size arrived.server.runs )
        , test "adding after AI rewires its single forward path" <|
            \_ ->
                let
                    ( added, _ ) =
                        Studio.update (Studio.Add W.wait) Studio.init
                in
                Expect.equal ( 6, [ "step-1" ], [ "review" ] ) ( List.length added.definition.nodes, W.outgoing "generate" added.definition |> List.map .to, W.outgoing "step-1" added.definition |> List.map .to )
        , test "only the coordinator can start membership admission" <| \_ -> Server.handle (Server.Start Samples.membership Dict.empty) (Server.signIn "interviewer" Server.init) |> Tuple.second |> Result.toMaybe |> Expect.equal Nothing
        , test "the next approval is assigned to the director" <| \_ -> atDirector |> Tuple.second |> Result.map (\r -> ( r.active, Engine.current r |> Maybe.map Server.requiredRole )) |> Expect.equal (Ok ( Just "director", Just "director" ))
        , test "an interviewer cannot approve on behalf of the director" <| \_ -> atDirector |> step "interviewer" (\r -> Server.Decide r.id r.revision "Approve admission" "") |> Tuple.second |> Result.toMaybe |> Expect.equal Nothing
        , test "the registrar cannot enroll before director approval" <| \_ -> atDirector |> step "registrar" (\r -> Server.Decide r.id r.revision "Confirm enrollment" "") |> Tuple.second |> Result.toMaybe |> Expect.equal Nothing
        , test "only the registrar can perform enrollment after approval" <| \_ -> atDirector |> step "director" (\r -> Server.Decide r.id r.revision "Approve admission" "Approved") |> step "coordinator" (\r -> Server.Decide r.id r.revision "Confirm enrollment" "") |> Tuple.second |> Result.toMaybe |> Expect.equal Nothing
        , test "the whole membership flow records identity and enrollment" <|
            \_ ->
                atDirector
                    |> step "director" (\r -> Server.Decide r.id r.revision "Approve admission" "Approved")
                    |> step "registrar" (\r -> Server.Decide r.id r.revision "Confirm enrollment" "Member M-1042")
                    |> step "registrar" (\r -> Server.Work r.id r.revision False)
                    |> Tuple.second
                    |> Result.map (\r -> ( r.status, Dict.member "membership" r.context, r.attempts |> List.filter (\a -> a.node == "director") |> List.head |> Maybe.andThen .actor ))
                    |> Expect.equal (Ok ( Succeeded, True, Just "Taylor · managing director" ))
        , test "declined applicants are never enrolled" <|
            \_ ->
                atDirector |> step "director" (\r -> Server.Decide r.id r.revision "Decline admission" "The supplied criteria were not met.") |> step "director" (\r -> Server.Work r.id r.revision False) |> Tuple.second |> Result.map (\r -> ( r.status, Dict.member "membership" r.context )) |> Expect.equal (Ok ( Succeeded, False ))
        , test "unknown labels fail without rewriting a previous actor" <|
            \_ ->
                case atDirector of
                    ( server, Ok run ) ->
                        let
                            ( next, result ) =
                                Server.handle (Server.Decide run.id run.revision "Unknown" "") (Server.signIn "director" server)
                        in
                        Expect.equal ( Nothing, Just run.attempts ) ( Result.toMaybe result, Dict.get run.id next.runs |> Maybe.map .attempts )

                    ( _, Err error ) ->
                        Expect.fail error
        , test "observers cannot edit definitions" <| \_ -> Server.canEdit Samples.character (Server.signIn "observer" Server.init) |> Expect.equal False
        , test "a forged editor message is rejected as well" <|
            \_ ->
                let
                    initial =
                        Studio.init

                    locked =
                        { initial | server = Server.signIn "observer" initial.server }

                    ( changed, _ ) =
                        Studio.update (Studio.Title "Forged") locked
                in
                Expect.equal initial.definition changed.definition
        , test "unauthorized sessions cannot cancel someone else's run" <| \_ -> withRun (\server run -> Server.handle (Server.Cancel run.id run.revision) (Server.signIn "observer" server) |> Tuple.second |> Result.toMaybe |> Expect.equal Nothing)
        , test "failed decisions preserve the person's notes" <|
            \_ ->
                case atDirector of
                    ( server, Ok run ) ->
                        let
                            initial =
                                Studio.init

                            ( pending, _ ) =
                                Studio.update (Studio.Decide "Approve admission") { initial | server = Server.signIn "observer" server, run = Remote.Loaded run, feedback = "Keep these review notes" }

                            ( replied, _ ) =
                                Studio.update (Studio.Arrived pending.ticket pending.server.actor (Server.Decide run.id run.revision "Approve admission" "Keep these review notes")) pending
                        in
                        Expect.equal ( "Keep these review notes", True ) ( replied.feedback, replied.error /= Nothing )

                    ( _, Err error ) ->
                        Expect.fail error
        , test "edits to a draft do not mutate a running snapshot" <|
            \_ ->
                withRun
                    (\_ run ->
                        let
                            initial =
                                Studio.init

                            draft =
                                initial.definition

                            ( edited, _ ) =
                                Studio.update (Studio.Change { draft | title = "New draft" }) { initial | run = Remote.Loaded run }
                        in
                        Expect.equal ( "New draft", Just "Character studio" ) ( edited.definition.title, Remote.toMaybe edited.run |> Maybe.map (.definition >> .title) )
                    )
        , test "request identity is fixed when submitted, not when its reply arrives" <|
            \_ ->
                case atDirector of
                    ( server, Ok run ) ->
                        let
                            initial =
                                Studio.init

                            ( pending, _ ) =
                                Studio.update (Studio.Decide "Approve admission") { initial | server = Server.signIn "director" server, run = Remote.Loaded run }

                            ( switched, _ ) =
                                Studio.update (Studio.Actor "interviewer") pending

                            ( replied, _ ) =
                                Studio.update (Studio.Arrived pending.ticket pending.server.actor (Server.Decide run.id run.revision "Approve admission" "")) switched
                        in
                        Expect.equal ( Just "enroll", "interviewer", Just (Just "Taylor · managing director") ) ( Remote.toMaybe replied.run |> Maybe.andThen .active, replied.server.actor.id, Remote.toMaybe replied.run |> Maybe.map (.attempts >> List.reverse >> List.head >> Maybe.andThen .actor) )

                    ( _, Err error ) ->
                        Expect.fail error
        , test "switching to a privileged identity cannot authorize an older request" <|
            \_ ->
                case atDirector of
                    ( server, Ok run ) ->
                        let
                            initial =
                                Studio.init

                            observer =
                                (Server.signIn "observer" server).actor

                            ( replied, _ ) =
                                Studio.update (Studio.Arrived 0 observer (Server.Decide run.id run.revision "Approve admission" "")) { initial | server = Server.signIn "director" server, run = Remote.Loaded run }
                        in
                        Expect.equal ( Just "director", True ) ( Remote.toMaybe replied.run |> Maybe.andThen .active, replied.error /= Nothing )

                    ( _, Err error ) ->
                        Expect.fail error
        , test "an unauthorized control action does not cancel the active worker ticket" <|
            \_ ->
                withRun
                    (\server run ->
                        let
                            initial =
                                Studio.init

                            ( rejected, _ ) =
                                Studio.update Studio.Pause { initial | server = Server.signIn "observer" server, run = Remote.Loaded run, ticket = 10, pending = True }
                        in
                        Expect.equal ( 10, True ) ( rejected.ticket, rejected.pending )
                    )
        , test "an error reply resumes current server work rather than stranding the process" <|
            \_ ->
                withRun
                    (\server run ->
                        let
                            initial =
                                Studio.init

                            ( replied, _ ) =
                                Studio.update (Studio.Arrived 3 server.actor (Server.Work run.id -1 False)) { initial | server = server, run = Remote.Loaded run, ticket = 3, pending = True }
                        in
                        Expect.equal ( True, True, 4 ) ( replied.pending, replied.error /= Nothing, replied.ticket )
                    )
        , test "a second start cannot strand an unfinished run" <|
            \_ ->
                withRun
                    (\server run ->
                        let
                            initial =
                                Studio.init

                            ( unchanged, _ ) =
                                Studio.update Studio.Start { initial | server = server, run = Remote.Loaded run }
                        in
                        Expect.equal ( 0, Just run.id ) ( unchanged.ticket, Remote.toMaybe unchanged.run |> Maybe.map .id )
                    )
        , test "typing a designer role does not revoke edit permission mid-input" <|
            \_ ->
                let
                    ( partial, _ ) =
                        Studio.update (Studio.OwnerRole "coord") Studio.init

                    ( complete, _ ) =
                        Studio.update (Studio.OwnerRole "coordinator") partial

                    ( applied, _ ) =
                        Studio.update Studio.ApplyOwnerRole complete
                in
                Expect.equal ( "designer", "coordinator", "coordinator" ) ( complete.definition.ownerRole, complete.ownerRoleDraft, applied.definition.ownerRole )
        , test "a late imported file cannot overwrite newer draft edits" <|
            \_ ->
                let
                    ( importing, _ ) =
                        Studio.update Studio.ImportDraft Studio.init

                    ( edited, _ ) =
                        Studio.update (Studio.Title "A newer edit") importing

                    ( late, _ ) =
                        Studio.update (Studio.DraftText importing.draftTicket (Codec.encode Ids.string Samples.document |> Encode.encode 0)) edited
                in
                Expect.equal "A newer edit" late.definition.title
        , test "deleting the inspected node selects a surviving node" <|
            \_ ->
                let
                    initial =
                        Studio.init

                    d =
                        initial.definition

                    ( changed, _ ) =
                        Studio.update (Studio.Change { d | nodes = List.filter (\n -> n.id /= "generate") d.nodes }) initial
                in
                Expect.equal (Just "brief") changed.selected
        , test "AI state controls the number of simulated images" <|
            \_ ->
                let
                    d =
                        Samples.character

                    changed =
                        { d
                            | nodes =
                                List.map
                                    (\n ->
                                        if n.id == "generate" then
                                            { n | state = "{\"imageCount\":3}" }

                                        else
                                            n
                                    )
                                    d.nodes
                        }
                in
                Server.handle (Server.Start changed (Dict.singleton "brief" Encode.null)) Server.init
                    |> step "studio" (\r -> Server.Work r.id r.revision False)
                    |> step "studio" (\r -> Server.Work r.id r.revision False)
                    |> Tuple.second
                    |> Result.map (Server.artifacts >> List.length)
                    |> Expect.equal (Ok 3)
        , test "invalid image counts fail without being silently clamped" <|
            \_ ->
                let
                    d =
                        Samples.character

                    changed =
                        { d
                            | nodes =
                                List.map
                                    (\n ->
                                        if n.id == "generate" then
                                            { n | state = "{\"imageCount\":0}" }

                                        else
                                            n
                                    )
                                    d.nodes
                        }
                in
                Server.handle (Server.Start changed (Dict.singleton "brief" Encode.null)) Server.init
                    |> step "studio" (\r -> Server.Work r.id r.revision False)
                    |> step "studio" (\r -> Server.Work r.id r.revision False)
                    |> Tuple.second
                    |> Result.map (\r -> ( r.status, List.length (Server.artifacts r) ))
                    |> Expect.equal (Ok ( Failed, 0 ))
        ]
