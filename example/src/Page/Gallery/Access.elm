module Page.Gallery.Access exposing (Model, Msg, init, subscriptions, update, view)

{-| Gallery page: roles and approvals. A permission matrix whose roles inherit from
each other, with Save and Discard around it, and an approval flow in which the viewer
approves or rejects and the displayed state follows at once.

The matrix keeps its values here, in `Decisions`: only what was said directly about a
role. A role without a decision inherits from its parent, and the matrix is told both
(`PermissionMatrix.cell`). A change says what a role should have of its own, or nothing,
which removes the decision so that the cell inherits again.

-}

import Dict exposing (Dict)
import Html exposing (Html)
import Html.Attributes as Attr
import Klar
import Klar.ApprovalFlow as ApprovalFlow
import Klar.Avatar as Avatar
import Klar.Button as Button
import Klar.Layout as Layout
import Klar.Locale exposing (Locale)
import Klar.PermissionMatrix as PermissionMatrix
import Klar.Remote as Remote
import Klar.Settings exposing (Settings)
import Klar.Text as Text
import Klar.TextArea as TextArea
import Klar.Theme as Theme
import Set exposing (Set)
import Showcase.Doc as Doc
import Showcase.Sample as Sample
import Task
import Time



-- ROLES AND PERMISSIONS


type Role
    = Picker
    | Dispatcher
    | Supervisor
    | Administrator


type Permission
    = ViewOrders
    | EditOrders
    | CancelOrders
    | ViewStock
    | AdjustStock
    | ExportReports
    | ManageUsers


roleKey : Role -> String
roleKey role =
    case role of
        Picker ->
            "picker"

        Dispatcher ->
            "dispatcher"

        Supervisor ->
            "supervisor"

        Administrator ->
            "administrator"


roleName : Role -> String
roleName role =
    case role of
        Picker ->
            "Picker"

        Dispatcher ->
            "Dispatcher"

        Supervisor ->
            "Supervisor"

        Administrator ->
            "Administrator"


permissionKey : Permission -> String
permissionKey permission =
    case permission of
        ViewOrders ->
            "view-orders"

        EditOrders ->
            "edit-orders"

        CancelOrders ->
            "cancel-orders"

        ViewStock ->
            "view-stock"

        AdjustStock ->
            "adjust-stock"

        ExportReports ->
            "export-reports"

        ManageUsers ->
            "manage-users"


{-| The role whose permissions a role has unless it says otherwise.
-}
parent : Role -> Maybe Role
parent role =
    case role of
        Dispatcher ->
            Just Picker

        Supervisor ->
            Just Dispatcher

        _ ->
            Nothing


{-| What was said directly about a role and a permission. Everything else is inherited.
-}
type alias Decisions =
    Dict ( String, String ) Bool


{-| What a role may do: what was said for it, or else what its parent may.
-}
effective : Decisions -> Role -> Permission -> Bool
effective decisions role permission =
    if role == Administrator then
        True

    else
        case Dict.get ( roleKey role, permissionKey permission ) decisions of
            Just own ->
                own

            Nothing ->
                case parent role of
                    Just above ->
                        effective decisions above permission

                    Nothing ->
                        False


{-| Both what was said for the role and what it would inherit: the matrix decides what to
show, how to toggle and when a cell can go back to inheriting.
-}
cellOf : Decisions -> Role -> Permission -> PermissionMatrix.Cell
cellOf decisions role permission =
    if role == Administrator then
        PermissionMatrix.direct PermissionMatrix.granted

    else
        PermissionMatrix.cell
            { own = Dict.get ( roleKey role, permissionKey permission ) decisions |> Maybe.map PermissionMatrix.fromBool
            , inherited =
                parent role
                    |> Maybe.map
                        (\above ->
                            { access = PermissionMatrix.fromBool (effective decisions above permission)
                            , from = Just (roleName above)
                            }
                        )
            }


{-| A change is what a role should have of its own: an access to store, or nothing, which
removes the decision and lets the cell inherit again. No inheritance logic is needed here.
-}
applyChange : PermissionMatrix.Change Role Permission -> Decisions -> Decisions
applyChange change decisions =
    let
        key =
            ( roleKey (PermissionMatrix.changedRole change), permissionKey (PermissionMatrix.changedPermission change) )
    in
    case PermissionMatrix.newAccess change of
        Just access ->
            Dict.insert key (PermissionMatrix.isGranted access) decisions

        Nothing ->
            Dict.remove key decisions


initialDecisions : Decisions
initialDecisions =
    [ ( Picker, ViewOrders, True )
    , ( Picker, ViewStock, True )
    , ( Dispatcher, EditOrders, True )
    , ( Dispatcher, CancelOrders, True )
    , ( Supervisor, AdjustStock, True )
    , ( Supervisor, ExportReports, True )
    , ( Supervisor, CancelOrders, False )
    ]
        |> List.map (\( role, permission, own ) -> ( ( roleKey role, permissionKey permission ), own ))
        |> Dict.fromList


theMatrix : Decisions -> PermissionMatrix.Matrix Role Permission
theMatrix decisions =
    PermissionMatrix.matrix
        { roles =
            [ PermissionMatrix.role Picker "Picker"
            , PermissionMatrix.role Dispatcher "Dispatcher"
            , PermissionMatrix.role Supervisor "Supervisor"
            , PermissionMatrix.role Administrator "Administrator"
                |> PermissionMatrix.locked "Administrator always has every permission"
            ]
        , roleKey = roleKey
        , permissions =
            [ PermissionMatrix.permission ViewOrders "View orders" |> PermissionMatrix.inGroup "Orders"
            , PermissionMatrix.permission EditOrders "Edit orders" |> PermissionMatrix.inGroup "Orders"
            , PermissionMatrix.permission CancelOrders "Cancel orders" |> PermissionMatrix.inGroup "Orders"
            , PermissionMatrix.permission ViewStock "View stock" |> PermissionMatrix.inGroup "Stock"
            , PermissionMatrix.permission AdjustStock "Adjust stock" |> PermissionMatrix.inGroup "Stock"
            , PermissionMatrix.permission ExportReports "Export reports" |> PermissionMatrix.inGroup "Reports"
            , PermissionMatrix.permission ManageUsers "Manage users"
            ]
        , permissionKey = permissionKey
        , cell = cellOf decisions
        }


{-| 200 permissions in 12 groups and 25 roles, to see that it stays quick.
-}
bigMatrix : Set ( Int, Int ) -> PermissionMatrix.Matrix Int Int
bigMatrix given =
    PermissionMatrix.matrix
        { roles =
            List.range 1 25
                |> List.map (\i -> PermissionMatrix.role i ("Role " ++ String.fromInt i))
        , roleKey = String.fromInt
        , permissions =
            List.range 1 200
                |> List.map
                    (\i ->
                        PermissionMatrix.permission i ("Permission " ++ String.fromInt i)
                            |> PermissionMatrix.inGroup ("Module " ++ String.fromInt (1 + (i - 1) // 17))
                    )
        , permissionKey = String.fromInt
        , cell =
            \r p -> PermissionMatrix.direct (PermissionMatrix.fromBool (Set.member ( r, p ) given))
        }


initialBig : Set ( Int, Int )
initialBig =
    List.range 1 25
        |> List.concatMap (\r -> List.range 1 200 |> List.filter (\p -> modBy 5 (r * 3 + p) == 0) |> List.map (\p -> ( r, p )))
        |> Set.fromList



-- APPROVERS


type User
    = Ada
    | Grace
    | Alan
    | Edsger
    | Barbara


userKey : User -> String
userKey user =
    case user of
        Ada ->
            "ada"

        Grace ->
            "grace"

        Alan ->
            "alan"

        Edsger ->
            "edsger"

        Barbara ->
            "barbara"


userName : User -> String
userName user =
    case user of
        Ada ->
            "Ada Lovelace"

        Grace ->
            "Grace Hopper"

        Alan ->
            "Alan Turing"

        Edsger ->
            "Edsger Dijkstra"

        Barbara ->
            "Barbara Liskov"


personOf : User -> Avatar.Entry
personOf user =
    Avatar.entry (userName user)


type Verdict
    = Yes
    | No


type alias Verdicted =
    { verdict : Verdict
    , at : Time.Posix
    , comment : Maybe String
    }


daysBefore : Int -> Time.Posix -> Time.Posix
daysBefore days time =
    Time.millisToPosix (Time.posixToMillis time - days * 86400000)


daysAfter : Int -> Time.Posix -> Time.Posix
daysAfter days time =
    daysBefore (negate days) time


initialDecisionsOfUsers : Dict String Verdicted
initialDecisionsOfUsers =
    Dict.fromList
        [ ( userKey Ada, { verdict = Yes, at = daysBefore 2 Sample.now, comment = Just "Matches the return." } ) ]


decisionOf : Dict String Verdicted -> User -> ApprovalFlow.Decision
decisionOf decisions user =
    case Dict.get (userKey user) decisions of
        Nothing ->
            ApprovalFlow.pending

        Just decided ->
            case decided.verdict of
                Yes ->
                    ApprovalFlow.approved { at = Just decided.at, comment = decided.comment }

                No ->
                    ApprovalFlow.rejected { at = Just decided.at, comment = decided.comment }


who : Dict String Verdicted -> User -> ApprovalFlow.Approver User
who decisions user =
    ApprovalFlow.approver user (decisionOf decisions user)


{-| The credit note: the team lead, then finance (either of two), then the director.
-}
creditNote : Dict String Verdicted -> ApprovalFlow.Flow User
creditNote decisions =
    ApprovalFlow.flow
        [ ApprovalFlow.step "Team lead" ApprovalFlow.all (who decisions Ada) []
        , ApprovalFlow.step "Finance"
            ApprovalFlow.any
            (who decisions Grace)
            [ who decisions Alan ]
            |> ApprovalFlow.withDue (daysAfter 2 Sample.now)
        , ApprovalFlow.step "Director" ApprovalFlow.all (who decisions Edsger) []
        ]


{-| A purchase request, to show the other statuses: finance is late.
-}
lateRequest : ApprovalFlow.Flow User
lateRequest =
    ApprovalFlow.flow
        [ ApprovalFlow.step "Team lead"
            ApprovalFlow.all
            (ApprovalFlow.approver Ada (ApprovalFlow.approved { at = Just (daysBefore 6 Sample.now), comment = Nothing }))
            []
        , ApprovalFlow.step "Finance"
            ApprovalFlow.all
            (ApprovalFlow.approver Grace (ApprovalFlow.approved { at = Just (daysBefore 5 Sample.now), comment = Nothing }))
            [ ApprovalFlow.approver Alan ApprovalFlow.pending ]
            |> ApprovalFlow.withDue (daysBefore 1 Sample.now)
        , ApprovalFlow.step "Director" ApprovalFlow.all (ApprovalFlow.approver Edsger ApprovalFlow.pending) []
        ]


rejectedRequest : ApprovalFlow.Flow User
rejectedRequest =
    ApprovalFlow.flow
        [ ApprovalFlow.step "Team lead"
            ApprovalFlow.all
            (ApprovalFlow.approver Ada (ApprovalFlow.approved { at = Just (daysBefore 4 Sample.now), comment = Nothing }))
            []
        , ApprovalFlow.step "Finance"
            ApprovalFlow.all
            (ApprovalFlow.approver Grace (ApprovalFlow.rejected { at = Just (daysBefore 3 Sample.now), comment = Just "The amount does not match the invoice." }))
            [ ApprovalFlow.approver Alan ApprovalFlow.pending ]
        , ApprovalFlow.step "Director" ApprovalFlow.all (ApprovalFlow.approver Edsger ApprovalFlow.pending) []
        ]


approvedRequest : ApprovalFlow.Flow User
approvedRequest =
    ApprovalFlow.flow
        [ ApprovalFlow.step "Team lead"
            ApprovalFlow.all
            (ApprovalFlow.approver Ada (ApprovalFlow.approved { at = Just (daysBefore 4 Sample.now), comment = Nothing }))
            []
        , ApprovalFlow.step "Finance"
            ApprovalFlow.any
            (ApprovalFlow.approver Grace ApprovalFlow.pending)
            [ ApprovalFlow.approver Alan (ApprovalFlow.approved { at = Just (daysBefore 3 Sample.now), comment = Just "Within budget." }) ]
        ]



-- MODEL


type alias Model =
    { matrix : PermissionMatrix.State
    , decisions : Decisions
    , saved : Decisions
    , outcome : Maybe String
    , readOnly : PermissionMatrix.State
    , loading : PermissionMatrix.State
    , failing : PermissionMatrix.State
    , retries : Int
    , big : PermissionMatrix.State
    , bigGrants : Set ( Int, Int )
    , viewer : Maybe User
    , users : Dict String Verdicted
    , rejecting : Bool
    , reason : String
    }


type Msg
    = MatrixMsg PermissionMatrix.Msg
    | CellsChanged (List (PermissionMatrix.Change Role Permission))
    | Save
    | Discard
    | ReadOnlyMsg PermissionMatrix.Msg
    | LoadingMsg PermissionMatrix.Msg
    | FailingMsg PermissionMatrix.Msg
    | Retried
    | BigMsg PermissionMatrix.Msg
    | BigChanged (List (PermissionMatrix.Change Int Int))
    | ViewerPicked (Maybe User)
    | ApproveClicked
    | RejectClicked
    | ReasonTyped String
    | RejectConfirmed
    | RejectCancelled
    | Decided Verdict (Maybe String) Time.Posix
    | FlowFocused
    | FlowReset


init : ( Model, Cmd Msg )
init =
    ( { matrix = PermissionMatrix.init "access-matrix"
      , decisions = initialDecisions
      , saved = initialDecisions
      , outcome = Nothing
      , readOnly = PermissionMatrix.init "access-read-only"
      , loading = PermissionMatrix.init "access-loading"
      , failing = PermissionMatrix.init "access-failing"
      , retries = 0
      , big = PermissionMatrix.init "access-big"
      , bigGrants = initialBig
      , viewer = Just Grace
      , users = initialDecisionsOfUsers
      , rejecting = False
      , reason = ""
      }
    , Cmd.none
    )



-- UPDATE


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        MatrixMsg inner ->
            let
                ( matrix, cmd ) =
                    PermissionMatrix.update inner model.matrix
            in
            ( { model | matrix = matrix }, Cmd.map MatrixMsg cmd )

        CellsChanged changes ->
            ( { model
                | decisions = List.foldl applyChange model.decisions changes
                , outcome = Nothing
              }
            , Cmd.none
            )

        Save ->
            ( { model | saved = model.decisions, outcome = Just "Saved (nothing leaves this demo)." }, Cmd.none )

        Discard ->
            ( { model | decisions = model.saved, outcome = Just "Changes discarded." }, Cmd.none )

        ReadOnlyMsg inner ->
            let
                ( state, cmd ) =
                    PermissionMatrix.update inner model.readOnly
            in
            ( { model | readOnly = state }, Cmd.map ReadOnlyMsg cmd )

        LoadingMsg inner ->
            let
                ( state, cmd ) =
                    PermissionMatrix.update inner model.loading
            in
            ( { model | loading = state }, Cmd.map LoadingMsg cmd )

        FailingMsg inner ->
            let
                ( state, cmd ) =
                    PermissionMatrix.update inner model.failing
            in
            ( { model | failing = state }, Cmd.map FailingMsg cmd )

        Retried ->
            ( { model | retries = model.retries + 1 }, Cmd.none )

        BigMsg inner ->
            let
                ( state, cmd ) =
                    PermissionMatrix.update inner model.big
            in
            ( { model | big = state }, Cmd.map BigMsg cmd )

        BigChanged changes ->
            ( { model
                | bigGrants =
                    List.foldl
                        (\change grants ->
                            case Maybe.map PermissionMatrix.isGranted (PermissionMatrix.newAccess change) of
                                Just True ->
                                    Set.insert ( PermissionMatrix.changedRole change, PermissionMatrix.changedPermission change ) grants

                                _ ->
                                    Set.remove ( PermissionMatrix.changedRole change, PermissionMatrix.changedPermission change ) grants
                        )
                        model.bigGrants
                        changes
              }
            , Cmd.none
            )

        ViewerPicked user ->
            ( { model | viewer = user, rejecting = False }, Cmd.none )

        ApproveClicked ->
            ( model, Task.perform (Decided Yes Nothing) Time.now )

        RejectClicked ->
            ( { model | rejecting = True, reason = "" }, Cmd.none )

        ReasonTyped text ->
            ( { model | reason = text }, Cmd.none )

        RejectConfirmed ->
            ( { model | rejecting = False }, Task.perform (Decided No (Just (String.trim model.reason))) Time.now )

        RejectCancelled ->
            ( { model | rejecting = False }, Cmd.none )

        Decided verdict comment time ->
            case model.viewer of
                Just user ->
                    ( { model | users = Dict.insert (userKey user) { verdict = verdict, at = time, comment = comment } model.users }
                      -- the buttons that had focus leave with the decision
                    , Klar.focus creditNoteId FlowFocused
                    )

                Nothing ->
                    ( model, Cmd.none )

        FlowFocused ->
            ( model, Cmd.none )

        FlowReset ->
            ( { model | users = initialDecisionsOfUsers, rejecting = False, reason = "" }, Cmd.none )


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none



-- VIEW


view : Settings -> Locale -> Model -> Html Msg
view settings locale model =
    Doc.page
        { title = "Roles and approvals"
        , description = "A permission matrix for roles and an approval flow with approvers and status. The status of a flow is derived from the decisions, so what is drawn can never contradict them. The language switch in the top bar changes the built-in texts."
        }
        [ matrixSection locale model
        , approvalSection settings locale model
        ]


labelled : String -> Html msg -> Html msg
labelled name content =
    Html.div [ Attr.style "min-width" "0" ]
        [ Html.div [ Attr.style "margin-bottom" "var(--klar-space-1)" ] [ Text.mono name ]
        , content
        ]



-- MATRIX


matrixSection : Locale -> Model -> Html Msg
matrixSection locale model =
    let
        changed =
            model.decisions /= model.saved
    in
    Doc.section "Permission matrix"
        "Roles are the columns and permissions the rows, in groups. A cell is granted, denied or inherited from another role. The values are the application's: it holds them, the matrix reports a click, a key press or a header checkbox as one message with a list of changes, and draws what the application gives back."
        [ Doc.example
            { title = "Roles that inherit, with Save and Discard"
            , description =
                Just "A dispatcher has what a picker has, and a supervisor what a dispatcher has, unless a cell says otherwise (dashed boxes with the source). Toggling an inherited cell overrides it (a small mark in its corner); toggling it back to what the parent says, the mark that appears under the pointer, or Delete or Backspace lets it inherit again, and the application only stores or removes what the change says. The administrator column is locked, with the reason under the grid. Cells that differ from the last save have a dot; the count and your buttons are above. Arrow keys, Home, End, Ctrl+Home, Ctrl+End, Page Up and Page Down move; Space or Enter toggles; the checkbox of a role or a permission grants or denies the whole line; Enter on a group row folds it."
            , code = Just matrixCode
            }
            (Layout.stack [ Layout.gap 2 ]
                [ PermissionMatrix.view MatrixMsg
                    [ PermissionMatrix.onChange CellsChanged
                    , PermissionMatrix.saved (cellOf model.saved)
                    , PermissionMatrix.locale locale
                    , PermissionMatrix.ariaLabel "Permissions of the roles"
                    , PermissionMatrix.toolbarActions
                        [ Button.view [ Button.disabled (not changed), Button.onClick Discard ] "Discard"
                        , Button.view [ Button.primary, Button.disabled (not changed), Button.onClick Save ] "Save"
                        ]
                    ]
                    model.matrix
                    (theMatrix model.decisions)
                , Text.caption (Maybe.withDefault "Toggle some cells, then save or discard." model.outcome)
                ]
            )
        , Doc.example
            { title = "Read-only and compact"
            , description = Just "Without onChange the cells show their state as an icon and a word and nothing can be changed, but the grid can still be moved through with the keys and the groups folded. The density is the one of the table."
            , code = Just readOnlyCode
            }
            (PermissionMatrix.view ReadOnlyMsg
                [ PermissionMatrix.density Theme.Compact
                , PermissionMatrix.locale locale
                , PermissionMatrix.maxHeight 320
                ]
                model.readOnly
                (theMatrix model.saved)
            )
        , Doc.example
            { title = "Loading and failing"
            , description = Just "A skeleton in the shape of a grid, and the problem with a Try again button when it is worth trying again."
            , code = Just remoteCode
            }
            (Layout.grid [ Layout.minColumn 360, Layout.gap 4 ]
                [ labelled "Loading"
                    (PermissionMatrix.viewRemote LoadingMsg [ PermissionMatrix.locale locale ] model.loading Remote.Loading)
                , labelled ("Failure, tried again " ++ String.fromInt model.retries ++ " times")
                    (PermissionMatrix.viewRemote FailingMsg
                        [ PermissionMatrix.locale locale, PermissionMatrix.onRetry Retried ]
                        model.failing
                        (Remote.Failed (Remote.problem Remote.network))
                    )
                ]
            )
        , Doc.example
            { title = "200 permissions by 25 roles"
            , description = Just "5 000 cells and 12 groups. Events are caught once on the grid, so no cell has a handler of its own. Filter, fold a group, or press the checkbox of a role: it acts on every permission that matches the filter, folded groups included."
            , code = Nothing
            }
            (PermissionMatrix.view BigMsg
                [ PermissionMatrix.onChange BigChanged
                , PermissionMatrix.density Theme.Compact
                , PermissionMatrix.locale locale
                , PermissionMatrix.maxHeight 420
                ]
                model.big
                (bigMatrix model.bigGrants)
            )
        ]



-- APPROVAL FLOW


viewerButton : Model -> Maybe User -> Html Msg
viewerButton model choice =
    Button.view
        [ Button.small
        , Button.pressed (model.viewer == choice)
        , Button.onClick (ViewerPicked choice)
        ]
        (case choice of
            Just user ->
                userName user

            Nothing ->
                "Not signed in"
        )


flowAttributes : Settings -> Locale -> Model -> List (ApprovalFlow.Attribute User Msg)
flowAttributes settings locale model =
    [ ApprovalFlow.viewer model.viewer
    , ApprovalFlow.onApprove ApproveClicked
    , ApprovalFlow.onReject RejectClicked
    , ApprovalFlow.now Sample.now
    , ApprovalFlow.settings settings
    , ApprovalFlow.locale locale
    , ApprovalFlow.ariaLabel "Approval of credit note 2024-117"
    , ApprovalFlow.id creditNoteId
    ]


creditNoteId : String
creditNoteId =
    "credit-note-flow"


staticAttributes : Settings -> Locale -> List (ApprovalFlow.Attribute User Msg)
staticAttributes settings locale =
    [ ApprovalFlow.now Sample.now
    , ApprovalFlow.settings settings
    , ApprovalFlow.locale locale
    ]


approvalSection : Settings -> Locale -> Model -> Html Msg
approvalSection settings locale model =
    Doc.section "Approval flow"
        "The steps of an approval, each with the rule for its approvers (all of them, or any one) and a decision from each. Where each step stands, and the flow, is worked out from the decisions: an approval in an any step wins over rejections, a rejection in an all step wins over approvals, and a rejection leaves the later steps not reached. Pick who you are, and decide."
        [ Doc.example
            { title = "Credit note 2024-117"
            , description = Just "Choose a viewer. A pending approver of the current step gets Approve and Reject; the flow, the line above it and the second layout below change at once. Reject asks for a reason in a form of the application's own, and the reason is shown under the name. The line above the steps is a polite live region."
            , code = Just flowCode
            }
            (Layout.stack [ Layout.gap 3 ]
                [ Layout.row [ Layout.gap 2, Layout.wrap, Layout.alignCenter ]
                    (Text.caption "You are:"
                        :: List.map (viewerButton model) [ Just Ada, Just Grace, Just Alan, Just Edsger, Just Barbara, Nothing ]
                        ++ [ Button.view [ Button.small, Button.ghost, Button.onClick FlowReset ] "Start again" ]
                    )
                , if model.rejecting then
                    rejectForm model

                  else
                    Html.text ""
                , ApprovalFlow.view personOf (flowAttributes settings locale model) (creditNote model.users)
                ]
            )
        , Doc.example
            { title = "The same flow, side by side"
            , description = Just "The horizontal layout for a wide, short strip. It is the same value, so deciding above changes it too. A row with many steps scrolls sideways."
            , code = Just "ApprovalFlow.view personOf [ ApprovalFlow.horizontal ] flow"
            }
            (ApprovalFlow.view personOf
                (ApprovalFlow.horizontal :: staticAttributes settings locale)
                (creditNote model.users)
            )
        , Doc.example
            { title = "Every status"
            , description = Just "A finance step that is overdue, a rejection after which the director is not reached, a flow in which an any step was approved by the second person, and a flow without steps. Each status is an icon and words, never only a color."
            , code = Just statusCode
            }
            (Layout.grid [ Layout.minColumn 340, Layout.gap 4 ]
                [ labelled "Overdue" (ApprovalFlow.view personOf (ApprovalFlow.ariaLabel "Purchase request, overdue" :: staticAttributes settings locale) lateRequest)
                , labelled "Rejected" (ApprovalFlow.view personOf (ApprovalFlow.ariaLabel "Purchase request, rejected" :: staticAttributes settings locale) rejectedRequest)
                , labelled "Approved" (ApprovalFlow.view personOf (ApprovalFlow.ariaLabel "Purchase request, approved" :: staticAttributes settings locale) approvedRequest)
                , labelled "No approval required" (ApprovalFlow.view personOf (ApprovalFlow.locale locale :: []) (ApprovalFlow.flow []))
                ]
            )
        , Doc.example
            { title = "Loading and failing"
            , description = Just "A skeleton of steps, and the problem with Try again."
            , code = Just "ApprovalFlow.viewRemote personOf [ ApprovalFlow.onRetry Reload ] model.approval"
            }
            (Layout.grid [ Layout.minColumn 340, Layout.gap 4 ]
                [ labelled "Loading" (ApprovalFlow.viewRemote personOf (staticAttributes settings locale) Remote.Loading)
                , labelled "Failure"
                    (ApprovalFlow.viewRemote personOf
                        (ApprovalFlow.onRetry Retried :: staticAttributes settings locale)
                        (Remote.Failed (Remote.problem Remote.timeout))
                    )
                ]
            )
        ]


rejectForm : Model -> Html Msg
rejectForm model =
    Layout.stack [ Layout.gap 2 ]
        [ TextArea.view
            [ TextArea.label "Reason for the rejection"
            , TextArea.id "access-reject-reason"
            , TextArea.required
            , TextArea.rows 2
            , TextArea.value model.reason
            , TextArea.onInput ReasonTyped
            ]
        , Layout.row [ Layout.gap 2 ]
            [ Button.view
                [ Button.danger
                , Button.disabled (String.isEmpty (String.trim model.reason))
                , Button.onClick RejectConfirmed
                ]
                "Reject"
            , Button.view [ Button.onClick RejectCancelled ] "Cancel"
            ]
        ]



-- CODE


matrixCode : String
matrixCode =
    """-- model: access : PermissionMatrix.State   (PermissionMatrix.init "role-matrix")
--        decisions, saved : what the application stores

PermissionMatrix.view MatrixMsg
    [ PermissionMatrix.onChange CellsChanged          -- without it: read-only
    , PermissionMatrix.saved (cellOf model.saved)     -- marks what differs
    , PermissionMatrix.toolbarActions [ discardButton, saveButton ]
    ]
    model.access
    (PermissionMatrix.matrix
        { roles =
            [ PermissionMatrix.role Picker "Picker"
            , PermissionMatrix.role Administrator "Administrator"
                |> PermissionMatrix.locked "Administrator always has every permission"
            ]
        , roleKey = Role.toString
        , permissions =
            [ PermissionMatrix.permission ViewOrders "View orders"
                |> PermissionMatrix.inGroup "Orders"
            ]
        , permissionKey = Permission.toString
        , cell = cellOf model.decisions
        }
    )

cellOf decisions role permission =
    PermissionMatrix.cell
        { own = Dict.get ( role, permission ) decisions |> Maybe.map PermissionMatrix.fromBool
        , inherited =
            parentOf role
                |> Maybe.map (inheritedFrom permission)   -- { access = ..., from = Just "Picker" }
        }

CellsChanged changes ->      -- one click or key, a list of one; a header checkbox, many
    ( { model | decisions = List.foldl store model.decisions changes }, Cmd.none )

store change decisions =
    case PermissionMatrix.newAccess change of
        Just access -> Dict.insert (key change) (PermissionMatrix.isGranted access) decisions
        Nothing -> Dict.remove (key change) decisions   -- inherits again"""


readOnlyCode : String
readOnlyCode =
    """PermissionMatrix.view ReadOnlyMsg
    [ PermissionMatrix.density Compact, PermissionMatrix.maxHeight 320 ]
    model.readOnly
    (toMatrix model.saved)"""


remoteCode : String
remoteCode =
    """PermissionMatrix.viewRemote MatrixMsg
    [ PermissionMatrix.onChange CellsChanged, PermissionMatrix.onRetry Reload ]
    model.access
    (Remote.map toMatrix model.grants)"""


flowCode : String
flowCode =
    """ApprovalFlow.view personOf
    [ ApprovalFlow.viewer (Just model.me)
    , ApprovalFlow.onApprove Approve
    , ApprovalFlow.onReject AskWhy        -- your own dialog; send the reason with the decision
    , ApprovalFlow.now model.now
    , ApprovalFlow.settings settings
    , ApprovalFlow.id "credit-note-flow"
    ]
    (ApprovalFlow.flow
        [ ApprovalFlow.step "Team lead" ApprovalFlow.all (approver ada) []
        , ApprovalFlow.step "Finance" ApprovalFlow.any (approver grace) [ approver alan ]
            |> ApprovalFlow.withDue deadline
        , ApprovalFlow.step "Director" ApprovalFlow.all (approver edsger) []
        ]
    )

-- the same answers, for a list or for the server
ApprovalFlow.isApproved (ApprovalFlow.status flow)   -- ask it, never match it
ApprovalFlow.currentStep flow                        -- Just 1
ApprovalFlow.pendingApprovers flow

-- the buttons leave with the decision, so give the focus to the flow in the same update
Decided ->
    ( { model | flow = record model.me model.flow }
    , Klar.focus "credit-note-flow" NoOp
    )"""


statusCode : String
statusCode =
    """List.map ApprovalFlow.stepIsSkipped (ApprovalFlow.stepStatuses flow)
--> [ False, False, True ]     -- a skipped step is shown as "Not reached"

ApprovalFlow.approved { at = Just time, comment = Just "Within budget." }
ApprovalFlow.rejected { at = Just time, comment = Just "The amount is wrong." }
ApprovalFlow.pending"""
