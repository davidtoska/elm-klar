module Klar.Diff.Inline exposing (Segment(..), addedText, clusters, diff, diffWithin, pairBudget, removedText, tokens)

{-| The difference between two pieces of text inside a line, by words.

Both texts are cut into tokens: runs of letters and digits, runs of white space,
and every other character on its own. The tokens are compared with the shortest
edit script ([Klar.Diff.Myers](Klar-Diff-Myers)). Where one long token was
replaced by another that is mostly the same (a changed digit in a number, a changed
letter in a name), the two are compared again character by character, so only the
characters that changed are marked.

Characters are whole code points: a character outside the Basic Multilingual Plane
(an emoji, written as two UTF-16 units) is never cut in the middle. Neither is a
letter cut from the accent or the mark that follows it (`e` and U+0301, an emoji
and its skin tone or its variation selector, the parts of a joined emoji).

A text that is not worth comparing in detail (very long, or nothing but white
space in common) comes back as one replacement, and the caller marks the whole
line.

The work is limited twice: each pair of texts has a budget of its own
(`pairBudget`), and a caller that compares many pairs gives each the part of a
shared budget that is left (`diffWithin`) and is told how much was used.

-}

import Array exposing (Array)
import Dict exposing (Dict)
import Klar.Diff.Myers as Myers exposing (Run(..))


{-| A stretch of the two texts: text that is the same in both, or text that was
replaced (the old text and the new text, either of which may be empty).
-}
type Segment
    = Keep String
    | Replace String String


{-| The most characters a text may have to be compared in detail.
-}
longestText : Int
longestText =
    4000


{-| The work that comparing one pair of texts may take: the same unit as the work
of `Klar.Diff.Myers` (a diagonal looked at, a pair of elements compared), and one
unit more for every character that is cut into tokens.
-}
pairBudget : Int
pairBudget =
    120000


{-| What cutting a text into tokens (and, for a long word, into characters) costs
for each character, in the unit of the edit script.
-}
characterCost : Int
characterCost =
    4


{-| A token is long enough for a comparison by characters when it has at least
this many characters, and has a digit in it (a number, an order number, a code) or is
very long. Two words of ordinary length are marked as a whole: "widget" and "gadget"
differ in "wi" and "ga", which no one reads as a change of a word.
-}
longToken : Int
longToken =
    4


veryLongToken : Int
veryLongToken =
    16


{-| The segments that turn the old text into the new one. Putting the old texts
of all segments together gives the old text, and the new texts the new one.
-}
diff : String -> String -> List Segment
diff old new =
    Tuple.first (diffWithin pairBudget old new)


{-| Like `diff`, with at most that much work (and never more than `pairBudget`),
and with the work that was done, so that the caller can take it from a budget it
shares between many pairs. A pair that does not fit in the budget comes back as
one replacement and costs nothing.
-}
diffWithin : Int -> String -> String -> ( List Segment, Int )
diffWithin budget old new =
    if old == new then
        if old == "" then
            ( [], 0 )

        else
            ( [ Keep old ], 0 )

    else if String.length old > longestText || String.length new > longestText then
        ( [ Replace old new ], 0 )

    else
        let
            allowed =
                min pairBudget budget

            tokenWork =
                characterCost * (String.length old + String.length new)
        in
        if tokenWork > allowed then
            ( [ Replace old new ], 0 )

        else
            let
                oldTokens =
                    tokens old

                newTokens =
                    tokens new

                ( oldIds, newIds ) =
                    identify oldTokens newTokens

                ( script, scriptWork ) =
                    Myers.diffCounted (allowed - tokenWork) oldIds newIds
            in
            case script of
                Nothing ->
                    ( [ Replace old new ], tokenWork + scriptWork )

                Just runs ->
                    let
                        ( refined, refineWork ) =
                            fromRuns (Array.fromList oldTokens) (Array.fromList newTokens) runs
                                |> refine (allowed - tokenWork - scriptWork)
                    in
                    ( refined
                        |> joinAcrossSpace
                        |> joinKept
                        |> worthKeeping old new
                    , tokenWork + scriptWork + refineWork
                    )


{-| The text of the old side.
-}
removedText : List Segment -> String
removedText segments =
    String.concat
        (List.map
            (\segment ->
                case segment of
                    Keep text ->
                        text

                    Replace removed _ ->
                        removed
            )
            segments
        )


{-| The text of the new side.
-}
addedText : List Segment -> String
addedText segments =
    String.concat
        (List.map
            (\segment ->
                case segment of
                    Keep text ->
                        text

                    Replace _ added ->
                        added
            )
            segments
        )



-- TOKENS


type CharClass
    = Space
    | Word
    | Punctuation


{-| Runs of letters and digits, runs of white space, and each other character on
its own. Putting the tokens together gives the text again.

    tokens "Total: 12.50" -- [ "Total", ":", " ", "12", ".", "50" ]

-}
tokens : String -> List String
tokens text =
    let
        step char ( finished, current, currentClass ) =
            let
                class =
                    classify char
            in
            case ( currentClass, class ) of
                ( Just Space, Space ) ->
                    ( finished, String.fromChar char :: current, currentClass )

                ( Just Word, Word ) ->
                    ( finished, String.fromChar char :: current, currentClass )

                _ ->
                    ( closeToken current finished, [ String.fromChar char ], Just class )

        ( done, last, _ ) =
            List.foldl step ( [], [], Nothing ) (String.toList text)
    in
    List.reverse (closeToken last done)


closeToken : List String -> List String -> List String
closeToken reversedPieces finished =
    case reversedPieces of
        [] ->
            finished

        _ ->
            String.concat (List.reverse reversedPieces) :: finished


classify : Char -> CharClass
classify char =
    let
        code =
            Char.toCode char
    in
    if char == ' ' || char == '\t' || char == '\n' || char == '\u{000D}' then
        Space

    else if code < 128 then
        if (code >= 48 && code <= 57) || (code >= 65 && code <= 90) || (code >= 97 && code <= 122) || code == 95 then
            Word

        else
            Punctuation

    else if code == 0xA0 || (code >= 0x2000 && code <= 0x200A) || code == 0x3000 || code == 0x2028 || code == 0x2029 then
        Space

    else if isOtherPunctuation code then
        Punctuation

    else
        Word


{-| Punctuation and symbols outside ASCII that are not letters: the Latin-1
punctuation, the general punctuation block and the punctuation of CJK text.
-}
isOtherPunctuation : Int -> Bool
isOtherPunctuation code =
    (code >= 0xA1 && code <= 0xBF && code /= 0xAA && code /= 0xB5 && code /= 0xBA)
        || code
        == 0xD7
        || code
        == 0xF7
        || (code >= 0x2010 && code <= 0x2027)
        || (code >= 0x2030 && code <= 0x205E)
        || (code >= 0x3001 && code <= 0x3003)
        || (code >= 0x3008 && code <= 0x3011)


{-| An integer for each distinct token, the same in both lists.
-}
identify : List String -> List String -> ( Array Int, Array Int )
identify first second =
    let
        -- `Dict.size` walks the whole dictionary: the next id is counted instead
        assign token ( ids, known, next ) =
            case Dict.get token known of
                Just id ->
                    ( id :: ids, known, next )

                Nothing ->
                    ( next :: ids, Dict.insert token next known, next + 1 )

        ( firstIds, firstKnown, firstNext ) =
            List.foldl assign ( [], Dict.empty, 0 ) first

        ( secondIds, _, _ ) =
            List.foldl assign ( [], firstKnown, firstNext ) second
    in
    ( Array.fromList (List.reverse firstIds), Array.fromList (List.reverse secondIds) )



-- FROM RUNS TO SEGMENTS


fromRuns : Array String -> Array String -> List Run -> List Segment
fromRuns old new runs =
    let
        slice array from count =
            String.concat (Array.toList (Array.slice from (from + count) array))

        step run ( oldAt, newAt, built ) =
            case run of
                Same count ->
                    ( oldAt + count, newAt + count, Keep (slice old oldAt count) :: built )

                Remove count ->
                    ( oldAt + count, newAt, Replace (slice old oldAt count) "" :: built )

                Insert count ->
                    ( oldAt, newAt + count, Replace "" (slice new newAt count) :: built )

        ( _, _, segments ) =
            List.foldl step ( 0, 0, [] ) runs
    in
    mergeReplacements (List.reverse segments)


{-| A removal followed by an insertion is one replacement.
-}
mergeReplacements : List Segment -> List Segment
mergeReplacements segments =
    case segments of
        (Replace removed "") :: (Replace "" added) :: rest ->
            mergeReplacements (Replace removed added :: rest)

        first :: rest ->
            first :: mergeReplacements rest

        [] ->
            []



-- CHARACTERS


{-| Replacements of one long token by another that is mostly the same are
compared again, character by character.
-}
refine : Int -> List Segment -> ( List Segment, Int )
refine budget segments =
    let
        step segment ( built, spent ) =
            case segment of
                Replace removed added ->
                    if isWordToken removed && isWordToken added && worthComparingByCharacters removed added then
                        let
                            ( found, work ) =
                                byCharacters (budget - spent) removed added
                        in
                        ( List.reverse found ++ built, spent + work )

                    else
                        ( segment :: built, spent )

                Keep _ ->
                    ( segment :: built, spent )

        ( reversed, total ) =
            List.foldl step ( [], 0 ) segments
    in
    ( List.reverse reversed, total )


worthComparingByCharacters : String -> String -> Bool
worthComparingByCharacters removed added =
    let
        removedLength =
            charCount removed

        addedLength =
            charCount added
    in
    removedLength
        >= longToken
        && addedLength
        >= longToken
        && (String.any Char.isDigit removed
                || String.any Char.isDigit added
                || (removedLength >= veryLongToken && addedLength >= veryLongToken)
           )


{-| Is the text one token of letters and digits?
-}
isWordToken : String -> Bool
isWordToken text =
    text /= "" && String.all (\char -> classify char == Word) text


{-| The number of characters as a person counts them: a letter with its accent is
one.
-}
charCount : String -> Int
charCount text =
    List.length (clusters text)


{-| The characters of a text, each with the marks that belong to it: a letter and
the accents after it, an emoji and its skin tone, its variation selector and the
emoji joined to it with a zero width joiner. Putting the clusters together gives the
text again.

    clusters "Ame\u{0301}lie" -- [ "A", "m", "e\u{0301}", "l", "i", "e" ]

-}
clusters : String -> List String
clusters text =
    let
        step char ( finished, current, previousJoins ) =
            if current /= [] && (previousJoins || extendsCluster char) then
                ( finished, String.fromChar char :: current, Char.toCode char == 0x200D )

            else
                ( closeToken current finished, [ String.fromChar char ], Char.toCode char == 0x200D )

        ( done, last, _ ) =
            List.foldl step ( [], [], False ) (String.toList text)
    in
    List.reverse (closeToken last done)


{-| Combining marks and the like: the accents, the marks of the Cyrillic, Hebrew,
Arabic, Devanagari and Thai scripts, the joiners, the variation selectors and the skin
tones of emoji. Marks of scripts that are not listed are cut from their letter, which
only makes the marked part a character longer or shorter.
-}
extendsCluster : Char -> Bool
extendsCluster char =
    let
        code =
            Char.toCode char
    in
    if code < 0x0300 then
        False

    else
        (code <= 0x036F)
            || (code >= 0x0483 && code <= 0x0489)
            || (code >= 0x0591 && code <= 0x05BD)
            || code == 0x05BF
            || code == 0x05C1
            || code == 0x05C2
            || code == 0x05C4
            || code == 0x05C5
            || code == 0x05C7
            || (code >= 0x0610 && code <= 0x061A)
            || (code >= 0x064B && code <= 0x065F)
            || code == 0x0670
            || (code >= 0x06D6 && code <= 0x06DC)
            || (code >= 0x06DF && code <= 0x06E4)
            || code == 0x06E7
            || code == 0x06E8
            || (code >= 0x06EA && code <= 0x06ED)
            || (code >= 0x0900 && code <= 0x0903)
            || (code >= 0x093A && code <= 0x093C)
            || (code >= 0x093E && code <= 0x094F)
            || (code >= 0x0951 && code <= 0x0957)
            || code == 0x0962
            || code == 0x0963
            || code == 0x0E31
            || (code >= 0x0E34 && code <= 0x0E3A)
            || (code >= 0x0E47 && code <= 0x0E4E)
            || (code >= 0x1AB0 && code <= 0x1AFF)
            || (code >= 0x1DC0 && code <= 0x1DFF)
            || code == 0x200C
            || code == 0x200D
            || (code >= 0x20D0 && code <= 0x20FF)
            || (code >= 0xFE00 && code <= 0xFE0F)
            || (code >= 0xFE20 && code <= 0xFE2F)
            || (code >= 0x1F3FB && code <= 0x1F3FF)
            || (code >= 0xE0100 && code <= 0xE01EF)


{-| The characters of two tokens compared. The result is used when the tokens
have at least half of their characters in common and differ in one or two places
("1234" and "1284"); otherwise the whole token stays replaced, because marking
five scattered letters of a word is harder to read than marking the word.
-}
byCharacters : Int -> String -> String -> ( List Segment, Int )
byCharacters budget removed added =
    let
        tokenWork =
            characterCost * (String.length removed + String.length added)
    in
    if tokenWork > budget then
        ( [ Replace removed added ], 0 )

    else
        let
            removedChars =
                clusters removed

            addedChars =
                clusters added

            ( removedIds, addedIds ) =
                identify removedChars addedChars
        in
        case Myers.diffCounted (min pairBudget (budget - tokenWork)) removedIds addedIds of
            ( Nothing, work ) ->
                ( [ Replace removed added ], tokenWork + work )

            ( Just runs, work ) ->
                let
                    segments =
                        fromRuns (Array.fromList removedChars) (Array.fromList addedChars) runs
                            |> absorbSingleCharacters

                    replacements =
                        List.length (List.filter isReplacement segments)

                    common =
                        List.sum
                            (List.map
                                (\segment ->
                                    case segment of
                                        Keep text ->
                                            charCount text

                                        Replace _ _ ->
                                            0
                                )
                                segments
                            )
                in
                if 4 * common >= charCount removed + charCount added && replacements <= 2 then
                    ( segments, tokenWork + work )

                else
                    ( [ Replace removed added ], tokenWork + work )


{-| One character that is the same between two replacements is not worth a
break: "Shipping" and "Shipment" differ in "ping" and "ment", not in "pi", "n" and
"g".
-}
absorbSingleCharacters : List Segment -> List Segment
absorbSingleCharacters segments =
    case segments of
        (Replace removedA addedA) :: (Keep between) :: (Replace removedB addedB) :: rest ->
            if charCount between == 1 then
                absorbSingleCharacters (Replace (removedA ++ between ++ removedB) (addedA ++ between ++ addedB) :: rest)

            else
                Replace removedA addedA :: absorbSingleCharacters (Keep between :: Replace removedB addedB :: rest)

        first :: rest ->
            first :: absorbSingleCharacters rest

        [] ->
            []


isReplacement : Segment -> Bool
isReplacement segment =
    case segment of
        Keep _ ->
            False

        Replace _ _ ->
            True



-- TIDYING


{-| White space between two replacements joins them: "foo bar" becoming "baz
qux" is one replacement, not two with a space between.
-}
joinAcrossSpace : List Segment -> List Segment
joinAcrossSpace segments =
    case segments of
        (Replace removedA addedA) :: (Keep between) :: (Replace removedB addedB) :: rest ->
            if isBlank between then
                joinAcrossSpace (Replace (removedA ++ between ++ removedB) (addedA ++ between ++ addedB) :: rest)

            else
                Replace removedA addedA :: joinAcrossSpace (Keep between :: Replace removedB addedB :: rest)

        first :: rest ->
            first :: joinAcrossSpace rest

        [] ->
            []


{-| Text that is the same and follows text that is the same is one segment.
-}
joinKept : List Segment -> List Segment
joinKept segments =
    case segments of
        (Keep first) :: (Keep second) :: rest ->
            joinKept (Keep (first ++ second) :: rest)

        first :: rest ->
            first :: joinKept rest

        [] ->
            []


isBlank : String -> Bool
isBlank text =
    String.all (\char -> classify char == Space) text


{-| When nothing but white space is in common, the two texts are different texts
and the whole of each is marked, not a scatter of pieces.
-}
worthKeeping : String -> String -> List Segment -> List Segment
worthKeeping old new segments =
    let
        sharesSomething =
            List.any
                (\segment ->
                    case segment of
                        Keep text ->
                            not (isBlank text)

                        Replace _ _ ->
                            False
                )
                segments
    in
    if sharesSomething then
        segments

    else
        [ Replace old new ]
