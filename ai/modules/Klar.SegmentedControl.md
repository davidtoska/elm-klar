# Klar.SegmentedControl

A row of joined options where exactly one is chosen: a switch between views ("List" / "Grid"), periods ("Day" / "Week" / "Month") or modes.

Import: `import Klar.SegmentedControl as SegmentedControl` | Group: Inputs

Types: `Option`, `Attribute`

## Signatures

```elm
-- View
type Attribute value msg  -- opaque: no constructors are exposed
view : List (Attribute value msg) -> Html msg

-- Options
type Option value  -- opaque: no constructors are exposed
option : value -> String -> Option value
iconOption : value -> Icon.Icon -> String -> Option value
withIcon : Icon.Icon -> Option value -> Option value
disabledOption : Option value -> Option value
options : List (Option value) -> Attribute value msg

-- Selection
selected : value -> Attribute value msg
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
size : Theme.Size -> Attribute value msg
fullWidth : Attribute value msg
disabled : Bool -> Attribute value msg
readOnly : Bool -> Attribute value msg
```

## Documentation

A row of joined options where exactly one is chosen: a switch between
views ("List" / "Grid"), periods ("Day" / "Week" / "Month") or modes.

Use when: a few short options that switch what the page shows, such as List or Grid, or Day, Week and Month.
Do not use when: the options need a sentence of explanation (`Klar.Radio`), there are many (`Klar.Select`), none or several may be on (`Klar.ToggleGroup`) or panels of content are switched (`Klar.Tabs`).

    import Klar.Icon as Icon
    import Klar.SegmentedControl as SegmentedControl

    -- model:  { layout : Layout }   (ListLayout, GridLayout: your own type)
    SegmentedControl.view
        [ SegmentedControl.label "Layout"
        , SegmentedControl.labelHidden
        , SegmentedControl.options
            [ SegmentedControl.option ListLayout "List" |> SegmentedControl.withIcon Icon.list
            , SegmentedControl.option GridLayout "Grid" |> SegmentedControl.withIcon Icon.grid
            ]
        , SegmentedControl.selected model.layout
        , SegmentedControl.onChange LayoutChanged
        ]

    -- update
    LayoutChanged layout ->
        ( { model | layout = layout }, Cmd.none )

**The values are your own** (`ListLayout`, `Week`, an `Int`): an option is made with
its value, `selected` is the chosen value and `onChange` gets the value of the
segment the user chooses. They are compared with `==`, so they have to be plain
data; there is nothing to convert to or from a `String`. The application owns the
choice and gives it back in `selected`: one value, because one segment is always
chosen. A control without `onChange` is read-only.

It is a group of radio buttons that looks like joined buttons, so the keyboard
works the way people expect: Tab enters the group at the chosen segment, and the
arrow keys move to the next or previous segment and choose it (skipping disabled
ones and wrapping around at the ends). The `label` names the group for screen
readers; `labelHidden` keeps it out of sight when the segments speak for
themselves.

Use it for a few short options that change what the page shows. For options that
need a sentence of explanation use [Klar.Radio](Klar.Radio.md), for more than a
handful [Klar.Select](Klar.Select.md), for options that are on or off
[Klar.ToggleGroup](Klar.ToggleGroup.md), and for switching between panels of content
[Klar.Tabs](Klar.Tabs.md). It takes the attributes that all form controls share
(`label`, `hint`, `error`, `required` ...; see [Klar.Field](Klar.Field.md)), and its
`id` is also the `name` that its radio buttons share.

## View

### `Attribute`

```elm
type Attribute value msg  -- opaque: no constructors are exposed
```

A setting of a segmented control. Make them with the functions below and
pass a list to `view`; later attributes win over earlier ones. `value` is the
type of the values of the segments (your own), `msg` the message of `onChange`.

### `view`

```elm
view : List (Attribute value msg) -> Html msg
```

A row of joined segments with a label (shown or hidden), a hint and an error
message. See the module documentation for the attributes that matter most:
`label`, `options`, `selected` and `onChange`.

## Options

### `Option`

```elm
type Option value  -- opaque: no constructors are exposed
```

One segment of the control: a value of your own and a text, with an optional
icon, and perhaps disabled. Make one with `option` or `iconOption`.

### `option`

```elm
option : value -> String -> Option value
```

`option Week "Week"`: the value that `onChange` gets when the segment is
chosen (of your own type), and the text of the segment. The values of a control
should differ from each other.

### `iconOption`

```elm
iconOption : value -> Icon.Icon -> String -> Option value
```

A segment with only an icon. The text is not shown, but it is the accessible
name and the native tooltip, so it must say what the segment is:
`iconOption GridLayout Icon.grid "Grid"`.

### `withIcon`

```elm
withIcon : Icon.Icon -> Option value -> Option value
```

An icon before the text of the segment (see [Klar.Icon](Klar.Icon.md)). The icon
is decoration. On a segment made with `iconOption` it replaces the icon.

    SegmentedControl.option ListLayout "List" |> SegmentedControl.withIcon Icon.list

### `disabledOption`

```elm
disabledOption : Option value -> Option value
```

Visible but not selectable: dimmed, and the arrow keys skip it.

### `options`

```elm
options : List (Option value) -> Attribute value msg
```

The segments, in the order they are shown.

## Selection

### `selected`

```elm
selected : value -> Attribute value msg
```

The value of the chosen segment. One segment is always chosen, so it is a
value, not a `Maybe`; a value that no segment has (or no `selected`) chooses
nothing, which only makes sense while the options are loading.

### `onChange`

```elm
onChange : (value -> msg) -> Attribute value msg
```

The message sent when the user chooses a segment, with the mouse or with the
arrow keys. It gets the value of that segment; store it and give it back with
`selected`. Without it the control is read-only (see `readOnly`).

    SegmentedControl.onChange PeriodChanged

## Label, hint and error

### `label`

```elm
label : String -> Attribute value msg
```

The label, shown above the control and naming it for screen readers. Give
every control one; `labelHidden` keeps it for screen readers only.

### `labelHidden`

```elm
labelHidden : Attribute value msg
```

Keep the label for screen readers only, for a control that is clear from its
segments, such as "Layout" for List and Grid icons: it becomes the `aria-label`
of the group. The label is still needed.

### `hint`

```elm
hint : String -> Attribute value msg
```

A line of help under the control, joined to it with `aria-describedby` so a
screen reader reads it with the control.

### `error`

```elm
error : String -> Attribute value msg
```

Shows an error message in red under the control and marks it invalid: the
border turns red and the group gets `aria-invalid`. Screen readers read the
message when it appears.

### `errorMaybe`

```elm
errorMaybe : Maybe String -> Attribute value msg
```

Like `error`, for a message that may not be there: `Nothing` shows no
error. It goes well with `Validate.errorFor`.

    SegmentedControl.errorMaybe (Validate.errorFor "report-period" errors)

### `required`

```elm
required : Attribute value msg
```

Marks the control as required: a `*` after the label and `aria-required` on
the group. It only marks the control and checks nothing.

### `optionalText`

```elm
optionalText : String -> Attribute value msg
```

Text shown after the label of a control that is not required, such as
"(optional)". There is no built-in text: without this, an optional control gets
no mark.

### `id`

```elm
id : String -> Attribute value msg
```

The DOM id of the group. The chosen segment, or the first one that can be
chosen when none is, gets this id, so an error summary can move focus to the
control (when no segment can take the focus, the group gets it). It is also the
`name` that the segments share, which makes them one group for the browser:
without an id it is made from the label and the texts of the segments, and two
controls with the same label and the same texts on one page need an id each.

## Look and behavior

### `size`

```elm
size : Theme.Size -> Attribute value msg
```

The height and text size of the segments: `Small`, `Medium` or `Large` (see
[Klar.Theme](Klar.Theme.md)). The default is `Medium`.

### `fullWidth`

```elm
fullWidth : Attribute value msg
```

Stretch over the whole width, every segment equally wide.

### `disabled`

```elm
disabled : Bool -> Attribute value msg
```

Disables the whole control: dimmed, skipped by Tab, and nothing can be
chosen. The default is `False`.

### `readOnly`

```elm
readOnly : Bool -> Attribute value msg
```

Shows the choice without letting the user change it, for example while a
report is being made. Unlike `disabled` it is not dimmed, and Tab still reaches
the chosen segment, so a screen reader can read it; the group has
`aria-readonly`, and the other segments cannot be chosen with the mouse or the
arrow keys: they are disabled, so screen readers call them unavailable, but they
are not dimmed. When no segment can take the focus, Tab reaches the group itself.
Nothing is sent to `onChange`. The default is `False`.
