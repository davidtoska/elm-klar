# Klar.FilterBar

Quick filters above a table: the conditions that are on, shown as chips ("Status is Paid"), an "Add filter" button that opens a small editor (field, operator, value), and optional preset pills like ...

Import: `import Klar.FilterBar as FilterBar` | Group: Rules and filters

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

-- The filters
rule : State -> Rule.Rule
setRule : Rule.Rule -> State -> State
clear : State -> State
isOpen : State -> Bool
close : State -> ( State, Cmd Msg )

-- Attributes
type Attribute row msg  -- opaque: no constructors are exposed
fields : List (Rule.Field row) -> Attribute row msg
quick : List ( String, Rule.Rule ) -> Attribute row msg
today : Date.Date -> Attribute row msg
ariaLabel : String -> Attribute row msg
addLabel : String -> Attribute row msg
locale : Locale.Locale -> Attribute row msg

-- Match count
matchCount : Remote.Remote Int -> Attribute row msg
totalCount : Int -> Attribute row msg
onRetry : msg -> Attribute row msg
```

## Documentation

Quick filters above a table: the conditions that are on, shown as chips
("Status is Paid"), an "Add filter" button that opens a small editor (field,
operator, value), and optional preset pills like "Unpaid".

Use when: users filter a table with a few quick conditions shown as chips and presets.
Do not use when: users need nested groups of conditions (use `Klar.RuleBuilder`).
Quick path: `init`, `update`, `view`, `rule`

    import Klar.FilterBar as FilterBar
    import Klar.Remote as Remote
    import Klar.Rule as Rule

    -- model
    { filters : FilterBar.State } -- FilterBar.init "order-filters"

    -- update
    FiltersMsg m ->
        let
            ( filters, cmd ) =
                FilterBar.update m model.filters
        in
        ( { model | filters = filters }, Cmd.map FiltersMsg cmd )

    -- view
    FilterBar.view FiltersMsg
        [ FilterBar.fields orderFields
        , FilterBar.quick [ ( "Unpaid", unpaid ), ( "Large orders", large ) ]
        , FilterBar.matchCount (Remote.Loaded (List.length visible))
        , FilterBar.today today
        ]
        model.filters

    -- the rows to show
    visible =
        List.filter (Rule.matches today orderFields (FilterBar.rule model.filters)) model.orders

    -- the presets are rules: "Status is Open" and "Total > 1000"
    unpaid : Rule.Rule
    unpaid =
        Rule.is "status" "open"

    large : Rule.Rule
    large =
        Rule.when "total" Rule.GreaterThan [ "1000" ]

`orderFields` is a `List (Rule.Field Order)` made with `Rule.textField` and
friends. A count that takes time (a server, a large data set) is the `Remote` it
is: `Loading` shows "Counting ...", `Remote.refresh` keeps the old count, dimmed,
while the new one is on its way, and a failed count offers `onRetry`.

The filters are a [Klar.Rule](Klar.Rule.md) `Rule`: a root group with one child for
each chip, combined with "and". The same rule can be handed to `Rule.matches` or
opened in [Klar.RuleBuilder](Klar.RuleBuilder.md) with
`RuleBuilder.setRule (FilterBar.rule model.filters)`. A rule made in the builder
can be shown here too (`setRule`): conditions become chips, nested groups become
read-only chips that can be removed, and the bar says how the chips combine when
it is not "and" ("Any of:"). A new filter is always combined with "and" with
what is there.

Clicking a chip opens the editor for it, in a popover under the chip. The
filter is only changed when the user applies it; a filter that is not complete
is not added, and the editor says what is missing. A chip whose condition is not
complete (possible after `setRule`) says so (to screen readers too) and does not
filter. Removing a chip and "Clear all" can be undone with the "Undo" button that
appears at the end of the bar. A preset whose rule does not fit the fields (a
misspelled field id, an operator of another kind) is drawn disabled, with the
problem as its tooltip, so the mistake shows at once.

**Keyboard**: `Tab` moves through the pills and buttons; the chips are one stop.
Among the chips `ArrowLeft` and `ArrowRight` move, `Home` and `End` go to the
first and the last, `Enter` or `Space` opens the editor of a condition chip, and
`Delete` or `Backspace` removes a chip (focus goes to its neighbour, and the
removal can be undone). A group chip (a group made in a `RuleBuilder` or a
preset) is edited where it was made: `Enter` does nothing on it, and it can only
be removed. The remove buttons are for the mouse; they are not tab stops. In the editor `Enter` in a text or number
field applies, and `Ctrl+Enter` (`Cmd+Enter` on a Mac) applies from any control,
also from a choice or a date; in a date field `Enter` takes the date that was
typed. `Escape` closes the editor without applying and gives focus back to the
chip or the add button (`Escape` in an open picker closes only the picker), and
moving focus out of the editor closes it too.

**State and text**: the state holds the filters and the editor that is open,
with the draft the user is working on. The built-in text follows `locale`, which
is English by default; field labels and choices come from the application.

## View

### `view`

```elm
view : (Msg -> msg) -> List (Attribute row msg) -> State -> Html msg
```

The bar: preset pills, the active filters as chips, the add button, a "Clear
all" button when there are filters, and the count. The editor opens in a popover
under the chip or the button. The first argument turns the bar's messages into
yours.

    FilterBar.view FiltersMsg [ FilterBar.fields orderFields ] model.filters

## State

### `State`

```elm
type State  -- opaque: no constructors are exposed
```

The state of one filter bar: the filters and the editor that is open, with
the draft the user is working on. Make one with `init`, keep it in your model and
pass it to `view` and `update`. Read the filters with `rule`.

### `Msg`

```elm
type Msg  -- opaque: no constructors are exposed
```

A message from the filter bar. Wrap it in one of your own messages and pass
it to `update`.

### `init`

```elm
init : String -> State
```

A filter bar without filters. The `String` is the DOM id of the bar and must
be unique on the page; the ids of the controls in its editor start with it.

    FilterBar.init "order-filters"

### `update`

```elm
update : Msg -> State -> ( State, Cmd Msg )
```

Applies a message from the filter bar. The command moves keyboard focus (into
the editor, back to a chip ...), so map it with `Cmd.map`. Compare `rule` before
and after to react to a change.

## The filters

### `rule`

```elm
rule : State -> Rule.Rule
```

The filters as a rule, for `Rule.matches`. The root is a group with the id 0
and one child for each chip. A rule made in the bar combines its chips with
"all of"; `setRule` can bring in a root that combines them in another way.
Compare it before and after `update` to find out whether the filters changed.

### `setRule`

```elm
setRule : Rule.Rule -> State -> State
```

Shows these filters, for example the rule of a saved view or a rule from the
rule builder. A rule that is a lone condition is put in a group, and the nodes
are renumbered from 0 if the root does not have the id 0 or an id occurs twice.
Closes the editor.

### `clear`

```elm
clear : State -> State
```

Removes every filter and closes the editor. Unlike the "Clear all" button it
does not offer to undo.

### `isOpen`

```elm
isOpen : State -> Bool
```

Is the filter editor open, for a new filter or for a chip?

### `close`

```elm
close : State -> ( State, Cmd Msg )
```

Closes the filter editor without applying what the user has entered, and
gives focus back to the chip or the add button it was opened from (as `Escape`
does). Map the command with the constructor you wrap the bar's messages in.

    FilterBar.close model.filters

## Attributes

### `Attribute`

```elm
type Attribute row msg  -- opaque: no constructors are exposed
```

A setting of the filter bar. Make them with the functions below and pass a
list to `view`; later attributes win over earlier ones. The type parameters are
the row type of your fields and your message type.

### `fields`

```elm
fields : List (Rule.Field row) -> Attribute row msg
```

What can be filtered on: the fields the user can pick in the editor, made
with `Rule.textField` and the other field functions. The default is no fields.

    FilterBar.fields
        [ Rule.choiceField "status" "Status" statuses .status
        , Rule.numberField "total" "Total" (.total >> Just)
        ]

### `quick`

```elm
quick : List ( String, Rule.Rule ) -> Attribute row msg
```

Ready-made filters, shown as toggle pills in front of the chips. Each one is
a name and a `Rule`.

    FilterBar.quick [ ( "Unpaid", unpaid ), ( "Large orders", large ) ]

A pill is on when the conditions of its rule are among the filters. Turning it
on adds them (the ones that are missing), turning it off removes them. A preset
that is an "all of" group adds each of its conditions as a chip of its own; any
other preset is added as one chip. The ids of a preset do not matter. A preset
that `Rule.validate` finds a problem in, for the fields of the bar, is drawn
disabled with the problem as its tooltip.

### `today`

```elm
today : Date.Date -> Attribute row msg
```

Today's date, for the date picker in the editor: it marks the day, powers its
"Today" button and completes short input. It does not change what the filters
match; give the same date to `Rule.matches`.

### `ariaLabel`

```elm
ariaLabel : String -> Attribute row msg
```

The name of the bar for screen readers. The default is "Filters".

### `addLabel`

```elm
addLabel : String -> Attribute row msg
```

The text of the add button. The default is "Add filter".

### `locale`

```elm
locale : Locale.Locale -> Attribute row msg
```

The language of the bar's own text: buttons, hints and the words that say how
the chips are combined. The default is `Locale.default`, which is `Locale.en`. Field
labels and choices come from the application.

## Match count

### `matchCount`

```elm
matchCount : Remote.Remote Int -> Attribute row msg
```

How many rows the filters let through, shown at the end of the bar as
"1,482 matches". Give `Remote.Loaded n` for a count you have (`Rule.matches`), or
the `Remote` of a count that takes time:

  - `Loading`: a spinner and "Counting ...".
  - `Failed`: "The count failed", with a retry button when there is `onRetry`.
  - Refreshing (`Remote.refresh` of a count): the old count stays, dimmed, with
    a spinner.
  - Old (`Remote.Kept` after a failed refresh): the old count, marked old, with
    the retry; while that retry runs the button stays, busy, and keeps focus.

`NotAsked`, the default, shows no count. The count is in a polite live region,
which is in the page from the start, so a screen reader hears the first count too.

    FilterBar.matchCount (Remote.Loaded (List.length visible))

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
