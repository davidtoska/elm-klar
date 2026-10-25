module Klar.Table.Layout exposing (..)

{-| Shared table geometry, column sizing, pinned cells and accessibility attributes.
-}

import Dict exposing (Dict)
import Html exposing (Html)
import Html.Attributes as Attr
import Json.Decode as Decode exposing (Decoder)
import Klar.Internal as Internal
import Klar.Table.ColumnLogic exposing (exportValue, findColumn, hasFooter, isShown, isSortable, sortKeyOf, sortLevel, visibleColumns)
import Klar.Table.DomIds exposing (bulkDomId, detailDomId, filterInputId, popupDomId, popupSuffix, rowDomId, scrollDomId, triggerDomId)
import Klar.Table.Types exposing (Align(..), Attribute(..), Column(..), ColumnAttribute(..), ColumnConfig, ColumnId(..), Config, Ctx, Data, DataStatus(..), Direction(..), Draft(..), Filter(..), FilterKind(..), Footer(..), Model, MoneyTotal, Msg(..), Picked(..), Popup(..), Query, RowInfo, Rows(..), Selection(..), SortBy(..), Source(..), State(..))
import Klar.Table.Window exposing (defaultVirtualHeight, headPx, pageWindow, rowPx, virtualGeometry, virtualWindow)


selectWidth : Int
selectWidth =
    40


expandWidth : Int
expandWidth =
    36


menuWidth : Int
menuWidth =
    48


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


alignClass : String -> Align -> String
alignClass block align =
    case align of
        AlignLeft ->
            ""

        AlignRight ->
            block ++ "--right"

        AlignCenter ->
            block ++ "--center"


{-| Are rows left out by the search or a filter? In client mode: there are rows
before filtering. In server mode: a search or filter is in effect.
-}
isFiltered : Ctx row msg -> Bool
isFiltered ctx =
    not (String.isEmpty ctx.model.search)
        || not (Dict.isEmpty ctx.model.filters)
        || (ctx.config.externalFilters > 0)
        || (ctx.config.server == Nothing && ctx.data.available > 0)


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
