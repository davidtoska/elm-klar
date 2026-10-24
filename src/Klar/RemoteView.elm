module Klar.RemoteView exposing
    ( view
    , Attribute, onRetry, id, loadingLabel, skeleton, emptyState, locale, settings
    )

{-| The body of a card, a dialog or a drawer that shows one piece of remote data:
a loading skeleton that screen readers hear, the failure with a retry, nothing to
show, and the data, old or being refreshed. You write only what the data looks like.

Use when: the body of a card, a dialog or a drawer shows one piece of remote data.
Do not use when: the data is a table or a list (use `Klar.Table` or `Klar.ListItem`, which take a `Remote` themselves).
Quick path: `view` with `onRetry`; `id` for focus after a retry, `emptyState` for an empty answer

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

`NotAsked` and `Loading` show a skeleton, with a polite "Loading" for screen readers
(`loadingLabel` says what is loading). `Failed` shows the problem with a "Try again"
button (`onRetry`) when trying again can help. The data calls your function, and when
your function returns no nodes at all the body says "Nothing to show"
(`emptyState` says it your way). Data that is `Kept` ([Klar.Remote](Klar-Remote)) stays
on the screen: dimmed and busy while it is refreshed, and with "Old data from 14:05"
and a retry when the last refresh failed.

**One element in every state.** The body is always one `div` that holds a live region
and then the content of the state, so that a refresh never rebuilds your nodes: a
button inside the body that starts a refresh keeps focus while the refresh is on its
way and when it ends, and so do the caret of a field, an open `<details>` and the
scroll position of an inner pane. The live region is the same element from loading to
data, and only its text changes, which is what screen readers announce reliably.

The body is a list with that one node, so it fits wherever a list of children goes:
the body of a `Card`, a `Modal` or a `Drawer`, or any `Html.div`. Inside, the content
is a column with the small gap of the library. When the data replaces a failure, the
"Try again" button that had focus is gone: inside a `Modal` or `Drawer` focus goes back
into the dialog by itself; in a `Card` or on a page it falls to the page, unless the body
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

@docs Attribute, onRetry, id, loadingLabel, skeleton, emptyState, locale, settings

-}

import Html exposing (Html)
import Html.Attributes as Attr
import Klar.EmptyState as EmptyState
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
    , emptyState : List (EmptyState.Attribute msg)
    , locale : Locale
    , settings : Settings
    }


configure : List (Attribute msg) -> Config msg
configure attributes =
    List.foldl (\(Attribute change) config -> change config)
        { onRetry = Nothing
        , id = Nothing
        , loadingLabel = Nothing
        , skeleton = Nothing
        , emptyState = []
        , locale = Locale.default
        , settings = Settings.default
        }
        attributes


{-| The message sent by the "Try again" button, in the failure and in the marker
of old data. The button is only shown for problems worth retrying (see
`Remote.isRetryable`).
-}
onRetry : msg -> Attribute msg
onRetry msg =
    Attribute (\config -> { config | onRetry = Just msg })


{-| The DOM id of the body, which must be unique on the page. The body is one element
in every state (loading, failed, nothing to show, old data, data); with an id it can
take focus, so that `Klar.focus` has a place to put it. There is no id by default.
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


{-| What the body shows when the data is there but your function draws nothing for
it (returns `[]`): an [Klar.EmptyState](Klar-EmptyState). The default is a compact
one that says "Nothing to show"; your attributes are applied after it, so yours win.
Return `[]` for an empty result and let the body say so:

    RemoteView.view
        [ RemoteView.emptyState [ EmptyState.title "No notes yet", EmptyState.action addNoteButton ] ]
        model.notes
        (List.map viewNote)

-}
emptyState : List (EmptyState.Attribute msg) -> Attribute msg
emptyState attributes =
    Attribute (\config -> { config | emptyState = attributes })


{-| The settings of the application (`Klar.Settings`): the time zone of the time in
"Old data from 14:05". Without it the time is written in UTC and ends in "UTC".

    RemoteView.settings model.settings

-}
settings : Settings -> Attribute msg
settings given =
    Attribute (\config -> { config | settings = given })


{-| The language of the built-in text ("Loading", "Try again", "Old data from",
"Nothing to show"). The default is `Locale.default`, which is English.
-}
locale : Locale -> Attribute msg
locale value =
    Attribute (\config -> { config | locale = value })


{-| The body for a `Remote`: the skeleton, the failure, the empty state, or what your
function makes of the data. The result is a list with one element, the same element in
every state.
-}
view : List (Attribute msg) -> Remote a -> (a -> List (Html msg)) -> List (Html msg)
view attributes data toBody =
    let
        config =
            configure attributes

        ( settled, freshness ) =
            Freshness.settle data

        -- The one element of every state: the same tag, the live region first and the
        -- content after it, so that Elm patches it in place from one state to the next.
        wrap modifiers busy announced content =
            [ Html.div
                [ Internal.cls ("klar-remote-body" :: modifiers)
                , busy
                , Internal.attrMaybe Attr.id config.id
                , Internal.attrIf (config.id /= Nothing) (Attr.tabindex -1)
                ]
                (Html.span [ Internal.cls [ "klar-sr-only" ], Attr.attribute "role" "status" ] [ Html.text announced ]
                    :: content
                )
            ]
    in
    case settled of
        Remote.Loaded value ->
            -- The marker is one node in every state (empty text while the data is
            -- fresh), so the nodes of the body keep their places when it comes and goes.
            wrap [ Freshness.className freshness ]
                (Freshness.busyAttr freshness)
                ""
                (Freshness.notice
                    { locale = config.locale, settings = config.settings, onRetry = config.onRetry, inline = False }
                    freshness
                    :: (case toBody value of
                            [] ->
                                [ EmptyState.view
                                    (EmptyState.compact
                                        :: EmptyState.title (Locale.pick config.locale { nb = "Ingenting å vise", en = "Nothing to show" })
                                        :: config.emptyState
                                    )
                                ]

                            nodes ->
                                nodes
                       )
                )

        Remote.Failed problem ->
            wrap []
                Internal.noAttr
                ""
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
            -- Busy is the placeholder, never an element around the live region: a
            -- screen reader may hold back what a busy region says.
            wrap [ "klar-remote-body--loading" ]
                Internal.noAttr
                (Maybe.withDefault (Locale.pick config.locale { nb = "Laster", en = "Loading" }) config.loadingLabel)
                [ Html.div [ Internal.cls [ "klar-remote-body" ], Attr.attribute "aria-busy" "true" ]
                    (case config.skeleton of
                        Just html ->
                            [ html ]

                        Nothing ->
                            [ Skeleton.line 45
                            , Skeleton.paragraph 3
                            ]
                    )
                ]
