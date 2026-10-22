# Klar.Slider

A slider for a number in a range, and a range slider with two thumbs.

Import: `import Klar.Slider as Slider` | Group: Inputs

Types: `Attribute`

## Signatures

```elm
-- Views
type Attribute msg  -- opaque: no constructors are exposed
view : List (Attribute msg) -> Html msg
viewRange : List (Attribute msg) -> Html msg

-- Range and value
min : Float -> Attribute msg
max : Float -> Attribute msg
step : Float -> Attribute msg
value : Float -> Attribute msg
onInput : (Float -> msg) -> Attribute msg
range : Float -> Float -> Attribute msg
onRangeInput : (Float -> Float -> msg) -> Attribute msg
minGap : Float -> Attribute msg

-- Showing the value
unit : String -> Attribute msg
valueFormat : (Float -> String) -> Attribute msg
hideValue : Attribute msg
bubble : Attribute msg
ticks : Float -> Attribute msg
marks : List ( Float, String ) -> Attribute msg

-- Label, hint and error
label : String -> Attribute msg
labelHidden : Attribute msg
hint : String -> Attribute msg
error : String -> Attribute msg
errorMaybe : Maybe String -> Attribute msg
required : Attribute msg
optionalText : String -> Attribute msg
id : String -> Attribute msg

-- Behavior and language
disabled : Bool -> Attribute msg
locale : Locale.Locale -> Attribute msg
```

## Documentation

A slider for a number in a range, and a range slider with two thumbs.

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
track follows the thumb on its own, without any scripting.

The current value is written at the right end of the line above the track,
level with the label. It is not beside the track, so the tracks of sliders
stacked in a form are all as long as their field, however wide the text of
their value is (`15 %`, `20 – 65 pcs`), and a track does not change length while
the thumb is dragged. The text has as many decimals as `step` has, in the number
format of the `locale`, followed by the `unit`; `valueFormat` replaces all of
that. A screen reader reads the written value as well (`aria-valuetext`), for a
range slider one thumb at a time.

Keyboard (the browser's own): arrow keys change the value by one `step`,
Page Up and Page Down by about ten percent of the range, Home and End jump to
the ends. The range slider has two focusable thumbs, named "From" and "To"; they
cannot pass each other (keep them `minGap` apart if you like).

Clicking the track of a range slider does nothing (only the thumbs take the
mouse), so that the two inputs never fight for the click.

A slider takes the attributes that all form controls share (`label`, `hint`,
`error`, `required` ...; see [Klar.Field](Klar.Field.md)). For a number that is
typed rather than dragged, use [Klar.NumberInput](Klar.NumberInput.md).

## Views

### `Attribute`

```elm
type Attribute msg  -- opaque: no constructors are exposed
```

A setting of a slider. Make them with the functions below and pass a list to
`view` or `viewRange`; later attributes win over earlier ones. Each of the two
views ignores the settings that belong to the other (`value` and `onInput` for
`view`; `range`, `onRangeInput` and `minGap` for `viewRange`).

### `view`

```elm
view : List (Attribute msg) -> Html msg
```

A slider with one thumb, for a number from `min` to `max`. It uses `value`
and `onInput`, and ignores the settings of a range slider.

    Slider.view
        [ Slider.label "Discount"
        , Slider.max 50
        , Slider.value model.discount
        , Slider.onInput DiscountChanged
        , Slider.unit "%"
        ]

### `viewRange`

```elm
viewRange : List (Attribute msg) -> Html msg
```

A slider with two thumbs, for a lower and an upper value from `min` to
`max`. It uses `range`, `onRangeInput` and `minGap`, and ignores `value` and
`onInput`. The two thumbs are inputs of their own, named "From" and "To" for
screen readers, inside a group that carries the label, hint and error.

    Slider.viewRange
        [ Slider.label "Order quantity"
        , Slider.max 500
        , Slider.range model.minQuantity model.maxQuantity
        , Slider.onRangeInput QuantityRangeChanged
        , Slider.minGap 10
        ]

## Range and value

### `min`

```elm
min : Float -> Attribute msg
```

The smallest value. The default is 0.

### `max`

```elm
max : Float -> Attribute msg
```

The largest value. The default is 100. A `max` below `min` counts as `min`.

### `step`

```elm
step : Float -> Attribute msg
```

How far one arrow key press moves the thumb. It is also the grid the value
snaps to, counted from `min`, and it sets the number of decimals that are
written (a step of 0.25 gives two, at most four). The default is 1; a step of 0
or less counts as 1.

### `value`

```elm
value : Float -> Attribute msg
```

The value of a single slider (`view`). The default is 0. A value outside
`min` and `max` is shown at the nearer end.

### `onInput`

```elm
onInput : (Float -> msg) -> Attribute msg
```

The message sent when the user moves the thumb of a single slider, with the
mouse, a finger or the keyboard (`view`). It gets the new value and is sent at
every change while the thumb is dragged, not only at the end. Store the value and
give it back with `value`.

    Slider.onInput DiscountChanged

### `range`

```elm
range : Float -> Float -> Attribute msg
```

The lower and the upper value of a range slider, in that order
(`viewRange`). Without it the thumbs sit at `min` and `max`.

### `onRangeInput`

```elm
onRangeInput : (Float -> Float -> msg) -> Attribute msg
```

The message sent when either thumb of a range slider moves (`viewRange`). It
gets the new lower value and the new upper value, already limited to `min` and
`max` and kept `minGap` apart; store both and give them back with `range`.

    Slider.onRangeInput QuantityRangeChanged

### `minGap`

```elm
minGap : Float -> Attribute msg
```

The least distance between the two thumbs of a range slider (`viewRange`).
The default is 0, which lets the thumbs meet.

## Showing the value

### `unit`

```elm
unit : String -> Attribute msg
```

A text written after the value, such as `%` or `kg`, with a non-breaking
space in between. A range slider writes it once, after the second number
("20 – 65 pcs"). There is no unit by default; `valueFormat` replaces it.

### `valueFormat`

```elm
valueFormat : (Float -> String) -> Attribute msg
```

Your own way of writing a value. It replaces the number format and the unit,
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

### `hideValue`

```elm
hideValue : Attribute msg
```

Does not write the value as text above the track. Combine it with `bubble`,
`ticks` or `marks`, or use it where the value is clear without it. A slider with
neither a label nor a value has no line above the track at all.

### `bubble`

```elm
bubble : Attribute msg
```

Shows the value in a small bubble above the thumb while the slider is
hovered, focused or dragged. A range slider shows both values together over the
middle of the filled part. The bubble is for the eyes only (`aria-hidden`).

### `ticks`

```elm
ticks : Float -> Attribute msg
```

A small tick mark every this many units, counted from `min`. Nothing is
drawn when the number is not positive or when the range would hold more than 100
steps of it. The ticks are decoration (`aria-hidden`).

### `marks`

```elm
marks : List ( Float, String ) -> Attribute msg
```

Labelled marks under the track, each a position on the scale and its text:
`[ ( 0, "Low" ), ( 50, "Medium" ), ( 100, "High" ) ]`. Screen readers do not
read the marks (`aria-hidden`); `valueFormat` can say the same in words.

## Label, hint and error

### `label`

```elm
label : String -> Attribute msg
```

The label, drawn at the left end of the line above the track. In a range
slider it names the group of the two thumbs.

### `labelHidden`

```elm
labelHidden : Attribute msg
```

Keep the label for screen readers only.

### `hint`

```elm
hint : String -> Attribute msg
```

A line of help under the slider, joined to it with `aria-describedby` so a
screen reader reads it with the slider.

### `error`

```elm
error : String -> Attribute msg
```

Shows an error message in red under the slider and marks it invalid: the
filled part of the track and the thumb turn red and the slider (each thumb of a
range slider) gets `aria-invalid`. Screen readers read the message when it
appears.

### `errorMaybe`

```elm
errorMaybe : Maybe String -> Attribute msg
```

Like `error`, for a message that may not be there: `Nothing` shows no
error. It goes well with `Validate.errorFor`.

    Slider.errorMaybe (Validate.errorFor "order-discount" errors)

### `required`

```elm
required : Attribute msg
```

Marks the slider as required with a `*` after the label. It is a visual mark
and checks nothing: ARIA has no required state for a slider, so a screen reader
does not hear it. Say so in the `hint` too.

### `optionalText`

```elm
optionalText : String -> Attribute msg
```

Text shown after the label of a slider that is not required, such as
"(optional)". There is no built-in text: without this, an optional slider gets
no mark.

### `id`

```elm
id : String -> Attribute msg
```

The DOM id of the slider (of the lower thumb in a range slider, whose upper
thumb gets `<id>-upper` and whose group gets `<id>-group`). Give it one when an
error summary should move focus to the slider; without it the id is made from the
label, so give sliders that share a label an id each.

## Behavior and language

### `disabled`

```elm
disabled : Bool -> Attribute msg
```

Dims the slider and makes it unchangeable and unfocusable. The default is
`False`.

### `locale`

```elm
locale : Locale.Locale -> Attribute msg
```

The language of the built-in text: the "From" and "To" that name the thumbs
of a range slider for screen readers, and the decimal and thousands separators
of the written value. The default is `Locale.default`, which is English.
