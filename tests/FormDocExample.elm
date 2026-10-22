module FormDocExample exposing (Model, Msg, init, update, view)

{-| The example of the module documentation of `Klar.Form`, compiled so that it
cannot go stale. A customer form with a text, a country, a long note, a
switch, a server that can refuse, and the leave flag.
-}

import Html exposing (Html)
import Klar.Button as Button
import Klar.Form as Form
import Klar.Form.Layout as FormLayout
import Klar.Form.Spec as Spec
import Klar.Ids as Ids exposing (Ids)
import Klar.Layout as Layout
import Klar.Locale as Locale
import Klar.Remote as Remote
import Klar.Select as Select
import Klar.TextArea as TextArea
import Klar.Validate as Validate



-- THE DECLARATION


type CountryId
    = CountryId String


countryIds : Ids CountryId
countryIds =
    Ids.make { toKey = \(CountryId code) -> code, fromKey = Just << CountryId }


type alias Fields =
    { name : Form.Field String
    , country : Form.Field (Maybe CountryId)
    , note : Form.Field String
    , preferred : Form.Field Bool
    }


type alias Values =
    { name : String
    , country : CountryId
    , note : Maybe String
    , preferred : Bool
    }


form : Form.Form () Fields Values
form =
    Spec.define "customer" Fields Values
        |> Spec.with (Spec.text "Name" |> Spec.required |> Spec.rules [ Validate.maxLength 80 ])
        |> Spec.with (Spec.choice countryIds "Country" |> Spec.required)
        |> Spec.with (Spec.text "Note" |> Spec.rules [ Validate.maxLength 500 ])
        |> Spec.with (Spec.toggle "Preferred customer")
        |> Spec.build


fields : Fields
fields =
    Form.fields form



-- THE MODEL AND THE UPDATE


type alias Model =
    { form : Form.State ()
    , status : FormLayout.Status
    }


type Msg
    = FormMsg Form.Msg
    | Save
    | Replied (List (Form.Problem ()))


init : Model
init =
    { form = Form.init form, status = FormLayout.Idle }


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        FormMsg inner ->
            Form.update form inner model.form
                |> Tuple.mapBoth (\state -> { model | form = state }) (Cmd.map FormMsg)

        Save ->
            case Form.toValues Locale.default form model.form of
                Ok values ->
                    ( { model | status = FormLayout.Submitting }, send values )

                Err _ ->
                    Form.reveal form model.form
                        |> Tuple.mapBoth (\state -> { model | form = state }) (Cmd.map FormMsg)

        Replied [] ->
            ( { model | form = Form.markClean model.form, status = FormLayout.Succeeded "Saved." }, Cmd.none )

        Replied found ->
            Form.rejected found form model.form
                |> Tuple.mapBoth (\state -> { model | form = state, status = FormLayout.Idle }) (Cmd.map FormMsg)



-- your request to the server; this package has no HTTP


send : Values -> Cmd Msg
send _ =
    Cmd.none



-- THE VIEW


view : Model -> Html Msg
view model =
    let
        v =
            Form.bind Locale.default FormMsg form model.form
    in
    FormLayout.view [ FormLayout.id "customer", FormLayout.onSubmit Save ]
        [ Form.summary v
        , FormLayout.section "Customer"
            "Who the invoice is for."
            [ FormLayout.grid 2
                [ Form.textInput v fields.name []
                , Form.select v fields.country (Remote.Loaded countries) []
                , FormLayout.fullRow (Form.textArea v fields.note [ TextArea.rows 3 ])
                , Form.switch v fields.preferred []
                ]
            ]
        , FormLayout.unsavedFlag [] (Form.isDirty model.form)
        , FormLayout.actions
            [ FormLayout.status [ FormLayout.id "customer" ] model.status
            , Layout.spacer
            , Button.view [ Button.primary, Button.submit ] "Save"
            ]
        ]


countries : List (Select.Option CountryId)
countries =
    [ Select.option (CountryId "no") "Norway"
    , Select.option (CountryId "se") "Sweden"
    ]
