module Klar.Toolbar exposing
    ( view
    , group, groupLabelled, label, separator, spacer
    , Attribute, ariaLabel, small, large, plain, scroll
    )

{-| A horizontal bar of grouped actions: the strip above a table, the actions of
an editor, or the bulk actions that appear when rows are selected.

    import Klar.Button as Button
    import Klar.Icon as Icon
    import Klar.TextInput as TextInput
    import Klar.Toolbar as Toolbar

    Toolbar.view [ Toolbar.ariaLabel "Orders" ]
        [ Toolbar.group
            [ Button.view [ Button.primary, Button.icon Icon.plus ] "New order"
            , Button.view [ Button.icon Icon.download ] "Export"
            ]
        , Toolbar.separator
        , Toolbar.label "3 selected"
        , Toolbar.groupLabelled "Selection"
            [ Button.view [ Button.ghost, Button.icon Icon.trash ] "Delete" ]
        , Toolbar.spacer
        , TextInput.view
            [ TextInput.search
            , TextInput.label "Search orders"
            , TextInput.labelHidden
            , TextInput.value model.query
            , TextInput.onInput QueryChanged
            ]
        ]

The bar lays out whatever buttons, inputs and menus you give it in a row, and
keeps no state. It wraps onto a second line when there is no room; `scroll` keeps
one line and scrolls sideways instead. The size (`small`, `large`) sets the
height of every control inside the bar, so plain buttons and inputs line up
without extra work (a control with a size of its own keeps it). A text input
placed straight into the bar, or into a group, is 240px wide and can shrink to
140px.

The bar is a `group` of controls (`role="group"`), not an ARIA `toolbar`: it does
not manage focus, so every control is reached with Tab, in order, and the arrow
keys are not used, which is what a `toolbar` would promise to assistive
technology. Name the bar with `ariaLabel`, especially when a page has more than
one.


# View

@docs view


# Content

@docs group, groupLabelled, label, separator, spacer


# Attributes

@docs Attribute, ariaLabel, small, large, plain, scroll

-}

import Html exposing (Html)
import Html.Attributes as Attr
import Klar.Internal as Internal


{-| A setting of the bar. Make them with the functions below and pass a list to
`view`; later attributes win over earlier ones. A toolbar sends no messages, so
the type has no `msg` parameter.
-}
type Attribute
    = Attribute (Config -> Config)


type Size
    = Small
    | Medium
    | Large


type alias Config =
    { ariaLabel : Maybe String
    , size : Size
    , plain : Bool
    , scroll : Bool
    }


configure : List Attribute -> Config
configure attributes =
    List.foldl (\(Attribute change) config -> change config)
        { ariaLabel = Nothing
        , size = Medium
        , plain = False
        , scroll = False
        }
        attributes


{-| The accessible name of the bar (`aria-label`): what the group of controls is
for, for example "Orders". There is no default; without it the bar has no name.
-}
ariaLabel : String -> Attribute
ariaLabel value =
    Attribute (\config -> { config | ariaLabel = Just value })


{-| A compact bar: 26px controls instead of the usual 32px, and less padding.
Buttons and inputs inside the bar follow, unless they have a size of their own.
-}
small : Attribute
small =
    Attribute (\config -> { config | size = Small })


{-| A roomy bar: 40px controls and more padding. Buttons and inputs inside the
bar follow, unless they have a size of their own.
-}
large : Attribute
large =
    Attribute (\config -> { config | size = Large })


{-| No border, no background and no padding, for a toolbar that sits inside
another surface such as a card header.
-}
plain : Attribute
plain =
    Attribute (\config -> { config | plain = True })


{-| Keeps every control on one line and scrolls the bar sideways when they do not
fit, instead of wrapping onto more lines.
-}
scroll : Attribute
scroll =
    Attribute (\config -> { config | scroll = True })


{-| The bar. The children are buttons, inputs, menus and the helpers below
(`group`, `separator`, `spacer`, `label`), laid out in a row in the order given.
-}
view : List Attribute -> List (Html msg) -> Html msg
view attributes children =
    let
        config =
            configure attributes
    in
    Html.div
        [ Internal.cls
            [ "klar-toolbar"
            , case config.size of
                Small ->
                    "klar-toolbar--sm"

                Medium ->
                    ""

                Large ->
                    "klar-toolbar--lg"
            , if config.plain then
                "klar-toolbar--plain"

              else
                ""
            , if config.scroll then
                "klar-toolbar--scroll"

              else
                ""
            ]
        , Attr.attribute "role" "group"
        , Internal.attrMaybe (Attr.attribute "aria-label") config.ariaLabel
        ]
        children


{-| Controls that belong together. They sit close to each other and, when the
bar wraps, move to the next line as one block. Use `groupLabelled` when the group
needs a name for screen readers.
-}
group : List (Html msg) -> Html msg
group children =
    Html.div [ Internal.cls [ "klar-toolbar__group" ] ] children


{-| Like `group`, but the group is announced as a named group (`role="group"`)
by screen readers. The name is not shown.

    Toolbar.groupLabelled "Layout"
        [ Button.iconOnly [ Button.ghost ] Icon.list "List"
        , Button.iconOnly [ Button.ghost ] Icon.grid "Grid"
        ]

-}
groupLabelled : String -> List (Html msg) -> Html msg
groupLabelled name children =
    Html.div
        [ Internal.cls [ "klar-toolbar__group" ]
        , Attr.attribute "role" "group"
        , Attr.attribute "aria-label" name
        ]
        children


{-| A thin vertical line between groups (`role="separator"`).
-}
separator : Html msg
separator =
    Html.span [ Internal.cls [ "klar-toolbar__separator" ], Attr.attribute "role" "separator", Attr.attribute "aria-orientation" "vertical" ] []


{-| Flexible empty space that takes up the room left over on its line, so that
everything after it moves to the far end of the bar.
-}
spacer : Html msg
spacer =
    Html.span [ Internal.cls [ "klar-toolbar__spacer" ] ] []


{-| Quiet gray text inside the bar, such as a count or a status.

    Toolbar.label "3 selected"

-}
label : String -> Html msg
label content =
    Html.span [ Internal.cls [ "klar-toolbar__label" ] ] [ Html.text content ]
