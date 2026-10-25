module Klar.Table.Processing exposing (..)

{-| Client/server row processing, indexed sorting, filtering and paging.
-}

import Array exposing (Array)
import Dict exposing (Dict)
import Klar.Internal.Window as Window
import Klar.Locale as Locale exposing (Locale)
import Klar.Remote as Remote exposing (Remote)
import Klar.Table.ColumnLogic exposing (findColumn, isSortable, sortKeyOf, sortLevel)
import Klar.Table.Columns exposing (status)
import Klar.Table.Filter exposing (filterTest, searchTest, searchWords)
import Klar.Table.Index as Index exposing (Index)
import Klar.Table.Numeric exposing (moneyTotals)
import Klar.Table.Rows exposing (sourceArray, sourceList, usablePrepared)
import Klar.Table.Sort as Sorting
import Klar.Table.State exposing (page)
import Klar.Table.Types exposing (ColumnConfig, Config, Data, DataStatus(..), Direction(..), Model, Rows(..), SortBy(..), Source(..))
import Klar.Table.Window exposing (pageWindow, virtualGeometry, virtualWindow)


{-| What to show: in client mode the rows after outside filter, column
filters, search and sort, and the slice for the current page.
-}
process : Config row msg -> Model -> List (ColumnConfig row msg) -> List (ColumnConfig row msg) -> Data row
process config model allColumns visible =
    let
        nothing =
            { status = Waiting
            , pageRows = []
            , pageAll = []
            , first = 0
            , rowCount = 0
            , matchingRows = \_ -> []
            , countMatching = \_ -> 0
            , totals = \_ -> Nothing
            , moneyTotals = \_ -> Nothing
            , total = Maybe.withDefault 0 config.server
            , available = Maybe.withDefault 0 config.server
            , page = max 1 model.page
            , pageCount = 1
            , offset = 0
            }
    in
    case config.rows of
        Remote.Loaded source ->
            case config.server of
                Just total ->
                    let
                        ( current, count, offset ) =
                            pageWindow config model total

                        allRows =
                            sourceList source

                        rowTotal =
                            List.length allRows

                        shown =
                            if config.virtual then
                                Window.window virtualWindow (virtualGeometry config model rowTotal) model.scroll

                            else
                                { first = 0, end = rowTotal, before = 0, after = 0 }
                    in
                    { status = Ready
                    , pageRows =
                        if config.virtual then
                            allRows |> List.drop shown.first |> List.take (shown.end - shown.first)

                        else
                            allRows
                    , pageAll = allRows
                    , first = shown.first
                    , rowCount = rowTotal
                    , matchingRows = \_ -> allRows
                    , countMatching = \test -> List.length (List.filter (\( index, row ) -> test index row) (List.indexedMap Tuple.pair allRows))
                    , totals = \_ -> Nothing
                    , moneyTotals = \_ -> Nothing
                    , total = total
                    , available = total
                    , page = current
                    , pageCount = count
                    , offset = offset
                    }

                Nothing ->
                    processClient config model allColumns visible source

        Remote.Failed problem ->
            { nothing | status = Failed problem }

        _ ->
            nothing


{-| Client mode: finds the matching rows as positions in the array of rows (see
`Klar.Table.Index`), and takes the rows of the current page from them. With
prepared rows the search texts and the sorted orders are there already.
-}
processClient : Config row msg -> Model -> List (ColumnConfig row msg) -> List (ColumnConfig row msg) -> Source row -> Data row
processClient config model allColumns visible source =
    let
        loc =
            config.locale

        array =
            sourceArray source

        rowAt position =
            Array.get position array

        onPosition test position =
            case rowAt position of
                Just row ->
                    test row

                Nothing ->
                    False

        prepared =
            usablePrepared loc allColumns source

        searched =
            List.filter .searchable visible

        words =
            searchWords model.search

        indexedSearch =
            case prepared of
                Just (Rows prep) ->
                    prep.searchIds == List.map .id searched

                Nothing ->
                    False

        searchFallback =
            if indexedSearch then
                []

            else
                searchTest loc searched model.search |> Maybe.map (onPosition >> List.singleton) |> Maybe.withDefault []

        columnTests =
            model.filters
                |> Dict.toList
                |> List.filterMap (\( colId, f ) -> findColumn colId allColumns |> Maybe.map (\col -> onPosition (filterTest loc col f)))

        tests =
            List.concat
                [ searchFallback
                , config.rowFilter |> Maybe.map (onPosition >> List.singleton) |> Maybe.withDefault []
                , columnTests
                ]

        matches =
            Index.matching
                (Maybe.map (\(Rows prep) -> prep.index) prepared)
                { count = Array.length array
                , words =
                    if indexedSearch then
                        words

                    else
                        []
                , tests = tests
                , levels = sortLevels loc prepared rowAt model.sort allColumns
                }

        total =
            Index.matchCount matches

        ( current, count, offset ) =
            pageWindow config model total

        rowsOf positions =
            List.filterMap rowAt positions

        shown =
            Window.window virtualWindow (virtualGeometry config model total) model.scroll

        pageRows =
            if config.virtual then
                rowsOf (Index.pageIndices shown.first (shown.end - shown.first) matches)

            else if config.paged then
                rowsOf (Index.pageIndices offset (max 1 model.pageSize) matches)

            else
                rowsOf (Index.allIndices matches)
    in
    { status = Ready
    , pageRows = pageRows
    , pageAll =
        if config.virtual then
            []

        else
            pageRows
    , first =
        if config.virtual then
            shown.first

        else
            0
    , rowCount =
        if config.virtual then
            total

        else
            List.length pageRows
    , matchingRows = \_ -> rowsOf (Index.allIndices matches)
    , countMatching =
        \test ->
            Index.countMatching
                (\place position ->
                    case rowAt position of
                        Just row ->
                            test place row

                        Nothing ->
                            False
                )
                matches
    , totals =
        case prepared of
            Just (Rows prep) ->
                -- read from the numbers kept per position: no row is turned into a number again
                \id -> Index.totalsOver id matches prep.index

            Nothing ->
                \_ -> Nothing
    , moneyTotals =
        case prepared of
            Just (Rows prep) ->
                if total == Array.length array then
                    -- every row matched: the totals worked out once by prepareRows
                    \id -> Dict.get id prep.moneyTotals

                else
                    \_ -> Nothing

            Nothing ->
                \_ -> Nothing
    , total = total
    , available = Array.length array
    , page = current
    , pageCount = count
    , offset = offset
    }


{-| The levels of the sort, for `Index.matching`. A single level on a column that
the prepared rows have the order of is read from the index; the others are
worked out from the rows.
-}
sortLevels :
    Locale
    -> Maybe (Rows row)
    -> (Int -> Maybe row)
    -> List ( String, Direction )
    -> List (ColumnConfig row msg)
    -> List Index.Level
sortLevels loc prepared rowAt levels allColumns =
    let
        chosen =
            levels
                |> List.filterMap
                    (\( colId, direction ) ->
                        findColumn colId allColumns
                            |> Maybe.andThen
                                (\col ->
                                    if isSortable col then
                                        Just ( col, direction == Descending )

                                    else
                                        Nothing
                                )
                    )

        computed ( col, descending ) =
            case col.sortBy of
                SortByComparator comparator ->
                    Index.Compared descending
                        (\a b ->
                            case ( rowAt a, rowAt b ) of
                                ( Just rowA, Just rowB ) ->
                                    comparator rowA rowB

                                _ ->
                                    EQ
                        )

                _ ->
                    Index.Keyed descending
                        (\position ->
                            case ( rowAt position, sortKeyOf loc col ) of
                                ( Just row, Just toKey ) ->
                                    toKey row

                                _ ->
                                    Sorting.Missing
                        )
    in
    case ( chosen, prepared ) of
        ( [ ( col, descending ) ], Just (Rows prep) ) ->
            if Index.hasRanks col.id prep.index then
                [ Index.Ranked col.id descending ]

            else
                [ computed ( col, descending ) ]

        _ ->
            List.map computed chosen


{-| Applies the outside filter, the column filters (except `excluded`, used
for the counts in a filter popover) and the search.
-}
keepMatching : Config row msg -> Model -> List (ColumnConfig row msg) -> List (ColumnConfig row msg) -> Maybe String -> List row -> List row
keepMatching config model allColumns visible excluded allRows =
    let
        loc =
            config.locale

        columnTests =
            model.filters
                |> Dict.toList
                |> List.filter (\( colId, _ ) -> Just colId /= excluded)
                |> List.filterMap (\( colId, f ) -> findColumn colId allColumns |> Maybe.map (\col -> filterTest loc col f))

        tests =
            List.concat
                [ config.rowFilter |> Maybe.map List.singleton |> Maybe.withDefault []
                , columnTests
                , searchTest loc (List.filter .searchable visible) model.search |> Maybe.map List.singleton |> Maybe.withDefault []
                ]
    in
    case tests of
        [] ->
            allRows

        _ ->
            List.filter (\row -> List.all (\test -> test row) tests) allRows


sortRows : Config row msg -> Model -> List (ColumnConfig row msg) -> List row -> List row
sortRows config model allColumns allRows =
    case List.filterMap (\( colId, direction ) -> findColumn colId allColumns |> Maybe.andThen (sortLevel config.locale direction)) model.sort of
        [] ->
            allRows

        levels ->
            Sorting.sort levels allRows
