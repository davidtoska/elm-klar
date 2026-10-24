module Klar.Stat exposing
    ( view, row
    , Attribute, label, value, int, decimal, abbreviated, money, unit, caption, icon
    , delta, change, moneyChange, deltaText, deltaLabel, lowerIsBetter, deltaTone
    , trend, trendTone
    , size, flat, onClick, id, locale, settings
    , remote, onRetry
    )

{-| A KPI tile: one number with its label, the change since last time, a short
note and optionally a trend line.

Use when: a headline number is read at a glance on a dashboard or at the top of a page.
Do not use when: there are several label and value pairs, use `Klar.DescriptionList`, or one value against a scale, use `gauge` or `meter` from `Klar.Chart`.
Quick path: `view` with `label` and a number (`int`, `decimal`, `abbreviated`, `money`); data from the backend goes in through `remote` with `onRetry`.

    import Klar.Stat as Stat

    Stat.view
        [ Stat.label "Open orders"
        , Stat.int 1284
        , Stat.delta 4.2
        , Stat.deltaLabel "vs. last week"
        , Stat.trend [ 12, 14, 13, 17, 16, 19, 21 ]
        ]

    -- delivery time: down is good
    Stat.view
        [ Stat.label "Delivery time"
        , Stat.value "14"
        , Stat.unit "days"
        , Stat.delta -8.5
        , Stat.lowerIsBetter
        ]

    -- from the backend: model.shipments is a Remote { count : Int, change : Float }
    Stat.view
        [ Stat.label "Shipments"
        , Stat.onRetry Reload
        , Stat.remote model.shipments (\s -> [ Stat.int s.count, Stat.delta s.change ])
        ]

    -- tiles side by side
    Stat.row
        [ Stat.view [ Stat.label "Orders", Stat.int 1284 ]
        , Stat.view [ Stat.label "Revenue", Stat.abbreviated 4200000, Stat.unit "USD" ]
        ]

Give the number as `int`, `decimal`, `abbreviated` or `money` and the tile writes it with the
separators of its `locale` (English by default: `1,284`, `4.2M`), or pass a
string you have formatted yourself to `value`. A long number is set in a smaller
type so that it is always written out in full.

The change is a percentage: `4.2` is shown as "+4.2%". Its color follows
direction and meaning: up is good unless the tile says `lowerIsBetter`. The arrow
and a visually hidden word ("increase" or "decrease") carry the direction, so
color is never the only signal.

A tile from the backend (`remote`) can be loading (a skeleton in place of the
number) or failed (a short message with a retry link); both keep the label so the
layout does not jump. A tile with no number at all shows a dash, and screen
readers hear "No data".
With `onClick` the whole tile is a button, so it can be reached and activated
from the keyboard (except while it shows a failure: then it is a plain block, and
only its retry button is a control).


# Views

@docs view, row


# Content

@docs Attribute, label, value, int, decimal, abbreviated, money, unit, caption, icon


# Change since last time

@docs delta, change, moneyChange, deltaText, deltaLabel, lowerIsBetter, deltaTone


# Trend

@docs trend, trendTone


# Look and behavior

@docs size, flat, onClick, id, locale, settings


# Data from the backend

@docs remote, onRetry

-}

import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Events
import Klar.Button as Button
import Klar.Chart as Chart
import Klar.Format as Format
import Klar.Icon as Icon exposing (Icon)
import Klar.Internal as Internal
import Klar.Internal.Freshness as Freshness exposing (Freshness)
import Klar.Locale as Locale exposing (Locale)
import Klar.Money as Money exposing (Money)
import Klar.Remote as Remote exposing (Problem, Remote)
import Klar.Settings as Settings exposing (Settings)
import Klar.Skeleton as Skeleton
import Klar.Theme as Theme exposing (Size(..), Tone(..))


{-| A setting of a tile. Make them with the functions below and pass a list to
`view`; later attributes win over earlier ones.
-}
type Attribute msg
    = Attribute (Config msg -> Config msg)


type Number
    = Raw String
    | Whole Int
    | Fixed Int Float
    | Compact Float
    | Amount Money


type State
    = Ready
    | Busy
    | Failed Problem


type alias Config msg =
    { label : String
    , value : Maybe Number
    , unit : Maybe String
    , delta : Maybe Float
    , deltaText : Maybe String
    , deltaLabel : Maybe String
    , deltaTone : Maybe Tone
    , lowerIsBetter : Bool
    , caption : Maybe String
    , trend : List Float
    , trendTone : Tone
    , icon : Maybe Icon
    , size : Size
    , flat : Bool
    , onClick : Maybe msg
    , onRetry : Maybe msg
    , id : Maybe String
    , busy : Bool
    , failure : Maybe Problem
    , freshness : Freshness
    , locale : Locale
    , settings : Settings
    }


configure : List (Attribute msg) -> Config msg
configure attributes =
    List.foldl (\(Attribute apply) config -> apply config)
        { label = ""
        , value = Nothing
        , unit = Nothing
        , delta = Nothing
        , deltaText = Nothing
        , deltaLabel = Nothing
        , deltaTone = Nothing
        , lowerIsBetter = False
        , caption = Nothing
        , trend = []
        , trendTone = Primary
        , icon = Nothing
        , size = Medium
        , flat = False
        , onClick = Nothing
        , onRetry = Nothing
        , id = Nothing
        , busy = False
        , failure = Nothing
        , freshness = Freshness.Fresh
        , locale = Locale.default
        , settings = Settings.default
        }
        attributes



-- ATTRIBUTES


{-| What the number is, in sentence case and without a colon: "Open orders". It
is the heading of the tile and stays on one line; a long label is cut with an
ellipsis and its full text is the tooltip. Default: empty.
-}
label : String -> Attribute msg
label text =
    Attribute (\config -> { config | label = text })


{-| The number as text that you have formatted yourself: `"1,284"`, `"87%"`,
`"14.5"`. To let the tile format it with its `locale`, use `int`, `decimal`,
`abbreviated` or `money` instead. Without any of them the tile shows a dash.
-}
value : String -> Attribute msg
value text =
    Attribute (\config -> { config | value = Just (Raw text) })


{-| A whole number, written with the thousands separator of the tile's `locale`:
`1284` is "1,284" in English.
-}
int : Int -> Attribute msg
int n =
    Attribute (\config -> { config | value = Just (Whole n) })


{-| A number with a fixed count of decimals, in the decimal and thousands
separators of the tile's `locale`: `decimal 1 14.53` is "14.5" in English. The
number is rounded, not cut. A number that is not finite (NaN or infinity) is
shown as an en dash.
-}
decimal : Int -> Float -> Attribute msg
decimal decimals n =
    Attribute (\config -> { config | value = Just (Fixed decimals n) })


{-| An amount of money, written with the symbol of its currency in the conventions
of the tile's `locale` (`$1,234.50` in English, `1 234,50 kr` in Norwegian), exactly
as `Money.toSymbolString` writes it. Use it instead of formatting the amount
yourself, so that money stays `Klar.Money` all the way to the screen. A symbol can
stand for several currencies (`kr`): where more than one is on the page, give the
code with `value (Money.toString locale amount)`.
-}
money : Money -> Attribute msg
money amount =
    Attribute (\config -> { config | value = Just (Amount amount) })


{-| A number that shortens itself when it is large: `12900` stays "12,900", but
`4200000` becomes "4.2M". Millions are written "M", billions "B" and trillions
"T" (English). Below a million the number is written in full, with at most one
decimal. A number that is not finite (NaN or infinity) is shown as an en dash.
-}
abbreviated : Float -> Attribute msg
abbreviated n =
    Attribute (\config -> { config | value = Just (Compact n) })


{-| A unit written after the number, smaller and muted: "days", "USD", "%".
-}
unit : String -> Attribute msg
unit text =
    Attribute (\config -> { config | unit = Just text })


{-| The change since last time, as a percentage: `4.2` is shown as "+4.2%" and
`-8` as "−8%" (with a true minus sign), rounded to one decimal. The sign picks the arrow and, together
with `lowerIsBetter`, the color. A change smaller than 0.05 counts as unchanged
and gets a dash. A value that is not a number (NaN or infinity) shows no change.
-}
delta : Float -> Attribute msg
delta percent =
    Attribute
        (\config ->
            { config
                | delta =
                    if isNaN percent || isInfinite percent then
                        Nothing

                    else
                        Just percent
            }
        )


{-| The change from a previous value to the current one, worked out for you: the
same as `delta` with the percentage `(current - previous) / |previous| * 100`. When
the previous value is 0 there is no percentage: two zeros are unchanged (a dash),
and from 0 to anything else no change is shown (use `deltaText "new"` to say so),
never `NaN` or infinity.

    Stat.change { current = 3, previous = 0 } -- no change shown

    Stat.change { current = 150, previous = 120 } -- +25%

-}
change : { current : Float, previous : Float } -> Attribute msg
change values =
    if values.previous == 0 then
        if values.current == 0 then
            delta 0

        else
            Attribute identity

    else
        delta ((values.current - values.previous) / abs values.previous * 100)


{-| The change between two amounts of money, as a percentage, worked out in minor
units: the same as `change`, and nothing is shown when the two are in different
currencies (a percentage of two currencies means nothing) or the previous amount
is zero.

    Stat.moneyChange { current = stockValueNow, previous = stockValueLastWeek }

-}
moneyChange : { current : Money, previous : Money } -> Attribute msg
moneyChange values =
    if Money.currencyOf values.current == Money.currencyOf values.previous then
        change
            { current = toFloat (Money.toMinor values.current)
            , previous = toFloat (Money.toMinor values.previous)
            }

    else
        Attribute identity


{-| The change as text of your own: "+12 orders". Pair it with `delta` to set
the arrow and the color; on its own the text is shown in neutral gray, without an
arrow.
-}
deltaText : String -> Attribute msg
deltaText text =
    Attribute (\config -> { config | deltaText = Just text })


{-| What the change is measured against: "vs. last week". It follows the change
and is only shown when there is one (`delta` or `deltaText`).
-}
deltaLabel : String -> Attribute msg
deltaLabel text =
    Attribute (\config -> { config | deltaLabel = Just text })


{-| Says that a decrease is the good direction, as with delivery times, error
rates and costs: a falling number is then green and a rising one red.
-}
lowerIsBetter : Attribute msg
lowerIsBetter =
    Attribute (\config -> { config | lowerIsBetter = True })


{-| Overrides the color of the change, whatever its direction. `Neutral` is gray,
`Success`, `Warning` and `Danger` are green, amber and red. The `Tone` type is
in [Klar.Theme](Klar-Theme).
-}
deltaTone : Tone -> Attribute msg
deltaTone value_ =
    Attribute (\config -> { config | deltaTone = Just value_ })


{-| A line of explanation under the number and its change: "Excluding returns".
-}
caption : String -> Attribute msg
caption text =
    Attribute (\config -> { config | caption = Just text })


{-| A small trend line under the tile, with the last values oldest first; about
12 is plenty. Nothing is drawn for fewer than two values. The line is a
`sparkline` from [Klar.Chart](Klar-Chart), and its accessible name is the label
followed by "trend".
-}
trend : List Float -> Attribute msg
trend values =
    Attribute (\config -> { config | trend = values })


{-| The color of the trend line. The default is `Primary` (blue).
-}
trendTone : Tone -> Attribute msg
trendTone value_ =
    Attribute (\config -> { config | trendTone = value_ })


{-| A small icon at the right end of the label line.
-}
icon : Icon -> Attribute msg
icon value_ =
    Attribute (\config -> { config | icon = Just value_ })


{-| The size of the number: `Small` (20px), `Medium` (26px, the default) or
`Large` (34px). The `Size` type is in [Klar.Theme](Klar-Theme). Without it the
size follows the density of the application (`Klar.Settings`): 20px when compact, 26px
when normal, 30px when comfortable.
-}
size : Size -> Attribute msg
size value_ =
    Attribute (\config -> { config | size = value_ })


{-| No border and no background, for a tile that sits inside a card or another
bordered container. Tiles in a `row` are already drawn without a border of their
own.
-}
flat : Attribute msg
flat =
    Attribute (\config -> { config | flat = True })


{-| Makes the whole tile a button that sends this message when it is clicked or
activated with the keyboard: for drilling down into the numbers. Without it the
tile is a plain block.

A tile that shows a failure is a plain block too, whatever `onClick` says: its
"Try again" button must not sit inside another button, and there is nothing to
drill down into. The tile is a button again when the data is back.

-}
onClick : msg -> Attribute msg
onClick msg =
    Attribute (\config -> { config | onClick = Just msg })


{-| The message sent by the "Try again" link in the failure state. The link is
only shown when the problem is worth retrying (see `Klar.Remote.isRetryable` in
[Klar.Remote](Klar-Remote)).
-}
onRetry : msg -> Attribute msg
onRetry msg =
    Attribute (\config -> { config | onRetry = Just msg })


{-| The DOM id of the tile. A tile that is not a button can then take focus from a
command in every state (loading, failed, old data, drawn): the "Try again" link is
replaced when the request starts again and focus would fall back to the page, so
call [`Klar.focus`](Klar#focus) with this id in the same `update`
branch. The id must be unique on the page.
-}
id : String -> Attribute msg
id domId =
    Attribute (\config -> { config | id = Just domId })


{-| Takes the content of the tile from a `Remote`. While the data is `NotAsked`
or `Loading` the tile shows a skeleton, on `Failed` it shows the problem, and
when the data has arrived it applies the attributes that the function returns
for it. Data that is `Kept` stays on the tile: dimmed and busy while it is
refreshed, and with "Old data from 14:05" and a retry (`onRetry`) when the last
refresh failed. A tile with that retry is a plain block, like a failed tile.

    Stat.view
        [ Stat.label "Shipments"
        , Stat.onRetry ReloadShipments
        , Stat.remote model.shipments (\s -> [ Stat.int s.count, Stat.delta s.change ])
        ]

Attributes that do not depend on the data, such as `label`, belong next to
`remote` in the list. Several tiles can read the same `Remote`, each taking its
own numbers from it.

-}
remote : Remote a -> (a -> List (Attribute msg)) -> Attribute msg
remote data toAttributes =
    Attribute
        (\config ->
            let
                ( settled, freshness ) =
                    Freshness.settle data
            in
            case settled of
                Remote.Loaded payload ->
                    List.foldl (\(Attribute apply) c -> apply c) { config | freshness = freshness } (toAttributes payload)

                Remote.Failed problem ->
                    { config | failure = Just problem }

                _ ->
                    { config | busy = True }
        )


{-| The settings of the application (`Klar.Settings`): the time zone of the time in
"Old data from 14:05". Without it the time is written in UTC and ends in "UTC".

    Stat.settings model.settings

-}
settings : Settings -> Attribute msg
settings given =
    Attribute (\config -> { config | settings = given })


{-| The language of the built-in text ("Loading", "Try again" and the hidden
"increase" and "decrease") and of the number format. The default is
`Locale.default`, which is English. See [Klar.Locale](Klar-Locale).
-}
locale : Locale -> Attribute msg
locale value_ =
    Attribute (\config -> { config | locale = value_ })



-- VIEW


{-| One tile. It is a plain block, or a button when `onClick` is set (a tile that
shows a failure is always a plain block).

    Stat.view [ Stat.label "Open orders", Stat.int 1284 ]

-}
view : List (Attribute msg) -> Html msg
view attributes =
    let
        config =
            configure attributes

        -- A tile that has failed is a plain block, not a button: its retry
        -- button must not sit inside another button (nested controls are
        -- invalid, and a click on retry would also send the tile's message),
        -- and a failure has nothing to drill down into.
        state =
            case config.failure of
                Just problem ->
                    Failed problem

                Nothing ->
                    if config.busy then
                        Busy

                    else
                        Ready

        -- Old data with its own retry button is a plain block for the same reason.
        retryInside =
            case ( config.freshness, config.onRetry ) of
                ( Freshness.Stale old, Just _ ) ->
                    Remote.isRetryable old.problem

                _ ->
                    False

        clickMessage =
            case state of
                Failed _ ->
                    Nothing

                _ ->
                    if retryInside then
                        Nothing

                    else
                        config.onClick

        classNames =
            Internal.cls
                [ "klar-stat"
                , "klar-stat--" ++ Internal.sizeSuffix config.size
                , if config.flat then
                    "klar-stat--flat"

                  else
                    ""
                , if clickMessage /= Nothing then
                    "klar-stat--interactive"

                  else
                    ""
                ]

        content =
            [ Html.span [ Internal.cls [ "klar-stat__head" ] ]
                [ Html.span [ Internal.cls [ "klar-stat__label" ], Attr.title config.label ] [ Html.text config.label ]
                , Internal.viewMaybe (\glyph -> Html.span [ Internal.cls [ "klar-stat__icon" ] ] [ Icon.view glyph ]) config.icon
                ]
            , case state of
                Busy ->
                    Html.span [ Internal.cls [ "klar-stat__body" ], Attr.attribute "aria-busy" "true" ]
                        [ Html.span [ Internal.cls [ "klar-stat__skeleton" ] ] [ Skeleton.block (skeletonHeight config.size) ]
                        , Html.span [ Internal.cls [ "klar-stat__skeleton", "klar-stat__skeleton--short" ] ] [ Skeleton.line 100 ]
                        , Html.span [ Internal.cls [ "klar-sr-only" ], Attr.attribute "role" "status" ]
                            [ Html.text (Locale.pick config.locale { nb = "Laster", en = "Loading" }) ]
                        ]

                Failed problem ->
                    Html.span [ Internal.cls [ "klar-stat__body" ] ] [ viewFailure config problem ]

                Ready ->
                    Html.span [ Internal.cls [ "klar-stat__body", Freshness.className config.freshness ], Freshness.busyAttr config.freshness ]
                        [ viewValue config
                        , viewDelta config
                        , Internal.viewMaybe (\text -> Html.span [ Internal.cls [ "klar-stat__caption" ] ] [ Html.text text ]) config.caption
                        , viewTrend config
                        , Freshness.notice
                            { locale = config.locale, settings = config.settings, onRetry = config.onRetry, inline = True }
                            config.freshness
                        ]
            ]
    in
    case clickMessage of
        Just msg ->
            Html.button
                [ classNames
                , Attr.type_ "button"
                , Events.onClick msg
                , Internal.attrMaybe Attr.id config.id
                ]
                content

        Nothing ->
            Html.div
                [ classNames
                , Internal.attrMaybe Attr.id config.id
                , Internal.attrIf (config.id /= Nothing) (Attr.tabindex -1)
                ]
                content


skeletonHeight : Size -> Int
skeletonHeight value_ =
    case value_ of
        Small ->
            20

        Medium ->
            26

        Large ->
            34


viewValue : Config msg -> Html msg
viewValue config =
    case config.value of
        Nothing ->
            -- No number is a state of its own, never an empty tile.
            Html.span [ Internal.cls [ "klar-stat__figure" ] ]
                [ Html.span [ Internal.cls [ "klar-stat__value", "klar-stat__value--missing" ], Attr.attribute "aria-hidden" "true" ] [ Html.text missingNumber ]
                , Html.span [ Internal.cls [ "klar-sr-only" ] ] [ Html.text (Locale.pick config.locale { nb = "Ingen data", en = "No data" }) ]
                ]

        Just number ->
            let
                shown =
                    numberText config.locale number

                -- A long number gets a smaller type size, so that it is always
                -- written out in full: a cut-off number is a wrong number.
                lengthClass =
                    if String.length shown > 15 then
                        "klar-stat__value--xlong"

                    else if String.length shown > 11 then
                        "klar-stat__value--long"

                    else
                        ""
            in
            Html.span [ Internal.cls [ "klar-stat__figure" ] ]
                [ Html.span [ Internal.cls [ "klar-stat__value", lengthClass ], Attr.title shown ] [ Html.text shown ]
                , Internal.viewMaybe (\text -> Html.span [ Internal.cls [ "klar-stat__unit" ] ] [ Html.text text ]) config.unit
                ]


numberText : Locale -> Number -> String
numberText loc number =
    case number of
        Raw text ->
            text

        Whole n ->
            Format.int loc n

        Fixed decimals n ->
            if isFinite n then
                Format.decimal loc decimals n

            else
                missingNumber

        Compact n ->
            if isFinite n then
                compactText loc n

            else
                missingNumber

        Amount amount ->
            Money.toSymbolString loc amount


{-| An en dash: what a number is shown as when it is not finite (NaN or
infinity), instead of text such as "NaN.NaN".
-}
missingNumber : String
missingNumber =
    "–"


isFinite : Float -> Bool
isFinite n =
    not (isNaN n || isInfinite n)


compactText : Locale -> Float -> String
compactText loc n =
    let
        a =
            abs n

        scaled divisor suffix =
            trimZeros loc (Format.decimal loc 1 (n / divisor)) ++ suffix

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
    if a >= 1.0e15 then
        -- Beyond what the unit names and the number formatting can carry.
        String.fromFloat n

    else if a >= 1.0e12 then
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

    else if abs (a - toFloat (round a)) < 1.0e-9 then
        Format.int loc (round n)

    else
        trimZeros loc (Format.decimal loc 1 n)


trimZeros : Locale -> String -> String
trimZeros loc text =
    let
        separator =
            Locale.decimalSeparator loc

        dropZeros s =
            if String.endsWith "0" s then
                dropZeros (String.dropRight 1 s)

            else
                s
    in
    case String.split separator text of
        [ whole, fraction ] ->
            let
                kept =
                    dropZeros fraction
            in
            if kept == "" then
                whole

            else
                whole ++ separator ++ kept

        _ ->
            text


type Direction
    = Up
    | Down
    | Level


viewDelta : Config msg -> Html msg
viewDelta config =
    case ( config.delta, config.deltaText ) of
        ( Nothing, Nothing ) ->
            Html.text ""

        ( maybeDelta, maybeText ) ->
            let
                direction =
                    case maybeDelta of
                        Just d ->
                            if abs d < 0.05 then
                                Level

                            else if d > 0 then
                                Up

                            else
                                Down

                        Nothing ->
                            Level

                good =
                    case direction of
                        Up ->
                            not config.lowerIsBetter

                        Down ->
                            config.lowerIsBetter

                        Level ->
                            True

                tone =
                    case config.deltaTone of
                        Just t ->
                            t

                        Nothing ->
                            case direction of
                                Level ->
                                    Neutral

                                _ ->
                                    if good then
                                        Success

                                    else
                                        Danger

                text =
                    case ( maybeText, maybeDelta ) of
                        ( Just custom, _ ) ->
                            custom

                        ( Nothing, Just d ) ->
                            signedPercent config.locale d

                        ( Nothing, Nothing ) ->
                            ""

                directionWord =
                    case ( maybeDelta, direction ) of
                        ( Nothing, _ ) ->
                            ""

                        ( _, Up ) ->
                            Locale.pick config.locale { nb = "økning", en = "increase" }

                        ( _, Down ) ->
                            Locale.pick config.locale { nb = "nedgang", en = "decrease" }

                        ( _, Level ) ->
                            Locale.pick config.locale { nb = "uendret", en = "unchanged" }
            in
            Html.span [ Internal.cls [ "klar-stat__change" ] ]
                [ Html.span
                    [ Internal.cls [ "klar-stat__delta", "klar-stat__delta--" ++ Internal.toneSuffix tone ] ]
                    [ case ( maybeDelta, direction ) of
                        ( Nothing, _ ) ->
                            Html.text ""

                        ( _, Up ) ->
                            Icon.sized Icon.ExtraSmall Icon.arrowUp

                        ( _, Down ) ->
                            Icon.sized Icon.ExtraSmall Icon.arrowDown

                        ( _, Level ) ->
                            Icon.sized Icon.ExtraSmall Icon.minus
                    , Html.span [ Internal.cls [ "klar-tabular" ] ] [ Html.text text ]
                    , Internal.viewIf (directionWord /= "") (Html.span [ Internal.cls [ "klar-sr-only" ] ] [ Html.text (", " ++ directionWord) ])
                    ]
                , Internal.viewMaybe (\t -> Html.span [ Internal.cls [ "klar-stat__delta-label" ] ] [ Html.text t ]) config.deltaLabel
                ]


{-| "+4,2 %", "-8 %", "0 %".
-}
signedPercent : Locale -> Float -> String
signedPercent loc d =
    let
        rounded =
            toFloat (round (abs d * 10)) / 10

        body =
            trimZeros loc (Format.decimal loc 1 rounded) ++ Locale.pick loc { nb = "\u{00A0}%", en = "%" }
    in
    if rounded == 0 then
        body

    else if d > 0 then
        "+" ++ body

    else
        "−" ++ body


viewTrend : Config msg -> Html msg
viewTrend config =
    if List.length config.trend < 2 then
        Html.text ""

    else
        Html.span [ Internal.cls [ "klar-stat__trend" ] ]
            [ Chart.sparkline
                [ Chart.area
                , Chart.height 32
                , Chart.tone config.trendTone
                , Chart.locale config.locale
                , Chart.ariaLabel
                    (config.label ++ ": " ++ Locale.pick config.locale { nb = "utvikling", en = "trend" })
                ]
                config.trend
            ]


viewFailure : Config msg -> Problem -> Html msg
viewFailure config problem =
    Html.span [ Internal.cls [ "klar-stat__failure" ], Attr.attribute "role" "status" ]
        [ Html.span [ Internal.cls [ "klar-stat__failure-text" ] ]
            [ Icon.view Icon.errorCircle
            , Html.span [ Attr.title (Maybe.withDefault (Remote.title config.locale problem) (Remote.detail config.locale problem)) ] [ Html.text (Remote.title config.locale problem) ]
            ]
        , case ( config.onRetry, Remote.isRetryable problem ) of
            ( Just msg, True ) ->
                Button.view
                    [ Button.link
                    , Button.small
                    , Button.onClick msg
                    , Button.icon Icon.refresh
                    ]
                    (Locale.pick config.locale { nb = "Prøv igjen", en = "Try again" })

            _ ->
                Html.text ""
        ]


{-| Tiles side by side in one bordered strip, divided by hairlines. Each tile is
at least 200px wide, so they wrap onto new lines in narrow containers.

    Stat.row
        [ Stat.view [ Stat.label "Orders", Stat.int 1284 ]
        , Stat.view [ Stat.label "Customers", Stat.int 312 ]
        ]

-}
row : List (Html msg) -> Html msg
row tiles =
    Html.div [ Internal.cls [ "klar-stat-row" ] ] tiles
