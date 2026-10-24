module TimelineFixTest exposing (suite)

{-| Benchmark run 1, T10: no "Load more" button when there is nothing more, the level of
the day headings, and an id that can take focus.
-}

import Expect
import Html.Attributes
import Klar.Locale as Locale
import Klar.Remote as Remote
import Klar.Settings as Settings
import Klar.Timeline as Timeline
import Test exposing (Test, describe, test)
import Test.Html.Event as Event
import Test.Html.Query as Query
import Test.Html.Selector as Selector
import Time


type Msg
    = More


events : List (Timeline.Event Msg)
events =
    [ Timeline.event "a" (Time.millisToPosix 1000) "Order shipped" ]


timeline : List (Timeline.Attribute Msg) -> Query.Single Msg
timeline attributes =
    Timeline.view attributes events |> Query.fromHtml


suite : Test
suite =
    describe "Timeline"
        [ test "Load more is a button while there is more" <|
            \_ -> timeline [ Timeline.loadMore More (Remote.Loaded True) ] |> Query.has [ Selector.text "Load more" ]
        , test "when there is nothing more the button stays, unavailable, so that its focus is kept" <|
            \_ ->
                timeline [ Timeline.loadMore More (Remote.Loaded False) ]
                    |> Expect.all
                        [ Query.find [ Selector.tag "button" ] >> Query.has [ Selector.attribute (Html.Attributes.attribute "aria-disabled" "true") ]
                        , Query.find [ Selector.tag "button" ] >> Query.hasNot [ Selector.disabled True ]
                        , Query.has [ Selector.text "No more events" ]
                        ]
        , test "while the next page loads the button is the same, busy and not disabled" <|
            \_ ->
                timeline [ Timeline.loadMore More Remote.Loading ]
                    |> Expect.all
                        [ Query.find [ Selector.tag "button" ] >> Query.has [ Selector.attribute (Html.Attributes.attribute "aria-busy" "true") ]
                        , Query.find [ Selector.tag "button" ] >> Query.hasNot [ Selector.disabled True ]
                        , Query.has [ Selector.text "Loading more events ..." ]
                        ]
        , test "a refresh of the next page (Remote.refresh) is loading too" <|
            \_ ->
                timeline [ Timeline.loadMore More (Remote.refresh (Remote.Loaded True)) ]
                    |> Query.has [ Selector.text "Loading more events ..." ]
        , test "a failed next page turns the button into Try again, which loads more" <|
            \_ ->
                timeline [ Timeline.loadMore More (Remote.Failed (Remote.problem Remote.server)) ]
                    |> Expect.all
                        [ Query.find [ Selector.tag "button" ] >> Query.has [ Selector.text "Try again" ]
                        , Query.find [ Selector.tag "button" ] >> Event.simulate Event.click >> Event.expect More
                        ]
        , test "with a total the footer counts against it" <|
            \_ ->
                timeline [ Timeline.loadMore More (Remote.Loaded True), Timeline.total 340 ]
                    |> Query.has [ Selector.text "Showing 1 of 340 events" ]
        , test "and in Norwegian" <|
            \_ ->
                timeline [ Timeline.loadMore More (Remote.Loaded True), Timeline.total 340, Timeline.locale Locale.nb ]
                    |> Query.has [ Selector.text "Viser 1 av 340 hendelser" ]
        , test "the day groups are keyed by their date" <|
            \_ ->
                Timeline.view [ Timeline.settings Settings.default ]
                    [ Timeline.event "b" (Time.millisToPosix (86400000 * 2)) "Later"
                    , Timeline.event "a" (Time.millisToPosix 1000) "Earlier"
                    ]
                    |> Query.fromHtml
                    |> Query.findAll [ Selector.class "klar-timeline__day" ]
                    |> Query.count (Expect.equal 2)
        , test "there is one status region in every state, so a change of its text is announced" <|
            \_ ->
                Expect.all
                    (List.map
                        (\html _ -> html |> Query.fromHtml |> Query.findAll [ Selector.attribute (Html.Attributes.attribute "role" "status"), Selector.class "klar-sr-only" ] |> Query.count (Expect.equal 1))
                        [ Timeline.viewRemote [] Remote.Loading
                        , Timeline.viewRemote [] (Remote.Loaded events)
                        , Timeline.viewRemote [] (Remote.Loaded [])
                        ]
                    )
                    ()
        , test "the day headings are h3 by default" <|
            \_ -> timeline [] |> Query.has [ Selector.tag "h3", Selector.class "klar-timeline__day-title" ]
        , test "headingLevel changes them" <|
            \_ -> timeline [ Timeline.headingLevel 2 ] |> Query.has [ Selector.tag "h2", Selector.class "klar-timeline__day-title" ]
        , test "headingLevel stays within 1 to 6" <|
            \_ -> timeline [ Timeline.headingLevel 9 ] |> Query.has [ Selector.tag "h6", Selector.class "klar-timeline__day-title" ]
        , test "an id puts the DOM id and a focus stop on the timeline in every state" <|
            \_ ->
                Expect.all
                    (List.map
                        (\attributes _ -> timeline attributes |> Query.has [ Selector.id "log", Selector.attribute (Html.Attributes.tabindex -1) ])
                        [ [ Timeline.id "log" ]
                        , [ Timeline.id "log", Timeline.loadMore More (Remote.Loaded False) ]
                        ]
                    )
                    ()
        ]
