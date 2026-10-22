module Page.Gallery.DataDisplay.Charts exposing (Model, Msg, init, update, view)

{-| The chart section: line, bar and donut charts, gauges and meters, sparklines,
and their loading, failed and empty states.
-}

import Api.Types as Types exposing (OrderStatus(..))
import Html exposing (Html)
import Klar.Chart as Chart
import Klar.Format as Format
import Klar.Layout as Layout
import Klar.Locale as Locale exposing (Locale)
import Klar.Remote as Remote
import Klar.RemoteView as RemoteView
import Klar.Text as Text
import Klar.Theme exposing (Tone(..))
import Page.Gallery.DataDisplay.Pretend as Pretend
import Showcase.Doc as Doc
import Showcase.Sample as Sample



-- MODEL


{-| The examples whose "Try again" is on its way.
-}
type alias Model =
    { retrying : List String
    }


type Msg
    = Retry String
    | RetryDone String
    | Focused


init : Model
init =
    { retrying = [] }


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        Retry example ->
            -- "Try again" is replaced by the skeleton: focus goes to the chart (its id).
            ( { model | retrying = example :: model.retrying }
            , Cmd.batch [ Pretend.later (RetryDone example), RemoteView.focus (chartId example) Focused ]
            )

        Focused ->
            ( model, Cmd.none )

        RetryDone example ->
            ( { model | retrying = List.filter (\other -> other /= example) model.retrying }, Cmd.none )


chartId : String -> String
chartId example =
    "chart-retry-" ++ example



-- VIEW


view : Locale -> Model -> Html Msg
view locale model =
    Doc.section "Charts"
        "The charts are built from HTML and CSS: bars, markers and donut slices are elements, and only the lines and areas are SVG (a mask in the color of the series). They fill the width of their container, text and lines keep a fixed size, and every chart has a hidden data table for screen readers. Hold the pointer over a category to see the values. Colors are handed out to the series in a fixed order; pin a series to a color with withColor to keep it when other series come and go."
        (lineExamples locale
            ++ barExamples locale
            ++ donutExamples locale
            ++ gaugeExamples locale
            ++ sparklineExamples locale
            ++ stateExamples locale model
        )


months : Locale -> List String
months locale =
    List.map (Locale.monthShort locale) (List.range 1 12)


{-| A smooth, repeatable curve, rounded to whole numbers.
-}
wave : Float -> Float -> Float -> Int -> Float
wave base amplitude phase i =
    toFloat (round (base + amplitude * sin (toFloat i * 0.62 + phase)))


twelve : Float -> Float -> Float -> List Float
twelve base amplitude phase =
    List.map (wave base amplitude phase) (List.range 0 11)



-- LINE


lineExamples : Locale -> List (Html Msg)
lineExamples locale =
    let
        dense =
            List.range 0 364
                |> List.map (\i -> toFloat (round (60 + 25 * sin (toFloat i / 28) + 8 * sin (toFloat i / 3))))

        compactLine title values =
            Chart.line [ Chart.title title, Chart.height 150, Chart.locale locale ] values
    in
    [ Doc.example
        { title = "Line chart with several series"
        , description = Just "A dashed line is a forecast or a target. The months that are not over yet are gaps in the line, not zeros."
        , code = Just """Chart.line [ Chart.title "Orders per month", Chart.categories months ]
    [ Chart.series "2025" [ 120, 180, 90, 220 ]
    , Chart.seriesMaybe "2026" [ Just 140, Just 200, Nothing, Nothing ]
    , Chart.series "Target" [ 280, 280, 280, 280 ] |> Chart.dashed |> Chart.withColor 8
    ]"""
        }
        (Chart.line
            [ Chart.title "Orders per month"
            , Chart.description "All warehouses"
            , Chart.categories (months locale)
            , Chart.height 240
            , Chart.locale locale
            ]
            [ Chart.series "2025" (twelve 240 90 0)
            , Chart.seriesMaybe "2026" (List.map Just (List.take 9 (twelve 260 100 0.4)) ++ [ Nothing, Nothing, Nothing ])
            , Chart.series "Target" (List.repeat 12 280) |> Chart.dashed |> Chart.withColor 8
            ]
        )
    , Doc.example
        { title = "Meaning, markers and axis"
        , description = Just "A series that means good or bad says so with withTone: the status colors are reserved for that. points, includeZero and maxLabels adjust the markers, the value axis and the number of category labels."
        , code = Just """Chart.line
    [ Chart.title "Deliveries per week"
    , Chart.categories weeks
    , Chart.points False
    , Chart.includeZero True
    , Chart.maxLabels 6
    ]
    [ Chart.series "On time" onTime |> Chart.withTone Success
    , Chart.series "Late" late |> Chart.withTone Danger
    ]"""
        }
        (Chart.line
            [ Chart.title "Deliveries per week"
            , Chart.categories (List.range 1 26 |> List.map (\week -> "Week " ++ String.fromInt week))
            , Chart.points False
            , Chart.includeZero True
            , Chart.maxLabels 6
            , Chart.height 200
            , Chart.locale locale
            ]
            [ Chart.series "On time" (List.map (wave 180 25 0) (List.range 0 25)) |> Chart.withTone Success
            , Chart.series "Late" (List.map (wave 22 8 1.5) (List.range 0 25)) |> Chart.withTone Danger
            ]
        )
    , Doc.example
        { title = "Negative values and an area"
        , description = Just "The axis gets a zero line when the data crosses zero. The area is a light, transparent version of the color of the line."
        , code = Just "Chart.line [ Chart.area, Chart.unit \"MUSD\", Chart.categories months ] [ Chart.series \"Net result\" [ 12, 8, -4, -11 ] ]"
        }
        (Chart.line
            [ Chart.title "Net result per month"
            , Chart.unit "MUSD"
            , Chart.area
            , Chart.categories (months locale)
            , Chart.height 200
            , Chart.locale locale
            ]
            [ Chart.series "Net result" [ 12, 8, -4, -11, -6, 3, 9, 14, 6, -2, -8, 5 ] ]
        )
    , Doc.example
        { title = "Many points"
        , description = Just "365 values. The markers only show under the pointer, and the axis shows at most twelve names. The tooltip shows the day and the value."
        , code = Just "Chart.line [ Chart.area, Chart.categories days ] [ Chart.series \"Utilization\" values ]"
        }
        (Chart.line
            [ Chart.title "Warehouse utilization per day"
            , Chart.unit "%"
            , Chart.area
            , Chart.categories (List.range 1 365 |> List.map (\day -> "Day " ++ String.fromInt day))
            , Chart.height 200
            , Chart.locale locale
            ]
            [ Chart.series "Utilization" dense ]
        )
    , Doc.example
        { title = "Awkward data, line chart"
        , description = Just "One point, equal values, a gap in the middle, huge numbers, tiny decimals and no data. Nothing breaks, and the axes get sensible numbers."
        , code = Nothing
        }
        (Layout.grid [ Layout.minColumn 300, Layout.gap 6 ]
            [ Chart.line [ Chart.title "One point", Chart.height 150, Chart.categories [ "Jan" ], Chart.locale locale ] [ Chart.series "A" [ 42 ] ]
            , compactLine "All values equal" [ Chart.series "A" [ 5, 5, 5, 5, 5 ] ]
            , Chart.line [ Chart.title "Gap in the middle", Chart.height 150, Chart.locale locale ]
                [ Chart.seriesMaybe "A" [ Just 3, Just 6, Nothing, Nothing, Just 4, Just 8, Just 7 ] ]
            , compactLine "Large numbers (billions)" [ Chart.series "Revenue" [ 1.2e9, 2.8e9, 2.1e9, 4.8e9, 3.9e9, 6.2e9 ] ]
            , compactLine "Even larger (trillions)" [ Chart.series "Value" [ 1.0e12, 3.2e12, 2.4e12, 4.8e12 ] ]
            , compactLine "Small decimals" [ Chart.series "Share" [ 0.0003, 0.0012, 0.0008, 0.0021, 0.0015 ] ]
            , compactLine "Only negative" [ Chart.series "Deviation" [ -42, -18, -30, -75, -60 ] ]
            , compactLine "Extreme numbers (1e15)" [ Chart.series "A" [ 1.0e15, -1.0e15, 0, 5.0e14 ] ]
            , compactLine "NaN and infinity become gaps" [ Chart.series "A" [ 1 / 0, 0 / 0, 5, 7 ], Chart.series "B" [ 2, 4, 1 / 0, 3 ] ]
            , Chart.line [ Chart.title "Empty", Chart.height 150, Chart.locale locale ] []
            ]
        )
    ]



-- BAR


{-| The orders of every warehouse of the sample data, counted by what is happening
to them.
-}
warehouseRows : List { name : String, waiting : Int, shipped : Int, delivered : Int }
warehouseRows =
    List.map
        (\warehouse ->
            let
                mine =
                    List.filter (\order -> order.warehouse == warehouse.id) Sample.orders

                count statuses =
                    List.length (List.filter (\order -> List.member order.status statuses) mine)
            in
            { name = warehouse.name
            , waiting = count [ Draft, Confirmed, Picking ]
            , shipped = count [ Shipped ]
            , delivered = count [ Delivered ]
            }
        )
        Sample.warehouses


barExamples : Locale -> List (Html Msg)
barExamples locale =
    let
        quarters =
            [ "Q4 2024", "Q1 2025", "Q2 2025", "Q3 2025", "Q4 2025", "Q1 2026", "Q2 2026", "Q3 2026" ]

        areas =
            [ "Inbound dock and cross-docking area"
            , "Cold storage"
            , "Pallet racking, hall A"
            , "Small parts picking"
            , "Dangerous goods cage"
            , "Returns processing and refurbishment"
            , "Packing and labelling"
            , "Oversized goods yard"
            , "Quarantine and inspection"
            , "Mezzanine archive"
            ]

        utilization =
            [ 94, 88, 81, 79, 74, 69, 62, 55, 47, 31 ]

        small title attrs data =
            Chart.bar ([ Chart.title title, Chart.height 160, Chart.locale locale ] ++ attrs) data
    in
    [ Doc.example
        { title = "Grouped bar chart"
        , description = Just "Bars are 24 pixels wide at most, and rounded only at the end away from the axis. Hold the pointer over a warehouse for all three values."
        , code = Just """Chart.bar [ Chart.title "Orders per warehouse", Chart.categories warehouses ]
    [ Chart.series "Waiting" [ 120, 140, 110 ]
    , Chart.series "Shipped" [ 90, 85, 100 ]
    , Chart.series "Delivered" [ 250, 270, 240 ]
    ]"""
        }
        (Chart.bar
            [ Chart.title "Orders per warehouse"
            , Chart.categories (List.map .name warehouseRows)
            , Chart.height 240
            , Chart.locale locale
            ]
            [ Chart.series "Waiting" (List.map (.waiting >> toFloat) warehouseRows)
            , Chart.series "Shipped" (List.map (.shipped >> toFloat) warehouseRows)
            , Chart.series "Delivered" (List.map (.delivered >> toFloat) warehouseRows)
            ]
        )
    , Doc.example
        { title = "Stacked, with totals"
        , description = Just "The parts are separated by a two pixel gap, not by a border. The number above a bar is the total."
        , code = Just """Chart.bar [ Chart.stacked, Chart.valueLabels, Chart.categories quarters ]
    [ Chart.series "Hardware" [ 310, 290, 330 ]
    , Chart.series "Electronics" [ 220, 240, 180 ]
    ]"""
        }
        (Chart.bar
            [ Chart.title "Revenue per quarter"
            , Chart.description "Thousand USD"
            , Chart.categories quarters
            , Chart.stacked
            , Chart.valueLabels
            , Chart.height 260
            , Chart.locale locale
            ]
            [ Chart.series "Hardware" [ 310, 290, 330, 360, 340, 320, 350, 380 ]
            , Chart.series "Electronics" [ 220, 240, 180, 260, 250, 270, 210, 290 ]
            , Chart.series "Packaging" [ 140, 150, 160, 130, 170, 180, 150, 160 ]
            , Chart.series "Other" [ 40, 35, 50, 45, 30, 55, 48, 52 ]
            ]
        )
    , Doc.example
        { title = "Horizontal, with long names"
        , description = Just "Names that do not fit are cut with “...” (the whole name is in the tooltip), and the height follows the number of categories. One series, so all the bars have the same color and there is no legend."
        , code = Just """Chart.bar
    [ Chart.horizontal
    , Chart.valueLabels
    , Chart.yMax 100
    , Chart.valueFormat (\\v -> Format.percent locale 0 (v / 100))
    , Chart.categories areas
    ]
    [ Chart.series "Utilization" values ]"""
        }
        (Chart.bar
            [ Chart.title "Utilization by area"
            , Chart.categories areas
            , Chart.horizontal
            , Chart.valueLabels
            , Chart.yMax 100
            , Chart.valueFormat (\v -> Format.percent locale 0 (v / 100))
            , Chart.locale locale
            ]
            [ Chart.series "Utilization" utilization ]
        )
    , Doc.example
        { title = "Awkward data, bar chart"
        , description = Just "Negative values go below the zero line, large numbers get short numbers on the axis, and there are single bars, many zeros and 40 categories. Hold the pointer over a bar, also the thin ones."
        , code = Nothing
        }
        (Layout.grid [ Layout.minColumn 300, Layout.gap 6 ]
            [ small "Negative values"
                [ Chart.categories (List.take 5 (months locale)) ]
                [ Chart.series "In" [ 12, 8, -5, 15, -9 ], Chart.series "Out" [ -6, -14, 3, -8, 10 ] ]
            , small "Stacked with negatives"
                [ Chart.categories [ "A", "B", "C", "D" ], Chart.stacked ]
                [ Chart.series "Revenue" [ 30, 25, 40, 20 ], Chart.series "Cost" [ -12, -18, -9, -22 ] ]
            , small "One bar" [ Chart.categories [ "Total" ] ] [ Chart.series "Count" [ 1284 ] ]
            , small "Large numbers"
                [ Chart.categories [ "A", "B", "C", "D" ] ]
                [ Chart.series "Revenue" [ 4.2e12, 3.1e12, 5.6e12, 1.9e12 ] ]
            , small "Zeros and small values"
                [ Chart.categories [ "a", "b", "c", "d", "e" ] ]
                [ Chart.series "n" [ 0, 0, 1, 0, 120 ] ]
            , small "40 categories"
                [ Chart.categories (List.range 1 40 |> List.map String.fromInt) ]
                [ Chart.series "Value" (List.range 1 40 |> List.map (wave 50 30 0)) ]
            , small "Many series"
                [ Chart.categories [ "X", "Y", "Z" ] ]
                (List.range 1 8
                    |> List.map (\i -> Chart.series ("Series " ++ String.fromInt i) [ toFloat (i * 3), toFloat (30 - i * 2), toFloat (i * i) ])
                )
            , Chart.bar [ Chart.title "Empty", Chart.height 160, Chart.locale locale ] []
            ]
        )
    ]



-- DONUT


donutExamples : Locale -> List (Html Msg)
donutExamples locale =
    let
        byStatus =
            Types.allOrderStatuses
                |> List.map
                    (\status ->
                        Chart.segment (Types.orderStatusLabel status)
                            (toFloat (List.length (List.filter (\order -> order.status == status) Sample.orders)))
                    )

        small title attrs segments =
            Chart.donut ([ Chart.title title, Chart.size 132, Chart.locale locale ] ++ attrs) segments
    in
    [ Doc.example
        { title = "Donut chart"
        , description = Just "The parts of one whole; it works best with six parts at most. The number in the middle is the total, unless you set something else. Hold the pointer over a part: the others fade and the tooltip shows the value and the share."
        , code = Just """Chart.donut [ Chart.centerCaption "orders" ]
    [ Chart.segment "Shipped" 420
    , Chart.segment "Picking" 310
    ]"""
        }
        (Chart.donut
            [ Chart.title "Orders by status"
            , Chart.centerCaption "orders"
            , Chart.locale locale
            ]
            byStatus
        )
    , Doc.example
        { title = "Awkward data, donut chart"
        , description = Just "One whole part, twelve parts (the smallest are folded into “Other”), only zeros, microscopic parts and parts with a meaning (green, amber, red)."
        , code = Just """Chart.donut [ Chart.centerLabel "92%", Chart.centerCaption "on time" ]
    [ Chart.segment "On time" 92 |> Chart.segmentTone Success
    , Chart.segment "At risk" 5 |> Chart.segmentTone Warning
    , Chart.segment "Late" 3 |> Chart.segmentTone Danger
    ]"""
        }
        (Layout.grid [ Layout.minColumn 330, Layout.gap 6 ]
            [ small "One whole part" [] [ Chart.segment "All" 100 ]
            , small "Twelve parts" [] (List.range 1 12 |> List.map (\i -> Chart.segment ("Part " ++ String.fromInt i) (toFloat (200 - i * 14))))
            , small "Only zeros" [] [ Chart.segment "A" 0, Chart.segment "B" 0 ]
            , small "Microscopic parts" [] [ Chart.segment "Main part" 9950, Chart.segment "Small" 30, Chart.segment "Smallest" 20 ]
            , small "Parts with a meaning"
                [ Chart.centerLabel (Format.percent locale 0 0.92), Chart.centerCaption "on time" ]
                [ Chart.segment "On time" 92 |> Chart.segmentTone Success
                , Chart.segment "At risk" 5 |> Chart.segmentTone Warning
                , Chart.segment "Late" 3 |> Chart.segmentTone Danger
                ]
            , small "Large numbers" [] [ Chart.segment "A" 4.2e12, Chart.segment "B" 3.1e12 ]
            ]
        )
    ]



-- GAUGE AND METER


gaugeExamples : Locale -> List (Html Msg)
gaugeExamples locale =
    let
        zones =
            [ ( 70, Success ), ( 90, Warning ), ( 100, Danger ) ]

        gauge title value attrs =
            Chart.gauge ([ Chart.title title, Chart.size 190, Chart.locale locale ] ++ attrs) value

        meter title value attrs =
            Chart.meter ([ Chart.title title, Chart.locale locale ] ++ attrs) value
    in
    [ Doc.example
        { title = "Gauge"
        , description = Just "The zone the value falls in colors the arc. The light track is a lighter step of the same color, so the state can be read along the whole arc. Values outside the scale are clipped."
        , code = Just "Chart.gauge [ Chart.range 0 100, Chart.thresholds [ ( 70, Success ), ( 90, Warning ), ( 100, Danger ) ] ] 84"
        }
        (Layout.row [ Layout.gap 8, Layout.wrap, Layout.alignStart ]
            [ gauge "Low" 35 [ Chart.thresholds zones, Chart.unit "%", Chart.centerCaption "Utilization" ]
            , gauge "High" 84 [ Chart.thresholds zones, Chart.unit "%", Chart.centerCaption "Utilization" ]
            , gauge "Critical" 97 [ Chart.thresholds zones, Chart.unit "%", Chart.centerCaption "Utilization" ]
            , gauge "Another scale" 150 [ Chart.range 0 200, Chart.centerCaption "Orders" ]
            , gauge "Outside the scale" 130 [ Chart.thresholds zones, Chart.centerCaption "Clipped" ]
            ]
        )
    , Doc.example
        { title = "Meter"
        , description = Just "The value as a marker on a scale with zones. Use it when the value is read against a limit."
        , code = Just "Chart.meter [ Chart.title \"Warehouse utilization\", Chart.thresholds zones ] 84"
        }
        (Layout.grid [ Layout.minColumn 260, Layout.gap 6 ]
            [ meter "Warehouse utilization" 84 [ Chart.thresholds zones, Chart.unit "%" ]
            , meter "Delivery time (days)" 8 [ Chart.range 0 30, Chart.thresholds [ ( 14, Success ), ( 21, Warning ), ( 30, Danger ) ] ]
            , meter "Without zones" 40 []
            , meter "Below the scale" -5 [ Chart.thresholds zones ]
            ]
        )
    ]



-- SPARKLINE


sparklineExamples : Locale -> List (Html Msg)
sparklineExamples locale =
    let
        cell label attrs values =
            Layout.stack [ Layout.gap 1 ]
                [ Text.caption label
                , Chart.sparkline (Chart.ariaLabel label :: Chart.locale locale :: attrs) values
                ]
    in
    [ Doc.example
        { title = "Sparkline"
        , description = Just "A small trend without axes, with a dot on the last value. It takes the width it is given. It has no title, so give it an ariaLabel that says what it shows."
        , code = Just "Chart.sparkline [ Chart.ariaLabel \"Orders, last 7 days\", Chart.area, Chart.size 120 ] [ 3, 5, 4, 8, 7, 9, 12 ]"
        }
        (Layout.grid [ Layout.minColumn 150, Layout.gap 4 ]
            [ cell "Rising" [ Chart.area ] [ 3, 5, 4, 8, 7, 9, 12, 11, 15 ]
            , cell "Falling" [ Chart.tone Danger ] [ 20, 18, 19, 14, 15, 9, 8 ]
            , cell "Flat" [] [ 5, 5, 5, 5, 5 ]
            , cell "Negative values" [ Chart.area, Chart.tone Warning ] [ -5, -9, -2, -14, -8, -3 ]
            , cell "One point" [] [ 42 ]
            , cell "Empty" [] []
            , cell "Loading" [ Chart.loading True ] [ 1, 2 ]
            , cell "Failed" [ Chart.failed (Remote.problem Remote.server) ] []
            , cell "Large, 120 pixels" [ Chart.size 120, Chart.height 44, Chart.area ] (List.range 0 40 |> List.map (wave 50 20 0))
            , cell "Large numbers" [] [ 1.0e12, 3.0e12, 2.0e12, 5.0e12 ]
            ]
        )
    ]



-- LOADING, FAILED AND EMPTY


stateExamples : Locale -> Model -> List (Html Msg)
stateExamples locale model =
    let
        row example kind =
            Layout.grid [ Layout.minColumn 280, Layout.gap 5 ]
                [ kind [ Chart.loading True ]
                , kind
                    [ Chart.remote (Pretend.down locale (List.member example model.retrying))
                    , Chart.id (chartId example)
                    , Chart.onRetry (Retry example)
                    ]
                , kind [ Chart.emptyText "No orders in this period" ]
                ]
    in
    [ Doc.example
        { title = "Loading, failed and empty"
        , description = Just "Every chart shows a skeleton of the right height while it loads, a short message with “Try again” when it failed, and an empty state when there is no data. With Chart.remote, loading and failure come straight from a Remote. Here the backend is down on purpose: “Try again” loads for a moment and fails again."
        , code = Just """Chart.line [ Chart.remote model.visits ] (Remote.withDefault [] model.visits)

Chart.bar [ Chart.failed problem, Chart.onRetry Reload ] []

Chart.donut [ Chart.emptyText "No data" ] []"""
        }
        (Layout.stack [ Layout.gap 6 ]
            [ row "line" (\attrs -> Chart.line ([ Chart.title "Line", Chart.height 120, Chart.locale locale ] ++ attrs) [])
            , row "bar" (\attrs -> Chart.bar ([ Chart.title "Bars", Chart.height 120, Chart.locale locale ] ++ attrs) [])
            , row "donut" (\attrs -> Chart.donut ([ Chart.title "Donut", Chart.locale locale ] ++ attrs) [])
            ]
        )
    ]
