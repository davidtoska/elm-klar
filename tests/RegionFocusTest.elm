module RegionFocusTest exposing (suite)

{-| Benchmark run 1, item 14: `Stat.id`, `Chart.id` and `Timeline.id` give the region an
element with that id that can take focus in every state, so that `Klar.focus` has
a place to put it after "Try again" (the retry button is replaced by the skeleton).
-}

import Expect
import Html exposing (Html)
import Html.Attributes
import Klar
import Klar.Chart as Chart
import Klar.Remote as Remote exposing (Remote(..))
import Klar.Stat as Stat
import Klar.Timeline as Timeline
import Test exposing (Test, describe, test)
import Test.Html.Query as Query
import Test.Html.Selector as Selector


type Msg
    = Retry


focusable : String -> Html Msg -> Expect.Expectation
focusable domId html =
    html
        |> Query.fromHtml
        |> Query.has [ Selector.id domId ]


states : List ( String, Remote Int )
states =
    [ ( "not asked", NotAsked )
    , ( "loading", Loading )
    , ( "failed", Failed (Remote.problem Remote.server) )
    , ( "loaded", Loaded 3 )
    , ( "refreshing", Remote.refresh (Loaded 3) )
    ]


suite : Test
suite =
    describe "region ids for focus after a retry"
        [ describe "Stat.id"
            (states
                |> List.map
                    (\( name, data ) ->
                        test name <|
                            \_ ->
                                Stat.view [ Stat.label "x", Stat.id "tile", Stat.onRetry Retry, Stat.remote data (\n -> [ Stat.int n ]) ]
                                    |> Query.fromHtml
                                    |> Query.has [ Selector.id "tile", Selector.attribute (Html.Attributes.tabindex -1) ]
                    )
            )
        , describe "Chart.id"
            (states
                |> List.map
                    (\( name, data ) ->
                        test name <|
                            \_ ->
                                Chart.lineRemote [ Chart.id "chart", Chart.onRetry Retry ] (Remote.map (\_ -> Chart.byCategory [] [ Chart.series "a" [ 1, 2 ] ]) data)
                                    |> Query.fromHtml
                                    |> Query.has [ Selector.id "chart", Selector.attribute (Html.Attributes.tabindex -1) ]
                    )
            )
        , describe "Timeline.id"
            (states
                |> List.map
                    (\( name, data ) ->
                        test name <|
                            \_ ->
                                Timeline.viewRemote [ Timeline.id "log", Timeline.onRetry Retry ] (Remote.map (\_ -> []) data)
                                    |> Query.fromHtml
                                    |> Query.has [ Selector.id "log", Selector.attribute (Html.Attributes.tabindex -1) ]
                    )
            )
        , test "without an id there is no extra element or tabindex" <|
            \_ ->
                Chart.lineRemote [] (Loaded (Chart.byCategory [] [ Chart.series "a" [ 1, 2 ] ]))
                    |> Query.fromHtml
                    |> Query.hasNot [ Selector.attribute (Html.Attributes.tabindex -1) ]
        ]
