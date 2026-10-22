# Klar.TextArea

A multi-line text field with a label, a hint and an error message.

Import: `import Klar.TextArea as TextArea` | Group: Inputs

Types: `Resize`, `Attribute`

## Signatures

```elm
-- View
type Attribute msg  -- opaque: no constructors are exposed
view : List (Attribute msg) -> Html msg

-- Value and events
value : String -> Attribute msg
onInput : (String -> msg) -> Attribute msg
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

-- Height and resizing
type Resize = ResizeNone | ResizeVertical
rows : Int -> Attribute msg
minRows : Int -> Attribute msg
maxRows : Int -> Attribute msg
resize : Resize -> Attribute msg

-- Length, placeholder and size
maxLength : Int -> Attribute msg
placeholder : String -> Attribute msg
size : Theme.Size -> Attribute msg

-- State and browser hints
disabled : Bool -> Attribute msg
readOnly : Bool -> Attribute msg
autocomplete : String -> Attribute msg
name : String -> Attribute msg

-- Language
locale : Locale.Locale -> Attribute msg
```

## Documentation

A multi-line text field with a label, a hint and an error message.

    import Klar.TextArea as TextArea

    TextArea.view
        [ TextArea.label "Delivery note"
        , TextArea.value model.note
        , TextArea.onInput NoteChanged
        , TextArea.maxLength 500
        ]

The application owns the value, as in [Klar.TextInput](Klar.TextInput.md): the
text area shows the `value` you give it and reports every change through
`onInput`. It keeps no state of its own, so there is no `State`, `Msg` or
`update`. Enter inserts a new line; there is no `onEnter`.

`label`, `labelHidden`, `hint`, `error`, `errorMaybe`, `required`,
`optionalText` and `id` are the common field attributes. They come with the
field wrapper ([Klar.Field](Klar.Field.md)) that most Klar inputs are built on, so
they mean the same in all of them: the wrapper draws the label, the required
marker, the hint and the error message around the text area and connects them
for screen readers (`for`, `aria-describedby`, `aria-invalid`,
`aria-required`). An error message is announced when it appears.

**Height.** `rows 4` is a fixed height of four lines, and the user can drag the
corner unless you pass `resize ResizeNone`. `minRows` and `maxRows` make the
field grow with its text instead: never smaller than `minRows`, scrolling after
`maxRows`.

    TextArea.view [ TextArea.minRows 3, TextArea.maxRows 10 ]

With `maxRows` alone, the smallest height is `rows` (3 by default). Growing uses
the CSS property `field-sizing: content`. Browsers without it fall back to a
hidden copy of the text that sizes the field, so the behavior is the same
everywhere and needs no JavaScript.

**Counter.** `maxLength` limits the length and shows a counter such as `12/500`
at the end of the line under the field, level with the hint (hint on the left,
counter on the right). It turns amber when the limit is near and red when the
text is longer than the limit, and screen readers are told the count once the
limit is near.

The text area is always inside the field wrapper, also when there is no `label`,
`hint` or `error` to draw, so it does not move (and lose the keyboard focus) when
the application shows an error while the user is typing. The wrapper of a text
area with nothing to draw adds no space and no width of its own.

The only built-in text is the count read out to screen readers ("12 of 500
characters"); `locale` changes its language.

## View

### `Attribute`

```elm
type Attribute msg  -- opaque: no constructors are exposed
```

A setting of a text area. Make them with the functions below and pass a
list to `view`; later attributes win over earlier ones.

### `view`

```elm
view : List (Attribute msg) -> Html msg
```

A text area with its label, hint and error message. The value, the events
and everything else are set with attributes.

    TextArea.view
        [ TextArea.label "Comments"
        , TextArea.optionalText "(optional)"
        , TextArea.minRows 2
        , TextArea.maxRows 8
        , TextArea.value model.comments
        , TextArea.onInput CommentsChanged
        ]

## Value and events

### `value`

```elm
value : String -> Attribute msg
```

The text in the text area. It always shows exactly this string, so keep it
in your model and update it from `onInput`. Default: empty.

### `onInput`

```elm
onInput : (String -> msg) -> Attribute msg
```

Sends the new text each time the user changes the text area, by typing,
pasting or cutting. The function gets the whole text. Store it in your model and
pass it back with `value`.

    TextArea.onInput NoteChanged -- NoteChanged : String -> Msg

### `onBlur`

```elm
onBlur : msg -> Attribute msg
```

Sends this message when the text area loses focus. A good moment to
validate, so that an error does not appear while the user is still typing.

### `onFocus`

```elm
onFocus : msg -> Attribute msg
```

Sends this message when the text area gets focus.

## Label, hint and error

### `label`

```elm
label : String -> Attribute msg
```

The label shown above the field. It is connected to the text area, so
clicking it focuses the text area and screen readers read it as the name of the
text area. Give every field a label, or hide it with `labelHidden`.

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

### `required`

```elm
required : Attribute msg
```

Marks the field as required: an asterisk after the label and
`aria-required` on the text area. This does not validate anything; check the
value yourself and show an `error`.

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

The DOM id of the text area. It must be unique on the page, because the
label, hint and error point at it. Without one, an id is made from the label (or
the placeholder), so two fields with the same label need explicit ids.

## Height and resizing

### `Resize`

```elm
type Resize = ResizeNone | ResizeVertical
```

Whether the user can drag the corner of the text area to change its height:
`ResizeVertical` allows it, `ResizeNone` does not. Used with `resize`.

### `rows`

```elm
rows : Int -> Attribute msg
```

A fixed height of this many visible lines. Default 3, and never less than 1.
`minRows` and `maxRows` make the field grow instead; with `maxRows` alone this
is the smallest height.

    TextArea.rows 5

### `minRows`

```elm
minRows : Int -> Attribute msg
```

Makes the field grow with its text, but never be smaller than this many
lines (at least 1). `rows` is then ignored. Combine it with `maxRows`.

### `maxRows`

```elm
maxRows : Int -> Attribute msg
```

Makes the field grow with its text up to this many lines (at least 1), and
then scroll. If this is less than the smallest height, the smallest height wins.

### `resize`

```elm
resize : Resize -> Attribute msg
```

Whether the user can drag the corner to change the height. Default:
`ResizeVertical` for a fixed height, `ResizeNone` for a field that grows
(`minRows` or `maxRows`).

    TextArea.resize TextArea.ResizeNone

## Length, placeholder and size

### `maxLength`

```elm
maxLength : Int -> Attribute msg
```

Limits the text to this many characters (the HTML `maxlength`, so the user
cannot type more) and shows a counter such as `12/500` under the field, at the
end of the line with the hint. The counter turns amber when the limit is near
(10 characters or a tenth of the limit are left, whichever is more) and red when
the text is longer than the limit, which can happen when your `value` is.

### `placeholder`

```elm
placeholder : String -> Attribute msg
```

Text shown inside the empty text area, for example a sample value. It is not
a substitute for a `label`, and it disappears as soon as the user types.
Default: none.

### `size`

```elm
size : Theme.Size -> Attribute msg
```

The padding and text size of the field: `Small`, `Medium` or `Large`, from
[Klar.Theme](Klar.Theme.md). Default `Medium`. The height follows `rows` (or
`minRows` and `maxRows`).

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

### `autocomplete`

```elm
autocomplete : String -> Attribute msg
```

The HTML `autocomplete` token. It tells the browser what the field contains,
such as `"street-address"` or `"off"`. Default: none, so the browser decides.

### `name`

```elm
name : String -> Attribute msg
```

The HTML `name` of the text area. Browsers use it to fill in saved values,
and a native form sends the value under this name. Default: none.

## Language

### `locale`

```elm
locale : Locale.Locale -> Attribute msg
```

The language of the built-in text, which here is the count read out to
screen readers ("12 of 500 characters" in English). Default `Locale.default`,
which is English. Texts you pass in yourself are shown as they are.
