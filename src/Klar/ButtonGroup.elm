module Klar.ButtonGroup exposing
    ( view
    , Attribute, size, disabled
    )

{-| Buttons that belong together, joined into one block: shared borders, only the
outer corners rounded, and one focus ring per button that always stays in view.

    import Klar.Button as Button
    import Klar.ButtonGroup as ButtonGroup
    import Klar.Icon as Icon

    ButtonGroup.view [] "Order actions"
        [ Button.view [ Button.icon Icon.edit, Button.onClick Edit ] "Edit"
        , Button.view [ Button.icon Icon.copy, Button.onClick Duplicate ] "Duplicate"
        , Button.iconOnly [ Button.onClick Print ] Icon.print "Print"
        ]

The children are ordinary [Klar.Button](Klar-Button) buttons (a button with an
`href` too, and the button of a [Klar.Menu](Klar-Menu) as the last one), so
everything a button can do still works. Each one is a separate button, reached with
Tab and activated with Enter or Space. The group is named by its first argument
(`role="group"` with that `aria-label`), because screen readers announce it when
the focus enters it.

Use it for actions that are close in meaning and that you want to read as one
control, such as "Edit / Duplicate / Print". For a choice between views use
[Klar.SegmentedControl](Klar-SegmentedControl), for options that are on or off
use [Klar.ToggleGroup](Klar-ToggleGroup), and for a main action with a few
alternatives [Klar.SplitButton](Klar-SplitButton). In a
[Klar.Toolbar](Klar-Toolbar) the group takes the size of the bar, like a button.

The group never wraps. It is a `fieldset`, so `disabled` turns off every button in
it at once, and the buttons keep the size they have (`size` sets it for the
buttons that have none of their own). A button with an `href` is a link, which
`disabled` cannot switch off: it is dimmed and cannot be clicked, but the keyboard
can still follow it.


# View

@docs view


# Attributes

@docs Attribute, size, disabled

-}

import Html exposing (Html)
import Html.Attributes as Attr
import Klar.Internal as Internal
import Klar.Theme as Theme exposing (Size(..))


{-| A setting of the group. Make them with `size` and `disabled` and pass a list
to `view`; later attributes win over earlier ones. A group sends no messages, so
the type has no `msg` parameter.
-}
type Attribute
    = Attribute (Config -> Config)


type alias Config =
    { size : Size
    , disabled : Bool
    }


configure : List Attribute -> Config
configure attributes =
    List.foldl (\(Attribute change) config -> change config)
        { size = Medium, disabled = False }
        attributes


{-| The size of the buttons that have none of their own: `Small`, `Medium` (the
default) or `Large` (see [Klar.Theme](Klar-Theme)). A button made with `Button.small`
or `Button.large` keeps its size.
-}
size : Size -> Attribute
size value =
    Attribute (\config -> { config | size = value })


{-| Turns off every button in the group (`fieldset` with `disabled`): they are
dimmed, cannot be clicked and are skipped by Tab. The default is `False`. Pass a
value from your model.
-}
disabled : Bool -> Attribute
disabled value =
    Attribute (\config -> { config | disabled = value })


{-| The group: its accessible name, then the buttons. The name is not shown; put a
visible label next to the group yourself if the page needs one.

    ButtonGroup.view [ ButtonGroup.size Small ] "Text alignment" [ left, center, right ]

-}
view : List Attribute -> String -> List (Html msg) -> Html msg
view attributes name children =
    let
        config =
            configure attributes
    in
    Html.fieldset
        [ Internal.cls
            [ "klar-btn-group"

            -- a medium group changes nothing, so a toolbar's size still reaches the buttons
            , if config.size == Medium then
                ""

              else
                "klar-btn-group--" ++ Theme.sizeSuffix config.size
            , if config.disabled then
                "klar-btn-group--disabled"

              else
                ""
            ]
        , Attr.attribute "role" "group"
        , Attr.attribute "aria-label" name
        , Attr.disabled config.disabled
        ]
        children
