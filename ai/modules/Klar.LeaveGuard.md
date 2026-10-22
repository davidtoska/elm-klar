# Klar.LeaveGuard

Asks "Leave without saving?" when the user navigates away inside the application while something is not saved.

Import: `import Klar.LeaveGuard as LeaveGuard` | Group: Pages and flow

Types: `Msg`, `Guard`, `Answer`, `Decision`, `Attribute`

## Signatures

```elm
-- The guard
type Guard source target  -- opaque: no constructors are exposed
init : String -> Guard source target
setDirty : source -> Bool -> Guard source target -> Guard source target
isDirty : Guard source target -> Bool
dirtySources : Guard source target -> List source

-- Asking
type Answer source target = Proceed target | Hold (Guard source target) (Cmd Msg)
request : target -> Guard source target -> Answer source target
dismiss : Guard source target -> ( Guard source target, Cmd Msg )

-- The dialog
type Msg  -- opaque: no constructors are exposed
type Decision target  -- opaque: no constructors are exposed
update : Msg -> Guard source target -> ( Guard source target, Cmd Msg, Maybe (Decision target) )
destination : Decision target -> target
savesFirst : Decision target -> Bool
view : (Msg -> msg) -> List Attribute -> Guard source target -> Overlay.Overlay msg
isOpen : Guard source target -> Bool
pending : Guard source target -> Maybe target

-- Attributes
type Attribute  -- opaque: no constructors are exposed
title : String -> Attribute
message : String -> Attribute
saveAndLeave : Attribute
locale : Locale.Locale -> Attribute
```

## Documentation

Asks "Leave without saving?" when the user navigates away inside the
application while something is not saved.

    import Klar.LeaveGuard as LeaveGuard exposing (Answer(..))

    -- model:   guard : LeaveGuard.Guard FormId Route      (LeaveGuard.init "leave-dialog")

    -- every navigation goes through the guard
    LinkClicked (Browser.Internal url) ->
        case LeaveGuard.request (Route.fromUrl url) model.guard of
            Proceed route ->
                goTo route model

            Hold guard cmd ->
                ( { model | guard = guard }, Cmd.map GuardMsg cmd )

    -- the forms tell the guard whether they are dirty
    OrderEdited draft ->
        ( { model
            | draft = draft
            , guard = LeaveGuard.setDirty OrderForm (draft /= model.saved) model.guard
          }
        , Cmd.none
        )

    -- the user answers the question
    GuardMsg m ->
        let
            ( guard, cmd, decision ) =
                LeaveGuard.update m model.guard

            next =
                ( { model | guard = guard }, Cmd.map GuardMsg cmd )
        in
        case decision of
            Nothing ->
                next

            Just answer ->
                if LeaveGuard.savesFirst answer then
                    -- "Save and leave": save, and go when it succeeded
                    saveThenGo (LeaveGuard.destination answer) next

                else
                    -- "Leave": the changes are given up, goTo is yours (Nav.pushUrl ...)
                    goTo (LeaveGuard.destination answer) { model | guard = guard }

    -- view: render the dialog once, with the page, and let it make the page inert
    LeaveGuard.view GuardMsg [] model.guard

`request` is the only way to ask. A guard with nothing dirty answers `Proceed`
with your own value, a `Route` or a `Url`, and you go there. A guard with something
dirty answers `Hold`: it keeps your value as plain data, opens a dialog ("Leave
without saving?" with "Leave" and "Stay") and gives you the new guard to keep, so
there is no way to hold a request and forget to open the dialog. The dialog is a
[Klar.Modal](Klar.Modal.md): focus goes to "Stay", the safe choice, `Escape`, the
backdrop and the close button mean "Stay", and focus goes back to the link or button
that asked (give it an id with `Button.id`; without one focus falls to the page).
`Leave` and `Stay` are messages of the dialog; `update` resolves them. On "Leave"
you get the held value back in a `Decision` and the guard forgets everything that was
dirty, since the user gave those changes up; on "Stay" nothing is left for you to
do. `update` returns the decision next to the new guard, and not as something to read
from the guard afterwards, because a decision is an event that happens once: kept in
the guard it would be stale at the next message, and a handler that reads it twice
would navigate twice. While the dialog is open the page behind it must be inert: pass
`isOpen` to `Modal.host` as `blocked`, or to `AppShell.modalOpen`.

**Several forms.** Each form that can hold unsaved changes is a source of your own
type (a union of the forms, a record id) and reports with `setDirty`. The guard is
clean only when every source is clean. Sources are compared with `==`, so they must
not contain functions. Requests are only held and handed back, never compared; they
too should be plain data (a `Route`, not a function), as anything in a model should.

**A new request while the question is open** replaces the held one: the latest thing
the user asked for is what "Leave" does. A request is never held when everything is
clean and no question is open.

**Save and leave.** With the attribute `saveAndLeave` the dialog has a third button.
It closes the dialog, keeps the dirty marks and gives you a decision for which
`savesFirst` is `True`: save, carry the route in the message that comes back from the
save (`SavedThenGo route`), and go there when it succeeded. If the save fails the user
is still on the page, with the form's own error. Leaving the dirty marks in place
means a second click on a link, while the save is on its way, asks again. If that
question is still open when the save comes back and you go to the saved route, call
`dismiss`, or "Leave" would take the user to the other link afterwards.

**What this cannot do.** The guard sees navigation inside the application. Closing the
tab, reloading and typing another address happen outside the page: only the
`beforeunload` event of JavaScript can ask about those, and Klar has no JavaScript. If
your application may have a port, this is all of it:

    port unsavedChanges : Bool -> Cmd msg

    // JavaScript, once
    app.ports.unsavedChanges.subscribe(function (dirty) {
      window.onbeforeunload = dirty ? function (event) { event.preventDefault(); } : null;
    });

and call it with `LeaveGuard.isDirty guard` whenever that changes.

**The browser's own buttons.** A click on a link reaches `onUrlRequest` before the
address changes, so a `request` there can stop it: when the answer is `Hold`, do not
push the address. The Back and Forward buttons cannot be stopped. `onUrlChange` is
called after the address has changed, and a program in Elm cannot read the position
in the history, so it cannot even tell which of the two was pressed. All it can do is
the opposite move, `Nav.forward 1` after a Back (`Nav.back 1` after a Forward), which
puts the address back without adding an entry to the history, and then `request` the
page the user wanted. That move calls `onUrlChange` once more: ignore the call whose
address is the page you are showing. If the user chooses "Leave", make the real move
(`Nav.back 1` again). Do not put the address back with `Nav.pushUrl`: it adds an
entry, so that Back, Leave, Back ends on the page the user has just left. Let your
target type say where the request came from (`Go Route` for a link, `GoBack` for the
Back button), so that `Leave` knows which move to make.

## The guard

### `Guard`

```elm
type Guard source target  -- opaque: no constructors are exposed
```

What the application knows about unsaved work: which sources are dirty, the
request that waits for an answer, and the dialog that asks. `source` is your own
type for the places that can hold unsaved changes and `target` is your own type for
where the user wants to go. Sources are compared with `==`, so they must not
contain functions. Make one with `init` and keep it in your model.

### `init`

```elm
init : String -> Guard source target
```

A guard with nothing dirty and no question open. The `String` is the DOM id of
the dialog and must be unique on the page; the ids of its parts start with it.

    LeaveGuard.init "leave-dialog"

### `setDirty`

```elm
setDirty : source -> Bool -> Guard source target -> Guard source target
```

Says whether a source holds unsaved changes. Call it whenever that can change,
with the comparison itself:

    LeaveGuard.setDirty OrderForm (model.draft /= model.saved) model.guard

Saying the same thing twice is harmless, and a source that was never mentioned is
clean. The guard keeps a handful of sources in a list: it is meant for forms, not
for thousands of rows.

### `isDirty`

```elm
isDirty : Guard source target -> Bool
```

Is anything dirty? `False` only when every source is clean. Use it for a
`beforeunload` port (see above) or an "unsaved changes" mark.

### `dirtySources`

```elm
dirtySources : Guard source target -> List source
```

The sources that are dirty, in the order they became dirty.

## Asking

### `Answer`

```elm
type Answer source target = Proceed target | Hold (Guard source target) (Cmd Msg)
```

The answer to a request: go there, or wait for the user.

  - `Proceed target` is the value you asked with. Nothing is dirty, no dialog is
    open, and the guard is unchanged: navigate.
  - `Hold guard cmd` means the value is kept and the dialog is open. Store the new
    guard and run the command (map it with `Cmd.map`): it moves focus to "Stay".

This is a union with exactly these two cases, because the application has to do
something different in each: there is nothing else a guard can say.

### `request`

```elm
request : target -> Guard source target -> Answer source target
```

Asks whether the user may go to `target` now. Every navigation of the
application goes through here, the clicks on links and the changes of the
address.

    LeaveGuard.request (Route.fromUrl url) model.guard

When a question is already open, the new `target` replaces the old one and the
dialog stays open (see the top of this page).

### `dismiss`

```elm
dismiss : Guard source target -> ( Guard source target, Cmd Msg )
```

Withdraws the question that is open: the held value is forgotten and the dialog
closes. The dirty marks stay as they are. If no question is open, nothing happens.
The result is the new guard and a command to map into your own message, as for
`request`.

Call it when the question has become stale, which is when the application went
somewhere by itself while the user had not yet answered: the save of "Save and
leave" came back and you went to the saved route while a click on another link had
opened a new question, or the session ended, or a redirect took the user away. The
question is about a place the user is no longer heading for, and "Leave" would send
them there.

    SavedThenGo route ->
        let
            ( guard, cmd ) =
                LeaveGuard.dismiss (LeaveGuard.setDirty OrderForm False model.guard)
        in
        goTo route { model | guard = guard }
            |> addCmd (Cmd.map GuardMsg cmd)

## The dialog

### `Msg`

```elm
type Msg  -- opaque: no constructors are exposed
```

The messages of the dialog: the three buttons and the focus movements. Wrap
it in a constructor of your own message type, such as `GuardMsg LeaveGuard.Msg`,
and hand it to `update`.

### `Decision`

```elm
type Decision target  -- opaque: no constructors are exposed
```

What the user decided in the dialog, when the decision has something for you
to do: to go on to the held value, perhaps after saving. Read it with `destination` and
`savesFirst`. The type is opaque, so that new kinds of decisions can be added later
without breaking anyone.

"Stay" is not a decision, there is nothing to do.

### `update`

```elm
update : Msg -> Guard source target -> ( Guard source target, Cmd Msg, Maybe (Decision target) )
```

Applies a message of the dialog. The result is the new guard, a command to
map into your own message with `Cmd.map`, and the decision when this message
settled the question. A button that is pressed twice, or after the question was
answered, settles nothing the second time.

### `destination`

```elm
destination : Decision target -> target
```

The value that was held: where the user wants to go.

### `savesFirst`

```elm
savesFirst : Decision target -> Bool
```

Must the application save before it goes to the `destination`? `True` for "Save and
leave", which is only offered with the attribute `saveAndLeave`; the dirty marks are
still there then, and you clear them when the save has succeeded. `False` for
"Leave": the user gave the changes up and the guard is clean.

### `view`

```elm
view : (Msg -> msg) -> List Attribute -> Guard source target -> Overlay.Overlay msg
```

The dialog. Renders nothing while no question is open, so it can stay in your
view all the time; put it in the `overlays` of
[`Modal.host`](Klar.Modal.md#host) or the `overlays` of `AppShell`.

    LeaveGuard.view GuardMsg [ LeaveGuard.saveAndLeave ] model.guard

### `isOpen`

```elm
isOpen : Guard source target -> Bool
```

Is the question open? Pass it to `Modal.host` as `blocked`, or to
`AppShell.modalOpen`, so that the page behind the dialog is inert.

### `pending`

```elm
pending : Guard source target -> Maybe target
```

The value that waits for the answer, while the question is open.

## Attributes

### `Attribute`

```elm
type Attribute  -- opaque: no constructors are exposed
```

A setting of the dialog. Make them with the functions below and pass a list
to `view`; later attributes win over earlier ones. They carry no messages, so the
type has no `msg` parameter.

### `title`

```elm
title : String -> Attribute
```

The question, replacing "Leave without saving?". It is the accessible name of
the dialog.

### `message`

```elm
message : String -> Attribute
```

The sentence under the question, replacing "You have unsaved changes. If you
leave now, they are lost." Name what is lost: "Order 1042 and its lines are not
saved."

### `saveAndLeave`

```elm
saveAndLeave : Attribute
```

Adds a third button, "Save and leave", for the application that can save from
here. Pressing it closes the dialog and `update` gives you `SaveFirst`. It is the
primary button of the dialog; focus still starts on "Stay".

### `locale`

```elm
locale : Locale.Locale -> Attribute
```

The language of the built-in text: the question, the sentence and the
buttons. The default is [`Locale.default`](Klar.Locale.md#default), which is English.
