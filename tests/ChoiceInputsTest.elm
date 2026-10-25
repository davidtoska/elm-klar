module ChoiceInputsTest exposing (suite)

{-| The choice inputs: Checkbox, CheckboxGroup, Radio, Switch, Slider and
SegmentedControl. Values of the application's own type, what each event sends,
read-only, the ids that follow the focus, the sizes, the slider's grid and commit
events, and the forced-colors rules.
-}

import Expect exposing (Expectation)
import Html.Attributes as Attr
import Json.Encode as Encode
import Klar.Checkbox as Checkbox
import Klar.CheckboxGroup as CheckboxGroup
import Klar.Icon as Icon
import Klar.Internal.Choice as Choice
import Klar.Radio as Radio
import Klar.SegmentedControl as SegmentedControl
import Klar.Slider as Slider
import Klar.Switch as Switch
import Klar.Theme exposing (Size(..))
import Support.Css as Css
import Test exposing (Test, describe, test)
import Test.Html.Event as Event
import Test.Html.Query as Query
import Test.Html.Selector as Selector exposing (Selector)


type Delivery
    = Standard
    | Express
    | Pickup


type Extra
    = GiftWrap
    | PaperInvoice
    | Insurance


type Msg
    = DeliveryChanged Delivery
    | ExtrasChanged (List Extra)
    | Checked Bool
    | Moved Float
    | Committed Float
    | RangeMoved Float Float
    | RangeCommitted Float Float


suite : Test
suite =
    describe "Choice inputs"
        [ checkboxTests
        , checkboxGroupTests
        , radioTests
        , segmentedTests
        , switchTests
        , sliderTests
        , idTests
        , stylesheetTests
        ]



-- HELPERS


aria : String -> String -> Selector
aria name value =
    Selector.attribute (Attr.attribute name value)


count : List Selector -> Int -> Query.Single msg -> Expectation
count selectors expected =
    Query.findAll selectors >> Query.count (Expect.equal expected)


change : ( String, Encode.Value )
change =
    Event.custom "change" (Encode.object [])


valueEvent : String -> String -> ( String, Encode.Value )
valueEvent name value =
    Event.custom name (Encode.object [ ( "target", Encode.object [ ( "value", Encode.string value ) ] ) ])


byId : String -> Query.Single msg -> Query.Single msg
byId id =
    Query.find [ Selector.id id ]



-- CHECKBOX


checkboxTests : Test
checkboxTests =
    describe "Klar.Checkbox"
        [ test "the size is a class with a rule: small and large boxes are drawn smaller and larger" <|
            \_ ->
                Expect.all
                    [ \_ -> Checkbox.view [ Checkbox.label "x", Checkbox.size Small ] |> Query.fromHtml |> Query.has [ Selector.class "klar-check--sm" ]
                    , \_ -> Checkbox.view [ Checkbox.label "x", Checkbox.size Large ] |> Query.fromHtml |> Query.has [ Selector.class "klar-check--lg" ]
                    , \_ -> Expect.equal True (String.contains ".klar-check--sm{--_box: 14px" Css.rules)
                    , \_ -> Expect.equal True (String.contains ".klar-check--lg{--_box: 18px" Css.rules)
                    ]
                    ()
        , test "errorMaybe Nothing is no error and Just is one" <|
            \_ ->
                Expect.all
                    [ \_ ->
                        Checkbox.view [ Checkbox.id "terms", Checkbox.label "Terms", Checkbox.errorMaybe Nothing ]
                            |> Query.fromHtml
                            |> Query.hasNot [ Selector.class "klar-check--invalid" ]
                    , \_ ->
                        Checkbox.view [ Checkbox.id "terms", Checkbox.label "Terms", Checkbox.errorMaybe (Just "Accept the terms") ]
                            |> Query.fromHtml
                            |> Expect.all
                                [ Query.has [ Selector.class "klar-check--invalid" ]
                                , Query.find [ Selector.id "terms-error" ] >> Query.has [ Selector.text "Accept the terms" ]
                                ]
                    ]
                    ()
        , test "required puts aria-required on the input and a hidden star after the label" <|
            \_ ->
                Checkbox.view [ Checkbox.id "terms", Checkbox.label "I accept the terms", Checkbox.required ]
                    |> Query.fromHtml
                    |> Expect.all
                        [ Query.find [ Selector.tag "input" ] >> Query.has [ aria "aria-required" "true" ]
                        , Query.find [ Selector.class "klar-field__required" ] >> Query.has [ aria "aria-hidden" "true", Selector.text "*" ]
                        ]
        , test "read only: no native input, a focusable role=checkbox with aria-checked and aria-readonly, named by its label" <|
            \_ ->
                Checkbox.view [ Checkbox.id "news", Checkbox.label "Newsletter", Checkbox.checked True, Checkbox.readOnly True, Checkbox.onCheck Checked ]
                    |> Query.fromHtml
                    |> Expect.all
                        [ count [ Selector.tag "input" ] 0
                        , Query.find [ Selector.id "news" ]
                            >> Query.has
                                [ aria "role" "checkbox"
                                , aria "aria-checked" "true"
                                , aria "aria-readonly" "true"
                                , Selector.attribute (Attr.tabindex 0)
                                , aria "aria-labelledby" "news-label"
                                ]
                        , Query.find [ Selector.id "news-label" ] >> Query.has [ Selector.text "Newsletter" ]
                        , Query.has [ Selector.class "klar-check--readonly" ]
                        , Query.hasNot [ Selector.class "klar-check--disabled" ]
                        ]
        , test "a read-only box sends nothing when clicked" <|
            \_ ->
                Checkbox.view [ Checkbox.id "news", Checkbox.label "Newsletter", Checkbox.readOnly True, Checkbox.onCheck Checked ]
                    |> Query.fromHtml
                    |> byId "news"
                    |> Event.simulate Event.click
                    |> Event.toResult
                    |> Expect.err
        , test "a read-only indeterminate box is mixed, and an unchecked one false" <|
            \_ ->
                Expect.all
                    [ \_ ->
                        Checkbox.view [ Checkbox.id "all", Checkbox.ariaLabel "All", Checkbox.indeterminate True, Checkbox.readOnly True ]
                            |> Query.fromHtml
                            |> byId "all"
                            |> Query.has [ aria "aria-checked" "mixed", aria "aria-label" "All" ]
                    , \_ ->
                        Checkbox.view [ Checkbox.id "one", Checkbox.ariaLabel "One", Checkbox.readOnly True ]
                            |> Query.fromHtml
                            |> byId "one"
                            |> Query.has [ aria "aria-checked" "false" ]
                    ]
                    ()
        , test "disabled wins over read only" <|
            \_ ->
                Checkbox.view [ Checkbox.label "x", Checkbox.readOnly True, Checkbox.disabled True ]
                    |> Query.fromHtml
                    |> Expect.all
                        [ Query.find [ Selector.tag "input" ] >> Query.has [ Selector.disabled True ]
                        , Query.hasNot [ Selector.class "klar-check--readonly" ]
                        ]
        ]



-- CHECKBOX GROUP


extras : List (CheckboxGroup.Attribute Extra Msg) -> Query.Single Msg
extras attributes =
    CheckboxGroup.view
        ([ CheckboxGroup.id "extras"
         , CheckboxGroup.label "Extras"
         , CheckboxGroup.options
            [ CheckboxGroup.option GiftWrap "Gift wrap"
            , CheckboxGroup.option PaperInvoice "Paper invoice"
            , CheckboxGroup.option Insurance "Shipping insurance" |> CheckboxGroup.disabledOption
            ]
         , CheckboxGroup.onChange ExtrasChanged
         ]
            ++ attributes
        )
        |> Query.fromHtml


selectAllBox : Query.Single msg -> Query.Single msg
selectAllBox =
    Query.find [ Selector.class "klar-checkgroup__all" ] >> Query.find [ Selector.tag "input" ]


checkboxGroupTests : Test
checkboxGroupTests =
    describe "Klar.CheckboxGroup"
        [ test "checking a box sends the whole selection of the application's own values, in the order of the options" <|
            \_ ->
                extras [ CheckboxGroup.selected [ PaperInvoice ] ]
                    |> byId "extras"
                    |> Event.simulate (Event.check True)
                    |> Event.expect (ExtrasChanged [ GiftWrap, PaperInvoice ])
        , test "clearing a box takes its value out" <|
            \_ ->
                extras [ CheckboxGroup.selected [ GiftWrap, PaperInvoice ] ]
                    |> byId "extras-1"
                    |> Event.simulate (Event.check False)
                    |> Event.expect (ExtrasChanged [ GiftWrap ])
        , test "select all checks every option that can be changed and leaves a disabled one as it was" <|
            \_ ->
                extras [ CheckboxGroup.selected [], CheckboxGroup.selectAll ]
                    |> selectAllBox
                    |> Event.simulate (Event.check True)
                    |> Event.expect (ExtrasChanged [ GiftWrap, PaperInvoice ])
        , test "clearing select all keeps a disabled option that is checked" <|
            \_ ->
                extras [ CheckboxGroup.selected [ GiftWrap, PaperInvoice, Insurance ], CheckboxGroup.selectAll ]
                    |> selectAllBox
                    |> Event.simulate (Event.check False)
                    |> Event.expect (ExtrasChanged [ Insurance ])
        , test "a size reaches every box" <|
            \_ ->
                extras [ CheckboxGroup.size Small, CheckboxGroup.selectAll ]
                    |> Expect.all
                        [ count [ Selector.class "klar-check--sm" ] 4
                        , count [ Selector.class "klar-check--md" ] 0
                        ]
        , test "read only: every box is a read-only checkbox and nothing can be sent" <|
            \_ ->
                extras [ CheckboxGroup.selected [ GiftWrap ], CheckboxGroup.readOnly True ]
                    |> Expect.all
                        [ count [ Selector.class "klar-check--readonly" ] 2
                        , count [ aria "role" "checkbox", aria "aria-readonly" "true" ] 2
                        , byId "extras" >> Query.has [ aria "aria-checked" "true" ]
                        , byId "extras" >> Event.simulate Event.click >> Event.toResult >> Expect.err
                        ]
        , test "a group without onChange is read only" <|
            \_ ->
                CheckboxGroup.view
                    [ CheckboxGroup.id "docs"
                    , CheckboxGroup.label "Documents"
                    , CheckboxGroup.options [ CheckboxGroup.option "invoice" "Invoice" ]
                    ]
                    |> Query.fromHtml
                    |> count [ Selector.tag "input" ] 0
        , test "with no box that can take the focus, the fieldset carries the id" <|
            \_ ->
                extras [ CheckboxGroup.disabled True ]
                    |> byId "extras"
                    |> Query.has [ Selector.tag "fieldset", Selector.attribute (Attr.tabindex -1) ]
        , test "the selection keeps unknown values at the end and never sends one twice" <|
            \_ ->
                Expect.all
                    [ \_ -> Expect.equal [ 1, 3, 9 ] (Choice.toggle [ 1, 2, 3 ] [ 9, 3, 3 ] 1 True)
                    , \_ -> Expect.equal [ 1, 2, 9 ] (Choice.setAll [ 1, 2, 3 ] [ 1, 2 ] [ 9, 2 ] True)
                    , \_ -> Expect.equal [ 3, 9 ] (Choice.setAll [ 1, 2, 3 ] [ 1, 2 ] [ 9, 3, 1 ] False)
                    , \_ -> Expect.equal [ 1, 2 ] (Choice.inOptionOrder [ 1, 2, 1 ] [ 2, 1, 1 ])
                    ]
                    ()
        ]



-- RADIO


delivery : List (Radio.Attribute Delivery Msg) -> Query.Single Msg
delivery attributes =
    Radio.view
        ([ Radio.id "delivery"
         , Radio.label "Delivery"
         , Radio.options
            [ Radio.option Standard "Standard"
            , Radio.option Express "Express"
            , Radio.option Pickup "Pick up" |> Radio.disabledOption
            ]
         , Radio.onChange DeliveryChanged
         ]
            ++ attributes
        )
        |> Query.fromHtml


radioTests : Test
radioTests =
    describe "Klar.Radio"
        [ test "choosing an option sends its value of the application's own type" <|
            \_ ->
                delivery [ Radio.selected (Just Standard) ]
                    |> byId "delivery-1"
                    |> Event.simulate change
                    |> Event.expect (DeliveryChanged Express)
        , test "the DOM value of an option is its position" <|
            \_ ->
                delivery []
                    |> Query.findAll [ Selector.tag "input" ]
                    |> Expect.all
                        [ Query.index 0 >> Query.has [ Selector.attribute (Attr.value "0") ]
                        , Query.index 1 >> Query.has [ Selector.attribute (Attr.value "1") ]
                        ]
        , test "the id of the group is on the chosen radio button" <|
            \_ ->
                delivery [ Radio.selected (Just Express) ]
                    |> byId "delivery"
                    |> Query.has [ Selector.tag "input", Selector.checked True ]
        , test "with nothing chosen the id is on the first radio button that can be chosen" <|
            \_ ->
                delivery [ Radio.selected Nothing ]
                    |> byId "delivery"
                    |> Query.has [ Selector.tag "input", Selector.attribute (Attr.value "0") ]
        , test "a disabled option is disabled" <|
            \_ ->
                delivery []
                    |> byId "delivery-2"
                    |> Query.has [ Selector.disabled True ]
        , test "read only: the group has aria-readonly, the chosen radio keeps the focus and the id, the others cannot be chosen" <|
            \_ ->
                delivery [ Radio.selected (Just Express), Radio.readOnly True ]
                    |> Expect.all
                        [ Query.find [ Selector.tag "fieldset" ] >> Query.has [ aria "aria-readonly" "true" ]
                        , byId "delivery" >> Query.has [ Selector.checked True, Selector.disabled False ]
                        , byId "delivery-0" >> Query.has [ Selector.disabled True ]
                        , byId "delivery" >> Event.simulate change >> Event.toResult >> Expect.err
                        , count [ Selector.class "klar-radio--readonly" ] 2
                        , count [ Selector.class "klar-radio--disabled" ] 1
                        ]
        , test "a group without onChange is read only" <|
            \_ ->
                Radio.view
                    [ Radio.id "plain"
                    , Radio.label "Plain"
                    , Radio.options [ Radio.option 1 "One", Radio.option 2 "Two" ]
                    , Radio.selected (Just 2)
                    ]
                    |> Query.fromHtml
                    |> Query.find [ Selector.tag "fieldset" ]
                    |> Query.has [ aria "aria-readonly" "true" ]
        , test "a disabled group puts its id on the fieldset, which can take the focus from a script" <|
            \_ ->
                delivery [ Radio.disabled True ]
                    |> byId "delivery"
                    |> Query.has [ Selector.tag "fieldset", Selector.attribute (Attr.tabindex -1) ]
        ]



-- SEGMENTED CONTROL


type Layout
    = ListLayout
    | GridLayout


layoutControl : List (SegmentedControl.Attribute Layout (Maybe Layout)) -> Query.Single (Maybe Layout)
layoutControl attributes =
    SegmentedControl.view
        ([ SegmentedControl.id "layout"
         , SegmentedControl.label "Layout"
         , SegmentedControl.options
            [ SegmentedControl.iconOption ListLayout Icon.list "List"
            , SegmentedControl.option GridLayout "Grid"
            ]
         , SegmentedControl.selected ListLayout
         , SegmentedControl.onChange Just
         ]
            ++ attributes
        )
        |> Query.fromHtml


segmentedTests : Test
segmentedTests =
    describe "Klar.SegmentedControl"
        [ test "choosing a segment sends its value of the application's own type" <|
            \_ ->
                layoutControl []
                    |> byId "layout-1"
                    |> Event.simulate change
                    |> Event.expect (Just GridLayout)
        , test "the id is on the chosen segment" <|
            \_ ->
                layoutControl []
                    |> byId "layout"
                    |> Query.has [ Selector.tag "input", Selector.checked True ]
        , test "an icon option keeps its text as the accessible name and the tooltip" <|
            \_ ->
                layoutControl []
                    |> Query.find [ Selector.class "klar-segmented__content--icon-only" ]
                    |> Expect.all
                        [ Query.has [ Selector.attribute (Attr.title "List") ]
                        , Query.find [ Selector.class "klar-segmented__label" ] >> Query.has [ Selector.class "klar-sr-only", Selector.text "List" ]
                        ]
        , test "a visible label names the group with aria-labelledby" <|
            \_ ->
                layoutControl []
                    |> Expect.all
                        [ Query.find [ aria "role" "radiogroup" ] >> Query.has [ aria "aria-labelledby" "layout-label" ]
                        , byId "layout-label" >> Query.has [ Selector.text "Layout" ]
                        ]
        , test "a hidden label is the aria-label of the group and adds no element" <|
            \_ ->
                layoutControl [ SegmentedControl.labelHidden ]
                    |> Expect.all
                        [ Query.find [ aria "role" "radiogroup" ] >> Query.has [ aria "aria-label" "Layout" ]
                        , count [ Selector.id "layout-label" ] 0
                        ]
        , test "read only: aria-readonly, the chosen segment keeps the focus, the other cannot be chosen" <|
            \_ ->
                layoutControl [ SegmentedControl.readOnly True ]
                    |> Expect.all
                        [ Query.find [ aria "role" "radiogroup" ] >> Query.has [ aria "aria-readonly" "true" ]
                        , byId "layout" >> Query.has [ Selector.disabled False ]
                        , byId "layout-1" >> Query.has [ Selector.disabled True ]
                        , byId "layout-1" >> Event.simulate change >> Event.toResult >> Expect.err
                        , count [ Selector.class "klar-segmented__item--readonly" ] 2
                        ]
        ]



-- SWITCH


switchTests : Test
switchTests =
    describe "Klar.Switch"
        [ test "onCheck gets the new value" <|
            \_ ->
                Switch.view [ Switch.label "Active", Switch.checked False, Switch.onCheck Checked ]
                    |> Query.fromHtml
                    |> Query.find [ Selector.tag "input" ]
                    |> Event.simulate (Event.check True)
                    |> Event.expect (Checked True)
        , test "the hint is joined to the switch" <|
            \_ ->
                Switch.view [ Switch.id "notify", Switch.label "Notify", Switch.hint "By email." ]
                    |> Query.fromHtml
                    |> Expect.all
                        [ Query.find [ Selector.tag "input" ] >> Query.has [ aria "aria-describedby" "notify-description" ]
                        , byId "notify-description" >> Query.has [ Selector.text "By email." ]
                        ]
        , test "errorMaybe Just shows the error, Nothing none" <|
            \_ ->
                Expect.all
                    [ \_ ->
                        Switch.view [ Switch.id "notify", Switch.label "Notify", Switch.errorMaybe (Just "Could not save") ]
                            |> Query.fromHtml
                            |> Query.has [ Selector.class "klar-switch--invalid" ]
                    , \_ ->
                        Switch.view [ Switch.id "notify", Switch.label "Notify", Switch.errorMaybe Nothing ]
                            |> Query.fromHtml
                            |> Query.hasNot [ Selector.class "klar-switch--invalid" ]
                    ]
                    ()
        , test "without an id the input gets none, so rows of switches share no id" <|
            \_ ->
                Switch.view [ Switch.ariaLabel "Active" ]
                    |> Query.fromHtml
                    |> Query.find [ Selector.tag "input" ]
                    |> Query.hasNot [ Selector.id "klar-switch-active" ]
        , test "read only: a focusable role=switch with aria-checked and aria-readonly, and no native input" <|
            \_ ->
                Switch.view [ Switch.id "active", Switch.label "Active", Switch.checked True, Switch.readOnly True, Switch.onCheck Checked ]
                    |> Query.fromHtml
                    |> Expect.all
                        [ count [ Selector.tag "input" ] 0
                        , byId "active"
                            >> Query.has
                                [ aria "role" "switch"
                                , aria "aria-checked" "true"
                                , aria "aria-readonly" "true"
                                , Selector.attribute (Attr.tabindex 0)
                                , aria "aria-labelledby" "active-label"
                                ]
                        , byId "active" >> Event.simulate Event.click >> Event.toResult >> Expect.err
                        ]
        , test "the status region is always there, and says Saving only while saving" <|
            \_ ->
                Expect.all
                    [ \_ ->
                        Switch.view [ Switch.label "Active" ]
                            |> Query.fromHtml
                            |> Query.find [ aria "role" "status" ]
                            |> Query.hasNot [ Selector.text "Saving" ]
                    , \_ ->
                        Switch.view [ Switch.label "Active", Switch.loading True, Switch.onCheck Checked ]
                            |> Query.fromHtml
                            |> Query.find [ aria "role" "status" ]
                            |> Query.has [ Selector.text "Saving ..." ]
                    ]
                    ()
        ]



-- SLIDER


sliderTests : Test
sliderTests =
    describe "Klar.Slider"
        [ test "a grid that starts at 0.5 is written with its decimal" <|
            \_ ->
                Slider.view [ Slider.id "s", Slider.label "Amount", Slider.min 0.5, Slider.max 10, Slider.value 1.5 ]
                    |> Query.fromHtml
                    |> Expect.all
                        [ Query.find [ Selector.class "klar-slider__value" ] >> Query.has [ Selector.text "1.5" ]
                        , Query.find [ Selector.tag "input" ] >> Query.has [ aria "aria-valuetext" "1.5" ]
                        ]
        , test "a value off the step grid is drawn and written where the browser puts the thumb" <|
            \_ ->
                Slider.view [ Slider.id "s", Slider.label "Discount", Slider.max 50, Slider.step 5, Slider.value 7 ]
                    |> Query.fromHtml
                    |> Expect.all
                        [ Query.find [ Selector.class "klar-slider__value" ] >> Query.has [ Selector.text "5" ]
                        , Query.find [ Selector.tag "input" ] >> Query.has [ aria "aria-valuetext" "5" ]
                        , Query.find [ Selector.class "klar-slider" ] >> Query.has [ Selector.attribute (Attr.attribute "style" "--klar-pct:0.1") ]
                        ]
        , test "a max off the grid: the thumb stops at the last point of the grid" <|
            \_ ->
                Slider.view [ Slider.id "s", Slider.label "Hours", Slider.max 50, Slider.step 15, Slider.value 50 ]
                    |> Query.fromHtml
                    |> Query.find [ Selector.class "klar-slider__value" ]
                    |> Query.has [ Selector.text "45" ]
        , test "onInput is sent while dragging and onCommit when the thumb is let go" <|
            \_ ->
                let
                    input =
                        Slider.view [ Slider.id "s", Slider.label "Price", Slider.max 1000, Slider.onInput Moved, Slider.onCommit Committed ]
                            |> Query.fromHtml
                            |> Query.find [ Selector.tag "input" ]
                in
                Expect.all
                    [ Event.simulate (valueEvent "input" "300") >> Event.expect (Moved 300)
                    , Event.simulate (valueEvent "change" "320") >> Event.expect (Committed 320)
                    ]
                    input
        , test "a range thumb moved past the other one is held minGap away from it" <|
            \_ ->
                Slider.viewRange [ Slider.id "q", Slider.label "Quantity", Slider.range 20 60, Slider.minGap 10, Slider.onRangeInput RangeMoved ]
                    |> Query.fromHtml
                    |> byId "q"
                    |> Event.simulate (valueEvent "input" "80")
                    |> Event.expect (RangeMoved 50 60)
        , test "onRangeCommit gets both values when a thumb is let go" <|
            \_ ->
                Slider.viewRange [ Slider.id "q", Slider.label "Quantity", Slider.range 20 60, Slider.onRangeCommit RangeCommitted ]
                    |> Query.fromHtml
                    |> byId "q-upper"
                    |> Event.simulate (valueEvent "change" "70")
                    |> Event.expect (RangeCommitted 20 70)
        , test "read only: no range input, a focusable role=slider with the value, aria-readonly and the label" <|
            \_ ->
                Slider.view [ Slider.id "s", Slider.label "Discount", Slider.max 50, Slider.value 15, Slider.unit "%", Slider.readOnly True, Slider.onInput Moved ]
                    |> Query.fromHtml
                    |> Expect.all
                        [ count [ Selector.tag "input" ] 0
                        , byId "s"
                            >> Query.has
                                [ aria "role" "slider"
                                , aria "aria-valuenow" "15"
                                , aria "aria-valuemin" "0"
                                , aria "aria-valuemax" "50"
                                , aria "aria-readonly" "true"
                                , aria "aria-labelledby" "s-label"
                                , Selector.attribute (Attr.tabindex 0)
                                ]
                        , Query.find [ Selector.class "klar-slider" ] >> Query.has [ Selector.class "klar-slider--readonly" ]
                        ]
        , test "a read-only range has two read-only thumbs, named after the label" <|
            \_ ->
                Slider.viewRange [ Slider.id "q", Slider.label "Quantity", Slider.range 20 60, Slider.readOnly True ]
                    |> Query.fromHtml
                    |> Expect.all
                        [ count [ Selector.tag "input" ] 0
                        , byId "q" >> Query.has [ aria "role" "slider", aria "aria-valuenow" "20", aria "aria-label" "Quantity, from" ]
                        , byId "q-upper" >> Query.has [ aria "role" "slider", aria "aria-valuenow" "60", aria "aria-label" "Quantity, to" ]
                        ]
        , test "the thumbs of a range are named after the label" <|
            \_ ->
                Slider.viewRange [ Slider.id "q", Slider.label "Quantity" ]
                    |> Query.fromHtml
                    |> Expect.all
                        [ byId "q" >> Query.has [ aria "aria-label" "Quantity, from" ]
                        , byId "q-upper" >> Query.has [ aria "aria-label" "Quantity, to" ]
                        ]
        ]



-- IDS


idTests : Test
idTests =
    describe "ids made from the label"
        [ test "two groups with the same label and other options get other ids" <|
            \_ ->
                Expect.notEqual
                    (Choice.groupId "radio" (Just "Delivery") [ "Standard", "Express" ])
                    (Choice.groupId "radio" (Just "Delivery") [ "Mail", "Courier" ])
        , test "a label without letters that fit an id still gives a valid id" <|
            \_ ->
                Choice.groupId "radio" (Just "日本語") [ "A" ]
                    |> String.startsWith "klar-radio-group-"
                    |> Expect.equal True
        , test "a group without an id gets one from its label" <|
            \_ ->
                Radio.view [ Radio.label "Delivery", Radio.options [ Radio.option Standard "Standard" ], Radio.onChange DeliveryChanged ]
                    |> Query.fromHtml
                    |> Query.find [ Selector.tag "input" ]
                    |> Query.has [ Selector.id (Choice.groupId "radio" (Just "Delivery") [ "Standard" ]) ]
        ]



-- STYLESHEET


{-| The rules inside each `@media (forced-colors: active)` block.
-}
forcedColorBlocks : List String
forcedColorBlocks =
    Css.rules
        |> String.split "@media (forced-colors: active){"
        |> List.drop 1
        |> List.map (String.split "}}" >> List.head >> Maybe.withDefault "")


stylesheetTests : Test
stylesheetTests =
    describe "forced colors (Windows high contrast)"
        (List.map
            (\selector ->
                test ("has a rule for " ++ selector) <|
                    \_ ->
                        forcedColorBlocks
                            |> List.any (String.contains selector)
                            |> Expect.equal True
            )
            [ ".klar-check__box{forced-color-adjust: none"
            , ".klar-radio__dot{forced-color-adjust: none"
            , ".klar-switch__track{forced-color-adjust: none"
            , ".klar-range__track"
            , ".klar-segmented__input:checked + .klar-segmented__content"
            , ".klar-checkgroup--invalid"
            ]
        )
