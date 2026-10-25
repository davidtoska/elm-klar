module Klar.Chart.Preparation exposing (..)

{-| Pure series arrays, line runs, stacked bars, data-table rows and tooltip values.
-}

import Array exposing (Array)
import Klar.Chart.Colors exposing (colorClass, toneClass, toneClassFor)
import Klar.Chart.Data exposing (byCategory, byDate, dashed, noData, segment, segmentSlot, segmentTone, series, seriesMaybe, withSlot, withTone)
import Klar.Chart.Numbers exposing (compact, dropTrailingZeros, firstJust, formatLabel, formatTick, formatValue, isWhole, missingOr, num, pct, percentText, roundTo, sanitize, smartFormat, stepDecimals, tickGutter, trimFraction)
import Klar.Chart.Texts exposing (summaryLine, texts)
import Klar.Chart.Types exposing (Attribute(..), Axis, Config, Data(..), LegendItem, PSeries, Piece, Prepared, Segment(..), Series(..), Slice, State(..), Texts)
import Klar.Format as Format


prepare : Config msg -> List Series -> Prepared
prepare config list =
    let
        longest =
            list
                |> List.map (\(Series s) -> List.length s.values)
                |> List.maximum
                |> Maybe.withDefault 0

        n =
            max (max (List.length config.categories) (List.length config.dates)) longest

        catArray =
            if List.isEmpty config.dates then
                Array.fromList config.categories

            else
                Array.fromList (List.map (Format.date config.locale) config.dates)

        shortArray =
            if List.isEmpty config.dates then
                catArray

            else
                Array.fromList (List.map (Format.dateShort config.locale) config.dates)

        labelAtIn array i =
            Array.get i array |> Maybe.withDefault (String.fromInt (i + 1))

        labelAt =
            labelAtIn catArray

        build index (Series s) =
            { name = s.name
            , values = Array.fromList s.values
            , cls = colorClass config.tone index s.color s.tone
            , dashed = s.dashed
            }
    in
    { n = n
    , cats = Array.fromList (List.map labelAt (List.range 0 (n - 1)))
    , short = Array.fromList (List.map (labelAtIn shortArray) (List.range 0 (n - 1)))
    , series = List.indexedMap build list
    }


valueAt : Int -> PSeries -> Maybe Float
valueAt i s =
    Array.get i s.values |> Maybe.andThen identity


hasAnyValue : Prepared -> Bool
hasAnyValue prepared =
    prepared.series
        |> List.any (\s -> s.values |> Array.toList |> List.any (\v -> v /= Nothing))


categoryAt : Prepared -> Int -> String
categoryAt prepared i =
    Array.get i prepared.cats |> Maybe.withDefault ""


{-| The label under the axis: as short as the category can be written.
-}
shortAt : Prepared -> Int -> String
shortAt prepared i =
    Array.get i prepared.short |> Maybe.withDefault ""


{-| The categories that get a label on the axis when every `every`-th one has
room: the first, every `every`-th after it, and always the last (usually the most
recent period); the label just before the last is dropped when the two would be
closer than `every`.
-}
labelledIndexes : Int -> Int -> List Int
labelledIndexes n every =
    List.range 0 (n - 1)
        |> List.filter (\i -> i == n - 1 || (modBy every i == 0 && n - 1 - i >= every))


tableRows : Config msg -> Prepared -> List (List String)
tableRows config prepared =
    List.range 0 (prepared.n - 1)
        |> List.map
            (\i ->
                categoryAt prepared i
                    :: List.map
                        (\s ->
                            case valueAt i s of
                                Just v ->
                                    formatValue config v

                                Nothing ->
                                    "-"
                        )
                        prepared.series
            )


{-| The tooltip text of one category: its name and a line per series.
-}
slotTip : Config msg -> Prepared -> Int -> String
slotTip config prepared i =
    let
        rows =
            prepared.series
                |> List.filterMap
                    (\s ->
                        valueAt i s
                            |> Maybe.map (\v -> s.name ++ ": " ++ formatValue config v)
                    )
    in
    String.join "\n" (categoryAt prepared i :: rows)


{-| Unbroken stretches of a series: a missing value ends a run.
-}
runs : Int -> Array (Maybe Float) -> List (List ( Int, Float ))
runs n values =
    let
        step i ( current, done ) =
            case Array.get i values |> Maybe.andThen identity of
                Just v ->
                    ( ( i, v ) :: current, done )

                Nothing ->
                    if List.isEmpty current then
                        ( [], done )

                    else
                        ( [], List.reverse current :: done )

        ( rest, finished ) =
            List.foldl step ( [], [] ) (List.range 0 (n - 1))
    in
    List.reverse
        (if List.isEmpty rest then
            finished

         else
            List.reverse rest :: finished
        )


horizontalHeight : Config msg -> Prepared -> Int
horizontalHeight config prepared =
    let
        perCategory =
            if config.stacked then
                28

            else
                max 28 (List.length prepared.series * 16 + 12)
    in
    clamp 120 1200 (prepared.n * perCategory + 4)


{-| The bars of one category: for grouped bars each from 0 to its value, for
stacked bars on top of each other (positives upwards, negatives downwards).
-}
piecesOf : Config msg -> Prepared -> Int -> List Piece
piecesOf config prepared i =
    let
        present =
            prepared.series
                |> List.indexedMap Tuple.pair
                |> List.filterMap
                    (\( index, s ) ->
                        valueAt i s |> Maybe.map (\v -> { series = s, index = index, value = v, from = 0, to = v, outer = True })
                    )
    in
    if config.stacked then
        let
            stackStep piece ( posTop, negTop, done ) =
                if piece.value >= 0 then
                    ( posTop + piece.value, negTop, { piece | from = posTop, to = posTop + piece.value } :: done )

                else
                    ( posTop, negTop + piece.value, { piece | from = negTop, to = negTop + piece.value } :: done )

            ( _, _, stackedPieces ) =
                List.foldl stackStep ( 0, 0, [] ) present

            lastPositive =
                stackedPieces |> List.filter (\p -> p.value >= 0) |> List.head |> Maybe.map .index

            lastNegative =
                stackedPieces |> List.filter (\p -> p.value < 0) |> List.head |> Maybe.map .index
        in
        stackedPieces
            |> List.reverse
            |> List.map
                (\p ->
                    { p
                        | outer =
                            if p.value >= 0 then
                                Just p.index == lastPositive

                            else
                                Just p.index == lastNegative
                    }
                )

    else
        present


barTableRows : Config msg -> Prepared -> List (List String)
barTableRows config prepared =
    List.range 0 (prepared.n - 1)
        |> List.map
            (\i ->
                let
                    cells =
                        List.map
                            (\s ->
                                case valueAt i s of
                                    Just v ->
                                        formatValue config v

                                    Nothing ->
                                        "-"
                            )
                            prepared.series

                    total =
                        prepared.series |> List.filterMap (valueAt i) |> List.sum
                in
                (categoryAt prepared i :: cells)
                    ++ (if config.stacked then
                            [ formatValue config total ]

                        else
                            []
                       )
            )


barTip : Config msg -> Prepared -> Int -> String
barTip config prepared i =
    let
        base =
            slotTip config prepared i

        total =
            prepared.series |> List.filterMap (valueAt i) |> List.sum

        t =
            texts config.locale
    in
    if config.stacked && List.length prepared.series > 1 then
        base ++ "\n" ++ t.total ++ ": " ++ formatValue config total

    else
        base
