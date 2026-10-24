module Klar.Markdown exposing
    ( view, viewDocument
    , Document, parse, plainText
    , Heading, headings, headingLevel, headingText, headingId
    , Attribute, locale, headingOffset, idPrefix, images, ImageHost, imageHost, imagesFrom, customLink, customCodeBlock
    )

{-| Markdown as safe, calm HTML: for the text of a note, a description, a help
page, or the answer of a language model that is still being written.

Use when: text written in Markdown, also by someone else or by a model, must be shown as safe HTML.
Do not use when: the user is to write the text, use `Klar.MarkdownEditor`.

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
    default an image is a link with its description. Loading an image from a
    relative path is a request to your own server with the reader's cookies, so
    text written by someone else can make a reader's browser call an address of
    yours (`![](/orders/17/cancel)`): when you turn images on, name the hosts you
    trust with `imagesFrom`, or do not turn them on for such text.
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
line breaks. Character references become the characters they stand for: numbers
(`&#8217;`, `&#x1F600;`) and the common names (`&amp;`, `&nbsp;`, `&mdash;`, `&aelig;`
...), which is what text copied from a web page or a mail holds; a character is never
markup, so `&lt;b&gt;` shows `<b>`, and a name that is not known stays as it was
written. Not understood, on purpose: HTML (it is text), setext headings (`Title` over `=====`) and reference links, because both change
what came before them and would make a half-written text jump around. A single
`~` is text, so "about ~5 minutes" is not struck through.

**Unfinished text.** The parser never fails, and text that stops in the middle of
something is shown as far as it goes: an open code fence runs to the end, an open
`**bold` is bold, an open `` `code `` is code, a table row with too few cells is
padded, and a link whose address has not arrived shows its words. What comes before
the last blank line of a text does not change when more text arrives, with one
exception that CommonMark makes: a list that goes on after a blank line becomes
loose, and then the paragraphs of all its items, also the earlier ones, are wrapped
in `p` elements (the items themselves stay as they were). The stylesheet makes a
loose list look nearly like a tight one, so a stream does not visibly jump. A list or
a block of code can also grow at its end. Only the paragraph that is still being
written can change its shape, and in it anything that is only open is shown as
closed; when a blank line follows it, it is finished, and an unclosed `**` is text.

**Headings** get an `id` made from their text, unique in the document (`intro`,
`intro-1`) and preceded by `md-` (`md-intro`), for a table of contents (see
`headings`). The prefix keeps text that someone else wrote from making an element
with an id of the page, such as `main` or `app`, or one that a form field points at;
`idPrefix` chooses another. A link in the text to one of its own headings, as a table of
contents in the text writes it (`[Pricing](#pricing)`), goes to that heading: the
prefix is put in front of it. A link to `"#" ++ id` changes the fragment of the address,
which a single page application that routes by the fragment takes for a route:
scroll to the heading with `Browser.Dom` instead. `headingOffset` moves the
headings down for a document inside a page that has headings of its own: levels
never go past `h6`, and a heading is never more than one level deeper than the
one before it, so the outline has no gaps.

**Layout.** The text takes the width it is given. A table or a code block that is
wider scrolls inside its own box, never the page; one that may scroll is a stop
for the Tab key, so it can be scrolled with the keyboard. Each paragraph picks its
own direction (`dir="auto"`), so a text in Arabic or Hebrew reads right to left.
The only built-in text is a few labels for screen readers; `locale` sets their
language.

**Your own links and code.** `customLink` and `customCodeBlock` let the application
draw some links (citations, links through its router) and some blocks of code (syntax
highlighting, a diagram, a copy button) itself, after the checks of this module; for
the others the function gives `Nothing` and they are drawn as usual.

The module keeps no state and sends no messages of its own. To parse once and show the result
more than once (or to read the headings), use `parse` and `viewDocument`:

    let
        document =
            Markdown.parse model.answer
    in
    Html.div []
        [ tableOfContents (Markdown.headings [] document)
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

@docs Attribute, locale, headingOffset, idPrefix, images, ImageHost, imageHost, imagesFrom, customLink, customCodeBlock

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
import Klar.Markdown.Utf16 as Utf16
import Set exposing (Set)



-- DOCUMENT


{-| A text that has been read: its blocks, headings and links, ready to be shown
or asked questions. Make one with `parse`. Keep it in the model and show it with
`viewDocument`, and the text is not read again each time the view runs. It is a large
value: compare two documents by the texts they were made from, not with `==`.
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
and lists. Give it the attributes you give the view: the `id` of a heading
contains the `idPrefix` (`md-` unless you set another), so the ids of the list are
the ids in the page. Use it to build a table of contents.

    Markdown.headings [] (Markdown.parse "# Orders\n\n## Open\n\n## Open")
        |> List.map Markdown.headingId
    -- [ "md-orders", "md-open", "md-open-1" ]

-}
headings : List (Attribute msg) -> Document -> List Heading
headings attributes (Document document) =
    collectHeadings (configure attributes).prefix document.blocks []
        |> List.reverse


collectHeadings : String -> List Block -> List Heading -> List Heading
collectHeadings prefix blocks found =
    List.foldl
        (\block acc ->
            case block of
                HeadingBlock heading ->
                    Heading { level = heading.level, text = Inline.plainText heading.content, id = prefix ++ heading.id } :: acc

                Quote inner ->
                    collectHeadings prefix inner acc

                ListBlock list ->
                    List.foldl (\item inner -> collectHeadings prefix item.blocks inner) acc list.items

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
`md-introduction`, `md-introduction-1`, with the `idPrefix` that `headings` was given.
-}
headingId : Heading -> String
headingId (Heading heading) =
    heading.id



-- ATTRIBUTES


{-| A setting of the view. Make them with the functions below and pass a list to
`view` or `viewDocument`; later attributes win over earlier ones. The view itself
sends no messages; `msg` is the message type of the Html that `customLink` and
`customCodeBlock` draw.
-}
type Attribute msg
    = Attribute (Config msg -> Config msg)


type ImagePolicy
    = NoImages
    | AnyImage
    | ImagesFrom (List String)


type alias Config msg =
    { locale : Locale
    , offset : Int
    , images : ImagePolicy
    , prefix : String
    , inLink : Bool
    , anchors : Set String
    , customLink : Maybe ({ href : String, external : Bool, title : String, content : List (Html msg) } -> Maybe (Html msg))
    , customCodeBlock : Maybe ({ language : String, code : String } -> Maybe (Html msg))
    }


configure : List (Attribute msg) -> Config msg
configure attributes =
    List.foldl (\(Attribute change) config -> change config)
        { locale = Locale.default
        , offset = 0
        , images = NoImages
        , prefix = "md-"
        , inLink = False
        , anchors = Set.empty
        , customLink = Nothing
        , customCodeBlock = Nothing
        }
        attributes


{-| The language of the few labels that are not part of the text: "Code", "Table",
"Image". Default `Locale.default`, which is English.
-}
locale : Locale -> Attribute msg
locale value =
    Attribute (\config -> { config | locale = value })


{-| Moves every heading down by this many levels (0 to 5), for a document that is
shown under headings of its own: with `headingOffset 2` a `#` is an `h3`. Levels
stop at `h6`. Default 0.
-}
headingOffset : Int -> Attribute msg
headingOffset levels =
    Attribute (\config -> { config | offset = clamp 0 5 levels })


{-| Text put in front of the id of every heading. Default `"md-"`, so that text which
someone else wrote cannot make an element with an id that the page uses. Choose
another for a page that shows several documents with the same headings (a list of
answers that all have a "Summary"), or give it the id of the answer. Give
`headings` the same attributes, so that its ids are the ids in the page.

    Markdown.view [ Markdown.idPrefix "answer-3-" ] answer.text

-}
idPrefix : String -> Attribute msg
idPrefix prefix =
    Attribute (\config -> { config | prefix = prefix })


{-| Shows images as images, for relative paths and for `http:` and `https:`
addresses. By default an image is shown as a link with its description, because
loading it from another site tells that site that the text was read, and the
address of an image can carry what a text from a model knows. Turn it on only for
text you trust: a relative path is a request to your own server with the reader's
cookies, which text written by someone else can use to make a reader's browser
call an address of yours. To trust only the hosts of your own image server, use
`imagesFrom`.

The browser is told to send no referrer and to load the image lazily.

-}
images : Attribute msg
images =
    Attribute (\config -> { config | images = AnyImage })


{-| A host that images may come from: a name such as `cdn.example.com`. Make one with
`imageHost`.
-}
type ImageHost
    = ImageHost String


{-| A host name for `imagesFrom`, or `Nothing` when the text is not a host name, so
a mistake does not silently turn every image into a link. A host name has letters,
digits and hyphens in labels separated by dots (`images.example.com`); capitals are
allowed and do not matter. A scheme (`https://cdn.example.com`), a port, a path, a
trailing dot, a wildcard, a user name and white space are refused.

    Markdown.imageHost "cdn.example.com" -- Just ...

    Markdown.imageHost "https://cdn.example.com" -- Nothing

-}
imageHost : String -> Maybe ImageHost
imageHost text =
    Url.hostName text |> Maybe.map ImageHost


{-| Shows images from relative paths and from these hosts, and every other image as
a link with its description. The match is exact: a subdomain needs its own entry
and the case does not matter. An address that has a port, a user name, a
percent sign or brackets in its host never matches, nor does an `http:` address
without `//` straight after the colon.

    Markdown.view [ Markdown.imagesFrom (List.filterMap Markdown.imageHost [ "cdn.example.com" ]) ] note.body

A relative path is a request to your own server with the reader's cookies, as for
`images`: for text from others, leave relative paths to a host of your own instead.

-}
imagesFrom : List ImageHost -> Attribute msg
imagesFrom hosts =
    Attribute (\config -> { config | images = ImagesFrom (List.map (\(ImageHost name) -> name) hosts) })


{-| Draws some links of the text yourself. The function gets every link that is drawn:
its address (`href`, after the checks of this module, so `javascript:` and the like
never reach it, and a link to a heading of the text already has the prefix), whether
it goes to another site, its title and its words as Html, and gives the Html to show,
or `Nothing` for the link as it is drawn without the function. Use it for citations
(`[1](#cite-1)` as a chip that opens a source), a link that goes through the router of
a `Browser.element`, or a question before another site opens.

    Markdown.view
        [ Markdown.customLink
            (\link ->
                if String.startsWith "#cite-" link.href then
                    Just (viewCitation (String.dropLeft 6 link.href) link.content)

                else
                    Nothing
            )
        ]
        answer.text

The words of a link are never a link themselves. Give the function as a top-level
function, so the view stays cheap to compare.

-}
customLink : ({ href : String, external : Bool, title : String, content : List (Html msg) } -> Maybe (Html msg)) -> Attribute msg
customLink draw =
    Attribute (\config -> { config | customLink = Just draw })


{-| Draws some blocks of code yourself. The function gets the language written after
the fence (`""` when there is none) and the code as it was written, and gives the Html
to show, or `Nothing` for the block as it is drawn without the function: with a label
for the language, in a box that scrolls. Use it for syntax highlighting, a diagram
drawn from the code, or a "Copy" button wired by your application.

    Markdown.customCodeBlock
        (\block ->
            if block.language == "sql" then
                Just (viewQuery block.code)

            else
                Nothing
        )

The code is text: show it with `Html.text`, never as markup.

-}
customCodeBlock : ({ language : String, code : String } -> Maybe (Html msg)) -> Attribute msg
customCodeBlock draw =
    Attribute (\config -> { config | customCodeBlock = Just draw })



-- VIEW


{-| A text as HTML. This is the one to use when the text is short or changes
often; for a text that you show again and again, parse it once with `parse` and
use `viewDocument`.

    Markdown.view [] "Orders **shipped today**: see [the list](/orders)."

-}
view : List (Attribute msg) -> String -> Html msg
view attributes text =
    viewDocument attributes (parse text)


{-| A parsed document as HTML, in a `div` that takes the width it is given.
-}
viewDocument : List (Attribute msg) -> Document -> Html msg
viewDocument attributes (Document document) =
    let
        settings =
            configure attributes

        -- the ids of the headings without the prefix, for links inside the text
        config =
            { settings
                | anchors =
                    collectHeadings "" document.blocks []
                        |> List.map headingId
                        |> Set.fromList
            }
    in
    Html.div [ Internal.cls [ "klar-md" ] ]
        (viewBlocks config False document.blocks
            ++ [ viewNotice config document.truncated ]
        )


viewNotice : Config msg -> Maybe { shown : Int, total : Int } -> Html msg
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


viewBlocks : Config msg -> Bool -> List Block -> List (Html msg)
viewBlocks config tight blocks =
    List.concatMap (viewBlock config tight) blocks


{-| One block. `tight` is for the paragraphs that are direct children of an item
of a tight list: they are not wrapped in a `p`.
-}
viewBlock : Config msg -> Bool -> Block -> List (Html msg)
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
            [ case Maybe.andThen (\draw -> draw code) config.customCodeBlock of
                Just drawn ->
                    drawn

                Nothing ->
                    viewCode config code
            ]

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


viewList : Config msg -> { start : Maybe Int, tight : Bool, items : List Parse.Item } -> Html msg
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


viewItem : Config msg -> Bool -> Parse.Item -> Html msg
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
        |> Utf16.left 80



-- CODE


viewCode : Config msg -> { language : String, code : String } -> Html msg
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


viewTable : Config msg -> { aligns : List Align, header : List (List Inline), rows : List (List (List Inline)) } -> Html msg
viewTable config table =
    let
        -- two short columns already overflow a narrow column: a tab stop too many is
        -- cheaper than a table that the keyboard cannot scroll
        mayScroll =
            List.length table.aligns >= 2 || List.any (\content -> String.length (Inline.plainText content) > 20) (List.concat (table.header :: table.rows))

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


viewInlines : Config msg -> List Inline -> List (Html msg)
viewInlines config inlines =
    List.concatMap (viewInline config) inlines


viewInline : Config msg -> Inline -> List (Html msg)
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


{-| A link, if its address is allowed; otherwise just the words of the link. A link
without words (`[](https://example.com)`) shows its address, so that it has a name;
a link that holds only an image without a description is named by its address.
Inside a link nothing is a link: an image that is not loaded is only its description.
-}
viewLink : Config msg -> { destination : String, title : String } -> List Inline -> List (Html msg)
viewLink config target children =
    case Url.classify target.destination of
        Nothing ->
            viewInlines config children

        Just kind ->
            let
                hasWords =
                    String.trim (Inline.plainText children) /= ""

                holdsImage =
                    List.any
                        (\child ->
                            case child of
                                Image _ ->
                                    True

                                _ ->
                                    False
                        )
                        children

                inside =
                    { config | inLink = True }

                href =
                    linkAddress config kind target.destination

                content =
                    if hasWords || holdsImage then
                        viewInlines inside children

                    else
                        [ Html.text target.destination ]

                drawn =
                    config.customLink
                        |> Maybe.andThen
                            (\draw ->
                                draw
                                    { href = href
                                    , external = kind == Url.External
                                    , title = target.title
                                    , content = content
                                    }
                            )
            in
            case drawn of
                Just custom ->
                    [ custom ]

                Nothing ->
                    viewDefaultLink kind href target.title (not hasWords && holdsImage) target.destination content


{-| A link as the module draws it: marked and with `rel` when it goes to another site,
named by its address when it holds only an image without a description.
-}
viewDefaultLink : Url.Kind -> String -> String -> Bool -> String -> List (Html msg) -> List (Html msg)
viewDefaultLink kind href title namedByAddress destination content =
    let
        external =
            kind == Url.External
    in
    [ Html.a
        [ Attr.href href
        , Internal.cls
            [ "klar-md__link"
            , if external then
                "klar-md__link--external"

              else
                ""
            ]
        , Internal.attrIf (title /= "") (Attr.title title)
        , Internal.attrIf external (Attr.rel "noopener noreferrer")
        , Internal.attrIf namedByAddress (Attr.attribute "aria-label" destination)
        ]
        (content
            ++ (if external then
                    [ Html.span [ Internal.cls [ "klar-md__external" ] ] [ Icon.view Icon.arrowUpRight ] ]

                else
                    []
               )
        )
    ]


{-| The address a link goes to. A link to a heading of the same text (`[Intro](#intro)`,
as a table of contents in the text writes it) goes to the id the heading has on the
page, with the prefix: `#md-intro`. The fragment is matched as it is and, failing
that, as the id that a heading with these words would get (`#Getting-Started` finds
`getting-started`). Other addresses are left as they are.
-}
linkAddress : Config msg -> Url.Kind -> String -> String
linkAddress config kind destination =
    if kind == Url.Fragment then
        let
            fragment =
                String.dropLeft 1 destination

            slugged =
                Parse.slug fragment
        in
        if fragment /= "" && Set.member fragment config.anchors then
            "#" ++ config.prefix ++ fragment

        else if fragment /= "" && Set.member slugged config.anchors then
            "#" ++ config.prefix ++ slugged

        else
            destination

    else
        destination


viewImage : Config msg -> { source : String, title : String, alt : String } -> Html msg
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
address is one that may be linked and the image is not inside a link already (an
`a` in an `a` is not valid, and the keyboard would stop twice).
-}
viewImagePlaceholder : Config msg -> Maybe Url.Kind -> { source : String, title : String, alt : String } -> Html msg
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
    case ( config.inLink, kind ) of
        ( False, Just Url.Relative ) ->
            Html.a [ Internal.cls [ "klar-md__link", "klar-md__placeholder" ], Attr.href image.source ] content

        ( False, Just Url.External ) ->
            Html.a [ Internal.cls [ "klar-md__link", "klar-md__placeholder" ], Attr.href image.source, Attr.rel "noopener noreferrer" ] content

        _ ->
            -- inside a link, or an address that is not linked: only the description
            Html.span [ Internal.cls [ "klar-md__placeholder" ] ] content
