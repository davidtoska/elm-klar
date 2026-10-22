# Klar.Stepper

The steps of a wizard or a checkout flow, laid out horizontally or vertically.

Import: `import Klar.Stepper as Stepper` | Group: Navigation

Types: `Step`, `Attribute`

## Signatures

```elm
-- Views
view : List (Attribute msg) -> List Step -> Html msg
progress : List (Attribute msg) -> List Step -> Html msg

-- Steps
type Step  -- opaque: no constructors are exposed
step : String -> Step
withDescription : String -> Step -> Step
failed : Step -> Step
disabledStep : Step -> Step

-- Attributes
type Attribute msg  -- opaque: no constructors are exposed
current : Int -> Attribute msg
onSelect : (Int -> msg) -> Attribute msg
vertical : Attribute msg
small : Attribute msg
ariaLabel : String -> Attribute msg
locale : Locale.Locale -> Attribute msg
```

## Documentation

The steps of a wizard or a checkout flow, laid out horizontally or vertically.

Use when: the user needs to see where they are in the steps of a wizard or a checkout flow.
Do not use when: you need switchable views of the same thing (use `Klar.Tabs`) or a plain progress measure (use `Klar.Progress`).

    import Klar.Stepper as Stepper

    steps : List Stepper.Step
    steps =
        [ Stepper.step "Customer"
        , Stepper.step "Shipping"
            |> Stepper.withDescription "Address and carrier"
        , Stepper.step "Payment"
            |> Stepper.failed
        , Stepper.step "Review"
        ]

    -- in the view
    Stepper.view
        [ Stepper.current model.step
        , Stepper.onSelect GoToStep
        ]
        steps

The stepper only shows where the user is. It keeps no state and decides nothing:
your model holds the index of the current step, and `onSelect` reports a click on
another step.

Steps are numbered from 0. The step with the index given to `current` is the
current one, the steps before it are complete and the ones after it are upcoming.
Mark exceptions on the step itself: `failed` (validation did not pass) and
`disabledStep` (not available yet). With `onSelect` every step that is not
disabled becomes a button, so disable the steps that must not be visited yet.

The steps are an ordered list. The current step has `aria-current="step"`, and a
step that is complete, failed or disabled is also announced in words ("completed",
"has errors", "unavailable"), because the marker alone does not reach screen
readers.

`progress` is the matching one-line summary, "Step 2 of 5", a good companion on
narrow screens or above a form:

    Stepper.progress [ Stepper.current model.step ] steps

The built-in text follows `locale` (English by default).

## Views

### `view`

```elm
view : List (Attribute msg) -> List Step -> Html msg
```

The steps, connected by thin lines, as an ordered list. In a horizontal row a
label that does not fit is cut with an ellipsis, and a row with very many steps
scrolls sideways (the row can take the keyboard focus, so that it can be scrolled
with the arrow keys); a vertical list wraps long labels and descriptions instead.

### `progress`

```elm
progress : List (Attribute msg) -> List Step -> Html msg
```

A one-line summary such as "Step 2 of 5", followed by the label of the current
step, as a polite live region so that screen readers announce the change. Takes
the same attributes and steps as `view`, but only `current` and `locale` matter;
a `current` outside the list is moved to the nearest step.

    Stepper.progress [ Stepper.current model.step ] steps

## Steps

### `Step`

```elm
type Step  -- opaque: no constructors are exposed
```

One step of the flow. Make it with `step` and refine it with
`withDescription`, `failed` and `disabledStep`.

### `step`

```elm
step : String -> Step
```

A step with a label. Whether it is complete, current or upcoming follows from
its place in the list and from `current`. The marker shows the number of the step
(counting from 1), or a check mark once the step is complete.

    Stepper.step "Shipping"

### `withDescription`

```elm
withDescription : String -> Step -> Step
```

A line of small gray text under the label, for a hint about what the step
holds.

### `failed`

```elm
failed : Step -> Step
```

Marks the step as having a problem: a red marker with an exclamation mark, and
"has errors" read out for screen readers. The step keeps its red marker whether
it is before, at or after the current step, and the current step keeps
`aria-current="step"` even when it has failed.

### `disabledStep`

```elm
disabledStep : Step -> Step
```

A step that cannot be opened (yet): drawn muted, with "unavailable" read out
for screen readers, and a disabled button when `onSelect` is used. It takes
precedence over `failed` and over the position of the step.

## Attributes

### `Attribute`

```elm
type Attribute msg  -- opaque: no constructors are exposed
```

A setting of the stepper. Make them with the functions below and pass a list
to `view` or `progress`; later attributes win over earlier ones. The `msg` is
your message type, used by `onSelect`.

### `current`

```elm
current : Int -> Attribute msg
```

The index of the current step, counting from 0 (default 0). The steps before
it are complete and the steps after it are upcoming. An index outside the list is
moved to the nearest step, in `view` and in `progress` alike, so an index past the
end makes the last step the current one.

### `onSelect`

```elm
onSelect : (Int -> msg) -> Attribute msg
```

Turns the steps into buttons that send their index (counting from 0) when
they are clicked or activated with the keyboard. The current step is a button
too. Steps marked with `disabledStep` stay disabled; without `onSelect` no step
is clickable.

    Stepper.onSelect GoToStep

### `vertical`

```elm
vertical : Attribute msg
```

Stacks the steps from top to bottom, for sidebars and steps with long
descriptions. The default is a horizontal row.

### `small`

```elm
small : Attribute msg
```

Smaller markers, 20px instead of 26px, for tight spaces.

### `ariaLabel`

```elm
ariaLabel : String -> Attribute msg
```

The accessible name of the list of steps. Default "Progress" (in the language
of `locale`).

### `locale`

```elm
locale : Locale.Locale -> Attribute msg
```

The language of the built-in text: the name of the list, the status read out
for a step ("completed", "has errors", "unavailable") and the "Step 2 of 5"
summary of `progress`. Default `Locale.en`.
