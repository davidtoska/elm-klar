# Klar.Overlay

The layer above the page: dialogs, drawers, the command palette, the shortcut sheet and the toasts.

Import: `import Klar.Overlay as Overlay` | Group: Overlays

Types: `Overlay`

## Signatures

```elm
-- Page and overlays
type Overlay msg  -- opaque: no constructors are exposed
host :
    { attributes : List (Html.Attribute msg), page : List (Html msg), overlays : List (Overlay msg) }
    -> Html msg
map : (a -> b) -> Overlay a -> Overlay b

-- Making your own overlay
dialog :
    { open : Bool, entry : Maybe (List String), watch : Maybe (String -> msg), render : { top : Bool, toastsFollow : Bool } -> Html msg }
    -> Overlay msg
toasts : { render : { trap : Maybe (List String) } -> Html msg } -> Overlay msg
layer :
    List (Overlay msg)
    -> { blocked : Bool, overlays : List (Html msg), watch : List (Html msg) -> List (Html msg) }
```

## Documentation

The layer above the page: dialogs, drawers, the command palette, the shortcut
sheet and the toasts.

Use when: you put dialogs, drawers, toasts or the command palette on the page (one `host` for all of them).
Do not use when: you need a menu or a tooltip next to an element (as `Klar.Menu` or `Klar.Tooltip`).

Every component of that kind ([Klar.Modal](Klar.Modal.md), [Klar.Drawer](Klar.Drawer.md),
[Klar.ConfirmDialog](Klar.ConfirmDialog.md), [Klar.CommandPalette](Klar.CommandPalette.md),
[Klar.ShortcutHelp](Klar.ShortcutHelp.md), [Klar.Toast](Klar.Toast.md),
[Klar.LeaveGuard](Klar.LeaveGuard.md)) has a `view` that
returns an `Overlay`, not plain `Html`. You give the page the list of them and it
does the rest:

    Overlay.host
        { attributes = []
        , page = [ viewOrders model ]
        , overlays =
            [ Modal.view EditDialogMsg [] model.editDialog "Edit order" [ orderForm ]
            , Drawer.view OrderDrawerMsg [] model.orderDrawer "Order 1042" [ details ]
            , ConfirmDialog.view CancelDialogMsg [] model.cancelDialog "Cancel order?"
            , Toast.view ToastMsg [] model.toasts
            ]
        }

An application built on [Klar.AppShell](Klar.AppShell.md) gives the same list to
`AppShell.overlays` and does not use `host`.

Because an overlay cannot be drawn in any other way, the application cannot
forget one:

  - **The page behind is inert** (no keyboard, no screen reader, no clicks) as soon
    as any dialog in the list is open. There is no flag to compute.
  - **The last open dialog in the list is on top.** Only it watches the keyboard
    focus: when the element that has focus is removed or disabled (a button that
    makes way for "Saving ...", say) focus moves to the dialog itself, so that
    `Escape` and `Tab` keep working. The application never calls anything for that.
  - **Focus goes back to where it was.** Every dialog that is closed remembers the
    last elements that had focus on the page. When the dialog closes, focus goes to
    its opener, or else to the most recent of those that still exist. A drawer
    opened by a route change, or by a command from the palette, returns focus to the
    row the user came from without being told. When nothing is known (the
    shortcut was pressed with focus on `body`), focus goes to the start of the page
    content, so the next `Tab` does not start at the top of the window.
  - **The toasts stay reachable.** While a dialog is open they move to the top of
    the window, or to the bottom of the side that a drawer leaves free (they never
    cover the footer buttons, the title or the close button), and are the last stop of the
    `Tab` loop of the dialog: after the footer, `Tab` goes through the buttons of
    the toasts and then back to the first element of the dialog.

Keep every overlay in the list all the time, also while it is closed (a closed
dialog draws nothing, but it is the one that remembers where focus was). A list
that changes length does no harm to the page (it keeps its place in the DOM, with
its focus, its typed text and its scroll positions), but a dialog that is not in
the list cannot remember anything. Up to 12 closed dialogs remember where focus
was; any further ones return focus to their opener, or to the start of the page.
The order of the list is the stacking order: put a dialog that another one opens
after it, and the toasts anywhere; they are always drawn last.

## Page and overlays

### `Overlay`

```elm
type Overlay msg  -- opaque: no constructors are exposed
```

A dialog, drawer, palette or stack of toasts, ready to be placed in the list
of overlays of a page. You get one from the `view` of the component.

### `host`

```elm
host :
    { attributes : List (Html.Attribute msg), page : List (Html msg), overlays : List (Overlay msg) }
    -> Html msg
```

The root of a page that uses overlays. The `page` is `inert` while any of the
`overlays` is open; the overlays are drawn beside it, so they stay usable.

`attributes` go on the root element, which can receive focus (`tabindex` -1) so
that [Klar.Shortcut](Klar.Shortcut.md) hears key presses that start there:
`[ Shortcut.listen ShortcutMsg shortcuts model.shortcuts ]`.

### `map`

```elm
map : (a -> b) -> Overlay a -> Overlay b
```

Turns the messages of an overlay into the messages of the page around it, as
`Html.map` does: a page module of your own that has dialogs hands them to the
main module with `List.map (Overlay.map PageMsg)`.

## Making your own overlay

The components of this package build their overlays with these. A lightbox or a
wizard is a [Klar.Modal](Klar.Modal.md) (with `flush` and `hideClose`, say), which
brings the focus trap, the recovery of lost focus, the scroll lock and the way
back. `dialog` is for a surface that does all of that itself, as the command
palette does. A page that is not built with `host` or `AppShell` takes the same
steps with `layer`.

### `dialog`

```elm
dialog :
    { open : Bool, entry : Maybe (List String), watch : Maybe (String -> msg), render : { top : Bool, toastsFollow : Bool } -> Html msg }
    -> Overlay msg
```

An overlay that takes over the page while it is open.

  - `open`: is it open? The page is `inert` while any dialog of the list is.
  - `entry`: the ids to try, in order, to give focus to the first element of the
    dialog (the toasts send focus there when `Tab` leaves them). `Nothing` for a
    dialog that keeps focus to itself, like the command palette.
  - `watch`: while the dialog is closed, a message for the id of every element of the
    page that gets focus. Keep the last few ids and, when the dialog closes, give
    focus to the first that still exists. `Nothing` while it is open.
  - `render`: the dialog, told whether it is `top` (the last open one of the list:
    only that one watches for focus that is lost) and whether `toastsFollow` (a
    stack of toasts comes after the dialogs, so the dialog must not close the loop
    of `Tab` stops itself).

### `toasts`

```elm
toasts : { render : { trap : Maybe (List String) } -> Html msg } -> Overlay msg
```

The stack of toasts. `trap` is the `entry` of the dialog that is open on top, if
there is one: the stack is then the last stop of its `Tab` loop and sends focus
back to it.

### `layer`

```elm
layer :
    List (Overlay msg)
    -> { blocked : Bool, overlays : List (Html msg), watch : List (Html msg) -> List (Html msg) }
```

What a page needs from its overlays, for a page that is not made with `host`:

  - `blocked`: some dialog is open, so make the page `inert`.
  - `overlays`: the overlays, drawn, to be placed beside the page.
  - `watch`: wraps the page and the overlays (they must be in one list, in the same
    place every time) so that closed dialogs hear where focus is.
