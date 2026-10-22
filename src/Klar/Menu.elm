module Klar.Menu exposing
    ( view
    , State, Msg, init, update, isOpen, open, close
    , Item, item, separator, heading, withIcon, withHint, danger, disabledItem
    , Attribute, items, label, kebab, trigger, alignEnd
    )

{-| A dropdown menu opened from a button. Used for actions that do not deserve
their own button: row actions, "more", user menus.

Use when: a few actions do not deserve their own buttons: row actions, "more", user menus.
Do not use when: the popup holds any content (as `Klar.Popover`), opens on right-click (as `Klar.ContextMenu`) or has a main action (as `Klar.SplitButton`).
Quick path: `init`, `update`, `view`, `isOpen`

Where a [Klar.Popover](Klar-Popover) holds any content, a menu is a list of
actions that closes as soon as one is picked. For a menu that opens where the
user right-clicks, use a [Klar.ContextMenu](Klar-ContextMenu).

    import Klar.Icon as Icon
    import Klar.Menu as Menu

    -- model:   rowMenu : Menu.State        (Menu.init "order-actions")

    -- update
    MenuMsg m ->
        let
            ( menu, cmd ) =
                Menu.update m model.rowMenu
        in
        ( { model | rowMenu = menu }, Cmd.map MenuMsg cmd )

    -- view
    Menu.view MenuMsg
        [ Menu.label "Actions"
        , Menu.items
            [ Menu.item "Edit" EditOrder |> Menu.withIcon Icon.edit
            , Menu.separator
            , Menu.item "Delete" DeleteOrder |> Menu.danger |> Menu.withIcon Icon.trash
            ]
        ]
        model.rowMenu

Clicking an item sends the item's own message and closes the menu. The button
opens the menu with a click, `Enter`, `Space` or `ArrowDown`, and focus moves
into the menu. Keyboard: the arrow keys move the highlight (and wrap around),
`Home` and `End` jump to the first and last item, `Enter` or `Space` pick the
highlighted item, and `Escape` or `Tab` close the menu. A click anywhere outside
the menu closes it too. When the menu closes, it gives focus back to its button,
except after `Tab` and `Shift+Tab`: they leave the menu like any other element,
`Tab` for the next element on the page and `Shift+Tab` for the button. Disabled
items are skipped. A long menu scrolls, and the keys scroll the highlighted item
into view (the pointer does not: an item under it can be seen). Screen readers
get a `menu` with `menuitem` entries.

Every menu needs a `State` and an id of its own. The menu has no built-in text,
so there is no `locale`: the labels come from your application.
[Klar.Modal](Klar-Modal) describes the rules that all popups share.

If an item opens a dialog, give the dialog to
[`Overlay.host`](Klar-Overlay#host): the page behind it is then `inert`, so closing
the menu, which gives focus back to its button, cannot take focus away from the
dialog.


# View

@docs view


# State

@docs State, Msg, init, update, isOpen, open, close


# Items

@docs Item, item, separator, heading, withIcon, withHint, danger, disabledItem


# Attributes

@docs Attribute, items, label, kebab, trigger, alignEnd

-}

import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Events
import Klar.Button as Button
import Klar.Icon as Icon exposing (Icon)
import Klar.Internal as Internal
import Klar.Menu.Scroll as Scroll



-- STATE


{-| The state of one menu: whether it is open and which item is highlighted.
Create it with `init`, keep it in your model (one per menu), and change it with
`open`, `close` and `update`.
-}
type State
    = State
        { id : String
        , open : Bool
        , highlighted : Int
        }


{-| A closed menu. The id must be unique on the page; the ids of the button, the
popup and the items start with it.
-}
init : String -> State
init id =
    State { id = id, open = False, highlighted = -1 }


{-| Is the menu open?
-}
isOpen : State -> Bool
isOpen (State state) =
    state.open


{-| The messages of the menu (opening, closing, moving the highlight). Wrap it in
a constructor of your own message type, such as `MenuMsg Menu.Msg`, and hand it
to `update`.
-}
type Msg
    = Toggle
    | Open
    | Close
    | CloseQuiet
    | Highlight Int
    | Step Int (List Int)
    | Jump Int (List Int)
    | Noop


{-| Handles opening and closing the menu and moving the highlight, and scrolls a
long menu to the highlighted item. Map its command into your own message with
`Cmd.map`. Picking an item does not go through here: it sends the message of the
item.
-}
update : Msg -> State -> ( State, Cmd Msg )
update msg ((State state) as current) =
    case msg of
        Toggle ->
            if state.open then
                close current

            else
                open current

        Open ->
            open current

        Close ->
            close current

        -- `Tab` leaves the menu: the browser moves focus on, and the menu must
        -- not pull it back to the button.
        CloseQuiet ->
            ( State { state | open = False, highlighted = -1 }, Cmd.none )

        -- The pointer is over the item: it can be seen, so the list stays put.
        Highlight index ->
            ( State { state | highlighted = index }, Cmd.none )

        -- Relative to the highlight in the model, not to the one the page was
        -- last drawn with: arrow keys that come faster than a redraw add up.
        Step direction enabledIndices ->
            case neighbour direction enabledIndices state.highlighted of
                Just index ->
                    ( State { state | highlighted = index }, bringIntoView state.id enabledIndices index )

                Nothing ->
                    ( current, Cmd.none )

        -- `Home` and `End`: the first or the last item that can be picked.
        Jump index enabledIndices ->
            ( State { state | highlighted = index }, bringIntoView state.id enabledIndices index )

        Noop ->
            ( current, Cmd.none )


{-| Opens the menu and moves keyboard focus into it, with no item highlighted
yet. Use it to open the menu from your own code, from a keyboard shortcut for
example.
-}
open : State -> ( State, Cmd Msg )
open (State state) =
    ( State { state | open = True, highlighted = -1 }
    , Internal.focus (popupId state.id) Noop
    )


{-| Closes the menu and gives focus back to its button. The menu closes by itself
when the user picks an item, clicks outside it or presses `Escape`; `Tab` closes
it too, but lets focus move on to the next element instead.
-}
close : State -> ( State, Cmd Msg )
close (State state) =
    ( State { state | open = False, highlighted = -1 }
    , if state.open then
        Internal.focus (triggerId state.id) Noop

      else
        Cmd.none
    )


{-| A menu that is taller than its maximum height scrolls: when the keys move the
highlight, scroll the list so that the highlighted item can be seen.
-}
bringIntoView : String -> List Int -> Int -> Cmd Msg
bringIntoView id enabledIndices index =
    Scroll.reveal
        { list = popupId id
        , item = optionId id index
        , edge = Scroll.edge enabledIndices index
        }
        Noop


triggerId : String -> String
triggerId id =
    id ++ "-trigger"


popupId : String -> String
popupId id =
    id ++ "-popup"


optionId : String -> Int -> String
optionId id index =
    id ++ "-item-" ++ String.fromInt index



-- ITEMS


{-| One entry of the menu: an action, a separator or a heading. Make them with
`item`, `separator` and `heading`, and refine an action with `withIcon`,
`withHint`, `danger` and `disabledItem`.
-}
type Item msg
    = Action (ActionConfig msg)
    | Separator
    | Heading String


type alias ActionConfig msg =
    { label : String
    , onClick : msg
    , icon : Maybe Icon
    , hint : Maybe String
    , danger : Bool
    , disabled : Bool
    }


{-| A menu entry that sends `msg` when picked: `Menu.item "Edit" EditOrder`. Keep
labels short; a long one is cut off with an ellipsis.
-}
item : String -> msg -> Item msg
item text msg =
    Action { label = text, onClick = msg, icon = Nothing, hint = Nothing, danger = False, disabled = False }


{-| A thin line between two groups of items.
-}
separator : Item msg
separator =
    Separator


{-| A small caption above a group of items. It cannot be picked or highlighted.
-}
heading : String -> Item msg
heading =
    Heading


{-| An icon before the label of an action. This function and `withHint`,
`danger` and `disabledItem` change an action and leave a separator or a heading
as it is.

    Menu.item "Edit" EditOrder |> Menu.withIcon Icon.edit

-}
withIcon : Icon -> Item msg -> Item msg
withIcon icon =
    mapAction (\action -> { action | icon = Just icon })


{-| Right-aligned gray text, typically a keyboard shortcut:
`Menu.withHint "Ctrl D"`. It is only shown; it does not install the shortcut
(see [Klar.Shortcut](Klar-Shortcut) for that).
-}
withHint : String -> Item msg -> Item msg
withHint hint =
    mapAction (\action -> { action | hint = Just hint })


{-| Red text, for destructive actions.
-}
danger : Item msg -> Item msg
danger =
    mapAction (\action -> { action | danger = True })


{-| Visible but not pickable: the arrow keys skip it, it is never highlighted,
and a click on it does nothing (the menu stays open).
-}
disabledItem : Item msg -> Item msg
disabledItem =
    mapAction (\action -> { action | disabled = True })


mapAction : (ActionConfig msg -> ActionConfig msg) -> Item msg -> Item msg
mapAction change entry =
    case entry of
        Action action ->
            Action (change action)

        other ->
            other



-- ATTRIBUTES


{-| A setting of a menu. Make them with the functions below and pass a list to
`view`; later attributes win over earlier ones.
-}
type Attribute msg
    = Attribute (Config msg -> Config msg)


type alias Config msg =
    { label : String
    , kebabLabel : Maybe String
    , items : List (Item msg)
    , triggerAttrs : List (Button.Attribute msg)
    , alignEnd : Bool
    }


configure : List (Attribute msg) -> Config msg
configure attributes =
    List.foldl (\(Attribute change) config -> change config)
        { label = ""
        , kebabLabel = Nothing
        , items = []
        , triggerAttrs = []
        , alignEnd = False
        }
        attributes


{-| Text on the button that opens the menu, followed by a small down arrow. It is
not used with `kebab`; without a label or `kebab` the button has no accessible
name.
-}
label : String -> Attribute msg
label text =
    Attribute (\config -> { config | label = text })


{-| An icon-only "more" button with three vertical dots instead of the text
button. The `String` is its accessible name and its native tooltip, so it must
say what the menu is for, such as "Order actions". The button looks like a
`ghost` button unless you style it with `trigger`.
-}
kebab : String -> Attribute msg
kebab accessibleName =
    Attribute (\config -> { config | kebabLabel = Just accessibleName })


{-| The entries of the menu, from top to bottom. The default is an empty menu. A
menu taller than 26rem (or than the window) scrolls.
-}
items : List (Item msg) -> Attribute msg
items value =
    Attribute (\config -> { config | items = value })


{-| Style the button: `Menu.trigger [ Button.ghost, Button.small ]`. The
attributes add up when you use it more than once. The id, the expanded state and
the click handler of the button belong to the menu and cannot be overridden.
-}
trigger : List (Button.Attribute msg) -> Attribute msg
trigger value =
    Attribute (\config -> { config | triggerAttrs = config.triggerAttrs ++ value })


{-| Align the menu's right edge with the button's right edge, so that the menu
extends to the left. Use it for a button near the right edge of the window or of
a table.
-}
alignEnd : Attribute msg
alignEnd =
    Attribute (\config -> { config | alignEnd = True })



-- VIEW


{-| The button and, while open, the menu; `toMsg` wraps the messages of the menu.
Where the browser supports CSS anchor positioning, the menu is never clipped by a
table or a dialog and flips above the button when there is no room below; other
browsers get plain positioning. Picking an item sends its own message and closes
the menu.
-}
view : (Msg -> msg) -> List (Attribute msg) -> State -> Html msg
view toMsg attributes ((State state) as current) =
    let
        config =
            configure attributes

        triggerBase =
            [ Button.id (triggerId state.id)
            , Button.expanded state.open
            , Button.htmlAttrs
                [ Attr.attribute "aria-haspopup" "menu"
                , Internal.onKeys [ ( "ArrowDown", toMsg Open ) ]
                ]
            , Button.onClick (toMsg Toggle)
            ]

        triggerView =
            case config.kebabLabel of
                Just accessibleName ->
                    Button.iconOnly (Button.ghost :: config.triggerAttrs ++ triggerBase) Icon.moreVertical accessibleName

                Nothing ->
                    Button.view (Button.iconRight Icon.chevronDown :: config.triggerAttrs ++ triggerBase) config.label
    in
    Html.div [ Internal.cls [ "klar-anchor", "klar-menu" ] ]
        [ triggerView
        , if state.open then
            viewPopup toMsg config current

          else
            Html.text ""
        ]


viewPopup : (Msg -> msg) -> Config msg -> State -> Html msg
viewPopup toMsg config (State state) =
    let
        entries =
            List.indexedMap Tuple.pair config.items

        enabled =
            entries
                |> List.filterMap
                    (\( index, entry ) ->
                        case entry of
                            Action action ->
                                if action.disabled then
                                    Nothing

                                else
                                    Just ( index, action )

                            _ ->
                                Nothing
                    )

        enabledIndices =
            List.map Tuple.first enabled

        highlightedAction =
            enabled
                |> List.filter (\( index, _ ) -> index == state.highlighted)
                |> List.head
                |> Maybe.map Tuple.second

        activateKeys =
            case highlightedAction of
                Just action ->
                    [ ( "Enter", action.onClick ), ( " ", action.onClick ) ]

                Nothing ->
                    []

        navigationKeys =
            List.filterMap identity
                [ Just ( "ArrowDown", toMsg (Step 1 enabledIndices) )
                , Just ( "ArrowUp", toMsg (Step -1 enabledIndices) )
                , Maybe.map (\i -> ( "Home", toMsg (Jump i enabledIndices) )) (List.head enabledIndices)
                , Maybe.map (\i -> ( "End", toMsg (Jump i enabledIndices) )) (List.head (List.reverse enabledIndices))
                ]
    in
    Html.div
        [ Internal.cls [ "klar-layer" ]
        , Events.onClick (toMsg Close)
        , Internal.onKeysPassive
            [ ( "Escape", toMsg Close )
            , ( "Tab", toMsg CloseQuiet )
            , ( "Shift+Tab", toMsg CloseQuiet )
            , ( "Enter", toMsg Close )
            , ( " ", toMsg Close )
            ]
        ]
        [ Html.div
            [ Internal.cls
                [ "klar-popup"
                , "klar-menu__popup"
                , if config.alignEnd then
                    "klar-popup--end"

                  else
                    ""
                ]
            , Attr.id (popupId state.id)
            , Attr.tabindex -1
            , Attr.attribute "role" "menu"
            , if state.highlighted >= 0 then
                Attr.attribute "aria-activedescendant" (optionId state.id state.highlighted)

              else
                Internal.noAttr
            , Internal.onKeys (activateKeys ++ navigationKeys)
            ]
            (List.map (viewEntry toMsg state.id state.highlighted) entries)
        ]


viewEntry : (Msg -> msg) -> String -> Int -> ( Int, Item msg ) -> Html msg
viewEntry toMsg id highlighted ( index, entry ) =
    case entry of
        Separator ->
            Html.div [ Internal.cls [ "klar-menu__separator" ], Attr.attribute "role" "separator" ] []

        Heading text ->
            Html.div [ Internal.cls [ "klar-menu__heading" ], Attr.attribute "role" "presentation" ] [ Html.text text ]

        Action action ->
            Html.div
                [ Internal.cls
                    [ "klar-menu__item"
                    , if index == highlighted then
                        "klar-menu__item--highlighted"

                      else
                        ""
                    , if action.danger then
                        "klar-menu__item--danger"

                      else
                        ""
                    , if action.disabled then
                        "klar-menu__item--disabled"

                      else
                        ""
                    ]
                , Attr.id (optionId id index)
                , Attr.attribute "role" "menuitem"
                , Internal.attrIf action.disabled (Attr.attribute "aria-disabled" "true")
                , if action.disabled then
                    Internal.onClickStop (toMsg Noop)

                  else
                    Events.onClick action.onClick

                -- A disabled item is never highlighted, not even under the pointer.
                , if action.disabled then
                    Internal.noAttr

                  else
                    Events.onMouseEnter (toMsg (Highlight index))
                ]
                [ Html.span [ Internal.cls [ "klar-menu__icon" ] ]
                    [ Internal.viewMaybe Icon.view action.icon ]
                , Html.span [ Internal.cls [ "klar-menu__label" ], Internal.attrIf (String.length action.label > 28) (Attr.title action.label) ] [ Html.text action.label ]
                , Internal.viewMaybe
                    (\hint -> Html.span [ Internal.cls [ "klar-menu__hint" ] ] [ Html.text hint ])
                    action.hint
                ]


{-| The next enabled index after `current` in direction `step` (wraps around).
-}
neighbour : Int -> List Int -> Int -> Maybe Int
neighbour step enabledIndices current =
    case enabledIndices of
        [] ->
            Nothing

        _ ->
            let
                ordered =
                    if step > 0 then
                        enabledIndices

                    else
                        List.reverse enabledIndices

                beyond =
                    ordered
                        |> List.filter
                            (\i ->
                                if step > 0 then
                                    i > current

                                else
                                    i < current
                            )
            in
            case beyond of
                first :: _ ->
                    Just first

                [] ->
                    List.head ordered
