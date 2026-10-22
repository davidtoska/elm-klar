module SelectFixTest exposing (suite)

{-| Regression tests for the select family (`Klar.Select`, `Klar.MultiSelect`,
`Klar.Autocomplete`) and the machinery they share (`Klar.Select.Popup`):

  - What Enter and Tab do after options failed to load depends on whether the
    "Try again" button is on screen. The button is there only when the problem
    is worth retrying (`Remote.isRetryable`) and the application gave an
    `onRetry`. Without the button, Enter must not send the retry message and Tab
    must close the list and move on.
  - A field that is typed into keeps its wrapper (`Field.viewStable`), so the
    browser does not rebuild the input, and drop keyboard focus, when the
    application sets an error while the user types.

-}

import Expect exposing (Expectation)
import Html exposing (Html)
import Json.Encode as Encode
import Klar.Autocomplete as Autocomplete
import Klar.Locale as Locale
import Klar.MultiSelect as MultiSelect
import Klar.Remote as Remote exposing (Kind, Remote(..))
import Klar.Select as Select
import Klar.Select.Popup as Popup
import Test exposing (Test, describe, test)
import Test.Html.Event as Event exposing (Event)
import Test.Html.Query as Query
import Test.Html.Selector as Selector exposing (Selector)


suite : Test
suite =
    describe "The select family (retry keys, stable field)"
        [ retryForTests
        , failureViewTests
        , selectTests
        , multiSelectTests
        , autocompleteTests
        , stableFieldTests
        ]


type Msg
    = SelectMsg (Select.Msg String)
    | MultiMsg (MultiSelect.Msg String)
    | AutoMsg Autocomplete.Msg
    | Retry
    | Leave
    | Refocus
    | NoOp



-- THE PROBLEMS


{-| Network trouble, timeouts, server errors and unknown errors are worth
retrying. Everything else fails the same way again.
-}
worthRetrying : List Kind
worthRetrying =
    [ Remote.network, Remote.timeout, Remote.server, Remote.unknown ]


notWorthRetrying : List Kind
notWorthRetrying =
    [ Remote.notFound, Remote.forbidden, Remote.unauthorized, Remote.validation, Remote.conflict ]


kindName : Kind -> String
kindName kind =
    [ ( Remote.network, "Network" )
    , ( Remote.timeout, "Timeout" )
    , ( Remote.server, "Server" )
    , ( Remote.notFound, "NotFound" )
    , ( Remote.forbidden, "Forbidden" )
    , ( Remote.unauthorized, "Unauthorized" )
    , ( Remote.validation, "Validation" )
    , ( Remote.conflict, "Conflict" )
    ]
        |> List.filter (\( k, _ ) -> k == kind)
        |> List.head
        |> Maybe.map Tuple.second
        |> Maybe.withDefault "Unknown"


problem : Kind -> Remote.Problem
problem kind =
    Remote.problem kind


failed : Kind -> Remote (List (Select.Option String))
failed kind =
    Failed (problem kind)


orders : List (Select.Option String)
orders =
    [ Select.option "o-1" "Order 1001", Select.option "o-2" "Order 1002" ]



-- THE KEYS


key : String -> ( String, Encode.Value )
key name =
    keyWith { shift = False } name


keyWith : { shift : Bool } -> String -> ( String, Encode.Value )
keyWith modifiers name =
    Event.custom "keydown"
        (Encode.object
            [ ( "key", Encode.string name )
            , ( "ctrlKey", Encode.bool False )
            , ( "metaKey", Encode.bool False )
            , ( "altKey", Encode.bool False )
            , ( "shiftKey", Encode.bool modifiers.shift )
            ]
        )


{-| The key press on the one element the selectors name, ready for the
expectations of `Test.Html.Event`.
-}
pressOn : List Selector -> ( String, Encode.Value ) -> Html Msg -> Event Msg
pressOn selectors event html =
    html
        |> Query.fromHtml
        |> Query.find selectors
        |> Event.simulate event


{-| The key press on the outermost element of the view itself.
-}
pressOnRoot : ( String, Encode.Value ) -> Html Msg -> Event Msg
pressOnRoot event html =
    html
        |> Query.fromHtml
        |> Event.simulate event


{-| Fails when the key sent the retry message.
-}
isNotRetry : Msg -> Expectation
isNotRetry msg =
    if msg == Retry then
        Expect.fail "the key sent the retry message, but no \"Try again\" button is on screen"

    else
        Expect.pass


{-| The key is handled and the browser's own action (submitting a form,
moving focus) is prevented. It does not send the retry message.
-}
expectHandledWithoutRetry : Event Msg -> Expectation
expectHandledWithoutRetry event =
    Expect.all
        [ Event.expectPreventDefault
        , expectMessage isNotRetry
        ]
        event


{-| The key is left to the browser: the element sends nothing and does not
prevent the default action, so Tab moves focus on.
-}
expectLeftToBrowser : Event Msg -> Expectation
expectLeftToBrowser event =
    case Event.toResult event of
        Err _ ->
            Expect.pass

        Ok _ ->
            Expect.fail "the key is handled, but it should be left to the browser (Tab moves on to the button)"


expectMessage : (Msg -> Expectation) -> Event Msg -> Expectation
expectMessage toExpectation event =
    case Event.toResult event of
        Ok msg ->
            toExpectation msg

        Err why ->
            Expect.fail ("the element did not handle the key: " ++ why)


{-| The key sent this message, and did not prevent the browser's action.
-}
expectPassiveMessage : (Msg -> Expectation) -> Event Msg -> Expectation
expectPassiveMessage toExpectation event =
    Expect.all
        [ Event.expectNotPreventDefault
        , expectMessage toExpectation
        ]
        event


expectRetry : Event Msg -> Expectation
expectRetry event =
    Expect.all
        [ Event.expectPreventDefault
        , expectMessage (\msg -> Expect.equal Retry msg)
        ]
        event


expectThat : Bool -> String -> Expectation
expectThat ok why =
    if ok then
        Expect.pass

    else
        Expect.fail why



-- THE RETRY BUTTON ON SCREEN


tryAgain : Int -> Html Msg -> Expectation
tryAgain count html =
    html
        |> Query.fromHtml
        |> Query.find [ Selector.class "klar-select__state" ]
        |> Query.findAll [ Selector.tag "button" ]
        |> Query.count (Expect.equal count)



-- RETRY FOR


retryForTests : Test
retryForTests =
    describe "Popup.retryFor (the one place that says whether \"Try again\" exists)"
        [ describe "a problem worth retrying, with onRetry"
            (List.map
                (\kind ->
                    test (kindName kind) <|
                        \_ -> Expect.equal (Just Retry) (Popup.retryFor (problem kind) (Just Retry))
                )
                worthRetrying
            )
        , describe "a problem that is not worth retrying, with onRetry"
            (List.map
                (\kind ->
                    test (kindName kind) <|
                        \_ -> Expect.equal Nothing (Popup.retryFor (problem kind) (Just Retry))
                )
                notWorthRetrying
            )
        , describe "without onRetry there is nothing to retry"
            (List.map
                (\kind ->
                    test (kindName kind) <|
                        \_ -> Expect.equal Nothing (Popup.retryFor (problem kind) Nothing)
                )
                (worthRetrying ++ notWorthRetrying)
            )
        ]



-- POPUP.VIEWFAILURE


failureView : Kind -> Maybe Msg -> Html Msg
failureView kind onRetry =
    Popup.viewFailure
        { locale = Locale.en
        , onRetry = onRetry
        , refocus = Refocus
        , leave = Leave
        , noop = NoOp
        }
        (problem kind)


failureViewTests : Test
failureViewTests =
    describe "Popup.viewFailure"
        [ describe "the button is on screen exactly when retryFor allows it"
            (List.map
                (\kind ->
                    test (kindName kind) <|
                        \_ ->
                            failureView kind (Just Retry)
                                |> Query.fromHtml
                                |> Query.findAll [ Selector.tag "button" ]
                                |> Query.count
                                    (Expect.equal
                                        (if Popup.retryFor (problem kind) (Just Retry) == Nothing then
                                            0

                                         else
                                            1
                                        )
                                    )
                )
                (worthRetrying ++ notWorthRetrying)
            )
        , test "there is no button without onRetry, even for a problem worth retrying" <|
            \_ ->
                failureView Remote.network Nothing
                    |> Query.fromHtml
                    |> Query.findAll [ Selector.tag "button" ]
                    |> Query.count (Expect.equal 0)
        , test "the button of a problem worth retrying sends the retry message" <|
            \_ ->
                failureView Remote.network (Just Retry)
                    |> Query.fromHtml
                    |> Query.find [ Selector.tag "button" ]
                    |> Event.simulate Event.click
                    |> Event.expect Retry
        , test "Tab on the container goes on from the retry button (sends leave)" <|
            \_ ->
                failureView Remote.network (Just Retry)
                    |> pressOnRoot (key "Tab")
                    |> expectPassiveMessage (\msg -> Expect.equal Leave msg)
        , test "without a button Tab is not handled: there is nothing to hold focus here" <|
            \_ ->
                failureView Remote.forbidden (Just Retry)
                    |> pressOnRoot (key "Tab")
                    |> expectLeftToBrowser
        , test "a click on it sends refocus (no button)" <|
            \_ ->
                failureView Remote.forbidden (Just Retry)
                    |> Query.fromHtml
                    |> Event.simulate Event.click
                    |> Event.expect Refocus
        , test "a click on it sends refocus (with a button)" <|
            \_ ->
                failureView Remote.network (Just Retry)
                    |> Query.fromHtml
                    |> Event.simulate Event.click
                    |> Event.expect Refocus
        ]



-- SELECT


openSelect : Select.State String
openSelect =
    Select.init "country"
        |> Select.open
        |> Tuple.first


selectView : Kind -> Bool -> Html Msg
selectView kind withRetry =
    Select.view SelectMsg
        ([ Select.label "Country", Select.remote (failed kind) ]
            ++ (if withRetry then
                    [ Select.onRetry Retry ]

                else
                    []
               )
        )
        openSelect


selectSearch : List Selector
selectSearch =
    [ Selector.id "country-search" ]


{-| What the open select does with a message: is the list still open, and is
the state exactly as it was?
-}
selectAfter : Msg -> { stillOpen : Bool, unchanged : Bool }
selectAfter msg =
    case msg of
        SelectMsg inner ->
            let
                next =
                    Tuple.first (Select.update inner openSelect)
            in
            { stillOpen = Select.isOpen next, unchanged = next == openSelect }

        _ ->
            { stillOpen = True, unchanged = False }


selectCloses : Msg -> Expectation
selectCloses msg =
    expectThat (not (selectAfter msg).stillOpen) "the list is still open"


selectDoesNothing : Msg -> Expectation
selectDoesNothing msg =
    expectThat (selectAfter msg).unchanged "the message changed the select"


selectTests : Test
selectTests =
    describe "Klar.Select, after the options failed to load"
        [ describe "no access (not worth retrying), onRetry given"
            [ test "there is no Try again button" <|
                \_ -> tryAgain 0 (selectView Remote.forbidden True)
            , test "Enter is handled, prevents the browser's action and sends nothing" <|
                \_ ->
                    selectView Remote.forbidden True
                        |> pressOn selectSearch (key "Enter")
                        |> Expect.all
                            [ expectHandledWithoutRetry
                            , expectMessage selectDoesNothing
                            ]
            , test "Tab closes the list and lets focus move on" <|
                \_ ->
                    selectView Remote.forbidden True
                        |> pressOn selectSearch (key "Tab")
                        |> expectPassiveMessage selectCloses
            , test "Shift+Tab closes the list and lets focus move on" <|
                \_ ->
                    selectView Remote.forbidden True
                        |> pressOn selectSearch (keyWith { shift = True } "Tab")
                        |> expectPassiveMessage selectCloses
            ]
        , describe "not found (not worth retrying), onRetry given"
            [ test "Enter does not retry" <|
                \_ ->
                    selectView Remote.notFound True
                        |> pressOn selectSearch (key "Enter")
                        |> expectHandledWithoutRetry
            , test "Tab closes the list" <|
                \_ ->
                    selectView Remote.notFound True
                        |> pressOn selectSearch (key "Tab")
                        |> expectPassiveMessage selectCloses
            ]
        , describe "network trouble (worth retrying), onRetry given"
            [ test "there is a Try again button" <|
                \_ -> tryAgain 1 (selectView Remote.network True)
            , test "Enter retries" <|
                \_ ->
                    selectView Remote.network True
                        |> pressOn selectSearch (key "Enter")
                        |> expectRetry
            , test "Tab is left to the browser: it moves on to the button" <|
                \_ ->
                    selectView Remote.network True
                        |> pressOn selectSearch (key "Tab")
                        |> expectLeftToBrowser
            , test "Shift+Tab closes the list" <|
                \_ ->
                    selectView Remote.network True
                        |> pressOn selectSearch (keyWith { shift = True } "Tab")
                        |> expectPassiveMessage selectCloses
            ]
        , describe "network trouble, but no onRetry (no button)"
            [ test "there is no Try again button" <|
                \_ -> tryAgain 0 (selectView Remote.network False)
            , test "Enter does nothing" <|
                \_ ->
                    selectView Remote.network False
                        |> pressOn selectSearch (key "Enter")
                        |> Expect.all
                            [ expectHandledWithoutRetry
                            , expectMessage selectDoesNothing
                            ]
            , test "Tab closes the list" <|
                \_ ->
                    selectView Remote.network False
                        |> pressOn selectSearch (key "Tab")
                        |> expectPassiveMessage selectCloses
            ]
        , describe "every kind of problem: the keys follow the button"
            (List.map
                (\kind ->
                    test (kindName kind) <|
                        \_ ->
                            let
                                buttonOnScreen =
                                    List.member kind worthRetrying
                            in
                            Expect.all
                                [ \_ -> tryAgain (boolToInt buttonOnScreen) (selectView kind True)
                                , \_ ->
                                    if buttonOnScreen then
                                        selectView kind True |> pressOn selectSearch (key "Tab") |> expectLeftToBrowser

                                    else
                                        selectView kind True |> pressOn selectSearch (key "Tab") |> expectPassiveMessage selectCloses
                                , \_ ->
                                    if buttonOnScreen then
                                        selectView kind True |> pressOn selectSearch (key "Enter") |> expectRetry

                                    else
                                        selectView kind True |> pressOn selectSearch (key "Enter") |> expectHandledWithoutRetry
                                ]
                                ()
                )
                (worthRetrying ++ notWorthRetrying)
            )
        ]


boolToInt : Bool -> Int
boolToInt value =
    if value then
        1

    else
        0



-- MULTI SELECT


openMulti : MultiSelect.State String
openMulti =
    MultiSelect.init "countries"
        |> MultiSelect.open
        |> Tuple.first


multiView : Kind -> Bool -> Html Msg
multiView kind withRetry =
    MultiSelect.view MultiMsg
        ([ MultiSelect.label "Countries", MultiSelect.remote (failed kind) ]
            ++ (if withRetry then
                    [ MultiSelect.onRetry Retry ]

                else
                    []
               )
        )
        openMulti


multiSearch : List Selector
multiSearch =
    [ Selector.id "countries-search" ]


multiAfter : Msg -> { stillOpen : Bool, unchanged : Bool }
multiAfter msg =
    case msg of
        MultiMsg inner ->
            let
                next =
                    Tuple.first (MultiSelect.update inner openMulti)
            in
            { stillOpen = MultiSelect.isOpen next, unchanged = next == openMulti }

        _ ->
            { stillOpen = True, unchanged = False }


multiCloses : Msg -> Expectation
multiCloses msg =
    expectThat (not (multiAfter msg).stillOpen) "the list is still open"


multiDoesNothing : Msg -> Expectation
multiDoesNothing msg =
    expectThat (multiAfter msg).unchanged "the message changed the multi select"


multiSelectTests : Test
multiSelectTests =
    describe "Klar.MultiSelect, after the options failed to load"
        [ describe "no access (not worth retrying), onRetry given"
            [ test "there is no Try again button" <|
                \_ -> tryAgain 0 (multiView Remote.forbidden True)
            , test "Enter is handled, prevents the browser's action and sends nothing" <|
                \_ ->
                    multiView Remote.forbidden True
                        |> pressOn multiSearch (key "Enter")
                        |> Expect.all
                            [ expectHandledWithoutRetry
                            , expectMessage multiDoesNothing
                            ]
            , test "Tab closes the list and lets focus move on" <|
                \_ ->
                    multiView Remote.forbidden True
                        |> pressOn multiSearch (key "Tab")
                        |> expectPassiveMessage multiCloses
            , test "Shift+Tab closes the list and lets focus move on" <|
                \_ ->
                    multiView Remote.forbidden True
                        |> pressOn multiSearch (keyWith { shift = True } "Tab")
                        |> expectPassiveMessage multiCloses
            ]
        , describe "network trouble (worth retrying), onRetry given"
            [ test "there is a Try again button" <|
                \_ -> tryAgain 1 (multiView Remote.network True)
            , test "Enter retries" <|
                \_ ->
                    multiView Remote.network True
                        |> pressOn multiSearch (key "Enter")
                        |> expectRetry
            , test "Tab is left to the browser: it moves on to the button" <|
                \_ ->
                    multiView Remote.network True
                        |> pressOn multiSearch (key "Tab")
                        |> expectLeftToBrowser
            , test "Shift+Tab closes the list" <|
                \_ ->
                    multiView Remote.network True
                        |> pressOn multiSearch (keyWith { shift = True } "Tab")
                        |> expectPassiveMessage multiCloses
            ]
        , describe "network trouble, but no onRetry (no button)"
            [ test "there is no Try again button" <|
                \_ -> tryAgain 0 (multiView Remote.network False)
            , test "Enter does nothing" <|
                \_ ->
                    multiView Remote.network False
                        |> pressOn multiSearch (key "Enter")
                        |> Expect.all
                            [ expectHandledWithoutRetry
                            , expectMessage multiDoesNothing
                            ]
            , test "Tab closes the list" <|
                \_ ->
                    multiView Remote.network False
                        |> pressOn multiSearch (key "Tab")
                        |> expectPassiveMessage multiCloses
            ]
        , describe "every kind of problem: the keys follow the button"
            (List.map
                (\kind ->
                    test (kindName kind) <|
                        \_ ->
                            let
                                buttonOnScreen =
                                    List.member kind worthRetrying
                            in
                            Expect.all
                                [ \_ -> tryAgain (boolToInt buttonOnScreen) (multiView kind True)
                                , \_ ->
                                    if buttonOnScreen then
                                        multiView kind True |> pressOn multiSearch (key "Tab") |> expectLeftToBrowser

                                    else
                                        multiView kind True |> pressOn multiSearch (key "Tab") |> expectPassiveMessage multiCloses
                                , \_ ->
                                    if buttonOnScreen then
                                        multiView kind True |> pressOn multiSearch (key "Enter") |> expectRetry

                                    else
                                        multiView kind True |> pressOn multiSearch (key "Enter") |> expectHandledWithoutRetry
                                ]
                                ()
                )
                (worthRetrying ++ notWorthRetrying)
            )
        ]



-- AUTOCOMPLETE


{-| The autocomplete after the user typed "m": the list is open, so a failed
load shows its error. Typing is the only way to open it, so the state comes
from the input event, as it does in a browser.
-}
openAutocomplete : Result String Autocomplete.State
openAutocomplete =
    let
        start =
            Autocomplete.init "city"
    in
    Autocomplete.view AutoMsg [ Autocomplete.suggestions (failed Remote.network) ] start
        |> Query.fromHtml
        |> Query.find [ Selector.tag "input" ]
        |> Event.simulate (Event.input "m")
        |> Event.toResult
        |> Result.andThen
            (\msg ->
                case msg of
                    AutoMsg inner ->
                        Ok (Tuple.first (Autocomplete.update inner start))

                    _ ->
                        Err "the input sent a message of another component"
            )


autocompleteView : Autocomplete.State -> Kind -> Bool -> Html Msg
autocompleteView state kind withRetry =
    Autocomplete.view AutoMsg
        ([ Autocomplete.label "City", Autocomplete.suggestions (failed kind) ]
            ++ (if withRetry then
                    [ Autocomplete.onRetry Retry ]

                else
                    []
               )
        )
        state


autocompleteInput : List Selector
autocompleteInput =
    [ Selector.id "city" ]


{-| Run a test on the open autocomplete, or fail with the reason it could not
be opened.
-}
withOpenAutocomplete : (Autocomplete.State -> Expectation) -> Expectation
withOpenAutocomplete toExpectation =
    case openAutocomplete of
        Ok state ->
            toExpectation state

        Err why ->
            Expect.fail ("could not open the autocomplete: " ++ why)


{-| The list is closed and the typed text is still there.
-}
autocompleteCloses : Autocomplete.State -> Msg -> Expectation
autocompleteCloses state msg =
    case msg of
        AutoMsg inner ->
            let
                next =
                    Tuple.first (Autocomplete.update inner state)
            in
            expectThat
                (not (Autocomplete.isOpen next) && Autocomplete.text next == Autocomplete.text state)
                "the list should be closed and the text kept"

        _ ->
            Expect.fail "the key sent a message of another component"


autocompleteTests : Test
autocompleteTests =
    describe "Klar.Autocomplete, after the suggestions failed to load"
        [ test "the list is open after typing (the setup of these tests)" <|
            \_ ->
                withOpenAutocomplete
                    (\state ->
                        expectThat (Autocomplete.isOpen state && Autocomplete.text state == "m") "typing should open the list"
                    )
        , describe "no access (not worth retrying), onRetry given"
            [ test "there is no Try again button" <|
                \_ -> withOpenAutocomplete (\state -> tryAgain 0 (autocompleteView state Remote.forbidden True))
            , test "Enter does not retry: it keeps the typed text and closes the list" <|
                \_ ->
                    withOpenAutocomplete
                        (\state ->
                            autocompleteView state Remote.forbidden True
                                |> pressOn autocompleteInput (key "Enter")
                                |> expectPassiveMessage
                                    (\msg ->
                                        Expect.all
                                            [ isNotRetry
                                            , autocompleteCloses state
                                            ]
                                            msg
                                    )
                        )
            , test "Tab closes the list and lets focus move on" <|
                \_ ->
                    withOpenAutocomplete
                        (\state ->
                            autocompleteView state Remote.forbidden True
                                |> pressOn autocompleteInput (key "Tab")
                                |> expectPassiveMessage (autocompleteCloses state)
                        )
            ]
        , describe "network trouble (worth retrying), onRetry given"
            [ test "there is a Try again button" <|
                \_ -> withOpenAutocomplete (\state -> tryAgain 1 (autocompleteView state Remote.network True))
            , test "Enter retries" <|
                \_ ->
                    withOpenAutocomplete
                        (\state ->
                            autocompleteView state Remote.network True
                                |> pressOn autocompleteInput (key "Enter")
                                |> expectRetry
                        )
            , test "Tab closes the list first, so focus does not land in the button" <|
                \_ ->
                    withOpenAutocomplete
                        (\state ->
                            autocompleteView state Remote.network True
                                |> pressOn autocompleteInput (key "Tab")
                                |> Expect.all
                                    [ Event.expectPreventDefault
                                    , expectMessage (autocompleteCloses state)
                                    ]
                        )
            ]
        , describe "network trouble, but no onRetry (no button)"
            [ test "there is no Try again button" <|
                \_ -> withOpenAutocomplete (\state -> tryAgain 0 (autocompleteView state Remote.network False))
            , test "Enter keeps the typed text" <|
                \_ ->
                    withOpenAutocomplete
                        (\state ->
                            autocompleteView state Remote.network False
                                |> pressOn autocompleteInput (key "Enter")
                                |> expectPassiveMessage (\msg -> Expect.all [ isNotRetry, autocompleteCloses state ] msg)
                        )
            , test "Tab closes the list and lets focus move on" <|
                \_ ->
                    withOpenAutocomplete
                        (\state ->
                            autocompleteView state Remote.network False
                                |> pressOn autocompleteInput (key "Tab")
                                |> expectPassiveMessage (autocompleteCloses state)
                        )
            ]
        , describe "every kind of problem: Enter follows the button"
            (List.map
                (\kind ->
                    test (kindName kind) <|
                        \_ ->
                            withOpenAutocomplete
                                (\state ->
                                    if List.member kind worthRetrying then
                                        autocompleteView state kind True
                                            |> pressOn autocompleteInput (key "Enter")
                                            |> expectRetry

                                    else
                                        autocompleteView state kind True
                                            |> pressOn autocompleteInput (key "Enter")
                                            |> expectPassiveMessage isNotRetry
                                )
                )
                (worthRetrying ++ notWorthRetrying)
            )
        ]



-- THE FIELD AROUND A TYPING CONTROL


{-| The autocomplete is inside its field wrapper, as the only control in it.
When an error appears later, the input must stay exactly where it is in the
tree: an element that moves is rebuilt by the browser and loses focus.
-}
inItsWrapper : List (Autocomplete.Attribute Msg) -> Expectation
inItsWrapper attributes =
    Autocomplete.view AutoMsg attributes (Autocomplete.init "city")
        |> Query.fromHtml
        |> Expect.all
            [ Query.has [ Selector.class "klar-field" ]
            , Query.children [ Selector.class "klar-autocomplete" ] >> Query.count (Expect.equal 1)
            , Query.find [ Selector.tag "input" ] >> Query.has [ Selector.id "city" ]
            ]


stableFieldTests : Test
stableFieldTests =
    describe "A field that is typed into keeps its wrapper"
        [ describe "Klar.Autocomplete is always inside the field wrapper"
            [ test "without label, hint or error (where the error used to move the input)" <|
                \_ -> inItsWrapper []
            , test "with an error" <|
                \_ -> inItsWrapper [ Autocomplete.error "Choose a city we deliver to" ]
            , test "with a label" <|
                \_ -> inItsWrapper [ Autocomplete.label "City" ]
            , test "with a hint" <|
                \_ -> inItsWrapper [ Autocomplete.hint "Where the order ships to" ]
            , test "with an error that is Nothing" <|
                \_ -> inItsWrapper [ Autocomplete.errorMaybe Nothing ]
            ]
        , test "the error appears under the input without moving it" <|
            \_ ->
                Autocomplete.view AutoMsg [ Autocomplete.errorMaybe (Just "Too short") ] (Autocomplete.init "city")
                    |> Query.fromHtml
                    |> Expect.all
                        [ Query.has [ Selector.class "klar-field--invalid" ]
                        , Query.find [ Selector.class "klar-field__error" ] >> Query.has [ Selector.text "Too short" ]
                        , Query.children [ Selector.class "klar-autocomplete" ] >> Query.count (Expect.equal 1)
                        ]
        , describe "Klar.Select and Klar.MultiSelect have a button trigger, no text input outside the popup"
            [ test "a closed select is a button" <|
                \_ ->
                    Select.view SelectMsg [ Select.options orders ] (Select.init "country")
                        |> Query.fromHtml
                        |> Expect.all
                            [ Query.find [ Selector.id "country" ] >> Query.has [ Selector.tag "button" ]
                            , Query.findAll [ Selector.tag "input" ] >> Query.count (Expect.equal 0)
                            ]
            , test "a closed multi select is a button" <|
                \_ ->
                    MultiSelect.view MultiMsg [ MultiSelect.options orders ] (MultiSelect.init "countries")
                        |> Query.fromHtml
                        |> Expect.all
                            [ Query.find [ Selector.id "countries" ] >> Query.has [ Selector.tag "button" ]
                            , Query.findAll [ Selector.tag "input" ] >> Query.count (Expect.equal 0)
                            ]
            ]
        ]
