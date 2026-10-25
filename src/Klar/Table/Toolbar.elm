module Klar.Table.Toolbar exposing (..)

{-| Search, active-filter summaries, density controls and column choices.
-}

import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Events
import Klar.Button as Button
import Klar.Checkbox as Checkbox
import Klar.Icon as Icon
import Klar.Internal as Internal
import Klar.Table.Bulk exposing (viewBulkBar)
import Klar.Table.ColumnLogic exposing (exportValue, findColumn, hasFooter, isShown, isSortable, sortKeyOf, sortLevel, visibleColumns)
import Klar.Table.DomIds exposing (bulkDomId, detailDomId, filterInputId, popupDomId, popupSuffix, rowDomId, scrollDomId, triggerDomId)
import Klar.Table.Export exposing (csvSeparatorOf, exportOptions, viewExportMenu)
import Klar.Table.Filter exposing (activeDrafts, canonicalChoice, choiceLabels, choiceOf, choicesOf, filterTest, fold, localChoice, parseNumber, searchTest, searchText, searchWords, toDraft, toFilter, withinRange)
import Klar.Table.HeaderFilters exposing (filterFocusTargets, filterValues, loadedRows, rangeDecimals, viewChoiceFilter, viewFilterButton, viewFilterContent)
import Klar.Table.Identity exposing (idsOf, isJust, keysBetween, keysOf, lookup, toggled)
import Klar.Table.Numeric exposing (formatNumber, majorAmount, moneyTotals, plainDecimal)
import Klar.Table.Popup exposing (focusLeft, isInside, outsideClick, viewPopup)
import Klar.Table.Selection exposing (clearSelection, deselect, dropAllMatching, dropAllMatchingOf, everyRowCanBeSelected, isLongClientTable, isPicked, isSelected, matchingSelectionState, pick, rowIsDisabled, select, selectableCount, selectableKeys, selectedCount, selectedIds, selection, selectionTotal, setSelectedIds)
import Klar.Table.Types exposing (Align(..), Attribute(..), Column(..), ColumnAttribute(..), ColumnConfig, ColumnId(..), Config, Ctx, Data, DataStatus(..), Direction(..), Draft(..), Filter(..), FilterKind(..), Footer(..), Model, MoneyTotal, Msg(..), Picked(..), Popup(..), Query, RowInfo, Rows(..), Selection(..), SortBy(..), Source(..), State(..))
import Klar.Tag as Tag
import Klar.TextInput as TextInput
import Klar.Theme as Theme exposing (Density(..), Tone)
import Set exposing (Set)


{-| Is there anything for the toolbar to hold? Column filters live in the
header, so a table with only those has no toolbar until a filter is active
(then "2 filters active" and its reset are shown here). A selectable table keeps
its band so the rows do not jump down when the first one is selected.
-}
hasToolbar : Ctx row msg -> Bool
hasToolbar ctx =
    hasTools ctx || ctx.hasSelect || activeFilterCount ctx > 0


{-| Search, refresh, density, columns, export or the application's own buttons.
-}
hasTools : Ctx row msg -> Bool
hasTools ctx =
    let
        config =
            ctx.config
    in
    config.searchable
        || config.columnChooser
        || config.densityToggle
        || config.export
        /= Nothing
        || isJust config.onRefresh
        || not (List.isEmpty config.toolbarActions)


{-| Filters in effect: the table's own and the application's.
-}
activeFilterCount : Ctx row msg -> Int
activeFilterCount ctx =
    List.length (activeDrafts ctx.model)


viewToolbar : Ctx row msg -> Html msg
viewToolbar ctx =
    if not (hasToolbar ctx) then
        Html.text ""

    else
        let
            config =
                ctx.config

            bulk =
                ctx.hasSelect && selectionTotal ctx > 0

            activeCount =
                activeFilterCount ctx
        in
        Html.div [ Internal.cls [ "klar-table__toolbar" ] ]
            [ Html.div
                [ Internal.cls
                    [ "klar-table__tools"
                    , if bulk then
                        "klar-table__tools--covered"

                      else
                        ""
                    ]
                ]
                [ if config.searchable then
                    viewSearch ctx

                  else
                    Html.text ""
                , if activeCount > 0 then
                    viewFilterSummary ctx activeCount

                  else
                    Html.text ""
                , -- the band is only there for the bulk bar: say what it is for
                  if ctx.hasSelect && not (hasTools ctx) && activeCount == 0 then
                    Html.span [ Internal.cls [ "klar-table__tools-note" ] ] [ Html.text ctx.t.noneSelected ]

                  else
                    Html.text ""
                , Html.div [ Internal.cls [ "klar-table__tools-end" ] ]
                    [ Internal.viewMaybe
                        (\msg ->
                            Button.iconOnly
                                [ Button.ghost
                                , Button.loading (config.refreshing || ctx.data.status == Waiting)
                                , Button.onClick msg
                                ]
                                Icon.refresh
                                ctx.t.refresh
                        )
                        config.onRefresh
                    , Internal.viewIf config.densityToggle (viewDensity ctx)
                    , Internal.viewIf config.columnChooser (viewColumnsMenu ctx)
                    , Internal.viewMaybe (viewExportMenu ctx ExportPopup) config.export
                    , Internal.viewIf (not (List.isEmpty config.toolbarActions))
                        (Html.div [ Internal.cls [ "klar-table__app-actions" ] ] config.toolbarActions)
                    ]
                ]
            , if bulk then
                viewBulkBar ctx

              else
                Html.text ""
            ]


viewSearch : Ctx row msg -> Html msg
viewSearch ctx =
    Html.div
        [ Internal.cls [ "klar-table__search" ]

        -- Escape clears the text and is used up: its default is prevented, so a
        -- dialog or drawer that reads defaultPrevented (keys are layered) leaves
        -- it alone; in an empty box it is left to the dialog.
        , Internal.attrIf (ctx.model.searchInput /= "")
            (Internal.onKeys [ ( "Escape", ctx.toMsg (SearchChanged "" 0) ) ])
        ]
        [ TextInput.view
            [ TextInput.id (ctx.model.id ++ "-search")
            , TextInput.label ctx.t.searchLabel
            , TextInput.labelHidden
            , TextInput.search
            , TextInput.clearable
            , TextInput.locale ctx.loc
            , TextInput.placeholder
                (case ctx.config.searchPlaceholder of
                    Just value ->
                        value

                    Nothing ->
                        if ctx.config.server == Nothing then
                            ctx.t.searchPlaceholder ctx.data.available

                        else
                            ctx.t.searchPlaceholder 0
                )
            , TextInput.value ctx.model.searchInput
            , TextInput.onInput (\value -> ctx.toMsg (SearchChanged value ctx.delay))
            ]
        ]


{-| "2 filters active" (opens the list of active filters) and "Reset filters".
-}
viewFilterSummary : Ctx row msg -> Int -> Html msg
viewFilterSummary ctx activeCount =
    let
        isOpen =
            ctx.model.popup == FiltersPopup

        drafts =
            activeDrafts ctx.model
    in
    Html.div [ Internal.cls [ "klar-table__filter-summary" ] ]
        [ Html.div [ Internal.cls [ "klar-anchor" ] ]
            [ Button.view
                [ Button.small
                , Button.icon Icon.filter
                , Button.id (triggerDomId ctx.model.id FiltersPopup)
                , Button.expanded isOpen
                , Button.htmlAttrs [ Attr.attribute "aria-haspopup" "dialog" ]
                , Button.onClick (ctx.toMsg (PopupOpened FiltersPopup []))
                ]
                (ctx.t.filtersActive activeCount)
            , if isOpen then
                viewPopup ctx
                    FiltersPopup
                    { title = ctx.t.activeFilters, alignEnd = False }
                    [ Html.div [ Internal.cls [ "klar-table__popover-body" ] ]
                        [ Html.ul [ Internal.cls [ "klar-table__chips" ] ]
                            (drafts
                                |> List.filterMap
                                    (\( colId, draft ) ->
                                        findColumn colId ctx.allColumns
                                            |> Maybe.map
                                                (\col ->
                                                    Html.li []
                                                        [ Tag.view
                                                            [ Tag.tone Theme.Primary
                                                            , Tag.locale ctx.loc
                                                            , Tag.onRemove (ctx.toMsg (FilterCleared colId))
                                                            ]
                                                            (describeDraft ctx col draft)
                                                        ]
                                                )
                                    )
                            )
                        ]
                    , Html.div [ Internal.cls [ "klar-table__popover-foot" ] ]
                        [ resetFiltersButton ctx [ Button.small, Button.ghost ] ctx.t.resetFilters FiltersCleared
                        , Button.view [ Button.small, Button.onClick (ctx.toMsg PopupClosed) ] ctx.t.done
                        ]
                    ]

              else
                Html.text ""
            ]
        , withAppReset ctx
            (Button.iconOnly
                [ Button.small
                , Button.ghost
                , Button.onClick (ctx.toMsg FiltersCleared)
                ]
                Icon.close
                ctx.t.resetFilters
            )
        ]


{-| A button that clears what its label says ("Reset filters": the column
filters; "Clear search and filters": the search too) and, in the same click,
sends the application's `onResetFilters`.
-}
resetFiltersButton : Ctx row msg -> List (Button.Attribute msg) -> String -> Msg -> Html msg
resetFiltersButton ctx buttonAttributes labelText resetMsg =
    withAppReset ctx (Button.view (buttonAttributes ++ [ Button.onClick (ctx.toMsg resetMsg) ]) labelText)


{-| The click on the button inside bubbles to this wrapper, which sends the
application's `onResetFilters` too.
-}
withAppReset : Ctx row msg -> Html msg -> Html msg
withAppReset ctx button =
    Html.span
        [ Internal.cls [ "klar-table__reset" ]
        , Internal.attrMaybe Events.onClick ctx.config.onResetFilters
        ]
        [ button ]


describeDraft : Ctx row msg -> ColumnConfig row msg -> Draft -> String
describeDraft ctx col draft =
    case draft of
        TextDraft value ->
            ctx.t.describeContains col.title (String.trim value)

        ChoiceDraft values ->
            let
                labelOf =
                    case col.filterValue of
                        Just _ ->
                            choiceLabels ctx.loc col (loadedRows ctx)

                        Nothing ->
                            choiceLabels ctx.loc col []

                list =
                    values |> Set.toList |> List.map (canonicalChoice col >> labelOf)

                shown =
                    List.take 3 list

                more =
                    List.length list - List.length shown
            in
            col.title
                ++ ": "
                ++ String.join ", " shown
                ++ (if more > 0 then
                        " +" ++ String.fromInt more

                    else
                        ""
                   )

        RangeDraft from to ->
            let
                show =
                    formatNumber ctx.loc (rangeDecimals ctx col)
            in
            col.title
                ++ ": "
                ++ (case ( parseNumber from, parseNumber to ) of
                        ( Just low, Just high ) ->
                            show (min low high) ++ "–" ++ show (max low high)

                        ( Just low, Nothing ) ->
                            "≥ " ++ show low

                        ( Nothing, Just high ) ->
                            "≤ " ++ show high

                        ( Nothing, Nothing ) ->
                            ""
                   )


densityCompact : Icon.Icon
densityCompact =
    Icon.fromSvg "table-density-compact" "<line x1='4' y1='4.5' x2='20' y2='4.5'/><line x1='4' y1='9.5' x2='20' y2='9.5'/><line x1='4' y1='14.5' x2='20' y2='14.5'/><line x1='4' y1='19.5' x2='20' y2='19.5'/>"


densityNormal : Icon.Icon
densityNormal =
    Icon.fromSvg "table-density-normal" "<line x1='4' y1='5' x2='20' y2='5'/><line x1='4' y1='12' x2='20' y2='12'/><line x1='4' y1='19' x2='20' y2='19'/>"


densityComfortable : Icon.Icon
densityComfortable =
    Icon.fromSvg "table-density-comfortable" "<rect x='4' y='4' width='16' height='6' rx='1'/><rect x='4' y='14' width='16' height='6' rx='1'/>"


viewDensity : Ctx row msg -> Html msg
viewDensity ctx =
    let
        choice value icon name =
            Button.iconOnly
                [ Button.ghost
                , Button.small
                , Button.pressed (ctx.model.density == value)
                , Button.title (ctx.t.density ++ ": " ++ name)
                , Button.onClick (ctx.toMsg (DensityChanged value))
                ]
                icon
                name
    in
    Html.div
        [ Internal.cls [ "klar-table__density" ]
        , Attr.attribute "role" "group"
        , Attr.attribute "aria-label" ctx.t.density
        ]
        [ choice Compact densityCompact ctx.t.compact
        , choice Normal densityNormal ctx.t.normal
        , choice Comfortable densityComfortable ctx.t.comfortable
        ]


viewColumnsMenu : Ctx row msg -> Html msg
viewColumnsMenu ctx =
    let
        isOpen =
            ctx.model.popup == ColumnsPopup

        shownCount =
            List.length ctx.visible

        checkboxId index =
            ctx.model.id ++ "-column-" ++ String.fromInt index

        isShownColumn col =
            List.any (\v -> v.id == col.id) ctx.visible

        isLocked col =
            not col.hideable || (isShownColumn col && shownCount <= 1)

        -- focus goes to the first checkbox that can be changed
        firstUnlocked =
            ctx.allColumns
                |> List.indexedMap Tuple.pair
                |> List.filter (\( _, col ) -> not (isLocked col))
                |> List.map (Tuple.first >> checkboxId)
                |> List.take 1
    in
    Html.div [ Internal.cls [ "klar-anchor" ] ]
        [ Button.view
            [ Button.ghost
            , Button.icon Icon.columns
            , Button.id (triggerDomId ctx.model.id ColumnsPopup)
            , Button.expanded isOpen
            , Button.htmlAttrs [ Attr.attribute "aria-haspopup" "dialog" ]
            , Button.onClick (ctx.toMsg (PopupOpened ColumnsPopup firstUnlocked))
            ]
            ctx.t.columns
        , if isOpen then
            viewPopup ctx
                ColumnsPopup
                { title = ctx.t.columnsTitle, alignEnd = True }
                [ Html.div [ Internal.cls [ "klar-table__popover-body" ] ]
                    -- The list scrolls: with many columns the popup (fixed
                    -- below the toolbar) would run past the bottom of the
                    -- window, taking "Done" with it.
                    [ Html.div [ Internal.cls [ "klar-table__options", "klar-table__options--scroll" ] ]
                        (List.indexedMap
                            (\index col ->
                                let
                                    shown =
                                        isShownColumn col

                                    locked =
                                        isLocked col
                                in
                                Html.div [ Internal.cls [ "klar-table__option" ] ]
                                    [ Checkbox.view
                                        [ Checkbox.id (checkboxId index)
                                        , Checkbox.label col.title
                                        , Checkbox.checked shown
                                        , Checkbox.disabled locked
                                        , Checkbox.onCheck (\value -> ctx.toMsg (ColumnToggled col.id value))
                                        ]
                                    ]
                            )
                            ctx.allColumns
                        )
                    ]
                , Html.div [ Internal.cls [ "klar-table__popover-foot" ] ]
                    [ Button.view [ Button.small, Button.ghost, Button.onClick (ctx.toMsg ColumnsReset) ] ctx.t.reset
                    , Button.view [ Button.small, Button.onClick (ctx.toMsg PopupClosed) ] ctx.t.done
                    ]
                ]

          else
            Html.text ""
        ]
