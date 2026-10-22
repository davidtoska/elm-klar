module Klar.Markdown.Utf16 exposing (isHighSurrogate, isLowSurrogate, left, repair)

{-| Text that is cut in the wrong place (`String.left 7` of a text with an emoji)
holds half of a character: the first half or the second half of a pair of code
units that have no meaning alone. A browser shows such a half as a replacement
character, but several functions of `elm/core` do not cope with one: `String.toList`
throws an exception on a text that starts with the second half, and `String.map`
puts the word `undefined` in the text after a first half at the end. An exception
in `view` ends a whole application, so the Markdown parser repairs its input first,
and the pure functions of the editor look at single code units with the functions
here, which do not iterate over characters.

The halves are found with `Json.Encode`: `JSON.stringify` writes a half that has no
partner as `\ud83d`, and nothing else is written that way.

-}

import Json.Decode as Decode
import Json.Encode as Encode


{-| Is this one code unit the first half of a pair (U+D800 to U+DBFF)?
-}
isHighSurrogate : String -> Bool
isHighSurrogate unit =
    case halfOf unit of
        Just digit ->
            digit == '8' || digit == '9' || digit == 'a' || digit == 'b'

        Nothing ->
            False


{-| Is this one code unit the second half of a pair (U+DC00 to U+DFFF)?
-}
isLowSurrogate : String -> Bool
isLowSurrogate unit =
    case halfOf unit of
        Just digit ->
            digit == 'c' || digit == 'd' || digit == 'e' || digit == 'f'

        Nothing ->
            False


{-| The third digit of the code of a single code unit that has no partner, as
`JSON.stringify` writes it: `\ud83d` gives `'8'`.
-}
halfOf : String -> Maybe Char
halfOf unit =
    if String.length unit /= 1 then
        Nothing

    else
        let
            encoded =
                Encode.encode 0 (Encode.string unit)
        in
        if String.startsWith "\"\\ud" encoded then
            encoded |> String.dropLeft 4 |> String.left 1 |> String.toList |> List.head

        else
            Nothing


{-| The first `n` code units of a text, but not the first half of a character that
takes two: cutting a text with `String.left` can leave half of an emoji, and that
half is not valid text. Use this wherever a text is cut to a length.
-}
left : Int -> String -> String
left n text =
    let
        head =
            String.left n text
    in
    if isHighSurrogate (String.right 1 head) then
        String.dropRight 1 head

    else
        head


{-| The text with every half that has no partner replaced by U+FFFD, and a first
half at the very end taken away: the rest of a character that is still arriving.
-}
repair : String -> String
repair text =
    let
        encoded =
            Encode.encode 0 (Encode.string text)
    in
    if String.contains "\\ud" encoded then
        -- `\\` is a backslash in the text; what is left of `\ud` after that is a half
        let
            pieces =
                String.split "\\\\" encoded

            lastIndex =
                List.length pieces - 1

            fixed =
                List.indexedMap (\index piece -> repairPiece (index == lastIndex) piece) pieces
        in
        Decode.decodeString Decode.string (String.join "\\\\" fixed)
            |> Result.withDefault ""

    else
        text


repairPiece : Bool -> String -> String
repairPiece isLast piece =
    case String.split "\\ud" piece of
        [] ->
            piece

        head :: tails ->
            let
                count =
                    List.length tails
            in
            head
                ++ String.concat
                    (List.indexedMap
                        (\index tail ->
                            let
                                digit =
                                    String.left 1 tail

                                rest =
                                    String.dropLeft 3 tail
                            in
                            -- a first half just before the closing quote of the text
                            if isLast && index == count - 1 && rest == "\"" && (digit == "8" || digit == "9" || digit == "a" || digit == "b") then
                                "\""

                            else
                                "\\ufffd" ++ rest
                        )
                        tails
                    )
