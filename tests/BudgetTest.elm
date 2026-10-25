module BudgetTest exposing (suite)

import Expect
import Fuzz
import Html.Attributes as Attr
import Klar.Budget as Budget
import Klar.Locale as Locale
import Klar.Money as Money
import Test exposing (Test, describe, fuzz2, test)
import Test.Html.Event as Event
import Test.Html.Query as Query
import Test.Html.Selector as Selector


budget : List Budget.Row -> Budget.State
budget values =
    Budget.init "budget-test" Money.nok |> Budget.setRows values


line : String -> String -> Budget.Row
line quantity price =
    Budget.row [ ( "description", "Work" ), ( "quantity", quantity ), ( "price", price ) ]


minorTotal : Budget.State -> Result String Int
minorTotal state =
    Budget.total Locale.en state
        |> Result.map Money.toMinor
        |> Result.mapError (Budget.problemText Locale.en)


suite : Test
suite =
    describe "Klar.Budget"
        [ test "an empty budget has an exact zero total" <|
            \_ -> minorTotal (budget []) |> Expect.equal (Ok 0)
        , test "fractional hours, prices and credits sum to the displayed line totals" <|
            \_ -> minorTotal (budget [ line "12.5" "950", line "24" "1100", line "60" "1250", line "1" "-2500" ]) |> Expect.equal (Ok 11077500)
        , test "each half-cent rounds away from zero before the grand total" <|
            \_ -> minorTotal (budget [ line "0.5" "0.01", line "0.5" "0.01" ]) |> Expect.equal (Ok 2)
        , test "negative half-cent rounds away from zero" <|
            \_ -> minorTotal (budget [ line "-0.5" "0.01" ]) |> Expect.equal (Ok -1)
        , test "decimal comma and six-place quantities are exact" <|
            \_ -> minorTotal (budget [ line "0,000001" "1000000" ]) |> Expect.equal (Ok 100)
        , test "zero is a valid quantity and price" <|
            \_ -> minorTotal (budget [ line "0" "123", line "2" "0" ]) |> Expect.equal (Ok 0)
        , test "incomplete lines block the total rather than silently disappearing" <|
            \_ -> minorTotal (budget [ line "2" "100", line "" "50" ]) |> Expect.err
        , test "malformed, excessive-precision and non-finite quantities are refused" <|
            \_ ->
                [ "no", "1.2.3", "0.0000001", "1e3", "NaN", "Infinity", "9007199254740992", "-", "." ]
                    |> List.map (\quantity -> minorTotal (budget [ line quantity "1" ]) |> Result.toMaybe)
                    |> Expect.equal (List.repeat 9 Nothing)
        , test "prices cannot silently lose decimals" <|
            \_ -> minorTotal (budget [ line "1" "1.005" ]) |> Expect.err
        , test "line arithmetic overflow is reported" <|
            \_ -> minorTotal (budget [ line "2" "90071992547409.91" ]) |> Expect.err
        , test "grand total overflow is reported" <|
            \_ -> minorTotal (budget [ line "1" "90071992547409.91", line "1" "0.01" ]) |> Expect.err
        , test "a fixed-cost formula does not require a quantity" <|
            \_ -> budget [ Budget.row [ ( "cost", "125.50" ) ] ] |> Budget.setFormula (Budget.amount "cost") |> minorTotal |> Expect.equal (Ok 12550)
        , test "a custom formula combines fees, rates and two multipliers" <|
            \_ ->
                budget [ Budget.row [ ( "days", "2" ), ( "people", "3" ), ( "rate", "100" ), ( "fee", "50" ) ] ]
                    |> Budget.setFormula (Budget.add (Budget.multiply "days" (Budget.multiply "people" (Budget.amount "rate"))) (Budget.amount "fee"))
                    |> minorTotal
                    |> Expect.equal (Ok 65000)
        , test "Norwegian grouped prices agree between the view and the reader" <|
            \_ ->
                Budget.total Locale.nb (budget [ line "2,5" "1.250,50" ])
                    |> Result.map Money.toMinor
                    |> Result.mapError (Budget.problemText Locale.nb)
                    |> Expect.equal (Ok 312625)
        , fuzz2 (Fuzz.intRange -10000 10000) (Fuzz.intRange 0 10000) "integer quantity multiplication stays exact" <|
            \quantity price ->
                minorTotal (budget [ line (String.fromInt quantity) (String.fromInt price) ])
                    |> Expect.equal (Ok (quantity * price * 100))
        , test "changing columns preserves hidden fields and calculations" <|
            \_ ->
                budget [ line "3" "10" ]
                    |> Budget.setColumns [ Budget.textColumn "description" "Cost" ]
                    |> Expect.all
                        [ minorTotal >> Expect.equal (Ok 3000)
                        , Budget.rows >> List.head >> Maybe.map (Budget.cellValue "quantity") >> Expect.equal (Just "3")
                        ]
        , test "there are never more than six columns, including the final total" <|
            \_ ->
                budget []
                    |> Budget.setColumns (List.range 1 8 |> List.map (\n -> Budget.textColumn (String.fromInt n) (String.fromInt n)))
                    |> Budget.view identity []
                    |> Query.fromHtml
                    |> Query.find [ Selector.tag "thead" ]
                    |> Query.findAll [ Selector.tag "th" ]
                    |> Query.count (Expect.equal 6)
        , test "duplicate and empty field keys do not create duplicate inputs" <|
            \_ ->
                budget [ line "1" "2" ]
                    |> Budget.setColumns [ Budget.textColumn "" "Empty", Budget.textColumn "description" "Cost", Budget.textColumn "description" "Again" ]
                    |> Budget.view identity []
                    |> Query.fromHtml
                    |> Query.findAll [ Selector.tag "input" ]
                    |> Query.count (Expect.equal 1)
        , test "read-only sheets have no editable inputs or action buttons" <|
            \_ ->
                Budget.view identity [ Budget.readOnly True ] (budget [ line "2" "10" ])
                    |> Query.fromHtml
                    |> Query.hasNot [ Selector.tag "input" ]
        , test "the add action creates a line with usable defaults" <|
            \_ ->
                let
                    state =
                        budget []
                in
                Budget.view identity [] state
                    |> Query.fromHtml
                    |> Query.find [ Selector.id "budget-test-add" ]
                    |> Event.simulate Event.click
                    |> Event.toResult
                    |> Result.map (\msg -> Budget.update msg state |> Tuple.first |> Budget.rows |> List.map (Budget.cellValue "quantity"))
                    |> Expect.equal (Ok [ "1" ])
        , test "typing preserves the raw text and recalculates" <|
            \_ ->
                let
                    state =
                        budget [ line "2" "10" ]
                in
                Budget.view identity [] state
                    |> Query.fromHtml
                    |> Query.find [ Selector.tag "input", Selector.attribute (Attr.attribute "aria-label" "Quantity, line 1") ]
                    |> Event.simulate (Event.input "3,50")
                    |> Event.toResult
                    |> Result.map
                        (\msg ->
                            let
                                edited =
                                    Budget.update msg state |> Tuple.first
                            in
                            ( minorTotal edited, Budget.rows edited |> List.head |> Maybe.map (Budget.cellValue "quantity") )
                        )
                    |> Expect.equal (Ok ( Ok 3500, Just "3,50" ))
        , test "removing a line recalculates the total" <|
            \_ ->
                let
                    state =
                        budget [ line "2" "10", line "3" "20" ]
                in
                Budget.view identity [] state
                    |> Query.fromHtml
                    |> Query.find [ Selector.attribute (Attr.attribute "aria-label" "Remove line 1") ]
                    |> Event.simulate Event.click
                    |> Event.toResult
                    |> Result.map (\msg -> Budget.update msg state |> Tuple.first |> minorTotal)
                    |> Expect.equal (Ok (Ok 6000))
        , test "the empty state and built-in labels are localized" <|
            \_ ->
                Budget.view identity [ Budget.locale Locale.nb ] (budget [])
                    |> Query.fromHtml
                    |> Query.has [ Selector.text "Legg til kostnad", Selector.text "Totalt budsjett" ]
        , test "an invalid numeric field is marked and its explanation uses the visible heading" <|
            \_ ->
                Budget.view identity [] (budget [ line "invalid" "20" ])
                    |> Query.fromHtml
                    |> Expect.all
                        [ Query.has [ Selector.text "Quantity: enter a number with up to six decimal places" ]
                        , Query.find [ Selector.attribute (Attr.attribute "aria-label" "Quantity, line 1") ]
                            >> Query.has [ Selector.attribute (Attr.attribute "aria-invalid" "true") ]
                        ]
        ]
