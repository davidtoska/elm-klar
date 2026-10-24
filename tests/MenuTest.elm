module MenuTest exposing (suite)

import Expect exposing (Expectation)
import Html exposing (Html)
import Html.Attributes as Attr
import Json.Encode as Encode
import Klar.Button as Button
import Klar.Kbd as Kbd
import Klar.Menu as Menu
import Klar.Menu.TypeAhead as TypeAhead
import Klar.Shortcut as Shortcut
import Test exposing (Test, describe, test)
import Test.Html.Event as Event
import Test.Html.Query as Query
import Test.Html.Selector as Selector exposing (Selector)


suite : Test
suite =
    describe "Klar.Menu"
        [ openingTests
        , ariaTests
        , typeAheadTests
        , shortcutTests
        , unavailableTests
        ]


type Msg
    = MenuMsg Menu.Msg
    | Picked String


menuId : String
menuId =
    "order-actions"


{-| Heading 0, "Open" 1, "Edit" 2 (cannot be picked), "Duplicate" 3, separator 4,
heading 5, "Delete" 6.
-}
entries : List (Menu.Item Msg)
entries =
    [ Menu.heading "Order"
    , Menu.item "Open" (Picked "open")
    , Menu.item "Edit" (Picked "edit") |> Menu.disabledItem
    , Menu.item "Duplicate" (Picked "duplicate")
    , Menu.separator
    , Menu.heading "Danger zone"
    , Menu.item "Delete" (Picked "delete")
    ]


draw : List (Menu.Attribute Msg) -> Menu.State -> Html Msg
draw attributes state =
    Menu.view MenuMsg (Menu.label "Actions" :: Menu.items entries :: attributes) state


closed : Menu.State
closed =
    Menu.init menuId


itemId : Int -> String
itemId index =
    menuId ++ "-item-" ++ String.fromInt index


role : String -> Selector
role name =
    Selector.attribute (Attr.attribute "role" name)


attr : String -> String -> Selector
attr name value =
    Selector.attribute (Attr.attribute name value)


key : String -> ( String, Encode.Value )
key name =
    Event.custom "keydown"
        (Encode.object
            [ ( "key", Encode.string name )
            , ( "ctrlKey", Encode.bool False )
            , ( "metaKey", Encode.bool False )
            , ( "altKey", Encode.bool False )
            , ( "shiftKey", Encode.bool False )
            ]
        )


{-| A click as the browser sends it: `detail` is 0 for a click made with Enter or
Space, and the number of clicks for the pointer.
-}
click : Int -> ( String, Encode.Value )
click detail =
    Event.custom "click" (Encode.object [ ( "detail", Encode.int detail ) ])


{-| The menu after this event on the element, and its command.
-}
after : List Selector -> ( String, Encode.Value ) -> List (Menu.Attribute Msg) -> Menu.State -> Result String ( Menu.State, Cmd Menu.Msg )
after selectors event attributes state =
    draw attributes state
        |> Query.fromHtml
        |> Query.find selectors
        |> Event.simulate event
        |> Event.toResult
        |> Result.andThen
            (\msg ->
                case msg of
                    MenuMsg inner ->
                        Ok (Menu.update inner state)

                    Picked _ ->
                        Err "an item was picked"
            )


onTrigger : List Selector
onTrigger =
    [ Selector.id (menuId ++ "-trigger") ]


onMenu : List Selector
onMenu =
    [ role "menu" ]


{-| Only this item is highlighted: the menu names it and draws it so.
-}
highlights : Int -> Menu.State -> Expectation
highlights index state =
    draw [] state
        |> Query.fromHtml
        |> Expect.all
            [ Query.find onMenu >> Query.has [ attr "aria-activedescendant" (itemId index) ]
            , Query.findAll [ Selector.class "klar-menu__item--highlighted" ] >> Query.count (Expect.equal 1)
            , Query.find [ Selector.class "klar-menu__item--highlighted" ] >> Query.has [ Selector.id (itemId index) ]
            ]


highlightsNothing : Menu.State -> Expectation
highlightsNothing state =
    draw [] state
        |> Query.fromHtml
        |> Expect.all
            [ Query.find onMenu >> Query.hasNot [ Selector.attribute (Attr.attribute "aria-activedescendant" (itemId 1)) ]
            , Query.findAll [ Selector.class "klar-menu__item--highlighted" ] >> Query.count (Expect.equal 0)
            ]


expectOpenAnd : (Menu.State -> Expectation) -> Result String ( Menu.State, Cmd Menu.Msg ) -> Expectation
expectOpenAnd check result =
    case result of
        Ok ( state, _ ) ->
            Expect.all [ \_ -> Menu.isOpen state |> Expect.equal True, \_ -> check state ] ()

        Err problem ->
            Expect.fail problem


openingTests : Test
openingTests =
    describe "opening"
        [ test "Enter or Space on the button (a click with detail 0) opens at the first item that can be picked" <|
            \_ -> after onTrigger (click 0) [] closed |> expectOpenAnd (highlights 1)
        , test "a click with the pointer opens with nothing highlighted" <|
            \_ -> after onTrigger (click 1) [] closed |> expectOpenAnd highlightsNothing
        , test "ArrowDown on the button opens at the first item" <|
            \_ -> after onTrigger (key "ArrowDown") [] closed |> expectOpenAnd (highlights 1)
        , test "ArrowUp on the button opens at the last item" <|
            \_ -> after onTrigger (key "ArrowUp") [] closed |> expectOpenAnd (highlights 6)
        , test "the keys of the button keep the browser from scrolling the page" <|
            \_ ->
                draw [] closed
                    |> Query.fromHtml
                    |> Query.find onTrigger
                    |> Event.simulate (key "ArrowDown")
                    |> Event.expectPreventDefault
        , test "Menu.open highlights the first item, as the keyboard opens it" <|
            \_ -> Menu.open closed |> Tuple.first |> highlights 1
        , test "after opening at the first item, ArrowDown goes on to the next one" <|
            \_ ->
                after onTrigger (key "ArrowDown") [] closed
                    |> Result.andThen (\( state, _ ) -> after onMenu (key "ArrowDown") [] state)
                    |> expectOpenAnd (highlights 3)
        , test "Enter right after opening from the keyboard picks the first item" <|
            \_ ->
                draw [] (Tuple.first (Menu.open closed))
                    |> Query.fromHtml
                    |> Query.find onMenu
                    |> Event.simulate (key "Enter")
                    |> Event.expect (Picked "open")
        , test "triggerId is the id of the button" <|
            \_ ->
                draw [] closed
                    |> Query.fromHtml
                    |> Query.find [ Selector.id (Menu.triggerId closed) ]
                    |> Query.has [ attr "aria-haspopup" "menu" ]
        ]


ariaTests : Test
ariaTests =
    describe "names and references"
        [ test "the menu is named after its button" <|
            \_ ->
                draw [] (Tuple.first (Menu.open closed))
                    |> Query.fromHtml
                    |> Query.find onMenu
                    |> Query.has [ attr "aria-labelledby" (Menu.triggerId closed) ]
        , test "the button controls the menu while it is open, and names nothing while it is closed" <|
            \_ ->
                Expect.all
                    [ \_ -> draw [] (Tuple.first (Menu.open closed)) |> Query.fromHtml |> Query.find onTrigger |> Query.has [ attr "aria-controls" (menuId ++ "-popup") ]
                    , \_ -> draw [] closed |> Query.fromHtml |> Query.find onTrigger |> Query.hasNot [ attr "aria-controls" (menuId ++ "-popup") ]
                    ]
                    ()
        , test "a heading names the group of the items under it" <|
            \_ ->
                draw [] (Tuple.first (Menu.open closed))
                    |> Query.fromHtml
                    |> Query.findAll [ role "group" ]
                    |> Expect.all
                        [ Query.count (Expect.equal 2)
                        , Query.first >> Query.has [ attr "aria-labelledby" (menuId ++ "-heading-0") ]
                        , Query.first >> Query.find [ Selector.id (menuId ++ "-heading-0") ] >> Query.has [ Selector.text "Order", attr "aria-hidden" "true" ]
                        , Query.first >> Query.findAll [ role "menuitem" ] >> Query.count (Expect.equal 3)
                        , Query.index 1 >> Query.findAll [ role "menuitem" ] >> Query.count (Expect.equal 1)
                        ]
        , test "the separator stays outside the groups" <|
            \_ ->
                draw [] (Tuple.first (Menu.open closed))
                    |> Query.fromHtml
                    |> Query.findAll [ role "group" ]
                    |> Query.each (Query.hasNot [ Selector.class "klar-menu__separator" ])
        , test "a highlight that is no longer an item that can be picked names nothing" <|
            \_ ->
                let
                    -- End highlights "Delete", the item at index 6
                    opened =
                        after onTrigger (click 1) [] closed
                            |> Result.andThen (\( state, _ ) -> after onMenu (key "End") [] state)
                            |> Result.map Tuple.first
                            |> Result.withDefault closed

                    fewer =
                        Menu.view MenuMsg [ Menu.items [ Menu.item "Open" (Picked "open") ] ] opened
                in
                fewer
                    |> Query.fromHtml
                    |> Expect.all
                        [ Query.find onMenu >> Query.hasNot [ attr "aria-activedescendant" (itemId 6) ]
                        , Query.findAll [ Selector.class "klar-menu__item--highlighted" ] >> Query.count (Expect.equal 0)
                        ]
        ]


typeAheadTests : Test
typeAheadTests =
    describe "typing a letter"
        [ test "moves to the next item that starts with it" <|
            \_ ->
                after onMenu (key "d") [] (Tuple.first (Menu.open closed))
                    |> expectOpenAnd (highlights 3)
        , test "the same letter again goes on to the next one, and around" <|
            \_ ->
                after onMenu (key "d") [] (Tuple.first (Menu.open closed))
                    |> Result.andThen (\( state, _ ) -> after onMenu (key "d") [] state)
                    |> expectOpenAnd (highlights 6)
        , test "a letter that no item starts with leaves the highlight" <|
            \_ ->
                after onMenu (key "x") [] (Tuple.first (Menu.open closed))
                    |> expectOpenAnd (highlights 1)
        , test "the browser does not act on the letter" <|
            \_ ->
                draw [] (Tuple.first (Menu.open closed))
                    |> Query.fromHtml
                    |> Query.find onMenu
                    |> Event.simulate (key "d")
                    |> Event.expectPreventDefault
        , test "find: case and accents do not count, an item that cannot be picked is not there" <|
            \_ ->
                Expect.all
                    [ \_ -> TypeAhead.find { typed = "e", from = -1 } [ ( 1, "Open" ), ( 3, "Édit" ) ] |> Expect.equal (Just 3)
                    , \_ -> TypeAhead.find { typed = "du", from = 3 } [ ( 1, "Open" ), ( 3, "Duplicate" ), ( 6, "Delete" ) ] |> Expect.equal (Just 3)
                    , \_ -> TypeAhead.find { typed = "de", from = 3 } [ ( 1, "Open" ), ( 3, "Duplicate" ), ( 6, "Delete" ) ] |> Expect.equal (Just 6)
                    , \_ -> TypeAhead.find { typed = "dd", from = 6 } [ ( 1, "Open" ), ( 3, "Duplicate" ), ( 6, "Delete" ) ] |> Expect.equal (Just 3)
                    , \_ -> TypeAhead.find { typed = "z", from = -1 } [ ( 1, "Open" ) ] |> Expect.equal Nothing
                    ]
                    ()
        ]


shortcutTests : Test
shortcutTests =
    let
        withKeys platform =
            Menu.view MenuMsg
                [ Menu.platform platform
                , Menu.items [ Menu.item "Duplicate" (Picked "duplicate") |> Menu.withShortcut (Shortcut.mod (Shortcut.char 'd')) ]
                ]
                (Tuple.first (Menu.open closed))
    in
    describe "withShortcut"
        [ test "is announced as aria-keyshortcuts, in the names ARIA uses" <|
            \_ ->
                Expect.all
                    [ \_ -> withKeys Kbd.pc |> Query.fromHtml |> Query.find [ role "menuitem" ] |> Query.has [ attr "aria-keyshortcuts" "Control+D" ]
                    , \_ -> withKeys Kbd.mac |> Query.fromHtml |> Query.find [ role "menuitem" ] |> Query.has [ attr "aria-keyshortcuts" "Meta+D" ]
                    ]
                    ()
        , test "is drawn as key caps for the platform, hidden from screen readers" <|
            \_ ->
                Expect.all
                    [ \_ -> withKeys Kbd.pc |> Query.fromHtml |> Query.find [ Selector.class "klar-menu__keys" ] |> Query.has [ attr "aria-hidden" "true", Selector.text "Ctrl" ]
                    , \_ -> withKeys Kbd.mac |> Query.fromHtml |> Query.find [ Selector.class "klar-menu__keys" ] |> Query.has [ Selector.text "⌘" ]
                    ]
                    ()
        , test "a sequence has caps but no aria-keyshortcuts, which cannot say it" <|
            \_ ->
                Menu.view MenuMsg
                    [ Menu.items [ Menu.item "Go to orders" (Picked "go") |> Menu.withShortcut (Shortcut.sequence [ Shortcut.char 'g', Shortcut.char 'o' ]) ] ]
                    (Tuple.first (Menu.open closed))
                    |> Query.fromHtml
                    |> Query.find [ role "menuitem" ]
                    |> Expect.all
                        [ Query.hasNot [ attr "aria-keyshortcuts" "G O" ]
                        , Query.has [ Selector.class "klar-menu__keys" ]
                        ]
        ]


unavailableTests : Test
unavailableTests =
    let
        unavailable className =
            Event.custom "keydown"
                (Encode.object
                    [ ( "key", Encode.string "ArrowDown" )
                    , ( "ctrlKey", Encode.bool False )
                    , ( "metaKey", Encode.bool False )
                    , ( "altKey", Encode.bool False )
                    , ( "shiftKey", Encode.bool False )
                    , ( "currentTarget", Encode.object [ ( "className", Encode.string className ) ] )
                    ]
                )

        clickOn className =
            Event.custom "click"
                (Encode.object
                    [ ( "detail", Encode.int 1 )
                    , ( "currentTarget", Encode.object [ ( "className", Encode.string className ) ] )
                    ]
                )

        sends event =
            draw [ Menu.trigger [ Button.ariaDisabled True ] ] closed
                |> Query.fromHtml
                |> Query.find onTrigger
                |> Event.simulate event
                |> Event.toResult
    in
    describe "a button that is unavailable"
        [ test "does not open the menu with ArrowDown" <|
            \_ -> sends (unavailable "klar-button klar-button--secondary klar-button--disabled") |> Expect.err
        , test "does not open it while it is loading" <|
            \_ -> sends (unavailable "klar-button klar-button--loading") |> Expect.err
        , test "does not open it with a click" <|
            \_ -> sends (clickOn "klar-button klar-button--disabled") |> Expect.err
        , test "is drawn unavailable" <|
            \_ ->
                draw [ Menu.trigger [ Button.ariaDisabled True ] ] closed
                    |> Query.fromHtml
                    |> Query.find onTrigger
                    |> Query.has [ Selector.class "klar-button--disabled", attr "aria-disabled" "true" ]
        ]
