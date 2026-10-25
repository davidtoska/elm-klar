module Klar.Table.Identity exposing (idsOf, isJust, keysBetween, keysOf, lookup, toggled)

{-| Row identity, key ranges and small value lookups shared by the table family.
-}

import Klar.Ids as Ids exposing (Ids)
import Set exposing (Set)


idsOf : Ids id -> Set String -> List id
idsOf ids keys =
    List.filterMap (Ids.fromKey ids) (Set.toList keys)


keysOf : Ids id -> List id -> List String
keysOf ids =
    List.map (Ids.toKey ids)


toggled : String -> Set String -> Set String
toggled key set =
    if Set.member key set then
        Set.remove key set

    else
        Set.insert key set


{-| Never compare a `Maybe` of a function with `==`; use this.
-}
isJust : Maybe a -> Bool
isJust maybe =
    case maybe of
        Just _ ->
            True

        Nothing ->
            False


lookup : String -> List ( String, a ) -> Maybe a
lookup key pairs =
    case pairs of
        [] ->
            Nothing

        ( k, v ) :: rest ->
            if k == key then
                Just v

            else
                lookup key rest


{-| The keys from one key to the other, both included, in the order of the list;
`Nothing` when one of them is not in it (the anchor is on another page).
-}
keysBetween : String -> String -> List String -> Maybe (List String)
keysBetween from to keys =
    let
        place key =
            keys
                |> List.indexedMap Tuple.pair
                |> List.filter (\( _, k ) -> k == key)
                |> List.head
                |> Maybe.map Tuple.first
    in
    case ( place from, place to ) of
        ( Just a, Just b ) ->
            Just (keys |> List.drop (min a b) |> List.take (abs (a - b) + 1))

        _ ->
            Nothing
