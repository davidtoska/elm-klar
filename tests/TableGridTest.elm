module TableGridTest exposing (suite)

{-| What `Klar.Table` tells assistive technology and the other surfaces around it:

  - a table whose rows take focus is a `grid` (a `treegrid` when rows expand),
    and a table that only shows data stays a plain table;
  - the row whose details are open elsewhere is marked (`currentRow`);
  - a money column sorts, filters, adds up and exports exactly (`money`);
  - Escape in the search box is used up only while there is text to clear.

-}

import Expect exposing (Expectation)
import Html exposing (Html)
import Html.Attributes as Attr
import Json.Encode as Encode
import Klar.Locale as Locale
import Klar.Money as Money exposing (Money)
import Klar.Remote exposing (Remote(..))
import Klar.Table as Table exposing (Filter(..))
import Support.Ids as Ids
import Support.Orders as Orders exposing (Msg(..), Order, expectRows, render)
import Test exposing (Test, describe, test)
import Test.Html.Event as Event
import Test.Html.Query as Query
import Test.Html.Selector as Selector exposing (Selector)


suite : Test
suite =
    describe "Klar.Table for assistive technology"
        [ gridTests
        , currentRowTests
        , moneyTests
        , searchEscapeTests
        ]


start : Table.State String
start =
    Table.init "orders"


role : String -> Selector
role value =
    Selector.attribute (Attr.attribute "role" value)


aria : String -> String -> Selector
aria name value =
    Selector.attribute (Attr.attribute name value)


table : List (Table.Attribute String Order Msg) -> Table.State String -> Query.Single Msg
table attributes state =
    render attributes state
        |> Query.fromHtml
        |> Query.find [ Selector.tag "table" ]


firstRow : List (Table.Attribute String Order Msg) -> Table.State String -> Query.Single Msg
firstRow attributes state =
    render attributes state
        |> Query.fromHtml
        |> Query.find [ Selector.id "orders-row-0" ]



-- GRID


gridTests : Test
gridTests =
    let
        clickable =
            [ Table.onRowClick Opened ]
    in
    describe "grid semantics"
        [ test "a table that only shows data has no role of its own" <|
            \_ -> table [] start |> Query.hasNot [ role "grid" ]
        , test "and its cells have none either" <|
            \_ -> firstRow [] start |> Query.findAll [ role "gridcell" ] |> Query.count (Expect.equal 0)
        , test "rows that can be clicked make it a grid" <|
            \_ -> table clickable start |> Query.has [ role "grid" ]
        , test "every row of the grid is a row" <|
            \_ -> firstRow clickable start |> Query.has [ role "row" ]
        , test "the header row is a row with column headers" <|
            \_ ->
                render clickable start
                    |> Query.fromHtml
                    |> Query.find [ Selector.tag "thead" ]
                    |> Query.findAll [ role "columnheader" ]
                    |> Query.count (Expect.equal 8)
        , test "the first cell of a row is its row header" <|
            \_ -> firstRow clickable start |> Query.findAll [ role "rowheader" ] |> Query.first |> Query.has [ Selector.text "ORD-2001" ]
        , test "the other cells are grid cells" <|
            \_ -> firstRow clickable start |> Query.findAll [ role "gridcell" ] |> Query.count (Expect.equal 7)
        , test "a selectable grid allows several rows to be selected" <|
            \_ -> table [ Table.selectable ] start |> Query.has [ role "grid", aria "aria-multiselectable" "true" ]
        , test "a grid that cannot select does not say it can" <|
            \_ -> table clickable start |> Query.hasNot [ aria "aria-multiselectable" "true" ]
        , test "rows that expand make it a tree grid" <|
            \_ -> table [ Table.expandedRow (\order -> Html.text order.city) ] start |> Query.has [ role "treegrid" ]
        , test "a closed row of the tree grid says so itself" <|
            \_ -> firstRow [ Table.expandedRow (\order -> Html.text order.city) ] start |> Query.has [ aria "aria-expanded" "false", aria "aria-level" "1" ]
        , test "an open row says it is open, and its details are a row one level down" <|
            \_ ->
                let
                    attributes =
                        [ Table.expandedRow (\order -> Html.text ("Details of " ++ order.number)) ]

                    opened =
                        Table.expand Ids.strings "ORD-2001" start
                in
                Expect.all
                    [ \_ -> firstRow attributes opened |> Query.has [ aria "aria-expanded" "true" ]
                    , \_ ->
                        render attributes opened
                            |> Query.fromHtml
                            |> Query.find [ Selector.id "orders-detail-0" ]
                            |> Query.has [ role "row", aria "aria-level" "2" ]
                    , \_ ->
                        render attributes opened
                            |> Query.fromHtml
                            |> Query.find [ Selector.id "orders-detail-0" ]
                            |> Query.children [ role "gridcell" ]
                            |> Query.count (Expect.equal 1)
                    ]
                    ()
        , test "the empty state of a grid is a row with one cell" <|
            \_ ->
                render (Table.remote (Loaded []) :: clickable) start
                    |> Query.fromHtml
                    |> Query.find [ Selector.class "klar-table__state-row" ]
                    |> Query.has [ role "row" ]
        ]



-- CURRENT ROW


currentRowTests : Test
currentRowTests =
    let
        attributes =
            [ Table.onRowClick Opened, Table.currentRow (\order -> order.number == "ORD-2002") ]
    in
    describe "Table.currentRow"
        [ test "the row whose details are open is the current one" <|
            \_ ->
                render attributes start
                    |> Query.fromHtml
                    |> Query.find [ Selector.id "orders-row-1" ]
                    |> Query.has [ aria "aria-current" "true", Selector.class "klar-table__row--current" ]
        , test "the other rows are not" <|
            \_ ->
                render attributes start
                    |> Query.fromHtml
                    |> Query.findAll [ aria "aria-current" "true" ]
                    |> Query.count (Expect.equal 1)
        , test "without currentRow no row is current" <|
            \_ ->
                render [ Table.onRowClick Opened ] start
                    |> Query.fromHtml
                    |> Query.findAll [ Selector.class "klar-table__row--current" ]
                    |> Query.count (Expect.equal 0)
        ]



-- MONEY


type alias Sale =
    { id : String, amount : Money }


nok : Int -> Money
nok minor =
    Money.fromMinor Money.nok minor |> Maybe.withDefault (Money.zero Money.nok)


eur : Int -> Money
eur minor =
    Money.fromMinor Money.eur minor |> Maybe.withDefault (Money.zero Money.eur)


sales : List Sale
sales =
    [ { id = "S-1", amount = nok 10 }
    , { id = "S-2", amount = nok 20 }
    , { id = "S-3", amount = nok 123450 }
    , { id = "S-4", amount = nok -500 }
    ]


saleTable : List (Table.Attribute String Sale Table.Msg) -> Table.State String -> Html Table.Msg
saleTable attributes state =
    Table.view identity
        ([ Table.columns
            [ Table.text (Table.columnId "id") "Sale" .id []
            , Table.money (Table.columnId "amount") "Amount" .amount [ Table.filterRange, Table.footerSum ]
            ]
         , Table.remote (Loaded sales)
         , Table.rowId Ids.strings .id
         , Table.ariaLabel "Sales"
         ]
            ++ attributes
        )
        state


shownRows : List (Table.Attribute String Sale Table.Msg) -> Table.State String -> Int -> Expectation
shownRows attributes state count =
    saleTable attributes state
        |> Query.fromHtml
        |> Query.findAll [ Selector.class "klar-table__row" ]
        |> Query.count (Expect.equal count)


footerHas : List (Table.Attribute String Sale Table.Msg) -> Table.State String -> String -> Expectation
footerHas attributes state value =
    saleTable attributes state
        |> Query.fromHtml
        |> Query.find [ Selector.tag "tfoot" ]
        |> Query.has [ Selector.text value ]


en : Money -> String
en =
    Money.toString Locale.en


moneyTests : Test
moneyTests =
    let
        amount =
            Table.columnId "amount"
    in
    describe "Table.money"
        [ test "an amount is shown with its currency code in the format of the locale" <|
            \_ -> saleTable [] start |> Query.fromHtml |> Query.has [ Selector.text (en (nok 123450)) ]
        , test "in Norwegian with the format of Norwegian" <|
            \_ -> saleTable [ Table.locale Locale.nb ] start |> Query.fromHtml |> Query.has [ Selector.text (Money.toString Locale.nb (nok 123450)) ]
        , test "it sorts by amount, a negative amount first" <|
            \_ ->
                saleTable [] (Table.setSort [ ( amount, Table.Ascending ) ] start)
                    |> Query.fromHtml
                    |> Query.find [ Selector.id "orders-row-0" ]
                    |> Query.has [ Selector.text "S-4" ]
        , test "the range filter is in whole units of the currency" <|
            \_ -> shownRows [] (Table.setFilter amount (Just (Between (Just 1) Nothing)) start) 1
        , test "the sum of every row" <|
            \_ -> footerHas [] start (en (nok 122980))
        , test "the sum is exact where a Float is not: two amounts of 45 035 996 273 704.95" <|
            \_ ->
                footerHas
                    [ Table.remote (Loaded [ { id = "a", amount = nok 4503599627370495 }, { id = "b", amount = nok 4503599627370495 } ]) ]
                    start
                    (en (nok 9007199254740990))
        , test "each currency has a total of its own, in the order they first appear" <|
            \_ ->
                footerHas [ Table.remote (Loaded ({ id = "S-5", amount = eur 30000 } :: sales)) ] start (en (eur 30000) ++ " · " ++ en (nok 122980))
        , test "the average is exact to the minor unit" <|
            \_ ->
                footerHas
                    [ Table.columns [ Table.money amount "Amount" .amount [ Table.footerAverage ] ]
                    , Table.remote (Loaded [ { id = "a", amount = nok 100 }, { id = "b", amount = nok 201 } ])
                    ]
                    start
                    (en (nok 151))
        , test "the CSV export writes the plain amount with the decimal separator of the locale" <|
            \_ ->
                let
                    attributes =
                        [ Table.exportCsv "sales.csv", Table.locale Locale.nb ]

                    click selectors state =
                        saleTable attributes state
                            |> Query.fromHtml
                            |> Query.find selectors
                            |> Event.simulate Event.click
                            |> Event.toResult
                in
                click [ Selector.id "orders-trigger-export" ] start
                    |> Result.map (\msg -> Tuple.first (Table.update msg start))
                    |> Result.andThen (click [ Selector.id "orders-popup-export-option-0" ])
                    |> Result.map Debug.toString
                    |> Expect.equal (Ok ("ExportClicked \"sales.csv\" " ++ Debug.toString "Sale;Amount\u{000D}\nS-1;0,10\u{000D}\nS-2;0,20\u{000D}\nS-3;1234,50\u{000D}\nS-4;-5,00"))
        , test "the search box skips amounts" <|
            \_ -> shownRows [ Table.searchable ] (Table.setSearch "1234" start) 0
        ]



-- ESCAPE IN THE SEARCH BOX


escape : ( String, Encode.Value )
escape =
    Event.custom "keydown"
        (Encode.object
            [ ( "key", Encode.string "Escape" )
            , ( "keyCode", Encode.int 27 )
            , ( "isComposing", Encode.bool False )
            , ( "ctrlKey", Encode.bool False )
            , ( "metaKey", Encode.bool False )
            , ( "altKey", Encode.bool False )
            , ( "shiftKey", Encode.bool False )
            ]
        )


searchEscapeTests : Test
searchEscapeTests =
    let
        searchBox state =
            render [ Table.searchable ] state
                |> Query.fromHtml
                |> Query.find [ Selector.class "klar-table__search" ]
    in
    describe "Escape in the search box"
        [ test "clears the text" <|
            \_ ->
                searchBox (Table.setSearch "acme" start)
                    |> Event.simulate escape
                    |> Event.toResult
                    |> Result.map (\msg -> Table.search (Orders.applyMsg msg (Table.setSearch "acme" start)))
                    |> Expect.equal (Ok "")
        , test "and is used up, so that a dialog around the table stays open" <|
            \_ ->
                searchBox (Table.setSearch "acme" start)
                    |> Event.simulate escape
                    |> Event.expectPreventDefault
        , test "an empty box leaves Escape to the dialog" <|
            \_ ->
                searchBox start
                    |> Event.simulate escape
                    |> Event.toResult
                    |> Expect.err
        ]
