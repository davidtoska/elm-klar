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
import Klar.EmptyState as EmptyState
import Klar.Locale as Locale
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


{-| The states with data: fresh, refreshing, old, and old while it is refreshed again.
-}
dataStates : List ( String, Remote String )
dataStates =
    let
        old =
            Remote.refreshWith (Loaded "data") (Err (Remote.problem Remote.server)) (Time.millisToPosix 0)
    in
    [ ( "fresh", Loaded "data" )
    , ( "fresh with a time", Remote.refreshWith Loading (Ok "data") (Time.millisToPosix 0) )
    , ( "refreshing", Remote.refresh (Loaded "data") )
    , ( "old", old )
    , ( "old and refreshing", Remote.refresh old )
    ]


roleStatus : Selector.Selector
roleStatus =
    Selector.attribute (Attr.attribute "role" "status")


ariaBusy : Selector.Selector
ariaBusy =
    Selector.attribute (Attr.attribute "aria-busy" "true")


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
        , test "without an id there is no id" <|
            \_ ->
                body [] (Loaded "data")
                    |> Query.fromHtml
                    |> Query.hasNot [ Selector.id "supplier" ]
        , describe "the body is one element in every state, with the live region first"
            (states
                |> List.map
                    (\( name, data ) ->
                        test name <|
                            \_ ->
                                body [] data
                                    |> Query.fromHtml
                                    |> Query.children []
                                    |> Expect.all
                                        [ Query.count (Expect.equal 1)
                                        , Query.first >> Query.has [ Selector.tag "div", Selector.class "klar-remote-body" ]
                                        , Query.first >> Query.children [] >> Query.first >> Query.has [ Selector.tag "span", roleStatus ]
                                        ]
                    )
            )
        , describe "the data keeps its parent when a refresh starts, fails and ends"
            (dataStates
                |> List.map
                    (\( name, data ) ->
                        test name <|
                            \_ ->
                                -- Fresh, refreshing and old data: the same element, and the
                                -- nodes of the body are its own children (the marker of old
                                -- data is one node that is empty text while the data is
                                -- fresh), so Elm patches them in place and focus stays.
                                body [] data
                                    |> Query.fromHtml
                                    |> Query.children []
                                    |> Query.first
                                    |> Query.children [ Selector.tag "p" ]
                                    |> Query.first
                                    |> Query.has [ Selector.text "data" ]
                    )
            )
        , test "while loading the live region says what is loading, outside the busy placeholder" <|
            \_ ->
                body [ RemoteView.loadingLabel "Loading supplier" ] Loading
                    |> Query.fromHtml
                    |> Expect.all
                        [ Query.find [ roleStatus ] >> Query.has [ Selector.text "Loading supplier" ]
                        , Query.findAll [ ariaBusy ] >> Query.count (Expect.equal 1)
                        , Query.findAll [ ariaBusy ] >> Query.each (Query.hasNot [ roleStatus ])
                        ]
        , test "with data the live region is quiet" <|
            \_ ->
                body [] (Loaded "data")
                    |> Query.fromHtml
                    |> Query.find [ roleStatus ]
                    |> Query.hasNot [ Selector.text "Loading" ]
        , test "a body function that draws nothing says so" <|
            \_ ->
                Html.div [] (RemoteView.view [] (Loaded []) (List.map (\text -> Html.p [] [ Html.text text ])))
                    |> Query.fromHtml
                    |> Query.has [ Selector.class "klar-state--empty", Selector.text "Nothing to show" ]
        , test "emptyState says it your way, in the language of the body" <|
            \_ ->
                Html.div []
                    (RemoteView.view
                        [ RemoteView.locale Locale.nb, RemoteView.emptyState [ EmptyState.description "Add the first note." ] ]
                        (Loaded [])
                        (List.map (\text -> Html.p [] [ Html.text text ]))
                    )
                    |> Query.fromHtml
                    |> Query.has [ Selector.text "Ingenting å vise", Selector.text "Add the first note." ]
        , test "a body with nodes has no empty state" <|
            \_ ->
                body [] (Loaded "data")
                    |> Query.fromHtml
                    |> Query.hasNot [ Selector.class "klar-state--empty" ]
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
