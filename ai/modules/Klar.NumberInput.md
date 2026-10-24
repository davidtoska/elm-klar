# Klar.NumberInput

A number field that understands how people write numbers.

Import: `import Klar.NumberInput as NumberInput` | Group: Inputs

Types: `Msg`, `State`, `Attribute`

## Signatures

```elm
-- View
type Attribute msg  -- opaque: no constructors are exposed
view : (Msg -> msg) -> List (Attribute msg) -> State -> Html msg

-- State
type State  -- opaque: no constructors are exposed
type Msg  -- opaque: no constructors are exposed
init : String -> State
update : Msg -> State -> ( State, Cmd Msg )

-- The number
value : State -> Maybe Float
setValue : Maybe Float -> State -> State
setLimits : List (Attribute msg) -> State -> State
clear : State -> State
isValid : State -> Bool
isTouched : State -> Bool

-- Reading numbers
parse : String -> Maybe Float
parseIn : Locale.Locale -> String -> Maybe Float

-- Label, hint and error
label : String -> Attribute msg
labelHidden : Attribute msg
hint : String -> Attribute msg
error : String -> Attribute msg
errorMaybe : Maybe String -> Attribute msg
required : Attribute msg
optionalText : String -> Attribute msg

-- Range and steps
min : Float -> Attribute msg
max : Float -> Attribute msg
step : Float -> Attribute msg
noSteppers : Attribute msg

-- Display
decimals : Int -> Attribute msg
grouped : Attribute msg
prefixText : String -> Attribute msg
suffixText : String -> Attribute msg
alignRight : Attribute msg
placeholder : String -> Attribute msg
size : Theme.Size -> Attribute msg

-- State and browser hints
disabled : Bool -> Attribute msg
readOnly : Bool -> Attribute msg
name : String -> Attribute msg

-- Language
locale : Locale.Locale -> Attribute msg
```

## Documentation

A number field that understands how people write numbers. It keeps the
text the user types ("1 234,5" or "12.5") and turns it into a number, so it is
stateful.

Use when: the value is a number that people type in their own way, with limits, decimals or a unit.
Do not use when: the value is plain text (use `Klar.TextInput`).
Quick path: `init`, `update`, `view`, `value`

    import Klar.NumberInput as NumberInput

    type alias Model =
        { quantity : NumberInput.State }

    init : Model
    init =
        { quantity = NumberInput.init "line-quantity" }

    -- update
    QuantityMsg inner ->
        let
            ( quantity, cmd ) =
                NumberInput.update inner model.quantity
        in
        ( { model | quantity = quantity }, Cmd.map QuantityMsg cmd )

    -- view
    NumberInput.view QuantityMsg
        [ NumberInput.label "Quantity"
        , NumberInput.min 1
        , NumberInput.max 500
        , NumberInput.suffixText "pcs"
        ]
        model.quantity

    -- read the number
    NumberInput.value model.quantity -- Maybe Float

The `String` given to `init` is the DOM id of the input, so there is no `id`
attribute. The application reads the number with `value`, reacts to changes by
comparing `value` before and after `update`, and uses `isTouched` to show errors
only after the user has been in the field once.

The input is a text input with a numeric keyboard hint, not the browser's
`type="number"`, so what the user types is kept as typed until the field is
left.

`label`, `labelHidden`, `hint`, `error`, `errorMaybe`, `required` and
`optionalText` are the common field attributes. They come with the field
wrapper ([Klar.Field](Klar.Field.md)) that most Klar inputs are built on, so they
mean the same in all of them: the wrapper draws the label, the required marker,
the hint and the error message around the input and connects them for screen
readers (`for`, `aria-describedby`, `aria-invalid`, `aria-required`). The number
field is always inside the wrapper, so it does not move when an error comes and
goes.

**Typing.** The field reads what is typed in the language of the field
(`locale`), the way `Klar.Format` writes numbers. In English a point is the
decimal point and a comma groups thousands: `1,234.5` and `1234.5` are both
1234.5, and `1,234` is 1234. In Norwegian a comma is the decimal comma, and a
space or a point groups thousands, as people write them: `1 234,5`, `1.234,5`
and `1234,5` are all 1234.5, `10.000` is ten thousand and `1,234` is 1.234.
Spaces and apostrophes are ignored in both. The other separator than the
decimal one that cannot group thousands is read as the decimal separator: `1,5`,
`12,34` and `0,500` in English, `1.5`, `12.25` and `0.500` in Norwegian. A
number written with both separators is read with the last one as the decimal
separator, so `1.234,56` and `1,234.56` are both 1234.56. Whatever the field
reads, it shows when it is left, so a reading the user did not mean is seen at
once. See `parseIn`.

**What the field shows.** The number is written by `Klar.Format` when the user
leaves the field, with the separators of the language: a point as the decimal
point in English and a comma in Norwegian, and with `grouped` a comma between
the thousands in English (`100,000`) and a no-break space in Norwegian
(`100 000`). The range error writes its limits in the same way. A negative
number begins with the minus sign of the keyboard, so that the text can be
edited and copied into a spreadsheet.

**Errors.** Text that is not a number shows the built-in error "Must be a
number". A number outside `min` and `max` shows the built-in range error, such
as "Must be between 1 and 500 pcs" ("Must be at least ..." or "Must be at most
..." when only one limit is set, with the `suffixText` unit added). Both replace
the application's own `error` until they are fixed. While the user is typing the
messages wait until the field is left, because "-" or "1," may be the start of a
number; only text with letters in it is reported at once.

**A typed number is never changed.** A number outside `min` and `max` is never
moved into the range behind the user's back. If someone types a discount of 55 %
where the highest allowed is 50, the field keeps 55 (it does not quietly become
50), shows the built-in error "Must be between 0 and 50" once the field is left,
and `isValid` is `False` from the first keystroke until it is fixed. The same
holds for a number you put in with `setValue`. Only stepping, with the + and -
buttons or the keyboard, moves a number into the range, because the user asked
for exactly that.

`isValid` knows the limits from the attributes of the view, which the field
learns when the user focuses, types in, leaves or steps it. A number that you
put in with `setValue` before any of that, such as one loaded from a server,
needs `setLimits` once, with the same attributes you give to `view`.

**Keyboard.** Arrow up and down change the number by `step`, and with Shift (or
with page up and page down) by ten steps. Stepping keeps to the grid of the steps
from `min` (or 0), as the browser's own number field does: with a step of 5, 3
goes up to 5. Stepping never leaves `min` and `max`. A pasted number that
carries the unit of the field (`12 kg`, `USD 12`) is read without it.
Leaving the field, or pressing Enter, rounds the number to `decimals` (half
away from zero, on the decimal digits, as `Klar.Format` rounds: `1.005` is
`1.01`) and formats it; Enter still lets a surrounding form submit. Escape
throws away the text being typed and brings back the number from before; its
default is then prevented, so a dialog around the field stays open. The + and -
buttons are not in the Tab order.

**Phones.** A field whose `min` is 0 or more asks for the numeric keyboard
(`inputmode` decimal, or numeric with `decimals 0`). A field that takes
negative numbers, or has no `min`, gets the full keyboard, because the numeric
keyboard of an iPhone has no minus key; give a field for amounts that cannot be
negative `min 0`.

**Accessibility.** The input has the role `spinbutton` with `aria-valuemin`,
`aria-valuemax` and `aria-valuenow`, and an `aria-valuetext` that is the text
of the field with its unit, so a screen reader reads "1 234,5 kg" as the field
shows it and not "1234.5".

The built-in texts (the errors, the names of the + and - buttons) and the number
format (the decimal and thousands separators, in what is shown and what is read)
follow `locale`.

## View

### `Attribute`

```elm
type Attribute msg  -- opaque: no constructors are exposed
```

A setting of a number field. Make them with the functions below and pass a
list to `view`; later attributes win over earlier ones.

### `view`

```elm
view : (Msg -> msg) -> List (Attribute msg) -> State -> Html msg
```

A number field with its label, hint and error message. The first argument
wraps the field's own messages in one of yours, and the state comes last.

    NumberInput.view QuantityMsg
        [ NumberInput.label "Quantity"
        , NumberInput.min 1
        ]
        model.quantity

## State

### `State`

```elm
type State  -- opaque: no constructors are exposed
```

The state of a number field: the text being typed, the number read from it
and whether the user has been in the field. Make one with `init`, keep it in
your model and give it to `view` and `update`.

### `Msg`

```elm
type Msg  -- opaque: no constructors are exposed
```

The messages a number field sends: typing, focus, leaving the field and the
steppers. `view` wraps them with the function you give it; hand them to `update`
when they come back.

### `init`

```elm
init : String -> State
```

An empty field. The `String` is the DOM id of the input; it must be unique
on the page, because the label, hint and error point at it. To start with a
number, use `setValue`.

    NumberInput.init "line-quantity" |> NumberInput.setValue (Just 12)

### `update`

```elm
update : Msg -> State -> ( State, Cmd Msg )
```

Moves the field on after one of its messages. The `Cmd` puts the focus back
in the input after a stepper button was used, so pass it on with `Cmd.map`.

## The number

### `value`

```elm
value : State -> Maybe Float
```

The number in the field, or `Nothing` when the field is empty or the text
is not a number. A number outside `min` and `max` is returned as it was typed;
`isValid` tells whether it is inside them.

### `setValue`

```elm
setValue : Maybe Float -> State -> State
```

Shows a number, or an empty field for `Nothing`, and throws away any text
that was being typed. The number is not moved into `min` and `max`: `isValid`
tells whether it is inside the limits the field knows (see `setLimits`). It is
shown as the attributes of the view say (`decimals`, `grouped`, `locale`), so
the decimal separator matches the language.

### `setLimits`

```elm
setLimits : List (Attribute msg) -> State -> State
```

Tells the state the limits (`min` and `max`) in the given attributes, so that
`isValid` knows them before the user has touched the field. Pass the list you
give to `view`; the other attributes in it are ignored. The number is never
changed.

A field learns its limits by itself when the user focuses, types in, leaves or
steps it. This is for a number that you put in with `setValue` before that, such
as a value loaded from a server, and for limits that change while the field is
on the screen.

    quantity : List (NumberInput.Attribute Msg)
    quantity =
        [ NumberInput.label "Quantity", NumberInput.min 1, NumberInput.max 500 ]

    NumberInput.init "line-quantity"
        |> NumberInput.setLimits quantity
        |> NumberInput.setValue (Just 700)
        |> NumberInput.isValid
    --> False

### `clear`

```elm
clear : State -> State
```

Empties the field and forgets that the user has been in it (`isTouched` is
`False` again), for example for a "Clear form" button.

### `isValid`

```elm
isValid : State -> Bool
```

`True` when the field is empty or holds a number inside `min` and `max`, and
`False` when the text is not a number or the number is outside them. It answers
at once, also while the user is still typing, although the field's own messages
wait until the field is left. A number outside the limits is never moved into
them (only stepping does that), so the application decides what to do.

The limits are the ones the field was last given: by the attributes of the view,
which the field learns when the user focuses, types in, leaves or steps it, or
by `setLimits`. An empty field counts as valid: for a number that is required,
also check `value` for `Nothing`.

### `isTouched`

```elm
isTouched : State -> Bool
```

`True` once the user has left the field, pressed Enter in it or used one of
the stepper buttons. Use it to show errors only after the first visit. `clear`
makes it `False` again.

## Reading numbers

### `parse`

```elm
parse : String -> Maybe Float
```

Reads a number the way people write it, in no language in particular: `,`
and `.` both work as the decimal separator, spaces and apostrophes are ignored,
and a leading `-` or `+` is allowed. A single `.` or `,` is always a decimal
separator. Gives `Nothing` for anything else, and for empty text.

    NumberInput.parse "12,5" --> Just 12.5

    NumberInput.parse "1 234,56" --> Just 1234.56

    NumberInput.parse "1.234,56" --> Just 1234.56

    NumberInput.parse "1,234.56" --> Just 1234.56

    NumberInput.parse "1.234" --> Just 1.234

    NumberInput.parse "1,234" --> Just 1.234

    NumberInput.parse "twelve" --> Nothing

The field itself reads what is typed with `parseIn`, which lets the language
decide what a lone comma means.

### `parseIn`

```elm
parseIn : Locale.Locale -> String -> Maybe Float
```

Reads a number the way the field does while the user types, in the language
of the field. It reads like `parse`, except that a lone separator between groups
of three digits is what the language says it is. In English a comma groups
thousands, so `1,234` is 1234, as `Klar.Format` writes it, and a point is the
decimal point. In Norwegian a comma is the decimal comma, so `1,234` is 1.234,
and a point groups thousands, as many write it, so `10.000` is 10000. The other
separator than the decimal one that cannot group thousands (`1,5`, `12,34`,
`0,500` in English, `1.5`, `12.25`, `0.500` in Norwegian) is the decimal
separator, and a number written with both separators is read with the last one
as the decimal separator (`1.234,56` and `1,234.56` are 1234.56 in both).
Spaces, no-break spaces and apostrophes are ignored.

    NumberInput.parseIn Locale.en "1,234.5" --> Just 1234.5

    NumberInput.parseIn Locale.en "1,234" --> Just 1234

    NumberInput.parseIn Locale.en "1,5" --> Just 1.5

    NumberInput.parseIn Locale.nb "1 234,5" --> Just 1234.5

    NumberInput.parseIn Locale.nb "1234,5" --> Just 1234.5

    NumberInput.parseIn Locale.nb "1,234" --> Just 1.234

    NumberInput.parseIn Locale.nb "10.000" --> Just 10000

    NumberInput.parseIn Locale.nb "1.5" --> Just 1.5

Whatever `Klar.Format.decimal` writes in a language, `parseIn` reads back with
the same language.

## Label, hint and error

### `label`

```elm
label : String -> Attribute msg
```

The label shown above the field. It is connected to the input, so clicking
it focuses the input and screen readers read it as the name of the input. Give
every field a label, or hide it with `labelHidden`.

### `labelHidden`

```elm
labelHidden : Attribute msg
```

Hides the `label` visually but keeps it for screen readers. Use it when the
surroundings already show what the field is for.

### `hint`

```elm
hint : String -> Attribute msg
```

Help text shown under the field, for example the format you expect. Screen
readers read it together with the label (`aria-describedby`).

### `error`

```elm
error : String -> Attribute msg
```

Shows an error message under the field and marks the field invalid (red
border, `aria-invalid`). Screen readers announce the message when it appears.
To show an error only sometimes, use `errorMaybe`. The field's own messages, for
text that is not a number and for a number outside `min` and `max`, replace this
one until they are fixed, so it is the place for rules of your own, such as a
business rule.

### `errorMaybe`

```elm
errorMaybe : Maybe String -> Attribute msg
```

Like `error`, but takes a `Maybe`: `Just message` shows the message and
`Nothing` shows no error. It fits the result of a validator.

### `required`

```elm
required : Attribute msg
```

Marks the field as required: an asterisk after the label and
`aria-required` on the input. This does not validate anything; an empty field
still counts as valid, so check `value` for `Nothing` yourself and show an
`error`.

### `optionalText`

```elm
optionalText : String -> Attribute msg
```

Text such as `"(optional)"` shown after the label of a field that is not
`required`. By default nothing is shown.

## Range and steps

### `min`

```elm
min : Float -> Attribute msg
```

The smallest allowed number. The stepper buttons and the arrow keys stop
here. A smaller number that is typed is kept as it is: the field shows the
built-in error ("Must be at least ..." or "Must be between ..."), and `isValid`
is `False` until it is fixed. Default: no lower limit.

    NumberInput.min 1

### `max`

```elm
max : Float -> Attribute msg
```

The largest allowed number, in the same way as `min`: stepping stops here,
and a larger number that is typed is kept, shown with the built-in error and
reported by `isValid`. Default: no upper limit.

    NumberInput.max 500

### `step`

```elm
step : Float -> Attribute msg
```

How much the arrow keys and the stepper buttons change the number. With
Shift, or with page up and page down, the change is ten times as big. Default 1;
a step of zero or less counts as 1.

    NumberInput.step 0.5

### `noSteppers`

```elm
noSteppers : Attribute msg
```

Hides the + and - buttons at the end of the field, for a field where
stepping makes no sense, such as a price. They are shown by default, and never
while the field is `disabled` or `readOnly`. The buttons are not in the Tab
order; keyboard users have the arrow keys either way.

## Display

### `decimals`

```elm
decimals : Int -> Attribute msg
```

A fixed number of decimals: the number is rounded to it when the field is
left, and it is always shown with exactly that many (`2` shows 12.5 as `12.50`).
`0` gives whole numbers, and phones show the numeric keyboard. Without it the
number keeps the decimals it has.

### `grouped`

```elm
grouped : Attribute msg
```

Shows thousands separators, as `Klar.Format` writes them: 1234567 appears as
`1,234,567` in English and as `1 234 567` (with no-break spaces) in Norwegian.
The range error writes its limits the same way. What the user types is read in
the same language (see `parseIn`), so `1,234.5` is a number in English and
`1 234,5` in Norwegian. Default: no separators.

### `prefixText`

```elm
prefixText : String -> Attribute msg
```

A unit or currency shown before the number, inside the field. Screen readers
read it with the number.

    NumberInput.prefixText "USD"

### `suffixText`

```elm
suffixText : String -> Attribute msg
```

A unit shown after the number, inside the field, such as `kg`, `pcs` or `%`.
Screen readers read it with the number, and the range error repeats it ("Must be
between 1 and 500 pcs").

    NumberInput.suffixText "kg"

### `alignRight`

```elm
alignRight : Attribute msg
```

Aligns the number to the right, for columns of amounts. Default: left.

### `placeholder`

```elm
placeholder : String -> Attribute msg
```

Text shown inside the empty field, for example a sample value. It is not a
substitute for a `label`, and it disappears as soon as the user types. Default:
none.

### `size`

```elm
size : Theme.Size -> Attribute msg
```

The size of the field: `Small` (26px high), `Medium` (32px) or `Large`
(40px) at the default density (see `Klar.Theme` for the others), from
[Klar.Theme](Klar.Theme.md). Default `Medium`.

## State and browser hints

### `disabled`

```elm
disabled : Bool -> Attribute msg
```

While `True` the field is dimmed and cannot be focused or changed. Default
`False`.

### `readOnly`

```elm
readOnly : Bool -> Attribute msg
```

While `True` the user can focus the field and select its text, but not
change it. Default `False`.

### `name`

```elm
name : String -> Attribute msg
```

The HTML `name` of the input. Browsers use it to fill in saved values, and a
native form sends the value under this name. Default: none.

## Language

### `locale`

```elm
locale : Locale.Locale -> Attribute msg
```

The language of the built-in texts and of the number format: the error
messages, the names of the stepper buttons ("Increase value" and "Decrease
value"), the separators the number is written with (`12.5` in English, `12,5` in
Norwegian; with `grouped`, `1,234.5` and `1 234,5`) and the way what the user
types is read (see `parseIn`). Default `Locale.default`, which is English. Texts
you pass in yourself are shown as they are.
