module StepperTest exposing (suite)

{-| `Klar.Stepper`: linear by default with `onSelect`, `nonLinear`, where
`aria-current` sits, the Tab stop of a horizontal row, the status words.
-}

import Expect
import Html exposing (Html)
import Html.Attributes as Attr
import Klar.Locale as Locale
import Klar.Stepper as Stepper
import Test exposing (Test, describe, test)
import Test.Html.Event as Event
import Test.Html.Query as Query
import Test.Html.Selector as Selector


type Msg
    = GoTo Int


steps : List Stepper.Step
steps =
    [ Stepper.step "Customer"
    , Stepper.step "Shipping"
    , Stepper.step "Payment"
    , Stepper.step "Review"
    ]


stepper : List (Stepper.Attribute Msg) -> Html Msg
stepper attributes =
    Stepper.view attributes steps


suite : Test
suite =
    describe "Klar.Stepper"
        [ test "with onSelect the steps up to the current one are buttons, the later ones are not" <|
            \_ ->
                stepper [ Stepper.current 1, Stepper.onSelect GoTo ]
                    |> Query.fromHtml
                    |> Query.findAll [ Selector.tag "button" ]
                    |> Query.count (Expect.equal 2)
        , test "a step that is done sends its index" <|
            \_ ->
                stepper [ Stepper.current 2, Stepper.onSelect GoTo ]
                    |> Query.fromHtml
                    |> Query.findAll [ Selector.tag "button" ]
                    |> Query.first
                    |> Event.simulate Event.click
                    |> Event.expect (GoTo 0)
        , test "nonLinear makes every step a button" <|
            \_ ->
                stepper [ Stepper.current 1, Stepper.onSelect GoTo, Stepper.nonLinear ]
                    |> Query.fromHtml
                    |> Query.findAll [ Selector.tag "button" ]
                    |> Query.count (Expect.equal 4)
        , test "a disabled step is a disabled button" <|
            \_ ->
                Stepper.view [ Stepper.current 1, Stepper.onSelect GoTo ] [ Stepper.step "Customer" |> Stepper.disabledStep, Stepper.step "Shipping" ]
                    |> Query.fromHtml
                    |> Query.findAll [ Selector.tag "button" ]
                    |> Query.first
                    |> Query.has [ Selector.disabled True ]
        , test "without onSelect the current step is marked on the list item, not on a plain element" <|
            \_ ->
                stepper [ Stepper.current 1 ]
                    |> Query.fromHtml
                    |> Query.find [ Selector.attribute (Attr.attribute "aria-current" "step") ]
                    |> Query.has [ Selector.tag "li", Selector.class "klar-stepper__step--current" ]
        , test "with onSelect the current step is marked on its button" <|
            \_ ->
                stepper [ Stepper.current 1, Stepper.onSelect GoTo ]
                    |> Query.fromHtml
                    |> Query.find [ Selector.attribute (Attr.attribute "aria-current" "step") ]
                    |> Query.has [ Selector.tag "button" ]
        , test "exactly one step is current" <|
            \_ ->
                stepper [ Stepper.current 2 ]
                    |> Query.fromHtml
                    |> Query.findAll [ Selector.attribute (Attr.attribute "aria-current" "step") ]
                    |> Query.count (Expect.equal 1)
        , test "a horizontal row without buttons can take the focus, to be scrolled" <|
            \_ ->
                stepper [ Stepper.current 1 ]
                    |> Query.fromHtml
                    |> Query.has [ Selector.attribute (Attr.tabindex 0) ]
        , test "a row with step buttons adds no Tab stop of its own" <|
            \_ ->
                stepper [ Stepper.current 1, Stepper.onSelect GoTo ]
                    |> Query.fromHtml
                    |> Query.find [ Selector.tag "ol" ]
                    |> Query.hasNot [ Selector.attribute (Attr.tabindex 0) ]
        , test "the status of a step is said in words, in Norwegian too" <|
            \_ ->
                Stepper.view [ Stepper.current 2, Stepper.locale Locale.nb ] (steps ++ [ Stepper.step "Extra" |> Stepper.failed ])
                    |> Query.fromHtml
                    |> Expect.all
                        [ Query.has [ Selector.text " (fullført)" ]
                        , Query.has [ Selector.text " (har feil)" ]
                        ]
        , test "progress is a polite status" <|
            \_ ->
                Stepper.progress [ Stepper.current 1 ] steps
                    |> Query.fromHtml
                    |> Query.has [ Selector.attribute (Attr.attribute "role" "status"), Selector.text "Step 2 of 4" ]
        ]
