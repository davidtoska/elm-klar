module Klar.Table.Sort exposing
    ( Key(..)
    , Level(..)
    , collationKey
    , compareKeys
    , numberKey
    , sort
    , textKey
    )

{-| Stable multi-column sorting for tables.

    Sort.sort
        [ Sort.ByKey False (\p -> Sort.textKey Locale.nb p.city) -- city A-Å
        , Sort.ByKey True (\p -> Sort.numberKey (Just (toFloat p.score))) -- then score, high first
        ]
        people

  - **Stable**: rows that compare equal keep their original order (the
    original position is the last tie-breaker, so this does not depend on
    the JavaScript engine).
  - **Fast**: keys are computed once per row (decorate, sort, undecorate),
    not once per comparison.
  - **Missing values last**: empty text and missing numbers go to the end in
    both directions.
  - **Norwegian alphabet**: `collationKey Locale.nb` sorts case-insensitively and
    puts Æ, Ø, Å after Z; accents sort with their base letter (é = e).

-}

import Klar.Internal as Internal
import Klar.Locale as Locale exposing (Locale)


{-| A precomputed sort key. Build text keys with `textKey` so they are
compared in the right alphabetical order.
-}
type Key
    = Text String
    | Number Float
    | Missing


{-| One level of a multi-column sort. The `Bool` is `True` for descending.
-}
type Level a
    = ByKey Bool (a -> Key)
    | ByComparator Bool (a -> a -> Order)


{-| A text key; empty (or blank) text is `Missing`.
-}
textKey : Locale -> String -> Key
textKey locale text =
    let
        trimmed =
            String.trim text
    in
    if String.isEmpty trimmed then
        Missing

    else
        Text (collationKey locale trimmed)


{-| A number key; `Nothing` and NaN are `Missing`.
-}
numberKey : Maybe Float -> Key
numberKey maybe =
    case maybe of
        Just n ->
            if isNaN n then
                Missing

            else
                Number n

        Nothing ->
            Missing


{-| A string that sorts in the alphabetical order of the locale when
compared with `compare`.

    collationKey Locale.nb "Ålesund" > collationKey Locale.nb "Zürich" --> True

    collationKey Locale.en "Ålesund" < collationKey Locale.en "Bergen" --> True

-}
collationKey : Locale -> String -> String
collationKey locale text =
    let
        lower =
            String.toLower text
    in
    if Internal.hasLatinLetters lower then
        Locale.pick locale
            { nb = String.map foldNorwegian lower
            , en = String.map foldLatin lower
            }

    else
        lower


{-| Sorts by the levels in order; the first level decides, the next breaks
ties, and so on. An empty list of levels returns the list unchanged.
-}
sort : List (Level a) -> List a -> List a
sort levels items =
    case levels of
        [] ->
            items

        [ ByKey descending toKey ] ->
            -- the common case, without the list walking of the general one
            items
                |> List.indexedMap (\index item -> ( toKey item, index, item ))
                |> List.sortWith (compareSingle descending)
                |> List.map (\( _, _, item ) -> item)

        _ ->
            items
                |> List.indexedMap (decorate levels)
                |> List.sortWith (compareDecorated levels)
                |> List.map .item



-- INTERNAL


type alias Decorated a =
    { index : Int
    , keys : List Key
    , item : a
    }


decorate : List (Level a) -> Int -> a -> Decorated a
decorate levels index item =
    { index = index
    , keys =
        List.map
            (\level ->
                case level of
                    ByKey _ toKey ->
                        toKey item

                    ByComparator _ _ ->
                        Missing
            )
            levels
    , item = item
    }


compareSingle : Bool -> ( Key, Int, a ) -> ( Key, Int, a ) -> Order
compareSingle descending ( keyA, indexA, _ ) ( keyB, indexB, _ ) =
    case compareKeys descending keyA keyB of
        EQ ->
            compare indexA indexB

        order ->
            order


compareDecorated : List (Level a) -> Decorated a -> Decorated a -> Order
compareDecorated levels a b =
    case compareLevels levels a.keys b.keys a.item b.item of
        EQ ->
            compare a.index b.index

        order ->
            order


compareLevels : List (Level a) -> List Key -> List Key -> a -> a -> Order
compareLevels levels keysA keysB itemA itemB =
    case ( levels, keysA, keysB ) of
        ( level :: moreLevels, keyA :: moreA, keyB :: moreB ) ->
            let
                order =
                    case level of
                        ByKey descending _ ->
                            compareKeys descending keyA keyB

                        ByComparator descending comparator ->
                            direct descending (comparator itemA itemB)
            in
            if order == EQ then
                compareLevels moreLevels moreA moreB itemA itemB

            else
                order

        _ ->
            EQ


{-| Compares two keys, the second argument says whether the order is reversed.
Missing values always sort last, whatever the direction.
-}
compareKeys : Bool -> Key -> Key -> Order
compareKeys descending a b =
    case ( a, b ) of
        ( Missing, Missing ) ->
            EQ

        ( Missing, _ ) ->
            GT

        ( _, Missing ) ->
            LT

        ( Text x, Text y ) ->
            direct descending (compare x y)

        ( Number x, Number y ) ->
            direct descending (compare x y)

        ( Number _, Text _ ) ->
            LT

        ( Text _, Number _ ) ->
            GT


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


{-| Norwegian: æ ø å after z (also ä = æ, ö = ø), other accents fold to their
base letter. `{`, `|` and `}` are the three code points right after `z`.
-}
foldNorwegian : Char -> Char
foldNorwegian c =
    if Char.toCode c < 128 then
        c

    else
        case c of
            'æ' ->
                '{'

            'ä' ->
                '{'

            'ø' ->
                '|'

            'ö' ->
                '|'

            'å' ->
                '}'

            'ü' ->
                'y'

            _ ->
                foldLatin c


foldLatin : Char -> Char
foldLatin c =
    if Char.toCode c < 128 then
        c

    else
        case c of
            'á' ->
                'a'

            'à' ->
                'a'

            'â' ->
                'a'

            'ã' ->
                'a'

            'ä' ->
                'a'

            'å' ->
                'a'

            'æ' ->
                'a'

            'ç' ->
                'c'

            'é' ->
                'e'

            'è' ->
                'e'

            'ê' ->
                'e'

            'ë' ->
                'e'

            'í' ->
                'i'

            'ì' ->
                'i'

            'î' ->
                'i'

            'ï' ->
                'i'

            'ñ' ->
                'n'

            'ó' ->
                'o'

            'ò' ->
                'o'

            'ô' ->
                'o'

            'õ' ->
                'o'

            'ö' ->
                'o'

            'ø' ->
                'o'

            'ú' ->
                'u'

            'ù' ->
                'u'

            'û' ->
                'u'

            'ü' ->
                'u'

            'ý' ->
                'y'

            'ß' ->
                's'

            _ ->
                c
