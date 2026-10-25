# Klar.QuantityInput

A quantity with an application's own unit type, keeping exactly the number text entered until the application explicitly changes it.

Import: `import Klar.QuantityInput as Quantity` | Group: Inputs

Types: `Msg`, `Unit`, `State`, `Limits`, `Attribute`

## Signatures

```elm
view :
    (Msg -> msg)
    -> List (Attribute msg)
    -> { ids : Ids.Ids id, units : List (Unit id) }
    -> State
    -> Html msg

-- Units
type Unit id  -- opaque: no constructors are exposed
unit : id -> String -> String -> Unit id

-- State and values
type State  -- opaque: no constructors are exposed
type Msg  -- opaque: no constructors are exposed
init : String -> State
update : Msg -> State -> ( State, Cmd Msg )
raw : State -> String
selected : Ids.Ids id -> State -> Maybe id
setValue : String -> State -> State
setUnit : Ids.Ids id -> id -> State -> State
touch : State -> State
reset : State -> State
value :
    List (Attribute msg)
    -> { ids : Ids.Ids id, units : List (Unit id) }
    -> State
    -> Result String (Maybe { amount : Float, unit : id })

-- Valid limits
type Limits  -- opaque: no constructors are exposed
between : Float -> Float -> Maybe Limits
atLeast : Float -> Maybe Limits
atMost : Float -> Maybe Limits

-- Attributes
type Attribute msg  -- opaque: no constructors are exposed
label : String -> Attribute msg
labelHidden : Attribute msg
hint : String -> Attribute msg
error : String -> Attribute msg
errorMaybe : Maybe String -> Attribute msg
required : Attribute msg
optionalText : String -> Attribute msg
limits : Limits -> Attribute msg
placeholder : String -> Attribute msg
disabled : Bool -> Attribute msg
readOnly : Bool -> Attribute msg
name : String -> Attribute msg
locale : Locale.Locale -> Attribute msg
```

## Documentation

A quantity with an application's own unit type, keeping exactly the number
text entered until the application explicitly changes it.

Use when: a number must be entered together with a unit such as kg, m or percent.
Do not use when: the unit is fixed, use `Klar.NumberInput.suffixText`, or for currency use `Klar.MoneyInput`.
Quick path: `unit`, `init`, `setUnit`, `update`, `view`, `value`

    import Klar.QuantityInput as Quantity

    -- in the model: quantity : Quantity.State
    -- initial value: Quantity.init "order-weight" |> Quantity.setUnit unitIds Kilograms
    -- in update:
    QuantityMsg inner ->
        let
            ( quantity, cmd ) =
                Quantity.update inner model.quantity
        in
        ( { model | quantity = quantity }, Cmd.map QuantityMsg cmd )

    -- use the same attributes and catalogue when drawing and reading:
    Quantity.view QuantityMsg attributes catalogue model.quantity

    Quantity.value attributes catalogue model.quantity
    -- Result String (Maybe { amount : Float, unit : UnitId })

`catalogue` is `{ ids = unitIds, units = [ Quantity.unit Kilograms "Kilograms" "kg", ... ] }`.
The unit select is native: keyboard arrows, typeahead and platform accessibility
are supplied by the browser. A change of unit changes only the unit, never the
number text. The application decides whether and how to convert a measurement;
there is no implicit factor, percent scaling or dimension conversion.

`value` validates with the current attributes and catalogue, so a language change,
a new limit or a removed unit cannot leave a previously valid cached value behind.
It returns `Ok Nothing` for a blank optional quantity, a complete typed quantity
for valid input, and a localized `Err` for incomplete, invalid, out-of-range or
unavailable-unit input. A trailing decimal separator is incomplete, not silently
accepted as a whole number. Numeric parsing otherwise follows `Klar.NumberInput.parseIn`.
The number is a finite Float; use `Klar.MoneyInput` for exact currency arithmetic.

Validation is shown after blur or `touch`; `value` is strict immediately, also
before the first blur. Built-in errors are delayed during IME composition, and composing
text is never returned as a valid quantity. No blur rounding, formatting, stepping
or range clamping is performed. Limits describe the numeric amount in the selected
unit; supply different attributes when different units have different bounds.

### `view`

```elm
view :
    (Msg -> msg)
    -> List (Attribute msg)
    -> { ids : Ids.Ids id, units : List (Unit id) }
    -> State
    -> Html msg
```

The field, with a number textbox and a native unit select. Both controls keep
their DOM position while validation changes. Unit ids must be unique in the catalogue.

## Units

### `Unit`

```elm
type Unit id  -- opaque: no constructors are exposed
```

A unit with your own id, a human label and a compact symbol. Ids must be unique.

### `unit`

```elm
unit : id -> String -> String -> Unit id
```

Creates an option, for example `unit Kilograms "Kilograms" "kg"`. Percent is
an ordinary unit: an entered 25 means `{ amount = 25, unit = Percent }`, not 0.25.

## State and values

### `State`

```elm
type State  -- opaque: no constructors are exposed
```

Exact raw text, a unit key and interaction state; never contains functions.

### `Msg`

```elm
type Msg  -- opaque: no constructors are exposed
```

Internal editing messages; pass them to `update`.

### `init`

```elm
init : String -> State
```

Creates a blank quantity without choosing a unit. The string is a unique DOM id.

### `update`

```elm
update : Msg -> State -> ( State, Cmd Msg )
```

Keeps text and unit changes exactly as entered. Never converts or reformats.

### `raw`

```elm
raw : State -> String
```

Exact number text, including invalid or incomplete input.

### `selected`

```elm
selected : Ids.Ids id -> State -> Maybe id
```

The selected application's unit id, if its key decodes. Use `value` to check
that the unit still exists in the current catalogue.

### `setValue`

```elm
setValue : String -> State -> State
```

Explicitly replaces raw number text without changing its unit or formatting it.

### `setUnit`

```elm
setUnit : Ids.Ids id -> id -> State -> State
```

Explicitly selects a unit without converting or changing the number text.

### `touch`

```elm
touch : State -> State
```

Shows current validation, for example after an attempted submit.

### `reset`

```elm
reset : State -> State
```

Clears number text, unit and touched state, preserving the DOM id.

### `value`

```elm
value :
    List (Attribute msg)
    -> { ids : Ids.Ids id, units : List (Unit id) }
    -> State
    -> Result String (Maybe { amount : Float, unit : id })
```

Reads and validates using the current settings and unit catalogue. Returns
`Ok Nothing` for a blank optional input, or the complete quantity, or a localized
error. Errors include external `error`, missing units and unfinished composition.

## Valid limits

### `Limits`

```elm
type Limits  -- opaque: no constructors are exposed
```

A valid finite numeric interval. Construct one with `between`, `atLeast` or `atMost`.

### `between`

```elm
between : Float -> Float -> Maybe Limits
```

Inclusive finite bounds. Returns `Nothing` for reversed bounds or NaN/infinity.

### `atLeast`

```elm
atLeast : Float -> Maybe Limits
```

An inclusive lower bound. Returns `Nothing` for NaN or infinity.

### `atMost`

```elm
atMost : Float -> Maybe Limits
```

An inclusive upper bound. Returns `Nothing` for NaN or infinity.

## Attributes

### `Attribute`

```elm
type Attribute msg  -- opaque: no constructors are exposed
```

Display and validation settings. Later attributes win; no limits by default.

### `label`

```elm
label : String -> Attribute msg
```

The field label. Defaults to the localized word "Quantity".

### `labelHidden`

```elm
labelHidden : Attribute msg
```

Hides the label visually while retaining its accessible name.

### `hint`

```elm
hint : String -> Attribute msg
```

Help text shared by the number input and the unit select. None by default.

### `error`

```elm
error : String -> Attribute msg
```

An application error, also rejected by `value`. None by default.

### `errorMaybe`

```elm
errorMaybe : Maybe String -> Attribute msg
```

Sets or clears an application error. `value` rejects it immediately; it is
shown without waiting for blur. Built-in validation takes precedence when touched.

### `required`

```elm
required : Attribute msg
```

Requires both a number and a unit. Optional by default.

### `optionalText`

```elm
optionalText : String -> Attribute msg
```

Text after an optional label, for example "(optional)". None by default.

### `limits`

```elm
limits : Limits -> Attribute msg
```

Numeric limits, interpreted in the selected unit. No limits by default.

### `placeholder`

```elm
placeholder : String -> Attribute msg
```

Number input placeholder. Empty by default.

### `disabled`

```elm
disabled : Bool -> Attribute msg
```

Disables both controls. Defaults to `False`.

### `readOnly`

```elm
readOnly : Bool -> Attribute msg
```

Makes the number read only and disables changing the unit. Defaults to `False`.

### `name`

```elm
name : String -> Attribute msg
```

Native form field name for the raw number; the unit uses `<name>-unit`.
Neither name is set by default. Application submission should use `value`.

### `locale`

```elm
locale : Locale.Locale -> Attribute msg
```

Numeric parsing and built-in error language. Defaults to English.
