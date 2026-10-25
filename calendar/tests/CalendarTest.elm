module CalendarTest exposing (suite)

import Expect
import Gcal exposing (EventTime(..), ResponseStatus(..))
import Ics
import Json.Decode as Decode
import Klar.Date as Date exposing (Date)
import Occurrence
import Test exposing (Test, describe, test)
import Time


date : Int -> Int -> Int -> Date
date y m d =
    Date.fromParts y m d |> Maybe.withDefault (Date.fromEpochDay 0)


crlf : List String -> String
crlf lines =
    String.join "\u{000D}\n" lines


invitation : String
invitation =
    crlf
        [ "BEGIN:VCALENDAR"
        , "PRODID:-//Google Inc//Google Calendar 70.9054//EN"
        , "VERSION:2.0"
        , "METHOD:REQUEST"
        , "BEGIN:VTIMEZONE"
        , "TZID:Europe/Oslo"
        , "BEGIN:STANDARD"
        , "DTSTART:19701025T030000"
        , "TZOFFSETTO:+0100"
        , "END:STANDARD"
        , "END:VTIMEZONE"
        , "BEGIN:VEVENT"
        , "DTSTART;TZID=Europe/Oslo:20261105T100000"
        , "DTEND;TZID=Europe/Oslo:20261105T113000"
        , "ORGANIZER;CN=Nora Fjeld:mailto:nora@fjordfoods.example"
        , "UID:7kukuqrfedlm2f9t3vbie@google.com"
        , "ATTENDEE;ROLE=REQ-PARTICIPANT;PARTSTAT=ACCEPTED;CN=Nora F"
        , " jeld:mailto:nora@fjordfoods.example"
        , "ATTENDEE;ROLE=REQ-PARTICIPANT;PARTSTAT=NEEDS-ACTION;RSVP=TRUE:mailto:ADA@example.com"
        , "ATTENDEE;ROLE=OPT-PARTICIPANT;PARTSTAT=TENTATIVE;CN=\"Berg, Cleo\":mailto:cleo@example.com"
        , "DESCRIPTION:Agenda:\\n1. Deliveries\\, prices"
        , "LOCATION:Fjord Foods\\, Bergen"
        , "SUMMARY:Supplier meeting"
        , "BEGIN:VALARM"
        , "DESCRIPTION:This is an event reminder"
        , "TRIGGER:-P0DT0H30M0S"
        , "END:VALARM"
        , "END:VEVENT"
        , "END:VCALENDAR"
        ]


export : String
export =
    crlf
        [ "BEGIN:VCALENDAR"
        , "METHOD:PUBLISH"
        , "X-WR-CALNAME:Deliveries"
        , "X-WR-TIMEZONE:Europe/Oslo"
        , "BEGIN:VEVENT"
        , "DTSTART;VALUE=DATE:20261102"
        , "UID:allday-1@google.com"
        , "SUMMARY:Warehouse closed"
        , "END:VEVENT"
        , "BEGIN:VEVENT"
        , "DTSTART:20261103T070000Z"
        , "DURATION:PT1H30M"
        , "UID:truck@google.com"
        , "RRULE:FREQ=WEEKLY;WKST=MO;UNTIL=20261231T225959Z;BYDAY=TU,TH"
        , "EXDATE;TZID=Europe/Oslo:20261105T080000"
        , "SUMMARY:Truck"
        , "END:VEVENT"
        , "BEGIN:VEVENT"
        , "DTSTART;TZID=Europe/Oslo:20261110T090000"
        , "DTEND;TZID=Europe/Oslo:20261110T100000"
        , "UID:truck@google.com"
        , "RECURRENCE-ID:20261110T070000Z"
        , "SUMMARY:Truck (late)"
        , "END:VEVENT"
        , "END:VCALENDAR"
        ]


calendar : Gcal.CalendarEntry
calendar =
    { id = "c"
    , summary = "C"
    , description = ""
    , timeZone = "Europe/Oslo"
    , backgroundColor = "#4986e7"
    , foregroundColor = "#000000"
    , accessRole = Gcal.Owner
    , primary = True
    , selected = True
    }


timed : Date -> Int -> EventTime
timed d minute =
    Timed { date = d, minute = minute, offset = "+01:00", timeZone = "" }


suite : Test
suite =
    describe "The calendar"
        [ describe "Ics.parse, an invitation"
            [ test "reads the method, the times in their zone and the guests" <|
                \_ ->
                    case Ics.parse invitation of
                        Ok cal ->
                            case cal.events of
                                [ e ] ->
                                    Expect.equal
                                        { method = cal.method
                                        , start = e.start
                                        , end = e.end
                                        , uid = e.iCalUID
                                        , organizer = Maybe.map .email e.organizer
                                        , guests = List.map (\a -> ( a.email, a.displayName, a.responseStatus )) e.attendees
                                        , optional = List.map .optional e.attendees
                                        , description = e.description
                                        , location = e.location
                                        }
                                        { method = "REQUEST"
                                        , start = Timed { date = date 2026 11 5, minute = 600, offset = "", timeZone = "Europe/Oslo" }
                                        , end = Timed { date = date 2026 11 5, minute = 690, offset = "", timeZone = "Europe/Oslo" }
                                        , uid = "7kukuqrfedlm2f9t3vbie@google.com"
                                        , organizer = Just "nora@fjordfoods.example"
                                        , guests =
                                            [ ( "nora@fjordfoods.example", "Nora Fjeld", Accepted )
                                            , ( "ada@example.com", "", NeedsAction )
                                            , ( "cleo@example.com", "Berg, Cleo", Tentative )
                                            ]
                                        , optional = [ False, False, True ]
                                        , description = "Agenda:\n1. Deliveries, prices"
                                        , location = "Fjord Foods, Bergen"
                                        }

                                _ ->
                                    Expect.fail "expected one event"

                        Err problem ->
                            Expect.fail problem
            , test "a reply carries the answer and the method" <|
                \_ ->
                    case Ics.parse invitation |> Result.map .events of
                        Ok [ e ] ->
                            let
                                text =
                                    Ics.reply { zoneName = "Europe/Oslo", now = Time.millisToPosix 0, email = "ada@example.com", name = "Ada", status = Accepted } e
                            in
                            Expect.all
                                [ \t -> Expect.equal True (String.contains "METHOD:REPLY" t)
                                , \t -> Expect.equal True (String.contains "ATTENDEE;PARTSTAT=ACCEPTED;CN=Ada:mailto:ada@example.com" t)
                                , \t -> Expect.equal True (String.contains "DTSTART;TZID=Europe/Oslo:20261105T100000" t)
                                , \t -> Expect.equal [] (List.filter (\line -> String.length line > 75) (String.split "\u{000D}\n" t))
                                ]
                                text

                        _ ->
                            Expect.fail "expected one event"
            , test "a file without a calendar is refused" <|
                \_ ->
                    Ics.parse "hello" |> Result.toMaybe |> Expect.equal Nothing
            ]
        , describe "Ics.parse, an export"
            [ test "an all-day event without an end lasts a day, a duration gives the end" <|
                \_ ->
                    case Ics.parse export |> Result.map .events of
                        Ok (allDay :: truck :: _) ->
                            Expect.equal
                                ( ( allDay.start, allDay.end ), ( truck.start, truck.end ) )
                                ( ( AllDay (date 2026 11 2), AllDay (date 2026 11 3) )
                                , ( Timed { date = date 2026 11 3, minute = 420, offset = "Z", timeZone = "" }
                                  , Timed { date = date 2026 11 3, minute = 510, offset = "Z", timeZone = "" }
                                  )
                                )

                        _ ->
                            Expect.fail "expected events"
            , test "a changed instance becomes an EXDATE on the series and an event of its own" <|
                \_ ->
                    case Ics.parse export |> Result.map .events of
                        Ok [ _, truck, late ] ->
                            Expect.equal
                                ( truck.recurrence, late.iCalUID, late.recurrence )
                                ( [ "RRULE:FREQ=WEEKLY;WKST=MO;UNTIL=20261231T225959Z;BYDAY=TU,TH"
                                  , "EXDATE;TZID=Europe/Oslo:20261105T080000"
                                  , "EXDATE:20261110T070000Z"
                                  ]
                                , "truck@google.com-20261110T070000Z"
                                , []
                                )

                        Ok events ->
                            Expect.fail ("expected three events, got " ++ String.fromInt (List.length events))

                        Err problem ->
                            Expect.fail problem
            , test "the series has its dates without the skipped ones" <|
                \_ ->
                    case Ics.parse export |> Result.map .events of
                        Ok [ _, truck, _ ] ->
                            Occurrence.expand { from = date 2026 11 1, to = date 2026 11 20 } calendar truck
                                |> List.map (.date >> Date.toIso)
                                |> Expect.equal [ "2026-11-03", "2026-11-12", "2026-11-17", "2026-11-19" ]

                        _ ->
                            Expect.fail "expected three events"
            ]
        , describe "Occurrence"
            [ test "a multi-day event touches every day it covers" <|
                \_ ->
                    let
                        event =
                            Gcal.emptyEvent (timed (date 2026 11 2) (22 * 60)) (timed (date 2026 11 3) 120)
                    in
                    Occurrence.expand { from = date 2026 11 3, to = date 2026 11 4 } calendar { event | id = "x" }
                        |> List.length
                        |> Expect.equal 1
            , test "overlapping events share the width, the others do not" <|
                \_ ->
                    let
                        occ id from to =
                            Occurrence.expand { from = date 2026 11 2, to = date 2026 11 3 }
                                calendar
                                (let
                                    e =
                                        Gcal.emptyEvent (timed (date 2026 11 2) from) (timed (date 2026 11 2) to)
                                 in
                                 { e | id = id }
                                )

                        placed =
                            Occurrence.layoutDay 20 (date 2026 11 2) (occ "a" 540 600 ++ occ "b" 570 660 ++ occ "c" 700 720)
                    in
                    placed
                        |> List.map (\p -> ( p.occurrence.event.id, p.column, p.columns ))
                        |> Expect.equal [ ( "a", 0, 2 ), ( "b", 1, 2 ), ( "c", 0, 1 ) ]
            , test "EXDATE dates are read in any of their forms" <|
                \_ ->
                    let
                        e =
                            Gcal.emptyEvent (AllDay (date 2026 1 1)) (AllDay (date 2026 1 2))
                    in
                    Occurrence.exdates { e | recurrence = [ "RRULE:FREQ=DAILY", "EXDATE;VALUE=DATE:20260103,20260105", "EXDATE:20260107T090000Z" ] }
                        |> List.map Date.toIso
                        |> Expect.equal [ "2026-01-03", "2026-01-05", "2026-01-07" ]
            ]
        , describe "Gcal"
            [ test "a dateTime is read as its wall clock" <|
                \_ ->
                    Decode.decodeString Gcal.eventTimeDecoder "{\"dateTime\":\"2026-10-25T10:15:00.000+01:00\",\"timeZone\":\"Europe/Oslo\"}"
                        |> Expect.equal (Ok (Timed { date = date 2026 10 25, minute = 615, offset = "+01:00", timeZone = "Europe/Oslo" }))
            , test "an event from the Google API decodes" <|
                \_ ->
                    Decode.decodeString Gcal.eventDecoder
                        """{"kind":"calendar#event","id":"abc","status":"confirmed","summary":"Lunch","start":{"date":"2026-10-25"},"end":{"date":"2026-10-26"},"attendees":[{"email":"a@b.c","self":true,"responseStatus":"tentative"}],"recurrence":["RRULE:FREQ=YEARLY"]}"""
                        |> Result.map (\e -> ( e.summary, Gcal.selfAttendee e |> Maybe.map .responseStatus, e.recurrence ))
                        |> Expect.equal (Ok ( "Lunch", Just Tentative, [ "RRULE:FREQ=YEARLY" ] ))
            ]
        ]
