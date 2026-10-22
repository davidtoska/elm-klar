module Klar.SplitButton exposing
    ( view
    , State, init, Msg, update, isOpen, open, close
    , Attribute, primary, secondary, ghost, danger, small, large, size, icon, loading, disabled, menuLabel, locale
    )

{-| A main action with a few alternatives: a button joined to a small arrow that
opens a menu. "Save" with "Save and close" and "Save as draft" behind the arrow.

    import Klar.Menu as Menu
    import Klar.SplitButton as SplitButton

    -- model:   saveSplit : SplitButton.State   (SplitButton.init "order-save")

    -- update
    SaveSplitMsg m ->
        let
            ( split, cmd ) =
                SplitButton.update m model.saveSplit
        in
        ( { model | saveSplit = split }, Cmd.map SaveSplitMsg cmd )

    -- view
    SplitButton.view SaveSplitMsg
        [ SplitButton.primary, SplitButton.loading model.saving ]
        { label = "Save"
        , onClick = Save
        , items =
            [ Menu.item "Save and close" SaveAndClose
            , Menu.item "Save as draft" SaveDraft
            , Menu.separator
            , Menu.item "Discard changes" Discard |> Menu.danger
            ]
        }
        model.saveSplit

The main part sends `onClick`, the one message that every split button must
have. The arrow opens a [Klar.Menu](Klar-Menu): the items are made with
`Menu.item`, `Menu.separator`, `Menu.withIcon`, `Menu.danger` and the other
functions of that module, and picking one sends its own message and closes the
menu. The menu is the menu of that module, so it opens below the button with its
right edge level with the button's (it flips above when there is no room), is
never cut off by a table or a dialog, and shuts when the user clicks outside it.
A split button without items is drawn as an ordinary button.

**Keyboard.** The two parts are two buttons in the Tab order. Enter and Space on the
main part send `onClick`; on the arrow they open the menu. `ArrowDown` on either
part opens the menu, and so does `Alt+ArrowDown` (the key that opens a list in
most programs). The focus moves into the menu: `ArrowDown` and `ArrowUp` move
the highlight (a menu opens with nothing highlighted, so the first `ArrowDown`
highlights the first item), Enter or Space picks it, `Home` and `End` jump to the
first and last, `Escape` closes the menu and gives focus back to the arrow, and
`Tab` leaves the menu. Screen readers get a button, and a second button named
"More options for Save" that has a menu (`aria-haspopup`) and says whether it
is open (`aria-expanded`).

While the button is `loading` the main part shows a spinner and does nothing, the
arrow is switched off and an open menu is hidden; with `disabled` both parts
are off. The look (`primary`, `secondary`, `ghost`, `danger`, the sizes) is the
look of a [Klar.Button](Klar-Button), and the same for both parts. Each split
button needs a `State` and an id of its own. The built-in text ("More options
for") follows `locale`.

For two buttons that are separate actions, side by side, use a
[Klar.ButtonGroup](Klar-ButtonGroup); for a menu with no main action
[Klar.Menu](Klar-Menu) itself.


# View

@docs view


# State

@docs State, init, Msg, update, isOpen, open, close


# Attributes

@docs Attribute, primary, secondary, ghost, danger, small, large, size, icon, loading, disabled, menuLabel, locale

-}

import Html exposing (Html)
import Html.Attributes as Attr
import Klar.Button as Button
import Klar.Icon exposing (Icon)
import Klar.Internal as Internal
import Klar.Locale as Locale exposing (Locale)
import Klar.Menu as Menu
import Klar.Theme as Theme exposing (Size(..))



-- STATE


{-| The state of one split button: whether its menu is open and which item is
highlighted. Make it with `init` and keep it in your model.
-}
type State
    = State { id : String, menu : Menu.State }


{-| A split button with a closed menu. The `String` is a DOM id that must be
unique on the page; the ids of the arrow, the menu and its items start with it.

    SplitButton.init "order-save"

-}
init : String -> State
init id =
    State { id = id, menu = Menu.init id }


{-| Is the menu open?
-}
isOpen : State -> Bool
isOpen (State state) =
    Menu.isOpen state.menu


{-| The messages of the split button: opening and closing the menu and moving the
highlight. Wrap it in a constructor of your own message type and hand it to
`update`. The click on the main part is not one of them: it sends your `onClick`.
-}
type Msg
    = MenuMsg Menu.Msg
    | OpenFromKey


{-| Handles the menu and moves keyboard focus into it and back to the arrow.
Map its command into your own message with `Cmd.map`. Picking an item does not go
through here: it sends the message of the item.
-}
update : Msg -> State -> ( State, Cmd Msg )
update msg ((State state) as current) =
    case msg of
        MenuMsg inner ->
            Menu.update inner state.menu
                |> wrap state.id

        -- `Alt+ArrowDown` also reaches this from inside the open menu, where it
        -- must not start the menu over.
        OpenFromKey ->
            if Menu.isOpen state.menu then
                ( current, Cmd.none )

            else
                open current


{-| Opens the menu and moves keyboard focus into it, for example from a keyboard
shortcut.
-}
open : State -> ( State, Cmd Msg )
open (State state) =
    Menu.open state.menu
        |> wrap state.id


{-| Closes the menu and gives focus back to the arrow. The menu closes by itself
when the user picks an item, clicks outside it or presses `Escape`.
-}
close : State -> ( State, Cmd Msg )
close (State state) =
    Menu.close state.menu
        |> wrap state.id


wrap : String -> ( Menu.State, Cmd Menu.Msg ) -> ( State, Cmd Msg )
wrap id ( menu, cmd ) =
    ( State { id = id, menu = menu }, Cmd.map MenuMsg cmd )



-- ATTRIBUTES


{-| A setting of a split button. Make them with the functions below and pass a
list to `view`; later attributes win over earlier ones. What the button does is in
the arguments of `view`, so the type has no `msg` parameter.
-}
type Attribute
    = Attribute (Config -> Config)


type Variant
    = Primary
    | Secondary
    | Ghost


type alias Config =
    { variant : Maybe Variant
    , danger : Bool
    , size : Size
    , icon : Maybe Icon
    , loading : Bool
    , disabled : Bool
    , menuLabel : Maybe String
    , locale : Locale
    }


configure : List Attribute -> Config
configure attributes =
    List.foldl (\(Attribute change) config -> change config)
        { variant = Nothing
        , danger = False
        , size = Medium
        , icon = Nothing
        , loading = False
        , disabled = False
        , menuLabel = Nothing
        , locale = Locale.default
        }
        attributes


{-| The one main action of a page or dialog: solid blue. Use it once per view.
-}
primary : Attribute
primary =
    Attribute (\config -> { config | variant = Just Primary })


{-| The default look: white with a thin gray border.
-}
secondary : Attribute
secondary =
    Attribute (\config -> { config | variant = Just Secondary })


{-| A quiet button with no border until the pointer is over it, for toolbars.
-}
ghost : Attribute
ghost =
    Attribute (\config -> { config | variant = Just Ghost })


{-| A destructive action. On its own (or with `primary`) the button is solid red;
with `secondary` or `ghost` it keeps that look and only the text (and the border
of a `secondary` button) turns red, exactly as with
[`Button.danger`](Klar-Button#danger).
-}
danger : Attribute
danger =
    Attribute (\config -> { config | danger = True })


{-| A compact button, 26px high.
-}
small : Attribute
small =
    Attribute (\config -> { config | size = Small })


{-| A large button, 40px high.
-}
large : Attribute
large =
    Attribute (\config -> { config | size = Large })


{-| Sets the size from a variable. The default is `Medium` (32px). `small` and
`large` are shorthands.
-}
size : Size -> Attribute
size value =
    Attribute (\config -> { config | size = value })


{-| An icon before the text of the main part.
-}
icon : Icon -> Attribute
icon value =
    Attribute (\config -> { config | icon = Just value })


{-| While `True` the main part shows a spinner instead of its icon, announces
`aria-busy` and ignores clicks, the arrow is switched off and the menu cannot be
opened. Pass a field of your model, so the button cannot be clicked twice while
a request is on its way.
-}
loading : Bool -> Attribute
loading value =
    Attribute (\config -> { config | loading = value })


{-| Disables both parts. A disabled button cannot be focused, and an open menu is
hidden. The default is `False`.
-}
disabled : Bool -> Attribute
disabled value =
    Attribute (\config -> { config | disabled = value })


{-| The accessible name of the arrow, which has no text. The default is "More
options for" and the text of the main part ("More options for Save"), in the
language of `locale`. Set it when the default does not fit, for example "Save options".
-}
menuLabel : String -> Attribute
menuLabel value =
    Attribute (\config -> { config | menuLabel = Just value })


{-| The language of the built-in text, the accessible name of the arrow. The
default is `Locale.default`, which is `Locale.en`.
-}
locale : Locale -> Attribute
locale value =
    Attribute (\config -> { config | locale = value })



-- VIEW


{-| The main button and the arrow with its menu. The first argument turns the
messages of the menu into yours. The record is what every split button needs: the
text of the main part, the message it sends, and the items of the menu (see
`Menu.item`).
-}
view :
    (Msg -> msg)
    -> List Attribute
    -> { label : String, onClick : msg, items : List (Menu.Item msg) }
    -> State
    -> Html msg
view toMsg attributes content (State state) =
    let
        config =
            configure attributes

        inactive =
            config.disabled || config.loading

        look =
            lookOf config

        mainButton =
            Button.view
                (look
                    ++ [ Button.loading config.loading
                       , Button.disabled config.disabled
                       , Button.onClick content.onClick
                       , Button.htmlAttrs [ Internal.onKeys [ ( "ArrowDown", toMsg OpenFromKey ) ] ]
                       ]
                    ++ (case config.icon of
                            Just leading ->
                                [ Button.icon leading ]

                            Nothing ->
                                []
                       )
                )
                content.label

        arrowName =
            case config.menuLabel of
                Just name ->
                    name

                Nothing ->
                    Locale.pick config.locale { nb = "Flere valg for ", en = "More options for " } ++ content.label

        -- A closed menu while the arrow is switched off: an open menu would still
        -- accept clicks on its items.
        shownMenu =
            if inactive then
                Menu.init state.id

            else
                state.menu
    in
    if List.isEmpty content.items then
        mainButton

    else
        Html.div
            [ Internal.cls
                [ "klar-split"
                , if config.size == Medium then
                    ""

                  else
                    "klar-split--" ++ Theme.sizeSuffix config.size
                , if config.loading then
                    "klar-split--loading"

                  else
                    ""
                ]

            -- Alt+ArrowDown from either part (and from inside the open menu, which
            -- `update` ignores).
            , Internal.onKeys [ ( "Alt+ArrowDown", toMsg OpenFromKey ) ]
            ]
            [ mainButton
            , Menu.view (\inner -> toMsg (MenuMsg inner))
                [ Menu.label ""
                , Menu.alignEnd
                , Menu.items content.items
                , Menu.trigger (look ++ [ Button.ariaLabel arrowName, Button.disabled inactive ])
                ]
                shownMenu
            ]


{-| The look of both parts: the variant, the danger tone and the size, as
`Klar.Button` has them.
-}
lookOf : Config -> List (Button.Attribute msg)
lookOf config =
    List.filterMap identity
        [ Maybe.map
            (\variant ->
                case variant of
                    Primary ->
                        Button.primary

                    Secondary ->
                        Button.secondary

                    Ghost ->
                        Button.ghost
            )
            config.variant
        , if config.danger then
            Just Button.danger

          else
            Nothing
        , Just (Button.size config.size)
        ]
