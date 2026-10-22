module Klar.Rule exposing
    ( Field, bareField, textField, numberField, dateField, boolField, choiceField, choiceFieldOf, inGroup, withOperators, fieldById
    , fieldId, fieldLabel, fieldKind, fieldGroup, fieldOperators
    , FieldKind(..), Choice
    , Operator(..), Operands(..), operatorsFor, operandsOf, operatorLabel
    , Rule(..), Group, Combinator(..), Condition, emptyGroup
    , matches, isComplete, parseNumber
    , validate, Issue, describe, quote
    , addCondition, addGroup, remove, duplicate, move, setCombinator, toggleNegated, setField, setOperator, setValue, addValue, removeValue
    , idOf, nextId, depth, conditionCount, isEmpty
    , encode, decoder
    )

{-| Rules as plain data: a tree of conditions and groups that you can edit,
check, run against your rows, describe in words and store as JSON.

Use when: filter conditions are data that the application stores, runs against its rows or describes in words.
Do not use when: the user must edit the conditions (use `Klar.RuleBuilder` or `Klar.FilterBar`).

A rule is what a filter builder lets the user say, for example "Status is Paid
and Total is greater than 100". This module has no HTML.
[Klar.RuleBuilder](Klar-RuleBuilder) and [Klar.FilterBar](Klar-FilterBar) draw
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
[Klar.Locale](Klar-Locale); the labels of fields and choices are yours.


# Fields

A field has an id (what saved rules refer to, so keep it stable), a label (what
people read), a `FieldKind` and a function that reads the value from one row.
Make fields with the functions below, one for each kind of value. The getter of
a number or date field returns a `Maybe`: `Nothing` means that the row has no
value.

@docs Field, bareField, textField, numberField, dateField, boolField, choiceField, choiceFieldOf, inGroup, withOperators, fieldById

@docs fieldId, fieldLabel, fieldKind, fieldGroup, fieldOperators

@docs FieldKind, Choice


# Operators and operands

An `Operator` says how a condition compares the field with its operands. Which
operators make sense depends on the `FieldKind`, see `operatorsFor`: a text
field offers `Contains`, a number field `GreaterThan`, a date field `InLastDays`
and so on.

Operands are kept as text, exactly what the user typed or picked, and are read
when the rule runs: numbers with a decimal comma or point (`parseNumber`), dates
as ISO `YYYY-MM-DD`, choices as the `value` of a `Choice`. That is why a rule
that is not finished yet can still be stored and shown.

@docs Operator, Operands, operatorsFor, operandsOf, operatorLabel


# Rules

A rule is built by hand as in the example above, with the editing functions
further down (starting from `emptyGroup`), or read with `decoder`. Every node of
the tree has an `Int` id that is unique within the tree. The root group made by
`emptyGroup` has the id 0, and `decoder` numbers the nodes of a rule it reads 0,
1, 2 ... from the top down.

@docs Rule, Group, Combinator, Condition, emptyGroup


# Running a rule

A rule is forgiving while it is being built. A condition that is not complete
(no operand yet, an operand that cannot be read, an operator that does not
belong to the field) and a condition on a field that does not exist are ignored,
and a group without any complete condition lets every row through. The result
therefore makes sense after every step the user takes. `validate` is where the
user hears about what is missing.

@docs matches, isComplete, parseNumber


# Checking and describing

@docs validate, Issue, describe, quote


# Editing

These functions take the id of the node to change and leave the rule as it is
when no node has that id. A new node gets the id `nextId`. They are plain
functions from rule to rule, so a rule in your model is edited with ordinary
`update` code.

@docs addCondition, addGroup, remove, duplicate, move, setCombinator, toggleNegated, setField, setOperator, setValue, addValue, removeValue


# Looking at a rule

@docs idOf, nextId, depth, conditionCount, isEmpty


# JSON

@docs encode, decoder

-}

import Json.Decode as Decode exposing (Decoder)
import Json.Encode as Encode
import Klar.Date as Date exposing (Date)
import Klar.Format as Format
import Klar.Ids as Ids exposing (Ids)
import Klar.Locale as Locale exposing (Locale)
import Klar.Search as Search
import Klar.Select.Option exposing (Option)



-- FIELDS


{-| The kind of value a field holds.

It decides which operators are on offer (see `operatorsFor`) and which editor
a rule builder shows for the operands. A `ChoiceKind` carries the choices the
user can pick from.

-}
type FieldKind
    = TextKind
    | NumberKind
    | DateKind
    | BooleanKind
    | ChoiceKind (List Choice)


{-| One of the values of a choice field. The `value` is what a rule stores and
what the getter of `choiceField` returns for a row; the `label` is what the user
reads.

    { value = "paid", label = "Paid" }

-}
type alias Choice =
    { value : String
    , label : String
    }


{-| What a field reads from one row: a text, a number, a date, a yes or no, one
of the choices, or nothing when the row has no value. It is the result of the
`get` function of a `Field`.

The type is opaque. The functions `textField`, `numberField`, `dateField`,
`boolField` and `choiceField` make fields that read the right kind of value, and
`matches` compares it with the operands of a condition, so there is nothing to
construct or take apart by hand.

-}
type Value
    = VText String
    | VNumber Float
    | VDate Date
    | VBool Bool
    | VChoice String
    | VMissing


{-| Something rules can talk about, and how to read it from a row of type
`row`. Make fields with `textField`, `numberField`, `dateField`, `boolField` or
`choiceField` (or `field`, when there are no rows to read), adjust them with
`inGroup` and `withOperators`, and read them with `fieldId`, `fieldLabel`,
`fieldKind`, `fieldGroup` and `fieldOperators`. The type is opaque, so that a
field can get more settings in a later version.
-}
type Field row
    = Field
        { id : String
        , label : String
        , kind : FieldKind
        , group : Maybe String
        , operators : Maybe (List Operator)
        , get : row -> Value
        }


make : String -> String -> FieldKind -> (row -> Value) -> Field row
make id label kind get =
    Field { id = id, label = label, kind = kind, group = Nothing, operators = Nothing, get = get }


{-| A field that only describes: an id, a label and a kind, with nothing to read
from a row. It is what you need when the rows are not in the browser (a server
filters them) and the fields only decide what a rule builder or filter bar
offers. `matches` finds no value in a row for such a field.

    Rule.bareField "status" "Status" (Rule.ChoiceKind statuses)

-}
bareField : String -> String -> FieldKind -> Field row
bareField id label kind =
    make id label kind (\_ -> VMissing)


{-| A field with text values. The first argument is the id, the second the label,
the third reads the text from a row.

    Rule.textField "country" "Country" .country

The operators are `Contains`, `StartsWith`, `Is` and the other text operators.
Comparisons ignore case and diacritics, and surrounding spaces.

-}
textField : String -> String -> (row -> String) -> Field row
textField id label get =
    make id label TextKind (\row -> VText (get row))


{-| A field with number values. `Nothing` means that the row has no number; such
a row only satisfies `IsEmpty` and `NotEquals`.

    Rule.numberField "total" "Total" (.total >> Just)

Operands are read with `parseNumber`, so a decimal comma and separators between
the thousands work.

-}
numberField : String -> String -> (row -> Maybe Float) -> Field row
numberField id label get =
    make id label NumberKind (\row -> get row |> Maybe.map VNumber |> Maybe.withDefault VMissing)


{-| A field with calendar dates ([Klar.Date](Klar-Date)). `Nothing` means that
the row has no date; such a row only satisfies `IsEmpty` and `IsNot`.

    Rule.dateField "created" "Created" (.created >> Just)

Operands are ISO dates (`2026-10-20`), or a number of days for `InLastDays` and
`InNextDays`.

-}
dateField : String -> String -> (row -> Maybe Date) -> Field row
dateField id label get =
    make id label DateKind (\row -> get row |> Maybe.map VDate |> Maybe.withDefault VMissing)


{-| A field with yes or no values. The only operators are `IsTrue` and
`IsFalse`, and they take no operand.

    Rule.boolField "gift" "Gift wrapped" .giftWrapped

-}
boolField : String -> String -> (row -> Bool) -> Field row
boolField id label get =
    make id label BooleanKind (\row -> VBool (get row))


{-| A field with a fixed set of values. The getter returns the `value` of the
choice a row has, and the empty text for a row without one (it then satisfies
`IsEmpty`, `IsNot` and `IsNoneOf`). Values are compared exactly.

    Rule.choiceField "status" "Status" statuses .status

-}
choiceField : String -> String -> List Choice -> (row -> String) -> Field row
choiceField id label choices get =
    make id
        label
        (ChoiceKind choices)
        (\row ->
            case get row of
                "" ->
                    VMissing

                value ->
                    VChoice value
        )


{-| A choice field over the application's own id type. The choices are the same
`Select.Option` list the form's select is drawn from, and the `Ids` are the same
that the form model uses, so the key functions are written once. A saved rule
still holds the key as text; `Ids.fromKey` reads it back as your type.

    Rule.choiceFieldOf categoryIds "category" "Category" categoryOptions .category

For a field that only describes (the rows are on a server), give a getter that
returns `Nothing`: `Rule.choiceFieldOf categoryIds "category" "Category" options (always Nothing)`.

-}
choiceFieldOf : Ids id -> String -> String -> List (Option id) -> (row -> Maybe id) -> Field row
choiceFieldOf ids id label options get =
    choiceField id
        label
        (List.map (\option -> { value = Ids.toKey ids option.value, label = option.label }) options)
        (get >> Maybe.map (Ids.toKey ids) >> Maybe.withDefault "")


{-| Lists the field under a heading in the field picker of the rule builder and
the filter bar. Fields with the same heading are listed together.

    Rule.textField "country" "Country" .country
        |> Rule.inGroup "Delivery"

-}
inGroup : String -> Field row -> Field row
inGroup group (Field data) =
    Field { data | group = Just group }


{-| Limits the operators the field offers to these, in this order, taken from the
ones that fit its kind (the others are ignored). A condition on the field starts
with the first one. Use it to leave out what makes no sense for a field: an
entity needs `Is` and `IsAnyOf`, not `Contains`. A saved rule that uses an
operator the field no longer offers is reported by `validate`.

    Rule.choiceField "owner" "Owner" owners .ownerId
        |> Rule.withOperators [ Is, IsNot, IsAnyOf ]

If none of the operators fit the kind, the field keeps all of them.

-}
withOperators : List Operator -> Field row -> Field row
withOperators operators (Field data) =
    Field { data | operators = Just operators }


readField : Field row -> row -> Value
readField (Field data) row =
    data.get row


{-| The id of a field: what conditions store to refer to it.
-}
fieldId : Field row -> String
fieldId (Field data) =
    data.id


{-| The label of a field: what the user reads.
-}
fieldLabel : Field row -> String
fieldLabel (Field data) =
    data.label


{-| The kind of a field.
-}
fieldKind : Field row -> FieldKind
fieldKind (Field data) =
    data.kind


{-| The heading a field is listed under in a field picker, set with `inGroup`.
-}
fieldGroup : Field row -> Maybe String
fieldGroup (Field data) =
    data.group


{-| The operators a field offers, in the order a picker lists them: the ones set
with `withOperators` that fit the kind of the field, or all those that fit it
(see `operatorsFor`).
-}
fieldOperators : Field row -> List Operator
fieldOperators (Field data) =
    let
        fitting =
            operatorsFor data.kind

        chosen =
            data.operators
                |> Maybe.map (List.filter (\operator -> List.member operator fitting))
                |> Maybe.withDefault []
    in
    if List.isEmpty chosen then
        fitting

    else
        unique chosen


unique : List a -> List a
unique list =
    List.foldl
        (\item kept ->
            if List.member item kept then
                kept

            else
                kept ++ [ item ]
        )
        []
        list


{-| Finds the field with this id.

    Rule.fieldById fields "total" -- Just the field

-}
fieldById : List (Field row) -> String -> Maybe (Field row)
fieldById fields id =
    fields |> List.filter (\candidate -> fieldId candidate == id) |> List.head



-- OPERATORS


{-| How a condition compares a field with its operands. Which operators fit
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

-}
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


{-| How many operands an operator takes, and so how many entries of the
`values` of a condition it uses.

  - `NoOperand`: `IsEmpty`, `IsNotEmpty`, `IsTrue` and `IsFalse`.
  - `OneOperand`: most operators, such as `Contains` or `GreaterThan`.
  - `TwoOperands`: `Between`, with the two ends.
  - `ManyOperands`: `IsAnyOf` and `IsNoneOf`, with any number of choices.

-}
type Operands
    = NoOperand
    | OneOperand
    | TwoOperands
    | ManyOperands


{-| The operators that fit a kind of field, in the order a picker should list
them. A new condition on a field starts with the first one.

    Rule.operatorsFor Rule.BooleanKind -- [ IsTrue, IsFalse ]

-}
operatorsFor : FieldKind -> List Operator
operatorsFor kind =
    case kind of
        TextKind ->
            [ Contains, NotContains, Is, IsNot, StartsWith, EndsWith, IsEmpty, IsNotEmpty ]

        NumberKind ->
            [ Equals, NotEquals, GreaterThan, GreaterOrEqual, LessThan, LessOrEqual, Between, IsEmpty, IsNotEmpty ]

        DateKind ->
            [ Is, IsNot, Before, After, OnOrBefore, OnOrAfter, Between, InLastDays, InNextDays, IsEmpty, IsNotEmpty ]

        BooleanKind ->
            [ IsTrue, IsFalse ]

        ChoiceKind _ ->
            [ Is, IsNot, IsAnyOf, IsNoneOf, IsEmpty, IsNotEmpty ]


{-| How many operands an operator takes.

    Rule.operandsOf Rule.Between -- TwoOperands

-}
operandsOf : Operator -> Operands
operandsOf operator =
    case operator of
        IsEmpty ->
            NoOperand

        IsNotEmpty ->
            NoOperand

        IsTrue ->
            NoOperand

        IsFalse ->
            NoOperand

        Between ->
            TwoOperands

        IsAnyOf ->
            ManyOperands

        IsNoneOf ->
            ManyOperands

        _ ->
            OneOperand


{-| The words (or the symbol) for an operator in the language of the locale,
for showing it to the user.

    Rule.operatorLabel Locale.en Rule.TextKind Rule.NotContains -- "does not contain"

    Rule.operatorLabel Locale.en Rule.NumberKind Rule.GreaterOrEqual -- "≥"

The `FieldKind` argument is reserved: pass the kind of the field the operator is
used on, so that a later version can word an operator differently for a kind of
field. Today the label does not depend on it. The comparison operators for
numbers are the same symbols in every language.

-}
operatorLabel : Locale -> FieldKind -> Operator -> String
operatorLabel locale _ operator =
    let
        pick nb en =
            Locale.pick locale { nb = nb, en = en }
    in
    case operator of
        Is ->
            pick "er" "is"

        IsNot ->
            pick "er ikke" "is not"

        Contains ->
            pick "inneholder" "contains"

        NotContains ->
            pick "inneholder ikke" "does not contain"

        StartsWith ->
            pick "starter med" "starts with"

        EndsWith ->
            pick "slutter med" "ends with"

        Equals ->
            "="

        NotEquals ->
            "≠"

        LessThan ->
            "<"

        LessOrEqual ->
            "≤"

        GreaterThan ->
            ">"

        GreaterOrEqual ->
            "≥"

        Between ->
            pick "mellom" "between"

        Before ->
            pick "før" "before"

        After ->
            pick "etter" "after"

        OnOrBefore ->
            pick "senest" "on or before"

        OnOrAfter ->
            pick "tidligst" "on or after"

        InLastDays ->
            pick "siste (dager)" "in the last (days)"

        InNextDays ->
            pick "neste (dager)" "in the next (days)"

        IsAnyOf ->
            pick "er en av" "is any of"

        IsNoneOf ->
            pick "er ingen av" "is none of"

        IsEmpty ->
            pick "er tom" "is empty"

        IsNotEmpty ->
            pick "er ikke tom" "is not empty"

        IsTrue ->
            pick "er ja" "is yes"

        IsFalse ->
            pick "er nei" "is no"


operatorKey : Operator -> String
operatorKey operator =
    case operator of
        Is ->
            "is"

        IsNot ->
            "isNot"

        Contains ->
            "contains"

        NotContains ->
            "notContains"

        StartsWith ->
            "startsWith"

        EndsWith ->
            "endsWith"

        Equals ->
            "eq"

        NotEquals ->
            "neq"

        LessThan ->
            "lt"

        LessOrEqual ->
            "lte"

        GreaterThan ->
            "gt"

        GreaterOrEqual ->
            "gte"

        Between ->
            "between"

        Before ->
            "before"

        After ->
            "after"

        OnOrBefore ->
            "onOrBefore"

        OnOrAfter ->
            "onOrAfter"

        InLastDays ->
            "inLastDays"

        InNextDays ->
            "inNextDays"

        IsAnyOf ->
            "anyOf"

        IsNoneOf ->
            "noneOf"

        IsEmpty ->
            "empty"

        IsNotEmpty ->
            "notEmpty"

        IsTrue ->
            "true"

        IsFalse ->
            "false"


operatorFromKey : String -> Maybe Operator
operatorFromKey key =
    [ Is, IsNot, Contains, NotContains, StartsWith, EndsWith, Equals, NotEquals, LessThan, LessOrEqual, GreaterThan, GreaterOrEqual, Between, Before, After, OnOrBefore, OnOrAfter, InLastDays, InNextDays, IsAnyOf, IsNoneOf, IsEmpty, IsNotEmpty, IsTrue, IsFalse ]
        |> List.filter (\operator -> operatorKey operator == key)
        |> List.head



-- THE RULE TREE


{-| How a group combines its children: with `All`, every child must match; with
`Any`, at least one must.
-}
type Combinator
    = All
    | Any


{-| One node of the tree: a `GroupRule` that combines other nodes, or a
`ConditionRule` that tests one field. A whole rule is the node at its root. In
everything the rule builder and the filter bar make, the root is a group.
-}
type Rule
    = GroupRule Group
    | ConditionRule Condition


{-| A node that combines its `children` (conditions and other groups).

  - `id` identifies the node within the tree.
  - `combinator` says whether `All` or `Any` of the children must match.
  - `negated` turns the outcome around: "not all of" or "none of".
  - `children` are the nodes inside the group, in the order they are shown.

A group without any complete condition inside it matches every row, negated or
not.

-}
type alias Group =
    { id : Int
    , combinator : Combinator
    , negated : Bool
    , children : List Rule
    }


{-| A test of one field.

  - `id` identifies the node within the tree.
  - `field` is the `id` of a `Field`. A condition on a field that is not in the
    list is ignored by `matches` and reported by `validate`.
  - `operator` says how the field is compared with the operands.
  - `values` are the operands as text. How many of them are used depends on the
    operator, see `operandsOf`.

For example "Total is greater than 100":

    { id = 2, field = "total", operator = GreaterThan, values = [ "100" ] }

-}
type alias Condition =
    { id : Int
    , field : String
    , operator : Operator
    , values : List String
    }


{-| A group with nothing in it, with the id 0: the usual starting point of a
rule. It matches every row.
-}
emptyGroup : Rule
emptyGroup =
    GroupRule { id = 0, combinator = All, negated = False, children = [] }


{-| The id of a node.
-}
idOf : Rule -> Int
idOf rule =
    case rule of
        GroupRule group ->
            group.id

        ConditionRule condition ->
            condition.id


{-| An id that no node in the tree uses: one more than the highest. The editing
functions use it for the nodes they add.
-}
nextId : Rule -> Int
nextId rule =
    maxId rule + 1


maxId : Rule -> Int
maxId rule =
    case rule of
        ConditionRule condition ->
            condition.id

        GroupRule group ->
            List.foldl (\child highest -> max highest (maxId child)) group.id group.children


{-| Does the rule have no conditions at all? Empty groups do not count as
conditions.
-}
isEmpty : Rule -> Bool
isEmpty rule =
    conditionCount rule == 0


{-| How many levels of groups the rule has, counting the outermost one: a
condition is 0, a group of conditions 1, a group with a group in it 2.

    Rule.depth Rule.emptyGroup -- 1

-}
depth : Rule -> Int
depth rule =
    case rule of
        ConditionRule _ ->
            0

        GroupRule group ->
            1 + (group.children |> List.map depth |> List.maximum |> Maybe.withDefault 0)


{-| How many conditions the rule has, in all its groups.
-}
conditionCount : Rule -> Int
conditionCount rule =
    case rule of
        ConditionRule _ ->
            1

        GroupRule group ->
            List.sum (List.map conditionCount group.children)



-- EDITING (all by node id; ids that do not exist change nothing)


{-| Apply a change to the node with this id, wherever it is.
-}
updateNode : Int -> (Rule -> Rule) -> Rule -> Rule
updateNode id change rule =
    if idOf rule == id then
        change rule

    else
        case rule of
            GroupRule group ->
                GroupRule { group | children = List.map (updateNode id change) group.children }

            ConditionRule _ ->
                rule


updateGroup : Int -> (Group -> Group) -> Rule -> Rule
updateGroup id change =
    updateNode id
        (\rule ->
            case rule of
                GroupRule group ->
                    GroupRule (change group)

                other ->
                    other
        )


updateCondition : Int -> (Condition -> Condition) -> Rule -> Rule
updateCondition id change =
    updateNode id
        (\rule ->
            case rule of
                ConditionRule condition ->
                    ConditionRule (change condition)

                other ->
                    other
        )


{-| Adds a new condition at the end of the group with this id. The arguments
are the fields, the id of the group and the rule. The condition starts on the
first of the fields, with the first operator that fits it and no operands yet
(without any fields it starts without a field).

    Rule.addCondition fields 0 Rule.emptyGroup

-}
addCondition : List (Field row) -> Int -> Rule -> Rule
addCondition fields groupId root =
    let
        id =
            nextId root

        condition =
            case fields of
                first :: _ ->
                    ConditionRule { id = id, field = fieldId first, operator = defaultOperatorOf first, values = [] }

                [] ->
                    ConditionRule { id = id, field = "", operator = Is, values = [] }
    in
    updateGroup groupId (\group -> { group | children = group.children ++ [ condition ] }) root


{-| Adds a new empty group at the end of the group with this id. It starts as
the opposite of its parent: "any of" inside "all of" and the other way round.
-}
addGroup : Int -> Rule -> Rule
addGroup groupId root =
    let
        id =
            nextId root
    in
    updateGroup groupId
        (\group ->
            let
                opposite =
                    case group.combinator of
                        All ->
                            Any

                        Any ->
                            All
            in
            { group | children = group.children ++ [ GroupRule { id = id, combinator = opposite, negated = False, children = [] } ] }
        )
        root


{-| Removes the node with this id, and everything inside it if it is a group.
The root of the rule cannot be removed.
-}
remove : Int -> Rule -> Rule
remove id rule =
    case rule of
        GroupRule group ->
            GroupRule
                { group
                    | children =
                        group.children
                            |> List.filter (\child -> idOf child /= id)
                            |> List.map (remove id)
                }

        other ->
            other


{-| Makes the group with this id combine its children with `All` or `Any`.
-}
setCombinator : Int -> Combinator -> Rule -> Rule
setCombinator id combinator =
    updateGroup id (\group -> { group | combinator = combinator })


{-| Negates the group with this id, or takes the negation away again.
-}
toggleNegated : Int -> Rule -> Rule
toggleNegated id =
    updateGroup id (\group -> { group | negated = not group.negated })


{-| Lets the condition with this id talk about another field. The arguments are
the fields, the id of the condition, the id of the new field and the rule.

The operator is kept if it also fits the new kind of field, otherwise the
condition gets the first operator of that kind. The operands are cleared. If the
id is not one of the fields, only the field of the condition changes.

-}
setField : List (Field row) -> Int -> String -> Rule -> Rule
setField fields id newId =
    updateCondition id
        (\condition ->
            case fieldById fields newId of
                Nothing ->
                    { condition | field = newId }

                Just field ->
                    { condition
                        | field = newId
                        , operator =
                            if List.member condition.operator (fieldOperators field) then
                                condition.operator

                            else
                                defaultOperatorOf field
                        , values = []
                    }
        )


defaultOperatorOf : Field row -> Operator
defaultOperatorOf field =
    fieldOperators field |> List.head |> Maybe.withDefault Is


{-| Changes the operator of the condition with this id, and trims or pads its
operands to fit: none for an operator without operands, only the first for one
operand, exactly two for `Between` (padded with empty texts), all of them for
`IsAnyOf` and `IsNoneOf`.
-}
setOperator : Int -> Operator -> Rule -> Rule
setOperator id operator =
    updateCondition id
        (\condition ->
            { condition
                | operator = operator
                , values =
                    case operandsOf operator of
                        NoOperand ->
                            []

                        OneOperand ->
                            List.take 1 condition.values

                        TwoOperands ->
                            padTo 2 (List.take 2 condition.values)

                        ManyOperands ->
                            condition.values
            }
        )


padTo : Int -> List String -> List String
padTo count values =
    values ++ List.repeat (count - List.length values) ""


{-| Sets the operand at an index of the condition with this id. The arguments
are the id of the condition, the index (0 is the first operand), the text and
the rule. The list of operands grows with empty texts if it is too short.

    Rule.setValue 2 0 "100" rule

-}
setValue : Int -> Int -> String -> Rule -> Rule
setValue id index text =
    updateCondition id
        (\condition ->
            { condition
                | values =
                    padTo (index + 1) condition.values
                        |> List.indexedMap
                            (\i current ->
                                if i == index then
                                    text

                                else
                                    current
                            )
            }
        )


{-| Adds an operand at the end of the condition with this id, for the operators
that take many (`IsAnyOf`, `IsNoneOf`). Empty text and an operand that is
already there are ignored.
-}
addValue : Int -> String -> Rule -> Rule
addValue id text =
    updateCondition id
        (\condition ->
            if List.member text condition.values || text == "" then
                condition

            else
                { condition | values = condition.values ++ [ text ] }
        )


{-| Removes the operands of the condition with this id that are equal to the
text.
-}
removeValue : Int -> String -> Rule -> Rule
removeValue id text =
    updateCondition id (\condition -> { condition | values = List.filter (\value -> value /= text) condition.values })


{-| Moves the node with this id by `delta` places within its group: `-1` one step
up, `1` one step down, `2` two steps down. The nodes it passes shift by one place,
so every node is kept exactly once. Nothing happens when `delta` is `0` or when
the move would take the node past an end of the group.

    Rule.move 2 -1 rule -- node 2 changes places with the node before it

-}
move : Int -> Int -> Rule -> Rule
move id delta rule =
    case rule of
        GroupRule group ->
            let
                children =
                    case indexOfChild id group.children of
                        Just index ->
                            moveWithin index delta group.children

                        Nothing ->
                            group.children
            in
            GroupRule { group | children = List.map (move id delta) children }

        other ->
            other


indexOfChild : Int -> List Rule -> Maybe Int
indexOfChild id children =
    children
        |> List.indexedMap Tuple.pair
        |> List.filter (\( _, child ) -> idOf child == id)
        |> List.head
        |> Maybe.map Tuple.first


moveWithin : Int -> Int -> List a -> List a
moveWithin index delta items =
    let
        target =
            index + delta
    in
    if delta == 0 || target < 0 || target >= List.length items then
        items

    else
        let
            rest =
                List.take index items ++ List.drop (index + 1) items
        in
        List.take target rest ++ List.take 1 (List.drop index items) ++ List.drop target rest


{-| Adds a copy of the node with this id (and of everything inside it) right
after it, with new ids. The root of the rule cannot be duplicated.
-}
duplicate : Int -> Rule -> Rule
duplicate id root =
    let
        start =
            nextId root

        copyOf found =
            renumber start found |> Tuple.first

        insertAfter group =
            case indexOfChild id group.children of
                Just index ->
                    case List.drop index group.children |> List.head of
                        Just original ->
                            { group
                                | children =
                                    List.take (index + 1) group.children
                                        ++ [ copyOf original ]
                                        ++ List.drop (index + 1) group.children
                            }

                        Nothing ->
                            group

                Nothing ->
                    { group | children = List.map (duplicateIn insertAfter) group.children }

        duplicateIn insert child =
            case child of
                GroupRule inner ->
                    GroupRule (insert inner)

                other ->
                    other
    in
    case root of
        GroupRule group ->
            GroupRule (insertAfter group)

        other ->
            other


{-| Gives every node in the subtree a new id, counting up from `start`.
Returns the new tree and the next unused id.
-}
renumber : Int -> Rule -> ( Rule, Int )
renumber start rule =
    case rule of
        ConditionRule condition ->
            ( ConditionRule { condition | id = start }, start + 1 )

        GroupRule group ->
            let
                ( children, next ) =
                    List.foldl
                        (\child ( done, cursor ) ->
                            let
                                ( renumbered, after ) =
                                    renumber cursor child
                            in
                            ( done ++ [ renumbered ], after )
                        )
                        ( [], start + 1 )
                        group.children
            in
            ( GroupRule { group | id = start, children = children }, next )



-- RUNNING A RULE


{-| Reads a number the way people type it, with a decimal point or comma and
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

-}
parseNumber : String -> Maybe Float
parseNumber text =
    let
        -- no spaces, and the minus sign U+2212 that Klar.Format writes is a "-"
        compact =
            text
                |> String.trim
                |> String.filter (\char -> not (isSpaceChar char))
                |> String.replace "−" "-"
    in
    case readSeparated compact of
        Just number ->
            Just number

        Nothing ->
            -- whatever else Elm can read, like "1e3" (a comma still means a point)
            compact
                |> String.replace "," "."
                |> String.toFloat
                |> Maybe.andThen finiteNumber


isSpaceChar : Char -> Bool
isSpaceChar char =
    char == ' ' || char == '\u{00A0}' || char == '\u{202F}' || char == '\u{2009}'


finiteNumber : Float -> Maybe Float
finiteNumber number =
    if isNaN number || isInfinite number then
        Nothing

    else
        Just number


{-| An optional sign and digits with points and commas. `Nothing` for text that
looks like something else, and for separators in the wrong places.
-}
readSeparated : String -> Maybe Float
readSeparated compact =
    let
        ( negative, unsigned ) =
            case String.uncons compact of
                Just ( '-', rest ) ->
                    ( True, rest )

                Just ( '+', rest ) ->
                    ( False, rest )

                _ ->
                    ( False, compact )
    in
    if String.all (\char -> Char.isDigit char || char == '.' || char == ',') unsigned then
        plainNumber unsigned
            |> Maybe.andThen String.toFloat
            |> Maybe.andThen finiteNumber
            |> Maybe.map
                (\number ->
                    if negative then
                        negate number

                    else
                        number
                )

    else
        Nothing


{-| The digits with a decimal point, as `String.toFloat` reads them: "1,234.5"
becomes "1234.5".
-}
plainNumber : String -> Maybe String
plainNumber unsigned =
    case ( String.indexes "." unsigned, String.indexes "," unsigned ) of
        ( [], [] ) ->
            if unsigned == "" then
                Nothing

            else
                Just unsigned

        ( [ _ ], [] ) ->
            oneSeparator "." True unsigned

        ( [], [ _ ] ) ->
            oneSeparator "," False unsigned

        ( _ :: _ :: _, [] ) ->
            thousandGroups "." unsigned

        ( [], _ :: _ :: _ ) ->
            thousandGroups "," unsigned

        ( points, commas ) ->
            -- both kinds: the last separator is the decimal one
            if lastIndex points > lastIndex commas then
                withThousands "." "," unsigned

            else
                withThousands "," "." unsigned


lastIndex : List Int -> Int
lastIndex indexes =
    List.maximum indexes |> Maybe.withDefault -1


{-| A single separator. A point can separate thousands ("1.234", "12.500");
a comma is always a decimal comma.
-}
oneSeparator : String -> Bool -> String -> Maybe String
oneSeparator separator mayBeThousands unsigned =
    case String.split separator unsigned of
        [ whole, fraction ] ->
            if whole == "" && fraction == "" then
                Nothing

            else if mayBeThousands && String.length fraction == 3 && whole /= "" && String.length whole <= 3 && not (String.startsWith "0" whole) then
                Just (whole ++ fraction)

            else
                Just (decimalNumber whole fraction)

        _ ->
            Nothing


{-| Digits in groups of three after the first group: "1,234,567" with the
separator "," is "1234567".
-}
thousandGroups : String -> String -> Maybe String
thousandGroups separator digits =
    case String.split separator digits of
        first :: rest ->
            if first /= "" && String.length first <= 3 && not (String.startsWith "0" first) && List.all (\group -> String.length group == 3) rest then
                Just (String.concat (first :: rest))

            else
                Nothing

        [] ->
            Nothing


{-| Thousands with a separator before the one decimal separator:
"1,234.5" is `withThousands "." "," "1,234.5"`.
-}
withThousands : String -> String -> String -> Maybe String
withThousands decimal thousands unsigned =
    case String.split decimal unsigned of
        [ whole, fraction ] ->
            thousandGroups thousands whole
                |> Maybe.map (\digits -> decimalNumber digits fraction)

        _ ->
            Nothing


decimalNumber : String -> String -> String
decimalNumber whole fraction =
    (if whole == "" then
        "0"

     else
        whole
    )
        ++ (if fraction == "" then
                ""

            else
                "." ++ fraction
           )


{-| Does the condition have everything it needs to filter? The arguments are the
field the condition is on and the condition. Its operator has to fit the field
(see `operatorsFor`), and every operand it needs has to be usable: a number that
`parseNumber` can read, an ISO date, a number of days that is not negative, or
text that is not blank (one choice is enough for `IsAnyOf` and `IsNoneOf`).

`matches` ignores conditions that are not complete, as it ignores conditions on
unknown fields. Otherwise an operator that does not fit the field (from old or
hand-written JSON) or a negative number of days would silently filter out every
row.

-}
isComplete : Field row -> Condition -> Bool
isComplete field condition =
    let
        dayCount text =
            parseNumber text |> Maybe.map (\n -> n >= 0) |> Maybe.withDefault False

        usable text =
            case fieldKind field of
                NumberKind ->
                    parseNumber text /= Nothing

                DateKind ->
                    case condition.operator of
                        InLastDays ->
                            dayCount text

                        InNextDays ->
                            dayCount text

                        _ ->
                            Date.fromIso text /= Nothing

                _ ->
                    String.trim text /= ""
    in
    fitsField field condition
        && (case operandsOf condition.operator of
                NoOperand ->
                    True

                OneOperand ->
                    List.head condition.values |> Maybe.map usable |> Maybe.withDefault False

                TwoOperands ->
                    List.length condition.values >= 2 && List.all usable (List.take 2 condition.values)

                ManyOperands ->
                    List.any usable condition.values
           )


{-| Is the condition's operator one of the field's operators?
-}
fitsField : Field row -> Condition -> Bool
fitsField field condition =
    List.member condition.operator (fieldOperators field)


{-| Does this row satisfy the rule? The arguments are today's date, the fields,
the rule and the row. `today` is what `InLastDays` and `InNextDays` count from;
get it with `Date.fromPosix` ([Klar.Date](Klar-Date)).

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

-}
matches : Date -> List (Field row) -> Rule -> row -> Bool
matches today fields rule row =
    case rule of
        ConditionRule condition ->
            case fieldById fields condition.field of
                Nothing ->
                    True

                Just field ->
                    if isComplete field condition then
                        test today condition.operator condition.values (readField field row)

                    else
                        True

        GroupRule group ->
            let
                active =
                    List.filter (isActive fields) group.children

                outcome =
                    if List.isEmpty active then
                        True

                    else
                        case group.combinator of
                            All ->
                                List.all (\child -> matches today fields child row) active

                            Any ->
                                List.any (\child -> matches today fields child row) active
            in
            if group.negated && not (List.isEmpty active) then
                not outcome

            else
                outcome


{-| A node takes part in the result if it has at least one complete condition.
-}
isActive : List (Field row) -> Rule -> Bool
isActive fields rule =
    case rule of
        ConditionRule condition ->
            fieldById fields condition.field
                |> Maybe.map (\field -> isComplete field condition)
                |> Maybe.withDefault False

        GroupRule group ->
            List.any (isActive fields) group.children


test : Date -> Operator -> List String -> Value -> Bool
test today operator values value =
    let
        first =
            List.head values |> Maybe.withDefault ""

        second =
            values |> List.drop 1 |> List.head |> Maybe.withDefault ""
    in
    case value of
        VMissing ->
            case operator of
                IsEmpty ->
                    True

                IsNot ->
                    True

                NotEquals ->
                    True

                NotContains ->
                    True

                IsNoneOf ->
                    True

                _ ->
                    False

        VText text ->
            let
                normalized =
                    Search.normalize (String.trim text)

                wanted =
                    Search.normalize (String.trim first)
            in
            case operator of
                Is ->
                    normalized == wanted

                IsNot ->
                    normalized /= wanted

                Contains ->
                    String.contains wanted normalized

                NotContains ->
                    not (String.contains wanted normalized)

                StartsWith ->
                    String.startsWith wanted normalized

                EndsWith ->
                    String.endsWith wanted normalized

                IsEmpty ->
                    normalized == ""

                IsNotEmpty ->
                    normalized /= ""

                _ ->
                    False

        VNumber number ->
            case operator of
                IsNotEmpty ->
                    True

                IsEmpty ->
                    False

                Between ->
                    case ( parseNumber first, parseNumber second ) of
                        ( Just low, Just high ) ->
                            number >= min low high && number <= max low high

                        _ ->
                            True

                _ ->
                    case parseNumber first of
                        Nothing ->
                            True

                        Just operand ->
                            case operator of
                                Equals ->
                                    number == operand

                                NotEquals ->
                                    number /= operand

                                LessThan ->
                                    number < operand

                                LessOrEqual ->
                                    number <= operand

                                GreaterThan ->
                                    number > operand

                                GreaterOrEqual ->
                                    number >= operand

                                _ ->
                                    False

        VDate date ->
            let
                days =
                    Date.toEpochDay date

                todayDays =
                    Date.toEpochDay today
            in
            case operator of
                IsNotEmpty ->
                    True

                IsEmpty ->
                    False

                InLastDays ->
                    case parseNumber first of
                        Just n ->
                            days <= todayDays && days >= todayDays - round n

                        Nothing ->
                            True

                InNextDays ->
                    case parseNumber first of
                        Just n ->
                            days >= todayDays && days <= todayDays + round n

                        Nothing ->
                            True

                Between ->
                    case ( Date.fromIso first, Date.fromIso second ) of
                        ( Just low, Just high ) ->
                            let
                                a =
                                    Date.toEpochDay low

                                b =
                                    Date.toEpochDay high
                            in
                            days >= min a b && days <= max a b

                        _ ->
                            True

                _ ->
                    case Date.fromIso first of
                        Nothing ->
                            True

                        Just operand ->
                            let
                                other =
                                    Date.toEpochDay operand
                            in
                            case operator of
                                Is ->
                                    days == other

                                IsNot ->
                                    days /= other

                                Before ->
                                    days < other

                                After ->
                                    days > other

                                OnOrBefore ->
                                    days <= other

                                OnOrAfter ->
                                    days >= other

                                _ ->
                                    False

        VBool flag ->
            case operator of
                IsTrue ->
                    flag

                IsFalse ->
                    not flag

                _ ->
                    False

        VChoice choice ->
            case operator of
                Is ->
                    choice == first

                IsNot ->
                    choice /= first

                IsAnyOf ->
                    List.member choice values

                IsNoneOf ->
                    not (List.member choice values)

                IsEmpty ->
                    False

                IsNotEmpty ->
                    True

                _ ->
                    False



-- CHECKING A RULE


{-| A problem with one node of the rule, for showing next to it: the `nodeId`
of the group or condition, and a `message` in the language of the locale given
to `validate`.
-}
type alias Issue =
    { nodeId : Int
    , message : String
    }


{-| What is wrong with the rule, for showing next to the nodes that have a
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

-}
validate : Locale -> List (Field row) -> Rule -> List Issue
validate locale fields rule =
    let
        pick nb en =
            Locale.pick locale { nb = nb, en = en }
    in
    case rule of
        GroupRule group ->
            (if List.isEmpty group.children && group.id /= 0 then
                [ { nodeId = group.id, message = pick "Gruppen er tom" "The group is empty" } ]

             else
                []
            )
                ++ List.concatMap (validate locale fields) group.children

        ConditionRule condition ->
            case fieldById fields condition.field of
                Nothing ->
                    [ { nodeId = condition.id, message = pick "Velg et felt" "Choose a field" } ]

                Just field ->
                    if not (fitsField field condition) then
                        [ { nodeId = condition.id, message = pick "Betingelsen passer ikke til feltet" "The operator does not fit the field" } ]

                    else if isComplete field condition then
                        case ( condition.operator, fieldKind field ) of
                            ( Between, NumberKind ) ->
                                case List.map parseNumber (List.take 2 condition.values) of
                                    [ Just low, Just high ] ->
                                        if low > high then
                                            [ { nodeId = condition.id, message = pick "Fra-verdien kan ikke være større enn til-verdien" "The first value must not be larger than the second" } ]

                                        else
                                            []

                                    _ ->
                                        []

                            ( Between, DateKind ) ->
                                case List.map Date.fromIso (List.take 2 condition.values) of
                                    [ Just low, Just high ] ->
                                        if Date.compare low high == GT then
                                            [ { nodeId = condition.id, message = pick "Fra-datoen kan ikke være etter til-datoen" "The start date must not be after the end date" } ]

                                        else
                                            []

                                    _ ->
                                        []

                            _ ->
                                []

                    else
                        [ { nodeId = condition.id
                          , message =
                                case ( fieldKind field, condition.operator ) of
                                    ( NumberKind, _ ) ->
                                        pick "Skriv inn et gyldig tall" "Enter a valid number"

                                    ( DateKind, InLastDays ) ->
                                        pick "Skriv inn et antall dager" "Enter a number of days"

                                    ( DateKind, InNextDays ) ->
                                        pick "Skriv inn et antall dager" "Enter a number of days"

                                    ( DateKind, _ ) ->
                                        pick "Velg en gyldig dato" "Choose a valid date"

                                    _ ->
                                        pick "Mangler verdi" "A value is missing"
                          }
                        ]



-- IN WORDS


{-| The rule as a sentence, for a summary or a tooltip:

    Rule.describe Locale.en fields rule
    -- "Status is Paid and (Total > 100 or Country is “Norway”)"

Incomplete conditions and groups without a complete condition are left out. A
rule with nothing left reads "All rows". Groups inside the rule are put in
parentheses when they have more than one part, and a negated group reads
"not (...)". Text operands are put in quotation marks (see `quote`), choices
are written with their label and dates in the format of the locale.

-}
describe : Locale -> List (Field row) -> Rule -> String
describe locale fields rule =
    describeNode locale fields True rule |> Maybe.withDefault (Locale.pick locale { nb = "Alle rader", en = "All rows" })


describeNode : Locale -> List (Field row) -> Bool -> Rule -> Maybe String
describeNode locale fields isRoot rule =
    let
        pick nb en =
            Locale.pick locale { nb = nb, en = en }
    in
    case rule of
        ConditionRule condition ->
            fieldById fields condition.field
                |> Maybe.andThen
                    (\field ->
                        if isComplete field condition then
                            Just (describeCondition locale field condition)

                        else
                            Nothing
                    )

        GroupRule group ->
            let
                parts =
                    List.filterMap (describeNode locale fields False) group.children

                joiner =
                    case group.combinator of
                        All ->
                            pick " og " " and "

                        Any ->
                            pick " eller " " or "

                body =
                    String.join joiner parts

                wrapped =
                    if List.length parts > 1 && not isRoot then
                        "(" ++ body ++ ")"

                    else
                        body
            in
            if List.isEmpty parts then
                Nothing

            else if group.negated then
                Just (pick "ikke (" "not (" ++ body ++ ")")

            else
                Just wrapped


{-| One condition as words: "Status is Paid", "Created in the last 30 days".
-}
describeCondition : Locale -> Field row -> Condition -> String
describeCondition locale field condition =
    let
        days =
            condition.values |> List.head |> Maybe.withDefault ""

        pick nb en =
            Locale.pick locale { nb = nb, en = en }

        -- "1 day", "30 days"
        unit =
            if parseNumber days == Just 1 then
                pick " dag" " day"

            else
                pick " dager" " days"
    in
    case condition.operator of
        InLastDays ->
            fieldLabel field ++ " " ++ pick "siste " "in the last " ++ days ++ unit

        InNextDays ->
            fieldLabel field ++ " " ++ pick "neste " "in the next " ++ days ++ unit

        _ ->
            fieldLabel field ++ " " ++ operatorLabel locale (fieldKind field) condition.operator ++ operandText locale field condition


{-| Puts a text in the quotation marks of the locale: “Ada” for `Locale.en`, «Ada»
for `Locale.nb`. `describe` uses it for the operands of text fields.
-}
quote : Locale -> String -> String
quote locale text =
    Locale.pick locale { nb = "«" ++ text ++ "»", en = "“" ++ text ++ "”" }


operandText : Locale -> Field row -> Condition -> String
operandText locale field condition =
    let
        label value =
            case fieldKind field of
                ChoiceKind choices ->
                    choices
                        |> List.filter (\choice -> choice.value == value)
                        |> List.head
                        |> Maybe.map .label
                        |> Maybe.withDefault value

                DateKind ->
                    Date.fromIso value
                        |> Maybe.map (Format.date locale)
                        |> Maybe.withDefault value

                _ ->
                    value

        quoted value =
            case fieldKind field of
                TextKind ->
                    " " ++ quote locale value

                _ ->
                    " " ++ label value
    in
    case operandsOf condition.operator of
        NoOperand ->
            ""

        OneOperand ->
            condition.values |> List.head |> Maybe.map quoted |> Maybe.withDefault ""

        TwoOperands ->
            case condition.values of
                low :: high :: _ ->
                    " " ++ label low ++ " – " ++ label high

                _ ->
                    ""

        ManyOperands ->
            " " ++ String.join ", " (List.map label (List.filter (\value -> value /= "") condition.values))



-- JSON


{-| The rule as JSON, for storing it or sending it to a backend. The ids of the
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

-}
encode : Rule -> Encode.Value
encode rule =
    case rule of
        GroupRule group ->
            Encode.object
                [ ( "type", Encode.string "group" )
                , ( "combinator"
                  , Encode.string
                        (case group.combinator of
                            All ->
                                "all"

                            Any ->
                                "any"
                        )
                  )
                , ( "not", Encode.bool group.negated )
                , ( "children", Encode.list encode group.children )
                ]

        ConditionRule condition ->
            Encode.object
                [ ( "type", Encode.string "condition" )
                , ( "field", Encode.string condition.field )
                , ( "operator", Encode.string (operatorKey condition.operator) )
                , ( "values", Encode.list Encode.string condition.values )
                ]


{-| Reads a rule from the JSON that `encode` writes, and gives every node a
fresh id: 0 for the root, then counting up from the top down.

    Decode.decodeString Rule.decoder text

`not` may be left out of a group (meaning false), and a `combinator` other than
"any" is read as "all". An unknown `type` or operator makes the decoder fail.

Groups nested more than 32 deep are refused (nobody writes that, and it keeps a
hostile text from running the decoder out of stack). Check a limit of your own
with `depth`.

-}
decoder : Decoder Rule
decoder =
    Decode.map (\rule -> renumber 0 rule |> Tuple.first) (ruleDecoder 32)


ruleDecoder : Int -> Decoder Rule
ruleDecoder levels =
    Decode.field "type" Decode.string
        |> Decode.andThen
            (\kind ->
                case kind of
                    "group" ->
                        if levels <= 0 then
                            Decode.fail "The groups are nested too deeply"

                        else
                            Decode.map3
                                (\combinator negated children ->
                                    GroupRule { id = 0, combinator = combinator, negated = negated, children = children }
                                )
                                (Decode.field "combinator" Decode.string
                                    |> Decode.map
                                        (\text ->
                                            if text == "any" then
                                                Any

                                            else
                                                All
                                        )
                                )
                                (Decode.oneOf [ Decode.field "not" Decode.bool, Decode.succeed False ])
                                (Decode.field "children" (Decode.list (Decode.lazy (\_ -> ruleDecoder (levels - 1)))))

                    "condition" ->
                        Decode.map3
                            (\field operator values ->
                                ConditionRule { id = 0, field = field, operator = operator, values = values }
                            )
                            (Decode.field "field" Decode.string)
                            (Decode.field "operator" Decode.string
                                |> Decode.andThen
                                    (\key ->
                                        case operatorFromKey key of
                                            Just operator ->
                                                Decode.succeed operator

                                            Nothing ->
                                                Decode.fail ("Unknown operator: " ++ key)
                                    )
                            )
                            (Decode.field "values" (Decode.list Decode.string))

                    other ->
                        Decode.fail ("Unknown rule type: " ++ other)
            )
