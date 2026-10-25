module MoneyInputTest exposing (suite)

{-| `Klar.MoneyInput`: the field for an amount in one currency.

A test draws the field, finds the input the way a user would, simulates the event,
takes the message that the input sends and gives it to `update`, as the application
would. The text the input shows and the messages it draws are read from the drawn
field.

-}

import Expect exposing (Expectation)
import Html.Attributes as Attr
import Json.Encode as Encode exposing (Value)
import Klar.Locale as Locale exposing (Locale)
import Klar.Money as Money exposing (Currency, Money)
import Klar.MoneyInput as MoneyInput
import Test exposing (Test, describe, test)
import Test.Html.Event as Event
import Test.Html.Query as Query
import Test.Html.Selector as Selector exposing (Selector)


type Msg
    = Input MoneyInput.Msg


suite : Test
suite =
    describe "Klar.MoneyInput"
        [ typingTests
        , writingOnLeavingTests
        , decimalsTests
        , notAnAmountTests
        , limitTests
        , negativeTests
        , pastingTests
        , stateTests
        , currencyTests
        , languageTests
        , renderTests
        , sharedRuleTests
        ]


{-| The rules every stateful input follows: what the user types wins over
`setValue`, the text and the message can be read, an IME composition is left alone,
and Norwegian `10.000` is not quietly ten.
-}
sharedRuleTests : Test
sharedRuleTests =
    describe "the rules of every input"
        [ test "setValue while the user is typing keeps their text and its amount" <|
            \_ ->
                after (typing price "12") fresh
                    |> Result.map (MoneyInput.setValue (Just (nok 99900)))
                    |> Result.map (\state -> ( MoneyInput.text Locale.en state, MoneyInput.value state |> Maybe.map Money.toMinor ))
                    |> Expect.equal (Ok ( "12", Just 1200 ))
        , test "clear and then setValue replace the text while the user is still typing" <|
            \_ ->
                after (typing price "12") fresh
                    |> Result.map (MoneyInput.clear >> MoneyInput.setValue (Just (nok 99900)))
                    |> Result.map (\state -> ( MoneyInput.text Locale.en state, MoneyInput.value state |> Maybe.map Money.toMinor ))
                    |> Expect.equal (Ok ( "999.00", Just 99900 ))
        , test "setValue after the user has left the field shows the new amount" <|
            \_ ->
                after (typedAndLeft price "12") fresh
                    |> Result.map (MoneyInput.setValue (Just (nok 99900)))
                    |> expectValue (Just 99900)
        , test "setValue in a field that has the focus but no typing yet shows the new amount" <|
            \_ ->
                after [ focusIn price ] fresh
                    |> Result.map (MoneyInput.setValue (Just (nok 99900)))
                    |> expectValue (Just 99900)
        , test "text is the written amount in the language" <|
            \_ ->
                fresh
                    |> MoneyInput.setValue (Just (nok 123450))
                    |> MoneyInput.text Locale.nb
                    |> Expect.equal ("1" ++ nbsp ++ "234,50")
        , test "text keeps text that is not an amount as it was typed" <|
            \_ ->
                after (typedAndLeft price "12,3,4") fresh
                    |> Result.map (MoneyInput.text Locale.en)
                    |> Expect.equal (Ok "12,3,4")
        , test "problem is the message the field shows" <|
            \_ ->
                after (typedAndLeft limited "1") fresh
                    |> Result.map (MoneyInput.problem limited)
                    |> Expect.equal (Ok (Just ("Must be between 10.00 and 5,000.00" ++ nbsp ++ "NOK")))
        , test "problem judges by the limits it is given, also for an amount the application put in" <|
            \_ ->
                fresh
                    |> MoneyInput.setValue (Just (nok -500))
                    |> MoneyInput.problem price
                    |> Expect.equal (Just "Must not be negative")
        , test "problem is Nothing for a good amount" <|
            \_ ->
                after (typedAndLeft limited "100") fresh
                    |> Result.map (MoneyInput.problem limited)
                    |> Expect.equal (Ok Nothing)
        , test "clear empties the field and forgets the visit" <|
            \_ ->
                after (typedAndLeft price "12") fresh
                    |> Result.map MoneyInput.clear
                    |> Result.map (\state -> ( MoneyInput.value state, MoneyInput.isTouched state ))
                    |> Expect.equal (Ok ( Nothing, False ))
        , test "the Enter that ends an IME composition does not write the amount" <|
            \_ ->
                after (typing price "12") fresh
                    |> Result.andThen
                        (event price
                            inputOf
                            (Event.custom "keydown"
                                (Encode.object
                                    [ ( "key", Encode.string "Enter" )
                                    , ( "isComposing", Encode.bool True )
                                    , ( "ctrlKey", Encode.bool False )
                                    , ( "metaKey", Encode.bool False )
                                    , ( "shiftKey", Encode.bool False )
                                    , ( "altKey", Encode.bool False )
                                    ]
                                )
                            )
                        )
                    |> Expect.err
        , test "Norwegian 10.000 is refused as unclear when the field is left, not read as ten" <|
            \_ ->
                after (typedAndLeft norwegian "10.000") fresh
                    |> Expect.all
                        [ expectValue Nothing
                        , expectError norwegian (Just ("Uklart skilletegn: skriv tusener som 10" ++ nbsp ++ "000 og desimaler som 10,50"))
                        ]
        , test "Norwegian 10.5 is still ten and a half" <|
            \_ ->
                after (typedAndLeft norwegian "10.5") fresh
                    |> expectValue (Just 1050)
        , test "setCurrency reads in the language that setLimits gave" <|
            \_ ->
                fresh
                    |> MoneyInput.setLimits norwegian
                    |> MoneyInput.setValue (Just (nok 10050))
                    |> MoneyInput.setCurrency Money.jpy
                    |> MoneyInput.text Locale.nb
                    |> Expect.equal "100,50"
        ]



-- HELPERS


nbsp : String
nbsp =
    "\u{00A0}"


type alias Step =
    MoneyInput.State -> Result String MoneyInput.State


type alias Attributes =
    List (MoneyInput.Attribute Msg)


kwd : Currency
kwd =
    Money.currency "KWD" |> Maybe.withDefault Money.nok


fresh : MoneyInput.State
fresh =
    MoneyInput.init "price" Money.nok


nok : Int -> Money
nok minor =
    Money.fromMinor Money.nok minor |> Maybe.withDefault (Money.zero Money.nok)


viewOf : Attributes -> MoneyInput.State -> Query.Single Msg
viewOf attributes state =
    MoneyInput.view Input attributes state |> Query.fromHtml


event : Attributes -> List Selector -> ( String, Value ) -> Step
event attributes selectors simulated state =
    viewOf attributes state
        |> Query.find selectors
        |> Event.simulate simulated
        |> Event.toResult
        |> Result.map (\(Input inner) -> Tuple.first (MoneyInput.update inner state))


inputOf : List Selector
inputOf =
    [ Selector.tag "input" ]


typeIn : Attributes -> String -> Step
typeIn attributes text =
    event attributes inputOf (Event.input text)


focusIn : Attributes -> Step
focusIn attributes =
    event attributes inputOf Event.focus


leave : Attributes -> Step
leave attributes =
    event attributes inputOf Event.blur


pressKey : Attributes -> String -> Step
pressKey attributes key =
    event attributes
        inputOf
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


after : List Step -> MoneyInput.State -> Result String MoneyInput.State
after steps state =
    List.foldl (\step result -> Result.andThen step result) (Ok state) steps


{-| Types, as a user does: focus, then the text.
-}
typing : Attributes -> String -> List Step
typing attributes text =
    [ focusIn attributes, typeIn attributes text ]


{-| Types a text and leaves the field.
-}
typedAndLeft : Attributes -> String -> List Step
typedAndLeft attributes text =
    typing attributes text ++ [ leave attributes ]


expectValue : Maybe Int -> Result String MoneyInput.State -> Expectation
expectValue expected result =
    case result of
        Ok state ->
            Expect.equal expected (MoneyInput.value state |> Maybe.map Money.toMinor)

        Err problem ->
            Expect.fail problem


expectValid : Bool -> Result String MoneyInput.State -> Expectation
expectValid expected result =
    case result of
        Ok state ->
            Expect.equal expected (MoneyInput.isValid state)

        Err problem ->
            Expect.fail problem


{-| What the input shows.
-}
expectShown : Attributes -> String -> Result String MoneyInput.State -> Expectation
expectShown attributes text result =
    case result of
        Ok state ->
            viewOf attributes state
                |> Query.find inputOf
                |> Query.has [ Selector.attribute (Attr.value text) ]

        Err problem ->
            Expect.fail problem


{-| The error the field draws, if any.
-}
expectError : Attributes -> Maybe String -> Result String MoneyInput.State -> Expectation
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


price : Attributes
price =
    [ MoneyInput.label "Price" ]


limited : Attributes
limited =
    [ MoneyInput.label "Price", MoneyInput.min (nok 1000), MoneyInput.max (nok 500000) ]


norwegian : Attributes
norwegian =
    [ MoneyInput.label "Pris", MoneyInput.locale Locale.nb ]



-- TYPING


typingTests : Test
typingTests =
    describe "typing"
        [ test "what is typed is kept as typed while the field has the focus" <|
            \_ ->
                after (typing price "1234,5") fresh
                    |> Expect.all [ expectShown price "1234,5", expectValue (Just 123450) ]
        , test "the amount is known from the first keystroke" <|
            \_ ->
                after (typing price "12") fresh
                    |> expectValue (Just 1200)
        , test "an empty field has no amount, and is valid" <|
            \_ ->
                after (typing price "12" ++ [ typeIn price "" ]) fresh
                    |> Expect.all [ expectValue Nothing, expectValid True, expectError price Nothing ]
        , test "a point and a comma are both a decimal separator" <|
            \_ ->
                Expect.equal [ Ok (Just 123450), Ok (Just 123450) ]
                    [ after (typing price "1234.50") fresh |> Result.map (MoneyInput.value >> Maybe.map Money.toMinor)
                    , after (typing price "1234,50") fresh |> Result.map (MoneyInput.value >> Maybe.map Money.toMinor)
                    ]
        , test "English reads 1,234 as one thousand two hundred and thirty-four" <|
            \_ ->
                after (typing [ MoneyInput.locale Locale.en ] "1,234") fresh
                    |> expectValue (Just 123400)
        , test "Norwegian reads 1,234 as one and 234 thousandths, which NOK does not have" <|
            \_ ->
                after (typing norwegian "1,234") fresh
                    |> Expect.all [ expectValue Nothing, expectValid False ]
        ]



-- WRITING THE AMOUNT WHEN THE FIELD IS LEFT


writingOnLeavingTests : Test
writingOnLeavingTests =
    describe "when the field is left"
        [ test "the amount is written with the grouping and the decimals of the currency, in English" <|
            \_ ->
                after (typedAndLeft price "1234.5") fresh
                    |> Expect.all [ expectShown price "1,234.50", expectValue (Just 123450), expectValid True ]
        , test "and in Norwegian, with a no-break space between the thousands" <|
            \_ ->
                after (typedAndLeft norwegian "1234,5") fresh
                    |> expectShown norwegian ("1" ++ nbsp ++ "234,50")
        , test "a whole number gets its decimals" <|
            \_ ->
                after (typedAndLeft price "7") fresh
                    |> expectShown price "7.00"
        , test "trailing zeros beyond the decimals change nothing and are written away" <|
            \_ ->
                after (typedAndLeft price "12.500") fresh
                    |> Expect.all [ expectShown price "12.50", expectValue (Just 1250), expectValid True ]
        , test "a currency without decimals is written without" <|
            \_ ->
                after (typedAndLeft price "1500") (MoneyInput.init "price" Money.jpy)
                    |> expectShown price "1,500"
        , test "a currency with three decimals is written with three" <|
            \_ ->
                after (typedAndLeft price "1234.5") (MoneyInput.init "price" kwd)
                    |> Expect.all [ expectShown price "1,234.500", expectValue (Just 1234500) ]
        , test "a negative amount begins with the minus sign of the keyboard" <|
            \_ ->
                after (typedAndLeft (MoneyInput.allowNegative :: price) "(1234,5)") fresh
                    |> expectShown (MoneyInput.allowNegative :: price) "-1,234.50"
        , test "what is written is read again as the same amount" <|
            \_ ->
                after (typedAndLeft norwegian "1 234 567,89" ++ [ focusIn norwegian, typeIn norwegian ("1" ++ nbsp ++ "234" ++ nbsp ++ "567,89") ]) fresh
                    |> expectValue (Just 123456789)
        , test "Enter writes the amount too, and the field is touched" <|
            \_ ->
                after (typing price "1234.5" ++ [ pressKey price "Enter" ]) fresh
                    |> Expect.all
                        [ expectShown price "1,234.50"
                        , \result -> Result.map MoneyInput.isTouched result |> Expect.equal (Ok True)
                        ]
        , test "leaving an empty field leaves it empty" <|
            \_ ->
                after (typedAndLeft price "   ") fresh
                    |> Expect.all [ expectShown price "", expectValue Nothing, expectValid True ]
        , test "leaving a field touches it" <|
            \_ ->
                after [ focusIn price, leave price ] fresh
                    |> Result.map MoneyInput.isTouched
                    |> Expect.equal (Ok True)
        , test "a field that was never visited is not touched" <|
            \_ ->
                after (typing price "5") fresh
                    |> Result.map MoneyInput.isTouched
                    |> Expect.equal (Ok False)
        ]



-- TOO MANY DECIMALS


decimalsTests : Test
decimalsTests =
    describe "more decimals than the currency has"
        [ test "the field says so at once, while the user is still in it" <|
            \_ ->
                after (typing price "12.505") fresh
                    |> expectError price (Just "NOK has 2 decimals")
        , test "the amount is nothing, and the field is invalid" <|
            \_ ->
                after (typing price "12.505") fresh
                    |> Expect.all [ expectValue Nothing, expectValid False ]
        , test "the text is kept as typed, also after leaving: nothing is rounded" <|
            \_ ->
                after (typedAndLeft price "12.505") fresh
                    |> Expect.all [ expectShown price "12.505", expectValue Nothing, expectValid False, expectError price (Just "NOK has 2 decimals") ]
        , test "fixing the text fixes the field" <|
            \_ ->
                after (typing price "12.505" ++ [ typeIn price "12.51" ]) fresh
                    |> Expect.all [ expectValue (Just 1251), expectValid True, expectError price Nothing ]
        , test "a currency without decimals says so" <|
            \_ ->
                after (typing price "1.5") (MoneyInput.init "price" Money.jpy)
                    |> expectError price (Just "JPY has no decimals")
        , test "a currency with three decimals says so" <|
            \_ ->
                after (typing price "1.2345") (MoneyInput.init "price" kwd)
                    |> expectError price (Just "KWD has 3 decimals")
        , test "the message is in the language of the field" <|
            \_ ->
                after (typing norwegian "12,505") fresh
                    |> expectError norwegian (Just "NOK har 2 desimaler")
        , test "in Norwegian a comma before three digits is a decimal comma: the same message" <|
            \_ ->
                after (typing norwegian "1,234") fresh
                    |> expectError norwegian (Just "NOK har 2 desimaler")
        , test "an amount that English reads with a comma for thousands in KWD is refused as unclear" <|
            \_ ->
                after (typedAndLeft [ MoneyInput.locale Locale.en ] "1,234") (MoneyInput.init "price" kwd)
                    |> Expect.all
                        [ expectValue Nothing
                        , expectValid False
                        , expectError [ MoneyInput.locale Locale.en ] (Just "The separators are unclear: write the amount with one decimal separator")
                        ]
        ]



-- TEXT THAT IS NOT AN AMOUNT


notAnAmountTests : Test
notAnAmountTests =
    describe "text that is not an amount"
        [ test "letters are reported at once" <|
            \_ ->
                after (typing price "abc") fresh
                    |> Expect.all [ expectError price (Just "Must be an amount"), expectValid False, expectValue Nothing ]
        , test "the symbol of another currency is reported at once" <|
            \_ ->
                after (typing price "$100") fresh
                    |> expectError price (Just "Must be an amount")
        , test "a minus sign that has no number yet is not an error while typing, but invalid" <|
            \_ ->
                after (typing price "-") fresh
                    |> Expect.all [ expectError price Nothing, expectValid False ]
        , test "it is an error once the field is left" <|
            \_ ->
                after (typedAndLeft price "-") fresh
                    |> Expect.all [ expectError price (Just "Must be an amount"), expectShown price "-" ]
        , test "separators that cannot be read wait until the field is left" <|
            \_ ->
                Expect.all
                    [ \_ -> after (typing price "1.2.3") fresh |> expectError price Nothing
                    , \_ -> after (typedAndLeft price "1.2.3") fresh |> expectError price (Just "The separators are unclear: write the amount with one decimal separator")
                    ]
                    ()
        , test "the marks that are read around an amount are not errors while they are typed: the code, the symbol and the other ways of writing it" <|
            \_ ->
                let
                    inCurrency code text =
                        case Money.currency code of
                            Just cur ->
                                after (typing price text) (MoneyInput.init "price" cur)

                            Nothing ->
                                Err "no such currency"
                in
                Expect.all
                    [ \_ -> inCurrency "CNY" "RM" |> expectError price Nothing
                    , \_ -> inCurrency "CNY" "RMB" |> expectError price Nothing
                    , \_ -> inCurrency "CNY" "RMB 100" |> Expect.all [ expectError price Nothing, expectValue (Just 10000) ]
                    , \_ -> inCurrency "CNY" "元" |> expectError price Nothing
                    , \_ -> inCurrency "CNY" "¥" |> expectError price Nothing
                    , \_ -> inCurrency "JPY" "円" |> expectError price Nothing
                    , \_ -> inCurrency "JPY" "￥1500" |> expectValue (Just 1500)
                    , \_ -> inCurrency "MXN" "Mex" |> expectError price Nothing
                    , \_ -> inCurrency "MXN" "Mex$ 5" |> Expect.all [ expectError price Nothing, expectValue (Just 500) ]
                    , \_ -> inCurrency "NOK" "NK" |> expectError price Nothing
                    , \_ -> inCurrency "NOK" "NKr 5" |> expectValue (Just 500)
                    , \_ -> inCurrency "USD" "US$" |> expectError price Nothing
                    ]
                    ()
        , test "other letters, and the marks of another currency, are errors at once" <|
            \_ ->
                let
                    inCurrency code text =
                        case Money.currency code of
                            Just cur ->
                                after (typing price text) (MoneyInput.init "price" cur)

                            Nothing ->
                                Err "no such currency"
                in
                Expect.all
                    [ \_ -> inCurrency "CNY" "xyz" |> expectError price (Just "Must be an amount")
                    , \_ -> inCurrency "CNY" "$" |> expectError price (Just "Must be an amount")
                    , \_ -> inCurrency "NOK" "€" |> expectError price (Just "Must be an amount")
                    , \_ -> inCurrency "USD" "kr" |> expectError price (Just "Must be an amount")
                    ]
                    ()
        , test "the code of the currency being typed is not an error while typing" <|
            \_ ->
                after (typing price "NO") fresh
                    |> expectError price Nothing
        , test "text that is not an amount is kept as typed" <|
            \_ ->
                after (typedAndLeft price "twelve") fresh
                    |> expectShown price "twelve"
        , test "the message is in Norwegian" <|
            \_ ->
                after (typing norwegian "abc") fresh
                    |> expectError norwegian (Just "Må være et gyldig beløp")
        , test "a message of the application is shown when the field has nothing to say itself" <|
            \_ ->
                after (typedAndLeft (MoneyInput.error "Already invoiced" :: price) "5") fresh
                    |> expectError (MoneyInput.error "Already invoiced" :: price) (Just "Already invoiced")
        , test "and the field's own message wins over it until fixed" <|
            \_ ->
                after (typing (MoneyInput.error "Already invoiced" :: price) "abc") fresh
                    |> expectError (MoneyInput.error "Already invoiced" :: price) (Just "Must be an amount")
        ]



-- LIMITS


limitTests : Test
limitTests =
    describe "min and max"
        [ test "an amount below the minimum is invalid from the first keystroke" <|
            \_ ->
                after (typing limited "5") fresh
                    |> expectValid False
        , test "an amount above the maximum is invalid from the first keystroke" <|
            \_ ->
                after (typing limited "6000") fresh
                    |> expectValid False
        , test "the limits themselves are valid" <|
            \_ ->
                Expect.equal [ Ok True, Ok True ]
                    [ after (typing limited "10") fresh |> Result.map MoneyInput.isValid
                    , after (typing limited "5000") fresh |> Result.map MoneyInput.isValid
                    ]
        , test "just outside the limits is invalid" <|
            \_ ->
                Expect.equal [ Ok False, Ok False ]
                    [ after (typing limited "9.99") fresh |> Result.map MoneyInput.isValid
                    , after (typing limited "5000.01") fresh |> Result.map MoneyInput.isValid
                    ]
        , test "the message waits while the user types" <|
            \_ ->
                after (typing limited "6000") fresh
                    |> expectError limited Nothing
        , test "after leaving, the amount is kept and the field says what the limits are" <|
            \_ ->
                after (typedAndLeft limited "6000") fresh
                    |> Expect.all
                        [ expectValue (Just 600000)
                        , expectValid False
                        , expectShown limited "6,000.00"
                        , expectError limited (Just ("Must be between 10.00 and 5,000.00" ++ nbsp ++ "NOK"))
                        ]
        , test "an amount outside the limits is never moved into them" <|
            \_ ->
                after (typedAndLeft limited "1") fresh
                    |> expectValue (Just 100)
        , test "only a minimum" <|
            \_ ->
                let
                    attributes =
                        [ MoneyInput.label "Price", MoneyInput.min (nok 1000) ]
                in
                after (typedAndLeft attributes "1") fresh
                    |> expectError attributes (Just ("Must be at least 10.00" ++ nbsp ++ "NOK"))
        , test "the minimum and the maximum in Norwegian" <|
            \_ ->
                let
                    minimum =
                        norwegian ++ [ MoneyInput.min (nok 1000) ]

                    maximum =
                        norwegian ++ [ MoneyInput.max (nok 1000) ]
                in
                Expect.all
                    [ \_ -> after (typedAndLeft minimum "1") fresh |> expectError minimum (Just ("Må være minst 10,00" ++ nbsp ++ "NOK"))
                    , \_ -> after (typedAndLeft maximum "11") fresh |> expectError maximum (Just ("Må være maksimalt 10,00" ++ nbsp ++ "NOK"))
                    ]
                    ()
        , test "only a maximum" <|
            \_ ->
                let
                    attributes =
                        [ MoneyInput.label "Price", MoneyInput.max (nok 1000) ]
                in
                after (typedAndLeft attributes "11") fresh
                    |> expectError attributes (Just ("Must be at most 10.00" ++ nbsp ++ "NOK"))
        , test "the message in Norwegian writes the limits in Norwegian" <|
            \_ ->
                let
                    attributes =
                        norwegian ++ [ MoneyInput.min (nok 1000), MoneyInput.max (nok 500000) ]
                in
                after (typedAndLeft attributes "6000") fresh
                    |> expectError attributes (Just ("Må være mellom 10,00 og 5" ++ nbsp ++ "000,00" ++ nbsp ++ "NOK"))
        , test "limits work in any currency of the field" <|
            \_ ->
                let
                    attributes =
                        [ MoneyInput.label "Price", MoneyInput.max (Money.fromMinor Money.jpy 1000 |> Maybe.withDefault (Money.zero Money.jpy)) ]
                in
                after (typedAndLeft attributes "5") (MoneyInput.init "price" Money.jpy)
                    |> Expect.all [ expectValid True, expectError attributes Nothing ]
        , test "a limit in another currency is a mistake that is shown, and the field is invalid" <|
            \_ ->
                let
                    attributes =
                        [ MoneyInput.label "Price", MoneyInput.max (Money.fromMinor Money.eur 1000 |> Maybe.withDefault (Money.zero Money.eur)) ]
                in
                after (typedAndLeft attributes "5") fresh
                    |> Expect.all
                        [ expectValid False
                        , expectError attributes (Just "The limit is in EUR, but the field is for NOK")
                        , expectValue (Just 500)
                        ]
        , test "an empty field is inside any limits" <|
            \_ ->
                after (typedAndLeft limited "") fresh
                    |> expectValid True
        ]



-- NEGATIVE AMOUNTS


negativeTests : Test
negativeTests =
    describe "negative amounts"
        [ test "are refused by default" <|
            \_ ->
                after (typedAndLeft price "-5") fresh
                    |> Expect.all [ expectValid False, expectValue (Just -500), expectError price (Just "Must not be negative") ]
        , test "are allowed with allowNegative" <|
            \_ ->
                after (typedAndLeft (MoneyInput.allowNegative :: price) "-5") fresh
                    |> Expect.all [ expectValid True, expectValue (Just -500), expectError (MoneyInput.allowNegative :: price) Nothing ]
        , test "parentheses mean negative" <|
            \_ ->
                after (typedAndLeft (MoneyInput.allowNegative :: price) "(5)") fresh
                    |> expectValue (Just -500)
        , test "zero is not negative" <|
            \_ ->
                after (typedAndLeft price "-0") fresh
                    |> Expect.all [ expectValid True, expectValue (Just 0) ]
        , test "the message is in Norwegian" <|
            \_ ->
                after (typedAndLeft norwegian "-5") fresh
                    |> expectError norwegian (Just "Beløpet kan ikke være negativt")
        , test "a negative amount inside a negative range is fine" <|
            \_ ->
                let
                    attributes =
                        [ MoneyInput.allowNegative, MoneyInput.min (nok -1000), MoneyInput.max (nok 1000) ]
                in
                Expect.equal [ Ok True, Ok False ]
                    [ after (typing attributes "-5") fresh |> Result.map MoneyInput.isValid
                    , after (typing attributes "-11") fresh |> Result.map MoneyInput.isValid
                    ]
        ]



-- PASTED TEXT


pastingTests : Test
pastingTests =
    describe "pasted text"
        [ test "with the code of the currency" <|
            \_ ->
                after (typedAndLeft norwegian "NOK 1 234,50") fresh
                    |> Expect.all [ expectValue (Just 123450), expectShown norwegian ("1" ++ nbsp ++ "234,50") ]
        , test "with the symbol, after the amount" <|
            \_ ->
                after (typedAndLeft norwegian "1 234,50 kr") fresh
                    |> expectValue (Just 123450)
        , test "with the Norwegian ending ,-" <|
            \_ ->
                after (typedAndLeft norwegian "1 234,-") fresh
                    |> expectValue (Just 123400)
        , test "with no-break spaces from a web page" <|
            \_ ->
                after (typedAndLeft norwegian ("1" ++ nbsp ++ "234" ++ nbsp ++ "567,00")) fresh
                    |> expectValue (Just 123456700)
        , test "with a real minus sign" <|
            \_ ->
                after (typedAndLeft (MoneyInput.allowNegative :: price) "−12.50") fresh
                    |> expectValue (Just -1250)
        , test "from a spreadsheet, with a symbol and thousands" <|
            \_ ->
                after (typedAndLeft [ MoneyInput.label "Price" ] "$1,234.50") (MoneyInput.init "price" Money.usd)
                    |> Expect.all [ expectValue (Just 123450), expectShown price "1,234.50" ]
        , test "with the symbol of another currency is refused" <|
            \_ ->
                after (typedAndLeft price "€100") fresh
                    |> Expect.all [ expectValue Nothing, expectError price (Just "Must be an amount") ]
        ]



-- STATE


stateTests : Test
stateTests =
    describe "the state"
        [ test "a new field is empty, untouched and valid, in its currency" <|
            \_ ->
                Expect.equal
                    { value = Nothing, touched = False, valid = True, currency = Money.nok }
                    { value = MoneyInput.value fresh, touched = MoneyInput.isTouched fresh, valid = MoneyInput.isValid fresh, currency = MoneyInput.currencyOf fresh }
        , test "setValue shows the amount, written like the field writes it" <|
            \_ ->
                Ok (MoneyInput.setValue (Just (nok 123450)) fresh)
                    |> Expect.all [ expectShown price "1,234.50", expectValue (Just 123450) ]
        , test "setValue throws away text that is not an amount, once the field was left" <|
            \_ ->
                after (typedAndLeft price "abc") fresh
                    |> Result.map (MoneyInput.setValue (Just (nok 500)))
                    |> Expect.all [ expectShown price "5.00", expectError price Nothing, expectValid True ]
        , test "setValue Nothing empties the field and keeps the currency" <|
            \_ ->
                MoneyInput.init "price" Money.jpy
                    |> MoneyInput.setValue Nothing
                    |> MoneyInput.currencyOf
                    |> Expect.equal Money.jpy
        , test "setValue with an amount in another currency makes that the currency of the field" <|
            \_ ->
                fresh
                    |> MoneyInput.setValue (Money.fromMinor Money.eur 500)
                    |> MoneyInput.currencyOf
                    |> Expect.equal Money.eur
        , test "setValue does not move an amount into the limits" <|
            \_ ->
                fresh
                    |> MoneyInput.setLimits limited
                    |> MoneyInput.setValue (Just (nok 600000))
                    |> Expect.all
                        [ \state -> Expect.equal (Just 600000) (MoneyInput.value state |> Maybe.map Money.toMinor)
                        , \state -> Expect.equal False (MoneyInput.isValid state)
                        ]
        , test "without setLimits a loaded amount is judged by the limits the field has seen: none" <|
            \_ ->
                fresh
                    |> MoneyInput.setValue (Just (nok 600000))
                    |> MoneyInput.isValid
                    |> Expect.equal True
        , test "setLimits knows negative amounts too" <|
            \_ ->
                fresh
                    |> MoneyInput.setLimits price
                    |> MoneyInput.setValue (Just (nok -5))
                    |> MoneyInput.isValid
                    |> Expect.equal False
        , test "the limits seen while typing stay until the field sees others" <|
            \_ ->
                after (typedAndLeft limited "20") fresh
                    |> Result.map (MoneyInput.setValue (Just (nok 600000)))
                    |> expectValid False
        , test "clear empties the field and forgets the visit, but keeps the limits and the currency" <|
            \_ ->
                after (typedAndLeft limited "6000") (MoneyInput.init "price" Money.usd)
                    |> Result.map MoneyInput.clear
                    |> Result.map (\state -> ( MoneyInput.value state, MoneyInput.isTouched state, MoneyInput.currencyOf state ))
                    |> Expect.equal (Ok ( Nothing, False, Money.usd ))
        , test "touch counts the field as visited, without changing anything else" <|
            \_ ->
                after (typing price "5") fresh
                    |> Result.map MoneyInput.touch
                    |> Expect.all [ expectValue (Just 500), \result -> Expect.equal (Ok True) (Result.map MoneyInput.isTouched result) ]
        , test "a credit note that is loaded into a field that allows negative amounts is not invalid, before the field has seen anything" <|
            \_ ->
                Expect.equal [ True, True, True ]
                    [ MoneyInput.setValue (Just (nok -500)) fresh |> MoneyInput.isValid
                    , MoneyInput.setLimits [ MoneyInput.allowNegative ] fresh |> MoneyInput.setValue (Just (nok -500)) |> MoneyInput.isValid
                    , MoneyInput.setValue (Just (nok -500)) fresh |> MoneyInput.setLimits [ MoneyInput.allowNegative ] |> MoneyInput.isValid
                    ]
        , test "and the field draws no error for it" <|
            \_ ->
                Ok (MoneyInput.setValue (Just (nok -500)) fresh |> MoneyInput.touch)
                    |> expectError (MoneyInput.allowNegative :: price) Nothing
        , test "once the field is told the limits, the same amount is judged by them" <|
            \_ ->
                Expect.equal [ False, True ]
                    [ MoneyInput.setValue (Just (nok -500)) fresh |> MoneyInput.setLimits price |> MoneyInput.isValid
                    , MoneyInput.setValue (Just (nok -500)) fresh |> MoneyInput.setLimits (MoneyInput.allowNegative :: price) |> MoneyInput.isValid
                    ]
        , test "a loaded amount that is not told the limits is only judged by being an amount" <|
            \_ ->
                Expect.equal [ True, True ]
                    [ MoneyInput.setValue (Just (nok 600000)) fresh |> MoneyInput.isValid
                    , Ok (MoneyInput.setValue (Just (nok 600000)) fresh) |> Result.map MoneyInput.isValid |> Result.withDefault False
                    ]
        , test "the first event tells the field the limits, and then it judges by them" <|
            \_ ->
                after [ focusIn limited ] (MoneyInput.setValue (Just (nok 600000)) fresh)
                    |> expectValid False
        , test "a touched field draws the errors that were waiting" <|
            \_ ->
                after (typing limited "6000") fresh
                    |> Result.map MoneyInput.touch
                    |> expectValid False
        ]



-- CURRENCY


currencyTests : Test
currencyTests =
    describe "setCurrency"
        [ test "the number stays and is read in the new currency" <|
            \_ ->
                Ok (MoneyInput.setValue (Just (nok 10050)) fresh)
                    |> Result.map (MoneyInput.setCurrency Money.usd)
                    |> Expect.all
                        [ expectValue (Just 10050)
                        , \result -> Expect.equal (Ok Money.usd) (Result.map MoneyInput.currencyOf result)
                        , expectShown price "100.50"
                        ]
        , test "into a currency with fewer decimals the amount is not rounded: the field says so" <|
            \_ ->
                Ok (MoneyInput.setValue (Just (nok 10050)) fresh)
                    |> Result.map (MoneyInput.setCurrency Money.jpy)
                    |> Expect.all
                        [ expectValue Nothing
                        , expectValid False
                        , expectShown price "100.50"
                        , expectError price (Just "JPY has no decimals")
                        ]
        , test "a whole amount goes to a currency without decimals" <|
            \_ ->
                Ok (MoneyInput.setValue (Just (nok 10000)) fresh)
                    |> Result.map (MoneyInput.setCurrency Money.jpy)
                    |> Expect.all [ expectValue (Just 100), expectShown price "100" ]
        , test "text being typed is read again in the new currency" <|
            \_ ->
                after (typing price "12.345") (MoneyInput.init "price" kwd)
                    |> Result.map (MoneyInput.setCurrency Money.nok)
                    |> Expect.all [ expectValue Nothing, expectShown price "12.345", expectError price (Just "NOK has 2 decimals") ]
        , test "and a text that was refused is accepted when the new currency allows it" <|
            \_ ->
                after (typing price "12.345") fresh
                    |> Result.map (MoneyInput.setCurrency kwd)
                    |> Expect.all [ expectValue (Just 12345), expectValid True ]
        , test "the same currency changes nothing" <|
            \_ ->
                after (typing price "12.345") fresh
                    |> Result.map (MoneyInput.setCurrency Money.nok)
                    |> Expect.all [ expectValue Nothing, expectShown price "12.345" ]
        , test "an empty field changes its currency" <|
            \_ ->
                Ok (MoneyInput.setCurrency Money.eur fresh)
                    |> Result.map MoneyInput.currencyOf
                    |> Expect.equal (Ok Money.eur)
        ]



-- LANGUAGE


languageTests : Test
languageTests =
    describe "the language"
        [ test "the placeholder shows how the amount is written" <|
            \_ ->
                Expect.all
                    [ \_ -> hasPlaceholder "0.00" price fresh
                    , \_ -> hasPlaceholder "0,00" norwegian fresh
                    , \_ -> hasPlaceholder "0" price (MoneyInput.init "price" Money.jpy)
                    , \_ -> hasPlaceholder "0.000" price (MoneyInput.init "price" kwd)
                    ]
                    ()
        , test "a placeholder of the application replaces it" <|
            \_ -> hasPlaceholder "e.g. 99.00" (MoneyInput.placeholder "e.g. 99.00" :: price) fresh
        ]


hasPlaceholder : String -> Attributes -> MoneyInput.State -> Expectation
hasPlaceholder text attributes state =
    viewOf attributes state
        |> Query.find inputOf
        |> Query.has [ Selector.attribute (Attr.placeholder text) ]



-- THE DRAWN FIELD


renderTests : Test
renderTests =
    describe "the drawn field"
        [ test "the input has the id given to init, a label that points at it, and the currency at the end" <|
            \_ ->
                viewOf price fresh
                    |> Expect.all
                        [ Query.find inputOf >> Query.has [ Selector.id "price" ]
                        , Query.find [ Selector.tag "label" ] >> Query.has [ Selector.attribute (Attr.for "price") ]
                        , Query.find [ Selector.id "price-currency" ] >> Query.has [ Selector.text "NOK" ]
                        ]
        , test "the currency is part of the description of the input" <|
            \_ ->
                viewOf price fresh
                    |> Query.find inputOf
                    |> Query.has [ Selector.attribute (Attr.attribute "aria-describedby" "price-currency") ]
        , test "with a hint and an error the description names all the ids, and they exist" <|
            \_ ->
                let
                    attributes =
                        [ MoneyInput.label "Price", MoneyInput.hint "Excluding VAT." ]
                in
                after (typedAndLeft attributes "x") fresh
                    |> Result.map
                        (\state ->
                            viewOf attributes state
                                |> Expect.all
                                    [ Query.find inputOf >> Query.has [ Selector.attribute (Attr.attribute "aria-describedby" "price-currency price-hint price-error") ]
                                    , Query.find [ Selector.id "price-hint" ] >> Query.has [ Selector.text "Excluding VAT." ]
                                    , Query.find [ Selector.id "price-error" ] >> Query.has [ Selector.text "Must be an amount" ]
                                    , Query.find inputOf >> Query.has [ Selector.attribute (Attr.attribute "aria-invalid" "true") ]
                                    ]
                        )
                    |> Result.withDefault (Expect.fail "the steps failed")
        , test "an input that is fine is not marked invalid" <|
            \_ ->
                viewOf price fresh
                    |> Query.find inputOf
                    |> Query.hasNot [ Selector.attribute (Attr.attribute "aria-invalid" "true") ]
        , test "a required field says so to assistive technology" <|
            \_ ->
                viewOf (MoneyInput.required :: price) fresh
                    |> Query.find inputOf
                    |> Query.has [ Selector.attribute (Attr.attribute "aria-required" "true") ]
        , test "the keyboard of a phone: decimal, numeric without decimals, and left to the phone for negative amounts" <|
            \_ ->
                Expect.all
                    [ \_ -> viewOf price fresh |> Query.find inputOf |> Query.has [ Selector.attribute (Attr.attribute "inputmode" "decimal") ]
                    , \_ -> viewOf price (MoneyInput.init "price" Money.jpy) |> Query.find inputOf |> Query.has [ Selector.attribute (Attr.attribute "inputmode" "numeric") ]
                    , \_ -> viewOf (MoneyInput.allowNegative :: price) fresh |> Query.find inputOf |> Query.hasNot [ Selector.attribute (Attr.attribute "inputmode" "decimal") ]
                    ]
                    ()
        , test "it is a text input that the browser does not fill in or spell check" <|
            \_ ->
                viewOf price fresh
                    |> Query.find inputOf
                    |> Query.has
                        [ Selector.attribute (Attr.type_ "text")
                        , Selector.attribute (Attr.attribute "autocomplete" "off")
                        , Selector.attribute (Attr.attribute "spellcheck" "false")
                        ]
        , test "disabled and read-only reach the input" <|
            \_ ->
                Expect.all
                    [ \_ -> viewOf (MoneyInput.disabled True :: price) fresh |> Query.find inputOf |> Query.has [ Selector.disabled True ]
                    , \_ -> viewOf (MoneyInput.readOnly True :: price) fresh |> Query.find inputOf |> Query.has [ Selector.attribute (Attr.readonly True) ]
                    , \_ -> viewOf (MoneyInput.disabled True :: price) fresh |> Query.has [ Selector.class "klar-input--disabled" ]
                    ]
                    ()
        , test "a disabled or read-only field does not react to Enter" <|
            \_ ->
                Expect.all
                    [ \_ -> after [ pressKey (MoneyInput.disabled True :: price) "Enter" ] fresh |> Expect.err
                    , \_ -> after [ pressKey (MoneyInput.readOnly True :: price) "Enter" ] fresh |> Expect.err
                    ]
                    ()
        , test "keys other than Enter are not taken" <|
            \_ ->
                after [ pressKey price "a" ] fresh |> Expect.err
        , test "the amount can be aligned to the right" <|
            \_ ->
                viewOf (MoneyInput.alignRight :: price) fresh
                    |> Query.find inputOf
                    |> Query.has [ Selector.class "klar-money__control--end" ]
        , test "the name reaches the input" <|
            \_ ->
                viewOf (MoneyInput.name "unit_price" :: price) fresh
                    |> Query.find inputOf
                    |> Query.has [ Selector.attribute (Attr.name "unit_price") ]
        , test "the field is inside its wrapper also with nothing to draw, so it keeps the focus when an error comes" <|
            \_ ->
                viewOf [] fresh
                    |> Query.has [ Selector.class "klar-field", Selector.containing [ Selector.tag "input" ] ]
        , test "the optional text and the hidden label reach the label" <|
            \_ ->
                viewOf [ MoneyInput.label "Price", MoneyInput.optionalText "(optional)", MoneyInput.labelHidden ] fresh
                    |> Query.find [ Selector.tag "label" ]
                    |> Query.has [ Selector.class "klar-sr-only", Selector.text "(optional)" ]
        ]
