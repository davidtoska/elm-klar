module MarkdownRobustTest exposing (suite)

{-| What the Markdown parser promises about any text: it never fails, it has
limits, and the blocks that are complete do not change when more text arrives.

The tests of cost do not measure time (that would depend on the machine). They
give the parser texts that would take a naive parser a very long time or a very
deep tree, and check that it finishes and that the tree stays within its bounds.
A test that did not finish would not pass.

-}

import Expect exposing (Expectation)
import Fuzz exposing (Fuzzer)
import Klar.Markdown.Inline as Inline exposing (Inline(..))
import Klar.Markdown.Parse as Parse exposing (Block(..))
import Support.MarkdownHtml as H
import Test exposing (Test, describe, fuzzWith, test)


suite : Test
suite =
    describe "Markdown robustness"
        [ totality
        , bounds
        , stability
        ]



-- TOTALITY


{-| Pieces that Markdown gives meaning to, glued together at random.
-}
fragment : Fuzzer String
fragment =
    Fuzz.oneOfValues
        [ "*"
        , "**"
        , "***"
        , "_"
        , "__"
        , "~~"
        , "~"
        , "`"
        , "``"
        , "```"
        , "~~~"
        , "["
        , "]"
        , "("
        , ")"
        , "!["
        , "]("
        , "<"
        , ">"
        , "http://a.b/c"
        , "https://x"
        , "<https://x.y>"
        , "<a@b.c>"
        , "\\"
        , "\\*"
        , "# "
        , "## "
        , "#"
        , "- "
        , "* "
        , "+ "
        , "1. "
        , "2) "
        , "10. "
        , "> "
        , ">"
        , "| "
        , "|"
        , " | "
        , "|---|"
        , "---"
        , "***"
        , ":"
        , "-"
        , "\n"
        , "\n"
        , "\n\n"
        , " "
        , "  "
        , "    "
        , "\t"
        , "a"
        , "bc"
        , "foo bar"
        , "[ ] "
        , "[x] "
        , "\""
        , "'"
        , "&"
        , "&amp;"
        , "<script>"
        , "javascript:"
        , "😀"
        , "\u{D83D}"
        , "\u{DE00}"
        , "\u{0000}"
        , "\u{000D}\n"
        , "\u{000D}"
        ]


randomText : Fuzzer String
randomText =
    Fuzz.listOfLengthBetween 0 120 fragment
        |> Fuzz.map String.concat


totality : Test
totality =
    describe "any text"
        [ fuzzWith { runs = 1000, distribution = Test.noDistribution } randomText "is read without failing" <|
            \text ->
                String.length (H.render text)
                    |> Expect.atLeast 0
        , fuzzWith { runs = 300, distribution = Test.noDistribution } Fuzz.string "made of arbitrary characters is read without failing" <|
            \text ->
                String.length (H.render text)
                    |> Expect.atLeast 0
        , fuzzWith { runs = 600, distribution = Test.noDistribution } randomText "has levels and ids that make sense" <|
            \text ->
                Parse.parse text
                    |> .blocks
                    |> headingsOf
                    |> checkOutline
        , fuzzWith { runs = 400, distribution = Test.noDistribution } randomText "gives text that is the same when read again" <|
            \text ->
                H.render text
                    |> Expect.equal (H.render text)
        ]


headingsOf : List Block -> List { level : Int, id : String }
headingsOf blocks =
    List.concatMap
        (\block ->
            case block of
                HeadingBlock heading ->
                    [ { level = heading.level, id = heading.id } ]

                Quote inner ->
                    headingsOf inner

                ListBlock list ->
                    List.concatMap (\item -> headingsOf item.blocks) list.items

                _ ->
                    []
        )
        blocks


{-| Levels are 1 to 6, never more than one deeper than the heading before, and
ids are not empty and not repeated.
-}
checkOutline : List { level : Int, id : String } -> Expectation
checkOutline headings =
    let
        levels =
            List.map .level headings

        ids =
            List.map .id headings

        jumps =
            List.map2 (\before after -> after - before) levels (List.drop 1 levels)
    in
    if List.any (\level -> level < 1 || level > 6) levels then
        Expect.fail "a level outside 1 to 6"

    else if List.any (\jump -> jump > 1) jumps then
        Expect.fail "a heading is more than one level deeper than the one before"

    else if List.any (\id -> id == "") ids then
        Expect.fail "an empty id"

    else if List.length (List.sort ids) /= List.length (uniqueSorted (List.sort ids)) then
        Expect.fail "an id that is used twice"

    else
        Expect.pass


uniqueSorted : List String -> List String
uniqueSorted sorted =
    case sorted of
        a :: b :: rest ->
            if a == b then
                uniqueSorted (b :: rest)

            else
                a :: uniqueSorted (b :: rest)

        _ ->
            sorted



-- BOUNDS


blockDepth : Block -> Int
blockDepth block =
    case block of
        Paragraph inlines ->
            inlineDepth inlines

        HeadingBlock heading ->
            inlineDepth heading.content

        Quote inner ->
            1 + listDepth inner

        ListBlock list ->
            1 + (list.items |> List.map (\item -> listDepth item.blocks) |> List.maximum |> Maybe.withDefault 0)

        Table table ->
            (table.header :: table.rows) |> List.concat |> List.map inlineDepth |> List.maximum |> Maybe.withDefault 0

        _ ->
            0


listDepth : List Block -> Int
listDepth blocks =
    blocks |> List.map blockDepth |> List.maximum |> Maybe.withDefault 0


inlineDepth : List Inline -> Int
inlineDepth inlines =
    inlines |> List.map inlineNodeDepth |> List.maximum |> Maybe.withDefault 0


inlineNodeDepth : Inline -> Int
inlineNodeDepth inline =
    case inline of
        Emphasis children ->
            1 + inlineDepth children

        Strong children ->
            1 + inlineDepth children

        Strikethrough children ->
            1 + inlineDepth children

        Link _ children ->
            1 + inlineDepth children

        _ ->
            0


depthOf : String -> Int
depthOf text =
    listDepth (Parse.parse text).blocks


bounds : Test
bounds =
    describe "bounds"
        [ test "a thousand opening brackets are text" <|
            \_ ->
                depthOf (String.repeat 30000 "[")
                    |> Expect.atMost 3
        , test "brackets and parentheses that never finish a link" <|
            \_ ->
                depthOf (String.repeat 20000 "[a](")
                    |> Expect.atMost 60
        , test "a line of stars" <|
            \_ ->
                depthOf (String.repeat 50000 "*")
                    |> Expect.atMost 10
        , test "stars that open and never close" <|
            \_ ->
                depthOf (String.repeat 30000 "*a ")
                    |> Expect.atMost 60
        , test "stars of every length, opened and closed" <|
            \_ ->
                depthOf (String.concat (List.map (\n -> String.repeat n "*" ++ "a ") (List.range 1 150)) ++ String.concat (List.map (\n -> "a" ++ String.repeat n "*" ++ " ") (List.range 1 150)))
                    |> Expect.atMost 60
        , test "underscores and tildes" <|
            \_ ->
                depthOf (String.repeat 20000 "_a ~~b " ++ String.repeat 20000 "b~~ a_ ")
                    |> Expect.atMost 60
        , test "backticks of every length with no end" <|
            \_ ->
                depthOf (String.concat (List.map (\n -> String.repeat n "`" ++ "a ") (List.range 1 400)))
                    |> Expect.atMost 3
        , test "nested quotes are cut at the limit" <|
            \_ ->
                depthOf (String.repeat 5000 "> " ++ "x")
                    |> Expect.atMost (Parse.maxDepth + 1)
        , test "nested lists are cut at the limit" <|
            \_ ->
                depthOf (String.repeat 5000 "- " ++ "x")
                    |> Expect.atMost (Parse.maxDepth + 1)
        , test "a staircase of lists is cut at the limit" <|
            \_ ->
                depthOf (String.concat (List.map (\n -> String.repeat (2 * n) " " ++ "- x\n") (List.range 0 200)))
                    |> Expect.atMost (Parse.maxDepth + 1)
        , test "quotes inside lists inside quotes" <|
            \_ ->
                depthOf (String.repeat 3000 "> - ")
                    |> Expect.atMost (Parse.maxDepth + 1)
        , test "a line of 50000 lines" <|
            \_ ->
                Parse.parse (String.repeat 50000 "a\n")
                    |> .blocks
                    |> List.length
                    |> Expect.equal 1
        , test "fifty thousand lines of two characters, each its own block" <|
            \_ ->
                Parse.parse (String.repeat 50000 "#\n-\n")
                    |> .truncated
                    |> Expect.notEqual Nothing
        , test "many small blocks" <|
            \_ ->
                Parse.parse (String.repeat 20000 "- a\n\n")
                    |> .blocks
                    |> List.length
                    |> Expect.equal 1
        , test "many paragraphs" <|
            \_ ->
                Parse.parse (String.repeat 30000 "a\n\n")
                    |> .blocks
                    |> List.length
                    |> Expect.equal 30000
        , test "many table rows" <|
            \_ ->
                Parse.parse ("| a | b |\n|---|---|\n" ++ String.repeat 8000 "| 1 | 2 |\n")
                    |> .blocks
                    |> List.length
                    |> Expect.equal 1
        , test "a very wide table" <|
            \_ ->
                Parse.parse (String.repeat 5000 "|a" ++ "|\n" ++ String.repeat 5000 "|-" ++ "|\n")
                    |> .blocks
                    |> List.length
                    |> Expect.equal 1
        , test "a long line of text" <|
            \_ ->
                Parse.parse (String.repeat 90000 "a")
                    |> .blocks
                    |> List.length
                    |> Expect.equal 1
        , test "a long run of spaces" <|
            \_ ->
                Parse.parse (String.repeat 90000 " " ++ "x")
                    |> .blocks
                    |> List.length
                    |> Expect.equal 1
        , test "many words with bare addresses" <|
            \_ ->
                depthOf (String.repeat 5000 "http://a.b/c(d ")
                    |> Expect.equal 1
        , test "many autolink openers" <|
            \_ ->
                depthOf (String.repeat 30000 "<a ")
                    |> Expect.equal 0
        , test "many closing brackets" <|
            \_ ->
                depthOf (String.repeat 30000 "]")
                    |> Expect.equal 0
        , test "links one after the other" <|
            \_ ->
                Parse.parse (String.repeat 10000 "[a](b) ")
                    |> .blocks
                    |> List.length
                    |> Expect.equal 1
        , test "text longer than the limit is cut and says so" <|
            \_ ->
                let
                    parsed =
                        Parse.parse (String.repeat 250000 "a")
                in
                Expect.equal (Just { shown = Parse.maxChars, total = 250000 }) parsed.truncated
        , test "text of exactly the limit is not cut" <|
            \_ ->
                Parse.parse (String.repeat Parse.maxChars "a")
                    |> .truncated
                    |> Expect.equal Nothing
        , test "the cut does not split a character made of two halves" <|
            \_ ->
                let
                    parsed =
                        Parse.parse (String.repeat (Parse.maxChars - 1) "a" ++ "😀 and more")
                in
                Expect.equal (Just { shown = Parse.maxChars - 1, total = Parse.maxChars + 10 }) parsed.truncated
        , test "the cut text is not closed for the reader" <|
            \_ ->
                H.render (String.repeat (Parse.maxChars - 3) "a" ++ " **bold and more")
                    |> String.contains "<strong>"
                    |> Expect.equal False
        ]



-- STABILITY


{-| The blocks of a text, apart from the last one, are the first blocks of every
longer text. So a view of a text that grows does not rearrange what it has shown.

This is checked at every length of the text for the documents below. For a text
made of random pieces it is checked where the text ends right after a blank line:
a line that is still being written can look like the start of a block (`***`) and
then become the continuation of the paragraph above it (`***x`), so the block
above it is only complete when a blank line follows it.

-}
stableWhen : (String -> Bool) -> String -> Expectation
stableWhen applies text =
    let
        full =
            (Parse.parse text).blocks

        failing =
            List.range 0 (String.length text)
                |> List.filter
                    (\length ->
                        applies (String.left length text)
                            && (let
                                    prefix =
                                        (Parse.parse (String.left length text)).blocks

                                    complete =
                                        List.length prefix - 1
                                in
                                List.take complete prefix /= List.take complete full
                               )
                    )
    in
    case List.head failing of
        Nothing ->
            Expect.pass

        Just length ->
            Expect.fail
                ("the blocks changed when the text grew from "
                    ++ String.fromInt length
                    ++ " characters: "
                    ++ H.render (String.left length text)
                    ++ "  =>  "
                    ++ H.render (String.left (length + 1) text)
                )


stableAtEvery : String -> Expectation
stableAtEvery =
    stableWhen (\_ -> True)


stableAfterBlankLines : String -> Expectation
stableAfterBlankLines =
    stableWhen endsAfterBlankLine


endsAfterBlankLine : String -> Bool
endsAfterBlankLine prefix =
    case List.reverse (String.lines prefix) of
        "" :: blank :: _ ->
            String.trim blank == ""

        _ ->
            False


documents : List ( String, String )
documents =
    [ ( "a note"
      , "# Delivery plan\n\nThe **first** shipment leaves on *Monday*. See [the schedule](https://example.com/plan \"Plan\") or <https://example.com/x>.\n\n## Items\n\n- Chairs\n- Tables\n  - Large\n  - Small\n- [ ] Check the count\n- [x] Order labels\n\n1. Pack\n2. Seal\n3. Ship\n\n> Handle with care.\n> Keep dry.\n\n```elm\nview model =\n    text \"hello\"\n\n```\n\n| Item | Count | Price |\n|:-----|------:|:-----:|\n| Chair | 12 | 40 |\n| Table | 3 | 120 |\n\n---\n\nLast paragraph with `code`, a hard  \nbreak, ~~old~~ new text and an image ![a chair](chair.png)."
      )
    , ( "lists and quotes", "- a\n\n  b\n- c\n\n> 1. one\n> 2. two\n>\n> > nested **quote**\n\n* x\n* y\n\n    indented code\n\n10. ten\n11. eleven\n" )
    , ( "tables", "Intro\n| a | b |\n|---|---|\n| 1 | 2 |\n| 3 | 4 |\nafter\n\n| only header |\n|---|\n" )
    , ( "unfinished markup", "Some **bold *and italic* text `with code [and a link](http://x.y/z) and ~~strike" )
    , ( "headings", "# One\n\n### Three\n\n## Two\n\n# One\n\n#### Four ####\n\n#\n\n## One\n" )
    , ( "emphasis and escapes", "*a **b** c* __d _e_ f__ \\*g\\* ***h*** snake_case_name 2*3*4" )
    , ( "html and entities", "<div>a</div>\n\n<script>alert(1)</script> &amp; <b>b</b>" )
    , ( "fences", "~~~\nwhile ``` is inside\n~~~\n\n````md\n```\nnested\n```\n````\n\nafter" )
    , ( "task lists", "- [ ] one\n- [x] two\n  - [ ] sub\n\n1. [x] numbered" )
    ]


stability : Test
stability =
    describe "text that grows"
        [ describe "the complete blocks do not change"
            (List.map (\( name, text ) -> test name (\_ -> stableAtEvery text)) documents)
        , fuzzWith { runs = 250, distribution = Test.noDistribution } (Fuzz.listOfLengthBetween 1 40 fragment |> Fuzz.map String.concat) "after every blank line of a random text" stableAfterBlankLines
        ]
