module Klar.Skeleton exposing
    ( line, lines
    , block, circle
    )

{-| Shimmering placeholders that stand in for content while it loads.

Use when: you can sketch what the content will look like (a title, a few lines, a picture) while it loads.
Do not use when: you cannot predict the shape of the content (use `Klar.Spinner`), or the region shows a `Remote` (use `Klar.RemoteView`, which draws a skeleton, says "Loading" to screen readers and keeps old data on the screen).

    import Klar.Layout as Layout
    import Klar.Skeleton as Skeleton
    import Klar.Spinner as Spinner

    Layout.stack [ Layout.gap 2 ]
        [ Spinner.view [ Spinner.label "Loading the order", Spinner.loading model.loading ]
        , Skeleton.line 40
        , Skeleton.lines 3
        , Skeleton.block 120
        ]

Use a skeleton when you can sketch what the content will look like: a title and
a few lines of text, a picture, an avatar. When you cannot, show a
[Klar.Spinner](Klar-Spinner) instead. [Klar.Table](Klar-Table),
[Klar.RemoteView](Klar-RemoteView) and the other components that load remote
data draw their own skeletons.

Widths are percentages of the parent (`line 60` is 60% wide) and heights and
diameters are pixels, so a skeleton fills the space it is put in. Skeletons are
hidden from screen readers (`aria-hidden`), so the area that shows them should
say that content is on its way: a labelled spinner that stays in the page (as
above), or `aria-busy="true"` on the area. The shimmer stands still for users
who prefer reduced motion, and in Windows high contrast every placeholder keeps
an outline.


# Text

@docs line, lines


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


{-| A paragraph of this many lines of text, one below the other. Their widths
vary a little, in the same pattern every time (100%, 94%, 97%, 91% ...), so the
block reads as text, and the last one is shorter (60% wide) when there is more
than one. There is always at least one line.

    Skeleton.lines 3

-}
lines : Int -> Html msg
lines count =
    let
        n =
            max 1 count
    in
    Html.div [ Internal.cls [ "klar-skeleton-lines" ], Attr.attribute "aria-hidden" "true" ]
        (List.range 1 n
            |> List.map
                (\i ->
                    if i == n && n > 1 then
                        line 60

                    else
                        line (widthOf i)
                )
        )


{-| The width of line `i` of a paragraph: a fixed pattern, so the same paragraph
looks the same in every render.
-}
widthOf : Int -> Int
widthOf i =
    case modBy 4 (i - 1) of
        0 ->
            100

        1 ->
            94

        2 ->
            97

        _ ->
            91


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
