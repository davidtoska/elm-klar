module Klar.Table.Rows exposing (..)

{-| Prepared row indexes and access to list-backed and prepared row sources.
-}

import Array exposing (Array)
import Dict exposing (Dict)
import Klar.Locale as Locale exposing (Locale)
import Klar.Table.ColumnLogic exposing (sortKeyOf, visibleColumns)
import Klar.Table.Filter exposing (searchText)
import Klar.Table.Index as Index exposing (Index)
import Klar.Table.Numeric exposing (moneyTotals)
import Klar.Table.State exposing (init, search)
import Klar.Table.Types exposing (Column(..), ColumnConfig, Footer(..), Rows(..), Source(..), State(..))


prepareRows : Locale -> List (Column row msg) -> Array row -> Rows row
prepareRows loc givenColumns array =
    let
        allColumns =
            List.map (\(Column col) -> col) givenColumns

        searched =
            (case init "" of
                State model ->
                    visibleColumns model allColumns
            )
                |> List.filter .searchable
    in
    Rows
        { array = array
        , locale = loc
        , columnIds = List.map .id allColumns
        , searchIds = List.map .id searched
        , index =
            Index.build array
                { search =
                    if List.isEmpty searched then
                        Nothing

                    else
                        Just (searchText loc searched)
                , sorts = List.filterMap (\col -> sortKeyOf loc col |> Maybe.map (Tuple.pair col.id)) allColumns
                , totals =
                    List.filterMap
                        (\col ->
                            -- a money column adds its amounts exactly in the footer instead
                            case ( col.footer, col.number, col.money ) of
                                ( Just FooterSum, Just toNumber, Nothing ) ->
                                    Just ( col.id, toNumber )

                                ( Just FooterAverage, Just toNumber, Nothing ) ->
                                    Just ( col.id, toNumber )

                                _ ->
                                    Nothing
                        )
                        allColumns
                }
        , moneyTotals =
            List.filterMap
                (\col ->
                    case ( col.footer, col.money ) of
                        ( Just FooterSum, Just toMoney ) ->
                            Just ( col.id, moneyTotals toMoney (Array.toList array) )

                        ( Just FooterAverage, Just toMoney ) ->
                            Just ( col.id, moneyTotals toMoney (Array.toList array) )

                        _ ->
                            Nothing
                )
                allColumns
                |> Dict.fromList
        }


rowsArray : Rows row -> Array row
rowsArray (Rows prep) =
    prep.array


sourceList : Source row -> List row
sourceList source =
    case source of
        FromList list ->
            list

        FromRows (Rows prep) ->
            Array.toList prep.array


sourceArray : Source row -> Array row
sourceArray source =
    case source of
        FromList list ->
            Array.fromList list

        FromRows (Rows prep) ->
            prep.array


{-| The prepared rows, if they were made for this locale and these columns.
-}
usablePrepared : Locale -> List (ColumnConfig row msg) -> Source row -> Maybe (Rows row)
usablePrepared loc allColumns source =
    case source of
        FromRows ((Rows prep) as prepared) ->
            if prep.locale == loc && prep.columnIds == List.map .id allColumns then
                Just prepared

            else
                Nothing

        FromList _ ->
            Nothing
