# Klar.ToggleGroup

A row of toggle buttons for choices that can be on or off: "Bold / Italic / Underline", the statuses to show in a list, the days of the week.

Import: `import Klar.ToggleGroup as ToggleGroup` | Group: Actions

Types: `Option`, `Attribute`

## Signatures

```elm
-- Groups
single :
    List Attribute
    -> { label : String, selected : Maybe id, onChange : Maybe id -> msg }
    -> List (Option id)
    -> Html msg
multiple :
    List Attribute
    -> { label : String, selected : List id, onChange : List id -> msg }
    -> List (Option id)
    -> Html msg

-- Options
type Option id  -- opaque: no constructors are exposed
option : id -> String -> Option id
iconOption : id -> Icon.Icon -> String -> Option id
withIcon : Icon.Icon -> Option id -> Option id
disabledOption : Option id -> Option id

-- Attributes
type Attribute  -- opaque: no constructors are exposed
size : Theme.Size -> Attribute
fullWidth : Attribute
disabled : Bool -> Attribute
labelHidden : Attribute
hint : String -> Attribute
error : String -> Attribute
errorMaybe : Maybe String -> Attribute
id : String -> Attribute
```

## Documentation

A row of toggle buttons for choices that can be on or off: "Bold / Italic /
Underline", the statuses to show in a list, the days of the week.

    import Klar.Icon as Icon
    import Klar.ToggleGroup as ToggleGroup

    -- model:  { styles : List Style }   (Bold, Italic, Underline: your own type)
    ToggleGroup.multiple [ ToggleGroup.size Small ]
        { label = "Text style"
        , selected = model.styles
        , onChange = StylesChanged
        }
        [ ToggleGroup.iconOption Bold Icon.bold "Bold"
        , ToggleGroup.iconOption Italic Icon.italic "Italic"
        , ToggleGroup.iconOption Underline Icon.underline "Underline"
        ]

    -- update
    StylesChanged styles ->
        ( { model | styles = styles }, Cmd.none )

There are two kinds, and a group is exactly one of them, so they cannot be mixed:

  - `multiple`: any number of options are on. `onChange` gets the whole new
    selection, a `List` of ids.
  - `single`: none or one option is on. Clicking the one that is on turns it off, and
    `onChange` gets `Nothing`; clicking another one moves the choice. That is
    what sets it apart from [Klar.SegmentedControl](Klar.SegmentedControl.md), where
    exactly one view is always chosen (use that for "List / Grid" or "Day / Week /
    Month"), and from [Klar.CheckboxGroup](Klar.CheckboxGroup.md) and
    [Klar.Radio](Klar.Radio.md), which have a sentence of explanation for each choice.

**The ids are your own values** (`Bold`, `Open`, `Monday`, an order id): an
option is made with its id, the selection is made of ids, and they are compared
with `==`, so they have to be plain data. The application keeps the selection and
gives it back in `selected`. Clicking never changes anything by itself: the message
carries the new selection, worked out from the selection the group was drawn
with, so there is nothing to read or fix up afterwards. The list a `multiple` group
sends is in the order of the options, whatever order the user clicked in, and an
id that no option has (the options changed) stays in it.

**Keyboard and screen readers.** Each option is a button with `aria-pressed`,
announced as "Bold, toggle button, pressed". Tab moves between the options, and
Space or Enter toggles the focused one. The arrow keys are not used: the group
is a plain `group` named by its label, not a widget with its own key map (as in
[Klar.Toolbar](Klar.Toolbar.md)), and a stateless component cannot move focus by
itself. It could have been built from radio buttons and checkboxes, which would give the
arrow keys, but a radio button cannot be turned off again (so it cannot
do `single`), and a screen reader announces it as "1 of 4", which is wrong for a
choice of none or one. A group of toggle buttons says what it is.

The label is required. It names the group for screen readers and is shown above
it unless `labelHidden`. An option with only an icon (`iconOption`) needs its
text just as much: the text is the accessible name and the native tooltip, so it
cannot be forgotten. The group has no text of its own, so there is no `locale`;
`hint` and `error` come from your application. It takes the look of a
[Klar.ButtonGroup](Klar.ButtonGroup.md).

## Groups

### `single`

```elm
single :
    List Attribute
    -> { label : String, selected : Maybe id, onChange : Maybe id -> msg }
    -> List (Option id)
    -> Html msg
```

A group where none or one option is on. `selected` is the id of the option that
is on, or `Nothing`; `onChange` gets the new choice: the id that was clicked, or
`Nothing` when the one that was on is clicked again. The `label` names the group.

    ToggleGroup.single []
        { label = "Status"
        , selected = model.status -- Maybe Status
        , onChange = StatusChanged
        }
        [ ToggleGroup.option Open "Open"
        , ToggleGroup.option Shipped "Shipped"
        , ToggleGroup.option Cancelled "Cancelled"
        ]

### `multiple`

```elm
multiple :
    List Attribute
    -> { label : String, selected : List id, onChange : List id -> msg }
    -> List (Option id)
    -> Html msg
```

A group where any number of options are on. `selected` lists the ids that are
on; `onChange` gets the new list, in the order of the options. The `label` names
the group.

    ToggleGroup.multiple []
        { label = "Working days"
        , selected = model.days -- List Weekday
        , onChange = DaysChanged
        }
        [ ToggleGroup.option Mon "Mon"
        , ToggleGroup.option Tue "Tue"
        , ToggleGroup.option Wed "Wed"
        ]

## Options

### `Option`

```elm
type Option id  -- opaque: no constructors are exposed
```

One toggle button of the group, with the id of your application. Make it with
`option` or `iconOption`; `withIcon` and `disabledOption` refine it.

### `option`

```elm
option : id -> String -> Option id
```

An option with a text: `option Open "Open"` is the id first, then the text.
The ids of a group should differ from each other.

### `iconOption`

```elm
iconOption : id -> Icon.Icon -> String -> Option id
```

An option with only an icon. The text is not shown, but it is the accessible
name and the native tooltip, so it must say what the option does:
`iconOption Bold Icon.bold "Bold"`.

### `withIcon`

```elm
withIcon : Icon.Icon -> Option id -> Option id
```

An icon before the text of an option. The icon is decoration. On an option made
with `iconOption` it replaces the icon.

    ToggleGroup.option Open "Open" |> ToggleGroup.withIcon Icon.circle

### `disabledOption`

```elm
disabledOption : Option id -> Option id
```

Visible but not clickable: dimmed, skipped by Tab, and left as it is in the
selection (a disabled option that is on stays on).

## Attributes

### `Attribute`

```elm
type Attribute  -- opaque: no constructors are exposed
```

A setting of a group. Make them with the functions below and pass a list to
`single` or `multiple`; later attributes win over earlier ones. The messages are
in the arguments of those functions, so the type has no `msg` parameter.

### `size`

```elm
size : Theme.Size -> Attribute
```

The height and text size of the buttons: `Small`, `Medium` or `Large` (see
[Klar.Theme](Klar.Theme.md)). The default is `Medium`.

### `fullWidth`

```elm
fullWidth : Attribute
```

Stretch over the whole width, every option equally wide.

### `disabled`

```elm
disabled : Bool -> Attribute
```

Disables the whole group. The default is `False`. The selection stays as it
is.

### `labelHidden`

```elm
labelHidden : Attribute
```

Keeps the label for screen readers only. Use it when the buttons are clear
without it, such as the icons of an editor. The label is still required.

### `hint`

```elm
hint : String -> Attribute
```

A line of help under the group, joined to it with `aria-describedby` so a
screen reader reads it with the group.

### `error`

```elm
error : String -> Attribute
```

Shows an error message in red under the group and draws the buttons with a red
border. Screen readers read the message when it appears.

### `errorMaybe`

```elm
errorMaybe : Maybe String -> Attribute
```

Like `error`, for a message that may not be there: `Nothing` shows no
error. It goes well with `Validate.errorFor`.

### `id`

```elm
id : String -> Attribute
```

The DOM id of the group; the ids of its label, hint and error start with it.
Without one it is made from the label and the texts of the options, with a number
worked out from them, so a label in any language (or an empty one) gives a valid id,
and two groups with the same label and other options do not share one. Two groups
with the same label and the same options on one page need an id each; the label,
the hint and the error of the second would otherwise be found by the first.
