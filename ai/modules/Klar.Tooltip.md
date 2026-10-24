# Klar.Tooltip

Short hints that appear when the pointer rests on an element or the keyboard focuses it.

Import: `import Klar.Tooltip as Tooltip` | Group: Overlays

Types: `Option`

## Signatures

```elm
-- On an element
attrs : List Option -> String -> List (Html.Attribute msg)

-- Around an element
wrap : List Option -> String -> (List (Html.Attribute msg) -> Html msg) -> Html msg

-- Options
type Option  -- opaque: no constructors are exposed
shortcut : Shortcut.Keys -> Option
platform : Kbd.Platform -> Option
below : Option
focusable : Option
id : String -> Option
```

## Documentation

Short hints that appear when the pointer rests on an element or the keyboard
focuses it. There is no state and there are no messages: it is all CSS.

Use when: an icon-only button, a keyboard shortcut or an unavailable control needs a short hint on hover or focus.
Do not use when: the user needs the information to proceed (put it in the page, or use `Klar.Popover` for richer content).

    import Klar.Button as Button
    import Klar.Shortcut as Shortcut
    import Klar.Tooltip as Tooltip

    -- on any element that takes attributes
    Button.iconOnly [ Button.htmlAttrs (Tooltip.attrs [] "Delete order") ] Icon.trash "Delete order"

    -- with the keyboard shortcut, the same `Shortcut.Keys` that Klar.Shortcut listens to
    Button.iconOnly
        [ Button.htmlAttrs (Tooltip.attrs [ Tooltip.shortcut (Shortcut.mod (Shortcut.char 'k')) ] "Open search") ]
        Icon.search
        "Search"

    -- a control that is unavailable stays focusable (ariaDisabled, never
    -- disabled), so that the keyboard reaches it and hears why
    Button.view
        [ Button.ariaDisabled True
        , Button.htmlAttrs (Tooltip.attrs [] "A shipped order cannot be deleted")
        ]
        "Delete"

    -- a real tooltip element, linked to the control the function draws
    Tooltip.wrap [ Tooltip.id "delete-tip" ]
        "A shipped order cannot be deleted"
        (\tip -> Button.view [ Button.ariaDisabled True, Button.htmlAttrs tip ] "Delete")

There are two flavors. `attrs` adds a data attribute to the element and lets the
stylesheet draw the tip: plain text, with the shortcut after a middle dot. `wrap`
renders a real `role="tooltip"` element next to the content, which the control
refers to with `aria-describedby`, and draws the shortcut as key caps. A few rules
of thumb:

  - A tooltip is a visual aid for sighted users. The element must have a name
    of its own (icon buttons get it from `aria-label`). `wrap` also gives screen
    readers the text, as the description of the control.
  - Do not combine it with a native `title`. `attrs` clears it.
  - `wrap` needs an id for its tip. Without the `id` option it is built from the
    text and the shortcut, so two wrapped tips on one page with the same words
    share an id: give each its own `id` when a page repeats a tip (on every row
    of a table, say), or use `attrs`, which needs no id.
  - The tip appears after a short delay on hover, and a shorter one on keyboard
    focus. It sits centered above the element and flips below it when there is
    no room, and it is kept inside the window at the left and right edges, so a
    table, a card or a dialog does not cut it off. Browsers without CSS anchor
    positioning show it centered above the element and do none of this. On a
    touch screen it shows on focus only.
  - `attrs` works on elements that can have pseudo-elements, which excludes
    `input`, `img` and similar. Use `wrap` for those.
  - `Escape` does not hide a tip: moving the pointer away or the focus on does.
  - There is no built-in text, so there is no `locale`.

## On an element

### `attrs`

```elm
attrs : List Option -> String -> List (Html.Attribute msg)
```

Attributes that give an element a tooltip with this text. Add them to the
attributes of the element, or hand them to a component that takes raw
attributes, such as `Button.htmlAttrs`.

    Tooltip.attrs [] "Sort by date"

    Tooltip.attrs [ Tooltip.below, Tooltip.shortcut (Shortcut.mod (Shortcut.char 'k')) ] "Open search"

## Around an element

### `wrap`

```elm
wrap : List Option -> String -> (List (Html.Attribute msg) -> Html msg) -> Html msg
```

A tooltip as a real element (`role="tooltip"`) next to a control. The function
draws the control and receives the attributes to put on it: the `aria-describedby`
that links it to the tip, so that a screen reader reads the tip as the description
of the control when it gets focus. Hand them to `Button.htmlAttrs`, or put them on
your own element.

    Tooltip.wrap [ Tooltip.below, Tooltip.id "pin-tip" ]
        "Pin to the top"
        (\tip -> Button.iconOnly [ Button.htmlAttrs tip ] Icon.bookmark "Pin")

For content that cannot take focus (a badge, a truncated text, a disabled link),
add `focusable`: the wrapper becomes the tab stop and carries the
`aria-describedby` itself, and the function receives no attributes.

    Tooltip.wrap [ Tooltip.focusable ] "Only warehouse staff can do this" (\_ -> Badge.view [] "Locked")

## Options

### `Option`

```elm
type Option  -- opaque: no constructors are exposed
```

A setting for `attrs` and `wrap`. Make one with `shortcut`, `platform`,
`below`, `focusable` or `id`.

### `shortcut`

```elm
shortcut : Shortcut.Keys -> Option
```

The keyboard shortcut to show next to the text: the same
[`Shortcut.Keys`](Klar.Shortcut.md#keys) that [Klar.Shortcut](Klar.Shortcut.md) listens
to, so the hint cannot drift from the binding. With `attrs` it follows the text
after a middle dot ("Open search · Ctrl+K"), with `wrap` it is drawn as key caps.
It is announced as `aria-keyshortcuts`, in the key names of ARIA (`Control+K`);
a sequence of keys (`G` then `O`) is shown but not announced, since ARIA has no
words for one.

    Tooltip.shortcut (Shortcut.mod (Shortcut.char 'k'))

### `platform`

```elm
platform : Kbd.Platform -> Option
```

Which keyboard to write the shortcut for: [`Kbd.pc`](Klar.Kbd.md#pc), the
default (Ctrl, Alt, Shift), or [`Kbd.mac`](Klar.Kbd.md#mac) (⌘, ⌥, ⇧, and `mod` is
Cmd). Pass the same platform you give [Klar.Kbd](Klar.Kbd.md).

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
the element itself for `attrs`, the wrapper for `wrap` (which then carries the
`aria-describedby` too, and hands the function no attributes). Use it for content
that cannot take focus: a truncated text, a badge, a disabled link. Leave it out
for buttons and links, which can be focused already.

### `id`

```elm
id : String -> Option
```

The DOM id of the tip that `wrap` draws; the control refers to it with
`aria-describedby`. Without it the id is built from the text and the shortcut, so
two tooltips with the same words on one page share an id: give each its own when a
page repeats a tip (on every row of a table, say), or use `attrs`, which needs no
id. `attrs` ignores it.

    Tooltip.wrap [ Tooltip.id ("delete-tip-" ++ order.id) ] "Delete order" deleteButton
