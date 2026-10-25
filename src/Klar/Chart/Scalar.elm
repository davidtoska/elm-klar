module Klar.Chart.Scalar exposing (..)

{-| Gauge and meter rendering against a configured measurement range.
-}

import Html exposing (Html)
import Html.Attributes as Attr
import Klar.Chart.Colors exposing (colorClass, toneClass, toneClassFor)
import Klar.Chart.Config exposing (area, ariaLabel, categories, centerCaption, centerLabel, configure, dates, description, emptyText, height, heightOf, hideLegend, horizontal, id, includeZero, legend, locale, maxLabels, onRetry, onSelect, pointsOnHover, range, selectable, settings, showLegend, stacked, thresholds, title, tone, unit, valueFormat, valueLabels, width, yMax, yMin, zoneToneFor)
import Klar.Chart.Numbers exposing (compact, dropTrailingZeros, firstJust, formatLabel, formatTick, formatValue, isWhole, missingOr, num, pct, percentText, roundTo, sanitize, smartFormat, stepDecimals, tickGutter, trimFraction)
import Klar.Chart.Shared exposing (categoryElement, dataTable, gridLine, header, legendIfWanted, legendView, maskLayer, plotFrame, shell, stateOf, withState, withStateInside, xLabel, xTick, yLabel)
import Klar.Chart.Texts exposing (summaryLine, texts)
import Klar.Chart.Types exposing (Attribute(..), Axis, Config, Data(..), LegendItem, PSeries, Piece, Prepared, Segment(..), Series(..), Slice, State(..), Texts)
import Klar.Internal as Internal
import Klar.Theme as Theme exposing (Tone(..))


{-| A half-circle gauge for one value against a scale (see `range`; the default
is 0 to 100). The zone the value falls in (see `thresholds`) decides the color.

    Chart.gauge [ Chart.centerCaption "of capacity", Chart.unit "%" ] 82

The value is written in the middle unless `centerLabel` says otherwise. A value
outside the scale fills the arc completely or not at all but is written as it is.
A value that is not a number (NaN, infinity) is a missing measurement: the arc
stays empty, the middle shows a dash and screen readers hear "No value".

-}
gauge : List (Attribute msg) -> Float -> Html msg
gauge attributes rawValue =
    let
        config =
            configure attributes

        t =
            texts config.locale

        measured =
            sanitize rawValue

        value =
            Maybe.withDefault config.rangeMin measured

        low =
            min config.rangeMin config.rangeMax

        high =
            max config.rangeMin config.rangeMax

        fractionOf v =
            if high - low <= 0 then
                0

            else
                clamp 0 1 ((v - low) / (high - low))

        cls =
            toneClassFor config (zoneToneFor config value)

        zoneMarks =
            config.thresholds
                |> List.map (\( limit, _ ) -> fractionOf limit)
                |> List.filter (\f -> f > 0.001 && f < 0.999)
                |> List.map
                    (\f ->
                        Html.span
                            [ Internal.cls [ "klar-chart__gauge-mark" ]
                            , Internal.styleVars [ ( "--klar-f", String.fromFloat (roundTo 3 f) ) ]
                            ]
                            []
                    )

        ( valueText, spokenValue ) =
            missingOr t measured (\v -> Maybe.withDefault (formatValue config v) config.centerLabel)

        label =
            String.join ". "
                (List.filter (\x -> x /= "")
                    [ Maybe.withDefault "" (firstJust [ config.ariaLabel, config.title ])
                    , Maybe.withDefault t.gauge config.centerCaption
                    ]
                )
    in
    withState config
        "gauge"
        110
        True
        (\() ->
            shell config
                "gauge"
                []
                [ header config
                , Html.div
                    [ Internal.cls [ "klar-chart__gauge" ]
                    , Attr.attribute "role" "meter"
                    , Attr.attribute "aria-label" label
                    , Attr.attribute "aria-valuemin" (String.fromFloat low)
                    , Attr.attribute "aria-valuemax" (String.fromFloat high)
                    , Attr.attribute "aria-valuenow" (String.fromFloat (clamp low high value))
                    , Attr.attribute "aria-valuetext" spokenValue
                    ]
                    ([ Html.div
                        [ Internal.cls [ "klar-chart__gauge-arc", cls ]
                        , Internal.styleVars
                            [ ( "--klar-f"
                              , case measured of
                                    Just _ ->
                                        String.fromFloat (roundTo 3 (fractionOf value))

                                    Nothing ->
                                        "0"
                              )
                            ]
                        , Attr.title spokenValue
                        ]
                        []
                     ]
                        ++ zoneMarks
                        ++ [ Html.div [ Internal.cls [ "klar-chart__center", "klar-chart__center--gauge" ] ]
                                [ Html.span [ Internal.cls [ "klar-chart__center-value" ] ] [ Html.text valueText ]
                                , Internal.viewMaybe (\text -> Html.span [ Internal.cls [ "klar-chart__center-caption" ] ] [ Html.text text ]) config.centerCaption
                                ]
                           , Html.div [ Internal.cls [ "klar-chart__gauge-scale", "klar-tabular" ], Attr.attribute "aria-hidden" "true" ]
                                [ Html.span [] [ Html.text (formatLabel config low) ]
                                , Html.span [] [ Html.text (formatLabel config high) ]
                                ]
                           ]
                    )
                ]
        )


{-| A horizontal meter: the value as a marker on a scale with zones.

    Chart.meter
        [ Chart.range 0 100
        , Chart.title "Warehouse fill"
        , Chart.thresholds [ ( 70, Success ), ( 90, Warning ), ( 100, Danger ) ]
        ]
        84

The title and the value are written above the track, and the two ends of the
scale below it. A meter is flat and as wide as its container, so it fits where
a gauge would take too much room. A value that is not a number is a missing
measurement: the value is a dash, the track has no marker and screen readers hear
"No value".

-}
meter : List (Attribute msg) -> Float -> Html msg
meter attributes rawValue =
    let
        config =
            configure attributes

        t =
            texts config.locale

        measured =
            sanitize rawValue

        value =
            Maybe.withDefault config.rangeMin measured

        low =
            min config.rangeMin config.rangeMax

        high =
            max config.rangeMin config.rangeMax

        position v =
            if high - low <= 0 then
                0

            else
                clamp 0 100 (100 * (v - low) / (high - low))

        zones =
            case config.thresholds of
                [] ->
                    [ ( high, Maybe.withDefault Primary config.tone ) ]

                list ->
                    list

        zoneStarts =
            low :: List.map Tuple.first zones

        zoneViews =
            List.map2
                (\start ( limit, zoneTone ) ->
                    Html.span
                        [ Internal.cls [ "klar-meter__zone", toneClass zoneTone ]
                        , Internal.styleVars [ ( "left", pct (position start) ), ( "width", pct (max 0 (position limit - position start)) ) ]
                        ]
                        []
                )
                zoneStarts
                zones

        current =
            zoneToneFor config value |> Maybe.withDefault Primary

        ( valueText, spokenValue ) =
            missingOr t measured (\v -> Maybe.withDefault (formatValue config v) config.centerLabel)

        name =
            Maybe.withDefault t.meter (firstJust [ config.ariaLabel, config.title ])
    in
    withState config
        "meter"
        40
        True
        (\() ->
            Html.figure
                [ Internal.cls [ "klar-chart", "klar-chart--meter" ]
                , Attr.attribute "role" "meter"
                , Attr.attribute "aria-label" name
                , Attr.attribute "aria-valuemin" (String.fromFloat low)
                , Attr.attribute "aria-valuemax" (String.fromFloat high)
                , Attr.attribute "aria-valuenow" (String.fromFloat (clamp low high value))
                , Attr.attribute "aria-valuetext" spokenValue
                ]
                [ Html.div [ Internal.cls [ "klar-meter__head" ] ]
                    [ Html.span [ Internal.cls [ "klar-meter__label" ] ] [ Html.text (Maybe.withDefault "" config.title) ]
                    , Html.span [ Internal.cls [ "klar-meter__value", "klar-tabular", toneClass current ] ] [ Html.text valueText ]
                    ]
                , Html.div [ Internal.cls [ "klar-meter__track" ], Attr.attribute "aria-hidden" "true" ]
                    (zoneViews
                        ++ (case measured of
                                Just _ ->
                                    [ Html.span
                                        [ Internal.cls [ "klar-meter__marker", toneClass current ]
                                        , Internal.styleVars [ ( "left", pct (position value) ) ]
                                        ]
                                        []
                                    ]

                                Nothing ->
                                    []
                           )
                    )
                , Html.div [ Internal.cls [ "klar-meter__scale", "klar-tabular" ], Attr.attribute "aria-hidden" "true" ]
                    [ Html.span [] [ Html.text (formatLabel config low) ]
                    , Html.span [] [ Html.text (formatLabel config high) ]
                    ]
                ]
        )
