module Klar.Table.Footer exposing (..)

{-| Column aggregates, range announcements and pagination controls.
-}

import Html exposing (Html)
import Html.Attributes as Attr
import Klar.Format as Format
import Klar.Internal as Internal
import Klar.Internal.Window as Window
import Klar.Money as Money exposing (Money)
import Klar.Pagination as Pagination
import Klar.Spinner as Spinner
import Klar.Table.ColumnLogic exposing (exportValue, findColumn, hasFooter, isShown, isSortable, sortKeyOf, sortLevel, visibleColumns)
import Klar.Table.Layout exposing (activeRowHidden, activeRowRequested, alignClass, dataCellClasses, expandWidth, fixedWidth, flexibleMinWidth, flexibleShare, gridPart, hasFocusableContent, headerWidth, isFiltered, isTreegrid, menuWidth, pinLeft, pinStyle, scrollVars, selectWidth, systemCells, systemPinStyle, tableMinWidth, usableFilter, viewColgroup)
import Klar.Table.Numeric exposing (formatNumber, majorAmount, moneyTotals, plainDecimal)
import Klar.Table.State exposing (clearFilters, collapse, collapseAll, columnId, columnName, density, expand, expandedIds, filters, init, isColumnVisible, isExpanded, page, pageSize, query, search, setColumnVisible, setDensity, setExpandedIds, setFilter, setPage, setPageSize, setQuery, setSearch, setSort, settled, sort, toggle)
import Klar.Table.Types exposing (Align(..), Attribute(..), Column(..), ColumnAttribute(..), ColumnConfig, ColumnId(..), Config, Ctx, Data, DataStatus(..), Direction(..), Draft(..), Filter(..), FilterKind(..), Footer(..), Model, MoneyTotal, Msg(..), Picked(..), Popup(..), Query, RowInfo, Rows(..), Selection(..), SortBy(..), Source(..), State(..))
import Klar.Theme as Theme exposing (Density(..), Tone)


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
