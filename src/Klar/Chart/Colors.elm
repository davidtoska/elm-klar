module Klar.Chart.Colors exposing (..)

{-| Pure palette and semantic-tone class choices for series and scalar charts.
-}

import Klar.Chart.Types exposing (Attribute(..), Axis, Config, Data(..), LegendItem, PSeries, Piece, Prepared, Segment(..), Series(..), Slice, State(..), Texts)
import Klar.Internal as Internal
import Klar.Theme as Theme exposing (Tone(..))


colorClass : Maybe Tone -> Int -> Maybe Int -> Maybe Tone -> String
colorClass chartTone index slot seriesTone =
    case ( seriesTone, slot, chartTone ) of
        ( Just t, _, _ ) ->
            toneClass t

        ( Nothing, Just s, _ ) ->
            "klar-chart-s" ++ String.fromInt (modBy 8 (s - 1))

        ( Nothing, Nothing, Just t ) ->
            if index == 0 then
                toneClass t

            else
                "klar-chart-s" ++ String.fromInt (modBy 8 index)

        _ ->
            "klar-chart-s" ++ String.fromInt (modBy 8 index)


toneClass : Tone -> String
toneClass t =
    "klar-chart-t-" ++ Internal.toneSuffix t


toneClassFor : Config msg -> Maybe Tone -> String
toneClassFor _ maybeTone =
    case maybeTone of
        Just t ->
            toneClass t

        Nothing ->
            toneClass Primary
