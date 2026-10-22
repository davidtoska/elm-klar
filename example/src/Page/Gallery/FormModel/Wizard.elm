module Page.Gallery.FormModel.Wizard exposing (Model, Msg, init, update, view)

{-| The form model on a customer onboarding wizard: four steps, a repeating
group of contacts, every kind of field, a server that refuses, a checkbox the
model does not hold, and the mark for unsaved changes. The application's own
code is the declaration, the loading of a record, the mapping of the server's
fields and the view.
-}

import Html exposing (Html)
import Klar.Alert as Alert
import Klar.Button as Button
import Klar.Card as Card
import Klar.Checkbox as Checkbox
import Klar.FileDrop as FileDrop
import Klar.Form as Form
import Klar.Form.Layout as FormLayout
import Klar.Form.Spec as Spec
import Klar.Icon as Icon
import Klar.Ids as Ids exposing (Ids)
import Klar.Layout as Layout
import Klar.Locale as Locale exposing (Locale)
import Klar.MultiSelect as MultiSelect
import Klar.NumberInput as NumberInput
import Klar.Remote as Remote
import Klar.Select as Select
import Klar.Stepper as Stepper
import Klar.TagInput as TagInput
import Klar.Text as Text
import Klar.TextArea as TextArea
import Klar.TextInput as TextInput
import Klar.Theme exposing (Tone(..))
import Klar.Validate as Validate



-- THE APPLICATION'S DOMAIN


type CountryId
    = CountryId String


type SegmentId
    = SegmentId Int


type Role
    = Buyer
    | Accountant
    | Warehouse


type alias Contact =
    { name : String
    , email : String
    , role : Role
    , primary : Bool
    }


type alias Customer =
    { name : String
    , legalName : Maybe String
    , registration : String
    , website : Maybe String
    , country : CountryId
    , segments : List SegmentId
    , preferred : Bool
    , certifications : List String
    , contract : FileDrop.FileInfo
    , contacts : List Contact
    , leadTime : Float
    , minimumOrder : Maybe Float
    , shipsTo : List CountryId
    , notes : Maybe String
    }


countryOptions : List (Select.Option CountryId)
countryOptions =
    [ Select.option (CountryId "no") "Norway"
    , Select.option (CountryId "se") "Sweden"
    , Select.option (CountryId "dk") "Denmark"
    , Select.option (CountryId "de") "Germany"
    , Select.option (CountryId "nl") "Netherlands"
    , Select.option (CountryId "pl") "Poland"
    ]


segmentOptions : List (Select.Option SegmentId)
segmentOptions =
    [ Select.option (SegmentId 1) "Grocery" |> Select.withGroup "Retail"
    , Select.option (SegmentId 2) "Fashion" |> Select.withGroup "Retail"
    , Select.option (SegmentId 3) "Machinery" |> Select.withGroup "Industry"
    , Select.option (SegmentId 4) "Chemicals" |> Select.withGroup "Industry"
    , Select.option (SegmentId 5) "Logistics" |> Select.withGroup "Services"
    ]


roleOptions : List (Select.Option Role)
roleOptions =
    [ Select.option Buyer "Buyer", Select.option Accountant "Accountant", Select.option Warehouse "Warehouse" ]


countryIds : Ids CountryId
countryIds =
    Ids.make { toKey = \(CountryId code) -> code, fromKey = Just << CountryId }


segmentIds : Ids SegmentId
segmentIds =
    Ids.make { toKey = \(SegmentId n) -> String.fromInt n, fromKey = Maybe.map SegmentId << String.toInt }


roleIds : Ids Role
roleIds =
    Ids.make
        { toKey =
            \role ->
                case role of
                    Buyer ->
                        "buyer"

                    Accountant ->
                        "accountant"

                    Warehouse ->
                        "warehouse"
        , fromKey =
            \key ->
                case key of
                    "buyer" ->
                        Just Buyer

                    "accountant" ->
                        Just Accountant

                    "warehouse" ->
                        Just Warehouse

                    _ ->
                        Nothing
        }


savedCustomer : Customer
savedCustomer =
    { name = "Northwind Trading"
    , legalName = Just "Northwind Trading AS"
    , registration = "12345678"
    , website = Just "https://northwind.example"
    , country = CountryId "no"
    , segments = [ SegmentId 1, SegmentId 5 ]
    , preferred = True
    , certifications = [ "ISO 9001" ]
    , contract = { name = "northwind-contract.pdf", size = 120000, mime = "application/pdf" }
    , contacts =
        [ { name = "Ada Lovelace", email = "ada@northwind.example", role = Buyer, primary = True }
        , { name = "Grace Hopper", email = "grace@northwind.example", role = Accountant, primary = False }
        ]
    , leadTime = 5
    , minimumOrder = Just 500
    , shipsTo = [ CountryId "no", CountryId "se" ]
    , notes = Just "Deliver to the back door."
    }


{-| The dummy backend: what the server says to a save.
-}
type Refusal
    = RefusedName
    | RefusedRegistration
    | RefusedCountry
    | RefusedCertification
    | RefusedContract
    | RefusedContactEmail Int


save : Customer -> List ( Refusal, String )
save customer =
    List.concat
        [ if customer.name == "Acme Trading" then
            [ ( RefusedName, "A customer with this name already exists." ) ]

          else
            []
        , if customer.registration == "00000000" then
            [ ( RefusedRegistration, "This registration number belongs to another customer." ) ]

          else
            []
        , if customer.country == CountryId "pl" then
            [ ( RefusedCountry, "We cannot take customers in this country yet." ) ]

          else
            []
        , if List.member "XYZ" customer.certifications then
            [ ( RefusedCertification, "Unknown certification \"XYZ\"." ) ]

          else
            []
        , if String.contains "draft" (String.toLower customer.contract.name) then
            [ ( RefusedContract, "A draft cannot be the signed contract." ) ]

          else
            []
        , customer.contacts
            |> List.indexedMap
                (\i contact ->
                    if String.endsWith "@mailinator.com" contact.email then
                        [ ( RefusedContactEmail i, "Disposable email addresses are not accepted." ) ]

                    else
                        []
                )
            |> List.concat
        ]



-- THE DECLARATION


type Step
    = Account
    | Contacts
    | Delivery
    | Review


type alias ContactFields =
    { name : Form.Field String
    , email : Form.Field String
    , role : Form.Field (Maybe Role)
    , primary : Form.Field Bool
    }


contactForm : Form.Form () ContactFields Contact
contactForm =
    Spec.define "contact" ContactFields Contact
        |> Spec.with (Spec.text "Name" |> Spec.required)
        |> Spec.with (Spec.text "Email" |> Spec.required |> Spec.rules [ Validate.email ])
        |> Spec.with (Spec.choice roleIds "Role" |> Spec.required)
        |> Spec.with (Spec.toggle "Primary contact")
        |> Spec.build


type alias Fields =
    { name : Form.Field String
    , legalName : Form.Field String
    , registration : Form.Field String
    , website : Form.Field String
    , country : Form.Field (Maybe CountryId)
    , segments : Form.Field (List SegmentId)
    , preferred : Form.Field Bool
    , certifications : Form.Field (List String)
    , contract : Form.Field (List FileDrop.FileInfo)
    , contacts : Form.Field (Form.Rows ContactFields)
    , leadTime : Form.Field (Maybe Float)
    , minimumOrder : Form.Field (Maybe Float)
    , shipsTo : Form.Field (List CountryId)
    , notes : Form.Field String
    }


form : Form.Form Step Fields Customer
form =
    Spec.define "wizard" Fields Customer
        |> Spec.step Account "Account"
        |> Spec.with (Spec.text "Name" |> Spec.required |> Spec.rules [ Validate.maxLength 80 ])
        |> Spec.with (Spec.text "Legal name")
        |> Spec.with (Spec.text "Registration number" |> Spec.required |> Spec.hint "8 digits." |> Spec.rules [ registrationFormat ])
        |> Spec.with (Spec.text "Website" |> Spec.rules [ httpUrl ])
        |> Spec.with (Spec.choice countryIds "Country" |> Spec.required)
        |> Spec.with (Spec.choices segmentIds "Segments" |> Spec.atLeast 1)
        |> Spec.with (Spec.toggle "Preferred customer" |> Spec.hint "Preferred customers are served first.")
        |> Spec.with (Spec.tags "Certifications" |> Spec.hint "Type a name and press Enter. Try XYZ: the server does not know it.")
        |> Spec.with (Spec.files "Signed contract" |> Spec.one |> Spec.required |> Spec.withMessage (\lang -> Locale.pick lang { nb = "Legg ved den signerte kontrakten", en = "Attach the signed contract." }))
        |> Spec.step Contacts "Contacts"
        |> Spec.with
            (Spec.rows { label = "Contacts", item = "Contact" } contactForm
                |> Spec.atLeast 1
                |> Spec.rule onlyOnePrimary (\lang -> Locale.pick lang { nb = "Bare én kontakt kan være hovedkontakt", en = "Only one contact can be the primary." })
            )
        |> Spec.step Delivery "Delivery"
        |> Spec.with (Spec.number "Lead time in days" |> Spec.required |> Spec.whole |> Spec.range 0 120)
        |> Spec.with (Spec.number "Minimum order")
        |> Spec.with (Spec.choices countryIds "Ships to" |> Spec.atLeast 1)
        |> Spec.with (Spec.text "Notes" |> Spec.rules [ Validate.maxLength 500 ])
        |> Spec.step Review "Review"
        |> Spec.build


f : Fields
f =
    Form.fields form


registrationFormat : Validate.Validator
registrationFormat =
    Validate.custom (\text -> String.length text == 8 && String.all Char.isDigit text)
        { nb = "Må ha 8 siffer", en = "Must be 8 digits" }


httpUrl : Validate.Validator
httpUrl =
    Validate.custom (\text -> String.startsWith "https://" text || String.startsWith "http://" text)
        { nb = "Må starte med http:// eller https://", en = "Must start with http:// or https://" }


{-| A rule over the rows together: at most one contact is the primary. It is a
rule of the group, so it counts on the Contacts step like any other.
-}
onlyOnePrimary : List Contact -> Bool
onlyOnePrimary contacts =
    List.length (List.filter .primary contacts) <= 1


fill : Customer -> Form.State Step -> Form.State Step
fill c =
    Form.set f.name c.name
        >> Form.set f.legalName (Maybe.withDefault "" c.legalName)
        >> Form.set f.registration c.registration
        >> Form.set f.website (Maybe.withDefault "" c.website)
        >> Form.set f.country (Just c.country)
        >> Form.set f.segments c.segments
        >> Form.set f.preferred c.preferred
        >> Form.set f.certifications c.certifications
        >> Form.set f.contract [ c.contract ]
        >> Form.fillRows f.contacts fillContact c.contacts
        >> Form.set f.leadTime (Just c.leadTime)
        >> Form.set f.minimumOrder c.minimumOrder
        >> Form.set f.shipsTo c.shipsTo
        >> Form.set f.notes (Maybe.withDefault "" c.notes)


fillContact : Contact -> ContactFields -> Form.State Step -> Form.State Step
fillContact c row =
    Form.set row.name c.name
        >> Form.set row.email c.email
        >> Form.set row.role (Just c.role)
        >> Form.set row.primary c.primary


{-| The server's fields, mapped once to the handles of the form.
-}
fromRefusal : Form.State Step -> ( Refusal, String ) -> Maybe (Form.Problem Step)
fromRefusal state ( refusal, message ) =
    case refusal of
        RefusedName ->
            Just (Form.problem f.name message)

        RefusedRegistration ->
            Just (Form.problem f.registration message)

        RefusedCountry ->
            Just (Form.problem f.country message)

        RefusedCertification ->
            Just (Form.problem f.certifications message)

        RefusedContract ->
            Just (Form.problem f.contract message)

        RefusedContactEmail position ->
            Form.rowFields f.contacts state
                |> List.drop position
                |> List.head
                |> Maybe.map (\row -> Form.problem row.email message)



-- THE MODEL AND THE UPDATE


type alias Model =
    { form : Form.State Step
    , accepted : Bool
    , status : FormLayout.Status
    , saved : Maybe String
    }


type Msg
    = FormMsg Form.Msg
    | Next
    | Back
    | GoTo Step
    | Accepted Bool
    | Load
    | Revert


init : Model
init =
    { form = Form.init form, accepted = False, status = FormLayout.Idle, saved = Nothing }


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    let
        ( next, cmd ) =
            step msg model
    in
    ( sync next, cmd )


{-| The terms checkbox is not a field of the form. Its problem is handed over at
the end of every update, and from then on it is counted, listed on the review
step and marked on the stepper like the form's own.
-}
sync : Model -> Model
sync model =
    { model | form = Form.outside form (termsProblem model) model.form }


termsProblem : Model -> List (Form.Problem Step)
termsProblem model =
    if model.accepted then
        []

    else
        [ { field = termsId, label = "Terms", message = "Accept the terms to continue.", step = Just Review } ]


termsId : String
termsId =
    "wizard-terms"


step : Msg -> Model -> ( Model, Cmd Msg )
step msg model =
    case msg of
        FormMsg inner ->
            Form.update form inner model.form
                |> Tuple.mapBoth (\state -> { model | form = state }) (Cmd.map FormMsg)

        Back ->
            Form.back form model.form
                |> Tuple.mapBoth (\state -> { model | form = state }) (Cmd.map FormMsg)

        GoTo target ->
            Form.goTo form target model.form
                |> Tuple.mapBoth (\state -> { model | form = state }) (Cmd.map FormMsg)

        Accepted flag ->
            ( { model | accepted = flag }, Cmd.none )

        Next ->
            let
                next =
                    Form.advance form model.form
            in
            case next.submit of
                Nothing ->
                    ( { model | form = next.state }, Cmd.map FormMsg next.cmd )

                Just customer ->
                    case save customer of
                        [] ->
                            ( { model
                                | form = Form.markClean model.form
                                , status = FormLayout.Succeeded "Saved."
                                , saved = Just (customer.name ++ ", " ++ String.fromInt (List.length customer.contacts) ++ " contacts")
                              }
                            , Cmd.none
                            )

                        refusals ->
                            Form.rejected (List.filterMap (fromRefusal model.form) refusals) form model.form
                                |> Tuple.mapBoth (\state -> { model | form = state, status = FormLayout.Idle }) (Cmd.map FormMsg)

        Load ->
            ( { model | form = Form.init form |> fill savedCustomer |> Form.markClean, accepted = False, status = FormLayout.Idle }, Cmd.none )

        Revert ->
            ( { model | form = Form.revert form model.form, accepted = False, status = FormLayout.Idle }, Cmd.none )



-- THE VIEW


view : Locale -> Model -> Html Msg
view locale model =
    let
        v =
            Form.bind locale FormMsg form model.form

        current =
            Form.currentStep form model.form
    in
    Layout.stack [ Layout.gap 4 ]
        [ Form.stepper v [ Stepper.ariaLabel "Customer onboarding" ]
        , FormLayout.view [ FormLayout.id "wizard-form", FormLayout.onSubmit Next, FormLayout.ariaLabel "Customer onboarding", FormLayout.locale locale ]
            [ case current of
                Just Account ->
                    viewAccount v

                Just Contacts ->
                    viewContacts v model

                Just Delivery ->
                    viewDelivery v

                _ ->
                    viewReview v model
            , FormLayout.unsavedFlag [ FormLayout.locale locale ] (isDirty model)
            , FormLayout.actions
                [ FormLayout.status [ FormLayout.id "wizard-form", FormLayout.locale locale ] model.status
                , Layout.spacer
                , Button.view [ Button.onClick Revert, Button.disabled (not (isDirty model)) ] "Revert"
                , Button.view [ Button.onClick Load ] "Load saved customer"
                , if current == Just Account then
                    Html.text ""

                  else
                    Button.view [ Button.onClick Back, Button.icon Icon.arrowLeft ] "Back"
                , Button.view [ Button.primary, Button.submit ]
                    (if current == Just Review then
                        "Save customer"

                     else
                        "Next"
                    )
                ]
            ]
        , readout model
        ]


isDirty : Model -> Bool
isDirty model =
    Form.isDirty model.form


readout : Model -> Html Msg
readout model =
    Layout.stack [ Layout.gap 2 ]
        [ Text.caption
            ("Unsaved changes: "
                ++ (if isDirty model then
                        "yes"

                    else
                        "no"
                   )
            )
        , Text.caption ("Problems in the form, shown or not: " ++ String.fromInt (List.length (Form.problems Locale.en form model.form)))
        , Text.caption
            (case model.saved of
                Just text ->
                    "Last saved: " ++ text ++ "."

                Nothing ->
                    "Nothing saved yet. Try: the name Acme Trading, the registration number 00000000, the country Poland, a contact at mailinator.com."
            )
        ]


viewAccount : Form.View Msg -> Html Msg
viewAccount v =
    Layout.stack [ Layout.gap 4 ]
        [ Form.summary v
        , FormLayout.section "Company"
            "Who the customer is, as registered."
            [ FormLayout.grid 2
                [ Form.textInput v f.name [ TextInput.hint "How the customer appears in lists." ]
                , Form.textInput v f.legalName []
                , Form.textInput v f.registration [ TextInput.inputMode "numeric" ]
                , Form.textInput v f.website [ TextInput.url, TextInput.placeholder "https://" ]
                , Form.select v f.country (Remote.Loaded countryOptions) []
                , Form.multiSelect v f.segments (Remote.Loaded segmentOptions) []
                , FormLayout.fullRow (Form.switch v f.preferred [])
                ]
            ]
        , FormLayout.section "Certifications and contract"
            "What the customer holds, and the signed agreement."
            [ Form.tagInput v f.certifications [ TagInput.maxTags 6 ]
            , Form.fileDrop v f.contract [ FileDrop.accept [ ".pdf" ], FileDrop.maxSize 5000000, FileDrop.maxFiles 1 ]
            ]
        ]


viewContacts : Form.View Msg -> Model -> Html Msg
viewContacts v model =
    let
        card position row =
            Card.view
                [ Card.headingLevel 3
                , Card.title ("Contact " ++ String.fromInt (position + 1))
                , Card.actions [ Form.removeRow v f.contacts position [] ]
                ]
                [ FormLayout.grid 2
                    [ Form.textInput v row.name []
                    , Form.textInput v row.email [ TextInput.email ]
                    , Form.select v row.role (Remote.Loaded roleOptions) []
                    , Form.switch v row.primary []
                    ]
                ]
    in
    Layout.stack [ Layout.gap 4 ]
        (Form.summary v
            :: List.indexedMap card (Form.rowFields f.contacts model.form)
            ++ [ Form.addRow v f.contacts [] "Add contact" ]
        )


viewDelivery : Form.View Msg -> Html Msg
viewDelivery v =
    Layout.stack [ Layout.gap 4 ]
        [ Form.summary v
        , FormLayout.section "Delivery"
            "How fast, how much and where."
            [ FormLayout.grid 2
                [ Form.numberInput v f.leadTime [ NumberInput.suffixText "days" ]
                , Form.numberInput v f.minimumOrder [ NumberInput.prefixText "NOK", NumberInput.grouped ]
                , FormLayout.fullRow (Form.multiSelect v f.shipsTo (Remote.Loaded countryOptions) [])
                , FormLayout.fullRow (Form.textArea v f.notes [ TextArea.rows 3 ])
                ]
            ]
        ]


viewReview : Form.View Msg -> Model -> Html Msg
viewReview v model =
    Layout.stack [ Layout.gap 4 ]
        [ Form.summary v
        , case Form.toValues Locale.en form model.form of
            Ok customer ->
                Alert.view [ Alert.tone Success, Alert.compact ]
                    ("Everything is filled in: " ++ customer.name ++ " with " ++ String.fromInt (List.length customer.contacts) ++ " contacts. Read it once more, then save.")

            Err _ ->
                Text.paragraph "Fix the problems above. Each line leads to its step and its field."
        , Layout.row [ Layout.wrap ]
            [ Button.view [ Button.small, Button.onClick (GoTo Account) ] "Edit account"
            , Button.view [ Button.small, Button.onClick (GoTo Contacts) ] "Edit contacts"
            , Button.view [ Button.small, Button.onClick (GoTo Delivery) ] "Edit delivery"
            ]
        , Checkbox.view
            [ Checkbox.id termsId
            , Checkbox.label "I accept the terms of delivery"
            , Checkbox.checked model.accepted
            , Checkbox.onCheck Accepted
            ]
        ]
