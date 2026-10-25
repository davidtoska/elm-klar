module Klar.Table.HeaderFilters exposing (..)

{-| Column filter buttons, popovers and option counts.
-}

import Array exposing (Array)
import Dict exposing (Dict)
import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Events
import Klar.Button as Button
import Klar.Checkbox as Checkbox
import Klar.Format as Format
import Klar.Icon as Icon
import Klar.Internal as Internal
import Klar.Money as Money exposing (Money)
import Klar.Remote as Remote exposing (Problem, Remote)
import Klar.Search as Search
import Klar.Table.DomIds exposing (bulkDomId, detailDomId, filterInputId, popupDomId, popupSuffix, rowDomId, scrollDomId, triggerDomId)
import Klar.Table.Filter exposing (activeDrafts, canonicalChoice, choiceLabels, choiceOf, choicesOf, filterTest, fold, localChoice, parseNumber, searchTest, searchText, searchWords, toDraft, toFilter, withinRange)
import Klar.Table.Layout exposing (activeRowHidden, activeRowRequested, alignClass, dataCellClasses, expandWidth, fixedWidth, flexibleMinWidth, flexibleShare, gridPart, hasFocusableContent, headerWidth, isFiltered, isTreegrid, menuWidth, pinLeft, pinStyle, scrollVars, selectWidth, systemCells, systemPinStyle, tableMinWidth, usableFilter, viewColgroup)
import Klar.Table.Numeric exposing (formatNumber, majorAmount, moneyTotals, plainDecimal)
import Klar.Table.Popup exposing (focusLeft, isInside, outsideClick, viewPopup)
import Klar.Table.Processing exposing (keepMatching, process, processClient, sortLevels, sortRows)
import Klar.Table.Rows exposing (prepareRows, rowsArray, sourceArray, sourceList, usablePrepared)
import Klar.Table.Sort as Sorting
import Klar.Table.Types exposing (Align(..), Attribute(..), Column(..), ColumnAttribute(..), ColumnConfig, ColumnId(..), Config, Ctx, Data, DataStatus(..), Direction(..), Draft(..), Filter(..), FilterKind(..), Footer(..), Model, MoneyTotal, Msg(..), Picked(..), Popup(..), Query, RowInfo, Rows(..), Selection(..), SortBy(..), Source(..), State(..))
import Klar.TextInput as TextInput
import Klar.Theme as Theme exposing (Density(..), Tone)
import Set exposing (Set)


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
