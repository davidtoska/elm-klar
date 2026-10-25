module Klar.Chart.Core exposing (..)

{-| Chart implementations behind the representation-stable public documentation facade.
-}

import Array exposing (Array)
import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Events
import Klar.Chart.Axis exposing (axisFor, buildAxis, niceNum, verticalTicks, widen, xPos, yPos)
import Klar.Chart.Bar exposing (bar, barBody, barPlot)
import Klar.Chart.Colors exposing (colorClass, toneClass, toneClassFor)
import Klar.Chart.Config exposing (area, ariaLabel, categories, centerCaption, centerLabel, configure, dates, description, emptyText, height, heightOf, hideLegend, horizontal, id, includeZero, legend, locale, maxLabels, onRetry, onSelect, pointsOnHover, range, selectable, settings, showLegend, stacked, thresholds, title, tone, unit, valueFormat, valueLabels, width, yMax, yMin, zoneToneFor)
import Klar.Chart.Data exposing (byCategory, byDate, dashed, noData, segment, segmentSlot, segmentTone, series, seriesMaybe, withSlot, withTone)
import Klar.Chart.Donut exposing (donut, donutBody)
import Klar.Chart.Line exposing (line, lineBody, linePlot)
import Klar.Chart.Masks exposing (maskUrl, polygonShape, polylineShape, ringPolygon)
import Klar.Chart.Numbers exposing (compact, dropTrailingZeros, firstJust, formatLabel, formatTick, formatValue, isWhole, missingOr, num, pct, percentText, roundTo, sanitize, smartFormat, stepDecimals, tickGutter, trimFraction)
import Klar.Chart.Preparation exposing (barTableRows, barTip, categoryAt, hasAnyValue, horizontalHeight, labelledIndexes, piecesOf, prepare, runs, shortAt, slotTip, tableRows, valueAt)
import Klar.Chart.Scalar exposing (gauge, meter)
import Klar.Chart.Shared exposing (categoryElement, dataTable, gridLine, header, legendIfWanted, legendView, maskLayer, plotFrame, shell, stateOf, withState, withStateInside, xLabel, xTick, yLabel)
import Klar.Chart.Texts exposing (summaryLine, texts)
import Klar.Chart.Types exposing (Attribute(..), Axis, Config, Data(..), LegendItem, PSeries, Piece, Prepared, Segment(..), Series(..), Slice, State(..), Texts)
import Klar.Date exposing (Date)
import Klar.EmptyState as EmptyState
import Klar.ErrorState as ErrorState
import Klar.Format as Format
import Klar.Icon as Icon
import Klar.Internal as Internal
import Klar.Internal.Freshness as Freshness exposing (Freshness)
import Klar.Locale as Locale exposing (Locale)
import Klar.Remote as Remote exposing (Problem, Remote)
import Klar.Settings as Settings exposing (Settings)
import Klar.Skeleton as Skeleton
import Klar.Theme as Theme exposing (Tone(..))


{-| The state of a chart drawn from a `Remote`, and the data to draw when there is
data (`Kept` data counts).
-}
fromRemote : Remote a -> ( Attribute msg, Maybe a )
fromRemote data =
    let
        ( settled, freshness ) =
            Freshness.settle data
    in
    ( Attribute
        (\config ->
            { config
                | busy = Freshness.waiting settled
                , failure =
                    case settled of
                        Remote.Failed problem ->
                            Just problem

                        _ ->
                            Nothing
                , freshness = freshness
                , fromRemote = True
            }
        )
    , case settled of
        Remote.Loaded payload ->
            Just payload

        _ ->
            Nothing
    )


{-| Draws a chart from a `Remote` with the chart function of its kind and the
value to draw while there is nothing.
-}
remoteWith : (List (Attribute msg) -> a -> Html msg) -> a -> List (Attribute msg) -> Remote a -> Html msg
remoteWith draw nothing attributes data =
    let
        ( state, payload ) =
            fromRemote data
    in
    draw (attributes ++ [ state ]) (Maybe.withDefault nothing payload)


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



-- FROM A REMOTE


{-| A line chart from a `Remote`: the skeleton while it loads, the problem with
"Try again" (`onRetry`) when it failed, the empty state, the chart, and the
chart dimmed while it is refreshed or with "Old data from 14:05" when the last
refresh failed. Shape the data with `Remote.map` into a `Data`: the categories
(`byCategory`) or days (`byDate`) and the series together, so they come from the
same response. `categories` and `dates` in the attributes are replaced by those of
the `Data`.

    Chart.lineRemote
        [ Chart.title "Orders per day"
        , Chart.onRetry ReloadOrders
        , Chart.settings model.settings
        ]
        (Remote.map
            (\days -> Chart.byDate (List.map .day days) [ Chart.series "Orders" (List.map .count days) ])
            model.orders
        )

The chart keeps the same elements around it in every state with data, so the
keyboard focus on a category (`onSelect`) survives a refresh. Give it an `id`
to move focus there with `Klar.focus` when "Try again" goes away.

-}
lineRemote : List (Attribute msg) -> Remote Data -> Html msg
lineRemote =
    remoteWith (withData line) noData


{-| A bar chart from a `Remote`, with every state of `lineRemote`.

    Chart.barRemote [ Chart.horizontal, Chart.onRetry ReloadWarehouses ]
        (Remote.map
            (\rows -> Chart.byCategory (List.map .name rows) [ Chart.series "Late orders" (List.map .late rows) ])
            model.warehouses
        )

-}
barRemote : List (Attribute msg) -> Remote Data -> Html msg
barRemote =
    remoteWith (withData bar) noData


{-| Draws a line or bar chart from a `Data`: its categories (or days) come last, so
they replace any given in the attributes.
-}
withData : (List (Attribute msg) -> List Series -> Html msg) -> List (Attribute msg) -> Data -> Html msg
withData draw attributes (Data value) =
    draw
        (attributes ++ [ Attribute (\config -> { config | categories = value.categories, dates = value.dates }) ])
        value.series


{-| A donut from a `Remote`, with every state of `lineRemote`.

    Chart.donutRemote [ Chart.centerCaption "orders", Chart.onRetry ReloadStatuses ]
        (Remote.map (List.map (\s -> Chart.segment s.name s.count)) model.statuses)

-}
donutRemote : List (Attribute msg) -> Remote (List Segment) -> Html msg
donutRemote =
    remoteWith donut []


{-| A gauge from a `Remote`: the skeleton while it loads, the problem with "Try
again" when it failed, and the value (dimmed while it is refreshed, with "Old data
from 14:05" when the last refresh failed).

    Chart.gaugeRemote [ Chart.centerCaption "of capacity", Chart.onRetry Reload ]
        (Remote.map .utilization model.warehouse)

-}
gaugeRemote : List (Attribute msg) -> Remote Float -> Html msg
gaugeRemote =
    remoteWith gauge 0


{-| A meter from a `Remote`, with every state of `gaugeRemote`.

    Chart.meterRemote [ Chart.title "Warehouse fill", Chart.onRetry Reload ]
        (Remote.map .fill model.warehouse)

-}
meterRemote : List (Attribute msg) -> Remote Float -> Html msg
meterRemote =
    remoteWith meter 0


{-| A sparkline from a `Remote`: a skeleton line while it loads, a dash with the
problem as its name when it failed (there is no room for "Try again"), and the line,
dimmed while it is refreshed. Old data says so in its name.

    Chart.sparklineRemote [ Chart.ariaLabel "Orders, last 7 days" ]
        (Remote.map .lastWeek model.orders)

-}
sparklineRemote : List (Attribute msg) -> Remote (List Float) -> Html msg
sparklineRemote =
    remoteWith sparkline []
