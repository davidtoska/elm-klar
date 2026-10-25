module Klar.WorkflowNode exposing (view, Attribute, locale, onSelect, selected, status, detail)

{-| A compact, selectable workflow step with a kind, status and input/output ports.

Use when: composing process diagrams or a palette of reusable nodes.
Do not use when: editing a whole workflow; use `Klar.WorkflowBuilder`.

    import Klar.Workflow as Workflow
    import Klar.WorkflowNode as Node

    Node.view [ Node.onSelect SelectStep ]
        (Workflow.node "draw" Workflow.ai "Generate illustrations")

@docs view, Attribute, locale, onSelect, selected, status, detail

-}

import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Events
import Klar.Icon as Icon
import Klar.Locale as Locale exposing (Locale)
import Klar.Workflow as Workflow exposing (Node)


{-| Node appearance and selection handler. Later settings win.
-}
type Attribute msg
    = Attribute (Config msg -> Config msg)


type alias Config msg =
    { locale : Locale, onSelect : Maybe msg, selected : Bool, status : String, detail : String }


{-| Built-in language, English by default.
-}
locale : Locale -> Attribute msg
locale value =
    Attribute (\c -> { c | locale = value })


{-| Make the node a keyboard-accessible button that sends this message.
-}
onSelect : msg -> Attribute msg
onSelect value =
    Attribute (\c -> { c | onSelect = Just value })


{-| Mark the inspected node, false by default.
-}
selected : Bool -> Attribute msg
selected value =
    Attribute (\c -> { c | selected = value })


{-| Host-supplied, localized status text, empty by default.
-}
status : String -> Attribute msg
status value =
    Attribute (\c -> { c | status = value })


{-| Host-supplied summary, such as attempt or artifact count.
-}
detail : String -> Attribute msg
detail value =
    Attribute (\c -> { c | detail = value })


{-| Render a node. Kind and status are written in words as well as shown visually.
-}
view : List (Attribute msg) -> Node id -> Html msg
view attributes n =
    let
        c =
            List.foldl (\(Attribute f) acc -> f acc) { locale = Locale.default, onSelect = Nothing, selected = False, status = "", detail = "" } attributes

        tag =
            if c.onSelect == Nothing then
                Html.div

            else
                Html.button

        ports =
            List.filter ((/=) "") [ n.inputKey, n.outputKey ] |> String.join " → "
    in
    tag
        ([ Attr.classList [ ( "klar-workflow-node", True ), ( "klar-workflow-node--selected", c.selected ) ]
         , Attr.attribute "data-kind" (Workflow.kindKey n.kind)
         ]
            ++ (case c.onSelect of
                    Nothing ->
                        []

                    Just msg ->
                        [ Attr.type_ "button"
                        , Events.onClick msg
                        , Attr.attribute "aria-pressed"
                            (if c.selected then
                                "true"

                             else
                                "false"
                            )
                        ]
               )
        )
        [ Html.span [ Attr.class "klar-workflow-node__icon" ] [ Icon.view (Workflow.kindIcon n.kind) ]
        , Html.span [ Attr.class "klar-workflow-node__body" ]
            [ Html.span [ Attr.class "klar-workflow-node__kind" ] [ Html.text (Workflow.kindLabel c.locale n.kind) ]
            , Html.strong [] [ Html.text n.title ]
            , Html.span [ Attr.class "klar-workflow-node__detail" ]
                [ Html.text
                    (Locale.pick c.locale { en = "Role: ", nb = "Rolle: " }
                        ++ (if n.kind == Workflow.human then
                                n.approverRole

                            else
                                n.performerRole
                           )
                    )
                ]
            , Html.span [ Attr.class "klar-workflow-node__ports" ] [ Html.text ports ]
            , Html.span [ Attr.class "klar-workflow-node__detail" ] [ Html.text c.detail ]
            ]
        , Html.span [ Attr.class "klar-workflow-node__status" ] [ Html.text c.status ]
        ]
