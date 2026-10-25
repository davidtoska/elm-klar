module FormConditionsTest exposing (suite)

{-| Tests of the conditions of `Klar.Form.Spec` (`shownWhen`, `requiredWhen`), of
the rules that run at once (`checkFields`), and of `Form.domId`, `Form.query` and
`Form.fillRows` next to a field whose label starts like the group's.
-}

import Expect
import Html exposing (Html)
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


type alias Fields =
    { kind : Form.Field (Maybe Kind)
    , organisationNumber : Form.Field (Maybe String)
    , name : Form.Field String
    }


type alias Values =
    { kind : Kind
    , organisationNumber : Maybe String
    , name : String
    }


isCompany : Fields -> Form.State () -> Bool
isCompany handles state =
    Form.get handles.kind state == Just Company


form : Form.Form () Fields Values
form =
    Spec.define "customer" Fields Values
        |> Spec.with (Spec.choice kindIds "Customer kind" |> Spec.required)
        |> Spec.with (Spec.masked MaskedInput.norwegianOrganisationNumber "Organisation number")
        |> Spec.with (Spec.text "Name" |> Spec.required)
        |> Spec.shownWhen isCompany .organisationNumber
        |> Spec.requiredWhen isCompany .organisationNumber
        |> Spec.build


f : Fields
f =
    Form.fields form


as_ : Kind -> Form.State ()
as_ kind =
    Form.init form
        |> Form.set f.kind (Just kind)
        |> Form.set f.name "Acme"


bound : Form.State () -> Form.View Form.Msg
bound state =
    Form.bind Locale.en identity form state


problemsOf : Form.State () -> List ( String, String )
problemsOf state =
    Form.problems Locale.en form state |> List.map (\p -> ( p.label, p.message ))


orgnrView : Form.State () -> Html Form.Msg
orgnrView state =
    Form.maskedInput (bound state) f.organisationNumber []


suite : Test
suite =
    describe "conditions, rules that run at once, and handles"
        [ conditions
        , hiddenForEveryone
        , liveRules
        , handleTests
        , entries
        ]


conditions : Test
conditions =
    describe "shownWhen and requiredWhen"
        [ test "a field whose condition does not hold is not drawn" <|
            \_ ->
                orgnrView (as_ Person)
                    |> Query.fromHtml
                    |> Query.hasNot [ Selector.tag "input" ]
        , test "a field whose condition does not hold has no problems and gives its empty value" <|
            \_ ->
                as_ Person
                    |> Form.set f.organisationNumber (Just "123")
                    |> (\state -> ( problemsOf state, Form.toValues Locale.en form state |> Result.map .organisationNumber ))
                    |> Expect.equal ( [], Ok Nothing )
        , test "while it holds, the field is drawn with the required mark and an empty value is a problem" <|
            \_ ->
                Expect.all
                    [ \state -> orgnrView state |> Query.fromHtml |> Query.has [ Selector.class "klar-field__required" ]
                    , \state -> problemsOf state |> Expect.equal [ ( "Organisation number", "Required" ) ]
                    ]
                    (as_ Company)
        , test "while it holds, the value is in the values" <|
            \_ ->
                as_ Company
                    |> Form.set f.organisationNumber (Just "974760673")
                    |> Form.toValues Locale.en form
                    |> Result.map .organisationNumber
                    |> Expect.equal (Ok (Just "974760673"))
        , test "what was typed comes back when the condition holds again" <|
            \_ ->
                as_ Company
                    |> Form.set f.organisationNumber (Just "974760673")
                    |> Form.set f.kind (Just Person)
                    |> Form.set f.kind (Just Company)
                    |> Form.get f.organisationNumber
                    |> Expect.equal (Just "974760673")
        , test "a hidden field is left out of the summary after reveal" <|
            \_ ->
                as_ Person
                    |> Form.set f.name ""
                    |> Form.reveal form
                    |> Tuple.first
                    |> (\state -> Form.summary (bound state))
                    |> Query.fromHtml
                    |> Expect.all [ Query.has [ Selector.text "Required" ], Query.hasNot [ Selector.text "Organisation number" ] ]
        ]


type Step
    = Dates
    | Review


type alias BookingFields =
    { from : Form.Field (Maybe Date)
    , to : Form.Field (Maybe Date)
    }


type alias BookingValues =
    { from : Date
    , to : Date
    }


booking : Form.Form Step BookingFields BookingValues
booking =
    Spec.define "booking" BookingFields BookingValues
        |> Spec.step Dates "Dates"
        |> Spec.with (Spec.date "From" |> Spec.required)
        |> Spec.with (Spec.date "To" |> Spec.required)
        |> Spec.step Review "Review"
        |> Spec.checkFields
            (\locale bf state ->
                case ( Form.get bf.from state, Form.get bf.to state ) of
                    ( Just from, Just to ) ->
                        if Date.compare to from == LT then
                            [ Form.problem bf.to (Locale.pick locale { nb = "Til kan ikke være før fra", en = "To cannot be before from" }) ]

                        else
                            []

                    _ ->
                        []
            )
        |> Spec.build


day : Int -> Int -> Int -> Date
day y m d =
    Date.fromParts y m d |> Maybe.withDefault (Date.fromEpochDay 0)


liveRules : Test
liveRules =
    let
        bf =
            Form.fields booking

        backwards =
            Form.init booking
                |> Form.set bf.from (Just (day 2026 5 10))
                |> Form.set bf.to (Just (day 2026 5 1))
    in
    describe "checkFields"
        [ test "a rule over two fields gives its problem on the step of its field, in the locale" <|
            \_ ->
                Expect.all
                    [ \_ -> Form.problems Locale.en booking backwards |> List.map (\p -> ( p.label, p.message, p.step )) |> Expect.equal [ ( "To", "To cannot be before from", Just Dates ) ]
                    , \_ -> Form.problems Locale.nb booking backwards |> List.map .message |> Expect.equal [ "Til kan ikke være før fra" ]
                    ]
                    ()
        , test "its problem keeps the user on the step" <|
            \_ ->
                (Form.advance booking backwards).state
                    |> Form.currentStep booking
                    |> Expect.equal (Just Dates)
        , test "it says nothing while a field is empty" <|
            \_ ->
                Form.init booking
                    |> Form.set bf.from (Just (day 2026 5 10))
                    |> Form.problems Locale.en booking
                    |> List.map .message
                    |> Expect.equal [ "Required" ]
        , test "without its problem the step can be left" <|
            \_ ->
                (Form.advance booking (Form.set bf.to (Just (day 2026 5 20)) backwards)).state
                    |> Form.currentStep booking
                    |> Expect.equal (Just Review)
        ]


type alias SupplierFields =
    { contacts : Form.Field (Form.Rows ContactFields)
    , contactsNote : Form.Field String
    }


type alias SupplierValues =
    { contacts : List String
    , contactsNote : Maybe String
    }


type alias ContactFields =
    { name : Form.Field String }


contact : Form.Form () ContactFields String
contact =
    Spec.define "contact" ContactFields identity
        |> Spec.with (Spec.text "Name" |> Spec.required)
        |> Spec.build


supplier : Form.Form () SupplierFields SupplierValues
supplier =
    Spec.define "supplier" SupplierFields SupplierValues
        |> Spec.with (Spec.rows { label = "Contacts", item = "Contact" } contact)
        |> Spec.with (Spec.text "Contacts note")
        |> Spec.build


handleTests : Test
handleTests =
    let
        sf =
            Form.fields supplier
    in
    describe "handles"
        [ test "domId is the DOM id of the control, and of the add button of a group" <|
            \_ ->
                ( Form.domId f.name, Form.domId sf.contacts )
                    |> Expect.equal ( "customer-name", "supplier-contacts" )
        , test "query is empty for a field that is not a select, and for a closed select" <|
            \_ ->
                ( Form.query f.name (as_ Company), Form.query f.kind (as_ Company) )
                    |> Expect.equal ( "", "" )
        , test "fillRows keeps a field whose label starts like the group's" <|
            \_ ->
                Form.init supplier
                    |> Form.set sf.contactsNote "Call before noon"
                    |> Form.fillRows sf.contacts (\name row -> Form.set row.name name) [ "Ada", "Grace" ]
                    |> Form.toValues Locale.en supplier
                    |> Expect.equal (Ok { contacts = [ "Ada", "Grace" ], contactsNote = Just "Call before noon" })
        ]



-- A HIDDEN FIELD IS EMPTY FOR EVERYONE


type alias ChainFields =
    { kind : Form.Field (Maybe Kind)
    , vat : Form.Field String
    , vatNote : Form.Field String
    }


type alias ChainValues =
    { kind : Kind
    , vat : Maybe String
    , vatNote : Maybe String
    }


hasVat : ChainFields -> Form.State () -> Bool
hasVat handles state =
    String.trim (Form.get handles.vat state) /= ""


{-| The VAT note is shown, and required, when a VAT number is filled in; the VAT
number is shown for a company only.
-}
chain : Form.Form () ChainFields ChainValues
chain =
    Spec.define "chain" ChainFields ChainValues
        |> Spec.with (Spec.choice kindIds "Customer kind" |> Spec.required)
        |> Spec.with (Spec.text "VAT number")
        |> Spec.with (Spec.text "VAT note")
        |> Spec.shownWhen (\handles state -> Form.get handles.kind state == Just Company) .vat
        |> Spec.shownWhen hasVat .vatNote
        |> Spec.requiredWhen hasVat .vatNote
        |> Spec.build


type alias ShipFields =
    { elsewhere : Form.Field Bool
    , address : Form.Field String
    }


type alias ShipValues =
    { elsewhere : Bool
    , address : String
    }


{-| The mistake the docs warn about: a field that can be hidden, declared with
`required`.
-}
mistaken : Form.Form () ShipFields ShipValues
mistaken =
    Spec.define "ship" ShipFields ShipValues
        |> Spec.with (Spec.toggle "Ship elsewhere")
        |> Spec.with (Spec.text "Delivery address" |> Spec.required)
        |> Spec.shownWhen (\handles state -> Form.get handles.elsewhere state) .address
        |> Spec.build


hiddenForEveryone : Test
hiddenForEveryone =
    let
        cf =
            Form.fields chain

        typedAsCompany =
            Form.init chain
                |> Form.set cf.kind (Just Company)
                |> Form.set cf.vat "NO974760673MVA"

        chainProblems state =
            Form.problems Locale.en chain state |> List.map (\p -> ( p.label, p.message ))
    in
    describe "a field that is not shown is empty for every reader"
        [ test "a condition on a hidden field sees it empty: the field after it is hidden too" <|
            \_ ->
                typedAsCompany
                    |> Form.set cf.kind (Just Person)
                    |> Expect.all
                        [ \state -> chainProblems state |> Expect.equal []
                        , \state -> Form.toValues Locale.en chain state |> Expect.equal (Ok { kind = Person, vat = Nothing, vatNote = Nothing })
                        , \state -> Form.textInput (Form.bind Locale.en identity chain state) cf.vatNote [] |> Query.fromHtml |> Query.hasNot [ Selector.tag "input" ]
                        ]
        , test "while the field it depends on is shown, the chained field is shown and required" <|
            \_ ->
                chainProblems typedAsCompany
                    |> Expect.equal [ ( "VAT note", "Required" ) ]
        , test "a hidden field whose own rule fails is never in the summary" <|
            \_ ->
                Form.init mistaken
                    |> Form.reveal mistaken
                    |> Tuple.first
                    |> (\state -> Form.summary (Form.bind Locale.en identity mistaken state))
                    |> Query.fromHtml
                    |> Query.hasNot [ Selector.text "Delivery address" ]
        , test "toValues still fails then, and names the field, so the mistake can be found" <|
            \_ ->
                Form.toValues Locale.en mistaken (Form.init mistaken)
                    |> Result.mapError (List.map (\p -> ( p.label, p.message )))
                    |> Expect.equal (Err [ ( "Delivery address", "Required" ) ])
        , test "Check.failingWhenHidden finds the mistake, and nothing in a right declaration" <|
            \_ ->
                ( Check.failingWhenHidden mistaken, Check.failingWhenHidden form, Check.failingWhenHidden chain )
                    |> Expect.equal ( [ "Delivery address" ], [], [] )
        ]



-- WHERE THE FOCUS GOES


type alias EntryFields =
    { due : Form.Field (Maybe Date)
    , period : Form.Field (Maybe ( Date, Date ))
    , limit : Form.Field (Maybe Money)
    , orgnr : Form.Field (Maybe String)
    , kind : Form.Field (Maybe Kind)
    , terms : Form.Field Bool
    }


type alias EntryValues =
    { due : Maybe Date
    , period : ( Date, Date )
    , limit : Maybe Money
    , orgnr : Maybe String
    , kind : Maybe Kind
    , terms : Bool
    }


entryForm : Form.Form () EntryFields EntryValues
entryForm =
    Spec.define "entry" EntryFields EntryValues
        |> Spec.with (Spec.date "Due date")
        |> Spec.with (Spec.dateRange "Period" |> Spec.required)
        |> Spec.with (Spec.money Money.nok "Credit limit")
        |> Spec.with (Spec.masked MaskedInput.norwegianOrganisationNumber "Organisation number")
        |> Spec.with (Spec.choice kindIds "Customer kind")
        |> Spec.with (Spec.toggle "I accept the terms")
        |> Spec.build


{-| The element with the field's `domId` is an input of the drawn control (and
there is exactly one element with that id).
-}
reachesInput : (Form.View Form.Msg -> Html Form.Msg) -> String -> Expect.Expectation
reachesInput draw id =
    draw (Form.bind Locale.en identity entryForm (Form.init entryForm))
        |> Query.fromHtml
        |> Query.find [ Selector.id id ]
        |> Query.has [ Selector.tag "input" ]


entries : Test
entries =
    let
        ef =
            Form.fields entryForm
    in
    describe "domId is the id of a real input for every kind"
        [ test "date" <| \_ -> reachesInput (\v -> Form.datePicker v ef.due []) (Form.domId ef.due)
        , test "period: the from date" <|
            \_ ->
                Expect.all
                    [ \_ -> Form.domId ef.period |> Expect.equal "entry-period-from"
                    , \_ -> reachesInput (\v -> Form.dateRangePicker v ef.period []) (Form.domId ef.period)
                    ]
                    ()
        , test "money" <| \_ -> reachesInput (\v -> Form.moneyInput v ef.limit []) (Form.domId ef.limit)
        , test "masked" <| \_ -> reachesInput (\v -> Form.maskedInput v ef.orgnr []) (Form.domId ef.orgnr)
        , test "radio" <|
            \_ ->
                reachesInput (\v -> Form.radio v ef.kind [ Select.option Company "Company", Select.option Person "Person" ] [])
                    (Form.domId ef.kind)
        , test "checkbox" <| \_ -> reachesInput (\v -> Form.checkbox v ef.terms []) (Form.domId ef.terms)
        , test "the summary line of a required period goes to the from date" <|
            \_ ->
                Form.init entryForm
                    |> Form.reveal entryForm
                    |> Tuple.first
                    |> Form.problems Locale.en entryForm
                    |> List.map .field
                    |> Expect.equal [ "entry-period-from" ]
        ]
