module Klar.StatusPage exposing
    ( view
    , Kind, success, notFound, denied, sessionExpired, serverError, offline, maintenance, fromProblem
    , Attribute, title, description, icon, actions, reference, onRetry
    , headingLevel, standalone, id, locale
    , focusTitle
    )

{-| A page that stands for a whole result: "Order created", "No access", "Page
not found", "Something went wrong on our side", "Down for maintenance".

    import Klar.Button as Button
    import Klar.StatusPage as StatusPage

    -- the router found nothing for the address
    StatusPage.view
        [ StatusPage.actions [ Button.view [ Button.primary, Button.href "#/orders" ] "Go to orders" ] ]
        StatusPage.notFound

    -- the data of the page failed to load: the page follows the kind of the problem
    case model.order of
        Failure problem ->
            StatusPage.view
                [ StatusPage.onRetry ReloadOrder
                , StatusPage.reference "req-7f3a-91c2"
                ]
                (StatusPage.fromProblem problem)

        _ ->
            viewOrder model

    -- a form was submitted and the result replaces it
    StatusPage.view
        [ StatusPage.title "Order 1042 created"
        , StatusPage.description "A confirmation was sent to ada@example.com."
        , StatusPage.actions [ Button.view [ Button.href "#/orders/1042" ] "Open the order" ]
        ]
        StatusPage.success

It is the whole-page version of [Klar.EmptyState](Klar-EmptyState) and
[Klar.ErrorState](Klar-ErrorState): use those inside a table, a card or a panel,
and this when the result is the page. The page is centered, with a large calm
title, a sentence under it and a row of actions that you give as buttons. The
kind of page (`notFound`, `denied`, `serverError` ...) chooses the icon, the color
and the built-in texts, in English and Norwegian Bokmål (see `locale`); `title`
and `description` replace them. The kinds are values of an opaque type, so that
more can be added later.


# Semantics

The title is the `h1` of the page. Use `headingLevel` when the page sits in a
layout that already has one (a panel under a page header, say). There is no
`role` and no live region: a page that appears when the user navigates is
content, announced by the navigation itself (the application moves focus to the
content, see `AppShell.focusContent`, and changes the document title), and
`role="alert"` would interrupt a screen reader in the middle of a sentence for
something the user asked for. A live region that
is inserted together with its text is also announced by too few screen readers
to rely on.

When the page replaces what the user was looking at without a navigation (the
form that was just submitted, a list that failed to load), the focused button is
gone with it and focus falls to the page body, so nothing is read. Give the page an
`id` and, in the same `update` that shows it, call `focusTitle` with the same text:
the title takes focus and the screen reader reads the result. Keep the text in one
place, a value of your own, so that the two cannot differ; `focusTitle` does nothing
when no element has the id.

    orderCreated : String
    orderCreated =
        "order-created"

    StatusPage.view [ StatusPage.id orderCreated ] StatusPage.success

    StatusPage.focusTitle orderCreated NoOp

The page fills the height of the region it is in (the content of an `AppShell`, a
panel with a height) without making it scroll, and grows when its content needs
more room. A page that stands on its own, with no shell around it, is `standalone`:
it is as tall as the window and is the `main` landmark.

A `reference` is a correlation id that support can find in a log. Copying to the
clipboard needs JavaScript, so the reference is a monospace line that one click
selects completely (`user-select: all`); then `Ctrl C` copies it.


# View

@docs view


# Kinds of pages

@docs Kind, success, notFound, denied, sessionExpired, serverError, offline, maintenance, fromProblem


# Content

@docs Attribute, title, description, icon, actions, reference, onRetry


# Structure and text

@docs headingLevel, standalone, id, locale


# Focus

@docs focusTitle

-}

import Html exposing (Html)
import Html.Attributes as Attr
import Klar.Button as Button
import Klar.Icon as Icon exposing (Icon)
import Klar.Internal as Internal
import Klar.Locale as Locale exposing (Locale)
import Klar.Remote as Remote exposing (Problem)



-- KINDS


{-| What the page is about. Make one with `success`, `notFound`, `denied`,
`sessionExpired`, `serverError`, `offline`, `maintenance` or, for a failed
request, `fromProblem`, and give it to `view`. The type is opaque, so that new
kinds can be added without breaking anyone.
-}
type Kind
    = Success
    | NotFound
    | Maintenance
    | FromProblem Problem


{-| The action went through: "Order created". A green check, the title "Done" and
a short sentence; you will usually set your own `title` and `description`.
-}
success : Kind
success =
    Success


{-| The address matches nothing (404): "Page not found". A search icon in a
quiet gray. For a single record that is missing, use `fromProblem` with
`Remote.notFound` so that the texts of the problem are used.
-}
notFound : Kind
notFound =
    NotFound


{-| The user may not see this (403): "No access", and the advice to contact an
administrator. A lock in a quiet gray. It is `fromProblem` for a
`Remote.forbidden` problem.
-}
denied : Kind
denied =
    FromProblem (Remote.problem Remote.forbidden)


{-| The user has to sign in again (401): "Please sign in again". It is
`fromProblem` for a `Remote.unauthorized` problem. Give it a sign-in button
as an action.
-}
sessionExpired : Kind
sessionExpired =
    FromProblem (Remote.problem Remote.unauthorized)


{-| The server failed (500): "Something went wrong on our side", in red. It is
`fromProblem` for a `Remote.server` problem, and worth trying again (`onRetry`).
-}
serverError : Kind
serverError =
    FromProblem (Remote.problem Remote.server)


{-| There is no contact with the server: "Can't reach the service". It is
`fromProblem` for a `Remote.network` problem, and worth trying again
(`onRetry`).
-}
offline : Kind
offline =
    FromProblem (Remote.problem Remote.network)


{-| The service is down on purpose: "Down for maintenance", with a wrench. Worth
trying again (`onRetry`) in a few minutes.
-}
maintenance : Kind
maintenance =
    Maintenance


{-| The page for a failed request. The icon and the color follow the kind of the
problem (see [`Remote.Kind`](Klar-Remote#Kind)); the title, the explanation and
the code are the problem's own, which are the ready-made texts for its kind in
the language of the page unless you changed them with `Remote.withTitle` and
friends. The code, when the problem has one, is shown with the reference.
`onRetry` adds a "Try again" button for problems worth trying again.

    StatusPage.fromProblem (Remote.problem Remote.notFound |> Remote.withTitle "Order not found")

-}
fromProblem : Problem -> Kind
fromProblem problem =
    FromProblem problem



-- ATTRIBUTES


{-| A setting of a status page. Make them with the functions below and pass a
list to `view`; later attributes win over earlier ones.
-}
type Attribute msg
    = Attribute (Config msg -> Config msg)


type alias Config msg =
    { title : Maybe String
    , description : Maybe String
    , icon : Maybe Icon
    , actions : List (Html msg)
    , reference : Maybe String
    , onRetry : Maybe msg
    , headingLevel : Int
    , standalone : Bool
    , id : Maybe String
    , locale : Locale
    }


configure : List (Attribute msg) -> Config msg
configure attributes =
    List.foldl (\(Attribute change) config -> change config)
        { title = Nothing
        , description = Nothing
        , icon = Nothing
        , actions = []
        , reference = Nothing
        , onRetry = Nothing
        , headingLevel = 1
        , standalone = False
        , id = Nothing
        , locale = Locale.default
        }
        attributes


{-| The large title, replacing the one of the kind. A blank title leaves out the
heading altogether, so then another element of the page must be its `h1`.
-}
title : String -> Attribute msg
title value =
    Attribute (\config -> { config | title = Just value })


{-| The sentence under the title, replacing the one of the kind. A blank text
leaves it out.
-}
description : String -> Attribute msg
description value =
    Attribute (\config -> { config | description = Just value })


{-| Another icon than the one of the kind, for example `Icon.package` on a
success page that is about a shipment. The color still follows the kind.
-}
icon : Icon -> Attribute msg
icon value =
    Attribute (\config -> { config | icon = Just value })


{-| The row of actions under the text: buttons or links, in the order you give
them, the most important first. There are none by default. A page nearly always
needs one, so that the user is never left in a dead end.

    StatusPage.actions
        [ Button.view [ Button.primary, Button.href "#/orders" ] "Go to orders"
        , Button.view [ Button.href "#/" ] "Home"
        ]

-}
actions : List (Html msg) -> Attribute msg
actions value =
    Attribute (\config -> { config | actions = value })


{-| A correlation id for support, such as the id of the failed request, shown
small under the actions as "Reference: req-7f3a-91c2". The text is selected
completely by one click, so that `Ctrl C` copies it (a button that copies needs
JavaScript). There is none by default, and a blank one is left out, like a blank
title.
-}
reference : String -> Attribute msg
reference value =
    Attribute (\config -> { config | reference = Just value })


{-| The message sent by a "Try again" button, placed before your own actions. The
button is there only when trying again can help: for `serverError`, `offline`,
`maintenance` and a `fromProblem` page whose problem is worth retrying
(`Remote.isRetryable`), and never for the others. Without `onRetry` there is no
button.
-}
onRetry : msg -> Attribute msg
onRetry msg =
    Attribute (\config -> { config | onRetry = Just msg })


{-| The level of the title element, from 1 to 6. The default is 1, because the
page is normally the whole page. Use another level when the page sits inside a
layout that already has an `h1`. A number outside the range counts as the nearest
level. The level changes the element, not the look.
-}
headingLevel : Int -> Attribute msg
headingLevel level =
    Attribute (\config -> { config | headingLevel = clamp 1 6 level })


{-| The page stands on its own, with no `AppShell` around it: it is at least as
tall as the window and it is the `main` landmark of the document. Without it the
page fills the region it is placed in and is an ordinary `div`.
-}
standalone : Attribute msg
standalone =
    Attribute (\config -> { config | standalone = True })


{-| The DOM id of the element that `focusTitle` moves focus to, which must be unique
on the page: the title, which becomes focusable, or the whole page when it has no
title (a blank `title`), so that there is always something to focus. Give `focusTitle`
the same text. There is no id by default, and without one `focusTitle` finds nothing
and does nothing.
-}
id : String -> Attribute msg
id value =
    Attribute (\config -> { config | id = Just value })


{-| The language of the built-in text: the texts of the kinds, "Try again" and
the label of the reference. The default is [`Locale.default`](Klar-Locale#default),
which is English. The title and the explanation of a `fromProblem` page come from
the problem, in this language.
-}
locale : Locale -> Attribute msg
locale value =
    Attribute (\config -> { config | locale = value })



-- FOCUS


{-| Moves focus to the title of the page that has this `id` (the page itself when it
has no title; see the attribute `id`). Pass the same text as to `id`: if no element
has it, nothing happens. Call it in the same `update` that starts to show the page,
when the page replaces what the user was working with. The message is sent when it is
done, whether it worked or not.

    StatusPage.focusTitle "order-created" NoOp

-}
focusTitle : String -> msg -> Cmd msg
focusTitle pageId done =
    Internal.focus pageId done



-- VIEW


{-| The page: an icon, the title, a sentence, the actions and the reference,
centered in the region.

    StatusPage.view [ StatusPage.actions [ homeButton ] ] StatusPage.denied

-}
view : List (Attribute msg) -> Kind -> Html msg
view attributes kind =
    let
        config =
            configure attributes

        facts =
            describe config.locale kind

        shownTitle =
            Maybe.withDefault facts.title config.title

        shownDescription =
            case config.description of
                Just own ->
                    Internal.nonEmpty own

                Nothing ->
                    facts.description

        retryButton =
            case ( config.onRetry, facts.retryable ) of
                ( Just msg, True ) ->
                    [ Button.view
                        [ Button.icon Icon.refresh, Button.onClick msg ]
                        (Locale.pick config.locale { nb = "Prøv igjen", en = "Try again" })
                    ]

                _ ->
                    []

        buttons =
            retryButton ++ config.actions

        details =
            List.filterMap identity
                [ Maybe.map (\code -> ( Locale.pick config.locale { nb = "Kode", en = "Code" }, code )) (Maybe.andThen Internal.nonEmpty facts.code)
                , Maybe.map (\ref -> ( Locale.pick config.locale { nb = "Referanse", en = "Reference" }, ref )) (Maybe.andThen Internal.nonEmpty config.reference)
                ]

        shownTitleText =
            Internal.nonEmpty shownTitle

        -- The element `focusTitle` finds: the title, or the page when it has none.
        focusable =
            case config.id of
                Just pageId ->
                    [ Attr.id pageId, Attr.tabindex -1 ]

                Nothing ->
                    []

        root =
            if config.standalone then
                Html.main_

            else
                Html.div
    in
    root
        (Internal.cls
            [ "klar-status-page"
            , "klar-status-page--" ++ facts.tone
            , if config.standalone then
                "klar-status-page--standalone"

              else
                ""
            ]
            :: (case shownTitleText of
                    Just _ ->
                        []

                    Nothing ->
                        focusable
               )
        )
        [ Html.span [ Internal.cls [ "klar-status-page__icon" ] ]
            [ Icon.sized Icon.ExtraLarge (Maybe.withDefault facts.icon config.icon) ]
        , case shownTitleText of
            Just text ->
                Internal.heading config.headingLevel
                    (Internal.cls [ "klar-status-page__title" ] :: focusable)
                    [ Html.text text ]

            Nothing ->
                Html.text ""
        , Internal.viewMaybe
            (\text -> Html.p [ Internal.cls [ "klar-status-page__description" ] ] [ Html.text text ])
            shownDescription
        , Internal.viewIf (not (List.isEmpty buttons))
            (Html.div [ Internal.cls [ "klar-status-page__actions" ] ] buttons)
        , Internal.viewIf (not (List.isEmpty details))
            (Html.p [ Internal.cls [ "klar-status-page__meta" ] ] (List.map viewDetail details))
        ]


viewDetail : ( String, String ) -> Html msg
viewDetail ( name, value ) =
    Html.span [ Internal.cls [ "klar-status-page__detail" ] ]
        [ Html.span [ Internal.cls [ "klar-status-page__detail-name" ] ] [ Html.text (name ++ ": ") ]
        , Html.code [ Internal.cls [ "klar-status-page__value" ] ] [ Html.text value ]
        ]



-- WHAT A KIND LOOKS LIKE


type alias Facts =
    { icon : Icon
    , tone : String
    , title : String
    , description : Maybe String
    , code : Maybe String
    , retryable : Bool
    }


describe : Locale -> Kind -> Facts
describe language kind =
    case kind of
        Success ->
            { icon = Icon.checkCircle
            , tone = "success"
            , title = Locale.pick language { nb = "Ferdig", en = "Done" }
            , description = Just (Locale.pick language { nb = "Handlingen er gjennomført.", en = "The action was completed." })
            , code = Nothing
            , retryable = False
            }

        NotFound ->
            { icon = Icon.search
            , tone = "neutral"
            , title = Locale.pick language { nb = "Fant ikke siden", en = "Page not found" }
            , description =
                Just
                    (Locale.pick language
                        { nb = "Siden finnes ikke eller er flyttet. Sjekk adressen, eller gå tilbake."
                        , en = "The page doesn't exist or has moved. Check the address, or go back."
                        }
                    )
            , code = Nothing
            , retryable = False
            }

        Maintenance ->
            { icon = Icon.wrench
            , tone = "warning"
            , title = Locale.pick language { nb = "Under vedlikehold", en = "Down for maintenance" }
            , description =
                Just
                    (Locale.pick language
                        { nb = "Vi gjør forbedringer og er snart tilbake. Prøv igjen om noen minutter."
                        , en = "We are making improvements and will be back shortly. Try again in a few minutes."
                        }
                    )
            , code = Nothing
            , retryable = True
            }

        FromProblem problem ->
            { icon = iconFor (Remote.kind problem)
            , tone = toneFor (Remote.kind problem)
            , title = Remote.title language problem
            , description = Remote.detail language problem
            , code = Remote.code problem
            , retryable = Remote.isRetryable problem
            }


iconFor : Remote.Kind -> Icon
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


{-| Not finding or not being allowed is no failure of the system: it stays gray.
Losing contact is a warning, and a server that fails is red.
-}
toneFor : Remote.Kind -> String
toneFor kind =
    if kind == Remote.notFound || kind == Remote.forbidden || kind == Remote.unauthorized then
        "neutral"

    else if kind == Remote.network || kind == Remote.timeout || kind == Remote.validation || kind == Remote.conflict then
        "warning"

    else
        "danger"
