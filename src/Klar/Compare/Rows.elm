module Klar.Compare.Rows exposing
    ( Mark(..)
    , Row
    , Value(..)
    , baselineIndex
    , compareRow
    , uniqueKeys
    , value
    , visible
    )

{-| The logic of the comparison of records, apart from the page: what counts as
a value, which cells differ from the baseline, which rows are left out, and keys
that are different for every record.

A field gives a text for every record. A text that is empty or blank means that the
record has no value there. Two records are the same in a field when both have no value
or both have the same text, exactly. Functions are never compared: the application
turns what it wants compared into text.

-}

import Klar.Diff.Keys as Keys


{-| What a record has in a field: nothing, or a text.
-}
type Value
    = Missing
    | Value String


{-| How a cell stands to the baseline. The cell of the baseline record itself is
the baseline. When there is only one record there is nothing to compare, so its
cells are `Alone`.
-}
type Mark
    = Baseline
    | Same
    | Differs
    | Alone


{-| One row of the comparison: the cells of the records from left to right, and
whether every record has the value of the baseline.
-}
type alias Row =
    { marks : List Mark
    , allEqual : Bool
    }


{-| The value of a text: a blank text is no value.

    value "" -- Missing

    value "  " -- Missing

    value "12.50" -- Value "12.50"

-}
value : String -> Value
value text =
    if String.isEmpty (String.trim text) then
        Missing

    else
        Value text


{-| Compares the values of one field in all records with the value of the baseline
record (the index counts from 0; an index outside the list is taken as the first
record). Every record gets a mark and the row says whether all are equal.
-}
compareRow : Int -> List Value -> Row
compareRow baseline values =
    case values of
        [] ->
            { marks = [], allEqual = True }

        [ _ ] ->
            { marks = [ Alone ], allEqual = True }

        _ ->
            let
                index =
                    if baseline < 0 || baseline >= List.length values then
                        0

                    else
                        baseline

                reference =
                    values |> List.drop index |> List.head |> Maybe.withDefault Missing

                marks =
                    List.indexedMap
                        (\i found ->
                            if i == index then
                                Baseline

                            else if found == reference then
                                Same

                            else
                                Differs
                        )
                        values
            in
            { marks = marks, allEqual = not (List.member Differs marks) }


{-| The position of the baseline among the keys of the records: the record with the
given key, or the first record when there is none or no record has the key.
-}
baselineIndex : List String -> Maybe String -> Int
baselineIndex keys wanted =
    case wanted of
        Nothing ->
            0

        Just key ->
            keys
                |> List.indexedMap Tuple.pair
                |> List.filter (\( _, found ) -> found == key)
                |> List.head
                |> Maybe.map Tuple.first
                |> Maybe.withDefault 0


{-| Keys that are different for every record, so that two records with the same id
(a mistake in the data, but one that can happen) are both drawn and nothing is
dropped. The first record keeps its key; the next one with the same key gets
`~2` after it, then `~3`. A key that is taken (a record whose id is `"a~2"`) is
skipped, so the keys are different whatever the ids look like.

    uniqueKeys [ "a", "b", "a" ] -- [ "a", "b", "a~2" ]

-}
uniqueKeys : List String -> List String
uniqueKeys =
    Keys.unique (\key number -> key ++ "~" ++ String.fromInt number)


{-| The items that are drawn. A row where all records are equal is left out when
only the differences are wanted, and so is a heading that has no row left under it.
`toRow` gives the row of an item, or `Nothing` for a heading. The order is kept.
-}
visible : Bool -> (a -> Maybe Row) -> List a -> List a
visible onlyDifferences toRow items =
    if not onlyDifferences then
        items

    else
        let
            keep item =
                case toRow item of
                    Just found ->
                        not found.allEqual

                    Nothing ->
                        True

            isHeading item =
                toRow item == Nothing

            -- a heading stays when the next item is a row that stays; walking from the
            -- end, that is when the item kept just before it is a row (tail recursive,
            -- so thousands of fields do not grow the stack)
            withoutEmptyHeadings remaining kept =
                case remaining of
                    item :: rest ->
                        if isHeading item then
                            case kept of
                                next :: _ ->
                                    if isHeading next then
                                        withoutEmptyHeadings rest kept

                                    else
                                        withoutEmptyHeadings rest (item :: kept)

                                [] ->
                                    withoutEmptyHeadings rest kept

                        else
                            withoutEmptyHeadings rest (item :: kept)

                    [] ->
                        kept
        in
        withoutEmptyHeadings (List.reverse (List.filter keep items)) []
