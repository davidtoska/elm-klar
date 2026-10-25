module Klar.Table.Body exposing (..)

{-| Loading, empty, failed and data bodies, keyed rows, details and cells.
-}

import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Events
import Html.Keyed
import Json.Decode as Decode exposing (Decoder)
import Klar.Button as Button
import Klar.Checkbox as Checkbox
import Klar.EmptyState as EmptyState
import Klar.ErrorState as ErrorState
import Klar.Icon as Icon
import Klar.Internal as Internal
import Klar.Internal.Window as Window
import Klar.Menu as Menu
import Klar.Search as Search
import Klar.Skeleton as Skeleton
import Klar.Table.DomIds exposing (bulkDomId, detailDomId, filterInputId, popupDomId, popupSuffix, rowDomId, scrollDomId, triggerDomId)
import Klar.Table.Identity exposing (idsOf, isJust, keysBetween, keysOf, lookup, toggled)
import Klar.Table.Keyboard exposing (ignoreControls, rangeKeys, rangeMsg, rowContextMenu, rowKeyMsg, rowKeys, startsOnControl)
import Klar.Table.Layout exposing (activeRowHidden, activeRowRequested, alignClass, dataCellClasses, expandWidth, fixedWidth, flexibleMinWidth, flexibleShare, gridPart, hasFocusableContent, headerWidth, isFiltered, isTreegrid, menuWidth, pinLeft, pinStyle, scrollVars, selectWidth, systemCells, systemPinStyle, tableMinWidth, usableFilter, viewColgroup)
import Klar.Table.Selection exposing (clearSelection, deselect, dropAllMatching, dropAllMatchingOf, everyRowCanBeSelected, isLongClientTable, isPicked, isSelected, matchingSelectionState, pick, rowIsDisabled, select, selectableCount, selectableKeys, selectedCount, selectedIds, selection, selectionTotal, setSelectedIds)
import Klar.Table.Toolbar exposing (activeFilterCount, densityComfortable, densityCompact, densityNormal, describeDraft, hasToolbar, hasTools, resetFiltersButton, viewColumnsMenu, viewDensity, viewFilterSummary, viewSearch, viewToolbar, withAppReset)
import Klar.Table.Types exposing (Align(..), Attribute(..), Column(..), ColumnAttribute(..), ColumnConfig, ColumnId(..), Config, Ctx, Data, DataStatus(..), Direction(..), Draft(..), Filter(..), FilterKind(..), Footer(..), Model, MoneyTotal, Msg(..), Picked(..), Popup(..), Query, RowInfo, Rows(..), Selection(..), SortBy(..), Source(..), State(..))
import Klar.Table.Window exposing (defaultVirtualHeight, headPx, pageWindow, rowPx, virtualGeometry, virtualWindow)
import Set exposing (Set)


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
