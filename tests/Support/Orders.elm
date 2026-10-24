module Support.Orders exposing
    ( Msg(..)
    , Order
    , allOf
    , applyMsg
    , ariaLabelled
    , cannotUse
    , checkedBox
    , chosen
    , clickOn
    , columns
    , curated
    , expectRows
    , generated
    , keyDown
    , keyDownWith
    , passes
    , press
    , render
    , rowClickOn
    , rowDomId
    , send
    , shownNumbers
    , sortButton
    , sortClick
    )

{-| What the table tests share: orders as rows, a set of columns, a way to draw
the table, and helpers to press its buttons and read back which rows it shows.

The table keeps its state in the application. A test therefore draws the table,
finds a control the way a user would, simulates the event on it, takes the
message that the control sends, and gives it to `Table.update`. `press` does all
of that in one step, so a test can chain presses with `Result.andThen`.

-}

import Expect exposing (Expectation)
import Html exposing (Html)
import Html.Attributes as Attr
import Json.Encode as Encode
import Klar.Date as Date exposing (Date)
import Klar.Remote exposing (Remote(..))
import Klar.Table as Table
import Support.Ids as Ids
import Test.Html.Event as Event
import Test.Html.Query as Query
import Test.Html.Selector as Selector exposing (Selector)
import Test.Runner


type Msg
    = TableMsg Table.Msg
    | Retried
    | Refreshed
    | Opened Order
    | FiltersReset
    | Deleted


type alias Order =
    { number : String
    , customer : String
    , city : String
    , items : Int
    , total : Float
    , status : String
    , shipped : Maybe Date
    , express : Bool
    }


date : Int -> Int -> Int -> Maybe Date
date year month day =
    Date.fromParts year month day


{-| Eight orders with something to sort, search and filter on: accents, a
letter case that differs, missing dates, equal totals.
-}
curated : List Order
curated =
    [ { number = "ORD-2001", customer = "Acme Supplies", city = "Oslo", items = 3, total = 120.5, status = "Shipped", shipped = date 2026 10 1, express = True }
    , { number = "ORD-2002", customer = "Globex", city = "Bergen", items = 12, total = 52, status = "Open", shipped = Nothing, express = False }
    , { number = "ORD-2003", customer = "Østby Trading", city = "Ålesund", items = 1, total = 9.99, status = "Open", shipped = Nothing, express = True }
    , { number = "ORD-2004", customer = "Initech", city = "Oslo", items = 7, total = 1250, status = "Shipped", shipped = date 2026 9 25, express = True }
    , { number = "ORD-2005", customer = "Ærlig Varehus", city = "Bergen", items = 5, total = 75, status = "Cancelled", shipped = date 2026 8 2, express = False }
    , { number = "ORD-2006", customer = "Zeta Works", city = "Zürich", items = 2, total = 300, status = "Open", shipped = Nothing, express = False }
    , { number = "ORD-2007", customer = "acme logistics", city = "Oslo", items = 20, total = 0, status = "Shipped", shipped = date 2026 10 10, express = True }
    , { number = "ORD-2008", customer = "Éclair Foods", city = "Tromsø", items = 4, total = 75, status = "Open", shipped = date 2026 7 14, express = False }
    ]


{-| Orders 3001, 3002 ... for tests that need several pages.
-}
generated : Int -> List Order
generated count =
    List.range 1 count
        |> List.map
            (\n ->
                { number = "ORD-" ++ String.fromInt (3000 + n)
                , customer = "Customer " ++ String.fromInt n
                , city = [ "Oslo", "Bergen", "Trondheim" ] |> List.drop (modBy 3 n) |> List.head |> Maybe.withDefault "Oslo"
                , items = modBy 9 n
                , total = toFloat n * 5
                , status = [ "Open", "Shipped" ] |> List.drop (modBy 2 n) |> List.head |> Maybe.withDefault "Open"
                , shipped = Nothing
                , express = modBy 2 n == 0
                }
            )


columns : List (Table.Column Order Msg)
columns =
    [ Table.text (Table.columnId "number") "Order" .number []
    , Table.text (Table.columnId "customer") "Customer" .customer [ Table.filterText ]
    , Table.text (Table.columnId "city") "City" .city [ Table.filterSelect ]
    , Table.int (Table.columnId "items") "Items" .items [ Table.filterRange, Table.footerSum ]
    , Table.float (Table.columnId "total") "Total" 2 .total [ Table.filterRange, Table.footerAverage ]
    , Table.text (Table.columnId "status") "Status" .status [ Table.filterSelect ]
    , Table.maybeDate (Table.columnId "shipped") "Shipped" .shipped []
    , Table.bool (Table.columnId "express") "Express" .express [ Table.filterSelect ]
    ]


{-| The table with the id `orders`, the curated orders in `columns`, and then
the attributes of the test (later attributes win).
-}
render : List (Table.Attribute String Order Msg) -> Table.State String -> Html Msg
render attributes state =
    Table.view TableMsg
        ([ Table.columns columns
         , Table.remote (Loaded curated)
         , Table.rowId Ids.strings .number
         , Table.ariaLabel "Orders"
         ]
            ++ attributes
        )
        state


applyMsg : Msg -> Table.State String -> Table.State String
applyMsg msg state =
    case msg of
        TableMsg tableMsg ->
            Tuple.first (Table.update tableMsg state)

        _ ->
            state


{-| Draw the table, find the one element the selectors name, and simulate the
event on it. The result is the message the element sends, or what went wrong:
no such element, several, or an element that does not listen to the event.
-}
send : List (Table.Attribute String Order Msg) -> List Selector -> ( String, Encode.Value ) -> Table.State String -> Result String Msg
send attributes selectors event state =
    render attributes state
        |> Query.fromHtml
        |> Query.find selectors
        |> Event.simulate event
        |> Event.toResult


{-| `send`, and then give the message to `Table.update`.
-}
press : List (Table.Attribute String Order Msg) -> List Selector -> ( String, Encode.Value ) -> Table.State String -> Result String (Table.State String)
press attributes selectors event state =
    send attributes selectors event state
        |> Result.map (\msg -> applyMsg msg state)



-- WHAT THE USER POINTS AT


{-| The sort button in the header cell with this title.
-}
sortButton : String -> List Selector
sortButton title =
    [ Selector.class "klar-table__sort", Selector.containing [ Selector.text title ] ]


ariaLabelled : String -> List Selector
ariaLabelled label =
    [ Selector.attribute (Attr.attribute "aria-label" label) ]


rowDomId : Int -> String
rowDomId index =
    "orders-row-" ++ String.fromInt index



-- EVENTS


{-| The header buttons read the Shift key, so a plain `click` is not enough.
-}
sortClick : Bool -> ( String, Encode.Value )
sortClick shift =
    Event.custom "click" (Encode.object [ ( "shiftKey", Encode.bool shift ) ])


{-| A click that started on the element with this id.
-}
clickOn : String -> ( String, Encode.Value )
clickOn id =
    Event.custom "click" (Encode.object [ ( "target", Encode.object [ ( "id", Encode.string id ) ] ) ])


{-| A click on a row, which started on an element with this tag name.
-}
rowClickOn : String -> ( String, Encode.Value )
rowClickOn tagName =
    Event.custom "click" (Encode.object [ ( "target", Encode.object [ ( "tagName", Encode.string tagName ) ] ) ])


{-| A `select` that changed to this value.
-}
chosen : String -> ( String, Encode.Value )
chosen value =
    Event.custom "change" (Encode.object [ ( "target", Encode.object [ ( "value", Encode.string value ) ] ) ])


checkedBox : Bool -> ( String, Encode.Value )
checkedBox =
    Event.check


{-| A key pressed while the element with this id has the focus.
-}
keyDown : String -> String -> ( String, Encode.Value )
keyDown targetId key =
    keyDownWith { shift = False, ctrl = False } targetId key


keyDownWith : { shift : Bool, ctrl : Bool } -> String -> String -> ( String, Encode.Value )
keyDownWith modifiers targetId key =
    Event.custom "keydown"
        (Encode.object
            [ ( "key", Encode.string key )
            , ( "ctrlKey", Encode.bool modifiers.ctrl )
            , ( "metaKey", Encode.bool False )
            , ( "altKey", Encode.bool False )
            , ( "shiftKey", Encode.bool modifiers.shift )
            , ( "target", Encode.object [ ( "id", Encode.string targetId ) ] )
            ]
        )



-- WHAT THE TABLE SHOWS


{-| The control is there, but cannot be used: a disabled button, the current
page. (A control that is missing altogether is a failure, so that a mistake in
the selectors does not look like success.)
-}
cannotUse : List (Table.Attribute String Order Msg) -> List Selector -> ( String, Encode.Value ) -> Table.State String -> Expectation
cannotUse attributes selectors event state =
    allOf
        [ render attributes state
            |> Query.fromHtml
            |> Query.find selectors
            |> Query.has []
        , case send attributes selectors event state of
            Ok _ ->
                Expect.fail "The control sent a message, but it should not be usable."

            Err _ ->
                Expect.pass
        ]


allOf : List Expectation -> Expectation
allOf expectations =
    Expect.all (List.map (\expectation _ -> expectation) expectations) ()


{-| Did the expectation pass? For asking a question of the HTML instead of
asserting it.
-}
passes : Expectation -> Bool
passes expectation =
    case Test.Runner.getFailureReason expectation of
        Nothing ->
            True

        Just _ ->
            False


hasText : String -> Query.Single msg -> Bool
hasText text query =
    passes (Query.has [ Selector.text text ] query)


rowQuery : Int -> Query.Single Msg -> Query.Single Msg
rowQuery index table =
    Query.find [ Selector.id (rowDomId index) ] table


{-| The first of these that satisfy the test, in order, up to the first that
does not.
-}
takeWhile : (a -> Bool) -> List a -> List a
takeWhile test items =
    case items of
        [] ->
            []

        first :: rest ->
            if test first then
                first :: takeWhile test rest

            else
                []


{-| The order numbers of the rows the table draws, top to bottom: for every row
the first number from the candidates that the row shows.
-}
shownNumbers : Html Msg -> List String
shownNumbers html =
    let
        table =
            Query.fromHtml html

        candidates =
            List.map .number (curated ++ generated 120)

        exists index =
            passes (Query.has [] (rowQuery index table))
    in
    List.range 0 149
        |> takeWhile exists
        |> List.map
            (\index ->
                candidates
                    |> List.filter (\number -> hasText number (rowQuery index table))
                    |> List.head
                    |> Maybe.withDefault "(a row without an order number)"
            )


{-| The table draws exactly these rows, in this order. When it does not, the
failure lists the order numbers that it shows instead.
-}
expectRows : List String -> Html Msg -> Expectation
expectRows expected html =
    let
        table =
            Query.fromHtml html

        count =
            Query.findAll [ Selector.class "klar-table__row" ] table

        atPlace =
            List.indexedMap (\index number -> hasText number (rowQuery index table)) expected
    in
    if List.all identity atPlace && passes (Query.count (Expect.equal (List.length expected)) count) then
        Expect.pass

    else
        Expect.equal expected (shownNumbers html)
