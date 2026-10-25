module Klar.Chart.Axis exposing (..)

{-| Pure nice axis limits, ticks and value-to-percentage coordinates.
-}

import Klar.Chart.Numbers exposing (compact, dropTrailingZeros, firstJust, formatLabel, formatTick, formatValue, isWhole, missingOr, num, pct, percentText, roundTo, sanitize, smartFormat, stepDecimals, tickGutter, trimFraction)
import Klar.Chart.Types exposing (Attribute(..), Axis, Config, Data(..), LegendItem, PSeries, Piece, Prepared, Segment(..), Series(..), Slice, State(..), Texts)


{-| A value axis with "nice" limits and ticks. Fixed limits that cannot make an
axis (a minimum above the maximum, or a limit on the wrong side of the data) are
ignored and the axis follows the data.
-}
axisFor : Int -> Bool -> Maybe Float -> Maybe Float -> List Float -> Axis
axisFor wanted withZero givenMin givenMax values =
    let
        axis =
            buildAxis wanted withZero givenMin givenMax values
    in
    if axis.hi > axis.lo then
        axis

    else
        buildAxis wanted withZero Nothing Nothing values


buildAxis : Int -> Bool -> Maybe Float -> Maybe Float -> List Float -> Axis
buildAxis wanted withZero givenMin givenMax values =
    let
        ( fixedMin, fixedMax ) =
            case ( givenMin, givenMax ) of
                ( Just low, Just high ) ->
                    if low >= high then
                        ( Nothing, Nothing )

                    else
                        ( givenMin, givenMax )

                _ ->
                    ( givenMin, givenMax )

        dataMin =
            List.minimum values |> Maybe.withDefault 0

        dataMax =
            List.maximum values |> Maybe.withDefault 1

        ( low0, high0 ) =
            if withZero then
                ( min 0 dataMin, max 0 dataMax )

            else
                ( dataMin, dataMax )

        low1 =
            Maybe.withDefault low0 fixedMin

        high1 =
            Maybe.withDefault high0 fixedMax

        ( low2, high2 ) =
            widen low1 high1

        range0 =
            niceNum (high2 - low2) False

        step =
            niceNum (range0 / toFloat (max 1 (wanted - 1))) True

        lo =
            case fixedMin of
                Just v ->
                    v

                Nothing ->
                    toFloat (floor (low2 / step + 1.0e-9)) * step

        hi =
            case fixedMax of
                Just v ->
                    v

                Nothing ->
                    toFloat (ceiling (high2 / step - 1.0e-9)) * step

        ( lo2, hi2 ) =
            widen lo hi

        decimals =
            stepDecimals step

        firstTick =
            ceiling (lo2 / step - 1.0e-9)

        lastTick =
            floor (hi2 / step + 1.0e-9)

        ticks =
            List.range firstTick (min lastTick (firstTick + 60))
                |> List.map (\k -> roundTo decimals (toFloat k * step))
    in
    { lo = lo2, hi = hi2, ticks = ticks, decimals = decimals }


{-| How many ticks the vertical axis gets: one per 34 pixels of plot height, at
least two and at most five, so the labels of a low chart do not run into each
other.
-}
verticalTicks : Int -> Int
verticalTicks heightPx =
    clamp 2 5 (heightPx // 34 + 1)


widen : Float -> Float -> ( Float, Float )
widen low high =
    if high - low > 1.0e-12 * max 1 (abs high) then
        ( low, high )

    else if low == 0 && high == 0 then
        ( 0, 1 )

    else
        let
            spread =
                max 1 (abs low * 0.1)
        in
        ( low - spread, high + spread )


niceNum : Float -> Bool -> Float
niceNum x doRound =
    if x <= 0 || isNaN x || isInfinite x then
        1

    else
        let
            exponent =
                toFloat (floor (logBase 10 x))

            base =
                10 ^ exponent

            fraction =
                x / base

            nice =
                if doRound then
                    if fraction < 1.5 then
                        1

                    else if fraction < 3 then
                        2

                    else if fraction < 7 then
                        5

                    else
                        10

                else if fraction <= 1 then
                    1

                else if fraction <= 2 then
                    2

                else if fraction <= 5 then
                    5

                else
                    10
        in
        nice * base


{-| 0 at `hi`, 100 at `lo` (screen y grows downwards).
-}
yPos : Axis -> Float -> Float
yPos axis v =
    clamp -30 130 (100 - 100 * (v - axis.lo) / (axis.hi - axis.lo))


{-| 0 at `lo`, 100 at `hi`.
-}
xPos : Axis -> Float -> Float
xPos axis v =
    clamp -30 130 (100 * (v - axis.lo) / (axis.hi - axis.lo))
