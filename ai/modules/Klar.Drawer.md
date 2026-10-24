# Klar.Drawer

A panel that slides in from the side of the window: the details of a row in a list, a form with many filters, anything the user wants to see next to the page they came from.

Import: `import Klar.Drawer as Drawer` | Group: Overlays

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
type alias State = Modal.State
type alias Msg = Modal.Msg
init : String -> State
update : Msg -> State -> ( State, Cmd Msg )
isOpen : State -> Bool

-- Opening and closing
open : String -> State -> ( State, Cmd Msg )
openWith : { opener : String, focus : List String } -> State -> ( State, Cmd Msg )
close : State -> ( State, Cmd Msg )
closeButtonId : State -> String

-- Content
type alias Attribute msg = Modal.Attribute msg
subtitle : String -> Attribute msg
footer : List (Html msg) -> Attribute msg
footerStart : List (Html msg) -> Attribute msg
flush : Attribute msg
hideClose : Attribute msg
ariaDescribedBy : String -> Attribute msg

-- Size and side
small : Attribute msg
medium : Attribute msg
large : Attribute msg
right : Attribute msg
left : Attribute msg

-- Dismissing
static : Attribute msg
busy : Bool -> Attribute msg
onRequestClose : msg -> Attribute msg

-- Keyboard focus
lastFocus : String -> Attribute msg

-- Texts
locale : Locale.Locale -> Attribute msg
```

## Documentation

A panel that slides in from the side of the window: the details of a row in
a list, a form with many filters, anything the user wants to see next to the
page they came from.

Use when: the user looks at details or a form next to the page they came from, such as the details of a row in a list.
Do not use when: the task must be finished first (use `Klar.Modal`), the question is yes-or-no (use `Klar.ConfirmDialog`), the panel is small and next to a button (use `Klar.Popover`), or the user keeps working in the page beside the panel, moving from row to row (use `Klar.Splitter`: a drawer makes the page behind it inert).
Quick path: `init`, `open`, `update`, `view`, `close`, `isOpen`

    import Klar.Button as Button
    import Klar.Drawer as Drawer

    -- model:   drawer : Drawer.State          (Drawer.init "order-drawer")

    -- update
    ShowOrder order ->
        let
            ( drawer, cmd ) =
                Drawer.open "show-order-button" model.drawer
        in
        ( { model | drawer = drawer, selected = Just order }, Cmd.map DrawerMsg cmd )

    DrawerMsg m ->
        let
            ( drawer, cmd ) =
                Drawer.update m model.drawer
        in
        ( { model | drawer = drawer }, Cmd.map DrawerMsg cmd )

    -- view
    Drawer.view DrawerMsg
        [ Drawer.subtitle "Last changed 12 October"
        , Drawer.footer [ Button.view [ Button.onClick CloseDrawer ] "Close" ]
        ]
        model.drawer
        "Order 1042"
        [ orderDetails ]

A drawer is a [Klar.Modal](Klar.Modal.md) shown along the right or left edge of
the window. It has the same state and the same attributes, and it behaves the
same way: focus moves in when it opens, `Tab` stays inside, focus returns to
the opener when it closes, and `Escape`, a click on the backdrop and the close
button close it unless it is `static` or `busy`. The page behind an open drawer
cannot be scrolled, and the [`Overlay`](Klar.Overlay.md#overlay) that `view` returns
makes it `inert`. If the element that has focus inside the drawer is removed or
disabled (a button replaced after an action), focus moves to the drawer itself.
[Klar.Modal](Klar.Modal.md) and [Klar.Overlay](Klar.Overlay.md) explain all of this once,
for every overlay.

The details of a row usually load after the drawer opens. Give it the body of
[Klar.RemoteView](Klar.RemoteView.md): a skeleton that screen readers hear, the
failure with a retry, and old or refreshing data, with no `case` of your own.
Focus that was on the retry button goes back into the drawer when the data
arrives.

    Drawer.view DrawerMsg
        []
        model.drawer
        "Order 1042"
        (RemoteView.view [ RemoteView.onRetry ReloadOrder ] model.order viewOrder)

The drawer is as tall as the window. It is `medium` (480px) unless you say
`small` (360px) or `large` (720px), and never wider than the window. The only
built-in text is the label of the close button, which follows `locale`;
everything else comes from your application.

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

The drawer titled `title`, with `body` in its scrolling middle; it comes in
from the right unless you say `left`. The title is the heading of the drawer and
its accessible name. `toMsg` wraps the messages of the drawer. Renders nothing
while closed, so it can stay in your view all the time. It returns an
[`Overlay`](Klar.Overlay.md#overlay): put it in the list of overlays of
[`Overlay.host`](Klar.Overlay.md#host) or `AppShell.overlays`.

## State

### `State`

```elm
type alias State = Modal.State
```

The state of one drawer: whether it is open and where focus returns to.
Create it with `init`, keep it in your model and change it with `open`,
`close` and `update`. It is the same type as `Klar.Modal.State`.

### `Msg`

```elm
type alias Msg = Modal.Msg
```

The messages of a drawer (focus movements and the request to close). Wrap
it in a constructor of your own message type, such as `DrawerMsg Drawer.Msg`,
and hand it to `update`.

### `init`

```elm
init : String -> State
```

A closed drawer. The `String` is the DOM id of the drawer and must be
unique on the page.

### `update`

```elm
update : Msg -> State -> ( State, Cmd Msg )
```

Handles the focus movements and the request to close the drawer (from the
close button, `Escape` or the backdrop). Map its command into your own message.

### `isOpen`

```elm
isOpen : State -> Bool
```

Is the drawer open? The page is made inert by the overlay `view` returns; this
is for your own logic.

## Opening and closing

### `open`

```elm
open : String -> State -> ( State, Cmd Msg )
```

Opens the drawer and moves focus into it. `opener` is the DOM id of the
element to give focus back to when the drawer closes, such as the button or the
table row that opened it. With `""`, or when that element is gone, focus goes back
to the most recent element of the page that had focus before the drawer opened
and still exists (it needs an id). A drawer opened by a route change needs no
opener.

### `openWith`

```elm
openWith : { opener : String, focus : List String } -> State -> ( State, Cmd Msg )
```

Like `open`, with a list of element ids that should receive focus first
(a search field, say). The first one that exists wins; if none does, the drawer
itself gets focus.

    Drawer.openWith { opener = "filters-button", focus = [ "customer-search" ] } model.drawer

### `close`

```elm
close : State -> ( State, Cmd Msg )
```

Closes the drawer and gives focus back to its opener. Call it from your own
buttons (a "Close" button in the footer, say) and when the work is done. The
built-in close button, `Escape` and the backdrop close the drawer through
`update`.

### `closeButtonId`

```elm
closeButtonId : State -> String
```

The DOM id of the close button in the header, for use as the `opener` of a
dialog that you open from the drawer (a "Discard changes?" question asked from
`onRequestClose`, say), so that focus comes back to the close button. There is
no such button with `hideClose`.

## Content

### `Attribute`

```elm
type alias Attribute msg = Modal.Attribute msg
```

A setting of a drawer. Make them with the functions below and pass a list
to `view`; later attributes win over earlier ones. It is the same type as
`Klar.Modal.Attribute`.

### `subtitle`

```elm
subtitle : String -> Attribute msg
```

A smaller line below the title, for context such as the date of the last
change.

### `footer`

```elm
footer : List (Html msg) -> Attribute msg
```

The actions, right aligned in a fixed footer at the bottom of the drawer. The
primary action goes last. The footer is only shown when `footer` or
`footerStart` is given.

### `footerStart`

```elm
footerStart : List (Html msg) -> Attribute msg
```

Content at the left end of the footer, opposite the actions: a note, a
checkbox, a "Delete order" link.

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
close the drawer unless it is `static`, so give the user another way out, such
as a "Close" button in the footer.

### `ariaDescribedBy`

```elm
ariaDescribedBy : String -> Attribute msg
```

The id of an element inside the drawer that describes it, such as a
paragraph of explanation. Screen readers read it out after the title.

## Size and side

### `small`

```elm
small : Attribute msg
```

360px wide.

### `medium`

```elm
medium : Attribute msg
```

480px wide. This is the default.

### `large`

```elm
large : Attribute msg
```

720px wide.

### `right`

```elm
right : Attribute msg
```

Slide in from the right edge. This is the default.

### `left`

```elm
left : Attribute msg
```

Slide in from the left edge.

## Dismissing

### `static`

```elm
static : Attribute msg
```

A click on the backdrop and `Escape` do not close the drawer; the close
button still does. Use it for a drawer with a form, so that unsaved input is not
lost by a stray click. The drawer gives a small nudge instead, so that it does
not feel frozen.

### `busy`

```elm
busy : Bool -> Attribute msg
```

While `True` nothing can close the drawer: the close button is disabled and
the backdrop and `Escape` are ignored. Pass a field of your model that is `True`
while a request runs.

### `onRequestClose`

```elm
onRequestClose : msg -> Attribute msg
```

Send this message instead of closing. The close button, `Escape` and the
backdrop then send `msg` and the drawer stays open; the application decides,
and calls `close` when it is fine to go (after asking "Discard changes?", say).

## Keyboard focus

### `lastFocus`

```elm
lastFocus : String -> Attribute msg
```

The id of the element that `Shift+Tab` on the first element of the drawer
wraps around to, usually the primary button. Without it focus lands at the end of
the footer (or of the body when there is no footer), and the next `Shift+Tab`
reaches the last button.

## Texts

### `locale`

```elm
locale : Locale.Locale -> Attribute msg
```

The language of the built-in text, which is the label of the close button
("Close" by default). The default language is
[`Locale.default`](Klar.Locale.md#default), which is English.
