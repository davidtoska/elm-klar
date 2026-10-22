# Klar.Rule

Rules as plain data: a tree of conditions and groups that you can edit, check, run against your rows, describe in words and store as JSON.

Import: `import Klar.Rule as Rule` | Group: Rules and filters

Types: `Rule`, `Field`, `Operands`, `Operator`, `FieldKind`, `Combinator`, `Group`, `Issue`, `Choice`, `Condition`

## Signatures

```elm
-- Fields
type Field row  -- opaque: no constructors are exposed
bareField : String -> String -> FieldKind -> Field row
textField : String -> String -> (row -> String) -> Field row
numberField : String -> String -> (row -> Maybe Float) -> Field row
dateField : String -> String -> (row -> Maybe Date.Date) -> Field row
boolField : String -> String -> (row -> Bool) -> Field row
choiceField : String -> String -> List Choice -> (row -> String) -> Field row
choiceFieldOf :
    Ids.Ids id
    -> String
    -> String
    -> List (Select.Option.Option id)
    -> (row -> Maybe id)
    -> Field row
inGroup : String -> Field row -> Field row
withOperators : List Operator -> Field row -> Field row
fieldById : List (Field row) -> String -> Maybe (Field row)
fieldId : Field row -> String
fieldLabel : Field row -> String
fieldKind : Field row -> FieldKind
fieldGroup : Field row -> Maybe String
fieldOperators : Field row -> List Operator
type FieldKind = TextKind | NumberKind | DateKind | BooleanKind | ChoiceKind (List Choice)
type alias Choice = { value : String, label : String }

-- Operators and operands
type Operator
    = Is
    | IsNot
    | Contains
    | NotContains
    | StartsWith
    | EndsWith
    | Equals
    | NotEquals
    | LessThan
    | LessOrEqual
    | GreaterThan
    | GreaterOrEqual
    | Between
    | Before
    | After
    | OnOrBefore
    | OnOrAfter
    | InLastDays
    | InNextDays
    | IsAnyOf
    | IsNoneOf
    | IsEmpty
    | IsNotEmpty
    | IsTrue
    | IsFalse
type Operands = NoOperand | OneOperand | TwoOperands | ManyOperands
operatorsFor : FieldKind -> List Operator
operandsOf : Operator -> Operands
operatorLabel : Locale.Locale -> FieldKind -> Operator -> String

-- Rules
type Rule = GroupRule Group | ConditionRule Condition
type alias Group = { id : Int, combinator : Combinator, negated : Bool, children : List Rule }
type Combinator = All | Any
type alias Condition = { id : Int, field : String, operator : Operator, values : List String }
emptyGroup : Rule
is : String -> String -> Rule
isAnyOf : String -> List String -> Rule
when : String -> Operator -> List String -> Rule
allOf : List Rule -> Rule
anyOf : List Rule -> Rule

-- Running a rule
matches : Date.Date -> List (Field row) -> Rule -> row -> Bool
isComplete : Field row -> Condition -> Bool
parseNumber : String -> Maybe Float

-- Checking and describing
type alias Issue = { nodeId : Int, message : String }
validate : Locale.Locale -> List (Field row) -> Rule -> List Issue
describe : Locale.Locale -> List (Field row) -> Rule -> String
quote : Locale.Locale -> String -> String

-- Editing
addCondition : List (Field row) -> Int -> Rule -> Rule
addGroup : Int -> Rule -> Rule
remove : Int -> Rule -> Rule
duplicate : Int -> Rule -> Rule
move : Int -> Int -> Rule -> Rule
setCombinator : Int -> Combinator -> Rule -> Rule
toggleNegated : Int -> Rule -> Rule
setField : List (Field row) -> Int -> String -> Rule -> Rule
setOperator : Int -> Operator -> Rule -> Rule
setValue : Int -> Int -> String -> Rule -> Rule
addValue : Int -> String -> Rule -> Rule
removeValue : Int -> String -> Rule -> Rule

-- Looking at a rule
idOf : Rule -> Int
nextId : Rule -> Int
depth : Rule -> Int
conditionCount : Rule -> Int
isEmpty : Rule -> Bool

-- JSON
encode : Rule -> Json.Encode.Value
decoder : Json.Decode.Decoder Rule
```

## Documentation

Rules as plain data: a tree of conditions and groups that you can edit,
check, run against your rows, describe in words and store as JSON.

Use when: filter conditions are data that the application stores, runs against its rows or describes in words.
Do not use when: the user must edit the conditions (use `Klar.RuleBuilder` or `Klar.FilterBar`).
Quick path: `textField`, `choiceField`, `numberField`, `matches`, `describe`, `encode`, `decoder`

A rule is what a filter builder lets the user say, for example "Status is Paid
and Total is greater than 100". This module has no HTML.
[Klar.RuleBuilder](Klar.RuleBuilder.md) and [Klar.FilterBar](Klar.FilterBar.md) draw
and edit a `Rule`, and the module is just as useful on its own, for example to
filter rows with a rule that your backend has stored.

    import Json.Encode as Encode
    import Klar.Date exposing (Date)
    import Klar.Locale as Locale
    import Klar.Rule as Rule exposing (Combinator(..), Operator(..), Rule(..))

    type alias Order =
        { number : String
        , status : String
        , total : Float
        , created : Date
        , country : String
        }

    -- 1. The fields: what rules can talk about, and how to read it from a row
    fields : List (Rule.Field Order)
    fields =
        [ Rule.textField "country" "Country" .country
        , Rule.choiceField "status" "Status" statuses .status
        , Rule.numberField "total" "Total" (.total >> Just)
        , Rule.dateField "created" "Created" (.created >> Just)
        ]

    statuses : List Rule.Choice
    statuses =
        [ { value = "open", label = "Open" }
        , { value = "paid", label = "Paid" }
        ]

    -- 2. A rule: all of these conditions must hold
    paidAndLarge : Rule
    paidAndLarge =
        GroupRule
            { id = 0
            , combinator = All
            , negated = False
            , children =
                [ ConditionRule { id = 1, field = "status", operator = Is, values = [ "paid" ] }
                , ConditionRule { id = 2, field = "total", operator = GreaterThan, values = [ "100" ] }
                ]
            }

    -- 3. Use it (today : Date)
    List.filter (Rule.matches today fields paidAndLarge) orders

    Rule.describe Locale.en fields paidAndLarge
    -- "Status is Paid and Total > 100"

    Encode.encode 0 (Rule.encode paidAndLarge)
    -- {"type":"group","combinator":"all","not":false,"children":[ ... ]}

The pieces, from the bottom up:

  - A **field** says what rules can talk about and how to read it from a row:
    `Status`, `Total`.
  - A **condition** compares one field with some **operands** using an
    **operator**: `Total` `GreaterThan` `100`.
  - A **group** combines conditions and other groups, either "all of" or "any
    of" them, and can be negated.
  - A **rule** is such a tree. Its root is a group.

The text this module produces (operator words, issues, sentences) follows a
[Klar.Locale](Klar.Locale.md); the labels of fields and choices are yours.

## Fields

A field has an id (what saved rules refer to, so keep it stable), a label (what
people read), a `FieldKind` and a function that reads the value from one row.
Make fields with the functions below, one for each kind of value. The getter of
a number or date field returns a `Maybe`: `Nothing` means that the row has no
value.

### `Field`

```elm
type Field row  -- opaque: no constructors are exposed
```

Something rules can talk about, and how to read it from a row of type
`row`. Make fields with `textField`, `numberField`, `dateField`, `boolField` or
`choiceField` (or `field`, when there are no rows to read), adjust them with
`inGroup` and `withOperators`, and read them with `fieldId`, `fieldLabel`,
`fieldKind`, `fieldGroup` and `fieldOperators`. The type is opaque, so that a
field can get more settings in a later version.

### `bareField`

```elm
bareField : String -> String -> FieldKind -> Field row
```

A field that only describes: an id, a label and a kind, with nothing to read
from a row. It is what you need when the rows are not in the browser (a server
filters them) and the fields only decide what a rule builder or filter bar
offers. `matches` finds no value in a row for such a field.

    Rule.bareField "status" "Status" (Rule.ChoiceKind statuses)

### `textField`

```elm
textField : String -> String -> (row -> String) -> Field row
```

A field with text values. The first argument is the id, the second the label,
the third reads the text from a row.

    Rule.textField "country" "Country" .country

The operators are `Contains`, `StartsWith`, `Is` and the other text operators.
Comparisons ignore case and diacritics, and surrounding spaces.

### `numberField`

```elm
numberField : String -> String -> (row -> Maybe Float) -> Field row
```

A field with number values. `Nothing` means that the row has no number; such
a row only satisfies `IsEmpty` and `NotEquals`.

    Rule.numberField "total" "Total" (.total >> Just)

Operands are read with `parseNumber`, so a decimal comma and separators between
the thousands work.

### `dateField`

```elm
dateField : String -> String -> (row -> Maybe Date.Date) -> Field row
```

A field with calendar dates ([Klar.Date](Klar.Date.md)). `Nothing` means that
the row has no date; such a row only satisfies `IsEmpty` and `IsNot`.

    Rule.dateField "created" "Created" (.created >> Just)

Operands are ISO dates (`2026-10-20`), or a number of days for `InLastDays` and
`InNextDays`.

### `boolField`

```elm
boolField : String -> String -> (row -> Bool) -> Field row
```

A field with yes or no values. The only operators are `IsTrue` and
`IsFalse`, and they take no operand.

    Rule.boolField "gift" "Gift wrapped" .giftWrapped

### `choiceField`

```elm
choiceField : String -> String -> List Choice -> (row -> String) -> Field row
```

A field with a fixed set of values. The getter returns the `value` of the
choice a row has, and the empty text for a row without one (it then satisfies
`IsEmpty`, `IsNot` and `IsNoneOf`). Values are compared exactly.

    Rule.choiceField "status" "Status" statuses .status

### `choiceFieldOf`

```elm
choiceFieldOf :
    Ids.Ids id
    -> String
    -> String
    -> List (Select.Option.Option id)
    -> (row -> Maybe id)
    -> Field row
```

A choice field over the application's own id type. The choices are the same
`Select.Option` list the form's select is drawn from, and the `Ids` are the same
that the form model uses, so the key functions are written once. A saved rule
still holds the key as text; `Ids.fromKey` reads it back as your type.

    Rule.choiceFieldOf categoryIds "category" "Category" categoryOptions .category

For a field that only describes (the rows are on a server), give a getter that
returns `Nothing`: `Rule.choiceFieldOf categoryIds "category" "Category" options (always Nothing)`.

### `inGroup`

```elm
inGroup : String -> Field row -> Field row
```

Lists the field under a heading in the field picker of the rule builder and
the filter bar. Fields with the same heading are listed together.

    Rule.textField "country" "Country" .country
        |> Rule.inGroup "Delivery"

### `withOperators`

```elm
withOperators : List Operator -> Field row -> Field row
```

Limits the operators the field offers to these, in this order, taken from the
ones that fit its kind (the others are ignored). A condition on the field starts
with the first one. Use it to leave out what makes no sense for a field: an
entity needs `Is` and `IsAnyOf`, not `Contains`. A saved rule that uses an
operator the field no longer offers is reported by `validate`.

    Rule.choiceField "owner" "Owner" owners .ownerId
        |> Rule.withOperators [ Is, IsNot, IsAnyOf ]

If none of the operators fit the kind, the field keeps all of them.

### `fieldById`

```elm
fieldById : List (Field row) -> String -> Maybe (Field row)
```

Finds the field with this id.

    Rule.fieldById fields "total" -- Just the field

### `fieldId`

```elm
fieldId : Field row -> String
```

The id of a field: what conditions store to refer to it.

### `fieldLabel`

```elm
fieldLabel : Field row -> String
```

The label of a field: what the user reads.

### `fieldKind`

```elm
fieldKind : Field row -> FieldKind
```

The kind of a field.

### `fieldGroup`

```elm
fieldGroup : Field row -> Maybe String
```

The heading a field is listed under in a field picker, set with `inGroup`.

### `fieldOperators`

```elm
fieldOperators : Field row -> List Operator
```

The operators a field offers, in the order a picker lists them: the ones set
with `withOperators` that fit the kind of the field, or all those that fit it
(see `operatorsFor`).

### `FieldKind`

```elm
type FieldKind = TextKind | NumberKind | DateKind | BooleanKind | ChoiceKind (List Choice)
```

The kind of value a field holds.

It decides which operators are on offer (see `operatorsFor`) and which editor
a rule builder shows for the operands. A `ChoiceKind` carries the choices the
user can pick from.

### `Choice`

```elm
type alias Choice = { value : String, label : String }
```

One of the values of a choice field. The `value` is what a rule stores and
what the getter of `choiceField` returns for a row; the `label` is what the user
reads.

    { value = "paid", label = "Paid" }

## Operators and operands

An `Operator` says how a condition compares the field with its operands. Which
operators make sense depends on the `FieldKind`, see `operatorsFor`: a text
field offers `Contains`, a number field `GreaterThan`, a date field `InLastDays`
and so on.

Operands are kept as text, exactly what the user typed or picked, and are read
when the rule runs: numbers with a decimal comma or point (`parseNumber`), dates
as ISO `YYYY-MM-DD`, choices as the `value` of a `Choice`. That is why a rule
that is not finished yet can still be stored and shown.

### `Operator`

```elm
type Operator
    = Is
    | IsNot
    | Contains
    | NotContains
    | StartsWith
    | EndsWith
    | Equals
    | NotEquals
    | LessThan
    | LessOrEqual
    | GreaterThan
    | GreaterOrEqual
    | Between
    | Before
    | After
    | OnOrBefore
    | OnOrAfter
    | InLastDays
    | InNextDays
    | IsAnyOf
    | IsNoneOf
    | IsEmpty
    | IsNotEmpty
    | IsTrue
    | IsFalse
```

How a condition compares a field with its operands. Which operators fit
which kind of field is listed by `operatorsFor`; `operatorLabel` gives the
words the user reads and `operandsOf` how many operands an operator takes.

  - Text: `Is`, `IsNot`, `Contains`, `NotContains`, `StartsWith`, `EndsWith`
  - Numbers: `Equals`, `NotEquals`, `LessThan`, `LessOrEqual`, `GreaterThan`,
    `GreaterOrEqual`, `Between` (both ends included)
  - Dates: `Is`, `IsNot`, `Before`, `After`, `OnOrBefore`, `OnOrAfter`,
    `Between` (both ends included), `InLastDays` and `InNextDays` (today
    counts, the operand is a number of days)
  - Choices: `Is`, `IsNot`, `IsAnyOf`, `IsNoneOf`
  - Yes or no: `IsTrue`, `IsFalse`
  - Every kind except yes or no: `IsEmpty`, `IsNotEmpty`

### `Operands`

```elm
type Operands = NoOperand | OneOperand | TwoOperands | ManyOperands
```

How many operands an operator takes, and so how many entries of the
`values` of a condition it uses.

  - `NoOperand`: `IsEmpty`, `IsNotEmpty`, `IsTrue` and `IsFalse`.
  - `OneOperand`: most operators, such as `Contains` or `GreaterThan`.
  - `TwoOperands`: `Between`, with the two ends.
  - `ManyOperands`: `IsAnyOf` and `IsNoneOf`, with any number of choices.

### `operatorsFor`

```elm
operatorsFor : FieldKind -> List Operator
```

The operators that fit a kind of field, in the order a picker should list
them. A new condition on a field starts with the first one.

    Rule.operatorsFor Rule.BooleanKind -- [ IsTrue, IsFalse ]

### `operandsOf`

```elm
operandsOf : Operator -> Operands
```

How many operands an operator takes.

    Rule.operandsOf Rule.Between -- TwoOperands

### `operatorLabel`

```elm
operatorLabel : Locale.Locale -> FieldKind -> Operator -> String
```

The words (or the symbol) for an operator in the language of the locale,
for showing it to the user.

    Rule.operatorLabel Locale.en Rule.TextKind Rule.NotContains -- "does not contain"

    Rule.operatorLabel Locale.en Rule.NumberKind Rule.GreaterOrEqual -- "≥"

The `FieldKind` argument is reserved: pass the kind of the field the operator is
used on, so that a later version can word an operator differently for a kind of
field. Today the label does not depend on it. The comparison operators for
numbers are the same symbols in every language.

## Rules

A rule is built by hand as in the example above, with the editing functions
further down (starting from `emptyGroup`), or read with `decoder`. Every node of
the tree has an `Int` id that is unique within the tree. The root group made by
`emptyGroup` has the id 0, and `decoder` numbers the nodes of a rule it reads 0,
1, 2 ... from the top down.

### `Rule`

```elm
type Rule = GroupRule Group | ConditionRule Condition
```

One node of the tree: a `GroupRule` that combines other nodes, or a
`ConditionRule` that tests one field. A whole rule is the node at its root. In
everything the rule builder and the filter bar make, the root is a group.

### `Group`

```elm
type alias Group = { id : Int, combinator : Combinator, negated : Bool, children : List Rule }
```

A node that combines its `children` (conditions and other groups).

  - `id` identifies the node within the tree.
  - `combinator` says whether `All` or `Any` of the children must match.
  - `negated` turns the outcome around: "not all of" or "none of".
  - `children` are the nodes inside the group, in the order they are shown.

A group without any complete condition inside it matches every row, negated or
not.

### `Combinator`

```elm
type Combinator = All | Any
```

How a group combines its children: with `All`, every child must match; with
`Any`, at least one must.

### `Condition`

```elm
type alias Condition = { id : Int, field : String, operator : Operator, values : List String }
```

A test of one field.

  - `id` identifies the node within the tree.
  - `field` is the `id` of a `Field`. A condition on a field that is not in the
    list is ignored by `matches` and reported by `validate`.
  - `operator` says how the field is compared with the operands.
  - `values` are the operands as text. How many of them are used depends on the
    operator, see `operandsOf`.

For example "Total is greater than 100":

    { id = 2, field = "total", operator = GreaterThan, values = [ "100" ] }

### `emptyGroup`

```elm
emptyGroup : Rule
```

A group with nothing in it, with the id 0: the usual starting point of a
rule. It matches every row.

A rule written by hand, for a saved view or a preset, is shorter with these (they
number the nodes themselves; the records above stay as they are):

    Rule.allOf [ Rule.is "status" "open", Rule.when "total" Rule.GreaterOrEqual [ "1000" ] ]

### `is`

```elm
is : String -> String -> Rule
```

"The field is this value": `when field Is [ value ]`.

    Rule.is "status" "open"

### `isAnyOf`

```elm
isAnyOf : String -> List String -> Rule
```

"The field is one of these values": `when field IsAnyOf values`.

    Rule.isAnyOf "status" [ "received", "packed" ]

### `when`

```elm
when : String -> Operator -> List String -> Rule
```

A test of one field with any operator and its operands, as a rule whose id is 0.
It is a condition only: put it in `allOf` or `anyOf` to get the group that
`FilterBar` and `SavedViews` expect.

    Rule.when "total" Rule.GreaterOrEqual [ "1000" ]

### `allOf`

```elm
allOf : List Rule -> Rule
```

A group where all of the rules must match. The nodes of the whole tree are
numbered 0, 1, 2 ... from the top down, so the ids are unique.

### `anyOf`

```elm
anyOf : List Rule -> Rule
```

A group where any of the rules may match. Numbered as `allOf` is.

## Running a rule

A rule is forgiving while it is being built. A condition that is not complete
(no operand yet, an operand that cannot be read, an operator that does not
belong to the field) and a condition on a field that does not exist are ignored,
and a group without any complete condition lets every row through. The result
therefore makes sense after every step the user takes. `validate` is where the
user hears about what is missing.

### `matches`

```elm
matches : Date.Date -> List (Field row) -> Rule -> row -> Bool
```

Does this row satisfy the rule? The arguments are today's date, the fields,
the rule and the row. `today` is what `InLastDays` and `InNextDays` count from;
get it with `Date.fromPosix` ([Klar.Date](Klar.Date.md)).

    List.filter (Rule.matches today fields rule) orders

Conditions that are not complete (see `isComplete`) and conditions on fields
that are not in the list do not take part. A group is decided by the nodes that
do: with `All` they must all match, with `Any` one of them must, and a negated
group turns that around. A group in which nothing takes part lets every row
through, so an empty rule matches all rows.

Operands are compared in the way that fits the kind of the field:

  - Text ignores case, diacritics and surrounding spaces.
  - Numbers and dates compare by value, and `Between` includes both ends (it
    does not matter which end is the lower one).
  - `InLastDays` with the operand 30 includes today and the 30 days before it;
    `InNextDays` goes forward from today in the same way.
  - A row without a number or a date satisfies only `IsEmpty` and `NotEquals`
    (numbers) or `IsEmpty` and `IsNot` (dates).

### `isComplete`

```elm
isComplete : Field row -> Condition -> Bool
```

Does the condition have everything it needs to filter? The arguments are the
field the condition is on and the condition. Its operator has to fit the field
(see `operatorsFor`), and every operand it needs has to be usable: a number that
`parseNumber` can read, an ISO date, a number of days that is not negative, or
text that is not blank (one choice is enough for `IsAnyOf` and `IsNoneOf`).

`matches` ignores conditions that are not complete, as it ignores conditions on
unknown fields. Otherwise an operator that does not fit the field (from old or
hand-written JSON) or a negative number of days would silently filter out every
row.

### `parseNumber`

```elm
parseNumber : String -> Maybe Float
```

Reads a number the way people type it, with a decimal point or comma and
with separators between the thousands. Empty or unreadable text is `Nothing`.

    Rule.parseNumber "12.5" -- Just 12.5

    Rule.parseNumber "12,5" -- Just 12.5

    Rule.parseNumber "1 234,5" -- Just 1234.5

    Rule.parseNumber "1,234.5" -- Just 1234.5

    Rule.parseNumber "1.234,5" -- Just 1234.5

    Rule.parseNumber "-3" -- Just -3

    Rule.parseNumber "ten" -- Nothing

The rules:

  - Spaces, also non-breaking ones, separate thousands and are ignored. A
    leading `-` or `+` is the sign, and so is the minus sign `−` (U+2212) that
    `Klar.Format` writes.
  - If a number has both a point and a comma, the last one is the decimal
    separator and the other kind separates thousands, in groups of three digits:
    "1,234,567.89" and "1.234.567,89".
  - A separator that occurs more than once separates thousands, again in groups
    of three digits: "1,234,567" and "1.234.567" are 1234567, "1.2.3" is not a
    number.
  - A single separator is a decimal separator: "12.5", "12,5", "1234.567". The
    exception is a point with one to three digits before it and exactly three
    digits after it, such as "1.234" or "12.500". That is ambiguous, and the point
    is read as a thousands separator: 1234 and 12500. A comma in the same
    position stays a decimal comma, as it always was: "1,234" is 1.234. A leading
    zero is never a group of thousands, so "0.125" is 0.125.
  - An exponent such as "1e3" is read too. Other text ("12kg", "0x10"),
    "Infinity" and numbers too large for a `Float` are `Nothing`.

## Checking and describing

### `Issue`

```elm
type alias Issue = { nodeId : Int, message : String }
```

A problem with one node of the rule, for showing next to it: the `nodeId`
of the group or condition, and a `message` in the language of the locale given
to `validate`.

### `validate`

```elm
validate : Locale.Locale -> List (Field row) -> Rule -> List Issue
```

What is wrong with the rule, for showing next to the nodes that have a
problem. An empty list means that the rule is fine.

  - A condition on a field that is not in the list ("Choose a field").
  - An operator that does not fit the field.
  - An operand that is missing or cannot be read: not a number, not a date, not
    a number of days.
  - A `Between` whose ends are the wrong way round.
  - A group with nothing in it. The root group may be empty.

A node has at most one issue. The messages follow the locale.

    Rule.validate Locale.en fields rule
    -- [ { nodeId = 2, message = "Enter a valid number" } ]

### `describe`

```elm
describe : Locale.Locale -> List (Field row) -> Rule -> String
```

The rule as a sentence, for a summary or a tooltip:

    Rule.describe Locale.en fields rule
    -- "Status is Paid and (Total > 100 or Country is “Norway”)"

Incomplete conditions and groups without a complete condition are left out. A
rule with nothing left reads "All rows". Groups inside the rule are put in
parentheses when they have more than one part, and a negated group reads
"not (...)". Text operands are put in quotation marks (see `quote`), choices
are written with their label and dates in the format of the locale.

### `quote`

```elm
quote : Locale.Locale -> String -> String
```

Puts a text in the quotation marks of the locale: “Ada” for `Locale.en`, «Ada»
for `Locale.nb`. `describe` uses it for the operands of text fields.

## Editing

These functions take the id of the node to change and leave the rule as it is
when no node has that id. A new node gets the id `nextId`. They are plain
functions from rule to rule, so a rule in your model is edited with ordinary
`update` code.

### `addCondition`

```elm
addCondition : List (Field row) -> Int -> Rule -> Rule
```

Adds a new condition at the end of the group with this id. The arguments
are the fields, the id of the group and the rule. The condition starts on the
first of the fields, with the first operator that fits it and no operands yet
(without any fields it starts without a field).

    Rule.addCondition fields 0 Rule.emptyGroup

### `addGroup`

```elm
addGroup : Int -> Rule -> Rule
```

Adds a new empty group at the end of the group with this id. It starts as
the opposite of its parent: "any of" inside "all of" and the other way round.

### `remove`

```elm
remove : Int -> Rule -> Rule
```

Removes the node with this id, and everything inside it if it is a group.
The root of the rule cannot be removed.

### `duplicate`

```elm
duplicate : Int -> Rule -> Rule
```

Adds a copy of the node with this id (and of everything inside it) right
after it, with new ids. The root of the rule cannot be duplicated.

### `move`

```elm
move : Int -> Int -> Rule -> Rule
```

Moves the node with this id by `delta` places within its group: `-1` one step
up, `1` one step down, `2` two steps down. The nodes it passes shift by one place,
so every node is kept exactly once. Nothing happens when `delta` is `0` or when
the move would take the node past an end of the group.

    Rule.move 2 -1 rule -- node 2 changes places with the node before it

### `setCombinator`

```elm
setCombinator : Int -> Combinator -> Rule -> Rule
```

Makes the group with this id combine its children with `All` or `Any`.

### `toggleNegated`

```elm
toggleNegated : Int -> Rule -> Rule
```

Negates the group with this id, or takes the negation away again.

### `setField`

```elm
setField : List (Field row) -> Int -> String -> Rule -> Rule
```

Lets the condition with this id talk about another field. The arguments are
the fields, the id of the condition, the id of the new field and the rule.

The operator is kept if it also fits the new kind of field, otherwise the
condition gets the first operator of that kind. The operands are cleared. If the
id is not one of the fields, only the field of the condition changes.

### `setOperator`

```elm
setOperator : Int -> Operator -> Rule -> Rule
```

Changes the operator of the condition with this id, and trims or pads its
operands to fit: none for an operator without operands, only the first for one
operand, exactly two for `Between` (padded with empty texts), all of them for
`IsAnyOf` and `IsNoneOf`.

### `setValue`

```elm
setValue : Int -> Int -> String -> Rule -> Rule
```

Sets the operand at an index of the condition with this id. The arguments
are the id of the condition, the index (0 is the first operand), the text and
the rule. The list of operands grows with empty texts if it is too short.

    Rule.setValue 2 0 "100" rule

### `addValue`

```elm
addValue : Int -> String -> Rule -> Rule
```

Adds an operand at the end of the condition with this id, for the operators
that take many (`IsAnyOf`, `IsNoneOf`). Empty text and an operand that is
already there are ignored.

### `removeValue`

```elm
removeValue : Int -> String -> Rule -> Rule
```

Removes the operands of the condition with this id that are equal to the
text.

## Looking at a rule

### `idOf`

```elm
idOf : Rule -> Int
```

The id of a node.

### `nextId`

```elm
nextId : Rule -> Int
```

An id that no node in the tree uses: one more than the highest. The editing
functions use it for the nodes they add.

### `depth`

```elm
depth : Rule -> Int
```

How many levels of groups the rule has, counting the outermost one: a
condition is 0, a group of conditions 1, a group with a group in it 2.

    Rule.depth Rule.emptyGroup -- 1

### `conditionCount`

```elm
conditionCount : Rule -> Int
```

How many conditions the rule has, in all its groups.

### `isEmpty`

```elm
isEmpty : Rule -> Bool
```

Does the rule have no conditions at all? Empty groups do not count as
conditions.

## JSON

### `encode`

```elm
encode : Rule -> Json.Encode.Value
```

The rule as JSON, for storing it or sending it to a backend. The ids of the
nodes are not written; `decoder` gives the nodes new ones.

    Encode.encode 0 (Rule.encode rule)
    -- {"type":"group","combinator":"all","not":false,"children":[
    --     {"type":"condition","field":"total","operator":"gt","values":["100"]}
    -- ]}

A group has a `type` ("group"), a `combinator` ("all" or "any"), `not` (a
boolean) and `children`. A condition has a `type` ("condition"), a `field`, an
`operator` and `values` (a list of texts).

The operator is written as a short key. For most operators it is the name of the
constructor with a lowercase first letter: "isNot", "startsWith", "onOrBefore",
"inLastDays". The others are "eq", "neq", "lt", "lte", "gt" and "gte" (the number
comparisons), "anyOf" and "noneOf", "empty" and "notEmpty", "true" and "false".

### `decoder`

```elm
decoder : Json.Decode.Decoder Rule
```

Reads a rule from the JSON that `encode` writes, and gives every node a
fresh id: 0 for the root, then counting up from the top down.

    Decode.decodeString Rule.decoder text

`not` may be left out of a group (meaning false), and a `combinator` other than
"any" is read as "all". An unknown `type` or operator makes the decoder fail.

Groups nested more than 32 deep are refused (nobody writes that, and it keeps a
hostile text from running the decoder out of stack). Check a limit of your own
with `depth`.
