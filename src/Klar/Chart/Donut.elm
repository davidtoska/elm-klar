module Klar.Chart.Donut exposing (..)

{-| Donut slice preparation and rendering, including the Other group.
-}

import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Events
import Klar.Chart.Colors exposing (colorClass, toneClass, toneClassFor)
import Klar.Chart.Config exposing (area, ariaLabel, categories, centerCaption, centerLabel, configure, dates, description, emptyText, height, heightOf, hideLegend, horizontal, id, includeZero, legend, locale, maxLabels, onRetry, onSelect, pointsOnHover, range, selectable, settings, showLegend, stacked, thresholds, title, tone, unit, valueFormat, valueLabels, width, yMax, yMin, zoneToneFor)
import Klar.Chart.Data exposing (byCategory, byDate, dashed, noData, segment, segmentSlot, segmentTone, series, seriesMaybe, withSlot, withTone)
import Klar.Chart.Masks exposing (maskUrl, polygonShape, polylineShape, ringPolygon)
import Klar.Chart.Numbers exposing (compact, dropTrailingZeros, firstJust, formatLabel, formatTick, formatValue, isWhole, missingOr, num, pct, percentText, roundTo, sanitize, smartFormat, stepDecimals, tickGutter, trimFraction)
import Klar.Chart.Shared exposing (categoryElement, dataTable, gridLine, header, legendIfWanted, legendView, maskLayer, plotFrame, shell, stateOf, withState, withStateInside, xLabel, xTick, yLabel)
import Klar.Chart.Texts exposing (summaryLine, texts)
import Klar.Chart.Types exposing (Attribute(..), Axis, Config, Data(..), LegendItem, PSeries, Piece, Prepared, Segment(..), Series(..), Slice, State(..), Texts)
import Klar.Internal as Internal


donut : List (Attribute msg) -> List Segment -> Html msg
donut attributes segments =
    let
        config =
            configure attributes

        t =
            texts config.locale

        positive =
            segments
                |> List.indexedMap (\index (Segment s) -> { label = s.label, value = s.value, color = s.color, tone = s.tone, index = Just index })
                |> List.filter (\s -> s.value > 0)

        folded =
            if List.length positive > 8 then
                let
                    sorted =
                        List.sortBy (\s -> negate s.value) positive

                    rest =
                        List.drop 7 sorted
                in
                List.take 7 sorted
                    ++ [ { label = t.other, value = List.sum (List.map .value rest), color = Just 8, tone = Nothing, index = Nothing } ]

            else
                positive

        total =
            List.sum (List.map .value folded)
    in
    withState config "donut" 168 (total > 0) (\() -> donutBody config folded total)


donutBody : Config msg -> List Slice -> Float -> Html msg
donutBody config slices total =
    let
        t =
            texts config.locale

        classes =
            List.indexedMap (\index s -> colorClass Nothing index s.color s.tone) slices

        share s =
            s.value / total

        shareText s =
            percentText config.locale (share s)

        label =
            String.join ". "
                (List.filter (\x -> x /= "")
                    [ t.donut
                    , Maybe.withDefault "" (firstJust [ config.ariaLabel, config.title ])
                    , t.segmentCount (List.length slices)
                    ]
                )

        sliceTip s =
            s.label ++ ": " ++ formatValue config s.value ++ " (" ++ shareText s ++ ")"

        outer =
            46

        inner =
            32

        -- A 1.6% gap between slices, written as an angle at the outer edge.
        gap =
            if List.length slices > 1 then
                1.6 / outer

            else
                0

        arcs =
            slices
                |> List.foldl
                    (\s ( start, done ) ->
                        let
                            end =
                                start + share s * 2 * pi
                        in
                        ( end, ( s, start, end ) :: done )
                    )
                    ( 0, [] )
                |> Tuple.second
                |> List.reverse

        segmentEls =
            List.map2
                (\cls ( s, start, end ) ->
                    let
                        trim =
                            if end - start > 3 * gap then
                                gap

                            else
                                0
                    in
                    Html.div
                        [ Internal.cls
                            [ "klar-chart__segment"
                            , cls
                            , case sliceMsg s of
                                Just _ ->
                                    "klar-chart__segment--button"

                                Nothing ->
                                    ""
                            ]
                        , Attr.title (sliceTip s)
                        , Internal.styleVars [ ( "clip-path", ringPolygon outer inner (start + trim) (end - trim) ) ]
                        , Internal.attrMaybe Events.onClick (sliceMsg s)
                        ]
                        []
                )
                classes
                arcs

        -- The message of a slice: its position in the given list ("Other" has none).
        sliceMsg s =
            Maybe.map2 (\toMsg index -> toMsg index) config.onSelect s.index

        centerText =
            Maybe.withDefault (formatLabel config total) config.centerLabel

        legendItems =
            List.map2
                (\cls s ->
                    { label = s.label
                    , cls = cls
                    , detail = formatValue config s.value ++ "  ·  " ++ shareText s
                    , dashed = False
                    , select = sliceMsg s
                    }
                )
                classes
                slices
    in
    shell config
        "donut"
        []
        [ header config
        , Html.div [ Internal.cls [ "klar-chart__donut" ] ]
            [ Html.div
                [ Internal.cls [ "klar-chart__donut-frame" ]
                , Attr.attribute "role" "img"
                , Attr.attribute "aria-label" label
                ]
                [ Html.div [ Internal.cls [ "klar-chart__segments" ] ] segmentEls
                , Html.div [ Internal.cls [ "klar-chart__center" ], Attr.attribute "aria-hidden" "true" ]
                    [ Html.span [ Internal.cls [ "klar-chart__center-value" ] ] [ Html.text centerText ]
                    , Internal.viewMaybe (\text -> Html.span [ Internal.cls [ "klar-chart__center-caption" ] ] [ Html.text text ]) config.centerCaption
                    ]
                ]
            , if Maybe.withDefault True config.legend then
                legendView "bar" legendItems

              else if selectable config then
                -- hideLegend with onSelect: the legend buttons are the only
                -- keyboard path to the slices, so they stay, out of sight until
                -- one of them has the focus.
                Html.div [ Internal.cls [ "klar-chart__legend-hidden" ] ] [ legendView "bar" legendItems ]

              else
                Html.text ""
            ]
        , dataTable config
            [ t.category, t.value, t.share ]
            (List.map (\s -> [ s.label, formatValue config s.value, shareText s ]) slices)
        ]
