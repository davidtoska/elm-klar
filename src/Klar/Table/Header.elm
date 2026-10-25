module Klar.Table.Header exposing (..)

{-| Header cells, sorting controls and system-column headings.
-}

import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Events
import Json.Decode as Decode exposing (Decoder)
import Klar.Checkbox as Checkbox
import Klar.Icon as Icon
import Klar.Internal as Internal
import Klar.Table.ColumnLogic exposing (exportValue, findColumn, hasFooter, isShown, isSortable, sortKeyOf, sortLevel, visibleColumns)
import Klar.Table.HeaderFilters exposing (filterFocusTargets, filterValues, loadedRows, rangeDecimals, viewChoiceFilter, viewFilterButton, viewFilterContent)
import Klar.Table.Identity exposing (idsOf, isJust, keysBetween, keysOf, lookup, toggled)
import Klar.Table.Layout exposing (activeRowHidden, activeRowRequested, alignClass, dataCellClasses, expandWidth, fixedWidth, flexibleMinWidth, flexibleShare, gridPart, hasFocusableContent, headerWidth, isFiltered, isTreegrid, menuWidth, pinLeft, pinStyle, scrollVars, selectWidth, systemCells, systemPinStyle, tableMinWidth, usableFilter, viewColgroup)
import Klar.Table.Selection exposing (clearSelection, deselect, dropAllMatching, dropAllMatchingOf, everyRowCanBeSelected, isLongClientTable, isPicked, isSelected, matchingSelectionState, pick, rowIsDisabled, select, selectableCount, selectableKeys, selectedCount, selectedIds, selection, selectionTotal, setSelectedIds)
import Klar.Table.Types exposing (Align(..), Attribute(..), Column(..), ColumnAttribute(..), ColumnConfig, ColumnId(..), Config, Ctx, Data, DataStatus(..), Direction(..), Draft(..), Filter(..), FilterKind(..), Footer(..), Model, MoneyTotal, Msg(..), Picked(..), Popup(..), Query, RowInfo, Rows(..), Selection(..), SortBy(..), Source(..), State(..))


viewHead : Ctx row msg -> Html msg
viewHead ctx =
    let
        t =
            ctx.t

        pinClass =
            if ctx.pinnedFirst then
                "klar-table__cell--pinned"

            else
                ""

        pageSelected =
            List.filter (isPicked ctx.model.selection) ctx.pageKeys

        ( allOn, someOn ) =
            if isLongClientTable ctx then
                matchingSelectionState ctx

            else
                let
                    all =
                        not (List.isEmpty ctx.pageKeys) && List.length pageSelected == List.length ctx.pageKeys
                in
                ( all, not all && not (List.isEmpty pageSelected) )
    in
    Html.thead [ Internal.cls [ "klar-table__head" ] ]
        [ Html.tr [ Attr.attribute "aria-rowindex" "1", gridPart ctx "row" ]
            (List.concat
                [ if ctx.hasSelect then
                    [ Html.th
                        [ Internal.cls [ "klar-table__th", "klar-table__th--select", pinClass ]
                        , Attr.scope "col"
                        , gridPart ctx "columnheader"
                        , systemPinStyle ctx 0
                        ]
                        [ Checkbox.view
                            [ Checkbox.id (ctx.model.id ++ "-select-page")
                            , Checkbox.ariaLabel t.selectPage
                            , Checkbox.checked allOn
                            , Checkbox.indeterminate someOn
                            , Checkbox.disabled
                                ((if isLongClientTable ctx then
                                    ctx.data.total == 0

                                  else
                                    List.isEmpty ctx.pageKeys
                                 )
                                    || ctx.data.status
                                    /= Ready
                                )
                            , Checkbox.onCheck
                                (\value ->
                                    if isLongClientTable ctx then
                                        ctx.toMsg (RowsSelected (selectableKeys ctx) value)

                                    else
                                        ctx.toMsg (RowsSelected ctx.pageKeys value)
                                )
                            ]
                        ]
                    ]

                  else
                    []
                , if ctx.hasExpand then
                    [ Html.th
                        [ Internal.cls [ "klar-table__th", "klar-table__th--expand", pinClass ]
                        , Attr.scope "col"
                        , gridPart ctx "columnheader"
                        , systemPinStyle ctx
                            (if ctx.hasSelect then
                                selectWidth

                             else
                                0
                            )
                        ]
                        [ Html.span [ Internal.cls [ "klar-sr-only" ] ] [ Html.text t.details ] ]
                    ]

                  else
                    []
                , List.indexedMap (viewHeaderCell ctx) ctx.visible
                , if ctx.hasMenu then
                    [ Html.th [ Internal.cls [ "klar-table__th", "klar-table__th--menu" ], Attr.scope "col", gridPart ctx "columnheader" ]
                        [ Html.span [ Internal.cls [ "klar-sr-only" ] ] [ Html.text t.actions ] ]
                    ]

                  else
                    []
                ]
            )
        ]


viewHeaderCell : Ctx row msg -> Int -> ColumnConfig row msg -> Html msg
viewHeaderCell ctx index col =
    let
        model =
            ctx.model

        direction =
            lookup col.id model.sort

        sortPosition =
            model.sort
                |> List.indexedMap (\i ( colId, _ ) -> ( colId, i + 1 ))
                |> lookup col.id

        isPrimary =
            sortPosition == Just 1

        sortable =
            isSortable col

        pinnedHere =
            index == 0 && ctx.pinnedFirst

        filterOpen =
            model.popup == FilterPopup col.id

        sortIcon =
            Html.span
                [ Internal.cls
                    [ "klar-table__sort-icon"
                    , if direction /= Nothing then
                        "klar-table__sort-icon--active"

                      else
                        ""
                    ]
                , Attr.attribute "aria-hidden" "true"
                ]
                [ Icon.sized Icon.Small
                    (case direction of
                        Just Ascending ->
                            Icon.arrowUp

                        Just Descending ->
                            Icon.arrowDown

                        Nothing ->
                            Icon.chevronsUpDown
                    )
                , case ( sortPosition, List.length model.sort > 1 ) of
                    ( Just position, True ) ->
                        Html.span [ Internal.cls [ "klar-table__sort-order" ] ] [ Html.text (String.fromInt position) ]

                    _ ->
                        Html.text ""
                ]

        titleSpan =
            Html.span
                [ Internal.cls
                    [ "klar-table__title"
                    , if col.controls then
                        "klar-sr-only"

                      else
                        ""
                    ]
                ]
                [ Html.text col.title ]

        heading =
            if sortable then
                Html.button
                    [ Internal.cls [ "klar-table__sort" ]
                    , Attr.type_ "button"
                    , Attr.title
                        (case col.hint of
                            Just value ->
                                value

                            Nothing ->
                                if ctx.config.multiSort then
                                    ctx.t.multiSortHint

                                else
                                    ctx.t.sortHint
                        )
                    , Events.on "click"
                        (Decode.field "shiftKey" Decode.bool
                            |> Decode.map (\shift -> ctx.toMsg (SortClicked col.id (shift && ctx.config.multiSort)))
                        )
                    ]
                    (if col.align == AlignRight then
                        [ sortIcon, titleSpan ]

                     else
                        [ titleSpan, sortIcon ]
                    )

            else
                Html.span
                    [ Internal.cls [ "klar-table__label" ]
                    , Internal.attrMaybe Attr.title col.hint
                    ]
                    [ titleSpan ]

        filterControl =
            case usableFilter col of
                Just _ ->
                    viewFilterButton ctx col filterOpen

                Nothing ->
                    Html.text ""
    in
    Html.th
        [ Internal.cls
            [ "klar-table__th"
            , alignClass "klar-table__th" col.align
            , if pinnedHere then
                "klar-table__cell--pinned klar-table__cell--pin-edge"

              else
                ""
            , if filterOpen then
                "klar-table__th--open"

              else
                ""
            ]
        , Attr.scope "col"
        , gridPart ctx "columnheader"
        , if pinnedHere then
            Internal.styleVars [ ( "--_pin-left", Internal.px (pinLeft ctx) ) ]

          else
            Internal.noAttr
        , case ( direction, isPrimary ) of
            ( Just Ascending, True ) ->
                Attr.attribute "aria-sort" "ascending"

            ( Just Descending, True ) ->
                Attr.attribute "aria-sort" "descending"

            _ ->
                Internal.attrIf sortable (Attr.attribute "aria-sort" "none")
        ]
        [ Html.div [ Internal.cls [ "klar-table__heading", alignClass "klar-table__heading" col.align ] ]
            (if col.align == AlignRight then
                [ filterControl, heading ]

             else
                [ heading, filterControl ]
            )
        ]
