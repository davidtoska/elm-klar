module Klar.Overlay exposing
    ( Overlay, host, map
    , dialog, toasts, layer
    )

{-| The layer above the page: dialogs, drawers, the command palette, the shortcut
sheet and the toasts.

Use when: you put dialogs, drawers, toasts or the command palette on the page (one `host` for all of them).
Do not use when: you need a menu or a tooltip next to an element (as `Klar.Menu` or `Klar.Tooltip`).

Every component of that kind ([Klar.Modal](Klar-Modal), [Klar.Drawer](Klar-Drawer),
[Klar.ConfirmDialog](Klar-ConfirmDialog), [Klar.CommandPalette](Klar-CommandPalette),
[Klar.ShortcutHelp](Klar-ShortcutHelp), [Klar.Toast](Klar-Toast)) has a `view` that
returns an `Overlay`, not plain `Html`. You give the page the list of them and it
does the rest:

    Overlay.host
        { attributes = []
        , page = [ viewOrders model ]
        , overlays =
            [ Modal.view EditDialogMsg [ Modal.title "Edit order" ] model.editDialog [ orderForm ]
            , Drawer.view OrderDrawerMsg [ Drawer.title "Order 1042" ] model.orderDrawer [ details ]
            , ConfirmDialog.view CancelDialogMsg [ ConfirmDialog.title "Cancel order?" ] model.cancelDialog
            , Toast.view ToastMsg [] model.toasts
            ]
        }

An application built on [Klar.AppShell](Klar-AppShell) gives the same list to
`AppShell.overlays` and does not use `host`.

Because an overlay cannot be drawn in any other way, the application cannot
forget one:

  - **The page behind is inert** (no keyboard, no screen reader, no clicks) as soon
    as any dialog in the list is open. There is no flag to compute.
  - **The last open dialog in the list is on top.** Only it watches the keyboard
    focus: when the element that has focus is removed or disabled (a button that
    makes way for "Saving ...", say) focus moves to the dialog itself, so that
    `Escape` and `Tab` keep working. The application never calls anything for that.
  - **Focus goes back to where it was.** Every dialog that is closed remembers the
    last elements that had focus on the page. When the dialog closes, focus goes to
    its opener, or else to the most recent of those that still exist. A drawer
    opened by a route change, or by a command from the palette, returns focus to the
    row the user came from without being told. When nothing is known (the
    shortcut was pressed with focus on `body`), focus goes to the start of the page
    content, so the next `Tab` does not start at the top of the window.
  - **The toasts stay reachable.** While a dialog is open they move to the top of
    the window, or to the bottom of the side that a drawer leaves free (they never
    cover the footer buttons, the title or the close button), and are the last stop of the
    `Tab` loop of the dialog: after the footer, `Tab` goes through the buttons of
    the toasts and then back to the first element of the dialog.

Keep every overlay in the list all the time, also while it is closed (a closed
dialog draws nothing, but it is the one that remembers where focus was). The order
of the list is the stacking order: put a dialog that another one opens after it,
and the toasts anywhere; they are always drawn last.


# Page and overlays

@docs Overlay, host, map


# Making your own overlay

The components of this package build their overlays with these; so can you, for a
lightbox or a wizard that is not a `Modal`. A page that is not built with `host`
or `AppShell` takes the same steps with `layer`.

@docs dialog, toasts, layer

-}

import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Events
import Json.Decode as Decode
import Klar.Internal as Internal


{-| A dialog, drawer, palette or stack of toasts, ready to be placed in the list
of overlays of a page. You get one from the `view` of the component.
-}
type Overlay msg
    = Overlay (Data msg)


type alias Data msg =
    { kind : Kind
    , open : Bool

    -- Dialogs: where the first `Tab` past the last element lands (the chain of
    -- ids to try), or `Nothing` when the overlay keeps its own focus (the palette).
    , entry : Maybe (List String)

    -- A closed dialog listens to the focus on the page, to know what to give
    -- focus back to when it opens and closes later.
    , watch : Maybe (String -> msg)
    , render : Around -> Html msg
    }


type Kind
    = Dialog
    | Toasts


{-| What an overlay is told about the others when it is drawn.
-}
type alias Around =
    { -- The dialog on top of all open ones.
      top : Bool

    -- Dialogs: there is a toast stack that closes the tab loop.
    , toastsFollow : Bool

    -- Toasts: the entry of the dialog on top, if one is open.
    , trap : Maybe (List String)
    }


{-| An overlay that takes over the page while it is open.

  - `open`: is it open? The page is `inert` while any dialog of the list is.
  - `entry`: the ids to try, in order, to give focus to the first element of the
    dialog (the toasts send focus there when `Tab` leaves them). `Nothing` for a
    dialog that keeps focus to itself, like the command palette.
  - `watch`: while the dialog is closed, a message for the id of every element of the
    page that gets focus. Keep the last few ids and, when the dialog closes, give
    focus to the first that still exists. `Nothing` while it is open.
  - `render`: the dialog, told whether it is `top` (the last open one of the list:
    only that one watches for focus that is lost) and whether `toastsFollow` (a
    stack of toasts comes after the dialogs, so the dialog must not close the loop
    of `Tab` stops itself).

-}
dialog :
    { open : Bool
    , entry : Maybe (List String)
    , watch : Maybe (String -> msg)
    , render : { top : Bool, toastsFollow : Bool } -> Html msg
    }
    -> Overlay msg
dialog options =
    Overlay
        { kind = Dialog
        , open = options.open
        , entry = options.entry
        , watch = options.watch
        , render = \around -> options.render { top = around.top, toastsFollow = around.toastsFollow }
        }


{-| The stack of toasts. `trap` is the `entry` of the dialog that is open on top, if
there is one: the stack is then the last stop of its `Tab` loop and sends focus
back to it.
-}
toasts : { render : { trap : Maybe (List String) } -> Html msg } -> Overlay msg
toasts options =
    Overlay
        { kind = Toasts
        , open = False
        , entry = Nothing
        , watch = Nothing
        , render = \around -> options.render { trap = around.trap }
        }


{-| Turns the messages of an overlay into the messages of the page around it, as
`Html.map` does: a page module of your own that has dialogs hands them to the
main module with `List.map (Overlay.map PageMsg)`.
-}
map : (a -> b) -> Overlay a -> Overlay b
map change (Overlay data) =
    Overlay
        { kind = data.kind
        , open = data.open
        , entry = data.entry
        , watch = Maybe.map (\toMsg id -> change (toMsg id)) data.watch
        , render = \around -> Html.map change (data.render around)
        }


{-| What a page needs from its overlays, for a page that is not made with `host`:

  - `blocked`: some dialog is open, so make the page `inert`.
  - `overlays`: the overlays, drawn, to be placed beside the page.
  - `watch`: wraps the page and the overlays (they must be in one list, in the same
    place every time) so that closed dialogs hear where focus is.

-}
layer :
    List (Overlay msg)
    ->
        { blocked : Bool
        , overlays : List (Html msg)
        , watch : List (Html msg) -> List (Html msg)
        }
layer overlays =
    let
        dialogs =
            List.filter (\(Overlay data) -> data.kind == Dialog) overlays

        stacks =
            List.filter (\(Overlay data) -> data.kind == Toasts) overlays

        openDialogs =
            List.filter (\(Overlay data) -> data.open) dialogs

        topIndex =
            List.indexedMap Tuple.pair dialogs
                |> List.filter (\( _, Overlay data ) -> data.open)
                |> List.reverse
                |> List.head
                |> Maybe.map Tuple.first

        topDialog =
            List.reverse openDialogs |> List.head

        hasToasts =
            not (List.isEmpty stacks)

        around isTop =
            { top = isTop
            , toastsFollow = hasToasts
            , trap = Maybe.andThen (\(Overlay data) -> data.entry) topDialog
            }

        -- One wrapper for every dialog, open or not, so that the page keeps its
        -- place in the DOM when a dialog opens; only a closed one listens.
        watchers =
            List.map (\(Overlay data) -> data.watch) dialogs
    in
    { blocked = not (List.isEmpty openDialogs)
    , overlays =
        List.indexedMap (\index (Overlay data) -> data.render (around (Just index == topIndex))) dialogs
            -- toasts last, so that they come after the dialogs in the tab order
            ++ List.map (\(Overlay data) -> data.render (around False)) stacks
    , watch = \children -> List.foldl wrapWatcher children watchers
    }


wrapWatcher : Maybe (String -> msg) -> List (Html msg) -> List (Html msg)
wrapWatcher watch children =
    [ Html.div
        [ Internal.cls [ "klar-contents" ]
        , Internal.attrMaybe
            (\toMsg ->
                Events.on "focusin"
                    (Decode.at [ "target", "id" ] Decode.string
                        |> Decode.andThen
                            (\id ->
                                if id == "" then
                                    Decode.fail "nothing to remember"

                                else
                                    Decode.succeed (toMsg id)
                            )
                    )
            )
            watch
        ]
        children
    ]


{-| The root of a page that uses overlays. The `page` is `inert` while any of the
`overlays` is open; the overlays are drawn beside it, so they stay usable.

`attributes` go on the root element, which can receive focus (`tabindex` -1) so
that [Klar.Shortcut](Klar-Shortcut) hears key presses that start there:
`[ Shortcut.listen ShortcutMsg shortcuts model.shortcuts ]`.

-}
host :
    { attributes : List (Html.Attribute msg)
    , page : List (Html msg)
    , overlays : List (Overlay msg)
    }
    -> Html msg
host options =
    let
        around =
            layer options.overlays
    in
    Html.div
        ([ Internal.cls [ "klar-overlay-host" ], Attr.tabindex -1 ] ++ options.attributes)
        (around.watch
            (Html.div
                [ Internal.cls [ "klar-overlay-host__page" ]
                , Attr.id Internal.pageStartId
                , Attr.tabindex -1
                , Internal.attrIf around.blocked (Attr.attribute "inert" "")
                ]
                options.page
                :: around.overlays
            )
        )
