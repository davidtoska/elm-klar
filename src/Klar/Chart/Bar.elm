module Klar.Chart.Bar exposing (..)

{-| Grouped/stacked horizontal and vertical bar chart rendering.
-}

import Html exposing (Html)
import Html.Attributes as Attr
import Klar.Chart.Axis exposing (axisFor, buildAxis, niceNum, verticalTicks, widen, xPos, yPos)
import Klar.Chart.Config exposing (area, ariaLabel, categories, centerCaption, centerLabel, configure, dates, description, emptyText, height, heightOf, hideLegend, horizontal, id, includeZero, legend, locale, maxLabels, onRetry, onSelect, pointsOnHover, range, selectable, settings, showLegend, stacked, thresholds, title, tone, unit, valueFormat, valueLabels, width, yMax, yMin, zoneToneFor)
import Klar.Chart.Numbers exposing (compact, dropTrailingZeros, firstJust, formatLabel, formatTick, formatValue, isWhole, missingOr, num, pct, percentText, roundTo, sanitize, smartFormat, stepDecimals, tickGutter, trimFraction)
import Klar.Chart.Preparation exposing (barTableRows, barTip, categoryAt, hasAnyValue, horizontalHeight, labelledIndexes, piecesOf, prepare, runs, shortAt, slotTip, tableRows, valueAt)
import Klar.Chart.Shared exposing (categoryElement, dataTable, gridLine, header, legendIfWanted, legendView, maskLayer, plotFrame, shell, stateOf, withState, withStateInside, xLabel, xTick, yLabel)
import Klar.Chart.Texts exposing (summaryLine, texts)
import Klar.Chart.Types exposing (Attribute(..), Axis, Config, Data(..), LegendItem, PSeries, Piece, Prepared, Segment(..), Series(..), Slice, State(..), Texts)
import Klar.Internal as Internal


bar : List (Attribute msg) -> List Series -> Html msg
bar attributes seriesList =
    let
        config =
            configure attributes

        prepared =
            prepare config seriesList

        fallbackHeight =
            if config.horizontal then
                horizontalHeight config prepared

            else
                220
    in
    withState config "bar" (heightOf config fallbackHeight) (prepared.n > 0 && hasAnyValue prepared) (\() -> barBody config prepared)


barBody : Config msg -> Prepared -> Html msg
barBody config prepared =
    let
        t =
            texts config.locale

        n =
            prepared.n

        extremes =
            List.range 0 (n - 1)
                |> List.concatMap
                    (\i ->
                        let
                            pieces =
                                piecesOf config prepared i
                        in
                        List.concatMap (\p -> [ p.from, p.to ]) pieces
                    )

        axis =
            axisFor
                (if config.horizontal then
                    5

                 else
                    verticalTicks (heightOf config 220)
                )
                True
                config.yMin
                config.yMax
                extremes

        slotSize =
            100 / toFloat n

        -- A horizontal chart has a row per bar: every bar is named when its row
        -- is at least 14px high. A vertical chart thins its labels to 12.
        every =
            if config.horizontal then
                max (max 1 (ceiling (14 * toFloat n / toFloat heightPx)))
                    (case config.maxLabels of
                        Just most ->
                            ceiling (toFloat n / toFloat most)

                        Nothing ->
                            1
                    )

            else
                max 1 (ceiling (toFloat n / toFloat (Maybe.withDefault 12 config.maxLabels)))

        label =
            summaryLine config t.bar (List.length prepared.series) n

        categoryLabels =
            labelledIndexes n every
                |> List.map
                    (\i ->
                        if config.horizontal then
                            Html.span
                                [ Internal.cls [ "klar-chart__ylabel" ]
                                , Internal.styleVars [ ( "top", pct ((toFloat i + 0.5) * slotSize) ) ]
                                , Attr.title (categoryAt prepared i)
                                ]
                                [ Html.text (categoryAt prepared i) ]

                        else
                            xLabel ((toFloat i + 0.5) * slotSize) (slotSize * toFloat every) (categoryAt prepared i) (shortAt prepared i)
                    )

        tickLabels =
            List.map
                (\tick ->
                    if config.horizontal then
                        xTick (xPos axis tick) (formatTick config axis tick)

                    else
                        yLabel (yPos axis tick) (formatTick config axis tick)
                )
                axis.ticks

        longestCategory =
            List.range 0 (n - 1)
                |> List.map (\i -> String.length (categoryAt prepared i))
                |> List.maximum
                |> Maybe.withDefault 3

        gutter =
            if config.horizontal then
                clamp 48 168 (longestCategory * 7 + 10)

            else
                tickGutter config axis

        ( yLabels, xLabels ) =
            if config.horizontal then
                ( categoryLabels, tickLabels )

            else
                ( tickLabels, categoryLabels )

        heightPx =
            heightOf config
                (if config.horizontal then
                    horizontalHeight config prepared

                 else
                    220
                )

        totalHeader =
            if config.stacked then
                [ t.total ]

            else
                []
    in
    shell config
        "bar"
        []
        [ header config
        , plotFrame config
            heightPx
            gutter
            label
            (barPlot config axis prepared)
            yLabels
            xLabels
        , legendIfWanted config "bar" prepared
        , dataTable config
            (t.category :: List.map .name prepared.series ++ totalHeader)
            (barTableRows config prepared)
        ]


barPlot : Config msg -> Axis -> Prepared -> Html msg
barPlot config axis prepared =
    let
        n =
            prepared.n

        groupCount =
            max 1 (List.length prepared.series)

        horizontalBars =
            config.horizontal

        -- A bar that is longer than a fixed axis ends at the edge of the plot.
        along v =
            clamp 0
                100
                (if horizontalBars then
                    xPos axis v

                 else
                    yPos axis v
                )

        zero =
            clamp 0 100 (along 0)

        barsInView =
            n
                * (if config.stacked then
                    1

                   else
                    groupCount
                  )

        -- Labels need room: skip them when the bars are many.
        roomForLabels =
            config.valueLabels
                && barsInView
                <= (if horizontalBars then
                        60

                    else
                        24
                   )

        drawBar piece =
            let
                a =
                    along piece.from

                b =
                    along piece.to

                near =
                    min a b

                far =
                    max a b

                negative =
                    piece.value < 0

                endClass =
                    if not piece.outer then
                        ""

                    else if horizontalBars then
                        if negative then
                            "klar-chart__bar--left"

                        else
                            "klar-chart__bar--right"

                    else if negative then
                        "klar-chart__bar--down"

                    else
                        "klar-chart__bar--up"

                stackClass =
                    if config.stacked then
                        "klar-chart__bar--stacked "
                            ++ (if negative then
                                    "klar-chart__bar--neg"

                                else
                                    "klar-chart__bar--pos"
                               )

                    else
                        ""
            in
            Html.span
                [ Internal.cls [ "klar-chart__bar", piece.series.cls, endClass, stackClass ]
                , Internal.styleVars
                    (if horizontalBars then
                        [ ( "left", pct near ), ( "right", pct (100 - far) ) ]

                     else
                        [ ( "top", pct near ), ( "bottom", pct (100 - far) ) ]
                    )
                ]
                []

        -- A zero draws nothing: no bar, only its label.
        barSpan piece =
            if piece.value == 0 then
                Html.text ""

            else
                drawBar piece

        -- A label at the end of a bar: `endValue` is where the bar ends (data
        -- units), `shown` is the number written.
        valueLabel endValue shown =
            Html.span
                [ Internal.cls
                    [ "klar-chart__value"
                    , "klar-tabular"
                    , if endValue < 0 then
                        "klar-chart__value--neg"

                      else
                        ""
                    ]
                , Internal.styleVars
                    [ ( if horizontalBars then
                            "left"

                        else
                            "top"
                      , pct (along endValue)
                      )
                    ]
                ]
                [ Html.text (formatLabel config shown) ]

        slot i =
            let
                pieces =
                    piecesOf config prepared i

                lanes =
                    if config.stacked then
                        let
                            total =
                                List.sum (List.map .value pieces)

                            top =
                                List.foldl (\p acc -> max acc (max p.from p.to)) 0 pieces

                            bottom =
                                List.foldl (\p acc -> min acc (min p.from p.to)) 0 pieces
                        in
                        [ Html.span [ Internal.cls [ "klar-chart__lane" ] ]
                            (List.map barSpan pieces
                                ++ (if roomForLabels && not (List.isEmpty pieces) then
                                        [ valueLabel
                                            (if top > 0 then
                                                top

                                             else
                                                bottom
                                            )
                                            total
                                        ]

                                    else
                                        []
                                   )
                            )
                        ]

                    else
                        List.range 0 (groupCount - 1)
                            |> List.map
                                (\index ->
                                    case List.filter (\p -> p.index == index) pieces |> List.head of
                                        Just piece ->
                                            Html.span [ Internal.cls [ "klar-chart__lane" ] ]
                                                (barSpan piece
                                                    :: (if roomForLabels then
                                                            [ valueLabel piece.to piece.value ]

                                                        else
                                                            []
                                                       )
                                                )

                                        Nothing ->
                                            Html.span [ Internal.cls [ "klar-chart__lane" ] ] []
                                )
            in
            categoryElement config
                prepared.n
                i
                (barTip config prepared i)
                []
                [ Html.span [ Internal.cls [ "klar-chart__lanes" ] ] lanes ]
    in
    Html.div
        [ Internal.cls
            [ "klar-chart__plot"
            , if horizontalBars then
                "klar-chart__plot--horizontal"

              else
                ""
            ]
        ]
        (List.map (\tick -> gridLine horizontalBars "klar-chart__grid" (along tick)) axis.ticks
            ++ [ Html.div
                    [ Internal.cls [ "klar-chart__slots", "klar-chart__bars" ]
                    , Internal.styleVars [ ( "--klar-n", String.fromInt n ) ]
                    ]
                    (List.map slot (List.range 0 (n - 1)))
               , gridLine horizontalBars "klar-chart__axis" zero
               ]
        )
