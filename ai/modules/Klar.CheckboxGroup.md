# Klar.CheckboxGroup

A group of checkboxes: choose any number of the options.

Import: `import Klar.CheckboxGroup as CheckboxGroup` | Group: Inputs

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
selected : List value -> Attribute value msg
onChange : (List value -> msg) -> Attribute value msg
selectAll : Attribute value msg
selectAllLabel : String -> Attribute value msg

-- Label, hint and error
label : String -> Attribute value msg
labelHidden : Attribute value msg
hint : String -> Attribute value msg
error : String -> Attribute value msg
errorMaybe : Maybe String -> Attribute value msg
required : Attribute value msg
optionalText : String -> Attribute value msg
id : String -> Attribute value msg

-- Look, behavior and language
horizontal : Attribute value msg
size : Theme.Size -> Attribute value msg
disabled : Bool -> Attribute value msg
readOnly : Bool -> Attribute value msg
locale : Locale.Locale -> Attribute value msg
```

## Documentation

A group of checkboxes: choose any number of the options.

Use when: a handful of options where the user may choose any number and should see them all.
Do not use when: exactly one choice is wanted (`Klar.Radio`), the options are a compact row of toggles (`Klar.ToggleGroup`) or the list is long and needs a search box (`Klar.MultiSelect`).

    import Klar.CheckboxGroup as CheckboxGroup

    -- model:  { extras : List Extra }   (GiftWrap, PaperInvoice, Insurance: your own type)
    CheckboxGroup.view
        [ CheckboxGroup.label "Extras"
        , CheckboxGroup.options
            [ CheckboxGroup.option GiftWrap "Gift wrap"
            , CheckboxGroup.option PaperInvoice "Paper invoice"
            , CheckboxGroup.option Insurance "Shipping insurance"
                |> CheckboxGroup.withDescription "Covers loss and damage up to 500."
            ]
        , CheckboxGroup.selected model.extras
        , CheckboxGroup.onChange ExtrasChanged
        , CheckboxGroup.selectAll
        ]

    -- update
    ExtrasChanged extras ->
        ( { model | extras = extras }, Cmd.none )

**The values are your own** (`GiftWrap`, a warehouse id, an `Int`): an option is
made with its value, `selected` is the list of the values of the checked options,
and `onChange` gets the whole new selection, in the order of the options, so the
application just stores it. They are compared with `==`, so they have to be plain
data; there is nothing to convert to or from a `String`. A group without
`onChange` is read-only. `selectAll` adds a "Select all" checkbox on top that is
checked when every option is, shows a dash when only some are, and checks or
clears all of them; it leaves disabled options as they are.

The group is a `fieldset` whose legend is the label, and each option is a
[Klar.Checkbox](Klar.Checkbox.md). It takes the attributes that all form controls
share (`label`, `hint`, `error`, `required` ...; see [Klar.Field](Klar.Field.md)),
and the first checkbox that can be changed carries the `id` of the group, so
the error summary of [Klar.Form.Layout](Klar.Form.Layout.md) can move focus into it.

Use a group for a handful of options that people should see all at once. For
exactly one choice use [Klar.Radio](Klar.Radio.md), for a compact row of on and off
buttons [Klar.ToggleGroup](Klar.ToggleGroup.md), and for a long list, which needs a
search box, [Klar.MultiSelect](Klar.MultiSelect.md).

## View

### `Attribute`

```elm
type Attribute value msg  -- opaque: no constructors are exposed
```

A setting of a checkbox group. Make them with the functions below and pass
a list to `view`; later attributes win over earlier ones. `value` is the type of
the values of the options (your own), `msg` the message of `onChange`.

### `view`

```elm
view : List (Attribute value msg) -> Html msg
```

A `fieldset` of checkboxes with its legend, hint and error message. See the
module documentation for the attributes that matter most: `options`, `selected`
and `onChange`.

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

`option GiftWrap "Gift wrap"`: the value that ends up in the selection when
the box is checked (of your own type), and the text next to the box. The values
of a group should differ from each other.

### `withDescription`

```elm
withDescription : String -> Option value -> Option value
```

A line of gray explanation under the text of the option.

    CheckboxGroup.option Insurance "Shipping insurance"
        |> CheckboxGroup.withDescription "Covers loss and damage up to 500."

### `disabledOption`

```elm
disabledOption : Option value -> Option value
```

Visible but not changeable: the user cannot check or uncheck it, and
`selectAll` leaves its value in the selection or out of it, as it was.

### `options`

```elm
options : List (Option value) -> Attribute value msg
```

The choices of the group, in the order they are shown.

## Selection

### `selected`

```elm
selected : List value -> Attribute value msg
```

The values of the checked options. A value that no option has is not shown,
but it stays in the selection that `onChange` sends. The default is the empty
list.

### `onChange`

```elm
onChange : (List value -> msg) -> Attribute value msg
```

The message sent when a checkbox (or the select-all box) is changed. It gets
the complete new selection, in the order of the options (values that no option
has come last, and no value comes twice), so the application can store it as it
is. Without it the group is read-only (see `readOnly`).

    CheckboxGroup.onChange ExtrasChanged

### `selectAll`

```elm
selectAll : Attribute value msg
```

Adds a "Select all" checkbox above the options. It is checked when every
option that can be changed is checked, shows a dash when only some are, and
checks or clears all of them with one click. Options made with `disabledOption`
keep their state. The text is "Select all" in English; `selectAllLabel` changes
it.

### `selectAllLabel`

```elm
selectAllLabel : String -> Attribute value msg
```

Replaces the built-in "Select all" text of the select-all checkbox. This
also switches `selectAll` on.

    CheckboxGroup.selectAllLabel "All extras"

## Label, hint and error

### `label`

```elm
label : String -> Attribute value msg
```

The legend of the group: its name, shown above the options. Give every
group one, or screen readers cannot say what the choices are for; `labelHidden`
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

Shows an error message in red under the group and marks it: the empty boxes
get a red border. Screen readers read the message when it appears and with the
group afterwards (`aria-describedby`); a plain group has no `aria-invalid`.

### `errorMaybe`

```elm
errorMaybe : Maybe String -> Attribute value msg
```

Like `error`, for a message that may not be there: `Nothing` shows no
error. It goes well with `Validate.errorFor`.

    CheckboxGroup.errorMaybe (Validate.errorFor "order-extras" errors)

### `required`

```elm
required : Attribute value msg
```

Marks the group as required with a `*` after the legend. It is a visual mark
and checks nothing: ARIA has no required state for a group of checkboxes, so
tell screen reader users in the `hint` too ("Choose at least one").

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

The DOM id of the group. Its first checkbox that can be changed gets this
id, so an error summary can move focus into the group; the other checkboxes get
`<id>-<position>` (counting from 0) and the fieldset gets `<id>-group`. When no
checkbox can take the focus, the fieldset gets the id instead.

Without it the id is made from the label and the texts of the options. That is
enough unless two groups on a page have both the same: give those an id each.

## Look, behavior and language

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

The size of the checkboxes and their text: `Small`, `Medium` or `Large` (see
[Klar.Theme](Klar.Theme.md)). The default is `Medium`.

### `disabled`

```elm
disabled : Bool -> Attribute value msg
```

Disables the whole group, including the select-all box: dimmed, skipped by
Tab, and nothing can be changed. The default is `False`.

### `readOnly`

```elm
readOnly : Bool -> Attribute value msg
```

Shows the selection without letting the user change it, for a record the
user may read but not edit. Each box is a read-only checkbox (see
`Checkbox.readOnly`): not dimmed, reached with Tab and read by screen readers,
but a click or Space changes nothing and nothing is sent to `onChange`. The
default is `False`.

### `locale`

```elm
locale : Locale.Locale -> Attribute value msg
```

The language of the built-in text, which is the label of the select-all box.
The default is `Locale.default`, which is English.
