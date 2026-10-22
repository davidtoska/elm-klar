module Klar.Markdown exposing
    ( view, viewDocument
    , Document, parse, plainText
    , Heading, headings, headingLevel, headingText, headingId
    , Attribute, locale, headingOffset, idPrefix, images, imagesFrom
    )

{-| Markdown as safe, calm HTML: for the text of a note, a description, a help
page, or the answer of a language model that is still being written.

    import Klar.Markdown as Markdown

    Markdown.view [] model.description

    Markdown.view [ Markdown.headingOffset 2 ] article.body

The text is read by a small parser of this package, not by the browser, and
nothing in it can run code or call a server on its own. This is what makes the
module safe for text you did not write:

  - **HTML is text.** `<script>` and `<img onerror=...>` are shown as the
    characters they are. Nothing is ever passed to the page as markup.
  - **Links are checked.** Only `http:`, `https:`, `mailto:`, `tel:`, relative
    paths and `#fragments` become links. `javascript:`, `data:` and every other
    address (also when it is hidden behind capital letters, tabs, control
    characters or percent signs) leaves the words of the link and no link. Links
    to other sites carry `rel="noopener noreferrer"` and a small arrow.
  - **Images are not loaded** unless you ask for them with `images` or
    `imagesFrom`. A remote image tells its server that the text was read, and a
    text from a model can put what it has seen into the address of one. By
    default an image is a link with its description.
  - **The cost is bounded.** The parser is linear in the length of the text. Text
    longer than 100,000 characters is cut, and the page says so. Quotes and lists
    inside each other are followed 16 levels deep, emphasis 12, and a text such as
    `[[[[[[[[` or a line of 100,000 asterisks costs no more than any other.

**What is understood.** Headings (`#` to `######`), paragraphs, block quotes,
bullet and numbered lists (nested, tight or loose, a numbered list keeps the
number it starts at), task lists (`- [ ]` and `- [x]` become disabled check
boxes that screen readers announce), fenced code (```` ``` ```` and `~~~`, the language
is kept as a label) and indented code, thematic breaks, tables with alignment,
emphasis, strong text, `~~strikethrough~~`, code spans, links with titles,
`<autolinks>`, plain `https://` addresses, images, backslash escapes and hard
line breaks. Not understood, on purpose: HTML and `&entities;` (they are text),
setext headings (`Title` over `=====`) and reference links, because both change
what came before them and would make a half-written text jump around. A single
`~` is text, so "about ~5 minutes" is not struck through.

**Unfinished text.** The parser never fails, and text that stops in the middle of
something is shown as far as it goes: an open code fence runs to the end, an open
`**bold` is bold, an open `` `code `` is code, a table row with too few cells is
padded, and a link whose address has not arrived shows its words. The blocks that
are complete never change when more text arrives; only the last one can. So the
view of a text that grows, one piece after the other, stays still. (Anything in
the last paragraph that is only open is shown as closed. If the paragraph is
followed by a blank line, it is finished, and an unclosed `**` is text.)

**Headings** get an `id` made from their text, unique in the document (`intro`,
`intro-1`), for links to a section and for a table of contents (see `headings`).
`headingOffset` moves them down for a document inside a page that has headings of
its own: levels never go past `h6`, and a heading is never more than one level
deeper than the one before it, so the outline has no gaps.

**Layout.** The text takes the width it is given. A table or a code block that is
wider scrolls inside its own box, never the page; one that may scroll is a stop
for the Tab key, so it can be scrolled with the keyboard. Each paragraph picks its
own direction (`dir="auto"`), so a text in Arabic or Hebrew reads right to left.
The only built-in text is a few labels for screen readers; `locale` sets their
language.

The module keeps no state and sends no messages. To parse once and show the result
more than once (or to read the headings), use `parse` and `viewDocument`:

    let
        document =
            Markdown.parse model.answer
    in
    Html.div []
        [ tableOfContents (Markdown.headings document)
        , Markdown.viewDocument [] document
        ]

For a text that the user writes, [Klar.MarkdownEditor](Klar-MarkdownEditor) puts a
text area and this view side by side.


# Views

@docs view, viewDocument


# Parsing

@docs Document, parse, plainText


# Headings

@docs Heading, headings, headingLevel, headingText, headingId


# Attributes

@docs Attribute, locale, headingOffset, idPrefix, images, imagesFrom

-}

import Html exposing (Html)
import Html.Attributes as Attr
import Klar.Format as Format
import Klar.Icon as Icon
import Klar.Internal as Internal
import Klar.Locale as Locale exposing (Locale)
import Klar.Markdown.Inline as Inline exposing (Inline(..))
import Klar.Markdown.Parse as Parse exposing (Align(..), Block(..))
import Klar.Markdown.Url as Url



-- DOCUMENT


{-| A text that has been read: its blocks, headings and links, ready to be shown
or asked questions. Make one with `parse`. It is cheap to keep in the model and to
compare, so a view that shows it again and again does not read the text again.
-}
type Document
    = Document Parse.Document


{-| Reads a text. It never fails: any text gives a document, text that is
unfinished is read as far as it goes, and a text longer than 100,000 characters is
cut and says so when it is shown.

    Markdown.parse "# Orders\n\nShipped **today**."

-}
parse : String -> Document
parse text =
    Document (Parse.parse text)


{-| The text of a document without any markup: one line for each paragraph, heading,
list item, row of a table (cells separated by `|`) and line of code, with the
words of links and the descriptions of images. It fits a search index, a preview
that is cut after some characters, or a notification.

    Markdown.plainText (Markdown.parse "Ship **two** orders.") -- "Ship two orders."

-}
plainText : Document -> String
plainText (Document document) =
    Parse.plainText document



-- HEADINGS


{-| A heading of a document: its level, its text and the id of its element. Make
the list with `headings`.
-}
type Heading
    = Heading { level : Int, text : String, id : String }


{-| The headings of a document in the order they appear, also those inside quotes
and lists. Use it to build a table of contents; link each entry to
`"#" ++ Markdown.headingId heading`.

    Markdown.headings (Markdown.parse "# Orders\n\n## Open\n\n## Open")
        |> List.map Markdown.headingId
    -- [ "orders", "open", "open-1" ]

-}
headings : Document -> List Heading
headings (Document document) =
    collectHeadings document.blocks []
        |> List.reverse


collectHeadings : List Block -> List Heading -> List Heading
collectHeadings blocks found =
    List.foldl
        (\block acc ->
            case block of
                HeadingBlock heading ->
                    Heading { level = heading.level, text = Inline.plainText heading.content, id = heading.id } :: acc

                Quote inner ->
                    collectHeadings inner acc

                ListBlock list ->
                    List.foldl (\item inner -> collectHeadings item.blocks inner) acc list.items

                _ ->
                    acc
        )
        found
        blocks


{-| The level of a heading, from 1 to 6. The first heading of a document has the
level it was written with; each later one is at most one deeper than the one before
it, so a `###` that follows a `#` has level 2. It does not include the
`headingOffset` of a view.
-}
headingLevel : Heading -> Int
headingLevel (Heading heading) =
    heading.level


{-| The words of a heading, without markup.
-}
headingText : Heading -> String
headingText (Heading heading) =
    heading.text


{-| The id of the heading's element, made from its text and unique in the document:
`introduction`, `introduction-1`. It is without the `idPrefix` of a view; put your
own prefix in front when you link to the heading.
-}
headingId : Heading -> String
headingId (Heading heading) =
    heading.id



-- ATTRIBUTES


{-| A setting of the view. Make them with the functions below and pass a list to
`view` or `viewDocument`; later attributes win over earlier ones. The view sends no
messages, so the type has no `msg` parameter.
-}
type Attribute
    = Attribute (Config -> Config)


type ImagePolicy
    = NoImages
    | AnyImage
    | ImagesFrom (List String)


type alias Config =
    { locale : Locale
    , offset : Int
    , images : ImagePolicy
    , prefix : String
    }


configure : List Attribute -> Config
configure attributes =
    List.foldl (\(Attribute change) config -> change config)
        { locale = Locale.default
        , offset = 0
        , images = NoImages
        , prefix = ""
        }
        attributes


{-| The language of the few labels that are not part of the text: "Code", "Table",
"Image". Default `Locale.default`, which is English.
-}
locale : Locale -> Attribute
locale value =
    Attribute (\config -> { config | locale = value })


{-| Moves every heading down by this many levels (0 to 5), for a document that is
shown under headings of its own: with `headingOffset 2` a `#` is an `h3`. Levels
stop at `h6`. Default 0.
-}
headingOffset : Int -> Attribute
headingOffset levels =
    Attribute (\config -> { config | offset = clamp 0 5 levels })


{-| Text put in front of the id of every heading, for a page that shows several
documents with the same headings (a list of answers that all have a "Summary").
Default: none.

    Markdown.view [ Markdown.idPrefix "answer-3-" ] answer.text

-}
idPrefix : String -> Attribute
idPrefix prefix =
    Attribute (\config -> { config | prefix = prefix })


{-| Shows images as images, for relative paths and for `http:` and `https:`
addresses. By default an image is shown as a link with its description, because
loading it from another site tells that site that the text was read, and the
address of an image can carry what a text from a model knows. Turn it on only for
text you trust. To trust only your own image server, use `imagesFrom`.

The browser is told to send no referrer and to load the image lazily.

-}
images : Attribute
images =
    Attribute (\config -> { config | images = AnyImage })


{-| Shows images from relative paths and from these hosts, and every other image
as a link with its description. A host is a name such as `"images.example.com"`:
the match is exact (a subdomain needs its own entry), the case does not matter,
and an address with a user name or a port that is not part of the name never
matches.

    Markdown.view [ Markdown.imagesFrom [ "cdn.example.com" ] ] note.body

-}
imagesFrom : List String -> Attribute
imagesFrom hosts =
    Attribute (\config -> { config | images = ImagesFrom (List.map (String.toLower << String.trim) hosts) })



-- VIEW


{-| A text as HTML. This is the one to use when the text is short or changes
often; for a text that you show again and again, parse it once with `parse` and
use `viewDocument`.

    Markdown.view [] "Orders **shipped today**: see [the list](#/orders)."

-}
view : List Attribute -> String -> Html msg
view attributes text =
    viewDocument attributes (parse text)


{-| A parsed document as HTML, in a `div` that takes the width it is given.
-}
viewDocument : List Attribute -> Document -> Html msg
viewDocument attributes (Document document) =
    let
        config =
            configure attributes
    in
    Html.div [ Internal.cls [ "klar-md" ] ]
        (viewBlocks config False document.blocks
            ++ [ viewNotice config document.truncated ]
        )


viewNotice : Config -> Maybe { shown : Int, total : Int } -> Html msg
viewNotice config truncated =
    case truncated of
        Nothing ->
            Html.text ""

        Just cut ->
            let
                shown =
                    Format.int config.locale cut.shown

                total =
                    Format.int config.locale cut.total
            in
            Html.p
                [ Internal.cls [ "klar-md__notice" ]
                , Attr.attribute "role" "note"
                ]
                [ Html.text
                    (Locale.pick config.locale
                        { nb = "Bare de første " ++ shown ++ " av " ++ total ++ " tegnene vises."
                        , en = "Only the first " ++ shown ++ " of " ++ total ++ " characters are shown."
                        }
                    )
                ]


viewBlocks : Config -> Bool -> List Block -> List (Html msg)
viewBlocks config tight blocks =
    List.concatMap (viewBlock config tight) blocks


{-| One block. `tight` is for the paragraphs that are direct children of an item
of a tight list: they are not wrapped in a `p`.
-}
viewBlock : Config -> Bool -> Block -> List (Html msg)
viewBlock config tight block =
    case block of
        Paragraph inlines ->
            if tight then
                viewInlines config inlines

            else
                [ Html.p [ autoDirection ] (viewInlines config inlines) ]

        HeadingBlock heading ->
            [ Internal.heading (min 6 (heading.level + config.offset))
                [ Attr.id (config.prefix ++ heading.id), autoDirection ]
                (viewInlines config heading.content)
            ]

        Quote blocks ->
            [ Html.blockquote [ autoDirection ] (viewBlocks config False blocks) ]

        CodeBlock code ->
            [ viewCode config code ]

        ListBlock list ->
            [ viewList config list ]

        Rule ->
            [ Html.hr [] [] ]

        Table table ->
            [ viewTable config table ]


autoDirection : Html.Attribute msg
autoDirection =
    Attr.attribute "dir" "auto"



-- LISTS


viewList : Config -> { start : Maybe Int, tight : Bool, items : List Parse.Item } -> Html msg
viewList config list =
    let
        items =
            List.map (viewItem config list.tight) list.items
    in
    case list.start of
        Just 1 ->
            Html.ol [ autoDirection ] items

        Just number ->
            Html.ol [ autoDirection, Attr.start number ] items

        Nothing ->
            Html.ul [ autoDirection ] items


viewItem : Config -> Bool -> Parse.Item -> Html msg
viewItem config tight item =
    case item.task of
        Nothing ->
            Html.li [] (viewBlocks config tight item.blocks)

        Just checked ->
            Html.li [ Internal.cls [ "klar-md__task" ] ]
                (case item.blocks of
                    (Paragraph inlines) :: others ->
                        let
                            label =
                                Html.label [ Internal.cls [ "klar-md__task-label" ] ]
                                    (viewCheckbox checked :: viewInlines config inlines)
                        in
                        (if tight then
                            label

                         else
                            Html.p [ autoDirection ] [ label ]
                        )
                            :: viewBlocks config tight others

                    blocks ->
                        Html.input
                            [ Internal.cls [ "klar-md__checkbox" ]
                            , Attr.type_ "checkbox"
                            , Attr.disabled True
                            , Attr.checked checked
                            , Attr.attribute "aria-label" (itemLabel blocks)
                            ]
                            []
                            :: viewBlocks config tight blocks
                )


{-| A check box that only shows: it cannot be changed, and screen readers say
whether it is checked.
-}
viewCheckbox : Bool -> Html msg
viewCheckbox checked =
    Html.input
        [ Internal.cls [ "klar-md__checkbox" ]
        , Attr.type_ "checkbox"
        , Attr.disabled True
        , Attr.checked checked
        ]
        []


{-| The name of a check box whose item does not start with a paragraph.
-}
itemLabel : List Block -> String
itemLabel blocks =
    Parse.plainText { blocks = List.take 1 blocks, truncated = Nothing }
        |> String.left 80



-- CODE


viewCode : Config -> { language : String, code : String } -> Html msg
viewCode config code =
    let
        lines =
            String.lines code.code

        mayScroll =
            List.length lines > 16 || List.any (\line -> String.length line > 24) lines

        name =
            if code.language == "" then
                Locale.pick config.locale { nb = "Kode", en = "Code" }

            else
                Locale.pick config.locale { nb = "Kode: ", en = "Code: " } ++ code.language
    in
    Html.div [ Internal.cls [ "klar-md__code" ] ]
        [ if code.language == "" then
            Html.text ""

          else
            Html.span [ Internal.cls [ "klar-md__language" ], Attr.attribute "aria-hidden" "true" ] [ Html.text code.language ]
        , Html.pre
            ([ Internal.cls [ "klar-md__pre" ]
             , Attr.attribute "dir" "ltr"
             , Attr.attribute "role" "group"
             , Attr.attribute "aria-label" name
             ]
                ++ (if mayScroll then
                        [ Attr.tabindex 0 ]

                    else
                        []
                   )
            )
            [ Html.code
                (if code.language == "" then
                    []

                 else
                    [ Attr.class ("language-" ++ code.language), Attr.attribute "data-language" code.language ]
                )
                [ Html.text code.code ]
            ]
        ]



-- TABLES


viewTable : Config -> { aligns : List Align, header : List (List Inline), rows : List (List (List Inline)) } -> Html msg
viewTable config table =
    let
        mayScroll =
            List.length table.aligns >= 3 || List.any (\content -> String.length (Inline.plainText content) > 20) (List.concat (table.header :: table.rows))

        cell isHeader align content =
            (if isHeader then
                Html.th

             else
                Html.td
            )
                (Internal.cls [ "klar-md__cell", alignClass align ]
                    :: (if isHeader then
                            [ Attr.scope "col" ]

                        else
                            []
                       )
                )
                (viewInlines config content)

        row isHeader cells =
            Html.tr [] (List.map2 (cell isHeader) table.aligns cells)
    in
    Html.div
        ([ Internal.cls [ "klar-md__table" ]
         , Attr.attribute "role" "group"
         , Attr.attribute "aria-label" (Locale.pick config.locale { nb = "Tabell", en = "Table" })
         ]
            ++ (if mayScroll then
                    [ Attr.tabindex 0 ]

                else
                    []
               )
        )
        [ Html.table [ autoDirection ]
            [ Html.thead [] [ row True table.header ]
            , Html.tbody [] (List.map (row False) table.rows)
            ]
        ]


alignClass : Align -> String
alignClass align =
    case align of
        AlignNone ->
            ""

        AlignLeft ->
            "klar-md__cell--left"

        AlignCenter ->
            "klar-md__cell--center"

        AlignRight ->
            "klar-md__cell--right"



-- INLINES


viewInlines : Config -> List Inline -> List (Html msg)
viewInlines config inlines =
    List.concatMap (viewInline config) inlines


viewInline : Config -> Inline -> List (Html msg)
viewInline config inline =
    case inline of
        Text text ->
            [ Html.text text ]

        Code text ->
            [ Html.code [ Internal.cls [ "klar-md__inline-code" ] ] [ Html.text text ] ]

        Emphasis children ->
            [ Html.em [] (viewInlines config children) ]

        Strong children ->
            [ Html.strong [] (viewInlines config children) ]

        Strikethrough children ->
            [ Html.del [] (viewInlines config children) ]

        SoftBreak ->
            [ Html.text "\n" ]

        HardBreak ->
            [ Html.br [] [] ]

        Link target children ->
            viewLink config target children

        Image image ->
            [ viewImage config image ]


{-| A link, if its address is allowed; otherwise just the words of the link.
-}
viewLink : Config -> { destination : String, title : String } -> List Inline -> List (Html msg)
viewLink config target children =
    case Url.classify target.destination of
        Nothing ->
            viewInlines config children

        Just kind ->
            [ Html.a
                ([ Attr.href target.destination
                 , Internal.cls
                    [ "klar-md__link"
                    , if kind == Url.External then
                        "klar-md__link--external"

                      else
                        ""
                    ]
                 ]
                    ++ (if target.title == "" then
                            []

                        else
                            [ Attr.title target.title ]
                       )
                    ++ (if kind == Url.External then
                            [ Attr.rel "noopener noreferrer" ]

                        else
                            []
                       )
                )
                (viewInlines config children
                    ++ (if kind == Url.External then
                            [ Html.span [ Internal.cls [ "klar-md__external" ] ] [ Icon.view Icon.arrowUpRight ] ]

                        else
                            []
                       )
                )
            ]


viewImage : Config -> { source : String, title : String, alt : String } -> Html msg
viewImage config image =
    let
        kind =
            Url.classify image.source

        isShown =
            case ( kind, config.images ) of
                ( Just Url.Relative, AnyImage ) ->
                    True

                ( Just Url.External, AnyImage ) ->
                    True

                ( Just Url.Relative, ImagesFrom _ ) ->
                    True

                ( Just Url.External, ImagesFrom hosts ) ->
                    case Url.host image.source of
                        Just host ->
                            List.member host hosts

                        Nothing ->
                            False

                _ ->
                    False
    in
    if isShown then
        Html.img
            ([ Internal.cls [ "klar-md__image" ]
             , Attr.src image.source
             , Attr.alt image.alt
             , Attr.attribute "loading" "lazy"
             , Attr.attribute "decoding" "async"
             , Attr.attribute "referrerpolicy" "no-referrer"
             ]
                ++ (if image.title == "" then
                        []

                    else
                        [ Attr.title image.title ]
                   )
            )
            []

    else
        viewImagePlaceholder config kind image


{-| An image that is not loaded: its description, as a link to the image when the
address is one that may be linked.
-}
viewImagePlaceholder : Config -> Maybe Url.Kind -> { source : String, title : String, alt : String } -> Html msg
viewImagePlaceholder config kind image =
    let
        description =
            if String.trim image.alt == "" then
                Locale.pick config.locale { nb = "Bilde", en = "Image" }

            else
                image.alt

        content =
            [ Icon.view Icon.image
            , Html.span [ Internal.cls [ "klar-sr-only" ] ] [ Html.text (Locale.pick config.locale { nb = "Bilde: ", en = "Image: " }) ]
            , Html.text description
            ]
    in
    case kind of
        Just Url.Relative ->
            Html.a [ Internal.cls [ "klar-md__link", "klar-md__placeholder" ], Attr.href image.source ] content

        Just Url.External ->
            Html.a [ Internal.cls [ "klar-md__link", "klar-md__placeholder" ], Attr.href image.source, Attr.rel "noopener noreferrer" ] content

        _ ->
            Html.span [ Internal.cls [ "klar-md__placeholder" ] ] content
