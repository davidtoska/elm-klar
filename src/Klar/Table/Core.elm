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
import Klar.Table.Body exposing (rangeClick, retryClicked, skeletonRow, skeletonRows, spacerBody, stateRow, viewBodies, viewBody, viewCell, viewEmpty, viewRow, viewRowAndDetail)
import Klar.Table.Bulk exposing (viewBulkBar)
import Klar.Table.ColumnLogic exposing (exportValue, findColumn, hasFooter, isShown, isSortable, sortKeyOf, sortLevel, visibleColumns)
import Klar.Table.Columns exposing (actions, alignCenter, alignRight, alwaysVisible, badge, baseColumn, bool, build, cell, custom, date, exportAs, filterOptions, filterRange, filterSelect, filterText, filterValue, float, footer, footerAverage, footerSum, hiddenByDefault, hint, includeInSearch, int, maybeDate, minWidth, money, noTooltip, notExported, notSearchable, pinned, sortDate, sortMaybeNumber, sortNumber, sortText, sortWith, status, text, unsortable, width, wrap)
import Klar.Table.Config exposing (activeExternalFilters, ariaLabel, bulkActions, columnChooser, columns, configure, csvSeparator, currentRow, densityToggle, emptyState, expandedRow, exportCsv, fillHeight, finish, locale, maxHeight, multiSort, onRefresh, onResetFilters, onRetry, onRowClick, pageSizes, rangeText, remote, remotePrepared, rowActions, rowDisabled, rowFilter, rowId, rowLabel, rowTone, searchDebounce, searchPlaceholder, searchable, selectable, server, settings, toolbarActions, unpaged, virtual, zebra)
import Klar.Table.Csv as Csv
import Klar.Table.CsvRows exposing (csvText, withSuffix)
import Klar.Table.DomIds exposing (bulkDomId, detailDomId, filterInputId, popupDomId, popupSuffix, rowDomId, scrollDomId, triggerDomId)
import Klar.Table.Export exposing (csvSeparatorOf, exportOptions, viewExportMenu)
import Klar.Table.Filter exposing (activeDrafts, canonicalChoice, choiceLabels, choiceOf, choicesOf, filterTest, fold, localChoice, parseNumber, searchTest, searchText, searchWords, toDraft, toFilter, withinRange)
import Klar.Table.Header exposing (viewHead, viewHeaderCell)
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
import Klar.Table.Toolbar exposing (activeFilterCount, densityComfortable, densityCompact, densityNormal, describeDraft, hasToolbar, hasTools, resetFiltersButton, viewColumnsMenu, viewDensity, viewFilterSummary, viewSearch, viewToolbar, withAppReset)
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
