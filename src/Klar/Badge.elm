module Klar.Badge exposing
    ( view, status, count
    , Attribute, tone, solid, outline, dot, icon, size, max
    )

{-| Small read-only labels for state and metadata, such as "Paid" or
"Overdue", and round number badges.

Use when: the user must read a state or a count, such as "Paid", "Overdue" or a number.
Do not use when: the label is something the user picked and can remove (as `Klar.Tag`).

    import Klar.Badge as Badge
    import Klar.Theme exposing (Tone(..))

    Badge.view [ Badge.tone Success ] "Paid"

    Badge.view [ Badge.tone Warning, Badge.dot ] "Pending"

    Badge.status Danger "Overdue"

    Badge.count [ Badge.tone Danger ] 128

A badge shows a state that the user reads but does not change. For something
the user picked and can take away, use [Klar.Tag](Klar-Tag). There are three
forms: `view` is a small box with a tinted background (or a `solid` or `outline`
one), `status` is a colored dot with text and no box, which fits well in table
cells, and `count` is a round number.

The color is not announced by screen readers, so put the meaning in the text
("Overdue", not just a red badge). A label that does not fit its container is
cut with an ellipsis; a label longer than 12 characters carries the whole text
as a tooltip. Every tone keeps WCAG AA contrast in every theme, the `solid` ones
included, and the dots stay visible in Windows high contrast. Badges never send
messages, so `Attribute` has no `msg` parameter.


# Views

@docs view, status, count


# Attributes

@docs Attribute, tone, solid, outline, dot, icon, size, max

-}

import Html exposing (Html)
import Html.Attributes as Attr
import Klar.Icon as Icon exposing (Icon)
import Klar.Internal as Internal
import Klar.Theme as Theme exposing (Size(..), Tone(..))


{-| A setting of a badge. Make them with the functions below and pass a list to
`view` or `count`; later attributes win over earlier ones.
-}
type Attribute
    = Attribute (Config -> Config)


type alias Config =
    { tone : Tone
    , style : Style
    , dot : Bool
    , size : Size
    , icon : Maybe Icon
    , max : Int
    }


type Style
    = Subtle
    | Solid
    | Outline


configure : Config -> List Attribute -> Config
configure start attributes =
    List.foldl (\(Attribute change) config -> change config) start attributes


defaults : Config
defaults =
    { tone = Neutral, style = Subtle, dot = False, size = Medium, icon = Nothing, max = 99 }


{-| The color of the badge: `Neutral` (gray, the default of `view`), `Primary`
(the default of `count`) or `Info` (the accent color), `Success`, `Warning` or
`Danger`.
-}
tone : Tone -> Attribute
tone value =
    Attribute (\config -> { config | tone = value })


{-| A background filled with the color of the tone instead of the default light
tint, for a badge that has to stand out. A `count` is solid by default.
-}
solid : Attribute
solid =
    Attribute (\config -> { config | style = Solid })


{-| A border in the color of the tone and no fill, instead of the default light
tint (or, on a `count`, the solid fill).
-}
outline : Attribute
outline =
    Attribute (\config -> { config | style = Outline })


{-| A small dot before the text, in the color of the text. It has no effect on a
`count`.
-}
dot : Attribute
dot =
    Attribute (\config -> { config | dot = True })


{-| The size of the badge: `Small` (16px high), `Medium` (20px, the default) or
`Large` (24px). A `count` is 16px, 18px or 22px.
-}
size : Size -> Attribute
size value =
    Attribute (\config -> { config | size = value })


{-| A small icon before the text (after the `dot`, if there is one). It has no
effect on a `count`.
-}
icon : Icon -> Attribute
icon value =
    Attribute (\config -> { config | icon = Just value })


{-| The largest number a `count` writes out. A larger number shows as this number
with a plus ("99+"), while the tooltip and screen readers get the exact number.
The default is 99, and the smallest value is 1. It has no effect on `view`.

    Badge.count [ Badge.max 999 ] 1280 -- shows "999+"

-}
max : Int -> Attribute
max value =
    Attribute (\config -> { config | max = Basics.max 1 value })


{-| A badge with the given text. Name the state in the text: the color is only a
hint.

    Badge.view [ Badge.tone Success, Badge.solid ] "Shipped"

-}
view : List Attribute -> String -> Html msg
view attributes label =
    let
        config =
            configure defaults attributes
    in
    Html.span
        [ Internal.cls
            [ "klar-badge"
            , "klar-badge--" ++ Internal.toneSuffix config.tone
            , "klar-badge--" ++ styleSuffix config.style
            , "klar-badge--" ++ Internal.sizeSuffix config.size
            ]
        ]
        [ Internal.viewIf config.dot (Html.span [ Internal.cls [ "klar-badge__dot" ] ] [])
        , Internal.viewMaybe Icon.view config.icon
        , viewLabel "klar-badge__label" label
        ]


{-| A plain status: a colored dot and text, without a box. Good inside tables
and lists, where a column of boxes would be noisy. The dot has at least 3 : 1
contrast against the page, so a column of statuses can be scanned by color.

    Badge.status Success "In stock"

-}
status : Tone -> String -> Html msg
status value label =
    Html.span [ Internal.cls [ "klar-status", "klar-status--" ++ Internal.toneSuffix value ] ]
        [ Html.span [ Internal.cls [ "klar-status__dot" ] ] []
        , viewLabel "klar-status__label" label
        ]


{-| A round number badge, such as a count of unread messages or of the errors in
a form. It is `Primary` and `solid` by default; `tone`, `outline`, `size` and
`max` change it. A number above `max` (99 by default) shows as "99+", while the
tooltip and screen readers get the exact number. A count of zero or less shows
nothing, so a badge for "nothing new" goes away by itself.

    Badge.count [] 7

    Badge.count [ Badge.tone Danger, Badge.size Small ] model.errorCount

-}
count : List Attribute -> Int -> Html msg
count attributes n =
    let
        config =
            configure { defaults | tone = Primary, style = Solid } attributes

        exact =
            String.fromInt n
    in
    if n <= 0 then
        Html.text ""

    else
        Html.span
            [ Internal.cls
                [ "klar-badge"
                , "klar-badge--count"
                , "klar-badge--" ++ Internal.toneSuffix config.tone
                , "klar-badge--" ++ styleSuffix config.style
                , "klar-badge--" ++ Internal.sizeSuffix config.size
                ]
            , Internal.attrIf (n > config.max) (Attr.title exact)
            ]
            (if n > config.max then
                [ Html.span [ Attr.attribute "aria-hidden" "true" ] [ Html.text (String.fromInt config.max ++ "+") ]
                , Html.span [ Internal.cls [ "klar-sr-only" ] ] [ Html.text exact ]
                ]

             else
                [ Html.text exact ]
            )


{-| The label of a badge or a status: cut with an ellipsis when it does not fit,
with the whole text as a tooltip when it is long enough to be cut in a table
cell.
-}
viewLabel : String -> String -> Html msg
viewLabel className label =
    Html.span
        [ Internal.cls [ className ]
        , Internal.attrIf (String.length label > 12) (Attr.title label)
        ]
        [ Html.text label ]


styleSuffix : Style -> String
styleSuffix style =
    case style of
        Subtle ->
            "subtle"

        Solid ->
            "solid"

        Outline ->
            "outline"
