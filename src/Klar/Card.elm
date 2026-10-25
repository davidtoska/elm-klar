module Klar.Card exposing
    ( view
    , Attribute, title, headingLevel, subtitle, actions, footer
    , flush, sunken, raised, accent
    , id
    )

{-| A bordered surface that groups related content, with an optional header and
footer.

Use when: related content belongs together on a bordered surface with an optional title, actions and footer.
Do not use when: the content is a whole page region with its own header (as `Klar.PageHeader`) or an overlay (as `Klar.Modal`).
Quick path: `view`, `title`, `actions`, `footer`, `RemoteView.view`

    import Klar.Button as Button
    import Klar.Card as Card

    Card.view
        [ Card.title "Recent activity"
        , Card.subtitle "Last 30 days"
        , Card.actions [ Button.view [ Button.small ] "Export" ]
        ]
        [ content ]

The header is shown when the card has a title, a subtitle or actions. The card
is a `section` element and its title is an `h2`, the level under the `h1` of a
`PageHeader`, unless you choose another level
with `headingLevel`, so that the title fits the outline of the page (see
[Klar.Text](Klar-Text) for the other headings). `flush` removes the padding of
the body, for tables and lists that go edge to edge; `accent`, `sunken` and
`raised` change the look.

A card with an `id` and a title is a named region: a landmark that screen readers
list with the other landmarks of the page, named by its title, so a person can jump
from card to card on a dashboard. Give an `id` to the few cards that are the main
parts of a page, not to every card: twelve landmarks are as hard to use as none. A
card needs no id for focus; focus goes to its body (`RemoteView.id` below).

A card that shows one piece of remote data takes its body from
[Klar.RemoteView](Klar-RemoteView): the loading skeleton, the failure with a
retry, and old or refreshing data, without a `case` of your own. Give the body an
`id` and move focus to it when the retry starts, because the "Try again" button that
had the focus is replaced by the skeleton:

    -- view: `settings` gives the time zone of "Old data from 14:05", `locale` the language
    Card.view [ Card.title "Order 1042" ]
        (RemoteView.view
            [ RemoteView.id "order-body"
            , RemoteView.onRetry ReloadOrder
            , RemoteView.settings model.settings
            , RemoteView.locale (Settings.locale model.settings)
            ]
            model.order
            viewOrder
        )

    -- update
    ReloadOrder ->
        ( { model | order = Remote.refresh model.order }
        , Cmd.batch [ fetchOrder, Klar.focus "order-body" NoOp ]
        )


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
    , footer : List (Html msg)
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
        , headingLevel = 2
        , subtitle = Nothing
        , actions = []
        , footer = []
        , flush = False
        , sunken = False
        , raised = False
        , accent = Nothing
        , id = Nothing
        }
        attributes


{-| The title in the header, an `h2` unless you set another level with
`headingLevel`. A card without a title, a subtitle or actions has no header.
-}
title : String -> Attribute msg
title value =
    Attribute (\config -> { config | title = Just value })


{-| The level of the heading element of the title, from 1 to 6: `headingLevel 3`
makes it an `h3`. The default is 2, the level under the `h1` of a
[PageHeader](Klar-PageHeader). A number outside the range counts as the nearest
level. Choose another level for a card inside a section that has its own `h2`
(the card then takes 3): one below the heading of the section the card is in. The
level changes the element, not the look of the title.

    Card.view [ Card.title "Recent activity", Card.headingLevel 3 ] [ content ]

-}
headingLevel : Int -> Attribute msg
headingLevel level =
    Attribute (\config -> { config | headingLevel = clamp 1 6 level })


{-| A smaller line under the title, such as a period or a count. An empty text is no
subtitle.
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


{-| A tinted strip below the body, such as a summary or a few buttons, laid out in a
row that wraps. It starts at the left; a `Layout.spacer` pushes what comes after it
to the right end. An empty list is no footer.

    Card.footer [ Text.caption "Updated 3 minutes ago", Layout.spacer, Button.view [ Button.small ] "View all" ]

-}
footer : List (Html msg) -> Attribute msg
footer value =
    Attribute (\config -> { config | footer = value })


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


{-| The DOM id of the card. With a title, it also makes the card a named region, a
landmark of the page: the title gets the id `<id>-title` and the card points at it
with `aria-labelledby`. So give it only to the main cards of a page, the ones a person
jumps between; a card does not need an id to be scrolled to or focused inside.
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

        subtitleText =
            Maybe.andThen Internal.nonEmpty config.subtitle

        hasHeader =
            titleText /= Nothing || subtitleText /= Nothing || not (List.isEmpty config.actions)

        -- A section is a region landmark only when it has a name: the title, by its id.
        titleId =
            case ( config.id, titleText ) of
                ( Just cardId, Just _ ) ->
                    Just (cardId ++ "-title")

                _ ->
                    Nothing
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
                    "klar-card--accent klar-card--accent-" ++ Internal.toneSuffix tone

                Nothing ->
                    ""
            ]
        , Internal.attrMaybe Attr.id config.id
        , Internal.attrMaybe (Attr.attribute "aria-labelledby") titleId
        ]
        [ Internal.viewIf hasHeader
            (Html.header [ Internal.cls [ "klar-card__header" ] ]
                [ Html.div [ Internal.cls [ "klar-card__heading" ] ]
                    [ Internal.viewMaybe
                        (\t ->
                            Internal.heading config.headingLevel
                                [ Internal.cls [ "klar-card__title" ], Internal.attrMaybe Attr.id titleId ]
                                [ Html.text t ]
                        )
                        titleText
                    , Internal.viewMaybe (\t -> Html.p [ Internal.cls [ "klar-card__subtitle" ] ] [ Html.text t ]) subtitleText
                    ]
                , Internal.viewIf (not (List.isEmpty config.actions))
                    (Html.div [ Internal.cls [ "klar-card__actions" ] ] config.actions)
                ]
            )
        , Html.div [ Internal.cls [ "klar-card__body" ] ] children
        , Internal.viewIf (not (List.isEmpty config.footer))
            (Html.footer [ Internal.cls [ "klar-card__footer" ] ] config.footer)
        ]
