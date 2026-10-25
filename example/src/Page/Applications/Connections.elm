module Page.Applications.Connections exposing (Connection, Model, Msg(..), Phase(..), init, leave, update, view)

{-| Connection settings with explicit consent, per-service operation generations,
revocation and import retries. Only metadata belongs in this frontend model.
-}

import Dict exposing (Dict)
import Html exposing (Html)
import Klar
import Klar.Badge as Badge
import Klar.Button as Button
import Klar.Icon as Icon
import Klar.Layout as Layout
import Klar.SegmentedControl as Segmented
import Klar.Text as Text
import Klar.Theme exposing (Tone(..))
import Page.Applications.Catalog exposing (Page(..))
import Patterns.Workspace as Pattern
import Process
import Set exposing (Set)
import Task


type Phase
    = Disconnected
    | Reviewing
    | Authorizing
    | Connected
    | Expired
    | Syncing
    | SyncFailed


type alias Connection =
    { phase : Phase, ticket : Int, detail : String, imported : Bool }


type alias Model =
    { connections : Dict String Connection
    , repositories : Set String
    , files : Set String
    , calendars : Set String
    , scenario : String
    , pendingDisconnect : Maybe String
    }


init : Model
init =
    { connections = List.map (\id -> ( id, { phase = Disconnected, ticket = 0, detail = "", imported = False } )) [ "github", "drive", "calendar", "microsoft", "slack", "notion" ] |> Dict.fromList
    , repositories = Set.singleton "team/assistant"
    , files = Set.singleton "Product handbook"
    , calendars = Set.singleton "Work calendar"
    , scenario = "success"
    , pendingDisconnect = Nothing
    }


type Msg
    = Connect String
    | Authorize String
    | Cancel String
    | Finished String Int Bool String
    | Import String
    | RequestDisconnect String
    | ConfirmDisconnect
    | KeepConnection
    | Expire String
    | Repository String Bool
    | File String Bool
    | Calendar String Bool
    | Scenario String
    | NoOp


get : String -> Model -> Connection
get id model =
    Dict.get id model.connections |> Maybe.withDefault { phase = Disconnected, ticket = 0, detail = "", imported = False }


put : String -> Connection -> Model -> Model
put id connection model =
    { model | connections = Dict.insert id connection model.connections }


leave : Model -> Model
leave model =
    { model
        | pendingDisconnect = Nothing
        , connections =
            Dict.map
                (\_ connection ->
                    { connection
                        | ticket = connection.ticket + 1
                        , phase =
                            if List.member connection.phase [ Reviewing, Authorizing ] then
                                Disconnected

                            else if connection.phase == Syncing then
                                Connected

                            else
                                connection.phase
                    }
                )
                model.connections
    }


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    let
        selected value yes values =
            if yes then
                Set.insert value values

            else
                Set.remove value values
    in
    case msg of
        Connect id ->
            let
                connection =
                    get id model
            in
            ( put id { connection | phase = Reviewing, detail = "Review the requested access before continuing." } model, Klar.focus (id ++ "-consent") NoOp )

        Authorize id ->
            let
                connection =
                    get id model

                empty =
                    (id == "github" && Set.isEmpty model.repositories) || (id == "drive" && Set.isEmpty model.files) || (id == "calendar" && Set.isEmpty model.calendars)
            in
            if connection.phase /= Reviewing then
                ( model, Cmd.none )

            else if empty then
                ( put id { connection | detail = "Select at least one resource before granting access." } model, Klar.focus (id ++ "-consent") NoOp )

            else
                run id False model

        Cancel id ->
            let
                connection =
                    get id model
            in
            ( put id { connection | phase = Disconnected, ticket = connection.ticket + 1, detail = "Connection cancelled. No new access was granted." } model, Klar.focus (id ++ "-connect") NoOp )

        Import id ->
            if List.member (get id model).phase [ Connected, SyncFailed ] then
                run id True model

            else
                ( model, Cmd.none )

        Finished id ticket importing outcome ->
            let
                connection =
                    get id model

                successful =
                    outcome == "success"
            in
            if connection.ticket /= ticket || not (List.member connection.phase [ Authorizing, Syncing ]) then
                ( model, Cmd.none )

            else
                ( put id
                    { connection
                        | phase =
                            if successful then
                                Connected

                            else if outcome == "expired" then
                                Expired

                            else if importing then
                                SyncFailed

                            else
                                Disconnected
                        , imported = connection.imported || (successful && importing)
                        , detail =
                            if successful then
                                if importing then
                                    "Import complete. Your selected resources are up to date."

                                else
                                    "Connected as alex@workspace.example. Access is limited to your selection."

                            else if outcome == "denied" then
                                "Permission was declined. No new access was granted. You can try again."

                            else if outcome == "expired" then
                                "Access has expired or was revoked. Reconnect to continue importing."

                            else
                                "The service is unavailable. Try again; your previous import is kept."
                    }
                    model
                , Klar.focus (id ++ "-status") NoOp
                )

        RequestDisconnect id ->
            ( { model | pendingDisconnect = Just id }, Klar.focus "connection-disconnect" NoOp )

        ConfirmDisconnect ->
            case model.pendingDisconnect of
                Nothing ->
                    ( model, Cmd.none )

                Just id ->
                    let
                        connection =
                            get id model
                    in
                    ( put id { connection | phase = Disconnected, ticket = connection.ticket + 1, detail = "Disconnected. Background imports have stopped. Previously imported data is retained.", imported = False } { model | pendingDisconnect = Nothing }, Klar.focus (id ++ "-connect") NoOp )

        KeepConnection ->
            let
                focus =
                    model.pendingDisconnect |> Maybe.map (\id -> Klar.focus (id ++ "-disconnect") NoOp) |> Maybe.withDefault Cmd.none
            in
            ( { model | pendingDisconnect = Nothing }, focus )

        Expire id ->
            let
                connection =
                    get id model
            in
            ( put id { connection | phase = Expired, ticket = connection.ticket + 1, detail = "The provider revoked access. Reconnect to resume imports." } model, Cmd.none )

        Repository value yes ->
            ( { model | repositories = selected value yes model.repositories }, Cmd.none )

        File value yes ->
            ( { model | files = selected value yes model.files }, Cmd.none )

        Calendar value yes ->
            ( { model | calendars = selected value yes model.calendars }, Cmd.none )

        Scenario value ->
            ( { model | scenario = value }, Cmd.none )

        NoOp ->
            ( model, Cmd.none )


run : String -> Bool -> Model -> ( Model, Cmd Msg )
run id importing model =
    let
        connection =
            get id model

        ticket =
            connection.ticket + 1
    in
    ( put id
        { connection
            | phase =
                if importing then
                    Syncing

                else
                    Authorizing
            , ticket = ticket
            , detail =
                if importing then
                    "Importing your selected resources..."

                else
                    "Waiting for the provider to return..."
        }
        model
    , Process.sleep 1100 |> Task.perform (\_ -> Finished id ticket importing model.scenario)
    )


phaseLabel : Phase -> ( String, Tone )
phaseLabel phase =
    case phase of
        Disconnected ->
            ( "Not connected", Neutral )

        Reviewing ->
            ( "Review access", Info )

        Authorizing ->
            ( "Connecting", Info )

        Connected ->
            ( "Connected", Success )

        Expired ->
            ( "Needs attention", Warning )

        Syncing ->
            ( "Importing", Info )

        SyncFailed ->
            ( "Import failed", Danger )


view : Page -> Model -> Html Msg
view page model =
    Layout.stack [ Layout.gap 5 ]
        [ if page == Connections then
            catalog model

          else if page == GitHub then
            github model

          else
            google model
        , case model.pendingDisconnect of
            Nothing ->
                Html.text ""

            Just id ->
                Pattern.section "Disconnect this app?"
                    "Background access will stop. Previously imported data is retained."
                    [ Pattern.result "connection-disconnect" Warning ("Disconnect " ++ id ++ " from this workspace?")
                    , Layout.row [ Layout.gap 2, Layout.wrap ] [ Button.view [ Button.onClick KeepConnection ] "Keep connected", Button.view [ Button.danger, Button.onClick ConfirmDisconnect ] "Disconnect app" ]
                    ]
        , Pattern.section "Try the connection lifecycle"
            "Demo controls"
            [ Segmented.view [ Segmented.label "Next provider response", Segmented.options [ Segmented.option "success" "Success", Segmented.option "denied" "Declined", Segmented.option "expired" "Expired", Segmented.option "failure" "Service error" ], Segmented.selected model.scenario, Segmented.onChange Scenario ]
            , Text.secondary "Connect, review access, authorize and import. Change the response and retry, or simulate revoked access on a connected service."
            ]
        ]


catalog : Model -> Html Msg
catalog model =
    Layout.stack [ Layout.gap 5 ]
        [ Layout.row [ Layout.gap 2, Layout.wrap ] [ Badge.view [ Badge.tone Info ] "Workspace connections", Text.secondary "Access is granted separately for each app." ]
        , Layout.grid [ Layout.minColumn 280, Layout.gap 4 ]
            (List.map
                (\( id, name, description ) ->
                    let
                        ( label, tone ) =
                            phaseLabel (get id model).phase

                        destination =
                            if id == "github" then
                                "github"

                            else if List.member id [ "drive", "calendar" ] then
                                "google-workspace"

                            else
                                ""
                    in
                    Pattern.connectionCard
                        { name = name
                        , description = description
                        , icon =
                            if id == "github" then
                                Icon.gitBranch

                            else if id == "calendar" then
                                Icon.calendar

                            else if id == "drive" then
                                Icon.folder

                            else
                                Icon.link
                        , state = label
                        , tone = tone
                        , action =
                            if destination /= "" then
                                Pattern.link "Manage connection" destination

                            else
                                actions id model
                        }
                )
                [ ( "github", "GitHub", "Read code and issues from selected repositories." )
                , ( "drive", "Google Drive", "Make selected documents available to your assistant." )
                , ( "calendar", "Google Calendar", "Import events from the calendars you choose." )
                , ( "microsoft", "Microsoft 365", "Read a selected Microsoft calendar with delegated access." )
                , ( "slack", "Slack", "Connect an approved channel for team context." )
                , ( "notion", "Notion", "Connect selected pages as workspace knowledge." )
                ]
            )
        , Layout.stack [ Layout.gap 4 ] (List.map (\id -> consent id model) [ "microsoft", "slack", "notion" ])
        ]


github : Model -> Html Msg
github model =
    let
        locked =
            not (List.member (get "github" model).phase [ Disconnected, Reviewing, Expired ])
    in
    Layout.grid [ Layout.minColumn 320, Layout.gap 5 ]
        [ Pattern.section "Install the workspace GitHub App"
            "team · Organization account"
            [ Pattern.flow [ "Select repositories", "Grant access", "Import" ] (stage (get "github" model).phase)
            , Text.paragraph "Choose exactly which repositories your assistant can read. Change repository access by reconnecting."
            , Layout.stack [ Layout.gap 3 ] (List.map (\name -> Pattern.permission { label = name, reason = "Repository contents, issues and pull requests · read only", selected = Set.member name model.repositories, onChange = Repository name, disabled = locked }) [ "team/assistant", "team/documentation", "team/website" ])
            , actions "github" model
            , consent "github" model
            ]
        , Pattern.section "Requested permissions"
            "Read access for an assistant"
            [ permissionInfo "Repository contents" "Read source files to answer questions about your code."
            , permissionInfo "Issues and pull requests" "Read discussions and changes for project context."
            , permissionInfo "Repository metadata" "Identify repositories available to the installed app."
            , Text.secondary "This example grants no permission to push code, merge pull requests or manage your organization. A production installation may require organization approval."
            ]
        ]


google : Model -> Html Msg
google model =
    Layout.stack [ Layout.gap 5 ]
        [ Layout.grid [ Layout.minColumn 320, Layout.gap 5 ]
            [ Pattern.section "Google Drive"
                "Selected files · read and import"
                [ Text.paragraph "Choose files from a simulated Google Picker. In production, the picker grants access to these files; the server enforces that selection."
                , choices "drive" model.files File [ "Product handbook", "Project brief", "Meeting notes" ] model
                , actions "drive" model
                , consent "drive" model
                ]
            , Pattern.section "Google Calendar"
                "Selected calendars · read only"
                [ Text.paragraph "Choose the calendars to import. Background access keeps your assistant up to date while you are away."
                , choices "calendar" model.calendars Calendar [ "Work calendar", "Project calendar", "Team availability" ] model
                , actions "calendar" model
                , consent "calendar" model
                ]
            ]
        , Pattern.section "Your import scope"
            "Only your selected resources are imported"
            [ permissionInfo "Drive selection" (String.join ", " (Set.toList model.files))
            , permissionInfo "Calendar selection" (String.join ", " (Set.toList model.calendars))
            , Text.secondary "Drive's per-file grant can permit changes to selected files; this assistant's server must enforce its read-only policy. Calendar authorization covers more than the import selection; the server must restrict imports to the calendars chosen here."
            ]
        ]


choices : String -> Set String -> (String -> Bool -> Msg) -> List String -> Model -> Html Msg
choices id selection toMsg names model =
    Layout.stack [ Layout.gap 3 ]
        (List.map (\name -> Pattern.permission { label = name, reason = "Include in the next import", selected = Set.member name selection, onChange = toMsg name, disabled = not (List.member (get id model).phase [ Disconnected, Reviewing, Expired ]) }) names)


permissionInfo : String -> String -> Html Msg
permissionInfo title description =
    Layout.stack [ Layout.gap 1 ] [ Text.strong title, Text.secondary description ]


stage : Phase -> Int
stage phase =
    if List.member phase [ Reviewing, Authorizing ] then
        1

    else if List.member phase [ Connected, Syncing, SyncFailed ] then
        2

    else
        0


actions : String -> Model -> Html Msg
actions id model =
    let
        connection =
            get id model

        ( label, tone ) =
            phaseLabel connection.phase

        active =
            List.member connection.phase [ Connected, Syncing, SyncFailed ]
    in
    Layout.stack [ Layout.gap 3 ]
        [ Layout.row [ Layout.gap 2, Layout.wrap, Layout.alignCenter ]
            [ Badge.view [ Badge.tone tone, Badge.dot ] label
            , if active then
                Button.view [ Button.primary, Button.icon Icon.refresh, Button.onClick (Import id), Button.loading (connection.phase == Syncing) ]
                    (if connection.phase == SyncFailed then
                        "Retry import"

                     else
                        "Import now"
                    )

              else
                Button.view [ Button.id (id ++ "-connect"), Button.primary, Button.icon Icon.link, Button.onClick (Connect id), Button.loading (connection.phase == Authorizing), Button.disabled (connection.phase == Reviewing) ]
                    (if connection.phase == Expired then
                        "Reconnect"

                     else
                        "Connect"
                    )
            , if active then
                Button.view [ Button.id (id ++ "-disconnect"), Button.ghost, Button.danger, Button.onClick (RequestDisconnect id), Button.disabled (connection.phase == Syncing) ] "Disconnect"

              else
                Html.text ""
            , if active then
                Button.view [ Button.ghost, Button.small, Button.onClick (Expire id), Button.disabled (connection.phase == Syncing) ] "Simulate revoked access"

              else
                Html.text ""
            ]
        , Pattern.result (id ++ "-status") tone connection.detail
        , if connection.imported then
            Text.secondary "Last successful import: just now · Selected resources only"

          else
            Html.text ""
        ]


consent : String -> Model -> Html Msg
consent id model =
    let
        connection =
            get id model

        resources =
            if id == "github" then
                Set.toList model.repositories

            else if id == "drive" then
                Set.toList model.files

            else if id == "calendar" then
                Set.toList model.calendars

            else
                [ if id == "slack" then
                    "#project-assistant · selected channel history"

                  else if id == "notion" then
                    "Workspace handbook · selected page contents"

                  else
                    "Work calendar · read calendar events"
                ]
    in
    if List.member connection.phase [ Reviewing, Authorizing ] then
        Pattern.section "Review access"
            "alex@workspace.example · Demo authorization"
            [ Pattern.result (id ++ "-consent") Info ("Allow this workspace to import: " ++ String.join ", " resources ++ ". Background access continues until you disconnect.")
            , Layout.row [ Layout.gap 2, Layout.wrap ]
                [ Button.view [ Button.primary, Button.onClick (Authorize id), Button.loading (connection.phase == Authorizing) ] "Authorize connection"
                , Button.view [ Button.onClick (Cancel id) ] "Cancel"
                ]
            ]

    else
        Html.text ""
