module Klar.Table.Window exposing (..)

{-| Pure pagination and virtual-row geometry, in the same units as the table stylesheet.
-}

import Klar.Internal.Window as Window
import Klar.Pagination as Pagination
import Klar.Table.ColumnLogic exposing (exportValue, findColumn, hasFooter, isShown, isSortable, sortKeyOf, sortLevel, visibleColumns)
import Klar.Table.Types exposing (Align(..), Attribute(..), Column(..), ColumnAttribute(..), ColumnConfig, ColumnId(..), Config, Ctx, Data, DataStatus(..), Direction(..), Draft(..), Filter(..), FilterKind(..), Footer(..), Model, MoneyTotal, Msg(..), Picked(..), Popup(..), Query, RowInfo, Rows(..), Selection(..), SortBy(..), Source(..), State(..))
import Klar.Theme as Theme exposing (Density(..), Tone)


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
