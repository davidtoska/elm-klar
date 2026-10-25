module Klar.Menu exposing
    ( view
    , State, Msg, init, update, isOpen, open, close, triggerId
    , Item, item, separator, heading, withIcon, withShortcut, withHint, danger, disabledItem
    , Attribute, items, label, kebab, trigger, alignEnd, platform
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
    import Klar.Shortcut as Shortcut

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
            , Menu.item "Duplicate" DuplicateOrder |> Menu.withShortcut (Shortcut.mod (Shortcut.char 'd'))
            , Menu.separator
            , Menu.item "Delete" DeleteOrder |> Menu.danger |> Menu.withIcon Icon.trash
            ]
        ]
        model.rowMenu

Clicking an item sends the item's own message and closes the menu.

**Keyboard.** The button opens the menu with `Enter`, `Space` or `ArrowDown` with
the first item highlighted, and with `ArrowUp` with the last one; a click with
the pointer opens it with nothing highlighted. Focus moves into the menu: the
arrow keys move the highlight (and wrap around), `Home` and `End` jump to the
first and last item, typing a letter jumps to the next item whose label starts
with the letters typed (a space typed right after letters is part of the text),
`Enter` or `Space` pick the highlighted item, and `Escape` or `Tab` close the
menu. The menu prevents the default of the `Escape` it handles, so a drawer
around it or an `Escape` shortcut can ignore that key. A click anywhere outside the menu closes it
too. When the menu closes, it gives focus back to its button, except after `Tab`
and `Shift+Tab`: they leave the menu like any other element, `Tab` for the next
element on the page and `Shift+Tab` for the button. Disabled items are skipped. A
long menu scrolls, and the keys scroll the highlighted item into view (the
pointer does not: an item under it can be seen).

**Screen readers** get a `menu` named after its button, with `menuitem` entries;
the items under a `heading` are a `group` named after the heading, and a
shortcut (`withShortcut`) is announced as `aria-keyshortcuts`.

Every menu needs a `State` and an id of its own. The menu has no built-in text,
so there is no `locale`: the labels come from your application.
[Klar.Modal](Klar-Modal) describes the rules that all popups share.

If an item opens a dialog, give the dialog to
[`Overlay.host`](Klar-Overlay#host) and name the menu's button as the opener
(`Modal.open (Menu.triggerId model.rowMenu)`): the page behind the dialog is then
`inert`, so closing the menu, which gives focus back to its button, cannot take
focus away from the dialog, and focus goes back to the button when the dialog
closes.


# View

@docs view


# State

@docs State, Msg, init, update, isOpen, open, close, triggerId


# Items

@docs Item, item, separator, heading, withIcon, withShortcut, withHint, danger, disabledItem


# Attributes

@docs Attribute, items, label, kebab, trigger, alignEnd, platform

-}

import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Events
import Json.Decode as Decode exposing (Decoder)
import Klar.Button as Button
import Klar.Icon as Icon exposing (Icon)
import Klar.Internal as Internal
import Klar.Kbd as Kbd
import Klar.Kbd.Aria as Aria
import Klar.Menu.Core exposing (Highlight(..), MenuMsg(..), MenuState(..), openWith, popupId, triggerIdOf)
import Klar.Menu.Scroll as Scroll
import Klar.Menu.TypeAhead as TypeAhead
import Klar.Shortcut exposing (Keys)
import Process
import Task



-- STATE


{-| The state of one menu: whether it is open and which item is highlighted.
Create it with `init`, keep it in your model (one per menu), and change it with
`open`, `close` and `update`. It is opaque; a compiler message may call it
`Klar.Menu.Core.MenuState`, which is this same type.
-}
type alias State =
    MenuState


{-| A closed menu. The id must be unique on the page; the ids of the button, the
popup and the items start with it (the button's is `triggerId`).
-}
init : String -> State
init id =
    MenuState { id = id, open = False, highlight = NoItem, typed = "", typedAt = 0 }


{-| Is the menu open?
-}
isOpen : State -> Bool
isOpen (MenuState state) =
    state.open


{-| The DOM id of the button that opens the menu. Give it to `Modal.open` (or
`Drawer.open`, `ConfirmDialog.open`) when an item opens a dialog, so that focus
goes back to the button when the dialog closes.

    OpenDeleteDialog ->
        ( { model | confirm = ConfirmDialog.open (Menu.triggerId model.rowMenu) model.confirm }, Cmd.none )

-}
triggerId : State -> String
triggerId (MenuState state) =
    triggerIdOf state.id


{-| The messages of the menu (opening, closing, moving the highlight). Wrap it in
a constructor of your own message type, such as `MenuMsg Menu.Msg`, and hand it
to `update`. A compiler message may call it `Klar.Menu.Core.MenuMsg`, which is
this same type.
-}
type alias Msg =
    MenuMsg


{-| Handles opening and closing the menu and moving the highlight, and scrolls a
long menu to the highlighted item. Map its command into your own message with
`Cmd.map`. Picking an item does not go through here: it sends the message of the
item.
-}
update : Msg -> State -> ( State, Cmd Msg )
update msg ((MenuState state) as current) =
    case msg of
        Toggle target ->
            if state.open then
                close current

            else
                openWith target current

        OpenWith target ->
            openWith target current

        Close ->
            close current

        -- `Tab` leaves the menu: the browser moves focus on, and the menu must
        -- not pull it back to the button.
        CloseQuiet ->
            ( MenuState { state | open = False, highlight = NoItem, typed = "" }, Cmd.none )

        -- The pointer is over the item: it can be seen, so the list stays put.
        Hover index ->
            ( MenuState { state | highlight = Index index }, Cmd.none )

        -- Relative to the highlight in the model, not to the one the page was
        -- last drawn with: arrow keys that come faster than a redraw add up.
        Step direction enabledIndices ->
            case neighbour direction enabledIndices (resolve enabledIndices state.highlight |> Maybe.withDefault -1) of
                Just index ->
                    ( MenuState { state | highlight = Index index, typed = "" }, bringIntoView state.id enabledIndices index )

                Nothing ->
                    ( current, Cmd.none )

        -- `Home` and `End`: the first or the last item that can be picked.
        Jump index enabledIndices ->
            ( MenuState { state | highlight = Index index, typed = "" }, bringIntoView state.id enabledIndices index )

        -- A printable key: the typed letters so far, and the items that can be
        -- picked with their labels. The letters are forgotten after a pause.
        Type letter labelled ->
            let
                typed =
                    state.typed ++ letter

                from =
                    resolve (List.map Tuple.first labelled) state.highlight |> Maybe.withDefault -1

                counter =
                    state.typedAt + 1

                forget =
                    Process.sleep 700 |> Task.perform (\_ -> TypedTimeout counter)
            in
            case TypeAhead.find { typed = typed, from = from } labelled of
                Just index ->
                    ( MenuState { state | highlight = Index index, typed = typed, typedAt = counter }
                    , Cmd.batch [ bringIntoView state.id (List.map Tuple.first labelled) index, forget ]
                    )

                Nothing ->
                    ( MenuState { state | typed = typed, typedAt = counter }, forget )

        TypedTimeout counter ->
            if counter == state.typedAt then
                ( MenuState { state | typed = "" }, Cmd.none )

            else
                ( current, Cmd.none )

        Noop ->
            ( current, Cmd.none )


{-| Opens the menu with the first item that can be picked highlighted, as the
keyboard opens it, and moves keyboard focus into it. Use it to open the menu from
your own code, from a keyboard shortcut for example.
-}
open : State -> ( State, Cmd Msg )
open =
    openWith FirstItem


{-| Closes the menu and gives focus back to its button. The menu closes by itself
when the user picks an item, clicks outside it or presses `Escape`; `Tab` closes
it too, but lets focus move on to the next element instead.
-}
close : State -> ( State, Cmd Msg )
close (MenuState state) =
    ( MenuState { state | open = False, highlight = NoItem, typed = "" }
    , if state.open then
        Internal.focus (triggerIdOf state.id) Noop

      else
        Cmd.none
    )


{-| The index of the highlighted item among the items that can be picked, or
`Nothing`: an index that is no longer one of them (the items changed while the
menu was open) highlights nothing.
-}
resolve : List Int -> Highlight -> Maybe Int
resolve enabledIndices highlight =
    case highlight of
        NoItem ->
            Nothing

        FirstItem ->
            List.head enabledIndices

        LastItem ->
            List.head (List.reverse enabledIndices)

        Index index ->
            if List.member index enabledIndices then
                Just index

            else
                Nothing


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


optionId : String -> Int -> String
optionId id index =
    id ++ "-item-" ++ String.fromInt index


headingId : String -> Int -> String
headingId id index =
    id ++ "-heading-" ++ String.fromInt index



-- ITEMS


{-| One entry of the menu: an action, a separator or a heading. Make them with
`item`, `separator` and `heading`, and refine an action with `withIcon`,
`withShortcut`, `withHint`, `danger` and `disabledItem`.
-}
type Item msg
    = Action (ActionConfig msg)
    | Separator
    | Heading String


type alias ActionConfig msg =
    { label : String
    , onClick : msg
    , icon : Maybe Icon
    , shortcut : Maybe Keys
    , hint : Maybe String
    , danger : Bool
    , disabled : Bool
    }


{-| A menu entry that sends `msg` when picked: `Menu.item "Edit" EditOrder`. Keep
labels short; a long one is cut off with an ellipsis.
-}
item : String -> msg -> Item msg
item text msg =
    Action { label = text, onClick = msg, icon = Nothing, shortcut = Nothing, hint = Nothing, danger = False, disabled = False }


{-| A thin line between two groups of items.
-}
separator : Item msg
separator =
    Separator


{-| A small caption above a group of items. It cannot be picked or highlighted.
The items after it, up to the next heading or separator, are a `group` that
screen readers name after it ("Danger zone").
-}
heading : String -> Item msg
heading =
    Heading


{-| An icon before the label of an action. This function and `withShortcut`,
`withHint`, `danger` and `disabledItem` change an action and leave a separator
or a heading as it is.

    Menu.item "Edit" EditOrder |> Menu.withIcon Icon.edit

-}
withIcon : Icon -> Item msg -> Item msg
withIcon icon =
    mapAction (\action -> { action | icon = Just icon })


{-| The keyboard shortcut of the action, drawn as small key caps at the right of
the item, for the keyboard of `platform`, and announced to screen readers as
`aria-keyshortcuts`. It is the same typed value that
[Klar.Shortcut](Klar-Shortcut) listens to, so the hint cannot disagree with the
shortcut; the menu only shows it, the application installs the shortcut.

    Menu.item "Duplicate" DuplicateOrder
        |> Menu.withShortcut (Shortcut.mod (Shortcut.char 'd'))

-}
withShortcut : Keys -> Item msg -> Item msg
withShortcut keys =
    mapAction (\action -> { action | shortcut = Just keys })


{-| Right-aligned gray text after the label, for a short note that is not a
shortcut ("3 left", "Beta"). It is part of the item's name for screen readers.
Use `withShortcut` for a keyboard shortcut.
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
    , platform : Kbd.Platform
    }


configure : List (Attribute msg) -> Config msg
configure attributes =
    List.foldl (\(Attribute change) config -> change config)
        { label = ""
        , kebabLabel = Nothing
        , items = []
        , triggerAttrs = []
        , alignEnd = False
        , platform = Kbd.pc
        }
        attributes


{-| Text on the button that opens the menu, followed by a small down arrow. It is
not used with `kebab`; without a label or `kebab` the button has no accessible
name. The menu is named after its button for screen readers.
-}
label : String -> Attribute msg
label text =
    Attribute (\config -> { config | label = text })


{-| An icon-only "more" button with three vertical dots instead of the text
button. The `String` is its accessible name and its tooltip, so it must say what
the menu is for, such as "Order actions". The button looks like a `ghost` button
unless you style it with `trigger`.
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
the click and key handlers of the button belong to the menu; do not give it a
`Button.onClick`, which would take the click from the menu. A button made
`Button.ariaDisabled`, `Button.loading` or `Button.disabled` does not open the
menu, with the pointer or the keyboard.
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


{-| The keyboard that the shortcuts of `withShortcut` are drawn for: `Kbd.pc` (the
default: Ctrl, Alt, Shift) or `Kbd.mac` (⌘ ⌥ ⇧). See
[`Kbd.platformFromUserAgent`](Klar-Kbd#platformFromUserAgent).
-}
platform : Kbd.Platform -> Attribute msg
platform value =
    Attribute (\config -> { config | platform = value })



-- VIEW


{-| The button and, while open, the menu; `toMsg` wraps the messages of the menu.
Where the browser supports CSS anchor positioning, the menu is never clipped by a
table or a dialog and flips above the button when there is no room below; other
browsers get plain positioning. Picking an item sends its own message and closes
the menu.
-}
view : (Msg -> msg) -> List (Attribute msg) -> State -> Html msg
view toMsg attributes ((MenuState state) as current) =
    let
        config =
            configure attributes

        triggerBase =
            [ Button.id (triggerIdOf state.id)
            , Button.expanded state.open
            , Button.htmlAttrs
                [ Attr.attribute "aria-haspopup" "menu"

                -- the popup exists only while the menu is open
                , Internal.attrIf state.open (Attr.attribute "aria-controls" (popupId state.id))
                , Events.on "click" (whenActive (triggerClick toMsg))
                , Events.preventDefaultOn "keydown" (whenActive (triggerKeys toMsg))
                ]
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


{-| A click on the button. A click made with the keyboard (`Enter` or `Space`,
which the browser turns into a click with `detail` 0) opens the menu with the
first item highlighted, as the keyboard does; a click with the pointer highlights
nothing.
-}
triggerClick : (Msg -> msg) -> Decoder msg
triggerClick toMsg =
    Decode.oneOf [ Decode.field "detail" Decode.int, Decode.succeed 1 ]
        |> Decode.map
            (\detail ->
                toMsg
                    (Toggle
                        (if detail == 0 then
                            FirstItem

                         else
                            NoItem
                        )
                    )
            )


{-| `ArrowDown` opens the menu at the first item, `ArrowUp` at the last one.
-}
triggerKeys : (Msg -> msg) -> Decoder ( msg, Bool )
triggerKeys toMsg =
    Internal.keyEvent
        |> Decode.andThen
            (\event ->
                if event.ctrl || event.meta || event.alt || event.shift then
                    Decode.fail "a key with a modifier"

                else
                    case event.key of
                        "ArrowDown" ->
                            Decode.succeed ( toMsg (OpenWith FirstItem), True )

                        "ArrowUp" ->
                            Decode.succeed ( toMsg (OpenWith LastItem), True )

                        _ ->
                            Decode.fail "not a key of the button"
            )


{-| The handlers of the button are its own (`Button.htmlAttrs`), so they run
whatever the button looks like: they read from the button itself whether it is
drawn unavailable (`Button.ariaDisabled`, `Button.loading`), and then do nothing.
-}
whenActive : Decoder a -> Decoder a
whenActive decoder =
    Decode.oneOf [ Decode.at [ "currentTarget", "className" ] Decode.string, Decode.succeed "" ]
        |> Decode.andThen
            (\className ->
                let
                    names =
                        String.words className
                in
                if List.member "klar-button--disabled" names || List.member "klar-button--loading" names then
                    Decode.fail "the button is unavailable"

                else
                    decoder
            )


viewPopup : (Msg -> msg) -> Config msg -> State -> Html msg
viewPopup toMsg config (MenuState state) =
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

        highlighted =
            resolve enabledIndices state.highlight

        highlightedAction =
            enabled
                |> List.filter (\( index, _ ) -> Just index == highlighted)
                |> List.head
                |> Maybe.map Tuple.second

        -- While letters are being typed, a space is part of the text ("save a").
        typing =
            state.typed /= ""

        activateKeys =
            case highlightedAction of
                Just action ->
                    ( "Enter", action.onClick )
                        :: (if typing then
                                []

                            else
                                [ ( " ", action.onClick ) ]
                           )

                Nothing ->
                    []

        navigationKeys =
            List.filterMap identity
                [ Just ( "ArrowDown", toMsg (Step 1 enabledIndices) )
                , Just ( "ArrowUp", toMsg (Step -1 enabledIndices) )
                , Maybe.map (\i -> ( "Home", toMsg (Jump i enabledIndices) )) (List.head enabledIndices)
                , Maybe.map (\i -> ( "End", toMsg (Jump i enabledIndices) )) (List.head (List.reverse enabledIndices))
                ]

        labelled =
            List.map (\( index, action ) -> ( index, action.label )) enabled

        context =
            { toMsg = toMsg, id = state.id, highlighted = highlighted, platform = config.platform }
    in
    Html.div
        [ Internal.cls [ "klar-layer" ]
        , Events.onClick (toMsg Close)

        -- The menu handles Escape, so it prevents the default: a drawer, a page
        -- handler or an Escape shortcut ignores a key whose default is prevented.
        -- Tab closes the menu but lets focus move on.
        , Events.preventDefaultOn "keydown"
            (Decode.oneOf
                [ keyBindings
                    (( "Escape", toMsg Close )
                        :: ( "Enter", toMsg Close )
                        :: (if typing then
                                []

                            else
                                [ ( " ", toMsg Close ) ]
                           )
                    )
                , Internal.keyEvent
                    |> Decode.andThen
                        (\event ->
                            if event.key == "Tab" && not (event.ctrl || event.meta || event.alt) then
                                Decode.succeed ( toMsg CloseQuiet, False )

                            else
                                Decode.fail "not a key of the menu"
                        )
                ]
            )
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
            , Attr.attribute "aria-labelledby" (triggerIdOf state.id)
            , Internal.attrMaybe (\index -> Attr.attribute "aria-activedescendant" (optionId state.id index)) highlighted
            , Events.preventDefaultOn "keydown"
                (Decode.oneOf
                    [ keyBindings (activateKeys ++ navigationKeys)
                    , typeAhead typing (\letter -> toMsg (Type letter labelled))
                    ]
                )
            ]
            (viewEntries context entries)
        ]


{-| The keys of the open menu, with the browser default prevented. The names are
those of `Internal.onKeys`: `"ArrowDown"`, `"Enter"`, `" "`.
-}
keyBindings : List ( String, msg ) -> Decoder ( msg, Bool )
keyBindings bindings =
    Internal.keyEvent
        |> Decode.andThen
            (\event ->
                if event.ctrl || event.meta || event.alt || event.shift then
                    Decode.fail "a key with a modifier"

                else
                    case List.filter (\( name, _ ) -> name == event.key) bindings of
                        ( _, msg ) :: _ ->
                            Decode.succeed ( msg, True )

                        [] ->
                            Decode.fail "not a key of the menu"
            )


{-| A printable key without Ctrl, Cmd or Alt moves the highlight to the next item
whose label starts with the letters typed so far. A space is part of the text only
while letters are being typed (`typing`); otherwise it picks the highlighted item.
-}
typeAhead : Bool -> (String -> msg) -> Decoder ( msg, Bool )
typeAhead typing toMsg =
    Internal.keyEvent
        |> Decode.andThen
            (\event ->
                if event.ctrl || event.meta || event.alt || String.length event.key /= 1 || (event.key == " " && not typing) then
                    Decode.fail "not a letter"

                else
                    Decode.succeed ( toMsg event.key, True )
            )


type alias Context msg =
    { toMsg : Msg -> msg
    , id : String
    , highlighted : Maybe Int
    , platform : Kbd.Platform
    }


{-| The entries in order. A heading and the items after it, up to the next
heading or separator, are one `group` named by the heading.
-}
viewEntries : Context msg -> List ( Int, Item msg ) -> List (Html msg)
viewEntries context entries =
    case entries of
        [] ->
            []

        ( index, Heading text ) :: rest ->
            let
                ( inGroup, after ) =
                    leadingActions [] rest
            in
            Html.div
                [ Internal.cls [ "klar-menu__group" ]
                , Attr.attribute "role" "group"
                , Attr.attribute "aria-labelledby" (headingId context.id index)
                ]
                (Html.div
                    [ Internal.cls [ "klar-menu__heading" ]
                    , Attr.id (headingId context.id index)

                    -- the group is named by it; read on its own it would be read twice
                    , Attr.attribute "aria-hidden" "true"
                    ]
                    [ Html.text text ]
                    :: List.map (viewEntry context) inGroup
                )
                :: viewEntries context after

        entry :: rest ->
            viewEntry context entry :: viewEntries context rest


leadingActions : List ( Int, Item msg ) -> List ( Int, Item msg ) -> ( List ( Int, Item msg ), List ( Int, Item msg ) )
leadingActions taken entries =
    case entries of
        (( _, Action _ ) as entry) :: rest ->
            leadingActions (entry :: taken) rest

        _ ->
            ( List.reverse taken, entries )


viewEntry : Context msg -> ( Int, Item msg ) -> Html msg
viewEntry context ( index, entry ) =
    case entry of
        Separator ->
            Html.div [ Internal.cls [ "klar-menu__separator" ], Attr.attribute "role" "separator" ] []

        Heading text ->
            Html.div [ Internal.cls [ "klar-menu__heading" ], Attr.attribute "role" "presentation" ] [ Html.text text ]

        Action action ->
            Html.div
                [ Internal.cls
                    [ "klar-menu__item"
                    , if context.highlighted == Just index then
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
                , Attr.id (optionId context.id index)
                , Attr.attribute "role" "menuitem"
                , Internal.attrIf action.disabled (Attr.attribute "aria-disabled" "true")
                , Internal.attrMaybe (Attr.attribute "aria-keyshortcuts")
                    (action.shortcut |> Maybe.andThen (Aria.keyShortcuts { mac = context.platform == Kbd.mac }))
                , if action.disabled then
                    Internal.onClickStop (context.toMsg Noop)

                  else
                    Events.onClick action.onClick

                -- A disabled item is never highlighted, not even under the pointer.
                , if action.disabled then
                    Internal.noAttr

                  else
                    Events.onMouseEnter (context.toMsg (Hover index))
                ]
                [ Html.span [ Internal.cls [ "klar-menu__icon" ] ]
                    [ Internal.viewMaybe Icon.view action.icon ]
                , Html.span [ Internal.cls [ "klar-menu__label" ], Internal.attrIf (String.length action.label > 28) (Attr.title action.label) ] [ Html.text action.label ]
                , Internal.viewMaybe
                    (\hint -> Html.span [ Internal.cls [ "klar-menu__hint" ] ] [ Html.text hint ])
                    action.hint
                , Internal.viewMaybe
                    (\keys ->
                        -- the item says it with aria-keyshortcuts; its name stays the label
                        Html.span [ Internal.cls [ "klar-menu__hint", "klar-menu__keys" ], Attr.attribute "aria-hidden" "true" ]
                            [ Kbd.view [ Kbd.small, Kbd.platform context.platform ] keys ]
                    )
                    action.shortcut
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
