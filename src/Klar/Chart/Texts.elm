module Klar.Chart.Texts exposing (..)

{-| Localized chart vocabulary and accessible chart summary text.
-}

import Klar.Chart.Data exposing (byCategory, byDate, dashed, noData, segment, segmentSlot, segmentTone, series, seriesMaybe, withSlot, withTone)
import Klar.Chart.Types exposing (Attribute(..), Axis, Config, Data(..), LegendItem, PSeries, Piece, Prepared, Segment(..), Series(..), Slice, State(..), Texts)
import Klar.Format as Format
import Klar.Locale as Locale exposing (Locale)


texts : Locale -> Texts
texts loc =
    let
        pick nb en =
            Locale.pick loc { nb = nb, en = en }

        plural n one other =
            Format.plural loc n { one = one, other = other }
    in
    { noData = pick "Ingen data å vise" "No data to show"
    , loading = pick "Laster diagram" "Loading chart"
    , line = pick "Linjediagram" "Line chart"
    , bar = pick "Stolpediagram" "Bar chart"
    , donut = pick "Smultringdiagram" "Donut chart"
    , gauge = pick "Måler" "Gauge"
    , meter = pick "Måler" "Meter"
    , sparkline = pick "Trend" "Trend"
    , category = pick "Kategori" "Category"
    , value = pick "Verdi" "Value"
    , share = pick "Andel" "Share"
    , total = pick "Totalt" "Total"
    , other = pick "Andre" "Other"
    , tableTruncated = \n -> pick ("... og " ++ Format.int loc n ++ " rader til") ("... and " ++ Format.int loc n ++ " more rows")
    , seriesCount = \n -> Format.int loc n ++ " " ++ plural n (pick "serie" "series") (pick "serier" "series")
    , pointCount = \n -> Format.int loc n ++ " " ++ plural n (pick "punkt" "point") (pick "punkter" "points")
    , segmentCount = \n -> Format.int loc n ++ " " ++ plural n (pick "del" "segment") (pick "deler" "segments")
    , of_ = pick "av" "of"
    , low = pick "lavest" "low"
    , high = pick "høyest" "high"
    , last = pick "siste" "last"
    , noValue = pick "Ingen verdi" "No value"
    }


summaryLine : Config msg -> String -> Int -> Int -> String
summaryLine config kindLabel seriesCount pointCount =
    let
        t =
            texts config.locale

        name =
            case ( config.ariaLabel, config.title ) of
                ( Just label, _ ) ->
                    label

                ( Nothing, Just text ) ->
                    text

                _ ->
                    ""
    in
    String.join ". "
        (List.filter (\s -> s /= "")
            [ kindLabel
            , name
            , t.seriesCount seriesCount ++ ", " ++ t.pointCount pointCount
            ]
        )
