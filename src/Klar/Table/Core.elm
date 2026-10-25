module Klar.Table.Core exposing (..)

{-| The table implementation behind its documented, representation-stable public boundary.
-}

import Array exposing (Array)
import Browser.Dom as Dom
import Dict exposing (Dict)
import File.Download as Download
import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Events
import Html.Keyed
import Json.Decode as Decode exposing (Decoder)
import Json.Encode as Encode
import Klar.Badge as Badge
import Klar.Button as Button
import Klar.Checkbox as Checkbox
import Klar.Date as Date exposing (Date)
import Klar.EmptyState as EmptyState
import Klar.ErrorState as ErrorState
import Klar.Format as Format
import Klar.Icon as Icon
import Klar.Ids as Ids exposing (Ids)
import Klar.Internal as Internal
import Klar.Internal.Freshness as Freshness exposing (Freshness)
import Klar.Internal.Window as Window
import Klar.Locale as Locale exposing (Locale)
import Klar.Menu as Menu
import Klar.Money as Money exposing (Money)
import Klar.Pagination as Pagination
import Klar.Remote as Remote exposing (Problem, Remote)
import Klar.Search as Search
import Klar.Settings as Settings exposing (Settings)
import Klar.Skeleton as Skeleton
import Klar.Spinner as Spinner
import Klar.Table.Bulk exposing (viewBulkBar)
import Klar.Table.ColumnLogic exposing (exportValue, findColumn, hasFooter, isShown, isSortable, sortKeyOf, sortLevel, visibleColumns)
import Klar.Table.Columns exposing (actions, alignCenter, alignRight, alwaysVisible, badge, baseColumn, bool, build, cell, custom, date, exportAs, filterOptions, filterRange, filterSelect, filterText, filterValue, float, footer, footerAverage, footerSum, hiddenByDefault, hint, includeInSearch, int, maybeDate, minWidth, money, noTooltip, notExported, notSearchable, pinned, sortDate, sortMaybeNumber, sortNumber, sortText, sortWith, status, text, unsortable, width, wrap)
import Klar.Table.Config exposing (activeExternalFilters, ariaLabel, bulkActions, columnChooser, columns, configure, csvSeparator, currentRow, densityToggle, emptyState, expandedRow, exportCsv, fillHeight, finish, locale, maxHeight, multiSort, onRefresh, onResetFilters, onRetry, onRowClick, pageSizes, rangeText, remote, remotePrepared, rowActions, rowDisabled, rowFilter, rowId, rowLabel, rowTone, searchDebounce, searchPlaceholder, searchable, selectable, server, settings, toolbarActions, unpaged, virtual, zebra)
import Klar.Table.Csv as Csv
import Klar.Table.CsvRows exposing (csvText, withSuffix)
import Klar.Table.DomIds exposing (bulkDomId, detailDomId, filterInputId, popupDomId, popupSuffix, rowDomId, scrollDomId, triggerDomId)
import Klar.Table.Export exposing (csvSeparatorOf, exportOptions, viewExportMenu)
import Klar.Table.Filter exposing (activeDrafts, canonicalChoice, choiceLabels, choiceOf, choicesOf, filterTest, fold, localChoice, parseNumber, searchTest, searchText, searchWords, toDraft, toFilter, withinRange)
import Klar.Table.HeaderFilters exposing (filterFocusTargets, filterValues, loadedRows, rangeDecimals, viewChoiceFilter, viewFilterButton, viewFilterContent)
import Klar.Table.Identity exposing (idsOf, isJust, keysBetween, keysOf, lookup, toggled)
import Klar.Table.Index as Index exposing (Index)
import Klar.Table.Keyboard exposing (ignoreControls, rangeKeys, rangeMsg, rowContextMenu, rowKeyMsg, rowKeys, startsOnControl)
import Klar.Table.Layout exposing (activeRowHidden, activeRowRequested, alignClass, dataCellClasses, expandWidth, fixedWidth, flexibleMinWidth, flexibleShare, gridPart, hasFocusableContent, headerWidth, isFiltered, isTreegrid, menuWidth, pinLeft, pinStyle, scrollVars, selectWidth, systemCells, systemPinStyle, tableMinWidth, usableFilter, viewColgroup)
import Klar.Table.Numeric exposing (formatNumber, majorAmount, moneyTotals, plainDecimal)
import Klar.Table.Popup exposing (focusLeft, isInside, outsideClick, viewPopup)
import Klar.Table.Processing exposing (keepMatching, process, processClient, sortLevels, sortRows)
import Klar.Table.Query exposing (encodeQuery, filterDecoder, optionalField, queryDecoder, sortDecoder)
import Klar.Table.Rows exposing (prepareRows, rowsArray, sourceArray, sourceList, usablePrepared)
import Klar.Table.Selection exposing (clearSelection, deselect, dropAllMatching, dropAllMatchingOf, everyRowCanBeSelected, isLongClientTable, isPicked, isSelected, matchingSelectionState, pick, rowIsDisabled, select, selectableCount, selectableKeys, selectedCount, selectedIds, selection, selectionTotal, setSelectedIds)
import Klar.Table.Sort as Sorting
import Klar.Table.State exposing (clearFilters, collapse, collapseAll, columnId, columnName, density, expand, expandedIds, filters, init, isColumnVisible, isExpanded, page, pageSize, query, search, setColumnVisible, setDensity, setExpandedIds, setFilter, setPage, setPageSize, setQuery, setSearch, setSort, settled, sort, toggle)
import Klar.Table.Texts as Texts exposing (Texts)
import Klar.Table.Types exposing (Align(..), Attribute(..), Column(..), ColumnAttribute(..), ColumnConfig, ColumnId(..), Config, Ctx, Data, DataStatus(..), Direction(..), Draft(..), Filter(..), FilterKind(..), Footer(..), Model, MoneyTotal, Msg(..), Picked(..), Popup(..), Query, RowInfo, Rows(..), Selection(..), SortBy(..), Source(..), State(..))
import Klar.Table.Update exposing (afterClear, commit, focus, focusFirst, nextSort, schedule, scrollThenFocus, scrollTo, step, update)
import Klar.Table.Window exposing (defaultVirtualHeight, headPx, pageWindow, rowPx, virtualGeometry, virtualWindow)
import Klar.Tag as Tag
import Klar.TextInput as TextInput
import Klar.Theme as Theme exposing (Density(..), Tone)
import Process
import Set exposing (Set)
import Task


{-| Draws the table: toolbar, header, rows, totals row and pagination. `toMsg`
wraps the table's own messages, usually the constructor you handle in `update`.
The attributes describe the table (columns, rows, options) and are given on every
call; the `State` only holds what the user changed.

    Table.view TableMsg [ Table.columns columns, Table.remote model.orders ] model.table

-}
view : (Msg -> msg) -> List (Attribute id row msg) -> State id -> Html msg
view toMsg attributes (State model) =
    let
        config =
            configure attributes

        allColumns =
            List.map (\(Column col) -> col) config.columns

        visible =
            visibleColumns model allColumns

        data =
            process config model allColumns visible

        loc =
            config.locale

        keyOf index row =
            case config.rowId of
                Just toId ->
                    toId row

                Nothing ->
                    String.fromInt index

        labelOf row =
            case config.rowLabel of
                Just toLabel ->
                    toLabel row

                Nothing ->
                    case visible of
                        first :: _ ->
                            first.value loc row

                        [] ->
                            ""

        -- Selection and open rows are kept by row id. Without `rowId` they would
        -- be kept by position and follow the place, not the row, after a sort or
        -- a filter (and a bulk action would act on other rows), so the table
        -- draws no checkboxes and no details at all: the mistake shows at once.
        hasSelect =
            config.selectable && isJust config.rowId

        hasExpand =
            isJust config.expandedRow && isJust config.rowId

        hasMenu =
            isJust config.rowActions

        rowCount =
            data.rowCount

        isDisabled row =
            case config.rowDisabled of
                Just test ->
                    test row

                Nothing ->
                    False

        pageKeys =
            data.pageAll
                |> List.indexedMap (\i row -> ( keyOf (data.offset + i) row, isDisabled row ))
                |> List.filter (\( _, disabled ) -> not disabled)
                |> List.map Tuple.first

        ctx =
            { toMsg = toMsg
            , config = config
            , model = model
            , t = Texts.texts loc
            , loc = loc
            , allColumns = allColumns
            , visible = visible
            , data = data
            , keyOf = keyOf
            , labelOf = labelOf
            , delay =
                case config.searchDebounce of
                    Just ms ->
                        ms

                    Nothing ->
                        if config.server /= Nothing then
                            350

                        else
                            0
            , hasSelect = hasSelect
            , hasExpand = hasExpand
            , hasMenu = hasMenu
            , pinnedFirst =
                case visible of
                    first :: _ ->
                        first.pinned

                    [] ->
                        False
            , colCount =
                List.length visible
                    + (if hasSelect then
                        1

                       else
                        0
                      )
                    + (if hasExpand then
                        1

                       else
                        0
                      )
                    + (if hasMenu then
                        1

                       else
                        0
                      )
            , interactiveRows = isJust config.onRowClick || hasSelect || hasExpand || hasMenu
            , activeRow =
                if model.activeRow < rowCount then
                    model.activeRow

                else
                    0
            , rowCount = rowCount
            , pageKeys = pageKeys
            , geometry = virtualGeometry config model rowCount
            }
    in
    Html.div
        [ Internal.cls
            [ "klar-table"
            , "klar-table--" ++ Internal.densitySuffix model.density
            , if config.zebra then
                "klar-table--zebra"

              else
                ""
            , if config.refreshing && data.status == Ready then
                "klar-table--refreshing"

              else
                ""
            , if config.fillHeight then
                "klar-table--fill"

              else
                ""
            , if ctx.pinnedFirst then
                "klar-table--pinned"

              else
                ""
            , if config.virtual then
                "klar-table--virtual"

              else
                ""
            ]
        , Attr.id model.id
        , Internal.attrIf config.virtual (Internal.styleVars [ ( "--_row-h", Internal.px ctx.geometry.rowHeight ) ])
        ]
        [ viewToolbar ctx
        , case config.freshness of
            Freshness.Stale _ ->
                -- the retry button goes away when the data is fresh: focus waits on the table
                Html.div [ Events.on "click" (retryClicked ctx) ]
                    [ Freshness.notice
                        { locale = config.locale, settings = config.settings, onRetry = config.onRetry, inline = False }
                        config.freshness
                    ]

            _ ->
                Html.text ""
        , viewFrame ctx
        , viewFooter ctx
        , Html.div [ Internal.cls [ "klar-sr-only" ], Attr.attribute "role" "status", Attr.attribute "aria-live" "polite" ]
            [ Html.text (liveSummary ctx) ]

        -- "3 selected" when the selection changes; always there, so that the first
        -- selection is announced too, and empty when nothing is selected
        , Internal.viewIf hasSelect
            (Html.div [ Internal.cls [ "klar-sr-only" ], Attr.attribute "aria-live" "polite", Attr.id (model.id ++ "-selection-status") ]
                [ Html.text
                    (if selectionTotal ctx > 0 then
                        ctx.t.selected (selectionTotal ctx)

                     else
                        ""
                    )
                ]
            )
        ]


liveSummary : Ctx row msg -> String
liveSummary ctx =
    case ctx.data.status of
        Waiting ->
            ctx.t.loading

        Failed _ ->
            ""

        Ready ->
            if ctx.config.refreshing then
                ctx.t.refreshing

            else
                let
                    ( first, last ) =
                        if ctx.config.paged then
                            Pagination.range { page = ctx.data.page, pageSize = ctx.model.pageSize, total = ctx.data.total }

                        else
                            ( min 1 ctx.data.total, ctx.data.total )

                    counted =
                        if ctx.data.total == 0 then
                            ctx.t.noRows

                        else
                            ctx.t.summary first last ctx.data.total

                    sorted =
                        case ctx.model.sort of
                            ( colId, direction ) :: _ ->
                                case findColumn colId ctx.allColumns of
                                    Just col ->
                                        " " ++ ctx.t.sortedBy col.title (direction == Descending)

                                    Nothing ->
                                        ""

                            [] ->
                                ""
                in
                counted ++ sorted



-- TOOLBAR


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


viewFrame : Ctx row msg -> Html msg
viewFrame ctx =
    let
        config =
            ctx.config

        busy =
            ctx.data.status == Waiting || (config.refreshing && ctx.data.status == Ready)
    in
    Html.div [ Internal.cls [ "klar-table__frame" ] ]
        [ Html.div
            ([ Internal.cls [ "klar-table__scroll" ]
             , Attr.id (scrollDomId ctx.model.id)

             -- Not a tab stop: only a place for focus to wait (see RetryClicked).
             -- A table with nothing to focus in it is left alone: Chrome makes
             -- such a scroll area focusable, so it can be scrolled with the keys.
             -- One that scrolls is a tab stop while the row that Tab should reach
             -- is not drawn, and hands the focus to that row. With onResetFilters
             -- it can always take focus: it is where focus goes after "Reset
             -- filters" when the table has no search box or filter button.
             , Internal.attrIf (hasFocusableContent ctx || isJust config.onResetFilters)
                (Attr.tabindex
                    (if activeRowHidden ctx then
                        0

                     else
                        -1
                    )
                )
             , Internal.attrIf (config.virtual && activeRowHidden ctx) (Events.on "focus" (activeRowRequested ctx))
             , Internal.attrIf config.virtual (Events.on "scroll" (Decode.map (Scrolled >> ctx.toMsg) (Decode.at [ "target", "scrollTop" ] Decode.float)))
             , case scrollVars ctx of
                [] ->
                    Internal.noAttr

                vars ->
                    Internal.styleVars vars
             ]
                ++ (case config.label of
                        Just name ->
                            [ Attr.attribute "role" "region", Attr.attribute "aria-label" name ]

                        Nothing ->
                            []
                   )
            )
            [ let
                tableAttributes =
                    [ Internal.cls [ "klar-table__table" ]
                    , Internal.styleVars [ ( "min-width", Internal.px (tableMinWidth ctx) ) ]

                    -- Rows that expand make a tree grid (see isTreegrid): screen
                    -- readers then leave the arrow keys to the rows. Every other
                    -- table, also one whose rows take focus, stays a table.
                    , Internal.attrIf (isTreegrid ctx) (Attr.attribute "role" "treegrid")
                    , Internal.attrIf (isTreegrid ctx && ctx.hasSelect) (Attr.attribute "aria-multiselectable" "true")
                    , Internal.attrMaybe (Attr.attribute "aria-label") config.label
                    , Attr.attribute "aria-rowcount"
                        (if ctx.data.status == Ready then
                            String.fromInt (ctx.data.total + 1)

                         else
                            "-1"
                        )
                    , Attr.attribute "aria-colcount" (String.fromInt ctx.colCount)
                    , Internal.attrIf busy (Attr.attribute "aria-busy" "true")
                    ]

                parts =
                    List.concat
                        [ [ ( "colgroup", viewColgroup ctx ), ( "head", viewHead ctx ) ]
                        , viewBodies ctx
                        , [ ( "foot", viewFoot ctx ) ]
                        ]
              in
              if config.virtual then
                -- the chunks of rows come and go at the ends, and keys keep the others where they are
                Html.Keyed.node "table" tableAttributes parts

              else
                Html.table tableAttributes (List.map Tuple.second parts)
            ]
        , Html.div [ Internal.cls [ "klar-table__edge", "klar-table__edge--start" ], Attr.attribute "aria-hidden" "true" ] []
        , Html.div [ Internal.cls [ "klar-table__edge", "klar-table__edge--end" ], Attr.attribute "aria-hidden" "true" ] []
        , Internal.viewIf (config.refreshing && ctx.data.status == Ready)
            (Html.div [ Internal.cls [ "klar-table__progress" ], Attr.attribute "aria-hidden" "true" ] [])
        ]


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


viewBody : Ctx row msg -> Html msg
viewBody ctx =
    Html.Keyed.node "tbody"
        [ Internal.cls [ "klar-table__body" ] ]
        (case ctx.data.status of
            Waiting ->
                skeletonRows ctx

            Failed problem ->
                [ ( "state-error"
                  , stateRow ctx
                        -- the click on "Try again" bubbles to the wrapper, which
                        -- keeps focus in the table when the button goes away
                        (Html.div [ Events.on "click" (retryClicked ctx) ]
                            [ ErrorState.view
                                (List.filterMap identity
                                    [ Just ErrorState.compact
                                    , Just (ErrorState.locale ctx.loc)
                                    , Maybe.map ErrorState.onRetry ctx.config.onRetry
                                    ]
                                )
                                problem
                            ]
                        )
                  )
                ]

            Ready ->
                if List.isEmpty ctx.data.pageRows then
                    [ ( "state-empty", stateRow ctx (viewEmpty ctx) ) ]

                else
                    ctx.data.pageRows
                        |> List.indexedMap (\i row -> viewRowAndDetail ctx (ctx.data.first + i) row)
                        |> List.concat
        )


{-| The bodies of the table: one, or for a table that scrolls the empty room
above the rows in view, the rows in chunks of a `tbody` each, and the empty room
below them.
-}
viewBodies : Ctx row msg -> List ( String, Html msg )
viewBodies ctx =
    if ctx.config.virtual && ctx.data.status == Ready && not (List.isEmpty ctx.data.pageRows) then
        let
            after =
                ctx.data.rowCount - ctx.data.first - List.length ctx.data.pageRows

            chunk =
                virtualWindow.chunk

            chunks =
                ctx.data.pageRows
                    |> List.indexedMap (\i row -> ( ctx.data.first + i, row ))
                    |> List.foldr
                        (\( index, row ) groups ->
                            case groups of
                                ( number, members ) :: rest ->
                                    if number == index // chunk then
                                        ( number, ( index, row ) :: members ) :: rest

                                    else
                                        ( index // chunk, [ ( index, row ) ] ) :: groups

                                [] ->
                                    [ ( index // chunk, [ ( index, row ) ] ) ]
                        )
                        []
        in
        List.concat
            [ spacerBody ctx "top" ctx.data.first
            , List.map
                (\( number, members ) ->
                    ( "chunk-" ++ String.fromInt number
                    , Html.Keyed.node "tbody"
                        [ Internal.cls [ "klar-table__body" ] ]
                        (List.concatMap (\( index, row ) -> viewRowAndDetail ctx index row) members)
                    )
                )
                chunks
            , spacerBody ctx "bottom" after
            ]

    else
        [ ( "body", viewBody ctx ) ]


{-| The room of the rows of a table that scrolls that are not drawn.
-}
spacerBody : Ctx row msg -> String -> Int -> List ( String, Html msg )
spacerBody ctx place count =
    if count <= 0 then
        []

    else
        [ ( "spacer-" ++ place
          , Html.tbody [ Internal.cls [ "klar-table__spacer-body" ], Attr.attribute "aria-hidden" "true" ]
                [ Html.tr [ Internal.styleVars [ ( "height", Internal.px (count * ctx.geometry.rowHeight) ) ] ]
                    [ Html.td [ Attr.colspan ctx.colCount ] [] ]
                ]
          )
        ]


{-| A click on the retry button (the error state has no other control).
-}
retryClicked : Ctx row msg -> Decoder msg
retryClicked ctx =
    Decode.field "target" (startsOnControl 0)
        |> Decode.andThen
            (\onControl ->
                if onControl then
                    Decode.succeed (ctx.toMsg RetryClicked)

                else
                    Decode.fail "not the retry button"
            )


stateRow : Ctx row msg -> Html msg -> Html msg
stateRow ctx content =
    Html.tr [ Internal.cls [ "klar-table__state-row" ], gridPart ctx "row" ]
        [ Html.td [ Internal.cls [ "klar-table__state-cell" ], Attr.colspan ctx.colCount, gridPart ctx "gridcell" ]
            [ Html.div [ Internal.cls [ "klar-table__state" ] ] [ content ] ]
        ]


viewEmpty : Ctx row msg -> Html msg
viewEmpty ctx =
    let
        t =
            ctx.t

        filtered =
            isFiltered ctx
    in
    if ctx.data.total > 0 then
        EmptyState.view
            [ EmptyState.compact
            , EmptyState.icon Icon.fileText
            , EmptyState.title t.emptyPage
            , EmptyState.description t.emptyPageDescription
            , EmptyState.actions [ Button.view [ Button.onClick (ctx.toMsg FirstPageClicked) ] t.firstPage ]
            ]

    else if filtered then
        EmptyState.view
            [ EmptyState.compact
            , EmptyState.icon Icon.search
            , EmptyState.title t.noMatches
            , EmptyState.description t.noMatchesDescription
            , EmptyState.actions [ resetFiltersButton ctx [] t.clearSearchAndFilters AllCleared ]
            ]

    else
        EmptyState.view
            ([ EmptyState.compact
             , EmptyState.icon Icon.inbox
             , EmptyState.title t.noData
             , EmptyState.description t.noDataDescription
             ]
                ++ ctx.config.emptyState
            )


skeletonRows : Ctx row msg -> List ( String, Html msg )
skeletonRows ctx =
    let
        count =
            if ctx.config.paged then
                clamp 1 100 ctx.model.pageSize

            else
                8
    in
    List.range 0 (count - 1)
        |> List.map (\i -> ( "skeleton-" ++ String.fromInt i, skeletonRow ctx i ))


skeletonRow : Ctx row msg -> Int -> Html msg
skeletonRow ctx i =
    let
        widthFor j col =
            let
                spread =
                    modBy 41 ((i * 37 + j * 61 + 17) * 13)
            in
            if col.numeric then
                30 + modBy 25 spread

            else
                45 + spread
    in
    Html.tr [ Internal.cls [ "klar-table__row", "klar-table__row--skeleton" ], Attr.attribute "aria-hidden" "true" ]
        (List.concat
            [ systemCells ctx (\_ -> [])
            , List.indexedMap
                (\j col ->
                    Html.td [ Internal.cls (dataCellClasses ctx j col), pinStyle ctx j ]
                        [ if col.controls then
                            Html.text ""

                          else
                            Skeleton.line (widthFor j col)
                        ]
                )
                ctx.visible
            , if ctx.hasMenu then
                [ Html.td [ Internal.cls [ "klar-table__td", "klar-table__td--menu" ] ] [] ]

              else
                []
            ]
        )


viewRowAndDetail : Ctx row msg -> Int -> row -> List ( String, Html msg )
viewRowAndDetail ctx index row =
    let
        key =
            ctx.keyOf (ctx.data.offset + index) row

        expanded =
            ctx.hasExpand && Set.member key ctx.model.expanded

        rowHtml =
            viewRow ctx index row key expanded
    in
    case ( expanded, ctx.config.expandedRow ) of
        ( True, Just render ) ->
            [ ( "row-" ++ key, rowHtml )
            , ( "detail-" ++ key
              , Html.tr
                    [ Internal.cls [ "klar-table__detail-row" ]
                    , Attr.id (detailDomId ctx.model.id index)
                    , gridPart ctx "row"

                    -- in the tree grid the details are the child of their row
                    , Internal.attrIf (isTreegrid ctx) (Attr.attribute "aria-level" "2")
                    ]
                    [ Html.td
                        [ Internal.cls [ "klar-table__detail" ]
                        , gridPart ctx "gridcell"
                        , Attr.colspan ctx.colCount
                        , Internal.styleVars [ ( "--_indent", Internal.px (pinLeft ctx) ) ]
                        ]
                        [ Html.div [ Internal.cls [ "klar-table__detail-inner" ] ] [ render row ] ]
                    ]
              )
            ]

        _ ->
            [ ( "row-" ++ key, rowHtml ) ]


viewRow : Ctx row msg -> Int -> row -> String -> Bool -> Html msg
viewRow ctx index row key expanded =
    let
        config =
            ctx.config

        model =
            ctx.model

        t =
            ctx.t

        disabled =
            rowIsDisabled config row

        selected =
            ctx.hasSelect && isPicked model.selection key

        current =
            case config.currentRow of
                Just isCurrent ->
                    isCurrent row

                Nothing ->
                    False

        tone =
            config.rowTone |> Maybe.andThen (\toTone -> toTone row)

        domId =
            rowDomId model.id index

        name =
            ctx.labelOf row

        clickMsg =
            if disabled then
                Nothing

            else
                case config.onRowClick of
                    Just toMsg ->
                        Just (toMsg row)

                    Nothing ->
                        if ctx.hasExpand then
                            Just (ctx.toMsg (ExpandToggled key))

                        else
                            Nothing

        menuItems =
            case config.rowActions of
                Just toItems ->
                    toItems row

                Nothing ->
                    []

        menuId =
            model.id ++ "-menu-" ++ String.fromInt index

        -- where focus goes if the menu's own button is gone when it closes
        -- (the action removed the row)
        fallback =
            (menuId ++ "-trigger")
                :: (if ctx.interactiveRows then
                        [ domId ]

                    else
                        []
                   )
                ++ [ scrollDomId model.id ]

        -- One tab stop for the rows: the row that has (or last had) the focus
        -- keeps the tab stops of its own controls, the checkbox and the menu
        -- button. The other rows are reached with the arrow keys, instead of
        -- making a keyboard user tab through 25 or 50 checkboxes and menus.
        tabStop =
            if ctx.interactiveRows && index /= ctx.activeRow then
                Just -1

            else
                Nothing

        info =
            { index = index
            , key = key
            , domId = domId
            , disabled = disabled
            , selected = selected
            , expanded = expanded
            , click = clickMsg
            , menu =
                -- a disabled row has a menu button that cannot be used, and no
                -- key opens its menu either
                if disabled || List.isEmpty menuItems then
                    Nothing

                else
                    Just (ctx.toMsg (RowMenuOpened key menuId fallback))
            , menuTrigger = menuId ++ "-trigger"
            }

        pinClass =
            if ctx.pinnedFirst then
                "klar-table__cell--pinned"

            else
                ""

        selectCell =
            if ctx.hasSelect then
                [ Html.td
                    [ Internal.cls [ "klar-table__td", "klar-table__td--select", "klar-table__td--control", pinClass ]
                    , systemPinStyle ctx 0
                    , gridPart ctx "gridcell"
                    , if disabled then
                        Internal.noAttr

                      else
                        rangeClick ctx key selected
                    ]
                    [ Checkbox.view
                        (List.filterMap identity
                            [ Just (Checkbox.ariaLabel (t.selectRow name))
                            , Just (Checkbox.checked selected)
                            , Just (Checkbox.disabled disabled)
                            , if disabled then
                                Nothing

                              else
                                Just (Checkbox.onCheck (\value -> ctx.toMsg (RowSelected key value)))
                            , Maybe.map Checkbox.tabIndex tabStop
                            ]
                        )
                    ]
                ]

            else
                []

        expandCell =
            if ctx.hasExpand then
                [ Html.td
                    [ Internal.cls [ "klar-table__td", "klar-table__td--expand", "klar-table__td--control", pinClass ]
                    , gridPart ctx "gridcell"
                    , systemPinStyle ctx
                        (if ctx.hasSelect then
                            selectWidth

                         else
                            0
                        )
                    ]
                    [ Html.button
                        [ Internal.cls
                            [ "klar-table__expand"
                            , if expanded then
                                "klar-table__expand--open"

                              else
                                ""
                            ]
                        , Attr.type_ "button"
                        , Attr.tabindex -1
                        , Attr.disabled disabled

                        -- as on the row: a disabled row cannot open its details, so
                        -- its button does not say they are closed (only that they are open)
                        , Internal.attrIf (expanded || not disabled)
                            (Attr.attribute "aria-expanded"
                                (if expanded then
                                    "true"

                                 else
                                    "false"
                                )
                            )
                        , Internal.attrIf expanded (Attr.attribute "aria-controls" (detailDomId model.id index))
                        , Attr.attribute "aria-label"
                            (if expanded then
                                t.hideDetails name

                             else
                                t.showDetails name
                            )
                        , Attr.title
                            (if expanded then
                                t.hideDetails name

                             else
                                t.showDetails name
                            )
                        , Internal.attrIf (not disabled) (Events.onClick (ctx.toMsg (ExpandToggled key)))
                        ]
                        [ Icon.sized Icon.Small Icon.chevronRight ]
                    ]
                ]

            else
                []

        menuCell =
            case config.rowActions of
                Just _ ->
                    let
                        -- the menu of a disabled row stays closed, also when it
                        -- was open when the row became disabled
                        menuState =
                            case model.rowMenu of
                                Just ( openKey, state ) ->
                                    if openKey == key && not disabled then
                                        state

                                    else
                                        Menu.init menuId

                                Nothing ->
                                    Menu.init menuId

                        tabIndexAttrs =
                            case tabStop of
                                Just n ->
                                    [ Attr.tabindex n ]

                                Nothing ->
                                    []
                    in
                    [ Html.td [ Internal.cls [ "klar-table__td", "klar-table__td--menu", "klar-table__td--control" ], gridPart ctx "gridcell" ]
                        [ if List.isEmpty menuItems then
                            Html.text ""

                          else if disabled then
                            -- The trigger of a menu tells only when it is clicked whether it
                            -- is unavailable. A disabled row gets the same button without the
                            -- menu: disabled, it sends nothing and has nothing to open.
                            Html.div [ Internal.cls [ "klar-anchor", "klar-menu" ] ]
                                [ Button.iconOnly
                                    (Button.ghost
                                        :: Button.small
                                        :: Button.disabled True
                                        :: Button.id (Menu.triggerId menuState)
                                        :: Button.htmlAttrs (Attr.attribute "aria-haspopup" "menu" :: tabIndexAttrs)
                                        :: []
                                    )
                                    Icon.moreVertical
                                    (t.rowActions name)
                                ]

                          else
                            Menu.view (\menuMsg -> ctx.toMsg (RowMenu key menuId fallback menuMsg))
                                [ Menu.kebab (t.rowActions name)
                                , Menu.alignEnd
                                , Menu.trigger [ Button.small, Button.htmlAttrs tabIndexAttrs ]
                                , Menu.items menuItems
                                ]
                                menuState
                        ]
                    ]

                Nothing ->
                    []

        rowAttributes =
            List.concat
                [ [ Internal.cls
                        [ "klar-table__row"
                        , if ctx.config.zebra && modBy 2 index == 1 then
                            "klar-table__row--alt"

                          else
                            ""
                        , if selected then
                            "klar-table__row--selected"

                          else
                            ""
                        , if disabled then
                            "klar-table__row--disabled"

                          else
                            ""
                        , if isJust clickMsg then
                            "klar-table__row--clickable"

                          else
                            ""
                        , if expanded then
                            "klar-table__row--expanded"

                          else
                            ""
                        , if current then
                            "klar-table__row--current"

                          else
                            ""
                        , case tone of
                            Just value ->
                                "klar-table__row--tone klar-table__row--" ++ Internal.toneSuffix value

                            Nothing ->
                                ""
                        ]
                  , Attr.id domId
                  , Attr.attribute "aria-rowindex" (String.fromInt (ctx.data.offset + index + 2))
                  , Internal.attrIf ctx.hasSelect
                        (Attr.attribute "aria-selected"
                            (if selected then
                                "true"

                             else
                                "false"
                            )
                        )
                  , Internal.attrIf disabled (Attr.attribute "aria-disabled" "true")
                  , Internal.attrIf current (Attr.attribute "aria-current" "true")
                  , gridPart ctx "row"

                  -- a tree grid tells on the row whether its details are open; a
                  -- disabled row cannot open them, so it says nothing (unless they are open)
                  , Internal.attrIf (isTreegrid ctx) (Attr.attribute "aria-level" "1")
                  , Internal.attrIf (isTreegrid ctx && (expanded || not disabled))
                        (Attr.attribute "aria-expanded"
                            (if expanded then
                                "true"

                             else
                                "false"
                            )
                        )
                  ]
                , if ctx.interactiveRows then
                    [ Attr.tabindex
                        (if index == ctx.activeRow then
                            0

                         else
                            -1
                        )
                    , -- focusin, not focus: it also tells when a control in the row got the focus
                      Events.on "focusin" (Decode.succeed (ctx.toMsg (RowFocused index)))
                    , Events.preventDefaultOn "keydown" (rowKeys ctx info)
                    , Events.preventDefaultOn "contextmenu" (rowContextMenu info)
                    ]

                  else
                    []
                , case clickMsg of
                    Just msg ->
                        [ Events.on "click" (ignoreControls msg) ]

                    Nothing ->
                        []
                ]
    in
    Html.tr rowAttributes
        (List.concat
            [ selectCell
            , expandCell
            , List.indexedMap (viewCell ctx row) ctx.visible
            , menuCell
            ]
        )


viewCell : Ctx row msg -> row -> Int -> ColumnConfig row msg -> Html msg
viewCell ctx row index col =
    let
        value =
            col.value ctx.loc row

        blank =
            String.isEmpty (String.trim value)

        content =
            case col.cell of
                Just render ->
                    [ render ctx.loc row ]

                Nothing ->
                    if blank then
                        [ Html.span [ Internal.cls [ "klar-table__empty" ] ] [ Html.text "–" ] ]

                    else if col.searchable && not (String.isEmpty ctx.model.search) then
                        Search.highlight ctx.model.search value

                    else
                        [ Html.text value ]
    in
    Html.td
        [ Internal.cls (dataCellClasses ctx index col)
        , pinStyle ctx index
        , gridPart ctx
            (if index == 0 then
                "rowheader"

             else
                "gridcell"
            )
        , Internal.attrIf (col.tooltip && not blank && not (isJust col.cell)) (Attr.title value)
        ]
        [ Html.div [ Internal.cls [ "klar-table__cell" ] ] content ]


{-| Shift+click on the checkbox of a row (or its cell): the rows from the anchor
to this one take the state this one is about to get. The checkbox itself sends the
same state for its own row right after.
-}
rangeClick : Ctx row msg -> String -> Bool -> Html.Attribute msg
rangeClick ctx key selected =
    if ctx.model.anchor == Nothing || ctx.model.anchor == Just key then
        Internal.noAttr

    else
        Events.on "click"
            (Decode.field "shiftKey" Decode.bool
                |> Decode.andThen
                    (\shift ->
                        if shift then
                            case rangeMsg ctx key (not selected) of
                                Just msg ->
                                    Decode.succeed msg

                                Nothing ->
                                    Decode.fail "the anchor is not among these rows"

                        else
                            Decode.fail "not a range"
                    )
            )


viewFoot : Ctx row msg -> Html msg
viewFoot ctx =
    if ctx.data.status /= Ready || not (List.any hasFooter ctx.visible) || ctx.data.total == 0 then
        Html.text ""

    else
        let
            matched =
                ctx.data.matchingRows
        in
        Html.tfoot [ Internal.cls [ "klar-table__foot" ] ]
            [ Html.tr [ gridPart ctx "row" ]
                (List.concat
                    [ systemCells ctx (\_ -> [])
                    , List.indexedMap
                        (\index col ->
                            Html.td [ Internal.cls (dataCellClasses ctx index col), pinStyle ctx index, gridPart ctx "gridcell" ]
                                [ Html.div [ Internal.cls [ "klar-table__cell" ] ] (footerContent ctx matched index col) ]
                        )
                        ctx.visible
                    , if ctx.hasMenu then
                        [ Html.td [ Internal.cls [ "klar-table__td", "klar-table__td--menu" ], gridPart ctx "gridcell" ] [] ]

                      else
                        []
                    ]
                )
            ]


footerContent : Ctx row msg -> (() -> List row) -> Int -> ColumnConfig row msg -> List (Html msg)
footerContent ctx matched index col =
    let
        t =
            ctx.t

        numbers () =
            case col.number of
                Just toNumber ->
                    List.filterMap toNumber (matched ())

                Nothing ->
                    []

        -- the sum and the count, kept by prepared rows while no row is left out
        totals () =
            case ctx.data.totals col.id of
                Just kept ->
                    kept

                Nothing ->
                    let
                        values =
                            numbers ()
                    in
                    { sum = List.sum values, count = List.length values }

        aggregate name value =
            [ Html.span [ Internal.cls [ "klar-table__aggregate-label" ] ] [ Html.text name ]
            , Html.span [ Internal.cls [ "klar-table__aggregate" ] ] [ Html.text value ]
            ]

        -- a money column: exact totals, one for each currency (kept by prepared
        -- rows while no row is left out, so that a scroll adds up nothing again)
        moneyAggregate name toValue toMoney =
            case
                ctx.data.moneyTotals col.id
                    |> Maybe.withDefault (moneyTotals toMoney (matched ()))
            of
                [] ->
                    aggregate name "–"

                groups ->
                    aggregate name
                        (groups
                            |> List.map (\group -> Maybe.withDefault "–" (Maybe.map (Money.toString ctx.loc) (Maybe.andThen (toValue group.count) group.total)))
                            |> String.join " · "
                        )
    in
    case ( col.footer, col.money ) of
        ( Just FooterSum, Just toMoney ) ->
            moneyAggregate t.sum (\_ total -> Just total) toMoney

        ( Just FooterAverage, Just toMoney ) ->
            moneyAggregate t.average (\count total -> Result.toMaybe (Money.fraction 1 count total)) toMoney

        ( Just FooterSum, Nothing ) ->
            aggregate t.sum (formatNumber ctx.loc col.decimals (totals ()).sum)

        ( Just FooterAverage, Nothing ) ->
            let
                kept =
                    totals ()
            in
            if kept.count == 0 then
                aggregate t.average "–"

            else
                aggregate t.average (Format.decimal ctx.loc (max 1 col.decimals) (kept.sum / toFloat kept.count))

        ( Just (FooterCustom summarize), _ ) ->
            [ Html.text (summarize (matched ())) ]

        ( Nothing, _ ) ->
            if index == 0 then
                [ Html.span [ Internal.cls [ "klar-table__aggregate-label" ] ] [ Html.text t.total ] ]

            else
                []



-- FOOTER


{-| The pagination, in every state of a server-mode table once a total is known.
A page that is loading or failed must not take the pagination away: the user
is often on one of its controls (the page they just asked for, the page size),
and a control that disappears drops keyboard focus to the page. The range
("1–25 of 3,000") is not shown then, because it describes rows that are not
on screen; the other pages can still be tried.
-}
viewFooter : Ctx row msg -> Html msg
viewFooter ctx =
    if not ctx.config.paged then
        if ctx.config.virtual then
            viewRange ctx

        else
            Html.text ""

    else
        let
            totalKnown =
                ctx.config.server /= Nothing && ctx.data.total > 0
        in
        case ctx.data.status of
            Failed _ ->
                if totalKnown then
                    viewPagination ctx (Just [])

                else
                    Html.text ""

            Waiting ->
                let
                    loading =
                        -- announced by the table's own live region, so hidden here
                        Html.span [ Internal.cls [ "klar-table__footer-loading" ], Attr.attribute "aria-hidden" "true" ]
                            [ Spinner.view [ Spinner.size Theme.Small ]
                            , Html.text ctx.t.loading
                            ]
                in
                if totalKnown then
                    viewPagination ctx (Just [ loading ])

                else
                    Html.div [ Internal.cls [ "klar-table__footer" ] ] [ loading ]

            Ready ->
                if ctx.data.total == 0 && not (isFiltered ctx) then
                    -- nothing at all: no pagination to show
                    Html.text ""

                else
                    viewPagination ctx Nothing


{-| The rows in view of a long table, "Showing 1-24 of 50,000 rows". It is
for the eye only: the live region of the table does not repeat it while the
user scrolls, and every row says its place (`aria-rowindex`).
-}
viewRange : Ctx row msg -> Html msg
viewRange ctx =
    if ctx.data.status /= Ready || ctx.data.total == 0 then
        Html.text ""

    else
        let
            top =
                Window.clampScroll ctx.geometry ctx.model.scroll

            -- the rows that are in view in full
            first =
                clamp 1 ctx.data.total (ceiling (top / toFloat ctx.geometry.rowHeight) + 1)

            last =
                clamp first ctx.data.total (floor ((top + toFloat ctx.geometry.viewport) / toFloat ctx.geometry.rowHeight))
        in
        Html.div [ Internal.cls [ "klar-table__footer" ], Attr.attribute "aria-hidden" "true" ]
            [ Html.span [ Internal.cls [ "klar-table__footer-range", "klar-tabular" ] ]
                [ Html.text (Maybe.withDefault ctx.t.summary ctx.config.rangeText first last ctx.data.total) ]
            ]


{-| `summary` replaces the range text (a loading message, or nothing).
-}
viewPagination : Ctx row msg -> Maybe (List (Html msg)) -> Html msg
viewPagination ctx summary =
    Html.div [ Internal.cls [ "klar-table__footer" ] ]
        [ Pagination.view
            (List.filterMap identity
                [ Just (Pagination.id (ctx.model.id ++ "-pagination"))
                , Just (Pagination.onPage (\n -> ctx.toMsg (PageChanged n)))
                , Just (Pagination.onPageSize (\n -> ctx.toMsg (PageSizeChanged n)))
                , Just (Pagination.pageSizes ctx.config.pageSizes)
                , Just Pagination.jumpToPage
                , Just (Pagination.locale ctx.loc)
                , Maybe.map Pagination.rangeText ctx.config.rangeText
                , -- the landmark is named after the table, so that two tables on a page are told apart
                  Maybe.map (\name -> Pagination.ariaLabel (ctx.t.pagination name)) (Internal.nonEmpty (Maybe.withDefault "" ctx.config.label))
                , Maybe.map Pagination.summary summary
                ]
            )
            { page = ctx.data.page, pageSize = ctx.model.pageSize, total = ctx.data.total }
        ]
