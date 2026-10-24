module Klar.Internal.Choice exposing (groupId, inOptionOrder, setAll, toggle)

{-| What `Klar.Radio`, `Klar.SegmentedControl` and `Klar.CheckboxGroup` share: the
id of a group that was not given one, and the selection of a group of checkboxes.
Not exposed; the tests of the package read it. The values are the application's
own and are compared with `==`, so they must be plain data (no functions).
-}

import Klar.Internal as Internal


{-| An id made from the label and the texts of the options: `klar-<kind>-`, the label
as far as it can be written in an id (a label with no letter or digit that can, or no
label, reads `group`), and a number worked out from the label and every option text,
so that two groups with the same label and other options get different ids. Two
groups with the same label and the same option texts on one page get the same id:
give each an `id`.

    groupId "radio" (Just "Delivery") [ "Standard", "Express" ] -- klar-radio-delivery-<number>

-}
groupId : String -> Maybe String -> List String -> String
groupId kind label optionTexts =
    let
        text =
            Maybe.withDefault "" label

        readable =
            text
                |> String.toLower
                |> String.left 24
                |> Internal.sanitizeId
    in
    "klar-"
        ++ kind
        ++ "-"
        ++ (if String.all (\c -> c == '-' || c == '_') readable then
                "group"

            else
                readable
           )
        ++ "-"
        ++ String.fromInt (checksum (String.join "\n" (text :: optionTexts)))


{-| A small, stable number for a text. It reads every character, so it also tells
apart the texts that `sanitizeId` makes alike.
-}
checksum : String -> Int
checksum text =
    String.foldl (\char hash -> modBy 2147483629 (hash * 31 + Char.toCode char)) 7 text


{-| The selection after one box was checked or cleared, in the order of the options.
-}
toggle : List value -> List value -> value -> Bool -> List value
toggle optionValues current changed checked =
    let
        without =
            List.filter (\v -> v /= changed) current
    in
    inOptionOrder optionValues
        (if checked then
            without ++ [ changed ]

         else
            without
        )


{-| The selection after the select-all box was checked or cleared: every value that
can be changed goes in or out, the others stay as they were.
-}
setAll : List value -> List value -> List value -> Bool -> List value
setAll optionValues enabledValues current checked =
    let
        without =
            List.filter (\v -> not (List.member v enabledValues)) current
    in
    inOptionOrder optionValues
        (if checked then
            without ++ enabledValues

         else
            without
        )


{-| The values in the order of the options; a value that no option has stays, after
the others, and no value comes twice.
-}
inOptionOrder : List value -> List value -> List value
inOptionOrder optionValues values =
    unique
        (List.filter (\v -> List.member v values) optionValues
            ++ List.filter (\v -> not (List.member v optionValues)) values
        )


unique : List value -> List value
unique values =
    List.foldl
        (\v kept ->
            if List.member v kept then
                kept

            else
                v :: kept
        )
        []
        values
        |> List.reverse
