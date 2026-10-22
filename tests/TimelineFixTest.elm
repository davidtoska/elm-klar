module TimelineFixTest exposing (suite)

{-| Benchmark run 1, T10: no "Load more" button when there is nothing more, the level of
the day headings, and an id that can take focus.
-}

import Expect
import Html.Attributes
import Klar.Timeline as Timeline
import Test exposing (Test, describe, test)
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
            \_ -> timeline [ Timeline.onLoadMore More ] |> Query.has [ Selector.text "Load more" ]
        , test "when there is nothing more the button is gone, not dimmed" <|
            \_ ->
                timeline [ Timeline.onLoadMore More, Timeline.hasMore False ]
                    |> Expect.all
                        [ Query.hasNot [ Selector.tag "button" ]
                        , Query.has [ Selector.text "No more events" ]
                        ]
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
                        , [ Timeline.id "log", Timeline.loading True ]
                        , [ Timeline.id "log", Timeline.hasMore False, Timeline.onLoadMore More ]
                        ]
                    )
                    ()
        ]
