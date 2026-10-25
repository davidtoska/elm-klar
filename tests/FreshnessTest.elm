module FreshnessTest exposing (suite)

{-| The marker of old and refreshing data that every data component draws
(`Klar.Internal.Freshness`): the same elements in every state, a live region that is
always there, the reason in text, and a retry button in the Tab order.
-}

import Expect
import Html exposing (Html)
import Html.Attributes as Attr
import Klar.Internal.Freshness as Freshness exposing (Freshness(..))
import Klar.Locale as Locale
import Klar.Remote as Remote
import Klar.Settings as Settings
import Test exposing (Test, describe, test)
import Test.Html.Event as Event
import Test.Html.Query as Query
import Test.Html.Selector as Selector
import Time


type Msg
    = Retry


config : Bool -> Freshness.Config Msg
config inline =
    { locale = Locale.en, settings = Settings.default, onRetry = Just Retry, inline = inline }


{-| 14:05 in UTC.
-}
fourteenOhFive : Time.Posix
fourteenOhFive =
    Time.millisToPosix ((14 * 60 + 5) * 60 * 1000)


old : Bool -> Freshness
old refreshing =
    Stale { problem = Remote.problem Remote.network, at = Just fourteenOhFive, refreshing = refreshing }


states : List ( String, Freshness )
states =
    [ ( "fresh", Fresh ), ( "refreshing", Refreshing ), ( "old", old False ), ( "old and retrying", old True ) ]


wrapped : Bool -> Freshness -> Query.Single Msg
wrapped inline freshness =
    Freshness.wrap (config inline) [ Attr.class "klar-list-fresh" ] freshness [ Html.input [ Attr.id "row-1" ] [] ]
        |> Query.fromHtml


status : Selector.Selector
status =
    Selector.attribute (Attr.attribute "role" "status")


suite : Test
suite =
    describe "Klar.Internal.Freshness"
        [ describe "wrap draws the same elements in every state"
            (List.map
                (\( name, freshness ) ->
                    test name <|
                        \_ ->
                            wrapped False freshness
                                |> Expect.all
                                    [ Query.has [ Selector.tag "div", Selector.class "klar-fresh", Selector.class "klar-list-fresh" ]
                                    , Query.children [] >> Query.count (Expect.equal 2)
                                    , Query.children [] >> Query.index 0 >> Query.has [ Selector.class "klar-fresh__slot" ]
                                    , Query.children [] >> Query.index 1 >> Query.has [ Selector.tag "input", Selector.id "row-1" ]
                                    , Query.find [ Selector.class "klar-fresh__slot" ] >> Query.findAll [ status ] >> Query.count (Expect.equal 1)
                                    ]
                )
                states
            )
        , describe "the live region"
            [ test "is there and silent while the data is fresh" <|
                \_ ->
                    wrapped False Fresh
                        |> Query.find [ status ]
                        |> Query.has [ Selector.class "klar-sr-only", Selector.exactText "" ]
            , test "is silent while a refresh is on its way (aria-busy says it)" <|
                \_ ->
                    wrapped False Refreshing
                        |> Expect.all
                            [ Query.find [ status ] >> Query.has [ Selector.exactText "" ]
                            , Query.has [ Selector.attribute (Attr.attribute "aria-busy" "true"), Selector.class "klar-refreshing" ]
                            ]
            , test "says how old the data is and why when a refresh fails" <|
                \_ ->
                    wrapped False (old False)
                        |> Query.find [ status ]
                        |> Query.has [ Selector.exactText "Old data from 14:05 UTC. Refresh failed: Can't reach the service." ]
            , test "a title of the application that ends a sentence gets no second full stop" <|
                \_ ->
                    Freshness.announcement Locale.en
                        Settings.default
                        (Stale { problem = Remote.problem Remote.network |> Remote.withTitle "The warehouse is offline.", at = Nothing, refreshing = False })
                        |> Expect.equal "Old data. Refresh failed: The warehouse is offline."
            , test "in Norwegian" <|
                \_ ->
                    Freshness.announcement Locale.nb Settings.default (old False)
                        |> Expect.equal "Gamle data fra kl. 14:05 UTC. Oppdateringen feilet: Ingen kontakt med tjenesten."
            , test "an inline marker (a tile, a branch) is not a live region" <|
                \_ -> wrapped True (old False) |> Query.hasNot [ status ]
            ]
        , describe "the marker"
            [ test "says the reason in text, not only in a title" <|
                \_ ->
                    wrapped False (old False)
                        |> Query.find [ Selector.class "klar-stale__reason" ]
                        |> Expect.all
                            [ Query.has [ Selector.text "Refresh failed: Can't reach the service" ]
                            , Query.hasNot [ Selector.class "klar-sr-only" ]
                            ]
            , test "an inline marker keeps the reason for screen readers" <|
                \_ ->
                    wrapped True (old False)
                        |> Query.find [ Selector.class "klar-stale__reason" ]
                        |> Query.has [ Selector.class "klar-sr-only", Selector.text "Can't reach the service" ]
            , test "is not drawn for fresh or refreshing data" <|
                \_ ->
                    Expect.all
                        [ \_ -> wrapped False Fresh |> Query.hasNot [ Selector.class "klar-stale" ]
                        , \_ -> wrapped False Refreshing |> Query.hasNot [ Selector.class "klar-stale" ]
                        ]
                        ()
            , test "notice is the same slot on its own, a div (it holds the marker, a div)" <|
                \_ ->
                    Freshness.notice (config False) Fresh
                        |> Query.fromHtml
                        |> Expect.all [ Query.has [ Selector.tag "div", Selector.class "klar-fresh__slot" ], Query.find [ status ] >> Query.has [ Selector.exactText "" ] ]
            ]
        , describe "region"
            [ test "is the root with the id, which focus can reach from a retry" <|
                \_ ->
                    Freshness.region "orders" [ Attr.class "klar-list" ] "" [ Html.text "Order 1" ]
                        |> Query.fromHtml
                        |> Query.has [ Selector.id "orders", Selector.attribute (Attr.tabindex -1), Selector.class "klar-region", Selector.class "klar-list" ]
            , test "has a live region first, whose text is the component's for the state" <|
                \_ ->
                    Expect.all
                        [ \_ ->
                            Freshness.region "orders" [] "Loading orders" [ Html.text "skeleton" ]
                                |> Query.fromHtml
                                |> Query.children []
                                |> Query.first
                                |> Query.has [ status, Selector.class "klar-sr-only", Selector.exactText "Loading orders" ]
                        , \_ ->
                            Freshness.region "orders" [] "" [ Html.text "Order 1" ]
                                |> Query.fromHtml
                                |> Query.children []
                                |> Query.first
                                |> Query.has [ status, Selector.exactText "" ]
                        ]
                        ()
            ]
        , describe "the retry button"
            [ test "in the page it is in the Tab order" <|
                \_ ->
                    wrapped False (old False)
                        |> Query.find [ Selector.tag "button" ]
                        |> Expect.all
                            [ Query.has [ Selector.text "Try again" ]
                            , Query.hasNot [ Selector.attribute (Attr.tabindex -1) ]
                            , Event.simulate Event.click >> Event.expect Retry
                            ]
            , test "is busy while the retry is on its way" <|
                \_ ->
                    wrapped False (old True)
                        |> Query.find [ Selector.tag "button" ]
                        |> Query.has [ Selector.attribute (Attr.attribute "aria-busy" "true") ]
            , test "is not drawn for a problem that retrying cannot fix" <|
                \_ ->
                    Freshness.wrap
                        (config False)
                        []
                        (Stale { problem = Remote.problem Remote.forbidden, at = Nothing, refreshing = False })
                        []
                        |> Query.fromHtml
                        |> Query.hasNot [ Selector.tag "button" ]
            ]
        ]
