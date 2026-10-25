module Ics exposing
    ( Calendar
    , export
    , parse
    , reply
    )

{-| iCalendar (RFC 5545) files: the `.ics` that Google Calendar exports and the
invitations that come by email (`METHOD:REQUEST`, `METHOD:CANCEL`). `parse`
reads one into Google Calendar events; `reply` writes the answer to an
invitation and `export` a whole calendar.

Time zones are kept by name (`TZID`): the server turns a wall clock and a zone
name into a moment, so the `VTIMEZONE` blocks are not read.

-}

import Gcal exposing (Attendee, Event, EventTime(..), ResponseStatus(..))
import Klar.Date as Date exposing (Date)
import Time


type alias Calendar =
    { method : String
    , name : String
    , timeZone : String
    , events : List Event
    }


type alias Line =
    { name : String
    , params : List ( String, String )
    , value : String
    }



-- READING


parse : String -> Result String Calendar
parse source =
    let
        lines =
            source
                |> String.replace "\u{000D}\n" "\n"
                |> String.replace "\u{000D}" "\n"
                |> String.split "\n"
                |> unfold
                |> List.filterMap parseLine

        walked =
            List.foldl walk { stack = [], calendar = [], events = [], current = [] } lines

        prop name =
            List.filter (\l -> l.name == name) walked.calendar
                |> List.head
                |> Maybe.map (.value >> unescape)
                |> Maybe.withDefault ""

        method =
            String.toUpper (prop "METHOD")

        zone =
            prop "X-WR-TIMEZONE"
    in
    if not (List.any (\l -> l.name == "BEGIN" && String.toUpper l.value == "VCALENDAR") lines) then
        Err "This is not a calendar file: it has no BEGIN:VCALENDAR."

    else
        let
            events =
                List.reverse walked.events
                    |> List.filterMap (toEvent zone)
                    |> mergeOverrides
                    |> List.map
                        (\e ->
                            if method == "CANCEL" then
                                { e | status = "cancelled" }

                            else
                                e
                        )
        in
        if List.isEmpty events then
            Err "The file has no events."

        else
            Ok { method = method, name = prop "X-WR-CALNAME", timeZone = zone, events = events }


unfold : List String -> List String
unfold lines =
    List.foldl
        (\line acc ->
            case acc of
                previous :: rest ->
                    if String.startsWith " " line || String.startsWith "\t" line then
                        (previous ++ String.dropLeft 1 line) :: rest

                    else
                        line :: acc

                [] ->
                    [ line ]
        )
        []
        lines
        |> List.reverse


{-| `NAME;PARAM=value;PARAM="quoted: value":the value`
-}
parseLine : String -> Maybe Line
parseLine line =
    case splitUnquoted ':' line of
        head :: valueParts ->
            if List.isEmpty valueParts then
                Nothing

            else
                case splitUnquoted ';' head of
                    name :: params ->
                        Just
                            { name = String.toUpper (String.trim name)
                            , params = List.filterMap parseParam params
                            , value = String.join ":" valueParts
                            }

                    [] ->
                        Nothing

        [] ->
            Nothing


parseParam : String -> Maybe ( String, String )
parseParam text =
    case String.indexes "=" text of
        i :: _ ->
            Just
                ( String.toUpper (String.left i text)
                , String.dropLeft (i + 1) text |> String.replace "\"" ""
                )

        [] ->
            Nothing


{-| Splits at a character outside double quotes. Only the first colon of a
line separates the value, so the parts after it are joined again by the caller.
-}
splitUnquoted : Char -> String -> List String
splitUnquoted separator text =
    let
        step c ( inQuotes, current, parts ) =
            if c == '"' then
                ( not inQuotes, c :: current, parts )

            else if c == separator && not inQuotes then
                ( inQuotes, [], String.fromList (List.reverse current) :: parts )

            else
                ( inQuotes, c :: current, parts )

        ( _, last, done ) =
            List.foldl step ( False, [], [] ) (String.toList text)
    in
    List.reverse (String.fromList (List.reverse last) :: done)
        |> rejoinValue separator


{-| After the first unquoted colon the rest is the value, colons and all.
-}
rejoinValue : Char -> List String -> List String
rejoinValue separator parts =
    if separator == ':' then
        case parts of
            head :: rest ->
                if List.isEmpty rest then
                    [ head ]

                else
                    [ head, String.join ":" rest ]

            [] ->
                []

    else
        parts


type alias Walk =
    { stack : List String
    , calendar : List Line
    , events : List (List Line)
    , current : List Line
    }


walk : Line -> Walk -> Walk
walk line state =
    case line.name of
        "BEGIN" ->
            { state
                | stack = String.toUpper line.value :: state.stack
                , current =
                    if String.toUpper line.value == "VEVENT" then
                        []

                    else
                        state.current
            }

        "END" ->
            if String.toUpper line.value == "VEVENT" && List.head state.stack == Just "VEVENT" then
                { state | stack = List.drop 1 state.stack, events = List.reverse state.current :: state.events, current = [] }

            else
                { state | stack = List.drop 1 state.stack }

        _ ->
            case state.stack of
                [ "VCALENDAR" ] ->
                    { state | calendar = line :: state.calendar }

                "VEVENT" :: _ ->
                    { state | current = line :: state.current }

                _ ->
                    state


type alias Parsed =
    { event : Event
    , recurrenceId : Maybe Line
    }


toEvent : String -> List Line -> Maybe Parsed
toEvent calendarZone lines =
    let
        first name =
            List.filter (\l -> l.name == name) lines |> List.head

        text name =
            first name |> Maybe.map (.value >> unescape) |> Maybe.withDefault ""

        all name =
            List.filter (\l -> l.name == name) lines

        start =
            first "DTSTART" |> Maybe.andThen (readTime calendarZone)
    in
    case start of
        Just startTime ->
            let
                end =
                    case first "DTEND" |> Maybe.andThen (readTime calendarZone) of
                        Just e ->
                            e

                        Nothing ->
                            case first "DURATION" |> Maybe.andThen (.value >> duration) of
                                Just minutes ->
                                    addMinutes minutes startTime

                                Nothing ->
                                    case startTime of
                                        AllDay date ->
                                            AllDay (Date.addDays 1 date)

                                        Timed _ ->
                                            startTime

                uid =
                    text "UID"

                status =
                    String.toLower (text "STATUS")

                transp =
                    String.toUpper (text "TRANSP")
            in
            Just
                { event =
                    { id = ""
                    , iCalUID =
                        if uid == "" then
                            text "SUMMARY" ++ "-" ++ (first "DTSTART" |> Maybe.map .value |> Maybe.withDefault "") ++ "@import"

                        else
                            uid
                    , status =
                        if status == "cancelled" || status == "tentative" then
                            status

                        else
                            "confirmed"
                    , summary = text "SUMMARY"
                    , description = text "DESCRIPTION"
                    , location = text "LOCATION"
                    , start = startTime
                    , end = end
                    , recurrence =
                        List.map (\l -> "RRULE:" ++ l.value) (all "RRULE")
                            ++ List.map writeLine (all "EXDATE")
                    , attendees = List.map attendee (all "ATTENDEE")
                    , organizer =
                        first "ORGANIZER"
                            |> Maybe.map (\l -> { email = mailto l.value, displayName = param "CN" l, self = False })
                    , colorId = ""
                    , transparency =
                        if transp == "TRANSPARENT" then
                            "transparent"

                        else
                            ""
                    }
                , recurrenceId = first "RECURRENCE-ID"
                }

        Nothing ->
            Nothing


{-| A changed instance of a series (`RECURRENCE-ID`) becomes an event of its own
and an `EXDATE` on the series, as in the import of a Google calendar.
-}
mergeOverrides : List Parsed -> List Event
mergeOverrides parsed =
    let
        overrides =
            List.filterMap (\p -> Maybe.map (\rid -> ( p.event, rid )) p.recurrenceId) parsed

        exdatesFor uid =
            List.filter (\( e, _ ) -> e.iCalUID == uid) overrides
                |> List.map (\( _, rid ) -> writeLine { rid | name = "EXDATE" })
    in
    List.map
        (\p ->
            case p.recurrenceId of
                Just rid ->
                    let
                        event =
                            p.event
                    in
                    { event | iCalUID = event.iCalUID ++ "-" ++ rid.value, recurrence = [] }

                Nothing ->
                    if List.isEmpty p.event.recurrence then
                        p.event

                    else
                        let
                            event =
                                p.event
                        in
                        { event | recurrence = event.recurrence ++ exdatesFor event.iCalUID }
        )
        parsed
        |> List.filter (\e -> not (e.status == "cancelled" && List.isEmpty e.recurrence && isOverride e parsed))


isOverride : Event -> List Parsed -> Bool
isOverride event parsed =
    List.any (\p -> p.recurrenceId /= Nothing && String.startsWith p.event.iCalUID event.iCalUID && p.event.iCalUID /= event.iCalUID) parsed


attendee : Line -> Attendee
attendee line =
    { email = mailto line.value
    , displayName = param "CN" line
    , self = False
    , organizer = False
    , optional = param "ROLE" line == "OPT-PARTICIPANT"
    , responseStatus =
        case String.toUpper (param "PARTSTAT" line) of
            "ACCEPTED" ->
                Accepted

            "TENTATIVE" ->
                Tentative

            "DECLINED" ->
                Declined

            _ ->
                NeedsAction
    }


param : String -> Line -> String
param name line =
    List.filter (\( k, _ ) -> k == name) line.params
        |> List.head
        |> Maybe.map Tuple.second
        |> Maybe.withDefault ""


mailto : String -> String
mailto value =
    if String.startsWith "mailto:" (String.toLower value) then
        String.toLower (String.dropLeft 7 value)

    else
        String.toLower value


readTime : String -> Line -> Maybe EventTime
readTime calendarZone line =
    let
        value =
            String.trim line.value

        date =
            Date.fromParts
                (String.toInt (String.left 4 value) |> Maybe.withDefault 0)
                (String.toInt (String.slice 4 6 value) |> Maybe.withDefault 0)
                (String.toInt (String.slice 6 8 value) |> Maybe.withDefault 0)
    in
    case date of
        Just d ->
            if String.length value == 8 || param "VALUE" line == "DATE" then
                Just (AllDay d)

            else
                case ( String.toInt (String.slice 9 11 value), String.toInt (String.slice 11 13 value) ) of
                    ( Just h, Just m ) ->
                        let
                            utc =
                                String.endsWith "Z" value

                            tzid =
                                param "TZID" line
                        in
                        Just
                            (Timed
                                { date = d
                                , minute = h * 60 + m
                                , offset =
                                    if utc then
                                        "Z"

                                    else
                                        ""
                                , timeZone =
                                    if utc then
                                        ""

                                    else if tzid /= "" then
                                        tzid

                                    else
                                        calendarZone
                                }
                            )

                    _ ->
                        Nothing

        Nothing ->
            Nothing


{-| An RFC 5545 duration in minutes: `PT1H30M` is 90, `P1D` is 1440, `-PT15M` is -15.
-}
duration : String -> Maybe Int
duration text =
    let
        ( sign, body ) =
            if String.startsWith "-" text then
                ( -1, String.dropLeft 1 text )

            else if String.startsWith "+" text then
                ( 1, String.dropLeft 1 text )

            else
                ( 1, text )

        step c acc =
            case acc of
                Nothing ->
                    Nothing

                Just ( total, digits, inTime ) ->
                    if Char.isDigit c then
                        Just ( total, digits ++ String.fromChar c, inTime )

                    else
                        let
                            n =
                                String.toInt digits |> Maybe.withDefault 0
                        in
                        case c of
                            'P' ->
                                Just ( total, "", inTime )

                            'T' ->
                                Just ( total, "", True )

                            'W' ->
                                Just ( total + n * 7 * 1440, "", inTime )

                            'D' ->
                                Just ( total + n * 1440, "", inTime )

                            'H' ->
                                Just ( total + n * 60, "", inTime )

                            'M' ->
                                if inTime then
                                    Just ( total + n, "", inTime )

                                else
                                    Nothing

                            'S' ->
                                Just ( total, "", inTime )

                            _ ->
                                Nothing
    in
    if String.startsWith "P" body then
        String.foldl step (Just ( 0, "", False )) body
            |> Maybe.map (\( total, _, _ ) -> sign * total)

    else
        Nothing


addMinutes : Int -> EventTime -> EventTime
addMinutes minutes time =
    case time of
        AllDay date ->
            AllDay (Date.addDays (minutes // 1440) date)

        Timed t ->
            let
                total =
                    Date.toEpochDay t.date * 1440 + t.minute + minutes
            in
            Timed { t | date = Date.fromEpochDay (floorDiv total 1440), minute = modBy 1440 total }


floorDiv : Int -> Int -> Int
floorDiv a b =
    floor (toFloat a / toFloat b)


unescape : String -> String
unescape text =
    let
        step c ( escaped, out ) =
            if escaped then
                ( False
                , (case c of
                    'n' ->
                        '\n'

                    'N' ->
                        '\n'

                    _ ->
                        c
                  )
                    :: out
                )

            else if c == '\\' then
                ( True, out )

            else
                ( False, c :: out )
    in
    String.foldl step ( False, [] ) text
        |> Tuple.second
        |> List.reverse
        |> String.fromList



-- WRITING


escape : String -> String
escape text =
    text
        |> String.replace "\\" "\\\\"
        |> String.replace ";" "\\;"
        |> String.replace "," "\\,"
        |> String.replace "\u{000D}\n" "\\n"
        |> String.replace "\n" "\\n"


writeLine : Line -> String
writeLine line =
    line.name
        ++ String.concat (List.map (\( k, v ) -> ";" ++ k ++ "=" ++ quoteParam v) line.params)
        ++ ":"
        ++ line.value


quoteParam : String -> String
quoteParam value =
    if String.contains ":" value || String.contains ";" value || String.contains "," value then
        "\"" ++ value ++ "\""

    else
        value


{-| Lines longer than 75 octets are folded, as the RFC asks (counted in
characters here, which is the same for ASCII).
-}
fold : String -> String
fold line =
    if String.length line <= 75 then
        line

    else
        String.left 75 line ++ "\u{000D}\n " ++ fold (String.dropLeft 75 line)


document : String -> List String -> String
document method body =
    ([ "BEGIN:VCALENDAR", "PRODID:-//Klar Calendar//EN", "VERSION:2.0", "CALSCALE:GREGORIAN", "METHOD:" ++ method ]
        ++ body
        ++ [ "END:VCALENDAR" ]
    )
        |> List.map fold
        |> String.join "\u{000D}\n"
        |> (\s -> s ++ "\u{000D}\n")


timeLine : String -> String -> EventTime -> String
timeLine name zoneName time =
    case time of
        AllDay date ->
            name ++ ";VALUE=DATE:" ++ compactDate date

        Timed t ->
            let
                stamp =
                    compactDate t.date ++ "T" ++ pad2 (t.minute // 60) ++ pad2 (modBy 60 t.minute) ++ "00"
            in
            if t.offset == "Z" then
                name ++ ":" ++ stamp ++ "Z"

            else
                let
                    zone =
                        if t.offset == "" && t.timeZone /= "" then
                            t.timeZone

                        else
                            zoneName
                in
                name ++ ";TZID=" ++ zone ++ ":" ++ stamp


compactDate : Date -> String
compactDate date =
    String.replace "-" "" (Date.toIso date)


pad2 : Int -> String
pad2 n =
    String.padLeft 2 '0' (String.fromInt n)


utcStamp : Time.Posix -> String
utcStamp now =
    compactDate (Date.fromPosix Time.utc now)
        ++ "T"
        ++ pad2 (Time.toHour Time.utc now)
        ++ pad2 (Time.toMinute Time.utc now)
        ++ pad2 (Time.toSecond Time.utc now)
        ++ "Z"


partstat : ResponseStatus -> String
partstat status =
    case status of
        Accepted ->
            "ACCEPTED"

        Tentative ->
            "TENTATIVE"

        Declined ->
            "DECLINED"

        NeedsAction ->
            "NEEDS-ACTION"


person : String -> String -> String -> String
person name displayName email =
    name
        ++ (if displayName == "" then
                ""

            else
                ";CN=" ++ quoteParam displayName
           )
        ++ ":mailto:"
        ++ email


eventLines : String -> Time.Posix -> Event -> List String
eventLines zoneName now event =
    List.concat
        [ [ "BEGIN:VEVENT"
          , "UID:" ++ event.iCalUID
          , "DTSTAMP:" ++ utcStamp now
          , timeLine "DTSTART" zoneName event.start
          , timeLine "DTEND" zoneName event.end
          , "SUMMARY:" ++ escape event.summary
          ]
        , if event.description == "" then
            []

          else
            [ "DESCRIPTION:" ++ escape event.description ]
        , if event.location == "" then
            []

          else
            [ "LOCATION:" ++ escape event.location ]
        , event.recurrence
        , case event.organizer of
            Just o ->
                [ person "ORGANIZER" o.displayName o.email ]

            Nothing ->
                []
        , List.map
            (\a -> person ("ATTENDEE;PARTSTAT=" ++ partstat a.responseStatus) a.displayName a.email)
            event.attendees
        , [ "STATUS:" ++ String.toUpper event.status, "END:VEVENT" ]
        ]


{-| The answer to an invitation (`METHOD:REPLY`), for the guest to send back to
the organizer: the event with only the guest and their answer.
-}
reply : { zoneName : String, now : Time.Posix, email : String, name : String, status : ResponseStatus } -> Event -> String
reply { zoneName, now, email, name, status } event =
    document "REPLY"
        (eventLines zoneName
            now
            { event
                | attendees =
                    [ { email = email, displayName = name, self = True, organizer = False, optional = False, responseStatus = status } ]
                , description = ""
                , recurrence = List.filter (String.startsWith "RRULE") event.recurrence
            }
        )


{-| A whole calendar as an `.ics` file that Google Calendar and Outlook import.
The times are the wall clock in `zoneName`, the zone they were fetched in.
-}
export : { zoneName : String, now : Time.Posix, name : String } -> List Event -> String
export { zoneName, now, name } events =
    document "PUBLISH"
        (("X-WR-CALNAME:" ++ escape name)
            :: ("X-WR-TIMEZONE:" ++ zoneName)
            :: List.concatMap (\e -> eventLines zoneName now { e | iCalUID = nonEmpty e.iCalUID e.id }) events
        )


nonEmpty : String -> String -> String
nonEmpty value fallback =
    if value == "" then
        fallback

    else
        value
