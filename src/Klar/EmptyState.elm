module Klar.EmptyState exposing
    ( view
    , Attribute, icon, title, description, actions
    , compact, headingLevel, locale
    )

{-| What to show when there is nothing to show: an empty list, no search
results, a first-run screen.

Use when: a list or a screen of your own is empty and the user should be told why and what to do next.
Do not use when: a request failed (use `Klar.ErrorState`).

    import Klar.Button as Button
    import Klar.EmptyState as EmptyState
    import Klar.Icon as Icon

    EmptyState.view
        [ EmptyState.icon Icon.search
        , EmptyState.title "No matching orders"
        , EmptyState.description "Try a different search or clear the filters."
        , EmptyState.actions [ Button.view [ Button.onClick ClearFilters ] "Clear filters" ]
        ]

Say what is missing and, where it helps, what the user can do about it: a
button that clears the filters or creates the first item. For a request that
failed use [Klar.ErrorState](Klar-ErrorState) instead.

The components that show remote data ([Klar.Table](Klar-Table),
[Klar.Tree](Klar-Tree), [Klar.ListItem](Klar-ListItem) ...) render an empty
state themselves when a list comes back empty, and take a list of these
attributes to change it (`Table.emptyState`); use `view` for the views you build
on your own.

An empty state is ordinary content: it has no live region, so screen readers do
not announce it when it appears. When it answers what the user typed (a search
with no results), say so in a live region that stays on the page, such as the
result count of the search, rather than in the empty state.


# View

@docs view


# Content

@docs Attribute, icon, title, description, actions


# Look and text

@docs compact, headingLevel, locale

-}

import Html exposing (Html)
import Klar.Icon as Icon exposing (Icon)
import Klar.Internal as Internal
import Klar.Locale as Locale exposing (Locale)


{-| A setting of an empty state. Make them with the functions below and pass a
list to `view`; later attributes win over earlier ones.
-}
type Attribute msg
    = Attribute (Config msg -> Config msg)


type alias Config msg =
    { icon : Icon
    , title : Maybe String
    , description : Maybe String
    , actions : List (Html msg)
    , compact : Bool
    , headingLevel : Maybe Int
    , locale : Locale
    }


configure : List (Attribute msg) -> Config msg
configure attributes =
    List.foldl (\(Attribute change) config -> change config)
        { icon = Icon.inbox
        , title = Nothing
        , description = Nothing
        , actions = []
        , compact = False
        , headingLevel = Nothing
        , locale = Locale.default
        }
        attributes


{-| The large icon above the title. The default is `Icon.inbox`.
-}
icon : Icon -> Attribute msg
icon value =
    Attribute (\config -> { config | icon = value })


{-| The headline, such as "No orders yet": say what is missing. Without one the
state says "Nothing to show" (in the `locale`), so it is never only an icon. An
empty title (or one of spaces only) renders no headline element at all.
-}
title : String -> Attribute msg
title value =
    Attribute (\config -> { config | title = Just value })


{-| A sentence under the title that says why there is nothing here or what to
do about it. There is none by default.
-}
description : String -> Attribute msg
description value =
    Attribute (\config -> { config | description = Just value })


{-| Buttons or links below the text, for the obvious next steps, such as
"Create order" and "Import orders". The first is the main one. There are none
by default.
-}
actions : List (Html msg) -> Attribute msg
actions value =
    Attribute (\config -> { config | actions = value })


{-| Less vertical space and a smaller icon, for use inside tables and small
panels. It follows a compact density of the application (`Klar.Settings`) without it.
-}
compact : Attribute msg
compact =
    Attribute (\config -> { config | compact = True })


{-| Makes the title a heading of this level (1 to 6), for an empty state that is
the main content of a page or a section, so that screen reader users find it by
its heading. The default is no heading: a plain line, right inside a table cell
or a popup.
-}
headingLevel : Int -> Attribute msg
headingLevel level =
    Attribute (\config -> { config | headingLevel = Just level })


{-| The language of the built-in text, which is the default title ("Nothing to
show" in English). The default is `Locale.default`, which is English.
-}
locale : Locale -> Attribute msg
locale value =
    Attribute (\config -> { config | locale = value })


{-| A centered block with an icon, a title, an optional description and
optional actions.

    EmptyState.view [ EmptyState.title "No orders yet" ]

-}
view : List (Attribute msg) -> Html msg
view attributes =
    let
        config =
            configure attributes

        titleText =
            case config.title of
                Just text ->
                    Internal.nonEmpty text

                Nothing ->
                    Just (Locale.pick config.locale { nb = "Ingenting å vise", en = "Nothing to show" })
    in
    Html.div
        [ Internal.cls
            [ "klar-state"
            , "klar-state--empty"
            , if config.compact then
                "klar-state--compact"

              else
                ""
            ]
        ]
        [ Html.span [ Internal.cls [ "klar-state__icon" ] ] [ Icon.sized Icon.ExtraLarge config.icon ]
        , Internal.viewMaybe (viewTitle config.headingLevel) titleText
        , Internal.viewMaybe (\text -> Html.p [ Internal.cls [ "klar-state__description" ] ] [ Html.text text ]) config.description
        , Internal.viewIf (not (List.isEmpty config.actions))
            (Html.div [ Internal.cls [ "klar-state__actions" ] ] config.actions)
        ]


viewTitle : Maybe Int -> String -> Html msg
viewTitle level text =
    case level of
        Just n ->
            Internal.heading n [ Internal.cls [ "klar-state__title" ] ] [ Html.text text ]

        Nothing ->
            Html.div [ Internal.cls [ "klar-state__title" ] ] [ Html.text text ]
