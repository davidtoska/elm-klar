# Klar.Spinner

Loading indicators: a small spinner for inline use and a centered panel for a region that is still loading.

Import: `import Klar.Spinner as Spinner` | Group: Status and feedback

Types: `Attribute`

## Signatures

```elm
-- Spinners
view : List Attribute -> Html msg
panel : String -> Html msg

-- Attributes
type Attribute  -- opaque: no constructors are exposed
size : Theme.Size -> Attribute
label : String -> Attribute
```

## Documentation

Loading indicators: a small spinner for inline use and a centered panel for
a region that is still loading.

Use when: you do not know what the content will look like or how long the wait will be.
Do not use when: you can sketch the content (use `Klar.Skeleton`) or want a bar that shows how far a task has come (use `Klar.Progress`).

    import Klar.Spinner as Spinner
    import Klar.Theme exposing (Size(..))

    Spinner.view []

    Spinner.view [ Spinner.size Large, Spinner.label "Loading orders" ]

    Spinner.panel "Loading orders ..."

Use a spinner when you do not know what the content will look like or how long
the wait will be. When you can sketch the content, show a
[Klar.Skeleton](Klar.Skeleton.md) instead.

A spinner takes the color of the text around it, so it follows disabled and
danger states (only the large size is always drawn in the primary color). For
users who prefer reduced motion it turns more slowly.

A spinner with a `label` is a polite status message: screen readers announce
the label. Without a label the spinner is decoration and hidden from assistive
technology, so the text next to it should say what is going on. A
[Klar.Button](Klar.Button.md) with `loading` shows a spinner by itself.

## Spinners

### `view`

```elm
view : List Attribute -> Html msg
```

An inline spinner, small enough to sit next to text or inside a button.
With a `label` it is a status message for screen readers; without one it is only
decoration (the text next to it, or `aria-busy` on the button, says what is
going on).

    Spinner.view [ Spinner.label "Saving" ]

### `panel`

```elm
panel : String -> Html msg
```

A large spinner with a text below it, centered in the space around it, to
fill a panel or a table body while it loads. The text is visible, and screen
readers announce it as a status message.

    Spinner.panel "Loading orders ..."

## Attributes

### `Attribute`

```elm
type Attribute  -- opaque: no constructors are exposed
```

A setting of a spinner. Make them with `size` and `label` and pass a list
to `view`; later attributes win over earlier ones.

### `size`

```elm
size : Theme.Size -> Attribute
```

The size of the spinner: `Small` (12px), `Medium` (14px, the default) or
`Large` (22px, drawn in the primary color).

### `label`

```elm
label : String -> Attribute
```

Text that screen readers announce as a polite status message, for example
"Loading orders". The default is no label, which makes the spinner a
decoration that is hidden from assistive technology.
