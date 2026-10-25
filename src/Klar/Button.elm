module Klar.Button exposing
    ( view, iconOnly
    , Attribute, primary, secondary, ghost, link, danger, small, large, size, block
    , icon, iconRight, loading
    , onClick, submit, href, newTab, disabled, ariaDisabled
    , id, title, ariaLabel, pressed, expanded, locale, htmlAttrs
    )

{-| Buttons and button-looking links.

Use when: the user must trigger an action, or follow a link that should look like a button.
Do not use when: you need a plain link in running text (as `Klar.Link`) or a choice between options (as `Klar.SegmentedControl`).

    import Klar.Button as Button
    import Klar.Icon as Icon
    import Klar.Link as Link

    Button.view [ Button.primary, Button.onClick SaveOrder ] "Save order"

    Button.view [ Button.danger, Button.icon Icon.trash, Button.loading model.deleting ] "Delete"

    Button.iconOnly [ Button.ghost, Button.onClick Reload ] Icon.refresh "Reload"

    Button.view [ Button.href (Link.internal "/orders") ] "Open orders"

There are four looks: `primary` (the one main action on a page), `secondary`
(the default), `ghost` (quiet, for toolbars and table rows) and `link` (looks
like a link). A button with `href` is rendered as an anchor, so it can be opened
in a new tab, but it keeps the look of the other buttons. Its destination is a
[`Link.Target`](Klar-Link#Target), checked like the one of a
[Klar.Link](Klar-Link): a page of the application, another site, or a file to
save (`Link.download`).

`danger` marks a destructive action. On its own (or with `primary`) it is the
solid red button. Combined with `secondary`, `ghost` or `link` it keeps that
look and only changes the tone: red text and, for `secondary`, a red border. The
order of the attributes does not matter.

    Button.view [ Button.danger ] "Delete" -- solid red

    Button.view [ Button.ghost, Button.danger ] "Delete" -- quiet, red text

    Button.view [ Button.secondary, Button.danger ] "Delete" -- white, red text and border

A button that is `loading`, `disabled` or `ariaDisabled` does not send its
message and never submits a form; one that is a link cannot be followed then,
but keeps its place in the tab order (except with `disabled`).


# Views

@docs view, iconOnly


# Look and size

@docs Attribute, primary, secondary, ghost, link, danger, small, large, size, block


# Content

@docs icon, iconRight, loading


# Behavior

@docs onClick, submit, href, newTab, disabled, ariaDisabled


# Accessibility and HTML

@docs id, title, ariaLabel, pressed, expanded, locale, htmlAttrs

-}

import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Events
import Klar.Icon as Icon exposing (Icon)
import Klar.Internal as Internal
import Klar.Link as Link
import Klar.Link.Destination as Destination
import Klar.Locale as Locale exposing (Locale)
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
    , href : Maybe Link.Target
    , newTab : Bool
    , submit : Bool
    , id : Maybe String
    , title : Maybe String
    , ariaLabel : Maybe String
    , pressed : Maybe Bool
    , expanded : Maybe Bool
    , locale : Locale
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
    , locale = Locale.default
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
cannot be focused, so keyboard users skip it, and a button that is disabled while
it has focus throws the focus to the page; use `ariaDisabled` when it should keep
its place in the tab order.
-}
disabled : Bool -> Attribute msg
disabled value =
    Attribute (\config -> { config | disabled = value })


{-| Dimmed and unclickable like `disabled`, but the button stays in the tab
order and keeps the keyboard focus (`aria-disabled`). Use it for a button that
becomes unavailable while the user is on it, such as "Load more" after the last
page, and for one that a [Klar.Tooltip](Klar-Tooltip) explains: it still gets the
pointer and the focus that show the tip. A button with the real `disabled`
attribute loses its focus.
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


{-| Makes the button an anchor (`<a href>`) that leads to the target: a page of
the application (`Link.internal`), another site (`Link.external`, which opens in
a new tab) or a file to save (`Link.download`). See [Klar.Link](Klar-Link).

    Button.view [ Button.primary, Button.href (Link.internal "/orders/new") ] "New order"

    Button.view
        [ Button.icon Icon.download
        , Button.href (Link.download { fileName = "orders.csv", mimeType = "text/csv", content = csv })
        ]
        "Export"

A link has no `onClick` and no `submit` (they are ignored), and no `pressed` or
`expanded`, which a link cannot have. While it is `loading`, `disabled` or
`ariaDisabled` it has no `href`: it cannot be followed, and a screen reader finds
a link that is unavailable.

-}
href : Link.Target -> Attribute msg
href target =
    Attribute (\config -> { config | href = Just target })


{-| Opens a link made with `href` in a new tab (`target="_blank"`, with
`rel="noopener noreferrer"`), with the text "(opens in a new tab)" for screen
readers in the language of `locale`. A link to another site (`Link.external`)
does this without it.
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
`Klar.Tooltip` instead. On an `iconOnly` button it is the text of the tooltip
that the button has already, instead of the label.
-}
title : String -> Attribute msg
title value =
    Attribute (\config -> { config | title = Just value })


{-| The accessible name, when it differs from the visible label.
-}
ariaLabel : String -> Attribute msg
ariaLabel value =
    Attribute (\config -> { config | ariaLabel = Just value })


{-| Makes the button a toggle and says whether it is on (`aria-pressed`). In
Windows high contrast a button that is on gets a frame.

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


{-| The language of the built-in text: "(opens in a new tab)", which screen
readers read after the label of a link that opens in a new tab. The default is
`Locale.default`, which is `Locale.en`.
-}
locale : Locale -> Attribute msg
locale value =
    Attribute (\config -> { config | locale = value })


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
tooltip (a [Klar.Tooltip](Klar-Tooltip) that shows on hover and on keyboard
focus), so it must say what the button does. `Button.title` changes the text of
the tooltip, and `Tooltip.attrs` in `htmlAttrs` replaces it (to add a shortcut,
say). Inside `Tooltip.wrap` the wrap's tip is the only one.

    Button.iconOnly [ Button.ghost, Button.onClick Close ] Icon.close "Close"

-}
iconOnly : List (Attribute msg) -> Icon -> String -> Html msg
iconOnly attributes iconName label =
    let
        config =
            configure attributes
    in
    render True { config | icon = Just iconName, ariaLabel = Just label } ""


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
                , "klar-button--" ++ Internal.sizeSuffix config.size
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

        isLink =
            config.href /= Nothing

        -- A link opens a new tab when it is asked to, or when it leads to another
        -- site; a button (no href) and a file to save never do.
        opensTab =
            case config.href of
                Just target ->
                    not inactive && Destination.fileName target == Nothing && (config.newTab || Destination.opensInNewTab target)

                Nothing ->
                    False

        newTabText =
            Locale.pick config.locale { nb = "(åpnes i en ny fane)", en = "(opens in a new tab)" }

        -- An icon-only button is named by its aria-label, which hides the text inside it.
        name =
            if opensTab then
                Maybe.map (\text -> text ++ " " ++ newTabText) config.ariaLabel

            else
                config.ariaLabel

        -- An icon-only button shows its label as a Klar tooltip, which appears on
        -- keyboard focus too (a native title never does).
        tip =
            if isIconOnly then
                case config.title of
                    Just text ->
                        Just text

                    Nothing ->
                        config.ariaLabel

            else
                Nothing

        common =
            [ classNames
            , Internal.attrMaybe Attr.id config.id
            , if isIconOnly then
                Internal.noAttr

              else
                Internal.attrMaybe Attr.title config.title
            , Internal.attrMaybe (Attr.attribute "data-tip") tip
            , Internal.attrMaybe (Attr.attribute "aria-label") name

            -- a link cannot be pressed or expanded
            , if isLink then
                Internal.noAttr

              else
                Internal.attrMaybe (\p -> Attr.attribute "aria-pressed" (boolString p)) config.pressed
            , if isLink then
                Internal.noAttr

              else
                Internal.attrMaybe (\e -> Attr.attribute "aria-expanded" (boolString e)) config.expanded
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
                Html.span [ Internal.cls [ "klar-button__label" ] ]
                    [ Html.text label
                    , Internal.viewIf opensTab (Html.span [ Internal.cls [ "klar-sr-only" ] ] [ Html.text (" " ++ newTabText) ])
                    ]
            , Internal.viewMaybe Icon.view config.iconRight
            ]
    in
    case config.href of
        Just target ->
            -- One element whether it can be followed or not, so that a link that
            -- becomes busy or unavailable while it has focus keeps it.
            Html.a
                (common
                    ++ (if inactive then
                            -- `disabled` takes it out of the tab order, as it does a button
                            Destination.inactiveAttributes { focusable = not config.disabled }

                        else
                            -- Attributes, not the properties `Attr.href`, `Attr.target`
                            -- and `Attr.download`: a property that goes away when the
                            -- link becomes inactive is set to "" (href="" is a link to
                            -- this page, download="" saves it), an attribute is removed.
                            [ Destination.hrefAttribute target
                            , Internal.attrMaybe (Attr.attribute "download") (Destination.fileName target)
                            , Internal.attrIf opensTab (Attr.attribute "target" "_blank")
                            , Internal.attrIf opensTab (Attr.attribute "rel" "noopener noreferrer")
                            ]
                       )
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
