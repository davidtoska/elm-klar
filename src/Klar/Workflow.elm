module Klar.Workflow exposing
    ( Definition, Node, Edge, node, edge, loop
    , Kind, input, ai, human, task, decision, wait, output, kinds, kindKey, kindLabel, kindIcon
    , Issue, validate, issueText, find, outgoing
    )

{-| Ordered workflow definitions shared by a builder, a runner and a server.

Use when: people design processes with AI work, review, branches and bounded returns.
Do not use when: only a form's progress is needed; use `Klar.Stepper`.

    import Klar.Workflow as Workflow

    draft =
        { title = "Illustration"
        , ownerRole = "designer"
        , nodes =
            [ Workflow.node "brief" Workflow.input "Collect a brief"
            , Workflow.node "draw" Workflow.ai "Draw a character"
            , Workflow.node "done" Workflow.output "Deliver artwork"
            ]
        , edges =
            [ Workflow.edge "brief" "draw" "Continue"
            , Workflow.edge "draw" "done" "Continue"
            ]
        }

The list of nodes is the visual order. Every connection is explicit. A return
must have a positive traversal limit; this makes every accepted cycle bounded.
Definitions are plain data, suitable for encoding in your own API.

@docs Definition, Node, Edge, node, edge, loop
@docs Kind, input, ai, human, task, decision, wait, output, kinds, kindKey, kindLabel, kindIcon
@docs Issue, validate, issueText, find, outgoing

-}

import Json.Decode as Decode
import Klar.Icon as Icon exposing (Icon)
import Klar.Locale as Locale exposing (Locale)


{-| A versionable design. Running instances should keep their own snapshot.
-}
type alias Definition id =
    { title : String, nodes : List (Node id), edges : List (Edge id), ownerRole : String }


{-| A step's instructions, input binding, output binding and simulated wait in seconds.
An empty input binding means that no named input is required.
-}
type alias Node id =
    { id : id, kind : Kind, title : String, instructions : String, inputKey : String, outputKey : String, waitSeconds : Int, state : String, performerRole : String, approverRole : String }


{-| An explicitly labelled transition. `maxVisits` limits traversals of this edge,
not attempts at the destination. `Nothing` is only valid for forward edges.
-}
type alias Edge id =
    { from : id, to : id, label : String, maxVisits : Maybe Int }


{-| Standard node with blank instructions and bindings and a two-second wait.
-}
node : id -> Kind -> String -> Node id
node id kind title =
    { id = id, kind = kind, title = title, instructions = "", inputKey = "", outputKey = "", waitSeconds = 2, state = "{}", performerRole = "operator", approverRole = "reviewer" }


{-| A forward transition, chosen by its unique label at a branch.
-}
edge : id -> id -> String -> Edge id
edge from to label =
    { from = from, to = to, label = label, maxVisits = Nothing }


{-| A bounded return. Invalid limits remain visible to `validate`.
-}
loop : Int -> id -> id -> String -> Edge id
loop limit from to label =
    { from = from, to = to, label = label, maxVisits = Just limit }


{-| Extensible vocabulary of standard steps; compare values or use `kindKey`.
-}
type Kind
    = Input
    | Ai
    | Human
    | Task
    | Decision
    | Wait
    | Output


{-| A person supplies the initial context.
-}
input : Kind
input =
    Input


{-| Server-side AI work with instructions and named input/output.
-}
ai : Kind
ai =
    Ai


{-| A person reviews artifacts and chooses a transition.
-}
human : Kind
human =
    Human


{-| A manual task performed by its assigned role, such as an interview or enrollment.
-}
task : Kind
task =
    Task


{-| An explicit choice between labelled paths. The host evaluates its condition.
-}
decision : Kind
decision =
    Decision


{-| A server-owned delay or external wait.
-}
wait : Kind
wait =
    Wait


{-| A terminal step which delivers the resulting context.
-}
output : Kind
output =
    Output


{-| All standard kinds in palette order.
-}
kinds : List Kind
kinds =
    [ input, ai, human, task, decision, wait, output ]


{-| Stable machine name, suitable for your JSON protocol.
-}
kindKey : Kind -> String
kindKey kind =
    case kind of
        Input ->
            "input"

        Ai ->
            "ai"

        Human ->
            "human"

        Task ->
            "task"

        Decision ->
            "decision"

        Wait ->
            "wait"

        Output ->
            "output"


{-| Localized palette label.
-}
kindLabel : Locale -> Kind -> String
kindLabel locale kind =
    Locale.pick locale
        (case kind of
            Input ->
                { en = "Human input", nb = "Menneskelig input" }

            Ai ->
                { en = "AI task", nb = "AI-oppgave" }

            Human ->
                { en = "Human review", nb = "Menneskelig vurdering" }

            Task ->
                { en = "Human task", nb = "Menneskelig oppgave" }

            Decision ->
                { en = "Branch", nb = "Forgrening" }

            Wait ->
                { en = "Wait", nb = "Vent" }

            Output ->
                { en = "Output", nb = "Resultat" }
        )


{-| Icon matching the standard kind.
-}
kindIcon : Kind -> Icon
kindIcon kind =
    case kind of
        Input ->
            Icon.upload

        Ai ->
            Icon.zap

        Human ->
            Icon.user

        Task ->
            Icon.clipboardCheck

        Decision ->
            Icon.gitBranch

        Wait ->
            Icon.clock

        Output ->
            Icon.checkCircle


{-| One structural problem, scoped to a node when possible.
-}
type Issue id
    = Issue (Maybe id) String


{-| Localized structural error. Node titles are included in the message.
-}
issueText : Locale -> Definition id -> Issue id -> String
issueText locale definition (Issue target code) =
    let
        prefix =
            target |> Maybe.andThen (\id -> find id definition) |> Maybe.map (\n -> n.title ++ ": ") |> Maybe.withDefault ""

        message =
            case code of
                "start" ->
                    { en = "Use exactly one human input as the first step.", nb = "Bruk nøyaktig ett menneskelig input som første steg." }

                "end" ->
                    { en = "Add an output step.", nb = "Legg til et resultatsteg." }

                "duplicate" ->
                    { en = "Node identifiers must be unique.", nb = "Steg må ha unike ID-er." }

                "missing" ->
                    { en = "A connection refers to a missing step.", nb = "En forbindelse peker til et steg som mangler." }

                "loop" ->
                    { en = "Return connections need a positive limit.", nb = "Tilbakekoblinger må ha en positiv grense." }

                "labels" ->
                    { en = "Outgoing connections need unique, nonempty labels.", nb = "Utgående forbindelser må ha unike, utfylte navn." }

                "unreachable" ->
                    { en = "This step cannot be reached from the start.", nb = "Dette steget kan ikke nås fra starten." }

                "terminal" ->
                    { en = "An output cannot have outgoing connections.", nb = "Et resultat kan ikke ha utgående forbindelser." }

                "branch" ->
                    { en = "A branch needs at least two outgoing connections.", nb = "En forgrening trenger minst to utgående forbindelser." }

                "binding" ->
                    { en = "AI tasks need a named output.", nb = "AI-oppgaver trenger et navngitt resultat." }

                "entry" ->
                    { en = "The initial input cannot be revisited. Use a human task to collect more input.", nb = "Startinput kan ikke besøkes på nytt. Bruk en menneskelig oppgave for å hente mer input." }

                "reserved" ->
                    { en = "The feedback binding is reserved for workflow review notes.", nb = "Bindingen feedback er reservert for vurderingsnotater i prosessen." }

                "outputKey" ->
                    { en = "Each named output must belong to exactly one step.", nb = "Hvert navngitte resultat må tilhøre nøyaktig ett steg." }

                "deadEnd" ->
                    { en = "This step has no path to an output.", nb = "Dette steget har ingen vei til et resultat." }

                "role" ->
                    { en = "Assign an owner and an acting role for every human step.", nb = "Velg en eierrolle og en utførende rolle for alle menneskelige steg." }

                "state" ->
                    { en = "Initial state must be a JSON object.", nb = "Starttilstand m� v�re et JSON-objekt." }

                "wait" ->
                    { en = "Wait duration must be a nonnegative whole number.", nb = "Ventetid må være et ikke-negativt heltall." }

                "title" ->
                    { en = "Give the process and every step a title.", nb = "Gi prosessen og alle steg et navn." }

                _ ->
                    { en = "Connect this step to its next step.", nb = "Koble dette steget til neste steg." }
    in
    prefix ++ Locale.pick locale message


{-| Find a step using the application's own identifier.
-}
find : id -> Definition id -> Maybe (Node id)
find id definition =
    List.filter (\n -> n.id == id) definition.nodes |> List.head


{-| Connections in declaration order, which is also the order of branch buttons.
-}
outgoing : id -> Definition id -> List (Edge id)
outgoing id definition =
    List.filter (\e -> e.from == id) definition.edges


{-| Check start/end nodes, reachability, labels, bindings and bounded cycles.
No repair or clamping is performed. An empty list means the design is executable.
-}
validate : Definition id -> List (Issue id)
validate definition =
    let
        ids =
            List.map .id definition.nodes

        position id =
            List.indexedMap Tuple.pair ids |> List.filter (Tuple.second >> (==) id) |> List.head |> Maybe.map Tuple.first |> Maybe.withDefault -1

        check flag target code =
            if flag then
                [ Issue target code ]

            else
                []

        visit edges remaining reached =
            if remaining <= 0 then
                reached

            else
                let
                    next =
                        List.filter (\e -> List.member e.from reached) edges |> List.map .to
                in
                visit edges
                    (remaining - 1)
                    (List.foldl
                        (\id acc ->
                            if List.member id acc then
                                acc

                            else
                                id :: acc
                        )
                        reached
                        next
                    )

        reachable =
            visit definition.edges (List.length ids) (List.take 1 ids)

        canFinish =
            visit (List.map (\e -> { e | from = e.to, to = e.from }) definition.edges) (List.length ids) (definition.nodes |> List.filter (\n -> n.kind == output) |> List.map .id)

        perNode n =
            let
                exits =
                    outgoing n.id definition

                labels =
                    List.map .label exits
            in
            check (String.isEmpty (String.trim n.title)) (Just n.id) "title"
                ++ check (not (List.member n.id reachable)) (Just n.id) "unreachable"
                ++ check (not (List.member n.id canFinish)) (Just n.id) "deadEnd"
                ++ check (n.outputKey == "feedback") (Just n.id) "reserved"
                ++ check (n.outputKey /= "" && List.length (List.filter (\other -> other.outputKey == n.outputKey) definition.nodes) > 1) (Just n.id) "outputKey"
                ++ check (n.kind == output && not (List.isEmpty exits)) (Just n.id) "terminal"
                ++ check (n.kind /= output && List.isEmpty exits) (Just n.id) "next"
                ++ check (n.kind == decision && List.length exits < 2) (Just n.id) "branch"
                ++ check (n.kind == ai && String.isEmpty (String.trim n.outputKey)) (Just n.id) "binding"
                ++ check (Result.toMaybe (Decode.decodeString (Decode.dict Decode.value) n.state) == Nothing) (Just n.id) "state"
                ++ check ((n.kind == human && String.isEmpty (String.trim n.approverRole)) || (List.member n.kind [ input, task, decision ] && String.isEmpty (String.trim n.performerRole))) (Just n.id) "role"
                ++ check (n.waitSeconds < 0) (Just n.id) "wait"
                ++ check (List.any (String.trim >> String.isEmpty) labels || List.any (\label -> List.length (List.filter ((==) label) labels) > 1) labels) (Just n.id) "labels"

        perEdge e =
            check ((find e.to definition |> Maybe.map .kind) == Just input) (Just e.from) "entry"
                ++ check (not (List.member e.from ids && List.member e.to ids)) (Just e.from) "missing"
                ++ check ((position e.to <= position e.from && e.maxVisits == Nothing) || Maybe.withDefault False (Maybe.map ((>=) 0) e.maxVisits)) (Just e.from) "loop"
    in
    check (String.isEmpty (String.trim definition.title)) Nothing "title"
        ++ check (String.isEmpty (String.trim definition.ownerRole)) Nothing "role"
        ++ check (List.length (List.filter (\n -> n.kind == input) definition.nodes) /= 1 || (List.head definition.nodes |> Maybe.map .kind) /= Just input) Nothing "start"
        ++ check (not (List.any (\n -> n.kind == output) definition.nodes)) Nothing "end"
        ++ check (List.any (\id -> List.length (List.filter ((==) id) ids) > 1) ids) Nothing "duplicate"
        ++ List.concatMap perNode definition.nodes
        ++ List.concatMap perEdge definition.edges
