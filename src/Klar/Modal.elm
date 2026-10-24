module Klar.Modal exposing
    ( view
    , State, Msg, init, update, isOpen
    , open, openWith, close
    , Attribute, title, subtitle, footer, footerStart, flush, hideClose, ariaDescribedBy
    , small, medium, large, size, fullHeight, Side(..), side
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
        [ Modal.title "Edit order"
        , Modal.large
        , Modal.footer
            [ Button.view [ Button.onClick CancelEdit ] "Cancel"
            , Button.view [ Button.primary, Button.onClick SaveOrder ] "Save"
            ]
        ]
        model.editDialog
        [ orderForm ]

The dialog has a fixed header (the title and a close button), a body that
scrolls on its own and an optional fixed footer for the actions. Screen readers
announce it as a modal dialog named by its title. In the example, `CancelEdit`
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
        [ Modal.title "Order 1042" ]
        model.dialog
        (RemoteView.view [ RemoteView.onRetry ReloadOrder ] model.order viewOrder)


# View

@docs view


# State

The state remembers whether the dialog is open and where focus has to return
to when it closes. Keep one `State` in your model for every dialog, each with an
id of its own.

@docs State, Msg, init, update, isOpen


# Opening and closing

Opening returns the new state and a command that moves focus into the dialog;
map the command into your own message, as in the example. `open` takes the
_opener_: the DOM id of the element that opened the dialog (give a button an id
with `Button.id`). When the dialog closes, focus goes back to the opener, so
that keyboard users continue where they were. A popover or a menu owns its
button and returns focus to it without being told.

@docs open, openWith, close


# Content

@docs Attribute, title, subtitle, footer, footerStart, flush, hideClose, ariaDescribedBy


# Size and placement

@docs small, medium, large, size, fullHeight, Side, side


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

  - On `open` focus moves into the dialog: to the dialog itself, or to the
    first element named in `openWith { opener = ..., focus = [ "first-field-id" ] }`
    that exists.
  - `Tab` and `Shift+Tab` stay inside: two invisible tab stops around the
    dialog send focus to the other end. Going forward past the last element
    lands on the close button (or on the dialog itself when there is none);
    going backward past the first lands on the footer, or on the element named
    with `lastFocus`.
  - On `close` focus returns to the opener. If that element is gone, or there was
    none (`""`), to the most recent element of the page that had focus before the
    dialog opened and still exists. A dialog opened by a route change or by a
    command from the palette therefore needs no opener. If there is no such element
    either, to the start of the page content (the content area of an `AppShell`,
    the page of an `Overlay.host`), so that the next `Tab` starts there and not
    at the top of the window.
  - If the element that has focus inside the dialog is removed or disabled (a
    button replaced after an action), focus moves to the dialog itself. No call
    is needed for that.
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
import Json.Decode as Decode exposing (Decoder)
import Klar.Button as Button
import Klar.Icon as Icon
import Klar.Internal as Internal
import Klar.Locale as Locale exposing (Locale)
import Klar.Overlay as Overlay exposing (Overlay)
import Klar.Theme as Theme exposing (Size(..))
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

        -- The last elements of the page that had focus while the dialog was
        -- closed, newest first: where focus goes when the opener is gone.
        , trail : List String
        , arrived : Bool
        , nudge : Int
        }


{-| A closed dialog. The id must be unique on the page: it becomes the DOM id of
the dialog element, and the ids of the parts inside it start with it.
-}
init : String -> State
init id =
    State { id = id, open = False, opener = "", trail = [], arrived = False, nudge = 0 }


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
    | Arrived
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

        Arrived ->
            -- Focus came into the dialog: from now on it keeps watch (see `Lost`).
            ( State { state | arrived = True }, Cmd.none )

        Lost ->
            -- The element that had focus went away, or was disabled: focus fell
            -- to the page, where `Escape` and `Tab` no longer reach the dialog.
            ( current
            , if state.open then
                focusChain [ state.id ]

              else
                Cmd.none
            )

        ScrollBody step ->
            ( current, scrollBody (bodyId state.id) step )

        FocusFirst candidates ->
            ( current, focusChain candidates )

        FocusLast candidates ->
            ( current, focusChain candidates )

        Noop ->
            ( current, Cmd.none )


{-| Opens the dialog and moves focus into it. `opener` is the DOM id of the
element to give focus back to when the dialog closes, usually the button that
opened it. With `""`, or when that element is gone, focus goes back to the most
recent element of the page that had focus before the dialog opened and still
exists (it needs an id).

    Modal.open "edit-order-button" model.editDialog

-}
open : String -> State -> ( State, Cmd Msg )
open opener =
    openWith { opener = opener, focus = [] }


{-| Like `open`, with a list of element ids that should receive focus. The
first one that exists wins (if none does, the dialog itself gets focus), so a
form can ask for its first field:

    Modal.openWith { opener = "new-order-button", focus = [ "customer-name" ] } model.editDialog

Calling it on a dialog that is already open moves focus again and keeps the
first opener.

-}
openWith : { opener : String, focus : List String } -> State -> ( State, Cmd Msg )
openWith options (State state) =
    ( State
        { state
            | open = True
            , opener =
                if state.open then
                    state.opener

                else
                    options.opener
            , arrived = state.open && state.arrived
            , nudge = 0
        }
    , focusChain (options.focus ++ [ state.id ])
    )


{-| Closes the dialog and gives focus back to its opener (see `open`). Call it
from your own buttons and when the work is done; the close button, `Escape` and
the backdrop close the dialog through `update`.
-}
close : State -> ( State, Cmd Msg )
close (State state) =
    ( State { state | open = False }
    , if state.open then
        focusChain (List.filter ((/=) "") (state.opener :: state.trail) ++ [ Internal.pageStartId ])

      else
        Cmd.none
    )


{-| Try the ids in order and focus the first element that exists.
-}
focusChain : List String -> Cmd Msg
focusChain ids =
    case ids of
        [] ->
            Cmd.none

        first :: rest ->
            List.foldl
                (\id task -> Task.onError (\_ -> Dom.focus id) task)
                (Dom.focus first)
                rest
                |> Task.attempt (\_ -> Noop)


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


footerId : String -> String
footerId id =
    id ++ "-footer"


bodyId : String -> String
bodyId id =
    id ++ "-body"


bodyEndId : String -> String
bodyEndId id =
    id ++ "-end"



-- ATTRIBUTES


{-| A setting of a dialog. Make them with the functions below and pass a list to
`view`; later attributes win over earlier ones.
-}
type Attribute msg
    = Attribute (Config msg -> Config msg)


{-| The edge of the window that a dialog shown as a side panel (see `side`) is
attached to: `Right` or `Left`.
-}
type Side
    = Right
    | Left


type alias Config msg =
    { title : String
    , subtitle : Maybe String
    , size : Size
    , fullHeight : Bool
    , side : Maybe Side
    , static : Bool
    , busy : Bool
    , flush : Bool
    , hideClose : Bool
    , onRequestClose : Maybe msg
    , footer : List (Html msg)
    , footerStart : List (Html msg)
    , ariaDescribedBy : Maybe String
    , lastFocus : Maybe String
    , locale : Locale
    }


configure : List (Attribute msg) -> Config msg
configure attributes =
    List.foldl (\(Attribute change) config -> change config)
        { title = ""
        , subtitle = Nothing
        , size = Medium
        , fullHeight = False
        , side = Nothing
        , static = False
        , busy = False
        , flush = False
        , hideClose = False
        , onRequestClose = Nothing
        , footer = []
        , footerStart = []
        , ariaDescribedBy = Nothing
        , lastFocus = Nothing
        , locale = Locale.default
        }
        attributes


{-| The heading of the dialog. It is also the accessible name of the dialog, so
always set one.
-}
title : String -> Attribute msg
title value =
    Attribute (\config -> { config | title = value })


{-| A smaller line below the title, for context such as the order number.
-}
subtitle : String -> Attribute msg
subtitle value =
    Attribute (\config -> { config | subtitle = Just value })


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
shorthands. A dialog shown with `side` is 360, 480 or 720px wide instead.
-}
size : Size -> Attribute msg
size value =
    Attribute (\config -> { config | size = value })


{-| The dialog is as tall as the window (less a small margin) instead of only as
tall as its content. For long forms and lists.
-}
fullHeight : Attribute msg
fullHeight =
    Attribute (\config -> { config | fullHeight = True })


{-| Shows the dialog as a panel along one side of the window instead of a box in
the middle: as tall as the window and 360, 480 or 720px wide. Use
[Klar.Drawer](Klar-Drawer), which is this with the side set to `Right` by
default, rather than calling `side` yourself.
-}
side : Side -> Attribute msg
side value =
    Attribute (\config -> { config | side = Just value })


{-| A click on the backdrop and `Escape` do not close the dialog; the close
button still does. The dialog gives a small nudge instead, so that it does not
feel frozen. For forms with unsaved data.
-}
static : Attribute msg
static =
    Attribute (\config -> { config | static = True })


{-| While `True` nothing can close the dialog: the close button is disabled and
the backdrop and `Escape` are ignored. The dialog also announces `aria-busy`.
Pass a field of your model that is `True` while a request runs.
-}
busy : Bool -> Attribute msg
busy value =
    Attribute (\config -> { config | busy = value })


{-| Send this message instead of closing. The close button, `Escape` and the
backdrop then send `msg` and the dialog stays open; the application decides, and
calls `Modal.close` when it is fine to go (after asking "Discard changes?",
say). A `static` dialog sends `msg` only from its close button.
-}
onRequestClose : msg -> Attribute msg
onRequestClose msg =
    Attribute (\config -> { config | onRequestClose = Just msg })


{-| Content at the left end of the footer, opposite the actions: a note, a
checkbox, a "Delete order" link. Giving it also shows the footer.
-}
footerStart : List (Html msg) -> Attribute msg
footerStart value =
    Attribute (\config -> { config | footerStart = value })


{-| The actions, right aligned in a fixed footer at the bottom of the dialog. The
primary action goes last. The footer is only shown when `footer` or
`footerStart` is given.
-}
footer : List (Html msg) -> Attribute msg
footer value =
    Attribute (\config -> { config | footer = value })


{-| No padding around the body, for tables and lists that go edge to edge.
-}
flush : Attribute msg
flush =
    Attribute (\config -> { config | flush = True })


{-| Do not show the close button in the header. `Escape` and the backdrop still
close the dialog unless it is `static`, so give the user another way out, such
as a "Cancel" button in the footer.
-}
hideClose : Attribute msg
hideClose =
    Attribute (\config -> { config | hideClose = True })


{-| The id of an element inside the dialog that describes it (a paragraph of
explanation, say). Screen readers read it out after the title.
-}
ariaDescribedBy : String -> Attribute msg
ariaDescribedBy value =
    Attribute (\config -> { config | ariaDescribedBy = Just value })


{-| The id of the last button in the dialog. When the user presses `Shift+Tab`
on the first element, focus wraps around to this button instead of the footer.
-}
lastFocus : String -> Attribute msg
lastFocus value =
    Attribute (\config -> { config | lastFocus = Just value })


{-| The language of the built-in text, which is the label of the close button
("Close" by default). The default language is
[`Locale.default`](Klar-Locale#default), which is English.
-}
locale : Locale -> Attribute msg
locale value =
    Attribute (\config -> { config | locale = value })



-- VIEW


{-| The dialog, with `body` in its scrolling middle part. `toMsg` wraps the
messages of the dialog (see the example at the top of this page). Renders
nothing while the dialog is closed, so it can stay in your view all the time.
It returns an [`Overlay`](Klar-Overlay#Overlay): put it in the list of overlays
of [`Overlay.host`](Klar-Overlay#host) or `AppShell.overlays`.
-}
view : (Msg -> msg) -> List (Attribute msg) -> State -> List (Html msg) -> Overlay msg
view toMsg attributes ((State state) as current) body =
    let
        config =
            configure attributes

        hasFooter =
            not (List.isEmpty config.footer) || not (List.isEmpty config.footerStart)

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
        , render = \around -> viewDialog toMsg config current hasFooter firstTargets around body
        }


viewDialog :
    (Msg -> msg)
    -> Config msg
    -> State
    -> Bool
    -> List String
    -> { top : Bool, toastsFollow : Bool }
    -> List (Html msg)
    -> Html msg
viewDialog toMsg config (State state) hasFooter firstTargets around body =
    if not state.open then
        Html.text ""

    else
        let
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
                List.filterMap identity
                    [ config.lastFocus
                    , Just
                        (if hasFooter then
                            footerId state.id

                         else
                            bodyEndId state.id
                        )
                    , Just state.id
                    ]

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
                ([ Internal.cls [ "klar-modal__dialog", nudgeClass ]
                 , Attr.id state.id
                 , Attr.tabindex -1
                 , Attr.attribute "role" "dialog"
                 , Attr.attribute "aria-modal" "true"
                 , Attr.attribute "aria-labelledby" (titleId state.id)
                 , Internal.attrMaybe (Attr.attribute "aria-describedby") config.ariaDescribedBy
                 , Internal.attrIf config.busy (Attr.attribute "aria-busy" "true")
                 , Internal.attrIf (not state.arrived) (arrived toMsg)
                 ]
                    ++ [ dialogKeys state.id dismiss toMsg ]
                )
                [ viewHeader state.id config closeLabel requestClose
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
                                Html.div [ Attr.id (bodyEndId state.id), Attr.tabindex -1, Internal.cls [ "klar-modal__end" ] ] []
                           ]
                    )
                , viewFooter state.id config hasFooter
                , Internal.viewIf (state.arrived && around.top) (guard (toMsg Lost))
                ]
            , if around.toastsFollow then
                -- The toasts come next in the tab order and close the loop.
                Html.text ""

              else
                sentinel (toMsg (FocusFirst firstTargets))
            ]


viewHeader : String -> Config msg -> String -> msg -> Html msg
viewHeader id config closeLabel requestClose =
    -- A div, not a `header`: inside a dialog that element is no landmark, but two
    -- dialogs open at once would make axe count two banners.
    Html.div [ Internal.cls [ "klar-modal__header" ] ]
        [ Html.div [ Internal.cls [ "klar-modal__heading" ] ]
            [ Html.h2 [ Internal.cls [ "klar-modal__title" ], Attr.id (titleId id) ] [ Html.text config.title ]
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


viewFooter : String -> Config msg -> Bool -> Html msg
viewFooter id config hasFooter =
    if hasFooter then
        Html.div
            [ Internal.cls [ "klar-modal__footer" ]
            , Attr.id (footerId id)
            , Attr.tabindex -1
            ]
            [ if List.isEmpty config.footerStart then
                Html.text ""

              else
                Html.div [ Internal.cls [ "klar-modal__footer-start" ] ] config.footerStart
            , Html.div [ Internal.cls [ "klar-modal__footer-actions" ] ] config.footer
            ]

    else
        Html.text ""


{-| Focus entered the dialog for the first time. From then on the dialog watches
for focus that falls out of it (see `guard`).
-}
arrived : (Msg -> msg) -> Html.Attribute msg
arrived toMsg =
    Events.on "focusin" (Decode.succeed (toMsg Arrived))


{-| An invisible element that tells the dialog when focus is lost. The stylesheet
runs the animation `klar-focus-lost` on it while no part of any overlay contains
focus (the element that had it was removed or disabled, and the page fell back to
the body). That start is the only signal pure Elm can get: browsers send no event
when a focused element disappears.
-}
guard : msg -> Html msg
guard lost =
    Html.span
        [ Internal.cls [ "klar-modal__guard" ]
        , Attr.attribute "aria-hidden" "true"
        , Events.on "animationstart"
            (Decode.field "animationName" Decode.string
                |> Decode.andThen
                    (\name ->
                        if name == "klar-focus-lost" then
                            Decode.succeed lost

                        else
                            Decode.fail "another animation"
                    )
            )
        ]
        []


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



-- ESCAPE


{-| The keydown handler of the dialog (a node keeps only one).

`Escape` closes the dialog, unless it was pressed in a popup (a menu, a select
...) that is open inside the dialog; that popup handles it itself.

While the dialog element itself has focus, which it has when the dialog opens,
the keys that scroll a page scroll the body of the dialog: it is not focusable,
and without this a long text in a dialog could not be read with the keyboard.

-}
dialogKeys : String -> Maybe msg -> (Msg -> msg) -> Html.Attribute msg
dialogKeys dialogId dismiss toMsg =
    Events.preventDefaultOn "keydown"
        (Internal.keyEvent
            |> Decode.andThen
                (\event ->
                    if event.key == "Escape" then
                        case dismiss of
                            Just msg ->
                                Decode.field "target" (insidePopup dialogId 0)
                                    |> Decode.andThen
                                        (\nested ->
                                            if nested then
                                                Decode.fail "handled by a popup"

                                            else
                                                Decode.succeed ( msg, True )
                                        )

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


{-| Walk up from the event target to the dialog element. `True` if a popup
layer (`.klar-layer` or `.klar-popup`) lies on the way.
-}
insidePopup : String -> Int -> Decoder Bool
insidePopup dialogId depth =
    if depth > 60 then
        Decode.succeed False

    else
        Decode.oneOf
            [ Decode.field "id" Decode.string
                |> Decode.andThen
                    (\id ->
                        if id == dialogId then
                            Decode.succeed False

                        else
                            Decode.fail "keep climbing"
                    )
            , Decode.field "className" Decode.string
                |> Decode.andThen
                    (\names ->
                        let
                            tokens =
                                String.words names
                        in
                        if List.member "klar-layer" tokens || List.member "klar-popup" tokens then
                            Decode.succeed True

                        else
                            Decode.fail "keep climbing"
                    )
            , Decode.field "parentElement" (Decode.lazy (\_ -> insidePopup dialogId (depth + 1)))
            , Decode.succeed False
            ]
