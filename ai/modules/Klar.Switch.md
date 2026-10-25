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
onCheck : (Bool -> msg) -> Attribute msg
loading : Bool -> Attribute msg

-- Label and messages
label : String -> Attribute msg
hint : String -> Attribute msg
error : String -> Attribute msg
errorMaybe : Maybe String -> Attribute msg
ariaLabel : String -> Attribute msg

-- Look and behavior
size : Theme.Size -> Attribute msg
controlAtEnd : Attribute msg
disabled : Bool -> Attribute msg
readOnly : Bool -> Attribute msg
id : String -> Attribute msg
locale : Locale.Locale -> Attribute msg
```

## Documentation

An on/off switch for a setting that takes effect at once ("Email
notifications"). Use a [Klar.Checkbox](Klar.Checkbox.md) instead when the choice is
part of a form that is saved with a button.

Use when: an on/off setting that takes effect at once, such as email notifications.
Do not use when: the choice is part of a form that is saved with a button (`Klar.Checkbox`).

    import Klar.Switch as Switch

    Switch.view
        [ Switch.label "Email notifications"
        , Switch.hint "You get an email when an order ships."
        , Switch.checked model.notify
        , Switch.onCheck NotifyChecked
        , Switch.loading model.saving
        , Switch.errorMaybe model.notifyError
        ]

The application owns the value: `checked` says whether the switch is on, and
`onCheck` gets the new value when the user clicks the switch or its label, or
presses Space on it. A setting that is saved at once stores the new value, marks
the model as saving until the answer arrives, and sends the request; when the
save fails it puts the old value back and says why:

    NotifyChecked value ->
        if value == model.notify then
            -- pressed again while the last change is being saved
            ( model, Cmd.none )

        else
            ( { model | notify = value, saving = True, notifyError = Nothing }, saveNotify value )

    NotifySaved (Ok ()) ->
        ( { model | saving = False }, Cmd.none )

    NotifySaved (Err _) ->
        ( { model | notify = not model.notify, saving = False, notifyError = Just "Could not save. Try again." }
        , Cmd.none
        )

It is a checkbox with `role="switch"`, so screen readers say "on" and "off".
While `loading` is `True` (the application is saving the new value) the knob
shows a spinner, screen readers hear "Saving ...", and neither a click nor Space
changes the switch: it keeps showing the value the application gives it, and it
keeps the keyboard focus.

The hint and the error message are drawn under the label, or beside the switch
when there is no label (a switch without a label needs `ariaLabel`). Both are
joined to the switch with `aria-describedby`, and the error is read out when it
appears. A switch draws these parts itself and does not use
[Klar.Field](Klar.Field.md); it has the same `hint`, `error` and `errorMaybe` as the
fields, and `ariaLabel` instead of `labelHidden`.

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

A switch with its label, hint and error message, or bare. See the module
documentation for the attributes that matter most: `checked`, `onCheck` and
`loading`.

## Value

### `checked`

```elm
checked : Bool -> Attribute msg
```

Whether the switch is on. The default is `False`. The switch always shows
the value it is given, also while it is `loading`.

### `onCheck`

```elm
onCheck : (Bool -> msg) -> Attribute msg
```

The message sent when the user toggles the switch. It gets the new value,
`True` for on. Store it, or wait for the server to confirm it, and give it back
with `checked`.

    Switch.onCheck NotifyChecked

### `loading`

```elm
loading : Bool -> Attribute msg
```

While `True` the application is saving the change: the knob shows a
spinner, the switch announces `aria-busy`, a screen-reader-only "Saving ..." is
read out, and the switch is `aria-disabled`: a click or Space changes nothing.
The switch keeps the keyboard focus, so a keyboard user can go on from it. A
click or Space while saving sends the value the switch already has to `onCheck`,
so compare it with your model before you save again (see the module example).
Pass a field of your model. The default is `False`.

## Label and messages

### `label`

```elm
label : String -> Attribute msg
```

The text next to the switch. A click on it toggles the switch, and it is the
accessible name of the switch. Without a label the switch is bare: give it an
`ariaLabel`.

### `hint`

```elm
hint : String -> Attribute msg
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
outline without a message.

### `errorMaybe`

```elm
errorMaybe : Maybe String -> Attribute msg
```

Like `error`, for a message that may not be there: `Nothing` shows no
error, such as the reason the last save failed.

    Switch.errorMaybe model.notifyError

### `ariaLabel`

```elm
ariaLabel : String -> Attribute msg
```

The accessible name when there is no visible label, such as "Active" in the
row of a table. It becomes the `aria-label` of the switch.

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

### `readOnly`

```elm
readOnly : Bool -> Attribute msg
```

Shows the setting without letting the user change it, for a user who may not
change it. Unlike `disabled` it is not dimmed, and Tab still reaches it, so a
screen reader can read it ("Email notifications, switch, on, read only"); a click
or Space changes nothing and nothing is sent to `onCheck`. The switch is then an
element with `role="switch"`, `aria-checked` and `aria-readonly` instead of a
native checkbox, with the same `id`. `disabled` wins over it. The default is
`False`.

### `id`

```elm
id : String -> Attribute msg
```

The DOM id of the switch, for moving focus to it with `Klar.focus`. No id is
set by default. The label, the hint and the error message get the ids
`<id>-label`, `<id>-description` and `<id>-error`. Without an id they are made
from the label (or the `ariaLabel`), so give switches that share a text and show
a hint or an error (the rows of a table) an id each.

### `locale`

```elm
locale : Locale.Locale -> Attribute msg
```

The language of the built-in text, which is the "Saving ..." that screen
readers hear while the switch is `loading`. The default is `Locale.default`,
which is English.
