module RulesFixTest exposing (suite)

{-| Regression tests for the second pass over the rule and shortcut modules:

  - `Rule.parseNumber` reads "1,234.5" (English), "1.234,5" and "1 234,5"
    (Norwegian and German) as well as "12,5" and "12.5", negative numbers
    included, and still says `Nothing` to anything that is not a number.
  - `Rule.operatorLabel` keeps its signature; only equality depends on the kind
    of field ("is" on text, `=` on numbers).
  - A shortcut for the plus key (`"+"`, `"mod++"`) fires, and `Shortcut.keycaps`
    shows the plus.
  - Shortcuts do not fire while the user types in a field, a text area, a
    select or an editable element, with or without Ctrl, Alt or Cmd, unless
    they are marked `inInputs`. A character typed with AltGr never fires a
    shortcut in a field. Everywhere else nothing changed.
  - The placeholder of the name of a saved view is neutral.

-}

import Expect exposing (Expectation)
import Fuzz exposing (Fuzzer)
import Html exposing (Html)
import Html.Attributes as Attr
import Json.Encode as Encode
import Klar.Date as Date
import Klar.FilterBar as FilterBar
import Klar.Format as Format
import Klar.Locale as Locale exposing (Locale)
import Klar.Overlay as Overlay
import Klar.Remote as Remote exposing (Remote(..))
import Klar.Rule as Rule exposing (FieldKind, Operator(..), Rule(..))
import Klar.RuleBuilder as RuleBuilder
import Klar.SavedViews as SavedViews
import Klar.Shortcut as Shortcut exposing (Shortcut)
import Klar.ShortcutHelp as ShortcutHelp
import Support.Keys as Keys
import Test exposing (Test, describe, fuzz, test)
import Test.Html.Event as Event
import Test.Html.Query as Query
import Test.Html.Selector as Selector
import Time


suite : Test
suite =
    describe "Fixes in Klar.Rule, Klar.Shortcut, Klar.ShortcutHelp and Klar.SavedViews"
        [ parseNumberTests
        , parseNumberPropertyTests
        , rulesWithSeparatorsTests
        , operatorLabelTests
        , exactLabelTests
        , describeDaysTests
        , filterBarCountingTests
        , plusKeyTests
        , keycapsTests
        , typingTests
        , dialogTests
        , pageTests
        , altGrTests
        , sequenceTests
        , helpSheetTests
        , savedViewsTests
        ]



-- parseNumber


parses : String -> Float -> Test
parses text expected =
    parsesNamed ("\"" ++ text ++ "\"") text expected


{-| For texts with spaces that cannot be told apart in the name of a test.
-}
parsesNamed : String -> String -> Float -> Test
parsesNamed name text expected =
    test (name ++ " is " ++ String.fromFloat expected) <|
        \_ -> Expect.equal (Just expected) (Rule.parseNumber text)


isNoNumber : String -> Test
isNoNumber text =
    test ("\"" ++ text ++ "\" is no number") <|
        \_ -> Expect.equal Nothing (Rule.parseNumber text)


parseNumberTests : Test
parseNumberTests =
    describe "Rule.parseNumber"
        [ describe "English: commas between the thousands, a point for the decimals"
            [ parses "1,234.5" 1234.5
            , parses "1,234,567.89" 1234567.89
            , parses "1,234,567" 1234567
            , parses "12,345.678" 12345.678
            , parses "999,999.99" 999999.99
            , parses "1,234." 1234
            ]
        , describe "Norwegian and German: points or spaces between the thousands, a comma for the decimals"
            [ parses "1.234,5" 1234.5
            , parses "1.234.567,89" 1234567.89
            , parses "1.234.567" 1234567
            , parses "1 234,5" 1234.5
            , parses "1 234 567" 1234567
            , parses "12 345,67" 12345.67
            , parsesNamed "a non-breaking space" "1\u{00A0}234,5" 1234.5
            , parsesNamed "a narrow non-breaking space" "1\u{202F}234,5" 1234.5
            , parsesNamed "a thin space" "1\u{2009}234" 1234
            ]
        , describe "a decimal point or comma"
            [ parses "12.5" 12.5
            , parses "12,5" 12.5
            , parses "0.5" 0.5
            , parses "0,5" 0.5
            , parses "1.23" 1.23
            , parses "1,23" 1.23
            , parses "1.2345" 1.2345
            , parses "1,2345" 1.2345
            , parses "1234.567" 1234.567
            , parses "1234,567" 1234.567
            , parses "12 345.678" 12345.678
            ]
        , describe "a single separator with exactly three digits after it is ambiguous"
            [ parses "1,234" 1.234
            , parses "12,345" 12.345
            , parses "123,456" 123.456
            , parses "1.234" 1234
            , parses "12.500" 12500
            , parses "123.456" 123456
            , parses "1.000" 1000
            , parses "0.125" 0.125
            , parses "0,125" 0.125
            , parses "00.125" 0.125
            ]
        , describe "negative numbers"
            [ parses "-3" -3
            , parses "-12,5" -12.5
            , parses "-12.5" -12.5
            , parses "-0.5" -0.5
            , parses "-.5" -0.5
            , parses "-1,234.5" -1234.5
            , parses "-1.234,5" -1234.5
            , parses "-1 234,5" -1234.5
            , parses "-1.234" -1234
            , parses "-1,234" -1.234
            , parses "- 5" -5
            , parsesNamed "the minus sign U+2212 that Klar.Format writes" "−5" -5
            , parsesNamed "the minus sign U+2212 and thousands" "−1 234,5" -1234.5
            , parses "+3" 3
            , parses "+1,234.5" 1234.5
            ]
        , describe "what was a number before is still a number"
            [ parses "42" 42
            , parses "0" 0
            , parses "007" 7
            , parses "  7  " 7
            , parses ".5" 0.5
            , parses ",5" 0.5
            , parses "5." 5
            , parses "5," 5
            , parses "1e3" 1000
            , parses "1,5e3" 1500
            , parsesNamed "a non-breaking space between the thousands" "1\u{00A0}000" 1000
            ]
        , describe "separators in the wrong places"
            (List.map isNoNumber
                [ "1,234,5"
                , "12,34,567"
                , "1.2.3"
                , "1,2,3"
                , "1.234.56"
                , "1,234.567,8"
                , "1.234,567.8"
                , "1,23.4"
                , "12.345,6789.1"
                , "1,.5"
                , "1.5."
                , "0,234.5"
                , "01,234.5"
                ]
            )
        , describe "garbage"
            (List.map isNoNumber
                [ ""
                , "   "
                , "abc"
                , "ten"
                , "12kg"
                , "kg12"
                , "1 2 3 e"
                , "--5"
                , "+-5"
                , "-+5"
                , "5-"
                , "1-2"
                , "-"
                , "+"
                , "."
                , ","
                , ".,"
                , "0x10"
                , "Infinity"
                , "-Infinity"
                , "NaN"
                , "1e999"
                , "٣"
                ]
            )
        ]


numberish : Fuzzer String
numberish =
    Fuzz.list (Fuzz.oneOfValues (String.toList "0123456789.,-+ eE\u{00A0}−"))
        |> Fuzz.map String.fromList


parseNumberPropertyTests : Test
parseNumberPropertyTests =
    describe "Rule.parseNumber (properties)"
        [ fuzz Fuzz.string "a number is never NaN or infinite" <|
            \text -> expectFinite (Rule.parseNumber text)
        , fuzz numberish "a number made of digits, separators and signs is never NaN or infinite" <|
            \text -> expectFinite (Rule.parseNumber text)
        , fuzz (Fuzz.intRange -2000000000 2000000000) "a whole number reads as itself" <|
            \n -> Expect.equal (Just (toFloat n)) (Rule.parseNumber (String.fromInt n))
        , fuzz (Fuzz.intRange -2000000000 2000000000) "a number that Klar.Format writes in Norwegian reads back" <|
            \n -> Expect.equal (Just (toFloat n)) (Rule.parseNumber (Format.int Locale.nb n))
        , fuzz (Fuzz.intRange 1000000 2000000000) "a big number that Klar.Format writes in English reads back" <|
            \n -> Expect.equal (Just (toFloat n)) (Rule.parseNumber (Format.int Locale.en n))
        , fuzz (Fuzz.intRange -999 999) "a small number that Klar.Format writes in English reads back" <|
            \n -> Expect.equal (Just (toFloat n)) (Rule.parseNumber (Format.int Locale.en n))
        , fuzz (Fuzz.intRange -100000000 100000000) "an amount with two decimals reads back in English" <|
            \cents ->
                let
                    amount =
                        toFloat cents / 100
                in
                Expect.equal (Just amount) (Rule.parseNumber (Format.decimal Locale.en 2 amount))
        , fuzz (Fuzz.intRange -100000000 100000000) "an amount with two decimals reads back in Norwegian" <|
            \cents ->
                let
                    amount =
                        toFloat cents / 100
                in
                Expect.equal (Just amount) (Rule.parseNumber (Format.decimal Locale.nb 2 amount))
        ]


expectFinite : Maybe Float -> Expectation
expectFinite parsed =
    case parsed of
        Just n ->
            Expect.equal False (isNaN n || isInfinite n)

        Nothing ->
            Expect.pass



-- rules with separators in the operands


totalIs : Operator -> List String -> Rule
totalIs operator operands =
    ConditionRule { id = 1, field = "total", operator = operator, values = operands }


totalFields : List (Rule.Field Float)
totalFields =
    [ Rule.numberField "total" "Total" Just ]


rulesWithSeparatorsTests : Test
rulesWithSeparatorsTests =
    let
        matching operator operands total =
            Rule.matches (Date.fromEpochDay 20746) totalFields (totalIs operator operands) total

        issues operator operands =
            List.map .message (Rule.validate Locale.en totalFields (totalIs operator operands))
    in
    describe "rules with separators in the numbers"
        [ test "a total of 2 000 is above \"1,234.5\"" <|
            \_ -> Expect.equal True (matching GreaterThan [ "1,234.5" ] 2000)
        , test "a total of 1 000 is not above \"1,234.5\"" <|
            \_ -> Expect.equal False (matching GreaterThan [ "1,234.5" ] 1000)
        , test "a total of 1 000 is not above \"1.234,5\"" <|
            \_ -> Expect.equal False (matching GreaterThan [ "1.234,5" ] 1000)
        , test "a total of 2 000 is above \"1 234,5\"" <|
            \_ -> Expect.equal True (matching GreaterThan [ "1 234,5" ] 2000)
        , test "a total of 1 234.5 is equal to \"1,234.5\"" <|
            \_ -> Expect.equal True (matching Is [ "1,234.5" ] 1234.5)
        , test "a total of 1 500 is between \"1,000.5\" and \"2.000,5\"" <|
            \_ -> Expect.equal True (matching Between [ "1,000.5", "2.000,5" ] 1500)
        , test "a total of 3 000 is not between \"1,000.5\" and \"2.000,5\"" <|
            \_ -> Expect.equal False (matching Between [ "1,000.5", "2.000,5" ] 3000)
        , test "a number with separators is not reported as invalid" <|
            \_ -> Expect.equal [] (issues GreaterThan [ "1,234.5" ])
        , test "numbers with separators in the wrong order are reported" <|
            \_ -> Expect.equal [ "The first value must not be larger than the second" ] (issues Between [ "2.000,5", "1,000.5" ])
        , test "garbage is still reported as invalid" <|
            \_ -> Expect.equal [ "Enter a valid number" ] (issues GreaterThan [ "1,2,3" ])
        , test "a total of -2 000 is below \"-1.234,5\", a total of -1 000 is not" <|
            \_ -> Expect.equal [ True, False ] [ matching LessThan [ "-1.234,5" ] -2000, matching LessThan [ "-1.234,5" ] -1000 ]
        ]



-- Rule.operatorLabel


allOperators : List Operator
allOperators =
    [ Is, IsNot, Contains, NotContains, StartsWith, EndsWith, LessThan, LessOrEqual, GreaterThan, GreaterOrEqual, Between, NotBetween, Before, After, OnOrBefore, OnOrAfter, InLastDays, InNextDays, MoreThanDaysAgo, MoreThanDaysAhead, InPeriod, IsAnyOf, IsNoneOf, IsEmpty, IsNotEmpty, IsTrue, IsFalse ]


allKinds : List FieldKind
allKinds =
    [ Rule.textKind, Rule.numberKind, Rule.dateKind, Rule.booleanKind, Rule.choiceKind [ { value = "paid", label = "Paid" } ] ]


operatorLabelTests : Test
operatorLabelTests =
    describe "Rule.operatorLabel"
        [ test "takes a locale, the kind of the field and an operator" <|
            \_ -> Expect.equal "does not contain" (Rule.operatorLabel Locale.en Rule.textKind NotContains)
        , test "is written in Norwegian for the Norwegian locale" <|
            \_ -> Expect.equal "inneholder ikke" (Rule.operatorLabel Locale.nb Rule.textKind NotContains)
        , test "\"is\" reads the same for every kind of field but numbers, where it is =" <|
            \_ ->
                Expect.equal
                    [ "is", "=", "is", "is", "is" ]
                    (List.map (\kind -> Rule.operatorLabel Locale.en kind Is) allKinds)
        , describe "does not depend on the kind of field, but for equality"
            (List.concatMap
                (\locale ->
                    List.map
                        (\operator ->
                            test (Locale.toCode locale ++ ": " ++ Rule.operatorLabel locale Rule.textKind operator) <|
                                \_ ->
                                    Expect.equal
                                        (List.map (\_ -> Rule.operatorLabel locale Rule.textKind operator) allKinds)
                                        (List.map (\kind -> Rule.operatorLabel locale kind operator) allKinds)
                        )
                        (List.filter (\operator -> operator /= Is && operator /= IsNot) allOperators)
                )
                Locale.all
            )
        ]


englishLabels : List ( Operator, String )
englishLabels =
    [ ( Is, "is" )
    , ( IsNot, "is not" )
    , ( Contains, "contains" )
    , ( NotContains, "does not contain" )
    , ( StartsWith, "starts with" )
    , ( EndsWith, "ends with" )
    , ( LessThan, "<" )
    , ( LessOrEqual, "≤" )
    , ( GreaterThan, ">" )
    , ( GreaterOrEqual, "≥" )
    , ( Between, "between" )
    , ( NotBetween, "not between" )
    , ( Before, "before" )
    , ( After, "after" )
    , ( OnOrBefore, "on or before" )
    , ( OnOrAfter, "on or after" )
    , ( InLastDays, "in the last (days)" )
    , ( InNextDays, "in the next (days)" )
    , ( MoreThanDaysAgo, "more than (days) ago" )
    , ( MoreThanDaysAhead, "in more than (days)" )
    , ( InPeriod, "is within" )
    , ( IsAnyOf, "is any of" )
    , ( IsNoneOf, "is none of" )
    , ( IsEmpty, "is empty" )
    , ( IsNotEmpty, "is not empty" )
    , ( IsTrue, "is yes" )
    , ( IsFalse, "is no" )
    ]


norwegianLabels : List ( Operator, String )
norwegianLabels =
    [ ( Is, "er" )
    , ( IsNot, "er ikke" )
    , ( Contains, "inneholder" )
    , ( NotContains, "inneholder ikke" )
    , ( StartsWith, "starter med" )
    , ( EndsWith, "slutter med" )
    , ( LessThan, "<" )
    , ( LessOrEqual, "≤" )
    , ( GreaterThan, ">" )
    , ( GreaterOrEqual, "≥" )
    , ( Between, "mellom" )
    , ( NotBetween, "ikke mellom" )
    , ( Before, "før" )
    , ( After, "etter" )
    , ( OnOrBefore, "senest" )
    , ( OnOrAfter, "tidligst" )
    , ( InLastDays, "siste (dager)" )
    , ( InNextDays, "neste (dager)" )
    , ( MoreThanDaysAgo, "for mer enn (dager) siden" )
    , ( MoreThanDaysAhead, "om mer enn (dager)" )
    , ( InPeriod, "er innenfor" )
    , ( IsAnyOf, "er en av" )
    , ( IsNoneOf, "er ingen av" )
    , ( IsEmpty, "er tom" )
    , ( IsNotEmpty, "er ikke tom" )
    , ( IsTrue, "er ja" )
    , ( IsFalse, "er nei" )
    ]


labelOf : Locale -> Operator -> String
labelOf locale operator =
    Rule.operatorLabel locale Rule.textKind operator


exactLabelTests : Test
exactLabelTests =
    describe "the label of every operator"
        [ describe "in English"
            (List.map
                (\( operator, label ) -> test label (\_ -> Expect.equal label (labelOf Locale.en operator)))
                englishLabels
            )
        , describe "in Norwegian"
            (List.map
                (\( operator, label ) -> test label (\_ -> Expect.equal label (labelOf Locale.nb operator)))
                norwegianLabels
            )
        , test "the lists above name every operator once" <|
            \_ ->
                Expect.equal
                    (List.map (Rule.operatorLabel Locale.en Rule.textKind) allOperators)
                    (List.map Tuple.second englishLabels)
        , describe "the operators of a kind of field have different labels in the picker"
            (List.concatMap
                (\locale ->
                    List.map
                        (\kind ->
                            let
                                labels =
                                    List.map (Rule.operatorLabel locale kind) (Rule.operatorsFor kind)
                            in
                            test (Locale.toCode locale ++ ": " ++ String.join ", " labels) <|
                                \_ -> Expect.equal labels (unique labels)
                        )
                        allKinds
                )
                Locale.all
            )
        ]


unique : List String -> List String
unique labels =
    List.foldl
        (\label kept ->
            if List.member label kept then
                kept

            else
                kept ++ [ label ]
        )
        []
        labels



-- describing days


createdFields : List (Rule.Field ())
createdFields =
    [ Rule.dateField "created" "Created" (\_ -> Nothing) ]


inDays : Operator -> String -> Rule
inDays operator days =
    ConditionRule { id = 1, field = "created", operator = operator, values = [ days ] }


describeDaysTests : Test
describeDaysTests =
    let
        sentence locale operator days =
            Rule.describe locale createdFields (inDays operator days)

        chip locale days =
            FilterBar.init "bar"
                |> FilterBar.setRule (inDays InLastDays days)
                |> filterBar locale []
                |> Query.fromHtml
                |> Query.find [ Selector.class "klar-filterbar__chip-value" ]
    in
    describe "one day is not written in the plural"
        [ describe "the sentence"
            [ test "English, in the last 1 day" <|
                \_ -> Expect.equal "Created in the last 1 day" (sentence Locale.en InLastDays "1")
            , test "English, in the next 1 day" <|
                \_ -> Expect.equal "Created in the next 1 day" (sentence Locale.en InNextDays "1")
            , test "English, in the last 30 days" <|
                \_ -> Expect.equal "Created in the last 30 days" (sentence Locale.en InLastDays "30")
            , test "English, in the next 7 days" <|
                \_ -> Expect.equal "Created in the next 7 days" (sentence Locale.en InNextDays "7")
            , test "English, in the last 0 days" <|
                \_ -> Expect.equal "Created in the last 0 days" (sentence Locale.en InLastDays "0")
            , test "English, 1,0 is one day too, written as it was read" <|
                \_ -> Expect.equal "Created in the last 1 day" (sentence Locale.en InLastDays "1,0")
            , test "Norwegian, siste 1 dag" <|
                \_ -> Expect.equal "Created siste 1 dag" (sentence Locale.nb InLastDays "1")
            , test "Norwegian, neste 1 dag" <|
                \_ -> Expect.equal "Created neste 1 dag" (sentence Locale.nb InNextDays "1")
            , test "Norwegian, siste 30 dager" <|
                \_ -> Expect.equal "Created siste 30 dager" (sentence Locale.nb InLastDays "30")
            , test "Norwegian, neste 7 dager" <|
                \_ -> Expect.equal "Created neste 7 dager" (sentence Locale.nb InNextDays "7")
            ]
        , describe "the chip of the filter bar"
            [ test "English, 1 day" <|
                \_ -> chip Locale.en "1" |> Query.has [ Selector.text "1 day" ]
            , test "English, 30 days" <|
                \_ -> chip Locale.en "30" |> Query.has [ Selector.text "30 days" ]
            , test "Norwegian, 1 dag" <|
                \_ -> chip Locale.nb "1" |> Query.has [ Selector.text "1 dag" ]
            , test "Norwegian, 30 dager" <|
                \_ -> chip Locale.nb "30" |> Query.has [ Selector.text "30 dager" ]
            , test "English, 1 is not written as 1 days" <|
                \_ -> chip Locale.en "1" |> Query.hasNot [ Selector.text "1 days" ]
            ]
        ]



-- the count of the filter bar and the rule builder


filterBar : Locale -> List (FilterBar.Attribute () Msg) -> FilterBar.State -> Html Msg
filterBar locale attributes state =
    FilterBar.view FilterMsg
        ([ FilterBar.locale locale, FilterBar.fields createdFields ] ++ attributes)
        state


theCount : Locale -> List (FilterBar.Attribute () Msg) -> Query.Single Msg
theCount locale attributes =
    filterBar locale attributes (FilterBar.init "bar")
        |> Query.fromHtml
        |> Query.find [ Selector.class "klar-filterbar__count" ]


theBuilderCount : List (RuleBuilder.Attribute () Msg) -> Query.Single Msg
theBuilderCount attributes =
    RuleBuilder.view BuilderMsg attributes (RuleBuilder.init "builder")
        |> Query.fromHtml
        |> Query.find [ Selector.class "klar-rules__matches" ]


filterBarCountingTests : Test
filterBarCountingTests =
    describe "the match count of the filter bar and the rule builder"
        [ test "Loading shows \"Counting ...\" and a spinner" <|
            \_ ->
                theCount Locale.en [ FilterBar.matchCount Loading ]
                    |> Expect.all
                        [ Query.has [ Selector.text "Counting ..." ]
                        , Query.find [ Selector.class "klar-spinner" ] >> Query.has [ Selector.tag "span" ]
                        ]
        , test "shows it in Norwegian for the Norwegian locale" <|
            \_ -> theCount Locale.nb [ FilterBar.matchCount Loading ] |> Query.has [ Selector.text "Teller ..." ]
        , test "a refreshed count stays, dimmed and busy, with a spinner" <|
            \_ ->
                theCount Locale.en [ FilterBar.matchCount (Remote.refresh (Loaded 3)), FilterBar.totalCount 10 ]
                    |> Expect.all
                        [ Query.find [ Selector.tag "strong" ] >> Query.has [ Selector.text "3" ]
                        , Query.has [ Selector.class "klar-rule-count--refreshing" ]
                        , Query.find [ Selector.class "klar-rule-count__text" ] >> Query.has [ Selector.attribute (Attr.attribute "aria-busy" "true") ]
                        , Query.find [ Selector.class "klar-spinner" ] >> Query.has [ Selector.tag "span" ]
                        ]
        , test "a failed count says so and offers the retry" <|
            \_ ->
                theCount Locale.en [ FilterBar.matchCount (Failed (Remote.problem Remote.network)), FilterBar.onRetry Retried ]
                    |> Expect.all
                        [ Query.has [ Selector.text "The count failed" ]
                        , Query.find [ Selector.tag "button" ] >> Event.simulate Event.click >> Event.expect Retried
                        ]
        , test "while the retry of an old count runs, the button stays, busy" <|
            \_ ->
                let
                    old =
                        Remote.refreshWith (Remote.refresh (Loaded 3)) (Err (Remote.problem Remote.network)) (Time.millisToPosix 0)
                in
                Expect.all
                    [ \_ ->
                        theCount Locale.en [ FilterBar.matchCount old, FilterBar.onRetry Retried ]
                            |> Query.find [ Selector.id "bar-count-retry" ]
                            |> Event.simulate Event.click
                            |> Event.expect Retried
                    , \_ ->
                        theCount Locale.en [ FilterBar.matchCount (Remote.refresh old), FilterBar.onRetry Retried ]
                            |> Query.find [ Selector.id "bar-count-retry" ]
                            |> Query.has [ Selector.attribute (Attr.attribute "aria-busy" "true"), Selector.attribute (Attr.attribute "aria-disabled" "true") ]
                    , \_ ->
                        theCount Locale.en [ FilterBar.matchCount (Remote.refresh old), FilterBar.onRetry Retried ]
                            |> Query.findAll [ Selector.class "klar-spinner" ]
                            |> Query.count (Expect.equal 1)
                    ]
                    ()
        , test "without onRetry a failed count has no button" <|
            \_ ->
                theCount Locale.en [ FilterBar.matchCount (Failed (Remote.problem Remote.network)) ]
                    |> Query.findAll [ Selector.tag "button" ]
                    |> Query.count (Expect.equal 0)
        , test "the live region is there before the first count" <|
            \_ ->
                theCount Locale.en []
                    |> Query.find [ Selector.class "klar-rule-count__text" ]
                    |> Query.has [ Selector.attribute (Attr.attribute "aria-live" "polite") ]
        , test "the live region is the same element when the count comes" <|
            \_ ->
                theCount Locale.en [ FilterBar.matchCount (Loaded 3) ]
                    |> Query.find [ Selector.class "klar-rule-count__text" ]
                    |> Expect.all
                        [ Query.has [ Selector.attribute (Attr.attribute "aria-live" "polite") ]
                        , Query.has [ Selector.text "matches" ]
                        ]
        , test "NotAsked shows no count" <|
            \_ ->
                theCount Locale.en [ FilterBar.matchCount NotAsked ]
                    |> Query.findAll [ Selector.tag "strong" ]
                    |> Query.count (Expect.equal 0)
        , test "the count with a total reads \"3 of 10 matches\"" <|
            \_ ->
                theCount Locale.en [ FilterBar.matchCount (Loaded 3), FilterBar.totalCount 10 ]
                    |> Expect.all
                        [ Query.find [ Selector.tag "strong" ] >> Query.has [ Selector.text "3" ]
                        , Query.has [ Selector.text "of 10 matches" ]
                        ]
        , test "the rule builder says the same" <|
            \_ ->
                Expect.all
                    [ \_ -> Expect.all runningChecks (theBuilderCount [ RuleBuilder.matchCount Loading ])
                    , \_ -> Expect.all runningChecks (theCount Locale.en [ FilterBar.matchCount Loading ])
                    ]
                    ()
        ]


{-| What the count says while the application counts: the words and a spinner.
-}
runningChecks : List (Query.Single Msg -> Expectation)
runningChecks =
    [ Query.has [ Selector.text "Counting ..." ]
    , Query.find [ Selector.class "klar-rule-count__text" ] >> Query.has [ Selector.attribute (Attr.attribute "aria-live" "polite") ]
    , Query.find [ Selector.class "klar-spinner" ] >> Query.has [ Selector.class "klar-spinner--sm" ]
    ]



-- shortcuts: pressing keys


type Msg
    = Retried
    | ShortcutMsg Shortcut.Msg
    | OpenPalette
    | GoToOrders
    | ShowHelp
    | ZoomIn
    | ZoomInPlain
    | Close
    | Save
    | SelectAll
    | ToggleSidebar
    | SwitchLanguage
    | Mention
    | HelpMsg ShortcutHelp.Msg
    | FilterMsg FilterBar.Msg
    | BuilderMsg RuleBuilder.Msg


type Target
    = OnPage
    | OnButton
    | InTextField
    | InTextArea
    | InSelect
    | InEditable
    | InDialog
    | InDialogTextField


type alias Key =
    { key : String
    , ctrl : Bool
    , meta : Bool
    , alt : Bool
    , shift : Bool
    , time : Float
    , target : Target
    }


plain : String -> Key
plain name =
    { key = name, ctrl = False, meta = False, alt = False, shift = False, time = 1000, target = OnPage }


withShift : String -> Key
withShift name =
    let
        key =
            plain name
    in
    { key | shift = True }


withCtrl : String -> Key
withCtrl name =
    let
        key =
            plain name
    in
    { key | ctrl = True }


withCmd : String -> Key
withCmd name =
    let
        key =
            plain name
    in
    { key | meta = True }


withAlt : String -> Key
withAlt name =
    let
        key =
            plain name
    in
    { key | alt = True }


withCtrlAndAlt : String -> Key
withCtrlAndAlt name =
    let
        key =
            plain name
    in
    { key | ctrl = True, alt = True }


{-| What Windows reports for a character typed with AltGr: Ctrl and Alt
together, and the character itself as the key.
-}
altGr : String -> Key
altGr character =
    let
        key =
            plain character
    in
    { key | ctrl = True, alt = True }


at : Target -> Key -> Key
at target key =
    { key | target = target }


element : String -> Bool -> Bool -> Encode.Value
element tag editable insideDialog =
    Encode.object
        ([ ( "tagName", Encode.string tag )
         , ( "isContentEditable", Encode.bool editable )
         ]
            ++ (if insideDialog then
                    [ ( "parentElement", Encode.object [ ( "ariaModal", Encode.string "true" ) ] ) ]

                else
                    []
               )
        )


targetJson : Target -> Encode.Value
targetJson target =
    case target of
        OnPage ->
            element "BODY" False False

        OnButton ->
            element "BUTTON" False False

        InTextField ->
            element "INPUT" False False

        InTextArea ->
            element "TEXTAREA" False False

        InSelect ->
            element "SELECT" False False

        InEditable ->
            element "DIV" True False

        InDialog ->
            element "BUTTON" False True

        InDialogTextField ->
            element "INPUT" False True


keydown : Key -> ( String, Encode.Value )
keydown key =
    Event.custom "keydown"
        (Encode.object
            [ ( "key", Encode.string key.key )
            , ( "ctrlKey", Encode.bool key.ctrl )
            , ( "metaKey", Encode.bool key.meta )
            , ( "altKey", Encode.bool key.alt )
            , ( "shiftKey", Encode.bool key.shift )
            , ( "repeat", Encode.bool False )
            , ( "timeStamp", Encode.float key.time )
            , ( "target", targetJson key.target )
            ]
        )


type Outcome
    = Fires Msg
    | Accepted
    | Ignored


{-| Press the key on the element that listens, and let the application handle
the message the way it would.
-}
press : List (Shortcut Msg) -> Shortcut.State -> Key -> ( Shortcut.State, Outcome )
press shortcuts state key =
    case pressEvent shortcuts state key |> Event.toResult of
        Err _ ->
            ( state, Ignored )

        Ok (ShortcutMsg inner) ->
            case Shortcut.update shortcuts inner state of
                ( next, Just fired ) ->
                    ( next, Fires fired )

                ( next, Nothing ) ->
                    ( next, Accepted )

        Ok other ->
            ( state, Fires other )


pressEvent : List (Shortcut Msg) -> Shortcut.State -> Key -> Event.Event Msg
pressEvent shortcuts state key =
    Html.div [ Shortcut.listen ShortcutMsg shortcuts state ] []
        |> Query.fromHtml
        |> Event.simulate (keydown key)


fires : Msg -> List (Shortcut Msg) -> Key -> Expectation
fires expected shortcuts key =
    Expect.equal (Fires expected) (Tuple.second (press shortcuts Shortcut.init key))


staysSilent : List (Shortcut Msg) -> Key -> Expectation
staysSilent shortcuts key =
    Expect.equal Ignored (Tuple.second (press shortcuts Shortcut.init key))


{-| The browser's own action is prevented when a shortcut fires.
-}
preventsDefault : List (Shortcut Msg) -> Key -> Expectation
preventsDefault shortcuts key =
    pressEvent shortcuts Shortcut.init key |> Event.expectPreventDefault


palette : Shortcut Msg
palette =
    Shortcut.shortcut (Shortcut.mod (Shortcut.char 'k')) "Navigation" "Open the command palette" OpenPalette


goToOrders : Shortcut Msg
goToOrders =
    Shortcut.shortcut (Shortcut.sequence [ Shortcut.char 'g', Shortcut.char 'o' ]) "Navigation" "Go to orders" GoToOrders


help : Shortcut Msg
help =
    Shortcut.shortcut (Shortcut.char '?') "Help" "Show the keyboard shortcuts" ShowHelp


close : Shortcut Msg
close =
    Shortcut.shortcut Shortcut.escape "Navigation" "Close" Close


save : Shortcut Msg
save =
    Shortcut.shortcut (Shortcut.mod (Shortcut.char 's')) "Orders" "Save the order" Save


selectAll : Shortcut Msg
selectAll =
    Shortcut.shortcut (Shortcut.mod (Shortcut.char 'a')) "Orders" "Select all orders" SelectAll


switchLanguage : Shortcut Msg
switchLanguage =
    Shortcut.shortcut (Shortcut.alt (Shortcut.char 'l')) "View" "Switch the language" SwitchLanguage


sidebar : Shortcut Msg
sidebar =
    Shortcut.shortcut (Shortcut.char '[') "View" "Show or hide the sidebar" ToggleSidebar


mention : Shortcut Msg
mention =
    Shortcut.shortcut (Shortcut.char '@') "Orders" "Mention a colleague" Mention



-- shortcuts: the plus key


plusKeyTests : Test
plusKeyTests =
    let
        plus =
            Shortcut.shortcut (Shortcut.char '+') "View" "Zoom in" ZoomInPlain

        ctrlPlus =
            Shortcut.shortcut (Shortcut.mod (Shortcut.char '+')) "View" "Zoom in" ZoomIn
    in
    describe "a shortcut for the plus key"
        [ test "\"+\" fires on Shift and + (the plus key of a US keyboard)" <|
            \_ -> fires ZoomInPlain [ plus ] (withShift "+")
        , test "\"+\" fires on + without Shift (the numeric keypad)" <|
            \_ -> fires ZoomInPlain [ plus ] (plain "+")
        , test "\"mod++\" fires on Ctrl and +" <|
            \_ -> fires ZoomIn [ ctrlPlus ] (withCtrl "+")
        , test "\"mod++\" fires on Cmd and +" <|
            \_ -> fires ZoomIn [ ctrlPlus ] (withCmd "+")
        , test "\"mod++\" fires on Ctrl, Shift and + (Ctrl and the plus key of a US keyboard)" <|
            \_ -> fires ZoomIn [ ctrlPlus ] { key = "+", ctrl = True, meta = False, alt = False, shift = True, time = 1000, target = OnPage }
        , test "\"mod++\" does not fire on + alone" <|
            \_ -> staysSilent [ ctrlPlus ] (plain "+")
        , test "\"+\" does not fire on Ctrl and +" <|
            \_ -> staysSilent [ plus ] (withCtrl "+")
        , test "\"mod++\" and \"+\" are told apart" <|
            \_ ->
                Expect.equal
                    [ Fires ZoomIn, Fires ZoomInPlain ]
                    [ Tuple.second (press [ plus, ctrlPlus ] Shortcut.init (withCtrl "+"))
                    , Tuple.second (press [ plus, ctrlPlus ] Shortcut.init (plain "+"))
                    ]
        , test "\"+\" does not fire on another key" <|
            \_ -> staysSilent [ plus ] (plain "-")
        , test "the plus key can end a sequence" <|
            \_ ->
                let
                    zoom =
                        Shortcut.shortcut (Shortcut.sequence [ Shortcut.char 'z', Shortcut.char '+' ]) "View" "Zoom in" ZoomInPlain

                    ( afterZ, first ) =
                        press [ zoom ] Shortcut.init (plain "z")

                    second =
                        Tuple.second (press [ zoom ] afterZ (withShift "+"))
                in
                Expect.equal [ Accepted, Fires ZoomInPlain ] [ first, second ]
        , test "a fired \"+\" prevents the browser's own action" <|
            \_ -> preventsDefault [ plus ] (withShift "+")
        , test "a fired \"mod++\" prevents the browser's own action" <|
            \_ -> preventsDefault [ ctrlPlus ] (withCtrl "+")
        ]


keycapsTests : Test
keycapsTests =
    let
        caps name keys expected =
            test name <| \_ -> Expect.equal expected (Shortcut.keycaps (Keys.parse keys))
    in
    describe "Shortcut.keycaps"
        [ caps "the plus key" "+" [ [ "+" ] ]
        , caps "Ctrl and the plus key" "mod++" [ [ "Ctrl", "+" ] ]
        , caps "Alt and the plus key" "alt++" [ [ "Alt", "+" ] ]
        , caps "Shift and the plus key" "shift++" [ [ "Shift", "+" ] ]
        , caps "Ctrl, Shift and the plus key" "mod+shift++" [ [ "Ctrl", "Shift", "+" ] ]
        , caps "the modifiers are written in the same order whatever the order of the description" "shift+mod++" [ [ "Ctrl", "Shift", "+" ] ]
        , caps "a sequence that ends with the plus key" "z +" [ [ "Z" ], [ "+" ] ]
        , caps "a sequence that starts with the plus key" "+ z" [ [ "+" ], [ "Z" ] ]
        , caps "Ctrl and a letter" "mod+k" [ [ "Ctrl", "K" ] ]
        , caps "mod is written as Ctrl" "mod+s" [ [ "Ctrl", "S" ] ]
        , caps "a sequence of two letters" "g m" [ [ "G" ], [ "M" ] ]
        , caps "a question mark" "?" [ [ "?" ] ]
        , caps "Escape" "esc" [ [ "Esc" ] ]
        , caps "arrows" "alt+shift+up" [ [ "Alt", "Shift", "↑" ] ]
        ]



-- shortcuts: typing in a field


typingTests : Test
typingTests =
    describe "while the user types"
        (List.map typingIn
            [ ( "in a text field", InTextField )
            , ( "in a text area", InTextArea )
            , ( "in a select", InSelect )
            , ( "in an editable element", InEditable )
            , ( "in a text field inside a dialog", InDialogTextField )
            ]
        )


typingIn : ( String, Target ) -> Test
typingIn ( name, target ) =
    describe name
        [ test "Ctrl and K does not fire" <|
            \_ -> staysSilent [ palette ] (at target (withCtrl "k"))
        , test "Cmd and K does not fire" <|
            \_ -> staysSilent [ palette ] (at target (withCmd "k"))
        , test "Alt and L does not fire" <|
            \_ -> staysSilent [ switchLanguage ] (at target (withAlt "l"))
        , test "Ctrl and S does not fire" <|
            \_ -> staysSilent [ save ] (at target (withCtrl "s"))
        , test "Ctrl and A does not fire" <|
            \_ -> staysSilent [ selectAll ] (at target (withCtrl "a"))
        , test "a question mark does not fire" <|
            \_ -> staysSilent [ help ] (at target (withShift "?"))
        , test "Escape does not fire" <|
            \_ -> staysSilent [ close ] (at target (plain "Escape"))
        , test "the first key of a sequence does not start it" <|
            \_ -> staysSilent [ goToOrders ] (at target (plain "g"))
        , test "Ctrl and K fires when the shortcut is marked inInputs" <|
            \_ -> fires OpenPalette [ Shortcut.inInputs palette ] (at target (withCtrl "k"))
        , test "Cmd and K fires when the shortcut is marked inInputs" <|
            \_ -> fires OpenPalette [ Shortcut.inInputs palette ] (at target (withCmd "k"))
        , test "Alt and L fires when the shortcut is marked inInputs" <|
            \_ -> fires SwitchLanguage [ Shortcut.inInputs switchLanguage ] (at target (withAlt "l"))
        , test "Escape fires when the shortcut is marked inInputs" <|
            \_ -> fires Close [ Shortcut.inInputs close ] (at target (plain "Escape"))
        , test "a question mark fires when the shortcut is marked inInputs" <|
            \_ -> fires ShowHelp [ Shortcut.inInputs help ] (at target (withShift "?"))
        , test "only the shortcuts marked inInputs fire" <|
            \_ ->
                Expect.equal
                    [ Fires OpenPalette, Ignored ]
                    [ Tuple.second (press [ Shortcut.inInputs palette, save ] Shortcut.init (at target (withCtrl "k")))
                    , Tuple.second (press [ Shortcut.inInputs palette, save ] Shortcut.init (at target (withCtrl "s")))
                    ]
        , test "a shortcut that fires prevents the browser's own action" <|
            \_ -> preventsDefault [ Shortcut.inInputs palette ] (at target (withCtrl "k"))
        , test "a character typed with AltGr does not fire a shortcut" <|
            \_ -> staysSilent [ mention ] (at target (altGr "@"))
        , test "a character typed with AltGr does not fire a shortcut marked inInputs either" <|
            \_ -> staysSilent [ Shortcut.inInputs mention ] (at target (altGr "@"))
        ]



-- shortcuts: inside a dialog, but not in a field


dialogTests : Test
dialogTests =
    describe "inside a dialog (not in a field)"
        [ test "a plain key does not fire" <|
            \_ -> staysSilent [ help ] (at InDialog (withShift "?"))
        , test "the first key of a sequence does not start it" <|
            \_ -> staysSilent [ goToOrders ] (at InDialog (plain "g"))
        , test "Ctrl and K fires" <|
            \_ -> fires OpenPalette [ palette ] (at InDialog (withCtrl "k"))
        , test "Cmd and K fires" <|
            \_ -> fires OpenPalette [ palette ] (at InDialog (withCmd "k"))
        , test "Alt and L fires" <|
            \_ -> fires SwitchLanguage [ switchLanguage ] (at InDialog (withAlt "l"))
        , test "Ctrl and A is left to select everything" <|
            \_ -> staysSilent [ selectAll ] (at InDialog (withCtrl "a"))
        , test "a plain key fires when the shortcut is marked inInputs" <|
            \_ -> fires Close [ Shortcut.inInputs close ] (at InDialog (plain "Escape"))
        , test "Ctrl and A fires when the shortcut is marked inInputs" <|
            \_ -> fires SelectAll [ Shortcut.inInputs selectAll ] (at InDialog (withCtrl "a"))
        , test "a character typed with AltGr counts as the plain symbol, which stays out of the dialog" <|
            \_ -> staysSilent [ sidebar ] (at InDialog (altGr "["))
        ]



-- shortcuts: on the page


pageTests : Test
pageTests =
    describe "on the page"
        (List.map onThePage
            [ ( "with nothing focused", OnPage )
            , ( "on a button", OnButton )
            ]
        )


onThePage : ( String, Target ) -> Test
onThePage ( name, target ) =
    describe name
        [ test "a plain key fires" <|
            \_ -> fires ShowHelp [ help ] (at target (withShift "?"))
        , test "Escape fires" <|
            \_ -> fires Close [ close ] (at target (plain "Escape"))
        , test "Ctrl and K fires" <|
            \_ -> fires OpenPalette [ palette ] (at target (withCtrl "k"))
        , test "Cmd and K fires" <|
            \_ -> fires OpenPalette [ palette ] (at target (withCmd "k"))
        , test "Alt and L fires" <|
            \_ -> fires SwitchLanguage [ switchLanguage ] (at target (withAlt "l"))
        , test "Ctrl and A fires" <|
            \_ -> fires SelectAll [ selectAll ] (at target (withCtrl "a"))
        , test "a shortcut that fires prevents the browser's own action" <|
            \_ -> preventsDefault [ palette ] (at target (withCtrl "k"))
        , test "another key does nothing" <|
            \_ -> staysSilent [ palette, help, close ] (at target (plain "x"))
        , test "a key that is held down does not repeat the shortcut" <|
            \_ ->
                let
                    event =
                        Html.div [ Shortcut.listen ShortcutMsg [ help ] Shortcut.init ] []
                            |> Query.fromHtml
                            |> Event.simulate
                                (Event.custom "keydown"
                                    (Encode.object
                                        [ ( "key", Encode.string "?" )
                                        , ( "ctrlKey", Encode.bool False )
                                        , ( "metaKey", Encode.bool False )
                                        , ( "altKey", Encode.bool False )
                                        , ( "shiftKey", Encode.bool True )
                                        , ( "repeat", Encode.bool True )
                                        , ( "target", targetJson target )
                                        ]
                                    )
                                )
                in
                case Event.toResult event of
                    Err _ ->
                        Expect.pass

                    Ok _ ->
                        Expect.fail "a repeated key press fired the shortcut"
        ]



-- shortcuts: AltGr


altGrTests : Test
altGrTests =
    describe "characters typed with AltGr"
        [ test "AltGr and 8 on a German keyboard is a \"[\" and fires a shortcut for \"[\" on the page" <|
            \_ -> fires ToggleSidebar [ sidebar ] (altGr "[")
        , test "it is not Ctrl, Alt and 8" <|
            \_ -> staysSilent [ Shortcut.shortcut (Shortcut.mod (Shortcut.alt (Shortcut.char '8'))) "View" "Something else" Mention ] (altGr "[")
        , test "it is not Ctrl, Alt and \"[\" either" <|
            \_ -> staysSilent [ Shortcut.shortcut (Shortcut.mod (Shortcut.alt (Shortcut.char '['))) "View" "Something else" Mention ] (altGr "[")
        , test "the Option key of a Mac gives the character, not Alt and a key" <|
            \_ -> staysSilent [ switchLanguage ] (withAlt "¬")
        , test "Ctrl, Alt and a letter is a real combination" <|
            \_ -> fires Mention [ Shortcut.shortcut (Shortcut.mod (Shortcut.alt (Shortcut.char 'n'))) "Orders" "Mention" Mention ] (withCtrlAndAlt "n")
        ]



-- shortcuts: sequences


sequenceTests : Test
sequenceTests =
    describe "sequences"
        [ test "a sequence fires when the second key follows" <|
            \_ ->
                let
                    ( afterG, first ) =
                        press [ goToOrders ] Shortcut.init (plain "g")

                    second =
                        Tuple.second (press [ goToOrders ] afterG { key = "o", ctrl = False, meta = False, alt = False, shift = False, time = 1500, target = OnPage })
                in
                Expect.equal [ Accepted, Fires GoToOrders ] [ first, second ]
        , test "the first key of a sequence does not prevent the browser's own action" <|
            \_ -> pressEvent [ goToOrders ] Shortcut.init (plain "g") |> Event.expectNotPreventDefault
        , test "a sequence does not start in a field" <|
            \_ -> staysSilent [ goToOrders ] (at InTextField (plain "g"))
        ]



-- the help sheet


helpSheet : List (Shortcut Msg) -> Html Msg
helpSheet shortcuts =
    ShortcutHelp.init "help"
        |> ShortcutHelp.open ""
        |> Tuple.first
        |> ShortcutHelp.view HelpMsg [] shortcuts
        |> List.singleton
        |> (\overlays -> Overlay.host { attributes = [], page = [], overlays = overlays })


helpSheetTests : Test
helpSheetTests =
    describe "the help sheet"
        [ test "writes mod as Ctrl and shows the plus key" <|
            \_ ->
                helpSheet [ Shortcut.shortcut (Shortcut.mod (Shortcut.char '+')) "View" "Zoom in" ZoomIn ]
                    |> Query.fromHtml
                    |> Query.find [ Selector.class "klar-kbd-combo" ]
                    |> Query.findAll [ Selector.tag "kbd" ]
                    |> Expect.all
                        [ Query.count (Expect.equal 2)
                        , Query.index 0 >> Query.has [ Selector.text "Ctrl" ]
                        , Query.index 1 >> Query.has [ Selector.text "+" ]
                        ]
        , test "shows the plus key of a shortcut with only the plus key" <|
            \_ ->
                helpSheet [ Shortcut.shortcut (Shortcut.char '+') "View" "Zoom in" ZoomInPlain ]
                    |> Query.fromHtml
                    |> Query.find [ Selector.class "klar-kbd-combo" ]
                    |> Query.findAll [ Selector.tag "kbd" ]
                    |> Expect.all
                        [ Query.count (Expect.equal 1)
                        , Query.index 0 >> Query.has [ Selector.text "+" ]
                        ]
        , test "says that shortcuts do not work in a field unless stated otherwise" <|
            \_ ->
                helpSheet [ palette ]
                    |> Query.fromHtml
                    |> Query.contains [ Html.text "Shortcuts do not work while you type in a field, unless stated otherwise." ]
        , test "marks a shortcut that works in a field" <|
            \_ ->
                helpSheet [ Shortcut.inInputs palette, help ]
                    |> Query.fromHtml
                    |> Query.findAll [ Selector.class "klar-shortcuts__note" ]
                    |> Query.count (Expect.equal 1)
        ]



-- saved views


type ViewsMsg
    = ViewsMsg SavedViews.Msg


viewsView : Locale -> SavedViews.State -> Html ViewsMsg
viewsView locale state =
    SavedViews.view ViewsMsg
        [ SavedViews.locale locale
        , SavedViews.current Rule.emptyGroup
        ]
        state


{-| Click the element with this id, and let the component handle the message.
-}
clickOn : Locale -> String -> SavedViews.State -> Result String SavedViews.State
clickOn locale id state =
    viewsView locale state
        |> Query.fromHtml
        |> Query.find [ Selector.id id ]
        |> Event.simulate Event.click
        |> Event.toResult
        |> Result.map (\(ViewsMsg msg) -> Tuple.first (SavedViews.update msg state))


{-| The component with its list open and the form to save a view on screen.
-}
savingAView : Locale -> Result String SavedViews.State
savingAView locale =
    SavedViews.init "views"
        |> clickOn locale "views-trigger"
        |> Result.andThen (clickOn locale "views-save")


inTheNameField : Locale -> (Query.Single ViewsMsg -> Expectation) -> Expectation
inTheNameField locale check =
    case savingAView locale of
        Err why ->
            Expect.fail why

        Ok state ->
            viewsView locale state
                |> Query.fromHtml
                |> Query.find [ Selector.id "views-name" ]
                |> check


savedViewsTests : Test
savedViewsTests =
    describe "the name of a saved view"
        [ test "the English placeholder is neutral" <|
            \_ ->
                inTheNameField Locale.en
                    (Query.has [ Selector.attribute (Attr.placeholder "For example “Overdue in Oslo”") ])
        , test "the Norwegian placeholder is neutral" <|
            \_ ->
                inTheNameField Locale.nb
                    (Query.has [ Selector.attribute (Attr.placeholder "For eksempel «Forfalt i Oslo»") ])
        , test "the English placeholder says nothing about risk" <|
            \_ ->
                inTheNameField Locale.en
                    (Query.hasNot [ Selector.attribute (Attr.placeholder "For example “High risk in Oslo”") ])
        , test "the Norwegian placeholder says nothing about risk" <|
            \_ ->
                inTheNameField Locale.nb
                    (Query.hasNot [ Selector.attribute (Attr.placeholder "For eksempel «Høy risiko i Oslo»") ])
        ]
