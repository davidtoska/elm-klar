module Page.Applications.Classification exposing (Document, Model, Msg(..), Status(..), init, leave, update, view)

{-| A simulated JEV document-classification work queue. Low confidence routes to
human review. A request generation prevents cancelled runs from updating a row.
No JEV endpoint or response schema is assumed by this example.
-}

import Html exposing (Html)
import Klar
import Klar.Badge as Badge
import Klar.Button as Button
import Klar.Card as Card
import Klar.Icon as Icon
import Klar.Layout as Layout
import Klar.Progress as Progress
import Klar.SegmentedControl as Segmented
import Klar.Text as Text
import Klar.Theme exposing (Tone(..))
import Patterns.Workspace as Pattern
import Process
import Task


type Status
    = Queued
    | Classifying
    | Checking
    | Classified String Int
    | NeedsReview String Int
    | Approved String
    | Failed


type alias Document =
    { id : Int, name : String, excerpt : String, status : Status, proposed : String }


type alias Model =
    { documents : List Document, running : Bool, ticket : Int, threshold : Int, scenario : String, message : String }


init : Model
init =
    { documents =
        [ { id = 1, name = "invoice-1042.pdf", excerpt = "Invoice 1042 · Total EUR 2,400 · Payment due in 30 days.", status = Queued, proposed = "Invoice" }
        , { id = 2, name = "service-agreement.pdf", excerpt = "This agreement sets out the service period, responsibilities and termination clauses.", status = Queued, proposed = "Contract" }
        , { id = 3, name = "customer-message.txt", excerpt = "Could you change the billing contact? We also need help with our workspace access.", status = Queued, proposed = "Support" }
        , { id = 4, name = "scanned-attachment.pdf", excerpt = "Image-only attachment. The first simulated attempt fails; retry it after the batch.", status = Queued, proposed = "Other" }
        ]
    , running = False
    , ticket = 0
    , threshold = 85
    , scenario = "mixed"
    , message = "Four documents are ready. Start a batch to see each stage."
    }


type Msg
    = Start
    | Cancel
    | Completed Int Int String
    | ContentClassified Int Int String
    | Retry Int
    | Category Int String
    | Approve Int
    | Threshold Int
    | Scenario String
    | Reset
    | NoOp


leave : Model -> Model
leave model =
    { model
        | running = False
        , ticket = model.ticket + 1
        , documents =
            List.map
                (\doc ->
                    if List.member doc.status [ Classifying, Checking ] then
                        { doc | status = Queued }

                    else
                        doc
                )
                model.documents
    }


change : Int -> (Document -> Document) -> Model -> Model
change id fn model =
    { model
        | documents =
            List.map
                (\doc ->
                    if doc.id == id then
                        fn doc

                    else
                        doc
                )
                model.documents
    }


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        Start ->
            if model.running then
                ( model, Cmd.none )

            else
                next { model | running = True, ticket = model.ticket + 1 }
                    |> focusStatus

        Cancel ->
            ( leave { model | message = "Batch stopped. Completed results are kept; unfinished documents return to the queue." }, Klar.focus "classification-status" NoOp )

        ContentClassified ticket id scenario ->
            if ticket /= model.ticket || not model.running || not (List.any (\doc -> doc.id == id && doc.status == Classifying) model.documents) then
                ( model, Cmd.none )

            else
                ( change id (\doc -> { doc | status = Checking }) model
                , Process.sleep 650 |> Task.perform (\_ -> Completed ticket id scenario)
                )

        Completed ticket id scenario ->
            if ticket /= model.ticket || not model.running || not (List.any (\doc -> doc.id == id && doc.status == Checking) model.documents) then
                ( model, Cmd.none )

            else
                let
                    confidence =
                        if id == 1 then
                            98

                        else if id == 2 then
                            89

                        else
                            62

                    outcome doc =
                        { doc
                            | status =
                                if scenario == "unavailable" || (scenario == "mixed" && id == 4) then
                                    Failed

                                else if confidence < model.threshold then
                                    NeedsReview doc.proposed confidence

                                else
                                    Classified doc.proposed confidence
                        }
                in
                next (change id outcome model)

        Retry id ->
            if model.running then
                ( model, Cmd.none )

            else if List.any (\doc -> doc.id == id && doc.status == Failed) model.documents then
                next
                    (change id
                        (\doc -> { doc | status = Queued })
                        { model
                            | running = True
                            , ticket = model.ticket + 1
                            , scenario =
                                if model.scenario == "mixed" then
                                    "success"

                                else
                                    model.scenario
                        }
                    )
                    |> focusStatus

            else
                ( model, Cmd.none )

        Category id category ->
            ( change id
                (\doc ->
                    case doc.status of
                        NeedsReview _ _ ->
                            { doc | proposed = category }

                        _ ->
                            doc
                )
                model
            , Cmd.none
            )

        Approve id ->
            ( change id
                (\doc ->
                    case doc.status of
                        NeedsReview _ _ ->
                            { doc | status = Approved doc.proposed }

                        _ ->
                            doc
                )
                { model | message = "Classification approved by a reviewer. The decision is ready for downstream processing." }
            , Klar.focus ("document-status-" ++ String.fromInt id) NoOp
            )

        Threshold value ->
            ( { model | threshold = value }, Cmd.none )

        Scenario value ->
            ( { model | scenario = value }, Cmd.none )

        Reset ->
            ( { init | ticket = model.ticket + 1 }, Cmd.none )

        NoOp ->
            ( model, Cmd.none )


focusStatus : ( Model, Cmd Msg ) -> ( Model, Cmd Msg )
focusStatus ( model, cmd ) =
    ( model, Cmd.batch [ cmd, Klar.focus "classification-status" NoOp ] )


next : Model -> ( Model, Cmd Msg )
next model =
    case List.filter (\doc -> doc.status == Queued) model.documents |> List.head of
        Nothing ->
            ( { model | running = False, message = "Batch finished. Review uncertain classifications and retry failed documents." }, Cmd.none )

        Just doc ->
            ( change doc.id (\item -> { item | status = Classifying }) { model | message = "JEV is classifying " ++ doc.name ++ "..." }
            , Process.sleep 950 |> Task.perform (\_ -> ContentClassified model.ticket doc.id model.scenario)
            )


isResolved : Document -> Bool
isResolved doc =
    case doc.status of
        Classified _ _ ->
            True

        Approved _ ->
            True

        _ ->
            False


status : Status -> ( String, Tone )
status value =
    case value of
        Queued ->
            ( "Queued", Neutral )

        Classifying ->
            ( "Classifying", Info )

        Checking ->
            ( "Checking confidence", Info )

        Classified _ _ ->
            ( "Classified", Success )

        NeedsReview _ _ ->
            ( "Needs review", Warning )

        Approved _ ->
            ( "Approved", Success )

        Failed ->
            ( "Failed", Danger )


view : Model -> Html Msg
view model =
    let
        count predicate =
            List.filter predicate model.documents |> List.length

        resolved =
            count isResolved

        review =
            count
                (\doc ->
                    case doc.status of
                        NeedsReview _ _ ->
                            True

                        _ ->
                            False
                )

        failed =
            count (\doc -> doc.status == Failed)

        queued =
            count (\doc -> doc.status == Queued)
    in
    Layout.stack [ Layout.gap 5 ]
        [ Pattern.flow [ "In queue", "Classifying", "Confidence check", "Human review", "Ready to use" ]
            (if List.any (\doc -> doc.status == Checking) model.documents then
                2

             else if model.running then
                1

             else if review > 0 then
                3

             else if resolved > 0 then
                4

             else
                0
            )
        , Layout.grid [ Layout.minColumn 180, Layout.gap 4 ]
            (List.map (\( label, value, tone ) -> Card.view [] [ Layout.stack [ Layout.gap 2 ] [ Text.figure (String.fromInt value), Badge.view [ Badge.tone tone ] label ] ]) [ ( "In queue", queued, Neutral ), ( "Ready to use", resolved, Success ), ( "Needs review", review, Warning ), ( "Failed", failed, Danger ) ])
        , Pattern.section "Document queue"
            "JEV · Simulated classification adapter"
            [ Layout.row [ Layout.gap 2, Layout.wrap ]
                [ Button.view [ Button.primary, Button.icon Icon.play, Button.onClick Start, Button.loading model.running, Button.disabled (queued == 0) ]
                    (if model.running then
                        "Classifying documents..."

                     else
                        "Classify queued documents"
                    )
                , Button.view [ Button.onClick Cancel, Button.disabled (not model.running), Button.icon Icon.pause ] "Stop batch"
                , Button.view [ Button.ghost, Button.onClick Reset, Button.disabled model.running, Button.icon Icon.refresh ] "Reset demo"
                ]
            , Pattern.result "classification-status" Info model.message
            , Progress.view [ Progress.label "Ready for downstream processing", Progress.outOf resolved (List.length model.documents), Progress.showValue ]
            , Layout.stack [ Layout.gap 4 ] (List.map (viewDocument model.running) model.documents)
            ]
        , Layout.grid [ Layout.minColumn 320, Layout.gap 5 ]
            [ Pattern.section "Classification policy"
                "Confidence below the threshold always goes to review"
                [ Segmented.view [ Segmented.label "Minimum confidence", Segmented.options [ Segmented.option 75 "75%", Segmented.option 85 "85%", Segmented.option 95 "95%" ], Segmented.selected model.threshold, Segmented.onChange Threshold, Segmented.disabled model.running ]
                , Segmented.view [ Segmented.label "Next run", Segmented.options [ Segmented.option "mixed" "Mixed outcomes", Segmented.option "success" "No service errors", Segmented.option "unavailable" "JEV unavailable" ], Segmented.selected model.scenario, Segmented.onChange Scenario, Segmented.disabled model.running ]
                , Text.secondary "Changes apply to the next classification. Confidence values are simulated scores, not a guarantee of correctness. Human approval is recorded separately from an automatic result."
                ]
            , Pattern.section "From document to action"
                "A reusable classification workflow"
                [ Text.paragraph "Classify incoming documents, route invoices to finance, agreements to legal and support requests to your help desk. Review uncertain results before they trigger an action."
                , Text.secondary "All documents and JEV answers are made up. This page demonstrates the states and controls; a real server-side adapter must validate JEV responses and enforce access to source documents."
                , Pattern.link "Configure the JEV provider" "ai-providers"
                ]
            ]
        ]


viewDocument : Bool -> Document -> Html Msg
viewDocument running doc =
    let
        ( label, tone ) =
            status doc.status

        prediction =
            case doc.status of
                Classified category confidence ->
                    category ++ " · " ++ String.fromInt confidence ++ "% confidence"

                NeedsReview category confidence ->
                    "Suggested: " ++ category ++ " · " ++ String.fromInt confidence ++ "% confidence"

                Approved category ->
                    category ++ " · Approved by reviewer"

                Classifying ->
                    "Reading content and choosing a category..."

                Checking ->
                    "Comparing confidence with your review policy..."

                Failed ->
                    "JEV could not classify this document. Retry when the service is available."

                Queued ->
                    "Waiting for classification"
    in
    Card.view [ Card.title doc.name, Card.headingLevel 3, Card.actions [ Badge.view [ Badge.tone tone, Badge.dot ] label ] ]
        [ Layout.stack [ Layout.gap 3 ]
            [ Text.paragraph doc.excerpt
            , Pattern.result ("document-status-" ++ String.fromInt doc.id) tone prediction
            , case doc.status of
                NeedsReview _ _ ->
                    Layout.stack [ Layout.gap 3 ]
                        [ Segmented.view [ Segmented.id ("category-" ++ String.fromInt doc.id), Segmented.label ("Review category for " ++ doc.name), Segmented.options (List.map (\name -> Segmented.option name name) [ "Invoice", "Contract", "Support", "Other" ]), Segmented.selected doc.proposed, Segmented.onChange (Category doc.id) ]
                        , Button.view [ Button.icon Icon.check, Button.onClick (Approve doc.id) ] "Approve classification"
                        ]

                Failed ->
                    Button.view [ Button.onClick (Retry doc.id), Button.disabled running, Button.icon Icon.refresh ] "Retry document"

                _ ->
                    Html.text ""
            ]
        ]
