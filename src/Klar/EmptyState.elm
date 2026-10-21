module Klar.EmptyState exposing
    ( view
    , Attribute, icon, title, description, action
    , compact
    )

{-| What to show when there is nothing to show: an empty list, no search
results, a first-run screen.

    import Klar.Button as Button
    import Klar.EmptyState as EmptyState
    import Klar.Icon as Icon

    EmptyState.view
        [ EmptyState.icon Icon.search
        , EmptyState.title "No matching orders"
        , EmptyState.description "Try a different search or clear the filters."
        , EmptyState.action (Button.view [ Button.onClick ClearFilters ] "Clear filters")
        ]

Say what is missing and, where it helps, what the user can do about it: a
button that clears the filters or creates the first item. For a request that
failed use [Klar.ErrorState](Klar-ErrorState) instead.

The components that show remote data ([Klar.Table](Klar-Table),
[Klar.Tree](Klar-Tree), [Klar.ListItem](Klar-ListItem) ...) render an empty
state themselves when a list comes back empty; use this module for the views
you build on your own. An empty state is ordinary content: it has no live
region, so screen readers do not announce it when it appears.


# View

@docs view


# Content

@docs Attribute, icon, title, description, action


# Look

@docs compact

-}

import Html exposing (Html)
import Klar.Icon as Icon exposing (Icon)
import Klar.Internal as Internal


{-| A setting of an empty state. Make them with the functions below and pass a
list to `view`; later attributes win over earlier ones.
-}
type Attribute msg
    = Attribute (Config msg -> Config msg)


type alias Config msg =
    { icon : Icon
    , title : String
    , description : Maybe String
    , action : Maybe (Html msg)
    , compact : Bool
    }


configure : List (Attribute msg) -> Config msg
configure attributes =
    List.foldl (\(Attribute change) config -> change config)
        { icon = Icon.inbox
        , title = ""
        , description = Nothing
        , action = Nothing
        , compact = False
        }
        attributes


{-| The large icon above the title. The default is `Icon.inbox`.
-}
icon : Icon -> Attribute msg
icon value =
    Attribute (\config -> { config | icon = value })


{-| The headline, such as "No orders yet". Give one: a state says what is
missing. The default is no title, and an empty title (or one of spaces only)
renders no headline element at all.
-}
title : String -> Attribute msg
title value =
    Attribute (\config -> { config | title = value })


{-| A sentence under the title that says why there is nothing here or what to
do about it. There is none by default.
-}
description : String -> Attribute msg
description value =
    Attribute (\config -> { config | description = Just value })


{-| A button or link below the text, for the obvious next step.
-}
action : Html msg -> Attribute msg
action value =
    Attribute (\config -> { config | action = Just value })


{-| Less vertical space and a smaller icon, for use inside tables and small
panels.
-}
compact : Attribute msg
compact =
    Attribute (\config -> { config | compact = True })


{-| A centered block with an icon, a title, an optional description and an
optional action.

    EmptyState.view [ EmptyState.title "No orders yet" ]

-}
view : List (Attribute msg) -> Html msg
view attributes =
    let
        config =
            configure attributes
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
        , Internal.viewMaybe (\text -> Html.div [ Internal.cls [ "klar-state__title" ] ] [ Html.text text ]) (Internal.nonEmpty config.title)
        , Internal.viewMaybe (\text -> Html.p [ Internal.cls [ "klar-state__description" ] ] [ Html.text text ]) config.description
        , Internal.viewMaybe (\html -> Html.div [ Internal.cls [ "klar-state__action" ] ] [ html ]) config.action
        ]
