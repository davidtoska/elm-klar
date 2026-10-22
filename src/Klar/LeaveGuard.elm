module Klar.LeaveGuard exposing
    ( Guard, init, setDirty, isDirty, dirtySources
    , request, Answer(..)
    , Msg, update, Decision(..), view, isOpen, pending
    , Attribute, title, message, saveAndLeave, locale
    )

{-| Asks "Leave without saving?" when the user navigates away inside the
application while something is not saved.

    import Klar.LeaveGuard as LeaveGuard exposing (Answer(..), Decision(..))

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

            Just (Leave route) ->
                -- the changes are given up: goTo is yours (Nav.pushUrl ...)
                goTo route { model | guard = guard }

            Just (SaveFirst route) ->
                saveThenGo route next

    -- view: render the dialog once, with the page, and let it make the page inert
    LeaveGuard.view GuardMsg [] model.guard

`request` is the only way to ask. A guard with nothing dirty answers `Proceed`
with your own value, a `Route` or a `Url`, and you go there. A guard with something
dirty answers `Hold`: it keeps your value as plain data, opens a dialog ("Leave
without saving?" with "Leave" and "Stay") and gives you the new guard to keep, so
there is no way to hold a request and forget to open the dialog. The dialog is a
[Klar.Modal](Klar-Modal): focus goes to "Stay", the safe choice, `Escape`, the
backdrop and the close button mean "Stay", and focus goes back to the link or button
that asked (give it an id with `Button.id`; without one focus falls to the page).
`Leave` and `Stay` are messages of the dialog; `update` resolves them. On "Leave"
you get the held value back as a `Decision` and the guard forgets everything that was
dirty, since the user gave those changes up; on "Stay" nothing is left for you to
do. While the dialog is open the page behind it must be inert: pass `isOpen` to
`Modal.host` as `blocked`, or to `AppShell.modalOpen`.

**Several forms.** Each form that can hold unsaved changes is a source of your own
type (a union of the forms, a record id) and reports with `setDirty`. The guard is
clean only when every source is clean. Sources and requests are compared with `==`, so
they must not contain functions.

**A new request while the question is open** replaces the held one: the latest thing
the user asked for is what "Leave" does. A request is never held when everything is
clean and no question is open.

**Save and leave.** With the attribute `saveAndLeave` the dialog has a third button.
It closes the dialog, keeps the dirty marks and gives you `SaveFirst route`: save,
carry the route in the message that comes back from the save (`SavedThenGo route`),
and go there when it succeeded. If the save fails the user is still on the page, with
the form's own error. Leaving the dirty marks in place means a second click on a
link, while the save is on its way, asks again.

**What this cannot do.** The guard sees navigation inside the application. Closing the
tab, reloading and typing another address happen outside the page: only the
`beforeunload` event of JavaScript can ask about those, and Klar has no JavaScript. If
your application may have a port, this is all of it:

    port unsavedChanges : Bool -> Cmd msg

    // JavaScript, once
    app.ports.unsavedChanges.subscribe(function (dirty) {
      window.onbeforeunload = dirty ? function (event) { event.preventDefault(); } : null;
    });

and call it with `LeaveGuard.isDirty guard` whenever that changes. The back button
of the browser changes the address before your program hears of it: in
`UrlChanged`, put the old address back (`Nav.pushUrl`) and `request` the new one.


# The guard

@docs Guard, init, setDirty, isDirty, dirtySources


# Asking

@docs request, Answer


# The dialog

@docs Msg, update, Decision, view, isOpen, pending


# Attributes

@docs Attribute, title, message, saveAndLeave, locale

-}

import Html exposing (Html)
import Html.Attributes as Attr
import Klar.Button as Button
import Klar.Icon as Icon
import Klar.Internal as Internal
import Klar.Locale as Locale exposing (Locale)
import Klar.Modal as Modal



-- THE GUARD


{-| What the application knows about unsaved work: which sources are dirty, the
request that waits for an answer, and the dialog that asks. `source` is your own
type for the places that can hold unsaved changes and `target` is your own type for
where the user wants to go. Neither may contain functions. Make one with `init`
and keep it in your model.
-}
type Guard source target
    = Guard
        { id : String
        , modal : Modal.State
        , dirty : List source
        , held : Maybe target
        }


{-| A guard with nothing dirty and no question open. The `String` is the DOM id of
the dialog and must be unique on the page; the ids of its parts start with it.

    LeaveGuard.init "leave-dialog"

-}
init : String -> Guard source target
init id =
    Guard { id = id, modal = Modal.init id, dirty = [], held = Nothing }


{-| Says whether a source holds unsaved changes. Call it whenever that can change,
with the comparison itself:

    LeaveGuard.setDirty OrderForm (model.draft /= model.saved) model.guard

Saying the same thing twice is harmless, and a source that was never mentioned is
clean. The guard keeps a handful of sources in a list: it is meant for forms, not
for thousands of rows.

-}
setDirty : source -> Bool -> Guard source target -> Guard source target
setDirty source dirty (Guard state) =
    Guard
        { state
            | dirty =
                if dirty then
                    if List.member source state.dirty then
                        state.dirty

                    else
                        state.dirty ++ [ source ]

                else
                    List.filter (\other -> other /= source) state.dirty
        }


{-| Is anything dirty? `False` only when every source is clean. Use it for a
`beforeunload` port (see above) or an "unsaved changes" mark.
-}
isDirty : Guard source target -> Bool
isDirty (Guard state) =
    not (List.isEmpty state.dirty)


{-| The sources that are dirty, in the order they became dirty.
-}
dirtySources : Guard source target -> List source
dirtySources (Guard state) =
    state.dirty



-- ASKING


{-| The answer to a request: go there, or wait for the user.

  - `Proceed target` is the value you asked with. Nothing is dirty, no dialog is
    open, and the guard is unchanged: navigate.
  - `Hold guard cmd` means the value is kept and the dialog is open. Store the new
    guard and run the command (map it with `Cmd.map`): it moves focus to "Stay".

This is a union with exactly these two cases, because the application has to do
something different in each: there is nothing else a guard can say.

-}
type Answer source target
    = Proceed target
    | Hold (Guard source target) (Cmd Msg)


{-| Asks whether the user may go to `target` now. Every navigation of the
application goes through here, the clicks on links and the changes of the
address.

    LeaveGuard.request (Route.fromUrl url) model.guard

When a question is already open, the new `target` replaces the old one and the
dialog stays open (see the top of this page).

-}
request : target -> Guard source target -> Answer source target
request target ((Guard state) as guard) =
    case ( state.dirty, state.held ) of
        ( [], Nothing ) ->
            Proceed target

        _ ->
            let
                -- "" as the opener: focus goes back to whatever had it when the
                -- dialog opened, if that element has an id
                ( modal, cmd ) =
                    Modal.openWith { opener = "", focus = [ stayId state.id ] } state.modal
            in
            Hold (Guard { state | modal = modal, held = Just target }) (Cmd.map ModalMsg cmd)



-- THE DIALOG


{-| The messages of the dialog: the three buttons and the focus movements. Wrap
it in a constructor of your own message type, such as `GuardMsg LeaveGuard.Msg`,
and hand it to `update`.
-}
type Msg
    = ModalMsg Modal.Msg
    | StayPressed
    | LeavePressed
    | SavePressed


{-| What the user decided in the dialog.

  - `Leave target` is the value that was held. The user gave up the unsaved
    changes: the guard is clean now. Navigate.
  - `SaveFirst target` comes only from the button added by `saveAndLeave`. The
    dirty marks are still there: save, then navigate when it succeeded.

"Stay" is not a decision, there is nothing to do.

-}
type Decision target
    = Leave target
    | SaveFirst target


{-| Applies a message of the dialog. The result is the new guard, a command to
map into your own message with `Cmd.map`, and the decision when this message
settled the question. A button that is pressed twice, or after the question was
answered, settles nothing the second time.
-}
update : Msg -> Guard source target -> ( Guard source target, Cmd Msg, Maybe (Decision target) )
update msg ((Guard state) as guard) =
    case msg of
        ModalMsg inner ->
            let
                ( modal, cmd ) =
                    Modal.update inner state.modal
            in
            ( Guard { state | modal = modal }, Cmd.map ModalMsg cmd, Nothing )

        StayPressed ->
            case state.held of
                Just _ ->
                    let
                        ( modal, cmd ) =
                            Modal.close state.modal
                    in
                    ( Guard { state | modal = modal, held = Nothing }, Cmd.map ModalMsg cmd, Nothing )

                Nothing ->
                    ( guard, Cmd.none, Nothing )

        LeavePressed ->
            case state.held of
                Just target ->
                    let
                        ( modal, cmd ) =
                            Modal.close state.modal
                    in
                    ( Guard { state | modal = modal, held = Nothing, dirty = [] }
                    , Cmd.map ModalMsg cmd
                    , Just (Leave target)
                    )

                Nothing ->
                    ( guard, Cmd.none, Nothing )

        SavePressed ->
            case state.held of
                Just target ->
                    let
                        ( modal, cmd ) =
                            Modal.close state.modal
                    in
                    ( Guard { state | modal = modal, held = Nothing }
                    , Cmd.map ModalMsg cmd
                    , Just (SaveFirst target)
                    )

                Nothing ->
                    ( guard, Cmd.none, Nothing )


{-| Is the question open? Pass it to `Modal.host` as `blocked`, or to
`AppShell.modalOpen`, so that the page behind the dialog is inert.
-}
isOpen : Guard source target -> Bool
isOpen (Guard state) =
    Modal.isOpen state.modal


{-| The value that waits for the answer, while the question is open.
-}
pending : Guard source target -> Maybe target
pending (Guard state) =
    state.held


stayId : String -> String
stayId id =
    id ++ "-stay"


leaveId : String -> String
leaveId id =
    id ++ "-leave"


saveId : String -> String
saveId id =
    id ++ "-save"


messageId : String -> String
messageId id =
    id ++ "-message"



-- ATTRIBUTES


{-| A setting of the dialog. Make them with the functions below and pass a list
to `view`; later attributes win over earlier ones. They carry no messages, so the
type has no `msg` parameter.
-}
type Attribute
    = Attribute (Config -> Config)


type alias Config =
    { title : Maybe String
    , message : Maybe String
    , save : Bool
    , locale : Locale
    }


configure : List Attribute -> Config
configure attributes =
    List.foldl (\(Attribute change) config -> change config)
        { title = Nothing, message = Nothing, save = False, locale = Locale.default }
        attributes


{-| The question, replacing "Leave without saving?". It is the accessible name of
the dialog.
-}
title : String -> Attribute
title value =
    Attribute (\config -> { config | title = Just value })


{-| The sentence under the question, replacing "You have unsaved changes. If you
leave now, they are lost." Name what is lost: "Order 1042 and its lines are not
saved."
-}
message : String -> Attribute
message value =
    Attribute (\config -> { config | message = Just value })


{-| Adds a third button, "Save and leave", for the application that can save from
here. Pressing it closes the dialog and `update` gives you `SaveFirst`. It is the
primary button of the dialog; focus still starts on "Stay".
-}
saveAndLeave : Attribute
saveAndLeave =
    Attribute (\config -> { config | save = True })


{-| The language of the built-in text: the question, the sentence and the
buttons. The default is [`Locale.default`](Klar-Locale#default), which is English.
-}
locale : Locale -> Attribute
locale value =
    Attribute (\config -> { config | locale = value })



-- VIEW


{-| The dialog. Renders nothing while no question is open, so it can stay in your
view all the time; put it in the `overlays` of
[`Modal.host`](Klar-Modal#host) or the `overlays` of `AppShell`.

    LeaveGuard.view GuardMsg [ LeaveGuard.saveAndLeave ] model.guard

-}
view : (Msg -> msg) -> List Attribute -> Guard source target -> Html msg
view toMsg attributes (Guard state) =
    let
        config =
            configure attributes

        texts =
            { title = Locale.pick config.locale { nb = "Forlate siden uten å lagre?", en = "Leave without saving?" }
            , message =
                Locale.pick config.locale
                    { nb = "Du har ulagrede endringer. Forlater du siden nå, går de tapt."
                    , en = "You have unsaved changes. If you leave now, they are lost."
                    }
            , leave = Locale.pick config.locale { nb = "Forlat", en = "Leave" }
            , stay = Locale.pick config.locale { nb = "Bli her", en = "Stay" }
            , save = Locale.pick config.locale { nb = "Lagre og forlat", en = "Save and leave" }
            }

        leaveButton =
            Button.view
                [ Button.id (leaveId state.id)
                , Button.secondary
                , Button.danger
                , Button.onClick (toMsg LeavePressed)
                ]
                texts.leave

        stayButton =
            Button.view
                ([ Button.id (stayId state.id)
                 , Button.onClick (toMsg StayPressed)
                 ]
                    ++ (if config.save then
                            []

                        else
                            [ Button.primary ]
                       )
                )
                texts.stay

        saveButton =
            Button.view
                [ Button.id (saveId state.id)
                , Button.primary
                , Button.icon Icon.save
                , Button.onClick (toMsg SavePressed)
                ]
                texts.save
    in
    Modal.view (\inner -> toMsg (ModalMsg inner))
        [ Modal.title (Maybe.withDefault texts.title config.title)
        , Modal.small
        , Modal.locale config.locale
        , Modal.onRequestClose (toMsg StayPressed)
        , Modal.ariaDescribedBy (messageId state.id)
        , Modal.lastFocus
            (if config.save then
                saveId state.id

             else
                stayId state.id
            )
        , Modal.footer
            (if config.save then
                [ leaveButton, stayButton, saveButton ]

             else
                [ leaveButton, stayButton ]
            )
        ]
        state.modal
        [ Html.p
            [ Internal.cls [ "klar-leave__message" ]
            , Attr.id (messageId state.id)
            ]
            [ Html.text (Maybe.withDefault texts.message config.message) ]
        ]
