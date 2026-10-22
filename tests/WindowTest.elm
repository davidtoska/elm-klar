module WindowTest exposing (suite)

import Expect
import Fuzz
import Klar.Internal.Window as Window exposing (Geometry)
import Test exposing (Test, describe, fuzz2, test)


geometry : Int -> Geometry
geometry count =
    { rowHeight = 36, viewport = 360, count = count }


suite : Test
suite =
    describe "Klar.Internal.Window"
        [ describe "window"
            [ test "at the top it starts at row 0 and takes the rows in view and the overscan" <|
                \_ ->
                    -- 10 rows in view, one more for a half row, then 3 of overscan
                    Expect.equal { first = 0, end = 14, before = 0, after = (1000 - 14) * 36 }
                        (Window.window { overscan = 3, chunk = 1 } (geometry 1000) 0)
            , test "scrolled by 100 rows it starts that many rows down, less the overscan" <|
                \_ ->
                    Expect.equal { first = 97, end = 114, before = 97 * 36, after = (1000 - 114) * 36 }
                        (Window.window { overscan = 3, chunk = 1 } (geometry 1000) (100 * 36))
            , test "at the end it stops at the last row" <|
                \_ ->
                    -- the furthest offset has row 990 at the top
                    Window.window { overscan = 3, chunk = 1 } (geometry 1000) (1000 * 36)
                        |> Expect.equal { first = 987, end = 1000, before = 987 * 36, after = 0 }
            , test "a short list is drawn whole" <|
                \_ ->
                    Expect.equal { first = 0, end = 4, before = 0, after = 0 }
                        (Window.window { overscan = 6, chunk = 1 } (geometry 4) 0)
            , test "no rows, no window" <|
                \_ ->
                    Expect.equal { first = 0, end = 0, before = 0, after = 0 }
                        (Window.window { overscan = 6, chunk = 1 } (geometry 0) 500)
            , test "with chunks the window starts and ends on a multiple of the chunk" <|
                \_ ->
                    -- row 100 at the top: 97 is the first wanted, 114 the last
                    Expect.equal { first = 96, end = 128, before = 96 * 36, after = (1000 - 128) * 36 }
                        (Window.window { overscan = 3, chunk = 16 } (geometry 1000) (100 * 36))
            , fuzz2 (Fuzz.intRange 0 5000) (Fuzz.floatRange 0 300000) "scrolling by less than a row moves the window by whole chunks only" <|
                \count scroll ->
                    let
                        a =
                            Window.window { overscan = 4, chunk = 16 } (geometry count) scroll

                        b =
                            Window.window { overscan = 4, chunk = 16 } (geometry count) (scroll + 17)
                    in
                    Expect.all
                        [ \_ -> Expect.equal 0 (modBy 16 a.first)
                        , \_ -> Expect.equal True (modBy 16 a.end == 0 || a.end == count)
                        , \_ -> Expect.atMost 16 (abs (b.first - a.first))
                        ]
                        ()
            , fuzz2 (Fuzz.intRange 0 5000) (Fuzz.floatRange -100 300000) "the rows and the room around them always add up to the whole list" <|
                \count scroll ->
                    let
                        w =
                            Window.window { overscan = 4, chunk = 1 } (geometry count) scroll
                    in
                    Expect.equal (count * 36) (w.before + (w.end - w.first) * 36 + w.after)
            , fuzz2 (Fuzz.intRange 1 5000) (Fuzz.floatRange 0 300000) "the rows in view are always drawn" <|
                \count scroll ->
                    let
                        g =
                            geometry count

                        w =
                            Window.window { overscan = 0, chunk = 1 } g scroll

                        top =
                            Window.clampScroll g scroll

                        lastInView =
                            min (count - 1) (floor ((top + 360 - 1) / 36))
                    in
                    Expect.all
                        [ \_ -> Expect.atMost (floor (top / 36)) w.first
                        , \_ -> Expect.atLeast (lastInView + 1) w.end
                        ]
                        ()
            ]
        , describe "clampScroll"
            [ test "stays between the top and the furthest offset" <|
                \_ ->
                    Expect.equal [ 0, 0, 1000 * 36 - 360 ]
                        (List.map (Window.clampScroll (geometry 1000)) [ -5, 0, 1.0e9 ])
            , test "a list that fits cannot scroll" <|
                \_ -> Expect.equal 0 (Window.clampScroll (geometry 5) 200)
            ]
        , describe "scrollToRow"
            [ test "a row in view does not move the list" <|
                \_ -> Expect.equal 720 (Window.scrollToRow (geometry 1000) 720 25)
            , test "a row above moves its top to the top" <|
                \_ -> Expect.equal (10 * 36) (Window.scrollToRow (geometry 1000) 720 10)
            , test "a row below moves its bottom to the bottom" <|
                \_ -> Expect.equal (41 * 36 - 360 + 36) (Window.scrollToRow (geometry 1000) 720 41)
            , test "the last row can be reached" <|
                \_ -> Expect.equal (1000 * 36 - 360) (Window.scrollToRow (geometry 1000) 0 999)
            , fuzz2 (Fuzz.intRange 1 3000) (Fuzz.intRange 0 100000) "the row is in view afterwards" <|
                \count start ->
                    let
                        g =
                            geometry count

                        row =
                            modBy count start

                        top =
                            Window.scrollToRow g (toFloat start) row
                    in
                    Expect.all
                        [ \_ -> Expect.atLeast 0 top
                        , \_ -> Expect.atMost (toFloat (max 0 (count * 36 - 360))) top
                        , \_ -> Expect.atMost (toFloat row * 36) top
                        , \_ -> Expect.atLeast (toFloat (row * 36 + 36 - 360)) top
                        ]
                        ()
            ]
        , describe "rowsPerScreen"
            [ test "counts whole rows" <|
                \_ -> Expect.equal 10 (Window.rowsPerScreen (geometry 100))
            , test "is at least 1" <|
                \_ -> Expect.equal 1 (Window.rowsPerScreen { rowHeight = 36, viewport = 10, count = 100 })
            ]
        ]
