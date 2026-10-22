module HistoryTest exposing (suite)

{-| Klar.History: the data structure (record, undo, redo, the limit, bursts, the saved
point) with property tests over long random sequences, and the controls (names,
disabled state, the announcement).
-}

import Expect exposing (Expectation)
import Fuzz exposing (Fuzzer)
import Html exposing (Html)
import Html.Attributes as Attr
import Klar.History as History exposing (History)
import Klar.Locale as Locale
import Klar.Shortcut as Shortcut
import Support.FlowHtml as H
import Test exposing (Test, describe, fuzz, fuzz2, test)
import Test.Html.Event as Event
import Test.Html.Query as Query
import Test.Html.Selector as Selector exposing (Selector)


type Msg
    = Undo
    | Redo


{-| The value is an `Int`, the key of a burst a field number.
-}
type alias H =
    History Int Int


suite : Test
suite =
    describe "Klar.History"
        [ basicTests
        , labelTests
        , limitTests
        , burstTests
        , savedPointTests
        , propertyTests
        , sequenceTests
        , controlsTests
        , shortcutTests
        ]


fresh : H
fresh =
    History.init 0


{-| Record these values one after the other, each as a step of its own.
-}
recordAll : List Int -> H -> H
recordAll values history =
    List.foldl (\value h -> History.record [] value h) history values


{-| Everything one can see of a history without moving through it.
-}
type alias Seen =
    { present : Int
    , canUndo : Bool
    , canRedo : Bool
    , undoLabel : Maybe String
    , redoLabel : Maybe String
    , atSaved : Bool
    }


seen : H -> Seen
seen h =
    { present = History.present h
    , canUndo = History.canUndo h
    , canRedo = History.canRedo h
    , undoLabel = History.undoLabel h
    , redoLabel = History.redoLabel h
    , atSaved = History.isAtSavedPoint h
    }


{-| How many steps back one can go.
-}
undoDepth : H -> Int
undoDepth h =
    if History.canUndo h then
        1 + undoDepth (History.undo h)

    else
        0


redoDepth : H -> Int
redoDepth h =
    if History.canRedo h then
        1 + redoDepth (History.redo h)

    else
        0


{-| The values on the way back to the start, nearest first.
-}
walkBack : H -> List Int
walkBack h =
    if History.canUndo h then
        History.present h :: walkBack (History.undo h)

    else
        [ History.present h ]


smallValue : Fuzzer Int
smallValue =
    Fuzz.intRange 0 6



-- BASICS


basicTests : Test
basicTests =
    describe "the basics"
        [ test "a new history is at its value, with nothing to undo or redo" <|
            \_ ->
                History.init 5
                    |> Expect.all
                        [ \h -> Expect.equal 5 (History.present h)
                        , \h -> Expect.equal False (History.canUndo h)
                        , \h -> Expect.equal False (History.canRedo h)
                        , \h -> Expect.equal Nothing (History.undoLabel h)
                        , \h -> Expect.equal Nothing (History.redoLabel h)
                        , \h -> Expect.equal True (History.isAtSavedPoint h)
                        ]
        , test "record makes a new present value that can be undone" <|
            \_ ->
                fresh
                    |> History.record [] 1
                    |> Expect.all
                        [ \h -> Expect.equal 1 (History.present h)
                        , \h -> Expect.equal True (History.canUndo h)
                        , \h -> Expect.equal False (History.canRedo h)
                        ]
        , test "undo goes back and redo comes forward again" <|
            \_ ->
                let
                    h =
                        recordAll [ 1, 2, 3 ] fresh
                in
                Expect.all
                    [ \_ -> Expect.equal 2 (History.present (History.undo h))
                    , \_ -> Expect.equal 0 (History.present (History.undo (History.undo (History.undo h))))
                    , \_ -> Expect.equal 3 (History.present (History.redo (History.undo h)))
                    , \_ -> Expect.equal True (History.canRedo (History.undo h))
                    ]
                    ()
        , test "undo and redo with nothing to do change nothing" <|
            \_ ->
                Expect.all
                    [ \_ -> Expect.equal fresh (History.undo fresh)
                    , \_ -> Expect.equal fresh (History.redo fresh)
                    , \_ -> Expect.equal (recordAll [ 1 ] fresh) (History.redo (recordAll [ 1 ] fresh))
                    ]
                    ()
        , test "recording the present value changes nothing at all" <|
            \_ ->
                let
                    h =
                        recordAll [ 1, 2 ] fresh |> History.undo
                in
                Expect.equal h (History.record [ History.label "x" ] (History.present h) h)
        , test "recording something new forgets what could have been redone" <|
            \_ ->
                recordAll [ 1, 2, 3 ] fresh
                    |> History.undo
                    |> History.undo
                    |> History.record [] 9
                    |> Expect.all
                        [ \h -> Expect.equal False (History.canRedo h)
                        , \h -> Expect.equal [ 9, 1, 0 ] (walkBack h)
                        ]
        , test "the value can be any type without functions" <|
            \_ ->
                let
                    h : History () { quantity : String, note : String }
                    h =
                        History.init { quantity = "1", note = "" }
                            |> History.record [] { quantity = "2", note = "" }
                            |> History.record [] { quantity = "2", note = "fragile" }
                in
                Expect.equal [ { quantity = "2", note = "fragile" }, { quantity = "2", note = "" }, { quantity = "1", note = "" } ] (walkBack_ h)
        ]


walkBack_ : History () a -> List a
walkBack_ h =
    if History.canUndo h then
        History.present h :: walkBack_ (History.undo h)

    else
        [ History.present h ]



-- LABELS


labelTests : Test
labelTests =
    describe "labels"
        [ test "undoLabel is the label of the edit undo would take back" <|
            \_ ->
                fresh
                    |> History.record [ History.label "Changed quantity" ] 1
                    |> History.record [ History.label "Changed note" ] 2
                    |> Expect.all
                        [ \h -> Expect.equal (Just "Changed note") (History.undoLabel h)
                        , \h -> Expect.equal (Just "Changed quantity") (History.undoLabel (History.undo h))
                        , \h -> Expect.equal Nothing (History.undoLabel (History.undo (History.undo h)))
                        ]
        , test "redoLabel is the label of the edit redo would bring back" <|
            \_ ->
                fresh
                    |> History.record [ History.label "Changed quantity" ] 1
                    |> History.record [ History.label "Changed note" ] 2
                    |> History.undo
                    |> Expect.all
                        [ \h -> Expect.equal (Just "Changed note") (History.redoLabel h)
                        , \h -> Expect.equal (Just "Changed quantity") (History.undoLabel h)
                        , \h -> Expect.equal Nothing (History.redoLabel (History.redo h))
                        ]
        , test "an edit without a label has none" <|
            \_ -> Expect.equal Nothing (History.undoLabel (History.record [] 1 fresh))
        , test "there is no label with nothing to undo" <|
            \_ -> Expect.equal Nothing (History.undoLabel fresh)
        , test "labels travel with their step through undo and redo" <|
            \_ ->
                let
                    h =
                        fresh
                            |> History.record [ History.label "A" ] 1
                            |> History.record [ History.label "B" ] 2
                in
                Expect.equal (seen h) (seen (History.redo (History.undo h)))
        ]



-- THE LIMIT


limitTests : Test
limitTests =
    describe "the limit"
        [ test "the default keeps 100 steps" <|
            \_ -> Expect.equal 100 (undoDepth (recordAll (List.range 1 150) fresh))
        , test "withLimit keeps that many" <|
            \_ ->
                let
                    h =
                        History.withLimit 3 fresh |> recordAll (List.range 1 10)
                in
                Expect.all
                    [ \_ -> Expect.equal 3 (undoDepth h)
                    , \_ -> Expect.equal [ 10, 9, 8, 7 ] (walkBack h)
                    ]
                    ()
        , test "the same number can be redone" <|
            \_ ->
                let
                    h =
                        History.withLimit 3 fresh |> recordAll (List.range 1 10)

                    allBack =
                        h |> History.undo |> History.undo |> History.undo
                in
                Expect.all
                    [ \_ -> Expect.equal 7 (History.present allBack)
                    , \_ -> Expect.equal 3 (redoDepth allBack)
                    , \_ -> Expect.equal 10 (History.present (History.redo (History.redo (History.redo allBack))))
                    ]
                    ()
        , test "a limit below 1 counts as 1" <|
            \_ ->
                Expect.all
                    [ \_ -> Expect.equal 1 (undoDepth (History.withLimit 0 fresh |> recordAll [ 1, 2, 3 ]))
                    , \_ -> Expect.equal 1 (undoDepth (History.withLimit -9 fresh |> recordAll [ 1, 2, 3 ]))
                    ]
                    ()
        , test "a smaller limit drops the oldest steps at once" <|
            \_ ->
                let
                    h =
                        recordAll (List.range 1 10) fresh |> History.withLimit 2
                in
                Expect.equal [ 10, 9, 8 ] (walkBack h)
        , test "a larger limit does not bring dropped steps back" <|
            \_ ->
                let
                    h =
                        History.withLimit 2 fresh |> recordAll (List.range 1 5) |> History.withLimit 50
                in
                Expect.equal 2 (undoDepth h)
        , test "the limit survives reset and clear" <|
            \_ ->
                let
                    h =
                        History.withLimit 2 fresh |> History.reset 0 |> History.clear |> recordAll (List.range 1 9)
                in
                Expect.equal 2 (undoDepth h)
        , fuzz2 (Fuzz.intRange 1 12) (Fuzz.list smallValue) "no sequence of edits leaves more than the limit to undo or redo" <|
            \limit values ->
                let
                    h =
                        History.withLimit limit fresh |> recordAll values
                in
                Expect.all
                    [ \_ -> Expect.atMost limit (undoDepth h)
                    , \_ -> Expect.atMost limit (redoDepth (iterate (undoDepth h) History.undo h))
                    , \_ -> Expect.atMost limit (undoDepth h + redoDepth h)
                    ]
                    ()
        ]


iterate : Int -> (a -> a) -> a -> a
iterate n f x =
    if n <= 0 then
        x

    else
        iterate (n - 1) f (f x)



-- BURSTS


burstTests : Test
burstTests =
    let
        typing field value =
            History.record [ History.coalesce field, History.label ("Changed " ++ String.fromInt field) ] value
    in
    describe "bursts"
        [ test "edits with the same key become one step" <|
            \_ ->
                fresh
                    |> typing 1 1
                    |> typing 1 2
                    |> typing 1 3
                    |> Expect.all
                        [ \h -> Expect.equal 1 (undoDepth h)
                        , \h -> Expect.equal 3 (History.present h)
                        , \h -> Expect.equal 0 (History.present (History.undo h))
                        ]
        , test "edits with another key start another step" <|
            \_ ->
                fresh
                    |> typing 1 1
                    |> typing 1 2
                    |> typing 2 3
                    |> typing 2 4
                    |> Expect.all
                        [ \h -> Expect.equal [ 4, 2, 0 ] (walkBack h)
                        ]
        , test "an edit without a key ends the burst" <|
            \_ ->
                fresh
                    |> typing 1 1
                    |> History.record [] 2
                    |> typing 1 3
                    |> (\h -> Expect.equal [ 3, 2, 1, 0 ] (walkBack h))
        , test "an edit without a key does not join an earlier one" <|
            \_ ->
                fresh
                    |> History.record [] 1
                    |> History.record [] 2
                    |> (\h -> Expect.equal 2 (undoDepth h))
        , test "endBurst makes the next edit a step of its own" <|
            \_ ->
                fresh
                    |> typing 1 1
                    |> typing 1 2
                    |> History.endBurst
                    |> typing 1 3
                    |> (\h -> Expect.equal [ 3, 2, 0 ] (walkBack h))
        , test "undo ends the burst: typing again after an undo is a step of its own" <|
            \_ ->
                fresh
                    |> typing 1 1
                    |> typing 2 5
                    |> History.undo
                    |> typing 1 7
                    |> (\h -> Expect.equal [ 7, 1, 0 ] (walkBack h))
        , test "redo ends the burst too" <|
            \_ ->
                fresh
                    |> typing 1 1
                    |> typing 2 5
                    |> History.undo
                    |> History.redo
                    |> typing 2 6
                    |> (\h -> Expect.equal [ 6, 5, 1, 0 ] (walkBack h))
        , test "a burst that comes back to where it began leaves no step" <|
            \_ ->
                fresh
                    |> typing 1 1
                    |> typing 1 2
                    |> typing 1 0
                    |> Expect.all
                        [ \h -> Expect.equal False (History.canUndo h)
                        , \h -> Expect.equal 0 (History.present h)
                        ]
        , test "and the next edit with that key starts a new burst" <|
            \_ ->
                fresh
                    |> typing 1 1
                    |> typing 1 0
                    |> typing 1 4
                    |> typing 1 5
                    |> (\h -> Expect.equal [ 5, 0 ] (walkBack h))
        , test "the step keeps the label of the first edit, or the latest that has one" <|
            \_ ->
                fresh
                    |> History.record [ History.coalesce 1, History.label "First" ] 1
                    |> History.record [ History.coalesce 1 ] 2
                    |> Expect.all
                        [ \h -> Expect.equal (Just "First") (History.undoLabel h)
                        , \h ->
                            Expect.equal (Just "Latest")
                                (History.undoLabel (History.record [ History.coalesce 1, History.label "Latest" ] 3 h))
                        ]
        , test "a burst joins only when nothing was recorded in between" <|
            \_ ->
                fresh
                    |> typing 1 1
                    |> typing 2 2
                    |> typing 1 3
                    |> (\h -> Expect.equal [ 3, 2, 1, 0 ] (walkBack h))
        , test "reset and clear end the burst" <|
            \_ ->
                Expect.all
                    [ \_ -> fresh |> typing 1 1 |> History.clear |> typing 1 2 |> (\h -> Expect.equal [ 2, 1 ] (walkBack h))
                    , \_ -> fresh |> typing 1 1 |> History.reset 7 |> typing 1 8 |> (\h -> Expect.equal [ 8, 7 ] (walkBack h))
                    ]
                    ()
        , test "the keys can be a custom type" <|
            \_ ->
                let
                    h : History Field Int
                    h =
                        History.init 0
                            |> History.record [ History.coalesce Quantity ] 1
                            |> History.record [ History.coalesce Quantity ] 2
                            |> History.record [ History.coalesce Price ] 3
                in
                Expect.equal 2 (undoDepth_ h)
        ]


type Field
    = Quantity
    | Price


undoDepth_ : History Field Int -> Int
undoDepth_ h =
    if History.canUndo h then
        1 + undoDepth_ (History.undo h)

    else
        0



-- THE SAVED POINT


savedPointTests : Test
savedPointTests =
    describe "the saved point"
        [ test "the first value is the saved one" <|
            \_ -> Expect.equal True (History.isAtSavedPoint fresh)
        , test "an edit leaves the saved point" <|
            \_ -> Expect.equal False (History.isAtSavedPoint (History.record [] 1 fresh))
        , test "undo comes back to it" <|
            \_ -> Expect.equal True (History.isAtSavedPoint (History.undo (History.record [] 1 fresh)))
        , test "so does redo, past it" <|
            \_ ->
                let
                    h =
                        recordAll [ 1, 2 ] fresh |> History.markSaved |> History.undo
                in
                Expect.all
                    [ \x -> Expect.equal False (History.isAtSavedPoint x)
                    , \x -> Expect.equal True (History.isAtSavedPoint (History.redo x))
                    ]
                    h
        , test "an edit that undoes another is back at the saved value" <|
            \_ -> Expect.equal True (History.isAtSavedPoint (fresh |> History.record [] 1 |> History.record [] 0))
        , test "markSaved says that the present value is the saved one and keeps the steps" <|
            \_ ->
                recordAll [ 1, 2 ] fresh
                    |> History.markSaved
                    |> Expect.all
                        [ \h -> Expect.equal True (History.isAtSavedPoint h)
                        , \h -> Expect.equal 2 (History.saved h)
                        , \h -> Expect.equal 2 (undoDepth h)
                        ]
        , test "saved is the value that counts as saved" <|
            \_ -> Expect.equal 0 (History.saved (recordAll [ 1, 2, 3 ] fresh))
        , test "reset starts over from a value, which is also the saved one" <|
            \_ ->
                recordAll [ 1, 2 ] fresh
                    |> History.reset 8
                    |> Expect.all
                        [ \h -> Expect.equal 8 (History.present h)
                        , \h -> Expect.equal True (History.isAtSavedPoint h)
                        , \h -> Expect.equal False (History.canUndo h)
                        , \h -> Expect.equal False (History.canRedo h)
                        ]
        , test "clear forgets the steps and keeps the value and the saved point" <|
            \_ ->
                recordAll [ 1, 2 ] fresh
                    |> History.undo
                    |> History.clear
                    |> Expect.all
                        [ \h -> Expect.equal 1 (History.present h)
                        , \h -> Expect.equal False (History.canUndo h)
                        , \h -> Expect.equal False (History.canRedo h)
                        , \h -> Expect.equal 0 (History.saved h)
                        , \h -> Expect.equal False (History.isAtSavedPoint h)
                        ]
        , fuzz2 smallValue (Fuzz.list smallValue) "isAtSavedPoint is whether the present value equals the saved one" <|
            \start values ->
                let
                    h =
                        History.init start |> recordAll values
                in
                Expect.equal (History.present h == start) (History.isAtSavedPoint h)
        ]



-- PROPERTIES


propertyTests : Test
propertyTests =
    describe "properties"
        [ fuzz (Fuzz.list smallValue) "undo then redo changes nothing one can see" <|
            \values ->
                let
                    h =
                        recordAll values fresh
                in
                if History.canUndo h then
                    Expect.equal (seen h) (seen (History.redo (History.undo h)))

                else
                    Expect.equal (seen h) (seen (History.undo h))
        , fuzz (Fuzz.list smallValue) "redo then undo changes nothing either, after an undo" <|
            \values ->
                let
                    h =
                        recordAll values fresh |> History.undo
                in
                if History.canRedo h then
                    Expect.equal (seen h) (seen (History.undo (History.redo h)))

                else
                    Expect.equal (seen h) (seen (History.redo h))
        , fuzz (Fuzz.list smallValue) "undoing everything gets back to the start and redoing everything to the end" <|
            \values ->
                let
                    h =
                        History.withLimit 1000 fresh |> recordAll values

                    start =
                        iterate 2000 History.undo h

                    end =
                        iterate 2000 History.redo start
                in
                Expect.all
                    [ \_ -> Expect.equal 0 (History.present start)
                    , \_ -> Expect.equal False (History.canUndo start)
                    , \_ -> Expect.equal (History.present h) (History.present end)
                    , \_ -> Expect.equal (seen h) (seen end)
                    ]
                    ()
        , fuzz (Fuzz.list smallValue) "every undo changes the value: a step is never a no-op" <|
            \values ->
                let
                    walked =
                        walkBack (recordAll values fresh)
                in
                Expect.equal True (List.map2 (/=) walked (List.drop 1 walked) |> List.all identity)
        , fuzz (Fuzz.list smallValue) "recording the present value again changes nothing" <|
            \values ->
                let
                    h =
                        recordAll values fresh
                in
                Expect.equal h (History.record [] (History.present h) h)
        , fuzz (Fuzz.list smallValue) "undo and redo on a history nobody edited never fail" <|
            \values ->
                let
                    h =
                        History.init (List.sum values)
                in
                Expect.equal h (iterate (List.length values) History.redo (iterate (List.length values) History.undo h))
        , fuzz2 (Fuzz.list smallValue) (Fuzz.intRange 1 7) "a burst is the same as its last edit (the coalescing law)" <|
            \values key ->
                case List.reverse values of
                    [] ->
                        Expect.pass

                    last :: _ ->
                        let
                            asBurst =
                                List.foldl (\value h -> History.record [ History.coalesce key ] value h) fresh values

                            asOne =
                                History.record [ History.coalesce key ] last fresh
                        in
                        Expect.all
                            [ \_ -> Expect.equal (seen asOne) (seen asBurst)
                            , \_ -> Expect.equal (undoDepth asOne) (undoDepth asBurst)
                            , \_ -> Expect.equal (walkBack asOne) (walkBack asBurst)
                            ]
                            ()
        , fuzz2 (Fuzz.list smallValue) (Fuzz.list smallValue) "a burst starts from wherever the history was" <|
            \before values ->
                case List.reverse values of
                    [] ->
                        Expect.pass

                    last :: _ ->
                        let
                            start =
                                recordAll before fresh |> History.endBurst

                            asBurst =
                                List.foldl (\value h -> History.record [ History.coalesce 1 ] value h) start values

                            asOne =
                                History.record [ History.coalesce 1 ] last start
                        in
                        Expect.equal (walkBack asOne) (walkBack asBurst)
        ]



-- LONG RANDOM SEQUENCES


type Op
    = Record Int (Maybe Int) (Maybe String)
    | Undo_
    | Redo_
    | EndBurst
    | MarkSaved
    | Clear
    | Reset Int
    | WithLimit Int


opFuzzer : Fuzzer Op
opFuzzer =
    Fuzz.frequency
        [ ( 8, Fuzz.map3 Record smallValue (Fuzz.maybe (Fuzz.intRange 1 3)) (Fuzz.maybe (Fuzz.constant "edit")) )
        , ( 4, Fuzz.constant Undo_ )
        , ( 3, Fuzz.constant Redo_ )
        , ( 1, Fuzz.constant EndBurst )
        , ( 1, Fuzz.constant MarkSaved )
        , ( 1, Fuzz.constant Clear )
        , ( 1, Fuzz.map Reset smallValue )
        , ( 1, Fuzz.map WithLimit (Fuzz.intRange -1 6) )
        ]


apply : Op -> H -> H
apply op h =
    case op of
        Record value key text ->
            History.record
                (List.filterMap identity [ Maybe.map History.coalesce key, Maybe.map History.label text ])
                value
                h

        Undo_ ->
            History.undo h

        Redo_ ->
            History.redo h

        EndBurst ->
            History.endBurst h

        MarkSaved ->
            History.markSaved h

        Clear ->
            History.clear h

        Reset value ->
            History.reset value h

        WithLimit n ->
            History.withLimit n h


sequenceTests : Test
sequenceTests =
    describe "long random sequences"
        [ fuzz (Fuzz.list opFuzzer) "no step is a no-op, the limit holds, and the history can be walked both ways" <|
            \ops ->
                let
                    limitOf =
                        List.foldl
                            (\op limit ->
                                case op of
                                    WithLimit n ->
                                        max 1 n

                                    _ ->
                                        limit
                            )
                            100
                            ops

                    h =
                        List.foldl apply fresh ops

                    walked =
                        walkBack h

                    back =
                        undoDepth h

                    atStart =
                        iterate back History.undo h
                in
                Expect.all
                    [ \_ -> Expect.equal True (List.map2 (/=) walked (List.drop 1 walked) |> List.all identity)
                    , \_ -> Expect.atMost limitOf back
                    , \_ -> Expect.atMost limitOf (redoDepth h)
                    , \_ -> Expect.atMost limitOf (redoDepth atStart)
                    , \_ -> Expect.equal (History.present (iterate (redoDepth h) History.redo h)) (History.present (iterate (redoDepth atStart) History.redo atStart))
                    , \_ -> Expect.atMost limitOf (back + redoDepth h)
                    , \_ -> Expect.equal (History.present h == History.saved h) (History.isAtSavedPoint h)
                    ]
                    ()
        , fuzz (Fuzz.list opFuzzer) "undo then redo is the identity after any sequence" <|
            \ops ->
                let
                    h =
                        List.foldl apply fresh ops
                in
                if History.canUndo h then
                    Expect.equal (seen h) (seen (History.redo (History.undo h)))

                else
                    Expect.pass
        ]



-- THE CONTROLS


controlsTests : Test
controlsTests =
    let
        controls attributes h =
            History.controls attributes { onUndo = Undo, onRedo = Redo } h

        undoButton =
            [ Selector.tag "button", Selector.containing [ Selector.class "klar-icon--undo" ] ]

        redoButton =
            [ Selector.tag "button", Selector.containing [ Selector.class "klar-icon--redo" ] ]

        live =
            [ Selector.class "klar-history__live" ]

        labelled =
            fresh
                |> History.record [ History.label "Changed quantity" ] 1
                |> History.record [ History.label "Changed note" ] 2
    in
    describe "the controls"
        [ test "two icon buttons with names, in a named group" <|
            \_ ->
                controls [] fresh
                    |> Expect.all
                        [ H.has [ H.attr "role" "group", H.attr "aria-label" "Undo and redo" ]
                        , H.inside undoButton [ H.attr "aria-label" "Undo" ]
                        , H.inside redoButton [ H.attr "aria-label" "Redo" ]
                        ]
        , test "the buttons are named after the step they would take" <|
            \_ ->
                controls [] (History.undo labelled)
                    |> Expect.all
                        [ H.inside undoButton [ H.attr "aria-label" "Undo: Changed quantity" ]
                        , H.inside redoButton [ H.attr "aria-label" "Redo: Changed note" ]
                        ]
        , test "a step without a label is just 'Undo'" <|
            \_ -> controls [] (History.record [] 1 fresh) |> H.inside undoButton [ H.attr "aria-label" "Undo" ]
        , test "with nothing to do a button stays in the tab order and says it is disabled" <|
            \_ ->
                controls [] fresh
                    |> Expect.all
                        [ H.inside undoButton [ H.attr "aria-disabled" "true" ]
                        , H.inside redoButton [ H.attr "aria-disabled" "true" ]
                        , H.none [ Selector.attribute (Attr.disabled True) ]
                        ]
        , test "with something to do it is not disabled" <|
            \_ ->
                controls [] (History.undo labelled)
                    |> Expect.all
                        [ H.inside undoButton [ Selector.attribute (Attr.type_ "button") ]
                        , H.none [ H.attr "aria-disabled" "true" ]
                        ]
        , test "a button that has something to do sends its message" <|
            \_ ->
                Expect.all
                    [ \_ -> controls [] labelled |> H.sends undoButton Event.click |> Expect.equal (Ok Undo)
                    , \_ -> controls [] (History.undo labelled) |> H.sends redoButton Event.click |> Expect.equal (Ok Redo)
                    ]
                    ()
        , test "a button with nothing to do sends nothing" <|
            \_ ->
                Expect.all
                    [ \_ -> controls [] fresh |> H.sends undoButton Event.click |> Result.toMaybe |> Expect.equal Nothing
                    , \_ -> controls [] labelled |> H.sends redoButton Event.click |> Result.toMaybe |> Expect.equal Nothing
                    ]
                    ()
        , describe "the announcement"
            [ test "a polite live region that is there from the start, and empty" <|
                \_ ->
                    controls [] labelled
                        |> Expect.all
                            [ H.inside live [ H.attr "role" "status", H.attr "aria-live" "polite", H.attr "aria-atomic" "true", Selector.class "klar-sr-only" ]
                            , H.none [ Selector.class "klar-history__live", Selector.containing [ Selector.text "Undid" ] ]
                            ]
            , test "after an undo it says what was undone" <|
                \_ -> controls [] (History.undo labelled) |> H.inside live [ Selector.text "Undid: Changed note" ]
            , test "after a redo it says what was redone" <|
                \_ -> controls [] (labelled |> History.undo |> History.undo |> History.redo) |> H.inside live [ Selector.text "Redid: Changed quantity" ]
            , test "an unlabeled step is called the last change" <|
                \_ ->
                    controls [] (History.record [] 1 fresh |> History.undo)
                        |> H.inside live [ Selector.text "Undid the last change" ]
            , test "and an unlabeled redo the change" <|
                \_ ->
                    controls [] (History.record [] 1 fresh |> History.undo |> History.redo)
                        |> H.inside live [ Selector.text "Redid the change" ]
            , test "a new edit takes the announcement away" <|
                \_ ->
                    controls [] (History.undo labelled |> History.record [] 9)
                        |> H.none [ Selector.class "klar-history__live", Selector.containing [ Selector.text "Undid" ] ]
            , test "an undo that did nothing announces nothing" <|
                \_ ->
                    controls [] (History.undo fresh)
                        |> H.none [ Selector.class "klar-history__live", Selector.containing [ Selector.text "Undid" ] ]
            , test "in Norwegian" <|
                \_ ->
                    controls [ History.locale Locale.nb ] (History.undo labelled)
                        |> Expect.all
                            [ H.inside live [ Selector.text "Angret: Changed note" ]
                            , H.inside undoButton [ H.attr "aria-label" "Angre: Changed quantity" ]
                            , H.inside redoButton [ H.attr "aria-label" "Gjør om: Changed note" ]
                            , H.has [ H.attr "role" "group", H.attr "aria-label" "Angre og gjør om" ]
                            ]
            , test "in Norwegian, with no labels" <|
                \_ ->
                    controls [ History.locale Locale.nb ] (History.record [] 1 fresh |> History.undo)
                        |> H.inside live [ Selector.text "Angret siste endring" ]
            , test "the announcement is a keyed child, so that the same text twice is heard twice" <|
                \_ ->
                    let
                        two =
                            fresh |> History.record [ History.label "Edit" ] 1 |> History.record [ History.label "Edit" ] 2

                        text h =
                            controls [] h |> Query.fromHtml |> Query.find live |> Query.has [ Selector.text "Undid: Edit" ]
                    in
                    Expect.all
                        [ \_ -> text (History.undo two)
                        , \_ -> text (History.undo (History.undo two))
                        ]
                        ()
            ]
        , describe "shortcut hints"
            [ test "none unless asked for: a hint for a key that does nothing would be a lie" <|
                \_ ->
                    controls [] labelled
                        |> Expect.all
                            [ H.none [ Selector.attribute (Attr.attribute "aria-keyshortcuts" "Control+Z") ]
                            , H.inside undoButton [ Selector.attribute (Attr.title "Undo: Changed note") ]
                            ]
            , test "showShortcuts adds them to the tooltips and to aria-keyshortcuts" <|
                \_ ->
                    controls [ History.showShortcuts ] (History.undo labelled)
                        |> Expect.all
                            [ H.inside undoButton [ Selector.attribute (Attr.title "Undo: Changed quantity (Ctrl+Z)"), H.attr "aria-keyshortcuts" "Control+Z" ]
                            , H.inside redoButton [ Selector.attribute (Attr.title "Redo: Changed note (Ctrl+Shift+Z)"), H.attr "aria-keyshortcuts" "Control+Shift+Z" ]
                            ]
            ]
        ]



-- THE SHORTCUTS


shortcutTests : Test
shortcutTests =
    let
        made =
            History.shortcuts Locale.en { onUndo = Undo, onRedo = Redo }
    in
    describe "shortcuts"
        [ test "two shortcuts: Ctrl Z and Ctrl Shift Z" <|
            \_ ->
                Expect.equal
                    [ [ [ "Ctrl", "Z" ] ], [ [ "Ctrl", "Shift", "Z" ] ] ]
                    (List.map (Shortcut.keycaps << Shortcut.keysOf) made)
        , test "with names for the shortcut sheet, in a group" <|
            \_ ->
                Expect.all
                    [ \_ -> Expect.equal [ "Undo", "Redo" ] (List.map Shortcut.labelOf made)
                    , \_ -> Expect.equal [ "Edit", "Edit" ] (List.map Shortcut.groupOf made)
                    ]
                    ()
        , test "in Norwegian" <|
            \_ ->
                let
                    norwegian =
                        History.shortcuts Locale.nb { onUndo = Undo, onRedo = Redo }
                in
                Expect.all
                    [ \_ -> Expect.equal [ "Angre", "Gjør om" ] (List.map Shortcut.labelOf norwegian)
                    , \_ -> Expect.equal [ "Redigering", "Redigering" ] (List.map Shortcut.groupOf norwegian)
                    ]
                    ()
        , test "they do not fire in text fields unless the application marks them" <|
            \_ -> Expect.equal [ False, False ] (List.map Shortcut.firesInInputs made)
        , test "the keys are the ones the controls show" <|
            \_ ->
                -- the same keys the hint in the controls names
                Expect.equal (Shortcut.keycaps (Shortcut.mod (Shortcut.char 'z'))) (Shortcut.keycaps (Shortcut.keysOf (List.head made |> Maybe.withDefault (Shortcut.shortcut Shortcut.escape "" "" Undo))))
        ]
