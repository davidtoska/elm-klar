module TablePreparedTest exposing (suite)

import Array
import Expect
import Fuzz exposing (Fuzzer)
import Klar.Locale as Locale exposing (Locale)
import Klar.Remote exposing (Remote(..))
import Klar.Table as Table exposing (Direction(..), Filter(..))
import Support.Orders as Orders exposing (Msg, Order, columns, curated, generated, passes)
import Test exposing (Test, describe, fuzzWith, test)
import Test.Html.Query as Query
import Test.Html.Selector as Selector


suite : Test
suite =
    describe "Klar.Table with prepared rows"
        [ describe "shows what plain rows show"
            [ withStates "for any search, sort, filter and page" <|
                \locale state ->
                    Expect.equal
                        (shownWith (plain locale) state)
                        (shownWith (prepared locale locale columns) state)
            , withStates "when the user hides a column, so the searched columns differ" <|
                \locale state ->
                    let
                        hidden =
                            Table.setColumnVisible (Table.columnId "customer") False state
                    in
                    Expect.equal
                        (shownWith (plain locale) hidden)
                        (shownWith (prepared locale locale columns) hidden)
            , withStates "when the table is given other columns than the rows were prepared for" <|
                \locale state ->
                    Expect.equal
                        (shownWith (plain locale) state)
                        (shownWith (prepared locale locale (List.take 4 columns)) state)
            , withStates "when the table has another locale than the rows were prepared for" <|
                \locale state ->
                    Expect.equal
                        (shownWith (plain locale) state)
                        (shownWith (prepared locale (otherLocale locale) columns) state)
            ]
        , describe "the footer"
            [ test "has the sum and the average of the plain rows" <|
                \_ ->
                    Expect.all
                        [ \attributes -> expectFooter [ "54", "235.31" ] attributes (Table.init "orders")
                        , \attributes -> expectFooter [ "54", "235.31" ] attributes (Table.init "orders")
                        ]
                        [ Table.remote (Loaded curated) ]
            , test "is the same for prepared rows" <|
                \_ ->
                    expectFooter [ "54", "235.31" ]
                        [ Table.remotePrepared (Loaded (Table.prepareRows Locale.default columns (Array.fromList curated))) ]
                        (Table.init "orders")
            , test "sums only the matching rows once the search leaves some out" <|
                \_ ->
                    -- Oslo: items 3 + 7 + 20, totals 120.5, 1250 and 0
                    expectFooter [ "30", "456.83" ]
                        [ Table.remotePrepared (Loaded (Table.prepareRows Locale.default columns (Array.fromList curated))) ]
                        (Table.init "orders" |> Table.setSearch "oslo")
            ]
        ]


withStates : String -> (Locale -> Table.State String -> Expect.Expectation) -> Test
withStates description check =
    fuzzWith { runs = 30, distribution = Test.noDistribution } (Fuzz.pair localeFuzzer stateFuzzer) description (\( locale, state ) -> check locale state)


expectFooter : List String -> List (Table.Attribute String Order Msg) -> Table.State String -> Expect.Expectation
expectFooter texts attributes state =
    let
        aggregates =
            Orders.render (attributes ++ [ Table.searchable ]) state
                |> Query.fromHtml
                |> Query.findAll [ Selector.class "klar-table__aggregate" ]
    in
    texts
        |> List.indexedMap (\index text -> aggregates |> Query.index index |> Query.has [ Selector.text text ])
        |> Orders.allOf


rowsUnderTest : List Order
rowsUnderTest =
    curated ++ generated 12


plain : Locale -> List (Table.Attribute String Order Msg)
plain locale =
    [ Table.remote (Loaded rowsUnderTest), Table.locale locale, Table.pageSizes [ 5, 10 ] ]


prepared : Locale -> Locale -> List (Table.Column Order Msg) -> List (Table.Attribute String Order Msg)
prepared viewLocale preparedLocale forColumns =
    [ Table.remotePrepared (Loaded (Table.prepareRows preparedLocale forColumns (Array.fromList rowsUnderTest)))
    , Table.locale viewLocale
    , Table.pageSizes [ 5, 10 ]
    ]


shownWith : List (Table.Attribute String Order Msg) -> Table.State String -> List String
shownWith attributes state =
    let
        table =
            Orders.render (attributes ++ [ Table.searchable ]) state |> Query.fromHtml

        row index =
            Query.find [ Selector.id (Orders.rowDomId index) ] table

        exists index =
            passes (Query.has [] (row index))
    in
    List.range 0 9
        |> takeWhile exists
        |> List.map
            (\index ->
                rowsUnderTest
                    |> List.map .number
                    |> List.filter (\number -> passes (Query.has [ Selector.text number ] (row index)))
                    |> List.head
                    |> Maybe.withDefault "?"
            )


takeWhile : (a -> Bool) -> List a -> List a
takeWhile test items =
    case items of
        first :: rest ->
            if test first then
                first :: takeWhile test rest

            else
                []

        [] ->
            []


otherLocale : Locale -> Locale
otherLocale locale =
    if locale == Locale.en then
        Locale.nb

    else
        Locale.en


localeFuzzer : Fuzzer Locale
localeFuzzer =
    Fuzz.oneOfValues [ Locale.en, Locale.nb ]


stateFuzzer : Fuzzer (Table.State String)
stateFuzzer =
    Fuzz.map5
        (\search sorts page size filter ->
            Table.init "orders"
                |> Table.setSearch search
                |> Table.setSort sorts
                |> Table.setPageSize size
                |> Table.setPage page
                |> Table.setFilter (Table.columnId "city") filter
        )
        (Fuzz.oneOfValues [ "", "oslo", "acme", "ø", "customer 1", "zz", "shipped open", "12" ])
        (Fuzz.oneOfValues
            [ []
            , [ ( Table.columnId "customer", Ascending ) ]
            , [ ( Table.columnId "customer", Descending ) ]
            , [ ( Table.columnId "items", Descending ) ]
            , [ ( Table.columnId "total", Ascending ) ]
            , [ ( Table.columnId "shipped", Descending ) ]
            , [ ( Table.columnId "city", Ascending ), ( Table.columnId "items", Descending ) ]
            ]
        )
        (Fuzz.intRange 1 4)
        (Fuzz.oneOfValues [ 5, 10 ])
        (Fuzz.oneOfValues [ Nothing, Just (OneOf [ "Oslo" ]), Just (Contains "o") ])
