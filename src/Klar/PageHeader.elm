module Klar.PageHeader exposing
    ( view, Attribute
    , title, headingLevel, subtitle, badges, meta, metaItem
    , breadcrumbs, backLink, actions, tabs
    , band, sticky
    )

{-| The top of a page: the title, a line of explanation, where the page sits in
the application, the state of the thing you are looking at, and what you can do
with it.

Use when: a page needs a title with its subtitle, status, breadcrumbs, actions and tabs at the top.
Do not use when: you need the frame of the whole application (use `Klar.AppShell`) or the title of a card or panel (use `Klar.Card`).

    import Klar.Badge as Badge
    import Klar.Breadcrumbs as Breadcrumbs
    import Klar.Button as Button
    import Klar.Icon as Icon
    import Klar.Menu as Menu
    import Klar.PageHeader as PageHeader
    import Klar.Tabs as Tabs
    import Klar.Theme exposing (Tone(..))

    PageHeader.view
        [ PageHeader.breadcrumbs
            (Breadcrumbs.static
                [ Breadcrumbs.items
                    [ Breadcrumbs.link "Orders" "#/orders"
                    , Breadcrumbs.text "Order 10482"
                    ]
                ]
            )
        , PageHeader.title "Order 10482"
        , PageHeader.subtitle "Placed by Ada Lovelace on 12 March 2025"
        , PageHeader.badges [ Badge.view [ Badge.tone Success ] "Shipped" ]
        , PageHeader.meta
            [ PageHeader.metaItem "Customer number" "100482"
            , PageHeader.metaItem "Last changed" "2 hours ago"
            ]
        , PageHeader.actions
            [ Button.view [ Button.primary, Button.icon Icon.edit ] "Edit"
            , Menu.view MenuMsg
                [ Menu.kebab "More actions"
                , Menu.alignEnd
                , Menu.items [ Menu.item "Duplicate order" Duplicate ]
                ]
                model.menu
            ]
        , PageHeader.tabs
            (Tabs.view TabsMsg
                [ Tabs.withoutPanels
                , Tabs.tabs [ Tabs.tab "details" "Details", Tabs.tab "items" "Items" ]
                ]
                model.tabs
            )
        ]

Everything but the title is optional, and a part you leave out takes no space.
The title is the `h1` of the page, so use one header per page (or choose another
level with `headingLevel`); without a title (or with a blank one) the header
renders no heading at all. The header keeps no
state and has no text of its own: the breadcrumbs, tabs and menus you pass in are
built by you and keep their state in your model.

The header is an ordinary block inside the page. `band` turns it into a
full-width white band with a line underneath, which cancels the padding of the
content area of [Klar.AppShell](Klar-AppShell), and `sticky` keeps that band at
the top of the scrolling area while the page scrolls. The actions move below the
title when there is no room beside it.


# View

@docs view, Attribute


# Title

@docs title, headingLevel, subtitle, badges, meta, metaItem


# Navigation and actions

@docs breadcrumbs, backLink, actions, tabs


# Look

@docs band, sticky

-}

import Html exposing (Html)
import Html.Attributes as Attr
import Klar.Icon as Icon
import Klar.Internal as Internal



-- ATTRIBUTES


{-| A part or a setting of the header. Make them with the functions below and
pass a list to `view`; later attributes win over earlier ones, and the parts can
come in any order.
-}
type Attribute msg
    = Attribute (Config msg -> Config msg)


type alias Config msg =
    { title : String
    , headingLevel : Int
    , subtitle : Maybe String
    , breadcrumbs : Maybe (Html msg)
    , back : Maybe { href : String, label : String }
    , badges : List (Html msg)
    , meta : List (Html msg)
    , actions : List (Html msg)
    , tabs : Maybe (Html msg)
    , band : Bool
    , sticky : Bool
    }


configure : List (Attribute msg) -> Config msg
configure attributes =
    List.foldl (\(Attribute change) config -> change config)
        { title = ""
        , headingLevel = 1
        , subtitle = Nothing
        , breadcrumbs = Nothing
        , back = Nothing
        , badges = []
        , meta = []
        , actions = []
        , tabs = Nothing
        , band = False
        , sticky = False
        }
        attributes


{-| The page title, rendered as the `h1` of the page. Without a title, or with a
blank one, the header renders no heading at all, so another element of the page
must be its `h1`.
-}
title : String -> Attribute msg
title value =
    Attribute (\config -> { config | title = value })


{-| The level of the heading element of the title, from 1 to 6. The default is 1,
because the header is normally the top of the page. Use another level when the
header sits inside a page that already has an `h1`, such as a header in a panel or
a dialog, or a page with several headers (a gallery of examples). A number outside
the range counts as the nearest level. The level changes the element, not the look
of the title.

    PageHeader.view [ PageHeader.title "Order lines", PageHeader.headingLevel 2 ]

-}
headingLevel : Int -> Attribute msg
headingLevel level =
    Attribute (\config -> { config | headingLevel = clamp 1 6 level })


{-| A line of gray text under the title, for a short explanation of the page.
-}
subtitle : String -> Attribute msg
subtitle value =
    Attribute (\config -> { config | subtitle = Just value })


{-| Where the page sits in the application, above the title. Pass a
[Klar.Breadcrumbs](Klar-Breadcrumbs) trail, made with `Breadcrumbs.view` or
`Breadcrumbs.static`. Together with a `backLink` the link comes first, then the
trail, on the same line.
-}
breadcrumbs : Html msg -> Attribute msg
breadcrumbs value =
    Attribute (\config -> { config | breadcrumbs = Just value })


{-| A link with a left arrow back to the list the page came from, above the title.
`href` is where it goes (`#/path` for navigation inside a single page
application) and `label` its text.

    PageHeader.backLink { href = "#/orders", label = "All orders" }

-}
backLink : { href : String, label : String } -> Attribute msg
backLink value =
    Attribute (\config -> { config | back = Just value })


{-| Status badges on the same line as the title, after it (they wrap below the
title when there is no room). Pass [Klar.Badge](Klar-Badge) views.
-}
badges : List (Html msg) -> Attribute msg
badges value =
    Attribute (\config -> { config | badges = value })


{-| A row of small facts under the subtitle, such as an identifier or the time of
the last change. Make each fact with `metaItem`.
-}
meta : List (Html msg) -> Attribute msg
meta value =
    Attribute (\config -> { config | meta = value })


{-| Buttons and menus at the right end of the header, level with the title. Put
the primary action first. They move below the title when there is no room beside
it.
-}
actions : List (Html msg) -> Attribute msg
actions value =
    Attribute (\config -> { config | actions = value })


{-| A row of tabs along the bottom edge of the header. Pass the tab strip made by
`Tabs.view` from [Klar.Tabs](Klar-Tabs). The panels, if there are any
(`Tabs.panel`), belong in the body of the page below the header; when the tabs
choose a route and have no panels, give the strip `Tabs.withoutPanels`.
-}
tabs : Html msg -> Attribute msg
tabs value =
    Attribute (\config -> { config | tabs = Just value })


{-| A white band across the full width with a line underneath, instead of a plain
block. Inside [Klar.AppShell](Klar-AppShell) it cancels the padding of the content
area so that the band touches the edges, so use it for the first element of a
page. Anywhere else it is a white block with padding and a line under it.
-}
band : Attribute msg
band =
    Attribute (\config -> { config | band = True })


{-| Keeps the header at the top of the scrolling area while the page scrolls.
Implies `band`.
-}
sticky : Attribute msg
sticky =
    Attribute (\config -> { config | sticky = True, band = True })



-- VIEW


{-| One fact for `meta`: a gray label and its value, in that order.

    PageHeader.metaItem "Customer number" "100482"

-}
metaItem : String -> String -> Html msg
metaItem label value =
    Html.span [ Internal.cls [ "klar-page-header__meta-item" ] ]
        [ Html.span [ Internal.cls [ "klar-page-header__meta-label" ] ] [ Html.text label ]
        , Html.span [ Internal.cls [ "klar-page-header__meta-value" ] ] [ Html.text value ]
        ]


{-| The header block. Everything but the title is optional and left out when
empty. The order of the attributes does not matter: the parts always appear in
the same places.
-}
view : List (Attribute msg) -> Html msg
view attributes =
    let
        config =
            configure attributes

        hasTop =
            isJust config.breadcrumbs || isJust config.back

        -- no title, no `h1`: an empty heading would only confuse screen readers
        title_ =
            Internal.nonEmpty config.title

        hasBadges =
            not (List.isEmpty config.badges)
    in
    Html.header
        [ Internal.cls
            [ "klar-page-header"
            , if config.band then
                "klar-page-header--band"

              else
                ""
            , if config.sticky then
                "klar-page-header--sticky"

              else
                ""
            , if isJust config.tabs then
                "klar-page-header--has-tabs"

              else
                ""
            ]
        ]
        [ Internal.viewIf hasTop
            (Html.div [ Internal.cls [ "klar-page-header__top" ] ]
                [ Internal.viewMaybe
                    (\back ->
                        Html.a [ Internal.cls [ "klar-page-header__back" ], Attr.href back.href ]
                            [ Icon.view Icon.arrowLeft
                            , Html.span [] [ Html.text back.label ]
                            ]
                    )
                    config.back
                , Internal.viewMaybe identity config.breadcrumbs
                ]
            )
        , Html.div [ Internal.cls [ "klar-page-header__main" ] ]
            [ Html.div [ Internal.cls [ "klar-page-header__titles" ] ]
                [ Internal.viewIf (isJust title_ || hasBadges)
                    (Html.div [ Internal.cls [ "klar-page-header__title-row" ] ]
                        [ Internal.viewMaybe
                            (\text -> Internal.heading config.headingLevel [ Internal.cls [ "klar-page-header__title" ] ] [ Html.text text ])
                            title_
                        , Internal.viewIf hasBadges
                            (Html.div [ Internal.cls [ "klar-page-header__badges" ] ] config.badges)
                        ]
                    )
                , Internal.viewMaybe
                    (\text -> Html.p [ Internal.cls [ "klar-page-header__subtitle" ] ] [ Html.text text ])
                    config.subtitle
                , Internal.viewIf (not (List.isEmpty config.meta))
                    (Html.div [ Internal.cls [ "klar-page-header__meta" ] ] config.meta)
                ]
            , Internal.viewIf (not (List.isEmpty config.actions))
                (Html.div [ Internal.cls [ "klar-page-header__actions" ] ] config.actions)
            ]
        , Internal.viewMaybe
            (\content -> Html.div [ Internal.cls [ "klar-page-header__tabs" ] ] [ content ])
            config.tabs
        ]


isJust : Maybe a -> Bool
isJust maybe =
    case maybe of
        Just _ ->
            True

        Nothing ->
            False
