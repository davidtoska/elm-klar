module ServerListTest exposing (suite)

{-| The pure parts of `Klar.ServerList`: the request and its ticket, an answer to an old
request that is dropped, the page that goes back to 1 when the rule changed, a saved view
that is loaded into the filter bar and the table, and the selection as a `Target`.

The messages of the table and the filter bar are made the way a user makes them: the
control is drawn, found and clicked, and the message it sends is given to `update`. A control
that is not there is a failure, not a control that does nothing.

-}

import Expect exposing (Expectation)
import Html exposing (Html)
import Json.Encode as Encode
import Klar.FilterBar as FilterBar
import Klar.Remote as Remote exposing (Remote(..))
import Klar.Rule as Rule
import Klar.SavedViews as SavedViews
import Klar.ServerList as ServerList exposing (Request, Step)
import Klar.Table as Table
import Support.Orders as Orders
import Test exposing (Test, describe, test)
import Test.Html.Event as Event
import Test.Html.Query as Query
import Test.Html.Selector as Selector exposing (Selector)
import Time


type alias Order =
    { id : String
    , status : String
    }


type alias State =
    ServerList.State String Order


type alias Msg =
    ServerList.Msg Order


type alias Answer =
    Result Remote.Problem (ServerList.Page Order)


open : Rule.Rule
open =
    Rule.allOf [ Rule.is "status" "open" ]


packed : Rule.Rule
packed =
    Rule.allOf [ Rule.is "status" "packed" ]


views : List SavedViews.SavedView
views =
    [ SavedViews.savedView "Open" open |> SavedViews.asDefault
    , SavedViews.savedView "Packed" packed
        |> SavedViews.withQuery { search = "ada", sort = [], filters = [], page = 5, pageSize = 25 }
    ]


fields : List (Rule.Field Order)
fields =
    [ Rule.textField "status" "Status" .status ]


at : Time.Posix
at =
    Time.millisToPosix 1000


page : Answer
page =
    Ok { rows = [ { id = "a", status = "open" } ], total = 40 }


started : Step String Order
started =
    ServerList.init "orders" views


{-| The request of a step, or a failure when the step asked for nothing.
-}
asked : (Request -> Expectation) -> Step String Order -> Expectation
asked check step =
    case step.request of
        Just request ->
            check request

        Nothing ->
            Expect.fail "the step asked for nothing, and a request was expected"


{-| Answer a request and give back the state.
-}
answer : Request -> Answer -> State -> State
answer request result state =
    (ServerList.update (ServerList.gotPage request result at) state).state


{-| The state after the first request has been answered.
-}
loaded : State
loaded =
    case started.request of
        Just request ->
            answer request page started.state

        Nothing ->
            started.state


everything : State -> Html Msg
everything state =
    Html.div []
        [ ServerList.viewSavedViews identity [] state
        , ServerList.viewFilterBar identity [ FilterBar.fields fields ] state
        , ServerList.viewTable identity
            [ Table.columns
                [ Table.text (Table.columnId "id") "Id" .id []
                , Table.text (Table.columnId "status") "Status" .status []
                ]
            , Table.rowId Table.stringIds .id
            ]
            state
        ]


{-| The step that follows a click on the control.
-}
clicked : ( String, Encode.Value ) -> List Selector -> State -> Result String (Step String Order)
clicked event selectors state =
    everything state
        |> Query.fromHtml
        |> Query.find selectors
        |> Event.simulate event
        |> Event.toResult
        |> Result.map (\msg -> ServerList.update msg state)


afterClick : ( String, Encode.Value ) -> List Selector -> State -> (Request -> Expectation) -> Expectation
afterClick event selectors state check =
    case clicked event selectors state of
        Ok step ->
            asked check step

        Err problem ->
            Expect.fail problem


suite : Test
suite =
    describe "Klar.ServerList"
        [ startTests
        , answerTests
        , queryTests
        , viewTests
        , selectionTests
        ]


startTests : Test
startTests =
    describe "the first request"
        [ test "applies the default view: its rule is in the request and in the filter bar" <|
            \_ ->
                started
                    |> asked
                        (\request ->
                            Expect.all
                                [ \_ -> Expect.equal request.rule open
                                , \_ -> Expect.equal (ServerList.rule started.state) open
                                , \_ -> Expect.equal (Maybe.map .name (ServerList.activeView started.state)) (Just "Open")
                                , \_ -> Expect.equal started.save Nothing
                                , \_ -> Expect.equal (ServerList.rows started.state) Loading
                                ]
                                ()
                        )
        , test "without views the first request has an empty rule and page 1" <|
            \_ ->
                ServerList.init "orders" []
                    |> asked (\request -> Expect.equal ( request.rule, request.query.page ) ( Rule.emptyGroup, 1 ))
        , test "setViews after the list was made asks again with the default view" <|
            \_ ->
                ServerList.setViews views (ServerList.init "orders" []).state
                    |> asked (\request -> Expect.equal request.rule open)
        , test "setViews with the views the list has asks for nothing" <|
            \_ ->
                Expect.equal (ServerList.setViews views loaded).request Nothing
        ]


answerTests : Test
answerTests =
    describe "answers"
        [ test "the answer to the latest request is shown, with the total" <|
            \_ ->
                Expect.equal ( Remote.toMaybe (ServerList.rows loaded), ServerList.total loaded )
                    ( Just [ { id = "a", status = "open" } ], 40 )
        , test "an answer to an old request is dropped" <|
            \_ ->
                let
                    first =
                        ServerList.refresh loaded

                    second =
                        ServerList.refresh first.state
                in
                first
                    |> asked
                        (\old ->
                            let
                                late =
                                    ServerList.update (ServerList.gotPage old (Ok { rows = [], total = 1 }) at) second.state
                            in
                            Expect.all
                                [ \_ -> Expect.equal (ServerList.total late.state) 40
                                , \_ -> Expect.equal (Remote.isRefreshing (ServerList.rows late.state)) True
                                , \_ -> Expect.equal late.request Nothing
                                ]
                                ()
                        )
        , test "the answer to the latest request is taken after an old one was dropped" <|
            \_ ->
                let
                    first =
                        ServerList.refresh loaded

                    second =
                        ServerList.refresh first.state
                in
                Maybe.map2
                    (\old latest ->
                        ServerList.update (ServerList.gotPage old (Ok { rows = [], total = 1 }) at) second.state
                            |> .state
                            |> answer latest (Ok { rows = [], total = 7 })
                            |> ServerList.total
                    )
                    first.request
                    second.request
                    |> Expect.equal (Just 7)
        , test "a failed answer keeps the rows on the screen as old data" <|
            \_ ->
                let
                    step =
                        ServerList.refresh loaded
                in
                step
                    |> asked
                        (\request ->
                            let
                                failed =
                                    answer request (Err (Remote.problem Remote.server)) step.state
                            in
                            Expect.all
                                [ \_ -> Expect.equal (Remote.isStale (ServerList.rows failed)) True
                                , \_ -> Expect.equal (Remote.toMaybe (ServerList.rows failed)) (Just [ { id = "a", status = "open" } ])
                                ]
                                ()
                        )
        , test "a failed first answer is a failure with nothing to keep" <|
            \_ ->
                started
                    |> asked (\request -> Expect.equal (Remote.isFailed (ServerList.rows (answer request (Err (Remote.problem Remote.server)) started.state))) True)
        , test "every request has a ticket of its own" <|
            \_ ->
                Maybe.map2 (\a b -> a.ticket /= b.ticket) started.request (ServerList.refresh started.state).request
                    |> Expect.equal (Just True)
        ]


queryTests : Test
queryTests =
    describe "the query and the rule"
        [ test "removing a filter chip asks again from page 1 with the smaller rule" <|
            \_ ->
                let
                    onPageThree =
                        ServerList.mapTable (Table.setPage 3) loaded
                in
                afterClick Event.click
                    [ Selector.class "klar-filterbar__chip-remove" ]
                    onPageThree
                    (\request -> Expect.equal ( request.query.page, Rule.conditionCount request.rule ) ( 1, 0 ))
        , test "a sort click asks again with the sort, from page 1" <|
            \_ ->
                afterClick (Orders.sortClick False)
                    (Orders.sortButton "Status")
                    (ServerList.mapTable (Table.setPage 3) loaded)
                    (\request -> Expect.equal ( request.query.sort, request.query.page ) ( [ ( Table.columnId "status", Table.Ascending ) ], 1 ))
        , test "an answer asks for nothing" <|
            \_ ->
                started
                    |> asked (\request -> Expect.equal (ServerList.update (ServerList.gotPage request page at) started.state).request Nothing)
        , test "applying a view puts its rule and its query in place, at page 1, and stores nothing" <|
            \_ ->
                let
                    step =
                        ServerList.applyView "Packed" loaded
                in
                step
                    |> asked
                        (\request ->
                            Expect.all
                                [ \_ -> Expect.equal request.rule packed
                                , \_ -> Expect.equal request.query.search "ada"
                                , \_ -> Expect.equal request.query.page 1
                                , \_ -> Expect.equal (ServerList.rule step.state) packed
                                , \_ -> Expect.equal step.save Nothing
                                ]
                                ()
                        )
        , test "applying an unknown view asks for nothing" <|
            \_ ->
                Expect.equal (ServerList.applyView "Nope" loaded).request Nothing
        , test "the request has the query and the rule that the state shows" <|
            \_ ->
                ServerList.refresh loaded
                    |> asked (\request -> Expect.equal ( request.query, request.rule ) ( ServerList.query loaded, ServerList.rule loaded ))
        ]


viewTests : Test
viewTests =
    describe "the parts"
        [ test "the filter bar says how many rows match once the answer is there" <|
            \_ ->
                everything loaded
                    |> Query.fromHtml
                    |> Query.has [ Selector.text "40" ]
        ]


selectionTests : Test
selectionTests =
    describe "the selection as a target"
        [ test "nothing selected is no target" <|
            \_ ->
                Expect.equal (ServerList.target Table.stringIds loaded) Nothing
        , test "rows picked one by one are a Picked target" <|
            \_ ->
                ServerList.mapTable (Table.setSelected Table.stringIds [ "a", "b" ] True) loaded
                    |> ServerList.target Table.stringIds
                    |> Expect.equal (Just (ServerList.Picked [ "a", "b" ]))
        ]
