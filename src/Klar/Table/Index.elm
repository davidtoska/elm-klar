module Klar.Table.Index exposing
    ( Index
    , Level(..)
    , Matches
    , Totals
    , allIndices
    , build
    , hasHaystack
    , hasRanks
    , matchCount
    , matching
    , pageIndices
    , totalsOf
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
        , ranks : Dict String Ranks
        , totals : Dict String Totals
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
    Index
        { haystack = Maybe.map (\text -> Array.map text rows) spec.search
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
        }


{-| The sum and the count of a column over all the rows, if the index was asked
to keep them.
-}
totalsOf : String -> Index -> Maybe Totals
totalsOf id (Index index) =
    Dict.get id index.totals


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
                                List.all (\word -> String.contains word text) words

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

        kept =
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
                    List.all (\test -> test position) tests

                survivors =
                    case positions of
                        Natural count ->
                            naturalFold passes (count - 1) []

                        InArray array ->
                            Array.foldr
                                (\position acc ->
                                    if passes position then
                                        position :: acc

                                    else
                                        acc
                                )
                                []
                                array

                        InList list ->
                            List.filter passes list
            in
            Matches (List.length survivors) (InList survivors)


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
