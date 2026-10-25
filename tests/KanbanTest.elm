module KanbanTest exposing (suite)

import Expect
import Html exposing (Html)
import Html.Attributes as Attr
import Json.Encode as Encode
import Klar.Ids as Ids exposing (Ids)
import Klar.Kanban as Kanban
import Klar.Locale as Locale
import Klar.Remote as Remote exposing (Remote)
import Test exposing (Test, describe, test)
import Test.Html.Event as Event
import Test.Html.Query as Query
import Test.Html.Selector as S exposing (Selector)
import Time


type CardId
    = CardId Int


type StageId
    = Todo
    | Doing
    | Done


type alias Card =
    { id : CardId, title : String }


type Msg
    = BoardMsg Kanban.Msg
    | Retry
    | Open CardId


cardIds : Ids CardId
cardIds =
    Ids.make { toKey = \(CardId id) -> String.fromInt id, fromKey = String.toInt >> Maybe.map CardId }


stageIds : Ids StageId
stageIds =
    Ids.list
        (\stage ->
            case stage of
                Todo ->
                    "todo"

                Doing ->
                    "doing"

                Done ->
                    "done"
        )
        [ Todo, Doing, Done ]


first : Card
first =
    { id = CardId 1, title = "Order 1" }


second : Card
second =
    { id = CardId 2, title = "Order 2" }


third : Card
third =
    { id = CardId 3, title = "Order 3" }


board : List (Kanban.Column StageId Card)
board =
    [ Kanban.column Todo "To do" [ first, second ], Kanban.column Doing "In progress" [ third ], Kanban.column Done "Done" [] ]


widget : List (Kanban.Column StageId Card) -> Kanban.State -> Html Kanban.Msg
widget columns state =
    Kanban.view identity [] { label = "Orders", columns = Remote.Loaded columns, columnIds = stageIds, cardIds = cardIds, cardId = .id, title = .title, content = always (Html.text "") } state


send : List Selector -> ( String, Encode.Value ) -> List (Kanban.Column StageId Card) -> Kanban.State -> Result String Kanban.State
send selectors event columns state =
    widget columns state |> Query.fromHtml |> Query.find selectors |> Event.simulate event |> Event.toResult |> Result.map (\msg -> Kanban.update msg state |> Tuple.first)


pick : List (Kanban.Column StageId Card) -> Kanban.State -> Result String Kanban.State
pick columns state =
    send [ S.id "board-move-1" ] Event.click columns state


inputAt : Int -> String -> List (Kanban.Column StageId Card) -> Kanban.State -> Result String Kanban.State
inputAt index value columns state =
    widget columns state |> Query.fromHtml |> Query.findAll [ S.tag "select" ] |> Query.index index |> Event.simulate (Event.input value) |> Event.toResult |> Result.map (\msg -> Kanban.update msg state |> Tuple.first)


request : String -> Int -> List (Kanban.Column StageId Card) -> Result String (Kanban.Move CardId StageId)
request target at columns =
    pick columns (Kanban.init "board")
        |> Result.andThen (inputAt 0 target columns)
        |> Result.andThen (inputAt 1 (String.fromInt at) columns)
        |> Result.andThen
            (\before ->
                send [ S.tag "button", S.containing [ S.text "Move here" ] ] Event.click columns before
                    |> Result.andThen (\after -> Kanban.move cardIds stageIds before after |> Result.fromMaybe "No move request")
            )


order : List (Kanban.Column StageId Card) -> List (List CardId)
order columns =
    List.map (Kanban.cards >> List.map .id) columns


withCap : Int -> Kanban.Column StageId Card -> Kanban.Column StageId Card
withCap maximum col =
    Kanban.limit maximum |> Maybe.map (\cap -> Kanban.withLimit cap col) |> Maybe.withDefault col


remoteWidget : Remote (List (Kanban.Column StageId Card)) -> Html Msg
remoteWidget data =
    Kanban.view BoardMsg [ Kanban.onRetry Retry ] { label = "Orders", columns = data, columnIds = stageIds, cardIds = cardIds, cardId = .id, title = .title, content = always (Html.text "") } (Kanban.init "board")


key : String -> ( String, Encode.Value )
key name =
    Event.custom "keydown" (Encode.object [ ( "key", Encode.string name ), ( "ctrlKey", Encode.bool False ), ( "metaKey", Encode.bool False ), ( "shiftKey", Encode.bool False ), ( "altKey", Encode.bool False ) ])


suite : Test
suite =
    describe "Klar.Kanban"
        [ describe "Typed, revision-checked move requests"
            [ test "moving into an empty column preserves every card once" <|
                \_ ->
                    request "done" 0 board |> Result.andThen (\change -> Kanban.applyMove cardIds stageIds .id change board |> Result.mapError (Kanban.problemText Locale.en)) |> Result.map order |> Expect.equal (Ok [ [ CardId 2 ], [ CardId 3 ], [ CardId 1 ] ])
            , test "destination positions count after removing the source" <|
                \_ ->
                    request "todo" 1 board |> Result.andThen (\change -> Kanban.applyMove cardIds stageIds .id change board |> Result.mapError (Kanban.problemText Locale.en)) |> Result.map order |> Expect.equal (Ok [ [ CardId 2, CardId 1 ], [ CardId 3 ], [] ])
            , test "moving to the existing position leaves the order alone" <|
                \_ ->
                    request "todo" 0 board |> Result.andThen (\change -> Kanban.applyMove cardIds stageIds .id change board |> Result.mapError (Kanban.problemText Locale.en)) |> Result.map order |> Expect.equal (Ok (order board))
            , test "request accessors retain the application's own types" <|
                \_ ->
                    request "doing" 1 board |> Result.map (\change -> ( Kanban.cardId change, Kanban.source change, ( Kanban.target change, Kanban.position change ) )) |> Expect.equal (Ok ( CardId 1, Todo, ( Doing, 1 ) ))
            , test "a request cannot be applied to a changed card order" <|
                \_ ->
                    let
                        changed =
                            [ Kanban.column Todo "To do" [ second, first ], Kanban.column Doing "In progress" [ third ], Kanban.column Done "Done" [] ]
                    in
                    request "done" 0 board |> Result.map (\change -> Kanban.applyMove cardIds stageIds .id change changed |> Result.mapError (Kanban.problemText Locale.en)) |> Expect.equal (Ok (Err "The board changed. Cancel this move and choose again."))
            , test "a request cannot be applied twice" <|
                \_ ->
                    request "done" 0 board |> Result.map (\change -> Kanban.applyMove cardIds stageIds .id change board |> Result.andThen (Kanban.applyMove cardIds stageIds .id change) |> Result.mapError (Kanban.problemText Locale.en) |> Result.map order) |> Expect.equal (Ok (Err "The board changed. Cancel this move and choose again."))
            , test "changed card details survive a valid move" <|
                \_ ->
                    let
                        changed =
                            [ Kanban.column Todo "To do" [ { first | title = "Updated title" }, second ], Kanban.column Doing "In progress" [ third ], Kanban.column Done "Done" [] ]
                    in
                    request "done" 0 board |> Result.andThen (\change -> Kanban.applyMove cardIds stageIds .id change changed |> Result.mapError (Kanban.problemText Locale.en)) |> Result.map (List.concatMap Kanban.cards >> List.map .title) |> Expect.equal (Ok [ "Order 2", "Order 3", "Updated title" ])
            , test "same state twice has no new request" <|
                \_ ->
                    let
                        state =
                            Kanban.init "board"
                    in
                    Kanban.move cardIds stageIds state state |> Expect.equal Nothing
            , test "reading a request with a codec that cannot decode its ids returns Nothing" <|
                \_ ->
                    pick board (Kanban.init "board") |> Result.andThen (\before -> send [ S.tag "button", S.containing [ S.text "Move here" ] ] Event.click board before |> Result.map (\after -> Kanban.move (Ids.make { toKey = Ids.toKey cardIds, fromKey = always Nothing }) stageIds before after |> Maybe.map Kanban.cardId)) |> Expect.equal (Ok Nothing)
            ]
        , describe "Work-in-progress limits"
            [ test "negative capacities are rejected" <| \_ -> Expect.equal Nothing (Kanban.limit -1)
            , test "zero is a valid closed capacity" <| \_ -> Kanban.limit 0 |> Maybe.map (always True) |> Expect.equal (Just True)
            , test "a full destination is disabled and refuses synthetic selection" <|
                \_ ->
                    let
                        limited =
                            [ Kanban.column Todo "To do" [ first, second ], withCap 1 (Kanban.column Doing "In progress" [ third ]), Kanban.column Done "Done" [] ]
                    in
                    pick limited (Kanban.init "board") |> Result.andThen (inputAt 0 "doing" limited) |> Result.map (widget limited >> Query.fromHtml >> Query.has [ S.text "The destination has reached its work-in-progress limit." ]) |> Result.withDefault (Expect.fail "Could not open move controls")
            , test "reordering an over-limit column does not increase WIP" <|
                \_ ->
                    let
                        limited =
                            [ withCap 1 (Kanban.column Todo "To do" [ first, second ]), Kanban.column Doing "In progress" [ third ], Kanban.column Done "Done" [] ]
                    in
                    request "todo" 1 limited |> Result.andThen (\change -> Kanban.applyMove cardIds stageIds .id change limited |> Result.mapError (Kanban.problemText Locale.en)) |> Result.map order |> Expect.equal (Ok [ [ CardId 2, CardId 1 ], [ CardId 3 ], [] ])
            , test "moving out of an over-limit column is permitted" <|
                \_ ->
                    let
                        limited =
                            [ withCap 0 (Kanban.column Todo "To do" [ first, second ]), Kanban.column Doing "In progress" [ third ], Kanban.column Done "Done" [] ]
                    in
                    request "done" 0 limited |> Result.andThen (\change -> Kanban.applyMove cardIds stageIds .id change limited |> Result.mapError (Kanban.problemText Locale.en)) |> Result.map order |> Expect.equal (Ok [ [ CardId 2 ], [ CardId 3 ], [ CardId 1 ] ])
            , test "capacity changes invalidate pending moves" <|
                \_ ->
                    let
                        changed =
                            [ Kanban.column Todo "To do" [ first, second ], withCap 1 (Kanban.column Doing "In progress" [ third ]), Kanban.column Done "Done" [] ]
                    in
                    request "doing" 1 board |> Result.map (\change -> Kanban.applyMove cardIds stageIds .id change changed |> Result.mapError (Kanban.problemText Locale.en) |> Result.map order) |> Expect.equal (Ok (Err "The board changed. Cancel this move and choose again."))
            ]
        , describe "Keyboard controls and safe markup"
            [ test "arrow keys change the proposed position before confirmation" <|
                \_ ->
                    pick board (Kanban.init "board") |> Result.andThen (send [ S.id "board-move-1" ] (key "ArrowDown") board) |> Result.map (widget board >> Query.fromHtml >> Query.has [ S.attribute (Attr.value "1"), S.tag "select" ]) |> Result.withDefault (Expect.fail "Arrow key did not produce a state")
            , test "keyboard navigation reaches an empty stage beyond a full stage" <|
                \_ ->
                    let
                        limited =
                            [ Kanban.column Todo "To do" [ first, second ], withCap 1 (Kanban.column Doing "In progress" [ third ]), Kanban.column Done "Done" [] ]
                    in
                    pick limited (Kanban.init "board") |> Result.andThen (send [ S.id "board-move-1" ] (key "ArrowRight") limited) |> Result.andThen (\before -> send [ S.id "board-move-1" ] (key "Enter") limited before |> Result.map (\after -> Kanban.move cardIds stageIds before after |> Maybe.map Kanban.target)) |> Expect.equal (Ok (Just Done))
            , test "Escape cancels without producing a move request" <|
                \_ ->
                    pick board (Kanban.init "board") |> Result.andThen (\before -> send [ S.id "board-move-1" ] (key "Escape") board before |> Result.map (\after -> Kanban.move cardIds stageIds before after |> Maybe.map Kanban.cardId)) |> Expect.equal (Ok Nothing)
            , test "Tab cancels the panel instead of committing" <|
                \_ ->
                    pick board (Kanban.init "board") |> Result.andThen (send [ S.id "board-move-1" ] (key "Tab") board) |> Result.map (widget board >> Query.fromHtml >> Query.findAll [ S.tag "select" ] >> Query.count (Expect.equal 0)) |> Result.withDefault (Expect.fail "Tab did not produce a state")
            , test "duplicate card ids show a warning and remove movement controls" <|
                \_ ->
                    widget [ Kanban.column Todo "To do" [ first, first ] ] (Kanban.init "board") |> Query.fromHtml |> Expect.all [ Query.has [ S.text "Column and card ids must be unique. Moving is disabled." ], Query.findAll [ S.class "klar-kanban__handle" ] >> Query.count (Expect.equal 0), Query.findAll [ S.class "klar-kanban__card" ] >> Query.count (Expect.equal 2) ]
            , test "duplicate columns show every stage with a warning" <|
                \_ ->
                    widget [ Kanban.column Todo "One" [ first ], Kanban.column Todo "Two" [ second ] ] (Kanban.init "board") |> Query.fromHtml |> Expect.all [ Query.has [ S.text "Column and card ids must be unique. Moving is disabled." ], Query.findAll [ S.class "klar-kanban__column" ] >> Query.count (Expect.equal 2) ]
            , test "column headings and help references exist" <|
                \_ ->
                    widget board (Kanban.init "board") |> Query.fromHtml |> Expect.all [ Query.has [ S.id "board-help" ], Query.has [ S.attribute (Attr.attribute "aria-describedby" "board-help") ], Query.has [ S.id "board-column-0" ], Query.has [ S.attribute (Attr.attribute "aria-labelledby" "board-column-0") ] ]
            ]
        , describe "Remote data"
            [ test "loading announces busy state" <| \_ -> remoteWidget Remote.Loading |> Query.fromHtml |> Query.has [ S.attribute (Attr.attribute "aria-busy" "true") ]
            , test "failure offers retry" <| \_ -> remoteWidget (Remote.Failed (Remote.problem Remote.network)) |> Query.fromHtml |> Query.find [ S.tag "button", S.containing [ S.text "Try again" ] ] |> Event.simulate Event.click |> Event.expect Retry
            , test "no stages is an empty state" <| \_ -> remoteWidget (Remote.Loaded []) |> Query.fromHtml |> Query.has [ S.text "No stages" ]
            , test "a board with empty stages preserves those stages" <| \_ -> remoteWidget (Remote.Loaded [ Kanban.column Todo "To do" [] ]) |> Query.fromHtml |> Expect.all [ Query.has [ S.text "To do" ], Query.has [ S.text "No cards" ] ]
            , test "refresh keeps all cards while disabling movement" <| \_ -> remoteWidget (Remote.refresh (Remote.Loaded board)) |> Query.fromHtml |> Expect.all [ Query.findAll [ S.class "klar-kanban__card" ] >> Query.count (Expect.equal 3), Query.findAll [ S.class "klar-kanban__handle", S.disabled True ] >> Query.count (Expect.equal 3) ]
            , test "stale data shows a retry and disables movement" <| \_ -> remoteWidget (Remote.refreshWith (Remote.Loaded board) (Err (Remote.problem Remote.network)) (Time.millisToPosix 0)) |> Query.fromHtml |> Expect.all [ Query.has [ S.text "Old data" ], Query.findAll [ S.class "klar-kanban__handle", S.disabled True ] >> Query.count (Expect.equal 3) ]
            , test "retained empty data still shows old-data status" <| \_ -> remoteWidget (Remote.refreshWith (Remote.Loaded []) (Err (Remote.problem Remote.network)) (Time.millisToPosix 0)) |> Query.fromHtml |> Expect.all [ Query.has [ S.text "No stages" ], Query.has [ S.text "Old data" ] ]
            ]
        ]
