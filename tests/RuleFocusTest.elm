module RuleFocusTest exposing (suite)

{-| The focus of the rule builder: `RuleBuilder.focusId` names a control that is
on screen for every kind of node, `issues` is what the builder itself would
show, and the container of the builder can take the focus.
-}

import Expect
import Html.Attributes
import Klar.Locale as Locale
import Klar.Rule as Rule exposing (Combinator(..), Operator(..), Rule(..))
import Klar.RuleBuilder as RuleBuilder
import Test exposing (Test, describe, test)
import Test.Html.Query as Query
import Test.Html.Selector as Selector


type Msg
    = BuilderMsg RuleBuilder.Msg


fields : List (Rule.Field ())
fields =
    [ Rule.numberField "quantity" "Quantity" (always Nothing)
    , Rule.textField "name" "Name" (always "")
    ]


condition : Int -> String -> Operator -> List String -> Rule
condition id field operator values =
    ConditionRule { id = id, field = field, operator = operator, values = values }


rootOf : List Rule -> Rule
rootOf children =
    GroupRule { id = 0, combinator = All, negated = False, children = children }


stateWith : Rule -> RuleBuilder.State
stateWith rule =
    RuleBuilder.init "pr" |> RuleBuilder.setRule rule


{-| A rule with a lone group, an unfinished condition, a number that cannot be
read, a finished condition and one that needs no value.
-}
sample : Rule
sample =
    rootOf
        [ condition 1 "" Is []
        , condition 2 "quantity" GreaterThan [ "many" ]
        , condition 3 "quantity" GreaterThan [ "10" ]
        , condition 4 "name" IsEmpty []
        , GroupRule { id = 5, combinator = Any, negated = False, children = [] }
        ]


drawn : RuleBuilder.State -> Query.Single Msg
drawn state =
    RuleBuilder.view BuilderMsg [ RuleBuilder.fields fields ] state
        |> Query.fromHtml


suite : Test
suite =
    describe "the focus of the rule builder"
        [ describe "focusId"
            [ test "a condition without a field leads to the field picker" <|
                \_ -> RuleBuilder.focusId fields (stateWith sample) 1 |> Expect.equal "pr-n1-field"
            , test "a condition that needs a value leads to the first value" <|
                \_ -> RuleBuilder.focusId fields (stateWith sample) 2 |> Expect.equal "pr-n2-v0"
            , test "a condition that takes no value leads to the operator" <|
                \_ -> RuleBuilder.focusId fields (stateWith sample) 4 |> Expect.equal "pr-n4-op"
            , test "a group leads to its add button" <|
                \_ -> RuleBuilder.focusId fields (stateWith sample) 5 |> Expect.equal "pr-n5-add-rule"
            , test "the root group leads to its add button" <|
                \_ -> RuleBuilder.focusId fields (stateWith sample) 0 |> Expect.equal "pr-n0-add-rule"
            , test "a node that is not there leads to the add button of the rule" <|
                \_ -> RuleBuilder.focusId fields (stateWith sample) 99 |> Expect.equal "pr-n0-add-rule"
            , test "every id it gives is an element of the page" <|
                \_ ->
                    let
                        state =
                            stateWith sample
                    in
                    Expect.all
                        (List.map
                            (\node -> \_ -> drawn state |> Query.has [ Selector.id (RuleBuilder.focusId fields state node) ])
                            [ 0, 1, 2, 3, 4, 5 ]
                        )
                        ()
            ]
        , describe "issues"
            [ test "they name the nodes with a problem, one each, in the language asked for" <|
                \_ ->
                    RuleBuilder.issues Locale.en fields (stateWith sample)
                        |> List.map (\issue -> ( issue.nodeId, issue.message ))
                        |> Expect.equal
                            [ ( 1, "Choose a field" )
                            , ( 2, "Enter a valid number" )
                            , ( 5, "The group is empty" )
                            ]
            , test "a rule that is fine has none" <|
                \_ ->
                    RuleBuilder.issues Locale.en fields (stateWith (rootOf [ condition 1 "quantity" GreaterThan [ "10" ] ]))
                        |> Expect.equal []
            ]
        , describe "the container"
            [ test "can take the focus, so a problem that points at the builder as a whole has somewhere to go" <|
                \_ ->
                    drawn (stateWith sample)
                        |> Query.has [ Selector.id "pr", Selector.attribute (Html.Attributes.tabindex -1) ]
            ]
        ]
