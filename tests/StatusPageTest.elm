module StatusPageTest exposing (suite)

{-| Klar.StatusPage: the page for each kind, its texts in two languages, the one
heading, the absence of any live region, the retry button and the focus target.
-}

import Expect
import Fuzz
import Html exposing (Html)
import Html.Attributes as Attr
import Klar.Button as Button
import Klar.Icon as Icon
import Klar.Locale as Locale
import Klar.Remote as Remote
import Klar.Settings as Settings
import Klar.StatusPage as StatusPage exposing (Kind)
import Support.FlowHtml as H
import Test exposing (Test, describe, fuzz, test)
import Test.Html.Event as Event
import Test.Html.Query as Query
import Test.Html.Selector as Selector exposing (Selector)
import Time


type Msg
    = Retry
    | Home
    | Done


suite : Test
suite =
    describe "Klar.StatusPage"
        [ kindTests
        , textTests
        , headingTests
        , semanticsTests
        , actionTests
        , referenceTests
        , retryTests
        , problemTests
        , iconAndToneTests
        , focusTests
        , retryingAndBackTests
        ]


page : List (StatusPage.Attribute Msg) -> Kind -> Html Msg
page =
    StatusPage.view


heading : Selector
heading =
    Selector.class "klar-status-page__title"


allKinds : List ( String, Kind )
allKinds =
    [ ( "success", StatusPage.success )
    , ( "pageNotFound", StatusPage.pageNotFound )
    , ( "forbidden", StatusPage.forbidden )
    , ( "unauthorized", StatusPage.unauthorized )
    , ( "server", StatusPage.server )
    , ( "network", StatusPage.network )
    , ( "maintenance", StatusPage.maintenance )
    ]



-- THE KINDS


kindTests : Test
kindTests =
    describe "kinds"
        [ describe "every kind has a title and a sentence, in English"
            (List.map
                (\( name, kind ) ->
                    test name <|
                        \_ ->
                            page [] kind
                                |> Expect.all
                                    [ H.count 1 [ Selector.tag "h1" ]
                                    , H.count 1 [ Selector.class "klar-status-page__description" ]
                                    ]
                )
                allKinds
            )
        , describe "and in Norwegian"
            (List.map
                (\( name, kind ) ->
                    test name <|
                        \_ ->
                            page [ StatusPage.locale Locale.nb ] kind
                                |> Expect.all
                                    [ H.count 1 [ Selector.tag "h1" ]
                                    , H.count 1 [ Selector.class "klar-status-page__description" ]
                                    ]
                )
                allKinds
            )
        , test "the English title of each kind" <|
            \_ ->
                [ ( StatusPage.success, "Done" )
                , ( StatusPage.pageNotFound, "Page not found" )
                , ( StatusPage.forbidden, "No access" )
                , ( StatusPage.unauthorized, "Please sign in again" )
                , ( StatusPage.server, "Something went wrong on our side" )
                , ( StatusPage.network, "Can't reach the service" )
                , ( StatusPage.maintenance, "Down for maintenance" )
                ]
                    |> List.map (\( kind, text ) -> \_ -> page [] kind |> H.inside [ heading ] [ Selector.text text ])
                    |> (\checks -> Expect.all checks ())
        , test "the Norwegian title of each kind" <|
            \_ ->
                [ ( StatusPage.success, "Ferdig" )
                , ( StatusPage.pageNotFound, "Fant ikke siden" )
                , ( StatusPage.forbidden, "Ingen tilgang" )
                , ( StatusPage.unauthorized, "Du må logge inn på nytt" )
                , ( StatusPage.server, "Noe gikk galt hos oss" )
                , ( StatusPage.network, "Ingen kontakt med tjenesten" )
                , ( StatusPage.maintenance, "Under vedlikehold" )
                ]
                    |> List.map (\( kind, text ) -> \_ -> page [ StatusPage.locale Locale.nb ] kind |> H.inside [ heading ] [ Selector.text text ])
                    |> (\checks -> Expect.all checks ())
        , test "denied, sessionExpired, serverError and offline are the problems of their kind" <|
            \_ ->
                Expect.all
                    [ \_ -> Expect.equal StatusPage.forbidden (StatusPage.fromProblem (Remote.problem Remote.forbidden))
                    , \_ -> Expect.equal StatusPage.unauthorized (StatusPage.fromProblem (Remote.problem Remote.unauthorized))
                    , \_ -> Expect.equal StatusPage.server (StatusPage.fromProblem (Remote.problem Remote.server))
                    , \_ -> Expect.equal StatusPage.network (StatusPage.fromProblem (Remote.problem Remote.network))
                    ]
                    ()
        ]



-- TEXT


textTests : Test
textTests =
    describe "text"
        [ test "title replaces the title of the kind" <|
            \_ ->
                page [ StatusPage.title "Order 1042 created" ] StatusPage.success
                    |> Expect.all
                        [ H.inside [ heading ] [ Selector.text "Order 1042 created" ]
                        , H.none [ Selector.text "Done" ]
                        ]
        , test "description replaces the sentence of the kind" <|
            \_ ->
                page [ StatusPage.description "We sent a confirmation." ] StatusPage.success
                    |> Expect.all
                        [ H.inside [ Selector.class "klar-status-page__description" ] [ Selector.text "We sent a confirmation." ]
                        , H.none [ Selector.text "The action was completed." ]
                        ]
        , test "a blank title leaves out the heading" <|
            \_ ->
                page [ StatusPage.title "   " ] StatusPage.pageNotFound
                    |> Expect.all
                        [ H.none [ heading ]
                        , H.none [ Selector.tag "h1" ]
                        ]
        , test "a blank description leaves out the sentence" <|
            \_ -> page [ StatusPage.description "" ] StatusPage.pageNotFound |> H.none [ Selector.class "klar-status-page__description" ]
        , test "later attributes win" <|
            \_ ->
                page [ StatusPage.title "First", StatusPage.title "Second" ] StatusPage.pageNotFound
                    |> H.inside [ heading ] [ Selector.text "Second" ]
        , test "the order of the attributes does not matter" <|
            \_ ->
                let
                    same html =
                        html
                            |> Expect.all
                                [ H.inside [ Selector.tag "h2" ] [ Selector.text "A" ]
                                , H.inside [ Selector.class "klar-status-page__value" ] [ Selector.text "r" ]
                                , H.has [ Selector.tag "main" ]
                                ]
                in
                Expect.all
                    [ \_ -> same (page [ StatusPage.title "A", StatusPage.headingLevel 2, StatusPage.reference "r", StatusPage.standalone ] StatusPage.success)
                    , \_ -> same (page [ StatusPage.standalone, StatusPage.reference "r", StatusPage.headingLevel 2, StatusPage.title "A" ] StatusPage.success)
                    ]
                    ()
        ]



-- HEADING


headingTests : Test
headingTests =
    describe "the heading"
        [ test "there is exactly one h1 by default" <|
            \_ -> page [] StatusPage.pageNotFound |> H.count 1 [ Selector.tag "h1" ]
        , test "and no other heading" <|
            \_ ->
                page [] StatusPage.pageNotFound
                    |> Expect.all
                        [ H.none [ Selector.tag "h2" ]
                        , H.none [ Selector.tag "h3" ]
                        ]
        , test "headingLevel 2 gives an h2 and no h1" <|
            \_ ->
                page [ StatusPage.headingLevel 2 ] StatusPage.pageNotFound
                    |> Expect.all
                        [ H.count 1 [ Selector.tag "h2" ]
                        , H.none [ Selector.tag "h1" ]
                        ]
        , test "levels outside 1 to 6 count as the nearest" <|
            \_ ->
                Expect.all
                    [ \_ -> page [ StatusPage.headingLevel 0 ] StatusPage.pageNotFound |> H.count 1 [ Selector.tag "h1" ]
                    , \_ -> page [ StatusPage.headingLevel 9 ] StatusPage.pageNotFound |> H.count 1 [ Selector.tag "h6" ]
                    , \_ -> page [ StatusPage.headingLevel -4 ] StatusPage.pageNotFound |> H.count 1 [ Selector.tag "h1" ]
                    ]
                    ()
        , fuzz (Fuzz.intRange -20 20) "any level gives exactly one heading element" <|
            \level ->
                page [ StatusPage.headingLevel level ] StatusPage.server
                    |> H.count 1 [ Selector.class "klar-status-page__title" ]
        , test "the level changes the element and not the class" <|
            \_ -> page [ StatusPage.headingLevel 3 ] StatusPage.pageNotFound |> H.inside [ Selector.tag "h3" ] [ heading ]
        ]



-- SEMANTICS


semanticsTests : Test
semanticsTests =
    describe "semantics"
        [ test "no role and no live region on any kind" <|
            \_ ->
                allKinds
                    |> List.map
                        (\( _, kind ) ->
                            \_ ->
                                page [ StatusPage.onRetry Retry, StatusPage.actions [ Button.view [] "Home" ] ] kind
                                    |> Expect.all
                                        [ H.none [ H.attr "role" "alert" ]
                                        , H.none [ H.attr "role" "status" ]
                                        , H.none [ H.attr "role" "alertdialog" ]
                                        , H.none [ Selector.attribute (Attr.attribute "aria-live" "polite") ]
                                        , H.none [ Selector.attribute (Attr.attribute "aria-live" "assertive") ]
                                        ]
                        )
                    |> (\checks -> Expect.all checks ())
        , test "the root is an ordinary div by default" <|
            \_ -> page [] StatusPage.pageNotFound |> H.has [ Selector.tag "div", Selector.class "klar-status-page" ]
        , test "standalone makes it the main landmark and as tall as the window" <|
            \_ -> page [ StatusPage.standalone ] StatusPage.pageNotFound |> H.has [ Selector.tag "main", Selector.classes [ "klar-status-page", "klar-status-page--standalone" ] ]
        , test "the default has no standalone class" <|
            \_ -> page [] StatusPage.pageNotFound |> H.hasNot [ Selector.class "klar-status-page--standalone" ]
        , test "the icon is hidden from assistive technology" <|
            \_ -> page [] StatusPage.pageNotFound |> H.inside [ Selector.class "klar-status-page__icon" ] [ Selector.containing [ H.attr "aria-hidden" "true" ] ]
        , test "nothing can take focus by itself: no tabindex, no autofocus, no button" <|
            \_ ->
                page [] StatusPage.forbidden
                    |> Expect.all
                        [ H.none [ Selector.attribute (Attr.tabindex -1) ]
                        , H.none [ Selector.attribute (Attr.autofocus True) ]
                        , H.none [ Selector.tag "button" ]
                        ]
        ]



-- ACTIONS


actionTests : Test
actionTests =
    describe "actions"
        [ test "none by default" <|
            \_ -> page [] StatusPage.pageNotFound |> H.none [ Selector.class "klar-status-page__actions" ]
        , test "in the order given" <|
            \_ ->
                let
                    row =
                        page [ StatusPage.actions [ Button.view [ Button.onClick Home ] "Go home", Button.view [ Button.onClick Done ] "Orders" ] ] StatusPage.pageNotFound
                            |> Query.fromHtml
                            |> Query.find [ Selector.class "klar-status-page__actions" ]
                            |> Query.findAll [ Selector.tag "button" ]
                in
                Expect.all
                    [ \_ -> row |> Query.index 0 |> Query.has [ Selector.text "Go home" ]
                    , \_ -> row |> Query.index 1 |> Query.has [ Selector.text "Orders" ]
                    ]
                    ()
        , test "the buttons send their own messages" <|
            \_ ->
                page [ StatusPage.actions [ Button.view [ Button.onClick Home ] "Go home" ] ] StatusPage.pageNotFound
                    |> H.sends [ Selector.tag "button" ] Event.click
                    |> Expect.equal (Ok Home)
        ]



-- REFERENCE


referenceTests : Test
referenceTests =
    describe "reference"
        [ test "none by default" <|
            \_ -> page [] StatusPage.server |> H.none [ Selector.class "klar-status-page__meta" ]
        , test "shown in a monospace value that one click selects" <|
            \_ ->
                page [ StatusPage.reference "req-7f3a-91c2" ] StatusPage.server
                    |> H.inside [ Selector.tag "code", Selector.class "klar-status-page__value" ] [ Selector.text "req-7f3a-91c2" ]
        , test "with a label, in English" <|
            \_ ->
                page [ StatusPage.reference "abc" ] StatusPage.server
                    |> H.inside [ Selector.class "klar-status-page__meta" ] [ Selector.text "Reference: " ]
        , test "and in Norwegian" <|
            \_ ->
                page [ StatusPage.reference "abc", StatusPage.locale Locale.nb ] StatusPage.server
                    |> H.inside [ Selector.class "klar-status-page__meta" ] [ Selector.text "Referanse: " ]
        , test "the code of a problem is shown next to it" <|
            \_ ->
                page [ StatusPage.reference "abc" ] (StatusPage.fromProblem (Remote.problem Remote.server |> Remote.withCode "503"))
                    |> H.count 2 [ Selector.class "klar-status-page__value" ]
        , test "the code is shown without a reference" <|
            \_ ->
                page [] (StatusPage.fromProblem (Remote.problem Remote.server |> Remote.withCode "503"))
                    |> H.inside [ Selector.class "klar-status-page__value" ] [ Selector.text "503" ]
        , test "a blank reference draws nothing, like a blank title" <|
            \_ ->
                Expect.all
                    [ \_ -> page [ StatusPage.reference "" ] StatusPage.server |> H.none [ Selector.class "klar-status-page__meta" ]
                    , \_ -> page [ StatusPage.reference "   " ] StatusPage.server |> H.none [ Selector.class "klar-status-page__meta" ]
                    , \_ -> page [ StatusPage.reference "" ] StatusPage.server |> H.none [ Selector.text "Reference" ]
                    , \_ -> page [ StatusPage.reference "" ] StatusPage.server |> H.none [ Selector.tag "code" ]
                    ]
                    ()
        , test "a blank reference does not hide the code of the problem" <|
            \_ ->
                page [ StatusPage.reference "" ] (StatusPage.fromProblem (Remote.problem Remote.server |> Remote.withCode "503"))
                    |> Expect.all
                        [ H.count 1 [ Selector.class "klar-status-page__value" ]
                        , H.none [ Selector.text "Reference" ]
                        ]
        , test "a blank code of a problem draws nothing either" <|
            \_ ->
                page [] (StatusPage.fromProblem (Remote.problem Remote.server |> Remote.withCode ""))
                    |> H.none [ Selector.class "klar-status-page__meta" ]
        , test "a reference that is a long unbroken word stays inside the meta line" <|
            \_ ->
                page [ StatusPage.reference (String.repeat 200 "x") ] StatusPage.server
                    |> H.count 1 [ Selector.class "klar-status-page__meta" ]
        ]



-- RETRY


retryTests : Test
retryTests =
    let
        retryButton =
            [ Selector.tag "button", Selector.containing [ Selector.text "Try again" ] ]

        offered kind =
            page [ StatusPage.onRetry Retry ] kind |> H.count 1 retryButton

        notOffered kind =
            page [ StatusPage.onRetry Retry ] kind |> H.none [ Selector.tag "button" ]
    in
    describe "retry"
        [ test "offered when trying again can help" <|
            \_ ->
                Expect.all
                    [ \_ -> offered StatusPage.server
                    , \_ -> offered StatusPage.network
                    , \_ -> offered StatusPage.maintenance
                    , \_ -> offered (StatusPage.fromProblem (Remote.problem Remote.timeout))
                    , \_ -> offered (StatusPage.fromProblem (Remote.problem Remote.unknown))
                    ]
                    ()
        , test "not offered when it would fail the same way" <|
            \_ ->
                Expect.all
                    [ \_ -> notOffered StatusPage.success
                    , \_ -> notOffered StatusPage.pageNotFound
                    , \_ -> notOffered StatusPage.forbidden
                    , \_ -> notOffered StatusPage.unauthorized
                    , \_ -> notOffered (StatusPage.fromProblem (Remote.problem Remote.validation))
                    , \_ -> notOffered (StatusPage.fromProblem (Remote.problem Remote.conflict))
                    ]
                    ()
        , test "not offered without onRetry" <|
            \_ -> page [] StatusPage.server |> H.none [ Selector.tag "button" ]
        , test "it sends the message" <|
            \_ -> page [ StatusPage.onRetry Retry ] StatusPage.server |> H.sends retryButton Event.click |> Expect.equal (Ok Retry)
        , test "in Norwegian" <|
            \_ ->
                page [ StatusPage.onRetry Retry, StatusPage.locale Locale.nb ] StatusPage.server
                    |> H.count 1 [ Selector.tag "button", Selector.containing [ Selector.text "Prøv igjen" ] ]
        , test "it comes before the actions of the application" <|
            \_ ->
                let
                    buttons =
                        page [ StatusPage.onRetry Retry, StatusPage.actions [ Button.view [] "Go home" ] ] StatusPage.server
                            |> Query.fromHtml
                            |> Query.findAll [ Selector.tag "button" ]
                in
                Expect.all
                    [ \_ -> buttons |> Query.index 0 |> Query.has [ Selector.text "Try again" ]
                    , \_ -> buttons |> Query.index 1 |> Query.has [ Selector.text "Go home" ]
                    ]
                    ()
        ]



-- PROBLEMS


problemTests : Test
problemTests =
    describe "fromProblem"
        [ test "uses the ready-made texts of the problem's kind" <|
            \_ ->
                page [] (StatusPage.fromProblem (Remote.problem Remote.conflict))
                    |> H.inside [ heading ] [ Selector.text "This conflicts with the current data" ]
        , test "in the language of the page" <|
            \_ ->
                page [ StatusPage.locale Locale.nb ] (StatusPage.fromProblem (Remote.problem Remote.conflict))
                    |> H.inside [ heading ] [ Selector.text "Dette er i konflikt med dataene slik de er nå" ]
        , test "the title and the detail the application gave the problem are used" <|
            \_ ->
                page []
                    (StatusPage.fromProblem
                        (Remote.problem Remote.notFound
                            |> Remote.withTitle "Order not found"
                            |> Remote.withDetail "Order 1042 was deleted."
                        )
                    )
                    |> Expect.all
                        [ H.inside [ heading ] [ Selector.text "Order not found" ]
                        , H.inside [ Selector.class "klar-status-page__description" ] [ Selector.text "Order 1042 was deleted." ]
                        ]
        , test "the title of the attribute wins over the title of the problem" <|
            \_ ->
                page [ StatusPage.title "Own title" ] (StatusPage.fromProblem (Remote.problem Remote.notFound |> Remote.withTitle "Order not found"))
                    |> H.inside [ heading ] [ Selector.text "Own title" ]
        , test "an empty title of the problem hides the heading, as in the error state" <|
            \_ ->
                page [] (StatusPage.fromProblem (Remote.problem Remote.notFound |> Remote.withTitle ""))
                    |> H.none [ heading ]
        ]



-- ICON AND TONE


iconAndToneTests : Test
iconAndToneTests =
    let
        iconIs kind name =
            page [] kind |> H.count 1 [ Selector.class ("klar-icon--" ++ name) ]

        toneIs kind tone =
            page [] kind |> H.has [ Selector.class ("klar-status-page--" ++ tone) ]

        problemOf kind =
            StatusPage.fromProblem (Remote.problem kind)
    in
    describe "icon and tone"
        [ test "the icon follows the kind" <|
            \_ ->
                Expect.all
                    [ \_ -> iconIs StatusPage.success "check-circle"
                    , \_ -> iconIs StatusPage.pageNotFound "search"
                    , \_ -> iconIs StatusPage.forbidden "lock"
                    , \_ -> iconIs StatusPage.unauthorized "key"
                    , \_ -> iconIs StatusPage.server "server"
                    , \_ -> iconIs StatusPage.network "wifi-off"
                    , \_ -> iconIs StatusPage.maintenance "wrench"
                    , \_ -> iconIs (problemOf Remote.timeout) "clock"
                    , \_ -> iconIs (problemOf Remote.tooManyRequests) "clock"
                    , \_ -> iconIs (problemOf Remote.validation) "warning"
                    , \_ -> iconIs (problemOf Remote.conflict) "warning"
                    , \_ -> iconIs (problemOf Remote.unknown) "error-circle"
                    ]
                    ()
        , test "another icon replaces it" <|
            \_ ->
                page [ StatusPage.icon Icon.package ] StatusPage.success
                    |> Expect.all
                        [ H.count 1 [ Selector.class "klar-icon--package" ]
                        , H.none [ Selector.class "klar-icon--check-circle" ]
                        ]
        , test "the tone follows the kind" <|
            \_ ->
                Expect.all
                    [ \_ -> toneIs StatusPage.success "success"
                    , \_ -> toneIs StatusPage.pageNotFound "neutral"
                    , \_ -> toneIs StatusPage.forbidden "neutral"
                    , \_ -> toneIs StatusPage.unauthorized "neutral"
                    , \_ -> toneIs StatusPage.server "danger"
                    , \_ -> toneIs StatusPage.network "warning"
                    , \_ -> toneIs StatusPage.maintenance "warning"
                    , \_ -> toneIs (problemOf Remote.unknown) "danger"
                    , \_ -> toneIs (problemOf Remote.timeout) "warning"
                    , \_ -> toneIs (problemOf Remote.tooManyRequests) "warning"
                    ]
                    ()
        ]



-- FOCUS


focusTests : Test
focusTests =
    describe "focus"
        [ test "without an id nothing can take focus" <|
            \_ ->
                page [] StatusPage.success
                    |> Expect.all
                        [ H.none [ Selector.attribute (Attr.tabindex -1) ]
                        , H.none [ Selector.id "order-created" ]
                        ]
        , test "the title has the id and can take focus" <|
            \_ ->
                page [ StatusPage.id "order-created" ] StatusPage.success
                    |> Expect.all
                        [ H.inside [ Selector.id "order-created" ] [ Selector.tag "h1", Selector.attribute (Attr.tabindex -1) ]
                        , H.count 1 [ Selector.attribute (Attr.tabindex -1) ]
                        ]
        , test "the id of the title is exactly the text given, so that Klar.focus can be given the same text" <|
            \_ ->
                page [ StatusPage.id "x" ] StatusPage.pageNotFound
                    |> H.inside [ Selector.id "x" ] [ heading ]
        , test "with a blank title the page itself has the id and can take focus, so that there is always something to find" <|
            \_ ->
                Expect.all
                    [ \_ -> page [ StatusPage.id "order-created", StatusPage.title "" ] StatusPage.success |> H.has [ Selector.id "order-created", Selector.attribute (Attr.tabindex -1), Selector.class "klar-status-page" ]
                    , \_ -> page [ StatusPage.id "order-created", StatusPage.title "  " ] StatusPage.success |> H.has [ Selector.id "order-created", Selector.attribute (Attr.tabindex -1) ]
                    ]
                    ()
        , test "the id is only in one place: on the title when there is one" <|
            \_ ->
                page [ StatusPage.id "order-created" ] StatusPage.success
                    |> H.count 1 [ Selector.id "order-created" ]
        ]


{-| `retrying` keeps the retry button in place, busy; `backAt` says when maintenance ends.
-}
retryingAndBackTests : Test
retryingAndBackTests =
    let
        retryButton =
            [ Selector.tag "button", Selector.containing [ Selector.text "Try again" ] ]

        twoThirty =
            Time.millisToPosix ((14 * 60 + 30) * 60 * 1000)
    in
    describe "retrying and the time back"
        [ test "while retrying the button is still there, busy" <|
            \_ ->
                page [ StatusPage.onRetry Retry, StatusPage.retrying True ] StatusPage.server
                    |> H.inside retryButton [ H.attr "aria-busy" "true" ]
        , test "not retrying by default" <|
            \_ ->
                page [ StatusPage.onRetry Retry ] StatusPage.server
                    |> H.none [ Selector.attribute (Attr.attribute "aria-busy" "true") ]
        , test "maintenance says when it is expected back, in UTC without settings" <|
            \_ ->
                page [ StatusPage.backAt twoThirty ] StatusPage.maintenance
                    |> H.has [ Selector.text "Expected back at 14:30 UTC." ]
        , test "in the zone of the settings and the language of the page" <|
            \_ ->
                page [ StatusPage.backAt twoThirty, StatusPage.settings (Settings.withZone Time.utc Settings.default), StatusPage.locale Locale.nb ] StatusPage.maintenance
                    |> H.has [ Selector.text "Ventet tilbake kl. 14:30." ]
        , test "a description of your own wins" <|
            \_ ->
                page [ StatusPage.backAt twoThirty, StatusPage.description "Back tomorrow." ] StatusPage.maintenance
                    |> H.none [ Selector.text "Expected back" ]
        , test "other kinds ignore it" <|
            \_ ->
                page [ StatusPage.backAt twoThirty ] StatusPage.server
                    |> H.none [ Selector.text "Expected back" ]
        ]
