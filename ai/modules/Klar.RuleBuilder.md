# Klar.RuleBuilder

A visual editor for rules: groups of conditions that the user builds, rearranges and reads as a sentence, drawn with thin gray connector lines.

Import: `import Klar.RuleBuilder as RuleBuilder` | Group: Rules and filters

Types: `Msg`, `State`, `Attribute`

## Signatures

```elm
-- View
view : (Msg -> msg) -> List (Attribute row msg) -> State -> Html msg

-- State
type State  -- opaque: no constructors are exposed
type Msg  -- opaque: no constructors are exposed
init : String -> State
update : Msg -> State -> ( State, Cmd Msg )

-- The rule
rule : State -> Rule.Rule
setRule : Rule.Rule -> State -> State
clear : State -> State

-- Issues
showIssues : State -> State
hideIssues : State -> State

-- Attributes
type Attribute row msg  -- opaque: no constructors are exposed
fields : List (Rule.Field row) -> Attribute row msg
today : Date.Date -> Attribute row msg
maxDepth : Int -> Attribute row msg
label : String -> Attribute row msg
locale : Locale.Locale -> Attribute row msg

-- Match count
matchCount : Maybe Int -> Attribute row msg
totalCount : Int -> Attribute row msg
counting : Bool -> Attribute row msg

-- Toolbar
json : Attribute row msg
importJson : Attribute row msg
actions : List (Html msg) -> Attribute row msg
```

## Documentation

A visual editor for rules: groups of conditions that the user builds,
rearranges and reads as a sentence, drawn with thin gray connector lines.

It edits a [Klar.Rule](Klar.Rule.md) `Rule` and never sees your rows: the
application runs the rule with `Rule.matches` and passes the number of matching
rows with `matchCount`. Use it when users need the full power of nested "all
of" and "any of" groups. For a row of filter chips above a table,
[Klar.FilterBar](Klar.FilterBar.md) is the lighter choice; both work on the same
`Rule`.

    import Klar.Rule as Rule
    import Klar.RuleBuilder as RuleBuilder

    -- model
    { rules : RuleBuilder.State } -- RuleBuilder.init "order-rules"

    -- update
    RulesMsg m ->
        let
            ( rules, cmd ) =
                RuleBuilder.update m model.rules
        in
        ( { model | rules = rules }, Cmd.map RulesMsg cmd )
        -- compare RuleBuilder.rule rules with RuleBuilder.rule model.rules
        -- to react to a change (save the rule, count the matches ...)

    -- view
    RuleBuilder.view RulesMsg
        [ RuleBuilder.fields orderFields
        , RuleBuilder.matchCount (Just (List.length matching))
        , RuleBuilder.today today
        , RuleBuilder.json
        ]
        model.rules

    -- the orders that match the rule
    matching =
        List.filter (Rule.matches today orderFields (RuleBuilder.rule model.rules)) model.orders

`orderFields` is a `List (Rule.Field Order)` made with `Rule.textField` and
friends. For a large data set the application can show `counting True` while it
works out the count.

**Editors**: the field picker is a searchable [Klar.Select](Klar.Select.md),
grouped by the heading given with `Rule.inGroup`; the operators come from
`Rule.operatorsFor`. The value editor follows the field and the operator: a
text input, a number input (read by `Rule.parseNumber`: a decimal comma or
point and separators between the thousands, two inputs for "between"), a
[Klar.DatePicker](Klar.DatePicker.md) (the operand is stored as ISO `YYYY-MM-DD`),
a number of days for "in the last / next N days", a
[Klar.Select](Klar.Select.md) for one choice and a
[Klar.MultiSelect](Klar.MultiSelect.md) for "is any of" and "is none of". Yes or
no fields and "is empty" take no value.

**Issues** (`Rule.validate`) are shown on the node that has them: a red line
around the control and a short message. A node shows its issues once the user
has tried to fill it in (typed, picked, or left a value field), so a fresh,
empty condition is not red. `showIssues` shows every issue at once, for example
when the user tries to save.

**Keyboard**: every control is reached with `Tab`. The pickers open with
`Enter`, `Space` or `ArrowDown` and search as you type; "All" and "Any" switch
with the arrow keys; the menu of a group (the three dots) moves, duplicates and
removes it. `Enter` in a value field does nothing destructive, and `Delete` or
`Backspace` never removes a condition or a group: they have buttons of their
own, and a removal, a reset or an import can be undone with the "Undo" button
that appears. Groups can be collapsed to a one-line summary.

**State and text**: the state holds the rule and what the user is doing with
it (collapsed groups, open pickers and menus, the JSON and import panels, the
last change that can be undone). The built-in text (buttons, issue messages,
the summary sentence) follows `locale`, which is English by default; the labels
of fields and choices come from the application.

## View

### `view`

```elm
view : (Msg -> msg) -> List (Attribute row msg) -> State -> Html msg
```

The builder: the tree of groups and conditions, then the summary sentence
(`Rule.describe`) with the match count, and the toolbar ("Reset", the JSON and
import buttons if asked for, and your `actions`). The first argument turns the
builder's messages into yours.

    RuleBuilder.view RulesMsg [ RuleBuilder.fields orderFields ] model.rules

## State

### `State`

```elm
type State  -- opaque: no constructors are exposed
```

The state of one rule builder: the rule and what the user is doing with it
(collapsed groups, open pickers and menus, the JSON and import panels, the
change that can be undone). Make one with `init`, keep it in your model and pass
it to `view` and `update`. Read the rule with `rule`.

### `Msg`

```elm
type Msg  -- opaque: no constructors are exposed
```

A message from the builder. Wrap it in one of your own messages and pass it
to `update`.

### `init`

```elm
init : String -> State
```

A rule builder with an empty rule, which matches every row. The `String` is
the DOM id of the builder and must be unique on the page; the ids of its inner
controls start with it.

    RuleBuilder.init "order-rules"

### `update`

```elm
update : Msg -> State -> ( State, Cmd Msg )
```

Applies a message from the builder. The command moves keyboard focus (to a
new condition, to a neighbour after a removal ...), so map it with `Cmd.map`.
Compare `rule` before and after to react to a change.

## The rule

### `rule`

```elm
rule : State -> Rule.Rule
```

The rule being built. The root is always a group, with the id 0. Compare it
before and after `update` to find out whether the user changed the rule.

### `setRule`

```elm
setRule : Rule.Rule -> State -> State
```

Replaces the rule, for example with a saved one. A rule that is a lone
condition is put in a group, and the nodes are renumbered from 0 if the root
does not have the id 0 or an id occurs twice. Collapsed groups and other state
are kept for the nodes that still exist; an offer to undo is dropped.

### `clear`

```elm
clear : State -> State
```

Starts over with an empty rule. Unlike the "Reset" button of the toolbar it
does not offer to undo.

## Issues

### `showIssues`

```elm
showIssues : State -> State
```

Shows every issue now, also on nodes the user has not touched yet. Call it
when the user tries to save an incomplete rule.

### `hideIssues`

```elm
hideIssues : State -> State
```

Hides the issues again until the user touches a node, for example after a
successful save.

## Attributes

### `Attribute`

```elm
type Attribute row msg  -- opaque: no constructors are exposed
```

A setting of the builder. Make them with the functions below and pass a
list to `view`; later attributes win over earlier ones. The type parameters are
the row type of your fields and your message type.

### `fields`

```elm
fields : List (Rule.Field row) -> Attribute row msg
```

What the rules can talk about: the fields the user can pick for a
condition, made with `Rule.textField` and the other field functions. The first
field is the one a new condition starts with. The default is no fields.

    RuleBuilder.fields
        [ Rule.textField "country" "Country" .country
        , Rule.numberField "total" "Total" (.total >> Just)
        ]

### `today`

```elm
today : Date.Date -> Attribute row msg
```

Today's date, for the date pickers of date fields: it marks the day, powers
their "Today" button and completes short input. It does not change what a rule
matches; give the same date to `Rule.matches`.

### `maxDepth`

```elm
maxDepth : Int -> Attribute row msg
```

How many levels of groups a rule may have, counting the outermost group. The
default is 4, and values below 1 count as 1. Groups on the deepest level get no
"Add group" button, and an imported rule that is deeper is refused. A rule that
the application gives with `setRule` is shown as it is.

### `label`

```elm
label : String -> Attribute row msg
```

The accessible name of the builder. The default is "Rule builder".

### `locale`

```elm
locale : Locale.Locale -> Attribute row msg
```

The language of the builder's own text: buttons, issue messages, the summary
sentence. The default is `Locale.default`, which is `Locale.en`. Field labels and
choices come from the application.

## Match count

### `matchCount`

```elm
matchCount : Maybe Int -> Attribute row msg
```

How many rows the rule matches, counted by the application (for example
with `Rule.matches`). Shown next to the summary as "1,482 matches". `Nothing`,
the default, shows no count.

### `totalCount`

```elm
totalCount : Int -> Attribute row msg
```

The number of rows before filtering. With a `matchCount` the count reads
"1,482 of 3,000 matches". Without a `matchCount` nothing is shown.

### `counting`

```elm
counting : Bool -> Attribute row msg
```

While `True` the builder shows a spinner and "Running ..." instead of the
count, for a large data set that takes time to filter. The default is `False`.

## Toolbar

### `json`

```elm
json : Attribute row msg
```

Adds a "Show JSON" button to the toolbar. It opens the rule as JSON
(`Rule.encode`, indented) with a "Download" link that saves it as `rule.json`.

### `importJson`

```elm
importJson : Attribute row msg
```

Adds an "Import JSON" button to the toolbar: the user pastes a rule as JSON
(the format of `Rule.decoder`) and applies it. Text that is not valid JSON, or
not a rule, gives a message. So does a rule with more levels of groups than
`maxDepth` allows: it is refused, never trimmed, because cutting groups off would
change what the rule means. A valid rule replaces the current one, and the
replacement can be undone.

### `actions`

```elm
actions : List (Html msg) -> Attribute row msg
```

Extra buttons at the end of the builder's toolbar, such as a "Save rule"
button. They are your own `Html`, and their messages are yours.

    RuleBuilder.actions
        [ Button.view [ Button.primary, Button.onClick SaveRule ] "Save rule" ]
