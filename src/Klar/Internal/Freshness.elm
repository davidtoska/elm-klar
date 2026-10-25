module Klar.Internal.Freshness exposing
    ( Freshness(..), settle, waiting
    , Config, region, wrap, notice, noticeSaying, announcement
    , busy, busyAttr, className, text
    )

{-| What every data component shows for a `Remote.Kept`: data that is being
refreshed (dimmed, busy) and data that is old because the last refresh failed (a
calm marker with the time, the reason and a retry). The component settles its
`Remote` once (`settle` turns `Kept` into `Loaded`) and draws the rest as it always
did.

The one way to draw it is `wrap`, around the content of the `Loaded` state whatever
its freshness:

    case Freshness.settle remote of
        ( Remote.Loaded rows, freshness ) ->
            Freshness.wrap
                { locale = config.locale, settings = config.settings, onRetry = config.onRetry, inline = False }
                [ Internal.cls [ "klar-list-fresh" ] ]
                freshness
                [ viewRows rows ]

        ( Remote.Failed problem, _ ) ->
            ...

`wrap` draws the same elements in every state (fresh, refreshing, old), so a refresh
that starts or ends never replaces the content and the keyboard focus inside it stays
where it is. Its first child is a slot that is always there, with a polite live
region whose text changes when the data turns old, which a screen reader announces
(a live region that is inserted together with its text is often not announced).

A small inline marker (`inline = True`: a `Klar.Stat` tile, a lazy branch of
`Klar.Tree`) is not a live region, because a page with many of them would speak once
per tile: such a component announces nothing, and the page that shows it says it once
with `Alert.stale`.

In a popup that closes on Tab (a select, a picker), a retry button is out of reach of
the keyboard: Tab closes the popup and the button with it. Such a popup gives the
keyboard its own way to retry, a row of its own list that the arrow keys reach;
the marker cannot draw that row for it.


# Settle

@docs Freshness, settle, waiting


# Draw

@docs Config, region, wrap, notice, noticeSaying, announcement


# Parts

@docs busy, busyAttr, className, text

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


{-| How fresh the shown data is: fresh, being refreshed, or old because the last
refresh failed (with the reason, the time of the data, and whether a retry is on
its way).
-}
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



-- DRAW


{-| What the marker needs: the locale and the settings of the component (the time
is written in the zone of the settings), the retry message (`Nothing`, or a problem
that retrying cannot fix, draws no button), and whether the marker is the small
inline pill (`True`: a tile, a branch of a tree) or the strip above the content.
-}
type alias Config msg =
    { locale : Locale
    , settings : Settings
    , onRetry : Maybe msg
    , inline : Bool
    }


{-| The content of a component with its freshness around it: a `div` with the
given attributes (the component's own classes go here), dimmed and `aria-busy`
while a refresh is on its way, whose first child is the slot of the marker and
whose other children are the content. The elements are the same in every state, so
a refresh that starts or ends keeps the content, and the focus in it. Draw it in the
`Loaded` state whatever the freshness, not only when the data is old.
-}
wrap : Config msg -> List (Html.Attribute msg) -> Freshness -> List (Html msg) -> Html msg
wrap config attributes freshness content =
    Html.div
        (Internal.cls [ "klar-fresh", className freshness ]
            :: busyAttr freshness
            :: attributes
        )
        (notice config freshness :: content)


{-| The root of a component that shows remote data, the same element in every state
(loading, failed, data): it carries the component's id and `tabindex` -1, so that
`Klar.focus id` after a Try again, whose button goes away with the failure, lands on
the component and not on `body`. For a component that has an id and a retry that
goes away; a component without an id uses `wrap` alone. A root with `tabindex` -1
also takes the focus from a mouse press on a part of it that is not a control
(without a ring: the ring of Base is for the keyboard), and a screen reader that
lands on it reads it whole. Its first child is a polite live region that is
always there, with the text the component gives for the state (`"Loading events"`
while loading, `""` once the data is there), so the change is announced; a live region
that comes in together with its text often is not. The component's own classes and
attributes go in the list; `wrap` goes inside it, around the data.

    Freshness.region config.id
        [ Internal.cls [ "klar-timeline" ] ]
        (if Freshness.waiting remote then
            t.loadingEvents

         else
            ""
        )
        (case Freshness.settle remote of
            ( Remote.Loaded events, freshness ) ->
                [ Freshness.wrap Freshness.InPage noticeConfig [] freshness (viewEvents events) ]

            ( Remote.Failed problem, _ ) ->
                [ viewFailure problem ]

            _ ->
                [ viewSkeleton ]
        )

-}
region : String -> List (Html.Attribute msg) -> String -> List (Html msg) -> Html msg
region id attributes spoken children =
    Html.div (Attr.id id :: Attr.tabindex -1 :: Internal.cls [ "klar-region" ] :: attributes)
        (Html.span [ Internal.cls [ "klar-sr-only" ], Attr.attribute "role" "status" ] [ Html.text spoken ]
            :: children
        )


{-| The marker on its own, for a component that draws the box around its content
itself: the same slot that `wrap` puts first. Draw it in every state of the data
(also when it is fresh, where it is an empty live region), so the live region is
there before its text changes.
-}
notice : Config msg -> Freshness -> Html msg
notice config freshness =
    noticeSaying config (announcement config.locale config.settings freshness) freshness


{-| The marker of `notice`, whose live region says the given text instead of the
`announcement`: for a component whose one live region also says what the marker
does not, such as "Loading" while there is no data yet. Give it the `announcement`
once there is data, so that old data is still said. The elements are those of
`notice` in every state, so the live region is there before its text changes.
-}
noticeSaying : Config msg -> String -> Freshness -> Html msg
noticeSaying config spoken freshness =
    Html.div [ Internal.cls [ "klar-fresh__slot" ] ]
        [ if config.inline then
            Html.text ""

          else
            Html.span
                [ Internal.cls [ "klar-sr-only" ]
                , Attr.attribute "role" "status"
                ]
                [ Html.text spoken ]
        , case freshness of
            Stale value ->
                marker config value

            _ ->
                Html.text ""
        ]


{-| What the live region of the marker says: "Old data from 14:05. Refresh failed:
Can't reach the service." for old data, and nothing for fresh or refreshing data (a
refresh says it with `aria-busy`). For a component that has a live region of its
own, which should say it instead of a second one.
-}
announcement : Locale -> Settings -> Freshness -> String
announcement locale settings freshness =
    case freshness of
        Stale value ->
            sentence (text locale settings value.at) ++ " " ++ sentence (failedText locale value.problem)

        _ ->
            ""


{-| A text that ends with a full stop, unless it ends with one already (or with
another mark that ends a sentence, as a title the application gives may).
-}
sentence : String -> String
sentence raw =
    let
        trimmed =
            String.trimRight raw
    in
    if List.any (\mark -> String.endsWith mark trimmed) [ ".", "!", "?", "…" ] then
        trimmed

    else
        trimmed ++ "."


marker : Config msg -> { problem : Problem, at : Maybe Time.Posix, refreshing : Bool } -> Html msg
marker config value =
    let
        full =
            case value.at of
                Just at ->
                    Settings.dateTime (Settings.withLocale config.locale config.settings) at

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
        , Attr.title (String.trim (Remote.title config.locale value.problem ++ " " ++ full))
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
            [ Html.text ("· " ++ failedText config.locale value.problem) ]
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


{-| "Refresh failed: Can't reach the service".
-}
failedText : Locale -> Problem -> String
failedText locale problem =
    Locale.pick locale { nb = "Oppdateringen feilet: ", en = "Refresh failed: " } ++ Remote.title locale problem



-- PARTS


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
