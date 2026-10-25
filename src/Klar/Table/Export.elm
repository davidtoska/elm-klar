module Klar.Table.Export exposing (..)

{-| The export menu for matching, page and selected rows.
-}

import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Events
import Json.Decode as Decode exposing (Decoder)
import Klar.Button as Button
import Klar.Icon as Icon
import Klar.Internal as Internal
import Klar.Locale as Locale exposing (Locale)
import Klar.Remote as Remote exposing (Problem, Remote)
import Klar.Table.CsvRows exposing (csvText, withSuffix)
import Klar.Table.DomIds exposing (bulkDomId, detailDomId, filterInputId, popupDomId, popupSuffix, rowDomId, scrollDomId, triggerDomId)
import Klar.Table.Popup exposing (focusLeft, isInside, outsideClick, viewPopup)
import Klar.Table.Processing exposing (keepMatching, process, processClient, sortLevels, sortRows)
import Klar.Table.Rows exposing (prepareRows, rowsArray, sourceArray, sourceList, usablePrepared)
import Klar.Table.Selection exposing (clearSelection, deselect, dropAllMatching, dropAllMatchingOf, everyRowCanBeSelected, isLongClientTable, isPicked, isSelected, matchingSelectionState, pick, rowIsDisabled, select, selectableCount, selectableKeys, selectedCount, selectedIds, selection, selectionTotal, setSelectedIds)
import Klar.Table.Types exposing (Align(..), Attribute(..), Column(..), ColumnAttribute(..), ColumnConfig, ColumnId(..), Config, Ctx, Data, DataStatus(..), Direction(..), Draft(..), Filter(..), FilterKind(..), Footer(..), Model, MoneyTotal, Msg(..), Picked(..), Popup(..), Query, RowInfo, Rows(..), Selection(..), SortBy(..), Source(..), State(..))


{-| The export menu, in the toolbar (`ExportPopup`) or in the bulk action bar
(`BulkExportPopup`, the selected rows first).
-}
viewExportMenu : Ctx row msg -> Popup -> String -> Html msg
viewExportMenu ctx popup filename =
    let
        isOpen =
            ctx.model.popup == popup

        inBulkBar =
            popup == BulkExportPopup
    in
    Html.div [ Internal.cls [ "klar-anchor" ] ]
        [ Button.view
            [ if inBulkBar then
                Button.small

              else
                Button.ghost
            , Button.icon Icon.download
            , Button.id (triggerDomId ctx.model.id popup)
            , Button.expanded isOpen
            , Button.disabled (ctx.data.status /= Ready)
            , Button.htmlAttrs [ Attr.attribute "aria-haspopup" "dialog" ]
            , Button.onClick (ctx.toMsg (PopupOpened popup [ popupDomId ctx.model.id popup ++ "-option-0" ]))
            ]
            ctx.t.export
        , if isOpen then
            viewPopup ctx popup { title = ctx.t.exportTitle, alignEnd = True } (exportOptions ctx popup filename)

          else
            Html.text ""
        ]


{-| The download buttons. The CSV text of a choice is written only when its
button is clicked (in the click decoder), never on a render, and the file is
saved from `update` with `File.Download.string`, which has no size limit (a
`data:` link stops at the length of a URL, a few megabytes).
-}
exportOptions : Ctx row msg -> Popup -> String -> List (Html msg)
exportOptions ctx popup filename =
    let
        separator =
            csvSeparatorOf ctx

        exported =
            List.filter .exported ctx.visible

        -- the whole page in server mode, also when `virtual` draws only part of it
        pageRows =
            ctx.data.pageAll

        selectedRows =
            case ( ctx.config.rows, ctx.config.server ) of
                ( Remote.Loaded source, Nothing ) ->
                    sourceList source
                        |> List.indexedMap Tuple.pair
                        |> List.filter (\( index, row ) -> isPicked ctx.model.selection (ctx.keyOf index row))
                        |> List.map Tuple.second
                        |> sortRows ctx.config ctx.model ctx.allColumns

                _ ->
                    pageRows
                        |> List.indexedMap Tuple.pair
                        |> List.filter (\( index, row ) -> isPicked ctx.model.selection (ctx.keyOf (ctx.data.offset + index) row))
                        |> List.map Tuple.second

        option index title suffix choice =
            Html.button
                [ Internal.cls [ "klar-table__export-option" ]
                , Attr.type_ "button"
                , Attr.id (popupDomId ctx.model.id popup ++ "-option-" ++ String.fromInt index)
                , Events.on "click"
                    (Decode.succeed ()
                        |> Decode.map
                            (\_ -> ctx.toMsg (ExportClicked (withSuffix suffix filename) (csvText separator exported ctx.loc (choice.rows ()))))
                    )
                ]
                [ Icon.view Icon.download
                , Html.span [ Internal.cls [ "klar-table__export-label" ] ] [ Html.text title ]
                , Html.span [ Internal.cls [ "klar-table__export-count", "klar-tabular" ] ] [ Html.text (ctx.t.rowCount choice.count) ]
                ]

        allChoice =
            if ctx.config.server == Nothing then
                Just ( ctx.t.exportAll, "", { count = ctx.data.total, rows = ctx.data.matchingRows } )

            else
                Nothing

        -- In server mode only the current page is here. A file of "the selected
        -- rows" that lacks the ones on other pages would be wrong without a sign,
        -- so it is offered only when every selected row is on this page.
        offPage =
            if ctx.config.server == Nothing then
                0

            else
                max 0 (selectionTotal ctx - List.length selectedRows)

        selectedChoice =
            if ctx.hasSelect && not (List.isEmpty selectedRows) && offPage == 0 then
                Just ( ctx.t.exportSelected, ctx.t.fileSelected, { count = List.length selectedRows, rows = \_ -> selectedRows } )

            else
                Nothing

        pageChoice =
            { count = List.length pageRows, rows = \_ -> pageRows }

        pageOption =
            if ctx.config.paged && ctx.data.pageCount > 1 then
                Just ( ctx.t.exportPage, ctx.t.filePage ctx.data.page, pageChoice )

            else
                Nothing

        choices =
            (if popup == BulkExportPopup then
                [ selectedChoice, allChoice, pageOption ]

             else
                [ allChoice, selectedChoice, pageOption ]
            )
                |> List.filterMap identity
                |> (\list ->
                        if List.isEmpty list then
                            [ ( ctx.t.exportPage, "", pageChoice ) ]

                        else
                            list
                   )
    in
    [ Html.div [ Internal.cls [ "klar-table__popover-body", "klar-table__popover-body--flush" ] ]
        (List.indexedMap (\index ( title, suffix, choice ) -> option index title suffix choice) choices)
    , Internal.viewIf (ctx.hasSelect && offPage > 0)
        (Html.p [ Internal.cls [ "klar-table__popover-note" ] ]
            [ Html.text (ctx.t.selectionOffPage offPage (selectionTotal ctx)) ]
        )
    , Html.p [ Internal.cls [ "klar-table__popover-note", "klar-table__popover-note--foot" ] ]
        [ Html.text (ctx.t.exportNote (List.length exported) separator) ]
    ]


{-| The field separator of the export: `csvSeparator`, or a comma in English and a
semicolon in Norwegian.
-}
csvSeparatorOf : Ctx row msg -> Char
csvSeparatorOf ctx =
    Maybe.withDefault (Locale.pick ctx.loc { nb = ';', en = ',' }) ctx.config.csvSeparator
