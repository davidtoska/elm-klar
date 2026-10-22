# Klar.Text

Typography: titles, paragraphs, small print and code.

Import: `import Klar.Text as Text` | Group: Foundations

## Signatures

```elm
-- Headings
title : String -> Html msg
heading : String -> Html msg
subheading : String -> Html msg
overline : String -> Html msg
figure : String -> Html msg

-- Paragraphs
paragraph : String -> Html msg
paragraphWith : List (Html msg) -> Html msg
lead : String -> Html msg
text : String -> Html msg

-- Inline text
secondary : String -> Html msg
muted : String -> Html msg
caption : String -> Html msg
strong : String -> Html msg
link : { href : String, label : String } -> Html msg

-- Code and keys
mono : String -> Html msg
code : String -> Html msg
codeBlock : String -> Html msg
kbd : String -> Html msg
kbdCombo : List String -> Html msg
```

## Documentation

Typography: titles, paragraphs, small print and code. Application code uses
these instead of raw `h1`, `p` and `code` elements, so that text looks the same
everywhere.

Use when: the page needs titles, paragraphs, small print or code that look the same everywhere.
Do not use when: the text is a link (use `Klar.Link`), an action (use `Klar.Button`) or key caps (use `Klar.Kbd`).

    import Klar.Text as Text

    Text.title "Orders"

    Text.paragraph "All orders from the last 30 days."

    Text.paragraphWith
        [ Text.text "Press "
        , Text.kbdCombo [ "Ctrl", "K" ]
        , Text.text " to search, or "
        , Text.link { href = "#/help", label = "read the help" }
        , Text.text "."
        ]

The headings are real heading elements, so the outline of the page is right for
screen readers: `title` is the `h1` (use it once per page), `heading` an `h2` and
`subheading` an `h3`. Use `figure` for a large number that is not a heading.

**Block or inline.** Some functions make a block, which starts on a new line, and the
others make inline text, which runs on in the line it is in. Two inline ones next
to each other (in a `Layout.stack`, say) end up on one line: put them in
`paragraphWith`, or use a block.

| | Functions |
| --- | --- |
| Block | `title`, `heading`, `subheading`, `overline`, `lead`, `paragraph`, `paragraphWith`, `codeBlock` |
| Inline | `text`, `figure`, `secondary`, `muted`, `caption`, `strong`, `link`, `mono`, `code`, `kbd`, `kbdCombo` |

Every function takes its text as a `String` (`kbdCombo` takes a list of strings
and `paragraphWith` a list of HTML) and no attributes. When you need an id or an
event handler, wrap the result in an element of your own.

## Headings

### `title`

```elm
title : String -> Html msg
```

The title of the page, an `h1`. Use it once per page.

### `heading`

```elm
heading : String -> Html msg
```

A heading for a section of the page, an `h2`.

### `subheading`

```elm
subheading : String -> Html msg
```

A heading inside a section, an `h3`.

### `overline`

```elm
overline : String -> Html msg
```

A small label above a group or a title, shown in capital letters. Write the
text in normal case: `Text.overline "Overview"` appears as "OVERVIEW". It is a
`div`, not a heading.

### `figure`

```elm
figure : String -> Html msg
```

A large number or short figure ("1,482") that is not a heading: it looks
like `title`, but it is a plain `span`, so it does not add an `h1` to the page.

## Paragraphs

### `paragraph`

```elm
paragraph : String -> Html msg
```

A paragraph of body text. Lines are limited to about 80 characters so that
long text stays easy to read.

### `paragraphWith`

```elm
paragraphWith : List (Html msg) -> Html msg
```

A paragraph made of inline content such as `text`, `strong`, `link` and
`code`.

    Text.paragraphWith
        [ Text.text "Orders are shipped within "
        , Text.strong "two days"
        , Text.text "."
        ]

### `lead`

```elm
lead : String -> Html msg
```

A larger introductory paragraph, for the first lines under a title.

### `text`

```elm
text : String -> Html msg
```

A plain text node, the same as `Html.text`. Handy in the list of
`paragraphWith` when you do not import `Html`.

## Inline text

### `secondary`

```elm
secondary : String -> Html msg
```

Gray inline text for less important information. It keeps the size of the
text around it.

### `muted`

```elm
muted : String -> Html msg
```

Lighter gray inline text, for hints and metadata. It keeps the size of the
text around it.

### `caption`

```elm
caption : String -> Html msg
```

Small, muted inline text for captions and fine print.

### `strong`

```elm
strong : String -> Html msg
```

Bold inline text (a `strong` element), for words that matter.

### `link`

```elm
link : { href : String, label : String } -> Html msg
```

An ordinary link (an `a` element). Use hash URLs such as `#/orders` to
navigate inside a single page application. In a `Browser.application` the click
is reported as `UrlRequested`, like every other link.

    Text.link { href = "#/orders", label = "All orders" }

## Code and keys

### `mono`

```elm
mono : String -> Html msg
```

Monospace inline text, for ids, hashes and URLs.

    Text.mono "ORD-2041"

### `code`

```elm
code : String -> Html msg
```

Inline code (a `code` element) on a light background, for names and short
commands inside a sentence.

### `codeBlock`

```elm
codeBlock : String -> Html msg
```

A block of preformatted code on a dark background. Line breaks and spaces
are kept, and lines that are too wide scroll sideways. The block can take the
keyboard focus, so that it can be scrolled without a mouse.

### `kbd`

```elm
kbd : String -> Html msg
```

A single key cap (a `kbd` element), such as "Esc".

    Text.kbd "Esc"

### `kbdCombo`

```elm
kbdCombo : List String -> Html msg
```

Several key caps in a row, for a keyboard shortcut.

    Text.kbdCombo [ "Ctrl", "K" ]
