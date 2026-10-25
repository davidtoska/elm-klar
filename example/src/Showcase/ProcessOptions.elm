module Showcase.ProcessOptions exposing (klarStateMachine, klarWorkflowBuilder, klarWorkflowNode, klarWorkflowRun)

import Klar.Locale as Locale
import Klar.StateMachine as KlarStateMachine
import Klar.WorkflowBuilder as KlarWorkflowBuilder
import Klar.WorkflowNode as KlarWorkflowNode
import Klar.WorkflowRun as KlarWorkflowRun
import Showcase.Config as Config exposing (Config)


klarWorkflowNode : Config -> List (KlarWorkflowNode.Attribute msg) -> List (KlarWorkflowNode.Attribute msg)
klarWorkflowNode config original =
    original
        ++ List.filterMap identity
            [ Config.get config "WorkflowNode" "locale" |> Maybe.andThen (\value -> Locale.fromCode value |> Maybe.map KlarWorkflowNode.locale)
            , Config.get config "WorkflowNode" "selected" |> Maybe.andThen (\value -> Just (value == "True") |> Maybe.map KlarWorkflowNode.selected)
            , Config.get config "WorkflowNode" "status" |> Maybe.andThen (\value -> Just value |> Maybe.map KlarWorkflowNode.status)
            , Config.get config "WorkflowNode" "detail" |> Maybe.andThen (\value -> Just value |> Maybe.map KlarWorkflowNode.detail)
            ]


klarWorkflowBuilder : Config -> List (KlarWorkflowBuilder.Attribute id msg) -> List (KlarWorkflowBuilder.Attribute id msg)
klarWorkflowBuilder config original =
    original
        ++ List.filterMap identity
            [ Config.get config "WorkflowBuilder" "id" |> Maybe.map KlarWorkflowBuilder.id
            , Config.get config "WorkflowBuilder" "locale" |> Maybe.andThen (\value -> Locale.fromCode value |> Maybe.map KlarWorkflowBuilder.locale)
            , Config.get config "WorkflowBuilder" "readOnly" |> Maybe.andThen (\value -> Just (value == "True") |> Maybe.map KlarWorkflowBuilder.readOnly)
            ]


klarWorkflowRun : Config -> List (KlarWorkflowRun.Attribute id msg) -> List (KlarWorkflowRun.Attribute id msg)
klarWorkflowRun config original =
    original
        ++ List.filterMap identity
            [ Config.get config "WorkflowRun" "locale" |> Maybe.andThen (\value -> Locale.fromCode value |> Maybe.map KlarWorkflowRun.locale)
            , Config.get config "WorkflowRun" "id" |> Maybe.andThen (\value -> Just value |> Maybe.map KlarWorkflowRun.id)
            ]


klarStateMachine : Config -> List (KlarStateMachine.Attribute msg) -> List (KlarStateMachine.Attribute msg)
klarStateMachine config original =
    original
        ++ List.filterMap identity
            [ Config.get config "StateMachine" "locale" |> Maybe.andThen (\value -> Locale.fromCode value |> Maybe.map KlarStateMachine.locale)
            ]
