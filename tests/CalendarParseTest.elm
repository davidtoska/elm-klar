module CalendarParseTest exposing (suite)

{-| Tests of how the pickers read typed dates and times (`Klar.Calendar.Parse`)
and of the helpers they share (`Klar.Calendar.Util`).

Today is 20 October 2026, a Tuesday, in every test unless a test says otherwise.

-}

import Expect
import Fuzz exposing (Fuzzer)
import Klar.Calendar.Parse as Parse exposing (Problem(..), TimeProblem(..))
import Klar.Calendar.Util as Util
import Klar.Date as Date exposing (Date)
import Klar.Format as Format
import Klar.Locale as Locale exposing (Locale)
import Test exposing (Test, describe, fuzz, fuzz2, fuzz3, test)


suite : Test
suite =
    describe "Klar.Calendar.Parse and Klar.Calendar.Util"
        [ dateFormatTests
        , dateRejectionTests
        , relativeTests
        , shortYearTests
        , digitsOnlyTests
        , boundsTests
        , messageTests
        , isCompleteTests
        , dateProperties
        , timeTests
        , timeBoundsTests
        , minutesTests
        , timeProperties
        , comparisonTests
        , clampTests
        , isoWeekTests
        , weekTests
        , monthArithmeticTests
        ]



-- DATA


date : Int -> Int -> Int -> Date
date year month day =
    Date.fromParts year month day |> Maybe.withDefault (Date.fromEpochDay 0)


today : Date
today =
    date 2026 10 20


{-| The rules of a field with no bounds, on the day of the tests.
-}
rules : Locale -> Parse.Rules
rules locale =
    { locale = locale, today = Just today, min = Nothing, max = Nothing, isDisabled = always False }


{-| The same field on another day.
-}
onDay : Date -> Parse.Rules
onDay day =
    { locale = Locale.en, today = Just day, min = Nothing, max = Nothing, isDisabled = always False }


{-| A field that does not know what day it is.
-}
withoutToday : Locale -> Parse.Rules
withoutToday locale =
    { locale = locale, today = Nothing, min = Nothing, max = Nothing, isDisabled = always False }


{-| An English field with bounds.
-}
between : Maybe Date -> Maybe Date -> Parse.Rules
between lower upper =
    { locale = Locale.en, today = Just today, min = lower, max = upper, isDisabled = always False }


{-| The date a text comes to, written as ISO text, or why it does not.
-}
parsed : Parse.Rules -> String -> Result Problem (Maybe String)
parsed r text =
    Parse.date r text |> Result.map (Maybe.map Date.toIso)


check : String -> a -> a -> Test
check name expected actual =
    test name <| \_ -> Expect.equal expected actual


languageName : Locale -> String
languageName locale =
    Locale.pick locale { nb = "Norwegian", en = "English" }


{-| One text in one language.
-}
reads : Locale -> String -> String -> Test
reads locale text expected =
    check ("reads \"" ++ text ++ "\" as " ++ expected ++ " in " ++ languageName locale)
        (Ok (Just expected))
        (parsed (rules locale) text)


{-| One text, in both languages, with the same result.
-}
readsInBoth : String -> String -> Test
readsInBoth text expected =
    check ("reads \"" ++ text ++ "\" as " ++ expected)
        ( Ok (Just expected), Ok (Just expected) )
        ( parsed (rules Locale.en) text, parsed (rules Locale.nb) text )


rejectsInBoth : String -> Test
rejectsInBoth text =
    check ("rejects \"" ++ text ++ "\"")
        ( Err Unparseable, Err Unparseable )
        ( parsed (rules Locale.en) text, parsed (rules Locale.nb) text )


pad : Int -> String
pad n =
    String.padLeft 2 '0' (String.fromInt n)


{-| Any day from 1000 to 2999, the years that can be typed with four digits.
-}
dateFuzzer : Fuzzer Date
dateFuzzer =
    Fuzz.intRange (Date.toEpochDay (date 1000 1 1)) (Date.toEpochDay (date 2999 12 31))
        |> Fuzz.map Date.fromEpochDay


separatorFuzzer : Fuzzer String
separatorFuzzer =
    Fuzz.oneOfValues [ ".", "/", "-", " ", ",", " . ", " / ", " - ", "..", ", " ]


{-| Text made of the characters of dates, so that many of the texts come close to
a date.
-}
dateLikeFuzzer : Fuzzer String
dateLikeFuzzer =
    Fuzz.oneOfValues (String.toList "0123456789./- ,+tT")
        |> Fuzz.listOfLengthBetween 0 12
        |> Fuzz.map String.fromList



-- DATES THAT ARE TYPED IN FULL


dateFormatTests : Test
dateFormatTests =
    describe "date: the ways to write a date"
        [ readsInBoth "20.10.2026" "2026-10-20"
        , readsInBoth "20/10/2026" "2026-10-20"
        , readsInBoth "20-10-2026" "2026-10-20"
        , readsInBoth "2026-10-20" "2026-10-20"
        , readsInBoth "2026/10/20" "2026-10-20"
        , readsInBoth "2026.10.20" "2026-10-20"
        , readsInBoth "20 10 2026" "2026-10-20"
        , readsInBoth "20,10,2026" "2026-10-20"
        , readsInBoth "20.1 . 2026" "2026-01-20"
        , readsInBoth "20 / 10 / 2026" "2026-10-20"
        , readsInBoth "20 - 10 - 2026" "2026-10-20"
        , readsInBoth "2026 - 10 - 20" "2026-10-20"
        , readsInBoth "20.1 2010" "2010-01-20"
        , readsInBoth "  20.10.2026  " "2026-10-20"
        , readsInBoth "1.2.2026" "2026-02-01"
        , readsInBoth "01.02.2026" "2026-02-01"
        , readsInBoth "1/2/2026" "2026-02-01"
        , readsInBoth "03/04/2026" "2026-04-03"
        , readsInBoth "2026-1-2" "2026-01-02"
        , readsInBoth "20..10..2026" "2026-10-20"
        , readsInBoth "20.10.2026." "2026-10-20"
        , readsInBoth ".20.10.2026" "2026-10-20"
        , readsInBoth "29.02.2024" "2024-02-29"
        , readsInBoth "31.12.1999" "1999-12-31"
        , readsInBoth "01.01.1000" "1000-01-01"
        , readsInBoth "31.12.2999" "2999-12-31"
        , check "blank text is no date, and no problem" (Ok Nothing) (parsed (rules Locale.en) "   ")
        , check "the empty text too" (Ok Nothing) (parsed (rules Locale.nb) "")
        , check "a tab and a line break are blank too" (Ok Nothing) (parsed (rules Locale.en) "\t \n")
        , check "20.10 is the day and month of this year" (Ok (Just "2026-10-20")) (parsed (rules Locale.en) "20.10")
        , check "5/3 is the 5th of March" (Ok (Just "2026-03-05")) (parsed (rules Locale.nb) "5/3")
        , check "the year of a day and a month follows today" (Ok (Just "2031-10-20")) (parsed (onDay (date 2031 1 1)) "20.10")
        , check "31.04 does not exist" (Err Unparseable) (parsed (rules Locale.en) "31.04")
        , check "29.02 does not exist in a year that is not a leap year" (Err Unparseable) (parsed (rules Locale.en) "29.02")
        , check "29.02 exists in a leap year" (Ok (Just "2024-02-29")) (parsed (onDay (date 2024 6 1)) "29.02")
        , check "a day and a month need today" (Err Unparseable) (parsed (withoutToday Locale.en) "20.10")
        , check "a full date does not need today" (Ok (Just "2026-10-20")) (parsed (withoutToday Locale.en) "20.10.2026")
        , check "a year and a month are no day and month" (Err Unparseable) (parsed (rules Locale.en) "2026-10")
        , check "a day with three digits is no day" (Err Unparseable) (parsed (rules Locale.en) "200.10")
        ]


dateRejectionTests : Test
dateRejectionTests =
    describe "date: what is not a date"
        [ rejectsInBoth "abc"
        , rejectsInBoth "not a date"
        , rejectsInBoth "32.10.2026"
        , rejectsInBoth "0.10.2026"
        , rejectsInBoth "20.0.2026"
        , rejectsInBoth "20.13.2026"
        , rejectsInBoth "29.02.2026"
        , rejectsInBoth "31.04.2026"
        , rejectsInBoth "31.11.2026"
        , rejectsInBoth "10/20/2026"
        , rejectsInBoth "20.10.999"
        , rejectsInBoth "20.10.12345"
        , rejectsInBoth "20.10.0999"
        , rejectsInBoth "20.10.3000"
        , rejectsInBoth "1.1.1"
        , rejectsInBoth "5.5.049"
        , rejectsInBoth "2026-10-2026"
        , rejectsInBoth "20.10.2026abc"
        , rejectsInBoth "2026-10-20-1"
        , rejectsInBoth "1.2.3.4"
        , rejectsInBoth "20.10.2026 14:30"
        , rejectsInBoth "2026-10-20T10:00:00Z"
        , rejectsInBoth "+"
        , rejectsInBoth "-"
        , rejectsInBoth "."
        , rejectsInBoth "20."
        , rejectsInBoth "- - -"
        , rejectsInBoth "٢٠.١٠.٢٠٢٦"
        , rejectsInBoth "２０.１０.２０２６"
        , rejectsInBoth "📅"
        , check "a date with a month in letters" (Err Unparseable) (parsed (rules Locale.nb) "2026-Oct-20")
        ]


relativeTests : Test
relativeTests =
    describe "date: relative to today (2026-10-20)"
        [ readsInBoth "t" "2026-10-20"
        , readsInBoth "T" "2026-10-20"
        , readsInBoth "today" "2026-10-20"
        , readsInBoth "Today" "2026-10-20"
        , readsInBoth "i dag" "2026-10-20"
        , readsInBoth "I Dag" "2026-10-20"
        , readsInBoth "idag" "2026-10-20"
        , readsInBoth "  t  " "2026-10-20"
        , readsInBoth "+3" "2026-10-23"
        , readsInBoth "-7" "2026-10-13"
        , readsInBoth "+0" "2026-10-20"
        , readsInBoth "-0" "2026-10-20"
        , readsInBoth "+12" "2026-11-01"
        , readsInBoth "-20" "2026-09-30"
        , readsInBoth "+365" "2027-10-20"
        , readsInBoth "+36500" "2126-09-26"
        , readsInBoth "-36500" "1926-11-14"
        , rejectsInBoth "+36501"
        , rejectsInBoth "-36501"
        , rejectsInBoth "+3.5"
        , rejectsInBoth "++3"
        , rejectsInBoth "+ 3"
        , rejectsInBoth "3+"
        , rejectsInBoth "+x"
        , rejectsInBoth "tt"
        , rejectsInBoth "i  dag"
        , check "the short forms need today: t" (Err Unparseable) (parsed (withoutToday Locale.en) "t")
        , check "the short forms need today: i dag" (Err Unparseable) (parsed (withoutToday Locale.nb) "i dag")
        , check "the short forms need today: +3" (Err Unparseable) (parsed (withoutToday Locale.en) "+3")
        , check "the short forms need today: -7" (Err Unparseable) (parsed (withoutToday Locale.en) "-7")
        , check "the days are counted from the day of the field" (Ok (Just "2024-03-01")) (parsed (onDay (date 2024 2 28)) "+2")
        , check "a relative date goes through the bounds: tomorrow is too late for a field that ends today"
            (Err (TooLate today))
            (parsed (between Nothing (Just today)) "+1")
        , check "and today is not too late" (Ok (Just "2026-10-20")) (parsed (between Nothing (Just today)) "t")
        , check "yesterday is too early for a field that starts today" (Err (TooEarly today)) (parsed (between (Just today) Nothing) "-1")
        ]


shortYearTests : Test
shortYearTests =
    describe "date: two-digit years (today is 2026-10-20)"
        [ readsInBoth "20.10.26" "2026-10-20"
        , readsInBoth "20.1 . 26" "2026-01-20"
        , readsInBoth "20.10.00" "2000-10-20"
        , readsInBoth "20.10.05" "2005-10-20"
        , readsInBoth "20.10.36" "2036-10-20"
        , readsInBoth "20.10.37" "1937-10-20"
        , readsInBoth "20.10.99" "1999-10-20"
        , readsInBoth "01.01.30" "2030-01-01"
        , readsInBoth "1/1/30" "2030-01-01"
        , readsInBoth "30-6-45" "1945-06-30"
        , check "a field that ends today reads 01.01.30 as 1930, as the documentation says" (Ok (Just "1930-01-01")) (parsed (between Nothing (Just today)) "01.01.30")
        , check "a field that starts in 2020 reads it as 2030" (Ok (Just "2030-01-01")) (parsed (between (Just (date 2020 1 1)) Nothing) "01.01.30")
        , check "a field that ends in 2050 reads 40 as 1940, the nearer century" (Ok (Just "1940-01-01")) (parsed (between Nothing (Just (date 2050 1 1))) "01.01.40")
        , check "a field that only has days in the 2090s reads 98 as 2098" (Ok (Just "2098-06-15")) (parsed (between (Just (date 2090 1 1)) (Just (date 2099 12 31))) "15.06.98")
        , check "a field that ends in 1999 reads 05 as 1905, because 2005 does not fit" (Ok (Just "1905-06-15")) (parsed (between Nothing (Just (date 1999 12 31))) "15.06.05")
        , check "when neither century fits, the first reading is kept and the bounds object" (Err (TooEarly (date 2040 1 1))) (parsed (between (Just (date 2040 1 1)) (Just (date 2041 1 1))) "01.01.30")
        , check "29 February in the year 00 is the leap day of 2000" (Ok (Just "2000-02-29")) (parsed (rules Locale.en) "29.02.00")
        , check "29 February in a short year that is no leap year" (Err Unparseable) (parsed (rules Locale.en) "29.02.25")
        , check "29 February in a short year that is a leap year" (Ok (Just "2028-02-29")) (parsed (rules Locale.en) "29.02.28")
        , check "in the year 2100, which is no leap year, 29.02.00 is read as 2000" (Ok (Just "2000-02-29")) (parsed (onDay (date 2100 5 5)) "29.02.00")
        , check "without today 49 is 2049" (Ok (Just "2049-05-05")) (parsed (withoutToday Locale.en) "5.5.49")
        , check "without today 50 is 1950" (Ok (Just "1950-05-05")) (parsed (withoutToday Locale.en) "5.5.50")
        , check "ten years after another today: in 2060 the year 70 is 2070" (Ok (Just "2070-01-01")) (parsed (onDay (date 2060 6 1)) "1.1.70")
        , check "and 71 is 1971" (Ok (Just "1971-01-01")) (parsed (onDay (date 2060 6 1)) "1.1.71")
        ]


digitsOnlyTests : Test
digitsOnlyTests =
    describe "date: digits only"
        [ readsInBoth "20102026" "2026-10-20"
        , readsInBoth "01022026" "2026-02-01"
        , readsInBoth "20261020" "2026-10-20"
        , readsInBoth "31122999" "2999-12-31"
        , reads Locale.nb "201026" "2026-10-20"
        , reads Locale.en "201026" "2020-10-26"
        , reads Locale.nb "010226" "2026-02-01"
        , reads Locale.en "260201" "2026-02-01"
        , readsInBoth "2010" "2026-10-20"
        , readsInBoth "0102" "2026-02-01"
        , readsInBoth "3112" "2026-12-31"
        , reads Locale.en "20101010" "2010-10-10"
        , reads Locale.nb "20101010" "1010-10-20"
        , rejectsInBoth "99999999"
        , rejectsInBoth "31042026"
        , rejectsInBoth "20132026"
        , rejectsInBoth "00102026"
        , rejectsInBoth "20100999"
        , rejectsInBoth "9999"
        , rejectsInBoth "3213"
        , rejectsInBoth "3002"
        , rejectsInBoth "0010"
        , rejectsInBoth "1"
        , rejectsInBoth "20"
        , rejectsInBoth "201"
        , rejectsInBoth "20102"
        , rejectsInBoth "2010202"
        , rejectsInBoth "201020261"
        , check "a month that does not exist in 6 digits" (Err Unparseable) (parsed (rules Locale.nb) "201326")
        , check "four digits need today" (Err Unparseable) (parsed (withoutToday Locale.en) "2010")
        , check "six digits do not" (Ok (Just "2026-10-20")) (parsed (withoutToday Locale.nb) "201026")
        , check "eight digits do not either" (Ok (Just "2026-10-20")) (parsed (withoutToday Locale.nb) "20102026")
        , check "four digits follow the year of today" (Ok (Just "2031-10-20")) (parsed (onDay (date 2031 1 1)) "2010")
        ]


boundsTests : Test
boundsTests =
    let
        r lower upper isDisabled =
            { locale = Locale.en, today = Just today, min = lower, max = upper, isDisabled = isDisabled }

        january =
            Just (date 2026 1 1)

        december =
            Just (date 2026 12 31)

        weekend day =
            Date.weekday day >= 6
    in
    describe "date: the bounds and the dates that are not available"
        [ check "inside" (Ok (Just "2026-06-15")) (parsed (r january december (always False)) "15.06.2026")
        , check "on the first day" (Ok (Just "2026-01-01")) (parsed (r january december (always False)) "1.1.2026")
        , check "on the last day" (Ok (Just "2026-12-31")) (parsed (r january december (always False)) "31.12.2026")
        , check "the day before the first" (Err (TooEarly (date 2026 1 1))) (parsed (r january december (always False)) "31.12.2025")
        , check "the day after the last" (Err (TooLate (date 2026 12 31))) (parsed (r january december (always False)) "1.1.2027")
        , check "only a start" (Err (TooEarly (date 2026 1 1))) (parsed (r january Nothing (always False)) "1.1.2000")
        , check "and nothing after it" (Ok (Just "2999-12-31")) (parsed (r january Nothing (always False)) "31.12.2999")
        , check "only an end" (Err (TooLate (date 2026 12 31))) (parsed (r Nothing december (always False)) "1.1.2100")
        , check "and nothing before it" (Ok (Just "1000-01-01")) (parsed (r Nothing december (always False)) "1.1.1000")
        , check "no bounds" (Ok (Just "1000-01-01")) (parsed (r Nothing Nothing (always False)) "1.1.1000")
        , check "the bounds apply to digits only" (Err (TooEarly (date 2026 1 1))) (parsed (r january december (always False)) "01012025")
        , check "the bounds apply to two-digit years" (Err (TooLate (date 2026 12 31))) (parsed (r january december (always False)) "1.1.27")
        , check "a Saturday is not available" (Err Unavailable) (parsed (r Nothing Nothing weekend) "24.10.2026")
        , check "a Sunday neither" (Err Unavailable) (parsed (r Nothing Nothing weekend) "25.10.2026")
        , check "a Friday is" (Ok (Just "2026-10-23")) (parsed (r Nothing Nothing weekend) "23.10.2026")
        , check "the start is checked before the end" (Err (TooEarly (date 2026 6 1))) (parsed (r (Just (date 2026 6 1)) (Just (date 2026 5 1)) (always False)) "1.1.2026")
        , check "and the end when the start is fine" (Err (TooLate (date 2026 5 1))) (parsed (r (Just (date 2026 6 1)) (Just (date 2026 5 1)) (always False)) "1.7.2026")
        , check "the bounds are checked before the dates that are not available" (Err (TooLate (date 2026 12 31))) (parsed (r january december (always True)) "1.1.2027")
        , check "text that is no date is no problem of the bounds" (Err Unparseable) (parsed (r january december (always True)) "not a date")
        , check "blank text is fine whatever the bounds" (Ok Nothing) (parsed (r january december (always True)) " ")
        , check "check on its own: inside" (Ok (date 2026 6 15)) (Parse.check (r january december (always False)) (date 2026 6 15))
        , check "check on its own: too early" (Err (TooEarly (date 2026 1 1))) (Parse.check (r january december (always False)) (date 2025 1 1))
        , check "check on its own: too late" (Err (TooLate (date 2026 12 31))) (Parse.check (r january december (always False)) (date 2027 1 1))
        , check "check on its own: not available" (Err Unavailable) (Parse.check (r Nothing Nothing (always True)) (date 2026 1 1))
        ]


messageTests : Test
messageTests =
    describe "date: messages"
        [ check "unparseable (English)" "Invalid date" (Parse.message Locale.en Unparseable)
        , check "unparseable (Norwegian)" "Ugyldig dato" (Parse.message Locale.nb Unparseable)
        , check "too early (English)" "The date cannot be before 2026-01-01" (Parse.message Locale.en (TooEarly (date 2026 1 1)))
        , check "too early (Norwegian)" "Datoen kan ikke være før 01.01.2026" (Parse.message Locale.nb (TooEarly (date 2026 1 1)))
        , check "too late (English)" "The date cannot be after 2026-12-31" (Parse.message Locale.en (TooLate (date 2026 12 31)))
        , check "too late (Norwegian)" "Datoen kan ikke være etter 31.12.2026" (Parse.message Locale.nb (TooLate (date 2026 12 31)))
        , check "unavailable (English)" "The date is not available" (Parse.message Locale.en Unavailable)
        , check "unavailable (Norwegian)" "Datoen er ikke tilgjengelig" (Parse.message Locale.nb Unavailable)
        , check "range order (English)" "The start date cannot be after the end date" (Parse.message Locale.en RangeOrder)
        , check "range order (Norwegian)" "Fra-datoen kan ikke være etter til-datoen" (Parse.message Locale.nb RangeOrder)
        , check "range too long (English)" "The period cannot be longer than 31 days" (Parse.message Locale.en (RangeTooLong 31))
        , check "range too long (Norwegian)" "Perioden kan ikke være lengre enn 31 dager" (Parse.message Locale.nb (RangeTooLong 31))
        , check "every problem has a message of its own in both languages"
            12
            (List.length
                (unique
                    (List.concatMap (\p -> [ Parse.message Locale.en p, Parse.message Locale.nb p ])
                        [ Unparseable, TooEarly today, TooLate today, Unavailable, RangeOrder, RangeTooLong 7 ]
                    )
                )
            )
        ]


unique : List String -> List String
unique list =
    List.foldr
        (\item kept ->
            if List.member item kept then
                kept

            else
                item :: kept
        )
        []
        list


isCompleteTests : Test
isCompleteTests =
    describe "isComplete"
        [ check "a date in full" True (Parse.isComplete "20.10.2026")
        , check "an ISO date" True (Parse.isComplete "2026-10-20")
        , check "with other separators" True (Parse.isComplete "20/10/2026")
        , check "with spaces as separators" True (Parse.isComplete "20 10 2026")
        , check "spaces around it do not count" True (Parse.isComplete "  20.10.2026  ")
        , check "a two-digit year is not complete" False (Parse.isComplete "20.10.26")
        , check "a year that is not finished" False (Parse.isComplete "20.10.202")
        , check "a day and a month" False (Parse.isComplete "20.10")
        , check "digits only" False (Parse.isComplete "20102026")
        , check "nothing" False (Parse.isComplete "")
        , check "text" False (Parse.isComplete "tomorrow")
        , check "one character too many" False (Parse.isComplete "20.10.2026x")
        , check "t is not a date in full" False (Parse.isComplete "t")
        , check "a day or a month with one digit and a four-digit year are complete, as the documentation says"
            []
            (List.filter (\text -> not (Parse.isComplete text)) [ "1.2.2026", "20.1.2026", "1.12.2026", "1/2/2026", "1 2 2026" ])
        , check "so are the documented forms with spaces around the separators"
            []
            (List.filter (\text -> not (Parse.isComplete text)) [ "20 / 10 / 2026", "20 - 10 - 2026", "20.1 . 2026", "2026 - 10 - 20" ])
        , check "a year first needs a month and a day of two digits, as the day may still get its second digit"
            [ False, False, False ]
            [ Parse.isComplete "2026-1-2", Parse.isComplete "2026-10-2", Parse.isComplete "2026-1-20" ]
        , check "a year of two digits may be the start of a year of four" False (Parse.isComplete "1.2.20")
        , check "a year of five digits is no year" False (Parse.isComplete "1.2.20265")
        , check "four groups of digits are not a date" False (Parse.isComplete "1.2.3.2026")
        , check "a group of three digits is no day" False (Parse.isComplete "100.2.2026")
        , check "a year first, with a year that is too long" False (Parse.isComplete "20265-10-20")
        , check "a complete text that is not a date is still complete, for the pickers to complain about" True (Parse.isComplete "99.99.9999")
        , fuzz dateFuzzer "every date written in full with zero padding is complete" <|
            \d ->
                Expect.equal [ True, True, True ]
                    [ Parse.isComplete (Format.date Locale.en d)
                    , Parse.isComplete (Format.date Locale.nb d)
                    , Parse.isComplete (String.join "/" [ pad (Date.day d), pad (Date.month d), String.fromInt (Date.year d) ])
                    ]
        , fuzz2 dateFuzzer separatorFuzzer "every date written in full is complete, with or without zero padding, whatever the separators" <|
            \d separator ->
                Expect.equal [ True, True, True, True ]
                    [ Parse.isComplete (String.join separator [ pad (Date.day d), pad (Date.month d), String.fromInt (Date.year d) ])
                    , Parse.isComplete (String.join separator [ String.fromInt (Date.day d), String.fromInt (Date.month d), String.fromInt (Date.year d) ])
                    , Parse.isComplete (String.join separator [ String.fromInt (Date.year d), pad (Date.month d), pad (Date.day d) ])
                    , Parse.isComplete ("  " ++ String.join separator [ String.fromInt (Date.day d), String.fromInt (Date.month d), String.fromInt (Date.year d) ] ++ " ")
                    ]
        , fuzz2 dateFuzzer separatorFuzzer "and no part of it that is shorter is complete: the picker waits for the last digit" <|
            \d separator ->
                let
                    written =
                        [ String.join separator [ pad (Date.day d), pad (Date.month d), String.fromInt (Date.year d) ]
                        , String.join separator [ String.fromInt (Date.day d), String.fromInt (Date.month d), String.fromInt (Date.year d) ]
                        , String.join separator [ String.fromInt (Date.year d), pad (Date.month d), pad (Date.day d) ]
                        ]

                    prefixes text =
                        List.map (\n -> String.left n text) (List.range 0 (String.length text - 1))
                in
                written
                    |> List.concatMap prefixes
                    |> List.filter Parse.isComplete
                    |> Expect.equal []
        ]



-- DATE PROPERTIES


dateProperties : Test
dateProperties =
    describe "date: properties"
        [ fuzz2 dateFuzzer separatorFuzzer "day, month and year with any separator, with or without zero padding, are read back" <|
            \d separator ->
                let
                    padded =
                        String.join separator [ pad (Date.day d), pad (Date.month d), String.fromInt (Date.year d) ]

                    plain =
                        String.join separator [ String.fromInt (Date.day d), String.fromInt (Date.month d), String.fromInt (Date.year d) ]
                in
                Expect.equal
                    (List.repeat 4 (Ok (Just d)))
                    [ Parse.date (rules Locale.en) padded, Parse.date (rules Locale.nb) padded, Parse.date (rules Locale.en) plain, Parse.date (rules Locale.nb) plain ]
        , fuzz2 dateFuzzer separatorFuzzer "year first is read back" <|
            \d separator ->
                Expect.equal
                    [ Ok (Just d), Ok (Just d) ]
                    (List.map (\locale -> Parse.date (rules locale) (String.join separator [ String.fromInt (Date.year d), pad (Date.month d), pad (Date.day d) ]))
                        [ Locale.en, Locale.nb ]
                    )
        , fuzz dateFuzzer "a date that Klar.Format writes is read back in English" <|
            \d -> Parse.date (rules Locale.en) (Format.date Locale.en d) |> Expect.equal (Ok (Just d))
        , fuzz dateFuzzer "and in Norwegian" <|
            \d -> Parse.date (rules Locale.nb) (Format.date Locale.nb d) |> Expect.equal (Ok (Just d))
        , fuzz dateFuzzer "eight digits with the day first are read back in Norwegian" <|
            \d -> Parse.date (rules Locale.nb) (pad (Date.day d) ++ pad (Date.month d) ++ String.fromInt (Date.year d)) |> Expect.equal (Ok (Just d))
        , fuzz dateFuzzer "eight digits with the year first are read back in English" <|
            \d -> Parse.date (rules Locale.en) (String.fromInt (Date.year d) ++ pad (Date.month d) ++ pad (Date.day d)) |> Expect.equal (Ok (Just d))
        , fuzz dateFuzzer "six digits, day first, read the same as the date with separators in Norwegian" <|
            \d ->
                let
                    short =
                        pad (modBy 100 (Date.year d))
                in
                Expect.equal
                    (Parse.date (rules Locale.nb) (pad (Date.day d) ++ "." ++ pad (Date.month d) ++ "." ++ short))
                    (Parse.date (rules Locale.nb) (pad (Date.day d) ++ pad (Date.month d) ++ short))
        , fuzz (Fuzz.intRange -36500 36500) "plus or minus a number of days is that many days from today" <|
            \n ->
                let
                    text =
                        if n >= 0 then
                            "+" ++ String.fromInt n

                        else
                            String.fromInt n
                in
                Parse.date (rules Locale.en) text |> Expect.equal (Ok (Just (Date.addDays n today)))
        , fuzz3 (Fuzz.intRange 0 99) (Fuzz.intRange 1 12) (Fuzz.intRange 1 28) "a two-digit year is a year from 89 years back to 10 years ahead, ending in the same two digits" <|
            \short month day ->
                let
                    text =
                        pad day ++ "." ++ pad month ++ "." ++ pad short
                in
                case Parse.date (rules Locale.en) text of
                    Ok (Just d) ->
                        Expect.all
                            [ \x -> Expect.atLeast (2026 - 89) (Date.year x)
                            , \x -> Expect.atMost (2026 + 10) (Date.year x)
                            , \x -> Expect.equal short (modBy 100 (Date.year x))
                            , \x -> Expect.equal ( month, day ) ( Date.month x, Date.day x )
                            ]
                            d

                    Ok Nothing ->
                        Expect.fail ("\"" ++ text ++ "\" was taken for no date")

                    Err problem ->
                        Expect.fail ("\"" ++ text ++ "\": " ++ Parse.message Locale.en problem)
        , fuzz Fuzz.string "any text is a valid date, no date or a problem, and never crashes" <|
            \text ->
                case Parse.date (rules Locale.en) text of
                    Ok (Just d) ->
                        Expect.equal True (isValid d)

                    Ok Nothing ->
                        Expect.equal "" (String.trim text)

                    Err _ ->
                        Expect.pass
        , fuzz dateLikeFuzzer "text that is close to a date is a date that reads back from the way it is written, or no date" <|
            \text ->
                case Parse.date (rules Locale.nb) text of
                    Ok (Just d) ->
                        Expect.all
                            [ \x -> Expect.equal True (isValid x)
                            , \x -> Expect.equal (Ok (Just x)) (Parse.date (rules Locale.nb) (Format.date Locale.nb x))
                            , \x -> Expect.equal (Ok (Just x)) (Parse.date (rules Locale.en) (Format.date Locale.en x))
                            ]
                            d

                    Ok Nothing ->
                        Expect.equal "" (String.trim text)

                    Err _ ->
                        Expect.pass
        , fuzz3 dateFuzzer dateFuzzer dateFuzzer "a date is accepted exactly when it is inside the bounds" <|
            \a b d ->
                let
                    lower =
                        Util.earlier a b

                    upper =
                        Util.later a b

                    expected =
                        if Util.before d lower then
                            Err (TooEarly lower)

                        else if Util.after d upper then
                            Err (TooLate upper)

                        else
                            Ok (Just d)
                in
                Parse.date (between (Just lower) (Just upper)) (Date.toIso d) |> Expect.equal expected
        , fuzz dateFuzzer "dates that are not available are refused" <|
            \d ->
                let
                    odd day =
                        modBy 2 (Date.toEpochDay day) == 1

                    r =
                        { locale = Locale.en, today = Just today, min = Nothing, max = Nothing, isDisabled = odd }
                in
                Parse.date r (Date.toIso d)
                    |> Expect.equal
                        (if odd d then
                            Err Unavailable

                         else
                            Ok (Just d)
                        )
        ]



-- TIMES


time : Int -> Int -> Parse.Time
time hour minute =
    { hour = hour, minute = minute }


openDay : Parse.TimeRules
openDay =
    { min = Nothing, max = Nothing }


readTime : String -> Result TimeProblem (Maybe String)
readTime text =
    Parse.time openDay text |> Result.map (Maybe.map Parse.formatTime)


readsTime : String -> String -> Test
readsTime text expected =
    check ("reads \"" ++ text ++ "\" as " ++ expected) (Ok (Just expected)) (readTime text)


rejectsTime : String -> Test
rejectsTime text =
    check ("rejects \"" ++ text ++ "\"") (Err TimeUnparseable) (readTime text)


timeTests : Test
timeTests =
    describe "time: the ways to write a time"
        [ readsTime "14:30" "14:30"
        , readsTime "14.30" "14:30"
        , readsTime "14,30" "14:30"
        , readsTime "14 30" "14:30"
        , readsTime "1430" "14:30"
        , readsTime "930" "09:30"
        , readsTime "0930" "09:30"
        , readsTime "9:30" "09:30"
        , readsTime "9:5" "09:05"
        , readsTime "9.5" "09:05"
        , readsTime "14" "14:00"
        , readsTime "9" "09:00"
        , readsTime "0" "00:00"
        , readsTime "00:00" "00:00"
        , readsTime "0:00" "00:00"
        , readsTime "0000" "00:00"
        , readsTime "23:59" "23:59"
        , readsTime "2359" "23:59"
        , readsTime "123" "01:23"
        , readsTime "1234" "12:34"
        , readsTime "14:" "14:00"
        , readsTime "kl 14:30" "14:30"
        , readsTime "kl. 14.30" "14:30"
        , readsTime "KL 14:30" "14:30"
        , readsTime "kl14:30" "14:30"
        , readsTime "  14:30  " "14:30"
        , readsTime "kl 9" "09:00"
        , check "blank text is no time, and no problem" (Ok Nothing) (readTime "   ")
        , check "the empty text too" (Ok Nothing) (readTime "")
        , rejectsTime "24:00"
        , rejectsTime "12:60"
        , rejectsTime "2400"
        , rejectsTime "99"
        , rejectsTime "1260"
        , rejectsTime "12345"
        , rejectsTime ":30"
        , rejectsTime ":"
        , rejectsTime "14:30:15"
        , rejectsTime "1:2:3"
        , rejectsTime "2pm"
        , rejectsTime "14h30"
        , rejectsTime "abc"
        , rejectsTime "kl"
        , rejectsTime "k l 14:30"
        , rejectsTime "14:300"
        , rejectsTime "-1"
        , rejectsTime "14:-5"
        , rejectsTime "1 4 3 0"
        , rejectsTime "١٤:٣٠"
        ]


timeBoundsTests : Test
timeBoundsTests =
    let
        office =
            { min = Just (time 8 0), max = Just (time 17 0) }

        from8 =
            { min = Just (time 8 0), max = Nothing }

        until17 =
            { min = Nothing, max = Just (time 17 0) }
    in
    describe "time: the bounds"
        [ check "inside" (Ok (Just (time 12 0))) (Parse.time office "12:00")
        , check "the first minute" (Ok (Just (time 8 0))) (Parse.time office "08:00")
        , check "the last minute" (Ok (Just (time 17 0))) (Parse.time office "17:00")
        , check "a minute too early" (Err (TimeTooEarly (time 8 0))) (Parse.time office "07:59")
        , check "a minute too late" (Err (TimeTooLate (time 17 0))) (Parse.time office "17:01")
        , check "midnight is too early for an office" (Err (TimeTooEarly (time 8 0))) (Parse.time office "0")
        , check "only a start" (Err (TimeTooEarly (time 8 0))) (Parse.time from8 "7")
        , check "and no end" (Ok (Just (time 23 59))) (Parse.time from8 "23:59")
        , check "only an end" (Err (TimeTooLate (time 17 0))) (Parse.time until17 "18")
        , check "and no start" (Ok (Just (time 0 0))) (Parse.time until17 "0")
        , check "text that is no time is no problem of the bounds" (Err TimeUnparseable) (Parse.time office "25:00")
        , check "blank text is fine whatever the bounds" (Ok Nothing) (Parse.time office "")
        , check "unparseable (English)" "Invalid time" (Parse.timeMessage Locale.en TimeUnparseable)
        , check "unparseable (Norwegian)" "Ugyldig klokkeslett" (Parse.timeMessage Locale.nb TimeUnparseable)
        , check "too early (English)" "The time cannot be before 08:00" (Parse.timeMessage Locale.en (TimeTooEarly (time 8 0)))
        , check "too early (Norwegian)" "Klokkeslettet kan ikke være før 08:00" (Parse.timeMessage Locale.nb (TimeTooEarly (time 8 0)))
        , check "too late (English)" "The time cannot be after 17:00" (Parse.timeMessage Locale.en (TimeTooLate (time 17 0)))
        , check "too late (Norwegian)" "Klokkeslettet kan ikke være etter 17:00" (Parse.timeMessage Locale.nb (TimeTooLate (time 17 0)))
        ]


minutesTests : Test
minutesTests =
    describe "time: minutes since midnight"
        [ check "toMinutes" 870 (Parse.toMinutes (time 14 30))
        , check "toMinutes at midnight" 0 (Parse.toMinutes (time 0 0))
        , check "toMinutes in the last minute of the day" 1439 (Parse.toMinutes (time 23 59))
        , check "fromMinutes" (time 14 30) (Parse.fromMinutes 870)
        , check "fromMinutes of 0" (time 0 0) (Parse.fromMinutes 0)
        , check "fromMinutes of 1439" (time 23 59) (Parse.fromMinutes 1439)
        , check "a whole day wraps to midnight" (time 0 0) (Parse.fromMinutes 1440)
        , check "a day and a minute" (time 0 1) (Parse.fromMinutes 1441)
        , check "a minute before midnight" (time 23 59) (Parse.fromMinutes -1)
        , check "a day back" (time 0 0) (Parse.fromMinutes -1440)
        , check "a day and an hour back" (time 23 0) (Parse.fromMinutes -1500)
        , check "a very large number of minutes" (time 10 40) (Parse.fromMinutes 1000000000)
        , check "formatTime pads the hour and the minute" "08:05" (Parse.formatTime (time 8 5))
        , check "formatTime at midnight" "00:00" (Parse.formatTime (time 0 0))
        , check "formatTime in the last minute" "23:59" (Parse.formatTime (time 23 59))
        , check "formatTime at noon" "12:00" (Parse.formatTime (time 12 0))
        ]


{-| Text made of the characters of times.
-}
timeLikeFuzzer : Fuzzer String
timeLikeFuzzer =
    Fuzz.oneOfValues (String.toList "0123456789:., kl")
        |> Fuzz.listOfLengthBetween 0 8
        |> Fuzz.map String.fromList


timeProperties : Test
timeProperties =
    describe "time: properties"
        [ fuzz2 (Fuzz.intRange 0 23) (Fuzz.intRange 0 59) "a time that is written in the usual ways is read back" <|
            \hour minute ->
                Expect.equal
                    (List.repeat 5 (Ok (Just (time hour minute))))
                    (List.map (Parse.time openDay)
                        [ Parse.formatTime (time hour minute)
                        , String.fromInt hour ++ "." ++ pad minute
                        , pad hour ++ pad minute
                        , "kl " ++ Parse.formatTime (time hour minute)
                        , String.fromInt hour ++ ":" ++ String.fromInt minute
                        ]
                    )
        , fuzz Fuzz.int "fromMinutes always gives a time of the day" <|
            \minutes ->
                let
                    t =
                        Parse.fromMinutes minutes
                in
                Expect.equal True (t.hour >= 0 && t.hour <= 23 && t.minute >= 0 && t.minute <= 59)
        , fuzz (Fuzz.intRange -2000000 2000000) "toMinutes of fromMinutes is the minute of the day" <|
            \minutes ->
                Parse.toMinutes (Parse.fromMinutes minutes) |> Expect.equal (modBy 1440 minutes)
        , fuzz (Fuzz.intRange 0 1439) "fromMinutes of toMinutes is the same time" <|
            \minutes ->
                Parse.fromMinutes minutes |> Parse.toMinutes |> Expect.equal minutes
        , fuzz Fuzz.string "any text is a time, no time or a problem, and never crashes" <|
            \text ->
                case Parse.time openDay text of
                    Ok (Just t) ->
                        Expect.equal True (t.hour >= 0 && t.hour <= 23 && t.minute >= 0 && t.minute <= 59)

                    Ok Nothing ->
                        Expect.equal "" (String.trim text)

                    Err _ ->
                        Expect.pass
        , fuzz timeLikeFuzzer "text that is close to a time is a time that reads back from the way it is written, or no time" <|
            \text ->
                case Parse.time openDay text of
                    Ok (Just t) ->
                        Expect.equal (Ok (Just t)) (Parse.time openDay (Parse.formatTime t))

                    Ok Nothing ->
                        Expect.equal "" (String.trim text)

                    Err _ ->
                        Expect.pass
        , fuzz3 (Fuzz.intRange 0 1439) (Fuzz.intRange 0 1439) (Fuzz.intRange 0 1439) "a time inside the bounds is accepted and one outside is refused with the bound it broke" <|
            \a b c ->
                let
                    lower =
                        min a b

                    upper =
                        max a b

                    bounds =
                        { min = Just (Parse.fromMinutes lower), max = Just (Parse.fromMinutes upper) }

                    expected =
                        if c < lower then
                            Err (TimeTooEarly (Parse.fromMinutes lower))

                        else if c > upper then
                            Err (TimeTooLate (Parse.fromMinutes upper))

                        else
                            Ok (Just (Parse.fromMinutes c))
                in
                Parse.time bounds (Parse.formatTime (Parse.fromMinutes c)) |> Expect.equal expected
        ]



-- UTIL: COMPARING AND CLAMPING


comparisonTests : Test
comparisonTests =
    let
        a =
            date 2026 10 20

        b =
            date 2026 10 21
    in
    describe "Util: comparing dates"
        [ check "before" [ True, False, False ] [ Util.before a b, Util.before a a, Util.before b a ]
        , check "after" [ False, False, True ] [ Util.after a b, Util.after a a, Util.after b a ]
        , check "atOrBefore" [ True, True, False ] [ Util.atOrBefore a b, Util.atOrBefore a a, Util.atOrBefore b a ]
        , check "atOrAfter" [ False, True, True ] [ Util.atOrAfter a b, Util.atOrAfter a a, Util.atOrAfter b a ]
        , check "earlier" [ a, a, a ] [ Util.earlier a b, Util.earlier b a, Util.earlier a a ]
        , check "later" [ b, b, a ] [ Util.later a b, Util.later b a, Util.later a a ]
        , check "across the end of a year" True (Util.before (date 2026 12 31) (date 2027 1 1))
        , check "across the end of a month" True (Util.before (date 2026 2 28) (date 2026 3 1))
        , check "years are compared before months" True (Util.after (date 2027 1 1) (date 2026 12 31))
        , check "months are compared before days" True (Util.after (date 2026 3 1) (date 2026 2 28))
        , check "the first year" True (Util.before (date 1 1 1) (date 1 1 2))
        , fuzz2 dateFuzzer dateFuzzer "agrees with the order of the day numbers" <|
            \x y ->
                Expect.equal
                    [ Date.toEpochDay x < Date.toEpochDay y, Date.toEpochDay x > Date.toEpochDay y, Date.toEpochDay x <= Date.toEpochDay y, Date.toEpochDay x >= Date.toEpochDay y ]
                    [ Util.before x y, Util.after x y, Util.atOrBefore x y, Util.atOrAfter x y ]
        , fuzz2 dateFuzzer dateFuzzer "earlier and later are the two dates, the earlier one first" <|
            \x y ->
                Expect.equal
                    (List.sortBy Date.toEpochDay [ x, y ])
                    [ Util.earlier x y, Util.later x y ]
        ]


clampTests : Test
clampTests =
    let
        low =
            Just (date 2026 3 1)

        high =
            Just (date 2026 9 30)
    in
    describe "Util: clampTo"
        [ check "inside both bounds" (date 2026 6 15) (Util.clampTo low high (date 2026 6 15))
        , check "below the lower bound" (date 2026 3 1) (Util.clampTo low high (date 2026 1 1))
        , check "above the upper bound" (date 2026 9 30) (Util.clampTo low high (date 2026 12 31))
        , check "on the lower bound" (date 2026 3 1) (Util.clampTo low high (date 2026 3 1))
        , check "on the upper bound" (date 2026 9 30) (Util.clampTo low high (date 2026 9 30))
        , check "no bounds" (date 1999 1 1) (Util.clampTo Nothing Nothing (date 1999 1 1))
        , check "only a lower bound, above it" (date 2100 1 1) (Util.clampTo low Nothing (date 2100 1 1))
        , check "only a lower bound, below it" (date 2026 3 1) (Util.clampTo low Nothing (date 2000 1 1))
        , check "only an upper bound, below it" (date 2000 1 1) (Util.clampTo Nothing high (date 2000 1 1))
        , check "only an upper bound, above it" (date 2026 9 30) (Util.clampTo Nothing high (date 2100 1 1))
        , check "a single day" (date 2026 5 5) (Util.clampTo (Just (date 2026 5 5)) (Just (date 2026 5 5)) (date 2030 1 1))
        , check "bounds that cross: the upper bound wins" (date 2026 3 1) (Util.clampTo high low (date 2026 6 15))
        , fuzz3 dateFuzzer dateFuzzer dateFuzzer "the result is inside the bounds, and is the date itself when it was inside" <|
            \x y z ->
                let
                    lower =
                        Util.earlier x y

                    upper =
                        Util.later x y

                    result =
                        Util.clampTo (Just lower) (Just upper) z
                in
                Expect.all
                    [ \r -> Expect.equal True (Util.atOrAfter r lower && Util.atOrBefore r upper)
                    , \r ->
                        if Util.atOrAfter z lower && Util.atOrBefore z upper then
                            Expect.equal z r

                        else
                            Expect.pass
                    ]
                    result
        , fuzz3 dateFuzzer dateFuzzer dateFuzzer "clamping twice is clamping once" <|
            \x y z ->
                let
                    clamp =
                        Util.clampTo (Just (Util.earlier x y)) (Just (Util.later x y))
                in
                Expect.equal (clamp z) (clamp (clamp z))
        ]



-- UTIL: WEEKS


{-| The ISO week number by another way than the library uses: week 1 is the week
that has 4 January in it, and weeks are counted from its Monday.
-}
referenceWeek : Date -> Int
referenceWeek d =
    let
        weekOne year =
            let
                fourth =
                    date year 1 4
            in
            Date.addDays (1 - Date.weekday fourth) fourth

        weekYear =
            if Util.before d (weekOne (Date.year d)) then
                Date.year d - 1

            else if Util.atOrAfter d (weekOne (Date.year d + 1)) then
                Date.year d + 1

            else
                Date.year d
    in
    Date.diffDays (weekOne weekYear) d // 7 + 1


{-| The week numbers of 28 to 31 December of a year and of 1 to 5 January of the
next, made by another program (the ISO calendar of Python) and written down here.
-}
weeksAroundNewYear : List ( Int, List Int )
weeksAroundNewYear =
    [ ( 2000, [ 52, 52, 52, 52, 1, 1, 1, 1, 1 ] )
    , ( 2001, [ 52, 52, 52, 1, 1, 1, 1, 1, 1 ] )
    , ( 2002, [ 52, 52, 1, 1, 1, 1, 1, 1, 1 ] )
    , ( 2003, [ 52, 1, 1, 1, 1, 1, 1, 1, 2 ] )
    , ( 2004, [ 53, 53, 53, 53, 53, 53, 1, 1, 1 ] )
    , ( 2005, [ 52, 52, 52, 52, 52, 1, 1, 1, 1 ] )
    , ( 2006, [ 52, 52, 52, 52, 1, 1, 1, 1, 1 ] )
    , ( 2007, [ 52, 52, 52, 1, 1, 1, 1, 1, 1 ] )
    , ( 2008, [ 52, 1, 1, 1, 1, 1, 1, 1, 2 ] )
    , ( 2009, [ 53, 53, 53, 53, 53, 53, 53, 1, 1 ] )
    , ( 2010, [ 52, 52, 52, 52, 52, 52, 1, 1, 1 ] )
    , ( 2011, [ 52, 52, 52, 52, 52, 1, 1, 1, 1 ] )
    , ( 2012, [ 52, 52, 52, 1, 1, 1, 1, 1, 1 ] )
    , ( 2013, [ 52, 52, 1, 1, 1, 1, 1, 1, 1 ] )
    , ( 2014, [ 52, 1, 1, 1, 1, 1, 1, 1, 2 ] )
    , ( 2015, [ 53, 53, 53, 53, 53, 53, 53, 1, 1 ] )
    , ( 2016, [ 52, 52, 52, 52, 52, 1, 1, 1, 1 ] )
    , ( 2017, [ 52, 52, 52, 52, 1, 1, 1, 1, 1 ] )
    , ( 2018, [ 52, 52, 52, 1, 1, 1, 1, 1, 1 ] )
    , ( 2019, [ 52, 52, 1, 1, 1, 1, 1, 1, 1 ] )
    , ( 2020, [ 53, 53, 53, 53, 53, 53, 53, 1, 1 ] )
    , ( 2021, [ 52, 52, 52, 52, 52, 52, 1, 1, 1 ] )
    , ( 2022, [ 52, 52, 52, 52, 52, 1, 1, 1, 1 ] )
    , ( 2023, [ 52, 52, 52, 52, 1, 1, 1, 1, 1 ] )
    , ( 2024, [ 52, 52, 1, 1, 1, 1, 1, 1, 1 ] )
    , ( 2025, [ 52, 1, 1, 1, 1, 1, 1, 1, 2 ] )
    , ( 2026, [ 53, 53, 53, 53, 53, 53, 53, 1, 1 ] )
    , ( 2027, [ 52, 52, 52, 52, 52, 52, 1, 1, 1 ] )
    , ( 2028, [ 52, 52, 52, 52, 1, 1, 1, 1, 1 ] )
    , ( 2029, [ 52, 52, 52, 1, 1, 1, 1, 1, 1 ] )
    , ( 2030, [ 52, 52, 1, 1, 1, 1, 1, 1, 1 ] )
    , ( 2031, [ 52, 1, 1, 1, 1, 1, 1, 1, 2 ] )
    , ( 2032, [ 53, 53, 53, 53, 53, 53, 1, 1, 1 ] )
    , ( 2033, [ 52, 52, 52, 52, 52, 1, 1, 1, 1 ] )
    , ( 2034, [ 52, 52, 52, 52, 1, 1, 1, 1, 1 ] )
    , ( 2035, [ 52, 52, 52, 1, 1, 1, 1, 1, 1 ] )
    , ( 2036, [ 52, 1, 1, 1, 1, 1, 1, 1, 2 ] )
    , ( 2037, [ 53, 53, 53, 53, 53, 53, 53, 1, 1 ] )
    , ( 2038, [ 52, 52, 52, 52, 52, 52, 1, 1, 1 ] )
    , ( 2039, [ 52, 52, 52, 52, 52, 1, 1, 1, 1 ] )
    , ( 2040, [ 52, 52, 52, 1, 1, 1, 1, 1, 1 ] )
    ]


weeksAround : Int -> List Int
weeksAround year =
    List.map (\day -> Util.isoWeek (date year 12 day)) [ 28, 29, 30, 31 ]
        ++ List.map (\day -> Util.isoWeek (date (year + 1) 1 day)) [ 1, 2, 3, 4, 5 ]


isoWeekTests : Test
isoWeekTests =
    describe "Util: isoWeek"
        [ check "1 January 2026, a Thursday, is in week 1" 1 (Util.isoWeek (date 2026 1 1))
        , check "28 December 2025 is in week 52" 52 (Util.isoWeek (date 2025 12 28))
        , check "29 December 2025, a Monday, is in week 1 of 2026" 1 (Util.isoWeek (date 2025 12 29))
        , check "31 December 2020 is in week 53" 53 (Util.isoWeek (date 2020 12 31))
        , check "1 January 2021, a Friday, is still in week 53" 53 (Util.isoWeek (date 2021 1 1))
        , check "3 January 2021, a Sunday, too" 53 (Util.isoWeek (date 2021 1 3))
        , check "4 January 2021, a Monday, is in week 1" 1 (Util.isoWeek (date 2021 1 4))
        , check "31 December 2018, a Monday, is in week 1 of 2019" 1 (Util.isoWeek (date 2018 12 31))
        , check "30 December 2024 is in week 1 of 2025" 1 (Util.isoWeek (date 2024 12 30))
        , check "1 January 2016 is in week 53 of 2015" 53 (Util.isoWeek (date 2016 1 1))
        , check "4 January 2016 is in week 1" 1 (Util.isoWeek (date 2016 1 4))
        , check "20 October 2026, the day of these tests, is in week 43" 43 (Util.isoWeek (date 2026 10 20))
        , check "29 February 2024 is in week 9" 9 (Util.isoWeek (date 2024 2 29))
        , check "31 December 2026 is in week 53" 53 (Util.isoWeek (date 2026 12 31))
        , check "1 January 2027, a Friday, is in week 53 of 2026" 53 (Util.isoWeek (date 2027 1 1))
        , check "the years of 2000 to 2040 that have 53 weeks"
            [ 2004, 2009, 2015, 2020, 2026, 2032, 2037 ]
            (List.filter (\year -> Util.isoWeek (date year 12 28) == 53) (List.range 2000 2040))
        , check "4 January is in week 1 in every year from 1000 to 2999"
            []
            (List.filter (\year -> Util.isoWeek (date year 1 4) /= 1) (List.range 1000 2999))
        , check "a year has 53 weeks when it starts on a Thursday, or on a Wednesday if it is a leap year"
            []
            (List.filter
                (\year ->
                    let
                        startsOn =
                            Date.weekday (date year 1 1)

                        expected =
                            startsOn == 4 || (startsOn == 3 && Date.isLeapYear year)
                    in
                    (Util.isoWeek (date year 12 28) == 53) /= expected
                )
                (List.range 1000 2999)
            )
        , test "agrees with the week that has 4 January in it, for every day of 1990 to 2060" <|
            \_ ->
                List.range (Date.toEpochDay (date 1990 1 1)) (Date.toEpochDay (date 2060 12 31))
                    |> List.map Date.fromEpochDay
                    |> List.filter (\day -> Util.isoWeek day /= referenceWeek day)
                    |> List.take 3
                    |> List.map Date.toIso
                    |> Expect.equal []
        , describe "the days around a new year, from a table made by another program"
            (List.map
                (\( year, expected ) ->
                    check ("from 28 December " ++ String.fromInt year ++ " to 5 January " ++ String.fromInt (year + 1)) expected (weeksAround year)
                )
                weeksAroundNewYear
            )
        , fuzz dateFuzzer "is between 1 and 53" <|
            \d -> Expect.all [ \w -> Expect.atLeast 1 w, \w -> Expect.atMost 53 w ] (Util.isoWeek d)
        , fuzz dateFuzzer "all the days of a week have the same number" <|
            \d ->
                Expect.equal True
                    (List.all (\offset -> Util.isoWeek (Date.addDays offset (Util.startOfWeek d)) == Util.isoWeek d) (List.range 0 6))
        , fuzz dateFuzzer "the next week has the next number, or 1 at the end of the year" <|
            \d ->
                let
                    this =
                        Util.isoWeek d

                    next =
                        Util.isoWeek (Date.addDays 7 d)
                in
                Expect.equal True (next == this + 1 || next == 1)
        ]


weekTests : Test
weekTests =
    describe "Util: startOfWeek and endOfWeek"
        [ check "the start of the week of a Tuesday is the Monday before" (date 2026 10 19) (Util.startOfWeek (date 2026 10 20))
        , check "the end of the week of a Tuesday is the Sunday after" (date 2026 10 25) (Util.endOfWeek (date 2026 10 20))
        , check "a Monday is the start of its week" (date 2026 10 19) (Util.startOfWeek (date 2026 10 19))
        , check "and the end of it is six days later" (date 2026 10 25) (Util.endOfWeek (date 2026 10 19))
        , check "a Sunday is the end of its week" (date 2026 10 25) (Util.endOfWeek (date 2026 10 25))
        , check "and the start of it is six days earlier" (date 2026 10 19) (Util.startOfWeek (date 2026 10 25))
        , check "across a new year" ( date 2025 12 29, date 2026 1 4 ) ( Util.startOfWeek (date 2026 1 1), Util.endOfWeek (date 2026 1 1) )
        , check "across a leap day" ( date 2024 2 26, date 2024 3 3 ) ( Util.startOfWeek (date 2024 2 29), Util.endOfWeek (date 2024 2 29) )
        , fuzz dateFuzzer "the start is a Monday, the end a Sunday, and the date is in between" <|
            \d ->
                Expect.all
                    [ \x -> Expect.equal 1 (Date.weekday (Util.startOfWeek x))
                    , \x -> Expect.equal 7 (Date.weekday (Util.endOfWeek x))
                    , \x -> Expect.equal 6 (Date.diffDays (Util.startOfWeek x) (Util.endOfWeek x))
                    , \x -> Expect.equal True (Util.atOrBefore (Util.startOfWeek x) x && Util.atOrAfter (Util.endOfWeek x) x)
                    ]
                    d
        ]



-- UTIL: MONTHS


monthArithmeticTests : Test
monthArithmeticTests =
    describe "Util: months"
        [ check "monthIndex counts months from the year 0" 24312 (Util.monthIndex 2026 1)
        , check "the next month has the next index" (Util.monthIndex 2026 10 + 1) (Util.monthIndex 2026 11)
        , check "December and the next January are one apart" (Util.monthIndex 2026 12 + 1) (Util.monthIndex 2027 1)
        , check "monthOfIndex undoes monthIndex" ( 2026, 10 ) (Util.monthOfIndex (Util.monthIndex 2026 10))
        , check "the documented example" ( 2027, 1 ) (Util.addMonthsTo 2 ( 2026, 11 ))
        , check "no months" ( 2026, 11 ) (Util.addMonthsTo 0 ( 2026, 11 ))
        , check "one month" ( 2026, 12 ) (Util.addMonthsTo 1 ( 2026, 11 ))
        , check "one month back" ( 2026, 10 ) (Util.addMonthsTo -1 ( 2026, 11 ))
        , check "back over the new year" ( 2025, 12 ) (Util.addMonthsTo -1 ( 2026, 1 ))
        , check "twelve months is a year" ( 2027, 3 ) (Util.addMonthsTo 12 ( 2026, 3 ))
        , check "twelve months back is a year back" ( 2025, 3 ) (Util.addMonthsTo -12 ( 2026, 3 ))
        , check "a hundred years" ( 2126, 3 ) (Util.addMonthsTo 1200 ( 2026, 3 ))
        , check "a hundred years back" ( 1926, 3 ) (Util.addMonthsTo -1200 ( 2026, 3 ))
        , check "to the last month of the year 9999" ( 9999, 12 ) (Util.addMonthsTo 1 ( 9999, 11 ))
        , check "from the year 1 back to its first month" ( 1, 1 ) (Util.addMonthsTo -11 ( 1, 12 ))
        , check "from the first month of the year 1 back one month is December of the year 0" ( 0, 12 ) (Util.addMonthsTo -1 ( 1, 1 ))
        , check "a month of the year -1 is a month of the year -1" ( -1, 3 ) (Util.monthOfIndex (Util.monthIndex -1 3))
        , check "so is the first month of it" ( -1, 1 ) (Util.monthOfIndex (Util.monthIndex -1 1))
        , check "and the last month of the year before it" ( -2, 12 ) (Util.monthOfIndex (Util.monthIndex -2 12))
        , check "paging back from the year 0 into the year -1" ( -1, 12 ) (Util.addMonthsTo -1 ( 0, 1 ))
        , fuzz3 (Fuzz.intRange 1 9999) (Fuzz.intRange 1 12) (Fuzz.intRange -130000 100000) "adding months gives a valid month, that many months on" <|
            \year month n ->
                let
                    ( y, m ) =
                        Util.addMonthsTo n ( year, month )
                in
                Expect.all
                    [ \_ -> Expect.equal True (m >= 1 && m <= 12)
                    , \_ -> Expect.equal (Util.monthIndex year month + n) (Util.monthIndex y m)
                    ]
                    ()
        , fuzz2 (Fuzz.intRange -3000 9999) (Fuzz.intRange 1 12) "monthOfIndex undoes monthIndex for every month, before the year 0 too" <|
            \year month -> Expect.equal ( year, month ) (Util.monthOfIndex (Util.monthIndex year month))
        , fuzz3 (Fuzz.intRange 1 9999) (Fuzz.intRange 1 12) (Fuzz.intRange 0 12000) "adding and taking away the same months gives the same month" <|
            \year month n ->
                Expect.equal ( year, month ) (Util.addMonthsTo -n (Util.addMonthsTo n ( year, month )))
        , fuzz3 (Fuzz.intRange 1 9999) (Fuzz.intRange 1 12) (Fuzz.intRange 1 28) "adding months here agrees with Date.addMonths" <|
            \year month day ->
                let
                    ( y, m ) =
                        Util.addMonthsTo 7 ( year, month )

                    moved =
                        Date.addMonths 7 (date year month day)
                in
                Expect.equal ( Date.year moved, Date.month moved ) ( y, m )
        ]


{-| Every `Date` is a day that exists; reading the parts back must give the same date.
-}
isValid : Date -> Bool
isValid d =
    Date.fromParts (Date.year d) (Date.month d) (Date.day d) == Just d
