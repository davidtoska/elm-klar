module Klar.Chart exposing
    ( line, bar, donut, gauge, meter, sparkline
    , Series, series, seriesMaybe, withColor, withTone, dashed
    , Segment, segment, segmentColor, segmentTone
    , Attribute, title, description, ariaLabel, size, height, tone, locale, settings, unit, valueFormat
    , categories, dates, area, points, stacked, horizontal, valueLabels, legend, yMin, yMax, includeZero, maxLabels
    , centerLabel, centerCaption, range, thresholds
    , loading, failed, onRetry, remote, emptyText
    , id
    )

{-| Line, bar, donut, gauge, meter and sparkline charts, drawn without any chart
or SVG package.

Use when: numbers are shown as a trend, a comparison of categories, parts of a whole or one value against a scale.
Do not use when: the progress of a task is shown, use `Klar.Progress`.

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


# Charts

@docs line, bar, donut, gauge, meter, sparkline


# Series

@docs Series, series, seriesMaybe, withColor, withTone, dashed


# Segments

@docs Segment, segment, segmentColor, segmentTone


# Attributes

@docs Attribute, title, description, ariaLabel, size, height, tone, locale, settings, unit, valueFormat


# Line and bar charts

@docs categories, dates, area, points, stacked, horizontal, valueLabels, legend, yMin, yMax, includeZero, maxLabels


# Donut, gauge and meter

@docs centerLabel, centerCaption, range, thresholds


# Loading, failure and empty

@docs loading, failed, onRetry, remote, emptyText

-}

import Array exposing (Array)
import Html exposing (Html)
import Html.Attributes as Attr
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



-- DATA


{-| A named row of values, one per category: the data of a line or bar chart.
Make one with `series` or `seriesMaybe`, adjust it with `withColor`, `withTone`
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
`segmentColor` and `segmentTone`, and pass a list of them to `donut`.
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
series name values =
    Series { name = name, values = List.map sanitize values, color = Nothing, tone = Nothing, dashed = False }


{-| Like `series`, with explicit gaps for missing measurements: a `Nothing`
breaks the line (or leaves out the bar), and the data table shows a dash.

    Chart.seriesMaybe "Temperature" [ Just 4, Just 6, Nothing, Just 9 ]

-}
seriesMaybe : String -> List (Maybe Float) -> Series
seriesMaybe name values =
    Series { name = name, values = List.map (Maybe.andThen sanitize) values, color = Nothing, tone = Nothing, dashed = False }


{-| Gives the series palette slot 1 to 8 instead of the slot that matches its
position in the list. Use it to keep a color stable when series come and go.

    Chart.series "Returns" [ 2, 3, 1 ] |> Chart.withColor 4

-}
withColor : Int -> Series -> Series
withColor slot (Series s) =
    Series { s | color = Just slot }


{-| Colors the series by meaning (`Success`, `Warning`, `Danger` ...) instead of
by position. Reserve this for series that really are good or bad, such as "On
time" and "Late". The `Tone` type is in [Klar.Theme](Klar-Theme).
-}
withTone : Tone -> Series -> Series
withTone value (Series s) =
    Series { s | tone = Just value }


{-| Draws the series as a dashed line: for forecasts, targets, last year. It is
meant for line charts, where a dashed series also shows its markers only while
the pointer is over a category.
-}
dashed : Series -> Series
dashed (Series s) =
    Series { s | dashed = True }


{-| A slice of a donut, with a label and a value. The size of a slice is its
value relative to the total of all slices.

    Chart.segment "Shipped" 420

Negative and non-numeric values count as 0, and a slice of 0 is left out.

-}
segment : String -> Float -> Segment
segment label value =
    Segment { label = label, value = Maybe.withDefault 0 (sanitize value) |> max 0, color = Nothing, tone = Nothing }


{-| Gives this slice palette slot 1 to 8 instead of the slot that matches its
position in the list.
-}
segmentColor : Int -> Segment -> Segment
segmentColor slot (Segment s) =
    Segment { s | color = Just slot }


{-| Colors this slice by meaning (`Success`, `Warning`, `Danger` ...) instead of
by position. Reserve it for slices that really are good or bad.
-}
segmentTone : Tone -> Segment -> Segment
segmentTone value (Segment s) =
    Segment { s | tone = Just value }


sanitize : Float -> Maybe Float
sanitize value =
    if isNaN value || isInfinite value then
        Nothing

    else
        Just (clamp -1.0e15 1.0e15 value)



-- ATTRIBUTES


{-| A setting of a chart. Make them with the functions below and pass a list to a
chart function (`line`, `bar` and so on); later attributes win over earlier ones.
-}
type Attribute msg
    = Attribute (Config msg -> Config msg)


type State
    = Ready
    | Busy
    | Failed Problem


type alias Config msg =
    { title : Maybe String
    , description : Maybe String
    , ariaLabel : Maybe String
    , categories : List String
    , dates : List Date
    , height : Maybe Int
    , size : Maybe Int
    , area : Bool
    , points : Maybe Bool
    , stacked : Bool
    , horizontal : Bool
    , valueLabels : Bool
    , legend : Maybe Bool
    , yMin : Maybe Float
    , yMax : Maybe Float
    , includeZero : Maybe Bool
    , valueFormat : Maybe (Float -> String)
    , unit : String
    , locale : Locale
    , settings : Settings
    , tone : Maybe Tone
    , busy : Bool
    , failure : Maybe Problem
    , freshness : Freshness
    , onRetry : Maybe msg
    , id : Maybe String
    , emptyText : Maybe String
    , centerLabel : Maybe String
    , centerCaption : Maybe String
    , thresholds : List ( Float, Tone )
    , rangeMin : Float
    , rangeMax : Float
    , maxLabels : Int
    }


configure : List (Attribute msg) -> Config msg
configure attributes =
    List.foldl (\(Attribute change) config -> change config)
        { title = Nothing
        , description = Nothing
        , ariaLabel = Nothing
        , categories = []
        , dates = []
        , height = Nothing
        , size = Nothing
        , area = False
        , points = Nothing
        , stacked = False
        , horizontal = False
        , valueLabels = False
        , legend = Nothing
        , yMin = Nothing
        , yMax = Nothing
        , includeZero = Nothing
        , valueFormat = Nothing
        , unit = ""
        , locale = Locale.default
        , settings = Settings.default
        , tone = Nothing
        , busy = False
        , failure = Nothing
        , freshness = Freshness.Fresh
        , onRetry = Nothing
        , id = Nothing
        , emptyText = Nothing
        , centerLabel = Nothing
        , centerCaption = Nothing
        , thresholds = []
        , rangeMin = 0
        , rangeMax = 100
        , maxLabels = 12
        }
        attributes


{-| The DOM id of the chart, which then sits in an element that can take focus
in every state (loading, failed, old data, drawn). The "Try again" button is
replaced when the request starts again and focus would fall back to the page: call
[`RemoteView.focus`](Klar-RemoteView#focus) with this id in the same `update`
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
size (see `size`).
-}
height : Int -> Attribute msg
height pixels =
    Attribute (\config -> { config | height = Just (clamp 16 1200 pixels) })


{-| The width in pixels of a sparkline, donut or gauge, kept between 24 and 1200.
Without it they take what the container gives them (sparkline: 100%, donut:
168px, gauge: 200px). Line charts, bar charts and meters always fill their
container.
-}
size : Int -> Attribute msg
size pixels =
    Attribute (\config -> { config | size = Just (clamp 24 1200 pixels) })


{-| Fills the area under the line, for every series of a line chart and for a
sparkline.
-}
area : Attribute msg
area =
    Attribute (\config -> { config | area = True })


{-| Whether the points of a line chart carry a marker. `True` always shows a
marker on every point; `False` shows it only while the pointer is over a
category. By default markers are always shown for up to 40 categories, and only on
hover beyond that. The markers of a `dashed` series are always on hover only.
-}
points : Bool -> Attribute msg
points value =
    Attribute (\config -> { config | points = Just value })


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


{-| Forces the legend of a line, bar or donut chart on (`True`) or off (`False`).
By default a line or bar chart shows it for two or more series, and a donut
always shows it. Without the legend of a donut the slices are only named in the
tooltips and in the hidden data table, so hide it only when the slices are
labelled in some other way.
-}
legend : Bool -> Attribute msg
legend value =
    Attribute (\config -> { config | legend = Just value })


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


{-| Whether the value axis must include zero. The default is `True` for bar
charts and `False` for line charts, where the axis follows the data.
-}
includeZero : Bool -> Attribute msg
includeZero value =
    Attribute (\config -> { config | includeZero = Just value })


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


{-| Shows a skeleton of about the same height in place of the chart while `True`,
and screen readers hear "Loading chart" (a sparkline becomes a skeleton line that
is marked as busy). Pass a field of your model. Default: `False`.

`loading`, `failed` and `remote` only add up: a chart is busy when any of them
says so, and shows a failure when any of them has one, whatever the order. So
`Chart.remote model.sales` followed by `Chart.loading False` keeps the loading
and the failure that `remote` set.

-}
loading : Bool -> Attribute msg
loading value =
    Attribute (\config -> { config | busy = config.busy || value })


{-| Shows the problem instead of the chart, with a "Try again" button if
`onRetry` is set and the problem is worth retrying. Make a `Problem` with
`Klar.Remote.problem`, or use `remote`. A sparkline is too small for a message:
it shows a dash with the title of the problem as its tooltip.
-}
failed : Problem -> Attribute msg
failed problem =
    Attribute (\config -> { config | failure = Just problem })


{-| The message sent by the "Try again" button in the failure state and in the
marker of old data. The button is only shown when the problem is worth retrying
(see `Klar.Remote.isRetryable` in [Klar.Remote](Klar-Remote)); a sparkline has
none.
-}
onRetry : msg -> Attribute msg
onRetry msg =
    Attribute (\config -> { config | onRetry = Just msg })


{-| Takes loading, failure, refreshing and old data from a `Remote`. The data
itself is passed to the chart as usual. `NotAsked` and `Loading` show the
skeleton, `Failed` shows the problem and `Loaded` shows the chart. Data that is
`Kept` stays on the screen: dimmed and busy while it is refreshed, and with the
marker "Old data from 14:05" and a retry when the last refresh failed.

    Chart.line [ Chart.remote model.sales ] (Remote.withDefault [] model.sales)

Here `model.sales` is a `Remote (List Chart.Series)`.

-}
remote : Remote a -> Attribute msg
remote data =
    Attribute
        (\config ->
            let
                ( settled, freshness ) =
                    Freshness.settle data
            in
            { config
                | busy = config.busy || Freshness.waiting settled
                , failure =
                    case settled of
                        Remote.Failed problem ->
                            Just problem

                        _ ->
                            config.failure
                , freshness = freshness
            }
        )


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
default is 12; the rest are left out evenly (every second, third ... label is
shown). The value is kept between 2 and 60.
-}
maxLabels : Int -> Attribute msg
maxLabels n =
    Attribute (\config -> { config | maxLabels = clamp 2 60 n })



-- TEXT


type alias Texts =
    { noData : String
    , loading : String
    , line : String
    , bar : String
    , donut : String
    , gauge : String
    , meter : String
    , sparkline : String
    , category : String
    , value : String
    , share : String
    , total : String
    , other : String
    , tableTruncated : Int -> String
    , seriesCount : Int -> String
    , pointCount : Int -> String
    , segmentCount : Int -> String
    , of_ : String
    }


texts : Locale -> Texts
texts loc =
    let
        pick nb en =
            Locale.pick loc { nb = nb, en = en }

        plural n one other =
            Format.plural loc n { one = one, other = other }
    in
    { noData = pick "Ingen data å vise" "No data to show"
    , loading = pick "Laster diagram" "Loading chart"
    , line = pick "Linjediagram" "Line chart"
    , bar = pick "Stolpediagram" "Bar chart"
    , donut = pick "Smultringdiagram" "Donut chart"
    , gauge = pick "Måler" "Gauge"
    , meter = pick "Måler" "Meter"
    , sparkline = pick "Trend" "Trend"
    , category = pick "Kategori" "Category"
    , value = pick "Verdi" "Value"
    , share = pick "Andel" "Share"
    , total = pick "Totalt" "Total"
    , other = pick "Andre" "Other"
    , tableTruncated = \n -> pick ("... og " ++ Format.int loc n ++ " rader til") ("... and " ++ Format.int loc n ++ " more rows")
    , seriesCount = \n -> Format.int loc n ++ " " ++ plural n (pick "serie" "series") (pick "serier" "series")
    , pointCount = \n -> Format.int loc n ++ " " ++ plural n (pick "punkt" "point") (pick "punkter" "points")
    , segmentCount = \n -> Format.int loc n ++ " " ++ plural n (pick "del" "segment") (pick "deler" "segments")
    , of_ = pick "av" "of"
    }



-- STATES AND SHELL


stateOf : Config msg -> State
stateOf config =
    case config.failure of
        Just problem ->
            Failed problem

        Nothing ->
            if config.busy then
                Busy

            else
                Ready


withState : Config msg -> String -> Int -> Bool -> (() -> Html msg) -> Html msg
withState config kind placeholderHeight hasData body =
    case config.id of
        Just domId ->
            Html.div [ Attr.id domId, Attr.tabindex -1 ] [ withStateInside config kind placeholderHeight hasData body ]

        Nothing ->
            withStateInside config kind placeholderHeight hasData body


withStateInside : Config msg -> String -> Int -> Bool -> (() -> Html msg) -> Html msg
withStateInside config kind placeholderHeight hasData body =
    let
        t =
            texts config.locale
    in
    case stateOf config of
        Busy ->
            shell config
                kind
                [ ( "aria-busy", "true" ) ]
                [ header config
                , Html.span [ Internal.cls [ "klar-sr-only" ], Attr.attribute "role" "status" ] [ Html.text t.loading ]
                , Skeleton.block placeholderHeight
                ]

        Failed problem ->
            shell config
                kind
                []
                [ header config
                , ErrorState.view
                    (List.filterMap identity
                        [ Just ErrorState.compact
                        , Just (ErrorState.locale config.locale)
                        , Maybe.map ErrorState.onRetry config.onRetry
                        ]
                    )
                    problem
                ]

        Ready ->
            if hasData then
                case config.freshness of
                    Freshness.Fresh ->
                        body ()

                    _ ->
                        Html.div
                            [ Internal.cls [ "klar-chart-fresh", Freshness.className config.freshness ]
                            , Freshness.busyAttr config.freshness
                            ]
                            [ Freshness.notice
                                { locale = config.locale, settings = config.settings, onRetry = config.onRetry, inline = False }
                                config.freshness
                            , body ()
                            ]

            else
                shell config
                    kind
                    []
                    [ header config
                    , EmptyState.view
                        [ EmptyState.compact
                        , EmptyState.icon Icon.barChart
                        , EmptyState.title (Maybe.withDefault t.noData config.emptyText)
                        ]
                    ]


shell : Config msg -> String -> List ( String, String ) -> List (Html msg) -> Html msg
shell config kind extra children =
    Html.figure
        ([ Internal.cls [ "klar-chart", "klar-chart--" ++ kind ]
         , case config.size of
            Just pixels ->
                Internal.styleVars [ ( "--klar-chart-w", Internal.px pixels ) ]

            Nothing ->
                Internal.noAttr
         ]
            ++ List.map (\( k, v ) -> Attr.attribute k v) extra
        )
        children


header : Config msg -> Html msg
header config =
    case ( config.title, config.description ) of
        ( Nothing, Nothing ) ->
            Html.text ""

        _ ->
            Html.figcaption [ Internal.cls [ "klar-chart__caption" ] ]
                [ Internal.viewMaybe (\text -> Html.span [ Internal.cls [ "klar-chart__title" ] ] [ Html.text text ]) config.title
                , Internal.viewMaybe (\text -> Html.span [ Internal.cls [ "klar-chart__description" ] ] [ Html.text text ]) config.description
                ]



-- SERIES PREPARATION


type alias PSeries =
    { name : String
    , values : Array (Maybe Float)
    , cls : String
    , dashed : Bool
    }


type alias Prepared =
    { n : Int
    , cats : Array String
    , short : Array String
    , series : List PSeries
    }


prepare : Config msg -> List Series -> Prepared
prepare config list =
    let
        longest =
            list
                |> List.map (\(Series s) -> List.length s.values)
                |> List.maximum
                |> Maybe.withDefault 0

        n =
            max (max (List.length config.categories) (List.length config.dates)) longest

        catArray =
            if List.isEmpty config.dates then
                Array.fromList config.categories

            else
                Array.fromList (List.map (Format.date config.locale) config.dates)

        shortArray =
            if List.isEmpty config.dates then
                catArray

            else
                Array.fromList (List.map (Format.dateShort config.locale) config.dates)

        labelAtIn array i =
            Array.get i array |> Maybe.withDefault (String.fromInt (i + 1))

        labelAt =
            labelAtIn catArray

        build index (Series s) =
            { name = s.name
            , values = Array.fromList s.values
            , cls = colorClass config.tone index s.color s.tone
            , dashed = s.dashed
            }
    in
    { n = n
    , cats = Array.fromList (List.map labelAt (List.range 0 (n - 1)))
    , short = Array.fromList (List.map (labelAtIn shortArray) (List.range 0 (n - 1)))
    , series = List.indexedMap build list
    }


colorClass : Maybe Tone -> Int -> Maybe Int -> Maybe Tone -> String
colorClass chartTone index slot seriesTone =
    case ( seriesTone, slot, chartTone ) of
        ( Just t, _, _ ) ->
            toneClass t

        ( Nothing, Just s, _ ) ->
            "klar-chart-s" ++ String.fromInt (modBy 8 (s - 1))

        ( Nothing, Nothing, Just t ) ->
            if index == 0 then
                toneClass t

            else
                "klar-chart-s" ++ String.fromInt (modBy 8 index)

        _ ->
            "klar-chart-s" ++ String.fromInt (modBy 8 index)


toneClass : Tone -> String
toneClass t =
    "klar-chart-t-" ++ Theme.toneSuffix t


valueAt : Int -> PSeries -> Maybe Float
valueAt i s =
    Array.get i s.values |> Maybe.andThen identity


hasAnyValue : Prepared -> Bool
hasAnyValue prepared =
    prepared.series
        |> List.any (\s -> s.values |> Array.toList |> List.any (\v -> v /= Nothing))


categoryAt : Prepared -> Int -> String
categoryAt prepared i =
    Array.get i prepared.cats |> Maybe.withDefault ""


{-| The label under the axis: as short as the category can be written.
-}
shortAt : Prepared -> Int -> String
shortAt prepared i =
    Array.get i prepared.short |> Maybe.withDefault ""



-- NUMBERS AND SCALES


{-| A number that is safe to write into an SVG attribute.
-}
num : Float -> String
num x =
    if isNaN x || isInfinite x then
        "0"

    else
        String.fromFloat (toFloat (round (clamp -100000 100000 x * 100)) / 100)


pct : Float -> String
pct x =
    num x ++ "%"


type alias Axis =
    { lo : Float
    , hi : Float
    , ticks : List Float
    , decimals : Int
    }


{-| A value axis with "nice" limits and ticks. Fixed limits that cannot make an
axis (a minimum above the maximum, or a limit on the wrong side of the data) are
ignored and the axis follows the data.
-}
axisFor : Int -> Bool -> Maybe Float -> Maybe Float -> List Float -> Axis
axisFor wanted withZero givenMin givenMax values =
    let
        axis =
            buildAxis wanted withZero givenMin givenMax values
    in
    if axis.hi > axis.lo then
        axis

    else
        buildAxis wanted withZero Nothing Nothing values


buildAxis : Int -> Bool -> Maybe Float -> Maybe Float -> List Float -> Axis
buildAxis wanted withZero givenMin givenMax values =
    let
        ( fixedMin, fixedMax ) =
            case ( givenMin, givenMax ) of
                ( Just low, Just high ) ->
                    if low >= high then
                        ( Nothing, Nothing )

                    else
                        ( givenMin, givenMax )

                _ ->
                    ( givenMin, givenMax )

        dataMin =
            List.minimum values |> Maybe.withDefault 0

        dataMax =
            List.maximum values |> Maybe.withDefault 1

        ( low0, high0 ) =
            if withZero then
                ( min 0 dataMin, max 0 dataMax )

            else
                ( dataMin, dataMax )

        low1 =
            Maybe.withDefault low0 fixedMin

        high1 =
            Maybe.withDefault high0 fixedMax

        ( low2, high2 ) =
            widen low1 high1

        range0 =
            niceNum (high2 - low2) False

        step =
            niceNum (range0 / toFloat (max 1 (wanted - 1))) True

        lo =
            case fixedMin of
                Just v ->
                    v

                Nothing ->
                    toFloat (floor (low2 / step + 1.0e-9)) * step

        hi =
            case fixedMax of
                Just v ->
                    v

                Nothing ->
                    toFloat (ceiling (high2 / step - 1.0e-9)) * step

        ( lo2, hi2 ) =
            widen lo hi

        decimals =
            stepDecimals step

        firstTick =
            ceiling (lo2 / step - 1.0e-9)

        lastTick =
            floor (hi2 / step + 1.0e-9)

        ticks =
            List.range firstTick (min lastTick (firstTick + 60))
                |> List.map (\k -> roundTo decimals (toFloat k * step))
    in
    { lo = lo2, hi = hi2, ticks = ticks, decimals = decimals }


{-| How many ticks the vertical axis gets: one per 34 pixels of plot height, at
least two and at most five, so the labels of a low chart do not run into each
other.
-}
verticalTicks : Int -> Int
verticalTicks heightPx =
    clamp 2 5 (heightPx // 34 + 1)


widen : Float -> Float -> ( Float, Float )
widen low high =
    if high - low > 1.0e-12 * max 1 (abs high) then
        ( low, high )

    else if low == 0 && high == 0 then
        ( 0, 1 )

    else
        let
            spread =
                max 1 (abs low * 0.1)
        in
        ( low - spread, high + spread )


niceNum : Float -> Bool -> Float
niceNum x doRound =
    if x <= 0 || isNaN x || isInfinite x then
        1

    else
        let
            exponent =
                toFloat (floor (logBase 10 x))

            base =
                10 ^ exponent

            fraction =
                x / base

            nice =
                if doRound then
                    if fraction < 1.5 then
                        1

                    else if fraction < 3 then
                        2

                    else if fraction < 7 then
                        5

                    else
                        10

                else if fraction <= 1 then
                    1

                else if fraction <= 2 then
                    2

                else if fraction <= 5 then
                    5

                else
                    10
        in
        nice * base


stepDecimals : Float -> Int
stepDecimals step =
    if step >= 1 then
        0

    else
        clamp 0 8 (ceiling (negate (logBase 10 step) - 1.0e-9))


roundTo : Int -> Float -> Float
roundTo decimals x =
    let
        factor =
            10 ^ toFloat decimals
    in
    toFloat (round (x * factor)) / factor


{-| 0 at `hi`, 100 at `lo` (screen y grows downwards).
-}
yPos : Axis -> Float -> Float
yPos axis v =
    clamp -30 130 (100 - 100 * (v - axis.lo) / (axis.hi - axis.lo))


{-| 0 at `lo`, 100 at `hi`.
-}
xPos : Axis -> Float -> Float
xPos axis v =
    clamp -30 130 (100 * (v - axis.lo) / (axis.hi - axis.lo))


isWhole : Float -> Bool
isWhole v =
    abs (v - toFloat (round v)) < 1.0e-9 * max 1 (abs v)


{-| A value for tooltips and the data table: as many decimals as it needs,
at most a handful.
-}
smartFormat : Locale -> Float -> String
smartFormat loc v =
    let
        a =
            abs v

        decimals =
            if isWhole v || a == 0 then
                0

            else if a >= 100 then
                1

            else if a >= 1 then
                2

            else
                clamp 2 6 (ceiling (negate (logBase 10 a)) + 1)
    in
    if a >= 1.0e15 then
        compact loc v

    else
        trimFraction loc (Format.decimal loc decimals v)


{-| "12.5%" from the ratio 0.125, in the number format of the locale.
-}
percentText : Locale -> Float -> String
percentText loc ratio =
    trimFraction loc (Format.decimal loc 1 (ratio * 100))
        ++ Locale.pick loc { nb = "\u{00A0}%", en = "%" }


{-| "2.5M" for 2500000, with the unit names of the locale. Used for axis labels of
large numbers.
-}
compact : Locale -> Float -> String
compact loc v =
    let
        a =
            abs v

        scaled divisor suffix =
            trimFraction loc (Format.decimal loc 1 (v / divisor)) ++ suffix

        -- 999 960 000 would be written "1,000M": it rounds up to the next unit.
        roundsUp divisor =
            toFloat (round (a / divisor * 10)) / 10 >= 1000

        billions =
            scaled 1.0e12 (Locale.pick loc { nb = " bill.", en = "T" })

        milliards =
            scaled 1.0e9 (Locale.pick loc { nb = " mrd.", en = "B" })

        millions =
            scaled 1.0e6 (Locale.pick loc { nb = " mill.", en = "M" })
    in
    if a >= 1.0e12 then
        billions

    else if a >= 1.0e9 then
        if roundsUp 1.0e9 then
            billions

        else
            milliards

    else if a >= 1.0e6 then
        if roundsUp 1.0e6 then
            milliards

        else
            millions

    else
        smartFormat loc v


trimFraction : Locale -> String -> String
trimFraction loc text =
    let
        separator =
            Locale.decimalSeparator loc
    in
    case String.split separator text of
        [ whole, fraction ] ->
            let
                kept =
                    dropTrailingZeros fraction
            in
            if kept == "" then
                whole

            else
                whole ++ separator ++ kept

        _ ->
            text


dropTrailingZeros : String -> String
dropTrailingZeros text =
    if String.endsWith "0" text then
        dropTrailingZeros (String.dropRight 1 text)

    else
        text


{-| A value with the chart's unit, for tooltips and the data table.
-}
formatValue : Config msg -> Float -> String
formatValue config v =
    case config.valueFormat of
        Just format ->
            format v

        Nothing ->
            smartFormat config.locale v
                ++ (if config.unit == "" then
                        ""

                    else
                        "\u{00A0}" ++ config.unit
                   )


{-| A value on an axis: compact, with the decimals the tick step needs.
-}
formatTick : Config msg -> Axis -> Float -> String
formatTick config axis v =
    case config.valueFormat of
        Just format ->
            format v

        Nothing ->
            if abs v >= 1.0e6 then
                compact config.locale v

            else
                Format.decimal config.locale axis.decimals v


{-| Short value for labels on bars.
-}
formatLabel : Config msg -> Float -> String
formatLabel config v =
    case config.valueFormat of
        Just format ->
            format v

        Nothing ->
            if abs v >= 1.0e6 then
                compact config.locale v

            else
                smartFormat config.locale v


tickGutter : Config msg -> Axis -> Int
tickGutter config axis =
    axis.ticks
        |> List.map (\t -> String.length (formatTick config axis t))
        |> List.maximum
        |> Maybe.withDefault 3
        |> (\chars -> chars * 7 + 8)
        |> clamp 28 180



-- MASKS


{-| A CSS value that paints a shape: an SVG document, made here from numbers
only, as a data URI. An element uses it as a mask and its background supplies
the color, so the stylesheet owns every color (the same way icons work).
`margin` widens the view box so a stroke at the very edge is not cut off.

The geometry is 0 to 100 in both directions and stretches to the element, so a
chart needs no knowledge of its width.

-}
maskUrl : Float -> String -> String
maskUrl margin shapes =
    let
        start =
            num (negate margin)

        extent =
            num (100 + 2 * margin)
    in
    "url(\"data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='"
        ++ start
        ++ " "
        ++ start
        ++ " "
        ++ extent
        ++ " "
        ++ extent
        ++ "' preserveAspectRatio='none'>"
        ++ shapes
        ++ "</svg>\")"


{-| A stroked line that keeps its width however much the geometry is stretched.
-}
polylineShape : Float -> Bool -> String -> String
polylineShape width isDashed coordinates =
    "<polyline points='"
        ++ coordinates
        ++ "' fill='none' stroke='black' stroke-width='"
        ++ num width
        ++ "' stroke-linecap='round' stroke-linejoin='round' vector-effect='non-scaling-stroke'"
        ++ (if isDashed then
                " stroke-dasharray='6 4'"

            else
                ""
           )
        ++ "/>"


polygonShape : String -> String
polygonShape coordinates =
    "<polygon points='" ++ coordinates ++ "' fill='black'/>"


maskLayer : List String -> String -> Html msg
maskLayer classNames url =
    Html.span
        [ Internal.cls classNames
        , Internal.styleVars [ ( "--klar-mask", url ) ]
        , Attr.attribute "aria-hidden" "true"
        ]
        []


{-| A gridline across the plot at `position` percent.
-}
gridLine : Bool -> String -> Float -> Html msg
gridLine vertical className position =
    Html.div
        [ Internal.cls
            [ className
            , if vertical then
                className ++ "--v"

              else
                ""
            ]
        , Internal.styleVars
            [ ( if vertical then
                    "left"

                else
                    "top"
              , pct position
              )
            ]
        , Attr.attribute "aria-hidden" "true"
        ]
        []



-- SHARED PIECES


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


type alias LegendItem =
    { label : String
    , cls : String
    , detail : String
    , dashed : Bool
    }


legendView : String -> List LegendItem -> Html msg
legendView shape items =
    Html.ul [ Internal.cls [ "klar-chart__legend" ] ]
        (List.map
            (\item ->
                Html.li [ Internal.cls [ "klar-chart__legend-item" ] ]
                    [ Html.span
                        [ Internal.cls
                            [ "klar-chart__swatch"
                            , "klar-chart__swatch--" ++ shape
                            , item.cls
                            , if item.dashed then
                                "klar-chart__swatch--dashed"

                              else
                                ""
                            ]
                        , Attr.attribute "aria-hidden" "true"
                        ]
                        []
                    , Html.span [ Internal.cls [ "klar-chart__legend-label" ], Attr.title item.label ] [ Html.text item.label ]
                    , if item.detail == "" then
                        Html.text ""

                      else
                        Html.span [ Internal.cls [ "klar-chart__legend-detail", "klar-tabular" ] ] [ Html.text item.detail ]
                    ]
            )
            items
        )


{-| The same numbers as a visually hidden table, for screen readers.
-}
dataTable : Config msg -> List String -> List (List String) -> Html msg
dataTable config headers rows =
    let
        t =
            texts config.locale

        limit =
            120

        shown =
            List.take limit rows

        hidden =
            List.length rows - List.length shown
    in
    -- The hiding class goes on a wrapper: a table ignores `width` and
    -- `overflow`, so a hidden table itself would be as wide as its text and
    -- push the page sideways on a phone.
    Html.div [ Internal.cls [ "klar-sr-only" ] ]
        [ Html.table []
            [ Html.caption [] [ Html.text (Maybe.withDefault "" (firstJust [ config.ariaLabel, config.title ])) ]
            , Html.thead []
                [ Html.tr [] (List.map (\h -> Html.th [ Attr.attribute "scope" "col" ] [ Html.text h ]) headers) ]
            , Html.tbody []
                (List.map
                    (\cells ->
                        case cells of
                            first :: rest ->
                                Html.tr []
                                    (Html.th [ Attr.attribute "scope" "row" ] [ Html.text first ]
                                        :: List.map (\c -> Html.td [] [ Html.text c ]) rest
                                    )

                            [] ->
                                Html.tr [] []
                    )
                    shown
                )
            , if hidden > 0 then
                Html.tfoot [] [ Html.tr [] [ Html.td [ Attr.attribute "colspan" (String.fromInt (List.length headers)) ] [ Html.text (t.tableTruncated hidden) ] ] ]

              else
                Html.text ""
            ]
        ]


plotFrame : Int -> Int -> String -> Html msg -> List (Html msg) -> List (Html msg) -> Html msg
plotFrame heightPx gutterPx label plot yLabels xLabels =
    Html.div
        [ Internal.cls [ "klar-chart__frame" ]
        , Internal.styleVars [ ( "--klar-chart-h", Internal.px heightPx ), ( "--klar-chart-gutter", Internal.px gutterPx ) ]
        , Attr.attribute "role" "img"
        , Attr.attribute "aria-label" label
        ]
        [ Html.div [ Internal.cls [ "klar-chart__y" ], Attr.attribute "aria-hidden" "true" ] yLabels
        , plot
        , Html.div [ Internal.cls [ "klar-chart__x" ], Attr.attribute "aria-hidden" "true" ] xLabels
        ]


{-| A label on the vertical axis, positioned by its y percentage.
-}
yLabel : Float -> String -> Html msg
yLabel y text =
    Html.span
        [ Internal.cls [ "klar-chart__tick", "klar-tabular" ]
        , Internal.styleVars [ ( "top", pct y ) ]
        ]
        [ Html.text text ]


{-| A label on the horizontal axis, centered at an x percentage and as wide
as the room it may use.
-}
xLabel : Float -> Float -> String -> String -> Html msg
xLabel center room full text =
    Html.span
        [ Internal.cls [ "klar-chart__xlabel", "klar-tabular" ]
        , Internal.styleVars [ ( "left", pct center ), ( "width", pct room ) ]
        , Attr.title full
        ]
        [ Html.text text ]


{-| A tick on the horizontal value axis: as wide as its text.
-}
xTick : Float -> String -> Html msg
xTick center text =
    Html.span
        [ Internal.cls [ "klar-chart__xtick", "klar-tabular" ]
        , Internal.styleVars [ ( "left", pct center ) ]
        ]
        [ Html.text text ]


summaryLine : Config msg -> String -> Int -> Int -> String
summaryLine config kindLabel seriesCount pointCount =
    let
        t =
            texts config.locale

        name =
            case ( config.ariaLabel, config.title ) of
                ( Just label, _ ) ->
                    label

                ( Nothing, Just text ) ->
                    text

                _ ->
                    ""
    in
    String.join ". "
        (List.filter (\s -> s /= "")
            [ kindLabel
            , name
            , t.seriesCount seriesCount ++ ", " ++ t.pointCount pointCount
            ]
        )



-- LINE CHART


{-| A line chart with one or more series: a trend over categories, usually time.

    Chart.line [ Chart.title "Orders per month", Chart.categories months ]
        [ Chart.series "2025" [ 12, 18, 9, 22 ]
        , Chart.series "2026" [ 14, 20, 15, 25 ]
        ]

The value axis follows the data; add `includeZero True` to start it at zero. A
missing value (see `seriesMaybe`) leaves a gap in the line. The legend shows for
two or more series, and each category has a tooltip with its values.

-}
line : List (Attribute msg) -> List Series -> Html msg
line attributes seriesList =
    let
        config =
            configure attributes

        prepared =
            prepare config seriesList
    in
    withState config "line" (heightOf config 220) (prepared.n > 0 && hasAnyValue prepared) (\() -> lineBody config prepared)


lineBody : Config msg -> Prepared -> Html msg
lineBody config prepared =
    let
        t =
            texts config.locale

        allValues =
            prepared.series
                |> List.concatMap (\s -> Array.toList s.values |> List.filterMap identity)

        axis =
            axisFor (verticalTicks (heightOf config 220)) (Maybe.withDefault False config.includeZero) config.yMin config.yMax allValues

        showPoints =
            case config.points of
                Just value ->
                    value

                Nothing ->
                    prepared.n <= 40

        n =
            prepared.n

        every =
            max 1 (ceiling (toFloat n / toFloat config.maxLabels))

        slotWidth =
            100 / toFloat n

        xLabels =
            List.range 0 (n - 1)
                |> List.filter (\i -> modBy every i == 0)
                |> List.map
                    (\i ->
                        xLabel ((toFloat i + 0.5) * slotWidth) (slotWidth * toFloat every) (categoryAt prepared i) (shortAt prepared i)
                    )

        yLabels =
            List.map (\tick -> yLabel (yPos axis tick) (formatTick config axis tick)) axis.ticks

        label =
            summaryLine config t.line (List.length prepared.series) n
    in
    shell config
        "line"
        []
        [ header config
        , plotFrame (heightOf config 220)
            (tickGutter config axis)
            label
            (linePlot config axis prepared showPoints)
            yLabels
            xLabels
        , legendIfWanted config "line" prepared
        , dataTable config
            (t.category :: List.map .name prepared.series)
            (tableRows config prepared)
        ]


legendIfWanted : Config msg -> String -> Prepared -> Html msg
legendIfWanted config shape prepared =
    if showLegend config (List.length prepared.series) then
        legendView shape (List.map (\s -> { label = s.name, cls = s.cls, detail = "", dashed = s.dashed }) prepared.series)

    else
        Html.text ""


tableRows : Config msg -> Prepared -> List (List String)
tableRows config prepared =
    List.range 0 (prepared.n - 1)
        |> List.map
            (\i ->
                categoryAt prepared i
                    :: List.map
                        (\s ->
                            case valueAt i s of
                                Just v ->
                                    formatValue config v

                                Nothing ->
                                    "-"
                        )
                        prepared.series
            )


{-| The tooltip text of one category: its name and a line per series.
-}
slotTip : Config msg -> Prepared -> Int -> String
slotTip config prepared i =
    let
        rows =
            prepared.series
                |> List.filterMap
                    (\s ->
                        valueAt i s
                            |> Maybe.map (\v -> s.name ++ ": " ++ formatValue config v)
                    )
    in
    String.join "\n" (categoryAt prepared i :: rows)


linePlot : Config msg -> Axis -> Prepared -> Bool -> Html msg
linePlot config axis prepared showPoints =
    let
        n =
            prepared.n

        xAt i =
            (toFloat i + 0.5) / toFloat n * 100

        yAt v =
            yPos axis v

        baselineY =
            clamp 0 100 (yPos axis 0)

        pointsOf run =
            run
                |> List.map (\( i, v ) -> num (xAt i) ++ "," ++ num (yAt v))
                |> String.join " "

        seriesLayers s =
            let
                stretches =
                    runs n s.values |> List.filter (\run -> List.length run >= 2)

                lineShapes =
                    List.map (\run -> polylineShape 2 s.dashed (pointsOf run)) stretches

                areaShapes =
                    if config.area then
                        stretches
                            |> List.filterMap
                                (\run ->
                                    case ( List.head run, List.head (List.reverse run) ) of
                                        ( Just ( first, _ ), Just ( last, _ ) ) ->
                                            Just
                                                (polygonShape
                                                    (pointsOf run
                                                        ++ " "
                                                        ++ num (xAt last)
                                                        ++ ","
                                                        ++ num baselineY
                                                        ++ " "
                                                        ++ num (xAt first)
                                                        ++ ","
                                                        ++ num baselineY
                                                    )
                                                )

                                        _ ->
                                            Nothing
                                )

                    else
                        []
            in
            (if List.isEmpty areaShapes then
                []

             else
                [ maskLayer [ "klar-chart__area", s.cls ] (maskUrl 0 (String.concat areaShapes)) ]
            )
                ++ (if List.isEmpty lineShapes then
                        []

                    else
                        [ maskLayer [ "klar-chart__line", s.cls ] (maskUrl 0 (String.concat lineShapes)) ]
                   )

        slot i =
            Html.div
                [ Internal.cls [ "klar-chart__slot" ]
                , Attr.title (slotTip config prepared i)
                ]
                (prepared.series
                    |> List.filterMap
                        (\s ->
                            valueAt i s
                                |> Maybe.map
                                    (\v ->
                                        Html.span
                                            [ Internal.cls
                                                [ "klar-chart__point"
                                                , s.cls
                                                , if showPoints && not s.dashed then
                                                    ""

                                                  else
                                                    "klar-chart__point--quiet"
                                                ]
                                            , -- A value outside a fixed axis is pinned to the edge of the plot.
                                              Internal.styleVars [ ( "top", pct (clamp 0 100 (yAt v)) ) ]
                                            ]
                                            []
                                    )
                        )
                )
    in
    Html.div [ Internal.cls [ "klar-chart__plot" ] ]
        (List.map (\tick -> gridLine False "klar-chart__grid" (yAt tick)) axis.ticks
            ++ [ gridLine False "klar-chart__axis" baselineY ]
            ++ List.concatMap seriesLayers prepared.series
            ++ [ Html.div
                    [ Internal.cls [ "klar-chart__slots" ]
                    , Internal.styleVars [ ( "--klar-n", String.fromInt n ) ]
                    ]
                    (List.map slot (List.range 0 (n - 1)))
               ]
        )


{-| Unbroken stretches of a series: a missing value ends a run.
-}
runs : Int -> Array (Maybe Float) -> List (List ( Int, Float ))
runs n values =
    let
        step i ( current, done ) =
            case Array.get i values |> Maybe.andThen identity of
                Just v ->
                    ( ( i, v ) :: current, done )

                Nothing ->
                    if List.isEmpty current then
                        ( [], done )

                    else
                        ( [], List.reverse current :: done )

        ( rest, finished ) =
            List.foldl step ( [], [] ) (List.range 0 (n - 1))
    in
    List.reverse
        (if List.isEmpty rest then
            finished

         else
            List.reverse rest :: finished
        )



-- BAR CHART


{-| Vertical or horizontal bars, grouped or stacked: one group of bars per
category, one bar per series.

    Chart.bar [ Chart.categories months, Chart.stacked ]
        [ Chart.series "Shipped" [ 40, 52, 47 ]
        , Chart.series "Returned" [ 3, 5, 2 ]
        ]

The value axis includes zero unless you say `includeZero False`. A value of 0
draws no bar.

-}
bar : List (Attribute msg) -> List Series -> Html msg
bar attributes seriesList =
    let
        config =
            configure attributes

        prepared =
            prepare config seriesList

        fallbackHeight =
            if config.horizontal then
                horizontalHeight config prepared

            else
                220
    in
    withState config "bar" (heightOf config fallbackHeight) (prepared.n > 0 && hasAnyValue prepared) (\() -> barBody config prepared)


horizontalHeight : Config msg -> Prepared -> Int
horizontalHeight config prepared =
    let
        perCategory =
            if config.stacked then
                28

            else
                max 28 (List.length prepared.series * 16 + 12)
    in
    clamp 120 1200 (prepared.n * perCategory + 4)


type alias Piece =
    { series : PSeries
    , index : Int
    , value : Float
    , from : Float
    , to : Float
    , outer : Bool
    }


{-| The bars of one category: for grouped bars each from 0 to its value, for
stacked bars on top of each other (positives upwards, negatives downwards).
-}
piecesOf : Config msg -> Prepared -> Int -> List Piece
piecesOf config prepared i =
    let
        present =
            prepared.series
                |> List.indexedMap Tuple.pair
                |> List.filterMap
                    (\( index, s ) ->
                        valueAt i s |> Maybe.map (\v -> { series = s, index = index, value = v, from = 0, to = v, outer = True })
                    )
    in
    if config.stacked then
        let
            stackStep piece ( posTop, negTop, done ) =
                if piece.value >= 0 then
                    ( posTop + piece.value, negTop, { piece | from = posTop, to = posTop + piece.value } :: done )

                else
                    ( posTop, negTop + piece.value, { piece | from = negTop, to = negTop + piece.value } :: done )

            ( _, _, stackedPieces ) =
                List.foldl stackStep ( 0, 0, [] ) present

            lastPositive =
                stackedPieces |> List.filter (\p -> p.value >= 0) |> List.head |> Maybe.map .index

            lastNegative =
                stackedPieces |> List.filter (\p -> p.value < 0) |> List.head |> Maybe.map .index
        in
        stackedPieces
            |> List.reverse
            |> List.map
                (\p ->
                    { p
                        | outer =
                            if p.value >= 0 then
                                Just p.index == lastPositive

                            else
                                Just p.index == lastNegative
                    }
                )

    else
        present


barBody : Config msg -> Prepared -> Html msg
barBody config prepared =
    let
        t =
            texts config.locale

        n =
            prepared.n

        extremes =
            List.range 0 (n - 1)
                |> List.concatMap
                    (\i ->
                        let
                            pieces =
                                piecesOf config prepared i
                        in
                        List.concatMap (\p -> [ p.from, p.to ]) pieces
                    )

        axis =
            axisFor
                (if config.horizontal then
                    5

                 else
                    verticalTicks (heightOf config 220)
                )
                (Maybe.withDefault True config.includeZero)
                config.yMin
                config.yMax
                extremes

        slotSize =
            100 / toFloat n

        every =
            max 1 (ceiling (toFloat n / toFloat config.maxLabels))

        label =
            summaryLine config t.bar (List.length prepared.series) n

        categoryLabels =
            List.range 0 (n - 1)
                |> List.filter (\i -> modBy every i == 0)
                |> List.map
                    (\i ->
                        if config.horizontal then
                            Html.span
                                [ Internal.cls [ "klar-chart__ylabel" ]
                                , Internal.styleVars [ ( "top", pct ((toFloat i + 0.5) * slotSize) ) ]
                                , Attr.title (categoryAt prepared i)
                                ]
                                [ Html.text (categoryAt prepared i) ]

                        else
                            xLabel ((toFloat i + 0.5) * slotSize) (slotSize * toFloat every) (categoryAt prepared i) (shortAt prepared i)
                    )

        tickLabels =
            List.map
                (\tick ->
                    if config.horizontal then
                        xTick (xPos axis tick) (formatTick config axis tick)

                    else
                        yLabel (yPos axis tick) (formatTick config axis tick)
                )
                axis.ticks

        longestCategory =
            List.range 0 (n - 1)
                |> List.map (\i -> String.length (categoryAt prepared i))
                |> List.maximum
                |> Maybe.withDefault 3

        gutter =
            if config.horizontal then
                clamp 48 168 (longestCategory * 7 + 10)

            else
                tickGutter config axis

        ( yLabels, xLabels ) =
            if config.horizontal then
                ( categoryLabels, tickLabels )

            else
                ( tickLabels, categoryLabels )

        heightPx =
            heightOf config
                (if config.horizontal then
                    horizontalHeight config prepared

                 else
                    220
                )

        totalHeader =
            if config.stacked then
                [ t.total ]

            else
                []
    in
    shell config
        "bar"
        []
        [ header config
        , plotFrame heightPx
            gutter
            label
            (barPlot config axis prepared)
            yLabels
            xLabels
        , legendIfWanted config "bar" prepared
        , dataTable config
            (t.category :: List.map .name prepared.series ++ totalHeader)
            (barTableRows config prepared)
        ]


barTableRows : Config msg -> Prepared -> List (List String)
barTableRows config prepared =
    List.range 0 (prepared.n - 1)
        |> List.map
            (\i ->
                let
                    cells =
                        List.map
                            (\s ->
                                case valueAt i s of
                                    Just v ->
                                        formatValue config v

                                    Nothing ->
                                        "-"
                            )
                            prepared.series

                    total =
                        prepared.series |> List.filterMap (valueAt i) |> List.sum
                in
                (categoryAt prepared i :: cells)
                    ++ (if config.stacked then
                            [ formatValue config total ]

                        else
                            []
                       )
            )


barPlot : Config msg -> Axis -> Prepared -> Html msg
barPlot config axis prepared =
    let
        n =
            prepared.n

        groupCount =
            max 1 (List.length prepared.series)

        horizontalBars =
            config.horizontal

        -- A bar that is longer than a fixed axis ends at the edge of the plot.
        along v =
            clamp 0
                100
                (if horizontalBars then
                    xPos axis v

                 else
                    yPos axis v
                )

        zero =
            clamp 0 100 (along 0)

        barsInView =
            n
                * (if config.stacked then
                    1

                   else
                    groupCount
                  )

        -- Labels need room: skip them when the bars are many.
        roomForLabels =
            config.valueLabels
                && barsInView
                <= (if horizontalBars then
                        60

                    else
                        24
                   )

        drawBar piece =
            let
                a =
                    along piece.from

                b =
                    along piece.to

                near =
                    min a b

                far =
                    max a b

                negative =
                    piece.value < 0

                endClass =
                    if not piece.outer then
                        ""

                    else if horizontalBars then
                        if negative then
                            "klar-chart__bar--left"

                        else
                            "klar-chart__bar--right"

                    else if negative then
                        "klar-chart__bar--down"

                    else
                        "klar-chart__bar--up"

                stackClass =
                    if config.stacked then
                        "klar-chart__bar--stacked "
                            ++ (if negative then
                                    "klar-chart__bar--neg"

                                else
                                    "klar-chart__bar--pos"
                               )

                    else
                        ""
            in
            Html.span
                [ Internal.cls [ "klar-chart__bar", piece.series.cls, endClass, stackClass ]
                , Internal.styleVars
                    (if horizontalBars then
                        [ ( "left", pct near ), ( "right", pct (100 - far) ) ]

                     else
                        [ ( "top", pct near ), ( "bottom", pct (100 - far) ) ]
                    )
                ]
                []

        -- A zero draws nothing: no bar, only its label.
        barSpan piece =
            if piece.value == 0 then
                Html.text ""

            else
                drawBar piece

        -- A label at the end of a bar: `endValue` is where the bar ends (data
        -- units), `shown` is the number written.
        valueLabel endValue shown =
            Html.span
                [ Internal.cls
                    [ "klar-chart__value"
                    , "klar-tabular"
                    , if endValue < 0 then
                        "klar-chart__value--neg"

                      else
                        ""
                    ]
                , Internal.styleVars
                    [ ( if horizontalBars then
                            "left"

                        else
                            "top"
                      , pct (along endValue)
                      )
                    ]
                ]
                [ Html.text (formatLabel config shown) ]

        slot i =
            let
                pieces =
                    piecesOf config prepared i

                lanes =
                    if config.stacked then
                        let
                            total =
                                List.sum (List.map .value pieces)

                            top =
                                List.foldl (\p acc -> max acc (max p.from p.to)) 0 pieces

                            bottom =
                                List.foldl (\p acc -> min acc (min p.from p.to)) 0 pieces
                        in
                        [ Html.div [ Internal.cls [ "klar-chart__lane" ] ]
                            (List.map barSpan pieces
                                ++ (if roomForLabels && not (List.isEmpty pieces) then
                                        [ valueLabel
                                            (if top > 0 then
                                                top

                                             else
                                                bottom
                                            )
                                            total
                                        ]

                                    else
                                        []
                                   )
                            )
                        ]

                    else
                        List.range 0 (groupCount - 1)
                            |> List.map
                                (\index ->
                                    case List.filter (\p -> p.index == index) pieces |> List.head of
                                        Just piece ->
                                            Html.div [ Internal.cls [ "klar-chart__lane" ] ]
                                                (barSpan piece
                                                    :: (if roomForLabels then
                                                            [ valueLabel piece.to piece.value ]

                                                        else
                                                            []
                                                       )
                                                )

                                        Nothing ->
                                            Html.div [ Internal.cls [ "klar-chart__lane" ] ] []
                                )
            in
            Html.div
                [ Internal.cls [ "klar-chart__slot" ]
                , Attr.title (barTip config prepared i)
                ]
                [ Html.div [ Internal.cls [ "klar-chart__lanes" ] ] lanes ]
    in
    Html.div
        [ Internal.cls
            [ "klar-chart__plot"
            , if horizontalBars then
                "klar-chart__plot--horizontal"

              else
                ""
            ]
        ]
        (List.map (\tick -> gridLine horizontalBars "klar-chart__grid" (along tick)) axis.ticks
            ++ [ Html.div
                    [ Internal.cls [ "klar-chart__slots", "klar-chart__bars" ]
                    , Internal.styleVars [ ( "--klar-n", String.fromInt n ) ]
                    ]
                    (List.map slot (List.range 0 (n - 1)))
               , gridLine horizontalBars "klar-chart__axis" zero
               ]
        )


barTip : Config msg -> Prepared -> Int -> String
barTip config prepared i =
    let
        base =
            slotTip config prepared i

        total =
            prepared.series |> List.filterMap (valueAt i) |> List.sum

        t =
            texts config.locale
    in
    if config.stacked && List.length prepared.series > 1 then
        base ++ "\n" ++ t.total ++ ": " ++ formatValue config total

    else
        base



-- DONUT


{-| Parts of a whole. It is best with up to six slices: when there are more than
eight, the seven largest are kept and the rest are folded into one slice called
"Other".

    Chart.donut [ Chart.centerCaption "orders" ]
        [ Chart.segment "Shipped" 420, Chart.segment "Pending" 310 ]

The total is written in the middle unless `centerLabel` says otherwise, and the
legend lists every slice with its value and its share of the total. The legend is
shown unless you say `legend False`. Slices with a value of 0 are left out.

-}
donut : List (Attribute msg) -> List Segment -> Html msg
donut attributes segments =
    let
        config =
            configure attributes

        t =
            texts config.locale

        positive =
            segments
                |> List.map (\(Segment s) -> s)
                |> List.filter (\s -> s.value > 0)

        folded =
            if List.length positive > 8 then
                let
                    sorted =
                        List.sortBy (\s -> negate s.value) positive

                    rest =
                        List.drop 7 sorted
                in
                List.take 7 sorted
                    ++ [ { label = t.other, value = List.sum (List.map .value rest), color = Just 8, tone = Nothing } ]

            else
                positive

        total =
            List.sum (List.map .value folded)
    in
    withState config "donut" 168 (total > 0) (\() -> donutBody config folded total)


type alias Slice =
    { label : String
    , value : Float
    , color : Maybe Int
    , tone : Maybe Tone
    }


donutBody : Config msg -> List Slice -> Float -> Html msg
donutBody config slices total =
    let
        t =
            texts config.locale

        classes =
            List.indexedMap (\index s -> colorClass Nothing index s.color s.tone) slices

        share s =
            s.value / total

        shareText s =
            percentText config.locale (share s)

        label =
            String.join ". "
                (List.filter (\x -> x /= "")
                    [ t.donut
                    , Maybe.withDefault "" (firstJust [ config.ariaLabel, config.title ])
                    , t.segmentCount (List.length slices)
                    ]
                )

        sliceTip s =
            s.label ++ ": " ++ formatValue config s.value ++ " (" ++ shareText s ++ ")"

        outer =
            46

        inner =
            32

        -- A 1.6% gap between slices, written as an angle at the outer edge.
        gap =
            if List.length slices > 1 then
                1.6 / outer

            else
                0

        arcs =
            slices
                |> List.foldl
                    (\s ( start, done ) ->
                        let
                            end =
                                start + share s * 2 * pi
                        in
                        ( end, ( s, start, end ) :: done )
                    )
                    ( 0, [] )
                |> Tuple.second
                |> List.reverse

        segmentEls =
            List.map2
                (\cls ( s, start, end ) ->
                    let
                        trim =
                            if end - start > 3 * gap then
                                gap

                            else
                                0
                    in
                    Html.div
                        [ Internal.cls [ "klar-chart__segment", cls ]
                        , Attr.title (sliceTip s)
                        , Internal.styleVars [ ( "clip-path", ringPolygon outer inner (start + trim) (end - trim) ) ]
                        ]
                        []
                )
                classes
                arcs

        centerText =
            Maybe.withDefault (formatLabel config total) config.centerLabel

        legendItems =
            List.map2
                (\cls s ->
                    { label = s.label
                    , cls = cls
                    , detail = formatValue config s.value ++ "  ·  " ++ shareText s
                    , dashed = False
                    }
                )
                classes
                slices
    in
    shell config
        "donut"
        []
        [ header config
        , Html.div [ Internal.cls [ "klar-chart__donut" ] ]
            [ Html.div
                [ Internal.cls [ "klar-chart__donut-frame" ]
                , Attr.attribute "role" "img"
                , Attr.attribute "aria-label" label
                ]
                [ Html.div [ Internal.cls [ "klar-chart__segments" ] ] segmentEls
                , Html.div [ Internal.cls [ "klar-chart__center" ], Attr.attribute "aria-hidden" "true" ]
                    [ Html.span [ Internal.cls [ "klar-chart__center-value" ] ] [ Html.text centerText ]
                    , Internal.viewMaybe (\text -> Html.span [ Internal.cls [ "klar-chart__center-caption" ] ] [ Html.text text ]) config.centerCaption
                    ]
                ]
            , if Maybe.withDefault True config.legend then
                legendView "bar" legendItems

              else
                Html.text ""
            ]
        , dataTable config
            [ t.category, t.value, t.share ]
            (List.map (\s -> [ s.label, formatValue config s.value, shareText s ]) slices)
        ]


{-| A ring sector between two radii, as a `clip-path` polygon. Angles are in
radians from 12 o'clock, clockwise; radii are percentages of the box. The arc
is approximated with a point every 2.5 degrees. A polygon (unlike a mask)
also decides where the pointer hits, so every slice has its own tooltip.
-}
ringPolygon : Float -> Float -> Float -> Float -> String
ringPolygon outer inner a0 a1 =
    let
        sweep =
            a1 - a0

        steps =
            clamp 2 160 (ceiling (sweep / (pi / 72)))

        angleAt k =
            a0 + sweep * toFloat k / toFloat steps

        point radius angle =
            pct (50 + radius * sin angle) ++ " " ++ pct (50 - radius * cos angle)

        outerEdge =
            List.map (\k -> point outer (angleAt k)) (List.range 0 steps)

        innerEdge =
            List.map (\k -> point inner (angleAt k)) (List.reverse (List.range 0 steps))
    in
    if sweep <= 0 then
        "polygon(0% 0%)"

    else
        "polygon(" ++ String.join "," (outerEdge ++ innerEdge) ++ ")"



-- GAUGE


{-| A half-circle gauge for one value against a scale (see `range`; the default
is 0 to 100). The zone the value falls in (see `thresholds`) decides the color.

    Chart.gauge [ Chart.centerCaption "of capacity", Chart.unit "%" ] 82

The value is written in the middle unless `centerLabel` says otherwise. A value
outside the scale fills the arc completely or not at all but is written as it is,
and a value that is not a number counts as the lowest value of the scale.

-}
gauge : List (Attribute msg) -> Float -> Html msg
gauge attributes rawValue =
    let
        config =
            configure attributes

        t =
            texts config.locale

        value =
            Maybe.withDefault config.rangeMin (sanitize rawValue)

        low =
            min config.rangeMin config.rangeMax

        high =
            max config.rangeMin config.rangeMax

        fractionOf v =
            if high - low <= 0 then
                0

            else
                clamp 0 1 ((v - low) / (high - low))

        cls =
            toneClassFor config (zoneToneFor config value)

        zoneMarks =
            config.thresholds
                |> List.map (\( limit, _ ) -> fractionOf limit)
                |> List.filter (\f -> f > 0.001 && f < 0.999)
                |> List.map
                    (\f ->
                        Html.span
                            [ Internal.cls [ "klar-chart__gauge-mark" ]
                            , Internal.styleVars [ ( "--klar-f", String.fromFloat (roundTo 3 f) ) ]
                            ]
                            []
                    )

        valueText =
            Maybe.withDefault (formatValue config value) config.centerLabel

        label =
            String.join ". "
                (List.filter (\x -> x /= "")
                    [ Maybe.withDefault "" (firstJust [ config.ariaLabel, config.title ])
                    , Maybe.withDefault t.gauge config.centerCaption
                    ]
                )
    in
    withState config
        "gauge"
        110
        True
        (\() ->
            shell config
                "gauge"
                []
                [ header config
                , Html.div
                    [ Internal.cls [ "klar-chart__gauge" ]
                    , Attr.attribute "role" "meter"
                    , Attr.attribute "aria-label" label
                    , Attr.attribute "aria-valuemin" (String.fromFloat low)
                    , Attr.attribute "aria-valuemax" (String.fromFloat high)
                    , Attr.attribute "aria-valuenow" (String.fromFloat value)
                    , Attr.attribute "aria-valuetext" valueText
                    ]
                    ([ Html.div
                        [ Internal.cls [ "klar-chart__gauge-arc", cls ]
                        , Internal.styleVars [ ( "--klar-f", String.fromFloat (roundTo 3 (fractionOf value)) ) ]
                        , Attr.title (formatValue config value)
                        ]
                        []
                     ]
                        ++ zoneMarks
                        ++ [ Html.div [ Internal.cls [ "klar-chart__center", "klar-chart__center--gauge" ] ]
                                [ Html.span [ Internal.cls [ "klar-chart__center-value" ] ] [ Html.text valueText ]
                                , Internal.viewMaybe (\text -> Html.span [ Internal.cls [ "klar-chart__center-caption" ] ] [ Html.text text ]) config.centerCaption
                                ]
                           , Html.div [ Internal.cls [ "klar-chart__gauge-scale", "klar-tabular" ], Attr.attribute "aria-hidden" "true" ]
                                [ Html.span [] [ Html.text (formatLabel config low) ]
                                , Html.span [] [ Html.text (formatLabel config high) ]
                                ]
                           ]
                    )
                ]
        )


firstJust : List (Maybe a) -> Maybe a
firstJust maybes =
    case maybes of
        [] ->
            Nothing

        (Just x) :: _ ->
            Just x

        Nothing :: rest ->
            firstJust rest


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


toneClassFor : Config msg -> Maybe Tone -> String
toneClassFor _ maybeTone =
    case maybeTone of
        Just t ->
            toneClass t

        Nothing ->
            toneClass Primary



-- METER


{-| A horizontal meter: the value as a marker on a scale with zones.

    Chart.meter
        [ Chart.range 0 100
        , Chart.title "Warehouse fill"
        , Chart.thresholds [ ( 70, Success ), ( 90, Warning ), ( 100, Danger ) ]
        ]
        84

The title and the value are written above the track, and the two ends of the
scale below it. A meter is flat and as wide as its container, so it fits where
a gauge would take too much room.

-}
meter : List (Attribute msg) -> Float -> Html msg
meter attributes rawValue =
    let
        config =
            configure attributes

        t =
            texts config.locale

        value =
            Maybe.withDefault config.rangeMin (sanitize rawValue)

        low =
            min config.rangeMin config.rangeMax

        high =
            max config.rangeMin config.rangeMax

        position v =
            if high - low <= 0 then
                0

            else
                clamp 0 100 (100 * (v - low) / (high - low))

        zones =
            case config.thresholds of
                [] ->
                    [ ( high, Maybe.withDefault Primary config.tone ) ]

                list ->
                    list

        zoneStarts =
            low :: List.map Tuple.first zones

        zoneViews =
            List.map2
                (\start ( limit, zoneTone ) ->
                    Html.span
                        [ Internal.cls [ "klar-meter__zone", toneClass zoneTone ]
                        , Internal.styleVars [ ( "left", pct (position start) ), ( "width", pct (max 0 (position limit - position start)) ) ]
                        ]
                        []
                )
                zoneStarts
                zones

        current =
            zoneToneFor config value |> Maybe.withDefault Primary

        valueText =
            Maybe.withDefault (formatValue config value) config.centerLabel

        name =
            Maybe.withDefault t.meter (firstJust [ config.ariaLabel, config.title ])
    in
    withState config
        "meter"
        40
        True
        (\() ->
            Html.figure
                [ Internal.cls [ "klar-chart", "klar-chart--meter" ]
                , Attr.attribute "role" "meter"
                , Attr.attribute "aria-label" name
                , Attr.attribute "aria-valuemin" (String.fromFloat low)
                , Attr.attribute "aria-valuemax" (String.fromFloat high)
                , Attr.attribute "aria-valuenow" (String.fromFloat value)
                , Attr.attribute "aria-valuetext" valueText
                ]
                [ Html.div [ Internal.cls [ "klar-meter__head" ] ]
                    [ Html.span [ Internal.cls [ "klar-meter__label" ] ] [ Html.text (Maybe.withDefault "" config.title) ]
                    , Html.span [ Internal.cls [ "klar-meter__value", "klar-tabular", toneClass current ] ] [ Html.text valueText ]
                    ]
                , Html.div [ Internal.cls [ "klar-meter__track" ], Attr.attribute "aria-hidden" "true" ]
                    (zoneViews
                        ++ [ Html.span
                                [ Internal.cls [ "klar-meter__marker", toneClass current ]
                                , Internal.styleVars [ ( "left", pct (position value) ) ]
                                ]
                                []
                           ]
                    )
                , Html.div [ Internal.cls [ "klar-meter__scale", "klar-tabular" ], Attr.attribute "aria-hidden" "true" ]
                    [ Html.span [] [ Html.text (formatLabel config low) ]
                    , Html.span [] [ Html.text (formatLabel config high) ]
                    ]
                ]
        )



-- SPARKLINE


{-| A tiny trend line without axes, for a table cell or a tile (see
[Klar.Stat](Klar-Stat)). The last value gets a dot. It needs no categories; give it
an `ariaLabel` that says what it shows, because a sparkline has no title.

    Chart.sparkline
        [ Chart.ariaLabel "Orders, last 7 days", Chart.area, Chart.height 32 ]
        [ 3, 5, 4, 8, 7, 9, 12 ]

Values that are not numbers are left out. With one value there is only the dot,
with none a dash. The default height is 28px and the width fills the container
(see `size`).

-}
sparkline : List (Attribute msg) -> List Float -> Html msg
sparkline attributes rawValues =
    let
        config =
            configure attributes

        t =
            texts config.locale

        values =
            List.filterMap sanitize rawValues

        n =
            List.length values

        low =
            List.minimum values |> Maybe.withDefault 0

        high =
            List.maximum values |> Maybe.withDefault 0

        yAt v =
            if high - low <= 0 then
                50

            else
                100 - 100 * (v - low) / (high - low)

        xAt i =
            if n <= 1 then
                50

            else
                100 * toFloat i / toFloat (n - 1)

        coordinates =
            List.indexedMap (\i v -> ( xAt i, yAt v )) values

        pointList =
            coordinates
                |> List.map (\( x, y ) -> num x ++ "," ++ num y)
                |> String.join " "

        cls =
            case config.tone of
                Just tn ->
                    toneClass tn

                Nothing ->
                    "klar-chart-s0"

        lastValue =
            List.reverse values |> List.head |> Maybe.withDefault 0

        ( lastX, lastY ) =
            List.reverse coordinates |> List.head |> Maybe.withDefault ( 50, 50 )

        -- The mask is a little larger than the data, so a stroke at the very
        -- edge is not cut off; the dot is placed in the same widened box.
        margin =
            4

        inBox v =
            pct ((v + margin) / (100 + 2 * margin) * 100)

        layers =
            (if config.area && n >= 2 then
                [ maskLayer [ "klar-chart__area", cls ] (maskUrl margin (polygonShape (pointList ++ " 100,100 0,100"))) ]

             else
                []
            )
                ++ (if n >= 2 then
                        [ maskLayer [ "klar-chart__line", "klar-chart__line--thin", cls ] (maskUrl margin (polylineShape 1.5 False pointList)) ]

                    else
                        []
                   )

        summary =
            case config.ariaLabel of
                Just label ->
                    label

                Nothing ->
                    t.sparkline
                        ++ ": "
                        ++ t.pointCount n
                        ++ ", "
                        ++ formatValue config low
                        ++ " - "
                        ++ formatValue config high
                        ++ ", "
                        ++ formatValue config lastValue

        boxStyle =
            Internal.styleVars
                (List.filterMap identity
                    [ Maybe.map (\w -> ( "--klar-chart-w", Internal.px w )) config.size
                    , Just ( "--klar-chart-sh", Internal.px (heightOf config 28) )
                    ]
                )
    in
    case stateOf config of
        Busy ->
            Html.span [ Internal.cls [ "klar-chart-spark", "klar-chart-spark--loading" ], boxStyle, Attr.attribute "aria-busy" "true" ]
                [ Skeleton.line 100 ]

        Failed problem ->
            Html.span
                [ Internal.cls [ "klar-chart-spark", "klar-chart-spark--empty" ]
                , boxStyle
                , Attr.attribute "role" "img"
                , Attr.attribute "aria-label" (Remote.title config.locale problem)
                , Attr.title (Remote.title config.locale problem)
                ]
                [ Html.span [ Attr.attribute "aria-hidden" "true" ] [ Html.text "–" ] ]

        Ready ->
            if n == 0 then
                let
                    emptyLabel =
                        Maybe.withDefault t.noData config.emptyText
                in
                Html.span
                    [ Internal.cls [ "klar-chart-spark", "klar-chart-spark--empty" ]
                    , boxStyle
                    , Attr.attribute "role" "img"
                    , Attr.attribute "aria-label" emptyLabel
                    , Attr.title emptyLabel
                    ]
                    [ Html.span [ Attr.attribute "aria-hidden" "true" ] [ Html.text "–" ] ]

            else
                let
                    described =
                        case config.freshness of
                            Freshness.Stale value ->
                                summary ++ ". " ++ Freshness.text config.locale config.settings value.at

                            _ ->
                                summary
                in
                Html.span
                    [ Internal.cls [ "klar-chart-spark", Freshness.className config.freshness ]
                    , boxStyle
                    , Attr.attribute "role" "img"
                    , Attr.attribute "aria-label" described
                    , Attr.title described
                    , Freshness.busyAttr config.freshness
                    ]
                    [ Html.span [ Internal.cls [ "klar-chart-spark__field" ] ]
                        (layers
                            ++ [ Html.span
                                    [ Internal.cls [ "klar-chart__point", "klar-chart__point--last", cls ]
                                    , Internal.styleVars [ ( "left", inBox lastX ), ( "top", inBox lastY ) ]
                                    ]
                                    []
                               ]
                        )
                    ]
