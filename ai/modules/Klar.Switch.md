# Klar.Switch

An on/off switch for a setting that takes effect at once ("Email notifications").

Import: `import Klar.Switch as Switch` | Group: Inputs

Types: `Attribute`

## Signatures

```elm
-- View
type Attribute msg  -- opaque: no constructors are exposed
view : List (Attribute msg) -> Html msg

-- Value
checked : Bool -> Attribute msg
onToggle : (Bool -> msg) -> Attribute msg
loading : Bool -> Attribute msg

-- Label and messages
label : String -> Attribute msg
description : String -> Attribute msg
error : String -> Attribute msg
ariaLabel : String -> Attribute msg

-- Look and behavior
size : Theme.Size -> Attribute msg
controlAtEnd : Attribute msg
disabled : Bool -> Attribute msg
id : String -> Attribute msg
locale : Locale.Locale -> Attribute msg
```

## Documentation

An on/off switch for a setting that takes effect at once ("Email
notifications"). Use a [Klar.Checkbox](Klar.Checkbox.md) instead when the choice is
part of a form that is saved with a button.

    import Klar.Switch as Switch

    Switch.view
        [ Switch.label "Email notifications"
        , Switch.description "You get an email when an order ships."
        , Switch.checked model.notify
        , Switch.onToggle NotifyToggled
        , Switch.loading model.saving
        ]

The application owns the value: `checked` says whether the switch is on, and
`onToggle` gets the new value when the user clicks the switch or its label, or
presses Space on it. A setting that is saved at once usually stores the new
value, marks the model as saving until the answer arrives, and sends the
request:

    NotifyToggled value ->
        ( { model | notify = value, saving = True }, saveNotify value )

It is a checkbox with `role="switch"`, so screen readers say "on" and "off".
While `loading` is `True` (the application is saving the new value) the knob
shows a spinner and the input is disabled, so neither a click nor the keyboard
can change it; the switch keeps showing the value the application gives it. The
browser takes the keyboard focus from a control that becomes disabled, so move
it back with `Browser.Dom.focus` and the `id` of the switch when the save is
done, if that matters.

The description and the error message are drawn under the label, or beside the
switch when there is no label (a switch without a label needs `ariaLabel`). Both
are joined to the switch with `aria-describedby`, and the error is read out when
it appears. A switch draws these parts itself and does not use
[Klar.Field](Klar.Field.md), so it has no `errorMaybe`, `required` or `labelHidden`.

## View

### `Attribute`

```elm
type Attribute msg  -- opaque: no constructors are exposed
```

A setting of a switch. Make them with the functions below and pass a list to
`view`; later attributes win over earlier ones.

### `view`

```elm
view : List (Attribute msg) -> Html msg
```

A switch with its label, description and error message, or bare. See the
module documentation for the attributes that matter most: `checked`,
`onToggle` and `loading`.

## Value

### `checked`

```elm
checked : Bool -> Attribute msg
```

Whether the switch is on. The default is `False`. The switch always shows
the value it is given, also while it is `loading`.

### `onToggle`

```elm
onToggle : (Bool -> msg) -> Attribute msg
```

The message sent when the user toggles the switch. It gets the new value,
`True` for on. Store it, or wait for the server to confirm it, and give it back
with `checked`.

    Switch.onToggle NotifyToggled

### `loading`

```elm
loading : Bool -> Attribute msg
```

While `True` the application is saving the change: the knob shows a
spinner, the switch announces `aria-busy` and a screen-reader-only "Saving ...",
and the input is disabled, so neither a click nor the keyboard changes it and
nothing is sent to `onToggle`. A disabled control cannot keep the keyboard focus;
move it back with `Browser.Dom.focus` (see `id`) when the save is done. Pass a
field of your model. The default is `False`.

## Label and messages

### `label`

```elm
label : String -> Attribute msg
```

The text next to the switch. A click on it toggles the switch, and it is the
accessible name of the switch. Without a label the switch is bare: give it an
`ariaLabel`.

### `description`

```elm
description : String -> Attribute msg
```

A line of gray explanation under the label (beside the switch when there is
no label), joined to the switch with `aria-describedby`. An empty text counts as
none.

### `error`

```elm
error : String -> Attribute msg
```

Marks the switch invalid (a red outline and `aria-invalid`) and shows the
message in red under the label (beside the switch when there is no label). The
message is joined to the switch with `aria-describedby`, and screen readers read
it when it appears. An empty text counts as no error, so there is never a red
outline without a message. There is no `errorMaybe`: add `error` to the list only
while there is a problem.

### `ariaLabel`

```elm
ariaLabel : String -> Attribute msg
```

The accessible name when there is no visible label. It becomes the
`aria-label` of the input.

## Look and behavior

### `size`

```elm
size : Theme.Size -> Attribute msg
```

The size of the switch and its text: `Small`, `Medium` or `Large` (see
[Klar.Theme](Klar.Theme.md)). The default is `Medium`.

### `controlAtEnd`

```elm
controlAtEnd : Attribute msg
```

Puts the switch at the far end of the row with the label first, like a
list of settings. The row fills the width of its container, so put the switch in
something wider than itself, such as a card or a stack.

### `disabled`

```elm
disabled : Bool -> Attribute msg
```

Dims the switch and makes it unchangeable and unfocusable (the HTML
`disabled` attribute). The default is `False`.

### `id`

```elm
id : String -> Attribute msg
```

The DOM id of the `input` element, for moving focus to it with
`Browser.Dom.focus`. The label, the description and the error message get the
ids `<id>-label`, `<id>-description` and `<id>-error`. Without an id it is made
from the label, or from the `ariaLabel` when there is no label, so give switches
that share a text an id each.

### `locale`

```elm
locale : Locale.Locale -> Attribute msg
```

The language of the built-in text, which is the "Saving ..." that screen
readers hear while the switch is `loading`. The default is `Locale.default`,
which is English.
