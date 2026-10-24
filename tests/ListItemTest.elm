module ListItemTest exposing (suite)

{-| `Klar.ListItem`: the rows keep their elements in every state of a `Remote`, so
that the focus survives a refresh; a disabled row keeps its button or link; the id
sits on the element that takes the focus; the built-in text of `viewRemote`; the
density classes.
-}

import Expect
import Html exposing (Html)
import Html.Attributes as Attr
import Klar.EmptyState as EmptyState
import Klar.ListItem as ListItem
import Klar.Locale as Locale
import Klar.Remote as Remote exposing (Remote(..))
import Klar.Theme exposing (Density(..), Tone(..))
import Test exposing (Test, describe, test)
import Test.Html.Event as Event
import Test.Html.Query as Query
import Test.Html.Selector as Selector
import Time


type Msg
    = Opened


rows : List ( String, Html Msg )
rows =
    [ ( "1042", ListItem.view [ ListItem.onClick Opened ] "Order 1042" )
    , ( "1043", ListItem.view [ ListItem.onClick Opened ] "Order 1043" )
    ]


failedRefresh : Remote a -> Remote a
failedRefresh data =
    Remote.refreshWith (Remote.refresh data) (Err (Remote.problem Remote.server)) (Time.millisToPosix 0)


withData : List ( String, Remote (List ( String, Html Msg )) )
withData =
    [ ( "loaded", Loaded rows )
    , ( "refreshing", Remote.refresh (Loaded rows) )
    , ( "old data", failedRefresh (Loaded rows) )
    , ( "old data, refreshing again", Remote.refresh (failedRefresh (Loaded rows)) )
    ]


suite : Test
suite =
    describe "Klar.ListItem"
        [ describe "viewRemote draws the rows inside the same elements in every state with data, so a refresh keeps the focus"
            (withData
                |> List.map
                    (\( name, data ) ->
                        test name <|
                            \_ ->
                                ListItem.viewRemote [ ListItem.ariaLabel "Orders" ] data
                                    |> Query.fromHtml
                                    |> Expect.all
                                        [ Query.has [ Selector.tag "div", Selector.class "klar-list-fresh" ]
                                        , Query.children [ Selector.tag "ul", Selector.attribute (Attr.attribute "role" "list") ]
                                            >> Query.count (Expect.equal 1)
                                        , Query.findAll [ Selector.tag "button" ] >> Query.count (Expect.equal 2)
                                        ]
                    )
            )
        , test "a refresh marks the list busy" <|
            \_ ->
                ListItem.viewRemote [] (Remote.refresh (Loaded rows))
                    |> Query.fromHtml
                    |> Query.has [ Selector.class "klar-refreshing", Selector.attribute (Attr.attribute "aria-busy" "true") ]
        , test "old data shows the marker with a retry" <|
            \_ ->
                ListItem.viewRemote [ ListItem.onRetry Opened ] (failedRefresh (Loaded rows))
                    |> Query.fromHtml
                    |> Query.find [ Selector.class "klar-stale" ]
                    |> Query.has [ Selector.text "Try again" ]
        , test "old data without rows shows the marker and the empty state" <|
            \_ ->
                ListItem.viewRemote [ ListItem.onRetry Opened ] (failedRefresh (Loaded []))
                    |> Query.fromHtml
                    |> Expect.all
                        [ Query.has [ Selector.class "klar-stale" ]
                        , Query.has [ Selector.text "Nothing to show" ]
                        ]
        , test "no rows that are refreshing are busy too" <|
            \_ ->
                ListItem.viewRemote [] (Remote.refresh (Loaded []))
                    |> Query.fromHtml
                    |> Query.has [ Selector.attribute (Attr.attribute "aria-busy" "true") ]
        , test "the empty state takes the attributes of the application after its own" <|
            \_ ->
                ListItem.viewRemote [ ListItem.emptyState [ EmptyState.title "No orders", EmptyState.description "None match." ] ] (Loaded [])
                    |> Query.fromHtml
                    |> Expect.all
                        [ Query.has [ Selector.text "No orders" ]
                        , Query.has [ Selector.text "None match." ]
                        , Query.hasNot [ Selector.text "Nothing to show" ]
                        ]
        , test "the default empty title is in Norwegian with the Norwegian locale" <|
            \_ ->
                ListItem.viewRemote [ ListItem.locale Locale.nb ] (Loaded [])
                    |> Query.fromHtml
                    |> Query.has [ Selector.text "Ingenting å vise" ]
        , test "loading says so to screen readers" <|
            \_ ->
                ListItem.viewRemote [] Loading
                    |> Query.fromHtml
                    |> Query.find [ Selector.attribute (Attr.attribute "role" "status") ]
                    |> Query.has [ Selector.text "Loading" ]
        , test "loading in Norwegian" <|
            \_ ->
                ListItem.viewRemote [ ListItem.locale Locale.nb ] NotAsked
                    |> Query.fromHtml
                    |> Query.has [ Selector.text "Laster" ]
        , test "the placeholder rows are hidden from screen readers" <|
            \_ ->
                ListItem.viewRemote [] Loading
                    |> Query.fromHtml
                    |> Query.findAll [ Selector.class "klar-list-item--skeleton" ]
                    |> Expect.all
                        [ Query.count (Expect.equal 4)
                        , Query.each (Query.has [ Selector.attribute (Attr.attribute "aria-hidden" "true") ])
                        ]
        , test "skeletonRows is at least 1" <|
            \_ ->
                ListItem.viewRemote [ ListItem.skeletonRows 0 ] Loading
                    |> Query.fromHtml
                    |> Query.findAll [ Selector.class "klar-list-item--skeleton" ]
                    |> Query.count (Expect.equal 1)
        , test "skeletonRows is at most 20" <|
            \_ ->
                ListItem.viewRemote [ ListItem.skeletonRows 99 ] Loading
                    |> Query.fromHtml
                    |> Query.findAll [ Selector.class "klar-list-item--skeleton" ]
                    |> Query.count (Expect.equal 20)
        , test "a failure has a retry button" <|
            \_ ->
                ListItem.viewRemote [ ListItem.onRetry Opened ] (Failed (Remote.problem Remote.server))
                    |> Query.fromHtml
                    |> Query.find [ Selector.tag "button" ]
                    |> Event.simulate Event.click
                    |> Event.expect Opened
        , test "keyedList is a list with its rows" <|
            \_ ->
                ListItem.keyedList [ ListItem.ariaLabel "Orders" ] rows
                    |> Query.fromHtml
                    |> Expect.all
                        [ Query.has [ Selector.tag "ul", Selector.attribute (Attr.attribute "role" "list"), Selector.attribute (Attr.attribute "aria-label" "Orders") ]
                        , Query.findAll [ Selector.tag "li" ] >> Query.count (Expect.equal 2)
                        ]
        , describe "a disabled row keeps its element, so the focus it has stays"
            [ test "a button stays a button, marked disabled and out of the Tab order" <|
                \_ ->
                    ListItem.view [ ListItem.onClick Opened, ListItem.disabled True ] "Order 1"
                        |> Query.fromHtml
                        |> Query.find [ Selector.tag "button" ]
                        |> Query.has
                            [ Selector.attribute (Attr.attribute "aria-disabled" "true")
                            , Selector.attribute (Attr.attribute "tabindex" "-1")
                            ]
            , test "a disabled button sends nothing" <|
                \_ ->
                    ListItem.view [ ListItem.onClick Opened, ListItem.disabled True ] "Order 1"
                        |> Query.fromHtml
                        |> Query.find [ Selector.tag "button" ]
                        |> Event.simulate Event.click
                        |> Event.toResult
                        |> Expect.err
            , test "a link stays a link without its address" <|
                \_ ->
                    ListItem.view [ ListItem.href "#/orders/1", ListItem.disabled True ] "Order 1"
                        |> Query.fromHtml
                        |> Query.find [ Selector.tag "a" ]
                        |> Expect.all
                            [ Query.has [ Selector.attribute (Attr.attribute "role" "link"), Selector.attribute (Attr.attribute "aria-disabled" "true") ]
                            , Query.hasNot [ Selector.attribute (Attr.href "#/orders/1") ]
                            ]
            , test "an enabled button is in the Tab order" <|
                \_ ->
                    ListItem.view [ ListItem.onClick Opened ] "Order 1"
                        |> Query.fromHtml
                        |> Query.find [ Selector.tag "button" ]
                        |> Query.hasNot [ Selector.attribute (Attr.attribute "tabindex" "-1") ]
            ]
        , describe "the id is on the element that takes the focus"
            [ test "a button row: on the button" <|
                \_ ->
                    ListItem.view [ ListItem.onClick Opened, ListItem.id "order-1" ] "Order 1"
                        |> Query.fromHtml
                        |> Query.find [ Selector.id "order-1" ]
                        |> Query.has [ Selector.tag "button" ]
            , test "a link row: on the link" <|
                \_ ->
                    ListItem.view [ ListItem.href "#/orders/1", ListItem.id "order-1" ] "Order 1"
                        |> Query.fromHtml
                        |> Query.find [ Selector.id "order-1" ]
                        |> Query.has [ Selector.tag "a" ]
            , test "a plain row: on the li" <|
                \_ ->
                    ListItem.view [ ListItem.id "order-1" ] "Order 1"
                        |> Query.fromHtml
                        |> Query.has [ Selector.tag "li", Selector.id "order-1" ]
            ]
        , describe "density"
            [ test "without it, no class: the list follows the application" <|
                \_ ->
                    ListItem.list [] []
                        |> Query.fromHtml
                        |> Expect.all
                            [ Query.hasNot [ Selector.class "klar-list--compact" ]
                            , Query.hasNot [ Selector.class "klar-list--normal" ]
                            , Query.hasNot [ Selector.class "klar-list--comfortable" ]
                            ]
            , test "Compact" <|
                \_ -> ListItem.list [ ListItem.density Compact ] [] |> Query.fromHtml |> Query.has [ Selector.class "klar-list--compact" ]
            , test "Normal, to stay normal in a compact application" <|
                \_ -> ListItem.list [ ListItem.density Normal ] [] |> Query.fromHtml |> Query.has [ Selector.class "klar-list--normal" ]
            , test "Comfortable" <|
                \_ -> ListItem.list [ ListItem.density Comfortable ] [] |> Query.fromHtml |> Query.has [ Selector.class "klar-list--comfortable" ]
            ]
        , test "an accent is marked by its tone" <|
            \_ ->
                ListItem.view [ ListItem.accent Danger ] "Order 1"
                    |> Query.fromHtml
                    |> Query.has [ Selector.classes [ "klar-list-item--accent", "klar-list-item--accent-danger" ] ]
        ]
