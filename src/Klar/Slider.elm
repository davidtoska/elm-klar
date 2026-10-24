module Klar.Slider exposing
    ( view, viewRange, Attribute
    , min, max, step, value, onInput, onCommit, range, onRangeInput, onRangeCommit, minGap
    , unit, valueFormat, hideValue, bubble, ticks, marks
    , label, labelHidden, hint, error, errorMaybe, required, optionalText, id
    , disabled, locale
    )

{-| A slider for a number in a range, and a range slider with two thumbs.

Use when: a number in a known range that is dragged rather than typed, or a range with two thumbs.
Do not use when: the number is typed (`Klar.NumberInput`).

    import Klar.Slider as Slider

    Slider.view
        [ Slider.label "Discount"
        , Slider.min 0
        , Slider.max 50
        , Slider.step 5
        , Slider.value model.discount
        , Slider.onInput DiscountChanged
        , Slider.unit "%"
        , Slider.ticks 10
        ]

    Slider.viewRange
        [ Slider.label "Order quantity"
        , Slider.min 0
        , Slider.max 500
        , Slider.range model.minQuantity model.maxQuantity
        , Slider.onRangeInput QuantityRangeChanged
        , Slider.unit "pcs"
        ]

The value is owned by the application, as a `Float` in the model. `onInput`
(`onRangeInput` for two thumbs) is sent with every change while the thumb is
dragged, and `value` (`range`) gives the new value back. The filled part of the
track follows the thumb on its own, without any scripting. `onCommit`
(`onRangeCommit`) is sent once when the user lets go of the thumb, and for every
key press: use it for what should not happen at every pixel of a drag, such as
fetching a list filtered by the value.

    -- update: show the value while dragging, fetch when the user lets go
    PriceMoved price ->
        ( { model | maxPrice = price }, Cmd.none )

    PriceChosen price ->
        ( { model | maxPrice = price }, fetchProducts price )

The current value is written at the right end of the line above the track,
level with the label. It is not beside the track, so the tracks of sliders
stacked in a form are all as long as their field, however wide the text of
their value is (`15 %`, `20 – 65 pcs`), and a track does not change length while
the thumb is dragged. The text has as many decimals as `step` (or `min`) has, in
the number format of the `locale`, followed by the `unit`; `valueFormat` replaces
all of that. A screen reader reads the written value as well (`aria-valuetext`),
for a range slider one thumb at a time. A value that is not on the grid of
`step` (counted from `min`) is drawn and written where the browser puts the
thumb, at the nearest point of the grid; the model keeps the value it has.

Keyboard (the browser's own): arrow keys change the value by one `step`,
Page Up and Page Down by about ten percent of the range, Home and End jump to
the ends. The range slider has two focusable thumbs, named after the label with
"from" and "to" ("Order quantity, from"); they cannot pass each other (keep them
`minGap` apart if you like), and each is joined to the hint and the error
message.

Clicking the track of a range slider does nothing (only the thumbs take the
mouse), so that the two inputs never fight for the click.

A slider takes the attributes that all form controls share (`label`, `hint`,
`error`, `required` ...; see [Klar.Field](Klar-Field)). For a number that is
typed rather than dragged, use [Klar.NumberInput](Klar-NumberInput).


# Views

@docs view, viewRange, Attribute


# Range and value

@docs min, max, step, value, onInput, onCommit, range, onRangeInput, onRangeCommit, minGap


# Showing the value

@docs unit, valueFormat, hideValue, bubble, ticks, marks


# Label, hint and error

@docs label, labelHidden, hint, error, errorMaybe, required, optionalText, id


# Behavior and language

@docs disabled, locale

-}

import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Events
import Json.Decode as Decode
import Klar.Field as Field
import Klar.Format as Format
import Klar.Internal as Internal
import Klar.Locale as Locale exposing (Locale)


{-| A setting of a slider. Make them with the functions below and pass a list to
`view` or `viewRange`; later attributes win over earlier ones. Each of the two
views ignores the settings that belong to the other (`value`, `onInput` and
`onCommit` for `view`; `range`, `onRangeInput`, `onRangeCommit` and `minGap` for
`viewRange`).
-}
type Attribute msg
    = Attribute (Config msg -> Config msg)


type alias Config msg =
    { field : Field.Config
    , min : Float
    , max : Float
    , step : Float
    , value : Float
    , lower : Maybe Float
    , upper : Maybe Float
    , minGap : Float
    , onInput : Maybe (Float -> msg)
    , onCommit : Maybe (Float -> msg)
    , onRangeInput : Maybe (Float -> Float -> msg)
    , onRangeCommit : Maybe (Float -> Float -> msg)
    , disabled : Bool
    , bubble : Bool
    , showValue : Bool
    , unit : String
    , format : Maybe (Float -> String)
    , ticks : Maybe Float
    , marks : List ( Float, String )
    , locale : Locale
    }


configure : List (Attribute msg) -> Config msg
configure attributes =
    List.foldl (\(Attribute change) config -> change config)
        { field = Field.empty
        , min = 0
        , max = 100
        , step = 1
        , value = 0
        , lower = Nothing
        , upper = Nothing
        , minGap = 0
        , onInput = Nothing
        , onCommit = Nothing
        , onRangeInput = Nothing
        , onRangeCommit = Nothing
        , disabled = False
        , bubble = False
        , showValue = True
        , unit = ""
        , format = Nothing
        , ticks = Nothing
        , marks = []
        , locale = Locale.default
        }
        attributes


updateField : (Field.Config -> Field.Config) -> Attribute msg
updateField change =
    Attribute (\config -> { config | field = change config.field })



-- FIELD ATTRIBUTES


{-| The label, drawn at the left end of the line above the track. In a range
slider it names the group of the two thumbs.
-}
label : String -> Attribute msg
label text =
    updateField (Field.setLabel text)


{-| Keep the label for screen readers only.
-}
labelHidden : Attribute msg
labelHidden =
    updateField Field.setLabelHidden


{-| A line of help under the slider, joined to it with `aria-describedby` so a
screen reader reads it with the slider.
-}
hint : String -> Attribute msg
hint text =
    updateField (Field.setHint text)


{-| Shows an error message in red under the slider and marks it invalid: the
filled part of the track and the thumb turn red and the slider (each thumb of a
range slider) gets `aria-invalid`. Screen readers read the message when it
appears.
-}
error : String -> Attribute msg
error text =
    updateField (Field.setError (Just text))


{-| Like `error`, for a message that may not be there: `Nothing` shows no
error. It goes well with `Validate.errorFor`.

    Slider.errorMaybe (Validate.errorFor "order-discount" errors)

-}
errorMaybe : Maybe String -> Attribute msg
errorMaybe maybe =
    updateField (Field.setError maybe)


{-| Marks the slider as required with a `*` after the label. It is a visual mark
and checks nothing: ARIA has no required state for a slider, so a screen reader
does not hear it. Say so in the `hint` too.
-}
required : Attribute msg
required =
    updateField (Field.setRequired True)


{-| Text shown after the label of a slider that is not required, such as
"(optional)". There is no built-in text: without this, an optional slider gets
no mark.
-}
optionalText : String -> Attribute msg
optionalText text =
    updateField (Field.setOptionalText text)


{-| The DOM id of the slider (of the lower thumb in a range slider, whose upper
thumb gets `<id>-upper` and whose group gets `<id>-group`). Give it one when an
error summary should move focus to the slider; without it the id is made from the
label, so give sliders that share a label an id each.
-}
id : String -> Attribute msg
id value_ =
    updateField (Field.setId value_)



-- CONTROL ATTRIBUTES


{-| The smallest value. The default is 0.
-}
min : Float -> Attribute msg
min number =
    Attribute (\config -> { config | min = number })


{-| The largest value. The default is 100. A `max` below `min` counts as `min`.
-}
max : Float -> Attribute msg
max number =
    Attribute (\config -> { config | max = number })


{-| How far one arrow key press moves the thumb. It is also the grid the value
snaps to, counted from `min`, and it sets the number of decimals that are
written (a step of 0.25 gives two, at most four; a `min` with more decimals gives
its own). The default is 1; a step of 0 or less counts as 1.
-}
step : Float -> Attribute msg
step amount =
    Attribute (\config -> { config | step = amount })


{-| The value of a single slider (`view`). The default is 0. A value outside
`min` and `max` is shown at the nearer end, and a value off the grid of `step` at
the nearest point of the grid, as the browser draws the thumb.
-}
value : Float -> Attribute msg
value number =
    Attribute (\config -> { config | value = number })


{-| The message sent when the user moves the thumb of a single slider, with the
mouse, a finger or the keyboard (`view`). It gets the new value and is sent at
every change while the thumb is dragged, not only at the end. Store the value and
give it back with `value`.

    Slider.onInput DiscountChanged

-}
onInput : (Float -> msg) -> Attribute msg
onInput toMsg =
    Attribute (\config -> { config | onInput = Just toMsg })


{-| The message sent when the user has chosen a value with a single slider
(`view`): once when the thumb is let go after a drag or a click on the track, and
after every key press. It gets the new value. Use it for work that should not
happen at every step of a drag, such as a request to the server; `onInput` still
keeps the shown value up to date.

    Slider.onCommit PriceChosen

-}
onCommit : (Float -> msg) -> Attribute msg
onCommit toMsg =
    Attribute (\config -> { config | onCommit = Just toMsg })


{-| The lower and the upper value of a range slider, in that order
(`viewRange`). Without it the thumbs sit at `min` and `max`.
-}
range : Float -> Float -> Attribute msg
range low high =
    Attribute (\config -> { config | lower = Just low, upper = Just high })


{-| The message sent when either thumb of a range slider moves (`viewRange`). It
gets the new lower value and the new upper value, already limited to `min` and
`max` and kept `minGap` apart; store both and give them back with `range`.

    Slider.onRangeInput QuantityRangeChanged

-}
onRangeInput : (Float -> Float -> msg) -> Attribute msg
onRangeInput toMsg =
    Attribute (\config -> { config | onRangeInput = Just toMsg })


{-| Like `onCommit`, for a range slider (`viewRange`): sent once when either thumb
is let go, and after every key press. It gets the lower and the upper value,
limited and kept apart like those of `onRangeInput`.

    Slider.onRangeCommit QuantityRangeChosen

-}
onRangeCommit : (Float -> Float -> msg) -> Attribute msg
onRangeCommit toMsg =
    Attribute (\config -> { config | onRangeCommit = Just toMsg })


{-| The least distance between the two thumbs of a range slider (`viewRange`).
The default is 0, which lets the thumbs meet.
-}
minGap : Float -> Attribute msg
minGap amount =
    Attribute (\config -> { config | minGap = Basics.max 0 amount })


{-| A text written after the value, such as `%` or `kg`, with a non-breaking
space in between. A range slider writes it once, after the second number
("20 – 65 pcs"). There is no unit by default; `valueFormat` replaces it.
-}
unit : String -> Attribute msg
unit text =
    Attribute (\config -> { config | unit = text })


{-| Your own way of writing a value. It replaces the number format and the unit,
and its text is also what a screen reader reads (`aria-valuetext`). A range
slider formats both numbers with it and joins them with a dash.

    Slider.valueFormat
        (\level ->
            if level < 34 then
                "Low"

            else if level < 67 then
                "Medium"

            else
                "High"
        )

-}
valueFormat : (Float -> String) -> Attribute msg
valueFormat toText =
    Attribute (\config -> { config | format = Just toText })


{-| Shows the value in a small bubble above the thumb while the slider is
hovered, focused or dragged. A range slider shows both values together over the
middle of the filled part. The bubble is for the eyes only (`aria-hidden`).
-}
bubble : Attribute msg
bubble =
    Attribute (\config -> { config | bubble = True })


{-| Does not write the value as text above the track. Combine it with `bubble`,
`ticks` or `marks`, or use it where the value is clear without it. A slider with
neither a label nor a value has no line above the track at all.
-}
hideValue : Attribute msg
hideValue =
    Attribute (\config -> { config | showValue = False })


{-| A small tick mark every this many units, counted from `min`. Nothing is
drawn when the number is not positive or when the range would hold more than 100
steps of it. The ticks are decoration (`aria-hidden`).
-}
ticks : Float -> Attribute msg
ticks every =
    Attribute (\config -> { config | ticks = Just every })


{-| Labelled marks under the track, each a position on the scale and its text:
`[ ( 0, "Low" ), ( 50, "Medium" ), ( 100, "High" ) ]`. Screen readers do not
read the marks (`aria-hidden`); `valueFormat` can say the same in words.
-}
marks : List ( Float, String ) -> Attribute msg
marks value_ =
    Attribute (\config -> { config | marks = value_ })


{-| Dims the slider and makes it unchangeable and unfocusable. The default is
`False`.
-}
disabled : Bool -> Attribute msg
disabled value_ =
    Attribute (\config -> { config | disabled = value_ })


{-| The language of the built-in text: the "from" and "to" that name the thumbs
of a range slider for screen readers, and the decimal and thousands separators
of the written value. The default is `Locale.default`, which is English.
-}
locale : Locale -> Attribute msg
locale value_ =
    Attribute (\config -> { config | locale = value_ })



-- VIEW


{-| A slider with one thumb, for a number from `min` to `max`. It uses `value`,
`onInput` and `onCommit`, and ignores the settings of a range slider.

    Slider.view
        [ Slider.label "Discount"
        , Slider.max 50
        , Slider.value model.discount
        , Slider.onInput DiscountChanged
        , Slider.unit "%"
        ]

-}
view : List (Attribute msg) -> Html msg
view attributes =
    let
        config =
            configure attributes

        field =
            ensureId "slider" config

        ( low, high ) =
            bounds config

        -- Where the browser puts the thumb: in the range and on the step grid.
        current =
            onGrid config (clampTo low high config.value)

        spoken =
            formatValue config current
    in
    Field.viewGroup field
        (Html.div [ Internal.cls (fieldClasses config) ]
            (viewHead config field (Just field.id) spoken
                ++ [ Html.div
                        [ Internal.cls (sliderClasses config False)
                        , Internal.styleVars [ ( "--klar-pct", String.fromFloat (fraction low high current) ) ]
                        ]
                        [ Html.div [ Internal.cls [ "klar-slider__body" ] ]
                            (Html.input
                                (sliderAttributes field
                                    ++ [ Internal.cls [ "klar-slider__input" ]
                                       , Attr.type_ "range"
                                       , Attr.min (String.fromFloat low)
                                       , Attr.max (String.fromFloat high)
                                       , Attr.step (String.fromFloat (safeStep config.step))
                                       , Attr.value (String.fromFloat current)
                                       , Attr.disabled config.disabled
                                       , Attr.attribute "aria-valuetext" spoken
                                       , Internal.attrMaybe (\toMsg -> onFloat "input" toMsg) config.onInput
                                       , Internal.attrMaybe (\toMsg -> onFloat "change" toMsg) config.onCommit
                                       ]
                                )
                                []
                                :: viewBubble config False spoken
                                ++ viewScale config low high
                            )
                        ]
                   ]
            )
        )


{-| The line above the track: the label on the left and the value on the right.
The value is not beside the track, so every slider's track is as long as its
field, however wide the text of the value is (and it does not change length
while the thumb is dragged). `labelFor` is the id of the input for a single
slider; a range slider's label names its group instead.
-}
viewHead : Config msg -> Field.Config -> Maybe String -> String -> List (Html msg)
viewHead config field labelFor valueText =
    let
        isRange =
            labelFor == Nothing

        labelClasses =
            [ "klar-field__label"
            , if field.labelHidden then
                "klar-sr-only"

              else
                ""
            ]

        labelBody text =
            [ Html.text text
            , Internal.viewIf field.required
                (Html.span [ Internal.cls [ "klar-field__required" ], Attr.attribute "aria-hidden" "true" ] [ Html.text "*" ])
            , case ( field.required, field.optionalText ) of
                ( False, Just optional ) ->
                    Html.span [ Internal.cls [ "klar-field__optional" ] ] [ Html.text optional ]

                _ ->
                    Html.text ""
            ]

        labelNode =
            case ( field.label, labelFor ) of
                ( Just text, Just inputId ) ->
                    Html.label
                        [ Internal.cls labelClasses
                        , Attr.id (Field.labelId field)
                        , Attr.for inputId
                        ]
                        (labelBody text)

                ( Just text, Nothing ) ->
                    Html.span
                        [ Internal.cls labelClasses
                        , Attr.id (Field.labelId field)
                        ]
                        (labelBody text)

                ( Nothing, _ ) ->
                    Html.text ""

        visibleLabel =
            field.label /= Nothing && not field.labelHidden

        valueNode =
            if config.showValue then
                Html.span
                    [ Internal.cls
                        [ "klar-slider__value"
                        , if isRange then
                            "klar-slider__value--range"

                          else
                            ""
                        , "klar-tabular"
                        ]
                    ]
                    [ Html.text valueText ]

            else
                Html.text ""
    in
    if field.label == Nothing && not config.showValue then
        []

    else
        [ Html.div
            [ Internal.cls
                [ "klar-slider-field__head"
                , if visibleLabel then
                    ""

                  else
                    "klar-slider-field__head--end"
                ]
            ]
            [ labelNode, valueNode ]
        ]


{-| A slider with two thumbs, for a lower and an upper value from `min` to
`max`. It uses `range`, `onRangeInput`, `onRangeCommit` and `minGap`, and ignores
`value`, `onInput` and `onCommit`. The two thumbs are inputs of their own, named
after the label with "from" and "to" for screen readers ("Order quantity, from"),
inside a group named by the label; each thumb is joined to the hint and the error
message.

    Slider.viewRange
        [ Slider.label "Order quantity"
        , Slider.max 500
        , Slider.range model.minQuantity model.maxQuantity
        , Slider.onRangeInput QuantityRangeChanged
        , Slider.minGap 10
        ]

-}
viewRange : List (Attribute msg) -> Html msg
viewRange attributes =
    let
        config =
            configure attributes

        field =
            ensureId "range" config

        ( low, high ) =
            bounds config

        gap =
            Basics.min config.minGap (high - low)

        first =
            clampTo low high (Maybe.withDefault low config.lower)

        second =
            clampTo low high (Maybe.withDefault high config.upper)

        lower =
            Basics.min first (second - gap) |> Basics.max low

        upper =
            Basics.max second (lower + gap) |> Basics.min high

        -- Where the browser puts the thumbs: on the step grid.
        lowerShown =
            onGrid config lower

        upperShown =
            onGrid config upper

        lowerText =
            formatValue config lowerShown

        upperText =
            formatValue config upperShown

        both =
            rangeText config lowerShown upperShown

        -- What a move of one thumb sends: the other one stays, and they keep
        -- `minGap` apart.
        withLower v =
            ( Basics.min v (upper - gap) |> Basics.max low, upper )

        withUpper v =
            ( lower, Basics.max v (lower + gap) |> Basics.min high )

        rangeHandlers toPair =
            [ Internal.attrMaybe (\toMsg -> onFloat "input" (\v -> pairTo toMsg (toPair v))) config.onRangeInput
            , Internal.attrMaybe (\toMsg -> onFloat "change" (\v -> pairTo toMsg (toPair v))) config.onRangeCommit
            ]

        -- "Order quantity, from": the thumbs are named after the label, so a
        -- list of the form controls tells them apart from other sliders.
        thumbName word =
            case field.label of
                Just text ->
                    text ++ ", " ++ String.toLower word

                Nothing ->
                    word

        midpoint =
            (low + high) / 2

        lowerInFront =
            lower >= upper && lower > midpoint

        lowerLabel =
            Locale.pick config.locale { nb = "Fra", en = "From" }

        upperLabel =
            Locale.pick config.locale { nb = "Til", en = "To" }

        groupId =
            field.id ++ "-group"

        labelId =
            field.id ++ "-label"

        -- The wrapper has the role `group`, which cannot be invalid or required
        -- in ARIA. Each thumb (a slider) carries aria-invalid and is joined to
        -- the hint and the error message, so tabbing from one thumb to the other
        -- reads them too.
        thumbAttributes =
            [ Attr.type_ "range"
            , Attr.min (String.fromFloat low)
            , Attr.max (String.fromFloat high)
            , Attr.step (String.fromFloat (safeStep config.step))
            , Attr.disabled config.disabled
            , invalidAttribute field
            ]
                ++ Field.describedByAttributes field
    in
    Field.viewGroup field
        (Html.div
            [ Attr.id groupId
            , Internal.cls (fieldClasses config)
            , Attr.attribute "role" "group"
            , Internal.attrIf (field.label /= Nothing) (Attr.attribute "aria-labelledby" labelId)
            ]
            (viewHead config field Nothing both
                ++ [ Html.div
                        [ Internal.cls (sliderClasses config True)
                        , Internal.styleVars
                            [ ( "--klar-lo", String.fromFloat (fraction low high lowerShown) )
                            , ( "--klar-hi", String.fromFloat (fraction low high upperShown) )
                            ]
                        ]
                        [ Html.div [ Internal.cls [ "klar-slider__body" ] ]
                            ([ Html.div [ Internal.cls [ "klar-range__track" ] ]
                                [ Html.div [ Internal.cls [ "klar-range__fill" ] ] [] ]
                             , Html.input
                                (thumbAttributes
                                    ++ [ Attr.id field.id
                                       , Internal.cls
                                            [ "klar-slider__input"
                                            , "klar-range__input"
                                            , if lowerInFront then
                                                "klar-range__input--front"

                                              else
                                                ""
                                            ]
                                       , Attr.attribute "aria-label" (thumbName lowerLabel)
                                       , Attr.value (String.fromFloat lower)
                                       , Attr.attribute "aria-valuetext" lowerText
                                       ]
                                    ++ rangeHandlers withLower
                                )
                                []
                             , Html.input
                                (thumbAttributes
                                    ++ [ Attr.id (field.id ++ "-upper")
                                       , Internal.cls
                                            [ "klar-slider__input"
                                            , "klar-range__input"
                                            , if lowerInFront then
                                                ""

                                              else
                                                "klar-range__input--front"
                                            ]
                                       , Attr.attribute "aria-label" (thumbName upperLabel)
                                       , Attr.value (String.fromFloat upper)
                                       , Attr.attribute "aria-valuetext" upperText
                                       ]
                                    ++ rangeHandlers withUpper
                                )
                                []
                             ]
                                ++ viewBubble config True both
                                ++ viewScale config low high
                            )
                        ]
                   ]
            )
        )


{-| What the input of a single slider takes from its field: the `id`, the
`aria-describedby` of the hint and the error message, and `aria-invalid`. Not
`aria-required`, which ARIA does not allow on the role `slider`.
-}
sliderAttributes : Field.Config -> List (Html.Attribute msg)
sliderAttributes field =
    Attr.id field.id
        :: Field.describedByAttributes field
        ++ [ invalidAttribute field ]


invalidAttribute : Field.Config -> Html.Attribute msg
invalidAttribute field =
    Internal.attrIf (field.error /= Nothing) (Attr.attribute "aria-invalid" "true")


fieldClasses : Config msg -> List String
fieldClasses config =
    [ "klar-slider-field"
    , if config.disabled then
        "klar-slider-field--disabled"

      else
        ""
    ]


sliderClasses : Config msg -> Bool -> List String
sliderClasses config isRange =
    [ "klar-slider"
    , if isRange then
        "klar-slider--range"

      else
        ""
    , if config.disabled then
        "klar-slider--disabled"

      else
        ""
    , if config.field.error /= Nothing then
        "klar-slider--invalid"

      else
        ""
    , if not (List.isEmpty config.marks) then
        "klar-slider--marks"

      else
        ""
    ]


{-| The value bubble. A single slider shows one over the thumb; a range
slider shows the two values together over the middle of the filled part.
-}
viewBubble : Config msg -> Bool -> String -> List (Html msg)
viewBubble config isRange text =
    if config.bubble then
        [ Html.span
            [ Internal.cls
                [ "klar-slider__bubble"
                , if isRange then
                    "klar-slider__bubble--range"

                  else
                    ""
                ]
            , Attr.attribute "aria-hidden" "true"
            ]
            [ Html.text text ]
        ]

    else
        []


viewScale : Config msg -> Float -> Float -> List (Html msg)
viewScale config low high =
    let
        tickMarks =
            case config.ticks of
                Just every ->
                    if every > 0 && (high - low) / every <= 100 then
                        List.range 0 (floor ((high - low) / every + 1.0e-9))
                            |> List.map (\i -> low + toFloat i * every)

                    else
                        []

                Nothing ->
                    []
    in
    (if List.isEmpty tickMarks then
        []

     else
        [ Html.div [ Internal.cls [ "klar-slider__ticks" ], Attr.attribute "aria-hidden" "true" ]
            (List.map
                (\at ->
                    Html.span
                        [ Internal.cls [ "klar-slider__tick" ]
                        , Internal.styleVars [ ( "--klar-at", String.fromFloat (fraction low high at) ) ]
                        ]
                        []
                )
                tickMarks
            )
        ]
    )
        ++ (if List.isEmpty config.marks then
                []

            else
                [ Html.div [ Internal.cls [ "klar-slider__marks" ], Attr.attribute "aria-hidden" "true" ]
                    (List.map
                        (\( at, text ) ->
                            Html.span
                                [ Internal.cls [ "klar-slider__mark" ]
                                , Internal.styleVars [ ( "--klar-at", String.fromFloat (fraction low high at) ) ]
                                ]
                                [ Html.text text ]
                        )
                        config.marks
                    )
                ]
           )


{-| The value of the input as a number, on the `input` event (every change while
dragging) or the `change` event (the thumb let go, or a key press).
-}
onFloat : String -> (Float -> msg) -> Html.Attribute msg
onFloat eventName toMsg =
    Events.on eventName
        (Decode.at [ "target", "value" ] Decode.string
            |> Decode.andThen
                (\text ->
                    case String.toFloat text of
                        Just number ->
                            Decode.succeed (toMsg number)

                        Nothing ->
                            Decode.fail "not a number"
                )
        )



-- HELPERS


pairTo : (Float -> Float -> msg) -> ( Float, Float ) -> msg
pairTo toMsg ( lower, upper ) =
    toMsg lower upper


bounds : Config msg -> ( Float, Float )
bounds config =
    ( config.min, Basics.max config.min config.max )


{-| Where the browser draws a value of a range input: the nearest point of the
grid of `step` that starts at `min` (the greater one of two that are as near),
never past the last point of the grid at or below `max`. The value is already in
the range.
-}
onGrid : Config msg -> Float -> Float
onGrid config number =
    let
        ( low, high ) =
            bounds config

        stepSize =
            safeStep config.step

        lastStep =
            toFloat (floor ((high - low) / stepSize + 1.0e-9))

        steps =
            toFloat (round ((number - low) / stepSize))
    in
    low + clampTo 0 lastStep steps * stepSize


{-| As many decimals as the step has, or as `min` has when that has more (a
grid from 0.5 in steps of 1 is 0.5, 1.5 ...), at most four.
-}
placesOf : Config msg -> Int
placesOf config =
    Basics.max (decimalPlaces (safeStep config.step)) (decimalPlaces config.min)


fraction : Float -> Float -> Float -> Float
fraction low high number =
    if high <= low then
        0

    else
        clampTo 0 1 ((number - low) / (high - low))


clampTo : Float -> Float -> Float -> Float
clampTo low high number =
    Basics.max low (Basics.min high number)


safeStep : Float -> Float
safeStep amount =
    if amount > 0 then
        amount

    else
        1


formatValue : Config msg -> Float -> String
formatValue config number =
    case config.format of
        Just toText ->
            toText number

        Nothing ->
            Format.decimal config.locale (placesOf config) number
                ++ (if config.unit == "" then
                        ""

                    else
                        "\u{00A0}" ++ config.unit
                   )


{-| "20 – 65 pcs": the unit once, after the second number (each thumb on its own
still says "20 pcs" and "65 pcs" to a screen reader). A `valueFormat` writes both
numbers itself.
-}
rangeText : Config msg -> Float -> Float -> String
rangeText config lower upper =
    case config.format of
        Just toText ->
            toText lower ++ " – " ++ toText upper

        Nothing ->
            let
                places =
                    placesOf config
            in
            Format.decimal config.locale places lower
                ++ " – "
                ++ Format.decimal config.locale places upper
                ++ (if config.unit == "" then
                        ""

                    else
                        "\u{00A0}" ++ config.unit
                   )


decimalPlaces : Float -> Int
decimalPlaces number =
    let
        text =
            String.fromFloat (abs number)
    in
    case String.split "." text of
        [ _, fractionPart ] ->
            if String.contains "e" fractionPart then
                4

            else
                Basics.min 4 (String.length fractionPart)

        _ ->
            0


ensureId : String -> Config msg -> Field.Config
ensureId kind config =
    if config.field.id == "" then
        Field.setId
            ("klar-" ++ kind ++ "-" ++ Internal.sanitizeId (String.toLower (Maybe.withDefault kind config.field.label)))
            config.field

    else
        config.field
