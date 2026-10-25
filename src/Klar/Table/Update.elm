module Klar.Table.Update exposing (..)

{-| Table state transitions and their focus, debounce, scrolling and download commands.
-}

import Browser.Dom as Dom
import Dict exposing (Dict)
import File.Download as Download
import Klar.Internal as Internal
import Klar.Internal.Window as Window
import Klar.Menu as Menu
import Klar.Table.DomIds exposing (bulkDomId, detailDomId, filterInputId, popupDomId, popupSuffix, rowDomId, scrollDomId, triggerDomId)
import Klar.Table.Filter exposing (activeDrafts, canonicalChoice, choiceLabels, choiceOf, choicesOf, filterTest, fold, localChoice, parseNumber, searchTest, searchText, searchWords, toDraft, toFilter, withinRange)
import Klar.Table.Identity exposing (idsOf, isJust, keysBetween, keysOf, lookup, toggled)
import Klar.Table.Selection exposing (clearSelection, deselect, dropAllMatching, dropAllMatchingOf, everyRowCanBeSelected, isLongClientTable, isPicked, isSelected, matchingSelectionState, pick, rowIsDisabled, select, selectableCount, selectableKeys, selectedCount, selectedIds, selection, selectionTotal, setSelectedIds)
import Klar.Table.State exposing (clearFilters, collapse, collapseAll, columnId, columnName, density, expand, expandedIds, filters, init, isColumnVisible, isExpanded, page, pageSize, query, search, setColumnVisible, setDensity, setExpandedIds, setFilter, setPage, setPageSize, setQuery, setSearch, setSort, settled, sort, toggle)
import Klar.Table.Types exposing (Align(..), Attribute(..), Column(..), ColumnAttribute(..), ColumnConfig, ColumnId(..), Config, Ctx, Data, DataStatus(..), Direction(..), Draft(..), Filter(..), FilterKind(..), Footer(..), Model, MoneyTotal, Msg(..), Picked(..), Popup(..), Query, RowInfo, Rows(..), Selection(..), SortBy(..), Source(..), State(..))
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
