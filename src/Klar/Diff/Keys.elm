module Klar.Diff.Keys exposing (unique)

{-| Keys that are different for every item, for the nodes of a `Html.Keyed` list
and for the identity of a change.

Two items can have the same key by mistake in the data (two records with the same
id, two fields with the same label). The first keeps its key and the next ones get
a number after it. A key that was made this way can be the same as the key of
another item (`"a"`, `"a"` and `"a~2"`), so every key that is given out is
remembered and a number that is taken is skipped. That makes every key different,
whatever the keys look like.

-}

import Dict exposing (Dict)
import Set exposing (Set)


{-| The keys, made different. The function writes the key of the second, the third
and so on item that has the same key: `\key n -> key ++ "~" ++ String.fromInt n`.
Keys that are different already are not changed, and the first item with a key
always keeps it, unless an earlier item got that key by being a repeat.

    unique suffix [ "a", "b", "a" ] -- [ "a", "b", "a~2" ]

    unique suffix [ "a", "a", "a~2" ] -- [ "a", "a~2", "a~2~2" ]

The work is one lookup for each key, and one more for each number that is skipped.

-}
unique : (String -> Int -> String) -> List String -> List String
unique suffix keys =
    let
        step key ( built, taken, next ) =
            let
                ( chosen, number ) =
                    choose suffix key (Dict.get key next |> Maybe.withDefault 1) taken
            in
            ( chosen :: built, Set.insert chosen taken, Dict.insert key (number + 1) next )

        ( reversed, _, _ ) =
            List.foldl step ( [], Set.empty, Dict.empty ) keys
    in
    List.reverse reversed


{-| The first number from `number` on whose key is not taken.
-}
choose : (String -> Int -> String) -> String -> Int -> Set String -> ( String, Int )
choose suffix key number taken =
    let
        candidate =
            if number <= 1 then
                key

            else
                suffix key number
    in
    if Set.member candidate taken then
        choose suffix key (number + 1) taken

    else
        ( candidate, number )
