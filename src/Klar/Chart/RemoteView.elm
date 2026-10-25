module Klar.Chart.RemoteView exposing (..)

{-| Remote-data adapters that keep chart data and category labels together.
-}

import Html exposing (Html)
import Klar.Chart.Bar exposing (bar, barBody, barPlot)
import Klar.Chart.Config exposing (area, ariaLabel, categories, centerCaption, centerLabel, configure, dates, description, emptyText, height, heightOf, hideLegend, horizontal, id, includeZero, legend, locale, maxLabels, onRetry, onSelect, pointsOnHover, range, selectable, settings, showLegend, stacked, thresholds, title, tone, unit, valueFormat, valueLabels, width, yMax, yMin, zoneToneFor)
import Klar.Chart.Data exposing (byCategory, byDate, dashed, noData, segment, segmentSlot, segmentTone, series, seriesMaybe, withSlot, withTone)
import Klar.Chart.Donut exposing (donut, donutBody)
import Klar.Chart.Line exposing (line, lineBody, linePlot)
import Klar.Chart.Scalar exposing (gauge, meter)
import Klar.Chart.Sparkline exposing (sparkline)
import Klar.Chart.Types exposing (Attribute(..), Axis, Config, Data(..), LegendItem, PSeries, Piece, Prepared, Segment(..), Series(..), Slice, State(..), Texts)
import Klar.Internal.Freshness as Freshness exposing (Freshness)
import Klar.Remote as Remote exposing (Problem, Remote)


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


lineRemote : List (Attribute msg) -> Remote Data -> Html msg
lineRemote =
    remoteWith (withData line) noData


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


donutRemote : List (Attribute msg) -> Remote (List Segment) -> Html msg
donutRemote =
    remoteWith donut []


gaugeRemote : List (Attribute msg) -> Remote Float -> Html msg
gaugeRemote =
    remoteWith gauge 0


meterRemote : List (Attribute msg) -> Remote Float -> Html msg
meterRemote =
    remoteWith meter 0


sparklineRemote : List (Attribute msg) -> Remote (List Float) -> Html msg
sparklineRemote =
    remoteWith sparkline []
