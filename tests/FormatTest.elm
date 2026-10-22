module FormatTest exposing (suite)

import Expect
import Klar.Date as Date exposing (Date)
import Klar.Format as Format
import Klar.Locale as Locale exposing (Locale)
import Test exposing (Test, describe, test)
import Time


nbsp : String
nbsp =
    "\u{00A0}"


minus : String
minus =
    "−"


suite : Test
suite =
    describe "Klar.Format"
        [ intTests
        , decimalTests
        , percentTests
        , currencyTests
        , bytesTests
        , durationTests
        , dateTests
        , relativeTests
        , pluralTests
        ]


check : String -> String -> String -> Test
check name expected actual =
    test name <| \_ -> Expect.equal expected actual


intTests : Test
intTests =
    describe "int"
        [ check "groups thousands in English" "1,234,567" (Format.int Locale.en 1234567)
        , check "groups thousands in Norwegian with non-breaking spaces" ("1" ++ nbsp ++ "234" ++ nbsp ++ "567") (Format.int Locale.nb 1234567)
        , check "does not group small numbers" "999" (Format.int Locale.en 999)
        , check "groups exactly at a thousand" "1,000" (Format.int Locale.en 1000)
        , check "zero" "0" (Format.int Locale.en 0)
        , check "uses a real minus sign" (minus ++ "1,000") (Format.int Locale.en -1000)
        ]


decimalTests : Test
decimalTests =
    describe "decimal"
        [ check "pads with zeros" "1,234.50" (Format.decimal Locale.en 2 1234.5)
        , check "uses the Norwegian separators" ("1" ++ nbsp ++ "234,50") (Format.decimal Locale.nb 2 1234.5)
        , check "zero decimals" "1,235" (Format.decimal Locale.en 0 1234.5)
        , check "rounds half away from zero" "3" (Format.decimal Locale.en 0 2.5)
        , check "rounds negative halves away from zero" (minus ++ "3") (Format.decimal Locale.en 0 -2.5)
        , check "1.005 rounds up, as written" "1.01" (Format.decimal Locale.en 2 1.005)
        , check "0.285 rounds up, as written" "0.29" (Format.decimal Locale.en 2 0.285)
        , check "2.675 rounds up, as written" "2.68" (Format.decimal Locale.en 2 2.675)
        , check "1.45 to one decimal" "1.5" (Format.decimal Locale.en 1 1.45)
        , check "carries into the whole part" "10.00" (Format.decimal Locale.en 2 9.995)
        , check "carries into a new thousand" "1,000" (Format.decimal Locale.en 0 999.5)
        , check "numbers above 32 bits" "3,000,000,000" (Format.decimal Locale.en 0 3000000000)
        , check "numbers above 32 bits with decimals" "12,345,678,901.50" (Format.decimal Locale.en 2 12345678901.5)
        , check "numbers that JavaScript writes with an exponent" "1,000,000,000,000,000,000,000" (Format.decimal Locale.en 0 1.0e21)
        , check "tiny numbers" "0.0000002" (Format.decimal Locale.en 7 1.5e-7)
        , check "a negative number keeps its sign" (minus ++ "0.5") (Format.decimal Locale.en 1 -0.5)
        , check "a number that rounds to zero is not negative" "0.0" (Format.decimal Locale.en 1 -0.04)
        , check "negative zero" "0.00" (Format.decimal Locale.en 2 (-1 * 0))
        , check "zero" "0.00" (Format.decimal Locale.en 2 0)
        , check "negative decimals count as none" "4" (Format.decimal Locale.en -2 3.7)
        , check "NaN" "NaN" (Format.decimal Locale.en 2 (0 / 0))
        , check "infinity" "∞" (Format.decimal Locale.en 2 (1 / 0))
        , check "negative infinity" (minus ++ "∞") (Format.decimal Locale.en 2 (-1 / 0))
        ]


percentTests : Test
percentTests =
    describe "percent"
        [ check "no decimals" "13%" (Format.percent Locale.en 0 0.127)
        , check "one decimal" "12.7%" (Format.percent Locale.en 1 0.127)
        , check "Norwegian puts a space before the sign" ("12,7" ++ nbsp ++ "%") (Format.percent Locale.nb 1 0.127)
        , check "0.145 is 14.5 percent and rounds up" "15%" (Format.percent Locale.en 0 0.145)
        , check "a whole" "100%" (Format.percent Locale.en 0 1)
        , check "zero" "0%" (Format.percent Locale.en 0 0)
        , check "negative" (minus ++ "12.5%") (Format.percent Locale.en 1 -0.125)
        , check "over 100 percent" "1,250%" (Format.percent Locale.en 0 12.5)
        , check "a tiny share" "0.0%" (Format.percent Locale.en 1 0.00004)
        ]


currencyTests : Test
currencyTests =
    describe "currency"
        [ check "English puts the symbol first" "$1,234.50" (Format.currency Locale.en "$" 2 1234.5)
        , check "Norwegian puts the symbol last" ("1" ++ nbsp ++ "234,50" ++ nbsp ++ "kr") (Format.currency Locale.nb "kr" 2 1234.5)
        , check "negative amounts" (minus ++ "$3.00") (Format.currency Locale.en "$" 2 -3)
        , check "a known code is written as its symbol" "$645.15" (Format.currency Locale.en "USD" 2 645.15)
        , check "an unknown code gets a non-breaking space" ("CHF" ++ nbsp ++ "3,673.80") (Format.currency Locale.en "CHF" 2 3673.8)
        , check "a known code in Norwegian" ("1" ++ nbsp ++ "234,50" ++ nbsp ++ "kr") (Format.currency Locale.nb "NOK" 2 1234.5)
        , check "no decimals" "JPY 1,500" (Format.currency Locale.en "JPY " 0 1500)
        , check "an amount that rounds to zero has no sign" "$0.00" (Format.currency Locale.en "$" 2 -0.001)
        ]


bytesTests : Test
bytesTests =
    describe "bytes"
        [ check "below a kilobyte" (String.concat [ "512", nbsp, "B" ]) (Format.bytes Locale.en 512)
        , check "zero" (String.concat [ "0", nbsp, "B" ]) (Format.bytes Locale.en 0)
        , check "a kilobyte is 1000 bytes" (String.concat [ "1.0", nbsp, "kB" ]) (Format.bytes Locale.en 1000)
        , check "megabytes with one decimal" (String.concat [ "1.5", nbsp, "MB" ]) (Format.bytes Locale.en 1536000)
        , check "Norwegian decimal comma" (String.concat [ "2,4", nbsp, "kB" ]) (Format.bytes Locale.nb 2400)
        , check "rounding up to the next unit" (String.concat [ "1.0", nbsp, "MB" ]) (Format.bytes Locale.en 999999)
        , check "gigabytes" (String.concat [ "4.2", nbsp, "GB" ]) (Format.bytes Locale.en 4200000000)
        , check "negative sizes" (String.concat [ minus, "2.0", nbsp, "kB" ]) (Format.bytes Locale.en -2000)
        ]


durationTests : Test
durationTests =
    describe "duration"
        [ check "milliseconds" (String.concat [ "340", nbsp, "ms" ]) (Format.duration Locale.en 340)
        , check "seconds with a decimal" (String.concat [ "1.2", nbsp, "s" ]) (Format.duration Locale.en 1200)
        , check "Norwegian decimal comma" (String.concat [ "1,2", nbsp, "s" ]) (Format.duration Locale.nb 1200)
        , check "59.96 seconds is a minute, not 60.0 seconds" (String.concat [ "1", nbsp, "min" ]) (Format.duration Locale.en 59960)
        , check "minutes and seconds" (String.concat [ "2", nbsp, "min 5", nbsp, "s" ]) (Format.duration Locale.en 125000)
        , check "whole minutes" (String.concat [ "3", nbsp, "min" ]) (Format.duration Locale.en 180000)
        , check "hours and minutes" (String.concat [ "1", nbsp, "h 2", nbsp, "min" ]) (Format.duration Locale.en 3720000)
        , check "Norwegian hours" (String.concat [ "1", nbsp, "t 2", nbsp, "min" ]) (Format.duration Locale.nb 3720000)
        , check "days and hours" (String.concat [ "2", nbsp, "d 7", nbsp, "h" ]) (Format.duration Locale.en 200000000)
        , check "negative" (String.concat [ minus, "340", nbsp, "ms" ]) (Format.duration Locale.en -340)
        ]


day : Int -> Int -> Int -> Date
day y m d =
    Date.fromParts y m d |> Maybe.withDefault (Date.fromEpochDay 0)


dateTests : Test
dateTests =
    describe "dates and times"
        [ check "English date is ISO" "2026-10-20" (Format.date Locale.en (day 2026 10 20))
        , check "Norwegian date" "20.10.2026" (Format.date Locale.nb (day 2026 10 20))
        , check "Norwegian date pads" "05.03.2026" (Format.date Locale.nb (day 2026 3 5))
        , check "the year has four digits in English" "0999-01-02" (Format.date Locale.en (day 999 1 2))
        , check "and in Norwegian" "02.01.0999" (Format.date Locale.nb (day 999 1 2))
        , check "long English date" "20 October 2026" (Format.dateLong Locale.en (day 2026 10 20))
        , check "long Norwegian date" "20. oktober 2026" (Format.dateLong Locale.nb (day 2026 10 20))
        , check "time of day" "14:05" (Format.time Time.utc (Time.millisToPosix (((14 * 60) + 5) * 60 * 1000)))
        , check "time of day pads" "00:07" (Format.time Time.utc (Time.millisToPosix (7 * 60 * 1000)))
        , check "ISO 8601 in UTC" "1970-01-02T01:02:03Z" (Format.iso8601 (Time.millisToPosix (((24 + 1) * 3600 + 2 * 60 + 3) * 1000 + 999)))
        , check "ISO 8601 of the epoch" "1970-01-01T00:00:00Z" (Format.iso8601 (Time.millisToPosix 0))
        , check "date and time" "1970-01-02 01:00" (Format.dateTime Locale.en Time.utc (Time.millisToPosix ((24 + 1) * 3600 * 1000)))
        ]


now : Time.Posix
now =
    Time.millisToPosix 1800000000000


ago : Int -> Int -> Time.Posix
ago days minutes =
    Time.millisToPosix (1800000000000 - days * 86400000 - minutes * 60000)


relativeTests : Test
relativeTests =
    describe "relative"
        [ check "just now" "just now" (Format.relative Locale.en now (ago 0 0))
        , check "Norwegian just now" "nå nettopp" (Format.relative Locale.nb now (ago 0 0))
        , check "one minute" "1 minute ago" (Format.relative Locale.en now (ago 0 1))
        , check "minutes" "5 minutes ago" (Format.relative Locale.en now (ago 0 5))
        , check "Norwegian minutes" "for 5 minutter siden" (Format.relative Locale.nb now (ago 0 5))
        , check "hours" "3 hours ago" (Format.relative Locale.en now (ago 0 185))
        , check "days" "3 days ago" (Format.relative Locale.en now (ago 3 0))
        , check "months, past the 32 bit limit of 24 days" "1 month ago" (Format.relative Locale.en now (ago 40 0))
        , check "years" "2 years ago" (Format.relative Locale.en now (ago 730 0))
        , check "the future" "in 2 hours" (Format.relative Locale.en now (ago 0 -125))
        , check "the Norwegian future" "om 3 dager" (Format.relative Locale.nb now (ago -3 0))
        , check "a moment ahead" "in a moment" (Format.relative Locale.en now (ago 0 0 |> plusSeconds 20))
        ]


plusSeconds : Int -> Time.Posix -> Time.Posix
plusSeconds seconds posix =
    Time.millisToPosix (Time.posixToMillis posix + seconds * 1000)


pluralTests : Test
pluralTests =
    describe "plural"
        [ check "one" "order" (Format.plural Locale.en 1 { one = "order", other = "orders" })
        , check "many" "orders" (Format.plural Locale.en 3 { one = "order", other = "orders" })
        , check "zero" "orders" (Format.plural Locale.en 0 { one = "order", other = "orders" })
        ]
