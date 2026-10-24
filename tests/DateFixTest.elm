module DateFixTest exposing (suite)

{-| Regression tests for the date and time fix pass:

  - `TimePicker.Time` is a plain record that the package itself defines.
  - The quick choices of `DateRangePicker` follow `min`, `max` and `disabledWhen`.
  - `DateTimePicker` links its hint and error to the group, and `required`
    reaches the inputs.
  - An untouched `Calendar` never starts on a month outside `min` and `max`.
  - The Norwegian shortcuts of the typed-input rules work in every locale.

The pickers keep their state in the application, so a test draws the view, finds a
control the way a user would, simulates the event on it, takes the message the
control sends, and gives it to `update`.

-}

import Expect exposing (Expectation)
import Html exposing (Html)
import Html.Attributes as Attr
import Klar.Calendar as Calendar
import Klar.Date as Date exposing (Date)
import Klar.DatePicker as DatePicker
import Klar.DateRangePicker as DateRangePicker
import Klar.DateTimePicker as DateTimePicker
import Klar.Locale as Locale exposing (Locale)
import Klar.TimePicker as TimePicker
import Test exposing (Test, describe, test)
import Test.Html.Event as Event
import Test.Html.Query as Query
import Test.Html.Selector as Selector exposing (Selector)


suite : Test
suite =
    describe "Date and time fixes"
        [ premises
        , timeRecord
        , quickChoices
        , rangeInputs
        , dateTimeAccessibility
        , dateTimeText
        , calendarStart
        , norwegianShortcuts
        ]


date : Int -> Int -> Int -> Date
date year month day =
    Date.fromParts year month day |> Maybe.withDefault (Date.fromEpochDay 0)


isWeekend : Date -> Bool
isWeekend day =
    Date.weekday day >= 6


attributeIs : String -> String -> Selector
attributeIs name value =
    Selector.attribute (Attr.attribute name value)


allOf : List Expectation -> Expectation
allOf expectations =
    Expect.all (List.map (\expectation _ -> expectation) expectations) ()


{-| What the tests say about the days of the week, so that a mistake in the
calendar arithmetic shows up here and not as a puzzling failure further down.
-}
premises : Test
premises =
    describe "the days of the week that the tests rely on"
        [ test "1 November 2026 is a Sunday, 4 November a Wednesday, 8 November a Sunday" <|
            \_ ->
                Expect.equal [ 7, 3, 7 ]
                    [ Date.weekday (date 2026 11 1), Date.weekday (date 2026 11 4), Date.weekday (date 2026 11 8) ]
        , test "9 November 2026 is a Monday" <|
            \_ -> Expect.equal 1 (Date.weekday (date 2026 11 9))
        , test "1 October 2026 is a Thursday, 31 October a Saturday" <|
            \_ ->
                Expect.equal [ 4, 6 ]
                    [ Date.weekday (date 2026 10 1), Date.weekday (date 2026 10 31) ]
        , test "the first and the last day of 2026 are Thursdays" <|
            \_ ->
                Expect.equal [ 4, 4 ]
                    [ Date.weekday (date 2026 1 1), Date.weekday (date 2026 12 31) ]
        ]



-- TIME RECORD


timeRecord : Test
timeRecord =
    describe "TimePicker.Time"
        [ test "a record literal is a Time" <|
            \_ ->
                let
                    start : TimePicker.Time
                    start =
                        { hour = 14, minute = 30 }
                in
                Expect.equal [ "14:30", "870" ]
                    [ TimePicker.toString start, String.fromInt (TimePicker.toMinutes start) ]
        , test "fromMinutes gives that record, also around midnight" <|
            \_ ->
                Expect.equal
                    [ { hour = 14, minute = 30 }, { hour = 1, minute = 0 }, { hour = 23, minute = 0 } ]
                    [ TimePicker.fromMinutes 870, TimePicker.fromMinutes 1500, TimePicker.fromMinutes -60 ]
        , test "the time of a time field is that record" <|
            \_ ->
                TimePicker.init "cutoff"
                    |> TimePicker.setValue (Just { hour = 8, minute = 5 })
                    |> TimePicker.value
                    |> Expect.equal (Just { hour = 8, minute = 5 })
        , test "a date and time is made of the two plain records" <|
            \_ ->
                let
                    pickup : DateTimePicker.DateTime
                    pickup =
                        { date = date 2026 10 20, time = { hour = 14, minute = 30 } }
                in
                DateTimePicker.init "pickup"
                    |> DateTimePicker.setValue (Just pickup)
                    |> DateTimePicker.value
                    |> Expect.equal (Just pickup)
        ]



-- QUICK CHOICES


type PeriodMsg
    = PickerMsg DateRangePicker.Msg


{-| The field with its popup open, for these attributes.
-}
openPeriod : List (DateRangePicker.Attribute msg) -> DateRangePicker.State
openPeriod attributes =
    DateRangePicker.init "period"
        |> DateRangePicker.open attributes
        |> Tuple.first


periodView : List (DateRangePicker.Attribute PeriodMsg) -> DateRangePicker.State -> Html PeriodMsg
periodView attributes state =
    DateRangePicker.view PickerMsg attributes state


{-| The button of the quick choice with this label.
-}
quickChoice : String -> List Selector
quickChoice label =
    [ Selector.class "klar-daterange__preset", Selector.containing [ Selector.text label ] ]


{-| Press the quick choice and read the period that the field then holds.
-}
pick : String -> List (DateRangePicker.Attribute PeriodMsg) -> Result String String
pick label attributes =
    let
        state =
            openPeriod attributes
    in
    periodView attributes state
        |> Query.fromHtml
        |> Query.find (quickChoice label)
        |> Event.simulate Event.click
        |> Event.toResult
        |> Result.map
            (\(PickerMsg message) ->
                case DateRangePicker.value (Tuple.first (DateRangePicker.update message state)) of
                    Just ( from, to ) ->
                        Date.toIso from ++ " .. " ++ Date.toIso to

                    Nothing ->
                        "no period"
            )


{-| The quick choice is there, dimmed, says why in its tooltip, and sends nothing.
-}
dimmedWith : String -> String -> List (DateRangePicker.Attribute PeriodMsg) -> Expectation
dimmedWith label reason attributes =
    allOf
        [ periodView attributes (openPeriod attributes)
            |> Query.fromHtml
            |> Query.find (quickChoice label)
            |> Query.has [ Selector.disabled True, Selector.attribute (Attr.title reason) ]
        , case pick label attributes of
            Ok _ ->
                Expect.fail ("The quick choice " ++ label ++ " sent a message, but it should be dimmed.")

            Err _ ->
                Expect.pass
        ]


notDimmed : String -> List (DateRangePicker.Attribute PeriodMsg) -> Expectation
notDimmed label attributes =
    periodView attributes (openPeriod attributes)
        |> Query.fromHtml
        |> Query.find (quickChoice label)
        |> Query.has [ Selector.disabled False ]


standardChoices : List String
standardChoices =
    [ "Today", "Last 7 days", "Last 30 days", "This week", "This month", "Last month", "This quarter", "Last quarter", "This year" ]


wednesday : Date
wednesday =
    date 2026 11 4


sunday : Date
sunday =
    date 2026 11 8


weekdaysOnly : List (DateRangePicker.Attribute msg)
weekdaysOnly =
    [ DateRangePicker.today wednesday, DateRangePicker.disabledWhen isWeekend ]


quickChoices : Test
quickChoices =
    describe "DateRangePicker quick choices"
        [ withoutDisabledDays
        , cutInward
        , cutToLimits
        , dimmedChoices
        , customChoices
        , pressedChoice
        ]


withoutDisabledDays : Test
withoutDisabledDays =
    let
        attributes =
            [ DateRangePicker.today wednesday ]
    in
    describe "without disabled days (unchanged)"
        [ test "Today" <|
            \_ -> Expect.equal (Ok "2026-11-04 .. 2026-11-04") (pick "Today" attributes)
        , test "Last 7 days" <|
            \_ -> Expect.equal (Ok "2026-10-29 .. 2026-11-04") (pick "Last 7 days" attributes)
        , test "Last 30 days" <|
            \_ -> Expect.equal (Ok "2026-10-06 .. 2026-11-04") (pick "Last 30 days" attributes)
        , test "This month" <|
            \_ -> Expect.equal (Ok "2026-11-01 .. 2026-11-30") (pick "This month" attributes)
        , test "Last month" <|
            \_ -> Expect.equal (Ok "2026-10-01 .. 2026-10-31") (pick "Last month" attributes)
        , test "This year" <|
            \_ -> Expect.equal (Ok "2026-01-01 .. 2026-12-31") (pick "This year" attributes)
        , test "This week: Monday to Sunday" <|
            \_ -> Expect.equal (Ok "2026-11-02 .. 2026-11-08") (pick "This week" attributes)
        , test "This quarter" <|
            \_ -> Expect.equal (Ok "2026-10-01 .. 2026-12-31") (pick "This quarter" attributes)
        , test "Last quarter" <|
            \_ -> Expect.equal (Ok "2026-07-01 .. 2026-09-30") (pick "Last quarter" attributes)
        , test "Last quarter in the first quarter is the last quarter of the year before" <|
            \_ -> Expect.equal (Ok "2025-10-01 .. 2025-12-31") (pick "Last quarter" [ DateRangePicker.today (date 2026 2 10) ])
        , test "the Norwegian names" <|
            \_ ->
                Expect.equal (Ok "2026-11-02 .. 2026-11-08")
                    (pick "Denne uken" [ DateRangePicker.today wednesday, DateRangePicker.locale Locale.nb ])
        , test "none of the nine is dimmed" <|
            \_ -> allOf (List.map (\label -> notDimmed label attributes) standardChoices)
        ]


cutInward : Test
cutInward =
    describe "with weekends disabled, a quick choice starts and ends on an allowed day"
        [ test "This month starts on Monday the 2nd, not on the Sunday" <|
            \_ -> Expect.equal (Ok "2026-11-02 .. 2026-11-30") (pick "This month" weekdaysOnly)
        , test "Last month ends on Friday the 30th, not on the Saturday" <|
            \_ -> Expect.equal (Ok "2026-10-01 .. 2026-10-30") (pick "Last month" weekdaysOnly)
        , test "days in between may be disabled, as in the calendar" <|
            \_ -> Expect.equal (Ok "2026-10-06 .. 2026-11-04") (pick "Last 30 days" weekdaysOnly)
        , test "a choice whose end days are allowed is not changed" <|
            \_ ->
                Expect.equal
                    [ Ok "2026-11-04 .. 2026-11-04", Ok "2026-10-29 .. 2026-11-04", Ok "2026-01-01 .. 2026-12-31" ]
                    [ pick "Today" weekdaysOnly, pick "Last 7 days" weekdaysOnly, pick "This year" weekdaysOnly ]
        , test "on a Sunday Last 7 days ends on the Friday before" <|
            \_ ->
                Expect.equal (Ok "2026-11-02 .. 2026-11-06")
                    (pick "Last 7 days" [ DateRangePicker.today sunday, DateRangePicker.disabledWhen isWeekend ])
        , test "the end days of every standard choice are days that typed input accepts" <|
            \_ ->
                let
                    accepted choice =
                        case pick choice weekdaysOnly of
                            Ok period ->
                                case String.split " .. " period of
                                    [ from, to ] ->
                                        DateRangePicker.init "period"
                                            |> DateRangePicker.setText { from = from, to = to }
                                            |> DateRangePicker.setLimits weekdaysOnly
                                            |> (not << DateRangePicker.isValid)
                                            |> not

                                    _ ->
                                        False

                            Err _ ->
                                False
                in
                Expect.equal (List.map (always True) standardChoices) (List.map accepted standardChoices)
        , test "typed input does reject a weekend end day (what the cut avoids)" <|
            \_ ->
                DateRangePicker.init "period"
                    |> DateRangePicker.setText { from = "2026-11-01", to = "2026-11-30" }
                    |> DateRangePicker.setLimits weekdaysOnly
                    |> (not << DateRangePicker.isValid)
                    |> Expect.equal True
        ]


cutToLimits : Test
cutToLimits =
    describe "min and max"
        [ test "max cuts a choice at the end, and the Sunday at the start still goes" <|
            \_ ->
                Expect.equal (Ok "2026-11-02 .. 2026-11-04")
                    (pick "This month" (DateRangePicker.max wednesday :: weekdaysOnly))
        , test "min cuts a choice at the start" <|
            \_ ->
                Expect.equal (Ok "2026-11-03 .. 2026-11-04")
                    (pick "Last 7 days" (DateRangePicker.min (date 2026 11 3) :: weekdaysOnly))
        , test "a limit on a disabled day moves inward too" <|
            \_ ->
                Expect.equal (Ok "2026-11-02 .. 2026-11-30")
                    (pick "This month" (DateRangePicker.min (date 2026 11 1) :: weekdaysOnly))
        , test "a choice that ends before min is dimmed and names the limit" <|
            \_ ->
                dimmedWith "Last month" "The date cannot be before 2026-11-03" (DateRangePicker.min (date 2026 11 3) :: weekdaysOnly)
        , test "a choice that starts after max is dimmed and names the limit" <|
            \_ ->
                dimmedWith "This month" "The date cannot be after 2026-10-15" (DateRangePicker.max (date 2026 10 15) :: weekdaysOnly)
        , test "the reason is in the language of the field" <|
            \_ ->
                dimmedWith "I dag"
                    "Datoen er ikke tilgjengelig"
                    [ DateRangePicker.locale Locale.nb, DateRangePicker.today sunday, DateRangePicker.disabledWhen isWeekend ]
        ]


dimmedChoices : Test
dimmedChoices =
    describe "dimmed quick choices"
        [ test "Today on a disabled day: nothing is left to choose" <|
            \_ ->
                dimmedWith "Today"
                    "The date is not available"
                    [ DateRangePicker.today sunday, DateRangePicker.disabledWhen isWeekend ]
        , test "every day disabled: all nine are dimmed" <|
            \_ ->
                let
                    attributes =
                        [ DateRangePicker.today wednesday, DateRangePicker.disabledWhen (always True) ]
                in
                allOf (List.map (\label -> dimmedWith label "The date is not available" attributes) standardChoices)
        , test "longer than maxRangeDays: dimmed, with the limit as the reason" <|
            \_ ->
                dimmedWith "Last 30 days"
                    "The period cannot be longer than 20 days"
                    [ DateRangePicker.today wednesday, DateRangePicker.maxRangeDays 20 ]
        , test "short enough for maxRangeDays: usable" <|
            \_ ->
                Expect.equal (Ok "2026-10-29 .. 2026-11-04")
                    (pick "Last 7 days" [ DateRangePicker.today wednesday, DateRangePicker.maxRangeDays 20 ])
        , test "the length counts after the cut inward" <|
            \_ ->
                -- 1 to 9 November is nine days; from Monday the 2nd it is eight.
                let
                    sprint =
                        DateRangePicker.preset "Sprint" (date 2026 11 1) (date 2026 11 9)

                    within limit =
                        [ DateRangePicker.presets [ sprint ]
                        , DateRangePicker.maxRangeDays limit
                        , DateRangePicker.disabledWhen isWeekend
                        ]
                in
                allOf
                    [ dimmedWith "Sprint" "The period cannot be longer than 7 days" (within 7)
                    , Expect.equal (Ok "2026-11-02 .. 2026-11-09") (pick "Sprint" (within 8))
                    ]
        , test "without today there are no standard quick choices" <|
            \_ ->
                periodView [] (openPeriod [])
                    |> Query.fromHtml
                    |> Query.findAll [ Selector.class "klar-daterange__preset" ]
                    |> Query.count (Expect.equal 0)
        ]


customChoices : Test
customChoices =
    let
        sprint =
            DateRangePicker.preset "Sprint" (date 2026 11 1) (date 2026 11 9)
    in
    describe "custom quick choices"
        [ test "they are offered without today and follow the same rules" <|
            \_ ->
                Expect.equal (Ok "2026-11-02 .. 2026-11-09")
                    (pick "Sprint" [ DateRangePicker.presets [ sprint ], DateRangePicker.disabledWhen isWeekend ])
        , test "without disabled days they keep their days" <|
            \_ ->
                Expect.equal (Ok "2026-11-01 .. 2026-11-09")
                    (pick "Sprint" [ DateRangePicker.presets [ sprint ] ])
        , test "preset puts the two days in order" <|
            \_ ->
                Expect.equal sprint (DateRangePicker.preset "Sprint" (date 2026 11 9) (date 2026 11 1))
        , test "a preset made with the days the wrong way round is read in order" <|
            \_ ->
                Expect.equal (Ok "2026-11-02 .. 2026-11-09")
                    (pick "Reversed" [ DateRangePicker.presets [ DateRangePicker.preset "Reversed" (date 2026 11 9) (date 2026 11 2) ] ])
        , test "noPresets draws no list" <|
            \_ ->
                let
                    attributes =
                        [ DateRangePicker.today wednesday, DateRangePicker.noPresets ]
                in
                periodView attributes (openPeriod attributes)
                    |> Query.fromHtml
                    |> Query.findAll [ Selector.class "klar-daterange__preset" ]
                    |> Query.count (Expect.equal 0)
        ]


pressedChoice : Test
pressedChoice =
    test "a quick choice that was cut shows as pressed while its period is the chosen one" <|
        \_ ->
            let
                state =
                    openPeriod weekdaysOnly

                chosen =
                    periodView weekdaysOnly state
                        |> Query.fromHtml
                        |> Query.find (quickChoice "This month")
                        |> Event.simulate Event.click
                        |> Event.toResult
            in
            case chosen of
                Ok (PickerMsg message) ->
                    let
                        reopened =
                            Tuple.first (DateRangePicker.update message state)
                                |> DateRangePicker.open weekdaysOnly
                                |> Tuple.first

                        reopenedView =
                            periodView weekdaysOnly reopened
                                |> Query.fromHtml
                    in
                    allOf
                        [ reopenedView |> Query.find (quickChoice "This month") |> Query.has [ attributeIs "aria-pressed" "true" ]
                        , reopenedView |> Query.find (quickChoice "Last month") |> Query.has [ attributeIs "aria-pressed" "false" ]
                        ]

                Err problem ->
                    Expect.fail problem



-- DATE AND TIME: ACCESSIBILITY


pickupView : List (DateTimePicker.Attribute DateTimePicker.Msg) -> Query.Single DateTimePicker.Msg
pickupView attributes =
    DateTimePicker.view identity attributes (DateTimePicker.init "pickup")
        |> Query.fromHtml


group : Query.Single msg -> Query.Single msg
group =
    Query.find [ attributeIs "role" "group" ]


dateTimeAccessibility : Test
dateTimeAccessibility =
    describe "DateTimePicker hint, error and required"
        [ test "required puts aria-required on the date input and on the time input" <|
            \_ ->
                let
                    view =
                        pickupView [ DateTimePicker.label "Pick-up time", DateTimePicker.required ]
                in
                allOf
                    [ view |> Query.find [ Selector.id "pickup-date" ] |> Query.has [ attributeIs "aria-required" "true" ]
                    , view |> Query.find [ Selector.id "pickup-time" ] |> Query.has [ attributeIs "aria-required" "true" ]
                    ]
        , test "required still draws the asterisk of the label" <|
            \_ ->
                pickupView [ DateTimePicker.label "Pick-up time", DateTimePicker.required ]
                    |> Query.find [ Selector.id "pickup-label" ]
                    |> Query.has [ Selector.text "*" ]
        , test "without required the inputs are not aria-required" <|
            \_ ->
                let
                    view =
                        pickupView [ DateTimePicker.label "Pick-up time" ]
                in
                allOf
                    [ view |> Query.find [ Selector.id "pickup-date" ] |> Query.hasNot [ attributeIs "aria-required" "true" ]
                    , view |> Query.find [ Selector.id "pickup-time" ] |> Query.hasNot [ attributeIs "aria-required" "true" ]
                    ]
        , test "the hint describes the group, and the hint element has that id" <|
            \_ ->
                let
                    view =
                        pickupView [ DateTimePicker.label "Pick-up time", DateTimePicker.hint "Weekdays only" ]
                in
                allOf
                    [ view |> group |> Query.has [ attributeIs "aria-describedby" "pickup-hint" ]
                    , view |> Query.find [ Selector.id "pickup-hint" ] |> Query.has [ Selector.text "Weekdays only" ]
                    ]
        , test "the error describes the group, and the error element is an alert with that id" <|
            \_ ->
                let
                    view =
                        pickupView [ DateTimePicker.label "Pick-up time", DateTimePicker.error "Choose a pick-up time" ]
                in
                allOf
                    [ view |> group |> Query.has [ attributeIs "aria-describedby" "pickup-error" ]
                    , view
                        |> Query.find [ Selector.id "pickup-error" ]
                        |> Query.has [ attributeIs "role" "alert", Selector.text "Choose a pick-up time" ]
                    ]
        , test "hint and error together: the hint first, as in Klar.Field" <|
            \_ ->
                pickupView
                    [ DateTimePicker.label "Pick-up time"
                    , DateTimePicker.hint "Weekdays only"
                    , DateTimePicker.error "Choose a pick-up time"
                    ]
                    |> group
                    |> Query.has [ attributeIs "aria-describedby" "pickup-hint pickup-error" ]
        , test "errorMaybe Nothing leaves no error and no link to it" <|
            \_ ->
                let
                    view =
                        pickupView
                            [ DateTimePicker.label "Pick-up time"
                            , DateTimePicker.hint "Weekdays only"
                            , DateTimePicker.errorMaybe Nothing
                            ]
                in
                allOf
                    [ view |> group |> Query.has [ attributeIs "aria-describedby" "pickup-hint" ]
                    , view |> Query.findAll [ Selector.id "pickup-error" ] |> Query.count (Expect.equal 0)
                    ]
        , test "with neither a hint nor an error the group describes nothing" <|
            \_ ->
                let
                    view =
                        pickupView [ DateTimePicker.label "Pick-up time" ]
                in
                allOf
                    (List.map
                        (\ids -> view |> group |> Query.hasNot [ attributeIs "aria-describedby" ids ])
                        [ "pickup-hint", "pickup-error", "pickup-hint pickup-error", "" ]
                    )
        , test "the group is still named by the label" <|
            \_ ->
                pickupView [ DateTimePicker.label "Pick-up time", DateTimePicker.hint "Weekdays only" ]
                    |> group
                    |> Query.has [ attributeIs "aria-labelledby" "pickup-label" ]
        , test "without a label the hint still describes the group" <|
            \_ ->
                pickupView [ DateTimePicker.hint "Weekdays only" ]
                    |> group
                    |> Query.has [ attributeIs "aria-describedby" "pickup-hint" ]
        ]



-- DATE AND TIME: TEXT, SETTEXT, VALIDATE


{-| The control drawn for this state: the query to look into it.
-}
pickupFor : List (DateTimePicker.Attribute DateTimePicker.Msg) -> DateTimePicker.State -> Query.Single DateTimePicker.Msg
pickupFor attributes state =
    DateTimePicker.view identity attributes state
        |> Query.fromHtml


noText : { date : String, time : String }
noText =
    { date = "", time = "" }


dateTimeText : Test
dateTimeText =
    let
        today =
            date 2026 10 20

        attributes =
            [ DateTimePicker.today today
            , DateTimePicker.minTime { hour = 8, minute = 0 }
            , DateTimePicker.maxTime { hour = 16, minute = 0 }
            ]

        typed texts =
            DateTimePicker.init "pickup" |> DateTimePicker.setText texts

        read texts =
            typed texts |> DateTimePicker.setLimits attributes

        afternoon =
            { date = today, time = { hour = 14, minute = 30 } }
    in
    describe "DateTimePicker text, setText and validate"
        [ test "a new control has no text" <|
            \_ -> Expect.equal noText (DateTimePicker.text (DateTimePicker.init "pickup"))
        , test "setText fills both inputs, and text gives the same back" <|
            \_ ->
                Expect.equal { date = "2026-10-20", time = "14:30" }
                    (DateTimePicker.text (typed { date = "2026-10-20", time = "14:30" }))
        , test "setText only fills the inputs: dateTime keeps its old value until the text is read" <|
            \_ ->
                Expect.equal [ Nothing, Just afternoon ]
                    [ DateTimePicker.value (typed { date = "2026-10-20", time = "14:30" })
                    , DateTimePicker.init "pickup"
                        |> DateTimePicker.setValue (Just afternoon)
                        |> DateTimePicker.setText { date = "2026-10-21", time = "15:00" }
                        |> DateTimePicker.value
                    ]
        , test "validate reads both texts" <|
            \_ ->
                Expect.equal ( Just afternoon, False )
                    (let
                        state =
                            read { date = "2026-10-20", time = "14:30" }
                     in
                     ( DateTimePicker.value state, (not << DateTimePicker.isValid) state )
                    )
        , test "validate reads the short forms like the fields do (today, a time without a colon)" <|
            \_ ->
                Expect.equal (Just { date = today, time = { hour = 9, minute = 30 } })
                    (DateTimePicker.value (read { date = "t", time = "930" }))
        , test "what is read is no longer pending text" <|
            \_ ->
                Expect.equal noText (DateTimePicker.text (read { date = "20.10.2026", time = "1430" }))
        , test "the inputs then show the formatted values" <|
            \_ ->
                let
                    view =
                        pickupFor attributes (read { date = "20.10.2026", time = "1430" })
                in
                allOf
                    [ view |> Query.find [ Selector.id "pickup-date" ] |> Query.has [ Selector.attribute (Attr.value "2026-10-20") ]
                    , view |> Query.find [ Selector.id "pickup-time" ] |> Query.has [ Selector.attribute (Attr.value "14:30") ]
                    ]
        , test "the locale of the control formats the date" <|
            \_ ->
                let
                    norwegian =
                        DateTimePicker.locale Locale.nb :: attributes
                in
                pickupFor norwegian (typed { date = "2026-10-20", time = "14:30" } |> DateTimePicker.setLimits norwegian)
                    |> Query.find [ Selector.id "pickup-date" ]
                    |> Query.has [ Selector.attribute (Attr.value "20.10.2026") ]
        , test "a date that is not a date: invalid, no value, the text stays and the date field says so" <|
            \_ ->
                let
                    state =
                        read { date = "garbage", time = "14:30" }
                in
                allOf
                    [ Expect.equal ( True, Nothing ) ( (not << DateTimePicker.isValid) state, DateTimePicker.value state )
                    , Expect.equal { date = "garbage", time = "" } (DateTimePicker.text state)
                    , pickupFor attributes state |> Query.has [ Selector.text "Invalid date" ]
                    ]
        , test "a time that is not a time: invalid, the text stays and the time field says so" <|
            \_ ->
                let
                    state =
                        read { date = "2026-10-20", time = "25:00" }
                in
                allOf
                    [ Expect.equal ( True, Nothing ) ( (not << DateTimePicker.isValid) state, DateTimePicker.value state )
                    , Expect.equal { date = "", time = "25:00" } (DateTimePicker.text state)
                    , pickupFor attributes state |> Query.has [ Selector.text "Invalid time" ]
                    ]
        , test "the time limits count" <|
            \_ ->
                let
                    early =
                        read { date = "2026-10-20", time = "07:30" }

                    late =
                        read { date = "2026-10-20", time = "16:30" }
                in
                allOf
                    [ Expect.equal [ True, True ] [ (not << DateTimePicker.isValid) early, (not << DateTimePicker.isValid) late ]
                    , pickupFor attributes early |> Query.has [ Selector.text "The time cannot be before 08:00" ]
                    , pickupFor attributes late |> Query.has [ Selector.text "The time cannot be after 16:00" ]
                    ]
        , test "the date limits count: min, max and disabledWhen" <|
            \_ ->
                let
                    limited =
                        [ DateTimePicker.min (date 2026 10 1)
                        , DateTimePicker.max (date 2026 10 31)
                        , DateTimePicker.disabledWhen isWeekend
                        ]

                    invalid text =
                        typed { date = text, time = "10:00" }
                            |> DateTimePicker.setLimits limited
                            |> (not << DateTimePicker.isValid)
                in
                Expect.equal [ True, True, True, False ]
                    [ invalid "2026-09-30", invalid "2026-11-01", invalid "2026-10-31", invalid "2026-10-30" ]
        , test "validate reads by the attributes it is given: today makes t a date" <|
            \_ ->
                let
                    state =
                        typed { date = "t", time = "10:00" }
                in
                Expect.equal [ True, False ]
                    [ (not << DateTimePicker.isValid) (DateTimePicker.setLimits [] state)
                    , (not << DateTimePicker.isValid) (DateTimePicker.setLimits [ DateTimePicker.today today ] state)
                    ]
        , test "a part without pending text is left as it is" <|
            \_ ->
                DateTimePicker.init "pickup"
                    |> DateTimePicker.setValue (Just afternoon)
                    |> DateTimePicker.setLimits attributes
                    |> DateTimePicker.value
                    |> Expect.equal (Just afternoon)
        , test "validate on an empty control leaves it empty and valid" <|
            \_ ->
                let
                    state =
                        DateTimePicker.setLimits attributes (DateTimePicker.init "pickup")
                in
                Expect.equal ( Nothing, False, noText )
                    ( DateTimePicker.value state, (not << DateTimePicker.isValid) state, DateTimePicker.text state )
        , test "blank texts empty the control" <|
            \_ ->
                DateTimePicker.init "pickup"
                    |> DateTimePicker.setValue (Just afternoon)
                    |> DateTimePicker.setText { date = "", time = "" }
                    |> DateTimePicker.setLimits attributes
                    |> DateTimePicker.value
                    |> Expect.equal Nothing
        , test "the date part is read even when the time part is not, and the other way round" <|
            \_ ->
                let
                    state =
                        read { date = "2026-10-20", time = "nonsense" }
                in
                Expect.equal ( Nothing, True, { date = "", time = "nonsense" } )
                    ( DateTimePicker.value state, (not << DateTimePicker.isValid) state, DateTimePicker.text state )
        ]



-- DATE RANGE: THE INPUTS


periodFor : List (DateRangePicker.Attribute PeriodMsg) -> Query.Single PeriodMsg
periodFor attributes =
    DateRangePicker.view PickerMsg attributes (DateRangePicker.init "period")
        |> Query.fromHtml


periodInput : String -> Query.Single msg -> Query.Single msg
periodInput side =
    Query.find [ Selector.id ("period-" ++ side) ]


rangeInputs : Test
rangeInputs =
    let
        described =
            [ DateRangePicker.label "Report period"
            , DateRangePicker.hint "Up to 90 days"
            , DateRangePicker.error "Choose a period"
            , DateRangePicker.required
            ]
    in
    describe "DateRangePicker inputs"
        [ test "the two inputs have the ids <id>-from and <id>-to" <|
            \_ ->
                let
                    view =
                        periodFor [ DateRangePicker.label "Report period" ]
                in
                allOf
                    [ view |> periodInput "from" |> Query.has [ Selector.tag "input" ]
                    , view |> periodInput "to" |> Query.has [ Selector.tag "input" ]
                    , view |> Query.findAll [ Selector.tag "input" ] |> Query.count (Expect.equal 2)
                    ]
        , test "the second input is described by the hint and the error of the field" <|
            \_ ->
                let
                    view =
                        periodFor described
                in
                allOf
                    [ view |> periodInput "from" |> Query.has [ attributeIs "aria-describedby" "period-from-hint period-from-error" ]
                    , view |> periodInput "to" |> Query.has [ attributeIs "aria-describedby" "period-from-hint period-from-error" ]
                    , view |> Query.find [ Selector.id "period-from-hint" ] |> Query.has [ Selector.text "Up to 90 days" ]
                    , view
                        |> Query.find [ Selector.id "period-from-error" ]
                        |> Query.has [ attributeIs "role" "alert", Selector.text "Choose a period" ]
                    ]
        , test "no element has an id that the second input would have made up" <|
            \_ ->
                periodFor described
                    |> Query.findAll [ Selector.id "period-to-hint" ]
                    |> Query.count (Expect.equal 0)
        , test "both inputs are invalid while the field has an error, and both are required" <|
            \_ ->
                let
                    view =
                        periodFor described
                in
                allOf
                    (List.concatMap
                        (\side ->
                            [ view |> periodInput side |> Query.has [ attributeIs "aria-invalid" "true" ]
                            , view |> periodInput side |> Query.has [ attributeIs "aria-required" "true" ]
                            ]
                        )
                        [ "from", "to" ]
                    )
        , test "without a hint, an error or required they say none of it" <|
            \_ ->
                let
                    view =
                        periodFor [ DateRangePicker.label "Report period" ]
                in
                allOf
                    (List.concatMap
                        (\side ->
                            [ view |> periodInput side |> Query.hasNot [ attributeIs "aria-invalid" "true" ]
                            , view |> periodInput side |> Query.hasNot [ attributeIs "aria-required" "true" ]
                            , view |> periodInput side |> Query.hasNot [ attributeIs "aria-describedby" "period-from-hint" ]
                            , view |> periodInput side |> Query.hasNot [ attributeIs "aria-describedby" "period-from-error" ]
                            ]
                        )
                        [ "from", "to" ]
                    )
        , test "the accessible name of each input says which date it is" <|
            \_ ->
                let
                    view =
                        periodFor [ DateRangePicker.label "Report period" ]
                in
                allOf
                    [ view |> periodInput "from" |> Query.has [ attributeIs "aria-label" "Report period, from date" ]
                    , view |> periodInput "to" |> Query.has [ attributeIs "aria-label" "Report period, to date" ]
                    ]
        ]



-- CALENDAR START


monthTitle : String -> Int -> String
monthTitle name year =
    -- the heading has a no-break space between the month and the year
    name ++ "\u{00A0}" ++ String.fromInt year


{-| The heading of the first month that the calendar shows.
-}
firstHeading : Html msg -> Query.Single msg
firstHeading html =
    html
        |> Query.fromHtml
        |> Query.findAll [ Selector.class "klar-calendar__title" ]
        |> Query.first


expectShows : String -> Int -> Html msg -> Expectation
expectShows name year html =
    firstHeading html |> Query.has [ Selector.text (monthTitle name year) ]


calendarView : List Calendar.Attribute -> Calendar.State -> Html Calendar.Msg
calendarView attributes state =
    Calendar.view identity attributes state


{-| Press the button with this accessible name, and give the message to `update`.
-}
pressNav : String -> List Calendar.Attribute -> Calendar.State -> Result String Calendar.State
pressNav label attributes state =
    calendarView attributes state
        |> Query.fromHtml
        |> Query.find [ attributeIs "aria-label" label ]
        |> Event.simulate Event.click
        |> Event.toResult
        |> Result.map (\message -> Tuple.first (Calendar.update message state))


calendarStart : Test
calendarStart =
    describe "the month that an untouched Calendar shows"
        [ test "no limits and no today: January 2000, as before" <|
            \_ -> expectShows "January" 2000 (calendarView [] (Calendar.init "c"))
        , test "today and no limits: the month of today, as before" <|
            \_ -> expectShows "October" 2026 (calendarView [ Calendar.today (date 2026 10 20) ] (Calendar.init "c"))
        , test "today inside the limits: the month of today, as before" <|
            \_ ->
                expectShows "October"
                    2026
                    (calendarView
                        [ Calendar.today (date 2026 10 20), Calendar.min (date 2026 1 1), Calendar.max (date 2026 12 31) ]
                        (Calendar.init "c")
                    )
        , test "no today and min after the placeholder: the month of min" <|
            \_ -> expectShows "March" 2026 (calendarView [ Calendar.min (date 2026 3 10) ] (Calendar.init "c"))
        , test "no today and max before the placeholder: the month of max" <|
            \_ -> expectShows "December" 1999 (calendarView [ Calendar.max (date 1999 12 31) ] (Calendar.init "c"))
        , test "no today and the placeholder inside the limits: January 2000" <|
            \_ ->
                expectShows "January"
                    2000
                    (calendarView [ Calendar.min (date 1990 1 1), Calendar.max (date 2010 1 1) ] (Calendar.init "c"))
        , test "today before min: the month of min" <|
            \_ ->
                expectShows "December"
                    2026
                    (calendarView [ Calendar.today (date 2026 10 20), Calendar.min (date 2026 12 1) ] (Calendar.init "c"))
        , test "today after max: the month of max" <|
            \_ ->
                expectShows "August"
                    2026
                    (calendarView [ Calendar.today (date 2026 10 20), Calendar.max (date 2026 8 15) ] (Calendar.init "c"))
        , test "a range calendar starts there too" <|
            \_ ->
                expectShows "March"
                    2026
                    (calendarView [ Calendar.min (date 2026 3 10), Calendar.months 2 ] (Calendar.initRange "c"))
        , test "the first message keeps that month: next goes one month on" <|
            \_ ->
                let
                    attributes =
                        [ Calendar.min (date 2026 3 10) ]
                in
                Calendar.init "c"
                    |> pressNav "Next month" attributes
                    |> Result.map (calendarView attributes)
                    |> Result.map (expectShows "April" 2026)
                    |> Result.withDefault (Expect.fail "The next button did not send a message.")
        , test "the first message keeps that month: previous goes one month back from max" <|
            \_ ->
                let
                    attributes =
                        [ Calendar.max (date 1999 12 31) ]
                in
                Calendar.init "c"
                    |> pressNav "Previous month" attributes
                    |> Result.map (calendarView attributes)
                    |> Result.map (expectShows "November" 1999)
                    |> Result.withDefault (Expect.fail "The previous button did not send a message.")
        , test "the month before min cannot be reached" <|
            \_ ->
                calendarView [ Calendar.min (date 2026 3 10) ] (Calendar.init "c")
                    |> Query.fromHtml
                    |> Query.find [ attributeIs "aria-label" "Previous month" ]
                    |> Query.has [ attributeIs "aria-disabled" "true" ]
        , test "showDate is explicit and is not moved into the limits" <|
            \_ ->
                expectShows "May"
                    2020
                    (calendarView [ Calendar.min (date 2026 3 10) ]
                        (Calendar.showDate (date 2020 5 5) (Calendar.init "c"))
                    )
        , test "a date field with min and no today opens on the month of min" <|
            \_ ->
                let
                    attributes =
                        [ DatePicker.min (date 2026 3 10) ]
                in
                DatePicker.init "due"
                    |> DatePicker.open attributes
                    |> Tuple.first
                    |> DatePicker.view identity attributes
                    |> expectShows "March" 2026
        , test "a period field with max and no today opens on the month of max" <|
            \_ ->
                let
                    attributes =
                        [ DateRangePicker.max (date 1999 12 31) ]
                in
                openPeriod attributes
                    |> periodView attributes
                    |> expectShows "December" 1999
        ]



-- NORWEGIAN SHORTCUTS


readDate : List (DatePicker.Attribute msg) -> String -> Maybe Date
readDate attributes text =
    DatePicker.init "d"
        |> DatePicker.setText text
        |> DatePicker.setLimits attributes
        |> DatePicker.value


readTime : List (TimePicker.Attribute msg) -> String -> Maybe TimePicker.Time
readTime attributes text =
    TimePicker.init "t"
        |> TimePicker.setText text
        |> TimePicker.setLimits attributes
        |> TimePicker.value


norwegianShortcuts : Test
norwegianShortcuts =
    let
        today =
            date 2026 10 20
    in
    describe "the Norwegian shortcuts work in every locale"
        [ test "i dag and idag mean today in an English field" <|
            \_ ->
                Expect.equal
                    [ Just today, Just today, Just today, Just today ]
                    (List.map (readDate [ DatePicker.today today ]) [ "i dag", "idag", "I dag", "today" ])
        , test "today and t mean today in a Norwegian field, and so do the Norwegian words" <|
            \_ ->
                Expect.equal
                    [ Just today, Just today, Just today, Just today ]
                    (List.map (readDate [ DatePicker.today today, DatePicker.locale Locale.nb ]) [ "today", "t", "i dag", "idag" ])
        , test "they need today, like t" <|
            \_ ->
                Expect.equal [ Nothing, Nothing, Nothing ]
                    (List.map (readDate []) [ "i dag", "idag", "t" ])
        , test "kl before a time is ignored in an English field" <|
            \_ ->
                Expect.equal
                    [ Just { hour = 14, minute = 30 }, Just { hour = 14, minute = 30 }, Just { hour = 9, minute = 0 } ]
                    (List.map (readTime []) [ "kl 14:30", "kl. 14.30", "kl 9" ])
        , test "kl before a time is ignored in a Norwegian field" <|
            \_ ->
                Expect.equal (Just { hour = 14, minute = 30 })
                    (readTime [ TimePicker.locale Locale.nb ] "kl 14:30")
        , test "the English forms work in a Norwegian field and the other way round" <|
            \_ ->
                Expect.equal
                    [ Just today, Just today, Just today, Just today ]
                    [ readDate [ DatePicker.locale Locale.nb ] "2026-10-20"
                    , readDate [ DatePicker.locale Locale.en ] "20.10.2026"
                    , readDate [ DatePicker.locale Locale.nb ] "20/10/2026"
                    , readDate [ DatePicker.locale Locale.en ] "20/10/2026"
                    ]
        ]
