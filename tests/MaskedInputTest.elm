module MaskedInputTest exposing (suite)

{-| `Klar.MaskedInput`: the field for an identifier with a fixed shape.

A test draws the field, finds the input the way a user would, simulates the event
(with the position of the caret, as a browser sends it), takes the message that the input
sends and gives it to `update`, as the application would.

-}

import Expect exposing (Expectation)
import Html.Attributes as Attr
import Json.Encode as Encode exposing (Value)
import Klar.Locale as Locale
import Klar.MaskedInput as MaskedInput exposing (Mask)
import Klar.Theme as Theme
import Test exposing (Test, describe, test)
import Test.Html.Event as Event
import Test.Html.Query as Query
import Test.Html.Selector as Selector exposing (Selector)


type Msg
    = Input MaskedInput.Msg


suite : Test
suite =
    describe "Klar.MaskedInput"
        [ masksTests
        , typingTests
        , valueTests
        , errorTests
        , languageTests
        , middleEditTests
        , wrongCharacterTests
        , leavingTests
        , stateTests
        , renderTests
        ]



-- HELPERS


type alias Step =
    MaskedInput.State -> Result String MaskedInput.State


type alias Attributes =
    List (MaskedInput.Attribute Msg)


inputOf : List Selector
inputOf =
    [ Selector.tag "input" ]


viewOf : Attributes -> MaskedInput.State -> Query.Single Msg
viewOf attributes state =
    MaskedInput.view Input attributes state |> Query.fromHtml


event : Attributes -> ( String, Value ) -> Step
event attributes simulated state =
    viewOf attributes state
        |> Query.find inputOf
        |> Event.simulate simulated
        |> Event.toResult
        |> Result.map (\(Input inner) -> Tuple.first (MaskedInput.update inner state))


{-| What a browser sends when the user has edited the text: the new text of the input and
the position of the caret behind the edit.
-}
inputEvent : String -> Int -> ( String, Value )
inputEvent typed caret =
    Event.custom "input"
        (Encode.object
            [ ( "target"
              , Encode.object
                    [ ( "value", Encode.string typed )
                    , ( "selectionStart", Encode.int caret )
                    ]
              )
            ]
        )


{-| Types a text with the caret at its end, as the user does.
-}
typeIn : Attributes -> String -> Step
typeIn attributes typed =
    event attributes (inputEvent typed (String.length typed))


{-| Types a text with the caret somewhere in it, as an edit in the middle does.
-}
typeAt : Attributes -> Int -> String -> Step
typeAt attributes caret typed =
    event attributes (inputEvent typed caret)


{-| One character after another, each added to what the field shows.
-}
typeOneByOne : Attributes -> String -> Step
typeOneByOne attributes characters state =
    String.toList characters
        |> List.foldl
            (\c result ->
                Result.andThen (\current -> typeIn attributes (MaskedInput.text current ++ String.fromChar c) current) result
            )
            (Ok state)


focusIn : Attributes -> Step
focusIn attributes =
    event attributes Event.focus


leave : Attributes -> Step
leave attributes =
    event attributes Event.blur


pressKey : Attributes -> String -> Step
pressKey attributes key =
    event attributes
        (Event.custom "keydown"
            (Encode.object
                [ ( "key", Encode.string key )
                , ( "ctrlKey", Encode.bool False )
                , ( "metaKey", Encode.bool False )
                , ( "shiftKey", Encode.bool False )
                , ( "altKey", Encode.bool False )
                ]
            )
        )


after : List Step -> MaskedInput.State -> Result String MaskedInput.State
after steps state =
    List.foldl (\step result -> Result.andThen step result) (Ok state) steps


orgnr : MaskedInput.State
orgnr =
    MaskedInput.init "orgnr" MaskedInput.norwegianOrganisationNumber


ibanField : MaskedInput.State
ibanField =
    MaskedInput.init "iban" MaskedInput.iban


phoneField : MaskedInput.State
phoneField =
    MaskedInput.init "phone" MaskedInput.phone


plain : Attributes
plain =
    [ MaskedInput.label "Organisation number" ]


norwegian : Attributes
norwegian =
    [ MaskedInput.label "Organisasjonsnummer", MaskedInput.locale Locale.nb ]


expectText : String -> Result String MaskedInput.State -> Expectation
expectText expected result =
    case result of
        Ok state ->
            Expect.equal expected (MaskedInput.text state)

        Err problem ->
            Expect.fail problem


{-| What the input shows.
-}
expectShown : Attributes -> String -> Result String MaskedInput.State -> Expectation
expectShown attributes shown result =
    case result of
        Ok state ->
            viewOf attributes state
                |> Query.find inputOf
                |> Query.has [ Selector.attribute (Attr.value shown) ]

        Err problem ->
            Expect.fail problem


expectValue : Maybe String -> Result String MaskedInput.State -> Expectation
expectValue expected result =
    case result of
        Ok state ->
            Expect.equal expected (MaskedInput.value state)

        Err problem ->
            Expect.fail problem


expectFlags : { complete : Bool, valid : Bool } -> Result String MaskedInput.State -> Expectation
expectFlags expected result =
    case result of
        Ok state ->
            Expect.equal expected { complete = MaskedInput.isComplete state, valid = MaskedInput.isValid state }

        Err problem ->
            Expect.fail problem


{-| The error the field draws, if any.
-}
expectError : Attributes -> Maybe String -> Result String MaskedInput.State -> Expectation
expectError attributes expected result =
    case result of
        Ok state ->
            case expected of
                Just message ->
                    viewOf attributes state
                        |> Query.find [ Selector.class "klar-field__error" ]
                        |> Query.has [ Selector.text message ]

                Nothing ->
                    viewOf attributes state
                        |> Query.hasNot [ Selector.class "klar-field__error" ]

        Err problem ->
            Expect.fail problem



-- THE MASKS


masksTests : Test
masksTests =
    describe "making a mask"
        [ test "a pattern is a mask" <|
            \_ -> Expect.equal True (MaskedInput.pattern "@@-####" /= Nothing)
        , test "a pattern that makes no sense is nothing, so the application knows at once" <|
            \_ ->
                [ "", "---", "AB-####", "##\\", "#\t#" ]
                    |> List.filterMap MaskedInput.pattern
                    |> List.length
                    |> Expect.equal 0
        , test "postal codes are known for some countries, in any case" <|
            \_ ->
                Expect.equal [ True, True, True, True, False, False ]
                    [ MaskedInput.postalCode "SE" /= Nothing
                    , MaskedInput.postalCode "nl" /= Nothing
                    , MaskedInput.postalCode " NO " /= Nothing
                    , MaskedInput.postalCode "US" /= Nothing
                    , MaskedInput.postalCode "GB" /= Nothing
                    , MaskedInput.postalCode "" /= Nothing
                    ]
        , test "the postal code of a country is written as people write it there" <|
            \_ ->
                Expect.equal [ Ok "123 45", Ok "1234 AB", Ok "12-345" ]
                    [ postalTyped "SE" "12345", postalTyped "NL" "1234ab", postalTyped "PL" "12345" ]
        , test "the order of the attributes does not matter" <|
            \_ ->
                let
                    first =
                        [ MaskedInput.label "A", MaskedInput.hint "h", MaskedInput.size Theme.Large ]

                    second =
                        [ MaskedInput.size Theme.Large, MaskedInput.hint "h", MaskedInput.label "A" ]
                in
                Expect.all
                    [ \_ -> viewOf first orgnr |> Query.has [ Selector.class "klar-input--lg", Selector.text "A", Selector.text "h" ]
                    , \_ -> viewOf second orgnr |> Query.has [ Selector.class "klar-input--lg", Selector.text "A", Selector.text "h" ]
                    ]
                    ()
        ]


postalTyped : String -> String -> Result String String
postalTyped country typed =
    case MaskedInput.postalCode country of
        Just mask ->
            after [ typeIn [] typed ] (MaskedInput.init "postal" mask) |> Result.map MaskedInput.text

        Nothing ->
            Err "no such country"



-- TYPING


typingTests : Test
typingTests =
    describe "typing at the end"
        [ test "an organisation number is written in groups while it is typed" <|
            \_ ->
                after [ typeOneByOne plain "974760673" ] orgnr
                    |> Expect.all [ expectText "974 760 673", expectShown plain "974 760 673" ]
        , test "every step is the groups so far" <|
            \_ ->
                let
                    steps =
                        [ "9", "97", "974", "974 7", "974 76", "974 760", "974 760 6", "974 760 67", "974 760 673" ]

                    shownAfter n =
                        after [ typeOneByOne plain (String.left n "974760673") ] orgnr |> Result.map MaskedInput.text
                in
                Expect.equal (List.map Ok steps) (List.map shownAfter (List.range 1 9))
        , test "an IBAN is written in groups of four, in capitals" <|
            \_ ->
                after [ typeOneByOne [] "no9386011117947" ] ibanField
                    |> expectText "NO93 8601 1117 947"
        , test "pasting a whole value, however it is written, gives the groups" <|
            \_ ->
                Expect.equal (List.repeat 4 (Ok "NO93 8601 1117 947"))
                    [ after [ typeIn [] "NO9386011117947" ] ibanField |> Result.map MaskedInput.text
                    , after [ typeIn [] "no93 8601 1117 947" ] ibanField |> Result.map MaskedInput.text
                    , after [ typeIn [] "NO93-8601-1117-947" ] ibanField |> Result.map MaskedInput.text
                    , after [ typeIn [] "  NO93.8601.1117.947 " ] ibanField |> Result.map MaskedInput.text
                    ]
        , test "typing a separator gives nothing: the next character brings it" <|
            \_ ->
                after [ typeIn plain "974", typeIn plain "974 " ] orgnr
                    |> expectText "974"
        , test "a phone number is written with its country code apart" <|
            \_ ->
                after [ typeOneByOne [] "+4791234567" ] phoneField
                    |> expectText "+47 912 34 567"
        , test "a bank account is written with points" <|
            \_ ->
                after [ typeOneByOne [] "86011117947" ] (MaskedInput.init "account" MaskedInput.norwegianBankAccount)
                    |> expectText "8601.11.17947"
        , test "a pattern of your own" <|
            \_ ->
                case MaskedInput.pattern "@@-####" of
                    Just mask ->
                        after [ typeOneByOne [] "ab1234" ] (MaskedInput.init "sku" mask)
                            |> Expect.all [ expectText "AB-1234", expectValue (Just "AB1234") ]

                    Nothing ->
                        Expect.fail "the pattern should be a pattern"
        , test "deleting from the end, a character at a time, goes back through the groups" <|
            \_ ->
                let
                    full =
                        after [ typeOneByOne plain "974760673" ] orgnr

                    deleted n =
                        full
                            |> Result.andThen (deleteFromEnd plain n)
                            |> Result.map MaskedInput.text
                in
                Expect.equal [ Ok "974 760 67", Ok "974 760 6", Ok "974 760", Ok "974 76", Ok "974 7", Ok "974" ]
                    (List.map deleted [ 1, 2, 3, 4, 5, 6 ])
        ]


deleteFromEnd : Attributes -> Int -> Step
deleteFromEnd attributes count state =
    List.foldl
        (\_ result ->
            Result.andThen (\current -> typeIn attributes (String.dropRight 1 (MaskedInput.text current)) current) result
        )
        (Ok state)
        (List.range 1 count)



-- THE VALUE


valueTests : Test
valueTests =
    describe "value, isComplete and isValid"
        [ test "an empty field has no value, is not complete, and is valid" <|
            \_ ->
                Ok orgnr
                    |> Expect.all [ expectValue Nothing, expectFlags { complete = False, valid = True } ]
        , test "an unfinished number has no value, is not complete, and is not valid" <|
            \_ ->
                after [ typeIn plain "974 760" ] orgnr
                    |> Expect.all [ expectValue Nothing, expectFlags { complete = False, valid = False } ]
        , test "a complete number with the right check digit is the value, complete and valid" <|
            \_ ->
                after [ typeIn plain "974 760 673" ] orgnr
                    |> Expect.all [ expectValue (Just "974760673"), expectFlags { complete = True, valid = True } ]
        , test "a complete number with the wrong check digit has no value, is complete, and is not valid" <|
            \_ ->
                after [ typeIn plain "974 760 674" ] orgnr
                    |> Expect.all [ expectValue Nothing, expectFlags { complete = True, valid = False } ]
        , test "a number that is too long has no value and is not complete" <|
            \_ ->
                after [ typeIn plain "974 760 673 1" ] orgnr
                    |> Expect.all [ expectValue Nothing, expectFlags { complete = False, valid = False } ]
        , test "the IBAN of a country is complete at the length of the country" <|
            \_ ->
                Expect.all
                    [ \_ -> after [ typeIn [] "NO93 8601 1117 947" ] ibanField |> Expect.all [ expectValue (Just "NO9386011117947"), expectFlags { complete = True, valid = True } ]
                    , \_ -> after [ typeIn [] "DE89 3704 0044 0532 0130 00" ] ibanField |> Expect.all [ expectValue (Just "DE89370400440532013000"), expectFlags { complete = True, valid = True } ]
                    , \_ -> after [ typeIn [] "NO93 8601 1117" ] ibanField |> Expect.all [ expectValue Nothing, expectFlags { complete = False, valid = False } ]
                    , \_ -> after [ typeIn [] "NO94 8601 1117 947" ] ibanField |> Expect.all [ expectValue Nothing, expectFlags { complete = True, valid = False } ]
                    ]
                    ()
        , test "the value of a phone number has its plus and no spaces" <|
            \_ ->
                after [ typeIn [] "+47 912 34 567" ] phoneField
                    |> Expect.all [ expectValue (Just "+4791234567"), expectFlags { complete = True, valid = True } ]
        , test "a phone number without + is not valid" <|
            \_ ->
                after [ typeIn [] "912 34 567" ] phoneField
                    |> Expect.all [ expectValue Nothing, expectFlags { complete = False, valid = False } ]
        , test "the value changes when the text does, and is known at once" <|
            \_ ->
                Expect.equal [ Ok Nothing, Ok (Just "974760673"), Ok Nothing ]
                    [ after [ typeIn plain "974 760 67" ] orgnr |> Result.map MaskedInput.value
                    , after [ typeIn plain "974 760 67", typeIn plain "974 760 673" ] orgnr |> Result.map MaskedInput.value
                    , after [ typeIn plain "974 760 673", typeIn plain "974 760 67" ] orgnr |> Result.map MaskedInput.value
                    ]
        ]



-- ERRORS


errorTests : Test
errorTests =
    describe "when the field says what is wrong"
        [ test "an unfinished number is not an error while the user types" <|
            \_ ->
                after [ focusIn plain, typeIn plain "974 76" ] orgnr
                    |> expectError plain Nothing
        , test "it is one when the field is left" <|
            \_ ->
                after [ focusIn plain, typeIn plain "974 76", leave plain ] orgnr
                    |> expectError plain (Just "Too short: 5 of 9 digits")
        , test "and when Enter is pressed" <|
            \_ ->
                after [ focusIn plain, typeIn plain "974 76", pressKey plain "Enter" ] orgnr
                    |> expectError plain (Just "Too short: 5 of 9 digits")
        , test "and when the application touches the field" <|
            \_ ->
                after [ typeIn plain "974 76" ] orgnr
                    |> Result.map MaskedInput.touch
                    |> expectError plain (Just "Too short: 5 of 9 digits")
        , test "a wrong check digit is shown at once, because no more typing fixes it" <|
            \_ ->
                after [ focusIn plain, typeIn plain "974 760 674" ] orgnr
                    |> expectError plain (Just "The check digit is wrong")
        , test "a number that is too long is shown at once" <|
            \_ ->
                after [ focusIn plain, typeIn plain "974 760 673 1" ] orgnr
                    |> expectError plain (Just "Too long: 10 of 9 digits")
        , test "the right number has no error" <|
            \_ ->
                after [ focusIn plain, typeIn plain "974 760 673", leave plain ] orgnr
                    |> expectError plain Nothing
        , test "an empty field has no error, also when it was left" <|
            \_ ->
                after [ focusIn plain, leave plain ] orgnr
                    |> expectError plain Nothing
        , test "an IBAN of the wrong length says what the length of the country is" <|
            \_ ->
                after [ focusIn [], typeIn [] "NO93 8601 1117", leave [] ] ibanField
                    |> expectError [] (Just "An IBAN from NO has 15 characters (12 entered)")
        , test "an IBAN that is too long says so at once" <|
            \_ ->
                after [ focusIn [], typeIn [] "NO93 8601 1117 9471" ] ibanField
                    |> expectError [] (Just "An IBAN from NO has 15 characters (16 entered)")
        , test "an IBAN with wrong check digits" <|
            \_ ->
                after [ focusIn [], typeIn [] "NO94 8601 1117 947" ] ibanField
                    |> expectError [] (Just "The IBAN check digits are wrong")
        , test "a country that has no IBANs is shown as soon as it is typed" <|
            \_ ->
                after [ focusIn [], typeIn [] "XX" ] ibanField
                    |> expectError [] (Just "XX is not an IBAN country")
        , test "a Norwegian phone number says how many digits it has" <|
            \_ ->
                after [ focusIn [], typeIn [] "+47 912 34 56", leave [] ] phoneField
                    |> expectError [] (Just "A number with +47 has 8 digits after the country code (7 entered)")
        , test "a phone number without a country code is told to start with +" <|
            \_ ->
                after [ focusIn [], typeIn [] "912 34 567", leave [] ] phoneField
                    |> expectError [] (Just "Start with + and the country code, like +47")
        , test "a short phone number" <|
            \_ ->
                after [ focusIn [], typeIn [] "+358 40 1", leave [] ] phoneField
                    |> expectError [] (Just "Too short: 6 of at least 7 digits")
        , test "fixing the text makes the error go" <|
            \_ ->
                after [ focusIn plain, typeIn plain "974 760 674", typeIn plain "974 760 673" ] orgnr
                    |> expectError plain Nothing
        , test "the error of the application is shown when the field has none of its own" <|
            \_ ->
                let
                    attributes =
                        MaskedInput.error "Already registered" :: plain
                in
                after [ focusIn attributes, typeIn attributes "974 760 673", leave attributes ] orgnr
                    |> expectError attributes (Just "Already registered")
        , test "and the error of the field wins over it until it is fixed" <|
            \_ ->
                let
                    attributes =
                        MaskedInput.error "Already registered" :: plain
                in
                after [ focusIn attributes, typeIn attributes "974 760 674" ] orgnr
                    |> expectError attributes (Just "The check digit is wrong")
        , test "errorMaybe Nothing shows no error" <|
            \_ ->
                let
                    attributes =
                        MaskedInput.errorMaybe Nothing :: plain
                in
                after [ typeIn attributes "974 760 673" ] orgnr
                    |> expectError attributes Nothing
        ]



-- LANGUAGE


languageTests : Test
languageTests =
    describe "in Norwegian"
        [ test "too short" <|
            \_ ->
                after [ typeIn norwegian "974 76", leave norwegian ] orgnr
                    |> expectError norwegian (Just "For kort: 5 av 9 siffer")
        , test "too long" <|
            \_ ->
                after [ typeIn norwegian "974 760 673 1" ] orgnr
                    |> expectError norwegian (Just "For lang: 10 av 9 siffer")
        , test "the check digit" <|
            \_ ->
                after [ typeIn norwegian "974 760 674" ] orgnr
                    |> expectError norwegian (Just "Kontrollsifferet er feil")
        , test "the IBAN" <|
            \_ ->
                Expect.all
                    [ \_ -> after [ typeIn norwegian "NO93 8601 1117", leave norwegian ] ibanField |> expectError norwegian (Just "Et IBAN-nummer fra NO har 15 tegn (12 skrevet)")
                    , \_ -> after [ typeIn norwegian "NO94 8601 1117 947" ] ibanField |> expectError norwegian (Just "IBAN-kontrollsifrene er feil")
                    , \_ -> after [ typeIn norwegian "XX" ] ibanField |> expectError norwegian (Just "XX er ikke et IBAN-land")
                    ]
                    ()
        , test "the phone number" <|
            \_ ->
                Expect.all
                    [ \_ -> after [ typeIn norwegian "912 34 567", leave norwegian ] phoneField |> expectError norwegian (Just "Start med + og landkode, for eksempel +47")
                    , \_ -> after [ typeIn norwegian "+47 912 34 56", leave norwegian ] phoneField |> expectError norwegian (Just "Et nummer med +47 har 8 siffer etter landkoden (7 skrevet)")
                    ]
                    ()
        , test "a character that does not belong" <|
            \_ ->
                after [ typeIn norwegian "974x" ] orgnr
                    |> expectError norwegian (Just "«x» er ikke tillatt her: forventet et siffer")
        , test "and in English" <|
            \_ ->
                after [ typeIn plain "974x" ] orgnr
                    |> expectError plain (Just "“x” is not allowed here: expected a digit")
        ]



-- EDITS IN THE MIDDLE


middleEditTests : Test
middleEditTests =
    describe "an edit in the middle of the text"
        [ test "is kept exactly as typed" <|
            \_ ->
                after [ typeIn plain "974 760 673", typeAt plain 3 "9 8974 760 673" ] orgnr
                    |> expectText "9 8974 760 673"
        , test "and the input shows it" <|
            \_ ->
                after [ typeIn plain "974 760 673", typeAt plain 3 "9 8974 760 673" ] orgnr
                    |> expectShown plain "9 8974 760 673"
        , test "the value is still known, from the characters" <|
            \_ ->
                after [ typeIn plain "974 760 673", typeAt plain 3 "97 4 760 673" ] orgnr
                    |> expectValue (Just "974760673")
        , test "a character replaced in the middle, which leaves the groups as they were, is the same text" <|
            \_ ->
                after [ typeIn plain "974 760 673", typeAt plain 6 "974 750 673" ] orgnr
                    |> expectText "974 750 673"
        , test "is written in groups when the user goes on typing at the end" <|
            \_ ->
                after [ typeIn plain "974 760 673", typeAt plain 3 "97 4 760 673", typeIn plain "97 4 760 673" ] orgnr
                    |> expectText "974 760 673"
        , test "a character deleted in the middle is kept as it is" <|
            \_ ->
                after [ typeIn plain "974 760 673", typeAt plain 5 "974 60 673" ] orgnr
                    |> expectText "974 60 673"
        , test "is written in groups when the field is left" <|
            \_ ->
                after [ focusIn plain, typeIn plain "974 760 673", typeAt plain 5 "974 60 673", leave plain ] orgnr
                    |> expectText "974 606 73"
        , test "and when Enter is pressed" <|
            \_ ->
                after [ focusIn plain, typeIn plain "974 760 673", typeAt plain 5 "974 60 673", pressKey plain "Enter" ] orgnr
                    |> expectText "974 606 73"
        , test "an event without the position of the caret counts as an edit at the end" <|
            \_ ->
                after [ event plain (Event.input "974760673") ] orgnr
                    |> expectText "974 760 673"
        ]



-- A CHARACTER THAT DOES NOT BELONG


wrongCharacterTests : Test
wrongCharacterTests =
    describe "a character that does not belong"
        [ test "is not dropped: the field shows the text as typed" <|
            \_ ->
                after [ typeIn plain "97476067x" ] orgnr
                    |> Expect.all [ expectText "97476067x", expectShown plain "97476067x" ]
        , test "and says so at once" <|
            \_ ->
                after [ focusIn plain, typeIn plain "97476067x" ] orgnr
                    |> expectError plain (Just "“x” is not allowed here: expected a digit")
        , test "the text is not written in groups while it is there, wherever the caret is" <|
            \_ ->
                Expect.equal [ Ok "9747x6067 3", Ok "9747x6067 3" ]
                    [ after [ typeAt plain 3 "9747x6067 3" ] orgnr |> Result.map MaskedInput.text
                    , after [ typeIn plain "9747x6067 3" ] orgnr |> Result.map MaskedInput.text
                    ]
        , test "there is no value, and the field is not valid" <|
            \_ ->
                after [ typeIn plain "974 760 67x" ] orgnr
                    |> Expect.all [ expectValue Nothing, expectFlags { complete = False, valid = False } ]
        , test "it stays after the field is left" <|
            \_ ->
                after [ focusIn plain, typeIn plain "974 760 67x", leave plain ] orgnr
                    |> Expect.all [ expectText "974 760 67x", expectError plain (Just "“x” is not allowed here: expected a digit") ]
        , test "deleting it makes the text come back in groups" <|
            \_ ->
                after [ typeIn plain "974 760 67x", typeIn plain "974 760 67" ] orgnr
                    |> expectText "974 760 67"
        , test "a letter in a field for digits, a digit where the IBAN has its country" <|
            \_ ->
                Expect.all
                    [ \_ -> after [ typeIn [] "1O93" ] ibanField |> expectError [] (Just "“1” is not allowed here: expected a letter")
                    , \_ -> after [ typeIn [] "NOA3" ] ibanField |> expectError [] (Just "“A” is not allowed here: expected a digit")
                    , \_ -> after [ typeIn [] "+0" ] phoneField |> expectError [] (Just "“0” is not allowed here: expected a digit from 1 to 9 (a country code does not start with 0)")
                    ]
                    ()
        , test "a letter that is not A to Z" <|
            \_ ->
                after [ typeIn [] "NØ93" ] ibanField
                    |> Expect.all [ expectText "NØ93", expectValue Nothing ]
        , test "pasting text with letters into a field for digits shows it all" <|
            \_ ->
                after [ typeIn plain "org. 974760673" ] orgnr
                    |> Expect.all [ expectText "org. 974760673", expectValue Nothing ]
        ]



-- LEAVING


leavingTests : Test
leavingTests =
    describe "leaving the field"
        [ test "touches it" <|
            \_ ->
                Expect.equal [ Ok False, Ok True ]
                    [ after [ focusIn plain, typeIn plain "974" ] orgnr |> Result.map MaskedInput.isTouched
                    , after [ focusIn plain, typeIn plain "974", leave plain ] orgnr |> Result.map MaskedInput.isTouched
                    ]
        , test "even when nothing was typed" <|
            \_ ->
                after [ focusIn plain, leave plain ] orgnr
                    |> Result.map MaskedInput.isTouched
                    |> Expect.equal (Ok True)
        , test "Enter touches it too" <|
            \_ ->
                after [ pressKey plain "Enter" ] orgnr
                    |> Result.map MaskedInput.isTouched
                    |> Expect.equal (Ok True)
        , test "other keys are not taken" <|
            \_ ->
                after [ pressKey plain "a" ] orgnr
                    |> Expect.err
        , test "a disabled or read-only field does not react to Enter" <|
            \_ ->
                Expect.all
                    [ \_ -> after [ pressKey (MaskedInput.disabled True :: plain) "Enter" ] orgnr |> Expect.err
                    , \_ -> after [ pressKey (MaskedInput.readOnly True :: plain) "Enter" ] orgnr |> Expect.err
                    ]
                    ()
        ]



-- THE STATE


stateTests : Test
stateTests =
    describe "the state"
        [ test "a new field is empty, untouched and valid" <|
            \_ ->
                Expect.equal
                    { value = Nothing, text = "", touched = False, valid = True, complete = False }
                    { value = MaskedInput.value orgnr, text = MaskedInput.text orgnr, touched = MaskedInput.isTouched orgnr, valid = MaskedInput.isValid orgnr, complete = MaskedInput.isComplete orgnr }
        , test "setValue shows an identifier in its groups, from a server or as a person wrote it" <|
            \_ ->
                Expect.equal [ "NO93 8601 1117 947", "NO93 8601 1117 947", "974 760 673" ]
                    [ MaskedInput.setValue (Just "NO9386011117947") ibanField |> MaskedInput.text
                    , MaskedInput.setValue (Just "no93 8601-1117.947") ibanField |> MaskedInput.text
                    , MaskedInput.setValue (Just "974760673") orgnr |> MaskedInput.text
                    ]
        , test "setValue with a valid identifier gives the value" <|
            \_ ->
                MaskedInput.setValue (Just "974760673") orgnr
                    |> MaskedInput.value
                    |> Expect.equal (Just "974760673")
        , test "setValue drops nothing: a value with a bad character is shown as it is" <|
            \_ ->
                MaskedInput.setValue (Just "97476067x") orgnr
                    |> Expect.all
                        [ \state -> Expect.equal "97476067x" (MaskedInput.text state)
                        , \state -> Expect.equal Nothing (MaskedInput.value state)
                        , \state -> Expect.equal False (MaskedInput.isValid state)
                        ]
        , test "setValue Nothing empties the field" <|
            \_ ->
                MaskedInput.setValue (Just "974760673") orgnr
                    |> MaskedInput.setValue Nothing
                    |> MaskedInput.text
                    |> Expect.equal ""
        , test "setValue does not touch the field" <|
            \_ ->
                MaskedInput.setValue (Just "974760674") orgnr
                    |> MaskedInput.isTouched
                    |> Expect.equal False
        , test "a value with a wrong check digit that was set shows its error once the field is touched" <|
            \_ ->
                Ok (MaskedInput.setValue (Just "974760674") orgnr |> MaskedInput.touch)
                    |> expectError plain (Just "The check digit is wrong")
        , test "reset empties the field and forgets the visit" <|
            \_ ->
                after [ focusIn plain, typeIn plain "974 760 673", leave plain ] orgnr
                    |> Result.map MaskedInput.reset
                    |> Result.map (\state -> ( MaskedInput.text state, MaskedInput.isTouched state ))
                    |> Expect.equal (Ok ( "", False ))
        , test "touch counts the field as visited" <|
            \_ ->
                MaskedInput.touch orgnr
                    |> MaskedInput.isTouched
                    |> Expect.equal True
        ]



-- THE DRAWN FIELD


renderTests : Test
renderTests =
    describe "the drawn field"
        [ test "the input has the id given to init, and a label that points at it" <|
            \_ ->
                viewOf plain orgnr
                    |> Expect.all
                        [ Query.find inputOf >> Query.has [ Selector.id "orgnr" ]
                        , Query.find [ Selector.tag "label" ] >> Query.has [ Selector.attribute (Attr.for "orgnr"), Selector.text "Organisation number" ]
                        ]
        , test "the ids that aria-describedby names exist" <|
            \_ ->
                let
                    attributes =
                        [ MaskedInput.label "Organisation number", MaskedInput.hint "Nine digits." ]
                in
                after [ focusIn attributes, typeIn attributes "974 760 674" ] orgnr
                    |> Result.map
                        (\state ->
                            viewOf attributes state
                                |> Expect.all
                                    [ Query.find inputOf >> Query.has [ Selector.attribute (Attr.attribute "aria-describedby" "orgnr-hint orgnr-error") ]
                                    , Query.find [ Selector.id "orgnr-hint" ] >> Query.has [ Selector.text "Nine digits." ]
                                    , Query.find [ Selector.id "orgnr-error" ] >> Query.has [ Selector.text "The check digit is wrong" ]
                                    , Query.find inputOf >> Query.has [ Selector.attribute (Attr.attribute "aria-invalid" "true") ]
                                    ]
                        )
                    |> Result.withDefault (Expect.fail "the steps failed")
        , test "an error is announced, a field without one is not marked invalid" <|
            \_ ->
                Expect.all
                    [ \_ -> viewOf plain orgnr |> Query.find inputOf |> Query.hasNot [ Selector.attribute (Attr.attribute "aria-invalid" "true") ]
                    , \_ -> after [ typeIn plain "974x" ] orgnr |> Result.map (\state -> viewOf plain state |> Query.find [ Selector.class "klar-field__error" ] |> Query.has [ Selector.attribute (Attr.attribute "role" "alert") ]) |> Result.withDefault (Expect.fail "the steps failed")
                    ]
                    ()
        , test "a required field says so to assistive technology" <|
            \_ ->
                viewOf (MaskedInput.required :: plain) orgnr
                    |> Query.find inputOf
                    |> Query.has [ Selector.attribute (Attr.attribute "aria-required" "true") ]
        , test "a text input that the browser does not capitalise, correct, spell check or fill in, always left to right" <|
            \_ ->
                viewOf plain orgnr
                    |> Query.find inputOf
                    |> Query.has
                        [ Selector.attribute (Attr.type_ "text")
                        , Selector.attribute (Attr.attribute "autocapitalize" "off")
                        , Selector.attribute (Attr.attribute "autocorrect" "off")
                        , Selector.attribute (Attr.attribute "spellcheck" "false")
                        , Selector.attribute (Attr.attribute "autocomplete" "off")
                        , Selector.attribute (Attr.attribute "dir" "ltr")
                        ]
        , test "the keyboard and the autocomplete token that suit the mask" <|
            \_ ->
                let
                    attributesOf mask =
                        viewOf [] (MaskedInput.init "x" mask) |> Query.find inputOf

                    postal =
                        MaskedInput.postalCode "SE" |> Maybe.withDefault MaskedInput.norwegianPostalCode

                    sku =
                        MaskedInput.pattern "@@-####" |> Maybe.withDefault MaskedInput.iban
                in
                Expect.all
                    [ \_ -> attributesOf MaskedInput.norwegianOrganisationNumber |> Query.has [ Selector.attribute (Attr.attribute "inputmode" "numeric"), Selector.attribute (Attr.attribute "autocomplete" "off") ]
                    , \_ -> attributesOf MaskedInput.norwegianBankAccount |> Query.has [ Selector.attribute (Attr.attribute "inputmode" "numeric") ]
                    , \_ -> attributesOf postal |> Query.has [ Selector.attribute (Attr.attribute "inputmode" "numeric"), Selector.attribute (Attr.attribute "autocomplete" "postal-code") ]
                    , \_ -> attributesOf MaskedInput.norwegianPostalCode |> Query.has [ Selector.attribute (Attr.attribute "autocomplete" "postal-code") ]
                    , \_ -> attributesOf MaskedInput.phone |> Query.has [ Selector.attribute (Attr.attribute "inputmode" "tel"), Selector.attribute (Attr.attribute "autocomplete" "tel") ]
                    , \_ -> attributesOf MaskedInput.iban |> Query.hasNot [ Selector.attribute (Attr.attribute "inputmode" "numeric") ]
                    , \_ -> attributesOf sku |> Query.hasNot [ Selector.attribute (Attr.attribute "inputmode" "numeric") ]
                    ]
                    ()
        , test "the placeholder shows the shape of the identifier" <|
            \_ ->
                Expect.all
                    [ \_ -> viewOf plain orgnr |> Query.find inputOf |> Query.has [ Selector.attribute (Attr.placeholder "000 000 000") ]
                    , \_ -> viewOf plain ibanField |> Query.find inputOf |> Query.has [ Selector.attribute (Attr.placeholder "NO00 0000 0000 000") ]
                    , \_ -> viewOf plain phoneField |> Query.find inputOf |> Query.has [ Selector.attribute (Attr.placeholder "+47 000 00 000") ]
                    , \_ -> viewOf (MaskedInput.placeholder "9 digits" :: plain) orgnr |> Query.find inputOf |> Query.has [ Selector.attribute (Attr.placeholder "9 digits") ]
                    ]
                    ()
        , test "a counter shows how far the user has come, and is hidden from screen readers" <|
            \_ ->
                after [ typeIn plain "974 76" ] orgnr
                    |> Result.map
                        (\state ->
                            viewOf plain state
                                |> Query.find [ Selector.class "klar-input__counter" ]
                                |> Query.has [ Selector.text "5/9", Selector.attribute (Attr.attribute "aria-hidden" "true") ]
                        )
                    |> Result.withDefault (Expect.fail "the steps failed")
        , test "the counter of an IBAN waits for the country, and then counts to its length" <|
            \_ ->
                Expect.all
                    [ \_ -> after [ typeIn [] "N" ] ibanField |> Result.map (\state -> viewOf [] state |> Query.hasNot [ Selector.class "klar-input__counter" ]) |> Result.withDefault (Expect.fail "the steps failed")
                    , \_ -> after [ typeIn [] "NO93 86" ] ibanField |> Result.map (\state -> viewOf [] state |> Query.find [ Selector.class "klar-input__counter" ] |> Query.has [ Selector.text "6/15" ]) |> Result.withDefault (Expect.fail "the steps failed")
                    ]
                    ()
        , test "an empty field has no counter" <|
            \_ ->
                viewOf plain orgnr |> Query.hasNot [ Selector.class "klar-input__counter" ]
        , test "disabled and read-only reach the input and the box" <|
            \_ ->
                Expect.all
                    [ \_ -> viewOf (MaskedInput.disabled True :: plain) orgnr |> Query.find inputOf |> Query.has [ Selector.disabled True ]
                    , \_ -> viewOf (MaskedInput.disabled True :: plain) orgnr |> Query.has [ Selector.class "klar-input--disabled" ]
                    , \_ -> viewOf (MaskedInput.readOnly True :: plain) orgnr |> Query.find inputOf |> Query.has [ Selector.attribute (Attr.readonly True) ]
                    , \_ -> viewOf (MaskedInput.readOnly True :: plain) orgnr |> Query.has [ Selector.class "klar-input--readonly" ]
                    ]
                    ()
        , test "the size and the name" <|
            \_ ->
                Expect.all
                    [ \_ -> viewOf (MaskedInput.size Theme.Small :: plain) orgnr |> Query.has [ Selector.class "klar-input--sm" ]
                    , \_ -> viewOf plain orgnr |> Query.has [ Selector.class "klar-input--md" ]
                    , \_ -> viewOf (MaskedInput.name "orgnr" :: plain) orgnr |> Query.find inputOf |> Query.has [ Selector.attribute (Attr.name "orgnr") ]
                    ]
                    ()
        , test "the field is inside its wrapper also with nothing to draw, so it keeps the focus when an error comes" <|
            \_ ->
                viewOf [] orgnr
                    |> Query.has [ Selector.class "klar-field", Selector.containing [ Selector.tag "input" ] ]
        , test "the optional text and the hidden label reach the label" <|
            \_ ->
                viewOf [ MaskedInput.label "Organisation number", MaskedInput.optionalText "(optional)", MaskedInput.labelHidden ] orgnr
                    |> Query.find [ Selector.tag "label" ]
                    |> Query.has [ Selector.class "klar-sr-only", Selector.text "(optional)" ]
        ]
