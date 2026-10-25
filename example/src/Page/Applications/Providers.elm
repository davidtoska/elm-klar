module Page.Applications.Providers exposing (Credential, Model, Msg(..), Phase(..), init, leave, update, view)

{-| Provider configuration with simulated verification and metadata-only saved
records. Never put a credential in a URL, delayed message or persistent storage.
-}

import Dict exposing (Dict)
import Html exposing (Html)
import Klar
import Klar.Badge as Badge
import Klar.Button as Button
import Klar.Icon as Icon
import Klar.Layout as Layout
import Klar.PasswordInput as Password
import Klar.SegmentedControl as Segmented
import Klar.Text as Text
import Klar.TextInput as Input
import Klar.Theme exposing (Tone(..))
import Patterns.Workspace as Pattern
import Process
import Task


type Phase
    = Unconfigured
    | Verifying
    | Ready
    | Failed


type alias Credential =
    { label : String, environment : String }


type alias Model =
    { selected : String
    , secret : Password.State
    , label : String
    , environment : String
    , credentials : Dict String Credential
    , defaultProvider : Maybe String
    , phase : Phase
    , message : String
    , scenario : String
    , ticket : Int
    , removing : Bool
    }


init : Model
init =
    { selected = "OpenAI", secret = Password.init "provider-secret", label = "Workspace assistant", environment = "Development", credentials = Dict.empty, defaultProvider = Nothing, phase = Unconfigured, message = "", scenario = "success", ticket = 0, removing = False }


type Msg
    = Select String
    | SecretMsg Password.Msg
    | Label String
    | Environment String
    | Scenario String
    | Verify
    | Verified Int String String
    | MakeDefault String
    | Remove
    | ConfirmRemove
    | CancelRemove
    | NoOp


leave : Model -> Model
leave model =
    { model
        | secret = Password.clear model.secret
        , ticket = model.ticket + 1
        , removing = False
        , phase =
            if Dict.member model.selected model.credentials then
                Ready

            else
                Unconfigured
        , message = ""
    }


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        Select name ->
            if model.phase == Verifying then
                ( model, Cmd.none )

            else
                ( leave { model | selected = name }, Cmd.none )

        SecretMsg inner ->
            let
                ( state, cmd ) =
                    Password.update inner model.secret
            in
            ( { model | secret = state }, Cmd.map SecretMsg cmd )

        Label value ->
            ( { model | label = value }, Cmd.none )

        Environment value ->
            ( { model | environment = value }, Cmd.none )

        Scenario value ->
            ( { model | scenario = value }, Cmd.none )

        Verify ->
            if model.phase == Verifying then
                ( model, Cmd.none )

            else if not (String.startsWith "demo-" (Password.value model.secret)) || String.length (Password.value model.secret) < 12 || String.isEmpty (String.trim model.label) then
                ( { model | phase = Failed, message = "Enter a connection name and a made-up key starting with demo- (at least 12 characters)." }, Klar.focus "provider-result" NoOp )

            else
                let
                    ticket =
                        model.ticket + 1
                in
                ( { model | phase = Verifying, ticket = ticket, secret = Password.clear model.secret, message = "Checking the credential and provider access..." }
                , Process.sleep 1000 |> Task.perform (\_ -> Verified ticket model.selected model.scenario)
                )

        Verified ticket provider outcome ->
            if ticket /= model.ticket || model.phase /= Verifying || provider /= model.selected then
                ( model, Cmd.none )

            else if outcome == "success" then
                ( { model | phase = Ready, credentials = Dict.insert provider { label = model.label, environment = model.environment } model.credentials, defaultProvider = Just (Maybe.withDefault provider model.defaultProvider), message = "Credential verified in this demo. Only connection metadata is kept; the key has been discarded." }, Klar.focus "provider-result" NoOp )

            else
                ( { model
                    | phase = Failed
                    , message =
                        if outcome == "invalid" then
                            "The provider rejected this credential. Enter a new demo key and try again."

                        else if outcome == "limited" then
                            "The provider rate limit was reached. Wait before retrying with a demo key."

                        else
                            "The provider could not be reached. Enter a demo key to retry. Existing connections are kept."
                  }
                , Klar.focus "provider-result" NoOp
                )

        MakeDefault provider ->
            if Dict.member provider model.credentials then
                ( { model | defaultProvider = Just provider }, Cmd.none )

            else
                ( model, Cmd.none )

        Remove ->
            ( { model | removing = True }, Klar.focus "provider-remove" NoOp )

        ConfirmRemove ->
            ( leave
                { model
                    | credentials = Dict.remove model.selected model.credentials
                    , defaultProvider =
                        if model.defaultProvider == Just model.selected then
                            Nothing

                        else
                            model.defaultProvider
                }
            , Klar.focus "provider-result" NoOp
            )

        CancelRemove ->
            ( { model | removing = False }, Klar.focus "provider-remove-button" NoOp )

        NoOp ->
            ( model, Cmd.none )


view : Model -> Html Msg
view model =
    let
        busy =
            model.phase == Verifying

        configured =
            Dict.member model.selected model.credentials
    in
    Layout.stack [ Layout.gap 5 ]
        [ Layout.grid [ Layout.minColumn 220, Layout.gap 4 ]
            (List.map
                (\name ->
                    Pattern.connectionCard
                        { name = name
                        , description =
                            if name == "Anthropic" then
                                "Claude API credentials for your assistant and server-side Claude Code workers."

                            else if name == "JEV" then
                                "Classification provider · simulated adapter."

                            else if name == "Custom provider" then
                                "A template for adding another server-side adapter."

                            else
                                "API access for your workspace assistant."
                        , icon =
                            if name == "JEV" then
                                Icon.layers

                            else
                                Icon.zap
                        , state =
                            if model.defaultProvider == Just name then
                                "Default"

                            else if Dict.member name model.credentials then
                                "Configured"

                            else
                                "Not configured"
                        , tone =
                            if Dict.member name model.credentials then
                                Success

                            else
                                Neutral
                        , action =
                            Button.view [ Button.onClick (Select name), Button.pressed (name == model.selected), Button.disabled busy ]
                                (if name == model.selected then
                                    "Selected"

                                 else
                                    "Configure"
                                )
                        }
                )
                [ "OpenAI", "Anthropic", "OpenRouter", "JEV", "Custom provider" ]
            )
        , Layout.grid [ Layout.minColumn 320, Layout.gap 5 ]
            [ Pattern.section (model.selected ++ " credentials")
                "Available to workspace administrators"
                [ Input.view [ Input.label "Connection name", Input.id "provider-label", Input.value model.label, Input.onInput Label, Input.disabled busy ]
                , Segmented.view [ Segmented.label "Environment", Segmented.options [ Segmented.option "Development" "Development", Segmented.option "Production" "Production" ], Segmented.selected model.environment, Segmented.onChange Environment, Segmented.disabled busy ]
                , Password.view SecretMsg
                    [ Password.label
                        (if configured then
                            "Replacement API key"

                         else
                            "API key"
                        )
                    , Password.autocomplete "off"
                    , Password.hint "Demo only: use demo-example-key. Keys are cleared immediately when verification starts."
                    , Password.disabled busy
                    ]
                    model.secret
                , Layout.row [ Layout.gap 2, Layout.wrap ]
                    [ Button.view [ Button.primary, Button.icon Icon.shieldCheck, Button.onClick Verify, Button.loading busy ]
                        (if configured then
                            "Verify & replace key"

                         else
                            "Verify & connect"
                        )
                    , if configured then
                        Button.view [ Button.id "provider-remove-button", Button.ghost, Button.danger, Button.onClick Remove, Button.disabled busy ] "Remove connection"

                      else
                        Html.text ""
                    ]
                , Pattern.result "provider-result"
                    (if model.phase == Failed then
                        Danger

                     else if model.phase == Ready then
                        Success

                     else
                        Info
                    )
                    model.message
                , if model.removing then
                    Layout.stack [ Layout.gap 3 ]
                        [ Pattern.result "provider-remove" Warning "Remove this provider? Tasks using it will need another configured provider."
                        , Layout.row [ Layout.gap 2, Layout.wrap ] [ Button.view [ Button.onClick CancelRemove ] "Keep provider", Button.view [ Button.danger, Button.onClick ConfirmRemove ] "Remove provider" ]
                        ]

                  else
                    Html.text ""
                ]
            , Pattern.section "Workspace routing"
                "Choose which connection new tasks use"
                [ Text.paragraph ("Default provider: " ++ Maybe.withDefault "Choose a verified connection" model.defaultProvider)
                , if Dict.isEmpty model.credentials then
                    Text.secondary "Verify a demo credential to enable provider routing."

                  else
                    Layout.stack [ Layout.gap 3 ] (Dict.toList model.credentials |> List.map (\( name, credential ) -> Layout.row [ Layout.gap 2, Layout.wrap, Layout.alignCenter ] [ Text.strong name, Badge.view [] credential.environment, Text.secondary credential.label, Button.view [ Button.small, Button.onClick (MakeDefault name), Button.disabled (model.defaultProvider == Just name || busy) ] "Use as default" ]))
                , Layout.divider
                , Text.strong "Claude Code and the Claude API"
                , Text.secondary "Anthropic API keys authenticate API requests and can be supplied to a server-side Claude Code worker. Signing in to a Claude subscription is a separate flow; this form does not import or expose a Claude Code login token."
                , Pattern.link "Try JEV classification" "jev-classification"
                ]
            ]
        , Pattern.section "Try credential verification"
            "Demo controls"
            [ Segmented.view [ Segmented.label "Verification response", Segmented.options [ Segmented.option "success" "Success", Segmented.option "invalid" "Invalid key", Segmented.option "limited" "Rate limit", Segmented.option "failure" "Unavailable" ], Segmented.selected model.scenario, Segmented.onChange Scenario, Segmented.disabled busy ]
            ]
        ]
