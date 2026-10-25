module Klar.Table.Numeric exposing (..)

{-| Exact monetary aggregates and locale-aware numeric values shared by table columns and export.
-}

import Dict exposing (Dict)
import Klar.Format as Format
import Klar.Locale as Locale exposing (Locale)
import Klar.Money as Money exposing (Money)
import Klar.Table.Types exposing (Align(..), Attribute(..), Column(..), ColumnAttribute(..), ColumnConfig, ColumnId(..), Config, Ctx, Data, DataStatus(..), Direction(..), Draft(..), Filter(..), FilterKind(..), Footer(..), Model, MoneyTotal, Msg(..), Picked(..), Popup(..), Query, RowInfo, Rows(..), Selection(..), SortBy(..), Source(..), State(..))


{-| An amount in whole units of its currency (12.5 for 12,50 kroner), for sorting
and the range filter.
-}
majorAmount : Money -> Float
majorAmount amount =
    toFloat (Money.toMinor amount) / toFloat (10 ^ Money.decimals (Money.currencyOf amount))


{-| The amounts of a money column added up exactly, one total for each currency in
the order of the currency codes (so that sorting or filtering the rows never moves
them), with the number of amounts in each.
-}
moneyTotals : (row -> Money) -> List row -> List MoneyTotal
moneyTotals toMoney someRows =
    let
        add row groups =
            let
                amount =
                    toMoney row

                code =
                    Money.currencyCode (Money.currencyOf amount)
            in
            case Dict.get code groups of
                Just group ->
                    Dict.insert code
                        { total = group.total |> Maybe.andThen (\running -> Result.toMaybe (Money.add running amount))
                        , count = group.count + 1
                        }
                        groups

                Nothing ->
                    Dict.insert code { total = Just amount, count = 1 } groups
    in
    List.foldl add Dict.empty someRows
        |> Dict.values


{-| A number with the locale's decimal separator and no thousands separator,
which spreadsheets read as a number.
-}
plainDecimal : Locale -> Int -> Float -> String
plainDecimal loc decimals n =
    Format.decimal loc decimals n
        |> String.replace (Locale.thousandSeparator loc) ""
        |> String.replace "−" "-"


formatNumber : Locale -> Int -> Float -> String
formatNumber loc decimals n =
    if decimals <= 0 && toFloat (round n) == n then
        Format.int loc (round n)

    else
        Format.decimal loc (max 1 decimals) n
