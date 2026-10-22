module ApprovalFlowTest exposing (suite)

{-| Klar.ApprovalFlow: the derived status (examples and properties), the viewer's
markup (list, current step, words next to icons), the buttons that only the right
viewer gets, the overdue marker, the texts in two languages and the remote states.
-}

import Expect
import Fuzz exposing (Fuzzer)
import Html exposing (Html)
import Json.Encode as Encode
import Klar.ApprovalFlow as ApprovalFlow
import Klar.Avatar as Avatar
import Klar.Locale as Locale
import Klar.Remote as Remote
import Support.FlowHtml as H
import Test exposing (Test, describe, fuzz, fuzz2, test)
import Test.Html.Query as Query
import Test.Html.Selector as Selector exposing (Selector)
import Time


type Msg
    = Approve
    | Reject
    | Retry


suite : Test
suite =
    describe "Klar.ApprovalFlow"
        [ derivationTests
        , propertyTests
        , listTests
        , currentTests
        , wordsTests
        , actionTests
        , overdueTests
        , localeTests
        , detailTests
        , remoteTests
        ]



-- BUILDING FLOWS FROM A SHORT DESCRIPTION


type D
    = P
    | Y
    | N


type alias Spec =
    { everyone : Bool
    , decisions : List D
    }


decision : D -> ApprovalFlow.Decision
decision d =
    case d of
        P ->
            ApprovalFlow.pending

        Y ->
            ApprovalFlow.approved { at = Nothing, comment = Nothing }

        N ->
            ApprovalFlow.rejected { at = Nothing, comment = Nothing }


{-| Every approver has an id of its own: the number of the step times ten, plus the
place in the step.
-}
build : List Spec -> ApprovalFlow.Flow Int
build specs =
    specs
        |> List.indexedMap
            (\index spec ->
                let
                    approvers =
                        spec.decisions
                            |> List.indexedMap (\place d -> ApprovalFlow.approver (index * 10 + place) (decision d))
                in
                case approvers of
                    first :: rest ->
                        [ ApprovalFlow.step ("Step " ++ String.fromInt index)
                            (if spec.everyone then
                                ApprovalFlow.all

                             else
                                ApprovalFlow.any
                            )
                            first
                            rest
                        ]

                    [] ->
                        -- a spec always has a decision (see the fuzzers); the type has no step without approvers
                        []
            )
        |> List.concat
        |> ApprovalFlow.flow


{-| The statuses as the tests write them: the library's are opaque and are asked with
predicates.
-}
type Status
    = Waiting
    | InProgress
    | Approved
    | Rejected
    | Skipped


stepStatus : ApprovalFlow.StepStatus -> Status
stepStatus status =
    if ApprovalFlow.stepIsWaiting status then
        Waiting

    else if ApprovalFlow.stepIsInProgress status then
        InProgress

    else if ApprovalFlow.stepIsApproved status then
        Approved

    else if ApprovalFlow.stepIsRejected status then
        Rejected

    else if ApprovalFlow.stepIsSkipped status then
        Skipped

    else
        -- no step status is none of these five
        Waiting


{-| The status of a whole flow, written with the same names (it is never Waiting or Skipped).
-}
flowStatus : ApprovalFlow.Flow Int -> Status
flowStatus theFlow =
    let
        status =
            ApprovalFlow.status theFlow
    in
    if ApprovalFlow.isApproved status then
        Approved

    else if ApprovalFlow.isRejected status then
        Rejected

    else if ApprovalFlow.isInProgress status then
        InProgress

    else
        Waiting


statusesOf : List Spec -> List Status
statusesOf specs =
    List.map stepStatus (ApprovalFlow.stepStatuses (build specs))


everyoneOf : List D -> Spec
everyoneOf decisions =
    { everyone = True, decisions = decisions }


anyOf : List D -> Spec
anyOf decisions =
    { everyone = False, decisions = decisions }



-- FUZZERS


dFuzz : Fuzzer D
dFuzz =
    Fuzz.oneOfValues [ P, Y, N ]


specFuzz : Fuzzer Spec
specFuzz =
    Fuzz.map2 Spec Fuzz.bool (Fuzz.listOfLengthBetween 1 4 dFuzz)


specsFuzz : Fuzzer (List Spec)
specsFuzz =
    Fuzz.listOfLengthBetween 0 6 specFuzz


{-| Specs whose decisions are all approvals: a step that is certainly met.
-}
metFuzz : Fuzzer Spec
metFuzz =
    Fuzz.map2 (\everyone count -> { everyone = everyone, decisions = List.repeat count Y }) Fuzz.bool (Fuzz.intRange 1 4)



-- THE DERIVATION: EXAMPLES


derivationTests : Test
derivationTests =
    describe "status derivation"
        [ test "a flow without steps requires nothing: approved, no current step, nobody to wait for" <|
            \_ ->
                let
                    empty =
                        build []
                in
                Expect.equal ( flowStatus empty, ApprovalFlow.currentStep empty, ApprovalFlow.pendingApprovers empty )
                    ( Approved, Nothing, [] )
        , test "nothing decided: the first step is in progress, the rest wait" <|
            \_ ->
                statusesOf [ everyoneOf [ P ], anyOf [ P, P ], everyoneOf [ P ] ]
                    |> Expect.equal [ InProgress, Waiting, Waiting ]
        , test "the example of the brief: approved, in progress, waiting" <|
            \_ ->
                let
                    specs =
                        [ everyoneOf [ Y ], anyOf [ P, P ], everyoneOf [ P ] ]
                in
                Expect.equal ( statusesOf specs, flowStatus (build specs), ApprovalFlow.currentStep (build specs) )
                    ( [ Approved, InProgress, Waiting ], InProgress, Just 1 )
        , test "all: one approval of two is still in progress" <|
            \_ ->
                statusesOf [ everyoneOf [ Y, P ] ] |> Expect.equal [ InProgress ]
        , test "all: every approver approved is approved" <|
            \_ ->
                statusesOf [ everyoneOf [ Y, Y, Y ] ] |> Expect.equal [ Approved ]
        , test "all: one rejection rejects the step, whatever the others did" <|
            \_ ->
                List.map (\decisions -> statusesOf [ everyoneOf decisions ])
                    [ [ N ], [ N, P ], [ Y, N ], [ Y, Y, N ], [ N, N ] ]
                    |> Expect.equal (List.repeat 5 [ Rejected ])
        , test "any: the first approval approves the step, even next to rejections" <|
            \_ ->
                List.map (\decisions -> statusesOf [ anyOf decisions ])
                    [ [ Y ], [ Y, P ], [ P, Y ], [ N, Y ], [ N, N, Y ] ]
                    |> Expect.equal (List.repeat 5 [ Approved ])
        , test "any: one rejection with others pending is still in progress" <|
            \_ ->
                statusesOf [ anyOf [ N, P ] ] |> Expect.equal [ InProgress ]
        , test "any: rejected only when every approver rejected" <|
            \_ ->
                statusesOf [ anyOf [ N, N ] ] |> Expect.equal [ Rejected ]
        , test "after a rejection the later steps are not reached" <|
            \_ ->
                let
                    specs =
                        [ everyoneOf [ Y ], everyoneOf [ N ], everyoneOf [ P ], anyOf [ Y ] ]
                in
                Expect.equal ( statusesOf specs, flowStatus (build specs), ApprovalFlow.currentStep (build specs) )
                    ( [ Approved, Rejected, Skipped, Skipped ], Rejected, Just 1 )
        , test "a decision on a step that is not reached is shown but does not count" <|
            \_ ->
                let
                    specs =
                        [ everyoneOf [ P ], everyoneOf [ Y ], anyOf [ N ] ]
                in
                Expect.equal ( statusesOf specs, flowStatus (build specs) )
                    ( [ InProgress, Waiting, Waiting ], InProgress )
        , test "every step approved: the flow is approved and there is no current step" <|
            \_ ->
                let
                    specs =
                        [ everyoneOf [ Y ], anyOf [ P, Y ], everyoneOf [ Y, Y ] ]
                in
                Expect.equal ( flowStatus (build specs), ApprovalFlow.currentStep (build specs) )
                    ( Approved, Nothing )
        , test "the pending approvers are those of the current step who have not decided" <|
            \_ ->
                ApprovalFlow.pendingApprovers (build [ everyoneOf [ Y ], everyoneOf [ Y, P, N ] ])
                    |> Expect.equal []
        , test "pending approvers of an all step: the ones who have not decided" <|
            \_ ->
                ApprovalFlow.pendingApprovers (build [ everyoneOf [ Y ], everyoneOf [ Y, P, P ], everyoneOf [ P ] ])
                    |> Expect.equal [ 11, 12 ]
        , test "pending approvers of an any step with a rejection: the ones still open" <|
            \_ ->
                ApprovalFlow.pendingApprovers (build [ anyOf [ N, P, P ] ])
                    |> Expect.equal [ 1, 2 ]
        , test "nobody is pending once the flow is rejected or approved" <|
            \_ ->
                ( ApprovalFlow.pendingApprovers (build [ everyoneOf [ N, P ] ])
                , ApprovalFlow.pendingApprovers (build [ everyoneOf [ Y ] ])
                )
                    |> Expect.equal ( [], [] )
        , test "a blank comment counts as none" <|
            \_ ->
                let
                    flow =
                        ApprovalFlow.flow
                            [ ApprovalFlow.step "Finance"
                                ApprovalFlow.all
                                (ApprovalFlow.approver 1 (ApprovalFlow.approved { at = Nothing, comment = Just "   " }))
                                []
                            ]
                in
                ApprovalFlow.view person [] flow
                    |> H.none [ Selector.class "klar-approval__comment" ]
        ]



-- THE DERIVATION: PROPERTIES


{-| Some steps approved, then either nothing, or one step in progress followed by
waiting steps, or one rejected step followed by skipped steps.
-}
wellShaped : List Status -> Bool
wellShaped list =
    let
        rest =
            dropWhile (\s -> s == Approved) list
    in
    case rest of
        [] ->
            True

        InProgress :: later ->
            List.all (\s -> s == Waiting) later

        Rejected :: later ->
            List.all (\s -> s == Skipped) later

        _ ->
            False


approvePending : D -> D
approvePending d =
    if d == P then
        Y

    else
        d


dropWhile : (a -> Bool) -> List a -> List a
dropWhile test list =
    case list of
        x :: xs ->
            if test x then
                dropWhile test xs

            else
                list

        [] ->
            []


propertyTests : Test
propertyTests =
    describe "status derivation: properties"
        [ fuzz specsFuzz "there is one status per step" <|
            \specs ->
                List.length (statusesOf specs) |> Expect.equal (List.length specs)
        , fuzz specsFuzz "the statuses always have a consistent shape" <|
            \specs ->
                statusesOf specs
                    |> wellShaped
                    |> Expect.equal True
        , fuzz specsFuzz "the flow status follows from the statuses of the steps, and is never waiting or skipped" <|
            \specs ->
                let
                    list =
                        statusesOf specs

                    expected =
                        if List.member Rejected list then
                            Rejected

                        else if List.all (\s -> s == Approved) list then
                            Approved

                        else
                            InProgress
                in
                flowStatus (build specs) |> Expect.equal expected
        , fuzz specsFuzz "the current step is the first step that is not approved" <|
            \specs ->
                let
                    list =
                        statusesOf specs

                    firstOpen =
                        list
                            |> List.indexedMap Tuple.pair
                            |> List.filter (\( _, s ) -> s /= Approved)
                            |> List.head
                            |> Maybe.map Tuple.first
                in
                ApprovalFlow.currentStep (build specs) |> Expect.equal firstOpen
        , fuzz2 specsFuzz specsFuzz "one rejection in an all step that is reached rejects it, and everything after it is skipped" <|
            \before after ->
                let
                    approvedBefore =
                        List.map (\s -> { s | decisions = List.map (always Y) s.decisions }) before

                    rejecting =
                        everyoneOf [ N, P, Y ]

                    list =
                        statusesOf (approvedBefore ++ [ rejecting ] ++ after)
                in
                Expect.equal (List.drop (List.length approvedBefore) list)
                    (Rejected :: List.repeat (List.length after) Skipped)
        , fuzz2 specsFuzz specsFuzz "an any step that is reached is approved by its first approval" <|
            \before after ->
                let
                    approvedBefore =
                        List.map (\s -> { s | decisions = List.map (always Y) s.decisions }) before

                    approving =
                        anyOf [ N, N, Y, P ]

                    list =
                        statusesOf (approvedBefore ++ [ approving ] ++ after)
                in
                list
                    |> List.drop (List.length approvedBefore)
                    |> List.head
                    |> Expect.equal (Just Approved)
        , fuzz2 specsFuzz specsFuzz "the order is respected: what happens after the current step does not change it or the steps before it" <|
            \specs later ->
                let
                    list =
                        statusesOf specs

                    keep =
                        case ApprovalFlow.currentStep (build specs) of
                            Just index ->
                                index + 1

                            Nothing ->
                                List.length list

                    changed =
                        List.take keep specs ++ later
                in
                List.take keep (statusesOf changed) |> Expect.equal (List.take keep list)
        , fuzz specsFuzz "approving everyone who is pending in the step being decided approves that step" <|
            \specs ->
                case ApprovalFlow.currentStep (build specs) of
                    Just index ->
                        if List.drop index (statusesOf specs) |> List.head |> (==) (Just InProgress) then
                            specs
                                |> List.indexedMap
                                    (\i spec ->
                                        if i == index then
                                            { spec | decisions = List.map approvePending spec.decisions }

                                        else
                                            spec
                                    )
                                |> statusesOf
                                |> List.drop index
                                |> List.head
                                |> Expect.equal (Just Approved)

                        else
                            Expect.pass

                    Nothing ->
                        Expect.pass
        , fuzz specsFuzz "pending approvers exist exactly when the flow is in progress, and belong to the current step" <|
            \specs ->
                let
                    theFlow =
                        build specs

                    pendingIds =
                        ApprovalFlow.pendingApprovers theFlow
                in
                case ( flowStatus theFlow, ApprovalFlow.currentStep theFlow ) of
                    ( InProgress, Just index ) ->
                        Expect.all
                            [ \ids -> List.isEmpty ids |> Expect.equal False
                            , \ids -> List.all (\id -> id // 10 == index) ids |> Expect.equal True
                            ]
                            pendingIds

                    _ ->
                        pendingIds |> Expect.equal []
        , fuzz metFuzz "a step in which everyone approved is met, whatever the rule" <|
            \spec ->
                statusesOf [ spec ] |> Expect.equal [ Approved ]
        ]



-- THE VIEWER


people : List ( Int, String )
people =
    [ ( 1, "Ada Lovelace" ), ( 2, "Grace Hopper" ), ( 3, "Alan Turing" ), ( 4, "Edsger Dijkstra" ) ]


person : Int -> Avatar.Entry
person id =
    { name =
        people
            |> List.filter (\( key, _ ) -> key == id)
            |> List.head
            |> Maybe.map Tuple.second
            |> Maybe.withDefault "Unknown"
    , image = Nothing
    }


march12 : Time.Posix
march12 =
    Time.millisToPosix 1710252300000


march14 : Time.Posix
march14 =
    Time.millisToPosix 1710417600000


march20 : Time.Posix
march20 =
    Time.millisToPosix 1710925200000


{-| Step 1 approved by Ada, step 2 waits for Grace or Alan (due 14 March), step 3
waits for Edsger.
-}
creditNote : ApprovalFlow.Flow Int
creditNote =
    ApprovalFlow.flow
        [ ApprovalFlow.step "Team lead"
            ApprovalFlow.all
            (ApprovalFlow.approver 1 (ApprovalFlow.approved { at = Just march12, comment = Just "Matches the return." }))
            []
        , ApprovalFlow.step "Finance"
            ApprovalFlow.any
            (ApprovalFlow.approver 2 ApprovalFlow.pending)
            [ ApprovalFlow.approver 3 ApprovalFlow.pending ]
            |> ApprovalFlow.withDue march14
        , ApprovalFlow.step "Director"
            ApprovalFlow.all
            (ApprovalFlow.approver 4 ApprovalFlow.pending)
            []
        ]


rejectedNote : ApprovalFlow.Flow Int
rejectedNote =
    ApprovalFlow.flow
        [ ApprovalFlow.step "Team lead" ApprovalFlow.all (ApprovalFlow.approver 1 (ApprovalFlow.approved { at = Nothing, comment = Nothing })) []
        , ApprovalFlow.step "Finance"
            ApprovalFlow.all
            (ApprovalFlow.approver 2 (ApprovalFlow.rejected { at = Just march12, comment = Just "The amount is wrong." }))
            [ ApprovalFlow.approver 3 ApprovalFlow.pending ]
        , ApprovalFlow.step "Director" ApprovalFlow.all (ApprovalFlow.approver 4 ApprovalFlow.pending) []
        ]


approvedNote : ApprovalFlow.Flow Int
approvedNote =
    build [ everyoneOf [ Y ], anyOf [ Y, P ] ]


viewIt : List (ApprovalFlow.Attribute Int Msg) -> ApprovalFlow.Flow Int -> Html Msg
viewIt attributes theFlow =
    ApprovalFlow.view person attributes theFlow


stepItem : Selector
stepItem =
    Selector.class "klar-approval__step"


listTests : Test
listTests =
    describe "the list"
        [ test "the steps are an ordered list inside a named region" <|
            \_ ->
                viewIt [] creditNote
                    |> Query.fromHtml
                    |> Expect.all
                        [ Query.has [ Selector.tag "section", H.attr "aria-label" "Approval steps" ]
                        , Query.find [ Selector.tag "ol" ] >> Query.findAll [ Selector.tag "li", stepItem ] >> Query.count (Expect.equal 3)
                        ]
        , test "the lists keep their list semantics when the stylesheet takes the bullets away" <|
            \_ ->
                viewIt [] creditNote
                    |> Query.fromHtml
                    |> Expect.all
                        [ Query.find [ Selector.tag "ol" ] >> Query.has [ H.attr "role" "list" ]
                        , Query.findAll [ Selector.tag "ul", Selector.class "klar-approval__people" ] >> Query.each (Query.has [ H.attr "role" "list" ])
                        ]
        , test "the name can be set" <|
            \_ ->
                viewIt [ ApprovalFlow.ariaLabel "Approval of credit note 2024-117" ] creditNote
                    |> H.has [ H.attr "aria-label" "Approval of credit note 2024-117" ]
        , test "every step is numbered for screen readers, and the title follows" <|
            \_ ->
                viewIt [] creditNote
                    |> H.has [ Selector.containing [ Selector.text "Step 2: " ] ]
        , test "the horizontal layout is a class, the vertical one the default" <|
            \_ ->
                Expect.all
                    [ \_ -> viewIt [] creditNote |> H.has [ Selector.class "klar-approval--vertical" ]
                    , \_ -> viewIt [ ApprovalFlow.horizontal ] creditNote |> H.has [ Selector.class "klar-approval--horizontal" ]
                    ]
                    ()
        , test "a flow without steps says that no approval is required" <|
            \_ ->
                viewIt [] (ApprovalFlow.flow [])
                    |> H.has [ Selector.text "No approval is required" ]
        ]


currentTests : Test
currentTests =
    describe "the current step"
        [ test "exactly one step is current, the one being decided" <|
            \_ ->
                viewIt [] creditNote
                    |> Query.fromHtml
                    |> Expect.all
                        [ Query.findAll [ H.attr "aria-current" "step" ] >> Query.count (Expect.equal 1)
                        , Query.find [ H.attr "aria-current" "step" ] >> Query.has [ Selector.text "Finance" ]
                        ]
        , test "in a rejected flow the rejected step is current" <|
            \_ ->
                viewIt [] rejectedNote
                    |> Query.fromHtml
                    |> Query.find [ H.attr "aria-current" "step" ]
                    |> Query.has [ Selector.text "Finance", Selector.class "klar-approval__step--rejected" ]
        , test "in an approved flow no step is current" <|
            \_ ->
                viewIt [] approvedNote
                    |> H.none [ H.attr "aria-current" "step" ]
        ]


wordsTests : Test
wordsTests =
    describe "statuses are words next to an icon, never colour alone"
        [ test "the statuses of the steps of the example" <|
            \_ ->
                viewIt [] creditNote
                    |> Query.fromHtml
                    |> Query.findAll [ Selector.class "klar-approval__status" ]
                    |> Expect.all
                        [ Query.count (Expect.equal 3)
                        , Query.index 0 >> Query.has [ Selector.text "Approved" ]
                        , Query.index 1 >> Query.has [ Selector.text "In progress" ]
                        , Query.index 2 >> Query.has [ Selector.text "Waiting for step 2" ]
                        ]
        , test "each status has an icon of its own beside the words" <|
            \_ ->
                viewIt [] creditNote
                    |> Query.fromHtml
                    |> Query.findAll [ Selector.class "klar-approval__status" ]
                    |> Query.each (Query.has [ Selector.class "klar-icon" ])
        , test "steps after a rejection are not reached" <|
            \_ ->
                viewIt [] rejectedNote
                    |> Query.fromHtml
                    |> Query.findAll [ Selector.class "klar-approval__status" ]
                    |> Expect.all
                        [ Query.index 1 >> Query.has [ Selector.text "Rejected" ]
                        , Query.index 2 >> Query.has [ Selector.text "Not reached" ]
                        ]
        , test "the line above says where the flow stands, as a polite status" <|
            \_ ->
                Expect.all
                    [ \_ -> viewIt [] creditNote |> H.inside [ Selector.class "klar-approval__summary" ] [ H.attr "role" "status", Selector.text "In progress: step 2 of 3 (Finance)" ]
                    , \_ -> viewIt [] rejectedNote |> H.inside [ Selector.class "klar-approval__summary" ] [ Selector.text "Rejected at step 2 (Finance)" ]
                    , \_ -> viewIt [] approvedNote |> H.inside [ Selector.class "klar-approval__summary" ] [ Selector.text "Approved" ]
                    ]
                    ()
        , test "the rule of a step: all, any of n, the count; none for a single approver" <|
            \_ ->
                let
                    both =
                        viewIt [] (build [ everyoneOf [ Y, P ], anyOf [ P, P ], everyoneOf [ P ] ])
                in
                both
                    |> Query.fromHtml
                    |> Query.findAll [ Selector.class "klar-approval__meta" ]
                    |> Expect.all
                        [ Query.count (Expect.equal 2)
                        , Query.index 0 >> Query.has [ Selector.text "All must approve", Selector.text "1 of 2 approved" ]
                        , Query.index 1 >> Query.has [ Selector.text "Any one of 2 must approve" ]
                        ]
        ]


actionTests : Test
actionTests =
    let
        approveButton =
            [ Selector.tag "button", Selector.containing [ Selector.text "Approve" ] ]

        rejectButton =
            [ Selector.tag "button", Selector.containing [ Selector.text "Reject" ] ]

        buttons who =
            [ ApprovalFlow.viewer who, ApprovalFlow.onApprove Approve, ApprovalFlow.onReject Reject ]

        click =
            ( "click", Encode.object [] )
    in
    describe "deciding"
        [ test "a pending approver of the current step gets both buttons, in a named group" <|
            \_ ->
                viewIt (buttons (Just 2)) creditNote
                    |> Query.fromHtml
                    |> Query.find [ Selector.class "klar-approval__actions" ]
                    |> Expect.all
                        [ Query.has [ H.attr "role" "group", H.attr "aria-label" "Your decision on Finance" ]
                        , Query.has approveButton
                        , Query.has rejectButton
                        ]
        , test "the buttons send the messages of the application" <|
            \_ ->
                let
                    html =
                        viewIt (buttons (Just 3)) creditNote
                in
                Expect.equal ( H.sends approveButton click html, H.sends rejectButton click html )
                    ( Ok Approve, Ok Reject )
        , test "nobody else gets buttons: no viewer, a stranger, a later step, a past step" <|
            \_ ->
                Expect.all
                    (List.map (\who -> \_ -> viewIt (buttons who) creditNote |> H.none approveButton) [ Nothing, Just 99, Just 4, Just 1 ])
                    ()
        , test "an approver who has decided in an all step is not asked again, the other one is" <|
            \_ ->
                let
                    half =
                        build [ everyoneOf [ Y, P ] ]
                in
                Expect.all
                    [ \_ -> viewIt (buttons (Just 0)) half |> H.none approveButton
                    , \_ -> viewIt (buttons (Just 1)) half |> H.count 1 approveButton
                    ]
                    ()
        , test "in a rejected or approved flow nobody is asked" <|
            \_ ->
                Expect.all
                    [ \_ -> viewIt (buttons (Just 3)) rejectedNote |> H.none approveButton
                    , \_ -> viewIt (buttons (Just 1)) approvedNote |> H.none approveButton
                    ]
                    ()
        , test "only the messages that are given have a button" <|
            \_ ->
                viewIt [ ApprovalFlow.viewer (Just 2), ApprovalFlow.onApprove Approve ] creditNote
                    |> Query.fromHtml
                    |> Expect.all
                        [ Query.findAll approveButton >> Query.count (Expect.equal 1)
                        , Query.findAll rejectButton >> Query.count (Expect.equal 0)
                        ]
        , test "without any message there is no group at all" <|
            \_ ->
                viewIt [ ApprovalFlow.viewer (Just 2) ] creditNote
                    |> H.none [ Selector.class "klar-approval__actions" ]
        , test "the viewer finds their own name marked" <|
            \_ ->
                viewIt [ ApprovalFlow.viewer (Just 2) ] creditNote
                    |> H.has [ Selector.text "(you)" ]
        ]


overdueTests : Test
overdueTests =
    let
        overdue =
            [ Selector.containing [ Selector.text "Overdue" ] ]
    in
    describe "overdue"
        [ test "the current step past its due time says so, next to the time" <|
            \_ ->
                viewIt [ ApprovalFlow.now march20 ] creditNote
                    |> Query.fromHtml
                    |> Expect.all
                        [ Query.has [ Selector.class "klar-approval__step--overdue" ]
                        , Query.has overdue
                        , Query.has [ Selector.class "klar-approval__due--overdue", Selector.text "2024-03-14 12:00" ]
                        ]
        , test "before the due time, or without a clock, nothing is overdue" <|
            \_ ->
                Expect.all
                    [ \_ -> viewIt [ ApprovalFlow.now march12 ] creditNote |> H.none [ Selector.class "klar-approval__step--overdue" ]
                    , \_ -> viewIt [] creditNote |> H.none [ Selector.class "klar-approval__step--overdue" ]
                    , \_ -> viewIt [] creditNote |> H.none overdue
                    ]
                    ()
        , test "a step that is not the current one is never overdue, and the due time is still shown" <|
            \_ ->
                let
                    waiting =
                        ApprovalFlow.flow
                            [ ApprovalFlow.step "Team lead" ApprovalFlow.all (ApprovalFlow.approver 1 ApprovalFlow.pending) []
                            , ApprovalFlow.step "Finance" ApprovalFlow.all (ApprovalFlow.approver 2 ApprovalFlow.pending) []
                                |> ApprovalFlow.withDue march14
                            ]
                in
                viewIt [ ApprovalFlow.now march20 ] waiting
                    |> Query.fromHtml
                    |> Expect.all
                        [ Query.hasNot [ Selector.class "klar-approval__step--overdue" ]
                        , Query.has [ Selector.class "klar-approval__due" ]
                        ]
        , test "a step that is decided is not overdue" <|
            \_ ->
                let
                    done =
                        ApprovalFlow.flow
                            [ ApprovalFlow.step "Finance" ApprovalFlow.all (ApprovalFlow.approver 2 (ApprovalFlow.approved { at = Nothing, comment = Nothing })) []
                                |> ApprovalFlow.withDue march14
                            ]
                in
                viewIt [ ApprovalFlow.now march20 ] done
                    |> Expect.all
                        [ H.none [ Selector.class "klar-approval__step--overdue" ]
                        , H.none overdue
                        ]
        ]


localeTests : Test
localeTests =
    describe "Norwegian"
        [ test "statuses, rules, buttons and the overdue marker in Norwegian" <|
            \_ ->
                viewIt [ ApprovalFlow.locale Locale.nb, ApprovalFlow.now march20, ApprovalFlow.viewer (Just 2), ApprovalFlow.onApprove Approve, ApprovalFlow.onReject Reject ] creditNote
                    |> Query.fromHtml
                    |> Expect.all
                        [ Query.has [ H.attr "aria-label" "Godkjenningssteg" ]
                        , Query.has [ Selector.text "Godkjent" ]
                        , Query.has [ Selector.text "Pågår" ]
                        , Query.has [ Selector.text "Venter på steg 2" ]
                        , Query.has [ Selector.text "Én av 2 må godkjenne" ]
                        , Query.has [ Selector.text "Over fristen" ]
                        , Query.has [ Selector.text "Frist" ]
                        , Query.has [ Selector.tag "button", Selector.containing [ Selector.text "Godkjenn" ] ]
                        , Query.has [ Selector.tag "button", Selector.containing [ Selector.text "Avvis" ] ]
                        , Query.has [ H.attr "aria-label" "Din beslutning om Finance" ]
                        , Query.has [ Selector.text "Pågår: steg 2 av 3 (Finance)" ]
                        , Query.has [ Selector.text "Venter på svar" ]
                        , Query.has [ Selector.text "(du)" ]
                        ]
        , test "a rejection and the steps that are not reached, in Norwegian" <|
            \_ ->
                viewIt [ ApprovalFlow.locale Locale.nb ] rejectedNote
                    |> Query.fromHtml
                    |> Expect.all
                        [ Query.has [ Selector.text "Avvist i steg 2 (Finance)" ]
                        , Query.has [ Selector.text "Ikke aktuelt" ]
                        ]
        , test "the empty flow in Norwegian" <|
            \_ ->
                viewIt [ ApprovalFlow.locale Locale.nb ] (ApprovalFlow.flow [])
                    |> H.has [ Selector.text "Ingen godkjenning kreves" ]
        , test "times follow the locale" <|
            \_ ->
                viewIt [ ApprovalFlow.locale Locale.nb ] creditNote
                    |> H.has [ Selector.text "12.03.2024 14:05" ]
        ]


detailTests : Test
detailTests =
    describe "approvers, times and comments"
        [ test "every approver is listed with the decision in words, the comment and the time" <|
            \_ ->
                viewIt [] creditNote
                    |> Query.fromHtml
                    |> Query.findAll [ Selector.class "klar-approval__person" ]
                    |> Expect.all
                        [ Query.count (Expect.equal 4)
                        , Query.index 0 >> Query.has [ Selector.text "Ada Lovelace", Selector.text "Approved", Selector.text "Matches the return.", Selector.text "2024-03-12 14:05" ]
                        , Query.index 1 >> Query.has [ Selector.text "Grace Hopper", Selector.text "Pending" ]
                        ]
        , test "a time is a time element with the moment as machine readable text" <|
            \_ ->
                viewIt [] creditNote
                    |> H.has [ Selector.tag "time", H.attr "datetime" "2024-03-12T14:05:00Z" ]
        , test "with a clock, the times carry a tooltip of how long ago they were" <|
            \_ ->
                viewIt [ ApprovalFlow.now march20 ] creditNote
                    |> H.has [ Selector.tag "time", H.attr "title" "7 days ago" ]
        , test "the time zone moves the time shown" <|
            \_ ->
                viewIt [ ApprovalFlow.zone (Time.customZone 120 []) ] creditNote
                    |> H.has [ Selector.text "2024-03-12 16:05" ]
        , test "the avatar next to a name is decorative, so the name is not read twice" <|
            \_ ->
                viewIt [] creditNote
                    |> Query.fromHtml
                    |> Query.findAll [ Selector.class "klar-approval__person" ]
                    |> Query.index 0
                    |> Query.has [ Selector.class "klar-avatar", H.attr "aria-hidden" "true" ]
        ]


remoteTests : Test
remoteTests =
    let
        remote data =
            ApprovalFlow.viewRemote person [ ApprovalFlow.onRetry Retry ] data
    in
    describe "remote data"
        [ test "loading and not asked show a busy skeleton with a status for screen readers" <|
            \_ ->
                Expect.all
                    (List.map
                        (\data -> \_ -> remote data |> H.has [ H.attr "aria-busy" "true", Selector.class "klar-approval--skeleton" ])
                        [ Remote.NotAsked, Remote.Loading ]
                    )
                    ()
        , test "a failure shows the problem and a retry button that sends the message" <|
            \_ ->
                let
                    html =
                        remote (Remote.Failed (Remote.problem Remote.network))
                in
                Expect.all
                    [ \_ -> H.has [ Selector.text "Try again" ] html
                    , \_ -> H.sends [ Selector.tag "button", Selector.containing [ Selector.text "Try again" ] ] ( "click", Encode.object [] ) html |> Expect.equal (Ok Retry)
                    ]
                    ()
        , test "a failure that cannot be retried has no button" <|
            \_ ->
                remote (Remote.Failed (Remote.problem Remote.forbidden))
                    |> H.none [ Selector.tag "button" ]
        , test "success shows the steps, and an empty flow its own state" <|
            \_ ->
                Expect.all
                    [ \_ -> remote (Remote.Loaded creditNote) |> H.has [ Selector.class "klar-approval__steps" ]
                    , \_ -> remote (Remote.Loaded (ApprovalFlow.flow [])) |> H.has [ Selector.text "No approval is required" ]
                    ]
                    ()
        ]
