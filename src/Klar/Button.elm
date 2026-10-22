module Klar.Button exposing
    ( view, iconOnly, group
    , Attribute, primary, secondary, ghost, link, danger, small, large, size, block
    , icon, iconRight, loading
    , onClick, submit, href, newTab, disabled, ariaDisabled
    , id, title, ariaLabel, pressed, expanded, htmlAttrs
    )

{-| Buttons and button-looking links.

Use when: the user must trigger an action, or follow a link that should look like a button.
Do not use when: you need a plain link in running text (as `Klar.Link`) or a choice between options (as `Klar.SegmentedControl`).

    import Klar.Button as Button
    import Klar.Icon as Icon

    Button.view [ Button.primary, Button.onClick SaveOrder ] "Save order"

    Button.view [ Button.danger, Button.icon Icon.trash, Button.loading model.deleting ] "Delete"

    Button.iconOnly [ Button.ghost, Button.onClick Reload ] Icon.refresh "Reload"

    Button.view [ Button.href "#/orders" ] "Open orders"

There are four looks: `primary` (the one main action on a page), `secondary`
(the default), `ghost` (quiet, for toolbars and table rows) and `link` (looks
like a link). A button with `href` is rendered as an anchor, so it can be opened
in a new tab, but it keeps the look of the other buttons.

`danger` marks a destructive action. On its own (or with `primary`) it is the
solid red button. Combined with `secondary`, `ghost` or `link` it keeps that
look and only changes the tone: red text and, for `secondary`, a red border. The
order of the attributes does not matter.

    Button.view [ Button.danger ] "Delete" -- solid red

    Button.view [ Button.ghost, Button.danger ] "Delete" -- quiet, red text

    Button.view [ Button.secondary, Button.danger ] "Delete" -- white, red text and border

A button that is `loading` or `disabled` does not send its message and never
submits a form.


# Views

@docs view, iconOnly, group


# Look and size

@docs Attribute, primary, secondary, ghost, link, danger, small, large, size, block


# Content

@docs icon, iconRight, loading


# Behavior

@docs onClick, submit, href, newTab, disabled, ariaDisabled


# Accessibility and HTML

@docs id, title, ariaLabel, pressed, expanded, htmlAttrs

-}

import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Events
import Klar.Icon as Icon exposing (Icon)
import Klar.Internal as Internal
import Klar.Spinner as Spinner
import Klar.Theme as Theme exposing (Size(..))


{-| A setting of a button. Make them with the functions below and pass a list
to `view`; later attributes win over earlier ones.
-}
type Attribute msg
    = Attribute (Config msg -> Config msg)


type Variant
    = Primary
    | Secondary
    | Ghost
    | Link


type alias Config msg =
    { variant : Maybe Variant
    , danger : Bool
    , size : Size
    , icon : Maybe Icon
    , iconRight : Maybe Icon
    , loading : Bool
    , disabled : Bool
    , ariaDisabled : Bool
    , block : Bool
    , onClick : Maybe msg
    , href : Maybe String
    , newTab : Bool
    , submit : Bool
    , id : Maybe String
    , title : Maybe String
    , ariaLabel : Maybe String
    , pressed : Maybe Bool
    , expanded : Maybe Bool
    , extra : List (Html.Attribute msg)
    }


defaults : Config msg
defaults =
    { variant = Nothing
    , danger = False
    , size = Medium
    , icon = Nothing
    , iconRight = Nothing
    , loading = False
    , disabled = False
    , ariaDisabled = False
    , block = False
    , onClick = Nothing
    , href = Nothing
    , newTab = False
    , submit = False
    , id = Nothing
    , title = Nothing
    , ariaLabel = Nothing
    , pressed = Nothing
    , expanded = Nothing
    , extra = []
    }


configure : List (Attribute msg) -> Config msg
configure attributes =
    List.foldl (\(Attribute change) config -> change config) defaults attributes



-- ATTRIBUTES


{-| The one main action of a page or dialog: solid blue. Use it once per view.
-}
primary : Attribute msg
primary =
    Attribute (\config -> { config | variant = Just Primary })


{-| The default look: white with a thin gray border.
-}
secondary : Attribute msg
secondary =
    Attribute (\config -> { config | variant = Just Secondary })


{-| A quiet button with no border until the pointer is over it. Good for
toolbars, table rows and icon-only buttons.
-}
ghost : Attribute msg
ghost =
    Attribute (\config -> { config | variant = Just Ghost })


{-| A destructive action. On its own (or with `primary`) the button is solid
red; with `secondary`, `ghost` or `link` it keeps that look and only the text
(and the border of a `secondary` button) turns red.
-}
danger : Attribute msg
danger =
    Attribute (\config -> { config | danger = True })


{-| A button that looks like a link, for actions inside running text.
-}
link : Attribute msg
link =
    Attribute (\config -> { config | variant = Just Link })


{-| A compact button, 26px high.
-}
small : Attribute msg
small =
    Attribute (\config -> { config | size = Small })


{-| A large button, 40px high, for the main action of an empty page or a form.
-}
large : Attribute msg
large =
    Attribute (\config -> { config | size = Large })


{-| Sets the size from a variable. The default is `Medium` (32px). `small` and
`large` are shorthands.
-}
size : Size -> Attribute msg
size value =
    Attribute (\config -> { config | size = value })


{-| An icon before the label.

    Button.view [ Button.icon Icon.plus ] "New order"

-}
icon : Icon -> Attribute msg
icon value =
    Attribute (\config -> { config | icon = Just value })


{-| An icon after the label, such as a chevron on a button that opens a menu.
-}
iconRight : Icon -> Attribute msg
iconRight value =
    Attribute (\config -> { config | iconRight = Just value })


{-| While `True` the button shows a spinner instead of its icon, announces
`aria-busy`, and ignores clicks. Pass a field of your model, so the button
cannot be clicked twice while a request is on its way.
-}
loading : Bool -> Attribute msg
loading value =
    Attribute (\config -> { config | loading = value })


{-| Disables the button with the HTML `disabled` attribute. A disabled button
cannot be focused, so keyboard users skip it; use `ariaDisabled` when it should
keep its place in the tab order.
-}
disabled : Bool -> Attribute msg
disabled value =
    Attribute (\config -> { config | disabled = value })


{-| Dimmed and unclickable like `disabled`, but the button stays in the tab
order and keeps the keyboard focus (`aria-disabled`). Use it for a button that
becomes unavailable while the user is on it, such as "Load more" after the last
page. A button with the real `disabled` attribute loses its focus.
-}
ariaDisabled : Bool -> Attribute msg
ariaDisabled value =
    Attribute (\config -> { config | ariaDisabled = value })


{-| Full width: the button fills its container.
-}
block : Attribute msg
block =
    Attribute (\config -> { config | block = True })


{-| The message sent when the button is clicked (or activated with the
keyboard). Nothing is sent while the button is `loading`, `disabled` or
`ariaDisabled`.
-}
onClick : msg -> Attribute msg
onClick msg =
    Attribute (\config -> { config | onClick = Just msg })


{-| Makes this the submit button of the surrounding `form`. Without it a button
has the type `button` and never submits anything.
-}
submit : Attribute msg
submit =
    Attribute (\config -> { config | submit = True })


{-| Makes the button an anchor that navigates to the URL. Use `#/path` for links
inside a single page application.
-}
href : String -> Attribute msg
href url =
    Attribute (\config -> { config | href = Just url })


{-| Opens a link made with `href` in a new tab (`target="_blank"`, with
`rel="noopener noreferrer"`).
-}
newTab : Attribute msg
newTab =
    Attribute (\config -> { config | newTab = True })


{-| The DOM id of the button. Needed to return focus to it, for example with
`Modal.open`.
-}
id : String -> Attribute msg
id value =
    Attribute (\config -> { config | id = Just value })


{-| The native tooltip (the `title` attribute). For a keyboard-friendly hint use
`Klar.Tooltip` instead.
-}
title : String -> Attribute msg
title value =
    Attribute (\config -> { config | title = Just value })


{-| The accessible name, when it differs from the visible label.
-}
ariaLabel : String -> Attribute msg
ariaLabel value =
    Attribute (\config -> { config | ariaLabel = Just value })


{-| Makes the button a toggle and says whether it is on (`aria-pressed`).

    Button.view [ Button.pressed model.showArchived, Button.onClick ToggleArchived ] "Archived"

-}
pressed : Bool -> Attribute msg
pressed value =
    Attribute (\config -> { config | pressed = Just value })


{-| For buttons that open a menu or a popup: says whether it is open
(`aria-expanded`).
-}
expanded : Bool -> Attribute msg
expanded value =
    Attribute (\config -> { config | expanded = Just value })


{-| An escape hatch for raw HTML attributes such as extra event handlers or
`data-` attributes. Other components that build on buttons use it.
-}
htmlAttrs : List (Html.Attribute msg) -> Attribute msg
htmlAttrs value =
    Attribute (\config -> { config | extra = config.extra ++ value })



-- VIEW


{-| A button with a text label.

    Button.view [ Button.primary, Button.onClick Save ] "Save"

-}
view : List (Attribute msg) -> String -> Html msg
view attributes label =
    render False (configure attributes) label


{-| A square button with only an icon. The label is the accessible name and the
native tooltip, so it must say what the button does.

    Button.iconOnly [ Button.ghost, Button.onClick Close ] Icon.close "Close"

-}
iconOnly : List (Attribute msg) -> Icon -> String -> Html msg
iconOnly attributes iconName label =
    let
        config =
            configure attributes
    in
    render True { config | icon = Just iconName, ariaLabel = Just label, title = Just (Maybe.withDefault label config.title) } ""


{-| Visually joins buttons into one segmented control.

    Button.group
        [ Button.view [ Button.pressed True ] "Day"
        , Button.view [] "Week"
        , Button.view [] "Month"
        ]

For a real choice between views, `Klar.SegmentedControl` also handles the arrow
keys.

-}
group : List (Html msg) -> Html msg
group buttons =
    Html.div [ Internal.cls [ "klar-button-group" ], Attr.attribute "role" "group" ] buttons


render : Bool -> Config msg -> String -> Html msg
render isIconOnly config label =
    let
        inactive =
            config.disabled || config.loading || config.ariaDisabled

        ( look, toned ) =
            appearance config

        classNames =
            Internal.cls
                [ "klar-button"
                , "klar-button--" ++ look
                , if toned then
                    "klar-button--tone-danger"

                  else
                    ""
                , "klar-button--" ++ Theme.sizeSuffix config.size
                , if isIconOnly then
                    "klar-button--icon-only"

                  else
                    ""
                , if config.block then
                    "klar-button--block"

                  else
                    ""
                , if config.loading then
                    "klar-button--loading"

                  else
                    ""
                , if config.disabled || config.ariaDisabled then
                    "klar-button--disabled"

                  else
                    ""
                ]

        common =
            [ classNames
            , Internal.attrMaybe Attr.id config.id
            , Internal.attrMaybe Attr.title config.title
            , Internal.attrMaybe (Attr.attribute "aria-label") config.ariaLabel
            , Internal.attrMaybe (\p -> Attr.attribute "aria-pressed" (boolString p)) config.pressed
            , Internal.attrMaybe (\e -> Attr.attribute "aria-expanded" (boolString e)) config.expanded
            , Internal.attrIf config.loading (Attr.attribute "aria-busy" "true")
            , Internal.attrIf inactive (Attr.attribute "aria-disabled" "true")
            ]
                ++ config.extra

        leading =
            if config.loading then
                Spinner.view []

            else
                Internal.viewMaybe Icon.view config.icon

        children =
            [ leading
            , if isIconOnly then
                Html.text ""

              else
                Html.span [ Internal.cls [ "klar-button__label" ] ] [ Html.text label ]
            , Internal.viewMaybe Icon.view config.iconRight
            ]
    in
    case config.href of
        Just url ->
            Html.a
                (common
                    ++ [ if inactive then
                            Internal.noAttr

                         else
                            Attr.href url
                       , Internal.attrIf config.newTab (Attr.target "_blank")
                       , Internal.attrIf config.newTab (Attr.rel "noopener noreferrer")
                       ]
                )
                children

        Nothing ->
            Html.button
                (common
                    ++ [ -- A busy or unavailable button must not submit the form
                         -- behind the application's back.
                         Attr.type_
                            (if config.submit && not inactive then
                                "submit"

                             else
                                "button"
                            )
                       , Attr.disabled config.disabled
                       , if inactive then
                            Internal.noAttr

                         else
                            Internal.attrMaybe Events.onClick config.onClick
                       ]
                )
                children


{-| The look of the button and whether it only has the danger tone (red text)
on top of a quiet look. `danger` alone, or with `primary`, is the solid red
button; with `secondary`, `ghost` or `link` it only changes the tone.
-}
appearance : Config msg -> ( String, Bool )
appearance config =
    case ( config.variant, config.danger ) of
        ( Nothing, False ) ->
            ( "secondary", False )

        ( Nothing, True ) ->
            ( "danger", False )

        ( Just Primary, False ) ->
            ( "primary", False )

        ( Just Primary, True ) ->
            ( "danger", False )

        ( Just Secondary, isDanger ) ->
            ( "secondary", isDanger )

        ( Just Ghost, isDanger ) ->
            ( "ghost", isDanger )

        ( Just Link, isDanger ) ->
            ( "link", isDanger )


boolString : Bool -> String
boolString value =
    if value then
        "true"

    else
        "false"
