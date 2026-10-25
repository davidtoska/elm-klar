module Page.Gallery.Actions.Keys exposing
    ( Model
    , Msg
    , init
    , section
    , update
    )

{-| The key caps of the gallery page "Actions and links": the same `Keys` values
that `Klar.Shortcut` listens to, shown for a PC or a Mac, and in the places where
hints belong: a tooltip, a menu item, a sentence.
-}

import Html exposing (Html)
import Klar.Button as Button
import Klar.Icon as Icon
import Klar.Kbd as Kbd
import Klar.Layout as Layout
import Klar.Locale exposing (Locale)
import Klar.Menu as Menu
import Klar.SegmentedControl as SegmentedControl
import Klar.Shortcut as Shortcut exposing (Keys)
import Klar.Text as Text
import Klar.Tooltip as Tooltip
import Showcase.Doc as Doc



-- MODEL


type alias Model =
    { mac : Bool
    , menu : Menu.State
    , last : Maybe String
    }


init : Model
init =
    { mac = False
    , menu = Menu.init "actions-keys-menu"
    , last = Nothing
    }


type Msg
    = MacChanged String
    | MenuMsg Menu.Msg
    | Did String


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        MacChanged value ->
            ( { model | mac = value == "mac" }, Cmd.none )

        MenuMsg inner ->
            Menu.update inner model.menu
                |> Tuple.mapBoth (\menu -> { model | menu = menu }) (Cmd.map MenuMsg)

        Did what ->
            ( { model | last = Just what }, Cmd.none )



-- THE SHORTCUTS OF THE PRETEND APPLICATION


openPalette : Keys
openPalette =
    Shortcut.mod (Shortcut.char 'k')


newOrder : Keys
newOrder =
    Shortcut.mod (Shortcut.shift (Shortcut.char 'n'))


saveOrder : Keys
saveOrder =
    Shortcut.mod (Shortcut.char 's')


goToOrders : Keys
goToOrders =
    Shortcut.sequence [ Shortcut.char 'g', Shortcut.char 'o' ]


help : Keys
help =
    Shortcut.char '?'


duplicate : Keys
duplicate =
    Shortcut.mod (Shortcut.char 'd')



-- VIEW


section : Locale -> Model -> Html Msg
section locale model =
    let
        platform =
            if model.mac then
                Kbd.mac

            else
                Kbd.pc

        basics =
            [ Kbd.platform platform, Kbd.locale locale ]

        text keys =
            Kbd.toString basics keys

        shortcuts =
            [ ( "Open the command palette", openPalette )
            , ( "New order", newOrder )
            , ( "Save", saveOrder )
            , ( "Go to orders", goToOrders )
            , ( "Show the shortcuts", help )
            , ( "Move up one row", Shortcut.alt Shortcut.up )
            , ( "Close", Shortcut.escape )
            , ( "Delete the row", Shortcut.delete )
            ]
    in
    Doc.section "Keyboard keys"
        "Key caps for hints and documentation, made from the same typed Keys that Klar.Shortcut listens to, so a key is never written as a string and the hint cannot disagree with the shortcut. Plain Elm cannot tell which keyboard the user has: the platform is an attribute (pc by default), and Kbd.platformFromUserAgent reads it from navigator.userAgent that the application gets in its flags. Screen readers skip the caps and read one phrase instead, such as Control plus K."
        [ Doc.example
            { title = "Keys, for a PC or a Mac"
            , description = Just "The platform decides how Ctrl, Alt, Shift, Enter, Tab, Backspace and Delete are written, and in which order the modifiers come. The same Keys value is behind every row."
            , code = Just keysCode
            }
            (Layout.stack [ Layout.gap 3, Layout.alignStart ]
                [ SegmentedControl.view
                    [ SegmentedControl.label "Keyboard"
                    , SegmentedControl.labelHidden
                    , SegmentedControl.id "actions-keys-platform"
                    , SegmentedControl.options [ SegmentedControl.option "pc" "Windows or Linux", SegmentedControl.option "mac" "Mac" ]
                    , SegmentedControl.selected
                        (if model.mac then
                            "mac"

                         else
                            "pc"
                        )
                    , SegmentedControl.onChange MacChanged
                    ]
                , Layout.container [ Layout.maxWidth 340, Layout.alignStart ]
                    [ Layout.stack [ Layout.gap 2 ]
                        (List.map (shortcutRow basics) shortcuts)
                    ]
                ]
            )
        , Doc.example
            { title = "Sizes"
            , description = Just "The default is 20px. Small (16px) is for a menu, a tooltip or the end of a field. Inline follows the text around it and does not make the line taller."
            , code = Just sizesCode
            }
            (Layout.stack [ Layout.gap 3 ]
                [ Layout.row [ Layout.gap 4, Layout.alignCenter, Layout.wrap ]
                    [ Kbd.view basics openPalette
                    , Kbd.view (Kbd.small :: basics) openPalette
                    , Kbd.view (Kbd.small :: basics) goToOrders
                    ]
                , Text.paragraphWith
                    [ Html.text "To find anything, press "
                    , Kbd.view (Kbd.inline :: basics) openPalette
                    , Html.text ", or press "
                    , Kbd.view (Kbd.inline :: basics) help
                    , Html.text " to see every shortcut. Go to the orders with "
                    , Kbd.view (Kbd.inline :: basics) goToOrders
                    , Html.text ", and close a dialog with "
                    , Kbd.view (Kbd.inline :: basics) Shortcut.escape
                    , Html.text "."
                    ]
                ]
            )
        , Doc.example
            { title = "In context: a tooltip, a menu and a button"
            , description = Just ("A menu item takes the same Keys (Menu.withShortcut) and draws them as small caps for the platform of the menu, with aria-keyshortcuts for screen readers. Kbd.toString writes the keys as text for the places that take a String, such as the shortcut of a tooltip. " ++ lastText model.last)
            , code = Just contextCode
            }
            (Layout.row [ Layout.gap 5, Layout.alignCenter, Layout.wrap ]
                [ Tooltip.wrap [ Tooltip.shortcut (text openPalette), Tooltip.id "actions-keys-tip" ]
                    "Open the command palette"
                    (Button.iconOnly [ Button.onClick (Did "Palette") ] Icon.search "Search")
                , Menu.view MenuMsg
                    [ Menu.label "Order"
                    , Menu.platform platform
                    , Menu.items
                        [ Menu.item "Save" (Did "Save") |> Menu.withIcon Icon.save |> Menu.withShortcut saveOrder
                        , Menu.item "Duplicate" (Did "Duplicate") |> Menu.withIcon Icon.copy |> Menu.withShortcut duplicate
                        , Menu.item "Go to orders" (Did "Go to orders") |> Menu.withShortcut goToOrders
                        ]
                    ]
                    model.menu
                , Layout.row [ Layout.gap 2, Layout.alignCenter ]
                    [ Button.view [ Button.primary, Button.icon Icon.plus, Button.onClick (Did "New order") ] "New order"
                    , Kbd.view (Kbd.small :: basics) newOrder
                    ]
                ]
            )
        , Doc.example
            { title = "A key that Shortcut has no value for"
            , description = Just "Kbd.key shows a key by the text printed on it. The text is shown and read as it is, never translated, and the platform does not change it. Prefer a Keys value whenever there is one."
            , code = Just keyCode
            }
            (Layout.row [ Layout.gap 3, Layout.alignCenter, Layout.wrap ]
                [ Kbd.key [] "Fn"
                , Kbd.key [] "Insert"
                , Kbd.key [] "Print Screen"
                , Text.paragraphWith
                    [ Html.text "Hold "
                    , Kbd.key [ Kbd.inline ] "Shift"
                    , Html.text " and click a row to select every row up to it."
                    ]
                ]
            )
        ]


shortcutRow : List Kbd.Attribute -> ( String, Keys ) -> Html msg
shortcutRow attributes ( label, keys ) =
    Layout.row [ Layout.gap 4, Layout.alignCenter, Layout.justifyBetween ]
        [ Html.text label
        , Kbd.view attributes keys
        ]


lastText : Maybe String -> String
lastText last =
    case last of
        Just what ->
            "Last action: " ++ what ++ "."

        Nothing ->
            "No action yet."



-- CODE


keysCode : String
keysCode =
    """import Klar.Kbd as Kbd
import Klar.Shortcut as Shortcut

-- the keys are the value that Shortcut.shortcut listens to
openPalette =
    Shortcut.mod (Shortcut.char 'k')

Kbd.view [] openPalette                                    -- Ctrl K
Kbd.view [ Kbd.platform Kbd.mac ] openPalette              -- ⌘ K
Kbd.view [] (Shortcut.sequence [ Shortcut.char 'g', Shortcut.char 'o' ])   -- G then O

-- the platform from the flags: Elm.Main.init({ flags: { userAgent: navigator.userAgent } })
Kbd.platform (Kbd.platformFromUserAgent flags.userAgent)
"""


sizesCode : String
sizesCode =
    """Kbd.view [] openPalette
Kbd.view [ Kbd.small ] openPalette

Text.paragraphWith
    [ Html.text "To find anything, press "
    , Kbd.view [ Kbd.inline ] openPalette
    , Html.text "."
    ]
"""


contextCode : String
contextCode =
    """-- a tooltip, with the shortcut as key caps
Tooltip.wrap [ Tooltip.shortcut (Kbd.toString attributes openPalette) ]
    "Open the command palette"
    (Button.iconOnly [] Icon.search "Search")

-- a menu item: the same Keys, drawn for the platform of the menu
Menu.view MenuMsg
    [ Menu.platform platform
    , Menu.items [ Menu.item "Save" Save |> Menu.withShortcut saveOrder ]
    ]
    model.menu

-- next to a button
Layout.row [ Layout.gap 2, Layout.alignCenter ]
    [ Button.view [ Button.primary ] "New order"
    , Kbd.view (Kbd.small :: attributes) newOrder
    ]
"""


keyCode : String
keyCode =
    """Kbd.key [] "Fn"
Kbd.key [ Kbd.inline ] "Click"
"""
