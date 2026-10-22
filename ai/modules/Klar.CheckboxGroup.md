# Klar.CheckboxGroup

A group of checkboxes: choose any number of the options.

Import: `import Klar.CheckboxGroup as CheckboxGroup` | Group: Inputs

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
selected : List String -> Attribute msg
onChange : (List String -> msg) -> Attribute msg
selectAll : Attribute msg
selectAllLabel : String -> Attribute msg

-- Label, hint and error
label : String -> Attribute msg
labelHidden : Attribute msg
hint : String -> Attribute msg
error : String -> Attribute msg
errorMaybe : Maybe String -> Attribute msg
required : Attribute msg
optionalText : String -> Attribute msg
id : String -> Attribute msg

-- Look and language
horizontal : Attribute msg
size : Theme.Size -> Attribute msg
disabled : Bool -> Attribute msg
locale : Locale.Locale -> Attribute msg
```

## Documentation

A group of checkboxes: choose any number of the options.

    import Klar.CheckboxGroup as CheckboxGroup

    CheckboxGroup.view
        [ CheckboxGroup.label "Extras"
        , CheckboxGroup.options
            [ CheckboxGroup.option "gift-wrap" "Gift wrap"
            , CheckboxGroup.option "paper-invoice" "Paper invoice"
            , CheckboxGroup.option "insurance" "Shipping insurance"
                |> CheckboxGroup.withDescription "Covers loss and damage up to 500."
            ]
        , CheckboxGroup.selected model.extras
        , CheckboxGroup.onChange ExtrasChanged
        , CheckboxGroup.selectAll
        ]

The application owns the selection. `selected` is the list of the values of the
checked options (a `List String` in the model), and `onChange` gets the whole
new selection, in the order of the options, so the application just stores it.
`selectAll` adds a "Select all" checkbox on top that is checked when every
option is, shows a dash when only some are, and checks or clears all of them;
it leaves disabled options as they are.

The group is a `fieldset` whose legend is the label, and each option is a
[Klar.Checkbox](Klar.Checkbox.md). It takes the attributes that all form controls
share (`label`, `hint`, `error`, `required` ...; see [Klar.Field](Klar.Field.md)),
and the first checkbox that can be changed carries the `id` of the group, so
the error summary of [Klar.Form](Klar.Form.md) can move focus into it.

Use a group for a handful of options that people should see all at once. For
exactly one choice use [Klar.Radio](Klar.Radio.md), and for a long list, which
needs a search box, [Klar.MultiSelect](Klar.MultiSelect.md).

## View

### `Attribute`

```elm
type Attribute msg  -- opaque: no constructors are exposed
```

A setting of a checkbox group. Make them with the functions below and pass
a list to `view`; later attributes win over earlier ones.

### `view`

```elm
view : List (Attribute msg) -> Html msg
```

A `fieldset` of checkboxes with its legend, hint and error message. See the
module documentation for the attributes that matter most: `options`, `selected`
and `onChange`.

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

`option "gift-wrap" "Gift wrap"`: the value that ends up in the selection
when the box is checked, and the text next to the box. The values of a group
should differ from each other.

### `withDescription`

```elm
withDescription : String -> Option -> Option
```

A line of gray explanation under the text of the option.

    CheckboxGroup.option "insurance" "Shipping insurance"
        |> CheckboxGroup.withDescription "Covers loss and damage up to 500."

### `disabledOption`

```elm
disabledOption : Option -> Option
```

Visible but not changeable: the user cannot check or uncheck it, and
`selectAll` leaves its value in the selection or out of it, as it was.

### `options`

```elm
options : List Option -> Attribute msg
```

The choices of the group, in the order they are shown.

## Selection

### `selected`

```elm
selected : List String -> Attribute msg
```

The values of the checked options. A value that no option has is not shown,
but it stays in the selection that `onChange` sends. The default is the empty
list.

### `onChange`

```elm
onChange : (List String -> msg) -> Attribute msg
```

The message sent when a checkbox (or the select-all box) is changed. It gets
the complete new selection, in the order of the options (values that no option
has come last), so the application can store it as it is. Without it the
checkboxes send nothing.

### `selectAll`

```elm
selectAll : Attribute msg
```

Adds a "Select all" checkbox above the options. It is checked when every
option that can be changed is checked, shows a dash when only some are, and
checks or clears all of them with one click. Options made with `disabledOption`
keep their state. The text is "Select all" in English; `selectAllLabel` changes
it.

### `selectAllLabel`

```elm
selectAllLabel : String -> Attribute msg
```

Replaces the built-in "Select all" text of the select-all checkbox. This
also switches `selectAll` on.

    CheckboxGroup.selectAllLabel "All extras"

## Label, hint and error

### `label`

```elm
label : String -> Attribute msg
```

The legend of the group: its name, shown above the options. Give every
group one, or screen readers cannot say what the choices are for; `labelHidden`
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

Shows an error message in red under the group and marks it: the empty boxes
get a red border. Screen readers read the message when it appears and with the
group afterwards (`aria-describedby`); a plain group has no `aria-invalid`.

### `errorMaybe`

```elm
errorMaybe : Maybe String -> Attribute msg
```

Like `error`, for a message that may not be there: `Nothing` shows no
error. It goes well with `Validate.errorFor`.

    CheckboxGroup.errorMaybe (Validate.errorFor "order-extras" errors)

### `required`

```elm
required : Attribute msg
```

Marks the group as required with a `*` after the legend. It is a visual mark
and checks nothing: ARIA has no required state for a group of checkboxes, so
tell screen reader users in the `hint` too ("Choose at least one").

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

The DOM id of the group. Its first checkbox that can be changed gets this
id, so an error summary can move focus into the group; the other checkboxes get
`<id>-<position>` (counting from 0) and the fieldset gets `<id>-group`.

Without it the id is made from the label and the values of the options. That is
enough unless two groups on a page have both the same: give those an id each.

## Look and language

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

The size of the checkboxes: `Small`, `Medium` or `Large` (see
[Klar.Theme](Klar.Theme.md)). The default is `Medium`.

### `disabled`

```elm
disabled : Bool -> Attribute msg
```

Disables the whole group, including the select-all box. The default is
`False`.

### `locale`

```elm
locale : Locale.Locale -> Attribute msg
```

The language of the built-in text, which is the label of the select-all box.
The default is `Locale.default`, which is English.
