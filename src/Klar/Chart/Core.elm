module Klar.Chart.Core exposing (..)

{-| Chart implementations behind the representation-stable public documentation facade.
-}

import Array exposing (Array)
import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Events
import Klar.Chart.Axis exposing (axisFor, buildAxis, niceNum, verticalTicks, widen, xPos, yPos)
import Klar.Chart.Colors exposing (colorClass, toneClass, toneClassFor)
import Klar.Chart.Config exposing (area, ariaLabel, categories, centerCaption, centerLabel, configure, dates, description, emptyText, height, heightOf, hideLegend, horizontal, id, includeZero, legend, locale, maxLabels, onRetry, onSelect, pointsOnHover, range, selectable, settings, showLegend, stacked, thresholds, title, tone, unit, valueFormat, valueLabels, width, yMax, yMin, zoneToneFor)
import Klar.Chart.Data exposing (byCategory, byDate, dashed, noData, segment, segmentSlot, segmentTone, series, seriesMaybe, withSlot, withTone)
import Klar.Chart.Numbers exposing (compact, dropTrailingZeros, firstJust, formatLabel, formatTick, formatValue, isWhole, missingOr, num, pct, percentText, roundTo, sanitize, smartFormat, stepDecimals, tickGutter, trimFraction)
import Klar.Chart.Types exposing (Attribute(..), Axis, Config, Data(..), LegendItem, PSeries, Piece, Prepared, Segment(..), Series(..), Slice, State(..), Texts)
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


{-| A category button: its click, and its values as the accessible name and the
tooltip. Without `onSelect` the category is a plain element with a native tooltip.
The tooltip of a category in the first or last third of the plot is aligned with
its start or its end, so it stays over the chart instead of sticking out past it.
-}
categoryElement : Config msg -> Int -> Int -> String -> List (Html.Attribute msg) -> List (Html msg) -> Html msg
categoryElement config count index tip attributes children =
    case config.onSelect of
        Just toMsg ->
            let
                align =
                    if 3 * index < count - 1 then
                        "klar-chart__slot--tip-start"

                    else if 3 * index > 2 * (count - 1) then
                        "klar-chart__slot--tip-end"

                    else
                        ""
            in
            Html.button
                ([ Attr.type_ "button"
                 , Internal.cls [ "klar-chart__slot", "klar-chart__slot--button", align ]
                 , Events.onClick (toMsg index)
                 , Attr.attribute "aria-label" (String.join ". " (String.lines tip))
                 , Attr.attribute "data-tip" tip
                 ]
                    ++ attributes
                )
                children

        Nothing ->
            Html.div (Internal.cls [ "klar-chart__slot" ] :: Attr.title tip :: attributes) children


{-| The state of a chart drawn from a `Remote`, and the data to draw when there is
data (`Kept` data counts).
-}
fromRemote : Remote a -> ( Attribute msg, Maybe a )
fromRemote data =
    let
        ( settled, freshness ) =
            Freshness.settle data
    in
    ( Attribute
        (\config ->
            { config
                | busy = Freshness.waiting settled
                , failure =
                    case settled of
                        Remote.Failed problem ->
                            Just problem

                        _ ->
                            Nothing
                , freshness = freshness
                , fromRemote = True
            }
        )
    , case settled of
        Remote.Loaded payload ->
            Just payload

        _ ->
            Nothing
    )


{-| Draws a chart from a `Remote` with the chart function of its kind and the
value to draw while there is nothing.
-}
remoteWith : (List (Attribute msg) -> a -> Html msg) -> a -> List (Attribute msg) -> Remote a -> Html msg
remoteWith draw nothing attributes data =
    let
        ( state, payload ) =
            fromRemote data
    in
    draw (attributes ++ [ state ]) (Maybe.withDefault nothing payload)


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
    , low = pick "lavest" "low"
    , high = pick "høyest" "high"
    , last = pick "siste" "last"
    , noValue = pick "Ingen verdi" "No value"
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
                if config.fromRemote then
                    -- The same elements around the chart whether the data is
                    -- fresh, refreshing or old, so that focus on a category
                    -- button survives a refresh.
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
                    body ()

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
         , case config.width of
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
polylineShape strokeWidth isDashed coordinates =
    "<polyline points='"
        ++ coordinates
        ++ "' fill='none' stroke='black' stroke-width='"
        ++ num strokeWidth
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


legendView : String -> List (LegendItem msg) -> Html msg
legendView shape items =
    Html.ul [ Internal.cls [ "klar-chart__legend" ] ]
        (List.map
            (\item ->
                let
                    content =
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
                in
                case item.select of
                    Just msg ->
                        -- A selectable slice: the legend item is its button, so
                        -- the keyboard reaches every slice.
                        Html.li [ Internal.cls [ "klar-chart__legend-entry" ] ]
                            [ Html.button
                                [ Attr.type_ "button"
                                , Internal.cls [ "klar-chart__legend-item", "klar-chart__legend-item--button" ]
                                , Events.onClick msg
                                ]
                                content
                            ]

                    Nothing ->
                        Html.li [ Internal.cls [ "klar-chart__legend-item" ] ] content
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


{-| The plot with its axes. It is a picture (`role="img"`) unless its categories
are buttons (`onSelect`): then it is a group, so that the buttons are reachable.
-}
plotFrame : Config msg -> Int -> Int -> String -> Html msg -> List (Html msg) -> List (Html msg) -> Html msg
plotFrame config heightPx gutterPx label plot yLabels xLabels =
    Html.div
        [ Internal.cls [ "klar-chart__frame" ]
        , Internal.styleVars [ ( "--klar-chart-h", Internal.px heightPx ), ( "--klar-chart-gutter", Internal.px gutterPx ) ]
        , Attr.attribute "role"
            (if selectable config then
                "group"

             else
                "img"
            )
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

The value axis follows the data; add `includeZero` to start it at zero. A
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
            axisFor (verticalTicks (heightOf config 220)) (config.includeZero || config.area) config.yMin config.yMax allValues

        showPoints =
            not config.pointsOnHover && prepared.n <= 40

        n =
            prepared.n

        every =
            max 1 (ceiling (toFloat n / toFloat (Maybe.withDefault 12 config.maxLabels)))

        slotWidth =
            100 / toFloat n

        xLabels =
            labelledIndexes n every
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
        , plotFrame config
            (heightOf config 220)
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


{-| The categories that get a label on the axis when every `every`-th one has
room: the first, every `every`-th after it, and always the last (usually the most
recent period); the label just before the last is dropped when the two would be
closer than `every`.
-}
labelledIndexes : Int -> Int -> List Int
labelledIndexes n every =
    List.range 0 (n - 1)
        |> List.filter (\i -> i == n - 1 || (modBy every i == 0 && n - 1 - i >= every))


legendIfWanted : Config msg -> String -> Prepared -> Html msg
legendIfWanted config shape prepared =
    if showLegend config (List.length prepared.series) then
        legendView shape (List.map (\s -> { label = s.name, cls = s.cls, detail = "", dashed = s.dashed, select = Nothing }) prepared.series)

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
            categoryElement config
                prepared.n
                i
                (slotTip config prepared i)
                []
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

The value axis always includes zero, so a bar is read by its length. A value of 0
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
                True
                config.yMin
                config.yMax
                extremes

        slotSize =
            100 / toFloat n

        -- A horizontal chart has a row per bar: every bar is named when its row
        -- is at least 14px high. A vertical chart thins its labels to 12.
        every =
            if config.horizontal then
                max (max 1 (ceiling (14 * toFloat n / toFloat heightPx)))
                    (case config.maxLabels of
                        Just most ->
                            ceiling (toFloat n / toFloat most)

                        Nothing ->
                            1
                    )

            else
                max 1 (ceiling (toFloat n / toFloat (Maybe.withDefault 12 config.maxLabels)))

        label =
            summaryLine config t.bar (List.length prepared.series) n

        categoryLabels =
            labelledIndexes n every
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
        , plotFrame config
            heightPx
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
                        [ Html.span [ Internal.cls [ "klar-chart__lane" ] ]
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
                                            Html.span [ Internal.cls [ "klar-chart__lane" ] ]
                                                (barSpan piece
                                                    :: (if roomForLabels then
                                                            [ valueLabel piece.to piece.value ]

                                                        else
                                                            []
                                                       )
                                                )

                                        Nothing ->
                                            Html.span [ Internal.cls [ "klar-chart__lane" ] ] []
                                )
            in
            categoryElement config
                prepared.n
                i
                (barTip config prepared i)
                []
                [ Html.span [ Internal.cls [ "klar-chart__lanes" ] ] lanes ]
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
shown unless you say `hideLegend`. Slices with a value of 0 are left out.

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
                |> List.indexedMap (\index (Segment s) -> { label = s.label, value = s.value, color = s.color, tone = s.tone, index = Just index })
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
                    ++ [ { label = t.other, value = List.sum (List.map .value rest), color = Just 8, tone = Nothing, index = Nothing } ]

            else
                positive

        total =
            List.sum (List.map .value folded)
    in
    withState config "donut" 168 (total > 0) (\() -> donutBody config folded total)


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
                        [ Internal.cls
                            [ "klar-chart__segment"
                            , cls
                            , case sliceMsg s of
                                Just _ ->
                                    "klar-chart__segment--button"

                                Nothing ->
                                    ""
                            ]
                        , Attr.title (sliceTip s)
                        , Internal.styleVars [ ( "clip-path", ringPolygon outer inner (start + trim) (end - trim) ) ]
                        , Internal.attrMaybe Events.onClick (sliceMsg s)
                        ]
                        []
                )
                classes
                arcs

        -- The message of a slice: its position in the given list ("Other" has none).
        sliceMsg s =
            Maybe.map2 (\toMsg index -> toMsg index) config.onSelect s.index

        centerText =
            Maybe.withDefault (formatLabel config total) config.centerLabel

        legendItems =
            List.map2
                (\cls s ->
                    { label = s.label
                    , cls = cls
                    , detail = formatValue config s.value ++ "  ·  " ++ shareText s
                    , dashed = False
                    , select = sliceMsg s
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

              else if selectable config then
                -- hideLegend with onSelect: the legend buttons are the only
                -- keyboard path to the slices, so they stay, out of sight until
                -- one of them has the focus.
                Html.div [ Internal.cls [ "klar-chart__legend-hidden" ] ] [ legendView "bar" legendItems ]

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
outside the scale fills the arc completely or not at all but is written as it is.
A value that is not a number (NaN, infinity) is a missing measurement: the arc
stays empty, the middle shows a dash and screen readers hear "No value".

-}
gauge : List (Attribute msg) -> Float -> Html msg
gauge attributes rawValue =
    let
        config =
            configure attributes

        t =
            texts config.locale

        measured =
            sanitize rawValue

        value =
            Maybe.withDefault config.rangeMin measured

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

        ( valueText, spokenValue ) =
            missingOr t measured (\v -> Maybe.withDefault (formatValue config v) config.centerLabel)

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
                    , Attr.attribute "aria-valuenow" (String.fromFloat (clamp low high value))
                    , Attr.attribute "aria-valuetext" spokenValue
                    ]
                    ([ Html.div
                        [ Internal.cls [ "klar-chart__gauge-arc", cls ]
                        , Internal.styleVars
                            [ ( "--klar-f"
                              , case measured of
                                    Just _ ->
                                        String.fromFloat (roundTo 3 (fractionOf value))

                                    Nothing ->
                                        "0"
                              )
                            ]
                        , Attr.title spokenValue
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
meter attributes rawValue =
    let
        config =
            configure attributes

        t =
            texts config.locale

        measured =
            sanitize rawValue

        value =
            Maybe.withDefault config.rangeMin measured

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

        ( valueText, spokenValue ) =
            missingOr t measured (\v -> Maybe.withDefault (formatValue config v) config.centerLabel)

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
                , Attr.attribute "aria-valuenow" (String.fromFloat (clamp low high value))
                , Attr.attribute "aria-valuetext" spokenValue
                ]
                [ Html.div [ Internal.cls [ "klar-meter__head" ] ]
                    [ Html.span [ Internal.cls [ "klar-meter__label" ] ] [ Html.text (Maybe.withDefault "" config.title) ]
                    , Html.span [ Internal.cls [ "klar-meter__value", "klar-tabular", toneClass current ] ] [ Html.text valueText ]
                    ]
                , Html.div [ Internal.cls [ "klar-meter__track" ], Attr.attribute "aria-hidden" "true" ]
                    (zoneViews
                        ++ (case measured of
                                Just _ ->
                                    [ Html.span
                                        [ Internal.cls [ "klar-meter__marker", toneClass current ]
                                        , Internal.styleVars [ ( "left", pct (position value) ) ]
                                        ]
                                        []
                                    ]

                                Nothing ->
                                    []
                           )
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
(see `width`).

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

        -- The numbers are always in the name: an `ariaLabel` says what the line
        -- shows, the summary what it says.
        numbers =
            t.pointCount n
                ++ ", "
                ++ t.low
                ++ " "
                ++ formatValue config low
                ++ ", "
                ++ t.high
                ++ " "
                ++ formatValue config high
                ++ ", "
                ++ t.last
                ++ " "
                ++ formatValue config lastValue

        summary =
            case config.ariaLabel of
                Just label ->
                    label ++ ". " ++ numbers

                Nothing ->
                    t.sparkline ++ ": " ++ numbers

        boxStyle =
            Internal.styleVars
                (List.filterMap identity
                    [ Maybe.map (\w -> ( "--klar-chart-w", Internal.px w )) config.width
                    , Just ( "--klar-chart-sh", Internal.px (heightOf config 28) )
                    ]
                )

        idAttrs =
            case config.id of
                Just domId ->
                    [ Attr.id domId, Attr.tabindex -1 ]

                Nothing ->
                    []
    in
    case stateOf config of
        Busy ->
            Html.span ([ Internal.cls [ "klar-chart-spark", "klar-chart-spark--loading" ], boxStyle, Attr.attribute "aria-busy" "true" ] ++ idAttrs)
                [ Skeleton.line 100 ]

        Failed problem ->
            Html.span
                ([ Internal.cls [ "klar-chart-spark", "klar-chart-spark--empty" ]
                 , boxStyle
                 , Attr.attribute "role" "img"
                 , Attr.attribute "aria-label" (Remote.title config.locale problem)
                 , Attr.title (Remote.title config.locale problem)
                 ]
                    ++ idAttrs
                )
                [ Html.span [ Attr.attribute "aria-hidden" "true" ] [ Html.text "–" ] ]

        Ready ->
            if n == 0 then
                let
                    emptyLabel =
                        Maybe.withDefault t.noData config.emptyText
                in
                Html.span
                    ([ Internal.cls [ "klar-chart-spark", "klar-chart-spark--empty" ]
                     , boxStyle
                     , Attr.attribute "role" "img"
                     , Attr.attribute "aria-label" emptyLabel
                     , Attr.title emptyLabel
                     ]
                        ++ idAttrs
                    )
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
                    ([ Internal.cls [ "klar-chart-spark", Freshness.className config.freshness ]
                     , boxStyle
                     , Attr.attribute "role" "img"
                     , Attr.attribute "aria-label" described
                     , Attr.title described
                     , Freshness.busyAttr config.freshness
                     ]
                        ++ idAttrs
                    )
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



-- FROM A REMOTE


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
lineRemote =
    remoteWith (withData line) noData


{-| A bar chart from a `Remote`, with every state of `lineRemote`.

    Chart.barRemote [ Chart.horizontal, Chart.onRetry ReloadWarehouses ]
        (Remote.map
            (\rows -> Chart.byCategory (List.map .name rows) [ Chart.series "Late orders" (List.map .late rows) ])
            model.warehouses
        )

-}
barRemote : List (Attribute msg) -> Remote Data -> Html msg
barRemote =
    remoteWith (withData bar) noData


{-| Draws a line or bar chart from a `Data`: its categories (or days) come last, so
they replace any given in the attributes.
-}
withData : (List (Attribute msg) -> List Series -> Html msg) -> List (Attribute msg) -> Data -> Html msg
withData draw attributes (Data value) =
    draw
        (attributes ++ [ Attribute (\config -> { config | categories = value.categories, dates = value.dates }) ])
        value.series


{-| A donut from a `Remote`, with every state of `lineRemote`.

    Chart.donutRemote [ Chart.centerCaption "orders", Chart.onRetry ReloadStatuses ]
        (Remote.map (List.map (\s -> Chart.segment s.name s.count)) model.statuses)

-}
donutRemote : List (Attribute msg) -> Remote (List Segment) -> Html msg
donutRemote =
    remoteWith donut []


{-| A gauge from a `Remote`: the skeleton while it loads, the problem with "Try
again" when it failed, and the value (dimmed while it is refreshed, with "Old data
from 14:05" when the last refresh failed).

    Chart.gaugeRemote [ Chart.centerCaption "of capacity", Chart.onRetry Reload ]
        (Remote.map .utilization model.warehouse)

-}
gaugeRemote : List (Attribute msg) -> Remote Float -> Html msg
gaugeRemote =
    remoteWith gauge 0


{-| A meter from a `Remote`, with every state of `gaugeRemote`.

    Chart.meterRemote [ Chart.title "Warehouse fill", Chart.onRetry Reload ]
        (Remote.map .fill model.warehouse)

-}
meterRemote : List (Attribute msg) -> Remote Float -> Html msg
meterRemote =
    remoteWith meter 0


{-| A sparkline from a `Remote`: a skeleton line while it loads, a dash with the
problem as its name when it failed (there is no room for "Try again"), and the line,
dimmed while it is refreshed. Old data says so in its name.

    Chart.sparklineRemote [ Chart.ariaLabel "Orders, last 7 days" ]
        (Remote.map .lastWeek model.orders)

-}
sparklineRemote : List (Attribute msg) -> Remote (List Float) -> Html msg
sparklineRemote =
    remoteWith sparkline []
