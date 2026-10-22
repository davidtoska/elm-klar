module Klar.Diff.Lines exposing
    ( ChangedLine
    , Compared
    , Comparison
    , Hunk
    , Options
    , Outcome(..)
    , Segment(..)
    , Summary
    , defaultMaxWork
    , diff
    , hunkKey
    , parse
    )

{-| The difference between two texts, line by line.

The texts are cut into lines (`\r\n`, `\n` and `\r` all end a line, and a text
that does not end with a line end is told apart from one that does, like `git`
does). Every distinct line gets an integer, the integers are compared with the
shortest edit script ([Klar.Diff.Myers](Klar-Diff-Myers)), and the script is turned
into the segments of the diff: stretches of equal lines, and hunks, each with the
lines that were removed and the lines that were added. The first removed line is
compared with the first added line inside the hunk, the second with the second and
so on, to mark what changed inside the line ([Klar.Diff.Inline](Klar-Diff-Inline)).

The work is limited. The beginning and the end of the texts that are the same are
cut off first (two equal texts cost no more than reading them). When what is left
is too different to compare in the given amount of work, the answer is a summary of
both texts instead (`TooLarge`), never a wrong or a late diff. Marking what changed
inside the lines has one budget for the whole diff (half of the given work): the
changed lines that come after it is spent are marked as a whole.

-}

import Array exposing (Array)
import Dict exposing (Dict)
import Klar.Diff.Inline as Inline
import Klar.Diff.Myers as Myers exposing (Run(..))
import Klar.Diff.Types exposing (Part)


{-| What the comparison ignores, and how much work it may do.
-}
type alias Options =
    { ignoreWhitespace : Bool
    , ignoreCase : Bool
    , maxWork : Int
    }


{-| The work that comparing two texts may take before the diff degrades to a
summary: about a third of a second in a browser.
-}
defaultMaxWork : Int
defaultMaxWork =
    2000000


{-| Together the lines of the two texts that are left when the beginning and the end
that are the same are cut off may be this many; more are not compared line by line.
-}
mostLines : Int
mostLines =
    200000


{-| A hunk that has more removed lines or more added lines than this is not marked
inside the lines. Lines are paired by their place in the hunk (the first removed
with the first added), which tells something about a small hunk and nothing about
a block of thousands of lines.
-}
mostPairs : Int
mostPairs =
    1000


{-| The answer, with a note on the line ends of the two texts.
-}
type alias Comparison =
    { outcome : Outcome
    , lineEndsDiffer : Bool
    }


type Outcome
    = Done Compared
    | TooLarge Summary


{-| A text compared line by line. Lines are numbered from 1 for people and from
0 inside; `oldStart` and `newStart` are the numbers from 0.
-}
type alias Compared =
    { old : Array String
    , new : Array String
    , oldMissingNewline : Bool
    , newMissingNewline : Bool
    , segments : List Segment
    }


type Segment
    = Equal { oldStart : Int, newStart : Int, count : Int }
    | Changed Hunk


{-| Removed and added lines that follow each other. `index` counts the hunks of the
diff from 0.
-}
type alias Hunk =
    { index : Int
    , oldStart : Int
    , newStart : Int
    , removed : List ChangedLine
    , added : List ChangedLine
    }


{-| A removed or an added line: its number (from 1), its text in pieces that say
what changed inside it, and whether it is the last line of a text that has no line
end after it.
-}
type alias ChangedLine =
    { number : Int
    , text : String
    , parts : List Part
    , missingNewline : Bool
    }


{-| What can be said of two texts that were not compared line by line.
-}
type alias Summary =
    { oldLines : Int
    , newLines : Int
    , sameAtStart : Int
    , sameAtEnd : Int
    , onlyInOld : Int
    , onlyInNew : Int
    }



-- PARSING


type alias Parsed =
    { lines : Array String
    , endsWithNewline : Bool
    , windowsLineEnds : Bool
    }


{-| The lines of a text. The empty text has no lines (not one empty line), and a
text that ends with a line end has no empty last line.
-}
parse : String -> Parsed
parse text =
    if text == "" then
        { lines = Array.empty, endsWithNewline = True, windowsLineEnds = False }

    else
        let
            all =
                String.lines text

            ( lines, ends ) =
                case List.reverse all of
                    "" :: reversedRest ->
                        ( List.reverse reversedRest, True )

                    _ ->
                        ( all, False )
        in
        { lines = Array.fromList lines
        , endsWithNewline = ends
        , windowsLineEnds = String.contains "\u{000D}\n" text
        }



-- COMPARING


{-| Compares two texts line by line.
-}
diff : Options -> String -> String -> Comparison
diff options oldText newText =
    let
        old =
            parse oldText

        new =
            parse newText

        oldMissingNewline =
            not old.endsWithNewline

        newMissingNewline =
            not new.endsWithNewline

        compared segments =
            Done
                { old = old.lines
                , new = new.lines
                , oldMissingNewline = oldMissingNewline
                , newMissingNewline = newMissingNewline
                , segments = segments
                }

        outcome =
            if oldText == newText then
                -- the same text is the same whatever the options say, and costs no more than reading it
                compared
                    (if Array.isEmpty old.lines then
                        []

                     else
                        [ Equal { oldStart = 0, newStart = 0, count = Array.length old.lines } ]
                    )

            else
                let
                    oldKeys =
                        keysOf options old

                    newKeys =
                        keysOf options new

                    oldCount =
                        Array.length oldKeys

                    newCount =
                        Array.length newKeys

                    -- the beginning and the end that are the same are not part of the work
                    prefix =
                        samePrefix oldKeys newKeys 0 (min oldCount newCount)

                    suffix =
                        sameSuffix oldKeys newKeys prefix 0

                    ( oldIds, newIds ) =
                        identify
                            (Array.slice prefix (oldCount - suffix) oldKeys)
                            (Array.slice prefix (newCount - suffix) newKeys)
                in
                if Array.length oldIds + Array.length newIds > mostLines then
                    TooLarge (summarize oldCount newCount prefix suffix oldIds newIds)

                else
                    case Myers.diff options.maxWork oldIds newIds of
                        Just runs ->
                            compared
                                (toSegments (options.maxWork // 2)
                                    old.lines
                                    new.lines
                                    oldMissingNewline
                                    newMissingNewline
                                    (sameRun prefix ++ runs ++ sameRun suffix)
                                )

                        Nothing ->
                            TooLarge (summarize oldCount newCount prefix suffix oldIds newIds)
    in
    { outcome = outcome
    , lineEndsDiffer = old.windowsLineEnds /= new.windowsLineEnds && Array.length old.lines > 0 && Array.length new.lines > 0
    }


{-| The beginning or the end that is the same in both texts, as the first or the
last run of the script. The runs of the middle never begin or end with a stretch
that is the same, because that was cut off.
-}
sameRun : Int -> List Run
sameRun count =
    if count > 0 then
        [ Same count ]

    else
        []


{-| What decides whether two lines are the same: the text, with the white space
or the case left out when the options say so, and whether it is a last line with
no line end after it (not when white space is ignored).
-}
keysOf : Options -> Parsed -> Array ( String, Int )
keysOf options parsed =
    let
        count =
            Array.length parsed.lines

        keyOf index line =
            ( line
                |> (if options.ignoreWhitespace then
                        collapseWhitespace

                    else
                        identity
                   )
                |> (if options.ignoreCase then
                        String.toLower

                    else
                        identity
                   )
            , if not options.ignoreWhitespace && not parsed.endsWithNewline && index == count - 1 then
                1

              else
                0
            )
    in
    Array.indexedMap keyOf parsed.lines


{-| No white space at the start and the end, and one space for each run of white
space inside.
-}
collapseWhitespace : String -> String
collapseWhitespace line =
    String.words line |> String.join " "


identify : Array ( String, Int ) -> Array ( String, Int ) -> ( Array Int, Array Int )
identify first second =
    let
        -- `Dict.size` walks the whole dictionary: the next id is counted instead
        assign key ( ids, known, next ) =
            case Dict.get key known of
                Just id ->
                    ( id :: ids, known, next )

                Nothing ->
                    ( next :: ids, Dict.insert key next known, next + 1 )

        ( firstIds, firstKnown, firstNext ) =
            Array.foldl assign ( [], Dict.empty, 0 ) first

        ( secondIds, _, _ ) =
            Array.foldl assign ( [], firstKnown, firstNext ) second
    in
    ( Array.fromList (List.reverse firstIds), Array.fromList (List.reverse secondIds) )


{-| What can be said of two texts that are too different to compare: how many lines
they have, how many are the same at the start and at the end (those were cut off
before the comparison, `oldIds` and `newIds` are the lines in between), and how many
lines of each text do not occur in the other.
-}
summarize : Int -> Int -> Int -> Int -> Array Int -> Array Int -> Summary
summarize oldCount newCount prefix suffix oldIds newIds =
    let
        counts ids =
            Array.foldl (\id -> Dict.update id (\n -> Just (Maybe.withDefault 0 n + 1))) Dict.empty ids

        oldCounts =
            counts oldIds

        newCounts =
            counts newIds

        surplus from other =
            Dict.foldl
                (\id count total -> total + max 0 (count - Maybe.withDefault 0 (Dict.get id other)))
                0
                from
    in
    { oldLines = oldCount
    , newLines = newCount
    , sameAtStart = prefix
    , sameAtEnd = suffix
    , onlyInOld = surplus oldCounts newCounts
    , onlyInNew = surplus newCounts oldCounts
    }


samePrefix : Array a -> Array a -> Int -> Int -> Int
samePrefix a b i limit =
    if i < limit && Array.get i a == Array.get i b then
        samePrefix a b (i + 1) limit

    else
        i


sameSuffix : Array a -> Array a -> Int -> Int -> Int
sameSuffix a b prefix count =
    let
        n =
            Array.length a

        m =
            Array.length b
    in
    if count < min (n - prefix) (m - prefix) && Array.get (n - 1 - count) a == Array.get (m - 1 - count) b then
        sameSuffix a b prefix (count + 1)

    else
        count



-- SEGMENTS


toSegments : Int -> Array String -> Array String -> Bool -> Bool -> List Run -> List Segment
toSegments inlineBudget old new oldMissingNewline newMissingNewline runs =
    let
        -- `budget` is what is left of the work for marking the changes inside the lines
        go remaining oldAt newAt index budget built =
            case remaining of
                [] ->
                    List.reverse built

                (Same count) :: rest ->
                    go rest (oldAt + count) (newAt + count) index budget (Equal { oldStart = oldAt, newStart = newAt, count = count } :: built)

                (Remove removedCount) :: (Insert addedCount) :: rest ->
                    let
                        ( found, spent ) =
                            hunk index oldAt newAt removedCount addedCount budget
                    in
                    go rest (oldAt + removedCount) (newAt + addedCount) (index + 1) (budget - spent) (Changed found :: built)

                (Remove removedCount) :: rest ->
                    let
                        ( found, spent ) =
                            hunk index oldAt newAt removedCount 0 budget
                    in
                    go rest (oldAt + removedCount) newAt (index + 1) (budget - spent) (Changed found :: built)

                (Insert addedCount) :: rest ->
                    let
                        ( found, spent ) =
                            hunk index oldAt newAt 0 addedCount budget
                    in
                    go rest oldAt (newAt + addedCount) (index + 1) (budget - spent) (Changed found :: built)

        hunk index oldAt newAt removedCount addedCount budget =
            let
                removedTexts =
                    texts old oldAt removedCount

                addedTexts =
                    texts new newAt addedCount

                ( paired, spent ) =
                    if removedCount > 0 && addedCount > 0 && removedCount <= mostPairs && addedCount <= mostPairs then
                        pairUp budget removedTexts addedTexts

                    else
                        ( [], 0 )
            in
            ( { index = index
              , oldStart = oldAt
              , newStart = newAt
              , removed =
                    changedLines (oldAt + 1) (Array.length old) oldMissingNewline removedTexts (List.map removedParts paired)
              , added =
                    changedLines (newAt + 1) (Array.length new) newMissingNewline addedTexts (List.map addedParts paired)
              }
            , spent
            )
    in
    go runs 0 0 0 inlineBudget []


{-| The first removed line is compared with the first added line, the second with
the second, and so on, each with what is left of the budget. A pair that comes
after the budget is spent is not compared: its lines are marked as a whole.
-}
pairUp : Int -> List String -> List String -> ( List (List Inline.Segment), Int )
pairUp budget removedTexts addedTexts =
    let
        step removedText addedText ( built, left ) =
            if left <= 0 then
                ( [ Inline.Replace removedText addedText ] :: built, left )

            else
                let
                    ( segments, spent ) =
                        Inline.diffWithin left removedText addedText
                in
                ( segments :: built, left - spent )

        ( reversed, remaining ) =
            List.foldl (\( removedText, addedText ) state -> step removedText addedText state)
                ( [], budget )
                (zip removedTexts addedTexts)
    in
    ( List.reverse reversed, budget - remaining )


zip : List a -> List b -> List ( a, b )
zip first second =
    List.map2 Tuple.pair first second


texts : Array String -> Int -> Int -> List String
texts lines from count =
    -- `Array.slice` copies what is left of the array: a lookup for each line is cheaper
    List.range from (from + count - 1)
        |> List.filterMap (\index -> Array.get index lines)


{-| The lines of one side of a hunk, with the pieces of those that were compared
with a line of the other side (the rest are one unchanged piece).
-}
changedLines : Int -> Int -> Bool -> List String -> List (List Part) -> List ChangedLine
changedLines firstNumber totalLines missingNewline lineTexts pairedParts =
    List.indexedMap
        (\offset lineText ->
            let
                number =
                    firstNumber + offset
            in
            { number = number
            , text = lineText
            , parts =
                case List.drop offset pairedParts |> List.head of
                    Just parts ->
                        parts

                    Nothing ->
                        [ { text = lineText, changed = False } ]
            , missingNewline = missingNewline && number == totalLines
            }
        )
        lineTexts


removedParts : List Inline.Segment -> List Part
removedParts segments =
    sidePieces
        (\segment ->
            case segment of
                Inline.Keep text ->
                    { text = text, changed = False }

                Inline.Replace removed _ ->
                    { text = removed, changed = True }
        )
        segments


addedParts : List Inline.Segment -> List Part
addedParts segments =
    sidePieces
        (\segment ->
            case segment of
                Inline.Keep text ->
                    { text = text, changed = False }

                Inline.Replace _ added ->
                    { text = added, changed = True }
        )
        segments


{-| The pieces of one side. A line with nothing in common with its partner is one
unchanged piece: the row is marked as a whole, so the text is not struck through
from end to end.
-}
sidePieces : (Inline.Segment -> Part) -> List Inline.Segment -> List Part
sidePieces toPart segments =
    case segments of
        [ Inline.Replace removed added ] ->
            [ { text = toPart (Inline.Replace removed added) |> .text, changed = False } ]

        _ ->
            segments
                |> List.map toPart
                |> List.filter (\part -> part.text /= "")


{-| A key for a hunk that stays the same for the same two texts and the same
options: where it starts and how many lines it has on each side.

    hunkKey hunk -- "12:3/14:2"

-}
hunkKey : Hunk -> String
hunkKey hunk =
    String.fromInt (hunk.oldStart + 1)
        ++ ":"
        ++ String.fromInt (List.length hunk.removed)
        ++ "/"
        ++ String.fromInt (hunk.newStart + 1)
        ++ ":"
        ++ String.fromInt (List.length hunk.added)
