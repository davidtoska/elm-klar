module Page.Gallery.DateTime exposing (Model, Msg, init, subscriptions, update, view)

{-| Gallery page: the calendar and the date, period, time and date-and-time
fields.

"Today" is `Showcase.Sample.today` on the whole page. Every field keeps its state
in a `Dict` under the key of its demo (see `demoDates` and the lists after it).
The calendar that loads its marks for the visible month asks a pretend server
(`Process.sleep` and a pure function), so it can show loading, failure and old marks.

-}

import Api.Types exposing (orderIdText, orderStatusLabel)
import Dict exposing (Dict)
import Html exposing (Html)
import Klar.Badge as Badge
import Klar.Button as Button
import Klar.Calendar as Calendar
import Klar.Card as Card
import Klar.Date as Date exposing (Date)
import Klar.DatePicker as DatePicker
import Klar.DateRangePicker as DateRangePicker
import Klar.DateTimePicker as DateTimePicker
import Klar.Format as Format
import Klar.Icon as Icon
import Klar.Layout as Layout
import Klar.Locale as Locale exposing (Locale)
import Klar.Remote as Remote exposing (Remote)
import Klar.Switch as Switch
import Klar.Text as Text
import Klar.Theme exposing (Size(..), Tone(..))
import Klar.TimePicker as TimePicker
import Process
import Showcase.Doc as Doc
import Showcase.Sample as Sample
import Task
import Time
import View.Labels as Labels



-- MODEL


type alias Model =
    { overview : Calendar.State
    , compact : Calendar.State
    , period : Calendar.State
    , norwegian : Calendar.State
    , orders : Calendar.State
    , schedule : Calendar.State
    , due : Remote (List ( Date, Int ))
    , outage : Bool
    , dates : Dict String DatePicker.State
    , ranges : Dict String DateRangePicker.State
    , times : Dict String TimePicker.State
    , dateTimes : Dict String DateTimePicker.State
    }


type Msg
    = OverviewMsg Calendar.Msg
    | CompactMsg Calendar.Msg
    | PeriodMsg Calendar.Msg
    | NorwegianMsg Calendar.Msg
    | OrdersMsg Calendar.Msg
    | ScheduleMsg Calendar.Msg
    | DueArrived Window (Result Remote.Kind (List ( Date, Int ))) Time.Posix
    | DueRetry
    | DueRefresh
    | OutageToggled Bool
    | DateMsg String DatePicker.Msg
    | RangeMsg String DateRangePicker.Msg
    | TimeMsg String TimePicker.Msg
    | DateTimeMsg String DateTimePicker.Msg


init : ( Model, Cmd Msg )
init =
    ( { overview = Calendar.init "cal-overview" |> Calendar.setValue (Just today)
      , compact = Calendar.init "cal-small"
      , period = Calendar.initRange "cal-period" |> Calendar.setMonths 2
      , norwegian = Calendar.init "cal-norwegian"
      , orders = Calendar.init "cal-orders" |> Calendar.setMonths 2
      , schedule = Calendar.init "cal-schedule" |> Calendar.showDate today
      , due = Remote.Loading
      , outage = False
      , dates = registry DatePicker.init demoDates
      , ranges = registry DateRangePicker.init demoRanges
      , times = registry TimePicker.init demoTimes
      , dateTimes = registry DateTimePicker.init demoDateTimes
      }
    , fetchDue False (Calendar.visibleRange (Calendar.init "cal-schedule" |> Calendar.showDate today))
    )


{-| One state per demo, started from its `prepare`.
-}
registry : (String -> state) -> List { a | key : String, prepare : state -> state } -> Dict String state
registry start demos =
    demos
        |> List.map (\demo -> ( demo.key, demo.prepare (start demo.key) ))
        |> Dict.fromList


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        OverviewMsg inner ->
            calendarStep OverviewMsg inner model.overview (\state -> { model | overview = state })

        CompactMsg inner ->
            calendarStep CompactMsg inner model.compact (\state -> { model | compact = state })

        PeriodMsg inner ->
            calendarStep PeriodMsg inner model.period (\state -> { model | period = state })

        NorwegianMsg inner ->
            calendarStep NorwegianMsg inner model.norwegian (\state -> { model | norwegian = state })

        OrdersMsg inner ->
            calendarStep OrdersMsg inner model.orders (\state -> { model | orders = state })

        ScheduleMsg inner ->
            let
                ( schedule, cmd ) =
                    Calendar.update inner model.schedule

                shown =
                    Calendar.visibleRange schedule
            in
            -- the calendar says which days it shows: ask for their marks when that changes
            if shown /= Calendar.visibleRange model.schedule then
                ( { model | schedule = schedule, due = Remote.Loading }
                , Cmd.batch [ Cmd.map ScheduleMsg cmd, fetchDue model.outage shown ]
                )

            else
                ( { model | schedule = schedule }, Cmd.map ScheduleMsg cmd )

        DueArrived window result at ->
            -- an answer for days that are no longer shown is dropped
            if window == Calendar.visibleRange model.schedule then
                ( { model | due = Remote.refreshWith model.due (Result.mapError Remote.problem result) at }, Cmd.none )

            else
                ( model, Cmd.none )

        DueRetry ->
            -- the button goes away while the marks load: the focus goes back to the calendar
            ( { model | due = Remote.refresh model.due }
            , Cmd.batch
                [ fetchDue model.outage (Calendar.visibleRange model.schedule)
                , Cmd.map ScheduleMsg (Calendar.focus model.schedule)
                ]
            )

        DueRefresh ->
            ( { model | due = Remote.refresh model.due }, fetchDue model.outage (Calendar.visibleRange model.schedule) )

        OutageToggled value ->
            ( { model | outage = value }, Cmd.none )

        DateMsg key inner ->
            let
                ( state, cmd ) =
                    DatePicker.update inner (lookup DatePicker.init key model.dates)
            in
            ( { model | dates = Dict.insert key state model.dates }, Cmd.map (DateMsg key) cmd )

        RangeMsg key inner ->
            let
                ( state, cmd ) =
                    DateRangePicker.update inner (lookup DateRangePicker.init key model.ranges)
            in
            ( { model | ranges = Dict.insert key state model.ranges }, Cmd.map (RangeMsg key) cmd )

        TimeMsg key inner ->
            let
                ( state, cmd ) =
                    TimePicker.update inner (lookup TimePicker.init key model.times)
            in
            ( { model | times = Dict.insert key state model.times }, Cmd.map (TimeMsg key) cmd )

        DateTimeMsg key inner ->
            let
                ( state, cmd ) =
                    DateTimePicker.update inner (lookup DateTimePicker.init key model.dateTimes)
            in
            ( { model | dateTimes = Dict.insert key state model.dateTimes }, Cmd.map (DateTimeMsg key) cmd )


calendarStep : (Calendar.Msg -> Msg) -> Calendar.Msg -> Calendar.State -> (Calendar.State -> Model) -> ( Model, Cmd Msg )
calendarStep toMsg inner state store =
    let
        ( next, cmd ) =
            Calendar.update inner state
    in
    ( store next, Cmd.map toMsg cmd )


lookup : (String -> state) -> String -> Dict String state -> state
lookup start key states =
    Dict.get key states |> Maybe.withDefault (start key)


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none



-- DEMO DATA


today : Date
today =
    Sample.today


isWeekend : Date -> Bool
isWeekend day =
    Date.weekday day >= 6


type alias Booking =
    { date : Date
    , time : String
    , title : String
    , tone : Tone
    }


{-| A booking a number of days from today.
-}
booking : Int -> String -> String -> Tone -> Booking
booking offset time title tone =
    { date = Date.addDays offset today, time = time, title = title, tone = tone }


{-| A small dock schedule around today: done (green), planned (blue), at risk
(amber) and urgent (red).
-}
bookings : List Booking
bookings =
    [ booking -9 "13:00" "Dock inspection, Rotterdam Hub" Neutral
    , booking -6 "09:15" "Pick-up, Cobalt Hardware Ltd" Neutral
    , booking -6 "11:00" "Supplier call, Harborline Supply" Neutral
    , booking -2 "14:30" "Stock count, Hamburg Central" Neutral
    , booking 0 "08:30" "Goods in, Gothenburg Port" Success
    , booking 0 "10:00" "Delivery, Aurora Logistics Ltd" Success
    , booking 0 "13:15" "Pick-up, Meridian Packaging AB" Primary
    , booking 0 "15:00" "Delivery, Juniper Furniture GmbH" Primary
    , booking 1 "09:00" "Pallet delivery, Summit Tools Inc" Primary
    , booking 2 "10:30" "Delivery, Nimbus Electronics BV" Primary
    , booking 2 "12:00" "Customs hold, Chicago North" Warning
    , booking 4 "14:00" "Delivery, Willow Outdoor SA" Primary
    , booking 7 "09:45" "Delayed shipment, Tundra Marine AS" Warning
    , booking 7 "11:15" "Delivery, Cedar Print Ltd" Primary
    , booking 9 "08:00" "Urgent pick-up, Vertex Chemicals GmbH" Danger
    , booking 13 "13:30" "Delivery, Granite Textiles Inc" Primary
    , booking 16 "10:00" "Pick-up, Delta Toys AB" Primary
    ]


bookingDots : List Calendar.Marker
bookingDots =
    List.map (\b -> Calendar.dot b.date b.tone (b.time ++ "  " ++ b.title)) bookings


bookingCounts : Locale -> List Calendar.Marker
bookingCounts locale =
    bookings
        |> List.map .date
        |> unique
        |> List.map
            (\day ->
                let
                    n =
                        List.length (List.filter (\b -> b.date == day) bookings)
                in
                Calendar.count day
                    n
                    (Format.int locale n ++ " " ++ Format.plural locale n { one = "booking", other = "bookings" })
            )


unique : List Date -> List Date
unique days =
    List.foldr
        (\day kept ->
            if List.member day kept then
                kept

            else
                day :: kept
        )
        []
        days


{-| One dot for the due date of every order (thousands of marks), colored by status.
-}
orderDots : List Calendar.Marker
orderDots =
    List.map
        (\order ->
            Calendar.dot order.due
                (Labels.statusTone order.status)
                (orderIdText order.id ++ ", " ++ order.customer ++ ", " ++ orderStatusLabel order.status)
        )
        Sample.orders



-- MARKS FOR THE VISIBLE MONTH


{-| The days a calendar shows, as `Calendar.visibleRange` tells them.
-}
type alias Window =
    { from : Date, to : Date }


{-| The pretend server: how many orders are due on each day between two dates.
-}
ordersDueBetween : Window -> List ( Date, Int )
ordersDueBetween window =
    Sample.orders
        |> List.filter (\order -> Date.compare order.due window.from /= LT && Date.compare order.due window.to /= GT)
        |> List.foldl
            (\order counts -> Dict.update (Date.toEpochDay order.due) (\n -> Just (Maybe.withDefault 0 n + 1)) counts)
            Dict.empty
        |> Dict.toList
        |> List.map (\( day, n ) -> ( Date.fromEpochDay day, n ))


{-| Asks the pretend server for the orders due in a window: it takes a second,
and fails while the outage is on.
-}
fetchDue : Bool -> Window -> Cmd Msg
fetchDue outage window =
    Process.sleep 900
        |> Task.andThen (\_ -> Time.now)
        |> Task.perform
            (\at ->
                DueArrived window
                    (if outage then
                        Err Remote.timeout

                     else
                        Ok (ordersDueBetween window)
                    )
                    at
            )


{-| One count on each day that has orders due.
-}
dueMarks : Locale -> List ( Date, Int ) -> List Calendar.Marker
dueMarks locale days =
    List.map (\( day, n ) -> Calendar.count day n (ordersDue locale n)) days


ordersDue : Locale -> Int -> String
ordersDue locale n =
    Format.int locale n ++ " " ++ Format.plural locale n { one = "order due", other = "orders due" }



-- DEMOS: DATE FIELDS


{-| Every date field on the page: its key, the locale it insists on (if any), its
attributes and its starting state. The attributes are used for both `view` and
the starting `validate`.
-}
type alias DateDemo =
    { key : String
    , fixed : Maybe Locale
    , attributes : List DatePicker.Attribute
    , prepare : DatePicker.State -> DatePicker.State
    }


demoDates : List DateDemo
demoDates =
    let
        plain key attributes =
            { key = key, fixed = Nothing, attributes = attributes, prepare = identity }

        withDate key attributes day =
            { key = key, fixed = Nothing, attributes = attributes, prepare = DatePicker.setDate (Just day) }

        typed key attributes typedText =
            { key = key
            , fixed = Nothing
            , attributes = attributes
            , prepare = DatePicker.setText typedText >> DatePicker.validate attributes
            }

        norwegian key attributes day =
            { key = key, fixed = Just Locale.nb, attributes = attributes, prepare = DatePicker.setDate (Just day) }

        base =
            [ DatePicker.today today ]

        bounded =
            [ DatePicker.min (Date.addDays -14 today), DatePicker.max (Date.addDays 30 today) ]
    in
    [ plain "date-default" (DatePicker.label "Due date" :: base)
    , withDate "date-value" (DatePicker.label "With a value and a clear button" :: DatePicker.clearable :: base) (Date.addDays 7 today)
    , withDate "date-disabled" (DatePicker.label "Disabled" :: DatePicker.disabled True :: base) today
    , withDate "date-readonly" (DatePicker.label "Read-only" :: DatePicker.readOnly True :: base) today
    , plain "date-founded"
        (DatePicker.label "Supplier founded on"
            :: DatePicker.max today
            :: DatePicker.clearable
            :: DatePicker.hint "Not after today. Try 01.01.30 and press Enter: it is read as 1930."
            :: base
        )
    , typed "date-garbage"
        (DatePicker.label "Invalid text" :: DatePicker.hint "Type 2026-10-20, 20.10.2026 or 20102026" :: base)
        "32.13.2026"
    , typed "date-outside"
        (DatePicker.label "Outside the limits" :: bounded ++ base)
        "01.01.2020"
    , plain "date-required"
        (DatePicker.label "Required" :: DatePicker.required :: DatePicker.error "Choose a delivery date" :: base)
    , plain "date-bounded"
        (DatePicker.label "From 14 days ago to 30 days ahead" :: DatePicker.hint "A date outside the period shows an error." :: bounded ++ base)
    , plain "date-weekdays"
        (DatePicker.label "Weekdays only" :: DatePicker.disabledWhen isWeekend :: DatePicker.weekNumbers :: base)
    , plain "date-markers"
        (DatePicker.label "Dock booking" :: DatePicker.markers bookingDots :: DatePicker.weekNumbers :: base)
    , norwegian "date-norwegian"
        [ DatePicker.label "Norwegian locale", DatePicker.today today, DatePicker.clearable ]
        (Date.addDays 3 today)
    , plain "date-bottom" (DatePicker.label "Due date" :: DatePicker.markers bookingDots :: base)
    , plain "date-scroll" (DatePicker.label "Due date" :: DatePicker.markers bookingDots :: base)
    ]



-- DEMOS: PERIOD FIELDS


{-| Every period field on the page.
-}
type alias RangeDemo =
    { key : String
    , fixed : Maybe Locale
    , attributes : List DateRangePicker.Attribute
    , prepare : DateRangePicker.State -> DateRangePicker.State
    }


demoRanges : List RangeDemo
demoRanges =
    let
        plain key attributes =
            { key = key, fixed = Nothing, attributes = attributes, prepare = identity }

        withRange key attributes start finish =
            { key = key, fixed = Nothing, attributes = attributes, prepare = DateRangePicker.setRange (Just ( start, finish )) }

        typed key attributes typedTexts =
            { key = key
            , fixed = Nothing
            , attributes = attributes
            , prepare = DateRangePicker.setText typedTexts >> DateRangePicker.validate attributes
            }

        norwegian key attributes start finish =
            { key = key, fixed = Just Locale.nb, attributes = attributes, prepare = DateRangePicker.setRange (Just ( start, finish )) }

        base =
            [ DateRangePicker.today today ]

        nextMonth =
            Date.addMonths 1 today
    in
    [ plain "range-default" (DateRangePicker.label "Period" :: DateRangePicker.clearable :: base)
    , withRange "range-value"
        (DateRangePicker.label "With a value" :: DateRangePicker.clearable :: base)
        (Date.addDays -6 today)
        today
    , withRange "range-disabled"
        (DateRangePicker.label "Disabled" :: DateRangePicker.disabled True :: base)
        (Date.addDays -3 today)
        today
    , withRange "range-readonly"
        (DateRangePicker.label "Read-only" :: DateRangePicker.readOnly True :: base)
        (Date.addDays -3 today)
        today
    , plain "range-max"
        (DateRangePicker.label "At most 14 days"
            :: DateRangePicker.maxRangeDays 14
            :: DateRangePicker.hint "Days beyond the 14-day limit are blocked after the first click."
            :: base
        )
    , plain "range-bounded"
        (DateRangePicker.label "From 30 days ago to today"
            :: DateRangePicker.min (Date.addDays -30 today)
            :: DateRangePicker.max today
            :: DateRangePicker.markers bookingDots
            :: DateRangePicker.weekNumbers
            :: base
        )
    , typed "range-order"
        (DateRangePicker.label "Wrong order" :: base)
        { from = Date.toIso today, to = Date.toIso (Date.addDays -10 today) }
    , typed "range-garbage"
        (DateRangePicker.label "Invalid text" :: base)
        { from = "abc", to = "2026-02-31" }
    , plain "range-required"
        (DateRangePicker.label "Required"
            :: DateRangePicker.required
            :: DateRangePicker.error "Choose a report period"
            :: base
        )
    , plain "range-custom"
        (DateRangePicker.label "Own quick choices"
            :: DateRangePicker.presets
                [ DateRangePicker.preset "Next 7 days" today (Date.addDays 6 today)
                , DateRangePicker.preset "Next 14 days" today (Date.addDays 13 today)
                , DateRangePicker.preset "Next month" (Date.startOfMonth nextMonth) (Date.endOfMonth nextMonth)
                ]
            :: base
        )
    , plain "range-none" (DateRangePicker.label "No quick choices" :: DateRangePicker.noPresets :: base)
    , norwegian "range-norwegian"
        [ DateRangePicker.label "Norwegian locale", DateRangePicker.today today, DateRangePicker.clearable ]
        (Date.addDays -6 today)
        today
    , plain "range-bottom" (DateRangePicker.label "Period" :: base)
    , plain "range-scroll" (DateRangePicker.label "Period" :: base)
    ]



-- DEMOS: TIME FIELDS


{-| Every time field on the page.
-}
type alias TimeDemo =
    { key : String
    , fixed : Maybe Locale
    , attributes : List TimePicker.Attribute
    , prepare : TimePicker.State -> TimePicker.State
    }


demoTimes : List TimeDemo
demoTimes =
    let
        plain key attributes =
            { key = key, fixed = Nothing, attributes = attributes, prepare = identity }

        withTime key attributes hour minute =
            { key = key, fixed = Nothing, attributes = attributes, prepare = TimePicker.setTime (Just { hour = hour, minute = minute }) }

        typed key attributes typedText =
            { key = key
            , fixed = Nothing
            , attributes = attributes
            , prepare = TimePicker.setText typedText >> TimePicker.validate attributes
            }

        opening =
            [ TimePicker.min { hour = 8, minute = 0 }, TimePicker.max { hour = 16, minute = 0 } ]
    in
    [ plain "time-default" [ TimePicker.label "Every 15 minutes (the default)" ]
    , withTime "time-value" [ TimePicker.label "With a value and a clear button", TimePicker.clearable ] 14 30
    , plain "time-step5" [ TimePicker.label "Every 5 minutes", TimePicker.step 5 ]
    , plain "time-step30" [ TimePicker.label "Every half hour", TimePicker.step 30 ]
    , plain "time-opening"
        (TimePicker.label "Pick-up time"
            :: TimePicker.hint "Opening hours are 08:00 to 16:00. Other times are not allowed."
            :: opening
        )
    , typed "time-garbage" [ TimePicker.label "Invalid text", TimePicker.hint "Type 14:30, 1430 or 930" ] "25:99"
    , typed "time-outside" (TimePicker.label "Outside the limits" :: opening) "07:15"
    , plain "time-required" [ TimePicker.label "Required", TimePicker.required, TimePicker.error "Choose a time" ]
    , withTime "time-disabled" [ TimePicker.label "Disabled", TimePicker.disabled True ] 9 0
    , withTime "time-readonly" [ TimePicker.label "Read-only", TimePicker.readOnly True ] 9 0
    , { key = "time-norwegian"
      , fixed = Just Locale.nb
      , attributes = [ TimePicker.label "Norwegian locale", TimePicker.step 30 ]
      , prepare = identity
      }
    , plain "time-bottom" [ TimePicker.label "Time" ]
    , plain "time-scroll" [ TimePicker.label "Time" ]
    ]



-- DEMOS: DATE AND TIME FIELDS


{-| Every date and time field on the page.
-}
type alias DateTimeDemo =
    { key : String
    , fixed : Maybe Locale
    , attributes : List DateTimePicker.Attribute
    , prepare : DateTimePicker.State -> DateTimePicker.State
    }


demoDateTimes : List DateTimeDemo
demoDateTimes =
    let
        plain key attributes =
            { key = key, fixed = Nothing, attributes = attributes, prepare = identity }

        withValue key attributes day hour minute =
            { key = key
            , fixed = Nothing
            , attributes = attributes
            , prepare = DateTimePicker.setDateTime (Just { date = day, time = { hour = hour, minute = minute } })
            }

        norwegian key attributes day hour minute =
            { key = key
            , fixed = Just Locale.nb
            , attributes = attributes
            , prepare = DateTimePicker.setDateTime (Just { date = day, time = { hour = hour, minute = minute } })
            }

        base =
            [ DateTimePicker.today today ]
    in
    [ plain "datetime-default"
        (DateTimePicker.label "Delivery slot"
            :: DateTimePicker.min today
            :: DateTimePicker.hint "Not before today. Times from 08:00 to 16:00 in 15-minute steps."
            :: DateTimePicker.minTime { hour = 8, minute = 0 }
            :: DateTimePicker.maxTime { hour = 16, minute = 0 }
            :: base
        )
    , withValue "datetime-value"
        (DateTimePicker.label "With a value and clear buttons" :: DateTimePicker.clearable :: DateTimePicker.step 5 :: base)
        (Date.addDays 1 today)
        10
        30
    , plain "datetime-required"
        (DateTimePicker.label "Required" :: DateTimePicker.required :: DateTimePicker.error "Choose a date and a time" :: base)
    , withValue "datetime-disabled"
        (DateTimePicker.label "Disabled" :: DateTimePicker.disabled True :: base)
        today
        9
        0
    , withValue "datetime-readonly"
        (DateTimePicker.label "Read-only" :: DateTimePicker.readOnly True :: base)
        today
        9
        0
    , norwegian "datetime-norwegian"
        [ DateTimePicker.label "Norwegian locale", DateTimePicker.today today, DateTimePicker.step 30 ]
        (Date.addDays 1 today)
        9
        30
    ]



-- VIEW


view : Locale -> Model -> Html Msg
view locale model =
    Doc.page
        { title = "Date and time"
        , description =
            "A calendar, a date field, a period field, a time field and a combined date and time field. Everything can be filled in with the keyboard, and everything opens a calendar or a list that is never cut off by tables, cards or dialogs. “Today” comes from the application and is "
                ++ Date.toIso today
                ++ " on this page."
        }
        [ calendars locale model
        , datePickers locale model
        , rangePickers locale model
        , timePickers locale model
        , dateTimePickers locale model
        , placement locale model
        ]


{-| A test fixture, not a component: a short scrolling box.
-}
scrollFixture : List (Html Msg) -> Html Msg
scrollFixture children =
    Card.view [ Card.sunken, Card.flush ]
        [ Layout.stack [ Layout.gap 4, Layout.padding 4, Layout.maxHeight 200 ] children ]


missing : String -> Html Msg
missing key =
    Text.text ("Missing demo " ++ key)


find : String -> List { a | key : String } -> Maybe { a | key : String }
find key demos =
    List.filter (\demo -> demo.key == key) demos |> List.head



-- VIEW: calendars


calendars : Locale -> Model -> Html Msg
calendars locale model =
    Doc.section "Calendar"
        "The month calendar behind the date fields, also useful on its own. Keyboard on a day: the arrow keys move, Home and End go to the start and end of the week, PageUp and PageDown change month, Shift + PageUp and Shift + PageDown change year, Enter or Space picks the day. Only one day is in the tab order. The title opens a month chooser, and the title of that a year chooser."
        [ Doc.example
            { title = "Overview with bookings"
            , description = Just "Dots show bookings (point at a day to read them): gray is past, green done, blue planned, amber at risk, red urgent. The number shows how many. Week numbers on the left and a button back to today. The bookings of the chosen day are listed beside the calendar."
            , code = Just calendarOverviewCode
            }
            (Layout.row [ Layout.gap 8, Layout.alignStart, Layout.wrap ]
                [ Calendar.view OverviewMsg
                    [ Calendar.locale locale
                    , Calendar.ariaLabel "Dock bookings"
                    , Calendar.today today
                    , Calendar.todayButton
                    , Calendar.weekNumbers
                    , Calendar.size Large
                    , Calendar.markers (bookingDots ++ bookingCounts locale)
                    ]
                    model.overview
                , agenda locale model.overview
                ]
            )
        , Doc.example
            { title = "Small, with limits and blocked weekends"
            , description = Just "From 10 days ago to 40 days ahead; Saturdays and Sundays cannot be picked. The arrow keys stop at the limits but move over the blocked days."
            , code = Just calendarSmallCode
            }
            (Layout.stack [ Layout.gap 3 ]
                [ Calendar.view CompactMsg
                    [ Calendar.locale locale
                    , Calendar.ariaLabel "Delivery window"
                    , Calendar.today today
                    , Calendar.min (Date.addDays -10 today)
                    , Calendar.max (Date.addDays 40 today)
                    , Calendar.disabledWhen isWeekend
                    , Calendar.size Small
                    ]
                    model.compact
                , Text.caption ("Chosen: " ++ describeCalendar locale model.compact)
                ]
            )
        , Doc.example
            { title = "Period (two clicks)"
            , description = Just "Made with initRange and two months. After the first click the period is previewed under the mouse pointer (or the keyboard focus)."
            , code = Just calendarPeriodCode
            }
            (Layout.stack [ Layout.gap 3 ]
                [ Calendar.view PeriodMsg
                    [ Calendar.locale locale
                    , Calendar.ariaLabel "Report period"
                    , Calendar.today today
                    ]
                    model.period
                , Text.caption ("Chosen: " ++ describePeriod locale model.period)
                ]
            )
        , Doc.example
            { title = "Norwegian"
            , description = Just "With locale Nb. Norwegian weekday and month names, the week number heading (Uke) and a button back to today (I dag). Weeks still start on Monday."
            , code = Just calendarNorwegianCode
            }
            (Calendar.view NorwegianMsg
                [ Calendar.ariaLabel "Norwegian calendar"
                , Calendar.today today
                , Calendar.locale Locale.nb
                , Calendar.weekNumbers
                , Calendar.todayButton
                , Calendar.size Small
                ]
                model.norwegian
            )
        , Doc.example
            { title = "Large amounts of data"
            , description =
                Just
                    (Format.int Locale.en (List.length Sample.orders)
                        ++ " orders, one dot for each due date, colored by status (up to three are drawn per day; point at a day to read the orders). The calendar only draws the visible months, so it is as fast as with little data."
                    )
            , code = Just calendarOrdersCode
            }
            (Calendar.view OrdersMsg
                [ Calendar.locale locale
                , Calendar.ariaLabel "Orders by due date"
                , Calendar.today today
                , Calendar.markers orderDots
                ]
                model.orders
            )
        , Doc.example
            { title = "Marks from a server"
            , description = Just "The calendar tells which days it shows (visibleRange), and the application asks for their marks when that changes and gives them as a Remote (remote). While they load the grid is busy and says so under the days; a failure says why with Try again (onRetry); a refresh keeps the marks, dimmed, and a failed refresh keeps them as old data. Here a pretend server answers in about a second. Turn on the outage and go to another month, or press Refresh."
            , code = Just calendarMonthsCode
            }
            (Layout.row [ Layout.gap 8, Layout.alignStart, Layout.wrap ]
                [ Calendar.view ScheduleMsg
                    [ Calendar.locale locale
                    , Calendar.ariaLabel "Orders due"
                    , Calendar.today today
                    , Calendar.remote (Remote.map (dueMarks locale) model.due)
                    , Calendar.onRetry DueRetry
                    ]
                    model.schedule
                , Layout.stack [ Layout.gap 4 ]
                    [ Switch.view
                        [ Switch.id "schedule-outage"
                        , Switch.label "Simulate an outage"
                        , Switch.description "Requests sent while it is on fail. Turn it off and press Try again."
                        , Switch.checked model.outage
                        , Switch.onToggle OutageToggled
                        , Switch.locale locale
                        ]
                    , Button.view [ Button.small, Button.icon Icon.refresh, Button.onClick DueRefresh ] "Refresh"
                    , Text.caption (dueSummary locale model)
                    ]
                ]
            )
        ]


{-| What the application knows about the window on show.
-}
dueSummary : Locale -> Model -> String
dueSummary locale model =
    case Remote.toMaybe model.due of
        Just days ->
            let
                total =
                    List.sum (List.map Tuple.second days)
            in
            if total == 0 then
                "No orders due in these days"

            else
                ordersDue locale total ++ " in these days"

        Nothing ->
            ""


{-| The bookings of the chosen day, next to the calendar.
-}
agenda : Locale -> Calendar.State -> Html Msg
agenda locale state =
    case Calendar.value state of
        Nothing ->
            Text.caption "Choose a day to see its bookings."

        Just day ->
            let
                items =
                    List.filter (\b -> b.date == day) bookings
            in
            Layout.stack [ Layout.gap 3 ]
                (Text.subheading (Locale.weekdayLong locale (Date.weekday day) ++ " " ++ Format.dateLong locale day)
                    :: (if List.isEmpty items then
                            [ Text.caption "No bookings" ]

                        else
                            List.map
                                (\b ->
                                    Layout.row [ Layout.gap 3 ]
                                        [ Text.mono b.time
                                        , Badge.status b.tone b.title
                                        ]
                                )
                                items
                       )
                )


describeCalendar : Locale -> Calendar.State -> String
describeCalendar locale state =
    case Calendar.value state of
        Just day ->
            Format.date locale day

        Nothing ->
            "none"


describePeriod : Locale -> Calendar.State -> String
describePeriod locale state =
    case ( Calendar.range state, Calendar.anchor state ) of
        ( Just ( start, finish ), _ ) ->
            Format.date locale start ++ " – " ++ Format.date locale finish

        ( Nothing, Just begin ) ->
            Format.date locale begin ++ " – (choose the end date)"

        ( Nothing, Nothing ) ->
            "none"



-- VIEW: date fields


{-| A date field with the value the application sees below it. The page's
language is the default; a demo that insists on a locale keeps it.
-}
datePicker : Locale -> Model -> String -> Html Msg
datePicker pageLocale model key =
    case find key demoDates of
        Nothing ->
            missing key

        Just demo ->
            let
                lang =
                    Maybe.withDefault pageLocale demo.fixed

                state =
                    lookup DatePicker.init key model.dates
            in
            Layout.stack [ Layout.gap 1 ]
                [ DatePicker.view (DateMsg key) (DatePicker.locale lang :: demo.attributes) state
                , Text.caption (describeDate lang state)
                ]


describeDate : Locale -> DatePicker.State -> String
describeDate lang state =
    case DatePicker.date state of
        Just day ->
            "Value: " ++ Format.date lang day

        Nothing ->
            if DatePicker.isInvalid state then
                "Value: none (the text “" ++ DatePicker.text state ++ "” was not accepted)"

            else
                "Value: none"


datePickers : Locale -> Model -> Html Msg
datePickers locale model =
    Doc.section "Date field"
        "Type the date or pick it in the calendar. The field reads 2026-10-20, 20.10.2026, 20102026, 20.10.26, 20.10 (this year), t or today, and +3 or -7 (days from today): a complete date as you type it, anything else when Enter is pressed or the field is left. Arrow down or Alt + arrow down opens the calendar, and so does Enter unless there is typed text to take. Escape closes the calendar and returns to the field (inside the month and year choosers it goes back one step first); Tab out of the calendar closes it."
        [ Doc.example
            { title = "Default and states"
            , description = Just "Empty, with a value and a clear button, disabled and read-only. The text below each field is the value the application sees."
            , code = Just dateDefaultCode
            }
            (Layout.grid [ Layout.minColumn 240, Layout.gap 6 ]
                (List.map (datePicker locale model) [ "date-default", "date-value", "date-disabled", "date-readonly" ])
            )
        , Doc.example
            { title = "A date in the past"
            , description = Just "The latest date is today. A two-digit year is read so that the date lands inside the limits: 01.01.30 becomes 1930, because 2030 is after today. The title of the calendar opens the months, and the title of that the years, twenty at a time."
            , code = Just datePastCode
            }
            (Layout.grid [ Layout.minColumn 240, Layout.gap 6 ]
                (List.map (datePicker locale model) [ "date-founded" ])
            )
        , Doc.example
            { title = "Invalid and required"
            , description = Just "The error message comes from text the field cannot read, from a date outside the limits, or from the application."
            , code = Just dateInvalidCode
            }
            (Layout.grid [ Layout.minColumn 240, Layout.gap 6 ]
                (List.map (datePicker locale model) [ "date-garbage", "date-outside", "date-required", "date-bounded" ])
            )
        , Doc.example
            { title = "Blocked days, bookings and the Norwegian locale"
            , description = Just "Weekends cannot be picked in the first field. In the second, the calendar shows the bookings as dots (point at a day to read them). The third uses the Norwegian locale: Norwegian text and the date written 20.10.2026."
            , code = Just dateBlockedCode
            }
            (Layout.grid [ Layout.minColumn 240, Layout.gap 6 ]
                (List.map (datePicker locale model) [ "date-weekdays", "date-markers", "date-norwegian" ])
            )
        ]



-- VIEW: period fields


rangePicker : Locale -> Model -> String -> Html Msg
rangePicker pageLocale model key =
    case find key demoRanges of
        Nothing ->
            missing key

        Just demo ->
            let
                lang =
                    Maybe.withDefault pageLocale demo.fixed

                state =
                    lookup DateRangePicker.init key model.ranges
            in
            Layout.stack [ Layout.gap 1 ]
                [ DateRangePicker.view (RangeMsg key) (DateRangePicker.locale lang :: demo.attributes) state
                , Text.caption (describeRange lang state)
                ]


describeRange : Locale -> DateRangePicker.State -> String
describeRange lang state =
    case DateRangePicker.range state of
        Just ( start, finish ) ->
            let
                days =
                    Date.diffDays start finish + 1
            in
            "Value: "
                ++ Format.date lang start
                ++ " – "
                ++ Format.date lang finish
                ++ " ("
                ++ Format.int lang days
                ++ " "
                ++ Format.plural lang days { one = "day", other = "days" }
                ++ ")"

        Nothing ->
            if DateRangePicker.isInvalid state then
                "Value: none (the period was not accepted)"

            else
                "Value: none"


rangePickers : Locale -> Model -> Html Msg
rangePickers locale model =
    Doc.section "Period field"
        "From and to date in one field, with one calendar that shows two months and a list of quick choices. Choose the period with two clicks: the choice applies at the second click, and between the clicks the period is previewed under the mouse pointer. Escape closes the popup and throws away a half-made choice. Keyboard in the calendar as for the date field."
        [ Doc.example
            { title = "Default with quick choices"
            , description = Just "The quick choices are computed from the “today” the application supplies, and cut to the limits."
            , code = Just rangeDefaultCode
            }
            (Layout.grid [ Layout.minColumn 320, Layout.gap 6 ]
                (List.map (rangePicker locale model) [ "range-default", "range-value", "range-disabled", "range-readonly" ])
            )
        , Doc.example
            { title = "Limits"
            , description = Just "A longest period, and limits with bookings and week numbers in the calendar. Quick choices that do not fit are disabled, and their tooltip says why."
            , code = Just rangeLimitsCode
            }
            (Layout.grid [ Layout.minColumn 320, Layout.gap 6 ]
                (List.map (rangePicker locale model) [ "range-max", "range-bounded" ])
            )
        , Doc.example
            { title = "Invalid and required"
            , description = Just "The start date after the end date, text the field cannot read, and a missing period."
            , code = Just rangeInvalidCode
            }
            (Layout.grid [ Layout.minColumn 320, Layout.gap 6 ]
                (List.map (rangePicker locale model) [ "range-order", "range-garbage", "range-required" ])
            )
        , Doc.example
            { title = "Own quick choices, no quick choices and the Norwegian locale"
            , description = Just "Own quick choices are shown even when the field has no today. The Norwegian locale translates the quick choices, the line below the calendar, the placeholders and the messages."
            , code = Just rangePresetsCode
            }
            (Layout.grid [ Layout.minColumn 320, Layout.gap 6 ]
                (List.map (rangePicker locale model) [ "range-custom", "range-none", "range-norwegian" ])
            )
        ]



-- VIEW: time fields


timePicker : Locale -> Model -> String -> Html Msg
timePicker pageLocale model key =
    case find key demoTimes of
        Nothing ->
            missing key

        Just demo ->
            let
                lang =
                    Maybe.withDefault pageLocale demo.fixed

                state =
                    lookup TimePicker.init key model.times
            in
            Layout.stack [ Layout.gap 1 ]
                [ TimePicker.view (TimeMsg key) (TimePicker.locale lang :: demo.attributes) state
                , Text.caption (describeTime state)
                ]


describeTime : TimePicker.State -> String
describeTime state =
    case TimePicker.time state of
        Just value ->
            "Value: " ++ TimePicker.toString value

        Nothing ->
            if TimePicker.isInvalid state then
                "Value: none (the text “" ++ TimePicker.text state ++ "” was not accepted)"

            else
                "Value: none"


timePickers : Locale -> Model -> Html Msg
timePickers locale model =
    Doc.section "Time field"
        "Type 14:30, 14.30, 1430, 930 or 14, or choose from the list. The list has times in fixed steps (5, 15 or 30 minutes) on a 24-hour clock. Click in the field, arrow down or Alt + arrow down opens the list; the arrow keys and PageUp / PageDown move, Enter chooses, Escape or Alt + arrow up closes it. Focus stays in the field the whole time."
        [ Doc.example
            { title = "Steps"
            , description = Just "The list offers a time every 15 minutes unless step says otherwise. Typed times between the steps are accepted too, such as 09:37."
            , code = Just timeStepsCode
            }
            (Layout.grid [ Layout.minColumn 200, Layout.gap 6 ]
                (List.map (timePicker locale model) [ "time-default", "time-value", "time-step5", "time-step30" ])
            )
        , Doc.example
            { title = "Limits and errors"
            , description = Just "The list only offers times inside the limits, and a typed time outside them is refused with a message. So is text the field cannot read."
            , code = Just timeLimitsCode
            }
            (Layout.grid [ Layout.minColumn 200, Layout.gap 6 ]
                (List.map (timePicker locale model) [ "time-opening", "time-garbage", "time-outside", "time-required" ])
            )
        , Doc.example
            { title = "Disabled, read-only and Norwegian"
            , description = Just "The Norwegian locale changes the text (the placeholder tt:mm, the button label and the messages); the clock is always 24-hour."
            , code = Just timeStatesCode
            }
            (Layout.grid [ Layout.minColumn 200, Layout.gap 6 ]
                (List.map (timePicker locale model) [ "time-disabled", "time-readonly", "time-norwegian" ])
            )
        ]



-- VIEW: date and time fields


dateTimePicker : Locale -> Model -> String -> Html Msg
dateTimePicker pageLocale model key =
    case find key demoDateTimes of
        Nothing ->
            missing key

        Just demo ->
            let
                lang =
                    Maybe.withDefault pageLocale demo.fixed

                state =
                    lookup DateTimePicker.init key model.dateTimes
            in
            Layout.stack [ Layout.gap 1 ]
                [ DateTimePicker.view (DateTimeMsg key) (DateTimePicker.locale lang :: demo.attributes) state
                , Text.caption (describeDateTime lang state)
                ]


describeDateTime : Locale -> DateTimePicker.State -> String
describeDateTime lang state =
    case DateTimePicker.dateTime state of
        Just value ->
            "Value: " ++ Format.date lang value.date ++ " " ++ TimePicker.toString value.time

        Nothing ->
            if DateTimePicker.isInvalid state then
                "Value: none (a part was not accepted)"

            else
                "Value: none"


dateTimePickers : Locale -> Model -> Html Msg
dateTimePickers locale model =
    Doc.section "Date and time field"
        "A date field and a time field under one label. The value is only complete when both parts are valid, and each part shows its own message when its text cannot be read. The parts work as described above."
        [ Doc.example
            { title = "Date and time"
            , description = Just "Limits for the date and for the time of day, then a value with clear buttons, required, disabled, read-only and Norwegian. The value below each field is only set when both parts are valid."
            , code = Just dateTimeCode
            }
            (Layout.grid [ Layout.minColumn 320, Layout.gap 6 ]
                (List.map (dateTimePicker locale model)
                    [ "datetime-default", "datetime-value", "datetime-required", "datetime-disabled", "datetime-readonly", "datetime-norwegian" ]
                )
            )
        ]



-- VIEW: placement


placement : Locale -> Model -> Html Msg
placement locale model =
    Doc.section "Placement"
        "Calendars and lists open above everything else. Here the fields sit in a small box that scrolls, and at the bottom of the page. Nothing is cut off, and when there is no room below they open upwards."
        [ Doc.example
            { title = "Inside a scrolling box"
            , description = Just "The box is 200 px high and clips its content. The fields are far down in it."
            , code = Nothing
            }
            (scrollFixture
                [ Text.paragraph "Scroll down in the box. The fields below open their calendar and list outside the edge of the box."
                , Text.paragraph "This is filler so that the box can scroll. Order ORD-10412 left the warehouse this morning, and the next stock count is planned in three weeks."
                , Text.paragraph "More filler. The pallets have been counted, and the supplier will confirm the delivery within the week. The customer has been told to call the warehouse with any questions."
                , Layout.grid [ Layout.minColumn 260, Layout.gap 4 ]
                    [ datePicker locale model "date-scroll"
                    , rangePicker locale model "range-scroll"
                    , timePicker locale model "time-scroll"
                    ]
                , Text.paragraph "Even more filler below the fields."
                , Text.paragraph "And a little more, so that the box can scroll past the fields."
                ]
            )
        , Doc.example
            { title = "At the bottom of the page"
            , description = Just "Scroll to the bottom of the page and open a field. The calendar opens upwards when there is no room below."
            , code = Nothing
            }
            (Layout.grid [ Layout.minColumn 260, Layout.gap 4 ]
                [ datePicker locale model "date-bottom"
                , rangePicker locale model "range-bottom"
                , timePicker locale model "time-bottom"
                ]
            )
        ]



-- CODE SNIPPETS


calendarOverviewCode : String
calendarOverviewCode =
    """-- model
{ calendar : Calendar.State }   -- Calendar.init "bookings" |> Calendar.setValue (Just model.today)

-- msg
CalendarMsg Calendar.Msg

-- update
CalendarMsg inner ->
    let
        ( calendar, cmd ) =
            Calendar.update inner model.calendar
    in
    ( { model | calendar = calendar }, Cmd.map CalendarMsg cmd )

-- view
Calendar.view CalendarMsg
    [ Calendar.today model.today
    , Calendar.todayButton
    , Calendar.weekNumbers
    , Calendar.size Large
    , Calendar.markers
        [ Calendar.dot date Success "10:00 Delivery, Aurora Logistics Ltd"
        , Calendar.count date 3 "3 bookings"
        ]
    ]
    model.calendar

-- read
Calendar.value model.calendar   -- Maybe Date"""


calendarSmallCode : String
calendarSmallCode =
    """Calendar.view CalendarMsg
    [ Calendar.today model.today
    , Calendar.min (Date.addDays -10 model.today)
    , Calendar.max (Date.addDays 40 model.today)
    , Calendar.disabledWhen isWeekend
    , Calendar.size Small
    ]
    model.calendar

isWeekend : Date -> Bool
isWeekend day =
    Date.weekday day >= 6"""


calendarPeriodCode : String
calendarPeriodCode =
    """-- model
{ period : Calendar.State }   -- Calendar.initRange "period" |> Calendar.setMonths 2

-- view
Calendar.view PeriodMsg [ Calendar.today model.today ] model.period

-- read
Calendar.range model.period    -- Maybe ( Date, Date ): Just after the second click
Calendar.anchor model.period   -- Maybe Date: the first click, while the second is awaited"""


calendarNorwegianCode : String
calendarNorwegianCode =
    """Calendar.view CalendarMsg
    [ Calendar.today model.today
    , Calendar.locale Locale.nb
    , Calendar.weekNumbers
    , Calendar.todayButton
    , Calendar.size Small
    ]
    model.calendar"""


calendarOrdersCode : String
calendarOrdersCode =
    """-- model: Calendar.init "orders" |> Calendar.setMonths 2
Calendar.view CalendarMsg
    [ Calendar.today model.today
    , Calendar.markers (List.map dueDot model.orders)
    ]
    model.calendar

dueDot : Order -> Calendar.Marker
dueDot order =
    Calendar.dot order.due (statusTone order.status) (orderIdText order.id ++ ", " ++ order.customer)"""


calendarMonthsCode : String
calendarMonthsCode =
    """-- model
{ calendar : Calendar.State   -- Calendar.init "orders" |> Calendar.showDate model.today
, due : Remote (List Order)   -- the orders due in the visible month
}

-- update
CalendarMsg inner ->
    let
        ( calendar, cmd ) =
            Calendar.update inner model.calendar

        shown =
            Calendar.visibleRange calendar
    in
    if shown /= Calendar.visibleRange model.calendar then
        ( { model | calendar = calendar, due = Remote.Loading }
        , Cmd.batch [ Cmd.map CalendarMsg cmd, fetchDue shown ]
        )

    else
        ( { model | calendar = calendar }, Cmd.map CalendarMsg cmd )

-- the answer, with the window it was asked for and the time it came
GotDue window result at ->
    if window == Calendar.visibleRange model.calendar then
        ( { model | due = Remote.refreshWith model.due result at }, Cmd.none )

    else
        ( model, Cmd.none )

RetryDue ->
    ( { model | due = Remote.refresh model.due }
    , Cmd.batch
        [ fetchDue (Calendar.visibleRange model.calendar)
        , Cmd.map CalendarMsg (Calendar.focus model.calendar)
        ]
    )

-- view
Calendar.view CalendarMsg
    [ Calendar.today model.today
    , Calendar.remote (Remote.map (List.map dueMark) model.due)
    , Calendar.onRetry RetryDue
    ]
    model.calendar"""


dateDefaultCode : String
dateDefaultCode =
    """-- model
{ dueDate : DatePicker.State }   -- DatePicker.init "due-date"

-- msg
DueDateMsg DatePicker.Msg

-- update
DueDateMsg inner ->
    let
        ( dueDate, cmd ) =
            DatePicker.update inner model.dueDate
    in
    ( { model | dueDate = dueDate }, Cmd.map DueDateMsg cmd )

-- view
DatePicker.view DueDateMsg
    [ DatePicker.label "Due date"
    , DatePicker.today model.today
    , DatePicker.clearable
    ]
    model.dueDate

-- states
DatePicker.disabled True   -- cannot be focused or changed; takes a Bool, so it can come from your model
DatePicker.readOnly True   -- can be focused and copied, not changed
DatePicker.setDate (Just order.due) model.dueDate   -- fill the field from the application

-- read
DatePicker.date model.dueDate   -- Maybe Date"""


datePastCode : String
datePastCode =
    """DatePicker.view FoundedMsg
    [ DatePicker.label "Supplier founded on"
    , DatePicker.today model.today
    , DatePicker.max model.today
    , DatePicker.clearable
    ]
    model.founded"""


dateInvalidCode : String
dateInvalidCode =
    """deliveryDate : Date -> List DatePicker.Attribute
deliveryDate today =
    [ DatePicker.label "Delivery date"
    , DatePicker.today today
    , DatePicker.min (Date.addDays -14 today)
    , DatePicker.max (Date.addDays 30 today)
    ]

DatePicker.view DateMsg (deliveryDate model.today) model.date

-- on submit: read the text the user has not left yet, then ask
DatePicker.validate (deliveryDate model.today) model.date |> DatePicker.isInvalid   -- Bool

-- a missing date is an error of the application
DatePicker.view DateMsg
    (DatePicker.required :: DatePicker.error "Choose a delivery date" :: deliveryDate model.today)
    model.date"""


dateBlockedCode : String
dateBlockedCode =
    """DatePicker.view DateMsg
    [ DatePicker.label "Weekdays only"
    , DatePicker.disabledWhen isWeekend
    , DatePicker.weekNumbers
    ]
    model.date

DatePicker.view DateMsg
    [ DatePicker.label "Dock booking"
    , DatePicker.markers [ Calendar.dot date Success "10:00 Delivery, Aurora Logistics Ltd" ]
    ]
    model.date

DatePicker.view DateMsg
    [ DatePicker.label "Norwegian locale", DatePicker.locale Locale.nb ]
    model.date"""


rangeDefaultCode : String
rangeDefaultCode =
    """-- model
{ period : DateRangePicker.State }   -- DateRangePicker.init "report-period"

-- msg
PeriodMsg DateRangePicker.Msg

-- update
PeriodMsg inner ->
    let
        ( period, cmd ) =
            DateRangePicker.update inner model.period
    in
    ( { model | period = period }, Cmd.map PeriodMsg cmd )

-- view
DateRangePicker.view PeriodMsg
    [ DateRangePicker.label "Report period"
    , DateRangePicker.today model.today
    , DateRangePicker.clearable
    ]
    model.period

-- read
DateRangePicker.range model.period   -- Maybe ( Date, Date )"""


rangeLimitsCode : String
rangeLimitsCode =
    """DateRangePicker.view PeriodMsg
    [ DateRangePicker.label "At most 14 days"
    , DateRangePicker.today model.today
    , DateRangePicker.maxRangeDays 14
    ]
    model.period

DateRangePicker.view PeriodMsg
    [ DateRangePicker.label "From 30 days ago to today"
    , DateRangePicker.today model.today
    , DateRangePicker.min (Date.addDays -30 model.today)
    , DateRangePicker.max model.today
    , DateRangePicker.markers bookingDots
    , DateRangePicker.weekNumbers
    ]
    model.period"""


rangeInvalidCode : String
rangeInvalidCode =
    """reportPeriod : Date -> List DateRangePicker.Attribute
reportPeriod today =
    [ DateRangePicker.label "Report period", DateRangePicker.today today ]

DateRangePicker.view PeriodMsg (reportPeriod model.today) model.period

-- on submit: read the text the user has not left yet, then ask
DateRangePicker.validate (reportPeriod model.today) model.period |> DateRangePicker.isInvalid   -- Bool

-- a missing period is an error of the application
DateRangePicker.view PeriodMsg
    (DateRangePicker.required :: DateRangePicker.error "Choose a report period" :: reportPeriod model.today)
    model.period"""


rangePresetsCode : String
rangePresetsCode =
    """DateRangePicker.presets
    [ DateRangePicker.preset "Next 7 days" model.today (Date.addDays 6 model.today)
    , DateRangePicker.preset "Next 14 days" model.today (Date.addDays 13 model.today)
    ]

DateRangePicker.noPresets

DateRangePicker.locale Locale.nb"""


timeStepsCode : String
timeStepsCode =
    """-- model
{ pickup : TimePicker.State }   -- TimePicker.init "pickup"

-- msg
PickupMsg TimePicker.Msg

-- update
PickupMsg inner ->
    let
        ( pickup, cmd ) =
            TimePicker.update inner model.pickup
    in
    ( { model | pickup = pickup }, Cmd.map PickupMsg cmd )

-- view
TimePicker.view PickupMsg
    [ TimePicker.label "Pick-up time"
    , TimePicker.step 15
    ]
    model.pickup

-- read
TimePicker.time model.pickup   -- Maybe { hour : Int, minute : Int }"""


timeLimitsCode : String
timeLimitsCode =
    """pickupTime : List TimePicker.Attribute
pickupTime =
    [ TimePicker.label "Pick-up time"
    , TimePicker.hint "Opening hours are 08:00 to 16:00."
    , TimePicker.min { hour = 8, minute = 0 }
    , TimePicker.max { hour = 16, minute = 0 }
    ]

TimePicker.view PickupMsg pickupTime model.pickup

-- on submit: read the text the user has not left yet, then ask
TimePicker.validate pickupTime model.pickup |> TimePicker.isInvalid   -- Bool

-- a missing time is an error of the application
TimePicker.view PickupMsg
    (TimePicker.required :: TimePicker.error "Choose a time" :: pickupTime)
    model.pickup"""


timeStatesCode : String
timeStatesCode =
    """TimePicker.view PickupMsg [ TimePicker.label "Pick-up time", TimePicker.disabled True ] model.pickup

TimePicker.view PickupMsg [ TimePicker.label "Pick-up time", TimePicker.readOnly True ] model.pickup

TimePicker.view PickupMsg [ TimePicker.label "Norwegian locale", TimePicker.locale Locale.nb ] model.pickup"""


dateTimeCode : String
dateTimeCode =
    """-- model
{ slot : DateTimePicker.State }   -- DateTimePicker.init "slot"

-- msg
SlotMsg DateTimePicker.Msg

-- update
SlotMsg inner ->
    let
        ( slot, cmd ) =
            DateTimePicker.update inner model.slot
    in
    ( { model | slot = slot }, Cmd.map SlotMsg cmd )

-- view
DateTimePicker.view SlotMsg
    [ DateTimePicker.label "Delivery slot"
    , DateTimePicker.today model.today
    , DateTimePicker.min model.today
    , DateTimePicker.minTime { hour = 8, minute = 0 }
    , DateTimePicker.maxTime { hour = 16, minute = 0 }
    , DateTimePicker.step 15
    ]
    model.slot

-- read
DateTimePicker.dateTime model.slot   -- Maybe { date : Date, time : TimePicker.Time }"""
