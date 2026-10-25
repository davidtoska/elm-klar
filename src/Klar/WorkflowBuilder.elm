module Klar.WorkflowBuilder exposing (view, Attribute, locale, selected, onSelect, onAdd, onChange, readOnly, id)

{-| A controlled, vertical workflow editor with a node palette, explicit branches,
bounded return arrows and an inspector for the selected node.

Use when: people graphically compose AI/human processes without an infinite canvas.
Do not use when: following an executing instance; use `Klar.WorkflowRun`.

    import Klar.Ids as Ids
    import Klar.WorkflowBuilder as Builder

    Builder.view Ids.string
        [ Builder.selected model.selected
        , Builder.onSelect SelectNode
        , Builder.onAdd AddNode
        , Builder.onChange ChangeDefinition
        ]
        model.definition

The application owns the definition, selection and new identifiers. Changes are
emitted as a complete proposed definition. The editor never repairs invalid
input; validation remains visible and execution can be blocked by the host.
Connection labels, endpoints and loop budgets are editable in the inspector.

@docs view, Attribute, locale, selected, onSelect, onAdd, onChange, readOnly, id

-}

import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Events
import Klar.Button as Button
import Klar.Ids as Ids exposing (Ids)
import Klar.Internal as Internal
import Klar.Locale as Locale exposing (Locale)
import Klar.TextArea as TextArea
import Klar.TextInput as TextInput
import Klar.Workflow as Workflow exposing (Definition, Kind, Node)
import Klar.WorkflowNode as WorkflowNode


{-| Controlled editor options. All callbacks are absent by default.
-}
type Attribute id msg
    = Attribute (Config id msg -> Config id msg)


type alias Config id msg =
    { locale : Locale, selected : Maybe id, onSelect : Maybe (id -> msg), onAdd : Maybe (Kind -> msg), onChange : Maybe (Definition id -> msg), readOnly : Bool, namespace : String }


{-| Built-in language, English by default.
-}
locale : Locale -> Attribute id msg
locale value =
    Attribute (\c -> { c | locale = value })


{-| Identifier of the inspected step, absent by default.
-}
selected : Maybe id -> Attribute id msg
selected value =
    Attribute (\c -> { c | selected = value })


{-| Receive the identifier of a clicked step or connection destination.
-}
onSelect : (id -> msg) -> Attribute id msg
onSelect value =
    Attribute (\c -> { c | onSelect = Just value })


{-| Receive a kind from the palette. Allocate an identifier in the application.
-}
onAdd : (Kind -> msg) -> Attribute id msg
onAdd value =
    Attribute (\c -> { c | onAdd = Just value })


{-| Receive a complete edited definition. Save/version it in your application.
-}
onChange : (Definition id -> msg) -> Attribute id msg
onChange value =
    Attribute (\c -> { c | onChange = Just value })


{-| Disable design mutations while keeping inspection available. Default false.
-}
readOnly : Bool -> Attribute id msg
readOnly value =
    Attribute (\c -> { c | readOnly = value })


{-| Unique DOM id and prefix for inspector fields. Defaults to `workflow-builder`;
set a distinct id for each editor on the same page. The root can receive focus.
-}
id : String -> Attribute id msg
id value =
    Attribute (\c -> { c | namespace = value })


{-| The editor. Each node is an ordinary button; all edits work with a keyboard.
The supplied `Ids` writes/reads the application's own node identifiers.
-}
view : Ids id -> List (Attribute id msg) -> Definition id -> Html msg
view ids attributes definition =
    let
        c =
            List.foldl (\(Attribute f) acc -> f acc) { locale = Locale.default, selected = Nothing, onSelect = Nothing, onAdd = Nothing, onChange = Nothing, readOnly = False, namespace = "workflow-builder" } attributes

        tr en nb =
            Locale.pick c.locale { en = en, nb = nb }

        editable =
            not c.readOnly && c.onChange /= Nothing

        selectNode n =
            case c.onSelect of
                Just send ->
                    [ WorkflowNode.onSelect (send n.id) ]

                Nothing ->
                    []

        titleOf key =
            Workflow.find key definition |> Maybe.map .title |> Maybe.withDefault (Ids.toKey ids key)

        position key =
            definition.nodes |> List.indexedMap Tuple.pair |> List.filter (Tuple.second >> .id >> (==) key) |> List.head |> Maybe.map (Tuple.first >> (+) 1) |> Maybe.withDefault 1

        returnRails =
            definition.edges |> List.filter (\e -> e.maxVisits /= Nothing && position e.to < position e.from) |> List.map (\e -> Html.li [ Attr.class "klar-workflow-builder__return-rail", Attr.attribute "aria-hidden" "true", Internal.styleVars [ ( "--klar-workflow-row", String.fromInt (position e.to) ), ( "--klar-workflow-end", String.fromInt (position e.from + 1) ) ] ] [])

        nodeRow index n =
            Html.li [ Attr.class "klar-workflow-builder__step", Internal.styleVars [ ( "--klar-workflow-row", String.fromInt (index + 1) ) ] ]
                [ WorkflowNode.view ([ WorkflowNode.locale c.locale, WorkflowNode.selected (c.selected == Just n.id) ] ++ selectNode n) n
                , Html.div [ Attr.class "klar-workflow-builder__edges" ]
                    (List.map
                        (\e ->
                            Html.div [ Attr.classList [ ( "klar-workflow-builder__edge", True ), ( "klar-workflow-builder__edge--return", e.maxVisits /= Nothing ) ] ]
                                [ Html.span [ Attr.attribute "aria-hidden" "true" ]
                                    [ Html.text
                                        (if e.maxVisits == Nothing then
                                            "↓"

                                         else
                                            "↰"
                                        )
                                    ]
                                , Button.view
                                    ([ Button.ghost, Button.small ]
                                        ++ (case c.onSelect of
                                                Just send ->
                                                    [ Button.onClick (send e.to) ]

                                                Nothing ->
                                                    [ Button.disabled True ]
                                           )
                                    )
                                    (e.label ++ " → " ++ titleOf e.to)
                                , Html.small [] [ Html.text (e.maxVisits |> Maybe.map (\limit -> tr "max " "maks " ++ String.fromInt limit) |> Maybe.withDefault "") ]
                                ]
                        )
                        (Workflow.outgoing n.id definition)
                    )
                ]

        inspect n =
            inspector ids c editable definition n
    in
    Html.div [ Attr.class "klar-workflow-builder", Attr.id c.namespace, Attr.tabindex -1 ]
        [ Html.aside [ Attr.class "klar-workflow-builder__palette", Attr.attribute "aria-label" (tr "Node palette" "Stegpalett") ]
            [ Html.h3 [] [ Html.text (tr "Add a step" "Legg til steg") ]
            , Html.div [ Attr.class "klar-workflow-builder__kinds" ]
                (List.map
                    (\kind ->
                        Button.view
                            ([ Button.secondary, Button.small, Button.icon (Workflow.kindIcon kind), Button.disabled (c.readOnly || c.onAdd == Nothing) ]
                                ++ (case c.onAdd of
                                        Just send ->
                                            [ Button.onClick (send kind) ]

                                        Nothing ->
                                            []
                                   )
                            )
                            (Workflow.kindLabel c.locale kind)
                    )
                    Workflow.kinds
                )
            , Html.p [] [ Html.text (tr "Select a step to edit its instructions, state and transitions." "Velg et steg for å redigere instruksjoner, tilstand og overganger.") ]
            ]
        , Html.div [ Attr.class "klar-workflow-builder__canvas" ]
            [ Html.div [ Attr.class "klar-workflow-builder__caption" ] [ Html.text (tr "PROCESS DEFINITION" "PROSESSDEFINISJON") ]
            , Html.h3 [] [ Html.text definition.title ]
            , Html.ol [ Attr.class "klar-workflow-builder__steps", Attr.attribute "aria-label" (tr "Process steps" "Prosessens steg") ] (List.indexedMap nodeRow definition.nodes ++ returnRails)
            ]
        , Html.aside [ Attr.class "klar-workflow-builder__inspector", Attr.attribute "aria-label" (tr "Step inspector" "Steginspektør") ]
            (case c.selected |> Maybe.andThen (\key -> Workflow.find key definition) of
                Just n ->
                    inspect n

                Nothing ->
                    [ Html.h3 [] [ Html.text (tr "Step inspector" "Steginspektør") ], Html.p [] [ Html.text (tr "Select a node to begin." "Velg et steg for å begynne.") ] ]
            )
        , Html.div [ Attr.class "klar-workflow-builder__validation", Attr.attribute "role" "status" ]
            [ Html.ul [] (List.map (\issue -> Html.li [] [ Html.text (Workflow.issueText c.locale definition issue) ]) (Workflow.validate definition)) ]
        ]


inspector : Ids id -> Config id msg -> Bool -> Definition id -> Node id -> List (Html msg)
inspector ids c editable definition n =
    let
        tr en nb =
            Locale.pick c.locale { en = en, nb = nb }

        emit transform =
            c.onChange |> Maybe.map (\send -> send (transform definition))

        field label value transform =
            TextInput.view
                ([ TextInput.id (c.namespace ++ "-" ++ String.replace " " "-" label), TextInput.label label, TextInput.value value, TextInput.disabled (not editable) ]
                    ++ (case c.onChange of
                            Just send ->
                                [ TextInput.onInput
                                    (\value_ ->
                                        send
                                            { definition
                                                | nodes =
                                                    List.map
                                                        (\old ->
                                                            if old.id == n.id then
                                                                transform value_ old

                                                            else
                                                                old
                                                        )
                                                        definition.nodes
                                            }
                                    )
                                ]

                            Nothing ->
                                []
                       )
                )
    in
    [ Html.h3 [] [ Html.text (tr "Step inspector" "Steginspektør") ]
    , field (tr "Title" "Navn") n.title (\value old -> { old | title = value })
    , TextArea.view
        ([ TextArea.id (c.namespace ++ "-instructions"), TextArea.label (tr "Instructions / condition" "Instruksjoner / betingelse"), TextArea.value n.instructions, TextArea.rows 5, TextArea.disabled (not editable) ]
            ++ (case c.onChange of
                    Just send ->
                        [ TextArea.onInput
                            (\value ->
                                send
                                    { definition
                                        | nodes =
                                            List.map
                                                (\old ->
                                                    if old.id == n.id then
                                                        { old | instructions = value }

                                                    else
                                                        old
                                                )
                                                definition.nodes
                                    }
                            )
                        ]

                    Nothing ->
                        []
               )
        )
    , TextArea.view
        ([ TextArea.id (c.namespace ++ "-state"), TextArea.label (tr "Initial state (JSON object)" "Starttilstand (JSON-objekt)"), TextArea.value n.state, TextArea.rows 4, TextArea.disabled (not editable) ]
            ++ (case c.onChange of
                    Just send ->
                        [ TextArea.onInput
                            (\value ->
                                send
                                    { definition
                                        | nodes =
                                            List.map
                                                (\old ->
                                                    if old.id == n.id then
                                                        { old | state = value }

                                                    else
                                                        old
                                                )
                                                definition.nodes
                                    }
                            )
                        ]

                    Nothing ->
                        []
               )
        )
    , field (tr "Performer role" "Utførende rolle") n.performerRole (\value old -> { old | performerRole = value })
    , field (tr "Approver role" "Godkjennende rolle") n.approverRole (\value old -> { old | approverRole = value })
    , field (tr "Input binding" "Input-binding") n.inputKey (\value old -> { old | inputKey = value })
    , field (tr "Output binding" "Resultat-binding") n.outputKey (\value old -> { old | outputKey = value })
    , case c.onChange of
        Just send ->
            if n.kind == Workflow.wait then
                Html.label [ Attr.class "klar-workflow-builder__field" ]
                    [ Html.span [] [ Html.text (tr "Wait seconds" "Ventetid i sekunder") ]
                    , Html.select
                        [ Attr.value (String.fromInt n.waitSeconds)
                        , Attr.disabled (not editable)
                        , Events.onInput
                            (\value ->
                                send
                                    { definition
                                        | nodes =
                                            List.map
                                                (\old ->
                                                    if old.id == n.id then
                                                        { old | waitSeconds = String.toInt value |> Maybe.withDefault old.waitSeconds }

                                                    else
                                                        old
                                                )
                                                definition.nodes
                                    }
                            )
                        ]
                        (List.map (\seconds -> Html.option [ Attr.value (String.fromInt seconds), Attr.selected (n.waitSeconds == seconds) ] [ Html.text (String.fromInt seconds) ]) (n.waitSeconds :: List.filter ((/=) n.waitSeconds) [ 0, 1, 2, 5, 10, 30, 60 ]))
                    ]

            else
                Html.text ""

        Nothing ->
            Html.text ""
    , case c.onChange of
        Just send ->
            Html.label [ Attr.class "klar-workflow-builder__field" ]
                [ Html.span [] [ Html.text (tr "Step kind" "Type steg") ]
                , Html.select
                    [ Attr.value (Workflow.kindKey n.kind)
                    , Attr.disabled (not editable)
                    , Events.onInput
                        (\value ->
                            send
                                { definition
                                    | nodes =
                                        List.map
                                            (\old ->
                                                if old.id == n.id then
                                                    { old | kind = List.filter (Workflow.kindKey >> (==) value) Workflow.kinds |> List.head |> Maybe.withDefault old.kind }

                                                else
                                                    old
                                            )
                                            definition.nodes
                                }
                        )
                    ]
                    (List.map (\kind -> Html.option [ Attr.value (Workflow.kindKey kind), Attr.selected (n.kind == kind) ] [ Html.text (Workflow.kindLabel c.locale kind) ]) Workflow.kinds)
                ]

        Nothing ->
            Html.text ""
    , Html.div [ Attr.class "klar-workflow-builder__reorder" ]
        (List.map
            (\( offset, label ) ->
                Button.view
                    ([ Button.ghost, Button.small, Button.disabled (not editable || (offset < 0 && (List.head definition.nodes |> Maybe.map .id) == Just n.id) || (offset > 0 && (List.reverse definition.nodes |> List.head |> Maybe.map .id) == Just n.id)) ]
                        ++ (emit
                                (\d ->
                                    let
                                        index =
                                            d.nodes |> List.indexedMap Tuple.pair |> List.filter (\( _, old ) -> old.id == n.id) |> List.head |> Maybe.map Tuple.first |> Maybe.withDefault 0

                                        destination =
                                            index + offset

                                        at i =
                                            List.drop i d.nodes |> List.head
                                    in
                                    if destination < 0 || destination >= List.length d.nodes then
                                        d

                                    else
                                        { d
                                            | nodes =
                                                List.indexedMap
                                                    (\i old ->
                                                        if i == index then
                                                            at destination |> Maybe.withDefault old

                                                        else if i == destination then
                                                            n

                                                        else
                                                            old
                                                    )
                                                    d.nodes
                                        }
                                )
                                |> Maybe.map Button.onClick
                                |> Maybe.map List.singleton
                                |> Maybe.withDefault []
                           )
                    )
                    label
            )
            [ ( -1, tr "Move up" "Flytt opp" ), ( 1, tr "Move down" "Flytt ned" ) ]
        )
    , Html.h4 [] [ Html.text (tr "Transitions" "Overganger") ]
    , Html.div [ Attr.class "klar-workflow-builder__transitions" ]
        (definition.edges |> List.indexedMap Tuple.pair |> List.filter (\( _, e ) -> e.from == n.id) |> List.map (\( index, e ) -> connectionEditor ids c editable definition index e))
    , Button.view
        ([ Button.small, Button.secondary, Button.disabled (not editable) ]
            ++ (emit (\d -> { d | edges = d.edges ++ [ Workflow.edge n.id (List.reverse d.nodes |> List.head |> Maybe.map .id |> Maybe.withDefault n.id) (tr "New path" "Ny vei" ++ " " ++ String.fromInt (List.length d.edges + 1)) ] }) |> Maybe.map Button.onClick |> Maybe.map List.singleton |> Maybe.withDefault [])
        )
        (tr "Add connection" "Legg til forbindelse")
    , Button.view
        ([ Button.small, Button.ghost, Button.disabled (not editable) ]
            ++ (emit (\d -> { d | nodes = List.filter (\old -> old.id /= n.id) d.nodes, edges = List.filter (\e -> e.from /= n.id && e.to /= n.id) d.edges }) |> Maybe.map Button.onClick |> Maybe.map List.singleton |> Maybe.withDefault [])
        )
        (tr "Delete step" "Slett steg")
    ]


connectionEditor : Ids id -> Config id msg -> Bool -> Definition id -> Int -> Workflow.Edge id -> Html msg
connectionEditor ids c editable definition index e =
    let
        tr en nb =
            Locale.pick c.locale { en = en, nb = nb }

        editor send =
            let
                change transform =
                    send
                        { definition
                            | edges =
                                List.indexedMap
                                    (\i old ->
                                        if i == index then
                                            transform old

                                        else
                                            old
                                    )
                                    definition.edges
                        }
            in
            [ TextInput.view [ TextInput.id (c.namespace ++ "-path-" ++ Ids.toKey ids e.from ++ "-" ++ String.fromInt index), TextInput.label (tr "Path label" "Navn på vei"), TextInput.value e.label, TextInput.disabled (not editable), TextInput.onInput (\value -> change (\old -> { old | label = value })) ]
            , Html.label [ Attr.class "klar-workflow-builder__field" ]
                [ Html.span [] [ Html.text (tr "Destination" "Mål") ]
                , Html.select [ Attr.value (Ids.toKey ids e.to), Attr.disabled (not editable), Events.onInput (\key -> change (\old -> { old | to = Ids.fromKey ids key |> Maybe.withDefault old.to })) ]
                    (List.map (\target -> Html.option [ Attr.value (Ids.toKey ids target.id), Attr.selected (target.id == e.to) ] [ Html.text target.title ]) definition.nodes)
                ]
            , Html.label [ Attr.class "klar-workflow-builder__field" ]
                [ Html.span [] [ Html.text (tr "Traversal limit" "Grense for passeringer") ]
                , Html.select [ Attr.value (e.maxVisits |> Maybe.map String.fromInt |> Maybe.withDefault ""), Attr.disabled (not editable), Events.onInput (\value -> change (\old -> { old | maxVisits = String.toInt value })) ]
                    (Html.option [ Attr.value "", Attr.selected (e.maxVisits == Nothing) ] [ Html.text (tr "Forward (unlimited)" "Fremover (ubegrenset)") ]
                        :: List.map (\limit -> Html.option [ Attr.value (String.fromInt limit), Attr.selected (e.maxVisits == Just limit) ] [ Html.text (tr "Maximum " "Maks " ++ String.fromInt limit) ]) ((e.maxVisits |> Maybe.map List.singleton |> Maybe.withDefault []) ++ List.filter (\limit -> Just limit /= e.maxVisits) (List.range 1 10))
                    )
                ]
            , Button.view [ Button.ghost, Button.small, Button.disabled (not editable), Button.onClick (send { definition | edges = List.indexedMap Tuple.pair definition.edges |> List.filter (Tuple.first >> (/=) index) |> List.map Tuple.second }) ] (tr "Remove connection" "Fjern forbindelse")
            ]
    in
    Html.div [ Attr.class "klar-workflow-builder__connection" ] (c.onChange |> Maybe.map editor |> Maybe.withDefault [ Html.text e.label ])
