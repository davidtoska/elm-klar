module Klar.Chart.Numbers exposing (..)

{-| Pure finite-value handling, locale-aware formatting and numeric chart measurements.
-}

import Klar.Chart.Types exposing (Attribute(..), Axis, Config, Data(..), LegendItem, PSeries, Piece, Prepared, Segment(..), Series(..), Slice, State(..), Texts)
import Klar.Format as Format
import Klar.Locale as Locale exposing (Locale)


sanitize : Float -> Maybe Float
sanitize value =
    if isNaN value || isInfinite value then
        Nothing

    else
        Just (clamp -1.0e15 1.0e15 value)


{-| A number that is safe to write into an SVG attribute.
-}
num : Float -> String
num x =
    if isNaN x || isInfinite x then
        "0"

    else
        String.fromFloat (toFloat (round (clamp -100000 100000 x * 100)) / 100)


pct : Float -> String
pct x =
    num x ++ "%"


stepDecimals : Float -> Int
stepDecimals step =
    if step >= 1 then
        0

    else
        clamp 0 8 (ceiling (negate (logBase 10 step) - 1.0e-9))


roundTo : Int -> Float -> Float
roundTo decimals x =
    let
        factor =
            10 ^ toFloat decimals
    in
    toFloat (round (x * factor)) / factor


isWhole : Float -> Bool
isWhole v =
    abs (v - toFloat (round v)) < 1.0e-9 * max 1 (abs v)


{-| A value for tooltips and the data table: as many decimals as it needs,
at most a handful.
-}
smartFormat : Locale -> Float -> String
smartFormat loc v =
    let
        a =
            abs v

        decimals =
            if isWhole v || a == 0 then
                0

            else if a >= 100 then
                1

            else if a >= 1 then
                2

            else
                clamp 2 6 (ceiling (negate (logBase 10 a)) + 1)
    in
    if a >= 1.0e15 then
        compact loc v

    else
        trimFraction loc (Format.decimal loc decimals v)


{-| "12.5%" from the ratio 0.125, in the number format of the locale.
-}
percentText : Locale -> Float -> String
percentText loc ratio =
    trimFraction loc (Format.decimal loc 1 (ratio * 100))
        ++ Locale.pick loc { nb = "\u{00A0}%", en = "%" }


{-| "2.5M" for 2500000, with the unit names of the locale. Used for axis labels of
large numbers.
-}
compact : Locale -> Float -> String
compact loc v =
    let
        a =
            abs v

        scaled divisor suffix =
            trimFraction loc (Format.decimal loc 1 (v / divisor)) ++ suffix

        -- 999 960 000 would be written "1,000M": it rounds up to the next unit.
        roundsUp divisor =
            toFloat (round (a / divisor * 10)) / 10 >= 1000

        billions =
            scaled 1.0e12 (Locale.pick loc { nb = " bill.", en = "T" })

        milliards =
            scaled 1.0e9 (Locale.pick loc { nb = " mrd.", en = "B" })

        millions =
            scaled 1.0e6 (Locale.pick loc { nb = " mill.", en = "M" })
    in
    if a >= 1.0e12 then
        billions

    else if a >= 1.0e9 then
        if roundsUp 1.0e9 then
            billions

        else
            milliards

    else if a >= 1.0e6 then
        if roundsUp 1.0e6 then
            milliards

        else
            millions

    else
        smartFormat loc v


trimFraction : Locale -> String -> String
trimFraction loc text =
    let
        separator =
            Locale.decimalSeparator loc
    in
    case String.split separator text of
        [ whole, fraction ] ->
            let
                kept =
                    dropTrailingZeros fraction
            in
            if kept == "" then
                whole

            else
                whole ++ separator ++ kept

        _ ->
            text


dropTrailingZeros : String -> String
dropTrailingZeros text =
    if String.endsWith "0" text then
        dropTrailingZeros (String.dropRight 1 text)

    else
        text


{-| A value with the chart's unit, for tooltips and the data table.
-}
formatValue : Config msg -> Float -> String
formatValue config v =
    case config.valueFormat of
        Just format ->
            format v

        Nothing ->
            smartFormat config.locale v
                ++ (if config.unit == "" then
                        ""

                    else
                        "\u{00A0}" ++ config.unit
                   )


{-| A value on an axis: compact, with the decimals the tick step needs.
-}
formatTick : Config msg -> Axis -> Float -> String
formatTick config axis v =
    case config.valueFormat of
        Just format ->
            format v

        Nothing ->
            if abs v >= 1.0e6 then
                compact config.locale v

            else
                Format.decimal config.locale axis.decimals v


{-| Short value for labels on bars.
-}
formatLabel : Config msg -> Float -> String
formatLabel config v =
    case config.valueFormat of
        Just format ->
            format v

        Nothing ->
            if abs v >= 1.0e6 then
                compact config.locale v

            else
                smartFormat config.locale v


tickGutter : Config msg -> Axis -> Int
tickGutter config axis =
    axis.ticks
        |> List.map (\t -> String.length (formatTick config axis t))
        |> List.maximum
        |> Maybe.withDefault 3
        |> (\chars -> chars * 7 + 8)
        |> clamp 28 180


{-| The shown and the spoken text of the value of a gauge or meter: an en dash and
"No value" for a missing measurement.
-}
missingOr : Texts -> Maybe Float -> (Float -> String) -> ( String, String )
missingOr t measured written =
    case measured of
        Just v ->
            ( written v, written v )

        Nothing ->
            ( "–", t.noValue )


firstJust : List (Maybe a) -> Maybe a
firstJust maybes =
    case maybes of
        [] ->
            Nothing

        (Just x) :: _ ->
            Just x

        Nothing :: rest ->
            firstJust rest
