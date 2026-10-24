module RuleTest exposing (suite)

import Expect
import Fuzz exposing (Fuzzer)
import Json.Decode as Decode
import Json.Encode as Encode
import Klar.Date as Date exposing (Date)
import Klar.Locale as Locale exposing (Locale)
import Klar.Rule as Rule exposing (Combinator(..), Operands(..), Operator(..), Rule(..))
import Set
import Test exposing (Test, describe, fuzz, fuzz2, test)


suite : Test
suite =
    describe "Klar.Rule"
        [ fieldTests
        , operatorLimitTests
        , operatorTests
        , numberParsingTests
        , orderTests
        , textOperatorTests
        , numberOperatorTests
        , dateOperatorTests
        , choiceOperatorTests
        , boolOperatorTests
        , incompleteConditionTests
        , groupTests
        , completenessTests
        , editingTests
        , moveTests
        , valueEditingTests
        , lookingTests
        , describeTests
        , validateTests
        , jsonTests
        , propertyTests
        ]



-- DATA


date : Int -> Int -> Int -> Date
date year month day =
    Date.fromParts year month day |> Maybe.withDefault (Date.fromEpochDay 0)


today : Date
today =
    date 2026 10 20


type alias Order =
    { number : String
    , customer : String
    , status : String
    , total : Maybe Float
    , created : Maybe Date
    , express : Bool
    }


orders : List Order
orders =
    [ { number = "ORD-1001", customer = "Acme Supplies", status = "paid", total = Just 120.5, created = Just (date 2026 10 1), express = True }
    , { number = "ORD-1002", customer = "Globex", status = "open", total = Just 52, created = Just (date 2025 3 15), express = False }
    , { number = "ORD-1003", customer = "Østby Trading", status = "", total = Nothing, created = Nothing, express = True }
    , { number = "ORD-1004", customer = "Initech", status = "paid", total = Just 20, created = Just (date 2026 9 25), express = True }
    ]


statuses : List Rule.Choice
statuses =
    [ { value = "open", label = "Open" }
    , { value = "paid", label = "Paid" }
    ]


fields : List (Rule.Field Order)
fields =
    [ Rule.textField "customer" "Customer" .customer
    , Rule.numberField "total" "Total" .total
    , Rule.dateField "created" "Created" .created
    , Rule.choiceField "status" "Status" statuses .status
    , Rule.boolField "express" "Express" .express
    ]


cond : Int -> String -> Operator -> List String -> Rule
cond id field operator values =
    ConditionRule { id = id, field = field, operator = operator, values = values }


group : Int -> Combinator -> List Rule -> Rule
group id combinator children =
    GroupRule { id = id, combinator = combinator, negated = False, children = children }


notGroup : Int -> Combinator -> List Rule -> Rule
notGroup id combinator children =
    GroupRule { id = id, combinator = combinator, negated = True, children = children }


{-| The order numbers that satisfy a rule, in the order of `orders`.
-}
run : Rule -> List String
run rule =
    orders |> List.filter (Rule.matches today fields rule) |> List.map .number


{-| Every row of `orders`, to say "the rule ignores this condition".
-}
everyOrder : List String
everyOrder =
    List.map .number orders


{-| Rules that talk about one kind of value at a time are easier to check
against a single value than against a table of rows.
-}
textMatch : Operator -> List String -> String -> Bool
textMatch operator values value =
    Rule.matches today [ Rule.textField "f" "F" identity ] (cond 1 "f" operator values) value


numberMatch : Operator -> List String -> Maybe Float -> Bool
numberMatch operator values value =
    Rule.matches today [ Rule.numberField "f" "F" identity ] (cond 1 "f" operator values) value


dateMatch : Operator -> List String -> Maybe Date -> Bool
dateMatch operator values value =
    Rule.matches today [ Rule.dateField "f" "F" identity ] (cond 1 "f" operator values) value


choiceMatch : Operator -> List String -> String -> Bool
choiceMatch operator values value =
    Rule.matches today [ Rule.choiceField "f" "F" statuses identity ] (cond 1 "f" operator values) value


boolMatch : Operator -> Bool -> Bool
boolMatch operator value =
    Rule.matches today [ Rule.boolField "f" "F" identity ] (cond 1 "f" operator []) value


truth : String -> Bool -> Bool -> Test
truth name expected actual =
    test name <| \_ -> Expect.equal expected actual


check : String -> a -> a -> Test
check name expected actual =
    test name <| \_ -> Expect.equal expected actual


allOperators : List Operator
allOperators =
    [ Is, IsNot, Contains, NotContains, StartsWith, EndsWith, LessThan, LessOrEqual, GreaterThan, GreaterOrEqual, Between, NotBetween, Before, After, OnOrBefore, OnOrAfter, InLastDays, InNextDays, MoreThanDaysAgo, MoreThanDaysAhead, InPeriod, IsAnyOf, IsNoneOf, IsEmpty, IsNotEmpty, IsTrue, IsFalse ]


{-| Every node of a rule, root first, so the ids can be read off.
-}
ids : Rule -> List Int
ids rule =
    case rule of
        ConditionRule condition ->
            [ condition.id ]

        GroupRule g ->
            g.id :: List.concatMap ids g.children


groupIds : Rule -> List Int
groupIds rule =
    case rule of
        ConditionRule _ ->
            []

        GroupRule g ->
            g.id :: List.concatMap groupIds g.children


allUnique : List Int -> Bool
allUnique items =
    Set.size (Set.fromList items) == List.length items


{-| The same tree with every id set to 0, to compare rules whose ids differ.
-}
stripIds : Rule -> Rule
stripIds rule =
    case rule of
        ConditionRule condition ->
            ConditionRule { condition | id = 0 }

        GroupRule g ->
            GroupRule { g | id = 0, children = List.map stripIds g.children }


findNode : Int -> Rule -> Maybe Rule
findNode id rule =
    if Rule.idOf rule == id then
        Just rule

    else
        case rule of
            ConditionRule _ ->
                Nothing

            GroupRule g ->
                g.children |> List.filterMap (findNode id) |> List.head


nodeCount : Rule -> Int
nodeCount rule =
    List.length (ids rule)


valuesOf : Int -> Rule -> List String
valuesOf id rule =
    case findNode id rule of
        Just (ConditionRule c) ->
            c.values

        _ ->
            [ "<not a condition>" ]


operatorOf : Int -> Rule -> Maybe Operator
operatorOf id rule =
    case findNode id rule of
        Just (ConditionRule c) ->
            Just c.operator

        _ ->
            Nothing


fieldOf : Int -> Rule -> Maybe String
fieldOf id rule =
    case findNode id rule of
        Just (ConditionRule c) ->
            Just c.field

        _ ->
            Nothing


childrenOf : Int -> Rule -> List Int
childrenOf id rule =
    case findNode id rule of
        Just (GroupRule g) ->
            List.map Rule.idOf g.children

        _ ->
            []


combinatorOf : Int -> Rule -> Maybe Combinator
combinatorOf id rule =
    case findNode id rule of
        Just (GroupRule g) ->
            Just g.combinator

        _ ->
            Nothing


isNegated : Int -> Rule -> Maybe Bool
isNegated id rule =
    case findNode id rule of
        Just (GroupRule g) ->
            Just g.negated

        _ ->
            Nothing


{-| A rule used by most editing tests:

    0 all
        ├ 1 status is paid
        └ 2 any
        ├ 3 total
        > 50
        └ 4 customer contains "ida"

-}
sampleRule : Rule
sampleRule =
    group 0
        All
        [ cond 1 "status" Is [ "paid" ]
        , group 2
            Any
            [ cond 3 "total" GreaterThan [ "50" ]
            , cond 4 "customer" Contains [ "ida" ]
            ]
        ]



-- FIELDS


fieldTests : Test
fieldTests =
    describe "fields"
        [ check "textField has the text kind" Rule.textKind (Rule.fieldKind (Rule.textField "a" "A" identity))
        , check "numberField has the number kind" Rule.numberKind (Rule.fieldKind (Rule.numberField "a" "A" (always Nothing)))
        , check "dateField has the date kind" Rule.dateKind (Rule.fieldKind (Rule.dateField "a" "A" (always Nothing)))
        , check "boolField has the boolean kind" Rule.booleanKind (Rule.fieldKind (Rule.boolField "a" "A" (always True)))
        , check "choiceField carries its choices" (Rule.choiceKind statuses) (Rule.fieldKind (Rule.choiceField "a" "A" statuses identity))
        , check "a field starts without a group" Nothing (Rule.fieldGroup (Rule.textField "a" "A" identity))
        , check "inGroup sets the heading" (Just "Delivery") (Rule.fieldGroup (Rule.textField "a" "A" identity |> Rule.inGroup "Delivery"))
        , check "inGroup keeps the id and the label"
            ( "a", "A" )
            (let
                f =
                    Rule.textField "a" "A" identity |> Rule.inGroup "Delivery"
             in
             ( Rule.fieldId f, Rule.fieldLabel f )
            )
        , check "fieldById finds a field" (Just "Total") (Rule.fieldById fields "total" |> Maybe.map Rule.fieldLabel)
        , check "fieldById is Nothing for an unknown id" Nothing (Rule.fieldById fields "nope" |> Maybe.map Rule.fieldLabel)
        , check "fieldById is case sensitive" Nothing (Rule.fieldById fields "Total" |> Maybe.map Rule.fieldLabel)
        , check "fieldById of nothing is Nothing" Nothing (Rule.fieldById [] "total" |> Maybe.map Rule.fieldLabel)
        , check "fieldById returns the first field when ids repeat"
            (Just "First")
            (Rule.fieldById [ Rule.textField "x" "First" identity, Rule.textField "x" "Second" identity ] "x" |> Maybe.map Rule.fieldLabel)
        ]



-- OPERATORS A FIELD OFFERS


operatorLimitTests : Test
operatorLimitTests =
    let
        owner =
            Rule.choiceField "owner" "Owner" statuses .status
                |> Rule.withOperators [ IsAnyOf, Contains, Is, IsAnyOf ]

        limited =
            [ owner ]
    in
    describe "withOperators"
        [ check "a field offers every operator of its kind by default"
            (Rule.operatorsFor Rule.textKind)
            (Rule.fieldOperators (Rule.textField "a" "A" identity))
        , check "withOperators limits the operators, in the order given, without repeats and without the ones that do not fit the kind"
            [ IsAnyOf, Is ]
            (Rule.fieldOperators owner)
        , check "when none of the operators fit the kind, the field keeps all of them"
            (Rule.operatorsFor (Rule.choiceKind statuses))
            (Rule.fieldOperators (Rule.choiceField "s" "S" statuses .status |> Rule.withOperators [ Contains, GreaterThan ]))
        , check "withOperators with an empty list keeps all of them"
            (Rule.operatorsFor Rule.textKind)
            (Rule.fieldOperators (Rule.textField "a" "A" identity |> Rule.withOperators []))
        , check "withOperators does not change the kind, the label or the group"
            ( Rule.choiceKind statuses, "Owner", Just "People" )
            (let
                f =
                    Rule.choiceField "owner" "Owner" statuses .status |> Rule.inGroup "People" |> Rule.withOperators [ Is ]
             in
             ( Rule.fieldKind f, Rule.fieldLabel f, Rule.fieldGroup f )
            )
        , check "a new condition starts with the first operator the field offers"
            (Just IsAnyOf)
            (case Rule.addCondition limited 0 Rule.emptyGroup of
                GroupRule g ->
                    case g.children of
                        [ ConditionRule c ] ->
                            Just c.operator

                        _ ->
                            Nothing

                ConditionRule _ ->
                    Nothing
            )
        , check "changing to a field that offers fewer operators replaces the operator that does not fit"
            (Just IsAnyOf)
            (case Rule.setField (fields ++ limited) 1 "owner" (group 0 All [ cond 1 "customer" Contains [ "x" ] ]) of
                GroupRule g ->
                    case g.children of
                        [ ConditionRule c ] ->
                            Just c.operator

                        _ ->
                            Nothing

                ConditionRule _ ->
                    Nothing
            )
        , check "validate reports an operator the field does not offer, even when it fits the kind"
            [ "The operator does not fit the field" ]
            (Rule.validate Locale.en limited (group 0 All [ cond 1 "owner" IsNot [ "open" ] ]) |> List.map .message)
        , check "validate accepts an operator the field offers"
            []
            (Rule.validate Locale.en limited (group 0 All [ cond 1 "owner" Is [ "open" ] ]) |> List.map .message)
        , check "a bare field has an id, a label and a kind and reads nothing from a row"
            { id = "k", label = "K", kind = Rule.numberKind, matched = False }
            (let
                f =
                    Rule.bareField "k" "K" Rule.numberKind
             in
             { id = Rule.fieldId f, label = Rule.fieldLabel f, kind = Rule.fieldKind f, matched = Rule.matches today [ f ] (cond 1 "k" Is [ "1" ]) () }
            )
        ]



-- OPERATORS


operatorTests : Test
operatorTests =
    describe "operators"
        [ check "text operators" [ Contains, NotContains, Is, IsNot, StartsWith, EndsWith, IsEmpty, IsNotEmpty ] (Rule.operatorsFor Rule.textKind)
        , check "number operators" [ Is, IsNot, GreaterThan, GreaterOrEqual, LessThan, LessOrEqual, Between, NotBetween, IsEmpty, IsNotEmpty ] (Rule.operatorsFor Rule.numberKind)
        , check "date operators" [ Is, IsNot, Before, After, OnOrBefore, OnOrAfter, Between, NotBetween, InPeriod, InLastDays, InNextDays, MoreThanDaysAgo, MoreThanDaysAhead, IsEmpty, IsNotEmpty ] (Rule.operatorsFor Rule.dateKind)
        , check "yes or no operators" [ IsTrue, IsFalse ] (Rule.operatorsFor Rule.booleanKind)
        , check "choice operators" [ Is, IsNot, IsAnyOf, IsNoneOf, IsEmpty, IsNotEmpty ] (Rule.operatorsFor (Rule.choiceKind statuses))
        , check "the choices do not change the operators" (Rule.operatorsFor (Rule.choiceKind [])) (Rule.operatorsFor (Rule.choiceKind statuses))
        , test "every operator belongs to at least one kind of field" <|
            \_ ->
                let
                    offered =
                        List.concatMap Rule.operatorsFor [ Rule.textKind, Rule.numberKind, Rule.dateKind, Rule.booleanKind, Rule.choiceKind [] ]
                in
                allOperators
                    |> List.filter (\operator -> not (List.member operator offered))
                    |> Expect.equal []
        , test "the labels of the operators of one kind are all different" <|
            \_ ->
                [ Rule.textKind, Rule.numberKind, Rule.dateKind, Rule.booleanKind, Rule.choiceKind [] ]
                    |> List.filter (\kind -> not (allUniqueStrings (List.map (Rule.operatorLabel Locale.en kind) (Rule.operatorsFor kind))))
                    |> Expect.equal []
        , check "operands: none" [ NoOperand, NoOperand, NoOperand, NoOperand ] (List.map Rule.operandsOf [ IsEmpty, IsNotEmpty, IsTrue, IsFalse ])
        , check "operands: two" [ TwoOperands, TwoOperands ] (List.map Rule.operandsOf [ Between, NotBetween ])
        , check "operands: many" [ ManyOperands, ManyOperands ] (List.map Rule.operandsOf [ IsAnyOf, IsNoneOf ])
        , check "operands: one for the others"
            []
            (allOperators
                |> List.filter (\operator -> not (List.member operator [ IsEmpty, IsNotEmpty, IsTrue, IsFalse, Between, NotBetween, IsAnyOf, IsNoneOf ]))
                |> List.filter (\operator -> Rule.operandsOf operator /= OneOperand)
            )
        , check "English labels" [ "contains", "does not contain", "is", "is not", "starts with", "ends with", "is empty", "is not empty" ] (List.map (Rule.operatorLabel Locale.en Rule.textKind) (Rule.operatorsFor Rule.textKind))
        , check "Norwegian labels" [ "inneholder", "inneholder ikke", "er", "er ikke", "starter med", "slutter med", "er tom", "er ikke tom" ] (List.map (Rule.operatorLabel Locale.nb Rule.textKind) (Rule.operatorsFor Rule.textKind))
        , check "number comparisons are symbols in every language"
            [ "=", "≠", ">", "≥", "<", "≤" ]
            (List.map (Rule.operatorLabel Locale.nb Rule.numberKind) [ Is, IsNot, GreaterThan, GreaterOrEqual, LessThan, LessOrEqual ])
        , check "the symbols are the same in English" (List.map (Rule.operatorLabel Locale.nb Rule.numberKind) [ Is, IsNot, GreaterThan, GreaterOrEqual, LessThan, LessOrEqual ]) (List.map (Rule.operatorLabel Locale.en Rule.numberKind) [ Is, IsNot, GreaterThan, GreaterOrEqual, LessThan, LessOrEqual ])
        , check "date labels" [ "before", "after", "on or before", "on or after", "in the last (days)", "in the next (days)", "more than (days) ago", "in more than (days)", "is within", "not between" ] (List.map (Rule.operatorLabel Locale.en Rule.dateKind) [ Before, After, OnOrBefore, OnOrAfter, InLastDays, InNextDays, MoreThanDaysAgo, MoreThanDaysAhead, InPeriod, NotBetween ])
        , check "Norwegian date labels" [ "for mer enn (dager) siden", "om mer enn (dager)", "er innenfor", "ikke mellom" ] (List.map (Rule.operatorLabel Locale.nb Rule.dateKind) [ MoreThanDaysAgo, MoreThanDaysAhead, InPeriod, NotBetween ])
        , check "equality reads is on text and = on numbers" [ "is", "=", "is not", "≠" ] [ Rule.operatorLabel Locale.en Rule.textKind Is, Rule.operatorLabel Locale.en Rule.numberKind Is, Rule.operatorLabel Locale.en Rule.dateKind IsNot, Rule.operatorLabel Locale.en Rule.numberKind IsNot ]
        , check "yes and no labels" [ "is yes", "is no", "er ja", "er nei" ] (List.map (Rule.operatorLabel Locale.en Rule.booleanKind) [ IsTrue, IsFalse ] ++ List.map (Rule.operatorLabel Locale.nb Rule.booleanKind) [ IsTrue, IsFalse ])
        , test "every operator has a label in both languages" <|
            \_ ->
                allOperators
                    |> List.filter (\operator -> Rule.operatorLabel Locale.en Rule.textKind operator == "" || Rule.operatorLabel Locale.nb Rule.textKind operator == "")
                    |> Expect.equal []
        , test "only equality is worded by the kind" <|
            \_ ->
                allOperators
                    |> List.filter (\operator -> operator /= Is && operator /= IsNot)
                    |> List.filter
                        (\operator ->
                            List.map (\kind -> Rule.operatorLabel Locale.en kind operator) [ Rule.textKind, Rule.numberKind, Rule.dateKind, Rule.booleanKind ]
                                |> allSame
                                |> not
                        )
                    |> Expect.equal []
        ]


allUniqueStrings : List String -> Bool
allUniqueStrings items =
    Set.size (Set.fromList items) == List.length items


allSame : List a -> Bool
allSame items =
    case items of
        [] ->
            True

        first :: rest ->
            List.all (\item -> item == first) rest



-- PARSING NUMBERS


numberParsingTests : Test
numberParsingTests =
    describe "parseNumber"
        [ check "a whole number" (Just 42) (Rule.parseNumber "42")
        , check "a decimal point" (Just 12.5) (Rule.parseNumber "12.5")
        , check "a decimal comma" (Just 12.5) (Rule.parseNumber "12,5")
        , check "spaces are thousand separators" (Just 1234.5) (Rule.parseNumber "1 234,5")
        , check "non-breaking spaces are thousand separators" (Just 1000) (Rule.parseNumber "1\u{00A0}000")
        , check "surrounding spaces are ignored" (Just 7) (Rule.parseNumber "  7  ")
        , check "a negative number" (Just -3) (Rule.parseNumber "-3")
        , check "zero" (Just 0) (Rule.parseNumber "0")
        , check "a leading decimal point" (Just 0.5) (Rule.parseNumber ".5")
        , check "an exponent" (Just 1000) (Rule.parseNumber "1e3")
        , check "text is no number" Nothing (Rule.parseNumber "ten")
        , check "empty text is no number" Nothing (Rule.parseNumber "")
        , check "blank text is no number" Nothing (Rule.parseNumber "   ")
        , check "a comma before the decimal point separates thousands" (Just 1234.5) (Rule.parseNumber "1,234.5")
        , check "a point before the decimal comma separates thousands" (Just 1234.5) (Rule.parseNumber "1.234,5")
        , check "two commas are no number" Nothing (Rule.parseNumber "1,234,5")
        , check "two signs are no number" Nothing (Rule.parseNumber "--5")
        , check "a lone minus is no number" Nothing (Rule.parseNumber "-")
        , check "hexadecimal is no number" Nothing (Rule.parseNumber "0x10")
        , check "a number with a unit is no number" Nothing (Rule.parseNumber "12kg")
        , -- Klar.Format writes negative numbers with a real minus sign (U+2212) and
          -- Klar.Table accepts it in its range filter, so a value pasted from a table
          -- has to be a number in a rule too.
          check "the minus sign that Klar.Format writes is a minus" (Just -5) (Rule.parseNumber "−5")
        ]



-- THE ORDERS


orderTests : Test
orderTests =
    describe "rules run against order rows"
        [ check "an empty group lets everything through" everyOrder (run Rule.emptyGroup)
        , check "an empty rule is empty" True (Rule.isEmpty Rule.emptyGroup)
        , check "text: contains ignores ø and o" [ "ORD-1003" ] (run (group 0 All [ cond 1 "customer" Contains [ "ostby" ] ]))
        , check "text: starts with" [ "ORD-1004" ] (run (group 0 All [ cond 1 "customer" StartsWith [ "init" ] ]))
        , check "text: does not contain" [ "ORD-1002", "ORD-1003", "ORD-1004" ] (run (group 0 All [ cond 1 "customer" NotContains [ "acme" ] ]))
        , check "number: greater than" [ "ORD-1001", "ORD-1002" ] (run (group 0 All [ cond 1 "total" GreaterThan [ "30" ] ]))
        , check "number: between includes both ends" [ "ORD-1002", "ORD-1004" ] (run (group 0 All [ cond 1 "total" Between [ "20", "52" ] ]))
        , check "number: a decimal comma works" [ "ORD-1004" ] (run (group 0 All [ cond 1 "total" LessThan [ "20,5" ] ]))
        , check "number: a missing total is empty" [ "ORD-1003" ] (run (group 0 All [ cond 1 "total" IsEmpty [] ]))
        , check "number: a missing total is not equal to 20" [ "ORD-1001", "ORD-1002", "ORD-1003" ] (run (group 0 All [ cond 1 "total" IsNot [ "20" ] ]))
        , check "date: after" [ "ORD-1001", "ORD-1004" ] (run (group 0 All [ cond 1 "created" After [ "2026-01-01" ] ]))
        , check "date: in the last 30 days" [ "ORD-1001", "ORD-1004" ] (run (group 0 All [ cond 1 "created" InLastDays [ "30" ] ]))
        , check "date: in the last 3 days" [] (run (group 0 All [ cond 1 "created" InLastDays [ "3" ] ]))
        , check "choice: is any of" [ "ORD-1001", "ORD-1002", "ORD-1004" ] (run (group 0 All [ cond 1 "status" IsAnyOf [ "paid", "open" ] ]))
        , check "choice: is none of counts the empty ones" [ "ORD-1002", "ORD-1003" ] (run (group 0 All [ cond 1 "status" IsNoneOf [ "paid" ] ]))
        , check "yes or no: is yes" [ "ORD-1001", "ORD-1003", "ORD-1004" ] (run (group 0 All [ cond 1 "express" IsTrue [] ]))
        , check "all: both must hold" [ "ORD-1001" ] (run (group 0 All [ cond 1 "status" Is [ "paid" ], cond 2 "total" GreaterThan [ "100" ] ]))
        , check "any: one must hold" [ "ORD-1001", "ORD-1002", "ORD-1004" ] (run (group 0 Any [ cond 1 "status" Is [ "paid" ], cond 2 "total" GreaterThan [ "50" ] ]))
        , check "nested groups"
            [ "ORD-1001", "ORD-1002" ]
            (run (group 0 All [ cond 1 "total" IsNotEmpty [], group 2 Any [ cond 3 "total" GreaterThan [ "50" ], cond 4 "customer" StartsWith [ "zzz" ] ] ]))
        , check "a negated group" [ "ORD-1002", "ORD-1003" ] (run (group 0 All [ notGroup 1 All [ cond 2 "status" Is [ "paid" ] ] ]))
        , check "a condition may be the whole rule" [ "ORD-1002" ] (run (cond 1 "status" Is [ "open" ]))
        ]



-- TEXT


textOperatorTests : Test
textOperatorTests =
    describe "text operators"
        [ truth "contains finds a part" True (textMatch Contains [ "ell" ] "Hello")
        , truth "contains ignores case" True (textMatch Contains [ "HELLO" ] "hello")
        , truth "contains ignores case of the value" True (textMatch Contains [ "hello" ] "HELLO")
        , truth "contains ignores diacritics in the operand" True (textMatch Contains [ "østby" ] "Ostby")
        , truth "contains ignores diacritics in the value" True (textMatch Contains [ "ostby" ] "ØSTBY")
        , truth "contains ignores spaces around the operand" True (textMatch Contains [ "  ell  " ] "Hello")
        , truth "contains does not ignore spaces inside" False (textMatch Contains [ "h ello" ] "Hello")
        , truth "contains does not find a missing part" False (textMatch Contains [ "xyz" ] "Hello")
        , truth "not contains" True (textMatch NotContains [ "xyz" ] "Hello")
        , truth "not contains is false when it is there" False (textMatch NotContains [ "ell" ] "Hello")
        , truth "starts with" True (textMatch StartsWith [ "he" ] "Hello")
        , truth "starts with is false for a part in the middle" False (textMatch StartsWith [ "ell" ] "Hello")
        , truth "the value is trimmed before it starts with" True (textMatch StartsWith [ "he" ] "  Hello")
        , truth "ends with" True (textMatch EndsWith [ "LLO" ] "Hello")
        , truth "ends with is false for the start" False (textMatch EndsWith [ "he" ] "Hello")
        , truth "the value is trimmed before it ends with" True (textMatch EndsWith [ "llo" ] "Hello  ")
        , truth "is compares the whole text" True (textMatch Is [ "hello" ] "Hello")
        , truth "is is false for a part" False (textMatch Is [ "hell" ] "Hello")
        , truth "is ignores surrounding spaces on both sides" True (textMatch Is [ " hello " ] "Hello ")
        , truth "is not" True (textMatch IsNot [ "bye" ] "Hello")
        , truth "is not is false for the same text" False (textMatch IsNot [ "HELLO" ] "hello")
        , truth "is empty for the empty text" True (textMatch IsEmpty [] "")
        , truth "is empty for blank text" True (textMatch IsEmpty [] "   ")
        , truth "is empty is false for text" False (textMatch IsEmpty [] "x")
        , truth "is not empty" True (textMatch IsNotEmpty [] "x")
        , truth "is not empty is false for blank text" False (textMatch IsNotEmpty [] " ")
        , truth "only the first operand is used" True (textMatch Contains [ "ell", "zzz" ] "Hello")
        , truth "the operators of other kinds do not match a text" True (textMatch GreaterThan [ "a" ] "b")
        ]



-- NUMBERS


numberOperatorTests : Test
numberOperatorTests =
    describe "number operators"
        [ truth "equals" True (numberMatch Is [ "52" ] (Just 52))
        , truth "equals with a decimal comma" True (numberMatch Is [ "52,5" ] (Just 52.5))
        , truth "equals with a decimal point" True (numberMatch Is [ "52.5" ] (Just 52.5))
        , truth "equals is false for another number" False (numberMatch Is [ "52" ] (Just 53))
        , truth "equals compares 0 and -0 as equal" True (numberMatch Is [ "0" ] (Just 0))
        , truth "not equals" True (numberMatch IsNot [ "52" ] (Just 53))
        , truth "not equals is false for the same number" False (numberMatch IsNot [ "52" ] (Just 52))
        , truth "not equals is true for a missing number" True (numberMatch IsNot [ "52" ] Nothing)
        , truth "less than" True (numberMatch LessThan [ "52" ] (Just 51.99))
        , truth "less than is false for the same number" False (numberMatch LessThan [ "52" ] (Just 52))
        , truth "less or equal is true for the same number" True (numberMatch LessOrEqual [ "52" ] (Just 52))
        , truth "less or equal is false above" False (numberMatch LessOrEqual [ "52" ] (Just 52.01))
        , truth "greater than" True (numberMatch GreaterThan [ "52" ] (Just 52.01))
        , truth "greater than is false for the same number" False (numberMatch GreaterThan [ "52" ] (Just 52))
        , truth "greater or equal is true for the same number" True (numberMatch GreaterOrEqual [ "52" ] (Just 52))
        , truth "greater or equal is false below" False (numberMatch GreaterOrEqual [ "52" ] (Just 51.99))
        , truth "comparing negative numbers" True (numberMatch LessThan [ "-1" ] (Just -2))
        , truth "a thousand separator in the operand" True (numberMatch Is [ "1 000" ] (Just 1000))
        , truth "very large numbers" True (numberMatch GreaterThan [ "1e12" ] (Just 1.0e13))
        , truth "between includes the lower end" True (numberMatch Between [ "20", "52" ] (Just 20))
        , truth "between includes the upper end" True (numberMatch Between [ "20", "52" ] (Just 52))
        , truth "between is false below" False (numberMatch Between [ "20", "52" ] (Just 19.99))
        , truth "between is false above" False (numberMatch Between [ "20", "52" ] (Just 52.01))
        , truth "between works with the ends the wrong way round" True (numberMatch Between [ "52", "20" ] (Just 30))
        , truth "between with the ends the wrong way round still excludes outside values" False (numberMatch Between [ "52", "20" ] (Just 60))
        , truth "between with equal ends is one number" True (numberMatch Between [ "5", "5" ] (Just 5))
        , truth "between is false for a missing number" False (numberMatch Between [ "1", "10" ] Nothing)
        , truth "is empty for a missing number" True (numberMatch IsEmpty [] Nothing)
        , truth "is empty is false for zero" False (numberMatch IsEmpty [] (Just 0))
        , truth "is not empty for zero" True (numberMatch IsNotEmpty [] (Just 0))
        , truth "is not empty is false for a missing number" False (numberMatch IsNotEmpty [] Nothing)
        , truth "a missing number is not less than anything" False (numberMatch LessThan [ "100" ] Nothing)
        , truth "a missing number is not greater than anything" False (numberMatch GreaterThan [ "-100" ] Nothing)
        , truth "a missing number is not equal to anything" False (numberMatch Is [ "0" ] Nothing)
        ]



-- DATES


dateMatchOn : Operator -> List String -> Date -> Bool
dateMatchOn operator values day =
    dateMatch operator values (Just day)


dateOperatorTests : Test
dateOperatorTests =
    describe "date operators"
        [ truth "is" True (dateMatchOn Is [ "2026-10-01" ] (date 2026 10 1))
        , truth "is is false for another day" False (dateMatchOn Is [ "2026-10-01" ] (date 2026 10 2))
        , truth "is not" True (dateMatchOn IsNot [ "2026-10-01" ] (date 2026 10 2))
        , truth "is not is true for a missing date" True (dateMatch IsNot [ "2026-10-01" ] Nothing)
        , truth "before" True (dateMatchOn Before [ "2026-10-01" ] (date 2026 9 30))
        , truth "before is false for the same day" False (dateMatchOn Before [ "2026-10-01" ] (date 2026 10 1))
        , truth "after" True (dateMatchOn After [ "2026-10-01" ] (date 2026 10 2))
        , truth "after is false for the same day" False (dateMatchOn After [ "2026-10-01" ] (date 2026 10 1))
        , truth "on or before includes the day" True (dateMatchOn OnOrBefore [ "2026-10-01" ] (date 2026 10 1))
        , truth "on or before is false the day after" False (dateMatchOn OnOrBefore [ "2026-10-01" ] (date 2026 10 2))
        , truth "on or after includes the day" True (dateMatchOn OnOrAfter [ "2026-10-01" ] (date 2026 10 1))
        , truth "on or after is false the day before" False (dateMatchOn OnOrAfter [ "2026-10-01" ] (date 2026 9 30))
        , truth "between includes the first day" True (dateMatchOn Between [ "2026-10-01", "2026-10-31" ] (date 2026 10 1))
        , truth "between includes the last day" True (dateMatchOn Between [ "2026-10-01", "2026-10-31" ] (date 2026 10 31))
        , truth "between is false after the last day" False (dateMatchOn Between [ "2026-10-01", "2026-10-31" ] (date 2026 11 1))
        , truth "between works with the ends the wrong way round" True (dateMatchOn Between [ "2026-10-31", "2026-10-01" ] (date 2026 10 15))
        , truth "between is false for a missing date" False (dateMatch Between [ "2026-10-01", "2026-10-31" ] Nothing)
        , truth "is empty for a missing date" True (dateMatch IsEmpty [] Nothing)
        , truth "is empty is false for a date" False (dateMatchOn IsEmpty [] today)
        , truth "is not empty for a date" True (dateMatchOn IsNotEmpty [] today)
        , truth "is not empty is false for a missing date" False (dateMatch IsNotEmpty [] Nothing)
        , truth "a missing date is not before anything" False (dateMatch Before [ "2100-01-01" ] Nothing)
        , truth "a missing date is not after anything" False (dateMatch After [ "1900-01-01" ] Nothing)
        , truth "a leap day can be an operand" True (dateMatchOn Is [ "2024-02-29" ] (date 2024 2 29))
        , truth "in the last days: today counts" True (dateMatchOn InLastDays [ "30" ] today)
        , truth "in the last 30 days: 30 days ago counts" True (dateMatchOn InLastDays [ "30" ] (date 2026 9 20))
        , truth "in the last 30 days: 31 days ago does not" False (dateMatchOn InLastDays [ "30" ] (date 2026 9 19))
        , truth "in the last days: tomorrow does not" False (dateMatchOn InLastDays [ "30" ] (date 2026 10 21))
        , truth "in the last 0 days is today only" True (dateMatchOn InLastDays [ "0" ] today)
        , truth "in the last 0 days is not yesterday" False (dateMatchOn InLastDays [ "0" ] (date 2026 10 19))
        , truth "in the last days: a missing date does not" False (dateMatch InLastDays [ "30" ] Nothing)
        , truth "in the last days crosses the end of the year" True (Rule.matches (date 2027 1 5) [ Rule.dateField "f" "F" identity ] (cond 1 "f" InLastDays [ "10" ]) (Just (date 2026 12 31)))
        , truth "in the next days: today counts" True (dateMatchOn InNextDays [ "7" ] today)
        , truth "in the next 7 days: 7 days ahead counts" True (dateMatchOn InNextDays [ "7" ] (date 2026 10 27))
        , truth "in the next 7 days: 8 days ahead does not" False (dateMatchOn InNextDays [ "7" ] (date 2026 10 28))
        , truth "in the next days: yesterday does not" False (dateMatchOn InNextDays [ "7" ] (date 2026 10 19))
        , truth "in the next days: a missing date does not" False (dateMatch InNextDays [ "7" ] Nothing)
        , truth "a number of days with a decimal comma is rounded" True (dateMatchOn InLastDays [ "2,6" ] (date 2026 10 17))
        , truth "an enormous number of days does not crash" True (dateMatchOn InLastDays [ "1e30" ] (date 1990 1 1))
        ]



-- CHOICES


choiceOperatorTests : Test
choiceOperatorTests =
    describe "choice operators"
        [ truth "is" True (choiceMatch Is [ "paid" ] "paid")
        , truth "is compares exactly, including the case" False (choiceMatch Is [ "paid" ] "Paid")
        , truth "is is false for another value" False (choiceMatch Is [ "paid" ] "open")
        , truth "is not" True (choiceMatch IsNot [ "paid" ] "open")
        , truth "is not is true for a row without a value" True (choiceMatch IsNot [ "paid" ] "")
        , truth "is any of" True (choiceMatch IsAnyOf [ "open", "paid" ] "paid")
        , truth "is any of is false for another value" False (choiceMatch IsAnyOf [ "open" ] "paid")
        , truth "is any of is false for a row without a value" False (choiceMatch IsAnyOf [ "open", "paid" ] "")
        , truth "is any of ignores blank entries" True (choiceMatch IsAnyOf [ "", "paid" ] "paid")
        , truth "is none of" True (choiceMatch IsNoneOf [ "open" ] "paid")
        , truth "is none of is false for a listed value" False (choiceMatch IsNoneOf [ "open", "paid" ] "paid")
        , truth "is none of is true for a row without a value" True (choiceMatch IsNoneOf [ "open", "paid" ] "")
        , truth "is empty for a row without a value" True (choiceMatch IsEmpty [] "")
        , truth "is empty is false for a value" False (choiceMatch IsEmpty [] "paid")
        , truth "is not empty for a value" True (choiceMatch IsNotEmpty [] "paid")
        , truth "is not empty is false for a row without a value" False (choiceMatch IsNotEmpty [] "")
        , truth "a value that is not one of the choices still compares" True (choiceMatch Is [ "void" ] "void")
        ]



-- YES OR NO


boolOperatorTests : Test
boolOperatorTests =
    describe "yes or no operators"
        [ truth "is yes" True (boolMatch IsTrue True)
        , truth "is yes is false for no" False (boolMatch IsTrue False)
        , truth "is no" True (boolMatch IsFalse False)
        , truth "is no is false for yes" False (boolMatch IsFalse True)
        , truth "is empty does not fit a yes or no field and is ignored" True (boolMatch IsEmpty True)
        ]



-- INCOMPLETE CONDITIONS


incompleteConditionTests : Test
incompleteConditionTests =
    let
        ignored name rule =
            check name everyOrder (run rule)
    in
    describe "incomplete conditions and unknown fields are ignored"
        [ ignored "a condition on an unknown field" (group 0 All [ cond 1 "nope" Is [ "x" ] ])
        , ignored "a condition on a field with an empty id" (group 0 All [ cond 1 "" Is [ "x" ] ])
        , ignored "a text condition without an operand" (group 0 All [ cond 1 "customer" Contains [] ])
        , ignored "a text condition with a blank operand" (group 0 All [ cond 1 "customer" Is [ "   " ] ])
        , ignored "a number condition with text for an operand" (group 0 All [ cond 1 "total" GreaterThan [ "abc" ] ])
        , ignored "a number condition without an operand" (group 0 All [ cond 1 "total" Is [] ])
        , ignored "between with one operand" (group 0 All [ cond 1 "total" Between [ "10" ] ])
        , ignored "between with a bad second operand" (group 0 All [ cond 1 "total" Between [ "10", "x" ] ])
        , ignored "a date condition with a date that does not exist" (group 0 All [ cond 1 "created" Is [ "2026-02-30" ] ])
        , ignored "a date condition that is not ISO" (group 0 All [ cond 1 "created" After [ "20.10.2026" ] ])
        , ignored "in the last days with text" (group 0 All [ cond 1 "created" InLastDays [ "many" ] ])
        , ignored "in the last days with a negative number" (group 0 All [ cond 1 "created" InLastDays [ "-5" ] ])
        , ignored "in the next days with a negative number" (group 0 All [ cond 1 "created" InNextDays [ "-5" ] ])
        , ignored "a choice condition without a choice" (group 0 All [ cond 1 "status" Is [ "" ] ])
        , ignored "is any of without choices" (group 0 All [ cond 1 "status" IsAnyOf [] ])
        , ignored "is any of with blank choices only" (group 0 All [ cond 1 "status" IsAnyOf [ "", " " ] ])
        , ignored "an operator of another kind on a choice field" (group 0 All [ cond 1 "status" GreaterThan [ "1" ] ])
        , ignored "an operator of another kind on a text field" (group 0 All [ cond 1 "customer" GreaterThan [ "1" ] ])
        , ignored "a text operator on a number field" (group 0 All [ cond 1 "total" Contains [ "1" ] ])
        , ignored "between on a text field" (group 0 All [ cond 1 "customer" Between [ "a", "z" ] ])
        , ignored "in the last days on a number field" (group 0 All [ cond 1 "total" InLastDays [ "30" ] ])
        , ignored "is yes on a text field" (group 0 All [ cond 1 "customer" IsTrue [] ])
        , ignored "is empty on a yes or no field" (group 0 All [ cond 1 "express" IsEmpty [] ])
        , check "an incomplete condition does not hide the complete ones"
            [ "ORD-1002" ]
            (run (group 0 All [ cond 1 "total" GreaterThan [ "abc" ], cond 2 "status" Is [ "open" ] ]))
        , check "in an 'any' group an incomplete condition counts as nothing, not as a match"
            []
            (run (group 0 Any [ cond 1 "total" GreaterThan [ "abc" ], cond 2 "status" Is [ "void" ] ]))
        , check "a group without a complete condition is ignored next to a complete one"
            [ "ORD-1002" ]
            (run (group 0 All [ cond 1 "status" Is [ "open" ], group 2 All [ cond 3 "nope" Is [ "x" ] ] ]))
        , check "an empty group inside a group is ignored"
            [ "ORD-1002" ]
            (run (group 0 All [ cond 1 "status" Is [ "open" ], group 2 Any [] ]))
        , check "a negated group without a complete condition still lets everything through"
            everyOrder
            (run (group 0 All [ notGroup 1 All [ cond 2 "nope" Is [ "x" ] ] ]))
        , check "a negated empty group lets everything through" everyOrder (run (notGroup 0 All []))
        ]



-- GROUPS


groupTests : Test
groupTests =
    let
        paid =
            cond 1 "status" Is [ "paid" ]

        large =
            cond 2 "total" GreaterThan [ "100" ]

        open =
            cond 3 "status" Is [ "open" ]
    in
    describe "groups"
        [ check "all of two" [ "ORD-1001" ] (run (group 0 All [ paid, large ]))
        , check "any of two" [ "ORD-1001", "ORD-1004" ] (run (group 0 Any [ paid, large ]))
        , check "not all of two" [ "ORD-1002", "ORD-1003", "ORD-1004" ] (run (notGroup 0 All [ paid, large ]))
        , check "none of two" [ "ORD-1002", "ORD-1003" ] (run (notGroup 0 Any [ paid, large ]))
        , check "a group with one condition" [ "ORD-1001", "ORD-1004" ] (run (group 0 All [ paid ]))
        , check "the order of the children does not matter" (run (group 0 All [ paid, large ])) (run (group 0 All [ large, paid ]))
        , check "double negation through nested groups" (run paid) (run (notGroup 0 All [ notGroup 1 All [ paid ] ]))
        , check "a nested all inside any" [ "ORD-1001", "ORD-1002" ] (run (group 0 Any [ group 4 All [ paid, large ], open ]))
        , check "three levels deep" [ "ORD-1001" ] (run (group 0 All [ group 1 All [ group 2 All [ group 3 All [ large ] ] ] ]))
        , check "all of a few conditions that together match nothing" [] (run (group 0 All [ paid, open ]))
        , test "De Morgan: not (a and b) is (not a) or (not b), for every order" <|
            \_ ->
                orders
                    |> List.map
                        (\row ->
                            Rule.matches today fields (notGroup 0 All [ paid, large ]) row
                                == Rule.matches today fields (group 0 Any [ notGroup 1 All [ paid ], notGroup 2 All [ large ] ]) row
                        )
                    |> Expect.equal (List.map (always True) orders)
        ]



-- COMPLETENESS


completenessTests : Test
completenessTests =
    let
        total =
            Rule.numberField "total" "Total" .total

        created =
            Rule.dateField "created" "Created" .created

        status =
            Rule.choiceField "status" "Status" statuses .status

        customer =
            Rule.textField "customer" "Customer" .customer

        express =
            Rule.boolField "express" "Express" .express

        condition operator values =
            { id = 1, field = "x", operator = operator, values = values }
    in
    describe "isComplete"
        [ truth "a number" True (Rule.isComplete total (condition GreaterThan [ "5" ]))
        , truth "a number with a decimal comma" True (Rule.isComplete total (condition GreaterThan [ "5,5" ]))
        , truth "not a number" False (Rule.isComplete total (condition GreaterThan [ "five" ]))
        , truth "no operand" False (Rule.isComplete total (condition GreaterThan []))
        , truth "an empty operand" False (Rule.isComplete total (condition GreaterThan [ "" ]))
        , truth "between needs two numbers" True (Rule.isComplete total (condition Between [ "1", "2" ]))
        , truth "between with one number is not enough" False (Rule.isComplete total (condition Between [ "1" ]))
        , truth "between with an empty end" False (Rule.isComplete total (condition Between [ "1", "" ]))
        , truth "between with the ends the wrong way round is complete" True (Rule.isComplete total (condition Between [ "9", "1" ]))
        , truth "extra operands after the used ones do not matter" True (Rule.isComplete total (condition GreaterThan [ "5", "junk" ]))
        , truth "is empty needs no operand" True (Rule.isComplete total (condition IsEmpty []))
        , truth "an operator of another kind is not complete" False (Rule.isComplete total (condition Contains [ "5" ]))
        , truth "a date" True (Rule.isComplete created (condition Before [ "2026-10-20" ]))
        , truth "a date in the wrong format" False (Rule.isComplete created (condition Before [ "20/10/2026" ]))
        , truth "a date that does not exist" False (Rule.isComplete created (condition Before [ "2026-13-01" ]))
        , truth "a number of days" True (Rule.isComplete created (condition InLastDays [ "7" ]))
        , truth "zero days" True (Rule.isComplete created (condition InLastDays [ "0" ]))
        , truth "a negative number of days" False (Rule.isComplete created (condition InLastDays [ "-1" ]))
        , truth "a date is not a number of days" False (Rule.isComplete created (condition InLastDays [ "2026-10-20" ]))
        , truth "a number of days is not a date" False (Rule.isComplete created (condition Is [ "7" ]))
        , truth "between needs two dates" True (Rule.isComplete created (condition Between [ "2026-01-01", "2026-12-31" ]))
        , truth "between with one bad date" False (Rule.isComplete created (condition Between [ "2026-01-01", "soon" ]))
        , truth "a choice" True (Rule.isComplete status (condition Is [ "paid" ]))
        , truth "a blank choice" False (Rule.isComplete status (condition Is [ "  " ]))
        , truth "any of needs one usable choice" True (Rule.isComplete status (condition IsAnyOf [ "", "paid" ]))
        , truth "any of with nothing usable" False (Rule.isComplete status (condition IsNoneOf [ "", " " ]))
        , truth "a text" True (Rule.isComplete customer (condition Contains [ "x" ]))
        , truth "a blank text" False (Rule.isComplete customer (condition Contains [ "   " ]))
        , truth "text with a space inside" True (Rule.isComplete customer (condition Contains [ "a b" ]))
        , truth "yes needs no operand" True (Rule.isComplete express (condition IsTrue []))
        , truth "a yes or no field has no other operator" False (Rule.isComplete express (condition Is [ "yes" ]))
        ]



-- EDITING


editingTests : Test
editingTests =
    describe "editing"
        [ describe "addCondition"
            [ check "adds a condition at the end of the group" [ 1, 2, 5 ] (childrenOf 0 (Rule.addCondition fields 0 sampleRule))
            , check "the new id is one more than the highest" 5 (Rule.nextId sampleRule)
            , check "the condition starts on the first field" (Just "customer") (fieldOf 5 (Rule.addCondition fields 0 sampleRule))
            , check "with the first operator that fits the field" (Just Contains) (operatorOf 5 (Rule.addCondition fields 0 sampleRule))
            , check "and no operands" [] (valuesOf 5 (Rule.addCondition fields 0 sampleRule))
            , check "it can be added in a nested group" [ 3, 4, 5 ] (childrenOf 2 (Rule.addCondition fields 2 sampleRule))
            , check "the first operator follows the kind of the first field" (Just Is) (operatorOf 1 (Rule.addCondition [ Rule.numberField "n" "N" (always Nothing) ] 0 Rule.emptyGroup))
            , check "the first field is used even when it is a yes or no field" (Just IsTrue) (operatorOf 1 (Rule.addCondition [ Rule.boolField "b" "B" (always True) ] 0 Rule.emptyGroup))
            , check "without fields the condition has no field" (Just "") (fieldOf 1 (Rule.addCondition [] 0 Rule.emptyGroup))
            , check "without fields the operator is 'is'" (Just Is) (operatorOf 1 (Rule.addCondition [] 0 Rule.emptyGroup))
            , check "an unknown group changes nothing" sampleRule (Rule.addCondition fields 99 sampleRule)
            , check "a condition id changes nothing" sampleRule (Rule.addCondition fields 1 sampleRule)
            , check "to an empty group gives the first id 1" [ 0, 1 ] (ids (Rule.addCondition fields 0 Rule.emptyGroup))
            , truth "a new condition is not complete, so it filters nothing" True (List.length (run (Rule.addCondition fields 0 Rule.emptyGroup)) == List.length orders)
            ]
        , describe "addGroup"
            [ check "adds an empty group" [ 1, 2, 5 ] (childrenOf 0 (Rule.addGroup 0 sampleRule))
            , check "inside 'all' it starts as 'any'" (Just Any) (combinatorOf 1 (Rule.addGroup 0 Rule.emptyGroup))
            , check "inside 'any' it starts as 'all'" (Just All) (combinatorOf 5 (Rule.addGroup 2 sampleRule))
            , check "it is not negated" (Just False) (isNegated 5 (Rule.addGroup 0 sampleRule))
            , check "it has no children" [] (childrenOf 5 (Rule.addGroup 0 sampleRule))
            , check "an unknown group changes nothing" sampleRule (Rule.addGroup 99 sampleRule)
            , check "a condition id changes nothing" sampleRule (Rule.addGroup 3 sampleRule)
            ]
        , describe "remove"
            [ check "removes a condition" [ 2 ] (childrenOf 0 (Rule.remove 1 sampleRule))
            , check "removes a nested condition" [ 3 ] (childrenOf 2 (Rule.remove 4 sampleRule))
            , check "removes a group with everything in it" [ 0, 1 ] (ids (Rule.remove 2 sampleRule))
            , check "the root cannot be removed" sampleRule (Rule.remove 0 sampleRule)
            , check "an unknown id changes nothing" sampleRule (Rule.remove 99 sampleRule)
            , check "the other nodes keep their ids" [ 0, 2, 3, 4 ] (ids (Rule.remove 1 sampleRule))
            , check "removing everything leaves the empty root" Rule.emptyGroup (sampleRule |> Rule.remove 1 |> Rule.remove 2)
            , check "the root of a rule without children stays" Rule.emptyGroup (Rule.remove 0 Rule.emptyGroup)
            , check "a condition as the whole rule is not removed" (cond 1 "a" Is [ "x" ]) (Rule.remove 1 (cond 1 "a" Is [ "x" ]))
            ]
        , describe "duplicate"
            [ check "puts the copy right after the original" [ 1, 5, 2 ] (childrenOf 0 (Rule.duplicate 1 sampleRule))
            , check "the copy has a new id" True (allUnique (ids (Rule.duplicate 1 sampleRule)))
            , check "a copy of a condition equals the original" (findNode 1 sampleRule |> Maybe.map stripIds) (findNode 5 (Rule.duplicate 1 sampleRule) |> Maybe.map stripIds)
            , check "a copy of a group gets new ids all the way down" [ 0, 1, 2, 3, 4, 5, 6, 7 ] (List.sort (ids (Rule.duplicate 2 sampleRule)))
            , check "the copy of a group comes after it" [ 1, 2, 5 ] (childrenOf 0 (Rule.duplicate 2 sampleRule))
            , check "the copy of a group has its own children" [ 6, 7 ] (childrenOf 5 (Rule.duplicate 2 sampleRule))
            , check "a copy of a group equals the original" (findNode 2 sampleRule |> Maybe.map stripIds) (findNode 5 (Rule.duplicate 2 sampleRule) |> Maybe.map stripIds)
            , check "the condition count grows by what was copied" (Rule.conditionCount sampleRule + 2) (Rule.conditionCount (Rule.duplicate 2 sampleRule))
            , check "a nested condition can be duplicated" [ 3, 5, 4 ] (childrenOf 2 (Rule.duplicate 3 sampleRule))
            , check "the root cannot be duplicated" sampleRule (Rule.duplicate 0 sampleRule)
            , check "an unknown id changes nothing" sampleRule (Rule.duplicate 99 sampleRule)
            , check "duplicating twice keeps the ids unique" True (allUnique (ids (sampleRule |> Rule.duplicate 1 |> Rule.duplicate 1 |> Rule.duplicate 2)))
            ]
        , describe "setCombinator and toggleNegated"
            [ check "setCombinator changes a group" (Just Any) (combinatorOf 0 (Rule.setCombinator 0 Any sampleRule))
            , check "setCombinator changes a nested group" (Just All) (combinatorOf 2 (Rule.setCombinator 2 All sampleRule))
            , check "setCombinator ignores a condition" sampleRule (Rule.setCombinator 1 Any sampleRule)
            , check "setCombinator ignores an unknown id" sampleRule (Rule.setCombinator 99 Any sampleRule)
            , check "toggleNegated negates" (Just True) (isNegated 0 (Rule.toggleNegated 0 sampleRule))
            , check "toggleNegated twice is the same" sampleRule (sampleRule |> Rule.toggleNegated 2 |> Rule.toggleNegated 2)
            , check "toggleNegated ignores a condition" sampleRule (Rule.toggleNegated 1 sampleRule)
            , check "toggleNegated ignores an unknown id" sampleRule (Rule.toggleNegated 99 sampleRule)
            ]
        , describe "setField"
            [ check "changes the field" (Just "status") (fieldOf 3 (Rule.setField fields 3 "status" sampleRule))
            , check "keeps an operator that fits the new field" (Just Is) (operatorOf 1 (Rule.setField fields 1 "created" sampleRule))
            , check "takes the first operator when the old one does not fit" (Just Is) (operatorOf 1 (Rule.setField fields 1 "total" (group 0 All [ cond 1 "customer" Contains [ "x" ] ])))
            , check "clears the operands" [] (valuesOf 3 (Rule.setField fields 3 "customer" sampleRule))
            , check "clears the operands even when the operator is kept" [] (valuesOf 1 (Rule.setField fields 1 "created" sampleRule))
            , check "an unknown field id only changes the field"
                ( Just "mystery", Just GreaterThan, [ "50" ] )
                (let
                    r =
                        Rule.setField fields 3 "mystery" sampleRule
                 in
                 ( fieldOf 3 r, operatorOf 3 r, valuesOf 3 r )
                )
            , check "a group id changes nothing" sampleRule (Rule.setField fields 2 "status" sampleRule)
            , check "an unknown node changes nothing" sampleRule (Rule.setField fields 99 "status" sampleRule)
            ]
        , describe "setOperator"
            [ check "changes the operator" (Just LessThan) (operatorOf 3 (Rule.setOperator 3 LessThan sampleRule))
            , check "keeps the first operand for an operator with one" [ "50" ] (valuesOf 3 (Rule.setOperator 3 LessThan sampleRule))
            , check "drops the operands for an operator without" [] (valuesOf 3 (Rule.setOperator 3 IsEmpty sampleRule))
            , check "pads 'between' to two operands" [ "50", "" ] (valuesOf 3 (Rule.setOperator 3 Between sampleRule))
            , check "pads 'between' without operands to two empty ones" [ "", "" ] (valuesOf 1 (Rule.setOperator 1 Between (group 0 All [ cond 1 "total" IsEmpty [] ])))
            , check "trims 'between' to two operands" [ "a", "b" ] (valuesOf 1 (Rule.setOperator 1 Between (group 0 All [ cond 1 "total" IsAnyOf [ "a", "b", "c" ] ])))
            , check "keeps all operands for 'any of'" [ "a", "b", "c" ] (valuesOf 1 (Rule.setOperator 1 IsAnyOf (group 0 All [ cond 1 "status" IsNoneOf [ "a", "b", "c" ] ])))
            , check "trims many operands to one for an operator with one" [ "a" ] (valuesOf 1 (Rule.setOperator 1 Is (group 0 All [ cond 1 "status" IsAnyOf [ "a", "b", "c" ] ])))
            , check "ignores a group" sampleRule (Rule.setOperator 2 Is sampleRule)
            , check "ignores an unknown id" sampleRule (Rule.setOperator 99 Is sampleRule)
            ]
        ]



-- MOVING


moveTests : Test
moveTests =
    let
        flat =
            group 0 All [ cond 1 "a" Is [ "x" ], cond 2 "b" Is [ "x" ], cond 3 "c" Is [ "x" ], cond 4 "d" Is [ "x" ] ]
    in
    describe "move"
        [ check "one step down swaps with the next" [ 2, 1, 3, 4 ] (childrenOf 0 (Rule.move 1 1 flat))
        , check "one step up swaps with the previous" [ 1, 3, 2, 4 ] (childrenOf 0 (Rule.move 3 -1 flat))
        , check "down from the middle" [ 1, 2, 4, 3 ] (childrenOf 0 (Rule.move 3 1 flat))
        , check "nothing happens at the top" [ 1, 2, 3, 4 ] (childrenOf 0 (Rule.move 1 -1 flat))
        , check "nothing happens at the bottom" [ 1, 2, 3, 4 ] (childrenOf 0 (Rule.move 4 1 flat))
        , check "an unknown id changes nothing" flat (Rule.move 99 1 flat)
        , check "the root cannot be moved" flat (Rule.move 0 1 flat)
        , check "a node in a nested group moves within that group" [ 4, 3 ] (childrenOf 2 (Rule.move 3 1 sampleRule))
        , check "moving a group moves it with its children" [ 2, 1 ] (childrenOf 0 (Rule.move 1 1 sampleRule))
        , check "moving a group keeps its children in order" [ 3, 4 ] (childrenOf 2 (Rule.move 2 -1 sampleRule))
        , check "a nested group can move too" [ 7, 6 ] (childrenOf 5 (Rule.move 6 1 (group 0 All [ group 5 Any [ cond 6 "a" Is [ "x" ], cond 7 "b" Is [ "x" ] ] ])))
        , check "moving down and up again restores the rule" flat (flat |> Rule.move 2 1 |> Rule.move 2 -1)
        , check "a single child cannot move" [ 1 ] (childrenOf 0 (Rule.move 1 1 (group 0 All [ cond 1 "a" Is [ "x" ] ])))
        , -- Was a bug: a delta of 0 put the node in the list twice (two nodes with the same id).
          check "a delta of 0 changes nothing" [ 1, 2, 3, 4 ] (childrenOf 0 (Rule.move 2 0 flat))
        , -- Was a bug: a delta of 2 (or more) dropped the nodes between the two places from the tree.
          check "a delta of 2 keeps every node" [ 1, 2, 3, 4 ] (childrenOf 0 (Rule.move 1 2 flat) |> List.sort)
        , -- The same for moving up by more than one.
          check "a delta of -3 keeps every node" [ 1, 2, 3, 4 ] (childrenOf 0 (Rule.move 4 -3 flat) |> List.sort)
        , check "a delta past the end changes nothing" [ 1, 2, 3, 4 ] (childrenOf 0 (Rule.move 2 9 flat))
        ]



-- OPERANDS


valueEditingTests : Test
valueEditingTests =
    describe "editing operands"
        [ describe "setValue"
            [ check "sets the first operand" [ "99" ] (valuesOf 3 (Rule.setValue 3 0 "99" sampleRule))
            , check "grows the list with empty texts" [ "50", "", "x" ] (valuesOf 3 (Rule.setValue 3 2 "x" sampleRule))
            , check "sets the second operand of 'between'" [ "10", "20" ] (valuesOf 1 (Rule.setValue 1 1 "20" (Rule.setValue 1 0 "10" (Rule.setOperator 1 Between (group 0 All [ cond 1 "total" Is [] ])))))
            , check "replaces only the operand at the index" [ "a", "z", "c" ] (valuesOf 1 (Rule.setValue 1 1 "z" (group 0 All [ cond 1 "status" IsAnyOf [ "a", "b", "c" ] ])))
            , check "a negative index changes nothing" sampleRule (Rule.setValue 3 -1 "x" sampleRule)
            , check "a group id changes nothing" sampleRule (Rule.setValue 2 0 "x" sampleRule)
            , check "an unknown id changes nothing" sampleRule (Rule.setValue 99 0 "x" sampleRule)
            , check "setting the same text again is the same" (Rule.setValue 3 0 "7" sampleRule) (sampleRule |> Rule.setValue 3 0 "7" |> Rule.setValue 3 0 "7")
            , check "an empty text is stored" [ "" ] (valuesOf 3 (Rule.setValue 3 0 "" sampleRule))
            ]
        , describe "addValue"
            [ check "adds at the end" [ "a", "b" ] (valuesOf 1 (Rule.addValue 1 "b" (group 0 All [ cond 1 "status" IsAnyOf [ "a" ] ])))
            , check "ignores a value that is already there" [ "a" ] (valuesOf 1 (Rule.addValue 1 "a" (group 0 All [ cond 1 "status" IsAnyOf [ "a" ] ])))
            , check "ignores empty text" [ "a" ] (valuesOf 1 (Rule.addValue 1 "" (group 0 All [ cond 1 "status" IsAnyOf [ "a" ] ])))
            , check "keeps text with spaces" [ "a", " " ] (valuesOf 1 (Rule.addValue 1 " " (group 0 All [ cond 1 "status" IsAnyOf [ "a" ] ])))
            , check "is case sensitive" [ "a", "A" ] (valuesOf 1 (Rule.addValue 1 "A" (group 0 All [ cond 1 "status" IsAnyOf [ "a" ] ])))
            , check "ignores a group" sampleRule (Rule.addValue 2 "x" sampleRule)
            , check "ignores an unknown id" sampleRule (Rule.addValue 99 "x" sampleRule)
            ]
        , describe "removeValue"
            [ check "removes an operand" [ "a", "c" ] (valuesOf 1 (Rule.removeValue 1 "b" (group 0 All [ cond 1 "status" IsAnyOf [ "a", "b", "c" ] ])))
            , check "removes every operand that is equal" [ "a" ] (valuesOf 1 (Rule.removeValue 1 "b" (group 0 All [ cond 1 "status" IsAnyOf [ "b", "a", "b" ] ])))
            , check "an absent text changes nothing" [ "a" ] (valuesOf 1 (Rule.removeValue 1 "x" (group 0 All [ cond 1 "status" IsAnyOf [ "a" ] ])))
            , check "can remove an empty operand" [ "a" ] (valuesOf 1 (Rule.removeValue 1 "" (group 0 All [ cond 1 "status" IsAnyOf [ "a", "" ] ])))
            , check "ignores an unknown id" sampleRule (Rule.removeValue 99 "x" sampleRule)
            ]
        ]



-- LOOKING AT A RULE


lookingTests : Test
lookingTests =
    describe "looking at a rule"
        [ check "idOf of a group" 2 (Rule.idOf (group 2 All []))
        , check "idOf of a condition" 7 (Rule.idOf (cond 7 "a" Is []))
        , check "the empty group has the id 0" 0 (Rule.idOf Rule.emptyGroup)
        , check "the empty group is an 'all' group" (Just All) (combinatorOf 0 Rule.emptyGroup)
        , check "the empty group is not negated" (Just False) (isNegated 0 Rule.emptyGroup)
        , check "nextId of the empty group" 1 (Rule.nextId Rule.emptyGroup)
        , check "nextId is one more than the highest id" 5 (Rule.nextId sampleRule)
        , check "nextId looks at deep nodes" 100 (Rule.nextId (group 0 All [ group 1 All [ cond 99 "a" Is [] ] ]))
        , check "nextId of a condition" 4 (Rule.nextId (cond 3 "a" Is []))
        , check "depth of a condition" 0 (Rule.depth (cond 1 "a" Is []))
        , check "depth of an empty group" 1 (Rule.depth Rule.emptyGroup)
        , check "depth of a group of conditions" 1 (Rule.depth (group 0 All [ cond 1 "a" Is [], cond 2 "b" Is [] ]))
        , check "depth of a group with a group in it" 2 (Rule.depth sampleRule)
        , check "depth counts the deepest branch" 3 (Rule.depth (group 0 All [ cond 1 "a" Is [], group 2 All [ group 3 All [] ], group 4 All [] ]))
        , check "conditionCount of nothing" 0 (Rule.conditionCount Rule.emptyGroup)
        , check "conditionCount counts all levels" 3 (Rule.conditionCount sampleRule)
        , check "conditionCount of a condition" 1 (Rule.conditionCount (cond 1 "a" Is []))
        , check "conditionCount does not count groups" 0 (Rule.conditionCount (group 0 All [ group 1 All [], group 2 All [] ]))
        , check "isEmpty is false with a condition" False (Rule.isEmpty sampleRule)
        , check "isEmpty ignores empty groups" True (Rule.isEmpty (group 0 All [ group 1 All [] ]))
        , check "a condition is not empty" False (Rule.isEmpty (cond 1 "a" Is []))
        , check "quote in English" "“Ada”" (Rule.quote Locale.en "Ada")
        , check "quote in Norwegian" "«Ada»" (Rule.quote Locale.nb "Ada")
        , check "quote of nothing" "“”" (Rule.quote Locale.en "")
        , check "quote does not escape what is inside" "“a“b”c”" (Rule.quote Locale.en "a“b”c")
        ]



-- IN WORDS


describeTests : Test
describeTests =
    let
        sentence =
            group 0
                All
                [ cond 1 "status" Is [ "paid" ]
                , group 2
                    Any
                    [ cond 3 "total" GreaterThan [ "100" ]
                    , cond 4 "customer" Contains [ "acme" ]
                    ]
                ]

        words locale rule =
            Rule.describe locale fields rule
    in
    describe "describe"
        [ check "an empty rule" "All rows" (words Locale.en Rule.emptyGroup)
        , check "an empty rule in Norwegian" "Alle rader" (words Locale.nb Rule.emptyGroup)
        , check "one condition" "Status is Paid" (words Locale.en (group 0 All [ cond 1 "status" Is [ "paid" ] ]))
        , check "a condition may be the whole rule" "Status is Paid" (words Locale.en (cond 1 "status" Is [ "paid" ]))
        , check "the documented sentence" "Status is Paid and (Total > 100 or Customer contains “acme”)" (words Locale.en sentence)
        , check "in Norwegian" "Status er Paid og (Total > 100 eller Customer inneholder «acme»)" (words Locale.nb sentence)
        , check "a group of one part has no parentheses" "Status is Paid" (words Locale.en (group 0 All [ group 1 Any [ cond 2 "status" Is [ "paid" ] ] ]))
        , check "the root has no parentheses" "Status is Paid and Total > 100" (words Locale.en (group 0 All [ cond 1 "status" Is [ "paid" ], cond 2 "total" GreaterThan [ "100" ] ]))
        , check "a negated group" "not (Status is Paid)" (words Locale.en (notGroup 0 All [ cond 1 "status" Is [ "paid" ] ]))
        , check "a negated group in Norwegian" "ikke (Status er Paid)" (words Locale.nb (notGroup 0 All [ cond 1 "status" Is [ "paid" ] ]))
        , check "a negated group of two parts" "not (Status is Paid or Total > 1)" (words Locale.en (notGroup 0 Any [ cond 1 "status" Is [ "paid" ], cond 2 "total" GreaterThan [ "1" ] ]))
        , check "a nested negated group" "Total > 1 and not (Status is Paid)" (words Locale.en (group 0 All [ cond 1 "total" GreaterThan [ "1" ], notGroup 2 All [ cond 3 "status" Is [ "paid" ] ] ]))
        , check "incomplete conditions are left out" "Status is Open" (words Locale.en (group 0 All [ cond 1 "total" GreaterThan [ "abc" ], cond 2 "status" Is [ "open" ] ]))
        , check "conditions on unknown fields are left out" "Status is Open" (words Locale.en (group 0 All [ cond 1 "nope" Is [ "x" ], cond 2 "status" Is [ "open" ] ]))
        , check "a rule with nothing complete reads as all rows" "All rows" (words Locale.en (group 0 All [ cond 1 "total" GreaterThan [ "abc" ] ]))
        , check "a negated group with nothing complete reads as all rows" "All rows" (words Locale.en (notGroup 0 All [ cond 1 "nope" Is [ "x" ] ]))
        , check "an empty group inside a group is left out" "Status is Open" (words Locale.en (group 0 All [ group 1 Any [], cond 2 "status" Is [ "open" ] ]))
        , check "text operands are quoted" "Customer starts with “Ada”" (words Locale.en (cond 1 "customer" StartsWith [ "Ada" ]))
        , check "text operands keep what was typed" "Customer is “ GLOBEX ”" (words Locale.en (cond 1 "customer" Is [ " GLOBEX " ]))
        , check "number operands are not quoted, and are written as they were read" "Total ≥ 50.5" (words Locale.en (cond 1 "total" GreaterOrEqual [ "50,5" ]))
        , check "choices are written with their label" "Status is not Open" (words Locale.en (cond 1 "status" IsNot [ "open" ]))
        , check "a choice that is not known is written as it is" "Status is void" (words Locale.en (cond 1 "status" Is [ "void" ]))
        , check "any of lists the labels" "Status is any of Paid, Open" (words Locale.en (cond 1 "status" IsAnyOf [ "paid", "open" ]))
        , check "any of leaves out blank entries" "Status is none of Paid" (words Locale.en (cond 1 "status" IsNoneOf [ "", "paid" ]))
        , check "between writes both ends" "Total between 10 – 20" (words Locale.en (cond 1 "total" Between [ "10", "20" ]))
        , check "no operand" "Total is empty" (words Locale.en (cond 1 "total" IsEmpty []))
        , check "yes or no" "Express is yes" (words Locale.en (cond 1 "express" IsTrue []))
        , check "dates are written in the format of the locale (English)" "Created after 2026-01-31" (words Locale.en (cond 1 "created" After [ "2026-01-31" ]))
        , check "dates are written in the format of the locale (Norwegian)" "Created etter 31.01.2026" (words Locale.nb (cond 1 "created" After [ "2026-01-31" ]))
        , check "between two dates" "Created between 2026-01-01 – 2026-01-31" (words Locale.en (cond 1 "created" Between [ "2026-01-01", "2026-01-31" ]))
        , check "in the last days" "Created in the last 30 days" (words Locale.en (cond 1 "created" InLastDays [ "30" ]))
        , check "in the next days in Norwegian" "Created neste 7 dager" (words Locale.nb (cond 1 "created" InNextDays [ "7" ]))
        , -- Was a bug: the sentence did not use the singular, so one day read "in the last
          -- 1 days" (and "siste 1 dager" in Norwegian).
          check "one day is not written in the plural (English)" False (String.endsWith " 1 days" (words Locale.en (cond 1 "created" InLastDays [ "1" ])))
        , -- The same in Norwegian.
          check "one day is not written in the plural (Norwegian)" False (String.endsWith " 1 dager" (words Locale.nb (cond 1 "created" InNextDays [ "1" ])))
        , test "describing never gives an empty text" <|
            \_ ->
                [ Rule.emptyGroup, sampleRule, sentence, cond 1 "nope" Is [] ]
                    |> List.map (\rule -> words Locale.en rule /= "" && words Locale.nb rule /= "")
                    |> Expect.equal [ True, True, True, True ]
        ]



-- VALIDATION


validateTests : Test
validateTests =
    let
        problems locale rule =
            Rule.validate locale fields rule |> List.map (\issue -> ( issue.nodeId, issue.message ))

        messages locale rule =
            Rule.validate locale fields rule |> List.map .message
    in
    describe "validate"
        [ check "a good rule has no issues" [] (messages Locale.en sampleRule)
        , check "an empty root group is fine" [] (messages Locale.en Rule.emptyGroup)
        , check "a missing operand" [ "A value is missing" ] (messages Locale.en (group 0 All [ cond 1 "customer" Contains [ "" ] ]))
        , check "a missing operand in Norwegian" [ "Mangler verdi" ] (messages Locale.nb (group 0 All [ cond 1 "customer" Contains [] ]))
        , check "a number that is no number" [ "Enter a valid number" ] (messages Locale.en (group 0 All [ cond 1 "total" GreaterThan [ "abc" ] ]))
        , check "a number that is no number in Norwegian" [ "Skriv inn et gyldig tall" ] (messages Locale.nb (group 0 All [ cond 1 "total" GreaterThan [ "abc" ] ]))
        , check "a date that is no date" [ "Choose a valid date" ] (messages Locale.en (group 0 All [ cond 1 "created" Is [ "yesterday" ] ]))
        , check "a date that is no date in Norwegian" [ "Velg en gyldig dato" ] (messages Locale.nb (group 0 All [ cond 1 "created" Is [ "yesterday" ] ]))
        , check "days that are no number" [ "Enter a whole number of days" ] (messages Locale.en (group 0 All [ cond 1 "created" InLastDays [ "x" ] ]))
        , check "a negative number of days" [ "Enter a whole number of days" ] (messages Locale.en (group 0 All [ cond 1 "created" InNextDays [ "-2" ] ]))
        , check "days in Norwegian" [ "Skriv inn et helt antall dager" ] (messages Locale.nb (group 0 All [ cond 1 "created" InNextDays [ "-2" ] ]))
        , check "an unknown field" [ "Choose a field" ] (messages Locale.en (group 0 All [ cond 1 "nope" Is [ "x" ] ]))
        , check "an unknown field in Norwegian" [ "Velg et felt" ] (messages Locale.nb (group 0 All [ cond 1 "nope" Is [ "x" ] ]))
        , check "no field at all" [ "Choose a field" ] (messages Locale.en (group 0 All [ cond 1 "" Is [] ]))
        , check "an operator that does not fit" [ "The operator does not fit the field" ] (messages Locale.en (group 0 All [ cond 1 "status" GreaterThan [ "1" ] ]))
        , check "an operator that does not fit, in Norwegian" [ "Betingelsen passer ikke til feltet" ] (messages Locale.nb (group 0 All [ cond 1 "status" GreaterThan [ "1" ] ]))
        , check "numbers the wrong way round" [ "The first value must not be larger than the second" ] (messages Locale.en (group 0 All [ cond 1 "total" Between [ "10", "5" ] ]))
        , check "numbers the wrong way round in Norwegian" [ "Fra-verdien kan ikke være større enn til-verdien" ] (messages Locale.nb (group 0 All [ cond 1 "total" Between [ "10", "5" ] ]))
        , check "numbers in the right order" [] (messages Locale.en (group 0 All [ cond 1 "total" Between [ "5", "10" ] ]))
        , check "equal numbers are fine" [] (messages Locale.en (group 0 All [ cond 1 "total" Between [ "5", "5" ] ]))
        , check "dates the wrong way round" [ "The start date must not be after the end date" ] (messages Locale.en (group 0 All [ cond 1 "created" Between [ "2026-12-31", "2026-01-01" ] ]))
        , check "dates the wrong way round in Norwegian" [ "Fra-datoen kan ikke være etter til-datoen" ] (messages Locale.nb (group 0 All [ cond 1 "created" Between [ "2026-12-31", "2026-01-01" ] ]))
        , check "dates in the right order" [] (messages Locale.en (group 0 All [ cond 1 "created" Between [ "2026-01-01", "2026-12-31" ] ]))
        , check "a nested group that is empty" [ "The group is empty" ] (messages Locale.en (group 0 All [ group 1 Any [] ]))
        , check "an empty group in Norwegian" [ "Gruppen er tom" ] (messages Locale.nb (group 0 All [ group 1 Any [] ]))
        , check "the issue names the node" [ ( 1, "The group is empty" ) ] (problems Locale.en (group 0 All [ group 1 Any [] ]))
        , check "the issues come in the order of the tree" [ 2, 3, 5 ] (Rule.validate Locale.en fields (group 0 All [ group 1 Any [ cond 2 "nope" Is [] ], cond 3 "total" Is [ "x" ], group 4 All [ group 5 All [] ] ]) |> List.map .nodeId)
        , check "every node has at most one issue"
            True
            (let
                issues =
                    Rule.validate Locale.en fields (group 0 All [ cond 1 "total" Between [ "x", "y" ], cond 2 "nope" Is [], group 3 All [] ])
             in
             allUnique (List.map .nodeId issues)
            )
        , check "a condition that is the whole rule is checked" [ "A value is missing" ] (messages Locale.en (cond 1 "customer" Is []))
        , -- Was a bug: only a list of exactly two operands was checked for the order of the
          -- ends, although `matches` reads the first two operands of a 'between' (and is
          -- complete with them), so a hand-written rule with a third operand was used with
          -- its ends the wrong way round and validate said nothing.
          check "numbers the wrong way round are found when there is a third operand" [ "The first value must not be larger than the second" ] (messages Locale.en (group 0 All [ cond 1 "total" Between [ "10", "5", "7" ] ]))
        , -- The same for dates.
          check "dates the wrong way round are found when there is a third operand" [ "The start date must not be after the end date" ] (messages Locale.en (group 0 All [ cond 1 "created" Between [ "2026-12-31", "2026-01-01", "2026-06-01" ] ]))
        ]



-- JSON


jsonTests : Test
jsonTests =
    let
        encoded rule =
            Encode.encode 0 (Rule.encode rule)

        decoded text =
            Decode.decodeString Rule.decoder text

        isError result =
            case result of
                Err _ ->
                    True

                Ok _ ->
                    False

        conditionJson operator =
            "{\"type\":\"condition\",\"field\":\"f\",\"operator\":\"" ++ operator ++ "\",\"values\":[]}"

        nested levels =
            if levels <= 0 then
                conditionJson "empty"

            else
                "{\"type\":\"group\",\"combinator\":\"all\",\"children\":[" ++ nested (levels - 1) ++ "]}"

        keyOf operator =
            encoded (cond 0 "f" operator [])
    in
    describe "JSON"
        [ check "a group" "{\"type\":\"group\",\"combinator\":\"all\",\"not\":false,\"children\":[]}" (encoded Rule.emptyGroup)
        , check "a negated 'any' group" "{\"type\":\"group\",\"combinator\":\"any\",\"not\":true,\"children\":[]}" (encoded (notGroup 0 Any []))
        , check "a condition" "{\"type\":\"condition\",\"field\":\"total\",\"operator\":\"gt\",\"values\":[\"100\"]}" (encoded (cond 1 "total" GreaterThan [ "100" ]))
        , check "the documented shape"
            "{\"type\":\"group\",\"combinator\":\"all\",\"not\":false,\"children\":[{\"type\":\"condition\",\"field\":\"status\",\"operator\":\"is\",\"values\":[\"paid\"]},{\"type\":\"condition\",\"field\":\"total\",\"operator\":\"gt\",\"values\":[\"100\"]}]}"
            (encoded (group 0 All [ cond 1 "status" Is [ "paid" ], cond 2 "total" GreaterThan [ "100" ] ]))
        , check "the ids are not written" False (String.contains "\"id\"" (encoded sampleRule))
        , check "text is escaped" "{\"type\":\"condition\",\"field\":\"a\\\"b\",\"operator\":\"is\",\"values\":[\"\\\\ \\n\"]}" (encoded (cond 1 "a\"b" Is [ "\\ \n" ]))
        , check "the operator keys that are the name of the constructor"
            [ "is", "isNot", "contains", "notContains", "startsWith", "endsWith", "between", "notBetween", "before", "after", "onOrBefore", "onOrAfter", "inLastDays", "inNextDays", "moreThanDaysAgo", "moreThanDaysAhead", "inPeriod" ]
            ([ Is, IsNot, Contains, NotContains, StartsWith, EndsWith, Between, NotBetween, Before, After, OnOrBefore, OnOrAfter, InLastDays, InNextDays, MoreThanDaysAgo, MoreThanDaysAhead, InPeriod ]
                |> List.map (\operator -> keyOf operator |> operatorKeyIn)
            )
        , check "the other operator keys"
            [ "lt", "lte", "gt", "gte", "anyOf", "noneOf", "empty", "notEmpty", "true", "false" ]
            ([ LessThan, LessOrEqual, GreaterThan, GreaterOrEqual, IsAnyOf, IsNoneOf, IsEmpty, IsNotEmpty, IsTrue, IsFalse ]
                |> List.map (\operator -> keyOf operator |> operatorKeyIn)
            )
        , check "the number equality of earlier versions is read as is and isNot"
            [ Ok (cond 0 "f" Is []), Ok (cond 0 "f" IsNot []) ]
            [ decoded (conditionJson "eq"), decoded (conditionJson "neq") ]
        , check "the keys of all operators are different" True (allUniqueStrings (List.map keyOf allOperators))
        , test "every operator is read back from its key" <|
            \_ ->
                allOperators
                    |> List.filter (\operator -> decoded (keyOf operator) /= Ok (cond 0 "f" operator []))
                    |> Expect.equal []
        , check "a group is read" (Ok (notGroup 0 Any [])) (decoded "{\"type\":\"group\",\"combinator\":\"any\",\"not\":true,\"children\":[]}")
        , check "'not' may be left out" (Ok (group 0 Any [])) (decoded "{\"type\":\"group\",\"combinator\":\"any\",\"children\":[]}")
        , check "a combinator other than 'any' is 'all'" (Ok (group 0 All [])) (decoded "{\"type\":\"group\",\"combinator\":\"either\",\"children\":[]}")
        , check "a condition is read" (Ok (cond 0 "total" GreaterThan [ "100" ])) (decoded "{\"type\":\"condition\",\"field\":\"total\",\"operator\":\"gt\",\"values\":[\"100\"]}")
        , check "a condition keeps all of its operands" (Ok (cond 0 "s" IsAnyOf [ "a", "b", "", "c" ])) (decoded "{\"type\":\"condition\",\"field\":\"s\",\"operator\":\"anyOf\",\"values\":[\"a\",\"b\",\"\",\"c\"]}")
        , check "unknown extra keys are ignored" (Ok (group 0 All [])) (decoded "{\"type\":\"group\",\"combinator\":\"all\",\"children\":[],\"title\":\"My filter\",\"id\":17}")
        , check "an unknown type fails" True (isError (decoded "{\"type\":\"box\",\"children\":[]}"))
        , check "an unknown operator fails" True (isError (decoded (conditionJson "nope")))
        , check "an operator key is case sensitive" True (isError (decoded (conditionJson "IsNot")))
        , check "a condition without values has none" (Ok (cond 0 "f" IsEmpty [])) (decoded "{\"type\":\"condition\",\"field\":\"f\",\"operator\":\"empty\"}")
        , check "values that are null are none" (Ok (cond 0 "f" IsEmpty [])) (decoded "{\"type\":\"condition\",\"field\":\"f\",\"operator\":\"empty\",\"values\":null}")
        , check "values that are not a list fail" True (isError (decoded "{\"type\":\"condition\",\"field\":\"f\",\"operator\":\"is\",\"values\":\"open\"}"))
        , check "values that are not texts fail" True (isError (decoded "{\"type\":\"condition\",\"field\":\"f\",\"operator\":\"is\",\"values\":[1]}"))
        , check "a missing type fails" True (isError (decoded "{\"combinator\":\"all\",\"children\":[]}"))
        , check "text that is no JSON fails" True (isError (decoded "not json"))
        , check "null fails" True (isError (decoded "null"))
        , check "the ids are counted from the top down"
            (Ok [ 0, 1, 2, 3, 4 ])
            (decoded (encoded (group 9 All [ cond 8 "a" Is [], group 7 Any [ cond 6 "b" Is [], cond 5 "c" Is [] ] ])) |> Result.map ids)
        , check "a condition as the root gets the id 0" (Ok 0) (decoded (conditionJson "empty") |> Result.map Rule.idOf)
        , check "groups nested 32 deep are read" (Ok 32) (decoded (nested 32) |> Result.map Rule.depth)
        , check "groups nested 33 deep are refused" True (isError (decoded (nested 33)))
        , check "groups nested 1000 deep are refused, not a stack overflow" True (isError (decoded (nested 1000)))
        , check "reading and writing again gives the same text" (encoded sampleRule) (decoded (encoded sampleRule) |> Result.map encoded |> Result.withDefault "failed")
        , check "the rule that was read equals the rule that was written, up to the ids" (Ok (stripIds sampleRule)) (decoded (encoded sampleRule) |> Result.map stripIds)
        , check "the ids of the rule that was read are the ones the editor would use" (Ok [ 0, 1, 2, 3, 4 ]) (decoded (encoded sampleRule) |> Result.map ids)
        , check "special characters survive" (Ok (cond 0 "ø\"é\\" Is [ "a\nb", "😀", "\u{0001}" ])) (decoded (encoded (cond 5 "ø\"é\\" Is [ "a\nb", "😀", "\u{0001}" ])))
        ]


{-| The operator key inside the JSON of a condition.
-}
operatorKeyIn : String -> String
operatorKeyIn json =
    json
        |> String.split "\"operator\":\""
        |> List.drop 1
        |> List.head
        |> Maybe.andThen (String.split "\"" >> List.head)
        |> Maybe.withDefault "?"



-- PROPERTIES


fieldIdFuzzer : Fuzzer String
fieldIdFuzzer =
    Fuzz.oneOfValues [ "customer", "total", "created", "status", "express", "nope", "" ]


valueFuzzer : Fuzzer String
valueFuzzer =
    Fuzz.oneOf
        [ Fuzz.oneOfValues [ "", " ", "0", "10", "52", "10,5", "-3", "abc", "2026-10-20", "2026-02-30", "paid", "open", "Acme", "ø", "1e3", "999999999999", "3", "  ost  ", "--" ]
        , Fuzz.string
        ]


operatorFuzzer : Fuzzer Operator
operatorFuzzer =
    Fuzz.oneOfValues allOperators


conditionFuzzer : Fuzzer Rule
conditionFuzzer =
    Fuzz.map3 (\field operator values -> ConditionRule { id = 0, field = field, operator = operator, values = values })
        fieldIdFuzzer
        operatorFuzzer
        (Fuzz.listOfLengthBetween 0 3 valueFuzzer)


ruleFuzzer : Int -> Fuzzer Rule
ruleFuzzer levels =
    if levels <= 0 then
        conditionFuzzer

    else
        Fuzz.frequency
            [ ( 3, conditionFuzzer )
            , ( 2
              , Fuzz.map3 (\combinator negated children -> GroupRule { id = 0, combinator = combinator, negated = negated, children = children })
                    (Fuzz.oneOfValues [ All, Any ])
                    Fuzz.bool
                    (Fuzz.listOfLengthBetween 0 4 (Fuzz.lazy (\_ -> ruleFuzzer (levels - 1))))
              )
            ]


{-| A group, as the editor makes it: any rule with a group at the root.
-}
rootFuzzer : Fuzzer Rule
rootFuzzer =
    Fuzz.map3 (\combinator negated children -> GroupRule { id = 0, combinator = combinator, negated = negated, children = children })
        (Fuzz.oneOfValues [ All, Any ])
        Fuzz.bool
        (Fuzz.listOfLengthBetween 0 4 (ruleFuzzer 3))


rowFuzzer : Fuzzer Order
rowFuzzer =
    Fuzz.map6 Order
        (Fuzz.oneOf [ Fuzz.constant "ORD-1", Fuzz.string ])
        (Fuzz.oneOf [ Fuzz.oneOfValues [ "Acme", "ost", "Østby", "" ], Fuzz.string ])
        (Fuzz.oneOfValues [ "", "paid", "open", "void" ])
        (Fuzz.maybe (Fuzz.oneOf [ Fuzz.oneOfValues [ 0, 3, 10, 10.5, -3, 52, 1.0e12 ], Fuzz.float ]))
        (Fuzz.maybe (Fuzz.map (\n -> Date.fromEpochDay (n + 739000)) (Fuzz.intRange -4000 4000)))
        Fuzz.bool


{-| One edit of a rule, aimed at a node by its place in the list of nodes.
-}
type Edit
    = AddCondition Int
    | AddGroup Int
    | Duplicate Int
    | MoveNode Int Int
    | RemoveNode Int
    | SetField Int String
    | SetOperator Int Operator
    | SetValue Int Int String
    | AddValue Int String
    | RemoveValue Int String
    | SetCombinator Int Combinator
    | ToggleNegated Int


editFuzzer : Fuzzer Edit
editFuzzer =
    let
        pick =
            Fuzz.intRange 0 40
    in
    Fuzz.frequency
        [ ( 4, Fuzz.map AddCondition pick )
        , ( 2, Fuzz.map AddGroup pick )
        , ( 2, Fuzz.map Duplicate pick )
        , ( 3, Fuzz.map2 MoveNode pick (Fuzz.oneOfValues [ -1, 1 ]) )
        , ( 2, Fuzz.map RemoveNode pick )
        , ( 2, Fuzz.map2 SetField pick fieldIdFuzzer )
        , ( 2, Fuzz.map2 SetOperator pick operatorFuzzer )
        , ( 2, Fuzz.map3 SetValue pick (Fuzz.intRange 0 3) valueFuzzer )
        , ( 1, Fuzz.map2 AddValue pick valueFuzzer )
        , ( 1, Fuzz.map2 RemoveValue pick valueFuzzer )
        , ( 1, Fuzz.map2 SetCombinator pick (Fuzz.oneOfValues [ All, Any ]) )
        , ( 1, Fuzz.map ToggleNegated pick )
        ]


nth : Int -> List a -> Maybe a
nth index items =
    if List.isEmpty items then
        Nothing

    else
        items |> List.drop (modBy (List.length items) index) |> List.head


apply : Edit -> Rule -> Rule
apply edit rule =
    let
        node index =
            nth index (ids rule) |> Maybe.withDefault 0

        groupNode index =
            nth index (groupIds rule) |> Maybe.withDefault 0
    in
    case edit of
        AddCondition index ->
            Rule.addCondition fields (groupNode index) rule

        AddGroup index ->
            Rule.addGroup (groupNode index) rule

        Duplicate index ->
            Rule.duplicate (node index) rule

        MoveNode index delta ->
            Rule.move (node index) delta rule

        RemoveNode index ->
            Rule.remove (node index) rule

        SetField index fieldId ->
            Rule.setField fields (node index) fieldId rule

        SetOperator index operator ->
            Rule.setOperator (node index) operator rule

        SetValue index at text ->
            Rule.setValue (node index) at text rule

        AddValue index text ->
            Rule.addValue (node index) text rule

        RemoveValue index text ->
            Rule.removeValue (node index) text rule

        SetCombinator index combinator ->
            Rule.setCombinator (groupNode index) combinator rule

        ToggleNegated index ->
            Rule.toggleNegated (groupNode index) rule


edited : List Edit -> Rule
edited edits =
    List.foldl apply Rule.emptyGroup edits


isGroupWithId0 : Rule -> Bool
isGroupWithId0 rule =
    case rule of
        GroupRule g ->
            g.id == 0

        ConditionRule _ ->
            False


propertyTests : Test
propertyTests =
    describe "properties"
        [ fuzz (Fuzz.list editFuzzer) "ids stay unique through any sequence of edits" <|
            \edits ->
                allUnique (ids (edited edits))
                    |> Expect.equal True
        , fuzz (Fuzz.list editFuzzer) "the root stays a group with the id 0 through any sequence of edits" <|
            \edits ->
                isGroupWithId0 (edited edits)
                    |> Expect.equal True
        , fuzz (Fuzz.list editFuzzer) "nextId is bigger than every id" <|
            \edits ->
                let
                    rule =
                        edited edits
                in
                List.all (\id -> id < Rule.nextId rule) (ids rule)
                    |> Expect.equal True
        , fuzz (Fuzz.list editFuzzer) "a rule that was edited can be written and read again" <|
            \edits ->
                let
                    rule =
                        edited edits
                in
                Encode.encode 0 (Rule.encode rule)
                    |> Decode.decodeString Rule.decoder
                    |> Result.map stripIds
                    |> Expect.equal (Ok (stripIds rule))
        , fuzz (Fuzz.list editFuzzer) "validate gives each node at most one issue" <|
            \edits ->
                Rule.validate Locale.en fields (edited edits)
                    |> List.map .nodeId
                    |> allUnique
                    |> Expect.equal True
        , fuzz2 (Fuzz.list editFuzzer) (Fuzz.intRange 0 40) "removing a node removes exactly its subtree and keeps the root" <|
            \edits index ->
                let
                    rule =
                        edited edits

                    target =
                        nth index (ids rule) |> Maybe.withDefault 0

                    removed =
                        Rule.remove target rule

                    expectedSize =
                        if target == 0 then
                            nodeCount rule

                        else
                            nodeCount rule - (findNode target rule |> Maybe.map nodeCount |> Maybe.withDefault 0)
                in
                Expect.all
                    [ \r -> Expect.equal True (isGroupWithId0 r)
                    , \r -> Expect.equal expectedSize (nodeCount r)
                    , \r -> Expect.equal True (allUnique (ids r))
                    , \r -> Expect.equal True (List.all (\id -> List.member id (ids rule)) (ids r))
                    , \r -> Expect.equal True (Rule.depth r >= 1)
                    ]
                    removed
        , fuzz2 (Fuzz.listOfLengthBetween 1 5 conditionFuzzer) rowFuzzer "removing a condition from an 'all' group never makes it match fewer rows" <|
            \conditions row ->
                let
                    before =
                        group 0 All (List.indexedMap (\i c -> withId (i + 1) c) conditions)

                    after =
                        Rule.remove 1 before
                in
                if Rule.matches today fields before row then
                    Expect.equal True (Rule.matches today fields after row)

                else
                    Expect.pass
        , fuzz2 (Fuzz.list editFuzzer) (Fuzz.intRange 0 40) "duplicating a node copies exactly its subtree and keeps the ids unique" <|
            \edits index ->
                let
                    rule =
                        edited edits

                    target =
                        nth index (ids rule) |> Maybe.withDefault 0

                    copied =
                        Rule.duplicate target rule

                    subtree =
                        findNode target rule |> Maybe.map nodeCount |> Maybe.withDefault 0

                    expectedSize =
                        if target == 0 then
                            nodeCount rule

                        else
                            nodeCount rule + subtree
                in
                Expect.all
                    [ \r -> Expect.equal expectedSize (nodeCount r)
                    , \r -> Expect.equal True (allUnique (ids r))
                    , \r ->
                        Expect.equal
                            (Rule.conditionCount rule
                                + (if target == 0 then
                                    0

                                   else
                                    findNode target rule |> Maybe.map Rule.conditionCount |> Maybe.withDefault 0
                                  )
                            )
                            (Rule.conditionCount r)
                    ]
                    copied
        , fuzz2 (Fuzz.list editFuzzer) (Fuzz.intRange 0 40) "moving a node one step keeps every node, only the order changes" <|
            \edits index ->
                let
                    rule =
                        edited edits

                    target =
                        nth index (ids rule) |> Maybe.withDefault 0
                in
                [ -1, 1 ]
                    |> List.map (\delta -> List.sort (ids (Rule.move target delta rule)))
                    |> Expect.equal [ List.sort (ids rule), List.sort (ids rule) ]
        , fuzz2 (Fuzz.list editFuzzer) (Fuzz.intRange 0 40) "moving down and then up again restores the rule" <|
            \edits index ->
                let
                    rule =
                        edited edits

                    target =
                        nth index (ids rule) |> Maybe.withDefault 0
                in
                -- the node stays where it is only when it has a neighbour to swap with;
                -- at the end of its group the first move does nothing and the second moves it
                if Rule.move target 1 rule == rule then
                    Expect.pass

                else
                    Expect.equal rule (rule |> Rule.move target 1 |> Rule.move target -1)
        , -- See "move" above: a delta of 0 or of more than one step used to corrupt the tree.
          fuzz2 (Fuzz.list editFuzzer) (Fuzz.pair (Fuzz.intRange 0 40) (Fuzz.intRange -4 4)) "moving a node by any delta keeps every node" <|
            \edits ( index, delta ) ->
                let
                    rule =
                        edited edits

                    target =
                        nth index (ids rule) |> Maybe.withDefault 0
                in
                Expect.equal (List.sort (ids rule)) (List.sort (ids (Rule.move target delta rule)))
        , fuzz2 rootFuzzer rowFuzzer "evaluating any rule on any row gives an answer" <|
            \rule row ->
                let
                    answer =
                        Rule.matches today fields rule row
                in
                Expect.equal True (answer || not answer)
        , fuzz rootFuzzer "describing and validating any rule gives an answer" <|
            \rule ->
                Expect.equal True
                    (String.length (Rule.describe Locale.en fields rule) > 0 && String.length (Rule.describe Locale.nb fields rule) > 0 && List.length (Rule.validate Locale.en fields rule) >= 0)
        , fuzz2 rootFuzzer rowFuzzer "a rule with only incomplete or unknown conditions lets every row through" <|
            \rule row ->
                let
                    broken =
                        breakAll rule
                in
                Rule.matches today fields broken row
                    |> Expect.equal True
        , fuzz2 conditionFuzzer rowFuzzer "negating a group of one active condition gives the opposite answer" <|
            \condition row ->
                let
                    plain =
                        group 0 All [ condition ]

                    negated =
                        notGroup 0 All [ condition ]

                    active =
                        isActiveIn condition
                in
                if active then
                    Expect.notEqual (Rule.matches today fields plain row) (Rule.matches today fields negated row)

                else
                    Expect.equal True (Rule.matches today fields negated row)
        , fuzz2 (Fuzz.pair conditionFuzzer conditionFuzzer) rowFuzzer "'all' is the conjunction and 'any' the disjunction of the active conditions" <|
            \( a, b ) row ->
                let
                    answer rule =
                        Rule.matches today fields rule row

                    both =
                        List.filter isActiveIn [ a, b ]

                    expectedAll =
                        List.all (\c -> answer c) both

                    expectedAny =
                        List.isEmpty both || List.any (\c -> answer c) both
                in
                Expect.equal ( expectedAll, expectedAny ) ( answer (group 0 All [ a, b ]), answer (group 0 Any [ a, b ]) )
        , fuzz rootFuzzer "writing and reading any rule gives the same rule, up to the ids" <|
            \rule ->
                Encode.encode 0 (Rule.encode rule)
                    |> Decode.decodeString Rule.decoder
                    |> Result.map stripIds
                    |> Expect.equal (Ok (stripIds rule))
        , fuzz rootFuzzer "writing and reading any rule numbers the nodes from the top down" <|
            \rule ->
                Encode.encode 0 (Rule.encode rule)
                    |> Decode.decodeString Rule.decoder
                    |> Result.map ids
                    |> Expect.equal (Ok (List.range 0 (nodeCount rule - 1)))
        , fuzz rootFuzzer "the JSON text of a rule that was read again is the same text" <|
            \rule ->
                let
                    text =
                        Encode.encode 0 (Rule.encode rule)
                in
                Decode.decodeString Rule.decoder text
                    |> Result.map (\again -> Encode.encode 0 (Rule.encode again))
                    |> Expect.equal (Ok text)
        , fuzz2 rootFuzzer rowFuzzer "a rule that was read again matches the same rows" <|
            \rule row ->
                Encode.encode 0 (Rule.encode rule)
                    |> Decode.decodeString Rule.decoder
                    |> Result.map (\again -> Rule.matches today fields again row)
                    |> Expect.equal (Ok (Rule.matches today fields rule row))
        , fuzz Fuzz.string "reading any text as a rule never crashes" <|
            \text ->
                case Decode.decodeString Rule.decoder text of
                    Ok rule ->
                        Expect.equal True (Rule.depth rule >= 0)

                    Err _ ->
                        Expect.pass
        , fuzz Fuzz.string "parseNumber never crashes and a number is never NaN" <|
            \text ->
                case Rule.parseNumber text of
                    Just n ->
                        Expect.equal False (isNaN n)

                    Nothing ->
                        Expect.pass
        ]


withId : Int -> Rule -> Rule
withId id rule =
    case rule of
        ConditionRule condition ->
            ConditionRule { condition | id = id }

        GroupRule g ->
            GroupRule { g | id = id }


{-| Is this condition one that `matches` takes into account?
-}
isActiveIn : Rule -> Bool
isActiveIn rule =
    case rule of
        ConditionRule condition ->
            Rule.fieldById fields condition.field
                |> Maybe.map (\field -> Rule.isComplete field condition)
                |> Maybe.withDefault False

        GroupRule _ ->
            False


{-| The same tree with every condition on a field that does not exist, or with
an operand that cannot be read, so that none of them takes part.
-}
breakAll : Rule -> Rule
breakAll rule =
    case rule of
        ConditionRule condition ->
            ConditionRule { condition | field = "no such field" }

        GroupRule g ->
            GroupRule { g | children = List.map breakAll g.children }
