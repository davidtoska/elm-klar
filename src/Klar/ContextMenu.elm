module Klar.ContextMenu exposing
    ( view
    , Attribute, ariaLabel, locale
    , area, attrs
    , State, Msg, init, update, isOpen, target, openFor, close
    )

{-| The menu that opens where the user right-clicks. One menu serves many
elements (the cards of a board, the items of a list): each element says what it
stands for, and the menu is built from that.

Use when: one menu must open where the user right-clicks and serve many elements, such as the cards of a board or the items of a list.
Do not use when: the menu opens from a button only (use `Klar.Menu`), or the elements are the rows of a `Klar.Table` (its row menu already opens on a right-click and the context menu key) or the nodes of a `Klar.Tree`.
Quick path: `init`, `area`, `view`, `update`, `close`

    import Klar.ContextMenu as ContextMenu
    import Klar.Menu as Menu

    -- model:   context : ContextMenu.State Order      (ContextMenu.init "order-context")

    -- every card (right click, or the context menu key, opens the menu)
    ContextMenu.area ContextMsg model.context { id = "order-" ++ order.id, target = order } [ cardContent ]

    -- or, on an element you build yourself
    Html.li (Attr.id ("order-" ++ order.id) :: Attr.tabindex 0 :: ContextMenu.attrs ContextMsg order) (orderLine order)

    -- once, anywhere: the menu. The items come from the order that was clicked.
    ContextMenu.view ContextMsg
        [ ContextMenu.ariaLabel "Order actions" ]
        (\order ->
            [ Menu.item "Open" (OpenOrder order) |> Menu.withIcon Icon.externalLink
            , Menu.item "Edit" (EditOrder order) |> Menu.withIcon Icon.edit
            , Menu.separator
            , Menu.item "Delete" (AskDelete order) |> Menu.withIcon Icon.trash |> Menu.danger
            ]
        )
        model.context

    -- update
    ContextMsg m ->
        let
            ( context, cmd ) =
                ContextMenu.update m model.context
        in
        ( { model | context = context }, Cmd.map ContextMsg cmd )

The items are the ones of [Klar.Menu](Klar-Menu) (`Menu.item`, `Menu.separator`,
`Menu.heading`, `Menu.danger`, `Menu.withIcon`, `Menu.withHint` ...), and the
keyboard works as in a menu: arrows, `Home`, `End`, `Enter` or `Space` to pick,
`Escape` or `Tab` to close (focus goes back to the element). A long menu
scrolls, and the keys keep the highlighted item in view. A click outside closes
it (a right-click too, without opening another menu), and so does the mouse
wheel, except over a menu that scrolls. Where the browser supports CSS anchor
positioning, the menu opens towards the free side near the edges of the window.
The menu's name for a screen reader is `ariaLabel` ("Actions" by default, in the
language of `locale`). [Klar.Modal](Klar-Modal) describes the rules that all
popups share.

**The browser's own menu** stays where it is needed: a right-click in a text
field, a text area or an editable element inside an area opens the browser's
menu (paste, spelling), and so does a right-click with `Shift` held, anywhere.

The value `a` identifies the element (a record, an id). It is compared with
`==` to mark the right-clicked element as active, so it must not contain
functions.

For the keyboard, an `area` can take focus (`Tab`, so each one is one more tab
stop); the context menu key or `Shift+F10` opens the menu for it and focus
returns to it when the menu closes. In a long list that has its own arrow-key
focus, put `attrs` on the items instead and give them `tabindex` yourself. A
"⋯" button or a keyboard shortcut opens the same menu with `openFor`.

When a menu item opens a dialog, give the dialog to
[`Overlay.host`](Klar-Overlay#host): the page behind it is then `inert`, so closing
the menu cannot take focus back from the dialog (the same holds for
[Klar.Menu](Klar-Menu)).


# View

@docs view


# Attributes

@docs Attribute, ariaLabel, locale


# Elements that open the menu

@docs area, attrs


# State

@docs State, Msg, init, update, isOpen, target, openFor, close

-}

import Browser.Dom as Dom
import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Events
import Json.Decode as Decode exposing (Decoder)
import Klar.Button as Button
import Klar.Internal as Internal
import Klar.Locale as Locale exposing (Locale)
import Klar.Menu as Menu
import Task



-- STATE


{-| The state of the context menu: whether it is open, which element it was
opened for (the `a`) and where on the screen. Create it with `init`, keep it in
your model, and change it with `close` and `update`.
-}
type State a
    = State
        { id : String
        , menu : Menu.State
        , target : Maybe a
        , x : Int
        , y : Int
        , restore : String
        }


{-| A closed menu. The id must be unique on the page; the ids of the parts of the
menu start with it.
-}
init : String -> State a
init id =
    State { id = id, menu = Menu.init id, target = Nothing, x = 0, y = 0, restore = "" }


{-| Is the menu open?
-}
isOpen : State a -> Bool
isOpen (State state) =
    Menu.isOpen state.menu


{-| What the menu was opened for (the `target` of the `area`, or the value given
to `attrs` or `openFor`), while it is open; `Nothing` when it is closed.
-}
target : State a -> Maybe a
target (State state) =
    if Menu.isOpen state.menu then
        state.target

    else
        Nothing


{-| The messages of the context menu. Wrap it in a constructor of your own
message type, such as `ContextMsg (ContextMenu.Msg Order)`, and hand it to
`update`.
-}
type Msg a
    = OpenAt a Pointer
    | MenuMsg Menu.Msg
    | Dismiss
    | Noop


type alias Pointer =
    { x : Int
    , y : Int
    , width : Int
    , height : Int
    , restore : String
    }


{-| Handles opening at the pointer, the menu keys and closing. Map its command
into your own message with `Cmd.map`.
-}
update : Msg a -> State a -> ( State a, Cmd (Msg a) )
update msg ((State state) as current) =
    case msg of
        OpenAt what pointer ->
            let
                ( menu, cmd ) =
                    Menu.open state.menu
            in
            ( State
                { state
                    | menu = menu
                    , target = Just what
                    , x = clamp 0 (max 0 (pointer.width - 8)) pointer.x
                    , y = clamp 0 (max 0 (pointer.height - 8)) pointer.y
                    , restore = pointer.restore
                }
            , Cmd.map MenuMsg cmd
            )

        MenuMsg inner ->
            let
                ( menu, cmd ) =
                    Menu.update inner state.menu

                closed =
                    Menu.isOpen state.menu && not (Menu.isOpen menu)
            in
            ( State { state | menu = menu }
            , Cmd.batch
                [ Cmd.map MenuMsg cmd
                , if closed then
                    restoreFocus state.restore

                  else
                    Cmd.none
                ]
            )

        Dismiss ->
            close current

        Noop ->
            ( current, Cmd.none )


{-| Opens the menu for `what` just below the element with this DOM id, as if it had
been right-clicked there: for a "⋯" button in a card, or a keyboard shortcut
that opens the menu of the selected item. Focus goes back to that element when
the menu closes. Nothing happens if no element has the id.

    OpenCardMenu order ->
        let
            ( context, cmd ) =
                ContextMenu.openFor ("order-" ++ order.id ++ "-more") order model.context
        in
        ( { model | context = context }, Cmd.map ContextMsg cmd )

-}
openFor : String -> a -> State a -> ( State a, Cmd (Msg a) )
openFor id what current =
    ( current
    , Dom.getElement id
        |> Task.attempt
            (\result ->
                case result of
                    Ok found ->
                        OpenAt what
                            { x = round (found.element.x - found.viewport.x)
                            , y = round (found.element.y - found.viewport.y + found.element.height)
                            , width = round found.viewport.width
                            , height = round found.viewport.height
                            , restore = id
                            }

                    Err _ ->
                        Noop
            )
    )


{-| Closes the menu and gives focus back to the element it was opened from (or,
if that element has no id, to the start of the page content of an
[`AppShell`](Klar-AppShell) or [`Overlay.host`](Klar-Overlay#host), so that
focus does not fall to the top of the page). The menu closes by itself when the
user picks an item, clicks outside it or presses `Escape`; call this when
something else should close it.
-}
close : State a -> ( State a, Cmd (Msg a) )
close (State state) =
    let
        ( menu, cmd ) =
            Menu.close state.menu
    in
    ( State { state | menu = menu }
    , Cmd.batch
        [ Cmd.map MenuMsg cmd
        , if Menu.isOpen state.menu then
            restoreFocus state.restore

          else
            Cmd.none
        ]
    )


{-| Focus goes back to the element the menu came from, or else to the start of
the page content: the menu that had focus is removed, and focus must not fall to
the body.
-}
restoreFocus : String -> Cmd (Msg a)
restoreFocus id =
    Internal.focusFirst (List.filter ((/=) "") [ id ] ++ [ Internal.pageStartId ]) Noop



-- OPENING


{-| Attributes that make an element open the menu for `what` when it is
right-clicked, or when the context menu key (or `Shift+F10`) is pressed on it;
the browser's own context menu is suppressed, except in a text field and with
`Shift` held. When the menu closes, focus goes back to the element that had
focus when it opened, or else to the element that carries these attributes,
provided that element has an `id`. For the keyboard the element must be able to
take focus (add `tabindex` yourself; an `area` has it already), and with nested
elements only the innermost one opens its menu.
-}
attrs : (Msg a -> msg) -> a -> List (Html.Attribute msg)
attrs toMsg what =
    [ Events.custom "contextmenu"
        (keepsBrowserMenu
            |> Decode.andThen
                (\keep ->
                    if keep then
                        Decode.fail "the browser's own menu"

                    else
                        pointerDecoder
                )
            |> Decode.map
                (\pointer ->
                    { message = toMsg (OpenAt what pointer)
                    , stopPropagation = True
                    , preventDefault = True
                    }
                )
        )
    ]


{-| A box that opens the menu for `target` when it, or anything inside it, is
right-clicked. It can take focus with `Tab` (the context menu key or `Shift+F10`
then opens the menu, which `aria-keyshortcuts` tells a screen reader), and it is
highlighted while the menu is open for it. The `id` must be unique on the page:
it lets the box take focus back when the menu closes.
-}
area : (Msg a -> msg) -> State a -> { id : String, target : a } -> List (Html msg) -> Html msg
area toMsg (State state) options children =
    Html.div
        (Internal.classes
            [ ( "klar-context-area", True )
            , ( "klar-context-area--active", Menu.isOpen state.menu && state.target == Just options.target )
            ]
            :: Attr.id options.id
            :: Attr.tabindex 0
            :: Attr.attribute "aria-keyshortcuts" "Shift+F10"
            :: attrs toMsg options.target
        )
        children


{-| A right-click in a text field (paste, spelling suggestions) or with `Shift`
held keeps the browser's own menu. A press of the context menu key or
`Shift+F10` is not a mouse button, so it still opens this menu.
-}
keepsBrowserMenu : Decoder Bool
keepsBrowserMenu =
    Decode.map3 (\inText shift button -> inText || (shift && button == 2))
        (Decode.oneOf [ Decode.field "target" textTarget, Decode.succeed False ])
        (Decode.oneOf [ Decode.field "shiftKey" Decode.bool, Decode.succeed False ])
        (Decode.oneOf [ Decode.field "button" Decode.int, Decode.succeed 0 ])


textTarget : Decoder Bool
textTarget =
    Decode.map3
        (\tag kind editable ->
            editable
                || (tag == "TEXTAREA")
                || (tag == "INPUT" && not (List.member kind [ "checkbox", "radio", "button", "submit", "reset", "image", "range", "color", "file" ]))
        )
        (Decode.oneOf [ Decode.field "tagName" Decode.string, Decode.succeed "" ])
        (Decode.oneOf [ Decode.field "type" Decode.string, Decode.succeed "" ])
        (Decode.oneOf [ Decode.field "isContentEditable" Decode.bool, Decode.succeed False ])


pointerDecoder : Decoder Pointer
pointerDecoder =
    Decode.map5 Pointer
        (Decode.field "clientX" Decode.float |> Decode.map round)
        (Decode.field "clientY" Decode.float |> Decode.map round)
        (Decode.at [ "view", "innerWidth" ] Decode.int)
        (Decode.at [ "view", "innerHeight" ] Decode.int)
        (Decode.oneOf
            [ Decode.at [ "target", "ownerDocument", "activeElement", "id" ] namedId
            , Decode.at [ "currentTarget", "id" ] namedId
            , Decode.succeed ""
            ]
        )


{-| A non-empty element id.
-}
namedId : Decoder String
namedId =
    Decode.string
        |> Decode.andThen
            (\id ->
                if id == "" then
                    Decode.fail "no id"

                else
                    Decode.succeed id
            )



-- ATTRIBUTES


{-| A setting of the context menu. Make them with the functions below and pass a
list to `view`; later attributes win over earlier ones. The `a` is the type of
what the menu is opened for.
-}
type Attribute a msg
    = Attribute (Config -> Config)


type alias Config =
    { label : Maybe String
    , locale : Locale
    }


configure : List (Attribute a msg) -> Config
configure attributes =
    List.foldl (\(Attribute change) config -> change config)
        { label = Nothing, locale = Locale.default }
        attributes


{-| The name of the menu that a screen reader says when it opens, such as "Order
actions". The default is "Actions" (in the language of `locale`).
-}
ariaLabel : String -> Attribute a msg
ariaLabel text =
    Attribute (\config -> { config | label = Just text })


{-| The language of the default name of the menu. The default is
`Locale.default`, which is `Locale.en`; the items are your own text.
-}
locale : Locale -> Attribute a msg
locale value =
    Attribute (\config -> { config | locale = value })



-- VIEW


{-| The menu: render it once, anywhere (it shows nothing while closed). The
function makes the items from what was right-clicked (the `a`), when the menu
opens. The menu opens at the pointer; where the browser supports CSS anchor
positioning it flips towards the free side near the edges of the window.

    ContextMenu.view ContextMsg [ ContextMenu.ariaLabel "Order actions" ] orderActions model.context

-}
view : (Msg a -> msg) -> List (Attribute a msg) -> (a -> List (Menu.Item msg)) -> State a -> Html msg
view toMsg attributes itemsFor (State state) =
    case ( Menu.isOpen state.menu, state.target ) of
        ( True, Just what ) ->
            let
                config =
                    configure attributes
            in
            Html.div
                [ Internal.cls [ "klar-context" ]
                , Internal.styleVars
                    [ ( "--klar-cx", Internal.px state.x )
                    , ( "--klar-cy", Internal.px state.y )
                    ]
                , Events.preventDefaultOn "contextmenu" (Decode.succeed ( toMsg Dismiss, True ))
                , Events.on "wheel" (wheelClosesMenu (toMsg Dismiss))

                -- `Tab` closes the menu (the menu sees to that) and focus goes back
                -- to the element the menu came from, once: not first on to
                -- whatever follows the menu on the page.
                , Events.preventDefaultOn "keydown" (tabStays (toMsg Noop))
                ]
                [ Menu.view (\inner -> toMsg (MenuMsg inner))
                    [ Menu.items (itemsFor what)

                    -- The hidden button names the menu for a screen reader.
                    , Menu.label (Maybe.withDefault (Locale.pick config.locale { nb = "Handlinger", en = "Actions" }) config.label)
                    , Menu.trigger [ Button.htmlAttrs [ Attr.hidden True ] ]
                    ]
                    state.menu
                ]

        _ ->
            Html.text ""


tabStays : msg -> Decoder ( msg, Bool )
tabStays noop =
    Decode.field "key" Decode.string
        |> Decode.andThen
            (\key ->
                if key == "Tab" then
                    Decode.succeed ( noop, True )

                else
                    Decode.fail "not Tab"
            )



-- WHEEL


{-| The mouse wheel closes the menu, so that it does not stay where it was when
the page scrolls under it. The wheel over a menu that scrolls by itself is for
the menu, though: a menu with more items than fit would otherwise close before
the pointer could reach the last ones.
-}
wheelClosesMenu : msg -> Decoder msg
wheelClosesMenu msg =
    Decode.oneOf [ Decode.field "target" (overScrollingMenu 0), Decode.succeed False ]
        |> Decode.andThen
            (\scrolls ->
                if scrolls then
                    Decode.fail "the wheel scrolls the menu"

                else
                    Decode.succeed msg
            )


{-| Walk up from the event target: is it inside a menu popup that has more to
scroll than it shows?
-}
overScrollingMenu : Int -> Decoder Bool
overScrollingMenu depth =
    if depth > 20 then
        Decode.succeed False

    else
        Decode.oneOf
            [ Decode.field "className" Decode.string
                |> Decode.andThen
                    (\names ->
                        if List.member "klar-menu__popup" (String.words names) then
                            Decode.map2 (>)
                                (Decode.field "scrollHeight" Decode.float)
                                (Decode.field "clientHeight" Decode.float)

                        else
                            Decode.fail "keep climbing"
                    )
            , Decode.field "parentElement" (Decode.lazy (\_ -> overScrollingMenu (depth + 1)))
            , Decode.succeed False
            ]
