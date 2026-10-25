module Main exposing (main)

{-| A calendar in the manner of Google Calendar: people sign in, keep several
calendars, share them, invite one another, and import from Google Calendar and
from calendar files and invitations (`.ics`).
-}

import Api exposing (AclRule, User)
import Browser
import Browser.Dom as Dom
import Browser.Navigation as Nav
import Dict exposing (Dict)
import File exposing (File)
import Gcal exposing (AccessRole(..), CalendarEntry, Event, EventTime(..), ResponseStatus(..))
import Grid
import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events
import Ics
import Json.Decode as Decode
import Json.Encode as Encode
import Klar
import Klar.Alert as Alert
import Klar.AppShell as AppShell
import Klar.Avatar as Avatar
import Klar.Badge as Badge
import Klar.Button as Button
import Klar.Calendar as Calendar
import Klar.Card as Card
import Klar.Checkbox as Checkbox
import Klar.Color as Color
import Klar.ConfirmDialog as ConfirmDialog
import Klar.Date as Date exposing (Date)
import Klar.DatePicker as DatePicker
import Klar.DateTimePicker as DateTimePicker
import Klar.EmptyState as EmptyState
import Klar.FileDrop as FileDrop
import Klar.Format as Format
import Klar.Icon as Icon
import Klar.Ids as Ids exposing (Ids)
import Klar.Layout as Layout
import Klar.Link as Link
import Klar.ListItem as ListItem
import Klar.Locale as Locale
import Klar.Modal as Modal
import Klar.Overlay exposing (Overlay)
import Klar.PageHeader as PageHeader
import Klar.PasswordInput as PasswordInput
import Klar.Radio as Radio
import Klar.Recurrence as Recurrence
import Klar.RecurrencePicker as RecurrencePicker
import Klar.Remote as Remote exposing (Problem, Remote(..))
import Klar.RemoteView as RemoteView
import Klar.SegmentedControl as SegmentedControl
import Klar.Select as Select
import Klar.Settings as Settings
import Klar.SideNav as SideNav
import Klar.Spinner as Spinner
import Klar.Switch as Switch
import Klar.TagInput as TagInput
import Klar.Text as Text
import Klar.TextArea as TextArea
import Klar.TextInput as TextInput
import Klar.Theme as Theme
import Klar.Toast as Toast
import Occurrence exposing (Occurrence)
import Process
import Task
import Time
import Url exposing (Url)
import Url.Builder as Builder


main : Program () Model Msg
main =
    Browser.application
        { init = init
        , update = update
        , view = view
        , subscriptions = \_ -> Time.every 30000 Tick
        , onUrlRequest = AppShell.onUrlRequest ShellMsg
        , onUrlChange = AppShell.onUrlChange ShellMsg
        }



-- MODEL


type Page
    = CalendarPage
    | InvitationsPage
    | ImportPage


type Mode
    = DayMode
    | WeekMode
    | MonthMode
    | AgendaMode


type Auth
    = Checking
    | SignedOut
    | SignedIn User


type alias Editor =
    { original : Maybe Occurrence
    , summary : String
    , allDay : Bool
    , start : DateTimePicker.State
    , end : DateTimePicker.State
    , startDay : DatePicker.State
    , endDay : DatePicker.State
    , repeat : RecurrencePicker.State
    , calendar : Select.State String
    , color : Select.State String
    , location : String
    , description : String
    , guests : TagInput.State
    , problem : Maybe String
    , busy : Bool
    }


type alias CalendarForm =
    { entry : Maybe CalendarEntry
    , name : String
    , description : String
    , color : Select.State String
    , acl : Remote (List AclRule)
    , shareWith : Select.State String
    , shareRole : String
    , problem : Maybe String
    , busy : Bool
    , export : Maybe String
    }


type Pending
    = DeleteEvent Occurrence
    | DeleteCalendar CalendarEntry
    | Unsubscribe CalendarEntry


type ImportContent
    = IcsFile Ics.Calendar
    | GoogleFile CalendarEntry (List Encode.Value)


type Progress
    = Idle
    | Working
    | Done String
    | ImportFailed String


type alias Model =
    { shell : AppShell.State Page
    , page : Page
    , key : Nav.Key
    , origin : String
    , settings : Settings.Settings
    , zone : Time.Zone
    , zoneName : String
    , now : Time.Posix
    , today : Date
    , googleClientId : String
    , demoUsers : List User
    , auth : Auth
    , registering : Bool
    , authName : String
    , authEmail : String
    , passwordInput : PasswordInput.State
    , authProblem : Maybe String
    , authBusy : Bool
    , calendars : Remote (List CalendarEntry)
    , events : Dict String (List Event)
    , eventsProblem : Maybe Problem
    , ticket : Int
    , people : List User
    , mode : Mode
    , focus : Date
    , mini : Calendar.State
    , invites : Remote (List Event)
    , toasts : Toast.State Msg
    , detailsModal : Modal.State
    , details : Maybe Occurrence
    , editorModal : Modal.State
    , editor : Editor
    , calendarModal : Modal.State
    , calendarForm : CalendarForm
    , confirm : ConfirmDialog.State
    , pending : Maybe Pending
    , deleteAll : Bool
    , fileDrop : FileDrop.State
    , file : Maybe ( String, Result String ImportContent )
    , fileTarget : Select.State String
    , fileProgress : Progress
    , reply : Maybe ( String, String )
    , googleToken : Maybe String
    , googleCalendars : Remote (List CalendarEntry)
    , googleChosen : List String
    , googleProgress : Progress
    }


init : () -> Url -> Nav.Key -> ( Model, Cmd Msg )
init _ url key =
    let
        token =
            url.fragment |> Maybe.andThen (fragmentParam "access_token")

        page =
            if token /= Nothing then
                ImportPage

            else
                pageFromUrl url

        epoch =
            Date.fromEpochDay 0
    in
    ( { shell = AppShell.init { id = "app-shell", key = key, url = url } |> AppShell.setPage (navigation 0) page
      , page = page
      , key = key
      , origin = originOf url
      , settings = Settings.default
      , zone = Time.utc
      , zoneName = "UTC"
      , now = Time.millisToPosix 0
      , today = epoch
      , googleClientId = ""
      , demoUsers = []
      , auth = Checking
      , registering = False
      , authName = ""
      , authEmail = ""
      , passwordInput = PasswordInput.init "auth-password"
      , authProblem = Nothing
      , authBusy = False
      , calendars = Loading
      , events = Dict.empty
      , eventsProblem = Nothing
      , ticket = 0
      , people = []
      , mode = WeekMode
      , focus = epoch
      , mini = Calendar.init "mini-calendar"
      , invites = Loading
      , toasts = Toast.init "toasts"
      , detailsModal = Modal.init "event-details"
      , details = Nothing
      , editorModal = Modal.init "event-editor"
      , editor = newEditor epoch 540 ""
      , calendarModal = Modal.init "calendar-settings"
      , calendarForm = emptyCalendarForm
      , confirm = ConfirmDialog.init "confirm"
      , pending = Nothing
      , deleteAll = False
      , fileDrop = FileDrop.init "import-file"
      , file = Nothing
      , fileTarget = Select.init "import-target" |> Select.setValue (Just "primary")
      , fileProgress = Idle
      , reply = Nothing
      , googleToken = token
      , googleCalendars = NotAsked
      , googleChosen = []
      , googleProgress = Idle
      }
    , Cmd.batch
        [ Task.perform GotZone Time.here
        , Task.perform GotZoneName Time.getZoneName
        , Task.perform Tick Time.now
        , Api.me GotMe
        , Api.config GotConfig
        , case token of
            Just t ->
                Cmd.batch [ Nav.replaceUrl key "#/import", Api.googleCalendars t GotGoogleCalendars ]

            Nothing ->
                Cmd.none
        ]
    )


newEditor : Date -> Int -> String -> Editor
newEditor date minute calendarId =
    let
        toTime m =
            { hour = modBy 1440 m // 60, minute = modBy 60 m }

        endMinute =
            min (minute + 60) (23 * 60 + 45)
    in
    { original = Nothing
    , summary = ""
    , allDay = False
    , start = DateTimePicker.init "event-start" |> DateTimePicker.setValue (Just { date = date, time = toTime minute })
    , end = DateTimePicker.init "event-end" |> DateTimePicker.setValue (Just { date = date, time = toTime endMinute })
    , startDay = DatePicker.init "event-start-day" |> DatePicker.setValue (Just date)
    , endDay = DatePicker.init "event-end-day" |> DatePicker.setValue (Just date)
    , repeat = RecurrencePicker.init "event-repeat" date
    , calendar = Select.init "event-calendar" |> Select.setValue (Just calendarId)
    , color = Select.init "event-color" |> Select.setValue (Just "")
    , location = ""
    , description = ""
    , guests = TagInput.init "event-guests"
    , problem = Nothing
    , busy = False
    }


emptyCalendarForm : CalendarForm
emptyCalendarForm =
    { entry = Nothing
    , name = ""
    , description = ""
    , color = Select.init "calendar-color"
    , acl = NotAsked
    , shareWith = Select.init "share-with"
    , shareRole = "reader"
    , problem = Nothing
    , busy = False
    , export = Nothing
    }


originOf : Url -> String
originOf url =
    (case url.protocol of
        Url.Http ->
            "http://"

        Url.Https ->
            "https://"
    )
        ++ url.host
        ++ (case url.port_ of
                Just p ->
                    ":" ++ String.fromInt p

                Nothing ->
                    ""
           )


fragmentParam : String -> String -> Maybe String
fragmentParam name fragment =
    String.split "&" fragment
        |> List.filterMap
            (\pair ->
                case String.split "=" pair of
                    [ k, v ] ->
                        if k == name then
                            Url.percentDecode v

                        else
                            Nothing

                    _ ->
                        Nothing
            )
        |> List.head


pageFromUrl : Url -> Page
pageFromUrl url =
    case url.fragment of
        Just "/invitations" ->
            InvitationsPage

        Just "/import" ->
            ImportPage

        _ ->
            CalendarPage


pageKeys : Ids Page
pageKeys =
    Ids.list
        (\page ->
            case page of
                CalendarPage ->
                    "calendar"

                InvitationsPage ->
                    "invitations"

                ImportPage ->
                    "import"
        )
        [ CalendarPage, InvitationsPage, ImportPage ]


navigation : Int -> List (SideNav.Entry Page msg)
navigation invitations =
    [ SideNav.item pageKeys { key = CalendarPage, label = "Calendar", href = "#/" } |> SideNav.withIcon Icon.calendar
    , SideNav.item pageKeys { key = InvitationsPage, label = "Invitations", href = "#/invitations" }
        |> SideNav.withIcon Icon.mail
        |> (if invitations > 0 then
                SideNav.withCount invitations

            else
                identity
           )
    , SideNav.item pageKeys { key = ImportPage, label = "Import", href = "#/import" } |> SideNav.withIcon Icon.upload
    ]



-- MESSAGES


type Msg
    = NoOp
    | ShellMsg AppShell.Msg
    | ToastMsg Toast.Msg
    | Tick Time.Posix
    | GotZone Time.Zone
    | GotZoneName Time.ZoneName
    | GotConfig (Result Problem { googleClientId : String, demo : List User })
    | DemoLogin String
      -- signing in
    | GotMe (Result Problem User)
    | SetRegistering Bool
    | AuthName String
    | AuthEmail String
    | PasswordMsg PasswordInput.Msg
    | SubmitAuth
    | GotAuth (Result Problem User)
    | SignOut
    | SignedOutDone (Result Problem ())
      -- data
    | GotCalendars (Result Problem (List CalendarEntry))
    | GotEvents Int String (Result Problem (List Event))
    | GotPeople (Result Problem (List User))
    | GotInvites (Result Problem (List Event))
    | Reload
      -- navigation in time
    | MiniMsg Calendar.Msg
    | SetMode String
    | GoToday
    | GoPrevious
    | GoNext
    | GoToDay Date
      -- calendars in the sidebar
    | ToggleCalendar CalendarEntry Bool
    | GotListEntry (Result Problem CalendarEntry)
      -- event details
    | OpenOccurrence Occurrence
    | DetailsModalMsg Modal.Msg
    | Respond Event ResponseStatus
    | GotResponse (Result Problem Event)
      -- the event editor
    | OpenSlot Date Int
    | OpenNew
    | EditOccurrence Occurrence
    | EditorModalMsg Modal.Msg
    | EditorSummary String
    | EditorAllDay Bool
    | EditorStartMsg DateTimePicker.Msg
    | EditorEndMsg DateTimePicker.Msg
    | EditorStartDayMsg DatePicker.Msg
    | EditorEndDayMsg DatePicker.Msg
    | EditorRepeatMsg RecurrencePicker.Msg
    | EditorCalendarMsg (Select.Msg String)
    | EditorColorMsg (Select.Msg String)
    | EditorLocation String
    | EditorDescription String
    | EditorGuestsMsg TagInput.Msg
    | SaveEvent
    | GotSaved (Result Problem Event)
      -- deleting
    | AskDeleteEvent Occurrence
    | SetDeleteAll Bool
    | ConfirmMsg ConfirmDialog.Msg
    | ConfirmPending
    | CancelPending
    | GotDeleted (Result Problem ())
      -- calendars
    | OpenNewCalendar
    | OpenCalendarSettings CalendarEntry
    | CalendarModalMsg Modal.Msg
    | CalendarName String
    | CalendarDescription String
    | CalendarColorMsg (Select.Msg String)
    | SaveCalendar
    | GotCalendarCreated (Result Problem String)
    | GotCalendarSaved (Result Problem ())
    | GotAcl (Result Problem (List AclRule))
    | ShareWithMsg (Select.Msg String)
    | ShareRole String
    | Share
    | ChangeRole AclRule String
    | RemoveRule AclRule
    | GotAclChange (Result Problem ())
    | AskDeleteCalendar CalendarEntry
    | AskUnsubscribe CalendarEntry
    | PrepareExport CalendarEntry
    | GotExport CalendarEntry (Result Problem (List Event))
      -- import
    | FileDropMsg FileDrop.Msg
    | GotFileText String String
    | FileTargetMsg (Select.Msg String)
    | ImportFile
    | GotImportCalendar (List Event) (Result Problem String)
    | GotFileImport (Result Problem Int)
    | AnswerInvitation Event ResponseStatus
    | GotInvitationImport Event ResponseStatus (Result Problem Int)
    | GotGoogleCalendars (Result Problem (List CalendarEntry))
    | ChooseGoogle String Bool
    | ImportGoogle
    | GotGoogleImport (Result Problem (List Api.GoogleImport))



-- UPDATE


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        NoOp ->
            ( model, Cmd.none )

        ShellMsg m ->
            let
                ( shell, cmd, address ) =
                    AppShell.update m model.shell
            in
            case address of
                Just url ->
                    if String.contains "access_token=" (Maybe.withDefault "" url.fragment) then
                        ( { model | shell = shell }, Cmd.map ShellMsg cmd )

                    else
                        let
                            page =
                                pageFromUrl url
                        in
                        ( { model | page = page, shell = AppShell.setPage (navigation (inviteCount model)) page shell }
                        , Cmd.batch
                            [ Cmd.map ShellMsg cmd
                            , if page == CalendarPage then
                                scrollToMorning

                              else
                                Cmd.none
                            ]
                        )

                Nothing ->
                    ( { model | shell = shell }, Cmd.map ShellMsg cmd )

        ToastMsg m ->
            Toast.update m model.toasts
                |> Tuple.mapBoth (\t -> { model | toasts = t }) (Cmd.map ToastMsg)

        Tick now ->
            let
                today =
                    Date.fromPosix model.zone now

                first =
                    Time.posixToMillis model.now == 0
            in
            ( { model
                | now = now
                , today = today
                , focus =
                    if first then
                        today

                    else
                        model.focus
                , mini =
                    if first then
                        model.mini |> Calendar.setValue (Just today) |> Calendar.showDate today

                    else
                        model.mini
              }
            , if first && isSignedIn model then
                loadEvents { model | focus = today }

              else
                Cmd.none
            )
                |> withTicket first

        GotZone zone ->
            let
                today =
                    Date.fromPosix zone model.now
            in
            ( { model
                | zone = zone
                , settings = Settings.withZone zone model.settings
                , today = today
                , focus =
                    if model.focus == Date.fromPosix Time.utc model.now then
                        today

                    else
                        model.focus
              }
            , Cmd.none
            )

        GotZoneName zoneName ->
            case zoneName of
                Time.Name name ->
                    ( { model | zoneName = name }, Cmd.none )

                Time.Offset _ ->
                    ( model, Cmd.none )

        GotConfig (Ok config) ->
            ( { model | googleClientId = config.googleClientId, demoUsers = config.demo }, Cmd.none )

        GotConfig (Err _) ->
            ( model, Cmd.none )

        DemoLogin email ->
            ( { model | authBusy = True, authProblem = Nothing }, Api.demoLogin email GotAuth )

        GotMe (Ok user) ->
            signedIn user model

        GotMe (Err _) ->
            ( { model | auth = SignedOut }, Cmd.none )

        SetRegistering registering ->
            ( { model | registering = registering, authProblem = Nothing }, Cmd.none )

        AuthName text ->
            ( { model | authName = text }, Cmd.none )

        AuthEmail text ->
            ( { model | authEmail = text }, Cmd.none )

        PasswordMsg m ->
            PasswordInput.update m model.passwordInput
                |> Tuple.mapBoth (\p -> { model | passwordInput = p }) (Cmd.map PasswordMsg)

        SubmitAuth ->
            if model.authBusy then
                ( model, Cmd.none )

            else
                ( { model | authBusy = True, authProblem = Nothing }
                , if model.registering then
                    Api.register { name = model.authName, email = model.authEmail, password = PasswordInput.value model.passwordInput, timeZone = model.zoneName } GotAuth

                  else
                    Api.login { email = model.authEmail, password = PasswordInput.value model.passwordInput } GotAuth
                )

        GotAuth (Ok user) ->
            signedIn user { model | authBusy = False, passwordInput = PasswordInput.clear model.passwordInput }

        GotAuth (Err problem) ->
            ( { model | authBusy = False, authProblem = Just (Api.message problem) }, Cmd.none )

        SignOut ->
            ( model, Api.logout SignedOutDone )

        SignedOutDone _ ->
            ( { model | auth = SignedOut, calendars = Loading, events = Dict.empty, invites = Loading, people = [] }, Cmd.none )

        GotCalendars result ->
            let
                next =
                    { model | calendars = Remote.fromResult result }
            in
            ( next, loadEvents next )
                |> withTicket True

        GotEvents ticket calendarId result ->
            if ticket /= model.ticket then
                ( model, Cmd.none )

            else
                case result of
                    Ok events ->
                        ( { model | events = Dict.insert calendarId events model.events, eventsProblem = Nothing }, Cmd.none )

                    Err problem ->
                        ( { model | eventsProblem = Just problem }, Cmd.none )

        GotPeople result ->
            ( { model | people = Result.withDefault model.people result }, Cmd.none )

        GotInvites result ->
            let
                next =
                    { model | invites = Remote.fromResult result }
            in
            ( { next | shell = AppShell.setPage (navigation (inviteCount next)) model.page model.shell }, Cmd.none )

        Reload ->
            reloadAll model

        MiniMsg m ->
            let
                ( mini, cmd ) =
                    Calendar.update m model.mini

                chosen =
                    Calendar.value mini
            in
            if chosen /= Calendar.value model.mini then
                case chosen of
                    Just date ->
                        goTo date { model | mini = mini }
                            |> Tuple.mapSecond (\c -> Cmd.batch [ c, Cmd.map MiniMsg cmd ])

                    Nothing ->
                        ( { model | mini = mini }, Cmd.map MiniMsg cmd )

            else
                ( { model | mini = mini }, Cmd.map MiniMsg cmd )

        SetMode key ->
            let
                next =
                    { model | mode = modeFromKey key }
            in
            ( next, Cmd.batch [ loadEvents next, scrollToMorning ] )
                |> withTicket True

        GoToday ->
            goTo model.today model

        GoPrevious ->
            goTo (step -1 model) model

        GoNext ->
            goTo (step 1 model) model

        GoToDay date ->
            let
                ( next, cmd ) =
                    goTo date { model | mode = DayMode }
            in
            ( next, Cmd.batch [ cmd, scrollToMorning ] )

        ToggleCalendar entry on ->
            let
                next =
                    { model
                        | calendars =
                            Remote.map
                                (List.map
                                    (\c ->
                                        if c.id == entry.id then
                                            { c | selected = on }

                                        else
                                            c
                                    )
                                )
                                model.calendars
                    }
            in
            ( next
            , Cmd.batch
                [ Api.patchListEntry entry.id [ ( "selected", Encode.bool on ) ] GotListEntry
                , if on then
                    loadCalendar next entry.id

                  else
                    Cmd.none
                ]
            )

        GotListEntry (Ok entry) ->
            ( { model
                | calendars =
                    Remote.map
                        (List.map
                            (\c ->
                                if c.id == entry.id then
                                    entry

                                else
                                    c
                            )
                        )
                        model.calendars
              }
            , Cmd.none
            )

        GotListEntry (Err problem) ->
            toast Theme.Danger (Api.message problem) model

        OpenOccurrence occ ->
            let
                ( modal, cmd ) =
                    Modal.open "" model.detailsModal
            in
            ( { model | details = Just occ, detailsModal = modal }, Cmd.map DetailsModalMsg cmd )

        DetailsModalMsg m ->
            Modal.update m model.detailsModal
                |> Tuple.mapBoth (\s -> { model | detailsModal = s }) (Cmd.map DetailsModalMsg)

        Respond event status ->
            case model.auth of
                SignedIn user ->
                    ( model, Api.respond "primary" event user.email status GotResponse )

                _ ->
                    ( model, Cmd.none )

        GotResponse (Ok event) ->
            let
                answer =
                    Gcal.selfAttendee event |> Maybe.map .responseStatus |> Maybe.withDefault NeedsAction

                updateDetails occ =
                    if occ.event.id == event.id then
                        { occ | event = { event | recurrence = occ.event.recurrence } }

                    else
                        occ
            in
            toast Theme.Success ("You answered " ++ answerText answer ++ " to " ++ event.summary ++ ".") { model | details = Maybe.map updateDetails model.details }
                |> andThen reloadAll

        GotResponse (Err problem) ->
            toast Theme.Danger (Api.message problem) model

        OpenSlot date minute ->
            openEditor (newEditor date minute (primaryId model)) "" model

        OpenNew ->
            openEditor (newEditor model.focus (nextHour model) (primaryId model)) "create-event" model

        EditOccurrence occ ->
            let
                ( details, cmd ) =
                    Modal.close model.detailsModal

                ( next, editCmd ) =
                    openEditor (editorFor occ) "" { model | detailsModal = details }
            in
            ( next, Cmd.batch [ Cmd.map DetailsModalMsg cmd, editCmd ] )

        EditorModalMsg m ->
            Modal.update m model.editorModal
                |> Tuple.mapBoth (\s -> { model | editorModal = s }) (Cmd.map EditorModalMsg)

        EditorSummary text ->
            updateEditor (\e -> { e | summary = text }) model

        EditorAllDay on ->
            updateEditor (\e -> { e | allDay = on }) model

        EditorStartMsg m ->
            let
                editor =
                    model.editor

                ( start, cmd ) =
                    DateTimePicker.update m editor.start

                end =
                    case ( DateTimePicker.value editor.start, DateTimePicker.value start, DateTimePicker.value editor.end ) of
                        ( Just before, Just after, Just oldEnd ) ->
                            if before /= after then
                                DateTimePicker.setValue (Just (fromWall (toWall after + toWall oldEnd - toWall before))) editor.end

                            else
                                editor.end

                        _ ->
                            editor.end

                repeat =
                    case DateTimePicker.value start of
                        Just dt ->
                            RecurrencePicker.setStart dt.date editor.repeat

                        Nothing ->
                            editor.repeat
            in
            ( { model | editor = { editor | start = start, end = end, repeat = repeat, problem = Nothing } }, Cmd.map EditorStartMsg cmd )

        EditorEndMsg m ->
            let
                editor =
                    model.editor

                ( end, cmd ) =
                    DateTimePicker.update m editor.end
            in
            ( { model | editor = { editor | end = end, problem = Nothing } }, Cmd.map EditorEndMsg cmd )

        EditorStartDayMsg m ->
            let
                editor =
                    model.editor

                ( startDay, cmd ) =
                    DatePicker.update m editor.startDay

                endDay =
                    case ( DatePicker.value editor.startDay, DatePicker.value startDay, DatePicker.value editor.endDay ) of
                        ( Just before, Just after, Just oldEnd ) ->
                            if before /= after then
                                DatePicker.setValue (Just (Date.addDays (Date.diffDays before oldEnd) after)) editor.endDay

                            else
                                editor.endDay

                        _ ->
                            editor.endDay

                repeat =
                    case DatePicker.value startDay of
                        Just date ->
                            RecurrencePicker.setStart date editor.repeat

                        Nothing ->
                            editor.repeat
            in
            ( { model | editor = { editor | startDay = startDay, endDay = endDay, repeat = repeat, problem = Nothing } }, Cmd.map EditorStartDayMsg cmd )

        EditorEndDayMsg m ->
            let
                editor =
                    model.editor

                ( endDay, cmd ) =
                    DatePicker.update m editor.endDay
            in
            ( { model | editor = { editor | endDay = endDay, problem = Nothing } }, Cmd.map EditorEndDayMsg cmd )

        EditorRepeatMsg m ->
            let
                editor =
                    model.editor

                ( repeat, cmd ) =
                    RecurrencePicker.update m editor.repeat
            in
            ( { model | editor = { editor | repeat = repeat } }, Cmd.map EditorRepeatMsg cmd )

        EditorCalendarMsg m ->
            let
                editor =
                    model.editor

                ( calendar, cmd ) =
                    Select.update m editor.calendar
            in
            ( { model | editor = { editor | calendar = calendar } }, Cmd.map EditorCalendarMsg cmd )

        EditorColorMsg m ->
            let
                editor =
                    model.editor

                ( color, cmd ) =
                    Select.update m editor.color
            in
            ( { model | editor = { editor | color = color } }, Cmd.map EditorColorMsg cmd )

        EditorLocation text ->
            updateEditor (\e -> { e | location = text }) model

        EditorDescription text ->
            updateEditor (\e -> { e | description = text }) model

        EditorGuestsMsg m ->
            let
                editor =
                    model.editor

                ( guests, cmd ) =
                    TagInput.update m editor.guests
            in
            ( { model | editor = { editor | guests = guests } }, Cmd.map EditorGuestsMsg cmd )

        SaveEvent ->
            let
                editor =
                    model.editor
            in
            case buildEvent model editor of
                Err problem ->
                    ( { model | editor = { editor | problem = Just problem } }, Cmd.none )

                Ok ( calendarId, event ) ->
                    ( { model | editor = { editor | busy = True, problem = Nothing } }
                    , case editor.original of
                        Just occ ->
                            Api.patchEvent occ.calendar.id occ.event.id model.zoneName (Gcal.encodeEvent event) GotSaved

                        Nothing ->
                            Api.insertEvent calendarId model.zoneName event GotSaved
                    )

        GotSaved (Ok event) ->
            let
                editor =
                    model.editor

                ( modal, cmd ) =
                    Modal.close model.editorModal
            in
            toast Theme.Success
                ((if event.summary == "" then
                    "The event"

                  else
                    "“" ++ event.summary ++ "”"
                 )
                    ++ " was saved."
                )
                { model | editor = { editor | busy = False }, editorModal = modal }
                |> andThen reloadAll
                |> Tuple.mapSecond (\c -> Cmd.batch [ c, Cmd.map EditorModalMsg cmd ])

        GotSaved (Err problem) ->
            let
                editor =
                    model.editor
            in
            ( { model | editor = { editor | busy = False, problem = Just (Api.message problem) } }, Cmd.none )

        AskDeleteEvent occ ->
            ask (DeleteEvent occ) "details-delete" { model | deleteAll = False }

        SetDeleteAll all ->
            ( { model | deleteAll = all }, Cmd.none )

        ConfirmMsg m ->
            ConfirmDialog.update m model.confirm
                |> Tuple.mapBoth (\s -> { model | confirm = s }) (Cmd.map ConfirmMsg)

        CancelPending ->
            let
                ( confirm, cmd ) =
                    ConfirmDialog.close model.confirm
            in
            ( { model | confirm = confirm, pending = Nothing }, Cmd.map ConfirmMsg cmd )

        ConfirmPending ->
            let
                busy =
                    { model | confirm = ConfirmDialog.setBusy model.confirm }
            in
            case model.pending of
                Just (DeleteEvent occ) ->
                    if isRecurring occ.event && not model.deleteAll then
                        ( busy
                        , Api.patchEvent occ.calendar.id
                            occ.event.id
                            model.zoneName
                            (Encode.object [ ( "recurrence", Encode.list Encode.string (occ.event.recurrence ++ [ exdateLine model occ ]) ) ])
                            (GotDeleted << Result.map (\_ -> ()))
                        )

                    else
                        ( busy, Api.deleteEvent occ.calendar.id occ.event.id GotDeleted )

                Just (DeleteCalendar entry) ->
                    ( busy, Api.deleteCalendar entry.id GotDeleted )

                Just (Unsubscribe entry) ->
                    ( busy, Api.unsubscribe entry.id GotDeleted )

                Nothing ->
                    ( model, Cmd.none )

        GotDeleted (Ok ()) ->
            let
                ( confirm, confirmCmd ) =
                    ConfirmDialog.close model.confirm

                ( details, detailsCmd ) =
                    Modal.close model.detailsModal

                ( calendarModal, calendarCmd ) =
                    Modal.close model.calendarModal

                text =
                    case model.pending of
                        Just (DeleteEvent _) ->
                            "The event was deleted."

                        Just (DeleteCalendar entry) ->
                            "The calendar “" ++ entry.summary ++ "” was deleted."

                        Just (Unsubscribe entry) ->
                            "“" ++ entry.summary ++ "” was removed from your list."

                        Nothing ->
                            "Done."
            in
            toast Theme.Success text { model | confirm = confirm, detailsModal = details, calendarModal = calendarModal, pending = Nothing }
                |> andThen reloadAll
                |> Tuple.mapSecond (\c -> Cmd.batch [ c, Cmd.map ConfirmMsg confirmCmd, Cmd.map DetailsModalMsg detailsCmd, Cmd.map CalendarModalMsg calendarCmd ])

        GotDeleted (Err problem) ->
            ( { model | confirm = ConfirmDialog.setFailed problem model.confirm }, Cmd.none )

        OpenNewCalendar ->
            let
                ( modal, cmd ) =
                    Modal.open "new-calendar" (Modal.setInitialFocus [ "calendar-name" ] model.calendarModal)
            in
            ( { model | calendarModal = modal, calendarForm = emptyCalendarForm }, Cmd.map CalendarModalMsg cmd )

        OpenCalendarSettings entry ->
            let
                ( modal, cmd ) =
                    Modal.open ("calendar-settings-" ++ domId entry.id) model.calendarModal

                colorId =
                    Gcal.calendarColors
                        |> List.filter (\( _, hex, _ ) -> hex == entry.backgroundColor)
                        |> List.head
                        |> Maybe.map (\( id, _, _ ) -> id)
                        |> Maybe.withDefault ""
            in
            ( { model
                | calendarModal = modal
                , calendarForm =
                    { emptyCalendarForm
                        | entry = Just entry
                        , name = entry.summary
                        , description = entry.description
                        , color = Select.init "calendar-color" |> Select.setValue (Just colorId)
                        , acl =
                            if entry.accessRole == Owner then
                                Loading

                            else
                                NotAsked
                    }
              }
            , Cmd.batch
                [ Cmd.map CalendarModalMsg cmd
                , if entry.accessRole == Owner then
                    Api.aclList entry.id GotAcl

                  else
                    Cmd.none
                ]
            )

        CalendarModalMsg m ->
            Modal.update m model.calendarModal
                |> Tuple.mapBoth (\s -> { model | calendarModal = s }) (Cmd.map CalendarModalMsg)

        CalendarName text ->
            updateCalendarForm (\f -> { f | name = text, problem = Nothing }) model

        CalendarDescription text ->
            updateCalendarForm (\f -> { f | description = text }) model

        CalendarColorMsg m ->
            let
                form =
                    model.calendarForm

                ( color, cmd ) =
                    Select.update m form.color

                changed =
                    Select.value color /= Select.value form.color
            in
            ( { model | calendarForm = { form | color = color } }
            , Cmd.batch
                [ Cmd.map CalendarColorMsg cmd
                , case ( changed, form.entry, Select.value color ) of
                    ( True, Just entry, Just colorId ) ->
                        Api.patchListEntry entry.id [ ( "colorId", Encode.string colorId ) ] GotListEntry

                    _ ->
                        Cmd.none
                ]
            )

        SaveCalendar ->
            let
                form =
                    model.calendarForm
            in
            if String.trim form.name == "" then
                updateCalendarForm (\f -> { f | problem = Just "Give the calendar a name." }) model

            else
                ( { model | calendarForm = { form | busy = True, problem = Nothing } }
                , case form.entry of
                    Just entry ->
                        Api.patchCalendar entry.id { summary = String.trim form.name, description = form.description } GotCalendarSaved

                    Nothing ->
                        Api.createCalendar { summary = String.trim form.name, description = form.description, timeZone = model.zoneName } GotCalendarCreated
                )

        GotCalendarCreated (Ok _) ->
            let
                ( modal, cmd ) =
                    Modal.close model.calendarModal
            in
            toast Theme.Success ("The calendar “" ++ String.trim model.calendarForm.name ++ "” was created. Share it from its settings.") { model | calendarModal = modal, calendarForm = emptyCalendarForm }
                |> andThen reloadAll
                |> Tuple.mapSecond (\c -> Cmd.batch [ c, Cmd.map CalendarModalMsg cmd ])

        GotCalendarCreated (Err problem) ->
            updateCalendarForm (\f -> { f | busy = False, problem = Just (Api.message problem) }) model

        GotCalendarSaved (Ok ()) ->
            toast Theme.Success "The calendar was saved." model
                |> andThen (updateCalendarForm (\f -> { f | busy = False }))
                |> andThen reloadAll

        GotCalendarSaved (Err problem) ->
            updateCalendarForm (\f -> { f | busy = False, problem = Just (Api.message problem) }) model

        GotAcl result ->
            updateCalendarForm (\f -> { f | acl = Remote.fromResult result }) model

        ShareWithMsg m ->
            let
                form =
                    model.calendarForm

                ( shareWith, cmd ) =
                    Select.update m form.shareWith
            in
            ( { model | calendarForm = { form | shareWith = shareWith, problem = Nothing } }, Cmd.map ShareWithMsg cmd )

        ShareRole role ->
            updateCalendarForm (\f -> { f | shareRole = role }) model

        Share ->
            let
                form =
                    model.calendarForm
            in
            case ( form.entry, Select.value form.shareWith ) of
                ( Just entry, Just email ) ->
                    ( { model | calendarForm = { form | busy = True } }
                    , Api.aclInsert entry.id { email = email, role = Gcal.accessRoleFromString form.shareRole } (GotAclChange << Result.map (\_ -> ()))
                    )

                _ ->
                    updateCalendarForm (\f -> { f | problem = Just "Choose a person, or write an email address." }) model

        ChangeRole rule role ->
            case model.calendarForm.entry of
                Just entry ->
                    ( model, Api.aclInsert entry.id { email = rule.email, role = Gcal.accessRoleFromString role } (GotAclChange << Result.map (\_ -> ())) )

                Nothing ->
                    ( model, Cmd.none )

        RemoveRule rule ->
            case model.calendarForm.entry of
                Just entry ->
                    ( model, Api.aclDelete entry.id rule.id GotAclChange )

                Nothing ->
                    ( model, Cmd.none )

        GotAclChange (Ok ()) ->
            case model.calendarForm.entry of
                Just entry ->
                    updateCalendarForm (\f -> { f | busy = False, shareWith = Select.clear f.shareWith }) model
                        |> andThen (\m -> ( m, Api.aclList entry.id GotAcl ))

                Nothing ->
                    ( model, Cmd.none )

        GotAclChange (Err problem) ->
            updateCalendarForm (\f -> { f | busy = False, problem = Just (Api.message problem) }) model

        AskDeleteCalendar entry ->
            ask (DeleteCalendar entry) "calendar-delete" model

        AskUnsubscribe entry ->
            ask (Unsubscribe entry) "calendar-unsubscribe" model

        PrepareExport entry ->
            ( model
            , Api.events
                { calendarId = entry.id
                , from = Date.fromEpochDay 0
                , to = Date.addDays 36500 model.today
                , zone = model.zoneName
                }
                (GotExport entry)
            )

        GotExport entry (Ok events) ->
            let
                text =
                    Ics.export { zoneName = model.zoneName, now = model.now, name = entry.summary } events
            in
            updateCalendarForm (\f -> { f | export = Just text }) model

        GotExport _ (Err problem) ->
            toast Theme.Danger (Api.message problem) model

        FileDropMsg m ->
            let
                ( fileDrop, cmd ) =
                    FileDrop.update m model.fileDrop

                read =
                    case FileDrop.rawFiles fileDrop of
                        file :: _ ->
                            if FileDrop.rawFiles model.fileDrop /= FileDrop.rawFiles fileDrop then
                                Task.perform (GotFileText (File.name file)) (File.toString file)

                            else
                                Cmd.none

                        [] ->
                            Cmd.none
            in
            ( { model
                | fileDrop = fileDrop
                , file =
                    if List.isEmpty (FileDrop.rawFiles fileDrop) then
                        Nothing

                    else
                        model.file
              }
            , Cmd.batch [ Cmd.map FileDropMsg cmd, read ]
            )

        GotFileText name text ->
            ( { model | file = Just ( name, readImport name text ), fileProgress = Idle, reply = Nothing }, Cmd.none )

        FileTargetMsg m ->
            Select.update m model.fileTarget
                |> Tuple.mapBoth (\s -> { model | fileTarget = s }) (Cmd.map FileTargetMsg)

        ImportFile ->
            case model.file of
                Just ( name, Ok (IcsFile calendar) ) ->
                    let
                        target =
                            Select.value model.fileTarget |> Maybe.withDefault "primary"
                    in
                    if target == "new" then
                        ( { model | fileProgress = Working }
                        , Api.createCalendar
                            { summary =
                                if calendar.name == "" then
                                    String.replace ".ics" "" name

                                else
                                    calendar.name
                            , description = ""
                            , timeZone =
                                if calendar.timeZone == "" then
                                    model.zoneName

                                else
                                    calendar.timeZone
                            }
                            (GotImportCalendar calendar.events)
                        )

                    else
                        ( { model | fileProgress = Working }, importEvents target calendar.events GotFileImport )

                Just ( _, Ok (GoogleFile entry items) ) ->
                    ( { model | fileProgress = Working }
                    , Api.googleImport entry items
                        |> Task.map .imported
                        |> Task.attempt GotFileImport
                    )

                _ ->
                    ( model, Cmd.none )

        GotImportCalendar events (Ok calendarId) ->
            ( model, importEvents calendarId events GotFileImport )

        GotImportCalendar _ (Err problem) ->
            ( { model | fileProgress = ImportFailed (Api.message problem) }, Cmd.none )

        GotFileImport (Ok count) ->
            ( { model | fileProgress = Done (Format.plural Locale.en count { one = "1 event was imported.", other = String.fromInt count ++ " events were imported." }) }, Cmd.none )
                |> andThen reloadAll

        GotFileImport (Err problem) ->
            ( { model | fileProgress = ImportFailed (Api.message problem) }, Cmd.none )

        AnswerInvitation event status ->
            case model.auth of
                SignedIn user ->
                    ( { model | fileProgress = Working }
                    , importEvents "primary" [ withAnswer user status event ] (GotInvitationImport event status)
                    )

                _ ->
                    ( model, Cmd.none )

        GotInvitationImport event status (Ok _) ->
            case model.auth of
                SignedIn user ->
                    ( { model
                        | fileProgress = Done ("“" ++ event.summary ++ "” is in your calendar, answered " ++ answerText status ++ ".")
                        , reply =
                            Just
                                ( "reply.ics"
                                , Ics.reply { zoneName = model.zoneName, now = model.now, email = user.email, name = user.name, status = status } event
                                )
                      }
                    , Cmd.none
                    )
                        |> andThen reloadAll

                _ ->
                    ( model, Cmd.none )

        GotInvitationImport _ _ (Err problem) ->
            ( { model | fileProgress = ImportFailed (Api.message problem) }, Cmd.none )

        GotGoogleCalendars result ->
            ( { model | googleCalendars = Remote.fromResult result }, Cmd.none )

        ChooseGoogle id on ->
            ( { model
                | googleChosen =
                    if on then
                        id :: List.filter ((/=) id) model.googleChosen

                    else
                        List.filter ((/=) id) model.googleChosen
              }
            , Cmd.none
            )

        ImportGoogle ->
            case ( model.googleToken, Remote.toMaybe model.googleCalendars ) of
                ( Just token, Just calendars ) ->
                    let
                        chosen =
                            List.filter (\c -> List.member c.id model.googleChosen) calendars
                    in
                    ( { model | googleProgress = Working }
                    , chosen
                        |> List.map (\entry -> Api.googleEvents token entry.id |> Task.andThen (Api.googleImport entry))
                        |> Task.sequence
                        |> Task.attempt GotGoogleImport
                    )

                _ ->
                    ( model, Cmd.none )

        GotGoogleImport (Ok results) ->
            ( { model
                | googleProgress =
                    Done
                        (results
                            |> List.map (\r -> "“" ++ r.summary ++ "”: " ++ String.fromInt r.imported ++ " events")
                            |> String.join ", "
                            |> (\s -> "Imported " ++ s ++ ".")
                        )
                , googleChosen = []
              }
            , Cmd.none
            )
                |> andThen reloadAll

        GotGoogleImport (Err problem) ->
            ( { model
                | googleProgress =
                    ImportFailed
                        (if Remote.kind problem == Remote.unauthorized then
                            "Google did not accept the access any longer. Connect again."

                         else
                            Api.message problem
                        )
              }
            , Cmd.none
            )



-- UPDATE HELPERS


andThen : (Model -> ( Model, Cmd Msg )) -> ( Model, Cmd Msg ) -> ( Model, Cmd Msg )
andThen f ( model, cmd ) =
    let
        ( next, cmd2 ) =
            f model
    in
    ( next, Cmd.batch [ cmd, cmd2 ] )


{-| A new ticket for the event requests that the command just sent, so that
older answers are dropped. `loadEvents` reads `model.ticket + 1`.
-}
withTicket : Bool -> ( Model, Cmd Msg ) -> ( Model, Cmd Msg )
withTicket bump ( model, cmd ) =
    if bump then
        ( { model | ticket = model.ticket + 1 }, cmd )

    else
        ( model, cmd )


toast : Theme.Tone -> String -> Model -> ( Model, Cmd Msg )
toast tone text model =
    Toast.push [ Toast.tone tone, Toast.message text ] model.toasts
        |> Tuple.mapBoth (\t -> { model | toasts = t }) (Cmd.map ToastMsg)


ask : Pending -> String -> Model -> ( Model, Cmd Msg )
ask pending opener model =
    let
        ( confirm, cmd ) =
            ConfirmDialog.open opener model.confirm
    in
    ( { model | pending = Just pending, confirm = confirm }, Cmd.map ConfirmMsg cmd )


isSignedIn : Model -> Bool
isSignedIn model =
    case model.auth of
        SignedIn _ ->
            True

        _ ->
            False


signedIn : User -> Model -> ( Model, Cmd Msg )
signedIn user model =
    ( { model | auth = SignedIn user, calendars = Loading }
    , Cmd.batch [ Api.calendarList GotCalendars, Api.people GotPeople, loadInvites model, scrollToMorning ]
    )


reloadAll : Model -> ( Model, Cmd Msg )
reloadAll model =
    ( { model | calendars = Remote.refresh model.calendars }
    , Cmd.batch [ Api.calendarList GotCalendars, loadInvites model ]
    )


loadInvites : Model -> Cmd Msg
loadInvites model =
    Api.events { calendarId = "primary", from = model.today, to = Date.addDays 366 model.today, zone = model.zoneName } GotInvites


{-| The events of every shown calendar for the period on screen. Answers carry
`model.ticket + 1` (see `withTicket`).
-}
loadEvents : Model -> Cmd Msg
loadEvents model =
    case Remote.toMaybe model.calendars of
        Just calendars ->
            calendars
                |> List.filter .selected
                |> List.map (\c -> loadCalendarWith (model.ticket + 1) model c.id)
                |> Cmd.batch

        Nothing ->
            Cmd.none


loadCalendar : Model -> String -> Cmd Msg
loadCalendar model id =
    loadCalendarWith model.ticket model id


loadCalendarWith : Int -> Model -> String -> Cmd Msg
loadCalendarWith ticket model id =
    let
        ( from, to ) =
            fetchRange model
    in
    Api.events { calendarId = id, from = from, to = to, zone = model.zoneName } (GotEvents ticket id)


goTo : Date -> Model -> ( Model, Cmd Msg )
goTo date model =
    let
        next =
            { model | focus = date, mini = model.mini |> Calendar.setValue (Just date) |> Calendar.showDate date }
    in
    if fetchRange next == fetchRange model then
        ( next, Cmd.none )

    else
        ( next, loadEvents next ) |> withTicket True


scrollToMorning : Cmd Msg
scrollToMorning =
    Process.sleep 200
        |> Task.andThen (\_ -> Dom.setViewportOf "time-grid" 0 (toFloat (7 * Grid.hourHeight)))
        |> Task.attempt (\_ -> NoOp)


modeFromKey : String -> Mode
modeFromKey key =
    case key of
        "day" ->
            DayMode

        "month" ->
            MonthMode

        "agenda" ->
            AgendaMode

        _ ->
            WeekMode


modeKey : Mode -> String
modeKey mode =
    case mode of
        DayMode ->
            "day"

        WeekMode ->
            "week"

        MonthMode ->
            "month"

        AgendaMode ->
            "agenda"


step : Int -> Model -> Date
step direction model =
    case model.mode of
        DayMode ->
            Date.addDays direction model.focus

        WeekMode ->
            Date.addDays (7 * direction) model.focus

        MonthMode ->
            Date.addMonths direction model.focus

        AgendaMode ->
            Date.addDays (30 * direction) model.focus


mondayOf : Date -> Date
mondayOf date =
    Date.addDays (1 - Date.weekday date) date


{-| The dates on screen, `to` exclusive.
-}
visibleRange : Model -> ( Date, Date )
visibleRange model =
    case model.mode of
        DayMode ->
            ( model.focus, Date.addDays 1 model.focus )

        WeekMode ->
            ( mondayOf model.focus, Date.addDays 7 (mondayOf model.focus) )

        MonthMode ->
            let
                first =
                    mondayOf (Date.startOfMonth model.focus)
            in
            ( first, Date.addDays 42 first )

        AgendaMode ->
            ( model.focus, Date.addDays 30 model.focus )


{-| What is fetched: the six weeks of the month around the period on screen, so
moving a day or a week inside a month asks the server nothing.
-}
fetchRange : Model -> ( Date, Date )
fetchRange model =
    let
        ( from, to ) =
            visibleRange model

        monthFirst =
            mondayOf (Date.startOfMonth model.focus)
    in
    ( minDate from monthFirst, maxDate to (Date.addDays 42 monthFirst) )


minDate : Date -> Date -> Date
minDate a b =
    if Date.compare a b == GT then
        b

    else
        a


maxDate : Date -> Date -> Date
maxDate a b =
    if Date.compare a b == GT then
        a

    else
        b


primaryId : Model -> String
primaryId model =
    Remote.toMaybe model.calendars
        |> Maybe.andThen (List.filter .primary >> List.head)
        |> Maybe.map .id
        |> Maybe.withDefault "primary"


nextHour : Model -> Int
nextHour model =
    min (22 * 60) ((Time.toHour model.zone model.now + 1) * 60)


inviteCount : Model -> Int
inviteCount model =
    List.length (pendingInvites model)


pendingInvites : Model -> List Event
pendingInvites model =
    Remote.toMaybe model.invites
        |> Maybe.withDefault []
        |> List.filter
            (\e ->
                case Gcal.selfAttendee e of
                    Just me ->
                        me.responseStatus == NeedsAction && not me.organizer

                    Nothing ->
                        False
            )


isRecurring : Event -> Bool
isRecurring event =
    List.any (String.startsWith "RRULE") event.recurrence


domId : String -> String
domId text =
    String.map
        (\c ->
            if Char.isAlphaNum c then
                c

            else
                '-'
        )
        text


answerText : ResponseStatus -> String
answerText status =
    case status of
        Accepted ->
            "yes"

        Tentative ->
            "maybe"

        Declined ->
            "no"

        NeedsAction ->
            "not yet"


withAnswer : User -> ResponseStatus -> Event -> Event
withAnswer user status event =
    let
        mine a =
            a.email == String.toLower user.email
    in
    if List.any mine event.attendees then
        { event
            | attendees =
                List.map
                    (\a ->
                        if mine a then
                            { a | responseStatus = status }

                        else
                            a
                    )
                    event.attendees
        }

    else
        { event | attendees = event.attendees ++ [ { email = user.email, displayName = user.name, self = True, organizer = False, optional = False, responseStatus = status } ] }


importEvents : String -> List Event -> (Result Problem Int -> Msg) -> Cmd Msg
importEvents calendarId events toMsg =
    events
        |> List.map (Api.importEvent calendarId)
        |> Task.sequence
        |> Task.map List.length
        |> Task.attempt toMsg


readImport : String -> String -> Result String ImportContent
readImport name text =
    if String.endsWith ".json" (String.toLower name) then
        Decode.decodeString
            (Decode.map3
                (\summary zone items ->
                    GoogleFile
                        { id = ""
                        , summary =
                            if summary == "" then
                                String.replace ".json" "" name

                            else
                                summary
                        , description = ""
                        , timeZone = zone
                        , backgroundColor = "#4986e7"
                        , foregroundColor = "#000000"
                        , accessRole = Owner
                        , primary = False
                        , selected = True
                        }
                        items
                )
                (Decode.oneOf [ Decode.field "summary" Decode.string, Decode.succeed "" ])
                (Decode.oneOf [ Decode.field "timeZone" Decode.string, Decode.succeed "UTC" ])
                (Decode.field "items" (Decode.list Decode.value))
            )
            text
            |> Result.mapError (\_ -> "This JSON is not a Google Calendar events list (it needs an “items” list).")

    else
        Ics.parse text |> Result.map IcsFile


updateEditor : (Editor -> Editor) -> Model -> ( Model, Cmd Msg )
updateEditor f model =
    ( { model | editor = f model.editor }, Cmd.none )


updateCalendarForm : (CalendarForm -> CalendarForm) -> Model -> ( Model, Cmd Msg )
updateCalendarForm f model =
    ( { model | calendarForm = f model.calendarForm }, Cmd.none )


openEditor : Editor -> String -> Model -> ( Model, Cmd Msg )
openEditor editor opener model =
    let
        ( modal, cmd ) =
            Modal.open opener (Modal.setInitialFocus [ "event-title" ] model.editorModal)
    in
    ( { model | editor = editor, editorModal = modal }, Cmd.map EditorModalMsg cmd )


toWall : DateTimePicker.DateTime -> Int
toWall dt =
    Date.toEpochDay dt.date * 1440 + dt.time.hour * 60 + dt.time.minute


fromWall : Int -> DateTimePicker.DateTime
fromWall wall =
    let
        day =
            floor (toFloat wall / 1440)

        minute =
            wall - day * 1440
    in
    { date = Date.fromEpochDay day, time = { hour = minute // 60, minute = modBy 60 minute } }


{-| The editor for an existing event: a recurring event is edited as a series,
from its first date.
-}
editorFor : Occurrence -> Editor
editorFor occ =
    let
        event =
            occ.event

        base =
            newEditor occ.date 540 occ.calendar.id
    in
    { base
        | original = Just occ
        , summary = event.summary
        , location = event.location
        , description = event.description
        , color = Select.init "event-color" |> Select.setValue (Just event.colorId)
        , guests = TagInput.init "event-guests" |> TagInput.setValues (List.filter (not << .organizer) event.attendees |> List.map .email)
    }
        |> (\e ->
                case ( event.start, event.end ) of
                    ( AllDay s, AllDay en ) ->
                        { e
                            | allDay = True
                            , startDay = DatePicker.setValue (Just s) e.startDay
                            , endDay = DatePicker.setValue (Just (Date.addDays -1 en)) e.endDay
                            , repeat = RecurrencePicker.init "event-repeat" s |> RecurrencePicker.setValue (Occurrence.rule event)
                        }

                    _ ->
                        let
                            s =
                                fromWall (Occurrence.wallOf event.start)

                            en =
                                fromWall (Occurrence.wallOf event.end)
                        in
                        { e
                            | allDay = False
                            , start = DateTimePicker.setValue (Just s) e.start
                            , end = DateTimePicker.setValue (Just en) e.end
                            , startDay = DatePicker.setValue (Just s.date) e.startDay
                            , endDay = DatePicker.setValue (Just en.date) e.endDay
                            , repeat = RecurrencePicker.init "event-repeat" s.date |> RecurrencePicker.setValue (Occurrence.rule event)
                        }
           )


buildEvent : Model -> Editor -> Result String ( String, Event )
buildEvent model editor =
    let
        times =
            if editor.allDay then
                case ( DatePicker.value editor.startDay, DatePicker.value editor.endDay ) of
                    ( Just s, Just e ) ->
                        if Date.compare e s == LT then
                            Err "The event ends before it starts."

                        else
                            Ok ( AllDay s, AllDay (Date.addDays 1 e) )

                    _ ->
                        Err "Choose the first and the last day."

            else
                case ( DateTimePicker.value editor.start, DateTimePicker.value editor.end ) of
                    ( Just s, Just e ) ->
                        if toWall e <= toWall s then
                            Err "The event must end after it starts."

                        else
                            Ok
                                ( Timed { date = s.date, minute = s.time.hour * 60 + s.time.minute, offset = "", timeZone = model.zoneName }
                                , Timed { date = e.date, minute = e.time.hour * 60 + e.time.minute, offset = "", timeZone = model.zoneName }
                                )

                    _ ->
                        Err "Choose when the event starts and ends."

        original =
            Maybe.map .event editor.original

        recurrence startTime =
            case RecurrencePicker.value editor.repeat of
                Just r ->
                    let
                        keptExdates =
                            case original of
                                Just o ->
                                    if Occurrence.wallOf o.start == Occurrence.wallOf startTime then
                                        List.filter (String.startsWith "EXDATE") o.recurrence

                                    else
                                        []

                                Nothing ->
                                    []
                    in
                    Ok (("RRULE:" ++ Recurrence.toRRule r) :: keptExdates)

                Nothing ->
                    case RecurrencePicker.problem editor.repeat of
                        Just problem ->
                            Err (RecurrencePicker.problemText Locale.en problem)

                        Nothing ->
                            Ok []

        previousAnswer email =
            original
                |> Maybe.map .attendees
                |> Maybe.withDefault []
                |> List.filter (\a -> a.email == email)
                |> List.head

        attendees =
            TagInput.values editor.guests
                |> List.map String.toLower
                |> List.map
                    (\email ->
                        previousAnswer email
                            |> Maybe.withDefault { email = email, displayName = "", self = False, organizer = False, optional = False, responseStatus = NeedsAction }
                    )
                |> (\guests ->
                        case original of
                            Just o ->
                                List.filter .organizer o.attendees ++ guests

                            Nothing ->
                                guests
                   )
    in
    times
        |> Result.andThen
            (\( start, end ) ->
                recurrence start
                    |> Result.map
                        (\rec ->
                            let
                                base =
                                    Maybe.withDefault (Gcal.emptyEvent start end) original
                            in
                            ( Select.value editor.calendar |> Maybe.withDefault (primaryId model)
                            , { base
                                | summary = String.trim editor.summary
                                , location = String.trim editor.location
                                , description = editor.description
                                , start = start
                                , end = end
                                , recurrence = rec
                                , attendees =
                                    if List.all .organizer attendees then
                                        []

                                    else
                                        attendees
                                , colorId = Select.value editor.color |> Maybe.withDefault ""
                                , organizer = Nothing
                                , iCalUID = ""
                              }
                            )
                        )
            )


exdateLine : Model -> Occurrence -> String
exdateLine model occ =
    let
        compact =
            String.replace "-" "" (Date.toIso occ.date)
    in
    if occ.allDay then
        "EXDATE;VALUE=DATE:" ++ compact

    else
        let
            minute =
                modBy 1440 occ.start
        in
        "EXDATE;TZID="
            ++ model.zoneName
            ++ ":"
            ++ compact
            ++ "T"
            ++ String.padLeft 2 '0' (String.fromInt (minute // 60))
            ++ String.padLeft 2 '0' (String.fromInt (modBy 60 minute))
            ++ "00"


{-| The occurrences of the shown calendars between two dates. An event that is
on the person's own calendar and on a calendar shared with them (an
invitation they also see there) is shown once, from their own.
-}
occurrencesBetween : Model -> Date -> Date -> List Occurrence
occurrencesBetween model from to =
    let
        calendars =
            Remote.toMaybe model.calendars
                |> Maybe.withDefault []
                |> List.filter .selected
                |> List.sortBy
                    (\c ->
                        if c.primary then
                            0

                        else
                            1
                    )

        step_ calendar ( seen, acc ) =
            let
                events =
                    Dict.get calendar.id model.events
                        |> Maybe.withDefault []
                        |> List.filter (\e -> not (List.member e.id seen))
            in
            ( List.map .id events ++ seen
            , acc ++ List.concatMap (Occurrence.expand { from = from, to = to } calendar) events
            )
    in
    List.foldl step_ ( [], [] ) calendars |> Tuple.second



-- VIEW


view : Model -> Browser.Document Msg
view model =
    { title =
        case ( Time.posixToMillis model.now == 0, model.page ) of
            ( True, _ ) ->
                "Calendar"

            ( _, CalendarPage ) ->
                periodTitle model ++ " · Calendar"

            ( _, InvitationsPage ) ->
                "Invitations · Calendar"

            ( _, ImportPage ) ->
                "Import · Calendar"
    , body =
        [ Klar.stylesheetFor model.settings
        , case ( Time.posixToMillis model.now == 0, model.auth ) of
            ( True, _ ) ->
                Layout.container [ Layout.padding 8 ] [ Spinner.view [ Spinner.label "Loading" ] ]

            ( _, Checking ) ->
                Layout.container [ Layout.padding 8 ] [ Spinner.view [ Spinner.label "Loading" ] ]

            ( _, SignedOut ) ->
                viewAuth model

            ( _, SignedIn user ) ->
                AppShell.view
                    [ AppShell.state ShellMsg model.shell
                    , AppShell.settings model.settings
                    , AppShell.brand (AppShell.brandLink { name = "Calendar", href = "#/", logo = Nothing })
                    , AppShell.sidebar (viewSidebar model)
                    , AppShell.userName user.name
                    , AppShell.userRole user.email
                    , AppShell.actions [ Button.view [ Button.ghost, Button.small, Button.icon Icon.logOut, Button.onClick SignOut ] "Sign out" ]
                    , AppShell.overlays
                        [ viewDetails model
                        , viewEditor model
                        , viewCalendarDialog model
                        , viewConfirm model
                        , Toast.view ToastMsg [] model.toasts
                        ]
                    ]
                    [ case model.page of
                        CalendarPage ->
                            viewCalendarPage model

                        InvitationsPage ->
                            viewInvitations model

                        ImportPage ->
                            viewImport model
                    ]
        ]
    }



-- SIGNING IN


viewAuth : Model -> Html Msg
viewAuth model =
    Layout.container [ Layout.maxWidth 440, Layout.padding 8 ]
        [ Layout.stack [ Layout.gap 4 ]
            [ Text.title "Calendar"
            , Text.secondary "Your calendars, shared calendars and invitations, in the format of Google Calendar."
            , if List.isEmpty model.demoUsers then
                Html.text ""

              else
                Card.view [ Card.title "Try it as", Card.subtitle "Demo people, no password needed." ]
                    [ Layout.stack [ Layout.gap 2 ]
                        (List.map
                            (\u ->
                                Button.view [ Button.block, Button.icon Icon.logIn, Button.onClick (DemoLogin u.email), Button.disabled model.authBusy ]
                                    (u.name ++ " (" ++ u.email ++ ")")
                            )
                            model.demoUsers
                        )
                    ]
            , Card.view
                [ Card.title
                    (if model.registering then
                        "Create an account"

                     else
                        "Sign in"
                    )
                ]
                [ Html.form [ Attr.novalidate True, onSubmit SubmitAuth ]
                    [ Layout.stack [ Layout.gap 3 ]
                        ([ SegmentedControl.view
                            [ SegmentedControl.options [ SegmentedControl.option "login" "Sign in", SegmentedControl.option "register" "Register" ]
                            , SegmentedControl.selected
                                (if model.registering then
                                    "register"

                                 else
                                    "login"
                                )
                            , SegmentedControl.onChange (\k -> SetRegistering (k == "register"))
                            , SegmentedControl.label "Account"
                            , SegmentedControl.labelHidden
                            , SegmentedControl.fullWidth
                            ]
                         ]
                            ++ (if model.registering then
                                    [ TextInput.view [ TextInput.label "Name", TextInput.id "auth-name", TextInput.value model.authName, TextInput.onInput AuthName, TextInput.autocomplete "name", TextInput.required ] ]

                                else
                                    []
                               )
                            ++ [ TextInput.view [ TextInput.label "Email", TextInput.id "auth-email", TextInput.email, TextInput.value model.authEmail, TextInput.onInput AuthEmail, TextInput.autocomplete "email", TextInput.required ]
                               , PasswordInput.view PasswordMsg
                                    [ PasswordInput.label "Password"
                                    , PasswordInput.onEnter SubmitAuth
                                    , if model.registering then
                                        PasswordInput.newPassword

                                      else
                                        PasswordInput.currentPassword
                                    , PasswordInput.hint
                                        (if model.registering then
                                            "At least 8 characters."

                                         else
                                            ""
                                        )
                                    , PasswordInput.required
                                    ]
                                    model.passwordInput
                               , case model.authProblem of
                                    Just problem ->
                                        Alert.view [ Alert.tone Theme.Danger ] problem

                                    Nothing ->
                                        Html.text ""
                               , Button.view
                                    [ Button.primary
                                    , Button.block
                                    , Button.submit
                                    , Button.loading model.authBusy
                                    ]
                                    (if model.registering then
                                        "Create account"

                                     else
                                        "Sign in"
                                    )
                               ]
                        )
                    ]
                ]
            ]
        ]


onSubmit : Msg -> Html.Attribute Msg
onSubmit msg =
    Html.Events.preventDefaultOn "submit" (Decode.succeed ( msg, True ))



-- SIDEBAR


viewSidebar : Model -> Html Msg
viewSidebar model =
    let
        calendars =
            Remote.toMaybe model.calendars |> Maybe.withDefault []

        mine =
            List.filter (\c -> c.accessRole == Owner) calendars

        others =
            List.filter (\c -> c.accessRole /= Owner) calendars
    in
    Layout.stack [ Layout.gap 4, Layout.padding 3 ]
        [ Button.view [ Button.primary, Button.block, Button.icon Icon.plus, Button.onClick OpenNew, Button.id "create-event-side" ] "Create event"
        , Calendar.view MiniMsg [ Calendar.ariaLabel "Go to date", Calendar.size Theme.Small ] (Calendar.setToday model.today model.mini)
        , AppShell.sideNav ShellMsg [ SideNav.entries (navigation (inviteCount model)), SideNav.ariaLabel "Pages" ] model.shell
        , calendarSection "My calendars"
            (Just (Button.iconOnly [ Button.ghost, Button.small, Button.onClick OpenNewCalendar, Button.id "new-calendar" ] Icon.plus "New calendar"))
            mine
        , if List.isEmpty others then
            Html.text ""

          else
            calendarSection "Other calendars" Nothing others
        ]


calendarSection : String -> Maybe (Html Msg) -> List CalendarEntry -> Html Msg
calendarSection title action entries =
    Html.section [ Attr.attribute "aria-label" title ]
        [ Layout.row [ Layout.alignCenter, Layout.justifyBetween ]
            [ Text.overline title, Maybe.withDefault (Html.text "") action ]
        , Layout.stack [ Layout.gap 1 ] (List.map calendarRow entries)
        ]


calendarRow : CalendarEntry -> Html Msg
calendarRow entry =
    -- KLAR GAP: a checkbox has no color of its own, so a swatch stands beside it
    Layout.row [ Layout.alignCenter, Layout.gap 2 ]
        [ Html.span
            [ Attr.style "flex" "none"
            , Attr.style "width" "12px"
            , Attr.style "height" "12px"
            , Attr.style "border-radius" "3px"
            , Attr.style "background" entry.backgroundColor
            , Attr.attribute "aria-hidden" "true"
            ]
            []
        , Html.div [ Attr.style "flex" "1", Attr.style "min-width" "0" ]
            [ Checkbox.view
                [ Checkbox.checked entry.selected
                , Checkbox.onCheck (ToggleCalendar entry)
                , Checkbox.label entry.summary
                , Checkbox.id ("show-" ++ domId entry.id)
                ]
            ]
        , Button.iconOnly
            [ Button.ghost
            , Button.small
            , Button.onClick (OpenCalendarSettings entry)
            , Button.id ("calendar-settings-" ++ domId entry.id)
            ]
            Icon.settings
            ("Settings and sharing for " ++ entry.summary)
        ]



-- CALENDAR PAGE


periodTitle : Model -> String
periodTitle model =
    let
        ( from, to ) =
            visibleRange model

        last =
            Date.addDays -1 to

        monthYear d =
            Grid.monthName (Date.month d) ++ " " ++ String.fromInt (Date.year d)
    in
    case model.mode of
        DayMode ->
            Format.dateLong Locale.en model.focus

        MonthMode ->
            monthYear model.focus

        _ ->
            if Date.month from == Date.month last then
                String.fromInt (Date.day from) ++ " – " ++ String.fromInt (Date.day last) ++ " " ++ monthYear last

            else if Date.year from == Date.year last then
                String.fromInt (Date.day from) ++ " " ++ Grid.monthName (Date.month from) ++ " – " ++ String.fromInt (Date.day last) ++ " " ++ monthYear last

            else
                String.fromInt (Date.day from) ++ " " ++ monthYear from ++ " – " ++ String.fromInt (Date.day last) ++ " " ++ monthYear last


viewCalendarPage : Model -> Html Msg
viewCalendarPage model =
    let
        ( from, to ) =
            visibleRange model

        occurrences =
            occurrencesBetween model from to

        config =
            { today = model.today
            , nowMinute = Time.toHour model.zone model.now * 60 + Time.toMinute model.zone model.now
            , onSlot = OpenSlot
            , onOpen = OpenOccurrence
            , onDay = GoToDay
            }

        previousLabel =
            case model.mode of
                DayMode ->
                    "Previous day"

                WeekMode ->
                    "Previous week"

                MonthMode ->
                    "Previous month"

                AgendaMode ->
                    "Previous 30 days"

        nextLabel =
            String.replace "Previous" "Next" previousLabel
    in
    Layout.stack [ Layout.gap 3 ]
        [ PageHeader.view
            [ PageHeader.title (periodTitle model)
            , PageHeader.actions
                [ Button.view [ Button.onClick GoToday ] "Today"
                , Button.iconOnly [ Button.ghost, Button.onClick GoPrevious ] Icon.chevronLeft previousLabel
                , Button.iconOnly [ Button.ghost, Button.onClick GoNext ] Icon.chevronRight nextLabel
                , SegmentedControl.view
                    [ SegmentedControl.options
                        [ SegmentedControl.option "day" "Day"
                        , SegmentedControl.option "week" "Week"
                        , SegmentedControl.option "month" "Month"
                        , SegmentedControl.option "agenda" "Agenda"
                        ]
                    , SegmentedControl.selected (modeKey model.mode)
                    , SegmentedControl.onChange SetMode
                    , SegmentedControl.label "View"
                    , SegmentedControl.labelHidden
                    ]
                , Button.view [ Button.primary, Button.icon Icon.plus, Button.onClick OpenNew, Button.id "create-event" ] "Create"
                ]
            ]
        , case model.eventsProblem of
            Just problem ->
                Alert.view
                    [ Alert.tone Theme.Danger
                    , Alert.title "Some events could not be loaded"
                    , Alert.actions [ Button.view [ Button.small, Button.onClick Reload ] "Try again" ]
                    ]
                    (Api.message problem)

            Nothing ->
                Html.text ""
        , case model.calendars of
            Failed problem ->
                Alert.view [ Alert.tone Theme.Danger, Alert.title "Your calendars could not be loaded", Alert.actions [ Button.view [ Button.small, Button.onClick Reload ] "Try again" ] ] (Api.message problem)

            _ ->
                case model.mode of
                    DayMode ->
                        Grid.week config [ model.focus ] occurrences

                    WeekMode ->
                        Grid.week config (List.map (\i -> Date.addDays i from) (List.range 0 6)) occurrences

                    MonthMode ->
                        Grid.month config model.focus occurrences

                    AgendaMode ->
                        Grid.agenda config from 30 occurrences
        ]



-- EVENT DETAILS


viewDetails : Model -> Overlay Msg
viewDetails model =
    case model.details of
        Nothing ->
            Modal.view DetailsModalMsg [] model.detailsModal "Event" []

        Just occ ->
            let
                event =
                    occ.event

                busyOnly =
                    occ.calendar.accessRole == FreeBusyReader

                me =
                    Gcal.selfAttendee event

                isGuest =
                    case me of
                        Just a ->
                            not a.organizer

                        Nothing ->
                            False

                editable =
                    Gcal.canEdit occ.calendar && not isGuest && not busyOnly

                line icon content =
                    Layout.row [ Layout.gap 2, Layout.alignStart ]
                        [ Html.span [ Attr.style "color" "var(--klar-text-muted)", Attr.style "padding-top" "2px" ] [ Icon.view icon ]
                        , Html.div [ Attr.style "min-width" "0", Attr.style "white-space" "pre-wrap", Attr.style "overflow-wrap" "anywhere" ] content
                        ]
            in
            Modal.view DetailsModalMsg
                [ Modal.subtitle (Format.dateLong Locale.en occ.date ++ " · " ++ Grid.timeRange occ)
                , Modal.medium
                , Modal.footerStart
                    (if editable then
                        [ Button.view [ Button.danger, Button.ghost, Button.icon Icon.trash, Button.onClick (AskDeleteEvent occ), Button.id "details-delete" ] "Delete" ]

                     else if isGuest then
                        [ Button.view [ Button.ghost, Button.icon Icon.trash, Button.onClick (Respond event Declined), Button.id "details-delete" ] "Remove (declines)" ]

                     else
                        []
                    )
                , Modal.footer
                    (if editable then
                        [ Button.view [ Button.primary, Button.icon Icon.edit, Button.onClick (EditOccurrence occ) ] "Edit" ]

                     else
                        []
                    )
                ]
                model.detailsModal
                (if busyOnly then
                    "Busy"

                 else if event.summary == "" then
                    "(No title)"

                 else
                    event.summary
                )
                [ Layout.stack [ Layout.gap 3 ]
                    (List.filterMap identity
                        [ case Occurrence.rule event of
                            Just r ->
                                Just (line Icon.refresh [ Html.text (Recurrence.describe Locale.en r) ])

                            Nothing ->
                                if isRecurring event then
                                    Just (line Icon.refresh [ Html.text "Repeats (a rule this calendar cannot show)" ])

                                else
                                    Nothing
                        , Just
                            (line Icon.calendar
                                [ Html.span [ Attr.style "display" "inline-block", Attr.style "width" "10px", Attr.style "height" "10px", Attr.style "border-radius" "50%", Attr.style "margin-right" "6px", Attr.style "background" (Grid.colorOf occ) ] []
                                , Html.text occ.calendar.summary
                                ]
                            )
                        , if event.location == "" || busyOnly then
                            Nothing

                          else
                            Just (line Icon.mapPin [ Html.text event.location ])
                        , if event.description == "" || busyOnly then
                            Nothing

                          else
                            Just (line Icon.fileText [ Html.text event.description ])
                        , case event.organizer of
                            Just o ->
                                if busyOnly then
                                    Nothing

                                else
                                    Just (line Icon.user [ Html.text ("Organizer: " ++ nameOf o.displayName o.email) ])

                            Nothing ->
                                Nothing
                        , if List.isEmpty event.attendees || busyOnly then
                            Nothing

                          else
                            Just (viewGuests event)
                        , case me of
                            Just a ->
                                if a.organizer then
                                    Nothing

                                else
                                    Just
                                        (SegmentedControl.view
                                            [ SegmentedControl.label "Going?"
                                            , SegmentedControl.options
                                                [ SegmentedControl.option "accepted" "Yes"
                                                , SegmentedControl.option "tentative" "Maybe"
                                                , SegmentedControl.option "declined" "No"
                                                ]
                                            , SegmentedControl.selected
                                                (if a.responseStatus == NeedsAction then
                                                    ""

                                                 else
                                                    Gcal.responseToString a.responseStatus
                                                )
                                            , SegmentedControl.onChange (\k -> Respond event (Gcal.responseFromString k))
                                            , SegmentedControl.id "details-answer"
                                            ]
                                        )

                            Nothing ->
                                Nothing
                        ]
                    )
                ]


nameOf : String -> String -> String
nameOf displayName email =
    if displayName == "" || String.toLower displayName == String.toLower email then
        email

    else
        displayName ++ " <" ++ email ++ ">"


viewGuests : Event -> Html Msg
viewGuests event =
    let
        count status =
            List.length (List.filter (\a -> a.responseStatus == status) event.attendees)

        summary =
            [ ( count Accepted, "yes" ), ( count Tentative, "maybe" ), ( count Declined, "no" ), ( count NeedsAction, "awaiting" ) ]
                |> List.filter (\( n, _ ) -> n > 0)
                |> List.map (\( n, word ) -> String.fromInt n ++ " " ++ word)
                |> String.join ", "
    in
    Layout.stack [ Layout.gap 2 ]
        [ Layout.row [ Layout.gap 2, Layout.alignCenter ]
            [ Icon.view Icon.users
            , Text.strong (Format.plural Locale.en (List.length event.attendees) { one = "1 guest", other = String.fromInt (List.length event.attendees) ++ " guests" })
            , Text.muted summary
            ]
        , ListItem.list [ ListItem.density Theme.Compact, ListItem.ariaLabel "Guests" ]
            (List.map
                (\a ->
                    ListItem.view
                        [ ListItem.leading (Avatar.view [ Avatar.size Theme.Small ] (nameOf a.displayName a.email |> String.split " <" |> List.head |> Maybe.withDefault a.email))
                        , ListItem.secondary
                            (a.email
                                ++ (if a.organizer then
                                        " · organizer"

                                    else if a.optional then
                                        " · optional"

                                    else
                                        ""
                                   )
                            )
                        , ListItem.trailing [ answerBadge a.responseStatus ]
                        ]
                        (if a.displayName == "" then
                            a.email

                         else
                            a.displayName
                        )
                )
                event.attendees
            )
        ]


answerBadge : ResponseStatus -> Html msg
answerBadge status =
    case status of
        Accepted ->
            Badge.status Theme.Success "Going"

        Tentative ->
            Badge.status Theme.Warning "Maybe"

        Declined ->
            Badge.status Theme.Danger "Not going"

        NeedsAction ->
            Badge.status Theme.Neutral "Awaiting"



-- EVENT EDITOR


viewEditor : Model -> Overlay Msg
viewEditor model =
    let
        editor =
            model.editor

        writable =
            Remote.toMaybe model.calendars
                |> Maybe.withDefault []
                |> List.filter Gcal.canEdit

        editing =
            editor.original /= Nothing
    in
    Modal.view EditorModalMsg
        [ Modal.large
        , Modal.busy editor.busy
        , Modal.footer
            [ Button.view [ Button.primary, Button.onClick SaveEvent, Button.loading editor.busy ] "Save" ]
        ]
        model.editorModal
        (if editing then
            "Edit event"

         else
            "New event"
        )
        [ Html.form [ Attr.novalidate True, onSubmit SaveEvent ]
            [ Layout.stack [ Layout.gap 3 ]
                [ TextInput.view
                    [ TextInput.label "Title"
                    , TextInput.id "event-title"
                    , TextInput.value editor.summary
                    , TextInput.onInput EditorSummary
                    , TextInput.placeholder "Add a title"
                    ]
                , Switch.view [ Switch.label "All day", Switch.checked editor.allDay, Switch.onCheck EditorAllDay, Switch.id "event-all-day" ]
                , if editor.allDay then
                    Layout.grid [ Layout.columns 2, Layout.gap 3 ]
                        [ DatePicker.view EditorStartDayMsg [ DatePicker.label "First day", DatePicker.today model.today ] editor.startDay
                        , DatePicker.view EditorEndDayMsg [ DatePicker.label "Last day", DatePicker.today model.today ] editor.endDay
                        ]

                  else
                    Layout.grid [ Layout.columns 2, Layout.gap 3 ]
                        [ DateTimePicker.view EditorStartMsg [ DateTimePicker.label "Starts", DateTimePicker.today model.today, DateTimePicker.step 15 ] editor.start
                        , DateTimePicker.view EditorEndMsg [ DateTimePicker.label "Ends", DateTimePicker.today model.today, DateTimePicker.step 15 ] editor.end
                        ]
                , RecurrencePicker.view EditorRepeatMsg [ RecurrencePicker.label "Repeat", RecurrencePicker.today model.today ] editor.repeat
                , Layout.grid [ Layout.columns 2, Layout.gap 3 ]
                    [ Select.view EditorCalendarMsg
                        [ Select.label "Calendar"
                        , Select.options
                            (List.map
                                (\c ->
                                    Select.option c.id c.summary
                                        |> (case Color.hex c.backgroundColor of
                                                Just color ->
                                                    Select.withColor color

                                                Nothing ->
                                                    identity
                                           )
                                )
                                writable
                            )
                        , Select.disabled editing
                        , Select.hint
                            (if editing then
                                "An event stays in its calendar."

                             else
                                ""
                            )
                        ]
                        editor.calendar
                    , Select.view EditorColorMsg
                        [ Select.label "Color"
                        , Select.options
                            (Select.option "" "Calendar color"
                                :: List.map
                                    (\c ->
                                        Select.option c.id c.name
                                            |> (case Color.hex c.hex of
                                                    Just color ->
                                                        Select.withColor color

                                                    Nothing ->
                                                        identity
                                               )
                                    )
                                    Gcal.eventColors
                            )
                        ]
                        editor.color
                    ]
                , TextInput.view [ TextInput.label "Location", TextInput.id "event-location", TextInput.value editor.location, TextInput.onInput EditorLocation, TextInput.prefixIcon Icon.mapPin ]
                , TagInput.view EditorGuestsMsg
                    [ TagInput.label "Guests"
                    , TagInput.placeholder "Email address, then Enter"
                    , TagInput.hint (guestHint model)
                    , TagInput.delimiters [ ',', ';', ' ' ]
                    , TagInput.validate
                        (\text ->
                            if String.contains "@" text && String.contains "." text then
                                Nothing

                            else
                                Just "Write an email address."
                        )
                    ]
                    editor.guests
                , TextArea.view [ TextArea.label "Description", TextArea.id "event-description", TextArea.value editor.description, TextArea.onInput EditorDescription, TextArea.rows 3 ]
                , case editor.problem of
                    Just problem ->
                        Alert.view [ Alert.tone Theme.Danger ] problem

                    Nothing ->
                        Html.text ""
                ]
            ]
        ]


guestHint : Model -> String
guestHint model =
    let
        others =
            case model.auth of
                SignedIn user ->
                    List.filter (\p -> p.email /= user.email) model.people

                _ ->
                    model.people
    in
    if List.isEmpty others then
        "Guests who have an account here see the invitation in their calendar."

    else
        "People here: " ++ String.join ", " (List.map .email (List.take 6 others)) ++ "."



-- CALENDAR SETTINGS AND SHARING


viewCalendarDialog : Model -> Overlay Msg
viewCalendarDialog model =
    let
        form =
            model.calendarForm
    in
    case form.entry of
        Nothing ->
            Modal.view CalendarModalMsg
                [ Modal.small
                , Modal.busy form.busy
                , Modal.footer [ Button.view [ Button.primary, Button.onClick SaveCalendar, Button.loading form.busy ] "Create calendar" ]
                ]
                model.calendarModal
                "New calendar"
                [ Html.form [ Attr.novalidate True, onSubmit SaveCalendar ]
                    [ Layout.stack [ Layout.gap 3 ]
                        [ TextInput.view [ TextInput.label "Name", TextInput.id "calendar-name", TextInput.value form.name, TextInput.onInput CalendarName, TextInput.required, TextInput.errorMaybe form.problem ]
                        , TextArea.view [ TextArea.label "Description", TextArea.id "calendar-description", TextArea.value form.description, TextArea.onInput CalendarDescription, TextArea.rows 2 ]
                        , Text.muted "You can share the calendar with others from its settings once it is made."
                        ]
                    ]
                ]

        Just entry ->
            let
                owner =
                    entry.accessRole == Owner
            in
            Modal.view CalendarModalMsg
                [ Modal.subtitle (roleText entry.accessRole)
                , Modal.large
                , Modal.footerStart
                    (if owner && not entry.primary then
                        [ Button.view [ Button.danger, Button.ghost, Button.icon Icon.trash, Button.onClick (AskDeleteCalendar entry), Button.id "calendar-delete" ] "Delete calendar" ]

                     else if not owner then
                        [ Button.view [ Button.ghost, Button.onClick (AskUnsubscribe entry), Button.id "calendar-unsubscribe" ] "Remove from my list" ]

                     else
                        []
                    )
                , Modal.footer
                    [ case form.export of
                        Just content ->
                            Button.view [ Button.href (Link.download { fileName = domId entry.summary ++ ".ics", mimeType = "text/calendar", content = content }), Button.icon Icon.download ] "Download .ics"

                        Nothing ->
                            if entry.accessRole == FreeBusyReader then
                                Html.text ""

                            else
                                Button.view [ Button.icon Icon.download, Button.onClick (PrepareExport entry) ] "Export"
                    ]
                ]
                model.calendarModal
                entry.summary
                [ Layout.stack [ Layout.gap 5 ]
                    [ Layout.stack [ Layout.gap 3 ]
                        (if owner then
                            [ TextInput.view [ TextInput.label "Name", TextInput.id "calendar-name", TextInput.value form.name, TextInput.onInput CalendarName, TextInput.errorMaybe form.problem ]
                            , TextArea.view [ TextArea.label "Description", TextArea.id "calendar-description", TextArea.value form.description, TextArea.onInput CalendarDescription, TextArea.rows 2 ]
                            , Layout.row [ Layout.justifyEnd ] [ Button.view [ Button.onClick SaveCalendar, Button.loading form.busy ] "Save name and description" ]
                            ]

                         else
                            [ Text.paragraph
                                (if entry.description == "" then
                                    "Shared with you."

                                 else
                                    entry.description
                                )
                            ]
                        )
                    , Select.view CalendarColorMsg
                        [ Select.label "Color"
                        , Select.hint "Only for you: everyone chooses their own colors."
                        , Select.options
                            (List.map
                                (\( id, hex, name ) ->
                                    Select.option id name
                                        |> (case Color.hex hex of
                                                Just color ->
                                                    Select.withColor color

                                                Nothing ->
                                                    identity
                                           )
                                )
                                Gcal.calendarColors
                            )
                        ]
                        form.color
                    , if owner then
                        viewSharing model entry

                      else
                        Html.text ""
                    , Text.caption ("Calendar id: " ++ entry.id)
                    ]
                ]


roleText : AccessRole -> String
roleText role =
    case role of
        Owner ->
            "You own this calendar"

        Writer ->
            "You can make changes to events"

        Reader ->
            "You can see all event details"

        FreeBusyReader ->
            "You can see only free and busy times"


roleOptions : List (SegmentedControl.Option String)
roleOptions =
    [ SegmentedControl.option "freeBusyReader" "Free/busy"
    , SegmentedControl.option "reader" "Details"
    , SegmentedControl.option "writer" "Edit"
    , SegmentedControl.option "owner" "Owner"
    ]


viewSharing : Model -> CalendarEntry -> Html Msg
viewSharing model entry =
    let
        form =
            model.calendarForm

        me =
            case model.auth of
                SignedIn user ->
                    user.email

                _ ->
                    ""

        shared =
            Remote.toMaybe form.acl |> Maybe.withDefault [] |> List.map .email

        candidates =
            model.people
                |> List.filter (\p -> p.email /= me && not (List.member p.email shared))
                |> List.map (\p -> Select.option p.email p.name |> Select.withDescription p.email)
    in
    Card.view [ Card.title "Share with people", Card.subtitle "As in Google Calendar: see only free/busy, see all details, make changes, or manage sharing." ]
        [ Layout.stack [ Layout.gap 3 ]
            (RemoteView.view [ RemoteView.onRetry (OpenCalendarSettings entry) ]
                form.acl
                (\rules ->
                    [ ListItem.list [ ListItem.ariaLabel "People with access", ListItem.bordered ]
                        (List.map
                            (\rule ->
                                let
                                    person =
                                        List.filter (\p -> p.email == rule.email) model.people |> List.head

                                    label =
                                        Maybe.map .name person |> Maybe.withDefault rule.email
                                in
                                ListItem.view
                                    [ ListItem.leading (Avatar.view [ Avatar.size Theme.Small ] label)
                                    , ListItem.secondary rule.email
                                    , ListItem.trailing
                                        (if rule.email == me then
                                            [ Badge.view [] "Owner (you)" ]

                                         else
                                            [ SegmentedControl.view
                                                [ SegmentedControl.options roleOptions
                                                , SegmentedControl.selected (Gcal.accessRoleToString rule.role)
                                                , SegmentedControl.onChange (ChangeRole rule)
                                                , SegmentedControl.label ("Access for " ++ label)
                                                , SegmentedControl.labelHidden
                                                , SegmentedControl.size Theme.Small
                                                ]
                                            , Button.iconOnly [ Button.ghost, Button.small, Button.onClick (RemoveRule rule) ] Icon.close ("Stop sharing with " ++ label)
                                            ]
                                        )
                                    ]
                                    label
                            )
                            rules
                        )
                    ]
                )
                ++ [ Layout.row [ Layout.gap 3, Layout.alignEnd, Layout.wrap ]
                        [ Html.div [ Attr.style "flex" "1 1 240px" ]
                            [ Select.view ShareWithMsg
                                [ Select.label "Add a person"
                                , Select.options candidates
                                , Select.creatable String.toLower
                                , Select.placeholder "Name or email address"
                                ]
                                form.shareWith
                            ]
                        , SegmentedControl.view
                            [ SegmentedControl.options (List.take 3 roleOptions)
                            , SegmentedControl.selected form.shareRole
                            , SegmentedControl.onChange ShareRole
                            , SegmentedControl.label "Access"
                            ]
                        , Button.view [ Button.primary, Button.icon Icon.share, Button.onClick Share, Button.loading form.busy ] "Share"
                        ]
                   , case form.problem of
                        Just problem ->
                            Alert.view [ Alert.tone Theme.Danger ] problem

                        Nothing ->
                            Html.text ""
                   ]
            )
        ]



-- CONFIRMATION


viewConfirm : Model -> Overlay Msg
viewConfirm model =
    let
        common =
            [ ConfirmDialog.onConfirm ConfirmPending, ConfirmDialog.onCancel CancelPending ]

        ( question, attributes ) =
            case model.pending of
                Just (DeleteEvent occ) ->
                    if isRecurring occ.event then
                        ( "Delete a repeating event"
                        , [ ConfirmDialog.tone Theme.Danger
                          , ConfirmDialog.confirmLabel "Delete"
                          , ConfirmDialog.body
                                [ Radio.view
                                    [ Radio.label "Which events?"
                                    , Radio.options [ Radio.option "one" ("Only " ++ Format.dateLong Locale.en occ.date), Radio.option "all" "All events in the series" ]
                                    , Radio.selected
                                        (Just
                                            (if model.deleteAll then
                                                "all"

                                             else
                                                "one"
                                            )
                                        )
                                    , Radio.onChange (\k -> SetDeleteAll (k == "all"))
                                    , Radio.id "delete-which"
                                    ]
                                ]
                          ]
                        )

                    else
                        ( "Delete the event?"
                        , [ ConfirmDialog.message ("“" ++ occ.event.summary ++ "” is deleted for everyone who sees this calendar.")
                          , ConfirmDialog.tone Theme.Danger
                          , ConfirmDialog.confirmLabel "Delete"
                          ]
                        )

                Just (DeleteCalendar entry) ->
                    ( "Delete the calendar?"
                    , [ ConfirmDialog.message ("“" ++ entry.summary ++ "” and all its events are deleted, also for the people it is shared with.")
                      , ConfirmDialog.tone Theme.Danger
                      , ConfirmDialog.confirmLabel "Delete calendar"
                      , ConfirmDialog.typeToConfirm entry.summary
                      ]
                    )

                Just (Unsubscribe entry) ->
                    ( "Remove from your list?"
                    , [ ConfirmDialog.message ("You stop seeing “" ++ entry.summary ++ "”. The owner can still share it with you again.")
                      , ConfirmDialog.confirmLabel "Remove"
                      ]
                    )

                Nothing ->
                    ( "Are you sure?", [] )
    in
    ConfirmDialog.view ConfirmMsg (common ++ attributes) model.confirm question



-- INVITATIONS


viewInvitations : Model -> Html Msg
viewInvitations model =
    let
        all =
            Remote.toMaybe model.invites |> Maybe.withDefault []

        invited =
            List.filter
                (\e ->
                    case Gcal.selfAttendee e of
                        Just a ->
                            not a.organizer

                        Nothing ->
                            False
                )
                all

        pending =
            pendingInvites model

        answered =
            List.filter (\e -> not (List.member e pending)) invited
    in
    Layout.stack [ Layout.gap 4 ]
        [ PageHeader.view
            [ PageHeader.title "Invitations"
            , PageHeader.subtitle "Events others have invited you to, from today and a year ahead."
            ]
        , Html.div []
            (RemoteView.view [ RemoteView.onRetry Reload ]
                model.invites
                (\_ ->
                    if List.isEmpty invited then
                        [ EmptyState.view
                            [ EmptyState.icon Icon.mail
                            , EmptyState.title "No invitations"
                            , EmptyState.description "When someone adds you as a guest, the event shows here and in your calendar. Invitations that come by email can be imported as .ics files."
                            , EmptyState.actions [ Button.view [ Button.href (Link.internal "#/import") ] "Import an invitation" ]
                            ]
                        ]

                    else
                        [ Layout.stack [ Layout.gap 4 ]
                            [ invitationList model "Waiting for your answer" pending
                            , invitationList model "Answered" answered
                            ]
                        ]
                )
            )
        ]


invitationList : Model -> String -> List Event -> Html Msg
invitationList model title events =
    if List.isEmpty events then
        Html.text ""

    else
        Card.view [ Card.title title, Card.flush ]
            [ ListItem.list [ ListItem.ariaLabel title ]
                (List.map
                    (\event ->
                        let
                            me =
                                Gcal.selfAttendee event |> Maybe.map .responseStatus |> Maybe.withDefault NeedsAction
                        in
                        ListItem.view
                            [ ListItem.secondary
                                (describeTime model event.start
                                    ++ (case event.organizer of
                                            Just o ->
                                                " · from " ++ nameOf o.displayName o.email

                                            Nothing ->
                                                ""
                                       )
                                )
                            , ListItem.meta event.location
                            , ListItem.trailing
                                [ SegmentedControl.view
                                    [ SegmentedControl.options
                                        [ SegmentedControl.option "accepted" "Yes"
                                        , SegmentedControl.option "tentative" "Maybe"
                                        , SegmentedControl.option "declined" "No"
                                        ]
                                    , SegmentedControl.selected
                                        (if me == NeedsAction then
                                            ""

                                         else
                                            Gcal.responseToString me
                                        )
                                    , SegmentedControl.onChange (\k -> Respond event (Gcal.responseFromString k))
                                    , SegmentedControl.label ("Going to " ++ event.summary ++ "?")
                                    , SegmentedControl.labelHidden
                                    , SegmentedControl.size Theme.Small
                                    ]
                                ]
                            ]
                            event.summary
                    )
                    events
                )
            ]


{-| A start for people. A time with an offset ("Z" from a file) is shown in the
local zone; a time in another named zone says which.
-}
describeTime : Model -> EventTime -> String
describeTime model time =
    case time of
        AllDay date ->
            Format.dateLong Locale.en date ++ ", all day"

        Timed t ->
            if t.offset == "Z" then
                let
                    posix =
                        Time.millisToPosix ((Date.toEpochDay t.date * 1440 + t.minute) * 60000)
                in
                Format.dateLong Locale.en (Date.fromPosix model.zone posix)
                    ++ " "
                    ++ Grid.clock (Time.toHour model.zone posix * 60 + Time.toMinute model.zone posix)

            else
                Format.dateLong Locale.en t.date
                    ++ " "
                    ++ Grid.clock t.minute
                    ++ (if t.offset == "" && t.timeZone /= "" && t.timeZone /= model.zoneName then
                            " (" ++ t.timeZone ++ ")"

                        else
                            ""
                       )



-- IMPORT


viewImport : Model -> Html Msg
viewImport model =
    Layout.stack [ Layout.gap 4 ]
        [ PageHeader.view
            [ PageHeader.title "Import"
            , PageHeader.subtitle "From Google Calendar, from a calendar file, or from an invitation that came by email."
            ]
        , Layout.grid [ Layout.minColumn 420, Layout.gap 4 ]
            [ viewGoogleImport model
            , viewFileImport model
            ]
        ]


viewGoogleImport : Model -> Html Msg
viewGoogleImport model =
    Card.view [ Card.title "Google Calendar", Card.subtitle "Reads your Google calendars (read only) and copies each into a new calendar here, with its repeating events." ]
        [ case model.googleToken of
            Nothing ->
                if model.googleClientId == "" then
                    Alert.viewWith [ Alert.tone Theme.Info, Alert.title "Not set up yet" ]
                        [ Text.paragraph "The server needs an OAuth client id from Google Cloud: start it with GOOGLE_CLIENT_ID set (see calendar/README.md). Until then, export the calendar from Google (Settings, Import and export) and import the .ics file here."
                        ]

                else
                    Layout.stack [ Layout.gap 3 ]
                        [ Text.paragraph "You are sent to Google to allow read access, and come back here with the list of your calendars."
                        , case Link.external (googleAuthUrl model) of
                            Just target ->
                                Button.view [ Button.primary, Button.icon Icon.calendar, Button.href target ] "Connect Google Calendar"

                            Nothing ->
                                Text.muted "The Google sign-in address could not be made."
                        ]

            Just _ ->
                Layout.stack [ Layout.gap 3 ]
                    (RemoteView.view []
                        model.googleCalendars
                        (\calendars ->
                            [ Layout.stack [ Layout.gap 2 ]
                                (List.map
                                    (\c ->
                                        Checkbox.view
                                            [ Checkbox.label c.summary
                                            , Checkbox.hint (roleText c.accessRole)
                                            , Checkbox.checked (List.member c.id model.googleChosen)
                                            , Checkbox.onCheck (ChooseGoogle c.id)
                                            , Checkbox.id ("google-" ++ domId c.id)
                                            ]
                                    )
                                    calendars
                                )
                            , Button.view
                                [ Button.primary
                                , Button.icon Icon.download
                                , Button.onClick ImportGoogle
                                , Button.disabled (List.isEmpty model.googleChosen)
                                , Button.loading (model.googleProgress == Working)
                                ]
                                (Format.plural Locale.en (List.length model.googleChosen) { one = "Import 1 calendar", other = "Import " ++ String.fromInt (List.length model.googleChosen) ++ " calendars" })
                            ]
                        )
                        ++ [ viewProgress model.googleProgress ]
                    )
        ]


googleAuthUrl : Model -> String
googleAuthUrl model =
    "https://accounts.google.com/o/oauth2/v2/auth"
        ++ Builder.toQuery
            [ Builder.string "client_id" model.googleClientId
            , Builder.string "redirect_uri" (model.origin ++ "/")
            , Builder.string "response_type" "token"
            , Builder.string "scope" "https://www.googleapis.com/auth/calendar.readonly"
            , Builder.string "include_granted_scopes" "true"
            , Builder.string "state" "import"
            ]


viewProgress : Progress -> Html Msg
viewProgress progress =
    case progress of
        Idle ->
            Html.text ""

        Working ->
            Spinner.view [ Spinner.label "Importing" ]

        Done text ->
            Alert.view [ Alert.tone Theme.Success, Alert.polite ] text

        ImportFailed text ->
            Alert.view [ Alert.tone Theme.Danger ] text


viewFileImport : Model -> Html Msg
viewFileImport model =
    Card.view [ Card.title "Calendar file or invitation", Card.subtitle "An .ics file (exported from Google Calendar, Outlook or Apple Calendar, or an invitation from an email), or a Google Calendar API events list as .json." ]
        [ Layout.stack [ Layout.gap 3 ]
            [ FileDrop.view FileDropMsg [ FileDrop.label "File", FileDrop.labelHidden, FileDrop.accept [ ".ics", ".ical", ".json", "text/calendar", "application/json" ], FileDrop.compact ] model.fileDrop
            , case model.file of
                Nothing ->
                    Html.text ""

                Just ( _, Err problem ) ->
                    Alert.view [ Alert.tone Theme.Danger, Alert.title "The file cannot be read" ] problem

                Just ( name, Ok content ) ->
                    viewFileContent model name content
            , viewProgress model.fileProgress
            , case model.reply of
                Just ( fileName, content ) ->
                    Alert.viewWith [ Alert.tone Theme.Info, Alert.title "Tell the organizer" ]
                        [ Text.paragraph "Your answer is saved here. To let the organizer know, attach this reply to an email to them."
                        , Button.view [ Button.href (Link.download { fileName = fileName, mimeType = "text/calendar", content = content }), Button.icon Icon.download ] "Download the reply (.ics)"
                        ]

                Nothing ->
                    Html.text ""
            ]
        ]


viewFileContent : Model -> String -> ImportContent -> Html Msg
viewFileContent model name content =
    case content of
        GoogleFile entry items ->
            Layout.stack [ Layout.gap 3 ]
                [ Text.paragraph (Format.plural Locale.en (List.length items) { one = "1 event", other = String.fromInt (List.length items) ++ " events" } ++ " from “" ++ entry.summary ++ "”. They go into a new calendar.")
                , Layout.row [] [ Button.view [ Button.primary, Button.onClick ImportFile, Button.loading (model.fileProgress == Working) ] "Import" ]
                ]

        IcsFile calendar ->
            if calendar.method == "REQUEST" then
                Layout.stack [ Layout.gap 3 ] (List.map (viewInvitationFile model) (List.take 3 calendar.events))

            else if calendar.method == "CANCEL" then
                Layout.stack [ Layout.gap 3 ]
                    [ Alert.view [ Alert.tone Theme.Warning, Alert.title "A cancellation" ]
                        ("The organizer cancelled " ++ String.join ", " (List.map (\e -> "“" ++ e.summary ++ "”") calendar.events) ++ ".")
                    , Layout.row [] [ Button.view [ Button.onClick ImportFile, Button.loading (model.fileProgress == Working) ] "Remove it from my calendar" ]
                    ]

            else
                let
                    writable =
                        Remote.toMaybe model.calendars |> Maybe.withDefault [] |> List.filter Gcal.canEdit
                in
                Layout.stack [ Layout.gap 3 ]
                    [ Text.paragraph
                        (Format.plural Locale.en (List.length calendar.events) { one = "1 event", other = String.fromInt (List.length calendar.events) ++ " events" }
                            ++ " in "
                            ++ (if calendar.name == "" then
                                    name

                                else
                                    "“" ++ calendar.name ++ "”"
                               )
                            ++ ". Events already imported are updated, not doubled."
                        )
                    , ListItem.list [ ListItem.ariaLabel "First events", ListItem.density Theme.Compact, ListItem.bordered ]
                        (List.map (\e -> ListItem.view [ ListItem.secondary (describeTime model e.start) ] e.summary) (List.take 5 calendar.events))
                    , Select.view FileTargetMsg
                        [ Select.label "Into"
                        , Select.options
                            (Select.option "new" "A new calendar"
                                :: List.map
                                    (\c ->
                                        Select.option
                                            (if c.primary then
                                                "primary"

                                             else
                                                c.id
                                            )
                                            c.summary
                                    )
                                    writable
                            )
                        ]
                        model.fileTarget
                    , Layout.row [] [ Button.view [ Button.primary, Button.onClick ImportFile, Button.loading (model.fileProgress == Working) ] "Import" ]
                    ]


viewInvitationFile : Model -> Event -> Html Msg
viewInvitationFile model event =
    Card.view [ Card.title event.summary, Card.subtitle (describeTime model event.start), Card.headingLevel 3, Card.sunken ]
        [ Layout.stack [ Layout.gap 2 ]
            [ case event.organizer of
                Just o ->
                    Text.secondary ("Invitation from " ++ nameOf o.displayName o.email)

                Nothing ->
                    Html.text ""
            , if event.location == "" then
                Html.text ""

              else
                Text.secondary event.location
            , if List.isEmpty event.attendees then
                Html.text ""

              else
                Text.muted ("Guests: " ++ String.join ", " (List.map (\a -> nameOf a.displayName a.email) event.attendees))
            , Layout.row [ Layout.gap 2, Layout.wrap ]
                [ Button.view [ Button.primary, Button.icon Icon.check, Button.onClick (AnswerInvitation event Accepted), Button.loading (model.fileProgress == Working) ] "Yes, add to my calendar"
                , Button.view [ Button.onClick (AnswerInvitation event Tentative) ] "Maybe"
                , Button.view [ Button.onClick (AnswerInvitation event Declined) ] "No"
                ]
            ]
        ]
