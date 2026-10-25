module RuleVocabularyTest exposing (suite)

{-| The vocabulary of `Klar.Rule` after its completion: one equality for every
kind, `NotBetween`, the relative date operators and the calendar periods, whole
day counts, the opaque field kinds, `matches` prepared once (checked on 100 000
rows), `settled` for servers, and the checks and sentences that go with them.
-}

import Expect
import Json.Encode as Encode
import Klar.Date as Date exposing (Date)
import Klar.Format as Format
import Klar.Locale as Locale
import Klar.Rule as Rule exposing (Combinator(..), Operator(..), Rule(..))
import Test exposing (Test, describe, test)


type alias Order =
    { number : Int
    , status : String
    , total : Maybe Float
    , created : Maybe Date
    , customer : String
    }


date : String -> Date
date iso =
    Date.fromIso iso |> Maybe.withDefault (Date.fromEpochDay 0)


{-| A Wednesday: the week around it runs from Monday 19 to Sunday 25 October.
-}
today : Date
today =
    date "2026-10-21"


statuses : List Rule.Choice
statuses =
    [ { value = "open", label = "Open" }, { value = "paid", label = "Paid" } ]


fields : List (Rule.Field Order)
fields =
    [ Rule.choiceField "status" "Status" statuses .status
    , Rule.numberField "total" "Total" .total
    , Rule.dateField "created" "Created" .created
    , Rule.textField "customer" "Customer" .customer
    ]


order : Int -> Order
order n =
    { number = n, status = "open", total = Just (toFloat n), created = Just today, customer = "" }


createdOn : String -> Order
createdOn iso =
    { number = 0, status = "open", total = Nothing, created = Date.fromIso iso, customer = "" }


cond : Int -> String -> Operator -> List String -> Rule
cond id field operator values =
    ConditionRule { id = id, field = field, operator = operator, values = values }


group : Int -> Combinator -> List Rule -> Rule
group id combinator children =
    GroupRule { id = id, combinator = combinator, negated = False, children = children }


{-| Does the one condition let this row through?
-}
passes : Date -> String -> Operator -> List String -> Order -> Bool
passes day field operator values row =
    Rule.matches day fields (group 0 All [ cond 1 field operator values ]) row


messages : Rule -> List String
messages rule =
    Rule.validate Locale.en fields rule |> List.map .message


suite : Test
suite =
    describe "the completed rule vocabulary"
        [ equality
        , notBetween
        , relativeDays
        , periods
        , kinds
        , compiled
        , settledRules
        , validation
        , sentences
        ]


equality : Test
equality =
    describe "Is and IsNot are the equality of numbers too"
        [ test "Is on a number compares the value as read" <|
            \_ -> Expect.equal [ True, True, False ] [ passes today "total" Is [ "1 000" ] (order 1000), passes today "total" Is [ "1000,0" ] (order 1000), passes today "total" Is [ "1000" ] (order 999) ]
        , test "IsNot lets a row without a number through" <|
            \_ -> Expect.equal True (passes today "total" IsNot [ "5" ] { number = 0, status = "", total = Nothing, created = Nothing, customer = "" })
        , test "a new condition on a number field starts with Is" <|
            \_ -> Expect.equal (Just Is) (Rule.fieldOperators (Rule.numberField "n" "N" (always Nothing)) |> List.head)
        ]


notBetween : Test
notBetween =
    describe "NotBetween"
        [ test "numbers outside both ends pass, the ends themselves do not, in either order" <|
            \_ ->
                Expect.equal [ True, False, False, False, True ]
                    (List.map (\n -> passes today "total" NotBetween [ "100", "10" ] (order n)) [ 5, 10, 50, 100, 150 ])
        , test "a row without a number passes, like the other negative operators" <|
            \_ -> Expect.equal True (passes today "total" NotBetween [ "10", "100" ] { number = 0, status = "", total = Nothing, created = Nothing, customer = "" })
        , test "dates outside the range pass" <|
            \_ ->
                Expect.equal [ True, False, False, True ]
                    (List.map (\iso -> passes today "created" NotBetween [ "2026-10-01", "2026-10-10" ] (createdOn iso)) [ "2026-09-30", "2026-10-01", "2026-10-10", "2026-10-11" ])
        , test "ends the wrong way round are reported, as for Between" <|
            \_ -> Expect.equal [ "The first value must not be larger than the second" ] (messages (group 0 All [ cond 1 "total" NotBetween [ "100", "10" ] ]))
        ]


relativeDays : Test
relativeDays =
    describe "relative days"
        [ test "more than 30 days ago starts the day before the last 30 days" <|
            \_ ->
                Expect.equal [ True, False, False, False ]
                    (List.map (\days -> passes today "created" MoreThanDaysAgo [ "30" ] (createdOn (Date.toIso (Date.addDays days today)))) [ -31, -30, 0, 5 ])
        , test "in more than 7 days starts the day after the next 7 days" <|
            \_ ->
                Expect.equal [ True, False, False ]
                    (List.map (\days -> passes today "created" MoreThanDaysAhead [ "7" ] (createdOn (Date.toIso (Date.addDays days today)))) [ 8, 7, -3 ])
        , test "a row without a date does not pass" <|
            \_ -> Expect.equal False (passes today "created" MoreThanDaysAgo [ "30" ] (createdOn ""))
        , test "a fraction of a day is not a day count: it does not filter, and validate says why" <|
            \_ ->
                Expect.equal ( True, [ "Enter a whole number of days" ] )
                    ( passes today "created" InLastDays [ "1.5" ] (createdOn "2000-01-01")
                    , messages (group 0 All [ cond 1 "created" InLastDays [ "1.5" ] ])
                    )
        , test "a day count with a separator between the thousands is read" <|
            \_ -> Expect.equal True (passes today "created" InLastDays [ "1 000" ] (createdOn "2024-06-01"))
        ]


periods : Test
periods =
    let
        within day key iso =
            passes day "created" InPeriod [ key ] (createdOn iso)
    in
    describe "InPeriod"
        [ test "this week runs from Monday to Sunday" <|
            \_ -> Expect.equal [ False, True, True, False ] (List.map (within today "thisWeek") [ "2026-10-18", "2026-10-19", "2026-10-25", "2026-10-26" ])
        , test "last week and next week" <|
            \_ -> Expect.equal [ True, True, False ] [ within today "lastWeek" "2026-10-12", within today "nextWeek" "2026-11-01", within today "lastWeek" "2026-10-19" ]
        , test "today, yesterday and tomorrow" <|
            \_ -> Expect.equal [ True, True, True, False ] [ within today "today" "2026-10-21", within today "yesterday" "2026-10-20", within today "tomorrow" "2026-10-22", within today "today" "2026-10-22" ]
        , test "last month of January is December of the year before" <|
            \_ -> Expect.equal [ False, True, True, False ] (List.map (within (date "2026-01-15") "lastMonth") [ "2025-11-30", "2025-12-01", "2025-12-31", "2026-01-01" ])
        , test "this month ends on its last day" <|
            \_ -> Expect.equal [ True, False ] [ within (date "2024-02-10") "thisMonth" "2024-02-29", within (date "2024-02-10") "thisMonth" "2024-03-01" ]
        , test "quarters are January to March, April to June ..." <|
            \_ -> Expect.equal [ True, True, False, True ] [ within today "thisQuarter" "2026-12-31", within today "lastQuarter" "2026-07-01", within today "lastQuarter" "2026-10-01", within (date "2026-02-01") "lastQuarter" "2025-10-01" ]
        , test "years" <|
            \_ -> Expect.equal [ True, True, True, False ] [ within today "thisYear" "2026-01-01", within today "lastYear" "2025-12-31", within today "nextYear" "2027-06-30", within today "thisYear" "2027-01-01" ]
        , test "an unknown period is not complete: it does not filter, and validate asks for a period" <|
            \_ ->
                Expect.equal ( True, [ "Choose a period" ] )
                    ( within today "someday" "1999-01-01", messages (group 0 All [ cond 1 "created" InPeriod [ "someday" ] ]) )
        , test "the same rule follows today" <|
            \_ -> Expect.equal [ True, False ] [ within today "thisMonth" "2026-10-02", within (date "2026-11-02") "thisMonth" "2026-10-02" ]
        ]


kinds : Test
kinds =
    describe "the opaque field kinds"
        [ test "the field functions set the kinds" <|
            \_ ->
                Expect.equal
                    [ Rule.textKind, Rule.numberKind, Rule.dateKind, Rule.booleanKind, Rule.choiceKind statuses ]
                    [ Rule.fieldKind (Rule.textField "a" "A" identity)
                    , Rule.fieldKind (Rule.numberField "a" "A" (always Nothing))
                    , Rule.fieldKind (Rule.dateField "a" "A" (always Nothing))
                    , Rule.fieldKind (Rule.boolField "a" "A" (always True))
                    , Rule.fieldKind (Rule.choiceField "a" "A" statuses identity)
                    ]
        , test "a bare field takes a kind made with a kind function" <|
            \_ -> Expect.equal (Rule.operatorsFor (Rule.choiceKind statuses)) (Rule.fieldOperators (Rule.bareField "s" "S" (Rule.choiceKind statuses)))
        , test "the relative operators are offered for dates, in the picker's order" <|
            \_ ->
                Expect.equal [ InPeriod, InLastDays, InNextDays, MoreThanDaysAgo, MoreThanDaysAhead ]
                    (Rule.operatorsFor Rule.dateKind |> List.filter (\operator -> List.member operator [ InPeriod, InLastDays, InNextDays, MoreThanDaysAgo, MoreThanDaysAhead ]))
        ]


{-| 100 000 orders with every kind of value, some of them missing.
-}
manyOrders : List Order
manyOrders =
    List.range 1 100000
        |> List.map
            (\n ->
                { number = n
                , status =
                    if modBy 3 n == 0 then
                        "paid"

                    else
                        "open"
                , total =
                    if modBy 10 n == 0 then
                        Nothing

                    else
                        Just (toFloat (modBy 1000 n))
                , created = Just (Date.addDays (negate (modBy 400 n)) today)
                , customer =
                    if modBy 2 n == 0 then
                        "Ålesund AS"

                    else
                        "Bergen"
                }
            )


bigRule : Rule
bigRule =
    Rule.allOf
        [ Rule.isAnyOf "status" [ "paid" ]
        , Rule.when "total" GreaterThan [ "100" ]
        , Rule.when "total" LessOrEqual [ "900" ]
        , Rule.when "created" InLastDays [ "300" ]
        , Rule.when "customer" Contains [ " alesund " ]
        , Rule.anyOf [ Rule.when "total" Is [ "500" ], Rule.when "created" MoreThanDaysAgo [ "100" ] ]
        , Rule.when "customer" IsNot [ "Oslo" ]
        , Rule.when "total" NotBetween [ "400", "300" ]
        , Rule.when "total" Between [ "nothing", "yet" ]
        , Rule.when "unknown" Is [ "x" ]
        ]


{-| The same rule written out by hand.
-}
bigRuleByHand : Order -> Bool
bigRuleByHand o =
    let
        total =
            Maybe.withDefault -1 o.total

        age =
            o.created |> Maybe.map (\created -> Date.diffDays created today) |> Maybe.withDefault -1
    in
    (o.status == "paid")
        && (o.total /= Nothing && total > 100 && total <= 900)
        && (age >= 0 && age <= 300)
        && (o.customer == "Ålesund AS")
        && (total == 500 || age > 100)
        && (o.total == Nothing || total < 300 || total > 400)


compiled : Test
compiled =
    describe "matches prepares the rule once"
        [ test "100 000 rows and ten conditions give the same rows as the rule written by hand" <|
            \_ ->
                Expect.equal
                    (List.filter bigRuleByHand manyOrders |> List.map .number)
                    (List.filter (Rule.matches today fields bigRule) manyOrders |> List.map .number)
        , test "a matcher made once can be used for many rows" <|
            \_ ->
                let
                    matcher =
                        Rule.matches today fields (Rule.allOf [ Rule.when "total" GreaterOrEqual [ "3" ] ])
                in
                Expect.equal [ False, True, True ] (List.map (order >> matcher) [ 2, 3, 4 ])
        , test "a rule with nothing complete lets every row through" <|
            \_ -> Expect.equal True (Rule.matches today fields (Rule.allOf [ Rule.when "total" GreaterThan [] ]) (order 1))
        , test "a negated group with nothing complete lets every row through" <|
            \_ -> Expect.equal True (Rule.matches today fields (GroupRule { id = 0, combinator = All, negated = True, children = [ cond 1 "total" GreaterThan [] ] }) (order 1))
        ]


settledRules : Test
settledRules =
    let
        encoded rule =
            Encode.encode 0 (Rule.encode rule)

        sample =
            Rule.allOf
                [ Rule.is "status" "paid"
                , Rule.when "total" GreaterThan [ "1 234,5" ]
                , Rule.when "total" Between [ "100", "10", "ignored" ]
                , Rule.when "customer" Contains [ "  ålesund " ]
                , Rule.when "nope" Is [ "x" ]
                , Rule.when "total" GreaterThan [ "many" ]
                , Rule.isAnyOf "status" [ "paid", "open", "paid", "" ]
                , Rule.when "created" InLastDays [ "30,0" ]
                , Rule.anyOf [ Rule.when "total" LessThan [] ]
                ]

        rows =
            List.map order (List.range 0 2000)
                ++ List.take 3000 manyOrders
    in
    describe "settled"
        [ test "keeps what matches uses, with the operands in one form" <|
            \_ ->
                Expect.equal
                    (encoded
                        (Rule.allOf
                            [ Rule.is "status" "paid"
                            , Rule.when "total" GreaterThan [ "1234.5" ]
                            , Rule.when "total" Between [ "10", "100" ]
                            , Rule.when "customer" Contains [ "ålesund" ]
                            , Rule.isAnyOf "status" [ "open", "paid" ]
                            , Rule.when "created" InLastDays [ "30" ]
                            ]
                        )
                    )
                    (encoded (Rule.settled fields sample))
        , test "the root is numbered from 0 down" <|
            \_ ->
                Expect.equal [ 0, 1, 2 ]
                    (case Rule.settled fields (Rule.allOf [ Rule.is "status" "paid", Rule.is "status" "open" ]) of
                        GroupRule g ->
                            0 :: List.map Rule.idOf g.children

                        ConditionRule c ->
                            [ c.id ]
                    )
        , test "a rule with nothing that filters settles to the empty group" <|
            \_ -> Expect.equal Rule.emptyGroup (Rule.settled fields (GroupRule { id = 0, combinator = Any, negated = True, children = [ cond 1 "total" GreaterThan [] ] }))
        , test "a negated root stays negated, inside a plain group" <|
            \_ ->
                Expect.equal
                    (List.filter (Rule.matches today fields (GroupRule { id = 0, combinator = Any, negated = True, children = [ cond 1 "total" LessThan [ "5" ], cond 2 "total" GreaterThan [ "1990" ] ] })) rows)
                    (List.filter (Rule.matches today fields (Rule.settled fields (GroupRule { id = 0, combinator = Any, negated = True, children = [ cond 1 "total" LessThan [ "5" ], cond 2 "total" GreaterThan [ "1990" ] ] }))) rows)
        , test "matches gives the same rows for the settled rule" <|
            \_ ->
                Expect.equal
                    (List.filter (Rule.matches today fields sample) rows |> List.length)
                    (List.filter (Rule.matches today fields (Rule.settled fields sample)) rows |> List.length)
        , test "and for the big rule" <|
            \_ ->
                Expect.equal
                    (List.filter (Rule.matches today fields bigRule) rows |> List.map .number)
                    (List.filter (Rule.matches today fields (Rule.settled fields bigRule)) rows |> List.map .number)
        ]


validation : Test
validation =
    describe "validate"
        [ test "an empty root is fine whatever its id" <|
            \_ -> Expect.equal [] (messages (group 5 All []))
        , test "an empty inner group is reported even with the id 0" <|
            \_ -> Expect.equal [ { nodeId = 0, message = "The group is empty" } ] (Rule.validate Locale.en fields (group 3 All [ group 0 Any [] ]))
        , test "a choice that is no longer among the choices is reported" <|
            \_ ->
                Expect.equal [ "The value is no longer available, choose another", "The value is no longer available, choose another" ]
                    (messages (group 0 All [ cond 1 "status" Is [ "gone" ], cond 2 "status" IsAnyOf [ "open", "gone" ] ]))
        , test "in Norwegian" <|
            \_ -> Expect.equal [ "Verdien finnes ikke lenger, velg en annen" ] (Rule.validate Locale.nb fields (group 0 All [ cond 1 "status" Is [ "gone" ] ]) |> List.map .message)
        , test "known choices are fine" <|
            \_ -> Expect.equal [] (messages (group 0 All [ cond 1 "status" IsNoneOf [ "open", "paid", "" ] ]))
        ]


sentences : Test
sentences =
    let
        words locale rule =
            Rule.describe locale fields rule
    in
    describe "describe"
        [ test "a period" <|
            \_ ->
                Expect.equal [ "Created is within this month", "Created er innenfor denne måneden" ]
                    [ words Locale.en (Rule.allOf [ Rule.when "created" InPeriod [ "thisMonth" ] ]), words Locale.nb (Rule.allOf [ Rule.when "created" InPeriod [ "thisMonth" ] ]) ]
        , test "more than N days ago" <|
            \_ ->
                Expect.equal [ "Created more than 30 days ago", "Created for mer enn 30 dager siden" ]
                    [ words Locale.en (Rule.allOf [ Rule.when "created" MoreThanDaysAgo [ "30" ] ]), words Locale.nb (Rule.allOf [ Rule.when "created" MoreThanDaysAgo [ "30" ] ]) ]
        , test "in more than N days" <|
            \_ -> Expect.equal "Created in more than 1 day" (words Locale.en (Rule.allOf [ Rule.when "created" MoreThanDaysAhead [ "1" ] ]))
        , test "a number reads as it was understood, in the format of the locale" <|
            \_ ->
                Expect.equal [ "Total > 1,234.5", "Total > " ++ Format.decimal Locale.nb 1 1234.5, "Total = 1.234" ]
                    [ words Locale.en (Rule.allOf [ Rule.when "total" GreaterThan [ "1 234,5" ] ])
                    , words Locale.nb (Rule.allOf [ Rule.when "total" GreaterThan [ "1 234,5" ] ])
                    , words Locale.en (Rule.allOf [ Rule.when "total" Is [ "1,234" ] ])
                    ]
        , test "not between" <|
            \_ -> Expect.equal "Total not between 10 – 100" (words Locale.en (Rule.allOf [ Rule.when "total" NotBetween [ "10", "100" ] ]))
        ]
