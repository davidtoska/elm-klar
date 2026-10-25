module Page.Gallery.Workbench.Demo exposing (Model, Msg, init, subscriptions, update, view)

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
import Showcase.Config as Config
import Showcase.Options as Options
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


view : Config.Config -> Locale -> Model -> Html Msg
view playground locale model =
    let
        panel title body =
            Config.only playground
                [ case title of
                    "Work queue" ->
                        "WorkQueue"

                    "The same records as cards" ->
                        "CardList"

                    "Concurrent edits: review before applying" ->
                        "ConflictResolver"

                    "Audit log" ->
                        "AuditLog"

                    _ ->
                        "NotificationCenter"
                ]
                (Card.view (Options.klarCard playground (List.concat [ Config.keep playground "Card" "title" (Card.title title), Config.keep playground "Card" "headingLevel" (Card.headingLevel 2) ])) [ body ])

        detail item =
            Layout.stack (Options.klarLayout playground (List.concat [ Config.keep playground "Layout" "gap" (Layout.gap 4) ]))
                [ Layout.row (Options.klarLayout playground (List.concat [ Config.keep playground "Layout" "justifyBetween" Layout.justifyBetween, Config.keep playground "Layout" "wrap" Layout.wrap ])) [ Text.heading item.number, Options.badgeView playground (Options.klarBadge playground (List.concat [ Config.keep playground "Badge" "tone" (Badge.tone Warning) ])) "Needs review" ]
                , Text.strong item.customer
                , Text.figure item.amount
                , Text.paragraph item.reason
                , Text.secondary "Demo: a decision updates this local work desk."
                , Layout.row (Options.klarLayout playground (List.concat [ Config.keep playground "Layout" "gap" (Layout.gap 2), Config.keep playground "Layout" "wrap" Layout.wrap ]))
                    [ Options.buttonView playground (Options.klarButton playground (List.concat [ Config.keep playground "Button" "primary" Button.primary, Config.keep playground "Button" "disabled" (Button.disabled (model.state /= Ready)), Config.keep playground "Button" "onClick" (Button.onClick (Decide item.id True)) ])) "Approve order"
                    , Options.buttonView playground (Options.klarButton playground (List.concat [ Config.keep playground "Button" "danger" Button.danger, Config.keep playground "Button" "disabled" (Button.disabled (model.state /= Ready)), Config.keep playground "Button" "onClick" (Button.onClick (Decide item.id False)) ])) "Reject order"
                    ]
                ]
    in
    Layout.stack (Options.klarLayout playground (List.concat [ Config.keep playground "Layout" "gap" (Layout.gap 6) ]))
        [ Layout.row (Options.klarLayout playground (List.concat [ Config.keep playground "Layout" "gap" (Layout.gap 2), Config.keep playground "Layout" "wrap" Layout.wrap ]))
            (List.map (\( label, state ) -> Options.buttonView playground (Options.klarButton playground (List.concat [ Config.keep playground "Button" "small" Button.small, Config.keep playground "Button" "pressed" (Button.pressed (model.state == state)), Config.keep playground "Button" "onClick" (Button.onClick (ChangeState state)) ])) label)
                [ ( "Data", Ready ), ( "Loading", Waiting ), ( "Failure", Failed ), ( "Empty", Empty ), ( "Refreshing", Refreshing ), ( "Old data", Stale ) ]
                ++ [ Options.buttonView playground (Options.klarButton playground (List.concat [ Config.keep playground "Button" "small" Button.small, Config.keep playground "Button" "onClick" (Button.onClick Refresh) ])) "Refresh while typing"
                   , Options.buttonView playground (Options.klarButton playground (List.concat [ Config.keep playground "Button" "small" Button.small, Config.keep playground "Button" "onClick" (Button.onClick Reset) ])) "Reset demo"
                   ]
            )
        , panel "Work queue"
            (WorkQueue.view QueueMsg
                (Options.klarWorkQueue playground (List.concat [ Config.keep playground "WorkQueue" "searchable" WorkQueue.searchable, Config.keep playground "WorkQueue" "locale" (WorkQueue.locale locale), Config.keep playground "WorkQueue" "settings" (WorkQueue.settings model.settings), Config.keep playground "WorkQueue" "onRetry" (WorkQueue.onRetry (Retry "review-queue")) ]))
                { label = "Orders awaiting review", items = remote model model.cases, ids = caseIds, id = .id, title = .number, summary = .customer, detail = detail }
                model.queue
            )
        , panel "The same records as cards"
            (CardList.view (Options.klarCardList playground (List.concat [ Config.keep playground "CardList" "id" (CardList.id "review-cards"), Config.keep playground "CardList" "selection" (CardList.selection model.selectedCards SelectCards), Config.keep playground "CardList" "onOpen" (CardList.onOpen OpenCase), Config.keep playground "CardList" "locale" (CardList.locale locale), Config.keep playground "CardList" "settings" (CardList.settings model.settings), Config.keep playground "CardList" "onRetry" (CardList.onRetry (Retry "review-cards")) ]))
                { label = "Order cards"
                , items = remote model model.cases
                , ids = caseIds
                , id = .id
                , title = .number
                , fields = [ CardList.field "Customer" (Text.text << .customer), CardList.field "Amount" (Text.mono << .amount), CardList.field "Reason" (Text.text << .reason) ]
                }
            )
        , panel "Concurrent edits: review before applying"
            (Layout.stack (Options.klarLayout playground (List.concat [ Config.keep playground "Layout" "gap" (Layout.gap 3) ]))
                [ Text.paragraph "Two people edited the same order. A customer reference added on only one side is kept automatically; warehouse and dispatch note need your decision."
                , Conflict.view ConflictMsg
                    (Options.klarConflictResolver playground (List.concat [ Config.keep playground "ConflictResolver" "onApply" (Conflict.onApply Apply), Config.keep playground "ConflictResolver" "locale" (Conflict.locale locale), Config.keep playground "ConflictResolver" "settings" (Conflict.settings model.settings), Config.keep playground "ConflictResolver" "onRetry" (Conflict.onRetry (Retry "order-conflict")) ]))
                    { label = "Order field conflicts", ids = Ids.string, fields = remote model model.fields }
                    model.conflict
                , case model.applied of
                    Just merged ->
                        Options.alertView playground (Options.klarAlert playground (List.concat [ Config.keep playground "Alert" "tone" (Alert.tone Success), Config.keep playground "Alert" "polite" Alert.polite ])) ("Resolved values: " ++ String.join " · " (List.map (\( label, value ) -> label ++ " = " ++ Maybe.withDefault "(absent)" value) merged))

                    Nothing ->
                        Html.text ""
                ]
            )
        , panel "Audit log"
            (AuditLog.view (Options.klarAuditLog playground (List.concat [ Config.keep playground "AuditLog" "id" (AuditLog.id "review-history"), Config.keep playground "AuditLog" "search" (AuditLog.search model.historyQuery HistoryQuery), Config.keep playground "AuditLog" "locale" (AuditLog.locale locale), Config.keep playground "AuditLog" "settings" (AuditLog.settings model.settings), Config.keep playground "AuditLog" "onRetry" (AuditLog.onRetry (Retry "review-history")) ]))
                { label = "Decision history", ids = Ids.int, entries = remote model model.audit }
            )
        , panel "Notification centre"
            (Notifications.view (Options.klarNotificationCenter playground (List.concat [ Config.keep playground "NotificationCenter" "id" (Notifications.id "review-notifications"), Config.keep playground "NotificationCenter" "unreadOnly" (Notifications.unreadOnly model.unreadOnly UnreadOnly), Config.keep playground "NotificationCenter" "onRead" (Notifications.onRead ReadNotice), Config.keep playground "NotificationCenter" "onReadAll" (Notifications.onReadAll ReadAll), Config.keep playground "NotificationCenter" "onDismiss" (Notifications.onDismiss DismissNotice), Config.keep playground "NotificationCenter" "locale" (Notifications.locale locale), Config.keep playground "NotificationCenter" "settings" (Notifications.settings model.settings), Config.keep playground "NotificationCenter" "onRetry" (Notifications.onRetry (Retry "review-notifications")) ]))
                { label = "Review notifications", ids = Ids.int, items = remote model (List.map Notifications.notification model.notices) }
            )
        ]


subscriptions : Model -> Sub Msg
subscriptions _ =
    Time.every 1000 Now
