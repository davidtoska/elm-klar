module RuleBuildersTest exposing (suite)

{-| The small constructors for rules written by hand: the nodes are numbered from the top down.
-}

import Expect
import Klar.Rule as Rule exposing (Combinator(..), Operator(..), Rule(..))
import Test exposing (Test, describe, test)


suite : Test
suite =
    describe "Klar.Rule constructors"
        [ test "is is a condition with one operand" <|
            \_ ->
                Rule.is "status" "open"
                    |> Expect.equal (ConditionRule { id = 0, field = "status", operator = Is, values = [ "open" ] })
        , test "allOf numbers the nodes from the top down" <|
            \_ ->
                Rule.allOf [ Rule.is "status" "open", Rule.anyOf [ Rule.isAnyOf "kind" [ "a", "b" ], Rule.when "total" GreaterOrEqual [ "10" ] ] ]
                    |> Expect.equal
                        (GroupRule
                            { id = 0
                            , combinator = All
                            , negated = False
                            , children =
                                [ ConditionRule { id = 1, field = "status", operator = Is, values = [ "open" ] }
                                , GroupRule
                                    { id = 2
                                    , combinator = Any
                                    , negated = False
                                    , children =
                                        [ ConditionRule { id = 3, field = "kind", operator = IsAnyOf, values = [ "a", "b" ] }
                                        , ConditionRule { id = 4, field = "total", operator = GreaterOrEqual, values = [ "10" ] }
                                        ]
                                    }
                                ]
                            }
                        )
        , test "the same rule as the hand-written records, so saved views keep their meaning" <|
            \_ ->
                Rule.allOf [ Rule.is "status" "open" ]
                    |> Expect.equal
                        (GroupRule { id = 0, combinator = All, negated = False, children = [ ConditionRule { id = 1, field = "status", operator = Is, values = [ "open" ] } ] })
        , test "an empty allOf is the empty rule up to the combinator" <|
            \_ ->
                Rule.allOf [] |> Expect.equal Rule.emptyGroup
        ]
