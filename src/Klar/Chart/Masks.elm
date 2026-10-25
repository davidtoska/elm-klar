module Klar.Chart.Masks exposing (..)

{-| Pure SVG mask strings and ring geometry, without Html or chart rendering.
-}

import Klar.Chart.Numbers exposing (compact, dropTrailingZeros, firstJust, formatLabel, formatTick, formatValue, isWhole, missingOr, num, pct, percentText, roundTo, sanitize, smartFormat, stepDecimals, tickGutter, trimFraction)


{-| A CSS value that paints a shape: an SVG document, made here from numbers
only, as a data URI. An element uses it as a mask and its background supplies
the color, so the stylesheet owns every color (the same way icons work).
`margin` widens the view box so a stroke at the very edge is not cut off.

The geometry is 0 to 100 in both directions and stretches to the element, so a
chart needs no knowledge of its width.

-}
maskUrl : Float -> String -> String
maskUrl margin shapes =
    let
        start =
            num (negate margin)

        extent =
            num (100 + 2 * margin)
    in
    "url(\"data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='"
        ++ start
        ++ " "
        ++ start
        ++ " "
        ++ extent
        ++ " "
        ++ extent
        ++ "' preserveAspectRatio='none'>"
        ++ shapes
        ++ "</svg>\")"


{-| A stroked line that keeps its width however much the geometry is stretched.
-}
polylineShape : Float -> Bool -> String -> String
polylineShape strokeWidth isDashed coordinates =
    "<polyline points='"
        ++ coordinates
        ++ "' fill='none' stroke='black' stroke-width='"
        ++ num strokeWidth
        ++ "' stroke-linecap='round' stroke-linejoin='round' vector-effect='non-scaling-stroke'"
        ++ (if isDashed then
                " stroke-dasharray='6 4'"

            else
                ""
           )
        ++ "/>"


polygonShape : String -> String
polygonShape coordinates =
    "<polygon points='" ++ coordinates ++ "' fill='black'/>"


{-| A ring sector between two radii, as a `clip-path` polygon. Angles are in
radians from 12 o'clock, clockwise; radii are percentages of the box. The arc
is approximated with a point every 2.5 degrees. A polygon (unlike a mask)
also decides where the pointer hits, so every slice has its own tooltip.
-}
ringPolygon : Float -> Float -> Float -> Float -> String
ringPolygon outer inner a0 a1 =
    let
        sweep =
            a1 - a0

        steps =
            clamp 2 160 (ceiling (sweep / (pi / 72)))

        angleAt k =
            a0 + sweep * toFloat k / toFloat steps

        point radius angle =
            pct (50 + radius * sin angle) ++ " " ++ pct (50 - radius * cos angle)

        outerEdge =
            List.map (\k -> point outer (angleAt k)) (List.range 0 steps)

        innerEdge =
            List.map (\k -> point inner (angleAt k)) (List.reverse (List.range 0 steps))
    in
    if sweep <= 0 then
        "polygon(0% 0%)"

    else
        "polygon(" ++ String.join "," (outerEdge ++ innerEdge) ++ ")"
