module MarkdownViewTest exposing (suite)

{-| The HTML of the Markdown view: semantics, accessibility attributes and the
attributes of the view.
-}

import Expect
import Html.Attributes as Attr
import Klar.Locale as Locale
import Klar.Markdown as Markdown
import Test exposing (Test, describe, test)
import Test.Html.Query as Query
import Test.Html.Selector as Selector


suite : Test
suite =
    describe "Markdown view"
        [ headingsTests
        , listTests
        , taskTests
        , codeTests
        , tableTests
        , linkTests
        , textTests
        , documentTests
        ]


query : List Markdown.Attribute -> String -> Query.Single msg
query attributes text =
    Query.fromHtml (Markdown.view attributes text)


count : String -> List Markdown.Attribute -> String -> Int -> Expect.Expectation
count tag attributes text expected =
    query attributes text
        |> Query.findAll [ Selector.tag tag ]
        |> Query.count (Expect.equal expected)


headingsTests : Test
headingsTests =
    describe "headings"
        [ test "a heading is a heading element with an id" <|
            \_ ->
                query [] "# Orders"
                    |> Query.find [ Selector.tag "h1" ]
                    |> Query.has [ Selector.id "orders", Selector.text "Orders" ]
        , test "the offset moves the levels down" <|
            \_ ->
                query [ Markdown.headingOffset 2 ] "# A\n\n## B"
                    |> Expect.all
                        [ Query.has [ Selector.tag "h3", Selector.id "a" ]
                        , Query.has [ Selector.tag "h4", Selector.id "b" ]
                        , Query.hasNot [ Selector.tag "h1" ]
                        , Query.hasNot [ Selector.tag "h2" ]
                        ]
        , test "levels stop at h6" <|
            \_ ->
                query [ Markdown.headingOffset 5 ] "# A\n\n## B\n\n### C"
                    |> Expect.all
                        [ Query.has [ Selector.tag "h6", Selector.id "a" ]
                        , Query.has [ Selector.tag "h6", Selector.id "b" ]
                        , Query.has [ Selector.tag "h6", Selector.id "c" ]
                        ]
        , test "the offset is at most five and at least nothing" <|
            \_ ->
                Expect.all
                    [ \_ -> query [ Markdown.headingOffset 99 ] "# A" |> Query.has [ Selector.tag "h6" ]
                    , \_ -> query [ Markdown.headingOffset -3 ] "# A" |> Query.has [ Selector.tag "h1" ]
                    ]
                    ()
        , test "a heading that skips levels does not skip them in the page" <|
            \_ ->
                query [ Markdown.headingOffset 1 ] "# A\n\n#### B"
                    |> Expect.all
                        [ Query.has [ Selector.tag "h2", Selector.id "a" ]
                        , Query.has [ Selector.tag "h3", Selector.id "b" ]
                        ]
        , test "a prefix goes in front of every id" <|
            \_ ->
                query [ Markdown.idPrefix "answer-3-" ] "# A\n\n## A"
                    |> Expect.all
                        [ Query.has [ Selector.id "answer-3-a" ]
                        , Query.has [ Selector.id "answer-3-a-1" ]
                        ]
        , test "the paragraphs choose their own direction" <|
            \_ ->
                query [] "مرحبا"
                    |> Query.find [ Selector.tag "p" ]
                    |> Query.has [ Selector.attribute (Attr.attribute "dir" "auto") ]
        ]


listTests : Test
listTests =
    describe "lists"
        [ test "a bullet list is a list of items" <|
            \_ ->
                query [] "- a\n- b"
                    |> Expect.all
                        [ Query.has [ Selector.tag "ul" ]
                        , Query.findAll [ Selector.tag "li" ] >> Query.count (Expect.equal 2)
                        ]
        , test "a numbered list keeps its number" <|
            \_ ->
                query [] "3. a\n4. b"
                    |> Query.find [ Selector.tag "ol" ]
                    |> Query.has [ Selector.attribute (Attr.start 3) ]
        , test "a numbered list from one needs no start" <|
            \_ ->
                query [] "1. a\n2. b"
                    |> Query.find [ Selector.tag "ol" ]
                    |> Query.hasNot [ Selector.attribute (Attr.start 1) ]
        , test "a tight list has no paragraphs" <|
            \_ ->
                count "p" [] "- a\n- b" 0
        , test "a loose list has paragraphs" <|
            \_ ->
                count "p" [] "- a\n\n- b" 2
        , test "a nested list is inside its item" <|
            \_ ->
                query [] "- a\n  - b"
                    |> Query.find [ Selector.tag "li", Selector.containing [ Selector.text "a" ] ]
                    |> Query.has [ Selector.tag "ul" ]
        ]


taskTests : Test
taskTests =
    describe "task lists"
        [ test "a task is a disabled check box in a label with the text" <|
            \_ ->
                query [] "- [ ] Check the count"
                    |> Query.find [ Selector.tag "label" ]
                    |> Expect.all
                        [ Query.has [ Selector.text "Check the count" ]
                        , Query.has [ Selector.tag "input", Selector.attribute (Attr.type_ "checkbox"), Selector.disabled True ]
                        ]
        , test "an open task is not checked" <|
            \_ ->
                query [] "- [ ] a"
                    |> Query.find [ Selector.tag "input" ]
                    |> Query.hasNot [ Selector.checked True ]
        , test "a done task is checked" <|
            \_ ->
                query [] "- [x] a"
                    |> Query.find [ Selector.tag "input" ]
                    |> Query.has [ Selector.checked True ]
        , test "an ordinary item has no check box" <|
            \_ ->
                count "input" [] "- a" 0
        , test "a loose task keeps the label inside its paragraph" <|
            \_ ->
                query [] "- [x] a\n\n- [ ] b"
                    |> Query.findAll [ Selector.tag "p" ]
                    |> Query.each (Query.has [ Selector.tag "label" ])
        , test "the check boxes are not in the way of the keyboard" <|
            \_ ->
                query [] "- [x] a"
                    |> Query.find [ Selector.tag "input" ]
                    |> Query.has [ Selector.disabled True ]
        ]


codeTests : Test
codeTests =
    describe "code"
        [ test "a code block is a pre with code" <|
            \_ ->
                query [] "```\nlet x = 1\n```"
                    |> Query.find [ Selector.tag "pre" ]
                    |> Query.has [ Selector.tag "code", Selector.text "let x = 1" ]
        , test "the block has a name" <|
            \_ ->
                query [] "```\nx\n```"
                    |> Query.find [ Selector.tag "pre" ]
                    |> Query.has [ Selector.attribute (Attr.attribute "aria-label" "Code"), Selector.attribute (Attr.attribute "role" "group") ]
        , test "the language is in the name, on the code and shown" <|
            \_ ->
                query [] "```python\nprint(1)\n```"
                    |> Expect.all
                        [ Query.has [ Selector.attribute (Attr.attribute "aria-label" "Code: python") ]
                        , Query.find [ Selector.tag "code" ] >> Query.has [ Selector.attribute (Attr.attribute "data-language" "python"), Selector.class "language-python" ]
                        , Query.has [ Selector.class "klar-md__language", Selector.text "python" ]
                        ]
        , test "a block without a language shows none" <|
            \_ ->
                query [] "```\nx\n```"
                    |> Query.hasNot [ Selector.class "klar-md__language" ]
        , test "a long line can be scrolled with the keyboard" <|
            \_ ->
                query [] ("```\n" ++ String.repeat 40 "x" ++ "\n```")
                    |> Query.find [ Selector.tag "pre" ]
                    |> Query.has [ Selector.attribute (Attr.tabindex 0) ]
        , test "many lines can be scrolled with the keyboard" <|
            \_ ->
                query [] ("```\n" ++ String.join "\n" (List.repeat 30 "x") ++ "\n```")
                    |> Query.find [ Selector.tag "pre" ]
                    |> Query.has [ Selector.attribute (Attr.tabindex 0) ]
        , test "a short block is not a stop for the keyboard" <|
            \_ ->
                query [] "```\nnpm install\n```"
                    |> Query.find [ Selector.tag "pre" ]
                    |> Query.hasNot [ Selector.attribute (Attr.tabindex 0) ]
        , test "the code is always read left to right" <|
            \_ ->
                query [] "```\nx\n```"
                    |> Query.find [ Selector.tag "pre" ]
                    |> Query.has [ Selector.attribute (Attr.attribute "dir" "ltr") ]
        , test "code in a line" <|
            \_ ->
                query [] "Use `npm test`."
                    |> Query.find [ Selector.tag "code" ]
                    |> Query.has [ Selector.text "npm test" ]
        ]


tableTests : Test
tableTests =
    describe "tables"
        [ test "the header cells are column headers" <|
            \_ ->
                query [] "| a | b |\n|---|---|\n| 1 | 2 |"
                    |> Query.findAll [ Selector.tag "th" ]
                    |> Expect.all
                        [ Query.count (Expect.equal 2)
                        , Query.each (Query.has [ Selector.attribute (Attr.scope "col") ])
                        ]
        , test "the header is in a thead and the rows in a tbody" <|
            \_ ->
                query [] "| a |\n|---|\n| 1 |\n| 2 |"
                    |> Expect.all
                        [ Query.find [ Selector.tag "thead" ] >> Query.findAll [ Selector.tag "th" ] >> Query.count (Expect.equal 1)
                        , Query.find [ Selector.tag "tbody" ] >> Query.findAll [ Selector.tag "td" ] >> Query.count (Expect.equal 2)
                        ]
        , test "the alignment is a class" <|
            \_ ->
                query [] "| a | b | c |\n|:--|:-:|--:|\n| 1 | 2 | 3 |"
                    |> Expect.all
                        [ Query.find [ Selector.tag "td", Selector.containing [ Selector.text "1" ] ] >> Query.has [ Selector.class "klar-md__cell--left" ]
                        , Query.find [ Selector.tag "td", Selector.containing [ Selector.text "2" ] ] >> Query.has [ Selector.class "klar-md__cell--center" ]
                        , Query.find [ Selector.tag "td", Selector.containing [ Selector.text "3" ] ] >> Query.has [ Selector.class "klar-md__cell--right" ]
                        ]
        , test "a table scrolls inside its own box, which has a name" <|
            \_ ->
                query [] "| a | b | c |\n|---|---|---|\n| 1 | 2 | 3 |"
                    |> Query.find [ Selector.class "klar-md__table" ]
                    |> Query.has [ Selector.attribute (Attr.tabindex 0), Selector.attribute (Attr.attribute "aria-label" "Table"), Selector.attribute (Attr.attribute "role" "group") ]
        , test "a small table is not a stop for the keyboard" <|
            \_ ->
                query [] "| a | b |\n|---|---|\n| 1 | 2 |"
                    |> Query.find [ Selector.class "klar-md__table" ]
                    |> Query.hasNot [ Selector.attribute (Attr.tabindex 0) ]
        , test "the cells are inline Markdown" <|
            \_ ->
                query [] "| a |\n|---|\n| **b** |"
                    |> Query.find [ Selector.tag "td" ]
                    |> Query.has [ Selector.tag "strong" ]
        ]


linkTests : Test
linkTests =
    describe "links"
        [ test "a link to another site is marked" <|
            \_ ->
                query [] "[docs](https://example.com)"
                    |> Query.find [ Selector.tag "a" ]
                    |> Query.has [ Selector.class "klar-md__link--external", Selector.text "docs" ]
        , test "a link to the same site is not" <|
            \_ ->
                query [] "[orders](/orders)"
                    |> Query.find [ Selector.tag "a" ]
                    |> Query.hasNot [ Selector.class "klar-md__link--external" ]
        , test "the title of a link is the title of the element" <|
            \_ ->
                query [] "[orders](/orders \"All orders\")"
                    |> Query.find [ Selector.tag "a" ]
                    |> Query.has [ Selector.attribute (Attr.title "All orders") ]
        , test "an email address is not marked as another site" <|
            \_ ->
                query [] "<ada@example.com>"
                    |> Query.find [ Selector.tag "a" ]
                    |> Query.hasNot [ Selector.class "klar-md__link--external" ]
        , test "a placeholder for an image says that it is an image" <|
            \_ ->
                query [] "![a chair](/chair.png)"
                    |> Query.find [ Selector.tag "a" ]
                    |> Query.has [ Selector.text "Image: ", Selector.text "a chair" ]
        ]


textTests : Test
textTests =
    describe "text"
        [ test "emphasis, strong text, strikethrough" <|
            \_ ->
                query [] "*a* **b** ~~c~~"
                    |> Expect.all
                        [ Query.has [ Selector.tag "em" ]
                        , Query.has [ Selector.tag "strong" ]
                        , Query.has [ Selector.tag "del" ]
                        ]
        , test "a block quote" <|
            \_ ->
                query [] "> a"
                    |> Query.has [ Selector.tag "blockquote" ]
        , test "a thematic break" <|
            \_ ->
                query [] "a\n\n---\n\nb"
                    |> Query.has [ Selector.tag "hr" ]
        , test "a hard break" <|
            \_ ->
                query [] "a  \nb"
                    |> Query.has [ Selector.tag "br" ]
        , test "the view is a block with a class and no inline style" <|
            \_ ->
                query [] "a"
                    |> Query.has [ Selector.class "klar-md" ]
        , test "empty text gives an empty block" <|
            \_ ->
                query [] ""
                    |> Query.hasNot [ Selector.tag "p" ]
        ]


documentTests : Test
documentTests =
    let
        document =
            Markdown.parse "# Orders\n\nText.\n\n## Open ##\n\n> ### Open\n\n- #### Open *now*\n\n```\n# not a heading\n```"
    in
    describe "documents"
        [ test "the headings in order, with the ids of the elements" <|
            \_ ->
                Markdown.headings document
                    |> List.map (\heading -> ( Markdown.headingLevel heading, Markdown.headingText heading, Markdown.headingId heading ))
                    |> Expect.equal
                        [ ( 1, "Orders", "orders" )
                        , ( 2, "Open", "open" )
                        , ( 3, "Open", "open-1" )
                        , ( 4, "Open now", "open-now" )
                        ]
        , test "the ids in the list are the ids in the page" <|
            \_ ->
                Query.fromHtml (Markdown.viewDocument [] document)
                    |> Expect.all
                        (Markdown.headings document
                            |> List.map Markdown.headingId
                            |> List.map (\id -> Query.has [ Selector.id id ])
                        )
        , test "plain text without markup" <|
            \_ ->
                Markdown.plainText (Markdown.parse "Ship **two** [orders](/o) `now`.\n\n- a\n- b\n\n| x | y |\n|---|---|\n| 1 | 2 |\n\n```\ncode\n```\n\n![chair](c.png)")
                    |> Expect.equal "Ship two orders now.\na\nb\nx | y\n1 | 2\ncode\nchair"
        , test "a cut text says so" <|
            \_ ->
                Markdown.view [] (String.repeat 150000 "a")
                    |> Query.fromHtml
                    |> Query.find [ Selector.tag "p", Selector.attribute (Attr.attribute "role" "note") ]
                    |> Query.has [ Selector.text "Only the first 100,000 of 150,000 characters are shown." ]
        , test "a text that is not cut has no notice" <|
            \_ ->
                query [] (String.repeat 100000 "a")
                    |> Query.hasNot [ Selector.attribute (Attr.attribute "role" "note") ]
        , describe "in Norwegian"
            [ test "the labels" <|
                \_ ->
                    query [ Markdown.locale Locale.nb ] "```python\nx\n```\n\n| a |\n|---|\n| 1 |\n\n![alt](/a.png) ![](/b.png)"
                        |> Expect.all
                            [ Query.has [ Selector.attribute (Attr.attribute "aria-label" "Kode: python") ]
                            , Query.has [ Selector.attribute (Attr.attribute "aria-label" "Tabell") ]
                            , Query.has [ Selector.text "Bilde: " ]
                            , Query.has [ Selector.text "Bilde" ]
                            ]
            , test "the notice" <|
                \_ ->
                    query [ Markdown.locale Locale.nb ] (String.repeat 150000 "a")
                        |> Query.has [ Selector.text "Bare de første 100\u{00A0}000 av 150\u{00A0}000 tegnene vises." ]
            ]
        ]
