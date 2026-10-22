module Main exposing (main)

{-| An edit form: the record is loaded (a `Remote`), edited, validated, and saved by a
backend that can answer with a problem per field or with a failure of its own.

The form is declared once with `Klar.Form.Model` (`Fm`): one `Fm.State` in the model and one
`Fm.Msg` in the messages, whatever the number of fields.

-}

import Browser
import Html exposing (Html)
import Klar
import Klar.Button as Button
import Klar.Card as Card
import Klar.ErrorState as ErrorState
import Klar.Form as Form
import Klar.Form.Model as Fm
import Klar.Layout as Layout
import Klar.Locale as Locale
import Klar.Overlay as Overlay exposing (Overlay)
import Klar.PageHeader as PageHeader
import Klar.Remote as Remote exposing (Remote(..))
import Klar.Select as Select
import Klar.Skeleton as Skeleton
import Klar.Toast as Toast
import Klar.Validate as Validate
import Process
import Task



-- THE RECORD AND THE BACKEND (a stand-in for HTTP)


type CountryId
    = CountryId String


type alias Customer =
    { name : String
    , email : String
    , creditLimit : Maybe Float
    , country : CountryId
    , active : Bool
    }


countries : List (Select.Option CountryId)
countries =
    [ Select.option (CountryId "no") "Norway"
    , Select.option (CountryId "se") "Sweden"
    , Select.option (CountryId "dk") "Denmark"
    ]


type SaveProblem
    = FieldProblem (Fields -> Fm.Field String) String
    | Failure Remote.Problem


{-| What the backend can answer: a problem per field, or a failure of its own.
Try the e-mail `taken@example.com` (a field problem) or the name `Crash` (a failure).
-}
saveCustomer : Customer -> Result (List SaveProblem) ()
saveCustomer customer =
    if customer.name == "Crash" then
        Err [ Failure (Remote.problem Remote.server) ]

    else if customer.email == "taken@example.com" then
        Err [ FieldProblem .email "This e-mail address belongs to another customer." ]

    else
        Ok ()


loadCustomer : Cmd Msg
loadCustomer =
    Process.sleep 500
        |> Task.map
            (\_ ->
                Ok
                    { name = "Aurora Logistics Ltd"
                    , email = "orders@aurora.example"
                    , creditLimit = Just 25000
                    , country = CountryId "no"
                    , active = True
                    }
            )
        |> Task.perform GotCustomer


sendSave : Customer -> Cmd Msg
sendSave customer =
    Process.sleep 700
        |> Task.map (\_ -> saveCustomer customer)
        |> Task.perform Saved



-- THE FORM, declared once


type alias Fields =
    { name : Fm.Field String
    , email : Fm.Field String
    , creditLimit : Fm.Field (Maybe Float)
    , country : Fm.Field (Maybe CountryId)
    , active : Fm.Field Bool
    }


countryIds : Fm.Ids CountryId
countryIds =
    Fm.ids { toKey = \(CountryId code) -> code, fromKey = Just << CountryId }


form : Fm.Form () Fields Customer
form =
    Fm.define "customer" Fields Customer
        |> Fm.with (Fm.text "Name" |> Fm.required |> Fm.rules [ Validate.maxLength 80 ])
        |> Fm.with (Fm.text "Email" |> Fm.required |> Fm.rules [ Validate.email ])
        |> Fm.with (Fm.number "Credit limit" |> Fm.range 0 100000 |> Fm.hint "In euros, 0 to 100 000.")
        |> Fm.with (Fm.choice countryIds "Country" |> Fm.required)
        |> Fm.with (Fm.toggle "Active")
        |> Fm.build


f : Fields
f =
    Fm.fields form



-- MODEL


type alias Model =
    { customer : Remote Customer
    , state : Fm.State ()
    , status : Form.Status
    , toasts : Toast.State Msg
    }


type Msg
    = GotCustomer (Result Remote.Problem Customer)
    | FormMsg Fm.Msg
    | ToastMsg Toast.Msg
    | Submit
    | Saved (Result (List SaveProblem) ())
    | Discard
    | Reload
    | NoOp


main : Program () Model Msg
main =
    Browser.element
        { init = \_ -> ( initialModel, loadCustomer )
        , update = update
        , view = view
        , subscriptions = \_ -> Sub.none
        }


initialModel : Model
initialModel =
    { customer = Loading
    , state = Fm.init form
    , status = Form.Idle
    , toasts = Toast.init
    }



-- UPDATE


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        GotCustomer (Ok customer) ->
            ( { model | customer = Loaded customer, state = fill customer model.state }, Cmd.none )

        GotCustomer (Err problem) ->
            ( { model | customer = Failed problem }, Cmd.none )

        FormMsg m ->
            let
                ( state, cmd ) =
                    Fm.update m model.state
            in
            ( { model | state = state }, Cmd.map FormMsg cmd )

        ToastMsg m ->
            let
                ( toasts, cmd ) =
                    Toast.update m model.toasts
            in
            ( { model | toasts = toasts }, Cmd.map ToastMsg cmd )

        Submit ->
            if model.status == Form.Submitting then
                ( model, Cmd.none )

            else
                case Fm.toValues Locale.default form model.state of
                    Ok customer ->
                        ( { model | status = Form.Submitting }, sendSave customer )

                    Err _ ->
                        -- show every problem, also in fields the user has not visited, and focus the summary
                        let
                            ( state, cmd ) =
                                Fm.reveal form model.state
                        in
                        ( { model | state = state }, Cmd.map FormMsg cmd )

        Saved (Ok ()) ->
            let
                ( toasts, cmd ) =
                    Toast.push [ Toast.success, Toast.message "Customer saved." ] model.toasts
            in
            ( { model | status = Form.Idle, state = Fm.markClean model.state, toasts = toasts }
            , Cmd.map ToastMsg cmd
            )

        Saved (Err problems) ->
            let
                fieldProblems =
                    List.filterMap
                        (\p ->
                            case p of
                                FieldProblem field text ->
                                    Just (Fm.problem (field f) text)

                                Failure _ ->
                                    Nothing
                        )
                        problems

                failure =
                    List.filterMap
                        (\p ->
                            case p of
                                Failure problem ->
                                    Just problem

                                FieldProblem _ _ ->
                                    Nothing
                        )
                        problems
                        |> List.head
            in
            case failure of
                Just problem ->
                    ( { model | status = Form.Failed problem }, Cmd.none )

                Nothing ->
                    let
                        ( state, cmd ) =
                            Fm.rejected fieldProblems form model.state
                    in
                    ( { model | status = Form.Idle, state = state }, Cmd.map FormMsg cmd )

        Discard ->
            ( { model | state = Fm.revert model.state }, Cmd.none )

        Reload ->
            ( { model | customer = Loading, status = Form.Idle }, loadCustomer )

        NoOp ->
            ( model, Cmd.none )


fill : Customer -> Fm.State () -> Fm.State ()
fill customer =
    Fm.set f.name customer.name
        >> Fm.set f.email customer.email
        >> Fm.set f.creditLimit customer.creditLimit
        >> Fm.set f.country (Just customer.country)
        >> Fm.set f.active customer.active
        >> Fm.markClean



-- VIEW


view : Model -> Html Msg
view model =
    Overlay.host
        { attributes = []
        , page = [ Klar.stylesheet, viewPage model ]
        , overlays = overlays model
        }


overlays : Model -> List (Overlay Msg)
overlays model =
    [ Toast.view ToastMsg [] model.toasts ]


viewPage : Model -> Html Msg
viewPage model =
    Layout.stack []
        [ PageHeader.view [ PageHeader.title "Edit customer" ]
        , case model.customer of
            Loaded _ ->
                viewForm model

            Failed problem ->
                ErrorState.view [ ErrorState.onRetry Reload ] problem

            _ ->
                Card.view [] [ Skeleton.lines 5 ]
        ]


viewForm : Model -> Html Msg
viewForm model =
    let
        v =
            Fm.bind Locale.default FormMsg form model.state

        attributes =
            [ Form.id "customer-form", Form.onSubmit Submit, Form.onRetry Submit ]
    in
    Form.view attributes
        [ Form.unsavedChanges [ Form.onDiscard Discard, Form.saving (model.status == Form.Submitting) ] (Fm.isDirty model.state)
        , Fm.summary v
        , Form.section "Customer"
            "Who we invoice."
            [ Form.grid 2
                [ Fm.textInput v f.name []
                , Fm.textInput v f.email []
                , Fm.numberInput v f.creditLimit []
                , Fm.select v f.country (Loaded countries) []
                , Fm.switch v f.active []
                ]
            ]
        , Form.actions
            [ Form.status attributes model.status
            , Layout.spacer
            , Button.view [ Button.primary, Button.submit, Button.loading (model.status == Form.Submitting) ] "Save"
            ]
        ]
