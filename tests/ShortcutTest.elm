module ShortcutTest exposing (suite)

import Expect exposing (Expectation)
import Fuzz exposing (Fuzzer)
import Html
import Json.Encode as Encode
import Klar.Internal.Keys as KeyWords
import Klar.Shortcut as Shortcut exposing (Shortcut)
import Support.Keys as Keys
import Test exposing (Test, describe, fuzz, fuzz2, test)
import Test.Html.Event as Event
import Test.Html.Query as Query
import Test.Runner


suite : Test
suite =
    describe "Klar.Shortcut"
        [ builderTests
        , keycapTests
        , keyNotationTests
        , preventDefaultTests
        , sequenceTests
        , whileTypingTests
        , insideDialogsTests
        , altGrTests
        , ignoredPressesTests
        , takenKeysTests
        , layoutTests
        , macTests
        , sameKeysTests
        , propertyTests
        ]



-- KEYS THAT ARE ALREADY TAKEN, OTHER LAYOUTS, THE MAC


{-| A component inside has handled the key and prevented its default action.
-}
handled : Press -> Press
handled p =
    { p | prevented = True }


{-| The press belongs to the composition of an input method.
-}
composingText : Press -> Press
composingText p =
    { p | composing = True }


{-| In an open popup (a menu): the target is inside `.klar-popup` and `.klar-layer`.
-}
inMenu : Press -> Press
inMenu p =
    { p | inPopup = True, tag = "DIV" }


{-| The physical key, as `KeyboardEvent.code` names it.
-}
onKey : String -> Press -> Press
onKey code p =
    { p | code = code }


onMac : Press -> Press
onMac p =
    { p | mac = True }


takenKeysTests : Test
takenKeysTests =
    describe "keys that are already taken"
        [ check "a key that a component handled does not fire" Nothing (alone (press "Escape" |> handled))
        , check "Ctrl and K that a component handled does not fire" Nothing (alone (press "k" |> ctrl |> handled))
        , check "the Enter or Escape that ends an input method's composition does not fire" Nothing (alone (press "Escape" |> inField |> composingText))
        , check "a plain letter in an open menu does not fire" Nothing (alone (press "n" |> inMenu))
        , check "a sequence does not start in an open menu" Nothing (series shortcuts [ press "g" |> inMenu, press "o" |> inMenu ] |> List.reverse |> List.head |> Maybe.andThen identity)
        , check "Escape in an open menu is the menu's, even when the shortcut is marked inInputs" Nothing (alone (press "Escape" |> inMenu))
        , check "Ctrl and K in an open menu fires" (Just OpenPalette) (alone (press "k" |> ctrl |> inMenu))
        , check "a combination in an open menu fires" (Just NextRow) (alone (press "ArrowDown" |> alt |> inMenu))
        ]


layoutTests : Test
layoutTests =
    describe "other keyboard layouts"
        [ check "Ctrl and the K key on a Russian layout (the key gives л)" (Just OpenPalette) (alone (press "л" |> ctrl |> onKey "KeyK"))
        , check "Ctrl and the K key on a Greek layout, in a field" (Just OpenPalette) (alone (press "κ" |> ctrl |> onKey "KeyK" |> inField))
        , check "Ctrl and the S key on a Hebrew layout" (Just Save) (alone (press "ד" |> ctrl |> onKey "KeyS"))
        , check "Ctrl and the 1 key on an AZERTY keyboard (the key gives &)" (Just Save) (firesAlone "mod+1" (press "&" |> ctrl |> onKey "Digit1"))
        , check "Ctrl, Shift and 1 (the key gives !)" (Just Save) (firesAlone "mod+shift+1" (press "!" |> ctrl |> shift |> onKey "Digit1"))
        , check "a letter without Ctrl, Alt or Cmd is not found by its place" Nothing (alone (press "т" |> onKey "KeyN"))
        , check "the key itself wins over its place: AZERTY Ctrl and A" (Just SelectAllRows) (alone (press "a" |> ctrl |> onKey "KeyQ"))
        , check "AltGr and 8 on a German keyboard is still the symbol [" (Just OpenBracket) (firesAmong [ Shortcut.shortcut (Shortcut.char '[') "View" "Sidebar" OpenBracket ] (press "[" |> ctrl |> alt |> onKey "Digit8"))
        , check "a symbol typed with AltGr in a field is still text, also by its place" Nothing (firesInFields "mod+alt+8" (press "[" |> ctrl |> alt |> onKey "Digit8" |> inField))
        ]


macTests : Test
macTests =
    describe "on a Mac"
        [ check "Cmd and K fires mod+k" (Just OpenPalette) (alone (press "k" |> cmd |> onMac))
        , check "Ctrl and K outside a field fires mod+k too" (Just OpenPalette) (alone (press "k" |> ctrl |> onMac))
        , check "Ctrl and K in a field is the field's (delete to the end of the line)" Nothing (alone (press "k" |> ctrl |> onMac |> inField))
        , check "Cmd and K in a field fires" (Just OpenPalette) (alone (press "k" |> cmd |> onMac |> inField))
        , check "Option and A (the key gives å) fires alt+a" (Just Save) (firesAlone "alt+a" (press "å" |> alt |> onMac |> onKey "KeyA"))
        , check "Option and N (a dead key) fires alt+n" (Just Save) (firesAlone "alt+n" (press "Dead" |> alt |> onMac |> onKey "KeyN"))
        , check "Option and A in a field is text" Nothing (firesInFields "alt+a" (press "å" |> alt |> onMac |> onKey "KeyA" |> editable))
        , check "Option and N in a field starts an accent, which is text" Nothing (firesInFields "alt+n" (press "Dead" |> alt |> onMac |> onKey "KeyN" |> inField))
        ]


sameKeysTests : Test
sameKeysTests =
    let
        list =
            [ Shortcut.shortcut Shortcut.escape "Navigation" "Close the panel" Close
            , Shortcut.shortcut Shortcut.escape "Search" "Clear the search" Slash |> Shortcut.inInputs
            ]
    in
    describe "two shortcuts with the same keys"
        [ check "in a field the one marked inInputs fires" (Just Slash) (firesAmong list (press "Escape" |> inField))
        , check "elsewhere the first one fires" (Just Close) (firesAmong list (press "Escape"))
        , check "both can fire, so they are no conflict" [] (Shortcut.conflicts list |> List.map .label)
        , check "the shortcuts of the imaginary application have no conflicts" [] (Shortcut.conflicts shortcuts |> List.map .label)
        , check "a second shortcut with the same keys never fires"
            [ { label = "Save again", hiddenBy = "Save" } ]
            (Shortcut.conflicts
                [ Shortcut.shortcut (Keys.parse "mod+s") "Orders" "Save" Save
                , Shortcut.shortcut (Keys.parse "mod+s") "Orders" "Save again" Save
                ]
                |> List.map (\found -> { label = found.label, hiddenBy = found.hiddenBy })
            )
        , check "a second shortcut marked inInputs hides nothing in fields, but the first one marked inInputs hides the second"
            [ "Close the panel" ]
            (Shortcut.conflicts
                [ Shortcut.shortcut Shortcut.escape "Search" "Clear the search" Slash |> Shortcut.inInputs
                , Shortcut.shortcut Shortcut.escape "Navigation" "Close the panel" Close
                ]
                |> List.map .label
            )
        , check "a key by itself hides a sequence that begins with it, wherever it is in the list"
            [ { label = "Go to orders", hiddenBy = "Go" } ]
            (Shortcut.conflicts
                [ Shortcut.shortcut (Keys.parse "g o") "Navigation" "Go to orders" GoToOrders
                , Shortcut.shortcut (Keys.parse "g") "Navigation" "Go" GoToCustomers
                ]
                |> List.map (\found -> { label = found.label, hiddenBy = found.hiddenBy })
            )
        , check "the keys of the hidden shortcut come with it"
            [ Keys.parse "g o" ]
            (Shortcut.conflicts
                [ Shortcut.shortcut (Keys.parse "g") "Navigation" "Go" GoToCustomers
                , Shortcut.shortcut (Keys.parse "g o") "Navigation" "Go to orders" GoToOrders
                ]
                |> List.map .keys
            )
        , check "an empty sequence hides nothing" [] (Shortcut.conflicts [ Shortcut.shortcut (Shortcut.sequence []) "X" "Nothing" Save, Shortcut.shortcut (Keys.parse "g o") "Y" "Go" GoToOrders ] |> List.map .label)
        ]


{-| What one key press does with a shortcut of its own that is marked `inInputs`.
-}
firesInFields : String -> Press -> Maybe Msg
firesInFields keys p =
    firesAmong [ Shortcut.shortcut (Keys.parse keys) "Group" "Label" Save |> Shortcut.inInputs ] p



-- WHAT A KEY PRESS LOOKS LIKE


type Msg
    = ShortcutMsg Shortcut.Msg
    | OpenPalette
    | GoToOrders
    | GoToCustomers
    | NewOrder
    | Help
    | Slash
    | Close
    | ZoomIn
    | ZoomOut
    | SelectAllRows
    | Save
    | NextRow
    | Duplicate
    | Rename
    | OpenBracket


{-| A key press, and what it happens on.
-}
type alias Press =
    { key : String
    , ctrl : Bool
    , meta : Bool
    , alt : Bool
    , shift : Bool
    , repeat : Bool
    , time : Maybe Float
    , tag : String
    , editable : Bool
    , dialogLevels : Maybe Int
    , code : String
    , prevented : Bool
    , composing : Bool
    , inPopup : Bool
    , mac : Bool
    }


press : String -> Press
press key =
    { key = key
    , ctrl = False
    , meta = False
    , alt = False
    , shift = False
    , repeat = False
    , time = Nothing
    , tag = "DIV"
    , editable = False
    , dialogLevels = Nothing
    , code = ""
    , prevented = False
    , composing = False
    , inPopup = False
    , mac = False
    }


ctrl : Press -> Press
ctrl p =
    { p | ctrl = True }


cmd : Press -> Press
cmd p =
    { p | meta = True }


alt : Press -> Press
alt p =
    { p | alt = True }


shift : Press -> Press
shift p =
    { p | shift = True }


at : Float -> Press -> Press
at time p =
    { p | time = Just time }


held : Press -> Press
held p =
    { p | repeat = True }


onTag : String -> Press -> Press
onTag tag p =
    { p | tag = tag }


inField : Press -> Press
inField =
    onTag "INPUT"


editable : Press -> Press
editable p =
    { p | editable = True }


{-| In a dialog: the target has a parent that is the dialog.
-}
inDialog : Press -> Press
inDialog p =
    { p | dialogLevels = Just 1, tag = "BUTTON" }


{-| In a dialog, with more elements between the target and the dialog.
-}
deepInDialog : Int -> Press -> Press
deepInDialog levels p =
    { p | dialogLevels = Just levels, tag = "SPAN" }


{-| The target of a key press: an element, and its parents up to a dialog.
-}
target : Press -> Encode.Value
target p =
    let
        parents levels =
            if levels <= 1 then
                Encode.object [ ( "tagName", Encode.string "SECTION" ), ( "ariaModal", Encode.string "true" ) ]

            else
                Encode.object [ ( "tagName", Encode.string "DIV" ), ( "parentElement", parents (levels - 1) ) ]
    in
    Encode.object
        [ ( "tagName", Encode.string p.tag )
        , ( "isContentEditable", Encode.bool p.editable )
        , ( "parentElement"
          , case p.dialogLevels of
                Just levels ->
                    parents levels

                Nothing ->
                    if p.inPopup then
                        Encode.object
                            [ ( "tagName", Encode.string "DIV" )
                            , ( "className", Encode.string "klar-popup klar-menu__popup" )
                            , ( "parentElement", Encode.object [ ( "tagName", Encode.string "DIV" ), ( "className", Encode.string "klar-layer" ) ] )
                            ]

                    else
                        Encode.object [ ( "tagName", Encode.string "BODY" ) ]
          )
        ]


keydown : Press -> ( String, Encode.Value )
keydown p =
    Event.custom "keydown"
        (Encode.object
            ([ ( "key", Encode.string p.key )
             , ( "ctrlKey", Encode.bool p.ctrl )
             , ( "metaKey", Encode.bool p.meta )
             , ( "altKey", Encode.bool p.alt )
             , ( "shiftKey", Encode.bool p.shift )
             , ( "repeat", Encode.bool p.repeat )
             , ( "target", target p )
             , ( "code", Encode.string p.code )
             , ( "defaultPrevented", Encode.bool p.prevented )
             , ( "isComposing", Encode.bool p.composing )
             , ( "view"
               , Encode.object
                    [ ( "navigator"
                      , Encode.object
                            [ ( "platform"
                              , Encode.string
                                    (if p.mac then
                                        "MacIntel"

                                     else
                                        "Win32"
                                    )
                              )
                            ]
                      )
                    ]
               )
             ]
                ++ (case p.time of
                        Just time ->
                            [ ( "timeStamp", Encode.float time ) ]

                        Nothing ->
                            []
                   )
            )
        )


{-| The shortcuts of an imaginary orders application.
-}
shortcuts : List (Shortcut Msg)
shortcuts =
    [ Shortcut.shortcut (Shortcut.mod (Shortcut.char 'k')) "Navigation" "Open the command palette" OpenPalette |> Shortcut.inInputs
    , Shortcut.shortcut (Shortcut.sequence [ Shortcut.char 'g', Shortcut.char 'o' ]) "Navigation" "Go to orders" GoToOrders
    , Shortcut.shortcut (Shortcut.sequence [ Shortcut.char 'g', Shortcut.char 'c' ]) "Navigation" "Go to customers" GoToCustomers
    , Shortcut.shortcut (Shortcut.char 'n') "Orders" "New order" NewOrder
    , Shortcut.shortcut (Shortcut.char '?') "Help" "Show the shortcuts" Help
    , Shortcut.shortcut (Shortcut.char '/') "Help" "Search" Slash
    , Shortcut.shortcut Shortcut.escape "Navigation" "Close" Close |> Shortcut.inInputs
    , Shortcut.shortcut (Shortcut.char '+') "View" "Zoom in" ZoomIn
    , Shortcut.shortcut (Shortcut.mod (Shortcut.char '-')) "View" "Zoom out" ZoomOut
    , Shortcut.shortcut (Shortcut.mod (Shortcut.char 'a')) "Orders" "Select all rows" SelectAllRows
    , Shortcut.shortcut (Shortcut.mod (Shortcut.char 's')) "Orders" "Save" Save
    , Shortcut.shortcut (Shortcut.alt Shortcut.down) "Orders" "Next row" NextRow
    , Shortcut.shortcut (Shortcut.shift (Shortcut.char 'd')) "Orders" "Duplicate" Duplicate
    , Shortcut.shortcut (Shortcut.function 2) "Orders" "Rename" Rename
    ]


{-| What one key press comes to: the message that fired, if one did, whether
the browser's own action is stopped, and the state afterwards.
-}
type alias Outcome =
    { fired : Maybe Msg
    , prevented : Bool
    , state : Shortcut.State
    }


pressAmong : List (Shortcut Msg) -> Shortcut.State -> Press -> Outcome
pressAmong list state p =
    let
        simulated =
            Html.div [ Shortcut.listen ShortcutMsg list state ] []
                |> Query.fromHtml
                |> Event.simulate (keydown p)
    in
    case Event.toResult simulated of
        Ok (ShortcutMsg m) ->
            let
                ( next, fired ) =
                    Shortcut.update list m state
            in
            { fired = fired, prevented = passes (Event.expectPreventDefault simulated), state = next }

        _ ->
            { fired = Nothing, prevented = False, state = state }


passes : Expectation -> Bool
passes expectation =
    case Test.Runner.getFailureReason expectation of
        Nothing ->
            True

        Just _ ->
            False


{-| A key press by itself, with no sequence under way.
-}
alone : Press -> Maybe Msg
alone p =
    (pressAmong shortcuts Shortcut.init p).fired


{-| What one key press does with a shortcut of its own.
-}
firesAlone : String -> Press -> Maybe Msg
firesAlone keys p =
    (pressAmong [ Shortcut.shortcut (Keys.parse keys) "Group" "Label" Save ] Shortcut.init p).fired


{-| A series of key presses; what each one fired.
-}
series : List (Shortcut Msg) -> List Press -> List (Maybe Msg)
series list presses =
    List.foldl
        (\p ( state, fired ) ->
            let
                outcome =
                    pressAmong list state p
            in
            ( outcome.state, fired ++ [ outcome.fired ] )
        )
        ( Shortcut.init, [] )
        presses
        |> Tuple.second


check : String -> a -> a -> Test
check name expected actual =
    test name <| \_ -> Expect.equal expected actual



-- KEYCAPS


keycapTests : Test
keycapTests =
    describe "the words of the keys, which Kbd turns into caps"
        [ check "mod+k" [ [ "Ctrl", "K" ] ] (KeyWords.words (Shortcut.mod (Shortcut.char 'k')))
        , check "a sequence is one list for each step" [ [ "G" ], [ "M" ] ] (KeyWords.words (Shortcut.sequence [ Shortcut.char 'g', Shortcut.char 'm' ]))
        , check "a symbol" [ [ "?" ] ] (KeyWords.words (Shortcut.char '?'))
        , check "the plus key with Ctrl" [ [ "Ctrl", "+" ] ] (KeyWords.words (Shortcut.mod (Shortcut.char '+')))
        , check "the plus key alone" [ [ "+" ] ] (KeyWords.words (Shortcut.char '+'))
        , check "the plus key with several modifiers" [ [ "Ctrl", "Shift", "+" ] ] (KeyWords.words (Shortcut.mod (Shortcut.shift (Shortcut.char '+'))))
        , check "the minus key with Ctrl" [ [ "Ctrl", "-" ] ] (KeyWords.words (Shortcut.mod (Shortcut.char '-')))
        , check "shift" [ [ "Shift", "N" ] ] (KeyWords.words (Shortcut.shift (Shortcut.char 'n')))
        , check "alt" [ [ "Alt", "K" ] ] (KeyWords.words (Shortcut.alt (Shortcut.char 'k')))
        , check "all three modifiers come in a fixed order, whatever order they were written in" [ [ "Ctrl", "Alt", "Shift", "P" ] ] (KeyWords.words (Shortcut.shift (Shortcut.alt (Shortcut.mod (Shortcut.char 'p')))))
        , check "escape" [ [ "Esc" ] ] (KeyWords.words Shortcut.escape)
        , check "enter" [ [ "Enter" ] ] (KeyWords.words Shortcut.enter)
        , check "space" [ [ "Space" ] ] (KeyWords.words Shortcut.space)
        , check "tab" [ [ "Tab" ] ] (KeyWords.words Shortcut.tab)
        , check "the arrow keys are arrows" [ [ "↑" ], [ "↓" ], [ "←" ], [ "→" ] ] (List.concatMap (Keys.parse >> KeyWords.words) [ "up", "down", "left", "right" ])
        , check "an arrow with a modifier" [ [ "Alt", "↓" ] ] (KeyWords.words (Shortcut.alt Shortcut.down))
        , check "a named key" [ [ "F2" ] ] (KeyWords.words (Shortcut.function 2))
        , check "the other named keys have names, not capitals (one table with Kbd)"
            [ [ "PageUp" ], [ "PageDown" ], [ "Delete" ], [ "Backspace" ], [ "Home" ], [ "End" ] ]
            (List.concatMap KeyWords.words [ Shortcut.pageUp, Shortcut.pageDown, Shortcut.delete, Shortcut.backspace, Shortcut.home, Shortcut.end ])
        , check "shift with a named key" [ [ "Shift", "Enter" ] ] (KeyWords.words (Shortcut.shift Shortcut.enter))
        , check "a digit" [ [ "1" ] ] (KeyWords.words (Shortcut.char '1'))
        , check "extra spaces between the steps and around them do not matter" [ [ "G" ], [ "M" ] ] (KeyWords.words (Shortcut.sequence [ Shortcut.char 'g', Shortcut.char 'm' ]))
        , check "a sequence of steps with modifiers" [ [ "Ctrl", "K" ], [ "Ctrl", "S" ] ] (KeyWords.words (Shortcut.sequence [ Shortcut.mod (Shortcut.char 'k'), Shortcut.mod (Shortcut.char 's') ]))
        , check "three steps are three lists" [ [ "G" ], [ "O" ], [ "X" ] ] (KeyWords.words (Shortcut.sequence [ Shortcut.char 'g', Shortcut.char 'o', Shortcut.char 'x' ]))
        , check "a letter that has an accent" [ [ "Ø" ] ] (KeyWords.words (Shortcut.char 'ø'))
        ]



-- THE NOTATION OF THE KEYS


keyNotationTests : Test
keyNotationTests =
    describe "which key presses fire which shortcut"
        [ check "Ctrl and K" (Just OpenPalette) (alone (press "k" |> ctrl))
        , check "Cmd and K, the same shortcut on a Mac" (Just OpenPalette) (alone (press "k" |> cmd))
        , check "K alone is not mod+k" Nothing (alone (press "k"))
        , check "Ctrl, Shift and K is not mod+k: shift counts for letters" Nothing (alone (press "K" |> ctrl |> shift))
        , check "Alt and K is not mod+k" Nothing (alone (press "k" |> alt))
        , check "Ctrl, Alt and K is not mod+k" Nothing (alone (press "k" |> ctrl |> alt))
        , check "Ctrl and Cmd together are still mod" (Just OpenPalette) (alone (press "k" |> ctrl |> cmd))
        , check "a capital K with Ctrl, when shift is not held (Caps Lock), is the same key" (Just OpenPalette) (alone (press "K" |> ctrl))
        , check "a plain letter" (Just NewOrder) (alone (press "n"))
        , check "the same letter with shift is another key" Nothing (alone (press "N" |> shift))
        , check "shift+d" (Just Duplicate) (alone (press "D" |> shift))
        , check "and d alone is nothing" Nothing (alone (press "d"))
        , check "a question mark, as it comes with shift on most keyboards" (Just Help) (alone (press "?" |> shift))
        , check "and without shift on keyboards where it does not need it" (Just Help) (alone (press "?"))
        , check "a slash" (Just Slash) (alone (press "/"))
        , check "the Escape key is esc" (Just Close) (alone (press "Escape"))
        , check "the plus key" (Just ZoomIn) (alone (press "+"))
        , check "the plus key with shift, as on a US keyboard" (Just ZoomIn) (alone (press "+" |> shift))
        , check "mod+- is Ctrl and the minus key" (Just ZoomOut) (alone (press "-" |> ctrl))
        , check "and not the minus key alone" Nothing (alone (press "-"))
        , check "mod+a" (Just SelectAllRows) (alone (press "a" |> ctrl))
        , check "mod+s with Cmd" (Just Save) (alone (press "s" |> cmd))
        , check "alt+down is Alt and the arrow key" (Just NextRow) (alone (press "ArrowDown" |> alt))
        , check "the arrow key alone is not alt+down" Nothing (alone (press "ArrowDown"))
        , check "f2" (Just Rename) (alone (press "F2"))
        , check "a key that is nobody's shortcut" Nothing (alone (press "q"))
        , check "a digit that is nobody's shortcut" Nothing (alone (press "7"))
        , check "the Enter key is nobody's shortcut" Nothing (alone (press "Enter"))
        , check "the plus key does not fire with Ctrl: that is mod++" Nothing (alone (press "+" |> ctrl))
        , check "mod++ is Ctrl and the plus key" (Just Save) (firesAlone "mod++" (press "+" |> ctrl))
        , check "mod++ with shift too, as on a US keyboard" (Just Save) (firesAlone "mod++" (press "+" |> ctrl |> shift))
        , check "mod++ does not fire for Ctrl alone" Nothing (firesAlone "mod++" (press "Control" |> ctrl))
        , check "mod++ does not fire for the plus key alone" Nothing (firesAlone "mod++" (press "+"))
        , check "the modifiers can be written in any order" (Just Save) (firesAlone "shift+alt+mod+p" (press "P" |> ctrl |> alt |> shift))
        , check "and in another" (Just Save) (firesAlone "mod+shift+alt+p" (press "P" |> ctrl |> alt |> shift))
        , check "extra spaces around the keys do not matter" (Just Save) (firesAlone "  mod+k  " (press "k" |> ctrl))
        , check "ctrl is another name for mod" (Just Save) (firesAlone "ctrl+s" (press "s" |> ctrl))
        , check "cmd is another name for mod" (Just Save) (firesAlone "cmd+s" (press "s" |> cmd))
        , check "and a shortcut written with ctrl is not a plain s" Nothing (firesAlone "ctrl+s" (press "s"))
        , check "the names are not case sensitive" (Just Save) (firesAlone "Mod+S" (press "s" |> ctrl))
        , check "option is another name for alt" (Just Save) (firesAlone "option+s" (press "s" |> alt))
        , check "the key caps of ctrl+k" [ [ "Ctrl", "K" ] ] (KeyWords.words (Shortcut.mod (Shortcut.char 'k')))
        , check "shift counts for named keys: shift+enter" (Just Save) (firesAlone "shift+enter" (press "Enter" |> shift))
        , check "and enter alone is not shift+enter" Nothing (firesAlone "shift+enter" (press "Enter"))
        , check "space" (Just Save) (firesAlone "space" (press " "))
        , check "an arrow key" (Just Save) (firesAlone "left" (press "ArrowLeft"))
        , check "the arrow keys up and right" [ Just Save, Just Save ] [ firesAlone "up" (press "ArrowUp"), firesAlone "right" (press "ArrowRight") ]
        , check "tab" (Just Save) (firesAlone "tab" (press "Tab"))
        , check "a digit" (Just Save) (firesAlone "1" (press "1"))
        , check "a letter that has an accent" (Just Save) (firesAlone "ø" (press "ø"))
        , check "the first of two shortcuts with the same keys wins"
            (Just Save)
            (pressAmong [ Shortcut.shortcut (Shortcut.char 'n') "G" "First" Save, Shortcut.shortcut (Shortcut.char 'n') "G" "Second" NewOrder ] Shortcut.init (press "n")).fired
        , check "nothing fires when there are no shortcuts" Nothing (pressAmong [] Shortcut.init (press "n")).fired
        ]



-- WHAT THE BROWSER IS TOLD


preventDefaultTests : Test
preventDefaultTests =
    let
        afterG =
            (pressAmong shortcuts Shortcut.init (press "g")).state
    in
    describe "the browser's own action"
        [ check "is stopped for a shortcut that fired" True (pressAmong shortcuts Shortcut.init (press "k" |> ctrl)).prevented
        , check "is stopped for a slash, which would open a quick find" True (pressAmong shortcuts Shortcut.init (press "/")).prevented
        , check "is not stopped for a key that is no shortcut" False (pressAmong shortcuts Shortcut.init (press "q")).prevented
        , check "is not stopped for the first key of a sequence" False (pressAmong shortcuts Shortcut.init (press "g")).prevented
        , check "is stopped for the second key of a sequence that fired" True (pressAmong shortcuts afterG (press "o")).prevented
        , check "is not stopped for a key that ends a sequence that did not fire" False (pressAmong shortcuts afterG (press "x")).prevented
        , check "is not stopped for a shortcut that does not apply while typing" False (pressAmong shortcuts Shortcut.init (press "n" |> inField)).prevented
        , check "is stopped for the repeats of a held Ctrl+S, which fire nothing (the page is not saved)"
            { fired = Nothing, prevented = True }
            (pressAmong shortcuts (stateAfter shortcuts [ press "s" |> ctrl ]) (press "s" |> ctrl |> held) |> firedAndPrevented)
        , check "is stopped for the repeats of a held Ctrl+K in the search box it opened (a field, and the shortcut is marked inInputs)"
            { fired = Nothing, prevented = True }
            (pressAmong shortcuts (stateAfter shortcuts [ press "k" |> ctrl ]) (press "k" |> ctrl |> held |> inField |> (\p -> { p | dialogLevels = Just 1 })) |> firedAndPrevented)
        , check "is not stopped for the repeats of a key that is no shortcut" False (pressAmong shortcuts Shortcut.init (press "q" |> held)).prevented
        , check "is not stopped for the repeats of a shortcut that does not apply in a field" False (pressAmong shortcuts (stateAfter shortcuts [ press "s" |> ctrl ]) (press "s" |> ctrl |> held |> inField)).prevented
        , check "is stopped for the repeats of the last key of a sequence that just fired"
            True
            (pressAmong twoStep (stateAfter twoStep [ press "k" |> ctrl, press "s" |> ctrl ]) (press "s" |> ctrl |> held)).prevented
        , check "is not stopped for a held key that ends a sequence that did not fire (the user may be typing)"
            False
            (pressAmong shortcuts Shortcut.init (press "o" |> held)).prevented
        , check "a held key with a shortcut marked repeats fires each time, and is stopped"
            { fired = Just NextRow, prevented = True }
            (pressAmong [ Shortcut.shortcut (Shortcut.char 'j') "Orders" "Next row" NextRow |> Shortcut.repeats ] Shortcut.init (press "j" |> held) |> firedAndPrevented)
        ]


{-| A sequence of two steps with Ctrl: Ctrl+K, then Ctrl+S.
-}
twoStep : List (Shortcut Msg)
twoStep =
    [ Shortcut.shortcut (Shortcut.sequence [ Shortcut.mod (Shortcut.char 'k'), Shortcut.mod (Shortcut.char 's') ]) "Orders" "Save all" Save ]


{-| The state after a series of key presses.
-}
stateAfter : List (Shortcut Msg) -> List Press -> Shortcut.State
stateAfter list presses =
    List.foldl (\p state -> (pressAmong list state p).state) Shortcut.init presses


firedAndPrevented : Outcome -> { fired : Maybe Msg, prevented : Bool }
firedAndPrevented outcome =
    { fired = outcome.fired, prevented = outcome.prevented }



-- SEQUENCES


sequenceTests : Test
sequenceTests =
    describe "sequences"
        [ check "g and then o" [ Nothing, Just GoToOrders ] (series shortcuts [ press "g", press "o" ])
        , check "g and then c" [ Nothing, Just GoToCustomers ] (series shortcuts [ press "g", press "c" ])
        , check "the first key alone fires nothing" [ Nothing ] (series shortcuts [ press "g" ])
        , check "the second key alone fires nothing" [ Nothing ] (series shortcuts [ press "o" ])
        , check "the wrong second key fires nothing, and ends the sequence" [ Nothing, Nothing, Nothing ] (series shortcuts [ press "g", press "x", press "o" ])
        , check "within the time (1199 ms later)" [ Nothing, Just GoToOrders ] (series shortcuts [ press "g" |> at 1000, press "o" |> at 2199 ])
        , check "not after 1200 ms" [ Nothing, Nothing ] (series shortcuts [ press "g" |> at 1000, press "o" |> at 2200 ])
        , check "not a long time later" [ Nothing, Nothing ] (series shortcuts [ press "g" |> at 1000, press "o" |> at 90000 ])
        , check "without time stamps the second key counts as being in time" [ Nothing, Just GoToOrders ] (series shortcuts [ press "g", press "o" ])
        , check "the time is counted from the latest first key: g, g again, then o"
            [ Nothing, Nothing, Just GoToOrders ]
            (series shortcuts [ press "g" |> at 1000, press "g" |> at 2000, press "o" |> at 3100 ])
        , check "after the sequence fired the first key is needed again" [ Nothing, Just GoToOrders, Nothing ] (series shortcuts [ press "g", press "o", press "o" ])
        , check "a sequence can be done twice" [ Nothing, Just GoToOrders, Nothing, Just GoToCustomers ] (series shortcuts [ press "g", press "o", press "g", press "c" ])
        , check "a key that is a shortcut of its own, between the two keys, fires that shortcut and ends the sequence"
            [ Nothing, Just NewOrder, Nothing ]
            (series shortcuts [ press "g", press "n", press "o" ])
        , check "a modifier key alone does not end a sequence"
            [ Nothing, Nothing, Just GoToOrders ]
            (series shortcuts [ press "g", press "Shift" |> shift, press "o" ])
        , check "a key held down does not end it either"
            [ Nothing, Nothing, Just GoToOrders ]
            (series shortcuts [ press "g", press "g" |> held, press "o" ])
        , check "a sequence of keys with modifiers"
            [ Nothing, Just Save ]
            (series [ Shortcut.shortcut (Shortcut.sequence [ Shortcut.mod (Shortcut.char 'k'), Shortcut.mod (Shortcut.char 's') ]) "G" "L" Save ] [ press "k" |> ctrl, press "s" |> ctrl ])
        , check "the second step must have its modifiers too"
            [ Nothing, Nothing ]
            (series [ Shortcut.shortcut (Shortcut.sequence [ Shortcut.mod (Shortcut.char 'k'), Shortcut.mod (Shortcut.char 's') ]) "G" "L" Save ] [ press "k" |> ctrl, press "s" ])
        , check "a key that is a shortcut by itself cannot also start a sequence: the shortcut wins"
            [ Just Rename, Nothing ]
            (series [ Shortcut.shortcut (Shortcut.char 'g') "G" "L" Rename, Shortcut.shortcut (Shortcut.sequence [ Shortcut.char 'g', Shortcut.char 'o' ]) "G" "L" GoToOrders ] [ press "g", press "o" ])
        , check "extra spaces in the keys of a sequence do not matter"
            [ Nothing, Just Save ]
            (series [ Shortcut.shortcut (Shortcut.sequence [ Shortcut.char 'g', Shortcut.char 'o' ]) "G" "L" Save ] [ press "g", press "o" ])
        , -- Was a bug: the documentation says "A sequence is several steps separated by
          -- spaces", but only two steps worked: the third key never fired anything.
          check "a sequence of three steps"
            [ Nothing, Nothing, Just Save ]
            (series [ Shortcut.shortcut (Shortcut.sequence [ Shortcut.char 'g', Shortcut.char 'o', Shortcut.char 'x' ]) "G" "L" Save ] [ press "g", press "o", press "x" ])
        ]



-- TYPING IN A FIELD


whileTypingTests : Test
whileTypingTests =
    describe "while the user types in a field"
        [ check "a plain key does not fire" Nothing (alone (press "n" |> inField))
        , check "a question mark does not fire" Nothing (alone (press "?" |> shift |> inField))
        , check "a slash does not fire" Nothing (alone (press "/" |> inField))
        , check "a combination with Ctrl does not fire either, unless it is marked inInputs (mod+s)" Nothing (alone (press "s" |> ctrl |> inField))
        , check "mod+a does not fire: it selects the text" Nothing (alone (press "a" |> ctrl |> inField))
        , check "a shortcut marked inInputs fires: mod+k" (Just OpenPalette) (alone (press "k" |> ctrl |> inField))
        , check "esc is marked inInputs" (Just Close) (alone (press "Escape" |> inField))
        , check "in a text area" (Just Close) (alone (press "Escape" |> onTag "TEXTAREA"))
        , check "in a select" (Just Close) (alone (press "Escape" |> onTag "SELECT"))
        , check "in an editable element" (Just Close) (alone (press "Escape" |> editable))
        , check "a plain key does not fire in a text area" Nothing (alone (press "n" |> onTag "TEXTAREA"))
        , check "a plain key does not fire in a select" Nothing (alone (press "n" |> onTag "SELECT"))
        , check "a plain key does not fire in an editable element" Nothing (alone (press "n" |> editable))
        , check "a button is not a field" (Just NewOrder) (alone (press "n" |> onTag "BUTTON"))
        , check "a link is not a field" (Just NewOrder) (alone (press "n" |> onTag "A"))
        , check "the page itself is not a field" (Just NewOrder) (alone (press "n" |> onTag "BODY"))
        , check "the first key of a sequence does not start one in a field" [ Nothing, Nothing ] (series shortcuts [ press "g" |> inField, press "o" |> inField ])
        , check "a shortcut marked inInputs also fires in a field inside a dialog" (Just OpenPalette) (alone (press "k" |> ctrl |> inField |> (\p -> { p | dialogLevels = Just 1 })))
        , check "the user can type every letter and symbol of the shortcuts"
            []
            (List.filterMap (\key -> alone (press key |> inField)) [ "n", "g", "o", "c", "d", "s", "k", "a", "?", "/", "+", "-" ])
        ]



-- DIALOGS


insideDialogsTests : Test
insideDialogsTests =
    describe "inside a dialog (a modal, a drawer, the command palette)"
        [ check "a plain key does not fire: g o must not take the user away from the dialog" Nothing (alone (press "n" |> inDialog))
        , check "a question mark does not fire" Nothing (alone (press "?" |> inDialog))
        , check "the first key of a sequence does not start one" [ Nothing, Nothing ] (series shortcuts [ press "g" |> inDialog, press "o" |> inDialog ])
        , check "Ctrl with a letter fires" (Just Save) (alone (press "s" |> ctrl |> inDialog))
        , check "Cmd with a letter fires" (Just Save) (alone (press "s" |> cmd |> inDialog))
        , check "Alt with a key fires" (Just NextRow) (alone (press "ArrowDown" |> alt |> inDialog))
        , check "mod+k, marked inInputs, fires" (Just OpenPalette) (alone (press "k" |> ctrl |> inDialog))
        , check "esc, marked inInputs, fires" (Just Close) (alone (press "Escape" |> inDialog))
        , check "mod+a does not fire: it selects everything in the dialog" Nothing (alone (press "a" |> ctrl |> inDialog))
        , check "mod+a fires again outside a dialog" (Just SelectAllRows) (alone (press "a" |> ctrl))
        , check "mod+a fires inside a dialog when it is marked inInputs"
            (Just SelectAllRows)
            (pressAmong [ Shortcut.shortcut (Shortcut.mod (Shortcut.char 'a')) "G" "L" SelectAllRows |> Shortcut.inInputs ] Shortcut.init (press "a" |> ctrl |> inDialog)).fired
        , check "the dialog may be one level up" (Just Save) (alone (press "s" |> ctrl |> deepInDialog 1))
        , check "or three levels up: a plain key does not fire there" Nothing (alone (press "n" |> deepInDialog 3))
        , check "and a combination with Ctrl does" (Just Save) (alone (press "s" |> ctrl |> deepInDialog 3))
        , check "a dialog more than forty levels up is not looked for" (Just NewOrder) (alone (press "n" |> deepInDialog 60))
        , check "the same key outside a dialog fires" (Just NewOrder) (alone (press "n" |> onTag "BUTTON"))
        , check "a sequence can be done outside a dialog after the dialog was closed"
            [ Nothing, Just GoToOrders ]
            (series shortcuts [ press "g" |> onTag "BODY", press "o" |> onTag "BODY" ])
        ]



-- ALTGR


altGrTests : Test
altGrTests =
    let
        bracket =
            Shortcut.shortcut (Shortcut.char '[') "G" "L" OpenBracket
    in
    describe "symbols typed with AltGr"
        [ check "a bracket typed with AltGr (Ctrl and Alt) counts as the plain bracket" (Just OpenBracket) (firesAmong [ bracket ] (press "[" |> ctrl |> alt))
        , check "a bracket typed with Option on a Mac counts as the plain bracket" (Just OpenBracket) (firesAmong [ bracket ] (press "[" |> alt |> onMac))
        , check "so it is not Ctrl+Alt+[" Nothing (firesAlone "mod+alt+[" (press "[" |> ctrl |> alt))
        , check "Alt and a symbol on a PC is alt with that symbol, not text" (Just Save) (firesAlone "alt+/" (press "/" |> alt))
        , check "and it fires in a field when it is marked inInputs" (Just Save) (firesInFields "alt+/" (press "/" |> alt |> inField))
        , check "and is not the plain symbol" Nothing (firesAmong [ Shortcut.shortcut (Shortcut.char '/') "G" "L" Slash ] (press "/" |> alt))
        , check "on a Mac Option and a symbol types another character, which is text" Nothing (firesAlone "alt+/" (press "÷" |> alt |> onMac |> onKey "Slash"))
        , check "a letter with Alt is still alt+letter" Nothing (firesAmong [ bracket ] (press "k" |> alt))
        , check "a letter with Alt fires alt+letter" (Just Save) (firesAlone "alt+k" (press "k" |> alt))
        , check "a digit with Alt is alt+digit" (Just Save) (firesAlone "alt+1" (press "1" |> alt))
        , check "a space with Alt is alt+space" (Just Save) (firesAlone "alt+space" (press " " |> alt))
        , check "in a field it is text, that never fires a shortcut, also when the shortcut is marked inInputs"
            Nothing
            (firesAmong [ bracket |> Shortcut.inInputs ] (press "[" |> ctrl |> alt |> inField))
        , check "in a dialog it is a plain key: it does not fire" Nothing (firesAmong [ bracket ] (press "[" |> ctrl |> alt |> inDialog))
        , check "in a dialog it fires when the shortcut is marked inInputs"
            (Just OpenBracket)
            (firesAmong [ bracket |> Shortcut.inInputs ] (press "[" |> ctrl |> alt |> inDialog))
        ]


firesAmong : List (Shortcut Msg) -> Press -> Maybe Msg
firesAmong list p =
    (pressAmong list Shortcut.init p).fired



-- PRESSES THAT ARE NOT KEY PRESSES


ignoredPressesTests : Test
ignoredPressesTests =
    describe "presses that count for nothing"
        [ check "a key that is held down does not repeat the shortcut" Nothing (alone (press "n" |> held))
        , check "also with modifiers" Nothing (alone (press "k" |> ctrl |> held))
        , check "a shortcut marked repeats fires again while its key is held"
            (Just NextRow)
            (firesAmong [ Shortcut.shortcut (Shortcut.char 'j') "Orders" "Next row" NextRow |> Shortcut.repeats ] (press "j" |> held))
        , check "a held key does not complete a sequence, even one marked repeats"
            [ Nothing, Nothing ]
            (series [ Shortcut.shortcut (Keys.parse "g o") "Navigation" "Go to orders" GoToOrders |> Shortcut.repeats ] [ press "g", press "o" |> held ])
        , check "Shift alone" Nothing (alone (press "Shift" |> shift))
        , check "Control alone" Nothing (alone (press "Control" |> ctrl))
        , check "Alt alone" Nothing (alone (press "Alt" |> alt))
        , check "Meta alone" Nothing (alone (press "Meta" |> cmd))
        , check "AltGraph alone" Nothing (alone (press "AltGraph"))
        , check "Caps Lock" Nothing (alone (press "CapsLock"))
        , test "a modifier key alone does not change a sequence that is waiting" <|
            \_ ->
                let
                    first =
                        pressAmong shortcuts Shortcut.init (press "g")
                in
                Expect.equal first.state (pressAmong shortcuts first.state (press "Shift" |> shift)).state
        ]



-- PROPERTIES


letters : List String
letters =
    String.split "" "abcdefghijklmnopqrstuvwxyz"


type alias Modifiers =
    { mod : Bool, alt : Bool, shift : Bool }


modifiersFuzzer : Fuzzer Modifiers
modifiersFuzzer =
    Fuzz.map3 Modifiers Fuzz.bool Fuzz.bool Fuzz.bool


{-| The notation of a combination, with the modifiers in this order.
-}
notation : Modifiers -> String -> List String -> String
notation modifiers key order =
    order
        |> List.filter
            (\name ->
                case name of
                    "mod" ->
                        modifiers.mod

                    "alt" ->
                        modifiers.alt

                    _ ->
                        modifiers.shift
            )
        |> (\names -> String.join "+" (names ++ [ key ]))


pressOf : Modifiers -> String -> Press
pressOf modifiers letter =
    let
        p =
            press
                (if modifiers.shift then
                    String.toUpper letter

                 else
                    letter
                )
    in
    { p | ctrl = modifiers.mod, alt = modifiers.alt, shift = modifiers.shift }


propertyTests : Test
propertyTests =
    describe "properties"
        [ fuzz2 modifiersFuzzer (Fuzz.oneOfValues letters) "a shortcut written with some modifiers, in any order, fires for exactly those modifiers and that letter" <|
            \modifiers letter ->
                Expect.equal
                    [ Just Save, Just Save, Just Save ]
                    (List.map (\order -> firesAlone (notation modifiers letter order) (pressOf modifiers letter))
                        [ [ "mod", "alt", "shift" ], [ "shift", "mod", "alt" ], [ "alt", "shift", "mod" ] ]
                    )
        , fuzz2 modifiersFuzzer (Fuzz.oneOfValues letters) "and for no other combination of the modifiers" <|
            \modifiers letter ->
                let
                    keys =
                        notation modifiers letter [ "mod", "alt", "shift" ]
                in
                Expect.equal
                    [ Nothing, Nothing, Nothing ]
                    [ firesAlone keys (pressOf { modifiers | mod = not modifiers.mod } letter)
                    , firesAlone keys (pressOf { modifiers | alt = not modifiers.alt } letter)
                    , firesAlone keys (pressOf { modifiers | shift = not modifiers.shift } letter)
                    ]
        , fuzz2 modifiersFuzzer (Fuzz.oneOfValues letters) "while the user types nothing fires, unless the shortcut is marked inInputs" <|
            \modifiers letter ->
                let
                    keys =
                        notation modifiers letter [ "mod", "alt", "shift" ]

                    typing =
                        pressOf modifiers letter |> inField
                in
                Expect.equal
                    ( Nothing, Just Save )
                    ( (pressAmong [ Shortcut.shortcut (Keys.parse keys) "G" "L" Save ] Shortcut.init typing).fired
                    , (pressAmong [ Shortcut.shortcut (Keys.parse keys) "G" "L" Save |> Shortcut.inInputs ] Shortcut.init typing).fired
                    )
        , fuzz2 modifiersFuzzer (Fuzz.oneOfValues letters) "in a dialog only combinations with Ctrl or Alt fire, unless the shortcut is marked inInputs" <|
            \modifiers letter ->
                let
                    keys =
                        notation modifiers letter [ "mod", "alt", "shift" ]

                    inside =
                        pressOf modifiers letter |> inDialog

                    expectedPlain =
                        if (modifiers.mod || modifiers.alt) && not (modifiers.mod && not modifiers.alt && not modifiers.shift && letter == "a") then
                            Just Save

                        else
                            Nothing
                in
                Expect.equal
                    ( expectedPlain, Just Save )
                    ( (pressAmong [ Shortcut.shortcut (Keys.parse keys) "G" "L" Save ] Shortcut.init inside).fired
                    , (pressAmong [ Shortcut.shortcut (Keys.parse keys) "G" "L" Save |> Shortcut.inInputs ] Shortcut.init inside).fired
                    )
        , fuzz2 modifiersFuzzer (Fuzz.oneOfValues letters) "a key that is held down never fires" <|
            \modifiers letter ->
                firesAlone (notation modifiers letter [ "mod", "alt", "shift" ]) (pressOf modifiers letter |> held)
                    |> Expect.equal Nothing
        , fuzz (Fuzz.oneOfValues letters) "keycaps shows each letter in capitals" <|
            \letter ->
                KeyWords.words (Keys.parse letter)
                    |> Expect.equal [ [ String.toUpper letter ] ]
        , fuzz2 (Fuzz.oneOfValues letters) (Fuzz.oneOfValues letters) "keycaps of a sequence has a list for each step" <|
            \first second ->
                KeyWords.words (Keys.parse (first ++ " " ++ second))
                    |> Expect.equal [ [ String.toUpper first ], [ String.toUpper second ] ]
        , fuzz2 modifiersFuzzer (Fuzz.oneOfValues letters) "keycaps lists the modifiers in the order Ctrl, Alt, Shift, whatever the order they were written in" <|
            \modifiers letter ->
                let
                    expected =
                        List.filterMap identity
                            [ if modifiers.mod then
                                Just "Ctrl"

                              else
                                Nothing
                            , if modifiers.alt then
                                Just "Alt"

                              else
                                Nothing
                            , if modifiers.shift then
                                Just "Shift"

                              else
                                Nothing
                            ]
                            ++ [ String.toUpper letter ]
                in
                Expect.equal
                    [ [ expected ], [ expected ] ]
                    [ KeyWords.words (Keys.parse (notation modifiers letter [ "shift", "mod", "alt" ]))
                    , KeyWords.words (Keys.parse (notation modifiers letter [ "alt", "shift", "mod" ]))
                    ]
        ]



-- THE KEYS ARE BUILT, NOT WRITTEN


builderTests : Test
builderTests =
    describe "building Keys"
        [ test "the order of the modifiers does not matter" <|
            \_ ->
                Expect.equal
                    (Shortcut.mod (Shortcut.alt (Shortcut.shift (Shortcut.char 'p'))))
                    (Shortcut.shift (Shortcut.mod (Shortcut.alt (Shortcut.char 'p'))))
        , test "a letter is not case sensitive" <|
            \_ -> Expect.equal (Shortcut.char 'k') (Shortcut.char 'K')
        , test "the space character is the space key" <|
            \_ -> Expect.equal Shortcut.space (Shortcut.char ' ')
        , test "a modifier twice is the same as once" <|
            \_ -> Expect.equal (Shortcut.mod (Shortcut.char 'k')) (Shortcut.mod (Shortcut.mod (Shortcut.char 'k')))
        , test "a modifier on a sequence applies to every key of it" <|
            \_ ->
                Expect.equal
                    [ [ "Ctrl", "G" ], [ "Ctrl", "O" ] ]
                    (KeyWords.words (Shortcut.mod (Shortcut.sequence [ Shortcut.char 'g', Shortcut.char 'o' ])))
        , test "a function key outside 1 to 12 is the nearest one" <|
            \_ -> Expect.equal [ Shortcut.function 1, Shortcut.function 12 ] [ Shortcut.function 0, Shortcut.function 99 ]
        , test "the plus key with a modifier" <|
            \_ -> Expect.equal [ [ "Ctrl", "+" ] ] (KeyWords.words (Shortcut.mod (Shortcut.char '+')))
        , test "the accessors read back what the shortcut was made with" <|
            \_ ->
                let
                    made =
                        Shortcut.shortcut (Shortcut.mod (Shortcut.char 'k')) "Navigation" "Open the palette" Save
                in
                Expect.equal
                    { keys = Shortcut.mod (Shortcut.char 'k'), group = "Navigation", label = "Open the palette", plain = False, marked = True }
                    { keys = Shortcut.keysOf made
                    , group = Shortcut.groupOf made
                    , label = Shortcut.labelOf made
                    , plain = Shortcut.firesInInputs made
                    , marked = Shortcut.firesInInputs (Shortcut.inInputs made)
                    }
        ]
