module Klar.Overlay exposing (Overlay, host, map)

{-| The layer above the page: dialogs, drawers, the command palette, the shortcut
sheet and the toasts.

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
    row the user came from without being told.
  - **The toasts stay reachable.** While a dialog is open they move to the top of
    the window (they never cover the footer buttons) and are the last stop of the
    `Tab` loop of the dialog: after the footer, `Tab` goes through the buttons of
    the toasts and then back to the first element of the dialog.

The order of the list is the stacking order: put a dialog that another one opens
after it, and the toasts anywhere.


# Page and overlays

@docs Overlay, host, map

-}

import Html exposing (Html)
import Html.Attributes as Attr
import Klar.Internal as Internal
import Klar.Internal.Overlay as Overlay


{-| A dialog, drawer, palette or stack of toasts, ready to be placed in the list
of overlays of a page. You get one from the `view` of the component and cannot
make or take one apart yourself.
-}
type alias Overlay msg =
    Overlay.Overlay msg


{-| Turns the messages of an overlay into the messages of the page around it, as
`Html.map` does: a page module of your own that has dialogs hands them to the
main module with `List.map (Overlay.map PageMsg)`.
-}
map : (a -> b) -> Overlay a -> Overlay b
map =
    Overlay.map


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
        layer =
            Overlay.layer options.overlays
    in
    Html.div
        ([ Internal.cls [ "klar-overlay-host" ], Attr.tabindex -1 ] ++ options.attributes)
        (layer.watch
            (Html.div
                [ Internal.cls [ "klar-overlay-host__page" ]
                , Internal.attrIf layer.blocked (Attr.attribute "inert" "")
                ]
                options.page
                :: layer.overlays
            )
        )
