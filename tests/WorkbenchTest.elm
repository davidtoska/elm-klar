module WorkbenchTest exposing (suite)

import Expect
import Fuzz
import Html exposing (Html)
import Html.Attributes as Attr
import Json.Encode as Encode
import Klar.AuditLog as AuditLog
import Klar.CardList as CardList
import Klar.ConflictResolver as Conflict
import Klar.Diff as Diff
import Klar.Ids as Ids
import Klar.Locale as Locale
import Klar.NotificationCenter as Notifications
import Klar.Remote as Remote exposing (Remote)
import Klar.WorkQueue as Queue
import Test exposing (Test, describe, fuzz2, test)
import Test.Html.Event as Event
import Test.Html.Query as Query
import Test.Html.Selector as S
import Time


type Id
    = Id Int


ids : Ids.Ids Id
ids =
    Ids.make { toKey = \(Id id) -> String.fromInt id, fromKey = String.toInt >> Maybe.map Id }


type Msg
    = Retry
    | Chosen (List Id)
    | Open Id
    | Read Int
    | ReadAll (List Int)
    | Dismiss Int
    | More
    | Filter Bool
    | Applied (List ( String, Maybe String ))
    | QueueMsg Queue.Msg
    | ConflictMsg Conflict.Msg


cards : List Id -> Remote (List Int) -> Html Msg
cards selected items =
    CardList.view [ CardList.selection selected Chosen, CardList.onOpen Open, CardList.onRetry Retry ]
        { label = "Cards", items = items, ids = ids, id = Id, title = String.fromInt, fields = [ CardList.field "Code" (String.fromInt >> Html.text) ] }


queue : Queue.State -> Remote (List Int) -> Html Queue.Msg
queue state items =
    Queue.view identity
        [ Queue.searchable ]
        { label = "Queue", items = items, ids = ids, id = Id, title = String.fromInt, summary = always "Summary", detail = String.fromInt >> Html.text }
        state


conflictFields : List (Conflict.Field String)
conflictFields =
    [ Conflict.field "address" "Address" { base = Just "Bergen", yours = Just "Oslo", theirs = Just "Trondheim" } ]


resolver : List (Conflict.Field String) -> Conflict.State -> Html Conflict.Msg
resolver fields state =
    Conflict.view identity [] { label = "Conflicts", ids = Ids.string, fields = Remote.Loaded fields } state


choose : Int -> List (Conflict.Field String) -> Conflict.State -> Result String Conflict.State
choose index fields state =
    resolver fields state
        |> Query.fromHtml
        |> Query.findAll [ S.tag "input", S.attribute (Attr.type_ "radio") ]
        |> Query.index index
        |> Event.simulate (Event.check True)
        |> Event.toResult
        |> Result.map (\msg -> Tuple.first (Conflict.update msg state))


notices : List (Notifications.Attribute Int Msg) -> Html Msg
notices attributes =
    Notifications.view attributes
        { label = "Inbox"
        , ids = Ids.int
        , items =
            Remote.Loaded
                [ Notifications.notification { id = 1, title = "One", body = "Body", at = Time.millisToPosix 0, unread = True }
                , Notifications.notification { id = 2, title = "Two", body = "Body", at = Time.millisToPosix 0, unread = False }
                ]
        }


allWidgets : List ( String, Remote (List Int) -> Html Msg )
allWidgets =
    [ ( "CardList", cards [] )
    , ( "WorkQueue"
      , \data ->
            Queue.view QueueMsg
                [ Queue.onRetry Retry ]
                { label = "Queue", items = data, ids = ids, id = Id, title = String.fromInt, summary = always "Summary", detail = String.fromInt >> Html.text }
                (Queue.init "queue")
      )
    , ( "AuditLog"
      , \data ->
            AuditLog.view [ AuditLog.onRetry Retry ]
                { label = "Audit", ids = Ids.int, entries = Remote.map (List.map (\id -> AuditLog.entry { id = id, actor = "Ada", action = "Changed order", at = Time.millisToPosix 0 })) data }
      )
    , ( "NotificationCenter"
      , \data ->
            Notifications.view [ Notifications.onRetry Retry ]
                { label = "Inbox", ids = Ids.int, items = Remote.map (List.map (\id -> Notifications.notification { id = id, title = "Notice", body = "Body", at = Time.millisToPosix 0, unread = True })) data }
      )
    , ( "ConflictResolver"
      , \data ->
            Conflict.view ConflictMsg
                [ Conflict.onRetry Retry ]
                { label = "Conflicts", ids = Ids.int, fields = Remote.map (List.map (\id -> Conflict.field id "Field" { base = Nothing, yours = Just "Mine", theirs = Just "Theirs" })) data }
                (Conflict.init "conflict")
      )
    ]


suite : Test
suite =
    describe "Data workbench"
        [ describe "Every component draws every remote state"
            (List.map
                (\( name, widget ) ->
                    describe name
                        [ test "not asked is an accessible loading state" <|
                            \_ ->
                                widget Remote.NotAsked |> Query.fromHtml |> Query.has [ S.attribute (Attr.attribute "aria-busy" "true") ]
                        , test "loading is busy" <|
                            \_ ->
                                widget Remote.Loading |> Query.fromHtml |> Query.has [ S.attribute (Attr.attribute "aria-busy" "true") ]
                        , test "initial failure can be retried" <|
                            \_ ->
                                widget (Remote.Failed (Remote.problem Remote.network)) |> Query.fromHtml |> Query.find [ S.tag "button", S.containing [ S.text "Try again" ] ] |> Event.simulate Event.click |> Event.expect Retry
                        , test "empty data is announced" <|
                            \_ ->
                                widget (Remote.Loaded []) |> Query.fromHtml |> Query.has [ S.class "klar-state--empty" ]
                        , test "refreshing keeps content and marks it busy" <|
                            \_ ->
                                widget (Remote.refresh (Remote.Loaded [ 1 ]))
                                    |> Query.fromHtml
                                    |> Expect.all
                                        [ Query.has [ S.class "klar-refreshing" ], Query.has [ S.attribute (Attr.attribute "aria-busy" "true") ] ]
                        , test "failed refresh keeps content and offers retry" <|
                            \_ ->
                                widget (Remote.refreshWith (Remote.Loaded [ 1 ]) (Err (Remote.problem Remote.network)) (Time.millisToPosix 0))
                                    |> Query.fromHtml
                                    |> Expect.all
                                        [ Query.has [ S.text "Old data" ], Query.has [ S.tag "button", S.containing [ S.text "Try again" ] ] ]
                        , test "retained empty data still shows the old-data marker" <|
                            \_ ->
                                widget (Remote.refreshWith (Remote.Loaded []) (Err (Remote.problem Remote.network)) (Time.millisToPosix 0))
                                    |> Query.fromHtml
                                    |> Expect.all
                                        [ Query.has [ S.text "Old data" ], Query.has [ S.class "klar-state--empty" ] ]
                        ]
                )
                allWidgets
            )
        , describe "Card selection uses the application's ids"
            [ test "select loaded keeps selections on another page" <|
                \_ ->
                    cards [ Id 99, Id 1 ] (Remote.Loaded [ 1, 2 ]) |> Query.fromHtml |> Query.findAll [ S.tag "input" ] |> Query.first |> Event.simulate (Event.check True) |> Event.expect (Chosen [ Id 99, Id 1, Id 2 ])
            , test "clear loaded preserves off-page selections" <|
                \_ ->
                    cards [ Id 99, Id 1, Id 2 ] (Remote.Loaded [ 1, 2 ]) |> Query.fromHtml |> Query.findAll [ S.tag "input" ] |> Query.first |> Event.simulate (Event.check False) |> Event.expect (Chosen [ Id 99 ])
            , test "partial selection is mixed for assistive technology" <|
                \_ ->
                    cards [ Id 1 ] (Remote.Loaded [ 1, 2 ]) |> Query.fromHtml |> Query.has [ S.attribute (Attr.attribute "aria-checked" "mixed") ]
            , test "opening sends the custom id" <|
                \_ ->
                    cards [] (Remote.Loaded [ 7 ]) |> Query.fromHtml |> Query.find [ S.tag "button", S.containing [ S.text "7" ] ] |> Event.simulate Event.click |> Event.expect (Open (Id 7))
            ]
        , describe "Three-way resolution"
            [ fuzz2 Fuzz.string Fuzz.string "a change on their side alone is preserved exactly" <|
                \base theirs ->
                    Conflict.resolved Ids.string [ Conflict.field "f" "Field" { base = Just base, yours = Just base, theirs = Just theirs } ] (Conflict.init "c") |> Expect.equal (Ok [ ( "f", Just theirs ) ])
            , fuzz2 Fuzz.string Fuzz.string "a change on your side alone is preserved exactly" <|
                \base yours ->
                    Conflict.resolved Ids.string [ Conflict.field "f" "Field" { base = Just base, yours = Just yours, theirs = Just base } ] (Conflict.init "c") |> Expect.equal (Ok [ ( "f", Just yours ) ])
            , test "both edited differently requires an explicit choice" <|
                \_ ->
                    Conflict.resolved Ids.string conflictFields (Conflict.init "c") |> Expect.equal (Err [ "address" ])
            , test "choosing yours produces exactly that value" <|
                \_ ->
                    choose 0 conflictFields (Conflict.init "c") |> Result.map (Conflict.resolved Ids.string conflictFields) |> Expect.equal (Ok (Ok [ ( "address", Just "Oslo" ) ]))
            , test "choosing theirs produces exactly that value" <|
                \_ ->
                    choose 1 conflictFields (Conflict.init "c") |> Result.map (Conflict.resolved Ids.string conflictFields) |> Expect.equal (Ok (Ok [ ( "address", Just "Trondheim" ) ]))
            , test "a refreshed version invalidates an earlier choice" <|
                \_ ->
                    choose 0 conflictFields (Conflict.init "c") |> Result.map (Conflict.resolved Ids.string [ Conflict.field "address" "Address" { base = Just "Bergen", yours = Just "Oslo", theirs = Just "Stavanger" } ]) |> Expect.equal (Ok (Err [ "address" ]))
            , test "absence and empty text remain different values" <|
                \_ ->
                    Conflict.resolved Ids.string [ Conflict.field "f" "Field" { base = Nothing, yours = Just "", theirs = Just " " } ] (Conflict.init "c") |> Expect.equal (Err [ "f" ])
            , test "deletion on just one side is preserved" <|
                \_ ->
                    Conflict.resolved Ids.string [ Conflict.field "f" "Field" { base = Just "a", yours = Nothing, theirs = Just "a" } ] (Conflict.init "c") |> Expect.equal (Ok [ ( "f", Nothing ) ])
            , test "reset removes decisions" <|
                \_ ->
                    choose 0 conflictFields (Conflict.init "c") |> Result.map (Conflict.reset >> Conflict.resolved Ids.string conflictFields) |> Expect.equal (Ok (Err [ "address" ]))
            , test "apply is disabled while data is being refreshed" <|
                \_ ->
                    Conflict.view ConflictMsg [ Conflict.onApply Applied ] { label = "Conflict", ids = Ids.string, fields = Remote.refresh (Remote.Loaded [ Conflict.field "f" "Field" { base = Nothing, yours = Just "a", theirs = Nothing } ]) } (Conflict.init "c") |> Query.fromHtml |> Query.find [ S.tag "button", S.containing [ S.text "Apply resolved values" ] ] |> Query.has [ S.disabled True ]
            ]
        , describe "Work queue"
            [ test "selection round trips custom ids" <|
                \_ ->
                    Queue.init "q" |> Queue.setSelected ids (Just (Id 12)) |> Queue.selected ids |> Expect.equal (Just (Id 12))
            , test "missing selected data is reported rather than silently replaced" <|
                \_ ->
                    queue (Queue.setSelected ids (Just (Id 99)) (Queue.init "q")) (Remote.Loaded [ 1, 2 ]) |> Query.fromHtml |> Query.has [ S.text "Selected item is no longer in the loaded queue" ]
            , test "arrow down selects the next custom id" <|
                \_ ->
                    let
                        state =
                            Queue.init "q"
                    in
                    queue state (Remote.Loaded [ 1, 2, 3 ]) |> Query.fromHtml |> Query.find [ S.id "q-item-1" ] |> Event.simulate (Event.custom "keydown" (Encode.object [ ( "key", Encode.string "ArrowDown" ), ( "ctrlKey", Encode.bool False ), ( "metaKey", Encode.bool False ), ( "shiftKey", Encode.bool False ), ( "altKey", Encode.bool False ) ])) |> Event.toResult |> Result.map (\msg -> Queue.update msg state |> Tuple.first |> Queue.selected ids) |> Expect.equal (Ok (Just (Id 2)))
            , test "a queue's detail reference exists" <|
                \_ ->
                    queue (Queue.init "q") (Remote.Loaded [ 1 ]) |> Query.fromHtml |> Expect.all [ Query.has [ S.attribute (Attr.attribute "aria-controls" "q-detail") ], Query.has [ S.id "q-detail" ] ]
            ]
        , describe "Notification actions"
            [ test "read-all only sends unread loaded ids" <|
                \_ ->
                    notices [ Notifications.onReadAll ReadAll ] |> Query.fromHtml |> Query.find [ S.tag "button", S.containing [ S.text "Mark loaded as read" ] ] |> Event.simulate Event.click |> Event.expect (ReadAll [ 1 ])
            , test "unread filtering leaves read data out" <|
                \_ ->
                    notices [ Notifications.unreadOnly True Filter ] |> Query.fromHtml |> Expect.all [ Query.has [ S.text "One" ], Query.hasNot [ S.text "Two" ] ]
            , test "read and dismiss are separate actions" <|
                \_ ->
                    notices [ Notifications.onRead Read, Notifications.onDismiss Dismiss ] |> Query.fromHtml |> Query.find [ S.tag "button", S.containing [ S.text "Mark as read" ] ] |> Event.simulate Event.click |> Event.expect (Read 1)
            , test "Norwegian built-in text is supplied" <|
                \_ ->
                    notices [ Notifications.locale Locale.nb, Notifications.onReadAll ReadAll ] |> Query.fromHtml |> Query.has [ S.text "Merk innlastede som lest" ]
            ]
        , test "audit diffs use native details and are collapsed initially" <|
            \_ ->
                AuditLog.view [] { label = "History", ids = Ids.int, entries = Remote.Loaded [ AuditLog.entry { id = 1, actor = "Ada", action = "Changed", at = Time.millisToPosix 0 } |> AuditLog.withDiff (Diff.lines [] "before" "after") ] } |> Query.fromHtml |> Query.find [ S.tag "details" ] |> Query.hasNot [ S.attribute (Attr.attribute "open" "") ]
        ]
