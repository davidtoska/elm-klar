module FeedbackTest exposing (suite)

{-| The feedback components: Badge, Tag, Alert, Spinner, Skeleton, Progress,
EmptyState, ErrorState and Avatar, and the avatar and chart colors of the
themes (`Klar.Internal.Palette`).

The helpers put a view into a `div` first, so that the root of the view is
found by `findAll` too.

-}

import Expect exposing (Expectation)
import Html exposing (Html)
import Html.Attributes as Attr
import Klar.Alert as Alert
import Klar.Avatar as Avatar
import Klar.Badge as Badge
import Klar.EmptyState as EmptyState
import Klar.ErrorState as ErrorState
import Klar.Internal.Css.Tokens as Tokens
import Klar.Internal.Palette as Palette exposing (Color, Spec)
import Klar.Locale as Locale
import Klar.Progress as Progress
import Klar.Remote as Remote
import Klar.Skeleton as Skeleton
import Klar.Spinner as Spinner
import Klar.Tag as Tag
import Klar.Theme exposing (Size(..), Tone(..))
import Test exposing (Test, describe, test)
import Test.Html.Event as Event
import Test.Html.Query as Query
import Test.Html.Selector as Selector exposing (Selector)


type Msg
    = Removed
    | Dismissed
    | Retried


suite : Test
suite =
    describe "Feedback components"
        [ badgeTests
        , tagTests
        , nextFocusTests
        , alertTests
        , spinnerTests
        , skeletonTests
        , progressTests
        , emptyStateTests
        , errorStateTests
        , avatarTests
        , initialsTests
        , paletteTests
        , stylesheetColorTests
        ]



-- HELPERS


inDiv : Html msg -> Query.Single msg
inDiv html =
    Query.fromHtml (Html.div [] [ html ])


howMany : List Selector -> Int -> Html msg -> Expectation
howMany selectors n html =
    html |> inDiv |> Query.findAll selectors |> Query.count (Expect.equal n)


attr : String -> String -> Selector
attr name value =
    Selector.attribute (Attr.attribute name value)


cls : String -> Selector
cls =
    Selector.class



-- BADGE


badgeTests : Test
badgeTests =
    describe "Badge"
        [ test "a badge has the classes of its tone, style and size" <|
            \_ ->
                Badge.view [ Badge.tone Warning, Badge.solid, Badge.size Small ] "Late"
                    |> howMany [ cls "klar-badge", cls "klar-badge--warning", cls "klar-badge--solid", cls "klar-badge--sm" ] 1
        , test "the dot comes before the icon and the label" <|
            \_ ->
                Badge.view [ Badge.dot ] "Pending"
                    |> inDiv
                    |> Query.find [ cls "klar-badge" ]
                    |> Query.children []
                    |> Query.index 0
                    |> Query.has [ cls "klar-badge__dot" ]
        , test "a short label has no tooltip" <|
            \_ -> Badge.view [] "Paid" |> howMany [ Selector.attribute (Attr.title "Paid") ] 0
        , test "a label longer than 12 characters carries the whole text as a tooltip" <|
            \_ -> Badge.view [] "Awaiting payment" |> howMany [ Selector.attribute (Attr.title "Awaiting payment") ] 1
        , test "a status has a dot and the tone class" <|
            \_ ->
                Badge.status Danger "Overdue"
                    |> Expect.all
                        [ howMany [ cls "klar-status", cls "klar-status--danger" ] 1
                        , howMany [ cls "klar-status__dot" ] 1
                        ]
        , test "a count is primary and solid by default" <|
            \_ -> Badge.count [] 7 |> howMany [ cls "klar-badge--count", cls "klar-badge--primary", cls "klar-badge--solid", Selector.exactText "7" ] 1
        , test "a count takes a tone and a size" <|
            \_ -> Badge.count [ Badge.tone Danger, Badge.size Small ] 3 |> howMany [ cls "klar-badge--count", cls "klar-badge--danger", cls "klar-badge--sm" ] 1
        , test "a count above 99 shows 99+, and the exact number to screen readers and as the tooltip" <|
            \_ ->
                Badge.count [] 128
                    |> Expect.all
                        [ howMany [ attr "aria-hidden" "true", Selector.exactText "99+" ] 1
                        , howMany [ cls "klar-sr-only", Selector.exactText "128" ] 1
                        , howMany [ cls "klar-badge--count", Selector.attribute (Attr.title "128") ] 1
                        ]
        , test "max sets the largest number written out" <|
            \_ -> Badge.count [ Badge.max 999 ] 1280 |> howMany [ Selector.exactText "999+" ] 1
        , test "a count of exactly max is written out" <|
            \_ -> Badge.count [] 99 |> howMany [ Selector.exactText "99" ] 1
        , test "a count of zero or less shows nothing" <|
            \_ ->
                Expect.all
                    [ \_ -> Badge.count [] 0 |> howMany [ cls "klar-badge" ] 0
                    , \_ -> Badge.count [] -3 |> howMany [ cls "klar-badge" ] 0
                    ]
                    ()
        ]



-- TAG


tagTests : Test
tagTests =
    let
        button =
            [ Selector.tag "button", cls "klar-tag__remove" ]
    in
    describe "Tag"
        [ test "without onRemove there is no button" <|
            \_ -> Tag.view [] "Warehouse A" |> howMany button 0
        , test "the remove button is named after the label, in the locale" <|
            \_ ->
                Expect.all
                    [ \_ -> Tag.view [ Tag.onRemove Removed ] "Warehouse A" |> howMany (button ++ [ attr "aria-label" "Remove Warehouse A", Selector.attribute (Attr.title "Remove Warehouse A") ]) 1
                    , \_ -> Tag.view [ Tag.onRemove Removed, Tag.locale Locale.nb ] "Lager A" |> howMany (button ++ [ attr "aria-label" "Fjern Lager A" ]) 1
                    ]
                    ()
        , test "removeLabel names the button and its tooltip" <|
            \_ ->
                Tag.view [ Tag.onRemove Removed, Tag.removeLabel "Remove filter Amount > 100" ] "Amount > 100"
                    |> howMany (button ++ [ attr "aria-label" "Remove filter Amount > 100", Selector.attribute (Attr.title "Remove filter Amount > 100") ]) 1
        , test "the button is a plain button with the id of removeId" <|
            \_ ->
                Tag.view [ Tag.onRemove Removed, Tag.removeId "remove-a" ] "Warehouse A"
                    |> howMany (button ++ [ Selector.attribute (Attr.type_ "button"), Selector.id "remove-a" ]) 1
        , test "a click sends the message" <|
            \_ ->
                Tag.view [ Tag.onRemove Removed ] "Warehouse A"
                    |> inDiv
                    |> Query.find button
                    |> Event.simulate Event.click
                    |> Event.expect Removed
        ]


nextFocusTests : Test
nextFocusTests =
    let
        next removed tags =
            Tag.nextFocus { removed = removed, tags = tags, toId = \t -> "remove-" ++ t, otherwise = "add" }
    in
    describe "Tag.nextFocus"
        [ test "the tag after the removed one" <|
            \_ -> next "b" [ "a", "b", "c" ] |> Expect.equal "remove-c"
        , test "the tag before, when the last was removed" <|
            \_ -> next "c" [ "a", "b", "c" ] |> Expect.equal "remove-b"
        , test "the fallback when the only tag was removed" <|
            \_ -> next "a" [ "a" ] |> Expect.equal "add"
        , test "the first tag after the first one removed" <|
            \_ -> next "a" [ "a", "b" ] |> Expect.equal "remove-b"
        , test "a tag that is not in the list leaves the last tag" <|
            \_ -> next "x" [ "a", "b" ] |> Expect.equal "remove-b"
        ]



-- ALERT


alertTests : Test
alertTests =
    let
        close =
            [ Selector.tag "button", cls "klar-alert__close" ]
    in
    describe "Alert"
        [ test "a warning is an alert, and polite makes it a status" <|
            \_ ->
                Expect.all
                    [ \_ -> Alert.view [ Alert.tone Warning ] "Careful" |> howMany [ cls "klar-alert", attr "role" "alert" ] 1
                    , \_ -> Alert.view [ Alert.tone Warning, Alert.polite ] "Careful" |> howMany [ cls "klar-alert", attr "role" "status" ] 1
                    , \_ -> Alert.view [ Alert.tone Success ] "Saved" |> howMany [ cls "klar-alert", attr "role" "status" ] 1
                    ]
                    ()
        , test "the close button is named Close, with the title when there is one" <|
            \_ ->
                Expect.all
                    [ \_ -> Alert.view [ Alert.onDismiss Dismissed ] "Saved" |> howMany (close ++ [ attr "aria-label" "Close", Selector.attribute (Attr.title "Close") ]) 1
                    , \_ -> Alert.view [ Alert.onDismiss Dismissed, Alert.title "Unsaved changes" ] "..." |> howMany (close ++ [ attr "aria-label" "Close: Unsaved changes" ]) 1
                    , \_ -> Alert.view [ Alert.onDismiss Dismissed, Alert.title "Ulagrede endringer", Alert.locale Locale.nb ] "..." |> howMany (close ++ [ attr "aria-label" "Lukk: Ulagrede endringer" ]) 1
                    ]
                    ()
        , test "the close button sends the message" <|
            \_ ->
                Alert.view [ Alert.onDismiss Dismissed ] "Saved"
                    |> inDiv
                    |> Query.find close
                    |> Event.simulate Event.click
                    |> Event.expect Dismissed
        , test "id gives the alert an id that can take the focus" <|
            \_ -> Alert.view [ Alert.id "save-error" ] "Failed" |> howMany [ cls "klar-alert", Selector.id "save-error", Selector.attribute (Attr.tabindex -1) ] 1
        , test "without an id the alert takes no focus" <|
            \_ -> Alert.view [] "Failed" |> howMany [ Selector.attribute (Attr.tabindex -1) ] 0
        , test "the stale notice lists the names in the locale" <|
            \_ ->
                Expect.all
                    [ \_ -> Alert.stale [] Retried [ "orders", "figures", "customers" ] |> inDiv |> Query.has [ Selector.text "orders, figures and customers." ]
                    , \_ -> Alert.stale [] Retried [ "orders", "figures" ] |> inDiv |> Query.has [ Selector.text "orders and figures." ]
                    , \_ -> Alert.stale [ Alert.locale Locale.nb ] Retried [ "ordrer", "tall", "kunder" ] |> inDiv |> Query.has [ Selector.text "ordrer, tall og kunder." ]
                    , \_ -> Alert.stale [] Retried [ "orders" ] |> inDiv |> Query.has [ Selector.text "for: orders." ]
                    ]
                    ()
        , test "the stale notice shows nothing without names" <|
            \_ -> Alert.stale [] Retried [] |> howMany [ cls "klar-alert" ] 0
        ]



-- SPINNER


spinnerTests : Test
spinnerTests =
    describe "Spinner"
        [ test "with a label it is a polite status with the label for screen readers" <|
            \_ ->
                Spinner.view [ Spinner.label "Saving" ]
                    |> Expect.all
                        [ howMany [ cls "klar-spinner", attr "role" "status", attr "aria-live" "polite" ] 1
                        , howMany [ cls "klar-sr-only", Selector.exactText "Saving" ] 1
                        ]
        , test "without a label it is decoration" <|
            \_ ->
                Spinner.view []
                    |> Expect.all
                        [ howMany [ cls "klar-spinner", attr "aria-hidden" "true" ] 1
                        , howMany [ attr "role" "status" ] 0
                        ]
        , test "a labelled spinner that is not loading keeps its empty live region" <|
            \_ ->
                Spinner.view [ Spinner.label "Saving", Spinner.loading False ]
                    |> Expect.all
                        [ howMany [ attr "role" "status", cls "klar-spinner-idle" ] 1
                        , howMany [ cls "klar-spinner" ] 0
                        , howMany [ Selector.text "Saving" ] 0
                        ]
        , test "an unlabelled spinner that is not loading draws nothing" <|
            \_ -> Spinner.view [ Spinner.loading False ] |> howMany [ cls "klar-spinner" ] 0
        , test "the panel is a status with visible text, delayed against flashing" <|
            \_ ->
                Spinner.panel [] "Loading orders ..."
                    |> Expect.all
                        [ howMany [ cls "klar-spinner-panel", cls "klar-spinner-panel--delayed", attr "role" "status" ] 1
                        , howMany [ cls "klar-spinner-panel__text", Selector.exactText "Loading orders ..." ] 1
                        , howMany [ cls "klar-spinner--lg" ] 1
                        ]
        , test "a compact panel" <|
            \_ -> Spinner.panel [ Spinner.compact ] "Loading" |> howMany [ cls "klar-spinner-panel--compact" ] 1
        , test "a panel that is not loading keeps its empty live region" <|
            \_ ->
                Spinner.panel [ Spinner.loading False ] "Loading orders ..."
                    |> Expect.all
                        [ howMany [ attr "role" "status", cls "klar-spinner-idle" ] 1
                        , howMany [ Selector.text "Loading orders" ] 0
                        ]
        ]



-- SKELETON


skeletonTests : Test
skeletonTests =
    let
        widths html =
            html
                |> inDiv
                |> Query.findAll [ cls "klar-skeleton--line" ]
    in
    describe "Skeleton"
        [ test "lines draws that many lines" <|
            \_ -> Skeleton.lines 4 |> widths |> Query.count (Expect.equal 4)
        , test "there is always at least one line" <|
            \_ -> Skeleton.lines 0 |> widths |> Query.count (Expect.equal 1)
        , test "a single line is full width" <|
            \_ -> Skeleton.lines 1 |> widths |> Query.index 0 |> Query.has [ attr "style" "width:100%" ]
        , test "the last of several lines is 60% wide, and the widths vary" <|
            \_ ->
                Skeleton.lines 3
                    |> widths
                    |> Expect.all
                        [ Query.index 0 >> Query.has [ attr "style" "width:100%" ]
                        , Query.index 1 >> Query.has [ attr "style" "width:94%" ]
                        , Query.index 2 >> Query.has [ attr "style" "width:60%" ]
                        ]
        , test "a line is kept between 5 and 100 percent" <|
            \_ ->
                Expect.all
                    [ \_ -> Skeleton.line 150 |> inDiv |> Query.has [ attr "style" "width:100%" ]
                    , \_ -> Skeleton.line 1 |> inDiv |> Query.has [ attr "style" "width:5%" ]
                    ]
                    ()
        , test "skeletons are hidden from screen readers" <|
            \_ -> Skeleton.circle 30 |> howMany [ cls "klar-skeleton--circle", attr "aria-hidden" "true" ] 1
        ]



-- PROGRESS


progressTests : Test
progressTests =
    let
        shown text html =
            html |> howMany [ cls "klar-progress__value", Selector.exactText text ] 1

        now n html =
            html |> howMany [ attr "role" "progressbar", attr "aria-valuenow" (String.fromInt n) ] 1
    in
    describe "Progress rounds down, so only a task that is done reads 100%"
        [ test "99.5 shows 99%" <|
            \_ -> Progress.view [ Progress.value 99.5, Progress.showValue ] |> Expect.all [ shown "99%", now 99 ]
        , test "100 shows 100%" <|
            \_ -> Progress.view [ Progress.value 100, Progress.showValue ] |> Expect.all [ shown "100%", now 100 ]
        , test "0.4 shows 0%" <|
            \_ -> Progress.view [ Progress.value 0.4, Progress.showValue ] |> Expect.all [ shown "0%", now 0 ]
        , test "62.5 shows 62%" <|
            \_ -> Progress.view [ Progress.value 62.5, Progress.showValue ] |> shown "62%"
        , test "2 of 3 steps fill 2 of 3 segments, despite the float" <|
            \_ ->
                Progress.view [ Progress.outOf 2 3, Progress.segments 3 ]
                    |> howMany [ cls "klar-progress__segment--filled" ] 2
        , test "99% of 4 segments fills 3, not 4" <|
            \_ ->
                Progress.view [ Progress.value 99, Progress.segments 4 ]
                    |> howMany [ cls "klar-progress__segment--filled" ] 3
        , test "more done than the total says so" <|
            \_ -> Progress.view [ Progress.outOf 7 5, Progress.showValue ] |> Expect.all [ shown "7 of 5", now 100 ]
        ]



-- EMPTY STATE


emptyStateTests : Test
emptyStateTests =
    let
        title =
            cls "klar-state__title"
    in
    describe "EmptyState"
        [ test "without a title it says that there is nothing to show, in the locale" <|
            \_ ->
                Expect.all
                    [ \_ -> EmptyState.view [] |> howMany [ title, Selector.exactText "Nothing to show" ] 1
                    , \_ -> EmptyState.view [ EmptyState.locale Locale.nb ] |> howMany [ title, Selector.exactText "Ingenting å vise" ] 1
                    ]
                    ()
        , test "actions are shown in order" <|
            \_ ->
                EmptyState.view
                    [ EmptyState.actions
                        [ Html.button [] [ Html.text "Create order" ]
                        , Html.button [] [ Html.text "Import" ]
                        ]
                    ]
                    |> inDiv
                    |> Query.find [ cls "klar-state__actions" ]
                    |> Query.children [ Selector.tag "button" ]
                    |> Expect.all
                        [ Query.count (Expect.equal 2)
                        , Query.index 0 >> Query.has [ Selector.text "Create order" ]
                        ]
        , test "no actions, no row" <|
            \_ -> EmptyState.view [] |> howMany [ cls "klar-state__actions" ] 0
        , test "headingLevel makes the title a heading" <|
            \_ -> EmptyState.view [ EmptyState.title "No orders yet", EmptyState.headingLevel 2 ] |> howMany [ Selector.tag "h2", title ] 1
        , test "by default the title is not a heading" <|
            \_ -> EmptyState.view [ EmptyState.title "No orders yet" ] |> Expect.all [ howMany [ title ] 1, howMany [ Selector.tag "h3" ] 0, howMany [ Selector.tag "h2" ] 0 ]
        ]



-- ERROR STATE


errorStateTests : Test
errorStateTests =
    let
        retry =
            [ Selector.tag "button", Selector.containing [ Selector.text "Try again" ] ]

        retryable =
            [ ( "network", Remote.network ), ( "timeout", Remote.timeout ), ( "server", Remote.server ), ( "unknown", Remote.unknown ) ]

        final =
            [ ( "notFound", Remote.notFound ), ( "forbidden", Remote.forbidden ), ( "unauthorized", Remote.unauthorized ), ( "validation", Remote.validation ), ( "conflict", Remote.conflict ) ]
    in
    describe "ErrorState"
        [ describe "a retry button for the kinds where trying again can help"
            (List.map
                (\( name, kind ) ->
                    test name <|
                        \_ -> ErrorState.view [ ErrorState.onRetry Retried ] (Remote.problem kind) |> howMany retry 1
                )
                retryable
            )
        , describe "no retry button for the kinds that would fail again"
            (List.map
                (\( name, kind ) ->
                    test name <|
                        \_ -> ErrorState.view [ ErrorState.onRetry Retried ] (Remote.problem kind) |> howMany retry 0
                )
                final
            )
        , test "no retry button without onRetry" <|
            \_ -> ErrorState.view [] (Remote.problem Remote.server) |> howMany retry 0
        , test "the retry button sends the message" <|
            \_ ->
                ErrorState.view [ ErrorState.onRetry Retried ] (Remote.problem Remote.server)
                    |> inDiv
                    |> Query.find retry
                    |> Event.simulate Event.click
                    |> Event.expect Retried
        , test "actions are shown after the retry button" <|
            \_ ->
                ErrorState.view
                    [ ErrorState.onRetry Retried, ErrorState.actions [ Html.button [] [ Html.text "Back to orders" ] ] ]
                    (Remote.problem Remote.server)
                    |> inDiv
                    |> Query.find [ cls "klar-state__actions" ]
                    |> Query.children [ Selector.tag "button" ]
                    |> Expect.all
                        [ Query.count (Expect.equal 2)
                        , Query.index 1 >> Query.has [ Selector.text "Back to orders" ]
                        ]
        , test "actions are a way forward when retrying cannot help" <|
            \_ ->
                ErrorState.view [ ErrorState.onRetry Retried, ErrorState.actions [ Html.button [] [ Html.text "Sign in" ] ] ] (Remote.problem Remote.unauthorized)
                    |> Expect.all
                        [ howMany retry 0
                        , howMany [ Selector.tag "button", Selector.containing [ Selector.text "Sign in" ] ] 1
                        ]
        , test "it is an alert, and polite makes it a status" <|
            \_ ->
                Expect.all
                    [ \_ -> ErrorState.view [] (Remote.problem Remote.server) |> howMany [ cls "klar-state--error", attr "role" "alert" ] 1
                    , \_ -> ErrorState.view [ ErrorState.polite ] (Remote.problem Remote.server) |> howMany [ cls "klar-state--error", attr "role" "status" ] 1
                    ]
                    ()
        , test "headingLevel makes the title a heading" <|
            \_ -> ErrorState.view [ ErrorState.headingLevel 1 ] (Remote.problem Remote.server) |> howMany [ Selector.tag "h1", cls "klar-state__title" ] 1
        , test "the code is shown" <|
            \_ -> ErrorState.view [] (Remote.problem Remote.server |> Remote.withCode "503") |> howMany [ cls "klar-state__code", Selector.exactText "503" ] 1
        ]



-- AVATAR


avatarTests : Test
avatarTests =
    describe "Avatar"
        [ test "every status is in the accessible name and has its dot" <|
            \_ ->
                Expect.all
                    (List.map
                        (\( status, text ) ->
                            \_ ->
                                Avatar.view [ Avatar.status status ] "Ada Lovelace"
                                    |> howMany [ attr "aria-label" ("Ada Lovelace, " ++ text), Selector.containing [ cls ("klar-avatar__status--" ++ text) ] ] 1
                        )
                        [ ( Avatar.online, "online" ), ( Avatar.away, "away" ), ( Avatar.busy, "busy" ), ( Avatar.offline, "offline" ) ]
                    )
                    ()
        , test "a status in Norwegian" <|
            \_ -> Avatar.view [ Avatar.status Avatar.away, Avatar.locale Locale.nb ] "Ada Lovelace" |> howMany [ attr "aria-label" "Ada Lovelace, borte" ] 1
        , test "the name is the tooltip" <|
            \_ -> Avatar.view [] "Ada Lovelace" |> howMany [ cls "klar-avatar", Selector.attribute (Attr.title "Ada Lovelace") ] 1
        , test "a decorative avatar has no tooltip, since the name is written next to it" <|
            \_ -> Avatar.view [ Avatar.decorative ] "Ada Lovelace" |> howMany [ Selector.attribute (Attr.title "Ada Lovelace") ] 0
        , test "an entry with withImage shows its picture in a group" <|
            \_ ->
                Avatar.group [] [ Avatar.entry "Grace Hopper" |> Avatar.withImage "/g.jpg", Avatar.entry "Ada Lovelace" ]
                    |> howMany [ cls "klar-avatar__image" ] 1
        , test "a blank name gets the neutral look" <|
            \_ -> Avatar.view [] "" |> howMany [ cls "klar-avatar--neutral" ] 1
        ]


initialsTests : Test
initialsTests =
    let
        check name expected =
            test ("[" ++ name ++ "] gives " ++ expected) <|
                \_ -> Avatar.initials name |> Expect.equal expected
    in
    describe "Avatar.initials"
        [ check "Ada Lovelace" "AL"
        , check "Warehouse" "W"
        , check "" "?"
        , check "   " "?"
        , check "Ada Lovelace (Finance)" "AL"
        , check "Ada Lovelace (Finance team)" "AL"
        , check "Ada [Ops] Lovelace" "AL"
        , check "Martin Luther King Jr." "MK"
        , check "Martin Luther King, Jr." "MK"
        , check "Elizabeth II" "E"
        , check "Ada Lovelace ✓" "AL"
        , check "Grace Hopper 🚀" "GH"
        , check "Øyvind Åsen" "ØÅ"
        , check "ada lovelace" "AL"
        , check "(Finance)" "F"
        , check "Jr" "J"
        , check "3M Norge" "3N"
        ]



-- PALETTE


paletteTests : Test
paletteTests =
    describe "The avatar and chart colors of every theme"
        (Palette.specs
            |> List.concatMap
                (\spec ->
                    [ themeColorTest spec False, themeColorTest spec True ]
                )
        )


themeColorTest : Spec -> Bool -> Test
themeColorTest spec dark =
    let
        name =
            spec.name
                ++ (if dark then
                        " dark"

                    else
                        " light"
                   )

        pairs =
            Palette.avatarPairs spec dark

        firstHue =
            pairs |> List.head |> Maybe.map (Tuple.first >> .h) |> Maybe.withDefault 0

        lowContrast =
            pairs
                |> List.indexedMap Tuple.pair
                |> List.filter (\( _, ( ground, ink ) ) -> Palette.contrast ink ground < 4.5)
                |> List.map (\( i, _ ) -> "avatar-" ++ String.fromInt i)

        nearAccent =
            pairs
                |> List.drop 2
                |> List.map (Tuple.first >> .h)
                |> List.filter (\h -> Palette.hueDistance h firstHue < 40)

        chart =
            Palette.chartColors spec dark

        chartAccent =
            chart
                |> List.filter (\( n, _ ) -> n == "chart-1")
                |> List.head
                |> Maybe.map Tuple.second
                |> Maybe.withDefault { h = spec.accentHue, s = 100 * spec.accentSat, l = 50 }

        chartGreen =
            chart
                |> List.filter (\( n, _ ) -> n == "chart-2")
                |> List.head
                |> Maybe.map (Tuple.second >> .h)
                |> Maybe.withDefault 150
    in
    test name <|
        \_ ->
            Expect.all
                [ \_ -> List.length pairs |> Expect.equal 8
                , \_ -> lowContrast |> Expect.equal []
                , \_ -> nearAccent |> Expect.equal []
                , \_ -> (chartAccent.s >= 50) |> Expect.equal True |> Expect.onFail "chart-1 has hardly any color"
                , \_ -> (Palette.hueDistance chartAccent.h chartGreen >= 40) |> Expect.equal True |> Expect.onFail "chart-1 and chart-2 are too close"
                ]
                ()


{-| The light mode of the first theme is the stylesheet as it is: the literal values
in `Klar.Internal.Css.Tokens`.
-}
stylesheetColorTests : Test
stylesheetColorTests =
    let
        token name =
            literal name |> Maybe.withDefault { h = 0, s = 0, l = 50 }

        ratio a b =
            Palette.contrast (token a) (token b)

        atLeast minimum ( a, b ) =
            \_ ->
                (ratio a b >= minimum)
                    |> Expect.equal True
                    |> Expect.onFail (a ++ " on " ++ b ++ " is " ++ String.fromFloat (toFloat (round (ratio a b * 100)) / 100))
    in
    describe "the stylesheet's own colors (Klar, light)"
        [ test "every token used here is in the stylesheet" <|
            \_ ->
                [ "white", "amber-700", "green-600", "red-600", "blue-600", "gray-600", "amber-600" ]
                    |> List.filter (\n -> literal n == Nothing)
                    |> Expect.equal []
        , test "solid badges: white on the solid color keeps 4.5 : 1" <|
            \_ ->
                Expect.all
                    (List.map (atLeast 4.5)
                        [ ( "white", "amber-700" ), ( "white", "green-600" ), ( "white", "red-600" ), ( "white", "blue-600" ), ( "white", "gray-600" ) ]
                    )
                    ()
        , test "status dots keep 3 : 1 against the page" <|
            \_ ->
                Expect.all
                    (List.map (atLeast 3)
                        [ ( "amber-600", "white" ), ( "green-600", "white" ), ( "red-600", "white" ), ( "blue-600", "white" ), ( "gray-600", "white" ) ]
                    )
                    ()
        ]


{-| A `--klar-<name>: #rrggbb;` of the token stylesheet, as a color.
-}
literal : String -> Maybe Color
literal name =
    let
        key =
            "--klar-" ++ name ++ ":"
    in
    Tokens.css
        |> String.lines
        |> List.map String.trim
        |> List.filter (String.startsWith key)
        |> List.head
        |> Maybe.map (String.dropLeft (String.length key) >> String.trim >> String.replace ";" "")
        |> Maybe.andThen fromHex


fromHex : String -> Maybe Color
fromHex text =
    let
        digits =
            String.toLower (String.replace "#" "" text)

        hexDigit c =
            String.indexes (String.fromChar c) "0123456789abcdef" |> List.head

        channel i =
            case String.toList (String.slice i (i + 2) digits) of
                [ a, b ] ->
                    Maybe.map2 (\x y -> toFloat (x * 16 + y) / 255) (hexDigit a) (hexDigit b)

                _ ->
                    Nothing
    in
    if String.length digits /= 6 then
        Nothing

    else
        Maybe.map3 toHsl (channel 0) (channel 2) (channel 4)


toHsl : Float -> Float -> Float -> Color
toHsl r g b =
    let
        hi =
            max r (max g b)

        lo =
            min r (min g b)

        l =
            (hi + lo) / 2

        d =
            hi - lo

        s =
            if d == 0 then
                0

            else
                d / (1 - abs (2 * l - 1))

        h =
            if d == 0 then
                0

            else if hi == r then
                60 * ((g - b) / d)

            else if hi == g then
                60 * ((b - r) / d + 2)

            else
                60 * ((r - g) / d + 4)
    in
    { h =
        if h < 0 then
            h + 360

        else
            h
    , s = s * 100
    , l = l * 100
    }
