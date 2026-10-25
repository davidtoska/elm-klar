module Klar.Alert exposing
    ( view, viewWith, stale
    , Attribute, tone, title, icon, actions, onDismiss
    , banner, compact
    , polite, id, locale
    )

{-| Inline messages that tell the user something important in the context where
it matters: information, success, a warning or an error.

Use when: the user must see an important message in the place where it matters.
Do not use when: the message should disappear by itself (as `Klar.Toast`).

    import Html
    import Klar.Alert as Alert
    import Klar.Theme exposing (Tone(..))

    Alert.view
        [ Alert.tone Warning, Alert.title "Unsaved changes" ]
        "Your changes to this order are not saved yet."

    Alert.viewWith
        [ Alert.tone Danger, Alert.onDismiss ErrorDismissed, Alert.actions [ retryButton ] ]
        [ Html.text "The order could not be saved. " ]

The tone sets the color and the icon; `Info` is the default. An alert stays
where you put it until you stop showing it. `onDismiss` adds a close button, but
it only sends your message: hide the alert in your `update` function, and move
the focus (the close button had it, and it is gone; see `onDismiss`). For a
message that goes away by itself use [Klar.Toast](Klar-Toast).

Errors and warnings use `role="alert"` so screen readers announce them at once,
even in the middle of a sentence; the other tones use `role="status"`. For a
message that appears while the user is typing (an "unsaved changes" notice), add
`Alert.polite`: it waits for a pause. An alert is announced when it appears, but
a polite one (`role="status"`) that arrives together with its text is missed by
some screen readers: a polite region is heard reliably only when its text changes
while it is on the page. So confirm the result of an action ("The order was
shipped") with a [Klar.Toast](Klar-Toast), whose region stays on the page, and
keep the alert for what must stay in view.


# Views

@docs view, viewWith, stale


# Content

@docs Attribute, tone, title, icon, actions, onDismiss


# Look

@docs banner, compact


# Accessibility and text

@docs polite, id, locale

-}

import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Events
import Klar.Button as Button
import Klar.Icon as Icon exposing (Icon)
import Klar.Internal as Internal
import Klar.Locale as Locale exposing (Locale)
import Klar.Theme as Theme exposing (Tone(..))


{-| A setting of an alert. Make them with the functions below and pass a list
to `view` or `viewWith`; later attributes win over earlier ones.
-}
type Attribute msg
    = Attribute (Config msg -> Config msg)


type alias Config msg =
    { tone : Tone
    , title : Maybe String
    , icon : Maybe Icon
    , onDismiss : Maybe msg
    , actions : List (Html msg)
    , banner : Bool
    , compact : Bool
    , polite : Bool
    , id : Maybe String
    , locale : Locale
    }


configure : List (Attribute msg) -> Config msg
configure attributes =
    List.foldl (\(Attribute change) config -> change config)
        { tone = Info
        , title = Nothing
        , icon = Nothing
        , onDismiss = Nothing
        , actions = []
        , banner = False
        , compact = False
        , polite = False
        , id = Nothing
        , locale = Locale.default
        }
        attributes


{-| The language of the built-in text: the accessible name of the close button
("Close", or "Close: " and the title in English) and the texts of `stale`. The
default is `Locale.default`, which is English.
-}
locale : Locale -> Attribute msg
locale value =
    Attribute (\config -> { config | locale = value })


{-| The kind of message, which sets its color, its icon and how screen readers
announce it. The default is `Info`. `Success`, `Warning` and `Danger` have colors
and icons of their own; `Primary` looks like `Info` and `Neutral` is gray.
-}
tone : Tone -> Attribute msg
tone value =
    Attribute (\config -> { config | tone = value })


{-| A short bold line above the message. There is no title by default.
-}
title : String -> Attribute msg
title value =
    Attribute (\config -> { config | title = Just value })


{-| Replaces the icon that comes with the tone: `Icon.info` for `Neutral`,
`Primary` and `Info`, `Icon.checkCircle` for `Success`, `Icon.warning` for
`Warning` and `Icon.errorCircle` for `Danger`.
-}
icon : Icon -> Attribute msg
icon value =
    Attribute (\config -> { config | icon = Just value })


{-| Shows a close button that sends this message. The alert does not hide
itself: stop showing it when the message arrives in your `update` function.
The button had the keyboard focus, and it goes away with the alert, so move the
focus to the next sensible place in the same branch (`Klar.focus`), or it falls
to the page:

    AlertDismissed ->
        ( { model | showAlert = False }, Klar.focus "order-form" NoOp )

The button is a 24px target named "Close", or "Close: " and the `title` when
the alert has one, so that several alerts on a page can be told apart.

-}
onDismiss : msg -> Attribute msg
onDismiss msg =
    Attribute (\config -> { config | onDismiss = Just msg })


{-| Buttons or links shown below the message, for the next step the user can
take, such as "Try again".
-}
actions : List (Html msg) -> Attribute msg
actions value =
    Attribute (\config -> { config | actions = value })


{-| A flat style for the top of a page or a panel: square corners, a border only
along the bottom edge and a colored bar at the left edge.
-}
banner : Attribute msg
banner =
    Attribute (\config -> { config | banner = True })


{-| Tighter padding and smaller text, for alerts inside forms and tables. Alerts
follow a compact density of the application (`Klar.Settings`) without it.
-}
compact : Attribute msg
compact =
    Attribute (\config -> { config | compact = True })


{-| Announce it politely (`role="status"`) even for a warning or an error, so
a screen reader finishes what it is reading first. Use it for notices that show
up by themselves while the user works, never for the result of an action.
-}
polite : Attribute msg
polite =
    Attribute (\config -> { config | polite = True })


{-| The DOM id of the alert. The alert can then take the focus (`Klar.focus`),
for example the summary of the errors after a failed submit, and a field can
point at it with `aria-describedby`. There is no id by default.

    Alert.view [ Alert.tone Danger, Alert.id "save-error" ] "The order could not be saved."

-}
id : String -> Attribute msg
id value =
    Attribute (\config -> { config | id = Just value })


{-| An alert with a plain text message.

    Alert.view [ Alert.tone Success ] "The order was shipped."

-}
view : List (Attribute msg) -> String -> Html msg
view attributes message =
    viewWith attributes [ Html.text message ]


{-| An alert whose message is HTML, for a link or some emphasis inside the
text.

    Alert.viewWith [ Alert.tone Info ]
        [ Html.text "See the "
        , Text.link { href = "#/shipping", label = "shipping rules" }
        , Html.text " for details."
        ]

-}
viewWith : List (Attribute msg) -> List (Html msg) -> Html msg
viewWith attributes children =
    let
        config =
            configure attributes

        urgent =
            (config.tone == Danger || config.tone == Warning) && not config.polite
    in
    Html.div
        [ Internal.cls
            [ "klar-alert"
            , "klar-alert--" ++ Internal.toneSuffix config.tone
            , if config.banner then
                "klar-alert--banner"

              else
                ""
            , if config.compact then
                "klar-alert--compact"

              else
                ""
            ]
        , Attr.attribute "role"
            (if urgent then
                "alert"

             else
                "status"
            )
        , Internal.attrMaybe Attr.id config.id
        , Internal.attrMaybe (\_ -> Attr.tabindex -1) config.id
        ]
        [ Html.span [ Internal.cls [ "klar-alert__icon" ] ]
            [ Icon.sized Icon.Medium (Maybe.withDefault (defaultIcon config.tone) config.icon) ]
        , Html.div [ Internal.cls [ "klar-alert__content" ] ]
            [ Internal.viewMaybe (\t -> Html.div [ Internal.cls [ "klar-alert__title" ] ] [ Html.text t ]) config.title
            , Html.div [ Internal.cls [ "klar-alert__message" ] ] children
            , Internal.viewIf (not (List.isEmpty config.actions))
                (Html.div [ Internal.cls [ "klar-alert__actions" ] ] config.actions)
            ]
        , case config.onDismiss of
            Just msg ->
                let
                    close =
                        Locale.pick config.locale { nb = "Lukk", en = "Close" }

                    closeLabel =
                        case Maybe.andThen Internal.nonEmpty config.title of
                            Just text ->
                                close ++ ": " ++ text

                            Nothing ->
                                close
                in
                Html.button
                    [ Internal.cls [ "klar-alert__close" ]
                    , Attr.type_ "button"
                    , Attr.attribute "aria-label" closeLabel
                    , Attr.title closeLabel
                    , Events.onClick msg
                    ]
                    [ Icon.view Icon.close ]

            Nothing ->
                Html.text ""
        ]


{-| One notice for a page whose data is old because a refresh failed, so that
nobody reads old numbers by mistake. Give it the names of the stale parts
(`Remote.staleIn` makes them) and the message that tries again. With no names it
shows nothing.

    Alert.stale [ Alert.locale model.locale ]
        Refresh
        (List.concat
            [ Remote.staleIn "orders" model.orders
            , Remote.staleIn "figures" model.summary
            ]
        )

The notice is a warning that screen readers announce politely, and the names
are joined as a list in the locale ("orders and figures"). The attributes that
make sense here are `locale`, `banner`, `compact`, `id` and `onDismiss`; the
tone, the title, the icon and the actions are set by the notice. When the
refresh works, the notice goes away with its "Try again" button, which may have
the keyboard focus: move it to the data that came back (`Klar.focus`).

-}
stale : List (Attribute msg) -> msg -> List String -> Html msg
stale attributes retry names =
    if List.isEmpty names then
        Html.text ""

    else
        let
            config =
                configure attributes

            pick nb en =
                Locale.pick config.locale { nb = nb, en = en }
        in
        view
            (attributes
                ++ [ tone Warning
                   , title (pick "Noen data er utdaterte" "Some data is out of date")
                   , polite
                   , actions [ Button.view [ Button.small, Button.icon Icon.refresh, Button.onClick retry ] (pick "Prøv igjen" "Try again") ]
                   ]
            )
            (pick "Siste oppdatering feilet. Viser forrige data for: " "The last refresh failed. Showing the previous data for: "
                ++ joinNames (pick "og" "and") names
                ++ "."
            )


{-| "a", "a and b", "a, b and c".
-}
joinNames : String -> List String -> String
joinNames and names =
    case List.reverse names of
        [] ->
            ""

        [ only ] ->
            only

        last :: rest ->
            String.join ", " (List.reverse rest) ++ " " ++ and ++ " " ++ last


defaultIcon : Tone -> Icon
defaultIcon value =
    case value of
        Neutral ->
            Icon.info

        Primary ->
            Icon.info

        Info ->
            Icon.info

        Success ->
            Icon.checkCircle

        Warning ->
            Icon.warning

        Danger ->
            Icon.errorCircle
