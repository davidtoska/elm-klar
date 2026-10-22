module RecurrencePickerTest exposing (suite)

{-| Klar.RecurrencePicker: the value it builds from what the user does (driven
through the rendered form, with real events), the problems of an incomplete
form, the weekday that cannot be turned off, `setRule` as the inverse of `value`,
and the accessibility of the markup.
-}

import Expect
import Html exposing (Html)
import Html.Attributes as Attr
import Json.Encode as Encode
import Klar.Locale as Locale
import Klar.Recurrence as Recurrence exposing (Rule)
import Klar.RecurrencePicker as RecurrencePicker exposing (Msg, State)
import Support.RecurrenceFuzz exposing (paramsFuzzer, startFuzzer)
import Support.RecurrenceReference as Reference exposing (date)
import Test exposing (Test, describe, fuzz2, test)
import Test.Html.Event as Event
import Test.Html.Query as Query
import Test.Html.Selector as Selector exposing (Selector)
import Time exposing (Month(..), Weekday(..))


suite : Test
suite =
    describe "Klar.RecurrencePicker"
        [ startTests
        , frequencyTests
        , weekdayTests
        , monthlyTests
        , missingDayTests
        , endTests
        , problemTests
        , setRuleTests
        , textTests
        , markupTests
        , previewTests
        ]



-- DRIVING THE FORM


id : String
id =
    "repeat"


type alias Attributes =
    List RecurrencePicker.Attribute


viewOf : Attributes -> State -> Html Msg
viewOf attributes state =
    RecurrencePicker.view identity attributes state


query : Attributes -> State -> Query.Single Msg
query attributes state =
    Query.fromHtml (viewOf attributes state)


{-| Sends an event to the one element that matches, and runs the message it
makes through `update`.
-}
send : List Selector -> ( String, Encode.Value ) -> State -> Result String State
send find event state =
    query [] state
        |> Query.find find
        |> Event.simulate event
        |> Event.toResult
        |> Result.map (\msg -> Tuple.first (RecurrencePicker.update msg state))


changed : ( String, Encode.Value )
changed =
    Event.custom "change" (Encode.object [])


radio : String -> String -> State -> Result String State
radio group choice =
    send
        [ Selector.tag "input"
        , Selector.attribute (Attr.name group)
        , Selector.attribute (Attr.value choice)
        ]
        changed


frequency : String -> State -> Result String State
frequency =
    radio id


ends : String -> State -> Result String State
ends =
    radio (id ++ "-end")


by : String -> State -> Result String State
by =
    radio (id ++ "-by")


missing : String -> State -> Result String State
missing =
    radio (id ++ "-missing")


typeInto : String -> String -> State -> Result String State
typeInto inputId text =
    send [ Selector.id inputId ] (Event.input text)


tick : Int -> Bool -> State -> Result String State
tick weekday on =
    send [ Selector.id (weekdayId weekday) ] (Event.check on)


{-| The checkbox of a weekday: the first one carries the id of the group, the
others the id with their position.
-}
weekdayId : Int -> String
weekdayId weekday =
    if weekday == 1 then
        id ++ "-weekdays"

    else
        id ++ "-weekdays-" ++ String.fromInt (weekday - 1)


run : List (State -> Result String State) -> State -> Result String State
run steps state =
    List.foldl (\step result -> Result.andThen step result) (Ok state) steps


fresh : State
fresh =
    RecurrencePicker.init id (date 2026 10 20)


from : Int -> Int -> Int -> State
from year month day =
    RecurrencePicker.init id (date year month day)


{-| The rule the form holds after the steps, or why they failed.
-}
valueAfter : State -> List (State -> Result String State) -> Result String (Maybe Rule)
valueAfter state steps =
    run steps state |> Result.map RecurrencePicker.value


built : Recurrence.Pattern -> List Recurrence.Option -> Result String (Maybe Rule)
built pattern options =
    Recurrence.rule pattern options
        |> Result.map Just
        |> Result.mapError (Recurrence.problemText Locale.en)


problemAfter : State -> List (State -> Result String State) -> Result String (Maybe String)
problemAfter state steps =
    run steps state
        |> Result.map (RecurrencePicker.problem >> Maybe.map (RecurrencePicker.problemText Locale.en))



-- START


startTests : Test
startTests =
    describe "a new field"
        [ test "does not repeat and has no problem" <|
            \_ ->
                Expect.equal ( Nothing, Nothing ) ( RecurrencePicker.value fresh, RecurrencePicker.problem fresh )
        , test "remembers its start date" <|
            \_ ->
                Expect.equal (date 2026 10 20) (RecurrencePicker.start fresh)
        , test "setStart moves the start date" <|
            \_ ->
                Expect.equal (date 2027 1 5) (RecurrencePicker.start (RecurrencePicker.setStart (date 2027 1 5) fresh))
        , test "the weekday that is ticked first follows the start date" <|
            \_ ->
                Expect.equal (built (Recurrence.weekly Fri []) [])
                    (valueAfter (RecurrencePicker.setStart (date 2026 10 23) fresh) [ frequency "weekly" ])
        , test "a weekday the user chose stays when the start moves" <|
            \_ ->
                Expect.equal (built (Recurrence.weekly Tue [ Wed ]) [])
                    (run [ frequency "weekly", tick 3 True ] fresh
                        |> Result.map (RecurrencePicker.setStart (date 2026 10 23))
                        |> Result.map RecurrencePicker.value
                    )
        ]



-- FREQUENCY


frequencyTests : Test
frequencyTests =
    describe "the frequency and the interval"
        [ test "does not repeat" <|
            \_ ->
                Expect.equal (Ok Nothing) (valueAfter fresh [ frequency "daily", frequency "once" ])
        , test "daily" <|
            \_ ->
                Expect.equal (built Recurrence.daily []) (valueAfter fresh [ frequency "daily" ])
        , test "weekly on the weekday of the start" <|
            \_ ->
                Expect.equal (built (Recurrence.weekly Tue []) []) (valueAfter fresh [ frequency "weekly" ])
        , test "monthly on the day of the start" <|
            \_ ->
                Expect.equal (built (Recurrence.monthlyOnDay 20) []) (valueAfter fresh [ frequency "monthly" ])
        , test "yearly on the date of the start" <|
            \_ ->
                Expect.equal (built (Recurrence.yearlyOnDate Oct 20) []) (valueAfter fresh [ frequency "yearly" ])
        , test "every third week" <|
            \_ ->
                Expect.equal (built (Recurrence.weekly Tue []) [ Recurrence.every 3 ])
                    (valueAfter fresh [ frequency "weekly", typeInto (id ++ "-interval") "3" ])
        , test "a choice with the keyboard does not lose what was typed in the interval" <|
            \_ ->
                Expect.equal (built Recurrence.daily [ Recurrence.every 5 ])
                    (valueAfter fresh [ frequency "weekly", typeInto (id ++ "-interval") "5", frequency "daily" ])
        ]



-- WEEKDAYS


weekdayTests : Test
weekdayTests =
    let
        refusal state =
            query [] state
                |> Query.find [ Selector.id (id ++ "-note") ]
                |> Query.has [ Selector.text "Tuesday cannot be turned off: at least one weekday has to be selected." ]
    in
    describe "the weekdays"
        [ test "more weekdays can be ticked" <|
            \_ ->
                Expect.equal (built (Recurrence.weekly Tue [ Thu, Sat ]) [])
                    (valueAfter fresh [ frequency "weekly", tick 4 True, tick 6 True ])
        , test "a weekday can be turned off while another is on" <|
            \_ ->
                Expect.equal (built (Recurrence.weekly Thu []) [])
                    (valueAfter fresh [ frequency "weekly", tick 4 True, tick 2 False ])
        , test "the last weekday cannot be turned off" <|
            \_ ->
                Expect.equal (built (Recurrence.weekly Tue []) [])
                    (valueAfter fresh [ frequency "weekly", tick 2 False ])
        , test "and the field says why, in a status message" <|
            \_ ->
                case run [ frequency "weekly", tick 2 False ] fresh of
                    Ok state ->
                        refusal state

                    Err message ->
                        Expect.fail message
        , test "the message is in Norwegian when the field is" <|
            \_ ->
                case run [ frequency "weekly", tick 2 False ] fresh of
                    Ok state ->
                        query [ RecurrencePicker.locale Locale.nb ] state
                            |> Query.find [ Selector.id (id ++ "-note") ]
                            |> Query.has [ Selector.text "Tirsdag kan ikke slås av: minst én ukedag må være valgt." ]

                    Err message ->
                        Expect.fail message
        , test "before any refusal the status element is there and empty" <|
            \_ ->
                case run [ frequency "weekly" ] fresh of
                    Ok state ->
                        Expect.all
                            [ Query.has [ Selector.attribute (Attr.attribute "role" "status") ]
                            , Query.hasNot [ Selector.containing [ Selector.text "cannot be turned off" ] ]
                            ]
                            (query [] state |> Query.find [ Selector.id (id ++ "-note") ])

                    Err message ->
                        Expect.fail message
        , test "the message goes away when a weekday is ticked" <|
            \_ ->
                case run [ frequency "weekly", tick 2 False, tick 3 True ] fresh of
                    Ok state ->
                        query [] state
                            |> Query.hasNot [ Selector.text "cannot be turned off" ]

                    Err message ->
                        Expect.fail message
        ]



-- MONTHLY AND YEARLY


monthlyTests : Test
monthlyTests =
    describe "the day of a monthly and a yearly rule"
        [ test "the choices follow the start: the day and the n-th weekday" <|
            \_ ->
                query [] (runOrFresh [ frequency "monthly" ] fresh)
                    |> Query.find [ Selector.id (id ++ "-by-group") ]
                    |> Expect.all
                        [ Query.has [ Selector.text "On day 20 of the month", Selector.text "On the third Tuesday of the month" ]
                        , Query.hasNot [ Selector.text "last" ]
                        ]
        , test "the n-th weekday" <|
            \_ ->
                Expect.equal (built (Recurrence.monthlyOnWeekday Recurrence.third Tue) [])
                    (valueAfter fresh [ frequency "monthly", by "nth" ])
        , test "the last weekday is offered when the start is the last, and so is the fourth" <|
            \_ ->
                let
                    start =
                        from 2026 10 27
                in
                Expect.equal
                    [ built (Recurrence.monthlyOnWeekday Recurrence.fourth Tue) []
                    , built (Recurrence.monthlyOnWeekday Recurrence.last Tue) []
                    ]
                    [ valueAfter start [ frequency "monthly", by "nth" ]
                    , valueAfter start [ frequency "monthly", by "last" ]
                    ]
        , test "a fifth weekday is the last, and there is no separate choice for it" <|
            \_ ->
                let
                    start =
                        from 2026 10 29
                in
                Expect.all
                    [ \_ -> Expect.equal (built (Recurrence.monthlyOnWeekday Recurrence.last Thu) []) (valueAfter start [ frequency "monthly", by "nth" ])
                    , \_ ->
                        query [] (runOrFresh [ frequency "monthly" ] start)
                            |> Query.find [ Selector.id (id ++ "-by-group") ]
                            |> Expect.all
                                [ Query.has [ Selector.text "On the last Thursday of the month" ]
                                , Query.findAll [ Selector.attribute (Attr.value "last") ] >> Query.count (Expect.equal 0)
                                ]
                    ]
                    ()
        , test "yearly: the date and the n-th weekday of the month" <|
            \_ ->
                Expect.equal
                    [ built (Recurrence.yearlyOnDate Oct 20) []
                    , built (Recurrence.yearlyOnWeekday Recurrence.third Tue Oct) []
                    ]
                    [ valueAfter fresh [ frequency "yearly" ]
                    , valueAfter fresh [ frequency "yearly", by "nth" ]
                    ]
        , test "the choices of a yearly rule say the month" <|
            \_ ->
                query [] (runOrFresh [ frequency "yearly" ] fresh)
                    |> Query.find [ Selector.id (id ++ "-by-group") ]
                    |> Query.has [ Selector.text "On 20 October", Selector.text "On the third Tuesday of October" ]
        , test "the choice follows the start date when it moves" <|
            \_ ->
                Expect.equal (built (Recurrence.monthlyOnWeekday Recurrence.second Wed) [])
                    (run [ frequency "monthly", by "nth" ] fresh
                        |> Result.map (RecurrencePicker.setStart (date 2026 11 11))
                        |> Result.map RecurrencePicker.value
                    )
        , test "a last-weekday choice becomes the n-th when the start is not the last any more" <|
            \_ ->
                Expect.equal (built (Recurrence.monthlyOnWeekday Recurrence.second Wed) [])
                    (run [ frequency "monthly", by "last" ] (from 2026 10 28)
                        |> Result.map (RecurrencePicker.setStart (date 2026 11 11))
                        |> Result.map RecurrencePicker.value
                    )
        ]


runOrFresh : List (State -> Result String State) -> State -> State
runOrFresh steps state =
    run steps state |> Result.withDefault state



-- DAYS THAT SOME MONTHS DO NOT HAVE


missingDayTests : Test
missingDayTests =
    describe "months without the day"
        [ test "the 31st asks what to do, and uses the last day by default" <|
            \_ ->
                Expect.equal (built (Recurrence.monthlyOnDay 31) [])
                    (valueAfter (from 2026 1 31) [ frequency "monthly" ])
        , test "the question is there for the 31st" <|
            \_ ->
                query [] (runOrFresh [ frequency "monthly" ] (from 2026 1 31))
                    |> Query.find [ Selector.id (id ++ "-missing-group") ]
                    |> Query.has [ Selector.text "In months without day 31", Selector.text "Use the last day of the month", Selector.text "Skip the month" ]
        , test "skipping the month" <|
            \_ ->
                Expect.equal (built (Recurrence.monthlyOnDay 31 |> Recurrence.skippingMissingDays) [])
                    (valueAfter (from 2026 1 31) [ frequency "monthly", missing "skip" ])
        , test "there is no question for a day every month has" <|
            \_ ->
                query [] (runOrFresh [ frequency "monthly" ] fresh)
                    |> Query.findAll [ Selector.id (id ++ "-missing-group") ]
                    |> Query.count (Expect.equal 0)
        , test "there is no question for the n-th weekday" <|
            \_ ->
                query [] (runOrFresh [ frequency "monthly", by "nth" ] (from 2026 1 31))
                    |> Query.findAll [ Selector.id (id ++ "-missing-group") ]
                    |> Query.count (Expect.equal 0)
        , test "29 February asks about the years without it" <|
            \_ ->
                Expect.equal
                    [ built (Recurrence.yearlyOnDate Feb 29) []
                    , built (Recurrence.yearlyOnDate Feb 29 |> Recurrence.skippingMissingDays) []
                    ]
                    [ valueAfter (from 2028 2 29) [ frequency "yearly" ]
                    , valueAfter (from 2028 2 29) [ frequency "yearly", missing "skip" ]
                    ]
        , test "and says so" <|
            \_ ->
                query [] (runOrFresh [ frequency "yearly" ] (from 2028 2 29))
                    |> Query.find [ Selector.id (id ++ "-missing-group") ]
                    |> Query.has [ Selector.text "In years without 29 February", Selector.text "Use 28 February" ]
        ]



-- THE END


endTests : Test
endTests =
    describe "how the rule ends"
        [ test "never, by default" <|
            \_ ->
                Expect.equal (built Recurrence.daily []) (valueAfter fresh [ frequency "daily", ends "never" ])
        , test "after a number of times" <|
            \_ ->
                Expect.equal (built Recurrence.daily [ Recurrence.ends (Recurrence.after 10) ])
                    (valueAfter fresh [ frequency "daily", ends "after" ])
        , test "after the number that was typed" <|
            \_ ->
                Expect.equal (built Recurrence.daily [ Recurrence.ends (Recurrence.after 4) ])
                    (valueAfter fresh [ frequency "daily", ends "after", typeInto (id ++ "-count") "4" ])
        , test "on a date" <|
            \_ ->
                Expect.equal (built (Recurrence.weekly Tue []) [ Recurrence.ends (Recurrence.until (date 2027 12 31)) ])
                    (valueAfter fresh [ frequency "weekly", ends "on", typeInto (id ++ "-until") "2027-12-31" ])
        , test "going back to never forgets nothing but ends the rule" <|
            \_ ->
                Expect.equal (built Recurrence.daily [])
                    (valueAfter fresh [ frequency "daily", ends "after", typeInto (id ++ "-count") "4", ends "never" ])
        , test "the number field and the date field are only there for their choice" <|
            \_ ->
                let
                    present theId steps check =
                        query [] (runOrFresh steps fresh)
                            |> Query.findAll [ Selector.id theId ]
                            |> Query.count check
                in
                Expect.all
                    [ \_ -> present (id ++ "-count") [ frequency "daily" ] (Expect.equal 0)
                    , \_ -> present (id ++ "-count") [ frequency "daily", ends "after" ] (Expect.equal 1)
                    , \_ -> present (id ++ "-until") [ frequency "daily", ends "after" ] (Expect.equal 0)
                    , \_ -> present (id ++ "-until") [ frequency "daily", ends "on" ] (Expect.equal 1)
                    ]
                    ()
        ]



-- PROBLEMS


problemTests : Test
problemTests =
    describe "an incomplete form"
        [ test "an empty interval has no value and a problem" <|
            \_ ->
                Expect.equal ( Ok Nothing, Ok (Just "Enter how often it repeats: a whole number, 1 or more.") )
                    ( valueAfter fresh [ frequency "weekly", typeInto (id ++ "-interval") "" ]
                    , problemAfter fresh [ frequency "weekly", typeInto (id ++ "-interval") "" ]
                    )
        , test "0, a fraction and a number that is too big are not an interval" <|
            \_ ->
                Expect.equal
                    (Ok [ True, True, True ])
                    (Result.map (List.map (\value -> value == Nothing))
                        (List.foldr (Result.map2 (::))
                            (Ok [])
                            [ valueAfter fresh [ frequency "daily", typeInto (id ++ "-interval") "0" ]
                            , valueAfter fresh [ frequency "daily", typeInto (id ++ "-interval") "2.5" ]
                            , valueAfter fresh [ frequency "daily", typeInto (id ++ "-interval") "1000" ]
                            ]
                        )
                    )
        , test "text that is not a number is not an interval, and nothing is guessed" <|
            \_ ->
                Expect.equal ( Ok Nothing, Ok (Just "Enter how often it repeats: a whole number, 1 or more.") )
                    ( valueAfter fresh [ frequency "daily", typeInto (id ++ "-interval") "abc" ]
                    , problemAfter fresh [ frequency "daily", typeInto (id ++ "-interval") "abc" ]
                    )
        , test "after with no number" <|
            \_ ->
                Expect.equal ( Ok Nothing, Ok (Just "Enter how many times it repeats: a whole number, 1 or more.") )
                    ( valueAfter fresh [ frequency "daily", ends "after", typeInto (id ++ "-count") "" ]
                    , problemAfter fresh [ frequency "daily", ends "after", typeInto (id ++ "-count") "" ]
                    )
        , test "on a date with no date" <|
            \_ ->
                Expect.equal ( Ok Nothing, Ok (Just "Choose the date it ends.") )
                    ( valueAfter fresh [ frequency "daily", ends "on" ]
                    , problemAfter fresh [ frequency "daily", ends "on" ]
                    )
        , test "the problem is in Norwegian too" <|
            \_ ->
                case run [ frequency "daily", ends "on" ] fresh of
                    Ok state ->
                        Expect.equal (Just "Velg datoen den slutter.")
                            (RecurrencePicker.problem state |> Maybe.map (RecurrencePicker.problemText Locale.nb))

                    Err message ->
                        Expect.fail message
        , test "a field that does not repeat has no problem even with a broken interval behind it" <|
            \_ ->
                Expect.equal (Ok Nothing)
                    (problemAfter fresh [ frequency "daily", typeInto (id ++ "-interval") "", frequency "once" ])
        , test "an empty interval is reported under the field once the user has left it" <|
            \_ ->
                case run [ frequency "daily", typeInto (id ++ "-interval") "", send [ Selector.id (id ++ "-interval") ] Event.blur ] fresh of
                    Ok state ->
                        query [] state
                            |> Query.find [ Selector.id (id ++ "-error") ]
                            |> Query.has
                                [ Selector.text "Enter how often it repeats: a whole number, 1 or more."
                                , Selector.attribute (Attr.attribute "role" "alert")
                                ]

                    Err message ->
                        Expect.fail message
        , test "text that is not a number is left to the number field, which has its own message" <|
            \_ ->
                case run [ frequency "daily", typeInto (id ++ "-interval") "abc", send [ Selector.id (id ++ "-interval") ] Event.blur ] fresh of
                    Ok state ->
                        Expect.all
                            [ Query.findAll [ Selector.id (id ++ "-error") ] >> Query.count (Expect.equal 0)
                            , Query.has [ Selector.id (id ++ "-interval-error") ]
                            ]
                            (query [] state)

                    Err message ->
                        Expect.fail message
        , test "the problem is not shown under the field before the number field was visited" <|
            \_ ->
                case run [ frequency "daily", ends "on" ] fresh of
                    Ok state ->
                        query [] state |> Query.hasNot [ Selector.text "Choose the date it ends." ]

                    Err message ->
                        Expect.fail message
        ]



-- setRule


setRuleTests : Test
setRuleTests =
    let
        loaded rule start =
            RecurrencePicker.setRule (Just rule) (RecurrencePicker.init id start)
    in
    describe "setRule"
        [ fuzz2 startFuzzer paramsFuzzer "value gives back the rule that was put in, whatever the start date" <|
            \start params ->
                case Reference.build start params of
                    Ok rule ->
                        Expect.equal (Just rule) (RecurrencePicker.value (loaded rule (date 2026 10 20)))

                    Err problem ->
                        Expect.fail (Recurrence.problemText Locale.en problem)
        , fuzz2 startFuzzer paramsFuzzer "and the same when the start date is the start of the rule" <|
            \start params ->
                case Reference.build start params of
                    Ok rule ->
                        Expect.equal (Just rule) (RecurrencePicker.value (loaded rule start))

                    Err problem ->
                        Expect.fail (Recurrence.problemText Locale.en problem)
        , test "Nothing is a field that does not repeat" <|
            \_ ->
                Expect.equal Nothing
                    (RecurrencePicker.value (RecurrencePicker.setRule Nothing (run [ frequency "daily" ] fresh |> Result.withDefault fresh)))
        , test "a rule whose day the start does not give is shown as it is" <|
            \_ ->
                case Recurrence.rule (Recurrence.monthlyOnDay 15) [] of
                    Ok rule ->
                        query []
                            (loaded rule (date 2026 10 20))
                            |> Query.find [ Selector.id (id ++ "-by-group") ]
                            |> Query.has
                                [ Selector.text "On day 15 of the month"
                                , Selector.text "On day 20 of the month"
                                ]

                    Err problem ->
                        Expect.fail (Recurrence.problemText Locale.en problem)
        , test "the skipped dates of the rule are kept when the user changes the rule" <|
            \_ ->
                case Recurrence.rule Recurrence.daily [ Recurrence.except [ date 2026 10 21 ] ] of
                    Ok rule ->
                        Expect.equal (Ok [ date 2026 10 21 ])
                            (run [ frequency "weekly" ] (loaded rule (date 2026 10 20))
                                |> Result.map (RecurrencePicker.value >> Maybe.map Recurrence.exceptions >> Maybe.withDefault [])
                            )

                    Err problem ->
                        Expect.fail (Recurrence.problemText Locale.en problem)
        , test "the weekdays of a loaded rule are shown ticked" <|
            \_ ->
                case Recurrence.rule (Recurrence.weekly Mon [ Thu ]) [ Recurrence.every 2 ] of
                    Ok rule ->
                        let
                            state =
                                loaded rule (date 2026 10 19)
                        in
                        Expect.all
                            [ \_ -> Query.has [ Selector.checked True ] (query [] state |> Query.find [ Selector.id (id ++ "-weekdays") ])
                            , \_ -> Query.has [ Selector.checked True ] (query [] state |> Query.find [ Selector.id (id ++ "-weekdays-3") ])
                            , \_ -> Query.has [ Selector.checked False ] (query [] state |> Query.find [ Selector.id (id ++ "-weekdays-1") ])
                            ]
                            ()

                    Err problem ->
                        Expect.fail (Recurrence.problemText Locale.en problem)
        ]



-- TEXT


textTests : Test
textTests =
    let
        summary attributes state =
            query attributes state |> Query.find [ Selector.id (id ++ "-summary") ]
    in
    describe "the sentence"
        [ test "says that the date does not repeat" <|
            \_ ->
                summary [] fresh |> Query.has [ Selector.text "Does not repeat" ]
        , test "describes the rule, as Klar.Recurrence does" <|
            \_ ->
                case run [ frequency "weekly", tick 4 True, typeInto (id ++ "-interval") "2" ] fresh of
                    Ok state ->
                        summary [] state |> Query.has [ Selector.text "Every 2 weeks on Tuesday and Thursday" ]

                    Err message ->
                        Expect.fail message
        , test "in Norwegian" <|
            \_ ->
                case run [ frequency "weekly", tick 4 True, typeInto (id ++ "-interval") "2" ] fresh of
                    Ok state ->
                        summary [ RecurrencePicker.locale Locale.nb ] state
                            |> Query.has [ Selector.text "Hver andre uke på tirsdag og torsdag" ]

                    Err message ->
                        Expect.fail message
        , test "is empty while the form is incomplete" <|
            \_ ->
                case run [ frequency "daily", typeInto (id ++ "-interval") "" ] fresh of
                    Ok state ->
                        summary [] state |> Query.hasNot [ Selector.containing [ Selector.text "Every" ] ]

                    Err message ->
                        Expect.fail message
        , test "the frequency choices are in Norwegian" <|
            \_ ->
                query [ RecurrencePicker.locale Locale.nb ] fresh
                    |> Query.has [ Selector.text "Gjentas ikke", Selector.text "Daglig", Selector.text "Ukentlig", Selector.text "Månedlig", Selector.text "Årlig" ]
        , test "the interval has the right words: 1 week, 2 weeks, in both languages" <|
            \_ ->
                Expect.all
                    [ \_ ->
                        query [] (runOrFresh [ frequency "weekly", typeInto (id ++ "-interval") "1" ] fresh)
                            |> Query.has [ Selector.text "Every", Selector.text "week" ]
                    , \_ ->
                        query [ RecurrencePicker.locale Locale.nb ] (runOrFresh [ frequency "yearly", typeInto (id ++ "-interval") "2" ] fresh)
                            |> Query.has [ Selector.text "Hvert", Selector.text "år" ]
                    ]
                    ()
        ]



-- MARKUP


markupTests : Test
markupTests =
    let
        weekly =
            runOrFresh [ frequency "weekly" ] fresh
    in
    describe "markup"
        [ test "the field is a fieldset with a legend" <|
            \_ ->
                query [ RecurrencePicker.label "Standing order" ] fresh
                    |> Expect.all
                        [ Query.has [ Selector.tag "fieldset", Selector.id (id ++ "-fieldset") ]
                        , Query.find [ Selector.tag "legend" ] >> Query.has [ Selector.text "Standing order", Selector.id (id ++ "-label") ]
                        ]
        , test "without a label the legend is the built-in word, for screen readers only" <|
            \_ ->
                query [] fresh
                    |> Query.find [ Selector.tag "legend" ]
                    |> Query.has [ Selector.text "Repeat", Selector.class "klar-sr-only" ]
        , test "the choice of frequency is a radio group with a name, and its first radio has the id of the field" <|
            \_ ->
                query [] fresh
                    |> Query.find [ Selector.id (id ++ "-group") ]
                    |> Expect.all
                        [ Query.has [ Selector.attribute (Attr.attribute "role" "radiogroup"), Selector.attribute (Attr.attribute "aria-label" "Frequency") ]
                        , Query.findAll [ Selector.tag "input", Selector.attribute (Attr.type_ "radio") ] >> Query.count (Expect.equal 5)
                        ]
        , test "the id of the field is on an input, so an error summary can move focus there" <|
            \_ ->
                query [] fresh
                    |> Query.find [ Selector.id id ]
                    |> Query.has [ Selector.tag "input" ]
        , test "the sentence is the only live region with aria-live" <|
            \_ ->
                query [] weekly
                    |> Query.findAll [ Selector.attribute (Attr.attribute "aria-live" "polite") ]
                    |> Query.count (Expect.equal 1)
        , test "and it is the sentence" <|
            \_ ->
                query [] weekly
                    |> Query.find [ Selector.attribute (Attr.attribute "aria-live" "polite") ]
                    |> Query.has [ Selector.id (id ++ "-summary") ]
        , test "the list of dates is not a live region" <|
            \_ ->
                query [] weekly
                    |> Query.find [ Selector.id (id ++ "-preview") ]
                    |> Query.hasNot [ Selector.attribute (Attr.attribute "aria-live" "polite") ]
        , test "the hint and the error describe the group and exist" <|
            \_ ->
                query [ RecurrencePicker.hint "Pick a pattern", RecurrencePicker.error "Choose how it repeats" ] fresh
                    |> Expect.all
                        [ Query.find [ Selector.tag "fieldset" ]
                            >> Query.has [ Selector.attribute (Attr.attribute "aria-describedby" (id ++ "-hint " ++ id ++ "-error")) ]
                        , Query.find [ Selector.id (id ++ "-hint") ] >> Query.has [ Selector.text "Pick a pattern" ]
                        , Query.find [ Selector.id (id ++ "-error") ]
                            >> Query.has [ Selector.text "Choose how it repeats", Selector.attribute (Attr.attribute "role" "alert") ]
                        ]
        , test "the field is wrapped the same way with and without an error, so focus stays" <|
            \_ ->
                let
                    wrapped attributes =
                        query attributes fresh
                            |> Expect.all
                                [ Query.has [ Selector.class "klar-field" ]
                                , Query.children [ Selector.tag "fieldset" ] >> Query.count (Expect.equal 1)
                                ]
                in
                Expect.all
                    [ \_ -> wrapped []
                    , \_ -> wrapped [ RecurrencePicker.error "Choose how it repeats" ]
                    , \_ -> wrapped [ RecurrencePicker.label "Repeat" ]
                    ]
                    ()
        , test "the frequency control is the first part, with and without the other parts" <|
            \_ ->
                let
                    firstChild state =
                        query [] state
                            |> Query.find [ Selector.class "klar-recurrence__body" ]
                            |> Query.children []
                            |> Query.first
                            |> Query.has [ Selector.class "klar-segmented-field" ]
                in
                Expect.all
                    [ \_ -> firstChild fresh
                    , \_ -> firstChild weekly
                    , \_ -> firstChild (runOrFresh [ frequency "monthly", ends "on" ] fresh)
                    ]
                    ()
        , test "the parts keep their ids when the frequency changes" <|
            \_ ->
                let
                    has theId state =
                        query [] state |> Query.has [ Selector.id theId ]
                in
                Expect.all
                    [ \_ -> has (id ++ "-summary") fresh
                    , \_ -> has (id ++ "-summary") weekly
                    , \_ -> has (id ++ "-interval") weekly
                    , \_ -> has (id ++ "-interval") (runOrFresh [ frequency "yearly" ] fresh)
                    , \_ -> has (id ++ "-end") weekly
                    ]
                    ()
        , test "every control gets the size, the language and disabled of the field" <|
            \_ ->
                query [ RecurrencePicker.disabled True ] weekly
                    |> Query.findAll [ Selector.tag "input", Selector.disabled False ]
                    |> Query.count (Expect.equal 0)
        , test "a read-only field shows the label and the sentence and nothing to change" <|
            \_ ->
                let
                    state =
                        runOrFresh [ frequency "weekly" ] fresh

                    html =
                        query [ RecurrencePicker.readOnly True, RecurrencePicker.label "Repeat" ] state
                in
                Expect.all
                    [ Query.findAll [ Selector.tag "input" ] >> Query.count (Expect.equal 0)
                    , Query.findAll [ Selector.tag "button" ] >> Query.count (Expect.equal 0)
                    , Query.has [ Selector.text "Weekly on Tuesday", Selector.text "Repeat" ]
                    , Query.findAll [ Selector.attribute (Attr.attribute "aria-live" "polite") ] >> Query.count (Expect.equal 0)
                    ]
                    html
        , test "a read-only field that does not repeat says so" <|
            \_ ->
                query [ RecurrencePicker.readOnly True ] fresh
                    |> Query.has [ Selector.text "Does not repeat" ]
        , test "required marks the legend" <|
            \_ ->
                query [ RecurrencePicker.label "Repeat", RecurrencePicker.required ] fresh
                    |> Query.find [ Selector.tag "legend" ]
                    |> Query.has [ Selector.class "klar-field__required" ]
        ]



-- THE NEXT DATES


previewTests : Test
previewTests =
    let
        dates attributes state =
            query attributes state
                |> Query.find [ Selector.id (id ++ "-preview") ]
                |> Query.findAll [ Selector.tag "time" ]

        titles state attributes =
            query attributes state |> Query.find [ Selector.id (id ++ "-preview") ]
    in
    describe "the next dates"
        [ test "five dates for a rule that goes on" <|
            \_ ->
                dates [] (runOrFresh [ frequency "daily" ] fresh)
                    |> Query.count (Expect.equal 5)
        , test "they are written as dates, with the weekday" <|
            \_ ->
                dates [] (runOrFresh [ frequency "weekly" ] fresh)
                    |> Query.first
                    |> Query.has [ Selector.text "Tuesday 20 October 2026", Selector.attribute (Attr.attribute "datetime" "2026-10-20") ]
        , test "and in Norwegian" <|
            \_ ->
                dates [ RecurrencePicker.locale Locale.nb ] (runOrFresh [ frequency "weekly" ] fresh)
                    |> Query.first
                    |> Query.has [ Selector.text "tirsdag 20. oktober 2026" ]
        , test "a rule that goes on says that there are more" <|
            \_ ->
                titles (runOrFresh [ frequency "daily" ] fresh) []
                    |> Query.has [ Selector.text "and more" ]
        , test "a rule that ends after three dates shows three and no more" <|
            \_ ->
                let
                    state =
                        runOrFresh [ frequency "daily", ends "after", typeInto (id ++ "-count") "3" ] fresh
                in
                Expect.all
                    [ \_ -> dates [] state |> Query.count (Expect.equal 3)
                    , \_ -> titles state [] |> Query.hasNot [ Selector.text "and more" ]
                    ]
                    ()
        , test "a rule with no dates says so" <|
            \_ ->
                -- 29 February, skipped in the years without it, every second year from an odd year
                case Recurrence.rule (Recurrence.yearlyOnDate Feb 29 |> Recurrence.skippingMissingDays) [ Recurrence.every 2 ] of
                    Ok rule ->
                        titles (RecurrencePicker.setRule (Just rule) (from 2025 2 1)) []
                            |> Expect.all
                                [ Query.has [ Selector.text "No dates match the rule." ]
                                , Query.findAll [ Selector.tag "time" ] >> Query.count (Expect.equal 0)
                                ]

                    Err problem ->
                        Expect.fail (Recurrence.problemText Locale.en problem)
        , test "the list starts at the start date, and says first" <|
            \_ ->
                titles (runOrFresh [ frequency "daily" ] fresh) []
                    |> Query.has [ Selector.text "First dates" ]
        , test "with today after the start the list starts at today and says next" <|
            \_ ->
                let
                    state =
                        runOrFresh [ frequency "daily" ] fresh
                in
                Expect.all
                    [ \_ -> titles state [ RecurrencePicker.today (date 2026 11 2) ] |> Query.has [ Selector.text "Next dates" ]
                    , \_ -> dates [ RecurrencePicker.today (date 2026 11 2) ] state |> Query.first |> Query.has [ Selector.text "2 November 2026" ]
                    ]
                    ()
        , test "there is no list while the form is incomplete or does not repeat" <|
            \_ ->
                Expect.all
                    [ \_ -> query [] fresh |> Query.findAll [ Selector.id (id ++ "-preview") ] |> Query.count (Expect.equal 0)
                    , \_ ->
                        query [] (runOrFresh [ frequency "daily", typeInto (id ++ "-interval") "" ] fresh)
                            |> Query.findAll [ Selector.id (id ++ "-preview") ]
                            |> Query.count (Expect.equal 0)
                    ]
                    ()
        ]
