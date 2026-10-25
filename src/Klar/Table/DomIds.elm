module Klar.Table.DomIds exposing (..)

{-| Stable DOM names shared by table messages, focus commands and rendering.
-}

import Klar.Internal as Internal
import Klar.Table.Types exposing (Popup(..))


popupSuffix : Popup -> String
popupSuffix popup =
    case popup of
        NoPopup ->
            "none"

        FilterPopup colId ->
            "filter-" ++ Internal.sanitizeId colId

        ColumnsPopup ->
            "columns"

        ExportPopup ->
            "export"

        BulkExportPopup ->
            "bulk-export"

        FiltersPopup ->
            "filters"


popupDomId : String -> Popup -> String
popupDomId tableId popup =
    tableId ++ "-popup-" ++ popupSuffix popup


triggerDomId : String -> Popup -> String
triggerDomId tableId popup =
    tableId ++ "-trigger-" ++ popupSuffix popup


rowDomId : String -> Int -> String
rowDomId tableId index =
    tableId ++ "-row-" ++ String.fromInt index


detailDomId : String -> Int -> String
detailDomId tableId index =
    tableId ++ "-detail-" ++ String.fromInt index


bulkDomId : String -> String
bulkDomId tableId =
    tableId ++ "-bulk"


{-| The scroll area: where focus waits when the control that had it (the retry
button) is replaced.
-}
scrollDomId : String -> String
scrollDomId tableId =
    tableId ++ "-scroll"


filterInputId : String -> String -> String -> String
filterInputId tableId colId part =
    tableId ++ "-filter-" ++ Internal.sanitizeId colId ++ "-" ++ part
