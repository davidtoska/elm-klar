module TableDataTest exposing (suite)

import Expect exposing (Expectation)
import Html
import Html.Attributes as Attr
import Klar.Date as Date
import Klar.Locale as Locale exposing (Locale)
import Klar.Remote as Remote exposing (Remote(..))
import Klar.Table as Table exposing (Direction(..), Filter(..))
import Klar.Table.Csv as Csv
import Support.Ids as Ids
import Support.Orders as Orders exposing (Msg(..), Order, allOf, ariaLabelled, expectRows, generated, press, render, sortButton, sortClick)
import Test exposing (Test, describe, test)
import Test.Html.Event as Event
import Test.Html.Query as Query
import Test.Html.Selector as Selector exposing (Selector)


suite : Test
suite =
    describe "Klar.Table (the rows it shows)"
        [ pagingTests
        , sortingTests
        , sortingColumnAttributeTests
        , searchTests
        , filterTests
        , outsideFilterTests
        , footerTests
        , localeTests
        , serverModeTests
        , exportTests
        ]



-- HELPERS


start : Table.State String
start =
    Table.init "orders"


{-| The rows the table shows, by order number, for a state and some attributes.
-}
shows : List Int -> List (Table.Attribute String Order Msg) -> Table.State String -> Expectation
shows codes attributes state =
    expectRows (numbers codes) (render attributes state)


numbers : List Int -> List String
numbers codes =
    List.map (\code -> "ORD-" ++ String.fromInt code) codes


allCodes : List Int
allCodes =
    [ 2001, 2002, 2003, 2004, 2005, 2006, 2007, 2008 ]


sorted : List ( Table.ColumnId, Direction ) -> Table.State String
sorted levels =
    Table.setSort levels start


element : List (Table.Attribute String Order Msg) -> List Selector -> List Selector -> Table.State String -> Expectation
element attributes find expectations state =
    render attributes state
        |> Query.fromHtml
        |> Query.find find
        |> Query.has expectations


root : List (Table.Attribute String Order Msg) -> List Selector -> Table.State String -> Expectation
root attributes expectations state =
    render attributes state
        |> Query.fromHtml
        |> Query.has expectations


noElement : List (Table.Attribute String Order Msg) -> List Selector -> Table.State String -> Expectation
noElement attributes find state =
    render attributes state
        |> Query.fromHtml
        |> Query.findAll find
        |> Query.count (Expect.equal 0)


byId : String -> List Selector
byId id =
    [ Selector.id id ]


ariaAttribute : String -> String -> Selector
ariaAttribute name value =
    Selector.attribute (Attr.attribute name value)


expectOk : (a -> Expectation) -> Result String a -> Expectation
expectOk toExpectation result =
    case result of
        Ok value ->
            toExpectation value

        Err problem ->
            Expect.fail problem


{-| One cell of the footer, counted from the left.
-}
footerCell : Int -> List (Table.Attribute String Order Msg) -> List Selector -> Table.State String -> Expectation
footerCell index attributes expectations state =
    render attributes state
        |> Query.fromHtml
        |> Query.find [ Selector.tag "tfoot" ]
        |> Query.findAll [ Selector.tag "td" ]
        |> Query.index index
        |> Query.has expectations



-- PAGING


pagingTests : Test
pagingTests =
    let
        pages size =
            Table.setPageSize size start

        summary text attributes state =
            element attributes [ Selector.class "klar-pagination__summary" ] [ Selector.text text ] state

        liveRegion text state =
            element [] [ Selector.attribute (Attr.attribute "role" "status") ] [ Selector.text text ] state

        oslo =
            Table.setFilter (Table.columnId "city") (Just (OneOf [ "Oslo" ]))
    in
    describe "pages"
        [ test "all eight rows fit on the first page of 25" <|
            \_ -> shows allCodes [] start
        , test "the first page of three" <|
            \_ -> shows [ 2001, 2002, 2003 ] [] (pages 3)
        , test "the second page of three" <|
            \_ -> shows [ 2004, 2005, 2006 ] [] (Table.setPage 2 (pages 3))
        , test "the last page is short" <|
            \_ -> shows [ 2007, 2008 ] [] (Table.setPage 3 (pages 3))
        , test "a page after the last shows the last" <|
            \_ -> shows [ 2007, 2008 ] [] (Table.setPage 40 (pages 3))
        , test "page 0 shows the first" <|
            \_ -> shows [ 2001, 2002, 2003 ] [] (Table.setPage 0 (pages 3))
        , test "a page size of 1" <|
            \_ -> shows [ 2003 ] [] (Table.setPage 3 (pages 1))
        , test "a page size larger than the rows" <|
            \_ -> shows allCodes [] (pages 1000)
        , test "the pages are cut after sorting, not before" <|
            \_ -> shows [ 2007, 2003, 2002 ] [] (Table.setPageSize 3 (sorted [ ( Table.columnId "total", Table.Ascending ) ]))
        , test "the pages are cut after filtering" <|
            \_ -> shows [ 2001, 2004 ] [] (oslo (pages 2))
        , test "the second page of a filtered table" <|
            \_ -> shows [ 2007 ] [] (oslo (pages 2) |> Table.setPage 2)
        , test "a restored page that is past the last page of what is left shows the last page" <|
            \_ ->
                shows [ 2007 ]
                    []
                    (Table.setQuery { search = "", sort = [], filters = [ ( Table.columnId "city", Table.OneOf [ "Oslo" ] ) ], page = 4, pageSize = 2 } start)
        , test "unpaged shows every row, whatever the page size" <|
            \_ -> shows allCodes [ Table.unpaged ] (pages 3)
        , test "unpaged has no pagination" <|
            \_ -> noElement [ Table.unpaged ] [ Selector.class "klar-pagination" ] start
        , test "the range of the page is shown" <|
            \_ -> summary "4–6 of 8" [] (Table.setPage 2 (pages 3))
        , test "the range of the last page" <|
            \_ -> summary "7–8 of 8" [] (Table.setPage 3 (pages 3))
        , test "the range counts the rows that match, not all rows" <|
            \_ -> summary "1–3 of 3" [] (oslo start)
        , test "the rows are numbered for screen readers from the top of the table, not of the page" <|
            \_ -> element [] (byId "orders-row-0") [ ariaAttribute "aria-rowindex" "5" ] (Table.setPage 2 (pages 3))
        , test "the first row has the number 2, the header being the first" <|
            \_ -> element [] (byId "orders-row-0") [ ariaAttribute "aria-rowindex" "2" ] start
        , test "the table says how many rows and columns there are, counting the header" <|
            \_ -> element [] [ Selector.tag "table" ] [ ariaAttribute "aria-rowcount" "9", ariaAttribute "aria-colcount" "8" ] start
        , test "a filter changes the number of rows" <|
            \_ -> element [] [ Selector.tag "table" ] [ ariaAttribute "aria-rowcount" "4" ] (oslo start)
        , test "the live region tells the range" <|
            \_ -> liveRegion "Showing 4–6 of 8 rows." (Table.setPage 2 (pages 3))
        , test "the live region tells the sort order" <|
            \_ -> liveRegion "Sorted by Total, descending." (sorted [ ( Table.columnId "total", Table.Descending ) ])
        , test "the live region tells that there are no rows" <|
            \_ -> liveRegion "No rows." (Table.setSearch "nothing like this" start)
        ]



-- SORTING


sortingTests : Test
sortingTests =
    let
        by id direction =
            sorted [ ( Table.columnId id, direction ) ]

        cityAndDate =
            Table.columns [ Table.text (Table.columnId "number") "Order" .number [], Table.custom (Table.columnId "size") "Size" (\order -> Html.text order.status) [] ]
    in
    describe "sorting"
        [ test "by a number, ascending" <|
            \_ -> shows [ 2007, 2003, 2002, 2005, 2008, 2001, 2006, 2004 ] [] (by "total" Ascending)
        , test "by a number, descending; equal numbers keep the order of the rows" <|
            \_ -> shows [ 2004, 2006, 2001, 2005, 2008, 2002, 2003, 2007 ] [] (by "total" Descending)
        , test "by a whole number" <|
            \_ -> shows [ 2003, 2006, 2001, 2008, 2005, 2004, 2002, 2007 ] [] (by "items" Ascending)
        , test "numbers are sorted as numbers, not as text (12 comes after 7)" <|
            \_ ->
                shows [ 2004, 2002, 2007 ]
                    [ Table.rows (Loaded (List.filter (\order -> List.member order.number (numbers [ 2002, 2004, 2007 ])) Orders.curated)) ]
                    (by "items" Ascending)
        , test "by text in the order of English: accents sort with their letter" <|
            \_ -> shows [ 2007, 2001, 2005, 2008, 2002, 2004, 2003, 2006 ] [] (by "customer" Ascending)
        , test "by text, descending" <|
            \_ -> shows [ 2006, 2003, 2004, 2002, 2008, 2005, 2001, 2007 ] [] (by "customer" Descending)
        , test "capital letters sort with the small ones: 'acme logistics' before 'Acme Supplies'" <|
            \_ -> shows [ 2007, 2001 ] [] (by "customer" Ascending |> Table.setFilter (Table.columnId "customer") (Just (Contains "acme")))
        , test "by date, ascending: rows without a date go last" <|
            \_ -> shows [ 2008, 2005, 2004, 2001, 2007, 2002, 2003, 2006 ] [] (by "shipped" Ascending)
        , test "by date, descending: rows without a date still go last" <|
            \_ -> shows [ 2007, 2001, 2004, 2005, 2008, 2002, 2003, 2006 ] [] (by "shipped" Descending)
        , test "by a text where several rows are equal, the rows keep their order" <|
            \_ -> shows [ 2005, 2002, 2003, 2006, 2008, 2001, 2004, 2007 ] [] (by "status" Ascending)
        , test "by a text, descending, equal rows still keep their order" <|
            \_ -> shows [ 2001, 2004, 2007, 2002, 2003, 2006, 2008, 2005 ] [] (by "status" Descending)
        , test "by yes and no" <|
            \_ -> shows [ 2002, 2005, 2006, 2008, 2001, 2003, 2004, 2007 ] [] (by "express" Ascending)
        , test "by two columns" <|
            \_ -> shows [ 2005, 2006, 2008, 2002, 2003, 2004, 2001, 2007 ] [] (sorted [ ( Table.columnId "status", Table.Ascending ), ( Table.columnId "total", Table.Descending ) ])
        , test "by two columns, the second one ascending" <|
            \_ -> shows [ 2005, 2003, 2002, 2008, 2006, 2007, 2001, 2004 ] [] (sorted [ ( Table.columnId "status", Table.Ascending ), ( Table.columnId "total", Table.Ascending ) ])
        , test "by three columns" <|
            \_ -> shows [ 2002, 2005, 2008, 2006, 2003, 2007, 2001, 2004 ] [] (sorted [ ( Table.columnId "express", Table.Ascending ), ( Table.columnId "city", Table.Ascending ), ( Table.columnId "total", Table.Ascending ) ])
        , test "a column that does not exist is skipped" <|
            \_ -> shows [ 2007, 2003, 2002, 2005, 2008, 2001, 2006, 2004 ] [] (sorted [ ( Table.columnId "nope", Table.Ascending ), ( Table.columnId "total", Table.Ascending ) ])
        , test "only columns that do not exist: the order of the rows" <|
            \_ -> shows allCodes [] (by "nope" Ascending)
        , test "a column that cannot be sorted is skipped" <|
            \_ -> shows allCodes [ Table.columns [ Table.text (Table.columnId "number") "Order" .number [ Table.unsortable ] ] ] (by "number" Descending)
        , test "a custom column is not sorted unless it says how" <|
            \_ -> shows allCodes [ cityAndDate ] (by "size" Descending)
        , test "sorting by a hidden column still works" <|
            \_ -> shows [ 2007, 2003, 2002, 2005, 2008, 2001, 2006, 2004 ] [] (by "total" Ascending |> Table.setColumnVisible (Table.columnId "total") False)
        , test "empty text sorts last, both ways" <|
            \_ ->
                let
                    blank =
                        [ Table.rows
                            (Loaded
                                (List.indexedMap
                                    (\i order ->
                                        if i == 1 then
                                            { order | customer = "  " }

                                        else
                                            order
                                    )
                                    (List.take 3 Orders.curated)
                                )
                            )
                        ]
                in
                allOf
                    [ shows [ 2001, 2003, 2002 ] blank (by "customer" Ascending)
                    , shows [ 2003, 2001, 2002 ] blank (by "customer" Descending)
                    ]
        , test "a click on the header sorts the rows" <|
            \_ ->
                press [] (sortButton "Total") (sortClick False) start
                    |> expectOk (\s -> shows [ 2007, 2003, 2002, 2005, 2008, 2001, 2006, 2004 ] [] s)
        , test "a second click reverses them" <|
            \_ ->
                press [] (sortButton "Total") (sortClick False) start
                    |> Result.andThen (press [] (sortButton "Total") (sortClick False))
                    |> expectOk (\s -> shows [ 2004, 2006, 2001, 2005, 2008, 2002, 2003, 2007 ] [] s)
        , test "a third click puts the rows back in the order of the data" <|
            \_ ->
                press [] (sortButton "Total") (sortClick False) start
                    |> Result.andThen (press [] (sortButton "Total") (sortClick False))
                    |> Result.andThen (press [] (sortButton "Total") (sortClick False))
                    |> expectOk (\s -> shows allCodes [] s)
        ]



-- COLUMN ATTRIBUTES THAT CHANGE HOW A COLUMN SORTS


sortingColumnAttributeTests : Test
sortingColumnAttributeTests =
    let
        rank order =
            case order.status of
                "Open" ->
                    0

                "Shipped" ->
                    1

                _ ->
                    2

        withAttributes attributes =
            [ Table.columns [ Table.text (Table.columnId "number") "Order" .number [], Table.text (Table.columnId "customer") "Customer" .customer attributes ] ]

        byCustomer direction =
            sorted [ ( Table.columnId "customer", direction ) ]
    in
    describe "columns that sort differently from what they show"
        [ test "sortNumber sorts a text column by a number" <|
            \_ -> shows [ 2002, 2004, 2006, 2008, 2001, 2003, 2005, 2007 ] (withAttributes [ Table.sortNumber (\order -> toFloat (String.length order.customer)) ]) (byCustomer Ascending)
        , test "sortText sorts by another text" <|
            \_ -> shows [ 2001, 2004, 2007, 2002, 2003, 2006, 2008, 2005 ] (withAttributes [ Table.sortText .status ]) (byCustomer Descending)
        , test "sortWith uses the comparison for the ascending order" <|
            \_ -> shows [ 2002, 2003, 2006, 2008, 2001, 2004, 2007, 2005 ] (withAttributes [ Table.sortWith (\a b -> compare (rank a) (rank b)) ]) (byCustomer Ascending)
        , test "and reverses it for the descending order, equal rows keeping their order" <|
            \_ -> shows [ 2005, 2001, 2004, 2007, 2002, 2003, 2006, 2008 ] (withAttributes [ Table.sortWith (\a b -> compare (rank a) (rank b)) ]) (byCustomer Descending)
        , test "sortMaybeNumber puts rows without a number last, both ways" <|
            \_ ->
                let
                    attributes =
                        withAttributes
                            [ Table.sortMaybeNumber
                                (\order ->
                                    if order.number == "ORD-2002" then
                                        Nothing

                                    else
                                        Just order.total
                                )
                            ]
                in
                allOf
                    [ shows [ 2007, 2003, 2005, 2008, 2001, 2006, 2004, 2002 ] attributes (byCustomer Ascending)
                    , shows [ 2004, 2006, 2001, 2005, 2008, 2003, 2007, 2002 ] attributes (byCustomer Descending)
                    ]
        , test "sortDate sorts a text column by a date" <|
            \_ ->
                shows [ 2008, 2005, 2004, 2001, 2007, 2002, 2003, 2006 ]
                    (withAttributes [ Table.sortDate (\order -> order.shipped |> Maybe.withDefault (Date.fromEpochDay 2932896)) ])
                    (byCustomer Ascending)
        , test "a custom column sorts once it is given a way" <|
            \_ ->
                shows [ 2007, 2003, 2002, 2005, 2008, 2001, 2006, 2004 ]
                    [ Table.columns [ Table.text (Table.columnId "number") "Order" .number [], Table.custom (Table.columnId "size") "Size" (\order -> Html.text order.status) [ Table.sortNumber .total ] ] ]
                    (sorted [ ( Table.columnId "size", Table.Ascending ) ])
        , test "a custom column that cannot sort has a title and no button" <|
            \_ ->
                allOf
                    [ noElement [ Table.columns [ Table.text (Table.columnId "number") "Order" .number [], Table.custom (Table.columnId "size") "Size" (\order -> Html.text order.status) [] ] ] (sortButton "Size") start
                    , element [ Table.columns [ Table.text (Table.columnId "number") "Order" .number [], Table.custom (Table.columnId "size") "Size" (\order -> Html.text order.status) [] ] ] [ Selector.tag "th", Selector.containing [ Selector.text "Size" ] ] [ Selector.text "Size" ] start
                    ]
        ]



-- SEARCHING


searchTests : Test
searchTests =
    let
        found codes attributes text =
            shows codes attributes (Table.setSearch text start)
    in
    describe "the search"
        [ test "finds a word in a text column" <|
            \_ -> found [ 2001, 2007 ] [] "acme"
        , test "ignores the case" <|
            \_ -> found [ 2001, 2007 ] [] "AcMe"
        , test "finds a part of a word" <|
            \_ -> found [ 2002 ] [] "lobe"
        , test "every word must be found" <|
            \_ -> found [ 2007 ] [] "acme logistics"
        , test "the words may be in different columns" <|
            \_ -> found [ 2001, 2004, 2007 ] [] "oslo s"
        , test "the words may come in any order" <|
            \_ -> found [ 2007 ] [] "logistics acme"
        , test "a word that nothing has finds nothing" <|
            \_ -> found [] [] "oslo zzz"
        , test "ignores the accents of the text: 'ostby' finds 'Østby'" <|
            \_ -> found [ 2003 ] [] "ostby"
        , test "ignores the accents of the search: 'Østby' finds 'Østby'" <|
            \_ -> found [ 2003 ] [] "Østby"
        , test "ignores the accents of the city" <|
            \_ -> found [ 2003 ] [] "alesund"
        , test "the É of a capital letter folds too" <|
            \_ -> found [ 2008 ] [] "eclair"
        , test "ü is u" <|
            \_ -> found [ 2006 ] [] "zurich"
        , test "ø is o: 'tromso' finds 'Tromsø'" <|
            \_ -> found [ 2008 ] [] "tromso"
        , test "extra spaces between and around the words do not matter" <|
            \_ -> found [ 2007 ] [] "   acme    logistics  "
        , test "spaces only is no search" <|
            \_ -> found allCodes [] "   "
        , test "searches the dates as they are shown" <|
            \_ -> found [ 2001 ] [] "2026-10-01"
        , test "searches the words of a yes and no column" <|
            \_ -> found [ 2001, 2003, 2004, 2007 ] [] "yes"
        , test "does not search a number column" <|
            \_ -> found [] [] "1250"
        , test "does when the column asks for it" <|
            \_ -> found [ 2004 ] [ Table.columns searchableTotal ] "1,250"
        , test "does not search a column that says it should not be searched" <|
            \_ -> found [] [ Table.columns [ Table.text (Table.columnId "number") "Order" .number [], Table.text (Table.columnId "city") "City" .city [ Table.notSearchable ] ] ] "oslo"
        , test "does not search a column that is hidden" <|
            \_ -> shows [] [] (start |> Table.setSearch "bergen" |> Table.setColumnVisible (Table.columnId "city") False)
        , test "searches a column again when it is shown" <|
            \_ -> shows [ 2002, 2005 ] [] (start |> Table.setSearch "bergen" |> Table.setColumnVisible (Table.columnId "city") False |> Table.setColumnVisible (Table.columnId "city") True)
        , test "goes back to page 1 and shows the rows of the new search" <|
            \_ -> shows [ 2001 ] [] (start |> Table.setPageSize 1 |> Table.setPage 5 |> Table.setSearch "acme supplies")
        , test "marks the match in the cell" <|
            \_ ->
                render [] (Table.setSearch "acme" start)
                    |> Query.fromHtml
                    |> Query.findAll [ Selector.tag "mark" ]
                    |> Query.count (Expect.equal 2)
        , test "marks the part of the text that matches, accents and all" <|
            \_ ->
                render [] (Table.setSearch "ostby" start)
                    |> Query.fromHtml
                    |> Query.find [ Selector.tag "mark" ]
                    |> Query.has [ Selector.text "Østby" ]
        , test "marks nothing without a search" <|
            \_ -> noElement [] [ Selector.tag "mark" ] start
        , test "does not mark a cell that is drawn by the application" <|
            \_ ->
                noElement [ Table.columns [ Table.text (Table.columnId "customer") "Customer" .customer [ Table.cell (\order -> Html.text order.customer) ] ] ] [ Selector.tag "mark" ] (Table.setSearch "acme" start)
        , test "searches the text of a column that is drawn by the application" <|
            \_ ->
                shows [ 2001, 2007 ]
                    [ Table.columns [ Table.text (Table.columnId "customer") "Customer" .customer [ Table.cell (\order -> Html.text order.customer) ], Table.text (Table.columnId "number") "Order" .number [] ] ]
                    (Table.setSearch "acme" start)
        , test "the matching rows are paged" <|
            \_ -> shows [ 2007 ] [] (start |> Table.setSearch "acme" |> Table.setPageSize 1 |> Table.setPage 2)
        ]


searchableTotal : List (Table.Column Order Msg)
searchableTotal =
    [ Table.text (Table.columnId "number") "Order" .number []
    , Table.float (Table.columnId "total") "Total" 2 .total [ Table.includeInSearch ]
    ]



-- FILTERING


filterTests : Test
filterTests =
    let
        filtered codes colId filter =
            shows codes [] (Table.setFilter (Table.columnId colId) (Just filter) start)
    in
    describe "column filters"
        [ test "contains, ignoring case" <|
            \_ -> filtered [ 2001, 2007 ] "customer" (Contains "ACME")
        , test "contains, ignoring accents" <|
            \_ -> filtered [ 2003 ] "customer" (Contains "ostby")
        , test "contains, ignoring spaces around the text" <|
            \_ -> filtered [ 2001, 2007 ] "customer" (Contains "  acme ")
        , test "contains the text anywhere" <|
            \_ -> filtered [ 2001, 2004, 2007, 2008 ] "city" (Contains "o")
        , test "contains the empty text: everything" <|
            \_ -> filtered allCodes "customer" (Contains "")
        , test "contains looks at the text that is shown, so a date by how it is written" <|
            \_ -> filtered [ 2001 ] "shipped" (Contains "2026-10-01")
        , test "one of the values" <|
            \_ -> filtered [ 2002, 2003, 2006, 2008 ] "status" (OneOf [ "Open" ])
        , test "one of several values" <|
            \_ -> filtered [ 2002, 2003, 2005, 2006, 2008 ] "status" (OneOf [ "Open", "Cancelled" ])
        , test "the values are compared exactly, case and all" <|
            \_ -> filtered [] "status" (OneOf [ "open" ])
        , test "one of no values: nothing passes" <|
            \_ -> filtered [] "status" (OneOf [])
        , test "a value that no row has" <|
            \_ -> filtered [] "status" (OneOf [ "Returned" ])
        , test "a range includes both ends" <|
            \_ -> filtered [ 2002, 2005, 2008 ] "total" (Between (Just 52) (Just 75))
        , test "a range without a lower end" <|
            \_ -> filtered [ 2003, 2007 ] "total" (Between Nothing (Just 10))
        , test "a range without an upper end" <|
            \_ -> filtered [ 2001, 2004, 2006 ] "total" (Between (Just 100) Nothing)
        , test "a range without ends is everything" <|
            \_ -> filtered allCodes "total" (Between Nothing Nothing)
        , test "a range of one number" <|
            \_ -> filtered [ 2005, 2008 ] "total" (Between (Just 75) (Just 75))
        , test "a range on whole numbers" <|
            \_ -> filtered [ 2002, 2004 ] "items" (Between (Just 7) (Just 12))
        , test "a range with a negative end" <|
            \_ -> filtered allCodes "total" (Between (Just -1) Nothing)
        , test "a range on a column with no numbers is left out" <|
            \_ -> filtered allCodes "customer" (Between (Just 1) (Just 2))
        , test "a filter on a column that does not exist is left out" <|
            \_ -> filtered allCodes "nope" (Contains "x")
        , test "a filter on a hidden column still counts" <|
            \_ -> shows [ 2001, 2004, 2007 ] [] (start |> Table.setFilter (Table.columnId "city") (Just (OneOf [ "Oslo" ])) |> Table.setColumnVisible (Table.columnId "city") False)
        , test "two filters both have to hold" <|
            \_ -> shows [ 2004 ] [] (start |> Table.setFilter (Table.columnId "city") (Just (OneOf [ "Oslo" ])) |> Table.setFilter (Table.columnId "total") (Just (Between (Just 1000) Nothing)))
        , test "a filter and a search both have to hold" <|
            \_ -> shows [ 2007 ] [] (start |> Table.setFilter (Table.columnId "city") (Just (OneOf [ "Oslo" ])) |> Table.setSearch "logistics")
        , test "removing a filter shows the rows again" <|
            \_ -> shows allCodes [] (start |> Table.setFilter (Table.columnId "city") (Just (OneOf [ "Oslo" ])) |> Table.setFilter (Table.columnId "city") Nothing)
        , test "a yes and no column: yes" <|
            \_ -> filtered [ 2001, 2003, 2004, 2007 ] "express" (OneOf [ "true" ])
        , test "a yes and no column: no" <|
            \_ -> filtered [ 2002, 2005, 2006, 2008 ] "express" (OneOf [ "false" ])
        , test "a yes and no column takes the English words" <|
            \_ -> filtered [ 2001, 2003, 2004, 2007 ] "express" (OneOf [ "Yes" ])
        , test "and the Norwegian words" <|
            \_ -> filtered [ 2001, 2003, 2004, 2007 ] "express" (OneOf [ "Ja" ])
        , test "and the Norwegian word for no, in an English table" <|
            \_ -> filtered [ 2002, 2005, 2006, 2008 ] "express" (OneOf [ "Nei" ])
        , test "both yes and no" <|
            \_ -> filtered allCodes "express" (OneOf [ "Yes", "No" ])
        , test "in a Norwegian table a saved filter in English still works" <|
            \_ -> shows [ 2002, 2005, 2006, 2008 ] [ Table.locale Locale.nb ] (Table.setFilter (Table.columnId "express") (Just (OneOf [ "No" ])) start)
        , test "and one that holds the words that belong to no language" <|
            \_ -> shows [ 2001, 2003, 2004, 2007 ] [ Table.locale Locale.nb ] (Table.setFilter (Table.columnId "express") (Just (OneOf [ "true" ])) start)
        ]


outsideFilterTests : Test
outsideFilterTests =
    let
        large order =
            order.total > 100
    in
    describe "filters outside the table"
        [ test "rowFilter leaves rows out" <|
            \_ -> shows [ 2001, 2004, 2006 ] [ Table.rowFilter large ] start
        , test "it works together with the search" <|
            \_ -> shows [ 2001 ] [ Table.rowFilter large ] (Table.setSearch "supplies" start)
        , test "and with the column filters" <|
            \_ -> shows [ 2004 ] [ Table.rowFilter large ] (Table.setFilter (Table.columnId "city") (Just (OneOf [ "Oslo" ])) start |> Table.setFilter (Table.columnId "total") (Just (Between (Just 1000) Nothing)))
        , test "activeExternalFilters is counted as a filter" <|
            \_ -> element [ Table.rowFilter large, Table.activeExternalFilters 1 ] (byId "orders-trigger-filters") [ Selector.text "1 filter active" ] start
        , test "and added to the filters of the table" <|
            \_ -> element [ Table.rowFilter large, Table.activeExternalFilters 2 ] (byId "orders-trigger-filters") [ Selector.text "3 filters active" ] (Table.setFilter (Table.columnId "city") (Just (OneOf [ "Oslo" ])) start)
        , test "without them the table says nothing about filters" <|
            \_ -> noElement [] (byId "orders-trigger-filters") start
        , test "a table whose rows are all filtered out says 'No matches'" <|
            \_ -> element [ Table.rowFilter (always False), Table.activeExternalFilters 1 ] [ Selector.class "klar-state" ] [ Selector.text "No matches" ] start
        , test "a table without rows says 'No data'" <|
            \_ -> element [ Table.rows (Loaded []) ] [ Selector.class "klar-state" ] [ Selector.text "No data" ] start
        , test "with an outside filter active, a table without rows says 'No matches': the filter may be why" <|
            \_ -> element [ Table.rows (Loaded []), Table.activeExternalFilters 1 ] [ Selector.class "klar-state" ] [ Selector.text "No matches" ] start
        , test "the popover lists the number of outside filters in a note" <|
            \_ ->
                press [ Table.activeExternalFilters 2, Table.rowFilter large ] (byId "orders-trigger-filters") Event.click start
                    |> expectOk (\s -> element [ Table.activeExternalFilters 2, Table.rowFilter large ] (byId "orders-popup-filters") [ Selector.text "+ 2 filters outside the table" ] s)
        , test "rowFilter is left alone in server mode, where the backend filters" <|
            \_ -> shows [ 2001, 2002 ] [ Table.rowFilter (always False), Table.server { total = 2 }, Table.rows (Loaded (List.take 2 Orders.curated)) ] start
        ]



-- FOOTERS


footerTests : Test
footerTests =
    let
        oslo =
            Table.setFilter (Table.columnId "city") (Just (OneOf [ "Oslo" ]))

        order =
            Table.text (Table.columnId "number") "Order" .number
    in
    describe "footers"
        [ test "a sum adds up every matching row, not only the page" <|
            \_ -> footerCell 3 [] [ Selector.text "54" ] (Table.setPageSize 3 start)
        , test "a sum follows the filters" <|
            \_ -> footerCell 3 [] [ Selector.text "30" ] (oslo start)
        , test "the sum has a label" <|
            \_ -> footerCell 3 [] [ Selector.class "klar-table__aggregate-label", Selector.text "Sum" ] start
        , test "an average is written with the decimals of the column" <|
            \_ -> footerCell 4 [] [ Selector.text "235.31" ] start
        , test "and a label" <|
            \_ -> footerCell 4 [] [ Selector.text "Avg" ] start
        , test "the average follows the filters" <|
            \_ -> footerCell 4 [] [ Selector.text "456.83" ] (oslo start)
        , test "the first column, when it has no footer of its own, says 'Total'" <|
            \_ -> footerCell 0 [] [ Selector.text "Total" ] start
        , test "there is no footer without matching rows" <|
            \_ -> noElement [] [ Selector.tag "tfoot" ] (Table.setSearch "nothing like this" start)
        , test "there is no footer when no visible column has one" <|
            \_ -> noElement [ Table.columns [ order [], Table.text (Table.columnId "city") "City" .city [] ] ] [ Selector.tag "tfoot" ] start
        , test "a column that is hidden has no footer" <|
            \_ -> noElement [] [ Selector.tag "tfoot", Selector.containing [ Selector.text "Sum" ] ] (Table.setColumnVisible (Table.columnId "items") False start)
        , test "the average of no numbers is a dash" <|
            \_ ->
                footerCell 1
                    [ Table.columns [ order [], Table.text (Table.columnId "city") "City" .city [ Table.sortMaybeNumber (always Nothing), Table.footerAverage ] ] ]
                    [ Selector.text "–" ]
                    start
        , test "footer gives the application the matching rows and shows what it returns" <|
            \_ ->
                footerCell 0
                    [ Table.columns [ order [ Table.footer (\rows -> String.fromInt (List.length rows) ++ " orders") ] ] ]
                    [ Selector.text "8 orders" ]
                    start
        , test "footer follows the search" <|
            \_ ->
                footerCell 0
                    [ Table.columns [ order [ Table.footer (\rows -> String.fromInt (List.length rows) ++ " orders") ], Table.text (Table.columnId "customer") "Customer" .customer [] ] ]
                    [ Selector.text "2 orders" ]
                    (Table.setSearch "acme" start)
        , test "in server mode the footer covers the current page" <|
            \_ -> footerCell 3 [ Table.server { total = 120 }, Table.rows (Loaded (List.take 2 Orders.curated)) ] [ Selector.text "15" ] start
        ]



-- LOCALE


localeTests : Test
localeTests =
    let
        norwegian =
            [ Table.locale Locale.nb ]
    in
    describe "locale"
        [ test "numbers in English" <|
            \_ -> element [] (byId "orders-row-3") [ Selector.text "1,250.00" ] start
        , test "numbers in Norwegian, with a decimal comma and a non-breaking space" <|
            \_ -> element norwegian (byId "orders-row-3") [ Selector.text "1\u{00A0}250,00" ] start
        , test "dates in English" <|
            \_ -> element [] (byId "orders-row-0") [ Selector.text "2026-10-01" ] start
        , test "dates in Norwegian" <|
            \_ -> element norwegian (byId "orders-row-0") [ Selector.text "01.10.2026" ] start
        , test "yes and no in English" <|
            \_ -> element [] (byId "orders-row-0") [ Selector.text "Yes" ] start
        , test "yes and no in Norwegian" <|
            \_ -> element norwegian (byId "orders-row-0") [ Selector.text "Ja" ] start
        , test "the built-in texts in Norwegian" <|
            \_ ->
                allOf
                    [ element (Table.searchable :: norwegian) (byId "orders-search") [ Selector.attribute (Attr.placeholder "Søk i 8 rader ...") ] start
                    , element norwegian [ Selector.class "klar-pagination__summary" ] [ Selector.text "1–8 av 8" ] start
                    , element norwegian [ Selector.tag "tfoot" ] [ Selector.text "Totalt" ] start
                    ]
        , test "the header hint in Norwegian" <|
            \_ -> element norwegian (sortButton "Total") [ Selector.attribute (Attr.title "Klikk for å sortere") ] start
        , test "text sorts in the Norwegian order: æ, ø, å after z" <|
            \_ -> shows [ 2007, 2001, 2008, 2002, 2004, 2006, 2005, 2003 ] norwegian (sorted [ ( Table.columnId "customer", Table.Ascending ) ])
        , test "the same text sorts differently in English" <|
            \_ -> shows [ 2007, 2001, 2005, 2008, 2002, 2004, 2003, 2006 ] [] (sorted [ ( Table.columnId "customer", Table.Ascending ) ])
        , test "cities in the Norwegian order: Ålesund last" <|
            \_ -> shows [ 2002, 2005, 2001, 2004, 2007, 2008, 2006, 2003 ] norwegian (sorted [ ( Table.columnId "city", Table.Ascending ) ])
        , test "cities in English: Ålesund first, as an A" <|
            \_ -> shows [ 2003, 2002, 2005, 2001, 2004, 2007, 2008, 2006 ] [] (sorted [ ( Table.columnId "city", Table.Ascending ) ])
        ]



-- SERVER MODE


serverModeTests : Test
serverModeTests =
    let
        server =
            [ Table.server { total = 120 }, Table.rows (Loaded (generated 25)) ]

        refreshingServer =
            [ Table.server { total = 120 }, Table.rows (Remote.refresh (Loaded (generated 25))) ]

        page =
            List.range 3001 3025

        empty =
            [ Table.server { total = 120 }, Table.rows (Loaded []) ]
    in
    describe "server mode"
        [ test "shows the rows it is given, as they are" <|
            \_ -> shows page server start
        , test "does not search them" <|
            \_ -> shows page server (Table.setSearch "nothing like this" start)
        , test "does not filter them" <|
            \_ -> shows page server (Table.setFilter (Table.columnId "city") (Just (OneOf [ "Nowhere" ])) start)
        , test "does not sort them" <|
            \_ -> shows page server (sorted [ ( Table.columnId "total", Table.Descending ) ])
        , test "does not cut them to the page, even when the page size is smaller" <|
            \_ -> shows page server (Table.setPageSize 10 start)
        , test "the pagination uses the total" <|
            \_ -> element server [ Selector.class "klar-pagination__summary" ] [ Selector.text "1–25 of 120" ] start
        , test "the range of a later page" <|
            \_ -> element server [ Selector.class "klar-pagination__summary" ] [ Selector.text "51–75 of 120" ] (Table.setPage 3 start)
        , test "a page after the last is shown as the last" <|
            \_ -> element server [ Selector.class "klar-pagination__summary" ] [ Selector.text "101–120 of 120" ] (Table.setPage 99 start)
        , test "the table says how many rows there are" <|
            \_ -> element server [ Selector.tag "table" ] [ ariaAttribute "aria-rowcount" "121" ] start
        , test "the rows are numbered from the top of the whole table" <|
            \_ -> element server (byId "orders-row-0") [ ariaAttribute "aria-rowindex" "52" ] (Table.setPage 3 start)
        , test "the pagination has a button for each of the five pages" <|
            \_ -> element server (ariaLabelled "Page 5") [] start
        , test "a negative total counts as no rows" <|
            \_ -> element [ Table.server { total = -4 }, Table.rows (Loaded []) ] [ Selector.class "klar-state" ] [ Selector.text "No data" ] start
        , test "no rows but a total says that this page is empty" <|
            \_ -> element empty [ Selector.class "klar-state" ] [ Selector.text "This page is empty" ] start
        , test "and offers the first page" <|
            \_ ->
                press empty [ Selector.tag "button", Selector.containing [ Selector.text "Go to the first page" ] ] Event.click (Table.setPage 3 start)
                    |> Result.map Table.page
                    |> Expect.equal (Ok 1)
        , test "while a new page is on its way the rows stay, dimmed, and the pagination stays" <|
            \_ ->
                allOf
                    [ root refreshingServer [ Selector.class "klar-table--refreshing" ] start
                    , element refreshingServer (byId "orders-pagination") [] start
                    ]
        , test "while the first rows are loading the pagination is not there for a table that does not know its total" <|
            \_ -> noElement [ Table.rows Loading ] [ Selector.class "klar-pagination" ] start
        ]



-- EXPORT


{-| The curated orders as the export writes them in English: the number, the
customer, the city, the items, the total with two decimals and no separator of
thousands, the status, the date shipped and yes or no.
-}
exported : List ( Int, List String )
exported =
    [ ( 2001, [ "ORD-2001", "Acme Supplies", "Oslo", "3", "120.50", "Shipped", "2026-10-01", "Yes" ] )
    , ( 2002, [ "ORD-2002", "Globex", "Bergen", "12", "52.00", "Open", "", "No" ] )
    , ( 2003, [ "ORD-2003", "Østby Trading", "Ålesund", "1", "9.99", "Open", "", "Yes" ] )
    , ( 2004, [ "ORD-2004", "Initech", "Oslo", "7", "1250.00", "Shipped", "2026-09-25", "Yes" ] )
    , ( 2005, [ "ORD-2005", "Ærlig Varehus", "Bergen", "5", "75.00", "Cancelled", "2026-08-02", "No" ] )
    , ( 2006, [ "ORD-2006", "Zeta Works", "Zürich", "2", "300.00", "Open", "", "No" ] )
    , ( 2007, [ "ORD-2007", "acme logistics", "Oslo", "20", "0.00", "Shipped", "2026-10-10", "Yes" ] )
    , ( 2008, [ "ORD-2008", "Éclair Foods", "Tromsø", "4", "75.00", "Open", "2026-07-14", "No" ] )
    ]


{-| The same in Norwegian: a decimal comma, dates with dots, Ja and Nei.
-}
exportedInNorwegian : List ( Int, List String )
exportedInNorwegian =
    [ ( 2001, [ "ORD-2001", "Acme Supplies", "Oslo", "3", "120,50", "Shipped", "01.10.2026", "Ja" ] )
    , ( 2002, [ "ORD-2002", "Globex", "Bergen", "12", "52,00", "Open", "", "Nei" ] )
    , ( 2003, [ "ORD-2003", "Østby Trading", "Ålesund", "1", "9,99", "Open", "", "Ja" ] )
    , ( 2004, [ "ORD-2004", "Initech", "Oslo", "7", "1250,00", "Shipped", "25.09.2026", "Ja" ] )
    , ( 2005, [ "ORD-2005", "Ærlig Varehus", "Bergen", "5", "75,00", "Cancelled", "02.08.2026", "Nei" ] )
    , ( 2006, [ "ORD-2006", "Zeta Works", "Zürich", "2", "300,00", "Open", "", "Nei" ] )
    , ( 2007, [ "ORD-2007", "acme logistics", "Oslo", "20", "0,00", "Shipped", "10.10.2026", "Ja" ] )
    , ( 2008, [ "ORD-2008", "Éclair Foods", "Tromsø", "4", "75,00", "Open", "14.07.2026", "Nei" ] )
    ]


exportTests : Test
exportTests =
    let
        exporting =
            [ Table.exportCsv "orders.csv" ]

        open attributes state =
            press attributes (byId "orders-trigger-export") Event.click state

        header =
            [ "Order", "Customer", "City", "Items", "Total", "Status", "Shipped", "Express" ]

        csvOf separator codes table =
            Csv.encode separator (header :: List.filterMap (\code -> List.filter (\( c, _ ) -> c == code) table |> List.head |> Maybe.map Tuple.second) codes)

        english codes =
            csvOf ',' codes exported

        option index attributes expectations state =
            element attributes (byId ("orders-popup-export-option-" ++ String.fromInt index)) expectations state

        link csv name =
            [ Selector.attribute (Attr.href (Csv.dataUrl csv)), Selector.attribute (Attr.download name) ]

        twoColumns =
            [ Table.columns [ Table.text (Table.columnId "number") "Order" .number [], Table.text (Table.columnId "city") "City" .city [ Table.notExported ] ] ]
    in
    describe "CSV export"
        [ test "there is no export button unless the application asks for it" <|
            \_ -> noElement [] (byId "orders-trigger-export") start
        , test "the button opens a menu of downloads" <|
            \_ -> open exporting start |> expectOk (\s -> element exporting [ Selector.attribute (Attr.attribute "role" "dialog") ] [ Selector.text "Export as CSV" ] s)
        , test "all matching rows are the first choice" <|
            \_ -> open exporting start |> expectOk (\s -> option 0 exporting [ Selector.text "All matching", Selector.text "8 rows" ] s)
        , test "the link downloads the file under the name given" <|
            \_ -> open exporting start |> expectOk (\s -> option 0 exporting (link (english allCodes) "orders.csv") s)
        , test "the rows are in the order of the table, not of the data" <|
            \_ ->
                open exporting (sorted [ ( Table.columnId "total", Table.Ascending ) ])
                    |> expectOk (\s -> option 0 exporting (link (english [ 2007, 2003, 2002, 2005, 2008, 2001, 2006, 2004 ]) "orders.csv") s)
        , test "only the rows that match the search" <|
            \_ ->
                open exporting (Table.setSearch "acme" start)
                    |> expectOk (\s -> option 0 exporting (link (english [ 2001, 2007 ]) "orders.csv") s)
        , test "in Norwegian the separator is a semicolon and numbers have a decimal comma" <|
            \_ ->
                let
                    norwegian =
                        [ Table.exportCsv "orders.csv", Table.locale Locale.nb ]
                in
                open norwegian start |> expectOk (\s -> option 0 norwegian (link (csvOf ';' allCodes exportedInNorwegian) "orders.csv") s)
        , test "csvSeparator chooses another" <|
            \_ ->
                let
                    attributes =
                        [ Table.exportCsv "orders.csv", Table.csvSeparator '\t' ]
                in
                open attributes start |> expectOk (\s -> option 0 attributes (link (csvOf '\t' allCodes exported) "orders.csv") s)
        , test "a column that is not exported is left out" <|
            \_ ->
                open (Table.exportCsv "orders.csv" :: twoColumns) start
                    |> expectOk (\s -> option 0 (Table.exportCsv "orders.csv" :: twoColumns) (link (Csv.encode ',' (List.map (\code -> [ code ]) ("Order" :: numbers allCodes))) "orders.csv") s)
        , test "a column that is hidden is left out" <|
            \_ ->
                let
                    attributes =
                        Table.exportCsv "orders.csv" :: [ Table.columns [ Table.text (Table.columnId "number") "Order" .number [], Table.text (Table.columnId "city") "City" .city [] ] ]
                in
                open attributes (Table.setColumnVisible (Table.columnId "city") False start)
                    |> expectOk (\s -> option 0 attributes (link (Csv.encode ',' (List.map (\code -> [ code ]) ("Order" :: numbers allCodes))) "orders.csv") s)
        , test "a custom column is exported when it says what to export" <|
            \_ ->
                let
                    attributes =
                        [ Table.exportCsv "orders.csv"
                        , Table.columns
                            [ Table.text (Table.columnId "number") "Order" .number []
                            , Table.custom (Table.columnId "size") "Size" (\order -> Html.text order.status) [ Table.exportAs (\order -> "size of " ++ order.number) ]
                            ]
                        ]
                in
                open attributes start
                    |> expectOk
                        (\s ->
                            option 0
                                attributes
                                (link (Csv.encode ',' ([ "Order", "Size" ] :: List.map (\code -> [ code, "size of " ++ code ]) (numbers allCodes))) "orders.csv")
                                s
                        )
        , test "text that a spreadsheet would run as a formula is made safe" <|
            \_ ->
                let
                    hostile =
                        [ { number = "ORD-1", customer = "=HYPERLINK(\"http://example.com\")", city = "Oslo", items = 1, total = 1, status = "Open", shipped = Nothing, express = False } ]

                    attributes =
                        [ Table.exportCsv "orders.csv", Table.rows (Loaded hostile), Table.columns [ Table.text (Table.columnId "number") "Order" .number [], Table.text (Table.columnId "customer") "Customer" .customer [] ] ]
                in
                open attributes start
                    |> expectOk (\s -> option 0 attributes (link "Order,Customer\u{000D}\nORD-1,\"'=HYPERLINK(\"\"http://example.com\"\")\"" "orders.csv") s)
        , test "the note tells the number of columns and the separator" <|
            \_ -> open exporting start |> expectOk (\s -> element exporting [ Selector.class "klar-table__popover-note" ] [ Selector.text "8 columns · UTF-8 · comma" ] s)
        , test "with more than one page the current page can be exported too" <|
            \_ ->
                open exporting (Table.setPageSize 3 start |> Table.setPage 2)
                    |> expectOk (\s -> option 1 exporting (link (english [ 2004, 2005, 2006 ]) "orders-page-2.csv") s)
        , test "but not when everything fits on one page" <|
            \_ -> open exporting start |> expectOk (noElement exporting (byId "orders-popup-export-option-1"))
        , test "selected rows are a choice of their own" <|
            \_ ->
                let
                    attributes =
                        Table.selectable :: exporting
                in
                open attributes (Table.setSelected Ids.strings [ "ORD-2002", "ORD-2005" ] True start)
                    |> expectOk (\s -> option 1 attributes (link (english [ 2002, 2005 ]) "orders-selected.csv") s)
        , test "in the bar of selected rows the selected rows come first" <|
            \_ ->
                let
                    attributes =
                        Table.selectable :: exporting
                in
                press attributes (byId "orders-trigger-bulk-export") Event.click (Table.setSelected Ids.strings [ "ORD-2002" ] True start)
                    |> expectOk (\s -> element attributes (byId "orders-popup-bulk-export-option-0") [ Selector.text "Selected rows", Selector.text "1 row" ] s)
        , test "a file name without an extension gets the suffix at the end" <|
            \_ ->
                let
                    attributes =
                        [ Table.exportCsv "orders", Table.selectable ]
                in
                open attributes (Table.setSelected Ids.strings [ "ORD-2002" ] True start)
                    |> expectOk (\s -> option 1 attributes [ Selector.attribute (Attr.download "orders-selected") ] s)
        , test "a file name with several dots gets the suffix before the last one" <|
            \_ ->
                let
                    attributes =
                        [ Table.exportCsv "orders.2026.csv", Table.selectable ]
                in
                open attributes (Table.setSelected Ids.strings [ "ORD-2002" ] True start)
                    |> expectOk (\s -> option 1 attributes [ Selector.attribute (Attr.download "orders.2026-selected.csv") ] s)
        , test "in server mode the table offers only the page it has" <|
            \_ ->
                let
                    attributes =
                        Table.server { total = 120 } :: Table.rows (Loaded (generated 25)) :: exporting
                in
                open attributes start
                    |> expectOk (\s -> option 0 attributes [ Selector.text "This page", Selector.text "25 rows" ] s)
        , test "the export button is disabled while the rows are loading" <|
            \_ -> element (Table.rows Loading :: exporting) (byId "orders-trigger-export") [ Selector.disabled True ] start
        ]
