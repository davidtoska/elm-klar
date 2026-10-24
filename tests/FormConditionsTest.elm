module FormConditionsTest exposing (suite)

{-| Tests of the conditions of `Klar.Form.Spec` (`shownWhen`, `requiredWhen`), of
the rules that run at once (`checkFields`), and of `Form.domId`, `Form.query` and
`Form.fillRows` next to a field whose label starts like the group's.
-}

import Expect
import Html exposing (Html)
import Klar.Date as Date exposing (Date)
import Klar.Form as Form
import Klar.Form.Spec as Spec
import Klar.Ids as Ids exposing (Ids)
import Klar.Locale as Locale exposing (Locale)
import Klar.MaskedInput as MaskedInput
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
        , liveRules
        , handleTests
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
