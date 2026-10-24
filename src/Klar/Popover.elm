module Klar.Popover exposing
    ( view
    , State, Msg, init, update, isOpen
    , open, openFocusing, close, toggle
    , Attribute, icon, iconOnly, trigger, customTrigger
    , title, closeButton, width, alignEnd, noPadding, initialFocus
    , locale
    )

{-| A small panel anchored to a button, with any content: a quick filter, a few
settings, a short form, an explanation with a link.

Use when: a small panel next to a button must hold any content, such as a quick filter or a few settings, and stay open while the user works in it.
Do not use when: you only need a list of actions (use `Klar.Menu`) or the work needs the full attention of the user (use `Klar.Modal`).
Quick path: `init`, `update`, `view`, `open`, `close`, `isOpen`

    -- model:   popover : Popover.State        (Popover.init "filter-popover")

    -- update
    PopoverMsg m ->
        let
            ( popover, cmd ) =
                Popover.update m model.popover
        in
        ( { model | popover = popover }, Cmd.map PopoverMsg cmd )

    ApplyFilter ->
        let
            ( popover, cmd ) =
                Popover.close model.popover
        in
        ( { model | popover = popover }
        , Cmd.batch [ loadOrders model.customer, Cmd.map PopoverMsg cmd ]
        )

    -- view
    Popover.view PopoverMsg
        [ Popover.icon Icon.filter
        , Popover.title "Quick filter"
        , Popover.closeButton
        , Popover.initialFocus [ "filter-customer" ]
        ]
        model.popover
        "Filter"
        [ TextInput.view
            [ TextInput.id "filter-customer"
            , TextInput.label "Customer"
            , TextInput.value model.customer
            , TextInput.onInput CustomerChanged
            ]
        , Button.view [ Button.primary, Button.onClick ApplyFilter ] "Apply"
        ]

The button opens the panel with a click, `Enter`, `Space` or `ArrowDown`. Where
the browser supports CSS anchor positioning, the panel is drawn next to the
button, is never clipped by a table or a dialog and flips above the button when
there is no room below; other browsers get plain positioning. Clicks inside the
panel do not close it. A click outside, `Escape` or the close button do, and
focus returns to the button. `Tab` out of the panel closes it too, and focus
goes where the user was heading. `Escape` pressed in a select or a menu that is
open inside the panel closes only that popup, and so does an `Escape` that a
control in the panel handled itself (a search field that cleared its text) or that
ends an IME composition. If the element that has focus in the panel is removed or
disabled (an "Apply" that becomes "Applying ..."), focus moves to the panel, so that
`Escape` and `Tab` keep working. [Klar.Modal](Klar-Modal) describes these rules,
shared by all popups and dialogs, in one place.

The label (`"Filter"` above) is a required argument of `view`: it is the text of
the button, or the name of an `iconOnly` button, and it names the panel when the
panel has no `title`. The panel is announced as a dialog. The only built-in text
is the label of the close button; it follows `locale`.
If a button in the panel opens a dialog, give the dialog to
[`Overlay.host`](Klar-Overlay#host): the page is then `inert`, so closing the panel,
which gives focus back to its button, cannot take focus away from the dialog.


# View

@docs view


# State

@docs State, Msg, init, update, isOpen


# Opening and closing

The button opens and closes the panel by itself. These functions are for the
rest: closing the panel when the work in it is done, or opening it from a
keyboard shortcut.

@docs open, openFocusing, close, toggle


# The button

@docs Attribute, icon, iconOnly, trigger, customTrigger


# The panel

@docs title, closeButton, width, alignEnd, noPadding, initialFocus


# Texts

@docs locale

-}

import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Events
import Json.Decode as Decode
import Klar.Button as Button
import Klar.Icon as Icon exposing (Icon)
import Klar.Internal as Internal
import Klar.Locale as Locale exposing (Locale)
import Klar.Overlay.Focus as Focus



-- STATE


{-| The state of one popover: whether its panel is open. Create it with `init`,
keep it in your model, and change it with `open`, `close`, `toggle` and
`update`.
-}
type State
    = State
        { id : String
        , open : Bool
        }


{-| A closed popover. The id must be unique on the page; the ids of the button
and of the panel start with it.
-}
init : String -> State
init id =
    State { id = id, open = False }


{-| Is the panel open? It follows the user (the button, a click outside the panel,
`Escape`) as well as your calls to `open` and `close`.
-}
isOpen : State -> Bool
isOpen (State state) =
    state.open


{-| The messages of the popover (opening, closing, focus). Wrap it in a
constructor of your own message type, such as `PopoverMsg Popover.Msg`, and hand
it to `update`.
-}
type Msg
    = Toggle (List String)
    | Close
    | CloseQuiet
    | Lost
    | Noop


{-| Handles opening, closing and focus. Map its command into your own message
with `Cmd.map`.
-}
update : Msg -> State -> ( State, Cmd Msg )
update msg ((State state) as current) =
    case msg of
        Toggle focus ->
            toggleWith focus current

        Close ->
            close current

        CloseQuiet ->
            ( State { state | open = False }, Cmd.none )

        Lost ->
            -- The element that had focus in the panel was removed or disabled, and
            -- focus fell to the page, where `Escape` no longer reaches the panel.
            ( current
            , if state.open then
                Internal.focusFirst [ popupId state.id ] Noop

              else
                Cmd.none
            )

        Noop ->
            ( current, Cmd.none )


{-| Opens the panel and moves focus into it (to the panel itself; use
`openFocusing` to focus a field). It ignores the `initialFocus` attribute, which
applies when the user opens the panel with the button.
-}
open : State -> ( State, Cmd Msg )
open =
    openFocusing []


{-| Opens the panel and focuses the first of these elements that exists (ids of
fields inside the panel). If none exists, the panel itself gets focus.
-}
openFocusing : List String -> State -> ( State, Cmd Msg )
openFocusing focus (State state) =
    ( State { state | open = True }
    , Internal.focusFirst (focus ++ [ popupId state.id ]) Noop
    )


{-| Closes the panel and gives focus back to its button. Call it from a button
inside the panel when the work is done, such as "Apply".
-}
close : State -> ( State, Cmd Msg )
close (State state) =
    ( State { state | open = False }
    , if state.open then
        Internal.focus (triggerId state.id) Noop

      else
        Cmd.none
    )


{-| Opens the panel if it is closed, closes it if it is open. Like `open`, it
ignores the `initialFocus` attribute.
-}
toggle : State -> ( State, Cmd Msg )
toggle =
    toggleWith []


toggleWith : List String -> State -> ( State, Cmd Msg )
toggleWith focus ((State state) as current) =
    if state.open then
        close current

    else
        openFocusing focus current


maybeList : (a -> b) -> Maybe a -> List b
maybeList change maybe =
    case maybe of
        Just value ->
            [ change value ]

        Nothing ->
            []


triggerId : String -> String
triggerId id =
    id ++ "-trigger"


popupId : String -> String
popupId id =
    id ++ "-popup"


titleId : String -> String
titleId id =
    id ++ "-title"



-- ATTRIBUTES


{-| A setting of a popover. Make them with the functions below and pass a list to
`view`; later attributes win over earlier ones.
-}
type Attribute msg
    = Attribute (Config msg -> Config msg)


type alias Config msg =
    { icon : Maybe Icon
    , iconOnly : Bool
    , triggerAttrs : List (Button.Attribute msg)
    , custom : Maybe (List (Html.Attribute msg) -> Html msg)
    , title : Maybe String
    , closeButton : Bool
    , alignEnd : Bool
    , width : Int
    , padding : Bool
    , initialFocus : List String
    , locale : Locale
    }


configure : List (Attribute msg) -> Config msg
configure attributes =
    List.foldl (\(Attribute change) config -> change config)
        { icon = Nothing
        , iconOnly = False
        , triggerAttrs = []
        , custom = Nothing
        , title = Nothing
        , closeButton = False
        , alignEnd = False
        , width = 320
        , padding = True
        , initialFocus = []
        , locale = Locale.default
        }
        attributes


{-| An icon on the button, before the label.
-}
icon : Icon -> Attribute msg
icon value =
    Attribute (\config -> { config | icon = Just value })


{-| The button shows only its icon (three dots if you give no `icon`), and the
label of `view` becomes its accessible name.

    Popover.view HelpMsg [ Popover.icon Icon.help, Popover.iconOnly ] model.help "What is priority?" [ explanation ]

-}
iconOnly : Attribute msg
iconOnly =
    Attribute (\config -> { config | iconOnly = True })


{-| Style the button: `Popover.trigger [ Button.ghost, Button.small ]`. The
attributes add up when you use it more than once. It has no effect with
`customTrigger`.
-}
trigger : List (Button.Attribute msg) -> Attribute msg
trigger value =
    Attribute (\config -> { config | triggerAttrs = config.triggerAttrs ++ value })


{-| Use your own element as the button. The function receives the attributes it
must put on that element (`id`, `aria-haspopup`, `aria-expanded`, the click
handler and the `ArrowDown` handler); without them the panel cannot open and
focus cannot return to the element. Your element shows its own text; the label of
`view` still names the panel when it has no `title`.

    Popover.customTrigger (\attrs -> Button.view [ Button.htmlAttrs attrs ] "Filter")

-}
customTrigger : (List (Html.Attribute msg) -> Html msg) -> Attribute msg
customTrigger value =
    Attribute (\config -> { config | custom = Just value })


{-| A heading in the panel; it is also the accessible name of the panel, instead
of the label.
-}
title : String -> Attribute msg
title value =
    Attribute (\config -> { config | title = Just value })


{-| A close button in the header of the panel. Its label follows `locale`. The
header is shown when the panel has a `title` or a close button.
-}
closeButton : Attribute msg
closeButton =
    Attribute (\config -> { config | closeButton = True })


{-| Align the right edge of the panel with the right edge of the button, so that
the panel extends to the left. Use it for a button near the right edge of the
window.
-}
alignEnd : Attribute msg
alignEnd =
    Attribute (\config -> { config | alignEnd = True })


{-| Width of the panel in pixels. The default is 320. The panel is never wider
than 520px or the window.
-}
width : Int -> Attribute msg
width value =
    Attribute (\config -> { config | width = value })


{-| No padding around the content, for lists and tables that go edge to edge.
Content taller than 70% of the window (at most 520px) scrolls.
-}
noPadding : Attribute msg
noPadding =
    Attribute (\config -> { config | padding = False })


{-| Ids of elements inside the panel that should get focus when the user opens
it with the button (the first one that exists). Without it the panel itself gets
focus. `open` and `toggle` ignore this attribute; when you open the panel from
your own code, use `openFocusing`.
-}
initialFocus : List String -> Attribute msg
initialFocus value =
    Attribute (\config -> { config | initialFocus = value })


{-| The language of the built-in text, which is the label of the close button
("Close" by default). The default language is
[`Locale.default`](Klar-Locale#default), which is English.
-}
locale : Locale -> Attribute msg
locale value =
    Attribute (\config -> { config | locale = value })



-- VIEW


{-| The button labelled `label` and, while open, the panel with `content`. The
label is the text of the button (its accessible name with `iconOnly`), and it
names the panel when the panel has no `title`. `toMsg` wraps the messages of the
popover. The content is laid out in a column, one item below the other.
-}
view : (Msg -> msg) -> List (Attribute msg) -> State -> String -> List (Html msg) -> Html msg
view toMsg attributes (State state) label content =
    let
        config =
            configure attributes

        triggerAttributes =
            [ Attr.id (triggerId state.id)
            , Attr.attribute "aria-haspopup" "dialog"
            , Attr.attribute "aria-expanded"
                (if state.open then
                    "true"

                 else
                    "false"
                )
            , Internal.attrIf state.open (Attr.attribute "aria-controls" (popupId state.id))
            , Events.onClick (toMsg (Toggle config.initialFocus))
            , Internal.onKeys [ ( "ArrowDown", toMsg (Toggle config.initialFocus) ) ]
            ]

        triggerView =
            case config.custom of
                Just build ->
                    build triggerAttributes

                Nothing ->
                    if config.iconOnly then
                        Button.iconOnly
                            (config.triggerAttrs ++ [ Button.htmlAttrs triggerAttributes ])
                            (Maybe.withDefault Icon.moreHorizontal config.icon)
                            label

                    else
                        Button.view
                            (maybeList Button.icon config.icon
                                ++ config.triggerAttrs
                                ++ [ Button.htmlAttrs triggerAttributes ]
                            )
                            label
    in
    Html.div [ Internal.cls [ "klar-anchor", "klar-popover" ] ]
        [ triggerView
        , if state.open then
            viewPanel toMsg config state label content

          else
            Html.text ""
        ]


viewPanel : (Msg -> msg) -> Config msg -> { id : String, open : Bool } -> String -> List (Html msg) -> Html msg
viewPanel toMsg config state label content =
    let
        hasHeader =
            config.title /= Nothing || config.closeButton
    in
    Html.div
        [ Internal.cls [ "klar-layer" ]
        , Events.onClick (toMsg Close)
        , Events.preventDefaultOn "keydown" (Focus.escape (popupId state.id) (toMsg Close))
        ]
        [ Html.div
            ([ Internal.cls
                [ "klar-popup"
                , "klar-popover__popup"
                , if config.alignEnd then
                    "klar-popup--end"

                  else
                    ""
                ]
             , Attr.id (popupId state.id)
             , Attr.tabindex -1
             , Attr.attribute "role" "dialog"
             , Internal.styleVars [ ( "width", Internal.px config.width ) ]
             , Internal.onClickStop (toMsg Noop)
             , focusLeft (popupId state.id) (toMsg CloseQuiet)
             ]
                ++ (case config.title of
                        Just _ ->
                            [ Attr.attribute "aria-labelledby" (titleId state.id) ]

                        Nothing ->
                            [ Attr.attribute "aria-label" label ]
                   )
            )
            [ Internal.viewIf hasHeader
                (Html.div [ Internal.cls [ "klar-popover__header" ] ]
                    [ Html.div [ Internal.cls [ "klar-popover__title" ], Attr.id (titleId state.id) ]
                        [ Html.text (Maybe.withDefault "" config.title) ]
                    , Internal.viewIf config.closeButton
                        (Button.iconOnly
                            [ Button.ghost, Button.small, Button.onClick (toMsg Close) ]
                            Icon.close
                            (Locale.pick config.locale { nb = "Lukk", en = "Close" })
                        )
                    ]
                )
            , Html.div
                [ Internal.cls
                    [ "klar-popover__body"
                    , if config.padding then
                        ""

                      else
                        "klar-popover__body--flush"
                    ]
                ]
                content

            -- Watches for focus that falls out of the panel (the focused element was
            -- removed or disabled). Only the innermost open panel keeps watch.
            , Focus.guard Focus.Idle (toMsg Lost)
            ]
        ]



-- EVENTS


{-| Focus moved from inside the panel to an element outside it.
-}
focusLeft : String -> msg -> Html.Attribute msg
focusLeft panelId msg =
    Events.on "focusout"
        (Decode.field "relatedTarget" (Decode.nullable (Focus.isInside panelId))
            |> Decode.andThen
                (\found ->
                    case found of
                        Just False ->
                            Decode.succeed msg

                        _ ->
                            Decode.fail "focus stays inside"
                )
        )
