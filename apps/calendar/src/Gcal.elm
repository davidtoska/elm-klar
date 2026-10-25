module Gcal exposing
    ( AccessRole(..)
    , Attendee
    , CalendarEntry
    , Event
    , EventTime(..)
    , Person
    , ResponseStatus(..)
    , accessRoleFromString
    , accessRoleToString
    , calendarColors
    , calendarEntryDecoder
    , canEdit
    , emptyEvent
    , encodeEvent
    , encodeEventTime
    , eventColors
    , eventDecoder
    , eventTimeDecoder
    , parseDateTime
    , responseFromString
    , responseToString
    , selfAttendee
    )

{-| The resources of the Google Calendar API v3 that this calendar reads and
writes: a calendar list entry, an event with its times, guests and recurrence.
The server of this application speaks the same JSON, so the decoders read both.
-}

import Json.Decode as Decode exposing (Decoder)
import Json.Encode as Encode
import Klar.Date as Date exposing (Date)


type AccessRole
    = FreeBusyReader
    | Reader
    | Writer
    | Owner


type alias CalendarEntry =
    { id : String
    , summary : String
    , description : String
    , timeZone : String
    , backgroundColor : String
    , foregroundColor : String
    , accessRole : AccessRole
    , primary : Bool
    , selected : Bool
    }


{-| A start or an end. `AllDay` is a `date`; `Timed` is a `dateTime` read as the
wall clock it shows (the server writes it in the zone that was asked for), with
the offset it had ("Z", "+02:00", or "" when there was none) and its `timeZone`.
-}
type EventTime
    = AllDay Date
    | Timed { date : Date, minute : Int, offset : String, timeZone : String }


type ResponseStatus
    = NeedsAction
    | Accepted
    | Tentative
    | Declined


type alias Person =
    { email : String
    , displayName : String
    , self : Bool
    }


type alias Attendee =
    { email : String
    , displayName : String
    , self : Bool
    , organizer : Bool
    , optional : Bool
    , responseStatus : ResponseStatus
    }


type alias Event =
    { id : String
    , iCalUID : String
    , status : String
    , summary : String
    , description : String
    , location : String
    , start : EventTime
    , end : EventTime
    , recurrence : List String
    , attendees : List Attendee
    , organizer : Maybe Person
    , colorId : String
    , transparency : String
    }


emptyEvent : EventTime -> EventTime -> Event
emptyEvent start end =
    { id = ""
    , iCalUID = ""
    , status = "confirmed"
    , summary = ""
    , description = ""
    , location = ""
    , start = start
    , end = end
    , recurrence = []
    , attendees = []
    , organizer = Nothing
    , colorId = ""
    , transparency = ""
    }


canEdit : CalendarEntry -> Bool
canEdit entry =
    entry.accessRole == Writer || entry.accessRole == Owner


selfAttendee : Event -> Maybe Attendee
selfAttendee event =
    List.filter .self event.attendees |> List.head



-- DECODERS


optional : String -> Decoder a -> a -> Decoder a
optional name decoder default =
    Decode.maybe (Decode.field name decoder)
        |> Decode.map (Maybe.withDefault default)


calendarEntryDecoder : Decoder CalendarEntry
calendarEntryDecoder =
    Decode.map8
        (\id summary description timeZone background foreground role ( primary, selected ) ->
            { id = id
            , summary = summary
            , description = description
            , timeZone = timeZone
            , backgroundColor = background
            , foregroundColor = foreground
            , accessRole = role
            , primary = primary
            , selected = selected
            }
        )
        (Decode.field "id" Decode.string)
        (Decode.oneOf [ Decode.field "summaryOverride" Decode.string, optional "summary" Decode.string "" ])
        (optional "description" Decode.string "")
        (optional "timeZone" Decode.string "UTC")
        (optional "backgroundColor" Decode.string "#4986e7")
        (optional "foregroundColor" Decode.string "#000000")
        (optional "accessRole" (Decode.map accessRoleFromString Decode.string) Reader)
        (Decode.map2 Tuple.pair
            (optional "primary" Decode.bool False)
            (optional "selected" Decode.bool False)
        )


accessRoleFromString : String -> AccessRole
accessRoleFromString text =
    case text of
        "owner" ->
            Owner

        "writer" ->
            Writer

        "freeBusyReader" ->
            FreeBusyReader

        _ ->
            Reader


accessRoleToString : AccessRole -> String
accessRoleToString role =
    case role of
        Owner ->
            "owner"

        Writer ->
            "writer"

        Reader ->
            "reader"

        FreeBusyReader ->
            "freeBusyReader"


responseFromString : String -> ResponseStatus
responseFromString text =
    case text of
        "accepted" ->
            Accepted

        "tentative" ->
            Tentative

        "declined" ->
            Declined

        _ ->
            NeedsAction


responseToString : ResponseStatus -> String
responseToString status =
    case status of
        Accepted ->
            "accepted"

        Tentative ->
            "tentative"

        Declined ->
            "declined"

        NeedsAction ->
            "needsAction"


eventDecoder : Decoder Event
eventDecoder =
    Decode.map8
        (\id iCalUID status summary description location ( start, end ) rest ->
            { id = id
            , iCalUID = iCalUID
            , status = status
            , summary = summary
            , description = description
            , location = location
            , start = start
            , end = end
            , recurrence = rest.recurrence
            , attendees = rest.attendees
            , organizer = rest.organizer
            , colorId = rest.colorId
            , transparency = rest.transparency
            }
        )
        (optional "id" Decode.string "")
        (optional "iCalUID" Decode.string "")
        (optional "status" Decode.string "confirmed")
        (optional "summary" Decode.string "")
        (optional "description" Decode.string "")
        (optional "location" Decode.string "")
        (Decode.map2 Tuple.pair
            (Decode.field "start" eventTimeDecoder)
            (Decode.field "end" eventTimeDecoder)
        )
        (Decode.map5
            (\recurrence attendees organizer colorId transparency ->
                { recurrence = recurrence
                , attendees = attendees
                , organizer = organizer
                , colorId = colorId
                , transparency = transparency
                }
            )
            (optional "recurrence" (Decode.list Decode.string) [])
            (optional "attendees" (Decode.list attendeeDecoder) [])
            (Decode.maybe (Decode.field "organizer" personDecoder))
            (optional "colorId" Decode.string "")
            (optional "transparency" Decode.string "")
        )


personDecoder : Decoder Person
personDecoder =
    Decode.map3 Person
        (optional "email" Decode.string "")
        (optional "displayName" Decode.string "")
        (optional "self" Decode.bool False)


attendeeDecoder : Decoder Attendee
attendeeDecoder =
    Decode.map6 Attendee
        (optional "email" Decode.string "")
        (optional "displayName" Decode.string "")
        (optional "self" Decode.bool False)
        (optional "organizer" Decode.bool False)
        (optional "optional" Decode.bool False)
        (optional "responseStatus" (Decode.map responseFromString Decode.string) NeedsAction)


eventTimeDecoder : Decoder EventTime
eventTimeDecoder =
    Decode.oneOf
        [ Decode.field "date" Decode.string
            |> Decode.andThen
                (\text ->
                    case Date.fromIso text of
                        Just date ->
                            Decode.succeed (AllDay date)

                        Nothing ->
                            Decode.fail ("Not a date: " ++ text)
                )
        , Decode.map2 Tuple.pair
            (Decode.field "dateTime" Decode.string)
            (optional "timeZone" Decode.string "")
            |> Decode.andThen
                (\( text, zone ) ->
                    case parseDateTime text of
                        Just t ->
                            Decode.succeed (Timed { t | timeZone = zone })

                        Nothing ->
                            Decode.fail ("Not a dateTime: " ++ text)
                )
        ]


{-| Reads an RFC 3339 date-time as its wall clock: `2026-10-24T10:00:00+02:00`
is 24 October at 600 minutes, offset "+02:00".
-}
parseDateTime : String -> Maybe { date : Date, minute : Int, offset : String, timeZone : String }
parseDateTime text =
    let
        datePart =
            String.left 10 text

        rest =
            String.dropLeft 11 text

        hour =
            String.toInt (String.left 2 rest)

        minute =
            String.toInt (String.slice 3 5 rest)

        afterMinutes =
            String.dropLeft 5 rest

        withoutSeconds =
            if String.startsWith ":" afterMinutes then
                String.dropLeft 3 afterMinutes
                    |> dropFraction

            else
                afterMinutes
    in
    case ( Date.fromIso datePart, hour, minute ) of
        ( Just date, Just h, Just m ) ->
            if String.slice 10 11 text == "T" && h >= 0 && h < 24 && m >= 0 && m < 60 && validOffset withoutSeconds then
                Just { date = date, minute = h * 60 + m, offset = withoutSeconds, timeZone = "" }

            else
                Nothing

        _ ->
            Nothing


dropFraction : String -> String
dropFraction text =
    if String.startsWith "." text then
        String.dropLeft 1 text
            |> String.toList
            |> dropWhile Char.isDigit
            |> String.fromList

    else
        text


dropWhile : (a -> Bool) -> List a -> List a
dropWhile keep list =
    case list of
        first :: others ->
            if keep first then
                dropWhile keep others

            else
                list

        [] ->
            []


validOffset : String -> Bool
validOffset offset =
    offset == "" || offset == "Z" || (String.length offset == 6 && (String.startsWith "+" offset || String.startsWith "-" offset))



-- ENCODERS


encodeEventTime : EventTime -> Encode.Value
encodeEventTime time =
    case time of
        AllDay date ->
            Encode.object [ ( "date", Encode.string (Date.toIso date) ) ]

        Timed t ->
            Encode.object
                (( "dateTime", Encode.string (Date.toIso t.date ++ "T" ++ clock t.minute ++ ":00" ++ t.offset) )
                    :: (if t.timeZone == "" then
                            []

                        else
                            [ ( "timeZone", Encode.string t.timeZone ) ]
                       )
                )


clock : Int -> String
clock minutes =
    pad2 (minutes // 60) ++ ":" ++ pad2 (modBy 60 minutes)


pad2 : Int -> String
pad2 n =
    String.padLeft 2 '0' (String.fromInt n)


{-| The fields of an event for an insert, an update or an import. Empty texts
and lists are left out, except the ones an update must be able to clear.
-}
encodeEvent : Event -> Encode.Value
encodeEvent event =
    let
        text name value =
            [ ( name, Encode.string value ) ]

        ifSet name value =
            if value == "" then
                []

            else
                text name value
    in
    Encode.object
        (List.concat
            [ text "summary" event.summary
            , text "description" event.description
            , text "location" event.location
            , [ ( "start", encodeEventTime event.start )
              , ( "end", encodeEventTime event.end )
              , ( "recurrence", Encode.list Encode.string event.recurrence )
              , ( "attendees", Encode.list encodeAttendee event.attendees )
              ]
            , ifSet "status" event.status
            , ifSet "iCalUID" event.iCalUID
            , ifSet "colorId" event.colorId
            , ifSet "transparency" event.transparency
            , case event.organizer of
                Just person ->
                    [ ( "organizer"
                      , Encode.object
                            (( "email", Encode.string person.email )
                                :: ifSet "displayName" person.displayName
                            )
                      )
                    ]

                Nothing ->
                    []
            ]
        )


encodeAttendee : Attendee -> Encode.Value
encodeAttendee attendee =
    Encode.object
        (List.concat
            [ [ ( "email", Encode.string attendee.email ) ]
            , if attendee.displayName == "" then
                []

              else
                [ ( "displayName", Encode.string attendee.displayName ) ]
            , [ ( "responseStatus", Encode.string (responseToString attendee.responseStatus) ) ]
            , if attendee.optional then
                [ ( "optional", Encode.bool True ) ]

              else
                []
            , if attendee.organizer then
                [ ( "organizer", Encode.bool True ) ]

              else
                []
            ]
        )



-- COLORS


{-| The calendar colors of Google Calendar, `colorId` "1" to "24", with names.
-}
calendarColors : List ( String, String, String )
calendarColors =
    List.indexedMap (\i ( hex, name ) -> ( String.fromInt (i + 1), hex, name ))
        [ ( "#ac725e", "Cocoa" )
        , ( "#d06b64", "Flamingo" )
        , ( "#f83a22", "Tomato" )
        , ( "#fa573c", "Tangerine" )
        , ( "#ff7537", "Pumpkin" )
        , ( "#ffad46", "Mango" )
        , ( "#42d692", "Eucalyptus" )
        , ( "#16a765", "Basil" )
        , ( "#7bd148", "Pistachio" )
        , ( "#b3dc6c", "Avocado" )
        , ( "#fbe983", "Citron" )
        , ( "#fad165", "Banana" )
        , ( "#92e1c0", "Sage" )
        , ( "#9fe1e7", "Peacock" )
        , ( "#9fc6e7", "Cobalt" )
        , ( "#4986e7", "Blueberry" )
        , ( "#9a9cff", "Lavender" )
        , ( "#b99aff", "Wisteria" )
        , ( "#c2c2c2", "Graphite" )
        , ( "#cabdbf", "Birch" )
        , ( "#cca6ac", "Radicchio" )
        , ( "#f691b2", "Cherry blossom" )
        , ( "#cd74e6", "Grape" )
        , ( "#a47ae2", "Amethyst" )
        ]


{-| The event colors of Google Calendar, `colorId` "1" to "11", with their names.
-}
eventColors : List { id : String, name : String, hex : String }
eventColors =
    [ { id = "1", name = "Lavender", hex = "#a4bdfc" }
    , { id = "2", name = "Sage", hex = "#7ae7bf" }
    , { id = "3", name = "Grape", hex = "#dbadff" }
    , { id = "4", name = "Flamingo", hex = "#ff887c" }
    , { id = "5", name = "Banana", hex = "#fbd75b" }
    , { id = "6", name = "Tangerine", hex = "#ffb878" }
    , { id = "7", name = "Peacock", hex = "#46d6db" }
    , { id = "8", name = "Graphite", hex = "#e1e1e1" }
    , { id = "9", name = "Blueberry", hex = "#5484ed" }
    , { id = "10", name = "Basil", hex = "#51b749" }
    , { id = "11", name = "Tomato", hex = "#dc2127" }
    ]
