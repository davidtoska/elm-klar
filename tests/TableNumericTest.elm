module TableNumericTest exposing (suite)

import Expect
import Klar.Money as Money
import Klar.Table.Numeric as Numeric
import Test exposing (Test, test)


suite : Test
suite =
    test "table money totals keep currencies separate and add minor units exactly" <|
        \_ ->
            let
                amount currency minor =
                    Money.fromMinor currency minor |> Maybe.withDefault (Money.zero currency)

                summarize group =
                    ( Maybe.map (\money -> ( Money.currencyCode (Money.currencyOf money), Money.toMinor money )) group.total, group.count )
            in
            Numeric.moneyTotals identity [ amount Money.nok 100, amount Money.eur 200, amount Money.nok 300 ]
                |> List.map summarize
                |> Expect.equal [ ( Just ( "EUR", 200 ), 1 ), ( Just ( "NOK", 400 ), 2 ) ]
