module TableCsvRowsTest exposing (suite)

import Expect
import Klar.Locale as Locale
import Klar.Table.Columns as Columns
import Klar.Table.CsvRows as CsvRows
import Klar.Table.Types exposing (Column(..), ColumnId(..))
import Test exposing (Test, describe, test)


suite : Test
suite =
    describe "Pure table CSV rows"
        [ test "export values replace displayed values and retain formula protection" <|
            \_ ->
                let
                    (Column column) =
                        Columns.text (ColumnId "value") "Value" identity [ Columns.exportAs (always "=1+1") ]
                in
                Expect.equal (String.join "\u{000D}\n" [ "Value", "'=1+1" ]) (CsvRows.csvText ';' [ column ] Locale.en [ "Displayed" ])
        , test "selection suffixes preserve multi-part extensions and extensionless names" <|
            \_ ->
                Expect.equal [ "orders.archive-selected.csv", "orders-selected" ] (List.map (CsvRows.withSuffix "-selected") [ "orders.archive.csv", "orders" ])
        ]
