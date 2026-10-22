module Klar.RemoteView exposing
    ( view
    , Attribute, onRetry, loadingLabel, skeleton, zone, locale
    )

{-| The body of a card, a dialog or a drawer that shows one piece of remote data:
a loading skeleton that screen readers hear, the failure with a retry, and the
data, old or being refreshed. You write only what the data looks like.

    import Klar.Card as Card
    import Klar.RemoteView as RemoteView

    Card.view [ Card.title "Order 1042" ]
        (RemoteView.view
            [ RemoteView.onRetry ReloadOrder, RemoteView.loadingLabel "Loading order" ]
            model.order
            viewOrder
        )

    -- the same for a drawer or a dialog
    Drawer.view DrawerMsg
        [ Drawer.title "Order 1042" ]
        model.drawer
        (RemoteView.view [ RemoteView.onRetry ReloadOrder ] model.order viewOrder)

`NotAsked` and `Loading` show a skeleton and set the body busy, with a polite
"Loading" for screen readers (`loadingLabel` says what is loading). `Failed` shows
the problem with a "Try again" button (`onRetry`). `Loaded` calls your function.
Data that is `Kept` ([Klar.Remote](Klar-Remote)) stays on the screen: dimmed and
busy while it is refreshed, and with "Old data from 14:05" and a retry when the
last refresh failed. An empty result is yours to draw, with
[Klar.EmptyState](Klar-EmptyState), inside the function.

The body is a list of nodes, so it fits wherever a list of children goes: the body
of a `Card`, a `Modal` or a `Drawer`, or any `Html.div`. Inside a `Modal` or
`Drawer`, focus that was on the retry button when the data reloads goes back into
the dialog by itself; in a `Card` it falls to the page, so move it yourself
(`Browser.Dom.focus`) if that matters.

@docs view


# Attributes

@docs Attribute, onRetry, loadingLabel, skeleton, zone, locale

-}

import Html exposing (Html)
import Html.Attributes as Attr
import Klar.ErrorState as ErrorState
import Klar.Internal as Internal
import Klar.Internal.Freshness as Freshness
import Klar.Locale as Locale exposing (Locale)
import Klar.Remote as Remote exposing (Remote)
import Klar.Skeleton as Skeleton
import Time


{-| A setting of the body. Make them with the functions below and pass a list to
`view`; later attributes win over earlier ones.
-}
type Attribute msg
    = Attribute (Config msg -> Config msg)


type alias Config msg =
    { onRetry : Maybe msg
    , loadingLabel : Maybe String
    , skeleton : Maybe (Html msg)
    , zone : Time.Zone
    , locale : Locale
    }


configure : List (Attribute msg) -> Config msg
configure attributes =
    List.foldl (\(Attribute change) config -> change config)
        { onRetry = Nothing, loadingLabel = Nothing, skeleton = Nothing, zone = Time.utc, locale = Locale.default }
        attributes


{-| The message sent by the "Try again" button, in the failure and in the marker
of old data. The button is only shown for problems worth retrying (see
`Remote.isRetryable`).
-}
onRetry : msg -> Attribute msg
onRetry msg =
    Attribute (\config -> { config | onRetry = Just msg })


{-| What is loading, as screen readers should hear it: "Loading order". The
default is "Loading".
-}
loadingLabel : String -> Attribute msg
loadingLabel text =
    Attribute (\config -> { config | loadingLabel = Just text })


{-| The placeholder shown while loading, drawn with [Klar.Skeleton](Klar-Skeleton).
The default is a title line and a few lines of text.
-}
skeleton : Html msg -> Attribute msg
skeleton html =
    Attribute (\config -> { config | skeleton = Just html })


{-| The time zone of the time in "Old data from 14:05". The default is UTC.
-}
zone : Time.Zone -> Attribute msg
zone value =
    Attribute (\config -> { config | zone = value })


{-| The language of the built-in text ("Loading", "Try again", "Old data from").
The default is `Locale.default`, which is English.
-}
locale : Locale -> Attribute msg
locale value =
    Attribute (\config -> { config | locale = value })


{-| The body for a `Remote`: the skeleton, the failure, or what your function
makes of the data.
-}
view : List (Attribute msg) -> Remote a -> (a -> List (Html msg)) -> List (Html msg)
view attributes data toBody =
    let
        config =
            configure attributes

        ( settled, freshness ) =
            Freshness.settle data

        loading =
            [ Html.div
                [ Internal.cls [ "klar-remote-body", "klar-remote-body--loading" ]
                , Attr.attribute "aria-busy" "true"
                ]
                [ Html.span [ Internal.cls [ "klar-sr-only" ], Attr.attribute "role" "status" ]
                    [ Html.text (Maybe.withDefault (Locale.pick config.locale { nb = "Laster", en = "Loading" }) config.loadingLabel) ]
                , case config.skeleton of
                    Just html ->
                        html

                    Nothing ->
                        Html.div [ Internal.cls [ "klar-remote-body" ] ]
                            [ Skeleton.line 45
                            , Skeleton.paragraph 3
                            ]
                ]
            ]
    in
    case settled of
        Remote.Loaded value ->
            case freshness of
                Freshness.Fresh ->
                    toBody value

                _ ->
                    [ Html.div
                        [ Internal.cls [ "klar-remote-body", Freshness.className freshness ]
                        , Freshness.busyAttr freshness
                        ]
                        (Freshness.notice
                            { locale = config.locale, zone = config.zone, onRetry = config.onRetry, inline = False }
                            freshness
                            :: toBody value
                        )
                    ]

        Remote.Failed problem ->
            [ ErrorState.view
                (List.filterMap identity
                    [ Just ErrorState.compact
                    , Just (ErrorState.locale config.locale)
                    , Maybe.map ErrorState.onRetry config.onRetry
                    ]
                )
                problem
            ]

        _ ->
            loading
