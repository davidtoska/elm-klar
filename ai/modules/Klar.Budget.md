# Klar.Budget

An editable budget sheet with up to six columns, calculated line amounts and an exact grand total.

Import: `import Klar.Budget as Budget` | Group: Tables and lists

Types: `Msg`, `Row`, `State`, `Column`, `Formula`, `Problem`, `Attribute`

## Signatures

```elm
-- View
type Attribute msg  -- opaque: no constructors are exposed
view : (Msg -> msg) -> List (Attribute msg) -> State -> Html msg
title : String -> Attribute msg
totalLabel : String -> Attribute msg
readOnly : Bool -> Attribute msg
locale : Locale.Locale -> Attribute msg

-- State
type State  -- opaque: no constructors are exposed
type Msg  -- opaque: no constructors are exposed
init : String -> Money.Currency -> State
update : Msg -> State -> ( State, Cmd Msg )
setColumns : List Column -> State -> State
setFormula : Formula -> State -> State
setRows : List Row -> State -> State
rows : State -> List Row

-- Columns and rows
type Column  -- opaque: no constructors are exposed
type Row  -- opaque: no constructors are exposed
textColumn : String -> String -> Column
numberColumn : String -> String -> Column
moneyColumn : String -> String -> Column
row : List ( String, String ) -> Row
cellValue : String -> Row -> String

-- Calculations
type Formula  -- opaque: no constructors are exposed
type Problem  -- opaque: no constructors are exposed
amount : String -> Formula
multiply : String -> Formula -> Formula
add : Formula -> Formula -> Formula
lineTotal : Locale.Locale -> State -> Row -> Result Problem Money.Money
total : Locale.Locale -> State -> Result Problem Money.Money
problemText : Locale.Locale -> Problem -> String
```

## Documentation

An editable budget sheet with up to six columns, calculated line amounts and
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

## View

### `Attribute`

```elm
type Attribute msg  -- opaque: no constructors are exposed
```

View configuration; later attributes override earlier ones.

### `view`

```elm
view : (Msg -> msg) -> List (Attribute msg) -> State -> Html msg
```

Draw the budget as a native table with labeled inputs and a sticky calculated
column. The add/remove actions share the total cell, so the sheet never exceeds six
columns. Invalid lines display an explanation and the grand total is unavailable.

### `title`

```elm
title : String -> Attribute msg
```

Heading for the sheet. Defaults to the localized word "Budget".

### `totalLabel`

```elm
totalLabel : String -> Attribute msg
```

Label for the grand total. Defaults to "Total budget".

### `readOnly`

```elm
readOnly : Bool -> Attribute msg
```

Show values and calculations without inputs or add/remove actions.

### `locale`

```elm
locale : Locale.Locale -> Attribute msg
```

Language and price parsing conventions; defaults to English.

## State

### `State`

```elm
type State  -- opaque: no constructors are exposed
```

Budget data, schema and formula. All input text lives here.

### `Msg`

```elm
type Msg  -- opaque: no constructors are exposed
```

Internal edits and row actions. Pass them to `update`.

### `init`

```elm
init : String -> Money.Currency -> State
```

Start an empty budget in one currency. The id must be unique on the page.
Default keys: `description`, `quantity`, `price`; formula: quantity times price.

### `update`

```elm
update : Msg -> State -> ( State, Cmd Msg )
```

Apply an edit or add/remove a line. New numeric fields start at one, price
fields at zero, and text fields empty. Add and remove move focus to a useful control.

### `setColumns`

```elm
setColumns : List Column -> State -> State
```

Replace the editable columns. The first five distinct, nonempty keys are
used; the calculated total is always appended. Existing row data is preserved.
An empty list restores the default columns. Configure `setFormula` as well when
using field keys other than the defaults.

### `setFormula`

```elm
setFormula : Formula -> State -> State
```

Replace the calculation for every line. The formula may reference preserved
fields that are currently hidden from the sheet.

### `setRows`

```elm
setRows : List Row -> State -> State
```

Replace the lines, preserving all their raw field values. Use to load or reset
a budget. Row identities are renewed to avoid reusing a focused input for new data.

### `rows`

```elm
rows : State -> List Row
```

All lines in their displayed order, including incomplete ones.

## Columns and rows

### `Column`

```elm
type Column  -- opaque: no constructors are exposed
```

One editable column with a stable, nonempty field key and a visible label.

### `Row`

```elm
type Row  -- opaque: no constructors are exposed
```

The values in one budget line, independent of its position in the sheet.

### `textColumn`

```elm
textColumn : String -> String -> Column
```

A description, category, unit or other text field.

### `numberColumn`

```elm
numberColumn : String -> String -> Column
```

A numeric field, such as hours or quantity. It affects the result only when
referenced by `multiply` in the formula.

### `moneyColumn`

```elm
moneyColumn : String -> String -> Column
```

A price field in the budget currency. Reference it with `amount`.

### `row`

```elm
row : List ( String, String ) -> Row
```

Make a line from field keys and their raw text. Missing fields read as empty.

### `cellValue`

```elm
cellValue : String -> Row -> String
```

Read the raw text of a field, or an empty string if absent.

## Calculations

### `Formula`

```elm
type Formula  -- opaque: no constructors are exposed
```

A calculation tree. It holds field keys, never functions.

### `Problem`

```elm
type Problem  -- opaque: no constructors are exposed
```

A missing value, invalid number or failed exact-money calculation.

### `amount`

```elm
amount : String -> Formula
```

Read a money field, such as a fixed expense or unit price.

### `multiply`

```elm
multiply : String -> Formula -> Formula
```

Multiply a formula by a numeric field, for example
`multiply "hours" (amount "rate")`. Each step rounds to the currency's minor unit.

### `add`

```elm
add : Formula -> Formula -> Formula
```

Add two formulas, for example a fixed fee plus hours times rate.

### `lineTotal`

```elm
lineTotal : Locale.Locale -> State -> Row -> Result Problem Money.Money
```

Calculate a single line with the configured formula and currency. Pass the
same locale as the view so ambiguous grouped prices are interpreted consistently.

### `total`

```elm
total : Locale.Locale -> State -> Result Problem Money.Money
```

The sum of the rounded line amounts. Empty budgets total zero. Any incomplete,
invalid or overflowing line makes the result an error instead of a partial total.

### `problemText`

```elm
problemText : Locale.Locale -> Problem -> String
```

Explain a calculation problem in English or Norwegian Bokmål.
