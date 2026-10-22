module ThemeTest exposing (suite)

import Expect
import Klar
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
            Palette.scale spec dark

        find name =
            colors
                |> List.filter (\( n, _ ) -> n == name)
                |> List.head
                |> Maybe.map Tuple.second

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
                    []

        surfaces =
            [ "white", "gray-50", "gray-100" ]

        status =
            [ "green", "amber", "red" ]

        pairs =
            List.concat
                [ List.concatMap (\ground -> [ ( "gray-900", ground ), ( "gray-700", ground ), ( "gray-600", ground ) ]) surfaces
                , List.map (\ground -> ( "blue-600", ground )) [ "white", "gray-50", "blue-50" ]
                , [ ( "white", "blue-600" ), ( "blue-700", "white" ) ]
                , List.concatMap (\s -> [ ( s ++ "-600", s ++ "-50" ), ( s ++ "-600", "white" ), ( "white", s ++ "-600" ) ]) status
                ]
    in
    test label <|
        \_ ->
            List.concatMap check pairs
                |> Expect.equal []
