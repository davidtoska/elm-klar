module FormRulesTest exposing (suite)

{-| A rule builder inside the rows of a form (`Spec.conditions`): the price rules
of a supplier, each with the conditions it holds under and the discount it gives.
The form owns adding and removing them, the dirty flag, their problems and where
the summary leads, and `Form.problemInRow` maps the server's position to a row.
-}

import Expect
import Html exposing (Html)
import Klar.Form as Form
import Klar.Form.Check as Check
import Klar.Form.Spec as Spec
import Klar.Locale as Locale
import Klar.Rule as Rule exposing (Combinator(..), Operator(..), Rule(..))
import Klar.RuleBuilder as RuleBuilder
import Test exposing (Test, describe, test)
import Test.Html.Event as Event
import Test.Html.Query as Query
import Test.Html.Selector as Selector


type Step
    = Info
    | Pricing
    | Review


type alias PriceFields =
    { conditions : Form.Field Rule.Rule
    , discount : Form.Field (Maybe Float)
    }


type alias PriceRule =
    { condition : Rule.Rule
    , discount : Float
    }


ruleFields : List (Rule.Field ())
ruleFields =
    [ Rule.numberField "quantity" "Quantity" (always Nothing)
    , Rule.textField "category" "Category" (always "")
    ]


priceRule : Form.Form () PriceFields PriceRule
priceRule =
    Spec.define "price-rule" PriceFields PriceRule
        |> Spec.with (Spec.conditions "Conditions" ruleFields |> Spec.required |> Spec.withMessage (\_ -> "Add a condition"))
        |> Spec.with (Spec.number "Discount" |> Spec.required |> Spec.range 1 100)
        |> Spec.build


type alias Fields =
    { name : Form.Field String
    , rules : Form.Field (Form.Rows PriceFields)
    }


type alias Values =
    { name : String
    , rules : List PriceRule
    }


form : Form.Form Step Fields Values
form =
    Spec.define "s" Fields Values
        |> Spec.step Info "Info"
        |> Spec.with (Spec.text "Name" |> Spec.required)
        |> Spec.step Pricing "Pricing"
        |> Spec.with (Spec.rows { label = "Price rules", item = "Price rule" } priceRule)
        |> Spec.step Review "Review"
        |> Spec.build


f : Fields
f =
    Form.fields form


condition : Int -> String -> Operator -> List String -> Rule
condition id field operator values =
    ConditionRule { id = id, field = field, operator = operator, values = values }


rootOf : List Rule -> Rule
rootOf children =
    GroupRule { id = 0, combinator = All, negated = False, children = children }


bigOrders : Rule
bigOrders =
    rootOf [ condition 1 "quantity" GreaterThan [ "100" ] ]


fromNorway : Rule
fromNorway =
    rootOf [ condition 1 "category" Is [ "bolts" ] ]


unfinished : Rule
unfinished =
    rootOf [ condition 1 "" Is [] ]


sample : Values
sample =
    { name = "Acme"
    , rules =
        [ { condition = bigOrders, discount = 5 }
        , { condition = fromNorway, discount = 10 }
        ]
    }


fill : Values -> Form.State Step -> Form.State Step
fill v =
    Form.set f.name v.name
        >> Form.fillRows f.rules
            (\rule row ->
                Form.set row.conditions rule.condition
                    >> Form.set row.discount (Just rule.discount)
            )
            v.rules


filled : Form.State Step
filled =
    Form.init form |> fill sample |> Form.markClean


bound : Form.State Step -> Form.View Form.Msg
bound state =
    Form.bind Locale.en identity form state


stepOf : Form.State Step -> Maybe Step
stepOf =
    Form.currentStep form


rowsOf : Form.State Step -> List PriceFields
rowsOf =
    Form.rowFields f.rules


conditionsAt : Int -> Form.State Step -> Maybe Rule
conditionsAt position state =
    rowsOf state |> List.drop position |> List.head |> Maybe.map (\row -> Form.get row.conditions state)


withConditions : Int -> Rule -> Form.State Step -> Form.State Step
withConditions position rule state =
    case rowsOf state |> List.drop position |> List.head of
        Just row ->
            Form.set row.conditions rule state

        Nothing ->
            state


problemTexts : Form.State Step -> List ( String, String )
problemTexts state =
    Form.problems Locale.en form state |> List.map (\p -> ( p.label, p.message ))


showsText : String -> Html Form.Msg -> Expect.Expectation
showsText wanted html =
    html |> Query.fromHtml |> Query.has [ Selector.text wanted ]


{-| Clicks the button of the summary that carries this text.
-}
clickSummaryLine : String -> Form.State Step -> Form.State Step
clickSummaryLine text state =
    Form.summary (bound state)
        |> Query.fromHtml
        |> Query.find [ Selector.tag "button", Selector.containing [ Selector.text text ] ]
        |> Event.simulate Event.click
        |> Event.toResult
        |> Result.map (\msg -> Form.update form msg state |> Tuple.first)
        |> Result.withDefault state


suite : Test
suite =
    describe "a rule builder in the rows of a form"
        [ describe "the value"
            [ test "the form produces the rules with their conditions and discounts" <|
                \_ -> Form.toValues Locale.en form filled |> Expect.equal (Ok sample)
            , test "a record loaded into the form comes out the same (Check.roundTrip)" <|
                \_ -> Check.roundTrip form fill sample |> Expect.equal (Ok sample)
            , test "each row keeps its own rule while another row is removed" <|
                \_ ->
                    let
                        removeFirst =
                            Form.removeRow (bound filled) f.rules 0 []
                                |> Query.fromHtml
                                |> Event.simulate Event.click
                                |> Event.toResult
                                |> Result.map (\msg -> Form.update form msg filled |> Tuple.first)
                                |> Result.withDefault filled
                    in
                    ( conditionsAt 0 removeFirst, List.length (rowsOf removeFirst) )
                        |> Expect.equal ( Just fromNorway, 1 )
            ]
        , describe "dirty"
            [ test "a loaded form is clean, a changed rule makes it dirty and the old rule makes it clean again" <|
                \_ ->
                    Expect.all
                        [ \_ -> Form.isDirty filled |> Expect.equal False
                        , \_ -> filled |> withConditions 1 bigOrders |> Form.isDirty |> Expect.equal True
                        , \_ -> filled |> withConditions 1 bigOrders |> withConditions 1 fromNorway |> Form.isDirty |> Expect.equal False
                        ]
                        ()
            , test "revert gives back the rules of the baseline" <|
                \_ ->
                    filled
                        |> withConditions 0 fromNorway
                        |> Form.revert form
                        |> conditionsAt 0
                        |> Expect.equal (Just bigOrders)
            ]
        , describe "problems"
            [ test "a row with no conditions is a problem of that row, named by position" <|
                \_ ->
                    filled
                        |> withConditions 1 (rootOf [])
                        |> problemTexts
                        |> Expect.equal [ ( "Price rule 2, Conditions", "Add a condition" ) ]
            , test "an unfinished condition is a problem that points at the control to fill in" <|
                \_ ->
                    let
                        state =
                            filled |> withConditions 0 unfinished
                    in
                    case ( Form.problems Locale.en form state, rowsOf state |> List.head ) of
                        ( [ problem ], Just row ) ->
                            Expect.all
                                [ \_ -> problem.message |> Expect.equal "Choose a field"
                                , \_ ->
                                    problem.field
                                        |> Expect.equal (RuleBuilder.focusId ruleFields (RuleBuilder.init (Form.problem row.conditions "").field |> RuleBuilder.setRule unfinished) 1)
                                , \_ -> problem.field |> Expect.notEqual (Form.problem row.conditions "").field
                                ]
                                ()

                        _ ->
                            Expect.fail "expected one problem"
            , test "the control it points at is on the page" <|
                \_ ->
                    let
                        state =
                            filled |> withConditions 0 unfinished
                    in
                    case ( Form.problems Locale.en form state, rowsOf state |> List.head ) of
                        ( [ problem ], Just row ) ->
                            Form.ruleBuilder (bound state) row.conditions ruleFields []
                                |> Query.fromHtml
                                |> Query.has [ Selector.id problem.field ]

                        _ ->
                            Expect.fail "expected one problem"
            , test "the form is not valid while a rule is" <|
                \_ -> filled |> withConditions 0 unfinished |> Form.hasProblems form |> Expect.equal True
            , test "the problem is in the summary of its step once the step was tried, and the line leads there" <|
                \_ ->
                    let
                        onInfo =
                            filled |> withConditions 0 unfinished

                        ( onReview, _ ) =
                            Form.goTo form Review onInfo
                    in
                    Expect.all
                        [ \_ -> stepOf onReview |> Expect.equal (Just Pricing)
                        , \_ -> Form.summary (bound onReview) |> showsText "Price rule 1, Conditions: Choose a field"
                        , \_ ->
                            Form.stepper (bound onReview) []
                                |> Query.fromHtml
                                |> Query.find [ Selector.class "klar-stepper__step--failed" ]
                                |> Query.has [ Selector.text "Pricing" ]
                        ]
                        ()
            , test "on the review step a line of the summary goes to the step of the rule" <|
                \_ ->
                    let
                        broken =
                            filled |> withConditions 0 unfinished

                        ( rejectedOnReview, _ ) =
                            Form.goTo form Review filled
                                |> Tuple.first
                                |> withConditions 0 unfinished
                                |> Form.reveal form
                    in
                    Expect.all
                        [ \_ -> stepOf rejectedOnReview |> Expect.equal (Just Review)
                        , \_ ->
                            clickSummaryLine "Choose a field" (Form.goTo form Review rejectedOnReview |> Tuple.first)
                                |> stepOf
                                |> Expect.equal (Just Pricing)
                        , \_ -> broken |> Form.hasProblems form |> Expect.equal True
                        ]
                        ()
            , test "after a try the builder shows its issues on the nodes" <|
                \_ ->
                    let
                        state =
                            filled |> withConditions 0 unfinished

                        shown =
                            Form.reveal form state |> Tuple.first
                    in
                    case rowsOf shown |> List.head of
                        Just row ->
                            Expect.all
                                [ \_ -> Form.ruleBuilder (bound state) row.conditions ruleFields [] |> Query.fromHtml |> Query.hasNot [ Selector.text "Choose a field" ]
                                , \_ -> Form.ruleBuilder (bound shown) row.conditions ruleFields [] |> Query.fromHtml |> Query.has [ Selector.text "Choose a field" ]
                                ]
                                ()

                        Nothing ->
                            Expect.fail "no row"
            ]
        , describe "the server's position"
            [ test "problemInRow finds the row at the position the server counted" <|
                \_ ->
                    Form.problemInRow f.rules 1 .discount "Above the limit" filled
                        |> Maybe.map (\p -> ( p.field, p.label ))
                        |> Expect.equal (rowsOf filled |> List.drop 1 |> List.head |> Maybe.map (\row -> ( (Form.problem row.discount "").field, "Discount" )))
            , test "a position the group does not have is nothing" <|
                \_ ->
                    ( Form.problemInRow f.rules 2 .discount "x" filled
                    , Form.problemInRow f.rules -1 .discount "x" filled
                    )
                        |> Expect.equal ( Nothing, Nothing )
            , test "the problem shows at the field, in the summary, and goes when the field is edited" <|
                \_ ->
                    let
                        refused =
                            [ Form.problemInRow f.rules 1 .discount "Above the limit" filled ]
                                |> List.filterMap identity

                        ( state, _ ) =
                            Form.rejected refused form filled
                    in
                    Expect.all
                        [ \_ -> stepOf state |> Expect.equal (Just Pricing)
                        , \_ -> Form.summary (bound state) |> showsText "Price rule 2, Discount: Above the limit"
                        , \_ -> Form.hasProblems form state |> Expect.equal True
                        , \_ -> Form.hasProblems form (withDiscount 1 "11" state) |> Expect.equal False
                        ]
                        ()
            , test "a server problem on the conditions is listed and leads to the builder as a whole" <|
                \_ ->
                    let
                        ( state, _ ) =
                            Form.rejected
                                ([ Form.problemInRow f.rules 0 .conditions "These conditions overlap another rule" filled ] |> List.filterMap identity)
                                form
                                filled
                    in
                    Form.summary (bound state) |> showsText "Price rule 1, Conditions: These conditions overlap another rule"
            ]
        ]


{-| The user types a discount into the field of a row.
-}
withDiscount : Int -> String -> Form.State Step -> Form.State Step
withDiscount position typed state =
    case rowsOf state |> List.drop position |> List.head of
        Just row ->
            Form.numberInput (bound state) row.discount []
                |> Query.fromHtml
                |> Query.find [ Selector.tag "input" ]
                |> Event.simulate (Event.input typed)
                |> Event.toResult
                |> Result.map (\msg -> Form.update form msg state |> Tuple.first)
                |> Result.withDefault state

        Nothing ->
            state
