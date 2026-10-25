module Klar.Chart.Data exposing (..)

{-| Series, segments and coordinated category/date data constructors.
-}

import Klar.Chart.Numbers exposing (compact, dropTrailingZeros, firstJust, formatLabel, formatTick, formatValue, isWhole, missingOr, num, pct, percentText, roundTo, sanitize, smartFormat, stepDecimals, tickGutter, trimFraction)
import Klar.Chart.Types exposing (Attribute(..), Axis, Config, Data(..), LegendItem, PSeries, Piece, Prepared, Segment(..), Series(..), Slice, State(..), Texts)
import Klar.Date exposing (Date)
import Klar.Theme as Theme exposing (Tone(..))


{-| A series with a name and its values, in the order of the categories. The
name is shown in the legend, in the tooltips and in the data table.

    Chart.series "2026" [ 14, 20, 15, 25 ]

Values that are not numbers (NaN, infinity) become gaps in the line; use
`seriesMaybe` to leave gaps on purpose.

-}
series : String -> List Float -> Series
series name values =
    Series { name = name, values = List.map sanitize values, color = Nothing, tone = Nothing, dashed = False }


{-| Like `series`, with explicit gaps for missing measurements: a `Nothing`
breaks the line (or leaves out the bar), and the data table shows a dash.

    Chart.seriesMaybe "Temperature" [ Just 4, Just 6, Nothing, Just 9 ]

-}
seriesMaybe : String -> List (Maybe Float) -> Series
seriesMaybe name values =
    Series { name = name, values = List.map (Maybe.andThen sanitize) values, color = Nothing, tone = Nothing, dashed = False }


{-| Gives the series palette slot 1 to 8 instead of the slot that matches its
position in the list. A slot is a place in the chart palette of the theme, not a
[Klar.Color](Klar-Color): a chart has no colors of your own, so it keeps its contrast. Use it to keep a color stable when series come and go.

    Chart.series "Returns" [ 2, 3, 1 ] |> Chart.withSlot 4

-}
withSlot : Int -> Series -> Series
withSlot slot (Series s) =
    Series { s | color = Just slot }


{-| Colors the series by meaning (`Success`, `Warning`, `Danger` ...) instead of
by position. Reserve this for series that really are good or bad, such as "On
time" and "Late". The `Tone` type is in [Klar.Theme](Klar-Theme).
-}
withTone : Tone -> Series -> Series
withTone value (Series s) =
    Series { s | tone = Just value }


{-| Draws the series as a dashed line: for forecasts, targets, last year. It is
meant for line charts, where a dashed series also shows its markers only while
the pointer is over a category.
-}
dashed : Series -> Series
dashed (Series s) =
    Series { s | dashed = True }


{-| A slice of a donut, with a label and a value. The size of a slice is its
value relative to the total of all slices.

    Chart.segment "Shipped" 420

Negative and non-numeric values count as 0, and a slice of 0 is left out.

-}
segment : String -> Float -> Segment
segment label value =
    Segment { label = label, value = Maybe.withDefault 0 (sanitize value) |> max 0, color = Nothing, tone = Nothing }


{-| Gives this slice palette slot 1 to 8 instead of the slot that matches its
position in the list (see `withSlot`).
-}
segmentSlot : Int -> Segment -> Segment
segmentSlot slot (Segment s) =
    Segment { s | color = Just slot }


{-| Colors this slice by meaning (`Success`, `Warning`, `Danger` ...) instead of
by position. Reserve it for slices that really are good or bad.
-}
segmentTone : Tone -> Segment -> Segment
segmentTone value (Segment s) =
    Segment { s | tone = Just value }


{-| Categories named by text, one per value, and the series: what `categories` and
the list of series are to `line` and `bar`.

    Remote.map
        (\rows -> Chart.byCategory (List.map .warehouse rows) [ Chart.series "Orders" (List.map .orders rows) ])
        model.warehouses

-}
byCategory : List String -> List Series -> Data
byCategory names list =
    Data { categories = names, dates = [], series = list }


{-| Categories that are days, one per value, and the series: what `dates` and the
list of series are to `line` and `bar`. The axis writes the days short and the
tooltips write them whole.

    Remote.map
        (\days -> Chart.byDate (List.map .day days) [ Chart.series "Orders" (List.map .count days) ])
        model.orders

-}
byDate : List Date -> List Series -> Data
byDate days list =
    Data { categories = [], dates = days, series = list }


noData : Data
noData =
    Data { categories = [], dates = [], series = [] }
