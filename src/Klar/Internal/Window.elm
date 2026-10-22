module Klar.Internal.Window exposing
    ( Geometry
    , Window
    , clampScroll
    , rowsPerScreen
    , scrollToRow
    , window
    )

{-| The arithmetic of a list that draws only the rows in view: which rows to draw
for a scroll offset, how much room the rows that are not drawn take, and where to
scroll to bring a row into view. Every row has the same height in pixels.

`Klar.Table` (the rows of a long table) and `Klar.VirtualList` (the rows of a long
list) both use it, so a row that is at the top of one is at the top of the other.

-}


{-| What the arithmetic needs to know. `viewport` is the height in pixels of the
room the rows are seen in (a table does not count its sticky header), `count` the
number of rows and `rowHeight` the height of each.
-}
type alias Geometry =
    { rowHeight : Int
    , viewport : Int
    , count : Int
    }


{-| The rows to draw: from `first` up to, not including, `end`, and the height in
pixels of the empty room before them and after them.
-}
type alias Window =
    { first : Int
    , end : Int
    , before : Int
    , after : Int
    }


{-| The rows in view at this scroll offset, and `overscan` more on each side, so
that a quick scroll does not show empty room before the next message arrives.
The window starts and ends at a multiple of `chunk` rows (or at the end of the
list), so that it moves a chunk at a time: a few rows of scrolling change
nothing, and a screenful changes one chunk, which a keyed list diffs without
moving the rows that stay (moving a row takes the keyboard focus out of it).
-}
window : { overscan : Int, chunk : Int } -> Geometry -> Float -> Window
window { overscan, chunk } geometry scroll =
    let
        height =
            max 1 geometry.rowHeight

        size =
            max 1 chunk

        top =
            clampScroll geometry scroll

        firstInView =
            floor (top / toFloat height)

        inView =
            ceiling (toFloat (max 0 geometry.viewport) / toFloat height) + 1

        first =
            max 0 (min geometry.count ((firstInView - max 0 overscan) // size * size))

        end =
            max first (min geometry.count (ceilingTo size (firstInView + inView + max 0 overscan)))
    in
    { first = first
    , end = end
    , before = first * height
    , after = (geometry.count - end) * height
    }


ceilingTo : Int -> Int -> Int
ceilingTo size n =
    (n + size - 1) // size * size


{-| Keeps a scroll offset between the top and the furthest the rows can scroll.
-}
clampScroll : Geometry -> Float -> Float
clampScroll geometry scroll =
    let
        furthest =
            max 0 (geometry.count * max 1 geometry.rowHeight - max 0 geometry.viewport)
    in
    clamp 0 (toFloat furthest) scroll


{-| The scroll offset that shows row `row` (counting from 0) in full, moving as
little as possible from the current one.
-}
scrollToRow : Geometry -> Float -> Int -> Float
scrollToRow geometry scroll row =
    let
        height =
            toFloat (max 1 geometry.rowHeight)

        top =
            clampScroll geometry scroll

        rowTop =
            toFloat (clamp 0 (max 0 (geometry.count - 1)) row) * height

        rowBottom =
            rowTop + height

        viewport =
            toFloat (max 0 geometry.viewport)
    in
    if rowTop < top then
        clampScroll geometry rowTop

    else if rowBottom > top + viewport then
        clampScroll geometry (rowBottom - viewport)

    else
        top


{-| How many whole rows fit in the viewport, at least 1: what PageUp and
PageDown move by.
-}
rowsPerScreen : Geometry -> Int
rowsPerScreen geometry =
    max 1 (max 0 geometry.viewport // max 1 geometry.rowHeight)
