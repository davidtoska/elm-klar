# Klar.ConfirmDialog

The "are you sure?" dialog, with the whole life of the request it guards.

Import: `import Klar.ConfirmDialog as ConfirmDialog` | Group: Overlays

Types: `Msg`, `State`, `Attribute`

## Signatures

```elm
-- View
view : (Msg -> msg) -> List (Attribute msg) -> State -> String -> Overlay.Overlay msg

-- State
type State  -- opaque: no constructors are exposed
type Msg  -- opaque: no constructors are exposed
init : String -> State
update : Msg -> State -> ( State, Cmd Msg )
isOpen : State -> Bool
isBusy : State -> Bool
problem : State -> Maybe Remote.Problem

-- Opening, confirming and closing
open : String -> State -> ( State, Cmd Msg )
setBusy : State -> State
setFailed : Remote.Problem -> State -> State
clearFailure : State -> State
close : State -> ( State, Cmd Msg )

-- Content
type Attribute msg  -- opaque: no constructors are exposed
message : String -> Attribute msg
body : List (Html msg) -> Attribute msg
consequences : List String -> Attribute msg

-- Tone
tone : Theme.Tone -> Attribute msg
icon : Icon.Icon -> Attribute msg

-- Buttons and typed confirmation
confirmLabel : String -> Attribute msg
cancelLabel : String -> Attribute msg
confirmDisabled : Bool -> Attribute msg
typeToConfirm : String -> Attribute msg
ignoreCase : Attribute msg

-- Messages
onConfirm : msg -> Attribute msg
onCancel : msg -> Attribute msg

-- Texts
locale : Locale.Locale -> Attribute msg
```

## Documentation

The "are you sure?" dialog, with the whole life of the request it guards.

Use when: the user must confirm an action that is hard to undo or that affects others, such as deleting an order or canceling a shipment.
Do not use when: the dialog is a form with several fields to fill in (use `Klar.Modal`); one or two controls in `body`, such as a reason or a target to choose, are fine.
Quick path: `init`, `open`, `update`, `view`, `setBusy`, `close`

The life of a request:

    idle  -->  busy  -->  closed          (success)
                 \--->  failed  -->  busy ...   (retry)

The dialog is a small [Klar.Modal](Klar.Modal.md), so focus, `Escape`, the
backdrop, scroll locking and the page behind it behave as described there. The
application keeps the thing being confirmed (a row, an id) in its own model, and
decides when to close:

    import Klar.ConfirmDialog as ConfirmDialog
    import Klar.Theme exposing (Tone(..))

    -- model:   dialog : ConfirmDialog.State   (ConfirmDialog.init "delete-dialog")
    --          pending : Maybe Order

    -- update
    AskDelete order ->
        let
            ( dialog, cmd ) =
                ConfirmDialog.open "delete-button" model.dialog
        in
        ( { model | dialog = dialog, pending = Just order }, Cmd.map DialogMsg cmd )

    ConfirmDelete ->                                  -- onConfirm
        ( { model | dialog = ConfirmDialog.setBusy model.dialog }, deleteRequest model.pending )

    Deleted (Ok _) ->
        closeDialog model

    Deleted (Err problem) ->
        ( { model | dialog = ConfirmDialog.setFailed problem model.dialog }, Cmd.none )

    CancelDelete ->                                   -- onCancel
        closeDialog model

    DialogMsg m ->
        let
            ( dialog, cmd ) =
                ConfirmDialog.update m model.dialog
        in
        ( { model | dialog = dialog }, Cmd.map DialogMsg cmd )

    -- a helper for the two branches that close the dialog
    closeDialog : Model -> ( Model, Cmd Msg )
    closeDialog model =
        let
            ( dialog, cmd ) =
                ConfirmDialog.close model.dialog
        in
        ( { model | dialog = dialog, pending = Nothing }, Cmd.map DialogMsg cmd )

    -- view
    ConfirmDialog.view DialogMsg
        [ ConfirmDialog.tone Danger
        , ConfirmDialog.message "Order 1042 will be removed from all lists."
        , ConfirmDialog.consequences [ "3 open shipments are canceled" ]
        , ConfirmDialog.confirmLabel "Delete order"
        , ConfirmDialog.typeToConfirm "DELETE"
        , ConfirmDialog.onConfirm ConfirmDelete
        , ConfirmDialog.onCancel CancelDelete
        ]
        model.dialog
        "Delete order?"

The last argument is the question. It is the title of the dialog and its
accessible name, so it cannot be left out.

While the request runs the confirm button shows a spinner and nothing can close
the dialog (`Escape`, the backdrop and the close button are ignored). A failed
request shows the problem inside the dialog, with a "Try again" button when the
problem is worth retrying (see [`Remote.isRetryable`](Klar.Remote.md#isretryable));
the dialog stays open and can be dismissed.

`onCancel` is sent for the cancel button, the close button, `Escape` and the
backdrop. Give it whenever your model holds what is being confirmed (the
`pending` order above), so that a cancel clears it. Without it the dialog closes
itself and your model never hears of it. Either way the dialog forgets the typed
text and the failure when it closes. While the request runs none of them sends
it. (An event from the frame before the dialog re-rendered as busy can still
slip through; if your `onCancel` handler closes the dialog, check
`ConfirmDialog.isBusy` first.)

Focus starts on the typed-confirmation field if there is one, otherwise on
"Cancel", so that a stray `Enter` never confirms a destructive action. Screen
readers announce the dialog as an `alertdialog` and read the message and the
consequences at once; the `body` is not part of that description. The
built-in texts (the buttons, "Try again" and the label of the
typed-confirmation field) follow `locale`.

## View

### `view`

```elm
view : (Msg -> msg) -> List (Attribute msg) -> State -> String -> Overlay.Overlay msg
```

The dialog that asks `question` ("Delete order?"): the title of the dialog and
its accessible name. `toMsg` wraps the messages of the dialog. Renders nothing
while closed, so it can stay in your view all the time. It returns an
[`Overlay`](Klar.Overlay.md#overlay) for [`Overlay.host`](Klar.Overlay.md#host) or
`AppShell.overlays`.

## State

### `State`

```elm
type State  -- opaque: no constructors are exposed
```

The state of one confirmation dialog: whether it is open, the phase of the
request it guards (idle, busy or failed) and the text typed so far. Create it
with `init`, keep it in your model, and change it with `open`, `setBusy`,
`setFailed`, `close` and `update`.

### `Msg`

```elm
type Msg  -- opaque: no constructors are exposed
```

The messages of the dialog (typing, the built-in cancel, focus movements).
Wrap it in a constructor of your own message type, such as
`DialogMsg ConfirmDialog.Msg`, and hand it to `update`.

### `init`

```elm
init : String -> State
```

A closed dialog. The id must be unique on the page: it is the DOM id of the
dialog, and the ids of the parts inside it start with it.

### `update`

```elm
update : Msg -> State -> ( State, Cmd Msg )
```

Handles the typed confirmation, the focus movements and the built-in cancel.
When the dialog closes itself (the close button, `Escape` or the backdrop, with
no `onCancel`), it forgets the typed text and the failure just as `close` does.
Map its command into your own message with `Cmd.map`.

### `isOpen`

```elm
isOpen : State -> Bool
```

Is the dialog open? The page behind it is made inert by the
[`Overlay`](Klar.Overlay.md#overlay) the dialog returns, so you rarely need this.

### `isBusy`

```elm
isBusy : State -> Bool
```

`True` while the request runs: from `setBusy` until `setFailed`, `close` or
`open`. Check it in your `onCancel` handler before you close the dialog.

### `problem`

```elm
problem : State -> Maybe Remote.Problem
```

The [`Problem`](Klar.Remote.md#problem) that was given to `setFailed`, while the
dialog is open and shows it; `Nothing` otherwise, and always once the dialog is
closed.

## Opening, confirming and closing

### `open`

```elm
open : String -> State -> ( State, Cmd Msg )
```

Opens the dialog in its idle state, clearing any earlier failure and typed
text. `opener` is the DOM id of the element that gets focus back when the dialog
closes, usually the button that asked the question (with `""`, the element that
had focus when the dialog opened, if it has an id). Focus starts on the
typed-confirmation field if there is one, otherwise on the cancel button.

### `setBusy`

```elm
setBusy : State -> State
```

Call this when the user confirmed and the request starts. The confirm button
shows a spinner, the typed-confirmation field becomes read-only, and nothing can
close the dialog until you call `close` or `setFailed`.

### `setFailed`

```elm
setFailed : Remote.Problem -> State -> State
```

Call this when the request failed. The dialog shows the problem (its title,
detail and code) and, if the problem is retryable and you gave an `onConfirm`, a
"Try again" button that sends your message again. The dialog can be dismissed
again.

It is for the answer of the server, not for checking the user's input: a missing
choice or a field that is not valid is a reason to keep the confirm button
disabled (see `confirmDisabled`), shown beside the field it concerns. If a problem
that was shown has been dealt with while the dialog stays open, take it away with
`clearFailure`.

### `clearFailure`

```elm
clearFailure : State -> State
```

Takes the failure away without closing the dialog, for a problem that does not
apply any more (the user chose another option, say). Nothing happens unless the
dialog shows a failure; a request that is running (`setBusy`) is not touched.

### `close`

```elm
close : State -> ( State, Cmd Msg )
```

Closes the dialog, forgets any typed text and failure, and gives focus back
to its opener. Call it when the request succeeded, and from your `onCancel`
handler.

## Content

### `Attribute`

```elm
type Attribute msg  -- opaque: no constructors are exposed
```

A setting of the dialog. Make them with the functions below and pass a list
to `view`; later attributes win over earlier ones.

### `message`

```elm
message : String -> Attribute msg
```

A short explanation in plain text, below the question: "Order 1042 will be
removed from all lists." Screen readers read it out after the title.

### `body`

```elm
body : List (Html msg) -> Attribute msg
```

Rich content below the message: a name in bold, a link, a small table.

### `consequences`

```elm
consequences : List String -> Attribute msg
```

What will happen, one short line each, shown as a bulleted list below the
message: "3 open shipments are canceled".

## Tone

### `tone`

```elm
tone : Theme.Tone -> Attribute msg
```

The tone of the question (a [`Tone`](Klar.Theme.md#tone)): `Neutral`, the default,
is a question with no risk (a blue help icon and a blue confirm button); `Warning`
an action that is hard to undo or that affects others (a warning icon, the confirm
button stays blue); `Danger` a destructive action (a red error icon and a red
confirm button). `Info` and `Success` look like `Neutral`.

    ConfirmDialog.tone Danger

### `icon`

```elm
icon : Icon.Icon -> Attribute msg
```

Replaces the icon of the tone with another one, for example
`ConfirmDialog.icon Icon.trash`.

## Buttons and typed confirmation

### `confirmLabel`

```elm
confirmLabel : String -> Attribute msg
```

Text of the confirm button. The default is "Confirm" (it follows `locale`).
Name the action instead: "Delete order".

### `cancelLabel`

```elm
cancelLabel : String -> Attribute msg
```

Text of the cancel button. The default is "Cancel" (it follows `locale`).

### `confirmDisabled`

```elm
confirmDisabled : Bool -> Attribute msg
```

Disables the confirm button (and `Enter` in the typed-confirmation field) while
`True`: pass a field of your model that is `False` until the user has made the
choice the question needs. The dialog stays calm about it: no message is shown,
so say what is missing beside the control (a `Select.errorMaybe`, say). If the
confirm button has focus when it becomes disabled, focus moves to the dialog.

### `typeToConfirm`

```elm
typeToConfirm : String -> Attribute msg
```

The user must type this text before the confirm button is enabled, for
actions that cannot be undone: a word that makes them stop and read, such as
`"DELETE"` or the name of the thing they delete. The field is labeled "Type
DELETE to confirm" (it follows `locale`), and `Enter` in it confirms once the
text matches. Matching is exact, apart from spaces at either end of what the
user typed, unless you add `ignoreCase`.

### `ignoreCase`

```elm
ignoreCase : Attribute msg
```

For `typeToConfirm`: "delete" matches "DELETE".

## Messages

### `onConfirm`

```elm
onConfirm : msg -> Attribute msg
```

The message sent when the user confirms: with the confirm button, with
`Enter` in the typed-confirmation field, or with the "Try again" button after a
failure. Nothing is sent until the typed text matches. Your `update` then calls
`setBusy` and starts the request.

### `onCancel`

```elm
onCancel : msg -> Attribute msg
```

The message sent when the user cancels in any way: with the cancel button,
the close button, `Escape` or the backdrop. Your `update` then calls `close` and
clears what was being confirmed. Give it whenever your model keeps that (a pending
order, an id): without `onCancel` the dialog closes itself, and your model would
keep the stale value. It is not sent while the request runs.

## Texts

### `locale`

```elm
locale : Locale.Locale -> Attribute msg
```

The language of the built-in text: the buttons ("Confirm" and "Cancel"), the
"Try again" button, the label of the typed-confirmation field and the label of
the close button. The default is [`Locale.default`](Klar.Locale.md#default), which
is English.
