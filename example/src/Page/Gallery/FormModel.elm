module Page.Gallery.FormModel exposing (Model, Msg, init, subscriptions, update, view)

{-| Gallery page: the form model. Step 1 of the supplier onboarding application
(a company: four texts, a country, several categories, a server problem on one
text, a dirty check, load and read back a record), rewritten on `Klar.Form.Model`
with neutral names (a customer account instead of a supplier).

The application's own code is between the markers `A`, `B` and `C`; the line
counts against the old version are in `design/FORM-MODEL.md` section 9.4.

-}

import Html exposing (Html)
import Klar.Button as Button
import Klar.Form as Form
import Klar.Form.Layout as FormLayout
import Klar.Form.Spec as Spec
import Klar.Ids as Ids exposing (Ids)
import Klar.Layout as Layout
import Klar.Locale as Locale exposing (Locale)
import Klar.MultiSelect as MultiSelect
import Klar.Remote as Remote
import Klar.Select as Select
import Klar.Text as Text
import Klar.TextInput as TextInput
import Klar.Validate as Validate
import Showcase.Doc as Doc



-- THE APPLICATION'S DOMAIN (not part of the count: every version has it)


type CountryId
    = CountryId String


type SegmentId
    = SegmentId Int


type alias Account =
    { name : String
    , legalName : String
    , registrationNumber : String
    , website : String
    , country : CountryId
    , segments : List SegmentId
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
    , Select.option (SegmentId 6) "Software" |> Select.withGroup "Services"
    ]


{-| The account the "Load" button loads.
-}
savedAccount : Account
savedAccount =
    { name = "Northwind Trading"
    , legalName = "Northwind Trading AS"
    , registrationNumber = "12345678"
    , website = "https://northwind.example"
    , country = CountryId "no"
    , segments = [ SegmentId 1, SegmentId 5 ]
    }


{-| The dummy backend: what the server says to a save.
-}
type BackendField
    = Name
    | LegalName
    | Registration
    | Website
    | CountryField


type alias BackendProblem =
    { field : BackendField, message : String }


save : { a | name : String, registration : String, country : CountryId } -> List BackendProblem
save values =
    List.filterMap identity
        [ if values.name == "Acme Trading" then
            Just { field = Name, message = "A customer with this name already exists." }

          else
            Nothing
        , if values.registration == "00000000" then
            Just { field = Registration, message = "This registration number belongs to another customer." }

          else
            Nothing
        , if values.country == CountryId "pl" then
            Just { field = CountryField, message = "We cannot take customers in this country yet." }

          else
            Nothing
        ]



-- A: THE DECLARATION


type alias Fields =
    { name : Form.Field String
    , legalName : Form.Field String
    , registration : Form.Field String
    , website : Form.Field String
    , country : Form.Field (Maybe CountryId)
    , segments : Form.Field (List SegmentId)
    }


type alias Values =
    { name : String
    , legalName : String
    , registration : String
    , website : Maybe String
    , country : CountryId
    , segments : List SegmentId
    }


countryIds : Ids CountryId
countryIds =
    Ids.make { toKey = \(CountryId code) -> code, fromKey = Just << CountryId }


segmentIds : Ids SegmentId
segmentIds =
    Ids.make { toKey = \(SegmentId n) -> String.fromInt n, fromKey = Maybe.map SegmentId << String.toInt }


form : Form.Form () Fields Values
form =
    Spec.define "account" Fields Values
        |> Spec.with (Spec.text "Name" |> Spec.required |> Spec.rules [ Validate.maxLength 80 ])
        |> Spec.with (Spec.text "Legal name" |> Spec.required)
        |> Spec.with (Spec.text "Registration number" |> Spec.required |> Spec.rules [ registrationFormat ])
        |> Spec.with (Spec.text "Website" |> Spec.rules [ httpUrl ])
        |> Spec.with (Spec.choice countryIds "Country" |> Spec.required)
        |> Spec.with (Spec.choices segmentIds "Segments" |> Spec.atLeast 1)
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
    Validate.custom (\text -> String.trim text == "" || String.startsWith "https://" text || String.startsWith "http://" text)
        { nb = "Må starte med http:// eller https://", en = "Must start with http:// or https://" }



-- B: LOAD, READ BACK, AND THE SERVER'S PROBLEMS


fill : Account -> Form.State () -> Form.State ()
fill a =
    Form.set f.name a.name
        >> Form.set f.legalName a.legalName
        >> Form.set f.registration a.registrationNumber
        >> Form.set f.website a.website
        >> Form.set f.country (Just a.country)
        >> Form.set f.segments a.segments


toAccount : Values -> Account
toAccount v =
    { name = v.name
    , legalName = v.legalName
    , registrationNumber = v.registration
    , website = Maybe.withDefault "" v.website
    , country = v.country
    , segments = v.segments
    }


fromBackend : BackendProblem -> Form.Problem ()
fromBackend p =
    case p.field of
        Name ->
            Form.problem f.name p.message

        LegalName ->
            Form.problem f.legalName p.message

        Registration ->
            Form.problem f.registration p.message

        Website ->
            Form.problem f.website p.message

        CountryField ->
            Form.problem f.country p.message



-- C: THE MODEL, THE UPDATE AND THE VIEW


type alias Model =
    { form : Form.State ()
    , status : FormLayout.Status
    , saved : Maybe Account
    }


type Msg
    = FormMsg Form.Msg
    | Save
    | Load
    | Revert


init : ( Model, Cmd Msg )
init =
    ( { form = Form.init form, status = FormLayout.Idle, saved = Nothing }, Cmd.none )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        FormMsg inner ->
            Form.update form inner model.form |> Tuple.mapBoth (\s -> { model | form = s }) (Cmd.map FormMsg)

        Load ->
            ( { model | form = Form.init form |> fill savedAccount |> Form.markClean, status = FormLayout.Idle }, Cmd.none )

        Revert ->
            ( { model | form = Form.revert form model.form, status = FormLayout.Idle }, Cmd.none )

        Save ->
            case Form.toValues Locale.default form model.form of
                Err _ ->
                    Form.reveal form model.form |> Tuple.mapBoth (\s -> { model | form = s }) (Cmd.map FormMsg)

                Ok values ->
                    case save values of
                        [] ->
                            ( { model | form = Form.markClean model.form, status = FormLayout.Succeeded "Saved.", saved = Just (toAccount values) }, Cmd.none )

                        problems ->
                            Form.rejected (List.map fromBackend problems) form model.form
                                |> Tuple.mapBoth (\s -> { model | form = s, status = FormLayout.Idle }) (Cmd.map FormMsg)


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none


accountForm : Locale -> Model -> Html Msg
accountForm locale model =
    let
        v =
            Form.bind locale FormMsg form model.form
    in
    FormLayout.view [ FormLayout.id "account", FormLayout.onSubmit Save ]
        [ Form.summary v
        , FormLayout.unsavedFlag [ FormLayout.locale locale ] (Form.isDirty model.form)
        , FormLayout.section "Account"
            "Who the customer is, as registered."
            [ FormLayout.grid 2
                [ Form.textInput v f.name [ TextInput.hint "How the customer appears in lists." ]
                , Form.textInput v f.legalName []
                , Form.textInput v f.registration [ TextInput.placeholder "8 digits" ]
                , Form.textInput v f.website [ TextInput.url ]
                , Form.select v f.country (Remote.Loaded countryOptions) []
                , Form.multiSelect v f.segments (Remote.Loaded segmentOptions) []
                ]
            ]
        , FormLayout.actions
            [ FormLayout.status [ FormLayout.locale locale ] model.status
            , Layout.spacer
            , Button.view [ Button.onClick Revert, Button.disabled (not (Form.isDirty model.form)) ] "Revert"
            , Button.view [ Button.onClick Load ] "Load saved account"
            , Button.view [ Button.primary, Button.submit ] "Save"
            ]
        ]



-- THE PAGE (not part of the count)


view : Locale -> Model -> Html Msg
view locale model =
    Doc.page
        { title = "Form model"
        , description = "A form declared once: the values of every field live in one state that knows when it is dirty, loads and returns a record, and takes the server's problems per field. Try: press Save on the empty form (every problem shows and the focus moves to the summary), type the name Acme Trading and the registration number 00000000, then Save (the server refuses and its words show at the fields until you edit them), or Load a saved account and type a letter and delete it again (clean again)."
        }
        [ Doc.section "Customer account"
            "Step 1 of the supplier onboarding application, on the form model."
            [ Doc.example { title = "A customer account", description = Nothing, code = Nothing } (accountForm locale model)
            , Layout.stack [ Layout.gap 2 ]
                [ Text.caption
                    ("Unsaved changes: "
                        ++ (if Form.isDirty model.form then
                                "yes"

                            else
                                "no"
                           )
                    )
                , Text.caption
                    (case model.saved of
                        Just account ->
                            "Last saved: " ++ account.name ++ ", " ++ account.registrationNumber ++ ", " ++ String.fromInt (List.length account.segments) ++ " segments."

                        Nothing ->
                            "Nothing saved yet."
                    )
                ]
            ]
        ]
