module InputsFixTest exposing (suite)

{-| Regression tests for five fixes to the input components.

1.  `NumberInput.isValid` knows the limits at once (typing, `setValue`, stepping,
    leaving), and a number is never clamped.
2.  `FileDrop`: `maxFiles 1` is a single-file field, and removing a file does not
    check again (or refuse) the files that were accepted.
3.  `PasswordInput.strength` reads Unicode and knows the common passwords of both
    languages.
4.  The inputs always sit in the field wrapper, so they stay put (and keep the
    keyboard focus) when an error appears.
5.  `InlineEdit.disabled` also stops an editor that is open, and the clear button
    of `TextInput` sends its message once.

A test draws the component, finds a control the way a user would, simulates the
event, takes the message that the control sends and gives it to `update`.

-}

import Expect exposing (Expectation)
import Fuzz
import Html exposing (Html)
import Html.Attributes as Attr
import Json.Encode as Encode exposing (Value)
import Klar
import Klar.FileDrop as FileDrop
import Klar.Format as Format
import Klar.InlineEdit as InlineEdit
import Klar.Locale as Locale
import Klar.NumberInput as NumberInput
import Klar.PasswordInput as PasswordInput
import Klar.Remote as Remote
import Klar.SearchInput as SearchInput
import Klar.TagInput as TagInput
import Klar.TextArea as TextArea
import Klar.TextInput as TextInput
import Support.Css as Css
import Test exposing (Test, describe, test)
import Test.Html.Event as Event
import Test.Html.Query as Query
import Test.Html.Selector as Selector exposing (Selector)


type Msg
    = Number NumberInput.Msg
    | Files FileDrop.Msg
    | Edit InlineEdit.Msg
    | Password PasswordInput.Msg
    | Search SearchInput.Msg
    | Tags TagInput.Msg
    | Typed String
    | Ignored


suite : Test
suite =
    describe "fixes to the input components"
        [ numberValidityTests
        , numberLimitsTests
        , numberFormatTests
        , singleFileTests
        , removalTests
        , strengthLetterTests
        , strengthLengthAndPatternTests
        , commonPasswordTests
        , wrapperTests
        , inlineEditTests
        , clearButtonTests
        ]



-- WHAT THE USER POINTS AT


labelled : String -> List Selector
labelled text =
    [ Selector.attribute (Attr.attribute "aria-label" text) ]


keyDown : String -> ( String, Value )
keyDown key =
    Event.custom "keydown"
        (Encode.object
            [ ( "key", Encode.string key )
            , ( "ctrlKey", Encode.bool False )
            , ( "metaKey", Encode.bool False )
            , ( "shiftKey", Encode.bool False )
            , ( "altKey", Encode.bool False )
            ]
        )


{-| A click with its `detail`: the number of presses of the mouse button that
came before it (0 from a key or from assistive technology).
-}
clickWithDetail : Int -> ( String, Value )
clickWithDetail detail =
    Event.custom "click" (Encode.object [ ( "detail", Encode.int detail ) ])



-- NUMBER INPUT


type alias NumberStep =
    NumberInput.State -> Result String NumberInput.State


discount : List (NumberInput.Attribute Msg)
discount =
    [ NumberInput.label "Discount", NumberInput.min 0, NumberInput.max 50, NumberInput.suffixText "%" ]


fresh : NumberInput.State
fresh =
    NumberInput.init "discount"


numberEvent : List (NumberInput.Attribute Msg) -> List Selector -> ( String, Value ) -> NumberStep
numberEvent attributes selectors event state =
    NumberInput.view Number attributes state
        |> Query.fromHtml
        |> Query.find selectors
        |> Event.simulate event
        |> Event.toResult
        |> Result.andThen
            (\msg ->
                case msg of
                    Number inner ->
                        Ok (Tuple.first (NumberInput.update inner state))

                    _ ->
                        Err "that was not a message of the number field"
            )


inputOf : List Selector
inputOf =
    [ Selector.tag "input" ]


typeIn : List (NumberInput.Attribute Msg) -> String -> NumberStep
typeIn attributes text =
    numberEvent attributes inputOf (Event.input text)


focusIn : List (NumberInput.Attribute Msg) -> NumberStep
focusIn attributes =
    numberEvent attributes inputOf Event.focus


leave : List (NumberInput.Attribute Msg) -> NumberStep
leave attributes =
    numberEvent attributes inputOf Event.blur


pressKey : List (NumberInput.Attribute Msg) -> String -> NumberStep
pressKey attributes key =
    numberEvent attributes inputOf (keyDown key)


stepUp : List (NumberInput.Attribute Msg) -> NumberStep
stepUp attributes =
    numberEvent attributes (labelled "Increase value") Event.click


stepDown : List (NumberInput.Attribute Msg) -> NumberStep
stepDown attributes =
    numberEvent attributes (labelled "Decrease value") Event.click


set : Float -> NumberStep
set number state =
    Ok (NumberInput.setValue (Just number) state)


after : List NumberStep -> NumberInput.State -> Result String NumberInput.State
after steps state =
    List.foldl (\step result -> Result.andThen step result) (Ok state) steps


expectValid : Bool -> Result String NumberInput.State -> Expectation
expectValid expected result =
    case result of
        Ok state ->
            Expect.equal expected (NumberInput.isValid state)

        Err problem ->
            Expect.fail problem


expectNumber : Maybe Float -> Result String NumberInput.State -> Expectation
expectNumber expected result =
    case result of
        Ok state ->
            Expect.equal expected (NumberInput.value state)

        Err problem ->
            Expect.fail problem


expectShown : List Selector -> (Query.Single Msg -> Expectation) -> List (NumberInput.Attribute Msg) -> Result String NumberInput.State -> Expectation
expectShown selectors check attributes result =
    case result of
        Ok state ->
            NumberInput.view Number attributes state
                |> Query.fromHtml
                |> Query.find selectors
                |> check

        Err problem ->
            Expect.fail problem


numberValidityTests : Test
numberValidityTests =
    describe "NumberInput.isValid"
        [ describe "while the user types, before the field is left"
            [ test "a number above max is invalid from the first keystroke" <|
                \_ -> after [ typeIn discount "55" ] fresh |> expectValid False
            , test "a number below min is invalid" <|
                \_ -> after [ typeIn discount "-5" ] fresh |> expectValid False
            , test "a number inside the limits is valid" <|
                \_ -> after [ typeIn discount "20" ] fresh |> expectValid True
            , test "the limits themselves are valid" <|
                \_ ->
                    Expect.equal [ Ok True, Ok True ]
                        [ after [ typeIn discount "0" ] fresh |> Result.map NumberInput.isValid
                        , after [ typeIn discount "50" ] fresh |> Result.map NumberInput.isValid
                        ]
            , test "a number just above max is invalid" <|
                \_ -> after [ typeIn discount "50,01" ] fresh |> expectValid False
            , test "fixing the number makes it valid again" <|
                \_ -> after [ typeIn discount "55", typeIn discount "45" ] fresh |> expectValid True
            , test "text that is not a number is invalid" <|
                \_ -> after [ typeIn discount "abc" ] fresh |> expectValid False
            , test "an empty field is valid" <|
                \_ -> after [ typeIn discount "5", typeIn discount "" ] fresh |> expectValid True
            , test "with no limits every number is valid" <|
                \_ -> after [ typeIn [] "1 000 000" ] fresh |> expectValid True
            , test "with only a max, a negative number is valid" <|
                \_ -> after [ typeIn [ NumberInput.max 10 ] "-100" ] fresh |> expectValid True
            , test "with only a min, a large number is valid" <|
                \_ -> after [ typeIn [ NumberInput.min 10 ] "1000" ] fresh |> expectValid True
            , test "a number above max typed is kept as typed, not clamped" <|
                \_ -> after [ typeIn discount "55" ] fresh |> expectNumber (Just 55)
            , test "the text of the input is what was typed" <|
                \_ ->
                    after [ typeIn discount "55" ] fresh
                        |> expectShown inputOf (Query.has [ Selector.attribute (Attr.value "55") ]) discount
            , test "the field's own message waits while typing, isValid does not" <|
                \_ ->
                    let
                        typing =
                            after [ focusIn discount, typeIn discount "55" ] fresh
                    in
                    Expect.all
                        [ expectValid False
                        , expectShown [ Selector.class "klar-field" ] (Query.hasNot [ Selector.class "klar-field__error" ]) discount
                        ]
                        typing
            ]
        , describe "after the user left the field"
            [ test "a number above max stays as typed and stays invalid" <|
                \_ ->
                    Expect.all [ expectNumber (Just 55), expectValid False ]
                        (after [ focusIn discount, typeIn discount "55", leave discount ] fresh)
            , test "the text of the input is still 55 after leaving" <|
                \_ ->
                    after [ focusIn discount, typeIn discount "55", leave discount ] fresh
                        |> expectShown inputOf (Query.has [ Selector.attribute (Attr.value "55") ]) discount
            , test "the field says so, with the limits" <|
                \_ ->
                    after [ focusIn discount, typeIn discount "55", leave discount ] fresh
                        |> expectShown [ Selector.class "klar-field__error" ] (Query.has [ Selector.text "Must be between 0 and 50" ]) discount
            , test "a number below min stays invalid after leaving" <|
                \_ -> after [ typeIn discount "-5", leave discount ] fresh |> expectValid False
            , test "a number inside the limits is valid after leaving" <|
                \_ -> after [ typeIn discount "20", leave discount ] fresh |> expectValid True
            , test "Enter keeps the number and it stays invalid" <|
                \_ ->
                    Expect.all [ expectNumber (Just 55), expectValid False ]
                        (after [ typeIn discount "55", pressKey discount "Enter" ] fresh)
            , test "leaving an empty field is valid" <|
                \_ -> after [ typeIn discount "", leave discount ] fresh |> expectValid True
            ]
        , describe "after setValue"
            [ test "a number above max is invalid once the field has seen its limits" <|
                \_ -> after [ focusIn discount, set 55 ] fresh |> expectValid False
            , test "a number below min is invalid" <|
                \_ -> after [ focusIn discount, set -1 ] fresh |> expectValid False
            , test "a number inside the limits is valid" <|
                \_ -> after [ focusIn discount, set 20 ] fresh |> expectValid True
            , test "setValue never moves the number into the range" <|
                \_ -> after [ focusIn discount, set 55 ] fresh |> expectNumber (Just 55)
            , test "the input shows the number as it is" <|
                \_ ->
                    after [ focusIn discount, set 55 ] fresh
                        |> expectShown inputOf (Query.has [ Selector.attribute (Attr.value "55") ]) discount
            , test "the field says so" <|
                \_ ->
                    after [ focusIn discount, set 55 ] fresh
                        |> expectShown [ Selector.class "klar-field__error" ] (Query.has [ Selector.text "Must be between 0 and 50" ]) discount
            , test "setValue Nothing is valid" <|
                \_ -> after [ focusIn discount, set 55, \s -> Ok (NumberInput.setValue Nothing s) ] fresh |> expectValid True
            , test "a typed number replaced by setValue is judged again" <|
                \_ -> after [ typeIn discount "20", set 55 ] fresh |> expectValid False
            , test "reset keeps the limits the field has seen" <|
                \_ -> after [ focusIn discount, \s -> Ok (NumberInput.clear s), set 55 ] fresh |> expectValid False
            ]
        , describe "while stepping"
            [ test "stepping up from 49 reaches 50, which is valid" <|
                \_ ->
                    Expect.all [ expectNumber (Just 50), expectValid True ]
                        (after [ set 49, stepUp discount ] fresh)
            , test "stepping up at max stays at max" <|
                \_ ->
                    Expect.all [ expectNumber (Just 50), expectValid True ]
                        (after [ set 50, stepUp discount ] fresh)
            , test "stepping down at min stays at min" <|
                \_ ->
                    Expect.all [ expectNumber (Just 0), expectValid True ]
                        (after [ set 0, stepDown discount ] fresh)
            , test "stepping is the one action that moves a number above max into the range" <|
                \_ ->
                    Expect.all [ expectNumber (Just 50), expectValid True ]
                        (after [ typeIn discount "55", stepDown discount ] fresh)
            , test "stepping up from a number above max lands on max" <|
                \_ ->
                    Expect.all [ expectNumber (Just 50), expectValid True ]
                        (after [ typeIn discount "55", stepUp discount ] fresh)
            , test "stepping up from a number below min lands on min" <|
                \_ ->
                    Expect.all [ expectNumber (Just 0), expectValid True ]
                        (after [ typeIn discount "-5", stepUp discount ] fresh)
            , test "the arrow keys step like the buttons" <|
                \_ ->
                    Expect.all [ expectNumber (Just 50), expectValid True ]
                        (after [ typeIn discount "55", pressKey discount "ArrowDown" ] fresh)
            , test "page up steps ten at a time and stops at max" <|
                \_ ->
                    Expect.all [ expectNumber (Just 50), expectValid True ]
                        (after [ set 45, pressKey discount "PageUp" ] fresh)
            , test "stepping shows the limits to the field for later" <|
                \_ -> after [ set 20, stepUp discount, set 60 ] fresh |> expectValid False
            , test "a step inside the limits changes the number by the step" <|
                \_ -> after [ set 20, stepUp discount ] fresh |> expectNumber (Just 21)
            ]
        ]


numberLimitsTests : Test
numberLimitsTests =
    describe "NumberInput.setLimits"
        [ test "a value loaded before anyone touched the field is checked against the limits" <|
            \_ ->
                fresh
                    |> NumberInput.setLimits discount
                    |> NumberInput.setValue (Just 55)
                    |> NumberInput.isValid
                    |> Expect.equal False
        , test "the order does not matter" <|
            \_ ->
                fresh
                    |> NumberInput.setValue (Just 55)
                    |> NumberInput.setLimits discount
                    |> NumberInput.isValid
                    |> Expect.equal False
        , test "a number inside the limits is valid" <|
            \_ ->
                fresh
                    |> NumberInput.setLimits discount
                    |> NumberInput.setValue (Just 20)
                    |> NumberInput.isValid
                    |> Expect.equal True
        , test "a number below min is invalid" <|
            \_ ->
                fresh
                    |> NumberInput.setLimits discount
                    |> NumberInput.setValue (Just -3)
                    |> NumberInput.isValid
                    |> Expect.equal False
        , test "an empty field is valid" <|
            \_ ->
                fresh
                    |> NumberInput.setLimits discount
                    |> NumberInput.isValid
                    |> Expect.equal True
        , test "the number is not changed" <|
            \_ ->
                fresh
                    |> NumberInput.setValue (Just 55)
                    |> NumberInput.setLimits discount
                    |> NumberInput.value
                    |> Expect.equal (Just 55)
        , test "the field is not touched by it" <|
            \_ ->
                fresh
                    |> NumberInput.setLimits discount
                    |> NumberInput.isTouched
                    |> Expect.equal False
        , test "only min and max are used, the other attributes are ignored" <|
            \_ ->
                fresh
                    |> NumberInput.setLimits [ NumberInput.label "Quantity", NumberInput.max 10, NumberInput.decimals 2, NumberInput.suffixText "pcs" ]
                    |> NumberInput.setValue (Just 11)
                    |> NumberInput.isValid
                    |> Expect.equal False
        , test "with only a max, a negative number is valid" <|
            \_ ->
                fresh
                    |> NumberInput.setLimits [ NumberInput.max 10 ]
                    |> NumberInput.setValue (Just -11)
                    |> NumberInput.isValid
                    |> Expect.equal True
        , test "later attributes win, as everywhere" <|
            \_ ->
                fresh
                    |> NumberInput.setLimits [ NumberInput.max 10, NumberInput.max 100 ]
                    |> NumberInput.setValue (Just 50)
                    |> NumberInput.isValid
                    |> Expect.equal True
        , test "an empty list takes the limits away" <|
            \_ ->
                fresh
                    |> NumberInput.setLimits discount
                    |> NumberInput.setLimits []
                    |> NumberInput.setValue (Just 55)
                    |> NumberInput.isValid
                    |> Expect.equal True
        , test "new limits replace the old ones, for limits that change on the screen" <|
            \_ ->
                fresh
                    |> NumberInput.setLimits discount
                    |> NumberInput.setValue (Just 40)
                    |> NumberInput.setLimits [ NumberInput.max 30 ]
                    |> NumberInput.isValid
                    |> Expect.equal False
        , test "the view tells the field its limits again when the user focuses it" <|
            \_ ->
                after [ \s -> Ok (NumberInput.setLimits [ NumberInput.max 100 ] s), set 55, focusIn discount ] fresh
                    |> expectValid False
        ]



-- NUMBER FORMATS


english : List (NumberInput.Attribute Msg)
english =
    [ NumberInput.locale Locale.en, NumberInput.grouped ]


norwegian : List (NumberInput.Attribute Msg)
norwegian =
    [ NumberInput.locale Locale.nb, NumberInput.grouped ]


nbsp : String
nbsp =
    "\u{00A0}"


minus : String
minus =
    "−"


languageName : Locale.Locale -> String
languageName lang =
    Locale.pick lang { nb = "Norwegian", en = "English" }


{-| What the input of a field with this number shows.
-}
shows : List (NumberInput.Attribute Msg) -> Float -> String -> Test
shows attributes number text =
    test (String.fromFloat number ++ " is shown as " ++ text) <|
        \_ ->
            after [ set number ] fresh
                |> expectShown inputOf (Query.has [ Selector.attribute (Attr.value text) ]) attributes


{-| The error that a field with these limits shows for this number.
-}
saysAbout : List (NumberInput.Attribute Msg) -> Float -> String -> Test
saysAbout attributes number message =
    test (String.fromFloat number ++ " gives \"" ++ message ++ "\"") <|
        \_ ->
            after [ set number ] fresh
                |> expectShown [ Selector.class "klar-field__error" ] (Query.has [ Selector.text message ]) attributes


{-| What typing this text gives, in the language of the field, both for the
field and for `parseIn`.
-}
reads : Locale.Locale -> String -> Float -> Test
reads lang text expected =
    test (languageName lang ++ ": " ++ text ++ " is " ++ String.fromFloat expected) <|
        \_ ->
            Expect.all
                [ \_ -> Expect.equal (Just expected) (NumberInput.parseIn lang text)
                , \_ -> after [ typeIn [ NumberInput.locale lang ] text ] fresh |> expectNumber (Just expected)
                , \_ -> after [ typeIn [ NumberInput.locale lang ] text, leave [ NumberInput.locale lang ] ] fresh |> expectNumber (Just expected)
                ]
                ()


numberFormatTests : Test
numberFormatTests =
    let
        range =
            [ NumberInput.min 0, NumberInput.max 100000 ]

        decimals2 =
            [ NumberInput.decimals 2 ]
    in
    describe "NumberInput writes and reads numbers in the language of the field"
        [ describe "what the field shows, with grouped"
            [ shows english 100000 "100,000"
            , shows norwegian 100000 ("100" ++ nbsp ++ "000")
            , shows english 1234567 "1,234,567"
            , shows norwegian 1234567 ("1" ++ nbsp ++ "234" ++ nbsp ++ "567")
            , shows english 999 "999"
            , shows english 1000 "1,000"
            , shows english 1234.5 "1,234.5"
            , shows norwegian 1234.5 ("1" ++ nbsp ++ "234,5")
            , shows (english ++ decimals2) 1234.5 "1,234.50"
            , shows (norwegian ++ decimals2) 1234.5 ("1" ++ nbsp ++ "234,50")
            , shows (english ++ decimals2) 1234567.891 "1,234,567.89"
            , shows (norwegian ++ decimals2) 1234567.891 ("1" ++ nbsp ++ "234" ++ nbsp ++ "567,89")
            , shows (english ++ [ NumberInput.decimals 0 ]) 2.5 "3"
            , shows english 0 "0"
            , shows english 12 "12"
            , test "English is the default language of the field" <|
                \_ -> after [ set 100000 ] fresh |> expectShown inputOf (Query.has [ Selector.attribute (Attr.value "100000") ]) []
            , test "grouped with the default language writes a comma" <|
                \_ -> after [ set 100000 ] fresh |> expectShown inputOf (Query.has [ Selector.attribute (Attr.value "100,000") ]) [ NumberInput.grouped ]
            ]
        , describe "without grouped there are no thousands separators"
            [ describe "English"
                [ shows [ NumberInput.locale Locale.en ] 100000 "100000"
                , shows [ NumberInput.locale Locale.en ] 1234.5 "1234.5"
                , shows [ NumberInput.locale Locale.en, NumberInput.decimals 2 ] 1234.5 "1234.50"
                ]
            , describe "Norwegian"
                [ shows [ NumberInput.locale Locale.nb ] 100000 "100000"
                , shows [ NumberInput.locale Locale.nb ] 1234.5 "1234,5"
                , shows [ NumberInput.locale Locale.nb, NumberInput.decimals 2 ] 1234.5 "1234,50"
                ]
            ]
        , describe "a negative number begins with the minus sign of the keyboard"
            [ shows english -1234.5 "-1,234.5"
            , shows norwegian -1234.5 ("-1" ++ nbsp ++ "234,5")
            , shows [ NumberInput.locale Locale.en ] -5 "-5"
            , shows (english ++ decimals2) -0.001 "0.00"
            ]
        , describe "the field writes what Klar.Format writes"
            [ Test.fuzz2 (Fuzz.floatRange -1000000000 1000000000) (Fuzz.intRange 0 3) "in English, grouped" <|
                \number places ->
                    after [ set number ] fresh
                        |> expectShown inputOf
                            (Query.has [ Selector.attribute (Attr.value (String.replace minus "-" (Format.decimal Locale.en places number))) ])
                            (english ++ [ NumberInput.decimals places ])
            , Test.fuzz2 (Fuzz.floatRange -1000000000 1000000000) (Fuzz.intRange 0 3) "in Norwegian, grouped" <|
                \number places ->
                    after [ set number ] fresh
                        |> expectShown inputOf
                            (Query.has [ Selector.attribute (Attr.value (String.replace minus "-" (Format.decimal Locale.nb places number))) ])
                            (norwegian ++ [ NumberInput.decimals places ])
            ]
        , describe "the range error writes the limits in the same way"
            [ saysAbout (english ++ range) 150000 "Must be between 0 and 100,000"
            , saysAbout (norwegian ++ range) 150000 ("Må være mellom 0 og 100" ++ nbsp ++ "000")
            , saysAbout (english ++ [ NumberInput.max 100000 ]) 150000 "Must be at most 100,000"
            , saysAbout (english ++ [ NumberInput.min 1000 ]) 5 "Must be at least 1,000"
            , saysAbout (norwegian ++ [ NumberInput.min 1000 ]) 5 ("Må være minst 1" ++ nbsp ++ "000")
            , saysAbout (english ++ [ NumberInput.max 100000, NumberInput.suffixText "pcs" ]) 150000 ("Must be at most 100,000" ++ nbsp ++ "pcs")
            , saysAbout (english ++ [ NumberInput.min 0.5, NumberInput.max 1234.5 ]) 5000 "Must be between 0.5 and 1,234.5"
            , saysAbout (norwegian ++ [ NumberInput.min 0.5, NumberInput.max 1234.5 ]) 5000 ("Må være mellom 0,5 og 1" ++ nbsp ++ "234,5")
            , saysAbout [ NumberInput.locale Locale.en, NumberInput.max 100000 ] 150000 "Must be at most 100000"
            , saysAbout [ NumberInput.locale Locale.nb, NumberInput.max 100000 ] 150000 "Må være høyst 100000"
            , saysAbout (english ++ [ NumberInput.min -50, NumberInput.max 50 ]) 60 ("Must be between " ++ minus ++ "50 and 50")
            ]
        , describe "what is typed is read in the language of the field"
            [ describe "English"
                [ reads Locale.en "1,234.5" 1234.5
                , reads Locale.en "1234.5" 1234.5
                , reads Locale.en "1,234" 1234
                , reads Locale.en "100,000" 100000
                , reads Locale.en "12,345,678" 12345678
                , reads Locale.en "1,234,567.89" 1234567.89
                , reads Locale.en "1.234" 1.234
                , reads Locale.en "12.5" 12.5
                , reads Locale.en "1 234.5" 1234.5
                , reads Locale.en "1,5" 1.5
                , reads Locale.en "12,34" 12.34
                , reads Locale.en "1,2345" 1.2345
                , reads Locale.en "0,500" 0.5
                , reads Locale.en ",5" 0.5
                , reads Locale.en "-1,234.5" -1234.5
                , reads Locale.en "+1,234" 1234
                , reads Locale.en "1.234,56" 1234.56
                ]
            , describe "Norwegian"
                [ reads Locale.nb "1 234,5" 1234.5
                , reads Locale.nb ("1" ++ nbsp ++ "234,5") 1234.5
                , reads Locale.nb "1234,5" 1234.5
                , reads Locale.nb "1 234" 1234
                , reads Locale.nb "1 234 567,89" 1234567.89
                , reads Locale.nb "1,234" 1.234
                , reads Locale.nb "12,5" 12.5
                , reads Locale.nb "1.234" 1234
                , reads Locale.nb "10.000" 10000
                , reads Locale.nb "1.5" 1.5
                , reads Locale.nb "12.25" 12.25
                , reads Locale.nb "0.500" 0.5
                , reads Locale.nb "1'234,5" 1234.5
                , reads Locale.nb "-1 234,5" -1234.5
                , reads Locale.nb "1,234.56" 1234.56
                , reads Locale.nb "1.234.567" 1234567
                ]
            , test "the same text means different numbers in the two languages" <|
                \_ -> Expect.equal ( Just 1234, Just 1.234 ) ( NumberInput.parseIn Locale.en "1,234", NumberInput.parseIn Locale.nb "1,234" )
            , test "text that is not a number is not a number in either language" <|
                \_ ->
                    Expect.equal [ Nothing, Nothing, Nothing, Nothing ]
                        [ NumberInput.parseIn Locale.en "twelve", NumberInput.parseIn Locale.nb "twelve", NumberInput.parseIn Locale.en "1,2,3", NumberInput.parseIn Locale.nb "1,2,3" ]
            ]
        , describe "NumberInput.parse does not depend on a language"
            [ test "a lone comma is the decimal comma" <|
                \_ -> Expect.equal [ Just 1.234, Just 1.5, Just 1.234 ] [ NumberInput.parse "1,234", NumberInput.parse "1,5", NumberInput.parse "1.234" ]
            , test "mixed separators and spaces are read as before" <|
                \_ -> Expect.equal [ Just 1234.56, Just 1234.56, Just 1234.5, Just 12.5 ] [ NumberInput.parse "1.234,56", NumberInput.parse "1,234.56", NumberInput.parse "1 234,5", NumberInput.parse "12,5" ]
            ]
        , describe "what Klar.Format writes, the field reads back"
            [ Test.fuzz2 (Fuzz.floatRange -1000000000 1000000000) (Fuzz.intRange 0 3) "a decimal number in English" <|
                \number places ->
                    NumberInput.parseIn Locale.en (Format.decimal Locale.en places number)
                        |> expectNear (Format.decimal Locale.en places number) number places
            , Test.fuzz2 (Fuzz.floatRange -1000000000 1000000000) (Fuzz.intRange 0 3) "a decimal number in Norwegian" <|
                \number places ->
                    NumberInput.parseIn Locale.nb (Format.decimal Locale.nb places number)
                        |> expectNear (Format.decimal Locale.nb places number) number places
            , Test.fuzz (Fuzz.intRange -2000000000 2000000000) "a whole number in English" <|
                \n -> Expect.equal (Just (toFloat n)) (NumberInput.parseIn Locale.en (Format.int Locale.en n))
            , Test.fuzz (Fuzz.intRange -2000000000 2000000000) "a whole number in Norwegian" <|
                \n -> Expect.equal (Just (toFloat n)) (NumberInput.parseIn Locale.nb (Format.int Locale.nb n))
            ]
        , describe "the text of the field is read back as the same number"
            [ test "the number is shown grouped after the field is left, and typing it again gives the same number" <|
                \_ ->
                    Expect.all
                        [ expectShown inputOf (Query.has [ Selector.attribute (Attr.value "1,234,567.5") ]) english
                        , expectNumber (Just 1234567.5)
                        ]
                        (after [ typeIn english "1234567.5", leave english ] fresh)
            , test "the shown text read again in English" <|
                \_ -> after [ typeIn english "1,234,567.5", leave english, typeIn english "1,234,567.5" ] fresh |> expectNumber (Just 1234567.5)
            , test "the Norwegian text is shown grouped after the field is left" <|
                \_ ->
                    after [ typeIn norwegian "1234567,5", leave norwegian ] fresh
                        |> expectShown inputOf (Query.has [ Selector.attribute (Attr.value ("1" ++ nbsp ++ "234" ++ nbsp ++ "567,5")) ]) norwegian
            , test "a number typed with a comma in English is shown the English way" <|
                \_ ->
                    after [ typeIn english "1,234", leave english ] fresh
                        |> expectShown inputOf (Query.has [ Selector.attribute (Attr.value "1,234") ]) english
            ]
        , describe "stepping reads and writes in the language of the field"
            [ test "English: a grouped number is stepped as the number it is" <|
                \_ ->
                    Expect.all
                        [ expectNumber (Just 1235)
                        , expectShown inputOf (Query.has [ Selector.attribute (Attr.value "1,235") ]) english
                        ]
                        (after [ typeIn english "1,234", stepUp english ] fresh)
            , test "Norwegian: a grouped number is stepped as the number it is, to the next whole step" <|
                \_ ->
                    Expect.all
                        [ expectNumber (Just 1235)
                        , expectShown inputOf (Query.has [ Selector.attribute (Attr.value ("1" ++ nbsp ++ "235,0")) ]) (norwegian ++ [ NumberInput.decimals 1 ])
                        ]
                        (after
                            [ typeIn (norwegian ++ [ NumberInput.decimals 1 ]) "1 234,5"
                            , numberEvent (norwegian ++ [ NumberInput.decimals 1 ]) (labelled "Øk verdien") Event.click
                            ]
                            fresh
                        )
            ]
        , describe "the limits are compared with the number the language means"
            [ test "100,000 is the largest number in English" <|
                \_ -> after [ typeIn (english ++ range) "100,000" ] fresh |> Expect.all [ expectNumber (Just 100000), expectValid True ]
            , test "100,001 is too large in English" <|
                \_ -> after [ typeIn (english ++ range) "100,001" ] fresh |> expectValid False
            , test "the same text is a small number in Norwegian" <|
                \_ -> after [ typeIn (norwegian ++ range) "100,001" ] fresh |> Expect.all [ expectNumber (Just 100.001), expectValid True ]
            ]
        ]


{-| The number that `parseIn` gave, within the rounding of the decimals.
-}
expectNear : String -> Float -> Int -> Maybe Float -> Expectation
expectNear text number places parsed =
    case parsed of
        Nothing ->
            Expect.fail ("\"" ++ text ++ "\" was not read as a number")

        Just value ->
            Expect.atMost (0.5 * 10 ^ negate (toFloat places) + 1.0e-6) (abs (value - number))



-- FILE DROP


type alias FilesStep =
    FileDrop.State -> Result String FileDrop.State


pdf : String -> Int -> FileDrop.FileInfo
pdf name size =
    { name = name, size = size, mime = "application/pdf" }


png : String -> Int -> FileDrop.FileInfo
png name size =
    { name = name, size = size, mime = "image/png" }


exe : String -> Int -> FileDrop.FileInfo
exe name size =
    { name = name, size = size, mime = "application/x-msdownload" }


fileJson : FileDrop.FileInfo -> Value
fileJson file =
    Encode.object [ ( "name", Encode.string file.name ), ( "size", Encode.int file.size ), ( "type", Encode.string file.mime ) ]


emptyDrop : FileDrop.State
emptyDrop =
    FileDrop.init "attachments"


fileInput : List Selector
fileInput =
    [ Selector.tag "input", Selector.attribute (Attr.type_ "file") ]


filesEvent : List (FileDrop.Attribute Msg) -> List Selector -> ( String, Value ) -> FilesStep
filesEvent attributes selectors event state =
    FileDrop.view Files attributes state
        |> Query.fromHtml
        |> Query.find selectors
        |> Event.simulate event
        |> Event.toResult
        |> Result.andThen (applyFiles state)


applyFiles : FileDrop.State -> Msg -> Result String FileDrop.State
applyFiles state msg =
    case msg of
        Files inner ->
            Ok (Tuple.first (FileDrop.update inner state))

        _ ->
            Err "that was not a message of the file field"


choose : List (FileDrop.Attribute Msg) -> List FileDrop.FileInfo -> FilesStep
choose attributes files =
    filesEvent attributes
        fileInput
        (Event.custom "change" (Encode.object [ ( "target", Encode.object [ ( "files", Encode.list fileJson files ) ] ) ]))


dropOn : List (FileDrop.Attribute Msg) -> List FileDrop.FileInfo -> FilesStep
dropOn attributes files =
    filesEvent attributes
        [ Selector.class "klar-filedrop__zone" ]
        (Event.custom "drop" (Encode.object [ ( "dataTransfer", Encode.object [ ( "files", Encode.list fileJson files ) ] ) ]))


remove : List (FileDrop.Attribute Msg) -> String -> FilesStep
remove attributes name =
    filesEvent attributes (labelled ("Remove " ++ name)) Event.click


{-| The remove button of the first file with this name, when there are two.
-}
removeFirst : List (FileDrop.Attribute Msg) -> String -> FilesStep
removeFirst attributes name state =
    FileDrop.view Files attributes state
        |> Query.fromHtml
        |> Query.findAll (labelled ("Remove " ++ name))
        |> Query.first
        |> Event.simulate Event.click
        |> Event.toResult
        |> Result.andThen (applyFiles state)


given : List FileDrop.FileInfo -> FilesStep
given files state =
    Ok (FileDrop.setFiles files state)


afterFiles : List FilesStep -> FileDrop.State -> Result String FileDrop.State
afterFiles steps state =
    List.foldl (\step result -> Result.andThen step result) (Ok state) steps


acceptedNames : Result String FileDrop.State -> Result String (List String)
acceptedNames =
    Result.map (FileDrop.files >> List.map .name)


refusedNames : Result String FileDrop.State -> Result String (List ( String, FileDrop.Problem ))
refusedNames =
    Result.map (FileDrop.rejected >> List.map (\( file, problem ) -> ( file.name, problem )))


viewOfFiles : List (FileDrop.Attribute Msg) -> FileDrop.State -> Query.Single Msg
viewOfFiles attributes state =
    FileDrop.view Files attributes state |> Query.fromHtml


singleFileTests : Test
singleFileTests =
    describe "FileDrop: maxFiles 1 is a single-file field"
        [ describe "what the user sees"
            [ test "the file input does not take several files" <|
                \_ ->
                    viewOfFiles [ FileDrop.maxFiles 1 ] emptyDrop
                        |> Query.find fileInput
                        |> Query.hasNot [ Selector.attribute (Attr.multiple True) ]
            , test "a limit of 2 does take several files" <|
                \_ ->
                    viewOfFiles [ FileDrop.maxFiles 2 ] emptyDrop
                        |> Query.find fileInput
                        |> Query.has [ Selector.attribute (Attr.multiple True) ]
            , test "multiple does take several files" <|
                \_ ->
                    viewOfFiles [ FileDrop.multiple ] emptyDrop
                        |> Query.find fileInput
                        |> Query.has [ Selector.attribute (Attr.multiple True) ]
            , test "the button says Choose file" <|
                \_ ->
                    viewOfFiles [ FileDrop.maxFiles 1 ] emptyDrop
                        |> Query.find [ Selector.class "klar-button__label" ]
                        |> Query.has [ Selector.exactText "Choose file" ]
            , test "the zone says a file" <|
                \_ ->
                    viewOfFiles [ FileDrop.maxFiles 1 ] emptyDrop
                        |> Query.find [ Selector.class "klar-filedrop__title" ]
                        |> Query.has [ Selector.exactText "Drag and drop a file here" ]
            , test "with a limit of 3 the button says Choose files" <|
                \_ ->
                    viewOfFiles [ FileDrop.maxFiles 3 ] emptyDrop
                        |> Query.find [ Selector.class "klar-button__label" ]
                        |> Query.has [ Selector.exactText "Choose files" ]
            , test "maxFiles 1 wins over multiple that comes before it" <|
                \_ ->
                    viewOfFiles [ FileDrop.multiple, FileDrop.maxFiles 1 ] emptyDrop
                        |> Query.find fileInput
                        |> Query.hasNot [ Selector.attribute (Attr.multiple True) ]
            , test "maxFiles 1 wins over multiple that comes after it" <|
                \_ ->
                    viewOfFiles [ FileDrop.maxFiles 1, FileDrop.multiple ] emptyDrop
                        |> Query.find fileInput
                        |> Query.hasNot [ Selector.attribute (Attr.multiple True) ]
            , test "a later maxFiles 3 makes it a list again" <|
                \_ ->
                    viewOfFiles [ FileDrop.maxFiles 1, FileDrop.maxFiles 3 ] emptyDrop
                        |> Query.find fileInput
                        |> Query.has [ Selector.attribute (Attr.multiple True) ]
            , test "the rules do not say \"Up to 1 files\"" <|
                \_ ->
                    viewOfFiles [ FileDrop.maxFiles 1, FileDrop.accept [ ".pdf" ] ] emptyDrop
                        |> Query.hasNot [ Selector.text "Up to" ]
            , test "the other rules are still written out" <|
                \_ ->
                    viewOfFiles [ FileDrop.maxFiles 1, FileDrop.accept [ ".pdf" ], FileDrop.maxSize 5000000 ] emptyDrop
                        |> Query.has [ Selector.text "Allowed types: PDF", Selector.text "per file" ]
            , test "a limit of 3 is written out" <|
                \_ ->
                    viewOfFiles [ FileDrop.maxFiles 3 ] emptyDrop
                        |> Query.has [ Selector.text "Up to 3 files" ]
            ]
        , describe "choosing a file"
            [ test "a second choice replaces the first" <|
                \_ ->
                    afterFiles [ choose [ FileDrop.maxFiles 1 ] [ pdf "a.pdf" 10 ], choose [ FileDrop.maxFiles 1 ] [ pdf "b.pdf" 20 ] ] emptyDrop
                        |> acceptedNames
                        |> Expect.equal (Ok [ "b.pdf" ])
            , test "nothing is refused for being the second" <|
                \_ ->
                    afterFiles [ choose [ FileDrop.maxFiles 1 ] [ pdf "a.pdf" 10 ], choose [ FileDrop.maxFiles 1 ] [ pdf "b.pdf" 20 ] ] emptyDrop
                        |> refusedNames
                        |> Expect.equal (Ok [])
            , test "the same file again is not a duplicate: it replaces itself" <|
                \_ ->
                    afterFiles [ choose [ FileDrop.maxFiles 1 ] [ pdf "a.pdf" 10 ], choose [ FileDrop.maxFiles 1 ] [ pdf "a.pdf" 10 ] ] emptyDrop
                        |> Expect.all [ acceptedNames >> Expect.equal (Ok [ "a.pdf" ]), refusedNames >> Expect.equal (Ok []) ]
            , test "several files at once: the first is used" <|
                \_ ->
                    afterFiles [ choose [ FileDrop.maxFiles 1 ] [ pdf "a.pdf" 10, pdf "b.pdf" 20 ] ] emptyDrop
                        |> acceptedNames
                        |> Expect.equal (Ok [ "a.pdf" ])
            , test "a refused file is replaced by a good one" <|
                \_ ->
                    afterFiles [ choose [ FileDrop.maxFiles 1, FileDrop.accept [ ".pdf" ] ] [ exe "x.exe" 10 ], choose [ FileDrop.maxFiles 1, FileDrop.accept [ ".pdf" ] ] [ pdf "a.pdf" 10 ] ] emptyDrop
                        |> Expect.all [ acceptedNames >> Expect.equal (Ok [ "a.pdf" ]), refusedNames >> Expect.equal (Ok []) ]
            , test "a refused file is still refused, with its reason" <|
                \_ ->
                    afterFiles [ choose [ FileDrop.maxFiles 1, FileDrop.accept [ ".pdf" ] ] [ exe "x.exe" 10 ] ] emptyDrop
                        |> Expect.all [ acceptedNames >> Expect.equal (Ok []), refusedNames >> Expect.equal (Ok [ ( "x.exe", FileDrop.WrongType ) ]) ]
            , test "a file given with setFiles is replaced by the next choice" <|
                \_ ->
                    afterFiles [ given [ pdf "server.pdf" 10 ], choose [ FileDrop.maxFiles 1 ] [ pdf "a.pdf" 10 ] ] emptyDrop
                        |> acceptedNames
                        |> Expect.equal (Ok [ "a.pdf" ])
            ]
        , describe "dropping a file"
            [ test "a second drop replaces the first" <|
                \_ ->
                    afterFiles [ dropOn [ FileDrop.maxFiles 1 ] [ pdf "a.pdf" 10 ], dropOn [ FileDrop.maxFiles 1 ] [ png "b.png" 20 ] ] emptyDrop
                        |> Expect.all [ acceptedNames >> Expect.equal (Ok [ "b.png" ]), refusedNames >> Expect.equal (Ok []) ]
            , test "a drop replaces a file that was chosen" <|
                \_ ->
                    afterFiles [ choose [ FileDrop.maxFiles 1 ] [ pdf "a.pdf" 10 ], dropOn [ FileDrop.maxFiles 1 ] [ pdf "b.pdf" 20 ] ] emptyDrop
                        |> acceptedNames
                        |> Expect.equal (Ok [ "b.pdf" ])
            , test "several dropped files: the first is used" <|
                \_ ->
                    afterFiles [ dropOn [ FileDrop.maxFiles 1 ] [ pdf "a.pdf" 10, pdf "b.pdf" 20 ] ] emptyDrop
                        |> acceptedNames
                        |> Expect.equal (Ok [ "a.pdf" ])
            ]
        , describe "a field with a limit above 1"
            [ test "it still keeps the files and refuses the ones over the limit" <|
                \_ ->
                    afterFiles [ choose [ FileDrop.maxFiles 2 ] [ pdf "a.pdf" 1, pdf "b.pdf" 2, pdf "c.pdf" 3 ] ] emptyDrop
                        |> Expect.all [ acceptedNames >> Expect.equal (Ok [ "a.pdf", "b.pdf" ]), refusedNames >> Expect.equal (Ok [ ( "c.pdf", FileDrop.TooMany ) ]) ]
            , test "a field without a limit and without multiple still replaces" <|
                \_ ->
                    afterFiles [ choose [] [ pdf "a.pdf" 1 ], choose [] [ pdf "b.pdf" 2 ] ] emptyDrop
                        |> acceptedNames
                        |> Expect.equal (Ok [ "b.pdf" ])
            ]
        ]


removalTests : Test
removalTests =
    let
        several =
            [ FileDrop.multiple, FileDrop.accept [ ".pdf" ], FileDrop.maxSize 1000 ]
    in
    describe "FileDrop: removing a file keeps the result of the others"
        [ describe "files added with setFiles are not checked, then or later"
            [ test "a file that is too large is not refused after another file is removed" <|
                \_ ->
                    afterFiles [ given [ pdf "big.pdf" 5000, pdf "small.pdf" 10 ], remove several "small.pdf" ] emptyDrop
                        |> Expect.all [ acceptedNames >> Expect.equal (Ok [ "big.pdf" ]), refusedNames >> Expect.equal (Ok []) ]
            , test "a file of the wrong type is not refused after another file is removed" <|
                \_ ->
                    afterFiles [ given [ exe "tool.exe" 10, pdf "a.pdf" 10 ], remove several "a.pdf" ] emptyDrop
                        |> Expect.all [ acceptedNames >> Expect.equal (Ok [ "tool.exe" ]), refusedNames >> Expect.equal (Ok []) ]
            , test "two files that repeat each other are not refused" <|
                \_ ->
                    afterFiles [ given [ pdf "a.pdf" 10, pdf "a.pdf" 10, pdf "b.pdf" 10 ], remove several "b.pdf" ] emptyDrop
                        |> Expect.all [ acceptedNames >> Expect.equal (Ok [ "a.pdf", "a.pdf" ]), refusedNames >> Expect.equal (Ok []) ]
            , test "more files than maxFiles allows are not refused" <|
                \_ ->
                    afterFiles [ given [ pdf "a.pdf" 1, pdf "b.pdf" 1, pdf "c.pdf" 1 ], remove [ FileDrop.maxFiles 2 ] "c.pdf" ] emptyDrop
                        |> Expect.all [ acceptedNames >> Expect.equal (Ok [ "a.pdf", "b.pdf" ]), refusedNames >> Expect.equal (Ok []) ]
            , test "removing one of the files given leaves the others accepted" <|
                \_ ->
                    afterFiles [ given [ pdf "big.pdf" 5000, pdf "huge.pdf" 9000, pdf "small.pdf" 10 ], remove several "huge.pdf" ] emptyDrop
                        |> Expect.all [ acceptedNames >> Expect.equal (Ok [ "big.pdf", "small.pdf" ]), refusedNames >> Expect.equal (Ok []) ]
            , test "they count towards maxFiles for the next file" <|
                \_ ->
                    afterFiles [ given [ pdf "a.pdf" 1, pdf "b.pdf" 1 ], choose [ FileDrop.multiple, FileDrop.maxFiles 2 ] [ pdf "c.pdf" 1 ] ] emptyDrop
                        |> refusedNames
                        |> Expect.equal (Ok [ ( "c.pdf", FileDrop.TooMany ) ])
            , test "a new file that repeats one of them is a duplicate" <|
                \_ ->
                    afterFiles [ given [ pdf "a.pdf" 1 ], choose [ FileDrop.multiple ] [ pdf "a.pdf" 1 ] ] emptyDrop
                        |> refusedNames
                        |> Expect.equal (Ok [ ( "a.pdf", FileDrop.Duplicate ) ])
            ]
        , describe "the result stays with the file"
            [ test "an accepted file stays accepted when the rules are stricter at the next removal" <|
                \_ ->
                    afterFiles
                        [ choose [ FileDrop.multiple, FileDrop.maxSize 10000 ] [ pdf "big.pdf" 5000, pdf "small.pdf" 10 ]
                        , remove [ FileDrop.multiple, FileDrop.maxSize 1000 ] "small.pdf"
                        ]
                        emptyDrop
                        |> acceptedNames
                        |> Expect.equal (Ok [ "big.pdf" ])
            , test "a file refused for its type stays refused with the same reason" <|
                \_ ->
                    afterFiles
                        [ choose (FileDrop.multiple :: [ FileDrop.accept [ ".pdf" ] ]) [ exe "x.exe" 1, pdf "a.pdf" 1 ]
                        , remove (FileDrop.multiple :: [ FileDrop.accept [ ".pdf" ] ]) "a.pdf"
                        ]
                        emptyDrop
                        |> refusedNames
                        |> Expect.equal (Ok [ ( "x.exe", FileDrop.WrongType ) ])
            , test "a file refused for its size stays refused, also when the limit is raised later" <|
                \_ ->
                    afterFiles
                        [ choose [ FileDrop.multiple, FileDrop.maxSize 100 ] [ pdf "big.pdf" 5000, pdf "small.pdf" 10 ]
                        , remove [ FileDrop.multiple, FileDrop.maxSize 100000 ] "small.pdf"
                        ]
                        emptyDrop
                        |> refusedNames
                        |> Expect.equal (Ok [ ( "big.pdf", FileDrop.TooLarge ) ])
            ]
        , describe "a file refused because of the others is checked again"
            [ test "a file over maxFiles is accepted when there is room" <|
                \_ ->
                    afterFiles
                        [ choose [ FileDrop.maxFiles 2 ] [ pdf "a.pdf" 1, pdf "b.pdf" 2, pdf "c.pdf" 3 ]
                        , remove [ FileDrop.maxFiles 2 ] "a.pdf"
                        ]
                        emptyDrop
                        |> Expect.all [ acceptedNames >> Expect.equal (Ok [ "b.pdf", "c.pdf" ]), refusedNames >> Expect.equal (Ok []) ]
            , test "a file over maxFiles stays refused while there is no room" <|
                \_ ->
                    afterFiles
                        [ choose [ FileDrop.maxFiles 2 ] [ pdf "a.pdf" 1, pdf "b.pdf" 2, pdf "c.pdf" 3, pdf "d.pdf" 4 ]
                        , remove [ FileDrop.maxFiles 2 ] "a.pdf"
                        ]
                        emptyDrop
                        |> Expect.all [ acceptedNames >> Expect.equal (Ok [ "b.pdf", "c.pdf" ]), refusedNames >> Expect.equal (Ok [ ( "d.pdf", FileDrop.TooMany ) ]) ]
            , test "a duplicate is accepted when the file it repeated is gone" <|
                \_ ->
                    afterFiles
                        [ choose [ FileDrop.multiple ] [ pdf "a.pdf" 1 ]
                        , choose [ FileDrop.multiple ] [ pdf "a.pdf" 1 ]
                        , removeFirst [ FileDrop.multiple ] "a.pdf"
                        ]
                        emptyDrop
                        |> Expect.all [ acceptedNames >> Expect.equal (Ok [ "a.pdf" ]), refusedNames >> Expect.equal (Ok []) ]
            , test "removing a file touches the field" <|
                \_ ->
                    afterFiles [ given [ pdf "a.pdf" 1 ], remove [ FileDrop.multiple ] "a.pdf" ] emptyDrop
                        |> Result.map FileDrop.isTouched
                        |> Expect.equal (Ok True)
            ]
        ]



-- PASSWORD STRENGTH


letters : String -> Int -> Test
letters text expected =
    test (text ++ " is " ++ String.fromInt expected) <|
        \_ -> Expect.equal expected (PasswordInput.strength text)


strengthLetterTests : Test
strengthLetterTests =
    describe "PasswordInput.strength reads letters of every script as letters"
        [ describe "letters with a case"
            [ test "accented lowercase and uppercase letters are two kinds, like e and E" <|
                \_ -> Expect.equal (PasswordInput.strength "euoEUOeuo") (PasswordInput.strength "éüöÉÜÖéüö")
            , letters "éüöÉÜÖéüö" 2
            , letters "æøåÆØÅ1234" 3
            , test "Norwegian letters count as letters, not as symbols" <|
                \_ -> Expect.equal (PasswordInput.strength "Kjxqzwmvt7") (PasswordInput.strength "Æjxqzwmvt7")
            , letters "Пароль-тест-Ж9" 4
            , test "Cyrillic is the same as Latin" <|
                \_ -> Expect.equal (PasswordInput.strength "Parolx-tezt-Z9") (PasswordInput.strength "Пароль-тест-Ж9")
            , test "Greek is the same as Latin" <|
                \_ -> Expect.equal (PasswordInput.strength "Kjxqzwmvt7") (PasswordInput.strength "Κηχφζωμντ7")
            , test "a sharp s is a lowercase letter" <|
                \_ -> Expect.equal (PasswordInput.strength "Kjxqzwmvt7") (PasswordInput.strength "Kßxqzwmvt7")
            ]
        , describe "letters of a script without case count with the lowercase ones"
            [ letters "密码强度测试kxqzwm" 1
            , letters "密码强度测试KXQZWM" 2
            , test "Chinese letters alone are one kind" <|
                \_ -> Expect.equal 1 (PasswordInput.strength "密码强度测试验证码字符串")
            , test "Arabic letters and Arabic-Indic digits are letters and digits" <|
                \_ -> Expect.equal 2 (PasswordInput.strength "كلمةالسر٣٤٥٦")
            , test "Hebrew letters count as letters" <|
                \_ -> Expect.equal 2 (PasswordInput.strength "סיסמהחזקהA")
            , test "Korean, Japanese and Thai letters count as letters" <|
                \_ ->
                    Expect.equal [ 2, 2, 2 ]
                        [ PasswordInput.strength "한국어비밀번호입니다A"
                        , PasswordInput.strength "パスワードですね１２"
                        , PasswordInput.strength "รหัสผ่านไทยA"
                        ]
            ]
        , describe "symbols are still symbols"
            [ letters "q€w£e¥r§t±y×" 2
            , test "punctuation beyond ASCII is a symbol" <|
                \_ -> Expect.equal (PasswordInput.strength "q-w_e.r,t;y:") (PasswordInput.strength "q—w…e¿r«t»y•")
            , test "emoji are symbols" <|
                \_ -> Expect.equal (PasswordInput.strength "k#m#x#q#z#h#") (PasswordInput.strength "k😀m😁x😂q😃z😄h😅")
            , test "a full-width exclamation mark is a symbol, a full-width letter is a letter" <|
                \_ -> Expect.equal (PasswordInput.strength "kxqzwmvT!") (PasswordInput.strength "kxqzwmvＴ！")
            , test "a combining accent is not a kind of its own" <|
                \_ -> Expect.equal 1 (PasswordInput.strength "kxqzwmvt́")
            , test "a combining accent does not turn a lowercase password into a mixed one" <|
                \_ -> Expect.equal (PasswordInput.strength "kxqzwmvte") (PasswordInput.strength "kxqzwmvté")
            ]
        ]


strengthLengthAndPatternTests : Test
strengthLengthAndPatternTests =
    describe "PasswordInput.strength: length, kinds and patterns"
        [ letters "" 0
        , letters "Kx7" 1
        , letters "kxqzwmvt" 1
        , letters "Kxqzwmvt" 2
        , letters "Kxqzwmvt7a" 3
        , letters "Kxqzwmvt7a#Zq9Pl" 4
        , letters "Kxqzwmvt7#Zq" 4
        , letters "abcdefgh" 1
        , letters "aaaaaaaa" 1
        , letters "password123" 1
        , describe "length counts characters, not UTF-16 units"
            [ letters "ab😀😁😂😃😄" 1
            , letters "ab😀😁😂😃😄😅" 2
            ]
        , describe "digits of other scripts are digits"
            [ test "Arabic-Indic digits next to letters make two kinds" <|
                \_ -> Expect.equal (PasswordInput.strength "kxqzwmvt73") (PasswordInput.strength "kxqzwmvt٧٣")
            , test "full-width digits are digits" <|
                \_ -> Expect.equal (PasswordInput.strength "kxqzwmvt73") (PasswordInput.strength "kxqzwmvt７３")
            ]
        , describe "an ascending run of letters of another script is a pattern too"
            [ letters "αβγδεζηθ" 1 ]
        , describe "length counts most: a long passphrase is strong without digits or symbols"
            [ letters "kxqzwmvtpqrlnbg" 2
            , letters "correct horse battery" 3
            , letters "correcthorsebatterystaple" 4
            , letters "kxqzwmvtpqrlnbgkxqzwmvt" 3
            ]
        , describe "a long password of few different characters is not strong"
            [ letters "aaaaaaaaaaaaaaaaaaaaaaab" 1
            , letters "abcabcabcabcabcabcabcabc" 1
            , letters "111111111111111111111112" 1
            , letters "aaaaaaaaaaaaaaab" 1
            , letters "Aa1!Aa1!Aa1!Aa1!" 2
            ]
        ]


{-| A strong password (4) with the word inside it.
-}
around : String -> String
around word =
    "Xk9#" ++ word ++ "#Zq4!pLm"


{-| A short password that is mostly the word.
-}
short : String -> String
short word =
    "Xk9#" ++ word


weakWith : String -> Test
weakWith word =
    test (word ++ " counts for nothing, so a short password with it is weak") <|
        \_ ->
            Expect.all
                [ \_ -> Expect.equal 1 (PasswordInput.strength (short word))
                , \_ -> Expect.equal (PasswordInput.strength (around "")) (PasswordInput.strength (around word))
                ]
                ()


commonPasswordTests : Test
commonPasswordTests =
    describe "PasswordInput.strength knows the common passwords of both languages"
        [ test "the password around the words is strong without them" <|
            \_ -> Expect.equal 4 (PasswordInput.strength (around "kitchen"))
        , describe "English, the ones from before"
            (List.map weakWith [ "password", "qwerty", "123456", "letmein", "welcome", "admin", "abc123", "iloveyou" ])
        , describe "English, more"
            (List.map weakWith [ "passw0rd", "p@ssw0rd", "qwertyuiop", "dragon", "monkey", "football", "baseball", "sunshine", "princess", "superman", "starwars", "trustno1", "1qaz2wsx", "changeme", "freedom", "mustang", "shadow", "soccer" ])
        , describe "Norwegian"
            (List.map weakWith [ "passord", "norge", "hemmelig", "velkommen", "sommer", "fotball", "elskerdeg", "kjaerlighet", "kjærlighet" ])
        , test "the case does not matter" <|
            \_ -> Expect.equal [ 1, 1, 1 ] (List.map (short >> PasswordInput.strength) [ "DRAGON", "Hemmelig", "PaSsOrD" ])
        , test "the locale does not matter: there is none" <|
            \_ -> Expect.equal [ 1, 1 ] (List.map (short >> PasswordInput.strength) [ "password", "passord" ])
        , test "a word inside a longer word counts" <|
            \_ -> Expect.equal 1 (PasswordInput.strength (short "myDragon"))
        , test "a password that is mostly a common one is weak however long it is" <|
            \_ -> Expect.equal [ 1, 1 ] (List.map PasswordInput.strength [ "password123", "Qwertyuiop12" ])
        ]



-- THE WRAPPER


type alias Wrapped =
    { name : String
    , view : Maybe String -> Html Msg
    , control : Selector
    , focusable : String
    }


wrapped : List Wrapped
wrapped =
    [ { name = "TextInput"
      , view = \error -> TextInput.view [ TextInput.value "x", TextInput.onInput Typed, TextInput.errorMaybe error ]
      , control = Selector.class "klar-input"
      , focusable = "input"
      }
    , { name = "TextInput with clearable and a prefix"
      , view = \error -> TextInput.view [ TextInput.value "x", TextInput.onInput Typed, TextInput.clearable, TextInput.search, TextInput.errorMaybe error ]
      , control = Selector.class "klar-input"
      , focusable = "input"
      }
    , { name = "TextArea"
      , view = \error -> TextArea.view [ TextArea.value "x", TextArea.onInput Typed, TextArea.errorMaybe error ]
      , control = Selector.class "klar-textarea-wrap"
      , focusable = "textarea"
      }
    , { name = "TextArea with a limit"
      , view = \error -> TextArea.view [ TextArea.value "x", TextArea.onInput Typed, TextArea.maxLength 10, TextArea.errorMaybe error ]
      , control = Selector.class "klar-textarea-wrap"
      , focusable = "textarea"
      }
    , { name = "PasswordInput"
      , view = \error -> PasswordInput.view Password [ PasswordInput.errorMaybe error ] (PasswordInput.setValue "x" (PasswordInput.init "password"))
      , control = Selector.class "klar-password"
      , focusable = "input"
      }
    , { name = "SearchInput"
      , view = \error -> SearchInput.view Search [ SearchInput.errorMaybe error ] (SearchInput.init "search")
      , control = Selector.class "klar-search"
      , focusable = "input"
      }
    , { name = "FileDrop"
      , view = \error -> FileDrop.view Files [ FileDrop.errorMaybe error ] (FileDrop.init "files")
      , control = Selector.class "klar-filedrop"
      , focusable = "input"
      }
    , { name = "NumberInput"
      , view = \error -> NumberInput.view Number [ NumberInput.errorMaybe error ] (NumberInput.init "number")
      , control = Selector.class "klar-number"
      , focusable = "input"
      }
    , { name = "TagInput"
      , view = \error -> TagInput.view Tags [ TagInput.errorMaybe error ] (TagInput.init "tags")
      , control = Selector.class "klar-taginput-wrap"
      , focusable = "input"
      }
    ]


{-| The element at this place among the children of the field, counting the text
nodes Elm puts in the places of the label, the hint and the error: the control
is always the second.
-}
controlOf : Query.Single Msg -> Query.Single Msg
controlOf field =
    field |> Query.children [] |> Query.index 1


wrapperTests : Test
wrapperTests =
    describe "the control stays in the same wrapper when an error appears"
        (List.map wrapperTest wrapped ++ [ stylesheetTest ])


wrapperTest : Wrapped -> Test
wrapperTest { name, view, control, focusable } =
    describe name
        [ test "with nothing to draw the control is inside the field" <|
            \_ ->
                view Nothing
                    |> Query.fromHtml
                    |> Expect.all
                        [ Query.has [ Selector.class "klar-field" ]
                        , controlOf >> Query.has [ control ]
                        ]
        , test "with an error it is the same field and the control is still in the same place" <|
            \_ ->
                view (Just "Bad")
                    |> Query.fromHtml
                    |> Expect.all
                        [ Query.has [ Selector.class "klar-field", Selector.class "klar-field--invalid" ]
                        , controlOf >> Query.has [ control ]
                        ]
        , test "the error is drawn in the wrapper" <|
            \_ ->
                view (Just "Bad")
                    |> Query.fromHtml
                    |> Query.find [ Selector.class "klar-field__error" ]
                    |> Query.has [ Selector.text "Bad" ]
        , test "with nothing to draw there is no label, hint or error in the field" <|
            \_ ->
                view Nothing
                    |> Query.fromHtml
                    |> Expect.all
                        [ Query.findAll [ Selector.class "klar-field__label" ] >> Query.count (Expect.equal 0)
                        , Query.findAll [ Selector.class "klar-field__hint" ] >> Query.count (Expect.equal 0)
                        , Query.findAll [ Selector.class "klar-field__error" ] >> Query.count (Expect.equal 0)
                        ]
        , test "the element that takes the focus is inside the control, with and without the error" <|
            \_ ->
                let
                    holdsTheFocus html =
                        html |> Query.fromHtml |> controlOf |> Query.findAll [ Selector.tag focusable ] |> Query.count (Expect.equal 1)
                in
                Expect.all [ \_ -> holdsTheFocus (view Nothing), \_ -> holdsTheFocus (view (Just "Bad")) ] ()
        ]


stylesheetTest : Test
stylesheetTest =
    describe "the stylesheet"
        [ test "a field around nothing but a text input is as wide as the input alone" <|
            \_ ->
                Expect.equal True (String.contains ".klar-field:has(> .klar-input:only-child){width: 100%}" Css.rules)
        ]



-- INLINE EDIT


type alias EditStep =
    InlineEdit.State -> Result String InlineEdit.State


customer : InlineEdit.State
customer =
    InlineEdit.init "customer" "Ada Lovelace"


editEvent : List (InlineEdit.Attribute Msg) -> List Selector -> ( String, Value ) -> EditStep
editEvent attributes selectors event state =
    InlineEdit.view Edit attributes state
        |> Query.fromHtml
        |> Query.find selectors
        |> Event.simulate event
        |> Event.toResult
        |> Result.andThen
            (\msg ->
                case msg of
                    Edit inner ->
                        Ok (Tuple.first (InlineEdit.update inner state))

                    _ ->
                        Err "that was not a message of the inline edit"
            )


startEditing : EditStep
startEditing =
    editEvent [] [ Selector.class "klar-inline-edit__display" ] Event.click


typeText : String -> EditStep
typeText text =
    editEvent [] inputOf (Event.input text)


afterEdits : List EditStep -> InlineEdit.State -> Result String InlineEdit.State
afterEdits steps state =
    List.foldl (\step result -> Result.andThen step result) (Ok state) steps


viewOfEdit : List (InlineEdit.Attribute Msg) -> InlineEdit.State -> Query.Single Msg
viewOfEdit attributes state =
    InlineEdit.view Edit attributes state |> Query.fromHtml


{-| An editor that is open, with a text that was typed in it.
-}
open : InlineEdit.State
open =
    afterEdits [ startEditing, typeText "Ada Byron" ] customer
        |> Result.withDefault customer


failedSave : InlineEdit.State
failedSave =
    failedWith Remote.network


failedWith : Remote.Kind -> InlineEdit.State
failedWith kind =
    afterEdits [ startEditing, typeText "Ada Byron", editEvent [] inputOf (keyDown "Enter") ] customer
        |> Result.map (InlineEdit.failed (Remote.problem kind))
        |> Result.withDefault customer


happens : Result String a -> Expectation
happens result =
    case result of
        Ok _ ->
            Expect.pass

        Err problem ->
            Expect.fail ("this should have been handled, but: " ++ problem)


nothingHappens : Result String a -> Expectation
nothingHappens result =
    case result of
        Ok _ ->
            Expect.fail "this should not be handled at all"

        Err _ ->
            Expect.pass


inlineEditTests : Test
inlineEditTests =
    let
        off =
            [ InlineEdit.disabled True ]

        saveButton =
            labelled "Save"

        cancelButton =
            labelled "Cancel"

        try attributes selectors event state =
            editEvent attributes selectors event state
    in
    describe "InlineEdit.disabled also stops an editor that is open"
        [ describe "the editor that is open"
            [ test "the editor is open before the test starts" <|
                \_ -> Expect.equal ( True, "Ada Lovelace" ) ( InlineEdit.isEditing open, InlineEdit.value open )
            , test "it is still on the screen when the field is disabled" <|
                \_ ->
                    viewOfEdit off open
                        |> Query.find inputOf
                        |> Query.has [ Selector.attribute (Attr.value "Ada Byron") ]
            , test "the input is read-only and says it is disabled" <|
                \_ ->
                    viewOfEdit off open
                        |> Query.find inputOf
                        |> Query.has [ Selector.attribute (Attr.readonly True), Selector.attribute (Attr.attribute "aria-disabled" "true") ]
            , test "the input is not marked read-only when the field is enabled" <|
                \_ ->
                    viewOfEdit [] open
                        |> Query.find inputOf
                        |> Query.hasNot [ Selector.attribute (Attr.readonly True), Selector.attribute (Attr.attribute "aria-disabled" "true") ]
            , test "the box looks disabled" <|
                \_ ->
                    viewOfEdit off open
                        |> Query.find [ Selector.class "klar-inline-edit__box" ]
                        |> Query.has [ Selector.class "klar-input--disabled" ]
            , test "the save button is disabled" <|
                \_ ->
                    viewOfEdit off open
                        |> Query.find saveButton
                        |> Query.has [ Selector.disabled True ]
            , test "the cancel button is disabled" <|
                \_ ->
                    viewOfEdit off open
                        |> Query.find cancelButton
                        |> Query.has [ Selector.disabled True ]
            , test "the buttons are not disabled when the field is enabled" <|
                \_ ->
                    viewOfEdit [] open
                        |> Query.find saveButton
                        |> Query.hasNot [ Selector.disabled True ]
            ]
        , describe "what the editor does not do while it is disabled"
            [ test "leaving it does not save" <|
                \_ -> try off inputOf Event.blur open |> nothingHappens
            , test "Enter does not save" <|
                \_ -> try off inputOf (keyDown "Enter") open |> nothingHappens
            , test "Escape does not cancel" <|
                \_ -> try off inputOf (keyDown "Escape") open |> nothingHappens
            , test "typing changes nothing" <|
                \_ -> try off inputOf (Event.input "Someone else") open |> nothingHappens
            , test "the save button does not save" <|
                \_ -> try off saveButton Event.click open |> nothingHappens
            , test "the cancel button does not cancel" <|
                \_ -> try off cancelButton Event.click open |> nothingHappens
            , test "the state stays an open editor with nothing to save" <|
                \_ ->
                    Expect.equal { editing = True, saving = False, pending = Nothing, value = "Ada Lovelace" }
                        { editing = InlineEdit.isEditing open
                        , saving = InlineEdit.isSaving open
                        , pending = InlineEdit.pending open
                        , value = InlineEdit.value open
                        }
            ]
        , describe "what the editor does when it is enabled"
            [ test "leaving it saves" <|
                \_ -> try [] inputOf Event.blur open |> happens
            , test "Enter saves" <|
                \_ -> try [] inputOf (keyDown "Enter") open |> Result.map InlineEdit.isSaving |> Expect.equal (Ok True)
            , test "Escape cancels" <|
                \_ -> try [] inputOf (keyDown "Escape") open |> Result.map InlineEdit.isEditing |> Expect.equal (Ok False)
            , test "typing changes the text" <|
                \_ -> try [] inputOf (Event.input "Someone else") open |> happens
            , test "the save button saves" <|
                \_ -> try [] saveButton Event.click open |> Result.map InlineEdit.isSaving |> Expect.equal (Ok True)
            , test "the cancel button cancels" <|
                \_ -> try [] cancelButton Event.click open |> Result.map InlineEdit.isEditing |> Expect.equal (Ok False)
            , test "once the field is enabled again the editor works where it stopped" <|
                \_ ->
                    -- the same state, drawn disabled and then enabled
                    Expect.all
                        [ \_ -> try off inputOf (keyDown "Enter") open |> nothingHappens
                        , \_ -> try [ InlineEdit.disabled False ] inputOf (keyDown "Enter") open |> Result.map (\s -> ( InlineEdit.isSaving s, InlineEdit.pending s )) |> Expect.equal (Ok ( True, Just "Ada Byron" ))
                        ]
                        ()
            ]
        , describe "the other states"
            [ test "a conflict or a validation problem cannot be tried again" <|
                \_ ->
                    Expect.all
                        [ \_ -> viewOfEdit [] (failedWith Remote.conflict) |> Query.hasNot [ Selector.text "Try again" ]
                        , \_ -> viewOfEdit [] (failedWith Remote.validation) |> Query.hasNot [ Selector.text "Try again" ]
                        , \_ -> viewOfEdit [] (failedWith Remote.conflict) |> Query.has [ Selector.text "Cancel" ]
                        , \_ -> viewOfEdit [] failedSave |> Query.has [ Selector.text "Try again" ]
                        ]
                        ()
            , test "text that is not being edited is plain text without a button" <|
                \_ -> viewOfEdit off customer |> Query.hasNot [ Selector.tag "button" ]
            , test "after a failed save the retry button is inactive" <|
                \_ ->
                    try off [ Selector.tag "button", Selector.containing [ Selector.text "Try again" ] ] Event.click failedSave
                        |> nothingHappens
            , test "after a failed save the cancel button is inactive" <|
                \_ ->
                    try off [ Selector.tag "button", Selector.containing [ Selector.text "Cancel" ] ] Event.click failedSave
                        |> nothingHappens
            , test "they are disabled buttons" <|
                \_ ->
                    viewOfEdit off failedSave
                        |> Query.findAll [ Selector.tag "button", Selector.disabled True ]
                        |> Query.count (Expect.equal 2)
            , test "after a failed save the buttons work when the field is enabled" <|
                \_ ->
                    Expect.all
                        [ \_ -> try [] [ Selector.tag "button", Selector.containing [ Selector.text "Try again" ] ] Event.click failedSave |> Result.map InlineEdit.isSaving |> Expect.equal (Ok True)
                        , \_ -> try [] [ Selector.tag "button", Selector.containing [ Selector.text "Cancel" ] ] Event.click failedSave |> Result.map InlineEdit.isFailed |> Expect.equal (Ok False)
                        ]
                        ()
            ]
        ]



-- THE CLEAR BUTTON OF TEXT INPUT


clearButtonTests : Test
clearButtonTests =
    let
        clear =
            TextInput.view [ TextInput.value "abc", TextInput.clearable, TextInput.onInput Typed ]
                |> Query.fromHtml
                |> Query.find [ Selector.class "klar-input__clear" ]

        messages events =
            events
                |> List.map (\event -> clear |> Event.simulate event |> Event.toResult)
                |> List.filterMap Result.toMaybe
    in
    describe "TextInput.clearable sends onInput \"\" once"
        [ test "pressing the mouse button clears" <|
            \_ -> clear |> Event.simulate Event.mouseDown |> Event.expect (Typed "")
        , test "pressing the mouse button keeps the focus in the field" <|
            \_ -> clear |> Event.simulate Event.mouseDown |> Event.expectPreventDefault
        , test "the click that follows a press sends nothing more" <|
            \_ -> clear |> Event.simulate (clickWithDetail 1) |> Event.toResult |> nothingHappens
        , test "a double click does not send either" <|
            \_ -> clear |> Event.simulate (clickWithDetail 2) |> Event.toResult |> nothingHappens
        , test "a whole click with the mouse sends one message" <|
            \_ -> Expect.equal [ Typed "" ] (messages [ Event.mouseDown, Event.mouseUp, clickWithDetail 1 ])
        , test "a click from a key or from assistive technology clears" <|
            \_ -> clear |> Event.simulate (clickWithDetail 0) |> Event.expect (Typed "")
        , test "a click that says nothing about presses clears" <|
            \_ -> clear |> Event.simulate Event.click |> Event.expect (Typed "")
        , test "the activation by a key sends one message" <|
            \_ -> Expect.equal [ Typed "" ] (messages [ clickWithDetail 0 ])
        , test "the button is still left out of the Tab order and has a name" <|
            \_ ->
                clear
                    |> Query.has
                        [ Selector.attribute (Attr.tabindex -1)
                        , Selector.attribute (Attr.attribute "aria-label" "Clear field")
                        ]
        ]
