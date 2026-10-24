module ThemeTest exposing (suite)

import Expect
import Klar
import Klar.Internal.Css.Tokens as Tokens
import Klar.Internal.Palette as Palette exposing (Color, Spec)
import Klar.Settings as Settings
import Klar.Theme as Theme exposing (Mode(..))
import Test exposing (Test, describe, test)
import Test.Html.Query as Query
import Test.Html.Selector as Selector


suite : Test
suite =
    describe "Klar.Theme"
        [ vocabularyTests
        , styleTests
        , contrastTests
        ]



-- THE TEN


vocabularyTests : Test
vocabularyTests =
    describe "the themes"
        [ test "there are ten, with different keys and names" <|
            \_ ->
                Expect.all
                    [ \_ -> List.length Theme.all |> Expect.equal 10
                    , \_ -> List.map Theme.key Theme.all |> unique |> Expect.equal True
                    , \_ -> List.map Theme.name Theme.all |> unique |> Expect.equal True
                    ]
                    ()
        , test "a key reads back the theme it came from" <|
            \_ ->
                Theme.all
                    |> List.map (\theme -> Theme.fromKey (Theme.key theme) |> Maybe.map Theme.key)
                    |> Expect.equal (List.map (Theme.key >> Just) Theme.all)
        , test "an unknown key is nothing" <|
            \_ -> Theme.fromKey "neon" |> Expect.equal Nothing
        , test "the settings start with the default theme in light mode" <|
            \_ ->
                Expect.all
                    [ \s -> Settings.theme s |> Theme.key |> Expect.equal "klar"
                    , \s -> Settings.mode s |> Expect.equal Light
                    ]
                    Settings.default
        ]


unique : List String -> Bool
unique items =
    List.length items
        == List.length
            (List.foldl
                (\x acc ->
                    if List.member x acc then
                        acc

                    else
                        x :: acc
                )
                []
                items
            )



-- THE STYLE ELEMENT


styleTests : Test
styleTests =
    describe "the style element"
        [ test "the default theme in light mode adds nothing: the stylesheet is that already" <|
            \_ -> lacks Theme.klar Light ":root"
        , test "another theme sets the accent scale on the root" <|
            \_ ->
                Expect.all
                    [ \_ -> has Theme.ocean Light ":root{"
                    , \_ -> has Theme.ocean Light "--klar-blue-600:hsl(196"
                    ]
                    ()
        , test "dark mode sets the color scheme and every scale" <|
            \_ ->
                Expect.all
                    [ \_ -> has Theme.klar Dark "color-scheme:dark"
                    , \_ -> has Theme.klar Dark "--klar-gray-900:"
                    , \_ -> has Theme.klar Dark "--klar-white:"
                    , \_ -> has Theme.klar Dark "--klar-red-50:"
                    ]
                    ()
        , test "the mode of the system puts the dark rules behind the media query" <|
            \_ ->
                Expect.all
                    [ \_ -> has Theme.indigo System "@media (prefers-color-scheme:dark){:root{"
                    , \_ -> has Theme.indigo System "color-scheme:dark"
                    ]
                    ()
        , test "light mode never mentions the dark scheme" <|
            \_ -> lacks Theme.violet Light "dark"
        , test "stylesheetFor draws the stylesheet and the theme" <|
            \_ ->
                Klar.stylesheetFor (Settings.default |> Settings.withTheme Theme.teal)
                    |> Query.fromHtml
                    |> Query.findAll [ Selector.tag "style" ]
                    |> Query.count (Expect.equal 2)
        ]


style : Theme.Theme -> Mode -> Query.Single msg
style theme mode =
    Theme.style theme mode
        |> Query.fromHtml


has : Theme.Theme -> Mode -> String -> Expect.Expectation
has theme mode text =
    style theme mode |> Query.has [ Selector.text text ]


lacks : Theme.Theme -> Mode -> String -> Expect.Expectation
lacks theme mode text =
    style theme mode |> Query.hasNot [ Selector.text text ]



-- CONTRAST


contrastTests : Test
contrastTests =
    describe "every pair keeps WCAG AA in every theme, light and dark"
        (Palette.specs
            |> List.concatMap
                (\spec ->
                    [ pairsTest spec False, pairsTest spec True ]
                )
        )


pairsTest : Spec -> Bool -> Test
pairsTest spec dark =
    let
        label =
            spec.name
                ++ (if dark then
                        " dark"

                    else
                        " light"
                   )

        colors =
            pageColors spec dark

        find name =
            colors
                |> List.filter (\( n, _ ) -> n == name)
                |> List.head
                |> Maybe.map Tuple.second

        -- A color that the page does not have is a failure, never a pass: a pair that
        -- cannot be measured is a pair nobody checked.
        check ( ink, ground ) =
            case ( find ink, find ground ) of
                ( Just a, Just b ) ->
                    let
                        ratio =
                            Palette.contrast a b
                    in
                    if ratio >= 4.5 then
                        []

                    else
                        [ ink ++ " on " ++ ground ++ " is " ++ String.fromFloat (toFloat (round (ratio * 100)) / 100) ]

                _ ->
                    [ ink ++ " on " ++ ground ++ ": a color the page does not have" ]

        surfaces =
            [ "white", "gray-50", "gray-100" ]

        status =
            [ "green", "amber", "red" ]

        pairs =
            List.concat
                [ List.concatMap (\ground -> [ ( "gray-900", ground ), ( "gray-700", ground ), ( "gray-600", ground ) ]) surfaces
                , List.map (\ground -> ( "blue-600", ground )) [ "white", "gray-50", "blue-50" ]
                , [ ( "white", "blue-600" ), ( "blue-700", "white" ) ]
                , List.concatMap
                    (\s ->
                        [ ( s ++ "-600", s ++ "-50" )
                        , ( s ++ "-600", "white" )
                        , ( s ++ "-600", "gray-50" )
                        , ( "white", s ++ "-600" )
                        , ( s ++ "-700", s ++ "-50" )
                        ]
                    )
                    status
                ]
    in
    test label <|
        \_ ->
            List.concatMap check pairs
                |> Expect.equal []


{-| The colors that are on the page for a theme in a mode: the hex colors of the
stylesheet's tokens, with the colors the theme sets on top. A light theme that is not
high contrast keeps the stylesheet's status colors, and the default theme in light
mode sets nothing at all, so its page is the tokens as they are.
-}
pageColors : Spec -> Bool -> List ( String, Color )
pageColors spec dark =
    let
        set =
            if spec.plain && not dark then
                []

            else
                Palette.scale spec dark

        names =
            List.map Tuple.first set
    in
    set ++ List.filter (\( n, _ ) -> not (List.member n names)) tokenColors


{-| Every `--klar-<name>: #rrggbb;` of the token block of the stylesheet.
-}
tokenColors : List ( String, Color )
tokenColors =
    Tokens.css
        |> String.lines
        |> List.filterMap
            (\line ->
                case String.split ":" (String.trim line) of
                    [ property, value ] ->
                        if String.startsWith "--klar-" property then
                            fromHex (String.trim (String.replace ";" "" value))
                                |> Maybe.map (\color -> ( String.dropLeft 7 property, color ))

                        else
                            Nothing

                    _ ->
                        Nothing
            )


fromHex : String -> Maybe Color
fromHex text =
    case String.toList text of
        [ '#', r1, r2, g1, g2, b1, b2 ] ->
            Maybe.map3 hsl (byte r1 r2) (byte g1 g2) (byte b1 b2)

        _ ->
            Nothing


byte : Char -> Char -> Maybe Float
byte high low =
    Maybe.map2 (\h l -> toFloat (h * 16 + l) / 255) (nibble high) (nibble low)


nibble : Char -> Maybe Int
nibble char =
    String.indexes (String.fromChar (Char.toLower char)) "0123456789abcdef"
        |> List.head


{-| Red, green and blue from 0 to 1 as hue, saturation and lightness (the
`Palette.Color` the contrast is measured on).
-}
hsl : Float -> Float -> Float -> Color
hsl r g b =
    let
        high =
            max r (max g b)

        low =
            min r (min g b)

        l =
            (high + low) / 2

        d =
            high - low

        s =
            if d == 0 then
                0

            else
                d / (1 - abs (2 * l - 1))

        h =
            if d == 0 then
                0

            else if high == r then
                60 * fmod ((g - b) / d) 6

            else if high == g then
                60 * ((b - r) / d + 2)

            else
                60 * ((r - g) / d + 4)
    in
    { h = h, s = s * 100, l = l * 100 }


fmod : Float -> Float -> Float
fmod x m =
    x - m * toFloat (floor (x / m))
