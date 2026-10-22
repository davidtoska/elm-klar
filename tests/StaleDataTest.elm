module StaleDataTest exposing (suite)

{-| Old and refreshing data (`Remote.Kept`): the pure functions of `Klar.Remote`,
and what each data component draws for it.
-}

import Expect
import Html exposing (Html)
import Html.Attributes as Attr
import Klar.Alert as Alert
import Klar.Card as Card
import Klar.Chart as Chart
import Klar.CommandPalette as CommandPalette
import Klar.Locale as Locale
import Klar.Overlay as Overlay
import Klar.Remote as Remote exposing (Remote(..))
import Klar.RemoteView as RemoteView
import Klar.Stat as Stat
import Klar.Table as Table
import Klar.Timeline as Timeline
import Klar.Tree as Tree
import Support.Orders as Orders
import Test exposing (Test, describe, test)
import Test.Html.Query as Query
import Test.Html.Selector as Selector
import Time


type Msg
    = Retry
    | TreeMsg Tree.Msg
    | PaletteMsg CommandPalette.Msg


suite : Test
suite =
    describe "Stale and refreshing data"
        [ transitions
        , reading
        , components
        , containers
        , palette
        , traps
        ]


at : Int -> Time.Posix
at minutes =
    Time.millisToPosix (minutes * 60 * 1000)


{-| 14:05 in UTC.
-}
fourteenOhFive : Time.Posix
fourteenOhFive =
    at (14 * 60 + 5)


failure : Remote.Problem
failure =
    Remote.problem Remote.network


look : Remote a -> { data : Maybe a, at : Maybe Time.Posix, stale : Bool, refreshing : Bool }
look remote =
    { data = Remote.toMaybe remote, at = Remote.loadedAt remote, stale = Remote.isStale remote, refreshing = Remote.isRefreshing remote }


stale : Remote Int
stale =
    Remote.refreshWith (Remote.refreshWith Loading (Ok 7) fourteenOhFive) (Err failure) (at 1000)


transitions : Test
transitions =
    describe "refresh and refreshWith"
        [ test "the first answer is fresh data that knows when it came" <|
            \_ ->
                let
                    first =
                        Remote.refreshWith Loading (Ok 7) fourteenOhFive
                in
                Expect.equal { data = Just 7, at = Just fourteenOhFive, stale = False, refreshing = False } (look first)
        , test "a failure with nothing to show is a plain Failed" <|
            \_ ->
                Expect.equal
                    [ Failed failure, Failed failure, Failed failure ]
                    [ Remote.refreshWith NotAsked (Err failure) (at 1)
                    , Remote.refreshWith Loading (Err failure) (at 1)
                    , Remote.refreshWith (Failed failure) (Err failure) (at 1)
                    ]
        , test "a failure while data is shown keeps the data, the time and the reason" <|
            \_ ->
                Expect.equal ( { data = Just 7, at = Just fourteenOhFive, stale = True, refreshing = False }, Just failure )
                    ( look stale, Remote.staleProblem stale )
        , test "a failure on plain Loaded data keeps it, without a time" <|
            \_ ->
                let
                    old =
                        Remote.refreshWith (Loaded 3) (Err failure) (at 5)
                in
                Expect.equal ( Just 3, Nothing, True ) ( Remote.toMaybe old, Remote.loadedAt old, Remote.isStale old )
        , test "refresh keeps the data and marks it busy" <|
            \_ ->
                let
                    busy =
                        Remote.refresh (Remote.refreshWith Loading (Ok 7) fourteenOhFive)
                in
                Expect.equal ( { data = Just 7, at = Just fourteenOhFive, stale = False, refreshing = True }, False ) ( look busy, Remote.isLoading busy )
        , test "refresh of old data keeps it old, and busy" <|
            \_ ->
                let
                    busy =
                        Remote.refresh stale
                in
                Expect.equal { data = Just 7, at = Just fourteenOhFive, stale = True, refreshing = True } (look busy)
        , test "refresh of nothing goes to Loading" <|
            \_ -> Expect.equal [ Loading, Loading, Loading ] [ Remote.refresh NotAsked, Remote.refresh Loading, Remote.refresh (Failed failure) ]
        , test "plain Loaded data can be refreshed" <|
            \_ -> Expect.equal ( Just 1, True ) ( Remote.toMaybe (Remote.refresh (Loaded 1)), Remote.isRefreshing (Remote.refresh (Loaded 1)) )
        , test "the next good answer makes old data fresh again" <|
            \_ ->
                let
                    again =
                        Remote.refreshWith (Remote.refresh stale) (Ok 9) (at 2000)
                in
                Expect.equal { data = Just 9, at = Just (at 2000), stale = False, refreshing = False } (look again)
        , test "another failure keeps the first time" <|
            \_ ->
                Expect.equal (Just fourteenOhFive) (Remote.loadedAt (Remote.refreshWith (Remote.refresh stale) (Err failure) (at 3000)))
        ]


reading : Test
reading =
    describe "reading kept data"
        [ test "map, toMaybe and withDefault see the data" <|
            \_ -> Expect.equal ( Just 8, 7, True ) ( Remote.toMaybe (Remote.map ((+) 1) stale), Remote.withDefault 0 stale, Remote.isLoaded stale )
        , test "map keeps the time and the reason" <|
            \_ ->
                let
                    mapped =
                        Remote.map String.fromInt stale
                in
                Expect.equal ( Just fourteenOhFive, True ) ( Remote.loadedAt mapped, Remote.isStale mapped )
        , test "only old data is stale" <|
            \_ ->
                Expect.equal [ False, False, False, False, True ]
                    (List.map Remote.isStale [ NotAsked, Loading, Loaded 1, Remote.refresh (Loaded 1), stale ])
        , test "staleIn names the stale parts, for the notice of the page" <|
            \_ ->
                Expect.equal [ "figures" ]
                    (List.concat [ Remote.staleIn "orders" (Loaded 1), Remote.staleIn "figures" stale, Remote.staleIn "stock" Loading ])
        ]


html : Html Msg -> Query.Single Msg
html =
    Query.fromHtml


text : String -> Selector.Selector
text =
    Selector.text


ariaBusy : Selector.Selector
ariaBusy =
    Selector.attribute (Attr.attribute "aria-busy" "true")


components : Test
components =
    let
        orders data extra =
            Orders.render (Table.rows data :: Table.onRetry Orders.Retried :: extra) (Table.init "orders")
                |> Query.fromHtml

        oldOrders =
            Remote.refreshWith (Remote.refreshWith Loading (Ok Orders.curated) fourteenOhFive) (Err failure) (at 1000)

        tile extra =
            Stat.view ([ Stat.label "Open orders", Stat.onRetry Retry ] ++ extra)

        history extra =
            Timeline.view ([ Timeline.remote stale ] ++ extra) []
    in
    describe "the components"
        [ test "a table keeps its rows and says how old they are" <|
            \_ ->
                orders oldOrders []
                    |> Expect.all
                        [ Query.has [ text "Old data from 14:05" ]
                        , Query.has [ text "ORD-2001" ]
                        , Query.has [ Selector.tag "button", text "Try again" ]
                        ]
        , test "a table that refreshes is busy and shows the progress line" <|
            \_ ->
                orders (Remote.refresh (Loaded Orders.curated)) []
                    |> Expect.all
                        [ Query.has [ Selector.class "klar-table--refreshing" ]
                        , Query.find [ Selector.class "klar-table__progress" ] >> Query.has [ Selector.attribute (Attr.attribute "aria-hidden" "true") ]
                        ]
        , test "a table with fresh data says nothing about age" <|
            \_ -> orders (Remote.refreshWith Loading (Ok Orders.curated) fourteenOhFive) [] |> Query.hasNot [ text "Old data" ]
        , test "the table speaks Norwegian when asked" <|
            \_ -> orders oldOrders [ Table.locale Locale.nb ] |> Query.has [ text "Gamle data fra kl. 14:05" ]
        , test "the zone decides the time" <|
            \_ -> orders oldOrders [ Table.zone (Time.customZone 120 []) ] |> Query.has [ text "Old data from 16:05" ]
        , test "a tile shows the old number with the time, and is a plain block with its retry" <|
            \_ ->
                html (tile [ Stat.remote stale (\n -> [ Stat.int n ]), Stat.onClick Retry ])
                    |> Expect.all
                        [ Query.has [ text "7", text "Old data from 14:05" ]
                        , Query.hasNot [ Selector.tag "button", Selector.class "klar-stat--interactive" ]
                        ]
        , test "a tile that refreshes is busy" <|
            \_ ->
                html (tile [ Stat.remote (Remote.refresh (Loaded 4)) (\n -> [ Stat.int n ]) ])
                    |> Query.has [ ariaBusy, text "4" ]
        , test "a chart with old data keeps drawing it and says so" <|
            \_ ->
                html (Chart.line [ Chart.title "Sales", Chart.remote stale, Chart.onRetry Retry ] [ Chart.series "2026" [ 1, 2, 3 ] ])
                    |> Query.has [ text "Old data from 14:05", Selector.class "klar-chart" ]
        , test "a sparkline says it in its label" <|
            \_ ->
                html (Chart.sparkline [ Chart.remote stale ] [ 1, 2, 3 ])
                    |> Query.has [ Selector.attribute (Attr.attribute "aria-label" "Trend: 3 points, 1 - 3, 3. Old data from 14:05") ]
        , test "a timeline marks old data" <|
            \_ ->
                html (history [ Timeline.onRetry Retry ])
                    |> Query.has [ text "Old data from 14:05" ]
        , test "a tree marks old data" <|
            \_ ->
                html
                    (Tree.viewRemote TreeMsg
                        [ Tree.onReload Retry ]
                        (Tree.init "tree")
                        (Remote.refreshWith (Remote.refreshWith Loading (Ok [ Tree.leaf Tree.stringIds "a" "Alpha" ]) fourteenOhFive) (Err failure) (at 1000))
                    )
                    |> Query.has [ text "Old data from 14:05", text "Alpha" ]
        , test "the marker is announced politely and has a retry button" <|
            \_ ->
                html (history [ Timeline.onRetry Retry ])
                    |> Query.find [ Selector.class "klar-stale" ]
                    |> Expect.all
                        [ Query.has [ Selector.attribute (Attr.attribute "role" "status") ]
                        , Query.has [ Selector.tag "button", text "Try again" ]
                        ]
        , test "a problem that retrying cannot fix has no retry button" <|
            \_ ->
                html
                    (Timeline.view
                        [ Timeline.remote (Remote.refreshWith (Loaded 1) (Err (Remote.problem Remote.forbidden)) (at 1)), Timeline.onRetry Retry ]
                        []
                    )
                    |> Expect.all [ Query.has [ text "Old data" ], Query.hasNot [ Selector.tag "button" ] ]
        ]


containers : Test
containers =
    let
        body data =
            Card.view [ Card.title "Order" ]
                (RemoteView.view [ RemoteView.onRetry Retry, RemoteView.loadingLabel "Loading order" ] data (\n -> [ Html.text ("Order " ++ String.fromInt n) ]))
                |> Query.fromHtml
    in
    describe "RemoteView in a card"
        [ test "loading is busy and says what is loading" <|
            \_ ->
                body Loading
                    |> Expect.all
                        [ Query.has [ ariaBusy, text "Loading order" ]
                        , Query.hasNot [ text "Order 1" ]
                        ]
        , test "NotAsked looks the same" <|
            \_ -> body NotAsked |> Query.has [ ariaBusy ]
        , test "failure has a retry" <|
            \_ -> body (Failed failure) |> Query.has [ Selector.tag "button", text "Try again" ]
        , test "data calls the function" <|
            \_ -> body (Loaded 1) |> Query.has [ text "Order 1" ]
        , test "old data stays, marked" <|
            \_ -> body stale |> Query.has [ text "Order 7", text "Old data from 14:05" ]
        , test "refreshing data stays, busy" <|
            \_ -> body (Remote.refresh (Loaded 2)) |> Query.has [ text "Order 2", ariaBusy ]
        , test "the page notice names what is old" <|
            \_ ->
                Alert.stale [] Retry [ "orders", "figures" ]
                    |> Query.fromHtml
                    |> Query.has [ text "orders, figures", text "Try again" ]
        , test "the page notice is empty when nothing is old" <|
            \_ -> Alert.stale [] Retry [] |> Query.fromHtml |> Query.hasNot [ Selector.class "klar-alert" ]
        ]


palette : Test
palette =
    let
        open =
            CommandPalette.init "palette" |> CommandPalette.open "opener" |> Tuple.first |> CommandPalette.setQuery "ada"

        view hits =
            CommandPalette.view PaletteMsg [ CommandPalette.sections [ CommandPalette.remote "Customers" hits ] ] open
                |> (\overlay -> Overlay.host { attributes = [], page = [], overlays = [ overlay ] })
                |> Query.fromHtml
    in
    describe "the command palette"
        [ test "does not say No results before the answer is there" <|
            \_ ->
                Expect.all
                    [ \_ -> view NotAsked |> Query.hasNot [ text "No results" ]
                    , \_ -> view Loading |> Query.hasNot [ text "No results" ]
                    ]
                    ()
        , test "NotAsked after typing shows a loading row" <|
            \_ -> view NotAsked |> Query.has [ Selector.class "klar-skeleton" ]
        , test "an empty answer does say it" <|
            \_ -> view (Loaded []) |> Query.has [ text "No results" ]
        , test "old hits stay, marked" <|
            \_ ->
                view (Remote.refreshWith (Remote.refreshWith Loading (Ok [ CommandPalette.item "Ada Lovelace" Retry ]) fourteenOhFive) (Err failure) (at 1000))
                    |> Query.has [ text " Lovelace", text "Old data from 14:05" ]
        ]


traps : Test
traps =
    describe "attributes that used to cancel each other"
        [ test "Chart.loading False after Chart.remote keeps the loading state" <|
            \_ ->
                html (Chart.line [ Chart.remote Loading, Chart.loading False ] [ Chart.series "a" [ 1 ] ])
                    |> Query.has [ ariaBusy ]
        , test "Chart.loading False after Chart.remote keeps the failure" <|
            \_ ->
                html (Chart.line [ Chart.remote (Failed failure), Chart.loading False ] [ Chart.series "a" [ 1 ] ])
                    |> Query.has [ text "Can't reach the service" ]
        , test "Chart.remote with data after Chart.loading True does not end the loading" <|
            \_ ->
                html (Chart.line [ Chart.loading True, Chart.remote (Loaded 1) ] [ Chart.series "a" [ 1 ] ])
                    |> Query.has [ ariaBusy ]
        , test "Stat.loading False after Stat.remote keeps the loading state" <|
            \_ ->
                html (Stat.view [ Stat.label "x", Stat.remote Loading (\_ -> []), Stat.loading False ])
                    |> Query.has [ ariaBusy ]
        , test "Stat.loading False after Stat.remote keeps the failure" <|
            \_ ->
                html (Stat.view [ Stat.label "x", Stat.remote (Failed failure) (\_ -> []), Stat.loading False ])
                    |> Query.has [ text "Can't reach the service" ]
        , test "Timeline.loading False after Timeline.remote keeps the loading state" <|
            \_ ->
                html (Timeline.view [ Timeline.remote Loading, Timeline.loading False ] [])
                    |> Query.has [ ariaBusy ]
        ]
