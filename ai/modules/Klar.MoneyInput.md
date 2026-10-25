# Klar.MoneyInput

A field for an amount of money in one currency.

Import: `import Klar.MoneyInput as MoneyInput` | Group: Inputs

Types: `Msg`, `State`, `Attribute`

## Signatures

```elm
-- View
type Attribute msg  -- opaque: no constructors are exposed
view : (Msg -> msg) -> List (Attribute msg) -> State -> Html msg

-- State
type State  -- opaque: no constructors are exposed
type Msg  -- opaque: no constructors are exposed
init : String -> Money.Currency -> State
update : Msg -> State -> ( State, Cmd Msg )

-- The amount
value : State -> Maybe Money.Money
text : Locale.Locale -> State -> String
problem : List (Attribute msg) -> State -> Maybe String
setValue : Maybe Money.Money -> State -> State
currencyOf : State -> Money.Currency
setCurrency : Money.Currency -> State -> State
setLimits : List (Attribute msg) -> State -> State
clear : State -> State
touch : State -> State
isValid : State -> Bool
isTouched : State -> Bool

-- Label, hint and error
label : String -> Attribute msg
labelHidden : Attribute msg
hint : String -> Attribute msg
error : String -> Attribute msg
errorMaybe : Maybe String -> Attribute msg
required : Attribute msg
optionalText : String -> Attribute msg

-- Limits
min : Money.Money -> Attribute msg
max : Money.Money -> Attribute msg
allowNegative : Attribute msg

-- Display
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

A field for an amount of money in one currency. It keeps the text the user
types ("1 234,5", "1,234.50", "kr 100") and reads it into an exact
[Klar.Money](Klar.Money.md), so it is stateful.

Use when: the user types an amount of money in one currency and the application needs it as an exact `Klar.Money`.
Do not use when: the number is not money (`Klar.NumberInput`) or an amount is only shown (`Klar.Money`).
Quick path: `init`, `update`, `view`, `value`

    import Klar.Money as Money
    import Klar.MoneyInput as MoneyInput

    type alias Model =
        { price : MoneyInput.State }

    init : Model
    init =
        { price = MoneyInput.init "line-price" Money.nok }

    -- update
    PriceMsg inner ->
        let
            ( price, cmd ) =
                MoneyInput.update inner model.price
        in
        ( { model | price = price }, Cmd.map PriceMsg cmd )

    -- view
    MoneyInput.view PriceMsg
        [ MoneyInput.label "Unit price"
        , MoneyInput.min (Money.zero Money.nok)
        , MoneyInput.required
        ]
        model.price

    -- read the amount
    MoneyInput.value model.price -- Maybe Money

The first `String` given to `init` is the DOM id of the input, so there is no `id`
attribute. The second is the currency, which is a required argument and not an
attribute: an amount without a currency means nothing. The application reads the
amount with `value`, reacts to changes by comparing `value` before and after
`update`, and uses `isTouched` to show its own errors only after the user has been
in the field once. `text` is what the field shows, and `problem` the message it
shows, for an error summary of your own.

`label`, `labelHidden`, `hint`, `error`, `errorMaybe`, `required` and `optionalText`
are the common field attributes. They come with the field wrapper
([Klar.Field](Klar.Field.md)) that most Klar inputs are built on, so they mean the same
in all of them. The field is always inside the wrapper, so it does not move when an
error comes and goes.

**The currency is always in view.** The code of the currency (`NOK`) stands at the
end of the field, so the person typing always sees which currency is meant, and a
screen reader reads it as the description of the field.

**Typing.** The field reads the text like `Money.parse` does, in the language of
the field (`locale`). `.` and `,` both work as the decimal separator, `1 234,50` and
`1,234.50` are both 1234.50, and the text may come with the currency (`NOK 1 234`,
`1 234,50 kr`), a minus sign or parentheses for a negative amount (`(100)`), and the
Norwegian `1 234,-`. In English `1,234` is 1234 and in Norwegian it is 1.234. In
Norwegian `10.000` is refused as unclear, not read as ten: many people write ten
thousand that way. What is typed is kept as typed while the field has the focus.

**What the field shows.** When the user leaves the field (or presses Enter) the
amount is written with the grouping and the separators of the language and exactly the
decimals of the currency: `1 234,50` for NOK in Norwegian, `1,500` for JPY, `1,234.567`
for KWD. A negative amount begins with the minus sign of the keyboard, so that the
text can be copied into a spreadsheet.

**Nothing is rounded for you.** An amount with more decimals than the currency has
(`12.505` NOK) is kept as typed, shows the error "NOK has 2 decimals" at once, and
`value` is `Nothing` until it is fixed: only the person who typed it knows whether it
should be 12.50 or 12.51. For the same reason `1,234` in a field for a currency with
three decimals (KWD) in English is refused as unclear, not guessed.

**Limits and negative amounts.** `min` and `max` take amounts. An amount outside them
is never moved into the range: it stays as typed, shows "Must be between 10.00 and
5,000.00 NOK" once the field is left, and `isValid` is `False` from the first
keystroke. A negative amount is refused unless the field has `allowNegative`, since
most amounts are not negative. A limit in another currency is a mistake in the
program; the field shows that, and is invalid, instead of ignoring the limit.

`isValid` knows the limits from the attributes of the view, which the field learns
when the user focuses, types in or leaves it. An amount that you put in with
`setValue` before that, such as one loaded from a server, needs `setLimits` once, with
the same attributes you give to `view`. `problem` takes the attributes itself, so it
always judges by the limits you give it.

**What the user types wins.** While the user is typing in the field, `setValue`
leaves the field alone, so an amount that is loaded again (a poll, a push from the
server) does not overwrite a half-typed one; the application learns the result by
comparing `value` before and after `update`.

**A percentage, a weight, a count.** The field is for money. A number with a unit
(`kg`, `pcs`, `%`) is a [NumberInput](Klar.NumberInput.md) with `suffixText`.

**Keyboard and accessibility.** Enter formats the amount and still lets a
surrounding form submit; the Enter that ends an IME composition only picks the
characters. The input is a text field with a numeric keyboard hint
(`inputmode="decimal"`, or `numeric` for a currency without decimals; a field that
`allowNegative` leaves the hint out, because the numeric keypad of a phone has no
minus key). Errors are announced when they appear.

The built-in texts (the errors) and the number format follow `locale`.

## View

### `Attribute`

```elm
type Attribute msg  -- opaque: no constructors are exposed
```

A setting of an amount field. Make them with the functions below and pass a list
to `view`; later attributes win over earlier ones.

### `view`

```elm
view : (Msg -> msg) -> List (Attribute msg) -> State -> Html msg
```

An amount field with its label, hint and error message. The first argument wraps
the field's own messages in one of yours, and the state comes last.

    MoneyInput.view PriceMsg
        [ MoneyInput.label "Unit price"
        , MoneyInput.min (Money.zero Money.nok)
        ]
        model.price

## State

### `State`

```elm
type State  -- opaque: no constructors are exposed
```

The state of an amount field: the text being typed, the amount read from it, the
currency and whether the user has been in the field. Make one with `init`, keep it in
your model and give it to `view` and `update`.

### `Msg`

```elm
type Msg  -- opaque: no constructors are exposed
```

The messages an amount field sends: typing, focus and leaving the field. `view`
wraps them with the function you give it; hand them to `update` when they come back.

### `init`

```elm
init : String -> Money.Currency -> State
```

An empty field for amounts in a currency. The `String` is the DOM id of the
input; it must be unique on the page, because the label, hint and error point at it.
To start with an amount, use `setValue`.

    MoneyInput.init "line-price" Money.nok

### `update`

```elm
update : Msg -> State -> ( State, Cmd Msg )
```

Moves the field on after one of its messages. There is never anything to do for
the runtime, so the `Cmd` is always `Cmd.none`; it is there so that the field is wired
like the others (`Cmd.map`).

## The amount

### `value`

```elm
value : State -> Maybe Money.Money
```

The amount in the field, or `Nothing` when the field is empty or the text is not
an amount in the currency of the field (it has too many decimals, for instance). An
amount outside `min` and `max`, or a negative one that is not allowed, is returned as
it was typed; `isValid` tells whether it is acceptable.

### `text`

```elm
text : Locale.Locale -> State -> String
```

The text in the field, as the field shows it in this language: what the user is
typing, text that is not an amount (kept as typed), or the amount written with the
grouping and the decimals of the language (`1 234,50` in Norwegian). `""` for an
empty field. Together with `value` it tells an empty field from one with text that
is not an amount.

    MoneyInput.text Locale.nb model.price -- "1 234,50"

### `problem`

```elm
problem : List (Attribute msg) -> State -> Maybe String
```

The message the field shows under itself about what is in it, in the language of
the attributes, or `Nothing`: "NOK has 2 decimals", "Must be between 10.00 and
5,000.00 NOK". It is judged by the limits in the attributes you pass, which are the
ones you give to `view`, and it follows the same timing as the field: the start of an
amount (`-`, `1,`) has no message while the user is typing it. Your own `error` is not
part of it. It is for showing, not for deciding: `Nothing` also means a half-typed
amount, so check `isValid` before you save. For an error summary of your own:

    MoneyInput.problem priceAttributes model.price

### `setValue`

```elm
setValue : Maybe Money.Money -> State -> State
```

Shows an amount, or an empty field for `Nothing`. The field takes the currency of
the amount (a field for NOK that is given an amount in EUR shows EUR, which is hard to
miss); `Nothing` keeps the currency. The amount is not moved into `min` and `max`:
`isValid` tells whether it is inside the limits the field knows (see `setLimits`).

While the user is typing in the field (it has the focus and text they typed), it
changes nothing: what they type wins over an amount loaded again from the server, and
the application learns the result by comparing `value` before and after `update`. To
replace their text on purpose, `clear` the field first: for the amount the server
wrote back after a save, or a "Reset" shortcut. Do that also after a save that started
while the user was typing (Ctrl+S): a field that was disabled or removed before they
left it never heard that they left, and still counts as being typed in.

    MoneyInput.clear model.price
        |> MoneyInput.setValue (Just saved.price)

### `currencyOf`

```elm
currencyOf : State -> Money.Currency
```

The currency of the field.

### `setCurrency`

```elm
setCurrency : Money.Currency -> State -> State
```

Changes the currency of the field, for example when the user chooses another one
from a list next to it. The number stays and is read again in the new currency: 100.50
in a field for NOK becomes 100.50 in a field for USD. In a currency with fewer
decimals (JPY) it would have to be rounded, and it is not: the text stays as it is and
the field says "JPY has no decimals". The text is read in the language the field last
saw in its attributes (from a message of the view, or from `setLimits`).

### `setLimits`

```elm
setLimits : List (Attribute msg) -> State -> State
```

Tells the state the limits in the given attributes (`min`, `max` and
`allowNegative`) and their language, so that `isValid` and `setCurrency` know them
before the user has touched the field. Pass the list you give to `view`; the other
attributes in it are ignored. The amount is never changed.

A field learns its limits by itself when the user focuses, types in or leaves it. This
is for an amount that you put in with `setValue` before that, such as one loaded from
a server, and for limits that change while the field is on the screen. Until the field
has learned its limits, in one way or the other, `isValid` does not judge the amount by
them: a credit note that you load into a field that has `allowNegative` is never
reported invalid because the field has not heard of `allowNegative` yet. It is not
reported invalid for a limit it does not know either, so give a loaded amount its
`setLimits` to have it checked.

    price : List (MoneyInput.Attribute Msg)
    price =
        [ MoneyInput.label "Price", MoneyInput.min (Money.zero Money.nok) ]

    MoneyInput.init "line-price" Money.nok
        |> MoneyInput.setLimits price
        |> MoneyInput.setValue (Money.fromMinor Money.nok -500)
        |> MoneyInput.isValid
    --> False

    -- and with allowNegative among the attributes, a credit note is fine
    MoneyInput.init "line-credit" Money.nok
        |> MoneyInput.setLimits [ MoneyInput.allowNegative ]
        |> MoneyInput.setValue (Money.fromMinor Money.nok -500)
        |> MoneyInput.isValid
    --> True

### `clear`

```elm
clear : State -> State
```

Empties the field and forgets that the user has been in it (`isTouched` is
`False` again), for example for a "Clear form" button. The currency stays.

### `touch`

```elm
touch : State -> State
```

Counts the field as visited, as if the user had been in it and left. Use it when
the application wants to show the errors of all fields at once, such as after a
failed attempt to submit.

### `isValid`

```elm
isValid : State -> Bool
```

`True` when the field is empty or holds an amount that is acceptable, and `False`
when the text is not an amount in the currency, the amount is negative where that is
not allowed, or it is outside `min` and `max`. It answers at once, also while the user
is still typing, although the field's own messages wait until the field is left. An
amount outside the limits is never moved into them, so the application decides what
to do.

An empty field counts as valid: for an amount that is required, also check `value`
for `Nothing`.

The field judges the amount by the limits it knows: the attributes it saw in a message of
the view, or the ones of `setLimits`. An amount that was put in with `setValue` and has
not been given limits is only checked for being an amount.

### `isTouched`

```elm
isTouched : State -> Bool
```

`True` once the user has left the field or pressed Enter in it, or `touch` was
used. Use it to show errors of your own only after the first visit. `clear` makes it
`False` again.

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

Help text shown under the field, for example what the amount is for. Screen
readers read it together with the label (`aria-describedby`).

### `error`

```elm
error : String -> Attribute msg
```

Shows an error message under the field and marks the field invalid (red
border, `aria-invalid`). Screen readers announce the message when it appears.
To show an error only sometimes, use `errorMaybe`. The field's own messages, for text
that is not an amount and for an amount outside the limits, replace this one until
they are fixed, so it is the place for rules of your own, such as a business rule or a
message from the server.

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

## Limits

### `min`

```elm
min : Money.Money -> Attribute msg
```

The smallest allowed amount. An amount below it is kept as it is typed: the field
shows the built-in error ("Must be at least 10.00 NOK" or "Must be between ...") and
`isValid` is `False` until it is fixed. Default: no lower limit. The amount must be in
the currency of the field.

    MoneyInput.min (Money.zero Money.nok)

### `max`

```elm
max : Money.Money -> Attribute msg
```

The largest allowed amount, in the same way as `min`: a larger amount that is typed
is kept, shown with the built-in error and reported by `isValid`. Default: no upper
limit.

    -- the credit limit of the customer, a Money that came with the record
    MoneyInput.max customer.creditLimit

### `allowNegative`

```elm
allowNegative : Attribute msg
```

Allows a negative amount (a credit note, a discount, a correction). Without it a
negative amount is kept as typed, shown with the error "Must not be negative", and
`isValid` is `False`.

## Display

### `alignRight`

```elm
alignRight : Attribute msg
```

Aligns the amount to the right, for columns of amounts. Default: left.

### `placeholder`

```elm
placeholder : String -> Attribute msg
```

Text shown inside the empty field. Without it the field shows a zero with the
decimals of the currency (`0,00` for NOK in Norwegian, `0.000` for KWD in English),
which tells how the amount is written. It is not a substitute for a `label`, and it
disappears as soon as the user types.

### `size`

```elm
size : Theme.Size -> Attribute msg
```

The size of the field: `Small` (26px high), `Medium` (32px) or `Large`
(40px), from [Klar.Theme](Klar.Theme.md). Default `Medium`.

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

The HTML `name` of the input. A native form sends the text under this name.
Default: none.

## Language

### `locale`

```elm
locale : Locale.Locale -> Attribute msg
```

The language of the built-in texts and of the number format: the error messages,
the separators the amount is written with (`1,234.50` in English, `1 234,50` in
Norwegian) and the way what the user types is read (see `Money.parse`). Default
`Locale.default`, which is English. Texts you pass in yourself are shown as they are.
