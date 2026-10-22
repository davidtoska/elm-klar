module Support.MarkdownHtml exposing (document, inlines, render)

{-| Writes the result of the Markdown parser as compact HTML, so that a test can
say what a text must become in the notation of the CommonMark examples.

There is no white space between the elements, and the paragraphs in the items of
a tight list have no `p`, as in CommonMark. A task item starts with `[ ]` or `[x]`.
Raw text is escaped, so a test can see that `<script>` is only text.

-}

import Klar.Markdown.Inline as Inline exposing (Inline(..))
import Klar.Markdown.Parse as Parse exposing (Align(..), Block(..))


{-| A text as HTML.
-}
render : String -> String
render text =
    document (Parse.parse text)


document : Parse.Document -> String
document parsed =
    blocks False parsed.blocks
        ++ (case parsed.truncated of
                Just cut ->
                    "<notice " ++ String.fromInt cut.shown ++ "/" ++ String.fromInt cut.total ++ ">"

                Nothing ->
                    ""
           )


blocks : Bool -> List Block -> String
blocks tight list =
    String.concat (List.map (block tight) list)


block : Bool -> Block -> String
block tight b =
    case b of
        Paragraph content ->
            if tight then
                inlines content

            else
                "<p>" ++ inlines content ++ "</p>"

        HeadingBlock heading ->
            let
                tag =
                    "h" ++ String.fromInt heading.level
            in
            "<" ++ tag ++ " id=\"" ++ heading.id ++ "\">" ++ inlines heading.content ++ "</" ++ tag ++ ">"

        Quote inner ->
            "<blockquote>" ++ blocks False inner ++ "</blockquote>"

        CodeBlock code ->
            "<pre><code"
                ++ (if code.language == "" then
                        ""

                    else
                        " class=\"language-" ++ code.language ++ "\""
                   )
                ++ ">"
                ++ escape code.code
                ++ "</code></pre>"

        ListBlock list ->
            let
                items =
                    String.concat (List.map (item list.tight) list.items)
            in
            case list.start of
                Just 1 ->
                    "<ol>" ++ items ++ "</ol>"

                Just n ->
                    "<ol start=\"" ++ String.fromInt n ++ "\">" ++ items ++ "</ol>"

                Nothing ->
                    "<ul>" ++ items ++ "</ul>"

        Rule ->
            "<hr>"

        Table table ->
            let
                cell tag align content =
                    "<"
                        ++ tag
                        ++ (case align of
                                AlignNone ->
                                    ""

                                AlignLeft ->
                                    " align=\"left\""

                                AlignCenter ->
                                    " align=\"center\""

                                AlignRight ->
                                    " align=\"right\""
                           )
                        ++ ">"
                        ++ inlines content
                        ++ "</"
                        ++ tag
                        ++ ">"

                row tag cells =
                    "<tr>" ++ String.concat (List.map2 (cell tag) table.aligns cells) ++ "</tr>"
            in
            "<table><thead>"
                ++ row "th" table.header
                ++ "</thead>"
                ++ (if List.isEmpty table.rows then
                        ""

                    else
                        "<tbody>" ++ String.concat (List.map (row "td") table.rows) ++ "</tbody>"
                   )
                ++ "</table>"


item : Bool -> Parse.Item -> String
item tight entry =
    "<li>"
        ++ (case entry.task of
                Just True ->
                    "[x] "

                Just False ->
                    "[ ] "

                Nothing ->
                    ""
           )
        ++ blocks tight entry.blocks
        ++ "</li>"


inlines : List Inline -> String
inlines list =
    String.concat (List.map inline list)


inline : Inline -> String
inline i =
    case i of
        Text text ->
            escape text

        Code text ->
            "<code>" ++ escape text ++ "</code>"

        Emphasis children ->
            "<em>" ++ inlines children ++ "</em>"

        Strong children ->
            "<strong>" ++ inlines children ++ "</strong>"

        Strikethrough children ->
            "<del>" ++ inlines children ++ "</del>"

        Link target children ->
            "<a href=\""
                ++ escape target.destination
                ++ "\""
                ++ (if target.title == "" then
                        ""

                    else
                        " title=\"" ++ escape target.title ++ "\""
                   )
                ++ ">"
                ++ inlines children
                ++ "</a>"

        Image image ->
            "<img src=\""
                ++ escape image.source
                ++ "\" alt=\""
                ++ escape image.alt
                ++ "\""
                ++ (if image.title == "" then
                        ""

                    else
                        " title=\"" ++ escape image.title ++ "\""
                   )
                ++ ">"

        SoftBreak ->
            "\n"

        HardBreak ->
            "<br>"


escape : String -> String
escape text =
    text
        |> String.replace "&" "&amp;"
        |> String.replace "<" "&lt;"
        |> String.replace ">" "&gt;"
        |> String.replace "\"" "&quot;"
