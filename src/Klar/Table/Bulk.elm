module Klar.Table.Bulk exposing (..)

{-| Bulk-selection controls and their announcement and export actions.
-}

import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Events
import Json.Decode as Decode exposing (Decoder)
import Klar.Button as Button
import Klar.Internal as Internal
import Klar.Table.DomIds exposing (bulkDomId, detailDomId, filterInputId, popupDomId, popupSuffix, rowDomId, scrollDomId, triggerDomId)
import Klar.Table.Export exposing (csvSeparatorOf, exportOptions, viewExportMenu)
import Klar.Table.Selection exposing (clearSelection, deselect, dropAllMatching, dropAllMatchingOf, everyRowCanBeSelected, isLongClientTable, isPicked, isSelected, matchingSelectionState, pick, rowIsDisabled, select, selectableCount, selectableKeys, selectedCount, selectedIds, selection, selectionTotal, setSelectedIds)
import Klar.Table.Types exposing (Align(..), Attribute(..), Column(..), ColumnAttribute(..), ColumnConfig, ColumnId(..), Config, Ctx, Data, DataStatus(..), Direction(..), Draft(..), Filter(..), FilterKind(..), Footer(..), Model, MoneyTotal, Msg(..), Picked(..), Popup(..), Query, RowInfo, Rows(..), Selection(..), SortBy(..), Source(..), State(..))
import Set exposing (Set)


viewBulkBar : Ctx row msg -> Html msg
viewBulkBar ctx =
    let
        t =
            ctx.t

        count =
            selectionTotal ctx

        allPageSelected =
            not (List.isEmpty ctx.pageKeys) && List.all (isPicked ctx.model.selection) ctx.pageKeys

        clientMode =
            ctx.config.server == Nothing

        -- client mode: what "select all N matching" selects (matching rows that are not disabled)
        selectableTotal =
            if clientMode then
                selectableCount ctx

            else
                ctx.data.total

        allMatchingSelected =
            case ctx.model.selection of
                AllPicked except ->
                    Set.isEmpty except

                Picked keys ->
                    clientMode
                        && selectableTotal
                        > 0
                        && Set.size keys
                        >= selectableTotal
                        && (everyRowCanBeSelected ctx || List.all (\key -> Set.member key keys) (selectableKeys ctx))

        note value =
            Html.span [ Internal.cls [ "klar-table__bulk-note" ] ] [ Html.text value ]

        -- Selected rows the user cannot see. Client mode knows they are left out
        -- by the search or a filter. A server only gives the current page, so
        -- there it is "not on this page": other pages, or rows a new search
        -- or filter took away. Either way the count in the bar is not a
        -- surprise when a bulk action then acts on all of them.
        hiddenCount =
            case ( ctx.model.selection, ctx.config.server, ctx.config.rowId ) of
                ( Picked keys, Nothing, Just toId ) ->
                    if Set.isEmpty keys || ctx.data.total == ctx.data.available then
                        -- no row is left out, so none of the selected rows is out of sight
                        0

                    else
                        Set.size keys - ctx.data.countMatching (\_ row -> Set.member (toId row) keys)

                ( Picked keys, Just _, _ ) ->
                    Set.size keys - List.length (List.filter (\key -> Set.member key keys) ctx.pageKeys)

                _ ->
                    0

        hiddenNote =
            note
                (if clientMode then
                    t.hiddenSelected hiddenCount

                 else
                    t.selectedElsewhere hiddenCount
                )

        prompt =
            if allMatchingSelected && selectableTotal > List.length ctx.pageKeys then
                note (t.allMatching selectableTotal)
                    :: (if hiddenCount > 0 then
                            [ hiddenNote ]

                        else
                            []
                       )

            else if allPageSelected && selectableTotal > List.length ctx.pageKeys then
                [ note (t.allOnPage (List.length ctx.pageKeys))
                , Button.view
                    [ Button.link
                    , if clientMode then
                        -- the keys of every matching row are found when the button is
                        -- clicked, not on every render while it is shown
                        Button.htmlAttrs
                            [ Events.on "click"
                                (Decode.succeed ()
                                    |> Decode.map (\_ -> ctx.toMsg (MatchingSelected (selectableKeys ctx)))
                                )
                            ]

                      else
                        Button.onClick (ctx.toMsg AllMatchingPicked)
                    ]
                    (t.selectAllMatching selectableTotal)
                ]

            else if hiddenCount > 0 then
                [ hiddenNote ]

            else
                []
    in
    Html.div
        [ Internal.cls [ "klar-table__bulk" ]
        , Attr.id (bulkDomId ctx.model.id)
        , Attr.tabindex -1
        , Attr.attribute "role" "region"
        , Attr.attribute "aria-label" (t.selected count)
        ]
        [ Html.span [ Internal.cls [ "klar-table__bulk-count", "klar-tabular" ] ] [ Html.text (t.selected count) ]
        , Html.div [ Internal.cls [ "klar-table__bulk-prompt" ] ] prompt
        , Html.div [ Internal.cls [ "klar-table__bulk-actions" ] ]
            ((case ctx.config.export of
                Just filename ->
                    [ viewExportMenu ctx BulkExportPopup filename ]

                Nothing ->
                    []
             )
                ++ ctx.config.bulkActions
                ++ [ Button.view
                        [ Button.small
                        , Button.ghost
                        , Button.onClick (ctx.toMsg (SelectionCleared (ctx.model.id ++ "-select-page")))
                        ]
                        t.cancel
                   ]
            )
        ]
