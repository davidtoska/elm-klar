module Klar.Chart.Data exposing (..)

{-| Series, segments and coordinated category/date data constructors.
-}

import Klar.Chart.Numbers exposing (compact, dropTrailingZeros, firstJust, formatLabel, formatTick, formatValue, isWhole, missingOr, num, pct, percentText, roundTo, sanitize, smartFormat, stepDecimals, tickGutter, trimFraction)
import Klar.Chart.Types exposing (Attribute(..), Axis, Config, Data(..), LegendItem, PSeries, Piece, Prepared, Segment(..), Series(..), Slice, State(..), Texts)
import Klar.Date exposing (Date)
import Klar.Theme as Theme exposing (Tone(..))


series : String -> List Float -> Series
series name values =
    Series { name = name, values = List.map sanitize values, color = Nothing, tone = Nothing, dashed = False }


seriesMaybe : String -> List (Maybe Float) -> Series
seriesMaybe name values =
    Series { name = name, values = List.map (Maybe.andThen sanitize) values, color = Nothing, tone = Nothing, dashed = False }


withSlot : Int -> Series -> Series
withSlot slot (Series s) =
    Series { s | color = Just slot }


withTone : Tone -> Series -> Series
withTone value (Series s) =
    Series { s | tone = Just value }


dashed : Series -> Series
dashed (Series s) =
    Series { s | dashed = True }


segment : String -> Float -> Segment
segment label value =
    Segment { label = label, value = Maybe.withDefault 0 (sanitize value) |> max 0, color = Nothing, tone = Nothing }


segmentSlot : Int -> Segment -> Segment
segmentSlot slot (Segment s) =
    Segment { s | color = Just slot }


segmentTone : Tone -> Segment -> Segment
segmentTone value (Segment s) =
    Segment { s | tone = Just value }


byCategory : List String -> List Series -> Data
byCategory names list =
    Data { categories = names, dates = [], series = list }


byDate : List Date -> List Series -> Data
byDate days list =
    Data { categories = [], dates = days, series = list }


noData : Data
noData =
    Data { categories = [], dates = [], series = [] }
