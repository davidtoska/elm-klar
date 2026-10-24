module Klar.ToggleGroup.Ids exposing (groupId)

{-| The DOM id of a toggle group that was not given one. Not exposed; `Klar.ToggleGroup`
uses it, and the tests of the package read it.
-}

import Klar.Internal as Internal


{-| An id made from the label and the texts of the options. The first part is the
first 24 characters of the label in lowercase, written as an id (`Internal.sanitizeId`:
letters, digits and `-` as they are, a space as `__`, any other character as its
code), so the id says what the group is. A label of dashes only, or no label, reads
`group` instead, and a number worked out from the whole text (the label and every
option) follows, so that labels which start alike still give different ids, and so
do two groups with the same label and other options. Two groups with the same label
and the same options on one page get the same id: give each an `id`.

    groupId "Order status" [ "Open", "Shipped" ] -- starts with klar-toggle-order__status- and ends with a number

-}
groupId : String -> List String -> String
groupId label optionTexts =
    let
        readable =
            label
                |> String.toLower
                |> String.left 24
                |> Internal.sanitizeId
    in
    "klar-toggle-"
        ++ (if String.all (\c -> c == '-' || c == '_') readable then
                "group"

            else
                readable
           )
        ++ "-"
        ++ String.fromInt (checksum (String.join "\n" (label :: optionTexts)))


{-| A small, stable number for a text (two different texts are not likely to get the
same one). It reads every character, so it also tells apart the texts whose first 24
characters are alike.
-}
checksum : String -> Int
checksum text =
    String.foldl (\char hash -> modBy 2147483629 (hash * 31 + Char.toCode char)) 7 text
