module Klar.Modal exposing
    ( view
    , State, Msg, init, setInitialFocus, update, isOpen
    , open, close
    , Attribute, subtitle, footer, footerStart, flush, hideClose, ariaDescribedBy
    , small, medium, large, size, fullHeight
    , static, busy, onRequestClose
    , lastFocus, closeButtonId
    , locale
    )

{-| A dialog on top of the page, for work that needs the user's full attention:
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
[Klar.ConfirmDialog](Klar-ConfirmDialog) and [Klar.Drawer](Klar-Drawer) are
built on this module, and [Klar.Popover](Klar-Popover), [Klar.Menu](Klar-Menu),
[Klar.ContextMenu](Klar-ContextMenu) and [Klar.Toast](Klar-Toast) refer back
to it instead of repeating them.

A dialog that shows data from the backend (the record to edit, an order to
review) takes its body from [Klar.RemoteView](Klar-RemoteView): the skeleton, the
failure with a retry, and old or refreshing data, without a `case` of your own.

    Modal.view ModalMsg
        []
        model.dialog
        "Order 1042"
        (RemoteView.view [ RemoteView.onRetry ReloadOrder ] model.order viewOrder)


# View

@docs view


# State

The state remembers whether the dialog is open, where focus goes when it opens and
where focus has to return to when it closes. Keep one `State` in your model for
every dialog, each with an id of its own.

@docs State, Msg, init, setInitialFocus, update, isOpen


# Opening and closing

Opening returns the new state and a command that moves focus into the dialog;
map the command into your own message, as in the example. `open` takes the
_opener_: the DOM id of the element that opened the dialog (give a button an id
with `Button.id`). When the dialog closes, focus goes back to the opener, so
that keyboard users continue where they were. A popover or a menu owns its
button and returns focus to it without being told.

@docs open, close


# Content

@docs Attribute, subtitle, footer, footerStart, flush, hideClose, ariaDescribedBy


# Size

A panel along the side of the window is a [Klar.Drawer](Klar-Drawer).

@docs small, medium, large, size, fullHeight


# Dismissing

By default the close button, `Escape` and a click on the backdrop close the
dialog. Three ways to change that:

  - `static`: the backdrop and `Escape` do nothing (the close button still
    works). Use it for forms with unsaved data. The dialog gives a small nudge
    so it does not feel frozen.
  - `onRequestClose msg`: the dialog never closes itself, it sends `msg` and
    the application decides (for example to ask "Discard changes?" with a
    [Klar.ConfirmDialog](Klar-ConfirmDialog) before it calls `Modal.close`).
  - `busy True`: while a request runs nothing can close the dialog.

@docs static, busy, onRequestClose


# Keyboard focus

  - On `open` focus moves into the dialog: to the first element named with
    `setInitialFocus` that exists, or else to the dialog itself (a screen reader
    then reads its title). Where focus goes on open is part of the state in every
    overlay that takes focus when it opens: `Modal`, `Drawer`, `ConfirmDialog` (it
    picks its own) and `Popover`, whose button opens it without a call of yours.
    Set it at `init`, or right before `open` when it depends on what is opened.
  - `Tab` and `Shift+Tab` stay inside: two invisible tab stops around the
    dialog send focus to the other end. Going forward past the last element
    lands on the close button (or on the dialog itself when there is none).
    Going backward past the first lands on the element named with `lastFocus`,
    or else at the end of the footer, or of the body when there is no footer (the
    footer or the body shows a focus ring), so that the next `Shift+Tab` reaches
    the last button.
  - On `close` focus returns to the opener. If that element is gone, or there was
    none (`""`), to the most recent element of the page that had focus before the
    dialog opened and still exists. A dialog opened by a route change or by a
    command from the palette therefore needs no opener. If there is no such element
    either, to the start of the page content (the content area of an `AppShell`,
    the page of an `Overlay.host`), so that the next `Tab` starts there and not
    at the top of the window.
  - If the element that has focus inside the dialog is removed or disabled (a
    button replaced after an action), or focus never arrived (the element named
    with `setInitialFocus` was disabled), focus moves to the dialog itself. No call
    is needed for that.
  - `Escape` is layered: the dialog closes only on an `Escape` that nothing inside
    it handled. A popup open inside the dialog (the list of a select, a menu, a
    date picker) closes alone, and so does a control that handles `Escape` and
    prevents its default (a field of your own that clears its text with
    `Html.Events.preventDefaultOn`, say). The `Escape` that ends an IME
    composition never closes the dialog.
  - The toasts are the last stop of the loop: see [Klar.Overlay](Klar-Overlay).

@docs lastFocus, closeButtonId


# Around the dialog

The page behind an open dialog cannot be scrolled: the stylesheet (see
[Klar](Klar)) hides the page scrollbar and keeps its place free, so that the
layout does not jump. To also make the page unreachable for the keyboard and for
screen readers, give the dialog to [`Overlay.host`](Klar-Overlay#host) (or to
`AppShell.overlays`): `view` returns an [`Overlay`](Klar-Overlay#Overlay), and the
page is `inert` as soon as one of them is open. There is no flag to keep in step.

Popups (a [Klar.Menu](Klar-Menu), a [Klar.Popover](Klar-Popover), the list of a
select or a date picker) are drawn with a transparent layer over the whole
window. A click anywhere outside the popup lands on that layer and closes the
popup instead of reaching the element underneath, and `Escape` closes it too.
When such a popup is open inside a dialog, `Escape` closes only the popup, not
the dialog.

A dialog can open another dialog (a [Klar.ConfirmDialog](Klar-ConfirmDialog)
from a `Modal`, say): put the upper one after the lower one in the list of
overlays. Focus returns to the button that opened it, inside the lower dialog.


# Texts

@docs locale

-}

import Browser.Dom as Dom
import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Events
import Json.Decode as Decode
import Klar.Button as Button
import Klar.Icon as Icon
import Klar.Internal as Internal
import Klar.Locale as Locale exposing (Locale)
import Klar.Modal.Config as Config exposing (Config, Role(..), Side(..))
import Klar.Overlay as Overlay exposing (Overlay)
import Klar.Overlay.Focus as Focus
import Klar.Theme exposing (Size(..))
import Task



-- STATE


{-| The state of one dialog: whether it is open, and where focus returns to when
it closes. Create it with `init`, keep it in your model, and change it with
`open`, `close` and `update`.
-}
type State
    = State
        { id : String
        , open : Bool
        , opener : String

        -- Where focus goes when the dialog opens (the first that exists).
        , focus : List String

        -- The last elements of the page that had focus while the dialog was
        -- closed, newest first: where focus goes when the opener is gone.
        , trail : List String
        , nudge : Int
        }


{-| A closed dialog. The id must be unique on the page: it becomes the DOM id of
the dialog element, and the ids of the parts inside it start with it.
-}
init : String -> State
init id =
    State { id = id, open = False, opener = "", focus = [], trail = [], nudge = 0 }


{-| The ids of elements inside the dialog that get focus when it opens, the first
one that exists: the first field of a form, a search field. Without it (the
default) the dialog itself gets focus, and a screen reader reads its title. Set it
when you create the state:

    Modal.init "edit-order-dialog" |> Modal.setInitialFocus [ "customer-name" ]

When the place depends on what is opened (a record that cannot be changed has no
field to start in), set it right before `open`:

    Modal.open "edit-order-button" (Modal.setInitialFocus [ "customer-name" ] model.editDialog)

-}
setInitialFocus : List String -> State -> State
setInitialFocus ids (State state) =
    State { state | focus = ids }


{-| Is the dialog open? The page behind it is made inert by the overlay `view`
returns, so you rarely need this: use it to show something only while the dialog
is open.
-}
isOpen : State -> Bool
isOpen (State state) =
    state.open


{-| The messages of a dialog (focus movements and the request to close). Wrap it
in a constructor of your own message type, such as `EditDialogMsg Modal.Msg`,
and hand it to `update`.
-}
type Msg
    = RequestClose
    | Nudge
    | Seen String
    | Lost
    | ScrollBody Step
    | FocusFirst (List String)
    | FocusLast (List String)
    | Noop


{-| How the keyboard scrolls the body of a dialog that has no focusable content.
-}
type Step
    = Lines Float
    | Pages Float
    | ToStart
    | ToEnd


{-| Handles the messages of the dialog: it moves focus, nudges a `static`
dialog, and closes the dialog when the user asks for it with the close button,
`Escape` or the backdrop (unless you took that over with `onRequestClose`). Map
its command into your own message with `Cmd.map`.
-}
update : Msg -> State -> ( State, Cmd Msg )
update msg ((State state) as current) =
    case msg of
        RequestClose ->
            close current

        Nudge ->
            ( State { state | nudge = state.nudge + 1 }, Cmd.none )

        Seen id ->
            -- Something on the page got focus while the dialog was closed.
            if state.open then
                ( current, Cmd.none )

            else
                ( State { state | trail = List.take 8 (id :: List.filter ((/=) id) state.trail) }
                , Cmd.none
                )

        Lost ->
            -- The element that had focus went away or was disabled, or focus never
            -- came in: it is on the page, where `Escape` and `Tab` do not reach the
            -- dialog.
            ( current
            , if state.open then
                Internal.focusFirst [ state.id ] Noop

              else
                Cmd.none
            )

        ScrollBody step ->
            ( current, scrollBody (bodyId state.id) step )

        FocusFirst candidates ->
            ( current, Internal.focusFirst candidates Noop )

        FocusLast candidates ->
            ( current, Internal.focusFirst candidates Noop )

        Noop ->
            ( current, Cmd.none )


{-| Opens the dialog and moves focus into it: to the first element of
`setInitialFocus` that exists, or else to the dialog itself. `opener` is the DOM
id of the element to give focus back to when the dialog closes, usually the button
that opened it. With `""`, or when that element is gone, focus goes back to the
most recent element of the page that had focus before the dialog opened and still
exists (it needs an id).

    Modal.open "edit-order-button" model.editDialog

Calling it on a dialog that is already open moves focus again and keeps the first
opener.

-}
open : String -> State -> ( State, Cmd Msg )
open opener (State state) =
    ( State
        { state
            | open = True
            , opener =
                if state.open then
                    state.opener

                else
                    opener
            , nudge = 0
        }
    , Internal.focusFirst (state.focus ++ [ state.id ]) Noop
    )


{-| Closes the dialog and gives focus back to its opener (see `open`). Call it
from your own buttons and when the work is done; the close button, `Escape` and
the backdrop close the dialog through `update`.
-}
close : State -> ( State, Cmd Msg )
close (State state) =
    ( State { state | open = False }
    , if state.open then
        Internal.focusFirst (List.filter ((/=) "") (state.opener :: state.trail) ++ [ Internal.pageStartId ]) Noop

      else
        Cmd.none
    )


{-| Scroll the body of the dialog.
-}
scrollBody : String -> Step -> Cmd Msg
scrollBody id step =
    Dom.getViewportOf id
        |> Task.andThen
            (\found ->
                let
                    furthest =
                        max 0 (found.scene.height - found.viewport.height)

                    target =
                        case step of
                            Lines n ->
                                found.viewport.y + n * 40

                            Pages n ->
                                found.viewport.y + n * found.viewport.height * 0.9

                            ToStart ->
                                0

                            ToEnd ->
                                furthest
                in
                Dom.setViewportOf id 0 (clamp 0 furthest target)
            )
        |> Task.attempt (\_ -> Noop)


{-| The DOM id of the close button in the header. Give it as the `opener` of a
dialog that is opened from this one, such as a "Discard changes?" question asked
from `onRequestClose`, so that focus comes back to the close button when that
dialog closes:

    ConfirmDialog.open (Modal.closeButtonId model.editDialog) model.discardDialog

There is no close button, and so nothing to return to, with `hideClose`.

-}
closeButtonId : State -> String
closeButtonId (State state) =
    closeId state.id


closeId : String -> String
closeId id =
    id ++ "-close"


titleId : String -> String
titleId id =
    id ++ "-title"


bodyId : String -> String
bodyId id =
    id ++ "-body"


{-| An empty element that can take focus at the very end of the dialog: after the
footer's buttons, or after the body when there is no footer. `Shift+Tab` past the
first element lands here, so that the next `Shift+Tab` reaches the last button.
-}
endId : String -> String
endId id =
    id ++ "-end"



-- ATTRIBUTES


{-| A setting of a dialog. Make them with the functions below and pass a list to
`view`; later attributes win over earlier ones. [Klar.Drawer](Klar-Drawer) and
[Klar.ConfirmDialog](Klar-ConfirmDialog) use the same settings. The type is opaque:
it is defined in a module of this package that is not exposed, so the functions
below are the only way to make one.
-}
type alias Attribute msg =
    Config.Attribute msg


{-| A smaller line below the title, for context such as the order number.
-}
subtitle : String -> Attribute msg
subtitle value =
    Config.Attribute (\config -> { config | subtitle = Just value })


{-| 400px wide, for a short question or a field or two.
-}
small : Attribute msg
small =
    size Small


{-| 560px wide. This is the default.
-}
medium : Attribute msg
medium =
    size Medium


{-| 800px wide, for wide forms and tables.
-}
large : Attribute msg
large =
    size Large


{-| Sets the width from a [`Size`](Klar-Theme#Size): `Small` (400px), `Medium`
(560px, the default) or `Large` (800px). `small`, `medium` and `large` are
shorthands. A [Klar.Drawer](Klar-Drawer) is 360, 480 or 720px wide instead.
-}
size : Size -> Attribute msg
size value =
    Config.Attribute (\config -> { config | size = value })


{-| The dialog is as tall as the window (less a small margin) instead of only as
tall as its content. For long forms and lists. It stays in the middle of the
window; a panel along its side is a [Klar.Drawer](Klar-Drawer).
-}
fullHeight : Attribute msg
fullHeight =
    Config.Attribute (\config -> { config | fullHeight = True })


{-| A click on the backdrop and `Escape` do not close the dialog; the close
button still does. The dialog gives a small nudge instead, so that it does not
feel frozen. For forms with unsaved data.
-}
static : Attribute msg
static =
    Config.Attribute (\config -> { config | static = True })


{-| While `True` nothing can close the dialog: the close button is disabled and
the backdrop and `Escape` are ignored. The dialog also announces `aria-busy`.
Pass a field of your model that is `True` while a request runs.
-}
busy : Bool -> Attribute msg
busy value =
    Config.Attribute (\config -> { config | busy = value })


{-| Send this message instead of closing. The close button, `Escape` and the
backdrop then send `msg` and the dialog stays open; the application decides, and
calls `Modal.close` when it is fine to go (after asking "Discard changes?",
say). A `static` dialog sends `msg` only from its close button.
-}
onRequestClose : msg -> Attribute msg
onRequestClose msg =
    Config.Attribute (\config -> { config | onRequestClose = Just msg })


{-| Content at the left end of the footer, opposite the actions: a note, a
checkbox, a "Delete order" link. Giving it also shows the footer.
-}
footerStart : List (Html msg) -> Attribute msg
footerStart value =
    Config.Attribute (\config -> { config | footerStart = value })


{-| The actions, right aligned in a fixed footer at the bottom of the dialog. The
primary action goes last. The footer is only shown when `footer` or
`footerStart` is given.
-}
footer : List (Html msg) -> Attribute msg
footer value =
    Config.Attribute (\config -> { config | footer = value })


{-| No padding around the body, for tables and lists that go edge to edge.
-}
flush : Attribute msg
flush =
    Config.Attribute (\config -> { config | flush = True })


{-| Do not show the close button in the header. `Escape` and the backdrop still
close the dialog unless it is `static`, so give the user another way out, such
as a "Cancel" button in the footer.
-}
hideClose : Attribute msg
hideClose =
    Config.Attribute (\config -> { config | hideClose = True })


{-| The id of an element inside the dialog that describes it (a paragraph of
explanation, say). Screen readers read it out after the title.
-}
ariaDescribedBy : String -> Attribute msg
ariaDescribedBy value =
    Config.Attribute (\config -> { config | ariaDescribedBy = Just value })


{-| The id of the element that `Shift+Tab` on the first element of the dialog
wraps around to, usually the primary button. Without it focus lands at the end of
the footer (or of the body when there is no footer), and the next `Shift+Tab`
reaches the last button.
-}
lastFocus : String -> Attribute msg
lastFocus value =
    Config.Attribute (\config -> { config | lastFocus = Just value })


{-| The language of the built-in text, which is the label of the close button
("Close" by default). The default language is
[`Locale.default`](Klar-Locale#default), which is English.
-}
locale : Locale -> Attribute msg
locale value =
    Config.Attribute (\config -> { config | locale = value })



-- VIEW


{-| The dialog titled `title`, with `body` in its scrolling middle part. The title
is the heading of the dialog and its accessible name. `toMsg` wraps the messages
of the dialog (see the example at the top of this page). Renders nothing while the
dialog is closed, so it can stay in your view all the time. It returns an
[`Overlay`](Klar-Overlay#Overlay): put it in the list of overlays of
[`Overlay.host`](Klar-Overlay#host) or `AppShell.overlays`.
-}
view : (Msg -> msg) -> List (Attribute msg) -> State -> String -> List (Html msg) -> Overlay msg
view toMsg attributes ((State state) as current) title body =
    let
        config =
            Config.configure attributes

        firstTargets =
            (if config.hideClose || config.busy then
                []

             else
                [ closeId state.id ]
            )
                ++ [ state.id ]
    in
    Overlay.dialog
        { open = state.open
        , entry = Just firstTargets
        , watch =
            if state.open then
                Nothing

            else
                Just (\id -> toMsg (Seen id))
        , render = \around -> viewDialog toMsg config current title firstTargets around body
        }


viewDialog :
    (Msg -> msg)
    -> Config msg
    -> State
    -> String
    -> List String
    -> { top : Bool, toastsFollow : Bool }
    -> List (Html msg)
    -> Html msg
viewDialog toMsg config (State state) title firstTargets around body =
    if not state.open then
        Html.text ""

    else
        let
            hasFooter =
                not (List.isEmpty config.footer) || not (List.isEmpty config.footerStart)

            requestClose =
                case config.onRequestClose of
                    Just msg ->
                        msg

                    Nothing ->
                        toMsg RequestClose

            -- What Escape and the backdrop do. Nothing = ignored.
            dismiss =
                if config.busy then
                    Nothing

                else if config.static then
                    Just (toMsg Nudge)

                else
                    Just requestClose

            closeLabel =
                Locale.pick config.locale { nb = "Lukk", en = "Close" }

            lastTargets =
                List.filterMap identity [ config.lastFocus, Just (endId state.id), Just state.id ]

            end =
                Html.div [ Attr.id (endId state.id), Attr.tabindex -1, Internal.cls [ "klar-modal__end" ] ] []

            nudgeClass =
                if state.nudge == 0 then
                    ""

                else if modBy 2 state.nudge == 1 then
                    "klar-modal__dialog--nudge-a"

                else
                    "klar-modal__dialog--nudge-b"
        in
        Html.div
            [ Internal.cls
                [ "klar-modal"
                , "klar-modal--" ++ Internal.sizeSuffix config.size
                , if config.fullHeight then
                    "klar-modal--tall"

                  else
                    ""
                , case config.side of
                    Just Right ->
                        "klar-modal--side klar-modal--right"

                    Just Left ->
                        "klar-modal--side klar-modal--left"

                    Nothing ->
                        ""
                ]
            ]
            [ Html.div [ Internal.cls [ "klar-modal-lock" ] ] []
            , sentinel (toMsg (FocusLast lastTargets))
            , Html.div
                ([ Internal.cls [ "klar-modal__backdrop" ]
                 , Internal.onMouseDownPrevent (toMsg Noop)
                 ]
                    ++ (case dismiss of
                            Just msg ->
                                [ Events.onClick msg ]

                            Nothing ->
                                []
                       )
                )
                []
            , Html.div
                [ Internal.cls [ "klar-modal__dialog", nudgeClass ]
                , Attr.id state.id
                , Attr.tabindex -1
                , Attr.attribute "role"
                    (case config.role of
                        Dialog ->
                            "dialog"

                        AlertDialog ->
                            "alertdialog"
                    )
                , Attr.attribute "aria-modal" "true"
                , Attr.attribute "aria-labelledby" (titleId state.id)
                , Internal.attrMaybe (Attr.attribute "aria-describedby") config.ariaDescribedBy
                , Internal.attrIf config.busy (Attr.attribute "aria-busy" "true")
                , dialogKeys state.id dismiss toMsg
                ]
                [ viewHeader state.id config title closeLabel requestClose
                , Html.div
                    [ Attr.id (bodyId state.id)
                    , Internal.cls
                        [ "klar-modal__body"
                        , if config.flush then
                            "klar-modal__body--flush"

                          else
                            ""
                        ]
                    ]
                    (body
                        ++ [ if hasFooter then
                                Html.text ""

                             else
                                end
                           ]
                    )
                , if hasFooter then
                    Html.div [ Internal.cls [ "klar-modal__footer" ] ]
                        [ if List.isEmpty config.footerStart then
                            Html.text ""

                          else
                            Html.div [ Internal.cls [ "klar-modal__footer-start" ] ] config.footerStart
                        , Html.div [ Internal.cls [ "klar-modal__footer-actions" ] ] config.footer
                        , end
                        ]

                  else
                    Html.text ""

                -- Only the dialog on top keeps watch, and it does from the moment it
                -- opens: focus that never arrives (the element named with
                -- `setInitialFocus` was disabled) is lost focus too.
                , Internal.viewIf around.top (Focus.guard Focus.Modal (toMsg Lost))
                ]
            , if around.toastsFollow then
                -- The toasts come next in the tab order and close the loop.
                Html.text ""

              else
                sentinel (toMsg (FocusFirst firstTargets))
            ]


viewHeader : String -> Config msg -> String -> String -> msg -> Html msg
viewHeader id config title closeLabel requestClose =
    -- A div, not a `header`: inside a dialog that element is no landmark, but two
    -- dialogs open at once would make axe count two banners.
    Html.div [ Internal.cls [ "klar-modal__header" ] ]
        [ Html.div [ Internal.cls [ "klar-modal__heading" ] ]
            [ Html.h2 [ Internal.cls [ "klar-modal__title" ], Attr.id (titleId id) ] [ Html.text title ]
            , Internal.viewMaybe
                (\text -> Html.p [ Internal.cls [ "klar-modal__subtitle" ] ] [ Html.text text ])
                config.subtitle
            ]
        , if config.hideClose then
            Html.text ""

          else
            Html.div [ Internal.cls [ "klar-modal__close" ] ]
                [ Button.iconOnly
                    [ Button.ghost
                    , Button.small
                    , Button.id (closeId id)
                    , Button.disabled config.busy
                    , Button.onClick requestClose
                    ]
                    Icon.close
                    closeLabel
                ]
        ]


{-| An invisible tab stop. When it receives focus the user has tabbed out of
the dialog; the message moves focus to the other end.
-}
sentinel : msg -> Html msg
sentinel msg =
    Html.div
        [ Internal.cls [ "klar-modal__sentinel" ]
        , Attr.tabindex 0
        , Events.onFocus msg
        ]
        []



-- KEYS


{-| The keydown handler of the dialog (a node keeps only one).

`Escape` closes the dialog, unless something inside handled it already (it
prevented the default), it was pressed in a popup that is open inside the dialog,
or it ends an IME composition. The dialog prevents the default of the `Escape` it acts
on, so that a global shortcut leaves it alone.

While the dialog element itself has focus, which it has when the dialog opens,
the keys that scroll a page scroll the body of the dialog: it is not focusable,
and without this a long text in a dialog could not be read with the keyboard.

-}
dialogKeys : String -> Maybe msg -> (Msg -> msg) -> Html.Attribute msg
dialogKeys dialogId dismiss toMsg =
    Events.preventDefaultOn "keydown"
        (Focus.unhandled
            |> Decode.andThen (\_ -> Internal.keyEvent)
            |> Decode.andThen
                (\event ->
                    if event.key == "Escape" then
                        case dismiss of
                            Just msg ->
                                Focus.escape dialogId msg

                            Nothing ->
                                Decode.fail "closing is switched off"

                    else if event.ctrl || event.meta || event.alt then
                        Decode.fail "a shortcut"

                    else
                        case scrollStep event.key of
                            Just step ->
                                Decode.at [ "target", "id" ] Decode.string
                                    |> Decode.andThen
                                        (\id ->
                                            if id == dialogId then
                                                Decode.succeed ( toMsg (ScrollBody step), True )

                                            else
                                                Decode.fail "focus is on something inside"
                                        )

                            Nothing ->
                                Decode.fail "not a key of the dialog"
                )
        )


scrollStep : String -> Maybe Step
scrollStep key =
    case key of
        "ArrowDown" ->
            Just (Lines 1)

        "ArrowUp" ->
            Just (Lines -1)

        "PageDown" ->
            Just (Pages 1)

        "PageUp" ->
            Just (Pages -1)

        "Home" ->
            Just ToStart

        "End" ->
            Just ToEnd

        _ ->
            Nothing
