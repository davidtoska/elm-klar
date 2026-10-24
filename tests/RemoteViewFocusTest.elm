module RemoteViewFocusTest exposing (suite)

{-| `RemoteView.id` draws one element that can take focus in every state, so that
`Klar.focus` has a place to put it after "Try again". And the pattern for a page that
is only a `RemoteView`: the page title is drawn outside the body, so there is one `h1` in
every state.
-}

import Expect
import Html exposing (Html)
import Html.Attributes as Attr
import Klar
import Klar.PageHeader as PageHeader
import Klar.Remote as Remote exposing (Remote(..))
import Klar.RemoteView as RemoteView
import Test exposing (Test, describe, test)
import Test.Html.Query as Query
import Test.Html.Selector as Selector
import Time


states : List ( String, Remote String )
states =
    [ ( "not asked", NotAsked )
    , ( "loading", Loading )
    , ( "failed", Failed (Remote.problem Remote.server) )
    , ( "loaded", Loaded "data" )
    , ( "refreshing", Remote.refresh (Loaded "data") )
    , ( "old data", Remote.refreshWith (Loaded "data") (Err (Remote.problem Remote.server)) (Time.millisToPosix 0) )
    ]


body : List (RemoteView.Attribute ()) -> Remote String -> Html ()
body attributes data =
    Html.div [] (RemoteView.view attributes data (\text -> [ Html.p [] [ Html.text text ] ]))


page : Remote String -> Html ()
page data =
    Html.div []
        [ PageHeader.view [ PageHeader.title "Supplier" ]
        , body [ RemoteView.onRetry () ] data
        ]


suite : Test
suite =
    describe "RemoteView focus and page title"
        [ describe "the body with an id is one focusable element in every state"
            (states
                |> List.map
                    (\( name, data ) ->
                        test name <|
                            \_ ->
                                body [ RemoteView.id "supplier" ] data
                                    |> Query.fromHtml
                                    |> Query.has [ Selector.id "supplier", Selector.attribute (Attr.tabindex -1) ]
                    )
            )
        , test "without an id nothing is wrapped" <|
            \_ ->
                body [] (Loaded "data")
                    |> Query.fromHtml
                    |> Query.hasNot [ Selector.id "supplier" ]
        , describe "a page title outside the body gives one h1 in every state"
            (states
                |> List.map
                    (\( name, data ) ->
                        test name <|
                            \_ ->
                                page data
                                    |> Query.fromHtml
                                    |> Query.findAll [ Selector.tag "h1" ]
                                    |> Query.count (Expect.equal 1)
                    )
            )
        ]
