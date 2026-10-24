module TableTest exposing (suite)

import Expect exposing (Expectation)
import Fuzz exposing (Fuzzer)
import Html exposing (Html)
import Html.Attributes as Attr
import Json.Encode as Encode
import Klar.Ids as Ids exposing (Ids)
import Klar.Menu as Menu
import Klar.Remote exposing (Remote(..))
import Klar.Table as Table exposing (Direction(..), Filter(..), Selection(..))
import Klar.Theme exposing (Density(..))
import Support.Ids as Ids
import Support.Orders as Orders exposing (Msg(..), Order, allOf, ariaLabelled, cannotUse, checkedBox, chosen, generated, keyDown, keyDownWith, passes, press, render, rowClickOn, send, sortButton, sortClick)
import Test exposing (Test, describe, fuzz, fuzzWith, test)
import Test.Html.Event as Event
import Test.Html.Query as Query
import Test.Html.Selector as Selector exposing (Selector)


suite : Test
suite =
    describe "Klar.Table (state and what the user does)"
        [ initTests
        , pageTests
        , searchStateTests
        , sortStateTests
        , filterStateTests
        , queryTests
        , selectionTests
        , ownIdTests
        , allMatchingTests
        , expandedColumnAndDensityStateTests
        , sortingByClickTests
        , pagingByClickTests
        , searchingByTypingTests
        , filterPopupTests
        , selectionByClickTests
        , rowKeyboardTests
        , rowClickTests
        , densityAndColumnChooserTests
        , expandByClickTests
        , propertyTests
        ]



-- HELPERS


check : String -> a -> a -> Test
check name expected actual =
    test name <| \_ -> Expect.equal expected actual


start : Table.State String
start =
    Table.init "orders"


type alias Step =
    Table.State String -> Result String (Table.State String)


{-| Do the steps one after the other, each on the table as the step before
left it. The first step that cannot be done ends it with its reason.
-}
after : List Step -> Table.State String -> Result String (Table.State String)
after steps state =
    List.foldl (\step result -> Result.andThen step result) (Ok state) steps


expectOk : (a -> Expectation) -> Result String a -> Expectation
expectOk toExpectation result =
    case result of
        Ok value ->
            toExpectation value

        Err problem ->
            Expect.fail problem


view : List (Table.Attribute String Order Msg) -> Table.State String -> Query.Single Msg
view attributes state =
    render attributes state |> Query.fromHtml


{-| Look at one element of the table.
-}
element : List (Table.Attribute String Order Msg) -> List Selector -> List Selector -> Table.State String -> Expectation
element attributes find expectations state =
    view attributes state
        |> Query.find find
        |> Query.has expectations


{-| Look at the element the table is made of itself, the one with its id.
-}
root : List (Table.Attribute String Order Msg) -> List Selector -> Table.State String -> Expectation
root attributes expectations state =
    view attributes state
        |> Query.has expectations


noElement : List (Table.Attribute String Order Msg) -> List Selector -> Table.State String -> Expectation
noElement attributes find state =
    view attributes state
        |> Query.findAll find
        |> Query.count (Expect.equal 0)


label : String -> Selector
label text =
    Selector.attribute (Attr.attribute "aria-label" text)


byId : String -> List Selector
byId id =
    [ Selector.id id ]


ariaAttribute : String -> String -> Selector
ariaAttribute name value =
    Selector.attribute (Attr.attribute name value)


{-| A button with this text in it. Buttons with a label are found by their text,
the way a user finds them.
-}
buttonWithText : String -> List Selector
buttonWithText text =
    [ Selector.tag "button", Selector.containing [ Selector.text text ] ]


clickOn : String -> ( String, Encode.Value )
clickOn =
    Orders.clickOn


tabStops : List (Table.Attribute String Order Msg) -> Table.State String -> List Int
tabStops attributes state =
    List.range 0 7
        |> List.filter
            (\index ->
                passes (view attributes state |> Query.find (byId (Orders.rowDomId index)) |> Query.has [ Selector.attribute (Attr.tabindex 0) ])
            )



-- THE STATE ALONE


initTests : Test
initTests =
    describe "init"
        [ check "a new table has nothing sorted, searched or filtered, on page 1 with 25 rows"
            { search = "", sort = [], filters = [], page = 1, pageSize = 25 }
            (Table.query start)
        , check "nothing is selected" (Selected []) (Table.selection Ids.strings start)
        , check "no ids are selected" [] (Table.selectedIds Ids.strings start)
        , check "nothing is selected, counted" 0 (Table.selectedCount 100 start)
        , check "nothing is expanded" [] (Table.expandedIds Ids.strings start)
        , check "the density is normal" Normal (Table.density start)
        , check "no column has been shown or hidden by the user" Nothing (Table.isColumnVisible (Table.columnId "city") start)
        , check "the accessors agree with the query"
            { search = "", sort = [], filters = [], page = 1, pageSize = 25 }
            { search = Table.search start, sort = Table.sort start, filters = Table.filters start, page = Table.page start, pageSize = Table.pageSize start }
        , test "the id of the table is the id of its element" <|
            \_ -> root [] [ Selector.id "orders", Selector.class "klar-table" ] start
        , test "another id is used for the element and its parts" <|
            \_ ->
                allOf
                    [ root [] [ Selector.id "invoices" ] (Table.init "invoices")
                    , element [] (byId "invoices-scroll") [] (Table.init "invoices")
                    ]
        ]


pageTests : Test
pageTests =
    describe "page and page size"
        [ check "setPage" 3 (Table.page (Table.setPage 3 start))
        , check "page 0 counts as the first page" 1 (Table.page (Table.setPage 0 start))
        , check "a negative page counts as the first page" 1 (Table.page (Table.setPage -7 start))
        , check "setPage leaves the rest of the query alone"
            { search = "a", sort = [ ( Table.columnId "total", Table.Descending ) ], filters = [ ( Table.columnId "city", Table.OneOf [ "Oslo" ] ) ], page = 4, pageSize = 10 }
            (start
                |> Table.setPageSize 10
                |> Table.setSearch "a"
                |> Table.setSort [ ( Table.columnId "total", Table.Descending ) ]
                |> Table.setFilter (Table.columnId "city") (Just (OneOf [ "Oslo" ]))
                |> Table.setPage 4
                |> Table.query
            )
        , check "setPageSize" 50 (Table.pageSize (Table.setPageSize 50 start))
        , check "setPageSize goes back to page 1" 1 (start |> Table.setPage 6 |> Table.setPageSize 50 |> Table.page)
        , check "a page size of 0 counts as 1" 1 (Table.pageSize (Table.setPageSize 0 start))
        , check "a negative page size counts as 1" 1 (Table.pageSize (Table.setPageSize -25 start))
        , check "a size that is not in the list of sizes is kept" 37 (Table.pageSize (Table.setPageSize 37 start))
        ]


searchStateTests : Test
searchStateTests =
    describe "setSearch"
        [ check "sets the search" "acme" (Table.search (Table.setSearch "acme" start))
        , check "the search in effect is trimmed" "acme" (Table.search (Table.setSearch "  acme \t" start))
        , check "the query has the trimmed search" "acme" (Table.query (Table.setSearch "  acme " start)).search
        , check "goes back to page 1" 1 (start |> Table.setPage 5 |> Table.setSearch "acme" |> Table.page)
        , check "an empty text removes the search" "" (start |> Table.setSearch "acme" |> Table.setSearch "" |> Table.search)
        , check "spaces only is no search" "" (Table.search (Table.setSearch "    " start))
        , check "the words inside are kept" "two  words" (Table.search (Table.setSearch " two  words " start))
        , test "the search box shows what was set, without trimming" <|
            \_ -> element [ Table.searchable ] (byId "orders-search") [ Selector.attribute (Attr.value "  acme ") ] (Table.setSearch "  acme " start)
        , check "the search does not touch the filters or the sort"
            ( [ ( Table.columnId "city", Table.OneOf [ "Oslo" ] ) ], [ ( Table.columnId "total", Table.Ascending ) ] )
            (let
                s =
                    start |> Table.setFilter (Table.columnId "city") (Just (OneOf [ "Oslo" ])) |> Table.setSort [ ( Table.columnId "total", Table.Ascending ) ] |> Table.setSearch "x"
             in
             ( Table.filters s, Table.sort s )
            )
        ]


sortStateTests : Test
sortStateTests =
    describe "setSort"
        [ check "sets the levels, primary first" [ ( Table.columnId "city", Table.Ascending ), ( Table.columnId "total", Table.Descending ) ] (Table.sort (Table.setSort [ ( Table.columnId "city", Table.Ascending ), ( Table.columnId "total", Table.Descending ) ] start))
        , check "goes back to page 1" 1 (start |> Table.setPage 3 |> Table.setSort [ ( Table.columnId "city", Table.Ascending ) ] |> Table.page)
        , check "an empty list removes the sort" [] (start |> Table.setSort [ ( Table.columnId "city", Table.Ascending ) ] |> Table.setSort [] |> Table.sort)
        , check "is shown in the query" [ ( Table.columnId "total", Table.Descending ) ] (Table.query (Table.setSort [ ( Table.columnId "total", Table.Descending ) ] start)).sort
        , check "ids that are not columns are stored as they are" [ ( Table.columnId "nope", Table.Ascending ) ] (Table.sort (Table.setSort [ ( Table.columnId "nope", Table.Ascending ) ] start))
        ]


filterStateTests : Test
filterStateTests =
    describe "setFilter and clearFilters"
        [ check "sets a filter" [ ( Table.columnId "city", Table.OneOf [ "Oslo" ] ) ] (Table.filters (Table.setFilter (Table.columnId "city") (Just (OneOf [ "Oslo" ])) start))
        , check "goes back to page 1" 1 (start |> Table.setPage 3 |> Table.setFilter (Table.columnId "city") (Just (Contains "o")) |> Table.page)
        , check "the filters are ordered by column id"
            [ ( Table.columnId "city", Table.Contains "o" ), ( Table.columnId "customer", Table.Contains "a" ), ( Table.columnId "total", Table.Between (Just 1) Nothing ) ]
            (start
                |> Table.setFilter (Table.columnId "total") (Just (Between (Just 1) Nothing))
                |> Table.setFilter (Table.columnId "city") (Just (Contains "o"))
                |> Table.setFilter (Table.columnId "customer") (Just (Contains "a"))
                |> Table.filters
            )
        , check "a second filter on the same column replaces the first" [ ( Table.columnId "city", Table.Contains "b" ) ] (start |> Table.setFilter (Table.columnId "city") (Just (Contains "a")) |> Table.setFilter (Table.columnId "city") (Just (Contains "b")) |> Table.filters)
        , check "Nothing removes the filter" [ ( Table.columnId "total", Table.Contains "x" ) ] (start |> Table.setFilter (Table.columnId "city") (Just (Contains "a")) |> Table.setFilter (Table.columnId "total") (Just (Contains "x")) |> Table.setFilter (Table.columnId "city") Nothing |> Table.filters)
        , check "removing a filter that is not there changes nothing" [] (Table.filters (Table.setFilter (Table.columnId "city") Nothing start))
        , check "removing a filter also goes back to page 1" 1 (start |> Table.setFilter (Table.columnId "city") (Just (Contains "a")) |> Table.setPage 4 |> Table.setFilter (Table.columnId "city") Nothing |> Table.page)
        , check "a filter for a column that does not exist is stored" [ ( Table.columnId "nope", Table.Contains "a" ) ] (Table.filters (Table.setFilter (Table.columnId "nope") (Just (Contains "a")) start))
        , check "clearFilters removes the search and all filters"
            ( "", [] )
            (start
                |> Table.setSearch "acme"
                |> Table.setFilter (Table.columnId "city") (Just (Contains "a"))
                |> Table.setFilter (Table.columnId "total") (Just (Between Nothing (Just 3)))
                |> Table.clearFilters
                |> (\s -> ( Table.search s, Table.filters s ))
            )
        , check "clearFilters goes back to page 1" 1 (start |> Table.setSearch "a" |> Table.setPage 3 |> Table.clearFilters |> Table.page)
        , check "clearFilters leaves the sort, the page size and the selection"
            ( [ ( Table.columnId "total", Table.Ascending ) ], 10, [ "ORD-2001" ] )
            (start
                |> Table.setSort [ ( Table.columnId "total", Table.Ascending ) ]
                |> Table.setPageSize 10
                |> Table.setSelected Ids.strings [ "ORD-2001" ] True
                |> Table.setFilter (Table.columnId "city") (Just (Contains "a"))
                |> Table.clearFilters
                |> (\s -> ( Table.sort s, Table.pageSize s, Table.selectedIds Ids.strings s ))
            )
        , test "the header says that a filter is active" <|
            \_ ->
                element []
                    (byId "orders-trigger-filter-city")
                    [ label "Filter City (filter active)" ]
                    (Table.setFilter (Table.columnId "city") (Just (OneOf [ "Oslo" ])) start)
        , test "and that it is not, after the filter was removed" <|
            \_ ->
                element []
                    (byId "orders-trigger-filter-city")
                    [ label "Filter City" ]
                    (start |> Table.setFilter (Table.columnId "city") (Just (OneOf [ "Oslo" ])) |> Table.setFilter (Table.columnId "city") Nothing)
        , test "a count of the active filters is shown" <|
            \_ ->
                element []
                    (byId "orders-trigger-filters")
                    [ Selector.text "2 filters active" ]
                    (start |> Table.setFilter (Table.columnId "city") (Just (OneOf [ "Oslo" ])) |> Table.setFilter (Table.columnId "customer") (Just (Contains "a")))
        ]



-- QUERY AND setQuery


savedQuery : Table.Query
savedQuery =
    { search = "acme"
    , sort = [ ( Table.columnId "total", Table.Descending ), ( Table.columnId "city", Table.Ascending ) ]
    , filters = [ ( Table.columnId "city", Table.OneOf [ "Oslo", "Bergen" ] ), ( Table.columnId "total", Table.Between (Just 10) Nothing ) ]
    , page = 3
    , pageSize = 10
    }


queryTests : Test
queryTests =
    describe "query and setQuery"
        [ check "a saved query is restored as it was" savedQuery (Table.query (Table.setQuery savedQuery start))
        , check "restoring a query replaces all the settings that are part of it"
            savedQuery
            (start
                |> Table.setSearch "other"
                |> Table.setSort [ ( Table.columnId "items", Table.Ascending ) ]
                |> Table.setFilter (Table.columnId "customer") (Just (Contains "x"))
                |> Table.setPageSize 100
                |> Table.setQuery savedQuery
                |> Table.query
            )
        , check "a page below 1 becomes 1" 1 (Table.query (Table.setQuery { savedQuery | page = 0 } start)).page
        , check "a negative page becomes 1" 1 (Table.query (Table.setQuery { savedQuery | page = -3 } start)).page
        , check "a page size below 1 becomes 1" 1 (Table.query (Table.setQuery { savedQuery | pageSize = 0 } start)).pageSize
        , check "the search in the query is trimmed" "acme" (Table.query (Table.setQuery { savedQuery | search = "  acme  " } start)).search
        , check "the filters come back ordered by column id"
            [ ( Table.columnId "a", Table.Contains "1" ), ( Table.columnId "b", Table.Contains "2" ), ( Table.columnId "c", Table.Contains "3" ) ]
            (Table.query (Table.setQuery { savedQuery | filters = [ ( Table.columnId "c", Table.Contains "3" ), ( Table.columnId "a", Table.Contains "1" ), ( Table.columnId "b", Table.Contains "2" ) ] } start)).filters
        , check "when a column is given twice the last filter wins"
            [ ( Table.columnId "a", Table.Contains "2" ) ]
            (Table.query (Table.setQuery { savedQuery | filters = [ ( Table.columnId "a", Table.Contains "1" ), ( Table.columnId "a", Table.Contains "2" ) ] } start)).filters
        , test "the search box shows the restored search, untrimmed" <|
            \_ -> element [ Table.searchable ] (byId "orders-search") [ Selector.attribute (Attr.value " acme") ] (Table.setQuery { savedQuery | search = " acme" } start)
        , test "the headers show the restored filters" <|
            \_ -> element [] (byId "orders-trigger-filter-total") [ label "Filter Total (filter active)" ] (Table.setQuery savedQuery start)
        , check "selected rows stay selected" [ "ORD-2002" ] (start |> Table.setSelected Ids.strings [ "ORD-2002" ] True |> Table.setQuery savedQuery |> Table.selectedIds Ids.strings)
        , check "selection, expansion, columns and density are not part of the query"
            True
            (Table.query (start |> Table.setSelected Ids.strings [ "a" ] True |> Table.setExpanded Ids.strings "a" True |> Table.setDensity Compact |> Table.setColumnVisible (Table.columnId "city") False)
                == Table.query start
            )
        , -- Was a bug: a range filter with its bounds the wrong way round matched nothing when
          -- it was restored with setFilter or setQuery, but the same two numbers typed into the
          -- filter popover mean "from 50 to 80" (as in Rule.matches). The next unrelated edit
          -- then silently turned the restored filter into (50, 80) and went back to page 1.
          test "a restored range with its bounds the wrong way round means the same range" <|
            \_ ->
                -- the totals 52, 75 and 75 are the ones between 50 and 80
                Orders.expectRows [ "ORD-2002", "ORD-2005", "ORD-2008" ]
                    (render [] (start |> Table.setFilter (Table.columnId "total") (Just (Between (Just 80) (Just 50)))))
        , check "the query reads from the state: two tables with the same settings have equal queries"
            True
            (Table.query (start |> Table.setSearch "a" |> Table.setPage 2) == Table.query (start |> Table.setPage 2 |> Table.setSearch "a" |> Table.setPage 2))
        ]



-- SELECTION


type RowNo
    = RowNo Int


rowNos : Ids RowNo
rowNos =
    Ids.make
        { toKey = \(RowNo n) -> "no-" ++ String.fromInt n
        , fromKey =
            \key ->
                if String.startsWith "no-" key then
                    Maybe.map RowNo (String.toInt (String.dropLeft 3 key))

                else
                    Nothing
        }


{-| How ids were written in an older version of the app (a saved view may still hold them).
-}
oldNos : Ids RowNo
oldNos =
    Ids.make { toKey = \(RowNo n) -> "old-" ++ String.fromInt n, fromKey = always Nothing }


ownIdTests : Test
ownIdTests =
    let
        numbered : Table.State RowNo
        numbered =
            Table.init "orders"
    in
    describe "an id type of the app's own (RowIds)"
        [ check "the selection comes back in the app's type, ordered by key as text" [ RowNo 10, RowNo 2 ] (numbered |> Table.setSelected rowNos [ RowNo 10, RowNo 2 ] True |> Table.selectedIds rowNos)
        , check "isSelected takes the app's type"
            ( True, False )
            (let
                s =
                    Table.setSelected rowNos [ RowNo 2 ] True numbered
             in
             ( Table.isSelected rowNos (RowNo 2) s, Table.isSelected rowNos (RowNo 3) s )
            )
        , check "the selection as a value" (Selected [ RowNo 1 ]) (numbered |> Table.setSelected rowNos [ RowNo 1 ] True |> Table.selection rowNos)
        , check "expanded rows come back in the app's type" [ RowNo 7 ] (numbered |> Table.setExpanded rowNos (RowNo 7) True |> Table.expandedIds rowNos)
        , check "a key the app cannot read is left out" [] (numbered |> Table.setSelected oldNos [ RowNo 1 ] True |> Table.selectedIds rowNos)
        , check "intIds keeps whole numbers" [ 1, 3 ] (Table.init "orders" |> Table.setSelected Ids.int [ 3, 1 ] True |> Table.selectedIds Ids.int)
        , check "stringIds keeps text as it is" [ "a", "b" ] (Table.init "orders" |> Table.setSelected Ids.string [ "b", "a" ] True |> Table.selectedIds Ids.string)
        , check "a state of the app's type compares with ==" True (Table.setSelected rowNos [ RowNo 1 ] True numbered == Table.setSelected rowNos [ RowNo 1 ] True numbered)
        ]


selectionTests : Test
selectionTests =
    describe "selection (setSelected, clearSelection ...)"
        [ check "select some rows" [ "a", "b" ] (Table.selectedIds Ids.strings (Table.setSelected Ids.strings [ "a", "b" ] True start))
        , check "the ids come back sorted, whatever the order they were selected in" [ "a", "b", "c" ] (Table.selectedIds Ids.strings (start |> Table.setSelected Ids.strings [ "c" ] True |> Table.setSelected Ids.strings [ "a", "b" ] True))
        , check "the selection as a value" (Selected [ "a", "b" ]) (Table.selection Ids.strings (Table.setSelected Ids.strings [ "b", "a" ] True start))
        , check "selecting twice selects once" [ "a" ] (Table.selectedIds Ids.strings (start |> Table.setSelected Ids.strings [ "a" ] True |> Table.setSelected Ids.strings [ "a", "a" ] True))
        , check "deselect some rows" [ "b" ] (Table.selectedIds Ids.strings (start |> Table.setSelected Ids.strings [ "a", "b" ] True |> Table.setSelected Ids.strings [ "a" ] False))
        , check "deselecting a row that is not selected changes nothing" [ "a" ] (Table.selectedIds Ids.strings (start |> Table.setSelected Ids.strings [ "a" ] True |> Table.setSelected Ids.strings [ "z" ] False))
        , check "selecting nothing changes nothing" [ "a" ] (Table.selectedIds Ids.strings (start |> Table.setSelected Ids.strings [ "a" ] True |> Table.setSelected Ids.strings [] True))
        , check "isSelected"
            ( True, False )
            (let
                s =
                    Table.setSelected Ids.strings [ "a" ] True start
             in
             ( Table.isSelected Ids.strings "a" s, Table.isSelected Ids.strings "b" s )
            )
        , check "isSelected is exact" False (Table.isSelected Ids.strings "A" (Table.setSelected Ids.strings [ "a" ] True start))
        , check "selectedCount counts the selected rows, whatever number it is given"
            ( 2, 2, 2 )
            (let
                s =
                    Table.setSelected Ids.strings [ "a", "b" ] True start
             in
             ( Table.selectedCount 0 s, Table.selectedCount 2 s, Table.selectedCount 5000 s )
            )
        , check "clearSelection" [] (start |> Table.setSelected Ids.strings [ "a", "b" ] True |> Table.clearSelection |> Table.selectedIds Ids.strings)
        , check "an id that looks like a number is a text, sorted as one" [ "10", "9" ] (Table.selectedIds Ids.strings (Table.setSelected Ids.strings [ "9", "10" ] True start))
        , check "a selection does not change the query" (Table.query start) (Table.query (Table.setSelected Ids.strings [ "a" ] True start))
        , check "paging does not change the selection" [ "a" ] (start |> Table.setSelected Ids.strings [ "a" ] True |> Table.setPage 4 |> Table.setPageSize 10 |> Table.selectedIds Ids.strings)
        , check "sorting does not change the selection" [ "a" ] (start |> Table.setSelected Ids.strings [ "a" ] True |> Table.setSort [ ( Table.columnId "city", Table.Ascending ) ] |> Table.selectedIds Ids.strings)
        , check "a new search keeps the rows that were picked one by one" [ "a" ] (start |> Table.setSelected Ids.strings [ "a" ] True |> Table.setSearch "x" |> Table.selectedIds Ids.strings)
        ]


{-| Server mode: 120 rows match, 25 of them are on the page.
-}
serverAttributes : List (Table.Attribute String Order Msg)
serverAttributes =
    [ Table.server { total = 120 }
    , Table.rows (Loaded (generated 25))
    , Table.selectable
    ]


{-| The header checkbox selects the 25 rows of the page, and the bar then
offers "Select all 120 matching".
-}
selectAllMatching : Step
selectAllMatching =
    \state ->
        after
            [ press serverAttributes (byId "orders-select-page") (checkedBox True)
            , press serverAttributes [ Selector.class "klar-table__bulk-prompt", Selector.tag "button" ] Event.click
            ]
            state


{-| Prepare the table, choose "all matching", make a change, and say what is
selected.
-}
selectionAfter : (Table.State String -> Table.State String) -> (Table.State String -> Table.State String) -> Result String (Selection String)
selectionAfter prepare change =
    selectAllMatching (prepare start)
        |> Result.map (change >> Table.selection Ids.strings)


allMatchingTests : Test
allMatchingTests =
    let
        everything =
            Ok (AllMatching { except = [] })

        ended =
            Ok (Selected [])
    in
    describe "'Select all N matching' (server mode)"
        [ test "the header checkbox selects the 25 rows of the page" <|
            \_ ->
                press serverAttributes (byId "orders-select-page") (checkedBox True) start
                    |> Result.map (Table.selectedIds Ids.strings)
                    |> Expect.equal (Ok (List.map .number (generated 25) |> List.sort))
        , test "the bar then offers to select all 120 matching rows" <|
            \_ ->
                press serverAttributes (byId "orders-select-page") (checkedBox True) start
                    |> expectOk (\state -> element serverAttributes [ Selector.class "klar-table__bulk-prompt" ] [ Selector.text "Select all 120 matching" ] state)
        , check "choosing it selects everything that matches" everything (selectionAfter identity identity)
        , check "the list of ids is then empty" (Ok []) (selectAllMatching start |> Result.map (Table.selectedIds Ids.strings))
        , check "and the count is the number of matching rows" (Ok 120) (selectAllMatching start |> Result.map (Table.selectedCount 120))
        , check "every id counts as selected" (Ok ( True, True )) (selectAllMatching start |> Result.map (\s -> ( Table.isSelected Ids.strings "ORD-3001" s, Table.isSelected Ids.strings "anything at all" s )))
        , check "deselecting a row adds it to the exceptions" (Ok (AllMatching { except = [ "ORD-3001" ] })) (selectionAfter identity (Table.setSelected Ids.strings [ "ORD-3001" ] False))
        , check "and the count goes down by one" (Ok 119) (selectAllMatching start |> Result.map (Table.setSelected Ids.strings [ "ORD-3001" ] False >> Table.selectedCount 120))
        , check "the excepted row is not selected, the others are" (Ok ( False, True )) (selectAllMatching start |> Result.map (Table.setSelected Ids.strings [ "ORD-3001" ] False >> (\s -> ( Table.isSelected Ids.strings "ORD-3001" s, Table.isSelected Ids.strings "ORD-3002" s ))))
        , check "selecting the row again removes the exception" everything (selectionAfter identity (Table.setSelected Ids.strings [ "ORD-3001" ] False >> Table.setSelected Ids.strings [ "ORD-3001" ] True))
        , check "the count never goes below 0" (Ok 0) (selectAllMatching start |> Result.map (Table.setSelected Ids.strings [ "a", "b", "c" ] False >> Table.selectedCount 0))
        , check "clearSelection ends it" ended (selectionAfter identity Table.clearSelection)
        , check "a changed search ends it" ended (selectionAfter identity (Table.setSearch "new"))
        , check "the same search keeps it" everything (selectionAfter (Table.setSearch "abc") (Table.setSearch "abc"))
        , check "the same search with other spaces keeps it" everything (selectionAfter (Table.setSearch "abc") (Table.setSearch "  abc "))
        , check "a changed filter ends it" ended (selectionAfter identity (Table.setFilter (Table.columnId "city") (Just (Contains "o"))))
        , check "the same filter keeps it" everything (selectionAfter (Table.setFilter (Table.columnId "city") (Just (Contains "o"))) (Table.setFilter (Table.columnId "city") (Just (Contains "o"))))
        , check "removing a filter ends it" ended (selectionAfter (Table.setFilter (Table.columnId "city") (Just (Contains "o"))) (Table.setFilter (Table.columnId "city") Nothing))
        , check "clearFilters keeps it when there was nothing to clear" everything (selectionAfter identity Table.clearFilters)
        , check "clearFilters ends it when there was a search" ended (selectionAfter (Table.setSearch "x") Table.clearFilters)
        , check "paging, the page size and the sort keep it" everything (selectionAfter identity (Table.setPage 3 >> Table.setPageSize 50 >> Table.setSort [ ( Table.columnId "total", Table.Ascending ) ]))
        , check "setQuery with another search ends it" ended (selectionAfter identity (Table.setQuery { search = "x", sort = [], filters = [], page = 1, pageSize = 25 }))
        , check "setQuery with another filter ends it" ended (selectionAfter identity (Table.setQuery { search = "", sort = [], filters = [ ( Table.columnId "city", Table.Contains "o" ) ], page = 1, pageSize = 25 }))
        , check "setQuery with the same search and filters keeps it" everything (selectionAfter identity (Table.setQuery { search = "", sort = [ ( Table.columnId "city", Table.Ascending ) ], filters = [], page = 2, pageSize = 10 }))
        , test "the bar says that all matching rows are selected" <|
            \_ ->
                selectAllMatching start
                    |> expectOk (\state -> element serverAttributes [ Selector.class "klar-table__bulk-prompt" ] [ Selector.text "All 120 matching rows are selected." ] state)
        , test "the bar counts them" <|
            \_ ->
                selectAllMatching start
                    |> expectOk (\state -> element serverAttributes [ Selector.class "klar-table__bulk-count" ] [ Selector.text "120 selected" ] state)
        , test "and counts without the exceptions" <|
            \_ ->
                selectAllMatching start
                    |> Result.map (Table.setSelected Ids.strings [ "ORD-3001", "ORD-3002" ] False)
                    |> expectOk (\state -> element serverAttributes [ Selector.class "klar-table__bulk-count" ] [ Selector.text "118 selected" ] state)
        ]


expandedColumnAndDensityStateTests : Test
expandedColumnAndDensityStateTests =
    describe "expanded rows, hidden columns and density"
        [ check "setExpanded opens a row" [ "a" ] (Table.expandedIds Ids.strings (Table.setExpanded Ids.strings "a" True start))
        , check "isExpanded"
            ( True, False )
            (let
                s =
                    Table.setExpanded Ids.strings "a" True start
             in
             ( Table.isExpanded Ids.strings "a" s, Table.isExpanded Ids.strings "b" s )
            )
        , check "setExpanded False closes it" [] (start |> Table.setExpanded Ids.strings "a" True |> Table.setExpanded Ids.strings "a" False |> Table.expandedIds Ids.strings)
        , check "the ids come back sorted" [ "a", "b" ] (start |> Table.setExpanded Ids.strings "b" True |> Table.setExpanded Ids.strings "a" True |> Table.expandedIds Ids.strings)
        , check "isColumnVisible remembers a choice"
            ( Just False, Just True, Nothing )
            (let
                s =
                    start |> Table.setColumnVisible (Table.columnId "city") False |> Table.setColumnVisible (Table.columnId "items") True
             in
             ( Table.isColumnVisible (Table.columnId "city") s, Table.isColumnVisible (Table.columnId "items") s, Table.isColumnVisible (Table.columnId "total") s )
            )
        , check "the last choice wins" (Just True) (start |> Table.setColumnVisible (Table.columnId "city") False |> Table.setColumnVisible (Table.columnId "city") True |> Table.isColumnVisible (Table.columnId "city"))
        , check "setDensity" Compact (Table.density (Table.setDensity Compact start))
        , check "setDensity Comfortable" Comfortable (Table.density (Table.setDensity Comfortable start))
        , test "the density is a class on the table" <|
            \_ -> root [] [ Selector.class "klar-table--comfortable" ] (Table.setDensity Comfortable start)
        ]



-- CLICKING HEADERS


sortOf : Result String (Table.State String) -> Result String (List ( Table.ColumnId, Direction ))
sortOf =
    Result.map Table.sort


ariaSort : String -> String -> Table.State String -> Expectation
ariaSort title value state =
    element [ Table.multiSort ] [ Selector.tag "th", Selector.containing [ Selector.text title ] ] [ ariaAttribute "aria-sort" value ] state


sortingByClickTests : Test
sortingByClickTests =
    let
        click title =
            press [] (sortButton title) (sortClick False)

        shiftClick title =
            press [ Table.multiSort ] (sortButton title) (sortClick True)

        plainClick title =
            press [ Table.multiSort ] (sortButton title) (sortClick False)
    in
    describe "clicking a column header"
        [ check "the first click sorts ascending" (Ok [ ( Table.columnId "total", Table.Ascending ) ]) (sortOf (after [ click "Total" ] start))
        , check "the second click sorts descending" (Ok [ ( Table.columnId "total", Table.Descending ) ]) (sortOf (after [ click "Total", click "Total" ] start))
        , check "the third click takes the sort away" (Ok []) (sortOf (after [ click "Total", click "Total", click "Total" ] start))
        , check "the fourth click starts again" (Ok [ ( Table.columnId "total", Table.Ascending ) ]) (sortOf (after [ click "Total", click "Total", click "Total", click "Total" ] start))
        , check "another column replaces the first" (Ok [ ( Table.columnId "customer", Table.Ascending ) ]) (sortOf (after [ click "Total", click "Customer" ] start))
        , check "a click goes back to page 1" (Ok 1) (after [ click "Total" ] (Table.setPage 3 start) |> Result.map Table.page)
        , check "without multiSort the Shift key changes nothing" (Ok [ ( Table.columnId "total", Table.Ascending ) ]) (sortOf (after [ press [] (sortButton "Total") (sortClick True) ] start))
        , check "with multiSort a Shift click adds a level" (Ok [ ( Table.columnId "total", Table.Ascending ), ( Table.columnId "customer", Table.Ascending ) ]) (sortOf (after [ shiftClick "Total", shiftClick "Customer" ] start))
        , check "a second Shift click on a level turns it round" (Ok [ ( Table.columnId "total", Table.Ascending ), ( Table.columnId "customer", Table.Descending ) ]) (sortOf (after [ shiftClick "Total", shiftClick "Customer", shiftClick "Customer" ] start))
        , check "a third Shift click takes the level away" (Ok [ ( Table.columnId "total", Table.Ascending ) ]) (sortOf (after [ shiftClick "Total", shiftClick "Customer", shiftClick "Customer", shiftClick "Customer" ] start))
        , check "a Shift click on the first level turns it round and keeps the others" (Ok [ ( Table.columnId "total", Table.Descending ), ( Table.columnId "customer", Table.Ascending ) ]) (sortOf (after [ shiftClick "Total", shiftClick "Customer", shiftClick "Total" ] start))
        , check "a Shift click on the only level takes it away when it comes to that" (Ok []) (sortOf (after [ shiftClick "Total", shiftClick "Total", shiftClick "Total" ] start))
        , check "a plain click when several levels are set starts a new sort" (Ok [ ( Table.columnId "items", Table.Ascending ) ]) (sortOf (after [ shiftClick "Total", shiftClick "Customer", plainClick "Items" ] start))
        , check "a plain click on a column of a multi-column sort gives a one-column sort" (Ok [ ( Table.columnId "customer", Table.Ascending ) ]) (sortOf (after [ shiftClick "Total", shiftClick "Customer", plainClick "Customer" ] start))
        , check "a plain click after a Shift click on one column cycles it" (Ok [ ( Table.columnId "total", Table.Descending ) ]) (sortOf (after [ shiftClick "Total", plainClick "Total" ] start))
        , test "a header is announced as sorted ascending" <|
            \_ -> click "Total" start |> expectOk (ariaSort "Total" "ascending")
        , test "a header is announced as sorted descending" <|
            \_ -> after [ click "Total", click "Total" ] start |> expectOk (ariaSort "Total" "descending")
        , test "the other headers say they are not sorted" <|
            \_ -> click "Total" start |> expectOk (ariaSort "Customer" "none")
        , test "after the third click no header is sorted" <|
            \_ -> after [ click "Total", click "Total", click "Total" ] start |> expectOk (ariaSort "Total" "none")
        , test "in a multi-column sort only the first level is announced" <|
            \_ ->
                after [ shiftClick "Total", shiftClick "Customer" ] start
                    |> expectOk (\s -> allOf [ ariaSort "Total" "ascending" s, ariaSort "Customer" "none" s ])
        , test "the sort order is numbered in the headers of a multi-column sort" <|
            \_ ->
                after [ shiftClick "Total", shiftClick "Customer" ] start
                    |> expectOk (\s -> element [ Table.multiSort ] [ Selector.tag "th", Selector.containing [ Selector.text "Customer" ] ] [ Selector.class "klar-table__sort-order", Selector.containing [ Selector.text "2" ] ] s)
        , test "a column that cannot be sorted has no button and no aria-sort" <|
            \_ ->
                allOf
                    [ noElement [ Table.columns [ Table.text (Table.columnId "number") "Order" .number [ Table.unsortable ] ] ] (sortButton "Order") start
                    , noElement [ Table.columns [ Table.text (Table.columnId "number") "Order" .number [ Table.unsortable ] ] ] [ Selector.tag "th", Selector.attribute (Attr.attribute "aria-sort" "none") ] start
                    ]
        ]



-- PAGING


pagingAttributes : List (Table.Attribute String Order Msg)
pagingAttributes =
    [ Table.rows (Loaded (generated 120)) ]


pagingByClickTests : Test
pagingByClickTests =
    let
        page n =
            press pagingAttributes (ariaLabelled ("Page " ++ String.fromInt n)) Event.click

        pressing text =
            press pagingAttributes (ariaLabelled text) Event.click

        pageOf =
            Result.map Table.page

        sizeSelect value =
            press pagingAttributes (byId "orders-pagination-size") (chosen value)

        jump value =
            press pagingAttributes (byId "orders-pagination-jump") (chosen value)
    in
    describe "paging with the controls in the footer"
        [ check "a page number" (Ok 2) (pageOf (after [ page 2 ] start))
        , check "next" (Ok 2) (pageOf (after [ pressing "Next page" ] start))
        , check "last" (Ok 5) (pageOf (after [ pressing "Last page" ] start))
        , check "first" (Ok 1) (pageOf (after [ pressing "Last page", pressing "First page" ] start))
        , check "previous" (Ok 2) (pageOf (after [ pressing "Previous page" ] (Table.setPage 3 start)))
        , test "a page after the last is shown as the last" <|
            \_ -> element pagingAttributes [ ariaAttribute "aria-current" "page" ] [ label "Page 5" ] (Table.setPage 99 start)
        , test "the current page has no click handler" <|
            \_ -> cannotUse pagingAttributes (ariaLabelled "Page 1") Event.click start
        , test "'previous' on the first page does nothing" <|
            \_ -> cannotUse pagingAttributes (ariaLabelled "Previous page") Event.click start
        , test "'first' on the first page does nothing" <|
            \_ -> cannotUse pagingAttributes (ariaLabelled "First page") Event.click start
        , test "'next' on the last page does nothing" <|
            \_ -> cannotUse pagingAttributes (ariaLabelled "Next page") Event.click (Table.setPage 5 start)
        , test "'last' on the last page does nothing" <|
            \_ -> cannotUse pagingAttributes (ariaLabelled "Last page") Event.click (Table.setPage 5 start)
        , check "a new page keeps the sort" (Ok ( [ ( Table.columnId "total", Table.Descending ) ], 2 )) (after [ page 2 ] (Table.setSort [ ( Table.columnId "total", Table.Descending ) ] start) |> Result.map (\s -> ( Table.sort s, Table.page s )))
        , describe "rows per page"
            [ check "50 per page from page 3 of 25 keeps the first row in view: page 2" (Ok ( 50, 2 )) (after [ sizeSelect "50" ] (Table.setPage 3 start) |> Result.map (\s -> ( Table.pageSize s, Table.page s )))
            , check "10 per page from page 3 of 25 is page 6" (Ok ( 10, 6 )) (after [ sizeSelect "10" ] (Table.setPage 3 start) |> Result.map (\s -> ( Table.pageSize s, Table.page s )))
            , check "100 per page from page 2 of 25 is page 1" (Ok ( 100, 1 )) (after [ sizeSelect "100" ] (Table.setPage 2 start) |> Result.map (\s -> ( Table.pageSize s, Table.page s )))
            , check "the first page stays the first page" (Ok 1) (after [ sizeSelect "10" ] start |> pageOf)
            , test "a size that is not a number sends nothing" <|
                \_ -> cannotUse pagingAttributes (byId "orders-pagination-size") (chosen "many") start
            , test "the choices come from pageSizes, and the size in use is always one of them" <|
                \_ ->
                    view (Table.pageSizes [ 5, 15 ] :: pagingAttributes) start
                        |> Query.find (byId "orders-pagination-size")
                        |> Query.findAll [ Selector.tag "option" ]
                        |> Query.count (Expect.equal 3)
            , test "the size in use is selected" <|
                \_ ->
                    view pagingAttributes (Table.setPageSize 50 start)
                        |> Query.find (byId "orders-pagination-size")
                        |> Query.find [ Selector.tag "option", Selector.selected True ]
                        |> Query.has [ Selector.text "50" ]
            ]
        , describe "go to page"
            [ check "a page number" (Ok 4) (after [ jump "4" ] start |> pageOf)
            , check "a page past the last is the last" (Ok 5) (after [ jump "99" ] start |> pageOf)
            , check "page 0 is the first" (Ok 1) (after [ jump "0" ] (Table.setPage 3 start) |> pageOf)
            , check "a negative page is the first" (Ok 1) (after [ jump "-8" ] (Table.setPage 3 start) |> pageOf)
            , check "spaces around the number are fine" (Ok 3) (after [ jump " 3 " ] start |> pageOf)
            , test "text sends nothing" <|
                \_ -> cannotUse pagingAttributes (byId "orders-pagination-jump") (chosen "three") start
            , test "Enter in the box jumps and keeps a surrounding form from being submitted" <|
                \_ ->
                    let
                        enter =
                            Event.custom "keydown" (Encode.object [ ( "key", Encode.string "Enter" ), ( "target", Encode.object [ ( "value", Encode.string "4" ) ] ) ])

                        typed =
                            view pagingAttributes start
                                |> Query.find (byId "orders-pagination-jump")
                                |> Event.simulate enter
                    in
                    allOf
                        [ Event.expectPreventDefault typed
                        , press pagingAttributes (byId "orders-pagination-jump") enter start
                            |> Result.map Table.page
                            |> Expect.equal (Ok 4)
                        ]
            , test "another key in the box is left alone" <|
                \_ ->
                    cannotUse pagingAttributes
                        (byId "orders-pagination-jump")
                        (Event.custom "keydown" (Encode.object [ ( "key", Encode.string "a" ), ( "target", Encode.object [ ( "value", Encode.string "4" ) ] ) ]))
                        start
            , test "the box shows the page and the largest page" <|
                \_ -> element pagingAttributes (byId "orders-pagination-jump") [ Selector.attribute (Attr.max "5"), Selector.attribute (Attr.value "3") ] (Table.setPage 3 start)
            , test "a table of one page has no 'go to page'" <|
                \_ -> noElement [] (byId "orders-pagination-jump") start
            ]
        ]



-- TYPING IN THE SEARCH BOX


searchingByTypingTests : Test
searchingByTypingTests =
    let
        typeInSearch attributes text =
            press (Table.searchable :: attributes) (byId "orders-search") (Event.input text)

        server =
            [ Table.server { total = 120 }, Table.rows (Loaded (generated 25)) ]
    in
    describe "typing in the search box"
        [ check "in client mode the search takes effect at once" (Ok "ost") (after [ typeInSearch [] "ost" ] start |> Result.map Table.search)
        , check "the text is trimmed in the query" (Ok "ost") (after [ typeInSearch [] "  ost " ] start |> Result.map Table.search)
        , check "a new search goes back to page 1" (Ok 1) (after [ typeInSearch [] "o" ] (Table.setPage 3 start) |> Result.map Table.page)
        , check "emptying the box removes the search" (Ok "") (after [ typeInSearch [] "o", typeInSearch [] "" ] start |> Result.map Table.search)
        , check "in server mode the query waits for the pause" (Ok "") (after [ typeInSearch server "ost" ] start |> Result.map Table.search)
        , check "in server mode the page does not change before the pause" (Ok 3) (after [ typeInSearch server "ost" ] (Table.setPage 3 start) |> Result.map Table.page)
        , test "in server mode the box shows what was typed meanwhile" <|
            \_ ->
                after [ typeInSearch server "ost" ] start
                    |> expectOk (\s -> element (Table.searchable :: server) (byId "orders-search") [ Selector.attribute (Attr.value "ost") ] s)
        , check "searchDebounce 0 makes server mode take effect at once" (Ok "ost") (after [ typeInSearch (Table.searchDebounce 0 :: server) "ost" ] start |> Result.map Table.search)
        , check "searchDebounce can make client mode wait" (Ok "") (after [ typeInSearch [ Table.searchDebounce 200 ] "ost" ] start |> Result.map Table.search)
        , check "Escape in the box clears the search at once, also in server mode"
            (Ok "")
            (after
                [ \s -> Ok (Table.setSearch "ost" s)
                , press (Table.searchable :: server) [ Selector.class "klar-table__search" ] (keyDown "orders-search" "Escape")
                ]
                start
                |> Result.map Table.search
            )
        , test "the clear button of the box clears it" <|
            \_ ->
                press [ Table.searchable ] [ Selector.id "orders-search" ] (Event.input "x") start
                    |> Result.andThen (press [ Table.searchable ] [ Selector.class "klar-input__clear" ] Event.click)
                    |> Result.map Table.search
                    |> Expect.equal (Ok "")
        , test "the box has a name for screen readers and says how many rows it searches" <|
            \_ ->
                allOf
                    [ element [ Table.searchable ] (byId "orders-search") [ Selector.attribute (Attr.placeholder "Search 8 rows ...") ] start
                    , element [ Table.searchable ] (byId "orders-search-label") [ Selector.text "Search the table" ] start
                    ]
        , test "the placeholder in server mode does not claim a number of rows" <|
            \_ -> element (Table.searchable :: server) (byId "orders-search") [ Selector.attribute (Attr.placeholder "Search ...") ] start
        , test "searchPlaceholder replaces it and turns the box on" <|
            \_ -> element [ Table.searchPlaceholder "Find an order" ] (byId "orders-search") [ Selector.attribute (Attr.placeholder "Find an order") ] start
        , test "without searchable there is no box" <|
            \_ -> noElement [] (byId "orders-search") start
        ]



-- FILTER POPOVERS


openFilter : String -> Step
openFilter columnId =
    press [] (byId ("orders-trigger-filter-" ++ columnId)) Event.click


filterPopupTests : Test
filterPopupTests =
    let
        typeIn inputId text =
            press [] (byId inputId) (Event.input text)

        tick inputId value =
            press [] (byId inputId) (checkedBox value)

        filtersOf =
            Result.map Table.filters

        dialog =
            [ Selector.attribute (Attr.attribute "role" "dialog") ]

        server =
            [ Table.server { total = 120 }, Table.rows (Loaded (generated 25)) ]
    in
    describe "the filter popovers in the header"
        [ test "a click on the filter button opens a dialog named after the column" <|
            \_ ->
                openFilter "customer" start
                    |> expectOk (\s -> element [] dialog [ label "Filter: Customer" ] s)
        , test "the button says that it opened something" <|
            \_ ->
                openFilter "customer" start
                    |> expectOk (\s -> element [] (byId "orders-trigger-filter-customer") [ ariaAttribute "aria-expanded" "true", ariaAttribute "aria-haspopup" "dialog" ] s)
        , test "a closed popover says so" <|
            \_ -> element [] (byId "orders-trigger-filter-customer") [ ariaAttribute "aria-expanded" "false" ] start
        , test "no dialog is there while none is open" <|
            \_ -> noElement [] dialog start
        , test "only one popover is open at a time" <|
            \_ ->
                after [ openFilter "customer", openFilter "city" ] start
                    |> expectOk (\s -> view [] s |> Query.findAll dialog |> Query.count (Expect.equal 1))
        , test "Escape closes it" <|
            \_ ->
                after [ openFilter "customer", press [] [ Selector.class "klar-layer" ] (keyDown "" "Escape") ] start
                    |> expectOk (noElement [] dialog)
        , test "the Done button closes it" <|
            \_ ->
                after [ openFilter "customer", press [] (buttonWithText "Done") Event.click ] start
                    |> expectOk (noElement [] dialog)
        , test "a click outside it closes it" <|
            \_ ->
                after [ openFilter "customer", press [] [ Selector.class "klar-layer" ] (clickOn "somewhere-else") ] start
                    |> expectOk (noElement [] dialog)
        , test "a click inside it does not" <|
            \_ ->
                openFilter "customer" start
                    |> expectOk (\s -> cannotUse [] [ Selector.class "klar-layer" ] (clickOn "orders-popup-filter-customer") s)
        , test "Enter in the box closes it" <|
            \_ ->
                after [ openFilter "customer", press [] (byId "orders-filter-customer-text") (keyDown "orders-filter-customer-text" "Enter") ] start
                    |> expectOk (noElement [] dialog)
        , describe "text"
            [ check "typing sets a filter that contains the text" (Ok [ ( Table.columnId "customer", Table.Contains "ac" ) ]) (filtersOf (after [ openFilter "customer", typeIn "orders-filter-customer-text" "ac" ] start))
            , check "the text is trimmed" (Ok [ ( Table.columnId "customer", Table.Contains "ac" ) ]) (filtersOf (after [ openFilter "customer", typeIn "orders-filter-customer-text" "  ac " ] start))
            , check "emptying the box removes the filter" (Ok []) (filtersOf (after [ openFilter "customer", typeIn "orders-filter-customer-text" "ac", typeIn "orders-filter-customer-text" "" ] start))
            , check "spaces only is no filter" (Ok []) (filtersOf (after [ openFilter "customer", typeIn "orders-filter-customer-text" "   " ] start))
            , check "a new filter goes back to page 1" (Ok 1) (after [ openFilter "customer", typeIn "orders-filter-customer-text" "ac" ] (Table.setPage 3 start) |> Result.map Table.page)
            , test "the header button then says that the filter is active" <|
                \_ ->
                    after [ openFilter "customer", typeIn "orders-filter-customer-text" "ac" ] start
                        |> expectOk (\s -> element [] (byId "orders-trigger-filter-customer") [ label "Filter Customer (filter active)" ] s)
            , test "the box keeps what was typed, with its spaces" <|
                \_ ->
                    after [ openFilter "customer", typeIn "orders-filter-customer-text" " ac " ] start
                        |> expectOk (\s -> element [] (byId "orders-filter-customer-text") [ Selector.attribute (Attr.value " ac ") ] s)
            , test "the summary counts the filter" <|
                \_ ->
                    after [ openFilter "customer", typeIn "orders-filter-customer-text" "ac" ] start
                        |> expectOk (\s -> element [] (byId "orders-trigger-filters") [ Selector.text "1 filter active" ] s)
            , test "the summary does not count text that is only spaces" <|
                \_ ->
                    after [ openFilter "customer", typeIn "orders-filter-customer-text" "   " ] start
                        |> expectOk (noElement [] (byId "orders-trigger-filters"))
            , test "the Reset button is disabled until something is typed" <|
                \_ ->
                    openFilter "customer" start
                        |> expectOk (\s -> element [] (buttonWithText "Reset") [ Selector.disabled True ] s)
            , test "and can be used afterwards" <|
                \_ ->
                    after [ openFilter "customer", typeIn "orders-filter-customer-text" "ac" ] start
                        |> expectOk (\s -> element [] (buttonWithText "Reset") [ Selector.disabled False ] s)
            , check "in server mode the filter waits for the pause"
                (Ok [])
                (press server (byId "orders-trigger-filter-customer") Event.click start
                    |> Result.andThen (press server (byId "orders-filter-customer-text") (Event.input "ac"))
                    |> Result.map Table.filters
                )
            ]
        , describe "choices"
            [ -- the English order of the cities: Ålesund, Bergen, Oslo, Tromsø, Zürich
              check "ticking a value sets a filter" (Ok [ ( Table.columnId "city", Table.OneOf [ "Oslo" ] ) ]) (filtersOf (after [ openFilter "city", tick "orders-filter-city-option-2" True ] start))
            , check "ticking two values lists them in order" (Ok [ ( Table.columnId "city", Table.OneOf [ "Bergen", "Oslo" ] ) ]) (filtersOf (after [ openFilter "city", tick "orders-filter-city-option-2" True, tick "orders-filter-city-option-1" True ] start))
            , check "unticking a value removes it" (Ok [ ( Table.columnId "city", Table.OneOf [ "Bergen" ] ) ]) (filtersOf (after [ openFilter "city", tick "orders-filter-city-option-2" True, tick "orders-filter-city-option-1" True, tick "orders-filter-city-option-2" False ] start))
            , check "unticking the last value removes the filter" (Ok []) (filtersOf (after [ openFilter "city", tick "orders-filter-city-option-2" True, tick "orders-filter-city-option-2" False ] start))
            , check "a choice goes back to page 1" (Ok 1) (after [ openFilter "city", tick "orders-filter-city-option-2" True ] (Table.setPage 3 start) |> Result.map Table.page)
            , -- Oslo, Bergen and Trondheim are the cities of the rows of the page in server mode
              check "a choice applies at once, also in server mode"
                (Ok [ ( Table.columnId "city", Table.OneOf [ "Oslo" ] ) ])
                (press server (byId "orders-trigger-filter-city") Event.click start
                    |> Result.andThen (press server (byId "orders-filter-city-option-1") (checkedBox True))
                    |> Result.map Table.filters
                )
            , test "the values are listed in the order of the language" <|
                \_ ->
                    openFilter "city" start
                        |> expectOk
                            (\s ->
                                allOf
                                    [ element [] (byId "orders-popup-filter-city") [ Selector.text "Ålesund" ] s
                                    , view [] s |> Query.find (byId "orders-filter-city-option-0") |> Query.has [ Selector.attribute (Attr.checked False) ]
                                    ]
                            )
            , test "every value is listed once with the number of rows that have it" <|
                \_ ->
                    openFilter "city" start
                        |> expectOk
                            (\s ->
                                view [] s
                                    |> Query.find (byId "orders-popup-filter-city")
                                    |> Query.findAll [ Selector.class "klar-table__option-count" ]
                                    |> Expect.all
                                        [ Query.count (Expect.equal 5)
                                        , Query.index 2 >> Query.has [ Selector.text "3" ]
                                        ]
                            )
            , check "Select all ticks every value"
                (Ok [ ( Table.columnId "city", Table.OneOf [ "Bergen", "Oslo", "Tromsø", "Zürich", "Ålesund" ] ) ])
                (filtersOf (after [ openFilter "city", press [] (buttonWithText "Select all") Event.click ] start))
            , check "Clear unticks them again"
                (Ok [])
                (filtersOf (after [ openFilter "city", press [] (buttonWithText "Select all") Event.click, press [] (buttonWithText "Clear") Event.click ] start))
            , test "Clear is disabled while nothing is ticked" <|
                \_ -> openFilter "city" start |> expectOk (\s -> element [] (buttonWithText "Clear") [ Selector.disabled True ] s)
            , test "Select all is disabled when every value is ticked" <|
                \_ ->
                    after [ openFilter "city", press [] (buttonWithText "Select all") Event.click ] start
                        |> expectOk (\s -> element [] (buttonWithText "Select all") [ Selector.disabled True ] s)
            , test "the counts follow the other filters" <|
                \_ ->
                    -- the open orders are in Bergen, Ålesund, Zürich and Tromsø, none in Oslo
                    openFilter "city" (Table.setFilter (Table.columnId "status") (Just (OneOf [ "Open" ])) start)
                        |> expectOk
                            (\s ->
                                view [] s
                                    |> Query.find (byId "orders-popup-filter-city")
                                    |> Query.findAll [ Selector.class "klar-table__option-count" ]
                                    |> Expect.all
                                        [ Query.index 1 >> Query.has [ Selector.text "1" ]
                                        , Query.index 2 >> Query.has [ Selector.text "0" ]
                                        ]
                            )
            , test "a search box is offered above eight values" <|
                \_ ->
                    let
                        many =
                            [ Table.rows (Loaded (generated 20)), Table.columns [ Table.text (Table.columnId "number") "Order" .number [ Table.filterSelect ] ] ]
                    in
                    press many (byId "orders-trigger-filter-number") Event.click start
                        |> expectOk (\s -> element many (byId "orders-filter-number-search") [ Selector.attribute (Attr.type_ "text") ] s)
            , test "and not for eight or fewer" <|
                \_ -> openFilter "city" start |> expectOk (noElement [] (byId "orders-filter-city-search"))
            , test "filterOptions are listed in the order given, also those that no row has" <|
                \_ ->
                    let
                        withOptions =
                            [ Table.columns [ Table.text (Table.columnId "status") "Status" .status [ Table.filterOptions [ "Open", "Shipped", "Cancelled", "Returned" ] ] ] ]
                    in
                    press withOptions (byId "orders-trigger-filter-status") Event.click start
                        |> expectOk
                            (\s ->
                                allOf
                                    [ element withOptions (byId "orders-popup-filter-status") [ Selector.text "Returned" ] s
                                    , view withOptions s |> Query.find (byId "orders-filter-status-option-3") |> Query.has []
                                    ]
                            )
            , test "a yes and no column offers the words of the language" <|
                \_ -> openFilter "express" start |> expectOk (\s -> element [] (byId "orders-popup-filter-express") [ Selector.text "Yes", Selector.text "No" ] s)
            , check "and the filter keeps words that belong to no language"
                (Ok [ ( Table.columnId "express", Table.OneOf [ "true" ] ) ])
                (filtersOf (after [ openFilter "express", tick "orders-filter-express-option-1" True ] start))
            ]
        , describe "ranges"
            [ check "a lower bound" (Ok [ ( Table.columnId "total", Table.Between (Just 50) Nothing ) ]) (filtersOf (after [ openFilter "total", typeIn "orders-filter-total-from" "50" ] start))
            , check "an upper bound" (Ok [ ( Table.columnId "total", Table.Between Nothing (Just 80) ) ]) (filtersOf (after [ openFilter "total", typeIn "orders-filter-total-to" "80" ] start))
            , check "both bounds" (Ok [ ( Table.columnId "total", Table.Between (Just 50) (Just 80) ) ]) (filtersOf (after [ openFilter "total", typeIn "orders-filter-total-from" "50", typeIn "orders-filter-total-to" "80" ] start))
            , check "a decimal comma" (Ok [ ( Table.columnId "total", Table.Between (Just 50.5) Nothing ) ]) (filtersOf (after [ openFilter "total", typeIn "orders-filter-total-from" "50,5" ] start))
            , check "spaces as thousand separators" (Ok [ ( Table.columnId "total", Table.Between (Just 1250) Nothing ) ]) (filtersOf (after [ openFilter "total", typeIn "orders-filter-total-from" "1 250" ] start))
            , check "a real minus sign" (Ok [ ( Table.columnId "total", Table.Between (Just -5) Nothing ) ]) (filtersOf (after [ openFilter "total", typeIn "orders-filter-total-from" "−5" ] start))
            , check "bounds the wrong way round are swapped, as in a rule" (Ok [ ( Table.columnId "total", Table.Between (Just 50) (Just 80) ) ]) (filtersOf (after [ openFilter "total", typeIn "orders-filter-total-from" "80", typeIn "orders-filter-total-to" "50" ] start))
            , check "text is no filter" (Ok []) (filtersOf (after [ openFilter "total", typeIn "orders-filter-total-from" "abc" ] start))
            , check "a bound that is text is left out when the other one is a number" (Ok [ ( Table.columnId "total", Table.Between Nothing (Just 80) ) ]) (filtersOf (after [ openFilter "total", typeIn "orders-filter-total-from" "abc", typeIn "orders-filter-total-to" "80" ] start))
            , check "emptying the box removes the filter" (Ok []) (filtersOf (after [ openFilter "total", typeIn "orders-filter-total-from" "50", typeIn "orders-filter-total-from" "" ] start))
            , test "text in a box is called out" <|
                \_ ->
                    after [ openFilter "total", typeIn "orders-filter-total-from" "abc" ] start
                        |> expectOk (\s -> element [] (byId "orders-filter-total-from-error") [ Selector.text "Not a number", ariaAttribute "role" "alert" ] s)
            , test "and the box points at the message" <|
                \_ ->
                    after [ openFilter "total", typeIn "orders-filter-total-from" "abc" ] start
                        |> expectOk (\s -> element [] (byId "orders-filter-total-from") [ ariaAttribute "aria-describedby" "orders-filter-total-from-error", ariaAttribute "aria-invalid" "true" ] s)
            , test "a number is not called out" <|
                \_ ->
                    after [ openFilter "total", typeIn "orders-filter-total-from" "12" ] start
                        |> expectOk (noElement [] (byId "orders-filter-total-from-error"))
            , test "the lowest and the highest value are shown as a hint" <|
                \_ ->
                    openFilter "total" start
                        |> expectOk (\s -> element [] (byId "orders-popup-filter-total") [ Selector.text "Values from 0.00 to 1,250.00" ] s)
            , test "a range filter on a column without numbers has no button" <|
                \_ ->
                    noElement [ Table.columns [ Table.text (Table.columnId "number") "Order" .number [ Table.filterRange ] ] ] [ Selector.class "klar-table__filter-button" ] start
            ]
        , describe "resetting"
            [ check "the Reset button of a popover removes that filter only"
                (Ok [ ( Table.columnId "city", Table.Contains "o" ) ])
                (filtersOf
                    (after
                        [ openFilter "customer"
                        , typeIn "orders-filter-customer-text" "ac"
                        , press [] (buttonWithText "Reset") Event.click
                        ]
                        (Table.setFilter (Table.columnId "city") (Just (Contains "o")) start)
                    )
                )
            , check "the reset button of the summary removes all the filters but keeps the search"
                (Ok ( "x", [] ))
                (after [ press [] (ariaLabelled "Reset filters") Event.click ] (start |> Table.setSearch "x" |> Table.setFilter (Table.columnId "city") (Just (Contains "o")) |> Table.setFilter (Table.columnId "total") (Just (Between (Just 1) Nothing)))
                    |> Result.map (\s -> ( Table.search s, Table.filters s ))
                )
            , test "the reset also sends the message of the application" <|
                \_ ->
                    send [ Table.onResetFilters FiltersReset ] [ Selector.class "klar-table__reset" ] Event.click (Table.setFilter (Table.columnId "city") (Just (Contains "o")) start)
                        |> Expect.equal (Ok FiltersReset)
            , test "'No matches' offers to reset the search too" <|
                \_ ->
                    press [] (buttonWithText "Clear search and filters") Event.click (start |> Table.setSearch "nowhere" |> Table.setFilter (Table.columnId "city") (Just (Contains "o")))
                        |> Result.map (\s -> ( Table.search s, Table.filters s ))
                        |> Expect.equal (Ok ( "", [] ))
            , test "'No matches' resets the filters that are outside the table too" <|
                \_ ->
                    send [ Table.onResetFilters FiltersReset ] [ Selector.class "klar-table__reset" ] Event.click (Table.setSearch "nowhere" start)
                        |> Expect.equal (Ok FiltersReset)
            , test "the active filters can be listed and removed one by one" <|
                \_ ->
                    let
                        two =
                            start |> Table.setFilter (Table.columnId "city") (Just (OneOf [ "Oslo" ])) |> Table.setFilter (Table.columnId "customer") (Just (Contains "ac"))
                    in
                    press [] (byId "orders-trigger-filters") Event.click two
                        |> expectOk
                            (\s ->
                                element []
                                    (byId "orders-popup-filters")
                                    [ Selector.text "City: Oslo", Selector.text "Customer contains “ac”" ]
                                    s
                            )
            , test "a chip removes its filter" <|
                \_ ->
                    let
                        two =
                            start |> Table.setFilter (Table.columnId "city") (Just (OneOf [ "Oslo" ])) |> Table.setFilter (Table.columnId "customer") (Just (Contains "ac"))
                    in
                    after [ press [] (byId "orders-trigger-filters") Event.click, press [] (ariaLabelled "Remove City: Oslo") Event.click ] two
                        |> Result.map Table.filters
                        |> Expect.equal (Ok [ ( Table.columnId "customer", Table.Contains "ac" ) ])
            ]
        ]



-- SELECTING ROWS WITH THE MOUSE


selectionByClickTests : Test
selectionByClickTests =
    let
        selectable =
            [ Table.selectable, Table.rowLabel .customer ]

        paged =
            Table.setPageSize 3 start

        pickRow name value =
            press selectable (ariaLabelled ("Select " ++ name)) (checkedBox value)

        selectPage value =
            press selectable (byId "orders-select-page") (checkedBox value)

        ids =
            Result.map (Table.selectedIds Ids.strings)

        cancelled order =
            order.status == "Cancelled"

        withCancelledDisabled =
            Table.rowDisabled cancelled :: selectable

        allMatchingButton attributes =
            press attributes (buttonWithText "Select all 8 matching") Event.click

        prompt attributes expectations state =
            element attributes [ Selector.class "klar-table__bulk-prompt" ] expectations state
    in
    describe "selecting rows"
        [ check "a checkbox selects its row" (Ok [ "ORD-2002" ]) (ids (after [ pickRow "Globex" True ] start))
        , check "and unselects it" (Ok []) (ids (after [ pickRow "Globex" True, pickRow "Globex" False ] start))
        , check "several rows" (Ok [ "ORD-2001", "ORD-2002" ]) (ids (after [ pickRow "Globex" True, pickRow "Acme Supplies" True ] start))
        , test "the checkbox of a row is named after the row" <|
            \_ -> element selectable (ariaLabelled "Select Initech") [ Selector.attribute (Attr.type_ "checkbox") ] start
        , test "by default the name of the row is the first column" <|
            \_ -> element [ Table.selectable ] (ariaLabelled "Select ORD-2004") [ Selector.attribute (Attr.type_ "checkbox") ] start
        , check "the header checkbox selects the rows of the page" (Ok [ "ORD-2004", "ORD-2005", "ORD-2006" ]) (ids (after [ selectPage True ] (Table.setPage 2 paged)))
        , check "and unselects them" (Ok []) (ids (after [ selectPage True, selectPage False ] paged))
        , check "the other pages are left alone"
            (Ok [ "ORD-2001", "ORD-2002", "ORD-2003", "ORD-2004", "ORD-2005", "ORD-2006" ])
            (ids (after [ selectPage True, press selectable (ariaLabelled "Next page") Event.click, selectPage True ] paged))
        , check "unselecting a page keeps the selection of the other pages"
            (Ok [ "ORD-2001", "ORD-2002", "ORD-2003" ])
            (ids (after [ selectPage True, press selectable (ariaLabelled "Next page") Event.click, selectPage True, selectPage False ] paged))
        , test "a row that is disabled cannot be selected" <|
            \_ -> element withCancelledDisabled (ariaLabelled "Select Ærlig Varehus") [ Selector.disabled True ] start
        , check "and is left out of the page selection"
            (Ok [ "ORD-2001", "ORD-2002", "ORD-2003", "ORD-2004", "ORD-2006", "ORD-2007", "ORD-2008" ])
            (ids (after [ press withCancelledDisabled (byId "orders-select-page") (checkedBox True) ] start))
        , test "no checkbox at all without selectable" <|
            \_ -> noElement [] [ Selector.attribute (Attr.type_ "checkbox") ] start
        , test "the header checkbox is checked when every row of the page is selected" <|
            \_ -> after [ selectPage True ] paged |> expectOk (element selectable (byId "orders-select-page") [ Selector.checked True ])
        , test "and is mixed while only some are" <|
            \_ -> after [ pickRow "Acme Supplies" True ] paged |> expectOk (element selectable (byId "orders-select-page") [ Selector.attribute (Attr.property "indeterminate" (Encode.bool True)) ])
        , test "the header checkbox is not checked when no row is selected" <|
            \_ -> element selectable (byId "orders-select-page") [ Selector.checked False ] start
        , test "the header checkbox has a name" <|
            \_ -> element selectable (byId "orders-select-page") [ label "Select all rows on this page" ] start
        , test "a selected row says so" <|
            \_ ->
                after [ pickRow "Globex" True ] start
                    |> expectOk (element selectable (byId "orders-row-1") [ ariaAttribute "aria-selected" "true", Selector.class "klar-table__row--selected" ])
        , test "a row that is not selected says so too" <|
            \_ -> element selectable (byId "orders-row-1") [ ariaAttribute "aria-selected" "false" ] start
        , describe "the bar"
            [ test "is not there while nothing is selected" <|
                \_ -> noElement selectable [ Selector.class "klar-table__bulk" ] start
            , test "says how many rows are selected" <|
                \_ ->
                    after [ pickRow "Globex" True, pickRow "Initech" True ] start
                        |> expectOk (element selectable [ Selector.class "klar-table__bulk" ] [ label "2 selected", Selector.text "2 selected" ])
            , test "has the buttons of the application" <|
                \_ ->
                    after [ pickRow "Globex" True ] start
                        |> expectOk (element (Table.bulkActions [ Html.text "Delete selected" ] :: selectable) [ Selector.class "klar-table__bulk-actions" ] [ Selector.text "Delete selected" ])
            , check "Cancel ends the selection"
                (Ok [])
                (ids (after [ pickRow "Globex" True, pickRow "Initech" True, press selectable (buttonWithText "Cancel") Event.click ] start))
            , test "offers to select all matching rows when a whole page is selected" <|
                \_ ->
                    after [ selectPage True ] paged
                        |> expectOk (prompt selectable [ Selector.text "All 3 on this page are selected.", Selector.text "Select all 8 matching" ])
            , test "and does not when the page is all there is" <|
                \_ ->
                    after [ selectPage True ] start
                        |> expectOk (noElement selectable [ Selector.class "klar-table__bulk-prompt", Selector.containing [ Selector.tag "button" ] ])
            , check "and selects them, on every page"
                (Ok [ "ORD-2001", "ORD-2002", "ORD-2003", "ORD-2004", "ORD-2005", "ORD-2006", "ORD-2007", "ORD-2008" ])
                (ids (after [ selectPage True, allMatchingButton selectable ] paged))
            , test "then says that all matching rows are selected" <|
                \_ ->
                    after [ selectPage True, allMatchingButton selectable ] paged
                        |> expectOk (prompt selectable [ Selector.text "All 8 matching rows are selected." ])
            , check "'all matching' leaves out the rows that are disabled"
                (Ok [ "ORD-2001", "ORD-2002", "ORD-2003", "ORD-2004", "ORD-2006", "ORD-2007", "ORD-2008" ])
                (ids
                    (after
                        [ press withCancelledDisabled (byId "orders-select-page") (checkedBox True)
                        , press withCancelledDisabled (buttonWithText "Select all 7 matching") Event.click
                        ]
                        paged
                    )
                )
            , check "'all matching' selects what the search finds, not everything"
                (Ok [ "ORD-2001", "ORD-2007" ])
                (ids
                    (after
                        [ press selectable (byId "orders-select-page") (checkedBox True)
                        ]
                        (Table.setSearch "acme" start)
                    )
                )
            , test "tells when a selected row is hidden by a search" <|
                \_ ->
                    after [ pickRow "Globex" True ] start
                        |> Result.map (Table.setSearch "acme")
                        |> expectOk (prompt selectable [ Selector.text "1 selected row is hidden by search or filters" ])
            , test "tells how many are hidden" <|
                \_ ->
                    after [ pickRow "Globex" True, pickRow "Initech" True ] start
                        |> Result.map (Table.setSearch "acme")
                        |> expectOk (prompt selectable [ Selector.text "2 selected rows are hidden by search or filters" ])
            , test "says nothing about hidden rows when none is hidden" <|
                \_ ->
                    after [ pickRow "Globex" True ] start
                        |> expectOk (noElement selectable [ Selector.class "klar-table__bulk-prompt", Selector.containing [ Selector.text "hidden" ] ])
            , test "in server mode tells that selected rows are not on this page" <|
                \_ ->
                    Ok (Table.setSelected Ids.strings [ "ORD-3001", "ORD-9999" ] True start)
                        |> expectOk (prompt serverAttributes [ Selector.text "1 selected row is not on this page" ])
            , test "the bar is a labelled region that can be given focus" <|
                \_ ->
                    after [ pickRow "Globex" True ] start
                        |> expectOk (element selectable (byId "orders-bulk") [ ariaAttribute "role" "region", Selector.attribute (Attr.tabindex -1) ])
            , test "the table keeps a place for the bar, so that the rows do not jump" <|
                \_ -> element selectable [ Selector.class "klar-table__toolbar" ] [ Selector.text "No rows selected" ] start
            ]
        ]



-- THE KEYBOARD ON ROWS


rowKeyboardTests : Test
rowKeyboardTests =
    let
        selectable =
            [ Table.selectable ]

        key target name =
            press selectable (byId (Orders.rowDomId target)) (keyDown (Orders.rowDomId target) name)

        stops =
            Result.map (tabStops selectable)

        row index =
            byId (Orders.rowDomId index)

        cancelled order =
            order.status == "Cancelled"
    in
    describe "keys on a row"
        [ check "the first row is the only tab stop at first" [ 0 ] (tabStops selectable start)
        , check "ArrowDown moves the tab stop to the next row" (Ok [ 1 ]) (stops (after [ key 0 "ArrowDown" ] start))
        , check "ArrowDown twice" (Ok [ 2 ]) (stops (after [ key 0 "ArrowDown", key 1 "ArrowDown" ] start))
        , check "ArrowUp moves it back" (Ok [ 0 ]) (stops (after [ key 0 "ArrowDown", key 1 "ArrowUp" ] start))
        , check "ArrowUp on the first row stays" (Ok [ 0 ]) (stops (after [ key 0 "ArrowUp" ] start))
        , check "ArrowDown on the last row stays" (Ok [ 7 ]) (stops (after [ key 0 "End", key 7 "ArrowDown" ] start))
        , check "End goes to the last row" (Ok [ 7 ]) (stops (after [ key 0 "End" ] start))
        , check "Home goes to the first row" (Ok [ 0 ]) (stops (after [ key 0 "End", key 7 "Home" ] start))
        , check "PageDown moves ten rows, or to the last" (Ok [ 7 ]) (stops (after [ key 0 "PageDown" ] start))
        , check "PageUp moves ten rows, or to the first" (Ok [ 0 ]) (stops (after [ key 0 "End", key 7 "PageUp" ] start))
        , check "PageDown stops at the last row of a short page" (Ok [ 2 ]) (Result.map (tabStops [ Table.selectable, Table.rows (Loaded (List.take 3 Orders.curated)) ]) (press [ Table.selectable, Table.rows (Loaded (List.take 3 Orders.curated)) ] (row 0) (keyDown "orders-row-0" "PageDown") start))
        , check "Space selects the row" (Ok [ "ORD-2001" ]) (after [ key 0 " " ] start |> Result.map (Table.selectedIds Ids.strings))
        , check "Space again unselects it" (Ok []) (after [ key 0 " ", key 0 " " ] start |> Result.map (Table.selectedIds Ids.strings))
        , test "a key with Ctrl is left to the browser" <|
            \_ -> cannotUse selectable (row 0) (keyDownWith { shift = False, ctrl = True } "orders-row-0" "ArrowDown") start
        , test "a key that was pressed in a control inside the row is left to the control" <|
            \_ -> cannotUse selectable (row 0) (keyDown "something-inside" "ArrowDown") start
        , test "other keys are left alone" <|
            \_ -> cannotUse selectable (row 0) (keyDown "orders-row-0" "x") start
        , test "a key the row uses keeps the browser from scrolling the page" <|
            \_ -> view selectable start |> Query.find (row 0) |> Event.simulate (keyDown "orders-row-0" "ArrowDown") |> Event.expectPreventDefault
        , test "a row that is disabled cannot be selected with Space" <|
            \_ -> cannotUse (Table.rowDisabled cancelled :: selectable) (row 4) (keyDown "orders-row-4" " ") start
        , test "Enter does nothing on a row that only can be selected" <|
            \_ -> cannotUse selectable (row 0) (keyDown "orders-row-0" "Enter") start
        , test "Enter opens the row, when the application listens to clicks" <|
            \_ ->
                send [ Table.onRowClick Opened ] (row 1) (keyDown "orders-row-1" "Enter") start
                    |> Result.map isOpened
                    |> Expect.equal (Ok (Just "ORD-2002"))
        , test "Enter on a row that is disabled does not open it" <|
            \_ -> cannotUse [ Table.onRowClick Opened, Table.rowDisabled (\o -> o.number == "ORD-2002") ] (row 1) (keyDown "orders-row-1" "Enter") start
        , test "Enter opens a row that can be expanded" <|
            \_ ->
                press expandable (row 1) (keyDown "orders-row-1" "Enter") start
                    |> Result.map (Table.expandedIds Ids.strings)
                    |> Expect.equal (Ok [ "ORD-2002" ])
        , test "ArrowRight expands a row" <|
            \_ ->
                press expandable (row 1) (keyDown "orders-row-1" "ArrowRight") start
                    |> Result.map (Table.expandedIds Ids.strings)
                    |> Expect.equal (Ok [ "ORD-2002" ])
        , test "ArrowRight on a row that is open does nothing" <|
            \_ -> cannotUse expandable (row 1) (keyDown "orders-row-1" "ArrowRight") (Table.setExpanded Ids.strings "ORD-2002" True start)
        , test "ArrowLeft collapses a row" <|
            \_ ->
                press expandable (row 1) (keyDown "orders-row-1" "ArrowLeft") (Table.setExpanded Ids.strings "ORD-2002" True start)
                    |> Result.map (Table.expandedIds Ids.strings)
                    |> Expect.equal (Ok [])
        , test "ArrowLeft on a row that is closed does nothing" <|
            \_ -> cannotUse expandable (row 1) (keyDown "orders-row-1" "ArrowLeft") start
        , test "without expandable rows the arrow keys left and right do nothing" <|
            \_ -> cannotUse selectable (row 1) (keyDown "orders-row-1" "ArrowRight") start
        , test "Shift+F10 opens the menu of the row" <|
            \_ ->
                press withMenu (row 1) (keyDownWith { shift = True, ctrl = False } "orders-row-1" "F10") start
                    |> expectOk (element withMenu [ ariaAttribute "role" "menu" ] [ Selector.text "Open order" ])
        , test "the menu key opens it too" <|
            \_ ->
                press withMenu (row 1) (keyDown "orders-row-1" "ContextMenu") start
                    |> expectOk (element withMenu [ ariaAttribute "role" "menu" ] [ Selector.text "Open order" ])
        , test "F10 alone does not" <|
            \_ -> cannotUse withMenu (row 1) (keyDown "orders-row-1" "F10") start
        , test "Enter opens the menu of a row that does nothing else" <|
            \_ ->
                press withMenu (row 1) (keyDown "orders-row-1" "Enter") start
                    |> expectOk (element withMenu [ ariaAttribute "role" "menu" ] [ Selector.text "Open order" ])
        , test "Enter does not open the menu of a row that has a click of its own" <|
            \_ ->
                send (Table.onRowClick Opened :: withMenu) (row 1) (keyDown "orders-row-1" "Enter") start
                    |> Result.map isOpened
                    |> Expect.equal (Ok (Just "ORD-2002"))
        , test "the context menu event from the keyboard opens the menu" <|
            \_ ->
                press withMenu (row 1) (Event.custom "contextmenu" (Encode.object [ ( "button", Encode.int 0 ) ])) start
                    |> expectOk (element withMenu [ ariaAttribute "role" "menu" ] [ Selector.text "Open order" ])
        , test "a right click keeps the menu of the browser" <|
            \_ -> cannotUse withMenu (row 1) (Event.custom "contextmenu" (Encode.object [ ( "button", Encode.int 2 ) ])) start
        , test "the menu has a button named after the row" <|
            \_ -> element withMenu (ariaLabelled "Actions for ORD-2003") [] start
        , test "rows are not tab stops when nothing can be done with them" <|
            \_ -> noElement [] [ Selector.id "orders-row-0", Selector.attribute (Attr.tabindex 0) ] start
        ]


expandable : List (Table.Attribute String Order Msg)
expandable =
    [ Table.expandedRow (\order -> Html.text ("Details of " ++ order.number)) ]


withMenu : List (Table.Attribute String Order Msg)
withMenu =
    [ Table.rowActions (\order -> [ Menu.item "Open order" (Opened order) ]) ]


isOpened : Msg -> Maybe String
isOpened msg =
    case msg of
        Opened order ->
            Just order.number

        _ ->
            Nothing



-- CLICKING ROWS


rowClickTests : Test
rowClickTests =
    let
        opened attributes selectors event state =
            send attributes selectors event state |> Result.map isOpened
    in
    describe "clicking a row"
        [ test "sends the message of the application with the row" <|
            \_ ->
                opened [ Table.onRowClick Opened ] (byId "orders-row-2") (rowClickOn "TD") start
                    |> Expect.equal (Ok (Just "ORD-2003"))
        , test "a click on a cell inside is a click on the row" <|
            \_ ->
                opened [ Table.onRowClick Opened ] (byId "orders-row-2") (rowClickOn "DIV") start
                    |> Expect.equal (Ok (Just "ORD-2003"))
        , test "a click on a button inside is not" <|
            \_ -> cannotUse [ Table.onRowClick Opened ] (byId "orders-row-2") (rowClickOn "BUTTON") start
        , test "nor is a click on a link" <|
            \_ -> cannotUse [ Table.onRowClick Opened ] (byId "orders-row-2") (rowClickOn "A") start
        , test "nor is a click on a checkbox" <|
            \_ -> cannotUse [ Table.onRowClick Opened ] (byId "orders-row-2") (rowClickOn "INPUT") start
        , test "nor is a click on a label" <|
            \_ -> cannotUse [ Table.onRowClick Opened ] (byId "orders-row-2") (rowClickOn "LABEL") start
        , test "a row that is disabled sends nothing" <|
            \_ -> cannotUse [ Table.onRowClick Opened, Table.rowDisabled (\o -> o.number == "ORD-2003") ] (byId "orders-row-2") (rowClickOn "TD") start
        , test "without onRowClick a row does nothing" <|
            \_ -> cannotUse [] (byId "orders-row-2") (rowClickOn "TD") start
        , test "a row of a table with expandable rows opens when clicked, if the application does not listen" <|
            \_ ->
                press expandable (byId "orders-row-2") (rowClickOn "TD") start
                    |> Result.map (Table.expandedIds Ids.strings)
                    |> Expect.equal (Ok [ "ORD-2003" ])
        , test "the application's click wins over opening the row" <|
            \_ -> opened (Table.onRowClick Opened :: expandable) (byId "orders-row-2") (rowClickOn "TD") start |> Expect.equal (Ok (Just "ORD-2003"))
        , test "a clickable row is marked" <|
            \_ -> element [ Table.onRowClick Opened ] (byId "orders-row-2") [ Selector.class "klar-table__row--clickable" ] start
        , test "a disabled row is marked as such" <|
            \_ -> element [ Table.rowDisabled (\o -> o.number == "ORD-2003") ] (byId "orders-row-2") [ ariaAttribute "aria-disabled" "true", Selector.class "klar-table__row--disabled" ] start
        , test "a row with a tone has a class for it" <|
            \_ ->
                element
                    [ Table.rowTone
                        (\o ->
                            if o.status == "Cancelled" then
                                Just Klar.Theme.Danger

                            else
                                Nothing
                        )
                    ]
                    (byId "orders-row-4")
                    [ Selector.class "klar-table__row--danger" ]
                    start
        ]



-- DENSITY AND COLUMNS


densityAndColumnChooserTests : Test
densityAndColumnChooserTests =
    let
        chooser =
            [ Table.columnChooser ]

        openChooser attributes =
            press attributes (byId "orders-trigger-columns") Event.click

        toggle index value =
            press chooser (byId ("orders-column-" ++ String.fromInt index)) (checkedBox value)

        headerHas title attributes state =
            passes (element attributes [ Selector.tag "thead" ] [ Selector.text title ] state)

        allColumnsExcept kept =
            [ "number", "customer", "city", "items", "total", "status", "shipped", "express" ]
                |> List.filter (\id -> id /= kept)

        hide ids state =
            List.foldl (\id s -> Table.setColumnVisible (Table.columnId id) False s) state ids

        twoColumns =
            [ Table.columns [ Table.text (Table.columnId "number") "Order" .number [ Table.alwaysVisible ], Table.text (Table.columnId "city") "City" .city [] ] ]
    in
    describe "density and the column chooser"
        [ describe "density"
            [ test "three buttons, the one in use is pressed" <|
                \_ ->
                    allOf
                        [ element [ Table.densityToggle ] (ariaLabelled "Normal") [ ariaAttribute "aria-pressed" "true" ] start
                        , element [ Table.densityToggle ] (ariaLabelled "Compact") [ ariaAttribute "aria-pressed" "false" ] start
                        , element [ Table.densityToggle ] (ariaLabelled "Comfortable") [ ariaAttribute "aria-pressed" "false" ] start
                        ]
            , check "a click on Compact" (Ok Compact) (press [ Table.densityToggle ] (ariaLabelled "Compact") Event.click start |> Result.map Table.density)
            , check "a click on Comfortable" (Ok Comfortable) (press [ Table.densityToggle ] (ariaLabelled "Comfortable") Event.click start |> Result.map Table.density)
            , check "and back to Normal" (Ok Normal) (after [ press [ Table.densityToggle ] (ariaLabelled "Compact") Event.click, press [ Table.densityToggle ] (ariaLabelled "Normal") Event.click ] start |> Result.map Table.density)
            , test "the pressed button follows the state" <|
                \_ -> element [ Table.densityToggle ] (ariaLabelled "Compact") [ ariaAttribute "aria-pressed" "true" ] (Table.setDensity Compact start)
            , test "the buttons are a group with a name" <|
                \_ -> element [ Table.densityToggle ] [ Selector.class "klar-table__density" ] [ ariaAttribute "role" "group", label "Density" ] start
            , test "there are no buttons without densityToggle" <|
                \_ -> noElement [] [ Selector.class "klar-table__density" ] start
            , test "setDensity works without the buttons" <|
                \_ -> root [] [ Selector.class "klar-table--compact" ] (Table.setDensity Compact start)
            ]
        , describe "column chooser"
            [ test "is closed at first" <|
                \_ -> element chooser (byId "orders-trigger-columns") [ ariaAttribute "aria-expanded" "false" ] start
            , test "opens a dialog with a checkbox for every column" <|
                \_ ->
                    openChooser chooser start
                        |> expectOk (\s -> view chooser s |> Query.find (byId "orders-popup-columns") |> Query.findAll [ Selector.attribute (Attr.type_ "checkbox") ] |> Query.count (Expect.equal 8))
            , check "unticking a column hides it" (Ok (Just False)) (after [ openChooser chooser, toggle 2 False ] start |> Result.map (Table.isColumnVisible (Table.columnId "city")))
            , test "its header is gone" <|
                \_ -> after [ openChooser chooser, toggle 2 False ] start |> expectOk (\s -> Expect.equal False (headerHas "City" chooser s))
            , test "and the other headers are still there" <|
                \_ -> after [ openChooser chooser, toggle 2 False ] start |> expectOk (\s -> Expect.equal True (headerHas "Customer" chooser s))
            , test "the cells of the column are gone too" <|
                \_ -> after [ openChooser chooser, toggle 2 False ] start |> expectOk (noElement chooser [ Selector.tag "tbody", Selector.containing [ Selector.text "Bergen" ] ])
            , check "ticking it again shows it" (Ok (Just True)) (after [ openChooser chooser, toggle 2 False, toggle 2 True ] start |> Result.map (Table.isColumnVisible (Table.columnId "city")))
            , check "Reset forgets all choices"
                (Ok Nothing)
                (after [ openChooser chooser, toggle 2 False, press chooser (buttonWithText "Reset") Event.click ] start |> Result.map (Table.isColumnVisible (Table.columnId "city")))
            , test "Done closes the dialog" <|
                \_ -> after [ openChooser chooser, press chooser (buttonWithText "Done") Event.click ] start |> expectOk (noElement chooser [ Selector.attribute (Attr.attribute "role" "dialog") ])
            , test "a column that is hidden by default is not drawn until it is shown" <|
                \_ ->
                    let
                        hiddenShipped =
                            [ Table.columns [ Table.text (Table.columnId "number") "Order" .number [], Table.maybeDate (Table.columnId "shipped") "Shipped" .shipped [ Table.hiddenByDefault ] ] ]
                    in
                    allOf
                        [ Expect.equal False (headerHas "Shipped" hiddenShipped start)
                        , Expect.equal True (headerHas "Shipped" hiddenShipped (Table.setColumnVisible (Table.columnId "shipped") True start))
                        ]
            , test "a column that is always visible cannot be hidden, not even from the application" <|
                \_ -> Expect.equal True (headerHas "Order" twoColumns (Table.setColumnVisible (Table.columnId "number") False start))
            , test "alwaysVisible cancels hiddenByDefault" <|
                \_ ->
                    Expect.equal True
                        (headerHas "Order" [ Table.columns [ Table.text (Table.columnId "number") "Order" .number [ Table.hiddenByDefault, Table.alwaysVisible ], Table.text (Table.columnId "city") "City" .city [] ] ] start)
            , test "the checkbox of a column that is always visible is disabled" <|
                \_ ->
                    openChooser (Table.columnChooser :: twoColumns) start
                        |> expectOk (\s -> element (Table.columnChooser :: twoColumns) (byId "orders-column-0") [ Selector.disabled True ] s)
            , test "the other checkbox can be used" <|
                \_ ->
                    openChooser (Table.columnChooser :: twoColumns) start
                        |> expectOk (\s -> element (Table.columnChooser :: twoColumns) (byId "orders-column-1") [ Selector.disabled False ] s)
            , test "the table always draws one column: the first, when all are hidden" <|
                \_ -> Expect.equal True (headerHas "Order" [] (hide (allColumnsExcept "") start))
            , test "the last column that is left cannot be unticked" <|
                \_ ->
                    openChooser chooser (hide (allColumnsExcept "customer") start)
                        |> expectOk (\s -> element chooser (byId "orders-column-1") [ Selector.disabled True ] s)
            , test "the others can be ticked" <|
                \_ ->
                    openChooser chooser (hide (allColumnsExcept "customer") start)
                        |> expectOk (\s -> element chooser (byId "orders-column-0") [ Selector.disabled False ] s)
            ]
        ]



-- OPENING ROWS


expandByClickTests : Test
expandByClickTests =
    describe "expandable rows"
        [ test "every row has a button, closed at first" <|
            \_ ->
                allOf
                    [ element expandable (ariaLabelled "Show details for ORD-2001") [ ariaAttribute "aria-expanded" "false" ] start
                    , view expandable start |> Query.findAll [ Selector.class "klar-table__expand" ] |> Query.count (Expect.equal 8)
                    ]
        , test "a closed row does not name a detail row" <|
            \_ -> noElement expandable [ Selector.class "klar-table__expand", Selector.attribute (Attr.attribute "aria-controls" "orders-detail-0") ] start
        , test "the header of the button column is for screen readers only" <|
            \_ -> element expandable [ Selector.class "klar-table__th--expand" ] [ Selector.text "Details", Selector.containing [ Selector.class "klar-sr-only" ] ] start
        , check "a click on the button opens the row" (Ok [ "ORD-2002" ]) (press expandable (ariaLabelled "Show details for ORD-2002") Event.click start |> Result.map (Table.expandedIds Ids.strings))
        , test "the detail is drawn under the row" <|
            \_ ->
                press expandable (ariaLabelled "Show details for ORD-2002") Event.click start
                    |> expectOk (element expandable (byId "orders-detail-1") [ Selector.text "Details of ORD-2002" ])
        , test "and the button then says it is open and names the detail" <|
            \_ ->
                press expandable (ariaLabelled "Show details for ORD-2002") Event.click start
                    |> expectOk (element expandable (ariaLabelled "Hide details for ORD-2002") [ ariaAttribute "aria-expanded" "true", ariaAttribute "aria-controls" "orders-detail-1" ])
        , check "a second click closes it"
            (Ok [])
            (after [ press expandable (ariaLabelled "Show details for ORD-2002") Event.click, press expandable (ariaLabelled "Hide details for ORD-2002") Event.click ] start
                |> Result.map (Table.expandedIds Ids.strings)
            )
        , test "several rows can be open" <|
            \_ ->
                after [ press expandable (ariaLabelled "Show details for ORD-2002") Event.click, press expandable (ariaLabelled "Show details for ORD-2005") Event.click ] start
                    |> Result.map (Table.expandedIds Ids.strings)
                    |> Expect.equal (Ok [ "ORD-2002", "ORD-2005" ])
        , test "a row that was opened by the application is open" <|
            \_ -> element expandable (byId "orders-detail-3") [ Selector.text "Details of ORD-2004" ] (Table.setExpanded Ids.strings "ORD-2004" True start)
        , test "the open row is marked" <|
            \_ -> element expandable (byId "orders-row-3") [ Selector.class "klar-table__row--expanded" ] (Table.setExpanded Ids.strings "ORD-2004" True start)
        , test "the detail row spans all the columns and the button column" <|
            \_ -> element expandable (byId "orders-detail-3") [ Selector.containing [ Selector.attribute (Attr.colspan 9) ] ] (Table.setExpanded Ids.strings "ORD-2004" True start)
        , test "rows are not expandable unless the application gives expandedRow" <|
            \_ -> noElement [] [ Selector.class "klar-table__expand" ] (Table.setExpanded Ids.strings "ORD-2004" True start)
        , test "an open row stays open when the table is sorted, because it follows its id" <|
            \_ ->
                press expandable (ariaLabelled "Show details for ORD-2001") Event.click start
                    |> Result.map (Table.setSort [ ( Table.columnId "total", Table.Descending ) ])
                    |> expectOk (element expandable [ Selector.class "klar-table__detail" ] [ Selector.text "Details of ORD-2001" ])
        ]



-- PROPERTIES


type Change
    = SetPage Int
    | SetPageSize Int
    | SetSearch String
    | SetSort (List ( String, Direction ))
    | SetFilter String (Maybe Filter)
    | ClearFilters
    | Select (List String) Bool
    | ClearSelection


columnIdFuzzer : Fuzzer String
columnIdFuzzer =
    Fuzz.oneOfValues [ "customer", "city", "items", "total", "nope", "" ]


filterFuzzer : Fuzzer Filter
filterFuzzer =
    Fuzz.oneOf
        [ Fuzz.map Contains Fuzz.string
        , Fuzz.map OneOf (Fuzz.list (Fuzz.oneOfValues [ "Oslo", "Bergen", "x" ]))
        , Fuzz.map2 Between (Fuzz.maybe (Fuzz.floatRange -100 100)) (Fuzz.maybe (Fuzz.floatRange -100 100))
        ]


directionFuzzer : Fuzzer Direction
directionFuzzer =
    Fuzz.oneOfValues [ Ascending, Descending ]


changesFuzzer : Fuzzer (List Change)
changesFuzzer =
    Fuzz.listOfLengthBetween 0 8 changeFuzzer


changeFuzzer : Fuzzer Change
changeFuzzer =
    Fuzz.oneOf
        [ Fuzz.map SetPage (Fuzz.intRange -3 50)
        , Fuzz.map SetPageSize (Fuzz.intRange -3 200)
        , Fuzz.map SetSearch (Fuzz.oneOf [ Fuzz.oneOfValues [ "", " ", " acme ", "ø" ], Fuzz.string ])
        , Fuzz.map SetSort (Fuzz.listOfLengthBetween 0 3 (Fuzz.pair columnIdFuzzer directionFuzzer))
        , Fuzz.map2 SetFilter columnIdFuzzer (Fuzz.maybe filterFuzzer)
        , Fuzz.constant ClearFilters
        , Fuzz.map2 Select (Fuzz.list (Fuzz.oneOfValues [ "a", "b", "c", "d" ])) Fuzz.bool
        , Fuzz.constant ClearSelection
        ]


applyChange : Change -> Table.State String -> Table.State String
applyChange change state =
    case change of
        SetPage n ->
            Table.setPage n state

        SetPageSize n ->
            Table.setPageSize n state

        SetSearch text ->
            Table.setSearch text state

        SetSort levels ->
            Table.setSort (List.map (Tuple.mapFirst Table.columnId) levels) state

        SetFilter columnId filter ->
            Table.setFilter (Table.columnId columnId) filter state

        ClearFilters ->
            Table.clearFilters state

        Select ids value ->
            Table.setSelected Ids.strings ids value state

        ClearSelection ->
            Table.clearSelection state


built : List Change -> Table.State String
built changes =
    List.foldl applyChange start changes


propertyTests : Test
propertyTests =
    describe "properties"
        [ fuzz changesFuzzer "the page and the page size are never below 1" <|
            \changes ->
                let
                    state =
                        built changes
                in
                Expect.all [ \s -> Expect.atLeast 1 (Table.page s), \s -> Expect.atLeast 1 (Table.pageSize s) ] state
        , fuzz changesFuzzer "the search in effect is trimmed" <|
            \changes ->
                let
                    search =
                        Table.search (built changes)
                in
                Expect.equal (String.trim search) search
        , fuzz changesFuzzer "the filters are ordered by column id, one for each column" <|
            \changes ->
                let
                    ids =
                        List.map (Tuple.first >> Table.columnName) (Table.filters (built changes))
                in
                Expect.equal (List.sort ids |> dedupe) ids
        , fuzz changesFuzzer "the selected ids are sorted, and each one is there once" <|
            \changes ->
                let
                    selected =
                        Table.selectedIds Ids.strings (built changes)
                in
                Expect.equal (List.sort selected |> dedupe) selected
        , fuzz changesFuzzer "restoring the query of a table on a new table gives the same query" <|
            \changes ->
                let
                    query =
                        Table.query (built changes)
                in
                Expect.equal query (Table.query (Table.setQuery query (Table.init "orders")))
        , fuzz changesFuzzer "the query is the same through the accessors" <|
            \changes ->
                let
                    state =
                        built changes
                in
                Expect.equal (Table.query state)
                    { search = Table.search state, sort = Table.sort state, filters = Table.filters state, page = Table.page state, pageSize = Table.pageSize state }
        , fuzz changesFuzzer "the selection is what selectedIds says" <|
            \changes ->
                let
                    state =
                        built changes
                in
                Expect.equal (Selected (Table.selectedIds Ids.strings state)) (Table.selection Ids.strings state)
        , fuzz changesFuzzer "everything selected is selected and the count agrees" <|
            \changes ->
                let
                    state =
                        built changes

                    ids =
                        Table.selectedIds Ids.strings state
                in
                Expect.equal ( True, List.length ids ) ( List.all (\id -> Table.isSelected Ids.strings id state) ids, Table.selectedCount 0 state )
        , fuzzWith { runs = 25, distribution = Test.noDistribution } changesFuzzer "drawing the table never fails, whatever the state" <|
            \changes ->
                render [ Table.selectable, Table.searchable ] (built changes)
                    |> Query.fromHtml
                    |> Query.has [ Selector.class "klar-table" ]
        ]


dedupe : List comparable -> List comparable
dedupe sorted =
    case sorted of
        a :: b :: rest ->
            if a == b then
                dedupe (b :: rest)

            else
                a :: dedupe (b :: rest)

        other ->
            other
