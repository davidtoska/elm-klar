module TableVirtualTest exposing (suite)

import Expect exposing (Expectation)
import Html.Attributes as Attr
import Json.Encode as Encode
import Klar.Remote exposing (Remote(..))
import Klar.Table as Table
import Klar.Theme as Theme
import Support.Orders as Orders exposing (Msg, Order, generated, passes)
import Test exposing (Test, describe, test)
import Test.Html.Event as Event
import Test.Html.Query as Query
import Test.Html.Selector as Selector exposing (Selector)


suite : Test
suite =
    describe "Klar.Table.virtual"
        [ drawing
        , scrolling
        , keyboard
        , selecting
        , serverMode
        ]


start : Table.State String
start =
    Table.init "orders"


longTable : List (Table.Attribute String Order Msg)
longTable =
    [ Table.remote (Loaded (generated 1000)), Table.virtual, Table.selectable ]


view : List (Table.Attribute String Order Msg) -> Table.State String -> Query.Single Msg
view attributes state =
    Orders.render attributes state |> Query.fromHtml


has : List Selector -> Query.Single Msg -> Bool
has selectors query =
    passes (Query.has selectors query)


hasRow : Int -> Query.Single Msg -> Bool
hasRow index query =
    passes (Query.has [] (Query.find [ Selector.id (Orders.rowDomId index) ] query))


{-| The first and the last of the rows 0 to 999 that are drawn.
-}
drawn : Query.Single Msg -> ( Int, Int )
drawn query =
    let
        present =
            List.filter (\index -> hasRow index query) (List.range 0 999)
    in
    ( List.head present |> Maybe.withDefault -1, List.reverse present |> List.head |> Maybe.withDefault -1 )


scrolledTo : Float -> Table.State String -> Table.State String
scrolledTo top state =
    let
        result =
            view longTable state
                |> Query.find [ Selector.id "orders-scroll" ]
                |> Event.simulate (Event.custom "scroll" (Encode.object [ ( "target", Encode.object [ ( "scrollTop", Encode.float top ) ] ) ]))
                |> Event.toResult
    in
    case result of
        Ok msg ->
            Orders.applyMsg msg state

        Err _ ->
            state


drawing : Test
drawing =
    describe "drawing"
        [ test "only the rows in view are drawn, and not all thousand" <|
            \_ ->
                -- 480 pixels, 36 pixels a row, less the header and the totals row
                drawn (view longTable start)
                    |> Expect.equal ( 0, 31 )
        , test "the table says how many rows there are, drawn or not" <|
            \_ ->
                view longTable start
                    |> Query.find [ Selector.tag "table" ]
                    |> Query.has [ Selector.attribute (Attr.attribute "aria-rowcount" "1001") ]
        , test "there are no pages: no pagination, and the range in view instead" <|
            \_ ->
                let
                    query =
                        view longTable start
                in
                Expect.all
                    [ \q -> Expect.equal False (has [ Selector.class "klar-pagination" ] q)
                    , \q -> Expect.equal True (has [ Selector.text "of 1,000 rows" ] q)
                    ]
                    query
        , test "the room of the rows that are not drawn is kept, so that the scrollbar is right" <|
            \_ ->
                view longTable start
                    |> Query.find [ Selector.class "klar-table__spacer-body" ]
                    |> Query.find [ Selector.tag "tr" ]
                    |> Query.has [ Selector.attribute (Attr.attribute "style" "height:34848px") ]
        , test "a row says its place in the whole table" <|
            \_ ->
                view longTable start
                    |> Query.find [ Selector.id (Orders.rowDomId 5) ]
                    |> Query.has [ Selector.attribute (Attr.attribute "aria-rowindex" "7") ]
        , test "compact rows are shorter, so more of them are drawn" <|
            \_ ->
                let
                    tall =
                        longTable ++ [ Table.maxHeight 900 ]
                in
                Expect.greaterThan
                    (drawn (view tall start) |> Tuple.second)
                    (drawn (view tall (Table.setDensity Theme.Compact start)) |> Tuple.second)
        , test "an empty table shows the empty state and no rows" <|
            \_ ->
                view [ Table.remote (Loaded []), Table.virtual ] start
                    |> Query.has [ Selector.text "No data" ]
        ]


scrolling : Test
scrolling =
    describe "scrolling"
        [ test "the rows in view change with the scroll offset, a chunk at a time" <|
            \_ ->
                -- row 500 at the top; 4 rows of overscan, then to the chunk of 16
                drawn (view longTable (scrolledTo (500 * 36) start))
                    |> Expect.equal ( 496, 527 )
        , test "a few rows of scrolling change nothing" <|
            \_ ->
                Expect.equal
                    (drawn (view longTable (scrolledTo (500 * 36) start)))
                    (drawn (view longTable (scrolledTo (500 * 36 + 100) start)))
        , test "the end of the table can be reached" <|
            \_ ->
                drawn (view longTable (scrolledTo 1.0e9 start))
                    |> Tuple.second
                    |> Expect.equal 999
        , test "the range in view ends with the last row at the end of the table" <|
            \_ ->
                view longTable (scrolledTo 1.0e9 start)
                    |> Query.has [ Selector.text "Showing 990–1,000 of 1,000 rows." ]
        , test "sorting goes back to the top" <|
            \_ ->
                let
                    scrolled =
                        scrolledTo (500 * 36) start

                    sorted =
                        Orders.press longTable (Orders.sortButton "Customer") (Orders.sortClick False) scrolled
                in
                case sorted of
                    Ok state ->
                        drawn (view longTable state) |> Tuple.first |> Expect.equal 0

                    Err problem ->
                        Expect.fail problem
        ]


keyboard : Test
keyboard =
    describe "the keyboard"
        [ test "the first row has the tab stop" <|
            \_ ->
                tabStop 0 start
        , test "PageDown moves by a screenful and scrolls to the row" <|
            \_ ->
                moved "PageDown" (Orders.rowDomId 0) start
                    |> Result.map (\state -> Expect.all [ tabStop 11, notTabStop 0, expectDrawn 11 ] state)
                    |> orFail
        , test "End goes to the last row, which is drawn then" <|
            \_ ->
                moved "End" (Orders.rowDomId 0) start
                    |> Result.map (\state -> Expect.all [ tabStop 999, notTabStop 0, expectDrawn 999 ] state)
                    |> orFail
        , test "Home goes back to the first row" <|
            \_ ->
                moved "End" (Orders.rowDomId 0) start
                    |> Result.andThen (moved "Home" (Orders.rowDomId 999))
                    |> Result.map (\state -> Expect.all [ tabStop 0, notTabStop 999, expectDrawn 0 ] state)
                    |> orFail
        ]


tabStop : Int -> Table.State String -> Expectation
tabStop index state =
    view longTable state
        |> Query.has [ Selector.all [ Selector.id (Orders.rowDomId index), Selector.attribute (Attr.tabindex 0) ] ]


notTabStop : Int -> Table.State String -> Expectation
notTabStop index state =
    if passes (Query.has [ Selector.all [ Selector.id (Orders.rowDomId index), Selector.attribute (Attr.tabindex 0) ] ] (view longTable state)) then
        Expect.fail ("row " ++ String.fromInt index ++ " has the tab stop")

    else
        Expect.pass


expectDrawn : Int -> Table.State String -> Expectation
expectDrawn index state =
    if hasRow index (view longTable state) then
        Expect.pass

    else
        Expect.fail ("row " ++ String.fromInt index ++ " is not drawn")


moved : String -> String -> Table.State String -> Result String (Table.State String)
moved key fromRow state =
    Orders.press longTable [ Selector.id fromRow ] (Orders.keyDown fromRow key) state


orFail : Result String Expectation -> Expectation
orFail result =
    case result of
        Ok expectation ->
            expectation

        Err problem ->
            Expect.fail problem


selecting : Test
selecting =
    describe "selecting"
        [ test "the checkbox in the header selects every matching row, not only those drawn" <|
            \_ ->
                Orders.press longTable [ Selector.id "orders-select-page" ] (Orders.checkedBox True) start
                    |> Result.map (\state -> Table.selectedCount 1000 state |> Expect.equal 1000)
                    |> orFail
        , test "and it is checked when they are all selected" <|
            \_ ->
                Orders.press longTable [ Selector.id "orders-select-page" ] (Orders.checkedBox True) start
                    |> Result.map (\state -> Expect.equal True (has [ Selector.id "orders-select-page", Selector.attribute (Attr.checked True) ] (view longTable state)))
                    |> orFail
        ]


serverMode : Test
serverMode =
    let
        server =
            [ Table.remote (Loaded (generated 200)), Table.server { total = 5000 }, Table.virtual ]
    in
    describe "in server mode"
        [ test "the pagination stays, and only the rows in view of the page are drawn" <|
            \_ ->
                let
                    query =
                        view server start
                in
                Expect.all
                    [ \q -> Expect.equal True (has [ Selector.class "klar-pagination" ] q)
                    , \q -> Expect.equal ( 0, 31 ) (drawnOf q)
                    ]
                    query
        ]


drawnOf : Query.Single Msg -> ( Int, Int )
drawnOf query =
    let
        present =
            List.filter (\index -> hasRow index query) (List.range 0 199)
    in
    ( List.head present |> Maybe.withDefault -1, List.reverse present |> List.head |> Maybe.withDefault -1 )
