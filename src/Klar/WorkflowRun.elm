module Klar.WorkflowRun exposing (view, viewRemote, Attribute, locale, selected, onSelect, onRetry, id)

{-| Live execution diagram, context and attempt history for a workflow snapshot.

Use when: a person needs to see which step is active and inspect intermediate results.
Do not use when: editing a definition; use `Klar.WorkflowBuilder`.

    import Klar.WorkflowRun as Runner

    Runner.view [ Runner.onSelect InspectStep ] run

The host owns decisions and server commands. This component only inspects data.
`viewRemote` also retains existing nodes through refreshing and failed refreshes.

@docs view, viewRemote, Attribute, locale, selected, onSelect, onRetry, id

-}

import Dict
import Html exposing (Html)
import Html.Attributes as Attr
import Json.Decode as Decode
import Json.Encode as Encode
import Klar.Locale as Locale exposing (Locale)
import Klar.Remote exposing (Remote)
import Klar.RemoteView as RemoteView
import Klar.Workflow as Workflow
import Klar.Workflow.Engine as Engine exposing (Run, Status(..))
import Klar.WorkflowNode as Node


{-| Inspector selection, language and remote retry settings.
-}
type Attribute id msg
    = Attribute (Config id msg -> Config id msg)


type alias Config id msg =
    { locale : Locale, selected : Maybe id, onSelect : Maybe (id -> msg), onRetry : Maybe msg, id : Maybe String }


configure : List (Attribute id msg) -> Config id msg
configure attributes =
    List.foldl (\(Attribute f) c -> f c) { locale = Locale.default, selected = Nothing, onSelect = Nothing, onRetry = Nothing, id = Nothing } attributes


{-| Built-in language, English by default.
-}
locale : Locale -> Attribute id msg
locale value =
    Attribute (\c -> { c | locale = value })


{-| Node whose attempt results are expanded. The active node is used by default.
-}
selected : Maybe id -> Attribute id msg
selected value =
    Attribute (\c -> { c | selected = value })


{-| Receive the inspected node identifier.
-}
onSelect : (id -> msg) -> Attribute id msg
onSelect value =
    Attribute (\c -> { c | onSelect = Just value })


{-| Retry a failed remote request; the host reloads the snapshot.
-}
onRetry : msg -> Attribute id msg
onRetry value =
    Attribute (\c -> { c | onRetry = Just value })


{-| Unique focus target, including remote loading and failure states.
-}
id : String -> Attribute id msg
id value =
    Attribute (\c -> { c | id = Just value })


{-| A remote run, with loading, failure, data, refreshing and old-data states.
-}
viewRemote : List (Attribute id msg) -> Remote (Run id) -> Html msg
viewRemote attributes remote =
    let
        c =
            configure attributes
    in
    Html.div []
        (RemoteView.view
            ([ RemoteView.locale c.locale ]
                ++ (c.id |> Maybe.map RemoteView.id |> Maybe.map List.singleton |> Maybe.withDefault [])
                ++ (c.onRetry |> Maybe.map RemoteView.onRetry |> Maybe.map List.singleton |> Maybe.withDefault [])
            )
            remote
            (\run -> [ render { c | id = Nothing } run ])
        )


statusText : Locale -> Status -> String
statusText language status =
    Locale.pick language
        (case status of
            Running ->
                { en = "Running", nb = "Kjører" }

            AwaitingInput ->
                { en = "Needs your decision", nb = "Trenger din vurdering" }

            Waiting ->
                { en = "Waiting", nb = "Venter" }

            Paused ->
                { en = "Paused", nb = "Satt på pause" }

            Succeeded ->
                { en = "Completed", nb = "Fullført" }

            Failed ->
                { en = "Failed", nb = "Feilet" }

            Cancelled ->
                { en = "Cancelled", nb = "Avbrutt" }
        )


{-| Draw the actual snapshot, attempts and named context. Revisited nodes retain
all their outputs and the active node is marked with `aria-current`.
-}
view : List (Attribute id msg) -> Run id -> Html msg
view attributes run =
    render (configure attributes) run


render : Config id msg -> Run id -> Html msg
render c run =
    let
        tr en nb =
            Locale.pick c.locale { en = en, nb = nb }

        target =
            case c.selected of
                Just value ->
                    Just value

                Nothing ->
                    run.active

        nodeView n =
            let
                attempts =
                    List.filter (\a -> a.node == n.id) run.attempts

                active =
                    run.active == Just n.id

                status =
                    if active then
                        statusText c.locale run.status

                    else if List.isEmpty attempts then
                        tr "Not reached" "Ikke nådd"

                    else if List.any (\s -> s.node == n.id && s.output == Nothing) run.nodeStates then
                        tr "Needs new result" "Trenger nytt resultat"

                    else
                        tr "Visited" "Besøkt"
            in
            Html.li
                ([ Attr.classList [ ( "klar-workflow-run__step", True ), ( "klar-workflow-run__step--active", active ) ] ]
                    ++ (if active then
                            [ Attr.attribute "aria-current" "step" ]

                        else
                            []
                       )
                )
                [ Node.view
                    ([ Node.locale c.locale, Node.selected (target == Just n.id), Node.status status, Node.detail (String.fromInt (List.length attempts) ++ tr " recorded attempts" " registrerte forsøk") ]
                        ++ (c.onSelect |> Maybe.map (\send -> Node.onSelect (send n.id)) |> Maybe.map List.singleton |> Maybe.withDefault [])
                    )
                    n
                , Html.div [ Attr.class "klar-workflow-run__routes" ]
                    (List.map
                        (\e ->
                            Html.span []
                                [ Html.text
                                    ((if e.maxVisits == Nothing then
                                        "↓ "

                                      else
                                        "↰ "
                                     )
                                        ++ e.label
                                        ++ " → "
                                        ++ (Workflow.find e.to run.definition |> Maybe.map .title |> Maybe.withDefault "?")
                                        ++ (e.maxVisits |> Maybe.map (\limit -> " · " ++ tr "max " "maks " ++ String.fromInt limit) |> Maybe.withDefault "")
                                    )
                                ]
                        )
                        (Workflow.outgoing n.id run.definition)
                    )
                ]

        history =
            run.attempts |> List.filter (\a -> target == Nothing || Just a.node == target)

        json value =
            Html.pre [ Attr.class "klar-workflow-run__json" ] [ Html.code [] [ Html.text (Encode.encode 2 (displayValue value)) ] ]
    in
    Html.section
        ([ Attr.class "klar-workflow-run" ] ++ (c.id |> Maybe.map (\value -> [ Attr.id value, Attr.tabindex -1 ]) |> Maybe.withDefault []))
        [ Html.header [ Attr.class "klar-workflow-run__header" ]
            [ Html.strong [] [ Html.text run.definition.title ]
            , Html.span [ Attr.attribute "role" "status", Attr.attribute "aria-live" "polite" ] [ Html.text (run.id ++ " · " ++ statusText c.locale run.status) ]
            ]
        , Html.div [ Attr.class "klar-workflow-run__layout" ]
            [ Html.ol [ Attr.class "klar-workflow-run__steps", Attr.attribute "aria-label" (tr "Execution steps" "Steg i kjøringen") ] (List.map nodeView run.definition.nodes)
            , Html.aside [ Attr.class "klar-workflow-run__inspector" ]
                [ Html.h3 [] [ Html.text (tr "Step results" "Resultater fra steg") ]
                , Html.p [] [ Html.text (target |> Maybe.andThen (\key -> Workflow.find key run.definition) |> Maybe.map .title |> Maybe.withDefault (tr "All attempts" "Alle forsøk")) ]
                , if List.isEmpty history then
                    Html.p [] [ Html.text (tr "No result yet. Results appear after a server acknowledgement." "Ingen resultater ennå. Resultater vises når serveren har bekreftet dem.") ]

                  else
                    Html.div [] (List.map (\a -> Html.details [] [ Html.summary [] [ Html.text (tr "Attempt " "Forsøk " ++ String.fromInt a.number ++ " · " ++ a.outcome ++ (a.actor |> Maybe.map ((++) " · ") |> Maybe.withDefault "")) ], json a.result ]) history)
                , Html.h3 [] [ Html.text (tr "Node state" "Stegets tilstand") ]
                , Html.div [] (run.nodeStates |> List.filter (\s -> target == Just s.node) |> List.map (\s -> json (Encode.object [ ( "initial", s.config ), ( "output", s.output |> Maybe.withDefault Encode.null ) ])))
                , Html.h3 [] [ Html.text (tr "Process context" "Prosessens kontekst") ]
                , json (Encode.object (Dict.toList run.context))
                , case run.error of
                    Just message ->
                        Html.p [ Attr.attribute "role" "alert" ] [ Html.text message ]

                    Nothing ->
                        Html.text ""
                ]
            ]
        ]



-- Inline image payloads stay intact in the run, but are abbreviated in the inspector.


displayValue : Encode.Value -> Encode.Value
displayValue value =
    case Decode.decodeValue Decode.string value of
        Ok text ->
            if String.length text > 400 then
                Encode.string (String.left 160 text ++ " … [" ++ String.fromInt (String.length text) ++ " characters]")

            else
                value

        Err _ ->
            case Decode.decodeValue (Decode.keyValuePairs Decode.value) value of
                Ok pairs ->
                    Encode.object (List.map (\( key, child ) -> ( key, displayValue child )) pairs)

                Err _ ->
                    case Decode.decodeValue (Decode.list Decode.value) value of
                        Ok children ->
                            Encode.list displayValue children

                        Err _ ->
                            value
