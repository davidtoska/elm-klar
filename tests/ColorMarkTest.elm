module ColorMarkTest exposing (suite)

{-| `Klar.Color`, and the dot that a color or a tone puts before an option in a
select, in the closed field and in a chip.
-}

import Expect
import Fuzz
import Html
import Html.Attributes as Attr
import Klar
import Klar.Color as Color
import Klar.MultiSelect as MultiSelect
import Klar.Search as Search
import Klar.Select as Select
import Klar.Select.Option as Option
import Klar.Tag as Tag
import Klar.Theme exposing (Tone(..))
import Test exposing (Test, describe, fuzz3, test)
import Test.Html.Query as Query
import Test.Html.Selector as Selector


suite : Test
suite =
    describe "colors on options"
        [ hexTests
        , optionTests
        , renderTests
        ]



-- THE COLOR


hexTests : Test
hexTests =
    describe "Klar.Color"
        [ test "reads the long and the short form, with or without the #, in any case" <|
            \_ ->
                List.map (Color.hex >> Maybe.map Color.toHex)
                    [ "#2A9461", "2a9461", "#2a9", " #FFF ", "000" ]
                    |> Expect.equal [ Just "#2a9461", Just "#2a9461", Just "#22aa99", Just "#ffffff", Just "#000000" ]
        , test "refuses what is not a color code" <|
            \_ ->
                List.map Color.hex [ "", "#", "red", "#12", "#1234", "#12345", "#1234567", "#12345g", "rgb(1,2,3)", "#2a94 61" ]
                    |> List.map ((==) Nothing)
                    |> List.all identity
                    |> Expect.equal True
        , test "rgb brings a number into the range" <|
            \_ -> Color.rgb -5 300 128 |> Color.toHex |> Expect.equal "#00ff80"
        , test "a code with an alpha channel is refused, not drawn opaque" <|
            \_ -> List.map Color.hex [ "#2a946180", "#2a98" ] |> Expect.equal [ Nothing, Nothing ]
        , test "toRgb gives the channels back" <|
            \_ ->
                Color.hex "#2a9461"
                    |> Maybe.map Color.toRgb
                    |> Expect.equal (Just { red = 42, green = 148, blue = 97 })
        , fuzz3 (Fuzz.intRange 0 255) (Fuzz.intRange 0 255) (Fuzz.intRange 0 255) "toHex and hex are each other's inverse" <|
            \r g b ->
                Color.rgb r g b
                    |> Color.toHex
                    |> Color.hex
                    |> Maybe.map Color.toHex
                    |> Expect.equal (Just (Color.toHex (Color.rgb r g b)))
        ]



-- THE OPTION


optionTests : Test
optionTests =
    describe "the option"
        [ test "a tone and a color replace each other: the last one set wins" <|
            \_ ->
                Expect.all
                    [ \o -> o |> Option.withTone Danger |> .color |> Expect.equal Nothing
                    , \o -> o |> Option.withColor (Color.rgb 1 2 3) |> .tone |> Expect.equal Nothing
                    , \o -> o |> Option.withColor (Color.rgb 1 2 3) |> Option.withTone Success |> (\x -> ( x.tone, x.color )) |> Expect.equal ( Just Success, Nothing )
                    ]
                    (Option.option "a" "A")
        , test "mapOption keeps the tone and the color" <|
            \_ ->
                Option.option 1 "One"
                    |> Option.withColor (Color.rgb 9 9 9)
                    |> Option.mapOption String.fromInt
                    |> .color
                    |> Expect.equal (Just (Color.rgb 9 9 9))
        ]



-- THE DOT


redOption : Option.Option String
redOption =
    Option.option "red" "Red" |> Option.withColor (Color.rgb 214 69 58)


amberOption : Option.Option String
amberOption =
    Option.option "amber" "Amber" |> Option.withTone Warning


plainOption : Option.Option String
plainOption =
    Option.option "plain" "Plain"


dot : Selector.Selector
dot =
    Selector.class "klar-dot"


renderTests : Test
renderTests =
    describe "the dot"
        [ test "a chosen option with a color shows it in the closed field, as a checked code" <|
            \_ ->
                closedSelect redOption
                    |> Query.has [ Selector.attribute (Attr.attribute "style" "--klar-dot:#d6453a") ]
        , test "a chosen option with a tone shows the dot of the tone" <|
            \_ ->
                closedSelect amberOption
                    |> Query.has [ Selector.class "klar-dot--warning" ]
        , test "an option with neither shows no dot" <|
            \_ -> closedSelect plainOption |> Query.hasNot [ dot ]
        , test "the dot is hidden from a screen reader" <|
            \_ ->
                closedSelect redOption
                    |> Query.find [ dot ]
                    |> Query.has [ Selector.attribute (Attr.attribute "aria-hidden" "true") ]
        , test "every row of the open list has its dot" <|
            \_ ->
                openSelect [ redOption, amberOption, plainOption ]
                    |> Query.findAll [ dot ]
                    |> Query.count (Expect.equal 2)
        , test "a chip of a multi select shows the color" <|
            \_ ->
                MultiSelect.init "m"
                    |> MultiSelect.setOptions [ redOption, amberOption ]
                    |> (\state -> MultiSelect.view identity [ MultiSelect.options [ redOption, amberOption ] ] state)
                    |> Query.fromHtml
                    |> Query.findAll [ dot ]
                    |> Query.count (Expect.equal 1)
        , test "a tag can carry a color" <|
            \_ ->
                Tag.view [ Tag.color (Color.rgb 1 2 3) ] "Team"
                    |> Query.fromHtml
                    |> Query.has [ dot ]
        , test "a search highlight is the mark of the search, never the dot" <|
            \_ ->
                Html.div [] (Search.highlight "ord" "Orders")
                    |> Query.fromHtml
                    |> Expect.all
                        [ Query.has [ Selector.tag "mark", Selector.class "klar-highlight" ]
                        , Query.hasNot [ dot ]
                        ]
        , test "the stylesheet has one rule for the highlight of a search and one for the dot" <|
            \_ ->
                Expect.all
                    [ \css -> List.length (String.indexes "\n.klar-highlight {" css) |> Expect.equal 1
                    , \css -> List.length (String.indexes "\n.klar-dot {" css) |> Expect.equal 1
                    ]
                    Klar.css
        ]


closedSelect : Option.Option String -> Query.Single ()
closedSelect chosen =
    Select.init "s"
        |> Select.setOption chosen
        |> (\state -> Select.view (\_ -> ()) [ Select.options [ chosen ] ] state)
        |> Query.fromHtml


openSelect : List (Option.Option String) -> Query.Single ()
openSelect options =
    Select.init "s"
        |> Select.open
        |> Tuple.first
        |> (\state -> Select.view (\_ -> ()) [ Select.options options ] state)
        |> Query.fromHtml
