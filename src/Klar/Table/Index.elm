module Klar.Table.Index exposing
    ( Index
    , Level(..)
    , Matches
    , Totals
    , allIndices
    , build
    , countMatching
    , hasHaystack
    , hasRanks
    , matchCount
    , matching
    , pageIndices
    , totalsOf
    , totalsOver
    )

{-| What a client-mode table works out once per list of rows, and the one pipeline
(filter, then sort) that finds the rows to show, over row positions.

The expensive part of showing 50 000 rows is not the sorting or the searching, but
turning each row into text and sort keys again and again. An `Index` keeps, for
every row, the text the search looks at and, for every sortable column, the rows
in ascending and in descending order. A sort click then reads a list that is
there already, a page change reads 25 positions of it, and a keystroke in the
search box is one `String.contains` per row.

Everything here works on positions in an `Array` of rows (0 to count - 1), not on
the rows, so it knows nothing of columns and can be tested alone.

-}

import Array exposing (Array)
import Dict exposing (Dict)
import Klar.Table.Sort as Sorting exposing (Key)



-- INDEX


{-| The text to search in for every row, and the sorted order of every sortable
column. It holds no functions.
-}
type Index
    = Index
        { haystack : Maybe (Array String)

        -- The same texts as a list: a keystroke walks it once (a list is read
        -- faster than an array, which has to be indexed for every row).
        , scanText : Maybe (List String)
        , ranks : Dict String Ranks
        , totals : Dict String Totals

        -- The number of every row for a footer column (NaN where it has none), so
        -- that the sum over the matching rows reads positions, not rows.
        , numbers : Dict String (Array Float)
        }


{-| The sum of a numeric column over all rows, and how many rows have a value in it.
-}
type alias Totals =
    { sum : Float
    , count : Int
    }


{-| The positions of all rows, ascending and descending by one column. Rows with
the same key keep their order in both (as a stable sort does), and rows without a
value come last in both.
-}
type alias Ranks =
    { asc : Array Int
    , desc : Array Int
    }


{-| Builds the index of a list of rows. `search` makes the text of a row that the
search words are looked for in (already folded to lower case without accents);
`sorts` makes a sort key per row for each column id that can be sorted this way.
-}
build :
    Array row
    -> { search : Maybe (row -> String), sorts : List ( String, row -> Key ), totals : List ( String, row -> Maybe Float ) }
    -> Index
build rows spec =
    let
        haystack =
            Maybe.map (\text -> Array.map text rows) spec.search
    in
    Index
        { haystack = haystack
        , scanText = Maybe.map Array.toList haystack
        , ranks =
            spec.sorts
                |> List.map (\( id, toKey ) -> ( id, ranksOf (Array.toList (Array.map toKey rows)) ))
                |> Dict.fromList
        , totals =
            spec.totals
                |> List.map
                    (\( id, toNumber ) ->
                        let
                            numbers =
                                Array.foldr
                                    (\row acc ->
                                        case toNumber row of
                                            Just n ->
                                                n :: acc

                                            Nothing ->
                                                acc
                                    )
                                    []
                                    rows
                        in
                        ( id, { sum = List.sum numbers, count = List.length numbers } )
                    )
                |> Dict.fromList
        , numbers =
            spec.totals
                |> List.map
                    (\( id, toNumber ) ->
                        ( id
                        , Array.map
                            (\row ->
                                case toNumber row of
                                    Just n ->
                                        n

                                    Nothing ->
                                        nan
                            )
                            rows
                        )
                    )
                |> Dict.fromList
        }


nan : Float
nan =
    0 / 0


{-| The sum and the count of a column over all the rows, if the index was asked
to keep them.
-}
totalsOf : String -> Index -> Maybe Totals
totalsOf id (Index index) =
    Dict.get id index.totals


{-| The sum and the count of a column over the rows that matched, if the index
was asked to keep the numbers. It reads the numbers of the matching positions, so
it costs no more than a pass over a list of integers, and the rows themselves
are never needed (a footer used to turn every matching row into a number again
on every message).
-}
totalsOver : String -> Matches -> Index -> Maybe Totals
totalsOver id (Matches count positions) (Index index) =
    case ( Dict.get id index.totals, Dict.get id index.numbers ) of
        ( Just all, Just numbers ) ->
            if count == Array.length numbers then
                -- every row matched: the sum kept while building
                Just all

            else
                Just (sumOver numbers positions)

        _ ->
            Nothing


sumOver : Array Float -> Positions -> Totals
sumOver numbers positions =
    case positions of
        Natural count ->
            sumRange numbers 0 count 0 0

        InArray array ->
            sumArray numbers array 0 0 0

        InList list ->
            sumList numbers list 0 0


sumRange : Array Float -> Int -> Int -> Float -> Int -> Totals
sumRange numbers position end sum found =
    if position >= end then
        { sum = sum, count = found }

    else
        case Array.get position numbers of
            Just n ->
                if isNaN n then
                    sumRange numbers (position + 1) end sum found

                else
                    sumRange numbers (position + 1) end (sum + n) (found + 1)

            Nothing ->
                sumRange numbers (position + 1) end sum found


sumArray : Array Float -> Array Int -> Int -> Float -> Int -> Totals
sumArray numbers positions at sum found =
    case Array.get at positions of
        Just position ->
            case Array.get position numbers of
                Just n ->
                    if isNaN n then
                        sumArray numbers positions (at + 1) sum found

                    else
                        sumArray numbers positions (at + 1) (sum + n) (found + 1)

                Nothing ->
                    sumArray numbers positions (at + 1) sum found

        Nothing ->
            { sum = sum, count = found }


sumList : Array Float -> List Int -> Float -> Int -> Totals
sumList numbers positions sum found =
    case positions of
        [] ->
            { sum = sum, count = found }

        position :: rest ->
            case Array.get position numbers of
                Just n ->
                    if isNaN n then
                        sumList numbers rest sum found

                    else
                        sumList numbers rest (sum + n) (found + 1)

                Nothing ->
                    sumList numbers rest sum found


{-| Does the index have search texts?
-}
hasHaystack : Index -> Bool
hasHaystack (Index index) =
    index.haystack /= Nothing


{-| Does the index know the order of this column?
-}
hasRanks : String -> Index -> Bool
hasRanks id (Index index) =
    Dict.member id index.ranks


ranksOf : List Key -> Ranks
ranksOf keys =
    let
        sorted =
            keys
                |> List.indexedMap (\position key -> ( key, position ))
                |> List.sortWith
                    (\( keyA, a ) ( keyB, b ) ->
                        case Sorting.compareKeys False keyA keyB of
                            EQ ->
                                compare a b

                            order ->
                                order
                    )

        groups =
            groupEqual sorted

        present =
            List.filter (\( missing, _ ) -> not missing) groups |> List.map Tuple.second

        absent =
            List.filter Tuple.first groups |> List.concatMap Tuple.second
    in
    { asc = Array.fromList (List.concat present ++ absent)
    , desc = Array.fromList (List.concat (List.reverse present) ++ absent)
    }


{-| Splits a sorted list into runs of equal keys, in order: whether the run is the
rows without a value, and their positions.
-}
groupEqual : List ( Key, Int ) -> List ( Bool, List Int )
groupEqual sorted =
    case sorted of
        [] ->
            []

        ( key, first ) :: rest ->
            groupLoop key [ first ] rest []


groupLoop : Key -> List Int -> List ( Key, Int ) -> List ( Bool, List Int ) -> List ( Bool, List Int )
groupLoop key current rest done =
    case rest of
        [] ->
            List.reverse (( key == Sorting.Missing, List.reverse current ) :: done)

        ( next, position ) :: more ->
            if Sorting.compareKeys False key next == EQ then
                groupLoop key (position :: current) more done

            else
                groupLoop next [ position ] more (( key == Sorting.Missing, List.reverse current ) :: done)



-- MATCHING


{-| One level of the sort. `Ranked` reads the order that the index has kept
(use it for a single level only; the id must be one that `hasRanks` says yes
to); the others work out the order from the rows.
-}
type Level
    = Ranked String Bool
    | Keyed Bool (Int -> Key)
    | Compared Bool (Int -> Int -> Order)


{-| The positions of the rows that matched, in the order to show them.
-}
type Matches
    = Matches Int Positions


type Positions
    = Natural Int
    | InArray (Array Int)
    | InList (List Int)


{-| The rows that pass every test, sorted. `count` is the number of rows. `words`
(when not empty) must all appear in the row's search text, which needs an index
with a search text (rows have none without it, and then no row matches). The
`tests` are for everything else (column filters, the outside filter). With
no levels the rows stay in their order. The sort is stable: rows that compare
equal stay in their original order.
-}
matching :
    Maybe Index
    -> { count : Int, words : List String, tests : List (Int -> Bool), levels : List Level }
    -> Matches
matching maybeIndex spec =
    let
        haystack =
            maybeIndex |> Maybe.andThen (\(Index index) -> index.haystack)

        searchTests =
            case ( spec.words, haystack ) of
                ( [], _ ) ->
                    []

                ( words, Just texts ) ->
                    [ \position ->
                        case Array.get position texts of
                            Just text ->
                                containsAll words text

                            Nothing ->
                                False
                    ]

                ( _, Nothing ) ->
                    [ \_ -> False ]

        tests =
            searchTests ++ spec.tests

        ranked =
            case ( spec.levels, maybeIndex ) of
                ( [ Ranked id descending ], Just (Index index) ) ->
                    Dict.get id index.ranks
                        |> Maybe.map
                            (\ranks ->
                                if descending then
                                    ranks.desc

                                else
                                    ranks.asc
                            )

                _ ->
                    Nothing

        base =
            case ranked of
                Just positions ->
                    InArray positions

                Nothing ->
                    Natural spec.count

        -- No sort of the index in the way: walk the list of search texts once.
        kept =
            case ( spec.words, base, maybeIndex |> Maybe.andThen (\(Index index) -> index.scanText) ) of
                ( _ :: _, Natural _, Just texts ) ->
                    scan spec.words spec.tests texts 0 []

                ( _ :: _, InArray order, _ ) ->
                    case haystack of
                        Just texts ->
                            scanOrder spec.words spec.tests texts (Array.toList order) []

                        Nothing ->
                            keep tests base

                _ ->
                    keep tests base

        computed =
            List.filter (isRanked >> not) spec.levels
    in
    case ( ranked, computed ) of
        ( Nothing, _ :: _ ) ->
            let
                sorted =
                    sortPositions computed (toList kept)
            in
            Matches (List.length sorted) (InList sorted)

        _ ->
            kept


isRanked : Level -> Bool
isRanked level =
    case level of
        Ranked _ _ ->
            True

        _ ->
            False


keep : List (Int -> Bool) -> Positions -> Matches
keep tests positions =
    case tests of
        [] ->
            Matches (length positions) positions

        _ ->
            let
                passes position =
                    allPass tests position

                survivors =
                    case positions of
                        Natural count ->
                            naturalFold passes (count - 1) []

                        InArray array ->
                            keepFrom passes (Array.toList array) []

                        InList list ->
                            List.filter passes list
            in
            Matches (List.length survivors) (InList survivors)


{-| Every word is in the text. A loop of its own: this runs for every row of the table
on every keystroke and every page change.
-}
containsAll : List String -> String -> Bool
containsAll words text =
    case words of
        [] ->
            True

        word :: rest ->
            if String.contains word text then
                containsAll rest text

            else
                False


allPass : List (Int -> Bool) -> Int -> Bool
allPass tests position =
    case tests of
        [] ->
            True

        test :: rest ->
            if test position then
                allPass rest position

            else
                False


{-| The positions whose search text has every word and that pass the other tests, from
a list of all the texts in order.
-}
scan : List String -> List (Int -> Bool) -> List String -> Int -> List Int -> Matches
scan words tests texts position found =
    case texts of
        [] ->
            let
                survivors =
                    List.reverse found
            in
            Matches (List.length survivors) (InList survivors)

        text :: rest ->
            if containsAll words text && allPass tests position then
                scan words tests rest (position + 1) (position :: found)

            else
                scan words tests rest (position + 1) found


{-| The positions in the order of a sorted column that have every word in their search
text and pass the other tests: the search texts are read by position, in that order.
-}
scanOrder : List String -> List (Int -> Bool) -> Array String -> List Int -> List Int -> Matches
scanOrder words tests texts order found =
    case order of
        [] ->
            let
                survivors =
                    List.reverse found
            in
            Matches (List.length survivors) (InList survivors)

        position :: rest ->
            case Array.get position texts of
                Just text ->
                    if containsAll words text && allPass tests position then
                        scanOrder words tests texts rest (position :: found)

                    else
                        scanOrder words tests texts rest found

                Nothing ->
                    scanOrder words tests texts rest found


{-| The positions of a list that pass, in order (a loop that walks the list once).
-}
keepFrom : (Int -> Bool) -> List Int -> List Int -> List Int
keepFrom passes positions found =
    case positions of
        [] ->
            List.reverse found

        position :: rest ->
            if passes position then
                keepFrom passes rest (position :: found)

            else
                keepFrom passes rest found


naturalFold : (Int -> Bool) -> Int -> List Int -> List Int
naturalFold passes position acc =
    if position < 0 then
        acc

    else if passes position then
        naturalFold passes (position - 1) (position :: acc)

    else
        naturalFold passes (position - 1) acc


length : Positions -> Int
length positions =
    case positions of
        Natural count ->
            count

        InArray array ->
            Array.length array

        InList list ->
            List.length list


toList : Matches -> List Int
toList (Matches _ positions) =
    case positions of
        Natural count ->
            List.range 0 (count - 1)

        InArray array ->
            Array.toList array

        InList list ->
            list


type alias Decorated =
    { position : Int
    , row : Int
    , keys : List Key
    }


sortPositions : List Level -> List Int -> List Int
sortPositions levels rows =
    let
        decorate position row =
            { position = position
            , row = row
            , keys =
                List.map
                    (\level ->
                        case level of
                            Keyed _ toKey ->
                                toKey row

                            _ ->
                                Sorting.Missing
                    )
                    levels
            }
    in
    rows
        |> List.indexedMap decorate
        |> List.sortWith (compareDecorated levels)
        |> List.map .row


compareDecorated : List Level -> Decorated -> Decorated -> Order
compareDecorated levels a b =
    case compareLevels levels a.keys b.keys a.row b.row of
        EQ ->
            compare a.position b.position

        order ->
            order


compareLevels : List Level -> List Key -> List Key -> Int -> Int -> Order
compareLevels levels keysA keysB rowA rowB =
    case ( levels, keysA, keysB ) of
        ( level :: moreLevels, keyA :: moreA, keyB :: moreB ) ->
            let
                order =
                    case level of
                        Keyed descending _ ->
                            Sorting.compareKeys descending keyA keyB

                        Compared descending comparator ->
                            direct descending (comparator rowA rowB)

                        Ranked _ _ ->
                            EQ
            in
            if order == EQ then
                compareLevels moreLevels moreA moreB rowA rowB

            else
                order

        _ ->
            EQ


direct : Bool -> Order -> Order
direct descending order =
    if descending then
        case order of
            LT ->
                GT

            EQ ->
                EQ

            GT ->
                LT

    else
        order



-- READING THE RESULT


{-| How many rows matched.
-}
matchCount : Matches -> Int
matchCount (Matches count _) =
    count


{-| How many of the matches pass a test. It gets the place among the matches (0 for
the first) and the position in the rows, and goes through the matches once, without
a list of rows.
-}
countMatching : (Int -> Int -> Bool) -> Matches -> Int
countMatching test (Matches _ positions) =
    case positions of
        Natural count ->
            countRange test 0 count 0

        InArray array ->
            countArray test array 0 0

        InList list ->
            countList test list 0 0


countRange : (Int -> Int -> Bool) -> Int -> Int -> Int -> Int
countRange test position end found =
    if position >= end then
        found

    else if test position position then
        countRange test (position + 1) end (found + 1)

    else
        countRange test (position + 1) end found


countArray : (Int -> Int -> Bool) -> Array Int -> Int -> Int -> Int
countArray test positions at found =
    case Array.get at positions of
        Just position ->
            if test at position then
                countArray test positions (at + 1) (found + 1)

            else
                countArray test positions (at + 1) found

        Nothing ->
            found


countList : (Int -> Int -> Bool) -> List Int -> Int -> Int -> Int
countList test positions at found =
    case positions of
        [] ->
            found

        position :: rest ->
            if test at position then
                countList test rest (at + 1) (found + 1)

            else
                countList test rest (at + 1) found


{-| The positions of `size` rows from the `offset`th match on.
-}
pageIndices : Int -> Int -> Matches -> List Int
pageIndices offset size (Matches count positions) =
    let
        from =
            max 0 offset

        to =
            min count (from + max 0 size)
    in
    case positions of
        Natural _ ->
            List.range from (to - 1)

        InArray array ->
            Array.slice from to array |> Array.toList

        InList list ->
            list |> List.drop from |> List.take (to - from)


{-| The positions of every match, in order.
-}
allIndices : Matches -> List Int
allIndices =
    toList
