module Klar.Chart exposing
    ( line, bar, donut, gauge, meter, sparkline
    , lineRemote, barRemote, Data, byCategory, byDate, donutRemote, gaugeRemote, meterRemote, sparklineRemote
    , Series, series, seriesMaybe, withSlot, withTone, dashed
    , Segment, segment, segmentSlot, segmentTone
    , Attribute, title, description, ariaLabel, id, width, height, tone, locale, settings, unit, valueFormat
    , categories, dates, area, pointsOnHover, stacked, horizontal, valueLabels, legend, hideLegend, yMin, yMax, includeZero, maxLabels
    , onSelect
    , centerLabel, centerCaption, range, thresholds
    , onRetry, emptyText
    )

{-| Line, bar, donut, gauge, meter and sparkline charts, drawn without any chart
or SVG package.

Use when: numbers are shown as a trend, a comparison of categories, parts of a whole or one value against a scale.
Do not use when: the progress of a task is shown, use `Klar.Progress`; or the reader must look up exact values row by row, use `Klar.Table`.
Quick path: `line` or `bar` with `categories` and a list of `series`; data from the backend goes to `lineRemote` (and its sisters) with `onRetry`, its categories and series together in `byCategory` or `byDate`.

    import Klar.Chart as Chart
    import Klar.Theme exposing (Tone(..))

    Chart.line [ Chart.title "Orders per month", Chart.categories months ]
        [ Chart.series "2025" [ 12, 18, 9, 22 ]
        , Chart.series "2026" [ 14, 20, 15, 25 ] |> Chart.dashed
        ]

    Chart.bar [ Chart.categories warehouses, Chart.horizontal, Chart.valueLabels ]
        [ Chart.series "Utilization" [ 82, 61, 94 ] ]

    Chart.donut [ Chart.centerCaption "orders" ]
        [ Chart.segment "Shipped" 420, Chart.segment "Pending" 310 ]

    Chart.sparkline [ Chart.area ] [ 3, 5, 4, 8, 7, 9 ]

    Chart.gauge
        [ Chart.range 0 100
        , Chart.thresholds [ ( 70, Success ), ( 90, Warning ), ( 100, Danger ) ]
        ]
        82

    -- from the backend: model.sales is a Remote (List { month : String, amount : Float })
    Chart.lineRemote [ Chart.title "Revenue", Chart.onRetry ReloadSales ]
        (Remote.map
            (\sales -> Chart.byCategory (List.map .month sales) [ Chart.series "Revenue" (List.map .amount sales) ])
            model.sales
        )

Here `months` and `warehouses` are lists of strings with one name per value.

Use `line` for a trend over categories, usually time, `bar` to compare categories
(side by side, or `stacked` to show a total), `donut` for the parts of one whole,
`gauge` and `meter` for one value against a scale, and `sparkline` for a tiny
trend without axes inside a table cell or a [Klar.Stat](Klar-Stat) tile. For the
progress of a task use [Klar.Progress](Klar-Progress) instead. Every chart takes
a list of attributes first. The charts share their attributes, and an attribute
that a chart has no use for is ignored.

How it is built: bars, markers, gridlines, tick labels and donut slices are
plain HTML elements positioned with percentages, so a chart fills the width of
its container and its text stays 11px at any width. The only SVG is the line
and the area under it: Elm writes a small SVG document (numbers only, with
non-scaling strokes, so a line is 2px at any stretch) as a data URI and the
element uses it as a CSS mask, exactly like the icons in [Klar.Icon](Klar-Icon).
The element's background is the series color, so the stylesheet owns every color
(the custom properties `--klar-chart-1` to `--klar-chart-8`). Nothing here needs
`innerHTML` (Elm 0.19.1 and later refuse to set it), and no data string is ever
written as markup: Elm escapes it.

A line, bar or donut chart is a `role="img"` with a text alternative ("Line
chart. Orders per month. 2 series, 4 points"), followed by a visually hidden
data table of at most 120 rows, so the numbers are never only in the picture. A
gauge and a meter are a `role="meter"` with their value, minimum and maximum. A
sparkline is an image labelled with its `ariaLabel` and a summary of its numbers
("7 points, low 3, high 12, last 12"). Native tooltips (`title`) show the values
on hover. Tooltips enhance, they never gate. With `onSelect` every category (and
every legend item of a donut) is a button: it can be clicked, reached with Tab and
read aloud, and it shows its values in a tooltip on hover and on keyboard focus.

Series get the colors of an eight-color palette in the order you give them, and
the palette starts over after eight. Use `withSlot` to pin a series to a slot,
so that its color does not change when other series come and go. A series that
means good or bad should say so with `withTone`: the status colors are reserved
for that.

Data from the backend goes to the sister of the chart that takes a `Remote`
(`lineRemote`, `barRemote`, `donutRemote`, `sparklineRemote`, `gaugeRemote`,
`meterRemote`): it draws the skeleton, the failure with "Try again" (`onRetry`),
the empty state, the data, a refresh (dimmed) and old data ("Old data from 14:05").
Shape the data with `Remote.map`. A line or bar chart from a `Remote` takes its
categories in the same value as its series (`byCategory`, `byDate`), so the names
under the axis always belong to the values above them. The built-in text ("No data to show", the names
of the chart kinds and so on) is English unless you set `locale`. Numbers on the
axes and in the tooltips follow the locale too, or your own `valueFormat`.


# Charts

@docs line, bar, donut, gauge, meter, sparkline


# Charts from a Remote

@docs lineRemote, barRemote, Data, byCategory, byDate, donutRemote, gaugeRemote, meterRemote, sparklineRemote


# Series

@docs Series, series, seriesMaybe, withSlot, withTone, dashed


# Segments

@docs Segment, segment, segmentSlot, segmentTone


# Attributes

@docs Attribute, title, description, ariaLabel, id, width, height, tone, locale, settings, unit, valueFormat


# Line and bar charts

@docs categories, dates, area, pointsOnHover, stacked, horizontal, valueLabels, legend, hideLegend, yMin, yMax, includeZero, maxLabels


# Selecting a category or segment

@docs onSelect


# Donut, gauge and meter

@docs centerLabel, centerCaption, range, thresholds


# Failure and empty

@docs onRetry, emptyText

-}

import Array exposing (Array)
import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Events
import Klar.Chart.Core as Core
import Klar.Chart.Data as Data
import Klar.Chart.Types as Types
import Klar.Date exposing (Date)
import Klar.EmptyState as EmptyState
import Klar.ErrorState as ErrorState
import Klar.Format as Format
import Klar.Icon as Icon
import Klar.Internal as Internal
import Klar.Internal.Freshness as Freshness exposing (Freshness)
import Klar.Locale as Locale exposing (Locale)
import Klar.Remote as Remote exposing (Problem, Remote)
import Klar.Settings as Settings exposing (Settings)
import Klar.Skeleton as Skeleton
import Klar.Theme as Theme exposing (Tone(..))


{-| A named row of values, one per category: the data of a line or bar chart.
Make one with `series` or `seriesMaybe`, adjust it with `withSlot`, `withTone`
and `dashed`, and pass a list of them to `line` or `bar`.
-}
type Series
    = Series
        { name : String
        , values : List (Maybe Float)
        , color : Maybe Int
        , tone : Maybe Tone
        , dashed : Bool
        }


{-| One slice of a donut. Make one with `segment`, adjust it with
`segmentSlot` and `segmentTone`, and pass a list of them to `donut`.
-}
type Segment
    = Segment
        { label : String
        , value : Float
        , color : Maybe Int
        , tone : Maybe Tone
        }


{-| A series with a name and its values, in the order of the categories. The
name is shown in the legend, in the tooltips and in the data table.

    Chart.series "2026" [ 14, 20, 15, 25 ]

Values that are not numbers (NaN, infinity) become gaps in the line; use
`seriesMaybe` to leave gaps on purpose.

-}
series : String -> List Float -> Series
series arg1 arg2 =
    fromCoreSeries (Data.series arg1 arg2)


{-| Like `series`, with explicit gaps for missing measurements: a `Nothing`
breaks the line (or leaves out the bar), and the data table shows a dash.

    Chart.seriesMaybe "Temperature" [ Just 4, Just 6, Nothing, Just 9 ]

-}
seriesMaybe : String -> List (Maybe Float) -> Series
seriesMaybe arg1 arg2 =
    fromCoreSeries (Data.seriesMaybe arg1 arg2)


{-| Gives the series palette slot 1 to 8 instead of the slot that matches its
position in the list. A slot is a place in the chart palette of the theme, not a
[Klar.Color](Klar-Color): a chart has no colors of your own, so it keeps its contrast. Use it to keep a color stable when series come and go.

    Chart.series "Returns" [ 2, 3, 1 ] |> Chart.withSlot 4

-}
withSlot : Int -> Series -> Series
withSlot arg1 arg2 =
    fromCoreSeries (Data.withSlot arg1 (unwrapSeries arg2))


{-| Colors the series by meaning (`Success`, `Warning`, `Danger` ...) instead of
by position. Reserve this for series that really are good or bad, such as "On
time" and "Late". The `Tone` type is in [Klar.Theme](Klar-Theme).
-}
withTone : Tone -> Series -> Series
withTone arg1 arg2 =
    fromCoreSeries (Data.withTone arg1 (unwrapSeries arg2))


{-| Draws the series as a dashed line: for forecasts, targets, last year. It is
meant for line charts, where a dashed series also shows its markers only while
the pointer is over a category.
-}
dashed : Series -> Series
dashed arg1 =
    fromCoreSeries (Data.dashed (unwrapSeries arg1))


{-| A slice of a donut, with a label and a value. The size of a slice is its
value relative to the total of all slices.

    Chart.segment "Shipped" 420

Negative and non-numeric values count as 0, and a slice of 0 is left out.

-}
segment : String -> Float -> Segment
segment arg1 arg2 =
    fromCoreSegment (Data.segment arg1 arg2)


{-| Gives this slice palette slot 1 to 8 instead of the slot that matches its
position in the list (see `withSlot`).
-}
segmentSlot : Int -> Segment -> Segment
segmentSlot arg1 arg2 =
    fromCoreSegment (Data.segmentSlot arg1 (unwrapSegment arg2))


{-| Colors this slice by meaning (`Success`, `Warning`, `Danger` ...) instead of
by position. Reserve it for slices that really are good or bad.
-}
segmentTone : Tone -> Segment -> Segment
segmentTone arg1 arg2 =
    fromCoreSegment (Data.segmentTone arg1 (unwrapSegment arg2))


{-| A setting of a chart. Make them with the functions below and pass a list to a
chart function (`line`, `bar` and so on); later attributes win over earlier ones.
-}
type Attribute msg
    = Attribute (Types.Config msg -> Types.Config msg)


{-| The DOM id of the chart, which then sits in an element that can take focus
in every state (loading, failed, old data, drawn). The "Try again" button is
replaced when the request starts again and focus would fall back to the page: call
[`Klar.focus`](Klar#focus) with this id in the same `update`
branch. The id must be unique on the page.
-}
id : String -> Attribute msg
id arg1 =
    fromCoreAttribute (Core.id arg1)


{-| A visible heading above the chart. It is also the accessible name of the
chart (and the caption of its hidden data table), unless `ariaLabel` is set. A
meter shows it at the left above the scale. A sparkline has no room for a
heading: give it an `ariaLabel` instead.
-}
title : String -> Attribute msg
title arg1 =
    fromCoreAttribute (Core.title arg1)


{-| A line of explanation under the title, for example the period or the source
of the numbers. A meter and a sparkline do not show it.
-}
description : String -> Attribute msg
description arg1 =
    fromCoreAttribute (Core.description arg1)


{-| The accessible name of the chart, for screen readers. Use it when there is no
visible `title`; when both are set, the `ariaLabel` is the accessible name (and
the caption of the hidden data table) and the title is only shown. A sparkline
has no title, so give it an `ariaLabel` that says what it shows: "Orders, last 7
days".
-}
ariaLabel : String -> Attribute msg
ariaLabel arg1 =
    fromCoreAttribute (Core.ariaLabel arg1)


{-| The names of the categories of a line or bar chart, one per value, in the
order of the values. They label the x axis (the left side of a horizontal bar
chart). A missing name is replaced by its position (1, 2, 3 ...), and names
beyond the longest series add empty categories.

    Chart.categories [ "Jan", "Feb", "Mar", "Apr" ]

-}
categories : List String -> Attribute msg
categories arg1 =
    fromCoreAttribute (Core.categories arg1)


{-| The categories of a line or bar chart when they are days, one per value, in
the order of the values. The axis writes them as short as a label can be (`21 Sep`
in English, `21. sep.` in Norwegian, see `Format.dateShort`), so that eight of them
fit under a half page chart, and the tooltip and the text alternative write the
whole date. `categories` and `dates` replace each other.

    Chart.line [ Chart.dates (List.map .day model.sales) ]

-}
dates : List Date -> Attribute msg
dates arg1 =
    fromCoreAttribute (Core.dates arg1)


{-| The height of the plot in pixels, kept between 16 and 1200. The defaults are
220 for line and bar charts, a height that follows the number of categories for
horizontal bars, and 28 for a sparkline. Donut, gauge and meter have a fixed
shape (see `width`).
-}
height : Int -> Attribute msg
height arg1 =
    fromCoreAttribute (Core.height arg1)


{-| The width in pixels of a sparkline, donut or gauge, kept between 24 and 1200.
Without it they take what the container gives them (sparkline: 100%, donut:
168px, gauge: 200px), and never more than the container. Line charts, bar charts
and meters always fill their container.
-}
width : Int -> Attribute msg
width arg1 =
    fromCoreAttribute (Core.width arg1)


{-| Fills the area under the line, for every series of a line chart and for a
sparkline. A filled area reads as an amount counted from zero, so the value axis
of a line chart with `area` includes zero.
-}
area : Attribute msg
area =
    fromCoreAttribute Core.area


{-| Shows the markers of a line chart only while the pointer (or the keyboard
focus, see `onSelect`) is on a category, for a calm line through many points. By
default every point has a marker for up to 40 categories, and beyond that markers
are shown on hover only. The markers of a `dashed` series are always on hover only.
-}
pointsOnHover : Attribute msg
pointsOnHover =
    fromCoreAttribute Core.pointsOnHover


{-| Stacks the series of a bar chart on top of each other instead of side by side.
Positive values stack upward from zero and negative values downward. The tooltip
and the data table get the total of each category.
-}
stacked : Attribute msg
stacked =
    fromCoreAttribute Core.stacked


{-| Horizontal bars: good for long category names and many categories. The
height of the chart follows the number of categories, unless you set `height`.
-}
horizontal : Attribute msg
horizontal =
    fromCoreAttribute Core.horizontal


{-| Prints the value at the end of each bar (the total, for stacked bars). It is
only shown when there is room: up to 24 bars in a vertical chart and up to 60 in
a horizontal one.
-}
valueLabels : Attribute msg
valueLabels =
    fromCoreAttribute Core.valueLabels


{-| Shows the legend of a line or bar chart even for a single series. By default a
line or bar chart shows it for two or more series, and a donut always shows it.
`legend` and `hideLegend` replace each other.
-}
legend : Attribute msg
legend =
    fromCoreAttribute Core.legend


{-| Leaves out the legend of a line, bar or donut chart, for a chart whose series
or slices are named in some other way (a title that says it, a table next to it).
Without the legend of a donut the slices are only named in the tooltips and in
the hidden data table. A donut with `onSelect` keeps its legend buttons, because
they are the keyboard path to the slices: out of sight until one of them has the
keyboard focus.
-}
hideLegend : Attribute msg
hideLegend =
    fromCoreAttribute Core.hideLegend


{-| Fixes the lower end of the value axis (the horizontal axis of a horizontal bar
chart). Values below it are cut off at the edge of the plot. A limit that cannot
make an axis, such as a minimum above the maximum, is ignored and the axis
follows the data.
-}
yMin : Float -> Attribute msg
yMin arg1 =
    fromCoreAttribute (Core.yMin arg1)


{-| Fixes the upper end of the value axis (the horizontal axis of a horizontal bar
chart). Values above it are cut off at the edge of the plot. A limit that cannot
make an axis is ignored and the axis follows the data.
-}
yMax : Float -> Attribute msg
yMax arg1 =
    fromCoreAttribute (Core.yMax arg1)


{-| Starts the value axis of a line chart at zero (or ends it there, for values
below zero). By default the axis of a line chart follows the data, unless the chart
has an `area`. The axis of a bar chart always includes zero: a bar is read by its
length.
-}
includeZero : Attribute msg
includeZero =
    fromCoreAttribute Core.includeZero


{-| How a value is written on the axis, in the tooltips, the value labels and the
data table, and in the text of a donut, gauge or meter. Use it for currencies,
percentages and other units. When it is set, `unit` is not added.

    Chart.valueFormat (\amount -> "$" ++ String.fromFloat amount)

The default writes numbers with the separators of the `locale`, with as many
decimals as the number needs, and shortens large axis values ("2.5M").

-}
valueFormat : (Float -> String) -> Attribute msg
valueFormat arg1 =
    fromCoreAttribute (Core.valueFormat arg1)


{-| A unit written after the value, separated by a non-breaking space: "USD".
It is added in the tooltips, the data table, the legend of a donut and the value
text of a gauge or meter, but not on the axis. It is ignored when `valueFormat`
is set.
-}
unit : String -> Attribute msg
unit arg1 =
    fromCoreAttribute (Core.unit arg1)


{-| The settings of the application (`Klar.Settings`): the time zone of the time in
"Old data from 14:05". Without it the time is written in UTC and ends in "UTC".

    Chart.settings model.settings

-}
settings : Settings -> Attribute msg
settings arg1 =
    fromCoreAttribute (Core.settings arg1)


{-| The language of the built-in text ("No data to show", "Line chart",
"Loading chart" and so on) and of the number format. The default is
`Locale.default`, which is English. See [Klar.Locale](Klar-Locale).
-}
locale : Locale -> Attribute msg
locale arg1 =
    fromCoreAttribute (Core.locale arg1)


{-| Colors the chart by meaning instead of by palette: the first series of a line
or bar chart (the other series keep their palette colors), a sparkline, and a
gauge or meter that has no `thresholds`. The default is `Primary` (blue).
-}
tone : Tone -> Attribute msg
tone arg1 =
    fromCoreAttribute (Core.tone arg1)


{-| The message sent by the "Try again" button of a chart from a `Remote`
(`lineRemote` and its sisters) that failed, and by the marker of old data. The
button is only shown when the problem is worth retrying (see
`Klar.Remote.isRetryable` in [Klar.Remote](Klar-Remote)); a sparkline is too small
for a message and has none.
-}
onRetry : msg -> Attribute msg
onRetry arg1 =
    fromCoreAttribute (Core.onRetry arg1)


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
onSelect arg1 =
    fromCoreAttribute (Core.onSelect arg1)


{-| The text of the empty state, shown when there is nothing to draw: no series,
no values, or a donut whose slices add up to 0. The default is "No data to show".
A sparkline uses it as its accessible label. A gauge and a meter always have a
value, so they never show it.
-}
emptyText : String -> Attribute msg
emptyText arg1 =
    fromCoreAttribute (Core.emptyText arg1)


{-| The big text in the middle of a donut or gauge. The default is the total of a
donut and the value of a gauge. A meter writes it as its value text above the
scale.
-}
centerLabel : String -> Attribute msg
centerLabel arg1 =
    fromCoreAttribute (Core.centerLabel arg1)


{-| A small text under the center value of a donut or gauge: "orders". On a gauge
it is also part of the accessible name (which says "Gauge" without it).
-}
centerCaption : String -> Attribute msg
centerCaption arg1 =
    fromCoreAttribute (Core.centerCaption arg1)


{-| The scale of a gauge or meter: its lowest and its highest value. The default
is 0 to 100. If the first number is the larger, the two are swapped.

    Chart.range 0 5000

-}
range : Float -> Float -> Attribute msg
range arg1 arg2 =
    fromCoreAttribute (Core.range arg1 arg2)


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
thresholds arg1 =
    fromCoreAttribute (Core.thresholds arg1)


{-| At most this many category labels on the axis of a line or bar chart. The
rest are left out evenly (every second, third ... label is shown), and the label
of the last category is always there. The default is 12 for a line chart and a
vertical bar chart; a horizontal bar chart names every bar that has a row of at
least 14 pixels. The value is kept between 2 and 60.
-}
maxLabels : Int -> Attribute msg
maxLabels arg1 =
    fromCoreAttribute (Core.maxLabels arg1)


{-| A line chart with one or more series: a trend over categories, usually time.

    Chart.line [ Chart.title "Orders per month", Chart.categories months ]
        [ Chart.series "2025" [ 12, 18, 9, 22 ]
        , Chart.series "2026" [ 14, 20, 15, 25 ]
        ]

The value axis follows the data; add `includeZero` to start it at zero. A
missing value (see `seriesMaybe`) leaves a gap in the line. The legend shows for
two or more series, and each category has a tooltip with its values.

-}
line : List (Attribute msg) -> List Series -> Html msg
line arg1 arg2 =
    Core.line (List.map unwrapAttribute arg1) (List.map unwrapSeries arg2)


{-| Vertical or horizontal bars, grouped or stacked: one group of bars per
category, one bar per series.

    Chart.bar [ Chart.categories months, Chart.stacked ]
        [ Chart.series "Shipped" [ 40, 52, 47 ]
        , Chart.series "Returned" [ 3, 5, 2 ]
        ]

The value axis always includes zero, so a bar is read by its length. A value of 0
draws no bar.

-}
bar : List (Attribute msg) -> List Series -> Html msg
bar arg1 arg2 =
    Core.bar (List.map unwrapAttribute arg1) (List.map unwrapSeries arg2)


{-| Parts of a whole. It is best with up to six slices: when there are more than
eight, the seven largest are kept and the rest are folded into one slice called
"Other".

    Chart.donut [ Chart.centerCaption "orders" ]
        [ Chart.segment "Shipped" 420, Chart.segment "Pending" 310 ]

The total is written in the middle unless `centerLabel` says otherwise, and the
legend lists every slice with its value and its share of the total. The legend is
shown unless you say `hideLegend`. Slices with a value of 0 are left out.

-}
donut : List (Attribute msg) -> List Segment -> Html msg
donut arg1 arg2 =
    Core.donut (List.map unwrapAttribute arg1) (List.map unwrapSegment arg2)


{-| A half-circle gauge for one value against a scale (see `range`; the default
is 0 to 100). The zone the value falls in (see `thresholds`) decides the color.

    Chart.gauge [ Chart.centerCaption "of capacity", Chart.unit "%" ] 82

The value is written in the middle unless `centerLabel` says otherwise. A value
outside the scale fills the arc completely or not at all but is written as it is.
A value that is not a number (NaN, infinity) is a missing measurement: the arc
stays empty, the middle shows a dash and screen readers hear "No value".

-}
gauge : List (Attribute msg) -> Float -> Html msg
gauge arg1 arg2 =
    Core.gauge (List.map unwrapAttribute arg1) arg2


{-| A horizontal meter: the value as a marker on a scale with zones.

    Chart.meter
        [ Chart.range 0 100
        , Chart.title "Warehouse fill"
        , Chart.thresholds [ ( 70, Success ), ( 90, Warning ), ( 100, Danger ) ]
        ]
        84

The title and the value are written above the track, and the two ends of the
scale below it. A meter is flat and as wide as its container, so it fits where
a gauge would take too much room. A value that is not a number is a missing
measurement: the value is a dash, the track has no marker and screen readers hear
"No value".

-}
meter : List (Attribute msg) -> Float -> Html msg
meter arg1 arg2 =
    Core.meter (List.map unwrapAttribute arg1) arg2


{-| A tiny trend line without axes, for a table cell or a tile (see
[Klar.Stat](Klar-Stat)). The last value gets a dot. It needs no categories; give it
an `ariaLabel` that says what it shows, because a sparkline has no title.

    Chart.sparkline
        [ Chart.ariaLabel "Orders, last 7 days", Chart.area, Chart.height 32 ]
        [ 3, 5, 4, 8, 7, 9, 12 ]

Values that are not numbers are left out. With one value there is only the dot,
with none a dash. The default height is 28px and the width fills the container
(see `width`).

-}
sparkline : List (Attribute msg) -> List Float -> Html msg
sparkline arg1 arg2 =
    Core.sparkline (List.map unwrapAttribute arg1) arg2


{-| A line chart from a `Remote`: the skeleton while it loads, the problem with
"Try again" (`onRetry`) when it failed, the empty state, the chart, and the
chart dimmed while it is refreshed or with "Old data from 14:05" when the last
refresh failed. Shape the data with `Remote.map` into a `Data`: the categories
(`byCategory`) or days (`byDate`) and the series together, so they come from the
same response. `categories` and `dates` in the attributes are replaced by those of
the `Data`.

    Chart.lineRemote
        [ Chart.title "Orders per day"
        , Chart.onRetry ReloadOrders
        , Chart.settings model.settings
        ]
        (Remote.map
            (\days -> Chart.byDate (List.map .day days) [ Chart.series "Orders" (List.map .count days) ])
            model.orders
        )

The chart keeps the same elements around it in every state with data, so the
keyboard focus on a category (`onSelect`) survives a refresh. Give it an `id`
to move focus there with `Klar.focus` when "Try again" goes away.

-}
lineRemote : List (Attribute msg) -> Remote Data -> Html msg
lineRemote arg1 arg2 =
    Core.lineRemote (List.map unwrapAttribute arg1) (Remote.map unwrapData arg2)


{-| A bar chart from a `Remote`, with every state of `lineRemote`.

    Chart.barRemote [ Chart.horizontal, Chart.onRetry ReloadWarehouses ]
        (Remote.map
            (\rows -> Chart.byCategory (List.map .name rows) [ Chart.series "Late orders" (List.map .late rows) ])
            model.warehouses
        )

-}
barRemote : List (Attribute msg) -> Remote Data -> Html msg
barRemote arg1 arg2 =
    Core.barRemote (List.map unwrapAttribute arg1) (Remote.map unwrapData arg2)


{-| The data of a line or bar chart from a `Remote` (`lineRemote`, `barRemote`):
its categories and its series in one value, made in the `Remote.map` that shapes
the response, so the labels can never come from another request than the values.
-}
type Data
    = Data { categories : List String, dates : List Date, series : List Types.Series }


{-| Categories named by text, one per value, and the series: what `categories` and
the list of series are to `line` and `bar`.

    Remote.map
        (\rows -> Chart.byCategory (List.map .warehouse rows) [ Chart.series "Orders" (List.map .orders rows) ])
        model.warehouses

-}
byCategory : List String -> List Series -> Data
byCategory arg1 arg2 =
    fromCoreData (Data.byCategory arg1 (List.map unwrapSeries arg2))


{-| Categories that are days, one per value, and the series: what `dates` and the
list of series are to `line` and `bar`. The axis writes the days short and the
tooltips write them whole.

    Remote.map
        (\days -> Chart.byDate (List.map .day days) [ Chart.series "Orders" (List.map .count days) ])
        model.orders

-}
byDate : List Date -> List Series -> Data
byDate arg1 arg2 =
    fromCoreData (Data.byDate arg1 (List.map unwrapSeries arg2))


{-| A donut from a `Remote`, with every state of `lineRemote`.

    Chart.donutRemote [ Chart.centerCaption "orders", Chart.onRetry ReloadStatuses ]
        (Remote.map (List.map (\s -> Chart.segment s.name s.count)) model.statuses)

-}
donutRemote : List (Attribute msg) -> Remote (List Segment) -> Html msg
donutRemote arg1 arg2 =
    Core.donutRemote (List.map unwrapAttribute arg1) (Remote.map (List.map unwrapSegment) arg2)


{-| A gauge from a `Remote`: the skeleton while it loads, the problem with "Try
again" when it failed, and the value (dimmed while it is refreshed, with "Old data
from 14:05" when the last refresh failed).

    Chart.gaugeRemote [ Chart.centerCaption "of capacity", Chart.onRetry Reload ]
        (Remote.map .utilization model.warehouse)

-}
gaugeRemote : List (Attribute msg) -> Remote Float -> Html msg
gaugeRemote arg1 arg2 =
    Core.gaugeRemote (List.map unwrapAttribute arg1) arg2


{-| A meter from a `Remote`, with every state of `gaugeRemote`.

    Chart.meterRemote [ Chart.title "Warehouse fill", Chart.onRetry Reload ]
        (Remote.map .fill model.warehouse)

-}
meterRemote : List (Attribute msg) -> Remote Float -> Html msg
meterRemote arg1 arg2 =
    Core.meterRemote (List.map unwrapAttribute arg1) arg2


{-| A sparkline from a `Remote`: a skeleton line while it loads, a dash with the
problem as its name when it failed (there is no room for "Try again"), and the line,
dimmed while it is refreshed. Old data says so in its name.

    Chart.sparklineRemote [ Chart.ariaLabel "Orders, last 7 days" ]
        (Remote.map .lastWeek model.orders)

-}
sparklineRemote : List (Attribute msg) -> Remote (List Float) -> Html msg
sparklineRemote arg1 arg2 =
    Core.sparklineRemote (List.map unwrapAttribute arg1) arg2


unwrapSeries : Series -> Types.Series
unwrapSeries (Series value) =
    Types.Series value


fromCoreSeries : Types.Series -> Series
fromCoreSeries (Types.Series value) =
    Series value


unwrapSegment : Segment -> Types.Segment
unwrapSegment (Segment value) =
    Types.Segment value


fromCoreSegment : Types.Segment -> Segment
fromCoreSegment (Types.Segment value) =
    Segment value


unwrapAttribute : Attribute msg -> Types.Attribute msg
unwrapAttribute (Attribute value) =
    Types.Attribute value


fromCoreAttribute : Types.Attribute msg -> Attribute msg
fromCoreAttribute (Types.Attribute value) =
    Attribute value


unwrapData : Data -> Types.Data
unwrapData (Data value) =
    Types.Data value


fromCoreData : Types.Data -> Data
fromCoreData (Types.Data value) =
    Data value
