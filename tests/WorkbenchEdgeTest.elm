module WorkbenchEdgeTest exposing (suite)

import Expect
import Html
import Html.Attributes as Attr
import Klar.AuditLog as AuditLog
import Klar.CardList as CardList
import Klar.ConflictResolver as Conflict
import Klar.Ids as Ids
import Klar.NotificationCenter as Notifications
import Klar.Remote as Remote
import Klar.WorkQueue as Queue
import Test exposing (Test, describe, test)
import Test.Html.Event as Event
import Test.Html.Query as Query
import Test.Html.Selector as S
import Time


type Msg
    = Apply (List ( String, Maybe String ))
    | ConflictMsg Conflict.Msg
    | Search String
    | Unread Bool
    | More


versions : { base : Maybe String, yours : Maybe String, theirs : Maybe String }
versions =
    { base = Just "a", yours = Just "b", theirs = Just "c" }


field : Conflict.Field String
field =
    Conflict.field "f" "Field" versions


chosen : Result String Conflict.State
chosen =
    let
        state =
            Conflict.init "conflict"
    in
    Conflict.view identity [] { label = "Resolve", ids = Ids.string, fields = Remote.Loaded [ field ] } state
        |> Query.fromHtml
        |> Query.findAll [ S.tag "input" ]
        |> Query.first
        |> Event.simulate (Event.check True)
        |> Event.toResult
        |> Result.map (\msg -> Conflict.update msg state |> Tuple.first)


applyButton : Remote.Remote (List (Conflict.Field String)) -> Query.Single Msg
applyButton data =
    Conflict.view ConflictMsg [ Conflict.onApply Apply ] { label = "Resolve", ids = Ids.string, fields = data } (Conflict.init "c")
        |> Query.fromHtml
        |> Query.find [ S.tag "button", S.containing [ S.text "Apply resolved values" ] ]


suite : Test
suite =
    describe "Workbench boundaries"
        [ describe "Merge decisions are version-bound"
            [ test "changing the base invalidates a reviewed choice" <|
                \_ ->
                    chosen |> Result.map (Conflict.resolved Ids.string [ Conflict.field "f" "Field" { versions | base = Just "new base" } ]) |> Expect.equal (Ok (Err [ "f" ]))
            , test "changing your edit invalidates a reviewed choice" <|
                \_ ->
                    chosen |> Result.map (Conflict.resolved Ids.string [ Conflict.field "f" "Field" { versions | yours = Just "new edit" } ]) |> Expect.equal (Ok (Err [ "f" ]))
            , test "changing their edit invalidates a reviewed choice" <|
                \_ ->
                    chosen |> Result.map (Conflict.resolved Ids.string [ Conflict.field "f" "Field" { versions | theirs = Just "new edit" } ]) |> Expect.equal (Ok (Err [ "f" ]))
            , test "identical deletes agree without a choice" <|
                \_ ->
                    Conflict.resolved Ids.string [ Conflict.field "f" "Field" { base = Just "a", yours = Nothing, theirs = Nothing } ] (Conflict.init "c") |> Expect.equal (Ok [ ( "f", Nothing ) ])
            , test "missing field ids do not silently appear in the result" <|
                \_ ->
                    chosen |> Result.map (Conflict.resolved Ids.string []) |> Expect.equal (Ok (Ok []))
            , test "resolved automatic values cannot be applied from stale data" <|
                \_ ->
                    Remote.refreshWith (Remote.Loaded [ Conflict.field "f" "Field" { base = Nothing, yours = Just "b", theirs = Nothing } ]) (Err (Remote.problem Remote.network)) (Time.millisToPosix 0)
                        |> applyButton
                        |> Query.has [ S.disabled True ]
            , test "the apply handler receives exact automatic values" <|
                \_ ->
                    applyButton (Remote.Loaded [ Conflict.field "f" "Field" { base = Nothing, yours = Just "  ", theirs = Nothing } ]) |> Event.simulate Event.click |> Event.expect (Apply [ ( "f", Just "  " ) ])
            , test "saving disables both radio options" <|
                \_ ->
                    Conflict.view ConflictMsg [ Conflict.saving True ] { label = "Resolve", ids = Ids.string, fields = Remote.Loaded [ field ] } (Conflict.init "c") |> Query.fromHtml |> Query.findAll [ S.tag "input", S.disabled True ] |> Query.count (Expect.equal 2)
            , test "empty fields offer no apply action" <|
                \_ ->
                    Conflict.view ConflictMsg [ Conflict.onApply Apply ] { label = "Resolve", ids = Ids.string, fields = Remote.Loaded [] } (Conflict.init "c") |> Query.fromHtml |> Query.findAll [ S.tag "button" ] |> Query.count (Expect.equal 0)
            ]
        , describe "Paging remains available without visible data"
            [ test "empty cards can load another page" <|
                \_ ->
                    CardList.view [ CardList.onLoadMore More ] { label = "Cards", ids = Ids.int, id = identity, items = Remote.Loaded [], title = String.fromInt, fields = [] } |> Query.fromHtml |> Query.find [ S.tag "button" ] |> Event.simulate Event.click |> Event.expect More
            , test "empty notifications can load older items" <|
                \_ ->
                    Notifications.view [ Notifications.onLoadMore More ] { label = "Inbox", ids = Ids.int, items = Remote.Loaded [] } |> Query.fromHtml |> Query.find [ S.tag "button" ] |> Event.simulate Event.click |> Event.expect More
            , test "empty history can load older events" <|
                \_ ->
                    AuditLog.view [ AuditLog.onLoadMore More ] { label = "History", ids = Ids.int, entries = Remote.Loaded [] } |> Query.fromHtml |> Query.find [ S.tag "button" ] |> Event.simulate Event.click |> Event.expect More
            , test "empty work queue can request another page" <|
                \_ ->
                    Queue.view (always More) [ Queue.onLoadMore More ] { label = "Queue", ids = Ids.int, id = identity, items = Remote.Loaded [], title = String.fromInt, summary = always "", detail = always (Html.text "") } (Queue.init "q") |> Query.fromHtml |> Query.find [ S.tag "button" ] |> Event.simulate Event.click |> Event.expect More
            , test "an audit query with no matches keeps the load-more action" <|
                \_ ->
                    AuditLog.view [ AuditLog.search "zzzzzz" Search, AuditLog.onLoadMore More ] { label = "History", ids = Ids.int, entries = Remote.Loaded [ AuditLog.entry { id = 1, actor = "Ada", action = "Approved", at = Time.millisToPosix 0 } ] } |> Query.fromHtml |> Query.find [ S.tag "button", S.containing [ S.text "Load more" ] ] |> Event.simulate Event.click |> Event.expect More
            ]
        , describe "Multiple component instances"
            [ test "history search ids can be scoped to their instance" <|
                \_ ->
                    AuditLog.view [ AuditLog.id "customer-history", AuditLog.search "" Search ] { label = "History", ids = Ids.int, entries = Remote.Loaded [ AuditLog.entry { id = 1, actor = "Ada", action = "Approved", at = Time.millisToPosix 0 } ] } |> Query.fromHtml |> Query.has [ S.tag "input", S.id "customer-history-search" ]
            , test "notification switch ids can be scoped to their instance" <|
                \_ ->
                    Notifications.view [ Notifications.id "orders-inbox", Notifications.unreadOnly False Unread ] { label = "Inbox", ids = Ids.int, items = Remote.Loaded [ Notifications.notification { id = 1, title = "Ready", body = "", unread = False, at = Time.millisToPosix 0 } ] } |> Query.fromHtml |> Query.has [ S.id "orders-inbox-unread" ]
            , test "a card region keeps its focus target during loading" <|
                \_ ->
                    CardList.view [ CardList.id "product-cards" ] { label = "Cards", ids = Ids.int, id = identity, items = Remote.Loading, title = String.fromInt, fields = [] } |> Query.fromHtml |> Query.has [ S.id "product-cards", S.attribute (Attr.tabindex -1) ]
            ]
        ]
