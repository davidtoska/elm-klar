module Page.Applications.Processes exposing (Model, Msg(..), componentView, init, leave, update, view)

{-| The process studio: build a definition, start a versioned snapshot, inspect
server work and decide at human checkpoints. All data is local to this demo.
-}

import Api.Workflows as Api
import Backend.WorkflowServer as Server
import Dict
import File
import File.Download
import File.Select
import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events
import Json.Decode as Decode
import Json.Encode as Encode
import Klar
import Klar.Alert as Alert
import Klar.Badge as Badge
import Klar.Button as Button
import Klar.Card as Card
import Klar.Checkbox as Checkbox
import Klar.FileDrop as FileDrop
import Klar.Icon as Icon
import Klar.Ids as Ids
import Klar.Layout as Layout
import Klar.Locale as Locale exposing (Locale)
import Klar.Remote as Remote exposing (Remote)
import Klar.SegmentedControl as Segmented
import Klar.Select as Select
import Klar.StateMachine as Machine
import Klar.Text as Text
import Klar.TextArea as TextArea
import Klar.TextInput as TextInput
import Klar.Theme exposing (Tone(..))
import Klar.Workflow as Workflow
import Klar.Workflow.Codec as Codec
import Klar.Workflow.Engine as Engine exposing (Run, Status(..))
import Klar.WorkflowBuilder as Builder
import Klar.WorkflowNode as Node
import Klar.WorkflowRun as Runner
import Showcase.Config as Config
import Showcase.Doc as Doc
import Showcase.ProcessOptions as Options
import Showcase.Workflows as Samples
import Task


type alias Model =
    { definition : Workflow.Definition String
    , selected : Maybe String
    , nextId : Int
    , tab : String
    , template : String
    , brief : String
    , files : FileDrop.State
    , preview : Maybe String
    , fileTicket : Int
    , server : Server.Server
    , run : Remote (Run String)
    , inspected : Maybe String
    , ticket : Int
    , pending : Bool
    , feedback : String
    , failNext : Bool
    , error : Maybe String
    , machine : Machine.Machine String
    , stateName : String
    , eventName : String
    , eventFrom : String
    , eventTo : String
    , actorSelect : Select.State String
    , fromSelect : Select.State String
    , toSelect : Select.State String
    , draftTicket : Int
    , ownerRoleDraft : String
    , previewRemote : String
    }


init : Model
init =
    { definition = Samples.character, selected = Just "generate", nextId = 1, tab = "build", template = "character", brief = "A curious young explorer for a gentle science-fiction comic. Teal jacket, round silhouette, expressive eyebrows. Keep the design readable in small panels.", files = FileDrop.init "process-reference", preview = Nothing, fileTicket = 0, server = Server.init, run = Remote.NotAsked, inspected = Nothing, ticket = 0, pending = False, feedback = "", failNext = False, error = Nothing, machine = Samples.lifecycle, stateName = "", eventName = "", eventFrom = "ready", eventTo = "working", actorSelect = Select.init "process-session" |> Select.setValue (Just "studio"), fromSelect = Select.init "lifecycle-from" |> Select.setValue (Just "ready"), toSelect = Select.init "lifecycle-to" |> Select.setValue (Just "working"), previewRemote = "loaded", draftTicket = 0, ownerRoleDraft = "designer" }


type Msg
    = Select String
    | Change (Workflow.Definition String)
    | Add Workflow.Kind
    | Template String
    | Tab String
    | Title String
    | ApplyOwnerRole
    | OwnerRole String
    | Actor String
    | ActorSelect (Select.Msg String)
    | FromSelect (Select.Msg String)
    | ToSelect (Select.Msg String)
    | PreviewRemote String
    | RetryPreview
    | NoOp
    | Brief String
    | Files FileDrop.Msg
    | Preview Int String
    | Start
    | Arrived Int Server.Actor Server.Request
    | Decide String
    | Feedback String
    | Inspect String
    | Pause
    | Resume
    | Cancel
    | Retry
    | Reload
    | LoadRun String
    | FailNext Bool
    | Export
    | SaveDraft
    | ImportDraft
    | DraftFile Int File.File
    | DraftText Int String
    | Event String
    | ResetMachine
    | StateName String
    | AddState
    | EventName String
    | EventFrom String
    | EventTo String
    | AddTransition
    | RenameState String String
    | TerminalState String Bool
    | RemoveState String
    | RemoveTransition Int


leave : Model -> Model
leave model =
    let
        paused =
            Remote.toMaybe model.run |> Maybe.map Engine.pause

        server =
            model.server
    in
    { model | ticket = model.ticket + 1, pending = False, run = paused |> Maybe.map Remote.Loaded |> Maybe.withDefault model.run, server = { server | runs = paused |> Maybe.map (\run -> Dict.insert run.id run server.runs) |> Maybe.withDefault server.runs } }


send : Server.Request -> Model -> ( Model, Cmd Msg )
send request model =
    let
        ticket =
            model.ticket + 1
    in
    ( { model | pending = True, ticket = ticket, error = Nothing }, Api.send (Arrived ticket model.server.actor) request model.server )


afterAck : Server.Request -> ( Model, Cmd Msg ) -> ( Model, Cmd Msg )
afterAck request ( model, cmd ) =
    let
        focus =
            case request of
                Server.Start _ _ ->
                    Klar.focus "process-run-focus" NoOp

                Server.Decide _ _ _ _ ->
                    Klar.focus "process-run-focus" NoOp

                _ ->
                    Cmd.none
    in
    ( model, Cmd.batch [ cmd, focus ] )


continue : Run String -> Model -> ( Model, Cmd Msg )
continue run model =
    if List.member run.status [ Running, Waiting ] then
        send (Server.Work run.id run.revision model.failNext)
            { model
                | failNext =
                    if (Engine.current run |> Maybe.map .kind) == Just Workflow.ai then
                        False

                    else
                        model.failNext
            }

    else
        ( model, Cmd.none )


withRun : (Run String -> Server.Request) -> Model -> ( Model, Cmd Msg )
withRun request model =
    case Remote.toMaybe model.run of
        Just run ->
            let
                command =
                    request run

                permitted =
                    case command of
                        Server.Decide _ _ _ _ ->
                            Server.canDecide run model.server

                        Server.Pause _ _ ->
                            Server.canControl run model.server

                        Server.Resume _ _ ->
                            Server.canControl run model.server

                        Server.Retry _ _ ->
                            Server.canControl run model.server

                        Server.Cancel _ _ ->
                            Server.canControl run model.server

                        _ ->
                            True
            in
            if permitted then
                send command model

            else
                ( { model | error = Just "This session is not assigned to this action." }, Cmd.none )

        Nothing ->
            ( model, Cmd.none )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    let
        changesDesign =
            case msg of
                Change _ ->
                    True

                Title _ ->
                    True

                OwnerRole _ ->
                    True

                ApplyOwnerRole ->
                    True

                Add _ ->
                    True

                DraftText _ _ ->
                    True

                _ ->
                    False
    in
    if changesDesign && not (Server.canEdit model.definition model.server) then
        ( { model | error = Just "This demo session cannot edit the process. Switch to its process designer." }, Cmd.none )

    else
        let
            ( next, cmd ) =
                updateAllowed msg model

            changed =
                case msg of
                    Template _ ->
                        True

                    OwnerRole _ ->
                        True

                    _ ->
                        next.definition /= model.definition
        in
        ( if changed then
            { next | draftTicket = model.draftTicket + 1 }

          else
            next
        , cmd
        )


updateAllowed : Msg -> Model -> ( Model, Cmd Msg )
updateAllowed msg model =
    case msg of
        NoOp ->
            ( model, Cmd.none )

        RetryPreview ->
            ( { model | previewRemote = "loaded" }, Klar.focus "workflow-preview-focus" NoOp )

        Select id ->
            ( { model | selected = Just id }, Cmd.none )

        Change definition ->
            let
                missing =
                    model.selected |> Maybe.map (\id -> Workflow.find id definition == Nothing) |> Maybe.withDefault False
            in
            ( { model
                | definition = definition
                , selected =
                    if missing then
                        List.head definition.nodes |> Maybe.map .id

                    else
                        model.selected
              }
            , if missing then
                Klar.focus "process-builder-focus" NoOp

              else
                Cmd.none
            )

        ActorSelect inner ->
            let
                ( state, cmd ) =
                    Select.update inner model.actorSelect
            in
            ( { model | actorSelect = state, server = Server.signIn (Select.value state |> Maybe.withDefault model.server.actor.id) model.server, error = Nothing }, Cmd.map ActorSelect cmd )

        FromSelect inner ->
            let
                ( state, cmd ) =
                    Select.update inner model.fromSelect
            in
            ( { model | fromSelect = state, eventFrom = Select.value state |> Maybe.withDefault model.eventFrom }, Cmd.map FromSelect cmd )

        ToSelect inner ->
            let
                ( state, cmd ) =
                    Select.update inner model.toSelect
            in
            ( { model | toSelect = state, eventTo = Select.value state |> Maybe.withDefault model.eventTo }, Cmd.map ToSelect cmd )

        PreviewRemote state ->
            ( { model | previewRemote = state }, Cmd.none )

        Actor actor ->
            ( { model | server = Server.signIn actor model.server, actorSelect = Select.setValue (Just actor) model.actorSelect, error = Nothing }, Cmd.none )

        OwnerRole role ->
            ( { model | ownerRoleDraft = role }, Cmd.none )

        ApplyOwnerRole ->
            if not (List.any (\actor -> List.member model.ownerRoleDraft actor.roles) Server.actors) then
                ( { model | error = Just "Choose a role assigned to one of the demo sessions before applying ownership." }, Cmd.none )

            else
                let
                    d =
                        model.definition
                in
                ( { model | definition = { d | ownerRole = model.ownerRoleDraft } }, Cmd.none )

        Title title ->
            let
                d =
                    model.definition
            in
            ( { model | definition = { d | title = title } }, Cmd.none )

        Add kind ->
            let
                d =
                    model.definition

                id =
                    List.range model.nextId (model.nextId + List.length d.nodes + 1) |> List.map (\i -> "step-" ++ String.fromInt i) |> List.filter (\key -> Workflow.find key d == Nothing) |> List.head |> Maybe.withDefault ("step-" ++ String.fromInt model.nextId)

                fresh =
                    Workflow.node id kind (Workflow.kindLabel Locale.en kind)

                n =
                    if kind == Workflow.ai then
                        { fresh | outputKey = "result_" ++ String.fromInt model.nextId }

                    else
                        fresh

                anchor =
                    model.selected |> Maybe.andThen (\key -> Workflow.find key d)

                insert nodes =
                    case nodes of
                        [] ->
                            [ n ]

                        first :: rest ->
                            if Just first.id == Maybe.map .id anchor then
                                first :: n :: rest

                            else
                                first :: insert rest

                exits =
                    anchor |> Maybe.map (\a -> Workflow.outgoing a.id d) |> Maybe.withDefault []

                edges =
                    case ( anchor, exits ) of
                        ( Just a, [ exit ] ) ->
                            if a.kind /= Workflow.output && exit.maxVisits == Nothing then
                                List.map
                                    (\e ->
                                        if e.from == a.id && e.label == exit.label then
                                            { e | to = id }

                                        else
                                            e
                                    )
                                    d.edges
                                    ++ [ Workflow.edge id exit.to "Continue" ]

                            else
                                d.edges

                        _ ->
                            d.edges
            in
            ( { model | definition = { d | nodes = insert d.nodes, edges = edges }, selected = Just id, nextId = model.nextId + 1 }, Cmd.none )

        Template template ->
            ( { model
                | template = template
                , definition =
                    if template == "document" then
                        Samples.document

                    else if template == "membership" then
                        Samples.membership

                    else if template == "publication" then
                        Samples.publication

                    else
                        Samples.character
                , selected = Nothing
                , ownerRoleDraft = "designer"
              }
            , Cmd.none
            )

        Tab tab ->
            ( { model | tab = tab }, Cmd.none )

        Brief brief ->
            ( { model | brief = brief }, Cmd.none )

        Files inner ->
            let
                ( files, cmd ) =
                    FileDrop.update inner model.files

                ticket =
                    model.fileTicket + 1

                previewCmd =
                    FileDrop.rawFiles files |> List.head |> Maybe.map (File.toUrl >> Task.perform (Preview ticket)) |> Maybe.withDefault Cmd.none
            in
            ( { model | files = files, preview = Nothing, fileTicket = ticket }, Cmd.batch [ Cmd.map Files cmd, previewCmd ] )

        Preview ticket url ->
            if ticket == model.fileTicket then
                ( { model | preview = Just url }, Cmd.none )

            else
                ( model, Cmd.none )

        Start ->
            if model.pending || (Remote.toMaybe model.run |> Maybe.map (\run -> List.member run.status [ Running, Waiting, AwaitingInput, Paused ]) |> Maybe.withDefault False) || not (Server.canStart model.definition model.server) || not (List.isEmpty (Workflow.validate model.definition)) || String.isEmpty (String.trim model.brief) then
                ( model, Cmd.none )

            else
                send
                    (Server.Start model.definition
                        (Dict.fromList [ ( "brief", Encode.object [ ( "text", Encode.string model.brief ), ( "reference", model.preview |> Maybe.map Encode.string |> Maybe.withDefault Encode.null ), ( "files", Encode.list (\file -> Encode.object [ ( "name", Encode.string file.name ), ( "bytes", Encode.int file.size ) ]) (FileDrop.values model.files) ) ] ) ])
                    )
                    { model | tab = "run", inspected = Nothing }

        Arrived ticket requestActor request ->
            if ticket /= model.ticket then
                ( model, Cmd.none )

            else
                let
                    before =
                        model.server

                    ( responseServer, result ) =
                        Server.handle request { before | actor = requestActor }

                    server =
                        { responseServer | actor = before.actor }
                in
                case result of
                    Err error ->
                        let
                            latest =
                                Remote.toMaybe model.run |> Maybe.andThen (\run -> Dict.get run.id server.runs)

                            currentModel =
                                { model | server = server, pending = False, error = Just error, run = latest |> Maybe.map Remote.Loaded |> Maybe.withDefault model.run }

                            ( next, cmd ) =
                                latest |> Maybe.map (\run -> continue run currentModel) |> Maybe.withDefault ( currentModel, Cmd.none )
                        in
                        ( { next | error = Just error }, cmd )

                    Ok run ->
                        let
                            settled =
                                { model
                                    | server = server
                                    , run = Remote.Loaded run
                                    , pending = False
                                    , feedback =
                                        case request of
                                            Server.Decide _ _ _ submitted ->
                                                if model.feedback == submitted then
                                                    ""

                                                else
                                                    model.feedback

                                            _ ->
                                                model.feedback
                                }
                        in
                        continue run settled |> afterAck request

        Decide label ->
            if model.pending then
                ( model, Cmd.none )

            else
                withRun (\r -> Server.Decide r.id r.revision label model.feedback) model

        Feedback value ->
            ( { model | feedback = value }, Cmd.none )

        Inspect id ->
            ( { model | inspected = Just id }, Cmd.none )

        Pause ->
            withRun (\r -> Server.Pause r.id r.revision) model

        Resume ->
            withRun (\r -> Server.Resume r.id r.revision) model

        Cancel ->
            withRun (\r -> Server.Cancel r.id r.revision) model

        Retry ->
            withRun (\r -> Server.Retry r.id r.revision) model

        Reload ->
            withRun (\r -> Server.Load r.id) model

        LoadRun id ->
            send (Server.Load id) { model | tab = "run", inspected = Nothing }

        FailNext flag ->
            ( { model | failNext = flag }, Cmd.none )

        SaveDraft ->
            ( model, File.Download.string "workflow.json" "application/json" (Encode.encode 2 (Codec.encode Ids.string model.definition)) )

        ImportDraft ->
            ( { model | draftTicket = model.draftTicket + 1 }, File.Select.file [ "application/json" ] (DraftFile (model.draftTicket + 1)) )

        DraftFile ticket file ->
            if ticket == model.draftTicket then
                ( model, File.toString file |> Task.perform (DraftText ticket) )

            else
                ( model, Cmd.none )

        DraftText ticket source ->
            if ticket /= model.draftTicket then
                ( model, Cmd.none )

            else
                case Decode.decodeString (Codec.decoder Ids.string) source of
                    Ok definition ->
                        ( { model | definition = definition, ownerRoleDraft = definition.ownerRole, selected = Nothing, nextId = model.nextId + List.length definition.nodes + 1, tab = "build", error = Nothing }, Cmd.none )

                    Err error ->
                        ( { model | error = Just (Decode.errorToString error) }, Cmd.none )

        Export ->
            case Remote.toMaybe model.run of
                Just run ->
                    ( model, File.Download.string (run.id ++ ".json") "application/json" (Encode.encode 2 (Encode.object [ ( "id", Encode.string run.id ), ( "process", Encode.string run.definition.title ), ( "context", Encode.object (Dict.toList run.context) ), ( "attempts", Encode.list (\a -> Encode.object [ ( "node", Encode.string a.node ), ( "attempt", Encode.int a.number ), ( "outcome", Encode.string a.outcome ), ( "actor", a.actor |> Maybe.map Encode.string |> Maybe.withDefault Encode.null ), ( "result", a.result ) ]) run.attempts ) ])) )

                Nothing ->
                    ( model, Cmd.none )

        Event event ->
            ( { model | machine = Machine.transition event model.machine |> Maybe.withDefault model.machine }, Cmd.none )

        ResetMachine ->
            ( { model | machine = Samples.lifecycle, fromSelect = Select.setValue (Just "ready") model.fromSelect, toSelect = Select.setValue (Just "working") model.toSelect, eventFrom = "ready", eventTo = "working" }, Cmd.none )

        StateName name ->
            ( { model | stateName = name }, Cmd.none )

        EventName name ->
            ( { model | eventName = name }, Cmd.none )

        EventFrom id ->
            ( { model | eventFrom = id }, Cmd.none )

        EventTo id ->
            ( { model | eventTo = id }, Cmd.none )

        AddState ->
            if String.isEmpty (String.trim model.stateName) then
                ( model, Cmd.none )

            else
                let
                    machine =
                        model.machine
                in
                ( { model | machine = { machine | states = machine.states ++ [ { id = List.range 1 (List.length machine.states + 1) |> List.map (\i -> "custom-" ++ String.fromInt i) |> List.filter (\id -> not (List.any (\s -> s.id == id) machine.states)) |> List.head |> Maybe.withDefault "custom", label = model.stateName, terminal = False } ] }, stateName = "" }, Cmd.none )

        RenameState id label ->
            let
                machine =
                    model.machine
            in
            ( { model
                | machine =
                    { machine
                        | states =
                            List.map
                                (\s ->
                                    if s.id == id then
                                        { s | label = label }

                                    else
                                        s
                                )
                                machine.states
                    }
              }
            , Cmd.none
            )

        TerminalState id terminal ->
            let
                machine =
                    model.machine
            in
            ( { model
                | machine =
                    { machine
                        | states =
                            List.map
                                (\s ->
                                    if s.id == id then
                                        { s | terminal = terminal }

                                    else
                                        s
                                )
                                machine.states
                    }
              }
            , Cmd.none
            )

        RemoveState id ->
            let
                machine =
                    model.machine

                remaining =
                    List.filter (\s -> s.id /= id) machine.states
            in
            if List.isEmpty remaining then
                ( model, Cmd.none )

            else
                ( { model
                    | machine =
                        { machine
                            | states = remaining
                            , transitions = List.filter (\e -> e.from /= id && e.to /= id) machine.transitions
                            , current =
                                if machine.current == id then
                                    List.head remaining |> Maybe.map .id |> Maybe.withDefault machine.current

                                else
                                    machine.current
                        }
                    , fromSelect = Select.setValue (List.head remaining |> Maybe.map .id) model.fromSelect
                    , toSelect = Select.setValue (List.head remaining |> Maybe.map .id) model.toSelect
                    , eventFrom = List.head remaining |> Maybe.map .id |> Maybe.withDefault model.eventFrom
                    , eventTo = List.head remaining |> Maybe.map .id |> Maybe.withDefault model.eventTo
                  }
                , Cmd.none
                )

        RemoveTransition index ->
            let
                machine =
                    model.machine
            in
            ( { model | machine = { machine | transitions = machine.transitions |> List.indexedMap Tuple.pair |> List.filter (Tuple.first >> (/=) index) |> List.map Tuple.second } }, Cmd.none )

        AddTransition ->
            if String.isEmpty (String.trim model.eventName) || List.any (\t -> t.from == model.eventFrom && t.event == model.eventName) model.machine.transitions then
                ( model, Cmd.none )

            else
                let
                    machine =
                        model.machine
                in
                ( { model | machine = { machine | transitions = machine.transitions ++ [ { from = model.eventFrom, to = model.eventTo, event = model.eventName } ] }, eventName = "" }, Cmd.none )


view : Model -> Html Msg
view model =
    Layout.stack [ Layout.gap 4 ]
        [ Layout.row [ Layout.gap 3, Layout.wrap, Layout.alignCenter ]
            [ Segmented.view [ Segmented.options [ Segmented.option "build" "Build process", Segmented.option "run" "Run & inspect", Segmented.option "states" "State machines" ], Segmented.selected model.tab, Segmented.onChange Tab ]
            , Layout.spacer
            , Badge.view [ Badge.tone Info ] "Elm · simulated server"
            ]
        , Layout.row [ Layout.gap 3, Layout.wrap, Layout.alignCenter ]
            [ Layout.stack [ Layout.width 320 ] [ Select.view ActorSelect [ Select.label "Demo session", Select.options (List.map (\actor -> Select.option actor.id actor.name) Server.actors) ] model.actorSelect ]
            , Text.caption ("Roles: " ++ String.join ", " model.server.actor.roles)
            ]
        , case model.error of
            Just error ->
                Alert.view [ Alert.tone Danger ] error

            Nothing ->
                Html.text ""
        , if model.tab == "states" then
            machineView Config.empty Locale.en model

          else if model.tab == "run" then
            runView Config.empty Locale.en model

          else
            buildView Locale.en model
        ]


buildView : Locale -> Model -> Html Msg
buildView locale model =
    Layout.stack [ Layout.gap 4 ]
        [ Layout.row [ Layout.gap 3, Layout.wrap ]
            [ Segmented.view [ Segmented.options [ Segmented.option "character" "Character studio", Segmented.option "document" "Document triage", Segmented.option "publication" "Editorial desk", Segmented.option "membership" "Membership admission" ], Segmented.selected model.template, Segmented.onChange Template ]
            , Layout.spacer
            , Button.view [ Button.ghost, Button.onClick ImportDraft ] "Import JSON"
            , Button.view [ Button.secondary, Button.onClick SaveDraft ] "Save definition"
            , Button.view [ Button.primary, Button.icon Icon.play, Button.onClick (Tab "run") ] "Prepare a run"
            ]
        , TextInput.view [ TextInput.label "Process name", TextInput.value model.definition.title, TextInput.onInput Title, TextInput.disabled (not (Server.canEdit model.definition model.server)) ]
        , TextInput.view [ TextInput.label "Process designer role", TextInput.value model.ownerRoleDraft, TextInput.onInput OwnerRole, TextInput.disabled (not (Server.canEdit model.definition model.server)) ]
        , Button.view [ Button.secondary, Button.small, Button.disabled (not (Server.canEdit model.definition model.server) || model.ownerRoleDraft == model.definition.ownerRole), Button.onClick ApplyOwnerRole ] "Apply designer role"
        , builderView Config.empty locale model
        , Text.caption "Select a step, then add from the palette to insert after it. A single forward connection is rewired automatically; branches stay explicit. Each run uses a frozen definition, so edits affect the next run."
        ]


runView : Config.Config -> Locale -> Model -> Html Msg
runView config locale model =
    let
        run =
            Remote.toMaybe model.run

        live =
            run |> Maybe.map (\r -> not (List.member r.status [ Succeeded, Cancelled, Failed ])) |> Maybe.withDefault False

        setup =
            Card.view [ Card.title "Start with a human", Card.subtitle "Choose a reference and describe the desired result. The example reference is optional." ]
                [ Layout.stack [ Layout.gap 3 ]
                    [ TextArea.view [ TextArea.label "Brief / source material", TextArea.value model.brief, TextArea.onInput Brief, TextArea.rows 3 ]
                    , FileDrop.view Files [ FileDrop.label "Reference image", FileDrop.accept [ "image/*" ], FileDrop.maxFiles 1, FileDrop.maxSize 10000000 ] model.files
                    , model.preview |> Maybe.map (\url -> Html.img [ Attr.src url, Attr.alt "Selected reference", Attr.width 140, Attr.height 140 ] []) |> Maybe.withDefault (Text.caption "No reference selected. The simulated illustrator will use the brief.")
                    , Text.caption ("Process: " ++ model.definition.title ++ " · Start role: " ++ (List.head model.definition.nodes |> Maybe.map .performerRole |> Maybe.withDefault "unassigned"))
                    , if Server.canStart model.definition model.server then
                        Html.text ""

                      else
                        Alert.view [ Alert.tone Info, Alert.compact ] "Switch the demo session to the assigned start role to start this process."
                    , Checkbox.view [ Checkbox.label "Fail the next AI task (test recovery)", Checkbox.checked model.failNext, Checkbox.onCheck FailNext ]
                    , Button.view [ Button.primary, Button.icon Icon.play, Button.disabled (not (Server.canStart model.definition model.server) || model.pending || live || String.isEmpty (String.trim model.brief) || not (List.isEmpty (Workflow.validate model.definition))), Button.onClick Start ] "Start process"
                    , if List.isEmpty (Workflow.validate model.definition) then
                        Html.text ""

                      else
                        Alert.view [ Alert.tone Warning ] "The draft has validation errors. Return to Build process before starting."
                    ]
                ]

        controls r =
            Layout.row [ Layout.gap 2, Layout.wrap ]
                [ Button.view [ Button.secondary, Button.onClick Pause, Button.disabled (not (Server.canControl r model.server) || not (List.member r.status [ Running, Waiting, AwaitingInput ])) ] "Pause"
                , Button.view [ Button.secondary, Button.onClick Resume, Button.disabled (not (Server.canControl r model.server) || r.status /= Paused || model.pending) ] "Resume"
                , Button.view [ Button.secondary, Button.onClick Retry, Button.disabled (not (Server.canControl r model.server) || r.status /= Failed || model.pending) ] "Retry failed step"
                , Button.view [ Button.ghost, Button.danger, Button.onClick Cancel, Button.disabled (not (Server.canControl r model.server) || List.member r.status [ Succeeded, Cancelled ] || (r.status == Paused && model.pending)) ] "Cancel run"
                , Layout.spacer
                , Button.view [ Button.ghost, Button.onClick Export ] "Export results"
                ]

        review r =
            if r.status == AwaitingInput then
                Card.view [ Card.title "Your decision", Card.subtitle (Engine.current r |> Maybe.map .instructions |> Maybe.withDefault "Choose the next path.") ]
                    [ Layout.stack [ Layout.gap 3 ]
                        [ Text.caption ("Assigned role: " ++ (Engine.current r |> Maybe.map Server.requiredRole |> Maybe.withDefault "—"))
                        , if Server.canDecide r model.server then
                            Html.text ""

                          else
                            Alert.view [ Alert.tone Warning ] "This step is waiting for its assigned role. Switch the demo session above to act as that person."
                        , TextArea.view [ TextArea.label "Notes / feedback", TextArea.value model.feedback, TextArea.onInput Feedback, TextArea.rows 2, TextArea.disabled model.pending ]
                        , Layout.row [ Layout.gap 2, Layout.wrap ] (List.map (\e -> Button.view [ Button.primary, Button.disabled (model.pending || not (Server.canDecide r model.server)), Button.onClick (Decide e.label) ] e.label) (Engine.available r))
                        , Text.caption "A return disappears when its traversal budget is exhausted. Approve remains available."
                        ]
                    ]

            else
                Html.text ""

        thumbnails r =
            if List.isEmpty (Server.artifacts r) then
                Html.text ""

            else
                Card.view [ Card.title "Character sheet", Card.subtitle (String.fromInt (List.length (Server.artifacts r)) ++ " simulated illustrations · inspect consistency before approving") ]
                    [ Layout.grid [ Layout.minColumn 120, Layout.gap 3 ]
                        (List.map (\a -> Html.figure [ Attr.style "margin" "0" ] [ Html.img [ Attr.src a.preview, Attr.alt ("Simulated character: " ++ a.label), Attr.style "width" "100%" ] [], Html.figcaption [] [ Html.text a.label ] ]) (Server.artifacts r))
                    ]
    in
    Layout.stack [ Layout.gap 4 ]
        ([ if run == Nothing then
            setup

           else
            Html.details [] [ Html.summary [] [ Html.text "Inputs for the next run" ], setup ]
         ]
            ++ (if Dict.isEmpty model.server.runs then
                    []

                else
                    [ Layout.row [ Layout.gap 2, Layout.wrap ] (Dict.values model.server.runs |> List.map (\r -> Button.view [ Button.ghost, Button.small, Button.disabled model.pending, Button.onClick (LoadRun r.id) ] (r.id ++ " · " ++ r.definition.title))) ]
               )
            ++ (run |> Maybe.map (\r -> [ controls r, review r, Html.div [ Attr.id "process-run-focus", Attr.tabindex -1 ] [ Runner.view (Options.klarWorkflowRun config [ Runner.locale locale, Runner.selected model.inspected, Runner.onSelect Inspect ]) r ], thumbnails r ]) |> Maybe.withDefault [ Text.paragraph "Start the process to watch server work, inspect each step's state and review its outputs." ])
        )


machineView : Config.Config -> Locale -> Model -> Html Msg
machineView config locale model =
    let
        choose label toMsg state =
            Select.view toMsg [ Select.label label, Select.options (List.map (\s -> Select.option s.id s.label) model.machine.states) ] state
    in
    Layout.stack [ Layout.gap 4 ]
        [ Text.paragraph "A step has a lifecycle of its own. Build states and event-labelled transitions, then run them by choosing enabled events. Terminal states have no outgoing actions."
        , Machine.view (Options.klarStateMachine config [ Machine.locale locale, Machine.onTransition Event ]) model.machine
        , Layout.grid [ Layout.minColumn 250, Layout.gap 4 ]
            [ Card.view [ Card.title "Add a state" ] [ TextInput.view [ TextInput.label "State name", TextInput.value model.stateName, TextInput.onInput StateName ], Button.view [ Button.secondary, Button.disabled (String.isEmpty (String.trim model.stateName)), Button.onClick AddState ] "Add state" ]
            , Card.view [ Card.title "Connect states" ]
                [ Layout.stack [ Layout.gap 3 ]
                    [ choose "From" FromSelect model.fromSelect
                    , choose "To" ToSelect model.toSelect
                    , TextInput.view [ TextInput.label "Event", TextInput.value model.eventName, TextInput.onInput EventName ]
                    , Button.view [ Button.secondary, Button.disabled (String.isEmpty (String.trim model.eventName)), Button.onClick AddTransition ] "Add transition"
                    ]
                ]
            ]
        , Card.view [ Card.title "State definitions" ]
            [ Layout.grid [ Layout.minColumn 220, Layout.gap 4 ]
                (List.map
                    (\s ->
                        Layout.stack [ Layout.gap 2 ]
                            [ TextInput.view [ TextInput.id ("state-name-" ++ s.id), TextInput.label "State label", TextInput.value s.label, TextInput.onInput (RenameState s.id) ]
                            , Checkbox.view [ Checkbox.id ("state-terminal-" ++ s.id), Checkbox.label "Terminal", Checkbox.checked s.terminal, Checkbox.onCheck (TerminalState s.id) ]
                            , Button.view [ Button.ghost, Button.small, Button.disabled (List.length model.machine.states <= 1), Button.onClick (RemoveState s.id) ] "Remove state"
                            ]
                    )
                    model.machine.states
                )
            ]
        , Card.view [ Card.title "Transition definitions" ]
            [ Layout.stack [ Layout.gap 2 ]
                (List.indexedMap
                    (\index e ->
                        Layout.row [ Layout.gap 2, Layout.wrap ]
                            [ Text.paragraph (e.from ++ " — " ++ e.event ++ " → " ++ e.to)
                            , Button.view [ Button.ghost, Button.small, Button.onClick (RemoveTransition index) ] "Remove transition"
                            ]
                    )
                    model.machine.transitions
                )
            ]
        , Button.view [ Button.ghost, Button.onClick ResetMachine ] "Reset lifecycle example"
        ]


componentView : Config.Config -> Locale -> Model -> Html Msg
componentView config locale model =
    if config.component == "" then
        Doc.page { title = "Processes & state", description = "Build and run AI, human and approval workflows. Each component has its own page in the sidebar." } [ processExample "Process studio" (view model) ]

    else
        Doc.configuredPage config
            { title = "Processes & state", description = "Vertical definitions, human checkpoints, bounded loops and observable execution." }
            [ Doc.configuredSection config [ "Workflow", "Workflow.Engine", "Workflow.Codec" ] "Process studio" "Build, execute and inspect four complete workflows. Server responses and illustrations are simulated." [ processExample "Process studio" (view model) ]
            , Doc.configuredSection config [ "WorkflowBuilder" ] "Workflow builder" "Select nodes, edit bindings and instructions, add branches and bounded returns." [ processExample "Editable process" (builderView config locale model) ]
            , Doc.configuredSection config [ "WorkflowNode" ] "Node vocabulary" "Seven standard node kinds, usable in your own diagrams." [ processExample "Standard nodes" (Layout.grid [ Layout.minColumn 220, Layout.gap 3 ] (List.map (\kind -> Node.view (Options.klarWorkflowNode config [ Node.locale locale, Node.status "Ready" ]) (Workflow.node (Workflow.kindKey kind) kind (Workflow.kindLabel locale kind))) Workflow.kinds)) ]
            , Doc.configuredSection config [ "WorkflowRun" ] "Execution inspector" "Start a real simulated run, pause it and inspect intermediate state." [ processExample "Run a process" (runView config locale model), processExample "Remote snapshots" (runnerPreview config locale model) ]
            , Doc.configuredSection config [ "StateMachine" ] "State machine" "Build and exercise a node's lifecycle." [ processExample "Build a lifecycle" (machineView config locale model) ]
            ]


builderView : Config.Config -> Locale -> Model -> Html Msg
builderView config locale model =
    Html.div [ Attr.id "process-builder-focus", Attr.tabindex -1 ]
        [ Builder.view Ids.string (Options.klarWorkflowBuilder config [ Builder.locale locale, Builder.selected model.selected, Builder.onSelect Select, Builder.onAdd Add, Builder.onChange Change, Builder.readOnly (not (Server.canEdit model.definition model.server)) ]) model.definition ]


processExample : String -> Html Msg -> Html Msg
processExample title content =
    Doc.example { title = title, description = Nothing, code = Nothing } content


runnerPreview : Config.Config -> Locale -> Model -> Html Msg
runnerPreview config locale model =
    let
        sample =
            Engine.start "preview-001" Samples.character (Dict.singleton "brief" (Encode.string "Reference brief")) |> Result.map (Engine.complete Encode.null >> Engine.complete (Encode.string "Simulated result")) |> Result.toMaybe

        remote run =
            case model.previewRemote of
                "loading" ->
                    Remote.Loading

                "failed" ->
                    Remote.Failed (Remote.problem Remote.network)

                "refreshing" ->
                    Remote.refresh (Remote.Loaded run)

                "stale" ->
                    Remote.settle (Remote.Loaded run) (Err (Remote.problem Remote.network))

                _ ->
                    Remote.Loaded run
    in
    Layout.stack [ Layout.gap 3 ]
        [ Text.subheading "Remote snapshot states"
        , Segmented.view [ Segmented.label "Snapshot state", Segmented.options (List.map (\name -> Segmented.option name name) [ "loaded", "loading", "failed", "refreshing", "stale" ]), Segmented.selected model.previewRemote, Segmented.onChange PreviewRemote ]
        , sample |> Maybe.map (\run -> Html.div [ Attr.id "workflow-preview-focus", Attr.tabindex -1 ] [ Runner.viewRemote (Options.klarWorkflowRun config [ Runner.id "workflow-preview", Runner.locale locale, Runner.onRetry RetryPreview ]) (remote run) ]) |> Maybe.withDefault (Html.text "")
        ]
