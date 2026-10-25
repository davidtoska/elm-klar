module FormKindsTest exposing (suite)

{-| Tests of the kinds of `Klar.Form` that sit on Klar's own value types: a date
(`DatePicker`), a period (`DateRangePicker`), an amount (`MoneyInput`), an
identifier (`MaskedInput`), and the radio and checkbox views of a choice and a
toggle. Also: the limits of dates and amounts are checked by the form and given
to the controls, `withMessage` keeps the hint and the limits, `rule` works on
any output, and numbers in messages follow the locale.
-}

import Expect
import Html exposing (Html)
import Html.Attributes as Attr
import Json.Encode as Encode
import Klar.Date as Date exposing (Date)
import Klar.Form as Form
import Klar.Form.Check as Check
import Klar.Form.Spec as Spec
import Klar.Ids as Ids exposing (Ids)
import Klar.Locale as Locale exposing (Locale)
import Klar.MaskedInput as MaskedInput
import Klar.Money as Money exposing (Money)
import Klar.Select as Select
import Test exposing (Test, describe, test)
import Test.Html.Event as Event
import Test.Html.Query as Query
import Test.Html.Selector as Selector


type Kind
    = Company
    | Person


kindIds : Ids Kind
kindIds =
    Ids.make
        { toKey =
            \kind ->
                case kind of
                    Company ->
                        "company"

                    Person ->
                        "person"
        , fromKey =
            \key ->
                case key of
                    "company" ->
                        Just Company

                    "person" ->
                        Just Person

                    _ ->
                        Nothing
        }


day : Int -> Int -> Int -> Date
day y m d =
    Date.fromParts y m d |> Maybe.withDefault (Date.fromEpochDay 0)


nok : Int -> Money
nok minor =
    Money.fromMinor Money.nok minor |> Maybe.withDefault (Money.zero Money.nok)


type alias Fields =
    { due : Form.Field (Maybe Date)
    , period : Form.Field (Maybe ( Date, Date ))
    , limit : Form.Field (Maybe Money)
    , orgnr : Form.Field (Maybe String)
    , kind : Form.Field (Maybe Kind)
    , terms : Form.Field Bool
    }


type alias Values =
    { due : Date
    , period : Maybe ( Date, Date )
    , limit : Money
    , orgnr : String
    , kind : Kind
    , terms : Bool
    }


form : Form.Form () Fields Values
form =
    Spec.define "customer" Fields Values
        |> Spec.with (Spec.date "Due date" |> Spec.required |> Spec.minDate (day 2026 1 1) |> Spec.maxDate (day 2026 12 31))
        |> Spec.with (Spec.dateRange "Period")
        |> Spec.with (Spec.money Money.nok "Credit limit" |> Spec.required |> Spec.maxMoney (nok 5000000))
        |> Spec.with (Spec.masked MaskedInput.norwegianOrganisationNumber "Organisation number" |> Spec.required)
        |> Spec.with (Spec.choice kindIds "Customer kind" |> Spec.required)
        |> Spec.with (Spec.toggle "I accept the terms" |> Spec.rule identity (\_ -> "Accept the terms to go on"))
        |> Spec.build


f : Fields
f =
    Form.fields form


sample : Values
sample =
    { due = day 2026 10 20
    , period = Just ( day 2026 11 1, day 2026 11 30 )
    , limit = nok 2500000
    , orgnr = "974760673"
    , kind = Person
    , terms = True
    }


fill : Values -> Form.State () -> Form.State ()
fill values =
    Form.set f.due (Just values.due)
        >> Form.set f.period values.period
        >> Form.set f.limit (Just values.limit)
        >> Form.set f.orgnr (Just values.orgnr)
        >> Form.set f.kind (Just values.kind)
        >> Form.set f.terms values.terms


filled : Form.State ()
filled =
    Form.init form |> fill sample |> Form.markClean


bound : Locale -> Form.State () -> Form.View Form.Msg
bound locale state =
    Form.bind locale identity form state


problemsOf : Locale -> Form.State () -> List ( String, String )
problemsOf locale state =
    Form.problems locale form state |> List.map (\p -> ( p.label, p.message ))


{-| Sends an event to the first element that matches and runs the form's update
on the message that comes back.
-}
fire : (Form.View Form.Msg -> Html Form.Msg) -> List Selector.Selector -> ( String, Encode.Value ) -> Form.State () -> Form.State ()
fire draw target event state =
    draw (bound Locale.en state)
        |> Query.fromHtml
        |> Query.find target
        |> Event.simulate event
        |> Event.toResult
        |> Result.map (\msg -> Form.update form msg state |> Tuple.first)
        |> Result.withDefault state


typeInto : (Form.View Form.Msg -> Html Form.Msg) -> String -> Form.State () -> Form.State ()
typeInto draw text =
    fire draw [ Selector.tag "input" ] (Event.input text)


leave : (Form.View Form.Msg -> Html Form.Msg) -> Form.State () -> Form.State ()
leave draw =
    fire draw [ Selector.tag "input" ] Event.blur


dueDate : Form.View Form.Msg -> Html Form.Msg
dueDate v =
    Form.datePicker v f.due []


creditLimit : Form.View Form.Msg -> Html Form.Msg
creditLimit v =
    Form.moneyInput v f.limit []


orgnr : Form.View Form.Msg -> Html Form.Msg
orgnr v =
    Form.maskedInput v f.orgnr []


kinds : List (Select.Option Kind)
kinds =
    [ Select.option Company "Company", Select.option Person "Private person" |> Select.withDescription "No organisation number" ]


suite : Test
suite =
    describe "Klar.Form kinds on Klar's own types"
        [ test "a record with a date, a period, an amount, an identifier, a radio choice and a checkbox survives the form" <|
            \_ -> Check.roundTrip form fill sample |> Expect.equal (Ok sample)
        , test "an empty form names every required field" <|
            \_ ->
                problemsOf Locale.en (Form.init form)
                    |> Expect.equal
                        [ ( "Due date", "Required" )
                        , ( "Credit limit", "Required" )
                        , ( "Organisation number", "Required" )
                        , ( "Customer kind", "Required" )
                        , ( "I accept the terms", "Accept the terms to go on" )
                        ]
        , dates
        , amounts
        , identifiers
        , choices
        , rules
        ]


dates : Test
dates =
    describe "dates"
        [ test "a loaded date before minDate is a problem, written as the locale writes dates" <|
            \_ ->
                Expect.all
                    [ \state -> problemsOf Locale.en state |> Expect.equal [ ( "Due date", "The date cannot be before 2026-01-01" ) ]
                    , \state -> problemsOf Locale.nb state |> Expect.equal [ ( "Due date", "Datoen kan ikke være før 01.01.2026" ) ]
                    ]
                    (Form.set f.due (Just (day 2025 12 31)) filled)
        , test "a loaded date after maxDate is a problem" <|
            \_ ->
                problemsOf Locale.en (Form.set f.due (Just (day 2027 1 1)) filled)
                    |> Expect.equal [ ( "Due date", "The date cannot be after 2026-12-31" ) ]
        , test "the picker gets the limits of the declaration: a typed date before minDate is refused" <|
            \_ ->
                typeInto dueDate "2025-12-31" filled
                    |> problemsOf Locale.en
                    |> Expect.equal [ ( "Due date", "Invalid date" ) ]
        , test "a typed date inside the limits is the value, and the form is dirty" <|
            \_ ->
                typeInto dueDate "2026-03-15" filled
                    |> (\state -> ( Form.get f.due state, Form.isDirty state ))
                    |> Expect.equal ( Just (day 2026 3 15), True )
        , test "a picked date shows its problem at once, without waiting for the field to be left" <|
            \_ ->
                typeInto dueDate "2025-12-31" filled
                    |> (\state -> dueDate (bound Locale.en state))
                    |> Query.fromHtml
                    |> Query.has [ Selector.class "klar-field--invalid" ]
        , test "a period is set and read as a pair of dates" <|
            \_ ->
                Form.get f.period filled |> Expect.equal (Just ( day 2026 11 1, day 2026 11 30 ))
        ]


amounts : Test
amounts =
    let
        signed =
            Spec.define "refund" identity identity
                |> Spec.with (Spec.money Money.nok "Correction" |> Spec.minMoney (nok -100000))
                |> Spec.build

        signedField =
            Form.fields signed

        signedProblems amount =
            Form.init signed
                |> Form.set signedField (Just amount)
                |> Form.problems Locale.en signed
                |> List.map .message
    in
    describe "amounts"
        [ test "a negative amount is refused without a negative minMoney" <|
            \_ ->
                problemsOf Locale.en (Form.set f.limit (Just (nok -100)) filled)
                    |> Expect.equal [ ( "Credit limit", "Must not be negative" ) ]
        , test "a negative minMoney allows negative amounts down to it" <|
            \_ ->
                ( signedProblems (nok -5000), signedProblems (nok -200000) |> List.map (String.left 16) )
                    |> Expect.equal ( [], [ "Must be at least" ] )
        , test "an amount above maxMoney is a problem with the amount and the currency" <|
            \_ ->
                problemsOf Locale.en (Form.set f.limit (Just (nok 5000001)) filled)
                    |> Expect.equal [ ( "Credit limit", "Must be at most 50,000.00\u{00A0}NOK" ) ]
        , test "text that is not an amount is a problem" <|
            \_ ->
                typeInto creditLimit "12x" filled
                    |> problemsOf Locale.en
                    |> Expect.equal [ ( "Credit limit", "Must be an amount" ) ]
        , test "a typed amount is the value, exact" <|
            \_ ->
                typeInto creditLimit "1 234,50" filled
                    |> Form.get f.limit
                    |> Expect.equal (Just (nok 123450))
        , test "the problem of an amount waits until the field is left" <|
            \_ ->
                let
                    typed =
                        -- as in a browser: the field gets the focus, then the text
                        filled
                            |> fire creditLimit [ Selector.tag "input" ] Event.focus
                            |> typeInto creditLimit "60000"
                in
                Expect.all
                    [ \_ -> creditLimit (bound Locale.en typed) |> Query.fromHtml |> Query.hasNot [ Selector.class "klar-field--invalid" ]
                    , \_ -> creditLimit (bound Locale.en (leave creditLimit typed)) |> Query.fromHtml |> Query.has [ Selector.class "klar-field--invalid" ]
                    ]
                    ()
        ]


identifiers : Test
identifiers =
    describe "identifiers"
        [ test "an incomplete organisation number is a problem" <|
            \_ ->
                typeInto orgnr "97476067" filled
                    |> problemsOf Locale.en
                    |> Expect.equal [ ( "Organisation number", "Incomplete or invalid" ) ]
        , test "a complete organisation number is the value without separators" <|
            \_ ->
                typeInto orgnr "974 760 673" (Form.set f.orgnr Nothing filled)
                    |> Form.get f.orgnr
                    |> Expect.equal (Just "974760673")
        , test "loading the same number again keeps the form clean" <|
            \_ ->
                Form.set f.orgnr (Just "974760673") filled
                    |> Form.isDirty
                    |> Expect.equal False
        ]


choices : Test
choices =
    let
        radios state =
            Form.radio (bound Locale.en state) f.kind kinds []

        terms state =
            Form.checkbox (bound Locale.en state) f.terms []

        termsBox v =
            Form.checkbox v f.terms []
    in
    describe "radio and checkbox"
        [ test "a radio group draws the options of the choice with the legend of the field" <|
            \_ ->
                radios filled
                    |> Query.fromHtml
                    |> Expect.all
                        [ Query.findAll [ Selector.tag "input", Selector.attribute (Attr.type_ "radio") ] >> Query.count (Expect.equal 2)
                        , Query.find [ Selector.tag "legend" ] >> Query.has [ Selector.text "Customer kind" ]
                        , Query.has [ Selector.text "No organisation number" ]
                        , Query.find [ Selector.id "customer-customer-kind" ] >> Query.has [ Selector.attribute (Attr.checked True) ]
                        ]
        , test "choosing a radio button sets the choice" <|
            \_ ->
                -- the inputs of a radio group carry the place of their option (choice-inputs): Company is the first
                Form.set f.kind Nothing filled
                    |> fire (\v -> Form.radio v f.kind kinds []) [ Selector.attribute (Attr.value "0") ] (Event.custom "change" Encode.null)
                    |> Form.get f.kind
                    |> Expect.equal (Just Company)
        , test "a checkbox shows the problem of its rule once it was changed" <|
            \_ ->
                Expect.all
                    [ \_ ->
                        fire termsBox [ Selector.tag "input" ] (Event.check False) filled
                            |> terms
                            |> Query.fromHtml
                            |> Query.has [ Selector.text "Accept the terms to go on" ]
                    , \_ ->
                        fire termsBox [ Selector.tag "input" ] (Event.check False) filled
                            |> fire termsBox [ Selector.tag "input" ] (Event.check True)
                            |> problemsOf Locale.en
                            |> Expect.equal []
                    ]
                    ()
        ]


type alias RuleFields =
    { name : Form.Field String
    , quantity : Form.Field (Maybe Float)
    , rate : Form.Field (Maybe Float)
    }


type alias RuleValues =
    { name : String
    , quantity : Maybe Float
    , rate : Maybe Float
    }


rules : Test
rules =
    let
        ruled =
            Spec.define "line" RuleFields RuleValues
                |> Spec.with (Spec.text "Name" |> Spec.required |> Spec.hint "Full legal name" |> Spec.withMessage (\_ -> "Enter a name"))
                |> Spec.with
                    (Spec.number "Quantity"
                        |> Spec.range 1 99
                        |> Spec.withMessage (\_ -> "One to 99")
                        |> Spec.rule (\n -> n /= Just 7) (\_ -> "Not seven")
                    )
                |> Spec.with (Spec.number "Rate" |> Spec.range 0.5 1.5)
                |> Spec.build

        rf =
            Form.fields ruled

        v state =
            Form.bind Locale.en identity ruled state

        messages locale state =
            Form.problems locale ruled state |> List.map .message
    in
    describe "rules"
        [ test "withMessage after hint keeps the hint" <|
            \_ ->
                Form.textInput (v (Form.init ruled)) rf.name []
                    |> Query.fromHtml
                    |> Query.has [ Selector.text "Full legal name" ]
        , test "withMessage after range keeps the limits of the control" <|
            \_ ->
                Form.numberInput (v (Form.init ruled)) rf.quantity []
                    |> Query.fromHtml
                    |> Query.find [ Selector.tag "input" ]
                    |> Query.has [ Selector.attribute (Attr.attribute "aria-valuemin" "1"), Selector.attribute (Attr.attribute "aria-valuemax" "99") ]
        , test "the reworded messages are the ones given" <|
            \_ ->
                Form.init ruled
                    |> Form.set rf.quantity (Just 120)
                    |> messages Locale.en
                    |> Expect.equal [ "Enter a name", "One to 99" ]
        , test "rule works on any output" <|
            \_ ->
                Form.init ruled
                    |> Form.set rf.name "Acme"
                    |> Form.set rf.quantity (Just 7)
                    |> messages Locale.en
                    |> Expect.equal [ "Not seven" ]
        , test "the numbers of a range are written as the locale writes them" <|
            \_ ->
                Form.init ruled
                    |> Form.set rf.name "Acme"
                    |> Form.set rf.rate (Just 2)
                    |> messages Locale.nb
                    |> Expect.equal [ "Må være mellom 0,5 og 1,5" ]
        ]
