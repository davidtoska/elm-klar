module Support.RecurrenceFuzz exposing (paramsFuzzer, startFuzzer)

{-| Random start dates and random rules for the recurrence tests: month ends,
leap days and the turn of the year are over-represented on purpose.
-}

import Fuzz exposing (Fuzzer)
import Klar.Date as Date exposing (Date)
import Support.RecurrenceReference exposing (Ending(..), Kind(..), Params, date)


firstDay : Int
firstDay =
    Date.toEpochDay (date 2019 1 1)


lastDay : Int
lastDay =
    Date.toEpochDay (date 2031 12 31)


startFuzzer : Fuzzer Date
startFuzzer =
    Fuzz.frequency
        [ ( 4, Fuzz.map Date.fromEpochDay (Fuzz.intRange firstDay lastDay) )
        , ( 2, Fuzz.map (Date.fromEpochDay >> Date.endOfMonth) (Fuzz.intRange firstDay lastDay) )
        , ( 1, Fuzz.map (\offset -> Date.addDays offset (date 2024 2 29)) (Fuzz.intRange -3 3) )
        , ( 1, Fuzz.map2 (\y offset -> Date.addDays offset (date y 12 31)) (Fuzz.intRange 2019 2031) (Fuzz.intRange -2 2) )
        ]


weekdayFuzzer : Fuzzer Int
weekdayFuzzer =
    Fuzz.intRange 1 7


kindFuzzer : Fuzzer Kind
kindFuzzer =
    let
        weekdays =
            Fuzz.map2 (::) weekdayFuzzer (Fuzz.map (List.take 6) (Fuzz.list weekdayFuzzer))

        monthDay =
            Fuzz.frequency [ ( 3, Fuzz.intRange 1 31 ), ( 3, Fuzz.intRange 28 31 ) ]

        ordinal =
            Fuzz.oneOfValues [ 1, 2, 3, 4, -1 ]

        yearDate =
            Fuzz.frequency
                [ ( 3, Fuzz.map2 Tuple.pair (Fuzz.intRange 1 12) (Fuzz.intRange 1 28) )
                , ( 3, Fuzz.oneOfValues [ ( 2, 29 ), ( 2, 28 ), ( 1, 31 ), ( 4, 30 ), ( 12, 31 ), ( 3, 31 ), ( 6, 30 ) ] )
                ]
    in
    Fuzz.frequency
        [ ( 1, Fuzz.constant KDaily )
        , ( 3, Fuzz.map KWeekly weekdays )
        , ( 3, Fuzz.map2 KMonthDay monthDay Fuzz.bool )
        , ( 3, Fuzz.map2 KMonthNth ordinal weekdayFuzzer )
        , ( 3, Fuzz.map2 (\( month, day ) skip -> KYearDate month day skip) yearDate Fuzz.bool )
        , ( 2, Fuzz.map3 KYearNth ordinal weekdayFuzzer (Fuzz.intRange 1 12) )
        ]


paramsFuzzer : Fuzzer Params
paramsFuzzer =
    Fuzz.map4 Params
        (Fuzz.frequency [ ( 3, Fuzz.intRange 1 3 ), ( 2, Fuzz.intRange 1 12 ) ])
        kindFuzzer
        (Fuzz.frequency
            [ ( 3, Fuzz.constant EndNever )
            , ( 2, Fuzz.map EndAfter (Fuzz.intRange 1 30) )
            , ( 2, Fuzz.map EndOn (Fuzz.intRange 0 900) )
            ]
        )
        (Fuzz.map (List.take 5) (Fuzz.list (Fuzz.intRange 0 400)))
