module Examples.EditForm exposing (main)

{-| An edit form: the record is loaded (a `Remote`), edited, validated, and saved by a
backend that can answer with a problem per field or with a failure of its own.

The form is declared once with `Klar.Form.Spec`: one `Form.State` in the model and one
`Form.Msg` in the messages, whatever the number of fields.

The pattern:

1.  Declare the form once (`Spec.define ... |> Spec.with ... |> Spec.build`); the n-th `with` fills the n-th field of `Fields` and of `Customer`. Keep one `Form.State ()` and one `Form.Msg` in the model. The country id type is written as text once, with `Ids.make`.
2.  Load into the form with `Form.set` and then `Form.markClean`; `Form.isDirty` drives `FormLayout.unsavedChanges`, and `Form.revert` is Discard.
3.  `Form.submit` validates, focuses problems and returns at most one request with a ticket. A second submit while pending returns no request.
4.  `Form.finish` matches the ticket, marks the submitted values clean or retains the draft and shows the server's rejection or request failure. `Spec.serverKey` maps the backend's names; an unknown key stays in the summary as text.
5.  Retry runs the same Submit branch. The form handles focus on its stable `Submission.view` region, so the application needs no manual retry focus or second status in its model.
6.  `Form.summary` draws the list of problems and receives the focus; the application writes no DOM id and no draft record.
7.  The credit limit is money (`Spec.money`, `Form.moneyInput`): an exact `Klar.Money` with its limits in the declaration, never a `Float`.
8.  The page draws the loading, failed and loaded customer with `RemoteView.view`, never with a `case` of its own: a refresh keeps the form on the screen.

Try the e-mail `taken@example.com` (field problem), `unknown@example.com`
(a server problem without a field), and the name `Crash` (failure). Correct the
input and retry; the same form inputs and status region remain in place.

-}

import Browser
import Html exposing (Html)
import Klar
import Klar.Button as Button
import Klar.Form as Form
import Klar.Form.Layout as FormLayout
import Klar.Form.Spec as Spec
import Klar.Form.Submission as Submission
import Klar.Ids as Ids exposing (Ids)
import Klar.Layout as Layout
import Klar.Locale as Locale
import Klar.Money as Money exposing (Money)
import Klar.Overlay as Overlay exposing (Overlay)
import Klar.PageHeader as PageHeader
import Klar.Remote as Remote exposing (Remote(..))
import Klar.RemoteView as RemoteView
import Klar.Select as Select
import Klar.Theme exposing (Tone(..))
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


{-| What the backend can answer: a problem per field, or a failure of its own.
Try the e-mail `taken@example.com` (a field problem) or the name `Crash` (a failure).
-}
saveCustomer : Customer -> Result Submission.Error ()
saveCustomer customer =
    if customer.name == "Crash" then
        Err (Submission.Failed (Remote.problem Remote.server))

    else if customer.email == "taken@example.com" then
        Err (Submission.Rejected [ { field = "email_address", message = "This e-mail address belongs to another customer." } ])

    else if customer.email == "unknown@example.com" then
        Err (Submission.Rejected [ { field = "billing_account", message = "The billing account is suspended. Contact the accounts team." } ])

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


sendSave : Submission.Ticket -> Customer -> Cmd Msg
sendSave ticket customer =
    Process.sleep 1500
        |> Task.map (\_ -> saveCustomer customer)
        |> Task.perform (Saved ticket)



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
        |> Spec.with (Spec.text "Email" |> Spec.required |> Spec.rules [ Validate.email ] |> Spec.serverKey "email_address")
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
    , toasts : Toast.State Msg
    }


type Msg
    = GotCustomer (Result Remote.Problem Customer)
    | FormMsg Form.Msg
    | ToastMsg Toast.Msg
    | Submit
    | Retry
    | Saved Submission.Ticket (Result Submission.Error ())
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
    , toasts = Toast.init "toasts"
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
            let
                attempt =
                    Form.submit Locale.default form model.state
            in
            ( { model | state = attempt.state }
            , Cmd.batch
                [ Cmd.map FormMsg attempt.cmd
                , attempt.request |> Maybe.map (\request -> sendSave request.ticket request.values) |> Maybe.withDefault Cmd.none
                ]
            )

        Retry ->
            update Submit model

        Saved ticket result ->
            let
                ( state, cmd ) =
                    Form.finish ticket (Result.map (\_ -> "Customer saved.") result) form model.state
            in
            if state == model.state then
                ( model, Cmd.none )

            else
                case result of
                    Ok () ->
                        let
                            ( toasts, toastCmd ) =
                                Toast.push [ Toast.tone Success, Toast.message "Customer saved." ] model.toasts
                        in
                        ( { model | state = state, toasts = toasts }, Cmd.batch [ Cmd.map FormMsg cmd, Cmd.map ToastMsg toastCmd ] )

                    Err _ ->
                        ( { model | state = state }, Cmd.map FormMsg cmd )

        Discard ->
            ( { model | state = Form.revert form model.state }, Cmd.none )

        Reload ->
            -- the "Try again" button goes away: put the focus on the region, which stays
            ( { model | customer = Remote.refresh model.customer }
            , Cmd.batch [ loadCustomer, Klar.focus "customer-record" NoOp ]
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
    -- RemoteView draws the skeleton, the failure with "Try again" and old data
    -- that is being refreshed; the page title stays outside it.
    Layout.stack []
        [ PageHeader.view [ PageHeader.title "Edit customer" ]
        , Layout.stack []
            (RemoteView.view
                [ RemoteView.id "customer-record", RemoteView.onRetry Reload, RemoteView.loadingLabel "Loading the customer" ]
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
            [ FormLayout.id "customer"
            , FormLayout.onSubmit Submit
            , FormLayout.onRetry Retry
            , FormLayout.saving (Submission.status (Form.submission model.state) == FormLayout.Submitting)
            ]
    in
    FormLayout.view attributes
        [ FormLayout.unsavedChanges [ FormLayout.onDiscard Discard, FormLayout.saving (Submission.status (Form.submission model.state) == FormLayout.Submitting) ] (Form.isDirty model.state)
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
            [ Submission.view attributes (Form.submission model.state)
            , Layout.spacer
            , Button.view [ Button.primary, Button.submit, Button.loading (Submission.status (Form.submission model.state) == FormLayout.Submitting) ] "Save"
            ]
        ]
