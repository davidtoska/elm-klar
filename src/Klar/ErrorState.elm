module Klar.ErrorState exposing
    ( view
    , Attribute, onRetry, compact, locale
    )

{-| What to show when a request failed: a clear title, the reason, and a
button to try again when trying again can help.

    import Klar.ErrorState as ErrorState
    import Klar.Locale as Locale
    import Klar.Remote as Remote exposing (Remote(..))
    import Klar.Spinner as Spinner

    viewOrders : Remote (List Order) -> Html Msg
    viewOrders orders =
        case orders of
            Loaded list ->
                viewOrderList list

            Failed problem ->
                ErrorState.view [ ErrorState.onRetry ReloadOrders ] problem

            _ ->
                Spinner.panel "Loading orders ..."

    -- inside a table or small panel
    ErrorState.view [ ErrorState.compact, ErrorState.onRetry ReloadOrders ] problem

Pair it with [Klar.Remote](Klar-Remote): when the data is `Failed problem`,
show this. A `Problem` is plain data. Make one for each failed request with
`Remote.problem`, which has ready-made texts for the kind of failure, and adjust
it with `Remote.withTitle`, `Remote.withDetail` or `Remote.withCode`:

    Remote.problem Remote.server
        |> Remote.withCode "503"

The icon follows the kind of the problem (`Icon.wifiOff` for `Remote.network`,
`Icon.clock` for `Remote.timeout`, `Icon.lock` for `Remote.forbidden` ...). The state is
announced to screen readers at once (`role="alert"`). The retry button is shown
only when you gave an `onRetry` message and the problem is worth retrying
(`Remote.isRetryable`: network trouble, timeouts, server errors and unknown
errors). The other kinds, such as a missing resource or a permission problem,
would fail the same way again, so there is no button for them. The components
that show remote data ([Klar.Table](Klar-Table), [Klar.Tree](Klar-Tree),
[Klar.ListItem](Klar-ListItem) ...) use this module themselves.


# View

@docs view


# Attributes

@docs Attribute, onRetry, compact, locale

-}

import Html exposing (Html)
import Html.Attributes as Attr
import Klar.Button as Button
import Klar.Icon as Icon exposing (Icon)
import Klar.Internal as Internal
import Klar.Locale as Locale exposing (Locale)
import Klar.Remote as Remote exposing (Kind, Problem)


{-| A setting of an error state. Make them with the functions below and pass a
list to `view`; later attributes win over earlier ones.
-}
type Attribute msg
    = Attribute (Config msg -> Config msg)


type alias Config msg =
    { onRetry : Maybe msg
    , compact : Bool
    , locale : Locale
    }


configure : List (Attribute msg) -> Config msg
configure attributes =
    List.foldl (\(Attribute change) config -> change config)
        { onRetry = Nothing, compact = False, locale = Locale.default }
        attributes


{-| The message sent when the user presses the "Try again" button. Without
`onRetry` there is no button. With it, the button is still hidden when trying
again would not help (see `Klar.Remote.isRetryable`).
-}
onRetry : msg -> Attribute msg
onRetry msg =
    Attribute (\config -> { config | onRetry = Just msg })


{-| Less vertical space and a smaller icon, for use inside tables and small
panels.
-}
compact : Attribute msg
compact =
    Attribute (\config -> { config | compact = True })


{-| The language of the built-in text, which is the label of the retry button
("Try again" in English). The default is `Locale.default`, which is English. The
title and the detail come from the `Problem`: the texts the problem has of its
own, or the ready-made ones for its kind in this language.
-}
locale : Locale -> Attribute msg
locale value =
    Attribute (\config -> { config | locale = value })


{-| An error state for a `Problem`: an icon for its kind, its title, its detail
and its code (when it has them), and the retry button. A problem with an empty
title renders no headline element.

    ErrorState.view [ ErrorState.onRetry ReloadOrders ] problem

-}
view : List (Attribute msg) -> Problem -> Html msg
view attributes problem =
    let
        config =
            configure attributes

        retryLabel =
            Locale.pick config.locale { nb = "Prøv igjen", en = "Try again" }
    in
    Html.div
        [ Internal.cls
            [ "klar-state"
            , "klar-state--error"
            , if config.compact then
                "klar-state--compact"

              else
                ""
            ]
        , Attr.attribute "role" "alert"
        ]
        [ Html.span [ Internal.cls [ "klar-state__icon" ] ] [ Icon.sized Icon.ExtraLarge (iconFor (Remote.kind problem)) ]
        , Internal.viewMaybe (\text -> Html.div [ Internal.cls [ "klar-state__title" ] ] [ Html.text text ]) (Internal.nonEmpty (Remote.title config.locale problem))
        , Internal.viewMaybe (\text -> Html.p [ Internal.cls [ "klar-state__description" ] ] [ Html.text text ]) (Remote.detail config.locale problem)
        , Internal.viewMaybe
            (\code -> Html.div [ Internal.cls [ "klar-state__code" ] ] [ Html.text code ])
            (Remote.code problem)
        , case ( config.onRetry, Remote.isRetryable problem ) of
            ( Just msg, True ) ->
                Html.div [ Internal.cls [ "klar-state__action" ] ]
                    [ Button.view [ Button.icon Icon.refresh, Button.onClick msg ] retryLabel ]

            _ ->
                Html.text ""
        ]


iconFor : Kind -> Icon
iconFor kind =
    if kind == Remote.network then
        Icon.wifiOff

    else if kind == Remote.timeout then
        Icon.clock

    else if kind == Remote.server then
        Icon.server

    else if kind == Remote.notFound then
        Icon.search

    else if kind == Remote.forbidden then
        Icon.lock

    else if kind == Remote.unauthorized then
        Icon.key

    else if kind == Remote.validation || kind == Remote.conflict then
        Icon.warning

    else
        Icon.errorCircle
