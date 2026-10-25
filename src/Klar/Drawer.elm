module Klar.Drawer exposing
    ( view
    , State, Msg, init, setInitialFocus, update, isOpen
    , open, close, closeButtonId
    , Attribute, subtitle, footer, footerStart, flush, hideClose, ariaDescribedBy
    , small, medium, large, right, left
    , static, busy, onRequestClose
    , lastFocus
    , locale
    )

{-| A panel that slides in from the side of the window: the details of a row in
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

A drawer is a [Klar.Modal](Klar-Modal) shown along the right or left edge of
the window. It has the same state and the same attributes, and it behaves the
same way: focus moves in when it opens, `Tab` stays inside, focus returns to
the opener when it closes, and `Escape`, a click on the backdrop and the close
button close it unless it is `static` or `busy`. The page behind an open drawer
cannot be scrolled, and the [`Overlay`](Klar-Overlay#Overlay) that `view` returns
makes it `inert`. If the element that has focus inside the drawer is removed or
disabled (a button replaced after an action), focus moves to the drawer itself.
[Klar.Modal](Klar-Modal) and [Klar.Overlay](Klar-Overlay) explain all of this once,
for every overlay.

The details of a row usually load after the drawer opens. Give it the body of
[Klar.RemoteView](Klar-RemoteView): a skeleton that screen readers hear, the
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


# View

@docs view


# State

@docs State, Msg, init, setInitialFocus, update, isOpen


# Opening and closing

@docs open, close, closeButtonId


# Content

@docs Attribute, subtitle, footer, footerStart, flush, hideClose, ariaDescribedBy


# Size and side

@docs small, medium, large, right, left


# Dismissing

@docs static, busy, onRequestClose


# Keyboard focus

@docs lastFocus


# Texts

@docs locale

-}

import Html exposing (Html)
import Klar.Locale exposing (Locale)
import Klar.Modal as Modal
import Klar.Modal.Config as Config exposing (Side(..))
import Klar.Overlay exposing (Overlay)


{-| The state of one drawer: whether it is open and where focus returns to.
Create it with `init`, keep it in your model and change it with `open`,
`close` and `update`. It is the same type as `Klar.Modal.State`.
-}
type alias State =
    Modal.State


{-| The messages of a drawer (focus movements and the request to close). Wrap
it in a constructor of your own message type, such as `DrawerMsg Drawer.Msg`,
and hand it to `update`.
-}
type alias Msg =
    Modal.Msg


{-| A setting of a drawer. Make them with the functions below and pass a list
to `view`; later attributes win over earlier ones. It is the same type as
`Klar.Modal.Attribute`.
-}
type alias Attribute msg =
    Modal.Attribute msg


{-| A closed drawer. The `String` is the DOM id of the drawer and must be
unique on the page.
-}
init : String -> State
init =
    Modal.init


{-| Is the drawer open? The page is made inert by the overlay `view` returns; this
is for your own logic.
-}
isOpen : State -> Bool
isOpen =
    Modal.isOpen


{-| The ids of elements inside the drawer that get focus when it opens, the first
one that exists (a search field, the first field of a form). Without it (the
default) the drawer itself gets focus, and a screen reader reads its title. Set it
when you create the state:

    Drawer.init "filters-drawer" |> Drawer.setInitialFocus [ "customer-search" ]

When the place depends on the row that is opened, set it right before `open`:

    Drawer.open "order-1042-row" (Drawer.setInitialFocus [ "order-note" ] model.drawer)

-}
setInitialFocus : List String -> State -> State
setInitialFocus =
    Modal.setInitialFocus


{-| Opens the drawer and moves focus into it: to the first element of
`setInitialFocus` that exists, or else to the drawer itself. `opener` is the DOM
id of the element to give focus back to when the drawer closes, such as the button
or the table row that opened it. With `""`, or when that element is gone, focus
goes back to the most recent element of the page that had focus before the drawer
opened and still exists (it needs an id). A drawer opened by a route change needs
no opener.
-}
open : String -> State -> ( State, Cmd Msg )
open =
    Modal.open


{-| Closes the drawer and gives focus back to its opener. Call it from your own
buttons (a "Close" button in the footer, say) and when the work is done. The
built-in close button, `Escape` and the backdrop close the drawer through
`update`.
-}
close : State -> ( State, Cmd Msg )
close =
    Modal.close


{-| The DOM id of the close button in the header, for use as the `opener` of a
dialog that you open from the drawer (a "Discard changes?" question asked from
`onRequestClose`, say), so that focus comes back to the close button. There is
no such button with `hideClose`.
-}
closeButtonId : State -> String
closeButtonId =
    Modal.closeButtonId


{-| Handles the focus movements and the request to close the drawer (from the
close button, `Escape` or the backdrop). Map its command into your own message.
-}
update : Msg -> State -> ( State, Cmd Msg )
update =
    Modal.update


{-| The drawer titled `title`, with `body` in its scrolling middle; it comes in
from the right unless you say `left`. The title is the heading of the drawer and
its accessible name. `toMsg` wraps the messages of the drawer. Renders nothing
while closed, so it can stay in your view all the time. It returns an
[`Overlay`](Klar-Overlay#Overlay): put it in the list of overlays of
[`Overlay.host`](Klar-Overlay#host) or `AppShell.overlays`.
-}
view : (Msg -> msg) -> List (Attribute msg) -> State -> String -> List (Html msg) -> Overlay msg
view toMsg attributes =
    -- Only here does a dialog go to the side: `Modal.view` ignores `left` and `right`.
    Modal.view toMsg (attributes ++ [ Config.Attribute (\config -> { config | side = Just config.edge }) ])


{-| A smaller line below the title, for context such as the date of the last
change.
-}
subtitle : String -> Attribute msg
subtitle =
    Modal.subtitle


{-| 360px wide.
-}
small : Attribute msg
small =
    Modal.small


{-| 480px wide. This is the default.
-}
medium : Attribute msg
medium =
    Modal.medium


{-| 720px wide.
-}
large : Attribute msg
large =
    Modal.large


{-| Slide in from the right edge. This is the default. Only `Drawer.view` reads
it: `Modal.view` draws a centered dialog whatever you pass.
-}
right : Attribute msg
right =
    Config.Attribute (\config -> { config | edge = Right })


{-| Slide in from the left edge. Only `Drawer.view` reads it: `Modal.view` draws a
centered dialog whatever you pass.
-}
left : Attribute msg
left =
    Config.Attribute (\config -> { config | edge = Left })


{-| A click on the backdrop and `Escape` do not close the drawer; the close
button still does. Use it for a drawer with a form, so that unsaved input is not
lost by a stray click. The drawer gives a small nudge instead, so that it does
not feel frozen.
-}
static : Attribute msg
static =
    Modal.static


{-| While `True` nothing can close the drawer: the close button is disabled and
the backdrop and `Escape` are ignored. Pass a field of your model that is `True`
while a request runs.
-}
busy : Bool -> Attribute msg
busy =
    Modal.busy


{-| Send this message instead of closing. The close button, `Escape` and the
backdrop then send `msg` and the drawer stays open; the application decides,
and calls `close` when it is fine to go (after asking "Discard changes?", say).
-}
onRequestClose : msg -> Attribute msg
onRequestClose =
    Modal.onRequestClose


{-| The actions, right aligned in a fixed footer at the bottom of the drawer. The
primary action goes last. The footer is only shown when `footer` or
`footerStart` is given.
-}
footer : List (Html msg) -> Attribute msg
footer =
    Modal.footer


{-| Content at the left end of the footer, opposite the actions: a note, a
checkbox, a "Delete order" link.
-}
footerStart : List (Html msg) -> Attribute msg
footerStart =
    Modal.footerStart


{-| No padding around the body, for tables and lists that go edge to edge.
-}
flush : Attribute msg
flush =
    Modal.flush


{-| Do not show the close button in the header. `Escape` and the backdrop still
close the drawer unless it is `static`, so give the user another way out, such
as a "Close" button in the footer.
-}
hideClose : Attribute msg
hideClose =
    Modal.hideClose


{-| The id of an element inside the drawer that describes it, such as a
paragraph of explanation. Screen readers read it out after the title.
-}
ariaDescribedBy : String -> Attribute msg
ariaDescribedBy =
    Modal.ariaDescribedBy


{-| The id of the element that `Shift+Tab` on the first element of the drawer
wraps around to, usually the primary button. Without it focus lands at the end of
the footer (or of the body when there is no footer), and the next `Shift+Tab`
reaches the last button.
-}
lastFocus : String -> Attribute msg
lastFocus =
    Modal.lastFocus


{-| The language of the built-in text, which is the label of the close button
("Close" by default). The default language is
[`Locale.default`](Klar-Locale#default), which is English.
-}
locale : Locale -> Attribute msg
locale =
    Modal.locale
