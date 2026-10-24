# Klar.TextInput

A single-line text input with a label, a hint and an error message.

Import: `import Klar.TextInput as TextInput` | Group: Inputs

Types: `Attribute`

## Signatures

```elm
-- View
type Attribute msg  -- opaque: no constructors are exposed
view : List (Attribute msg) -> Html msg

-- Value and events
value : String -> Attribute msg
onInput : (String -> msg) -> Attribute msg
onEnter : msg -> Attribute msg
onBlur : msg -> Attribute msg
onFocus : msg -> Attribute msg

-- Label, hint and error
label : String -> Attribute msg
labelHidden : Attribute msg
hint : String -> Attribute msg
error : String -> Attribute msg
errorMaybe : Maybe String -> Attribute msg
required : Attribute msg
optionalText : String -> Attribute msg
id : String -> Attribute msg

-- Kind of input
email : Attribute msg
tel : Attribute msg
url : Attribute msg
search : Attribute msg
verbatim : Attribute msg

-- Decoration and helpers
placeholder : String -> Attribute msg
prefixIcon : Icon.Icon -> Attribute msg
prefixText : String -> Attribute msg
suffixIcon : Icon.Icon -> Attribute msg
suffixText : String -> Attribute msg
clearable : Attribute msg
maxLength : Int -> Attribute msg
size : Theme.Size -> Attribute msg

-- State and browser hints
disabled : Bool -> Attribute msg
readOnly : Bool -> Attribute msg
autofocus : Attribute msg
autocomplete : String -> Attribute msg
inputMode : String -> Attribute msg
name : String -> Attribute msg

-- Language
locale : Locale.Locale -> Attribute msg
```

## Documentation

A single-line text input with a label, a hint and an error message.

Use when: you need one line of text and want to own the value in your model.
Do not use when: the value is a number, a password, a search that waits for a pause, tags or several lines (use `Klar.NumberInput`, `Klar.PasswordInput`, `Klar.SearchInput`, `Klar.TagInput` or `Klar.TextArea`).

    import Klar.TextInput as TextInput

    TextInput.view
        [ TextInput.label "Customer name"
        , TextInput.required
        , TextInput.value model.customerName
        , TextInput.onInput CustomerNameChanged
        , TextInput.errorMaybe model.customerNameError
        ]

The application owns the value (a "controlled input"): the input shows the
`value` you give it and reports every change through `onInput`. It keeps no
state of its own, so there is no `State`, `Msg` or `update`. For numbers,
passwords, searches, tags and text of several lines use
[Klar.NumberInput](Klar.NumberInput.md), [Klar.PasswordInput](Klar.PasswordInput.md),
[Klar.SearchInput](Klar.SearchInput.md), [Klar.TagInput](Klar.TagInput.md) and
[Klar.TextArea](Klar.TextArea.md) instead. `search` makes a filter box that reports
every keystroke, for a list that is filtered in the browser.

`label`, `labelHidden`, `hint`, `error`, `errorMaybe`, `required`,
`optionalText` and `id` are the common field attributes. They come with the
field wrapper ([Klar.Field](Klar.Field.md)) that most Klar inputs are built on, so
they mean the same in all of them: the wrapper draws the label, the required
marker, the hint and the error message around the input and connects them for
screen readers (`for`, `aria-describedby`, `aria-invalid`, `aria-required`). An
error message is announced when it appears.

Every input needs an `id` that is unique on the page, because its label, hint
and error point at it. If you do not set one, it is made from the label (or,
failing that, the placeholder, the name, the hint or the error). An input with
none of them gets no id, so two such inputs never share one; give it an `id`
when something else must point at it.

The input is always inside the wrapper, also when there is no `label`, `hint` or
`error` to draw. It therefore stays where it is when the application shows an
error while the user is typing, and the keyboard focus is not lost. The wrapper
of an input with nothing to draw takes the place and the width of the input
alone, so the layout of a bare input does not change.

**Length.** `maxLength` shows a counter such as `12/200` at the end of the line
under the field, as [Klar.TextArea](Klar.TextArea.md) does. It never cuts what the
user types or pastes: a longer text stays, the counter and the field turn red,
and screen readers are told. Check the length when the form is sent, with
`Validate.maxLength` from [Klar.Validate](Klar.Validate.md).

The only texts the input brings itself are the name of the clear button ("Clear
field") and what the counter tells screen readers; `locale` changes their
language.

## View

### `Attribute`

```elm
type Attribute msg  -- opaque: no constructors are exposed
```

A setting of a text input. Make them with the functions below and pass a
list to `view`; later attributes win over earlier ones.

### `view`

```elm
view : List (Attribute msg) -> Html msg
```

An input with its label, hint and error message. The value, the events and
everything else are set with attributes.

    TextInput.view
        [ TextInput.label "Email"
        , TextInput.email
        , TextInput.clearable
        , TextInput.value model.email
        , TextInput.onInput EmailChanged
        ]

## Value and events

### `value`

```elm
value : String -> Attribute msg
```

The text in the input. The input always shows exactly this string, so keep
it in your model and update it from `onInput`. Default: empty.

### `onInput`

```elm
onInput : (String -> msg) -> Attribute msg
```

Sends the new text each time the user changes the input, by typing,
pasting or pressing the clear button (which sends `""`). The function gets the
whole text. Store it in your model and pass it back with `value`.

    TextInput.onInput NameChanged -- NameChanged : String -> Msg

### `onEnter`

```elm
onEnter : msg -> Attribute msg
```

Sends this message when the user presses Enter in the input (without Shift,
Ctrl, Alt or Cmd). The key press is cancelled, so it does not submit a
surrounding `form`; leave `onEnter` out to let Enter submit it. The Enter that
confirms a word in an input method (Chinese, Japanese, Korean) sends nothing.

### `onBlur`

```elm
onBlur : msg -> Attribute msg
```

Sends this message when the input loses focus. A good moment to validate, so
that an error does not appear while the user is still typing.

### `onFocus`

```elm
onFocus : msg -> Attribute msg
```

Sends this message when the input gets focus.

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
To show an error only sometimes, use `errorMaybe`.

### `errorMaybe`

```elm
errorMaybe : Maybe String -> Attribute msg
```

Like `error`, but takes a `Maybe`: `Just message` shows the message and
`Nothing` shows no error. It fits the result of a validator.

    TextInput.errorMaybe (Validate.run Locale.en Validate.email model.email)

### `required`

```elm
required : Attribute msg
```

Marks the field as required: an asterisk after the label and
`aria-required` on the input. This does not validate anything; check the value
yourself and show an `error`.

### `optionalText`

```elm
optionalText : String -> Attribute msg
```

Text such as `"(optional)"` shown after the label of a field that is not
`required`. By default nothing is shown.

### `id`

```elm
id : String -> Attribute msg
```

The DOM id of the input. It must be unique on the page, because the label,
hint and error point at it. Without one, an id is made from the label (or the
placeholder, the name, the hint or the error), so two inputs with the same label
need explicit ids; an input with none of them gets no id.

## Kind of input

### `email`

```elm
email : Attribute msg
```

An email address: sets the HTML type `email`, so phones show a keyboard with
the `@` key. To check the address, use `Validate.email` from
[Klar.Validate](Klar.Validate.md).

### `tel`

```elm
tel : Attribute msg
```

A telephone number: sets the HTML type `tel`, so phones show a dial pad. The
text is not checked or reformatted.

### `url`

```elm
url : Attribute msg
```

A web address: sets the HTML type `url`, so phones show a keyboard made for
addresses. The text is not checked.

### `search`

```elm
search : Attribute msg
```

A filter box: a magnifying glass at the start of the field and the search
keyboard on phones. It is still a plain text input, and every keystroke reaches
`onInput`, which suits a list that is filtered in the browser. It replaces an
earlier prefix. For a search that waits until the user stops typing (a request
to a server), use [Klar.SearchInput](Klar.SearchInput.md).

### `verbatim`

```elm
verbatim : Attribute msg
```

For codes, not words: order numbers, SKUs, IBANs, user names. Switches off
spell checking (no red lines under `SKU-4471`), automatic capital letters and
autocorrect on phones. Default: the browser decides.

## Decoration and helpers

### `placeholder`

```elm
placeholder : String -> Attribute msg
```

Text shown inside the empty input, for example a sample value. It is not a
substitute for a `label`, and it disappears as soon as the user types. Default:
none.

### `prefixIcon`

```elm
prefixIcon : Icon.Icon -> Attribute msg
```

Shows an icon at the start of the field, inside the border. A later
`prefixIcon`, `prefixText` or `search` replaces it.

    TextInput.prefixIcon Icon.mail

### `prefixText`

```elm
prefixText : String -> Attribute msg
```

Shows a short text at the start of the field, inside the border, such as a
currency code or `"https://"`. A later `prefixIcon`, `prefixText` or `search`
replaces it.

### `suffixIcon`

```elm
suffixIcon : Icon.Icon -> Attribute msg
```

Shows an icon at the end of the field, inside the border. A later
`suffixIcon` or `suffixText` replaces it.

### `suffixText`

```elm
suffixText : String -> Attribute msg
```

Shows a short text at the end of the field, inside the border, such as a
unit (`"kg"`). A later `suffixIcon` or `suffixText` replaces it.

### `clearable`

```elm
clearable : Attribute msg
```

Shows a small clear button at the end of the field while there is text. The
button sends an empty string through `onInput`, once for each use, so it needs
`onInput`. It is not in the Tab order, its accessible name is "Clear field" (see
`locale`), and it is hidden while the field is `disabled` or `readOnly`.

### `maxLength`

```elm
maxLength : Int -> Attribute msg
```

Shows a counter such as `12/200` at the end of the line under the field. It
turns amber when the limit is near (10 characters or a tenth of the limit left,
whichever is more) and red past it, and the field is then marked invalid
(`aria-invalid`). Nothing is cut: a longer text that is typed or pasted stays,
so that the user can see it and shorten it, so check the length yourself when
the form is sent (`Validate.maxLength`). Screen readers hear "12 of 200
characters" with the field, and are told once when the text comes near the
limit, reaches it and passes it.

### `size`

```elm
size : Theme.Size -> Attribute msg
```

The size of the field: `Small` (26px high), `Medium` (32px) or `Large`
(40px) at the default density (see `Klar.Theme` for the others), from
[Klar.Theme](Klar.Theme.md). Default `Medium`.

    TextInput.size Theme.Small

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

### `autofocus`

```elm
autofocus : Attribute msg
```

Asks the browser to focus the input when it is shown (the HTML `autofocus`
attribute). Browsers honor it for one element at most, and not once the user has
started to move the focus around, so it is unreliable for an input that appears
later, in a dialog for example. To move the focus yourself, use
`Klar.focus` with the `id` of the input.

### `autocomplete`

```elm
autocomplete : String -> Attribute msg
```

The HTML `autocomplete` token. It tells the browser (and password managers)
what the field contains, such as `"email"`, `"given-name"` or `"off"`. Default:
none, so the browser decides.

### `inputMode`

```elm
inputMode : String -> Attribute msg
```

The HTML `inputmode`: which on-screen keyboard phones show, such as
`"numeric"`, `"decimal"`, `"email"`, `"tel"`, `"url"` or `"search"`. Default:
none, so the keyboard follows the type of the input.

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

The language of the built-in text: the name of the clear button ("Clear
field" in English) and what the counter of `maxLength` tells screen readers ("12
of 200 characters"). Default `Locale.default`, which is English. Texts you pass
in yourself are shown as they are.
