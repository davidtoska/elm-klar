module FoundationsTest exposing (suite)

{-| The markup of the foundations: `Klar.Text`, `Klar.Layout`, `Klar.Card` and
`Klar.Icon`.
-}

import Expect
import Html
import Html.Attributes as Attr
import Klar
import Klar.Card as Card
import Klar.Icon as Icon
import Klar.Layout as Layout
import Klar.Text as Text
import Test exposing (Test, describe, test)
import Test.Html.Query as Query
import Test.Html.Selector as Selector exposing (Selector)


suite : Test
suite =
    describe "the foundations"
        [ textTests
        , layoutTests
        , cardTests
        , iconTests
        ]


attr : String -> String -> Selector
attr name value =
    Selector.attribute (Attr.attribute name value)



-- TEXT


textTests : Test
textTests =
    describe "Klar.Text"
        [ test "the headings are h1, h2 and h3" <|
            \_ ->
                Html.div [] [ Text.title "A", Text.heading "B", Text.subheading "C" ]
                    |> Query.fromHtml
                    |> Expect.all
                        [ Query.find [ Selector.tag "h1" ] >> Query.has [ Selector.text "A", Selector.class "klar-text--title" ]
                        , Query.find [ Selector.tag "h2" ] >> Query.has [ Selector.text "B", Selector.class "klar-text--heading" ]
                        , Query.find [ Selector.tag "h3" ] >> Query.has [ Selector.text "C", Selector.class "klar-text--subheading" ]
                        ]
        , test "headingLevel draws the element of the level, with the look of its kind" <|
            \_ ->
                Html.div [] [ Text.headingLevel 4 "Lines", Text.headingLevel 1 "Page", Text.headingLevel 2 "Part" ]
                    |> Query.fromHtml
                    |> Expect.all
                        [ Query.find [ Selector.tag "h4" ] >> Query.has [ Selector.text "Lines", Selector.class "klar-text--subheading" ]
                        , Query.find [ Selector.tag "h1" ] >> Query.has [ Selector.class "klar-text--title" ]
                        , Query.find [ Selector.tag "h2" ] >> Query.has [ Selector.class "klar-text--heading" ]
                        ]
        , test "a level outside 1 to 6 counts as the nearest" <|
            \_ ->
                Html.div [] [ Text.headingLevel 0 "Low", Text.headingLevel 9 "Deep" ]
                    |> Query.fromHtml
                    |> Expect.all
                        [ Query.find [ Selector.tag "h1" ] >> Query.has [ Selector.text "Low" ]
                        , Query.find [ Selector.tag "h6" ] >> Query.has [ Selector.text "Deep" ]
                        ]
        , test "truncated text keeps the whole text, and shows it as the tooltip" <|
            \_ ->
                Text.truncated "Nordic Office Supplies AS"
                    |> Query.fromHtml
                    |> Query.has
                        [ Selector.tag "span"
                        , Selector.class "klar-text--truncated"
                        , attr "title" "Nordic Office Supplies AS"
                        , Selector.text "Nordic Office Supplies AS"
                        ]
        , test "the inline functions are spans, strong and code; the blocks are p, div and pre" <|
            \_ ->
                Html.div []
                    [ Text.secondary "s", Text.muted "m", Text.caption "c", Text.mono "o", Text.figure "1", Text.strong "b", Text.code "x", Text.paragraph "p", Text.lead "l", Text.overline "v" ]
                    |> Query.fromHtml
                    |> Expect.all
                        [ Query.findAll [ Selector.tag "span" ] >> Query.count (Expect.equal 5)
                        , Query.findAll [ Selector.tag "strong" ] >> Query.count (Expect.equal 1)
                        , Query.findAll [ Selector.tag "code" ] >> Query.count (Expect.equal 1)
                        , Query.findAll [ Selector.tag "p" ] >> Query.count (Expect.equal 2)
                        ]
        , test "a code block can take the focus, so that it can be scrolled with the keyboard" <|
            \_ ->
                Text.codeBlock "x = 1"
                    |> Query.fromHtml
                    |> Query.has [ Selector.tag "pre", Selector.attribute (Attr.tabindex 0), Selector.text "x = 1" ]
        , test "a figure has tabular digits, so that a number that changes does not move" <|
            \_ ->
                Expect.equal True (String.contains "font-variant-numeric: tabular-nums;\n}\n\n/* One line with an ellipsis" Klar.css)
        ]



-- LAYOUT


layoutTests : Test
layoutTests =
    let
        gapOf n =
            Layout.stack [ Layout.gap n ] []
                |> Query.fromHtml
    in
    describe "Klar.Layout"
        [ test "a gap is a step of the scale: 7, 9 and 11 go down one step, above 12 is 12, below 1 is none" <|
            \_ ->
                Expect.all
                    (List.map
                        (\( n, value ) -> \_ -> gapOf n |> Query.has [ attr "style" ("--klar-gap:" ++ value) ])
                        [ ( -1, "0px" )
                        , ( 0, "0px" )
                        , ( 1, "var(--klar-space-1)" )
                        , ( 7, "var(--klar-space-6)" )
                        , ( 9, "var(--klar-space-8)" )
                        , ( 11, "var(--klar-space-10)" )
                        , ( 12, "var(--klar-space-12)" )
                        , ( 13, "var(--klar-space-12)" )
                        , ( 100, "var(--klar-space-12)" )
                        ]
                    )
                    ()
        , test "a layout can carry an id" <|
            \_ ->
                Layout.stack [ Layout.id "orders-panel" ] []
                    |> Query.fromHtml
                    |> Query.has [ Selector.id "orders-panel" ]
        , test "a name for a screen reader makes the layout a named region" <|
            \_ ->
                Layout.stack [ Layout.ariaLabel "Recent orders" ] []
                    |> Query.fromHtml
                    |> Query.has [ attr "role" "region", attr "aria-label" "Recent orders" ]
        , test "an empty name is no name and no region" <|
            \_ ->
                Layout.stack [ Layout.ariaLabel "" ] []
                    |> Query.fromHtml
                    |> Expect.all
                        [ Query.hasNot [ attr "role" "region" ]
                        , Query.hasNot [ attr "aria-label" "" ]
                        ]
        , test "scroll makes a scroll area that takes the focus, with no height limit of its own" <|
            \_ ->
                Layout.stack [ Layout.scroll, Layout.fillRest ] []
                    |> Query.fromHtml
                    |> Query.has
                        [ Selector.classes [ "klar-scroll", "klar-fill-rest" ]
                        , Selector.attribute (Attr.tabindex 0)
                        , attr "style" "--klar-gap:var(--klar-space-3);--klar-max-h:none"
                        ]
        , test "a layout that does not scroll is not a tab stop" <|
            \_ ->
                Layout.stack [] []
                    |> Query.fromHtml
                    |> Query.hasNot [ Selector.attribute (Attr.tabindex 0) ]
        , test "maxHeight scrolls by itself and sets its limit" <|
            \_ ->
                Layout.stack [ Layout.maxHeight 320 ] []
                    |> Query.fromHtml
                    |> Query.has [ Selector.class "klar-scroll", attr "style" "--klar-gap:var(--klar-space-3);--klar-max-h:320px" ]
        , test "a container with fillRest hands the height on" <|
            \_ ->
                Layout.container [ Layout.fillRest ] [ Layout.stack [ Layout.fillRest ] [] ]
                    |> Query.fromHtml
                    |> Query.has [ Selector.classes [ "klar-container", "klar-fill-rest" ] ]
        , test "the stylesheet makes a container with fillRest a flex column" <|
            \_ ->
                Expect.equal True (String.contains ".klar-container.klar-fill-rest { display: flex; flex-direction: column; }" Klar.css)
        , test "the vertical divider is a vertical separator" <|
            \_ ->
                Layout.dividerVertical
                    |> Query.fromHtml
                    |> Query.has [ Selector.class "klar-divider-v", attr "role" "separator", attr "aria-orientation" "vertical" ]
        ]



-- CARD


cardTests : Test
cardTests =
    describe "Klar.Card"
        [ test "an empty subtitle is no subtitle, and with nothing else no header" <|
            \_ ->
                Card.view [ Card.subtitle "" ] [ Html.text "body" ]
                    |> Query.fromHtml
                    |> Expect.all
                        [ Query.hasNot [ Selector.class "klar-card__header" ]
                        , Query.hasNot [ Selector.class "klar-card__subtitle" ]
                        ]
        , test "a card with an id and a title is a region named by its title" <|
            \_ ->
                Card.view [ Card.id "revenue", Card.title "Revenue" ] []
                    |> Query.fromHtml
                    |> Expect.all
                        [ Query.has [ Selector.tag "section", Selector.id "revenue", attr "aria-labelledby" "revenue-title" ]
                        , Query.find [ Selector.tag "h2" ] >> Query.has [ Selector.id "revenue-title", Selector.text "Revenue" ]
                        ]
        , test "a card without an id or without a title points at nothing" <|
            \_ ->
                Expect.all
                    [ \_ -> Card.view [ Card.title "Revenue" ] [] |> Query.fromHtml |> Query.hasNot [ attr "aria-labelledby" "revenue-title" ]
                    , \_ ->
                        Card.view [ Card.id "revenue" ] []
                            |> Query.fromHtml
                            |> Query.hasNot [ attr "aria-labelledby" "revenue-title" ]
                    ]
                    ()
        , test "the header follows the density: its height comes from the control token" <|
            \_ ->
                Expect.equal True (String.contains "min-height: calc(var(--klar-control) + var(--klar-space-3));" Klar.css)
        ]



-- ICON


iconTests : Test
iconTests =
    let
        styleOf icon =
            Icon.view icon |> Query.fromHtml
    in
    describe "Klar.Icon"
        [ test "a drawing written on several lines is one line in the url" <|
            \_ ->
                styleOf (Icon.fromSvg "lines" "<path d='M1 1'/>\n\t<path d='M2 2'/>\u{000D}\n")
                    |> Query.has
                        [ attr "style"
                            "--klar-icon:url(\"data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' fill='none' stroke='black' stroke-width='2' stroke-linecap='round' stroke-linejoin='round'><path d='M1 1'/>  <path d='M2 2'/> </svg>\")"
                        ]
        , test "a backslash cannot start a CSS escape in the url" <|
            \_ ->
                styleOf (Icon.fromSvg "slash" "<text>a\\b</text>")
                    |> Query.has
                        [ attr "style"
                            "--klar-icon:url(\"data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' fill='none' stroke='black' stroke-width='2' stroke-linecap='round' stroke-linejoin='round'><text>a%5Cb</text></svg>\")"
                        ]
        , test "a blank label is no name: the icon is decorative, not an image without a name" <|
            \_ ->
                Icon.labelled "  " Icon.warning
                    |> Query.fromHtml
                    |> Expect.all
                        [ Query.has [ attr "aria-hidden" "true" ]
                        , Query.hasNot [ attr "role" "img" ]
                        ]
        , test "a label names the icon" <|
            \_ ->
                Icon.labelled "Overdue" Icon.warning
                    |> Query.fromHtml
                    |> Query.has [ attr "role" "img", attr "aria-label" "Overdue" ]
        , test "a name with a space or a dot is one class" <|
            \_ ->
                Icon.view (Icon.custom "my icon.v2")
                    |> Query.fromHtml
                    |> Query.has [ Selector.class "klar-icon--my-icon-v2" ]
        , test "a name is never a size: custom \"lg\" is 16 pixels" <|
            \_ ->
                Icon.sized Icon.Large (Icon.custom "lg")
                    |> Query.fromHtml
                    |> Query.has [ Selector.classes [ "klar-icon--lg", "klar-icon--size-20" ] ]
        , test "an icon prints: its color is kept when the page is printed" <|
            \_ ->
                Expect.equal True (String.contains "vertical-align: -0.2em;\n  /* The color is a background" Klar.css)
        ]
