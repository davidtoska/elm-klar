# Klar.Tooltip

Short hints that appear when the pointer rests on an element or the keyboard focuses it.

Import: `import Klar.Tooltip as Tooltip` | Group: Overlays

Types: `Option`

## Signatures

```elm
-- On an element
attrs : String -> List (Html.Attribute msg)
attrsWith : List Option -> String -> List (Html.Attribute msg)
withShortcut : String -> List (Html.Attribute msg) -> List (Html.Attribute msg)
placeBelow : List (Html.Attribute msg) -> List (Html.Attribute msg)

-- Around an element
wrap : List Option -> String -> Html msg -> Html msg

-- Options
type Option  -- opaque: no constructors are exposed
shortcut : String -> Option
below : Option
focusable : Option
id : String -> Option
```

## Documentation

Short hints that appear when the pointer rests on an element or the keyboard
focuses it. There is no state and there are no messages: it is all CSS.

Use when: an icon-only button, a keyboard shortcut or an unavailable control needs a short hint on hover or focus.
Do not use when: the user needs the information to proceed (put it in the page, or use `Klar.Popover` for richer content).

    import Klar.Tooltip as Tooltip

    -- on any element that accepts attributes
    Button.iconOnly [ Button.htmlAttrs (Tooltip.attrs "Delete order") ] Icon.trash "Delete order"

    -- with the keyboard shortcut
    Button.iconOnly
        [ Button.htmlAttrs (Tooltip.attrs "Open search" |> Tooltip.withShortcut "Ctrl K") ]
        Icon.search
        "Search"

    -- around something you cannot put attributes on (a badge, a disabled
    -- button, a truncated text)
    Tooltip.wrap [] "A shipped order cannot be deleted" (Button.view [ Button.disabled True ] "Delete")

    Tooltip.wrap [ Tooltip.shortcut "Ctrl K" ] "Open search" child

There are two flavors. `attrs` adds a data attribute to the element and lets
the stylesheet draw the tip: plain text, with the shortcut after a middle dot.
`wrap` renders a real `role="tooltip"` element next to the content, linked with
`aria-describedby`, and draws the shortcut as key caps. A few rules of thumb:

  - A tooltip is a visual aid for sighted users. The element must have a name
    of its own (icon buttons get it from `aria-label`).
  - Do not combine it with a native `title`. `attrs` clears it.
  - `wrap` builds the id of the tip from its text and shortcuts, unless you give
    an `id`. Two wrapped tooltips on one page with the same text, the same
    shortcuts and no `id` therefore share an id: the page has a duplicate id, and
    the second wrapper is described by the first tip (which has the same words).
    Give each its own `id`, or use `attrs`, which needs no id.
  - The tip appears after a short delay on hover, and a shorter one on keyboard
    focus. It sits centered above the element and flips below it when there is
    no room, and it is kept inside the window at the left and right edges, so a
    table, a card or a dialog does not cut it off. Browsers without CSS anchor
    positioning show it centered above the element and do none of this.
  - `attrs` works on elements that can have pseudo-elements, which excludes
    `input`, `img` and similar. Use `wrap` for those.
  - There is no built-in text, so there is no `locale`.

## On an element

### `attrs`

```elm
attrs : String -> List (Html.Attribute msg)
```

Attributes that give an element a tooltip with this text. Add them to the
attributes of the element, or hand them to a component that takes raw
attributes, such as `Button.htmlAttrs`.

### `attrsWith`

```elm
attrsWith : List Option -> String -> List (Html.Attribute msg)
```

Like `attrs`, with options.

    Tooltip.attrsWith [ Tooltip.below, Tooltip.shortcut "Ctrl K" ] "Open search"

### `withShortcut`

```elm
withShortcut : String -> List (Html.Attribute msg) -> List (Html.Attribute msg)
```

Adds the keyboard shortcut to the attributes of `attrs`. It is shown after
the text and announced as `aria-keyshortcuts`, with the key names that ARIA
uses: `Ctrl` becomes `Control`, `Cmd` becomes `Meta`, `Option` becomes `Alt` and
`Esc` becomes `Escape`.

    Tooltip.attrs "Open search" |> Tooltip.withShortcut "Ctrl K"

### `placeBelow`

```elm
placeBelow : List (Html.Attribute msg) -> List (Html.Attribute msg)
```

Shows the tip below the element, for the attributes of `attrs`.

    Tooltip.attrs "Sort by date" |> Tooltip.placeBelow

## Around an element

### `wrap`

```elm
wrap : List Option -> String -> Html msg -> Html msg
```

Wraps an element in a tooltip, for things that cannot take the attributes of
`attrs`. The wrapper is an inline box around the content; the tip is a real
element with `role="tooltip"`, which the wrapper refers to with
`aria-describedby`. Two wrapped tooltips with the same text and shortcuts on one
page need different `id`s.

    Tooltip.wrap [ Tooltip.below ] "Only warehouse staff can do this" (Badge.view [] "Locked")

## Options

### `Option`

```elm
type Option  -- opaque: no constructors are exposed
```

A setting for `attrsWith` and `wrap`. Make one with `shortcut`, `below`,
`focusable` or `id`.

### `shortcut`

```elm
shortcut : String -> Option
```

The keyboard shortcut to show next to the text: `shortcut "Ctrl K"`. Separate
the keys with a space or a `+`. With `attrs` it follows the text after a middle
dot ("Open search · Ctrl K"), with `wrap` it is drawn as key caps.

### `below`

```elm
below : Option
```

Show the tip below the element instead of above it (it still flips to the
other side when there is no room).

### `focusable`

```elm
focusable : Option
```

Lets the keyboard reach the element that carries the tip (`tabindex="0"`):
the wrapper for `wrap`, the element itself for `attrsWith`. Use it so that the
tip of a truncated text or a badge can be read without a pointer. Leave it out
for buttons and links, which can be focused already.

### `id`

```elm
id : String -> Option
```

The DOM id of the tip that `wrap` draws; the wrapper refers to it with
`aria-describedby`. Without it the id is built from the text and the shortcuts,
so two tooltips with the same words on one page share an id: give each its own
when a page repeats a tip (on every row of a table, say), or use `attrs`, which
needs no id. `attrsWith` ignores it.

    Tooltip.wrap [ Tooltip.id ("delete-tip-" ++ order.id) ] "Delete order" deleteButton
