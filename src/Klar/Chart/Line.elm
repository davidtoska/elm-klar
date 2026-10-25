module Klar.Chart.Line exposing (..)

{-| Line and area chart rendering from prepared series and axes.
-}

import Array exposing (Array)
import Html exposing (Html)
import Klar.Chart.Axis exposing (axisFor, buildAxis, niceNum, verticalTicks, widen, xPos, yPos)
import Klar.Chart.Config exposing (area, ariaLabel, categories, centerCaption, centerLabel, configure, dates, description, emptyText, height, heightOf, hideLegend, horizontal, id, includeZero, legend, locale, maxLabels, onRetry, onSelect, pointsOnHover, range, selectable, settings, showLegend, stacked, thresholds, title, tone, unit, valueFormat, valueLabels, width, yMax, yMin, zoneToneFor)
import Klar.Chart.Masks exposing (maskUrl, polygonShape, polylineShape, ringPolygon)
import Klar.Chart.Numbers exposing (compact, dropTrailingZeros, firstJust, formatLabel, formatTick, formatValue, isWhole, missingOr, num, pct, percentText, roundTo, sanitize, smartFormat, stepDecimals, tickGutter, trimFraction)
import Klar.Chart.Preparation exposing (barTableRows, barTip, categoryAt, hasAnyValue, horizontalHeight, labelledIndexes, piecesOf, prepare, runs, shortAt, slotTip, tableRows, valueAt)
import Klar.Chart.Shared exposing (categoryElement, dataTable, gridLine, header, legendIfWanted, legendView, maskLayer, plotFrame, shell, stateOf, withState, withStateInside, xLabel, xTick, yLabel)
import Klar.Chart.Texts exposing (summaryLine, texts)
import Klar.Chart.Types exposing (Attribute(..), Axis, Config, Data(..), LegendItem, PSeries, Piece, Prepared, Segment(..), Series(..), Slice, State(..), Texts)
import Klar.Internal as Internal


line : List (Attribute msg) -> List Series -> Html msg
line attributes seriesList =
    let
        config =
            configure attributes

        prepared =
            prepare config seriesList
    in
    withState config "line" (heightOf config 220) (prepared.n > 0 && hasAnyValue prepared) (\() -> lineBody config prepared)


lineBody : Config msg -> Prepared -> Html msg
lineBody config prepared =
    let
        t =
            texts config.locale

        allValues =
            prepared.series
                |> List.concatMap (\s -> Array.toList s.values |> List.filterMap identity)

        axis =
            axisFor (verticalTicks (heightOf config 220)) (config.includeZero || config.area) config.yMin config.yMax allValues

        showPoints =
            not config.pointsOnHover && prepared.n <= 40

        n =
            prepared.n

        every =
            max 1 (ceiling (toFloat n / toFloat (Maybe.withDefault 12 config.maxLabels)))

        slotWidth =
            100 / toFloat n

        xLabels =
            labelledIndexes n every
                |> List.map
                    (\i ->
                        xLabel ((toFloat i + 0.5) * slotWidth) (slotWidth * toFloat every) (categoryAt prepared i) (shortAt prepared i)
                    )

        yLabels =
            List.map (\tick -> yLabel (yPos axis tick) (formatTick config axis tick)) axis.ticks

        label =
            summaryLine config t.line (List.length prepared.series) n
    in
    shell config
        "line"
        []
        [ header config
        , plotFrame config
            (heightOf config 220)
            (tickGutter config axis)
            label
            (linePlot config axis prepared showPoints)
            yLabels
            xLabels
        , legendIfWanted config "line" prepared
        , dataTable config
            (t.category :: List.map .name prepared.series)
            (tableRows config prepared)
        ]


linePlot : Config msg -> Axis -> Prepared -> Bool -> Html msg
linePlot config axis prepared showPoints =
    let
        n =
            prepared.n

        xAt i =
            (toFloat i + 0.5) / toFloat n * 100

        yAt v =
            yPos axis v

        baselineY =
            clamp 0 100 (yPos axis 0)

        pointsOf run =
            run
                |> List.map (\( i, v ) -> num (xAt i) ++ "," ++ num (yAt v))
                |> String.join " "

        seriesLayers s =
            let
                stretches =
                    runs n s.values |> List.filter (\run -> List.length run >= 2)

                lineShapes =
                    List.map (\run -> polylineShape 2 s.dashed (pointsOf run)) stretches

                areaShapes =
                    if config.area then
                        stretches
                            |> List.filterMap
                                (\run ->
                                    case ( List.head run, List.head (List.reverse run) ) of
                                        ( Just ( first, _ ), Just ( last, _ ) ) ->
                                            Just
                                                (polygonShape
                                                    (pointsOf run
                                                        ++ " "
                                                        ++ num (xAt last)
                                                        ++ ","
                                                        ++ num baselineY
                                                        ++ " "
                                                        ++ num (xAt first)
                                                        ++ ","
                                                        ++ num baselineY
                                                    )
                                                )

                                        _ ->
                                            Nothing
                                )

                    else
                        []
            in
            (if List.isEmpty areaShapes then
                []

             else
                [ maskLayer [ "klar-chart__area", s.cls ] (maskUrl 0 (String.concat areaShapes)) ]
            )
                ++ (if List.isEmpty lineShapes then
                        []

                    else
                        [ maskLayer [ "klar-chart__line", s.cls ] (maskUrl 0 (String.concat lineShapes)) ]
                   )

        slot i =
            categoryElement config
                prepared.n
                i
                (slotTip config prepared i)
                []
                (prepared.series
                    |> List.filterMap
                        (\s ->
                            valueAt i s
                                |> Maybe.map
                                    (\v ->
                                        Html.span
                                            [ Internal.cls
                                                [ "klar-chart__point"
                                                , s.cls
                                                , if showPoints && not s.dashed then
                                                    ""

                                                  else
                                                    "klar-chart__point--quiet"
                                                ]
                                            , -- A value outside a fixed axis is pinned to the edge of the plot.
                                              Internal.styleVars [ ( "top", pct (clamp 0 100 (yAt v)) ) ]
                                            ]
                                            []
                                    )
                        )
                )
    in
    Html.div [ Internal.cls [ "klar-chart__plot" ] ]
        (List.map (\tick -> gridLine False "klar-chart__grid" (yAt tick)) axis.ticks
            ++ [ gridLine False "klar-chart__axis" baselineY ]
            ++ List.concatMap seriesLayers prepared.series
            ++ [ Html.div
                    [ Internal.cls [ "klar-chart__slots" ]
                    , Internal.styleVars [ ( "--klar-n", String.fromInt n ) ]
                    ]
                    (List.map slot (List.range 0 (n - 1)))
               ]
        )
