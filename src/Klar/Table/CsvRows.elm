module Klar.Table.CsvRows exposing (..)

{-| Pure column-to-CSV assembly and export filename suffixes, without table rendering.
-}

import Klar.Locale as Locale exposing (Locale)
import Klar.Table.ColumnLogic exposing (exportValue)
import Klar.Table.Csv as Csv
import Klar.Table.Types exposing (ColumnConfig)


{-| The CSV text of some rows: a line of titles, then a line per row with the
exported values of these columns.
-}
csvText : Char -> List (ColumnConfig row msg) -> Locale -> List row -> String
csvText separator exported loc someRows =
    Csv.encode separator
        (List.map .title exported
            :: List.map (\row -> List.map (\col -> exportValue loc col row) exported) someRows
        )


{-| "orders.csv" + "-selected" = "orders-selected.csv" (the suffix is "-valgte" in
Norwegian)
-}
withSuffix : String -> String -> String
withSuffix suffix filename =
    if String.isEmpty suffix then
        filename

    else
        case List.reverse (String.split "." filename) of
            extension :: ((_ :: _) as restReversed) ->
                String.join "." (List.reverse restReversed) ++ suffix ++ "." ++ extension

            _ ->
                filename ++ suffix
