module Klar.Table.ColumnLogic exposing (..)

{-| Pure column visibility, sort keys and export values without table rendering.
-}

import Dict exposing (Dict)
import Klar.Locale as Locale exposing (Locale)
import Klar.Table.Sort as Sorting
import Klar.Table.Types exposing (Align(..), Attribute(..), Column(..), ColumnAttribute(..), ColumnConfig, ColumnId(..), Config, Ctx, Data, DataStatus(..), Direction(..), Draft(..), Filter(..), FilterKind(..), Footer(..), Model, MoneyTotal, Msg(..), Picked(..), Popup(..), Query, RowInfo, Rows(..), Selection(..), SortBy(..), Source(..), State(..))


sortLevel : Locale -> Direction -> ColumnConfig row msg -> Maybe (Sorting.Level row)
sortLevel loc direction col =
    let
        descending =
            direction == Descending
    in
    case col.sortBy of
        SortByComparator comparator ->
            Just (Sorting.ByComparator descending comparator)

        _ ->
            sortKeyOf loc col |> Maybe.map (Sorting.ByKey descending)


{-| The sort key of a row in this column, for the columns that sort by a key.
-}
sortKeyOf : Locale -> ColumnConfig row msg -> Maybe (row -> Sorting.Key)
sortKeyOf loc col =
    case col.sortBy of
        SortByValue ->
            Just (\row -> Sorting.textKey loc (col.value loc row))

        SortByText toText ->
            Just (\row -> Sorting.textKey loc (toText row))

        SortByNumber toNumber ->
            Just (\row -> Sorting.numberKey (toNumber row))

        SortByComparator _ ->
            Nothing

        NotSortable ->
            Nothing


isSortable : ColumnConfig row msg -> Bool
isSortable col =
    case col.sortBy of
        NotSortable ->
            False

        _ ->
            True


hasFooter : ColumnConfig row msg -> Bool
hasFooter col =
    case col.footer of
        Just _ ->
            True

        Nothing ->
            False


findColumn : String -> List (ColumnConfig row msg) -> Maybe (ColumnConfig row msg)
findColumn colId allColumns =
    case allColumns of
        [] ->
            Nothing

        col :: rest ->
            if col.id == colId then
                Just col

            else
                findColumn colId rest


visibleColumns : Model -> List (ColumnConfig row msg) -> List (ColumnConfig row msg)
visibleColumns model allColumns =
    case List.filter (isShown model) allColumns of
        [] ->
            List.take 1 allColumns

        shown ->
            shown


isShown : Model -> ColumnConfig row msg -> Bool
isShown model col =
    if col.hideable then
        Dict.get col.id model.visibility |> Maybe.withDefault (not col.hiddenByDefault)

    else
        True


exportValue : Locale -> ColumnConfig row msg -> row -> String
exportValue loc col row =
    case col.export of
        Just toText ->
            toText loc row

        Nothing ->
            col.value loc row
