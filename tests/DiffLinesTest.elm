module DiffLinesTest exposing (suite)

import Array
import Expect
import Fuzz exposing (Fuzzer)
import Klar.Diff.Lines as Lines exposing (Outcome(..), Segment(..))
import Test exposing (Test, describe, fuzz2, test)


suite : Test
suite =
    describe "Klar.Diff.Lines"
        [ parsing
        , comparing
        , options
        , degrading
        , properties
        ]


plain : Lines.Options
plain =
    { ignoreWhitespace = False, ignoreCase = False, maxWork = Lines.defaultMaxWork }


compared : Lines.Options -> String -> String -> Maybe Lines.Compared
compared opts old new =
    case (Lines.diff opts old new).outcome of
        Done result ->
            Just result

        TooLarge _ ->
            Nothing


hunksOf : Lines.Options -> String -> String -> List Lines.Hunk
hunksOf opts old new =
    compared opts old new
        |> Maybe.map .segments
        |> Maybe.withDefault []
        |> List.filterMap
            (\segment ->
                case segment of
                    Changed hunk ->
                        Just hunk

                    Equal _ ->
                        Nothing
            )


numbersAndTexts : List Lines.ChangedLine -> List ( Int, String )
numbersAndTexts =
    List.map (\line -> ( line.number, line.text ))


parsing : Test
parsing =
    describe "cutting a text into lines"
        [ test "the empty text has no lines" <|
            \_ -> Expect.equal 0 (Array.length (Lines.parse "").lines)
        , test "a text without a line end at the end" <|
            \_ ->
                Lines.parse "a\nb"
                    |> Expect.all
                        [ \parsed -> Expect.equal [ "a", "b" ] (Array.toList parsed.lines)
                        , \parsed -> Expect.equal False parsed.endsWithNewline
                        ]
        , test "a text with a line end at the end has no empty last line" <|
            \_ ->
                Lines.parse "a\nb\n"
                    |> Expect.all
                        [ \parsed -> Expect.equal [ "a", "b" ] (Array.toList parsed.lines)
                        , \parsed -> Expect.equal True parsed.endsWithNewline
                        ]
        , test "a text of one line end is one empty line" <|
            \_ -> Expect.equal [ "" ] (Array.toList (Lines.parse "\n").lines)
        , test "an empty line at the end is kept" <|
            \_ -> Expect.equal [ "a", "" ] (Array.toList (Lines.parse "a\n\n").lines)
        , test "\\r\\n, \\n and \\r all end a line" <|
            \_ -> Expect.equal [ "a", "b", "c", "d" ] (Array.toList (Lines.parse "a\u{000D}\nb\nc\u{000D}d").lines)
        , test "windows line ends are noticed" <|
            \_ ->
                Expect.equal ( True, False )
                    ( (Lines.parse "a\u{000D}\nb").windowsLineEnds, (Lines.parse "a\nb").windowsLineEnds )
        ]


comparing : Test
comparing =
    describe "comparing two texts"
        [ test "equal texts have no hunks" <|
            \_ ->
                compared plain "a\nb\nc\n" "a\nb\nc\n"
                    |> Maybe.map .segments
                    |> Expect.equal (Just [ Equal { oldStart = 0, newStart = 0, count = 3 } ])
        , test "two empty texts have no segments" <|
            \_ ->
                compared plain "" ""
                    |> Maybe.map .segments
                    |> Expect.equal (Just [])
        , test "everything is added to an empty text" <|
            \_ ->
                hunksOf plain "" "a\nb"
                    |> List.map (\hunk -> ( numbersAndTexts hunk.removed, numbersAndTexts hunk.added ))
                    |> Expect.equal [ ( [], [ ( 1, "a" ), ( 2, "b" ) ] ) ]
        , test "everything is removed when the new text is empty" <|
            \_ ->
                hunksOf plain "a\nb\n" ""
                    |> List.map (\hunk -> ( numbersAndTexts hunk.removed, numbersAndTexts hunk.added ))
                    |> Expect.equal [ ( [ ( 1, "a" ), ( 2, "b" ) ], [] ) ]
        , test "a changed line in the middle has the numbers of both texts" <|
            \_ ->
                hunksOf plain "a\nb\nc\nd\ne" "a\nb\nX\nd\ne"
                    |> List.map (\hunk -> { oldStart = hunk.oldStart, newStart = hunk.newStart, removed = numbersAndTexts hunk.removed, added = numbersAndTexts hunk.added })
                    |> Expect.equal [ { oldStart = 2, newStart = 2, removed = [ ( 3, "c" ) ], added = [ ( 3, "X" ) ] } ]
        , test "lines added before shift the numbers of the new text" <|
            \_ ->
                hunksOf plain "a\nb\nc" "new\nnew2\na\nb\nX"
                    |> List.map (\hunk -> ( numbersAndTexts hunk.removed, numbersAndTexts hunk.added ))
                    |> Expect.equal
                        [ ( [], [ ( 1, "new" ), ( 2, "new2" ) ] )
                        , ( [ ( 3, "c" ) ], [ ( 5, "X" ) ] )
                        ]
        , test "the hunks are numbered from 0 in order" <|
            \_ ->
                hunksOf plain "a\nb\nc\nd\ne" "A\nb\nc\nd\nE"
                    |> List.map .index
                    |> Expect.equal [ 0, 1 ]
        , test "the first removed line is compared with the first added line" <|
            \_ ->
                hunksOf plain "Total: 1234.50" "Total: 1284.50"
                    |> List.concatMap (\hunk -> List.map .parts hunk.removed ++ List.map .parts hunk.added)
                    |> Expect.equal
                        [ [ { text = "Total: 12", changed = False }, { text = "3", changed = True }, { text = "4.50", changed = False } ]
                        , [ { text = "Total: 12", changed = False }, { text = "8", changed = True }, { text = "4.50", changed = False } ]
                        ]
        , test "lines with nothing in common are not marked inside" <|
            \_ ->
                hunksOf plain "alpha one" "gamma two"
                    |> List.concatMap (\hunk -> List.map .parts hunk.removed)
                    |> Expect.equal [ [ { text = "alpha one", changed = False } ] ]
        , test "a line without a partner is one unchanged piece" <|
            \_ ->
                hunksOf plain "a" "a changed\nextra"
                    |> List.concatMap (\hunk -> List.map .parts hunk.added)
                    |> Expect.equal
                        [ [ { text = "a", changed = False }, { text = " changed", changed = True } ]
                        , [ { text = "extra", changed = False } ]
                        ]
        , test "a text that gets a line end at the end changes its last line" <|
            \_ ->
                hunksOf plain "a\nb" "a\nb\n"
                    |> List.map (\hunk -> ( List.map .missingNewline hunk.removed, List.map .missingNewline hunk.added ))
                    |> Expect.equal [ ( [ True ], [ False ] ) ]
        , test "two texts that both lack the line end at the end are equal" <|
            \_ ->
                hunksOf plain "a\nb" "a\nb"
                    |> Expect.equal []
        , test "the last line of a text without a line end is marked" <|
            \_ ->
                hunksOf plain "a\nb" "a\nc"
                    |> List.map (\hunk -> ( List.map .missingNewline hunk.removed, List.map .missingNewline hunk.added ))
                    |> Expect.equal [ ( [ True ], [ True ] ) ]
        , test "line ends of windows and unix are not a difference, but are noted" <|
            \_ ->
                let
                    result =
                        Lines.diff plain "a\u{000D}\nb\u{000D}\n" "a\nb\n"
                in
                Expect.equal ( True, [] )
                    ( result.lineEndsDiffer
                    , case result.outcome of
                        Done found ->
                            List.filter (\segment -> segment /= Equal { oldStart = 0, newStart = 0, count = 2 }) found.segments

                        TooLarge _ ->
                            [ Equal { oldStart = 0, newStart = 0, count = 0 } ]
                    )
        , test "texts with the same line ends are not noted" <|
            \_ -> Expect.equal False (Lines.diff plain "a\nb" "a\nc").lineEndsDiffer
        , test "an empty text has no line ends to differ" <|
            \_ -> Expect.equal False (Lines.diff plain "" "a\u{000D}\nb").lineEndsDiffer
        , test "the key of a hunk says where it is and how big" <|
            \_ ->
                hunksOf plain "a\nb\nc\nd" "a\nX\nY\nd"
                    |> List.map Lines.hunkKey
                    |> Expect.equal [ "2:2/2:2" ]
        , test "the keys do not change for the same texts" <|
            \_ ->
                Expect.equal
                    (List.map Lines.hunkKey (hunksOf plain "a\nb\nc\nd\ne\nf" "a\nB\nc\nd\nE\nf"))
                    (List.map Lines.hunkKey (hunksOf plain "a\nb\nc\nd\ne\nf" "a\nB\nc\nd\nE\nf"))
        ]


options : Test
options =
    describe "ignoring white space and case"
        [ test "a change of the white space is a change" <|
            \_ -> Expect.equal 1 (List.length (hunksOf plain "a  b\nc" "a b\nc"))
        , test "a change of the white space is ignored on request" <|
            \_ -> Expect.equal 0 (List.length (hunksOf { plain | ignoreWhitespace = True } "a  b\nc" "a b\nc"))
        , test "indentation and trailing white space are ignored on request" <|
            \_ -> Expect.equal 0 (List.length (hunksOf { plain | ignoreWhitespace = True } "    a\n\tb  " "a\nb"))
        , test "white space that separates words is still a difference when it is not there" <|
            \_ -> Expect.equal 1 (List.length (hunksOf { plain | ignoreWhitespace = True } "a b" "ab"))
        , test "a missing line end at the end is white space" <|
            \_ -> Expect.equal 0 (List.length (hunksOf { plain | ignoreWhitespace = True } "a\nb" "a\nb\n"))
        , test "a change of case is a change" <|
            \_ -> Expect.equal 1 (List.length (hunksOf plain "Hello" "hello"))
        , test "a change of case is ignored on request" <|
            \_ -> Expect.equal 0 (List.length (hunksOf { plain | ignoreCase = True } "Hello" "hello"))
        , test "both options together" <|
            \_ -> Expect.equal 0 (List.length (hunksOf { plain | ignoreCase = True, ignoreWhitespace = True } "  Hello   World" "hello world"))
        , test "a real change is found with the options on" <|
            \_ -> Expect.equal 1 (List.length (hunksOf { plain | ignoreCase = True, ignoreWhitespace = True } "Hello World\nb" "hello  there\nb"))
        , test "equal lines show the text of the new side's numbers, the changed ones are kept as they are" <|
            \_ ->
                hunksOf { plain | ignoreWhitespace = True } "x\n  a\ny" "x\na  \nz"
                    |> List.map (\hunk -> ( numbersAndTexts hunk.removed, numbersAndTexts hunk.added ))
                    |> Expect.equal [ ( [ ( 3, "y" ) ], [ ( 3, "z" ) ] ) ]
        ]


degrading : Test
degrading =
    describe "texts that are too different"
        [ test "a diff that needs more work than allowed is a summary" <|
            \_ ->
                let
                    old =
                        String.join "\n" (List.map (\i -> "old " ++ String.fromInt i) (List.range 1 300))

                    new =
                        String.join "\n" (List.map (\i -> "new " ++ String.fromInt i) (List.range 1 250))
                in
                case (Lines.diff { plain | maxWork = 1000 } old new).outcome of
                    TooLarge summary ->
                        Expect.equal
                            { oldLines = 300, newLines = 250, sameAtStart = 0, sameAtEnd = 0, onlyInOld = 300, onlyInNew = 250 }
                            summary

                    Done _ ->
                        Expect.fail "expected a summary"
        , test "the summary tells how much is the same at the start and the end" <|
            \_ ->
                let
                    old =
                        String.join "\n" ([ "head 1", "head 2" ] ++ List.map (\i -> "old " ++ String.fromInt i) (List.range 1 200) ++ [ "tail" ])

                    new =
                        String.join "\n" ([ "head 1", "head 2" ] ++ List.map (\i -> "new " ++ String.fromInt i) (List.range 1 200) ++ [ "tail" ])
                in
                case (Lines.diff { plain | maxWork = 1000 } old new).outcome of
                    TooLarge summary ->
                        Expect.equal { start = 2, end = 1, old = 200, new = 200 }
                            { start = summary.sameAtStart, end = summary.sameAtEnd, old = summary.onlyInOld, new = summary.onlyInNew }

                    Done _ ->
                        Expect.fail "expected a summary"
        , test "the summary counts lines that only moved as present in both" <|
            \_ ->
                let
                    old =
                        String.join "\n" (List.map String.fromInt (List.range 1 100)) ++ "\n"

                    new =
                        String.join "\n" (List.map String.fromInt (List.reverse (List.range 1 100))) ++ "\n"
                in
                case (Lines.diff { plain | maxWork = 100 } old new).outcome of
                    TooLarge summary ->
                        Expect.equal ( 0, 0 ) ( summary.onlyInOld, summary.onlyInNew )

                    Done _ ->
                        Expect.fail "expected a summary"
        , test "a few changes in a long text are found whatever its length" <|
            \_ ->
                let
                    old =
                        String.join "\n" (List.map String.fromInt (List.range 1 20000))

                    new =
                        String.join "\n" (List.map String.fromInt (List.range 1 9999) ++ [ "ten thousand" ] ++ List.map String.fromInt (List.range 10001 20000))
                in
                hunksOf plain old new
                    |> List.map (\hunk -> ( numbersAndTexts hunk.removed, numbersAndTexts hunk.added ))
                    |> Expect.equal [ ( [ ( 10000, "10000" ) ], [ ( 10000, "ten thousand" ) ] ) ]
        , test "5 000 lines with 600 changed lines are compared" <|
            \_ ->
                let
                    lines =
                        List.range 1 5000

                    old =
                        String.join "\n" (List.map (\i -> "line " ++ String.fromInt i) lines)

                    new =
                        String.join "\n"
                            (List.map
                                (\i ->
                                    if modBy 8 i == 3 then
                                        "changed " ++ String.fromInt i

                                    else
                                        "line " ++ String.fromInt i
                                )
                                lines
                            )
                in
                hunksOf plain old new
                    |> List.length
                    |> Expect.equal 625
        ]


properties : Test
properties =
    describe "properties"
        [ fuzz2 lineText lineText "the equal lines and the removed lines are the old text, the equal and the added lines the new text" <|
            \old new ->
                case compared plain old new of
                    Just result ->
                        Expect.all
                            [ \_ -> Expect.equal (Array.toList (Lines.parse old).lines) (oldLinesOf result)
                            , \_ -> Expect.equal (Array.toList (Lines.parse new).lines) (newLinesOf result)
                            ]
                            ()

                    Nothing ->
                        Expect.fail "expected a diff"
        , fuzz2 lineText lineText "no hunk is empty and no two hunks follow each other" <|
            \old new ->
                case compared plain old new of
                    Just result ->
                        Expect.equal [] (shapeProblems result.segments)

                    Nothing ->
                        Expect.fail "expected a diff"
        , fuzz2 lineText lineText "a text compared with itself has no hunks" <|
            \old _ ->
                hunksOf plain old old
                    |> Expect.equal []
        ]


{-| The old lines, put together from the equal segments and the removed lines of
the hunks.
-}
oldLinesOf : Lines.Compared -> List String
oldLinesOf result =
    result.segments
        |> List.concatMap
            (\segment ->
                case segment of
                    Equal { oldStart, count } ->
                        Array.toList (Array.slice oldStart (oldStart + count) result.old)

                    Changed hunk ->
                        List.map .text hunk.removed
            )


newLinesOf : Lines.Compared -> List String
newLinesOf result =
    result.segments
        |> List.concatMap
            (\segment ->
                case segment of
                    Equal { newStart, count } ->
                        Array.toList (Array.slice newStart (newStart + count) result.new)

                    Changed hunk ->
                        List.map .text hunk.added
            )


shapeProblems : List Segment -> List String
shapeProblems segments =
    let
        empty segment =
            case segment of
                Equal { count } ->
                    count == 0

                Changed hunk ->
                    List.isEmpty hunk.removed && List.isEmpty hunk.added

        twice pair =
            case pair of
                ( Equal _, Equal _ ) ->
                    True

                ( Changed _, Changed _ ) ->
                    True

                _ ->
                    False
    in
    (if List.any empty segments then
        [ "an empty segment" ]

     else
        []
    )
        ++ (if List.any twice (List.map2 Tuple.pair segments (List.drop 1 segments)) then
                [ "two segments of the same kind in a row" ]

            else
                []
           )


lineText : Fuzzer String
lineText =
    Fuzz.listOfLengthBetween 0 12 (Fuzz.oneOfValues [ "a", "b", "c", "  d", "", "e " ])
        |> Fuzz.map (String.join "\n")
