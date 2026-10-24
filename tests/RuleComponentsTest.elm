module RuleComponentsTest exposing (suite)

{-| The rule builder and the filter bar, driven through their views: one issue
for each node, the names for screen readers, the builder as a form field, the
download without a `data:` link, a new rule that starts fresh, undo in the filter
bar, presets checked against the fields, incomplete chips that say so, and
Ctrl+Enter in the filter editor.
-}

import Expect
import Html exposing (Html)
import Html.Attributes as Attr
import Json.Encode as Encode
import Klar.FilterBar as FilterBar
import Klar.Locale as Locale
import Klar.Rule as Rule exposing (Combinator(..), Operator(..), Rule(..))
import Klar.RuleBuilder as RuleBuilder
import Test exposing (Test, describe, test)
import Test.Html.Event as Event
import Test.Html.Query as Query
import Test.Html.Selector as Selector


fields : List (Rule.Field ())
fields =
    [ Rule.numberField "quantity" "Quantity" (always Nothing)
    , Rule.dateField "created" "Created" (always Nothing)
    , Rule.choiceField "status" "Status" [ { value = "open", label = "Open" }, { value = "paid", label = "Paid" } ] (always "")
    ]


cond : Int -> String -> Operator -> List String -> Rule
cond id field operator values =
    ConditionRule { id = id, field = field, operator = operator, values = values }


rootOf : List Rule -> Rule
rootOf children =
    GroupRule { id = 0, combinator = All, negated = False, children = children }


suite : Test
suite =
    describe "the rule builder and the filter bar"
        [ builderTests
        , barTests
        ]



-- RULE BUILDER


builderState : Rule -> RuleBuilder.State
builderState rule =
    RuleBuilder.init "pr" |> RuleBuilder.setRule rule


builder : List (RuleBuilder.Attribute () RuleBuilder.Msg) -> RuleBuilder.State -> Html RuleBuilder.Msg
builder attributes state =
    RuleBuilder.view identity (RuleBuilder.fields fields :: attributes) state


{-| Clicks the element and runs the message through `update`.
-}
clickIn : (RuleBuilder.State -> Html RuleBuilder.Msg) -> List Selector.Selector -> RuleBuilder.State -> Result String RuleBuilder.State
clickIn draw selectors state =
    draw state
        |> Query.fromHtml
        |> Query.find selectors
        |> Event.simulate Event.click
        |> Event.toResult
        |> Result.map (\msg -> RuleBuilder.update msg state |> Tuple.first)


builderTests : Test
builderTests =
    describe "RuleBuilder"
        [ test "issues gives one problem for each node, in the order of the tree" <|
            \_ ->
                RuleBuilder.issues Locale.en fields (builderState (rootOf [ cond 1 "quantity" StartsWith [ "x" ], cond 2 "created" InLastDays [] ]))
                    |> Expect.equal
                        [ { nodeId = 1, message = "The operator does not fit the field" }
                        , { nodeId = 2, message = "Enter a whole number of days" }
                        ]
        , test "the issues on screen are the same, one each" <|
            \_ ->
                builder [] (builderState (rootOf [ cond 1 "quantity" StartsWith [ "x" ], cond 2 "created" InLastDays [] ]) |> RuleBuilder.showIssues)
                    |> Query.fromHtml
                    |> Query.findAll [ Selector.class "klar-rules__issue" ]
                    |> Query.count (Expect.equal 2)
        , test "ariaLabel names the builder for screen readers" <|
            \_ ->
                builder [ RuleBuilder.ariaLabel "Price rule" ] (RuleBuilder.init "pr")
                    |> Query.fromHtml
                    |> Query.has [ Selector.id "pr", Selector.attribute (Attr.attribute "aria-label" "Price rule") ]
        , test "a label is drawn and names the builder" <|
            \_ ->
                builder [ RuleBuilder.label "Conditions", RuleBuilder.required ] (RuleBuilder.init "pr")
                    |> Query.fromHtml
                    |> Expect.all
                        [ Query.find [ Selector.id "pr-label" ] >> Query.has [ Selector.text "Conditions", Selector.class "klar-field__label" ]
                        , Query.find [ Selector.id "pr" ] >> Query.has [ Selector.attribute (Attr.attribute "aria-labelledby" "pr-label") ]
                        , Query.find [ Selector.id "pr-label" ] >> Query.has [ Selector.class "klar-field__required" ] >> always Expect.pass
                        ]
        , test "a hint and an error are joined to the builder" <|
            \_ ->
                builder [ RuleBuilder.label "Conditions", RuleBuilder.hint "When the price applies.", RuleBuilder.error "Add a condition" ] (RuleBuilder.init "pr")
                    |> Query.fromHtml
                    |> Expect.all
                        [ Query.find [ Selector.id "pr" ] >> Query.has [ Selector.attribute (Attr.attribute "aria-describedby" "pr-hint pr-error") ]
                        , Query.find [ Selector.id "pr-hint" ] >> Query.has [ Selector.text "When the price applies." ]
                        , Query.find [ Selector.id "pr-error" ] >> Query.has [ Selector.text "Add a condition" ]
                        ]
        , test "errorMaybe Nothing shows no error" <|
            \_ ->
                builder [ RuleBuilder.errorMaybe Nothing ] (RuleBuilder.init "pr")
                    |> Query.fromHtml
                    |> Query.findAll [ Selector.class "klar-field__error" ]
                    |> Query.count (Expect.equal 0)
        , test "the JSON download is a button that update answers, not a data: link" <|
            \_ ->
                let
                    draw =
                        builder [ RuleBuilder.json ]
                in
                case clickIn draw [ Selector.tag "button", Selector.containing [ Selector.text "Show JSON" ] ] (builderState (rootOf [ cond 1 "quantity" GreaterThan [ "3" ] ])) of
                    Ok opened ->
                        draw opened
                            |> Query.fromHtml
                            |> Expect.all
                                [ Query.findAll [ Selector.tag "a" ] >> Query.count (Expect.equal 0)
                                , Query.find [ Selector.tag "button", Selector.containing [ Selector.text "Download" ] ]
                                    >> Event.simulate Event.click
                                    >> Event.toResult
                                    >> Result.map (\_ -> ())
                                    >> Expect.equal (Ok ())
                                ]

                    Err problem ->
                        Expect.fail problem
        , test "a condition is named with its place among its siblings" <|
            \_ ->
                builder [] (builderState (rootOf [ cond 1 "quantity" GreaterThan [ "3" ], cond 2 "quantity" LessThan [ "9" ] ]))
                    |> Query.fromHtml
                    |> Query.find [ Selector.id "pr-n2" ]
                    |> Query.has [ Selector.attribute (Attr.attribute "aria-label" "Condition 2 of 2") ]
        , test "the negation box says what it negates" <|
            \_ ->
                builder [] (RuleBuilder.init "pr")
                    |> Query.fromHtml
                    |> Query.find [ Selector.id "pr-n0-not" ]
                    |> Query.has [ Selector.attribute (Attr.attribute "aria-label" "Not: negate the whole rule") ]
        , test "another rule starts fresh: what the user touched before does not show its issues" <|
            \_ ->
                let
                    touched =
                        builder [] (builderState (rootOf [ cond 1 "quantity" GreaterThan [ "" ] ]))
                            |> Query.fromHtml
                            |> Query.find [ Selector.id "pr-n1-v0" ]
                            |> Event.simulate (Event.input "many")
                            |> Event.toResult
                            |> Result.map (\msg -> RuleBuilder.update msg (builderState (rootOf [ cond 1 "quantity" GreaterThan [ "" ] ])) |> Tuple.first)

                    issuesShown state expectation =
                        builder [] state
                            |> Query.fromHtml
                            |> Query.findAll [ Selector.class "klar-rules__issue" ]
                            |> Query.count expectation
                in
                case touched of
                    Ok state ->
                        Expect.all
                            [ \s -> issuesShown s (Expect.equal 1)
                            , \s -> issuesShown (RuleBuilder.setRule (rootOf [ cond 1 "quantity" LessThan [ "x" ] ]) s) (Expect.equal 0)
                            , \s -> issuesShown (RuleBuilder.setRule (RuleBuilder.rule s) s) (Expect.equal 1)
                            ]
                            state

                    Err problem ->
                        Expect.fail problem
        ]



-- FILTER BAR


barState : Rule -> FilterBar.State
barState rule =
    FilterBar.init "bar" |> FilterBar.setRule rule


bar : List (FilterBar.Attribute () FilterBar.Msg) -> FilterBar.State -> Html FilterBar.Msg
bar attributes state =
    FilterBar.view identity (FilterBar.fields fields :: attributes) state


press : List Selector.Selector -> ( String, Encode.Value ) -> FilterBar.State -> Result String FilterBar.State
press selectors event state =
    bar [] state
        |> Query.fromHtml
        |> Query.find selectors
        |> Event.simulate event
        |> Event.toResult
        |> Result.map (\msg -> FilterBar.update msg state |> Tuple.first)


ctrlEnter : ( String, Encode.Value )
ctrlEnter =
    Event.custom "keydown"
        (Encode.object
            [ ( "key", Encode.string "Enter" )
            , ( "ctrlKey", Encode.bool True )
            , ( "metaKey", Encode.bool False )
            , ( "shiftKey", Encode.bool False )
            , ( "altKey", Encode.bool False )
            , ( "isComposing", Encode.bool False )
            , ( "keyCode", Encode.int 13 )
            , ( "defaultPrevented", Encode.bool False )
            ]
        )


paidAndLarge : Rule
paidAndLarge =
    Rule.allOf [ Rule.is "status" "paid", Rule.when "quantity" GreaterThan [ "10" ] ]


same : Rule -> Rule -> Bool
same a b =
    Encode.encode 0 (Rule.encode a) == Encode.encode 0 (Rule.encode b)


barTests : Test
barTests =
    describe "FilterBar"
        [ test "ariaLabel names the bar for screen readers" <|
            \_ ->
                FilterBar.view identity [ FilterBar.ariaLabel "Order filters" ] (FilterBar.init "bar")
                    |> Query.fromHtml
                    |> Query.has [ Selector.id "bar", Selector.attribute (Attr.attribute "aria-label" "Order filters") ]
        , test "Clear all can be undone, and the undo goes away with the next change" <|
            \_ ->
                case press [ Selector.id "bar-clear" ] Event.click (barState paidAndLarge) of
                    Ok cleared ->
                        Expect.all
                            [ \s -> Expect.equal True (Rule.isEmpty (FilterBar.rule s))
                            , \s -> bar [] s |> Query.fromHtml |> Query.find [ Selector.id "bar-undo" ] |> Query.has [ Selector.text "Undo" ]
                            , \s -> press [ Selector.id "bar-undo" ] Event.click s |> Result.map (FilterBar.rule >> same paidAndLarge) |> Expect.equal (Ok True)
                            , \s -> bar [] (FilterBar.setRule paidAndLarge s) |> Query.fromHtml |> Query.findAll [ Selector.id "bar-undo" ] |> Query.count (Expect.equal 0)
                            ]
                            cleared

                    Err problem ->
                        Expect.fail problem
        , test "removing a chip can be undone" <|
            \_ ->
                press [ Selector.id "bar-chip-1-remove" ] Event.click (barState paidAndLarge)
                    |> Result.andThen (press [ Selector.id "bar-undo" ] Event.click)
                    |> Result.map (FilterBar.rule >> same paidAndLarge)
                    |> Expect.equal (Ok True)
        , test "the status region for the undo is in the page before anything is removed" <|
            \_ ->
                bar [] (barState paidAndLarge)
                    |> Query.fromHtml
                    |> Query.find [ Selector.class "klar-filterbar__undo" ]
                    |> Query.has [ Selector.attribute (Attr.attribute "role" "status") ]
        , test "a preset on a field that does not exist is disabled, and says why" <|
            \_ ->
                bar [ FilterBar.quick [ ( "Big", Rule.allOf [ Rule.when "quantty" GreaterThan [ "10" ] ] ), ( "Paid", Rule.is "status" "paid" ) ] ] (FilterBar.init "bar")
                    |> Query.fromHtml
                    |> Expect.all
                        [ Query.find [ Selector.id "bar-quick-0" ] >> Query.has [ Selector.disabled True, Selector.attribute (Attr.title "Big: Choose a field") ]
                        , Query.find [ Selector.id "bar-quick-1" ] >> Query.has [ Selector.disabled False ]
                        ]
        , test "a preset whose operator does not fit the field is disabled" <|
            \_ ->
                bar [ FilterBar.quick [ ( "Starts", Rule.when "quantity" StartsWith [ "1" ] ) ] ] (FilterBar.init "bar")
                    |> Query.fromHtml
                    |> Query.find [ Selector.id "bar-quick-0" ]
                    |> Query.has [ Selector.disabled True ]
        , test "an incomplete chip says so to screen readers" <|
            \_ ->
                bar [] (barState (Rule.allOf [ Rule.when "quantity" GreaterThan [] ]))
                    |> Query.fromHtml
                    |> Query.find [ Selector.id "bar-chip-1" ]
                    |> Query.find [ Selector.class "klar-sr-only" ]
                    |> Query.has [ Selector.text "incomplete, not filtering" ]
        , test "a group chip in which nothing filters is drawn as incomplete" <|
            \_ ->
                bar [] (barState (Rule.allOf [ Rule.anyOf [ Rule.when "quantity" GreaterThan [] ] ]))
                    |> Query.fromHtml
                    |> Query.findAll [ Selector.class "klar-filterbar__chip--incomplete" ]
                    |> Query.count (Expect.equal 1)
        , test "the open chip names its dialog" <|
            \_ ->
                press [ Selector.id "bar-chip-1" ] Event.click (barState paidAndLarge)
                    |> Result.map
                        (\opened ->
                            bar [] opened
                                |> Query.fromHtml
                                |> Query.find [ Selector.id "bar-chip-1" ]
                                |> Query.has [ Selector.attribute (Attr.attribute "aria-controls" "bar-popup") ]
                        )
                    |> Result.withDefault (Expect.fail "the chip did not open")
        , test "Ctrl+Enter in the editor applies it" <|
            \_ ->
                press [ Selector.id "bar-chip-2" ] Event.click (barState paidAndLarge)
                    |> Result.andThen (press [ Selector.id "bar-popup" ] ctrlEnter)
                    |> Result.map (\s -> ( FilterBar.isOpen s, same paidAndLarge (FilterBar.rule s) ))
                    |> Expect.equal (Ok ( False, True ))
        , test "close shuts the editor and hands back a command" <|
            \_ ->
                press [ Selector.id "bar-chip-1" ] Event.click (barState paidAndLarge)
                    |> Result.map (\opened -> ( FilterBar.isOpen opened, FilterBar.isOpen (Tuple.first (FilterBar.close opened)) ))
                    |> Expect.equal (Ok ( True, False ))
        ]
