# Form model

Design for ROADMAP A8 "Form model" (EVALUATION item 10). Status: **built.** The core was
built on the branch `form-model` and judged by the second A0 round; the seam that round found
(steps, rows, tags, files, problems the application can see, focus, one `Ids`) was closed on
the branch `t-form`, and the modules were renamed and split. Section 10 at the end records
what is built now, the decisions taken, the numbers and the proof; sections 1 to 9 are the
design and the prototype as they were written, with their names (`Fm` is `Klar.Form.Model`
there, which is now `Klar.Form`, with the declaration in `Klar.Form.Spec`).

Method: the onboarding app (`apps/onboarding/src`) is the test. Line counts are physical
lines of the file ranges named; the counts of the proposal are non-blank lines of the
sketches in section 7. One piece was checked with the compiler (in a scratch directory, not
in the repository): the typing of the builder pipeline (section 2). The rest of sections 1
to 8 is a design, not a build.

## 1. The problem in numbers

`apps/onboarding` has a five-step flow. The values of one form live in ten places: eight
Klar component states (`Select`, `MultiSelect` x2, `TagInput`, `FileDrop`, `NumberInput` x2,
`Select`), plain strings, and lists the application edits itself. Everything that ties them
together was written by hand. The friction log marks 270 lines `KLAR GAP`; that undercounts,
because most of the plumbing is not marked. From `Flow.elm` (1951 lines) and `Ids.elm`
(180 lines):

| What the application wrote | Lines | Where | Friction |
|---|---|---|---|
| `Draft`, `emptyDraft`, `toDraft`, `withBaseline`, `isDirty` (dirty = values differ from a baseline) | 67 | 100-120, 242-264, 301-324 | O-018 |
| `load` (a record into ten states, ten different setters) | 32 | 267-298 | O-018 |
| `toSupplier` (ten states into the record, `Maybe` if invalid) | 28 | 341-368 | O-018 |
| client validation per step, `requiredValue`, `nonEmptyList`, `numberProblems`, `fromErrors` | 160 | 372-530 | O-001 |
| server problems: field-to-handle mapping, merge with client problems, drop on edit | 73 | 534-606 (plus `edited` called in 8 update branches) | O-019 |
| step control: `step`, `furthest`, `attempted`, `reviewAttempted`, `firstFieldOf`, `markAttempted`, `GoStep`/`Back`/`Submit`/`FocusField`, the stepper list | about 100 | 608-624, 948-997, 1155-1161, 1229-1246 | O-003, O-022 |
| one `Msg` constructor, one `update` branch and one `case` per control | about 150 | 646-686, 715-839 | O-018 |
| DOM ids (`Ids.elm`: 40 ids, 10 of them functions of a row) and the `Form.labels` list that repeats them with a label | 180 + 28 | `Ids.elm`, 1274-1301 | O-021 |
| **Form plumbing in total** | **about 820** | of about 3 100 application lines (26 %) | |

Not form model, but measured with it: the leave guard (45 lines in `Main`, O-017) and the rule
keys (30 lines, O-002, fixed by the "typed ids" item of A8).

**What every application will repeat** (so Klar should own it): a baseline and a dirty test;
load a record and read one back; "is this required field empty" for every control kind;
problems from the server tied to a field, merged with client problems and cleared when the
field is edited; which step a field is on, validation before Next, "go to the field on
another step"; the stepper status; ids and labels written twice. **What stays the
application's**: the record type, the rules about its own data, the mapping from its backend's
field names to its fields, the navigation, the words.

Nobody got a type wrong (0 wrong-type errors in 3 builds), so this is not a type-safety
failure of today's API. It is the glue between existing components, and principle 4
("complexity inside, business logic outside") and the admission question "does it avoid glue
code that every application would repeat?" say it belongs in Klar.

## 2. The design

### 2.1 The idea in one paragraph

A form is **declared once**, as a constant: its fields in order, each with a label and its
rules, grouped in steps. The declaration gives the application three things: a record of
**field handles** (to put in the view, to read, to tie a server problem to), the **record the
form produces** when valid, and the **schema** Klar needs to validate and to update. The
application keeps one `Fm.State` in its model and one `FormMsg Fm.Msg` in its `Msg`. The state
holds every value, the baseline, what was touched, the step, the server problems and the
submit status. It holds the existing component states (`Select.State` and the rest)
internally. It contains no function, and neither does `Fm.Msg`.

(`Fm` is `import Klar.Form.Model as Fm`. The layout module `Klar.Form` stays as it is:
`view`, `section`, `grid`, `actions`, `status`, `errorSummary`, `unsavedFlag`. One new exposed
module, so `Klar.Form` does not grow past what one doc page can say.)

### 2.2 Types

```elm
module Klar.Form.Model exposing (..)   -- exposed names listed in 2.6

type Form step fields values          -- the declaration; a constant, never in Model or Msg
type State step                       -- opaque, data only; derive nothing from it by hand
type Msg                              -- opaque, data only (Dict key, component Msg, ...)
type Field control                    -- a handle; `control` is the type of the control's value
type Ids id                           -- how the application's id type is written as text, once
type Problem                          -- a message tied to a field (client or server)
type View msg                         -- a form, a state and a `toMsg`, bound once per view

ids : { toKey : id -> String, fromKey : String -> Maybe id } -> Ids id      -- same shape as Table.rowIds
```

`Field control` is what `Fields` is made of. The control type says what the value looks like
*while editing* (empty is a legal value): text is `String`, a select is `Maybe id`, a
multi select `List id`, a number `Maybe Float`, tags `List String`, files `List FileInfo`, a
switch `Bool`, a date `Maybe Date`. What the form *produces* is a second type, the output of
the rules: a required select produces `id`, not `Maybe id`.

### 2.3 Declaring fields (the builder pipeline)

```elm
type Spec control output              -- one field's kind, label and rules; built by the functions below
type Builder step fields values       -- the pipeline while it is being built

define : String -> fields -> values -> Builder step fields values
          -- the String is the form's DOM id prefix; fields and values are record constructors
with   : Spec control output -> Builder step (Field control -> f) (output -> v) -> Builder step f v
step   : step -> String -> Builder step f v -> Builder step f v   -- the fields that follow are on this step
build  : Builder step fields values -> Form step fields values
fields : Form step fields values -> fields                         -- the handles, a constant

-- kinds (one per control; a label is always required)
text    : String -> Spec String (Maybe String)           -- blank is Nothing; the output is trimmed, the display is not
number  : String -> Spec (Maybe Float) (Maybe Float)
choice  : Ids id -> String -> Spec (Maybe id) (Maybe id)  -- Select, or Radio at view time
choices : Ids id -> String -> Spec (List id) (List id)    -- MultiSelect
tags    : String -> Spec (List String) (List String)
files   : String -> Spec (List FileInfo) (List FileInfo)
toggle  : String -> Spec Bool Bool
day     : String -> Spec (Maybe Date) (Maybe Date)
-- NOT in the first version: custom (application-owned editor with a Value codec) and rows (2.7)

-- rules; each returns the same kind of spec, a few change the output type
required : Spec c (Maybe a) -> Spec c a              -- also draws the "*"; removes Maybe from the output
atLeast  : Int -> Spec c (List a) -> Spec c (List a)  -- required, and the message says how many
one      : Spec c (List a) -> Spec c (Maybe a)        -- at most one (a single file)
rules    : List Validate.Validator -> Spec String o -> Spec String o   -- the existing validators, unchanged
range    : Float -> Float -> Spec (Maybe Float) o -> Spec (Maybe Float) o
whole    : Spec (Maybe Float) o -> Spec (Maybe Float) o               -- no decimals, shown and checked
hint     : String -> Spec c o -> Spec c o
withMessage : (Locale -> String) -> Spec c o -> Spec c o   -- replaces the message of the rule just added
```

How a mistake becomes a compile error (principle 5):

| Mistake | Why it does not compile |
|---|---|
| A field is declared but not in `Fields` (or the reverse) | `with` consumes one constructor argument of `Fields` *and* one of `Values` per call. `build` of a half-applied pipeline has type `Form step (Field c -> Fields) ...`, not `Form step Fields Values`; the annotation on the declaration fails |
| A field is read before it exists | the only way to get a handle is `fields form`, which is the record of all of them |
| Two fields clash on a DOM id | the application never writes one. Ids are `<form id>-<slug of label>`, numbered `-2`, `-3` for a repeated label, in declaration order. Two forms with the same prefix are the one remaining way, and `define` takes the prefix as its first argument, like `Form.id` today |
| A required choice is used as optional | `required` changes the output type: `Values.country : CountryId` cannot be given `Maybe CountryId` |
| A select view is given a text handle | `select : View msg -> Field (Maybe id) -> ...` takes only a `Maybe id` control; checked in the scratch sketch. Gap: `text` and `choice` over `String` ids are different types (`String` against `Maybe String`), but a `choice` over `Float` ids and a `number` are both `Maybe Float`. Rare; a runtime check draws a visible "this field is declared as another kind" instead of garbage |
| A select has no options | the options are a positional argument of `select` and `multiSelect`, not an attribute |
| An id type is unusable as a key | `ids` needs both `toKey` and `fromKey`; `Table.rowIds` already asks for the same two functions |
| Two states that exclude each other | a step is the application's own custom type (`Company | Contacts | ...`); the status is the existing `Form.Status`; `choice` is "one or none", never a `Maybe` next to a flag |

What the compiler does **not** check, said plainly: that `Fields` and `Values` list their
fields in the same order as the pipeline (both are filled by position, like a decoder
pipeline; swapping two `Maybe String` slots in only one of the two records is a bug no type
sees), and that `fill` (loading, 2.4) sets every field. The mitigation is one property the
application tests in one line (`fill s |> toValues |> Result.map toSupplier == Ok s`) and the
fact that `Fields` and `Values` are declared next to each other. Section 8 lists this as a risk.

### 2.4 Load, read, dirty

```elm
init       : Form step f v -> State step                        -- every field empty, first step, clean
set        : Field c -> c -> State step -> State step           -- the one setter, for every kind
get        : Field c -> State step -> c                         -- the value as edited (Maybe, List, ...)
toValues   : Form step f v -> State step -> Result (List Problem) v   -- all rules, all steps; the record or the problems
isDirty    : State step -> Bool                                  -- values differ from the baseline
markClean  : State step -> State step                            -- baseline := now (after load, after a successful save)
revert     : Form step f v -> State step -> State step           -- values := baseline
```

* **Going in.** `fill : Supplier -> State Step -> State Step` is a pipe of `Fm.set fields.x s.x`,
  one line per field. `Fm.init form |> fill supplier |> Fm.markClean` is "load a record".
  `set` is one function for all kinds because `Field c` carries the control type (a select
  takes `Maybe CountryId`, a switch `Bool`): a wrong value is a type error. For a select, `set`
  also needs the option's label; as today (`Select.setValue`), the field shows "Loading ..." until
  the options arrive and then the label, and `Fm.get` returns the id at once.
* **Coming out.** `toValues` returns `Err problems` or `Ok values`: an invalid form cannot
  produce a record, and the problems are the same list the summary shows. `values` is the form's
  own flat record (`Values`); the application maps it to its domain record in a function it
  owns (`toSupplier : Values -> Supplier`, with the version and the id that the form never
  touches). `Maybe` would hide which field is wrong; the cost of `Result` is none, since
  `Result.toMaybe` exists.
* **Dirty** is not "an input event happened". It is `snapshot state /= baseline`, where a
  snapshot holds only values (a `Select`'s open list and search text are not part of it), so
  typing a letter and deleting it is clean again, which is what the existing `unsavedFlag`
  promises. The text a user typed is compared as typed; trimming happens only in the output
  (principle 2: nothing is changed behind the user's back).

### 2.5 What is inside `State`

```elm
type State step =
    State
        { slots : Dict String Slot        -- key = the field's DOM id; one slot per field
        , baseline : Dict String Snapshot
        , touched : Set String            -- left once, or edited
        , server : Dict String String     -- problems from the server, by field
        , step : Int, furthest : Int, attempted : Set Int, reviewed : Bool
        , status : Form.Status
        }

type Slot                                   -- private
    = SText String
    | SSelect (Select.State String)         -- ids are the keys given by `Ids`
    | SMulti (MultiSelect.State String)
    | STags TagInput.State
    | SNumber NumberInput.State
    | SFiles FileDrop.State
    | SDate DatePicker.State
    | SToggle Bool
    -- later (amendment 3): SJson for `custom`, SRows for `rows`
```

The **existing component states stay as they are** and the form holds them (answer to
question 6). Because several kinds of component state are stored in one dictionary, an id type
cannot appear in the type of the slot: the form stores `Select.State String` with the key from
`Ids`. `Fm.Msg` is then one closed union of the component messages at `String`
(`Selected Key (Select.Msg String)`, `Typed Key String`, ...). It is data, opaque, and can grow.
The application never sees a key: it sees `CountryId`.

Consequences: `Select.Option id` must be mapped to `Select.Option String` inside `select`; this
needs one small addition to `Select` (`mapOption`), listed in step 1 of the plan. The behaviour
that components have worked out ("keys right after a list opens", focus return) lives in the
component `update`; the form calls it and forwards the `Cmd`, so it is kept.

### 2.6 The view

```elm
bind : (Msg -> msg) -> Form step f v -> State step -> View msg   -- once per view; carries the state and the toMsg

text        : View msg -> Field String -> List (TextInput.Attribute msg) -> Html msg
textArea    : View msg -> Field String -> List (TextArea.Attribute msg) -> Html msg
number      : View msg -> Field (Maybe Float) -> List (NumberInput.Attribute msg) -> Html msg
select      : View msg -> Field (Maybe id) -> Remote (List (Select.Option id)) -> List (Select.Attribute id msg) -> Html msg
radio       : View msg -> Field (Maybe id) -> List (Select.Option id) -> List (Radio.Attribute msg) -> Html msg   -- the same field as select, other control
multiSelect : View msg -> Field (List id) -> Remote (List (Select.Option id)) -> List (MultiSelect.Attribute id msg) -> Html msg
tags        : View msg -> Field (List String) -> List (TagInput.Attribute msg) -> Html msg
files       : View msg -> Field (List FileInfo) -> List (FileDrop.Attribute msg) -> Html msg
toggle      : View msg -> Field Bool -> List (Switch.Attribute msg) -> Html msg
day         : View msg -> Field (Maybe Date) -> List DatePicker.Attribute -> Html msg
```

Each view sets `id`, `label`, `required`, `value`, `errorMaybe` and the message **after** the
application's attributes, so they win: the application cannot give a control a second id.
The attributes that remain are the ones the declaration does not know (a placeholder, a
suffix text, `TextInput.url`, `FileDrop.accept`, `Select.onRetry`). The existing attribute
types are reused, so there is no second vocabulary to learn (principle 10).

**Naming (found while building).** The first draft gave the kinds and the views the same
names (`text`, `number`, `toggle`), which cannot both be exposed from one module. A view is
named after the component it draws and a kind after the value it declares: kinds `text
number choice choices toggle`, views `textInput numberInput select multiSelect switch`. The
sketches in this document that say `Fm.text v fields.name` mean `Fm.textInput v fields.name`.

Exposed names: see section 9.5 for the count of the first version and the proposal to split
it. The full design (steps, rows, custom, tags, files, day) was estimated at about 55 names.
No new exposed union.

### 2.7 Repeating groups and application-owned values (NOT in the first version)

The onboarding contacts step is a list of rows with five fields each, and the price rules are
edited in a dialog that returns one finished rule. Both are common. **Amendment 3 of the
owner: neither `rows` nor `custom` is built in this round.** They are the hard part, they
freeze names in a published API, and the core must first be proved by a real second round of
A0. What must be true before they are added is in section 9.3. The sketch below stays as the
direction, not as a promise:

```elm
rows   : String -> Form () rf rv -> Spec (Rows rf) (List rv)     -- a sub-declaration per row
row    : Int -> Field (Rows rf) -> State step -> rf              -- the handles of row i (ids: contacts-2-email)
addRow, removeRow : Field (Rows rf) -> State step -> State step
check  : (fields -> values -> List Problem) -> Form step f v -> Form step f v   -- across fields and rows
```

"Exactly one contact is the primary" is a `check` that returns a `Problem` on a row's handle.
A `custom` field keeps the application's value (`List PriceRule`) as encoded text for the
baseline, and the dialog commits with `Fm.set fields.priceRules rules`. It needs a codec; the
only one missing for the onboarding app is none (`Rule.encode` and `Rule.decoder` exist).

## 3. Server problems tied to fields (O-019)

The application hands back one value after a failed save:

```elm
problem  : Field c -> String -> Problem                             -- a handle and a message
rejected : List Problem -> Form step f v -> State step -> ( State step, Cmd Msg )
```

`problem` takes a handle of any kind, so the type of the *application's* backend field
(`Backend.Name`, `Backend.ContactEmail 2`) is mapped once to a handle:

```elm
fromBackend : Backend.Problem -> Fm.Problem
fromBackend p =
    case p.field of
        Backend.Name -> Fm.problem fields.name p.message
        Backend.CountryField -> Fm.problem fields.country p.message
        Backend.ContactEmail i -> Fm.problem (Fm.row i fields.contacts).email p.message
```

`rejected` stores them by field key and does what `Flow.SaveArrived` does by hand today: marks
the form as reviewed, moves to the review step (or, in a form without one, the step of the first
problem), and focuses the summary. Rules for showing a problem:

* A field shows **one** message, chosen in this order: its client problem, then its server
  problem. A server problem never hides a client problem, and a field that is fine on the
  client but rejected by the server shows the server's words (today's `visibleProblems`).
* Problems appear **next to the field** (the control's own error) and **in the summary**
  (`Fm.summary`), with the label from the declaration, so `Form.labels` is not needed. A
  contact row's label is "Contact 2 email" from the row's index.
* A server problem is **cleared when its field is edited**: the form's `update` drops
  `server[key]` on any change of that field (also a change that restores the old value; the
  server said no to a value the user has since touched). It is the only place that ever needed
  `edited` and its eight call sites.
* A whole-request failure (`Remote.Problem`: network, conflict) is not a field problem. It is
  the existing `Form.Status` (`Fm.setStatus (Form.Failed problem)`), shown by `Form.status` with
  its retry. `Remote.Problem` stays opaque and request-level; the field problems are a different
  type because they have a different owner (principle 9: Klar does not know the backend).
* A conflict (a version changed by another person) stays in the application: it needs the
  other record. The model helps with one function (step 4): `differingSteps : Form step f v ->
  State step -> State step -> List step` compares two states by step, so the dialog's list of
  "sections that differ" (`sectionsDiffering`, 25 lines) becomes
  `differingSteps form mine (fill theirs (init form))`.

## 4. Steps (O-003, O-022)

```elm
step   : step -> String -> Builder ... -> Builder ...             -- declaration (2.3)
review : step -> String -> Builder ... -> Builder ...             -- a last step with no fields of its own

currentStep : Form step f v -> State step -> step
advance : Form step f v -> State step -> { state : State step, cmd : Cmd Msg, submit : Maybe v }
back    : Form step f v -> State step -> ( State step, Cmd Msg )
goTo    : Form step f v -> step -> State step -> ( State step, Cmd Msg )
stepper : View msg -> List (Stepper.Attribute msg) -> Html msg
summary : View msg -> Html msg
```

* **Which fields are on which step** is the position of `step Company "Company"` in the
  declaration. The step type is the application's own custom type, so `case step of` in the
  application is checked by the compiler, and the name given to `step` is the label of the
  stepper.
* **Validation before Next.** `advance` is the whole `Submit` branch of today's `update`: on a
  non-last step it validates the fields of the current step only, and if there are problems it
  marks the step attempted, shows them and focuses the summary; if not it moves on and focuses
  the first field of the next step (the step's first field is known from the declaration, so
  `firstFieldOf` goes). On the last step it validates all steps; if valid it returns `submit =
  Just values` (the application starts its request and calls `setStatus Submitting`), otherwise
  it marks the form reviewed so all problems show. The result is a record, not an exposed union,
  so nothing here can break by growing.
* **The review step.** `summary` lists every *visible* problem of every step with its label and
  a button; the button's message is `Fm.Msg` and `update` handles it: set the step of the field
  (`Fm.goTo` semantics), then focus the field in the same update (checked to work without a
  delay in the onboarding run). The review page itself (the descriptions of the values) is the
  application's view; it reads `Fm.get fields.country state` and a step-level
  `Fm.stepHasProblems : Form -> State -> step -> Bool` to colour its cards.
* **Visible problems.** A field shows its problem when it was left once (blur) or edited, when
  its step has been attempted, or when the form was reviewed. Before that a required field is
  quiet. This is the rule the application writes by hand today with `attempted` and
  `reviewAttempted`.
* **Stepper status.** `stepper` renders `Stepper.view` with, per step: *disabled* if it is
  after the furthest step reached, *failed* if it has visible problems, *done* if it was
  attempted and has none, otherwise upcoming or current. `failed` and `disabledStep` exist;
  *done* needs `Stepper.done : Step -> Step` (step 1 of the plan; additive). "Visited" is
  "not disabled": the stepper does not need a fourth look.
* `goTo` to a step beyond the furthest is refused (the stepper's click), except in a form
  loaded from a record, where every step is reached (`init |> fill |> markClean` sets furthest
  to the last step, as `Flow.init` does by hand).

## 5. Dirty and the leave question (O-005, O-017)

**Klar can do, purely in Elm:** `isDirty`, a baseline (`markClean`, `revert`), the existing
`Form.unsavedFlag` / `unsavedChanges` fed by `isDirty state`, and `differingSteps`. The mark
for "unsaved changes" is therefore one call with no `Draft`.

**Stays with the application:** the question "may the user leave?". Klar sees only its own
state. The leave itself is a navigation event (`LinkClicked`, `UrlChanged`), and
`Browser.application` is the application's. What the form model gives is the flag:

```elm
LinkClicked request when Fm.isDirty model.form -> ask "Discard changes?" via ConfirmDialog
```

The roadmap already has "leave-guard for unsaved changes inside the application" (Phase B) and
O-017 proposes `Klar.Navigation`. That helper takes a `Bool` (`Fm.isDirty`) and is independent
of the form model; it should be designed next to the overlay layer, not here. Honest limits,
the same as `Form.unsavedChanges` says today: closing or reloading the tab cannot be guarded
without `beforeunload`, which needs JavaScript (principle 7 and 8). Klar will not fake it.

**The draft.** A draft in memory is the state itself. Surviving a reload needs storage, which
needs JavaScript. `encodeDraft : Form step f v -> State step -> Value` and `restoreDraft` can
exist for an application that has a port and a place to put it; Klar offers the encoding and
nothing else (open question 4).

## 6. How the form model meets the existing components

Three designs were weighed. All three keep the component modules (`Select`, `MultiSelect`,
`TagInput`, `NumberInput`, `FileDrop`, `DatePicker`) and `Form`, `Field`, `Validate`, `Stepper`
as modules; they differ in who owns the values and how the application names a field.

**A. Declared fields: a builder pipeline with typed handles** (section 2). One `Fm.State`,
one `Fm.Msg`; the components' states are held inside, ids go through `Ids`.

**B. Declared fields: a custom type of keys.** The application writes
`type FieldKey = Name | Country | Categories | ContactEmail Int | ...` and one function
`fieldSpec : FieldKey -> Fm.Spec` with an exhaustive `case`; values are read with
`Fm.text Name state`, `Fm.choice countries Country state`. One `State FieldKey`, one `Msg
FieldKey`.

**C. Toolkit: the application keeps the component states, Klar adds lenses.** The model stays
as it is; Klar adds `Form.watch : (model -> a) -> ...` style helpers and a `Form.dirty` that
compares a list of getters, plus a recipe for server problems.

| Criterion | A. Pipeline and handles | B. Custom type of keys | C. Toolkit over today's states |
|---|---|---|---|
| New API surface | about 55 names; the biggest of the three | about 40; no handle types, no `Builder` | about 15 |
| Type safety | **highest**: the control type is in the handle (`Field (Maybe CountryId)`), required changes the output type, a half-declared form does not compile, `set` and `get` are checked | medium: a key is not tied to a value type, so `Fm.text Country state` compiles and fails (or shows a blank) at run time; *exhaustiveness is excellent*: a key without a spec does not compile, and the same for its step | as today: nothing ties a getter to a control |
| "Cannot read before declared", "ids cannot clash" | compile time (only `fields form` gives handles; ids derived) | compile time for declared (`case` is exhaustive); the DOM id needs `toString : FieldKey -> String` written by the application, unless derived from the label (then it is the same as A) | not solved: ids are strings |
| What the application writes for onboarding step 1 | about 100 lines, about 125 formatted (section 7) | about 130 (estimate): the key type (10), the spec function (35), views by key (45), getters for the record by hand (25 for the step) | about 230 (estimate): states, messages and updates remain; saves the `Draft` and `load` only (about 60 lines for the whole app) |
| `Msg` and `State` | `FormMsg Fm.Msg` and `form : Fm.State Step`; no function in either. The typed component messages are forwarded inside | `FormMsg (Fm.Msg FieldKey)` and `State FieldKey`; no function | **ten `Msg` constructors remain** and ten component states; a `Draft` record is the only new thing |
| Repeating rows | needs `rows` (a second declaration); design cost | natural: `ContactEmail Int` is a key | natural: it is the application's list |
| Migration from today's `Form`, `Field`, `Validate` | additive: `Klar.Form` and `Validate` unchanged and reused; `Validate.Validator` is the text rule type; components unchanged except `Select.mapOption` and `Stepper.done`. Existing applications keep working | additive too; but the key-to-id string function resembles what O-021 complained about | none; nothing is delivered that fixes O-019, O-003, O-022 |
| How an AI reads it from the docs | one pipeline that reads like a decoder (`|> with`), one record of handles, one state; two things to keep in order | plain Elm everywhere (a custom type and a `case`); the three-places-per-field cost is visible, but each place is obvious | the AI must write the same glue as before; it has a recipe, not a type |
| Risks | positional `Fields` / `Values` (not compiler-checked); the erased id; the large `update` | type holes at run time; a fourth place per field when the value type changes | the 820 lines stay |

**Recommendation: A.** B is the second best and the right choice if the owner decides that no
type machinery beyond custom types and records is acceptable; its weakness is exactly the one
Klar exists to remove (a value read as the wrong kind compiles). C is not a form model; it
only moves the 270 marked lines into a tidier recipe and leaves ten messages and ten states in
every application.

A wins on the things the three applications showed hurt: the compiler already catches the
wrong argument (0 errors), so the next step in safety is to make the *forgotten* thing
impossible (an unvalidated required select, a field on no step, a server problem tied to a
string), and only A does that. Its price is a pipeline that must be learnt once. That cost is
small for an AI that has read `Json.Decode.Pipeline` and is paid back by every field
afterwards. B gets its repeated-row support for free; A must build it (2.7), and that is the
largest piece of work.

## 7. A real piece rewritten: step 1 of the onboarding app

Step 1 is the company: four text fields, a `Select` over `CountryId`, a `MultiSelect` over
`CategoryId`, tags, and a required file. The server can reject `Name`, `LegalName`,
`Registration`, `Website`, `CountryField`.

### 7.1 Today (counted in `Flow.elm` and `Ids.elm`)

| Part | Lines |
|---|---|
| Model fields `name` ... `contract` | 8 |
| `Draft`, `emptyDraft`, `toDraft` (company fields) | 24 |
| `init` (blank states with their DOM ids) | 8 |
| `load`, company fields (the contract file takes 9) | 16 |
| `toSupplier`, company fields | 9 |
| `companyProblems` and its validators (`registrationFormat`, `httpUrl`) | 22 + 10 |
| `serverProblem`, company cases | 15 |
| `Msg` constructors and the `TextField` type | 10 |
| `update` branches for the company controls | 40 |
| `companyStep` view | 85 |
| DOM ids (`Ids.elm`, 8 ids) and the `Form.labels` rows | 40 + 8 |
| **Total** | **295** |

### 7.2 With the form model

```elm
-- Supplier/Form.elm: the declaration (company part) ------------------------------- count: A
type Step
    = Company
    | Contacts
    | Delivery
    | Pricing
    | Review


type alias Fields =
    { name : Fm.Field String
    , legalName : Fm.Field String
    , registration : Fm.Field String
    , website : Fm.Field String
    , country : Fm.Field (Maybe CountryId)
    , categories : Fm.Field (List CategoryId)
    , certifications : Fm.Field (List String)
    , contract : Fm.Field (List FileDrop.FileInfo)
    }


type alias Values =
    { name : String
    , legalName : String
    , registration : String
    , website : Maybe String
    , country : CountryId
    , categories : List CategoryId
    , certifications : List String
    , contract : FileDrop.FileInfo
    }


countryIds : Fm.Ids CountryId
countryIds =
    Fm.ids { toKey = \(CountryId code) -> code, fromKey = Just << CountryId }


categoryIds : Fm.Ids CategoryId
categoryIds =
    Fm.ids { toKey = \(CategoryId n) -> String.fromInt n, fromKey = Maybe.map CategoryId << String.toInt }


form : Fm.Form Step Fields Values
form =
    Fm.define "supplier" Fields Values
        |> Fm.step Company "Company"
        |> Fm.with (Fm.text "Name" |> Fm.required |> Fm.rules [ Validate.maxLength 80 ])
        |> Fm.with (Fm.text "Legal name" |> Fm.required)
        |> Fm.with (Fm.text "Registration number" |> Fm.required |> Fm.rules [ registrationFormat ])
        |> Fm.with (Fm.text "Website" |> Fm.rules [ httpUrl ])
        |> Fm.with (Fm.choice countryIds "Country" |> Fm.required)
        |> Fm.with (Fm.choices categoryIds "Product categories" |> Fm.atLeast 1)
        |> Fm.with (Fm.tags "Certifications")
        |> Fm.with (Fm.files "Signed contract" |> Fm.one |> Fm.required)
        -- ... Contacts, Delivery, Pricing, Review follow the same way
        |> Fm.build


fields : Fields
fields =
    Fm.fields form
```

```elm
-- Supplier/Form.elm: loading and the server's problems (company part) ------------- count: B
fill : Supplier -> Fm.State Step -> Fm.State Step
fill s =
    Fm.set fields.name s.name
        >> Fm.set fields.legalName s.legalName
        >> Fm.set fields.registration s.registrationNumber
        >> Fm.set fields.website s.website
        >> Fm.set fields.country (Just s.country)
        >> Fm.set fields.categories s.categories
        >> Fm.set fields.certifications s.certifications
        >> Fm.set fields.contract (Maybe.withDefault [] (Maybe.map (\f -> [ f ]) s.contractFile))


fromBackend : Backend.Problem -> Fm.Problem
fromBackend p =
    case p.field of
        Backend.Name -> Fm.problem fields.name p.message
        Backend.LegalName -> Fm.problem fields.legalName p.message
        Backend.Registration -> Fm.problem fields.registration p.message
        Backend.Website -> Fm.problem fields.website p.message
        Backend.CountryField -> Fm.problem fields.country p.message
        -- ... contacts, delivery, pricing
```

```elm
-- Flow.elm: the model, the update and the step's view ------------------------------- count: C
type alias Model =                     -- the form fields are one entry
    { form : Fm.State Step, ... }

type Msg
    = FormMsg Fm.Msg                   -- one constructor for every control of every step
    | ...

FormMsg inner ->
    Fm.update form inner m.form |> Tuple.mapBoth (\f -> { m | form = f }) (Cmd.map FormMsg)

Submit ->
    let r = Fm.advance form m.form in
    ( { m | form = r.state }, Cmd.map FormMsg r.cmd )   -- and send r.submit when Just

dirty : Bool
dirty = Fm.isDirty m.form

companyStep : Ctx -> Fm.View Msg -> Html Msg
companyStep ctx v =
    Form.section "Company"
        "Who the supplier is, as registered."
        [ Form.grid 2
            [ Fm.text v fields.name [ TextInput.hint "How the supplier appears in lists." ]
            , Fm.text v fields.legalName []
            , Fm.text v fields.registration [ TextInput.hint "8 digits." ]
            , Fm.text v fields.website [ TextInput.url ]
            , Fm.select v fields.country (countryOptions ctx.countries) [ Select.onRetry ReloadRef ]
            , Fm.multiSelect v fields.categories (categoryOptions ctx.categories) [ MultiSelect.onRetry ReloadRef ]
            , Form.fullRow (Fm.tags v fields.certifications [ TagInput.placeholder "Type a certification and press Enter", TagInput.hint "For example ISO 9001.", TagInput.maxTags 10 ])
            , Form.fullRow (Fm.files v fields.contract [ FileDrop.accept [ ".pdf" ], FileDrop.maxSize 5000000 ])
            ]
        ]
```

### 7.3 The count

| Part | Today | With the model |
|---|---|---|
| Declaration: records, ids, pipeline (A) | 8 (model) + 24 (draft) + 8 (init) + 22 + 10 (rules) + 48 (ids, labels) = 120 | 50 |
| Load and server problems (B) | 16 + 9 + 15 = 40 | 20 |
| Msg, update and view (C) | 10 + 40 + 85 = 135 | 28 |
| **Total** | **295** | **98** |

(Non-blank lines of the sketches above, comments included; elm-format breaks the longest view lines, so say about 125 in a real file, against 295: a reduction of about 60 %. The `Msg` and `update` lines of C are counted once, since they are shared by all five steps;
in the other four steps they are 0 more lines, where today each step adds its own.) The
checks that ran by hand are now one declaration: `requiredValue`, `nonEmptyList`,
`numberProblems`, `fromErrors` and `validateText` (about 50 lines, shared) disappear, as do
`Draft`, `toDraft`, `withBaseline`, `isDirty`, the whole of `Ids.elm` except modal ids, the
`edited` helper and its eight call sites, `visibleProblems` and `errorFor`, `markAttempted`,
`firstFieldOf` and the stepper list. For the whole app the estimate is: 820 lines of plumbing
become about 260 (declaration 110, fill and backend mapping 60, wiring 30, review and
dialog functions that read `Fm.get` 60), with `Msg` shrinking by about 25 constructors.

## 8. What the design does not do, risks, open questions, plan

### Deliberately not done

* **No generated views.** The form model does not draw the form. The application keeps its
  sections, grid and its own review page; the model supplies controls one at a time. A full
  generator (`Form.view fields`) would take away the layout the application needs.
* **No conditional visibility, no field groups, no wizard branching** (Phase F "field groups
  with conditional visibility"). A field that is hidden is simply not placed in the view; a rule
  that depends on another field uses `check`.
* **No HTTP, no knowledge of the backend.** Klar takes `List Problem` and a `Form.Status`.
* **No leave guard, no `beforeunload`** (section 5).
* **No persistence of a draft** beyond in memory (section 5).
* **No undo/redo.** The baseline gives `revert`; history is Phase D.
* **`InlineEdit` is not a form field.** It saves one value on its own and keeps its own state;
  the detail page (`Detail.elm`) does not change. Using `Fm.Field` inside it later is possible,
  not planned.
* **No validation that depends on the server** (is this registration number taken?): that is
  a server problem after the save, or an asynchronous check the application owns.

### The three biggest risks

1. **Order is by position, and `fill` is not checked for completeness.** `Fields`, `Values`
   and the pipeline must list the fields in the same order, and two `Maybe String` slots
   swapped in one record only is invisible to the compiler. Mitigation: the documentation
   puts both records next to the declaration, a one-line round-trip test is part of every
   recipe, and `Fm.roundTrips` can be a ready-made test helper. If the owner finds this
   unacceptable for principle 5, design B is the alternative.
2. **Erased ids and a large `update`.** Choices are stored as `Select.State String` by key.
   A bad `Ids` (`fromKey` not the inverse of `toKey`) is a silent loss. The form's `update`
   must forward 10 component kinds and keep their focus behaviour (the CONTRIBUTING items about
   keys right after a list opens and focus surviving a re-render); a regression there would
   be found only in the browser, where the three applications found all their bugs.
   Mitigation: `ids` exports a test helper that checks a list of values round-trips; every
   kind is checked with real key presses and `document.activeElement` before the step is done.
3. **Scope: rows and application-owned editors (deferred, section 9.3).** The flat form is well defined; contacts
   (rows with a cross-row rule) and pricing rules (an editor in a dialog) are what the
   onboarding app actually needs. If they turn out awkward, the model covers only half of the
   app, and the 820 lines drop to 500, not 260. They are built last (step 5) so that the
   decision can be reviewed with a working core. The API is frozen at the first publish, so
   `rows` and `custom` must be right before then; they are not worth shipping half done.

### Open questions for the owner

1. **Are string keys for ids acceptable?** `choice` needs `Ids id` (`toKey`, `fromKey`), the
   same pair `Table.rowIds` and `Tree.nodeIds` already ask for. *Recommend: yes*, and unify the
   three into one `Klar.Ids` type in the "typed ids" item of A8, which also fixes O-002 and
   O-004 (`Rule` choices, `Radio`). The alternative is to keep `Select.State id` in the
   application's model, which is design C.
2. **Is a positional pipeline acceptable?** See risk 1. *Recommend: yes*, with the round-trip
   test in the recipe. Say no only if the owner wants the compiler to refuse a swap.
3. **Rows and custom values in the first version, or later?** *Decided by the owner: not in
   this round* (section 9.3). They are added only when the conditions listed there hold.
4. **When is a field's problem shown?** Proposed: after the field was left once or edited,
   after its step was attempted, after the form was reviewed. The alternative (only after a
   Next or Save) shows less while typing. *Recommend: the proposed rule*; it is one function
   and can be changed in a minor version because the rule is not part of the types.
5. **The draft.** Encode and restore the state as `Value` for applications with a port, or
   not at all? *Recommend: not in the first version.* It adds names to a frozen API and no
   application of the three asked for it. Add it with Phase F "wizard form with a draft".

### Implementation plan (each step reviewable on its own)

1. **Small additions to existing modules** (no new module; built: `Select.mapOption`; `Stepper.done` waits for step 4). `Select.mapOption` (and the same
   for `MultiSelect`'s option), `Stepper.done` plus a doc line that "visited" is "not
   disabled". Tests: pure unit tests of
   `mapOption` (label, group, description kept). Breaks: nothing. Review: a 100-line diff.
2. **`Klar.Form.Model`, the core for text, number, choice, choices, toggle** (built, section 9). `Ids`, `Spec`,
   `define/with/build/fields`, `init/set/get/toValues`, `isDirty/markClean/revert`, `update`,
   `bind` and the five views, the id derivation. Tests (elm-test, pure): validation and the
   output type of `required`, `atLeast`, `one`; `set`/`get`/`toValues` round trip; dirty after
   typing and undoing; id derivation is unique for equal labels; and the "must not compile"
   list that A5 asks for (a half-declared form, a text handle given to `select`). Breaks:
   nothing; the new module is added to `exposed-modules`. Showcase page.
3. **The remaining kinds**: tags, files, day, radio and `textArea` (`custom` is out, section 9.3). Tests: each
   kind's parse, empty value and snapshot. A browser pass with the keyboard on every kind,
   checking focus after an edit and after opening a list (the CONTRIBUTING rules). Breaks:
   nothing.
4. **Steps, problems and status.** `step/review`, `advance/back/goTo`, `stepper`, `summary`,
   the visible-problem rule, `problem/rejected`, `setStatus`, `differingSteps`,
   `stepHasProblems`. Tests: the rule of visibility for every combination of touched,
   attempted and reviewed; `advance` on every step; a server problem clears when its field is
   edited; `rejected` goes to the right step. Breaks: nothing.
5. **Rows, `custom` and `check`** (deferred by amendment 3; only after the conditions of
   section 9.3). `rows`, `row`, `addRow`, `removeRow`, row ids, `check`. Tests: ids
   of row 0 and 2 stay stable when row 1 is removed (the keys follow the position, so the
   summary says "Contact 2"); a cross-row rule; dirty after adding and removing a row. Breaks:
   nothing. This is the step that can change the design of 2.7; review it separately.
6. **Migrate and document.** Rewrite `apps/onboarding` on the model (the A0 second round), the
   recipe "an edit form with validation and a save that can fail" (A1) and the `Klar.Form`
   module doc, which points to the model and keeps its low-level example. In the same change,
   decide what to remove while the API is free: `Form.labels` and `Form.onFocusField` stay (a
   hand-written form still needs them); `Validate.collect` stays. Tests: `npm run check`, the
   benchmark. Breaks: nothing in `Klar.Form`. The application `apps/onboarding` changes
   completely, which is the purpose.

**First step: step 1**, because it is additive and small, and it settles the one thing the
core depends on (a `Select.Option` can be given another id type).

## 9. The owner's amendments, and what building steps 1 and 2 taught

Branch `form-model`. Built: plan steps 1 and 2 (the core: text, number, choice, choices,
toggle) and the showcase page *Form model* (`example/src/Page/Gallery/FormModel.elm`). Not
built: steps, tags, files, day, radio, `textArea`, `rows`, `custom`, `check`, the stepper,
`Stepper.done` (it has no user until the steps exist), the migration of `apps/onboarding`.
The text above this section is already consistent with these decisions.

### 9.1 `withMessage` takes a function from `Locale` (amendment 1)

```elm
withMessage : (Locale -> String) -> Spec c o -> Spec c o
```

The first draft took `{ nb : String, en : String }`, which freezes the set of languages
into the API (`Locale` is opaque so that a language can be added in a minor version). A
declaration is a constant, so the function lives in the `Form` constant and never in `State`
or `Msg`. The application writes `\locale -> Locale.pick locale { nb = ..., en = ... }`,
which is what `Validate.withMessage` hides inside its own record today. Built-in messages
(required, at least, at most one, range, whole, not a number) are in English and Norwegian
Bokmål in the module.

`withMessage` replaces the message of **the rule added last** (`required`, `atLeast`, `one`,
`rules`, `range`, `whole`); on a spec with no rule yet it does nothing. Tested.

### 9.2 Naming and layering: open decision (amendment 2)

The new model is the way to build a form, so it should not live next to `Klar.Form` as
`Klar.Form.Model` forever. **Now:** it is the module `Klar.Form.Model`, as designed, so that
nothing churns while the prototype is judged. **Plan once the prototype is judged good**
(the owner's decision, after the second A0 round has used it):

1. `Klar.Form.Model` becomes `Klar.Form`. Its types and functions keep their names
   (`Fm.Field`, `Fm.State`, `Fm.textInput` ... become `Form.Field`, `Form.State`,
   `Form.textInput`), so the move is a rename of the import in applications.
2. Today's `Klar.Form` (the frame: `view`, `section`, `grid`, `fullRow`, `actions`,
   `stickyActions`, `errorSummary`, `focusSummary`, `focusField`, `Status`, `status`,
   `focusStatus`, `unsavedChanges`, `unsavedFlag` and the attributes) moves under it as
   `Klar.Form.Layout` (or `Klar.Form.Frame`; the name is part of the decision). The form model
   uses it internally and reuses its attributes, so the layout stays one module.
3. In one commit while the API is free (nothing is published): `elm.json` exposed modules,
   the module docs, `USING.md`, `example/` and `apps/*` imports, `check:example-imports`,
   the README module list, and the recipe "an edit form with validation and a save that can
   fail". `Form.Status` stays a closed union (it is on the list in `CONTRIBUTING.md`
   rule 8) and moves with the layout.
4. A hand-written form (no model) keeps working through `Klar.Form.Layout`; its low-level
   example stays in that module's doc.

Questions for that decision: does `Status` belong with the layout or with the model (the
model's `rejected` and `reveal` end in the same `focusSummary`)? Does `Klar.Form.Spec`
(section 9.5) stay a submodule?

### 9.3 `custom` and `rows` are not built (amendment 3)

Both are removed from the first-version scope (sections 2.3 and 2.7 say so). They are the
hard part, they freeze the most names, and they are what the onboarding app needs for half of
its forms; shipping them half done is worse than shipping them late. **They are added only
when all of these are true:**

1. The core (this round) has been used by the second A0 round: the three applications are
   rebuilt on it, and the friction log has no open item against the core's shape (the
   pipeline, the handles, the `set`/`get` pair, the visibility rule).
2. The types of the steps are decided (section 4 is built), because a row group is a
   sub-form with its own step and its own problems, and its handles must fit the summary.
3. The answer to "how does a handle name row `i`" exists in a prototype that compiles: the
   keys follow the position (`contacts-2-email`), so removing row 1 renames row 2; the
   summary says "Contact 2" from the position. That choice, and the cross-row `check`, are
   the decisions that cannot be changed after the first publish.
4. `custom` has a second consumer besides the price-rule dialog (`Rule` is one); an
   application-owned editor needs `Value` encode and decode, and the baseline is the encoded
   text. One consumer is not enough to freeze that codec shape.

Until then the application keeps those values in its own model and uses
`Fm.isDirty`/`Fm.markClean` for the rest; nothing in the core prevents it.

### 9.4 The four parameters, tested for real (amendment 4)

Eleven wrong programs, compiled with Elm 0.19.3: [FORM-MODEL-ERRORS.md](FORM-MODEL-ERRORS.md)
(sources and the unedited output in `design/form-model-errors/`). Result in one paragraph:
**readable.** Nine of the eleven point at the right line and show the missing or wrong
thing in the application's own words (`Fm.Field (Maybe Country) -> Fields`: a slot of `Fields`
that still waits for a `Maybe Country`). Two are weaker (two differently typed fields
swapped: the location is right, the message is about the records, and the compiler's
hint "takes too many arguments" points the wrong way; a single-field form that forgot the
`Values` constructor). The unresolved `step` shows as noise in `Builder step ...`. The one
mistake the compiler cannot see (two same-typed fields swapped) is caught by
`Fm.roundTrip` in one test line. The evidence does not call for design B.

### 9.5 The exposed API of the first version (amendment 5)

`Klar.Form.Model` exposes **47 names**:

| Group | Names | Count |
|---|---|---|
| Types | `Form State Msg Field Ids Problem Spec Builder View` | 9 |
| Declaring | `define with build fields ids` | 5 |
| Kinds | `text number choice choices toggle` | 5 |
| Rules | `required atLeast one rules range whole hint withMessage` | 8 |
| Values and state | `init set get toValues isDirty markClean revert update` | 8 |
| Problems from the server | `problem rejected reveal` | 3 |
| Views | `bind textInput numberInput select multiSelect switch summary` | 7 |
| Tests | `roundTrip lostIds` | 2 |

No exposed union, no function-valued field in `State` or `Msg` (see 9.6 for the one that the
select's own message carries). For comparison, in this repository: `Klar.Icon` 195, `Klar.Table`
124, `Klar.Tree` 55, `Klar.Rule` 53, `Klar.Money` 48, **`Klar.Form.Model` 47**, `Klar.Chart`
46, `Klar.Select` 44, today's `Klar.Form` 28. There is no budget script yet (A2 asks for
one and says "not a hard number"); by the roadmap's own wording the question is whether the
*common path* is short. The common path of an application is about 22 names (`define with
build fields ids`, `text choice choices`, `required atLeast`, `init set markClean get
toValues`, `update`, `bind`, `textInput select multiSelect`, `summary`, `problem rejected`),
so the common path fits. The module as a whole is over the ~40 mark.

**Proposal (to do with the rename of 9.2, not now):** split by role, which also splits the
documentation page in two readable halves.

* `Klar.Form.Spec`, the declaration vocabulary that is only read once, at the top of the file:
  `Spec`, the five kinds and the eight rules, **14 names**. (Plain Elm modules, imported as
  `Spec`: `Spec.text "Name" |> Spec.required`.)
* `Klar.Form.Check`, test helpers: `roundTrip`, `lostIds`, **2 names** (it keeps the test
  helpers out of the application's autocomplete and out of the module an AI reads first).
* `Klar.Form.Model` (later `Klar.Form`): the rest, **31 names**. `Builder` is the only type
  an application never writes (it appears in the `define`/`with`/`build` signatures; if those
  three moved into `Klar.Form.Spec` too, that module would have 17 names and the runtime 28;
  either split is fine).

Every type that appears in a public signature must stay nameable (`check:api` enforces it),
so `Builder`, `Spec` and `View` cannot become internal; what can move is functions.

### 9.6 What the build changed in the design

* **Names of the views.** The kinds and the views had the same names (`text`, `number`,
  `toggle`), which cannot both be exposed. A view is named after the component it draws:
  `textInput numberInput select multiSelect switch`; a kind after the value: `text number
  choice choices toggle`. (Section 2.6 says so.)
* **`update : Msg -> State step -> ( State step, Cmd Msg )`** and
  **`revert : State step -> State step`** do not take the `Form`: nothing in them needs it
  (the component messages carry their own rules; the baseline is in the state). The same
  shape as every component's `update`.
* **Locale is an argument where text is made:** `toValues : Locale -> Form -> State -> ...`
  and `bind : Locale -> (Msg -> msg) -> Form -> State -> View msg`. A `Problem` is
  `{ field : String, message : String }`, the shape of `Validate.Error`, so it goes to
  `Form.errorSummary` unchanged; the labels for the summary come from the declaration.
* **`reveal : Form -> State -> ( State, Cmd Msg )`** is new: the "attempted" of the
  visible-problem rule for a form without steps (press Save, show every problem, focus the
  summary). `rejected` does the same and stores the server's problems. With steps (plan
  step 4) both are replaced by `advance`.
* **The visible-problem rule** as designed, minus steps: a client problem shows when the
  field was edited or left, or after `reveal`/`rejected`; a server problem shows until its
  field is edited; the client problem wins. For a select and a multi select "left" is "the
  list was open and is now closed"; for a number it is `NumberInput.isTouched`.
* **The type variable `step` is a phantom** until the steps are built: forms are
  `Fm.Form () Fields Values`. Adding `step` later changes no signature.
* **Select attributes are `Select.Attribute String msg`**, not `Attribute id msg`: the state
  stores keys (`Select.State String`), so an attribute that mentions the id type
  (`creatable`, `valueText`, `options`, `remote`) cannot be given by the application. That
  is intended (the options are an argument); the attributes that do not mention it
  (`placeholder`, `onRetry`, `clearable` ...) are polymorphic and work.
* **A function in the select's own message.** `Select.Msg` carries `Maybe (String -> id)` in
  its `Key` constructor (the `creatable` factory). The form never offers `creatable`, so it is
  always `Nothing` in a form's `Msg`; the claim "no function in `State` or `Msg`" holds for
  everything the form adds and for every message a form can produce today.
* **One-field forms** need both constructors (`Fm.define "p" identity identity`); forgetting
  the second is case I of the error file.
* **`Form.Status` stays with the application** (it is not in `State`): the application
  owns the request and the model keeps `status : Form.Status`, as the page does.
* **Key clash with a component's derived ids.** A select with key `account-country` derives
  `account-country-search`; a field labelled "Country search" in the same form would clash.
  Not guarded; rare, and a duplicate-id check belongs with the A8 "DOM ids derived from
  state" item.

### 9.7 The count on the showcase page (step 1 of the onboarding app)

`example/src/Page/Gallery/FormModel.elm`, a customer account: four texts, a country select,
a segments multi select, a server problem on the name, the registration number and the
country, the dirty flag, Load, Revert, Save and the status. Non-blank lines, after
`elm-format`, between the markers:

| Part | Design sketch (8 fields) | Built (6 fields) | Notes |
|---|---|---|---|
| A. Declaration: records, ids, pipeline, two validators | 50 | 44 | 62 lines with blanks; two `Validate.custom` rules are in it |
| B. Load, `toAccount`, server mapping | 20 | 31 | `toAccount` (8) is the application's domain mapping, not in the sketch |
| C. Model, `Msg`, `init`, `update`, the form's view | 28 | 64 | model/msg/init 13, update 20 (FormMsg, Load, Revert, Save with server problems), subscriptions 3, view 28 |
| **Total** | **98** (about 125 formatted) | **139** | |

The old version of the same step is counted at 295 (section 7.1) for eight fields and
without Save, Load, Revert or the status line. The comparison is therefore not exact: the
built page does more (a working Save with server problems, Load, Revert, a status line) with
fewer fields (no tags, no files). Read it as: the sketch was about right in A (and in the
total, once formatting is counted: 125 predicted, 139 built, with the extra features); C is
bigger than sketched because the sketch left out the `Model`/`Msg`/`init` boilerplate and the
save flow; and the reduction against 295 is at least 50 %, more if the old version were
given the same features. No old-API version of this exact page exists, so no better number
is claimed. What did disappear, as designed: `Draft`, `toDraft`, `isDirty`, `edited` and its
call sites, the DOM ids, the `Form.labels` list, `visibleProblems`, `requiredValue` and
`nonEmptyList`, and ten `Msg` constructors (there is one).

### 9.8 Verified in a browser

Headless Chrome over the DevTools protocol with real key events (script:
`form-model-browser-test.mjs` in the shared notes folder), page `#/components/form-model`:

* Tab order: name, legal name, registration number, website, country, segments, Load saved
  account, Save (Revert is disabled while the form is clean and is skipped).
* Focus after an edit stays in the input while the error appears and goes
  (`document.activeElement` = `input#account-name` after typing, clearing and retyping).
* Select: ArrowDown on the trigger opens the list with focus in the search input; typing
  `swe` and Enter picks Sweden and focus returns to the trigger. Multi select: two picks keep
  focus in the search input; Escape returns focus to the trigger; both chips show.
* Save with a server refusal: focus is on the summary (`div#account-summary`); the name and
  registration number show the server's words at the field and in the summary; editing the
  name clears only the name's problem and focus stays in the input.
* Save with client problems: focus on the summary, "Name: Required | Registration number:
  Required"; a summary button focuses its field. Enter in a field submits.
* Load, type a letter (unsaved: yes), delete it (unsaved: no), Revert.
* axe-core 4.10.2 (wcag2a, wcag2aa, wcag21aa, wcag22aa, best-practice): no violations on
  the initial page, with server problems showing, with client problems showing, and at the
  end.

## 10. What is built now (branch `t-form`)

The seam of A0 round 2 (`apps/ROUND2-EVALUATION.md` item 3; 110 `KLAR GAP` lines and 19
frictions in `apps/round2/onboarding`) is closed. The order of the work and what it changed:

1. **Problems the application can see (R2O-005, 006, 007, 018).** `Form.problems` and
   `Form.hasProblems` return everything wrong, with the field's label and its step: the
   rules of every field, the server's problems that still stand, and `Form.outside`
   (problems of things the model does not hold, written as plain `Problem` records).
   `toValues` fails while any of them stands, so a record is never produced behind a server
   problem. `Form.focus` and `Form.goToProblem` replace the hand-typed DOM ids. `rejected`
   stores the problems whether or not the form is on screen, goes to the step of the first
   problem and focuses a summary that may not exist (a no-op), which is the whole answer to
   R2O-018.
2. **Kinds and ids (R2O-001, 004, 011, 014, 017).** `Spec.tags`, `Spec.files` (with
   `required`, `atLeast`, `one`; refused files are a problem of the field), `Form.textArea`
   (a second view of a text field, not a kind), and `Klar.Ids`: the one place an id type is
   written as text, taken by `Spec.choice`, `Spec.choices` and `Rule.choiceFieldOf`. `rules`
   now lets a blank text pass every rule, `Validate.custom` included; a field that must be
   filled in says `required`.
3. **Steps and rows (R2O-003, 013, 015, 016).** `Spec.step` declares the application's own
   step type. `advance`, `back`, `goTo`, `stepper` and `summary` own the current step, the
   validation on the way when jumping forward, the failed marks, the focus on the new step
   and the review list. `Spec.rows` declares a repeating group once; its sub-declaration is
   an ordinary `Form`. `Form.isDirty` is one flag over every step and row.
4. **Module shape (9.2, 9.5).** `Klar.Form` is the model, `Klar.Form.Layout` the old frame,
   `Klar.Form.Spec` the declaration, `Klar.Form.Check` the test helpers. One implementation
   (`Klar.Form.Core`, not exposed) behind three documented faces; `check:api` accepts an
   alias that only re-exports an internal type.

### Decisions

* **Row keys are stable numbers, not positions.** Section 9.3 proposed `contacts-2-email`
  by position (removing row 1 renames row 2). It is not what was built. Every row gets a
  number from a counter in the state when it is added (`supplier-contacts-3-email`), the
  number stays with the row for as long as it lives and is never used twice, also after
  `revert` and `fillRows`. Why: the state of a select, a tag field or a file field is in a
  slot keyed by the DOM id, so a position key would move or lose it when a row is removed;
  the focus after a remove and the server's problems of a removed row need ids that do not
  shift; an application that keeps a handle keeps a right one. The position is only for
  words: the summary says "Contact 2, Email" and the remove button "Remove contact 2", and
  the server's own position (the list it was sent) is mapped with
  `Form.rowFields f.contacts state |> List.drop i`. The cost: a DOM id is not predictable
  from the position, which nobody should need.
* **`custom` stays out**, as asked. The price rules of the onboarding app (a rule builder
  and a discount) are the application's; they are handed to the form as problems with
  `outside`, and the form counts them, lists them, marks their step and blocks the Next
  button on them.
* **A `check` runs when every field of the form is valid on its own**, so on a form with
  steps it shows up when the last step is reached. A rule that belongs to a step goes on the
  field: `Spec.rule` takes a rule over the whole list of a list-valued field, `rows`
  included ("at most one primary contact"). The sub-form of a group has its own `check`,
  which runs row by row. Found in the browser, not in the unit tests.
* **A step with no fields of the form** gets an empty named region where `summary` goes, so
  the focus has a place to land when the form moves to it (the review step; a step whose
  fields the application draws). The review list is the `summary` on the last step when it
  has no fields.
* **No `disabled` steps and no `furthest`.** The stepper allows every click; going forward
  checks every step on the way and stops at the first with problems. That is "validate the
  steps on the way", and it needs no state besides the current step.
* **Dirty over the part the form does not hold** is the application's `||` with its own
  snapshot (the rules). It is one line, but it is the one place a leave guard needs two
  questions.

### The API, by module

| Module | Names | Of which types |
|---|---|---|
| `Klar.Form` | 44 | `Form State Msg Field Rows Problem View` |
| `Klar.Form.Spec` | 24 | `Builder Spec` |
| `Klar.Form.Check` | 2 | |
| `Klar.Form.Layout` | 28 | `Status(..) Attribute` |
| `Klar.Ids` | 4 | `Ids` |

The form model is 70 names (the prototype of section 9.5 had 47 for text, number, choice,
choices and toggle). The common path of a flat form is about 22: `Spec.define with build
text choice choices required atLeast`, `Form.fields init update bind toValues summary
textInput select multiSelect problem rejected reveal markClean isDirty`, `Ids.make`. A wizard
adds `Spec.step rows`, `Form.advance back goTo stepper currentStep rowFields addRow
removeRow fillRows`.

### The proof

`apps/round2/onboarding` was copied to a scratch folder and its forms rewritten on the model
(`design/form-model-proof/Flow.elm`; the other modules changed by two lines each: `Domain`
takes `Klar.Ids`, `Main` focuses with `Flow.firstFocus`).

| | Round 2 | On the finished model |
|---|---|---|
| `Flow.elm`, physical lines | 2 011 | 1 299 |
| `Flow.elm`, code lines (no blanks, no comments) | 1 631 | 1 030 |
| Section by section, code lines | declarations 73, model 198, issues 216, update 624, view 447 | the form (declaration, load, server mapping, record) 180, model 88, price rules 67, update 283, view 367 |
| `KLAR GAP` lines | 110 | 45, all for the price rules |
| Copy of the server's problems | 79 lines | none |
| Hand-typed DOM ids for fields | 14 `focusField` call sites | none (`Form.focus`, the summary) |
| Own stepper bookkeeping (`step`, `tried`, `attempt`, `enter`, `SelectStep`, marks; R2O-016 says about 90) | about 90 lines | none |
| Rows (contacts): a form per row, `reveal` per row, `allJust` (R2O-003, 013) | not counted separately | `Spec.rows`, `rowFields`, `addRow`, `removeRow`: no code of its own |
| Own OR of dirty flags (R2O-015) | about 20 lines | 1 line (`Form.isDirty ... || rules`) |

What still needs glue, and why: the 45 lines are the price rules, the one editor that is
the application's (the model has no `custom`): (a) `sync`, the call of `Form.outside` at the
end of every update (6 lines); (b) the server's refusals of a rule, kept by the application
with the rule because the form cannot place them (12 lines); (c) `moved`, which focuses the
first rule when the form has moved to the Pricing step, because the form has nothing to focus
there (27 lines). The list of rules, the rule builder, the discounts and their own problems
(67 lines) are the editor itself and are not counted as a gap.

Walked in headless Chrome over the DevTools protocol with real key events (scripts in the
shared notes folder, `t-form-browser-tests`): every kind (text, select, multi select,
switch, tags, files, number, long text), Enter in a field to go to the next step, the
stepper, add and remove rows with Enter on the buttons (focus after each), a rejected save
(focus on the summary of the step of the first problem), editing the refused field (only
its problem goes), the conflict flow, the offline retry, and the unsaved mark. axe-core 4.10
(wcag2a, 2aa, 21aa, 22aa, best-practice): no violations in the states of the application
that were walked and in 11 states of the showcase page.
