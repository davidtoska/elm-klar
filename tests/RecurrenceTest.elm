module RecurrenceTest exposing (suite)

import Expect
import Fuzz exposing (Fuzzer)
import Klar.Date as Date exposing (Date)
import Klar.Locale as Locale
import Klar.Recurrence as Recurrence exposing (Rule)
import Klar.Recurrence.RRule as RRule
import Klar.Recurrence.Spec as Spec exposing (Problem(..), Reason(..))
import Support.RecurrenceFuzz exposing (paramsFuzzer, startFuzzer)
import Support.RecurrenceReference as Reference exposing (Ending(..), Params, date)
import Test exposing (Test, describe, fuzzWith, test)
import Time exposing (Month(..), Weekday(..))


suite : Test
suite =
    describe "Klar.Recurrence"
        [ wellKnownDates
        , monthEnds
        , startAndCounting
        , building
        , limits
        , rrule
        , rruleRejects
        , bounds
        , words
        , againstTheReference
        ]



-- HELPERS


type alias Built =
    Result Recurrence.Problem Rule


{-| Every helper answers with a `Result String`, so that a rule that could not be
built shows up as the text of its problem in the failing comparison, and the
expected values are written as `Ok`.
-}
text : Result Recurrence.Problem a -> Result String a
text =
    Result.mapError (Recurrence.problemText Locale.en)


iso : List Date -> List String
iso =
    List.map Date.toIso


dates : { start : Date, from : Date, limit : Int } -> Built -> Result String (List String)
dates window built =
    text (Result.map (Recurrence.occurrences window >> iso) built)


from : Date -> Int -> Built -> Result String (List String)
from start limit built =
    dates { start = start, from = start, limit = limit } built


build : Recurrence.Pattern -> List Recurrence.Option -> Built
build =
    Recurrence.rule


rruleOf : Built -> Result String String
rruleOf built =
    text (Result.map Recurrence.toRRule built)


describeIn : Locale.Locale -> Built -> Result String String
describeIn locale built =
    onRule (Recurrence.describe locale) built


onRule : (Rule -> a) -> Built -> Result String a
onRule change built =
    text (Result.map change built)


{-| The results of several questions, or the first problem.
-}
combine : List (Result String a) -> Result String (List a)
combine results =
    List.foldr (Result.map2 (::)) (Ok []) results



-- WELL-KNOWN DATES


wellKnownDates : Test
wellKnownDates =
    describe "well-known rules"
        [ test "every day" <|
            \_ ->
                Expect.equal (Ok [ "2026-10-20", "2026-10-21", "2026-10-22" ])
                    (from (date 2026 10 20) 3 (build Recurrence.daily []))
        , test "every third day" <|
            \_ ->
                Expect.equal (Ok [ "2026-10-20", "2026-10-23", "2026-10-26" ])
                    (from (date 2026 10 20) 3 (build Recurrence.daily [ Recurrence.every 3 ]))
        , test "every week on Monday and Thursday, from a Monday" <|
            \_ ->
                Expect.equal (Ok [ "2026-10-19", "2026-10-22", "2026-10-26", "2026-10-29" ])
                    (from (date 2026 10 19) 4 (build (Recurrence.weekly Mon [ Thu ]) []))
        , test "every second week on Monday and Thursday, from a Tuesday: the Monday before the start is not an occurrence" <|
            \_ ->
                Expect.equal (Ok [ "2026-10-22", "2026-11-02", "2026-11-05", "2026-11-16", "2026-11-19" ])
                    (from (date 2026 10 20) 5 (build (Recurrence.weekly Mon [ Thu ]) [ Recurrence.every 2 ]))
        , test "weeks are counted from Monday: a Sunday belongs to the week before the next Monday" <|
            \_ ->
                -- start on Sunday 2026-10-25; every second week on Sunday and Monday
                Expect.equal (Ok [ "2026-10-25", "2026-11-02", "2026-11-08", "2026-11-16" ])
                    (from (date 2026 10 25) 4 (build (Recurrence.weekly Sun [ Mon ]) [ Recurrence.every 2 ]))
        , test "every weekday" <|
            \_ ->
                Expect.equal (Ok [ "2026-10-22", "2026-10-23", "2026-10-26", "2026-10-27" ])
                    (from (date 2026 10 22) 4 (build (Recurrence.weekly Mon [ Tue, Wed, Thu, Fri ]) []))
        , test "monthly on the 15th" <|
            \_ ->
                Expect.equal (Ok [ "2026-10-15", "2026-11-15", "2026-12-15", "2027-01-15" ])
                    (from (date 2026 10 1) 4 (build (Recurrence.monthlyOnDay 15) []))
        , test "every second month on the 15th, starting after the 15th" <|
            \_ ->
                Expect.equal (Ok [ "2026-12-15", "2027-02-15" ])
                    (from (date 2026 10 20) 2 (build (Recurrence.monthlyOnDay 15) [ Recurrence.every 2 ]))
        , test "the second Tuesday of every month" <|
            \_ ->
                Expect.equal (Ok [ "2026-10-13", "2026-11-10", "2026-12-08", "2027-01-12" ])
                    (from (date 2026 10 1) 4 (build (Recurrence.monthlyOnWeekday Recurrence.second Tue) []))
        , test "the last Friday of every month until the end of the year" <|
            \_ ->
                Expect.equal (Ok [ "2027-10-29", "2027-11-26", "2027-12-31" ])
                    (from (date 2027 10 1)
                        10
                        (build (Recurrence.monthlyOnWeekday Recurrence.last Fri)
                            [ Recurrence.ends (Recurrence.until (date 2027 12 31)) ]
                        )
                    )
        , test "the first Monday of every third month" <|
            \_ ->
                Expect.equal (Ok [ "2026-10-05", "2027-01-04", "2027-04-05" ])
                    (from (date 2026 10 1) 3 (build (Recurrence.monthlyOnWeekday Recurrence.first Mon) [ Recurrence.every 3 ]))
        , test "yearly on a date" <|
            \_ ->
                Expect.equal (Ok [ "2026-10-20", "2027-10-20", "2028-10-20" ])
                    (from (date 2026 1 1) 3 (build (Recurrence.yearlyOnDate Oct 20) []))
        , test "yearly on the third Tuesday of October" <|
            \_ ->
                Expect.equal (Ok [ "2026-10-20", "2027-10-19", "2028-10-17" ])
                    (from (date 2026 1 1) 3 (build (Recurrence.yearlyOnWeekday Recurrence.third Tue Oct) []))
        , test "every second year" <|
            \_ ->
                Expect.equal (Ok [ "2026-10-20", "2028-10-20", "2030-10-20" ])
                    (from (date 2026 1 1) 3 (build (Recurrence.yearlyOnDate Oct 20) [ Recurrence.every 2 ]))
        ]



-- MONTH ENDS


monthEnds : Test
monthEnds =
    describe "months and years that are too short"
        [ test "the 31st uses the last day of a shorter month by default" <|
            \_ ->
                Expect.equal (Ok [ "2026-01-31", "2026-02-28", "2026-03-31", "2026-04-30", "2026-05-31" ])
                    (from (date 2026 1 31) 5 (build (Recurrence.monthlyOnDay 31) []))
        , test "the 31st can skip the shorter months instead" <|
            \_ ->
                Expect.equal (Ok [ "2026-01-31", "2026-03-31", "2026-05-31", "2026-07-31", "2026-08-31" ])
                    (from (date 2026 1 31) 5 (build (Recurrence.monthlyOnDay 31 |> Recurrence.skippingMissingDays) []))
        , test "the 30th uses 28 February in a year without a 29th" <|
            \_ ->
                Expect.equal (Ok [ "2027-01-30", "2027-02-28", "2027-03-30", "2027-04-30" ])
                    (from (date 2027 1 30) 4 (build (Recurrence.monthlyOnDay 30) []))
        , test "the 30th uses 29 February in a leap year" <|
            \_ ->
                Expect.equal (Ok [ "2028-01-30", "2028-02-29", "2028-03-30" ])
                    (from (date 2028 1 30) 3 (build (Recurrence.monthlyOnDay 30) []))
        , test "29 February falls on 28 February in the years without it" <|
            \_ ->
                Expect.equal (Ok [ "2024-02-29", "2025-02-28", "2026-02-28", "2027-02-28", "2028-02-29" ])
                    (from (date 2024 2 29) 5 (build (Recurrence.yearlyOnDate Feb 29) []))
        , test "29 February can skip the years without it" <|
            \_ ->
                Expect.equal (Ok [ "2024-02-29", "2028-02-29", "2032-02-29" ])
                    (from (date 2024 2 29) 3 (build (Recurrence.yearlyOnDate Feb 29 |> Recurrence.skippingMissingDays) []))
        , test "skipping 29 February every second year from an odd year finds nothing, and does not hang" <|
            \_ ->
                Expect.equal (Ok [])
                    (from (date 2025 2 1) 5 (build (Recurrence.yearlyOnDate Feb 29 |> Recurrence.skippingMissingDays) [ Recurrence.every 2 ]))
        , test "skipping the 31st every twelfth month from February finds nothing and does not hang" <|
            \_ ->
                Expect.equal (Ok [])
                    (from (date 2026 2 1) 5 (build (Recurrence.monthlyOnDay 31 |> Recurrence.skippingMissingDays) [ Recurrence.every 12 ]))
        , test "skippingMissingDays changes nothing for a day every month has" <|
            \_ ->
                Expect.equal (build (Recurrence.monthlyOnDay 15) []) (build (Recurrence.monthlyOnDay 15 |> Recurrence.skippingMissingDays) [])
        , test "skippingMissingDays changes nothing for the other patterns" <|
            \_ ->
                Expect.equal (build Recurrence.daily []) (build (Recurrence.daily |> Recurrence.skippingMissingDays) [])
        ]



-- START, FROM AND COUNTING


startAndCounting : Test
startAndCounting =
    let
        daily3 =
            build Recurrence.daily [ Recurrence.ends (Recurrence.after 3) ]
    in
    describe "the start, the window and the count"
        [ test "after 3 occurrences counts from the start, also when the window starts later" <|
            \_ ->
                Expect.equal (Ok [ "2026-10-22" ])
                    (dates { start = date 2026 10 20, from = date 2026 10 22, limit = 10 } daily3)
        , test "a window after the last occurrence is empty" <|
            \_ ->
                Expect.equal (Ok [])
                    (dates { start = date 2026 10 20, from = date 2026 10 23, limit = 10 } daily3)
        , test "a date before the start is never an occurrence" <|
            \_ ->
                Expect.equal (Ok [ "2026-10-20", "2026-10-21", "2026-10-22" ])
                    (dates { start = date 2026 10 20, from = date 2026 1 1, limit = 10 } daily3)
        , test "until is inclusive" <|
            \_ ->
                Expect.equal (Ok [ "2026-10-20", "2026-10-21", "2026-10-22" ])
                    (from (date 2026 10 20) 10 (build Recurrence.daily [ Recurrence.ends (Recurrence.until (date 2026 10 22)) ]))
        , test "until before the start gives no dates" <|
            \_ ->
                Expect.equal (Ok [])
                    (from (date 2026 10 20) 10 (build Recurrence.daily [ Recurrence.ends (Recurrence.until (date 2026 10 19)) ]))
        , test "a skipped date is left out but still counts towards after" <|
            \_ ->
                Expect.equal (Ok [ "2026-10-20", "2026-10-22" ])
                    (from (date 2026 10 20)
                        10
                        (build Recurrence.daily
                            [ Recurrence.ends (Recurrence.after 3)
                            , Recurrence.except [ date 2026 10 21 ]
                            ]
                        )
                    )
        , test "a weekly rule begins on the first matching day, not on the start" <|
            \_ ->
                Expect.equal (Ok [ "2026-10-26" ])
                    (from (date 2026 10 20) 1 (build (Recurrence.weekly Mon []) []))
        , test "isOccurrence" <|
            \_ ->
                let
                    built =
                        build (Recurrence.weekly Mon [ Thu ]) [ Recurrence.every 2, Recurrence.except [ date 2026 11 5 ] ]

                    isIt day =
                        onRule (Recurrence.isOccurrence { start = date 2026 10 20, date = day }) built
                in
                Expect.equal
                    (Ok [ False, True, False, True, False, False, True ])
                    (combine
                        [ isIt (date 2026 10 19) -- before the start
                        , isIt (date 2026 10 22)
                        , isIt (date 2026 10 29) -- the off week
                        , isIt (date 2026 11 2)
                        , isIt (date 2026 11 5) -- skipped
                        , isIt (date 2026 11 3) -- a Tuesday
                        , isIt (date 2026 11 16)
                        ]
                    )
        , test "next is the first occurrence after a date, the date itself not counted" <|
            \_ ->
                let
                    built =
                        build (Recurrence.weekly Mon []) []

                    after day =
                        onRule (Recurrence.next { start = date 2026 10 19, after = day } >> Maybe.map Date.toIso) built
                in
                Expect.equal
                    (Ok [ Just "2026-10-26", Just "2026-11-02", Just "2026-10-26" ])
                    (combine
                        [ after (date 2026 10 19)
                        , after (date 2026 10 26)
                        , after (date 2026 10 25)
                        ]
                    )
        , test "next is Nothing after the end" <|
            \_ ->
                Expect.equal (Ok Nothing)
                    (onRule (Recurrence.next { start = date 2026 10 20, after = date 2026 10 22 }) daily3)
        , test "count of a rule that ends" <|
            \_ ->
                Expect.equal
                    (Ok [ Just 3, Just 2, Just 4, Nothing ])
                    (combine
                        [ onRule (Recurrence.count { start = date 2026 10 20 }) daily3
                        , onRule (Recurrence.count { start = date 2026 10 20 })
                            (build Recurrence.daily [ Recurrence.ends (Recurrence.after 3), Recurrence.except [ date 2026 10 21 ] ])
                        , onRule (Recurrence.count { start = date 2026 10 19 })
                            (build (Recurrence.weekly Mon []) [ Recurrence.ends (Recurrence.until (date 2026 11 9)) ])
                        , onRule (Recurrence.count { start = date 2026 10 20 }) (build Recurrence.daily [])
                        ]
                    )
        , test "exceptions are kept in order and without duplicates" <|
            \_ ->
                Expect.equal (Ok [ "2026-10-21", "2026-10-25" ])
                    (onRule (Recurrence.exceptions >> iso)
                        (build Recurrence.daily [ Recurrence.except [ date 2026 10 25, date 2026 10 21, date 2026 10 25 ] ])
                    )
        , test "withExceptions replaces the skipped dates" <|
            \_ ->
                Expect.equal (Ok [ "2026-10-22" ])
                    (onRule (Recurrence.withExceptions [ date 2026 10 22 ] >> Recurrence.exceptions >> iso)
                        (build Recurrence.daily [ Recurrence.except [ date 2026 10 21 ] ])
                    )
        ]



-- BUILDING


building : Test
building =
    let
        problem result =
            case result of
                Ok _ ->
                    "no problem"

                Err value ->
                    Recurrence.problemText Locale.en value
    in
    describe "building a rule"
        [ test "an interval of 0 is a problem, not 1" <|
            \_ ->
                Expect.equal "How often it repeats must be a whole number, 1 or more, not 0."
                    (problem (Recurrence.rule Recurrence.daily [ Recurrence.every 0 ]))
        , test "a negative interval is a problem" <|
            \_ ->
                Expect.equal "How often it repeats must be a whole number, 1 or more, not -3."
                    (problem (Recurrence.rule (Recurrence.weekly Mon []) [ Recurrence.every -3 ]))
        , test "after 0 is a problem" <|
            \_ ->
                Expect.equal "The number of occurrences must be 1 or more, not 0."
                    (problem (Recurrence.rule Recurrence.daily [ Recurrence.ends (Recurrence.after 0) ]))
        , test "the 0th and the 32nd are problems" <|
            \_ ->
                Expect.equal
                    [ "The day of the month must be from 1 to 31, not 0.", "The day of the month must be from 1 to 31, not 32." ]
                    [ problem (Recurrence.rule (Recurrence.monthlyOnDay 0) [])
                    , problem (Recurrence.rule (Recurrence.monthlyOnDay 32) [])
                    ]
        , test "31 April and 30 February do not exist" <|
            \_ ->
                Expect.equal
                    [ "That date does not exist: 31 April.", "That date does not exist: 30 February." ]
                    [ problem (Recurrence.rule (Recurrence.yearlyOnDate Apr 31) [])
                    , problem (Recurrence.rule (Recurrence.yearlyOnDate Feb 30) [])
                    ]
        , test "29 February exists" <|
            \_ ->
                Expect.equal "no problem" (problem (Recurrence.rule (Recurrence.yearlyOnDate Feb 29) []))
        , test "the order of the options does not matter" <|
            \_ ->
                Expect.equal
                    (Recurrence.rule Recurrence.daily [ Recurrence.every 2, Recurrence.ends (Recurrence.after 5), Recurrence.except [ date 2026 1 1 ] ])
                    (Recurrence.rule Recurrence.daily [ Recurrence.except [ date 2026 1 1 ], Recurrence.ends (Recurrence.after 5), Recurrence.every 2 ])
        , test "a later option wins over an earlier one of the same kind" <|
            \_ ->
                Expect.equal
                    (Recurrence.rule Recurrence.daily [ Recurrence.every 3 ])
                    (Recurrence.rule Recurrence.daily [ Recurrence.every 0, Recurrence.every 3 ])
        , test "the order of the weekdays does not matter, nor do duplicates" <|
            \_ ->
                Expect.equal
                    (Recurrence.rule (Recurrence.weekly Mon [ Thu ]) [])
                    (Recurrence.rule (Recurrence.weekly Thu [ Mon, Thu ]) [])
        ]



-- LIMITS


limits : Test
limits =
    let
        everyDay =
            build Recurrence.daily []
    in
    describe "limits"
        [ test "a limit of 0 or less gives no dates" <|
            \_ ->
                Expect.equal (Ok [ [], [] ])
                    (combine
                        [ from (date 2026 1 1) 0 everyDay
                        , from (date 2026 1 1) -5 everyDay
                        ]
                    )
        , test "no call returns more than maxOccurrences" <|
            \_ ->
                Expect.equal (Ok [ 10000, 10000 ])
                    (combine
                        [ onRule (Recurrence.occurrences { start = date 2026 1 1, from = date 2026 1 1, limit = 1000000 } >> List.length) everyDay
                        , Ok Recurrence.maxOccurrences
                        ]
                    )
        , test "between says when it cut the result" <|
            \_ ->
                let
                    summary to =
                        onRule
                            (\rule ->
                                let
                                    found =
                                        Recurrence.between { start = date 2026 1 1, from = date 2026 1 1, to = to } rule
                                in
                                ( List.length found.dates, found.truncated )
                            )
                            everyDay
                in
                Expect.equal (Ok [ ( 10000, True ), ( 10, False ) ])
                    (combine [ summary (date 2100 1 1), summary (date 2026 1 10) ])
        , test "a daily rule over a hundred thousand years does not freeze and stops at the last day" <|
            \_ ->
                Expect.equal (Ok [ "9999-12-30", "9999-12-31" ])
                    (dates { start = date 9999 12 30, from = date 9999 12 30, limit = 10 } everyDay)
        , test "a yearly rule is found a century away without walking the days" <|
            \_ ->
                Expect.equal (Ok [ "2126-10-20", "2127-10-20" ])
                    (dates { start = date 2026 10 20, from = date 2126 1 1, limit = 2 } (build (Recurrence.yearlyOnDate Oct 20) []))
        , test "a rule with an end far in the future still gives the first dates at once" <|
            \_ ->
                Expect.equal (Ok [ "2026-01-01" ])
                    (from (date 2026 1 1) 1 (build Recurrence.daily [ Recurrence.ends (Recurrence.until (date 9999 12 31)) ]))
        , test "a count too large for the calendar ends at the last day" <|
            \_ ->
                Expect.equal (Ok [ "9999-12-31" ])
                    (dates { start = date 2026 1 1, from = date 9999 12 31, limit = 5 }
                        (build Recurrence.daily [ Recurrence.ends (Recurrence.after 1000000000) ])
                    )
        , test "a daily rule over a hundred years has more dates than count reports" <|
            \_ ->
                Expect.equal (Ok Nothing)
                    (onRule (Recurrence.count { start = date 2026 1 1 })
                        (build Recurrence.daily [ Recurrence.ends (Recurrence.until (date 2126 1 1)) ])
                    )
        ]



-- RRULE


rrule : Test
rrule =
    let
        written pattern options =
            rruleOf (build pattern options)

        read input =
            text (Result.map Recurrence.toRRule (Recurrence.fromRRule input))
    in
    describe "RRULE text"
        [ test "every day" <|
            \_ -> Expect.equal (Ok "FREQ=DAILY") (written Recurrence.daily [])
        , test "every second week on Monday and Thursday, ten times" <|
            \_ ->
                Expect.equal (Ok "FREQ=WEEKLY;INTERVAL=2;BYDAY=MO,TH;COUNT=10")
                    (written (Recurrence.weekly Thu [ Mon ]) [ Recurrence.every 2, Recurrence.ends (Recurrence.after 10) ])
        , test "a day of the month, and the last day" <|
            \_ ->
                Expect.equal
                    (Ok
                        [ "FREQ=MONTHLY;BYMONTHDAY=15"
                        , "FREQ=MONTHLY;BYMONTHDAY=-1"
                        , "FREQ=MONTHLY;BYMONTHDAY=31"
                        ]
                    )
                    (combine
                        [ written (Recurrence.monthlyOnDay 15) []
                        , written (Recurrence.monthlyOnDay 31) []
                        , written (Recurrence.monthlyOnDay 31 |> Recurrence.skippingMissingDays) []
                        ]
                    )
        , test "the 29th and the 30th with the last day of a shorter month" <|
            \_ ->
                Expect.equal
                    (Ok
                        [ "FREQ=MONTHLY;BYMONTHDAY=28,29;BYSETPOS=-1"
                        , "FREQ=MONTHLY;BYMONTHDAY=28,29,30;BYSETPOS=-1"
                        ]
                    )
                    (combine
                        [ written (Recurrence.monthlyOnDay 29) []
                        , written (Recurrence.monthlyOnDay 30) []
                        ]
                    )
        , test "the n-th weekday of the month, and the last" <|
            \_ ->
                Expect.equal
                    (Ok
                        [ "FREQ=MONTHLY;BYDAY=2TU"
                        , "FREQ=MONTHLY;BYDAY=-1FR;UNTIL=20271231"
                        ]
                    )
                    (combine
                        [ written (Recurrence.monthlyOnWeekday Recurrence.second Tue) []
                        , written (Recurrence.monthlyOnWeekday Recurrence.last Fri) [ Recurrence.ends (Recurrence.until (date 2027 12 31)) ]
                        ]
                    )
        , test "yearly" <|
            \_ ->
                Expect.equal
                    (Ok
                        [ "FREQ=YEARLY;BYMONTH=10;BYMONTHDAY=20"
                        , "FREQ=YEARLY;INTERVAL=2;BYMONTH=10;BYDAY=3TU"
                        , "FREQ=YEARLY;BYMONTH=2;BYMONTHDAY=28,29;BYSETPOS=-1"
                        , "FREQ=YEARLY;BYMONTH=2;BYMONTHDAY=29"
                        ]
                    )
                    (combine
                        [ written (Recurrence.yearlyOnDate Oct 20) []
                        , written (Recurrence.yearlyOnWeekday Recurrence.third Tue Oct) [ Recurrence.every 2 ]
                        , written (Recurrence.yearlyOnDate Feb 29) []
                        , written (Recurrence.yearlyOnDate Feb 29 |> Recurrence.skippingMissingDays) []
                        ]
                    )
        , test "skipped dates are not part of the RRULE" <|
            \_ ->
                Expect.equal (Ok "FREQ=DAILY")
                    (written Recurrence.daily [ Recurrence.except [ date 2026 1 1 ] ])
        , test "reading accepts a prefix, lower case, any order and any order of the days" <|
            \_ ->
                Expect.equal
                    (Ok "FREQ=WEEKLY;INTERVAL=2;BYDAY=MO,TH;COUNT=10")
                    (read " rrule:count=10;byday=th,mo;interval=2;freq=weekly ")
        , test "WKST is accepted where it cannot change the dates" <|
            \_ ->
                Expect.equal
                    (combine [ Ok "FREQ=WEEKLY;BYDAY=MO", Ok "FREQ=WEEKLY;INTERVAL=2;BYDAY=MO", Ok "FREQ=DAILY" ])
                    (combine
                        [ read "FREQ=WEEKLY;BYDAY=MO;WKST=SU"
                        , read "FREQ=WEEKLY;INTERVAL=2;BYDAY=MO;WKST=MO"
                        , read "FREQ=DAILY;WKST=SU"
                        ]
                    )
        , test "the clamped forms of the 30th and the last day are read back" <|
            \_ ->
                Expect.equal
                    (combine
                        [ Ok "FREQ=MONTHLY;BYMONTHDAY=28,29,30;BYSETPOS=-1"
                        , Ok "FREQ=MONTHLY;BYMONTHDAY=-1"
                        , Ok "FREQ=MONTHLY;BYMONTHDAY=-1"
                        ]
                    )
                    (combine
                        [ read "FREQ=MONTHLY;BYMONTHDAY=28,29,30;BYSETPOS=-1"
                        , read "FREQ=MONTHLY;BYMONTHDAY=-1"
                        , read "FREQ=MONTHLY;BYMONTHDAY=31,30,29,28;BYSETPOS=-1"
                        ]
                    )
        ]


rruleRejects : Test
rruleRejects =
    let
        rejects input expected =
            test ("rejects \"" ++ input ++ "\"") <|
                \_ -> Expect.equal (Err expected) (RRule.fromText input)
    in
    describe "RRULE text outside the subset is a problem that names it"
        [ rejects "" EmptyText
        , rejects "   " EmptyText
        , rejects "RRULE:" EmptyText
        , rejects "FREQ=HOURLY" (Unsupported "FREQ=HOURLY" Plain)
        , rejects "FREQ=SECONDLY;INTERVAL=5" (Unsupported "FREQ=SECONDLY" Plain)
        , rejects "FREQ=FORTNIGHTLY" (CannotRead "FREQ=FORTNIGHTLY")
        , rejects "INTERVAL=2" (MissingPart "FREQ")
        , rejects "FREQ=WEEKLY" (MissingPart "BYDAY")
        , rejects "FREQ=MONTHLY" (MissingPart "BYMONTHDAY or BYDAY")
        , rejects "FREQ=YEARLY" (MissingPart "BYMONTH")
        , rejects "FREQ=YEARLY;BYMONTH=10" (MissingPart "BYMONTHDAY or BYDAY")
        , rejects "FREQ=DAILY;INTERVAL=0" (IntervalTooSmall 0)
        , rejects "FREQ=DAILY;INTERVAL=-2" (CannotRead "INTERVAL=-2")
        , rejects "FREQ=DAILY;INTERVAL=x" (CannotRead "INTERVAL=x")
        , rejects "FREQ=DAILY;COUNT=0" (CountTooSmall 0)
        , rejects "FREQ=DAILY;COUNT=3;UNTIL=20271231" (Conflict "COUNT and UNTIL")
        , rejects "FREQ=DAILY;UNTIL=20271231T235959Z" (Unsupported "UNTIL=20271231T235959Z" UntilWithTime)
        , rejects "FREQ=DAILY;UNTIL=20271331" (CannotRead "UNTIL=20271331")
        , rejects "FREQ=DAILY;UNTIL=2027" (CannotRead "UNTIL=2027")
        , rejects "FREQ=DAILY;FREQ=DAILY" (RepeatedPart "FREQ")
        , rejects "FREQ=DAILY;BYHOUR=9" (Unsupported "BYHOUR" Plain)
        , rejects "FREQ=DAILY;X-NOTE=1" (Unsupported "X-NOTE" Plain)
        , rejects "FREQ=DAILY;INTERVAL=2;BYDAY=MO" (Unsupported "BYDAY" DaysWithDailyInterval)
        , rejects "FREQ=DAILY;BYDAY=1MO" (Unsupported "BYDAY=1MO" (With "FREQ=DAILY"))
        , rejects "FREQ=DAILY;BYDAY=MO;BYMONTH=1" (Unsupported "BYMONTH" (With "FREQ=DAILY"))
        , rejects "FREQ=DAILY;BYSETPOS=1" (Unsupported "BYSETPOS" (With "FREQ=DAILY"))
        , rejects "FREQ=WEEKLY;BYDAY=1MO" (Unsupported "BYDAY=1MO" (With "FREQ=WEEKLY"))
        , rejects "FREQ=WEEKLY;BYDAY=XX" (CannotRead "BYDAY=XX")
        , rejects "FREQ=WEEKLY;BYDAY=MO;BYMONTH=1" (Unsupported "BYMONTH" (With "FREQ=WEEKLY"))
        , rejects "FREQ=WEEKLY;INTERVAL=2;BYDAY=MO;WKST=SU" (Unsupported "WKST=SU" WeekStartWithInterval)
        , rejects "FREQ=WEEKLY;BYDAY=MO;WKST=XX" (CannotRead "WKST=XX")
        , rejects "FREQ=MONTHLY;BYDAY=5TU" (Unsupported "BYDAY=5TU" OrdinalBeyondFourth)
        , rejects "FREQ=MONTHLY;BYDAY=-2TU" (Unsupported "BYDAY=-2TU" OrdinalBeyondFourth)
        , rejects "FREQ=MONTHLY;BYDAY=MO" (Unsupported "BYDAY=MO" (EveryWeekdayOf "FREQ=MONTHLY" "2MO"))
        , rejects "FREQ=MONTHLY;BYDAY=1MO,2TU" (Unsupported "BYDAY" (SeveralDaysWith "FREQ=MONTHLY"))
        , rejects "FREQ=MONTHLY;BYMONTHDAY=1,15" (Unsupported "BYMONTHDAY" SeveralDays)
        , rejects "FREQ=MONTHLY;BYMONTHDAY=-2" (Unsupported "BYMONTHDAY=-2" Plain)
        , rejects "FREQ=MONTHLY;BYMONTHDAY=32" (DayOutOfRange 32)
        , rejects "FREQ=MONTHLY;BYMONTHDAY=0" (DayOutOfRange 0)
        , rejects "FREQ=MONTHLY;BYMONTHDAY=15;BYDAY=2TU" (Unsupported "BYMONTHDAY" (With "BYDAY"))
        , rejects "FREQ=MONTHLY;BYMONTH=3;BYMONTHDAY=15" (Unsupported "BYMONTH" (With "FREQ=MONTHLY"))
        , rejects "FREQ=MONTHLY;BYMONTHDAY=15;BYSETPOS=-1" (Unsupported "BYMONTHDAY=15" LastFromDay28)
        , rejects "FREQ=MONTHLY;BYMONTHDAY=29,30;BYSETPOS=-1" (Unsupported "BYMONTHDAY=29,30" LastFromDay28)
        , rejects "FREQ=MONTHLY;BYMONTHDAY=28,29,30,31;BYSETPOS=1" (Unsupported "BYSETPOS=1" Plain)
        , rejects "FREQ=MONTHLY;BYDAY=2TU;BYSETPOS=1" (Unsupported "BYSETPOS=1" (With "BYDAY"))
        , rejects "FREQ=YEARLY;BYMONTH=13;BYMONTHDAY=1" (MonthOutOfRange 13)
        , rejects "FREQ=YEARLY;BYMONTH=1,2;BYMONTHDAY=1" (Unsupported "BYMONTH" SeveralMonths)
        , rejects "FREQ=YEARLY;BYMONTH=4;BYMONTHDAY=31" (NoSuchDate 4 31)
        , rejects "FREQ=DAILY;INTERVAL=2147483648" IntervalTooLarge
        , rejects "FREQ=DAILY;INTERVAL=99999999999999999999" IntervalTooLarge
        , rejects "FREQ=DAILY;COUNT=2147483648" CountTooLarge
        , rejects "FREQ=DAILY;COUNT=99999999999999999999" CountTooLarge
        , rejects "FREQ=MONTHLY;BYMONTHDAY=99999999999999999999" (DayOutOfRange 999999999999)
        , rejects "FREQ=YEARLY;BYMONTH=4;BYMONTHDAY=28,29,30,31;BYSETPOS=1" (Unsupported "BYSETPOS=1" Plain)
        , rejects "this is not a rule" (CannotRead "this is not a rule")
        , rejects "FREQ=DAILY\nCOUNT=3" (Unsupported "" SeveralLines)
        , rejects "DTSTART:20261020T090000Z" (Unsupported "DTSTART" OutsideRule)
        ]



-- BOUNDS AND INTEROP


bounds : Test
bounds =
    let
        problem result =
            case result of
                Ok _ ->
                    "no problem"

                Err value ->
                    Recurrence.problemText Locale.en value

        read input =
            text (Result.map Recurrence.toRRule (Recurrence.fromRRule input))
    in
    describe "bounds and interchange"
        [ test "the largest interval and count are accepted and survive the RRULE" <|
            \_ ->
                Expect.equal (Ok "FREQ=DAILY;INTERVAL=2147483647;COUNT=2147483647")
                    (rruleOf (build Recurrence.daily [ Recurrence.every 2147483647, Recurrence.ends (Recurrence.after 2147483647) ])
                        |> Result.andThen read
                    )
        , test "one more is a problem, and is not clamped" <|
            \_ ->
                Expect.equal
                    [ "How often it repeats cannot be more than 2147483647."
                    , "The number of occurrences cannot be more than 2147483647."
                    ]
                    [ problem (Recurrence.rule Recurrence.daily [ Recurrence.every 2147483648 ])
                    , problem (Recurrence.rule Recurrence.daily [ Recurrence.ends (Recurrence.after 2147483648) ])
                    ]
        , test "a huge number in an RRULE is a problem, not a different number" <|
            \_ ->
                Expect.equal
                    (Err "How often it repeats cannot be more than 2147483647.")
                    (read "FREQ=DAILY;INTERVAL=99999999999999999999")
        , test "leading zeros do not make a number large" <|
            \_ ->
                Expect.equal (Ok "FREQ=DAILY;INTERVAL=7") (read "FREQ=DAILY;INTERVAL=0000000000000000007")
        , test "a daily rule with the largest interval has its first date and no second" <|
            \_ ->
                Expect.equal (Ok [ "2026-10-20" ])
                    (from (date 2026 10 20) 5 (build Recurrence.daily [ Recurrence.every 2147483647 ]))
        , test "the largest interval of a weekly, monthly and yearly rule does not hang" <|
            \_ ->
                Expect.equal (Ok [ [ "2026-10-20" ], [ "2026-10-20" ], [ "2026-10-20" ] ])
                    (combine
                        [ from (date 2026 10 20) 5 (build (Recurrence.weekly Tue []) [ Recurrence.every 2147483647 ])
                        , from (date 2026 10 20) 5 (build (Recurrence.monthlyOnDay 20) [ Recurrence.every 2147483647 ])
                        , from (date 2026 10 20) 5 (build (Recurrence.yearlyOnDate Oct 20) [ Recurrence.every 2147483647 ])
                        ]
                    )
        , test "an end date in the year 9999 is fine, and in the year 10000 is a problem" <|
            \_ ->
                Expect.equal
                    [ "no problem", "The end date must be in the year 9999 or earlier." ]
                    [ problem (Recurrence.rule Recurrence.daily [ Recurrence.ends (Recurrence.until (date 9999 12 31)) ])
                    , problem (Recurrence.rule Recurrence.daily [ Recurrence.ends (Recurrence.until (date 10000 1 1)) ])
                    ]
        , test "the last possible end date goes through the RRULE and back" <|
            \_ ->
                Expect.equal (Ok "FREQ=DAILY;UNTIL=99991231")
                    (rruleOf (build Recurrence.daily [ Recurrence.ends (Recurrence.until (date 9999 12 31)) ]) |> Result.andThen read)
        , test "every weekday written as a daily rule with BYDAY is the weekly rule" <|
            \_ ->
                Expect.equal
                    (Ok ( "FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR", "Every weekday" ))
                    (Recurrence.fromRRule "FREQ=DAILY;BYDAY=MO,TU,WE,TH,FR"
                        |> Result.map (\rule -> ( Recurrence.toRRule rule, Recurrence.describe Locale.en rule ))
                        |> Result.mapError (Recurrence.problemText Locale.en)
                    )
        , test "and equals the weekly rule that was built" <|
            \_ ->
                Expect.equal (build (Recurrence.weekly Mon [ Tue, Wed, Thu, Fri ]) [])
                    (Recurrence.fromRRule "FREQ=DAILY;BYDAY=FR,MO,TU,WE,TH")
        , test "the last day of a month, every year" <|
            \_ ->
                Expect.equal
                    (Ok
                        [ ( "FREQ=YEARLY;BYMONTH=3;BYMONTHDAY=31", "Yearly on 31 March" )
                        , ( "FREQ=YEARLY;BYMONTH=4;BYMONTHDAY=30", "Yearly on 30 April" )
                        , ( "FREQ=YEARLY;BYMONTH=2;BYMONTHDAY=28,29;BYSETPOS=-1", "Yearly on 29 February (28 February in other years)" )
                        ]
                    )
                    (combine
                        (List.map
                            (\input ->
                                Recurrence.fromRRule input
                                    |> Result.map (\rule -> ( Recurrence.toRRule rule, Recurrence.describe Locale.en rule ))
                                    |> Result.mapError (Recurrence.problemText Locale.en)
                            )
                            [ "FREQ=YEARLY;BYMONTH=3;BYMONTHDAY=-1"
                            , "FREQ=YEARLY;BYMONTH=4;BYMONTHDAY=-1"
                            , "FREQ=YEARLY;BYMONTH=2;BYMONTHDAY=-1"
                            ]
                        )
                    )
        , test "the last day of February has the dates of the last day of February" <|
            \_ ->
                Expect.equal (Ok [ "2027-02-28", "2028-02-29", "2029-02-28" ])
                    (case Recurrence.fromRRule "FREQ=YEARLY;BYMONTH=2;BYMONTHDAY=-1" of
                        Ok rule ->
                            Ok (iso (Recurrence.occurrences { start = date 2027 1 1, from = date 2027 1 1, limit = 3 } rule))

                        Err problem_ ->
                            Err (Recurrence.problemText Locale.en problem_)
                    )
        , test "isEndless tells a rule without an end from the others" <|
            \_ ->
                Expect.equal (Ok [ True, False, False ])
                    (combine
                        [ onRule Recurrence.isEndless (build Recurrence.daily [])
                        , onRule Recurrence.isEndless (build Recurrence.daily [ Recurrence.ends (Recurrence.after 3) ])
                        , onRule Recurrence.isEndless (build Recurrence.daily [ Recurrence.ends (Recurrence.until (date 2027 1 1)) ])
                        ]
                    )
        , test "weekly on all seven days is its own rule, not daily" <|
            \_ ->
                Expect.notEqual (build Recurrence.daily [])
                    (build (Recurrence.weekly Mon [ Tue, Wed, Thu, Fri, Sat, Sun ]) [])
        ]



-- WORDS


words : Test
words =
    let
        both pattern options =
            let
                built =
                    build pattern options
            in
            Result.map2 Tuple.pair (describeIn Locale.en built) (describeIn Locale.nb built)
    in
    describe "describe"
        [ test "every day" <|
            \_ -> Expect.equal (Ok ( "Every day", "Hver dag" )) (both Recurrence.daily [])
        , test "every second day, every third day, every thirteenth day" <|
            \_ ->
                Expect.equal
                    (Ok
                        [ ( "Every 2 days", "Hver andre dag" )
                        , ( "Every 3 days", "Hver tredje dag" )
                        , ( "Every 13 days", "Hver 13. dag" )
                        ]
                    )
                    (combine
                        [ both Recurrence.daily [ Recurrence.every 2 ]
                        , both Recurrence.daily [ Recurrence.every 3 ]
                        , both Recurrence.daily [ Recurrence.every 13 ]
                        ]
                    )
        , test "weekly" <|
            \_ ->
                Expect.equal
                    (Ok
                        [ ( "Weekly on Monday", "Hver mandag" )
                        , ( "Every 2 weeks on Monday and Thursday", "Hver andre uke på mandag og torsdag" )
                        , ( "Weekly on Monday, Wednesday and Friday", "Ukentlig på mandag, onsdag og fredag" )
                        ]
                    )
                    (combine
                        [ both (Recurrence.weekly Mon []) []
                        , both (Recurrence.weekly Thu [ Mon ]) [ Recurrence.every 2 ]
                        , both (Recurrence.weekly Fri [ Mon, Wed ]) []
                        ]
                    )
        , test "every weekday and every day of the week" <|
            \_ ->
                Expect.equal
                    (Ok
                        [ ( "Every weekday", "Hver ukedag" )
                        , ( "Every day", "Hver dag" )
                        , ( "Every 2 weeks on weekdays", "Hver andre uke på ukedager" )
                        ]
                    )
                    (combine
                        [ both (Recurrence.weekly Mon [ Tue, Wed, Thu, Fri ]) []
                        , both (Recurrence.weekly Mon [ Tue, Wed, Thu, Fri, Sat, Sun ]) []
                        , both (Recurrence.weekly Mon [ Tue, Wed, Thu, Fri ]) [ Recurrence.every 2 ]
                        ]
                    )
        , test "monthly on a day" <|
            \_ ->
                Expect.equal
                    (Ok
                        [ ( "Monthly on the 15th", "Månedlig den 15." )
                        , ( "Every 3 months on the 1st", "Hver tredje måned den 1." )
                        , ( "Monthly on the 22nd", "Månedlig den 22." )
                        , ( "Monthly on the 23rd", "Månedlig den 23." )
                        ]
                    )
                    (combine
                        [ both (Recurrence.monthlyOnDay 15) []
                        , both (Recurrence.monthlyOnDay 1) [ Recurrence.every 3 ]
                        , both (Recurrence.monthlyOnDay 22) []
                        , both (Recurrence.monthlyOnDay 23) []
                        ]
                    )
        , test "the days that some months do not have say what happens" <|
            \_ ->
                Expect.equal
                    (Ok
                        [ ( "On the last day of every month", "Siste dag i hver måned" )
                        , ( "Monthly on the 31st (months without it are skipped)", "Månedlig den 31. (måneder uten denne dagen hoppes over)" )
                        , ( "Monthly on the 30th (or the last day of shorter months)", "Månedlig den 30. (eller siste dag i kortere måneder)" )
                        , ( "Every 2 months on the last day", "Hver andre måned den siste dagen" )
                        ]
                    )
                    (combine
                        [ both (Recurrence.monthlyOnDay 31) []
                        , both (Recurrence.monthlyOnDay 31 |> Recurrence.skippingMissingDays) []
                        , both (Recurrence.monthlyOnDay 30) []
                        , both (Recurrence.monthlyOnDay 31) [ Recurrence.every 2 ]
                        ]
                    )
        , test "the n-th weekday of the month" <|
            \_ ->
                Expect.equal
                    (Ok
                        [ ( "On the second Tuesday of every month", "Den andre tirsdagen i hver måned" )
                        , ( "On the last Friday of every month through 31 December 2027", "Den siste fredagen i hver måned til og med 31. desember 2027" )
                        , ( "Every 2 months on the first Monday", "Hver andre måned den første mandagen" )
                        ]
                    )
                    (combine
                        [ both (Recurrence.monthlyOnWeekday Recurrence.second Tue) []
                        , both (Recurrence.monthlyOnWeekday Recurrence.last Fri) [ Recurrence.ends (Recurrence.until (date 2027 12 31)) ]
                        , both (Recurrence.monthlyOnWeekday Recurrence.first Mon) [ Recurrence.every 2 ]
                        ]
                    )
        , test "yearly" <|
            \_ ->
                Expect.equal
                    (Ok
                        [ ( "Yearly on 20 October", "Årlig 20. oktober" )
                        , ( "Every 2 years on 20 October", "Hvert annet år 20. oktober" )
                        , ( "Yearly on 29 February (28 February in other years)", "Årlig 29. februar (28. februar i år uten skuddag)" )
                        , ( "Yearly on 29 February (leap years only)", "Årlig 29. februar (bare skuddår)" )
                        , ( "On the third Tuesday of October every year", "Den tredje tirsdagen i oktober hvert år" )
                        , ( "Every 3 years on the last Friday of March", "Hvert tredje år den siste fredagen i mars" )
                        ]
                    )
                    (combine
                        [ both (Recurrence.yearlyOnDate Oct 20) []
                        , both (Recurrence.yearlyOnDate Oct 20) [ Recurrence.every 2 ]
                        , both (Recurrence.yearlyOnDate Feb 29) []
                        , both (Recurrence.yearlyOnDate Feb 29 |> Recurrence.skippingMissingDays) []
                        , both (Recurrence.yearlyOnWeekday Recurrence.third Tue Oct) []
                        , both (Recurrence.yearlyOnWeekday Recurrence.last Fri Mar) [ Recurrence.every 3 ]
                        ]
                    )
        , test "the end and the skipped dates" <|
            \_ ->
                Expect.equal
                    (Ok
                        [ ( "Every day, once", "Hver dag, én gang" )
                        , ( "Every day, 10 times", "Hver dag, 10 ganger" )
                        , ( "Every day through 31 December 2027", "Hver dag til og med 31. desember 2027" )
                        , ( "Every day, except 1 date", "Hver dag, unntatt 1 dato" )
                        , ( "Every day, 5 times, except 2 dates", "Hver dag, 5 ganger, unntatt 2 datoer" )
                        ]
                    )
                    (combine
                        [ both Recurrence.daily [ Recurrence.ends (Recurrence.after 1) ]
                        , both Recurrence.daily [ Recurrence.ends (Recurrence.after 10) ]
                        , both Recurrence.daily [ Recurrence.ends (Recurrence.until (date 2027 12 31)) ]
                        , both Recurrence.daily [ Recurrence.except [ date 2026 1 1 ] ]
                        , both Recurrence.daily [ Recurrence.ends (Recurrence.after 5), Recurrence.except [ date 2026 1 1, date 2026 1 2 ] ]
                        ]
                    )
        , test "problems have words in both languages" <|
            \_ ->
                case Recurrence.fromRRule "FREQ=HOURLY" of
                    Err problem ->
                        Expect.equal
                            ( "Not supported in a recurrence rule: FREQ=HOURLY.", "Støttes ikke i en gjentakelsesregel: FREQ=HOURLY." )
                            ( Recurrence.problemText Locale.en problem, Recurrence.problemText Locale.nb problem )

                    Ok _ ->
                        Expect.fail "FREQ=HOURLY must not be read"
        , test "a Norwegian problem text of an RRULE has no English words in it" <|
            \_ ->
                [ "FREQ=DAILY;UNTIL=20271231T235959Z"
                , "FREQ=DAILY;INTERVAL=2;BYDAY=MO"
                , "FREQ=DAILY;BYDAY=1MO"
                , "FREQ=WEEKLY;INTERVAL=2;BYDAY=MO;WKST=SU"
                , "FREQ=MONTHLY;BYDAY=5TU"
                , "FREQ=MONTHLY;BYDAY=MO"
                , "FREQ=MONTHLY;BYDAY=1MO,2TU"
                , "FREQ=MONTHLY;BYMONTHDAY=1,15"
                , "FREQ=MONTHLY;BYMONTHDAY=15;BYDAY=2TU"
                , "FREQ=MONTHLY;BYMONTHDAY=15;BYSETPOS=-1"
                , "FREQ=MONTHLY;BYDAY=2TU;BYSETPOS=1"
                , "FREQ=YEARLY;BYMONTH=1,2;BYMONTHDAY=1"
                , "FREQ=DAILY\nCOUNT=3"
                , "DTSTART:20261020T090000Z"
                ]
                    |> List.filterMap
                        (\given ->
                            case Recurrence.fromRRule given of
                                Err problem ->
                                    let
                                        said =
                                            Recurrence.problemText Locale.nb problem
                                    in
                                    if List.any (\english -> String.contains english said) [ " with ", " only ", "give ", " the ", "several", "together", "interval above", "every " ] then
                                        Just said

                                    else
                                        Nothing

                                Ok _ ->
                                    Just (given ++ " was read")
                        )
                    |> Expect.equal []
        , test "the English words name the part and the reason" <|
            \_ ->
                Recurrence.fromRRule "FREQ=MONTHLY;BYDAY=MO"
                    |> Result.mapError (Recurrence.problemText Locale.en)
                    |> Expect.equal (Err "Not supported in a recurrence rule: BYDAY=MO with FREQ=MONTHLY (every such day of the month). Give the number, such as 2MO.")
        , test "fifty thousand skipped dates do not overflow the stack" <|
            \_ ->
                Recurrence.rule Recurrence.daily [ Recurrence.except (List.map (\n -> Date.addDays n (date 2026 1 1)) (List.range 0 49999)) ]
                    |> Result.map (Recurrence.exceptions >> List.length)
                    |> Expect.equal (Ok 50000)
        ]



-- AGAINST THE REFERENCE


type alias Case =
    { start : Date
    , params : Params
    , fromOffset : Int
    , limit : Int
    , span : Int
    }


caseFuzzer : Fuzzer Case
caseFuzzer =
    Fuzz.map5 Case
        startFuzzer
        paramsFuzzer
        (Fuzz.frequency [ ( 2, Fuzz.intRange -20 0 ), ( 5, Fuzz.intRange 0 1000 ) ])
        (Fuzz.frequency [ ( 1, Fuzz.constant 0 ), ( 6, Fuzz.intRange 1 40 ) ])
        (Fuzz.intRange 0 800)


withoutSkipped : Params -> Params
withoutSkipped params =
    { params | skipped = [] }


withRule : Case -> (Rule -> Date -> Date -> Expect.Expectation) -> Expect.Expectation
withRule c check =
    case Reference.build c.start c.params of
        Err problem ->
            Expect.fail ("the rule could not be built: " ++ Recurrence.problemText Locale.en problem)

        Ok rule ->
            let
                from_ =
                    Date.addDays c.fromOffset c.start

                scanEnd =
                    Date.addDays Reference.scanLimit
                        (if Date.compare from_ c.start == GT then
                            from_

                         else
                            c.start
                        )
            in
            check rule from_ scanEnd


atOrAfter : Date -> Date -> Bool
atOrAfter bound day =
    Date.compare day bound /= LT


atOrBefore : Date -> Date -> Bool
atOrBefore bound day =
    Date.compare day bound /= GT


againstTheReference : Test
againstTheReference =
    let
        runs =
            { runs = 400, distribution = Test.noDistribution }
    in
    describe "against the day-by-day reference"
        [ fuzzWith runs caseFuzzer "occurrences are what the reference finds" <|
            \c ->
                withRule c
                    (\rule from_ scanEnd ->
                        Expect.equal
                            (Reference.reference c.start c.params scanEnd
                                |> List.filter (atOrAfter from_)
                                |> List.take c.limit
                            )
                            (Recurrence.occurrences { start = c.start, from = from_, limit = c.limit } rule
                                |> List.filter (atOrBefore scanEnd)
                            )
                    )
        , fuzzWith runs caseFuzzer "between is what the reference finds in the window" <|
            \c ->
                withRule c
                    (\rule from_ scanEnd ->
                        let
                            to =
                                Date.addDays c.span from_

                            found =
                                Recurrence.between { start = c.start, from = from_, to = to } rule
                        in
                        Expect.equal
                            ( Reference.reference c.start c.params scanEnd
                                |> List.filter (\day -> atOrAfter from_ day && atOrBefore to day)
                            , False
                            )
                            ( found.dates, found.truncated )
                    )
        , fuzzWith runs caseFuzzer "isOccurrence agrees with the reference on every day of a window" <|
            \c ->
                withRule c
                    (\rule from_ scanEnd ->
                        let
                            series =
                                Reference.reference c.start c.params scanEnd

                            window =
                                List.range 0 (c.span // 10 + 10)
                                    |> List.map (\offset -> Date.addDays offset from_)

                            wrong =
                                List.filter
                                    (\day ->
                                        Recurrence.isOccurrence { start = c.start, date = day } rule
                                            /= List.member day series
                                    )
                                    window
                        in
                        Expect.equal [] (iso wrong)
                    )
        , fuzzWith runs caseFuzzer "next is the first occurrence after a date" <|
            \c ->
                withRule c
                    (\rule from_ scanEnd ->
                        Expect.equal
                            (Reference.reference c.start c.params scanEnd
                                |> List.filter (\day -> Date.compare day from_ == GT)
                                |> List.head
                            )
                            (Recurrence.next { start = c.start, after = from_ } rule
                                |> Maybe.andThen
                                    (\day ->
                                        if atOrBefore scanEnd day then
                                            Just day

                                        else
                                            Nothing
                                    )
                            )
                    )
        , fuzzWith runs caseFuzzer "the dates are strictly increasing, inside the window, within the limit and never skipped" <|
            \c ->
                withRule c
                    (\rule from_ _ ->
                        let
                            found =
                                Recurrence.occurrences { start = c.start, from = from_, limit = c.limit } rule

                            skippedDates =
                                Recurrence.exceptions rule

                            increasing =
                                List.map2 (\a b -> Date.compare a b == LT) found (List.drop 1 found)
                        in
                        Expect.equal
                            { increasing = True, withinLimit = True, inWindow = True, notSkipped = True }
                            { increasing = List.all identity increasing
                            , withinLimit = List.length found <= c.limit
                            , inWindow = List.all (\day -> atOrAfter c.start day && atOrAfter from_ day) found
                            , notSkipped = List.all (\day -> not (List.member day skippedDates)) found
                            }
                    )
        , fuzzWith runs caseFuzzer "a rule written as RRULE and read again is the same rule" <|
            \c ->
                withRule c
                    (\rule _ _ ->
                        Expect.equal
                            (Ok (Recurrence.withExceptions [] rule))
                            (Recurrence.fromRRule (Recurrence.toRRule rule))
                    )
        , fuzzWith runs caseFuzzer "a rule without skipped dates survives the RRULE round trip with ==" <|
            \c ->
                case Reference.build c.start (withoutSkipped c.params) of
                    Ok rule ->
                        Expect.equal (Ok rule) (Recurrence.fromRRule (Recurrence.toRRule rule))

                    Err problem ->
                        Expect.fail (Recurrence.problemText Locale.en problem)
        , fuzzWith runs caseFuzzer "every rule has a description in both languages" <|
            \c ->
                withRule c
                    (\rule _ _ ->
                        Expect.equal ( False, False, True )
                            ( String.isEmpty (Recurrence.describe Locale.en rule)
                            , String.isEmpty (Recurrence.describe Locale.nb rule)
                            , Recurrence.describe Locale.en rule /= Recurrence.describe Locale.nb rule
                            )
                    )
        , fuzzWith runs caseFuzzer "the same rule read back from its RRULE has the same dates" <|
            \c ->
                withRule c
                    (\rule from_ _ ->
                        case Recurrence.fromRRule (Recurrence.toRRule rule) of
                            Ok again ->
                                Expect.equal
                                    (Recurrence.occurrences { start = c.start, from = from_, limit = 20 } (Recurrence.withExceptions [] rule))
                                    (Recurrence.occurrences { start = c.start, from = from_, limit = 20 } again)

                            Err problem ->
                                Expect.fail (Recurrence.problemText Locale.en problem)
                    )
        ]
