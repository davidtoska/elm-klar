# Klar.Field

The wrapper around a form control: a label, a required or optional mark, a hint and an error message, joined to the control for screen readers.

Import: `import Klar.Field as Field` | Group: Forms

Types: `Config`

## Signatures

```elm
-- Wrapping a control
view : Config -> Html msg -> Html msg
viewWithAside : Config -> Html msg -> Html msg -> Html msg
viewGroup : Config -> Html msg -> Html msg

-- Describing the field
type alias Config =
    { id : String
    , label : Maybe String
    , hint : Maybe String
    , error : Maybe String
    , required : Bool
    , optionalText : Maybe String
    , labelHidden : Bool
    }
empty : Config
setId : String -> Config -> Config
setLabel : String -> Config -> Config
setLabelHidden : Config -> Config
setHint : String -> Config -> Config
setError : Maybe String -> Config -> Config
setRequired : Bool -> Config -> Config
setOptionalText : String -> Config -> Config

-- Wiring the control
controlAttributes : Config -> List (Html.Attribute msg)
describedByAttributes : Config -> List (Html.Attribute msg)
labelId : Config -> String
hintId : Config -> String
```

## Documentation

The wrapper around a form control: a label, a required or optional mark, a
hint and an error message, joined to the control for screen readers.

Use when: you build a custom control that should look and behave like the other fields (label, hint, error).
Do not use when: you use a control from this package such as `Klar.TextInput` or `Klar.Select`; they wrap themselves in a field.

The inputs of this package (`TextInput`, `Select`, `DatePicker`, `Radio`,
`Slider` ...) wrap themselves in a field, so an application seldom calls this
module. It uses the attributes these controls have in common instead:

    import Klar.Locale as Locale
    import Klar.TextInput as TextInput
    import Klar.Validate as Validate

    TextInput.view
        [ TextInput.id "order-customer"
        , TextInput.label "Customer"
        , TextInput.hint "As it should appear on the invoice."
        , TextInput.required
        , TextInput.value model.customer
        , TextInput.onInput CustomerChanged
        , TextInput.errorMaybe (Validate.errorFor "order-customer" model.errors)
        ]

`label` is the text above the control (`labelHidden` keeps it for screen
readers only), `hint` a line of help under it, and `error` (or `errorMaybe`)
the message about a problem, in red under the control. `required` puts a `*`
after the label, and `optionalText` writes something like "(optional)" after
the label of a field that is not required. `id` is the DOM id of the control:
give every control its own, because the ids of the other parts are made from it
and the error summary of [Klar.Form.Layout](Klar.Form.Layout.md) moves focus to a control by its
id. [Klar.Checkbox](Klar.Checkbox.md) and [Klar.Switch](Klar.Switch.md) draw their
label, hint and error beside the box themselves and do not use this module.

A field shows what it is told and checks nothing. `required` only adds the mark
and `aria-required`; deciding when a value is wrong is the job of the
application. [Klar.Validate](Klar.Validate.md) turns values into a list of
problems, each the `id` of a control and a message, and `Validate.errorFor` picks
the message of one control, as above:

    validate : Model -> List Validate.Problem
    validate model =
        Validate.collect Locale.default
            [ ( "order-customer", [ Validate.required ], model.customer )
            , ( "order-email", [ Validate.required, Validate.email ], model.email )
            ]

Call it when the user submits or leaves a control, keep the result in the model
(`model.errors` above), hand each message to its control, and drop it when the
value is fixed. [Klar.Form.Layout](Klar.Form.Layout.md) turns the same list of problems into an
error summary at the top of the form and shows the state of the submit; its
documentation walks through a whole form.

**What screen readers get.** The wrapper joins the parts together:

  - the label is a `label` element for the `id` of the control;
  - `aria-describedby` on the control names the hint and the error message;
  - `aria-invalid` is `true` while there is an error;
  - `aria-required` is `true` on a required field, and the `*` is hidden from
    screen readers;
  - the error message has `role="alert"`, so it is read out when it appears.

The label, the hint and the error message get the ids `<id>-label`,
`<id>-hint` and `<id>-error`. ARIA lets only some roles carry `aria-invalid` and
`aria-required`, so a group of checkboxes (`role="group"`) is joined to its hint
and error message with `aria-describedby` alone (`describedByAttributes`).

**Which view.** Every view always draws the wrapper, also around a control with
no label, no hint and no error, and the control keeps its place in it when a
hint or an error comes and goes. (A control that moved into a wrapper when its
first error appeared would be rebuilt by the browser, and the keyboard focus in
it would drop to the page.) `view` draws the label of the field; a control that
draws its own label, like a group with a legend, uses `viewGroup`; and a control
with something small at the end of the line under it, like a character counter,
uses `viewWithAside`. A blank hint or error (`""`) counts as none, so there is
never an empty message, nor a field marked invalid without one.

**A control of your own.** Describe the field, put `controlAttributes` on the
element that takes the keyboard focus, and wrap it:

    import Html exposing (Html)
    import Html.Attributes as Attr
    import Html.Events as Events
    import Klar.Field as Field

    quantityField : Model -> Html Msg
    quantityField model =
        let
            field =
                Field.empty
                    |> Field.setId "order-quantity"
                    |> Field.setLabel "Quantity"
                    |> Field.setRequired True
                    |> Field.setError model.quantityError
        in
        Field.view field
            (Html.input
                (Field.controlAttributes field
                    ++ [ Attr.type_ "number"
                       , Attr.value model.quantity
                       , Events.onInput QuantityChanged
                       ]
                )
                []
            )

A control that draws a part of the field itself, such as a file drop that shows
the hint above its drop zone, gives that element the matching id (`hintId` or
`labelId`) and wraps with the part removed: `Field.view { field | hint = Nothing } control`.
Build `controlAttributes` from the complete config, so that `aria-describedby`
still points at the hint.

## Wrapping a control

### `view`

```elm
view : Config -> Html msg -> Html msg
```

Wraps a control in its field: the label (with the `*` of a required field
or the optional text), the control, then the hint and the error message. The
wrapper is always drawn, also when the field has no label, no hint and no error,
so the control stays where it is when an error comes and goes and keeps the
keyboard focus.

### `viewWithAside`

```elm
viewWithAside : Config -> Html msg -> Html msg -> Html msg
```

Like `view`, with something small at the end of the row under the control,
level with the hint and the error message: a character counter, for example.
That extra element is the second argument, the control the third.

    Field.viewWithAside field (Html.text "12/200") control

### `viewGroup`

```elm
viewGroup : Config -> Html msg -> Html msg
```

For a control that draws its own label, like a group of radio buttons with
a legend: the label is not drawn here (give the element that shows it the id
`labelId`), and the hint and the error message are, under the control. Like
`view`, it always draws the wrapper, so the control is not rebuilt when an error
comes and goes (choosing a radio button with the arrow keys clears the error,
and the focus stays on the button).

## Describing the field

### `Config`

```elm
type alias Config =
    { id : String
    , label : Maybe String
    , hint : Maybe String
    , error : Maybe String
    , required : Bool
    , optionalText : Maybe String
    , labelHidden : Bool
    }
```

Everything a field knows about its control: the DOM `id`, the `label`, the
`hint` and the `error` text (each may be missing), whether the control is
`required`, the `optionalText` that follows the label of an optional field, and
whether the label is hidden (`labelHidden`). Start from `empty` and change it
with the `set...` functions; a control keeps one in its own configuration.

### `empty`

```elm
empty : Config
```

A field with nothing in it: no label, hint or error, not required, and an
empty `id`. Give it an id with `setId` before you use it, because the label,
the hint and the error message are joined to the control through that id.

### `setId`

```elm
setId : String -> Config -> Config
```

The DOM id of the control, unique on the page. The label points at it, and
the ids of the label, the hint and the error message are made from it
(`<id>-label`, `<id>-hint` and `<id>-error`).

### `setLabel`

```elm
setLabel : String -> Config -> Config
```

The text of the label, drawn above the control and joined to it with `for`.
Without a label the control needs another accessible name.

### `setLabelHidden`

```elm
setLabelHidden : Config -> Config
```

Hide the label visually but keep it for screen readers, for a control whose
purpose is clear from what surrounds it, such as a search box in a toolbar. The
label itself still comes from `setLabel`.

### `setHint`

```elm
setHint : String -> Config -> Config
```

A line of help under the control. It is joined to the control with
`aria-describedby`, so a screen reader reads it together with the control. A
blank text counts as no hint.

### `setError`

```elm
setError : Maybe String -> Config -> Config
```

`Just message` shows the message in red under the control, marks the
control invalid (`aria-invalid`) and has screen readers read the message when it
appears (`role="alert"`). `Nothing` clears the error, and so does a blank
message (`Just ""`): a field is never marked invalid without a message to say why.

### `setRequired`

```elm
setRequired : Bool -> Config -> Config
```

Marks the field as required: a `*` after the label and `aria-required` on
the control. It only marks the field and checks nothing. The default is
`False`.

### `setOptionalText`

```elm
setOptionalText : String -> Config -> Config
```

Text shown after the label of a field that is not required, such as
"(optional)". There is no built-in text: without this, an optional field gets
no mark. A required field never shows it.

## Wiring the control

### `controlAttributes`

```elm
controlAttributes : Config -> List (Html.Attribute msg)
```

The attributes the control itself needs: its `id`, `aria-describedby` (the
hint and the error message, when there are some), `aria-invalid` (while there is
an error) and `aria-required` (on a required field). Put them on the element
that takes the keyboard focus, the one the label belongs to.

ARIA allows `aria-invalid` and `aria-required` only on some roles: both on
`textbox`, `combobox`, `spinbutton`, `listbox` and `radiogroup`, for example, but
neither on a plain `group`, and `aria-required` not on a `slider`. For an element
with such a role use `describedByAttributes` and add the ones its role allows.

### `describedByAttributes`

```elm
describedByAttributes : Config -> List (Html.Attribute msg)
```

Only the `aria-describedby` attribute of `controlAttributes`: it names the
hint and the error message that the field has, and the list is empty when it has
neither. Use it for an element whose role does not allow `aria-invalid` or
`aria-required`, such as the wrapper of a group of checkboxes (`role="group"`),
and give the attributes that the role does allow yourself.

### `labelId`

```elm
labelId : Config -> String
```

The DOM id of the label element (`<id>-label`), for `aria-labelledby`. A
control that draws its own label (see `viewGroup`) gives its element this id.

### `hintId`

```elm
hintId : Config -> String
```

The DOM id of the hint paragraph (`<id>-hint`); `aria-describedby` on the
control points at it. A control that draws the hint itself gives its element
this id.
