module Examples.EditForm exposing (main)

{-| An edit form: the record is loaded (a `Remote`), edited, validated, and saved by a
backend that can answer with a problem per field or with a failure of its own.

The form is declared once with `Klar.Form.Spec`: one `Form.State` in the model and one
`Form.Msg` in the messages, whatever the number of fields.

The pattern:

1.  Declare the form once (`Spec.define ... |> Spec.with ... |> Spec.build`); the n-th `with` fills the n-th field of `Fields` and of `Customer`. Keep one `Form.State ()` and one `Form.Msg` in the model. The country id type is written as text once, with `Ids.make`.
2.  Load into the form with `Form.set` and then `Form.markClean`; `Form.isDirty` drives `FormLayout.unsavedChanges`, and `Form.revert` is Discard.
3.  On submit: `Form.toValues` gives the record or the problems; on problems call `Form.reveal` (shows all, focuses the summary).
4.  A save sets `FormLayout.Submitting`; the answer is `Form.markClean` plus a toast, or `Form.rejected` with `Form.problem field message` for each field problem (shown at the field and in the summary until that field is edited), or `FormLayout.Failed problem` for a failure with a retry button.
5.  The retry button of a failure gets its own message (`Retry`): it runs `Submit` and `FormLayout.focusStatus`, because "Try again" is replaced by "Saving ..." the moment it is pressed and focus would fall to the page. `Form.rejected` (field problems from the server) already moves focus to the summary.
6.  `Form.summary` draws the list of problems and receives the focus; the application writes no DOM id and no draft record.
7.  The credit limit is money (`Spec.money`, `Form.moneyInput`): an exact `Klar.Money` with its limits in the declaration, never a `Float`.
8.  The page draws the loading, failed and loaded customer with `RemoteView.view`, never with a `case` of its own: a refresh keeps the form on the screen.

Try the e-mail `taken@example.com` (field problem) and the name `Crash` (failure).

-}

import Browser
import Html exposing (Html)
import Klar
import Klar.Button as Button
import Klar.Form as Form
import Klar.Form.Layout as FormLayout
import Klar.Form.Spec as Spec
import Klar.Ids as Ids exposing (Ids)
import Klar.Layout as Layout
import Klar.Locale as Locale
import Klar.Money as Money exposing (Money)
import Klar.Overlay as Overlay exposing (Overlay)
import Klar.PageHeader as PageHeader
import Klar.Remote as Remote exposing (Remote(..))
import Klar.RemoteView as RemoteView
import Klar.Select as Select
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
    , creditLimit : Maybe Money
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
    = FieldProblem (Fields -> Form.Field String) String
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
                    , creditLimit = Money.fromMinor Money.eur 2500000
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
    { name : Form.Field String
    , email : Form.Field String
    , creditLimit : Form.Field (Maybe Money)
    , country : Form.Field (Maybe CountryId)
    , active : Form.Field Bool
    }


countryIds : Ids CountryId
countryIds =
    Ids.make { toKey = \(CountryId code) -> code, fromKey = Just << CountryId }


form : Form.Form () Fields Customer
form =
    Spec.define "customer" Fields Customer
        |> Spec.with (Spec.text "Name" |> Spec.required |> Spec.rules [ Validate.maxLength 80 ])
        |> Spec.with (Spec.text "Email" |> Spec.required |> Spec.rules [ Validate.email ])
        |> Spec.with
            (Spec.money Money.eur "Credit limit"
                |> Spec.minMoney (Money.zero Money.eur)
                |> Spec.maxMoney highestCreditLimit
                |> Spec.hint "0 to 100 000."
            )
        |> Spec.with (Spec.choice countryIds "Country" |> Spec.required)
        |> Spec.with (Spec.toggle "Active")
        |> Spec.build


f : Fields
f =
    Form.fields form


highestCreditLimit : Money
highestCreditLimit =
    Money.fromMinor Money.eur 10000000 |> Maybe.withDefault (Money.zero Money.eur)



-- MODEL


type alias Model =
    { customer : Remote Customer
    , state : Form.State ()
    , status : FormLayout.Status
    , toasts : Toast.State Msg
    }


type Msg
    = GotCustomer (Result Remote.Problem Customer)
    | FormMsg Form.Msg
    | ToastMsg Toast.Msg
    | Submit
    | Retry
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
    , state = Form.init form
    , status = FormLayout.Idle
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
                    Form.update form m model.state
            in
            ( { model | state = state }, Cmd.map FormMsg cmd )

        ToastMsg m ->
            let
                ( toasts, cmd ) =
                    Toast.update m model.toasts
            in
            ( { model | toasts = toasts }, Cmd.map ToastMsg cmd )

        Submit ->
            if model.status == FormLayout.Submitting then
                ( model, Cmd.none )

            else
                case Form.toValues Locale.default form model.state of
                    Ok customer ->
                        ( { model | status = FormLayout.Submitting }, sendSave customer )

                    Err _ ->
                        -- show every problem, also in fields the user has not visited, and focus the summary
                        let
                            ( state, cmd ) =
                                Form.reveal form model.state
                        in
                        ( { model | state = state }, Cmd.map FormMsg cmd )

        Retry ->
            -- "Try again" is replaced by "Saving ..." the moment it is pressed: move focus to the status line
            let
                ( retried, cmd ) =
                    update Submit model
            in
            ( retried, Cmd.batch [ cmd, FormLayout.focusStatus "customer-form" NoOp ] )

        Saved (Ok ()) ->
            let
                ( toasts, cmd ) =
                    Toast.push [ Toast.success, Toast.message "Customer saved." ] model.toasts
            in
            ( { model | status = FormLayout.Idle, state = Form.markClean model.state, toasts = toasts }
            , Cmd.map ToastMsg cmd
            )

        Saved (Err problems) ->
            let
                fieldProblems =
                    List.filterMap
                        (\p ->
                            case p of
                                FieldProblem field text ->
                                    Just (Form.problem (field f) text)

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
                    ( { model | status = FormLayout.Failed problem }, Cmd.none )

                Nothing ->
                    let
                        ( state, cmd ) =
                            Form.rejected fieldProblems form model.state
                    in
                    ( { model | status = FormLayout.Idle, state = state }, Cmd.map FormMsg cmd )

        Discard ->
            ( { model | state = Form.revert form model.state }, Cmd.none )

        Reload ->
            -- the "Try again" button goes away: put the focus on the region, which stays
            ( { model | customer = Remote.refresh model.customer, status = FormLayout.Idle }
            , Cmd.batch [ loadCustomer, Klar.focus "customer" NoOp ]
            )

        NoOp ->
            ( model, Cmd.none )


fill : Customer -> Form.State () -> Form.State ()
fill customer =
    Form.set f.name customer.name
        >> Form.set f.email customer.email
        >> Form.set f.creditLimit customer.creditLimit
        >> Form.set f.country (Just customer.country)
        >> Form.set f.active customer.active
        >> Form.markClean



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
        , Layout.stack []
            (RemoteView.view
                [ RemoteView.id "customer", RemoteView.onRetry Reload, RemoteView.loadingLabel "Loading the customer" ]
                model.customer
                (\_ -> [ viewForm model ])
            )
        ]


viewForm : Model -> Html Msg
viewForm model =
    let
        v =
            Form.bind Locale.default FormMsg form model.state

        attributes =
            [ FormLayout.id "customer-form", FormLayout.onSubmit Submit, FormLayout.onRetry Retry ]
    in
    FormLayout.view attributes
        [ FormLayout.unsavedChanges [ FormLayout.onDiscard Discard, FormLayout.saving (model.status == FormLayout.Submitting) ] (Form.isDirty model.state)
        , Form.summary v
        , FormLayout.section "Customer"
            "Who we invoice."
            [ FormLayout.grid 2
                [ Form.textInput v f.name []
                , Form.textInput v f.email []
                , Form.moneyInput v f.creditLimit []
                , Form.select v f.country (Loaded countries) []
                , Form.switch v f.active []
                ]
            ]
        , FormLayout.actions
            [ FormLayout.status attributes model.status
            , Layout.spacer
            , Button.view [ Button.primary, Button.submit, Button.loading (model.status == FormLayout.Submitting) ] "Save"
            ]
        ]
