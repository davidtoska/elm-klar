module OverlaysFixTest exposing (suite)

{-| Regression tests for the fixes to the overlay modules:

  - `Tooltip`: `aria-keyshortcuts` uses the key names of ARIA, and a wrapped tip
    can be given an id of its own.
  - `ConfirmDialog`: however the dialog closes, it forgets its failure.
  - `Toast`: raising `maxVisible` moves queued toasts up at once, and their
    timers start with the next `push` or `update`.
  - `Menu`: `kebab` draws vertical dots, `Tab` closes the menu without pulling
    focus back to the button (`Escape` and a click still do), and the keys that
    move the highlight scroll a long menu so that the highlighted item is in view.
  - `ContextMenu`: the same keys work in a context menu, and the mouse wheel
    scrolls a long one instead of closing it.

Controls are found the way a user would find them, the event is simulated on
them, and the message that comes out is given to `update`.

A command cannot be looked into, but it can be compared with `Cmd.none`: that is
how the tests tell "focus goes back" or "a timer starts" from "nothing happens".

-}

import Browser.Dom as Dom
import Expect exposing (Expectation)
import Html exposing (Html)
import Html.Attributes as Attr
import Json.Encode as Encode
import Klar.ConfirmDialog as ConfirmDialog
import Klar.ContextMenu as ContextMenu
import Klar.Locale as Locale
import Klar.Menu as Menu
import Klar.Menu.Scroll as Scroll
import Klar.Overlay as Overlay
import Klar.Remote as Remote
import Klar.Toast as Toast
import Klar.Tooltip as Tooltip
import Test exposing (Test, describe, test)
import Test.Html.Event as Event
import Test.Html.Query as Query
import Test.Html.Selector as Selector exposing (Selector)


suite : Test
suite =
    describe "The fixes to the overlay modules"
        [ tooltipTests
        , confirmDialogTests
        , toastTests
        , menuTests
        , menuScrollTests
        , scrollGeometryTests
        , contextMenuTests
        ]



-- SHARED


{-| Draw the html, find the one element the selectors name, simulate the event
on it, and give the message that it sends (or what went wrong: no such element,
several, or an element that does not listen to the event).
-}
send : Html msg -> List Selector -> ( String, Encode.Value ) -> Result String msg
send html selectors event =
    html
        |> Query.fromHtml
        |> Query.find selectors
        |> Event.simulate event
        |> Event.toResult


{-| A `keydown` with the fields that the library reads.
-}
keyDown : { shift : Bool } -> String -> String -> ( String, Encode.Value )
keyDown modifiers targetId key =
    Event.custom "keydown"
        (Encode.object
            [ ( "key", Encode.string key )
            , ( "ctrlKey", Encode.bool False )
            , ( "metaKey", Encode.bool False )
            , ( "altKey", Encode.bool False )
            , ( "shiftKey", Encode.bool modifiers.shift )
            , ( "target", Encode.object [ ( "id", Encode.string targetId ) ] )
            ]
        )


role : String -> Selector
role name =
    Selector.attribute (Attr.attribute "role" name)


{-| A command that does something, as opposed to `Cmd.none`.
-}
expectCommand : Cmd msg -> Expectation
expectCommand cmd =
    Expect.notEqual Cmd.none cmd


expectNoCommand : Cmd msg -> Expectation
expectNoCommand cmd =
    Expect.equal Cmd.none cmd


{-| Turn "the control was not there" into a failure of the test.
-}
expectOk : (a -> Expectation) -> Result String a -> Expectation
expectOk check result =
    case result of
        Ok value ->
            check value

        Err problem ->
            Expect.fail problem



-- TOOLTIP


tooltipTests : Test
tooltipTests =
    describe "Klar.Tooltip"
        [ describe "aria-keyshortcuts uses the key names of ARIA"
            [ announced "Ctrl K" "Control+K"
            , announced "Ctrl+Shift+K" "Control+Shift+K"
            , announced "ctrl k" "Control+K"
            , announced "Cmd K" "Meta+K"
            , announced "Command+K" "Meta+K"
            , announced "⌘ K" "Meta+K"
            , announced "Option Shift P" "Alt+Shift+P"
            , announced "Alt K" "Alt+K"
            , announced "Esc" "Escape"
            , announced "Ctrl Enter" "Control+Enter"
            , announced "Ctrl Del" "Control+Delete"
            , announced "Ctrl Right" "Control+ArrowRight"
            , announced "Alt Left" "Alt+ArrowLeft"
            , announced "Shift PgDn" "Shift+PageDown"
            , announced "Ctrl Space" "Control+Space"
            , announced "Ctrl F5" "Control+F5"
            , announced "Ctrl /" "Control+/"
            , announced "Ctrl Home" "Control+Home"
            , test "attrsWith announces it the same way" <|
                \_ ->
                    Html.button (Tooltip.attrsWith [ Tooltip.shortcut "Cmd K" ] "Open search") []
                        |> Query.fromHtml
                        |> Query.has [ Selector.attribute (Attr.attribute "aria-keyshortcuts" "Meta+K") ]
            , test "the visible shortcut stays as it was written" <|
                \_ ->
                    shortcutButton "Cmd K"
                        |> Query.fromHtml
                        |> Query.has [ Selector.attribute (Attr.attribute "data-tip-key" "· Cmd K") ]
            ]
        , describe "the id of a wrapped tip"
            [ test "an id of your own names the tip, and the wrapper points at it" <|
                \_ ->
                    wrapped [ Tooltip.id "delete-tip-1" ] "Delete order"
                        |> Query.fromHtml
                        |> Expect.all
                            [ Query.has [ Selector.class "klar-tip-wrap", describedBy "delete-tip-1" ]
                            , Query.find [ role "tooltip" ] >> Query.has [ Selector.id "delete-tip-1", Selector.text "Delete order" ]
                            ]
            , test "two tips with the same words get their own ids when asked" <|
                \_ ->
                    Html.div []
                        [ wrapped [ Tooltip.id "delete-tip-1" ] "Delete order"
                        , wrapped [ Tooltip.id "delete-tip-2" ] "Delete order"
                        ]
                        |> Query.fromHtml
                        |> Expect.all
                            [ Query.findAll [ role "tooltip" ] >> Query.count (Expect.equal 2)
                            , Query.findAll [ Selector.id "delete-tip-1" ] >> Query.count (Expect.equal 1)
                            , Query.findAll [ Selector.id "delete-tip-2" ] >> Query.count (Expect.equal 1)
                            , Query.findAll [ describedBy "delete-tip-1" ] >> Query.count (Expect.equal 1)
                            , Query.findAll [ describedBy "delete-tip-2" ] >> Query.count (Expect.equal 1)
                            ]
            , test "the last id wins" <|
                \_ ->
                    wrapped [ Tooltip.id "first", Tooltip.id "second" ] "Delete order"
                        |> Query.fromHtml
                        |> Expect.all
                            [ Query.has [ describedBy "second" ]
                            , Query.findAll [ Selector.id "second" ] >> Query.count (Expect.equal 1)
                            , Query.findAll [ Selector.id "first" ] >> Query.count (Expect.equal 0)
                            ]
            , test "attrsWith has no tip to give an id to, so it ignores one" <|
                \_ ->
                    Html.button (Tooltip.attrsWith [ Tooltip.id "ignored" ] "Hint") []
                        |> Query.fromHtml
                        |> Expect.all
                            [ Query.hasNot [ Selector.id "ignored" ]
                            , Query.has [ Selector.attribute (Attr.attribute "data-tip" "Hint") ]
                            ]
            ]
        ]


{-| A button with a tip and a shortcut, for reading the attributes.
-}
shortcutButton : String -> Html msg
shortcutButton keys =
    Html.button (Tooltip.attrs "Open search" |> Tooltip.withShortcut keys) [ Html.text "Search" ]


announced : String -> String -> Test
announced written expected =
    test (written ++ " is announced as " ++ expected) <|
        \_ ->
            shortcutButton written
                |> Query.fromHtml
                |> Query.has [ Selector.attribute (Attr.attribute "aria-keyshortcuts" expected) ]


wrapped : List Tooltip.Option -> String -> Html msg
wrapped options text =
    Tooltip.wrap options text (Html.button [] [ Html.text "Delete" ])


describedBy : String -> Selector
describedBy id =
    Selector.attribute (Attr.attribute "aria-describedby" id)



-- CONFIRM DIALOG


type DialogMsg
    = Dialog ConfirmDialog.Msg
    | Cancelled


dialogId : String
dialogId =
    "delete-dialog"


{-| The dialog as the application draws it, with or without `onCancel`.
-}
drawDialog : Bool -> ConfirmDialog.State -> Html DialogMsg
drawDialog withOnCancel state =
    Overlay.host
        { attributes = []
        , page = []
        , overlays =
            [ ConfirmDialog.view Dialog
                (ConfirmDialog.title "Delete order?"
                    :: (if withOnCancel then
                            [ ConfirmDialog.onCancel Cancelled ]

                        else
                            []
                       )
                )
                state
            ]
        }


{-| What the application does with a message of the dialog: hands the dialog its
own messages, and closes the dialog when its `onCancel` message comes (that is
what the documentation tells it to do).
-}
settle : ConfirmDialog.State -> DialogMsg -> ConfirmDialog.State
settle state msg =
    case msg of
        Dialog inner ->
            Tuple.first (ConfirmDialog.update inner state)

        Cancelled ->
            Tuple.first (ConfirmDialog.close state)


openDialog : ConfirmDialog.State
openDialog =
    ConfirmDialog.init dialogId
        |> ConfirmDialog.open ""
        |> Tuple.first


serverProblem : Remote.Problem
serverProblem =
    Remote.problem Remote.server


failedDialog : ConfirmDialog.State
failedDialog =
    ConfirmDialog.setFailed serverProblem openDialog


{-| Every control that closes the dialog, found as the user finds it.
-}
waysToClose : List ( String, List Selector, ( String, Encode.Value ) )
waysToClose =
    [ ( "the close button", [ Selector.id (dialogId ++ "-close") ], Event.click )
    , ( "a click on the backdrop", [ Selector.class "klar-modal__backdrop" ], Event.click )
    , ( "Escape", [ Selector.id dialogId ], keyDown { shift = False } dialogId "Escape" )
    , ( "the cancel button", [ Selector.id (dialogId ++ "-cancel") ], Event.click )
    ]


confirmDialogTests : Test
confirmDialogTests =
    describe "Klar.ConfirmDialog"
        [ describe "closing the dialog forgets the failure"
            [ test "the failed dialog is open and shows its problem" <|
                \_ ->
                    Expect.all
                        [ ConfirmDialog.isOpen >> Expect.equal True
                        , ConfirmDialog.problem >> Expect.equal (Just serverProblem)
                        ]
                        failedDialog
            , describe "without onCancel the dialog closes itself" (List.map (closesAfterFailure False) waysToClose)
            , describe "with onCancel the application closes it" (List.map (closesAfterFailure True) waysToClose)
            , test "ConfirmDialog.close does the same" <|
                \_ ->
                    ConfirmDialog.close failedDialog
                        |> Tuple.first
                        |> expectForgotten
            , test "a close request from the frame before the dialog drew itself as busy ends the busy phase" <|
                \_ ->
                    send (drawDialog False openDialog) [ Selector.id (dialogId ++ "-close") ] Event.click
                        |> Result.map (settle (ConfirmDialog.setBusy openDialog))
                        |> expectOk expectForgotten
            ]
        , describe "a closed dialog has no problem"
            [ test "not even when the failure comes late" <|
                \_ ->
                    ConfirmDialog.init dialogId
                        |> ConfirmDialog.setFailed serverProblem
                        |> ConfirmDialog.problem
                        |> Expect.equal Nothing
            , test "or when the request fails after the application closed the dialog" <|
                \_ ->
                    ConfirmDialog.close openDialog
                        |> Tuple.first
                        |> ConfirmDialog.setFailed serverProblem
                        |> ConfirmDialog.problem
                        |> Expect.equal Nothing
            , test "opening the dialog again starts without it" <|
                \_ ->
                    ConfirmDialog.open "" failedDialog
                        |> Tuple.first
                        |> ConfirmDialog.problem
                        |> Expect.equal Nothing
            ]
        ]


closesAfterFailure : Bool -> ( String, List Selector, ( String, Encode.Value ) ) -> Test
closesAfterFailure withOnCancel ( name, selectors, event ) =
    test name <|
        \_ ->
            send (drawDialog withOnCancel failedDialog) selectors event
                |> Result.map (settle failedDialog)
                |> expectOk expectForgotten


expectForgotten : ConfirmDialog.State -> Expectation
expectForgotten state =
    Expect.all
        [ ConfirmDialog.isOpen >> Expect.equal False
        , ConfirmDialog.isBusy >> Expect.equal False
        , ConfirmDialog.problem >> Expect.equal Nothing
        ]
        state



-- TOAST


type alias Stack =
    Toast.State Toast.Msg


{-| The toast with this text, pushed on the stack.
-}
pushed : String -> Stack -> Stack
pushed text stack =
    Toast.push [ Toast.message text ] stack
        |> Tuple.first


drawStack : Stack -> Query.Single Toast.Msg
drawStack stack =
    Overlay.host { attributes = [], page = [], overlays = [ Toast.view identity [] stack ] }
        |> Query.fromHtml


toasts : Selector
toasts =
    Selector.class "klar-toast"


shown : Int -> Stack -> Expectation
shown expected stack =
    drawStack stack
        |> Query.findAll [ toasts ]
        |> Query.count (Expect.equal expected)


{-| The nth toast on screen reads like this.
-}
reads : Int -> String -> Stack -> Expectation
reads index text stack =
    drawStack stack
        |> Query.findAll [ Selector.class "klar-toast__message" ]
        |> Query.index index
        |> Query.has [ Selector.text text ]


{-| What the first toast on screen sends for this event.
-}
firstToast : ( String, Encode.Value ) -> Stack -> Result String Toast.Msg
firstToast event stack =
    drawStack stack
        |> Query.findAll [ toasts ]
        |> Query.first
        |> Event.simulate event
        |> Event.toResult


{-| What the close button of the first toast on screen sends.
-}
dismissFirst : Stack -> Result String Toast.Msg
dismissFirst stack =
    drawStack stack
        |> Query.findAll [ toasts ]
        |> Query.first
        |> Query.find [ Selector.tag "button" ]
        |> Event.simulate Event.click
        |> Event.toResult


{-| Three toasts pushed on a stack that shows one: the first is on screen, two
wait in the queue.
-}
crowded : Stack
crowded =
    Toast.init
        |> Toast.maxVisible 1
        |> pushed "Toast 1"
        |> pushed "Toast 2"
        |> pushed "Toast 3"


toastTests : Test
toastTests =
    describe "Klar.Toast"
        [ describe "the queue"
            [ test "toasts beyond the limit wait" <|
                \_ ->
                    Expect.all
                        [ shown 1
                        , Toast.queued >> Expect.equal 2
                        , Toast.count >> Expect.equal 3
                        ]
                        crowded
            ]
        , describe "raising maxVisible moves queued toasts up at once"
            [ test "all of them, when there is room" <|
                \_ ->
                    Toast.maxVisible 3 crowded
                        |> Expect.all
                            [ shown 3
                            , Toast.queued >> Expect.equal 0
                            , Toast.count >> Expect.equal 3
                            ]
            , test "just as many as there is room for" <|
                \_ ->
                    Toast.maxVisible 2 crowded
                        |> Expect.all
                            [ shown 2
                            , Toast.queued >> Expect.equal 1
                            , Toast.count >> Expect.equal 3
                            ]
            , test "in the order in which they were pushed" <|
                \_ ->
                    Toast.maxVisible 3 crowded
                        |> Expect.all
                            [ reads 0 "Toast 1"
                            , reads 1 "Toast 2"
                            , reads 2 "Toast 3"
                            ]
            , test "and the note about the toasts that wait goes away" <|
                \_ ->
                    Toast.maxVisible 3 crowded
                        |> drawStack
                        |> Expect.all
                            [ Query.hasNot [ Selector.text "more waiting" ]
                            , Query.findAll [ Selector.class "klar-toasts__more" ] >> Query.count (Expect.equal 0)
                            ]
            , test "while the note counts them as long as they wait" <|
                \_ ->
                    crowded
                        |> drawStack
                        |> Query.has [ Selector.text "+ 2 more waiting" ]
            , test "a toast pushed afterwards goes behind the ones that moved up" <|
                \_ ->
                    Toast.maxVisible 3 crowded
                        |> pushed "Toast 4"
                        |> Expect.all
                            [ shown 3
                            , Toast.queued >> Expect.equal 1
                            , reads 2 "Toast 3"
                            ]
            , test "a limit below 1 counts as 1" <|
                \_ ->
                    Toast.maxVisible 0 crowded
                        |> Expect.all
                            [ shown 1
                            , Toast.queued >> Expect.equal 2
                            ]
            ]
        , describe "lowering maxVisible"
            [ test "hides nothing that is on screen, and sends the next ones to the queue" <|
                \_ ->
                    Toast.maxVisible 3 crowded
                        |> Toast.maxVisible 1
                        |> pushed "Toast 4"
                        |> Expect.all
                            [ shown 3
                            , Toast.queued >> Expect.equal 1
                            ]
            ]
        , describe "the timers"
            [ test "a toast that moved up gets its timer with the next update" <|
                \_ ->
                    Toast.maxVisible 2 (stackOf [ "Toast 1", "Toast 2" ] 1)
                        |> afterFirstToast Event.mouseEnter
                        |> expectOk (Tuple.second >> expectCommand)
            , test "once, not with every update" <|
                \_ ->
                    Toast.maxVisible 2 (stackOf [ "Toast 1", "Toast 2" ] 1)
                        |> afterFirstToast Event.mouseEnter
                        |> expectOk (\( stack, _ ) -> afterFirstToast Event.mouseEnter stack |> expectOk (Tuple.second >> expectNoCommand))
            , test "a toast that moved up gets its timer with the next push as well" <|
                \_ ->
                    Toast.maxVisible 2 (stackOf [ "Toast 1", "Toast 2" ] 1)
                        |> Toast.push [ Toast.message "Toast 3" ]
                        |> Tuple.second
                        |> expectCommand
            , test "nothing to start, nothing sent" <|
                \_ ->
                    stackOf [ "Toast 1", "Toast 2" ] 2
                        |> afterFirstToast Event.mouseEnter
                        |> expectOk (Tuple.second >> expectNoCommand)
            , test "dismissing a toast starts the timer of the one that takes its place" <|
                \_ ->
                    stackOf [ "Toast 1", "Toast 2" ] 1
                        |> (\stack ->
                                dismissFirst stack
                                    |> Result.map (\msg -> Toast.update msg stack)
                           )
                        |> expectOk
                            (\( stack, cmd ) ->
                                Expect.all
                                    [ \_ -> expectCommand cmd
                                    , \_ -> shown 1 stack
                                    , \_ -> reads 0 "Toast 2" stack
                                    ]
                                    ()
                            )
            , test "the pointer stops the timer, and leaving it starts a new one" <|
                \_ ->
                    let
                        stack =
                            stackOf [ "Toast 1" ] 2
                    in
                    afterFirstToast Event.mouseEnter stack
                        |> expectOk
                            (\( held, entering ) ->
                                Expect.all
                                    [ \_ -> expectNoCommand entering
                                    , \_ ->
                                        afterFirstToast Event.mouseLeave held
                                            |> expectOk (Tuple.second >> expectCommand)
                                    ]
                                    ()
                            )
            ]
        ]


{-| A stack that shows this many toasts, with the texts pushed in this order.
-}
stackOf : List String -> Int -> Stack
stackOf texts limit =
    List.foldl pushed (Toast.maxVisible limit Toast.init) texts


{-| Send the event to the first toast on screen and give the message to `update`.
-}
afterFirstToast : ( String, Encode.Value ) -> Stack -> Result String ( Stack, Cmd Toast.Msg )
afterFirstToast event stack =
    firstToast event stack
        |> Result.map (\msg -> Toast.update msg stack)



-- MENU


type MenuMsg
    = MenuMsg Menu.Msg
    | Picked String


menuId : String
menuId =
    "order-actions"


drawMenu : List (Menu.Attribute MenuMsg) -> Menu.State -> Html MenuMsg
drawMenu attributes state =
    Menu.view MenuMsg
        (Menu.items
            [ Menu.item "Edit order" (Picked "edit")
            , Menu.separator
            , Menu.item "Delete order" (Picked "delete")
            ]
            :: attributes
        )
        state


closedMenu : Menu.State
closedMenu =
    Menu.init menuId


openMenu : Menu.State
openMenu =
    Menu.open closedMenu
        |> Tuple.first


{-| The layer behind the open menu is where the keys and the outside click land.
-}
layer : List Selector
layer =
    [ Selector.class "klar-layer" ]


{-| What the open menu sends for this event, given to `Menu.update`.
-}
afterEvent : List Selector -> ( String, Encode.Value ) -> Result String ( Menu.State, Cmd Menu.Msg )
afterEvent selectors event =
    send (drawMenu [] openMenu) selectors event
        |> Result.andThen (inMenu openMenu)


{-| Give the message to the menu, if it is a message of the menu.
-}
inMenu : Menu.State -> MenuMsg -> Result String ( Menu.State, Cmd Menu.Msg )
inMenu state msg =
    case msg of
        MenuMsg inner ->
            Ok (Menu.update inner state)

        Picked _ ->
            Err "an item was picked, not a message of the menu"


menuTests : Test
menuTests =
    describe "Klar.Menu"
        [ describe "kebab"
            [ test "draws three vertical dots" <|
                \_ ->
                    drawMenu [ Menu.kebab "Order actions" ] closedMenu
                        |> Query.fromHtml
                        |> Expect.all
                            [ Query.has [ Selector.class "klar-icon--more-vertical" ]
                            , Query.hasNot [ Selector.class "klar-icon--more-horizontal" ]
                            ]
            , test "is still named for the screen reader" <|
                \_ ->
                    drawMenu [ Menu.kebab "Order actions" ] closedMenu
                        |> Query.fromHtml
                        |> Query.has [ Selector.attribute (Attr.attribute "aria-label" "Order actions") ]
            ]
        , describe "Tab in an open menu"
            [ test "closes it" <|
                \_ ->
                    afterEvent layer (keyDown { shift = False } menuId "Tab")
                        |> expectOk (Tuple.first >> Menu.isOpen >> Expect.equal False)
            , test "does not take focus back to the button, so it moves on" <|
                \_ ->
                    afterEvent layer (keyDown { shift = False } menuId "Tab")
                        |> expectOk (Tuple.second >> expectNoCommand)
            , test "leaves the browser's own move of focus alone" <|
                \_ ->
                    drawMenu [] openMenu
                        |> Query.fromHtml
                        |> Query.find layer
                        |> Event.simulate (keyDown { shift = False } menuId "Tab")
                        |> Event.expectNotPreventDefault
            ]
        , describe "Shift+Tab in an open menu"
            [ test "closes it without a focus command either" <|
                \_ ->
                    afterEvent layer (keyDown { shift = True } menuId "Tab")
                        |> expectOk
                            (\( state, cmd ) ->
                                Expect.all
                                    [ \_ -> Menu.isOpen state |> Expect.equal False
                                    , \_ -> expectNoCommand cmd
                                    ]
                                    ()
                            )
            ]
        , describe "everything else that closes the menu gives focus back to the button"
            [ test "Escape" <|
                \_ ->
                    afterEvent layer (keyDown { shift = False } menuId "Escape")
                        |> expectOk
                            (\( state, cmd ) ->
                                Expect.all
                                    [ \_ -> Menu.isOpen state |> Expect.equal False
                                    , \_ -> expectCommand cmd
                                    ]
                                    ()
                            )
            , test "a click outside the menu" <|
                \_ ->
                    afterEvent layer Event.click
                        |> expectOk
                            (\( state, cmd ) ->
                                Expect.all
                                    [ \_ -> Menu.isOpen state |> Expect.equal False
                                    , \_ -> expectCommand cmd
                                    ]
                                    ()
                            )
            , test "Enter with no item highlighted" <|
                \_ ->
                    afterEvent layer (keyDown { shift = False } menuId "Enter")
                        |> expectOk
                            (\( state, cmd ) ->
                                Expect.all
                                    [ \_ -> Menu.isOpen state |> Expect.equal False
                                    , \_ -> expectCommand cmd
                                    ]
                                    ()
                            )
            , test "Menu.close" <|
                \_ ->
                    Menu.close openMenu
                        |> (\( state, cmd ) ->
                                Expect.all
                                    [ \_ -> Menu.isOpen state |> Expect.equal False
                                    , \_ -> expectCommand cmd
                                    ]
                                    ()
                           )
            ]
        ]



-- MENU: THE HIGHLIGHT STAYS IN VIEW


{-| A menu with headings, a separator and an item that cannot be picked between
the items, as a long menu has. The indices: heading 0, "Open" 1, "Edit" 2 (it
cannot be picked), "Print" 3, separator 4, heading 5, "Delete" 6. The items that
can be picked are 1, 3 and 6.
-}
longMenu : List (Menu.Attribute MenuMsg)
longMenu =
    [ Menu.items
        [ Menu.heading "Orders"
        , Menu.item "Open" (Picked "open")
        , Menu.item "Edit" (Picked "edit") |> Menu.disabledItem
        , Menu.item "Print" (Picked "print")
        , Menu.separator
        , Menu.heading "Danger zone"
        , Menu.item "Delete" (Picked "delete")
        ]
    ]


itemId : String -> Int -> String
itemId id index =
    id ++ "-item-" ++ String.fromInt index


{-| The key goes to the open menu, which is what has focus; the message that
comes out is given to `Menu.update`.
-}
pressKey : String -> Menu.State -> Result String ( Menu.State, Cmd Menu.Msg )
pressKey key state =
    send (drawMenu longMenu state) [ role "menu" ] (keyDown { shift = False } menuId key)
        |> Result.andThen (inMenu state)


{-| Press the keys one after the other, the way the user does. The result is
what the last key did.
-}
pressKeys : List String -> Menu.State -> Result String ( Menu.State, Cmd Menu.Msg )
pressKeys keys state =
    List.foldl
        (\key result -> Result.andThen (\( current, _ ) -> pressKey key current) result)
        (Ok ( state, Cmd.none ))
        keys


{-| This item, and only this one, is highlighted: the menu names it as the active
one, and it is drawn highlighted.
-}
highlighting : Int -> Menu.State -> Expectation
highlighting index state =
    drawMenu longMenu state
        |> Query.fromHtml
        |> Expect.all
            [ Query.find [ role "menu" ] >> Query.has [ Selector.attribute (Attr.attribute "aria-activedescendant" (itemId menuId index)) ]
            , Query.find [ Selector.class "klar-menu__item--highlighted" ] >> Query.has [ Selector.id (itemId menuId index) ]
            ]


{-| The highlight is at this item, and the list was told to scroll to it.
-}
highlightedAndScrolled : Int -> Result String ( Menu.State, Cmd Menu.Msg ) -> Expectation
highlightedAndScrolled index =
    expectOk
        (\( state, cmd ) ->
            Expect.all
                [ \_ -> highlighting index state
                , \_ -> expectCommand cmd
                ]
                ()
        )


menuScrollTests : Test
menuScrollTests =
    describe "Klar.Menu: the keys keep the highlighted item in view"
        [ test "ArrowDown highlights the first item that can be picked and scrolls to it" <|
            \_ ->
                pressKeys [ "ArrowDown" ] openMenu
                    |> highlightedAndScrolled 1
        , test "ArrowDown skips what cannot be picked: a disabled item, a separator, a heading" <|
            \_ ->
                Expect.all
                    [ \_ -> pressKeys [ "ArrowDown", "ArrowDown" ] openMenu |> highlightedAndScrolled 3
                    , \_ -> pressKeys [ "ArrowDown", "ArrowDown", "ArrowDown" ] openMenu |> highlightedAndScrolled 6
                    ]
                    ()
        , test "ArrowDown at the last item goes round to the first, and scrolls back" <|
            \_ ->
                pressKeys [ "ArrowDown", "ArrowDown", "ArrowDown", "ArrowDown" ] openMenu
                    |> highlightedAndScrolled 1
        , test "ArrowUp goes up past what cannot be picked" <|
            \_ ->
                pressKeys [ "ArrowDown", "ArrowDown", "ArrowDown", "ArrowUp" ] openMenu
                    |> highlightedAndScrolled 3
        , test "ArrowUp in a menu with no highlight starts at the last item" <|
            \_ ->
                pressKeys [ "ArrowUp" ] openMenu
                    |> highlightedAndScrolled 6
        , test "Home highlights the first item that can be picked and scrolls to it" <|
            \_ ->
                pressKeys [ "ArrowDown", "ArrowDown", "Home" ] openMenu
                    |> highlightedAndScrolled 1
        , test "End highlights the last item that can be picked and scrolls to it" <|
            \_ ->
                pressKeys [ "End" ] openMenu
                    |> highlightedAndScrolled 6
        , test "the pointer highlights an item without scrolling, because the item can be seen" <|
            \_ ->
                send (drawMenu longMenu openMenu) [ Selector.id (itemId menuId 3) ] Event.mouseEnter
                    |> Result.andThen (inMenu openMenu)
                    |> expectOk
                        (\( state, cmd ) ->
                            Expect.all
                                [ \_ -> highlighting 3 state
                                , \_ -> expectNoCommand cmd
                                ]
                                ()
                        )
        , test "Enter still picks the highlighted item" <|
            \_ ->
                pressKeys [ "ArrowDown", "ArrowDown" ] openMenu
                    |> expectOk
                        (\( state, _ ) ->
                            send (drawMenu longMenu state) [ role "menu" ] (keyDown { shift = False } menuId "Enter")
                                |> Expect.equal (Ok (Picked "print"))
                        )
        ]



-- WHERE TO SCROLL


{-| A list of thirty-pixel rows that shows 260 pixels of them. Its border box
starts at 100 in the page and is 262 high (a border of 1 pixel), and 4 pixels of
padding sit above the first row and below the last one. Measured as the page
measures: `box` is the list, `scroll` the part that scrolls (260 high, as much as
it shows), `item` the row.
-}
measured : { rows : Int, scrolledTo : Float, row : Int } -> { box : Dom.Element, scroll : Dom.Viewport, item : Dom.Element }
measured { rows, scrolledTo, row } =
    { box = element 50 100 202 262
    , scroll =
        { scene = { width = 200, height = toFloat (rows * 30 + 8) }
        , viewport = { x = 0, y = scrolledTo, width = 200, height = 260 }
        }
    , item = element 55 (100 + 1 + 4 + toFloat (row * 30) - scrolledTo) 190 30
    }


element : Float -> Float -> Float -> Float -> Dom.Element
element x y width height =
    { scene = { width = 1000, height = 2000 }
    , viewport = { x = 0, y = 0, width = 1000, height = 800 }
    , element = { x = x, y = y, width = width, height = height }
    }


scrollsTo : String -> { rows : Int, scrolledTo : Float, row : Int } -> Float -> Test
scrollsTo name situation expected =
    test name <|
        \_ ->
            Scroll.scrollTop (measured situation)
                |> Expect.within (Expect.Absolute 0.001) expected


scrollGeometryTests : Test
scrollGeometryTests =
    describe "Klar.Menu.Scroll"
        [ describe "scrollTop: as little scrolling as possible"
            [ scrollsTo "an item that can be seen: stay where you are" { rows = 20, scrolledTo = 0, row = 3 } 0
            , scrollsTo "an item that can be seen after scrolling: stay where you are" { rows = 20, scrolledTo = 100, row = 8 } 100
            , scrollsTo "an item that ends at the bottom edge of the list can be seen" { rows = 20, scrolledTo = 74, row = 10 } 74
            , scrollsTo "an item that starts at the top edge of the list can be seen" { rows = 20, scrolledTo = 64, row = 2 } 64
            , scrollsTo "an item that sticks out at the bottom: scroll down just enough" { rows = 20, scrolledTo = 0, row = 8 } 14
            , scrollsTo "an item far below: scroll down until it ends at the bottom edge" { rows = 20, scrolledTo = 0, row = 10 } 74
            , scrollsTo "an item above: scroll up until it starts at the top edge" { rows = 20, scrolledTo = 300, row = 2 } 64
            , scrollsTo "an item that sticks out at the top: scroll up just enough" { rows = 20, scrolledTo = 100, row = 3 } 94
            , scrollsTo "never past the end of the list" { rows = 20, scrolledTo = 0, row = 40 } 348
            , scrollsTo "never before the start of the list" { rows = 20, scrolledTo = 10, row = -2 } 0
            , scrollsTo "a list that does not scroll stays at the start" { rows = 5, scrolledTo = 0, row = 12 } 0
            , test "the border is worked out from the heights, not assumed" <|
                \_ ->
                    -- The same list with a border of 3 pixels: the part that scrolls
                    -- starts at 103, so a row that starts at 102 sticks out by one.
                    let
                        situation =
                            measured { rows = 20, scrolledTo = 50, row = 0 }
                    in
                    Scroll.scrollTop
                        { situation
                            | box = element 50 100 206 266
                            , item = element 55 102 190 30
                        }
                        |> Expect.within (Expect.Absolute 0.001) 49
            ]
        , describe "edge: where the first and the last item go"
            [ test "the first item that can be picked shows the top of the list, with the heading above it" <|
                \_ -> Expect.equal Scroll.Top (Scroll.edge [ 1, 3, 6 ] 1)
            , test "the last item that can be picked shows the bottom" <|
                \_ -> Expect.equal Scroll.Bottom (Scroll.edge [ 1, 3, 6 ] 6)
            , test "an item in between is brought into view as it is" <|
                \_ -> Expect.equal Scroll.Nearest (Scroll.edge [ 1, 3, 6 ] 3)
            , test "the only item that can be picked is not an edge" <|
                \_ -> Expect.equal Scroll.Nearest (Scroll.edge [ 4 ] 4)
            , test "no items that can be picked, no edge" <|
                \_ -> Expect.equal Scroll.Nearest (Scroll.edge [] 0)
            ]
        ]



-- CONTEXT MENU


type ContextMsg
    = Context (ContextMenu.Msg String)
    | ContextPicked String


contextId : String
contextId =
    "order-context"


{-| The row that opens the menu and the menu itself, as the application draws
them. The menu has the items of `longMenu`.
-}
drawContext : ContextMenu.State String -> Html ContextMsg
drawContext state =
    Html.div []
        [ ContextMenu.area Context state { id = "order-row", target = "1042" } [ Html.text "Order 1042" ]
        , ContextMenu.view Context
            [ ContextMenu.items
                (\order ->
                    [ Menu.heading ("Order " ++ order)
                    , Menu.item "Open" (ContextPicked "open")
                    , Menu.item "Edit" (ContextPicked "edit") |> Menu.disabledItem
                    , Menu.item "Print" (ContextPicked "print")
                    , Menu.separator
                    , Menu.heading "Danger zone"
                    , Menu.item "Delete" (ContextPicked "delete")
                    ]
                )
            ]
            state
        ]


{-| The browser's `contextmenu` event on the row, with the fields the library reads.
-}
rightClick : ( String, Encode.Value )
rightClick =
    Event.custom "contextmenu"
        (Encode.object
            [ ( "clientX", Encode.float 120 )
            , ( "clientY", Encode.float 80 )
            , ( "view", Encode.object [ ( "innerWidth", Encode.int 1024 ), ( "innerHeight", Encode.int 768 ) ] )
            , ( "currentTarget", Encode.object [ ( "id", Encode.string "order-row" ) ] )
            ]
        )


inContext : ContextMenu.State String -> ContextMsg -> Result String ( ContextMenu.State String, Cmd (ContextMenu.Msg String) )
inContext state msg =
    case msg of
        Context inner ->
            Ok (ContextMenu.update inner state)

        ContextPicked _ ->
            Err "an item was picked, not a message of the menu"


{-| The context menu after a right click on the row.
-}
rightClicked : Result String (ContextMenu.State String)
rightClicked =
    let
        closed =
            ContextMenu.init contextId
    in
    send (drawContext closed) [ Selector.id "order-row" ] rightClick
        |> Result.andThen (inContext closed)
        |> Result.map Tuple.first


{-| A key pressed in the open context menu.
-}
pressInContext : String -> ContextMenu.State String -> Result String (ContextMenu.State String)
pressInContext key state =
    send (drawContext state) [ role "menu" ] (keyDown { shift = False } contextId key)
        |> Result.andThen (inContext state)
        |> Result.map Tuple.first


{-| The context menu names this item as the active one.
-}
activeInContext : Int -> ContextMenu.State String -> Expectation
activeInContext index state =
    drawContext state
        |> Query.fromHtml
        |> Query.find [ role "menu" ]
        |> Query.has [ Selector.attribute (Attr.attribute "aria-activedescendant" (itemId contextId index)) ]


{-| The mouse wheel over this element of the page.
-}
wheelOver : Encode.Value -> ( String, Encode.Value )
wheelOver target =
    Event.custom "wheel" (Encode.object [ ( "target", target ) ])


{-| An element, as the wheel event describes it, with its parent if it has one.
-}
domNode : String -> List ( String, Encode.Value ) -> Encode.Value
domNode className more =
    Encode.object (( "className", Encode.string className ) :: more)


{-| The size of what an element shows and of what it holds.
-}
holding : Float -> Float -> List ( String, Encode.Value )
holding scrollHeight clientHeight =
    [ ( "scrollHeight", Encode.float scrollHeight ), ( "clientHeight", Encode.float clientHeight ) ]


{-| The wheel closes the menu: what the open context menu is like afterwards.
-}
afterWheel : Encode.Value -> ContextMenu.State String -> Result String (ContextMenu.State String)
afterWheel target state =
    send (drawContext state) [ Selector.class "klar-context" ] (wheelOver target)
        |> Result.andThen (inContext state)
        |> Result.map Tuple.first


contextMenuTests : Test
contextMenuTests =
    describe "Klar.ContextMenu"
        [ test "a right click on the row opens the menu for it" <|
            \_ ->
                rightClicked
                    |> expectOk
                        (\state ->
                            Expect.all
                                [ ContextMenu.isOpen >> Expect.equal True
                                , ContextMenu.target >> Expect.equal (Just "1042")
                                ]
                                state
                        )
        , describe "the keys move the highlight, as in a menu"
            [ test "ArrowDown highlights the first item that can be picked" <|
                \_ ->
                    rightClicked
                        |> Result.andThen (pressInContext "ArrowDown")
                        |> expectOk (activeInContext 1)
            , test "ArrowDown skips the item that cannot be picked" <|
                \_ ->
                    rightClicked
                        |> Result.andThen (pressInContext "ArrowDown")
                        |> Result.andThen (pressInContext "ArrowDown")
                        |> expectOk (activeInContext 3)
            , test "End highlights the last item that can be picked" <|
                \_ ->
                    rightClicked
                        |> Result.andThen (pressInContext "End")
                        |> expectOk (activeInContext 6)
            , test "Home goes back to the first" <|
                \_ ->
                    rightClicked
                        |> Result.andThen (pressInContext "End")
                        |> Result.andThen (pressInContext "Home")
                        |> expectOk (activeInContext 1)
            ]
        , describe "the mouse wheel"
            [ test "closes the menu when it turns over the page" <|
                \_ ->
                    rightClicked
                        |> Result.andThen (afterWheel (domNode "klar-layer" []))
                        |> expectOk (ContextMenu.isOpen >> Expect.equal False)
            , test "closes the menu when it turns over a menu that has room for all its items" <|
                \_ ->
                    rightClicked
                        |> Result.andThen (afterWheel (domNode "klar-popup klar-menu__popup" (holding 200 200)))
                        |> expectOk (ContextMenu.isOpen >> Expect.equal False)
            , test "closes the menu when the event does not say where it was" <|
                \_ ->
                    rightClicked
                        |> Result.andThen
                            (\state ->
                                send (drawContext state) [ Selector.class "klar-context" ] (Event.custom "wheel" (Encode.object []))
                                    |> Result.andThen (inContext state)
                                    |> Result.map Tuple.first
                            )
                        |> expectOk (ContextMenu.isOpen >> Expect.equal False)
            , test "scrolls the menu, and does not close it, when the menu has more items than fit" <|
                \_ ->
                    rightClicked
                        |> expectOk
                            (\state ->
                                afterWheel (domNode "klar-popup klar-menu__popup" (holding 600 416)) state
                                    |> expectError
                            )
            , test "also over an item of a menu that scrolls" <|
                \_ ->
                    rightClicked
                        |> expectOk
                            (\state ->
                                afterWheel
                                    (domNode "klar-menu__item"
                                        [ ( "parentElement", domNode "klar-popup klar-menu__popup" (holding 600 416) ) ]
                                    )
                                    state
                                    |> expectError
                            )
            , test "over an item of a menu with room for everything it closes the menu" <|
                \_ ->
                    rightClicked
                        |> Result.andThen
                            (afterWheel
                                (domNode "klar-menu__item"
                                    [ ( "parentElement", domNode "klar-popup klar-menu__popup" (holding 200 200) ) ]
                                )
                            )
                        |> expectOk (ContextMenu.isOpen >> Expect.equal False)
            ]
        , describe "the browser's own menu"
            [ test "a right-click in a text field inside the row keeps it" <|
                \_ ->
                    send (drawContext (ContextMenu.init contextId))
                        [ Selector.id "order-row" ]
                        (rightClickWith [ ( "target", Encode.object [ ( "tagName", Encode.string "INPUT" ), ( "type", Encode.string "text" ) ] ) ])
                        |> expectError
            , test "a right-click in a text area or an editable element keeps it" <|
                \_ ->
                    Expect.all
                        [ \_ ->
                            send (drawContext (ContextMenu.init contextId))
                                [ Selector.id "order-row" ]
                                (rightClickWith [ ( "target", Encode.object [ ( "tagName", Encode.string "TEXTAREA" ) ] ) ])
                                |> expectError
                        , \_ ->
                            send (drawContext (ContextMenu.init contextId))
                                [ Selector.id "order-row" ]
                                (rightClickWith [ ( "target", Encode.object [ ( "tagName", Encode.string "DIV" ), ( "isContentEditable", Encode.bool True ) ] ) ])
                                |> expectError
                        ]
                        ()
            , test "a right-click on a checkbox in the row opens the row's menu" <|
                \_ ->
                    send (drawContext (ContextMenu.init contextId))
                        [ Selector.id "order-row" ]
                        (rightClickWith [ ( "target", Encode.object [ ( "tagName", Encode.string "INPUT" ), ( "type", Encode.string "checkbox" ) ] ) ])
                        |> Result.andThen (inContext (ContextMenu.init contextId))
                        |> expectOk (Tuple.first >> ContextMenu.isOpen >> Expect.equal True)
            , test "a right-click with Shift held keeps it" <|
                \_ ->
                    send (drawContext (ContextMenu.init contextId))
                        [ Selector.id "order-row" ]
                        (rightClickWith [ ( "shiftKey", Encode.bool True ), ( "button", Encode.int 2 ) ])
                        |> expectError
            , test "Shift+F10 (Shift held, no mouse button) still opens the menu" <|
                \_ ->
                    send (drawContext (ContextMenu.init contextId))
                        [ Selector.id "order-row" ]
                        (rightClickWith [ ( "shiftKey", Encode.bool True ), ( "button", Encode.int 0 ) ])
                        |> Result.andThen (inContext (ContextMenu.init contextId))
                        |> expectOk (Tuple.first >> ContextMenu.isOpen >> Expect.equal True)
            ]
        , test "the menu has a name for screen readers, Actions by default" <|
            \_ ->
                rightClicked
                    |> expectOk
                        (\state ->
                            drawContext state
                                |> Query.fromHtml
                                |> Query.find [ Selector.class "klar-context" ]
                                |> Query.find [ Selector.tag "button" ]
                                |> Query.has [ Selector.text "Actions" ]
                        )
        , test "Tab in the open menu does not move focus on through the page (it goes back to the row)" <|
            \_ ->
                rightClicked
                    |> expectOk
                        (\state ->
                            drawContext state
                                |> Query.fromHtml
                                |> Query.find [ Selector.class "klar-context" ]
                                |> Event.simulate (Event.custom "keydown" (Encode.object [ ( "key", Encode.string "Tab" ) ]))
                                |> Event.expectPreventDefault
                        )
        , test "the row tells a screen reader that Shift+F10 opens its menu" <|
            \_ ->
                drawContext (ContextMenu.init contextId)
                    |> Query.fromHtml
                    |> Query.find [ Selector.id "order-row" ]
                    |> Query.has [ Selector.attribute (Attr.attribute "aria-keyshortcuts" "Shift+F10") ]
        ]


{-| A right-click on the row with more fields.
-}
rightClickWith : List ( String, Encode.Value ) -> ( String, Encode.Value )
rightClickWith fields =
    Event.custom "contextmenu"
        (Encode.object
            ([ ( "clientX", Encode.float 120 )
             , ( "clientY", Encode.float 80 )
             , ( "view", Encode.object [ ( "innerWidth", Encode.int 1024 ), ( "innerHeight", Encode.int 768 ) ] )
             , ( "currentTarget", Encode.object [ ( "id", Encode.string "order-row" ) ] )
             ]
                ++ fields
            )
        )


{-| The event did not reach `update`: the menu does not handle it, the page or the
menu itself scrolls.
-}
expectError : Result String a -> Expectation
expectError result =
    case result of
        Ok _ ->
            Expect.fail "The menu handled the wheel, but it should have been left for the scrolling."

        Err _ ->
            Expect.pass
