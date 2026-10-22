module Klar.Form.Spec exposing
    ( Builder, define, with, step, check, build
    , Spec, text, number, choice, choices, toggle, tags, files, conditions, rows
    , required, atLeast, one, rule, rules, range, whole, hint, withMessage
    )

{-| The declaration of a form: its fields in order, each with a label and its
rules, grouped in steps. It is read once, at the top of the file that owns the
form, and it is a constant: it never goes in a model or a message. What is
declared here is used through [`Klar.Form`](Klar-Form).

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


# What the compiler says

The declaration is the one place where the types are a little long (`Form step
fields values`, `Builder step fields values`, `Spec control output`), so the
messages are worth knowing. They were produced on purpose, one mistake at a time,
and are kept with their full output in
[design/FORM-MODEL-ERRORS.md](https://github.com/davidtoska/elm-klar/blob/main/design/FORM-MODEL-ERRORS.md).
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


# A step you draw yourself

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


# Declaring a form

@docs Builder, define, with, step, check, build


# Kinds of field

A kind says what the field holds and what the form produces. Every kind takes a
label; it is the label of the control, the line in the summary and the base of
the DOM id.

@docs Spec, text, number, choice, choices, toggle, tags, files, conditions, rows


# Rules

@docs required, atLeast, one, rule, rules, range, whole, hint, withMessage

-}

import Klar.FileDrop as FileDrop
import Klar.Form as Form
import Klar.Form.Core as Core
import Klar.Ids exposing (Ids)
import Klar.Locale exposing (Locale)
import Klar.Rule as Rule
import Klar.Validate as Validate



-- TYPES


{-| The declaration while it is being built with `with`. Start it with `define`
and finish it with `build`.
-}
type alias Builder step fields values =
    Core.Builder step fields values


{-| One field's kind, label and rules, as built by `text`, `number`, `choice`
and the others and changed by the rules. `control` is the type of the value
while it is edited, `output` the type the form produces: `required` turns a
`Maybe a` output into `a`.
-}
type alias Spec control output =
    Core.Spec control output



-- DECLARING


{-| Starts a declaration. The text is the prefix of the DOM ids of the fields
(`"supplier"` gives `supplier-name`, `supplier-legal-name` ...) and of the
summary; it must be different for every form on the page. The other two
arguments are the record constructors `Fields` and `Values`. (A form that is
only used as the rows of another form gets its prefix from the group: the text
is not used.)

    Spec.define "supplier" Fields Values
        |> Spec.with (Spec.text "Name")
        |> Spec.build

-}
define : String -> fields -> values -> Builder step fields values
define =
    Core.define


{-| Adds the next field. It fills the next argument of `Fields` with its handle
and the next argument of `Values` with its output. The DOM id is made from the
form's prefix and the label (`Legal name` becomes `supplier-legal-name`); a
repeated label gets `-2`, `-3` ... so two ids never clash.
-}
with : Spec control output -> Builder step (Form.Field control -> f) (output -> v) -> Builder step f v
with =
    Core.with


{-| The fields that follow are on this step. The step is a value of the
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

-}
step : step -> String -> Builder step fields values -> Builder step fields values
step =
    Core.step


{-| A rule over several fields, run when every field of the form is valid on its
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

-}
check : (fields -> Form.State step -> values -> List (Form.Problem step)) -> Builder step fields values -> Builder step fields values
check =
    Core.check


{-| Finishes the declaration. The result only has the type
`Form step Fields Values` when every `with` matched an argument of both records;
a field missing from one of them is a compile error.
-}
build : Builder step fields values -> Form.Form step fields values
build =
    Core.build



-- KINDS


{-| A line of text. Blank is `Nothing` in the output, and the output is trimmed
(the display is not: nothing is changed behind the user's back). Add `required`
to get a `String`. Draw it with `textInput`, or with `textArea` for a long note.
-}
text : String -> Spec String (Maybe String)
text =
    Core.text


{-| A number. Empty is `Nothing`. Add `required`, `range` or `whole`.
-}
number : String -> Spec (Maybe Float) (Maybe Float)
number =
    Core.number


{-| One of the application's values, chosen in a `select`. Empty is `Nothing`.
Add `required` to get the id itself.
-}
choice : Ids id -> String -> Spec (Maybe id) (Maybe id)
choice =
    Core.choice


{-| Several of the application's values, chosen in a `multiSelect`, in the order
they were chosen. Empty is `[]`. Add `atLeast 1` to make it required.
-}
choices : Ids id -> String -> Spec (List id) (List id)
choices =
    Core.choices


{-| An on/off choice, drawn by `switch`. Off is the empty value.
-}
toggle : String -> Spec Bool Bool
toggle =
    Core.toggle


{-| Free-form tags, drawn by `tagInput`: type a word, press Enter, get a chip. The
order is the order they were added. Empty is `[]`. Add `atLeast 1` to make it
required, and give the delimiters, the limit and a rule for a single tag to the
view (`TagInput.delimiters`, `TagInput.maxTags`, `TagInput.validate`).

    Spec.tags "Certifications" |> Spec.atLeast 1

-}
tags : String -> Spec (List String) (List String)
tags =
    Core.tags


{-| Files the user chose or dropped, drawn by `fileDrop`. Empty is `[]`. Files the
drop zone refused (wrong type, too large) are not in the value; while one of
them is still listed the field has the problem "Remove the refused file". Add
`atLeast 1` to require a file, or `one` for a single file (`one |> required`
for a file that must be there). The size and type limits belong to the view
(`FileDrop.accept`, `FileDrop.maxSize`).

    Spec.files "Signed contract" |> Spec.one |> Spec.required

-}
files : String -> Spec (List FileDrop.FileInfo) (List FileDrop.FileInfo)
files =
    Core.files


{-| The conditions of a rule, edited in a rule builder and drawn with
`Form.ruleBuilder`: "if the category is X and the quantity is above Y". The value
is a [`Rule`](Klar-Rule); empty (no condition) is `Nothing`, and `required`
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

-}
conditions : String -> List (Rule.Field ()) -> Spec Rule.Rule (Maybe Rule.Rule)
conditions =
    Core.conditions


{-| A repeating group, such as the contacts of a supplier: every row has the
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

-}
rows : { label : String, item : String } -> Form.Form () rowFields rowValues -> Spec (Form.Rows rowFields) (List rowValues)
rows =
    Core.rows



-- RULES


{-| The field must have a value: the output loses its `Maybe`. A text must not
be blank, a choice must be made. The label gets the `*` of a required field.

    Spec.text "Name" |> Spec.required -- Spec String String

-}
required : Spec c (Maybe a) -> Spec c a
required =
    Core.required


{-| A list with at least this many items. It is required, and the message says
how many. On a `rows` group it also starts the form with that many empty rows.

    Spec.choices categoryIds "Categories" |> Spec.atLeast 1

-}
atLeast : Int -> Spec c (List a) -> Spec c (List a)
atLeast =
    Core.atLeast


{-| At most one item: the output is `Maybe a` instead of a list.
-}
one : Spec c (List a) -> Spec c (Maybe a)
one =
    Core.one


{-| A rule over the whole list of a list-valued field, for what is wrong with the
items _together_: at most one contact is the primary, two emails are the same.
It runs when every item is valid on its own, and a problem is the field's own
(a group of rows shows it by its add button and in the summary), so it counts on
its step like any other rule. The message is a function of the locale, like
`withMessage`.

    Spec.rows { label = "Contacts", item = "Contact" } contact
        |> Spec.rule
            (\contacts -> List.length (List.filter .primary contacts) <= 1)
            (\lang -> Locale.pick lang { nb = "Bare én kan være hovedkontakt", en = "Only one contact can be the primary" })

-}
rule : (List a -> Bool) -> (Locale -> String) -> Spec c (List a) -> Spec c (List a)
rule =
    Core.rule


{-| The existing validators of [Klar.Validate](Klar-Validate) on a text, run on
the text as typed. The first problem wins. A blank text passes every rule, also
`Validate.custom` and `Validate.required`: an optional field that is left empty
is fine, and a field that must be filled in says so with `required`, not with
a rule.

    Spec.text "Name" |> Spec.required |> Spec.rules [ Validate.maxLength 80 ]

-}
rules : List Validate.Validator -> Spec String o -> Spec String o
rules =
    Core.rules


{-| A number from `low` to `high`, both included. The control shows the limits
and keeps a number outside them as typed (it shows the problem, it does not move
the number).
-}
range : Float -> Float -> Spec (Maybe Float) o -> Spec (Maybe Float) o
range =
    Core.range


{-| A whole number: no decimals, shown and checked.
-}
whole : Spec (Maybe Float) o -> Spec (Maybe Float) o
whole =
    Core.whole


{-| A short help text under the field.
-}
hint : String -> Spec c o -> Spec c o
hint =
    Core.hint


{-| Replaces the message of the rule that was added last, in every language: a
function from the locale to the text, so the declaration (a constant) does not
fix the set of languages.

    Spec.text "Name"
        |> Spec.required
        |> Spec.withMessage (\locale -> Locale.pick locale { nb = "Oppgi navn", en = "Enter a name" })

-}
withMessage : (Locale -> String) -> Spec c o -> Spec c o
withMessage =
    Core.withMessage
