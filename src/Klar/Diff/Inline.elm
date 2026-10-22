module Klar.Diff.Inline exposing (Segment(..), addedText, diff, removedText, tokens)

{-| The difference between two pieces of text inside a line, by words.

Both texts are cut into tokens: runs of letters and digits, runs of white space,
and every other character on its own. The tokens are compared with the shortest
edit script ([Klar.Diff.Myers](Klar-Diff-Myers)). Where one long token was
replaced by another that is mostly the same (a changed digit in a number, a changed
letter in a name), the two are compared again character by character, so only the
characters that changed are marked.

Characters are whole code points: a character outside the Basic Multilingual Plane
(an emoji, written as two UTF-16 units) is never cut in the middle.

A text that is not worth comparing in detail (very long, or nothing but white
space in common) comes back as one replacement, and the caller marks the whole
line.

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


{-| The work that comparing the tokens or the characters of one pair of texts may
take.
-}
workBudget : Int
workBudget =
    120000


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
    if old == new then
        if old == "" then
            []

        else
            [ Keep old ]

    else if String.length old > longestText || String.length new > longestText then
        [ Replace old new ]

    else
        let
            oldTokens =
                tokens old

            newTokens =
                tokens new

            ( oldIds, newIds ) =
                identify oldTokens newTokens
        in
        case Myers.diff workBudget oldIds newIds of
            Nothing ->
                [ Replace old new ]

            Just runs ->
                fromRuns (Array.fromList oldTokens) (Array.fromList newTokens) runs
                    |> refine
                    |> joinAcrossSpace
                    |> joinKept
                    |> worthKeeping old new


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
refine : List Segment -> List Segment
refine segments =
    List.concatMap
        (\segment ->
            case segment of
                Replace removed added ->
                    if isWordToken removed && isWordToken added && worthComparingByCharacters removed added then
                        byCharacters removed added

                    else
                        [ segment ]

                Keep _ ->
                    [ segment ]
        )
        segments


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


isWordToken : String -> Bool
isWordToken text =
    case tokens text of
        [ single ] ->
            case String.toList single of
                first :: _ ->
                    classify first == Word

                [] ->
                    False

        _ ->
            False


charCount : String -> Int
charCount text =
    List.length (String.toList text)


{-| The characters of two tokens compared. The result is used when the tokens
have at least half of their characters in common and differ in one or two places
("1234" and "1284"); otherwise the whole token stays replaced, because marking
five scattered letters of a word is harder to read than marking the word.
-}
byCharacters : String -> String -> List Segment
byCharacters removed added =
    let
        removedChars =
            List.map String.fromChar (String.toList removed)

        addedChars =
            List.map String.fromChar (String.toList added)

        ( removedIds, addedIds ) =
            identify removedChars addedChars
    in
    case Myers.diff workBudget removedIds addedIds of
        Nothing ->
            [ Replace removed added ]

        Just runs ->
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
                segments

            else
                [ Replace removed added ]


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
