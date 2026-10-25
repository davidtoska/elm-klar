module Page.Gallery.Ai exposing (Model, Msg, init, subscriptions, update, view)

{-| A simulated application server: versioned review, statement discussion and
ticketed streaming. No provider or network request is used by this demonstration.
-}

import Dict exposing (Dict)
import Html exposing (Html)
import Klar
import Klar.AiChat as Chat
import Klar.AiReview as Review
import Klar.Button as Button
import Klar.Card as Card
import Klar.CommentThread as Thread
import Klar.Ids as Ids
import Klar.Layout as Layout
import Klar.Locale exposing (Locale)
import Klar.Remote as Remote exposing (Remote)
import Klar.Settings exposing (Settings)
import Klar.Text as Text
import Process
import Showcase.Config as Config
import Showcase.Doc as Doc
import Showcase.Options as Options
import Task
import Time


type alias Discussion =
    { state : Thread.State, comments : List (Thread.Comment Int) }


type alias Turn =
    { id : Int, role : Chat.Role, author : String, body : String }


type alias Model =
    { review : Review.State
    , proposals : Remote (List (Review.Proposal String))
    , version : Int
    , saving : Bool
    , failSave : Bool
    , saveError : Maybe String
    , saveTicket : Int
    , result : String
    , delivery : String
    , priority : String
    , discussions : Dict String Discussion
    , chat : Chat.State
    , turns : List Turn
    , status : Chat.Status
    , run : Int
    , nextId : Int
    , responseId : Int
    , failGeneration : Bool
    }


type Msg
    = ReviewMsg Review.Msg
    | Save (List (Review.Decision String))
    | Saved Int Int Bool (List (Review.Decision String))
    | Revise
    | Load String
    | RetryReview
    | FailSave
    | ThreadMsg String Thread.Msg
    | Post String (Thread.Submission Int)
    | ChatMsg Chat.Msg
    | Send Chat.Submission
    | Chunk Int Int
    | Stop
    | RetryChat
    | FailGeneration
    | NoOp


init : ( Model, Cmd Msg )
init =
    ( { review = Review.init "ai-proposal-review"
      , proposals = Remote.Loaded (proposals 1)
      , version = 1
      , saving = False
      , failSave = False
      , saveError = Nothing
      , saveTicket = 0
      , result = "No decisions saved."
      , delivery = "Deliver to the Bergen warehouse."
      , priority = "Standard"
      , discussions = Dict.empty
      , chat = Chat.init "ai-conversation"
      , turns = [ { id = 1, role = Chat.Assistant, author = "Operations assistant", body = "I can **propose** changes and explain their sources. Review each suggestion below before your server applies it.\n\nWhat would you like to investigate?" } ]
      , status = Chat.Idle
      , run = 0
      , nextId = 2
      , responseId = 0
      , failGeneration = False
      }
    , Cmd.none
    )


proposals : Int -> List (Review.Proposal String)
proposals version =
    [ Review.proposal
        { id = "delivery"
        , revision = "delivery-v" ++ String.fromInt version
        , title = "Update the delivery instructions"
        , before = "Deliver to the Bergen warehouse."
        , after =
            if version == 1 then
                "Deliver to the Oslo warehouse. Call the receiving desk."

            else
                "Deliver to the Oslo warehouse after 10:00. Call the receiving desk."
        , rationale = "The customer's latest message names Oslo. Verify the receiving hours before applying. This proposal only changes the delivery note; it does not book or send a shipment."
        , sources = [ Review.source { label = "Customer message · demo evidence", url = "#/orders", excerpt = "Please use our Oslo warehouse for the next delivery. Call the receiving desk when you arrive." } ]
        }
    , Review.proposal
        { id = "priority"
        , revision = "priority-v1"
        , title = "Mark the customer as priority"
        , before = "Standard"
        , after = "Priority"
        , rationale = "The draft suggests priority because the delivery is urgent. No customer agreement or policy has been retrieved to support this change. Consider rejecting it and asking for evidence."
        , sources = []
        }
    ]


threadFor : String -> Model -> Discussion
threadFor key model =
    Dict.get key model.discussions |> Maybe.withDefault { state = Thread.init ("ai-discussion-" ++ key), comments = [] }


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        ReviewMsg inner ->
            let
                ( state, cmd ) =
                    Review.update inner model.review
            in
            ( { model | review = state }, Cmd.map ReviewMsg cmd )

        Save decisions ->
            if model.saving || Review.decisions Ids.string model.proposals model.review /= Just decisions then
                ( model, Cmd.none )

            else
                ( { model | saving = True, saveError = Nothing, saveTicket = model.saveTicket + 1, failSave = False }
                , Process.sleep 1200 |> Task.perform (always (Saved (model.saveTicket + 1) model.version model.failSave decisions))
                )

        Saved ticket version fails decisions ->
            if ticket /= model.saveTicket then
                ( model, Cmd.none )

            else if version /= model.version then
                ( { model | saving = False, saveError = Just "Revision conflict: the server received a newer proposal. Review the current version." }, Cmd.none )

            else if fails then
                ( { model | saving = False, saveError = Just "The server could not save the review. Your decisions and notes are retained. Try again." }, Cmd.none )

            else
                let
                    approved =
                        List.filter .approved decisions |> List.length

                    rejected =
                        List.length decisions - approved

                    accepts id =
                        List.any (\decision -> decision.id == id && decision.approved) decisions
                in
                ( { model
                    | saving = False
                    , saveError = Nothing
                    , proposals = Remote.Loaded []
                    , review = Review.reset model.review
                    , delivery =
                        if accepts "delivery" then
                            if version == 1 then
                                "Deliver to the Oslo warehouse. Call the receiving desk."

                            else
                                "Deliver to the Oslo warehouse after 10:00. Call the receiving desk."

                        else
                            model.delivery
                    , priority =
                        if accepts "priority" then
                            "Priority"

                        else
                            model.priority
                    , result = "Server acknowledged: " ++ String.fromInt approved ++ " approved, " ++ String.fromInt rejected ++ " rejected. Only approved changes were applied in this simulation."
                  }
                , Cmd.none
                )

        Revise ->
            ( { model | version = model.version + 1, proposals = Remote.Loaded (proposals (model.version + 1)), result = "The server issued a new delivery proposal. Its previous decision no longer counts." }, Cmd.none )

        Load state ->
            ( { model
                | proposals =
                    case state of
                        "loading" ->
                            Remote.Loading

                        "failed" ->
                            Remote.Failed (Remote.problem Remote.network)

                        "empty" ->
                            Remote.Loaded []

                        "refreshing" ->
                            Remote.refresh (Remote.Loaded (proposals model.version))

                        "stale" ->
                            Remote.settle (Remote.Loaded (proposals model.version)) (Err (Remote.problem Remote.network))

                        _ ->
                            Remote.Loaded (proposals model.version)
              }
            , Cmd.none
            )

        RetryReview ->
            ( { model | proposals = Remote.Loaded (proposals model.version) }, Klar.focus "ai-proposal-review" NoOp )

        FailSave ->
            ( { model | failSave = not model.failSave }, Cmd.none )

        ThreadMsg key inner ->
            let
                thread =
                    threadFor key model

                ( state, cmd ) =
                    Thread.update inner thread.state
            in
            ( { model | discussions = Dict.insert key { thread | state = state } model.discussions }, Cmd.map (ThreadMsg key) cmd )

        Post key sent ->
            let
                thread =
                    threadFor key model

                comment =
                    Thread.comment { id = List.length thread.comments + 1, author = "You", body = Thread.submissionBody sent, at = Time.millisToPosix 1792922400000 }

                entry =
                    Maybe.map (\parent -> Thread.replyTo parent comment) (Thread.submissionParent sent) |> Maybe.withDefault comment
            in
            ( { model | discussions = Dict.insert key { state = Thread.acknowledge sent thread.state, comments = thread.comments ++ [ entry ] } model.discussions }, Cmd.none )

        ChatMsg inner ->
            let
                ( state, cmd ) =
                    Chat.update inner model.chat
            in
            ( { model | chat = state }, Cmd.map ChatMsg cmd )

        Send sent ->
            if model.status == Chat.Generating then
                ( model, Cmd.none )

            else
                let
                    next =
                        { model | chat = Chat.acknowledge sent model.chat, turns = model.turns ++ [ { id = model.nextId, role = Chat.User, author = "You", body = Chat.submissionText sent } ], nextId = model.nextId + 1 }
                in
                startGeneration next

        Chunk run count ->
            if run /= model.run || model.status /= Chat.Generating then
                ( model, Cmd.none )

            else if model.failGeneration && count == 3 then
                ( { model | status = Chat.Failed "The simulated server connection closed.", failGeneration = False }, Cmd.none )

            else
                let
                    answer =
                        "I found **two proposed changes**.\n\n1. Update the delivery instructions using the customer's message.\n2. Change the customer's priority, which currently has **no supporting source**.\n\nReview each statement, add a comment where evidence is missing, and approve or reject it. Your server checks the reviewed revisions before applying any approved change."

                    complete =
                        count * 28 >= String.length answer

                    turns =
                        List.map
                            (\turn ->
                                if turn.id == model.responseId then
                                    { turn | body = String.left (count * 28) answer }

                                else
                                    turn
                            )
                            model.turns
                in
                ( { model
                    | turns = turns
                    , status =
                        if complete then
                            Chat.Idle

                        else
                            Chat.Generating
                  }
                , if complete then
                    Cmd.none

                  else
                    Process.sleep 180 |> Task.perform (always (Chunk run (count + 1)))
                )

        Stop ->
            ( { model | run = model.run + 1, status = Chat.Interrupted }, Cmd.none )

        RetryChat ->
            if model.status == Chat.Generating then
                ( model, Cmd.none )

            else
                startGeneration model

        FailGeneration ->
            ( { model | failGeneration = not model.failGeneration }, Cmd.none )

        NoOp ->
            ( model, Cmd.none )


startGeneration : Model -> ( Model, Cmd Msg )
startGeneration model =
    ( { model | run = model.run + 1, status = Chat.Generating, responseId = model.nextId, nextId = model.nextId + 1, turns = model.turns ++ [ { id = model.nextId, role = Chat.Assistant, author = "Operations assistant", body = "" } ] }
    , Process.sleep 300 |> Task.perform (always (Chunk (model.run + 1) 1))
    )


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none


view : Config.Config -> Settings -> Locale -> Model -> Html Msg
view playground settings locale model =
    Doc.configuredPage playground
        { title = "AI workspace", description = "Understand the evidence. Discuss individual statements. Decide what your server may apply. These components work with AI on your own server; this gallery uses a local simulation with no provider calls." }
        [ Doc.configuredSection playground
            [ "AiReview" ]
            "From suggestion to decision"
            "AI output remains a proposal until a person reviews it and the server acknowledges the decision."
            [ Layout.grid (Options.klarLayout playground (List.concat [ Config.keep playground "Layout" "minColumn" (Layout.minColumn 230), Config.keep playground "Layout" "gap" (Layout.gap 3) ]))
                [ Card.view (Options.klarCard playground (List.concat [ Config.keep playground "Card" "title" (Card.title "1 · Understand"), Config.keep playground "Card" "headingLevel" (Card.headingLevel 3) ])) [ Text.paragraph "Inspect exact values, sources, assumptions and limitations. Reuse Diff, JsonViewer, Chart and Table for richer outputs." ]
                , Card.view (Options.klarCard playground (List.concat [ Config.keep playground "Card" "title" (Card.title "2 · Discuss"), Config.keep playground "Card" "headingLevel" (Card.headingLevel 3) ])) [ Text.paragraph "Comment on each statement and revision. A revised claim gets its own discussion context." ]
                , Card.view (Options.klarCard playground (List.concat [ Config.keep playground "Card" "title" (Card.title "3 · Decide"), Config.keep playground "Card" "headingLevel" (Card.headingLevel 3) ])) [ Text.paragraph "Approve or reject each proposal. The server validates permissions and versions before writing, and records an audit trail." ]
                ]
            ]
        , Doc.configuredSection playground
            [ "AiReview" ]
            "AiReview · evidence and approval"
            "Try a rejection without a reason, change a proposal after reviewing it, or simulate a failed save. You can issue a new revision while a save is pending to exercise server conflict handling."
            [ Layout.row (Options.klarLayout playground (List.concat [ Config.keep playground "Layout" "gap" (Layout.gap 2), Config.keep playground "Layout" "wrap" Layout.wrap ]))
                [ Options.buttonView playground (Options.klarButton playground (List.concat [ Config.keep playground "Button" "onClick" (Button.onClick Revise) ])) "Issue new revision"
                , Options.buttonView playground
                    (Options.klarButton playground (List.concat [ Config.keep playground "Button" "onClick" (Button.onClick FailSave), Config.keep playground "Button" "disabled" (Button.disabled model.saving) ]))
                    (if model.failSave then
                        "Next save will fail"

                     else
                        "Fail next save"
                    )
                ]
            , Layout.row (Options.klarLayout playground (List.concat [ Config.keep playground "Layout" "gap" (Layout.gap 2), Config.keep playground "Layout" "wrap" Layout.wrap ])) (List.map (\( key, label ) -> Options.buttonView playground (Options.klarButton playground (List.concat [ Config.keep playground "Button" "small" Button.small, Config.keep playground "Button" "disabled" (Button.disabled model.saving), Config.keep playground "Button" "onClick" (Button.onClick (Load key)) ])) label) [ ( "ready", "Ready" ), ( "loading", "Loading" ), ( "failed", "Failed" ), ( "empty", "Empty" ), ( "refreshing", "Refreshing" ), ( "stale", "Old data" ) ])
            , Text.paragraph model.result
            , Card.view (Options.klarCard playground (List.concat [ Config.keep playground "Card" "title" (Card.title "Saved record · simulated server"), Config.keep playground "Card" "headingLevel" (Card.headingLevel 3) ]))
                [ Text.paragraph ("Delivery: " ++ model.delivery), Text.paragraph ("Customer priority: " ++ model.priority) ]
            , Review.view ReviewMsg
                (Options.klarAiReview playground
                    (List.concat
                        [ Config.keep playground "AiReview" "locale" (Review.locale locale)
                        , Config.keep playground "AiReview" "settings" (Review.settings settings)
                        , Config.keep playground "AiReview" "onRetry" (Review.onRetry RetryReview)
                        , Config.keep playground "AiReview" "onSubmit" (Review.onSubmit Save)
                        , Config.keep playground "AiReview" "saving" (Review.saving model.saving)
                        , Config.keep playground "AiReview" "errorMaybe" (Review.errorMaybe model.saveError)
                        , Config.keep playground
                            "AiReview"
                            "discussion"
                            (Review.discussion
                                (\id revision ->
                                    let
                                        key =
                                            id ++ "-" ++ revision

                                        thread =
                                            threadFor key model
                                    in
                                    Thread.view (ThreadMsg key) (Options.klarCommentThread playground (List.concat [ Config.keep playground "CommentThread" "locale" (Thread.locale locale), Config.keep playground "CommentThread" "settings" (Thread.settings settings), Config.keep playground "CommentThread" "onSubmit" (Thread.onSubmit (Post key)) ])) { label = "Discussion · " ++ id ++ " · " ++ revision, ids = Ids.int, comments = Remote.Loaded thread.comments } thread.state
                                )
                            )
                        ]
                    )
                )
                { label = "AI proposal review", ids = Ids.string, proposals = model.proposals }
                model.review
            ]
        , Doc.configuredSection playground
            [ "AiChat" ]
            "AiChat · server conversation"
            "Send a message to stream a simulated answer. Stop preserves partial output and invalidates late chunks. Write a new draft during generation; the composer stays available."
            [ Options.buttonView playground
                (Options.klarButton playground (List.concat [ Config.keep playground "Button" "onClick" (Button.onClick FailGeneration), Config.keep playground "Button" "disabled" (Button.disabled (model.status == Chat.Generating)) ]))
                (if model.failGeneration then
                    "Next response will fail"

                 else
                    "Fail next response"
                )
            , Chat.view ChatMsg
                (Options.klarAiChat playground (List.concat [ Config.keep playground "AiChat" "locale" (Chat.locale locale), Config.keep playground "AiChat" "settings" (Chat.settings settings), Config.keep playground "AiChat" "onSend" (Chat.onSend Send), Config.keep playground "AiChat" "onStop" (Chat.onStop Stop), Config.keep playground "AiChat" "onRetry" (Chat.onRetry RetryChat) ]))
                { label = "Operations AI chat", ids = Ids.int, messages = Remote.Loaded (List.map Chat.message model.turns), status = model.status }
                model.chat
            ]
        , Doc.configuredSection playground
            [ "AiReview", "AiChat" ]
            "Server boundary"
            "Transport and AI providers belong to the application. Klar handles the review interface."
            [ Text.paragraph "The server owns provider credentials, authentication, retrieval, tool permissions, validation, cancellation and audit storage. Return stable proposal ids and revision tokens. Accept decisions only against current proposal and target-record versions; make retries idempotent. Never run an AI tool call merely because it appeared in chat."
            , Text.paragraph "Use ApprovalFlow for multi-person sign-off, AuditLog for acknowledged changes, CommentThread for discussions, Diff for detailed change inspection and JsonViewer or Table for structured AI results."
            ]
        ]
