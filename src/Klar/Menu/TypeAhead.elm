module Klar.Menu.TypeAhead exposing (find)

{-| Typing in an open menu: the item whose label starts with the letters typed.

Not meant for application code.

-}

import Klar.Internal as Internal


{-| The index of the item to highlight, given the letters typed so far, the
highlighted index (`-1` for none) and the items that can be picked with their
labels, in order. Case and accents do not count ("e" finds "Édit").

  - One letter, or the same letter again and again ("d", "dd"), moves to the
    next item that starts with it, after the highlighted one, and wraps around:
    pressing "d" twice goes from "Duplicate" to "Delete".
  - Several letters ("du") find the first item that starts with them, from the
    highlighted one on, so the highlight stays where it is while it still matches.

`Nothing` when no item matches; the highlight then stays where it was.

-}
find : { typed : String, from : Int } -> List ( Int, String ) -> Maybe Int
find { typed, from } labelled =
    let
        wanted =
            Internal.normalize typed

        ( prefix, after ) =
            case String.toList wanted of
                first :: rest ->
                    if List.all (\char -> char == first) rest then
                        ( String.fromChar first, True )

                    else
                        ( wanted, False )

                [] ->
                    ( "", False )

        startsHere ( index, _ ) =
            if after then
                index > from

            else
                index >= from

        ordered =
            List.filter startsHere labelled ++ List.filter (not << startsHere) labelled
    in
    if prefix == "" then
        Nothing

    else
        ordered
            |> List.filter (\( _, text ) -> String.startsWith prefix (Internal.normalize (String.trimLeft text)))
            |> List.head
            |> Maybe.map Tuple.first
