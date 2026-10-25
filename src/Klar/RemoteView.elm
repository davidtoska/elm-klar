module Klar.RemoteView exposing
    ( view
    , Attribute, onRetry, id, loadingLabel, skeleton, locale, settings
    )

{-| The body of a card, a dialog or a drawer that shows one piece of remote data:
a loading skeleton that screen readers hear, the failure with a retry, and the
data, old or being refreshed. You write only what the data looks like.

Use when: the body of a card, a dialog or a drawer shows one piece of remote data.
Do not use when: the data is a table or a list (use `Klar.Table` or `Klar.ListItem`, which take a `Remote` themselves).

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
last refresh failed. What your function makes is drawn in one column (the same
element whether the data is fresh, refreshing or old, so a refresh that starts or
ends keeps the focus in it). An empty result is yours to draw, with
[Klar.EmptyState](Klar-EmptyState), inside the function.

The body is a list of nodes, so it fits wherever a list of children goes: the body
of a `Card`, a `Modal` or a `Drawer`, or any `Html.div`. Inside a `Modal` or
`Drawer`, focus that was on the retry button when the data reloads goes back into
the dialog by itself; in a `Card` or on a page it falls to the page, unless the body
has an `id` and you move focus to it when you start the new request:

    RemoteView.view [ RemoteView.id "supplier", RemoteView.onRetry Retry ] model.supplier viewSupplier

    Retry ->
        ( { model | supplier = Remote.refresh model.supplier }
        , Cmd.batch [ fetchSupplier, Klar.focus "supplier" NoOp ]
        )

**A page that is only a `RemoteView`** has no heading while the data loads or when the
request failed, if the heading is part of the data. Draw the title of the page outside
the body, from what you know before the data is there, and give the body no heading of
its own: there is then one `h1` in every state.

    Layout.stack []
        [ PageHeader.view [ PageHeader.title (Remote.toMaybe model.supplier |> Maybe.map .name |> Maybe.withDefault "Supplier") ]
        , Layout.stack [] (RemoteView.view [ RemoteView.onRetry Retry ] model.supplier viewDetails)
        ]

@docs view


# Attributes

@docs Attribute, onRetry, id, loadingLabel, skeleton, locale, settings

-}

import Html exposing (Html)
import Html.Attributes as Attr
import Klar.ErrorState as ErrorState
import Klar.Internal as Internal
import Klar.Internal.Freshness as Freshness
import Klar.Locale as Locale exposing (Locale)
import Klar.Remote as Remote exposing (Remote)
import Klar.Settings as Settings exposing (Settings)
import Klar.Skeleton as Skeleton


{-| A setting of the body. Make them with the functions below and pass a list to
`view`; later attributes win over earlier ones.
-}
type Attribute msg
    = Attribute (Config msg -> Config msg)


type alias Config msg =
    { onRetry : Maybe msg
    , id : Maybe String
    , loadingLabel : Maybe String
    , skeleton : Maybe (Html msg)
    , locale : Locale
    , settings : Settings
    }


configure : List (Attribute msg) -> Config msg
configure attributes =
    List.foldl (\(Attribute change) config -> change config)
        { onRetry = Nothing, id = Nothing, loadingLabel = Nothing, skeleton = Nothing, locale = Locale.default, settings = Settings.default }
        attributes


{-| The message sent by the "Try again" button, in the failure and in the marker
of old data. The button is only shown for problems worth retrying (see
`Remote.isRetryable`).
-}
onRetry : msg -> Attribute msg
onRetry msg =
    Attribute (\config -> { config | onRetry = Just msg })


{-| The DOM id of the body. With it, the body is drawn inside one element that is the
same in every state (loading, failed, old data, data) and can take focus, so that
`Klar.focus` has a place to put it. The id must be unique on the page.
-}
id : String -> Attribute msg
id value =
    Attribute (\config -> { config | id = Just value })


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


{-| The settings of the application (`Klar.Settings`): the time zone of the time in
"Old data from 14:05". Without it the time is written in UTC and ends in "UTC".

    RemoteView.settings model.settings

-}
settings : Settings -> Attribute msg
settings given =
    Attribute (\config -> { config | settings = given })


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
    case (configure attributes).id of
        Just domId ->
            [ Html.div [ Attr.id domId, Attr.tabindex -1 ] (body attributes data toBody) ]

        Nothing ->
            body attributes data toBody


body : List (Attribute msg) -> Remote a -> (a -> List (Html msg)) -> List (Html msg)
body attributes data toBody =
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
            [ Freshness.wrap
                { locale = config.locale, settings = config.settings, onRetry = config.onRetry, inline = False }
                [ Internal.cls [ "klar-remote-body" ] ]
                freshness
                (toBody value)
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
