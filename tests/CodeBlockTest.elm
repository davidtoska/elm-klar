module CodeBlockTest exposing (suite)

import Expect
import Fuzz
import Html.Attributes as Attr
import Klar.CodeBlock as Code
import Klar.CodeBlock.Lexer as Lexer
import Klar.Internal as Internal
import Klar.Locale as Locale
import Test exposing (Test, describe, fuzz, test)
import Test.Html.Query as Query
import Test.Html.Selector as S


source : String
source =
    "{\u{000D}\n\t\"unsafe\": \"<script>&\\\"\",\n  \"ready\": true\n}\n"


widget : List Code.Attribute -> String -> Query.Single msg
widget attributes text =
    Code.view attributes { id = "payload", label = "Order payload", source = text } |> Query.fromHtml


restore : List Lexer.Token -> String
restore =
    List.map .text >> String.concat


suite : Test
suite =
    describe "Klar.CodeBlock"
        [ test "plain source does not allocate a DOM span for every line" <|
            \_ ->
                widget [] (String.repeat 10000 "x\n") |> Query.findAll [ S.class "klar-source__line" ] |> Query.count (Expect.equal 0)
        , describe "Lexical highlighting preserves source"
            (List.map (\( label, mode ) -> fuzz Fuzz.string (label ++ " round trips all characters") <| \text -> Lexer.highlight mode text |> restore |> Expect.equal text)
                [ ( "plain", Lexer.Plain ), ( "JSON", Lexer.Json ), ( "Elm", Lexer.Elm ) ]
            )
        , test "JSON escaped quotes stay in one string token" <|
            \_ ->
                Lexer.highlight Lexer.Json "\"a\\\"b\"" |> Expect.equal [ { kind = Lexer.Quoted, text = "\"a\\\"b\"" } ]
        , test "unfinished strings preserve all their characters" <|
            \_ ->
                Lexer.highlight Lexer.Json "\"unfinished\\" |> restore |> Expect.equal "\"unfinished\\"
        , test "nested Elm comments remain one comment" <|
            \_ ->
                Lexer.highlight Lexer.Elm "{- outside {- inside -} outside -}" |> Expect.equal [ { kind = Lexer.Comment, text = "{- outside {- inside -} outside -}" } ]
        , test "unfinished nested comments preserve all characters" <|
            \_ ->
                Lexer.highlight Lexer.Elm "{- one {- two -}" |> restore |> Expect.equal "{- one {- two -}"
        , test "Elm multiline strings carry their newlines unchanged" <|
            \_ ->
                Lexer.highlight Lexer.Elm "\"\"\"one\ntwo\"\"\"" |> Expect.equal [ { kind = Lexer.Quoted, text = "\"\"\"one\ntwo\"\"\"" } ]
        , test "an apostrophe in an Elm identifier is not a string delimiter" <|
            \_ ->
                Lexer.highlight Lexer.Elm "model'" |> Expect.equal [ { kind = Lexer.Text, text = "model'" } ]
        , test "keywords inside strings are not highlighted as keywords" <|
            \_ ->
                Lexer.highlight Lexer.Elm "\"if then else\"" |> List.map .kind |> Expect.equal [ Lexer.Quoted ]
        , test "the highlighting budget leaves large source intact" <|
            \_ ->
                let
                    text =
                        String.repeat 30001 "x"
                in
                Lexer.highlight Lexer.Elm text |> Expect.equal [ { kind = Lexer.Text, text = text } ]
        , test "many small tokens are stack safe within the highlighting budget" <|
            \_ ->
                let
                    text =
                        String.repeat 10000 "a "
                in
                Lexer.highlight Lexer.Elm text |> restore |> Expect.equal text
        , test "the source is escaped rather than inserted as HTML" <|
            \_ ->
                widget [ Code.language Code.json ] source
                    |> Expect.all
                        [ Query.has [ S.text "<script>" ], Query.findAll [ S.tag "script" ] >> Query.count (Expect.equal 0) ]
        , test "the scroll region is named and keyboard focusable" <|
            \_ ->
                widget [] "abc" |> Query.find [ S.id "payload" ] |> Query.has [ S.attribute (Attr.tabindex 0), S.attribute (Attr.attribute "role" "region"), S.attribute (Attr.attribute "aria-label" "Order payload") ]
        , test "line-number gutter is hidden from screen readers" <|
            \_ ->
                widget [ Code.lineNumbers True ] "one\ntwo" |> Query.find [ S.class "klar-source__numbers" ] |> Query.has [ S.attribute (Attr.attribute "aria-hidden" "true") ]
        , test "line numbers are absent unless requested" <|
            \_ ->
                widget [] "one\ntwo" |> Query.findAll [ S.class "klar-source__numbers" ] |> Query.count (Expect.equal 0)
        , test "a preview discloses its visible and total counts" <|
            \_ ->
                widget [ Code.maxLines 2 ] "one\ntwo\nthree" |> Query.has [ S.text "2 of 3 lines shown — preview truncated" ]
        , test "a zero-line preview still discloses the missing source" <|
            \_ ->
                widget [ Code.maxLines 0 ] "one\ntwo" |> Query.has [ S.text "0 of 2 lines shown — preview truncated" ]
        , test "download always uses full original source, including CRLF and final newline" <|
            \_ ->
                widget [ Code.maxLines 1, Code.download "order.json" ] source |> Query.find [ S.tag "a" ] |> Query.has [ S.attribute (Attr.href ("data:text/plain;charset=utf-8," ++ Internal.percentEncode source)), S.attribute (Attr.download "order.json"), S.attribute (Attr.target "_blank") ]
        , test "only existing positive lines are highlighted" <|
            \_ ->
                widget [ Code.highlightLines [ -1, 0, 2, 2, 99 ] ] "one\ntwo\nthree" |> Query.findAll [ S.class "klar-source__line--marked" ] |> Query.count (Expect.equal 1)
        , test "an empty source is named explicitly" <|
            \_ ->
                widget [] "" |> Query.has [ S.text "Empty source" ]
        , test "Norwegian preview and action text" <|
            \_ ->
                widget [ Code.locale Locale.nb, Code.maxLines 1, Code.download "order.txt" ] "one\ntwo" |> Expect.all [ Query.has [ S.text "1 av 2 linjer vist — forhåndsvisningen er avkortet" ], Query.has [ S.text "Last ned kilde" ] ]
        ]
