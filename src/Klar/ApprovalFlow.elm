module Klar.ApprovalFlow exposing
    ( view, viewRemote
    , Flow, flow, Step, step, withDue, Quorum, all, any
    , Approver, approver, Decision, pending, approved, rejected
    , Status, status, isInProgress, isApproved, isRejected
    , StepStatus, stepStatuses, stepIsWaiting, stepIsInProgress, stepIsApproved, stepIsRejected, stepIsSkipped
    , currentStep, pendingApprovers
    , Attribute, viewer, onApprove, onReject, now, settings, horizontal, ariaLabel, onRetry, locale
    )

{-| The approval process of one item: an ordered list of steps, each with one or
several approvers and a decision from each, and where the item stands.

Use when: an invoice, a credit note or a request needs sign-off and the page shows who has decided and who is next.
Do not use when: only a history of what happened is shown, use `Klar.Timeline`, or the steps of a wizard, use `Klar.Stepper`.

    import Klar.ApprovalFlow as ApprovalFlow
    import Klar.Avatar as Avatar

    creditNoteFlow : Time.Posix -> ApprovalFlow.Flow UserId
    creditNoteFlow deadline =
        ApprovalFlow.flow
            [ ApprovalFlow.step "Team lead"
                ApprovalFlow.all
                (ApprovalFlow.approver ada
                    (ApprovalFlow.approved { at = Just twelfthOfMarch, comment = Just "Matches the return." })
                )
                []
            , ApprovalFlow.step "Finance"
                ApprovalFlow.any
                (ApprovalFlow.approver grace ApprovalFlow.pending)
                [ ApprovalFlow.approver alan ApprovalFlow.pending ]
                |> ApprovalFlow.withDue deadline
            , ApprovalFlow.step "Director"
                ApprovalFlow.all
                (ApprovalFlow.approver edsger ApprovalFlow.pending)
                []
            ]

    -- view: who is shown how, and who is looking
    ApprovalFlow.view personOf
        [ ApprovalFlow.viewer (Just model.me)
        , ApprovalFlow.onApprove Approve
        , ApprovalFlow.onReject AskWhyRejected
        , ApprovalFlow.now model.now
        , ApprovalFlow.settings model.settings
        ]
        (creditNoteFlow model.deadline)

    personOf : UserId -> Avatar.Entry
    personOf id =
        { name = User.name id, image = User.pictureUrl id }

Use it on the page of an invoice, a credit note, a purchase request or a change
that needs sign-off. It shows the process; it does not run it: your server
decides who may decide and records the decisions, and you give the decisions back
as data. For a history of what happened, with no rules, see
[Klar.Timeline](Klar-Timeline); for the steps of a wizard the user fills in
himself, [Klar.Stepper](Klar-Stepper).

**The status is derived, never given.** Where a step stands and where the whole
flow stands follow from the decisions and the rules, in one place, so a screen
cannot contradict its own data. The steps are taken in order:

  - A step is met when its `Quorum` is satisfied: with `all` every approver
    approved, with `any` at least one did. It fails when it can no longer be met:
    with `all` as soon as one approver rejected, with `any` when all of them did.
    A rejection in an `all` step wins over approvals; an approval in an `any` step
    wins over rejections.
  - Going from the first step, the steps that are met are approved. The first step
    that is neither met nor failed is in progress and the steps after it wait. The
    first step that failed is rejected and the steps after it are skipped ("Not
    reached"): nobody is asked once the flow is rejected.
  - A decision recorded on a step that waits or is skipped is shown, but it does
    not count: the order of the steps is respected.
  - The flow is rejected when a step is, approved when every step is (a flow
    without steps requires nothing and counts as approved) and in progress
    otherwise. A flow is never "waiting" or "skipped": those are states of a step.

`status`, `stepStatuses`, `currentStep` and `pendingApprovers` give you the same
answers the viewer draws, for a list of requests, a badge or a check on the server:

    if ApprovalFlow.isApproved (ApprovalFlow.status flow) then
        shipOrder

Both kinds of status are opaque and asked with `isApproved`, `stepIsSkipped` and
the like, so that states such as "withdrawn" or "returned for changes" can be added
without breaking an application.

**What is shown.** The steps form an ordered list, connected by a line. Each step
shows its status as an icon and in words (never in colour alone), its rule ("All
must approve", "Any one of 2 must approve", "1 of 2 approved"), its approvers with
their decision, the time and the comment, and a due time. The current step is
marked with `aria-current="step"` and drawn stronger. A line above the steps
says where the flow stands and is a polite live region, so a decision that arrives
while the page is open is announced. The layout is vertical, or `horizontal` for a
wide, short strip.

**Overdue.** Give the step a due time (`withDue`) and the flow the current time
(`now`), and an unfinished current step past its due time says "Overdue". The
component never reads the clock itself: keep `Time.Posix` in your model and update
it, for example with `Time.every`.

**Deciding.** When `viewer` is one of the approvers who still has to decide on the
current step, the step shows "Approve" and "Reject" buttons, as far as you gave
`onApprove` and `onReject`. They only send your message: the dialog that asks for
the reason of a rejection, the request to the server and the new decision are
yours. A reject message is the place to open a comment field; when the answer
comes back, put it in the decision (`rejected { at = ..., comment = ... }`).

**Times** are shown in the zone of the `settings` you give (`Klar.Settings`, UTC and marked as such if you give none) and in the format of `locale`, with
[Klar.Format](Klar-Format). The built-in text (statuses, rules, "Overdue", the
buttons) is English unless you set `locale`. Names and comments come from you.


# Views

@docs view, viewRemote


# The flow

@docs Flow, flow, Step, step, withDue, Quorum, all, any


# Approvers and decisions

@docs Approver, approver, Decision, pending, approved, rejected


# Where the flow stands

@docs Status, status, isInProgress, isApproved, isRejected

@docs StepStatus, stepStatuses, stepIsWaiting, stepIsInProgress, stepIsApproved, stepIsRejected, stepIsSkipped

@docs currentStep, pendingApprovers


# Attributes

@docs Attribute, viewer, onApprove, onReject, now, settings, horizontal, ariaLabel, onRetry, locale

-}

import Html exposing (Html)
import Html.Attributes as Attr
import Klar.Avatar as Avatar
import Klar.Badge as Badge
import Klar.Button as Button
import Klar.Date as Date
import Klar.EmptyState as EmptyState
import Klar.ErrorState as ErrorState
import Klar.Format as Format
import Klar.Icon as Icon exposing (Icon)
import Klar.Internal as Internal
import Klar.Internal.Freshness as Freshness
import Klar.Locale as Locale exposing (Locale)
import Klar.Settings as Settings exposing (Settings)
import Klar.Remote as Remote exposing (Remote)
import Klar.Skeleton as Skeleton
import Klar.Theme exposing (Size(..), Tone(..))
import Time



-- DATA


{-| The approval process of one item: a list of steps in the order they are taken.
Make one with `flow`. A flow is plain data that you build from your own records
on every render; it holds no state. `approver` is your own type for the people
(an id, a record), compared with `==`, so it must not contain functions.
-}
type Flow approver
    = Flow (List (Step approver))


{-| One step of the flow: a title, a `Quorum`, and the approvers with their
decisions. Make it with `step`.
-}
type Step approver
    = Step (StepData approver)


type alias StepData approver =
    { title : String
    , quorum : Quorum
    , first : Approver approver
    , rest : List (Approver approver)
    , due : Maybe Time.Posix
    }


{-| How many of the approvers of a step have to approve: `all` of them, or `any`
one of them. Opaque, so that a rule such as "at least two" can be added later
without breaking anyone.
-}
type Quorum
    = Everyone
    | AnyOne


{-| One person who has to decide on a step, with the decision so far. Make it with
`approver`.
-}
type Approver approver
    = Approver approver Decision


{-| What an approver has decided: nothing yet (`pending`), `approved` or
`rejected`, the last two with an optional time and an optional comment.
-}
type Decision
    = DecisionPending
    | DecisionApproved Details
    | DecisionRejected Details


type alias Details =
    { at : Maybe Time.Posix
    , comment : Maybe String
    }


{-| The steps, first step first. The list may be empty: then nothing is required
(the flow counts as approved and the viewer says "No approval is required").

    ApprovalFlow.flow
        [ ApprovalFlow.step "Team lead" ApprovalFlow.all (ApprovalFlow.approver ada ApprovalFlow.pending) []
        ]

-}
flow : List (Step approver) -> Flow approver
flow =
    Flow


{-| A step: the title, the rule, the first approver and the other approvers. A
step needs at least one approver, which is why the first one is a separate
argument: a step nobody can decide on cannot be written. If your data may hold a
step without approvers, decide what that means (leave the step out, show an
error) before you call this; the type does not let you guess.

    ApprovalFlow.step "Finance"
        ApprovalFlow.any
        (ApprovalFlow.approver grace ApprovalFlow.pending)
        [ ApprovalFlow.approver alan ApprovalFlow.pending ]

List every person once per step. The title is the name of the role or the
department ("Team lead", "Finance"), not the number: the steps are numbered by
their place in the flow.

-}
step : String -> Quorum -> Approver approver -> List (Approver approver) -> Step approver
step title quorum first rest =
    Step { title = title, quorum = quorum, first = first, rest = rest, due = Nothing }


{-| The time by which the step should be decided. It is shown on a step that is
in progress or waiting, and marks the current step "Overdue" once the `now` of
the viewer is later. Without it a step has no deadline.
-}
withDue : Time.Posix -> Step approver -> Step approver
withDue time (Step data) =
    Step { data | due = Just time }


{-| Every approver of the step has to approve. One rejection rejects the step.
-}
all : Quorum
all =
    Everyone


{-| One approver is enough: the first approval approves the step. The step is
only rejected when every approver has rejected.
-}
any : Quorum
any =
    AnyOne


{-| A person and what they have decided. `who` is your own type, the same one you
give to `viewer`.

    ApprovalFlow.approver ada (ApprovalFlow.approved { at = Just time, comment = Nothing })

-}
approver : approver -> Decision -> Approver approver
approver who decision =
    Approver who decision


{-| No decision yet.
-}
pending : Decision
pending =
    DecisionPending


{-| The approver approved. `at` is when, if you know; `comment` is what they wrote,
if anything (a blank comment counts as none).

    ApprovalFlow.approved { at = Just time, comment = Just "Matches the return." }

-}
approved : { at : Maybe Time.Posix, comment : Maybe String } -> Decision
approved details =
    DecisionApproved (tidy details)


{-| The approver rejected, with the time and the reason if you have them. The
reason is what the viewer shows under the name, so ask for one when the user
presses "Reject".

    ApprovalFlow.rejected { at = Just time, comment = Just "The amount is wrong." }

-}
rejected : { at : Maybe Time.Posix, comment : Maybe String } -> Decision
rejected details =
    DecisionRejected (tidy details)


tidy : Details -> Details
tidy details =
    { details | comment = Maybe.andThen Internal.nonEmpty details.comment |> Maybe.map String.trim }



-- STATUS


{-| Where the whole flow stands: in progress, approved or rejected. Get it with
`status` and ask it with `isApproved`, `isRejected` and `isInProgress`. It is opaque,
so that a state such as "withdrawn" or "returned for changes" can be added later
without breaking anyone. How it is derived is described in the module documentation.
-}
type Status
    = FlowInProgress
    | FlowApproved
    | FlowRejected


{-| Where one step stands: waiting, in progress, approved, rejected or skipped
(shown as "Not reached"). Get the list with `stepStatuses` and ask each with
`stepIsWaiting`, `stepIsInProgress`, `stepIsApproved`, `stepIsRejected` and
`stepIsSkipped`. It is opaque for the same reason as `Status`.
-}
type StepStatus
    = StepWaiting
    | StepInProgress
    | StepApproved
    | StepRejected
    | StepSkipped


{-| The flow is not finished: a step is being decided.
-}
isInProgress : Status -> Bool
isInProgress theStatus =
    theStatus == FlowInProgress


{-| Every step is approved (also when there are no steps): the item may go on.
-}
isApproved : Status -> Bool
isApproved theStatus =
    theStatus == FlowApproved


{-| A step was rejected: the item stops here.
-}
isRejected : Status -> Bool
isRejected theStatus =
    theStatus == FlowRejected


{-| An earlier step has not been approved yet, so this one has not been reached.
-}
stepIsWaiting : StepStatus -> Bool
stepIsWaiting theStatus =
    theStatus == StepWaiting


{-| The step is being decided.
-}
stepIsInProgress : StepStatus -> Bool
stepIsInProgress theStatus =
    theStatus == StepInProgress


{-| The rule of the step is met.
-}
stepIsApproved : StepStatus -> Bool
stepIsApproved theStatus =
    theStatus == StepApproved


{-| The step can no longer be met: it was rejected.
-}
stepIsRejected : StepStatus -> Bool
stepIsRejected theStatus =
    theStatus == StepRejected


{-| The step is not reached because an earlier step was rejected (the viewer says
"Not reached").
-}
stepIsSkipped : StepStatus -> Bool
stepIsSkipped theStatus =
    theStatus == StepSkipped


type Outcome
    = Met
    | Failed
    | Open


decisionOf : Approver approver -> Decision
decisionOf (Approver _ decision) =
    decision


isApproval : Decision -> Bool
isApproval decision =
    case decision of
        DecisionApproved _ ->
            True

        _ ->
            False


isRejection : Decision -> Bool
isRejection decision =
    case decision of
        DecisionRejected _ ->
            True

        _ ->
            False


approversOf : StepData approver -> List (Approver approver)
approversOf data =
    data.first :: data.rest


countWhere : (Decision -> Bool) -> StepData approver -> Int
countWhere test data =
    approversOf data
        |> List.filter (\person -> test (decisionOf person))
        |> List.length


{-| Whether the rule of a step is met, failed, or still open, by its own
decisions alone.
-}
outcome : StepData approver -> Outcome
outcome data =
    let
        total =
            1 + List.length data.rest

        yes =
            countWhere isApproval data

        no =
            countWhere isRejection data
    in
    case data.quorum of
        Everyone ->
            if no > 0 then
                Failed

            else if yes == total then
                Met

            else
                Open

        AnyOne ->
            if yes > 0 then
                Met

            else if no == total then
                Failed

            else
                Open


type Phase
    = Walking
    | Blocked
    | Stopped


{-| Where each step stands, in the order of the steps. The list always has as many
entries as the flow has steps and has one of three shapes: some approved steps,
then either nothing more, or one step in progress followed by waiting steps, or one
rejected step followed by skipped steps.
-}
stepStatuses : Flow approver -> List StepStatus
stepStatuses (Flow steps) =
    walk Walking steps


walk : Phase -> List (Step approver) -> List StepStatus
walk phase steps =
    case steps of
        [] ->
            []

        (Step data) :: rest ->
            case phase of
                Walking ->
                    case outcome data of
                        Met ->
                            StepApproved :: walk Walking rest

                        Open ->
                            StepInProgress :: walk Blocked rest

                        Failed ->
                            StepRejected :: walk Stopped rest

                Blocked ->
                    StepWaiting :: walk Blocked rest

                Stopped ->
                    StepSkipped :: walk Stopped rest


{-| Where the whole flow stands: rejected when a step was rejected, approved when
every step is approved (also when there are no steps, which require nothing), in
progress otherwise.

    ApprovalFlow.isInProgress (ApprovalFlow.status (creditNoteFlow deadline)) --> True

-}
status : Flow approver -> Status
status theFlow =
    let
        list =
            stepStatuses theFlow
    in
    if List.member StepRejected list then
        FlowRejected

    else if List.all (\each -> each == StepApproved) list then
        FlowApproved

    else
        FlowInProgress


{-| The step the flow stands at, counting from 0 like [Klar.Stepper](Klar-Stepper):
the first step that is not approved, which is the step being decided or the step
that was rejected. Nothing when every step is approved, and for a flow without
steps. The viewer marks this step with `aria-current="step"`.
-}
currentStep : Flow approver -> Maybe Int
currentStep theFlow =
    stepStatuses theFlow
        |> List.indexedMap Tuple.pair
        |> List.filter (\( _, each ) -> each == StepInProgress || each == StepRejected)
        |> List.head
        |> Maybe.map Tuple.first


{-| The people who still have to decide for the flow to move on: the approvers of
the step being decided who have not decided. Empty when the flow is approved or
rejected. The viewer offers "Approve" and "Reject" to a `viewer` in this list,
and you can use it to find the requests that wait for a person.

    List.member model.me (ApprovalFlow.pendingApprovers flow)

-}
pendingApprovers : Flow approver -> List approver
pendingApprovers ((Flow steps) as theFlow) =
    List.map2 Tuple.pair steps (stepStatuses theFlow)
        |> List.filter (\( _, each ) -> each == StepInProgress)
        |> List.head
        |> Maybe.map
            (\( Step data, _ ) ->
                approversOf data
                    |> List.filterMap
                        (\(Approver who decision) ->
                            if decision == DecisionPending then
                                Just who

                            else
                                Nothing
                        )
            )
        |> Maybe.withDefault []



-- ATTRIBUTES


{-| A setting of the viewer. Make them with the functions below and pass a list to
`view` or `viewRemote`; later attributes win over earlier ones. `approver` is your
type for people, `msg` your message type.
-}
type Attribute approver msg
    = Attribute (Config approver msg -> Config approver msg)


type alias Config approver msg =
    { locale : Locale
    , settings : Settings
    , now : Maybe Time.Posix
    , horizontal : Bool
    , label : Maybe String
    , viewer : Maybe approver
    , onApprove : Maybe msg
    , onReject : Maybe msg
    , onRetry : Maybe msg
    }


configure : List (Attribute approver msg) -> Config approver msg
configure attributes =
    List.foldl (\(Attribute change) config -> change config)
        { locale = Locale.default
        , settings = Settings.default
        , now = Nothing
        , horizontal = False
        , label = Nothing
        , viewer = Nothing
        , onApprove = Nothing
        , onReject = Nothing
        , onRetry = Nothing
        }
        attributes


{-| Who is looking at the flow, in the same type as the approvers, or `Nothing`
for someone who is not signed in or not involved. When the viewer is an approver
who has not decided on the step being decided, that step gets the "Approve" and
"Reject" buttons (see `onApprove` and `onReject`) and the viewer's name says
"(you)". The default is `Nothing`.
-}
viewer : Maybe approver -> Attribute approver msg
viewer who =
    Attribute (\config -> { config | viewer = who })


{-| The message sent by the "Approve" button. The button is shown to a `viewer`
who has to decide on the current step. Without it there is no such button.
-}
onApprove : msg -> Attribute approver msg
onApprove msg =
    Attribute (\config -> { config | onApprove = Just msg })


{-| The message sent by the "Reject" button, shown like "Approve". The viewer asks
for nothing: if a rejection needs a reason, open your own dialog or field when
this message arrives and send the decision with its comment afterwards.
-}
onReject : msg -> Attribute approver msg
onReject msg =
    Attribute (\config -> { config | onReject = Just msg })


{-| The current time. It decides whether a step is overdue and lets the times
carry a tooltip such as "3 days ago". Without it nothing is marked overdue. The
viewer does not read the clock: keep the value in your model and update it.
-}
now : Time.Posix -> Attribute approver msg
now time =
    Attribute (\config -> { config | now = Just time })


{-| The settings of the application (`Klar.Settings`): the time zone of the times
of decisions and deadlines. Without it the times are written in UTC and end in
"UTC".

    ApprovalFlow.settings model.settings

-}
settings : Settings -> Attribute approver msg
settings given =
    Attribute (\config -> { config | settings = given })


{-| Lays the steps out side by side, for a wide and short strip. The default is
vertical, one step below the other, which suits a side panel and long comments. A
row with many steps scrolls sideways.
-}
horizontal : Attribute approver msg
horizontal =
    Attribute (\config -> { config | horizontal = True })


{-| The accessible name of the flow, such as "Approval of credit note 2024-117".
The default is "Approval steps" in the language of `locale`.
-}
ariaLabel : String -> Attribute approver msg
ariaLabel text =
    Attribute (\config -> { config | label = Just text })


{-| The message sent by the "Try again" button when `viewRemote` shows a failure
that is worth retrying.
-}
onRetry : msg -> Attribute approver msg
onRetry msg =
    Attribute (\config -> { config | onRetry = Just msg })


{-| The language of the built-in text: statuses, rules, "Overdue", the buttons and
the labels for screen readers, and of the format of times. The default is
`Locale.default`, which is English. See [Klar.Locale](Klar-Locale).
-}
locale : Locale -> Attribute approver msg
locale value =
    Attribute (\config -> { config | locale = value })



-- TEXT


type alias Texts =
    { label : String
    , waitingFor : Int -> String
    , inProgress : String
    , approved : String
    , rejected : String
    , notReached : String
    , pending : String
    , everyone : String
    , anyOne : Int -> String
    , countApproved : Int -> Int -> String
    , due : String
    , overdue : String
    , approve : String
    , reject : String
    , yourDecision : String -> String
    , you : String
    , stepNumber : Int -> String
    , empty : String
    , loading : String
    , summaryApproved : String
    , summaryRejected : Int -> String -> String
    , summaryInProgress : Int -> Int -> String -> String
    }


texts : Locale -> Texts
texts loc =
    let
        pick nb en =
            Locale.pick loc { nb = nb, en = en }

        number n =
            Format.int loc n
    in
    { label = pick "Godkjenningssteg" "Approval steps"
    , waitingFor = \n -> pick ("Venter på steg " ++ number n) ("Waiting for step " ++ number n)
    , inProgress = pick "Pågår" "In progress"
    , approved = pick "Godkjent" "Approved"
    , rejected = pick "Avvist" "Rejected"
    , notReached = pick "Ikke aktuelt" "Not reached"
    , pending = pick "Venter på svar" "Pending"
    , everyone = pick "Alle må godkjenne" "All must approve"
    , anyOne = \n -> pick ("Én av " ++ number n ++ " må godkjenne") ("Any one of " ++ number n ++ " must approve")
    , countApproved = \yes total -> pick (number yes ++ " av " ++ number total ++ " godkjent") (number yes ++ " of " ++ number total ++ " approved")
    , due = pick "Frist" "Due"
    , overdue = pick "Over fristen" "Overdue"
    , approve = pick "Godkjenn" "Approve"
    , reject = pick "Avvis" "Reject"
    , yourDecision = \title -> pick ("Din beslutning om " ++ title) ("Your decision on " ++ title)
    , you = pick "du" "you"
    , stepNumber = \n -> pick ("Steg " ++ number n) ("Step " ++ number n)
    , empty = pick "Ingen godkjenning kreves" "No approval is required"
    , loading = pick "Laster godkjenningen" "Loading the approval"
    , summaryApproved = pick "Godkjent" "Approved"
    , summaryRejected = \n title -> pick ("Avvist i steg " ++ number n ++ " (" ++ title ++ ")") ("Rejected at step " ++ number n ++ " (" ++ title ++ ")")
    , summaryInProgress = \n total title -> pick ("Pågår: steg " ++ number n ++ " av " ++ number total ++ " (" ++ title ++ ")") ("In progress: step " ++ number n ++ " of " ++ number total ++ " (" ++ title ++ ")")
    }



-- VIEW


{-| The flow as an ordered list of steps with a line above that says where it
stands. The first argument turns one of your approvers into a name and, if you
have one, the URL of a picture; the name is shown next to a small avatar.

    ApprovalFlow.view personOf [ ApprovalFlow.viewer (Just model.me) ] (creditNoteFlow model.deadline)

A flow without steps shows "No approval is required".

-}
view : (approver -> Avatar.Entry) -> List (Attribute approver msg) -> Flow approver -> Html msg
view person attributes theFlow =
    let
        config =
            configure attributes

        t =
            texts config.locale
    in
    case theFlow of
        Flow [] ->
            EmptyState.view
                [ EmptyState.compact
                , EmptyState.icon Icon.shieldCheck
                , EmptyState.title t.empty
                ]

        Flow steps ->
            viewSteps person config t theFlow steps


{-| The same for a flow that comes from the backend. `Success` shows the flow,
`Failure` shows the problem with a "Try again" button (`onRetry`), and `NotAsked`
and `Loading` show a skeleton of steps.

    ApprovalFlow.viewRemote personOf [ ApprovalFlow.onRetry Reload ] (Remote.map toFlow model.approval)

-}
viewRemote : (approver -> Avatar.Entry) -> List (Attribute approver msg) -> Remote (Flow approver) -> Html msg
viewRemote person attributes data =
    let
        config =
            configure attributes

        t =
            texts config.locale
    in
    case Tuple.first (Freshness.settle data) of
        Remote.Loaded theFlow ->
            view person attributes theFlow

        Remote.Failed problem ->
            ErrorState.view
                (List.filterMap identity
                    [ Just ErrorState.compact
                    , Just (ErrorState.locale config.locale)
                    , Maybe.map ErrorState.onRetry config.onRetry
                    ]
                )
                problem

        _ ->
            Html.div
                [ Internal.cls [ "klar-approval", "klar-approval--skeleton" ]
                , Attr.attribute "aria-busy" "true"
                ]
                (Html.span [ Internal.cls [ "klar-sr-only" ], Attr.attribute "role" "status" ] [ Html.text t.loading ]
                    :: List.map
                        (\width ->
                            Html.div [ Internal.cls [ "klar-approval__skeleton-step" ], Attr.attribute "aria-hidden" "true" ]
                                [ Skeleton.circle 24
                                , Html.div [ Internal.cls [ "klar-approval__skeleton-text" ] ]
                                    [ Skeleton.line width, Skeleton.line 70 ]
                                ]
                        )
                        [ 40, 55, 35 ]
                )


type alias Env approver msg =
    { config : Config approver msg
    , t : Texts
    , person : approver -> Avatar.Entry
    , current : Maybe Int
    , total : Int
    , canDecide : Bool
    }


viewSteps : (approver -> Avatar.Entry) -> Config approver msg -> Texts -> Flow approver -> List (Step approver) -> Html msg
viewSteps person config t theFlow steps =
    let
        current =
            currentStep theFlow

        env =
            { config = config
            , t = t
            , person = person
            , current = current
            , total = List.length steps
            , canDecide =
                case config.viewer of
                    Just who ->
                        List.member who (pendingApprovers theFlow)

                    Nothing ->
                        False
            }

        titleOf index =
            steps
                |> List.drop index
                |> List.head
                |> Maybe.map (\(Step data) -> data.title)
                |> Maybe.withDefault ""

        summaryText =
            case status theFlow of
                FlowApproved ->
                    t.summaryApproved

                FlowRejected ->
                    t.summaryRejected (Maybe.withDefault 0 current + 1) (titleOf (Maybe.withDefault 0 current))

                _ ->
                    t.summaryInProgress (Maybe.withDefault 0 current + 1) env.total (titleOf (Maybe.withDefault 0 current))

        summaryIcon =
            case status theFlow of
                FlowApproved ->
                    Icon.checkCircle

                FlowRejected ->
                    Icon.xCircle

                _ ->
                    Icon.clock
    in
    Html.section
        [ Internal.cls
            [ "klar-approval"
            , if config.horizontal then
                "klar-approval--horizontal"

              else
                "klar-approval--vertical"
            ]
        , Attr.attribute "aria-label" (Maybe.withDefault t.label config.label)
        ]
        [ Html.p
            [ Internal.cls [ "klar-approval__summary", "klar-approval__summary--" ++ flowSuffix (status theFlow) ]
            , Attr.attribute "role" "status"
            ]
            [ Icon.view summaryIcon
            , Html.span [] [ Html.text summaryText ]
            ]
        , Html.ol [ Internal.cls [ "klar-approval__steps" ], Attr.attribute "role" "list" ]
            (List.map2 Tuple.pair steps (stepStatuses theFlow)
                |> List.indexedMap (\index ( each, state ) -> viewStep env index each state)
            )
        ]


flowSuffix : Status -> String
flowSuffix theStatus =
    case theStatus of
        FlowInProgress ->
            "in-progress"

        FlowApproved ->
            "approved"

        FlowRejected ->
            "rejected"


statusSuffix : StepStatus -> String
statusSuffix state =
    case state of
        StepWaiting ->
            "waiting"

        StepInProgress ->
            "in-progress"

        StepApproved ->
            "approved"

        StepRejected ->
            "rejected"

        StepSkipped ->
            "skipped"


statusIcon : StepStatus -> Icon
statusIcon state =
    case state of
        StepWaiting ->
            Icon.hourglass

        StepInProgress ->
            Icon.clock

        StepApproved ->
            Icon.checkCircle

        StepRejected ->
            Icon.xCircle

        StepSkipped ->
            Icon.minusCircle


statusText : Env approver msg -> StepStatus -> String
statusText env state =
    case state of
        StepWaiting ->
            env.t.waitingFor (Maybe.withDefault 0 env.current + 1)

        StepInProgress ->
            env.t.inProgress

        StepApproved ->
            env.t.approved

        StepRejected ->
            env.t.rejected

        StepSkipped ->
            env.t.notReached


viewStep : Env approver msg -> Int -> Step approver -> StepStatus -> Html msg
viewStep env index (Step data) state =
    let
        t =
            env.t

        isCurrent =
            env.current == Just index

        people =
            approversOf data

        total =
            List.length people

        yes =
            countWhere isApproval data

        isOverdue =
            case ( data.due, env.config.now ) of
                ( Just due, Just current ) ->
                    state == StepInProgress && Time.posixToMillis current > Time.posixToMillis due

                _ ->
                    False

        rule =
            if total == 1 then
                Nothing

            else
                Just
                    (case data.quorum of
                        Everyone ->
                            t.everyone

                        AnyOne ->
                            t.anyOne total
                    )

        progress =
            if total > 1 && data.quorum == Everyone && (state == StepInProgress || state == StepApproved) then
                Just (t.countApproved yes total)

            else
                Nothing

        dueNote =
            case data.due of
                Just due ->
                    if state == StepInProgress || state == StepWaiting then
                        Just (viewDue env isOverdue due)

                    else
                        Nothing

                Nothing ->
                    Nothing

        notes =
            List.filterMap identity
                [ Maybe.map (\text -> Html.span [] [ Html.text text ]) rule
                , Maybe.map (\text -> Html.span [] [ Html.text text ]) progress
                , dueNote
                ]

        marker =
            Html.span [ Internal.cls [ "klar-approval__marker" ], Attr.attribute "aria-hidden" "true" ]
                [ case state of
                    StepApproved ->
                        Icon.sized Icon.Small Icon.check

                    StepRejected ->
                        Icon.sized Icon.Small Icon.close

                    StepInProgress ->
                        Icon.sized Icon.Small Icon.clock

                    StepSkipped ->
                        Icon.sized Icon.Small Icon.minus

                    StepWaiting ->
                        Html.text (String.fromInt (index + 1))
                ]
    in
    Html.li
        ([ Internal.cls
            [ "klar-approval__step"
            , "klar-approval__step--" ++ statusSuffix state
            , if isCurrent then
                "klar-approval__step--current"

              else
                ""
            , if isOverdue then
                "klar-approval__step--overdue"

              else
                ""
            ]
         ]
            ++ (if isCurrent then
                    [ Attr.attribute "aria-current" "step" ]

                else
                    []
               )
        )
        [ marker
        , Html.div [ Internal.cls [ "klar-approval__body" ] ]
            [ Html.div [ Internal.cls [ "klar-approval__head" ] ]
                [ Html.span [ Internal.cls [ "klar-approval__title" ] ]
                    [ Html.span [ Internal.cls [ "klar-sr-only" ] ] [ Html.text (t.stepNumber (index + 1) ++ ": ") ]
                    , Html.text data.title
                    ]
                , Html.span [ Internal.cls [ "klar-approval__status" ] ]
                    [ Icon.view (statusIcon state)
                    , Html.span [] [ Html.text (statusText env state) ]
                    ]
                , Internal.viewIf isOverdue
                    (Badge.view [ Badge.tone Danger, Badge.icon Icon.warning, Badge.size Small ] t.overdue)
                ]
            , Internal.viewIf (not (List.isEmpty notes))
                (Html.p [ Internal.cls [ "klar-approval__meta" ] ] notes)
            , Html.ul [ Internal.cls [ "klar-approval__people" ], Attr.attribute "role" "list" ]
                (List.map (viewPerson env) people)
            , viewActions env state isCurrent data.title
            ]
        ]


viewDue : Env approver msg -> Bool -> Time.Posix -> Html msg
viewDue env isOverdue due =
    Html.span
        [ Internal.cls
            [ "klar-approval__due"
            , if isOverdue then
                "klar-approval__due--overdue"

              else
                ""
            ]
        ]
        [ Html.text (env.t.due ++ " ")
        , timeElement env due
        ]


timeElement : Env approver msg -> Time.Posix -> Html msg
timeElement env time =
    let
        config =
            env.config
    in
    Html.time
        ([ Internal.cls [ "klar-approval__time", "klar-tabular" ]
         , Attr.attribute "datetime" (isoTime time)
         ]
            ++ (case config.now of
                    Just current ->
                        [ Attr.title (Format.relative config.locale current time) ]

                    Nothing ->
                        []
               )
        )
        [ Html.text (Settings.dateTime config.locale config.settings time) ]


isoTime : Time.Posix -> String
isoTime posix =
    let
        pad2 n =
            String.padLeft 2 '0' (String.fromInt n)
    in
    Date.toIso (Date.fromPosix Time.utc posix)
        ++ "T"
        ++ pad2 (Time.toHour Time.utc posix)
        ++ ":"
        ++ pad2 (Time.toMinute Time.utc posix)
        ++ ":"
        ++ pad2 (Time.toSecond Time.utc posix)
        ++ "Z"


viewPerson : Env approver msg -> Approver approver -> Html msg
viewPerson env (Approver who decision) =
    let
        t =
            env.t

        entry =
            env.person who

        isViewer =
            env.config.viewer == Just who

        shown =
            case decision of
                DecisionPending ->
                    { suffix = "pending", glyph = Icon.clock, text = t.pending, details = Nothing }

                DecisionApproved d ->
                    { suffix = "approved", glyph = Icon.check, text = t.approved, details = Just d }

                DecisionRejected d ->
                    { suffix = "rejected", glyph = Icon.close, text = t.rejected, details = Just d }
    in
    Html.li [ Internal.cls [ "klar-approval__person", "klar-approval__person--" ++ shown.suffix ] ]
        [ Avatar.view
            (Avatar.extraSmall
                :: Avatar.decorative
                :: List.filterMap identity [ Maybe.map Avatar.image entry.image ]
            )
            entry.name
        , Html.span [ Internal.cls [ "klar-approval__name" ], Attr.title entry.name ]
            [ Html.text entry.name
            , Internal.viewIf isViewer (Html.span [ Internal.cls [ "klar-approval__you" ] ] [ Html.text (" (" ++ t.you ++ ")") ])
            ]
        , Html.span [ Internal.cls [ "klar-approval__decision" ] ]
            [ Icon.view shown.glyph
            , Html.span [] [ Html.text shown.text ]
            ]
        , case shown.details of
            Just d ->
                Html.span [ Internal.cls [ "klar-approval__when" ] ]
                    [ Internal.viewMaybe (timeElement env) d.at ]

            Nothing ->
                Html.text ""
        , case Maybe.andThen .comment shown.details of
            Just comment ->
                Html.p [ Internal.cls [ "klar-approval__comment" ] ] [ Html.text comment ]

            Nothing ->
                Html.text ""
        ]


viewActions : Env approver msg -> StepStatus -> Bool -> String -> Html msg
viewActions env state isCurrent title =
    let
        t =
            env.t

        buttons =
            List.filterMap identity
                [ Maybe.map (\msg -> Button.view [ Button.small, Button.primary, Button.icon Icon.check, Button.onClick msg ] t.approve) env.config.onApprove
                , Maybe.map (\msg -> Button.view [ Button.small, Button.danger, Button.icon Icon.close, Button.onClick msg ] t.reject) env.config.onReject
                ]
    in
    if state == StepInProgress && isCurrent && env.canDecide && not (List.isEmpty buttons) then
        Html.div
            [ Internal.cls [ "klar-approval__actions" ]
            , Attr.attribute "role" "group"
            , Attr.attribute "aria-label" (t.yourDecision title)
            ]
            buttons

    else
        Html.text ""
