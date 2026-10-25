module Backend.WorkflowServer exposing (Actor, Request(..), Server, actors, artifacts, canControl, canDecide, canEdit, canStart, delay, handle, init, requiredRole, signIn)

{-| A deterministic Elm server simulator. Requests carry a run id and expected
revision, so duplicate and late worker replies cannot advance a different run.
Replace this boundary with HTTP/SSE in an application; the Klar components do
not know which transport is used. No external AI service is called.
-}

import Dict exposing (Dict)
import Json.Decode as Decode
import Json.Encode as Encode exposing (Value)
import Klar.Locale as Locale
import Klar.Workflow as Workflow exposing (Definition)
import Klar.Workflow.Engine as Engine exposing (Run, Status(..))
import Url


type alias Server =
    { runs : Dict String (Run String), nextId : Int, actor : Actor }


type alias Actor =
    { id : String, name : String, roles : List String }


actors : List Actor
actors =
    [ { id = "studio", name = "Alex · process designer", roles = [ "designer", "operator", "reviewer", "workflow-admin" ] }
    , { id = "coordinator", name = "Morgan · membership coordinator", roles = [ "coordinator" ] }
    , { id = "interviewer", name = "Sam · interviewer", roles = [ "interviewer" ] }
    , { id = "director", name = "Taylor · managing director", roles = [ "director" ] }
    , { id = "registrar", name = "Robin · membership registrar", roles = [ "registrar" ] }
    , { id = "observer", name = "Casey · observer", roles = [ "observer" ] }
    ]



-- A demo session switch. Production resolves the principal from a verified
-- server session, never from a role or actor claimed in request JSON.


signIn : String -> Server -> Server
signIn id server =
    { server | actor = List.filter (\actor -> actor.id == id) actors |> List.head |> Maybe.withDefault server.actor }


requiredRole : Workflow.Node id -> String
requiredRole n =
    if n.kind == Workflow.human then
        n.approverRole

    else
        n.performerRole


canEdit : Definition id -> Server -> Bool
canEdit definition server =
    List.member definition.ownerRole server.actor.roles


canStart : Definition id -> Server -> Bool
canStart definition server =
    List.head definition.nodes |> Maybe.map (\n -> List.member n.performerRole server.actor.roles) |> Maybe.withDefault False


canDecide : Run String -> Server -> Bool
canDecide run server =
    run.status == AwaitingInput && (Engine.current run |> Maybe.map (\n -> List.member (requiredRole n) server.actor.roles) |> Maybe.withDefault False)


canControl : Run String -> Server -> Bool
canControl run server =
    run.startedBy == server.actor.id || List.member "workflow-admin" server.actor.roles


type Request
    = Start (Definition String) (Dict String Value)
    | Work String Int Bool
    | Decide String Int String String
    | Pause String Int
    | Resume String Int
    | Retry String Int
    | Cancel String Int
    | Load String


init : Server
init =
    { runs = Dict.empty, nextId = 1, actor = { id = "studio", name = "Alex · process designer", roles = [ "designer", "operator", "reviewer", "workflow-admin" ] } }


delay : Request -> Server -> Float
delay request server =
    case request of
        Work id _ _ ->
            Dict.get id server.runs
                |> Maybe.andThen Engine.current
                |> Maybe.map
                    (\n ->
                        if n.kind == Workflow.wait then
                            toFloat n.waitSeconds * 1000

                        else if n.kind == Workflow.ai then
                            1800

                        else
                            450
                    )
                |> Maybe.withDefault 450

        _ ->
            350


handle : Request -> Server -> ( Server, Result String (Run String) )
handle request server =
    let
        stamp name run =
            { run
                | attempts =
                    run.attempts
                        |> List.reverse
                        |> (\attempts ->
                                case attempts of
                                    latest :: rest ->
                                        { latest | actor = Just name } :: rest

                                    [] ->
                                        []
                           )
                        |> List.reverse
            }

        audited name action run =
            let
                next =
                    action run
            in
            if List.length next.attempts > List.length run.attempts then
                stamp name next

            else
                next

        mutate id revision permitted transform =
            case Dict.get id server.runs of
                Nothing ->
                    ( server, Err "Run not found." )

                Just run ->
                    if not (permitted run) then
                        ( server, Err "Permission denied. This session does not have the role assigned to this action." )

                    else if run.revision /= revision then
                        ( server, Err "Revision conflict. Reload the run before sending this command again." )

                    else
                        let
                            next =
                                transform run
                        in
                        if next.revision == run.revision then
                            ( server, Err "This action is not available in the current state or its transition budget is exhausted." )

                        else
                            ( { server | runs = Dict.insert id next server.runs }, Ok next )
    in
    case request of
        Start definition context ->
            if not (canStart definition server) then
                ( server, Err "Permission denied. Only the assigned start role may start this process." )

            else
                case Engine.start ("run-" ++ String.padLeft 4 '0' (String.fromInt server.nextId)) definition context of
                    Err issues ->
                        ( server, Err (List.map (Workflow.issueText Locale.en definition) issues |> String.join " ") )

                    Ok started ->
                        let
                            run =
                                { started | startedBy = server.actor.id }
                        in
                        ( { server | runs = Dict.insert run.id run server.runs, nextId = server.nextId + 1 }, Ok run )

        Work id revision fails ->
            mutate id
                revision
                (\run -> List.member run.status [ Running, Waiting ])
                (\run ->
                    if fails && (Engine.current run |> Maybe.map .kind) == Just Workflow.ai then
                        audited "Simulated AI worker" (Engine.fail "The simulated AI worker timed out. Retry to keep working with the same input.") run

                    else if (Engine.current run |> Maybe.map (\n -> n.kind == Workflow.ai && n.outputKey == "character_sheet")) == Just True && Result.toMaybe (imageCount run) == Nothing then
                        audited "Simulated AI worker" (Engine.fail "imageCount must be a whole number from 1 to 24 in the AI step's initial state.") run

                    else
                        audited "Workflow service" (Engine.complete (workerResult run)) run
                )

        Decide id revision label feedback ->
            mutate id revision (\run -> canDecide run server) (audited server.actor.name (Engine.choose label feedback))

        Pause id revision ->
            mutate id revision (\run -> canControl run server) Engine.pause

        Resume id revision ->
            mutate id revision (\run -> canControl run server) Engine.resume

        Retry id revision ->
            mutate id revision (\run -> canControl run server) Engine.retry

        Cancel id revision ->
            mutate id revision (\run -> canControl run server) Engine.cancel

        Load id ->
            ( server, Dict.get id server.runs |> Result.fromMaybe "Run not found." )


workerResult : Run String -> Value
workerResult run =
    case Engine.current run of
        Nothing ->
            Encode.null

        Just n ->
            if n.kind == Workflow.input then
                Dict.get "brief" run.context |> Maybe.withDefault Encode.null

            else if n.kind == Workflow.ai then
                Encode.object
                    [ ( "settings", Decode.decodeString Decode.value n.state |> Result.withDefault Encode.null )
                    , ( "simulated", Encode.bool True )
                    , ( "instructions", Encode.string n.instructions )
                    , ( "input", Dict.get n.inputKey run.context |> Maybe.withDefault Encode.null )
                    , ( "feedback", Dict.get "feedback" run.context |> Maybe.withDefault Encode.null )
                    , ( "revision", Encode.int (run.revision + 1) )
                    , ( "summary"
                      , Encode.string
                            (if n.outputKey == "character_sheet" then
                                String.fromInt (imageCount run |> Result.withDefault 12) ++ " simulated character views are ready for human review."

                             else
                                "Simulated analysis completed. Review the instructions and input before approving."
                            )
                      )
                    , ( "artifacts"
                      , Encode.list identity
                            (if n.outputKey == "character_sheet" then
                                List.range 1 (imageCount run |> Result.withDefault 12) |> List.map (artifact (run.revision + 1))

                             else
                                []
                            )
                      )
                    ]

            else if n.kind == Workflow.output then
                Encode.object (Dict.toList run.context)

            else
                Encode.object [ ( "waitedSeconds", Encode.int n.waitSeconds ), ( "simulated", Encode.bool True ) ]


imageCount : Run String -> Result String Int
imageCount run =
    let
        state =
            Engine.current run |> Maybe.map .state |> Maybe.withDefault "{}"
    in
    case Decode.decodeString (Decode.dict Decode.value) state |> Result.toMaybe |> Maybe.andThen (Dict.get "imageCount") of
        Nothing ->
            Ok 12

        Just value ->
            Decode.decodeValue Decode.int value
                |> Result.mapError (always "Invalid imageCount")
                |> Result.andThen
                    (\count ->
                        if count >= 1 && count <= 24 then
                            Ok count

                        else
                            Err "Invalid imageCount"
                    )


artifact : Int -> Int -> Value
artifact revision index =
    let
        labels =
            [ "Front", "Three-quarter", "Profile", "Back", "Happy", "Surprised", "Thinking", "Determined", "Walking", "Running", "Sitting", "Waving" ]

        label =
            List.drop (index - 1) labels |> List.head |> Maybe.withDefault "Study"

        hue =
            String.fromInt (180 + modBy 100 (revision * 17 + index * 9))

        shift =
            String.fromInt (modBy 9 index - 4)

        svg =
            "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 180 180'><rect width='180' height='180' rx='6' fill='hsl(" ++ hue ++ ",28%,94%)'/><path d='M25 154H155M90 22V160' stroke='hsl(" ++ hue ++ ",20%,82%)' stroke-dasharray='3 5'/><g transform='translate(" ++ shift ++ " 0)' stroke='#34475c' stroke-width='2.5' stroke-linecap='round' stroke-linejoin='round'><path d='M57 143Q56 99 90 99Q124 99 123 143Z' fill='hsl(" ++ hue ++ ",38%,66%)'/><path d='M74 111L69 151M106 111L111 151' fill='none'/><ellipse cx='90' cy='73' rx='25' ry='30' fill='#f0d8c0'/><path d='M65 70Q57 37 87 35Q119 33 116 65L101 53L90 59L78 52Z' fill='#34475c'/><path d='M79 75H81M99 75H101M83 89Q90 " ++ String.fromInt (91 + modBy 7 index) ++ " 97 89' fill='none'/></g><text x='12' y='170' font-family='sans-serif' font-size='9' fill='#455060'>SIMULATED / " ++ String.fromInt index ++ "</text></svg>"
    in
    Encode.object [ ( "label", Encode.string label ), ( "preview", Encode.string ("data:image/svg+xml," ++ Url.percentEncode svg) ), ( "revision", Encode.int revision ) ]


artifacts : Run String -> List { label : String, preview : String }
artifacts run =
    Dict.get "character_sheet" run.context
        |> Maybe.andThen (Decode.decodeValue (Decode.field "artifacts" (Decode.list (Decode.map2 (\label preview -> { label = label, preview = preview }) (Decode.field "label" Decode.string) (Decode.field "preview" Decode.string)))) >> Result.toMaybe)
        |> Maybe.withDefault []
