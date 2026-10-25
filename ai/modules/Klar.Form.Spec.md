# Klar.Form.Spec

The declaration of a form: its fields in order, each with a label and its rules, grouped in steps.

Import: `import Klar.Form.Spec as Spec` | Group: Forms

Types: `Spec`, `Builder`

## Signatures

```elm
-- Declaring a form
type alias Builder step fields values = Form.Core.Builder step fields values
define : String -> fields -> values -> Builder step fields values
with :
    Spec control output
    -> Builder step (Form.Field control -> f) (output -> v)
    -> Builder step f v
step : step -> String -> Builder step fields values -> Builder step fields values
check :
    (fields -> Form.State step -> values -> List (Form.Problem step))
    -> Builder step fields values
    -> Builder step fields values
checkFields :
    (Locale.Locale -> fields -> Form.State step -> List (Form.Problem step))
    -> Builder step fields values
    -> Builder step fields values
shownWhen :
    (fields -> Form.State step -> Bool)
    -> (fields -> Form.Field c)
    -> Builder step fields values
    -> Builder step fields values
requiredWhen :
    (fields -> Form.State step -> Bool)
    -> (fields -> Form.Field c)
    -> Builder step fields values
    -> Builder step fields values
build : Builder step fields values -> Form.Form step fields values

-- Kinds of field
type alias Spec control output = Form.Core.Spec control output
text : String -> Spec String (Maybe String)
number : String -> Spec (Maybe Float) (Maybe Float)
choice : Ids.Ids id -> String -> Spec (Maybe id) (Maybe id)
choices : Ids.Ids id -> String -> Spec (List id) (List id)
toggle : String -> Spec Bool Bool
date : String -> Spec (Maybe Date.Date) (Maybe Date.Date)
dateRange : String -> Spec (Maybe ( Date.Date, Date.Date )) (Maybe ( Date.Date, Date.Date ))
money : Money.Currency -> String -> Spec (Maybe Money.Money) (Maybe Money.Money)
masked : MaskedInput.Mask -> String -> Spec (Maybe String) (Maybe String)
tags : String -> Spec (List String) (List String)
files : String -> Spec (List FileDrop.FileInfo) (List FileDrop.FileInfo)
conditions : String -> List (Rule.Field ()) -> Spec Rule.Rule (Maybe Rule.Rule)
rows :
    { label : String, item : String }
    -> Form.Form () rowFields rowValues
    -> Spec (Form.Rows rowFields) (List rowValues)

-- Rules
required : Spec c (Maybe a) -> Spec c a
atLeast : Int -> Spec c (List a) -> Spec c (List a)
one : Spec c (List a) -> Spec c (Maybe a)
rule : (o -> Bool) -> (Locale.Locale -> String) -> Spec c o -> Spec c o
rules : List Validate.Validator -> Spec String o -> Spec String o
range : Float -> Float -> Spec (Maybe Float) o -> Spec (Maybe Float) o
whole : Spec (Maybe Float) o -> Spec (Maybe Float) o
minDate : Date.Date -> Spec (Maybe Date.Date) o -> Spec (Maybe Date.Date) o
maxDate : Date.Date -> Spec (Maybe Date.Date) o -> Spec (Maybe Date.Date) o
minMoney : Money.Money -> Spec (Maybe Money.Money) o -> Spec (Maybe Money.Money) o
maxMoney : Money.Money -> Spec (Maybe Money.Money) o -> Spec (Maybe Money.Money) o
hint : String -> Spec c o -> Spec c o
serverKey : String -> Spec c o -> Spec c o
withMessage : (Locale.Locale -> String) -> Spec c o -> Spec c o
```

## Documentation

The declaration of a form: its fields in order, each with a label and its
rules, grouped in steps. It is read once, at the top of the file that owns the
form, and it is a constant: it never goes in a model or a message. What is
declared here is used through [`Klar.Form`](Klar.Form.md).

Use when: you declare the fields, labels, rules and steps of a form once, at the top of the file that owns it.
Do not use when: you keep or change form state at run time (use `Klar.Form`).
Quick path: `define`, `with`, `build`

    import Klar.Form as Form
    import Klar.Form.Spec as Spec

    type alias Fields =
        { name : Form.Field String
        , country : Form.Field (Maybe CountryId)
        , categories : Form.Field (List CategoryId)
        }

    type alias Values =
        { name : String
        , country : CountryId
        , categories : List CategoryId
        }

    form : Form.Form () Fields Values
    form =
        Spec.define "supplier" Fields Values
            |> Spec.with (Spec.text "Name" |> Spec.required |> Spec.rules [ Validate.maxLength 80 ])
            |> Spec.with (Spec.choice countryIds "Country" |> Spec.required)
            |> Spec.with (Spec.choices categoryIds "Categories" |> Spec.atLeast 1)
            |> Spec.build

`Fields` is the record of **handles** you put in the view and read with; `Values`
is the record the form **produces** when it is valid. Both are filled by
position, like a decoder pipeline: the n-th `with` fills the n-th argument of
`Fields` and of `Values`, so a field that is declared but missing from a record
(or the other way round) is a compile error. The one thing the compiler cannot
see is two fields of the same type swapped in one of the two records; put
`Form.Check.roundTrip` in one test to catch that.

**What a rule does to the type.** `required` turns `Maybe a` into `a`, so
`Values.country : CountryId` cannot be given a `Maybe`; `atLeast 1` keeps a list;
`one` turns a list into a `Maybe`. A kind that cannot be empty (`toggle`) has no
`required`.

**Quick path.** `define`, `with`, `build`, the kind of each field (`text`,
`choice`, `choices` ...) and `required` or `atLeast` cover a form. `step` makes it
a wizard; `rows` declares a repeating group; `check` adds a rule over several
fields or rows.

## What the compiler says

The declaration is the one place where the types are a little long (`Form step
fields values`, `Builder step fields values`, `Spec control output`), so the
messages are worth knowing. They were produced on purpose, one mistake at a time.
The names below are the ones the compiler prints.

| The compiler says | It means |
|---|---|
| `Spec.Builder step Fields (Country -> Values)` where `Spec.Builder step (Form.Field (Maybe Country) -> f) (Country -> Values)` is wanted, at the last `with` | The last field has no slot in `Fields` (or, the other way round, in `Values`): the record is shorter than the pipeline. The slot named in the type is the field that is missing |
| The body is `Form.Form () (Form.Field (Maybe Country) -> Fields) (Country -> Values)`, the annotation says `Form.Form () Fields Values` | A field is in both records but not in the pipeline: a `with` is missing. The unfilled slots in the type say which field |
| `Spec.Builder step (Form.Field (Maybe Country) -> Form.Field String -> Fields) ...` where `Spec.Builder step (Form.Field String -> f) (Maybe String -> v)` is wanted | Two differently typed fields are in another order in the records than in the pipeline: the n-th `with` fills the n-th slot. The compiler's hint ("takes too many arguments") points the wrong way; reorder the records |
| `... (Maybe Country -> Values)` where `... (Country -> v)` is wanted | `Values` says `Maybe Country` for a field that is `required`: `required` takes the `Maybe` away. The hint "use Maybe.withDefault" is not the fix |
| `Form.Field String` where `Form.Field (Maybe id)` is wanted, at `Form.select` | A text handle was given to a select (or the other way round): the type of a handle is the kind of its control |
| `Form.Field (Form.Rows ContactFields)` where `Form.Field String` is wanted | A handle of a group of rows was given to a text input: draw the rows with `Form.rowFields` and the fields of each |
| The body is `Spec.Builder step Fields Values`, the annotation says `Form.Form () Fields Values` | `build` is missing at the end |
| `Spec.Spec Bool Bool` where `Spec.Spec Bool (Maybe a)` is wanted | `required` on a kind that cannot be empty (a `toggle`) |
| `values -> Spec.Builder step (Form.Field String -> Fields) values` | A form with one field was given only `Fields`: `define` takes both record constructors (`Spec.define "p" identity identity` for a single value) |
| `Spec.Builder step (Form.Field String -> Fields) ...` where `Spec.Builder step { a \| nickname : Form.Field c } ...` is wanted, at `Spec.check` | `check` comes before the last `with`: it must be the last step of the pipeline, because it needs every handle |

The one mistake the compiler cannot see is two fields of the same type swapped in
`Fields` or in `Values`; `Form.Check.roundTrip` catches it in one test line. A
repeated label gets the next free DOM id (`name`, `name-2`), so two fields never
clash; the prefix is the one thing that must be different for every form on a page.

## A step you draw yourself

A step with no `with` after it, in the middle of the form, has no fields of the
form: you draw what is on it. The form still owns the step (the stepper, Next and
Back, the focus when the step is entered, the red mark when something on it is
wrong), and `Form.summary` still goes at the top, where it draws an empty region
the focus can land on. What the form cannot see, give it as problems with
`Form.outside`, on this step. Only the **last** step with no fields is the review
step, whose summary lists every problem of every step.

    type Step
        = Company
        | Pricing
        | Review

    type alias Fields =
        { name : Form.Field String }

    type alias Values =
        { name : String }

    form : Form.Form Step Fields Values
    form =
        Spec.define "supplier" Fields Values
            |> Spec.step Company "Company"
            |> Spec.with (Spec.text "Name" |> Spec.required)
            |> Spec.step Pricing "Pricing rules"
            |> Spec.step Review "Review"
            |> Spec.build

    viewPricing : (Form.Msg -> msg) -> Form.State Step -> Html msg -> Html msg
    viewPricing toMsg state editor =
        Html.div []
            [ Form.summary (Form.bind Locale.default toMsg form state)
            , editor
            ]

    withEditorProblems : List (Form.Problem Step) -> Form.State Step -> Form.State Step
    withEditorProblems found =
        Form.outside form found

Each problem you give names its `step` (`Just Pricing`) and the DOM id the focus
goes to. When the thing you draw is a list of rules, prefer `rows` with
`conditions`: the form then owns the list as well.

## Declaring a form

### `Builder`

```elm
type alias Builder step fields values = Form.Core.Builder step fields values
```

The declaration while it is being built with `with`. Start it with `define`
and finish it with `build`.

### `define`

```elm
define : String -> fields -> values -> Builder step fields values
```

Starts a declaration. The text is the prefix of the DOM ids of the fields
(`"supplier"` gives `supplier-name`, `supplier-legal-name` ...) and of the
summary; it must be different for every form on the page. The other two
arguments are the record constructors `Fields` and `Values`. (A form that is
only used as the rows of another form gets its prefix from the group: the text
is not used.)

    Spec.define "supplier" Fields Values
        |> Spec.with (Spec.text "Name")
        |> Spec.build

### `with`

```elm
with :
    Spec control output
    -> Builder step (Form.Field control -> f) (output -> v)
    -> Builder step f v
```

Adds the next field. It fills the next argument of `Fields` with its handle
and the next argument of `Values` with its output. The DOM id is made from the
form's prefix and the label (`Legal name` becomes `supplier-legal-name`); a
repeated label gets `-2`, `-3` ... so two ids never clash.

### `step`

```elm
step : step -> String -> Builder step fields values -> Builder step fields values
```

The fields that follow are on this step. The step is a value of the
application's own type, and the text is its label in the stepper and in the
review list. Declare the steps in order, before their fields. The last step,
when it has no fields of its own, is the review step: its summary lists every
problem of every step. A step with no fields in the middle is one you draw
yourself (see "A step you draw yourself" above).

    Spec.define "supplier" Fields Values
        |> Spec.step Company "Company"
        |> Spec.with (Spec.text "Name" |> Spec.required)
        |> Spec.step Review "Review"
        |> Spec.build

### `check`

```elm
check :
    (fields -> Form.State step -> values -> List (Form.Problem step))
    -> Builder step fields values
    -> Builder step fields values
```

A rule over several fields, run when every field of the form is valid on its
own. On a form with steps that means it shows up when the last step is reached;
a rule that belongs to one step goes on the field (`rule`, for a list of rows) or
on the sub-form of a group, which is checked row by row. It
gets the handles, the state (to find the rows of a group with `rowFields`) and
the values, and returns the problems it finds, each tied to a field with
`problem`. Put it last, after the `with` calls: it is a compile error before.

    Spec.define "supplier" Fields Values
        |> Spec.with (Spec.rows { label = "Contacts", item = "Contact" } contact)
        |> Spec.check
            (\f state _ ->
                Form.rowFields f.contacts state
                    |> List.filter (\row -> Form.get row.primary state)
                    |> List.drop 1
                    |> List.map (\row -> Form.problem row.primary "Only one contact can be the primary.")
            )
        |> Spec.build

### `checkFields`

```elm
checkFields :
    (Locale.Locale -> fields -> Form.State step -> List (Form.Problem step))
    -> Builder step fields values
    -> Builder step fields values
```

A rule over several fields that runs at once, without waiting for the rest of
the form: "the end date is after the start date", "the confirmation matches the
email". It gets the locale, the handles and the state, reads the fields with
`Form.get` (so it sees `Nothing` for an empty field, and then says nothing), and
returns the problems it finds, each tied to a field with `Form.problem`. A
problem belongs to the step of its field: it shows there once the field was left
or edited, and it keeps the user on that step. Use `check` instead for a rule
that needs the whole record of values. Put it after the `with` calls.

    Spec.define "booking" Fields Values
        |> Spec.with (Spec.date "From" |> Spec.required)
        |> Spec.with (Spec.date "To" |> Spec.required)
        |> Spec.checkFields
            (\locale f state ->
                case ( Form.get f.from state, Form.get f.to state ) of
                    ( Just from, Just to ) ->
                        if Date.compare to from == LT then
                            [ Form.problem f.to (Locale.pick locale { nb = "Til kan ikke være før fra", en = "To cannot be before from" }) ]

                        else
                            []

                    _ ->
                        []
            )
        |> Spec.build

### `shownWhen`

```elm
shownWhen :
    (fields -> Form.State step -> Bool)
    -> (fields -> Form.Field c)
    -> Builder step fields values
    -> Builder step fields values
```

The field is part of the form only while the condition holds: a VAT number
for a company, a delivery address when "ship elsewhere" is on. While it does not,
the field is not drawn (its view is empty), its problems are left out, and the
values get its empty value (`Nothing`, `[]`, `False`), whatever was typed in
it. What was typed is kept, so it comes back when the condition holds again.
Declare such a field without `required`, so that its output can be empty, and add
`requiredWhen` with the same condition to require it while it is shown. Put it
after the `with` calls, like `check`; in the sub-form of `rows` it works row by
row. A hidden field is empty for everyone, also for the conditions of other
fields: a field shown only when a hidden field is filled in is hidden too.

A field whose empty value breaks its own rules (`required`, `atLeast`, a `rule`
that wants a ticked box) cannot be hidden: while it is, `toValues` fails with its
problem, though the screen shows none. `Check.failingWhenHidden` finds such a
field in a test.

    Spec.define "customer" Fields Values
        |> Spec.with (Spec.choice kindIds "Customer kind" |> Spec.required)
        |> Spec.with (Spec.masked MaskedInput.norwegianOrganisationNumber "Organisation number")
        |> Spec.shownWhen isCompany .organisationNumber
        |> Spec.requiredWhen isCompany .organisationNumber
        |> Spec.build

    isCompany : Fields -> Form.State () -> Bool
    isCompany handles state =
        Form.get handles.kind state == Just Company

### `requiredWhen`

```elm
requiredWhen :
    (fields -> Form.State step -> Bool)
    -> (fields -> Form.Field c)
    -> Builder step fields values
    -> Builder step fields values
```

The field is required while the condition holds: it gets the `*` of a
required field, and an empty value is the problem "Required". Its output keeps
its type, so declare it without `required`. Put it after the `with` calls; see
`shownWhen` for an example.

### `build`

```elm
build : Builder step fields values -> Form.Form step fields values
```

Finishes the declaration. The result only has the type
`Form step Fields Values` when every `with` matched an argument of both records;
a field missing from one of them is a compile error.

## Kinds of field

A kind says what the field holds and what the form produces. Every kind takes a
label; it is the label of the control, the line in the summary and the base of
the DOM id.

### `Spec`

```elm
type alias Spec control output = Form.Core.Spec control output
```

One field's kind, label and rules, as built by `text`, `number`, `choice`
and the others and changed by the rules. `control` is the type of the value
while it is edited, `output` the type the form produces: `required` turns a
`Maybe a` output into `a`.

### `text`

```elm
text : String -> Spec String (Maybe String)
```

A line of text. Blank is `Nothing` in the output, and the output is trimmed
(the display is not: nothing is changed behind the user's back). Add `required`
to get a `String`. Draw it with `textInput`, or with `textArea` for a long note.

### `number`

```elm
number : String -> Spec (Maybe Float) (Maybe Float)
```

A number. Empty is `Nothing`. Add `required`, `range` or `whole`.

### `choice`

```elm
choice : Ids.Ids id -> String -> Spec (Maybe id) (Maybe id)
```

One of the application's values, chosen in a `select`. Empty is `Nothing`.
Add `required` to get the id itself.

The options are given where the form is drawn (`Form.select`), so they may come from
a database, each with its own color: `Select.withColor` and `Select.withTone` show a dot
in the list and in the field.

### `choices`

```elm
choices : Ids.Ids id -> String -> Spec (List id) (List id)
```

Several of the application's values, chosen in a `multiSelect`, in the order
they were chosen. The chips show the color of an option that has one. Empty is `[]`. Add `atLeast 1` to make it required.

### `toggle`

```elm
toggle : String -> Spec Bool Bool
```

An on/off choice, drawn by `switch`. Off is the empty value.

### `date`

```elm
date : String -> Spec (Maybe Date.Date) (Maybe Date.Date)
```

A date, typed or picked in a calendar, drawn by `Form.datePicker`. Empty is
`Nothing`; add `required`, `minDate` or `maxDate`. Text that is not a date is
the problem "Invalid date" until it is fixed. The value is a
[`Date`](Klar.Date.md), never a `String`.

    Spec.date "Delivery date" |> Spec.required |> Spec.minDate firstDeliveryDay

### `dateRange`

```elm
dateRange : String -> Spec (Maybe ( Date.Date, Date.Date )) (Maybe ( Date.Date, Date.Date ))
```

A period from one date to another, both included, drawn by
`Form.dateRangePicker`. Empty is `Nothing`; add `required`. Text that is not a
date, or a period the picker refuses (an end before the start, longer than
`DateRangePicker.maxRangeDays`), is the problem "Invalid period" until it is
fixed. The earliest and latest day are attributes of the picker.

    Spec.dateRange "Campaign period" |> Spec.required

### `money`

```elm
money : Money.Currency -> String -> Spec (Maybe Money.Money) (Maybe Money.Money)
```

An amount of money in one currency, drawn by `Form.moneyInput`. The value is
an exact [`Money`](Klar.Money.md), never a `Float`. Empty is `Nothing`; add
`required`, `minMoney` or `maxMoney`. Text that is not an amount is the problem
"Must be an amount", and a negative amount is refused unless `minMoney` is below
zero (as in `MoneyInput`).

    Spec.money Money.nok "Credit limit"
        |> Spec.required
        |> Spec.maxMoney creditCeiling

### `masked`

```elm
masked : MaskedInput.Mask -> String -> Spec (Maybe String) (Maybe String)
```

An identifier with a fixed shape and often a check digit (an organisation
number, an IBAN, a bank account, a postal code, a phone number), drawn by
`Form.maskedInput`. The value is the identifier without separators, as
`MaskedInput.value` gives it (`"974760673"`); empty is `Nothing`; add `required`.
An identifier that is incomplete or has a wrong check digit is the problem
"Incomplete or invalid" until it is fixed (the field itself says what is wrong).

    Spec.masked MaskedInput.norwegianOrganisationNumber "Organisation number" |> Spec.required

### `tags`

```elm
tags : String -> Spec (List String) (List String)
```

Free-form tags, drawn by `tagInput`: type a word, press Enter, get a chip. The
order is the order they were added. Empty is `[]`. Add `atLeast 1` to make it
required, and give the delimiters, the limit and a rule for a single tag to the
view (`TagInput.delimiters`, `TagInput.maxTags`, `TagInput.validate`).

    Spec.tags "Certifications" |> Spec.atLeast 1

### `files`

```elm
files : String -> Spec (List FileDrop.FileInfo) (List FileDrop.FileInfo)
```

Files the user chose or dropped, drawn by `fileDrop`. Empty is `[]`. Files the
drop zone refused (wrong type, too large) are not in the value; while one of
them is still listed the field has the problem "Remove the refused file". Add
`atLeast 1` to require a file, or `one` for a single file (`one |> required`
for a file that must be there). The size and type limits belong to the view
(`FileDrop.accept`, `FileDrop.maxSize`). The value is the name, size and type of
each file; the browser's own `File` values, for the request you make, are
`Form.rawFiles`.

    Spec.files "Signed contract" |> Spec.one |> Spec.required

### `conditions`

```elm
conditions : String -> List (Rule.Field ()) -> Spec Rule.Rule (Maybe Rule.Rule)
```

The conditions of a rule, edited in a rule builder and drawn with
`Form.ruleBuilder`: "if the category is X and the quantity is above Y". The value
is a [`Rule`](Klar.Rule.md); empty (no condition) is `Nothing`, and `required`
asks for at least one. The fields say what a rule can talk about and are used to
check it (`RuleBuilder.issues`), so a rule with an unfinished condition is a
problem of the field; the choices' options are not read there, so the declaration
can hold the fields without them and the view the same fields with the options
that have arrived.

    Spec.conditions "Conditions" (priceFields [])
        |> Spec.required
        |> Spec.withMessage (\locale -> Locale.pick locale { nb = "Legg til en betingelse", en = "Add a condition" })

The usual place is the row of a group: the conditions of a price rule next to the
outcome it gives, so that adding, removing, dirty, problems and the focus
are the form's (see `rows`).

### `rows`

```elm
rows :
    { label : String, item : String }
    -> Form.Form () rowFields rowValues
    -> Spec (Form.Rows rowFields) (List rowValues)
```

A repeating group, such as the contacts of a supplier: every row has the
fields of the form you give, declared once. The `label` names the group (in the
summary, "Add at least 1" and the like), the `item` names one row ("Contact":
the summary says "Contact 2, Email: Required" and the remove button "Remove
contact 2"). The output is the list of the rows' values, in the order of the
rows. `atLeast n` requires n rows and starts the form with n empty rows. Draw
the rows with `rowFields`, the buttons with `addRow` and `removeRow`.

    contact : Form.Form () ContactFields Contact
    contact =
        Spec.define "contact" ContactFields Contact
            |> Spec.with (Spec.text "Name" |> Spec.required)
            |> Spec.with (Spec.text "Email" |> Spec.required |> Spec.rules [ Validate.email ])
            |> Spec.build

    Spec.rows { label = "Contacts", item = "Contact" } contact |> Spec.atLeast 1

**Keys of the rows.** Every row gets a number when it is added, and the number
stays with the row for as long as it lives: `supplier-contacts-3-email` is the
same row's field after rows 1 and 2 are removed, and a number is never used
twice. Positions ("Contact 2") are only for the words and for problems from the
server. This keeps the state of a select or tag field with its row, makes a
removed row's problems go with it, and lets an application keep a handle.

## Rules

### `required`

```elm
required : Spec c (Maybe a) -> Spec c a
```

The field must have a value: the output loses its `Maybe`. A text must not
be blank, a choice must be made. The label gets the `*` of a required field.

    Spec.text "Name" |> Spec.required -- Spec String String

### `atLeast`

```elm
atLeast : Int -> Spec c (List a) -> Spec c (List a)
```

A list with at least this many items. It is required, and the message says
how many. On a `rows` group it also starts the form with that many empty rows.

    Spec.choices categoryIds "Categories" |> Spec.atLeast 1

### `one`

```elm
one : Spec c (List a) -> Spec c (Maybe a)
```

At most one item: the output is `Maybe a` instead of a list.

### `rule`

```elm
rule : (o -> Bool) -> (Locale.Locale -> String) -> Spec c o -> Spec c o
```

A rule on the value the field produces, for what the kind and the other rules
cannot say: a quantity in whole boxes of 6, a box that must be ticked, at most one
contact that is the primary. It runs when the field's own read succeeded (after
`required`, a refused text and the other rules), and its problem is the field's
own: it shows at the field and counts on the field's step, so a rule of step 1
shows on step 1. On a group of rows it sees the list of the rows' values, and
its problem shows by the add button. The message is a function of the locale,
like `withMessage`.

    Spec.toggle "I accept the terms of delivery"
        |> Spec.rule identity
            (\lang -> Locale.pick lang { nb = "Du må godta vilkårene", en = "Accept the terms to go on" })

    Spec.number "Quantity"
        |> Spec.required
        |> Spec.rule (\n -> modBy 6 (round n) == 0)
            (\lang -> Locale.pick lang { nb = "Bestill i hele esker à 6", en = "Order in whole boxes of 6" })

    Spec.rows { label = "Contacts", item = "Contact" } contact
        |> Spec.rule
            (\contacts -> List.length (List.filter .primary contacts) <= 1)
            (\lang -> Locale.pick lang { nb = "Bare én kan være hovedkontakt", en = "Only one contact can be the primary" })

### `rules`

```elm
rules : List Validate.Validator -> Spec String o -> Spec String o
```

The existing validators of [Klar.Validate](Klar.Validate.md) on a text, run on
the text as typed. The first problem wins. A blank text passes every rule, also
`Validate.custom` and `Validate.required`: an optional field that is left empty
is fine, and a field that must be filled in says so with `required`, not with
a rule.

    Spec.text "Name" |> Spec.required |> Spec.rules [ Validate.maxLength 80 ]

### `range`

```elm
range : Float -> Float -> Spec (Maybe Float) o -> Spec (Maybe Float) o
```

A number from `low` to `high`, both included. The control shows the limits
and keeps a number outside them as typed (it shows the problem, it does not move
the number). The message writes the numbers as the locale does ("Må være mellom
0,5 og 1,5").

### `whole`

```elm
whole : Spec (Maybe Float) o -> Spec (Maybe Float) o
```

A whole number: no decimals, shown and checked.

### `minDate`

```elm
minDate : Date.Date -> Spec (Maybe Date.Date) o -> Spec (Maybe Date.Date) o
```

The earliest date a `date` field takes, included. The calendar does not offer
the days before it, a typed date before it is refused at once, and a date put in
with `Form.set` (a loaded record) is the problem "The date cannot be before ..."
until it is changed. The declaration is a constant, so a limit that depends on
today is an attribute of the view instead: `DatePicker.min model.today`.

    Spec.date "Delivery date" |> Spec.minDate firstDeliveryDay

### `maxDate`

```elm
maxDate : Date.Date -> Spec (Maybe Date.Date) o -> Spec (Maybe Date.Date) o
```

The latest date a `date` field takes, included, in the same way as
`minDate`.

### `minMoney`

```elm
minMoney : Money.Money -> Spec (Maybe Money.Money) o -> Spec (Maybe Money.Money) o
```

The lowest amount a `money` field takes, included, in the currency of the
field. An amount below it is kept as typed and is the problem "Must be at least
...". A lowest amount below zero allows negative amounts down to it; without
one, an amount must not be negative.

    Spec.money Money.nok "Correction" |> Spec.minMoney largestRefund

### `maxMoney`

```elm
maxMoney : Money.Money -> Spec (Maybe Money.Money) o -> Spec (Maybe Money.Money) o
```

The highest amount a `money` field takes, included, in the same way as
`minMoney`.

### `hint`

```elm
hint : String -> Spec c o -> Spec c o
```

A short help text under the field. A later `withMessage` keeps it.

### `serverKey`

```elm
serverKey : String -> Spec c o -> Spec c o
```

The server's field key for save rejections. Defaults to the label's local
key, without the form prefix (`Email` becomes `email`). It changes no DOM id.
Use it when the backend calls a field something else, such as `email_address`.
`Form.finish` matches only an unambiguous key; unknown or ambiguous keys remain
in the summary. Repeated rows can be addressed by their handles' `Form.domId`.

### `withMessage`

```elm
withMessage : (Locale.Locale -> String) -> Spec c o -> Spec c o
```

Replaces the message of the rule that was added last, in every language: a
function from the locale to the text, so the declaration (a constant) does not
fix the set of languages.

    Spec.text "Name"
        |> Spec.required
        |> Spec.withMessage (\locale -> Locale.pick locale { nb = "Oppgi navn", en = "Enter a name" })
