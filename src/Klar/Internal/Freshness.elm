module Klar.Internal.Freshness exposing
    ( Freshness(..)
    , busy
    , busyAttr
    , className
    , notice
    , settle
    , text
    , waiting
    )

{-| What every data component shows for a `Remote.Kept`: data that is being
refreshed (dimmed, busy) and data that is old because the last refresh failed (a
calm marker with the time and a retry). The component settles its `Remote` once
(`settle` turns `Kept` into `Loaded`) and draws the rest as it always did.
-}

import Html exposing (Html)
import Html.Attributes as Attr
import Klar.Button as Button
import Klar.Icon as Icon
import Klar.Internal as Internal
import Klar.Locale as Locale exposing (Locale)
import Klar.Remote as Remote exposing (Problem, Remote)
import Klar.Settings as Settings exposing (Settings)
import Time


type Freshness
    = Fresh
    | Refreshing
    | Stale { problem : Problem, at : Maybe Time.Posix, refreshing : Bool }


{-| The data as `Loaded` (or the other states untouched), and how fresh it is.
-}
settle : Remote a -> ( Remote a, Freshness )
settle remote =
    case remote of
        Remote.Kept _ ->
            ( case Remote.toMaybe remote of
                Just data ->
                    Remote.Loaded data

                Nothing ->
                    remote
            , case Remote.staleProblem remote of
                Just problem ->
                    Stale { problem = problem, at = Remote.loadedAt remote, refreshing = Remote.isRefreshing remote }

                Nothing ->
                    if Remote.isRefreshing remote then
                        Refreshing

                    else
                        Fresh
            )

        _ ->
            ( remote, Fresh )


{-| Nothing to show yet: not asked or loading.
-}
waiting : Remote a -> Bool
waiting remote =
    case remote of
        Remote.NotAsked ->
            True

        Remote.Loading ->
            True

        _ ->
            False


{-| Whether a refresh is on its way.
-}
busy : Freshness -> Bool
busy freshness =
    case freshness of
        Fresh ->
            False

        Refreshing ->
            True

        Stale value ->
            value.refreshing


{-| `aria-busy` while a refresh is on its way.
-}
busyAttr : Freshness -> Html.Attribute msg
busyAttr freshness =
    Internal.attrIf (busy freshness) (Attr.attribute "aria-busy" "true")


{-| The class that dims the content of a component while it refreshes.
-}
className : Freshness -> String
className freshness =
    if busy freshness then
        "klar-refreshing"

    else
        ""


{-| "Old data from 14:05", for places that only have room for a label.
-}
text : Locale -> Settings -> Maybe Time.Posix -> String
text locale settings maybeAt =
    case maybeAt of
        Just at ->
            Locale.pick locale { nb = "Gamle data fra kl. " ++ Settings.time settings at, en = "Old data from " ++ Settings.time settings at }

        Nothing ->
            Locale.pick locale { nb = "Gamle data", en = "Old data" }


{-| The marker for old data, announced politely, with the retry button when
trying again could help. Nothing for fresh or refreshing data.
-}
notice :
    { locale : Locale, settings : Settings, onRetry : Maybe msg, inline : Bool }
    -> Freshness
    -> Html msg
notice config freshness =
    case freshness of
        Stale value ->
            let
                reason =
                    Locale.pick config.locale { nb = "Oppdateringen feilet", en = "Refresh failed" }

                why =
                    Remote.title config.locale value.problem

                full =
                    case value.at of
                        Just at ->
                            Settings.dateTime config.locale config.settings at

                        Nothing ->
                            ""
            in
            Html.div
                [ Internal.cls
                    [ "klar-stale"
                    , if config.inline then
                        "klar-stale--inline"

                      else
                        ""
                    ]
                , Attr.attribute "role" "status"
                , Attr.title (String.trim (why ++ " " ++ full))
                ]
                [ Icon.view Icon.clock
                , Html.span [ Internal.cls [ "klar-stale__text" ] ] [ Html.text (text config.locale config.settings value.at) ]
                , Html.span
                    [ Internal.cls
                        [ "klar-stale__reason"
                        , if config.inline then
                            "klar-sr-only"

                          else
                            ""
                        ]
                    ]
                    [ Html.text ("· " ++ reason) ]
                , case ( config.onRetry, Remote.isRetryable value.problem ) of
                    ( Just msg, True ) ->
                        Html.span [ Internal.cls [ "klar-stale__action" ] ]
                            [ Button.view
                                [ Button.small
                                , Button.ghost
                                , Button.icon Icon.refresh
                                , Button.loading value.refreshing
                                , Button.onClick msg
                                ]
                                (Locale.pick config.locale { nb = "Prøv igjen", en = "Try again" })
                            ]

                    _ ->
                        Html.text ""
                ]

        _ ->
            Html.text ""
