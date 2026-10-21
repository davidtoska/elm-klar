module Klar.Search exposing
    ( filter, rank
    , score, matches, highlight
    , Prepared, Query, prepare, prepareMany, query, scorePrepared
    , normalize
    )

{-| Text matching for search fields, selects and command palettes: forgiving
about case and accents, and ranked, so the best match comes first.

Matching ignores case and diacritics (`ø` matches `o`, `é` matches `e`), and
treats a query as several words that must all match somewhere:
`"ada london"` finds "Ada Lovelace, London".

    import Klar.Search as Search

    Search.score "ada" "Ada Lovelace" -- Just 1  (lower is better)

    Search.score "xyz" "Ada Lovelace" -- Nothing

    Search.filter .name "ada" customers -- matching items, best first

    Search.highlight "ada" "Ada Lovelace" -- the text, with <mark> around "Ada"

A smaller score is a better match:

  - `0` the text is the query
  - `1` the text starts with the query
  - `2` a word in the text starts with the query
  - `3` the query is somewhere inside the text
  - `6` the letters of the query appear in order and close together (a typo-tolerant
    match, only for words of three letters or more)

For long lists this is fast because the texts are normalized in one go (`filter` and
`rank` do that for you). If you search the same texts again and again, prepare them
once and keep the result:

    prepared =
        Search.prepareMany (List.map .name customers)

    q =
        Search.query "ada"

    List.map (Search.scorePrepared q) prepared


# Searching a list

@docs filter, rank


# Scoring one text

@docs score, matches, highlight


# Preparing texts and queries

@docs Prepared, Query, prepare, prepareMany, query, scorePrepared


# Normalizing

@docs normalize

-}

import Html exposing (Html)
import Klar.Internal as Internal



-- NORMALIZING


{-| Lowercases a text and strips diacritics: `"Ørsted"` becomes `"orsted"`, `"Škoda"`
becomes `"skoda"` and `"Łódź"` becomes `"lodz"`. The letters of the Latin-1 and Latin
Extended-A blocks are covered; Norwegian "æ" becomes "a" and "ø" "o". The result
has as many characters as the input, so a match position in the normalized text is
the same position in the original. Useful for sorting and comparing texts the way
the search does.
-}
normalize : String -> String
normalize text =
    Internal.normalize text


{-| Word separators turned into spaces, so "a word starts with" is a plain
substring test.
-}
separatorsToSpaces : String -> String
separatorsToSpaces text =
    List.foldl
        (\mark current ->
            if String.contains mark current then
                String.replace mark " " current

            else
                current
        )
        text
        [ "-", "/", "\t", "\n", "\u{000D}", "\u{00A0}" ]



-- PREPARED TEXT AND QUERIES


{-| A text prepared for matching with `scorePrepared`. Make one with `prepare`
or `prepareMany` and keep it as long as the text does not change.
-}
type Prepared
    = Prepared
        { text : String
        , words : String
        }


type alias Word =
    { text : String
    , spaced : String
    , letters : List String
    , fuzzy : Bool
    }


{-| A query, split into words once. Make one with `query`.
-}
type Query
    = Query (List Word)


{-| Prepares one text for matching.
-}
prepare : String -> Prepared
prepare text =
    let
        normalized =
            normalize text
    in
    Prepared { text = normalized, words = " " ++ separatorsToSpaces normalized }


{-| Prepares many texts at once. All texts are joined, normalized in one go
and split again, which is much faster than normalizing thousands of short
strings one by one. The result has one entry for every text, in the same order.
-}
prepareMany : List String -> List Prepared
prepareMany texts =
    let
        count =
            List.length texts

        joined =
            normalize (String.join separator texts)

        parts =
            String.split separator joined

        wordParts =
            String.split separator (separatorsToSpaces joined)
    in
    if count > 0 && List.length parts == count && List.length wordParts == count then
        List.map2 (\text words -> Prepared { text = text, words = " " ++ words }) parts wordParts

    else
        List.map prepare texts


{-| A control character that does not occur in normal text and is not changed
by lowercasing.
-}
separator : String
separator =
    "\u{0001}"


{-| Splits what the user typed into words, to be scored against many texts. An
empty query has no words and matches every text.
-}
query : String -> Query
query text =
    normalize text
        |> String.words
        |> List.filter (\word -> word /= "")
        |> List.map
            (\word ->
                { text = word
                , spaced = " " ++ word
                , letters = String.split "" word
                , fuzzy = String.length word >= 3
                }
            )
        |> Query



-- SCORING


{-| How well `text` matches `queryText`: `Nothing` if it does not, otherwise a
score where lower is better (see the list at the top of this page). An empty
query matches everything with 0. With several words in the query the scores of
the words are added, and every word has to match.

    Search.score "ada" "Ada Lovelace" -- Just 1

    Search.score "lovelace" "Ada Lovelace" -- Just 2

    Search.score "ada lovelace" "Ada Lovelace" -- Just 3

    Search.score "lvlc" "Ada Lovelace" -- Just 6

-}
score : String -> String -> Maybe Int
score queryText text =
    scorePrepared (query queryText) (prepare text)


{-| Like `score`, for a query and a text that are prepared already.
-}
scorePrepared : Query -> Prepared -> Maybe Int
scorePrepared (Query words) prepared =
    scoreWords words prepared 0


scoreWords : List Word -> Prepared -> Int -> Maybe Int
scoreWords words prepared total =
    case words of
        [] ->
            Just total

        word :: rest ->
            case scoreWord word prepared of
                Just points ->
                    scoreWords rest prepared (total + points)

                Nothing ->
                    Nothing


scoreWord : Word -> Prepared -> Maybe Int
scoreWord word (Prepared prepared) =
    if prepared.text == word.text then
        Just 0

    else if String.startsWith word.text prepared.text then
        Just 1

    else if String.contains word.spaced prepared.words then
        Just 2

    else if String.contains word.text prepared.text then
        Just 3

    else if word.fuzzy && inOrder word.letters prepared.text then
        Just 6

    else
        Nothing


{-| Whether the letters appear in this order and reasonably close together
(within about twice their own length), so "brgn" finds "Bergen" but "aron"
does not find "Navigation and structure".
-}
inOrder : List String -> String -> Bool
inOrder letters haystack =
    case walk letters haystack 0 Nothing of
        Just ( first, last ) ->
            last - first + 1 <= 2 * List.length letters + 2

        Nothing ->
            False


{-| Follows the letters through the text, from the left. Gives the positions
of the first and last letter found.
-}
walk : List String -> String -> Int -> Maybe Int -> Maybe ( Int, Int )
walk letters rest offset first =
    case letters of
        [] ->
            Maybe.map (\start -> ( start, offset - 1 )) first

        letter :: others ->
            case String.indexes letter rest of
                position :: _ ->
                    let
                        absolute =
                            offset + position

                        consumed =
                            position + String.length letter
                    in
                    walk others
                        (String.dropLeft consumed rest)
                        (offset + consumed)
                        (Just (Maybe.withDefault absolute first))

                [] ->
                    Nothing


{-| Whether the text matches the query at all.

    Search.matches "ber" "Bergen" -- True

-}
matches : String -> String -> Bool
matches queryText text =
    score queryText text /= Nothing


{-| Keeps the items that match, best matches first. Items with equal scores
keep their original order. A query that is empty or only spaces returns the
list unchanged.

    Search.filter identity "ber" [ "Åsberg", "Oslo", "Bergen" ] -- [ "Bergen", "Åsberg" ]

-}
filter : (a -> String) -> String -> List a -> List a
filter toText queryText items =
    if String.isEmpty (String.trim queryText) then
        items

    else
        rank toText queryText items |> List.map Tuple.second


{-| Like `filter`, but keeps the scores: `( score, item )`, best first.
-}
rank : (a -> String) -> String -> List a -> List ( Int, a )
rank toText queryText items =
    let
        words =
            query queryText

        prepared =
            prepareMany (List.map toText items)
    in
    List.map2 Tuple.pair items prepared
        |> List.filterMap
            (\( item, text ) ->
                scorePrepared words text
                    |> Maybe.map (\points -> ( points, item ))
            )
        |> List.sortBy Tuple.first



-- HIGHLIGHTING


{-| Splits `text` into plain parts and highlighted parts (`<mark>` elements) at
every place a word of the query occurs, to show why a result matched. Matching
is done on the normalized text, so `"orsted"` highlights "Ørsted".

    Search.highlight "ber" "Bergen" -- "Ber" in a <mark>, then "gen"

-}
highlight : String -> String -> List (Html msg)
highlight queryText text =
    case query queryText of
        Query [] ->
            [ Html.text text ]

        Query words ->
            let
                haystack =
                    normalize text

                ranges =
                    words
                        |> List.filterMap
                            (\word ->
                                firstIndex word.text haystack
                                    |> Maybe.map (\start -> ( start, start + String.length word.text ))
                            )
                        |> mergeRanges
            in
            splitByRanges text ranges


firstIndex : String -> String -> Maybe Int
firstIndex needle haystack =
    case String.indexes needle haystack of
        first :: _ ->
            Just first

        [] ->
            Nothing


mergeRanges : List ( Int, Int ) -> List ( Int, Int )
mergeRanges ranges =
    ranges
        |> List.sortBy Tuple.first
        |> List.foldl
            (\( start, end ) merged ->
                case merged of
                    ( lastStart, lastEnd ) :: rest ->
                        if start <= lastEnd then
                            ( lastStart, max lastEnd end ) :: rest

                        else
                            ( start, end ) :: merged

                    [] ->
                        [ ( start, end ) ]
            )
            []
        |> List.reverse


splitByRanges : String -> List ( Int, Int ) -> List (Html msg)
splitByRanges text ranges =
    let
        step ( start, end ) ( cursor, parts ) =
            ( end
            , Html.mark [ Internal.cls [ "klar-mark" ] ] [ Html.text (String.slice start end text) ]
                :: Html.text (String.slice cursor start text)
                :: parts
            )

        ( last, reversed ) =
            List.foldl step ( 0, [] ) ranges
    in
    List.reverse (Html.text (String.dropLeft last text) :: reversed)
