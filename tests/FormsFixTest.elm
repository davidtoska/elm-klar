module FormsFixTest exposing (suite)

{-| Regression tests for the accessibility fixes of the form controls:

  - `aria-describedby` only names elements that are drawn,
  - a switch that is saving is inert,
  - a checkbox draws its hint and its error message with or without a label,
  - sections and forms cannot get the same DOM id,
  - `aria-invalid` and `aria-required` only where the ARIA role allows them.

-}

import Expect exposing (Expectation)
import Html exposing (Html)
import Html.Attributes as Attr
import Klar.Checkbox as Checkbox
import Klar.CheckboxGroup as CheckboxGroup
import Klar.Field as Field
import Klar.Form.Layout as FormLayout
import Klar.Radio as Radio
import Klar.SegmentedControl as SegmentedControl
import Klar.Slider as Slider
import Klar.Switch as Switch
import Test exposing (Test, describe, test)
import Test.Html.Event as Event
import Test.Html.Query as Query
import Test.Html.Selector as Selector exposing (Selector)


type Msg
    = Toggled Bool
    | Checked Bool
    | Moved Float
    | MovedRange Float Float


suite : Test
suite =
    describe "Forms: accessibility and id fixes"
        [ switchTests
        , checkboxTests
        , checkboxGroupTests
        , radioGroupTests
        , segmentedControlTests
        , sliderTests
        , formTests
        , fieldTests
        ]



-- HELPERS


aria : String -> String -> Selector
aria name value =
    Selector.attribute (Attr.attribute name value)


role : String -> Selector
role =
    aria "role"


inputOf : Query.Single msg -> Query.Single msg
inputOf =
    Query.find [ Selector.tag "input" ]


{-| How many elements match all the selectors.
-}
count : List Selector -> Int -> Query.Single msg -> Expectation
count selectors expected =
    Query.findAll selectors >> Query.count (Expect.equal expected)



-- SWITCH


switch : List (Switch.Attribute Msg) -> Query.Single Msg
switch attributes =
    Switch.view attributes |> Query.fromHtml


switchTests : Test
switchTests =
    describe "Klar.Switch"
        [ test "a description without a label is drawn and aria-describedby names it" <|
            \_ ->
                let
                    root =
                        switch
                            [ Switch.id "notify"
                            , Switch.ariaLabel "Email notifications"
                            , Switch.description "You get an email when an order ships."
                            ]
                in
                Expect.all
                    [ \r -> Query.has [ aria "aria-describedby" "notify-description" ] (inputOf r)
                    , \r -> Query.find [ Selector.id "notify-description" ] r |> Query.has [ Selector.text "You get an email when an order ships." ]
                    , \r -> count [ Selector.id "notify-description" ] 1 r
                    ]
                    root
        , test "with a label the description is named as well" <|
            \_ ->
                let
                    root =
                        switch
                            [ Switch.id "notify"
                            , Switch.label "Email notifications"
                            , Switch.description "You get an email when an order ships."
                            ]
                in
                Expect.all
                    [ \r -> Query.has [ aria "aria-describedby" "notify-description" ] (inputOf r)
                    , \r -> Query.has [ aria "aria-labelledby" "notify-label" ] (inputOf r)
                    , \r -> count [ Selector.id "notify-description" ] 1 r
                    , \r -> count [ Selector.id "notify-label" ] 1 r
                    ]
                    root
        , test "without a description or an error aria-describedby is left out" <|
            \_ ->
                let
                    root =
                        switch [ Switch.id "notify", Switch.label "Email notifications" ]
                in
                Expect.all
                    [ \r -> Query.hasNot [ aria "aria-describedby" "notify-description" ] (inputOf r)
                    , \r -> Query.hasNot [ aria "aria-describedby" "notify-error" ] (inputOf r)
                    , \r -> Query.hasNot [ aria "aria-describedby" "notify-description notify-error" ] (inputOf r)
                    , \r -> count [ Selector.id "notify-description" ] 0 r
                    , \r -> count [ Selector.id "notify-error" ] 0 r
                    ]
                    root
        , test "an error without a label is drawn as an alert and named" <|
            \_ ->
                let
                    root =
                        switch
                            [ Switch.id "notify"
                            , Switch.ariaLabel "Email notifications"
                            , Switch.error "Turn this on to place the order"
                            ]
                in
                Expect.all
                    [ \r -> Query.find [ Selector.id "notify-error" ] r |> Query.has [ role "alert", Selector.text "Turn this on to place the order" ]
                    , \r -> Query.has [ aria "aria-describedby" "notify-error", aria "aria-invalid" "true" ] (inputOf r)
                    , \r -> Query.has [ Selector.class "klar-switch--invalid" ] r
                    ]
                    root
        , test "a description and an error are named in that order" <|
            \_ ->
                switch
                    [ Switch.id "notify"
                    , Switch.label "Email notifications"
                    , Switch.description "You get an email when an order ships."
                    , Switch.error "Turn this on to place the order"
                    ]
                    |> inputOf
                    |> Query.has [ aria "aria-describedby" "notify-description notify-error" ]
        , test "an empty error is no error: no red outline, no aria-invalid, no element" <|
            \_ ->
                let
                    root =
                        switch [ Switch.id "notify", Switch.label "Email notifications", Switch.error "  " ]
                in
                Expect.all
                    [ \r -> Query.hasNot [ Selector.class "klar-switch--invalid" ] r
                    , \r -> Query.hasNot [ aria "aria-invalid" "true" ] (inputOf r)
                    , \r -> count [ Selector.id "notify-error" ] 0 r
                    ]
                    root
        , test "while it is loading the input is disabled" <|
            \_ ->
                switch [ Switch.label "Email notifications", Switch.onToggle Toggled, Switch.loading True ]
                    |> inputOf
                    |> Query.has [ Selector.disabled True, aria "aria-busy" "true" ]
        , test "while it is loading a change on the input sends nothing" <|
            \_ ->
                switch [ Switch.label "Email notifications", Switch.checked False, Switch.onToggle Toggled, Switch.loading True ]
                    |> inputOf
                    |> Event.simulate (Event.check True)
                    |> Event.toResult
                    |> Expect.err
        , test "while it is loading a click on the input sends nothing" <|
            \_ ->
                switch [ Switch.label "Email notifications", Switch.checked False, Switch.onToggle Toggled, Switch.loading True ]
                    |> inputOf
                    |> Event.simulate Event.click
                    |> Event.toResult
                    |> Expect.err
        , test "while it is loading the switch keeps showing the value it is given" <|
            \_ ->
                Expect.all
                    [ \r -> Query.has [ Selector.class "klar-switch--on", Selector.class "klar-switch--loading" ] r
                    , \r -> Query.has [ Selector.checked True ] (inputOf r)
                    ]
                    (switch [ Switch.label "Email notifications", Switch.checked True, Switch.onToggle Toggled, Switch.loading True ])
        , test "loading does not dim the switch the way disabled does" <|
            \_ ->
                switch [ Switch.label "Email notifications", Switch.loading True ]
                    |> Query.hasNot [ Selector.class "klar-switch--disabled" ]
        , test "a switch that is not loading can be changed" <|
            \_ ->
                let
                    root =
                        switch [ Switch.label "Email notifications", Switch.checked False, Switch.onToggle Toggled ]
                in
                Expect.all
                    [ \r -> Query.has [ Selector.disabled False ] (inputOf r)
                    , \r -> inputOf r |> Event.simulate (Event.check True) |> Event.expect (Toggled True)
                    ]
                    root
        , test "a disabled switch is disabled and dimmed" <|
            \_ ->
                let
                    root =
                        switch [ Switch.label "Email notifications", Switch.disabled True ]
                in
                Expect.all
                    [ \r -> Query.has [ Selector.disabled True ] (inputOf r)
                    , \r -> Query.has [ Selector.class "klar-switch--disabled" ] r
                    ]
                    root
        ]



-- CHECKBOX


checkbox : List (Checkbox.Attribute Msg) -> Query.Single Msg
checkbox attributes =
    Checkbox.view attributes |> Query.fromHtml


checkboxTests : Test
checkboxTests =
    describe "Klar.Checkbox"
        [ test "a hint without a label is drawn next to the box and named" <|
            \_ ->
                let
                    root =
                        checkbox
                            [ Checkbox.id "terms"
                            , Checkbox.ariaLabel "Accept the terms"
                            , Checkbox.hint "You can change this later."
                            ]
                in
                Expect.all
                    [ \r -> Query.find [ Selector.id "terms-description" ] r |> Query.has [ Selector.class "klar-check__hint", Selector.text "You can change this later." ]
                    , \r -> Query.has [ aria "aria-describedby" "terms-description", aria "aria-label" "Accept the terms" ] (inputOf r)
                    , \r -> Query.hasNot [ aria "aria-labelledby" "terms-label" ] (inputOf r)
                    , \r -> Query.hasNot [ Selector.class "klar-check--bare" ] r
                    ]
                    root
        , test "an error without a label is drawn as an alert, named, and marks the box" <|
            \_ ->
                let
                    root =
                        checkbox
                            [ Checkbox.id "terms"
                            , Checkbox.ariaLabel "Accept the terms"
                            , Checkbox.error "Accept the terms to continue"
                            ]
                in
                Expect.all
                    [ \r -> Query.find [ Selector.id "terms-error" ] r |> Query.has [ role "alert", Selector.class "klar-check__error", Selector.text "Accept the terms to continue" ]
                    , \r -> Query.has [ aria "aria-describedby" "terms-error", aria "aria-invalid" "true" ] (inputOf r)
                    , \r -> Query.has [ Selector.class "klar-check--invalid" ] r
                    ]
                    root
        , test "with a label, a hint and an error the name is the label alone" <|
            \_ ->
                let
                    root =
                        checkbox
                            [ Checkbox.id "terms"
                            , Checkbox.label "I accept the terms"
                            , Checkbox.hint "You can change this later."
                            , Checkbox.error "Accept the terms to continue"
                            ]
                in
                Expect.all
                    [ \r -> Query.has [ aria "aria-labelledby" "terms-label", aria "aria-describedby" "terms-description terms-error" ] (inputOf r)
                    , \r -> Query.find [ Selector.id "terms-label" ] r |> Query.has [ Selector.text "I accept the terms" ]
                    , \r -> Query.find [ Selector.id "terms-label" ] r |> Query.hasNot [ Selector.text "You can change this later." ]
                    , \r -> Query.find [ Selector.id "terms-label" ] r |> Query.hasNot [ Selector.text "Accept the terms to continue" ]
                    ]
                    root
        , test "the labelled look is kept: label, hint and error in one text column" <|
            \_ ->
                let
                    column =
                        checkbox
                            [ Checkbox.id "terms"
                            , Checkbox.label "I accept the terms"
                            , Checkbox.hint "You can change this later."
                            , Checkbox.error "Accept the terms to continue"
                            ]
                            |> Query.find [ Selector.class "klar-check__text" ]
                            |> Query.children []
                in
                Expect.all
                    [ Query.count (Expect.equal 3)
                    , Query.index 0 >> Query.has [ Selector.class "klar-check__label" ]
                    , Query.index 1 >> Query.has [ Selector.class "klar-check__hint" ]
                    , Query.index 2 >> Query.has [ Selector.class "klar-check__error" ]
                    ]
                    column
        , test "a label alone adds no ids and no aria-labelledby or aria-describedby" <|
            \_ ->
                let
                    root =
                        checkbox [ Checkbox.id "terms", Checkbox.label "I accept the terms" ]
                in
                Expect.all
                    [ \r -> Query.hasNot [ aria "aria-labelledby" "terms-label" ] (inputOf r)
                    , \r -> count [ Selector.id "terms-label" ] 0 r
                    , \r -> Query.find [ Selector.class "klar-check__label" ] r |> Query.has [ Selector.text "I accept the terms" ]
                    ]
                    root
        , test "an empty error is no error: no red box, no aria-invalid, no element" <|
            \_ ->
                let
                    root =
                        checkbox [ Checkbox.id "terms", Checkbox.label "I accept the terms", Checkbox.error "" ]
                in
                Expect.all
                    [ \r -> Query.hasNot [ Selector.class "klar-check--invalid" ] r
                    , \r -> Query.hasNot [ aria "aria-invalid" "true" ] (inputOf r)
                    , \r -> count [ Selector.id "terms-error" ] 0 r
                    , \r -> count [ Selector.class "klar-check__error" ] 0 r
                    ]
                    root
        , test "a blank error on a bare checkbox is no error either" <|
            \_ ->
                checkbox [ Checkbox.ariaLabel "Select all orders", Checkbox.error "   " ]
                    |> Expect.all
                        [ Query.hasNot [ Selector.class "klar-check--invalid" ]
                        , Query.has [ Selector.class "klar-check--bare" ]
                        ]
        , test "a message makes the box red" <|
            \_ ->
                checkbox [ Checkbox.label "I accept the terms", Checkbox.error "Accept the terms to continue" ]
                    |> Query.has [ Selector.class "klar-check--invalid" ]
        , test "a bare checkbox has no text column and no ids to refer to" <|
            \_ ->
                let
                    root =
                        checkbox [ Checkbox.ariaLabel "Select order 1042", Checkbox.checked True ]
                in
                Expect.all
                    [ Query.has [ Selector.class "klar-check--bare" ]
                    , count [ Selector.class "klar-check__text" ] 0
                    , \r -> Query.has [ aria "aria-label" "Select order 1042" ] (inputOf r)
                    , \r -> Query.hasNot [ aria "aria-describedby" "klar-check-select__order__1042-description" ] (inputOf r)
                    ]
                    root
        , test "without an id the ids of the parts are made from the label, and the input gets none" <|
            \_ ->
                let
                    root =
                        checkbox [ Checkbox.label "Accept terms", Checkbox.error "Required" ]
                in
                Expect.all
                    [ \r -> Query.has [ aria "aria-describedby" "klar-check-accept__terms-error", aria "aria-labelledby" "klar-check-accept__terms-label" ] (inputOf r)
                    , count [ Selector.id "klar-check-accept__terms-error" ] 1
                    , count [ Selector.id "klar-check-accept__terms-label" ] 1
                    , count [ Selector.id "klar-check-accept__terms" ] 0
                    ]
                    root
        , test "toggling still sends the new value" <|
            \_ ->
                checkbox [ Checkbox.label "I accept the terms", Checkbox.onCheck Checked ]
                    |> inputOf
                    |> Event.simulate (Event.check True)
                    |> Event.expect (Checked True)
        , test "an indeterminate box still sends True" <|
            \_ ->
                checkbox [ Checkbox.ariaLabel "Select all orders", Checkbox.indeterminate True, Checkbox.onCheck Checked ]
                    |> inputOf
                    |> Event.simulate (Event.check False)
                    |> Event.expect (Checked True)
        ]



-- CHECKBOX GROUP


extras : List (CheckboxGroup.Attribute Msg) -> Query.Single Msg
extras attributes =
    CheckboxGroup.view
        ([ CheckboxGroup.id "extras"
         , CheckboxGroup.label "Extras"
         , CheckboxGroup.options
            [ CheckboxGroup.option "gift-wrap" "Gift wrap"
                |> CheckboxGroup.withDescription "Wrapped in paper."
            , CheckboxGroup.option "paper-invoice" "Paper invoice"
            ]
         ]
            ++ attributes
        )
        |> Query.fromHtml


checkboxGroupTests : Test
checkboxGroupTests =
    describe "Klar.CheckboxGroup"
        [ test "a group has no aria-invalid or aria-required, even when it is invalid and required" <|
            \_ ->
                extras [ CheckboxGroup.required, CheckboxGroup.error "Choose at least one" ]
                    |> Expect.all
                        [ Query.find [ Selector.tag "fieldset" ] >> Query.has [ role "group" ]
                        , count [ aria "aria-invalid" "true" ] 0
                        , count [ aria "aria-required" "true" ] 0
                        ]
        , test "the hint and the error message are joined to the group with aria-describedby" <|
            \_ ->
                let
                    root =
                        extras [ CheckboxGroup.hint "Pick what you need.", CheckboxGroup.error "Choose at least one" ]
                in
                Expect.all
                    [ \r -> Query.find [ Selector.tag "fieldset" ] r |> Query.has [ aria "aria-describedby" "extras-hint extras-error" ]
                    , \r -> Query.find [ Selector.id "extras-error" ] r |> Query.has [ role "alert", Selector.text "Choose at least one" ]
                    , \r -> Query.find [ Selector.id "extras-hint" ] r |> Query.has [ Selector.text "Pick what you need." ]
                    ]
                    root
        , test "without a hint or an error the group refers to nothing" <|
            \_ ->
                extras []
                    |> Query.find [ Selector.tag "fieldset" ]
                    |> Expect.all
                        [ Query.hasNot [ aria "aria-describedby" "extras-hint" ]
                        , Query.hasNot [ aria "aria-describedby" "extras-error" ]
                        , Query.hasNot [ aria "aria-describedby" "extras-hint extras-error" ]
                        ]
        , test "the empty boxes are still marked red by an error" <|
            \_ ->
                extras [ CheckboxGroup.error "Choose at least one" ]
                    |> Query.find [ Selector.tag "fieldset" ]
                    |> Query.has [ Selector.class "klar-checkgroup--invalid" ]
        , test "the fieldset has the id <id>-group and the first checkbox has the id of the group" <|
            \_ ->
                let
                    root =
                        extras []
                in
                Expect.all
                    [ count [ Selector.id "extras-group", Selector.tag "fieldset" ] 1
                    , count [ Selector.id "extras", Selector.tag "input" ] 1
                    , count [ Selector.id "extras-1", Selector.tag "input" ] 1
                    ]
                    root
        , test "the hint of the group and the description of the first option do not share an id" <|
            \_ ->
                let
                    root =
                        extras [ CheckboxGroup.hint "Pick what you need." ]
                in
                Expect.all
                    [ count [ Selector.id "extras-hint" ] 1
                    , count [ Selector.id "extras-description" ] 1
                    , \r -> Query.find [ Selector.id "extras-description" ] r |> Query.has [ Selector.text "Wrapped in paper." ]
                    ]
                    root
        , test "the description of an option is named by its checkbox and is not part of its name" <|
            \_ ->
                extras []
                    |> Query.find [ Selector.id "extras", Selector.tag "input" ]
                    |> Query.has [ aria "aria-labelledby" "extras-label", aria "aria-describedby" "extras-description" ]
        ]



-- RADIO GROUP AND SEGMENTED CONTROL (the role radiogroup allows both states)


deliveryOptions : List Radio.Option
deliveryOptions =
    [ Radio.option "standard" "Standard", Radio.option "express" "Express" ]


radioGroupTests : Test
radioGroupTests =
    describe "Klar.Radio"
        [ test "a radio group is a radiogroup and keeps aria-required, aria-invalid and aria-describedby" <|
            \_ ->
                Radio.view
                    [ Radio.id "delivery"
                    , Radio.label "Delivery"
                    , Radio.hint "Pick one."
                    , Radio.required
                    , Radio.error "Choose a delivery option"
                    , Radio.options deliveryOptions
                    ]
                    |> Query.fromHtml
                    |> Query.find [ role "radiogroup" ]
                    |> Query.has
                        [ aria "aria-required" "true"
                        , aria "aria-invalid" "true"
                        , aria "aria-describedby" "delivery-hint delivery-error"
                        ]
        ]


segmentedControlTests : Test
segmentedControlTests =
    describe "Klar.SegmentedControl"
        [ test "a segmented control is a radiogroup and keeps aria-required, aria-invalid and aria-describedby" <|
            \_ ->
                SegmentedControl.view
                    [ SegmentedControl.id "period"
                    , SegmentedControl.label "Period"
                    , SegmentedControl.hint "Pick one."
                    , SegmentedControl.required
                    , SegmentedControl.error "Choose a period"
                    , SegmentedControl.options [ SegmentedControl.option "day" "Day", SegmentedControl.option "week" "Week" ]
                    ]
                    |> Query.fromHtml
                    |> Query.find [ role "radiogroup" ]
                    |> Query.has
                        [ aria "aria-required" "true"
                        , aria "aria-invalid" "true"
                        , aria "aria-describedby" "period-hint period-error"
                        ]
        ]



-- SLIDER


slider : List (Slider.Attribute Msg) -> Query.Single Msg
slider attributes =
    Slider.view
        ([ Slider.id "discount", Slider.label "Discount", Slider.onInput Moved ] ++ attributes)
        |> Query.fromHtml


rangeSlider : List (Slider.Attribute Msg) -> Query.Single Msg
rangeSlider attributes =
    Slider.viewRange
        ([ Slider.id "quantity", Slider.label "Order quantity", Slider.onRangeInput MovedRange ] ++ attributes)
        |> Query.fromHtml


sliderTests : Test
sliderTests =
    describe "Klar.Slider"
        [ test "the input of a slider has aria-invalid and aria-describedby but never aria-required" <|
            \_ ->
                slider [ Slider.hint "Up to 50 %.", Slider.required, Slider.error "Too high" ]
                    |> inputOf
                    |> Expect.all
                        [ Query.has [ Selector.id "discount", aria "aria-invalid" "true", aria "aria-describedby" "discount-hint discount-error" ]
                        , Query.hasNot [ aria "aria-required" "true" ]
                        ]
        , test "a slider without an error is not marked invalid" <|
            \_ ->
                slider [ Slider.required ]
                    |> inputOf
                    |> Expect.all
                        [ Query.hasNot [ aria "aria-invalid" "true" ]
                        , Query.hasNot [ aria "aria-required" "true" ]
                        ]
        , test "the wrapper of a range slider is a group with aria-describedby, and only the two thumbs are aria-invalid" <|
            \_ ->
                -- (Query.has and Query.hasNot also look at the descendants, so the
                -- elements that carry the attribute are counted instead.)
                rangeSlider [ Slider.hint "At least 10.", Slider.required, Slider.error "Too few" ]
                    |> Expect.all
                        [ Query.find [ Selector.id "quantity-group" ]
                            >> Query.has [ role "group", aria "aria-describedby" "quantity-hint quantity-error" ]
                        , count [ aria "aria-invalid" "true" ] 2
                        , count [ Selector.tag "input", aria "aria-invalid" "true" ] 2
                        , count [ aria "aria-required" "true" ] 0
                        ]
        , test "both thumbs of an invalid range slider are aria-invalid, and neither is aria-required" <|
            \_ ->
                let
                    thumbs =
                        rangeSlider [ Slider.required, Slider.error "Too few" ]
                            |> Query.findAll [ Selector.tag "input" ]
                in
                Expect.all
                    [ Query.count (Expect.equal 2)
                    , Query.each (Query.has [ aria "aria-invalid" "true" ])
                    , Query.each (Query.hasNot [ aria "aria-required" "true" ])
                    ]
                    thumbs
        , test "the thumbs keep their ids and names" <|
            \_ ->
                let
                    root =
                        rangeSlider []
                in
                Expect.all
                    [ count [ Selector.id "quantity", Selector.tag "input" ] 1
                    , count [ Selector.id "quantity-upper", Selector.tag "input" ] 1
                    , count [ aria "aria-label" "From" ] 1
                    , count [ aria "aria-label" "To" ] 1
                    ]
                    root
        , test "a range slider without an error has no invalid thumb" <|
            \_ ->
                rangeSlider []
                    |> Query.findAll [ Selector.tag "input" ]
                    |> Query.each (Query.hasNot [ aria "aria-invalid" "true" ])
        ]



-- FORM


type alias Problem =
    { field : String, message : String }


problem : Problem
problem =
    { field = "email", message = "Invalid email address" }


section : String -> Html Msg
section title =
    FormLayout.section title "" []


formTests : Test
formTests =
    describe "Klar.Form"
        [ test "two sections with the same title get no DOM id that could collide" <|
            \_ ->
                let
                    root =
                        FormLayout.view [] [ section "Details", section "Details" ] |> Query.fromHtml
                in
                Expect.all
                    [ count [ Selector.tag "section" ] 2
                    , count [ Selector.id "klar-form-section-details" ] 0
                    , count [ aria "aria-labelledby" "klar-form-section-details" ] 0
                    ]
                    root
        , test "a section is named by its title" <|
            \_ ->
                let
                    root =
                        FormLayout.view [] [ section "Customer", section "Delivery" ] |> Query.fromHtml
                in
                Expect.all
                    [ Query.find [ aria "aria-label" "Customer" ] >> Query.has [ role "group", Selector.tag "section" ]
                    , Query.find [ aria "aria-label" "Delivery" ] >> Query.has [ role "group", Selector.tag "section" ]
                    , Query.find [ Selector.tag "h2", Selector.containing [ Selector.text "Customer" ] ]
                        >> Query.has [ Selector.class "klar-form-section__title" ]
                    ]
                    root
        , test "sections with the same title in two forms of one page share nothing" <|
            \_ ->
                let
                    page =
                        Html.div []
                            [ FormLayout.view [ FormLayout.id "billing" ] [ section "Details" ]
                            , FormLayout.view [ FormLayout.id "shipping" ] [ section "Details" ]
                            ]
                            |> Query.fromHtml
                in
                Expect.all
                    [ count [ Selector.tag "section" ] 2
                    , count [ Selector.id "klar-form-section-details" ] 0
                    , count [ Selector.id "billing" ] 1
                    , count [ Selector.id "shipping" ] 1
                    ]
                    page
        , test "the ids of the summary and the status line come from the id of the form" <|
            \_ ->
                let
                    page =
                        Html.div []
                            [ FormLayout.errorSummary [ FormLayout.id "billing" ] [ problem ]
                            , FormLayout.status [ FormLayout.id "billing" ] FormLayout.Submitting
                            , FormLayout.errorSummary [ FormLayout.id "shipping" ] [ problem ]
                            , FormLayout.status [ FormLayout.id "shipping" ] (FormLayout.Succeeded "Saved")
                            ]
                            |> Query.fromHtml
                in
                Expect.all
                    [ count [ Selector.id "billing-summary" ] 1
                    , count [ Selector.id "billing-status" ] 1
                    , count [ Selector.id "shipping-summary" ] 1
                    , count [ Selector.id "shipping-status" ] 1
                    , count [ Selector.id "form-summary" ] 0
                    , count [ Selector.id "form-status" ] 0
                    ]
                    page
        , test "without a form id the summary and the status line use form-summary and form-status" <|
            \_ ->
                let
                    page =
                        Html.div []
                            [ FormLayout.errorSummary [] [ problem ]
                            , FormLayout.status [] FormLayout.Submitting
                            ]
                            |> Query.fromHtml
                in
                Expect.all
                    [ count [ Selector.id "form-summary" ] 1
                    , count [ Selector.id "form-status" ] 1
                    ]
                    page
        , test "an idle status and an empty summary draw nothing" <|
            \_ ->
                Html.div []
                    [ FormLayout.errorSummary [ FormLayout.id "billing" ] []
                    , FormLayout.status [ FormLayout.id "billing" ] FormLayout.Idle
                    ]
                    |> Query.fromHtml
                    |> Expect.all
                        [ count [ Selector.id "billing-summary" ] 0
                        , count [ Selector.id "billing-status" ] 0
                        ]
        , test "the id of the form is on the form element" <|
            \_ ->
                FormLayout.view [ FormLayout.id "billing" ] []
                    |> Query.fromHtml
                    |> Query.has [ Selector.tag "form", Selector.id "billing" ]
        ]



-- FIELD


field : Field.Config
field =
    Field.empty
        |> Field.setId "email"
        |> Field.setLabel "Email"
        |> Field.setRequired True


target : List (Html.Attribute Msg) -> Query.Single Msg
target attributes =
    Html.div attributes [] |> Query.fromHtml


fieldTests : Test
fieldTests =
    describe "Klar.Field"
        [ test "describedByAttributes names the hint and the error message, and nothing else" <|
            \_ ->
                let
                    config =
                        field |> Field.setHint "Used for confirmations." |> Field.setError (Just "Invalid email address")
                in
                target (Field.describedByAttributes config)
                    |> Expect.all
                        [ Query.has [ aria "aria-describedby" "email-hint email-error" ]
                        , Query.hasNot [ aria "aria-invalid" "true" ]
                        , Query.hasNot [ aria "aria-required" "true" ]
                        , Query.hasNot [ Selector.id "email" ]
                        ]
        , test "describedByAttributes names only the hint when there is no error" <|
            \_ ->
                let
                    config =
                        field |> Field.setHint "Used for confirmations."
                in
                target (Field.describedByAttributes config)
                    |> Query.has [ aria "aria-describedby" "email-hint" ]
        , test "describedByAttributes is empty for a field without a hint or an error" <|
            \_ ->
                Field.describedByAttributes field
                    |> List.length
                    |> Expect.equal 0
        , test "controlAttributes still has the id, aria-describedby, aria-invalid and aria-required" <|
            \_ ->
                let
                    config =
                        field |> Field.setHint "Used for confirmations." |> Field.setError (Just "Invalid email address")
                in
                target (Field.controlAttributes config)
                    |> Query.has
                        [ Selector.id "email"
                        , aria "aria-describedby" "email-hint email-error"
                        , aria "aria-invalid" "true"
                        , aria "aria-required" "true"
                        ]
        ]
