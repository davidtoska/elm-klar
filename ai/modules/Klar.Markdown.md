# Klar.Markdown

Markdown as safe, calm HTML: for the text of a note, a description, a help page, or the answer of a language model that is still being written.

Import: `import Klar.Markdown as Markdown` | Group: Text and change

Types: `Heading`, `Document`, `Attribute`, `ImageHost`

## Signatures

```elm
-- Views
view : List (Attribute msg) -> String -> Html msg
viewDocument : List (Attribute msg) -> Document -> Html msg

-- Parsing
type Document  -- opaque: no constructors are exposed
parse : String -> Document
plainText : Document -> String

-- Headings
type Heading  -- opaque: no constructors are exposed
headings : List (Attribute msg) -> Document -> List Heading
headingLevel : Heading -> Int
headingText : Heading -> String
headingId : Heading -> String

-- Attributes
type Attribute msg  -- opaque: no constructors are exposed
type ImageHost  -- opaque: no constructors are exposed
locale : Locale.Locale -> Attribute msg
headingOffset : Int -> Attribute msg
idPrefix : String -> Attribute msg
images : Attribute msg
imageHost : String -> Maybe ImageHost
imagesFrom : List ImageHost -> Attribute msg
customLink :
    ({ href : String, external : Bool, title : String, content : List (Html msg) } -> Maybe (Html msg))
    -> Attribute msg
customCodeBlock : ({ language : String, code : String } -> Maybe (Html msg)) -> Attribute msg
```

## Documentation

Markdown as safe, calm HTML: for the text of a note, a description, a help
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
is kept as a label) and indented code, thematic breaks, tables with alignment
(`:---` is left and `---:` right, as in GFM, also in a text that reads right to left;
a column without one starts where the text starts), emphasis, strong text, `~~strikethrough~~`, code spans, links with titles,
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

For a text that the user writes, [Klar.MarkdownEditor](Klar.MarkdownEditor.md) puts a
text area and this view side by side.

## Views

### `view`

```elm
view : List (Attribute msg) -> String -> Html msg
```

A text as HTML. This is the one to use when the text is short or changes
often; for a text that you show again and again, parse it once with `parse` and
use `viewDocument`.

    Markdown.view [] "Orders **shipped today**: see [the list](/orders)."

### `viewDocument`

```elm
viewDocument : List (Attribute msg) -> Document -> Html msg
```

A parsed document as HTML, in a `div` that takes the width it is given.

## Parsing

### `Document`

```elm
type Document  -- opaque: no constructors are exposed
```

A text that has been read: its blocks, headings and links, ready to be shown
or asked questions. Make one with `parse`. Keep it in the model and show it with
`viewDocument`, and the text is not read again each time the view runs. It is a large
value: compare two documents by the texts they were made from, not with `==`.

### `parse`

```elm
parse : String -> Document
```

Reads a text. It never fails: any text gives a document, text that is
unfinished is read as far as it goes, and a text longer than 100,000 characters is
cut and says so when it is shown.

    Markdown.parse "# Orders\n\nShipped **today**."

### `plainText`

```elm
plainText : Document -> String
```

The text of a document without any markup: one line for each paragraph, heading,
list item, row of a table (cells separated by `|`) and line of code, with the
words of links and the descriptions of images. It fits a search index, a preview
that is cut after some characters, or a notification.

    Markdown.plainText (Markdown.parse "Ship **two** orders.") -- "Ship two orders."

## Headings

### `Heading`

```elm
type Heading  -- opaque: no constructors are exposed
```

A heading of a document: its level, its text and the id of its element. Make
the list with `headings`.

### `headings`

```elm
headings : List (Attribute msg) -> Document -> List Heading
```

The headings of a document in the order they appear, also those inside quotes
and lists. Give it the attributes you give the view: the `id` of a heading
contains the `idPrefix` (`md-` unless you set another), so the ids of the list are
the ids in the page. Use it to build a table of contents.

    Markdown.headings [] (Markdown.parse "# Orders\n\n## Open\n\n## Open")
        |> List.map Markdown.headingId
    -- [ "md-orders", "md-open", "md-open-1" ]

### `headingLevel`

```elm
headingLevel : Heading -> Int
```

The level of a heading, from 1 to 6. The first heading of a document has the
level it was written with; each later one is at most one deeper than the one before
it, so a `###` that follows a `#` has level 2. It does not include the
`headingOffset` of a view.

### `headingText`

```elm
headingText : Heading -> String
```

The words of a heading, without markup.

### `headingId`

```elm
headingId : Heading -> String
```

The id of the heading's element, made from its text and unique in the document:
`md-introduction`, `md-introduction-1`, with the `idPrefix` that `headings` was given.

## Attributes

### `Attribute`

```elm
type Attribute msg  -- opaque: no constructors are exposed
```

A setting of the view. Make them with the functions below and pass a list to
`view` or `viewDocument`; later attributes win over earlier ones. The view itself
sends no messages; `msg` is the message type of the Html that `customLink` and
`customCodeBlock` draw.

### `ImageHost`

```elm
type ImageHost  -- opaque: no constructors are exposed
```

A host that images may come from: a name such as `cdn.example.com`. Make one with
`imageHost`.

### `locale`

```elm
locale : Locale.Locale -> Attribute msg
```

The language of the few labels that are not part of the text: "Code", "Table",
"Image". Default `Locale.default`, which is English.

### `headingOffset`

```elm
headingOffset : Int -> Attribute msg
```

Moves every heading down by this many levels (0 to 5), for a document that is
shown under headings of its own: with `headingOffset 2` a `#` is an `h3`. Levels
stop at `h6`. Default 0.

### `idPrefix`

```elm
idPrefix : String -> Attribute msg
```

Text put in front of the id of every heading. Default `"md-"`, so that text which
someone else wrote cannot make an element with an id that the page uses. Choose
another for a page that shows several documents with the same headings (a list of
answers that all have a "Summary"), or give it the id of the answer. Give
`headings` the same attributes, so that its ids are the ids in the page.

    Markdown.view [ Markdown.idPrefix "answer-3-" ] answer.text

### `images`

```elm
images : Attribute msg
```

Shows images as images, for relative paths and for `http:` and `https:`
addresses. By default an image is shown as a link with its description, because
loading it from another site tells that site that the text was read, and the
address of an image can carry what a text from a model knows. Turn it on only for
text you trust: a relative path is a request to your own server with the reader's
cookies, which text written by someone else can use to make a reader's browser
call an address of yours. To trust only the hosts of your own image server, use
`imagesFrom`.

The browser is told to send no referrer and to load the image lazily.

### `imageHost`

```elm
imageHost : String -> Maybe ImageHost
```

A host name for `imagesFrom`, or `Nothing` when the text is not a host name, so
a mistake does not silently turn every image into a link. A host name has letters,
digits and hyphens in labels separated by dots (`images.example.com`); capitals are
allowed and do not matter. A scheme (`https://cdn.example.com`), a port, a path, a
trailing dot, a wildcard, a user name and white space are refused.

    Markdown.imageHost "cdn.example.com" -- Just ...

    Markdown.imageHost "https://cdn.example.com" -- Nothing

### `imagesFrom`

```elm
imagesFrom : List ImageHost -> Attribute msg
```

Shows images from relative paths and from these hosts, and every other image as
a link with its description. The match is exact: a subdomain needs its own entry
and the case does not matter. An address that has a port, a user name, a
percent sign or brackets in its host never matches, nor does an `http:` address
without `//` straight after the colon.

    Markdown.view [ Markdown.imagesFrom (List.filterMap Markdown.imageHost [ "cdn.example.com" ]) ] note.body

A relative path is a request to your own server with the reader's cookies, as for
`images`: for text from others, leave relative paths to a host of your own instead.

### `customLink`

```elm
customLink :
    ({ href : String, external : Bool, title : String, content : List (Html msg) } -> Maybe (Html msg))
    -> Attribute msg
```

Draws some links of the text yourself. The function gets every link that is drawn:
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

### `customCodeBlock`

```elm
customCodeBlock : ({ language : String, code : String } -> Maybe (Html msg)) -> Attribute msg
```

Draws some blocks of code yourself. The function gets the language written after
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
