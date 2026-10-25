module Api exposing
    ( AclRule
    , GoogleImport
    , User
    , aclDelete
    , aclInsert
    , aclList
    , calendarList
    , config
    , createCalendar
    , deleteCalendar
    , deleteEvent
    , demoLogin
    , events
    , googleCalendars
    , googleEvents
    , googleImport
    , importEvent
    , insertEvent
    , login
    , logout
    , me
    , message
    , patchCalendar
    , patchEvent
    , patchListEntry
    , people
    , register
    , respond
    , unsubscribe
    )

{-| The requests of the calendar. Everything under `/calendar/v3` has the paths
and the JSON of the Google Calendar API v3, so the same requests work against
`https://www.googleapis.com` with an access token; `/auth` and `/api` are the
server's own (people, and the import of a whole Google calendar).
-}

import Gcal exposing (AccessRole, CalendarEntry, Event)
import Http
import Json.Decode as Decode exposing (Decoder)
import Json.Encode as Encode
import Klar.Date as Date exposing (Date)
import Klar.Locale as Locale
import Klar.Remote as Remote exposing (Problem)
import Task exposing (Task)
import Url
import Url.Builder as Builder


type alias User =
    { name : String
    , email : String
    }


type alias AclRule =
    { id : String
    , role : AccessRole
    , email : String
    }


type alias GoogleImport =
    { calendarId : String
    , summary : String
    , imported : Int
    , skipped : Int
    }



-- PROBLEMS


{-| A Google error (`{ "error": { "code", "message" } }`) as a `Remote.Problem`
with the message as its detail.
-}
toProblem : Int -> String -> Problem
toProblem status body =
    let
        kind =
            if status == 401 then
                Remote.unauthorized

            else if status == 403 then
                Remote.forbidden

            else if status == 404 then
                Remote.notFound

            else if status == 409 then
                Remote.conflict

            else if status >= 400 && status < 500 then
                Remote.validation

            else
                Remote.server
    in
    case Decode.decodeString (Decode.at [ "error", "message" ] Decode.string) body of
        Ok text ->
            Remote.problem kind |> Remote.withDetail text |> Remote.withCode (String.fromInt status)

        Err _ ->
            Remote.problem kind |> Remote.withCode (String.fromInt status)


{-| The text to show for a problem: the server's own message when it gave one.
-}
message : Problem -> String
message problem =
    Remote.detail Locale.en problem
        |> Maybe.withDefault (Remote.title Locale.en problem)


resolve : Decoder a -> Http.Response String -> Result Problem a
resolve decoder response =
    case response of
        Http.GoodStatus_ _ body ->
            if String.isEmpty body then
                Decode.decodeString decoder "null"
                    |> Result.mapError (\_ -> Remote.problem Remote.server |> Remote.withDetail "The answer was empty.")

            else
                Decode.decodeString decoder body
                    |> Result.mapError (\e -> Remote.problem Remote.server |> Remote.withDetail (Decode.errorToString e))

        Http.BadStatus_ meta body ->
            Err (toProblem meta.statusCode body)

        Http.NetworkError_ ->
            Err (Remote.problem Remote.network)

        Http.Timeout_ ->
            Err (Remote.problem Remote.timeout)

        Http.BadUrl_ url ->
            Err (Remote.problem Remote.unknown |> Remote.withDetail ("Bad address: " ++ url))


expect : (Result Problem a -> msg) -> Decoder a -> Http.Expect msg
expect toMsg decoder =
    Http.expectStringResponse toMsg (resolve decoder)


request : { method : String, url : String, body : Maybe Encode.Value, token : Maybe String } -> (Result Problem a -> msg) -> Decoder a -> Cmd msg
request r toMsg decoder =
    Http.request
        { method = r.method
        , headers = authorization r.token
        , url = localUrl r.url
        , body = Maybe.map Http.jsonBody r.body |> Maybe.withDefault Http.emptyBody
        , expect = expect toMsg decoder
        , timeout = Just 30000
        , tracker = Nothing
        }


task : { method : String, url : String, body : Maybe Encode.Value, token : Maybe String } -> Decoder a -> Task Problem a
task r decoder =
    Http.task
        { method = r.method
        , headers = authorization r.token
        , url = localUrl r.url
        , body = Maybe.map Http.jsonBody r.body |> Maybe.withDefault Http.emptyBody
        , resolver = Http.stringResolver (resolve decoder)
        , timeout = Just 60000
        }


{-| Resolve local API paths beside the application, so the same client works at
the standalone root and under the showcase's /calendar-app/ mount. Absolute
Google API URLs keep their origin.
-}
localUrl : String -> String
localUrl url =
    if String.startsWith "/" url then
        String.dropLeft 1 url

    else
        url


authorization : Maybe String -> List Http.Header
authorization token =
    case token of
        Just t ->
            [ Http.header "Authorization" ("Bearer " ++ t) ]

        Nothing ->
            []


get : String -> (Result Problem a -> msg) -> Decoder a -> Cmd msg
get url =
    request { method = "GET", url = url, body = Nothing, token = Nothing }


send : String -> String -> Encode.Value -> (Result Problem a -> msg) -> Decoder a -> Cmd msg
send method url body =
    request { method = method, url = url, body = Just body, token = Nothing }


remove : String -> (Result Problem () -> msg) -> Cmd msg
remove url toMsg =
    request { method = "DELETE", url = url, body = Nothing, token = Nothing } toMsg (Decode.succeed ())


{-| `/calendar/v3/calendars/<id>/...`, the id percent-encoded (Google ids hold
`@` and `#`).
-}
calendarUrl : String -> List String -> List Builder.QueryParameter -> String
calendarUrl id rest query =
    "/calendar/v3/calendars/" ++ Url.percentEncode id ++ String.concat (List.map (\p -> "/" ++ Url.percentEncode p) rest) ++ Builder.toQuery query



-- PEOPLE


userDecoder : Decoder User
userDecoder =
    Decode.map2 User (Decode.field "name" Decode.string) (Decode.field "email" Decode.string)


{-| The server's settings: the Google client id, and the demo people when it
runs with `--demo`.
-}
config : (Result Problem { googleClientId : String, demo : List User } -> msg) -> Cmd msg
config toMsg =
    get "/config.json"
        toMsg
        (Decode.map2 (\id demo -> { googleClientId = id, demo = demo })
            (Decode.field "googleClientId" Decode.string)
            (Decode.oneOf [ Decode.field "demo" (Decode.list userDecoder), Decode.succeed [] ])
        )


{-| Signs in as a demo person, without a password (only with `--demo`).
-}
demoLogin : String -> (Result Problem User -> msg) -> Cmd msg
demoLogin email toMsg =
    send "POST" "/auth/demo" (Encode.object [ ( "email", Encode.string email ) ]) toMsg userDecoder


me : (Result Problem User -> msg) -> Cmd msg
me toMsg =
    get "/auth/me" toMsg userDecoder


login : { email : String, password : String } -> (Result Problem User -> msg) -> Cmd msg
login { email, password } toMsg =
    send "POST" "/auth/login" (Encode.object [ ( "email", Encode.string email ), ( "password", Encode.string password ) ]) toMsg userDecoder


register : { name : String, email : String, password : String, timeZone : String } -> (Result Problem User -> msg) -> Cmd msg
register r toMsg =
    send "POST"
        "/auth/register"
        (Encode.object
            [ ( "name", Encode.string r.name )
            , ( "email", Encode.string r.email )
            , ( "password", Encode.string r.password )
            , ( "timeZone", Encode.string r.timeZone )
            ]
        )
        toMsg
        userDecoder


logout : (Result Problem () -> msg) -> Cmd msg
logout toMsg =
    send "POST" "/auth/logout" (Encode.object []) toMsg (Decode.succeed ())


people : (Result Problem (List User) -> msg) -> Cmd msg
people toMsg =
    get "/api/users" toMsg (Decode.field "items" (Decode.list userDecoder))



-- CALENDARS


calendarList : (Result Problem (List CalendarEntry) -> msg) -> Cmd msg
calendarList toMsg =
    get "/calendar/v3/users/me/calendarList" toMsg (Decode.field "items" (Decode.list Gcal.calendarEntryDecoder))


patchListEntry : String -> List ( String, Encode.Value ) -> (Result Problem CalendarEntry -> msg) -> Cmd msg
patchListEntry id fields toMsg =
    send "PATCH" ("/calendar/v3/users/me/calendarList/" ++ Url.percentEncode id) (Encode.object fields) toMsg Gcal.calendarEntryDecoder


unsubscribe : String -> (Result Problem () -> msg) -> Cmd msg
unsubscribe id =
    remove ("/calendar/v3/users/me/calendarList/" ++ Url.percentEncode id)


createCalendar : { summary : String, description : String, timeZone : String } -> (Result Problem String -> msg) -> Cmd msg
createCalendar r toMsg =
    send "POST"
        "/calendar/v3/calendars"
        (Encode.object
            [ ( "summary", Encode.string r.summary )
            , ( "description", Encode.string r.description )
            , ( "timeZone", Encode.string r.timeZone )
            ]
        )
        toMsg
        (Decode.field "id" Decode.string)


patchCalendar : String -> { summary : String, description : String } -> (Result Problem () -> msg) -> Cmd msg
patchCalendar id r toMsg =
    send "PATCH"
        (calendarUrl id [] [])
        (Encode.object [ ( "summary", Encode.string r.summary ), ( "description", Encode.string r.description ) ])
        toMsg
        (Decode.succeed ())


deleteCalendar : String -> (Result Problem () -> msg) -> Cmd msg
deleteCalendar id =
    remove (calendarUrl id [] [])



-- SHARING


aclDecoder : Decoder AclRule
aclDecoder =
    Decode.map3 AclRule
        (Decode.field "id" Decode.string)
        (Decode.field "role" (Decode.map Gcal.accessRoleFromString Decode.string))
        (Decode.oneOf [ Decode.at [ "scope", "value" ] Decode.string, Decode.succeed "" ])


aclList : String -> (Result Problem (List AclRule) -> msg) -> Cmd msg
aclList id toMsg =
    get (calendarUrl id [ "acl" ] []) toMsg (Decode.field "items" (Decode.list aclDecoder))


aclInsert : String -> { email : String, role : AccessRole } -> (Result Problem AclRule -> msg) -> Cmd msg
aclInsert id { email, role } toMsg =
    send "POST"
        (calendarUrl id [ "acl" ] [])
        (Encode.object
            [ ( "role", Encode.string (Gcal.accessRoleToString role) )
            , ( "scope", Encode.object [ ( "type", Encode.string "user" ), ( "value", Encode.string email ) ] )
            ]
        )
        toMsg
        aclDecoder


aclDelete : String -> String -> (Result Problem () -> msg) -> Cmd msg
aclDelete id ruleId =
    remove (calendarUrl id [ "acl", ruleId ] [])



-- EVENTS


{-| The events of a calendar that touch the period, recurring events as their
series (`singleEvents=false`), the times written in `zone`.
-}
events : { calendarId : String, from : Date, to : Date, zone : String } -> (Result Problem (List Event) -> msg) -> Cmd msg
events r toMsg =
    get
        (calendarUrl r.calendarId
            [ "events" ]
            [ Builder.string "timeMin" (Date.toIso (Date.addDays -1 r.from) ++ "T00:00:00Z")
            , Builder.string "timeMax" (Date.toIso (Date.addDays 1 r.to) ++ "T00:00:00Z")
            , Builder.string "timeZone" r.zone
            , Builder.string "singleEvents" "false"
            , Builder.string "maxResults" "2500"
            ]
        )
        toMsg
        (Decode.field "items" (Decode.list Gcal.eventDecoder))


insertEvent : String -> String -> Event -> (Result Problem Event -> msg) -> Cmd msg
insertEvent calendarId zone event toMsg =
    send "POST" (calendarUrl calendarId [ "events" ] [ Builder.string "timeZone" zone ]) (Gcal.encodeEvent event) toMsg Gcal.eventDecoder


patchEvent : String -> String -> String -> Encode.Value -> (Result Problem Event -> msg) -> Cmd msg
patchEvent calendarId eventId zone body toMsg =
    send "PATCH" (calendarUrl calendarId [ "events", eventId ] [ Builder.string "timeZone" zone ]) body toMsg Gcal.eventDecoder


{-| A guest's answer to an invitation: only their own `responseStatus`.
-}
respond : String -> Event -> String -> Gcal.ResponseStatus -> (Result Problem Event -> msg) -> Cmd msg
respond calendarId event email status =
    patchEvent calendarId
        event.id
        ""
        (Encode.object
            [ ( "attendees"
              , Encode.list identity
                    [ Encode.object
                        [ ( "email", Encode.string email )
                        , ( "responseStatus", Encode.string (Gcal.responseToString status) )
                        ]
                    ]
              )
            ]
        )


deleteEvent : String -> String -> (Result Problem () -> msg) -> Cmd msg
deleteEvent calendarId eventId =
    remove (calendarUrl calendarId [ "events", eventId ] [])


{-| `events.import`: adds the event, or updates the one with the same `iCalUID`.
-}
importEvent : String -> Event -> Task Problem ()
importEvent calendarId event =
    task { method = "POST", url = calendarUrl calendarId [ "events", "import" ] [], body = Just (Gcal.encodeEvent event), token = Nothing }
        (Decode.succeed ())



-- GOOGLE


googleBase : String
googleBase =
    "https://www.googleapis.com/calendar/v3"


{-| The calendars of the signed-in Google account.
-}
googleCalendars : String -> (Result Problem (List CalendarEntry) -> msg) -> Cmd msg
googleCalendars token toMsg =
    request { method = "GET", url = googleBase ++ "/users/me/calendarList?maxResults=250", body = Nothing, token = Just token }
        toMsg
        (Decode.field "items" (Decode.list Gcal.calendarEntryDecoder))


{-| Every event of a Google calendar as Google wrote it (all pages, recurring
events as series and their changed instances).
-}
googleEvents : String -> String -> Task Problem (List Encode.Value)
googleEvents token calendarId =
    let
        page pageToken collected =
            task
                { method = "GET"
                , url =
                    googleBase
                        ++ "/calendars/"
                        ++ Url.percentEncode calendarId
                        ++ "/events"
                        ++ Builder.toQuery
                            (Builder.string "maxResults" "2500"
                                :: Builder.string "singleEvents" "false"
                                :: (case pageToken of
                                        Just t ->
                                            [ Builder.string "pageToken" t ]

                                        Nothing ->
                                            []
                                   )
                            )
                , body = Nothing
                , token = Just token
                }
                (Decode.map2 Tuple.pair
                    (Decode.field "items" (Decode.list Decode.value))
                    (Decode.maybe (Decode.field "nextPageToken" Decode.string))
                )
                |> Task.andThen
                    (\( items, next ) ->
                        case next of
                            Just t ->
                                page (Just t) (collected ++ items)

                            Nothing ->
                                Task.succeed (collected ++ items)
                    )
    in
    page Nothing []


{-| Sends the events of a Google calendar to the server, which makes a new
calendar of them.
-}
googleImport : CalendarEntry -> List Encode.Value -> Task Problem GoogleImport
googleImport source items =
    task
        { method = "POST"
        , url = "/api/import/google"
        , body =
            Just
                (Encode.object
                    [ ( "calendar"
                      , Encode.object
                            [ ( "summary", Encode.string source.summary )
                            , ( "description", Encode.string source.description )
                            , ( "timeZone", Encode.string source.timeZone )
                            , ( "backgroundColor", Encode.string source.backgroundColor )
                            , ( "foregroundColor", Encode.string source.foregroundColor )
                            ]
                      )
                    , ( "items", Encode.list identity items )
                    ]
                )
        , token = Nothing
        }
        (Decode.map4 GoogleImport
            (Decode.field "calendarId" Decode.string)
            (Decode.field "summary" Decode.string)
            (Decode.field "imported" Decode.int)
            (Decode.field "skipped" Decode.int)
        )
