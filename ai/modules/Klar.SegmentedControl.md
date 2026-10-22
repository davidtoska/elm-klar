# Klar.SegmentedControl

A row of joined options where exactly one is chosen: a switch between views ("List" / "Grid"), periods ("Day" / "Week" / "Month") or modes.

Import: `import Klar.SegmentedControl as SegmentedControl` | Group: Inputs

Types: `Option`, `Attribute`

## Signatures

```elm
-- View
type Attribute msg  -- opaque: no constructors are exposed
view : List (Attribute msg) -> Html msg

-- Options
type Option  -- opaque: no constructors are exposed
option : String -> String -> Option
withIcon : Icon.Icon -> Option -> Option
iconOnly : Option -> Option
disabledOption : Option -> Option
options : List Option -> Attribute msg

-- Selection
selected : Maybe String -> Attribute msg
onSelect : (String -> msg) -> Attribute msg

-- Label, hint and error
label : String -> Attribute msg
labelHidden : Attribute msg
ariaLabel : String -> Attribute msg
hint : String -> Attribute msg
error : String -> Attribute msg
errorMaybe : Maybe String -> Attribute msg
required : Attribute msg
optionalText : String -> Attribute msg
id : String -> Attribute msg

-- Look
size : Theme.Size -> Attribute msg
fullWidth : Attribute msg
disabled : Bool -> Attribute msg
```

## Documentation

A row of joined options where exactly one is chosen: a switch between
views ("List" / "Grid"), periods ("Day" / "Week" / "Month") or modes.

Use when: a few short options that switch what the page shows, such as List or Grid, or Day, Week and Month.
Do not use when: the options need a sentence of explanation (`Klar.Radio`), there are many (`Klar.Select`) or panels of content are switched (`Klar.Tabs`).

    import Klar.Icon as Icon
    import Klar.SegmentedControl as SegmentedControl

    SegmentedControl.view
        [ SegmentedControl.ariaLabel "Layout"
        , SegmentedControl.options
            [ SegmentedControl.option "list" "List" |> SegmentedControl.withIcon Icon.list
            , SegmentedControl.option "grid" "Grid" |> SegmentedControl.withIcon Icon.grid
            ]
        , SegmentedControl.selected (Just model.layout)
        , SegmentedControl.onSelect LayoutChanged
        ]

The application owns the choice: `selected` says which option is chosen
(`Nothing` for none) and `onSelect` gets the value of the option the user
chooses.

It is a group of radio buttons that looks like joined buttons, so the
keyboard works the way people expect: Tab enters the group at the chosen
option, and the arrow keys move to the neighboring option and choose it. Give
it a visible `label` or an `ariaLabel`, which is the name of the group for
screen readers.

Use it for a few short options that change what the page shows. For options that
need a sentence of explanation use [Klar.Radio](Klar.Radio.md), for more than a
handful [Klar.Select](Klar.Select.md), and for switching between panels of content
[Klar.Tabs](Klar.Tabs.md). It takes the attributes that all form controls share
(`label`, `hint`, `error`, `required` ...; see [Klar.Field](Klar.Field.md)), and its
`id` is also the `name` that its radio buttons share.

## View

### `Attribute`

```elm
type Attribute msg  -- opaque: no constructors are exposed
```

A setting of a segmented control. Make them with the functions below and
pass a list to `view`; later attributes win over earlier ones.

### `view`

```elm
view : List (Attribute msg) -> Html msg
```

A row of joined segments with an optional label, hint and error message.
See the module documentation for the attributes that matter most: `options`,
`selected` and `onSelect`.

## Options

### `Option`

```elm
type Option  -- opaque: no constructors are exposed
```

One segment of the control: a value and a text, with an optional icon, and
perhaps disabled. Make one with `option`.

### `option`

```elm
option : String -> String -> Option
```

`option "week" "Week"`: the value that `onSelect` gets when the segment is
chosen, and the text of the segment. The values of a control should differ from
each other.

### `withIcon`

```elm
withIcon : Icon.Icon -> Option -> Option
```

An icon before the text of the segment. See [Klar.Icon](Klar.Icon.md), and
`iconOnly` to drop the text.

    SegmentedControl.option "list" "List" |> SegmentedControl.withIcon Icon.list

### `iconOnly`

```elm
iconOnly : Option -> Option
```

Show only the icon, which needs `withIcon`. The text stays as the accessible
name and as the tooltip, so it must still say what the segment is.

### `disabledOption`

```elm
disabledOption : Option -> Option
```

Visible but not selectable: dimmed, and the arrow keys skip it.

### `options`

```elm
options : List Option -> Attribute msg
```

The segments, in the order they are shown.

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

The message sent when the user chooses a segment, with the mouse or with the
arrow keys. It gets the value of that option; store it and give it back with
`selected`. Without it the control sends nothing.

    SegmentedControl.onSelect PeriodChanged

## Label, hint and error

### `label`

```elm
label : String -> Attribute msg
```

The label, shown above the control and naming it for screen readers. Give
the control a `label` or an `ariaLabel`.

### `labelHidden`

```elm
labelHidden : Attribute msg
```

Keep the label for screen readers only.

### `ariaLabel`

```elm
ariaLabel : String -> Attribute msg
```

The accessible name when there is no visible label, such as "Layout" for a
control that is clear from its icons. It becomes the `aria-label` of the group;
a `label`, when there is one, takes its place.

### `hint`

```elm
hint : String -> Attribute msg
```

A line of help under the control, joined to it with `aria-describedby` so a
screen reader reads it with the control.

### `error`

```elm
error : String -> Attribute msg
```

Shows an error message in red under the control and marks it invalid: the
border turns red and the group gets `aria-invalid`. Screen readers read the
message when it appears.

### `errorMaybe`

```elm
errorMaybe : Maybe String -> Attribute msg
```

Like `error`, for a message that may not be there: `Nothing` shows no
error. It goes well with `Validate.errorFor`.

    SegmentedControl.errorMaybe (Validate.errorFor "report-period" errors)

### `required`

```elm
required : Attribute msg
```

Marks the control as required: a `*` after the label and `aria-required` on
the group. It only marks the control and checks nothing.

### `optionalText`

```elm
optionalText : String -> Attribute msg
```

Text shown after the label of a control that is not required, such as
"(optional)". There is no built-in text: without this, an optional control gets
no mark.

### `id`

```elm
id : String -> Attribute msg
```

The DOM id of the group. The chosen segment, or the first one that can be
chosen when none is, gets this id, so an error summary can move focus to the
control. It is also the `name` that the segments share, which makes them one
group for the browser: without an id it is made from the label (or `ariaLabel`)
and the option values, and two controls with the same label and the same option
values on one page need an id each.

## Look

### `size`

```elm
size : Theme.Size -> Attribute msg
```

The height and text size of the segments: `Small`, `Medium` or `Large` (see
[Klar.Theme](Klar.Theme.md)). The default is `Medium`.

### `fullWidth`

```elm
fullWidth : Attribute msg
```

Stretch over the whole width, every segment equally wide.

### `disabled`

```elm
disabled : Bool -> Attribute msg
```

Disables the whole control. The default is `False`.
