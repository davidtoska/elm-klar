module DiffBoundsTest exposing (suite)

{-| The limits of the diff: the work has a bound whatever the texts are, a huge block
of lines is cut and says so, keys can never collide, a letter is never cut from its
accent, and the viewer has one name for its content.
-}

import Array
import Expect
import Fuzz exposing (Fuzzer)
import Html exposing (Html)
import Html.Attributes as Attr
import Json.Encode as Encode
import Klar.Compare as Compare
import Klar.Diff as Diff
import Klar.Diff.Inline as Inline exposing (Segment(..))
import Klar.Diff.Keys as Keys
import Klar.Diff.Myers as Myers
import Klar.Format as Format
import Klar.Ids as Ids
import Klar.Locale as Locale
import Set
import Test exposing (Test, describe, fuzz, fuzz2, fuzz3, test)
import Test.Html.Event as Event
import Test.Html.Query as Query
import Test.Html.Selector as Selector exposing (Selector)


suite : Test
suite =
    describe "the limits of Klar.Diff and Klar.Compare"
        [ workTests
        , bigTextTests
        , hugeHunkTests
        , foldFocusTests
        , nameTests
        , keyTests
        , graphemeTests
        , compareTests
        ]



-- THE WORK HAS A BOUND


workTests : Test
workTests =
    describe "the work of marking what changed inside the lines"
        [ test "a pair that does not fit in the budget costs nothing and is one replacement" <|
            \_ ->
                Expect.equal ( [ Replace "a b c d" "a b x d" ], 0 ) (Inline.diffWithin 0 "a b c d" "a b x d")
        , test "a negative budget is the same as none" <|
            \_ ->
                Expect.equal ( [ Replace "a b c d" "a b x d" ], 0 ) (Inline.diffWithin -50 "a b c d" "a b x d")
        , test "with enough budget the words are marked" <|
            \_ ->
                Inline.diffWithin 100000 "a b c d" "a b x d"
                    |> Tuple.first
                    |> Expect.equal [ Keep "a b ", Replace "c" "x", Keep " d" ]
        , test "equal texts cost nothing" <|
            \_ -> Expect.equal ( [ Keep "same" ], 0 ) (Inline.diffWithin 10 "same" "same")
        , fuzz3 wordsFuzzer wordsFuzzer (Fuzz.intRange -5 200000) "the segments put the texts together again, whatever the budget" <|
            \old new budget ->
                let
                    segments =
                        Tuple.first (Inline.diffWithin budget old new)
                in
                Expect.equal ( old, new ) ( Inline.removedText segments, Inline.addedText segments )
        , fuzz2 (Fuzz.listOfLengthBetween 0 30 (Fuzz.pair wordsFuzzer wordsFuzzer)) (Fuzz.intRange 0 60000) "many pairs together never take much more than the budget" <|
            \pairs budget ->
                let
                    step ( old, new ) left =
                        left - Tuple.second (Inline.diffWithin left old new)

                    remaining =
                        List.foldl step budget pairs
                in
                -- a pair that crosses the line overshoots by about the size of its texts
                Expect.atLeast (negate 20000) remaining
        , test "a block of changed lines shares one budget: the lines after it is spent are marked whole" <|
            \_ ->
                let
                    line i changed =
                        List.range 1 60
                            |> List.map
                                (\k ->
                                    if changed && k == 30 then
                                        "zzz" ++ String.fromInt (i * 7 + k)

                                    else
                                        "word" ++ String.fromInt (i * 7 + k)
                                )
                            |> String.join " "

                    old =
                        List.range 1 800 |> List.map (\i -> line i False) |> String.join "\n"

                    new =
                        List.range 1 800 |> List.map (\i -> line i True) |> String.join "\n"

                    diff =
                        Diff.lines [] old new

                    -- a static view draws the first 500 rows of the block: the removed lines
                    markedLines =
                        Diff.viewStatic [] diff
                            |> Query.fromHtml
                            |> Query.findAll [ Selector.tag "del" ]
                            |> Query.count (\count -> Expect.all [ Expect.atLeast 50, Expect.atMost 600 ] count)
                in
                Expect.all
                    [ \_ -> Expect.equal False (Diff.tooLarge diff)
                    , \_ -> Expect.equal 800 (Diff.stats diff).changed
                    , \_ -> markedLines
                    ]
                    ()
        , test "600 changed lines of 300 words that have nothing in common are not too large, and are done" <|
            \_ ->
                let
                    make prefix =
                        List.range 1 600
                            |> List.map
                                (\i ->
                                    List.range 1 300
                                        |> List.map (\w -> prefix ++ String.fromInt (i * 7 + w * 13 + 100000))
                                        |> String.join " "
                                )
                            |> String.join "\n"
                in
                Expect.equal False (Diff.tooLarge (Diff.lines [] (make "a") (make "b")))
        , test "a block of more than a thousand changed lines is not marked inside the lines" <|
            \_ ->
                let
                    make prefix =
                        List.range 1 1200 |> List.map (\i -> prefix ++ " row " ++ String.fromInt i) |> String.join "\n"
                in
                Diff.viewStatic [] (Diff.lines [] (make "old") (make "new"))
                    |> Query.fromHtml
                    |> Query.findAll [ Selector.tag "ins" ]
                    |> Query.count (Expect.equal 0)
        , test "the strings of a JSON diff share one budget" <|
            \_ ->
                let
                    text word =
                        List.range 1 250
                            |> List.map (\k -> "w" ++ String.fromInt k)
                            |> List.map
                                (\w ->
                                    if w == "w75" then
                                        word

                                    else
                                        w
                                )
                            |> String.join " "

                    document word =
                        Encode.object
                            (List.range 1 200
                                |> List.map (\i -> ( "key" ++ String.fromInt (1000 + i), Encode.string (text word) ))
                            )
                in
                Diff.viewStatic [] (Diff.json [] (document "alpha") (document "omega"))
                    |> Query.fromHtml
                    |> Query.findAll [ Selector.class "klar-diff__ins--whole" ]
                    |> Query.count (Expect.all [ Expect.atLeast 50, Expect.atMost 180 ])
        , test "the fields of a diff share one budget" <|
            \_ ->
                let
                    text word =
                        List.range 1 250
                            |> List.map (\k -> "w" ++ String.fromInt k)
                            |> List.map
                                (\w ->
                                    if w == "w75" then
                                        word

                                    else
                                        w
                                )
                            |> String.join " "

                    fields word =
                        List.range 1 200
                            |> List.map (\i -> { label = "Field " ++ String.fromInt i, before = Just (text "alpha"), after = Just (text word) })
                in
                Diff.viewStatic [] (Diff.fields (fields "omega"))
                    |> Query.fromHtml
                    |> Query.findAll [ Selector.class "klar-diff__ins--whole" ]
                    |> Query.count (Expect.all [ Expect.atLeast 50, Expect.atMost 180 ])
        , fuzz2 (Fuzz.listOfLengthBetween 0 12 (Fuzz.intRange 0 5)) (Fuzz.listOfLengthBetween 0 12 (Fuzz.intRange 0 5)) "the work that Myers reports is more than the budget exactly when it gives up" <|
            \a b ->
                let
                    ( answer, work ) =
                        Myers.diffCounted 3 (Array.fromList a) (Array.fromList b)
                in
                case answer of
                    Nothing ->
                        Expect.atLeast 4 work

                    Just _ ->
                        Expect.all
                            [ \_ -> Expect.equal (Myers.diff 3 (Array.fromList a) (Array.fromList b)) answer
                            , \_ -> Expect.atLeast 0 work
                            ]
                            ()
        , test "the work of equal sequences is the work of reading them" <|
            \_ ->
                Myers.diffCounted 10 (Array.fromList [ 1, 2, 3, 4 ]) (Array.fromList [ 1, 2, 3, 4 ])
                    |> Tuple.second
                    |> Expect.equal 4
        ]


wordsFuzzer : Fuzzer String
wordsFuzzer =
    Fuzz.listOfLengthBetween 0
        25
        (Fuzz.oneOfValues [ "alpha", "beta", "gamma", "12", "3400", "order-77", " ", "  ", ",", "x" ])
        |> Fuzz.map String.concat



-- BIG TEXTS


bigTextTests : Test
bigTextTests =
    let
        numbered count =
            List.range 1 count |> List.map (\i -> "line " ++ String.fromInt i)
    in
    describe "big texts"
        [ test "two equal texts of a quarter of a million lines are not too large" <|
            \_ ->
                let
                    text =
                        String.join "\n" (numbered 250000)

                    diff =
                        Diff.lines [] text text
                in
                Expect.all
                    [ \_ -> Expect.equal False (Diff.tooLarge diff)
                    , \_ -> Expect.equal True (Diff.isEmpty diff)
                    ]
                    ()
        , test "equal texts are equal whatever the options say" <|
            \_ ->
                Diff.lines [ Diff.ignoreWhitespace, Diff.ignoreCase ] "a\n  b\n" "a\n  b\n"
                    |> Diff.isEmpty
                    |> Expect.equal True
        , test "a change in the middle of a huge text costs no more than the change" <|
            \_ ->
                let
                    old =
                        String.join "\n" (numbered 210000)

                    new =
                        String.join "\n"
                            (List.indexedMap
                                (\i line ->
                                    if i == 105000 then
                                        "changed"

                                    else
                                        line
                                )
                                (numbered 210000)
                            )

                    diff =
                        Diff.lines [] old new
                in
                Expect.all
                    [ \_ -> Expect.equal False (Diff.tooLarge diff)
                    , \_ -> Expect.equal 1 (List.length (Diff.hunks diff))
                    , \_ -> Expect.equal { added = 0, removed = 0, changed = 1 } (Diff.stats diff)
                    ]
                    ()
        , test "the summary of a diff that is too large counts what was cut off at the start and the end" <|
            \_ ->
                let
                    side prefix =
                        List.range 1 3000 |> List.map (\i -> prefix ++ String.fromInt i)

                    old =
                        String.join "\n" ([ "start 1", "start 2" ] ++ side "old " ++ [ "end" ])

                    new =
                        String.join "\n" ([ "start 1", "start 2" ] ++ side "new " ++ [ "end" ])
                in
                Diff.viewStatic [] (Diff.lines [] old new)
                    |> Query.fromHtml
                    |> Expect.all
                        [ Query.has [ Selector.text "Too large to compare line by line" ]
                        , Query.has [ Selector.text "3,003 lines" ]
                        ]
        ]



-- A HUGE BLOCK IS CUT


type alias Model =
    { state : Diff.State
    , diff : Diff.Diff
    }


start : Diff.Diff -> Model
start diff =
    { state = Diff.init "diff", diff = diff }


viewOf : List (Diff.Attribute Diff.Msg) -> Model -> Html Diff.Msg
viewOf attributes model =
    Diff.view identity attributes model.state model.diff


query : List (Diff.Attribute Diff.Msg) -> Model -> Query.Single Diff.Msg
query attributes model =
    Query.fromHtml (viewOf attributes model)


press : List (Diff.Attribute Diff.Msg) -> List Selector -> Model -> Result String Model
press attributes selectors model =
    query attributes model
        |> Query.find selectors
        |> Event.simulate Event.click
        |> Event.toResult
        |> Result.map (\msg -> { model | state = Tuple.first (Diff.update msg model.state) })


button : String -> List Selector
button name =
    [ Selector.tag "button", Selector.containing [ Selector.text name ] ]


resultExpectation : Result String Expect.Expectation -> Expect.Expectation
resultExpectation result =
    case result of
        Ok expectation ->
            expectation

        Err message ->
            Expect.fail message


bigLog : Int -> String
bigLog count =
    List.range 1 count |> List.map (\i -> "log line " ++ String.fromInt i) |> String.join "\n"


hugeHunkTests : Test
hugeHunkTests =
    let
        added =
            Diff.lines [] "" (bigLog 20000)
    in
    describe "a block of thousands of changed lines"
        [ test "it is one change" <|
            \_ -> Expect.equal 1 (List.length (Diff.hunks added))
        , test "the viewer draws 500 rows of it and says so" <|
            \_ ->
                query [] (start added)
                    |> Expect.all
                        [ Query.findAll [ Selector.class "klar-diff__row" ] >> Query.count (Expect.equal 500)
                        , Query.has [ Selector.text "Showing 500 of 20,000 changed lines" ]
                        , Query.has (button "Show 500 more lines (19,500 left)")
                        ]
        , test "the first row of the change still has the id for the focus" <|
            \_ -> query [] (start added) |> Query.has [ Selector.id "diff-change-0" ]
        , test "the static viewer cuts the block too, and has no button" <|
            \_ ->
                Diff.viewStatic [] added
                    |> Query.fromHtml
                    |> Expect.all
                        [ Query.findAll [ Selector.class "klar-diff__row" ] >> Query.count (Expect.equal 500)
                        , Query.has [ Selector.text "Showing 500 of 20,000 changed lines" ]
                        , Query.hasNot [ Selector.tag "button" ]
                        ]
        , test "show more draws 500 more rows, and the row where they begin has the id for the focus" <|
            \_ ->
                press [] (button "Show 500 more lines") (start added)
                    |> Result.map
                        (\moved ->
                            query [] moved
                                |> Expect.all
                                    [ Query.findAll [ Selector.class "klar-diff__row" ] >> Query.count (Expect.equal 1000)
                                    , Query.has [ Selector.text "Showing 1,000 of 20,000 changed lines" ]
                                    , Query.has [ Selector.id "diff-row-h1/1-500" ]
                                    , Query.hasNot [ Selector.id "diff-row-h1/1-1000" ]
                                    ]
                        )
                    |> resultExpectation
        , test "the last rows say how many are left, and then the note goes away" <|
            \_ ->
                let
                    small =
                        start (Diff.lines [] "" (bigLog 700))
                in
                press [] (button "Show 200 more lines (200 left)") small
                    |> Result.map
                        (\moved ->
                            query [] moved
                                |> Expect.all
                                    [ Query.findAll [ Selector.class "klar-diff__row" ] >> Query.count (Expect.equal 700)
                                    , Query.hasNot [ Selector.text "changed lines" ]
                                    ]
                        )
                    |> resultExpectation
        , test "a block of 500 lines is not cut" <|
            \_ ->
                query [] (start (Diff.lines [] "" (bigLog 500)))
                    |> Expect.all
                        [ Query.findAll [ Selector.class "klar-diff__row" ] >> Query.count (Expect.equal 500)
                        , Query.hasNot [ Selector.text "changed lines" ]
                        ]
        , test "side by side it is cut as well" <|
            \_ ->
                let
                    model =
                        { state = Diff.setSplit True (Diff.init "diff"), diff = added }
                in
                query [] model
                    |> Expect.all
                        [ Query.findAll [ Selector.class "klar-diff__row" ] >> Query.count (Expect.equal 500)
                        , Query.has [ Selector.text "Showing 500 of 20,000 changed lines" ]
                        ]
        , test "a block that was removed is cut the same way" <|
            \_ ->
                query [] (start (Diff.lines [] (bigLog 3000) ""))
                    |> Expect.all
                        [ Query.findAll [ Selector.class "klar-diff__row" ] >> Query.count (Expect.equal 500)
                        , Query.has [ Selector.text "Showing 500 of 3,000 changed lines" ]
                        ]
        , test "the note is in Norwegian when the language is" <|
            \_ ->
                query [ Diff.locale Locale.nb ] (start added)
                    |> Expect.all
                        [ Query.has [ Selector.text ("Viser 500 av " ++ Format.int Locale.nb 20000 ++ " endrede linjer") ]
                        , Query.has (button ("Vis 500 flere linjer (" ++ Format.int Locale.nb 19500 ++ " igjen)"))
                        ]
        , test "a static view of many changes draws 1,000 of them and says so" <|
            \_ ->
                let
                    fields =
                        List.range 1 1500
                            |> List.map (\i -> { label = "Field " ++ String.fromInt i, before = Just "a", after = Just "b" })
                in
                Diff.viewStatic [] (Diff.fields fields)
                    |> Query.fromHtml
                    |> Expect.all
                        [ Query.findAll [ Selector.class "klar-diff__entry" ] >> Query.count (Expect.equal 1000)
                        , Query.has [ Selector.text "Showing 1,000 of 1,500 changes" ]
                        ]
        , test "a static view of a few changes does not say anything about a limit" <|
            \_ ->
                Diff.viewStatic [] (Diff.fields [ { label = "Status", before = Just "a", after = Just "b" } ])
                    |> Query.fromHtml
                    |> Query.hasNot [ Selector.class "klar-diff__footer" ]
        ]



-- THE FOCUS WHEN LINES ARE OPENED


foldFocusTests : Test
foldFocusTests =
    let
        old =
            List.range 1 2000 |> List.map (\i -> "row " ++ String.fromInt i) |> String.join "\n"

        new =
            List.range 1 2000
                |> List.map
                    (\i ->
                        if i == 1 || i == 2000 then
                            "changed " ++ String.fromInt i

                        else
                            "row " ++ String.fromInt i
                    )
                |> String.join "\n"

        model =
            start (Diff.lines [] old new)

        opened =
            press [] (button "unchanged lines") model
    in
    describe "opening unchanged lines"
        [ test "the first 500 lines open, with a button for the rest" <|
            \_ ->
                opened
                    |> Result.map
                        (\moved ->
                            query [] moved
                                |> Expect.all
                                    [ Query.has (button "Show 500 more unchanged lines (1,492 left)")
                                    , Query.has (button "Hide 1,992 unchanged lines")
                                    ]
                        )
                    |> resultExpectation
        , test "the row where the next lines begin has an id, and no other row of the run has one" <|
            \_ ->
                opened
                    |> Result.andThen (press [] (button "Show 500 more unchanged lines"))
                    |> Result.map
                        (\moved ->
                            query [] moved
                                |> Expect.all
                                    [ Query.has [ Selector.id "diff-row-f5-500" ]
                                    , Query.hasNot [ Selector.id "diff-row-f5-1000" ]
                                    , Query.hasNot [ Selector.id "diff-row-f5-499" ]
                                    , Query.hasNot [ Selector.id "diff-row-f5-0" ]
                                    ]
                        )
                    |> resultExpectation
        , test "a static view has none of these ids" <|
            \_ ->
                Diff.viewStatic [] (Diff.lines [] old new)
                    |> Query.fromHtml
                    |> Query.hasNot [ Selector.id "-row-f5-500" ]
        ]



-- THE NAME OF THE VIEWER


nameTests : Test
nameTests =
    let
        name text =
            Selector.attribute (Attr.attribute "aria-label" text)

        region =
            Selector.attribute (Attr.attribute "role" "region")

        group =
            Selector.attribute (Attr.attribute "role" "group")

        -- the viewer itself has the id of the state
        frame =
            Selector.id "diff"

        fieldsDiff =
            Diff.fields [ { label = "Status", before = Just "Open", after = Just "Shipped" } ]

        linesDiff =
            Diff.lines [] "a\nb\n" "a\nc\n"

        label =
            Diff.ariaLabel "Changes to the order"

        -- everything that has the name, found from a box around the viewer so that the
        -- viewer itself is one of the things that can be found
        named html =
            Html.div [] [ html ]
                |> Query.fromHtml
                |> Query.findAll [ name "Changes to the order" ]

        theOnlyOne expectation html =
            named html
                |> Expect.all
                    [ Query.count (Expect.equal 1)
                    , Query.first >> expectation
                    ]
    in
    describe "one name for the content"
        [ test "a viewer of fields without a height has the name on the whole viewer, as a group" <|
            \_ ->
                viewOf [ label ] (start fieldsDiff)
                    |> theOnlyOne (Query.has [ frame, group ])
        , test "with a height the box that scrolls is the named region" <|
            \_ ->
                viewOf [ label, Diff.maxHeight 200 ] (start fieldsDiff)
                    |> theOnlyOne (Expect.all [ Query.has [ region, Selector.class "klar-diff__scroll" ], Query.hasNot [ frame ] ])
        , test "a viewer of lines has the name on the region only" <|
            \_ ->
                viewOf [ label ] (start linesDiff)
                    |> theOnlyOne (Expect.all [ Query.has [ region, Selector.class "klar-diff__scroll" ], Query.hasNot [ frame ] ])
        , test "a static view of lines has the name on the box that scrolls only, a group and not a landmark" <|
            \_ ->
                Diff.viewStatic [ label ] linesDiff
                    |> theOnlyOne (Expect.all [ Query.has [ group, Selector.class "klar-diff__scroll" ], Query.hasNot [ region ] ])
        , test "wrapped lines do not scroll: the name is on the whole and the box is no tab stop" <|
            \_ ->
                Diff.viewStatic [ label, Diff.wrapLines ] linesDiff
                    |> Expect.all
                        [ theOnlyOne (Query.has [ group, Selector.class "klar-diff" ])
                        , Query.fromHtml >> Query.find [ Selector.class "klar-diff__scroll" ] >> Query.hasNot [ Selector.attribute (Attr.tabindex 0) ]
                        ]
        , test "wrapped lines with a height scroll up and down, so the box is a tab stop again" <|
            \_ ->
                viewOf [ label, Diff.wrapLines, Diff.maxHeight 200 ] (start linesDiff)
                    |> theOnlyOne (Query.has [ region, Selector.class "klar-diff__scroll", Selector.attribute (Attr.tabindex 0) ])
        , test "a static view of fields is a group with the name" <|
            \_ ->
                Diff.viewStatic [ label ] fieldsDiff
                    |> theOnlyOne (Query.has [ group, Selector.class "klar-diff" ])
        , test "a viewer with nothing to show has the name on the whole" <|
            \_ ->
                viewOf [ label ] (start (Diff.lines [] "a" "a"))
                    |> theOnlyOne (Query.has [ frame, group ])
        , test "so has a summary of a diff that is too large" <|
            \_ ->
                let
                    side prefix =
                        List.range 1 3000 |> List.map (\i -> prefix ++ String.fromInt i) |> String.join "\n"
                in
                viewOf [ label ] (start (Diff.lines [] (side "a") (side "b")))
                    |> theOnlyOne (Query.has [ frame, group ])
        ]



-- KEYS


keyTests : Test
keyTests =
    let
        suffix key number =
            key ++ "~" ++ String.fromInt number

        keyFuzzer =
            Fuzz.listOfLengthBetween 0
                14
                (Fuzz.oneOfValues [ "a", "a~2", "a~3", "a~2~2", "b", "a~", "" ])
    in
    describe "keys that cannot collide"
        [ test "the example that repeated a key" <|
            \_ ->
                Keys.unique suffix [ "a", "a", "a~2" ]
                    |> Expect.equal [ "a", "a~2", "a~2~2" ]
        , test "different keys stay as they are" <|
            \_ -> Expect.equal [ "a", "b", "c" ] (Keys.unique suffix [ "a", "b", "c" ])
        , test "a repeated key gets a number" <|
            \_ -> Expect.equal [ "a", "b", "a~2", "a~3" ] (Keys.unique suffix [ "a", "b", "a", "a" ])
        , fuzz keyFuzzer "there are as many keys as before and all are different" <|
            \keys ->
                let
                    made =
                        Keys.unique suffix keys
                in
                Expect.all
                    [ \_ -> Expect.equal (List.length keys) (List.length made)
                    , \_ -> Expect.equal (List.length made) (Set.size (Set.fromList made))
                    ]
                    ()
        , fuzz keyFuzzer "keys that were different already are not changed" <|
            \keys ->
                let
                    distinct =
                        Set.toList (Set.fromList keys)
                in
                Expect.equal distinct (Keys.unique suffix distinct)
        , fuzz keyFuzzer "the first item with a key that is new keeps it" <|
            \keys ->
                case ( keys, Keys.unique suffix keys ) of
                    ( first :: _, firstMade :: _ ) ->
                        Expect.equal first firstMade

                    _ ->
                        Expect.pass
        , test "a field that is called like a repeated label does not collide with it" <|
            \_ ->
                let
                    fields =
                        [ { label = "Status", before = Just "a", after = Just "b" }
                        , { label = "Status", before = Just "c", after = Just "d" }
                        , { label = "Status (2)", before = Just "e", after = Just "f" }
                        ]

                    keys =
                        Diff.hunks (Diff.fields fields) |> List.map Diff.hunkKey
                in
                Expect.all
                    [ \_ -> Expect.equal 3 (List.length keys)
                    , \_ -> Expect.equal 3 (Set.size (Set.fromList keys))
                    ]
                    ()
        , test "two places with the same path as text have different keys" <|
            \_ ->
                let
                    object a b =
                        Encode.object
                            [ ( "a.b", Encode.int a )
                            , ( "a", Encode.object [ ( "b", Encode.int b ) ] )
                            ]

                    keys =
                        Diff.hunks (Diff.json [] (object 1 1) (object 2 2)) |> List.map Diff.hunkKey
                in
                Expect.all
                    [ \_ -> Expect.equal 2 (List.length keys)
                    , \_ -> Expect.equal 2 (Set.size (Set.fromList keys))
                    ]
                    ()
        ]



-- GRAPHEMES


graphemeTests : Test
graphemeTests =
    let
        marks =
            [ "́", "̈", "️", "🏽" ]

        isMark text =
            case String.uncons text of
                Just ( first, _ ) ->
                    List.member (String.fromChar first) marks

                Nothing ->
                    False

        textFuzzer =
            Fuzz.listOfLengthBetween 0
                16
                (Fuzz.oneOfValues [ "e", "a", "x", "1", "2", "3", "́", "̈", "🏽", "️", "👍", "-", " " ])
                |> Fuzz.map String.concat
    in
    describe "a letter is never cut from its accent"
        [ test "the characters of a word with an accent" <|
            \_ ->
                Expect.equal [ "A", "m", "é", "l", "i", "e" ] (Inline.clusters "Amélie")
        , test "an emoji with a skin tone is one character" <|
            \_ -> Expect.equal [ "a", "👍🏽", "b" ] (Inline.clusters "a👍🏽b")
        , test "emoji joined with a zero width joiner are one character" <|
            \_ -> Expect.equal [ "x", "👩\u{200D}💻", "y" ] (Inline.clusters "x👩\u{200D}💻y")
        , test "the accent is part of the word in the tokens" <|
            \_ -> Expect.equal [ "Amélie", " ", "x" ] (Inline.tokens "Amélie x")
        , test "a changed letter with an accent is marked with its accent" <|
            \_ ->
                Inline.diff "Améliexxxx1234" "Amelieyyyy1234"
                    |> List.filter (\segment -> segment /= Keep "Am")
                    |> List.all
                        (\segment ->
                            case segment of
                                Keep text ->
                                    not (isMark text)

                                Replace removed added ->
                                    not (isMark removed) && not (isMark added)
                        )
                    |> Expect.equal True
        , fuzz textFuzzer "the characters make the text again" <|
            \text -> Expect.equal text (String.concat (Inline.clusters text))
        , fuzz2 textFuzzer textFuzzer "no part of a diff begins with a mark that belongs to the character before it" <|
            \old new ->
                let
                    segments =
                        Inline.diff old new

                    begins segment =
                        case segment of
                            Keep text ->
                                [ text ]

                            Replace removed added ->
                                [ removed, added ]

                    -- the first part of a text may begin with a mark: there is nothing before it
                    inner =
                        List.drop 1 segments
                in
                inner
                    |> List.concatMap begins
                    |> List.filter isMark
                    |> Expect.equal []
        , fuzz2 textFuzzer textFuzzer "the segments still make both texts" <|
            \old new ->
                let
                    segments =
                        Inline.diff old new
                in
                Expect.equal ( old, new ) ( Inline.removedText segments, Inline.addedText segments )
        ]



-- COMPARE


type alias Item =
    { id : Int
    , name : String
    }


compareView : List (Compare.Field Item msg) -> List Item -> Html msg
compareView fields items =
    Compare.view []
        { ariaLabel = "Compare"
        , ids = Ids.int
        , id = .id
        , header = \item -> Html.text item.name
        , fields = fields
        }
        items


compareTests : Test
compareTests =
    let
        items =
            [ { id = 1, name = "One" }, { id = 2, name = "Two" } ]
    in
    describe "a comparison without fields"
        [ test "says that there are no fields, not that there are no differences" <|
            \_ ->
                compareView [] items
                    |> Query.fromHtml
                    |> Expect.all
                        [ Query.has [ Selector.text "No fields" ]
                        , Query.hasNot [ Selector.text "No differences" ]
                        , Query.hasNot [ Selector.text "All the records have the same values" ]
                        ]
        , test "headings alone are no fields either" <|
            \_ ->
                compareView [ Compare.heading "Pricing" ] items
                    |> Query.fromHtml
                    |> Expect.all
                        [ Query.has [ Selector.text "No fields" ]
                        , Query.hasNot [ Selector.text "Pricing" ]
                        ]
        , test "the summary says so too" <|
            \_ ->
                compareView [] items
                    |> Query.fromHtml
                    |> Query.find [ Selector.class "klar-compare__summary" ]
                    |> Query.has [ Selector.text "No fields" ]
        , test "records that have the same values still say No differences" <|
            \_ ->
                compareView [ Compare.text "Kind" (always "tool") ] items
                    |> Query.fromHtml
                    |> Expect.all
                        [ Query.has [ Selector.text "0 of 1 fields differ from the baseline" ]
                        , Query.hasNot [ Selector.text "No fields" ]
                        ]
        , test "in Norwegian" <|
            \_ ->
                Compare.view [ Compare.locale Locale.nb ]
                    { ariaLabel = "Sammenlign"
                    , ids = Ids.int
                    , id = .id
                    , header = \item -> Html.text item.name
                    , fields = []
                    }
                    items
                    |> Query.fromHtml
                    |> Query.has [ Selector.text "Ingen felt" ]
        , test "records with the same id are all drawn" <|
            \_ ->
                compareView [ Compare.text "Name" .name ]
                    [ { id = 1, name = "One" }, { id = 1, name = "Uno" }, { id = 1, name = "Eins" } ]
                    |> Query.fromHtml
                    |> Query.findAll [ Selector.tag "th", Selector.attribute (Attr.scope "col") ]
                    |> Query.count (Expect.equal 4)
        ]
