# Klar.RecurrencePicker

A form field that builds a repeating Klar.Recurrence rule.

Import: `import Klar.RecurrencePicker as RecurrencePicker` | Group: Date and time

Types: `Msg`, `State`, `Problem`, `Attribute`

## Signatures

```elm
-- View
view : (Msg -> msg) -> List (Attribute msg) -> State -> Html msg

-- State
type State  -- opaque: no constructors are exposed
type Msg  -- opaque: no constructors are exposed
init : String -> Date.Date -> State
update : Msg -> State -> ( State, Cmd Msg )

-- The rule
type Problem  -- opaque: no constructors are exposed
value : State -> Maybe Recurrence.Rule
setValue : Maybe Recurrence.Rule -> State -> State
isValid : State -> Bool
problem : State -> Maybe Problem
problemText : Locale.Locale -> Problem -> String

-- The start date
start : State -> Date.Date
setStart : Date.Date -> State -> State

-- Attributes
type Attribute msg  -- opaque: no constructors are exposed
label : String -> Attribute msg
labelHidden : Attribute msg
hint : String -> Attribute msg
error : String -> Attribute msg
errorMaybe : Maybe String -> Attribute msg
required : Attribute msg
optionalText : String -> Attribute msg

-- Look and behavior
today : Date.Date -> Attribute msg
size : Theme.Size -> Attribute msg
locale : Locale.Locale -> Attribute msg
disabled : Bool -> Attribute msg
readOnly : Bool -> Attribute msg
```

## Documentation

A form field that builds a repeating [Klar.Recurrence](Klar.Recurrence.md) rule:
how often (daily, weekly, monthly, yearly), every how many, on which days, how
it ends, with a sentence that says what the rule means and the next dates it
gives.

Use when: a person sets up something that repeats: a standing order, a delivery schedule, a recurring invoice.
Do not use when: you need a single date (as `Klar.DatePicker`) or the dates of a rule without a form (as `Klar.Recurrence`).
Quick path: `init`, `update`, `view`, `value`

See also [Klar.DatePicker](Klar.DatePicker.md) and [Klar.Recurrence](Klar.Recurrence.md).

    import Klar.Date exposing (Date)
    import Klar.Recurrence exposing (Rule)
    import Klar.RecurrencePicker as RecurrencePicker

    -- model: the picker needs the date the series starts on
    { repeat : RecurrencePicker.State }   -- RecurrencePicker.init "standing-order-repeat" firstDelivery

    -- msg
    RepeatMsg RecurrencePicker.Msg

    -- update
    RepeatMsg m ->
        let
            ( repeat, cmd ) =
                RecurrencePicker.update m model.repeat
        in
        ( { model | repeat = repeat }, Cmd.map RepeatMsg cmd )

    -- the delivery date was changed somewhere else
    DeliveryDateChanged date ->
        ( { model | repeat = RecurrencePicker.setStart date model.repeat }, Cmd.none )

    -- view
    RecurrencePicker.view RepeatMsg
        [ RecurrencePicker.label "Repeat"
        , RecurrencePicker.today model.today
        ]
        model.repeat

    -- read
    RecurrencePicker.value model.repeat     -- Maybe Rule
    RecurrencePicker.isValid model.repeat   -- False while the form is half filled in

The value is a `Maybe Rule`. `Nothing` means the date does not repeat, and also
that the form is not complete yet (the number of weeks is empty, "after" has no
number); `isValid` tells these apart (`problem` says why), and the field shows
the reason under itself. Save only when `isValid` is `True`. The state holds the
value and there are no out-messages: compare `value` before and after `update`
to react to a change.

The application gives the start date. The options for a monthly rule follow it
("On day 20", "On the third Tuesday", "On the last Tuesday" when the start is
the last one, and "On the last day of the month" when the start is the last day
of a month shorter than 31 days), and so does the weekday that is ticked first. Call `setStart`
when the date changes. A rule loaded from a server is put in with `setValue`.

**The form.** "Repeat" chooses between no repetition, daily, weekly, monthly and
yearly. The others show what that needs: "Every [2] weeks", the seven weekdays,
the choice of the day of the month, and how the rule ends: never, after a
number of times, or on a date (a [Klar.DatePicker](Klar.DatePicker.md)). The last
ticked weekday cannot be turned off, since a weekly rule needs a day; the field
says so in a message that screen readers announce politely. For "the 31st" of a
month, and 29 February, it asks what happens when there is no such day: use the
last day (the default) or skip the month. Below the fields a sentence says what
the rule means, in the language of the field, and the next five dates follow; both
are made by [Klar.Recurrence](Klar.Recurrence.md).

**The end.** An end date before the start date is a problem (`EndBeforeStart`):
the field has no `value` until it is changed, and says so under the fields. The
number of times and the interval are whole numbers from 1 to 2 147 483 647, the
same limits as in [Klar.Recurrence](Klar.Recurrence.md), so every rule that module
accepts can be shown.

**Skipped dates.** A rule can skip dates (`Recurrence.except`). The field does
not add any, but it shows the ones a loaded rule has, each as a tag with a button
that removes it, and a "Remove all" button; the keyboard focus moves to the next
date, or back to the field. A skipped date that no longer fits the rule (a
Tuesday in a rule that now repeats on Thursdays) stays in the list until it is
removed: nothing is dropped behind the user's back.

Everything is built from the components of this package, so the keyboard works
as it does there: the arrow keys in the choice of frequency, the weekdays as
check boxes, the spinbutton for the interval, the calendar of the date field. The
whole field is one `fieldset` with the label as its legend, and the fields that
come and go keep their place, so the keyboard focus stays where it is when the
frequency changes. The sentence is the one `aria-live="polite"` region, so a screen
reader hears the new meaning after each change, and the list of dates is not
announced. The only other message that can be announced is the status line about
the weekday that cannot be turned off (`role="status"`), which is empty until the
user tries.

With `readOnly` the field shows its label and the sentence and nothing else. The
built-in text follows `locale` (English by default).

**What this is not.** A rule is a set of calendar dates. A time of day and a time
zone are not part of it; your application adds them to each date.

## View

### `view`

```elm
view : (Msg -> msg) -> List (Attribute msg) -> State -> Html msg
```

The field. The first argument wraps the messages of the field in one of
yours.

    RecurrencePicker.view RepeatMsg
        [ RecurrencePicker.label "Repeat"
        , RecurrencePicker.today model.today
        ]
        model.repeat

## State

### `State`

```elm
type State  -- opaque: no constructors are exposed
```

Everything the field keeps: the chosen frequency, the numbers and the dates
in its inputs, the days that are ticked, and the start date. Make it with
`init`, keep it in your model, and read the rule with `value`.

### `Msg`

```elm
type Msg  -- opaque: no constructors are exposed
```

The messages of the field. Wrap them in one constructor of your own `Msg`,
give that constructor to `view`, and pass what comes back to `update`.

### `init`

```elm
init : String -> Date.Date -> State
```

A field that does not repeat. The `String` is the DOM id of the first control
(the choice of frequency) and must be unique on the page; the other parts get
ids made from it (`<id>-interval`, `<id>-weekdays`, `<id>-by`, `<id>-end`,
`<id>-count`, `<id>-until`, `<id>-summary` ...). The date is the start of the
series, which the options for a monthly rule follow.

    RecurrencePicker.init "standing-order-repeat" firstDelivery

### `update`

```elm
update : Msg -> State -> ( State, Cmd Msg )
```

Handles a message of the field. Returns the new state and the command that
moves the keyboard focus (after a stepper button of a number field, for
example). Map the command with the constructor of your own `Msg`.

    RepeatMsg m ->
        let
            ( repeat, cmd ) =
                RecurrencePicker.update m model.repeat
        in
        ( { model | repeat = repeat }, Cmd.map RepeatMsg cmd )

## The rule

### `Problem`

```elm
type Problem  -- opaque: no constructors are exposed
```

What is missing from the field. It is opaque, so that more can be added;
`problemText` says it in a sentence.

### `value`

```elm
value : State -> Maybe Recurrence.Rule
```

The rule the field holds. `Nothing` means that the date does not repeat, and
also that the form is not complete yet, so check `isValid` before you save:
`value` alone cannot tell "does not repeat" from "half filled in". The rule is
counted from the start date of the field.

    if RecurrencePicker.isValid model.repeat then
        save (RecurrencePicker.value model.repeat)

    else
        -- the field already shows why under itself
        ( model, Cmd.none )

### `setValue`

```elm
setValue : Maybe Recurrence.Rule -> State -> State
```

Shows a rule in the field, or "Does not repeat" for `Nothing`: for a rule
loaded from a server. Everything the rule says is put in the inputs (the
interval, the days, the end), and the dates it skips are kept. A text the user was
typing is dropped.

The field shows the rule as it is and never changes it. The day of a monthly or
yearly rule is kept as the rule has it, also when it is the day of the start date:
the choice is listed (once, with the choices that follow the start date) and
`setStart` does not move it. A rule that is loaded with an end date before the
start date has no `value` and the problem `EndBeforeStart` until one of them is
changed.

    RecurrencePicker.setValue (Just rule) model.repeat

### `isValid`

```elm
isValid : State -> Bool
```

Whether `value` is what the user means: `True` when the field does not
repeat or holds a complete rule, `False` while a number is missing or cannot be
used, the end date is not chosen, or the end date is before the start date (see
`problem`).

### `problem`

```elm
problem : State -> Maybe Problem
```

Why the field is not valid: a number that is missing or cannot be used, an
end date that is not chosen, or an end date that is before the start date.
`Nothing` when the field is complete, and when it does not repeat at all. The
field itself shows the message under its fields, and `problemText` gives it in
words (for a summary of the form's problems).

### `problemText`

```elm
problemText : Locale.Locale -> Problem -> String
```

The problem in a sentence, in the language of the locale.

    RecurrencePicker.problem model.repeat
        |> Maybe.map (RecurrencePicker.problemText Locale.en)

## The start date

### `start`

```elm
start : State -> Date.Date
```

The date the series starts on, as given to `init` or `setStart`.

### `setStart`

```elm
setStart : Date.Date -> State -> State
```

Moves the start date. The choices for a monthly or yearly rule follow it, and
so does the weekday of a weekly rule while nobody has chosen weekdays. A choice
the user made stays, and so does a rule that was put in with `setValue`.

## Attributes

### `Attribute`

```elm
type Attribute msg  -- opaque: no constructors are exposed
```

A setting of the field. Make them with the functions below and pass a list to
`view`; later attributes win over earlier ones.

### `label`

```elm
label : String -> Attribute msg
```

The legend of the field: its name, above the choices. Without it the legend
is the built-in "Repeat", kept for screen readers only.

### `labelHidden`

```elm
labelHidden : Attribute msg
```

Keeps the label for screen readers but does not show it, for a field whose
purpose is clear from what surrounds it. Needs `label`.

### `hint`

```elm
hint : String -> Attribute msg
```

A line of help under the field. It describes the whole group
(`aria-describedby`), so screen readers read it when the focus enters.

### `error`

```elm
error : String -> Attribute msg
```

An error message of your application, shown under the field and announced to
screen readers (`role="alert"`). While the field has a problem of its own (see
`problem`) that message is shown instead.

### `errorMaybe`

```elm
errorMaybe : Maybe String -> Attribute msg
```

Like `error`, but takes a `Maybe`: `Nothing` means no error.

### `required`

```elm
required : Attribute msg
```

Puts a `*` after the label. It only marks the field and checks nothing: "Does
not repeat" is a valid answer.

### `optionalText`

```elm
optionalText : String -> Attribute msg
```

Text shown after the label of a field that is not `required`, such as
"(optional)". Default: none.

## Look and behavior

### `today`

```elm
today : Date.Date -> Attribute msg
```

Today, from the application (the library never reads the clock). The date
field of "ends on" marks it, and the next dates start from today when it is
later than the start date. Without it the list shows the first dates of the
series.

### `size`

```elm
size : Theme.Size -> Attribute msg
```

The size of the controls: `Small`, `Medium` or `Large` (see
[Klar.Theme](Klar.Theme.md)). Default: `Medium`.

### `locale`

```elm
locale : Locale.Locale -> Attribute msg
```

The language of the built-in text, of the sentence and of the dates (see
[Klar.Locale](Klar.Locale.md)). Default: `Locale.default`, which is English.

### `disabled`

```elm
disabled : Bool -> Attribute msg
```

Disables every control. Takes a `Bool` so that it can come from your model,
for example while a form is saved. Default: `False`.

### `readOnly`

```elm
readOnly : Bool -> Attribute msg
```

Shows the label and the sentence only ("Every 2 weeks on Monday and
Thursday"), with no controls and no list of dates, for a page that displays a
saved rule. Default: `False`.
