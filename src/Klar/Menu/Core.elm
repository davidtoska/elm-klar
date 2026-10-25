module Klar.Menu.Core exposing (Highlight(..), MenuMsg(..), MenuState(..), openWith, popupId, triggerIdOf)

{-| The state and the messages of `Klar.Menu`, kept here so that
`Klar.ContextMenu` can open a menu with nothing highlighted after a right-click
(`openWith NoItem`), as a native context menu opens, while the keyboard opens it
at the first item.

Not meant for application code: `Klar.Menu.State` and `Klar.Menu.Msg` are these
types.

-}

import Klar.Internal as Internal
import Klar.Menu.Scroll as Scroll


{-| The state of one menu (see `Klar.Menu.State`).
-}
type MenuState
    = MenuState
        { id : String
        , open : Bool
        , highlight : Highlight
        , typed : String
        , typedAt : Int
        }


{-| Which item is highlighted. The first and the last item are found when the
items are known (in `view`, or in a message made by it), so that a menu can be
opened at the first item without knowing the items.
-}
type Highlight
    = NoItem
    | FirstItem
    | LastItem
    | Index Int


{-| The messages of the menu (see `Klar.Menu.Msg`).
-}
type MenuMsg
    = Toggle Highlight
    | OpenWith Highlight
    | Close
    | CloseQuiet
    | Hover Int
    | Step Int (List Int)
    | Jump Int (List Int)
    | Type String (List ( Int, String ))
    | TypedTimeout Int
    | Noop


{-| Opens the menu with this highlight and moves keyboard focus into it.
-}
openWith : Highlight -> MenuState -> ( MenuState, Cmd MenuMsg )
openWith target (MenuState state) =
    ( MenuState { state | open = True, highlight = target, typed = "" }
    , Cmd.batch
        [ Internal.focus (popupId state.id) Noop

        -- The last item of a long menu is at the bottom of the list.
        , if target == LastItem then
            Scroll.reveal { list = popupId state.id, item = "", edge = Scroll.Bottom } Noop

          else
            Cmd.none
        ]
    )


{-| The id of the button that opens the menu.
-}
triggerIdOf : String -> String
triggerIdOf id =
    id ++ "-trigger"


{-| The id of the open menu.
-}
popupId : String -> String
popupId id =
    id ++ "-popup"
