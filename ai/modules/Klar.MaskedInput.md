# Klar.MaskedInput

A field for an identifier that has a fixed shape and, often, a check digit: an IBAN, an organisation number, a bank account, a postal code, a phone number, or a code of your own such as `AB-1234`.

Import: `import Klar.MaskedInput as MaskedInput` | Group: Inputs

Types: `Msg`, `Mask`, `State`, `Attribute`

## Signatures

```elm
-- View
type Attribute msg  -- opaque: no constructors are exposed
view : (Msg -> msg) -> List (Attribute msg) -> State -> Html msg

-- State
type State  -- opaque: no constructors are exposed
type Msg  -- opaque: no constructors are exposed
init : String -> Mask -> State
update : Msg -> State -> ( State, Cmd Msg )

-- Masks
type Mask  -- opaque: no constructors are exposed
iban : Mask
norwegianOrganisationNumber : Mask
norwegianBankAccount : Mask
norwegianPostalCode : Mask
postalCode : String -> Maybe Mask
phone : Mask
ean13 : Mask
pattern : String -> Maybe Mask
setMask : Mask -> State -> State

-- The identifier
value : State -> Maybe String
text : State -> String
problem : List (Attribute msg) -> State -> Maybe String
setValue : Maybe String -> State -> State
clear : State -> State
touch : State -> State
isComplete : State -> Bool
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

-- Display and browser hints
placeholder : String -> Attribute msg
size : Theme.Size -> Attribute msg
disabled : Bool -> Attribute msg
readOnly : Bool -> Attribute msg
name : String -> Attribute msg

-- Language
locale : Locale.Locale -> Attribute msg
```

## Documentation

A field for an identifier that has a fixed shape and, often, a check digit: an
IBAN, an organisation number, a bank account, a postal code, a phone number, or a
code of your own such as `AB-1234`. It writes the text in its groups as the user types
it, and says what is wrong with it. It is stateful.

Use when: an identifier with a fixed shape and often a check digit, such as an IBAN, an organisation number or a postal code.
Do not use when: the text is free (`Klar.TextInput`) or the value is an amount of money (`Klar.MoneyInput`).
Quick path: `init`, `update`, `view`, `value`

    import Klar.MaskedInput as MaskedInput

    type alias Model =
        { account : MaskedInput.State }

    init : Model
    init =
        { account = MaskedInput.init "supplier-iban" MaskedInput.iban }

    -- update
    AccountMsg inner ->
        let
            ( account, cmd ) =
                MaskedInput.update inner model.account
        in
        ( { model | account = account }, Cmd.map AccountMsg cmd )

    -- view
    MaskedInput.view AccountMsg
        [ MaskedInput.label "IBAN", MaskedInput.required ]
        model.account

    -- read the IBAN
    MaskedInput.value model.account -- Just "NO9386011117947" when it is complete and right

The first `String` given to `init` is the DOM id of the input, so there is no `id`
attribute. The second is the `Mask`, which says what is accepted. The application
reads the identifier with `value`, which is `Nothing` until the identifier is
complete and its check digits are right, and uses `isTouched` to show errors of its
own only after the user has been in the field once. It reacts to changes by comparing
`value` before and after `update`. `text` is what the field shows, and `problem` the
message it shows, for an error summary of your own.

`label`, `labelHidden`, `hint`, `error`, `errorMaybe`, `required` and `optionalText`
are the common field attributes. They come with the field wrapper
([Klar.Field](Klar.Field.md)) that most Klar inputs are built on, so they mean the same
in all of them. The field is always inside the wrapper, so it does not move when an
error comes and goes.

**Masks.** A `Mask` is a value, made by a function: `iban`,
`norwegianOrganisationNumber`, `norwegianBankAccount`, `norwegianPostalCode`,
`postalCode "SE"`, `phone`, `ean13` (the barcode number of a product), or a pattern
of your own with `pattern "@@-####"`. A mask
that can fail to be made (an unknown country, a pattern that makes no sense) gives
`Maybe`, so the application knows at once, not when the user is in the field. Build
the masks once, in `init`; `setMask` changes the mask of a field that is on the
screen, such as the postal code of an address whose country changes.

**What is typed is not changed behind the user's back.** Separators (spaces, hyphens,
points, slashes, parentheses) can be typed anywhere or left out: the field puts them
in the right places, and they are not part of the value. Letters are written in
capitals, and the full-width digits and letters of an IME (`１２３`) count as the
ordinary ones. Nothing else is quietly dropped: a letter in a field for digits stays
where it was typed, and the field says so at once. Text that is too long stays too, and
is reported. `value` is `Nothing` until all of that is fixed. While the user is typing,
`setValue` leaves the field alone: what they type wins.

**Errors.** The messages are specific: "The check digit is wrong", "An IBAN from NO
has 15 characters (12 entered)", "Too short: 6 of 9 digits". An error that more typing
cannot fix (a character that does not belong, a value that is too long, a wrong check
digit in a complete value) is shown at once. An unfinished value is not an error while
the user is typing; it becomes one when the field is left or Enter is pressed (the
field is then touched), or when the application calls `touch`. The `error` and
`errorMaybe` of the application, for problems that only the server knows, show when the
field has no message of its own.

**The caret.** The field writes the text in its groups while the user types at the end
of it, which is where nearly everyone types and where a pasted identifier ends up. The
browser moves the caret to the end of the field whenever the value is set, and plain
Elm cannot put it back, so an edit in the middle of the text (a character inserted or
deleted before the end) is kept exactly as typed, and written in its groups once the
user goes on typing at the end or leaves the field. Nothing is ever lost or moved; the
groups are just a little late after such an edit.

**Not libphonenumber.** The phone mask is a help, not a validator: it requires the
international form (`+`, the country code, the rest), accepts 7 to 15 digits as the
standard for phone numbers says, and writes Norwegian (`+47 912 34 567`), Danish and
North American numbers in their usual groups and others in groups of three. It does
not know which numbers exist. National numbers without `+` are refused with a message
that says what to do, and so is the national zero in parentheses after the country code
(`+44 (0)20 7946 0958`): dropping the parentheses would leave a 0 in the number, so the
field keeps the text as typed and asks for the number without `(0)`.

**Keyboard and accessibility.** The input is a text field with the keyboard hint that
suits the mask (numeric for digits, telephone pad for a phone number) and without
automatic capitals, corrections and spell checking. Identifiers read from left to
right in every language, so the input is always left to right. Enter writes the
identifier in its groups and still lets a surrounding form submit; the Enter that ends
an IME composition only picks the characters. Errors are announced when they appear,
and a message does not change while the user types on (a value that is too long says
how long it should be, not how long it is now). A counter such as `6/9` next to the
field (hidden from screen readers) shows how far the user has come.

The built-in texts (the errors) follow `locale`.

## View

### `Attribute`

```elm
type Attribute msg  -- opaque: no constructors are exposed
```

A setting of a masked field. Make them with the functions below and pass a list to
`view`; later attributes win over earlier ones.

### `view`

```elm
view : (Msg -> msg) -> List (Attribute msg) -> State -> Html msg
```

A masked field with its label, hint and error message. The first argument wraps
the field's own messages in one of yours, and the state comes last.

    MaskedInput.view OrgnrMsg
        [ MaskedInput.label "Organisation number"
        , MaskedInput.required
        ]
        model.orgnr

## State

### `State`

```elm
type State  -- opaque: no constructors are exposed
```

The state of a field: the text it shows and whether the user has been in it. Make
one with `init`, keep it in your model and give it to `view` and `update`.

### `Msg`

```elm
type Msg  -- opaque: no constructors are exposed
```

The messages a masked field sends: what was typed, focus and leaving the field.
`view` wraps them with the function you give it; hand them to `update` when they come
back.

### `init`

```elm
init : String -> Mask -> State
```

An empty field for a mask. The `String` is the DOM id of the input; it must be
unique on the page, because the label, hint and error point at it. To start with an
identifier, use `setValue`.

    MaskedInput.init "supplier-orgnr" MaskedInput.norwegianOrganisationNumber

### `update`

```elm
update : Msg -> State -> ( State, Cmd Msg )
```

Moves the field on after one of its messages. The `Cmd` is always `Cmd.none`; it is
there so that the field is wired like the others (`Cmd.map`).

## Masks

### `Mask`

```elm
type Mask  -- opaque: no constructors are exposed
```

What a field accepts: the shape of the text, how it is written in groups, and
which check digits it must have. Make one with `iban`, `norwegianOrganisationNumber`,
`norwegianBankAccount`, `norwegianPostalCode`, `postalCode`, `phone` or `pattern`.

### `iban`

```elm
iban : Mask
```

An IBAN, the international bank account number: two letters for the country, two
check digits and the national account number, `NO93 8601 1117 947`. The length must be
the one of the country (15 for Norway, 22 for Germany), and the check digits must be
right (ISO 7064, modulus 97; the digits 00, 01 and 99, which ISO 13616 does not use, are
refused). The countries are those of the SWIFT IBAN registry as public copies of it
listed them in May 2026, 89 of them; an IBAN from a country that has joined since is
reported as "no IBAN country" until this package is updated, and so is one from a
country that has no IBANs in the registry. The value is written without spaces:
`NO9386011117947`.

### `norwegianOrganisationNumber`

```elm
norwegianOrganisationNumber : Mask
```

A Norwegian organisation number: nine digits where the last is a check digit
(modulus 11), `974 760 673`. The value is the nine digits.

### `norwegianBankAccount`

```elm
norwegianBankAccount : Mask
```

A Norwegian bank account number: eleven digits where the last is a check digit
(modulus 11), written `8601.11.17947`. The value is the eleven digits. Use `iban` for
an account that may be abroad.

### `norwegianPostalCode`

```elm
norwegianPostalCode : Mask
```

A Norwegian postal code: four digits, `0150`. There is no check digit, so any four
digits are accepted; the application knows which postal codes exist. It is the same
mask as `postalCode "NO"`, without the `Maybe`: where the country is fixed, this one
cannot fail.

### `postalCode`

```elm
postalCode : String -> Maybe Mask
```

The postal codes of a country, by its two-letter ISO 3166 code (`"SE"` for
`123 45`, `"NL"` for `1234 AB`, `"PL"` for `12-345`). Upper or lower case, and spaces
around the code, are fine. It is for a country that is not fixed, such as the one in an
address, and `postalCode "NO"` is the Norwegian mask too, so every country of the list
works the same way; where the country is Norway, `norwegianPostalCode` has no `Nothing`
to handle. When the country of the address changes, give the field the new mask with
`setMask`. `Nothing` for a country that is not in the list (Norway,
Sweden, Denmark, Finland, Iceland, Germany, Austria, Switzerland, Liechtenstein, the
Netherlands, Belgium, Luxembourg, France, Spain, Italy, Portugal, Poland, Czechia,
Slovakia, Estonia, the United States, Japan, Australia and New Zealand); the postal
codes of other countries, such as Ireland and the United Kingdom, are not a fixed
pattern, and `pattern` can make one for the others.

### `phone`

```elm
phone : Mask
```

A phone number in the international form: `+`, the country calling code and the
number, 7 to 15 digits in all, as in `+47 912 34 567`. A Norwegian number (`+47`) must
have exactly eight digits after the code. Spaces, hyphens, points and parentheses may be
typed and are not part of the value, which is `+4791234567`. This is a help for typing,
not a phone number database.

### `ean13`

```elm
ean13 : Mask
```

The number under the barcode of a product, a GTIN-13 (EAN-13): thirteen digits
where the last is a check digit (modulus 10), `5901234123457`. A scanner that types
the number and an Enter works too: the Enter writes it and lets a form go on. The
value is the thirteen digits.

### `pattern`

```elm
pattern : String -> Maybe Mask
```

A mask of your own from a pattern. Three characters are slots, and every other
character is a fixed one that the field writes by itself and that is not part of the
value. The characters in a pattern are these:

  - `#` takes a digit;
  - `@` takes a letter, A to Z, in capitals;
  - `*` takes a letter or a digit;
  - anything else that is not a letter or a digit (a hyphen, a space, a point) is
    shown between the slots; a backslash in front of a character makes it one of
    those, so `\#` is a hash sign.

Two examples:

    MaskedInput.pattern "@@-####" -- AB-1234

    MaskedInput.pattern "##.##.##" -- 12.34.56

The value is the characters of the slots (`AB1234`); `text` is what the field shows
(`AB-1234`). Use the shown form when the hyphen belongs to the identifier.

`Nothing` for a pattern without slots, a pattern that ends in a backslash, one with a
letter (of any alphabet, `å` and `é` too) or a digit that is not a slot (the user would
have to type it; the application can add a fixed start itself), one with a control
character, and one longer than 64 characters. There is no check digit.

### `setMask`

```elm
setMask : Mask -> State -> State
```

Gives the field another mask and keeps its text, written again in the groups of
the new mask (or kept as it is, with the message about it, when it does not fit). For
a field whose rule depends on other data: the postal code of an address when its
country changes. Whether the user has been in the field stays as it was.

    CountryChanged country ->
        case MaskedInput.postalCode country of
            Just mask ->
                ( { model | postal = MaskedInput.setMask mask model.postal }, Cmd.none )

            Nothing ->
                -- no fixed pattern for this country: a plain text field instead
                ( model, Cmd.none )

## The identifier

### `value`

```elm
value : State -> Maybe String
```

The identifier, or `Nothing` when the field is empty or what is in it is not a
complete, right identifier. It is the normalised value: no separators, letters in
capitals, a phone number with its `+` (`NO9386011117947`, `974760673`,
`+4791234567`). Fixed characters of a pattern are not in it; `text` has them.

### `text`

```elm
text : State -> String
```

The text in the field, written in its groups (`NO93 8601 1117 947`), or exactly as
typed while it holds a character that does not belong or an edit in the middle waits
to be written. Together with `value` it tells an empty field from an unfinished one.

### `problem`

```elm
problem : List (Attribute msg) -> State -> Maybe String
```

The message the field shows under itself about what is in it, in the language of
the attributes, or `Nothing`: "The check digit is wrong", "Too short: 6 of 9 digits".
It follows the same timing as the field: an unfinished value has no message until the
field is left (or `touch` is used). Pass the attributes you give to `view`; your own
`error` is not part of it. For an error summary of your own:

    MaskedInput.problem ibanAttributes (MaskedInput.touch model.iban)

### `setValue`

```elm
setValue : Maybe String -> State -> State
```

Shows an identifier, or an empty field for `Nothing`. The text may be as it comes
from a server (`NO9386011117947`) or as a person wrote it (`no93 8601 1117 947`); the
field writes it in its groups. Whatever it is, nothing is dropped: if it has a character
that does not belong, the field shows it as it is, with the message about it.

While the user is typing in the field (they have typed since they came into it, and
have not left it or pressed Enter yet), it changes nothing: what they type wins, and
the application learns the result by comparing `value` before and after `update`.

### `clear`

```elm
clear : State -> State
```

Empties the field and forgets that the user has been in it (`isTouched` is
`False` again), for example for a "Clear form" button.

### `touch`

```elm
touch : State -> State
```

Counts the field as visited, as if the user had been in it and left, so that the
messages about an unfinished value show. Use it when the application wants to show the
errors of all fields at once, such as after a failed attempt to submit.

### `isComplete`

```elm
isComplete : State -> Bool
```

`True` when the field has all the characters it needs, whatever its check digits
say: nine digits for an organisation number, the length of the country for an IBAN. An
empty field is not complete.

### `isValid`

```elm
isValid : State -> Bool
```

`True` when the field is empty or holds a complete identifier with the right check
digits, and `False` when anything is wrong with what is in it, including an unfinished
value. It answers at once, also while the user is typing, although the messages of an
unfinished value wait until the field is left. An empty field counts as valid: for an
identifier that is required, also check `value` for `Nothing`.

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

Help text shown under the field, for example what the identifier is for. Screen
readers read it together with the label (`aria-describedby`).

### `error`

```elm
error : String -> Attribute msg
```

Shows an error message under the field and marks the field invalid (red
border, `aria-invalid`). Screen readers announce the message when it appears.
To show an error only sometimes, use `errorMaybe`. The field's own messages replace
this one until they are fixed, so it is the place for rules of your own, such as "This
account is already registered" from the server.

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

## Display and browser hints

### `placeholder`

```elm
placeholder : String -> Attribute msg
```

Text shown inside the empty field. Without it the field shows the shape of the
identifier, such as `NO00 0000 0000 000` for an IBAN or `000 000 000` for an
organisation number, which tells how it is written. It is not a substitute for a
`label`, and it disappears as soon as the user types.

### `size`

```elm
size : Theme.Size -> Attribute msg
```

The size of the field: `Small` (26px high), `Medium` (32px) or `Large`
(40px), from [Klar.Theme](Klar.Theme.md). Default `Medium`.

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

The language of the built-in texts, which are the error messages. Default
`Locale.default`, which is English. Texts you pass in yourself are shown as they are.
