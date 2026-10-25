module Showcase.Workflows exposing (character, document, lifecycle, membership, publication)

{-| Copyable workflow templates. The server evaluates work; human/condition
branches remain explicit. These are deliberately smaller than BPMN.
-}

import Klar.StateMachine exposing (Machine)
import Klar.Workflow as W exposing (Definition)


character : Definition String
character =
    { ownerRole = "designer"
    , title = "Character studio"
    , nodes =
        [ W.node "brief" W.input "Reference image & creative brief" |> configure "" "brief" "Describe the character, intended audience and visual style."
        , W.node "generate" W.ai "Generate twelve character views" |> configure "brief" "character_sheet" "Create a consistent comic character from the reference. Produce twelve views and expressions. Keep the same silhouette, costume and palette. Incorporate review feedback on subsequent attempts."
        , W.node "review" W.human "Review identity & consistency" |> configure "character_sheet" "" "Inspect every view. Approve the sheet or send specific feedback to the illustrator. At most two revision rounds."
        , W.node "package" W.wait "Prepare the character package"
        , W.node "deliver" W.output "Character sheet ready" |> configure "character_sheet" "delivery" "Deliver the approved images and the character brief."
        ]
    , edges = [ W.edge "brief" "generate" "Start illustration", W.edge "generate" "review" "Review results", W.edge "review" "package" "Approve", W.loop 2 "review" "generate" "Revise", W.edge "package" "deliver" "Deliver" ]
    }


document : Definition String
document =
    { ownerRole = "designer"
    , title = "Document triage"
    , nodes =
        [ W.node "brief" W.input "Receive the document" |> configure "" "brief" "Paste a document excerpt and describe the classification rules."
        , W.node "analyse" W.ai "Extract facts & propose a category" |> configure "brief" "analysis" "Extract key facts, propose a category and state uncertainty. Do not invent missing evidence."
        , W.node "route" W.decision "Choose a route by confidence" |> configure "analysis" "" "Simulation: inspect the analysis and explicitly choose a route. A real server would evaluate the confidence condition."
        , W.node "review" W.human "Resolve uncertain evidence" |> configure "analysis" "" "Check the facts against the source. Approve or request another analysis."
        , W.node "deliver" W.output "Classification ready" |> configure "analysis" "classification" "Return the approved analysis."
        ]
    , edges = [ W.edge "brief" "analyse" "Analyse", W.edge "analyse" "route" "Check confidence", W.edge "route" "deliver" "High confidence", W.edge "route" "review" "Needs review", W.edge "review" "deliver" "Approve", W.loop 1 "review" "analyse" "Investigate again" ]
    }


publication : Definition String
publication =
    { ownerRole = "designer"
    , title = "Editorial desk"
    , nodes =
        [ W.node "brief" W.input "Topic, audience & sources" |> configure "" "brief" "Describe the audience and provide source material."
        , W.node "draft" W.ai "Draft an evidence-based article" |> configure "brief" "article" "Write a short article using only the supplied sources. Apply editorial feedback when it exists."
        , W.node "review" W.human "Editorial sign-off" |> configure "article" "" "Check tone and claims. Approve or request a revision."
        , W.node "hold" W.wait "Wait for the publication window"
        , W.node "deliver" W.output "Publication package" |> configure "article" "package" "Prepare a package; this simulation does not publish anything."
        ]
    , edges = [ W.edge "brief" "draft" "Write", W.edge "draft" "review" "Request sign-off", W.edge "review" "hold" "Approve", W.loop 3 "review" "draft" "Revise", W.edge "hold" "deliver" "Prepare package" ]
    }


membership : Definition String
membership =
    let
        assigned performer approver n =
            { n | performerRole = performer, approverRole = approver }
    in
    { title = "Membership admission"
    , ownerRole = "designer"
    , nodes =
        [ W.node "application" W.input "Receive a membership application" |> configure "" "application" "Record the applicant's request and consent to the membership process." |> assigned "coordinator" "coordinator"
        , W.node "interview" W.task "Conduct the membership interview" |> configure "application" "interview_notes" "The assigned interviewer meets the applicant. Record the interview notes and recommend whether to proceed." |> assigned "interviewer" "interviewer"
        , W.node "recommendation" W.human "Membership coordinator's recommendation" |> configure "interview_notes" "recommendation" "Review the interview evidence. Recommend admission, request another interview or close the application." |> assigned "coordinator" "coordinator"
        , W.node "director" W.human "Managing director's approval" |> configure "recommendation" "director_decision" "The managing director decides. Return the recommendation once for clarification, approve admission or decline." |> assigned "director" "director"
        , W.node "enroll" W.task "Enroll the approved member" |> configure "director_decision" "membership" "Only the registrar may enroll the applicant after director approval. Record a membership reference in the task notes." |> assigned "registrar" "registrar"
        , W.node "welcome" W.output "Member enrolled" |> configure "membership" "receipt" "Return the enrollment receipt. This simulation does not create a real member."
        , W.node "closed" W.output "Application closed" |> configure "application" "closure" "Record the decision and the reason without enrolling the applicant."
        ]
    , edges =
        [ W.edge "application" "interview" "Schedule interview"
        , W.edge "interview" "recommendation" "Submit interview"
        , W.edge "recommendation" "director" "Recommend admission"
        , W.loop 1 "recommendation" "interview" "Interview again"
        , W.edge "recommendation" "closed" "Close application"
        , W.edge "director" "enroll" "Approve admission"
        , W.loop 1 "director" "recommendation" "Request clarification"
        , W.edge "director" "closed" "Decline admission"
        , W.edge "enroll" "welcome" "Confirm enrollment"
        ]
    }


configure : String -> String -> String -> W.Node id -> W.Node id
configure inputKey outputKey instructions n =
    { n
        | inputKey = inputKey
        , outputKey = outputKey
        , instructions = instructions
        , state =
            if outputKey == "character_sheet" then
                "{\"imageCount\":12,\"style\":\"comic\",\"preserveIdentity\":true}"

            else
                "{}"
    }


lifecycle : Machine String
lifecycle =
    { states = [ { id = "ready", label = "Ready", terminal = False }, { id = "working", label = "Working", terminal = False }, { id = "review", label = "In review", terminal = False }, { id = "done", label = "Done", terminal = True } ]
    , transitions = [ { from = "ready", to = "working", event = "Start" }, { from = "working", to = "review", event = "Submit" }, { from = "review", to = "working", event = "Revise" }, { from = "review", to = "done", event = "Approve" } ]
    , current = "ready"
    }
