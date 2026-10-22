# Klar.Progress

Progress: a linear bar, a bar divided into steps, and a ring.

Import: `import Klar.Progress as Progress` | Group: Status and feedback

Types: `Attribute`

## Signatures

```elm
-- Views
view : List Attribute -> Html msg
ring : List Attribute -> Html msg

-- Value
type Attribute  -- opaque: no constructors are exposed
value : Float -> Attribute
outOf : Int -> Int -> Attribute
indeterminate : Attribute

-- Text and accessibility
label : String -> Attribute
ariaLabel : String -> Attribute
showValue : Attribute
valueText : String -> Attribute
locale : Locale.Locale -> Attribute

-- Look
tone : Theme.Tone -> Attribute
size : Theme.Size -> Attribute
striped : Attribute
segments : Int -> Attribute
```

## Documentation

Progress: a linear bar, a bar divided into steps, and a ring.

Use when: you can say how far a task has come, as a percentage or as steps such as "3 of 5".
Do not use when: there is nothing to measure and a plain wait will do (use `Klar.Spinner`).
Quick path: `view`, `ring`

    import Klar.Progress as Progress
    import Klar.Theme exposing (Tone(..))

    Progress.view [ Progress.label "Upload", Progress.value 62, Progress.showValue ]

    Progress.view [ Progress.label "Importing orders", Progress.indeterminate ]

    Progress.view
        [ Progress.label "Checkout"
        , Progress.outOf 3 5
        , Progress.segments 5
        , Progress.showValue
        ]

    Progress.ring [ Progress.value 80, Progress.tone Success, Progress.label "Done" ]

The value is a percentage from 0 to 100. Use `outOf` when you count steps, as in
"3 of 5", and `indeterminate` when the length of the task is unknown. Every
progress element is a `role="progressbar"` with `aria-valuenow` (omitted while
indeterminate) and a text alternative: the `ariaLabel`, else the `label`, else
the built-in text "Progress". The unfilled track is a light step of the bar's own
color, so the state reads across the whole length of the bar.

Attributes are applied in order, and the last one wins: `value` replaces an
earlier `outOf` (with its "3 of 5" text), `outOf` replaces an earlier `value`,
and `indeterminate` and a value cancel each other. `valueText` is the exception:
it replaces the automatic value text wherever it stands in the list.

The ring shows its value in the middle, and the label below it when there is
room. It ignores `showValue`, `striped` and `segments`. When there is nothing to
measure, a [Klar.Spinner](Klar.Spinner.md) is the lighter choice.

## Views

### `view`

```elm
view : List Attribute -> Html msg
```

A horizontal bar. Add `showValue` for the value as text, `segments` to
divide it into steps and `striped` for stripes.

### `ring`

```elm
ring : List Attribute -> Html msg
```

A circular ring with the value in the middle, for dashboards and other tight
spaces. It uses `value`, `outOf`, `valueText`, `indeterminate`, `tone`, `size`,
`label`, `ariaLabel` and `locale`.

## Value

### `Attribute`

```elm
type Attribute  -- opaque: no constructors are exposed
```

A setting of a progress indicator. Make them with the functions below and
pass a list to `view` or `ring`; later attributes win over earlier ones.

### `value`

```elm
value : Float -> Attribute
```

The progress as a percentage from 0 to 100. The default is 0. A number
outside the range is clamped to it, and NaN or infinity count as 0. Also turns
`indeterminate` off, and replaces an earlier `outOf` together with its "3 of 5"
text.

    Progress.view [ Progress.value 62.5 ]

### `outOf`

```elm
outOf : Int -> Int -> Attribute
```

Sets the value from a count of steps: `outOf 3 5` is 60%. With `showValue`
the text reads "3 of 5" instead of a percentage. A total of 0 or less gives 0%.
Also turns `indeterminate` off. It replaces an earlier `value`, and a later
`value` replaces it.

### `indeterminate`

```elm
indeterminate : Attribute
```

The length of the task is unknown: an animated bar (or a spinning ring)
without a value. It has no `aria-valuenow` and shows no value text. In a bar
with `segments` no step is filled, whatever the value was; a wave of highlights
runs over the steps instead. A later `value` or `outOf` turns it off.

## Text and accessibility

### `label`

```elm
label : String -> Attribute
```

Visible text above the bar, or inside the ring. It is also the accessible
name, unless you give an `ariaLabel`. A `Small` ring is too small for the text
and only keeps the accessible name.

### `ariaLabel`

```elm
ariaLabel : String -> Attribute
```

An accessible name for when you want no visible label. It wins over `label`
as the accessible name. When neither is given, the name is the built-in text
("Progress" in English).

### `showValue`

```elm
showValue : Attribute
```

Shows the value as text next to the label: "62%", or "3 of 5" after `outOf`.
It is hidden while the bar is `indeterminate`. A ring always shows its value.

### `valueText`

```elm
valueText : String -> Attribute
```

Replaces the value text with your own, for example "12 of 40 hours", and
turns `showValue` on. Screen readers get the same text as `aria-valuetext`.

    Progress.view [ Progress.value 30, Progress.valueText "12 of 40 hours" ]

### `locale`

```elm
locale : Locale.Locale -> Attribute
```

The language of the built-in text: the word "of" in the text of `outOf`, the
accessible name "Progress", and the number format ("62%" in English). The
default is `Locale.default`, which is English.

## Look

### `tone`

```elm
tone : Theme.Tone -> Attribute
```

The color: `Primary` (blue, the default), `Success`, `Warning`, `Danger` or
`Neutral` (gray). `Info` looks like `Primary`.

### `size`

```elm
size : Theme.Size -> Attribute
```

The thickness of the bar: `Small` is 4px, `Medium` 8px and `Large` 12px. For
a ring it is the diameter: 36px, 64px and 88px. The default is `Medium`.

### `striped`

```elm
striped : Attribute
```

Moving diagonal stripes on the filled part of the bar. They stand still for
users who prefer reduced motion. Bars only, and not together with `segments`.

### `segments`

```elm
segments : Int -> Attribute
```

Divides the bar into this many equal steps (at least 2, at most 40) instead
of one continuous bar. The number of filled steps is the value rounded to a
whole step. An `indeterminate` bar fills no step and shows a wave of highlights
over the steps. Bars only.

    Progress.view [ Progress.outOf 2 4, Progress.segments 4 ]
