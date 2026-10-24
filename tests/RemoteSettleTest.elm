module RemoteSettleTest exposing (suite)

{-| `Remote.settle` takes an answer into the state without a time, `Remote.map2`
combines two remotes, and the texts of a problem fit any request.
-}

import Expect
import Fuzz exposing (Fuzzer)
import Klar.Locale as Locale
import Klar.Remote as Remote exposing (Remote(..))
import Test exposing (Test, describe, fuzz, fuzz2, test)
import Time


failure : Remote.Problem
failure =
    Remote.problem Remote.server


other : Remote.Problem
other =
    Remote.problem Remote.timeout


at : Int -> Time.Posix
at =
    Time.millisToPosix


{-| Every state a `Remote Int` can be in, from the functions an application calls.
-}
remoteFuzzer : Fuzzer (Remote Int)
remoteFuzzer =
    Fuzz.oneOf
        [ Fuzz.constant NotAsked
        , Fuzz.constant Loading
        , Fuzz.constant (Failed failure)
        , Fuzz.map Loaded Fuzz.int
        , Fuzz.map Remote.refresh (Fuzz.map Loaded Fuzz.int)
        , Fuzz.map2 (\n t -> Remote.refreshWith Loading (Ok n) (at t)) Fuzz.int (Fuzz.intRange 0 100000)
        , Fuzz.map (\n -> Remote.settle (Loaded n) (Err failure)) Fuzz.int
        , Fuzz.map2 (\n t -> Remote.settle (Remote.refreshWith Loading (Ok n) (at t)) (Err other)) Fuzz.int (Fuzz.intRange 0 100000)
        , Fuzz.map (\n -> Remote.refresh (Remote.settle (Loaded n) (Err failure))) Fuzz.int
        ]


suite : Test
suite =
    describe "Remote"
        [ settle
        , map2
        , texts
        ]


settle : Test
settle =
    describe "settle"
        [ test "the first answer is fresh data" <|
            \_ -> Remote.settle Loading (Ok 1) |> Expect.equal (Loaded 1)
        , test "a failed first load is a failure" <|
            \_ -> Remote.settle Loading (Err failure) |> Expect.equal (Failed failure)
        , test "a failed refresh keeps the data, old, with the problem" <|
            \_ ->
                Remote.settle (Remote.refresh (Loaded 1)) (Err failure)
                    |> Expect.all
                        [ Remote.toMaybe >> Expect.equal (Just 1)
                        , Remote.staleProblem >> Expect.equal (Just failure)
                        , Remote.isRefreshing >> Expect.equal False
                        ]
        , test "a failed refresh keeps the time the data was loaded" <|
            \_ ->
                Remote.settle (Remote.refresh (Remote.refreshWith Loading (Ok 1) (at 5000))) (Err failure)
                    |> Remote.loadedAt
                    |> Expect.equal (Just (at 5000))
        , test "a good answer after old data is fresh again" <|
            \_ ->
                Remote.settle (Remote.settle (Loaded 1) (Err failure)) (Ok 2)
                    |> Expect.equal (Loaded 2)
        , fuzz remoteFuzzer "Ok always gives Loaded, whatever came before" <|
            \before -> Remote.settle before (Ok 7) |> Expect.equal (Loaded 7)
        , fuzz remoteFuzzer "Err never drops data that was there" <|
            \before ->
                Remote.settle before (Err other)
                    |> Remote.toMaybe
                    |> Expect.equal (Remote.toMaybe before)
        , fuzz remoteFuzzer "Err is the same as for refreshWith" <|
            \before ->
                Remote.settle before (Err other)
                    |> Expect.equal (Remote.refreshWith before (Err other) (at 1))
        , test "fromResult is settle Loading" <|
            \_ ->
                Expect.equal
                    [ Remote.fromResult (Ok 3), Remote.fromResult (Err failure) ]
                    [ Remote.settle Loading (Ok 3), Remote.settle Loading (Err failure) ]
        ]


map2 : Test
map2 =
    describe "map2"
        [ test "both there: the combination" <|
            \_ -> Remote.map2 (+) (Loaded 1) (Loaded 2) |> Expect.equal (Loaded 3)
        , test "a failure wins over loading, which wins over not asked" <|
            \_ ->
                Expect.equal
                    [ Failed failure, Failed failure, Loading, Loading, NotAsked, Failed failure ]
                    [ Remote.map2 (+) (Failed failure) Loading
                    , Remote.map2 (+) Loading (Failed failure)
                    , Remote.map2 (+) Loading NotAsked
                    , Remote.map2 (+) (Loaded 1) Loading
                    , Remote.map2 (+) NotAsked (Loaded 1)
                    , Remote.map2 (+) (Remote.refresh (Loaded 1)) (Failed failure)
                    ]
        , test "the first failure wins" <|
            \_ -> Remote.map2 (+) (Failed failure) (Failed other) |> Expect.equal (Failed failure)
        , test "refreshing when either side is" <|
            \_ ->
                Remote.map2 (+) (Loaded 1) (Remote.refresh (Loaded 2))
                    |> Expect.all
                        [ Remote.isRefreshing >> Expect.equal True
                        , Remote.toMaybe >> Expect.equal (Just 3)
                        ]
        , test "old with the problem of the first old side, loaded at the earlier time" <|
            \_ ->
                Remote.map2 (+)
                    (Remote.refreshWith Loading (Ok 1) (at 9000))
                    (Remote.settle (Remote.refreshWith Loading (Ok 2) (at 4000)) (Err other))
                    |> Expect.all
                        [ Remote.staleProblem >> Expect.equal (Just other)
                        , Remote.loadedAt >> Expect.equal (Just (at 4000))
                        , Remote.toMaybe >> Expect.equal (Just 3)
                        ]
        , fuzz2 remoteFuzzer remoteFuzzer "the data is there exactly when it is there on both sides" <|
            \a b ->
                Remote.map2 Tuple.pair a b
                    |> Remote.toMaybe
                    |> Expect.equal (Maybe.map2 Tuple.pair (Remote.toMaybe a) (Remote.toMaybe b))
        , fuzz2 remoteFuzzer remoteFuzzer "refreshing and old are joined with or" <|
            \a b ->
                Remote.map2 Tuple.pair a b
                    |> Expect.all
                        [ Remote.isRefreshing >> Expect.equal (Remote.isLoaded a && Remote.isLoaded b && (Remote.isRefreshing a || Remote.isRefreshing b))
                        , Remote.isStale >> Expect.equal (Remote.isLoaded a && Remote.isLoaded b && (Remote.isStale a || Remote.isStale b))
                        ]
        , fuzz remoteFuzzer "combining with fresh data changes nothing but the data" <|
            \a ->
                Remote.map2 (\x _ -> x) a (Loaded ())
                    |> Expect.equal a
        ]


texts : Test
texts =
    describe "the texts of a problem"
        [ test "a blank explanation of your own hides the explanation" <|
            \_ ->
                Expect.equal [ Nothing, Nothing, Just "Order 1042 is locked." ]
                    [ Remote.detail Locale.en (Remote.problem Remote.server |> Remote.withDetail "")
                    , Remote.detail Locale.en (Remote.problem Remote.server |> Remote.withDetail "   ")
                    , Remote.detail Locale.en (Remote.problem Remote.server |> Remote.withDetail "Order 1042 is locked.")
                    ]
        , test "the ready-made explanation is there" <|
            \_ ->
                Remote.detail Locale.en (Remote.problem Remote.server)
                    |> Expect.notEqual Nothing
        , test "a rejected request does not speak of a form" <|
            \_ ->
                Expect.equal
                    [ "The request was rejected", "Forespørselen ble avvist", "The data changed in the meantime", "Dataene er endret i mellomtiden" ]
                    [ Remote.title Locale.en (Remote.problem Remote.validation)
                    , Remote.title Locale.nb (Remote.problem Remote.validation)
                    , Remote.title Locale.en (Remote.problem Remote.conflict)
                    , Remote.title Locale.nb (Remote.problem Remote.conflict)
                    ]
        , test "too many requests is worth trying again, with its own texts" <|
            \_ ->
                Expect.equal
                    [ "True", "Too many requests", "For mange forespørsler" ]
                    [ if Remote.isRetryable (Remote.problem Remote.tooManyRequests) then
                        "True"

                      else
                        "False"
                    , Remote.title Locale.en (Remote.problem Remote.tooManyRequests)
                    , Remote.title Locale.nb (Remote.problem Remote.tooManyRequests)
                    ]
        , test "no ready-made text names fields or forms" <|
            \_ ->
                [ Remote.validation, Remote.conflict ]
                    |> List.concatMap (\k -> [ Remote.problem k |> Remote.title Locale.en, Remote.problem k |> Remote.detail Locale.en |> Maybe.withDefault "" ])
                    |> List.filter (\text -> String.contains "form" (String.toLower text) || String.contains "field" (String.toLower text))
                    |> Expect.equal []
        ]
