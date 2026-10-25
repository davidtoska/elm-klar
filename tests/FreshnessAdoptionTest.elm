module FreshnessAdoptionTest exposing (suite)

{-| The components that show remote data keep the same elements around it whether
the data is fresh, refreshing or old, so a refresh that starts or ends never replaces
the content (and an element in it that has the focus keeps it).
-}

import Expect
import Html
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


suite : Test
suite =
    describe "remote data in the components"
        [ describe "RemoteView keeps one body element around the content"
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
                                    , Query.children [] >> Query.first >> Query.has [ Selector.tag "div", Selector.class "klar-remote-body" ]
                                    , Query.children [] >> Query.first >> Query.find [ Selector.id "note" ] >> Query.has [ Selector.tag "input" ]
                                    ]
                )
                (states "Ring the customer")
            )
        , describe "ListItem.viewRemote keeps the rows in every state"
            (List.map
                (\( name, data ) ->
                    test name <|
                        \_ ->
                            ListItem.viewRemote [ ListItem.onRetry Retry ]
                                (Remote.map (List.map (\note -> ( note, Html.input [ Attr.id "note", Attr.value note ] [] ))) data)
                                |> Query.fromHtml
                                |> Query.find [ Selector.id "note" ]
                                |> Query.has [ Selector.tag "input" ]
                )
                (states [ "Order 1" ])
            )
        , test "old data after a failed refresh offers a retry next to the rows" <|
            \_ ->
                case List.reverse (states [ "Order 1" ]) of
                    ( _, data ) :: _ ->
                        ListItem.viewRemote [ ListItem.onRetry Retry ]
                            (Remote.map (List.map (\note -> ( note, Html.input [ Attr.id "note", Attr.value note ] [] ))) data)
                            |> Query.fromHtml
                            |> Query.has [ Selector.text "Try again" ]

                    [] ->
                        Expect.fail "no states"
        ]
