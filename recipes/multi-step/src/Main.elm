module Main exposing (main)

{-| A multi-step flow: three steps (customer, delivery, review) with a `Stepper`, one route per
step, validation before "Next", a submit that can fail, and a leave guard that asks before
the flow is left with unsaved input.

Every way out of the flow goes through `LeaveGuard.request`: a link (`LinkClicked`) and the
step strip. What it cannot stop is the browser's own Back button, see the KLAR GAP below.

-}

import Browser
import Browser.Navigation as Nav
import Html exposing (Html)
import Klar
import Klar.Button as Button
import Klar.Card as Card
import Klar.DescriptionList as DescriptionList
import Klar.Form as Form
import Klar.Layout as Layout
import Klar.LeaveGuard as LeaveGuard exposing (Answer(..))
import Klar.Locale as Locale
import Klar.Overlay as Overlay exposing (Overlay)
import Klar.PageHeader as PageHeader
import Klar.Radio as Radio
import Klar.Remote as Remote
import Klar.Stepper as Stepper
import Klar.TextInput as TextInput
import Klar.Toast as Toast
import Klar.Validate as Validate
import Process
import Task
import Url exposing (Url)



-- ROUTES


type Step
    = Customer
    | Delivery
    | Review


type Route
    = Home
    | Order Step
    | Done


steps : List Step
steps =
    [ Customer, Delivery, Review ]


stepIndex : Step -> Int
stepIndex step =
    case step of
        Customer ->
            0

        Delivery ->
            1

        Review ->
            2


routeToPath : Route -> String
routeToPath route =
    case route of
        Home ->
            "#/"

        Order Customer ->
            "#/order/customer"

        Order Delivery ->
            "#/order/delivery"

        Order Review ->
            "#/order/review"

        Done ->
            "#/order/done"


routeFromUrl : Url -> Route
routeFromUrl url =
    case url.fragment of
        Just "/order/customer" ->
            Order Customer

        Just "/order/delivery" ->
            Order Delivery

        Just "/order/review" ->
            Order Review

        Just "/order/done" ->
            Done

        _ ->
            Home



-- MODEL


type alias Draft =
    { customer : String
    , email : String
    , address : String
    , priority : String
    }


emptyDraft : Draft
emptyDraft =
    { customer = "", email = "", address = "", priority = "standard" }


{-| The one source of unsaved changes. A page with several forms has one constructor each.
-}
type Source
    = OrderDraft


{-| What a navigation wants: a plain value, so the guard can hold it.
-}
type Target
    = Go Route


type alias Model =
    { key : Nav.Key
    , route : Route
    , draft : Draft
    , showErrors : Bool
    , status : Form.Status
    , guard : LeaveGuard.Guard Source Target
    , toasts : Toast.State Msg
    }


type Msg
    = LinkClicked Browser.UrlRequest
    | UrlChanged Url
    | Edited Draft
    | Next Step
    | Back Step
    | StepSelected Int
    | Submit
    | Submitted (Result String ())
    | GuardMsg LeaveGuard.Msg
    | ToastMsg Toast.Msg
    | FocusField String
    | NoOp


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
      , draft = emptyDraft
      , showErrors = False
      , status = Form.Idle
      , guard = LeaveGuard.init "leave-dialog"
      , toasts = Toast.init
      }
    , Cmd.none
    )


{-| A stand-in for the request. The customer "Crash" makes it fail.
-}
sendOrder : Draft -> Cmd Msg
sendOrder draft =
    Process.sleep 700
        |> Task.map
            (\_ ->
                if draft.customer == "Crash" then
                    Err "The server could not take the order."

                else
                    Ok ()
            )
        |> Task.perform Submitted



-- VALIDATION, per step


fieldIds : { customer : String, email : String, address : String }
fieldIds =
    { customer = "order-customer", email = "order-email", address = "order-address" }



-- KLAR GAP: Klar.Form.Model has no steps (validate and reveal only the fields of the current step), so this flow keeps its own draft and uses Validate.


problems : Step -> Draft -> List Validate.Error
problems step draft =
    case step of
        Customer ->
            Validate.collect Locale.default
                [ ( fieldIds.customer, [ Validate.required ], draft.customer )
                , ( fieldIds.email, [ Validate.required, Validate.email ], draft.email )
                ]

        Delivery ->
            Validate.collect Locale.default [ ( fieldIds.address, [ Validate.required ], draft.address ) ]

        Review ->
            []


allProblems : Draft -> List Validate.Error
allProblems draft =
    List.concatMap (\step -> problems step draft) steps


{-| The furthest step the user may open: the first one with a problem.
-}
reached : Draft -> Int
reached draft =
    steps
        |> List.filter (\step -> not (List.isEmpty (problems step draft)))
        |> List.head
        |> Maybe.map stepIndex
        |> Maybe.withDefault 2



-- UPDATE


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        LinkClicked (Browser.Internal url) ->
            navigate (Go (routeFromUrl url)) model

        LinkClicked (Browser.External href) ->
            ( model, Nav.load href )

        UrlChanged url ->
            -- KLAR GAP: the browser Back and Forward buttons cannot be stopped, so the guard does not ask for them (the draft stays in the model).
            ( { model | route = routeFromUrl url, showErrors = False }, Cmd.none )

        Edited draft ->
            ( { model
                | draft = draft
                , status = Form.Idle
                , guard = LeaveGuard.setDirty OrderDraft (draft /= emptyDraft) model.guard
              }
            , Cmd.none
            )

        Next step ->
            if List.isEmpty (problems step model.draft) then
                ( { model | showErrors = False }, Nav.pushUrl model.key (routeToPath (Order (nextStep step))) )

            else
                ( { model | showErrors = True }, Form.focusSummary "order-form" NoOp )

        Back step ->
            ( { model | showErrors = False }, Nav.pushUrl model.key (routeToPath (Order (previousStep step))) )

        StepSelected index ->
            case List.drop index steps |> List.head of
                Just step ->
                    ( model, Nav.pushUrl model.key (routeToPath (Order step)) )

                Nothing ->
                    ( model, Cmd.none )

        Submit ->
            if model.status == Form.Submitting then
                ( model, Cmd.none )

            else
                ( { model | status = Form.Submitting }, sendOrder model.draft )

        Submitted (Ok ()) ->
            let
                ( toasts, cmd ) =
                    Toast.push [ Toast.success, Toast.message "Order placed." ] model.toasts
            in
            -- nothing is unsaved any more: clear the dirty mark, then leave the flow
            ( { model | draft = emptyDraft, status = Form.Idle, guard = LeaveGuard.setDirty OrderDraft False model.guard, toasts = toasts }
            , Cmd.batch [ Cmd.map ToastMsg cmd, Nav.pushUrl model.key (routeToPath Done) ]
            )

        Submitted (Err message) ->
            ( { model | status = Form.Failed (remoteProblem message) }, Cmd.none )

        GuardMsg m ->
            let
                ( guard, cmd, decision ) =
                    LeaveGuard.update m model.guard

                next =
                    { model | guard = guard }
            in
            case decision of
                Nothing ->
                    ( next, Cmd.map GuardMsg cmd )

                Just answer ->
                    -- "Leave": the changes are given up
                    let
                        (Go route) =
                            LeaveGuard.destination answer
                    in
                    ( { next | draft = emptyDraft, status = Form.Idle }
                    , Cmd.batch [ Cmd.map GuardMsg cmd, Nav.pushUrl model.key (routeToPath route) ]
                    )

        ToastMsg m ->
            let
                ( toasts, cmd ) =
                    Toast.update m model.toasts
            in
            ( { model | toasts = toasts }, Cmd.map ToastMsg cmd )

        FocusField id ->
            ( model, Form.focusField id NoOp )

        NoOp ->
            ( model, Cmd.none )


{-| Every navigation asks the guard first.
-}
navigate : Target -> Model -> ( Model, Cmd Msg )
navigate target model =
    case LeaveGuard.request target model.guard of
        Proceed (Go route) ->
            ( model, Nav.pushUrl model.key (routeToPath route) )

        Hold guard cmd ->
            ( { model | guard = guard }, Cmd.map GuardMsg cmd )


nextStep : Step -> Step
nextStep step =
    case step of
        Customer ->
            Delivery

        _ ->
            Review


previousStep : Step -> Step
previousStep step =
    case step of
        Review ->
            Delivery

        _ ->
            Customer


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
                , Button.view [ Button.primary, Button.href (routeToPath (Order Customer)) ] "New order"
                ]

        Done ->
            Layout.stack []
                [ PageHeader.view [ PageHeader.title "Order placed" ]
                , Button.view [ Button.href (routeToPath Home) ] "Back to orders"
                ]

        Order step ->
            viewStep model step


viewStep : Model -> Step -> Html Msg
viewStep model step =
    let
        errors =
            if model.showErrors then
                problems step model.draft

            else
                []

        attributes =
            [ Form.id "order-form", Form.onFocusField FocusField, Form.onRetry Submit, Form.onSubmit (submitMessage step) ]

        draft =
            model.draft
    in
    Layout.stack []
        [ PageHeader.view [ PageHeader.title "New order" ]
        , Stepper.view
            [ Stepper.current (stepIndex step), Stepper.onSelect StepSelected ]
            (List.map (stepLabel (reached draft)) steps)
        , Card.view []
            [ Form.view attributes
                [ Form.errorSummary attributes errors
                , case step of
                    Customer ->
                        Layout.stack []
                            [ TextInput.view
                                [ TextInput.id fieldIds.customer
                                , TextInput.label "Customer"
                                , TextInput.required
                                , TextInput.value draft.customer
                                , TextInput.onInput (\v -> Edited { draft | customer = v })
                                , TextInput.errorMaybe (Validate.errorFor fieldIds.customer errors)
                                ]
                            , TextInput.view
                                [ TextInput.id fieldIds.email
                                , TextInput.label "Email"
                                , TextInput.email
                                , TextInput.required
                                , TextInput.value draft.email
                                , TextInput.onInput (\v -> Edited { draft | email = v })
                                , TextInput.errorMaybe (Validate.errorFor fieldIds.email errors)
                                ]
                            ]

                    Delivery ->
                        Layout.stack []
                            [ TextInput.view
                                [ TextInput.id fieldIds.address
                                , TextInput.label "Address"
                                , TextInput.required
                                , TextInput.value draft.address
                                , TextInput.onInput (\v -> Edited { draft | address = v })
                                , TextInput.errorMaybe (Validate.errorFor fieldIds.address errors)
                                ]
                            , Radio.view
                                [ Radio.id "order-priority"
                                , Radio.label "Priority"
                                , Radio.options [ Radio.option "standard" "Standard, 3 to 5 days", Radio.option "express" "Express, next day" ]
                                , Radio.selected (Just draft.priority)
                                , Radio.onSelect (\v -> Edited { draft | priority = v })
                                ]
                            ]

                    Review ->
                        DescriptionList.view []
                            [ DescriptionList.text "Customer" draft.customer
                            , DescriptionList.text "Email" draft.email
                            , DescriptionList.text "Address" draft.address
                            , DescriptionList.text "Priority" draft.priority
                            ]
                , Form.actions
                    [ Button.view [ Button.id "cancel-order", Button.ghost, Button.href (routeToPath Home) ] "Cancel"
                    , Form.status attributes model.status
                    , Layout.spacer
                    , if step == Customer then
                        Html.text ""

                      else
                        Button.view [ Button.onClick (Back step) ] "Back"
                    , Button.view
                        [ Button.primary
                        , Button.submit
                        , Button.loading (model.status == Form.Submitting)
                        ]
                        (if step == Review then
                            "Place order"

                         else
                            "Next"
                        )
                    ]
                ]
            ]
        ]


submitMessage : Step -> Msg
submitMessage step =
    if step == Review then
        Submit

    else
        Next step


stepLabel : Int -> Step -> Stepper.Step
stepLabel furthest step =
    let
        label =
            case step of
                Customer ->
                    "Customer"

                Delivery ->
                    "Delivery"

                Review ->
                    "Review"
    in
    if stepIndex step > furthest then
        Stepper.step label |> Stepper.disabledStep

    else
        Stepper.step label
