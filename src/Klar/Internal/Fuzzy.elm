module Klar.Internal.Fuzzy exposing (inOrder, window)

{-| The match of letters in order that `Klar.Search` and the select family share, so a
select and a search find the same texts: the letters of a word appear in this order,
within about twice their number.
-}


{-| Whether the letters appear in this order and reasonably close together
(within about twice their own length), so "brgn" finds "Bergen" but "aron"
does not find "Navigation and structure".
-}
inOrder : List String -> String -> Bool
inOrder letters haystack =
    window False letters haystack /= Nothing


{-| The positions of the letters in a place where they appear in order within
`2n + 2` characters (n letters): the first such place from the left, or with
`tightest` the narrowest one (for `highlight`, which shows the letters that make
the most sense). Every place where the first letter occurs is tried as a start, so
a close match further on is found when an earlier word holds the first letter
too: "brgn" finds "Bob's Bergen". A walk from a later start can only end later, so
a start from which the letters cannot all be found ends the search.
-}
window : Bool -> List String -> String -> Maybe (List Int)
window tightest letters haystack =
    case letters of
        first :: _ ->
            tryStarts
                { tightest = tightest, letters = letters, haystack = haystack, limit = 2 * List.length letters + 2 }
                (List.take maxStarts (String.indexes first haystack))
                Nothing

        [] ->
            Nothing


{-| How many places of the first letter are tried: enough for any label of a
list, and a limit for a long text full of one letter.
-}
maxStarts : Int
maxStarts =
    16


tryStarts :
    { tightest : Bool, letters : List String, haystack : String, limit : Int }
    -> List Int
    -> Maybe ( Int, List Int )
    -> Maybe (List Int)
tryStarts search starts best =
    case starts of
        [] ->
            Maybe.map Tuple.second best

        start :: later ->
            case walk search.letters search.haystack start [] of
                Just positions ->
                    let
                        width =
                            List.foldl (\position _ -> position) start positions - start + 1

                        narrower =
                            best |> Maybe.map (\( bestWidth, _ ) -> width < bestWidth) |> Maybe.withDefault True
                    in
                    if width <= search.limit && not search.tightest then
                        Just positions

                    else if width <= search.limit && narrower then
                        tryStarts search later (Just ( width, positions ))

                    else
                        tryStarts search later best

                Nothing ->
                    Maybe.map Tuple.second best


{-| Follows the letters through the text from `offset`, each at the first place
after the one before. Gives the position of every letter, in order.
-}
walk : List String -> String -> Int -> List Int -> Maybe (List Int)
walk letters haystack offset found =
    case letters of
        [] ->
            Just (List.reverse found)

        letter :: others ->
            case String.indexes letter (String.dropLeft offset haystack) of
                position :: _ ->
                    walk others haystack (offset + position + String.length letter) ((offset + position) :: found)

                [] ->
                    Nothing
