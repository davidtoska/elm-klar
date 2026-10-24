module Klar.Progress exposing
    ( view, ring
    , Attribute, value, outOf, indeterminate
    , label, ariaLabel, showValue, valueText, locale
    , tone, size, striped, segments
    )

{-| Progress: a linear bar, a bar divided into steps, and a ring.

Use when: you can say how far a task has come, as a percentage or as steps such as "3 of 5".
Do not use when: there is nothing to measure and a plain wait will do (use `Klar.Spinner`).
Quick path: `view`, `ring`

    import Klar.Progress as Progress
    import Klar.Theme exposing (Tone(..))

    Progress.view [ Progress.label "Upload", Progress.value 62, Progress.showValue ]

    Progress.view [ Progress.label "Importing orders", Progress.indeterminate ]

    Progress.view
        [ Progress.label "Checkout"
        , Progress.outOf 3 5
        , Progress.segments 5
        , Progress.showValue
        ]

    Progress.ring [ Progress.value 80, Progress.tone Success, Progress.label "Done" ]

The value is a percentage from 0 to 100. Use `outOf` when you count steps, as in
"3 of 5", and `indeterminate` when the length of the task is unknown. Every
progress element is a `role="progressbar"` with `aria-valuenow` (omitted while
indeterminate) and a text alternative: the `ariaLabel`, else the `label`, else
the built-in text "Progress". The unfilled track is a light step of the bar's own
color, so the state reads across the whole length of the bar, and it keeps an
outline in Windows high contrast.

The shown value is rounded down, as a download is: 99.6 shows "99%", and only
a task that is done shows "100%" (the same holds for `aria-valuenow` and for the
filled steps of `segments`). Under reduced motion an indeterminate bar runs at
3.2s a round and a ring turns at 1.6s, the speed of every turning indicator of
Klar; stripes stand still.

Attributes are applied in order, and the last one wins: `value` replaces an
earlier `outOf` (with its "3 of 5" text), `outOf` replaces an earlier `value`,
and `indeterminate` and a value cancel each other. `valueText` is the exception:
it replaces the automatic value text wherever it stands in the list.

The ring shows its value in the middle, and the label below it when there is
room. It ignores `showValue`, `striped` and `segments`. When there is nothing to
measure, a [Klar.Spinner](Klar-Spinner) is the lighter choice.


# Views

@docs view, ring


# Value

@docs Attribute, value, outOf, indeterminate


# Text and accessibility

@docs label, ariaLabel, showValue, valueText, locale


# Look

@docs tone, size, striped, segments

-}

import Html exposing (Html)
import Html.Attributes as Attr
import Klar.Format as Format
import Klar.Internal as Internal
import Klar.Locale as Locale exposing (Locale)
import Klar.Theme as Theme exposing (Size(..), Tone(..))


{-| A setting of a progress indicator. Make them with the functions below and
pass a list to `view` or `ring`; later attributes win over earlier ones.
-}
type Attribute
    = Attribute (Config -> Config)


type alias Config =
    { value : Float
    , indeterminate : Bool
    , label : Maybe String
    , ariaLabel : Maybe String
    , showValue : Bool
    , valueText : Maybe String
    , tone : Tone
    , size : Size
    , striped : Bool
    , segments : Maybe Int
    , counts : Maybe ( Int, Int )
    , locale : Locale
    }


configure : List Attribute -> Config
configure attributes =
    List.foldl (\(Attribute change) config -> change config)
        { value = 0
        , indeterminate = False
        , label = Nothing
        , ariaLabel = Nothing
        , showValue = False
        , valueText = Nothing
        , tone = Primary
        , size = Medium
        , striped = False
        , segments = Nothing
        , counts = Nothing
        , locale = Locale.default
        }
        attributes



-- ATTRIBUTES


{-| The progress as a percentage from 0 to 100. The default is 0. A number
outside the range is clamped to it, and NaN or infinity count as 0. Also turns
`indeterminate` off, and replaces an earlier `outOf` together with its "3 of 5"
text.

    Progress.view [ Progress.value 62.5 ]

-}
value : Float -> Attribute
value percent =
    Attribute (\config -> { config | value = clampPercent percent, counts = Nothing, indeterminate = False })


{-| Sets the value from a count of steps: `outOf 3 5` is 60%. With `showValue`
the text reads "3 of 5" instead of a percentage. A total of 0 or less gives 0%,
and more done than the total fills the bar while the text still says what you
gave it ("7 of 5"), so a wrong count is not hidden. Also turns `indeterminate`
off. It replaces an earlier `value`, and a later `value` replaces it. For a bar
of steps, give `segments` the same total.
-}
outOf : Int -> Int -> Attribute
outOf done total =
    Attribute
        (\config ->
            { config
                | value =
                    if total <= 0 then
                        0

                    else
                        clampPercent (100 * toFloat done / toFloat total)
                , counts = Just ( max 0 done, max 0 total )
                , indeterminate = False
            }
        )


{-| The length of the task is unknown: an animated bar (or a spinning ring)
without a value. It has no `aria-valuenow` and shows no value text. In a bar
with `segments` no step is filled, whatever the value was; a wave of highlights
runs over the steps instead. A later `value` or `outOf` turns it off.
-}
indeterminate : Attribute
indeterminate =
    Attribute (\config -> { config | indeterminate = True })


{-| Visible text above the bar, or inside the ring. It is also the accessible
name, unless you give an `ariaLabel`. A `Small` ring is too small for the text
and only keeps the accessible name.
-}
label : String -> Attribute
label text =
    Attribute (\config -> { config | label = Just text })


{-| An accessible name for when you want no visible label. It wins over `label`
as the accessible name. When neither is given, the name is the built-in text
("Progress" in English).
-}
ariaLabel : String -> Attribute
ariaLabel text =
    Attribute (\config -> { config | ariaLabel = Just text })


{-| Shows the value as text next to the label: "62%", or "3 of 5" after `outOf`.
It is hidden while the bar is `indeterminate`. A ring always shows its value.
-}
showValue : Attribute
showValue =
    Attribute (\config -> { config | showValue = True })


{-| Replaces the value text with your own, for example "12 of 40 hours", and
turns `showValue` on. Screen readers get the same text as `aria-valuetext`.

    Progress.view [ Progress.value 30, Progress.valueText "12 of 40 hours" ]

-}
valueText : String -> Attribute
valueText text =
    Attribute (\config -> { config | valueText = Just text, showValue = True })


{-| The color: `Primary` (blue, the default), `Success`, `Warning`, `Danger` or
`Neutral` (gray). `Info` looks like `Primary`.
-}
tone : Tone -> Attribute
tone value_ =
    Attribute (\config -> { config | tone = value_ })


{-| The thickness of the bar: `Small` is 4px, `Medium` 8px and `Large` 12px. For
a ring it is the diameter: 36px, 64px and 88px. The default is `Medium`.
-}
size : Size -> Attribute
size value_ =
    Attribute (\config -> { config | size = value_ })


{-| Moving diagonal stripes on the filled part of the bar. They stand still for
users who prefer reduced motion. Bars only, and not together with `segments`.
-}
striped : Attribute
striped =
    Attribute (\config -> { config | striped = True })


{-| Divides the bar into this many equal steps (at least 2, at most 40) instead
of one continuous bar. The number of filled steps is the value rounded down to a
whole step, so the last step fills only when the task is done. An
`indeterminate` bar fills no step and shows a wave of highlights over the steps.
Bars only.

    Progress.view [ Progress.outOf 2 4, Progress.segments 4 ]

-}
segments : Int -> Attribute
segments n =
    Attribute (\config -> { config | segments = Just (clamp 2 40 n) })


{-| The language of the built-in text: the word "of" in the text of `outOf`, the
accessible name "Progress", and the number format ("62%" in English). The
default is `Locale.default`, which is English.
-}
locale : Locale -> Attribute
locale value_ =
    Attribute (\config -> { config | locale = value_ })



-- VIEW


{-| A horizontal bar. Add `showValue` for the value as text, `segments` to
divide it into steps and `striped` for stripes.
-}
view : List Attribute -> Html msg
view attributes =
    let
        config =
            configure attributes

        valueLabel =
            displayValue config
    in
    Html.div
        ([ Internal.cls
            [ "klar-progress"
            , "klar-progress--" ++ Internal.toneSuffix config.tone
            , "klar-progress--" ++ Internal.sizeSuffix config.size
            , if config.indeterminate then
                "klar-progress--indeterminate"

              else
                ""
            , if config.striped then
                "klar-progress--striped"

              else
                ""
            , if config.segments /= Nothing then
                "klar-progress--segmented"

              else
                ""
            ]
         , Internal.styleVars [ ( "--klar-p", numberString config.value ) ]
         ]
            ++ progressAria config valueLabel
        )
        [ if config.label /= Nothing || (config.showValue && not config.indeterminate) then
            Html.div [ Internal.cls [ "klar-progress__head" ] ]
                [ Html.span [ Internal.cls [ "klar-progress__label" ] ] [ Html.text (Maybe.withDefault "" config.label) ]
                , Internal.viewIf (config.showValue && not config.indeterminate)
                    (Html.span [ Internal.cls [ "klar-progress__value", "klar-tabular" ] ] [ Html.text valueLabel ])
                ]

          else
            Html.text ""
        , case config.segments of
            Just count ->
                let
                    -- An indeterminate bar does not know how far it is, so no
                    -- step is filled. A wave of highlights runs over the steps
                    -- instead; the style variables place each step in the wave.
                    filled =
                        if config.indeterminate then
                            0

                        else
                            floorSteps (toFloat count * config.value / 100)
                in
                Html.div
                    [ Internal.cls [ "klar-progress__segments" ]
                    , Internal.attrIf config.indeterminate (Internal.styleVars [ ( "--klar-segs", String.fromInt count ) ])
                    ]
                    (List.range 1 count
                        |> List.map
                            (\i ->
                                Html.span
                                    [ Internal.cls
                                        [ "klar-progress__segment"
                                        , if i <= filled then
                                            "klar-progress__segment--filled"

                                          else
                                            ""
                                        ]
                                    , Internal.attrIf config.indeterminate (Internal.styleVars [ ( "--klar-seg", String.fromInt i ) ])
                                    ]
                                    []
                            )
                    )

            Nothing ->
                Html.div [ Internal.cls [ "klar-progress__track" ] ]
                    [ Html.div [ Internal.cls [ "klar-progress__bar" ] ] [] ]
        ]


{-| A circular ring with the value in the middle, for dashboards and other tight
spaces. It uses `value`, `outOf`, `valueText`, `indeterminate`, `tone`, `size`,
`label`, `ariaLabel` and `locale`.
-}
ring : List Attribute -> Html msg
ring attributes =
    let
        config =
            configure attributes

        valueLabel =
            displayValue config
    in
    Html.div
        ([ Internal.cls
            [ "klar-progress-ring"
            , "klar-progress--" ++ Internal.toneSuffix config.tone
            , "klar-progress-ring--" ++ Internal.sizeSuffix config.size
            , if config.indeterminate then
                "klar-progress--indeterminate"

              else
                ""
            ]
         , Internal.styleVars [ ( "--klar-p", numberString config.value ) ]
         ]
            ++ progressAria config valueLabel
        )
        [ Html.span [ Internal.cls [ "klar-progress-ring__arc" ] ] []
        , Html.span [ Internal.cls [ "klar-progress-ring__center" ] ]
            [ Internal.viewIf (not config.indeterminate)
                (Html.span [ Internal.cls [ "klar-progress-ring__value", "klar-tabular" ] ] [ Html.text valueLabel ])
            , case config.label of
                Just text ->
                    Html.span [ Internal.cls [ "klar-progress-ring__label" ] ] [ Html.text text ]

                Nothing ->
                    Html.text ""
            ]
        ]


progressAria : Config -> String -> List (Html.Attribute msg)
progressAria config valueLabel =
    List.filterMap identity
        [ Just (Attr.attribute "role" "progressbar")
        , Just (Attr.attribute "aria-valuemin" "0")
        , Just (Attr.attribute "aria-valuemax" "100")
        , if config.indeterminate then
            Nothing

          else
            Just (Attr.attribute "aria-valuenow" (String.fromInt (wholePercent config.value)))
        , if config.indeterminate then
            Nothing

          else
            Just (Attr.attribute "aria-valuetext" valueLabel)
        , -- A progressbar must have a name; without a label the role is all
          -- there is to say.
          Just
            (Attr.attribute "aria-label"
                (case ( config.ariaLabel, config.label ) of
                    ( Just text, _ ) ->
                        text

                    ( Nothing, Just text ) ->
                        text

                    _ ->
                        Locale.pick config.locale { nb = "Fremdrift", en = "Progress" }
                )
            )
        ]


displayValue : Config -> String
displayValue config =
    case ( config.valueText, config.counts ) of
        ( Just text, _ ) ->
            text

        ( Nothing, Just ( done, total ) ) ->
            Format.int config.locale done
                ++ " "
                ++ Locale.pick config.locale { nb = "av", en = "of" }
                ++ " "
                ++ Format.int config.locale total

        _ ->
            Format.percent config.locale 0 (toFloat (wholePercent config.value) / 100)


{-| The whole percent to show: rounded down, so that only a task that is done
reads 100.
-}
wholePercent : Float -> Int
wholePercent percent =
    floorSteps percent


{-| Rounded down, with a margin for the error of a float: 3 \* (200 / 3) / 100 is
2, not 1.
-}
floorSteps : Float -> Int
floorSteps x =
    floor (x + 1.0e-9)


clampPercent : Float -> Float
clampPercent percent =
    if isNaN percent || isInfinite percent then
        0

    else
        clamp 0 100 percent


{-| At most two decimals, never scientific notation.
-}
numberString : Float -> String
numberString n =
    String.fromFloat (toFloat (round (n * 100)) / 100)
