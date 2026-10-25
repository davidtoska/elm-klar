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
import Klar.Date as Date
import Klar.FilterBar as FilterBar
import Klar.Ids as Ids exposing (Ids)
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
    (ServerList.update (ServerList.gotPage request result) state).state


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
            , Table.rowId Ids.string .id
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
        , fixTests
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
                                    ServerList.update (ServerList.gotPage old (Ok { rows = [], total = 1 })) second.state
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
                        ServerList.update (ServerList.gotPage old (Ok { rows = [], total = 1 })) second.state
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
                        (ServerList.mapTable (Table.setPage 3) loaded).state
                in
                afterClick Event.click
                    [ Selector.class "klar-filterbar__chip-remove" ]
                    onPageThree
                    (\request -> Expect.equal ( request.query.page, Rule.conditionCount request.rule ) ( 1, 0 ))
        , test "a sort click asks again with the sort, from page 1" <|
            \_ ->
                afterClick (Orders.sortClick False)
                    (Orders.sortButton "Status")
                    (ServerList.mapTable (Table.setPage 3) loaded).state
                    (\request -> Expect.equal ( request.query.sort, request.query.page ) ( [ ( Table.columnId "status", Table.Ascending ) ], 1 ))
        , test "an answer asks for nothing" <|
            \_ ->
                started
                    |> asked (\request -> Expect.equal (ServerList.update (ServerList.gotPage request page) started.state).request Nothing)
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
                Expect.equal (ServerList.target Ids.string loaded) Nothing
        , test "rows picked one by one are a Picked target" <|
            \_ ->
                (ServerList.mapTable (Table.setSelected Ids.string [ "a", "b" ] True) loaded).state
                    |> ServerList.target Ids.string
                    |> Expect.equal (Just (ServerList.Picked [ "a", "b" ]))
        ]


plainView : SavedViews.SavedView
plainView =
    SavedViews.savedView "Plain" packed


today : Date.Date
today =
    Date.fromPosix Time.utc (Time.millisToPosix 0)


fixTests : Test
fixTests =
    describe "the glue after the audit"
        [ test "views that arrive after the user searched leave the search and the rule alone" <|
            \_ ->
                let
                    first =
                        ServerList.init "orders" []

                    searched =
                        case first.request of
                            Just request ->
                                (ServerList.mapTable (Table.setSearch "fjord") (answer request page first.state)).state

                            Nothing ->
                                first.state

                    step =
                        ServerList.setViews views searched
                in
                Expect.all
                    [ \_ -> Expect.equal (ServerList.rule step.state) Rule.emptyGroup
                    , \_ -> Expect.equal (ServerList.query step.state).search "fjord"
                    , \_ -> Expect.equal (ServerList.activeView step.state) Nothing
                    , \_ -> Expect.equal step.request Nothing
                    ]
                    ()
        , test "a later list of views (the echo of a store) never applies the default" <|
            \_ ->
                let
                    -- "Open" was active and is gone; "Packed" is the default now
                    echo =
                        [ SavedViews.savedView "Packed" packed |> SavedViews.asDefault ]

                    step =
                        ServerList.setViews echo loaded
                in
                Expect.all
                    [ \_ -> Expect.equal (ServerList.rule step.state) open
                    , \_ -> Expect.equal step.request Nothing
                    , \_ -> Expect.equal (List.map .name (ServerList.savedViews step.state)) [ "Packed" ]
                    ]
                    ()
        , test "mapTable with a new page size asks with it" <|
            \_ ->
                ServerList.mapTable (Table.setPageSize 50) loaded
                    |> asked (\request -> Expect.equal request.query.pageSize 50)
        , test "mapTable that leaves the query alone asks for nothing" <|
            \_ ->
                Expect.equal (ServerList.mapTable Table.clearSelection loaded).request Nothing
        , test "a view without a query takes away the search of the view before" <|
            \_ ->
                let
                    withPlain =
                        (ServerList.setViews (views ++ [ plainView ]) loaded).state

                    step =
                        ServerList.applyView "Plain" (ServerList.applyView "Packed" withPlain).state
                in
                Expect.equal (ServerList.query step.state).search ""
        , test "an empty page past the end asks for the last page" <|
            \_ ->
                let
                    onFive =
                        ServerList.mapTable (Table.setPage 5) loaded
                in
                onFive
                    |> asked
                        (\request ->
                            ServerList.update (ServerList.gotPage request (Ok { rows = [], total = 40 })) onFive.state
                                |> asked (\again -> Expect.equal again.query.page 2)
                        )
        , test "an empty answer past page 1 with nothing left goes back to page 1 without asking" <|
            \_ ->
                let
                    onFive =
                        ServerList.mapTable (Table.setPage 5) loaded
                in
                onFive
                    |> asked
                        (\request ->
                            let
                                step =
                                    ServerList.update (ServerList.gotPage request (Ok { rows = [], total = 0 })) onFive.state
                            in
                            Expect.equal ( step.request, (ServerList.query step.state).page ) ( Nothing, 1 )
                        )
        , test "the filter bar shows no count after a failed refresh" <|
            \_ ->
                let
                    step =
                        ServerList.refresh loaded

                    failed =
                        case step.request of
                            Just request ->
                                answer request (Err (Remote.problem Remote.server)) step.state

                            Nothing ->
                                step.state

                    countIn state =
                        ServerList.viewFilterBar identity [ FilterBar.fields fields ] state
                            |> Query.fromHtml
                in
                Expect.all
                    [ \_ -> countIn loaded |> Query.has [ Selector.text "40" ]
                    , \_ -> countIn failed |> Query.hasNot [ Selector.text "40" ]
                    ]
                    ()
        , test "mapRows changes the rows on the screen and asks for nothing" <|
            \_ ->
                ServerList.mapRows (\order -> { order | status = "packed" }) loaded
                    |> ServerList.rows
                    |> Remote.toMaybe
                    |> Expect.equal (Just [ { id = "a", status = "packed" } ])
        , test "views that arrive while the first page is on its way and change nothing ask for nothing" <|
            \_ ->
                Expect.equal (ServerList.setViews views started.state).request Nothing
        , test "a view applied right after init asks, also when nothing changed" <|
            \_ ->
                Expect.notEqual (ServerList.applyView "Open" started.state).request Nothing
        , test "applyView matches the name ignoring case" <|
            \_ ->
                ServerList.applyView "packed" loaded
                    |> asked (\request -> Expect.equal request.rule packed)
        , test "the address of a list reads back as the same list and asks for nothing" <|
            \_ ->
                let
                    state =
                        (ServerList.mapTable (Table.setSort [ ( Table.columnId "status", Table.Descending ) ] >> Table.setPage 2) loaded).state
                in
                Expect.equal (ServerList.fromQueryString (ServerList.toQueryString state) state).request Nothing
        , test "the address writes the view, the search, the sort, the page and the size" <|
            \_ ->
                let
                    state =
                        (ServerList.mapTable (Table.setSearch "fjord & co" >> Table.setSort [ ( Table.columnId "status", Table.Descending ) ] >> Table.setPage 2) loaded).state

                    text =
                        ServerList.toQueryString state
                in
                Expect.all
                    (List.map (\part -> \_ -> Expect.equal ( part, String.contains part text ) ( part, True ))
                        [ "view=Open", "search=fjord%20%26%20co", "sort=-status", "page=2", "size=25", "rule=" ]
                    )
                    ()
        , test "an address put on another list gives it the query, the page and the rule" <|
            \_ ->
                let
                    state =
                        (ServerList.mapTable (Table.setSearch "fjord" >> Table.setPage 2) (ServerList.applyView "Packed" loaded).state).state
                in
                ServerList.fromQueryString (ServerList.toQueryString state) loaded
                    |> asked
                        (\request ->
                            Expect.all
                                [ \_ -> Expect.equal request.query (ServerList.query state)
                                , \_ -> Expect.equal (Rule.conditionCount request.rule) 1
                                , \_ -> Expect.equal (Rule.matches today fields request.rule { id = "x", status = "packed" }) True
                                ]
                                ()
                        )
        , test "an address with only a view applies the view" <|
            \_ ->
                ServerList.fromQueryString "view=Packed" loaded
                    |> asked (\request -> Expect.equal ( request.rule, request.query.search ) ( packed, "ada" ))
        , test "an address without the list's parameters is Reset: the default view" <|
            \_ ->
                ServerList.fromQueryString "" (ServerList.applyView "Packed" loaded).state
                    |> asked (\request -> Expect.equal ( request.rule, request.query.search ) ( open, "" ))
        , test "a parameter that cannot be read counts as missing" <|
            \_ ->
                ServerList.fromQueryString "page=abc&rule=%7Bnot%20json&size=25" loaded
                    |> asked (\request -> Expect.equal ( request.query.page, Rule.conditionCount request.rule ) ( 1, 0 ))
        ]
