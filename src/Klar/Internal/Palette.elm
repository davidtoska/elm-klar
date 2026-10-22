module Klar.Internal.Palette exposing
    ( Color
    , Spec
    , contrast
    , css
    , declarations
    , scale
    , specs
    )

{-| The colors of the themes, computed in Elm.

A theme is a few numbers (a hue for the accent, a hue and a saturation for the
neutrals). The scales that the stylesheet is made of (`--klar-gray-*`,
`--klar-blue-*`, the status colors) are computed from them with fixed lightness
tables, one for each of light, dark, high contrast light and high contrast dark.
The semantic tokens (`--klar-text`, `--klar-surface`, ...) are left alone: they
point at the scales, so a new scale restyles every component.

The lightness tables are chosen so that the pairs of the library keep WCAG AA in
every theme; `tests/ThemeTest.elm` checks it for all of them.

-}


type alias Color =
    { h : Float, s : Float, l : Float }


type alias Spec =
    { key : String
    , name : String
    , accentHue : Float
    , accentSat : Float
    , neutralHue : Float
    , neutralSat : Float
    , strong : Bool
    , plain : Bool
    }


{-| The ten themes, in the order they are offered. The first one is the stylesheet
as it is: in light mode it adds nothing.
-}
specs : List Spec
specs =
    [ { key = "klar", name = "Klar", accentHue = 212, accentSat = 1, neutralHue = 213, neutralSat = 15, strong = False, plain = True }
    , { key = "ocean", name = "Ocean", accentHue = 196, accentSat = 0.95, neutralHue = 200, neutralSat = 14, strong = False, plain = False }
    , { key = "teal", name = "Teal", accentHue = 176, accentSat = 0.9, neutralHue = 180, neutralSat = 12, strong = False, plain = False }
    , { key = "indigo", name = "Indigo", accentHue = 234, accentSat = 1, neutralHue = 232, neutralSat = 14, strong = False, plain = False }
    , { key = "violet", name = "Violet", accentHue = 262, accentSat = 1, neutralHue = 260, neutralSat = 12, strong = False, plain = False }
    , { key = "plum", name = "Plum", accentHue = 292, accentSat = 0.75, neutralHue = 290, neutralSat = 9, strong = False, plain = False }
    , { key = "slate", name = "Slate", accentHue = 212, accentSat = 0.3, neutralHue = 212, neutralSat = 10, strong = False, plain = False }
    , { key = "graphite", name = "Graphite", accentHue = 220, accentSat = 0.05, neutralHue = 220, neutralSat = 3, strong = False, plain = False }
    , { key = "sand", name = "Sand", accentHue = 205, accentSat = 0.9, neutralHue = 38, neutralSat = 10, strong = False, plain = False }
    , { key = "contrast", name = "Contrast", accentHue = 220, accentSat = 1, neutralHue = 220, neutralSat = 0, strong = True, plain = False }
    ]



-- THE SCALES


neutralSteps : List String
neutralSteps =
    [ "25", "50", "100", "150", "200", "300", "400", "500", "600", "700", "800", "900" ]


accentSteps : List String
accentSteps =
    [ "50", "100", "200", "300", "400", "500", "600", "700", "800", "900" ]


statusSteps : List String
statusSteps =
    [ "50", "100", "500", "600", "700" ]


neutralLightness : Bool -> Bool -> List Float
neutralLightness strong dark =
    case ( strong, dark ) of
        ( False, False ) ->
            [ 98.5, 96.5, 94, 91.5, 88, 82, 66, 54, 42.5, 31, 21.5, 13 ]

        ( False, True ) ->
            [ 12, 10, 7.5, 19, 24, 33, 46, 58, 70, 80, 88, 94 ]

        ( True, False ) ->
            [ 99, 97, 94, 88, 58, 45, 40, 36, 25, 18, 12, 5 ]

        ( True, True ) ->
            [ 4, 0, 9, 22, 52, 66, 72, 78, 86, 92, 96, 100 ]


whiteLightness : Bool -> Bool -> Float
whiteLightness strong dark =
    case ( strong, dark ) of
        ( _, False ) ->
            100

        ( False, True ) ->
            14

        ( True, True ) ->
            7


accentLightness : Bool -> Bool -> List Float
accentLightness strong dark =
    case ( strong, dark ) of
        ( False, False ) ->
            [ 96, 92.5, 86, 75, 60, 47, 39, 31, 24, 17 ]

        ( False, True ) ->
            [ 16, 22, 30, 44, 58, 66, 71, 77, 83, 91 ]

        ( True, False ) ->
            [ 95, 90, 80, 60, 40, 30, 24, 19, 14, 9 ]

        ( True, True ) ->
            [ 8, 14, 24, 50, 68, 78, 84, 89, 93, 96 ]


accentSaturation : List Float
accentSaturation =
    [ 60, 62, 58, 55, 60, 62, 78, 82, 82, 82 ]


{-| Hue, saturation and the lightness of the steps 50, 100, 500, 600 and 700.
-}
statusColors : Bool -> Bool -> String -> ( Float, Float, List Float )
statusColors strong dark name =
    let
        lightness =
            case ( strong, dark ) of
                ( True, False ) ->
                    [ 94, 85, 30, 24, 18 ]

                ( False, True ) ->
                    [ 14, 20, 50, 63, 74 ]

                _ ->
                    [ 8, 16, 55, 68, 80 ]
    in
    case name of
        "green" ->
            ( 150, saturationOf strong dark 85 38, lightness )

        "amber" ->
            ( 40, saturationOf strong dark 95 65, lightness )

        _ ->
            ( 5, saturationOf strong dark 80 62, lightness )


saturationOf : Bool -> Bool -> Float -> Float -> Float
saturationOf strong dark forStrongLight forDark =
    if strong && not dark then
        forStrongLight

    else
        forDark


{-| Every color the theme sets, by token name without the `--klar-` (`gray-50`,
`blue-600`, `white`, `green-50`). A light theme that is not high contrast leaves out
the status colors: the stylesheet's own stay.
-}
scale : Spec -> Bool -> List ( String, Color )
scale spec dark =
    let
        neutralColor l =
            { h = spec.neutralHue
            , s =
                if dark && l > 60 then
                    spec.neutralSat * 0.6

                else
                    spec.neutralSat
            , l = l
            }

        neutrals =
            ( "white", neutralColor (whiteLightness spec.strong dark) )
                :: List.map2 (\step l -> ( "gray-" ++ step, neutralColor l ))
                    neutralSteps
                    (neutralLightness spec.strong dark)

        accents =
            List.map3
                (\step l s -> ( "blue-" ++ step, { h = spec.accentHue, s = min 100 (s * spec.accentSat), l = l } ))
                accentSteps
                (accentLightness spec.strong dark)
                accentSaturation

        status name =
            let
                ( h, s, lightness ) =
                    statusColors spec.strong dark name
            in
            List.map2 (\step l -> ( name ++ "-" ++ step, { h = h, s = s, l = l } )) statusSteps lightness
    in
    (neutrals
        ++ accents
        ++ (if dark || spec.strong then
                List.concatMap status [ "green", "amber", "red" ]

            else
                []
           )
    )
        |> (if dark then
                identity

            else
                fitLight
           )


{-| A light scale is drawn from lightness tables, but the same lightness is brighter
in some hues (yellow green, cyan) than in others. So the text steps are darkened
until the pairs of the library reach 4.6 : 1 (WCAG asks 4.5), and the steps after
them follow, so the order of the scale holds.
-}
fitLight : List ( String, Color ) -> List ( String, Color )
fitLight colors =
    let
        get name =
            colors
                |> List.filter (\( n, _ ) -> n == name)
                |> List.head
                |> Maybe.map Tuple.second
                |> Maybe.withDefault { h = 0, s = 0, l = 0 }

        white =
            get "white"

        gray50 =
            get "gray-50"

        gray100 =
            get "gray-100"

        blue50 =
            get "blue-50"

        darken ok c =
            if ok c || c.l <= 1 then
                c

            else
                darken ok { c | l = c.l - 0.5 }

        below gap previous c =
            if c.l > previous.l - gap then
                { c | l = previous.l - gap }

            else
                c

        gray600 =
            darken (\c -> contrast c gray100 >= 4.6 && contrast c white >= 4.6) (get "gray-600")

        gray700 =
            below 8 gray600 (get "gray-700")

        gray800 =
            below 8 gray700 (get "gray-800")

        gray900 =
            below 6 gray800 (get "gray-900")

        blue600 =
            darken
                (\c ->
                    contrast c white >= 4.6 && contrast c gray50 >= 4.6 && contrast c blue50 >= 4.6
                )
                (get "blue-600")

        blue700 =
            below 8 blue600 (get "blue-700")

        blue800 =
            below 7 blue700 (get "blue-800")

        blue900 =
            below 7 blue800 (get "blue-900")

        blue500 =
            darken (\c -> contrast c white >= 3.2) (below -8 blue600 (get "blue-500") |> (\c -> { c | l = min c.l (blue600.l + 8) }))

        updates =
            [ ( "gray-600", gray600 )
            , ( "gray-700", gray700 )
            , ( "gray-800", gray800 )
            , ( "gray-900", gray900 )
            , ( "blue-500", blue500 )
            , ( "blue-600", blue600 )
            , ( "blue-700", blue700 )
            , ( "blue-800", blue800 )
            , ( "blue-900", blue900 )
            ]
    in
    List.map
        (\( name, c ) ->
            case List.filter (\( n, _ ) -> n == name) updates |> List.head of
                Just ( _, fitted ) ->
                    ( name, fitted )

                Nothing ->
                    ( name, c )
        )
        colors



-- THE STYLE


{-| The custom properties of a theme in one mode; none for the light mode of the
first theme, which is the stylesheet as it is.
-}
declarations : Spec -> Bool -> List ( String, String )
declarations spec dark =
    if spec.plain && not dark then
        []

    else
        let
            colors =
                List.map (\( name, c ) -> ( "--klar-" ++ name, hsl c )) (scale spec dark)

            accent500 =
                scale spec dark
                    |> List.filter (\( name, _ ) -> name == "blue-500")
                    |> List.head
                    |> Maybe.map Tuple.second
                    |> Maybe.withDefault { h = spec.accentHue, s = 50, l = 50 }

            ring c alpha =
                "0 0 0 3px " ++ hsla c alpha

            neutral l =
                hsl { h = spec.neutralHue, s = spec.neutralSat, l = l }
        in
        if dark then
            colors
                ++ [ ( "--klar-surface-hover"
                     , neutral
                        (if spec.strong then
                            14

                         else
                            17
                        )
                     )
                   , ( "--klar-surface-active"
                     , neutral
                        (if spec.strong then
                            20

                         else
                            21
                        )
                     )
                   , ( "--klar-code-bg"
                     , neutral
                        (if spec.strong then
                            0

                         else
                            6
                        )
                     )
                   , ( "--klar-code-text", neutral 88 )
                   , ( "--klar-overlay", "rgba(0, 0, 0, 0.6)" )
                   , ( "--klar-tint-hover", "rgba(255, 255, 255, 0.08)" )
                   , ( "--klar-tint-border", "rgba(255, 255, 255, 0.12)" )
                   , ( "--klar-highlight", "hsl(45 60% 22%)" )
                   , ( "--klar-shadow-xs", "0 1px 1px rgba(0, 0, 0, 0.3)" )
                   , ( "--klar-shadow-sm", "0 1px 2px rgba(0, 0, 0, 0.4), 0 1px 1px rgba(0, 0, 0, 0.3)" )
                   , ( "--klar-shadow-md", "0 4px 12px rgba(0, 0, 0, 0.5), 0 1px 3px rgba(0, 0, 0, 0.35)" )
                   , ( "--klar-shadow-lg", "0 12px 32px rgba(0, 0, 0, 0.6), 0 2px 6px rgba(0, 0, 0, 0.4)" )
                   , ( "--klar-focus-ring", ring accent500 0.4 )
                   , ( "--klar-focus-ring-danger", "0 0 0 3px hsla(5, 62%, 60%, 0.4)" )
                   , ( "--klar-chart-hover", "rgba(255, 255, 255, 0.06)" )
                   , ( "--klar-avatar-3-bg", "hsl(187 35% 22%)" )
                   , ( "--klar-avatar-3-fg", "hsl(187 45% 80%)" )
                   , ( "--klar-avatar-4-bg", "hsl(232 35% 25%)" )
                   , ( "--klar-avatar-4-fg", "hsl(232 60% 85%)" )
                   , ( "--klar-avatar-5-bg", "hsl(45 30% 22%)" )
                   , ( "--klar-avatar-5-fg", "hsl(45 50% 80%)" )
                   , ( "--klar-avatar-7-bg", "hsl(350 30% 24%)" )
                   , ( "--klar-avatar-7-fg", "hsl(350 55% 85%)" )
                   , ( "color-scheme", "dark" )
                   ]

        else
            colors ++ [ ( "--klar-focus-ring", ring accent500 0.25 ) ]


{-| One `:root` rule from declarations, or nothing when there are none.
-}
css : List ( String, String ) -> String
css pairs =
    if List.isEmpty pairs then
        ""

    else
        ":root{" ++ String.join ";" (List.map (\( k, v ) -> k ++ ":" ++ v) pairs) ++ "}"


hsl : Color -> String
hsl c =
    "hsl(" ++ number c.h ++ " " ++ number c.s ++ "% " ++ number c.l ++ "%)"


hsla : Color -> Float -> String
hsla c alpha =
    "hsl(" ++ number c.h ++ " " ++ number c.s ++ "% " ++ number c.l ++ "% / " ++ number alpha ++ ")"


number : Float -> String
number x =
    String.fromFloat (toFloat (round (x * 100)) / 100)



-- CONTRAST


{-| The contrast ratio of two colors, as WCAG 2 defines it (1 to 21).
-}
contrast : Color -> Color -> Float
contrast a b =
    let
        la =
            luminance a

        lb =
            luminance b
    in
    (max la lb + 0.05) / (min la lb + 0.05)


luminance : Color -> Float
luminance c =
    let
        ( r, g, b ) =
            toRgb c

        channel v =
            if v <= 0.03928 then
                v / 12.92

            else
                ((v + 0.055) / 1.055) ^ 2.4
    in
    0.2126 * channel r + 0.7152 * channel g + 0.0722 * channel b


toRgb : Color -> ( Float, Float, Float )
toRgb c =
    let
        s =
            c.s / 100

        l =
            c.l / 100

        a =
            s * min l (1 - l)

        f n =
            let
                x =
                    n + c.h / 30

                k =
                    x - 12 * toFloat (floor (x / 12))
            in
            l - a * max -1 (min (min (k - 3) (9 - k)) 1)
    in
    ( f 0, f 8, f 4 )
