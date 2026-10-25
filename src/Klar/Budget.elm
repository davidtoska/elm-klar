module Klar.Budget exposing
    ( view, Attribute, title, totalLabel, readOnly, locale
    , State, Msg, init, update, setColumns, setFormula, setRows, rows
    , Column, textColumn, numberColumn, moneyColumn, Row, row, cellValue
    , Formula, amount, multiply, add, lineTotal, total, Problem, problemText
    )

{-| An editable budget sheet with up to six columns, calculated line amounts and
an exact grand total. The final column is always the calculated amount.

Use when: people enter cost descriptions, quantities and prices to build a budget.
Do not use when: displaying or sorting existing records, use `Klar.Table`.
Quick path: `init`, `setRows`, `update`, `view`, `total`

    import Klar.Budget as Budget
    import Klar.Money as Money


    -- model field
    -- budget : Budget.State
    initialBudget : Budget.State
    initialBudget =
        Budget.init "project-budget" Money.nok
            |> Budget.setRows
                [ Budget.row
                    [ ( "description", "Design" )
                    , ( "quantity", "12.5" )
                    , ( "price", "950" )
                    ]
                ]

    -- update branch
    -- BudgetMsg inner ->
    --     let
    --         ( budget, cmd ) = Budget.update inner model.budget
    --     in
    --     ( { model | budget = budget }, Cmd.map BudgetMsg cmd )
    -- view
    -- Budget.view BudgetMsg [ Budget.title "Project budget" ] model.budget

The default columns are description, quantity and unit price, plus the calculated
amount. `setColumns` supplies up to five editable columns; the total makes six.
`setFormula` chooses the calculation independently: `amount "cost"` for a fixed
cost, `multiply "hours" (amount "rate")` for hourly work, or `add` to combine costs.
Hidden fields remain in the rows when the visible columns change.

Prices use `Klar.Money.parse`, quantities accept a dot or comma and up to six
decimal places, without thousands punctuation (spaces are accepted). Multiplication
uses exact integer ratios and rounds half away from zero at each step. The grand
total adds the displayed, rounded line amounts. Invalid or incomplete lines show
an error and block the grand total; they are never silently counted as zero.
Negative quantities and prices support credits. Typed text is kept verbatim.

Read the rows to save them; each row's fields can be read with `cellValue`. No
network, subscriptions or application-specific record types are required. The
currency is fixed at initialization, so changing currencies requires an explicit
new budget. Native inputs support Tab, Shift+Tab, selection, copy and paste.


# View

@docs view, Attribute, title, totalLabel, readOnly, locale


# State

@docs State, Msg, init, update, setColumns, setFormula, setRows, rows


# Columns and rows

@docs Column, textColumn, numberColumn, moneyColumn, Row, row, cellValue


# Calculations

@docs Formula, amount, multiply, add, lineTotal, total, Problem, problemText

-}

import Char
import Dict exposing (Dict)
import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Events
import Html.Keyed as Keyed
import Klar.Icon as Icon
import Klar.Internal as Internal
import Klar.Locale as Locale exposing (Locale)
import Klar.Money as Money exposing (Currency, Money)


{-| Budget data, schema and formula. All input text lives here.
-}
type State
    = State
        { id : String
        , currency : Currency
        , columns : List Column
        , formula : Formula
        , entries : List ( Int, Row )
        , nextId : Int
        }


{-| Internal edits and row actions. Pass them to `update`.
-}
type Msg
    = Edit Int String String
    | Append
    | Remove Int
    | NoOp


{-| One editable column with a stable, nonempty field key and a visible label.
-}
type Column
    = Column String String Kind


type Kind
    = Text
    | Number
    | Price


{-| A description, category, unit or other text field.
-}
textColumn : String -> String -> Column
textColumn key label =
    Column key label Text


{-| A numeric field, such as hours or quantity. It affects the result only when
referenced by `multiply` in the formula.
-}
numberColumn : String -> String -> Column
numberColumn key label =
    Column key label Number


{-| A price field in the budget currency. Reference it with `amount`.
-}
moneyColumn : String -> String -> Column
moneyColumn key label =
    Column key label Price


{-| The values in one budget line, independent of its position in the sheet.
-}
type Row
    = Row (Dict String String)


{-| Make a line from field keys and their raw text. Missing fields read as empty.
-}
row : List ( String, String ) -> Row
row fields =
    Row (Dict.fromList fields)


{-| Read the raw text of a field, or an empty string if absent.
-}
cellValue : String -> Row -> String
cellValue key (Row fields) =
    Dict.get key fields |> Maybe.withDefault ""


{-| A calculation tree. It holds field keys, never functions.
-}
type Formula
    = Amount String
    | Multiply String Formula
    | Add Formula Formula


{-| Read a money field, such as a fixed expense or unit price.
-}
amount : String -> Formula
amount =
    Amount


{-| Multiply a formula by a numeric field, for example
`multiply "hours" (amount "rate")`. Each step rounds to the currency's minor unit.
-}
multiply : String -> Formula -> Formula
multiply =
    Multiply


{-| Add two formulas, for example a fixed fee plus hours times rate.
-}
add : Formula -> Formula -> Formula
add =
    Add


{-| Start an empty budget in one currency. The id must be unique on the page.
Default keys: `description`, `quantity`, `price`; formula: quantity times price.
-}
init : String -> Currency -> State
init id currency =
    State
        { id = Internal.sanitizeId id
        , currency = currency
        , columns = []
        , formula = multiply "quantity" (amount "price")
        , entries = []
        , nextId = 0
        }


{-| Replace the editable columns. The first five distinct, nonempty keys are
used; the calculated total is always appended. Existing row data is preserved.
An empty list restores the default columns. Configure `setFormula` as well when
using field keys other than the defaults.
-}
setColumns : List Column -> State -> State
setColumns columns (State state) =
    let
        insert ((Column key _ _) as column) result =
            if String.trim key == "" || List.any (\(Column other _ _) -> other == key) result then
                result

            else
                result ++ [ column ]
    in
    State { state | columns = List.foldl insert [] columns |> List.take 5 }


{-| Replace the calculation for every line. The formula may reference preserved
fields that are currently hidden from the sheet.
-}
setFormula : Formula -> State -> State
setFormula formula (State state) =
    State { state | formula = formula }


{-| Replace the lines, preserving all their raw field values. Use to load or reset
a budget. Row identities are renewed to avoid reusing a focused input for new data.
-}
setRows : List Row -> State -> State
setRows values (State state) =
    State
        { state
            | entries = List.indexedMap (\index value -> ( state.nextId + index, value )) values
            , nextId = state.nextId + List.length values
        }


{-| All lines in their displayed order, including incomplete ones.
-}
rows : State -> List Row
rows (State state) =
    List.map Tuple.second state.entries


{-| A missing value, invalid number or failed exact-money calculation.
-}
type Problem
    = Missing String
    | InvalidQuantity String
    | MoneyProblem String Money.Problem


{-| Explain a calculation problem in English or Norwegian Bokmål.
-}
problemText : Locale -> Problem -> String
problemText language problem =
    case problem of
        Missing key ->
            Locale.pick language { en = "Enter a value for " ++ key, nb = "Fyll inn " ++ key }

        InvalidQuantity key ->
            Locale.pick language
                { en = key ++ ": enter a number with up to six decimal places"
                , nb = key ++ ": skriv et tall med opptil seks desimaler"
                }

        MoneyProblem key problem_ ->
            (if key == "" then
                ""

             else
                key ++ ": "
            )
                ++ Money.problemText language problem_


{-| Calculate a single line with the configured formula and currency. Pass the
same locale as the view so ambiguous grouped prices are interpreted consistently.
-}
lineTotal : Locale -> State -> Row -> Result Problem Money
lineTotal =
    lineTotalIn


lineTotalIn : Locale -> State -> Row -> Result Problem Money
lineTotalIn language (State state) values =
    let
        required key =
            if String.trim (cellValue key values) == "" then
                Err (Missing key)

            else
                Ok (cellValue key values)

        evaluate formula =
            case formula of
                Amount key ->
                    required key
                        |> Result.andThen (Money.parse language state.currency >> Result.mapError (MoneyProblem key))

                Multiply key inner ->
                    Result.map2 Tuple.pair
                        (required key |> Result.andThen (ratio >> Result.fromMaybe (InvalidQuantity key)))
                        (evaluate inner)
                        |> Result.andThen
                            (\( ( numerator, denominator ), value ) ->
                                Money.fraction numerator denominator value |> Result.mapError (MoneyProblem key)
                            )

                Add left right ->
                    Result.map2 Tuple.pair (evaluate left) (evaluate right)
                        |> Result.andThen (\( a, b ) -> Money.add a b |> Result.mapError (MoneyProblem ""))
    in
    evaluate state.formula


ratio : String -> Maybe ( Int, Int )
ratio raw =
    let
        cleaned =
            raw |> String.trim |> String.replace " " "" |> String.replace "\u{00A0}" "" |> String.replace "," "."

        unsigned =
            if String.startsWith "-" cleaned || String.startsWith "+" cleaned then
                String.dropLeft 1 cleaned

            else
                cleaned

        sign =
            if String.startsWith "-" cleaned then
                -1

            else
                1

        build whole fraction =
            let
                digits =
                    whole ++ fraction
            in
            if digits == "" || not (String.all Char.isDigit digits) || String.length fraction > 6 then
                Nothing

            else
                String.toInt digits
                    |> Maybe.andThen
                        (\n ->
                            if n > 9007199254740991 then
                                Nothing

                            else
                                Just ( sign * n, 10 ^ String.length fraction )
                        )
    in
    case String.split "." unsigned of
        [ whole ] ->
            build whole ""

        [ whole, fraction ] ->
            build whole fraction

        _ ->
            Nothing


{-| The sum of the rounded line amounts. Empty budgets total zero. Any incomplete,
invalid or overflowing line makes the result an error instead of a partial total.
-}
total : Locale -> State -> Result Problem Money
total =
    totalIn


totalIn : Locale -> State -> Result Problem Money
totalIn language ((State state) as budget) =
    List.foldl
        (\( _, values ) accumulated ->
            Result.map2 Tuple.pair accumulated (lineTotalIn language budget values)
                |> Result.andThen (\( a, b ) -> Money.add a b |> Result.mapError (MoneyProblem ""))
        )
        (Ok (Money.zero state.currency))
        state.entries


{-| Apply an edit or add/remove a line. New numeric fields start at one, price
fields at zero, and text fields empty. Add and remove move focus to a useful control.
-}
update : Msg -> State -> ( State, Cmd Msg )
update msg ((State state) as budget) =
    case msg of
        Edit id key value ->
            ( State
                { state
                    | entries =
                        List.map
                            (\( rowId, (Row fields) as values ) ->
                                ( rowId
                                , if id == rowId then
                                    Row (Dict.insert key value fields)

                                  else
                                    values
                                )
                            )
                            state.entries
                }
            , Cmd.none
            )

        Append ->
            let
                columns =
                    columnsIn Locale.default budget

                initial (Column key _ kind) =
                    ( key
                    , case kind of
                        Text ->
                            ""

                        Number ->
                            "1"

                        Price ->
                            "0"
                    )
            in
            ( State { state | entries = state.entries ++ [ ( state.nextId, row (List.map initial columns) ) ], nextId = state.nextId + 1 }
            , Internal.focus (inputId state.id state.nextId 0) NoOp
            )

        Remove id ->
            ( State { state | entries = List.filter (Tuple.first >> (/=) id) state.entries }
            , Internal.focus (state.id ++ "-add") NoOp
            )

        NoOp ->
            ( budget, Cmd.none )


{-| View configuration; later attributes override earlier ones.
-}
type Attribute msg
    = Attribute (Config -> Config)


type alias Config =
    { title : Maybe String, totalLabel : Maybe String, readOnly : Bool, locale : Locale }


{-| Heading for the sheet. Defaults to the localized word "Budget".
-}
title : String -> Attribute msg
title value =
    Attribute (\config -> { config | title = Just value })


{-| Label for the grand total. Defaults to "Total budget".
-}
totalLabel : String -> Attribute msg
totalLabel value =
    Attribute (\config -> { config | totalLabel = Just value })


{-| Show values and calculations without inputs or add/remove actions.
-}
readOnly : Bool -> Attribute msg
readOnly value =
    Attribute (\config -> { config | readOnly = value })


{-| Language and price parsing conventions; defaults to English.
-}
locale : Locale -> Attribute msg
locale value =
    Attribute (\config -> { config | locale = value })


columnsIn : Locale -> State -> List Column
columnsIn language (State state) =
    if List.isEmpty state.columns then
        [ textColumn "description" (Locale.pick language { en = "Cost description", nb = "Beskrivelse av kostnad" })
        , numberColumn "quantity" (Locale.pick language { en = "Quantity", nb = "Antall" })
        , moneyColumn "price" (Locale.pick language { en = "Unit price", nb = "Enhetspris" })
        ]

    else
        state.columns


inputId : String -> Int -> Int -> String
inputId base rowId column =
    base ++ "-r" ++ String.fromInt rowId ++ "-c" ++ String.fromInt column


{-| Draw the budget as a native table with labeled inputs and a sticky calculated
column. The add/remove actions share the total cell, so the sheet never exceeds six
columns. Invalid lines display an explanation and the grand total is unavailable.
-}
view : (Msg -> msg) -> List (Attribute msg) -> State -> Html msg
view toMsg attributes ((State state) as budget) =
    let
        config =
            List.foldl (\(Attribute apply) -> apply)
                { title = Nothing, totalLabel = Nothing, readOnly = False, locale = Locale.default }
                attributes

        pick en nb =
            Locale.pick config.locale { en = en, nb = nb }

        columns =
            columnsIn config.locale budget

        label =
            Maybe.withDefault (pick "Budget" "Budsjett") config.title

        displayTotal result =
            case result of
                Ok value ->
                    Money.toAmountString config.locale value

                Err _ ->
                    "—"

        problemLabel key =
            columns
                |> List.filterMap
                    (\(Column field heading _) ->
                        if field == key then
                            Just heading

                        else
                            Nothing
                    )
                |> List.head
                |> Maybe.withDefault key

        localizedProblem problem =
            case problem of
                Missing key ->
                    Missing (problemLabel key)

                InvalidQuantity key ->
                    InvalidQuantity (problemLabel key)

                MoneyProblem key issue ->
                    MoneyProblem (problemLabel key) issue

        viewLine index ( id, values ) =
            let
                result =
                    lineTotalIn config.locale budget values

                errorId =
                    state.id ++ "-error-" ++ String.fromInt id

                viewCell columnIndex (Column key columnLabel kind) =
                    Html.td [ Attr.class "klar-budget__cell" ]
                        [ if config.readOnly then
                            Html.span [ Attr.classList [ ( "klar-budget__number", kind /= Text ) ] ]
                                [ Html.text (cellValue key values) ]

                          else
                            Html.input
                                [ Attr.id (inputId state.id id columnIndex)
                                , Attr.classList [ ( "klar-budget__input", True ), ( "klar-budget__number", kind /= Text ) ]
                                , Attr.type_ "text"
                                , Attr.attribute "inputmode"
                                    (if kind == Text then
                                        "text"

                                     else
                                        "decimal"
                                    )
                                , Attr.attribute "aria-label" (columnLabel ++ ", " ++ pick "line " "linje " ++ String.fromInt (index + 1))
                                , Attr.attribute "aria-describedby" errorId
                                , Attr.attribute "aria-invalid"
                                    (case result of
                                        Err (Missing field) ->
                                            if field == key then
                                                "true"

                                            else
                                                "false"

                                        Err (InvalidQuantity field) ->
                                            if field == key then
                                                "true"

                                            else
                                                "false"

                                        Err (MoneyProblem field _) ->
                                            if field == key then
                                                "true"

                                            else
                                                "false"

                                        Ok _ ->
                                            "false"
                                    )
                                , Attr.value (cellValue key values)
                                , Events.onInput (Edit id key >> toMsg)
                                ]
                                []
                        ]
            in
            Html.tr [ Attr.class "klar-budget__line" ]
                (List.indexedMap viewCell columns
                    ++ [ Html.td [ Attr.class "klar-budget__result" ]
                            [ Html.div [ Attr.class "klar-budget__amount" ]
                                [ Html.strong [] [ Html.text (displayTotal result) ]
                                , if config.readOnly then
                                    Html.text ""

                                  else
                                    Html.button
                                        [ Attr.type_ "button"
                                        , Attr.class "klar-budget__remove"
                                        , Attr.attribute "aria-label" (pick "Remove line " "Fjern linje " ++ String.fromInt (index + 1))
                                        , Events.onClick (toMsg (Remove id))
                                        ]
                                        [ Icon.view Icon.trash ]
                                ]
                            , Html.div [ Attr.id errorId, Attr.class "klar-budget__error" ]
                                [ Html.text
                                    (case result of
                                        Ok _ ->
                                            ""

                                        Err problem ->
                                            problemText config.locale (localizedProblem problem)
                                    )
                                ]
                            ]
                       ]
                )

        grandResult =
            totalIn config.locale budget
    in
    Html.section [ Attr.id state.id, Attr.class "klar-budget", Attr.attribute "aria-labelledby" (state.id ++ "-title") ]
        [ Html.div [ Attr.class "klar-budget__header" ]
            [ Html.h3 [ Attr.id (state.id ++ "-title"), Attr.class "klar-budget__title" ] [ Html.text label ]
            , Html.span [ Attr.class "klar-budget__currency" ] [ Html.text (Money.currencyCode state.currency) ]
            ]
        , Html.div [ Attr.class "klar-budget__scroll", Attr.tabindex 0, Attr.attribute "role" "region", Attr.attribute "aria-label" label ]
            [ Html.table [ Attr.class "klar-budget__table" ]
                [ Html.thead []
                    [ Html.tr []
                        (List.map (\(Column _ heading kind) -> Html.th [ Attr.scope "col", Attr.classList [ ( "klar-budget__number", kind /= Text ) ] ] [ Html.text heading ]) columns
                            ++ [ Html.th [ Attr.scope "col", Attr.class "klar-budget__result" ] [ Html.text (pick "Amount" "Sum") ] ]
                        )
                    ]
                , Keyed.node "tbody"
                    []
                    (if List.isEmpty state.entries then
                        [ ( "empty", Html.tr [] [ Html.td [ Attr.colspan (List.length columns + 1), Attr.class "klar-budget__empty" ] [ Html.text (pick "Add your first cost to start the budget." "Legg til den første kostnaden for å starte budsjettet.") ] ] ) ]

                     else
                        List.indexedMap (\index entry -> ( String.fromInt (Tuple.first entry), viewLine index entry )) state.entries
                    )
                , Html.tfoot []
                    [ Html.tr []
                        [ Html.th [ Attr.scope "row", Attr.colspan (List.length columns) ]
                            [ Html.text (Maybe.withDefault (pick "Total budget" "Totalt budsjett") config.totalLabel) ]
                        , Html.td [ Attr.class "klar-budget__result" ]
                            [ Html.div [ Attr.class "klar-budget__grand-total", Attr.attribute "aria-live" "polite", Attr.attribute "aria-atomic" "true" ]
                                [ Html.text (displayTotal grandResult ++ " " ++ Money.currencyCode state.currency) ]
                            ]
                        ]
                    ]
                ]
            ]
        , Html.div [ Attr.class "klar-budget__footer" ]
            [ if config.readOnly then
                Html.text ""

              else
                Html.button [ Attr.id (state.id ++ "-add"), Attr.type_ "button", Attr.class "klar-budget__add", Events.onClick (toMsg Append) ]
                    [ Icon.view Icon.plus, Html.text (pick "Add cost" "Legg til kostnad") ]
            , Html.span [ Attr.class "klar-budget__note" ]
                [ Html.text
                    (case grandResult of
                        Ok _ ->
                            String.fromInt (List.length state.entries) ++ pick " cost lines · calculated automatically" " kostnadslinjer · beregnes automatisk"

                        Err _ ->
                            pick "Complete or correct the marked lines to calculate the total." "Fyll ut eller rett linjene med feil for å beregne totalen."
                    )
                ]
            ]
        ]
