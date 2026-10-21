module Klar.Card exposing
    ( view
    , Attribute, title, headingLevel, subtitle, actions, footer
    , flush, sunken, raised, accent
    , id
    )

{-| A bordered surface that groups related content, with an optional header and
footer.

    import Klar.Button as Button
    import Klar.Card as Card

    Card.view
        [ Card.title "Recent activity"
        , Card.subtitle "Last 30 days"
        , Card.actions [ Button.view [ Button.small ] "Export" ]
        ]
        [ content ]

The header is shown when the card has a title, a subtitle or actions. The card
is a `section` element and its title is an `h3` unless you choose another level
with `headingLevel`, so that the title fits the outline of the page (see
[Klar.Text](Klar-Text) for the other headings). `flush` removes the padding of
the body, for tables and lists that go edge to edge; `accent`, `sunken` and
`raised` change the look.


# View

@docs view


# Header and footer

@docs Attribute, title, headingLevel, subtitle, actions, footer


# Look

@docs flush, sunken, raised, accent


# HTML

@docs id

-}

import Html exposing (Html)
import Html.Attributes as Attr
import Klar.Internal as Internal
import Klar.Theme as Theme exposing (Tone)


{-| A setting of a card. Make them with the functions below and pass a list to
`view`; later attributes win over earlier ones.
-}
type Attribute msg
    = Attribute (Config msg -> Config msg)


type alias Config msg =
    { title : Maybe String
    , subtitle : Maybe String
    , actions : List (Html msg)
    , footer : Maybe (Html msg)
    , flush : Bool
    , sunken : Bool
    , raised : Bool
    , accent : Maybe Tone
    , id : Maybe String
    , headingLevel : Int
    }


configure : List (Attribute msg) -> Config msg
configure attributes =
    List.foldl (\(Attribute change) config -> change config)
        { title = Nothing
        , headingLevel = 3
        , subtitle = Nothing
        , actions = []
        , footer = Nothing
        , flush = False
        , sunken = False
        , raised = False
        , accent = Nothing
        , id = Nothing
        }
        attributes


{-| The title in the header, an `h3` unless you set another level with
`headingLevel`. A card without a title, a subtitle or actions has no header.
-}
title : String -> Attribute msg
title value =
    Attribute (\config -> { config | title = Just value })


{-| The level of the heading element of the title, from 1 to 6: `headingLevel 2`
makes it an `h2`. The default is 3. A number outside the range counts as the
nearest level. Choose the level that fits the outline of the page: one below the
heading of the section the card is in. The level changes the element, not the
look of the title.

    Card.view [ Card.title "Recent activity", Card.headingLevel 2 ] [ content ]

-}
headingLevel : Int -> Attribute msg
headingLevel level =
    Attribute (\config -> { config | headingLevel = clamp 1 6 level })


{-| A smaller line under the title, such as a period or a count.
-}
subtitle : String -> Attribute msg
subtitle value =
    Attribute (\config -> { config | subtitle = Just value })


{-| Buttons or links at the right end of the header. On a narrow card they move
below the title.
-}
actions : List (Html msg) -> Attribute msg
actions value =
    Attribute (\config -> { config | actions = value })


{-| A single element in a tinted strip below the body, such as a summary or a
row of buttons. To put several elements in the footer, wrap them in a
`Layout.row`.
-}
footer : Html msg -> Attribute msg
footer value =
    Attribute (\config -> { config | footer = Just value })


{-| No padding around the body, so that a table, a list or a picture goes edge to
edge. The header and the footer keep their padding.
-}
flush : Attribute msg
flush =
    Attribute (\config -> { config | flush = True })


{-| A light gray background instead of white, for less prominent content.
-}
sunken : Attribute msg
sunken =
    Attribute (\config -> { config | sunken = True })


{-| A subtle shadow, to lift the card off the page.
-}
raised : Attribute msg
raised =
    Attribute (\config -> { config | raised = True })


{-| A colored strip along the left edge, to mark a status. `Neutral` is gray,
`Primary` and `Info` are blue, and `Success`, `Warning` and `Danger` have colors
of their own.

    Card.view [ Card.title "Payment failed", Card.accent Danger ] [ details ]

-}
accent : Tone -> Attribute msg
accent value =
    Attribute (\config -> { config | accent = Just value })


{-| The DOM id of the card.
-}
id : String -> Attribute msg
id value =
    Attribute (\config -> { config | id = Just value })


{-| A card with the given content in its body. The attributes decide on the
header, the footer and the look of the card.

    Card.view [ Card.title "Shipping address" ] [ Text.paragraph "12 Main Street" ]

-}
view : List (Attribute msg) -> List (Html msg) -> Html msg
view attributes children =
    let
        config =
            configure attributes

        -- An empty title is no title: a heading with no text helps nobody.
        titleText =
            Maybe.andThen Internal.nonEmpty config.title

        hasHeader =
            titleText /= Nothing || config.subtitle /= Nothing || not (List.isEmpty config.actions)
    in
    Html.section
        [ Internal.cls
            [ "klar-card"
            , if config.flush then
                "klar-card--flush"

              else
                ""
            , if config.sunken then
                "klar-card--sunken"

              else
                ""
            , if config.raised then
                "klar-card--raised"

              else
                ""
            , case config.accent of
                Just tone ->
                    "klar-card--accent klar-card--accent-" ++ Theme.toneSuffix tone

                Nothing ->
                    ""
            ]
        , Internal.attrMaybe Attr.id config.id
        ]
        [ Internal.viewIf hasHeader
            (Html.header [ Internal.cls [ "klar-card__header" ] ]
                [ Html.div [ Internal.cls [ "klar-card__heading" ] ]
                    [ Internal.viewMaybe (\t -> Internal.heading config.headingLevel [ Internal.cls [ "klar-card__title" ] ] [ Html.text t ]) titleText
                    , Internal.viewMaybe (\t -> Html.p [ Internal.cls [ "klar-card__subtitle" ] ] [ Html.text t ]) config.subtitle
                    ]
                , Internal.viewIf (not (List.isEmpty config.actions))
                    (Html.div [ Internal.cls [ "klar-card__actions" ] ] config.actions)
                ]
            )
        , Html.div [ Internal.cls [ "klar-card__body" ] ] children
        , Internal.viewMaybe (\f -> Html.footer [ Internal.cls [ "klar-card__footer" ] ] [ f ]) config.footer
        ]
