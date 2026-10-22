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

-- Series
type Series  -- opaque: no constructors are exposed
series : String -> List Float -> Series
seriesMaybe : String -> List (Maybe Float) -> Series
withColor : Int -> Series -> Series
withTone : Theme.Tone -> Series -> Series
dashed : Series -> Series

-- Segments
type Segment  -- opaque: no constructors are exposed
segment : String -> Float -> Segment
segmentColor : Int -> Segment -> Segment
segmentTone : Theme.Tone -> Segment -> Segment

-- Attributes
type Attribute msg  -- opaque: no constructors are exposed
title : String -> Attribute msg
description : String -> Attribute msg
ariaLabel : String -> Attribute msg
size : Int -> Attribute msg
height : Int -> Attribute msg
tone : Theme.Tone -> Attribute msg
locale : Locale.Locale -> Attribute msg
unit : String -> Attribute msg
valueFormat : (Float -> String) -> Attribute msg

-- Line and bar charts
categories : List String -> Attribute msg
area : Attribute msg
points : Bool -> Attribute msg
stacked : Attribute msg
horizontal : Attribute msg
valueLabels : Attribute msg
legend : Bool -> Attribute msg
yMin : Float -> Attribute msg
yMax : Float -> Attribute msg
includeZero : Bool -> Attribute msg
maxLabels : Int -> Attribute msg

-- Donut, gauge and meter
centerLabel : String -> Attribute msg
centerCaption : String -> Attribute msg
range : Float -> Float -> Attribute msg
thresholds : List ( Float, Theme.Tone ) -> Attribute msg

-- Loading, failure and empty
loading : Bool -> Attribute msg
failed : Remote.Problem -> Attribute msg
onRetry : msg -> Attribute msg
remote : Remote.Remote a -> Attribute msg
emptyText : String -> Attribute msg
```

## Documentation

Line, bar, donut, gauge, meter and sparkline charts, drawn without any chart
or SVG package.

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
sparkline is an image labelled with a summary of its numbers; give it an
`ariaLabel` that says what it shows. Native tooltips (`title`) show the values
on hover. Tooltips enhance, they never gate.

Series get the colors of an eight-color palette in the order you give them, and
the palette starts over after eight. Use `withColor` to pin a series to a slot,
so that its color does not change when other series come and go. A series that
means good or bad should say so with `withTone`: the status colors are reserved
for that.

Charts show loading, failed and empty states themselves (`loading`, `failed`,
`remote`). The built-in text ("No data to show", the names of the chart kinds
and so on) is English unless you set `locale`. Numbers on the axes and in the
tooltips follow the locale too, or your own `valueFormat`.

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

The value axis follows the data; add `includeZero True` to start it at zero. A
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

The value axis includes zero unless you say `includeZero False`. A value of 0
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
shown unless you say `legend False`. Slices with a value of 0 are left out.

### `gauge`

```elm
gauge : List (Attribute msg) -> Float -> Html msg
```

A half-circle gauge for one value against a scale (see `range`; the default
is 0 to 100). The zone the value falls in (see `thresholds`) decides the color.

    Chart.gauge [ Chart.centerCaption "of capacity", Chart.unit "%" ] 82

The value is written in the middle unless `centerLabel` says otherwise. A value
outside the scale fills the arc completely or not at all but is written as it is,
and a value that is not a number counts as the lowest value of the scale.

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
a gauge would take too much room.

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
(see `size`).

## Series

### `Series`

```elm
type Series  -- opaque: no constructors are exposed
```

A named row of values, one per category: the data of a line or bar chart.
Make one with `series` or `seriesMaybe`, adjust it with `withColor`, `withTone`
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

### `withColor`

```elm
withColor : Int -> Series -> Series
```

Gives the series palette slot 1 to 8 instead of the slot that matches its
position in the list. Use it to keep a color stable when series come and go.

    Chart.series "Returns" [ 2, 3, 1 ] |> Chart.withColor 4

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
`segmentColor` and `segmentTone`, and pass a list of them to `donut`.

### `segment`

```elm
segment : String -> Float -> Segment
```

A slice of a donut, with a label and a value. The size of a slice is its
value relative to the total of all slices.

    Chart.segment "Shipped" 420

Negative and non-numeric values count as 0, and a slice of 0 is left out.

### `segmentColor`

```elm
segmentColor : Int -> Segment -> Segment
```

Gives this slice palette slot 1 to 8 instead of the slot that matches its
position in the list.

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

### `size`

```elm
size : Int -> Attribute msg
```

The width in pixels of a sparkline, donut or gauge, kept between 24 and 1200.
Without it they take what the container gives them (sparkline: 100%, donut:
168px, gauge: 200px). Line charts, bar charts and meters always fill their
container.

### `height`

```elm
height : Int -> Attribute msg
```

The height of the plot in pixels, kept between 16 and 1200. The defaults are
220 for line and bar charts, a height that follows the number of categories for
horizontal bars, and 28 for a sparkline. Donut, gauge and meter have a fixed
size (see `size`).

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

### `area`

```elm
area : Attribute msg
```

Fills the area under the line, for every series of a line chart and for a
sparkline.

### `points`

```elm
points : Bool -> Attribute msg
```

Whether the points of a line chart carry a marker. `True` always shows a
marker on every point; `False` shows it only while the pointer is over a
category. By default markers are always shown for up to 40 categories, and only on
hover beyond that. The markers of a `dashed` series are always on hover only.

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
legend : Bool -> Attribute msg
```

Forces the legend of a line, bar or donut chart on (`True`) or off (`False`).
By default a line or bar chart shows it for two or more series, and a donut
always shows it. Without the legend of a donut the slices are only named in the
tooltips and in the hidden data table, so hide it only when the slices are
labelled in some other way.

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
includeZero : Bool -> Attribute msg
```

Whether the value axis must include zero. The default is `True` for bar
charts and `False` for line charts, where the axis follows the data.

### `maxLabels`

```elm
maxLabels : Int -> Attribute msg
```

At most this many category labels on the axis of a line or bar chart. The
default is 12; the rest are left out evenly (every second, third ... label is
shown). The value is kept between 2 and 60.

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

## Loading, failure and empty

### `loading`

```elm
loading : Bool -> Attribute msg
```

While `True` a skeleton of about the same height replaces the chart, and
screen readers hear "Loading chart" (a sparkline becomes a skeleton line that is
marked as busy). Pass a field of your model. Default: `False`.

### `failed`

```elm
failed : Remote.Problem -> Attribute msg
```

Shows the problem instead of the chart, with a "Try again" button if
`onRetry` is set and the problem is worth retrying. Make a `Problem` with
`Klar.Remote.problem`, or use `remote`. A sparkline is too small for a message:
it shows a dash with the title of the problem as its tooltip.

### `onRetry`

```elm
onRetry : msg -> Attribute msg
```

The message sent by the "Try again" button in the failure state. The button is
only shown when the problem is worth retrying (see `Klar.Remote.isRetryable` in
[Klar.Remote](Klar.Remote.md)); a sparkline has none.

### `remote`

```elm
remote : Remote.Remote a -> Attribute msg
```

Takes loading and failure from a `Remote`. The data itself is passed to the
chart as usual. `NotAsked` and `Loading` show the skeleton, `Failed` shows the
problem and `Loaded` shows the chart.

    Chart.line [ Chart.remote model.sales ] (Remote.withDefault [] model.sales)

Here `model.sales` is a `Remote (List Chart.Series)`.

### `emptyText`

```elm
emptyText : String -> Attribute msg
```

The text of the empty state, shown when there is nothing to draw: no series,
no values, or a donut whose slices add up to 0. The default is "No data to show".
A sparkline uses it as its accessible label. A gauge and a meter always have a
value, so they never show it.
