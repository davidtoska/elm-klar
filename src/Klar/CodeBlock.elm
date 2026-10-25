module Klar.CodeBlock exposing
    ( view
    , Language, plain, json, elm
    , Attribute, language, lineNumbers, highlightLines, maxLines, maxHeight, download, locale
    )

{-| Read-only source code with lexical highlighting, line numbers and an honest
preview limit; source is always escaped text and is never executed.

Use when: a person must inspect a payload, query, configuration or generated code.
Do not use when: the text must be edited, use `Klar.TextArea` or `Klar.MarkdownEditor`.

    import Klar.CodeBlock as CodeBlock

    CodeBlock.view
        [ CodeBlock.language CodeBlock.json
        , CodeBlock.lineNumbers True
        , CodeBlock.highlightLines [ 2 ]
        , CodeBlock.download "order.json"
        ]
        { id = "order-payload", label = "Order payload", source = "{\n  \"quantity\": 12\n}" }

The named scroll region is a keyboard stop. Lines do not wrap, so indentation and
long values remain exact. The line-number gutter cannot be selected and is hidden
from screen readers. The code itself preserves every character, including tabs,
CRLF and a final newline; no trimming, parsing or formatting is applied.

`json` and `elm` are lexical guides, not validators. Unfinished strings and Elm's
nested comments remain visible. Highlighting is bounded to 30,000 characters of
the visible source; beyond that the source is plain text in full. A preview limit
is always accompanied by its visible and total line counts, while `download`
always contains the complete original source. There is no clipboard action: select
the source and use the browser's native copy command.

Without marked lines, large plain sources use a single source text node. Marking
lines requires one span per visible line; use `maxLines` for very large marked
documents. Rendering is otherwise unrestricted and the complete text is retained.

This component receives local text. For backend data put it inside `Klar.RemoteView`.

@docs view


# Languages

@docs Language, plain, json, elm


# Attributes

@docs Attribute, language, lineNumbers, highlightLines, maxLines, maxHeight, download, locale

-}

import Html exposing (Html)
import Html.Attributes as Attr
import Klar.CodeBlock.Lexer as Lexer
import Klar.Format as Format
import Klar.Internal as Internal
import Klar.Locale as Locale exposing (Locale)
import Set exposing (Set)


{-| An opaque lexical-highlighting mode. The default is `plain`.
-}
type Language
    = Language Lexer.Language


{-| Plain, uncoloured source. No syntax is assumed.
-}
plain : Language
plain =
    Language Lexer.Plain


{-| JSON strings, numbers and literal words. This does not validate JSON.
-}
json : Language
json =
    Language Lexer.Json


{-| Elm keywords, strings, character literals and nested comments. Not a parser.
-}
elm : Language
elm =
    Language Lexer.Elm


{-| Optional source-view settings; later attributes win.
-}
type Attribute
    = Attribute (Config -> Config)


type alias Config =
    { language : Language, lineNumbers : Bool, highlights : Set Int, maxLines : Maybe Int, maxHeight : Maybe Int, download : Maybe String, locale : Locale }


{-| Lexical highlighting. Defaults to `plain`.
-}
language : Language -> Attribute
language value =
    Attribute (\c -> { c | language = value })


{-| Shows an unselectable gutter. Defaults to `False`.
-}
lineNumbers : Bool -> Attribute
lineNumbers value =
    Attribute (\c -> { c | lineNumbers = value })


{-| One-based lines to mark, with an underline as well as a background.
Nonpositive and nonexistent lines have no effect. No lines are marked by default.
-}
highlightLines : List Int -> Attribute
highlightLines lines =
    Attribute (\c -> { c | highlights = Set.fromList (List.filter ((<) 0) lines) })


{-| Limits the preview to this many lines; zero or negative values show no source
lines. The footer always discloses truncation. Unrestricted by default.
-}
maxLines : Int -> Attribute
maxLines count =
    Attribute (\c -> { c | maxLines = Just (Basics.max 0 count) })


{-| Maximum scroll-region height in pixels, at least 80. Unrestricted by default.
-}
maxHeight : Int -> Attribute
maxHeight pixels =
    Attribute (\c -> { c | maxHeight = Just (Basics.max 80 pixels) })


{-| Adds a native download link for the complete source with this suggested file
name. The browser may sanitize the name. No download link by default.
-}
download : String -> Attribute
download name =
    Attribute (\c -> { c | download = Just name })


{-| Built-in text language. Defaults to English.
-}
locale : Locale -> Attribute
locale value =
    Attribute (\c -> { c | locale = value })


{-| Draws exact local source. `id` must be unique on the page; `label` names the
keyboard-accessible scroll region and its download action.
-}
view : List Attribute -> { id : String, label : String, source : String } -> Html msg
view attributes data =
    let
        c =
            List.foldl (\(Attribute change) acc -> change acc)
                { language = plain, lineNumbers = False, highlights = Set.empty, maxLines = Nothing, maxHeight = Nothing, download = Nothing, locale = Locale.default }
                attributes

        pick en nb =
            Locale.pick c.locale { en = en, nb = nb }

        originalLines =
            if data.source == "" then
                []

            else
                String.split "\n" data.source

        shownLines =
            case c.maxLines of
                Nothing ->
                    originalLines

                Just count ->
                    List.take count originalLines

        visibleSource =
            String.join "\n" shownLines

        (Language mode) =
            c.language

        -- Tokenise once across line boundaries; split tokens afterwards so a
        -- multiline string or comment keeps its category on every visible line.
        renderedSource =
            let
                tokens =
                    Lexer.highlight mode visibleSource
            in
            if Set.isEmpty c.highlights then
                List.map renderToken tokens

            else
                tokens
                    |> splitTokens
                    |> List.indexedMap
                        (\index line ->
                            Html.span [ Internal.classes [ ( "klar-code-block__line", True ), ( "klar-code-block__line--marked", Set.member (index + 1) c.highlights ) ] ]
                                (List.map renderToken line)
                        )
                    |> List.intersperse (Html.text "\n")

        total =
            List.length originalLines

        shown =
            List.length shownLines

        truncated =
            shown < total

        counts =
            Format.int c.locale shown ++ pick " of " " av " ++ Format.int c.locale total ++ pick " lines shown" " linjer vist"
    in
    Html.div [ Internal.cls [ "klar-code-block" ] ]
        [ Html.div [ Internal.cls [ "klar-code-block__toolbar" ] ]
            [ Html.strong [] [ Html.text data.label ]
            , case c.download of
                Just name ->
                    Html.a
                        [ Attr.href ("data:text/plain;charset=utf-8," ++ Internal.percentEncode data.source), Attr.download name, Attr.target "_blank", Attr.rel "noopener", Internal.cls [ "klar-code-block__download" ], Attr.attribute "aria-label" (pick "Download " "Last ned " ++ data.label) ]
                        [ Html.text (pick "Download source" "Last ned kilde") ]

                Nothing ->
                    Html.text ""
            ]
        , Html.div
            ([ Attr.id data.id, Attr.tabindex 0, Attr.attribute "role" "region", Attr.attribute "aria-label" data.label, Internal.cls [ "klar-code-block__scroll" ] ]
                ++ (c.maxHeight |> Maybe.map (\pixels -> [ Internal.styleVars [ ( "--klar-code-height", Internal.px pixels ) ] ]) |> Maybe.withDefault [])
            )
            [ if c.lineNumbers then
                Html.pre [ Internal.cls [ "klar-code-block__numbers" ], Attr.attribute "aria-hidden" "true" ]
                    [ Html.text (List.range 1 shown |> List.map String.fromInt |> String.join "\n") ]

              else
                Html.text ""
            , Html.pre [ Internal.cls [ "klar-code-block__source" ] ] [ Html.code [] renderedSource ]
            ]
        , if truncated then
            Html.div [ Internal.cls [ "klar-code-block__notice" ], Attr.attribute "role" "status" ] [ Html.text (counts ++ pick " — preview truncated" " — forhåndsvisningen er avkortet") ]

          else if data.source == "" then
            Html.div [ Internal.cls [ "klar-code-block__notice" ], Attr.attribute "role" "status" ] [ Html.text (pick "Empty source" "Tom kilde") ]

          else
            Html.text ""
        ]


renderToken : Lexer.Token -> Html msg
renderToken token =
    case token.kind of
        Lexer.Text ->
            Html.text token.text

        _ ->
            Html.span
                [ Internal.cls
                    [ "klar-code-block__token--"
                        ++ (case token.kind of
                                Lexer.Keyword ->
                                    "keyword"

                                Lexer.Quoted ->
                                    "quoted"

                                Lexer.Number ->
                                    "number"

                                Lexer.Comment ->
                                    "comment"

                                Lexer.Text ->
                                    "text"
                           )
                    ]
                ]
                [ Html.text token.text ]


splitTokens : List Lexer.Token -> List (List Lexer.Token)
splitTokens tokens =
    let
        add token ( current, previous ) =
            case String.split "\n" token.text of
                first :: rest ->
                    List.foldl (\part ( line, done ) -> ( [ { kind = token.kind, text = part } ], List.reverse line :: done ))
                        ( { kind = token.kind, text = first } :: current, previous )
                        rest

                [] ->
                    ( current, previous )

        ( last, before ) =
            List.foldl add ( [], [] ) tokens
    in
    List.reverse (List.reverse last :: before)
