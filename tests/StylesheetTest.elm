module StylesheetTest exposing (suite)

import Expect
import Html.Attributes as Attr
import Klar
import Klar.Icon as Icon
import Klar.Theme as Theme exposing (Density(..), Size(..), Tone(..))
import Set
import Test exposing (Test, describe, test)
import Test.Html.Query as Query
import Test.Html.Selector as Selector


count : String -> String -> Int
count needle haystack =
    List.length (String.indexes needle haystack)


suite : Test
suite =
    describe "the stylesheet and the shared vocabulary"
        [ describe "Klar.stylesheet"
            [ test "is a style element" <|
                \_ ->
                    Klar.stylesheet
                        |> Query.fromHtml
                        |> Query.has [ Selector.tag "style" ]
            , test "holds the same rules as Klar.css" <|
                \_ ->
                    Klar.stylesheet
                        |> Query.fromHtml
                        |> Query.has [ Selector.text Klar.css ]
            , test "is not empty" <|
                \_ -> Expect.greaterThan 100000 (String.length Klar.css)
            , test "has as many opening as closing braces" <|
                \_ -> Expect.equal (count "{" Klar.css) (count "}" Klar.css)
            , test "defines the tokens" <|
                \_ ->
                    Expect.equal [ True, True, True ]
                        (List.map (\token -> String.contains token Klar.css) [ "--klar-primary:", "--klar-space-4:", "--klar-font:" ])
            , test "styles the components" <|
                \_ ->
                    Expect.equal [ True, True, True, True ]
                        (List.map (\selector -> String.contains selector Klar.css) [ ".klar-button", ".klar-table", ".klar-select", ".klar-modal" ])
            , test "has no leftovers of the old prefix" <|
                \_ -> Expect.equal False (String.contains ".ui-" Klar.css || String.contains "--ui-" Klar.css)
            ]
        , describe "icons"
            [ test "every icon has its own name" <|
                \_ ->
                    Expect.equal (List.length Icon.all) (Set.size (Set.fromList (List.map Icon.name Icon.all)))
            , test "every icon has a rule in the stylesheet" <|
                \_ ->
                    Icon.all
                        |> List.filter (\icon -> not (String.contains (".klar-icon--" ++ Icon.name icon ++ "{") Klar.css))
                        |> List.map Icon.name
                        |> Expect.equal []
            , test "a custom icon is named as given" <|
                \_ -> Expect.equal "invoice" (Icon.name (Icon.custom "invoice"))
            , test "a decorative icon is hidden from assistive technology" <|
                \_ ->
                    Icon.view Icon.search
                        |> Query.fromHtml
                        |> Query.has [ Selector.attribute (Attr.attribute "aria-hidden" "true") ]
            , test "a labelled icon is an image with a name" <|
                \_ ->
                    Icon.labelled "Search" Icon.search
                        |> Query.fromHtml
                        |> Query.has
                            [ Selector.attribute (Attr.attribute "role" "img")
                            , Selector.attribute (Attr.attribute "aria-label" "Search")
                            ]
            ]
        , describe "Klar.Theme"
            [ test "tones" <|
                \_ ->
                    Expect.equal [ "neutral", "primary", "info", "success", "warning", "danger" ]
                        (List.map Theme.toneSuffix [ Neutral, Primary, Info, Success, Warning, Danger ])
            , test "sizes" <|
                \_ -> Expect.equal [ "sm", "md", "lg" ] (List.map Theme.sizeSuffix [ Small, Medium, Large ])
            , test "densities" <|
                \_ -> Expect.equal [ "compact", "normal", "comfortable" ] (List.map Theme.densitySuffix [ Compact, Normal, Comfortable ])
            ]
        ]
