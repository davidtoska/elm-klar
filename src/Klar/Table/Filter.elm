module Klar.Table.Filter exposing (..)

{-| Pure filter drafts, choices, numeric bounds and normalized row search.
-}

import Dict exposing (Dict)
import Klar.Internal as Internal
import Klar.Locale as Locale exposing (Locale)
import Klar.Search as Search
import Klar.Table.Texts as Texts exposing (Texts)
import Klar.Table.Types exposing (ColumnConfig, Draft(..), Filter(..), Model)
import Set exposing (Set)


toFilter : Draft -> Maybe Filter
toFilter draft =
    case draft of
        TextDraft value ->
            if String.isEmpty (String.trim value) then
                Nothing

            else
                Just (Contains (String.trim value))

        ChoiceDraft values ->
            if Set.isEmpty values then
                Nothing

            else
                Just (OneOf (Set.toList values))

        RangeDraft from to ->
            case ( parseNumber from, parseNumber to ) of
                ( Nothing, Nothing ) ->
                    Nothing

                ( Just low, Just high ) ->
                    -- "80 to 20" means 20 to 80 (as in Rule.matches), not "nothing"
                    Just (Between (Just (min low high)) (Just (max low high)))

                ( low, high ) ->
                    Just (Between low high)


toDraft : Filter -> Draft
toDraft f =
    case f of
        Contains value ->
            TextDraft value

        OneOf values ->
            ChoiceDraft (Set.fromList values)

        Between low high ->
            RangeDraft
                (Maybe.map String.fromFloat low |> Maybe.withDefault "")
                (Maybe.map String.fromFloat high |> Maybe.withDefault "")


choicesOf : String -> Dict String Draft -> Set String
choicesOf colId inputs =
    case Dict.get colId inputs of
        Just (ChoiceDraft values) ->
            values

        _ ->
            Set.empty


{-| "12,5", "12.5", "1 234", "−3" (Unicode minus) are numbers.
-}
parseNumber : String -> Maybe Float
parseNumber raw =
    let
        cleaned =
            raw
                |> String.trim
                |> String.replace "−" "-"
                |> String.filter (\c -> c /= ' ' && c /= '\u{00A0}')
                |> String.replace "," "."
    in
    if String.isEmpty cleaned then
        Nothing

    else
        String.toFloat cleaned
            |> Maybe.andThen
                (\n ->
                    if isNaN n || isInfinite n then
                        Nothing

                    else
                        Just n
                )


{-| A yes / no column offers "Yes" / "No" in English and "Ja" / "Nei" in
Norwegian. A filter keeps the value it was set with, which would stop matching
when the language changes, so choices of such a column are kept in one form that
belongs to no language (`"true"` and `"false"`) and shown in the language of the
moment. Other columns are left as they are.
-}
canonicalChoice : ColumnConfig row msg -> String -> String
canonicalChoice col value =
    if col.boolean then
        if value == (Texts.texts Locale.en).yes || value == (Texts.texts Locale.nb).yes then
            "true"

        else if value == (Texts.texts Locale.en).no || value == (Texts.texts Locale.nb).no then
            "false"

        else
            value

    else
        value


{-| The choice as the column says it in this language.
-}
localChoice : Locale -> ColumnConfig row msg -> String -> String
localChoice loc col value =
    if col.boolean then
        if value == "true" then
            (Texts.texts loc).yes

        else if value == "false" then
            (Texts.texts loc).no

        else
            value

    else
        value


{-| The value a select filter keeps for a row: its `filterValue`, or the text of
the column (`"true"` or `"false"` for a yes / no column).
-}
choiceOf : Locale -> ColumnConfig row msg -> row -> String
choiceOf loc col row =
    case col.filterValue of
        Just toValue ->
            toValue row

        Nothing ->
            canonicalChoice col (col.value loc row)


{-| How a select filter shows the values it keeps: the label of `filterOptions`,
"Yes" and "No" for a yes / no column, and for a column with a `filterValue` the
text of a row with that value. A value that nothing names is shown as it is.
-}
choiceLabels : Locale -> ColumnConfig row msg -> List row -> String -> String
choiceLabels loc col someRows =
    let
        given =
            Maybe.withDefault [] col.filterOptions
                |> List.map (\option -> ( option.value, option.label ))
                |> Dict.fromList

        found =
            case col.filterValue of
                Just toValue ->
                    List.foldl
                        (\row dict ->
                            let
                                value =
                                    toValue row
                            in
                            if Dict.member value dict then
                                dict

                            else
                                Dict.insert value (col.value loc row) dict
                        )
                        Dict.empty
                        someRows

                Nothing ->
                    Dict.empty
    in
    \value ->
        case Dict.get value given of
            Just label_ ->
                label_

            Nothing ->
                case Dict.get value found of
                    Just label_ ->
                        label_

                    Nothing ->
                        localChoice loc col value


{-| Does a row pass a column filter?
-}
filterTest : Locale -> ColumnConfig row msg -> Filter -> (row -> Bool)
filterTest loc col f =
    case f of
        Contains needle ->
            let
                wanted =
                    Search.normalize (String.trim needle)
            in
            \row -> String.contains wanted (fold (col.value loc row))

        OneOf values ->
            let
                allowed =
                    Set.fromList (List.map (canonicalChoice col) values)
            in
            \row -> Set.member (choiceOf loc col row) allowed

        Between low high ->
            case col.number of
                Just toNumber ->
                    \row ->
                        case toNumber row of
                            Just n ->
                                withinRange low high n

                            Nothing ->
                                False

                Nothing ->
                    always True


withinRange : Maybe Float -> Maybe Float -> Float -> Bool
withinRange low high n =
    let
        -- a range restored with its ends the wrong way round is the same range, as
        -- when the two numbers are typed into the filter
        ( from, to ) =
            case ( low, high ) of
                ( Just a, Just b ) ->
                    if a > b then
                        ( high, low )

                    else
                        ( low, high )

                _ ->
                    ( low, high )
    in
    (case from of
        Just bound ->
            n >= bound

        Nothing ->
            True
    )
        && (case to of
                Just bound ->
                    n <= bound

                Nothing ->
                    True
           )


searchWords : String -> List String
searchWords value =
    value
        |> Search.normalize
        |> String.words
        |> List.filter (\word -> word /= "")


{-| Every word of the search must be found in one of the searched columns
(case and accents ignored).
-}
searchTest : Locale -> List (ColumnConfig row msg) -> String -> Maybe (row -> Bool)
searchTest loc searched value =
    case searchWords value of
        [] ->
            Nothing

        words ->
            Just (\row -> List.all (\word -> String.contains word (searchText loc searched row)) words)


{-| The text of a row that the search looks in: the values of the searched
columns, one on each line, in lower case and without accents.
-}
searchText : Locale -> List (ColumnConfig row msg) -> row -> String
searchText loc searched row =
    searched
        |> List.map (\col -> col.value loc row)
        |> String.join "\n"
        |> String.replace "\u{00A0}" " "
        |> fold


{-| The same as `Search.normalize` (lower case, accents folded), but the slow
character-by-character fold only runs when the text has accented letters (the
letters from U+00C0 to U+00FF).
-}
fold : String -> String
fold value =
    let
        lower =
            String.toLower value
    in
    if Internal.hasLatinLetters lower then
        Search.normalize lower

    else
        lower


activeDrafts : Model -> List ( String, Draft )
activeDrafts model =
    model.inputs
        |> Dict.toList
        |> List.filter (\( _, draft ) -> toFilter draft /= Nothing)
