module Klar.Chart.Sparkline exposing (..)

{-| Compact trend rendering with its full remote/freshness states.
-}

import Html exposing (Html)
import Html.Attributes as Attr
import Klar.Chart.Colors exposing (colorClass, toneClass, toneClassFor)
import Klar.Chart.Config exposing (area, ariaLabel, categories, centerCaption, centerLabel, configure, dates, description, emptyText, height, heightOf, hideLegend, horizontal, id, includeZero, legend, locale, maxLabels, onRetry, onSelect, pointsOnHover, range, selectable, settings, showLegend, stacked, thresholds, title, tone, unit, valueFormat, valueLabels, width, yMax, yMin, zoneToneFor)
import Klar.Chart.Masks exposing (maskUrl, polygonShape, polylineShape, ringPolygon)
import Klar.Chart.Numbers exposing (compact, dropTrailingZeros, firstJust, formatLabel, formatTick, formatValue, isWhole, missingOr, num, pct, percentText, roundTo, sanitize, smartFormat, stepDecimals, tickGutter, trimFraction)
import Klar.Chart.Shared exposing (categoryElement, dataTable, gridLine, header, legendIfWanted, legendView, maskLayer, plotFrame, shell, stateOf, withState, withStateInside, xLabel, xTick, yLabel)
import Klar.Chart.Texts exposing (summaryLine, texts)
import Klar.Chart.Types exposing (Attribute(..), Axis, Config, Data(..), LegendItem, PSeries, Piece, Prepared, Segment(..), Series(..), Slice, State(..), Texts)
import Klar.Internal as Internal
import Klar.Internal.Freshness as Freshness exposing (Freshness)
import Klar.Remote as Remote exposing (Problem, Remote)
import Klar.Skeleton as Skeleton


{-| A tiny trend line without axes, for a table cell or a tile (see
[Klar.Stat](Klar-Stat)). The last value gets a dot. It needs no categories; give it
an `ariaLabel` that says what it shows, because a sparkline has no title.

    Chart.sparkline
        [ Chart.ariaLabel "Orders, last 7 days", Chart.area, Chart.height 32 ]
        [ 3, 5, 4, 8, 7, 9, 12 ]

Values that are not numbers are left out. With one value there is only the dot,
with none a dash. The default height is 28px and the width fills the container
(see `width`).

-}
sparkline : List (Attribute msg) -> List Float -> Html msg
sparkline attributes rawValues =
    let
        config =
            configure attributes

        t =
            texts config.locale

        values =
            List.filterMap sanitize rawValues

        n =
            List.length values

        low =
            List.minimum values |> Maybe.withDefault 0

        high =
            List.maximum values |> Maybe.withDefault 0

        yAt v =
            if high - low <= 0 then
                50

            else
                100 - 100 * (v - low) / (high - low)

        xAt i =
            if n <= 1 then
                50

            else
                100 * toFloat i / toFloat (n - 1)

        coordinates =
            List.indexedMap (\i v -> ( xAt i, yAt v )) values

        pointList =
            coordinates
                |> List.map (\( x, y ) -> num x ++ "," ++ num y)
                |> String.join " "

        cls =
            case config.tone of
                Just tn ->
                    toneClass tn

                Nothing ->
                    "klar-chart-s0"

        lastValue =
            List.reverse values |> List.head |> Maybe.withDefault 0

        ( lastX, lastY ) =
            List.reverse coordinates |> List.head |> Maybe.withDefault ( 50, 50 )

        -- The mask is a little larger than the data, so a stroke at the very
        -- edge is not cut off; the dot is placed in the same widened box.
        margin =
            4

        inBox v =
            pct ((v + margin) / (100 + 2 * margin) * 100)

        layers =
            (if config.area && n >= 2 then
                [ maskLayer [ "klar-chart__area", cls ] (maskUrl margin (polygonShape (pointList ++ " 100,100 0,100"))) ]

             else
                []
            )
                ++ (if n >= 2 then
                        [ maskLayer [ "klar-chart__line", "klar-chart__line--thin", cls ] (maskUrl margin (polylineShape 1.5 False pointList)) ]

                    else
                        []
                   )

        -- The numbers are always in the name: an `ariaLabel` says what the line
        -- shows, the summary what it says.
        numbers =
            t.pointCount n
                ++ ", "
                ++ t.low
                ++ " "
                ++ formatValue config low
                ++ ", "
                ++ t.high
                ++ " "
                ++ formatValue config high
                ++ ", "
                ++ t.last
                ++ " "
                ++ formatValue config lastValue

        summary =
            case config.ariaLabel of
                Just label ->
                    label ++ ". " ++ numbers

                Nothing ->
                    t.sparkline ++ ": " ++ numbers

        boxStyle =
            Internal.styleVars
                (List.filterMap identity
                    [ Maybe.map (\w -> ( "--klar-chart-w", Internal.px w )) config.width
                    , Just ( "--klar-chart-sh", Internal.px (heightOf config 28) )
                    ]
                )

        idAttrs =
            case config.id of
                Just domId ->
                    [ Attr.id domId, Attr.tabindex -1 ]

                Nothing ->
                    []
    in
    case stateOf config of
        Busy ->
            Html.span ([ Internal.cls [ "klar-chart-spark", "klar-chart-spark--loading" ], boxStyle, Attr.attribute "aria-busy" "true" ] ++ idAttrs)
                [ Skeleton.line 100 ]

        Failed problem ->
            Html.span
                ([ Internal.cls [ "klar-chart-spark", "klar-chart-spark--empty" ]
                 , boxStyle
                 , Attr.attribute "role" "img"
                 , Attr.attribute "aria-label" (Remote.title config.locale problem)
                 , Attr.title (Remote.title config.locale problem)
                 ]
                    ++ idAttrs
                )
                [ Html.span [ Attr.attribute "aria-hidden" "true" ] [ Html.text "–" ] ]

        Ready ->
            if n == 0 then
                let
                    emptyLabel =
                        Maybe.withDefault t.noData config.emptyText
                in
                Html.span
                    ([ Internal.cls [ "klar-chart-spark", "klar-chart-spark--empty" ]
                     , boxStyle
                     , Attr.attribute "role" "img"
                     , Attr.attribute "aria-label" emptyLabel
                     , Attr.title emptyLabel
                     ]
                        ++ idAttrs
                    )
                    [ Html.span [ Attr.attribute "aria-hidden" "true" ] [ Html.text "–" ] ]

            else
                let
                    described =
                        case config.freshness of
                            Freshness.Stale value ->
                                summary ++ ". " ++ Freshness.text config.locale config.settings value.at

                            _ ->
                                summary
                in
                Html.span
                    ([ Internal.cls [ "klar-chart-spark", Freshness.className config.freshness ]
                     , boxStyle
                     , Attr.attribute "role" "img"
                     , Attr.attribute "aria-label" described
                     , Attr.title described
                     , Freshness.busyAttr config.freshness
                     ]
                        ++ idAttrs
                    )
                    [ Html.span [ Internal.cls [ "klar-chart-spark__field" ] ]
                        (layers
                            ++ [ Html.span
                                    [ Internal.cls [ "klar-chart__point", "klar-chart__point--last", cls ]
                                    , Internal.styleVars [ ( "left", inBox lastX ), ( "top", inBox lastY ) ]
                                    ]
                                    []
                               ]
                        )
                    ]
