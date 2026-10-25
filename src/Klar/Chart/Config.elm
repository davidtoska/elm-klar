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


id : String -> Attribute msg
id value =
    Attribute (\config -> { config | id = Just value })


title : String -> Attribute msg
title text =
    Attribute (\config -> { config | title = Just text })


description : String -> Attribute msg
description text =
    Attribute (\config -> { config | description = Just text })


ariaLabel : String -> Attribute msg
ariaLabel text =
    Attribute (\config -> { config | ariaLabel = Just text })


categories : List String -> Attribute msg
categories labels =
    Attribute (\config -> { config | categories = labels, dates = [] })


dates : List Date -> Attribute msg
dates days =
    Attribute (\config -> { config | dates = days, categories = [] })


height : Int -> Attribute msg
height pixels =
    Attribute (\config -> { config | height = Just (clamp 16 1200 pixels) })


width : Int -> Attribute msg
width pixels =
    Attribute (\config -> { config | width = Just (clamp 24 1200 pixels) })


area : Attribute msg
area =
    Attribute (\config -> { config | area = True })


pointsOnHover : Attribute msg
pointsOnHover =
    Attribute (\config -> { config | pointsOnHover = True })


stacked : Attribute msg
stacked =
    Attribute (\config -> { config | stacked = True })


horizontal : Attribute msg
horizontal =
    Attribute (\config -> { config | horizontal = True })


valueLabels : Attribute msg
valueLabels =
    Attribute (\config -> { config | valueLabels = True })


legend : Attribute msg
legend =
    Attribute (\config -> { config | legend = Just True })


hideLegend : Attribute msg
hideLegend =
    Attribute (\config -> { config | legend = Just False })


yMin : Float -> Attribute msg
yMin value =
    Attribute (\config -> { config | yMin = sanitize value })


yMax : Float -> Attribute msg
yMax value =
    Attribute (\config -> { config | yMax = sanitize value })


includeZero : Attribute msg
includeZero =
    Attribute (\config -> { config | includeZero = True })


valueFormat : (Float -> String) -> Attribute msg
valueFormat format =
    Attribute (\config -> { config | valueFormat = Just format })


unit : String -> Attribute msg
unit text =
    Attribute (\config -> { config | unit = text })


settings : Settings -> Attribute msg
settings given =
    Attribute (\config -> { config | settings = given })


locale : Locale -> Attribute msg
locale value =
    Attribute (\config -> { config | locale = value })


tone : Tone -> Attribute msg
tone value =
    Attribute (\config -> { config | tone = Just value })


onRetry : msg -> Attribute msg
onRetry msg =
    Attribute (\config -> { config | onRetry = Just msg })


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


emptyText : String -> Attribute msg
emptyText text =
    Attribute (\config -> { config | emptyText = Just text })


centerLabel : String -> Attribute msg
centerLabel text =
    Attribute (\config -> { config | centerLabel = Just text })


centerCaption : String -> Attribute msg
centerCaption text =
    Attribute (\config -> { config | centerCaption = Just text })


range : Float -> Float -> Attribute msg
range low high =
    Attribute
        (\config ->
            { config
                | rangeMin = Maybe.withDefault 0 (sanitize low)
                , rangeMax = Maybe.withDefault 100 (sanitize high)
            }
        )


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
