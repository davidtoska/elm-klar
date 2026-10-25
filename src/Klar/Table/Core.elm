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
import Klar.Table.ColumnLogic exposing (exportValue, findColumn, hasFooter, isShown, isSortable, sortKeyOf, sortLevel, visibleColumns)
import Klar.Table.Columns exposing (actions, alignCenter, alignRight, alwaysVisible, badge, baseColumn, bool, build, cell, custom, date, exportAs, filterOptions, filterRange, filterSelect, filterText, filterValue, float, footer, footerAverage, footerSum, hiddenByDefault, hint, includeInSearch, int, maybeDate, minWidth, money, noTooltip, notExported, notSearchable, pinned, sortDate, sortMaybeNumber, sortNumber, sortText, sortWith, status, text, unsortable, width, wrap)
import Klar.Table.Config exposing (activeExternalFilters, ariaLabel, bulkActions, columnChooser, columns, configure, csvSeparator, currentRow, densityToggle, emptyState, expandedRow, exportCsv, fillHeight, finish, locale, maxHeight, multiSort, onRefresh, onResetFilters, onRetry, onRowClick, pageSizes, rangeText, remote, remotePrepared, rowActions, rowDisabled, rowFilter, rowId, rowLabel, rowTone, searchDebounce, searchPlaceholder, searchable, selectable, server, settings, toolbarActions, unpaged, virtual, zebra)
import Klar.Table.Csv as Csv
import Klar.Table.DomIds exposing (bulkDomId, detailDomId, filterInputId, popupDomId, popupSuffix, rowDomId, scrollDomId, triggerDomId)
import Klar.Table.Filter exposing (activeDrafts, canonicalChoice, choiceLabels, choiceOf, choicesOf, filterTest, fold, localChoice, parseNumber, searchTest, searchText, searchWords, toDraft, toFilter, withinRange)
import Klar.Table.Identity exposing (idsOf, isJust, keysBetween, keysOf, lookup, toggled)
import Klar.Table.Index as Index exposing (Index)
import Klar.Table.Numeric exposing (formatNumber, majorAmount, moneyTotals, plainDecimal)
import Klar.Table.Query exposing (encodeQuery, filterDecoder, optionalField, queryDecoder, sortDecoder)
import Klar.Table.Rows exposing (prepareRows, rowsArray, sourceArray, sourceList, usablePrepared)
import Klar.Table.Selection exposing (clearSelection, deselect, dropAllMatching, dropAllMatchingOf, everyRowCanBeSelected, isLongClientTable, isPicked, isSelected, matchingSelectionState, pick, rowIsDisabled, select, selectableCount, selectableKeys, selectedCount, selectedIds, selection, selectionTotal, setSelectedIds)
import Klar.Table.Sort as Sorting
import Klar.Table.State exposing (clearFilters, collapse, collapseAll, columnId, columnName, density, expand, expandedIds, filters, init, isColumnVisible, isExpanded, page, pageSize, query, search, setColumnVisible, setDensity, setExpandedIds, setFilter, setPage, setPageSize, setQuery, setSearch, setSort, settled, sort, toggle)
import Klar.Table.Texts as Texts exposing (Texts)
import Klar.Table.Types exposing (Align(..), Attribute(..), Column(..), ColumnAttribute(..), ColumnConfig, ColumnId(..), Config, Ctx, Data, DataStatus(..), Direction(..), Draft(..), Filter(..), FilterKind(..), Footer(..), Model, MoneyTotal, Msg(..), Picked(..), Popup(..), Query, RowInfo, Rows(..), Selection(..), SortBy(..), Source(..), State(..))
import Klar.Tag as Tag
import Klar.TextInput as TextInput
import Klar.Theme as Theme exposing (Density(..), Tone)
import Process
import Set exposing (Set)
import Task


{-| Moves keyboard focus to the table (its scroll area; Tab goes on to the
header from there). Use it when whatever had focus is gone: a bulk action that
removed the selected rows takes the bulk bar and its buttons with it, and focus
would fall back to the page.

    DeleteSelected ->
        ( { model
            | orders = withoutOrders (Table.selectedIds orderIds model.table) model.orders
            , table = Table.clearSelection model.table
          }
        , Cmd.map TableMsg (Table.focus model.table)
        )

-}
focus : State id -> Cmd Msg
focus (State model) =
    Internal.focus (scrollDomId model.id) NoOp


{-| Applies a message from the table to its state. The `Cmd` moves keyboard
focus (into a popup, back to its button), runs the timer behind the search
debounce and saves the file of the CSV export, so map it back with your own
constructor: `Cmd.map TableMsg cmd`.
-}
update : Msg -> State id -> ( State id, Cmd Msg )
update msg (State model) =
    let
        ( next, cmd ) =
            step msg model
    in
    -- sorting and searching start at the top of a table that scrolls
    if model.scroll > 0 && next.scroll == 0 then
        ( State next, Cmd.batch [ cmd, scrollTo model.id 0 ] )

    else
        ( State next, cmd )


{-| Scrolls the scroll area to this offset, and then focuses the row. In that order:
focus in a row that is out of view makes the browser scroll, and the window of
drawn rows then moves a second time while the row has the focus. The row is drawn
already (the offset is in the model), and when it gets the focus it is in view.
-}
scrollThenFocus : String -> Float -> String -> Cmd Msg
scrollThenFocus tableId top rowDomIdValue =
    Dom.getViewportOf (scrollDomId tableId)
        |> Task.andThen (\viewport -> Dom.setViewportOf (scrollDomId tableId) viewport.viewport.x top)
        |> Task.andThen (\_ -> Dom.focus rowDomIdValue |> Task.onError (\_ -> Dom.focus (scrollDomId tableId)))
        |> Task.attempt (\_ -> NoOp)


{-| Scrolls the table's scroll area to this offset from the top, keeping its
horizontal position.
-}
scrollTo : String -> Float -> Cmd Msg
scrollTo tableId top =
    Dom.getViewportOf (scrollDomId tableId)
        |> Task.andThen (\viewport -> Dom.setViewportOf (scrollDomId tableId) viewport.viewport.x top)
        |> Task.attempt (\_ -> NoOp)


step : Msg -> Model -> ( Model, Cmd Msg )
step msg model =
    case msg of
        NoOp ->
            ( model, Cmd.none )

        SortClicked colId multi ->
            ( { model | sort = nextSort multi colId model.sort, page = 1, activeRow = 0, scroll = 0 }, Cmd.none )

        PageChanged n ->
            ( { model | page = max 1 n, activeRow = 0, scroll = 0, rowMenu = Nothing }, Cmd.none )

        PageSizeChanged size ->
            let
                newSize =
                    max 1 size

                firstIndex =
                    (max 1 model.page - 1) * model.pageSize
            in
            ( { model | pageSize = newSize, page = firstIndex // newSize + 1, activeRow = 0, scroll = 0 }, Cmd.none )

        SearchChanged value delay ->
            schedule delay { model | searchInput = value }

        FilterTextChanged colId value delay ->
            schedule delay { model | inputs = Dict.insert colId (TextDraft value) model.inputs }

        FilterRangeChanged colId isFrom value delay ->
            let
                ( from, to ) =
                    case Dict.get colId model.inputs of
                        Just (RangeDraft a b) ->
                            ( a, b )

                        _ ->
                            ( "", "" )

                next =
                    if isFrom then
                        RangeDraft value to

                    else
                        RangeDraft from value
            in
            schedule delay { model | inputs = Dict.insert colId next model.inputs }

        FilterChoiceToggled colId value checked ->
            let
                current =
                    choicesOf colId model.inputs

                next =
                    if checked then
                        Set.insert value current

                    else
                        Set.remove value current
            in
            ( commit { model | inputs = Dict.insert colId (ChoiceDraft next) model.inputs }, Cmd.none )

        FilterChoicesSet colId values ->
            -- "Select all" and "Clear" disable themselves: focus moves into the list
            ( commit { model | inputs = Dict.insert colId (ChoiceDraft (Set.fromList values)) model.inputs }
            , focusFirst [ filterInputId model.id colId "search", filterInputId model.id colId "option-0" ]
            )

        OptionQueryChanged value ->
            ( { model | optionQuery = value }, Cmd.none )

        FilterCleared colId ->
            afterClear (Just colId) model (commit { model | inputs = Dict.remove colId model.inputs })

        FiltersCleared ->
            afterClear Nothing model (commit { model | inputs = Dict.empty })

        AllCleared ->
            afterClear Nothing model (commit { model | inputs = Dict.empty, searchInput = "" })

        Debounced n ->
            if n == model.debounce then
                ( commit model, Cmd.none )

            else
                ( model, Cmd.none )

        PopupOpened popup focusIds ->
            ( { model | popup = popup, optionQuery = "" }
            , focusFirst (focusIds ++ [ popupDomId model.id popup ])
            )

        PopupClosed ->
            ( { model | popup = NoPopup }
            , if model.popup == NoPopup then
                Cmd.none

              else
                Internal.focus (triggerDomId model.id model.popup) NoOp
            )

        PopupLeft ->
            ( { model | popup = NoPopup }, Cmd.none )

        RowMenu key menuId fallback menuMsg ->
            let
                current =
                    case model.rowMenu of
                        Just ( openKey, menu ) ->
                            if openKey == key then
                                menu

                            else
                                Menu.init menuId

                        Nothing ->
                            Menu.init menuId

                ( next, cmd ) =
                    Menu.update menuMsg current

                closed =
                    Menu.isOpen current && not (Menu.isOpen next)
            in
            ( { model
                | rowMenu =
                    if Menu.isOpen next then
                        Just ( key, next )

                    else
                        Nothing
              }
            , Cmd.batch
                [ Cmd.map (RowMenu key menuId fallback) cmd

                -- The menu gives focus back to its button. When the action
                -- removed the row (a delete, a status that no longer matches
                -- the filter) the button is gone: the row that took its place,
                -- or the table, gets focus instead of the page.
                , if closed then
                    focusFirst fallback

                  else
                    Cmd.none
                ]
            )

        RowMenuOpened key menuId fallback ->
            -- Shift+F10 or the menu key on a row: the same as its "more" button
            let
                ( opened, cmd ) =
                    Menu.open (Menu.init menuId)
            in
            ( { model | rowMenu = Just ( key, opened ) }
            , Cmd.map (RowMenu key menuId fallback) cmd
            )

        RowSelected key checked ->
            ( { model | selection = pick [ key ] checked model.selection, anchor = Just key }, Cmd.none )

        RangeSelected keys checked target ->
            -- Shift: the rows from the anchor to this one get the state of this one
            ( { model | selection = pick keys checked model.selection, anchor = Just target }, Cmd.none )

        RowsSelected keys checked ->
            ( { model | selection = pick keys checked model.selection }, Cmd.none )

        MatchingSelected keys ->
            -- "Select all N matching" is replaced by a note: focus goes to the bar
            ( { model | selection = pick keys True model.selection }, Internal.focus (bulkDomId model.id) NoOp )

        AllMatchingPicked ->
            ( { model | selection = AllPicked Set.empty }, Internal.focus (bulkDomId model.id) NoOp )

        SelectionCleared focusId ->
            ( { model | selection = Picked Set.empty }, Internal.focus focusId NoOp )

        ExpandToggled key ->
            ( { model | expanded = toggled key model.expanded }, Cmd.none )

        DensityChanged value ->
            ( { model | density = value }, Cmd.none )

        ColumnToggled colId visible ->
            ( { model | visibility = Dict.insert colId visible model.visibility }, Cmd.none )

        ColumnsReset ->
            ( { model | visibility = Dict.empty }, Cmd.none )

        RowFocused index ->
            if index == model.activeRow then
                ( model, Cmd.none )

            else
                ( { model | activeRow = index }, Cmd.none )

        FocusRow index domId ->
            ( { model | activeRow = index }, Internal.focus domId NoOp )

        FocusVirtualRow index domId geometry ->
            -- the row may not be drawn yet: scroll first, so that it is when focus arrives
            let
                top =
                    Window.scrollToRow geometry model.scroll index
            in
            ( { model | activeRow = index, scroll = top }
            , scrollThenFocus model.id top domId
            )

        Scrolled top ->
            ( { model | scroll = max 0 top }, Cmd.none )

        RetryClicked ->
            -- "Try again" is replaced by skeleton rows while the answer is on
            -- its way: focus waits on the table instead of falling to the page
            ( model, Internal.focus (scrollDomId model.id) NoOp )

        FirstPageClicked ->
            -- the same for "Go to the first page" in the empty page: rows replace it
            ( { model | page = 1, activeRow = 0, scroll = 0, rowMenu = Nothing }, Internal.focus (scrollDomId model.id) NoOp )

        ExportClicked filename csv ->
            -- a byte order mark first, so that Excel reads æ, ø and å as UTF-8
            ( { model | popup = NoPopup }
            , Cmd.batch
                [ Download.string filename "text/csv;charset=utf-8" ("\u{FEFF}" ++ csv)
                , if model.popup == NoPopup then
                    Cmd.none

                  else
                    Internal.focus (triggerDomId model.id model.popup) NoOp
                ]
            )


{-| Where focus goes after a filter was removed. The control that removed it
is often gone or disabled now (a chip, "Reset", the reset button next to
"N filters active", the empty state), and without a new target focus would
fall back to the page, where Escape no longer closes anything. A summary
popover with no filters left is closed, so it does not open by itself with
the next filter.
-}
afterClear : Maybe String -> Model -> Model -> ( Model, Cmd Msg )
afterClear removed before after =
    let
        -- Every target takes focus when it is there: the search box, "N filters
        -- active", the filter button in the header of a column whose filter was
        -- removed, and last the scroll area, which can take focus whenever the
        -- table has a filter button. A row is not on the list: it cannot take
        -- focus unless the rows are interactive, and focus would fall to the page.
        clearedColumns =
            Maybe.withDefault [] (Maybe.map List.singleton removed)
                ++ List.map Tuple.first (activeDrafts before)

        outside =
            [ after.id ++ "-search", triggerDomId after.id FiltersPopup ]
                ++ List.map (\colId -> triggerDomId after.id (FilterPopup colId)) clearedColumns
                ++ [ scrollDomId after.id ]

        lastChip =
            activeDrafts before |> List.reverse |> List.head |> Maybe.map Tuple.first
    in
    case after.popup of
        FilterPopup colId ->
            ( after
            , focusFirst
                ([ "text", "from", "search", "option-0" ]
                    |> List.map (filterInputId after.id colId)
                    |> (\inputs -> inputs ++ [ popupDomId after.id after.popup ])
                )
            )

        FiltersPopup ->
            if List.isEmpty (activeDrafts after) then
                ( { after | popup = NoPopup }, focusFirst (triggerDomId after.id FiltersPopup :: outside) )

            else if removed == Nothing || removed == lastChip then
                -- the chips after a removed one move up and keep the focus; the last has nothing after it
                ( after, focusFirst [ popupDomId after.id FiltersPopup ] )

            else
                ( after, Cmd.none )

        _ ->
            ( after, focusFirst outside )


{-| Focus the first of these elements that exists.
-}
focusFirst : List String -> Cmd Msg
focusFirst ids =
    ids
        |> List.foldr (\domId fallback -> Dom.focus domId |> Task.onError (\_ -> fallback)) (Task.succeed ())
        |> Task.attempt (\_ -> NoOp)


{-| Plain click: sort by this column only, cycling ascending, descending,
unsorted. Shift-click (multi-sort): add the column, or cycle it in place.
-}
nextSort : Bool -> String -> List ( String, Direction ) -> List ( String, Direction )
nextSort multi colId current =
    let
        existing =
            lookup colId current

        cycled =
            case existing of
                Nothing ->
                    Just Ascending

                Just Ascending ->
                    Just Descending

                Just Descending ->
                    Nothing
    in
    if multi then
        case ( existing, cycled ) of
            ( Nothing, Just direction ) ->
                current ++ [ ( colId, direction ) ]

            ( Just _, Just direction ) ->
                List.map
                    (\( other, d ) ->
                        if other == colId then
                            ( other, direction )

                        else
                            ( other, d )
                    )
                    current

            ( _, Nothing ) ->
                List.filter (\( other, _ ) -> other /= colId) current

    else if List.length current == 1 && existing /= Nothing then
        case cycled of
            Just direction ->
                [ ( colId, direction ) ]

            Nothing ->
                []

    else
        [ ( colId, Ascending ) ]


{-| Typing is committed at once (`delay` 0) or after a pause; a newer key
press makes older timers stale.
-}
schedule : Int -> Model -> ( Model, Cmd Msg )
schedule delay model =
    if delay <= 0 then
        ( commit model, Cmd.none )

    else
        let
            n =
                model.debounce + 1
        in
        ( { model | debounce = n }
        , Process.sleep (toFloat delay) |> Task.perform (\_ -> Debounced n)
        )


{-| Turns the inputs into the search and filters in effect. A changed search
or filter goes back to page 1, and "all matching" no longer means the same
rows, so that selection is dropped.
-}
commit : Model -> Model
commit model =
    let
        newFilters =
            model.inputs
                |> Dict.toList
                |> List.filterMap (\( colId, draft ) -> Maybe.map (Tuple.pair colId) (toFilter draft))
                |> Dict.fromList

        newSearch =
            String.trim model.searchInput

        changed =
            Dict.toList newFilters /= Dict.toList model.filters || newSearch /= model.search
    in
    if changed then
        { model
            | filters = newFilters
            , search = newSearch
            , page = 1
            , activeRow = 0
            , scroll = 0
            , selection = dropAllMatchingOf model.selection
        }

    else
        model


{-| The decimals the numbers of the range filter of this column are shown with:
those of the currency of a money column (none for yen, three for dinars), read
from its first row, else the column's own.
-}
rangeDecimals : Ctx row msg -> ColumnConfig row msg -> Int
rangeDecimals ctx col =
    let
        firstRow =
            case ctx.config.rows of
                Remote.Loaded (FromList list) ->
                    List.head list

                Remote.Loaded (FromRows (Rows prep)) ->
                    Array.get 0 prep.array

                _ ->
                    Nothing
    in
    case ( col.money, firstRow ) of
        ( Just toMoney, Just row ) ->
            Money.decimals (Money.currencyOf (toMoney row))

        _ ->
            col.decimals


{-| What to show: in client mode the rows after outside filter, column
filters, search and sort, and the slice for the current page.
-}
process : Config row msg -> Model -> List (ColumnConfig row msg) -> List (ColumnConfig row msg) -> Data row
process config model allColumns visible =
    let
        nothing =
            { status = Waiting
            , pageRows = []
            , pageAll = []
            , first = 0
            , rowCount = 0
            , matchingRows = \_ -> []
            , countMatching = \_ -> 0
            , totals = \_ -> Nothing
            , moneyTotals = \_ -> Nothing
            , total = Maybe.withDefault 0 config.server
            , available = Maybe.withDefault 0 config.server
            , page = max 1 model.page
            , pageCount = 1
            , offset = 0
            }
    in
    case config.rows of
        Remote.Loaded source ->
            case config.server of
                Just total ->
                    let
                        ( current, count, offset ) =
                            pageWindow config model total

                        allRows =
                            sourceList source

                        rowTotal =
                            List.length allRows

                        shown =
                            if config.virtual then
                                Window.window virtualWindow (virtualGeometry config model rowTotal) model.scroll

                            else
                                { first = 0, end = rowTotal, before = 0, after = 0 }
                    in
                    { status = Ready
                    , pageRows =
                        if config.virtual then
                            allRows |> List.drop shown.first |> List.take (shown.end - shown.first)

                        else
                            allRows
                    , pageAll = allRows
                    , first = shown.first
                    , rowCount = rowTotal
                    , matchingRows = \_ -> allRows
                    , countMatching = \test -> List.length (List.filter (\( index, row ) -> test index row) (List.indexedMap Tuple.pair allRows))
                    , totals = \_ -> Nothing
                    , moneyTotals = \_ -> Nothing
                    , total = total
                    , available = total
                    , page = current
                    , pageCount = count
                    , offset = offset
                    }

                Nothing ->
                    processClient config model allColumns visible source

        Remote.Failed problem ->
            { nothing | status = Failed problem }

        _ ->
            nothing


{-| Client mode: finds the matching rows as positions in the array of rows (see
`Klar.Table.Index`), and takes the rows of the current page from them. With
prepared rows the search texts and the sorted orders are there already.
-}
processClient : Config row msg -> Model -> List (ColumnConfig row msg) -> List (ColumnConfig row msg) -> Source row -> Data row
processClient config model allColumns visible source =
    let
        loc =
            config.locale

        array =
            sourceArray source

        rowAt position =
            Array.get position array

        onPosition test position =
            case rowAt position of
                Just row ->
                    test row

                Nothing ->
                    False

        prepared =
            usablePrepared loc allColumns source

        searched =
            List.filter .searchable visible

        words =
            searchWords model.search

        indexedSearch =
            case prepared of
                Just (Rows prep) ->
                    prep.searchIds == List.map .id searched

                Nothing ->
                    False

        searchFallback =
            if indexedSearch then
                []

            else
                searchTest loc searched model.search |> Maybe.map (onPosition >> List.singleton) |> Maybe.withDefault []

        columnTests =
            model.filters
                |> Dict.toList
                |> List.filterMap (\( colId, f ) -> findColumn colId allColumns |> Maybe.map (\col -> onPosition (filterTest loc col f)))

        tests =
            List.concat
                [ searchFallback
                , config.rowFilter |> Maybe.map (onPosition >> List.singleton) |> Maybe.withDefault []
                , columnTests
                ]

        matches =
            Index.matching
                (Maybe.map (\(Rows prep) -> prep.index) prepared)
                { count = Array.length array
                , words =
                    if indexedSearch then
                        words

                    else
                        []
                , tests = tests
                , levels = sortLevels loc prepared rowAt model.sort allColumns
                }

        total =
            Index.matchCount matches

        ( current, count, offset ) =
            pageWindow config model total

        rowsOf positions =
            List.filterMap rowAt positions

        shown =
            Window.window virtualWindow (virtualGeometry config model total) model.scroll

        pageRows =
            if config.virtual then
                rowsOf (Index.pageIndices shown.first (shown.end - shown.first) matches)

            else if config.paged then
                rowsOf (Index.pageIndices offset (max 1 model.pageSize) matches)

            else
                rowsOf (Index.allIndices matches)
    in
    { status = Ready
    , pageRows = pageRows
    , pageAll =
        if config.virtual then
            []

        else
            pageRows
    , first =
        if config.virtual then
            shown.first

        else
            0
    , rowCount =
        if config.virtual then
            total

        else
            List.length pageRows
    , matchingRows = \_ -> rowsOf (Index.allIndices matches)
    , countMatching =
        \test ->
            Index.countMatching
                (\place position ->
                    case rowAt position of
                        Just row ->
                            test place row

                        Nothing ->
                            False
                )
                matches
    , totals =
        case prepared of
            Just (Rows prep) ->
                -- read from the numbers kept per position: no row is turned into a number again
                \id -> Index.totalsOver id matches prep.index

            Nothing ->
                \_ -> Nothing
    , moneyTotals =
        case prepared of
            Just (Rows prep) ->
                if total == Array.length array then
                    -- every row matched: the totals worked out once by prepareRows
                    \id -> Dict.get id prep.moneyTotals

                else
                    \_ -> Nothing

            Nothing ->
                \_ -> Nothing
    , total = total
    , available = Array.length array
    , page = current
    , pageCount = count
    , offset = offset
    }


{-| The levels of the sort, for `Index.matching`. A single level on a column that
the prepared rows have the order of is read from the index; the others are
worked out from the rows.
-}
sortLevels :
    Locale
    -> Maybe (Rows row)
    -> (Int -> Maybe row)
    -> List ( String, Direction )
    -> List (ColumnConfig row msg)
    -> List Index.Level
sortLevels loc prepared rowAt levels allColumns =
    let
        chosen =
            levels
                |> List.filterMap
                    (\( colId, direction ) ->
                        findColumn colId allColumns
                            |> Maybe.andThen
                                (\col ->
                                    if isSortable col then
                                        Just ( col, direction == Descending )

                                    else
                                        Nothing
                                )
                    )

        computed ( col, descending ) =
            case col.sortBy of
                SortByComparator comparator ->
                    Index.Compared descending
                        (\a b ->
                            case ( rowAt a, rowAt b ) of
                                ( Just rowA, Just rowB ) ->
                                    comparator rowA rowB

                                _ ->
                                    EQ
                        )

                _ ->
                    Index.Keyed descending
                        (\position ->
                            case ( rowAt position, sortKeyOf loc col ) of
                                ( Just row, Just toKey ) ->
                                    toKey row

                                _ ->
                                    Sorting.Missing
                        )
    in
    case ( chosen, prepared ) of
        ( [ ( col, descending ) ], Just (Rows prep) ) ->
            if Index.hasRanks col.id prep.index then
                [ Index.Ranked col.id descending ]

            else
                [ computed ( col, descending ) ]

        _ ->
            List.map computed chosen


{-| The rows of a table that scrolls are one height, the one of its density
(`--klar-row-compact`, `--klar-row` and `--klar-row-comfortable`).
-}
rowPx : Density -> Int
rowPx spacing =
    case spacing of
        Compact ->
            28

        Normal ->
            36

        Comfortable ->
            46


{-| The sticky header (`--_head-h`).
-}
headPx : Density -> Int
headPx spacing =
    case spacing of
        Compact ->
            28

        _ ->
            36


{-| How many rows are drawn beyond the ones in view, above and below, and in how
many rows at a time the drawn rows change (each chunk is a `tbody` of its own,
so that scrolling a few rows moves none of them and the keyboard focus stays).
-}
virtualWindow : { overscan : Int, chunk : Int }
virtualWindow =
    { overscan = 4, chunk = 16 }


{-| The height of a table that scrolls without `maxHeight`.
-}
defaultVirtualHeight : Int
defaultVirtualHeight =
    480


{-| What the window arithmetic needs for this table: the room the rows are seen in
is the scroll area less the header.
-}
virtualGeometry : Config row msg -> Model -> Int -> Window.Geometry
virtualGeometry config model count =
    let
        -- the totals row stays in view at the bottom and covers a row's room (a sum that
        -- does not fit on one line takes a second line, so it is a little taller)
        footPx =
            if List.any (\(Column col) -> hasFooter col) config.columns then
                rowPx model.density + 4

            else
                0

        area =
            case config.maxHeight of
                Just px ->
                    px

                Nothing ->
                    if config.fillHeight then
                        1000

                    else
                        defaultVirtualHeight
    in
    { rowHeight = rowPx model.density
    , viewport = max (rowPx model.density) (area - headPx model.density - footPx)
    , count = count
    }


pageWindow : Config row msg -> Model -> Int -> ( Int, Int, Int )
pageWindow config model total =
    if config.paged then
        let
            size =
                max 1 model.pageSize

            count =
                Pagination.pageCount size total

            current =
                clamp 1 count model.page
        in
        ( current, count, (current - 1) * size )

    else
        ( 1, 1, 0 )


{-| Applies the outside filter, the column filters (except `excluded`, used
for the counts in a filter popover) and the search.
-}
keepMatching : Config row msg -> Model -> List (ColumnConfig row msg) -> List (ColumnConfig row msg) -> Maybe String -> List row -> List row
keepMatching config model allColumns visible excluded allRows =
    let
        loc =
            config.locale

        columnTests =
            model.filters
                |> Dict.toList
                |> List.filter (\( colId, _ ) -> Just colId /= excluded)
                |> List.filterMap (\( colId, f ) -> findColumn colId allColumns |> Maybe.map (\col -> filterTest loc col f))

        tests =
            List.concat
                [ config.rowFilter |> Maybe.map List.singleton |> Maybe.withDefault []
                , columnTests
                , searchTest loc (List.filter .searchable visible) model.search |> Maybe.map List.singleton |> Maybe.withDefault []
                ]
    in
    case tests of
        [] ->
            allRows

        _ ->
            List.filter (\row -> List.all (\test -> test row) tests) allRows


sortRows : Config row msg -> Model -> List (ColumnConfig row msg) -> List row -> List row
sortRows config model allColumns allRows =
    case List.filterMap (\( colId, direction ) -> findColumn colId allColumns |> Maybe.andThen (sortLevel config.locale direction)) model.sort of
        [] ->
            allRows

        levels ->
            Sorting.sort levels allRows


selectWidth : Int
selectWidth =
    40


expandWidth : Int
expandWidth =
    36


menuWidth : Int
menuWidth =
    48


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


{-| The CSV text of some rows: a line of titles, then a line per row with the
exported values of these columns.
-}
csvText : Char -> List (ColumnConfig row msg) -> Locale -> List row -> String
csvText separator exported loc someRows =
    Csv.encode separator
        (List.map .title exported
            :: List.map (\row -> List.map (\col -> exportValue loc col row) exported) someRows
        )


{-| "orders.csv" + "-selected" = "orders-selected.csv" (the suffix is "-valgte" in
Norwegian)
-}
withSuffix : String -> String -> String
withSuffix suffix filename =
    if String.isEmpty suffix then
        filename

    else
        case List.reverse (String.split "." filename) of
            extension :: ((_ :: _) as restReversed) ->
                String.join "." (List.reverse restReversed) ++ suffix ++ "." ++ extension

            _ ->
                filename ++ suffix


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


{-| The popup recipe: a click-away layer, Escape closes and gives focus back
to the trigger, focus leaving the popup (Tab) closes it.
-}
viewPopup : Ctx row msg -> Popup -> { title : String, alignEnd : Bool } -> List (Html msg) -> Html msg
viewPopup ctx popup options content =
    let
        popupId =
            popupDomId ctx.model.id popup
    in
    Html.div
        [ Internal.cls [ "klar-layer" ]

        -- Clicks inside the popup are ignored here instead of being stopped in
        -- the popup: a handler that stops propagation makes Elm render in the
        -- middle of the click, which resets checkboxes before their change
        -- event fires.
        , Events.on "click" (outsideClick popupId (ctx.toMsg PopupClosed))

        -- Escape closes the popup and is used up, so that a dialog around the table stays open
        , Internal.onKeys [ ( "Escape", ctx.toMsg PopupClosed ) ]
        ]
        [ Html.div
            [ Internal.cls
                [ "klar-popup"
                , "klar-table__popover"
                , if options.alignEnd then
                    "klar-popup--end"

                  else
                    ""
                ]
            , Attr.id popupId
            , Attr.tabindex -1
            , Attr.attribute "role" "dialog"
            , Attr.attribute "aria-label" options.title
            , Events.on "focusout" (focusLeft popupId (ctx.toMsg PopupLeft))
            ]
            (Html.div [ Internal.cls [ "klar-table__popover-title" ] ] [ Html.text options.title ] :: content)
        ]


{-| Fires when focus moves to an element outside the popup (Tab, Shift+Tab).
Focus moving inside, or to nothing (the window lost focus), is ignored.
-}
focusLeft : String -> msg -> Decoder msg
focusLeft popupId msg =
    Decode.field "relatedTarget" (Decode.nullable (isInside popupId 0))
        |> Decode.andThen
            (\inside ->
                case inside of
                    Just False ->
                        Decode.succeed msg

                    _ ->
                        Decode.fail "focus stayed inside"
            )


{-| A click on the click-away layer itself, not one that started inside the
popup.
-}
outsideClick : String -> msg -> Decoder msg
outsideClick popupId msg =
    Decode.field "target" (isInside popupId 0)
        |> Decode.andThen
            (\inside ->
                if inside then
                    Decode.fail "click inside the popup"

                else
                    Decode.succeed msg
            )


isInside : String -> Int -> Decoder Bool
isInside targetId depth =
    Decode.oneOf [ Decode.field "id" Decode.string, Decode.succeed "" ]
        |> Decode.andThen
            (\elementId ->
                if elementId == targetId then
                    Decode.succeed True

                else if depth > 40 then
                    Decode.succeed False

                else
                    Decode.oneOf
                        [ Decode.field "parentElement" (Decode.null False)
                        , Decode.field "parentElement" (Decode.lazy (\_ -> isInside targetId (depth + 1)))
                        , Decode.succeed False
                        ]
            )



-- FRAME, HEADER AND BODY


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


{-| In a table that scrolls: is the row that has the tab stop out of the drawn rows?
-}
activeRowHidden : Ctx row msg -> Bool
activeRowHidden ctx =
    ctx.config.virtual
        && ctx.interactiveRows
        && ctx.data.status
        == Ready
        && ctx.data.rowCount
        > 0
        && (ctx.activeRow < ctx.data.first || ctx.activeRow >= ctx.data.first + List.length ctx.data.pageRows)


{-| The scroll area itself got the focus (Tab reached it): focus goes on to the row
that has the tab stop, which is scrolled into view first.
-}
activeRowRequested : Ctx row msg -> Decoder msg
activeRowRequested ctx =
    Decode.at [ "target", "id" ] Decode.string
        |> Decode.andThen
            (\targetId ->
                if targetId == scrollDomId ctx.model.id then
                    Decode.succeed (ctx.toMsg (FocusVirtualRow ctx.activeRow (rowDomId ctx.model.id ctx.activeRow) ctx.geometry))

                else
                    Decode.fail "not the scroll area"
            )


{-| Fixed columns keep their width; the others share the rest and each gets
at least the largest of their minimum widths before the table scrolls.
-}
tableMinWidth : Ctx row msg -> Int
tableMinWidth ctx =
    let
        fixed =
            ctx.visible |> List.filterMap fixedWidth |> List.sum

        flexibleCount =
            ctx.visible |> List.filter (\col -> col.width == Nothing) |> List.length

        system =
            (if ctx.hasSelect then
                selectWidth

             else
                0
            )
                + (if ctx.hasExpand then
                    expandWidth

                   else
                    0
                  )
                + (if ctx.hasMenu then
                    menuWidth

                   else
                    0
                  )
    in
    fixed + system + flexibleCount * flexibleShare ctx


{-| Is there a control in the table itself (a sort button, a filter, a row
that can be focused, controls in a cell) for the keyboard to reach?
-}
hasFocusableContent : Ctx row msg -> Bool
hasFocusableContent ctx =
    ctx.interactiveRows
        || List.any (\col -> isSortable col || usableFilter col /= Nothing || col.controls) ctx.visible


{-| What each column without a fixed width gets when the table is as narrow as
it can be (and therefore scrolls sideways): the largest of their minimum
widths.
-}
flexibleShare : Ctx row msg -> Int
flexibleShare ctx =
    ctx.visible
        |> List.filter (\col -> col.width == Nothing)
        |> List.map flexibleMinWidth
        |> List.maximum
        |> Maybe.withDefault 0


{-| What the sticky columns cover of the scroll area at the table's narrowest:
the pinned first column with the select and expand columns before it, and the
row menu at the other edge. Given to the scroll area as scroll padding, so
that the browser moves a control that got focus (Tab, Shift+Tab) clear of
them instead of leaving it underneath.
-}
scrollVars : Ctx row msg -> List ( String, String )
scrollVars ctx =
    let
        coveredLeft =
            case ctx.visible of
                first :: _ ->
                    if ctx.pinnedFirst then
                        pinLeft ctx
                            + (case fixedWidth first of
                                Just px ->
                                    px

                                Nothing ->
                                    flexibleShare ctx
                              )

                    else
                        0

                [] ->
                    0
    in
    List.concat
        [ case ctx.config.maxHeight of
            Just px ->
                [ ( "max-height", Internal.px px ) ]

            Nothing ->
                if ctx.config.virtual && not ctx.config.fillHeight then
                    [ ( "max-height", Internal.px defaultVirtualHeight ) ]

                else
                    []
        , if coveredLeft > 0 then
            [ ( "--_pin-w", Internal.px coveredLeft ) ]

          else
            []
        , if ctx.hasMenu then
            [ ( "--_menu-w", Internal.px menuWidth ) ]

          else
            []
        ]


viewColgroup : Ctx row msg -> Html msg
viewColgroup ctx =
    let
        fixedCol px =
            Html.col [ Internal.styleVars [ ( "width", Internal.px px ) ] ] []
    in
    Html.colgroup []
        (List.concat
            [ if ctx.hasSelect then
                [ fixedCol selectWidth ]

              else
                []
            , if ctx.hasExpand then
                [ fixedCol expandWidth ]

              else
                []
            , List.map
                (\col ->
                    case fixedWidth col of
                        Just px ->
                            fixedCol px

                        Nothing ->
                            Html.col [] []
                )
                ctx.visible
            , if ctx.hasMenu then
                [ fixedCol menuWidth ]

              else
                []
            ]
        )


{-| The width of a fixed column, never narrower than its header needs.
-}
fixedWidth : ColumnConfig row msg -> Maybe Int
fixedWidth col =
    Maybe.map (max (headerWidth col)) col.width


flexibleMinWidth : ColumnConfig row msg -> Int
flexibleMinWidth col =
    max col.minWidth (headerWidth col)


{-| A generous estimate of what the header needs so its title is not cut:
the title (about 7 px per character at the header's 12 px semibold), the
sort icon, the filter button and the cell padding.
-}
headerWidth : ColumnConfig row msg -> Int
headerWidth col =
    24
        + (if col.controls then
            0

           else
            ceiling (toFloat (String.length col.title) * 7.2)
          )
        + (if isSortable col then
            22

           else
            0
          )
        + (case usableFilter col of
            Just _ ->
                26

            Nothing ->
                0
          )


{-| The column's filter, if it can work: a range filter needs numbers.
-}
usableFilter : ColumnConfig row msg -> Maybe FilterKind
usableFilter col =
    case ( col.filter, col.number ) of
        ( Just RangeFilter, Nothing ) ->
            Nothing

        ( kind, _ ) ->
            kind


{-| Left offset of the pinned column: the select and expand columns before it.
-}
pinLeft : Ctx row msg -> Int
pinLeft ctx =
    (if ctx.hasSelect then
        selectWidth

     else
        0
    )
        + (if ctx.hasExpand then
            expandWidth

           else
            0
          )


systemPinStyle : Ctx row msg -> Int -> Html.Attribute msg
systemPinStyle ctx left =
    if ctx.pinnedFirst then
        Internal.styleVars [ ( "--_pin-left", Internal.px left ) ]

    else
        Internal.noAttr


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


alignClass : String -> Align -> String
alignClass block align =
    case align of
        AlignLeft ->
            ""

        AlignRight ->
            block ++ "--right"

        AlignCenter ->
            block ++ "--center"


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


viewFilterButton : Ctx row msg -> ColumnConfig row msg -> Bool -> Html msg
viewFilterButton ctx col isOpen =
    let
        active =
            case Dict.get col.id ctx.model.inputs of
                Just draft ->
                    toFilter draft /= Nothing

                Nothing ->
                    False

        popup =
            FilterPopup col.id

        name =
            if active then
                ctx.t.filterColumnActive col.title

            else
                ctx.t.filterColumn col.title
    in
    Html.div [ Internal.cls [ "klar-anchor", "klar-table__filter" ] ]
        [ Html.button
            [ Internal.cls
                [ "klar-table__filter-button"
                , if active then
                    "klar-table__filter-button--active"

                  else
                    ""
                ]
            , Attr.type_ "button"
            , Attr.id (triggerDomId ctx.model.id popup)
            , Attr.title name
            , Attr.attribute "aria-label" name
            , Attr.attribute "aria-haspopup" "dialog"

            -- No aria-pressed next to aria-expanded: a button that opens a popup is not also
            -- a toggle. A filter that is on is part of the name.
            , Attr.attribute "aria-expanded"
                (if isOpen then
                    "true"

                 else
                    "false"
                )
            , Events.onClick (ctx.toMsg (PopupOpened popup (filterFocusTargets ctx col)))
            ]
            [ Icon.sized Icon.Small Icon.filter ]
        , if isOpen then
            viewPopup ctx
                popup
                { title = ctx.t.filterTitle col.title
                , alignEnd = col.align == AlignRight
                }
                (viewFilterContent ctx col)

          else
            Html.text ""
        ]


{-| Where focus goes when a filter popover opens: the first of these that
exists.
-}
filterFocusTargets : Ctx row msg -> ColumnConfig row msg -> List String
filterFocusTargets ctx col =
    case usableFilter col of
        Just TextFilter ->
            [ filterInputId ctx.model.id col.id "text" ]

        Just RangeFilter ->
            [ filterInputId ctx.model.id col.id "from" ]

        Just SelectFilter ->
            [ filterInputId ctx.model.id col.id "search", filterInputId ctx.model.id col.id "option-0" ]

        Nothing ->
            []


viewFilterContent : Ctx row msg -> ColumnConfig row msg -> List (Html msg)
viewFilterContent ctx col =
    let
        t =
            ctx.t

        draft =
            Dict.get col.id ctx.model.inputs

        -- anything typed or picked can be cleared, also text that is not a valid filter yet ("abc" in a number field)
        active =
            case draft of
                Just (TextDraft value) ->
                    value /= ""

                Just (RangeDraft from to) ->
                    from /= "" || to /= ""

                Just (ChoiceDraft values) ->
                    not (Set.isEmpty values)

                Nothing ->
                    False

        foot =
            Html.div [ Internal.cls [ "klar-table__popover-foot" ] ]
                [ Button.view
                    [ Button.small
                    , Button.ghost
                    , Button.disabled (not active)
                    , Button.onClick (ctx.toMsg (FilterCleared col.id))
                    ]
                    t.clear
                , Button.view [ Button.small, Button.onClick (ctx.toMsg PopupClosed) ] t.done
                ]
    in
    case usableFilter col of
        Just TextFilter ->
            [ Html.div [ Internal.cls [ "klar-table__popover-body" ] ]
                [ TextInput.view
                    [ TextInput.id (filterInputId ctx.model.id col.id "text")
                    , TextInput.label t.contains
                    , TextInput.clearable
                    , TextInput.locale ctx.loc
                    , TextInput.value
                        (case draft of
                            Just (TextDraft value) ->
                                value

                            _ ->
                                ""
                        )
                    , TextInput.onInput (\value -> ctx.toMsg (FilterTextChanged col.id value ctx.delay))
                    , TextInput.onEnter (ctx.toMsg PopupClosed)
                    ]
                ]
            , foot
            ]

        Just RangeFilter ->
            let
                ( from, to ) =
                    case draft of
                        Just (RangeDraft a b) ->
                            ( a, b )

                        _ ->
                            ( "", "" )

                bounds =
                    case ( ctx.config.server, col.number ) of
                        ( Nothing, Just toNumber ) ->
                            let
                                numbers =
                                    case ctx.config.rows of
                                        Remote.Loaded source ->
                                            List.filterMap toNumber (sourceList source)

                                        _ ->
                                            []
                            in
                            Maybe.map2 Tuple.pair (List.minimum numbers) (List.maximum numbers)

                        _ ->
                            Nothing

                invalid raw =
                    not (String.isEmpty (String.trim raw)) && parseNumber raw == Nothing

                rangeInput part value isFrom =
                    TextInput.view
                        [ TextInput.id (filterInputId ctx.model.id col.id part)
                        , TextInput.label
                            (if isFrom then
                                t.from

                             else
                                t.to
                            )
                        , TextInput.inputMode "decimal"
                        , TextInput.locale ctx.loc
                        , TextInput.value value
                        , TextInput.onInput (\raw -> ctx.toMsg (FilterRangeChanged col.id isFrom raw ctx.delay))
                        , TextInput.onEnter (ctx.toMsg PopupClosed)
                        , TextInput.errorMaybe
                            (if invalid value then
                                Just t.notANumber

                             else
                                Nothing
                            )
                        ]
            in
            [ Html.div [ Internal.cls [ "klar-table__popover-body" ] ]
                [ Html.div [ Internal.cls [ "klar-table__range" ] ]
                    [ rangeInput "from" from True
                    , rangeInput "to" to False
                    ]
                , Internal.viewMaybe
                    (\( low, high ) ->
                        Html.p [ Internal.cls [ "klar-table__popover-note" ] ]
                            [ Html.text (t.rangeHint (formatNumber ctx.loc (rangeDecimals ctx col) low) (formatNumber ctx.loc (rangeDecimals ctx col) high)) ]
                    )
                    bounds
                ]
            , foot
            ]

        Just SelectFilter ->
            viewChoiceFilter ctx col ++ [ foot ]

        Nothing ->
            []


{-| The rows of the table as they came (all rows in client mode, the page in
server mode), or none while they load.
-}
loadedRows : Ctx row msg -> List row
loadedRows ctx =
    case ctx.config.rows of
        Remote.Loaded rowSource ->
            sourceList rowSource

        _ ->
            []


{-| The values a select filter offers (what it keeps, see `choiceOf`): the
column's `filterOptions`, or the distinct values in the rows, in the order of
their labels, plus anything already chosen.
-}
filterValues : Ctx row msg -> ColumnConfig row msg -> (String -> String) -> List String
filterValues ctx col labelOf =
    let
        chosen =
            choicesOf col.id ctx.model.inputs |> Set.map (canonicalChoice col)

        base =
            case col.filterOptions of
                Just options ->
                    List.map .value options

                Nothing ->
                    loadedRows ctx
                        |> List.filter (\row -> not (String.isEmpty (String.trim (col.value ctx.loc row))))
                        |> List.map (choiceOf ctx.loc col)
                        |> Set.fromList
                        |> Set.toList
                        |> List.sortBy (labelOf >> Sorting.collationKey ctx.loc)
    in
    base ++ List.filter (\value -> not (List.member value base)) (Set.toList chosen)


viewChoiceFilter : Ctx row msg -> ColumnConfig row msg -> List (Html msg)
viewChoiceFilter ctx col =
    let
        t =
            ctx.t

        labelOf =
            choiceLabels ctx.loc col (loadedRows ctx)

        values =
            filterValues ctx col labelOf

        chosen =
            choicesOf col.id ctx.model.inputs
                |> Set.map (canonicalChoice col)

        isChosen value =
            Set.member value chosen

        showSearch =
            List.length values > 8

        shown =
            if showSearch && String.trim ctx.model.optionQuery /= "" then
                List.filter (labelOf >> Search.matches ctx.model.optionQuery) values

            else
                values

        -- how many rows each value would add, given the other filters and the search
        counts =
            case ( ctx.config.server, ctx.config.rows ) of
                ( Nothing, Remote.Loaded source ) ->
                    sourceList source
                        |> keepMatching ctx.config ctx.model ctx.allColumns ctx.visible (Just col.id)
                        |> List.foldl
                            (\row dict ->
                                Dict.update (choiceOf ctx.loc col row) (\c -> Just (Maybe.withDefault 0 c + 1)) dict
                            )
                            Dict.empty
                        |> Just

                _ ->
                    Nothing
    in
    [ Html.div [ Internal.cls [ "klar-table__popover-body" ] ]
        [ Internal.viewIf showSearch
            (TextInput.view
                [ TextInput.id (filterInputId ctx.model.id col.id "search")
                , TextInput.label t.searchValues
                , TextInput.labelHidden
                , TextInput.search
                , TextInput.clearable
                , TextInput.size Theme.Small
                , TextInput.placeholder t.searchValues
                , TextInput.locale ctx.loc
                , TextInput.value ctx.model.optionQuery
                , TextInput.onInput (\value -> ctx.toMsg (OptionQueryChanged value))
                ]
            )
        , Html.div [ Internal.cls [ "klar-table__option-actions" ] ]
            [ Button.view
                [ Button.link
                , Button.disabled (List.all isChosen shown)
                , Button.onClick (ctx.toMsg (FilterChoicesSet col.id (Set.toList chosen ++ shown)))
                ]
                t.selectAll
            , Button.view
                [ Button.link
                , Button.disabled (Set.isEmpty chosen)
                , Button.onClick (ctx.toMsg (FilterChoicesSet col.id []))
                ]
                t.selectNone
            ]
        , if List.isEmpty shown then
            Html.p [ Internal.cls [ "klar-table__popover-note" ] ] [ Html.text t.noValues ]

          else
            Html.div [ Internal.cls [ "klar-table__options", "klar-table__options--scroll" ] ]
                (List.indexedMap
                    (\index value ->
                        Html.div [ Internal.cls [ "klar-table__option" ] ]
                            [ Checkbox.view
                                [ Checkbox.id (filterInputId ctx.model.id col.id ("option-" ++ String.fromInt index))
                                , Checkbox.label (labelOf value)
                                , Checkbox.checked (isChosen value)
                                , Checkbox.onCheck (\checked -> ctx.toMsg (FilterChoiceToggled col.id value checked))
                                ]
                            , Internal.viewMaybe
                                (\dict ->
                                    Html.span [ Internal.cls [ "klar-table__option-count", "klar-tabular" ] ]
                                        [ Html.text (Format.int ctx.loc (Dict.get value dict |> Maybe.withDefault 0)) ]
                                )
                                counts
                            ]
                    )
                    shown
                )
        ]
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


{-| Are rows left out by the search or a filter? In client mode: there are rows
before filtering. In server mode: a search or filter is in effect.
-}
isFiltered : Ctx row msg -> Bool
isFiltered ctx =
    not (String.isEmpty ctx.model.search)
        || not (Dict.isEmpty ctx.model.filters)
        || (ctx.config.externalFilters > 0)
        || (ctx.config.server == Nothing && ctx.data.available > 0)


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


{-| The select and expand cells, empty, for skeleton and footer rows.
-}
systemCells : Ctx row msg -> (String -> List (Html msg)) -> List (Html msg)
systemCells ctx content =
    let
        pinClass =
            if ctx.pinnedFirst then
                "klar-table__cell--pinned"

            else
                ""
    in
    List.concat
        [ if ctx.hasSelect then
            [ Html.td [ Internal.cls [ "klar-table__td", "klar-table__td--select", pinClass ], systemPinStyle ctx 0, gridPart ctx "gridcell" ] (content "select") ]

          else
            []
        , if ctx.hasExpand then
            [ Html.td
                [ Internal.cls [ "klar-table__td", "klar-table__td--expand", pinClass ]
                , gridPart ctx "gridcell"
                , systemPinStyle ctx
                    (if ctx.hasSelect then
                        selectWidth

                     else
                        0
                    )
                ]
                (content "expand")
            ]

          else
            []
        ]


dataCellClasses : Ctx row msg -> Int -> ColumnConfig row msg -> List String
dataCellClasses ctx index col =
    [ "klar-table__td"
    , alignClass "klar-table__td" col.align
    , if col.numeric then
        "klar-tabular"

      else
        ""
    , if col.wrap then
        "klar-table__td--wrap"

      else
        ""
    , if col.controls then
        "klar-table__td--controls"

      else
        ""
    , if index == 0 && ctx.pinnedFirst then
        "klar-table__cell--pinned klar-table__cell--pin-edge"

      else
        ""
    ]


{-| The role of a row or cell in the tree grid of a table whose rows expand
(`row`, `columnheader`, `rowheader`, `gridcell`). Every other table is a plain
table, where the elements have their roles already.
-}
gridPart : Ctx row msg -> String -> Html.Attribute msg
gridPart ctx role =
    if isTreegrid ctx then
        Attr.attribute "role" role

    else
        Internal.noAttr


{-| A table whose rows take focus and expand is a `treegrid`, the ARIA pattern
where focus is on rows and ArrowRight and ArrowLeft expand and collapse them, as
here. Rows that only take focus (clickable, selectable, with a menu) keep the
semantics of a plain table: a `grid` would promise arrow keys between cells, and
a screen reader in a grid gives up reading the table cell by cell in browse mode.
-}
isTreegrid : Ctx row msg -> Bool
isTreegrid ctx =
    ctx.interactiveRows && ctx.hasExpand


pinStyle : Ctx row msg -> Int -> Html.Attribute msg
pinStyle ctx index =
    if index == 0 && ctx.pinnedFirst then
        Internal.styleVars [ ( "--_pin-left", Internal.px (pinLeft ctx) ) ]

    else
        Internal.noAttr


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


{-| The keys a Shift range runs over, in the order of the table: the rows of the
page that can be selected, or every matching one in a client table that scrolls.
Only asked for when the user makes a range.
-}
rangeKeys : Ctx row msg -> List String
rangeKeys ctx =
    if isLongClientTable ctx then
        selectableKeys ctx

    else
        ctx.pageKeys


{-| The message of a Shift range that ends on this row, which gets the state the
row is about to get (`checked`), as in a mail client; `Nothing` without an anchor
on this page.
-}
rangeMsg : Ctx row msg -> String -> Bool -> Maybe msg
rangeMsg ctx key checked =
    ctx.model.anchor
        |> Maybe.andThen (\anchorKey -> keysBetween anchorKey key (rangeKeys ctx))
        |> Maybe.map (\keys -> ctx.toMsg (RangeSelected keys checked key))


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


{-| Keys on a focused row, and the keys that move between rows on its checkbox
and its menu button.
-}
rowKeys : Ctx row msg -> RowInfo msg -> Decoder ( msg, Bool )
rowKeys ctx info =
    Decode.map5 (\key targetId command alt shift -> { key = key, targetId = targetId, command = command, alt = alt, shift = shift })
        (Decode.field "key" Decode.string)
        (Decode.oneOf [ Decode.at [ "target", "id" ] Decode.string, Decode.succeed "" ])
        (Decode.map2 (||)
            (Decode.field "ctrlKey" Decode.bool)
            (Decode.field "metaKey" Decode.bool)
        )
        (Decode.field "altKey" Decode.bool)
        (Decode.field "shiftKey" Decode.bool)
        |> Decode.andThen
            (\event ->
                if event.targetId /= info.domId then
                    -- On the row's checkbox or menu button the keys that move to other
                    -- rows still work, unless the control used the key itself (the
                    -- menu button opens its menu with ArrowDown).
                    if List.member event.key [ "ArrowDown", "ArrowUp", "Home", "End", "PageDown", "PageUp" ] && not event.command && not event.alt then
                        Decode.map2 Tuple.pair
                            (Decode.oneOf [ Decode.at [ "target", "type" ] Decode.string, Decode.succeed "" ])
                            (Decode.oneOf [ Decode.field "defaultPrevented" Decode.bool, Decode.succeed False ])
                            |> Decode.andThen
                                (\( targetType, prevented ) ->
                                    if not prevented && (targetType == "checkbox" || event.targetId == info.menuTrigger) then
                                        case rowKeyMsg ctx info event.key event.shift of
                                            Just msg ->
                                                Decode.succeed ( msg, True )

                                            Nothing ->
                                                Decode.fail "unhandled key"

                                    else
                                        Decode.fail "not on a control of the row"
                                )

                    else
                        Decode.fail "not on the row"

                else if event.command && not event.alt && String.toLower event.key == "a" && ctx.hasSelect then
                    -- Ctrl+A (Cmd+A): every row of the page, or every matching row of a table that scrolls
                    Decode.succeed ( ctx.toMsg (RowsSelected (rangeKeys ctx) True), True )

                else if event.command || event.alt then
                    Decode.fail "a key with Ctrl, Cmd or Alt"

                else
                    case rowKeyMsg ctx info event.key event.shift of
                        Just msg ->
                            Decode.succeed ( msg, True )

                        Nothing ->
                            Decode.fail "unhandled key"
            )


{-| The menu key and Shift+F10 can also arrive as a `contextmenu` event, which
the browser answers with its own menu unless the page does something with it.
That event has `button` 0 when it comes from the keyboard (or a long press) and
2 from a right click, which keeps the browser's menu.
-}
rowContextMenu : RowInfo msg -> Decoder ( msg, Bool )
rowContextMenu info =
    Decode.field "button" Decode.int
        |> Decode.andThen
            (\button ->
                case ( button, info.menu ) of
                    ( 0, Just msg ) ->
                        Decode.succeed ( msg, True )

                    _ ->
                        Decode.fail "a right click, or a row without a menu"
            )


rowKeyMsg : Ctx row msg -> RowInfo msg -> String -> Bool -> Maybe msg
rowKeyMsg ctx info key shift =
    let
        focusRow target =
            if target >= 0 && target < ctx.rowCount && target /= info.index then
                if ctx.config.virtual then
                    Just (ctx.toMsg (FocusVirtualRow target (rowDomId ctx.model.id target) ctx.geometry))

                else
                    Just (ctx.toMsg (FocusRow target (rowDomId ctx.model.id target)))

            else
                Just (ctx.toMsg NoOp)

        -- ten rows at a time, or a screenful when the table scrolls; otherwise the
        -- page scrolls away from the focused row
        jump =
            if ctx.config.virtual then
                Window.rowsPerScreen ctx.geometry

            else
                10
    in
    case key of
        "ArrowDown" ->
            focusRow (info.index + 1)

        "ArrowUp" ->
            focusRow (info.index - 1)

        "Home" ->
            focusRow 0

        "End" ->
            focusRow (ctx.rowCount - 1)

        "PageDown" ->
            focusRow (min (ctx.rowCount - 1) (info.index + jump))

        "PageUp" ->
            focusRow (max 0 (info.index - jump))

        "Enter" ->
            case info.click of
                Just msg ->
                    Just msg

                Nothing ->
                    -- a row that does nothing else when clicked opens its menu
                    if isJust ctx.config.onRowClick || ctx.hasExpand then
                        Nothing

                    else
                        info.menu

        -- the context menu key and Shift+F10: the row's "more" menu
        "ContextMenu" ->
            info.menu

        "F10" ->
            if shift then
                info.menu

            else
                Nothing

        " " ->
            if ctx.hasSelect && not info.disabled then
                -- Shift+Space: the rows from the anchor to this one
                case
                    if shift then
                        rangeMsg ctx info.key (not info.selected)

                    else
                        Nothing
                of
                    Just msg ->
                        Just msg

                    Nothing ->
                        Just (ctx.toMsg (RowSelected info.key (not info.selected)))

            else
                Nothing

        "ArrowRight" ->
            if ctx.hasExpand && not info.expanded && not info.disabled then
                Just (ctx.toMsg (ExpandToggled info.key))

            else
                Nothing

        "ArrowLeft" ->
            if ctx.hasExpand && info.expanded && not info.disabled then
                Just (ctx.toMsg (ExpandToggled info.key))

            else
                Nothing

        _ ->
            Nothing


{-| A row click, unless it started on a control inside the row (a button, a
link, a checkbox, a menu, an inline action).
-}
ignoreControls : msg -> Decoder msg
ignoreControls msg =
    Decode.field "target" (startsOnControl 0)
        |> Decode.andThen
            (\onControl ->
                if onControl then
                    Decode.fail "click on a control"

                else
                    Decode.succeed msg
            )


startsOnControl : Int -> Decoder Bool
startsOnControl depth =
    Decode.map2 Tuple.pair
        (Decode.oneOf [ Decode.field "tagName" Decode.string, Decode.succeed "" ])
        (Decode.oneOf [ Decode.field "className" Decode.string, Decode.succeed "" ])
        |> Decode.andThen
            (\( tag, className ) ->
                if tag == "" || tag == "TR" || tag == "TABLE" || depth > 20 then
                    Decode.succeed False

                else if
                    List.member tag [ "A", "BUTTON", "INPUT", "SELECT", "TEXTAREA", "LABEL", "SUMMARY" ]
                        || String.contains "klar-anchor" className
                        || String.contains "klar-layer" className
                        || String.contains "klar-table__td--control" className
                then
                    Decode.succeed True

                else
                    Decode.oneOf
                        [ Decode.field "parentElement" (Decode.lazy (\_ -> startsOnControl (depth + 1)))
                        , Decode.succeed False
                        ]
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
