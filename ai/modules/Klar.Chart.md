# Klar.Chart

Line, bar, donut, gauge, meter and sparkline charts, drawn without any chart or SVG package.

Import: `import Klar.Chart as Chart` | Group: Data display

Types: `Series`, `Segment`, `Attribute`

## Signatures

```elm
-- Charts
line : List (Attribute msg) -> List Series -> Html msg
bar : List (Attribute msg) -> List Series -> Html msg
donut : List (Attribute msg) -> List Segment -> Html msg
gauge : List (Attribute msg) -> Float -> Html msg
meter : List (Attribute msg) -> Float -> Html msg
sparkline : List (Attribute msg) -> List Float -> Html msg

-- Charts from a Remote
lineRemote : List (Attribute msg) -> Remote.Remote (List Series) -> Html msg
barRemote : List (Attribute msg) -> Remote.Remote (List Series) -> Html msg
donutRemote : List (Attribute msg) -> Remote.Remote (List Segment) -> Html msg
gaugeRemote : List (Attribute msg) -> Remote.Remote Float -> Html msg
meterRemote : List (Attribute msg) -> Remote.Remote Float -> Html msg
sparklineRemote : List (Attribute msg) -> Remote.Remote (List Float) -> Html msg

-- Series
type Series  -- opaque: no constructors are exposed
series : String -> List Float -> Series
seriesMaybe : String -> List (Maybe Float) -> Series
withSlot : Int -> Series -> Series
withTone : Theme.Tone -> Series -> Series
dashed : Series -> Series

-- Segments
type Segment  -- opaque: no constructors are exposed
segment : String -> Float -> Segment
segmentSlot : Int -> Segment -> Segment
segmentTone : Theme.Tone -> Segment -> Segment

-- Attributes
type Attribute msg  -- opaque: no constructors are exposed
title : String -> Attribute msg
description : String -> Attribute msg
ariaLabel : String -> Attribute msg
id : String -> Attribute msg
width : Int -> Attribute msg
height : Int -> Attribute msg
tone : Theme.Tone -> Attribute msg
locale : Locale.Locale -> Attribute msg
settings : Settings.Settings -> Attribute msg
unit : String -> Attribute msg
valueFormat : (Float -> String) -> Attribute msg

-- Line and bar charts
categories : List String -> Attribute msg
dates : List Date.Date -> Attribute msg
area : Attribute msg
pointsOnHover : Attribute msg
stacked : Attribute msg
horizontal : Attribute msg
valueLabels : Attribute msg
legend : Attribute msg
hideLegend : Attribute msg
yMin : Float -> Attribute msg
yMax : Float -> Attribute msg
includeZero : Attribute msg
maxLabels : Int -> Attribute msg

-- Selecting a category or segment
onSelect : (Int -> msg) -> Attribute msg

-- Donut, gauge and meter
centerLabel : String -> Attribute msg
centerCaption : String -> Attribute msg
range : Float -> Float -> Attribute msg
thresholds : List ( Float, Theme.Tone ) -> Attribute msg

-- Failure and empty
onRetry : msg -> Attribute msg
emptyText : String -> Attribute msg
```

## Documentation

Line, bar, donut, gauge, meter and sparkline charts, drawn without any chart
or SVG package.

Use when: numbers are shown as a trend, a comparison of categories, parts of a whole or one value against a scale.
Do not use when: the progress of a task is shown, use `Klar.Progress`; or the reader must look up exact values row by row, use `Klar.Table`.
Quick path: `line` or `bar` with `categories` and a list of `series`; data from the backend goes to `lineRemote` (and its sisters) with `onRetry`.

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
    Chart.lineRemote
        [ Chart.title "Revenue"
        , Chart.categories (List.map .month (Remote.withDefault [] model.sales))
        , Chart.onRetry ReloadSales
        ]
        (Remote.map (\sales -> [ Chart.series "Revenue" (List.map .amount sales) ]) model.sales)

Here `months` and `warehouses` are lists of strings with one name per value.

Use `line` for a trend over categories, usually time, `bar` to compare categories
(side by side, or `stacked` to show a total), `donut` for the parts of one whole,
`gauge` and `meter` for one value against a scale, and `sparkline` for a tiny
trend without axes inside a table cell or a [Klar.Stat](Klar.Stat.md) tile. For the
progress of a task use [Klar.Progress](Klar.Progress.md) instead. Every chart takes
a list of attributes first. The charts share their attributes, and an attribute
that a chart has no use for is ignored.

How it is built: bars, markers, gridlines, tick labels and donut slices are
plain HTML elements positioned with percentages, so a chart fills the width of
its container and its text stays 11px at any width. The only SVG is the line
and the area under it: Elm writes a small SVG document (numbers only, with
non-scaling strokes, so a line is 2px at any stretch) as a data URI and the
element uses it as a CSS mask, exactly like the icons in [Klar.Icon](Klar.Icon.md).
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
Shape the data with `Remote.map`. The built-in text ("No data to show", the names
of the chart kinds and so on) is English unless you set `locale`. Numbers on the
axes and in the tooltips follow the locale too, or your own `valueFormat`.

## Charts

### `line`

```elm
line : List (Attribute msg) -> List Series -> Html msg
```

A line chart with one or more series: a trend over categories, usually time.

    Chart.line [ Chart.title "Orders per month", Chart.categories months ]
        [ Chart.series "2025" [ 12, 18, 9, 22 ]
        , Chart.series "2026" [ 14, 20, 15, 25 ]
        ]

The value axis follows the data; add `includeZero` to start it at zero. A
missing value (see `seriesMaybe`) leaves a gap in the line. The legend shows for
two or more series, and each category has a tooltip with its values.

### `bar`

```elm
bar : List (Attribute msg) -> List Series -> Html msg
```

Vertical or horizontal bars, grouped or stacked: one group of bars per
category, one bar per series.

    Chart.bar [ Chart.categories months, Chart.stacked ]
        [ Chart.series "Shipped" [ 40, 52, 47 ]
        , Chart.series "Returned" [ 3, 5, 2 ]
        ]

The value axis always includes zero, so a bar is read by its length. A value of 0
draws no bar.

### `donut`

```elm
donut : List (Attribute msg) -> List Segment -> Html msg
```

Parts of a whole. It is best with up to six slices: when there are more than
eight, the seven largest are kept and the rest are folded into one slice called
"Other".

    Chart.donut [ Chart.centerCaption "orders" ]
        [ Chart.segment "Shipped" 420, Chart.segment "Pending" 310 ]

The total is written in the middle unless `centerLabel` says otherwise, and the
legend lists every slice with its value and its share of the total. The legend is
shown unless you say `hideLegend`. Slices with a value of 0 are left out.

### `gauge`

```elm
gauge : List (Attribute msg) -> Float -> Html msg
```

A half-circle gauge for one value against a scale (see `range`; the default
is 0 to 100). The zone the value falls in (see `thresholds`) decides the color.

    Chart.gauge [ Chart.centerCaption "of capacity", Chart.unit "%" ] 82

The value is written in the middle unless `centerLabel` says otherwise. A value
outside the scale fills the arc completely or not at all but is written as it is.
A value that is not a number (NaN, infinity) is a missing measurement: the arc
stays empty, the middle shows a dash and screen readers hear "No value".

### `meter`

```elm
meter : List (Attribute msg) -> Float -> Html msg
```

A horizontal meter: the value as a marker on a scale with zones.

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

### `sparkline`

```elm
sparkline : List (Attribute msg) -> List Float -> Html msg
```

A tiny trend line without axes, for a table cell or a tile (see
[Klar.Stat](Klar.Stat.md)). The last value gets a dot. It needs no categories; give it
an `ariaLabel` that says what it shows, because a sparkline has no title.

    Chart.sparkline
        [ Chart.ariaLabel "Orders, last 7 days", Chart.area, Chart.height 32 ]
        [ 3, 5, 4, 8, 7, 9, 12 ]

Values that are not numbers are left out. With one value there is only the dot,
with none a dash. The default height is 28px and the width fills the container
(see `width`).

## Charts from a Remote

### `lineRemote`

```elm
lineRemote : List (Attribute msg) -> Remote.Remote (List Series) -> Html msg
```

A line chart from a `Remote`: the skeleton while it loads, the problem with
"Try again" (`onRetry`) when it failed, the empty state, the chart, and the
chart dimmed while it is refreshed or with "Old data from 14:05" when the last
refresh failed. Shape the data with `Remote.map`; the categories come from the
same `Remote`.

    Chart.lineRemote
        [ Chart.title "Orders per day"
        , Chart.dates (List.map .day (Remote.withDefault [] model.orders))
        , Chart.onRetry ReloadOrders
        , Chart.settings model.settings
        ]
        (Remote.map (\days -> [ Chart.series "Orders" (List.map .count days) ]) model.orders)

The chart keeps the same elements around it in every state with data, so the
keyboard focus on a category (`onSelect`) survives a refresh. Give it an `id`
to move focus there with `Klar.focus` when "Try again" goes away.

### `barRemote`

```elm
barRemote : List (Attribute msg) -> Remote.Remote (List Series) -> Html msg
```

A bar chart from a `Remote`, with every state of `lineRemote`.

    Chart.barRemote
        [ Chart.categories (List.map .name (Remote.withDefault [] model.warehouses))
        , Chart.horizontal
        , Chart.onRetry ReloadWarehouses
        ]
        (Remote.map (\rows -> [ Chart.series "Late orders" (List.map .late rows) ]) model.warehouses)

### `donutRemote`

```elm
donutRemote : List (Attribute msg) -> Remote.Remote (List Segment) -> Html msg
```

A donut from a `Remote`, with every state of `lineRemote`.

    Chart.donutRemote [ Chart.centerCaption "orders", Chart.onRetry ReloadStatuses ]
        (Remote.map (List.map (\s -> Chart.segment s.name s.count)) model.statuses)

### `gaugeRemote`

```elm
gaugeRemote : List (Attribute msg) -> Remote.Remote Float -> Html msg
```

A gauge from a `Remote`: the skeleton while it loads, the problem with "Try
again" when it failed, and the value (dimmed while it is refreshed, with "Old data
from 14:05" when the last refresh failed).

    Chart.gaugeRemote [ Chart.centerCaption "of capacity", Chart.onRetry Reload ]
        (Remote.map .utilization model.warehouse)

### `meterRemote`

```elm
meterRemote : List (Attribute msg) -> Remote.Remote Float -> Html msg
```

A meter from a `Remote`, with every state of `gaugeRemote`.

    Chart.meterRemote [ Chart.title "Warehouse fill", Chart.onRetry Reload ]
        (Remote.map .fill model.warehouse)

### `sparklineRemote`

```elm
sparklineRemote : List (Attribute msg) -> Remote.Remote (List Float) -> Html msg
```

A sparkline from a `Remote`: a skeleton line while it loads, a dash with the
problem as its name when it failed (there is no room for "Try again"), and the line,
dimmed while it is refreshed. Old data says so in its name.

    Chart.sparklineRemote [ Chart.ariaLabel "Orders, last 7 days" ]
        (Remote.map .lastWeek model.orders)

## Series

### `Series`

```elm
type Series  -- opaque: no constructors are exposed
```

A named row of values, one per category: the data of a line or bar chart.
Make one with `series` or `seriesMaybe`, adjust it with `withSlot`, `withTone`
and `dashed`, and pass a list of them to `line` or `bar`.

### `series`

```elm
series : String -> List Float -> Series
```

A series with a name and its values, in the order of the categories. The
name is shown in the legend, in the tooltips and in the data table.

    Chart.series "2026" [ 14, 20, 15, 25 ]

Values that are not numbers (NaN, infinity) become gaps in the line; use
`seriesMaybe` to leave gaps on purpose.

### `seriesMaybe`

```elm
seriesMaybe : String -> List (Maybe Float) -> Series
```

Like `series`, with explicit gaps for missing measurements: a `Nothing`
breaks the line (or leaves out the bar), and the data table shows a dash.

    Chart.seriesMaybe "Temperature" [ Just 4, Just 6, Nothing, Just 9 ]

### `withSlot`

```elm
withSlot : Int -> Series -> Series
```

Gives the series palette slot 1 to 8 instead of the slot that matches its
position in the list. A slot is a place in the chart palette of the theme, not a
[Klar.Color](Klar.Color.md): a chart has no colors of your own, so it keeps its contrast. Use it to keep a color stable when series come and go.

    Chart.series "Returns" [ 2, 3, 1 ] |> Chart.withSlot 4

### `withTone`

```elm
withTone : Theme.Tone -> Series -> Series
```

Colors the series by meaning (`Success`, `Warning`, `Danger` ...) instead of
by position. Reserve this for series that really are good or bad, such as "On
time" and "Late". The `Tone` type is in [Klar.Theme](Klar.Theme.md).

### `dashed`

```elm
dashed : Series -> Series
```

Draws the series as a dashed line: for forecasts, targets, last year. It is
meant for line charts, where a dashed series also shows its markers only while
the pointer is over a category.

## Segments

### `Segment`

```elm
type Segment  -- opaque: no constructors are exposed
```

One slice of a donut. Make one with `segment`, adjust it with
`segmentSlot` and `segmentTone`, and pass a list of them to `donut`.

### `segment`

```elm
segment : String -> Float -> Segment
```

A slice of a donut, with a label and a value. The size of a slice is its
value relative to the total of all slices.

    Chart.segment "Shipped" 420

Negative and non-numeric values count as 0, and a slice of 0 is left out.

### `segmentSlot`

```elm
segmentSlot : Int -> Segment -> Segment
```

Gives this slice palette slot 1 to 8 instead of the slot that matches its
position in the list (see `withSlot`).

### `segmentTone`

```elm
segmentTone : Theme.Tone -> Segment -> Segment
```

Colors this slice by meaning (`Success`, `Warning`, `Danger` ...) instead of
by position. Reserve it for slices that really are good or bad.

## Attributes

### `Attribute`

```elm
type Attribute msg  -- opaque: no constructors are exposed
```

A setting of a chart. Make them with the functions below and pass a list to a
chart function (`line`, `bar` and so on); later attributes win over earlier ones.

### `title`

```elm
title : String -> Attribute msg
```

A visible heading above the chart. It is also the accessible name of the
chart (and the caption of its hidden data table), unless `ariaLabel` is set. A
meter shows it at the left above the scale. A sparkline has no room for a
heading: give it an `ariaLabel` instead.

### `description`

```elm
description : String -> Attribute msg
```

A line of explanation under the title, for example the period or the source
of the numbers. A meter and a sparkline do not show it.

### `ariaLabel`

```elm
ariaLabel : String -> Attribute msg
```

The accessible name of the chart, for screen readers. Use it when there is no
visible `title`; when both are set, the `ariaLabel` is the accessible name (and
the caption of the hidden data table) and the title is only shown. A sparkline
has no title, so give it an `ariaLabel` that says what it shows: "Orders, last 7
days".

### `id`

```elm
id : String -> Attribute msg
```

The DOM id of the chart, which then sits in an element that can take focus
in every state (loading, failed, old data, drawn). The "Try again" button is
replaced when the request starts again and focus would fall back to the page: call
[`Klar.focus`](Klar.md#focus) with this id in the same `update`
branch. The id must be unique on the page.

### `width`

```elm
width : Int -> Attribute msg
```

The width in pixels of a sparkline, donut or gauge, kept between 24 and 1200.
Without it they take what the container gives them (sparkline: 100%, donut:
168px, gauge: 200px), and never more than the container. Line charts, bar charts
and meters always fill their container.

### `height`

```elm
height : Int -> Attribute msg
```

The height of the plot in pixels, kept between 16 and 1200. The defaults are
220 for line and bar charts, a height that follows the number of categories for
horizontal bars, and 28 for a sparkline. Donut, gauge and meter have a fixed
shape (see `width`).

### `tone`

```elm
tone : Theme.Tone -> Attribute msg
```

Colors the chart by meaning instead of by palette: the first series of a line
or bar chart (the other series keep their palette colors), a sparkline, and a
gauge or meter that has no `thresholds`. The default is `Primary` (blue).

### `locale`

```elm
locale : Locale.Locale -> Attribute msg
```

The language of the built-in text ("No data to show", "Line chart",
"Loading chart" and so on) and of the number format. The default is
`Locale.default`, which is English. See [Klar.Locale](Klar.Locale.md).

### `settings`

```elm
settings : Settings.Settings -> Attribute msg
```

The settings of the application (`Klar.Settings`): the time zone of the time in
"Old data from 14:05". Without it the time is written in UTC and ends in "UTC".

    Chart.settings model.settings

### `unit`

```elm
unit : String -> Attribute msg
```

A unit written after the value, separated by a non-breaking space: "USD".
It is added in the tooltips, the data table, the legend of a donut and the value
text of a gauge or meter, but not on the axis. It is ignored when `valueFormat`
is set.

### `valueFormat`

```elm
valueFormat : (Float -> String) -> Attribute msg
```

How a value is written on the axis, in the tooltips, the value labels and the
data table, and in the text of a donut, gauge or meter. Use it for currencies,
percentages and other units. When it is set, `unit` is not added.

    Chart.valueFormat (\amount -> "$" ++ String.fromFloat amount)

The default writes numbers with the separators of the `locale`, with as many
decimals as the number needs, and shortens large axis values ("2.5M").

## Line and bar charts

### `categories`

```elm
categories : List String -> Attribute msg
```

The names of the categories of a line or bar chart, one per value, in the
order of the values. They label the x axis (the left side of a horizontal bar
chart). A missing name is replaced by its position (1, 2, 3 ...), and names
beyond the longest series add empty categories.

    Chart.categories [ "Jan", "Feb", "Mar", "Apr" ]

### `dates`

```elm
dates : List Date.Date -> Attribute msg
```

The categories of a line or bar chart when they are days, one per value, in
the order of the values. The axis writes them as short as a label can be (`21 Sep`
in English, `21. sep.` in Norwegian, see `Format.dateShort`), so that eight of them
fit under a half page chart, and the tooltip and the text alternative write the
whole date. `categories` and `dates` replace each other.

    Chart.line [ Chart.dates (List.map .day model.sales) ]

### `area`

```elm
area : Attribute msg
```

Fills the area under the line, for every series of a line chart and for a
sparkline. A filled area reads as an amount counted from zero, so the value axis
of a line chart with `area` includes zero.

### `pointsOnHover`

```elm
pointsOnHover : Attribute msg
```

Shows the markers of a line chart only while the pointer (or the keyboard
focus, see `onSelect`) is on a category, for a calm line through many points. By
default every point has a marker for up to 40 categories, and beyond that markers
are shown on hover only. The markers of a `dashed` series are always on hover only.

### `stacked`

```elm
stacked : Attribute msg
```

Stacks the series of a bar chart on top of each other instead of side by side.
Positive values stack upward from zero and negative values downward. The tooltip
and the data table get the total of each category.

### `horizontal`

```elm
horizontal : Attribute msg
```

Horizontal bars: good for long category names and many categories. The
height of the chart follows the number of categories, unless you set `height`.

### `valueLabels`

```elm
valueLabels : Attribute msg
```

Prints the value at the end of each bar (the total, for stacked bars). It is
only shown when there is room: up to 24 bars in a vertical chart and up to 60 in
a horizontal one.

### `legend`

```elm
legend : Attribute msg
```

Shows the legend of a line or bar chart even for a single series. By default a
line or bar chart shows it for two or more series, and a donut always shows it.
`legend` and `hideLegend` replace each other.

### `hideLegend`

```elm
hideLegend : Attribute msg
```

Leaves out the legend of a line, bar or donut chart, for a chart whose series
or slices are named in some other way (a title that says it, a table next to it).
Without the legend of a donut the slices are only named in the tooltips and in
the hidden data table, and a donut with `onSelect` has no keyboard path to its
slices: keep the legend there.

### `yMin`

```elm
yMin : Float -> Attribute msg
```

Fixes the lower end of the value axis (the horizontal axis of a horizontal bar
chart). Values below it are cut off at the edge of the plot. A limit that cannot
make an axis, such as a minimum above the maximum, is ignored and the axis
follows the data.

### `yMax`

```elm
yMax : Float -> Attribute msg
```

Fixes the upper end of the value axis (the horizontal axis of a horizontal bar
chart). Values above it are cut off at the edge of the plot. A limit that cannot
make an axis is ignored and the axis follows the data.

### `includeZero`

```elm
includeZero : Attribute msg
```

Starts the value axis of a line chart at zero (or ends it there, for values
below zero). By default the axis of a line chart follows the data, unless the chart
has an `area`. The axis of a bar chart always includes zero: a bar is read by its
length.

### `maxLabels`

```elm
maxLabels : Int -> Attribute msg
```

At most this many category labels on the axis of a line or bar chart. The
rest are left out evenly (every second, third ... label is shown), and the label
of the last category is always there. The default is 12 for a line chart and a
vertical bar chart; a horizontal bar chart names every bar that has a row of at
least 14 pixels. The value is kept between 2 and 60.

## Selecting a category or segment

### `onSelect`

```elm
onSelect : (Int -> msg) -> Attribute msg
```

Makes every category of a line or bar chart, and every slice of a donut, a
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

## Donut, gauge and meter

### `centerLabel`

```elm
centerLabel : String -> Attribute msg
```

The big text in the middle of a donut or gauge. The default is the total of a
donut and the value of a gauge. A meter writes it as its value text above the
scale.

### `centerCaption`

```elm
centerCaption : String -> Attribute msg
```

A small text under the center value of a donut or gauge: "orders". On a gauge
it is also part of the accessible name (which says "Gauge" without it).

### `range`

```elm
range : Float -> Float -> Attribute msg
```

The scale of a gauge or meter: its lowest and its highest value. The default
is 0 to 100. If the first number is the larger, the two are swapped.

    Chart.range 0 5000

### `thresholds`

```elm
thresholds : List ( Float, Theme.Tone ) -> Attribute msg
```

Zones of a gauge or meter: the upper limit of each zone and its meaning. The
zone the value falls in colors the gauge and the value of the meter. A meter also
draws every zone on its track, and a gauge a tick at each limit.

    Chart.thresholds [ ( 70, Success ), ( 90, Warning ), ( 100, Danger ) ]

Here values up to 70 are good, up to 90 a warning, and up to 100 dangerous. Let the
last limit be the top of the `range`: a value beyond it takes the color of the last
zone, but a meter leaves the part of its track after the last limit uncolored. The
zones are sorted by limit. Without thresholds the whole scale has the `tone` of the
chart.

## Failure and empty

### `onRetry`

```elm
onRetry : msg -> Attribute msg
```

The message sent by the "Try again" button of a chart from a `Remote`
(`lineRemote` and its sisters) that failed, and by the marker of old data. The
button is only shown when the problem is worth retrying (see
`Klar.Remote.isRetryable` in [Klar.Remote](Klar.Remote.md)); a sparkline is too small
for a message and has none.

### `emptyText`

```elm
emptyText : String -> Attribute msg
```

The text of the empty state, shown when there is nothing to draw: no series,
no values, or a donut whose slices add up to 0. The default is "No data to show".
A sparkline uses it as its accessible label. A gauge and a meter always have a
value, so they never show it.
