# Klar.Modal

A dialog on top of the page, for work that needs the user's full attention: editing a record, a form with several fields, a step of a wizard.

Import: `import Klar.Modal as Modal` | Group: Overlays

Types: `Msg`, `State`, `Attribute`

## Signatures

```elm
-- View
view :
    (Msg -> msg)
    -> List (Attribute msg)
    -> State
    -> String
    -> List (Html msg)
    -> Overlay.Overlay msg

-- State
type State  -- opaque: no constructors are exposed
type Msg  -- opaque: no constructors are exposed
init : String -> State
update : Msg -> State -> ( State, Cmd Msg )
isOpen : State -> Bool

-- Opening and closing
open : String -> State -> ( State, Cmd Msg )
openWith : { opener : String, focus : List String } -> State -> ( State, Cmd Msg )
close : State -> ( State, Cmd Msg )

-- Content
type alias Attribute msg = Modal.Config.Attribute msg
subtitle : String -> Attribute msg
footer : List (Html msg) -> Attribute msg
footerStart : List (Html msg) -> Attribute msg
flush : Attribute msg
hideClose : Attribute msg
ariaDescribedBy : String -> Attribute msg

-- Size
small : Attribute msg
medium : Attribute msg
large : Attribute msg
size : Theme.Size -> Attribute msg
fullHeight : Attribute msg

-- Dismissing
static : Attribute msg
busy : Bool -> Attribute msg
onRequestClose : msg -> Attribute msg

-- Keyboard focus
lastFocus : String -> Attribute msg
closeButtonId : State -> String

-- Texts
locale : Locale.Locale -> Attribute msg
```

## Documentation

A dialog on top of the page, for work that needs the user's full attention:
editing a record, a form with several fields, a step of a wizard.

Use when: the user must finish a task, such as editing a record or a form with several fields, before doing anything else.
Do not use when: a yes-or-no question (use `Klar.ConfirmDialog`), a panel beside the page (use `Klar.Drawer`) or a small panel next to a button (use `Klar.Popover`) is enough.
Quick path: `init`, `open`, `update`, `view`, `close`, `isOpen`

    import Klar.Button as Button
    import Klar.Modal as Modal

    -- model:   editDialog : Modal.State          (Modal.init "edit-order-dialog")

    -- update
    EditOrder ->
        let
            ( dialog, cmd ) =
                Modal.open "edit-order-button" model.editDialog
        in
        ( { model | editDialog = dialog }, Cmd.map EditDialogMsg cmd )

    EditDialogMsg m ->
        let
            ( dialog, cmd ) =
                Modal.update m model.editDialog
        in
        ( { model | editDialog = dialog }, Cmd.map EditDialogMsg cmd )

    -- view
    Modal.view EditDialogMsg
        [ Modal.large
        , Modal.footer
            [ Button.view [ Button.onClick CancelEdit ] "Cancel"
            , Button.view [ Button.primary, Button.onClick SaveOrder ] "Save"
            ]
        ]
        model.editDialog
        "Edit order"
        [ orderForm ]

The dialog has a fixed header (the title and a close button), a body that
scrolls on its own and an optional fixed footer for the actions. The title is a
required argument of `view`: it is the heading and the accessible name, so screen
readers announce a modal dialog called "Edit order". In the example, `CancelEdit`
and a successful `SaveOrder` end by calling `Modal.close`; the close button,
`Escape` and a click on the backdrop close the dialog without any code of yours.

This page also describes the rules that all overlays of the library share: the
opener, dismissing, keyboard focus, the page behind and popups.
[Klar.ConfirmDialog](Klar.ConfirmDialog.md) and [Klar.Drawer](Klar.Drawer.md) are
built on this module, and [Klar.Popover](Klar.Popover.md), [Klar.Menu](Klar.Menu.md),
[Klar.ContextMenu](Klar.ContextMenu.md) and [Klar.Toast](Klar.Toast.md) refer back
to it instead of repeating them.

A dialog that shows data from the backend (the record to edit, an order to
review) takes its body from [Klar.RemoteView](Klar.RemoteView.md): the skeleton, the
failure with a retry, and old or refreshing data, without a `case` of your own.

    Modal.view ModalMsg
        []
        model.dialog
        "Order 1042"
        (RemoteView.view [ RemoteView.onRetry ReloadOrder ] model.order viewOrder)

## View

### `view`

```elm
view :
    (Msg -> msg)
    -> List (Attribute msg)
    -> State
    -> String
    -> List (Html msg)
    -> Overlay.Overlay msg
```

The dialog titled `title`, with `body` in its scrolling middle part. The title
is the heading of the dialog and its accessible name. `toMsg` wraps the messages
of the dialog (see the example at the top of this page). Renders nothing while the
dialog is closed, so it can stay in your view all the time. It returns an
[`Overlay`](Klar.Overlay.md#overlay): put it in the list of overlays of
[`Overlay.host`](Klar.Overlay.md#host) or `AppShell.overlays`.

## State

The state remembers whether the dialog is open and where focus has to return
to when it closes. Keep one `State` in your model for every dialog, each with an
id of its own.

### `State`

```elm
type State  -- opaque: no constructors are exposed
```

The state of one dialog: whether it is open, and where focus returns to when
it closes. Create it with `init`, keep it in your model, and change it with
`open`, `close` and `update`.

### `Msg`

```elm
type Msg  -- opaque: no constructors are exposed
```

The messages of a dialog (focus movements and the request to close). Wrap it
in a constructor of your own message type, such as `EditDialogMsg Modal.Msg`,
and hand it to `update`.

### `init`

```elm
init : String -> State
```

A closed dialog. The id must be unique on the page: it becomes the DOM id of
the dialog element, and the ids of the parts inside it start with it.

### `update`

```elm
update : Msg -> State -> ( State, Cmd Msg )
```

Handles the messages of the dialog: it moves focus, nudges a `static`
dialog, and closes the dialog when the user asks for it with the close button,
`Escape` or the backdrop (unless you took that over with `onRequestClose`). Map
its command into your own message with `Cmd.map`.

### `isOpen`

```elm
isOpen : State -> Bool
```

Is the dialog open? The page behind it is made inert by the overlay `view`
returns, so you rarely need this: use it to show something only while the dialog
is open.

## Opening and closing

Opening returns the new state and a command that moves focus into the dialog;
map the command into your own message, as in the example. `open` takes the
_opener_: the DOM id of the element that opened the dialog (give a button an id
with `Button.id`). When the dialog closes, focus goes back to the opener, so
that keyboard users continue where they were. A popover or a menu owns its
button and returns focus to it without being told.

### `open`

```elm
open : String -> State -> ( State, Cmd Msg )
```

Opens the dialog and moves focus into it. `opener` is the DOM id of the
element to give focus back to when the dialog closes, usually the button that
opened it. With `""`, or when that element is gone, focus goes back to the most
recent element of the page that had focus before the dialog opened and still
exists (it needs an id).

    Modal.open "edit-order-button" model.editDialog

### `openWith`

```elm
openWith : { opener : String, focus : List String } -> State -> ( State, Cmd Msg )
```

Like `open`, with a list of element ids that should receive focus. The
first one that exists wins (if none does, the dialog itself gets focus), so a
form can ask for its first field:

    Modal.openWith { opener = "new-order-button", focus = [ "customer-name" ] } model.editDialog

Calling it on a dialog that is already open moves focus again and keeps the
first opener.

### `close`

```elm
close : State -> ( State, Cmd Msg )
```

Closes the dialog and gives focus back to its opener (see `open`). Call it
from your own buttons and when the work is done; the close button, `Escape` and
the backdrop close the dialog through `update`.

## Content

### `Attribute`

```elm
type alias Attribute msg = Modal.Config.Attribute msg
```

A setting of a dialog. Make them with the functions below and pass a list to
`view`; later attributes win over earlier ones. [Klar.Drawer](Klar.Drawer.md) and
[Klar.ConfirmDialog](Klar.ConfirmDialog.md) use the same settings.

### `subtitle`

```elm
subtitle : String -> Attribute msg
```

A smaller line below the title, for context such as the order number.

### `footer`

```elm
footer : List (Html msg) -> Attribute msg
```

The actions, right aligned in a fixed footer at the bottom of the dialog. The
primary action goes last. The footer is only shown when `footer` or
`footerStart` is given.

### `footerStart`

```elm
footerStart : List (Html msg) -> Attribute msg
```

Content at the left end of the footer, opposite the actions: a note, a
checkbox, a "Delete order" link. Giving it also shows the footer.

### `flush`

```elm
flush : Attribute msg
```

No padding around the body, for tables and lists that go edge to edge.

### `hideClose`

```elm
hideClose : Attribute msg
```

Do not show the close button in the header. `Escape` and the backdrop still
close the dialog unless it is `static`, so give the user another way out, such
as a "Cancel" button in the footer.

### `ariaDescribedBy`

```elm
ariaDescribedBy : String -> Attribute msg
```

The id of an element inside the dialog that describes it (a paragraph of
explanation, say). Screen readers read it out after the title.

## Size

A panel along the side of the window is a [Klar.Drawer](Klar.Drawer.md).

### `small`

```elm
small : Attribute msg
```

400px wide, for a short question or a field or two.

### `medium`

```elm
medium : Attribute msg
```

560px wide. This is the default.

### `large`

```elm
large : Attribute msg
```

800px wide, for wide forms and tables.

### `size`

```elm
size : Theme.Size -> Attribute msg
```

Sets the width from a [`Size`](Klar.Theme.md#size): `Small` (400px), `Medium`
(560px, the default) or `Large` (800px). `small`, `medium` and `large` are
shorthands. A [Klar.Drawer](Klar.Drawer.md) is 360, 480 or 720px wide instead.

### `fullHeight`

```elm
fullHeight : Attribute msg
```

The dialog is as tall as the window (less a small margin) instead of only as
tall as its content. For long forms and lists. It stays in the middle of the
window; a panel along its side is a [Klar.Drawer](Klar.Drawer.md).

## Dismissing

By default the close button, `Escape` and a click on the backdrop close the
dialog. Three ways to change that:

  - `static`: the backdrop and `Escape` do nothing (the close button still
    works). Use it for forms with unsaved data. The dialog gives a small nudge
    so it does not feel frozen.
  - `onRequestClose msg`: the dialog never closes itself, it sends `msg` and
    the application decides (for example to ask "Discard changes?" with a
    [Klar.ConfirmDialog](Klar.ConfirmDialog.md) before it calls `Modal.close`).
  - `busy True`: while a request runs nothing can close the dialog.

### `static`

```elm
static : Attribute msg
```

A click on the backdrop and `Escape` do not close the dialog; the close
button still does. The dialog gives a small nudge instead, so that it does not
feel frozen. For forms with unsaved data.

### `busy`

```elm
busy : Bool -> Attribute msg
```

While `True` nothing can close the dialog: the close button is disabled and
the backdrop and `Escape` are ignored. The dialog also announces `aria-busy`.
Pass a field of your model that is `True` while a request runs.

### `onRequestClose`

```elm
onRequestClose : msg -> Attribute msg
```

Send this message instead of closing. The close button, `Escape` and the
backdrop then send `msg` and the dialog stays open; the application decides, and
calls `Modal.close` when it is fine to go (after asking "Discard changes?",
say). A `static` dialog sends `msg` only from its close button.

## Keyboard focus

  - On `open` focus moves into the dialog: to the dialog itself, or to the
    first element named in `openWith { opener = ..., focus = [ "first-field-id" ] }`
    that exists.
  - `Tab` and `Shift+Tab` stay inside: two invisible tab stops around the
    dialog send focus to the other end. Going forward past the last element
    lands on the close button (or on the dialog itself when there is none).
    Going backward past the first lands on the element named with `lastFocus`,
    or else at the end of the footer (the footer shows a focus ring), so that the
    next `Shift+Tab` reaches the last button of the footer.
  - On `close` focus returns to the opener. If that element is gone, or there was
    none (`""`), to the most recent element of the page that had focus before the
    dialog opened and still exists. A dialog opened by a route change or by a
    command from the palette therefore needs no opener. If there is no such element
    either, to the start of the page content (the content area of an `AppShell`,
    the page of an `Overlay.host`), so that the next `Tab` starts there and not
    at the top of the window.
  - If the element that has focus inside the dialog is removed or disabled (a
    button replaced after an action), or focus never arrived (the element named in
    `openWith` was disabled), focus moves to the dialog itself. No call is needed
    for that.
  - `Escape` is layered: a control inside the dialog that handles it (a field that
    clears its text, a select or a menu that closes its list) keeps it, and the
    dialog closes only on an `Escape` that nothing inside handled. The `Escape`
    that cancels an IME composition never closes the dialog.
  - The toasts are the last stop of the loop: see [Klar.Overlay](Klar.Overlay.md).

### `lastFocus`

```elm
lastFocus : String -> Attribute msg
```

The id of the element that `Shift+Tab` on the first element of the dialog
wraps around to, usually the primary button. Without it focus lands at the end of
the footer (or of the body when there is no footer), and the next `Shift+Tab`
reaches the last button.

### `closeButtonId`

```elm
closeButtonId : State -> String
```

The DOM id of the close button in the header. Give it as the `opener` of a
dialog that is opened from this one, such as a "Discard changes?" question asked
from `onRequestClose`, so that focus comes back to the close button when that
dialog closes:

    ConfirmDialog.open (Modal.closeButtonId model.editDialog) model.discardDialog

There is no close button, and so nothing to return to, with `hideClose`.

## Around the dialog

The page behind an open dialog cannot be scrolled: the stylesheet (see
[Klar](Klar.md)) hides the page scrollbar and keeps its place free, so that the
layout does not jump. To also make the page unreachable for the keyboard and for
screen readers, give the dialog to [`Overlay.host`](Klar.Overlay.md#host) (or to
`AppShell.overlays`): `view` returns an [`Overlay`](Klar.Overlay.md#overlay), and the
page is `inert` as soon as one of them is open. There is no flag to keep in step.

Popups (a [Klar.Menu](Klar.Menu.md), a [Klar.Popover](Klar.Popover.md), the list of a
select or a date picker) are drawn with a transparent layer over the whole
window. A click anywhere outside the popup lands on that layer and closes the
popup instead of reaching the element underneath, and `Escape` closes it too.
When such a popup is open inside a dialog, `Escape` closes only the popup, not
the dialog.

A dialog can open another dialog (a [Klar.ConfirmDialog](Klar.ConfirmDialog.md)
from a `Modal`, say): put the upper one after the lower one in the list of
overlays. Focus returns to the button that opened it, inside the lower dialog.

## Texts

### `locale`

```elm
locale : Locale.Locale -> Attribute msg
```

The language of the built-in text, which is the label of the close button
("Close" by default). The default language is
[`Locale.default`](Klar.Locale.md#default), which is English.
