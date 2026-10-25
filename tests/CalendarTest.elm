module CalendarTest exposing (suite)

{-| Klar.Calendar: the keyboard, the choosers, the limits of the dates, the
visible months, the spoken status and the marks from a backend.

Messages are taken from the rendered view (a click or a key press on an element
found by its id), given to `update`, and the next view is checked: the same path
a browser takes.

-}

import Expect
import Html
import Html.Attributes
import Json.Encode as Encode
import Klar.Calendar as Calendar
import Klar.Date as Date exposing (Date)
import Klar.Locale as Locale
import Klar.Remote as Remote
import Klar.Theme exposing (Tone(..))
import Test exposing (Test, describe, test)
import Test.Html.Event as Event
import Test.Html.Query as Query
import Test.Html.Selector as Selector
import Time


suite : Test
suite =
    describe "Klar.Calendar"
        [ keyboardTests
        , todayTests
        , pickTests
        , chooserTests
        , limitTests
        , visibleTests
        , weekTests
        , announceTests
        , remoteTests
        ]



-- HELPERS


date : Int -> Int -> Int -> Date
date y m d =
    Date.fromParts y m d |> Maybe.withDefault (Date.fromEpochDay 0)


today : Date
today =
    date 2026 10 20


type Msg
    = CalendarMsg Calendar.Msg
    | Retry


type alias Attrs =
    List (Calendar.Attribute Msg)


render : Attrs -> Calendar.State -> Query.Single Msg
render attributes state =
    Calendar.view CalendarMsg attributes state |> Query.fromHtml


{-| The calendar's own message out of the page's, given to `update`.
-}
step : Calendar.State -> Msg -> Result String Calendar.State
step state msg =
    case msg of
        CalendarMsg inner ->
            Ok (Calendar.update inner state |> Tuple.first)

        Retry ->
            Err "the retry button, not a calendar message"


{-| A key press as the browser sends it (the fields the decoders of Klar read).
-}
keydown : String -> Bool -> ( String, Encode.Value )
keydown key shift =
    Event.custom "keydown"
        (Encode.object
            [ ( "key", Encode.string key )
            , ( "ctrlKey", Encode.bool False )
            , ( "metaKey", Encode.bool False )
            , ( "shiftKey", Encode.bool shift )
            , ( "altKey", Encode.bool False )
            , ( "isComposing", Encode.bool False )
            , ( "keyCode", Encode.int 0 )
            ]
        )


{-| Sends an event to the element with this id and runs `update` with the message.
-}
send : ( String, Encode.Value ) -> String -> Attrs -> Calendar.State -> Result String Calendar.State
send event id attributes state =
    render attributes state
        |> Query.find [ Selector.id id ]
        |> Event.simulate event
        |> Event.toResult
        |> Result.andThen (step state)


{-| A key press on the grid of the first month (the grid handles the keys of its days).
-}
press : String -> Bool -> Attrs -> Calendar.State -> Result String Calendar.State
press key shift attributes state =
    render attributes state
        |> Query.findAll [ Selector.attribute (attr "role" "grid") ]
        |> Query.first
        |> Event.simulate (keydown key shift)
        |> Event.toResult
        |> Result.andThen (step state)


{-| A key press on the month or year chooser: the panel holds the Escape of
its heading buttons and its picks (a key the picks do not handle bubbles up).
-}
pressChooser : String -> Attrs -> Calendar.State -> Result String Calendar.State
pressChooser key attributes state =
    render attributes state
        |> Query.find [ Selector.class "klar-calendar__panel" ]
        |> Event.simulate (keydown key False)
        |> Event.toResult
        |> Result.andThen (step state)


attr : String -> String -> Html.Attribute msg
attr name value =
    Html.Attributes.attribute name value


steps : List (Calendar.State -> Result String Calendar.State) -> Calendar.State -> Result String Calendar.State
steps list state =
    List.foldl (\next result -> Result.andThen next result) (Ok state) list


{-| An untouched calendar that knows today, as an application starts one.
-}
start : Calendar.State
start =
    Calendar.init "c" |> Calendar.setToday today


iso : Date -> String
iso =
    Date.toIso



-- KEYBOARD


keyboardTests : Test
keyboardTests =
    let
        attributes =
            []

        focusAfter keys =
            steps (List.map (\( key, shift ) -> press key shift attributes) keys) start
                |> Result.map (Calendar.focusedDay >> iso)
    in
    describe "keyboard"
        [ test "the arrow keys move by day and by week" <|
            \_ -> Expect.equal (Ok "2026-10-28") (focusAfter [ ( "ArrowRight", False ), ( "ArrowDown", False ) ])
        , test "Home and End go to Monday and Sunday in English and Norwegian" <|
            \_ ->
                Expect.equal (Ok ( "2026-10-19", "2026-10-25" ))
                    (Result.map2 Tuple.pair
                        (focusAfter [ ( "Home", False ) ])
                        (focusAfter [ ( "End", False ) ])
                    )
        , test "PageDown changes month and Shift+PageUp the year" <|
            \_ -> Expect.equal (Ok "2025-11-20") (focusAfter [ ( "PageDown", False ), ( "PageUp", True ) ])
        , test "the visible month follows the focus" <|
            \_ ->
                steps [ press "PageDown" False attributes ] start
                    |> Result.map Calendar.visibleMonth
                    |> Expect.equal (Ok { year = 2026, month = 11 })
        , test "the arrow keys stop at max" <|
            \_ ->
                steps (List.repeat 5 (press "ArrowRight" False [ Calendar.max (date 2026 10 22) ])) start
                    |> Result.map (Calendar.focusedDay >> iso)
                    |> Expect.equal (Ok "2026-10-22")
        ]



-- TODAY


todayTests : Test
todayTests =
    let
        title state =
            render [] state |> Query.find [ Selector.id "c-title-0" ]
    in
    describe "today in the state"
        [ test "an untouched calendar shows the month of today, and the accessors say the same" <|
            \_ ->
                Expect.all
                    [ \_ -> title start |> Query.has [ Selector.text "October\u{00A0}2026" ]
                    , \_ -> Calendar.visibleMonth start |> Expect.equal { year = 2026, month = 10 }
                    , \_ -> Calendar.visibleRange start |> Expect.equal { from = date 2026 10 1, to = date 2026 10 31 }
                    , \_ -> Calendar.focusedDay start |> Expect.equal today
                    , \_ -> render [] start |> Query.find [ Selector.id "c-d-2026-10-20" ] |> Query.has [ Selector.attribute (Html.Attributes.tabindex 0) ]
                    ]
                    ()
        , test "without today both say January 2000" <|
            \_ ->
                Expect.all
                    [ \_ -> title (Calendar.init "c") |> Query.has [ Selector.text "January\u{00A0}2000" ]
                    , \_ -> Calendar.visibleMonth (Calendar.init "c") |> Expect.equal { year = 2000, month = 1 }
                    ]
                    ()
        , test "today is marked" <|
            \_ ->
                render [] start
                    |> Query.find [ Selector.id "c-d-2026-10-20" ]
                    |> Query.has [ Selector.attribute (attr "aria-current" "date"), Selector.class "klar-calendar__day--today" ]
        , test "setToday does not move a calendar that shows another month" <|
            \_ ->
                Calendar.init "c"
                    |> Calendar.showDate (date 2027 3 5)
                    |> Calendar.setToday today
                    |> Calendar.visibleMonth
                    |> Expect.equal { year = 2027, month = 3 }
        , test "the first key press starts from today" <|
            \_ ->
                press "ArrowRight" False [] start
                    |> Result.map (Calendar.focusedDay >> iso)
                    |> Expect.equal (Ok "2026-10-21")
        , test "the Today button takes the calendar back to the month of today" <|
            \_ ->
                steps [ press "PageDown" False [ Calendar.todayButton ], send Event.click "c-today" [ Calendar.todayButton ] ] start
                    |> Result.map Calendar.visibleMonth
                    |> Expect.equal (Ok { year = 2026, month = 10 })
        , test "with min after today the view starts inside the limits" <|
            \_ ->
                render [ Calendar.min (date 2027 1 10) ] start
                    |> Query.find [ Selector.id "c-title-0" ]
                    |> Query.has [ Selector.text "January\u{00A0}2027" ]
        ]



-- PICKING


pickTests : Test
pickTests =
    describe "picking"
        [ test "a click on a day chooses it" <|
            \_ ->
                send Event.click "c-d-2026-10-22" [] start
                    |> Result.map Calendar.value
                    |> Expect.equal (Ok (Just (date 2026 10 22)))
        , test "a day of the next month chooses it and shows its month" <|
            \_ ->
                send Event.click "c-d-2026-11-01" [] start
                    |> Result.map (\state -> ( Calendar.value state, Calendar.visibleMonth state ))
                    |> Expect.equal (Ok ( Just (date 2026 11 1), { year = 2026, month = 11 } ))
        , test "a range takes two clicks, in either order" <|
            \_ ->
                steps [ send Event.click "c-d-2026-10-25" [], send Event.click "c-d-2026-10-21" [] ]
                    (Calendar.initRange "c" |> Calendar.showDate today)
                    |> Result.map Calendar.range
                    |> Expect.equal (Ok (Just ( date 2026 10 21, date 2026 10 25 )))
        , test "the grid of a range calendar is multi-selectable" <|
            \_ ->
                render [] (Calendar.initRange "c" |> Calendar.showDate today)
                    |> Query.findAll [ Selector.attribute (attr "aria-multiselectable" "true") ]
                    |> Query.count (Expect.equal 1)
        , test "a single calendar is not" <|
            \_ ->
                render [] start
                    |> Query.findAll [ Selector.attribute (attr "aria-multiselectable" "true") ]
                    |> Query.count (Expect.equal 0)
        , test "setValue chooses a day and shows its month" <|
            \_ ->
                Calendar.setValue (Just (date 2027 3 5)) start
                    |> (\state -> ( Calendar.value state, Calendar.visibleMonth state ))
                    |> Expect.equal ( Just (date 2027 3 5), { year = 2027, month = 3 } )
        ]



-- CHOOSERS


chooserTests : Test
chooserTests =
    describe "the month and year choosers"
        [ test "Escape in the month chooser goes back to the days" <|
            \_ ->
                steps [ send Event.click "c-title-0" [], pressChooser "Escape" [] ] start
                    |> Result.map (\state -> render [] state |> Query.findAll [ Selector.class "klar-calendar__grid" ] |> Query.count (Expect.equal 1))
                    |> Result.withDefault (Expect.fail "no message")
        , test "Escape in the year chooser goes back to the months" <|
            \_ ->
                steps [ send Event.click "c-title-0" [], send Event.click "c-title-0" [], pressChooser "Escape" [] ] start
                    |> Result.map (\state -> render [] state |> Query.findAll [ Selector.class "klar-calendar__picks--months" ] |> Query.count (Expect.equal 1))
                    |> Result.withDefault (Expect.fail "no message")
        , test "the heading buttons of a chooser are inside the panel that takes Escape" <|
            \_ ->
                steps [ send Event.click "c-title-0" [] ] start
                    |> Result.map
                        (\state ->
                            render [] state
                                |> Query.find [ Selector.class "klar-calendar__panel" ]
                                |> Expect.all
                                    [ Query.has [ Selector.id "c-prev" ]
                                    , Query.has [ Selector.id "c-next" ]
                                    , Query.has [ Selector.id "c-title-0" ]
                                    ]
                        )
                    |> Result.withDefault (Expect.fail "no message")
        , test "the years come in pages of twenty that start at 1, 21 ... 2021" <|
            \_ ->
                steps [ send Event.click "c-title-0" [], send Event.click "c-title-0" [] ] start
                    |> Result.map
                        (\state ->
                            render [] state
                                |> Expect.all
                                    [ Query.has [ Selector.id "c-y-2021" ]
                                    , Query.has [ Selector.id "c-y-2040" ]
                                    , Query.hasNot [ Selector.id "c-y-2020" ]
                                    ]
                        )
                    |> Result.withDefault (Expect.fail "no message")
        , test "there is no year 0" <|
            \_ ->
                steps [ send Event.click "c-title-0" [], send Event.click "c-title-0" [] ] (Calendar.init "c" |> Calendar.showDate (date 5 6 1))
                    |> Result.map
                        (\state ->
                            render [] state
                                |> Expect.all
                                    [ Query.has [ Selector.id "c-y-1" ]
                                    , Query.hasNot [ Selector.id "c-y-0" ]
                                    , Query.find [ Selector.id "c-prev" ] >> Query.has [ Selector.attribute (attr "aria-disabled" "true") ]
                                    ]
                        )
                    |> Result.withDefault (Expect.fail "no message")
        , test "today's month is aria-current in the month chooser" <|
            \_ ->
                steps [ send Event.click "c-title-0" [] ] start
                    |> Result.map (\state -> render [] state |> Query.find [ Selector.id "c-m-10" ] |> Query.has [ Selector.attribute (attr "aria-current" "date") ])
                    |> Result.withDefault (Expect.fail "no message")
        ]



-- LIMITS


limitTests : Test
limitTests =
    describe "the dates stay between year 1 and 9999"
        [ test "Shift+PageUp from year 1 stays in year 1" <|
            \_ ->
                steps [ press "PageUp" True [] ] (Calendar.init "c" |> Calendar.showDate (date 1 3 10))
                    |> Result.map (Calendar.focusedDay >> Date.year)
                    |> Expect.equal (Ok 1)
        , test "Shift+PageDown from 9999 stays in 9999" <|
            \_ ->
                steps [ press "PageDown" True [] ] (Calendar.init "c" |> Calendar.showDate (date 9999 10 10))
                    |> Result.map (Calendar.focusedDay >> iso)
                    |> Expect.equal (Ok "9999-12-31")
        , test "the previous month of January of year 1 is disabled" <|
            \_ ->
                render [] (Calendar.init "c" |> Calendar.showDate (date 1 1 10))
                    |> Query.find [ Selector.id "c-prev" ]
                    |> Query.has [ Selector.attribute (attr "aria-disabled" "true") ]
        ]



-- VISIBLE MONTHS


visibleTests : Test
visibleTests =
    describe "the visible months"
        [ test "visibleRange covers the month" <|
            \_ ->
                Calendar.visibleRange start
                    |> Expect.equal { from = date 2026 10 1, to = date 2026 10 31 }
        , test "and every month of setMonths" <|
            \_ ->
                Calendar.visibleRange (start |> Calendar.setMonths 3)
                    |> Expect.equal { from = date 2026 10 1, to = date 2026 12 31 }
        , test "setMonths draws that many months" <|
            \_ ->
                render [] (start |> Calendar.setMonths 2)
                    |> Query.findAll [ Selector.class "klar-calendar__grid" ]
                    |> Query.count (Expect.equal 2)
        , test "a move past the last visible month scrolls by one month" <|
            \_ ->
                steps [ press "PageDown" False [], press "PageDown" False [] ] (start |> Calendar.setMonths 2)
                    |> Result.map Calendar.visibleRange
                    |> Expect.equal (Ok { from = date 2026 11 1, to = date 2026 12 31 })
        ]



-- WEEK NUMBERS


weekTests : Test
weekTests =
    describe "week numbers"
        [ test "a row has the ISO week of its Thursday" <|
            \_ ->
                render [ Calendar.weekNumbers ] (Calendar.init "c" |> Calendar.showDate (date 2027 1 1))
                    |> Query.findAll [ Selector.class "klar-calendar__week" ]
                    |> Query.first
                    |> Query.has [ Selector.text "53" ]
        , test "the column head has the full name" <|
            \_ ->
                render [ Calendar.weekNumbers ] start
                    |> Query.find [ Selector.class "klar-calendar__week-head" ]
                    |> Query.has [ Selector.attribute (attr "abbr" "Week number") ]
        ]



-- ANNOUNCEMENTS


announceTests : Test
announceTests =
    let
        spoken attributes state =
            render attributes state |> Query.find [ Selector.id "c-announce" ]
    in
    describe "the spoken status"
        [ test "it is there, empty, before a choice" <|
            \_ -> spoken [] start |> Query.has [ Selector.attribute (attr "aria-live" "polite") ]
        , test "a chosen day is announced" <|
            \_ ->
                send Event.click "c-d-2026-10-22" [] start
                    |> Result.map (\state -> spoken [] state |> Query.has [ Selector.text "Selected: Thursday 22 October 2026" ])
                    |> Result.withDefault (Expect.fail "no message")
        , test "in Norwegian too" <|
            \_ ->
                send Event.click "c-d-2026-10-22" [ Calendar.locale Locale.nb ] start
                    |> Result.map (\state -> spoken [ Calendar.locale Locale.nb ] state |> Query.has [ Selector.text "Valgt: torsdag 22. oktober 2026" ])
                    |> Result.withDefault (Expect.fail "no message")
        , test "the first day of a period asks for the end" <|
            \_ ->
                send Event.click "c-d-2026-10-22" [] (Calendar.initRange "c" |> Calendar.showDate today)
                    |> Result.map (\state -> spoken [] state |> Query.has [ Selector.text "Start: Thursday 22 October 2026. Choose the end date." ])
                    |> Result.withDefault (Expect.fail "no message")
        , test "the whole period is announced" <|
            \_ ->
                Calendar.initRange "c"
                    |> Calendar.setRange (Just ( date 2026 10 22, date 2026 10 25 ))
                    |> spoken []
                    |> Query.has [ Selector.text "Selected period: 22 October 2026 to 25 October 2026" ]
        ]



-- MARKS FROM A BACKEND


remoteTests : Test
remoteTests =
    let
        marks =
            [ Calendar.dot (date 2026 10 22) Info "Delivery" ]

        status attributes =
            render attributes start |> Query.find [ Selector.id "c-marks" ]
    in
    describe "marks from a backend"
        [ test "plain markers have no status line" <|
            \_ ->
                render [ Calendar.markers marks ] start
                    |> Query.findAll [ Selector.id "c-marks" ]
                    |> Query.count (Expect.equal 0)
        , test "loading: the line says so, politely, and the grid is not held back as busy" <|
            \_ ->
                Expect.all
                    [ \_ -> render [ Calendar.remote Remote.Loading ] start |> Query.findAll [ Selector.attribute (attr "aria-busy" "true") ] |> Query.count (Expect.equal 0)
                    , \_ -> status [ Calendar.remote Remote.Loading ] |> Query.has [ Selector.text "Loading", Selector.attribute (attr "aria-live" "polite") ]
                    ]
                    ()
        , test "loaded: the marks are drawn and nothing is busy" <|
            \_ ->
                render [ Calendar.remote (Remote.Loaded marks) ] start
                    |> Expect.all
                        [ Query.find [ Selector.id "c-d-2026-10-22" ] >> Query.has [ Selector.class "klar-calendar__dot" ]
                        , Query.findAll [ Selector.attribute (attr "aria-busy" "true") ] >> Query.count (Expect.equal 0)
                        , Query.find [ Selector.id "c-marks" ] >> Query.children [] >> Query.count (Expect.equal 1)
                        ]
        , test "failed: the reason and a retry button that sends onRetry" <|
            \_ ->
                status [ Calendar.remote (Remote.Failed (Remote.problem Remote.network)), Calendar.onRetry Retry ]
                    |> Query.find [ Selector.id "c-retry" ]
                    |> Event.simulate Event.click
                    |> Event.expect Retry
        , test "a problem that trying again cannot fix has no retry button" <|
            \_ ->
                status [ Calendar.remote (Remote.Failed (Remote.problem Remote.forbidden)), Calendar.onRetry Retry ]
                    |> Query.findAll [ Selector.id "c-retry" ]
                    |> Query.count (Expect.equal 0)
        , test "failed without onRetry: no button" <|
            \_ ->
                status [ Calendar.remote (Remote.Failed (Remote.problem Remote.network)) ]
                    |> Query.findAll [ Selector.id "c-retry" ]
                    |> Query.count (Expect.equal 0)
        , test "refreshing: the marks stay, dimmed, and nothing is held back as busy" <|
            \_ ->
                render [ Calendar.remote (Remote.refresh (Remote.Loaded marks)) ] start
                    |> Expect.all
                        [ Query.has [ Selector.class "klar-calendar--refreshing" ]
                        , Query.find [ Selector.id "c-d-2026-10-22" ] >> Query.has [ Selector.class "klar-calendar__dot" ]
                        , Query.findAll [ Selector.attribute (attr "aria-busy" "true") ] >> Query.count (Expect.equal 0)
                        ]
        , test "old marks after a failed refresh: the notice with a retry, and the dots stay" <|
            \_ ->
                let
                    stale =
                        Remote.refreshWith (Remote.Loaded marks) (Err (Remote.problem Remote.network)) (Time.millisToPosix 0)

                    attributes =
                        [ Calendar.remote stale, Calendar.onRetry Retry ]
                in
                Expect.all
                    [ \_ -> status attributes |> Query.findAll [ Selector.class "klar-stale" ] |> Query.count (Expect.equal 1)
                    , \_ -> status attributes |> Query.has [ Selector.text "Old data" ]
                    , \_ -> status attributes |> Query.find [ Selector.tag "button" ] |> Event.simulate Event.click |> Event.expect Retry
                    , \_ -> render attributes start |> Query.find [ Selector.id "c-d-2026-10-22" ] |> Query.has [ Selector.class "klar-calendar__dot" ]
                    ]
                    ()
        , test "the same elements around the days in every state, so the focus survives" <|
            \_ ->
                [ Remote.NotAsked
                , Remote.Loading
                , Remote.Loaded marks
                , Remote.refresh (Remote.Loaded marks)
                , Remote.Failed (Remote.problem Remote.network)
                , Remote.refreshWith (Remote.Loaded marks) (Err (Remote.problem Remote.network)) (Time.millisToPosix 0)
                ]
                    |> List.map
                        (\data ->
                            let
                                view =
                                    render [ Calendar.remote data, Calendar.onRetry Retry ] start
                            in
                            \_ ->
                                Expect.all
                                    [ \_ -> view |> Query.findAll [ Selector.class "klar-calendar__grid" ] |> Query.count (Expect.equal 1)
                                    , \_ -> view |> Query.findAll [ Selector.class "klar-calendar__day" ] |> Query.count (Expect.equal 42)
                                    , \_ -> view |> Query.find [ Selector.class "klar-calendar__body" ] |> Query.children [ Selector.class "klar-calendar__months" ] |> Query.count (Expect.equal 1)
                                    , \_ -> view |> Query.findAll [ Selector.id "c-marks" ] |> Query.count (Expect.equal 1)
                                    , \_ -> view |> Query.find [ Selector.id "c-d-2026-10-20" ] |> Query.has [ Selector.attribute (Html.Attributes.tabindex 0) ]
                                    ]
                                    ()
                        )
                    |> (\checks -> Expect.all checks ())
        ]
