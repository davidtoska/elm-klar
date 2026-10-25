# Klar.Spinner

Loading indicators: a small spinner for inline use and a centered panel for a region that is still loading.

Import: `import Klar.Spinner as Spinner` | Group: Status and feedback

Types: `Attribute`

## Signatures

```elm
-- Spinners
view : List Attribute -> Html msg
panel : List Attribute -> String -> Html msg

-- Attributes
type Attribute  -- opaque: no constructors are exposed
size : Theme.Size -> Attribute
label : String -> Attribute
loading : Bool -> Attribute
compact : Attribute
```

## Documentation

Loading indicators: a small spinner for inline use and a centered panel for
a region that is still loading.

Use when: you do not know what the content will look like or how long the wait will be.
Do not use when: you can sketch the content (use `Klar.Skeleton`), want a bar that shows how far a task has come (use `Klar.Progress`), or the region shows a `Remote` (use `Klar.RemoteView`, which draws loading, failure and old data for you).

    import Klar.Spinner as Spinner
    import Klar.Theme exposing (Size(..))

    -- always in the view; it spins and is announced while model.saving is True
    Spinner.view [ Spinner.label "Saving order", Spinner.loading model.saving ]

    Spinner.view [ Spinner.size Large ]

    -- always in the view, next to the orders it waits for
    Spinner.panel [ Spinner.loading model.loadingOrders ] "Loading orders ..."

Use a spinner when you do not know what the content will look like or how long
the wait will be. When you can sketch the content, show a
[Klar.Skeleton](Klar.Skeleton.md) instead.

A spinner takes the color of the text around it, so it follows disabled and
danger states (only the large size is always drawn in the primary color). For
users who prefer reduced motion it turns more slowly, at the same speed as every
other turning indicator of Klar.

**Screen readers.** A spinner with a `label` is a polite live region. Screen
readers announce a live region reliably only when its text changes while it is
on the page, not when it arrives with its text. So keep a labelled spinner in the
view and switch it with `loading`: the region stays, and only its text comes and
goes. The same holds for a `panel`. Without a label the spinner is decoration
and hidden from assistive technology, so the text next to it should say what is
going on. A [Klar.Button](Klar.Button.md) with `loading` shows a spinner by itself.

## Spinners

### `view`

```elm
view : List Attribute -> Html msg
```

An inline spinner, small enough to sit next to text or inside a button.
With a `label` it is a status message for screen readers; without one it is only
decoration (the text next to it, or `aria-busy` on the button, says what is
going on).

    Spinner.view [ Spinner.label "Saving", Spinner.loading model.saving ]

### `panel`

```elm
panel : List Attribute -> String -> Html msg
```

A large spinner with a text below it, centered in the space around it, to
fill a panel or a table body while it loads. It has the height of an
[Klar.EmptyState](Klar.EmptyState.md) or an [Klar.ErrorState](Klar.ErrorState.md), so
a region that goes from loading to empty or failed keeps its place. The text is
visible and is a polite status message.

A wait that ends within 400ms shows no spinner at all: the panel fades in after
that, so a fast answer does not flash.

Render the panel all the time, next to the content it waits for, and switch it
with `loading`: its live region stays in the page, and screen readers announce
the text when a wait starts. A panel that a `case` branch puts in the page
arrives together with its text, and that is announced unreliably. For a region
that shows a `Remote`, use [Klar.RemoteView](Klar.RemoteView.md) instead.

    Html.div []
        [ Spinner.panel [ Spinner.loading model.loadingOrders ] "Loading orders ..."
        , viewOrders model.orders
        ]

    Spinner.panel [ Spinner.compact, Spinner.loading model.exporting ] "Preparing the export ..."

## Attributes

### `Attribute`

```elm
type Attribute  -- opaque: no constructors are exposed
```

A setting of a spinner. Make them with the functions below and pass a list
to `view` or `panel`; later attributes win over earlier ones.

### `size`

```elm
size : Theme.Size -> Attribute
```

The size of the spinner: `Small` (12px), `Medium` (14px, the default of
`view`) or `Large` (22px, drawn in the primary color, the default of `panel`).

### `label`

```elm
label : String -> Attribute
```

Text that screen readers announce as a polite status message, for example
"Saving order". The default is no label, which makes the spinner a decoration
that is hidden from assistive technology. It has no effect on `panel`, whose
text is visible.

### `loading`

```elm
loading : Bool -> Attribute
```

Whether the wait is on, from your model. The default is `True`. With `False`
nothing is drawn, but a labelled spinner (and a `panel`) keeps its empty live
region in the page, so the next `True` is announced. Render the spinner all the
time with `loading` rather than adding it with an `if`.

    Spinner.view [ Spinner.label "Saving order", Spinner.loading model.saving ]

### `compact`

```elm
compact : Attribute
```

Less vertical space around a `panel`, for tables and small panels. It is the
space of a compact [Klar.EmptyState](Klar.EmptyState.md), and a panel follows a
compact density of the application (`Klar.Settings`) without it. It has no
effect on `view`.
