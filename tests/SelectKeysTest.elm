module SelectKeysTest exposing (suite)

{-| The keys, the focus path and the ARIA references of the select family
(`Klar.Select`, `Klar.MultiSelect`, `Klar.Autocomplete`):

  - The keys of an input method composition (Japanese, Chinese, Korean ...) are
    the input method's: the Enter that confirms the composed text never chooses
    an option, and the arrows choose a candidate, not a row.
  - Home and End move the caret in a search box with text, and go to the first
    and last row only while it is empty; Ctrl+Home and Ctrl+End always do.
  - `aria-activedescendant` names only a row that is on the page: the list draws
    the rows around the scroll position, and an id that is not there names
    nothing.
  - With old options whose refresh failed, Tab goes from the search box to the
    "Try again" of the notice, and from there out of the popup, which closes
    behind it; a click on that button gives the focus back to the search box.
  - The value setters take what the model holds (`Select.setValue` a `Maybe`),
    and "Select all" adds what is left, once, in `update`.

-}

import Expect exposing (Expectation)
import Html exposing (Html)
import Html.Attributes as Attr
import Json.Encode as Encode
import Klar.Autocomplete as Autocomplete
import Klar.MultiSelect as MultiSelect
import Klar.Remote as Remote exposing (Remote(..))
import Klar.Select as Select
import Klar.Theme as Theme
import Klar.VirtualList as VirtualList
import Test exposing (Test, describe, test)
import Test.Html.Event as Event exposing (Event)
import Test.Html.Query as Query
import Test.Html.Selector as Selector exposing (Selector)
import Time


suite : Test
suite =
    describe "The keys and the focus path of the select family"
        [ compositionTests
        , homeEndTests
        , activeDescendantTests
        , staleNoticeTests
        , setValueTests
        , selectAllTests
        , groupTests
        , isDrawnTests
        , autocompleteTests
        ]


type Msg
    = SelectMsg (Select.Msg String)
    | MultiMsg (MultiSelect.Msg String)
    | AutoMsg (Autocomplete.Msg String)
    | Retry



-- KEYS


type alias Press =
    { key : String
    , ctrl : Bool
    , composing : Bool
    , keyCode : Int
    , text : String
    }


plain : String -> Press
plain name =
    { key = name, ctrl = False, composing = False, keyCode = 0, text = "" }


keydown : Press -> ( String, Encode.Value )
keydown p =
    Event.custom "keydown"
        (Encode.object
            [ ( "key", Encode.string p.key )
            , ( "ctrlKey", Encode.bool p.ctrl )
            , ( "metaKey", Encode.bool False )
            , ( "altKey", Encode.bool False )
            , ( "shiftKey", Encode.bool False )
            , ( "isComposing", Encode.bool p.composing )
            , ( "keyCode", Encode.int p.keyCode )
            , ( "target", Encode.object [ ( "value", Encode.string p.text ) ] )
            ]
        )


pressOn : List Selector -> Press -> Html Msg -> Event Msg
pressOn selectors p html =
    html
        |> Query.fromHtml
        |> Query.find selectors
        |> Event.simulate (keydown p)


{-| Nothing acts on the key: the browser (or the input method) has it.
-}
expectIgnored : Event Msg -> Expectation
expectIgnored event =
    case Event.toResult event of
        Err _ ->
            Expect.pass

        Ok _ ->
            Expect.fail "the key was acted on, but it belongs to the browser or the input method"


expectHandled : Event Msg -> Expectation
expectHandled event =
    Expect.all
        [ Event.expectPreventDefault
        , \e ->
            case Event.toResult e of
                Ok _ ->
                    Expect.pass

                Err why ->
                    Expect.fail ("the key was not handled: " ++ why)
        ]
        event


messageOf : Event Msg -> Result String Msg
messageOf event =
    Event.toResult event



-- FIXTURES


countries : List (Select.Option String)
countries =
    List.map (\n -> Select.option ("c" ++ String.fromInt n) ("Country " ++ String.fromInt n)) (List.range 1 200)


openSelect : Select.State String
openSelect =
    Select.init "country" |> Select.open |> Tuple.first


selectView : List (Select.Attribute String Msg) -> Select.State String -> Html Msg
selectView attributes state =
    Select.view SelectMsg (Select.label "Country" :: attributes) state


search : List Selector
search =
    [ Selector.id "country-search" ]


openMulti : MultiSelect.State String
openMulti =
    MultiSelect.init "countries" |> MultiSelect.open |> Tuple.first


multiView : List (MultiSelect.Attribute String Msg) -> MultiSelect.State String -> Html Msg
multiView attributes state =
    MultiSelect.view MultiMsg (MultiSelect.label "Countries" :: attributes) state


multiSearch : List Selector
multiSearch =
    [ Selector.id "countries-search" ]


{-| The select after the messages, each fed back through `update`.
-}
selectAfter : List Msg -> Select.State String -> Select.State String
selectAfter messages state =
    List.foldl
        (\msg current ->
            case msg of
                SelectMsg inner ->
                    Tuple.first (Select.update inner current)

                _ ->
                    current
        )
        state
        messages


multiAfter : List Msg -> MultiSelect.State String -> MultiSelect.State String
multiAfter messages state =
    List.foldl
        (\msg current ->
            case msg of
                MultiMsg inner ->
                    Tuple.first (MultiSelect.update inner current)

                _ ->
                    current
        )
        state
        messages


{-| The autocomplete after the user typed `text`: typing is the only way to
open it, so the state comes from the input event, as in a browser.
-}
typedInto : String -> List (Autocomplete.Attribute String Msg) -> Result String (Autocomplete.State String)
typedInto text attributes =
    let
        start =
            Autocomplete.init "city"
    in
    Autocomplete.view AutoMsg attributes start
        |> Query.fromHtml
        |> Query.find [ Selector.tag "input" ]
        |> Event.simulate (Event.input text)
        |> Event.toResult
        |> Result.andThen
            (\msg ->
                case msg of
                    AutoMsg inner ->
                        Ok (Tuple.first (Autocomplete.update inner start))

                    _ ->
                        Err "the input sent a message of another component"
            )


cities : List (Select.Option String)
cities =
    [ Select.option "ams" "Amsterdam", Select.option "ber" "Berlin", Select.option "bern" "Bern" ]



-- COMPOSITION


compositionTests : Test
compositionTests =
    let
        composingEnter =
            { key = "Enter", ctrl = False, composing = True, keyCode = 229, text = "" }

        composingArrow =
            { key = "ArrowDown", ctrl = False, composing = True, keyCode = 229, text = "" }

        keyCode229Enter =
            { key = "Enter", ctrl = False, composing = False, keyCode = 229, text = "" }
    in
    describe "Keys of an input method composition are left to it"
        [ test "Select: the Enter that confirms a composition does not choose" <|
            \_ ->
                selectView [ Select.options countries ] openSelect
                    |> pressOn search composingEnter
                    |> expectIgnored
        , test "Select: the key code 229 alone is a composition too" <|
            \_ ->
                selectView [ Select.options countries ] openSelect
                    |> pressOn search keyCode229Enter
                    |> expectIgnored
        , test "Select: the arrows choose a candidate, not a row" <|
            \_ ->
                selectView [ Select.options countries ] openSelect
                    |> pressOn search composingArrow
                    |> expectIgnored
        , test "Select: a plain Enter still chooses" <|
            \_ ->
                selectView [ Select.options countries ] openSelect
                    |> pressOn search (plain "Enter")
                    |> expectHandled
        , test "Select: the closed field does not open on a composing key" <|
            \_ ->
                selectView [ Select.options countries ] (Select.init "country")
                    |> pressOn [ Selector.id "country" ] composingArrow
                    |> expectIgnored
        , test "MultiSelect: the Enter that confirms a composition does not toggle" <|
            \_ ->
                multiView [ MultiSelect.options countries ] openMulti
                    |> pressOn multiSearch composingEnter
                    |> expectIgnored
        , test "Autocomplete: the Enter that confirms a composition does not pick" <|
            \_ ->
                case typedInto "Ber" [ Autocomplete.options cities ] of
                    Ok state ->
                        Autocomplete.view AutoMsg [ Autocomplete.options cities ] state
                            |> pressOn [ Selector.id "city" ] composingEnter
                            |> expectIgnored

                    Err why ->
                        Expect.fail why
        ]



-- HOME AND END


homeEndTests : Test
homeEndTests =
    let
        withText name =
            { key = name, ctrl = False, composing = False, keyCode = 0, text = "Coun" }

        withCtrl name =
            { key = name, ctrl = True, composing = False, keyCode = 0, text = "Coun" }
    in
    describe "Home and End in a search box"
        [ test "Select: End in an empty search box goes to the last row" <|
            \_ ->
                let
                    view =
                        selectView [ Select.options countries ] openSelect
                in
                case messageOf (pressOn search (plain "End") view) of
                    Ok msg ->
                        selectView [ Select.options countries ] (selectAfter [ msg ] openSelect)
                            |> Query.fromHtml
                            |> Query.find search
                            |> Query.has [ Selector.attribute (Attr.attribute "aria-activedescendant" "country-opt-199") ]

                    Err why ->
                        Expect.fail ("End was not handled: " ++ why)
        , test "Select: Home and End with text in the box move the caret" <|
            \_ ->
                Expect.all
                    [ \view -> view |> pressOn search (withText "Home") |> expectIgnored
                    , \view -> view |> pressOn search (withText "End") |> expectIgnored
                    ]
                    (selectView [ Select.options countries ] openSelect)
        , test "Select: Ctrl+Home and Ctrl+End always move the highlight" <|
            \_ ->
                Expect.all
                    [ \view -> view |> pressOn search (withCtrl "Home") |> expectHandled
                    , \view -> view |> pressOn search (withCtrl "End") |> expectHandled
                    ]
                    (selectView [ Select.options countries ] openSelect)
        , test "MultiSelect: Home with text in the box moves the caret" <|
            \_ ->
                multiView [ MultiSelect.options countries ] openMulti
                    |> pressOn multiSearch (withText "Home")
                    |> expectIgnored
        , test "MultiSelect: Home in an empty box goes to the first row" <|
            \_ ->
                multiView [ MultiSelect.options countries ] openMulti
                    |> pressOn multiSearch (plain "Home")
                    |> expectHandled
        ]



-- ARIA-ACTIVEDESCENDANT


activeDescendantTests : Test
activeDescendantTests =
    let
        scrolledFar =
            selectView [ Select.options countries ] openSelect
                |> Query.fromHtml
                |> Query.find [ Selector.id "country-listbox" ]
                |> Event.simulate (Event.custom "scroll" (Encode.object [ ( "target", Encode.object [ ( "scrollTop", Encode.float 4000 ) ] ) ]))
                |> Event.toResult
    in
    describe "aria-activedescendant names a row that is on the page"
        [ test "on open it names the highlighted first row, which is drawn" <|
            \_ ->
                selectView [ Select.options countries ] openSelect
                    |> Query.fromHtml
                    |> Expect.all
                        [ Query.find search >> Query.has [ Selector.attribute (Attr.attribute "aria-activedescendant" "country-opt-0") ]
                        , Query.has [ Selector.id "country-opt-0" ]
                        ]
        , test "after the wheel scrolled the highlighted row away, it names nothing" <|
            \_ ->
                case scrolledFar of
                    Ok msg ->
                        selectView [ Select.options countries ] (selectAfter [ msg ] openSelect)
                            |> Query.fromHtml
                            |> Expect.all
                                [ Query.findAll [ Selector.id "country-opt-0" ] >> Query.count (Expect.equal 0)
                                , Query.find search >> Query.hasNot [ Selector.attribute (Attr.attribute "aria-activedescendant" "country-opt-0") ]
                                ]

                    Err why ->
                        Expect.fail ("the list did not report the scroll: " ++ why)
        ]



-- THE OLD-DATA NOTICE


staleOptions : Remote (List (Select.Option String))
staleOptions =
    Remote.refreshWith (Loaded (List.take 3 countries)) (Err (Remote.problem Remote.network)) (Time.millisToPosix 0)


staleNoticeTests : Test
staleNoticeTests =
    let
        view =
            selectView [ Select.remote staleOptions, Select.onRetry Retry ] openSelect
    in
    describe "Old options with a failed refresh: Tab reaches Try again, focus never drops"
        [ test "the notice shows its Try again button" <|
            \_ ->
                view
                    |> Query.fromHtml
                    |> Query.find [ Selector.class "klar-select__notice" ]
                    |> Query.findAll [ Selector.tag "button" ]
                    |> Query.count (Expect.equal 1)
        , test "Tab in the search box is left to the browser and does not close the list" <|
            \_ ->
                view
                    |> pressOn search (plain "Tab")
                    |> expectIgnored
        , test "Tab on the notice closes the list behind the focus that moves on" <|
            \_ ->
                case messageOf (pressOn [ Selector.class "klar-select__notice" ] (plain "Tab") view) of
                    Ok msg ->
                        Expect.equal False (Select.isOpen (selectAfter [ msg ] openSelect))

                    Err why ->
                        Expect.fail ("Tab on the notice was not handled: " ++ why)
        , test "a click on the notice keeps the list open (focus goes back to the search box)" <|
            \_ ->
                view
                    |> Query.fromHtml
                    |> Query.find [ Selector.class "klar-select__notice" ]
                    |> Event.simulate Event.click
                    |> Event.toResult
                    |> Result.map (\msg -> Select.isOpen (selectAfter [ msg ] openSelect))
                    |> Expect.equal (Ok True)
        , test "without onRetry there is no button, and Tab closes the list as usual" <|
            \_ ->
                case messageOf (pressOn search (plain "Tab") (selectView [ Select.remote staleOptions ] openSelect)) of
                    Ok msg ->
                        Expect.equal False (Select.isOpen (selectAfter [ msg ] openSelect))

                    Err why ->
                        Expect.fail ("Tab was not handled: " ++ why)
        , test "MultiSelect: Tab is left to the browser too, on to Try again" <|
            \_ ->
                multiView [ MultiSelect.remote staleOptions, MultiSelect.onRetry Retry ] (MultiSelect.clear openMulti)
                    |> pressOn multiSearch (plain "Tab")
                    |> expectIgnored
        ]



-- SET VALUE


setValueTests : Test
setValueTests =
    describe "Select.setValue takes what the model holds"
        [ test "Just chooses the value" <|
            \_ ->
                Select.init "country"
                    |> Select.setValue (Just "c3")
                    |> Select.value
                    |> Expect.equal (Just "c3")
        , test "Nothing empties the field" <|
            \_ ->
                Select.init "country"
                    |> Select.setValue (Just "c3")
                    |> Select.setValue Nothing
                    |> Select.value
                    |> Expect.equal Nothing
        , test "a value the loaded options lack is \"Unknown value\" without valueText" <|
            \_ ->
                selectView [ Select.options (List.take 3 countries) ] (Select.init "country" |> Select.setValue (Just "zz"))
                    |> Query.fromHtml
                    |> Query.find [ Selector.id "country" ]
                    |> Query.has [ Selector.text "Unknown value" ]
        , test "and the text of valueText with it" <|
            \_ ->
                selectView [ Select.options (List.take 3 countries), Select.valueText (\v -> "Country " ++ v) ] (Select.init "country" |> Select.setValue (Just "zz"))
                    |> Query.fromHtml
                    |> Query.find [ Selector.id "country" ]
                    |> Query.has [ Selector.text "Country zz" ]
        ]



-- SELECT ALL


selectAllButton : Html Msg -> Query.Single Msg
selectAllButton html =
    html
        |> Query.fromHtml
        |> Query.find [ Selector.tag "button", Selector.containing [ Selector.text "Select all" ] ]


selectAllTests : Test
selectAllTests =
    let
        few =
            List.take 4 countries

        allChosen =
            openMulti |> MultiSelect.setValues (List.map .value few)

        clickSelectAll attributes state =
            multiView attributes state
                |> selectAllButton
                |> Event.simulate Event.click
                |> Event.toResult
                |> Result.map (\msg -> multiAfter [ msg ] state)
    in
    describe "MultiSelect: Select all"
        [ test "is unavailable when every match is chosen" <|
            \_ ->
                multiView [ MultiSelect.options few ] allChosen
                    |> selectAllButton
                    |> Query.has [ Selector.attribute (Attr.disabled True) ]
        , test "adds the matches that are not chosen yet, after the chosen ones" <|
            \_ ->
                clickSelectAll [ MultiSelect.options few ] (openMulti |> MultiSelect.setValues [ "c3" ])
                    |> Result.map MultiSelect.values
                    |> Expect.equal (Ok [ "c3", "c1", "c2", "c4" ])
        , test "adds only as many as maxSelected leaves" <|
            \_ ->
                clickSelectAll [ MultiSelect.options few, MultiSelect.maxSelected 2 ] (openMulti |> MultiSelect.setValues [ "c3" ])
                    |> Result.map MultiSelect.values
                    |> Expect.equal (Ok [ "c3", "c1" ])
        , test "removing a chip from the closed field is announced" <|
            \_ ->
                let
                    closed =
                        MultiSelect.init "countries" |> MultiSelect.setOptions (List.take 2 countries)
                in
                multiView [ MultiSelect.options few ] closed
                    |> Query.fromHtml
                    |> Query.findAll [ Selector.class "klar-tag__remove" ]
                    |> Query.first
                    |> Event.simulate Event.click
                    |> Event.toResult
                    |> Result.map
                        (\msg ->
                            multiView [ MultiSelect.options few ] (multiAfter [ msg ] closed)
                                |> Query.fromHtml
                                |> Query.find [ Selector.class "klar-select__control" ]
                                |> Query.children [ Selector.attribute (Attr.attribute "role" "status") ]
                                |> Query.first
                                |> Query.has [ Selector.text "Country 1 removed" ]
                        )
                    |> Result.withDefault (Expect.fail "the remove button sent nothing")
        , test "a long list with everything chosen: the click adds nothing twice" <|
            \_ ->
                let
                    many =
                        List.map (\n -> Select.option ("v" ++ String.fromInt n) ("Value " ++ String.fromInt n)) (List.range 1 1000)

                    state =
                        openMulti |> MultiSelect.setValues (List.map .value many)
                in
                clickSelectAll [ MultiSelect.options many ] state
                    |> Result.map (MultiSelect.values >> List.length)
                    |> Expect.equal (Ok 1000)
        ]



-- GROUPS


groupTests : Test
groupTests =
    test "an option says its group to screen readers (the heading rows are not in the listbox)" <|
        \_ ->
            selectView [ Select.options [ Select.option "no" "Norway" |> Select.withGroup "Europe" ] ] openSelect
                |> Query.fromHtml
                |> Query.find [ Selector.id "country-opt-1" ]
                |> Query.find [ Selector.class "klar-sr-only" ]
                |> Query.has [ Selector.text ", Europe" ]



-- VIRTUAL LIST


isDrawnTests : Test
isDrawnTests =
    let
        geometry =
            { rowHeight = 32, height = 320, count = 1000, inset = 0 }

        scrolled top =
            VirtualList.init "rows" |> VirtualList.scrollTo top |> Tuple.first
    in
    describe "VirtualList.isDrawn"
        [ test "the rows in view are drawn" <|
            \_ ->
                Expect.equal [ True, True, True ]
                    (List.map (\i -> VirtualList.isDrawn geometry i (scrolled 0)) [ 0, 5, 10 ])
        , test "a row far below the view is not" <|
            \_ -> Expect.equal False (VirtualList.isDrawn geometry 500 (scrolled 0))
        , test "after scrolling, the rows above are gone and the rows in view are drawn" <|
            \_ ->
                Expect.equal [ False, True, True ]
                    (List.map (\i -> VirtualList.isDrawn geometry i (scrolled 3200)) [ 0, 100, 109 ])
        , test "a row past the end is never drawn" <|
            \_ -> Expect.equal False (VirtualList.isDrawn { geometry | count = 3 } 3 (scrolled 0))
        , test "reveal centres a row that is out of view and makes it the active row" <|
            \_ ->
                let
                    ( revealed, _ ) =
                        VirtualList.reveal [] { row = 500, count = 1000 } (VirtualList.init "rows")
                in
                -- rows of 44 px (the Normal density), a list of 320 px
                Expect.equal ( Just 500, 500 * 44 - (320 - 44) / 2 )
                    ( VirtualList.active revealed, VirtualList.scrollTop revealed )
        , test "reveal leaves a row in view where it is" <|
            \_ ->
                let
                    ( revealed, _ ) =
                        VirtualList.reveal [] { row = 2, count = 1000 } (VirtualList.init "rows")
                in
                Expect.equal ( Just 2, 0 ) ( VirtualList.active revealed, VirtualList.scrollTop revealed )
        , test "reveal follows the density of the list" <|
            \_ ->
                let
                    ( revealed, _ ) =
                        VirtualList.reveal [ VirtualList.density Theme.Compact ] { row = 500, count = 1000 } (VirtualList.init "rows")
                in
                Expect.equal (500 * 32 - (320 - 32) / 2) (VirtualList.scrollTop revealed)
        , test "reveal clamps a row past the end to the last" <|
            \_ ->
                VirtualList.reveal [] { row = 5000, count = 10 } (VirtualList.init "rows")
                    |> Tuple.first
                    |> VirtualList.active
                    |> Expect.equal (Just 9)
        ]



-- AUTOCOMPLETE


autoAfter : Event Msg -> Autocomplete.State String -> Result String (Autocomplete.State String)
autoAfter event state =
    Event.toResult event
        |> Result.andThen
            (\msg ->
                case msg of
                    AutoMsg inner ->
                        Ok (Tuple.first (Autocomplete.update inner state))

                    _ ->
                        Err "a message of another component"
            )


autoInput : List Selector
autoInput =
    [ Selector.id "city" ]


{-| The autocomplete after typing `text`, then the event on the input.
-}
typedThen : String -> List (Autocomplete.Attribute String Msg) -> ( String, Encode.Value ) -> Result String (Autocomplete.State String)
typedThen text attributes event =
    typedInto text attributes
        |> Result.andThen
            (\state ->
                Autocomplete.view AutoMsg attributes state
                    |> Query.fromHtml
                    |> Query.find autoInput
                    |> Event.simulate event
                    |> (\e -> autoAfter e state)
            )


autocompleteTests : Test
autocompleteTests =
    let
        local =
            [ Autocomplete.options cities ]

        pickedAfter event =
            typedThen "berlin" local event |> Result.map Autocomplete.picked
    in
    describe "Autocomplete: typed values, and picked the same however the field is left"
        [ test "Enter on a text that is a suggestion's label picks it" <|
            \_ -> Expect.equal (Ok (Just "ber")) (pickedAfter (keydown (plain "Enter")))
        , test "Tab picks it too" <|
            \_ -> Expect.equal (Ok (Just "ber")) (pickedAfter (keydown (plain "Tab")))
        , test "Escape picks it too" <|
            \_ -> Expect.equal (Ok (Just "ber")) (pickedAfter (keydown (plain "Escape")))
        , test "and so does a click elsewhere (blur)" <|
            \_ -> Expect.equal (Ok (Just "ber")) (pickedAfter Event.blur)
        , test "a free text picks nothing" <|
            \_ ->
                typedThen "Berlinn" local Event.blur
                    |> Result.map Autocomplete.picked
                    |> Expect.equal (Ok Nothing)
        , test "setOption puts a saved suggestion back: its label and its value" <|
            \_ ->
                let
                    state =
                        Autocomplete.init "city" |> Autocomplete.setOption (Select.option "bern" "Bern")
                in
                Expect.equal ( "Bern", Just "bern" ) ( Autocomplete.text state, Autocomplete.picked state )
        , test "a picked suggestion keeps its value when another has the same label" <|
            \_ ->
                let
                    twins =
                        [ Autocomplete.options [ Select.option "il" "Springfield", Select.option "mo" "Springfield" ] ]

                    state =
                        Autocomplete.init "city" |> Autocomplete.setOption (Select.option "mo" "Springfield")
                in
                Autocomplete.view AutoMsg twins state
                    |> Query.fromHtml
                    |> Query.find autoInput
                    |> Event.simulate Event.blur
                    |> (\e -> autoAfter e state)
                    |> Result.map Autocomplete.picked
                    |> Expect.equal (Ok (Just "mo"))
        , test "clear empties the text and the pick" <|
            \_ ->
                Autocomplete.init "city"
                    |> Autocomplete.setOption (Select.option "bern" "Bern")
                    |> Autocomplete.clear
                    |> (\state -> ( Autocomplete.text state, Autocomplete.picked state ))
                    |> Expect.equal ( "", Nothing )
        , test "a read-only field reacts to no key, and sends no onEnter" <|
            \_ ->
                Autocomplete.view AutoMsg
                    [ Autocomplete.options cities, Autocomplete.readOnly True, Autocomplete.onEnter Retry ]
                    (Autocomplete.init "city" |> Autocomplete.setText "Berlin")
                    |> Expect.all
                        [ \view -> view |> pressOn autoInput (plain "Enter") |> expectIgnored
                        , \view -> view |> pressOn [ Selector.class "klar-autocomplete" ] (plain "Enter") |> expectIgnored
                        ]
        , test "while \"No suggestions\" shows, aria-controls names the popup that says so" <|
            \_ ->
                case typedInto "zz" [ Autocomplete.remote (Loaded []) ] of
                    Ok state ->
                        Autocomplete.view AutoMsg [ Autocomplete.remote (Loaded []) ] state
                            |> Query.fromHtml
                            |> Expect.all
                                [ Query.find autoInput >> Query.has [ Selector.attribute (Attr.attribute "aria-controls" "city-popup") ]
                                , Query.has [ Selector.id "city-popup" ]
                                ]

                    Err why ->
                        Expect.fail why
        , test "open and close, like Select" <|
            \_ ->
                let
                    opened =
                        Autocomplete.init "city" |> Autocomplete.open |> Tuple.first
                in
                Expect.equal ( True, False )
                    ( Autocomplete.isOpen opened, Autocomplete.isOpen (Tuple.first (Autocomplete.close opened)) )
        ]
