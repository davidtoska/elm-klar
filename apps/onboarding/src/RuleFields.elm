module RuleFields exposing (fields, describe)

{-| What a pricing rule can talk about. The rule builder only knows strings, so the
application's own ids are written as keys here (KLAR GAP: see FRICTION.md O-002).
-}

import Domain exposing (..)
import Klar.Locale as Locale
import Klar.Rule as Rule exposing (Choice, FieldKind(..))


fields : { a | categories : List Category, countries : List Country } -> List (Rule.Field ())
fields ref =
    [ Rule.bareField "category"
        "Category"
        (ChoiceKind
            -- KLAR GAP: Rule.Choice values are Strings, the application's CategoryId has to be written as a key
            (List.map (\c -> { value = categoryKey c.id, label = c.name }) ref.categories)
        )
        |> Rule.withOperators [ Rule.Is, Rule.IsNot, Rule.IsAnyOf ]
    , Rule.bareField "quantity" "Quantity" NumberKind
        |> Rule.withOperators [ Rule.GreaterThan, Rule.GreaterOrEqual, Rule.LessThan, Rule.Between ]
    , Rule.bareField "orderTotal" "Order total" NumberKind
        |> Rule.withOperators [ Rule.GreaterThan, Rule.GreaterOrEqual, Rule.LessThan, Rule.Between ]
    , Rule.bareField "destination"
        "Destination country"
        (ChoiceKind
            (List.map (\c -> { value = countryKey c.id, label = c.name }) ref.countries)
        )
        |> Rule.withOperators [ Rule.Is, Rule.IsNot, Rule.IsAnyOf ]
    ]


describe : { a | categories : List Category, countries : List Country } -> Rule.Rule -> String
describe ref rule =
    Rule.describe Locale.en (fields ref) rule
