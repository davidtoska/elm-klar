module FoundationFixTest exposing (suite)

{-| Regression tests for the fix pass over the foundation and status modules:
Layout, Card, EmptyState, ErrorState, Progress, Avatar, JsonViewer and ListItem.

Each test looks at the HTML a view renders (`Test.Html.Query`) or at the message
an event sends (`Test.Html.Event`).

A note on the queries of `elm-explorations/test`: `has` and `hasNot` look at the
element and everything below it, while `find` and `findAll` look only below the
element. The helpers `has`, `hasNot` and `howMany` below hide the second part by
putting the view into a `div` first, so that the root of the view is found too.
Where a descendant could carry the same attribute as the element under test, the
test counts the elements instead of asking whether there is one.

-}

import Expect exposing (Expectation)
import Html exposing (Html)
import Html.Attributes as Attr
import Json.Encode as Encode
import Klar.Avatar as Avatar
import Klar.Card as Card
import Klar.EmptyState as EmptyState
import Klar.ErrorState as ErrorState
import Klar.JsonViewer as JsonViewer
import Klar.Layout as Layout
import Klar.ListItem as ListItem
import Klar.Locale as Locale exposing (Locale)
import Klar.Progress as Progress
import Klar.Remote as Remote exposing (Remote(..))
import Test exposing (Test, describe, test)
import Test.Html.Event as Event
import Test.Html.Query as Query
import Test.Html.Selector as Selector exposing (Selector)


type Msg
    = Opened
    | FromViewer JsonViewer.Msg


suite : Test
suite =
    describe "Foundation and status modules (fix pass)"
        [ layoutColumnTests
        , layoutScrollTests
        , listScrollTests
        , listLinkTests
        , listLabelTests
        , jsonScrollTests
        , emptyTitleTests
        , cardHeadingTests
        , progressValueTests
        , progressSegmentTests
        , avatarGroupNameTests
        , avatarDecorativeTests
        , avatarEntryTests
        ]



-- HELPERS


{-| The view in a `div`, so that the queries that look below an element find the
root of the view too.
-}
inDiv : Html msg -> Query.Single msg
inDiv html =
    Query.fromHtml (Html.div [] [ html ])


{-| The element, or something below it, matches every selector.
-}
has : List Selector -> Html msg -> Expectation
has selectors html =
    html |> Query.fromHtml |> Query.has selectors


{-| Nothing in the view matches the selectors.
-}
hasNot : List Selector -> Html msg -> Expectation
hasNot selectors html =
    html |> Query.fromHtml |> Query.hasNot selectors


{-| How many elements of the view, the root included, match the selectors.
-}
howMany : List Selector -> Int -> Html msg -> Expectation
howMany selectors n html =
    html |> inDiv |> Query.findAll selectors |> Query.count (Expect.equal n)


attr : String -> String -> Selector
attr name value =
    Selector.attribute (Attr.attribute name value)


role : String -> Selector
role name =
    attr "role" name


ariaLabel : String -> Selector
ariaLabel text =
    attr "aria-label" text


ariaHidden : Selector
ariaHidden =
    attr "aria-hidden" "true"


{-| An element that is in the tab order (`tabindex="0"`).
-}
focusable : Selector
focusable =
    Selector.attribute (Attr.tabindex 0)


{-| The `style` attribute that `Layout.grid` writes for a template, with the default
gap, and the class that bounds a `columnSpan` inside it to a number of columns.
-}
gridStyle : String -> Int -> Selector
gridStyle template cols =
    Selector.all
        [ attr "style" ("--klar-grid-template:" ++ template ++ ";--klar-gap:var(--klar-space-3)")
        , Selector.class ("klar-grid--cols-" ++ String.fromInt cols)
        ]



-- LAYOUT: columns and minColumn


layoutColumnTests : Test
layoutColumnTests =
    let
        columnsTest name given expected =
            test name <|
                \_ ->
                    Layout.grid [ Layout.columns given ] []
                        |> has [ gridStyle ("repeat(" ++ String.fromInt expected ++ ", minmax(0, 1fr))") expected ]

        minColumnTest name given expected =
            test name <|
                \_ ->
                    Layout.grid [ Layout.minColumn given ] []
                        |> has [ gridStyle ("repeat(auto-fit, minmax(min(" ++ String.fromInt expected ++ "px, 100%), 1fr))") 1 ]
    in
    describe "Layout.columns and Layout.minColumn never write invalid CSS"
        [ columnsTest "3 columns stay 3" 3 3
        , columnsTest "1 column stays 1" 1 1
        , columnsTest "0 columns count as 1" 0 1
        , columnsTest "a negative number counts as 1" -4 1
        , columnsTest "a very negative number counts as 1" -100000 1
        , minColumnTest "240 pixels stay 240" 240 240
        , minColumnTest "16 pixels stay 16" 16 16
        , minColumnTest "15 pixels count as 16" 15 16
        , minColumnTest "1 pixel counts as 16" 1 16
        , minColumnTest "0 pixels count as 16" 0 16
        , minColumnTest "a negative width counts as 16" -50 16
        , test "columns still wins over minColumn, and is clamped too" <|
            \_ ->
                Layout.grid [ Layout.minColumn 200, Layout.columns 0 ] []
                    |> has [ gridStyle "repeat(1, minmax(0, 1fr))" 1 ]
        , test "fillRest marks a stack as the rest of the height" <|
            \_ ->
                Layout.stack [ Layout.fillRest ] []
                    |> has [ Selector.classes [ "klar-stack", "klar-fill-rest" ] ]
        , test "a stack without fillRest is as tall as its content" <|
            \_ ->
                Layout.stack [] []
                    |> Query.fromHtml
                    |> Query.hasNot [ Selector.class "klar-fill-rest" ]
        , test "a grid with neither keeps the default of 240 pixels" <|
            \_ ->
                Layout.grid [] []
                    |> has [ gridStyle "repeat(auto-fit, minmax(min(240px, 100%), 1fr))" 1 ]
        ]



-- LAYOUT: maxHeight


layouts : List ( String, List (Layout.Attribute msg) -> List (Html msg) -> Html msg )
layouts =
    [ ( "stack", Layout.stack )
    , ( "row", Layout.row )
    , ( "grid", Layout.grid )
    , ( "container", Layout.container )
    ]


layoutScrollTests : Test
layoutScrollTests =
    describe "Layout.maxHeight makes a scroll area that the keyboard can reach"
        (layouts
            |> List.concatMap
                (\( name, layout ) ->
                    [ test ("a " ++ name ++ " with maxHeight is in the tab order") <|
                        \_ -> layout [ Layout.maxHeight 120 ] [ Html.text "content" ] |> has [ focusable ]
                    , test ("a " ++ name ++ " with maxHeight still scrolls: its class and its limit are there") <|
                        \_ ->
                            layout [ Layout.maxHeight 120 ] []
                                |> has [ Selector.class "klar-scroll", attr "style" (maxHeightStyle name) ]
                    , test ("a " ++ name ++ " without maxHeight is not in the tab order") <|
                        \_ -> layout [] [ Html.text "content" ] |> hasNot [ focusable ]
                    , test ("a " ++ name ++ " with maxHeight has no role: it has no name to give") <|
                        \_ -> layout [ Layout.maxHeight 120 ] [] |> hasNot [ role "region" ]
                    ]
                )
        )


{-| The `style` attribute of a layout with `maxHeight 120` and nothing else. A
grid starts with its template.
-}
maxHeightStyle : String -> String
maxHeightStyle name =
    if name == "grid" then
        "--klar-grid-template:repeat(auto-fit, minmax(min(240px, 100%), 1fr));--klar-gap:var(--klar-space-3);--klar-max-h:120px"

    else
        "--klar-gap:var(--klar-space-3);--klar-max-h:120px"



-- LISTITEM: a list that scrolls


listScrollTests : Test
listScrollTests =
    let
        rows =
            [ ListItem.view [] "Order 1", ListItem.view [] "Order 2" ]

        orderRow name =
            ( name, ListItem.view [] name )
    in
    describe "ListItem.maxHeight makes a scroll area that the keyboard can reach"
        [ test "a list with maxHeight is in the tab order" <|
            \_ -> ListItem.list [ ListItem.maxHeight 200 ] rows |> has [ focusable ]
        , test "a list without maxHeight is not" <|
            \_ -> ListItem.list [] rows |> hasNot [ focusable ]
        , test "a list with maxHeight keeps the role list: a region would take the list away from the rows" <|
            \_ -> ListItem.list [ ListItem.maxHeight 200 ] rows |> has [ role "list" ]
        , test "a list with maxHeight is never a region, named or not" <|
            \_ ->
                ListItem.list [ ListItem.maxHeight 200, ListItem.ariaLabel "Tickets" ] rows
                    |> hasNot [ role "region" ]
        , test "a named list with maxHeight keeps its name" <|
            \_ ->
                ListItem.list [ ListItem.maxHeight 200, ListItem.ariaLabel "Tickets" ] rows
                    |> has [ focusable, role "list", ariaLabel "Tickets" ]
        , test "viewRemote: the rows of a loaded list scroll and can take focus" <|
            \_ ->
                ListItem.viewRemote [ ListItem.maxHeight 200 ] (Loaded [ orderRow "Order 1" ])
                    |> has [ focusable, Selector.class "klar-list--scroll" ]
        , test "viewRemote: the placeholder rows have no height limit, so no tab stop" <|
            \_ ->
                ListItem.viewRemote [ ListItem.maxHeight 200 ] Loading
                    |> hasNot [ focusable ]
        ]



-- LISTITEM: a row that is a link and has an onClick


linkRow : List (ListItem.Attribute Msg) -> Html Msg
linkRow attributes =
    ListItem.view ([ ListItem.href "#/orders/1", ListItem.onClick Opened ] ++ attributes) "Order 1"


{-| The result of a click on the link of a row: the message, or the reason why
there is none.
-}
clickOnLink : ( String, Encode.Value ) -> Html Msg -> Result String Msg
clickOnLink click html =
    html
        |> Query.fromHtml
        |> Query.find [ Selector.tag "a" ]
        |> Event.simulate click
        |> Event.toResult


{-| A click event with the fields the browser sends.
-}
clickWith : List ( String, Encode.Value ) -> ( String, Encode.Value )
clickWith fields =
    Event.custom "click" (Encode.object fields)


listLinkTests : Test
listLinkTests =
    let
        sends name click =
            test name <|
                \_ -> clickOnLink click (linkRow []) |> Expect.equal (Ok Opened)

        sendsNothing name click =
            test name <|
                \_ -> clickOnLink click (linkRow []) |> Result.toMaybe |> Expect.equal Nothing
    in
    describe "ListItem: a row with href and onClick"
        [ test "is still a link to the address" <|
            \_ ->
                linkRow []
                    |> Query.fromHtml
                    |> Query.find [ Selector.tag "a" ]
                    |> Query.has [ Selector.attribute (Attr.href "#/orders/1") ]
        , test "is a link and not a button" <|
            \_ ->
                linkRow []
                    |> Expect.all
                        [ howMany [ Selector.tag "a" ] 1
                        , howMany [ Selector.tag "button" ] 0
                        ]
        , sends "a click with no details sends the message" Event.click
        , sends "a click of the main button with no keys sends the message"
            (clickWith
                [ ( "button", Encode.int 0 )
                , ( "ctrlKey", Encode.bool False )
                , ( "metaKey", Encode.bool False )
                , ( "shiftKey", Encode.bool False )
                , ( "altKey", Encode.bool False )
                ]
            )
        , sendsNothing "a click with Ctrl (open in a new tab) sends nothing" (clickWith [ ( "ctrlKey", Encode.bool True ) ])
        , sendsNothing "a click with Cmd sends nothing" (clickWith [ ( "metaKey", Encode.bool True ) ])
        , sendsNothing "a click with Shift (open in a new window) sends nothing" (clickWith [ ( "shiftKey", Encode.bool True ) ])
        , sendsNothing "a click with Alt (download) sends nothing" (clickWith [ ( "altKey", Encode.bool True ) ])
        , sendsNothing "a click of the middle button sends nothing" (clickWith [ ( "button", Encode.int 1 ) ])
        , test "the click handler never prevents the default action, so the link is followed" <|
            \_ ->
                linkRow []
                    |> Query.fromHtml
                    |> Query.find [ Selector.tag "a" ]
                    |> Event.simulate Event.click
                    |> Event.expectNotPreventDefault
        , test "the click handler does not stop the event from reaching other listeners" <|
            \_ ->
                linkRow []
                    |> Query.fromHtml
                    |> Query.find [ Selector.tag "a" ]
                    |> Event.simulate Event.click
                    |> Event.expectNotStopPropagation
        , test "a row with only an href has no click handler" <|
            \_ ->
                ListItem.view [ ListItem.href "#/orders/1" ] "Order 1"
                    |> Query.fromHtml
                    |> Query.find [ Selector.tag "a" ]
                    |> Event.simulate Event.click
                    |> Event.toResult
                    |> Result.toMaybe
                    |> Expect.equal Nothing
        , test "a row with only an onClick is a button that sends the message" <|
            \_ ->
                ListItem.view [ ListItem.onClick Opened ] "Order 1"
                    |> Query.fromHtml
                    |> Query.find [ Selector.tag "button" ]
                    |> Event.simulate Event.click
                    |> Event.expect Opened
        , test "a disabled row stays a link (so it keeps the focus), without its address" <|
            \_ ->
                linkRow [ ListItem.disabled True ]
                    |> Expect.all
                        [ howMany [ Selector.tag "a", Selector.attribute (Attr.attribute "aria-disabled" "true") ] 1
                        , howMany [ Selector.tag "a", Selector.attribute (Attr.href "#/orders/1") ] 0
                        , howMany [ Selector.tag "button" ] 0
                        ]
        ]



-- LISTITEM: aria-label only where it can be used


listLabelTests : Test
listLabelTests =
    describe "ListItem.rowAriaLabel"
        [ test "names a row that is a button" <|
            \_ ->
                ListItem.view [ ListItem.onClick Opened, ListItem.rowAriaLabel "Open order 1" ] "Order 1"
                    |> howMany [ Selector.tag "button", ariaLabel "Open order 1" ] 1
        , test "names a row that is a link" <|
            \_ ->
                ListItem.view [ ListItem.href "#/orders/1", ListItem.rowAriaLabel "Open order 1" ] "Order 1"
                    |> howMany [ Selector.tag "a", ariaLabel "Open order 1" ] 1
        , test "names a row that is a link with an onClick" <|
            \_ ->
                linkRow [ ListItem.rowAriaLabel "Open order 1" ]
                    |> howMany [ Selector.tag "a", ariaLabel "Open order 1" ] 1
        , test "a plain row has no aria-label: a div has no role that can take one" <|
            \_ ->
                ListItem.view [ ListItem.rowAriaLabel "Order 1, shipped" ] "Order 1"
                    |> howMany [ ariaLabel "Order 1, shipped" ] 0
        , test "a disabled row stays a button, so it keeps its name" <|
            \_ ->
                ListItem.view [ ListItem.onClick Opened, ListItem.disabled True, ListItem.rowAriaLabel "Open order 1" ] "Order 1"
                    |> howMany [ Selector.tag "button", ariaLabel "Open order 1" ] 1
        , test "a plain row still shows its title" <|
            \_ ->
                ListItem.view [ ListItem.rowAriaLabel "Order 1, shipped" ] "Order 1"
                    |> howMany [ Selector.class "klar-list-item__title", Selector.exactText "Order 1" ] 1
        ]



-- JSONVIEWER: a viewer that scrolls


jsonScrollTests : Test
jsonScrollTests =
    let
        viewer attributes =
            JsonViewer.view FromViewer
                attributes
                (JsonViewer.init "response")
                (Encode.object [ ( "id", Encode.int 1 ) ])

        scrollArea attributes =
            viewer attributes |> Query.fromHtml |> Query.find [ Selector.class "klar-json__scroll" ]
    in
    describe "JsonViewer: an ARIA tree with one tab stop, also when it scrolls"
        [ test "the scroll area is no extra, nameless tab stop: the keyboard scrolls by moving from row to row" <|
            \_ -> scrollArea [ JsonViewer.maxHeight 200 ] |> Query.hasNot [ Selector.attribute (Attr.tabindex 0), role "region" ]
        , test "the tree has exactly one tab stop" <|
            \_ ->
                viewer [ JsonViewer.maxHeight 200 ]
                    |> howMany [ focusable ] 1
        , test "the tree carries the name, once" <|
            \_ ->
                viewer [ JsonViewer.maxHeight 200, JsonViewer.ariaLabel "API response" ]
                    |> Expect.all
                        [ \html -> html |> Query.fromHtml |> Query.find [ role "tree" ] |> Query.has [ ariaLabel "API response" ]
                        , howMany [ ariaLabel "API response" ] 1
                        ]
        , test "without a name the tree is called JSON" <|
            \_ -> viewer [] |> Query.fromHtml |> Query.find [ role "tree" ] |> Query.has [ ariaLabel "JSON" ]
        , test "the toolbar still has its texts in English" <|
            \_ ->
                viewer [ JsonViewer.toolbar ]
                    |> Expect.all
                        [ howMany [ Selector.text "Expand all" ] 1
                        , howMany [ Selector.text "Collapse all" ] 1
                        ]
        , test "and in Norwegian" <|
            \_ ->
                viewer [ JsonViewer.toolbar, JsonViewer.locale Locale.nb ]
                    |> Expect.all
                        [ howMany [ Selector.text "Utvid alle" ] 1
                        , howMany [ Selector.text "Skjul alle" ] 1
                        ]
        ]



-- EMPTYSTATE and ERRORSTATE: no empty headline


emptyTitleTests : Test
emptyTitleTests =
    let
        title =
            [ Selector.class "klar-state__title" ]

        serverProblem =
            Remote.problem Remote.server
    in
    describe "An empty title renders no headline element"
        [ test "EmptyState with a title has one" <|
            \_ ->
                EmptyState.view [ EmptyState.title "No orders yet" ]
                    |> howMany (title ++ [ Selector.exactText "No orders yet" ]) 1
        , test "EmptyState with no title says that there is nothing to show" <|
            \_ -> EmptyState.view [] |> howMany (title ++ [ Selector.exactText "Nothing to show" ]) 1
        , test "EmptyState with an empty title has none" <|
            \_ -> EmptyState.view [ EmptyState.title "" ] |> howMany title 0
        , test "EmptyState with a title of spaces has none" <|
            \_ -> EmptyState.view [ EmptyState.title "   " ] |> howMany title 0
        , test "the icon, the description and the action are still there without a title" <|
            \_ ->
                EmptyState.view
                    [ EmptyState.title ""
                    , EmptyState.description "Try again later."
                    , EmptyState.actions [ Html.button [] [ Html.text "Reload" ] ]
                    ]
                    |> Expect.all
                        [ howMany [ Selector.class "klar-state__description" ] 1
                        , howMany [ Selector.class "klar-state__actions" ] 1
                        , howMany [ Selector.class "klar-state__icon" ] 1
                        ]
        , test "a later title replaces an empty one" <|
            \_ ->
                EmptyState.view [ EmptyState.title "", EmptyState.title "No orders yet" ]
                    |> howMany title 1
        , test "ErrorState shows the title of its problem" <|
            \_ ->
                ErrorState.view [] serverProblem
                    |> howMany (title ++ [ Selector.exactText "Something went wrong on our side" ]) 1
        , test "ErrorState with an empty title has no headline" <|
            \_ ->
                ErrorState.view [] (Remote.withTitle "" serverProblem)
                    |> howMany title 0
        , test "ErrorState without a title still shows the detail" <|
            \_ ->
                ErrorState.view [] (Remote.withTitle "" serverProblem)
                    |> howMany [ Selector.class "klar-state__description" ] 1
        ]



-- CARD: headingLevel


cardHeadingTests : Test
cardHeadingTests =
    let
        titleOf attributes =
            Card.view (Card.title "Recent activity" :: attributes) [ Html.text "content" ]
                |> Query.fromHtml
                |> Query.find [ Selector.class "klar-card__title" ]

        levelTest level expected =
            test ("headingLevel " ++ String.fromInt level ++ " makes an " ++ expected) <|
                \_ ->
                    titleOf [ Card.headingLevel level ]
                        |> Query.has [ Selector.tag expected, Selector.exactText "Recent activity" ]
    in
    describe "Card.headingLevel"
        [ test "the default is an h2, the level under the h1 of a PageHeader" <|
            \_ -> titleOf [] |> Query.has [ Selector.tag "h2" ]
        , levelTest 1 "h1"
        , levelTest 2 "h2"
        , levelTest 3 "h3"
        , levelTest 4 "h4"
        , levelTest 5 "h5"
        , levelTest 6 "h6"
        , levelTest 0 "h1"
        , levelTest -3 "h1"
        , levelTest 7 "h6"
        , levelTest 100 "h6"
        , test "the order of the attributes does not matter" <|
            \_ ->
                Card.view [ Card.headingLevel 2, Card.title "Recent activity" ] []
                    |> howMany [ Selector.tag "h2", Selector.exactText "Recent activity" ] 1
        , test "the last headingLevel wins" <|
            \_ -> titleOf [ Card.headingLevel 2, Card.headingLevel 4 ] |> Query.has [ Selector.tag "h4" ]
        , test "there is only one heading in the card, whatever the level" <|
            \_ ->
                Card.view [ Card.title "Recent activity", Card.headingLevel 5 ] [ Html.text "content" ]
                    |> Expect.all
                        [ howMany [ Selector.tag "h5" ] 1
                        , howMany [ Selector.tag "h3" ] 0
                        , howMany [ Selector.class "klar-card__title" ] 1
                        ]
        , test "a card without a title has no heading, whatever the level" <|
            \_ ->
                Card.view [ Card.headingLevel 2, Card.subtitle "Last 30 days" ] []
                    |> Expect.all
                        [ howMany [ Selector.class "klar-card__title" ] 0
                        , howMany [ Selector.tag "h1" ] 0
                        , howMany [ Selector.tag "h2" ] 0
                        , howMany [ Selector.tag "h3" ] 0
                        ]
        , test "an empty title renders no heading, but the subtitle stays" <|
            \_ ->
                Card.view [ Card.title "", Card.subtitle "Last 30 days" ] []
                    |> Expect.all
                        [ howMany [ Selector.class "klar-card__title" ] 0
                        , howMany [ Selector.class "klar-card__subtitle" ] 1
                        ]
        , test "an empty title and nothing else renders no header" <|
            \_ -> Card.view [ Card.title "" ] [] |> howMany [ Selector.class "klar-card__header" ] 0
        ]



-- PROGRESS: value and outOf, in whatever order


progressValueTests : Test
progressValueTests =
    let
        bar attributes =
            Progress.view (attributes ++ [ Progress.showValue ])

        shown text html =
            html
                |> Query.fromHtml
                |> Query.find [ Selector.class "klar-progress__value" ]
                |> Query.has [ Selector.exactText text ]

        ariaNow n =
            attr "aria-valuenow" (String.fromInt n)

        ariaText text =
            attr "aria-valuetext" text
    in
    describe "Progress: the last of value and outOf wins"
        [ test "value after outOf replaces the 3 of 5 text" <|
            \_ -> bar [ Progress.outOf 3 5, Progress.value 80 ] |> shown "80%"
        , test "value after outOf also moves the bar and the aria values" <|
            \_ -> bar [ Progress.outOf 3 5, Progress.value 80 ] |> has [ ariaNow 80, ariaText "80%" ]
        , test "outOf after value gives the 3 of 5 text" <|
            \_ -> bar [ Progress.value 80, Progress.outOf 3 5 ] |> shown "3 of 5"
        , test "outOf after value also moves the bar and the aria values" <|
            \_ -> bar [ Progress.value 80, Progress.outOf 3 5 ] |> has [ ariaNow 60, ariaText "3 of 5" ]
        , test "outOf, value and outOf again: the last one wins" <|
            \_ -> bar [ Progress.outOf 3 5, Progress.value 80, Progress.outOf 1 4 ] |> shown "1 of 4"
        , test "outOf, outOf and value: the value wins" <|
            \_ -> bar [ Progress.outOf 3 5, Progress.outOf 1 4, Progress.value 50 ] |> shown "50%"
        , test "valueText wins after value" <|
            \_ -> bar [ Progress.value 30, Progress.valueText "12 of 40 hours" ] |> shown "12 of 40 hours"
        , test "valueText wins before value" <|
            \_ -> bar [ Progress.valueText "12 of 40 hours", Progress.value 30 ] |> shown "12 of 40 hours"
        , test "valueText wins before outOf" <|
            \_ -> bar [ Progress.valueText "12 of 40 hours", Progress.outOf 3 5 ] |> shown "12 of 40 hours"
        , test "valueText is also the aria-valuetext, and the bar still follows the value" <|
            \_ ->
                bar [ Progress.valueText "12 of 40 hours", Progress.value 30 ]
                    |> has [ ariaText "12 of 40 hours", ariaNow 30 ]
        , test "value after indeterminate makes the bar determinate again" <|
            \_ -> bar [ Progress.indeterminate, Progress.value 40 ] |> has [ ariaNow 40 ]
        , test "outOf after indeterminate makes the bar determinate again" <|
            \_ -> bar [ Progress.indeterminate, Progress.outOf 2 4 ] |> has [ ariaNow 50 ]
        , test "indeterminate after value wins: no aria-valuenow and no value text" <|
            \_ ->
                bar [ Progress.value 40, Progress.indeterminate ]
                    |> Expect.all
                        [ has [ Selector.class "klar-progress--indeterminate" ]
                        , hasNot [ ariaNow 40 ]
                        , howMany [ Selector.class "klar-progress__value" ] 0
                        ]
        , test "the ring follows the same rule" <|
            \_ ->
                Progress.ring [ Progress.outOf 3 5, Progress.value 80 ]
                    |> Query.fromHtml
                    |> Query.find [ Selector.class "klar-progress-ring__value" ]
                    |> Query.has [ Selector.exactText "80%" ]
        ]



-- PROGRESS: an indeterminate bar with steps


progressSegmentTests : Test
progressSegmentTests =
    let
        segment =
            Selector.class "klar-progress__segment"

        filled =
            Selector.class "klar-progress__segment--filled"

        step n =
            attr "style" ("--klar-seg:" ++ String.fromInt n)
    in
    describe "Progress.segments"
        [ test "a bar with steps fills the steps of its value" <|
            \_ ->
                Progress.view [ Progress.value 60, Progress.segments 5 ]
                    |> Expect.all
                        [ howMany [ segment ] 5
                        , howMany [ filled ] 3
                        ]
        , test "a bar with steps has no wave" <|
            \_ ->
                Progress.view [ Progress.value 60, Progress.segments 5 ]
                    |> Expect.all
                        [ howMany [ step 1 ] 0
                        , howMany [ attr "style" "--klar-segs:5" ] 0
                        ]
        , test "an indeterminate bar with steps fills none of them, whatever its value was" <|
            \_ ->
                Progress.view [ Progress.value 60, Progress.segments 5, Progress.indeterminate ]
                    |> Expect.all
                        [ howMany [ segment ] 5
                        , howMany [ filled ] 0
                        ]
        , test "an indeterminate bar with steps knows the place of every step in the wave" <|
            \_ ->
                let
                    steps =
                        Progress.view [ Progress.segments 5, Progress.indeterminate ]
                            |> inDiv
                            |> Query.findAll [ segment ]
                in
                Expect.all
                    (List.map (\n () -> steps |> Query.index (n - 1) |> Query.has [ step n ]) (List.range 1 5))
                    ()
        , test "and the row of steps says how many there are" <|
            \_ ->
                Progress.view [ Progress.segments 5, Progress.indeterminate ]
                    |> howMany [ Selector.class "klar-progress__segments", attr "style" "--klar-segs:5" ] 1
        , test "it is still announced as a progress bar, with no value" <|
            \_ ->
                Progress.view [ Progress.label "Importing", Progress.segments 5, Progress.indeterminate ]
                    |> Expect.all
                        [ has [ role "progressbar", ariaLabel "Importing" ]
                        , hasNot [ attr "aria-valuenow" "0" ]
                        , hasNot [ attr "aria-valuetext" "0%" ]
                        ]
        , test "a value after indeterminate fills the steps again" <|
            \_ ->
                Progress.view [ Progress.segments 5, Progress.indeterminate, Progress.value 60 ]
                    |> Expect.all
                        [ howMany [ filled ] 3
                        , howMany [ step 1 ] 0
                        ]
        ]



-- AVATAR: groups


people : List Avatar.Entry
people =
    List.map Avatar.entry [ "Ada Lovelace", "Grace Hopper", "Alan Turing", "Edsger Dijkstra", "Barbara Liskov" ]


avatarGroupNameTests : Test
avatarGroupNameTests =
    let
        named locale count expected =
            test (expected ++ " (" ++ Locale.toCode locale ++ ")") <|
                \_ ->
                    Avatar.group [ Avatar.locale locale ] (List.take count people)
                        |> has [ role "group", ariaLabel expected ]
    in
    describe "The name of an Avatar.group counts avatars, in words that fit people, organizations and systems"
        [ named Locale.en 1 "1 avatar"
        , named Locale.en 2 "2 avatars"
        , named Locale.en 5 "5 avatars"
        , named Locale.nb 1 "1 avatar"
        , named Locale.nb 2 "2 avatarer"
        , named Locale.nb 5 "5 avatarer"
        , test "the count includes the avatars behind the +N bubble" <|
            \_ -> Avatar.group [ Avatar.maxShown 2 ] people |> has [ role "group", ariaLabel "5 avatars" ]
        , test "the default is English" <|
            \_ -> Avatar.group [] (List.take 3 people) |> has [ ariaLabel "3 avatars" ]
        , test "the bubble still names the avatars it hides" <|
            \_ ->
                Avatar.group [ Avatar.maxShown 2 ] people
                    |> howMany [ Selector.class "klar-avatar--more", role "img", ariaLabel "3 more: Alan Turing, Edsger Dijkstra, Barbara Liskov" ] 1
        , test "in Norwegian too" <|
            \_ ->
                Avatar.group [ Avatar.maxShown 4, Avatar.locale Locale.nb ] people
                    |> howMany [ Selector.class "klar-avatar--more", role "img", ariaLabel "1 til: Barbara Liskov" ] 1
        ]



-- AVATAR: decorative groups


avatarDecorativeTests : Test
avatarDecorativeTests =
    let
        decorativeGroup =
            Avatar.group [ Avatar.maxShown 2, Avatar.decorative ] people
    in
    describe "Avatar.decorative on a group"
        [ test "a group that is not decorative is one group, with an image for every avatar and for the bubble" <|
            \_ ->
                Avatar.group [ Avatar.maxShown 2 ] people
                    |> Expect.all
                        [ howMany [ role "group" ] 1
                        , howMany [ role "img" ] 3
                        ]
        , test "a decorative group hides itself: the first hidden element is the group" <|
            \_ ->
                decorativeGroup
                    |> inDiv
                    |> Query.findAll [ ariaHidden ]
                    |> Query.first
                    |> Query.has [ Selector.class "klar-avatar-group" ]
        , test "and is no longer a group with a name" <|
            \_ ->
                decorativeGroup
                    |> Expect.all
                        [ hasNot [ role "group" ]
                        , hasNot [ ariaLabel "5 avatars" ]
                        ]
        , test "its +N bubble is hidden too: the bubble and its text are two hidden elements" <|
            \_ ->
                decorativeGroup
                    |> howMany [ Selector.class "klar-avatar--more", ariaHidden ] 2
        , test "and the bubble is no image with a name" <|
            \_ ->
                decorativeGroup
                    |> Expect.all
                        [ howMany [ Selector.class "klar-avatar--more", role "img" ] 0
                        , hasNot [ ariaLabel "3 more: Alan Turing, Edsger Dijkstra, Barbara Liskov" ]
                        ]
        , test "no element of a decorative group has a role or a name" <|
            \_ ->
                decorativeGroup
                    |> Expect.all
                        [ hasNot [ role "group" ]
                        , hasNot [ role "img" ]
                        , hasNot [ ariaLabel "Ada Lovelace" ]
                        , hasNot [ ariaLabel "Grace Hopper" ]
                        ]
        , test "the tooltip with the hidden names stays for the mouse" <|
            \_ ->
                decorativeGroup
                    |> howMany [ Selector.class "klar-avatar--more", Selector.attribute (Attr.title "Alan Turing, Edsger Dijkstra, Barbara Liskov") ] 1
        , test "a single decorative avatar is hidden as before" <|
            \_ ->
                Avatar.view [ Avatar.decorative ] "Ada Lovelace"
                    |> Expect.all
                        [ howMany [ Selector.class "klar-avatar", ariaHidden ] 2
                        , hasNot [ role "img" ]
                        ]
        ]



-- AVATAR: what an entry brings


avatarEntryTests : Test
avatarEntryTests =
    let
        grace =
            Avatar.entry "Grace Hopper" |> Avatar.withImage "/images/grace.jpg"
    in
    describe "Avatar.group: pictures and status"
        [ test "an entry with a picture shows it" <|
            \_ ->
                Avatar.group [] [ grace, Avatar.entry "Ada Lovelace" ]
                    |> inDiv
                    |> Query.findAll [ Selector.class "klar-avatar__image" ]
                    |> Expect.all
                        [ Query.count (Expect.equal 1)
                        , Query.index 0 >> Query.has [ attr "style" "background-image:url(\"/images/grace.jpg\")" ]
                        ]
        , test "an entry without a picture shows the initials" <|
            \_ ->
                Avatar.group [] [ Avatar.entry "Ada Lovelace" ]
                    |> Expect.all
                        [ howMany [ Selector.class "klar-avatar__image" ] 0
                        , howMany [ Selector.class "klar-avatar__initials", Selector.exactText "AL" ] 1
                        ]
        , test "the image attribute is for single avatars: it adds no picture to the entries" <|
            \_ ->
                Avatar.group [ Avatar.image "/images/everyone.jpg" ] [ Avatar.entry "Ada Lovelace" ]
                    |> howMany [ Selector.class "klar-avatar__image" ] 0
        , test "the status attribute is for single avatars: no entry gets a dot or a status in its name" <|
            \_ ->
                Avatar.group [ Avatar.status Avatar.online ] [ Avatar.entry "Ada Lovelace" ]
                    |> Expect.all
                        [ howMany [ Selector.class "klar-avatar__status" ] 0
                        , howMany [ ariaLabel "Ada Lovelace" ] 1
                        ]
        , test "a single avatar shows its status" <|
            \_ ->
                Avatar.view [ Avatar.status Avatar.online ] "Ada Lovelace"
                    |> Expect.all
                        [ howMany [ ariaLabel "Ada Lovelace, online" ] 1
                        , howMany [ Selector.class "klar-avatar__status--online" ] 1
                        ]
        ]
