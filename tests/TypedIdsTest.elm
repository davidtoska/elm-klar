module TypedIdsTest exposing (suite)

{-| The selects hand back the application's own id type, not a `String`.
-}

import Expect
import Klar.MultiSelect as MultiSelect
import Klar.Select as Select
import Test exposing (Test, describe, test)
import Test.Html.Query as Query
import Test.Html.Selector as Selector


type CustomerId
    = CustomerId Int


type alias Customer =
    { id : CustomerId
    , name : String
    }


customers : List Customer
customers =
    [ { id = CustomerId 1, name = "Ada Lovelace" }
    , { id = CustomerId 2, name = "Grace Hopper" }
    , { id = CustomerId 3, name = "Katherine Johnson" }
    ]


options : List (Select.Option CustomerId)
options =
    List.map (\customer -> Select.option customer.id customer.name) customers


suite : Test
suite =
    describe "typed ids"
        [ describe "Select"
            [ test "the value is the id that was set, with its own type" <|
                \_ ->
                    Select.init "customer"
                        |> Select.setValue (CustomerId 2)
                        |> Select.value
                        |> Expect.equal (Just (CustomerId 2))
            , test "a select shows the label of the option whose id was set" <|
                \_ ->
                    Select.view identity [ Select.label "Customer", Select.options options ] (Select.init "customer" |> Select.setValue (CustomerId 3))
                        |> Query.fromHtml
                        |> Query.has [ Selector.text "Katherine Johnson" ]
            , test "an id that no option has is shown as an unknown value, not as a guess" <|
                \_ ->
                    Select.view identity [ Select.label "Customer", Select.options options ] (Select.init "customer" |> Select.setValue (CustomerId 99))
                        |> Query.fromHtml
                        |> Query.has [ Selector.text "Unknown value" ]
            , test "valueText says how to write an id that no option has" <|
                \_ ->
                    Select.view
                        identity
                        [ Select.label "Customer"
                        , Select.options options
                        , Select.valueText (\(CustomerId n) -> "Customer #" ++ String.fromInt n)
                        ]
                        (Select.init "customer" |> Select.setValue (CustomerId 99))
                        |> Query.fromHtml
                        |> Query.has [ Selector.text "Customer #99" ]
            , test "setOption stores the id of the option" <|
                \_ ->
                    Select.init "customer"
                        |> Select.setOption (Select.option (CustomerId 7) "Annie Easley")
                        |> Select.value
                        |> Expect.equal (Just (CustomerId 7))
            , test "clear forgets the id" <|
                \_ ->
                    Select.init "customer"
                        |> Select.setValue (CustomerId 1)
                        |> Select.clear
                        |> Select.value
                        |> Expect.equal Nothing
            ]
        , describe "MultiSelect"
            [ test "the values are the ids that were set, in order, without duplicates" <|
                \_ ->
                    MultiSelect.init "customers"
                        |> MultiSelect.setValues [ CustomerId 3, CustomerId 1, CustomerId 3 ]
                        |> MultiSelect.values
                        |> Expect.equal [ CustomerId 3, CustomerId 1 ]
            , test "the chips show the labels of the options" <|
                \_ ->
                    MultiSelect.view identity
                        [ MultiSelect.label "Customers", MultiSelect.options options ]
                        (MultiSelect.init "customers" |> MultiSelect.setValues [ CustomerId 1, CustomerId 2 ])
                        |> Query.fromHtml
                        |> Query.has [ Selector.text "Ada Lovelace", Selector.text "Grace Hopper" ]
            , test "setOptions stores the ids of the options" <|
                \_ ->
                    MultiSelect.init "customers"
                        |> MultiSelect.setOptions [ Select.option (CustomerId 5) "Mary Jackson" ]
                        |> MultiSelect.values
                        |> Expect.equal [ CustomerId 5 ]
            , test "clear forgets all the ids" <|
                \_ ->
                    MultiSelect.init "customers"
                        |> MultiSelect.setValues [ CustomerId 1, CustomerId 2 ]
                        |> MultiSelect.clear
                        |> MultiSelect.values
                        |> Expect.equal []
            ]
        ]
