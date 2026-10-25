module Klar.Form exposing
    ( Form, State, Msg, Field, Rows, Problem, View
    , fields
    , init, set, setOption, get, query, rawFiles, rowFields, fillRows, toValues, isDirty, markClean, revert, update
    , problems, hasProblems, outside, problem, problemInRow, rejected, reveal, focus, domId, goToProblem
    , currentStep, attempted, advance, back, goTo
    , bind, textInput, textArea, numberInput, select, multiSelect, radio, switch, checkbox, datePicker, dateRangePicker, moneyInput, maskedInput, tagInput, fileDrop, ruleBuilder, addRow, removeRow, stepper, stepBody, summary
    )

{-| A form as one value: the text and choices of every field, which fields the
user has left, what the server refused, the rows of a repeating group, the step
the user is on, and whether anything has changed. You declare the form once with
[`Klar.Form.Spec`](Klar-Form-Spec), keep one [`State`](#State) in your model and
one [`Msg`](#Msg) in your messages, and draw each control with one call. The
application never writes a DOM id, a component state per field, a dirty test, a
"validate before Next" or a second copy of the server's problems.

Use when: you edit a record in a form and want the values, rules, steps and server problems kept in one state.
Do not use when: the form is hand-wired or only needs a frame (use `Klar.Form.Layout`), or one value saves by itself (use `Klar.InlineEdit`).
Quick path: `init`, `bind`, `update`, `toValues`, `summary`, `rejected`

Use it for an edit form, a sign-up, a wizard with a review step, a form with a
repeating group (the contacts of a supplier). For one value that saves by itself
use [`Klar.InlineEdit`](Klar-InlineEdit); for the frame around a form (sections,
the button row, the status of the save) use
[`Klar.Form.Layout`](Klar-Form-Layout), which this module is built on and which
a hand-written form can use alone.

| Module | Is for |
|---|---|
| `Klar.Form.Spec` | declaring the form: the fields, their rules, the steps (read once, at the top of a file) |
| `Klar.Form` | using it: state, update, problems, steps, the controls |
| `Klar.Form.Layout` | the frame: sections, grid, button row, status, unsaved mark |
| `Klar.Form.Check` | tests: the round trip of a record, the keys of an id type |
| `Klar.Ids` | how your id types are written as text, once |


# Quick path

Six functions cover a form: `init` (the state), `bind` (once per view), `update`
(one branch for every control), `toValues` (the record, or the problems),
`summary` (the list of problems) and `rejected` (what the server refused).
`reveal` shows the problems after a Save that found some. A form with steps adds
`advance` and `stepper`; one with repeating groups adds `rowFields`, `addRow` and
`removeRow`.

A customer form with a text, a country, a long note and a switch, a save that
the server can refuse, and the mark for unsaved changes. The model keeps one
`Form.State`, the message has one `Form.Msg`, and the view is one call for each
control:

    -- THE DECLARATION
    type CountryId
        = CountryId String

    countryIds : Ids CountryId
    countryIds =
        Ids.make { toKey = \(CountryId code) -> code, fromKey = Just << CountryId }

    type alias Fields =
        { name : Form.Field String
        , country : Form.Field (Maybe CountryId)
        , note : Form.Field String
        , preferred : Form.Field Bool
        }

    type alias Values =
        { name : String
        , country : CountryId
        , note : Maybe String
        , preferred : Bool
        }

    form : Form.Form () Fields Values
    form =
        Spec.define "customer" Fields Values
            |> Spec.with (Spec.text "Name" |> Spec.required |> Spec.rules [ Validate.maxLength 80 ])
            |> Spec.with (Spec.choice countryIds "Country" |> Spec.required)
            |> Spec.with (Spec.text "Note" |> Spec.rules [ Validate.maxLength 500 ])
            |> Spec.with (Spec.toggle "Preferred customer")
            |> Spec.build

    fields : Fields
    fields =
        Form.fields form

    -- THE MODEL AND THE UPDATE
    type alias Model =
        { form : Form.State ()
        , status : FormLayout.Status
        }

    type Msg
        = FormMsg Form.Msg
        | Save
        | Replied (List (Form.Problem ()))

    init : Model
    init =
        { form = Form.init form, status = FormLayout.Idle }

    update : Msg -> Model -> ( Model, Cmd Msg )
    update msg model =
        case msg of
            FormMsg inner ->
                Form.update form inner model.form
                    |> Tuple.mapBoth (\state -> { model | form = state }) (Cmd.map FormMsg)

            Save ->
                if model.status == FormLayout.Submitting then
                    -- Enter in a field submits too: one request at a time
                    ( model, Cmd.none )

                else
                    case Form.toValues Locale.default form model.form of
                        Ok values ->
                            ( { model | status = FormLayout.Submitting }, send values )

                        Err _ ->
                            Form.reveal form model.form
                                |> Tuple.mapBoth (\state -> { model | form = state }) (Cmd.map FormMsg)

            Replied [] ->
                ( { model | form = Form.markClean model.form, status = FormLayout.Succeeded "Saved." }, Cmd.none )

            Replied found ->
                Form.rejected found form model.form
                    |> Tuple.mapBoth (\state -> { model | form = state, status = FormLayout.Idle }) (Cmd.map FormMsg)

    -- your request to the server; this package has no HTTP
    send : Values -> Cmd Msg
    send _ =
        Cmd.none

    -- THE VIEW
    view : Model -> Html Msg
    view model =
        let
            v =
                Form.bind Locale.default FormMsg form model.form
        in
        FormLayout.view [ FormLayout.id "customer", FormLayout.onSubmit Save ]
            [ Form.summary v
            , FormLayout.section "Customer"
                "Who the invoice is for."
                [ FormLayout.grid 2
                    [ Form.textInput v fields.name []
                    , Form.select v fields.country (Remote.Loaded countries) []
                    , FormLayout.fullRow (Form.textArea v fields.note [ TextArea.rows 3 ])
                    , Form.switch v fields.preferred []
                    ]
                ]
            , FormLayout.unsavedFlag [] (Form.isDirty model.form)
            , FormLayout.actions
                [ FormLayout.status [ FormLayout.id "customer" ] model.status
                , Layout.spacer
                , Button.view [ Button.primary, Button.submit ] "Save"
                ]
            ]

    countries : List (Select.Option CountryId)
    countries =
        [ Select.option (CountryId "no") "Norway"
        , Select.option (CountryId "se") "Sweden"
        ]

The state also has no function in it, nor has the message, so the model can be
compared, stored and tested. `Form.isDirty model.form` is the flag for
`FormLayout.unsavedFlag` and for a leave guard.

**When a problem shows.** A field that is typed into (a text, a number, an
amount, an identifier) shows its problem once the user has left it, and from
then on follows every keystroke: "a" is not an email address yet, and the user is
not interrupted while typing it. A field that is answered at once (a choice, a
switch, a checkbox, a picked date, a tag, a file) shows its problem when it is
given. After `reveal`, `rejected` or `advance` every field shows its own; a
problem the server gave shows at once and goes away when its field is edited.
Rows and fields added later start quiet again.

**Kinds and controls.** Every value has its own kind, and the values are Klar's own
types, so nothing is parsed twice:

| Kind (`Klar.Form.Spec`) | Value | Drawn with |
|---|---|---|
| `text` | `String` | `textInput`, `textArea` |
| `number` | `Float` | `numberInput` |
| `choice` | your id type | `select`, `radio` |
| `choices` | a list of your ids | `multiSelect` |
| `toggle` | `Bool` | `switch`, `checkbox` |
| `date` | [`Date`](Klar-Date) | `datePicker` |
| `dateRange` | a pair of `Date` | `dateRangePicker` |
| `money` | [`Money`](Klar-Money) | `moneyInput` |
| `masked` | an identifier without separators | `maskedInput` |
| `tags` | a list of `String` | `tagInput` |
| `files` | a list of `FileDrop.FileInfo` | `fileDrop` |
| `conditions` | a [`Rule`](Klar-Rule) | `ruleBuilder` |
| `rows` | a list of a sub-form's values | `rowFields`, `addRow`, `removeRow` |

**Fields that depend on others.** `Spec.shownWhen` keeps a field out of the form
(not drawn, no problems, its empty value in the values) while a condition on the
other fields does not hold, and `Spec.requiredWhen` requires it while one does: a
VAT number for a company. `Spec.checkFields` is a rule over several fields that
runs at once ("the end date is after the start date"), on the step of its field;
`Spec.check` waits for the whole record.

**A choice among thousands.** Give `select` the attribute `Select.serverSearch`,
fetch the options when `query` changes, and load a saved value with `setOption`,
so its label shows before the first search.

**Steps.** Declare them with `Spec.step`; the form then owns which step the user
is on. Draw the fields of the current step inside `stepBody`: without it Elm reuses the
focused input of one step for the field at the same place in the next, and the
focus move that `advance` makes blurs it and shows "Required" on a field nobody
touched. `advance` is the whole of the Next and Save buttons, `back` of Back and
`goTo` of "Edit" on a review page, and `stepper` draws the steps with a red mark
on the ones that have problems showing. A step that is reached by clicking
forward must pass every step on the way. The last step, when it has no fields, is
the review step: its `summary` lists every problem of every step, each with a
button that goes there.

**Rows.** `Spec.rows` declares a repeating group once. Every row has a number
that stays with it while it lives, so the DOM ids, the focus and the state of a
select follow the row when another row is removed; "Contact 2" in the words is
the position.

**A rule builder in a row.** `Spec.conditions` is the kind for the conditions of a
rule, drawn with `ruleBuilder`. In a row of a group it sits next to the outcome of
the rule, so "if the category is X and the quantity is above Y, give Z % off" is one
sub-form (`conditions` and a `number`) and a list of them is `Spec.rows`: the state
of each builder follows its row, and dirty, problems, the summary and the focus are
the form's. A refused discount in the third rule is
`Form.problemInRow f.priceRules 2 .discount message`.

**Things outside the form.** Something the model does not hold, such as a rule
builder on a page of its own, gives its problems to `outside` (point their `field`
at `RuleBuilder.focusId`), and they are then in the summary, the stepper marks and
`toValues` like any other.


# Types

@docs Form, State, Msg, Field, Rows, Problem, View


# The handles

@docs fields


# Values and state

@docs init, set, setOption, get, query, rawFiles, rowFields, fillRows, toValues, isDirty, markClean, revert, update


# Problems and focus

@docs problems, hasProblems, outside, problem, problemInRow, rejected, reveal, focus, domId, goToProblem


# Steps

@docs currentStep, attempted, advance, back, goTo


# Drawing the form

@docs bind, textInput, textArea, numberInput, select, multiSelect, radio, switch, checkbox, datePicker, dateRangePicker, moneyInput, maskedInput, tagInput, fileDrop, ruleBuilder, addRow, removeRow, stepper, stepBody, summary

-}

import File exposing (File)
import Html exposing (Html)
import Klar.Button as Button
import Klar.Checkbox as Checkbox
import Klar.Date exposing (Date)
import Klar.DatePicker as DatePicker
import Klar.DateRangePicker as DateRangePicker
import Klar.FileDrop as FileDrop
import Klar.Form.Core as Core
import Klar.Locale exposing (Locale)
import Klar.MaskedInput as MaskedInput
import Klar.Money exposing (Money)
import Klar.MoneyInput as MoneyInput
import Klar.MultiSelect as MultiSelect
import Klar.NumberInput as NumberInput
import Klar.Radio as Radio
import Klar.Remote exposing (Remote)
import Klar.Rule as Rule
import Klar.RuleBuilder as RuleBuilder
import Klar.Select as Select
import Klar.Stepper as Stepper
import Klar.Switch as Switch
import Klar.TagInput as TagInput
import Klar.TextArea as TextArea
import Klar.TextInput as TextInput



-- TYPES


{-| A form declaration: the fields in order with their rules. It is a constant
(`form`), never part of the model or of a message. The three parameters are the
application's own step type (`()` for a form without steps), the record of
field handles (`Fields`) and the record the form produces (`Values`).
-}
type alias Form step fields values =
    Core.Form step fields values


{-| Everything the form keeps while it is being edited: the value of every field
(and the open list of a select), the rows of every repeating group, the baseline
for `isDirty`, which fields were left, the problems the server gave and the
current step. It is data only: there is no function in it. Make it with `init`
and keep it in the model.
-}
type alias State step =
    Core.State step


{-| What the controls of the form send. Wrap it in one constructor of the
application's message type and pass what comes back to `update`.
-}
type alias Msg =
    Core.Msg


{-| A handle to one field. The type says what the value looks like while it is
edited: `String` for a text, `Maybe id` for a choice, `List id` for several,
`Maybe Float` for a number, `Bool` for a switch or a checkbox, `Maybe Date` for a date,
`Maybe ( Date, Date )` for a period, `Maybe Money` for an amount, `Maybe String` for an
identifier, `List String` for tags, a list of files for files and a `Rule` for conditions. Get the handles from `fields form`; there is no other
way to make one.
-}
type alias Field control =
    Core.Field control


{-| The control of a repeating group (`rows`): the handles of the rows it has
now. It has no constructor, so a rows field cannot be given a value with `set`;
read the handles of the rows with `rowFields` and load them with `fillRows`.
-}
type alias Rows rowFields =
    Core.Rows rowFields


{-| A message tied to a field: the DOM id of the control (`field`), the label
the user knows the field by (`label`), what to tell the user (`message`) and,
in a form with steps, the step the field is on. `problems` lists them all.

Write one by hand for something the form model does not hold, such as the
rule builder of a price rule, and hand it to `outside`:

    { field = "price-rule-1"
    , label = "Price rule 1"
    , message = "Add at least one condition."
    , step = Just Pricing
    }

-}
type alias Problem step =
    { field : String
    , label : String
    , message : String
    , step : Maybe step
    }


{-| A form, a state and a message wrapper, bound once per view with `bind`.
Every control of the form is drawn from it.
-}
type alias View msg =
    Core.View msg



-- THE HANDLES


{-| The handles of the form's fields, as the `Fields` record. A constant: bind
it once at the top level of the module.
-}
fields : Form step fields values -> fields
fields =
    Core.fields



-- VALUES AND STATE


{-| A form with every field empty, nothing touched, the first step, a group of
rows with its minimum number of empty rows, and that state as the baseline. Each
field's component gets its DOM id here.
-}
init : Form step fields values -> State step
init =
    Core.init


{-| Puts a value in a field, for every kind of field. The type of the handle
decides what is accepted: a select takes a `Maybe CountryId`, a switch a `Bool`.
Use it to load a record. A select shows its label as soon as its options have
arrived; `get` returns the value at once. The rows of a group are loaded with
`fillRows`.

    Form.init form
        |> Form.set f.name "Acme Supplies"
        |> Form.set f.country (Just (CountryId "no"))
        |> Form.markClean

-}
set : Field c -> c -> State step -> State step
set =
    Core.set


{-| The value of a field as it is edited: `Nothing` for an empty select, `[]` for
an empty multi select, the text as typed.
-}
get : Field c -> State step -> c
get =
    Core.get


{-| Puts a value in a `choice` field together with its option, so that the field
shows the option's label also when the options it is drawn with do not have it:
a saved customer in a select that searches the server, whose options are only
the latest hits. For a select that has all its options, `set` is enough.

    Form.setOption fields.customer (Select.option order.customerId order.customerName) state

-}
setOption : Field (Maybe id) -> Select.Option id -> State step -> State step
setOption =
    Core.setOption


{-| The search text of a `select` or `multiSelect` field while its list is open,
and `""` otherwise (and for every other kind). For a choice among thousands of
records, give the select `Select.serverSearch` and fetch the options when the
text changes: compare it before and after `update`. It follows the box after a
pause of 300 ms in the typing, so write no debounce of your own, and send the
text with the request so that a late answer to an old text can be dropped.

    FormMsg inner ->
        let
            ( state, cmd ) =
                Form.update form inner model.form
        in
        if Form.query fields.customer state /= Form.query fields.customer model.form then
            ( { model | form = state, customers = Remote.Loading }
            , Cmd.batch [ Cmd.map FormMsg cmd, searchCustomers (Form.query fields.customer state) ]
            )

        else
            ( { model | form = state }, Cmd.map FormMsg cmd )

    -- in the view
    Form.select v fields.customer model.customers [ Select.serverSearch ]

-}
query : Field c -> State step -> String
query =
    Core.query


{-| The browser's `File` values of the files the user chose in a `files` field
(the accepted ones, in order), for the request you make: the form holds the
`FileInfo` (name, size, type) and the library never sends anything. A file
loaded with `set` has none, so this is the list to upload.

    Form.rawFiles f.contract model.form
        |> List.map (Http.filePart "contract")
        |> Http.multipartBody

-}
rawFiles : Field (List FileDrop.FileInfo) -> State step -> List File
rawFiles =
    Core.rawFiles


{-| The handles of the rows a group has now, in order. Draw one card of fields
for each; the position is for the words ("Contact 2"). A handle is the row's
own: it stays right when other rows are added or removed, and stops working when
its row is removed.

    Form.rowFields f.contacts model.form
        |> List.indexedMap (\i row -> contactCard v i row)

-}
rowFields : Field (Rows rowFields) -> State step -> List rowFields
rowFields =
    Core.rowFields


{-| Loads a list of records into the rows of a group: the rows that are there are
replaced by one new row for each item, and `fill` puts the item in the row's
fields. Like `set`, it does not change the baseline; call `markClean` after a
load.

    Form.fillRows f.contacts
        (\contact row ->
            Form.set row.name contact.name
                >> Form.set row.email contact.email
        )
        supplier.contacts

-}
fillRows : Field (Rows rowFields) -> (a -> rowFields -> State step -> State step) -> List a -> State step -> State step
fillRows =
    Core.fillRows


{-| The record the form produces, or all the problems, in the order of the
declaration, in the given language. An invalid form cannot produce a record.
Rules and `required` run on every field, whether or not the user has been
there. A problem the server gave that still stands (its field has not been
edited) and every problem given to `outside` count too: the form is not valid
while they are there, so a record is never produced behind them.

    case Form.toValues Locale.default form model.form of
        Ok values ->
            save values

        Err found ->
            ...

-}
toValues : Locale -> Form step fields values -> State step -> Result (List (Problem step)) values
toValues =
    Core.toValues


{-| `True` when the values differ from the baseline, rows added and removed
included. Typing a letter and deleting it again is clean again. Only values
count: an open list, a search text or a server problem do not. It covers every
field of every step and every row, so one flag is enough for the leave guard.
-}
isDirty : State step -> Bool
isDirty =
    Core.isDirty


{-| The values now become the baseline, after a load or a successful save.
-}
markClean : State step -> State step
markClean =
    Core.markClean


{-| Every field goes back to the baseline, removed rows come back and added rows
go. Problems and what was touched are forgotten.
-}
revert : Form step fields values -> State step -> State step
revert =
    Core.revert


{-| Handles a message of the form's controls. A change in a field clears the
server problem of that field. It also answers the buttons that add and remove
rows, the stepper and the lines of the summary, which is why it needs the form.

    FormMsg inner ->
        let
            ( state, cmd ) =
                Form.update form inner model.form
        in
        ( { model | form = form }, Cmd.map FormMsg cmd )

-}
update : Form step fields values -> Msg -> State step -> ( State step, Cmd Msg )
update =
    Core.update



-- PROBLEMS AND FOCUS


{-| Everything that is wrong now, in the order of the declaration: the rules of
every field (whether or not the user has been there), the problems the server
gave that still stand, and the problems given to `outside`. A field has at most
one problem from the form, its own rule first and then the server's. This is the
list `toValues` gives when it fails, and the list for a review page or a count;
`summary` and the field's own message show the part of it that has come to
light.

    Form.problems Locale.default form model.form
        |> List.map (\p -> p.label ++ ": " ++ p.message)

-}
problems : Locale -> Form step fields values -> State step -> List (Problem step)
problems =
    Core.problems


{-| `True` when `problems` is not empty. Use it to keep a Save button quiet or to
colour a step: the language does not matter for the answer.
-}
hasProblems : Form step fields values -> State step -> Bool
hasProblems =
    Core.hasProblems


{-| Gives the form the problems of something it does not hold itself, such as
the rule builder of a price rule. They count like the form's own: they are in
`problems`, `toValues` fails while they stand, the stepper marks their step, and
`summary` lists them once their step has been tried (`advance`, `reveal`,
`rejected`). Each is a `Problem` you write by hand; its `field` is the DOM id of
the element the summary moves the focus to, and its `step` the step it belongs
to.

The list replaces the one given before, so compute it from your model and call
it at the end of your `update`, for example in the same place that handles the
messages of the rule builder:

    ( { model | form = Form.outside form (ruleProblems model) model.form }, cmd )

-}
outside : Form step fields values -> List (Problem step) -> State step -> State step
outside =
    Core.outside


{-| A message from the server tied to a field. Map the backend's own field type
to a handle once, in the application:

    fromBackend : Backend.Problem -> Form.Problem step
    fromBackend p =
        case p.field of
            Backend.Name ->
                Form.problem f.name p.message

            Backend.Country ->
                Form.problem f.country p.message

The label and the step are filled in from the declaration. A field in a row has
a handle for each row: `Form.rowFields f.contacts state`, then the row at the
position the server named.

-}
problem : Field c -> String -> Problem step
problem =
    Core.problem


{-| A message from the server for a field in a row of a repeating group, at the
position the server counted (from 0, in the list it was sent). The handle of the
row is found for you, so the mapping needs no `List.drop`. `Nothing` when the
group has no row at that position, for example because the user has removed it
since.

    fromBackend : Backend.Problem -> Form.State Step -> Maybe (Form.Problem Step)
    fromBackend p state =
        case p.field of
            Backend.ContactEmail position ->
                Form.problemInRow f.contacts position .email p.message state

            Backend.Name ->
                Just (Form.problem f.name p.message)

Hand the list to `rejected` (`List.filterMap` drops the `Nothing`s).

-}
problemInRow : Field (Rows rowFields) -> Int -> (rowFields -> Field c) -> String -> State step -> Maybe (Problem step)
problemInRow =
    Core.problemInRow


{-| Gives the form the problems of a failed save. Each is shown at its field
and in the summary until that field is edited, and counts as a problem
(`problems`, `toValues`) for as long. Every problem of the form shows from now
on, the form moves to the step of the first problem (so that its summary is the
one on screen), and the focus goes to the summary. On the review step (the last
step, when it has no fields) the form stays: its summary lists every problem of
every step, each with a button that goes there. A problem for a field the form
does not have is ignored.

The problems are stored whether or not the form is on screen. The `Cmd` focuses
the summary of this form; when the summary is not on screen (the form is on
another page, or not drawn yet) it finds nothing and does nothing, so it is safe
to batch or to drop. Two forms rejected in one reply each focus their own
summary, and the last one wins: keep the `Cmd` of the one the user is looking at.

-}
rejected : List (Problem step) -> Form step fields values -> State step -> ( State step, Cmd Msg )
rejected =
    Core.rejected


{-| Shows every problem now, also for fields the user has not been in, and moves
the focus to the summary. Call it when the user presses Save and `toValues`
returned problems (`advance` does it for you in a form with steps). Fields and
rows added later start quiet again.
-}
reveal : Form step fields values -> State step -> ( State step, Cmd Msg )
reveal =
    Core.reveal


{-| Moves the focus to a field, so the application never writes a DOM id. Map
the `Cmd` with your message constructor. Nothing happens when the field is not
on screen.

    Form.focus f.name |> Cmd.map FormMsg

-}
focus : Field c -> Cmd Msg
focus =
    Core.focus


{-| The DOM id of the element that takes the focus for a field: its control, the
add button of a group of rows, or the first button of a rule builder. It is for
the places that take DOM ids, such as `Modal.setInitialFocus` and
`Drawer.setInitialFocus` (the first field of a form in a drawer); to move the focus
in an update, use `focus`.

    Drawer.setInitialFocus [ Form.domId fields.name ] model.drawer
        |> Drawer.open "edit-customer"

-}
domId : Field c -> String
domId =
    Core.domId


{-| Goes to the element a problem is about, for a review list you draw yourself
(the summary does this by itself): the form changes to the step of the problem,
and the focus moves to its element once that step is on screen. The problem is
one of `problems`, or one you gave to `outside`.
-}
goToProblem : Form step fields values -> Problem step -> State step -> ( State step, Cmd Msg )
goToProblem =
    Core.goToProblem



-- STEPS


{-| The step the form is on, or `Nothing` in a form that was declared without
steps.

    case Form.currentStep form model.form of
        Just Company ->
            viewCompany model

        Just Contacts ->
            viewContacts model

        _ ->
            Html.text ""

-}
currentStep : Form step fields values -> State step -> Maybe step
currentStep =
    Core.currentStep


{-| `True` when the user has tried to leave this step (with `advance`) or the
problems were revealed (`reveal`, `rejected`). Something you draw yourself that
shows problems only after a try, such as the rule builder, asks it.
-}
attempted : Form step fields values -> step -> State step -> Bool
attempted =
    Core.attempted


{-| What the Next and Save buttons do. On a step before the last it checks that
step: with problems, they are shown, the step is marked as failed in the stepper
and the focus goes to the summary; without, the form moves on and the focus goes
to the first field of the next step. On the last step it checks the whole form:
with problems, they are all shown and the form goes to the review step (or, when
the last step has fields, to the first step with a problem); without,
`submit` is the record, ready to send. Sending it and keeping the
`FormLayout.Status` stays with the application.

    Submit ->
        let
            next =
                Form.advance form model.form
        in
        ( { model | form = next.state }
        , Cmd.batch [ Cmd.map FormMsg next.cmd, Maybe.map send next.submit |> Maybe.withDefault Cmd.none ]
        )

-}
advance : Form step fields values -> State step -> { state : State step, cmd : Cmd Msg, submit : Maybe values }
advance =
    Core.advance


{-| The Back button: one step back, without checking anything, and the focus goes
to the first field of that step. On the first step it does nothing.
-}
back : Form step fields values -> State step -> ( State step, Cmd Msg )
back =
    Core.back


{-| Goes to a step, for the "Edit" buttons of a review page. Going back is free.
Going forward checks every step on the way, as the stepper does: it stops at the
first one with problems, shows them and puts the focus on the summary.
-}
goTo : Form step fields values -> step -> State step -> ( State step, Cmd Msg )
goTo =
    Core.goTo



-- DRAWING THE FORM


{-| Binds the form, the state, the language and the message wrapper for one
view. The result carries everything the controls need, so each control is one
call.
-}
bind : Locale -> (Msg -> msg) -> Form step fields values -> State step -> View msg
bind =
    Core.bind


{-| A text input for a `text` field. The id, label, hint, required mark, value,
error and messages are set by the form and win over the application's
attributes; the others (a placeholder, `TextInput.url`, a suffix) are the
application's.
-}
textInput : View msg -> Field String -> List (TextInput.Attribute msg) -> Html msg
textInput =
    Core.textInput


{-| A multi-line text area for a `text` field: the same field as `textInput`,
drawn for a long note. Give the number of rows and the maximum length as
attributes (`TextArea.rows`, `TextArea.maxLength`).
-}
textArea : View msg -> Field String -> List (TextArea.Attribute msg) -> Html msg
textArea =
    Core.textArea


{-| A number input for a `number` field. The limits of `range` and the decimals
of `whole` are applied for you.
-}
numberInput : View msg -> Field (Maybe Float) -> List (NumberInput.Attribute msg) -> Html msg
numberInput =
    Core.numberInput


{-| A select for a `choice` field. The options are an argument, not an
attribute, so a select without options cannot be drawn.
-}
select : View msg -> Field (Maybe id) -> Remote (List (Select.Option id)) -> List (Select.Attribute String msg) -> Html msg
select =
    Core.select


{-| A multi select for a `choices` field.
-}
multiSelect : View msg -> Field (List id) -> Remote (List (Select.Option id)) -> List (MultiSelect.Attribute String msg) -> Html msg
multiSelect =
    Core.multiSelect


{-| A switch for a `toggle` field. The hint of the declaration is its
description.
-}
switch : View msg -> Field Bool -> List (Switch.Attribute msg) -> Html msg
switch =
    Core.switch


{-| A tag field for a `tags` field. The label, hint, required mark, error and
messages are set by the form; the delimiters, the limit, the placeholder and
a rule for a single tag are the application's attributes.
-}
tagInput : View msg -> Field (List String) -> List (TagInput.Attribute msg) -> Html msg
tagInput =
    Core.tagInput


{-| A drop zone for a `files` field. The type and size limits and the number of
files are the application's attributes (`FileDrop.accept`, `FileDrop.maxSize`,
`FileDrop.maxFiles`); `one` does not limit the zone by itself.
-}
fileDrop : View msg -> Field (List FileDrop.FileInfo) -> List (FileDrop.Attribute msg) -> Html msg
fileDrop =
    Core.fileDrop


{-| A rule builder for a `conditions` field. The label, hint, required mark,
language and DOM ids are set by the form; the fields (what a rule can talk about,
now with the options the user chooses among) are an argument, so a rule builder
without fields cannot be drawn. The other settings (`RuleBuilder.maxDepth`,
`RuleBuilder.json`) are the application's attributes.

    Form.ruleBuilder v row.conditions (priceFields options) []

Issues of the rule show on the node that has them once the step has been tried
(`advance`, `reveal`, `rejected`); a problem with the rule as a whole (a required
rule without conditions) shows under the builder. The summary leads to the
control that needs attention.

-}
ruleBuilder : View msg -> Field Rule.Rule -> List (Rule.Field ()) -> List (RuleBuilder.Attribute () msg) -> Html msg
ruleBuilder =
    Core.ruleBuilder


{-| A checkbox for a `toggle` field, for a yes or no that is saved with the form
("I accept the terms of delivery"). The label, the hint, the problem and the
value are the form's. `Spec.rule identity` makes ticking it a must.

    Form.checkbox v fields.acceptsTerms []

-}
checkbox : View msg -> Field Bool -> List (Checkbox.Attribute msg) -> Html msg
checkbox =
    Core.checkbox


{-| Radio buttons for a `choice` field, for two to five options that people
should see all at once. The options are the same `Select.Option` values that
`select` takes (`Select.option`, `Select.withDescription`, `Select.disabledOption`),
so a choice moves between the two controls without a change to its options. The
label of the field is the legend of the group; `Radio.horizontal` lays the
options out in a row.

    Form.radio v
        fields.customerKind
        [ Select.option Company "Company"
        , Select.option Person "Private person"
        ]
        [ Radio.horizontal ]

-}
radio : View msg -> Field (Maybe id) -> List (Select.Option id) -> List (Radio.Attribute String msg) -> Html msg
radio =
    Core.radio


{-| A date picker for a `date` field. The limits of `Spec.minDate` and
`Spec.maxDate` are given to the calendar for you. `today` (the marker, the
"Today" button and short forms such as `+3`) and a limit that depends on today
are the application's attributes.

    Form.datePicker v fields.deliveryDate [ DatePicker.today model.today, DatePicker.min model.today ]

-}
datePicker : View msg -> Field (Maybe Date) -> List (DatePicker.Attribute msg) -> Html msg
datePicker =
    Core.datePicker


{-| A date range picker for a `dateRange` field. The earliest and latest day,
the longest period and the presets are the application's attributes
(`DateRangePicker.min`, `DateRangePicker.maxRangeDays`, `DateRangePicker.today`);
a period the picker refuses is a problem of the form until it is fixed.
-}
dateRangePicker : View msg -> Field (Maybe ( Date, Date )) -> List (DateRangePicker.Attribute msg) -> Html msg
dateRangePicker =
    Core.dateRangePicker


{-| An amount field for a `money` field, in the currency of the declaration.
The limits of `Spec.minMoney` and `Spec.maxMoney` (and with them whether a
negative amount is allowed) are given to the field for you, so the field and
the form say the same.

    Form.moneyInput v fields.creditLimit [ MoneyInput.alignRight ]

-}
moneyInput : View msg -> Field (Maybe Money) -> List (MoneyInput.Attribute msg) -> Html msg
moneyInput =
    Core.moneyInput


{-| A masked field for a `masked` field: the identifier is written in its groups
as it is typed (`974 760 673`), and its check digit is checked. The field says
what is wrong ("Too short: 7 of 9 digits") once the user leaves it.

    Form.maskedInput v fields.organisationNumber []

-}
maskedInput : View msg -> Field (Maybe String) -> List (MaskedInput.Attribute msg) -> Html msg
maskedInput =
    Core.maskedInput


{-| The button that adds a row to a group, with the group's problem under it
("Add at least 1") when that is showing. The new row is added at the end and its
first field gets the focus. The button's DOM id is the group's: it is where the
summary and the focus after removing the last row lead.

    Form.addRow v f.contacts [] "Add contact"

-}
addRow : View msg -> Field (Rows rowFields) -> List (Button.Attribute msg) -> String -> Html msg
addRow =
    Core.addRow


{-| The button that removes the row at this position (counted from 0, as in
`List.indexedMap` over `rowFields`): an icon button named "Remove contact 2"
from the group's `item`. The focus goes to the next row's first field, or the
previous one, or the add button when no row is left.
-}
removeRow : View msg -> Field (Rows rowFields) -> Int -> List (Button.Attribute msg) -> Html msg
removeRow =
    Core.removeRow


{-| The steps of the form as a stepper, with the step the form is on and a red
mark on every step that has problems showing. A click on a step goes there; going
forward checks the steps on the way and stops at the first one with problems.
Nothing is drawn for a form without steps. The attributes are the stepper's own
(`Stepper.ariaLabel`, `Stepper.small`).
-}
stepper : View msg -> List (Stepper.Attribute msg) -> Html msg
stepper =
    Core.stepper


{-| The fields of the current step, drawn by the application, in one element. Use it
for the part of the form that changes with `currentStep`: Elm then makes new inputs for
the next step instead of reusing the focused input of the old one for the field at
the same place, which `advance` would blur (and show "Required" on a field nobody has
touched). Fields that stay on every step go outside it.

    FormLayout.view attributes
        [ Form.summary v
        , Form.stepBody v
            (case Form.currentStep form model.order of
                Just Customer ->
                    [ Form.textInput v f.name [], Form.textInput v f.email [] ]

                _ ->
                    [ Form.textInput v f.address [] ]
            )
        , FormLayout.actions [ ... ]
        ]

-}
stepBody : View msg -> List (Html msg) -> Html msg
stepBody =
    Core.stepBody


{-| The list of problems that are showing, with the labels of the declaration,
as `FormLayout.errorSummary`: the form's own and those given to `outside`. Each line
moves the focus to its element, on another step if need be. On a step it lists
the problems of that step; on the review step (a step with no fields) it lists
every problem of every step, shown or not, with the step in brackets. Nothing
is drawn while there is nothing to list, except on a step with no fields of the
form (a review step, or a step whose fields you draw yourself): there an empty
region named by the step is drawn, because the focus lands there when the form
moves to the step. Put `summary` at the top of every step.
-}
summary : View msg -> Html msg
summary =
    Core.summary
