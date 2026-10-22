# Klar.Checkbox

A checkbox, with a label or bare.

Import: `import Klar.Checkbox as Checkbox` | Group: Inputs

Types: `Attribute`

## Signatures

```elm
-- View
type Attribute msg  -- opaque: no constructors are exposed
view : List (Attribute msg) -> Html msg

-- Value
checked : Bool -> Attribute msg
indeterminate : Bool -> Attribute msg
onCheck : (Bool -> msg) -> Attribute msg

-- Label, hint and error
label : String -> Attribute msg
hint : String -> Attribute msg
error : String -> Attribute msg
ariaLabel : String -> Attribute msg

-- Look and behavior
size : Theme.Size -> Attribute msg
disabled : Bool -> Attribute msg
tabIndex : Int -> Attribute msg
id : String -> Attribute msg
```

## Documentation

A checkbox, with a label or bare.

Use when: a yes or no choice that is saved together with the rest of a form, or a bare box in a table row.
Do not use when: the setting takes effect at once (`Klar.Switch`) or several related choices share one label (`Klar.CheckboxGroup`).

    import Klar.Checkbox as Checkbox

    Checkbox.view
        [ Checkbox.label "Send me the monthly newsletter"
        , Checkbox.hint "At most one email a month."
        , Checkbox.checked model.newsletter
        , Checkbox.onCheck NewsletterChanged
        ]

The application owns the value: `checked` says whether the box is checked, and
`onCheck` gets the new value when the user clicks the box or its label, or
presses Space on it. Keep it in the model, like the text of an input. It is a
native checkbox, so Tab reaches it and Space toggles it.

Use a checkbox for a choice that is saved together with the rest of a form. A
setting that takes effect at once is a [Klar.Switch](Klar.Switch.md), and several
related choices that share one label and one error message are a
[Klar.CheckboxGroup](Klar.CheckboxGroup.md).

A checkbox without a label is "bare", as in the rows of [Klar.Table](Klar.Table.md)
or a "select all" header, and needs `ariaLabel` for its accessible name.
`indeterminate` shows a dash instead of a check for "some selected"; a click on
such a box sends `True`, because that is what "select all" is expected to do.

    Checkbox.view
        [ Checkbox.ariaLabel "Select all orders"
        , Checkbox.checked allSelected
        , Checkbox.indeterminate (someSelected && not allSelected)
        , Checkbox.onCheck AllOrdersToggled
        ]

The hint and the error message are drawn under the label, or beside the box when
there is no label (then the checkbox needs `ariaLabel`). Both are joined to the
checkbox with `aria-describedby`, the error is read out when it appears, and the
accessible name stays the label alone. A checkbox draws these itself and does not
use [Klar.Field](Klar.Field.md), so it has no `errorMaybe`, `required` or
`labelHidden`.

## View

### `Attribute`

```elm
type Attribute msg  -- opaque: no constructors are exposed
```

A setting of a checkbox. Make them with the functions below and pass a list
to `view`; later attributes win over earlier ones.

### `view`

```elm
view : List (Attribute msg) -> Html msg
```

A single checkbox. The box, its label, hint and error message are one
`label` element, so clicking the text toggles the box. Without any of that text
the checkbox is bare.

    Checkbox.view
        [ Checkbox.label "I accept the terms of delivery"
        , Checkbox.checked model.accepted
        , Checkbox.onCheck TermsAccepted
        ]

## Value

### `checked`

```elm
checked : Bool -> Attribute msg
```

Whether the box is checked. The default is `False`. While the box is
`indeterminate` it shows a dash, whatever this says.

### `indeterminate`

```elm
indeterminate : Bool -> Attribute msg
```

Shows a dash instead of a check, for "some selected". The box is the native
"indeterminate" state of a checkbox, which assistive technology announces as
"mixed". A click on an indeterminate box sends `True` to `onCheck`, because that is
what "select all" is expected to do. The default is `False`.

### `onCheck`

```elm
onCheck : (Bool -> msg) -> Attribute msg
```

The message sent when the user toggles the box. It gets the new value,
`True` for checked; store it and give it back with `checked`.

    Checkbox.onCheck NewsletterChanged

## Label, hint and error

### `label`

```elm
label : String -> Attribute msg
```

The text next to the box; a click on it toggles the checkbox. Without a
label the checkbox is bare: give it an `ariaLabel`.

### `hint`

```elm
hint : String -> Attribute msg
```

A line of gray explanation under the label (beside the box when there is no
label), joined to the checkbox with `aria-describedby`. An empty text counts as
none.

### `error`

```elm
error : String -> Attribute msg
```

Marks the checkbox invalid (a red box and `aria-invalid`) and shows the
message in red under the label (beside the box when there is no label). The
message is joined to the checkbox with `aria-describedby`, and screen readers
read it when it appears. An empty text counts as no error, so there is never a
red box without a message. There is no `errorMaybe`: add `error` to the list only
while there is a problem.

### `ariaLabel`

```elm
ariaLabel : String -> Attribute msg
```

The accessible name when there is no visible label, such as "Select all
orders" or "Select order 1042". It becomes the `aria-label` of the input.

## Look and behavior

### `size`

```elm
size : Theme.Size -> Attribute msg
```

The size of the box and its label: `Small`, `Medium` or `Large` (see
[Klar.Theme](Klar.Theme.md)). The default is `Medium`.

### `disabled`

```elm
disabled : Bool -> Attribute msg
```

Dims the checkbox and makes it unchangeable and unfocusable (the HTML
`disabled` attribute). The default is `False`.

### `tabIndex`

```elm
tabIndex : Int -> Attribute msg
```

The `tabindex` of the input. `-1` takes the checkbox out of the tab order
(it can still be clicked and focused by script), for a list of checkboxes that
is reached some other way, like the rows of [Klar.Table](Klar.Table.md), where the
arrow keys move between rows. Without it the browser decides: a checkbox is
reached with Tab.

### `id`

```elm
id : String -> Attribute msg
```

The DOM id of the `input` element, for moving focus to it with
`Browser.Dom.focus`. No id is set by default. The hint and the error message get
the ids `<id>-description` and `<id>-error`, and the label text `<id>-label`
while there is a hint or an error to leave out of the name. Without an id they
are made from the label (or the `ariaLabel`), so give checkboxes that share a
text and show a hint or an error an id each.
