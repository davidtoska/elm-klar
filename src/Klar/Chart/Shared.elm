module Klar.Chart.Shared exposing (..)

{-| Shared chart state shells, category interaction, legends, accessible data tables and plot pieces.
-}

import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Events
import Klar.Chart.Config exposing (area, ariaLabel, categories, centerCaption, centerLabel, configure, dates, description, emptyText, height, heightOf, hideLegend, horizontal, id, includeZero, legend, locale, maxLabels, onRetry, onSelect, pointsOnHover, range, selectable, settings, showLegend, stacked, thresholds, title, tone, unit, valueFormat, valueLabels, width, yMax, yMin, zoneToneFor)
import Klar.Chart.Data exposing (byCategory, byDate, dashed, noData, segment, segmentSlot, segmentTone, series, seriesMaybe, withSlot, withTone)
import Klar.Chart.Numbers exposing (compact, dropTrailingZeros, firstJust, formatLabel, formatTick, formatValue, isWhole, missingOr, num, pct, percentText, roundTo, sanitize, smartFormat, stepDecimals, tickGutter, trimFraction)
import Klar.Chart.Texts exposing (summaryLine, texts)
import Klar.Chart.Types exposing (Attribute(..), Axis, Config, Data(..), LegendItem, PSeries, Piece, Prepared, Segment(..), Series(..), Slice, State(..), Texts)
import Klar.EmptyState as EmptyState
import Klar.ErrorState as ErrorState
import Klar.Icon as Icon
import Klar.Internal as Internal
import Klar.Internal.Freshness as Freshness exposing (Freshness)
import Klar.Skeleton as Skeleton


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


legendIfWanted : Config msg -> String -> Prepared -> Html msg
legendIfWanted config shape prepared =
    if showLegend config (List.length prepared.series) then
        legendView shape (List.map (\s -> { label = s.name, cls = s.cls, detail = "", dashed = s.dashed, select = Nothing }) prepared.series)

    else
        Html.text ""
