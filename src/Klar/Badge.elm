module Klar.Badge exposing
    ( view, status, count
    , Attribute, tone, solid, outline, dot, icon, size
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

    Badge.count 128

A badge shows a state that the user reads but does not change. For something
the user picked and can take away, use [Klar.Tag](Klar-Tag). There are three
forms: `view` is a small box with a tinted background (or a `solid` or `outline`
one), `status` is a colored dot with text and no box, which fits well in table
cells, and `count` is a round number.

The color is not announced by screen readers, so put the meaning in the text
("Overdue", not just a red badge). A label that does not fit its container is
cut with an ellipsis; labels longer than 18 characters (24 for `status`) carry
the whole text as a tooltip. Badges never send messages, so `Attribute` has no
`msg` parameter.


# Views

@docs view, status, count


# Attributes

@docs Attribute, tone, solid, outline, dot, icon, size

-}

import Html exposing (Html)
import Html.Attributes as Attr
import Klar.Icon as Icon exposing (Icon)
import Klar.Internal as Internal
import Klar.Theme as Theme exposing (Size(..), Tone(..))


{-| A setting of a badge. Make them with the functions below and pass a list to
`view`; later attributes win over earlier ones.
-}
type Attribute
    = Attribute (Config -> Config)


type alias Config =
    { tone : Tone
    , style : Style
    , dot : Bool
    , size : Size
    , icon : Maybe Icon
    }


type Style
    = Subtle
    | Solid
    | Outline


configure : List Attribute -> Config
configure attributes =
    List.foldl (\(Attribute change) config -> change config)
        { tone = Neutral, style = Subtle, dot = False, size = Medium, icon = Nothing }
        attributes


{-| The color of the badge: `Neutral` (gray, the default), `Primary` or `Info`
(blue), `Success`, `Warning` or `Danger`.
-}
tone : Tone -> Attribute
tone value =
    Attribute (\config -> { config | tone = value })


{-| A background filled with the color of the tone instead of the default light
tint, for a badge that has to stand out.
-}
solid : Attribute
solid =
    Attribute (\config -> { config | style = Solid })


{-| A border in the color of the tone and no fill, instead of the default light
tint.
-}
outline : Attribute
outline =
    Attribute (\config -> { config | style = Outline })


{-| A small dot before the text, in the color of the text.
-}
dot : Attribute
dot =
    Attribute (\config -> { config | dot = True })


{-| The size of the badge: `Small` (16px high), `Medium` (20px, the default) or
`Large` (24px).
-}
size : Size -> Attribute
size value =
    Attribute (\config -> { config | size = value })


{-| A small icon before the text (after the `dot`, if there is one).
-}
icon : Icon -> Attribute
icon value =
    Attribute (\config -> { config | icon = Just value })


{-| A badge with the given text. Name the state in the text: the color is only a
hint.

    Badge.view [ Badge.tone Success, Badge.solid ] "Shipped"

-}
view : List Attribute -> String -> Html msg
view attributes label =
    let
        config =
            configure attributes
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
        , Html.span [ Internal.cls [ "klar-badge__label" ], Internal.attrIf (String.length label > 18) (Attr.title label) ] [ Html.text label ]
        ]


{-| A plain status: a colored dot and text, without a box. Good inside tables
and lists, where a column of boxes would be noisy.

    Badge.status Success "In stock"

-}
status : Tone -> String -> Html msg
status value label =
    Html.span [ Internal.cls [ "klar-status", "klar-status--" ++ Internal.toneSuffix value ] ]
        [ Html.span [ Internal.cls [ "klar-status__dot" ] ] []
        , Html.span [ Internal.cls [ "klar-status__label" ], Internal.attrIf (String.length label > 24) (Attr.title label) ] [ Html.text label ]
        ]


{-| A round number badge, such as a count of unread messages. It shows `99+` for
every number above 99.

    Badge.count 128 -- shows "99+"

-}
count : Int -> Html msg
count n =
    Html.span [ Internal.cls [ "klar-badge", "klar-badge--count" ] ]
        [ Html.text
            (if n > 99 then
                "99+"

             else
                String.fromInt n
            )
        ]


styleSuffix : Style -> String
styleSuffix style =
    case style of
        Subtle ->
            "subtle"

        Solid ->
            "solid"

        Outline ->
            "outline"
