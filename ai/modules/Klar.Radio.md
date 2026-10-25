# Klar.Radio

A group of radio buttons: choose exactly one of a few options.

Import: `import Klar.Radio as Radio` | Group: Inputs

Types: `Option`, `Attribute`

## Signatures

```elm
-- View
type Attribute value msg  -- opaque: no constructors are exposed
view : List (Attribute value msg) -> Html msg

-- Options
type Option value  -- opaque: no constructors are exposed
option : value -> String -> Option value
withDescription : String -> Option value -> Option value
disabledOption : Option value -> Option value
options : List (Option value) -> Attribute value msg

-- Selection
selected : Maybe value -> Attribute value msg
onChange : (value -> msg) -> Attribute value msg

-- Label, hint and error
label : String -> Attribute value msg
labelHidden : Attribute value msg
hint : String -> Attribute value msg
error : String -> Attribute value msg
errorMaybe : Maybe String -> Attribute value msg
required : Attribute value msg
optionalText : String -> Attribute value msg
id : String -> Attribute value msg

-- Look and behavior
horizontal : Attribute value msg
size : Theme.Size -> Attribute value msg
disabled : Bool -> Attribute value msg
readOnly : Bool -> Attribute value msg
```

## Documentation

A group of radio buttons: choose exactly one of a few options.

Use when: two to five options where exactly one is chosen and people should see them all.
Do not use when: there are more options (`Klar.Select`), a one-line switch between views is wanted (`Klar.SegmentedControl`) or several may be chosen (`Klar.CheckboxGroup`).

    import Klar.Radio as Radio

    -- model:  { delivery : Delivery }   (Standard, Express, Pickup: your own type)
    Radio.view
        [ Radio.label "Delivery"
        , Radio.id "order-delivery"
        , Radio.options
            [ Radio.option Standard "Standard"
            , Radio.option Express "Express"
                |> Radio.withDescription "Delivered the next working day."
            , Radio.option Pickup "Pick up in store" |> Radio.disabledOption
            ]
        , Radio.selected (Just model.delivery)
        , Radio.onChange DeliveryChanged
        ]

    -- update
    DeliveryChanged delivery ->
        ( { model | delivery = delivery }, Cmd.none )

**The values are your own** (`Standard`, a warehouse id, an `Int`): an option is
made with its value, `selected` is the chosen value (`Nothing` for none) and
`onChange` gets the value of the option the user chooses. They are compared with
`==`, so they have to be plain data; there is nothing to convert to or from a
`String`. The application owns the choice and gives it back in `selected`; a click
changes nothing by itself. A group without `onChange` is read-only.

The group is a `fieldset` with `role="radiogroup"` whose legend is the label.
Keyboard (the browser's own radio behavior): Tab enters the group at the chosen
option, or at the first one (Shift+Tab: the last one) when none is chosen; the arrow
keys move to the next or previous option and choose it, skip disabled options and
wrap around at the ends; Space chooses the focused one.

Use a radio group when there are two to five options and people should see them
all; use a [Klar.Select](Klar.Select.md) for more. For a one-line switch between
views or modes use [Klar.SegmentedControl](Klar.SegmentedControl.md), and for
choosing several options at once [Klar.CheckboxGroup](Klar.CheckboxGroup.md).

A group takes the attributes that all form controls share (`label`, `hint`,
`error`, `required` ...; see [Klar.Field](Klar.Field.md)). Its `id` is also the
`name` that its radio buttons share, so two groups on a page need different ids.

## View

### `Attribute`

```elm
type Attribute value msg  -- opaque: no constructors are exposed
```

A setting of a radio group. Make them with the functions below and pass a
list to `view`; later attributes win over earlier ones. `value` is the type of
the values of the options (your own), `msg` the message of `onChange`.

### `view`

```elm
view : List (Attribute value msg) -> Html msg
```

A `fieldset` of radio buttons with its legend, hint and error message. See
the module documentation for the attributes that matter most: `options`,
`selected` and `onChange`.

## Options

### `Option`

```elm
type Option value  -- opaque: no constructors are exposed
```

One choice of the group: a value of your own and a text, with an optional
description, and perhaps disabled. Make one with `option`.

### `option`

```elm
option : value -> String -> Option value
```

`option Express "Express"`: the value that `onChange` gets when the option is
chosen (of your own type), and the text next to the button. The values of a
group should differ from each other.

### `withDescription`

```elm
withDescription : String -> Option value -> Option value
```

A line of gray explanation under the text of the option. A screen reader
reads it together with the option (`aria-describedby`).

    Radio.option Express "Express"
        |> Radio.withDescription "Delivered the next working day."

### `disabledOption`

```elm
disabledOption : Option value -> Option value
```

Visible but not selectable: dimmed, and the arrow keys skip it.

### `options`

```elm
options : List (Option value) -> Attribute value msg
```

The choices of the group, in the order they are shown.

## Selection

### `selected`

```elm
selected : Maybe value -> Attribute value msg
```

The value of the chosen option, or `Nothing` when none is chosen, which is
the default. A value that no option has chooses nothing.

### `onChange`

```elm
onChange : (value -> msg) -> Attribute value msg
```

The message sent when the user chooses an option, with the mouse or with the
arrow keys. It gets the value of that option; store it and give it back with
`selected`. Without it the group is read-only (see `readOnly`).

    Radio.onChange DeliveryChanged

## Label, hint and error

### `label`

```elm
label : String -> Attribute value msg
```

The legend of the group: its name, shown above the options. Give every
group one, or screen readers cannot say what the choice is for; `labelHidden`
keeps it out of sight.

### `labelHidden`

```elm
labelHidden : Attribute value msg
```

Keep the label (the legend) for screen readers only.

### `hint`

```elm
hint : String -> Attribute value msg
```

A line of help under the group, joined to it with `aria-describedby` so a
screen reader reads it with the group.

### `error`

```elm
error : String -> Attribute value msg
```

Shows an error message in red under the group and marks it invalid: the
buttons get a red border and the group gets `aria-invalid`. Screen readers read
the message when it appears.

### `errorMaybe`

```elm
errorMaybe : Maybe String -> Attribute value msg
```

Like `error`, for a message that may not be there: `Nothing` shows no
error. It goes well with `Validate.errorFor`.

    Radio.errorMaybe (Validate.errorFor "order-delivery" errors)

### `required`

```elm
required : Attribute value msg
```

Marks the group as required: a `*` after the legend and `aria-required` on
the group. It only marks the group and checks nothing.

### `optionalText`

```elm
optionalText : String -> Attribute value msg
```

Text shown after the legend of a group that is not required, such as
"(optional)". There is no built-in text: without this, an optional group gets
no mark.

### `id`

```elm
id : String -> Attribute value msg
```

The DOM id of the group. Its chosen radio button, or the first one that can
be chosen when none is, gets this id, so an error summary can move focus to the
group (when no option can take the focus, the `fieldset` gets it). It is also the
`name` that all the radio buttons share, which is what makes them one group for
the browser.

Without it the group gets an id made from its label and the texts of its
options. That is enough for most pages, but two groups with the same label and
the same option texts on one page (in the rows of a table, say) would be one
group, where choosing in one clears the other: give such groups an id each.

## Look and behavior

### `horizontal`

```elm
horizontal : Attribute value msg
```

Lay the options out in a row, which wraps when there is not enough room,
instead of in a column.

### `size`

```elm
size : Theme.Size -> Attribute value msg
```

The size of the radio buttons and their text: `Small`, `Medium` or `Large`
(see [Klar.Theme](Klar.Theme.md)). The default is `Medium`.

### `disabled`

```elm
disabled : Bool -> Attribute value msg
```

Disables the whole group: dimmed, skipped by Tab, and nothing can be chosen.
The default is `False`.

### `readOnly`

```elm
readOnly : Bool -> Attribute value msg
```

Shows the choice without letting the user change it, for a record the user
may read but not edit. Unlike `disabled` it is not dimmed, and Tab still reaches
the chosen option, so a screen reader can read it ("Express, radio button,
checked"); the group has `aria-readonly`, and the other options cannot be chosen
with the mouse or the arrow keys: they are disabled, so screen readers call them
unavailable, but they are not dimmed. When nothing is chosen, Tab reaches the
group itself. Nothing is sent to `onChange`. The default is `False`.
