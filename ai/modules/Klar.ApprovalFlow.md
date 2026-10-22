# Klar.ApprovalFlow

The approval process of one item: an ordered list of steps, each with one or several approvers and a decision from each, and where the item stands.

Import: `import Klar.ApprovalFlow as ApprovalFlow` | Group: Access and approval

Types: `Flow`, `Step`, `Quorum`, `Status`, `Approver`, `Decision`, `Attribute`, `StepStatus`

## Signatures

```elm
-- Views
view : (approver -> Avatar.Entry) -> List (Attribute approver msg) -> Flow approver -> Html msg
viewRemote :
    (approver -> Avatar.Entry)
    -> List (Attribute approver msg)
    -> Remote.Remote (Flow approver)
    -> Html msg

-- The flow
type Flow approver  -- opaque: no constructors are exposed
type Step approver  -- opaque: no constructors are exposed
type Quorum  -- opaque: no constructors are exposed
flow : List (Step approver) -> Flow approver
step : String -> Quorum -> Approver approver -> List (Approver approver) -> Step approver
withDue : Time.Posix -> Step approver -> Step approver
all : Quorum
any : Quorum

-- Approvers and decisions
type Approver approver  -- opaque: no constructors are exposed
type Decision  -- opaque: no constructors are exposed
approver : approver -> Decision -> Approver approver
pending : Decision
approved : { at : Maybe Time.Posix, comment : Maybe String } -> Decision
rejected : { at : Maybe Time.Posix, comment : Maybe String } -> Decision

-- Where the flow stands
type Status  -- opaque: no constructors are exposed
status : Flow approver -> Status
isInProgress : Status -> Bool
isApproved : Status -> Bool
isRejected : Status -> Bool
type StepStatus  -- opaque: no constructors are exposed
stepStatuses : Flow approver -> List StepStatus
stepIsWaiting : StepStatus -> Bool
stepIsInProgress : StepStatus -> Bool
stepIsApproved : StepStatus -> Bool
stepIsRejected : StepStatus -> Bool
stepIsSkipped : StepStatus -> Bool
currentStep : Flow approver -> Maybe Int
pendingApprovers : Flow approver -> List approver

-- Attributes
type Attribute approver msg  -- opaque: no constructors are exposed
viewer : Maybe approver -> Attribute approver msg
onApprove : msg -> Attribute approver msg
onReject : msg -> Attribute approver msg
now : Time.Posix -> Attribute approver msg
settings : Settings.Settings -> Attribute approver msg
horizontal : Attribute approver msg
ariaLabel : String -> Attribute approver msg
onRetry : msg -> Attribute approver msg
locale : Locale.Locale -> Attribute approver msg
```

## Documentation

The approval process of one item: an ordered list of steps, each with one or
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
[Klar.Timeline](Klar.Timeline.md); for the steps of a wizard the user fills in
himself, [Klar.Stepper](Klar.Stepper.md).

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
[Klar.Format](Klar.Format.md). The built-in text (statuses, rules, "Overdue", the
buttons) is English unless you set `locale`. Names and comments come from you.

## Views

### `view`

```elm
view : (approver -> Avatar.Entry) -> List (Attribute approver msg) -> Flow approver -> Html msg
```

The flow as an ordered list of steps with a line above that says where it
stands. The first argument turns one of your approvers into a name and, if you
have one, the URL of a picture; the name is shown next to a small avatar.

    ApprovalFlow.view personOf [ ApprovalFlow.viewer (Just model.me) ] (creditNoteFlow model.deadline)

A flow without steps shows "No approval is required".

### `viewRemote`

```elm
viewRemote :
    (approver -> Avatar.Entry)
    -> List (Attribute approver msg)
    -> Remote.Remote (Flow approver)
    -> Html msg
```

The same for a flow that comes from the backend. `Success` shows the flow,
`Failure` shows the problem with a "Try again" button (`onRetry`), and `NotAsked`
and `Loading` show a skeleton of steps.

    ApprovalFlow.viewRemote personOf [ ApprovalFlow.onRetry Reload ] (Remote.map toFlow model.approval)

## The flow

### `Flow`

```elm
type Flow approver  -- opaque: no constructors are exposed
```

The approval process of one item: a list of steps in the order they are taken.
Make one with `flow`. A flow is plain data that you build from your own records
on every render; it holds no state. `approver` is your own type for the people
(an id, a record), compared with `==`, so it must not contain functions.

### `Step`

```elm
type Step approver  -- opaque: no constructors are exposed
```

One step of the flow: a title, a `Quorum`, and the approvers with their
decisions. Make it with `step`.

### `Quorum`

```elm
type Quorum  -- opaque: no constructors are exposed
```

How many of the approvers of a step have to approve: `all` of them, or `any`
one of them. Opaque, so that a rule such as "at least two" can be added later
without breaking anyone.

### `flow`

```elm
flow : List (Step approver) -> Flow approver
```

The steps, first step first. The list may be empty: then nothing is required
(the flow counts as approved and the viewer says "No approval is required").

    ApprovalFlow.flow
        [ ApprovalFlow.step "Team lead" ApprovalFlow.all (ApprovalFlow.approver ada ApprovalFlow.pending) []
        ]

### `step`

```elm
step : String -> Quorum -> Approver approver -> List (Approver approver) -> Step approver
```

A step: the title, the rule, the first approver and the other approvers. A
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

### `withDue`

```elm
withDue : Time.Posix -> Step approver -> Step approver
```

The time by which the step should be decided. It is shown on a step that is
in progress or waiting, and marks the current step "Overdue" once the `now` of
the viewer is later. Without it a step has no deadline.

### `all`

```elm
all : Quorum
```

Every approver of the step has to approve. One rejection rejects the step.

### `any`

```elm
any : Quorum
```

One approver is enough: the first approval approves the step. The step is
only rejected when every approver has rejected.

## Approvers and decisions

### `Approver`

```elm
type Approver approver  -- opaque: no constructors are exposed
```

One person who has to decide on a step, with the decision so far. Make it with
`approver`.

### `Decision`

```elm
type Decision  -- opaque: no constructors are exposed
```

What an approver has decided: nothing yet (`pending`), `approved` or
`rejected`, the last two with an optional time and an optional comment.

### `approver`

```elm
approver : approver -> Decision -> Approver approver
```

A person and what they have decided. `who` is your own type, the same one you
give to `viewer`.

    ApprovalFlow.approver ada (ApprovalFlow.approved { at = Just time, comment = Nothing })

### `pending`

```elm
pending : Decision
```

No decision yet.

### `approved`

```elm
approved : { at : Maybe Time.Posix, comment : Maybe String } -> Decision
```

The approver approved. `at` is when, if you know; `comment` is what they wrote,
if anything (a blank comment counts as none).

    ApprovalFlow.approved { at = Just time, comment = Just "Matches the return." }

### `rejected`

```elm
rejected : { at : Maybe Time.Posix, comment : Maybe String } -> Decision
```

The approver rejected, with the time and the reason if you have them. The
reason is what the viewer shows under the name, so ask for one when the user
presses "Reject".

    ApprovalFlow.rejected { at = Just time, comment = Just "The amount is wrong." }

## Where the flow stands

### `Status`

```elm
type Status  -- opaque: no constructors are exposed
```

Where the whole flow stands: in progress, approved or rejected. Get it with
`status` and ask it with `isApproved`, `isRejected` and `isInProgress`. It is opaque,
so that a state such as "withdrawn" or "returned for changes" can be added later
without breaking anyone. How it is derived is described in the module documentation.

### `status`

```elm
status : Flow approver -> Status
```

Where the whole flow stands: rejected when a step was rejected, approved when
every step is approved (also when there are no steps, which require nothing), in
progress otherwise.

    ApprovalFlow.isInProgress (ApprovalFlow.status (creditNoteFlow deadline)) --> True

### `isInProgress`

```elm
isInProgress : Status -> Bool
```

The flow is not finished: a step is being decided.

### `isApproved`

```elm
isApproved : Status -> Bool
```

Every step is approved (also when there are no steps): the item may go on.

### `isRejected`

```elm
isRejected : Status -> Bool
```

A step was rejected: the item stops here.

### `StepStatus`

```elm
type StepStatus  -- opaque: no constructors are exposed
```

Where one step stands: waiting, in progress, approved, rejected or skipped
(shown as "Not reached"). Get the list with `stepStatuses` and ask each with
`stepIsWaiting`, `stepIsInProgress`, `stepIsApproved`, `stepIsRejected` and
`stepIsSkipped`. It is opaque for the same reason as `Status`.

### `stepStatuses`

```elm
stepStatuses : Flow approver -> List StepStatus
```

Where each step stands, in the order of the steps. The list always has as many
entries as the flow has steps and has one of three shapes: some approved steps,
then either nothing more, or one step in progress followed by waiting steps, or one
rejected step followed by skipped steps.

### `stepIsWaiting`

```elm
stepIsWaiting : StepStatus -> Bool
```

An earlier step has not been approved yet, so this one has not been reached.

### `stepIsInProgress`

```elm
stepIsInProgress : StepStatus -> Bool
```

The step is being decided.

### `stepIsApproved`

```elm
stepIsApproved : StepStatus -> Bool
```

The rule of the step is met.

### `stepIsRejected`

```elm
stepIsRejected : StepStatus -> Bool
```

The step can no longer be met: it was rejected.

### `stepIsSkipped`

```elm
stepIsSkipped : StepStatus -> Bool
```

The step is not reached because an earlier step was rejected (the viewer says
"Not reached").

### `currentStep`

```elm
currentStep : Flow approver -> Maybe Int
```

The step the flow stands at, counting from 0 like [Klar.Stepper](Klar.Stepper.md):
the first step that is not approved, which is the step being decided or the step
that was rejected. Nothing when every step is approved, and for a flow without
steps. The viewer marks this step with `aria-current="step"`.

### `pendingApprovers`

```elm
pendingApprovers : Flow approver -> List approver
```

The people who still have to decide for the flow to move on: the approvers of
the step being decided who have not decided. Empty when the flow is approved or
rejected. The viewer offers "Approve" and "Reject" to a `viewer` in this list,
and you can use it to find the requests that wait for a person.

    List.member model.me (ApprovalFlow.pendingApprovers flow)

## Attributes

### `Attribute`

```elm
type Attribute approver msg  -- opaque: no constructors are exposed
```

A setting of the viewer. Make them with the functions below and pass a list to
`view` or `viewRemote`; later attributes win over earlier ones. `approver` is your
type for people, `msg` your message type.

### `viewer`

```elm
viewer : Maybe approver -> Attribute approver msg
```

Who is looking at the flow, in the same type as the approvers, or `Nothing`
for someone who is not signed in or not involved. When the viewer is an approver
who has not decided on the step being decided, that step gets the "Approve" and
"Reject" buttons (see `onApprove` and `onReject`) and the viewer's name says
"(you)". The default is `Nothing`.

### `onApprove`

```elm
onApprove : msg -> Attribute approver msg
```

The message sent by the "Approve" button. The button is shown to a `viewer`
who has to decide on the current step. Without it there is no such button.

### `onReject`

```elm
onReject : msg -> Attribute approver msg
```

The message sent by the "Reject" button, shown like "Approve". The viewer asks
for nothing: if a rejection needs a reason, open your own dialog or field when
this message arrives and send the decision with its comment afterwards.

### `now`

```elm
now : Time.Posix -> Attribute approver msg
```

The current time. It decides whether a step is overdue and lets the times
carry a tooltip such as "3 days ago". Without it nothing is marked overdue. The
viewer does not read the clock: keep the value in your model and update it.

### `settings`

```elm
settings : Settings.Settings -> Attribute approver msg
```

The settings of the application (`Klar.Settings`): the time zone of the times
of decisions and deadlines. Without it the times are written in UTC and end in
"UTC".

    ApprovalFlow.settings model.settings

### `horizontal`

```elm
horizontal : Attribute approver msg
```

Lays the steps out side by side, for a wide and short strip. The default is
vertical, one step below the other, which suits a side panel and long comments. A
row with many steps scrolls sideways.

### `ariaLabel`

```elm
ariaLabel : String -> Attribute approver msg
```

The accessible name of the flow, such as "Approval of credit note 2024-117".
The default is "Approval steps" in the language of `locale`.

### `onRetry`

```elm
onRetry : msg -> Attribute approver msg
```

The message sent by the "Try again" button when `viewRemote` shows a failure
that is worth retrying.

### `locale`

```elm
locale : Locale.Locale -> Attribute approver msg
```

The language of the built-in text: statuses, rules, "Overdue", the buttons and
the labels for screen readers, and of the format of times. The default is
`Locale.default`, which is English. See [Klar.Locale](Klar.Locale.md).
