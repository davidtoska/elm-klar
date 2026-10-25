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

-- Issues and focus
showIssues : State -> State
hideIssues : State -> State
issues : Locale.Locale -> List (Rule.Field row) -> State -> List Rule.Problem
focusId : List (Rule.Field row) -> State -> Int -> String
focusNode : List (Rule.Field row) -> State -> Int -> Cmd Msg
focusIssue : List (Rule.Field row) -> State -> Cmd Msg

-- Attributes
type Attribute row msg  -- opaque: no constructors are exposed
fields : List (Rule.Field row) -> Attribute row msg
today : Date.Date -> Attribute row msg
maxDepth : Int -> Attribute row msg
ariaLabel : String -> Attribute row msg
locale : Locale.Locale -> Attribute row msg

-- In a form
label : String -> Attribute row msg
hint : String -> Attribute row msg
error : String -> Attribute row msg
errorMaybe : Maybe String -> Attribute row msg
required : Attribute row msg
optionalText : String -> Attribute row msg

-- Match count
matchCount : Remote.Remote Int -> Attribute row msg
totalCount : Int -> Attribute row msg
onRetry : msg -> Attribute row msg

-- Toolbar
json : Attribute row msg
importJson : Attribute row msg
actions : List (Html msg) -> Attribute row msg
```

## Documentation

A visual editor for rules: groups of conditions that the user builds,
rearranges and reads as a sentence, drawn with thin gray connector lines.

Use when: users need the full power of nested "all of" and "any of" groups of conditions.
Do not use when: a row of filter chips above a table is enough (use `Klar.FilterBar`).
Quick path: `init`, `update`, `view`, `rule`

It edits a [Klar.Rule](Klar.Rule.md) `Rule` and never sees your rows: the
application runs the rule with `Rule.matches` and passes the number of matching
rows with `matchCount`, as a [Klar.Remote](Klar.Remote.md). Use it when users need the full power of nested "all
of" and "any of" groups. For a row of filter chips above a table,
[Klar.FilterBar](Klar.FilterBar.md) is the lighter choice; both work on the same
`Rule`.

    import Klar.Remote as Remote
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
        , RuleBuilder.matchCount (Remote.Loaded (List.length matching))
        , RuleBuilder.today today
        , RuleBuilder.json
        ]
        model.rules

    -- the orders that match the rule
    matching =
        List.filter (Rule.matches today orderFields (RuleBuilder.rule model.rules)) model.orders

`orderFields` is a `List (Rule.Field Order)` made with `Rule.textField` and
friends. A count that takes time (a server, a large data set) is the `Remote` it
is: `Loading` shows "Counting ...", `Remote.refresh` keeps the old count, dimmed,
while the new one is on its way, and a failed count offers `onRetry`.

**The outcome is yours.** A rule is only the condition: what happens when it
matches (a discount, a tag, a route) is neither in `Rule` nor in the builder. In a
form, declare the pair as a row: `Spec.conditions` and the outcome's own field in
one sub-form, `Spec.rows` around it, and the form adds, removes, saves and checks
the pairs (see [`Klar.Form`](Klar.Form.md)). Outside a form, keep one record per rule,
with a key that stays with it when others are removed, give each builder an id
made from that key, and ask each rule about the row:

    import Klar.Date exposing (Date)
    import Klar.Rule as Rule
    import Klar.RuleBuilder as RuleBuilder

    type alias Order =
        { category : String, quantity : Int }

    type alias PriceRule =
        { key : Int
        , when : RuleBuilder.State -- RuleBuilder.init ("price-rule-" ++ String.fromInt key)
        , discountPercent : Float
        }

    orderFields : List (Rule.Field Order)
    orderFields =
        [ Rule.textField "category" "Category" .category
        , Rule.numberField "quantity" "Quantity" (.quantity >> toFloat >> Just)
        ]

    discountFor : Date -> List PriceRule -> Order -> Float
    discountFor today priceRules order =
        priceRules
            |> List.filter (\priceRule -> Rule.matches today orderFields (RuleBuilder.rule priceRule.when) order)
            |> List.map .discountPercent
            |> List.maximum
            |> Maybe.withDefault 0

Draw the discount next to `RuleBuilder.view` in the same card; the message of each
builder carries the key of its rule. Focus the first unfinished builder with
`focusIssue`. Rules kept outside a `Klar.Form` report their problems into it with
`Form.outside`.

**Editors**: the field picker is a searchable [Klar.Select](Klar.Select.md),
grouped by the heading given with `Rule.inGroup`; the operators come from
`Rule.fieldOperators` (the field's `Rule.withOperators`, or every operator that
fits its kind). The value editor follows the field and the operator: a
text input, a number input (read by `Rule.parseNumber`: a decimal comma or
point and separators between the thousands, two inputs for "between"), a
[Klar.DatePicker](Klar.DatePicker.md) (the operand is stored as ISO `YYYY-MM-DD`),
a whole number of days for "in the last / next N days" and "more than N days
ago / ahead", a select of periods for "is within" (this month, last quarter
...), a [Klar.Select](Klar.Select.md) for one choice and a
[Klar.MultiSelect](Klar.MultiSelect.md) for "is any of" and "is none of". Yes or
no fields and "is empty" take no value.

**Issues** (`Rule.validate`, one per node) are shown on the node that has them: a red line
around the control and a short message. A node shows its issues once the user
has tried to fill it in (typed, picked, or left a value field), so a fresh,
empty condition is not red. `showIssues` shows every issue at once, for example
when the user tries to save. `issues` lists them for the application, and
`focusIssue` (or `focusNode` for one node) moves the focus to the control that
needs attention, so that a Save that finds an incomplete rule never leaves the
user looking at a button. `focusId` is the DOM id of that control, for a
`Form.Problem` that points into the builder: nothing is read from the page.

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
does not have the id 0 or an id occurs twice. An offer to undo is dropped.

When the new rule says the same as the old one (the same conditions and groups,
ids aside), collapsed groups, open pickers and the issues the user has already
seen are kept. Another rule starts fresh: no node of it counts as touched, so
its issues wait until the user works on it (or `showIssues`), and no group is
collapsed.

### `clear`

```elm
clear : State -> State
```

Starts over with an empty rule. Unlike the "Reset" button of the toolbar it
does not offer to undo.

## Issues and focus

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

### `issues`

```elm
issues : Locale.Locale -> List (Rule.Field row) -> State -> List Rule.Problem
```

Every issue the builder can show, for the fields given: `Rule.validate` of
the rule, at most one for each node, in the order of the tree. Each names the
node it belongs to. It is what a form or a save button asks before it lets the
rule through; the language is the one of the messages.

    RuleBuilder.issues Locale.en orderFields model.rules
    -- [ { nodeId = 2, message = "Enter a valid number" } ]

### `focusId`

```elm
focusId : List (Rule.Field row) -> State -> Int -> String
```

The DOM id of the control that stands for a node when the focus has to go
there: the first control a user fills in on a condition (the field picker when no
field is chosen, then the operator or the first value), the "add condition"
button of a group. Use it as the `field` of a `Form.Problem` that points at the
node, so that the summary of a form moves the focus into the builder. Nothing
needs to be read from the page: the id is made from the id given to `init`.
A node that does not exist leads to the "add condition" button of the whole rule.

### `focusNode`

```elm
focusNode : List (Rule.Field row) -> State -> Int -> Cmd Msg
```

Moves the focus to a node of the rule (see `focusId`). Map the command with
the constructor you wrap the builder's messages in.

    RuleBuilder.focusNode orderFields model.rules 2 |> Cmd.map RulesMsg

Nothing happens while the builder is not on screen.

### `focusIssue`

```elm
focusIssue : List (Rule.Field row) -> State -> Cmd Msg
```

Moves the focus to the first node that has an issue (see `issues`), or to
the "add condition" button of the whole rule when there is none, for example
when the user presses Save on an empty rule. Use it with `showIssues`:

    ( RuleBuilder.showIssues rules, RuleBuilder.focusIssue orderFields rules |> Cmd.map RulesMsg )

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

### `ariaLabel`

```elm
ariaLabel : String -> Attribute row msg
```

The name of the builder for screen readers, when it has no visible `label`.
The default is "Rule builder".

### `locale`

```elm
locale : Locale.Locale -> Attribute row msg
```

The language of the builder's own text: buttons, issue messages, the summary
sentence. The default is `Locale.default`, which is `Locale.en`. Field labels and
choices come from the application.

## In a form

A builder in a form has a visible label, a hint, a required mark and an error
message, like the other fields; `Form.ruleBuilder` sets them from the declaration.
Without a `label` the builder is named by `ariaLabel` alone.

### `label`

```elm
label : String -> Attribute row msg
```

A visible label above the builder, as a form field has; it also names the
builder for screen readers. The default is no label.

### `hint`

```elm
hint : String -> Attribute row msg
```

A line of help under the label, read with the builder by screen readers.

### `error`

```elm
error : String -> Attribute row msg
```

A problem with the rule as a whole, in red under the builder, such as "Add a
condition" for a required rule. The problems of single conditions are the
builder's own (see `issues`).

### `errorMaybe`

```elm
errorMaybe : Maybe String -> Attribute row msg
```

Like `error`, with `Nothing` for no problem.

### `required`

```elm
required : Attribute row msg
```

Marks the rule as required: a `*` after the label. The builder checks
nothing itself.

### `optionalText`

```elm
optionalText : String -> Attribute row msg
```

A text after the label of a rule that is not required, such as "(optional)".

## Match count

### `matchCount`

```elm
matchCount : Remote.Remote Int -> Attribute row msg
```

How many rows the rule matches, shown next to the summary as "1,482
matches". Give `Remote.Loaded n` for a count you have (`Rule.matches`), or the
`Remote` of a count that takes time:

  - `Loading`: a spinner and "Counting ...".
  - `Failed`: "The count failed", with a retry button when there is `onRetry`.
  - Refreshing (`Remote.refresh` of a count): the old count stays, dimmed, with
    a spinner.
  - Old (`Remote.Kept` after a failed refresh): the old count, marked old, with
    the retry.

`NotAsked`, the default, shows no count. The count is in a polite live region, so
a screen reader hears the new number.

    RuleBuilder.matchCount (Remote.Loaded (List.length matching))

### `totalCount`

```elm
totalCount : Int -> Attribute row msg
```

The number of rows before filtering. With a `matchCount` the count reads
"1,482 of 3,000 matches". Without a `matchCount` nothing is shown.

### `onRetry`

```elm
onRetry : msg -> Attribute row msg
```

The message of the retry button that a failed or old `matchCount` shows.
Without it there is no retry button.

## Toolbar

### `json`

```elm
json : Attribute row msg
```

Adds a "Show JSON" button to the toolbar. It opens the rule as JSON
(`Rule.encode`, indented) with a "Download" button that saves it as `rule.json`
(`regel.json` in Norwegian) through `File.Download`, so `update` returns the
command that does it.

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
