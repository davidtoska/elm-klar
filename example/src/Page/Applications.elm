module Page.Applications exposing (Model, Msg(..), init, leave, update, view)

{-| Composable application examples. The page registry supplies navigation; each
feature owns its update and lifecycle; Patterns.Workspace supplies larger views.
-}

import Html exposing (Html)
import Klar.Button as Button
import Klar.Icon as Icon
import Klar.Layout as Layout
import Klar.Link as Link
import Page.Applications.Auth as Auth
import Page.Applications.Catalog as Catalog exposing (Page(..))
import Page.Applications.Classification as Classification
import Page.Applications.Connections as Connections
import Page.Applications.Processes as Processes
import Page.Applications.Providers as Providers
import Patterns.Workspace as Pattern
import Showcase.CalendarApplication as CalendarApplication


type alias Model =
    { processes : Processes.Model, auth : Auth.Model, connections : Connections.Model, providers : Providers.Model, classification : Classification.Model }


init : Model
init =
    { processes = Processes.init, auth = Auth.init, connections = Connections.init, providers = Providers.init, classification = Classification.init }


type Msg
    = AuthMsg Auth.Msg
    | ConnectionsMsg Connections.Msg
    | ProvidersMsg Providers.Msg
    | ProcessesMsg Processes.Msg
    | ClassificationMsg Classification.Msg


leave : Model -> Model
leave model =
    { processes = Processes.leave model.processes, auth = Auth.leave model.auth, connections = Connections.leave model.connections, providers = Providers.leave model.providers, classification = Classification.leave model.classification }


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        AuthMsg inner ->
            let
                ( state, cmd ) =
                    Auth.update inner model.auth
            in
            ( { model | auth = state }, Cmd.map AuthMsg cmd )

        ConnectionsMsg inner ->
            let
                ( state, cmd ) =
                    Connections.update inner model.connections
            in
            ( { model | connections = state }, Cmd.map ConnectionsMsg cmd )

        ProvidersMsg inner ->
            let
                ( state, cmd ) =
                    Providers.update inner model.providers
            in
            ( { model | providers = state }, Cmd.map ProvidersMsg cmd )

        ProcessesMsg inner ->
            let
                ( state, cmd ) =
                    Processes.update inner model.processes
            in
            ( { model | processes = state }, Cmd.map ProcessesMsg cmd )

        ClassificationMsg inner ->
            let
                ( state, cmd ) =
                    Classification.update inner model.classification
            in
            ( { model | classification = state }, Cmd.map ClassificationMsg cmd )


view : Page -> Model -> Html Msg
view page model =
    Layout.stack [ Layout.gap 6 ]
        [ Pattern.header (Catalog.title page)
            (Catalog.description page)
            [ Button.view [ Button.ghost, Button.icon Icon.layers, Button.href (Link.internal "#/components/examples") ] "All examples" ]
        , if page == Calendar then
            Html.text ""

          else
            Pattern.demoNotice
        , case page of
            Calendar ->
                CalendarApplication.view

            Connections ->
                Html.map ConnectionsMsg (Connections.view page model.connections)

            GitHub ->
                Html.map ConnectionsMsg (Connections.view page model.connections)

            Google ->
                Html.map ConnectionsMsg (Connections.view page model.connections)

            AiProviders ->
                Html.map ProvidersMsg (Providers.view model.providers)

            Processes ->
                Html.map ProcessesMsg (Processes.view model.processes)

            Classification ->
                Html.map ClassificationMsg (Classification.view model.classification)

            _ ->
                Html.map AuthMsg (Auth.view page model.auth)
        ]
