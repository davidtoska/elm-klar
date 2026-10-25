module Klar.Modal.Config exposing
    ( Attribute(..), Config, configure
    , Side(..), Role(..)
    )

{-| The settings of a dialog, shared by [Klar.Modal](Klar-Modal),
[Klar.Drawer](Klar-Drawer) and [Klar.ConfirmDialog](Klar-ConfirmDialog). Not
exposed: `Modal.Attribute` is an alias of `Attribute`, so the three modules build
the same settings, and only this package can set the ones that are not public (the
side of a drawer, the role of a confirmation).

@docs Attribute, Config, configure
@docs Side, Role

-}

import Html exposing (Html)
import Klar.Locale as Locale exposing (Locale)
import Klar.Theme exposing (Size(..))


{-| A setting of a dialog: a change of its `Config`.
-}
type Attribute msg
    = Attribute (Config msg -> Config msg)


{-| The edge of the window a drawer is attached to.
-}
type Side
    = Right
    | Left


{-| What the dialog is to assistive technology: a `dialog`, or an `alertdialog` (a
question that interrupts the user, whose description screen readers read at once).
-}
type Role
    = Dialog
    | AlertDialog


{-| Everything a dialog can be told.
-}
type alias Config msg =
    { subtitle : Maybe String
    , size : Size
    , fullHeight : Bool

    -- `edge` is what `Drawer.left` and `Drawer.right` choose; `side` is the edge
    -- the dialog is drawn along. Only `Drawer.view` sets `side` (from `edge`), so
    -- `Modal.view` with the attributes of a drawer still draws a centered dialog.
    , edge : Side
    , side : Maybe Side
    , role : Role
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


{-| The settings, the later ones winning over the earlier ones.
-}
configure : List (Attribute msg) -> Config msg
configure attributes =
    List.foldl (\(Attribute change) config -> change config)
        { subtitle = Nothing
        , size = Medium
        , fullHeight = False
        , edge = Right
        , side = Nothing
        , role = Dialog
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
