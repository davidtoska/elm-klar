module TablePreparedCoreTest exposing (suite)

import Array
import Expect
import Klar.Locale as Locale
import Klar.Table.Columns as Columns
import Klar.Table.Index as Index
import Klar.Table.Rows as Rows
import Klar.Table.Types exposing (ColumnId(..), Rows(..))
import Test exposing (Test, test)


suite : Test
suite =
    test "preparing sort indexes preserves the source array order" <|
        \_ ->
            let
                prepared =
                    Rows.prepareRows Locale.en [ Columns.text (ColumnId "name") "Name" identity [] ] (Array.fromList [ "Zulu", "Ada" ])

                (Rows details) =
                    prepared
            in
            Expect.equal ( [ "Zulu", "Ada" ], True ) ( Array.toList (Rows.rowsArray prepared), Index.hasRanks "name" details.index )
