module Examples.ReviewDesk exposing (Model, Msg, init, main, subscriptions, update, view)

{-| A complete review desk using five workbench components together. Approval
removes a case from the queue, adds an audit event and an unread notification.
The concurrent-edit example resolves fields before applying the merged values.
The state controls let reviewers inspect the same screen loading, failed, empty,
refreshing and stale. No CSS, class names, ports or JavaScript are needed.
-}

import Browser
import Html exposing (Html)
import Klar
import Klar.Alert as Alert
import Klar.AuditLog as AuditLog
import Klar.Badge as Badge
import Klar.Button as Button
import Klar.Card as Card
import Klar.CardList as CardList
import Klar.ConflictResolver as Conflict
import Klar.Diff as Diff
import Klar.Ids as Ids exposing (Ids)
import Klar.Layout as Layout
import Klar.Locale as Locale exposing (Locale)
import Klar.NotificationCenter as Notifications
import Klar.Remote as Remote exposing (Remote)
import Klar.Settings as Settings exposing (Settings)
import Klar.Text as Text
import Klar.Theme exposing (Tone(..))
import Klar.WorkQueue as WorkQueue
import Process
import Task
import Time


type CaseId
    = CaseId Int


caseIds : Ids CaseId
caseIds =
    Ids.make { toKey = \(CaseId id) -> String.fromInt id, fromKey = String.toInt >> Maybe.map CaseId }


type alias Case =
    { id : CaseId, number : String, customer : String, amount : String, reason : String }


type DataState
    = Ready
    | Waiting
    | Failed
    | Empty
    | Refreshing
    | Stale


type alias Notice =
    { id : Int, title : String, body : String, unread : Bool, at : Time.Posix }


type alias Model =
    { queue : WorkQueue.State
    , cases : List Case
    , selectedCards : List CaseId
    , audit : List (AuditLog.Entry Int)
    , notices : List Notice
    , unreadOnly : Bool
    , historyQuery : String
    , conflict : Conflict.State
    , fields : List (Conflict.Field String)
    , applied : Maybe (List ( String, Maybe String ))
    , state : DataState
    , nextId : Int
    , request : Int
    , now : Time.Posix
    , settings : Settings
    }


type Msg
    = QueueMsg WorkQueue.Msg
    | ConflictMsg Conflict.Msg
    | SelectCards (List CaseId)
    | OpenCase CaseId
    | Decide CaseId Bool
    | UnreadOnly Bool
    | ReadNotice Int
    | ReadAll (List Int)
    | DismissNotice Int
    | HistoryQuery String
    | Apply (List ( String, Maybe String ))
    | ChangeState DataState
    | Retry String
    | Refresh
    | Refreshed Int
    | Reset
    | Zone Time.Zone
    | Now Time.Posix
    | NoOp


initialFields : List (Conflict.Field String)
initialFields =
    [ Conflict.field "warehouse" "Warehouse" { base = Just "Bergen", yours = Just "Oslo", theirs = Just "Trondheim" }
    , Conflict.field "reference" "Customer reference" { base = Nothing, yours = Just "PO-2026-1042", theirs = Nothing }
    , Conflict.field "note" "Dispatch note" { base = Just "Standard delivery", yours = Just "Call before arrival", theirs = Just "Leave at reception" }
    ]


init : ( Model, Cmd Msg )
init =
    ( { queue = WorkQueue.init "review-queue"
      , cases =
            [ { id = CaseId 1042, number = "ORD-1042", customer = "Northline Tools", amount = "12 450 NOK", reason = "Delivery address changed after the order was confirmed." }
            , { id = CaseId 1043, number = "ORD-1043", customer = "Fjord Supply", amount = "8 200 NOK", reason = "Discount exceeds the account's agreed threshold." }
            , { id = CaseId 1044, number = "ORD-1044", customer = "Harbour Workshop", amount = "36 900 NOK", reason = "New customer requesting payment by invoice." }
            ]
      , selectedCards = []
      , audit = [ AuditLog.entry { id = 0, actor = "System", action = "Review desk opened", at = Time.millisToPosix 1792886400000 } |> AuditLog.withDetail "Three orders need a human decision. Open an order, then approve or reject it to see the history and notifications update." ]
      , notices = [ { id = 0, title = "Review required", body = "Three orders are waiting for your decision.", at = Time.millisToPosix 1792886400000, unread = True } ]
      , unreadOnly = False
      , historyQuery = ""
      , conflict = Conflict.init "order-conflict"
      , fields = initialFields
      , applied = Nothing
      , state = Ready
      , nextId = 1
      , request = 0
      , now = Time.millisToPosix 1792886400000
      , settings = Settings.default
      }
    , Cmd.batch [ Task.perform Zone Time.here, Task.perform Now Time.now ]
    )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        QueueMsg inner ->
            let
                ( queue, cmd ) =
                    WorkQueue.update inner model.queue
            in
            ( { model | queue = queue }, Cmd.map QueueMsg cmd )

        ConflictMsg inner ->
            let
                ( conflict, cmd ) =
                    Conflict.update inner model.conflict
            in
            ( { model | conflict = conflict, applied = Nothing }, Cmd.map ConflictMsg cmd )

        SelectCards ids ->
            ( { model | selectedCards = ids }, Cmd.none )

        OpenCase id ->
            ( { model | queue = WorkQueue.setSelected caseIds (Just id) model.queue }, Klar.focus "review-queue" NoOp )

        Decide id approved ->
            case List.filter (\item -> item.id == id) model.cases |> List.head of
                Nothing ->
                    ( model, Cmd.none )

                Just item ->
                    let
                        action =
                            if approved then
                                "Approved"

                            else
                                "Rejected"

                        event =
                            AuditLog.entry { id = model.nextId, actor = "You", action = action ++ " " ++ item.number, at = model.now }
                                |> AuditLog.withDetail item.reason
                                |> AuditLog.withDiff (Diff.fields [ { label = "Review status", before = Just "Pending", after = Just action } ])
                    in
                    ( { model
                        | cases = List.filter (\one -> one.id /= id) model.cases
                        , selectedCards = List.filter ((/=) id) model.selectedCards
                        , queue = WorkQueue.setSelected caseIds Nothing model.queue
                        , audit = event :: model.audit
                        , notices = { id = model.nextId, title = action ++ " " ++ item.number, body = item.customer ++ " · " ++ item.amount, unread = True, at = model.now } :: model.notices
                        , nextId = model.nextId + 1
                      }
                    , Klar.focus "review-queue" NoOp
                    )

        UnreadOnly value ->
            ( { model | unreadOnly = value }, Cmd.none )

        ReadNotice id ->
            ( { model
                | notices =
                    List.map
                        (\notice ->
                            if notice.id == id then
                                { notice | unread = False }

                            else
                                notice
                        )
                        model.notices
              }
            , Klar.focus "review-notifications" NoOp
            )

        ReadAll ids ->
            ( { model
                | notices =
                    List.map
                        (\notice ->
                            if List.member notice.id ids then
                                { notice | unread = False }

                            else
                                notice
                        )
                        model.notices
              }
            , Klar.focus "review-notifications" NoOp
            )

        DismissNotice id ->
            ( { model | notices = List.filter (\notice -> notice.id /= id) model.notices }, Klar.focus "review-notifications" NoOp )

        HistoryQuery text ->
            ( { model | historyQuery = text }, Cmd.none )

        Apply merged ->
            ( { model | applied = Just merged }, Cmd.none )

        ChangeState state ->
            ( { model | state = state, request = model.request + 1 }, Cmd.none )

        Retry domId ->
            ( { model | state = Ready, request = model.request + 1 }, Klar.focus domId NoOp )

        Refresh ->
            ( { model | state = Refreshing, request = model.request + 1 }
            , Process.sleep 2500 |> Task.perform (always (Refreshed (model.request + 1)))
            )

        Refreshed request ->
            if request == model.request then
                ( { model | state = Ready }, Cmd.none )

            else
                ( model, Cmd.none )

        Reset ->
            init

        Zone zone ->
            ( { model | settings = Settings.withZone zone model.settings }, Cmd.none )

        Now now ->
            ( { model | now = now }, Cmd.none )

        NoOp ->
            ( model, Cmd.none )


remote : Model -> List a -> Remote (List a)
remote model items =
    case model.state of
        Ready ->
            Remote.Loaded items

        Waiting ->
            Remote.Loading

        Failed ->
            Remote.Failed (Remote.problem Remote.network)

        Empty ->
            Remote.Loaded []

        Refreshing ->
            Remote.refresh (Remote.Loaded items)

        Stale ->
            Remote.refreshWith (Remote.Loaded items) (Err (Remote.problem Remote.network)) model.now


view : Locale -> Model -> Html Msg
view locale model =
    let
        panel title body =
            Card.view [ Card.title title, Card.headingLevel 2 ] [ body ]

        detail item =
            Layout.stack [ Layout.gap 4 ]
                [ Layout.row [ Layout.justifyBetween, Layout.wrap ] [ Text.heading item.number, Badge.view [ Badge.tone Warning ] "Needs review" ]
                , Text.strong item.customer
                , Text.figure item.amount
                , Text.paragraph item.reason
                , Text.secondary "Demo: a decision updates this local work desk."
                , Layout.row [ Layout.gap 2, Layout.wrap ]
                    [ Button.view [ Button.primary, Button.disabled (model.state /= Ready), Button.onClick (Decide item.id True) ] "Approve order"
                    , Button.view [ Button.danger, Button.disabled (model.state /= Ready), Button.onClick (Decide item.id False) ] "Reject order"
                    ]
                ]
    in
    Layout.stack [ Layout.gap 6 ]
        [ Layout.row [ Layout.gap 2, Layout.wrap ]
            (List.map (\( label, state ) -> Button.view [ Button.small, Button.pressed (model.state == state), Button.onClick (ChangeState state) ] label)
                [ ( "Data", Ready ), ( "Loading", Waiting ), ( "Failure", Failed ), ( "Empty", Empty ), ( "Refreshing", Refreshing ), ( "Old data", Stale ) ]
                ++ [ Button.view [ Button.small, Button.onClick Refresh ] "Refresh while typing"
                   , Button.view [ Button.small, Button.onClick Reset ] "Reset demo"
                   ]
            )
        , panel "Work queue"
            (WorkQueue.view QueueMsg
                [ WorkQueue.searchable, WorkQueue.locale locale, WorkQueue.settings model.settings, WorkQueue.onRetry (Retry "review-queue") ]
                { label = "Orders awaiting review", items = remote model model.cases, ids = caseIds, id = .id, title = .number, summary = .customer, detail = detail }
                model.queue
            )
        , panel "The same records as cards"
            (CardList.view [ CardList.id "review-cards", CardList.selection model.selectedCards SelectCards, CardList.onOpen OpenCase, CardList.locale locale, CardList.settings model.settings, CardList.onRetry (Retry "review-cards") ]
                { label = "Order cards"
                , items = remote model model.cases
                , ids = caseIds
                , id = .id
                , title = .number
                , fields = [ CardList.field "Customer" (Text.text << .customer), CardList.field "Amount" (Text.mono << .amount), CardList.field "Reason" (Text.text << .reason) ]
                }
            )
        , panel "Concurrent edits: review before applying"
            (Layout.stack [ Layout.gap 3 ]
                [ Text.paragraph "Two people edited the same order. A customer reference added on only one side is kept automatically; warehouse and dispatch note need your decision."
                , Conflict.view ConflictMsg
                    [ Conflict.onApply Apply, Conflict.locale locale, Conflict.settings model.settings, Conflict.onRetry (Retry "order-conflict") ]
                    { label = "Order field conflicts", ids = Ids.string, fields = remote model model.fields }
                    model.conflict
                , case model.applied of
                    Just merged ->
                        Alert.view [ Alert.tone Success, Alert.polite ] ("Resolved values: " ++ String.join " · " (List.map (\( label, value ) -> label ++ " = " ++ Maybe.withDefault "(absent)" value) merged))

                    Nothing ->
                        Html.text ""
                ]
            )
        , panel "Audit log"
            (AuditLog.view [ AuditLog.id "review-history", AuditLog.search model.historyQuery HistoryQuery, AuditLog.locale locale, AuditLog.settings model.settings, AuditLog.onRetry (Retry "review-history") ]
                { label = "Decision history", ids = Ids.int, entries = remote model model.audit }
            )
        , panel "Notification centre"
            (Notifications.view [ Notifications.id "review-notifications", Notifications.unreadOnly model.unreadOnly UnreadOnly, Notifications.onRead ReadNotice, Notifications.onReadAll ReadAll, Notifications.onDismiss DismissNotice, Notifications.locale locale, Notifications.settings model.settings, Notifications.onRetry (Retry "review-notifications") ]
                { label = "Review notifications", ids = Ids.int, items = remote model (List.map Notifications.notification model.notices) }
            )
        ]


subscriptions : Model -> Sub Msg
subscriptions _ =
    Time.every 1000 Now


main : Program () Model Msg
main =
    Browser.document
        { init = always init
        , update = update
        , subscriptions = subscriptions
        , view = \model -> { title = "Review desk — Klar", body = [ Klar.stylesheet, Layout.container [ Layout.maxWidth 1200, Layout.padding 6 ] [ Text.title "Order review desk", Text.paragraph "Five workbench components, one connected workflow. Keyboard: Tab into the queue, then j/k or arrow keys; Tab again for the decision controls.", view Locale.en model ] ] }
        }
