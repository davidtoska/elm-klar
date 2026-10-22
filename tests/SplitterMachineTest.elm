module SplitterMachineTest exposing (suite)

import Browser.Dom as Dom
import Expect exposing (Expectation)
import Fuzz
import Klar.Splitter.Layout as Layout
import Klar.Splitter.Machine as Machine exposing (Device(..), Layout, Msg(..), Sample)
import Test exposing (Test, describe, fuzz, test)


suite : Test
suite =
    describe "Splitter: the state machine"
        [ dragTests
        , limitTests
        , keyboardTests
        , foldTests
        , robustnessTests
        ]



-- TWO PANES AND THREE


request : Layout.Request
request =
    { minShare = 0, maxShare = 1, minPixels = 0, maxPixels = Nothing }


two : Layout
two =
    { requests = [ request, request ], collapsible = [ False, False ], stacked = False }


three : Layout
three =
    { requests = [ request, request, request ], collapsible = [ False, False, False ], stacked = False }


withRequests : List Layout.Request -> Layout -> Layout
withRequests requests layout =
    { layout | requests = requests }


foldable : List Bool -> Layout -> Layout
foldable flags layout =
    { layout | collapsible = flags }


fresh : List Float -> Machine.State
fresh sizes =
    Machine.init "split" sizes


run : List Msg -> Machine.State -> Machine.State
run messages state =
    List.foldl (\msg current -> Tuple.first (Machine.update msg current)) state messages


at : Float -> Float -> Int -> Sample
at x y buttons =
    { x = x, y = y, buttons = buttons }


{-| The container, this wide and this high, as the browser reports it.
-}
container : Float -> Float -> Dom.Element
container width height =
    { scene = { width = width, height = height }
    , viewport = { x = 0, y = 0, width = width, height = height }
    , element = { x = 0, y = 0, width = width, height = height }
    }


{-| A container that is 808 pixels wide: 800 for the panes of two, and one gutter.
-}
measuredTwo : Int -> Msg
measuredTwo serial =
    Measured serial two (Ok (container 808 400))


serialOf : Machine.State -> Int
serialOf state =
    state.serial


sizesOf : Machine.State -> List Float
sizesOf state =
    List.map (\size -> toFloat (round (size * 1000)) / 1000) state.sizes


dragging : Machine.State -> Bool
dragging state =
    state.drag /= Nothing



-- DRAG


dragTests : Test
dragTests =
    let
        pressed =
            run [ Press two 0 Mouse (at 400 50 1) ] (fresh [ 0.5, 0.5 ])

        measured =
            run [ measuredTwo (serialOf pressed) ] pressed
    in
    describe "drag"
        [ test "a press starts a drag from the sizes there are" <|
            \_ -> Expect.equal ( True, [ 0.5, 0.5 ] ) ( dragging pressed, sizesOf pressed )
        , test "the pointer moves the separator by the same share of the room" <|
            \_ -> Expect.equal [ 0.6, 0.4 ] (sizesOf (run [ PointerMoved (at 480 50 1) ] measured))
        , test "and back" <|
            \_ -> Expect.equal [ 0.3, 0.7 ] (sizesOf (run [ PointerMoved (at 480 50 1), PointerMoved (at 240 50 1) ] measured))
        , test "up and down do not matter in a row" <|
            \_ -> Expect.equal [ 0.6, 0.4 ] (sizesOf (run [ PointerMoved (at 480 9000 1) ] measured))
        , test "the pointer may go before the container is measured: the drag catches up" <|
            \_ ->
                let
                    early =
                        run [ PointerMoved (at 480 50 1) ] pressed
                in
                Expect.equal ( [ 0.5, 0.5 ], [ 0.6, 0.4 ] ) ( sizesOf early, sizesOf (run [ measuredTwo (serialOf early) ] early) )
        , test "letting go ends the drag and keeps the sizes" <|
            \_ ->
                let
                    after =
                        run [ PointerMoved (at 480 50 1), Release ] measured
                in
                Expect.equal ( False, [ 0.6, 0.4 ] ) ( dragging after, sizesOf after )
        , test "Escape ends the drag and puts the sizes back" <|
            \_ ->
                let
                    after =
                        run [ PointerMoved (at 480 50 1), Cancel ] measured
                in
                Expect.equal ( False, [ 0.5, 0.5 ] ) ( dragging after, sizesOf after )
        , test "a mouse button that was let go unseen ends the drag where it is" <|
            \_ ->
                let
                    after =
                        run [ PointerMoved (at 480 50 1), PointerMoved (at 560 50 0), PointerMoved (at 100 50 1) ] measured
                in
                Expect.equal ( False, [ 0.6, 0.4 ] ) ( dragging after, sizesOf after )
        , test "a finger has no buttons to check" <|
            \_ ->
                let
                    touching =
                        run [ Press two 0 Touch (at 400 50 1) ] (fresh [ 0.5, 0.5 ])

                    after =
                        run [ measuredTwo (serialOf touching), PointerMoved (at 480 50 0) ] touching
                in
                Expect.equal ( True, [ 0.6, 0.4 ] ) ( dragging after, sizesOf after )
        , test "stacked panes follow the height" <|
            \_ ->
                let
                    stackedTwo =
                        { two | stacked = True }

                    start =
                        run [ Press stackedTwo 0 Mouse (at 50 200 1) ] (fresh [ 0.5, 0.5 ])

                    after =
                        run [ Measured (serialOf start) stackedTwo (Ok (container 300 408)), PointerMoved (at 9000 240 1) ] start
                in
                Expect.equal [ 0.6, 0.4 ] (sizesOf after)
        , test "the drag works from the sizes at the start, so it comes back exactly" <|
            \_ ->
                run [ PointerMoved (at 700 50 1), PointerMoved (at 400 50 1) ] measured
                    |> sizesOf
                    |> Expect.equal [ 0.5, 0.5 ]
        , test "three panes: only the two beside the separator change" <|
            \_ ->
                let
                    start =
                        run [ Press three 1 Mouse (at 500 50 1) ] (fresh [ 0.25, 0.5, 0.25 ])

                    after =
                        run [ Measured (serialOf start) three (Ok (container 816 400)), PointerMoved (at 580 50 1) ] start
                in
                Expect.equal [ 0.25, 0.6, 0.15 ] (sizesOf after)
        , test "a press on a separator that is not there does nothing" <|
            \_ ->
                Expect.equal False (dragging (run [ Press two 1 Mouse (at 0 0 1), Press two -1 Mouse (at 0 0 1) ] (fresh [ 0.5, 0.5 ])))
        ]



-- LIMITS


limitTests : Test
limitTests =
    let
        dragFrom layout start sizes x =
            let
                pressed =
                    run [ Press layout 0 Mouse (at start 50 1) ] (fresh sizes)
            in
            run [ Measured (serialOf pressed) layout (Ok (container 808 400)), PointerMoved (at x 50 1) ] pressed
    in
    describe "limits"
        [ test "a pane never gets smaller than its smallest size in percent" <|
            \_ ->
                dragFrom (withRequests [ request, { request | minShare = 0.3 } ] two) 400 [ 0.5, 0.5 ] 9000
                    |> sizesOf
                    |> Expect.equal [ 0.7, 0.3 ]
        , test "nor than its smallest size in pixels, once the container is known" <|
            \_ ->
                dragFrom (withRequests [ { request | minPixels = 400 }, request ] two) 400 [ 0.5, 0.5 ] -9000
                    |> sizesOf
                    |> Expect.equal [ 0.5, 0.5 ]
        , test "pixels become a share of the room: 240 of 800 is 30 percent" <|
            \_ ->
                dragFrom (withRequests [ { request | minPixels = 240 }, request ] two) 400 [ 0.5, 0.5 ] -9000
                    |> sizesOf
                    |> Expect.equal [ 0.3, 0.7 ]
        , test "a pane never gets larger than its largest size" <|
            \_ ->
                dragFrom (withRequests [ { request | maxShare = 0.6 }, request ] two) 400 [ 0.5, 0.5 ] 9000
                    |> sizesOf
                    |> Expect.equal [ 0.6, 0.4 ]
        , test "sizes that start outside their limits are brought in when the user moves a separator" <|
            \_ ->
                dragFrom (withRequests [ { request | minShare = 0.4 }, request ] two) 400 [ 0.1, 0.9 ] 400
                    |> sizesOf
                    |> Expect.equal [ 0.4, 0.6 ]
        , test "the view and the state agree on the sizes that are drawn" <|
            \_ ->
                let
                    layout =
                        withRequests [ { request | minShare = 0.4 }, request ] two
                in
                Machine.effective layout (fresh [ 0.1, 0.9 ])
                    |> List.map (\size -> toFloat (round (size * 1000)) / 1000)
                    |> Expect.equal [ 0.4, 0.6 ]
        ]



-- KEYBOARD


keyboardTests : Test
keyboardTests =
    describe "keyboard"
        [ test "one percent a step" <|
            \_ -> Expect.equal [ 0.51, 0.49 ] (sizesOf (run [ Nudge two 0 0.01 ] (fresh [ 0.5, 0.5 ])))
        , test "a large step" <|
            \_ -> Expect.equal [ 0.4, 0.6 ] (sizesOf (run [ Nudge two 0 -0.1 ] (fresh [ 0.5, 0.5 ])))
        , test "a step stops at the limits" <|
            \_ ->
                let
                    layout =
                        withRequests [ request, { request | minShare = 0.45 } ] two
                in
                Expect.equal [ 0.55, 0.45 ] (sizesOf (run [ Nudge layout 0 0.1, Nudge layout 0 0.1 ] (fresh [ 0.5, 0.5 ])))
        , test "keys that arrive faster than the page is drawn add up" <|
            \_ ->
                Expect.equal [ 0.53, 0.47 ] (sizesOf (run [ Nudge two 0 0.01, Nudge two 0 0.01, Nudge two 0 0.01 ] (fresh [ 0.5, 0.5 ])))
        , test "home and end" <|
            \_ ->
                let
                    layout =
                        withRequests [ { request | minShare = 0.2, maxShare = 0.8 }, request ] two
                in
                Expect.equal ( [ 0.2, 0.8 ], [ 0.8, 0.2 ] )
                    ( sizesOf (run [ Edge layout 0 False ] (fresh [ 0.5, 0.5 ]))
                    , sizesOf (run [ Edge layout 0 True ] (fresh [ 0.5, 0.5 ]))
                    )
        , test "a separator that is not there does nothing" <|
            \_ ->
                Expect.equal [ 0.5, 0.5 ] (sizesOf (run [ Nudge two 4 0.1, Edge two -1 True ] (fresh [ 0.5, 0.5 ])))
        , test "the pixel limits are known after a separator was focused" <|
            \_ ->
                let
                    layout =
                        withRequests [ { request | minPixels = 400 }, request ] two

                    focused =
                        run [ Measured 0 layout (Ok (container 808 400)) ] (fresh [ 0.5, 0.5 ])
                in
                Expect.equal [ 0.5, 0.5 ] (sizesOf (run [ Nudge layout 0 -0.1 ] focused))
        ]



-- FOLDING


foldTests : Test
foldTests =
    let
        sidebar =
            two |> foldable [ True, False ] |> withRequests [ { request | minShare = 0.2 }, request ]
    in
    describe "folding"
        [ test "Enter folds a pane that can fold: its room goes to the other" <|
            \_ ->
                Expect.equal [ 0, 1 ] (sizesOf (run [ Toggle sidebar 0 ] (fresh [ 0.3, 0.7 ])))
        , test "and opens it again with what it had" <|
            \_ ->
                Expect.equal [ 0.3, 0.7 ] (sizesOf (run [ Toggle sidebar 0, Toggle sidebar 0 ] (fresh [ 0.3, 0.7 ])))
        , test "a pane that cannot fold is not folded" <|
            \_ ->
                Expect.equal [ 0.3, 0.7 ] (sizesOf (run [ Toggle two 0 ] (fresh [ 0.3, 0.7 ])))
        , test "the pane after the separator can fold too" <|
            \_ ->
                let
                    detail =
                        two |> foldable [ False, True ]
                in
                Expect.equal [ 1, 0 ] (sizesOf (run [ Toggle detail 0 ] (fresh [ 0.6, 0.4 ])))
        , test "a folded pane is exactly nothing, and a drag cannot open it" <|
            \_ ->
                let
                    folded =
                        run [ Toggle sidebar 0 ] (fresh [ 0.3, 0.7 ])

                    pressed =
                        run [ Press sidebar 0 Mouse (at 8 50 1) ] folded

                    after =
                        run [ Measured (serialOf pressed) sidebar (Ok (container 808 400)), PointerMoved (at 400 50 1) ] pressed
                in
                Expect.equal [ 0, 1 ] (sizesOf after)
        , test "a pane that can fold keeps a sliver when it is dragged, so that it is not dragged shut by accident" <|
            \_ ->
                let
                    plain =
                        two |> foldable [ True, False ]

                    pressed =
                        run [ Press plain 0 Mouse (at 240 50 1) ] (fresh [ 0.3, 0.7 ])

                    after =
                        run [ Measured (serialOf pressed) plain (Ok (container 808 400)), PointerMoved (at -9000 50 1) ] pressed
                in
                Expect.equal [ 0.02, 0.98 ] (sizesOf after)
        , test "a layout that comes back folded is folded, and opens to the smallest size" <|
            \_ ->
                Expect.equal [ 0.2, 0.8 ] (sizesOf (run [ Toggle sidebar 0 ] (fresh [ 0, 1 ])))
        , test "nothing to spare, nothing opens" <|
            \_ ->
                let
                    tight =
                        sidebar |> withRequests [ { request | minShare = 0.2 }, { request | minShare = 1 } ]
                in
                Expect.equal [ 0, 1 ] (sizesOf (run [ Toggle tight 0 ] (fresh [ 0, 1 ])))
        , test "the layout comes folded from the sizes the application sets" <|
            \_ ->
                Expect.equal ( True, False )
                    ( Machine.isFolded sidebar [ 0, 1 ] 0, Machine.isFolded sidebar [ 0.3, 0.7 ] 0 )
        , test "a pane that cannot fold is never folded, not even at nothing" <|
            \_ ->
                Expect.equal False (Machine.isFolded two [ 0, 1 ] 0)
        ]



-- ROBUSTNESS


robustnessTests : Test
robustnessTests =
    let
        pressed =
            run [ Press two 0 Mouse (at 400 50 1) ] (fresh [ 0.5, 0.5 ])
    in
    describe "robustness"
        [ test "a container with no room moves nothing, and gives no sizes that are not sizes" <|
            \_ ->
                let
                    after =
                        run [ Measured (serialOf pressed) two (Ok (container 0 0)), PointerMoved (at 900 50 1) ] pressed
                in
                Expect.equal [ 0.5, 0.5 ] (sizesOf after)
        , test "a container that is narrower than the separators has no room either" <|
            \_ ->
                let
                    after =
                        run [ Measured (serialOf pressed) two (Ok (container 3 3)), PointerMoved (at 900 50 1) ] pressed
                in
                Expect.equal ( [ 0.5, 0.5 ], Just 0 ) ( sizesOf after, after.room )
        , test "an answer to an older press tells the room but moves nothing" <|
            \_ ->
                let
                    second =
                        run [ Release, Press two 0 Mouse (at 400 50 1) ] pressed

                    after =
                        run [ Measured (serialOf pressed) two (Ok (container 808 400)) ] second
                in
                Expect.equal ( [ 0.5, 0.5 ], Just 800 ) ( sizesOf after, after.room )
        , test "a container that is not on the page ends the press" <|
            \_ ->
                dragging (run [ Measured (serialOf pressed) two (Err (Dom.NotFound "split")) ] pressed)
                    |> Expect.equal False
        , test "pointer messages with no press do nothing" <|
            \_ ->
                let
                    state =
                        fresh [ 0.5, 0.5 ]
                in
                Expect.equal state (run [ PointerMoved (at 1 1 1), Release, Cancel ] state)
        , test "sizes for a number of panes that is not the state's are made to fit" <|
            \_ ->
                Machine.effective three (fresh [ 0.5, 0.5 ])
                    |> List.length
                    |> Expect.equal 3
        , fuzz (Fuzz.list (Fuzz.floatRange -200 1200)) "wherever the pointer goes, the sizes are sizes inside 0 to 1 that add up to 1" <|
            \xs ->
                let
                    layout =
                        withRequests [ { request | minShare = 0.1 }, { request | minPixels = 100 }, { request | maxShare = 0.7 } ] three

                    pressed2 =
                        run [ Press layout 0 Mouse (at 400 50 1) ] (fresh [ 0.2, 0.3, 0.5 ])

                    after =
                        run (Measured (serialOf pressed2) layout (Ok (container 816 400)) :: List.map (\x -> PointerMoved (at x 50 1)) xs) pressed2

                    sizes =
                        Machine.effective layout after
                in
                Expect.all
                    [ \_ -> Expect.within (Expect.Absolute 1.0e-9) 1 (List.sum sizes)
                    , \_ -> Expect.equal True (List.all (\size -> size >= 0 && size <= 1) sizes)
                    , \_ -> Expect.equal True (List.all (\size -> not (isNaN size)) sizes)
                    , \_ -> Expect.atLeast 0.1 (List.head sizes |> Maybe.withDefault 0)
                    ]
                    ()
        ]
