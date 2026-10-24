module Occurrence exposing
    ( Occurrence
    , Placed
    , covers
    , exdates
    , expand
    , layoutDay
    , rule
    , wallOf
    )

{-| The events of a period as the calendar draws them: a recurring event becomes
one occurrence per date (with `Klar.Recurrence`), and the timed occurrences of a
day are laid out in columns where they overlap.

Times are "wall minutes": the epoch day times 1440 plus the minute of the day,
on the wall clock of the zone the events were fetched in.

-}

import Gcal exposing (CalendarEntry, Event, EventTime(..))
import Klar.Date as Date exposing (Date)
import Klar.Recurrence as Recurrence


type alias Occurrence =
    { key : String
    , event : Event
    , calendar : CalendarEntry
    , start : Int
    , end : Int
    , allDay : Bool
    , date : Date
    }


wallOf : EventTime -> Int
wallOf time =
    case time of
        AllDay date ->
            Date.toEpochDay date * 1440

        Timed t ->
            Date.toEpochDay t.date * 1440 + t.minute


startDate : EventTime -> Date
startDate time =
    case time of
        AllDay date ->
            date

        Timed t ->
            t.date


{-| The rule of a recurring event, if `Klar.Recurrence` can read it. Parts it
does not know (`WKST`, the time of an `UNTIL`) are dropped first.
-}
rule : Event -> Maybe Recurrence.Rule
rule event =
    event.recurrence
        |> List.filter (String.startsWith "RRULE:")
        |> List.head
        |> Maybe.andThen
            (\line ->
                String.dropLeft 6 line
                    |> String.split ";"
                    |> List.filter (\part -> not (String.startsWith "WKST=" part))
                    |> List.map
                        (\part ->
                            if String.startsWith "UNTIL=" part then
                                String.left 14 part

                            else
                                part
                        )
                    |> String.join ";"
                    |> Recurrence.fromRRule
                    |> Result.toMaybe
            )
        |> Maybe.map (Recurrence.withExceptions (exdates event))


{-| The dates of the `EXDATE` lines (`EXDATE;TZID=Europe/Oslo:20261103T090000`,
`EXDATE;VALUE=DATE:20261103,20261110`).
-}
exdates : Event -> List Date
exdates event =
    event.recurrence
        |> List.filter (String.startsWith "EXDATE")
        |> List.concatMap
            (\line ->
                case String.split ":" line |> List.reverse |> List.head of
                    Just values ->
                        String.split "," values
                            |> List.filterMap
                                (\v ->
                                    Date.fromParts
                                        (String.toInt (String.left 4 v) |> Maybe.withDefault 0)
                                        (String.toInt (String.slice 4 6 v) |> Maybe.withDefault 0)
                                        (String.toInt (String.slice 6 8 v) |> Maybe.withDefault 0)
                                )

                    Nothing ->
                        []
            )


{-| Does an occurrence touch the period from `from` (inclusive) to `to`
(exclusive), in wall minutes?
-}
covers : Int -> Int -> Occurrence -> Bool
covers from to occ =
    occ.start < to && (occ.end > from || (occ.end == occ.start && occ.start >= from))


{-| The occurrences of an event between two dates (`to` exclusive). A recurring
event whose rule cannot be read shows only its first date.
-}
expand : { from : Date, to : Date } -> CalendarEntry -> Event -> List Occurrence
expand { from, to } calendar event =
    let
        start =
            wallOf event.start

        length =
            max 0 (wallOf event.end - start)

        first =
            startDate event.start

        allDay =
            case event.start of
                AllDay _ ->
                    True

                Timed _ ->
                    False

        fromWall =
            Date.toEpochDay from * 1440

        toWall =
            Date.toEpochDay to * 1440

        at date =
            let
                shift =
                    Date.diffDays first date * 1440
            in
            { key = event.id ++ "/" ++ Date.toIso date
            , event = event
            , calendar = calendar
            , start = start + shift
            , end = start + shift + length
            , allDay = allDay
            , date = date
            }

        dates =
            case rule event of
                Just r ->
                    let
                        found =
                            Recurrence.between
                                { start = first
                                , from = Date.addDays (negate (length // 1440 + 1)) from
                                , to = to
                                }
                                r

                        excluded =
                            exdates event
                    in
                    (if List.member first excluded then
                        found.dates

                     else
                        first :: found.dates
                    )
                        |> List.map Date.toEpochDay
                        |> List.sort
                        |> unique
                        |> List.map Date.fromEpochDay

                Nothing ->
                    [ first ]
    in
    List.map at dates
        |> List.filter (covers fromWall toWall)


unique : List comparable -> List comparable
unique sorted =
    case sorted of
        a :: b :: rest ->
            if a == b then
                unique (b :: rest)

            else
                a :: unique (b :: rest)

        _ ->
            sorted



-- LAYOUT


{-| An occurrence in a day column: its top and bottom in minutes of that day,
the column it is in and how many columns its group of overlapping events has.
-}
type alias Placed =
    { occurrence : Occurrence
    , top : Int
    , bottom : Int
    , column : Int
    , columns : Int
    }


{-| Lays out the timed occurrences of one day. An event shorter than
`minimum` minutes is drawn `minimum` minutes tall, and overlaps as such.
-}
layoutDay : Int -> Date -> List Occurrence -> List Placed
layoutDay minimum date occurrences =
    let
        dayStart =
            Date.toEpochDay date * 1440

        clipped =
            occurrences
                |> List.filter (\o -> not o.allDay && covers dayStart (dayStart + 1440) o)
                |> List.map
                    (\o ->
                        let
                            top =
                                clamp 0 1440 (o.start - dayStart)
                        in
                        { occurrence = o
                        , top = top
                        , bottom = min 1440 (max (top + minimum) (o.end - dayStart))
                        , column = 0
                        , columns = 1
                        }
                    )
                |> List.sortBy (\p -> ( p.top, negate p.bottom, p.occurrence.key ))
    in
    clusters clipped
        |> List.concatMap placeCluster


{-| Groups of occurrences that overlap one another, directly or through others.
-}
clusters : List Placed -> List (List Placed)
clusters sorted =
    let
        step p ( current, currentEnd, done ) =
            if List.isEmpty current || p.top < currentEnd then
                ( p :: current, max currentEnd p.bottom, done )

            else
                ( [ p ], p.bottom, List.reverse current :: done )

        ( last, _, finished ) =
            List.foldl step ( [], 0, [] ) sorted
    in
    List.reverse
        (if List.isEmpty last then
            finished

         else
            List.reverse last :: finished
        )


placeCluster : List Placed -> List Placed
placeCluster cluster =
    let
        -- the bottom of the last occurrence in each column
        step p ( columnEnds, placed ) =
            case firstFree p.top 0 columnEnds of
                Just i ->
                    ( List.indexedMap
                        (\j e ->
                            if j == i then
                                p.bottom

                            else
                                e
                        )
                        columnEnds
                    , { p | column = i } :: placed
                    )

                Nothing ->
                    ( columnEnds ++ [ p.bottom ], { p | column = List.length columnEnds } :: placed )

        ( ends, all ) =
            List.foldl step ( [], [] ) cluster
    in
    List.reverse all |> List.map (\p -> { p | columns = List.length ends })


firstFree : Int -> Int -> List Int -> Maybe Int
firstFree top index ends =
    case ends of
        e :: rest ->
            if e <= top then
                Just index

            else
                firstFree top (index + 1) rest

        [] ->
            Nothing
