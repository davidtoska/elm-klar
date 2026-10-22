# Klar.Radio

A group of radio buttons: choose exactly one of a few options.

Import: `import Klar.Radio as Radio` | Group: Inputs

Types: `Option`, `Attribute`

## Signatures

```elm
-- View
type Attribute msg  -- opaque: no constructors are exposed
view : List (Attribute msg) -> Html msg

-- Options
type Option  -- opaque: no constructors are exposed
option : String -> String -> Option
withDescription : String -> Option -> Option
disabledOption : Option -> Option
options : List Option -> Attribute msg

-- Selection
selected : Maybe String -> Attribute msg
onSelect : (String -> msg) -> Attribute msg

-- Label, hint and error
label : String -> Attribute msg
labelHidden : Attribute msg
hint : String -> Attribute msg
error : String -> Attribute msg
errorMaybe : Maybe String -> Attribute msg
required : Attribute msg
optionalText : String -> Attribute msg
id : String -> Attribute msg

-- Look
horizontal : Attribute msg
size : Theme.Size -> Attribute msg
disabled : Bool -> Attribute msg
```

## Documentation

A group of radio buttons: choose exactly one of a few options.

    import Klar.Radio as Radio

    Radio.view
        [ Radio.label "Delivery"
        , Radio.id "order-delivery"
        , Radio.options
            [ Radio.option "standard" "Standard"
            , Radio.option "express" "Express"
                |> Radio.withDescription "Delivered the next working day."
            , Radio.option "pickup" "Pick up in store" |> Radio.disabledOption
            ]
        , Radio.selected (Just model.delivery)
        , Radio.onSelect DeliveryChanged
        ]

The application owns the selection: `selected` says which option is chosen
(`Nothing` for none) and `onSelect` gets the value of the option the user
chooses. The group is a `fieldset` with `role="radiogroup"` whose legend is the
label. Keyboard: Tab enters the group at the chosen option (or the first one when
none is chosen), the arrow keys move to the neighboring option and choose it
(the browser's own radio behavior), and Space chooses the focused one.

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
type Attribute msg  -- opaque: no constructors are exposed
```

A setting of a radio group. Make them with the functions below and pass a
list to `view`; later attributes win over earlier ones.

### `view`

```elm
view : List (Attribute msg) -> Html msg
```

A `fieldset` of radio buttons with its legend, hint and error message. See
the module documentation for the attributes that matter most: `options`,
`selected` and `onSelect`.

## Options

### `Option`

```elm
type Option  -- opaque: no constructors are exposed
```

One choice of the group: a value and a text, with an optional description,
and perhaps disabled. Make one with `option`.

### `option`

```elm
option : String -> String -> Option
```

`option "express" "Express"`: the value that `onSelect` gets when the option
is chosen, and the text next to the button. The values of a group should differ
from each other.

### `withDescription`

```elm
withDescription : String -> Option -> Option
```

A line of gray explanation under the text of the option. A screen reader
reads it together with the option (`aria-describedby`).

    Radio.option "express" "Express"
        |> Radio.withDescription "Delivered the next working day."

### `disabledOption`

```elm
disabledOption : Option -> Option
```

Visible but not selectable: dimmed, and the arrow keys skip it.

### `options`

```elm
options : List Option -> Attribute msg
```

The choices of the group, in the order they are shown.

## Selection

### `selected`

```elm
selected : Maybe String -> Attribute msg
```

The value of the chosen option, or `Nothing` when none is chosen, which is
the default.

### `onSelect`

```elm
onSelect : (String -> msg) -> Attribute msg
```

The message sent when the user chooses an option, with the mouse or with the
arrow keys. It gets the value of that option; store it and give it back with
`selected`. Without it the group sends nothing.

## Label, hint and error

### `label`

```elm
label : String -> Attribute msg
```

The legend of the group: its name, shown above the options. Give every
group one, or screen readers cannot say what the choice is for; `labelHidden`
keeps it out of sight.

### `labelHidden`

```elm
labelHidden : Attribute msg
```

Keep the label (the legend) for screen readers only.

### `hint`

```elm
hint : String -> Attribute msg
```

A line of help under the group, joined to it with `aria-describedby` so a
screen reader reads it with the group.

### `error`

```elm
error : String -> Attribute msg
```

Shows an error message in red under the group and marks it invalid: the
buttons get a red border and the group gets `aria-invalid`. Screen readers read
the message when it appears.

### `errorMaybe`

```elm
errorMaybe : Maybe String -> Attribute msg
```

Like `error`, for a message that may not be there: `Nothing` shows no
error. It goes well with `Validate.errorFor`.

    Radio.errorMaybe (Validate.errorFor "order-delivery" errors)

### `required`

```elm
required : Attribute msg
```

Marks the group as required: a `*` after the legend and `aria-required` on
the group. It only marks the group and checks nothing.

### `optionalText`

```elm
optionalText : String -> Attribute msg
```

Text shown after the legend of a group that is not required, such as
"(optional)". There is no built-in text: without this, an optional group gets
no mark.

### `id`

```elm
id : String -> Attribute msg
```

The DOM id of the group. Its chosen radio button, or the first one that can
be chosen when none is, gets this id, so an error summary can move focus to the
group. It is also the `name` that all the radio buttons share, which is what
makes them one group for the browser.

Without it the group gets an id made from its label and the values of its
options. That is enough for most pages, but two groups with the same label and
the same option values on one page would be one group (choosing in one would
unselect the other): give such groups an id each.

## Look

### `horizontal`

```elm
horizontal : Attribute msg
```

Lay the options out in a row, which wraps when there is not enough room,
instead of in a column.

### `size`

```elm
size : Theme.Size -> Attribute msg
```

The size of the radio buttons and their text: `Small`, `Medium` or `Large`
(see [Klar.Theme](Klar.Theme.md)). The default is `Medium`.

### `disabled`

```elm
disabled : Bool -> Attribute msg
```

Disables the whole group. The default is `False`.
