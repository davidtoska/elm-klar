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

When the texts are too different to compare in the given amount of work, the answer
is a summary of both texts instead (`TooLarge`), never a wrong or a late diff.

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


{-| Together the two texts may have this many lines; more are not compared line
by line.
-}
mostLines : Int
mostLines =
    200000


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

        oldKeys =
            keysOf options old

        newKeys =
            keysOf options new

        ( oldIds, newIds ) =
            identify oldKeys newKeys

        outcome =
            if Array.length old.lines + Array.length new.lines > mostLines then
                TooLarge (summarize oldKeys newKeys oldIds newIds)

            else
                case Myers.diff options.maxWork oldIds newIds of
                    Just runs ->
                        Done
                            { old = old.lines
                            , new = new.lines
                            , oldMissingNewline = oldMissingNewline
                            , newMissingNewline = newMissingNewline
                            , segments = toSegments old.lines new.lines oldMissingNewline newMissingNewline runs
                            }

                    Nothing ->
                        TooLarge (summarize oldKeys newKeys oldIds newIds)
    in
    { outcome = outcome
    , lineEndsDiffer = old.windowsLineEnds /= new.windowsLineEnds && Array.length old.lines > 0 && Array.length new.lines > 0
    }


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


summarize : Array ( String, Int ) -> Array ( String, Int ) -> Array Int -> Array Int -> Summary
summarize oldKeys newKeys oldIds newIds =
    let
        oldCount =
            Array.length oldIds

        newCount =
            Array.length newIds

        prefix =
            samePrefix oldIds newIds 0 (min oldCount newCount)

        suffix =
            sameSuffix oldIds newIds prefix 0

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


samePrefix : Array Int -> Array Int -> Int -> Int -> Int
samePrefix a b i limit =
    if i < limit && Array.get i a == Array.get i b then
        samePrefix a b (i + 1) limit

    else
        i


sameSuffix : Array Int -> Array Int -> Int -> Int -> Int
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


toSegments : Array String -> Array String -> Bool -> Bool -> List Run -> List Segment
toSegments old new oldMissingNewline newMissingNewline runs =
    let
        go remaining oldAt newAt index built =
            case remaining of
                [] ->
                    List.reverse built

                (Same count) :: rest ->
                    go rest (oldAt + count) (newAt + count) index (Equal { oldStart = oldAt, newStart = newAt, count = count } :: built)

                (Remove removedCount) :: (Insert addedCount) :: rest ->
                    go rest (oldAt + removedCount) (newAt + addedCount) (index + 1) (Changed (hunk index oldAt newAt removedCount addedCount) :: built)

                (Remove removedCount) :: rest ->
                    go rest (oldAt + removedCount) newAt (index + 1) (Changed (hunk index oldAt newAt removedCount 0) :: built)

                (Insert addedCount) :: rest ->
                    go rest oldAt (newAt + addedCount) (index + 1) (Changed (hunk index oldAt newAt 0 addedCount) :: built)

        hunk index oldAt newAt removedCount addedCount =
            let
                removedTexts =
                    texts old oldAt removedCount

                addedTexts =
                    texts new newAt addedCount

                paired =
                    List.map2 Inline.diff removedTexts addedTexts

                partsOf side pairs =
                    List.map side pairs
            in
            { index = index
            , oldStart = oldAt
            , newStart = newAt
            , removed =
                changedLines (oldAt + 1) (Array.length old) oldMissingNewline removedTexts (partsOf removedParts paired)
            , added =
                changedLines (newAt + 1) (Array.length new) newMissingNewline addedTexts (partsOf addedParts paired)
            }
    in
    go runs 0 0 0 []


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
