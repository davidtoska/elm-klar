module LocaleAndRemoteTest exposing (suite)

import Expect
import Klar.Locale as Locale exposing (Locale)
import Klar.Remote as Remote exposing (Remote(..))
import Test exposing (Test, describe, test)


suite : Test
suite =
    describe "Klar.Locale and Klar.Remote"
        [ locale
        , remote
        , problems
        ]


locale : Test
locale =
    describe "Locale"
        [ test "English is the default" <|
            \_ -> Expect.equal Locale.en Locale.default
        , test "pick chooses a side" <|
            \_ ->
                Expect.equal [ "Save", "Lagre" ]
                    [ Locale.pick Locale.en { nb = "Lagre", en = "Save" }, Locale.pick Locale.nb { nb = "Lagre", en = "Save" } ]
        , test "codes" <|
            \_ -> Expect.equal [ "en", "nb" ] (List.map Locale.toCode Locale.all)
        , test "reading codes" <|
            \_ ->
                Expect.equal [ Just Locale.nb, Just Locale.nb, Just Locale.en, Just Locale.en, Nothing, Nothing ]
                    (List.map Locale.fromCode [ "nb", "NO", "en", "EN", "sv", "" ])
        , test "separators" <|
            \_ ->
                Expect.equal [ ",", "\u{00A0}", ".", "," ]
                    [ Locale.thousandSeparator Locale.en, Locale.thousandSeparator Locale.nb, Locale.decimalSeparator Locale.en, Locale.decimalSeparator Locale.nb ]
        , test "months" <|
            \_ ->
                Expect.equal [ "January", "desember", "mars" ]
                    [ Locale.monthName Locale.en 1, Locale.monthName Locale.nb 12, Locale.monthName Locale.nb 3 ]
        , test "months outside 1 to 12 have no name" <|
            \_ ->
                Expect.equal [ "", "", "", "" ]
                    [ Locale.monthName Locale.en 0, Locale.monthName Locale.en 13, Locale.monthName Locale.nb -1, Locale.monthShort Locale.en 0 ]
        , test "short months" <|
            \_ -> Expect.equal [ "Oct", "okt" ] [ Locale.monthShort Locale.en 10, Locale.monthShort Locale.nb 10 ]
        , test "weekdays" <|
            \_ ->
                Expect.equal [ "Monday", "søndag", "Tu", "lø" ]
                    [ Locale.weekdayLong Locale.en 1, Locale.weekdayLong Locale.nb 7, Locale.weekdayShort Locale.en 2, Locale.weekdayShort Locale.nb 6 ]
        , test "weekdays outside 1 to 7 have no name" <|
            \_ -> Expect.equal [ "", "", "" ] [ Locale.weekdayLong Locale.en 0, Locale.weekdayLong Locale.en 8, Locale.weekdayShort Locale.nb -3 ]
        , test "every month and weekday has a name in every language" <|
            \_ ->
                let
                    names l =
                        List.map (Locale.monthName l) (List.range 1 12) ++ List.map (Locale.weekdayLong l) (List.range 1 7)
                in
                Expect.equal True (List.all (\l -> List.all (\n -> n /= "") (names l)) Locale.all)
        , test "the weeks start on Monday" <|
            \_ -> Expect.equal [ 1, 1 ] [ Locale.firstDayOfWeek Locale.en, Locale.firstDayOfWeek Locale.nb ]
        , test "language names are written in the language" <|
            \_ -> Expect.equal [ "English", "Norsk (bokmål)" ] (List.map Locale.name Locale.all)
        ]


remote : Test
remote =
    let
        failure =
            Remote.problem Remote.timeout
    in
    describe "Remote"
        [ test "map changes only the data" <|
            \_ ->
                Expect.equal [ Success 2, NotAsked, Loading, Failure failure ]
                    [ Remote.map ((+) 1) (Success 1), Remote.map ((+) 1) NotAsked, Remote.map ((+) 1) Loading, Remote.map ((+) 1) (Failure failure) ]
        , test "toMaybe" <|
            \_ -> Expect.equal [ Just 1, Nothing, Nothing, Nothing ] (List.map Remote.toMaybe [ Success 1, NotAsked, Loading, Failure failure ])
        , test "withDefault" <|
            \_ -> Expect.equal [ 1, 0, 0, 0 ] (List.map (Remote.withDefault 0) [ Success 1, NotAsked, Loading, Failure failure ])
        , test "fromResult" <|
            \_ -> Expect.equal [ Success 1, Failure failure ] [ Remote.fromResult (Ok 1), Remote.fromResult (Err failure) ]
        , test "the predicates" <|
            \_ ->
                Expect.equal
                    [ ( False, False, False ), ( True, False, False ), ( False, False, True ), ( False, True, False ) ]
                    (List.map (\r -> ( Remote.isLoading r, Remote.isSuccess r, Remote.isFailure r ))
                        [ NotAsked, Loading, Failure failure, Success () ]
                    )
        , test "isLoading is not confused by data that contains functions" <|
            \_ -> Expect.equal False (Remote.isLoading (Success (\x -> x + 1)))
        ]


problems : Test
problems =
    let
        kinds =
            [ Remote.network, Remote.timeout, Remote.server, Remote.notFound, Remote.forbidden, Remote.unauthorized, Remote.validation, Remote.conflict, Remote.unknown ]
    in
    describe "Problem"
        [ test "every kind has a title and a detail in every language" <|
            \_ ->
                let
                    complete l p =
                        Remote.title l p /= "" && Remote.detail l p /= Nothing && Remote.detail l p /= Just ""
                in
                Expect.equal True (List.all (\l -> List.all (\k -> complete l (Remote.problem k)) kinds) Locale.all)
        , test "the problem remembers its kind" <|
            \_ -> Expect.equal kinds (List.map (\k -> Remote.kind (Remote.problem k)) kinds)
        , test "the English and Norwegian texts differ" <|
            \_ -> Expect.notEqual (Remote.title Locale.en (Remote.problem Remote.notFound)) (Remote.title Locale.nb (Remote.problem Remote.notFound))
        , test "the texts are chosen when the problem is read, so a language switch changes them" <|
            \_ ->
                let
                    p =
                        Remote.problem Remote.network
                in
                Expect.equal [ "Can't reach the service", "Ingen kontakt med tjenesten" ] [ Remote.title Locale.en p, Remote.title Locale.nb p ]
        , test "only network trouble, timeouts, server errors and unknown errors are retryable" <|
            \_ ->
                Expect.equal [ True, True, True, False, False, False, False, False, True ]
                    (List.map (\k -> Remote.isRetryable (Remote.problem k)) kinds)
        , test "title, detail and code can be replaced, in every language" <|
            \_ ->
                let
                    p =
                        Remote.problem Remote.server
                            |> Remote.withTitle "Orders are unavailable"
                            |> Remote.withDetail "The order service is down."
                            |> Remote.withCode "503"
                in
                Expect.equal
                    [ ( "Orders are unavailable", Just "The order service is down.", Just "503" )
                    , ( "Orders are unavailable", Just "The order service is down.", Just "503" )
                    ]
                    [ ( Remote.title Locale.en p, Remote.detail Locale.en p, Remote.code p )
                    , ( Remote.title Locale.nb p, Remote.detail Locale.nb p, Remote.code p )
                    ]
        ]
