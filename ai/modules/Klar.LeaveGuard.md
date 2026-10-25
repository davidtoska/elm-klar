# Klar.LeaveGuard

Asks "Leave without saving?" when the user leaves a page with unsaved work: by a link, by your own code and by the browser's Back and Forward buttons.

Import: `import Klar.LeaveGuard as LeaveGuard` | Group: Pages and flow

Types: `Msg`, `Guard`, `Answer`, `Change`, `Decision`, `Attribute`

## Signatures

```elm
-- The guard
type Guard source target  -- opaque: no constructors are exposed
init : String -> Guard source target
initAt : String -> Browser.Navigation.Key -> (Url.Url -> target) -> Url.Url -> Guard source target
setDirty : source -> Bool -> Guard source target -> Guard source target
isDirty : Guard source target -> Bool
dirtySources : Guard source target -> List source

-- Asking
type Answer source target = Proceed target | Hold (Guard source target) (Cmd Msg)
type Change target = Enter target | SamePage Url.Url | Unchanged
request : target -> Guard source target -> Answer source target
onUrlChange :
    (Url.Url -> target)
    -> Url.Url
    -> Guard source target
    -> ( Guard source target, Cmd Msg, Change target )
dismiss : Guard source target -> ( Guard source target, Cmd Msg )

-- The dialog
type Msg  -- opaque: no constructors are exposed
type Decision target  -- opaque: no constructors are exposed
update : Msg -> Guard source target -> ( Guard source target, Cmd Msg, Maybe (Decision target) )
destination : Decision target -> target
savesFirst : Decision target -> Bool
follow : (target -> String) -> Decision target -> Guard source target -> Cmd msg
view : (Msg -> msg) -> List (Attribute msg) -> Guard source target -> Overlay.Overlay msg
isOpen : Guard source target -> Bool
pending : Guard source target -> Maybe target

-- Attributes
type Attribute msg  -- opaque: no constructors are exposed
title : String -> Attribute msg
message : String -> Attribute msg
saveAndLeave : Attribute msg
locale : Locale.Locale -> Attribute msg
```

## Documentation

Asks "Leave without saving?" when the user leaves a page with unsaved work: by a
link, by your own code and by the browser's Back and Forward buttons.

Use when: a page holds unsaved work and every way of leaving it, including Back and Forward, must ask first.
Do not use when: only the unsaved state itself is needed without a dialog, read it with `isDirty` or compare values in your own model.
Quick path: `initAt`, `setDirty`, `request`, `onUrlChange`, `update` with `follow`, `view`

**The quick path.** Six functions, in this order:

  - `initAt` in `init`, with the `Key`, what an address means to you and the `Url`;
  - `setDirty` in the branch of each message that edits a form, with the comparison itself
    (`draft /= saved`); not in a wrapper that runs after every message (see "After Leave" below);
  - `request` for every link and every navigation of your own: `Proceed` and you
    push the address, `Hold` and the dialog is open;
  - `onUrlChange` in your `onUrlChange`: it answers the Back and Forward buttons, and it
    tells you which page to show (`Enter`), that the page you show has a new address
    (`SamePage`), or that there is nothing to do (`Unchanged`);
  - `update` for the buttons of the dialog: on "Leave" you get a decision, reset the work
    the user gave up, and go there with `follow` (on "Save and leave", `savesFirst`,
    save first);
  - `view` once, in the overlays.

The whole application, as it compiles:

    import Browser
    import Browser.Navigation as Nav
    import Html exposing (Html)
    import Html.Attributes as Attr
    import Html.Events as Events
    import Klar
    import Klar.LeaveGuard as LeaveGuard exposing (Answer(..), Change(..))
    import Klar.Overlay as Overlay
    import Url exposing (Url)

    type Route
        = Orders
        | NewOrder

    type Source
        = OrderForm

    type alias Model =
        { key : Nav.Key
        , route : Route
        , draft : String
        , guard : LeaveGuard.Guard Source Route
        }

    type Msg
        = LinkClicked Browser.UrlRequest
        | UrlChanged Url
        | Typed String
        | GuardMsg LeaveGuard.Msg
        | NoOp

    main : Program () Model Msg
    main =
        Browser.application
            { init = init
            , view = view
            , update = update
            , subscriptions = \_ -> Sub.none
            , onUrlRequest = LinkClicked
            , onUrlChange = UrlChanged
            }

    init : () -> Url -> Nav.Key -> ( Model, Cmd Msg )
    init _ url key =
        ( { key = key
          , route = fromUrl url
          , draft = ""
          , guard = LeaveGuard.initAt "leave-dialog" key fromUrl url
          }
        , Cmd.none
        )

    fromUrl : Url -> Route
    fromUrl url =
        if url.fragment == Just "/orders/new" then
            NewOrder

        else
            Orders

    toPath : Route -> String
    toPath route =
        case route of
            Orders ->
                "#/orders"

            NewOrder ->
                "#/orders/new"

    update : Msg -> Model -> ( Model, Cmd Msg )
    update msg model =
        case msg of
            LinkClicked (Browser.Internal url) ->
                case LeaveGuard.request (fromUrl url) model.guard of
                    Proceed route ->
                        ( model, Nav.pushUrl model.key (toPath route) )

                    Hold guard cmd ->
                        ( { model | guard = guard }, Cmd.map GuardMsg cmd )

            LinkClicked (Browser.External href) ->
                ( model, Nav.load href )

            UrlChanged url ->
                case LeaveGuard.onUrlChange fromUrl url model.guard of
                    ( guard, cmd, Enter route ) ->
                        ( { model | guard = guard, route = route }
                        , Cmd.batch
                            [ Cmd.map GuardMsg cmd
                            , Klar.focus "content" NoOp
                            ]
                        )

                    ( guard, cmd, SamePage _ ) ->
                        -- the page that is shown, at another address: a page with a sort
                        -- or a tab in the query reads it from the address here
                        ( { model | guard = guard }, Cmd.map GuardMsg cmd )

                    ( guard, cmd, Unchanged ) ->
                        ( { model | guard = guard }, Cmd.map GuardMsg cmd )

            Typed text ->
                ( { model
                    | draft = text
                    , guard = LeaveGuard.setDirty OrderForm (text /= "") model.guard
                  }
                , Cmd.none
                )

            GuardMsg inner ->
                let
                    ( guard, cmd, decision ) =
                        LeaveGuard.update inner model.guard
                in
                case decision of
                    Just answer ->
                        -- "Leave", whichever way the user left: the draft is given up here.
                        -- (With saveAndLeave, check LeaveGuard.savesFirst first: see follow.)
                        ( { model | guard = guard, draft = "" }
                        , Cmd.batch [ Cmd.map GuardMsg cmd, LeaveGuard.follow toPath answer guard ]
                        )

                    Nothing ->
                        ( { model | guard = guard }, Cmd.map GuardMsg cmd )

            NoOp ->
                ( model, Cmd.none )

    view : Model -> Browser.Document Msg
    view model =
        { title = "Orders"
        , body =
            [ Klar.stylesheet
            , Overlay.host
                { attributes = []
                , page = [ page model ]
                , overlays = [ LeaveGuard.view GuardMsg [] model.guard ]
                }
            ]
        }

    page : Model -> Html Msg
    page model =
        Html.div []
            [ Html.a [ Attr.id "to-orders", Attr.href "#/orders" ] [ Html.text "Orders" ]
            , Html.main_ [ Attr.id "content", Attr.tabindex -1 ]
                [ Html.input [ Attr.value model.draft, Events.onInput Typed ] [] ]
            ]

**What the dialog does.** A guard with nothing dirty answers `request` with `Proceed`
and your own value, a `Route` or a `Url`, and you go there. A guard with something
dirty answers `Hold`: it keeps your value as plain data, opens a dialog ("Leave
without saving?" with "Leave" and "Stay") and gives you the new guard to keep, so
there is no way to hold a request and forget to open the dialog. The dialog is a
[Klar.Modal](Klar.Modal.md): focus goes to "Stay", the safe choice, and `Escape`, the
backdrop and the close button mean "Stay". `Leave` and `Stay` are messages of the
dialog; `update` resolves them. On "Leave" you get the held value back in a `Decision`
and the guard forgets everything that was dirty, since the user gave those changes up:
reset what was given up in that branch, and go with `follow` (with `saveAndLeave`
the same branch gets "Save and leave" too: check `savesFirst` before you reset
anything, see `follow`). Every "Leave" gives a
decision, whether the question came from a link or from the Back button, so that branch
is the one place for it. On "Stay" nothing is left for you to do. `update` returns the decision next to the new
guard, and not as something to read from the guard afterwards, because a decision is
an event that happens once: kept in the guard it would be stale at the next message,
and a handler that reads it twice would navigate twice. While the dialog is open the
page behind it must be inert: the `Overlay.host` does that.

**The browser's own buttons.** Back and Forward cannot be stopped: `onUrlChange` is
called after the address has changed, and a program in Elm can neither read the
position in the history nor tell the two buttons apart. The guard therefore does not
try to undo the move. With something dirty it leaves the page as it is, opens the
question, and the address bar is already at the page the user wanted. "Leave" shows
that page (the guard replaces the address with itself, which adds no entry to the
history, and `onUrlChange` then answers `Enter`; `follow` knows that and pushes
nothing); "Stay" pushes the address of the page that is shown. One consequence is worth knowing: after "Stay" the entries
that were ahead of the page are gone, and when the user pressed Forward there is one
entry more than before. Never undo a Back with `Nav.forward 1` yourself: the browser
reports the address it leaves and then the one it reaches, so a handler that asks again
loops forever. You do not need `pushing` or
`restoring` fields, and a target type like `Go Route | GoBack`: all of it is
`onUrlChange`. A `Nav.pushUrl` of your own that did not ask first is caught the same
way, so asking is a courtesy that keeps the history tidy, not a duty the guard
depends on.

**Focus.** The dialog gives focus back to the element that had it when the question
was asked, if that element has an `id` (a `Button` with `Button.id`, a `SideNav` link,
a form field, your own `Html.a` with `Attr.id`). The page remembers the last few
elements that had focus while the dialog was closed; an element without an id is not
among them, and focus then goes to the last one that was, which may be somewhere else.
Give the links that can ask an id. After "Leave" the new page is yours: the dialog
puts focus back on the link, and the page you enter moves it on to its content
(`AppShell.focusContent`, or `FormLayout.focusField` for a field), which is what every navigation of the
application should do anyway. The example does it in `UrlChanged`.

**Several forms.** Each form that can hold unsaved changes is a source of your own
type (a union of the forms, a record id) and reports with `setDirty`. The guard is
clean only when every source is clean. Sources are compared with `==`, so they must
not contain functions. Targets are held, handed back and compared with `==` (with the page that is
shown); they too must be plain data (a `Route`, not a function), as anything in a model
should.
A page that is made of many parts (twenty contact rows, tags, files) is one source:
combine their flags in one function of yours and call `setDirty` once after each
update. [`FormLayout.unsavedChanges`](Klar.Form.Layout.md#unsavedchanges) and
[`FormLayout.unsavedFlag`](Klar.Form.Layout.md#unsavedflag) show the same fact to the user, in the
form; this guard acts on it. Which forms "Leave" gave up is `dirtySources` of the guard
you had before `update`, so reset exactly those:

    GuardMsg inner ->
        let
            givenUp =
                LeaveGuard.dirtySources model.guard

            ( guard, cmd, decision ) =
                LeaveGuard.update inner model.guard
        in
        ...

**After "Leave".** `setDirty` states what is true now; it does not say "something changed".
"Leave" gives the changes up, so the guard forgets every dirty mark, but your model still
holds whatever the user had typed. If the next message says `setDirty source True` again,
because a wrapper around `update` recomputes the flag after every message, the guard is
armed a second time for input the user just gave up: after Back and "Leave" the next
`onUrlChange` asks again and "Leave" seems to do nothing. Two rules keep it right: call
`setDirty` only in the branches of the messages that edit a form (and after a save has
succeeded, with `False`), and reset the form you left (`Form.init`, or the draft back to
the saved value) in the branch that gets the decision of "Leave". The guard cannot tell
a value that is unchanged from one that is new: both are "dirty".

**The same page at another address.** A page often keeps its sort, its filter or its tab
in the query. Such a change is no departure when the target of the new address is the
target of the page that is shown: `onUrlChange` asks nothing and answers `SamePage url`,
dirty or not. Apply the address to the page you show (read its sort or its tab from
`url`) and keep its work, as the address bar now says. A `request` for the page that
is shown is answered with `Proceed`: push the link's own `Url` then
(`Nav.pushUrl model.key (Url.toString url)`), since a target that leaves the query out
cannot write it back. So the target decides what a page is: leave out of it what does
not make another page. Targets are compared with `==`, so they are plain data.
`initAt` reads the target of the address the application starts on, so `request`
and `onUrlChange` agree from the first click.

**A new request while the question is open** replaces the held one: the latest thing
the user asked for is what "Leave" does. A request is never held when everything is
clean and no question is open.

**Save and leave.** With the attribute `saveAndLeave` the dialog has a third button.
It closes the dialog, keeps the dirty marks and gives you a decision for which
`savesFirst` is `True`: save, carry the route in the message that comes back from the
save (`SavedThenGo route`), and go there when it succeeded. If the save fails the user
is still on the page, with the form's own error; when the question came from the Back
button the address is put right at once, so that the page and the address bar agree
while the save is on its way. Leaving the dirty marks in place means a second click on
a link, while the save is on its way, asks again. If that question is still open when
the save comes back and you go to the saved route, call `dismiss`, or "Leave" would
take the user to the other link afterwards.

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

**Not an application with addresses.** A wizard or a drawer inside one page has no
`Url`. Make the guard with `init` and use `request`, `update` and `view` as above;
`onUrlChange` then enters every change, since there is nothing to compare with.

**Links.** A click on a link reaches `onUrlRequest` before the address changes, so a
`request` there can stop it: when the answer is `Hold`, do not push the address (and
`Browser.External` links go to `Nav.load` without asking). A `Nav.pushUrl` of your
own is asked about the same way.

**With an `AppShell`.** Both want the address, and the rule is: the guard answers the
clicks, the shell reports the address. `onUrlRequest` is a message of your own (it asks
the guard before it pushes), `onUrlChange` is the shell's, and the `Url` that
`AppShell.update` reports goes to `LeaveGuard.onUrlChange` (the shell has then closed
its drawer and reset the scroll, which does no harm when the page stays):

    Browser.application
        { onUrlRequest = LinkClicked
        , onUrlChange = AppShell.onUrlChange ShellMsg
        , ...
        }

    LinkClicked (Browser.Internal url) ->
        case LeaveGuard.request (pageFromUrl url) model.guard of
            Proceed page ->
                ( model, Nav.pushUrl model.key (pagePath page) )

            Hold guard cmd ->
                ( { model | guard = guard }, Cmd.map GuardMsg cmd )

    ShellMsg m ->
        let
            ( shell, cmd, address ) =
                AppShell.update m model.shell
        in
        case Maybe.map (\url -> LeaveGuard.onUrlChange pageFromUrl url model.guard) address of
            Just ( guard, guardCmd, Enter page ) ->
                enter page { model | shell = shell, guard = guard }
                    |> addCmd (Cmd.batch [ Cmd.map ShellMsg cmd, Cmd.map GuardMsg guardCmd ])

            Just ( guard, guardCmd, SamePage url ) ->
                ( applyQuery url { model | shell = shell, guard = guard }
                , Cmd.batch [ Cmd.map ShellMsg cmd, Cmd.map GuardMsg guardCmd ]
                )

            Just ( guard, guardCmd, Unchanged ) ->
                ( { model | shell = shell, guard = guard }
                , Cmd.batch [ Cmd.map ShellMsg cmd, Cmd.map GuardMsg guardCmd ]
                )

            Nothing ->
                ( { model | shell = shell }, Cmd.map ShellMsg cmd )

Tried in Chrome with unsaved input: the Back button opens the question with the address
at the page the user wanted, "Stay" puts the address back, "Leave" shows the page and
focus goes to the content. With the shell, as here, `enter` calls `AppShell.setPage` and
`AppShell.goToContent`; an application without a shell uses its own `UrlChanged`, as in the
example at the top.

## The guard

### `Guard`

```elm
type Guard source target  -- opaque: no constructors are exposed
```

What the application knows about unsaved work: which sources are dirty, the
request that waits for an answer, the address of the page, and the dialog that
asks. `source` is your own type for the places that can hold unsaved changes and
`target` is your own type for where the user wants to go. Sources are compared with
`==`, so they must not contain functions. Make one with `initAt` (or `init`) and keep
it in your model.

### `init`

```elm
init : String -> Guard source target
```

A guard with nothing dirty and no question open, for the navigation you
do yourself (a wizard, a drawer, a route in your own model). It does not know the
address bar, so `onUrlChange` has nothing to compare with: use `initAt` for an
application that has URLs. The `String` is the DOM id of the dialog and must be
unique on the page; the ids of its parts start with it.

    LeaveGuard.init "leave-dialog"

### `initAt`

```elm
initAt : String -> Browser.Navigation.Key -> (Url.Url -> target) -> Url.Url -> Guard source target
```

The same, for an application with URLs: give it the `Key` and the `Url` that
`Browser.application` gives your `init`, and what an address means to you (the same
function you give to `onUrlChange`). The guard keeps the address of the page that is
shown and its target, so a link to the page you started on is no departure from the
first click on, and it uses the key to put the address right after "Stay".

    init _ url key =
        ( { key = key
          , route = Route.fromUrl url
          , guard = LeaveGuard.initAt "leave-dialog" key Route.fromUrl url
          }
        , Cmd.none
        )

### `setDirty`

```elm
setDirty : source -> Bool -> Guard source target -> Guard source target
```

Says whether a source holds unsaved changes. Call it whenever that can change,
with the comparison itself:

    LeaveGuard.setDirty OrderForm (model.draft /= model.saved) model.guard

Saying the same thing twice is harmless, and a source that was never mentioned is
clean. The guard keeps a handful of sources in a list: it is meant for forms, not
for thousands of rows. A page with many parts (twenty rows of contacts, tags, files)
is one source: compare its model with the saved one, or combine the flags of the parts
in one function of yours, and call `setDirty` once.

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

### `Change`

```elm
type Change target = Enter target | SamePage Url.Url | Unchanged
```

What the page does with a new address, the answer of `onUrlChange`.

  - `Enter target`: show this page. It is another page and nothing is dirty, or the
    user has just left it ("Leave" after Back), or the guard was made with `init`.
  - `SamePage url`: the page you show, at another address. The target is the same
    (`==`) and only what the target leaves out has changed: a sort, a filter or a tab
    in the query. Apply `url` to the page you show and keep its work. This is no
    departure, dirty or not, so nothing was asked.
  - `Unchanged`: nothing to do, the guard has dealt with it. Your own `Nav.pushUrl`
    came back to the address the page shows, the guard put the address right after
    "Stay", or something is dirty and the user pressed Back or Forward: the page stays
    as it is, the question is open, and the address bar is already at the place the
    user wanted ("Leave" shows that page, "Stay" pushes the address of the page that is
    shown).

A union with exactly these three cases, because the page does something different in
each.

### `request`

```elm
request : target -> Guard source target -> Answer source target
```

Asks whether the user may go to `target` now. Every navigation of the
application goes through here, the clicks on links and the changes of the
address.

    LeaveGuard.request (Route.fromUrl url) model.guard

When a question is already open, the new `target` replaces the old one and the
dialog stays open (see the top of this page). A `target` equal (`==`) to the page that
is shown is answered with `Proceed`, even with something dirty: the user stays on the
page.

### `onUrlChange`

```elm
onUrlChange :
    (Url.Url -> target)
    -> Url.Url
    -> Guard source target
    -> ( Guard source target, Cmd Msg, Change target )
```

Call this from your `onUrlChange`, for every change of the address. It is
the whole answer to the browser's Back and Forward buttons, to a `Nav.pushUrl` that
did not ask first, and it takes the place of the code that enters the page.

    UrlChanged url ->
        case LeaveGuard.onUrlChange Route.fromUrl url model.guard of
            ( guard, cmd, Enter route ) ->
                enter route { model | guard = guard } |> addCmd (Cmd.map GuardMsg cmd)

            ( guard, cmd, SamePage address ) ->
                ( applyQuery address { model | guard = guard }, Cmd.map GuardMsg cmd )

            ( guard, cmd, Unchanged ) ->
                ( { model | guard = guard }, Cmd.map GuardMsg cmd )

The first argument says what an address means to you (the same `target` you give to
`request` and to `initAt`); the answer is a `Change`, which says what the page does.

The guard never moves in the history by itself. `Nav.back` and `Nav.forward` call
`onUrlChange` twice (at once with the address they leave, later with the new one),
and a program in Elm cannot tell Back from Forward; a guard that moved to undo the
move looped forever, which is why this one does not. Put together, the history after
"Stay" has one entry more than before only when the user pressed Forward, and the
forward entries are gone after Back; "Leave" adds no entry.

A guard made with `init` has no address to compare with and never holds: every
change of the address is entered.

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
settled the question: every "Leave" and every "Save and leave" gives one. A button
that is pressed twice, or after the question was answered, settles nothing the second
time.

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

### `follow`

```elm
follow : (target -> String) -> Decision target -> Guard source target -> Cmd msg
```

Goes to the destination of a decision of "Leave": it pushes the address of a
held link (with the `Key` of `initAt`), and does nothing when the Back or Forward
button already took the address bar there (the guard has made it the page's address,
and `onUrlChange` enters it). The function writes your target as an address, the
same one your links use. Call it in the branch that gets the decision, next to the
reset of the work the user gave up. With `saveAndLeave` that branch also gets "Save and
leave", which keeps the work: check `savesFirst` before you reset anything.

    Just answer ->
        if LeaveGuard.savesFirst answer then
            -- "Save and leave": save, and go on when the save has succeeded
            save (SavedThenGo (LeaveGuard.destination answer)) { model | guard = guard }
                |> addCmd (Cmd.map GuardMsg cmd)

        else
            -- "Leave": the draft is given up
            ( { model | guard = guard, draft = model.saved }
            , Cmd.batch [ Cmd.map GuardMsg cmd, LeaveGuard.follow Route.toPath answer guard ]
            )

For "Save and leave" `follow` does nothing. A guard made with `init` has no address to
move: show the `destination` yourself.

### `view`

```elm
view : (Msg -> msg) -> List (Attribute msg) -> Guard source target -> Overlay.Overlay msg
```

The dialog. Renders nothing while no question is open, so it can stay in your
view all the time; put it in the `overlays` of
[`Overlay.host`](Klar.Overlay.md#host) or the `overlays` of `AppShell`.

    LeaveGuard.view GuardMsg [ LeaveGuard.saveAndLeave ] model.guard

### `isOpen`

```elm
isOpen : Guard source target -> Bool
```

Is the question open? The page behind the dialog is already inert when `view` is in
the overlay list (`Overlay.host` or `AppShell.overlays`), so you need this only for
your own logic, such as ignoring a shortcut while the question is open.

### `pending`

```elm
pending : Guard source target -> Maybe target
```

The value that waits for the answer, while the question is open.

## Attributes

### `Attribute`

```elm
type Attribute msg  -- opaque: no constructors are exposed
```

A setting of the dialog. Make them with the functions below and pass a list
to `view`; later attributes win over earlier ones.

### `title`

```elm
title : String -> Attribute msg
```

The question, replacing "Leave without saving?". It is the accessible name of
the dialog.

### `message`

```elm
message : String -> Attribute msg
```

The sentence under the question, replacing "You have unsaved changes. If you
leave now, they are lost." Name what is lost: "Order 1042 and its lines are not
saved."

### `saveAndLeave`

```elm
saveAndLeave : Attribute msg
```

Adds a third button, "Save and leave", for the application that can save from
here. Pressing it closes the dialog and `update` gives you a `Decision` for which `savesFirst` is `True`. It is the
primary button of the dialog; focus still starts on "Stay".

### `locale`

```elm
locale : Locale.Locale -> Attribute msg
```

The language of the built-in text: the question, the sentence and the
buttons. The default is [`Locale.default`](Klar.Locale.md#default), which is English.
