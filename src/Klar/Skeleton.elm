module Klar.Skeleton exposing
    ( line, lines, paragraph
    , block, circle
    )

{-| Shimmering placeholders that stand in for content while it loads.

Use when: you can sketch what the content will look like (a title, a few lines, a picture) while it loads.
Do not use when: you cannot predict the shape of the content (use `Klar.Spinner`).

    import Klar.Layout as Layout
    import Klar.Skeleton as Skeleton

    Layout.stack [ Layout.gap 2 ]
        [ Skeleton.line 40
        , Skeleton.paragraph 3
        , Skeleton.block 120
        ]

Use a skeleton when you can sketch what the content will look like: a title and
a few lines of text, a picture, an avatar. When you cannot, show a
[Klar.Spinner](Klar-Spinner) instead. [Klar.Table](Klar-Table) and the other
components that load remote data draw their own skeletons.

Widths are percentages of the parent (`line 60` is 60% wide) and heights and
diameters are pixels, so a skeleton fills the space it is put in. Skeletons are
hidden from screen readers (`aria-hidden`), so the area that shows them should
say that content is on its way, for example with `aria-busy="true"` or a
spinner that has a label. The shimmer stands still for users who prefer reduced
motion.


# Text

@docs line, lines, paragraph


# Shapes

@docs block, circle

-}

import Html exposing (Html)
import Html.Attributes as Attr
import Klar.Internal as Internal


{-| One line of text, `percent` wide: a percentage of the parent, kept between
5 and 100. The line is 10px high.

    Skeleton.line 60

-}
line : Int -> Html msg
line percent =
    Html.span
        [ Internal.cls [ "klar-skeleton", "klar-skeleton--line" ]
        , Internal.styleVars [ ( "width", String.fromInt (clamp 5 100 percent) ++ "%" ) ]
        , Attr.attribute "aria-hidden" "true"
        ]
        []


{-| This many lines of text, one below the other, with the last one shorter
(60% wide) when there is more than one. There is always at least one line.
-}
lines : Int -> Html msg
lines count =
    Html.div [ Internal.cls [ "klar-skeleton-lines" ], Attr.attribute "aria-hidden" "true" ]
        (List.range 1 (max 1 count)
            |> List.map
                (\i ->
                    if i == count && count > 1 then
                        line 60

                    else
                        line 100
                )
        )


{-| The same as `lines`: a paragraph of this many placeholder lines.
-}
paragraph : Int -> Html msg
paragraph =
    lines


{-| A rectangle as wide as its parent and `height` pixels high, for a picture,
a chart or a card.

    Skeleton.block 160

-}
block : Int -> Html msg
block height =
    Html.div
        [ Internal.cls [ "klar-skeleton", "klar-skeleton--block" ]
        , Internal.styleVars [ ( "height", Internal.px height ) ]
        , Attr.attribute "aria-hidden" "true"
        ]
        []


{-| A round placeholder, `diameter` pixels wide and high, for an avatar.

    Skeleton.circle 30

-}
circle : Int -> Html msg
circle diameter =
    Html.span
        [ Internal.cls [ "klar-skeleton", "klar-skeleton--circle" ]
        , Internal.styleVars [ ( "width", Internal.px diameter ), ( "height", Internal.px diameter ) ]
        , Attr.attribute "aria-hidden" "true"
        ]
        []
