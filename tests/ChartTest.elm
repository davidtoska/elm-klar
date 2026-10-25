module ChartTest exposing (suite)

{-| Klar.Chart and Klar.Stat: the category labels, the click on a category or a
slice that the keyboard reaches, the numbers of a sparkline, a missing measurement,
and the charts from a `Remote`.
-}

import Expect
import Html.Attributes as Attr
import Klar.Chart as Chart
import Klar.Locale as Locale
import Klar.Remote as Remote
import Klar.Stat as Stat
import Test exposing (Test, describe, test)
import Test.Html.Event as Event
import Test.Html.Query as Query
import Test.Html.Selector as Selector


type Msg
    = Picked Int
    | Retry


names : Int -> List String
names n =
    List.map (\i -> "Warehouse " ++ String.fromInt i) (List.range 1 n)


values : Int -> List Float
values n =
    List.map toFloat (List.range 1 n)


ariaLabel : String -> Selector.Selector
ariaLabel text =
    Selector.attribute (Attr.attribute "aria-label" text)


suite : Test
suite =
    describe "Klar.Chart"
        [ labelTests
        , selectTests
        , sparklineTests
        , missingTests
        , remoteTests
        , statTests
        ]


labelTests : Test
labelTests =
    describe "category labels"
        [ test "a horizontal bar chart names every one of 30 bars" <|
            \_ ->
                Chart.bar [ Chart.horizontal, Chart.categories (names 30) ] [ Chart.series "Late" (values 30) ]
                    |> Query.fromHtml
                    |> Query.findAll [ Selector.class "klar-chart__ylabel" ]
                    |> Query.count (Expect.equal 30)
        , test "a horizontal bar chart that is too low for its rows thins them" <|
            \_ ->
                Chart.bar [ Chart.horizontal, Chart.height 140, Chart.categories (names 30) ] [ Chart.series "Late" (values 30) ]
                    |> Query.fromHtml
                    |> Query.findAll [ Selector.class "klar-chart__ylabel" ]
                    |> Query.count (Expect.lessThan 30)
        , test "the last category always has its label" <|
            \_ ->
                Chart.line [ Chart.categories (names 14) ] [ Chart.series "Orders" (values 14) ]
                    |> Query.fromHtml
                    |> Query.findAll [ Selector.class "klar-chart__xlabel" ]
                    |> Query.keep (Selector.text "Warehouse 14")
                    |> Query.count (Expect.equal 1)
        , test "a thinned axis keeps at most 12 labels and the last" <|
            \_ ->
                Chart.line [ Chart.categories (names 40) ] [ Chart.series "Orders" (values 40) ]
                    |> Query.fromHtml
                    |> Query.findAll [ Selector.class "klar-chart__xlabel" ]
                    |> Query.count (Expect.atMost 13)
        ]


selectTests : Test
selectTests =
    let
        barChart =
            Chart.bar [ Chart.categories [ "Oslo", "Bergen" ], Chart.onSelect Picked ] [ Chart.series "Late" [ 12, 4 ] ]
                |> Query.fromHtml
    in
    describe "onSelect"
        [ test "every category is a button named by its values" <|
            \_ ->
                barChart
                    |> Expect.all
                        [ Query.findAll [ Selector.tag "button", Selector.class "klar-chart__slot--button" ] >> Query.count (Expect.equal 2)
                        , Query.has [ Selector.tag "button", ariaLabel "Oslo. Late: 12" ]
                        ]
        , test "a click on a category sends its position" <|
            \_ ->
                barChart
                    |> Query.find [ Selector.tag "button", ariaLabel "Bergen. Late: 4" ]
                    |> Event.simulate Event.click
                    |> Event.expect (Picked 1)
        , test "a selectable plot is a group, so that the buttons in it are reachable" <|
            \_ ->
                barChart
                    |> Expect.all
                        [ Query.has [ Selector.class "klar-chart__frame", Selector.attribute (Attr.attribute "role" "group") ]
                        , Query.hasNot [ Selector.attribute (Attr.attribute "role" "img") ]
                        ]
        , test "without onSelect the plot is a picture and has no buttons" <|
            \_ ->
                Chart.bar [ Chart.categories [ "Oslo" ] ] [ Chart.series "Late" [ 12 ] ]
                    |> Query.fromHtml
                    |> Expect.all
                        [ Query.hasNot [ Selector.tag "button" ]
                        , Query.has [ Selector.class "klar-chart__frame", Selector.attribute (Attr.attribute "role" "img") ]
                        ]
        , test "the line chart has a button per category too" <|
            \_ ->
                Chart.line [ Chart.categories [ "Jan", "Feb", "Mar" ], Chart.onSelect Picked ] [ Chart.series "Orders" [ 3, 5, 4 ] ]
                    |> Query.fromHtml
                    |> Query.find [ Selector.tag "button", ariaLabel "Mar. Orders: 4" ]
                    |> Event.simulate Event.click
                    |> Event.expect (Picked 2)
        , test "a selectable donut keeps its legend buttons with hideLegend, out of sight, for the keyboard" <|
            \_ ->
                Chart.donut [ Chart.onSelect Picked, Chart.hideLegend ] [ Chart.segment "Shipped" 420, Chart.segment "Late" 30 ]
                    |> Query.fromHtml
                    |> Query.find [ Selector.class "klar-chart__legend-hidden" ]
                    |> Query.findAll [ Selector.tag "button" ]
                    |> Query.count (Expect.equal 2)
        , test "a donut with hideLegend and no onSelect has no legend" <|
            \_ ->
                Chart.donut [ Chart.hideLegend ] [ Chart.segment "Shipped" 420, Chart.segment "Late" 30 ]
                    |> Query.fromHtml
                    |> Query.hasNot [ Selector.class "klar-chart__legend" ]
        , test "a donut's legend items are the buttons, and send the position of the segment" <|
            \_ ->
                Chart.donut [ Chart.onSelect Picked ] [ Chart.segment "Empty" 0, Chart.segment "Shipped" 420, Chart.segment "Late" 30 ]
                    |> Query.fromHtml
                    |> Query.find [ Selector.tag "button", Selector.containing [ Selector.text "Late" ] ]
                    |> Event.simulate Event.click
                    |> Event.expect (Picked 2)
        ]


sparklineTests : Test
sparklineTests =
    describe "the numbers of a sparkline"
        [ test "an ariaLabel says what it shows, the summary what it says" <|
            \_ ->
                Chart.sparkline [ Chart.ariaLabel "Orders, last 7 days" ] [ 3, 5, 12 ]
                    |> Query.fromHtml
                    |> Query.has [ ariaLabel "Orders, last 7 days. 3 points, low 3, high 12, last 12" ]
        , test "in Norwegian" <|
            \_ ->
                Chart.sparkline [ Chart.ariaLabel "Ordrer", Chart.locale Locale.nb ] [ 3, 5, 12 ]
                    |> Query.fromHtml
                    |> Query.has [ ariaLabel "Ordrer. 3 punkter, lavest 3, høyest 12, siste 12" ]
        , test "the trend of a tile reaches a screen reader with its numbers" <|
            \_ ->
                Stat.view [ Stat.label "Open orders", Stat.int 21, Stat.trend [ 12, 14, 21 ] ]
                    |> Query.fromHtml
                    |> Query.has [ ariaLabel "Open orders: trend. 3 points, low 12, high 21, last 21" ]
        , test "a sparkline takes its id" <|
            \_ ->
                Chart.sparkline [ Chart.id "spark" ] [ 1, 2 ]
                    |> Query.fromHtml
                    |> Query.has [ Selector.id "spark" ]
        ]


missingTests : Test
missingTests =
    describe "a missing measurement is not a zero"
        [ test "a gauge of NaN shows a dash and says No value" <|
            \_ ->
                Chart.gauge [] (0 / 0)
                    |> Query.fromHtml
                    |> Expect.all
                        [ Query.has [ Selector.attribute (Attr.attribute "aria-valuetext" "No value") ]
                        , Query.has [ Selector.class "klar-chart__center-value", Selector.text "–" ]
                        ]
        , test "a meter of NaN has no marker" <|
            \_ ->
                Chart.meter [] (0 / 0)
                    |> Query.fromHtml
                    |> Expect.all
                        [ Query.has [ Selector.attribute (Attr.attribute "aria-valuetext" "No value") ]
                        , Query.hasNot [ Selector.class "klar-meter__marker" ]
                        ]
        , test "aria-valuenow stays inside the range, the text says the real value" <|
            \_ ->
                Chart.gauge [ Chart.range 0 100 ] 140
                    |> Query.fromHtml
                    |> Expect.all
                        [ Query.has [ Selector.attribute (Attr.attribute "aria-valuenow" "100") ]
                        , Query.has [ Selector.attribute (Attr.attribute "aria-valuetext" "140") ]
                        ]
        ]


remoteTests : Test
remoteTests =
    describe "charts from a Remote"
        [ test "a failed line chart shows Try again, which sends onRetry" <|
            \_ ->
                Chart.lineRemote [ Chart.onRetry Retry ] (Remote.Failed (Remote.problem Remote.server))
                    |> Query.fromHtml
                    |> Query.find [ Selector.tag "button", Selector.containing [ Selector.text "Try again" ] ]
                    |> Event.simulate Event.click
                    |> Event.expect Retry
        , test "the categories travel with the series in byCategory and replace those of the attributes" <|
            \_ ->
                Chart.lineRemote [ Chart.categories [ "Elsewhere" ] ]
                    (Remote.Loaded (Chart.byCategory [ "Jan", "Feb" ] [ Chart.series "Orders" [ 3, 5 ] ]))
                    |> Query.fromHtml
                    |> Expect.all
                        [ Query.has [ Selector.text "Jan" ]
                        , Query.has [ Selector.text "Feb" ]
                        , Query.hasNot [ Selector.text "Elsewhere" ]
                        ]
        , test "fresh, refreshing and old data have the same elements around the chart" <|
            \_ ->
                let
                    loaded =
                        Remote.Loaded (Chart.byCategory [] [ Chart.series "a" [ 1, 2 ] ])

                    -- the outermost element is the same wrapper in both
                    wrappers data =
                        Chart.lineRemote [] data
                            |> Query.fromHtml
                            |> Query.has [ Selector.tag "div", Selector.class "klar-chart-fresh" ]
                in
                Expect.all
                    [ \_ -> wrappers loaded
                    , \_ -> wrappers (Remote.refresh loaded)
                    ]
                    ()
        , test "an empty donut from a Remote shows the empty state" <|
            \_ ->
                Chart.donutRemote [ Chart.emptyText "No orders" ] (Remote.Loaded [])
                    |> Query.fromHtml
                    |> Query.has [ Selector.text "No orders" ]
        ]


statTests : Test
statTests =
    describe "Klar.Stat"
        [ test "a tile without a number shows a dash and says No data" <|
            \_ ->
                Stat.view [ Stat.label "Open orders" ]
                    |> Query.fromHtml
                    |> Expect.all
                        [ Query.has [ Selector.class "klar-stat__value--missing", Selector.text "–" ]
                        , Query.has [ Selector.class "klar-sr-only", Selector.text "No data" ]
                        ]
        , test "abbreviated shortens a large number" <|
            \_ ->
                Stat.view [ Stat.abbreviated 4200000 ]
                    |> Query.fromHtml
                    |> Query.has [ Selector.text "4.2M" ]
        , test "a lower-is-better rise is red, with the hidden word increase" <|
            \_ ->
                Stat.view [ Stat.int 5, Stat.delta 3, Stat.lowerIsBetter ]
                    |> Query.fromHtml
                    |> Expect.all
                        [ Query.has [ Selector.class "klar-stat__delta--danger" ]
                        , Query.has [ Selector.text ", increase" ]
                        ]
        , test "a change below 0.05 is unchanged and neutral" <|
            \_ ->
                Stat.view [ Stat.int 5, Stat.delta 0.04 ]
                    |> Query.fromHtml
                    |> Expect.all
                        [ Query.has [ Selector.class "klar-stat__delta--neutral" ]
                        , Query.has [ Selector.text ", unchanged" ]
                        ]
        , test "a fall is written with a true minus sign" <|
            \_ ->
                Stat.view [ Stat.int 5, Stat.delta -8 ]
                    |> Query.fromHtml
                    |> Query.has [ Selector.text "−8%" ]
        , test "deltaBy is a difference in the tile's units, with its direction" <|
            \_ ->
                Stat.view [ Stat.int 112, Stat.deltaBy 12 ]
                    |> Query.fromHtml
                    |> Expect.all
                        [ Query.has [ Selector.text "+12" ]
                        , Query.hasNot [ Selector.text "+12%" ]
                        , Query.has [ Selector.class "klar-stat__delta--success" ]
                        ]
        , test "deltaBy on a tile with decimals keeps them, so a small change is not a dash" <|
            \_ ->
                Stat.view [ Stat.decimal 2 0.12, Stat.deltaBy 0.03 ]
                    |> Query.fromHtml
                    |> Expect.all
                        [ Query.has [ Selector.text "+0.03" ]
                        , Query.has [ Selector.class "klar-stat__delta--success" ]
                        ]
        , test "deltaBy on an abbreviated tile is abbreviated like the value" <|
            \_ ->
                Stat.view [ Stat.abbreviated 4200000, Stat.deltaBy -1500000 ]
                    |> Query.fromHtml
                    |> Query.has [ Selector.text "−1.5M" ]
        , test "deltaBy on a whole number that rounds to zero is unchanged" <|
            \_ ->
                Stat.view [ Stat.int 112, Stat.deltaBy 0.4 ]
                    |> Query.fromHtml
                    |> Query.has [ Selector.text ", unchanged" ]
        , test "a tile has one live region in every state, and a failure is said in it" <|
            \_ ->
                let
                    regions data =
                        Stat.view [ Stat.label "Orders", Stat.remote data (\n -> [ Stat.int n ]) ]
                            |> Query.fromHtml
                            |> Query.findAll [ Selector.class "klar-sr-only", Selector.attribute (Attr.attribute "role" "status") ]
                in
                Expect.all
                    [ \_ -> regions Remote.Loading |> Query.count (Expect.equal 1)
                    , \_ -> regions (Remote.Loaded 4) |> Query.count (Expect.equal 1)
                    , \_ -> regions (Remote.Failed (Remote.problem Remote.server)) |> Query.count (Expect.equal 1)
                    , \_ -> regions (Remote.Failed (Remote.problem Remote.server)) |> Query.first |> Query.has [ Selector.text (Remote.title Locale.en (Remote.problem Remote.server)) ]
                    ]
                    ()
        , test "deltaPoints is in percentage points" <|
            \_ ->
                Stat.view [ Stat.decimal 1 3.5, Stat.deltaPoints -0.3 ]
                    |> Query.fromHtml
                    |> Expect.all
                        [ Query.has [ Selector.text "−0.3\u{00A0}pp" ]
                        , Query.has [ Selector.text ", decrease" ]
                        ]
        , test "and in Norwegian" <|
            \_ ->
                Stat.view [ Stat.decimal 1 3.5, Stat.deltaPoints 0.3, Stat.locale Locale.nb ]
                    |> Query.fromHtml
                    |> Query.has [ Selector.text "+0,3\u{00A0}p.p." ]
        , test "the last of delta, deltaBy and deltaPoints wins" <|
            \_ ->
                Stat.view [ Stat.int 5, Stat.deltaPoints 2, Stat.delta 4 ]
                    |> Query.fromHtml
                    |> Query.has [ Selector.text "+4%" ]
        ]
