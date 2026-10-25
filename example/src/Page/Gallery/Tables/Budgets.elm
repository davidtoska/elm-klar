module Page.Gallery.Tables.Budgets exposing (Model, Msg, init, update, view)

{-| A configurable budget editor, with live column presets and a read-only mode.
-}

import Html exposing (Html)
import Klar.Budget as Budget
import Klar.Button as Button
import Klar.Layout as Layout
import Klar.Locale exposing (Locale)
import Klar.Money as Money
import Klar.Switch as Switch
import Showcase.Doc as Doc


type alias Model =
    { budget : Budget.State, count : Int, readOnly : Bool }


type Msg
    = BudgetMsg Budget.Msg
    | Columns Int
    | ReadOnly Bool
    | Reset


init : Model
init =
    { budget = initial, count = 4, readOnly = False }


initial : Budget.State
initial =
    Budget.init "gallery-budget" Money.nok
        |> Budget.setRows
            [ line "Discovery and planning" "Consulting" "12.5" "hours" "950"
            , line "Interface design" "Design" "24" "hours" "1100"
            , line "Development" "Engineering" "60" "hours" "1250"
            , line "Project credit" "Adjustment" "1" "item" "-2500"
            ]


line : String -> String -> String -> String -> String -> Budget.Row
line description category quantity unit price =
    Budget.row
        [ ( "description", description ), ( "category", category ), ( "quantity", quantity ), ( "unit", unit ), ( "price", price ) ]


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        BudgetMsg inner ->
            Budget.update inner model.budget
                |> Tuple.mapBoth (\budget -> { model | budget = budget }) (Cmd.map BudgetMsg)

        Columns count ->
            ( { model
                | count = count
                , budget =
                    model.budget
                        |> Budget.setColumns
                            ([ Budget.textColumn "description" "Cost description" ]
                                ++ (if count >= 6 then
                                        [ Budget.textColumn "category" "Category" ]

                                    else
                                        []
                                   )
                                ++ (if count >= 4 then
                                        [ Budget.numberColumn "quantity" "Quantity" ]

                                    else
                                        []
                                   )
                                ++ (if count >= 5 then
                                        [ Budget.textColumn "unit" "Unit" ]

                                    else
                                        []
                                   )
                                ++ [ Budget.moneyColumn "price"
                                        (if count == 3 then
                                            "Cost"

                                         else
                                            "Unit price"
                                        )
                                   ]
                            )
                        |> Budget.setFormula
                            (if count == 3 then
                                Budget.amount "price"

                             else
                                Budget.multiply "quantity" (Budget.amount "price")
                            )
              }
            , Cmd.none
            )

        ReadOnly value ->
            ( { model | readOnly = value }, Cmd.none )

        Reset ->
            ( init, Cmd.none )


view : Locale -> Model -> Html Msg
view locale model =
    Doc.section "Budget sheet"
        "An editable budget with three to six columns. Switch the schema without losing data, enter fractional quantities, add credits, and see exact line amounts and a grand total."
        [ Doc.example
            { title = "Build a project budget"
            , description = Just "Choose the number of columns. Three columns use fixed costs; four to six use quantity × unit price. Prices and totals are in NOK."
            , code = Just "Budget.init \"project-budget\" Money.nok\n    |> Budget.setColumns\n        [ Budget.textColumn \"description\" \"Cost\"\n        , Budget.numberColumn \"quantity\" \"Hours\"\n        , Budget.moneyColumn \"price\" \"Hourly rate\"\n        ]\n    |> Budget.setFormula (Budget.multiply \"quantity\" (Budget.amount \"price\"))\n\n-- Budget.view BudgetMsg [ Budget.locale locale ] model.budget\n-- Budget.total locale model.budget"
            }
            (Layout.stack [ Layout.gap 4 ]
                [ Layout.row [ Layout.gap 2, Layout.wrap, Layout.alignCenter ]
                    (List.map
                        (\count ->
                            Button.view
                                ([ Button.small, Button.onClick (Columns count) ]
                                    ++ (if count == model.count then
                                            [ Button.primary ]

                                        else
                                            []
                                       )
                                )
                                (String.fromInt count ++ " columns")
                        )
                        [ 3, 4, 5, 6 ]
                        ++ [ Switch.view [ Switch.label "Read only", Switch.checked model.readOnly, Switch.onCheck ReadOnly, Switch.locale locale ]
                           , Button.view [ Button.small, Button.onClick Reset ] "Reset example"
                           ]
                    )
                , Budget.view BudgetMsg [ Budget.title "Website project", Budget.locale locale, Budget.readOnly model.readOnly ] model.budget
                ]
            )
        ]
