module Klar.Internal.Collection exposing (Config, empty, more, view)

{-| Shared remote states for the workbench components. Keep the outer region and
its focus target in the calling component, including while data is unavailable.
-}

import Html exposing (Html)
import Html.Attributes as Attr
import Klar.Button as Button
import Klar.EmptyState as EmptyState
import Klar.Internal as Internal
import Klar.Internal.Freshness as Freshness
import Klar.Locale as Locale exposing (Locale)
import Klar.Remote as Remote exposing (Remote)
import Klar.RemoteView as RemoteView
import Klar.Settings exposing (Settings)


type alias Config msg =
    { locale : Locale
    , settings : Settings
    , onRetry : Maybe msg
    , onLoadMore : Maybe msg
    }


view : Config msg -> String -> Remote (List a) -> (List a -> Html msg) -> List (Html msg)
view config emptyTitle remote render =
    let
        ( settled, freshness ) =
            Freshness.settle remote

        body =
            case settled of
                Remote.Loaded items ->
                    if List.isEmpty items then
                        [ empty emptyTitle, more config.locale config.onLoadMore ]

                    else
                        [ render items ]

                _ ->
                    RemoteView.view
                        ([ RemoteView.locale config.locale, RemoteView.settings config.settings ]
                            ++ List.filterMap (Maybe.map RemoteView.onRetry) [ config.onRetry ]
                        )
                        settled
                        (always [])
    in
    [ Html.div
        [ Internal.cls [ "klar-remote-body", Freshness.className freshness ]
        , Freshness.busyAttr freshness
        ]
        (Freshness.notice { locale = config.locale, settings = config.settings, onRetry = config.onRetry, inline = False } freshness :: body)
    ]


empty : String -> Html msg
empty title =
    Html.div [ Attr.attribute "role" "status" ]
        [ EmptyState.view [ EmptyState.compact, EmptyState.title title ] ]


more : Locale -> Maybe msg -> Html msg
more locale onLoad =
    case onLoad of
        Just msg ->
            Html.div [ Internal.cls [ "klar-workbench__more" ] ]
                [ Button.view [ Button.small, Button.onClick msg ]
                    (Locale.pick locale { en = "Load more", nb = "Last flere" })
                ]

        Nothing ->
            Html.text ""
