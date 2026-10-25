module FreshnessAdoptionTest exposing (suite)

{-| The components that draw their data with `Freshness.wrap` keep the same elements
around it whether the data is fresh, refreshing or old, so a refresh that starts or
ends never replaces the content (and an element in it that has the focus keeps it).
-}

import Expect
import Html exposing (Html)
import Html.Attributes as Attr
import Klar.ListItem as ListItem
import Klar.Remote as Remote exposing (Remote(..))
import Klar.RemoteView as RemoteView
import Test exposing (Test, describe, test)
import Test.Html.Query as Query
import Test.Html.Selector as Selector
import Time


type Msg
    = Retry


at : Int -> Time.Posix
at minutes =
    Time.millisToPosix (minutes * 60 * 1000)


{-| The data in the three states that show it: fresh, refreshing, and old after a
failed refresh.
-}
states : a -> List ( String, Remote a )
states data =
    let
        fresh =
            Remote.refreshWith Loading (Ok data) (at 845)
    in
    [ ( "fresh", fresh )
    , ( "refreshing", Remote.refresh fresh )
    , ( "old", Remote.refreshWith (Remote.refresh fresh) (Err (Remote.problem Remote.network)) (at 900) )
    ]


{-| The element around the data, the slot of the marker first and the data second,
in every state.
-}
sameTree : String -> (Query.Single Msg -> Query.Single Msg) -> Query.Single Msg -> Expect.Expectation
sameTree boxClass content =
    Expect.all
        [ Query.has [ Selector.tag "div", Selector.class "klar-fresh", Selector.class boxClass ]
        , Query.children [] >> Query.count (Expect.equal 2)
        , Query.children [] >> Query.index 0 >> Query.has [ Selector.class "klar-fresh__slot" ]
        , Query.children [] >> Query.index 1 >> content >> Query.has [ Selector.tag "input", Selector.id "note" ]
        ]


suite : Test
suite =
    describe "Freshness.wrap in the components"
        [ describe "RemoteView keeps the same elements around the body"
            (List.map
                (\( name, data ) ->
                    test name <|
                        \_ ->
                            Html.div []
                                (RemoteView.view [ RemoteView.onRetry Retry ]
                                    data
                                    (\note -> [ Html.input [ Attr.id "note", Attr.value note ] [] ])
                                )
                                |> Query.fromHtml
                                |> Expect.all
                                    [ Query.children [] >> Query.count (Expect.equal 1)
                                    , Query.children [] >> Query.first >> sameTree "klar-remote-body" identity
                                    ]
                )
                (states "Ring the customer")
            )
        , describe "ListItem.remote keeps the same elements around the list"
            (List.map
                (\( name, data ) ->
                    test name <|
                        \_ ->
                            ListItem.remote [ ListItem.onRetry Retry ]
                                (\note -> Html.input [ Attr.id "note", Attr.value note ] [])
                                data
                                |> Query.fromHtml
                                |> sameTree "klar-list-fresh" (Query.find [ Selector.id "note" ])
                )
                (states [ "Order 1" ])
            )
        , test "the marker of old data is in the slot, the content stays second" <|
            \_ ->
                case List.reverse (states [ "Order 1" ]) of
                    ( _, data ) :: _ ->
                        ListItem.remote [ ListItem.onRetry Retry ]
                            (\note -> Html.input [ Attr.id "note", Attr.value note ] [])
                            data
                            |> Query.fromHtml
                            |> Query.children []
                            |> Query.index 0
                            |> Query.has [ Selector.class "klar-stale", Selector.text "Try again" ]

                    [] ->
                        Expect.fail "no states"
        ]
