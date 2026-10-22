module SortableSessionTest exposing (suite)

import Browser.Dom as Dom
import Expect
import Fuzz exposing (Fuzzer)
import Klar.Sortable.Machine as Machine exposing (Msg(..), Note(..))
import Klar.Sortable.Order as Order exposing (Rect)
import Klar.Sortable.Session as Session exposing (Device(..), Layout)
import Test exposing (Test, describe, fuzz, fuzz2, fuzz3, test)


suite : Test
suite =
    describe "Sortable: the drag session and the state machine"
        [ sessionTests
        , keyboardFlowTests
        , pointerFlowTests
        , robustnessTests
        ]



-- A LIST OF FIVE


keys : List String
keys =
    [ "a", "b", "c", "d", "e" ]


layout : String -> Layout
layout source =
    { source = source, order = keys, fixed = List.map (\_ -> False) keys, horizontal = False }


withFixed : List Bool -> String -> Layout
withFixed flags source =
    { source = source, order = keys, fixed = flags, horizontal = False }


{-| The five items stacked, ten pixels high each.
-}
rectOf : String -> Rect
rectOf key =
    let
        index =
            keys |> List.indexedMap Tuple.pair |> List.filter (\( _, k ) -> k == key) |> List.head |> Maybe.map Tuple.first |> Maybe.withDefault 0
    in
    { x = 0, y = toFloat index * 10, width = 100, height = 10 }


point : Float -> Float -> Session.Point
point x y =
    { x = x, y = y }


run : List Machine.Msg -> Machine.State -> Machine.State
run messages state =
    List.foldl (\msg current -> Tuple.first (Machine.update msg current)) state messages


fresh : Machine.State
fresh =
    Machine.init "list"


serialOf : Machine.State -> Int
serialOf state =
    state.serial


measuredAll : Int -> List Machine.Msg
measuredAll serial =
    List.map (\key -> Measured serial key (Ok (rectOf key))) keys


sample : Float -> Float -> Int -> Machine.Msg
sample x y buttons =
    PointerMoved { page = point x y, client = point x y, buttons = buttons }


toOf : Machine.State -> Maybe Int
toOf state =
    Maybe.map .to state.session


liftedOf : Machine.State -> Bool
liftedOf state =
    Maybe.map .lifted state.session |> Maybe.withDefault False



-- SESSION


sessionTests : Test
sessionTests =
    describe "Session"
        [ test "a keyboard session starts lifted, where the item is" <|
            \_ ->
                Session.keyboard 1 (layout "c")
                    |> Maybe.map (\s -> ( s.from, s.to, s.lifted ))
                    |> Expect.equal (Just ( 2, 2, True ))
        , test "a fixed item and an item that is not in the list cannot be held" <|
            \_ ->
                Expect.equal [ Nothing, Nothing ]
                    [ Session.keyboard 1 (withFixed [ False, True, False, False, False ] "b")
                    , Session.keyboard 1 (layout "zzz")
                    ]
        , test "stepping stops at the ends and at a fixed item" <|
            \_ ->
                let
                    targets flags source deltas =
                        Session.keyboard 1 (withFixed flags source)
                            |> Maybe.map (\s -> List.foldl Session.step s deltas |> .to)
                in
                Expect.equal
                    [ Just 0, Just 4, Just 1, Just 3 ]
                    [ targets [ False, False, False, False, False ] "c" [ -1, -1, -1, -1 ]
                    , targets [ False, False, False, False, False ] "c" [ 1, 1, 1, 1 ]
                    , targets [ False, False, True, False, False ] "a" [ 1, 1, 1 ]
                    , targets [ False, False, True, False, False ] "d" [ -1, -1 ]
                    ]
        , test "jumping goes to the ends of the part the item is in" <|
            \_ ->
                let
                    ends flags source =
                        Session.keyboard 1 (withFixed flags source)
                            |> Maybe.map (\s -> ( .to (Session.jump False s), .to (Session.jump True s) ))
                in
                Expect.equal
                    [ Just ( 0, 4 ), Just ( 0, 1 ), Just ( 3, 4 ) ]
                    [ ends [ False, False, False, False, False ] "c"
                    , ends [ False, False, True, False, False ] "b"
                    , ends [ False, False, True, False, False ] "e"
                    ]
        , fuzz3 (Fuzz.list Fuzz.bool) (Fuzz.intRange 0 7) (Fuzz.list (Fuzz.intRange -3 3)) "steps never leave the part of the list the item is in" <|
            \flags index deltas ->
                let
                    names =
                        List.indexedMap (\i _ -> String.fromInt i) flags

                    source =
                        String.fromInt index
                in
                case Session.keyboard 1 { source = source, order = names, fixed = flags, horizontal = False } of
                    Just session ->
                        let
                            ( low, high ) =
                                Order.bounds flags index

                            final =
                                List.foldl Session.step session deltas
                        in
                        Expect.all [ \_ -> Expect.atLeast low final.to, \_ -> Expect.atMost high final.to ] ()

                    Nothing ->
                        Expect.pass
        , test "letting go: dropped, kept, never lifted, or stale" <|
            \_ ->
                let
                    held =
                        Session.keyboard 1 (layout "b") |> Maybe.withDefault emptySession

                    moved =
                        Session.step 2 held
                in
                Expect.equal
                    [ Session.Dropped 3, Session.Kept, Session.Stale ]
                    [ Session.finish keys moved
                    , Session.finish keys held
                    , Session.finish [ "a", "b", "c" ] moved
                    ]
        , test "a press is not a drag until the pointer has moved far enough" <|
            \_ ->
                let
                    pressed =
                        Session.pointer 1 (layout "a") Mouse (point 10 5) (point 10 5) |> Maybe.withDefault emptySession

                    lifts x y =
                        .lifted (Session.moved (point x y) (point x y) pressed)
                in
                Expect.equal
                    [ False, False, True, True ]
                    [ lifts 10 5, lifts 12 7, lifts 10 9, lifts 100 100 ]
        , test "a click that never moved ends as a press" <|
            \_ ->
                Session.pointer 1 (layout "a") Mouse (point 1 1) (point 1 1)
                    |> Maybe.map (Session.finish keys)
                    |> Expect.equal (Just Session.Pressed)
        ]


emptySession : Session.Session
emptySession =
    { serial = 0, source = "", from = 0, to = 0, order = [], fixed = [], horizontal = False, lifted = False, input = Session.Keyboard }



-- THE KEYBOARD PATH THROUGH THE STATE


keyboardFlowTests : Test
keyboardFlowTests =
    describe "keyboard path"
        [ test "pick up, move twice, drop" <|
            \_ ->
                let
                    state =
                        run [ Lift (layout "b"), Step 1, Step 1 ] fresh
                in
                Expect.equal
                    ( Just 3, Just (MovedTo 4 5), True )
                    ( toOf state, state.note, liftedOf state )
        , test "dropping records the move once" <|
            \_ ->
                let
                    state =
                        run [ Lift (layout "b"), Step 1, Step 1, Drop keys ] fresh
                in
                Expect.equal
                    { drops = 1, last = Just { key = "b", to = 3, placed = [ "a", "c", "d", "b", "e" ] }, session = Nothing, note = Just (Dropped "b" 4 5) }
                    { drops = state.drops, last = state.last, session = state.session, note = state.note }
        , test "dropping where it was is not a move" <|
            \_ ->
                let
                    state =
                        run [ Lift (layout "b"), Step 1, Step -1, Drop keys ] fresh
                in
                Expect.equal ( 0, Nothing, Just (Dropped "b" 2 5) ) ( state.drops, state.last, state.note )
        , test "escape puts it back and says so" <|
            \_ ->
                let
                    state =
                        run [ Lift (layout "c"), Step 1, Cancel ] fresh
                in
                Expect.equal ( 0, Nothing, Just (Cancelled "c" 3 5) ) ( state.drops, state.session, state.note )
        , test "leaving the handle cancels, but only for the item that is held" <|
            \_ ->
                let
                    held =
                        run [ Lift (layout "c"), Step 1 ] fresh
                in
                Expect.equal
                    ( Just 3, Nothing )
                    ( toOf (run [ Blurred "a" ] held), toOf (run [ Blurred "c" ] held) )
        , test "at the end the item cannot move further, and it says so" <|
            \_ ->
                let
                    state =
                        run [ Lift (layout "d"), Step 1, Step 1 ] fresh
                in
                Expect.equal ( Just 4, Just (AtLimit 5 5) ) ( toOf state, state.note )
        , test "home and end" <|
            \_ ->
                Expect.equal
                    ( Just 0, Just 4 )
                    ( toOf (run [ Lift (layout "c"), Jump False ] fresh), toOf (run [ Lift (layout "c"), Jump True ] fresh) )
        , test "a fixed item cannot be picked up" <|
            \_ ->
                run [ Lift (withFixed [ True, False, False, False, False ] "a") ] fresh
                    |> .session
                    |> Expect.equal Nothing
        , test "a list that changed while the item was held cancels the drop" <|
            \_ ->
                let
                    state =
                        run [ Lift (layout "b"), Step 2, Drop [ "a", "b", "c", "d", "e", "f" ] ] fresh
                in
                Expect.equal ( 0, Nothing, Just (Cancelled "b" 2 5) ) ( state.drops, state.session, state.note )
        , test "keys while nothing is held do nothing" <|
            \_ ->
                Expect.equal fresh (run [ Step 1, Jump True, Cancel, Drop keys, Blurred "a" ] fresh)
        ]



-- THE POINTER PATH


pointerFlowTests : Test
pointerFlowTests =
    let
        pressed =
            run [ Press (layout "a") Mouse (point 50 5) (point 50 5) ] fresh

        ready =
            run (measuredAll (serialOf pressed)) pressed
    in
    describe "pointer path"
        [ test "a press starts a session that is not a drag yet" <|
            \_ -> Expect.equal ( False, Just 0 ) ( liftedOf pressed, toOf pressed )
        , test "a drag follows the pointer to the gap under it" <|
            \_ ->
                let
                    state =
                        run [ sample 50 20 1, sample 50 38 1 ] ready
                in
                Expect.equal ( True, Just 3 ) ( liftedOf state, toOf state )
        , test "the pointer can come back" <|
            \_ ->
                run [ sample 50 38 1, sample 50 12 1, sample 50 4 1 ] ready
                    |> toOf
                    |> Expect.equal (Just 0)
        , test "the boxes may arrive after the pointer has moved" <|
            \_ ->
                let
                    early =
                        run [ sample 50 38 1 ] pressed
                in
                Expect.equal
                    ( Just 0, Just 3 )
                    ( toOf early, toOf (run (measuredAll (serialOf early)) early) )
        , test "dropping puts the item in the gap" <|
            \_ ->
                let
                    state =
                        run [ sample 50 38 1, Drop keys ] ready
                in
                Expect.equal ( 1, Just { key = "a", to = 3, placed = [ "b", "c", "d", "a", "e" ] }, Nothing ) ( state.drops, state.last, state.session )
        , test "dropping below the last item puts it last" <|
            \_ ->
                run [ sample 50 400 1, Drop keys ] ready
                    |> .last
                    |> Expect.equal (Just { key = "a", to = 4, placed = [ "b", "c", "d", "e", "a" ] })
        , test "a plain click does nothing" <|
            \_ ->
                let
                    state =
                        run [ sample 51 6 1, Drop keys ] ready
                in
                Expect.equal ( 0, Nothing, Nothing ) ( state.drops, state.session, state.note )
        , test "the mouse let go where nobody saw it: the drag is cancelled" <|
            \_ ->
                let
                    state =
                        run [ sample 50 38 1, sample 50 38 0 ] ready
                in
                Expect.equal ( 0, Nothing, Just (Cancelled "a" 1 5) ) ( state.drops, state.session, state.note )
        , test "a finger has no buttons to check" <|
            \_ ->
                let
                    touching =
                        run [ Press (layout "a") Touch (point 50 5) (point 50 5) ] fresh

                    state =
                        run (measuredAll (serialOf touching) ++ [ sample 50 38 0 ]) touching
                in
                Expect.equal ( True, Just 3 ) ( liftedOf state, toOf state )
        , test "escape cancels a drag" <|
            \_ ->
                run [ sample 50 38 1, Cancel ] ready
                    |> Expect.all [ .session >> Expect.equal Nothing, .drops >> Expect.equal 0 ]
        , test "a drag is told in words: picked up, then moved" <|
            \_ ->
                Expect.equal
                    [ Just (PickedUp "a" 1 5), Just (MovedTo 4 5) ]
                    [ .note (run [ sample 50 20 1 ] pressed)
                    , .note (run [ sample 50 20 1, sample 50 38 1 ] ready)
                    ]
        , test "a fixed item stops the drag" <|
            \_ ->
                let
                    barrier =
                        withFixed [ False, False, True, False, False ] "a"

                    start =
                        run [ Press barrier Mouse (point 50 5) (point 50 5) ] fresh

                    state =
                        run (measuredAll (serialOf start) ++ [ sample 50 45 1, Drop keys ]) start
                in
                Expect.equal ( Just { key = "a", to = 1, placed = [ "b", "a", "c", "d", "e" ] }, 1 ) ( state.last, state.drops )
        ]



-- ROBUSTNESS


robustnessTests : Test
robustnessTests =
    describe "robustness"
        [ test "answers to an older press are ignored" <|
            \_ ->
                let
                    first =
                        run [ Press (layout "a") Mouse (point 1 1) (point 1 1) ] fresh

                    second =
                        run [ Press (layout "b") Mouse (point 1 1) (point 1 1) ] first
                in
                Expect.equal (toOf second) (toOf (run (measuredAll (serialOf first)) second))
        , test "an item that is not on the page ends the press" <|
            \_ ->
                run
                    [ Press (layout "a") Mouse (point 1 1) (point 1 1)
                    , Measured 1 "c" (Err (Dom.NotFound "list-item-c"))
                    ]
                    fresh
                    |> .session
                    |> Expect.equal Nothing
        , test "pointer messages with no press do nothing" <|
            \_ ->
                Expect.equal fresh (run [ sample 1 1 1, Drop keys, Measured 1 "a" (Ok (rectOf "a")) ] fresh)
        , test "keys do not move a pointer drag" <|
            \_ ->
                let
                    pressed =
                        run [ Press (layout "a") Mouse (point 1 1) (point 1 1) ] fresh

                    dragged =
                        run (measuredAll (serialOf pressed) ++ [ sample 50 25 1 ]) pressed
                in
                Expect.equal (toOf dragged) (toOf (run [ Step 1, Jump True ] dragged))
        , fuzz2 (Fuzz.list (Fuzz.floatRange -100 200)) (Fuzz.intRange 0 4) "wherever the pointer goes, the target is a place of the list" <|
            \ys sourceIndex ->
                let
                    source =
                        keys |> List.drop sourceIndex |> List.head |> Maybe.withDefault "a"

                    start =
                        run [ Press (layout source) Mouse (point 0 0) (point 0 0) ] fresh

                    state =
                        run (measuredAll (serialOf start) ++ List.map (\y -> sample 20 y 1) ys) start
                in
                case toOf state of
                    Just target ->
                        Expect.all [ \_ -> Expect.atLeast 0 target, \_ -> Expect.atMost 4 target ] ()

                    Nothing ->
                        Expect.pass
        , fuzz (Fuzz.list (Fuzz.intRange -2 2)) "a keyboard drag never ends outside the list, and the moves always add up" <|
            \deltas ->
                let
                    state =
                        run (Lift (layout "c") :: List.map Step deltas ++ [ Drop keys ]) fresh
                in
                case state.last of
                    Just landing ->
                        Expect.all [ \_ -> Expect.atLeast 0 landing.to, \_ -> Expect.atMost 4 landing.to ] ()

                    Nothing ->
                        Expect.equal 0 state.drops
        ]
