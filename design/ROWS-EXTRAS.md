# Rows that hold an application-owned editor

*Status: built (design 1: `Spec.conditions`, `Form.ruleBuilder`, `Form.problemInRow`). A decision
record; the current API is in `ai/modules/Klar.Form.md` and `Klar.Form.Spec.md`.*

The question (R3O-013, R3O-003, R3O-018 of `apps/round3/onboarding/FRICTION.md`): a price
rule is a rule builder (the conditions) and a number (the discount), and a supplier has a
list of them. `Spec.rows` could not hold the rule builder, so the onboarding app wrote the
list a second time (336 lines in `PriceRules.elm`): add and remove, a dirty flag, its own
problems (`Form.outside`), the server's refusals, the focus. Two designs were weighed.

## Design 1: a closed kind per editor (built)

`Spec.conditions label ruleFields : Spec Rule (Maybe Rule)`. The field keeps a
`RuleBuilder.State` in a slot of its own (`SRule`) and the `Rule` in the baseline (`RRule`),
exactly as `files` keeps a `FileDrop.State` and a list of `FileInfo`. A row of a group is a
sub-form, so a price rule is

```elm
priceRule =
    Spec.define "price-rule" PriceRuleFields PriceRule
        |> Spec.with (Spec.conditions "Conditions" ruleFields |> Spec.required)
        |> Spec.with (Spec.number "Discount" |> Spec.required |> Spec.range 1 100)
        |> Spec.build
```

and the list is `Spec.rows { label = "Price rules", item = "Price rule" } priceRule`.
Everything the rows already have then applies to the builder without a line of glue: the
stable row numbers (the state of a builder follows its row when another row is removed),
add and remove with the focus after them, `isDirty`/`markClean`/`revert`, `fillRows`,
`toValues`, the summary and the stepper marks, `Form.problemInRow` for the server. The outcome
of a rule (R3O-003) is the other field of the same row, typed.

Cost: `Klar.Form.Core` imports `Klar.RuleBuilder` and `Klar.Rule`; every new kind of editor
is a change in the library (one new slot, one raw value, one view function). That is the
point: it is a closed set, checked by the compiler, and `State` stays data without a function
in it.

Two details found on the way. (a) The problem of a rule is about a node deep inside the
builder, and the container is not a control, so a problem now has a **target** (the DOM id the
focus goes to) besides its **key** (the field it belongs to). The key finds the label, the
step and the "shown" flag; the target is what `Problem.field` and the summary line carry
(`RuleBuilder.focusId` gives it, nothing is read from the page). A line of the summary
carries its step with it (`FocusField step id`), so it no longer has to find the field by
its id. (b) A builder is never "left": half a condition is how a rule is made. Editing does
not touch the field, so its problems show once the step is tried (`advance`, `reveal`,
`rejected`), the same rule as for problems given to `outside`; that is also when the builder
is told to show its own per-node issues.

## Design 2: a generic slot for any application value (not built)

`Spec.rows` with an `extra : e` per row, kept by the model. The state would have to hold a
value of a type the library does not know. In Elm that means either an existential type (not
possible), a function in `State` (a codec or an equality: the state could no longer be
compared, stored or tested, and every `Msg`/`State` guarantee of the model goes), or a
`Json.Value` with an encoder and decoder given in the declaration (the `custom` field that
section 9.3 of `FORM-MODEL.md` ruled out: it needs a second consumer before its shape is
frozen, and the baseline becomes encoded text). The cheaper form of it, "a key per row so my
own list can follow", leaves dirty, problems, removal and server errors with the application
again, which is the round 3 situation.

## Decision

Design 1, for the rule builder only. Another editor that wants to live in a row (a
`Money`, a date range) is already a kind or can be one; the day a third application-owned
editor appears is the day to look at design 2 again, with three consumers to shape the codec.

What stays outside the model: an editor that is not a field at all (a free-standing list on a
page that is not a form). For that, the rule builder alone is documented as a step-level
component: keep its `State` next to the form, give its problems to `Form.outside` with
`RuleBuilder.focusId` as the target, and focus it with `RuleBuilder.focusIssue`.
