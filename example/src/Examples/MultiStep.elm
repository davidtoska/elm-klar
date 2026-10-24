module Examples.MultiStep exposing (main)

{-| A multi-step flow: three steps (customer, delivery, review) with a `Stepper`, validation
before "Next", a review step that lists what is wrong, a submit that can fail, and a leave guard
that asks before the flow is left with unsaved input.

The form owns the steps (`Klar.Form.Spec.step`): which step the user is on, what "Next" checks,
the stepper, and the summary on the review step. The application owns the address of the flow
(`#/order`) and the leave guard. Every way out goes through the guard: a link
(`LeaveGuard.request`) and the browser's Back and Forward buttons (`LeaveGuard.onUrlChange`).

The pattern:

1.  Declare the steps with the fields: `Spec.step Customer "Customer" |> Spec.with ... |> Spec.step Review "Review"`. A last step with no fields is the review step. The form keeps which step the user is on; the application has only `Home | Order | Done` routes.
2.  "Next" and "Place order" are one button: `Form.advance` checks the current step (or the whole form on the last), shows the problems, focuses the summary, and gives `submit = Just values` when everything passed. "Back" is `Form.back`. `Form.stepper` draws the steps and marks the ones with problems; `Form.summary` on the review step lists every problem with a button that goes there. The fields of the current step are drawn inside `Form.stepBody v [ ... ]`: it keys them by step, so Elm makes new inputs for the next step instead of reusing the focused input of the old one for the field at the same place (which `advance`'s focus move would blur, and show "Required" on a field nobody touched).
3.  `LeaveGuard.Guard Source Route` is made with `initAt` and told `LeaveGuard.setDirty OrderForm (Form.isDirty state)` after each form message.
4.  Links ask first: `LeaveGuard.request`. The browser Back and Forward buttons are answered by `LeaveGuard.onUrlChange` in `UrlChanged`: with unsaved input the page stays and the dialog opens. "Leave" resets the form and pushes the held route; "Stay" needs no code.
5.  The submit sets `FormLayout.Submitting`, then `FormLayout.Failed problem` (with a retry button) or a toast, a clean form and the done route. Try the customer `Crash` for a failure. The retry button has its own message (`Retry`): it runs `Next` and `FormLayout.focusStatus`, because "Try again" is replaced by "Saving ..." the moment it is pressed and focus would fall to the page.

-}

import Browser
import Browser.Navigation as Nav
import Html exposing (Html)
import Klar
import Klar.Button as Button
import Klar.Card as Card
import Klar.DescriptionList as DescriptionList
import Klar.Form as Form
import Klar.Form.Layout as FormLayout
import Klar.Form.Spec as Spec
import Klar.Layout as Layout
import Klar.LeaveGuard as LeaveGuard exposing (Answer(..))
import Klar.Locale as Locale
import Klar.Overlay as Overlay exposing (Overlay)
import Klar.PageHeader as PageHeader
import Klar.Remote as Remote
import Klar.Theme exposing (Tone(..))
import Klar.Toast as Toast
import Klar.Validate as Validate
import Process
import Task
import Url exposing (Url)



-- ROUTES


type Route
    = Home
    | Order
    | Done


routeToPath : Route -> String
routeToPath route =
    case route of
        Home ->
            "#/"

        Order ->
            "#/order"

        Done ->
            "#/order/done"


routeFromUrl : Url -> Route
routeFromUrl url =
    case url.fragment of
        Just "/order" ->
            Order

        Just "/order/done" ->
            Done

        _ ->
            Home



-- THE FORM, declared once


type Step
    = Customer
    | Delivery
    | Review


type alias Fields =
    { name : Form.Field String
    , email : Form.Field String
    , address : Form.Field String
    , express : Form.Field Bool
    }


type alias OrderValues =
    { name : String
    , email : String
    , address : String
    , express : Bool
    }


form : Form.Form Step Fields OrderValues
form =
    Spec.define "order" Fields OrderValues
        |> Spec.step Customer "Customer"
        |> Spec.with (Spec.text "Customer" |> Spec.required)
        |> Spec.with (Spec.text "Email" |> Spec.required |> Spec.rules [ Validate.email ])
        |> Spec.step Delivery "Delivery"
        |> Spec.with (Spec.text "Address" |> Spec.required)
        |> Spec.with (Spec.toggle "Express" |> Spec.hint "Next day instead of 3 to 5 days.")
        |> Spec.step Review "Review"
        |> Spec.build


f : Fields
f =
    Form.fields form


{-| A stand-in for the request. The customer "Crash" makes it fail.
-}
sendOrder : OrderValues -> Cmd Msg
sendOrder order =
    Process.sleep 700
        |> Task.map
            (\_ ->
                if order.name == "Crash" then
                    Err "The server could not take the order."

                else
                    Ok ()
            )
        |> Task.perform Submitted



-- MODEL


{-| The one source of unsaved changes. A page with several forms has one constructor each.
-}
type Source
    = OrderForm


type alias Model =
    { key : Nav.Key
    , route : Route
    , order : Form.State Step
    , status : FormLayout.Status
    , guard : LeaveGuard.Guard Source Route
    , toasts : Toast.State Msg
    }


type Msg
    = LinkClicked Browser.UrlRequest
    | UrlChanged Url
    | FormMsg Form.Msg
    | Next
    | Retry
    | Back
    | NoOp
    | Submitted (Result String ())
    | GuardMsg LeaveGuard.Msg
    | ToastMsg Toast.Msg


main : Program () Model Msg
main =
    Browser.application
        { init = init
        , update = update
        , view = view
        , subscriptions = \_ -> Sub.none
        , onUrlRequest = LinkClicked
        , onUrlChange = UrlChanged
        }


init : () -> Url -> Nav.Key -> ( Model, Cmd Msg )
init _ url key =
    ( { key = key
      , route = routeFromUrl url
      , order = Form.init form
      , status = FormLayout.Idle
      , guard = LeaveGuard.initAt "leave-dialog" key url
      , toasts = Toast.init "toasts"
      }
    , Cmd.none
    )



-- UPDATE


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        LinkClicked (Browser.Internal url) ->
            case LeaveGuard.request (routeFromUrl url) model.guard of
                Proceed route ->
                    ( model, Nav.pushUrl model.key (routeToPath route) )

                Hold guard cmd ->
                    ( { model | guard = guard }, Cmd.map GuardMsg cmd )

        LinkClicked (Browser.External href) ->
            ( model, Nav.load href )

        UrlChanged url ->
            -- also the browser's Back and Forward: with unsaved input the guard keeps the page and asks
            case LeaveGuard.onUrlChange routeFromUrl url model.guard of
                ( guard, cmd, Just route ) ->
                    ( { model | route = route, guard = guard }, Cmd.map GuardMsg cmd )

                ( guard, cmd, Nothing ) ->
                    ( { model | guard = guard }, Cmd.map GuardMsg cmd )

        FormMsg inner ->
            let
                ( order, cmd ) =
                    Form.update form inner model.order
            in
            ( edited { model | order = order, status = FormLayout.Idle }, Cmd.map FormMsg cmd )

        Next ->
            if model.status == FormLayout.Submitting then
                ( model, Cmd.none )

            else
                let
                    next =
                        Form.advance form model.order
                in
                case next.submit of
                    Just order ->
                        ( { model | order = next.state, status = FormLayout.Submitting }
                        , Cmd.batch [ Cmd.map FormMsg next.cmd, sendOrder order ]
                        )

                    Nothing ->
                        ( { model | order = next.state }, Cmd.map FormMsg next.cmd )

        Retry ->
            -- "Try again" is replaced by "Saving ..." the moment it is pressed: move focus to the status line
            let
                ( retried, cmd ) =
                    update Next model
            in
            ( retried, Cmd.batch [ cmd, FormLayout.focusStatus "order-form" NoOp ] )

        NoOp ->
            ( model, Cmd.none )

        Back ->
            let
                ( order, cmd ) =
                    Form.back form model.order
            in
            ( { model | order = order }, Cmd.map FormMsg cmd )

        Submitted (Ok ()) ->
            let
                ( toasts, cmd ) =
                    Toast.push [ Toast.tone Success, Toast.message "Order placed." ] model.toasts
            in
            -- nothing is unsaved any more: start a clean form, then leave the flow
            ( edited { model | order = Form.init form, status = FormLayout.Idle, toasts = toasts }
            , Cmd.batch [ Cmd.map ToastMsg cmd, Nav.pushUrl model.key (routeToPath Done) ]
            )

        Submitted (Err message) ->
            ( { model | status = FormLayout.Failed (remoteProblem message) }, Cmd.none )

        GuardMsg inner ->
            let
                ( guard, cmd, decision ) =
                    LeaveGuard.update inner model.guard

                next =
                    { model | guard = guard }
            in
            case decision of
                Nothing ->
                    ( next, Cmd.map GuardMsg cmd )

                Just answer ->
                    -- "Leave": the changes are given up
                    ( { next | order = Form.init form, status = FormLayout.Idle }
                    , Cmd.batch
                        [ Cmd.map GuardMsg cmd
                        , Nav.pushUrl model.key (routeToPath (LeaveGuard.destination answer))
                        ]
                    )

        ToastMsg inner ->
            let
                ( toasts, cmd ) =
                    Toast.update inner model.toasts
            in
            ( { model | toasts = toasts }, Cmd.map ToastMsg cmd )


{-| Tell the guard whether the form holds unsaved input.
-}
edited : Model -> Model
edited model =
    { model | guard = LeaveGuard.setDirty OrderForm (Form.isDirty model.order) model.guard }


remoteProblem : String -> Remote.Problem
remoteProblem message =
    Remote.problem Remote.server |> Remote.withDetail message



-- VIEW


view : Model -> Browser.Document Msg
view model =
    { title = "New order"
    , body =
        [ Klar.stylesheet
        , Overlay.host { attributes = [], page = [ viewPage model ], overlays = overlays model }
        ]
    }


overlays : Model -> List (Overlay Msg)
overlays model =
    [ LeaveGuard.view GuardMsg
        [ LeaveGuard.title "Leave without placing the order?"
        , LeaveGuard.message "What you have typed is lost."
        ]
        model.guard
    , Toast.view ToastMsg [] model.toasts
    ]


viewPage : Model -> Html Msg
viewPage model =
    case model.route of
        Home ->
            Layout.stack []
                [ PageHeader.view [ PageHeader.title "Orders" ]
                , Button.view [ Button.primary, Button.href (routeToPath Order) ] "New order"
                ]

        Done ->
            Layout.stack []
                [ PageHeader.view [ PageHeader.title "Order placed" ]
                , Button.view [ Button.href (routeToPath Home) ] "Back to orders"
                ]

        Order ->
            viewOrder model


viewOrder : Model -> Html Msg
viewOrder model =
    let
        v =
            Form.bind Locale.default FormMsg form model.order

        step =
            Form.currentStep form model.order

        attributes =
            [ FormLayout.id "order-form", FormLayout.onSubmit Next, FormLayout.onRetry Retry ]
    in
    Layout.stack []
        [ PageHeader.view [ PageHeader.title "New order" ]
        , Form.stepper v []
        , Card.view []
            [ FormLayout.view attributes
                [ Form.summary v
                , -- keyed by the step: the inputs of one step are not reused for the next
                  Form.stepBody v
                    [ case step of
                        Just Customer ->
                            Layout.stack []
                                [ Form.textInput v f.name []
                                , Form.textInput v f.email []
                                ]

                        Just Delivery ->
                            Layout.stack []
                                [ Form.textInput v f.address []
                                , Form.switch v f.express []
                                ]

                        _ ->
                            viewReview model
                    ]
                , FormLayout.actions
                    [ Button.view [ Button.id "cancel-order", Button.ghost, Button.href (routeToPath Home) ] "Cancel"
                    , FormLayout.status attributes model.status
                    , Layout.spacer
                    , if step == Just Customer then
                        Html.text ""

                      else
                        Button.view [ Button.onClick Back ] "Back"
                    , Button.view
                        [ Button.primary
                        , Button.submit
                        , Button.loading (model.status == FormLayout.Submitting)
                        ]
                        (if step == Just Review then
                            "Place order"

                         else
                            "Next"
                        )
                    ]
                ]
            ]
        ]


viewReview : Model -> Html Msg
viewReview model =
    DescriptionList.view []
        [ DescriptionList.text "Customer" (Form.get f.name model.order)
        , DescriptionList.text "Email" (Form.get f.email model.order)
        , DescriptionList.text "Address" (Form.get f.address model.order)
        , DescriptionList.text "Delivery"
            (if Form.get f.express model.order then
                "Express, next day"

             else
                "Standard, 3 to 5 days"
            )
        ]
