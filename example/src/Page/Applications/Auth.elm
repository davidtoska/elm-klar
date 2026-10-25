module Page.Applications.Auth exposing (Model, Msg(..), Phase(..), init, leave, update, view)

{-| Account screens sharing one lifecycle. Timers carry a generation, never a
password; leaving a screen clears secrets and invalidates outstanding responses.
-}

import Html exposing (Html)
import Html.Events as Events
import Klar
import Klar.Button as Button
import Klar.Checkbox as Checkbox
import Klar.Icon as Icon
import Klar.Layout as Layout
import Klar.Locale as Locale
import Klar.PasswordInput as Password
import Klar.SegmentedControl as Segmented
import Klar.Text as Text
import Klar.TextInput as Input
import Klar.Theme exposing (Tone(..))
import Klar.Validate as Validate
import Page.Applications.Catalog as Catalog exposing (Page(..))
import Patterns.Workspace as Pattern
import Process
import Task


type Phase
    = Idle
    | Working
    | Done
    | Failed


type alias Model =
    { email : String
    , name : String
    , password : Password.State
    , confirmation : Password.State
    , accepted : Bool
    , submitted : Bool
    , phase : Phase
    , scenario : String
    , ticket : Int
    , message : String
    }


init : Model
init =
    { email = "", name = "", password = Password.init "auth-password", confirmation = Password.init "auth-confirmation", accepted = False, submitted = False, phase = Idle, scenario = "success", ticket = 0, message = "" }


type Msg
    = Email String
    | Name String
    | PasswordMsg Password.Msg
    | ConfirmationMsg Password.Msg
    | Accept Bool
    | Scenario String
    | Submit Page
    | Social Page String
    | Finished Int Page String
    | StartAgain
    | NoOp


leave : Model -> Model
leave model =
    { model | password = Password.clear model.password, confirmation = Password.clear model.confirmation, phase = Idle, message = "", submitted = False, ticket = model.ticket + 1 }


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        Email value ->
            ( { model | email = value }, Cmd.none )

        Name value ->
            ( { model | name = value }, Cmd.none )

        PasswordMsg inner ->
            let
                ( state, cmd ) =
                    Password.update inner model.password
            in
            ( { model | password = state }, Cmd.map PasswordMsg cmd )

        ConfirmationMsg inner ->
            let
                ( state, cmd ) =
                    Password.update inner model.confirmation
            in
            ( { model | confirmation = state }, Cmd.map ConfirmationMsg cmd )

        Accept value ->
            ( { model | accepted = value }, Cmd.none )

        Scenario value ->
            ( { model | scenario = value }, Cmd.none )

        Submit page ->
            if model.phase == Working then
                ( model, Cmd.none )

            else if List.any ((/=) Nothing) (errors page model) then
                ( { model | submitted = True }, Klar.focus "auth-validation" NoOp )

            else
                start page "Email" { model | submitted = True }

        Social page provider ->
            if model.phase == Working then
                ( model, Cmd.none )

            else
                start page provider model

        Finished ticket page provider ->
            if ticket /= model.ticket || model.phase /= Working then
                ( model, Cmd.none )

            else
                let
                    successful =
                        model.scenario == "success"

                    message =
                        if model.scenario == "cancelled" then
                            provider ++ " sign-in was cancelled. You can try again or choose another method."

                        else if model.scenario == "expired" then
                            "This recovery link has expired. Request a new link from Forgot password."

                        else if not successful then
                            "We could not complete the request. Check your details and try again."

                        else
                            case page of
                                SignUp ->
                                    "Check your inbox. A demo verification email is ready; verify your address before entering the workspace."

                                ForgotPassword ->
                                    "If an account exists for this email, a recovery link has been sent. Check your inbox and spam folder."

                                ResetPassword ->
                                    "Your password has been updated in this demo. You can now return to sign in."

                                _ ->
                                    "You are signed in to the demo workspace with " ++ provider ++ "."
                in
                ( { model
                    | phase =
                        if successful then
                            Done

                        else
                            Failed
                    , message = message
                    , submitted = False
                    , password = Password.clear model.password
                    , confirmation = Password.clear model.confirmation
                  }
                , Klar.focus "auth-result" NoOp
                )

        StartAgain ->
            ( leave model, Klar.focus "auth-validation" NoOp )

        NoOp ->
            ( model, Cmd.none )


start : Page -> String -> Model -> ( Model, Cmd Msg )
start page provider model =
    let
        ticket =
            model.ticket + 1
    in
    ( { model | phase = Working, message = "", ticket = ticket, password = Password.hide model.password, confirmation = Password.hide model.confirmation }
    , Process.sleep 850 |> Task.perform (\_ -> Finished ticket page provider)
    )


errors : Page -> Model -> List (Maybe String)
errors page model =
    [ if page == ResetPassword then
        Nothing

      else
        Validate.firstError Locale.en [ Validate.required, Validate.email ] model.email
    , if page == SignUp then
        Validate.run Locale.en Validate.required model.name

      else
        Nothing
    , if page == ForgotPassword then
        Nothing

      else
        Validate.firstError Locale.en
            [ Validate.required
            , Validate.minLength
                (if page == SignIn then
                    1

                 else
                    12
                )
            ]
            (Password.value model.password)
    , if page == ResetPassword && Password.value model.password /= Password.value model.confirmation then
        Just "The passwords must match."

      else
        Nothing
    , if page == SignUp && not model.accepted then
        Just "Accept the terms to create an account."

      else
        Nothing
    ]


view : Page -> Model -> Html Msg
view page model =
    let
        busy =
            model.phase == Working

        problems =
            if model.submitted then
                errors page model

            else
                []

        errorAt index =
            List.drop index problems |> List.head |> Maybe.withDefault Nothing

        action =
            case page of
                SignUp ->
                    "Create account"

                ForgotPassword ->
                    "Send recovery link"

                ResetPassword ->
                    "Update password"

                _ ->
                    "Sign in"

        social =
            page == SignIn || page == SignUp
    in
    Layout.grid [ Layout.minColumn 320, Layout.gap 6 ]
        [ Pattern.section
            (if page == SignIn then
                "Welcome back"

             else
                Catalog.title page
            )
            "Your workspace, connected."
            [ if social then
                Layout.stack [ Layout.gap 3 ]
                    [ Button.view [ Button.block, Button.icon Icon.globe, Button.onClick (Social page "Google"), Button.disabled busy ] "Continue with Google"
                    , Button.view [ Button.block, Button.icon Icon.grid, Button.onClick (Social page "Microsoft"), Button.disabled busy ] "Continue with Microsoft"
                    , Layout.dividerLabelled "or continue with email"
                    ]

              else
                Text.paragraph
                    (if page == ForgotPassword then
                        "Enter your work email and we will send you a recovery link."

                     else
                        "Choose a new password for your workspace account."
                    )
            , Html.form [ Events.onSubmit (Submit page) ]
                [ Layout.stack [ Layout.gap 4 ]
                    [ Pattern.result "auth-validation" Danger (String.join " " (List.filterMap identity problems))
                    , if page == SignUp then
                        Input.view [ Input.id "auth-name", Input.label "Full name", Input.autocomplete "name", Input.value model.name, Input.onInput Name, Input.errorMaybe (errorAt 1), Input.disabled busy ]

                      else
                        Html.text ""
                    , if page /= ResetPassword then
                        Input.view [ Input.id "auth-email", Input.label "Work email", Input.email, Input.autocomplete "email", Input.placeholder "you@company.com", Input.required, Input.value model.email, Input.onInput Email, Input.errorMaybe (errorAt 0), Input.disabled busy ]

                      else
                        Html.text ""
                    , if page /= ForgotPassword then
                        Password.view PasswordMsg
                            ([ Password.label
                                (if page == SignIn then
                                    "Password"

                                 else
                                    "New password"
                                )
                             , Password.required
                             , Password.errorMaybe (errorAt 2)
                             , Password.disabled busy
                             ]
                                ++ (if page == SignIn then
                                        [ Password.currentPassword ]

                                    else
                                        [ Password.newPassword, Password.strengthMeter, Password.hint "Use a passphrase with at least 12 characters." ]
                                   )
                            )
                            model.password

                      else
                        Html.text ""
                    , if page == ResetPassword then
                        Password.view ConfirmationMsg [ Password.label "Confirm new password", Password.newPassword, Password.required, Password.errorMaybe (errorAt 3), Password.disabled busy ] model.confirmation

                      else
                        Html.text ""
                    , if page == SignUp then
                        Checkbox.view [ Checkbox.label "I agree to the workspace terms and privacy policy", Checkbox.checked model.accepted, Checkbox.onCheck Accept, Checkbox.errorMaybe (errorAt 4), Checkbox.disabled busy ]

                      else
                        Html.text ""
                    , if page == SignIn then
                        Pattern.link "Forgot password?" "forgot-password"

                      else
                        Html.text ""
                    , Button.view [ Button.primary, Button.block, Button.submit, Button.loading busy, Button.disabled (model.phase == Done) ]
                        (if busy then
                            "Please wait..."

                         else
                            action
                        )
                    ]
                ]
            , Pattern.result "auth-result"
                (if model.phase == Done then
                    Success

                 else
                    Danger
                )
                model.message
            , if model.phase == Done then
                Button.view [ Button.onClick StartAgain, Button.icon Icon.refresh ] "Start again"

              else
                Html.text ""
            , Layout.row [ Layout.gap 2, Layout.wrap ]
                [ Pattern.link "Back to sign in" "sign-in"
                , Pattern.link "Create an account" "sign-up"
                , if page == ForgotPassword then
                    Pattern.link "Preview recovery link" "reset-password"

                  else
                    Html.text ""
                ]
            ]
        , Layout.stack [ Layout.gap 5 ]
            [ Pattern.section "One account. Your whole workspace."
                "A complete account flow"
                [ Pattern.flow [ "Identify", "Verify", "Enter workspace" ]
                    (if model.phase == Done then
                        2

                     else if busy then
                        1

                     else
                        0
                    )
                , Text.paragraph "Bring your documents, repositories and calendars into one place. Connect each tool when you need it, and choose what your assistant can access."
                , Layout.row [ Layout.gap 2, Layout.alignCenter ] [ Icon.view Icon.shieldCheck, Text.secondary "You control access to every connected app." ]
                , Pattern.link "Explore connected apps" "connections"
                ]
            , Pattern.section "Try the different outcomes"
                "Demo controls"
                [ Segmented.view [ Segmented.label "Server response", Segmented.options [ Segmented.option "success" "Success", Segmented.option "failure" "Failure", Segmented.option "cancelled" "Cancelled", Segmented.option "expired" "Expired link" ], Segmented.selected model.scenario, Segmented.onChange Scenario, Segmented.disabled busy ]
                , Text.secondary "Select an outcome before submitting. Social buttons simulate the provider redirect and return. Recovery and verification emails are simulated too."
                ]
            ]
        ]
