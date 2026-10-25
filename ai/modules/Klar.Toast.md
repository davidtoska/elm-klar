# Klar.Toast

Short notifications that appear in a corner of the window, stack up and go away by themselves: "Order saved", "Could not send the invoice".

Import: `import Klar.Toast as Toast` | Group: Overlays

Types: `Msg`, `State`, `Attribute`

## Signatures

```elm
-- View
view : (Msg -> msg) -> List (Attribute msg) -> State msg -> Overlay.Overlay msg

-- State
type State msg  -- opaque: no constructors are exposed
type Msg  -- opaque: no constructors are exposed
init : String -> State msg
update : Msg -> State msg -> ( State msg, Cmd Msg )
setMaxVisible : Int -> State msg -> State msg
count : State msg -> Int
queued : State msg -> Int
focus : State msg -> Cmd Msg

-- Showing and removing toasts
push : List (Attribute msg) -> State msg -> ( State msg, Cmd Msg )
dismiss : String -> State msg -> State msg
dismissAll : State msg -> State msg

-- Content
type Attribute msg  -- opaque: no constructors are exposed
title : String -> Attribute msg
message : String -> Attribute msg
action : String -> msg -> Attribute msg
key : String -> Attribute msg

-- Tone and time
tone : Theme.Tone -> Attribute msg
duration : Int -> Attribute msg
sticky : Attribute msg

-- Texts
locale : Locale.Locale -> Attribute msg
```

## Documentation

Short notifications that appear in a corner of the window, stack up and go
away by themselves: "Order saved", "Could not send the invoice".

Use when: the user needs feedback about something they just did, which needs no decision.
Do not use when: a message must stay on the page (use `Klar.Alert`) or the user must answer a question (use `Klar.ConfirmDialog`).
Quick path: `init`, `push`, `update`, `view`, `dismissAll`

    import Klar.Theme exposing (Tone(..))
    import Klar.Toast as Toast

    -- model:   toasts : Toast.State Msg       (Toast.init "toasts")

    -- update
    OrderSaved ->
        let
            ( toasts, cmd ) =
                Toast.push
                    [ Toast.tone Success
                    , Toast.title "Order saved"
                    , Toast.message "Order 1042 was updated."
                    ]
                    model.toasts
        in
        ( { model | toasts = toasts }, Cmd.map ToastMsg cmd )

    ToastMsg m ->
        let
            ( toasts, cmd ) =
                Toast.update m model.toasts
        in
        ( { model | toasts = toasts }, Cmd.map ToastMsg cmd )

    -- view (once, in the list of overlays; it is fixed in the bottom right corner)
    Toast.view ToastMsg [] model.toasts

A toast can carry one action, typically "Undo". Clicking it sends the
application's message and dismisses the toast:

    Toast.push [ Toast.message "Order deleted.", Toast.action "Undo" UndoDelete ] model.toasts

The state holds the application's messages, hence `State msg`.

A keyboard user needs a quick way to the "Undo" before it goes away: bind a key to
`focus` with [Klar.Shortcut](Klar.Shortcut.md). Take a key that the browser leaves
free, such as `F8`; `F6` belongs to the browser, which moves focus to its address
bar with it. The timer of a toast stops while focus is in it.

    -- shortcuts
    Shortcut.shortcut (Shortcut.function 8) "General" "Go to the notifications" FocusToasts

    -- update
    FocusToasts ->
        ( model, Cmd.map ToastMsg (Toast.focus model.toasts) )

## View

Render the stack once, always, near the root of the application: it is the live
region that screen readers listen to. Put it in the list of overlays of
[`Overlay.host`](Klar.Overlay.md#host), so that the toasts stay usable while a dialog
is open: they move out of the corner (to the top of the window, or to the other side
of a drawer) and `Tab` reaches them after the footer of the dialog. New toasts are
announced politely, without interrupting what the screen reader is saying; a
`Danger` toast is announced at once. A toast that goes away is not announced, and
neither are the ones that stay. Every toast has a close button, and one with an
action has a button for it; both can be reached with `Tab`. When the toast that has
focus goes away (it was closed, its action ran, or the application dismissed it),
focus moves to the next toast, or back to where it was before it came into the
stack, never to the top of the page.

### `view`

```elm
view : (Msg -> msg) -> List (Attribute msg) -> State msg -> Overlay.Overlay msg
```

The stack of toasts, fixed in the bottom right corner above everything else.
Put it in the list of overlays of [`Overlay.host`](Klar.Overlay.md#host) (or
`AppShell.overlays`), always, even when there are no toasts: it is the live region
screen readers listen to. Of the attributes only `locale` has an effect here.

While a dialog is open the stack moves to the top of the window, so that it never
covers the footer buttons; beside a drawer it goes to the bottom of the other side of
the window, so that the title and the close button of the drawer stay in reach (on a
narrow screen, where the drawer fills the window, it is at the top). It becomes the last stop of the dialog's
`Tab` loop: after the footer, `Tab` goes through the toasts (the action and the
close button of each) and then to the first element of the dialog again.

## State

At most `setMaxVisible` (default 4) toasts are shown; the rest wait in a queue and
take their place, with a fresh timer, as toasts go away (or at once, when you
raise the limit).

### `State`

```elm
type State msg  -- opaque: no constructors are exposed
```

The toasts on screen and the ones waiting in the queue. The type parameter is
your message type, because a toast can carry an action message. Create it with
`init`, keep it in your model, and change it with `push`, `dismissAll` and `update`.

### `Msg`

```elm
type Msg  -- opaque: no constructors are exposed
```

The messages of the toast stack (timers, dismissing, and the pause while a
toast is hovered or focused). Wrap it in a constructor of your own message type,
such as `ToastMsg Toast.Msg`, and hand it to `update`.

### `init`

```elm
init : String -> State msg
```

No toasts. The `String` is the DOM id of the stack: unique on the page, and the
ids of the toasts start with it. Up to four toasts are shown at once; change that
with `setMaxVisible`.

    Toast.init "toasts"

### `update`

```elm
update : Msg -> State msg -> ( State msg, Cmd Msg )
```

Handles timers, dismissing and the pause while a toast is hovered or focused.
Map its command into your own message with `Cmd.map`.

### `setMaxVisible`

```elm
setMaxVisible : Int -> State msg -> State msg
```

How many toasts are shown at once (at least 1; the default is 4). Set it when
you create the state, for example `Toast.init "toasts" |> Toast.setMaxVisible 3`.
Raising it later moves the toasts that are waiting in the queue up at once, and
their timers start with the next `push` or `update`; lowering it hides nothing.

### `count`

```elm
count : State msg -> Int
```

The number of toasts on screen plus the ones in the queue.

### `queued`

```elm
queued : State msg -> Int
```

The number of toasts waiting in the queue because the most toasts that can be
shown are already on screen.

### `focus`

```elm
focus : State msg -> Cmd Msg
```

Moves focus to the newest toast on screen: to its action ("Undo") if it has
one, else to its close button. Nothing happens when there is no toast. Bind it to a
key with [Klar.Shortcut](Klar.Shortcut.md), so that a keyboard user reaches a toast
before it goes away (its timer stops while focus is in it). When that toast goes
away, focus returns to where it was.

## Showing and removing toasts

### `push`

```elm
push : List (Attribute msg) -> State msg -> ( State msg, Cmd Msg )
```

Adds a toast built from the attributes. The command starts its timer: map it
into your own message. When the most toasts that can be shown are already on
screen, the new one waits in the queue. A toast with the same `key` as one on
screen or in the queue replaces it.

    Toast.push [ Toast.tone Warning, Toast.message "Stock is running low." ] model.toasts

### `dismiss`

```elm
dismiss : String -> State msg -> State msg
```

Removes the toast with this key (see `key`), on screen or waiting, and lets the
next one in the queue take its place. A key that no toast has changes nothing, so it is
safe to call when the toast may already be gone. Call it from `update`, for example
when a retry succeeded and the failure toast of the first try is stale:

    Toast.dismiss "note-save" model.toasts

If that toast had focus, focus moves to the next toast or back to where it was.

### `dismissAll`

```elm
dismissAll : State msg -> State msg
```

Removes every toast at once, the ones on screen and the ones in the queue. If
one of them had focus, focus goes back to where it was before it came into the
stack.

## Content

### `Attribute`

```elm
type Attribute msg  -- opaque: no constructors are exposed
```

A setting of a toast. Make them with the functions below and pass a list to
`push`; later attributes win over earlier ones. `view` takes the same list type
but only reads `locale`.

### `title`

```elm
title : String -> Attribute msg
```

A bold first line above the message.

### `message`

```elm
message : String -> Attribute msg
```

The text of the toast. It is empty by default, so give a `message`, a `title`
or both.

### `action`

```elm
action : String -> msg -> Attribute msg
```

One button, usually "Undo". A click sends the message and dismisses the toast.
A toast with an action stays at least 8 seconds, unless you set `duration` or
`sticky`.

    Toast.action "Undo" UndoDelete

### `key`

```elm
key : String -> Attribute msg
```

Names the toast, so that the application can take it away from `update` with
`dismiss`, and so that a new toast with the same key replaces the old one instead of
stacking next to it (a second failed save shows one toast, not two).

    Toast.push [ Toast.tone Danger, Toast.key "note-save", Toast.title "Could not save the note" ] model.toasts

## Tone and time

An `Info` toast (the default) goes away after 5 seconds, a `Success` toast after
4 and a `Warning` toast after 8; a `Danger` toast stays until it is closed. A
toast with an action stays at least 8 seconds. Change it with `duration` or
`sticky`. The timer stops while the pointer is over a toast or focus is inside
it, and starts over when the pointer leaves.

### `tone`

```elm
tone : Theme.Tone -> Attribute msg
```

The tone of the toast (a [`Tone`](Klar.Theme.md#tone)). It sets the icon, the
color of the accent and how long the toast stays on screen: `Info`, the default,
is a plain notice with a blue accent (5 seconds); `Success` something that went
well, with a green accent and a check mark (4 seconds); `Warning` something that
needs attention, with an amber accent and a warning sign (8 seconds); `Danger`
something that went wrong, with a red accent and an error sign, which stays until
the user closes it and is announced to screen readers at once. `Neutral` looks
like `Info` with a gray accent.

    Toast.push [ Toast.tone Danger, Toast.message "Could not send the invoice." ] model.toasts

### `duration`

```elm
duration : Int -> Attribute msg
```

Dismiss after this many milliseconds, whatever the tone. The timer stops
while the pointer is over the toast or focus is inside it.

### `sticky`

```elm
sticky : Attribute msg
```

Stays until the user closes it, whatever the tone.

## Texts

### `locale`

```elm
locale : Locale.Locale -> Attribute msg
```

For `view`: the language of the built-in text, which is the label of the
stack for screen readers ("Notifications"), the note "+ 2 more waiting" and the
label of the close buttons ("Dismiss notification"). `push` ignores it. The
default is [`Locale.default`](Klar.Locale.md#default), which is English.
