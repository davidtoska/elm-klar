module DatePickersTest exposing (suite)

{-| The date and time pickers after the perfecting pass:

  - every message is plain data (the view reads the text with the rules, so a
    message never holds the `disabledWhen` function),
  - one vocabulary for the field states: `value`, `setValue`, `isValid`,
    `setLimits`, `clear`,
  - `open` keeps a disabled or read-only field closed, and ARIA references name
    elements that exist,
  - `DateTimePicker` reads its parts, converts to and from moments and text, and
    names its inputs after its label.

A test draws the view, finds a control the way a user would, simulates the event
on it, and gives the message to `update`.

-}

import Expect exposing (Expectation)
import Html.Attributes as Attr
import Json.Encode as Encode
import Klar.Date as Date exposing (Date)
import Klar.DatePicker as DatePicker
import Klar.DateRangePicker as DateRangePicker
import Klar.DateTimePicker as DateTimePicker
import Klar.TimePicker as TimePicker
import Test exposing (Test, describe, test)
import Test.Html.Event as Event
import Test.Html.Query as Query
import Test.Html.Selector as Selector exposing (Selector)
import Time


suite : Test
suite =
    describe "Date and time pickers"
        [ plainMessages
        , datePickerReading
        , datePickerLimits
        , closedWhenInactive
        , rangeText
        , timePickerAria
        , ownButtons
        , dateTimeParts
        , dateTimeText
        , dateTimeMoments
        , dateTimeNames
        ]


date : Int -> Int -> Int -> Date
date year month day =
    Date.fromParts year month day |> Maybe.withDefault (Date.fromEpochDay 0)


today : Date
today =
    date 2026 10 20


isWeekend : Date -> Bool
isWeekend day =
    Date.weekday day >= 6


attributeIs : String -> String -> Selector
attributeIs name value =
    Selector.attribute (Attr.attribute name value)


allOf : List Expectation -> Expectation
allOf expectations =
    Expect.all (List.map (\expectation _ -> expectation) expectations) ()


{-| A key press on a text field whose text is `text`.
-}
key : String -> String -> ( String, Encode.Value )
key name text =
    Event.custom "keydown"
        (Encode.object
            [ ( "key", Encode.string name )
            , ( "ctrlKey", Encode.bool False )
            , ( "metaKey", Encode.bool False )
            , ( "shiftKey", Encode.bool False )
            , ( "altKey", Encode.bool False )
            , ( "target", Encode.object [ ( "value", Encode.string text ) ] )
            ]
        )


{-| Focus leaves a text field whose text is `text`.
-}
blur : String -> ( String, Encode.Value )
blur text =
    Event.custom "blur" (Encode.object [ ( "target", Encode.object [ ( "value", Encode.string text ) ] ) ])


{-| Every message is `Ok` and can be compared with `==`: comparing a value that
holds a function would crash the test.
-}
expectPlainData : Int -> List (Result String msg) -> Expectation
expectPlainData count messages =
    let
        found =
            List.filterMap Result.toMaybe messages
    in
    allOf
        [ Expect.equal count (List.length found)
        , Expect.equal True (found == List.reverse (List.reverse found))
        ]



-- DATE PICKER


dueAttributes : List (DatePicker.Attribute DatePicker.Msg)
dueAttributes =
    [ DatePicker.today today, DatePicker.min today, DatePicker.disabledWhen isWeekend ]


dueSend : String -> ( String, Encode.Value ) -> DatePicker.State -> Result String DatePicker.Msg
dueSend id event state =
    DatePicker.view identity dueAttributes state
        |> Query.fromHtml
        |> Query.find [ Selector.id id ]
        |> Event.simulate event
        |> Event.toResult


{-| The state after the event, sent from the view of `drawn` and given to
`update` with `state` (they differ when the event comes before a render).
-}
dueAfter : String -> ( String, Encode.Value ) -> DatePicker.State -> DatePicker.State -> DatePicker.State
dueAfter id event drawn state =
    case dueSend id event drawn of
        Ok message ->
            Tuple.first (DatePicker.update message state)

        Err _ ->
            state


plainMessages : Test
plainMessages =
    describe "a message holds plain data only"
        [ test "the date field: typing, leaving, Enter, ArrowDown, the calendar button and a day" <|
            \_ ->
                let
                    state =
                        DatePicker.init "due" |> DatePicker.setText "2026-10-2"

                    opened =
                        DatePicker.open dueAttributes (DatePicker.init "due") |> Tuple.first
                in
                expectPlainData 6
                    [ dueSend "due" (Event.input "2026-10-24") state
                    , dueSend "due" (blur "2026-10-24") state
                    , dueSend "due" (key "Enter" "2026-10-24") state
                    , dueSend "due" (key "ArrowDown" "2026-10-24") state
                    , dueSend "due-button" Event.click state
                    , dueSend "due-popup-cal-d-2026-10-21" Event.click opened
                    ]
        , test "the period field: typing, leaving and keys in both inputs, and the button" <|
            \_ ->
                let
                    attributes =
                        [ DateRangePicker.today today, DateRangePicker.disabledWhen isWeekend, DateRangePicker.maxRangeDays 30 ]

                    send id event =
                        DateRangePicker.view identity attributes (DateRangePicker.init "period")
                            |> Query.fromHtml
                            |> Query.find [ Selector.id id ]
                            |> Event.simulate event
                            |> Event.toResult
                in
                expectPlainData 7
                    [ send "period-from" (Event.input "2026-10-20")
                    , send "period-to" (Event.input "2026-10-23")
                    , send "period-from" (blur "2026-10-20")
                    , send "period-to" (blur "2026-10-23")
                    , send "period-from" (key "Enter" "2026-10-20")
                    , send "period-to" (key "ArrowDown" "2026-10-23")
                    , send "period-button" Event.click
                    ]
        , test "the date and time field" <|
            \_ ->
                let
                    send id event =
                        DateTimePicker.view identity [ DateTimePicker.today today, DateTimePicker.disabledWhen isWeekend ] (DateTimePicker.init "pickup")
                            |> Query.fromHtml
                            |> Query.find [ Selector.id id ]
                            |> Event.simulate event
                            |> Event.toResult
                in
                expectPlainData 4
                    [ send "pickup-date" (Event.input "2026-10-21")
                    , send "pickup-date" (blur "2026-10-21")
                    , send "pickup-time" (Event.input "14:30")
                    , send "pickup-date-button" Event.click
                    ]
        ]


datePickerReading : Test
datePickerReading =
    describe "the date field reads its text with the rules of the view"
        [ test "a complete date on a disabled day is rejected while typing" <|
            \_ ->
                let
                    state =
                        dueAfter "due" (Event.input "2026-10-24") (DatePicker.init "due") (DatePicker.init "due")
                in
                Expect.equal ( Nothing, False, "2026-10-24" ) ( DatePicker.value state, DatePicker.isValid state, DatePicker.text state )
        , test "a complete date on an allowed day is taken while typing, and the text stays" <|
            \_ ->
                let
                    state =
                        dueAfter "due" (Event.input "2026-10-21") (DatePicker.init "due") (DatePicker.init "due")
                in
                Expect.equal ( Just (date 2026 10 21), True, "2026-10-21" ) ( DatePicker.value state, DatePicker.isValid state, DatePicker.text state )
        , test "Enter right after typing, before the next render, takes the text the field has" <|
            \_ ->
                let
                    blank =
                        DatePicker.init "due"

                    -- a two-digit year is not complete, so it waits for Enter
                    typed =
                        dueAfter "due" (Event.input "21.10.26") blank blank

                    -- the view of the blank field, not yet drawn again
                    entered =
                        dueAfter "due" (key "Enter" "21.10.26") blank typed
                in
                Expect.equal ( Nothing, Just (date 2026 10 21), "" )
                    ( DatePicker.value typed, DatePicker.value entered, DatePicker.text entered )
        , test "leaving the field takes the text, formatted" <|
            \_ ->
                let
                    typed =
                        DatePicker.init "due" |> DatePicker.setText "21.10.2026"

                    left =
                        dueAfter "due" (blur "21.10.2026") typed typed
                in
                Expect.equal ( Just (date 2026 10 21), "" ) ( DatePicker.value left, DatePicker.text left )
        , test "a reading of another text than the field holds is left for later" <|
            \_ ->
                let
                    typed =
                        DatePicker.init "due" |> DatePicker.setText "2026-10-21"

                    left =
                        dueAfter "due" (blur "2026-10-22") typed typed
                in
                Expect.equal ( Nothing, "2026-10-21", True ) ( DatePicker.value left, DatePicker.text left, DatePicker.isValid left )
        ]


datePickerLimits : Test
datePickerLimits =
    describe "setLimits"
        [ test "reads pending text" <|
            \_ ->
                DatePicker.init "due"
                    |> DatePicker.setText "2026-10-21"
                    |> DatePicker.setLimits dueAttributes
                    |> DatePicker.value
                    |> Expect.equal (Just (date 2026 10 21))
        , test "an accepted date that the limits no longer allow keeps its text, with the message" <|
            \_ ->
                let
                    state =
                        DatePicker.init "due"
                            |> DatePicker.setValue (Just (date 2026 10 1))
                            |> DatePicker.setLimits dueAttributes
                in
                allOf
                    [ Expect.equal ( Nothing, False, "2026-10-01" ) ( DatePicker.value state, DatePicker.isValid state, DatePicker.text state )
                    , DatePicker.view identity dueAttributes state
                        |> Query.fromHtml
                        |> Query.has [ Selector.text "The date cannot be before 2026-10-20" ]
                    ]
        , test "a date inside the limits stays as it is" <|
            \_ ->
                let
                    state =
                        DatePicker.init "due"
                            |> DatePicker.setValue (Just (date 2026 10 21))
                            |> DatePicker.setLimits dueAttributes
                in
                Expect.equal ( Just (date 2026 10 21), True, "" ) ( DatePicker.value state, DatePicker.isValid state, DatePicker.text state )
        , test "the period field: a period longer than the new maxRangeDays is flagged" <|
            \_ ->
                let
                    state =
                        DateRangePicker.init "period"
                            |> DateRangePicker.setValue (Just ( date 2026 10 1, date 2026 10 31 ))
                            |> DateRangePicker.setLimits [ DateRangePicker.maxRangeDays 7 ]
                in
                Expect.equal ( Nothing, False ) ( DateRangePicker.value state, DateRangePicker.isValid state )
        , test "the period field: a from date before the new min keeps its text" <|
            \_ ->
                let
                    state =
                        DateRangePicker.init "period"
                            |> DateRangePicker.setValue (Just ( date 2026 10 1, date 2026 10 31 ))
                            |> DateRangePicker.setLimits [ DateRangePicker.min (date 2026 10 5) ]
                in
                Expect.equal ( { from = "2026-10-01", to = "" }, Nothing, Just (date 2026 10 31) )
                    ( DateRangePicker.text state, DateRangePicker.from state, DateRangePicker.to state )
        , test "the time field: a time after the new max keeps its text" <|
            \_ ->
                let
                    state =
                        TimePicker.init "cutoff"
                            |> TimePicker.setValue (Just { hour = 17, minute = 0 })
                            |> TimePicker.setLimits [ TimePicker.max { hour = 16, minute = 0 } ]
                in
                Expect.equal ( Nothing, False, "17:00" ) ( TimePicker.value state, TimePicker.isValid state, TimePicker.text state )
        , test "clear empties the field and its complaint" <|
            \_ ->
                DatePicker.init "due"
                    |> DatePicker.setValue (Just (date 2026 10 1))
                    |> DatePicker.setLimits dueAttributes
                    |> DatePicker.clear
                    |> (\state -> ( DatePicker.value state, DatePicker.isValid state, DatePicker.text state ))
                    |> Expect.equal ( Nothing, True, "" )
        ]


closedWhenInactive : Test
closedWhenInactive =
    describe "open keeps a disabled or read-only field closed"
        [ test "the date field" <|
            \_ ->
                Expect.equal [ False, False, True ]
                    (List.map
                        (\attributes -> DatePicker.isOpen (Tuple.first (DatePicker.open attributes (DatePicker.init "due"))))
                        [ [ DatePicker.disabled True ], [ DatePicker.readOnly True ], [] ]
                    )
        , test "the period field" <|
            \_ ->
                Expect.equal [ False, False, True ]
                    (List.map
                        (\attributes -> DateRangePicker.isOpen (Tuple.first (DateRangePicker.open attributes (DateRangePicker.init "period"))))
                        [ [ DateRangePicker.disabled True ], [ DateRangePicker.readOnly True ], [] ]
                    )
        , test "the time field" <|
            \_ ->
                Expect.equal [ False, False, True ]
                    (List.map
                        (\attributes -> TimePicker.isOpen (Tuple.first (TimePicker.open attributes (TimePicker.init "cutoff"))))
                        [ [ TimePicker.disabled True ], [ TimePicker.readOnly True ], [] ]
                    )
        , test "an open calendar button names a popup that exists" <|
            \_ ->
                let
                    html =
                        DatePicker.open dueAttributes (DatePicker.init "due")
                            |> Tuple.first
                            |> DatePicker.view identity dueAttributes
                            |> Query.fromHtml
                in
                allOf
                    [ html |> Query.find [ Selector.id "due-button" ] |> Query.has [ attributeIs "aria-controls" "due-popup", attributeIs "aria-expanded" "true" ]
                    , html |> Query.findAll [ Selector.id "due-popup" ] |> Query.count (Expect.equal 1)
                    ]
        ]


rangeText : Test
rangeText =
    describe "the period field's text and placeholder"
        [ test "text gives the pending text of both inputs" <|
            \_ ->
                DateRangePicker.init "period"
                    |> DateRangePicker.setText { from = "1.10.2026", to = "garbage" }
                    |> DateRangePicker.text
                    |> Expect.equal { from = "1.10.2026", to = "garbage" }
        , test "accepted dates are no pending text" <|
            \_ ->
                DateRangePicker.init "period"
                    |> DateRangePicker.setValue (Just ( date 2026 10 1, date 2026 10 31 ))
                    |> DateRangePicker.text
                    |> Expect.equal { from = "", to = "" }
        , test "placeholder reaches both inputs" <|
            \_ ->
                let
                    html =
                        DateRangePicker.view identity [ DateRangePicker.placeholder "dd.mm" ] (DateRangePicker.init "period")
                            |> Query.fromHtml
                in
                allOf
                    [ html |> Query.find [ Selector.id "period-from" ] |> Query.has [ Selector.attribute (Attr.placeholder "dd.mm") ]
                    , html |> Query.find [ Selector.id "period-to" ] |> Query.has [ Selector.attribute (Attr.placeholder "dd.mm") ]
                    ]
        ]


timePickerAria : Test
timePickerAria =
    let
        openWith attributes =
            TimePicker.open attributes (TimePicker.init "cutoff")
                |> Tuple.first
                |> TimePicker.view identity attributes
                |> Query.fromHtml
    in
    describe "the time field's list"
        [ test "with times to offer, aria-controls names the list, which exists" <|
            \_ ->
                let
                    html =
                        openWith []
                in
                allOf
                    [ html |> Query.find [ Selector.id "cutoff" ] |> Query.has [ attributeIs "aria-controls" "cutoff-popup-list" ]
                    , html |> Query.findAll [ Selector.id "cutoff-popup-list" ] |> Query.count (Expect.equal 1)
                    ]
        , test "with no time to offer, the input points at no list" <|
            \_ ->
                let
                    attributes =
                        [ TimePicker.min { hour = 16, minute = 0 }, TimePicker.max { hour = 8, minute = 0 } ]

                    html =
                        openWith attributes
                in
                allOf
                    [ html |> Query.find [ Selector.id "cutoff" ] |> Query.hasNot [ attributeIs "aria-controls" "cutoff-popup-list" ]
                    , html |> Query.has [ Selector.text "No times to choose" ]
                    ]
        ]


ownButtons : Test
ownButtons =
    describe "every field has a button of its own block"
        [ test "the period field" <|
            \_ ->
                DateRangePicker.view identity [] (DateRangePicker.init "period")
                    |> Query.fromHtml
                    |> Query.find [ Selector.id "period-button" ]
                    |> Query.has [ Selector.class "klar-daterange__button" ]
        , test "the time field" <|
            \_ ->
                TimePicker.view identity [] (TimePicker.init "cutoff")
                    |> Query.fromHtml
                    |> Query.find [ Selector.id "cutoff-button" ]
                    |> Query.has [ Selector.class "klar-timepicker__button" ]
        , test "the date field keeps its own" <|
            \_ ->
                DatePicker.view identity [] (DatePicker.init "due")
                    |> Query.fromHtml
                    |> Query.find [ Selector.id "due-button" ]
                    |> Query.has [ Selector.class "klar-datepicker__button" ]
        ]



-- DATE AND TIME


afternoon : DateTimePicker.DateTime
afternoon =
    { date = today, time = { hour = 14, minute = 30 } }


dateTimeParts : Test
dateTimeParts =
    describe "the parts of a date and time field"
        [ test "date and time are read on their own, value only with both" <|
            \_ ->
                let
                    state =
                        DateTimePicker.init "pickup" |> DateTimePicker.setDate (Just today)
                in
                Expect.equal ( Just today, Nothing, Nothing )
                    ( DateTimePicker.date state, DateTimePicker.time state, DateTimePicker.value state )
        , test "setTime completes the value and leaves the date alone" <|
            \_ ->
                DateTimePicker.init "pickup"
                    |> DateTimePicker.setDate (Just today)
                    |> DateTimePicker.setTime (Just { hour = 14, minute = 30 })
                    |> DateTimePicker.value
                    |> Expect.equal (Just afternoon)
        , test "setValue sets both, and clear empties both" <|
            \_ ->
                let
                    set =
                        DateTimePicker.init "pickup" |> DateTimePicker.setValue (Just afternoon)
                in
                Expect.equal ( Just afternoon, Nothing, Nothing )
                    ( DateTimePicker.value set, DateTimePicker.date (DateTimePicker.clear set), DateTimePicker.time (DateTimePicker.clear set) )
        ]


dateTimeText : Test
dateTimeText =
    describe "DateTimePicker.toIso and fromIso"
        [ test "toIso writes the local date and time" <|
            \_ -> Expect.equal "2026-10-20T14:30" (DateTimePicker.toIso afternoon)
        , test "fromIso reads it back" <|
            \_ -> Expect.equal (Just afternoon) (DateTimePicker.fromIso "2026-10-20T14:30")
        , test "seconds are accepted and dropped" <|
            \_ -> Expect.equal (Just afternoon) (DateTimePicker.fromIso "2026-10-20T14:30:59")
        , test "a zone makes it a moment, not a wall-clock time" <|
            \_ ->
                Expect.equal [ Nothing, Nothing ]
                    [ DateTimePicker.fromIso "2026-10-20T14:30Z", DateTimePicker.fromIso "2026-10-20T14:30+02:00" ]
        , test "what does not exist is Nothing" <|
            \_ ->
                Expect.equal [ Nothing, Nothing, Nothing, Nothing ]
                    [ DateTimePicker.fromIso "2026-02-30T10:00"
                    , DateTimePicker.fromIso "2026-10-20T24:00"
                    , DateTimePicker.fromIso "2026-10-20T9:00"
                    , DateTimePicker.fromIso "2026-10-20 14:30"
                    ]
        ]


{-| Central European time in 2026: UTC+1, and UTC+2 from 29 March 01:00 UTC to
25 October 01:00 UTC. An era of `Time.customZone` applies from the minute after
its `start`, so each starts a minute before the change.
-}
oslo : Time.Zone
oslo =
    let
        minutesAt day hourUtc =
            Date.toEpochDay day * 1440 + hourUtc * 60 - 1
    in
    Time.customZone 60
        [ { start = minutesAt (date 2026 10 25) 1, offset = 60 }
        , { start = minutesAt (date 2026 3 29) 1, offset = 120 }
        ]


{-| Milliseconds of a UTC date and time.
-}
utc : Date -> Int -> Int -> Int
utc day hour minute =
    Date.toEpochDay day * 86400000 + (hour * 60 + minute) * 60000


dateTimeMoments : Test
dateTimeMoments =
    let
        at day hour minute =
            { date = day, time = { hour = hour, minute = minute } }

        moment zone value =
            Time.posixToMillis (DateTimePicker.toPosix zone value)
    in
    describe "DateTimePicker.toPosix and fromPosix"
        [ test "in UTC the wall-clock time is the moment" <|
            \_ -> Expect.equal (utc today 14 30) (moment Time.utc afternoon)
        , test "in summer time the offset is two hours" <|
            \_ -> Expect.equal (utc (date 2026 7 1) 10 0) (moment oslo (at (date 2026 7 1) 12 0))
        , test "in winter time the offset is one hour" <|
            \_ -> Expect.equal (utc (date 2026 12 1) 11 0) (moment oslo (at (date 2026 12 1) 12 0))
        , test "a time that happens twice when the clock is put back is the first of the two" <|
            \_ -> Expect.equal (utc (date 2026 10 25) 0 30) (moment oslo (at (date 2026 10 25) 2 30))
        , test "a time that does not exist when the clock is put forward moves forward by the jump" <|
            \_ ->
                Expect.equal ( utc (date 2026 3 29) 1 30, at (date 2026 3 29) 3 30 )
                    ( moment oslo (at (date 2026 3 29) 2 30)
                    , DateTimePicker.fromPosix oslo (DateTimePicker.toPosix oslo (at (date 2026 3 29) 2 30))
                    )
        , test "fromPosix gives the wall-clock time back, on either side of a change" <|
            \_ ->
                let
                    times =
                        [ at (date 2026 3 28) 23 45, at (date 2026 3 29) 3 0, at (date 2026 10 24) 23 59, at (date 2026 10 25) 3 0, afternoon ]
                in
                Expect.equal times (List.map (\value -> DateTimePicker.fromPosix oslo (DateTimePicker.toPosix oslo value)) times)
        ]


dateTimeNames : Test
dateTimeNames =
    let
        input id attributes =
            DateTimePicker.view identity attributes (DateTimePicker.init "pickup")
                |> Query.fromHtml
                |> Query.find [ Selector.tag "label", Selector.attribute (Attr.for id) ]
    in
    describe "the inputs of a date and time field are named after its label"
        [ test "with a label" <|
            \_ ->
                allOf
                    [ input "pickup-date" [ DateTimePicker.label "Pick-up time" ] |> Query.has [ Selector.text "Pick-up time, date" ]
                    , input "pickup-time" [ DateTimePicker.label "Pick-up time" ] |> Query.has [ Selector.text "Pick-up time, time" ]
                    ]
        , test "without a label, the part alone" <|
            \_ ->
                allOf
                    [ input "pickup-date" [] |> Query.has [ Selector.text "Date" ]
                    , input "pickup-time" [] |> Query.has [ Selector.text "Time" ]
                    ]
        ]
