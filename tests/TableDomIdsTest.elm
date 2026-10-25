module TableDomIdsTest exposing (suite)

import Expect
import Klar.Table.DomIds as DomIds
import Klar.Table.Types exposing (Popup(..))
import Set
import Test exposing (Test, test)


suite : Test
suite =
    test "popup roots and triggers occupy distinct id namespaces" <|
        \_ ->
            let
                popups =
                    [ ColumnsPopup, ExportPopup, BulkExportPopup, FiltersPopup, FilterPopup "customer", FilterPopup "total" ]

                ids =
                    List.concatMap (\popup -> [ DomIds.popupDomId "orders" popup, DomIds.triggerDomId "orders" popup ]) popups
            in
            Expect.equal (List.length ids) (Set.size (Set.fromList ids))
