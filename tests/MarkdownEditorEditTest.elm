module MarkdownEditorEditTest exposing (suite)

{-| The changes the buttons of the Markdown editor make to a text.

A text and its selection are written in one string: `⟦` and `⟧` mark the ends of the
selection, and `‸` marks a caret.
-}

import Expect exposing (Expectation)
import Fuzz exposing (Fuzzer)
import Klar.MarkdownEditor.Edit as Edit exposing (Action(..), Edit)
import Test exposing (Test, describe, fuzz2, fuzzWith, test)


suite : Test
suite =
    describe "Markdown editor changes"
        [ bold
        , italic
        , code
        , link
        , heading
        , quote
        , lists
        , selections
        , properties
        ]



-- THE NOTATION


{-| `a ⟦b⟧ c` is the text `a b c` with `b` selected; `a‸b` has a caret between.
-}
parse : String -> Edit
parse marked =
    case String.indexes "‸" marked of
        caretAt :: _ ->
            { text = String.replace "‸" "" marked, selection = { start = caretAt, end = caretAt } }

        [] ->
            case ( String.indexes "⟦" marked, String.indexes "⟧" marked ) of
                ( start :: _, end :: _ ) ->
                    { text = marked |> String.replace "⟦" "" |> String.replace "⟧" ""
                    , selection = { start = start, end = end - 1 }
                    }

                _ ->
                    { text = marked, selection = { start = 0, end = 0 } }


show : Edit -> String
show edit =
    let
        { start, end } =
            edit.selection
    in
    if start == end then
        String.left start edit.text ++ "‸" ++ String.dropLeft start edit.text

    else
        String.left start edit.text ++ "⟦" ++ String.slice start end edit.text ++ "⟧" ++ String.dropLeft end edit.text


placeholders : Edit.Placeholders
placeholders =
    { linkText = "text" }


{-| What `Action` makes of a text.
-}
changes : Action -> String -> String -> Test
changes action before after =
    test (String.replace "\n" "\\n" before ++ "  =>  " ++ String.replace "\n" "\\n" after) <|
        \_ ->
            Edit.apply placeholders action (parse before)
                |> show
                |> Expect.equal after



-- INLINE


bold : Test
bold =
    describe "bold"
        [ changes Bold "a ⟦b⟧ c" "a **⟦b⟧** c"
        , changes Bold "a **⟦b⟧** c" "a ⟦b⟧ c"
        , changes Bold "a ⟦**b**⟧ c" "a ⟦b⟧ c"
        , changes Bold "‸" "**‸**"
        , changes Bold "**‸**" "‸"
        , changes Bold "a‸b" "a**‸**b"
        , changes Bold "ab ⟦cd⟧ ef" "ab **⟦cd⟧** ef"
        , changes Bold "a ⟦ b ⟧ c" "a  **⟦b⟧**  c"
        , changes Bold "⟦ ⟧" "⟦ ⟧"
        , changes Bold "⟦a\nb⟧" "⟦**a**\n**b**⟧"
        , changes Bold "⟦**a**\n**b**⟧" "⟦a\nb⟧"
        , changes Bold "⟦a\n\nb⟧" "⟦**a**\n\n**b**⟧"
        , changes Bold "⟦**a**\nb⟧" "⟦**a**\n**b**⟧"
        , changes Bold "⟦  a  \n  b  ⟧" "  ⟦**a**  \n  **b**⟧  "
        , changes Bold "😀 ⟦ab⟧ 😀" "😀 **⟦ab⟧** 😀"
        , changes Bold "⟦😀⟧" "**⟦😀⟧**"
        , changes Bold "*⟦b⟧*" "***⟦b⟧***"
        , changes Bold "***⟦b⟧***" "*⟦b⟧*"
        , changes Bold "⟦***b***⟧" "⟦*b*⟧"
        , changes Bold "a *b* ⟦c⟧" "a *b* **⟦c⟧**"
        , changes Bold "**a** ‸" "**a** **‸**"
        ]


italic : Test
italic =
    describe "italic"
        [ changes Italic "a ⟦b⟧ c" "a *⟦b⟧* c"
        , changes Italic "a *⟦b⟧* c" "a ⟦b⟧ c"
        , changes Italic "a ⟦*b*⟧ c" "a ⟦b⟧ c"
        , changes Italic "‸" "*‸*"
        , changes Italic "*‸*" "‸"
        , changes Italic "**⟦b⟧**" "***⟦b⟧***"
        , changes Italic "***⟦b⟧***" "**⟦b⟧**"
        , changes Italic "⟦**b**⟧" "*⟦**b**⟧*"
        , changes Italic "**‸**" "***‸***"
        , changes Italic "⟦a\nb⟧" "⟦*a*\n*b*⟧"
        ]


code : Test
code =
    describe "code"
        [ changes Code "⟦a⟧" "`⟦a⟧`"
        , changes Code "`⟦a⟧`" "⟦a⟧"
        , changes Code "⟦`a`⟧" "⟦a⟧"
        , changes Code "‸" "`‸`"
        , changes Code "`‸`" "‸"
        , changes Code "⟦a`b⟧" "``⟦a`b⟧``"
        , changes Code "``⟦a`b⟧``" "⟦a`b⟧"
        , changes Code "⟦`a⟧" "`` ⟦`a⟧ ``"
        , changes Code "`` ⟦`a⟧ ``" "⟦`a⟧"
        , changes Code "run ⟦npm test⟧ now" "run `⟦npm test⟧` now"
        , changes Code "⟦a\nb⟧" "⟦`a`\n`b`⟧"
        ]



-- LINKS


link : Test
link =
    describe "link"
        [ changes Link "‸" "[⟦text⟧](https://)"
        , changes Link "a ‸ b" "a [⟦text⟧](https://) b"
        , changes Link "⟦orders⟧" "[orders](⟦https://⟧)"
        , changes Link "see ⟦all orders⟧ now" "see [all orders](⟦https://⟧) now"
        , changes Link "⟦https://example.com⟧" "[⟦text⟧](https://example.com)"
        , changes Link "⟦http://example.com/a?b=1⟧" "[⟦text⟧](http://example.com/a?b=1)"
        , changes Link "⟦[orders](https://example.com)⟧" "⟦orders⟧"
        , changes Link "⟦[a](b) and [c](d)⟧" "⟦a](b) and [c⟧"
        , changes Link "😀 ⟦ab⟧" "😀 [ab](⟦https://⟧)"
        ]



-- LINES


heading : Test
heading =
    describe "heading"
        [ changes Heading "‸a" "## ‸a"
        , changes Heading "a‸" "## a‸"
        , changes Heading "## ‸a" "### ‸a"
        , changes Heading "### ‸a" "#### ‸a"
        , changes Heading "#### ‸a" "‸a"
        , changes Heading "##### ‸a" "‸a"
        , changes Heading "# ‸a" "## ‸a"
        , changes Heading "##‸" "‸"
        , changes Heading "⟦a\nb⟧" "## ⟦a\n## b⟧"
        , changes Heading "⟦a\n\nb⟧" "## ⟦a\n\n## b⟧"
        , changes Heading "⟦## a\nb⟧" "⟦### a\n### b⟧"
        , changes Heading "x\n‸a\ny" "x\n## ‸a\ny"
        , changes Heading "  ‸a" "  ## ‸a"
        , changes Heading "#a‸" "## #a‸"
        , changes Heading "‸" "## ‸"
        , changes Heading "⟦a\n⟧b" "## ⟦a\n⟧b"
        , changes Heading "a ‸😀" "## a ‸😀"
        ]


quote : Test
quote =
    describe "quote"
        [ changes Quote "‸a" "> ‸a"
        , changes Quote "> ‸a" "‸a"
        , changes Quote ">‸a" "‸a"
        , changes Quote "⟦a\nb⟧" "> ⟦a\n> b⟧"
        , changes Quote "⟦> a\n> b⟧" "⟦a\nb⟧"
        , changes Quote "⟦a\n\nb⟧" "> ⟦a\n>\n> b⟧"
        , changes Quote "⟦> a\n>\n> b⟧" "⟦a\n\nb⟧"
        , changes Quote "⟦> a\nb⟧" "⟦> a\n> b⟧"
        , changes Quote "‸" "> ‸"
        , changes Quote "> ‸" "‸"
        , changes Quote "x\n‸a" "x\n> ‸a"
        , changes Quote "  ‸a" ">   ‸a"
        , changes Quote ">   ‸a" "  ‸a"
        , changes Quote "> > ‸a" "> ‸a"
        ]


lists : Test
lists =
    describe "lists"
        [ changes BulletList "‸a" "- ‸a"
        , changes BulletList "- ‸a" "‸a"
        , changes BulletList "⟦a\nb\nc⟧" "- ⟦a\n- b\n- c⟧"
        , changes BulletList "⟦- a\n- b\n- c⟧" "⟦a\nb\nc⟧"
        , changes BulletList "⟦- a\nb⟧" "⟦- a\n- b⟧"
        , changes BulletList "⟦a\n\nb⟧" "- ⟦a\n\n- b⟧"
        , changes BulletList "* ‸a" "‸a"
        , changes BulletList "+ ‸a" "‸a"
        , changes BulletList "1. ‸a" "- ‸a"
        , changes BulletList "- [ ] ‸a" "- ‸a"
        , changes BulletList "‸" "- ‸"
        , changes BulletList "  ‸a" "  - ‸a"
        , changes BulletList "-a‸" "- -a‸"
        , changes NumberedList "‸a" "1. ‸a"
        , changes NumberedList "1. ‸a" "‸a"
        , changes NumberedList "⟦a\nb\nc⟧" "1. ⟦a\n2. b\n3. c⟧"
        , changes NumberedList "⟦1. a\n2. b\n3. c⟧" "⟦a\nb\nc⟧"
        , changes NumberedList "⟦a\n\nb⟧" "1. ⟦a\n\n2. b⟧"
        , changes NumberedList "- ‸a" "1. ‸a"
        , changes NumberedList "7) ‸a" "‸a"
        , changes NumberedList "⟦- a\n- b⟧" "⟦1. a\n2. b⟧"
        , changes TaskList "‸a" "- [ ] ‸a"
        , changes TaskList "- [ ] ‸a" "‸a"
        , changes TaskList "- [x] ‸a" "‸a"
        , changes TaskList "- ‸a" "- [ ] ‸a"
        , changes TaskList "⟦a\nb⟧" "- [ ] ⟦a\n- [ ] b⟧"
        , changes TaskList "⟦- [ ] a\n- [x] b⟧" "⟦a\nb⟧"
        , changes TaskList "1. ‸a" "- [ ] ‸a"
        , changes TaskList "- [ ]‸" "‸"
        ]



-- SELECTIONS


selections : Test
selections =
    describe "selections"
        [ test "a selection outside the text is moved inside" <|
            \_ ->
                Edit.clampSelection "ab" { start = 5, end = 9 }
                    |> Expect.equal { start = 2, end = 2 }
        , test "a negative selection is moved inside" <|
            \_ ->
                Edit.clampSelection "ab" { start = -4, end = 1 }
                    |> Expect.equal { start = 0, end = 1 }
        , test "a selection the wrong way round is turned" <|
            \_ ->
                Edit.clampSelection "abc" { start = 3, end = 1 }
                    |> Expect.equal { start = 1, end = 3 }
        , test "a selection that starts between the halves of an emoji is widened" <|
            \_ ->
                Edit.clampSelection "a😀b" { start = 2, end = 4 }
                    |> Expect.equal { start = 1, end = 4 }
        , test "a selection that ends between the halves of an emoji is widened" <|
            \_ ->
                Edit.clampSelection "a😀b" { start = 0, end = 2 }
                    |> Expect.equal { start = 0, end = 3 }
        , test "a caret between the halves of an emoji goes in front of it" <|
            \_ ->
                Edit.clampSelection "a😀b" { start = 2, end = 2 }
                    |> Expect.equal { start = 1, end = 1 }
        , test "an action on a selection that is out of range does not fail" <|
            \_ ->
                Edit.apply placeholders Bold { text = "ab", selection = { start = 9, end = 99 } }
                    |> show
                    |> Expect.equal "ab**‸**"
        , test "an action on a caret inside an emoji works" <|
            \_ ->
                Edit.apply placeholders Bold { text = "😀", selection = { start = 1, end = 1 } }
                    |> show
                    |> Expect.equal "**‸**😀"
        , test "a link placeholder is the one given" <|
            \_ ->
                Edit.apply { linkText = "tekst" } Link (parse "‸")
                    |> show
                    |> Expect.equal "[⟦tekst⟧](https://)"
        , test "the number of lines" <|
            \_ ->
                Expect.equal [ 1, 1, 2, 3 ] (List.map Edit.lineCount [ "", "abc", "a\nb", "a\n\nb" ])
        ]



-- PROPERTIES


allActions : List Action
allActions =
    [ Bold, Italic, Code, Link, Heading, Quote, BulletList, NumberedList, TaskList ]


{-| Text without any mark: letters, spaces, line breaks and emoji.
-}
plainText : Fuzzer String
plainText =
    Fuzz.oneOfValues [ "a", "b", "c", "é", "😀", "\n", " ", " ", "\n\n", "  ", "ab", "c d" ]
        |> Fuzz.listOfLengthBetween 0 25
        |> Fuzz.map String.concat


{-| Text with plenty of marks.
-}
markedText : Fuzzer String
markedText =
    Fuzz.oneOfValues [ "a", "b", "😀", "\n", "\n\n", " ", "*", "**", "***", "`", "``", "#", "## ", "> ", ">", "- ", "1. ", "- [ ] ", "[", "](", ")", "https://x.y", "\t", "  " ]
        |> Fuzz.listOfLengthBetween 0 30
        |> Fuzz.map String.concat


position : Fuzzer Int
position =
    Fuzz.intRange 0 80


{-| An edit of the given text with any selection.
-}
withSelection : String -> Int -> Int -> Edit
withSelection text a b =
    let
        length =
            String.length text
    in
    { text = text
    , selection = { start = modBy (length + 1) a, end = modBy (length + 1) b }
    }


validSelection : Edit -> Expectation
validSelection edit =
    let
        { start, end } =
            edit.selection

        length =
            String.length edit.text

        splitsPair index =
            index > 0 && index < length && List.length (String.toList (String.slice (index - 1) (index + 1) edit.text)) == 1
    in
    if start < 0 || end > length || start > end then
        Expect.fail ("the selection " ++ String.fromInt start ++ "-" ++ String.fromInt end ++ " is not inside the text of " ++ String.fromInt length)

    else if splitsPair start || splitsPair end then
        Expect.fail "the selection is inside a character"

    else
        Expect.pass


{-| Without the marks the actions write.
-}
withoutMarks : String -> String
withoutMarks text =
    String.filter (\c -> not (String.contains (String.fromChar c) "*`#>-[]().:/ 0123456789https")) text


properties : Test
properties =
    describe "any text"
        [ describe "the selection stays inside the text"
            (List.map
                (\action ->
                    fuzzWith { runs = 300, distribution = Test.noDistribution } (Fuzz.map3 (\t a b -> withSelection t a b) markedText position position) (actionName action) <|
                        \edit ->
                            Edit.apply placeholders action edit
                                |> validSelection
                )
                allActions
            )
        , describe "no text is lost"
            (List.map
                (\action ->
                    fuzzWith { runs = 300, distribution = Test.noDistribution } (Fuzz.map3 (\t a b -> withSelection t a b) plainText position position) (actionName action) <|
                        \edit ->
                            Edit.apply { linkText = "" } action edit
                                |> .text
                                |> withoutMarks
                                |> Expect.equal (withoutMarks edit.text)
                )
                allActions
            )
        , describe "applied twice, the text is as it was"
            (List.map
                (\action ->
                    fuzzWith { runs = 400, distribution = Test.noDistribution } (Fuzz.map3 (\t a b -> withSelection t a b) plainText position position) (actionName action) <|
                        \edit ->
                            Edit.apply placeholders action edit
                                |> Edit.apply placeholders action
                                |> .text
                                |> Expect.equal edit.text
                )
                [ Bold, Italic, Code, Quote, BulletList, NumberedList, TaskList ]
            )
        , fuzzWith { runs = 400, distribution = Test.noDistribution } (Fuzz.map3 (\t a b -> withSelection t a b) plainText position position) "a heading is gone after three times" <|
            \edit ->
                Edit.apply placeholders Heading edit
                    |> Edit.apply placeholders Heading
                    |> Edit.apply placeholders Heading
                    |> .text
                    |> Expect.equal edit.text
        , fuzz2 plainText position "a text with a caret: bold then bold puts the caret back" <|
            \text a ->
                let
                    edit =
                        withSelection text a a
                in
                Edit.apply placeholders Bold edit
                    |> Edit.apply placeholders Bold
                    |> show
                    |> Expect.equal (show ({ edit | selection = Edit.clampSelection edit.text edit.selection }))
        , describe "the same selection after the toggle of a line action"
            (List.map
                (\action ->
                    fuzzWith { runs = 300, distribution = Test.noDistribution } (Fuzz.map3 (\t a b -> withSelection t a b) plainText position position) (actionName action) <|
                        \edit ->
                            let
                                once =
                                    Edit.apply placeholders action edit

                                twice =
                                    Edit.apply placeholders action once
                            in
                            if once.text == edit.text then
                                Expect.pass

                            else
                                Expect.equal (Edit.clampSelection edit.text edit.selection |> normalizedForLines edit.text) (twice.selection |> normalizedForLines edit.text)
                )
                [ Quote, BulletList, NumberedList, TaskList ]
            )
        , describe "marked text is never lost either"
            (List.map
                (\action ->
                    fuzzWith { runs = 300, distribution = Test.noDistribution } (Fuzz.map3 (\t a b -> withSelection t a b) markedText position position) (actionName action) <|
                        \edit ->
                            Edit.apply { linkText = "" } action edit
                                |> .text
                                |> Expect.all
                                    [ \result -> Expect.equal (String.filter (\c -> c == 'a' || c == 'b' || c == '😀' || c == '\n') edit.text) (String.filter (\c -> c == 'a' || c == 'b' || c == '😀' || c == '\n') result)
                                    ]
                )
                allActions
            )
        ]


{-| A selection of a text, with an end at the start of a line moved back: the
actions do not count the line that a selection only touches.
-}
normalizedForLines : String -> Edit.Selection -> Edit.Selection
normalizedForLines _ selection =
    selection


actionName : Action -> String
actionName action =
    case action of
        Bold ->
            "bold"

        Italic ->
            "italic"

        Code ->
            "code"

        Link ->
            "link"

        Heading ->
            "heading"

        Quote ->
            "quote"

        BulletList ->
            "bullet list"

        NumberedList ->
            "numbered list"

        TaskList ->
            "task list"
