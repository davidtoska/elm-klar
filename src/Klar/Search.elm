module Klar.Search exposing
    ( filter, rank
    , score, matches, highlight
    , Prepared, Query, prepare, prepareMany, query, scorePrepared
    , normalize
    )

{-| Text matching for search fields, selects and command palettes: forgiving
about case and accents, and ranked, so the best match comes first.

Use when: a search field, a select or a list needs forgiving, ranked text matching.
Do not use when: the match must be exact, such as an id (compare the strings yourself).

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
  - `6` the letters of the query appear in order and close together, within about
    twice their number: letters left out are forgiven ("brgn" finds "Bergen"), a
    wrong or swapped letter is not. Only for words of three letters or more.

Sort by the score and keep the order of equal scores (`filter` and `rank` do); do not
rely on the numbers themselves, which a later version may spread out to fit a tier
between them.

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
    , distinct : List String
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
                , distinct = distinctLetters word
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
    -- Every exact match is a match of the word inside the text, so the one search
    -- for it comes first: a text that does not contain the word is not asked
    -- about its start or its words at all.
    if String.contains word.text prepared.text then
        if prepared.text == word.text then
            Just 0

        else if String.startsWith word.text prepared.text then
            Just 1

        else if String.contains word.spaced prepared.words then
            Just 2

        else
            Just 3

    else if word.fuzzy && hasEveryLetter word.distinct prepared.text && inOrder word.letters prepared.text then
        Just 6

    else
        Nothing


{-| The letters of a word, each once, in the order they first appear.
-}
distinctLetters : String -> List String
distinctLetters word =
    String.split "" word
        |> List.foldl
            (\letter seen ->
                if List.member letter seen then
                    seen

                else
                    letter :: seen
            )
            []
        |> List.reverse


{-| A cheap test that comes before the typo-tolerant one: a text that lacks one of
the letters cannot match loosely, and `String.contains` is a single native
search. Most texts fail on the first letter or two, so a query that matches
few texts (the slow case for the walk below) costs little more than one that
matches many.
-}
hasEveryLetter : List String -> String -> Bool
hasEveryLetter letters haystack =
    case letters of
        [] ->
            True

        letter :: rest ->
            String.contains letter haystack && hasEveryLetter rest haystack


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


{-| Splits `text` into plain parts and highlighted parts (`<mark>` elements), to
show why a result matched: for each word of the query, the place that `score`
used. That is the start of the text, else the start of a word ("ber" marks
"Bergen" in "Åsberg Bergen", not the "berg" inside "Åsberg"), else the first place
inside the text; for a match of letters in order, each of those letters. Matching
is done on the normalized text, so `"orsted"` highlights "Ørsted". The parts put
together are always the whole text.

    Search.highlight "ber" "Bergen" -- "Ber" in a <mark>, then "gen"

    Search.highlight "lvlc" "Ada Lovelace" -- the L, v, l and c each in a <mark>

-}
highlight : String -> String -> List (Html msg)
highlight queryText text =
    case query queryText of
        Query [] ->
            [ Html.text text ]

        Query words ->
            let
                (Prepared prepared) =
                    prepare text
            in
            splitByRanges text (mergeRanges (List.concatMap (\word -> wordRanges word prepared) words))


{-| Where a word of the query matched, as the ranges to mark: the place that the
score of the word came from.
-}
wordRanges : Word -> { text : String, words : String } -> List ( Int, Int )
wordRanges word prepared =
    let
        at start =
            [ ( start, start + String.length word.text ) ]
    in
    if String.contains word.text prepared.text then
        if String.startsWith word.text prepared.text then
            at 0

        else
            -- " word" at i in " " ++ text is the word at i in the text
            case String.indexes word.spaced prepared.words of
                start :: _ ->
                    at start

                [] ->
                    List.concatMap at (List.take 1 (String.indexes word.text prepared.text))

    else if word.fuzzy then
        window True word.letters prepared.text
            |> Maybe.map (List.map2 (\letter position -> ( position, position + String.length letter )) word.letters)
            |> Maybe.withDefault []

    else
        []


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
            , Html.mark [ Internal.cls [ "klar-highlight" ] ] [ Html.text (String.slice start end text) ]
                :: Html.text (String.slice cursor start text)
                :: parts
            )

        ( last, reversed ) =
            List.foldl step ( 0, [] ) ranges
    in
    List.reverse (Html.text (String.dropLeft last text) :: reversed)
