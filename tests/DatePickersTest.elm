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
        , timeRecords
        , ownButtons
        , dateTimeParts
        , dateTimeText
        , dateTimeMoments
        , dateTimeNames
        , dateTimePopups
        , invalidAndNames
        , rangeTyping
        , presetKeyboard
        , presetAtTheEnd
        , rangeName
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


{-| Every message is `Ok`, and the messages of two separate renders compare
equal with `==`. The two renders get two different functions for the disabled
days (`isWeekend` and a new closure around it), so a message that held the
function, or anything built from it, would make `==` meet two different
functions and crash the test.
-}
expectPlainData : Int -> ((Date -> Bool) -> List (Result String msg)) -> Expectation
expectPlainData count messagesWith =
    let
        first =
            List.filterMap Result.toMaybe (messagesWith isWeekend)

        second =
            List.filterMap Result.toMaybe (messagesWith (\d -> isWeekend d))
    in
    allOf
        [ Expect.equal count (List.length first)
        , Expect.equal count (List.length second)
        , Expect.equal True (List.all identity (List.map2 (==) first second))
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

                    sendWith disabled id event drawn =
                        DatePicker.view identity [ DatePicker.today today, DatePicker.min today, DatePicker.disabledWhen disabled ] drawn
                            |> Query.fromHtml
                            |> Query.find [ Selector.id id ]
                            |> Event.simulate event
                            |> Event.toResult
                in
                expectPlainData 6
                    (\disabled ->
                        [ sendWith disabled "due" (Event.input "2026-10-24") state
                        , sendWith disabled "due" (blur "2026-10-24") state
                        , sendWith disabled "due" (key "Enter" "2026-10-24") state
                        , sendWith disabled "due" (key "ArrowDown" "2026-10-24") state
                        , sendWith disabled "due-button" Event.click state
                        , sendWith disabled "due-popup-cal-d-2026-10-21" Event.click opened
                        ]
                    )
        , test "the period field: typing, leaving and keys in both inputs, and the button" <|
            \_ ->
                let
                    send disabled id event =
                        DateRangePicker.view identity
                            [ DateRangePicker.today today, DateRangePicker.disabledWhen disabled, DateRangePicker.maxRangeDays 30 ]
                            (DateRangePicker.init "period")
                            |> Query.fromHtml
                            |> Query.find [ Selector.id id ]
                            |> Event.simulate event
                            |> Event.toResult
                in
                expectPlainData 7
                    (\disabled ->
                        [ send disabled "period-from" (Event.input "2026-10-20")
                        , send disabled "period-to" (Event.input "2026-10-23")
                        , send disabled "period-from" (blur "2026-10-20")
                        , send disabled "period-to" (blur "2026-10-23")
                        , send disabled "period-from" (key "Enter" "2026-10-20")
                        , send disabled "period-to" (key "ArrowDown" "2026-10-23")
                        , send disabled "period-button" Event.click
                        ]
                    )
        , test "the date and time field" <|
            \_ ->
                let
                    send disabled id event =
                        DateTimePicker.view identity [ DateTimePicker.today today, DateTimePicker.disabledWhen disabled ] (DateTimePicker.init "pickup")
                            |> Query.fromHtml
                            |> Query.find [ Selector.id id ]
                            |> Event.simulate event
                            |> Event.toResult
                in
                expectPlainData 4
                    (\disabled ->
                        [ send disabled "pickup-date" (Event.input "2026-10-21")
                        , send disabled "pickup-date" (blur "2026-10-21")
                        , send disabled "pickup-time" (Event.input "14:30")
                        , send disabled "pickup-date-button" Event.click
                        ]
                    )
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
        , test "a field made disabled while its list is open names no highlighted option" <|
            \_ ->
                let
                    opened =
                        TimePicker.init "cutoff"
                            |> TimePicker.setValue (Just { hour = 9, minute = 0 })
                            |> TimePicker.open []
                            |> Tuple.first

                    input attributes =
                        TimePicker.view identity attributes opened
                            |> Query.fromHtml
                            |> Query.find [ Selector.id "cutoff" ]
                in
                allOf
                    [ input [] |> Query.has [ attributeIs "aria-activedescendant" "cutoff-popup-opt-540" ]
                    , input [ TimePicker.disabled True ] |> Query.hasNot [ attributeIs "aria-activedescendant" "cutoff-popup-opt-540" ]
                    , input [ TimePicker.readOnly True ] |> Query.hasNot [ attributeIs "aria-activedescendant" "cutoff-popup-opt-540" ]
                    ]
        ]


timeRecords : Test
timeRecords =
    describe "a Time record that is not a time of day"
        [ test "setValue does not take it, and the field says so" <|
            \_ ->
                let
                    state =
                        TimePicker.init "cutoff" |> TimePicker.setValue (Just { hour = 25, minute = 0 })
                in
                allOf
                    [ Expect.equal ( Nothing, False, "25:00" ) ( TimePicker.value state, TimePicker.isValid state, TimePicker.text state )
                    , TimePicker.view identity [] state |> Query.fromHtml |> Query.has [ Selector.text "Invalid time" ]
                    ]
        , test "min and max are moved to the nearest time of day" <|
            \_ ->
                TimePicker.init "cutoff"
                    |> TimePicker.setText "23:59"
                    |> TimePicker.setLimits [ TimePicker.min { hour = -3, minute = 0 }, TimePicker.max { hour = 30, minute = 75 } ]
                    |> TimePicker.value
                    |> Expect.equal (Just { hour = 23, minute = 59 })
        , test "the date and time field does not take it either" <|
            \_ ->
                let
                    state =
                        DateTimePicker.init "pickup" |> DateTimePicker.setValue (Just { date = today, time = { hour = 8, minute = 60 } })
                in
                Expect.equal ( Nothing, Just today, False ) ( DateTimePicker.value state, DateTimePicker.date state, DateTimePicker.isValid state )
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
        , test "what backends send: a fraction of a second, a lowercase t, a space" <|
            \_ ->
                Expect.equal [ Just afternoon, Just afternoon, Just afternoon, Just afternoon ]
                    [ DateTimePicker.fromIso "2026-10-20T14:30:00.000"
                    , DateTimePicker.fromIso "2026-10-20t14:30"
                    , DateTimePicker.fromIso "2026-10-20 14:30"
                    , DateTimePicker.fromIso "2026-10-20 14:30:05.123456"
                    ]
        , test "a fraction with a zone, or no digits, is not taken" <|
            \_ ->
                Expect.equal [ Nothing, Nothing, Nothing ]
                    [ DateTimePicker.fromIso "2026-10-20T14:30:00.000Z"
                    , DateTimePicker.fromIso "2026-10-20T14:30:00."
                    , DateTimePicker.fromIso "2026-10-20X14:30"
                    ]
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
                    , DateTimePicker.fromIso "2026-10-20T14:30:60"
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


dateTimePopups : Test
dateTimePopups =
    describe "the popups of a date and time field"
        [ test "open opens the calendar of the date part, and close closes it" <|
            \_ ->
                let
                    opened =
                        DateTimePicker.open [] (DateTimePicker.init "pickup") |> Tuple.first

                    closed =
                        DateTimePicker.close opened |> Tuple.first
                in
                Expect.equal ( True, False ) ( DateTimePicker.isOpen opened, DateTimePicker.isOpen closed )
        , test "a disabled control stays closed" <|
            \_ ->
                DateTimePicker.open [ DateTimePicker.disabled True ] (DateTimePicker.init "pickup")
                    |> Tuple.first
                    |> DateTimePicker.isOpen
                    |> Expect.equal False
        , test "name gives the inputs <name>-date and <name>-time" <|
            \_ ->
                let
                    html =
                        DateTimePicker.view identity [ DateTimePicker.name "pickup" ] (DateTimePicker.init "pickup")
                            |> Query.fromHtml
                in
                allOf
                    [ html |> Query.find [ Selector.id "pickup-date" ] |> Query.has [ Selector.attribute (Attr.name "pickup-date") ]
                    , html |> Query.find [ Selector.id "pickup-time" ] |> Query.has [ Selector.attribute (Attr.name "pickup-time") ]
                    ]
        , test "visibleMonth follows the calendar of the date part" <|
            \_ ->
                DateTimePicker.init "pickup"
                    |> DateTimePicker.setDate (Just today)
                    |> DateTimePicker.open []
                    |> Tuple.first
                    |> DateTimePicker.visibleMonth
                    |> Expect.equal { year = 2026, month = 10 }
        ]


invalidAndNames : Test
invalidAndNames =
    describe "invalid, and the names of the popups"
        [ test "invalid marks the input without a message" <|
            \_ ->
                let
                    html =
                        DatePicker.view identity [ DatePicker.label "Due date", DatePicker.invalid True ] (DatePicker.init "due")
                            |> Query.fromHtml
                in
                allOf
                    [ html |> Query.find [ Selector.id "due" ] |> Query.has [ attributeIs "aria-invalid" "true" ]
                    , html |> Query.findAll [ Selector.id "due-error" ] |> Query.count (Expect.equal 0)
                    , html |> Query.findAll [ Selector.class "klar-input--invalid" ] |> Query.count (Expect.equal 1)
                    ]
        , test "invalid False leaves the input alone" <|
            \_ ->
                TimePicker.view identity [ TimePicker.invalid False ] (TimePicker.init "cutoff")
                    |> Query.fromHtml
                    |> Query.find [ Selector.id "cutoff" ]
                    |> Query.hasNot [ attributeIs "aria-invalid" "true" ]
        , test "the error of a date and time field marks both inputs, and is shown once" <|
            \_ ->
                let
                    html =
                        DateTimePicker.view identity [ DateTimePicker.label "Pick-up time", DateTimePicker.error "Choose a later time" ] (DateTimePicker.init "pickup")
                            |> Query.fromHtml
                in
                allOf
                    [ html |> Query.find [ Selector.id "pickup-date" ] |> Query.has [ attributeIs "aria-invalid" "true" ]
                    , html |> Query.find [ Selector.id "pickup-time" ] |> Query.has [ attributeIs "aria-invalid" "true" ]
                    , html |> Query.findAll [ Selector.text "Choose a later time" ] |> Query.count (Expect.equal 1)
                    ]
        , test "the calendar popup is named after the field" <|
            \_ ->
                let
                    attributes =
                        [ DatePicker.label "Due date" ]
                in
                DatePicker.open attributes (DatePicker.init "due")
                    |> Tuple.first
                    |> DatePicker.view identity attributes
                    |> Query.fromHtml
                    |> Query.find [ Selector.id "due-popup" ]
                    |> Query.has [ attributeIs "aria-label" "Due date, choose date" ]
        , test "the period popup is named after the field and described by its status line" <|
            \_ ->
                let
                    attributes =
                        [ DateRangePicker.label "Report period" ]

                    html =
                        DateRangePicker.open attributes (DateRangePicker.init "period")
                            |> Tuple.first
                            |> DateRangePicker.view identity attributes
                            |> Query.fromHtml
                in
                allOf
                    [ html |> Query.find [ Selector.id "period-popup" ] |> Query.has [ attributeIs "aria-label" "Report period, choose period", attributeIs "aria-describedby" "period-popup-status" ]
                    , html |> Query.find [ Selector.id "period-popup-status" ] |> Query.has [ Selector.text "Choose the start date" ]
                    ]
        , test "Escape in the calendar closes it and prevents its default, so an overlay leaves it alone" <|
            \_ ->
                DatePicker.open [] (DatePicker.init "due")
                    |> Tuple.first
                    |> DatePicker.view identity []
                    |> Query.fromHtml
                    |> Query.find [ Selector.class "klar-layer" ]
                    |> Event.simulate (Event.custom "keydown" (Encode.object [ ( "key", Encode.string "Escape" ) ]))
                    |> Event.expectPreventDefault
        , test "an Escape that ends an IME composition is not taken" <|
            \_ ->
                DatePicker.open [] (DatePicker.init "due")
                    |> Tuple.first
                    |> DatePicker.view identity []
                    |> Query.fromHtml
                    |> Query.find [ Selector.class "klar-layer" ]
                    |> Event.simulate (Event.custom "keydown" (Encode.object [ ( "key", Encode.string "Escape" ), ( "isComposing", Encode.bool True ) ]))
                    |> Event.toResult
                    |> Expect.err
        ]


rangeTyping : Test
rangeTyping =
    let
        attributes =
            [ DateRangePicker.today today, DateRangePicker.maxRangeDays 7 ]

        typeInto id text state =
            DateRangePicker.view identity attributes state
                |> Query.fromHtml
                |> Query.find [ Selector.id id ]
                |> Event.simulate (Event.input text)
                |> Event.toResult
                |> Result.map (\message -> Tuple.first (DateRangePicker.update message state))
                |> Result.withDefault state

        typed from to =
            DateRangePicker.init "period"
                |> typeInto "period-from" from
                |> typeInto "period-to" to

        shows message state =
            DateRangePicker.view identity attributes state
                |> Query.fromHtml
                |> Query.has [ Selector.text message ]
    in
    describe "typing a period"
        [ test "a period in order is taken while typing" <|
            \_ ->
                typed "2026-10-20" "2026-10-23"
                    |> DateRangePicker.value
                    |> Expect.equal (Just ( date 2026 10 20, date 2026 10 23 ))
        , test "a to date before the from date is refused, and the field says so" <|
            \_ ->
                let
                    state =
                        typed "2026-10-20" "2026-10-10"
                in
                allOf
                    [ Expect.equal ( Nothing, False ) ( DateRangePicker.value state, DateRangePicker.isValid state )
                    , Expect.equal ( Just (date 2026 10 20), Just (date 2026 10 10) ) ( DateRangePicker.from state, DateRangePicker.to state )
                    , shows "The start date cannot be after the end date" state
                    ]
        , test "a period longer than maxRangeDays is refused" <|
            \_ ->
                let
                    state =
                        typed "2026-10-01" "2026-10-31"
                in
                allOf
                    [ Expect.equal ( Nothing, False ) ( DateRangePicker.value state, DateRangePicker.isValid state )
                    , shows "The period cannot be longer than 7 days" state
                    ]
        , test "correcting the to date makes the period valid again" <|
            \_ ->
                typed "2026-10-20" "2026-10-10"
                    |> typeInto "period-to" "2026-10-22"
                    |> (\state -> ( DateRangePicker.value state, DateRangePicker.isValid state ))
                    |> Expect.equal ( Just ( date 2026 10 20, date 2026 10 22 ), True )
        ]


{-| A quick choice whose days are all disabled is drawn dimmed, also when it
ends on 31 December 9999 (an "until further notice" date) or later: finding its
first allowed day must end.
-}
presetAtTheEnd : Test
presetAtTheEnd =
    let
        dimmed start finish =
            DateRangePicker.open [ DateRangePicker.today today ] (DateRangePicker.init "period")
                |> Tuple.first
                |> DateRangePicker.view identity
                    [ DateRangePicker.today today
                    , DateRangePicker.disabledWhen (\_ -> True)
                    , DateRangePicker.presets [ DateRangePicker.preset "Until further notice" start finish ]
                    ]
                |> Query.fromHtml
                |> Query.find [ Selector.class "klar-daterange__preset" ]
                |> Query.has [ Selector.disabled True ]
    in
    describe "a quick choice at the end of the calendar"
        [ test "ending on 31 December 9999" <|
            \_ -> dimmed (date 9999 12 31) (date 9999 12 31)
        , test "in year 10000" <|
            \_ -> dimmed (date 10000 1 1) (date 10000 1 3)
        ]


presetKeyboard : Test
presetKeyboard =
    let
        attributes =
            [ DateRangePicker.today (date 2026 11 4) ]

        opened =
            DateRangePicker.open attributes (DateRangePicker.init "period") |> Tuple.first

        tabIndexOf label state =
            DateRangePicker.view identity attributes state
                |> Query.fromHtml
                |> Query.find [ Selector.class "klar-daterange__preset", Selector.containing [ Selector.text label ] ]

        arrowDown targetId =
            Event.custom "keydown"
                (Encode.object
                    [ ( "key", Encode.string "ArrowDown" )
                    , ( "target", Encode.object [ ( "id", Encode.string targetId ) ] )
                    ]
                )

        -- ArrowDown on the quick choice with each id in turn, each message run
        -- through update.
        arrowDowns targetIds state =
            List.foldl
                (\targetId result ->
                    Result.andThen
                        (\current ->
                            DateRangePicker.view identity attributes current
                                |> Query.fromHtml
                                |> Query.find [ Selector.class "klar-daterange__presets" ]
                                |> Event.simulate (arrowDown targetId)
                                |> Event.toResult
                                |> Result.map (\msg -> DateRangePicker.update msg current |> Tuple.first)
                        )
                        result
                )
                (Ok state)
                targetIds

        tabStops state =
            DateRangePicker.view identity attributes state
                |> Query.fromHtml
                |> Query.findAll [ Selector.class "klar-daterange__preset", Selector.attribute (Attr.tabindex 0) ]

        -- From Today, three times ArrowDown: Last 7 days, Last 30 days, This week.
        moved =
            arrowDowns [ "period-popup-preset-0", "period-popup-preset-1", "period-popup-preset-2" ] opened
    in
    describe "the quick choices have one tab stop"
        [ test "the first is in the tab order and the others are not" <|
            \_ ->
                allOf
                    [ tabIndexOf "Today" opened |> Query.has [ Selector.attribute (Attr.tabindex 0) ]
                    , tabIndexOf "Last 7 days" opened |> Query.has [ Selector.attribute (Attr.tabindex -1) ]
                    ]
        , test "after a choice, the pressed one is the tab stop" <|
            \_ ->
                let
                    chosen =
                        opened
                            |> DateRangePicker.setValue (Just ( date 2026 11 1, date 2026 11 30 ))
                            |> DateRangePicker.open attributes
                            |> Tuple.first
                in
                allOf
                    [ tabIndexOf "This month" chosen |> Query.has [ Selector.attribute (Attr.tabindex 0) ]
                    , tabIndexOf "Today" chosen |> Query.has [ Selector.attribute (Attr.tabindex -1) ]
                    ]
        , test "the tab stop follows the arrow keys: after three times ArrowDown it is This week, and only it" <|
            \_ ->
                case moved of
                    Ok state ->
                        allOf
                            [ tabIndexOf "This week" state |> Query.has [ Selector.attribute (Attr.tabindex 0) ]
                            , tabIndexOf "Today" state |> Query.has [ Selector.attribute (Attr.tabindex -1) ]
                            , tabStops state |> Query.count (Expect.equal 1)
                            ]

                    Err message ->
                        Expect.fail message
        , test "opened again, the tab stop is the first quick choice again" <|
            \_ ->
                case Result.map (DateRangePicker.open attributes >> Tuple.first) moved of
                    Ok state ->
                        allOf
                            [ tabIndexOf "Today" state |> Query.has [ Selector.attribute (Attr.tabindex 0) ]
                            , tabStops state |> Query.count (Expect.equal 1)
                            ]

                    Err message ->
                        Expect.fail message
        , test "ArrowDown on a quick choice is taken, and its default prevented" <|
            \_ ->
                DateRangePicker.view identity attributes opened
                    |> Query.fromHtml
                    |> Query.find [ Selector.class "klar-daterange__presets" ]
                    |> Event.simulate (arrowDown "period-popup-preset-0")
                    |> Event.expectPreventDefault
        , test "a key from outside the quick choices is left alone" <|
            \_ ->
                DateRangePicker.view identity attributes opened
                    |> Query.fromHtml
                    |> Query.find [ Selector.class "klar-daterange__presets" ]
                    |> Event.simulate (arrowDown "somewhere-else")
                    |> Event.toResult
                    |> Expect.err
        ]


rangeName : Test
rangeName =
    test "name gives the period's inputs <name>-from and <name>-to" <|
        \_ ->
            let
                html =
                    DateRangePicker.view identity [ DateRangePicker.name "period" ] (DateRangePicker.init "report")
                        |> Query.fromHtml
            in
            allOf
                [ html |> Query.find [ Selector.id "report-from" ] |> Query.has [ Selector.attribute (Attr.name "period-from") ]
                , html |> Query.find [ Selector.id "report-to" ] |> Query.has [ Selector.attribute (Attr.name "period-to") ]
                ]
