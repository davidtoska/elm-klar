module Klar.Text exposing
    ( title, heading, subheading, headingLevel, overline, figure
    , paragraph, paragraphWith, lead, text
    , secondary, muted, caption, strong, truncated
    , mono, code, codeBlock
    )

{-| Typography: titles, paragraphs, small print and code. Application code uses
these instead of raw `h1`, `p` and `code` elements, so that text looks the same
everywhere.

Use when: the page needs titles, paragraphs, small print or code that look the same everywhere.
Do not use when: the text is a link (use `Klar.Link`, which is inline by default and goes into `paragraphWith`), an action (use `Klar.Button`) or key caps (use `Klar.Kbd`).

    import Klar.Kbd as Kbd
    import Klar.Link as Link
    import Klar.Shortcut as Shortcut
    import Klar.Text as Text

    Text.title "Orders"

    Text.paragraph "All orders from the last 30 days."

    Text.paragraphWith
        [ Text.text "Press "
        , Kbd.view [ Kbd.inline ] (Shortcut.mod (Shortcut.char 'k'))
        , Text.text " to search, or "
        , Link.view [] (Link.internal "/help") "read the help"
        , Text.text "."
        ]

The headings are real heading elements, so the outline of the page is right for
screen readers: `title` is the `h1` (use it once per page, and not at all on a page
with a [Klar.PageHeader](Klar-PageHeader), whose title is the `h1`), `heading` an `h2`
and `subheading` an `h3`; `headingLevel` is a heading of any level, for an outline that
goes deeper. Use `figure` for a large number that is not a heading.

**Block or inline.** Some functions make a block, which starts on a new line, and the
others make inline text, which runs on in the line it is in. Two inline ones next
to each other (in a `Layout.stack`, say) end up on one line: put them in
`paragraphWith`, or use a block.

| | Functions |
| --- | --- |
| Block | `title`, `heading`, `subheading`, `headingLevel`, `overline`, `lead`, `paragraph`, `paragraphWith`, `codeBlock` |
| Inline | `text`, `figure`, `secondary`, `muted`, `caption`, `strong`, `truncated`, `mono`, `code` |

Every function takes its text as a `String` (`paragraphWith` takes a list of HTML) and no attributes. When you need an id or an
event handler, wrap the result in an element of your own.


# Headings

@docs title, heading, subheading, headingLevel, overline, figure


# Paragraphs

@docs paragraph, paragraphWith, lead, text


# Inline text

@docs secondary, muted, caption, strong, truncated


# Code

@docs mono, code, codeBlock

Key caps are [Klar.Kbd](Klar-Kbd): `Kbd.view` for a shortcut, `Kbd.key` for one key.

-}

import Html exposing (Html)
import Html.Attributes as Attr
import Klar.Internal as Internal


{-| A plain text node, the same as `Html.text`. Handy in the list of
`paragraphWith` when you do not import `Html`.
-}
text : String -> Html msg
text =
    Html.text


{-| The title of the page, an `h1`. Use it once per page, on a page without a
[Klar.PageHeader](Klar-PageHeader): with a page header, its title is the `h1` and the
headings of the page start at `heading`.
-}
title : String -> Html msg
title content =
    Html.h1 [ Internal.cls [ "klar-text", "klar-text--title" ] ] [ Html.text content ]


{-| A large number or short figure ("1,482") that is not a heading: it looks
like `title`, but it is a plain `span`, so it does not add an `h1` to the page. Its
digits are tabular, so a figure that changes does not make the line jump.
-}
figure : String -> Html msg
figure content =
    Html.span [ Internal.cls [ "klar-text", "klar-text--figure" ] ] [ Html.text content ]


{-| A heading for a section of the page, an `h2`.
-}
heading : String -> Html msg
heading content =
    Html.h2 [ Internal.cls [ "klar-text", "klar-text--heading" ] ] [ Html.text content ]


{-| A heading inside a section, an `h3`.
-}
subheading : String -> Html msg
subheading content =
    Html.h3 [ Internal.cls [ "klar-text", "klar-text--subheading" ] ] [ Html.text content ]


{-| A heading of the given level, from 1 to 6, for an outline that goes deeper than
`subheading`: the headings inside a card whose title is an `h3` (`Card.headingLevel 3`)
are `headingLevel 4`. A number outside the range counts as the nearest level. Level 1
looks like `title`, 2 like `heading` and 3 to 6 like `subheading`.

    Card.view [ Card.title "Order 1042", Card.headingLevel 3 ]
        [ Text.headingLevel 4 "Lines", linesTable ]

-}
headingLevel : Int -> String -> Html msg
headingLevel level content =
    let
        clamped =
            clamp 1 6 level

        look =
            case clamped of
                1 ->
                    "klar-text--title"

                2 ->
                    "klar-text--heading"

                _ ->
                    "klar-text--subheading"
    in
    Internal.heading clamped [ Internal.cls [ "klar-text", look ] ] [ Html.text content ]


{-| A small label above a group or a title, shown in capital letters. Write the
text in normal case: `Text.overline "Overview"` appears as "OVERVIEW". It is a
`div`, not a heading.
-}
overline : String -> Html msg
overline content =
    Html.div [ Internal.cls [ "klar-text", "klar-text--overline" ] ] [ Html.text content ]


{-| A larger introductory paragraph, for the first lines under a title.
-}
lead : String -> Html msg
lead content =
    Html.p [ Internal.cls [ "klar-text", "klar-text--lead" ] ] [ Html.text content ]


{-| A paragraph of body text. Lines are limited to about 80 characters so that
long text stays easy to read.
-}
paragraph : String -> Html msg
paragraph content =
    Html.p [ Internal.cls [ "klar-text", "klar-text--paragraph" ] ] [ Html.text content ]


{-| A paragraph made of inline content such as `text`, `strong`, `code` and links
([Klar.Link](Klar-Link)).

    Text.paragraphWith
        [ Text.text "Orders are shipped within "
        , Text.strong "two days"
        , Text.text "."
        ]

-}
paragraphWith : List (Html msg) -> Html msg
paragraphWith children =
    Html.p [ Internal.cls [ "klar-text", "klar-text--paragraph" ] ] children


{-| Gray inline text for less important information. It keeps the size of the
text around it.
-}
secondary : String -> Html msg
secondary content =
    Html.span [ Internal.cls [ "klar-text--secondary" ] ] [ Html.text content ]


{-| Lighter gray inline text, for hints and metadata. It keeps the size of the
text around it.
-}
muted : String -> Html msg
muted content =
    Html.span [ Internal.cls [ "klar-text--muted" ] ] [ Html.text content ]


{-| Small, muted inline text for captions and fine print.
-}
caption : String -> Html msg
caption content =
    Html.span [ Internal.cls [ "klar-text", "klar-text--caption" ] ] [ Html.text content ]


{-| Bold inline text (a `strong` element), for words that matter.
-}
strong : String -> Html msg
strong content =
    Html.strong [ Internal.cls [ "klar-text--strong" ] ] [ Html.text content ]


{-| Text on one line that ends in an ellipsis when it is wider than the room it has,
with the whole text as the tooltip of the pointer: a customer name in a narrow panel,
a long id in a list. It is never wider than its parent.

    Layout.stack [ Layout.width 200 ] [ Text.truncated customer.name ]

The text is all there for a screen reader; only the eye sees it cut.

-}
truncated : String -> Html msg
truncated content =
    Html.span [ Internal.cls [ "klar-text--truncated" ], Attr.title content ] [ Html.text content ]


{-| Monospace inline text, for ids, hashes and URLs.

    Text.mono "ORD-2041"

-}
mono : String -> Html msg
mono content =
    Html.span [ Internal.cls [ "klar-mono" ] ] [ Html.text content ]


{-| Inline code (a `code` element) on a light background, for names and short
commands inside a sentence.
-}
code : String -> Html msg
code content =
    Html.code [ Internal.cls [ "klar-code" ] ] [ Html.text content ]


{-| A block of preformatted code on a dark background. Line breaks and spaces
are kept, and lines that are too wide scroll sideways. The block can take the
keyboard focus, so that it can be scrolled without a mouse; a screen reader reads
its text when it gets the focus.
-}
codeBlock : String -> Html msg
codeBlock content =
    Html.pre [ Internal.cls [ "klar-code-block" ], Attr.tabindex 0 ] [ Html.code [] [ Html.text content ] ]
