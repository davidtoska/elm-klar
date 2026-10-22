module SplitButtonTest exposing (suite)

import Expect exposing (Expectation)
import Html exposing (Html)
import Html.Attributes as Attr
import Json.Encode as Encode
import Klar.Icon as Icon
import Klar.Locale as Locale
import Klar.Menu as Menu
import Klar.SplitButton as SplitButton
import Klar.Theme exposing (Size(..))
import Support.ActionsQuery as ActionsQuery
import Test exposing (Test, describe, test)
import Test.Html.Event as Event
import Test.Html.Query as Query
import Test.Html.Selector as Selector exposing (Selector)


suite : Test
suite =
    describe "Klar.SplitButton"
        [ closedTests
        , mainPartTests
        , openTests
        , keyboardTests
        , stateTests
        , inactiveTests
        , lookTests
        ]



-- THE PROGRAM AROUND THE BUTTON


type Msg
    = SplitMsg SplitButton.Msg
    | Save
    | SaveAndClose
    | SaveDraft
    | Discard


closed : SplitButton.State
closed =
    SplitButton.init "order-save"


opened : SplitButton.State
opened =
    SplitButton.open closed |> Tuple.first


split : List SplitButton.Attribute -> SplitButton.State -> Html Msg
split attributes state =
    SplitButton.view SplitMsg
        attributes
        { label = "Save"
        , onClick = Save
        , items =
            [ Menu.item "Save and close" SaveAndClose
            , Menu.item "Save as draft" SaveDraft
            , Menu.separator
            , Menu.item "Discard changes" Discard |> Menu.danger
            ]
        }
        state


role : String -> Selector
role name =
    Selector.attribute (Attr.attribute "role" name)


attribute : String -> String -> Selector
attribute name value =
    Selector.attribute (Attr.attribute name value)


mainPart : Query.Single Msg -> Query.Single Msg
mainPart =
    Query.children [] >> Query.first


arrow : Query.Single Msg -> Query.Single Msg
arrow =
    Query.find [ attribute "aria-haspopup" "menu" ]


{-| The keys of a `keydown` as the library reads them.
-}
keyDown : { alt : Bool } -> String -> ( String, Encode.Value )
keyDown modifiers key =
    Event.custom "keydown"
        (Encode.object
            [ ( "key", Encode.string key )
            , ( "ctrlKey", Encode.bool False )
            , ( "metaKey", Encode.bool False )
            , ( "altKey", Encode.bool modifiers.alt )
            , ( "shiftKey", Encode.bool False )
            ]
        )


{-| Hand the message that an event made to `update`.
-}
afterwards : SplitButton.State -> Result String Msg -> Result String ( SplitButton.State, Cmd SplitButton.Msg )
afterwards state result =
    case result of
        Ok (SplitMsg inner) ->
            Ok (SplitButton.update inner state)

        Ok _ ->
            Err "a message of the application, not of the split button"

        Err problem ->
            Err problem


expectOk : (a -> Expectation) -> Result String a -> Expectation
expectOk check result =
    case result of
        Ok value ->
            check value

        Err problem ->
            Expect.fail problem


expectCommand : Cmd msg -> Expectation
expectCommand cmd =
    Expect.notEqual Cmd.none cmd



-- CLOSED


closedTests : Test
closedTests =
    describe "drawn closed"
        [ test "a button and an arrow, joined" <|
            \_ ->
                split [] closed
                    |> Query.fromHtml
                    |> Expect.all
                        [ Query.has [ Selector.class "klar-split" ]
                        , ActionsQuery.count [ Selector.tag "button" ] >> Expect.equal 2
                        , mainPart >> Query.has [ Selector.tag "button", Selector.text "Save" ]
                        ]
        , test "the arrow is a button that has a menu, and says that it is closed" <|
            \_ ->
                split [] closed
                    |> Query.fromHtml
                    |> arrow
                    |> Query.has
                        [ Selector.tag "button"
                        , attribute "aria-haspopup" "menu"
                        , attribute "aria-expanded" "false"
                        , attribute "type" "button"
                        ]
        , test "the arrow is named from the main part" <|
            \_ ->
                split [] closed
                    |> Query.fromHtml
                    |> arrow
                    |> Query.has [ attribute "aria-label" "More options for Save" ]
        , test "the name follows the locale, or is given" <|
            \_ ->
                Expect.all
                    [ \_ -> split [ SplitButton.locale Locale.nb ] closed |> Query.fromHtml |> arrow |> Query.has [ attribute "aria-label" "Flere valg for Save" ]
                    , \_ -> split [ SplitButton.menuLabel "Save options" ] closed |> Query.fromHtml |> arrow |> Query.has [ attribute "aria-label" "Save options" ]
                    ]
                    ()
        , test "the arrow has a chevron and no text" <|
            \_ ->
                split [] closed
                    |> Query.fromHtml
                    |> arrow
                    |> Query.has [ Selector.containing [ Selector.class "klar-icon--chevron-down" ] ]
        , test "no menu is in the page" <|
            \_ ->
                split [] closed
                    |> Query.fromHtml
                    |> ActionsQuery.absent [ role "menu" ]
        , test "without items it has no arrow and looks like an ordinary button" <|
            \_ ->
                noItems
                    |> Query.fromHtml
                    |> Expect.all
                        [ Query.has [ Selector.class "klar-split--single" ]
                        , ActionsQuery.absent [ attribute "aria-haspopup" "menu" ]
                        , ActionsQuery.count [ Selector.tag "button" ] >> Expect.equal 1
                        , mainPart >> Query.has [ Selector.tag "button", Selector.text "Save" ]
                        ]
        , test "the main button is the same element with and without items, so it keeps focus when items arrive" <|
            \_ ->
                -- Elm patches a node in place when the tag and the position stay the
                -- same, and builds it again when they do not.
                Expect.all
                    [ \_ -> split [] closed |> Query.fromHtml |> Query.has [ Selector.tag "div", Selector.class "klar-split" ]
                    , \_ -> noItems |> Query.fromHtml |> Query.has [ Selector.tag "div", Selector.class "klar-split" ]
                    , \_ -> split [] closed |> Query.fromHtml |> mainPart |> Query.has [ Selector.tag "button", Selector.text "Save" ]
                    , \_ -> noItems |> Query.fromHtml |> mainPart |> Query.has [ Selector.tag "button", Selector.text "Save" ]
                    ]
                    ()
        ]


noItems : Html Msg
noItems =
    SplitButton.view SplitMsg [] { label = "Save", onClick = Save, items = [] } closed



-- THE MAIN PART


mainPartTests : Test
mainPartTests =
    describe "the main part"
        [ test "sends the message of the application" <|
            \_ ->
                split [] closed
                    |> Query.fromHtml
                    |> mainPart
                    |> Event.simulate Event.click
                    |> Event.expect Save
        , test "does not open the menu" <|
            \_ ->
                split [] closed
                    |> Query.fromHtml
                    |> mainPart
                    |> Event.simulate Event.click
                    |> Event.toResult
                    |> afterwards closed
                    |> Expect.err
        , test "can have an icon" <|
            \_ ->
                split [ SplitButton.icon Icon.save ] closed
                    |> Query.fromHtml
                    |> mainPart
                    |> Query.has [ Selector.containing [ Selector.class "klar-icon--save" ] ]
        ]



-- OPEN


openTests : Test
openTests =
    describe "drawn open"
        [ test "the arrow says that it is open" <|
            \_ ->
                split [] opened
                    |> Query.fromHtml
                    |> arrow
                    |> Query.has [ attribute "aria-expanded" "true" ]
        , test "the items are a menu" <|
            \_ ->
                split [] opened
                    |> Query.fromHtml
                    |> Query.find [ role "menu" ]
                    |> ActionsQuery.count [ role "menuitem" ]
                    |> Expect.equal 3
        , test "the menu ends where the split button ends" <|
            \_ ->
                split [] opened
                    |> Query.fromHtml
                    |> Query.find [ role "menu" ]
                    |> Query.has [ Selector.class "klar-popup--end" ]
        , test "picking an item sends its own message" <|
            \_ ->
                Expect.all
                    [ \_ -> pick "Save and close" |> Event.expect SaveAndClose
                    , \_ -> pick "Save as draft" |> Event.expect SaveDraft
                    , \_ -> pick "Discard changes" |> Event.expect Discard
                    ]
                    ()
        , test "a click outside the menu, on the layer, closes it and gives focus back to the arrow" <|
            \_ ->
                split [] opened
                    |> Query.fromHtml
                    |> Query.find [ Selector.class "klar-layer" ]
                    |> Event.simulate Event.click
                    |> Event.toResult
                    |> afterwards opened
                    |> expectOk
                        (\( state, cmd ) ->
                            Expect.all
                                [ \_ -> SplitButton.isOpen state |> Expect.equal False
                                , \_ -> expectCommand cmd
                                ]
                                ()
                        )
        , test "Escape closes the menu and gives focus back to the arrow" <|
            \_ ->
                split [] opened
                    |> Query.fromHtml
                    |> Query.find [ Selector.class "klar-layer" ]
                    |> Event.simulate (keyDown { alt = False } "Escape")
                    |> Event.toResult
                    |> afterwards opened
                    |> expectOk
                        (\( state, cmd ) ->
                            Expect.all
                                [ \_ -> SplitButton.isOpen state |> Expect.equal False
                                , \_ -> expectCommand cmd
                                ]
                                ()
                        )
        , test "Tab closes it (and, as in Klar.Menu, leaves focus to the browser)" <|
            \_ ->
                split [] opened
                    |> Query.fromHtml
                    |> Query.find [ Selector.class "klar-layer" ]
                    |> Event.simulate (keyDown { alt = False } "Tab")
                    |> Event.toResult
                    |> afterwards opened
                    |> expectOk (Tuple.first >> SplitButton.isOpen >> Expect.equal False)
        ]


pick : String -> Event.Event Msg
pick text =
    split [] opened
        |> Query.fromHtml
        |> Query.find [ role "menuitem", Selector.containing [ Selector.text text ] ]
        |> Event.simulate Event.click



-- THE KEYBOARD


keyboardTests : Test
keyboardTests =
    describe "keyboard"
        [ test "ArrowDown on the main part opens the menu and moves focus into it" <|
            \_ ->
                split [] closed
                    |> Query.fromHtml
                    |> mainPart
                    |> Event.simulate (keyDown { alt = False } "ArrowDown")
                    |> Event.toResult
                    |> afterwards closed
                    |> expectOk
                        (\( state, cmd ) ->
                            Expect.all
                                [ \_ -> SplitButton.isOpen state |> Expect.equal True
                                , \_ -> expectCommand cmd
                                ]
                                ()
                        )
        , test "ArrowDown on the main part keeps the browser from scrolling the page" <|
            \_ ->
                split [] closed
                    |> Query.fromHtml
                    |> mainPart
                    |> Event.simulate (keyDown { alt = False } "ArrowDown")
                    |> Event.expectPreventDefault
        , test "ArrowDown on the arrow opens the menu" <|
            \_ ->
                split [] closed
                    |> Query.fromHtml
                    |> arrow
                    |> Event.simulate (keyDown { alt = False } "ArrowDown")
                    |> Event.toResult
                    |> afterwards closed
                    |> expectOk (Tuple.first >> SplitButton.isOpen >> Expect.equal True)
        , test "Alt+ArrowDown, from either part, opens the menu" <|
            \_ ->
                -- the key is heard on the element around both parts
                split [] closed
                    |> Query.fromHtml
                    |> Event.simulate (keyDown { alt = True } "ArrowDown")
                    |> Event.toResult
                    |> afterwards closed
                    |> expectOk (Tuple.first >> SplitButton.isOpen >> Expect.equal True)
        , test "other keys do nothing, so Enter and Space click the main part and Tab leaves" <|
            \_ ->
                Expect.all
                    [ \_ -> keyOnMain "Enter" |> Event.toResult |> Expect.err
                    , \_ -> keyOnMain " " |> Event.toResult |> Expect.err
                    , \_ -> keyOnMain "Tab" |> Event.toResult |> Expect.err
                    , \_ -> keyOnMain "Escape" |> Event.toResult |> Expect.err
                    ]
                    ()
        ]


keyOnMain : String -> Event.Event Msg
keyOnMain key =
    split [] closed
        |> Query.fromHtml
        |> mainPart
        |> Event.simulate (keyDown { alt = False } key)



-- THE STATE


stateTests : Test
stateTests =
    describe "state"
        [ test "starts closed" <|
            \_ ->
                SplitButton.isOpen closed |> Expect.equal False
        , test "open and close" <|
            \_ ->
                Expect.all
                    [ \_ -> SplitButton.isOpen opened |> Expect.equal True
                    , \_ -> SplitButton.close opened |> Tuple.first |> SplitButton.isOpen |> Expect.equal False
                    , \_ -> SplitButton.close opened |> Tuple.second |> expectCommand
                    , \_ -> SplitButton.open closed |> Tuple.second |> expectCommand
                    ]
                    ()
        , test "Alt+ArrowDown in a menu that is open does not start it over" <|
            \_ ->
                split [] opened
                    |> Query.fromHtml
                    |> Event.simulate (keyDown { alt = True } "ArrowDown")
                    |> Event.toResult
                    |> afterwards opened
                    |> expectOk
                        (\( state, cmd ) ->
                            Expect.all
                                [ \_ -> SplitButton.isOpen state |> Expect.equal True
                                , \_ -> Expect.equal Cmd.none cmd
                                ]
                                ()
                        )
        ]



-- LOADING AND DISABLED


inactiveTests : Test
inactiveTests =
    describe "loading and disabled"
        [ test "while loading the main part is busy and sends nothing" <|
            \_ ->
                split [ SplitButton.loading True ] closed
                    |> Query.fromHtml
                    |> mainPart
                    |> Expect.all
                        [ Query.has [ attribute "aria-busy" "true", Selector.class "klar-button--loading" ]
                        , Query.has [ Selector.containing [ Selector.class "klar-spinner" ] ]
                        , Event.simulate Event.click >> Event.toResult >> Expect.err
                        ]
        , test "while loading the arrow cannot be used, but it is aria-disabled and not disabled, so it keeps the focus" <|
            \_ ->
                split [ SplitButton.loading True ] closed
                    |> Query.fromHtml
                    |> arrow
                    |> Expect.all
                        [ Query.has [ attribute "aria-disabled" "true", Selector.disabled False ]
                        , Event.simulate Event.click >> Event.toResult >> Expect.err
                        ]
        , test "a menu that is open when loading starts stays open and drawn: the state is not faked" <|
            \_ ->
                split [ SplitButton.loading True ] opened
                    |> Query.fromHtml
                    |> Expect.all
                        [ ActionsQuery.count [ role "menuitem" ] >> Expect.equal 3
                        , arrow >> Query.has [ attribute "aria-expanded" "true" ]
                        , \_ -> SplitButton.isOpen opened |> Expect.equal True
                        ]
        , test "while loading or disabled no message can open a closed menu (the arrow of a loading button has the keyboard focus)" <|
            \_ ->
                let
                    arrowDown attributes =
                        split attributes closed
                            |> Query.fromHtml
                            |> arrow
                            |> Event.simulate (keyDown { alt = False } "ArrowDown")
                            |> Event.toResult
                            |> afterwards closed
                in
                Expect.all
                    [ \_ -> arrowDown [ SplitButton.loading True ] |> expectOk (Tuple.first >> SplitButton.isOpen >> Expect.equal False)
                    , \_ -> arrowDown [ SplitButton.disabled True ] |> expectOk (Tuple.first >> SplitButton.isOpen >> Expect.equal False)
                    , \_ -> arrowDown [] |> expectOk (Tuple.first >> SplitButton.isOpen >> Expect.equal True)
                    ]
                    ()
        , test "while loading an open menu can still be closed" <|
            \_ ->
                split [ SplitButton.loading True ] opened
                    |> Query.fromHtml
                    |> Query.find [ Selector.class "klar-layer" ]
                    |> Event.simulate (keyDown { alt = False } "Escape")
                    |> Event.toResult
                    |> afterwards opened
                    |> expectOk (Tuple.first >> SplitButton.isOpen >> Expect.equal False)
        , test "while loading or disabled the keys that open the menu do nothing" <|
            \_ ->
                let
                    arrowDownOnMain attributes =
                        split attributes closed
                            |> Query.fromHtml
                            |> mainPart
                            |> Event.simulate (keyDown { alt = False } "ArrowDown")
                            |> Event.toResult

                    altArrowDown attributes =
                        split attributes closed
                            |> Query.fromHtml
                            |> Event.simulate (keyDown { alt = True } "ArrowDown")
                            |> Event.toResult
                in
                Expect.all
                    [ \_ -> arrowDownOnMain [ SplitButton.loading True ] |> Expect.err
                    , \_ -> altArrowDown [ SplitButton.loading True ] |> Expect.err
                    , \_ -> arrowDownOnMain [ SplitButton.disabled True ] |> Expect.err
                    , \_ -> altArrowDown [ SplitButton.disabled True ] |> Expect.err
                    , \_ -> arrowDownOnMain [] |> Expect.ok
                    ]
                    ()
        , test "without items there is no menu to open with the keys" <|
            \_ ->
                noItems
                    |> Query.fromHtml
                    |> Event.simulate (keyDown { alt = False } "ArrowDown")
                    |> Event.toResult
                    |> Expect.err
        , test "loading False is an ordinary button again" <|
            \_ ->
                split [ SplitButton.loading True, SplitButton.loading False ] closed
                    |> Query.fromHtml
                    |> arrow
                    |> Query.hasNot [ attribute "aria-disabled" "true" ]
        , test "disabled turns off both parts" <|
            \_ ->
                split [ SplitButton.disabled True ] closed
                    |> Query.fromHtml
                    |> Expect.all
                        [ mainPart >> Query.has [ Selector.disabled True ]
                        , arrow >> Query.has [ Selector.disabled True ]
                        ]
        , test "a menu that is open when the button is disabled stays open until it is closed" <|
            \_ ->
                split [ SplitButton.disabled True ] opened
                    |> Query.fromHtml
                    |> ActionsQuery.count [ role "menuitem" ]
                    |> Expect.equal 3
        ]



-- LOOK


lookTests : Test
lookTests =
    describe "look"
        [ test "both parts have the look of a Button" <|
            \_ ->
                split [ SplitButton.primary ] closed
                    |> Query.fromHtml
                    |> Expect.all
                        [ mainPart >> Query.has [ Selector.class "klar-button--primary" ]
                        , arrow >> Query.has [ Selector.class "klar-button--primary" ]
                        ]
        , test "the default is the secondary look" <|
            \_ ->
                split [] closed
                    |> Query.fromHtml
                    |> mainPart
                    |> Query.has [ Selector.class "klar-button--secondary" ]
        , test "danger on its own is the solid red button, on a secondary one only the tone" <|
            \_ ->
                Expect.all
                    [ \_ -> split [ SplitButton.danger ] closed |> Query.fromHtml |> mainPart |> Query.has [ Selector.class "klar-button--danger" ]
                    , \_ -> split [ SplitButton.danger ] closed |> Query.fromHtml |> arrow |> Query.has [ Selector.class "klar-button--danger" ]
                    , \_ -> split [ SplitButton.secondary, SplitButton.danger ] closed |> Query.fromHtml |> mainPart |> Query.has [ Selector.class "klar-button--tone-danger" ]
                    ]
                    ()
        , test "the order of the attributes does not matter" <|
            \_ ->
                let
                    drawn attributes =
                        split attributes closed
                            |> Query.fromHtml
                            |> mainPart
                            |> Query.has [ Selector.classes [ "klar-button--ghost", "klar-button--tone-danger", "klar-button--sm" ] ]
                in
                Expect.all
                    [ \_ -> drawn [ SplitButton.danger, SplitButton.ghost, SplitButton.small ]
                    , \_ -> drawn [ SplitButton.small, SplitButton.danger, SplitButton.ghost ]
                    , \_ -> drawn [ SplitButton.ghost, SplitButton.small, SplitButton.danger ]
                    ]
                    ()
        , test "the sizes reach both parts" <|
            \_ ->
                Expect.all
                    [ \_ -> split [ SplitButton.small ] closed |> Query.fromHtml |> Expect.all [ mainPart >> Query.has [ Selector.class "klar-button--sm" ], arrow >> Query.has [ Selector.class "klar-button--sm" ], Query.has [ Selector.class "klar-split--sm" ] ]
                    , \_ -> split [ SplitButton.large ] closed |> Query.fromHtml |> Expect.all [ mainPart >> Query.has [ Selector.class "klar-button--lg" ], arrow >> Query.has [ Selector.class "klar-button--lg" ] ]
                    , \_ -> split [ SplitButton.size Small, SplitButton.size Large ] closed |> Query.fromHtml |> mainPart |> Query.has [ Selector.class "klar-button--lg" ]
                    ]
                    ()
        ]
