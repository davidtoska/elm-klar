module StylesheetTest exposing (suite)

import Expect
import Html.Attributes as Attr
import Klar
import Klar.Icon as Icon
import Klar.Icon.Library as Library
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
            , test "a link button is a target of at least 24 by 24 px (WCAG 2.2, the Try again of a Tree branch)" <|
                \_ ->
                    Klar.css
                        |> String.split ".klar-button--link{"
                        |> List.drop 1
                        |> List.head
                        |> Maybe.map (String.split "}" >> List.head >> Maybe.withDefault "")
                        |> Maybe.withDefault ""
                        |> Expect.all
                            [ String.contains "min-height: 24px" >> Expect.equal True
                            , String.contains "min-width: 24px" >> Expect.equal True
                            ]
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
            [ test "every icon of the library has its own name" <|
                \_ ->
                    Expect.equal Library.count (Set.size (Set.fromList (List.map Icon.name Library.all)))
            , test "the library has the everyday icons and every themed module" <|
                \_ ->
                    Expect.all
                        [ \groups -> Expect.equal "Klar.Icon" (Maybe.withDefault "" (Maybe.map .moduleName (List.head groups)))
                        , \groups -> Expect.equal 16 (List.length groups)
                        , \groups -> Expect.equal [] (List.filter (\group -> List.isEmpty group.icons) groups)
                        ]
                        Library.groups
            , test "the library is large" <|
                \_ -> Expect.greaterThan 450 Library.count
            , test "the stylesheet has no drawings: icons carry their own" <|
                \_ -> Expect.equal False (String.contains "--klar-icon: url(" Klar.css)
            , test "an icon carries its drawing as a mask" <|
                \_ ->
                    Icon.view (Icon.fromSvg "box" "<path d='M3 3h18v18H3z'/>")
                        |> Query.fromHtml
                        |> Query.has
                            [ Selector.class "klar-icon--box"
                            , Selector.attribute
                                (Attr.attribute "style"
                                    "--klar-icon:url(\"data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' fill='none' stroke='black' stroke-width='2' stroke-linecap='round' stroke-linejoin='round'><path d='M3 3h18v18H3z'/></svg>\")"
                                )
                            ]
            , test "a drawing cannot break out of the url: quotes, percent and hash are made safe" <|
                \_ ->
                    Icon.view (Icon.fromSvg "odd" "<path d=\"M1 1\" fill='#fff' stroke='50%'/>")
                        |> Query.fromHtml
                        |> Query.has
                            [ Selector.attribute
                                (Attr.attribute "style"
                                    "--klar-icon:url(\"data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' fill='none' stroke='black' stroke-width='2' stroke-linecap='round' stroke-linejoin='round'><path d='M1 1' fill='%23fff' stroke='50%25'/></svg>\")"
                                )
                            ]
            , test "every icon of the library draws itself" <|
                \_ ->
                    Expect.all
                        (List.map
                            (\icon () ->
                                Icon.view icon
                                    |> Query.fromHtml
                                    |> Query.has
                                        [ Selector.class ("klar-icon--" ++ Icon.name icon)
                                        , Selector.attribute (Attr.attribute "aria-hidden" "true")
                                        ]
                            )
                            Library.all
                        )
                        ()
            , test "a custom icon is named as given and brings no drawing" <|
                \_ ->
                    Expect.all
                        [ \icon -> Expect.equal "invoice" (Icon.name icon)
                        , \icon ->
                            Icon.view icon
                                |> Query.fromHtml
                                |> Query.hasNot [ Selector.attribute (Attr.attribute "style" "") ]
                        ]
                        (Icon.custom "invoice")
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
