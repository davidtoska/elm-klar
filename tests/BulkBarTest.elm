module BulkBarTest exposing (suite)

{-| Klar.BulkBar: nothing drawn at zero, the count in one live region that is
always there, the toolbar that the bar covers, the honest offer to select
everything, and the order of the controls.
-}

import Expect
import Fuzz
import Html exposing (Html)
import Html.Attributes as Attr
import Json.Encode as Encode
import Klar.BulkBar as BulkBar
import Klar.Button as Button
import Klar.Locale as Locale
import Support.FlowHtml as H
import Test exposing (Test, describe, fuzz, fuzz3, test)
import Test.Html.Event as Event
import Test.Html.Query as Query
import Test.Html.Selector as Selector exposing (Selector)


type Msg
    = Clear
    | SelectAll
    | Export
    | Delete
    | Search


suite : Test
suite =
    describe "Klar.BulkBar"
        [ nothingSelectedTests
        , countTests
        , coverTests
        , liveRegionTests
        , orderTests
        , offerTests
        , offerProperties
        , localeTests
        , focusTests
        ]


toolbar : Html Msg
toolbar =
    Html.input [ Attr.class "orders-search", Attr.type_ "search" ] []


bar : List (BulkBar.Attribute Msg) -> Int -> Html Msg
bar attributes selected =
    BulkBar.view attributes
        { toolbar = toolbar, selected = selected, onClear = Clear }
        [ Button.view [ Button.onClick Export ] "Export"
        , Button.view [ Button.onClick Delete ] "Delete"
        ]


everything : Int -> Int -> BulkBar.Attribute Msg
everything total onPage =
    BulkBar.selectAllMatching { total = total, onPage = onPage, onSelectAll = SelectAll }


theBar : Selector
theBar =
    Selector.class "klar-bulk__bar"


live : Selector
live =
    Selector.class "klar-bulk__live"


offerButton : Selector
offerButton =
    Selector.containing [ Selector.text "Select all" ]



-- NOTHING SELECTED


nothingSelectedTests : Test
nothingSelectedTests =
    describe "with nothing selected"
        [ test "the bar is only kept in its place: hidden, inert and without a role, so that nobody can reach or hear it" <|
            \_ ->
                bar [] 0
                    |> Expect.all
                        [ H.count 1 [ theBar ]
                        , H.inside [ theBar ] [ Selector.class "klar-bulk__bar--reserved", H.attr "aria-hidden" "true", H.attr "inert" "" ]
                        , H.none [ theBar, H.attr "role" "group" ]
                        ]
        , test "the toolbar is there and can be used" <|
            \_ ->
                bar [] 0
                    |> Expect.all
                        [ H.count 1 [ Selector.class "orders-search" ]
                        , H.none [ Selector.class "klar-bulk__under--covered" ]
                        , H.none [ Selector.class "klar-bulk__under", H.attr "inert" "" ]
                        ]
        , fuzz (Fuzz.intRange -50 0) "a count of zero or less is the same" <|
            \count ->
                bar [] count
                    |> Expect.all
                        [ H.count 1 [ Selector.class "klar-bulk__bar--reserved" ]
                        , H.none [ Selector.class "klar-bulk__under--covered" ]
                        ]
        , test "the place is kept for the bar as it looks with a page ticked: the count with the total and the offer" <|
            \_ ->
                bar [ everything 500 25 ] 0
                    |> Expect.all
                        [ H.inside [ Selector.class "klar-bulk__count" ] [ Selector.exactText "25 of 500 selected" ]
                        , H.inside [ Selector.class "klar-bulk__offer" ] [ Selector.text "Select all 500 matching" ]
                        ]
        , test "the live region says nothing about it" <|
            \_ -> bar [ everything 500 25 ] 0 |> H.inside [ live ] [ Selector.exactText "" ]
        , test "the real bar has the role again, and is not hidden" <|
            \_ ->
                bar [] 3
                    |> Expect.all
                        [ H.count 1 [ theBar ]
                        , H.none [ Selector.class "klar-bulk__bar--reserved" ]
                        , H.none [ Selector.class "klar-bulk__bar", H.attr "inert" "" ]
                        , H.count 1 [ theBar, H.attr "role" "group" ]
                        ]
        ]



-- THE COUNT


countTests : Test
countTests =
    describe "the count"
        [ test "is drawn in the bar" <|
            \_ -> bar [] 3 |> H.inside [ Selector.class "klar-bulk__count" ] [ Selector.text "3 selected" ]
        , test "one item" <|
            \_ -> bar [] 1 |> H.inside [ Selector.class "klar-bulk__count" ] [ Selector.text "1 selected" ]
        , test "is in tabular digits and hidden from assistive technology, which hears the live region" <|
            \_ -> bar [] 3 |> H.inside [ Selector.class "klar-bulk__count" ] [ Selector.class "klar-tabular", H.attr "aria-hidden" "true" ]
        , test "is of a total when the total is known and larger" <|
            \_ -> bar [ everything 12340 200 ] 200 |> H.inside [ Selector.class "klar-bulk__count" ] [ Selector.text "200 of 12,340 selected" ]
        , test "when everything is selected the bar shows the plain count and a screen reader is told 'All'" <|
            \_ ->
                bar [ everything 12340 200 ] 12340
                    |> Expect.all
                        [ H.inside [ Selector.class "klar-bulk__count" ] [ Selector.exactText "12,340 selected" ]
                        , H.inside [ live ] [ Selector.exactText "All 12,340 selected" ]
                        ]
        , test "one item of one is not 'All 1'" <|
            \_ -> bar [ everything 1 1 ] 1 |> H.inside [ live ] [ Selector.exactText "1 selected" ]
        , test "a total smaller than the count is not known: no claim about 'all' or 'of'" <|
            \_ ->
                bar [ everything 3 10 ] 30
                    |> Expect.all
                        [ H.inside [ Selector.class "klar-bulk__count" ] [ Selector.exactText "30 selected" ]
                        , H.inside [ live ] [ Selector.exactText "30 selected" ]
                        ]
        , test "a total of zero is not known either" <|
            \_ ->
                bar [ everything 0 5 ] 5
                    |> Expect.all
                        [ H.inside [ Selector.class "klar-bulk__count" ] [ Selector.exactText "5 selected" ]
                        , H.inside [ live ] [ Selector.exactText "5 selected" ]
                        , H.none [ Selector.class "klar-bulk__offer" ]
                        ]
        , test "and a negative one" <|
            \_ ->
                bar [ everything -7 5 ] 5
                    |> Expect.all
                        [ H.inside [ live ] [ Selector.exactText "5 selected" ]
                        , H.none [ Selector.class "klar-bulk__offer" ]
                        ]
        ]



-- THE COVER


coverTests : Test
coverTests =
    describe "the toolbar under the bar"
        [ test "is covered and inert while something is selected, and keeps its place" <|
            \_ ->
                bar [] 2
                    |> Expect.all
                        [ H.inside [ Selector.class "klar-bulk__under" ] [ Selector.class "klar-bulk__under--covered", H.attr "inert" "" ]
                        , H.count 1 [ Selector.class "orders-search" ]
                        ]
        , test "is the first child, and the bar the last" <|
            \_ ->
                let
                    children =
                        bar [] 2 |> Query.fromHtml |> Query.children []
                in
                Expect.all
                    [ \_ -> children |> Query.index 0 |> Query.has [ Selector.class "klar-bulk__under" ]
                    , \_ -> children |> Query.index 1 |> Query.has [ live ]
                    , \_ -> children |> Query.index 2 |> Query.has [ theBar ]
                    ]
                    ()
        , test "the live region and the toolbar keep their places at zero" <|
            \_ ->
                let
                    children =
                        bar [] 0 |> Query.fromHtml |> Query.children []
                in
                Expect.all
                    [ \_ -> children |> Query.index 0 |> Query.has [ Selector.class "klar-bulk__under" ]
                    , \_ -> children |> Query.index 1 |> Query.has [ live ]
                    ]
                    ()
        ]



-- THE LIVE REGION


liveRegionTests : Test
liveRegionTests =
    describe "the live region"
        [ test "is polite, atomic and a status" <|
            \_ ->
                bar [] 5
                    |> H.inside [ live ]
                        [ H.attr "role" "status"
                        , H.attr "aria-live" "polite"
                        , H.attr "aria-atomic" "true"
                        ]
        , test "is there before anything is selected, and empty, so that the first change is heard" <|
            \_ ->
                bar [] 0
                    |> Expect.all
                        [ H.count 1 [ live, H.attr "aria-live" "polite" ]
                        , H.none [ live, Selector.containing [ Selector.text "selected" ] ]
                        ]
        , test "says the same as the bar" <|
            \_ -> bar [ everything 500 25 ] 25 |> H.inside [ live ] [ Selector.text "25 of 500 selected" ]
        , test "is only for screen readers" <|
            \_ -> bar [] 5 |> H.inside [ live ] [ Selector.class "klar-sr-only" ]
        , test "there is one live region and it is not inside the bar" <|
            \_ ->
                bar [] 5
                    |> Expect.all
                        [ H.count 1 [ H.attr "aria-live" "polite" ]
                        , \html -> html |> Query.fromHtml |> Query.find [ theBar ] |> Query.hasNot [ Selector.containing [ H.attr "aria-live" "polite" ] ]
                        ]
        , test "the bar asks for no focus" <|
            \_ ->
                bar [] 5
                    |> Expect.all
                        [ H.none [ Selector.attribute (Attr.autofocus True) ]
                        , H.none [ Selector.attribute (Attr.tabindex -1) ]
                        ]
        ]



-- ORDER OF THE CONTROLS


orderTests : Test
orderTests =
    describe "the controls"
        [ test "the count, the offer, the actions and 'Clear selection' last" <|
            \_ ->
                let
                    buttons =
                        bar [ everything 500 25 ] 25
                            |> Query.fromHtml
                            |> Query.find [ theBar ]
                            |> Query.findAll [ Selector.tag "button" ]
                in
                Expect.all
                    [ \_ -> buttons |> Query.count (Expect.equal 4)
                    , \_ -> buttons |> Query.index 0 |> Query.has [ Selector.text "Select all 500 matching" ]
                    , \_ -> buttons |> Query.index 1 |> Query.has [ Selector.text "Export" ]
                    , \_ -> buttons |> Query.index 2 |> Query.has [ Selector.text "Delete" ]
                    , \_ -> buttons |> Query.index 3 |> Query.has [ Selector.text "Clear selection" ]
                    ]
                    ()
        , test "the count comes before every button" <|
            \_ ->
                let
                    inBar =
                        bar [] 2 |> Query.fromHtml |> Query.find [ theBar ] |> Query.children []
                in
                Expect.all
                    [ \_ -> inBar |> Query.index 0 |> Query.has [ Selector.class "klar-bulk__count" ]
                    , \_ -> inBar |> Query.index 2 |> Query.has [ Selector.class "klar-bulk__actions" ]
                    ]
                    ()
        , test "the bar is a named group" <|
            \_ ->
                bar [] 2 |> H.inside [ theBar ] [ H.attr "role" "group", H.attr "aria-label" "Actions for the selected items" ]
        , test "the actions send their messages" <|
            \_ ->
                Expect.all
                    [ \_ -> bar [] 2 |> H.sends [ Selector.tag "button", Selector.containing [ Selector.text "Export" ] ] Event.click |> Expect.equal (Ok Export)
                    , \_ -> bar [] 2 |> H.sends [ Selector.tag "button", Selector.containing [ Selector.text "Delete" ] ] Event.click |> Expect.equal (Ok Delete)
                    ]
                    ()
        , test "'Clear selection' sends onClear" <|
            \_ ->
                bar [] 2
                    |> H.sends [ Selector.tag "button", Selector.containing [ Selector.text "Clear selection" ] ] Event.click
                    |> Expect.equal (Ok Clear)
        , test "no keys are handled: the bar has no keydown listener of its own" <|
            \_ ->
                bar [] 2
                    |> H.sends [ theBar ] (Event.custom "keydown" keyEscape)
                    |> Result.toMaybe
                    |> Expect.equal Nothing
        ]


keyEscape : Encode.Value
keyEscape =
    Encode.object
        [ ( "key", Encode.string "Escape" )
        , ( "ctrlKey", Encode.bool False )
        , ( "metaKey", Encode.bool False )
        , ( "shiftKey", Encode.bool False )
        , ( "altKey", Encode.bool False )
        ]



-- THE OFFER


offerTests : Test
offerTests =
    describe "the offer to select everything"
        [ test "is made when the page is selected and more match" <|
            \_ ->
                bar [ everything 12340 25 ] 25
                    |> Expect.all
                        [ H.count 1 [ Selector.tag "button", offerButton ]
                        , H.inside [ Selector.class "klar-bulk__offer" ] [ Selector.text "Select all 12,340 matching" ]
                        ]
        , test "is not made when only part of the page is selected" <|
            \_ -> bar [ everything 12340 25 ] 24 |> H.none [ offerButton ]
        , test "is not made when the page is all there is" <|
            \_ -> bar [ everything 25 25 ] 25 |> H.none [ Selector.class "klar-bulk__offer" ]
        , test "is not made for an empty page" <|
            \_ -> bar [ everything 500 0 ] 5 |> H.none [ Selector.class "klar-bulk__offer" ]
        , test "is made when the selection spans more than a page" <|
            \_ -> bar [ everything 500 25 ] 60 |> H.count 1 [ offerButton ]
        , test "is not made without selectAllMatching" <|
            \_ -> bar [] 25 |> H.none [ Selector.class "klar-bulk__offer" ]
        , test "is not made for a total smaller than the count, nor for one below 1" <|
            \_ ->
                Expect.all
                    [ \_ -> bar [ everything 10 25 ] 30 |> H.none [ Selector.class "klar-bulk__offer" ]
                    , \_ -> bar [ everything 0 25 ] 30 |> H.none [ Selector.class "klar-bulk__offer" ]
                    , \_ -> bar [ everything -1 25 ] 30 |> H.none [ Selector.class "klar-bulk__offer" ]
                    ]
                    ()
        , test "sends onSelectAll" <|
            \_ ->
                bar [ everything 500 25 ] 25
                    |> H.sends [ Selector.tag "button", offerButton ] Event.click
                    |> Expect.equal (Ok SelectAll)
        , describe "once everything is selected"
            [ test "the button stays in its place as an inactive button that says so" <|
                \_ ->
                    bar [ everything 12340 25 ] 12340
                        |> H.inside [ Selector.tag "button", Selector.containing [ Selector.text "All matching selected" ] ] [ H.attr "aria-disabled" "true" ]
            , test "it is not disabled, so it can keep focus, and it does nothing when pressed" <|
                \_ ->
                    let
                        html =
                            bar [ everything 12340 25 ] 12340
                    in
                    Expect.all
                        [ \_ -> H.none [ Selector.class "klar-bulk__offer", Selector.containing [ Selector.disabled True ] ] html
                        , \_ -> H.sends [ Selector.tag "button", Selector.containing [ Selector.text "All matching selected" ] ] Event.click html |> Result.toMaybe |> Expect.equal Nothing
                        ]
                        ()
            , test "no 'Select all' button is left to press" <|
                \_ -> bar [ everything 12340 25 ] 12340 |> H.none [ offerButton ]
            , test "the button is the same element before and after: same parent, same place among the siblings" <|
                \_ ->
                    let
                        place html =
                            html
                                |> Query.fromHtml
                                |> Query.find [ theBar ]
                                |> Query.children []
                                |> Query.index 1
                                |> Query.find [ Selector.tag "button" ]
                    in
                    Expect.all
                        [ \_ -> place (bar [ everything 12340 25 ] 25) |> Query.has [ Selector.text "Select all 12,340 matching" ]
                        , \_ -> place (bar [ everything 12340 25 ] 12340) |> Query.has [ Selector.text "All matching selected" ]
                        , \_ -> bar [ everything 12340 25 ] 25 |> H.count 1 [ Selector.class "klar-bulk__offer" ]
                        , \_ -> bar [ everything 12340 25 ] 12340 |> H.count 1 [ Selector.class "klar-bulk__offer" ]
                        ]
                        ()
            , test "there is no taken button when the page was all there was" <|
                \_ -> bar [ everything 25 25 ] 25 |> H.none [ Selector.class "klar-bulk__offer" ]
            ]
        , test "the last selectAllMatching wins" <|
            \_ ->
                bar [ everything 500 25, everything 900 25 ] 25
                    |> H.inside [ Selector.class "klar-bulk__offer" ] [ Selector.text "Select all 900 matching" ]
        ]


offerProperties : Test
offerProperties =
    -- With nothing selected the offer is drawn only in the reserved, hidden bar (see "with nothing selected").
    describe "the offer, for any numbers"
        [ fuzz3 (Fuzz.intRange 1 400) (Fuzz.intRange -5 400) (Fuzz.intRange 0 60) "is there exactly when the page is selected and there is more to select" <|
            \selected total onPage ->
                let
                    shouldOffer =
                        onPage > 0 && selected >= onPage && total >= 1 && total > selected

                    html =
                        bar [ everything total onPage ] selected
                in
                if shouldOffer then
                    H.count 1 [ offerButton ] html

                else
                    H.none [ offerButton ] html
        , fuzz3 (Fuzz.intRange 1 400) (Fuzz.intRange -5 400) (Fuzz.intRange 0 60) "the inactive button is there exactly when everything that matches is selected and it was more than a page" <|
            \selected total onPage ->
                let
                    taken =
                        onPage > 0 && selected >= onPage && total >= 1 && total == selected && total > onPage

                    html =
                        bar [ everything total onPage ] selected
                in
                if taken then
                    H.count 1 [ Selector.tag "button", Selector.containing [ Selector.text "All matching selected" ], H.attr "aria-disabled" "true" ] html

                else
                    H.none [ Selector.text "All matching selected" ] html
        , fuzz3 (Fuzz.intRange 1 400) (Fuzz.intRange -5 400) (Fuzz.intRange 0 60) "what the bar shows and what a screen reader hears are right for any numbers, and never claim 'all' on a total that cannot be true" <|
            \selected total onPage ->
                let
                    html =
                        bar [ everything total onPage ] selected

                    shown =
                        html |> Query.fromHtml |> Query.find [ Selector.class "klar-bulk__count" ]

                    heard =
                        html |> Query.fromHtml |> Query.find [ live ]

                    plain =
                        String.fromInt selected ++ " selected"

                    ( expectedShown, expectedHeard ) =
                        if total < 1 || total < selected then
                            ( plain, plain )

                        else if selected < total then
                            let
                                partial =
                                    String.fromInt selected ++ " of " ++ String.fromInt total ++ " selected"
                            in
                            ( partial, partial )

                        else if selected > 1 then
                            ( plain, "All " ++ String.fromInt selected ++ " selected" )

                        else
                            ( plain, plain )
                in
                Expect.all
                    [ \_ -> shown |> Query.has [ Selector.exactText expectedShown ]
                    , \_ -> heard |> Query.has [ Selector.exactText expectedHeard ]
                    ]
                    ()
        ]



-- LOCALE


localeTests : Test
localeTests =
    describe "in Norwegian"
        [ test "the count" <|
            \_ -> bar [ BulkBar.locale Locale.nb ] 3 |> H.inside [ Selector.class "klar-bulk__count" ] [ Selector.exactText "3 valgt" ]
        , test "of a total, with a non-breaking space between the groups of digits" <|
            \_ ->
                bar [ BulkBar.locale Locale.nb, everything 12340 25 ] 25
                    |> H.inside [ live ] [ Selector.exactText "25 av 12\u{00A0}340 valgt" ]
        , test "all, heard by a screen reader, and the plain count in the bar" <|
            \_ ->
                bar [ BulkBar.locale Locale.nb, everything 12340 25 ] 12340
                    |> Expect.all
                        [ H.inside [ live ] [ Selector.exactText "Alle 12\u{00A0}340 valgt" ]
                        , H.inside [ Selector.class "klar-bulk__count" ] [ Selector.exactText "12\u{00A0}340 valgt" ]
                        , H.count 1 [ Selector.tag "button", Selector.containing [ Selector.text "Alle treff er valgt" ] ]
                        ]
        , test "the buttons" <|
            \_ ->
                bar [ BulkBar.locale Locale.nb, everything 12340 25 ] 25
                    |> Expect.all
                        [ H.count 1 [ Selector.tag "button", Selector.containing [ Selector.text "Velg alle 12\u{00A0}340 treff" ] ]
                        , H.count 1 [ Selector.tag "button", Selector.containing [ Selector.text "Fjern valg" ] ]
                        ]
        , test "the group" <|
            \_ -> bar [ BulkBar.locale Locale.nb ] 3 |> H.inside [ theBar ] [ H.attr "aria-label" "Handlinger for valgte elementer" ]
        , test "English is the default and uses commas" <|
            \_ -> bar [ everything 12340 25 ] 25 |> H.inside [ live ] [ Selector.exactText "25 of 12,340 selected" ]
        ]



-- FOCUS


focusTests : Test
focusTests =
    describe "focus"
        [ test "without an id nothing can take focus" <|
            \_ ->
                bar [] 3
                    |> Expect.all
                        [ H.none [ Selector.attribute (Attr.tabindex -1) ]
                        , H.none [ Selector.id "orders-bulk" ]
                        ]
        , test "with an id the box that the toolbar and the bar share can take focus" <|
            \_ -> bar [ BulkBar.id "orders-bulk" ] 3 |> H.has [ Selector.id "orders-bulk", Selector.attribute (Attr.tabindex -1), Selector.class "klar-bulk" ]
        , test "and it is on the page when nothing is selected, so that it is there when the bar has gone" <|
            \_ -> bar [ BulkBar.id "orders-bulk" ] 0 |> H.has [ Selector.id "orders-bulk", Selector.attribute (Attr.tabindex -1) ]
        , test "the bar and its buttons have no id of their own" <|
            \_ ->
                bar [ BulkBar.id "orders-bulk" ] 3
                    |> Expect.all
                        [ H.inside [ theBar ] [ Selector.tag "div" ]
                        , H.none [ Selector.id "orders-bulk" ]
                        , H.none [ Selector.attribute (Attr.tabindex -1) ]
                        ]
        , test "focus is a command" <|
            \_ -> Expect.notEqual Cmd.none (BulkBar.focus "orders-bulk" Search)
        ]
