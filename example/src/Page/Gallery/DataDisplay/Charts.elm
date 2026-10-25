module Page.Gallery.DataDisplay.Charts exposing (Model, Msg, init, update, view)

{-| The chart section: line, bar and donut charts, gauges and meters, sparklines,
and their loading, failed and empty states.
-}

import Api.Types as Types exposing (OrderStatus(..))
import Html exposing (Html)
import Klar
import Klar.Chart as Chart
import Klar.Format as Format
import Klar.Layout as Layout
import Klar.Locale as Locale exposing (Locale)
import Klar.Remote as Remote
import Klar.RemoteView as RemoteView
import Klar.Text as Text
import Klar.Theme exposing (Tone(..))
import Page.Gallery.DataDisplay.Pretend as Pretend
import Showcase.Config as Config
import Showcase.Doc as Doc
import Showcase.Options as Options
import Showcase.Sample as Sample



-- MODEL


{-| The examples whose "Try again" is on its way.
-}
type alias Model =
    { retrying : List String
    , picked : Maybe Int
    }


type Msg
    = Retry String
    | RetryDone String
    | Focused
    | Picked Int


init : Model
init =
    { retrying = [], picked = Nothing }


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        Retry example ->
            -- "Try again" is replaced by the skeleton: focus goes to the chart (its id).
            ( { model | retrying = example :: model.retrying }
            , Cmd.batch [ Pretend.later (RetryDone example), Klar.focus (chartId example) Focused ]
            )

        Focused ->
            ( model, Cmd.none )

        Picked index ->
            ( { model | picked = Just index }, Cmd.none )

        RetryDone example ->
            ( { model | retrying = List.filter (\other -> other /= example) model.retrying }, Cmd.none )


chartId : String -> String
chartId example =
    "chart-retry-" ++ example



-- VIEW


view : Config.Config -> Locale -> Model -> Html Msg
view playground locale model =
    Doc.configuredSection playground
        [ "Chart" ]
        "Charts"
        "The charts are built from HTML and CSS: bars, markers and donut slices are elements, and only the lines and areas are SVG (a mask in the color of the series). They fill the width of their container, text and lines keep a fixed size, and every chart has a hidden data table for screen readers. Hold the pointer over a category to see the values. Colors are handed out to the series in a fixed order; pin a series to a color with withSlot to keep it when other series come and go."
        (lineExamples playground locale
            ++ barExamples playground locale model
            ++ donutExamples playground locale
            ++ gaugeExamples playground locale
            ++ sparklineExamples playground locale
            ++ stateExamples playground locale model
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


lineExamples : Config.Config -> Locale -> List (Html Msg)
lineExamples playground locale =
    let
        dense =
            List.range 0 364
                |> List.map (\i -> toFloat (round (60 + 25 * sin (toFloat i / 28) + 8 * sin (toFloat i / 3))))

        compactLine title values =
            Chart.line (Options.klarChart playground (List.concat [ Config.keep playground "Chart" "title" (Chart.title title), Config.keep playground "Chart" "height" (Chart.height 150), Config.keep playground "Chart" "locale" (Chart.locale locale) ])) values
    in
    [ Doc.configuredExample playground
        [ "Chart" ]
        { title = "Line chart with several series"
        , description = Just "A dashed line is a forecast or a target. The months that are not over yet are gaps in the line, not zeros."
        , code = Just """Chart.line [ Chart.title "Orders per month", Chart.categories months ]
    [ Chart.series "2025" [ 120, 180, 90, 220 ]
    , Chart.seriesMaybe "2026" [ Just 140, Just 200, Nothing, Nothing ]
    , Chart.series "Target" [ 280, 280, 280, 280 ] |> Chart.dashed |> Chart.withSlot 8
    ]"""
        }
        (Chart.line
            (Options.klarChart playground
                (List.concat
                    [ Config.keep playground "Chart" "title" (Chart.title "Orders per month")
                    , Config.keep playground "Chart" "description" (Chart.description "All warehouses")
                    , Config.keep playground "Chart" "categories" (Chart.categories (months locale))
                    , Config.keep playground "Chart" "height" (Chart.height 240)
                    , Config.keep playground "Chart" "locale" (Chart.locale locale)
                    ]
                )
            )
            [ Chart.series "2025" (twelve 240 90 0)
            , Chart.seriesMaybe "2026" (List.map Just (List.take 9 (twelve 260 100 0.4)) ++ [ Nothing, Nothing, Nothing ])
            , Chart.series "Target" (List.repeat 12 280) |> Chart.dashed |> Chart.withSlot 8
            ]
        )
    , Doc.configuredExample playground
        [ "Chart" ]
        { title = "Meaning, markers and axis"
        , description = Just "A series that means good or bad says so with withTone: the status colors are reserved for that. points, includeZero and maxLabels adjust the markers, the value axis and the number of category labels."
        , code = Just """Chart.line
    [ Chart.title "Deliveries per week"
    , Chart.categories weeks
    , Chart.pointsOnHover
    , Chart.includeZero
    , Chart.maxLabels 6
    ]
    [ Chart.series "On time" onTime |> Chart.withTone Success
    , Chart.series "Late" late |> Chart.withTone Danger
    ]"""
        }
        (Chart.line
            (Options.klarChart playground
                (List.concat
                    [ Config.keep playground "Chart" "title" (Chart.title "Deliveries per week")
                    , Config.keep playground "Chart" "categories" (Chart.categories (List.range 1 26 |> List.map (\week -> "Week " ++ String.fromInt week)))
                    , Config.keep playground "Chart" "pointsOnHover" Chart.pointsOnHover
                    , Config.keep playground "Chart" "includeZero" Chart.includeZero
                    , Config.keep playground "Chart" "maxLabels" (Chart.maxLabels 6)
                    , Config.keep playground "Chart" "height" (Chart.height 200)
                    , Config.keep playground "Chart" "locale" (Chart.locale locale)
                    ]
                )
            )
            [ Chart.series "On time" (List.map (wave 180 25 0) (List.range 0 25)) |> Chart.withTone Success
            , Chart.series "Late" (List.map (wave 22 8 1.5) (List.range 0 25)) |> Chart.withTone Danger
            ]
        )
    , Doc.configuredExample playground
        [ "Chart" ]
        { title = "Negative values and an area"
        , description = Just "The axis gets a zero line when the data crosses zero. The area is a light, transparent version of the color of the line."
        , code = Just "Chart.line [ Chart.area, Chart.unit \"MUSD\", Chart.categories months ] [ Chart.series \"Net result\" [ 12, 8, -4, -11 ] ]"
        }
        (Chart.line
            (Options.klarChart playground
                (List.concat
                    [ Config.keep playground "Chart" "title" (Chart.title "Net result per month")
                    , Config.keep playground "Chart" "unit" (Chart.unit "MUSD")
                    , Config.keep playground "Chart" "area" Chart.area
                    , Config.keep playground "Chart" "categories" (Chart.categories (months locale))
                    , Config.keep playground "Chart" "height" (Chart.height 200)
                    , Config.keep playground "Chart" "locale" (Chart.locale locale)
                    ]
                )
            )
            [ Chart.series "Net result" [ 12, 8, -4, -11, -6, 3, 9, 14, 6, -2, -8, 5 ] ]
        )
    , Doc.configuredExample playground
        [ "Chart" ]
        { title = "Many points"
        , description = Just "365 values. The markers only show under the pointer, and the axis shows at most twelve names. The tooltip shows the day and the value."
        , code = Just "Chart.line [ Chart.area, Chart.categories days ] [ Chart.series \"Utilization\" values ]"
        }
        (Chart.line
            (Options.klarChart playground
                (List.concat
                    [ Config.keep playground "Chart" "title" (Chart.title "Warehouse utilization per day")
                    , Config.keep playground "Chart" "unit" (Chart.unit "%")
                    , Config.keep playground "Chart" "area" Chart.area
                    , Config.keep playground "Chart" "categories" (Chart.categories (List.range 1 365 |> List.map (\day -> "Day " ++ String.fromInt day)))
                    , Config.keep playground "Chart" "height" (Chart.height 200)
                    , Config.keep playground "Chart" "locale" (Chart.locale locale)
                    ]
                )
            )
            [ Chart.series "Utilization" dense ]
        )
    , Doc.configuredExample playground
        [ "Chart" ]
        { title = "Awkward data, line chart"
        , description = Just "One point, equal values, a gap in the middle, huge numbers, tiny decimals and no data. Nothing breaks, and the axes get sensible numbers."
        , code = Nothing
        }
        (Layout.grid (Options.klarLayout playground (List.concat [ Config.keep playground "Layout" "minColumn" (Layout.minColumn 300), Config.keep playground "Layout" "gap" (Layout.gap 6) ]))
            [ Chart.line (Options.klarChart playground (List.concat [ Config.keep playground "Chart" "title" (Chart.title "One point"), Config.keep playground "Chart" "height" (Chart.height 150), Config.keep playground "Chart" "categories" (Chart.categories [ "Jan" ]), Config.keep playground "Chart" "locale" (Chart.locale locale) ])) [ Chart.series "A" [ 42 ] ]
            , compactLine "All values equal" [ Chart.series "A" [ 5, 5, 5, 5, 5 ] ]
            , Chart.line (Options.klarChart playground (List.concat [ Config.keep playground "Chart" "title" (Chart.title "Gap in the middle"), Config.keep playground "Chart" "height" (Chart.height 150), Config.keep playground "Chart" "locale" (Chart.locale locale) ]))
                [ Chart.seriesMaybe "A" [ Just 3, Just 6, Nothing, Nothing, Just 4, Just 8, Just 7 ] ]
            , compactLine "Large numbers (billions)" [ Chart.series "Revenue" [ 1.2e9, 2.8e9, 2.1e9, 4.8e9, 3.9e9, 6.2e9 ] ]
            , compactLine "Even larger (trillions)" [ Chart.series "Value" [ 1.0e12, 3.2e12, 2.4e12, 4.8e12 ] ]
            , compactLine "Small decimals" [ Chart.series "Share" [ 0.0003, 0.0012, 0.0008, 0.0021, 0.0015 ] ]
            , compactLine "Only negative" [ Chart.series "Deviation" [ -42, -18, -30, -75, -60 ] ]
            , compactLine "Extreme numbers (1e15)" [ Chart.series "A" [ 1.0e15, -1.0e15, 0, 5.0e14 ] ]
            , compactLine "NaN and infinity become gaps" [ Chart.series "A" [ 1 / 0, 0 / 0, 5, 7 ], Chart.series "B" [ 2, 4, 1 / 0, 3 ] ]
            , Chart.line (Options.klarChart playground (List.concat [ Config.keep playground "Chart" "title" (Chart.title "Empty"), Config.keep playground "Chart" "height" (Chart.height 150), Config.keep playground "Chart" "locale" (Chart.locale locale) ])) []
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


barExamples : Config.Config -> Locale -> Model -> List (Html Msg)
barExamples playground locale model =
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
            Chart.bar (Options.klarChart playground (List.concat [ Config.keep playground "Chart" "title" (Chart.title title), Config.keep playground "Chart" "height" (Chart.height 160), Config.keep playground "Chart" "locale" (Chart.locale locale) ]) ++ attrs) data
    in
    [ Doc.configuredExample playground
        [ "Chart" ]
        { title = "Grouped bar chart, with a click on a warehouse"
        , description = Just "Bars are 24 pixels wide at most, and rounded only at the end away from the axis. With Chart.onSelect every warehouse is a button: click it, or Tab to it (its values show in a tooltip) and press Enter."
        , code = Just """Chart.bar
    [ Chart.title "Orders per warehouse"
    , Chart.categories warehouses
    , Chart.onSelect WarehousePicked
    ]
    [ Chart.series "Waiting" [ 120, 140, 110 ]
    , Chart.series "Shipped" [ 90, 85, 100 ]
    , Chart.series "Delivered" [ 250, 270, 240 ]
    ]"""
        }
        (Layout.stack (Options.klarLayout playground (List.concat [ Config.keep playground "Layout" "gap" (Layout.gap 2) ]))
            [ Chart.bar
                (Options.klarChart playground
                    (List.concat
                        [ Config.keep playground "Chart" "title" (Chart.title "Orders per warehouse")
                        , Config.keep playground "Chart" "categories" (Chart.categories (List.map .name warehouseRows))
                        , Config.keep playground "Chart" "height" (Chart.height 240)
                        , Config.keep playground "Chart" "locale" (Chart.locale locale)
                        , Config.keep playground "Chart" "onSelect" (Chart.onSelect Picked)
                        ]
                    )
                )
                [ Chart.series "Waiting" (List.map (.waiting >> toFloat) warehouseRows)
                , Chart.series "Shipped" (List.map (.shipped >> toFloat) warehouseRows)
                , Chart.series "Delivered" (List.map (.delivered >> toFloat) warehouseRows)
                ]
            , Text.caption
                (case model.picked |> Maybe.andThen (\index -> List.drop index warehouseRows |> List.head) of
                    Just row ->
                        "Picked: " ++ row.name

                    Nothing ->
                        "Pick a warehouse"
                )
            ]
        )
    , Doc.configuredExample playground
        [ "Chart" ]
        { title = "Stacked, with totals"
        , description = Just "The parts are separated by a two pixel gap, not by a border. The number above a bar is the total."
        , code = Just """Chart.bar [ Chart.stacked, Chart.valueLabels, Chart.categories quarters ]
    [ Chart.series "Hardware" [ 310, 290, 330 ]
    , Chart.series "Electronics" [ 220, 240, 180 ]
    ]"""
        }
        (Chart.bar
            (Options.klarChart playground
                (List.concat
                    [ Config.keep playground "Chart" "title" (Chart.title "Revenue per quarter")
                    , Config.keep playground "Chart" "description" (Chart.description "Thousand USD")
                    , Config.keep playground "Chart" "categories" (Chart.categories quarters)
                    , Config.keep playground "Chart" "stacked" Chart.stacked
                    , Config.keep playground "Chart" "valueLabels" Chart.valueLabels
                    , Config.keep playground "Chart" "height" (Chart.height 260)
                    , Config.keep playground "Chart" "locale" (Chart.locale locale)
                    ]
                )
            )
            [ Chart.series "Hardware" [ 310, 290, 330, 360, 340, 320, 350, 380 ]
            , Chart.series "Electronics" [ 220, 240, 180, 260, 250, 270, 210, 290 ]
            , Chart.series "Packaging" [ 140, 150, 160, 130, 170, 180, 150, 160 ]
            , Chart.series "Other" [ 40, 35, 50, 45, 30, 55, 48, 52 ]
            ]
        )
    , Doc.configuredExample playground
        [ "Chart", "Format" ]
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
            (Options.klarChart playground
                (List.concat
                    [ Config.keep playground "Chart" "title" (Chart.title "Utilization by area")
                    , Config.keep playground "Chart" "categories" (Chart.categories areas)
                    , Config.keep playground "Chart" "horizontal" Chart.horizontal
                    , Config.keep playground "Chart" "valueLabels" Chart.valueLabels
                    , Config.keep playground "Chart" "yMax" (Chart.yMax 100)
                    , Config.keep playground "Chart" "valueFormat" (Chart.valueFormat (\v -> Format.percent locale 0 (v / 100)))
                    , Config.keep playground "Chart" "locale" (Chart.locale locale)
                    ]
                )
            )
            [ Chart.series "Utilization" utilization ]
        )
    , Doc.configuredExample playground
        [ "Chart" ]
        { title = "Awkward data, bar chart"
        , description = Just "Negative values go below the zero line, large numbers get short numbers on the axis, and there are single bars, many zeros and 40 categories. Hold the pointer over a bar, also the thin ones."
        , code = Nothing
        }
        (Layout.grid (Options.klarLayout playground (List.concat [ Config.keep playground "Layout" "minColumn" (Layout.minColumn 300), Config.keep playground "Layout" "gap" (Layout.gap 6) ]))
            [ small "Negative values"
                (Options.klarChart playground (List.concat [ Config.keep playground "Chart" "categories" (Chart.categories (List.take 5 (months locale))) ]))
                [ Chart.series "In" [ 12, 8, -5, 15, -9 ], Chart.series "Out" [ -6, -14, 3, -8, 10 ] ]
            , small "Stacked with negatives"
                (Options.klarChart playground (List.concat [ Config.keep playground "Chart" "categories" (Chart.categories [ "A", "B", "C", "D" ]), Config.keep playground "Chart" "stacked" Chart.stacked ]))
                [ Chart.series "Revenue" [ 30, 25, 40, 20 ], Chart.series "Cost" [ -12, -18, -9, -22 ] ]
            , small "One bar" (Options.klarChart playground (List.concat [ Config.keep playground "Chart" "categories" (Chart.categories [ "Total" ]) ])) [ Chart.series "Count" [ 1284 ] ]
            , small "Large numbers"
                (Options.klarChart playground (List.concat [ Config.keep playground "Chart" "categories" (Chart.categories [ "A", "B", "C", "D" ]) ]))
                [ Chart.series "Revenue" [ 4.2e12, 3.1e12, 5.6e12, 1.9e12 ] ]
            , small "Zeros and small values"
                (Options.klarChart playground (List.concat [ Config.keep playground "Chart" "categories" (Chart.categories [ "a", "b", "c", "d", "e" ]) ]))
                [ Chart.series "n" [ 0, 0, 1, 0, 120 ] ]
            , small "40 categories"
                (Options.klarChart playground (List.concat [ Config.keep playground "Chart" "categories" (Chart.categories (List.range 1 40 |> List.map String.fromInt)) ]))
                [ Chart.series "Value" (List.range 1 40 |> List.map (wave 50 30 0)) ]
            , small "Many series"
                (Options.klarChart playground (List.concat [ Config.keep playground "Chart" "categories" (Chart.categories [ "X", "Y", "Z" ]) ]))
                (List.range 1 8
                    |> List.map (\i -> Chart.series ("Series " ++ String.fromInt i) [ toFloat (i * 3), toFloat (30 - i * 2), toFloat (i * i) ])
                )
            , Chart.bar (Options.klarChart playground (List.concat [ Config.keep playground "Chart" "title" (Chart.title "Empty"), Config.keep playground "Chart" "height" (Chart.height 160), Config.keep playground "Chart" "locale" (Chart.locale locale) ])) []
            ]
        )
    ]



-- DONUT


donutExamples : Config.Config -> Locale -> List (Html Msg)
donutExamples playground locale =
    let
        byStatus =
            Types.allOrderStatuses
                |> List.map
                    (\status ->
                        Chart.segment (Types.orderStatusLabel status)
                            (toFloat (List.length (List.filter (\order -> order.status == status) Sample.orders)))
                    )

        small title attrs segments =
            Chart.donut (Options.klarChart playground (List.concat [ Config.keep playground "Chart" "title" (Chart.title title), Config.keep playground "Chart" "width" (Chart.width 132), Config.keep playground "Chart" "locale" (Chart.locale locale) ]) ++ attrs) segments
    in
    [ Doc.configuredExample playground
        [ "Chart" ]
        { title = "Donut chart"
        , description = Just "The parts of one whole; it works best with six parts at most. The number in the middle is the total, unless you set something else. Hold the pointer over a part: the others fade and the tooltip shows the value and the share."
        , code = Just """Chart.donut [ Chart.centerCaption "orders" ]
    [ Chart.segment "Shipped" 420
    , Chart.segment "Picking" 310
    ]"""
        }
        (Chart.donut
            (Options.klarChart playground
                (List.concat
                    [ Config.keep playground "Chart" "title" (Chart.title "Orders by status")
                    , Config.keep playground "Chart" "centerCaption" (Chart.centerCaption "orders")
                    , Config.keep playground "Chart" "locale" (Chart.locale locale)
                    ]
                )
            )
            byStatus
        )
    , Doc.configuredExample playground
        [ "Chart", "Format" ]
        { title = "Awkward data, donut chart"
        , description = Just "One whole part, twelve parts (the smallest are folded into “Other”), only zeros, microscopic parts and parts with a meaning (green, amber, red)."
        , code = Just """Chart.donut [ Chart.centerLabel "92%", Chart.centerCaption "on time" ]
    [ Chart.segment "On time" 92 |> Chart.segmentTone Success
    , Chart.segment "At risk" 5 |> Chart.segmentTone Warning
    , Chart.segment "Late" 3 |> Chart.segmentTone Danger
    ]"""
        }
        (Layout.grid (Options.klarLayout playground (List.concat [ Config.keep playground "Layout" "minColumn" (Layout.minColumn 330), Config.keep playground "Layout" "gap" (Layout.gap 6) ]))
            [ small "One whole part" [] [ Chart.segment "All" 100 ]
            , small "Twelve parts" [] (List.range 1 12 |> List.map (\i -> Chart.segment ("Part " ++ String.fromInt i) (toFloat (200 - i * 14))))
            , small "Only zeros" [] [ Chart.segment "A" 0, Chart.segment "B" 0 ]
            , small "Microscopic parts" [] [ Chart.segment "Main part" 9950, Chart.segment "Small" 30, Chart.segment "Smallest" 20 ]
            , small "Parts with a meaning"
                (Options.klarChart playground (List.concat [ Config.keep playground "Chart" "centerLabel" (Chart.centerLabel (Format.percent locale 0 0.92)), Config.keep playground "Chart" "centerCaption" (Chart.centerCaption "on time") ]))
                [ Chart.segment "On time" 92 |> Chart.segmentTone Success
                , Chart.segment "At risk" 5 |> Chart.segmentTone Warning
                , Chart.segment "Late" 3 |> Chart.segmentTone Danger
                ]
            , small "Large numbers" [] [ Chart.segment "A" 4.2e12, Chart.segment "B" 3.1e12 ]
            ]
        )
    ]



-- GAUGE AND METER


gaugeExamples : Config.Config -> Locale -> List (Html Msg)
gaugeExamples playground locale =
    let
        zones =
            [ ( 70, Success ), ( 90, Warning ), ( 100, Danger ) ]

        gauge title value attrs =
            Chart.gauge (Options.klarChart playground (List.concat [ Config.keep playground "Chart" "title" (Chart.title title), Config.keep playground "Chart" "width" (Chart.width 190), Config.keep playground "Chart" "locale" (Chart.locale locale) ]) ++ attrs) value

        meter title value attrs =
            Chart.meter (Options.klarChart playground (List.concat [ Config.keep playground "Chart" "title" (Chart.title title), Config.keep playground "Chart" "locale" (Chart.locale locale) ]) ++ attrs) value
    in
    [ Doc.configuredExample playground
        [ "Chart" ]
        { title = "Gauge"
        , description = Just "The zone the value falls in colors the arc. The light track is a lighter step of the same color, so the state can be read along the whole arc. Values outside the scale are clipped."
        , code = Just "Chart.gauge [ Chart.range 0 100, Chart.thresholds [ ( 70, Success ), ( 90, Warning ), ( 100, Danger ) ] ] 84"
        }
        (Layout.row (Options.klarLayout playground (List.concat [ Config.keep playground "Layout" "gap" (Layout.gap 8), Config.keep playground "Layout" "wrap" Layout.wrap, Config.keep playground "Layout" "alignStart" Layout.alignStart ]))
            [ gauge "Low" 35 (Options.klarChart playground (List.concat [ Config.keep playground "Chart" "thresholds" (Chart.thresholds zones), Config.keep playground "Chart" "unit" (Chart.unit "%"), Config.keep playground "Chart" "centerCaption" (Chart.centerCaption "Utilization") ]))
            , gauge "High" 84 (Options.klarChart playground (List.concat [ Config.keep playground "Chart" "thresholds" (Chart.thresholds zones), Config.keep playground "Chart" "unit" (Chart.unit "%"), Config.keep playground "Chart" "centerCaption" (Chart.centerCaption "Utilization") ]))
            , gauge "Critical" 97 (Options.klarChart playground (List.concat [ Config.keep playground "Chart" "thresholds" (Chart.thresholds zones), Config.keep playground "Chart" "unit" (Chart.unit "%"), Config.keep playground "Chart" "centerCaption" (Chart.centerCaption "Utilization") ]))
            , gauge "Another scale" 150 (Options.klarChart playground (List.concat [ Config.keep playground "Chart" "range" (Chart.range 0 200), Config.keep playground "Chart" "centerCaption" (Chart.centerCaption "Orders") ]))
            , gauge "Outside the scale" 130 (Options.klarChart playground (List.concat [ Config.keep playground "Chart" "thresholds" (Chart.thresholds zones), Config.keep playground "Chart" "centerCaption" (Chart.centerCaption "Clipped") ]))
            ]
        )
    , Doc.configuredExample playground
        [ "Chart" ]
        { title = "Meter"
        , description = Just "The value as a marker on a scale with zones. Use it when the value is read against a limit."
        , code = Just "Chart.meter [ Chart.title \"Warehouse utilization\", Chart.thresholds zones ] 84"
        }
        (Layout.grid (Options.klarLayout playground (List.concat [ Config.keep playground "Layout" "minColumn" (Layout.minColumn 260), Config.keep playground "Layout" "gap" (Layout.gap 6) ]))
            [ meter "Warehouse utilization" 84 (Options.klarChart playground (List.concat [ Config.keep playground "Chart" "thresholds" (Chart.thresholds zones), Config.keep playground "Chart" "unit" (Chart.unit "%") ]))
            , meter "Delivery time (days)" 8 (Options.klarChart playground (List.concat [ Config.keep playground "Chart" "range" (Chart.range 0 30), Config.keep playground "Chart" "thresholds" (Chart.thresholds [ ( 14, Success ), ( 21, Warning ), ( 30, Danger ) ]) ]))
            , meter "Without zones" 40 []
            , meter "Below the scale" -5 (Options.klarChart playground (List.concat [ Config.keep playground "Chart" "thresholds" (Chart.thresholds zones) ]))
            ]
        )
    ]



-- SPARKLINE


sparklineExamples : Config.Config -> Locale -> List (Html Msg)
sparklineExamples playground locale =
    let
        cell label attrs values =
            Layout.stack (Options.klarLayout playground (List.concat [ Config.keep playground "Layout" "gap" (Layout.gap 1) ]))
                [ Text.caption label
                , Chart.sparkline (Chart.ariaLabel label :: Chart.locale locale :: attrs) values
                ]

        remoteCell label data =
            Layout.stack (Options.klarLayout playground (List.concat [ Config.keep playground "Layout" "gap" (Layout.gap 1) ]))
                [ Text.caption label
                , Chart.sparklineRemote (Options.klarChart playground (List.concat [ Config.keep playground "Chart" "ariaLabel" (Chart.ariaLabel label), Config.keep playground "Chart" "locale" (Chart.locale locale) ])) data
                ]
    in
    [ Doc.configuredExample playground
        [ "Chart", "Remote" ]
        { title = "Sparkline"
        , description = Just "A small trend without axes, with a dot on the last value. It takes the width it is given. It has no title, so give it an ariaLabel that says what it shows."
        , code = Just "Chart.sparkline [ Chart.ariaLabel \"Orders, last 7 days\", Chart.area, Chart.width 120 ] [ 3, 5, 4, 8, 7, 9, 12 ]"
        }
        (Layout.grid (Options.klarLayout playground (List.concat [ Config.keep playground "Layout" "minColumn" (Layout.minColumn 150), Config.keep playground "Layout" "gap" (Layout.gap 4) ]))
            [ cell "Rising" (Options.klarChart playground (List.concat [ Config.keep playground "Chart" "area" Chart.area ])) [ 3, 5, 4, 8, 7, 9, 12, 11, 15 ]
            , cell "Falling" (Options.klarChart playground (List.concat [ Config.keep playground "Chart" "tone" (Chart.tone Danger) ])) [ 20, 18, 19, 14, 15, 9, 8 ]
            , cell "Flat" [] [ 5, 5, 5, 5, 5 ]
            , cell "Negative values" (Options.klarChart playground (List.concat [ Config.keep playground "Chart" "area" Chart.area, Config.keep playground "Chart" "tone" (Chart.tone Warning) ])) [ -5, -9, -2, -14, -8, -3 ]
            , cell "One point" [] [ 42 ]
            , cell "Empty" [] []
            , remoteCell "Loading" Remote.Loading
            , remoteCell "Failed" (Remote.Failed (Remote.problem Remote.server))
            , cell "Large, 120 pixels" (Options.klarChart playground (List.concat [ Config.keep playground "Chart" "width" (Chart.width 120), Config.keep playground "Chart" "height" (Chart.height 44), Config.keep playground "Chart" "area" Chart.area ])) (List.range 0 40 |> List.map (wave 50 20 0))
            , cell "Large numbers" [] [ 1.0e12, 3.0e12, 2.0e12, 5.0e12 ]
            ]
        )
    ]



-- LOADING, FAILED AND EMPTY


stateExamples : Config.Config -> Locale -> Model -> List (Html Msg)
stateExamples playground locale model =
    let
        row example kind empty =
            Layout.grid (Options.klarLayout playground (List.concat [ Config.keep playground "Layout" "minColumn" (Layout.minColumn 280), Config.keep playground "Layout" "gap" (Layout.gap 5) ]))
                [ kind [] Remote.Loading
                , kind
                    (Options.klarChart playground
                        (List.concat
                            [ Config.keep playground "Chart" "id" (Chart.id (chartId example))
                            , Config.keep playground "Chart" "onRetry" (Chart.onRetry (Retry example))
                            ]
                        )
                    )
                    (Pretend.down locale (List.member example model.retrying))
                , kind (Options.klarChart playground (List.concat [ Config.keep playground "Chart" "emptyText" (Chart.emptyText "No orders in this period") ])) (Remote.Loaded empty)
                ]
    in
    [ Doc.configuredExample playground
        [ "Chart" ]
        { title = "Loading, failed and empty"
        , description = Just "Every chart from a Remote (lineRemote, barRemote, donutRemote, ...) shows a skeleton of the right height while it loads, a short message with “Try again” when it failed, and an empty state when there is no data. Here the backend is down on purpose: “Try again” loads for a moment and fails again."
        , code = Just """Chart.lineRemote [ Chart.onRetry Reload ]
    (Remote.map (\\days -> Chart.byDate (List.map .day days) [ Chart.series "Visits" (List.map .count days) ]) model.visits)

Chart.barRemote [ Chart.onRetry Reload, Chart.id "visits" ] (Remote.Failed problem)

Chart.donut [ Chart.emptyText "No data" ] []"""
        }
        (Layout.stack (Options.klarLayout playground (List.concat [ Config.keep playground "Layout" "gap" (Layout.gap 6) ]))
            [ row "line" (\attrs data -> Chart.lineRemote (Options.klarChart playground (List.concat [ Config.keep playground "Chart" "title" (Chart.title "Line"), Config.keep playground "Chart" "height" (Chart.height 120), Config.keep playground "Chart" "locale" (Chart.locale locale) ]) ++ attrs) data) (Chart.byCategory [] [])
            , row "bar" (\attrs data -> Chart.barRemote (Options.klarChart playground (List.concat [ Config.keep playground "Chart" "title" (Chart.title "Bars"), Config.keep playground "Chart" "height" (Chart.height 120), Config.keep playground "Chart" "locale" (Chart.locale locale) ]) ++ attrs) data) (Chart.byCategory [] [])
            , row "donut" (\attrs data -> Chart.donutRemote (Options.klarChart playground (List.concat [ Config.keep playground "Chart" "title" (Chart.title "Donut"), Config.keep playground "Chart" "locale" (Chart.locale locale) ]) ++ attrs) data) []
            ]
        )
    ]
