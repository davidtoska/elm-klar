module Klar.Chart.Config exposing (..)

{-| Chart attributes, default configuration and threshold/legend decisions.
-}

import Klar.Chart.Numbers exposing (compact, dropTrailingZeros, firstJust, formatLabel, formatTick, formatValue, isWhole, missingOr, num, pct, percentText, roundTo, sanitize, smartFormat, stepDecimals, tickGutter, trimFraction)
import Klar.Chart.Types exposing (Attribute(..), Axis, Config, Data(..), LegendItem, PSeries, Piece, Prepared, Segment(..), Series(..), Slice, State(..), Texts)
import Klar.Date exposing (Date)
import Klar.Internal.Freshness as Freshness exposing (Freshness)
import Klar.Locale as Locale exposing (Locale)
import Klar.Settings as Settings exposing (Settings)
import Klar.Theme as Theme exposing (Tone(..))


configure : List (Attribute msg) -> Config msg
configure attributes =
    List.foldl (\(Attribute change) config -> change config)
        { title = Nothing
        , description = Nothing
        , ariaLabel = Nothing
        , categories = []
        , dates = []
        , height = Nothing
        , width = Nothing
        , area = False
        , pointsOnHover = False
        , stacked = False
        , horizontal = False
        , valueLabels = False
        , legend = Nothing
        , yMin = Nothing
        , yMax = Nothing
        , includeZero = False
        , valueFormat = Nothing
        , unit = ""
        , locale = Locale.default
        , settings = Settings.default
        , tone = Nothing
        , busy = False
        , failure = Nothing
        , freshness = Freshness.Fresh
        , fromRemote = False
        , onRetry = Nothing
        , onSelect = Nothing
        , id = Nothing
        , emptyText = Nothing
        , centerLabel = Nothing
        , centerCaption = Nothing
        , thresholds = []
        , rangeMin = 0
        , rangeMax = 100
        , maxLabels = Nothing
        }
        attributes


{-| The DOM id of the chart, which then sits in an element that can take focus
in every state (loading, failed, old data, drawn). The "Try again" button is
replaced when the request starts again and focus would fall back to the page: call
[`Klar.focus`](Klar#focus) with this id in the same `update`
branch. The id must be unique on the page.
-}
id : String -> Attribute msg
id value =
    Attribute (\config -> { config | id = Just value })


{-| A visible heading above the chart. It is also the accessible name of the
chart (and the caption of its hidden data table), unless `ariaLabel` is set. A
meter shows it at the left above the scale. A sparkline has no room for a
heading: give it an `ariaLabel` instead.
-}
title : String -> Attribute msg
title text =
    Attribute (\config -> { config | title = Just text })


{-| A line of explanation under the title, for example the period or the source
of the numbers. A meter and a sparkline do not show it.
-}
description : String -> Attribute msg
description text =
    Attribute (\config -> { config | description = Just text })


{-| The accessible name of the chart, for screen readers. Use it when there is no
visible `title`; when both are set, the `ariaLabel` is the accessible name (and
the caption of the hidden data table) and the title is only shown. A sparkline
has no title, so give it an `ariaLabel` that says what it shows: "Orders, last 7
days".
-}
ariaLabel : String -> Attribute msg
ariaLabel text =
    Attribute (\config -> { config | ariaLabel = Just text })


{-| The names of the categories of a line or bar chart, one per value, in the
order of the values. They label the x axis (the left side of a horizontal bar
chart). A missing name is replaced by its position (1, 2, 3 ...), and names
beyond the longest series add empty categories.

    Chart.categories [ "Jan", "Feb", "Mar", "Apr" ]

-}
categories : List String -> Attribute msg
categories labels =
    Attribute (\config -> { config | categories = labels, dates = [] })


{-| The categories of a line or bar chart when they are days, one per value, in
the order of the values. The axis writes them as short as a label can be (`21 Sep`
in English, `21. sep.` in Norwegian, see `Format.dateShort`), so that eight of them
fit under a half page chart, and the tooltip and the text alternative write the
whole date. `categories` and `dates` replace each other.

    Chart.line [ Chart.dates (List.map .day model.sales) ]

-}
dates : List Date -> Attribute msg
dates days =
    Attribute (\config -> { config | dates = days, categories = [] })


{-| The height of the plot in pixels, kept between 16 and 1200. The defaults are
220 for line and bar charts, a height that follows the number of categories for
horizontal bars, and 28 for a sparkline. Donut, gauge and meter have a fixed
shape (see `width`).
-}
height : Int -> Attribute msg
height pixels =
    Attribute (\config -> { config | height = Just (clamp 16 1200 pixels) })


{-| The width in pixels of a sparkline, donut or gauge, kept between 24 and 1200.
Without it they take what the container gives them (sparkline: 100%, donut:
168px, gauge: 200px), and never more than the container. Line charts, bar charts
and meters always fill their container.
-}
width : Int -> Attribute msg
width pixels =
    Attribute (\config -> { config | width = Just (clamp 24 1200 pixels) })


{-| Fills the area under the line, for every series of a line chart and for a
sparkline. A filled area reads as an amount counted from zero, so the value axis
of a line chart with `area` includes zero.
-}
area : Attribute msg
area =
    Attribute (\config -> { config | area = True })


{-| Shows the markers of a line chart only while the pointer (or the keyboard
focus, see `onSelect`) is on a category, for a calm line through many points. By
default every point has a marker for up to 40 categories, and beyond that markers
are shown on hover only. The markers of a `dashed` series are always on hover only.
-}
pointsOnHover : Attribute msg
pointsOnHover =
    Attribute (\config -> { config | pointsOnHover = True })


{-| Stacks the series of a bar chart on top of each other instead of side by side.
Positive values stack upward from zero and negative values downward. The tooltip
and the data table get the total of each category.
-}
stacked : Attribute msg
stacked =
    Attribute (\config -> { config | stacked = True })


{-| Horizontal bars: good for long category names and many categories. The
height of the chart follows the number of categories, unless you set `height`.
-}
horizontal : Attribute msg
horizontal =
    Attribute (\config -> { config | horizontal = True })


{-| Prints the value at the end of each bar (the total, for stacked bars). It is
only shown when there is room: up to 24 bars in a vertical chart and up to 60 in
a horizontal one.
-}
valueLabels : Attribute msg
valueLabels =
    Attribute (\config -> { config | valueLabels = True })


{-| Shows the legend of a line or bar chart even for a single series. By default a
line or bar chart shows it for two or more series, and a donut always shows it.
`legend` and `hideLegend` replace each other.
-}
legend : Attribute msg
legend =
    Attribute (\config -> { config | legend = Just True })


{-| Leaves out the legend of a line, bar or donut chart, for a chart whose series
or slices are named in some other way (a title that says it, a table next to it).
Without the legend of a donut the slices are only named in the tooltips and in
the hidden data table. A donut with `onSelect` keeps its legend buttons, because
they are the keyboard path to the slices: out of sight until one of them has the
keyboard focus.
-}
hideLegend : Attribute msg
hideLegend =
    Attribute (\config -> { config | legend = Just False })


{-| Fixes the lower end of the value axis (the horizontal axis of a horizontal bar
chart). Values below it are cut off at the edge of the plot. A limit that cannot
make an axis, such as a minimum above the maximum, is ignored and the axis
follows the data.
-}
yMin : Float -> Attribute msg
yMin value =
    Attribute (\config -> { config | yMin = sanitize value })


{-| Fixes the upper end of the value axis (the horizontal axis of a horizontal bar
chart). Values above it are cut off at the edge of the plot. A limit that cannot
make an axis is ignored and the axis follows the data.
-}
yMax : Float -> Attribute msg
yMax value =
    Attribute (\config -> { config | yMax = sanitize value })


{-| Starts the value axis of a line chart at zero (or ends it there, for values
below zero). By default the axis of a line chart follows the data, unless the chart
has an `area`. The axis of a bar chart always includes zero: a bar is read by its
length.
-}
includeZero : Attribute msg
includeZero =
    Attribute (\config -> { config | includeZero = True })


{-| How a value is written on the axis, in the tooltips, the value labels and the
data table, and in the text of a donut, gauge or meter. Use it for currencies,
percentages and other units. When it is set, `unit` is not added.

    Chart.valueFormat (\amount -> "$" ++ String.fromFloat amount)

The default writes numbers with the separators of the `locale`, with as many
decimals as the number needs, and shortens large axis values ("2.5M").

-}
valueFormat : (Float -> String) -> Attribute msg
valueFormat format =
    Attribute (\config -> { config | valueFormat = Just format })


{-| A unit written after the value, separated by a non-breaking space: "USD".
It is added in the tooltips, the data table, the legend of a donut and the value
text of a gauge or meter, but not on the axis. It is ignored when `valueFormat`
is set.
-}
unit : String -> Attribute msg
unit text =
    Attribute (\config -> { config | unit = text })


{-| The settings of the application (`Klar.Settings`): the time zone of the time in
"Old data from 14:05". Without it the time is written in UTC and ends in "UTC".

    Chart.settings model.settings

-}
settings : Settings -> Attribute msg
settings given =
    Attribute (\config -> { config | settings = given })


{-| The language of the built-in text ("No data to show", "Line chart",
"Loading chart" and so on) and of the number format. The default is
`Locale.default`, which is English. See [Klar.Locale](Klar-Locale).
-}
locale : Locale -> Attribute msg
locale value =
    Attribute (\config -> { config | locale = value })


{-| Colors the chart by meaning instead of by palette: the first series of a line
or bar chart (the other series keep their palette colors), a sparkline, and a
gauge or meter that has no `thresholds`. The default is `Primary` (blue).
-}
tone : Tone -> Attribute msg
tone value =
    Attribute (\config -> { config | tone = Just value })


{-| The message sent by the "Try again" button of a chart from a `Remote`
(`lineRemote` and its sisters) that failed, and by the marker of old data. The
button is only shown when the problem is worth retrying (see
`Klar.Remote.isRetryable` in [Klar.Remote](Klar-Remote)); a sparkline is too small
for a message and has none.
-}
onRetry : msg -> Attribute msg
onRetry msg =
    Attribute (\config -> { config | onRetry = Just msg })


{-| Makes every category of a line or bar chart, and every slice of a donut, a
button that sends this message with its position in the lists you gave, counted
from 0: the category of `categories` (or `dates`), or the segment of the list given
to `donut`. Use it to drill down: "click the bar of warehouse B to see its late
orders".

    Chart.bar [ Chart.categories warehouses, Chart.onSelect WarehousePicked ]
        [ Chart.series "Late orders" [ 12, 4, 9 ] ]

Each category is a button in the tab order, named by its values ("Oslo. Late
orders: 12"), with a visible focus ring and a tooltip that shows its values on
hover and on keyboard focus. A donut's slices take the click, and its legend items
are the buttons that the keyboard reaches. The "Other" slice of a donut with more
than eight slices sends nothing. Without `onSelect` the chart is a picture.

-}
onSelect : (Int -> msg) -> Attribute msg
onSelect toMsg =
    Attribute (\config -> { config | onSelect = Just toMsg })


{-| Whether the categories are buttons. (A function is never compared with `==`.)
-}
selectable : Config msg -> Bool
selectable config =
    case config.onSelect of
        Just _ ->
            True

        Nothing ->
            False


{-| The text of the empty state, shown when there is nothing to draw: no series,
no values, or a donut whose slices add up to 0. The default is "No data to show".
A sparkline uses it as its accessible label. A gauge and a meter always have a
value, so they never show it.
-}
emptyText : String -> Attribute msg
emptyText text =
    Attribute (\config -> { config | emptyText = Just text })


{-| The big text in the middle of a donut or gauge. The default is the total of a
donut and the value of a gauge. A meter writes it as its value text above the
scale.
-}
centerLabel : String -> Attribute msg
centerLabel text =
    Attribute (\config -> { config | centerLabel = Just text })


{-| A small text under the center value of a donut or gauge: "orders". On a gauge
it is also part of the accessible name (which says "Gauge" without it).
-}
centerCaption : String -> Attribute msg
centerCaption text =
    Attribute (\config -> { config | centerCaption = Just text })


{-| The scale of a gauge or meter: its lowest and its highest value. The default
is 0 to 100. If the first number is the larger, the two are swapped.

    Chart.range 0 5000

-}
range : Float -> Float -> Attribute msg
range low high =
    Attribute
        (\config ->
            { config
                | rangeMin = Maybe.withDefault 0 (sanitize low)
                , rangeMax = Maybe.withDefault 100 (sanitize high)
            }
        )


{-| Zones of a gauge or meter: the upper limit of each zone and its meaning. The
zone the value falls in colors the gauge and the value of the meter. A meter also
draws every zone on its track, and a gauge a tick at each limit.

    Chart.thresholds [ ( 70, Success ), ( 90, Warning ), ( 100, Danger ) ]

Here values up to 70 are good, up to 90 a warning, and up to 100 dangerous. Let the
last limit be the top of the `range`: a value beyond it takes the color of the last
zone, but a meter leaves the part of its track after the last limit uncolored. The
zones are sorted by limit. Without thresholds the whole scale has the `tone` of the
chart.

-}
thresholds : List ( Float, Tone ) -> Attribute msg
thresholds zones =
    Attribute
        (\config ->
            { config
                | thresholds =
                    zones
                        |> List.filterMap (\( limit, t ) -> sanitize limit |> Maybe.map (\l -> ( l, t )))
                        |> List.sortBy Tuple.first
            }
        )


{-| At most this many category labels on the axis of a line or bar chart. The
rest are left out evenly (every second, third ... label is shown), and the label
of the last category is always there. The default is 12 for a line chart and a
vertical bar chart; a horizontal bar chart names every bar that has a row of at
least 14 pixels. The value is kept between 2 and 60.
-}
maxLabels : Int -> Attribute msg
maxLabels n =
    Attribute (\config -> { config | maxLabels = Just (clamp 2 60 n) })


heightOf : Config msg -> Int -> Int
heightOf config fallback =
    Maybe.withDefault fallback config.height


showLegend : Config msg -> Int -> Bool
showLegend config seriesCount =
    case config.legend of
        Just value ->
            value

        Nothing ->
            seriesCount >= 2


{-| The meaning of the zone a value is in: the first zone whose upper limit
it does not exceed; beyond the last limit, the last zone.
-}
zoneToneFor : Config msg -> Float -> Maybe Tone
zoneToneFor config value =
    case config.thresholds of
        [] ->
            config.tone

        zones ->
            case List.filter (\( limit, _ ) -> value <= limit) zones |> List.head of
                Just ( _, t ) ->
                    Just t

                Nothing ->
                    zones |> List.reverse |> List.head |> Maybe.map Tuple.second
