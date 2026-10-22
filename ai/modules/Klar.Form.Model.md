# Klar.Form.Model

A form declared once: its fields in order, each with a label and its rules.

Import: `import Klar.Form.Model as Fm` | Group: Forms

Types: `Ids`, `Msg`, `Form`, `Spec`, `View`, `Field`, `State`, `Builder`, `Problem`

## Signatures

```elm
-- Types
type Form step fields values  -- opaque: no constructors are exposed
type State step  -- opaque: no constructors are exposed
type Msg  -- opaque: no constructors are exposed
type Field control  -- opaque: no constructors are exposed
type Ids id  -- opaque: no constructors are exposed
type alias Problem = { field : String, message : String }
type Spec control output  -- opaque: no constructors are exposed
type Builder step fields values  -- opaque: no constructors are exposed
type View msg  -- opaque: no constructors are exposed

-- Declaring a form
define : String -> fields -> values -> Builder step fields values
with : Spec control output -> Builder step (Field control -> f) (output -> v) -> Builder step f v
build : Builder step fields values -> Form step fields values
fields : Form step fields values -> fields
ids : { toKey : id -> String, fromKey : String -> Maybe id } -> Ids id

-- Kinds of field
text : String -> Spec String (Maybe String)
number : String -> Spec (Maybe Float) (Maybe Float)
choice : Ids id -> String -> Spec (Maybe id) (Maybe id)
choices : Ids id -> String -> Spec (List id) (List id)
toggle : String -> Spec Bool Bool

-- Rules
required : Spec c (Maybe a) -> Spec c a
atLeast : Int -> Spec c (List a) -> Spec c (List a)
one : Spec c (List a) -> Spec c (Maybe a)
rules : List Validate.Validator -> Spec String o -> Spec String o
range : Float -> Float -> Spec (Maybe Float) o -> Spec (Maybe Float) o
whole : Spec (Maybe Float) o -> Spec (Maybe Float) o
hint : String -> Spec c o -> Spec c o
withMessage : (Locale.Locale -> String) -> Spec c o -> Spec c o

-- Values and state
init : Form step fields values -> State step
set : Field c -> c -> State step -> State step
get : Field c -> State step -> c
toValues : Locale.Locale -> Form step fields values -> State step -> Result (List Problem) values
isDirty : State step -> Bool
markClean : State step -> State step
revert : State step -> State step
update : Msg -> State step -> ( State step, Cmd Msg )

-- Problems from the server
problem : Field c -> String -> Problem
rejected : List Problem -> Form step fields values -> State step -> ( State step, Cmd Msg )
reveal : Form step fields values -> State step -> ( State step, Cmd Msg )

-- Views
bind : Locale.Locale -> (Msg -> msg) -> Form step fields values -> State step -> View msg
textInput : View msg -> Field String -> List (TextInput.Attribute msg) -> Html msg
numberInput : View msg -> Field (Maybe Float) -> List (NumberInput.Attribute msg) -> Html msg
select :
    View msg
    -> Field (Maybe id)
    -> Remote.Remote (List (Select.Option id))
    -> List (Select.Attribute String msg)
    -> Html msg
multiSelect :
    View msg
    -> Field (List id)
    -> Remote.Remote (List (Select.Option id))
    -> List (MultiSelect.Attribute String msg)
    -> Html msg
switch : View msg -> Field Bool -> List (Switch.Attribute msg) -> Html msg
summary : View msg -> Html msg

-- Tests
roundTrip :
    Form step fields values
    -> (values -> State step -> State step)
    -> values
    -> Result (List Problem) values
lostIds : Ids id -> List id -> List id
```

## Documentation

A form declared once: its fields in order, each with a label and its rules.
The declaration gives the application the **handles** of the fields (to put in
the view, to read and set, to tie a server problem to), the **record** the form
produces when it is valid, and everything Klar needs to validate and update it.
The application keeps one [`State`](#state) in its model and one [`Msg`](#msg)
in its messages, instead of one component state and one message per field.

This is a prototype of the form model (`design/FORM-MODEL.md` in the
repository): it handles text, numbers, one choice, several choices and
switches. Import it as `Fm`.

    import Klar.Form.Model as Fm
    import Klar.Locale as Locale
    import Klar.Validate as Validate

    type alias Fields =
        { name : Fm.Field String
        , country : Fm.Field (Maybe CountryId)
        , categories : Fm.Field (List CategoryId)
        }

    type alias Values =
        { name : String
        , country : CountryId
        , categories : List CategoryId
        }

    form : Fm.Form () Fields Values
    form =
        Fm.define "supplier" Fields Values
            |> Fm.with (Fm.text "Name" |> Fm.required |> Fm.rules [ Validate.maxLength 80 ])
            |> Fm.with (Fm.choice countryIds "Country" |> Fm.required)
            |> Fm.with (Fm.choices categoryIds "Categories" |> Fm.atLeast 1)
            |> Fm.build

    f : Fields
    f =
        Fm.fields form

    -- model:  { form : Fm.State () }          init: Fm.init form
    -- message: FormMsg Fm.Msg
    -- update:  FormMsg inner -> Fm.update inner model.form |> Tuple.mapBoth ... (Cmd.map FormMsg)
    -- view:
    let
        v =
            Fm.bind Locale.default FormMsg form model.form
    in
    Layout.stack
        [ Fm.textInput v f.name []
        , Fm.select v f.country (Remote.Loaded countries) []
        , Fm.multiSelect v f.categories (Remote.Loaded categories) []
        , Fm.summary v
        ]

Fields and values are filled **by position**, like a decoder pipeline: the
n-th `with` fills the n-th argument of `Fields` and of `Values`. The compiler
refuses a field that is declared but not in the records, and the other way
round; it cannot see two fields of the same type swapped in one of the two
records. Put [`roundTrip`](#roundtrip) in one test to catch that.

Things the compiler refuses (checked, see `design/FORM-MODEL-ERRORS.md`):

  - a field in the pipeline but not in `Fields` or `Values`, and the reverse
  - a field read as another type than it was declared (`Maybe CountryId` against
    `CountryId` when the field is `required`)
  - a text handle given to `select`, a choice handle given to `textInput`
  - a `required` rule on a field that cannot be empty (a switch)

## Types

### `Form`

```elm
type Form step fields values  -- opaque: no constructors are exposed
```

A form declaration: the fields in order with their rules. It is a constant
(`form`), never part of the model or of a message. The three parameters are the
application's own step type (`()` for a form without steps), the record of
field handles (`Fields`) and the record the form produces (`Values`).

### `State`

```elm
type State step  -- opaque: no constructors are exposed
```

Everything the form keeps while it is being edited: the value of every field
(and the open list of a select), the baseline for `isDirty`, which fields were
left, and the problems the server gave. It is data only: there is no function in
it. Make it with `init` and keep it in the model.

### `Msg`

```elm
type Msg  -- opaque: no constructors are exposed
```

What the controls of the form send. Wrap it in one constructor of the
application's message type and pass what comes back to `update`.

### `Field`

```elm
type Field control  -- opaque: no constructors are exposed
```

A handle to one field. The type says what the value looks like while it is
edited: `String` for a text, `Maybe id` for a choice, `List id` for several,
`Maybe Float` for a number, `Bool` for a switch. Get the handles from
`fields form`; there is no other way to make one.

### `Ids`

```elm
type Ids id  -- opaque: no constructors are exposed
```

How the application's id type is written as text, once. Both directions are
needed: `fromKey` must give back what `toKey` wrote (test it with `lostIds`).

    countryIds : Fm.Ids CountryId
    countryIds =
        Fm.ids { toKey = \(CountryId code) -> code, fromKey = Just << CountryId }

### `Problem`

```elm
type alias Problem = { field : String, message : String }
```

A message tied to a field: the DOM id of the control (`field`) and what to
tell the user. It has the shape of `Validate.Error`, so it fits
`Form.errorSummary`.

### `Spec`

```elm
type Spec control output  -- opaque: no constructors are exposed
```

One field's kind, label and rules, as built by `text`, `number`, `choice`
and the others and changed by the rules. `control` is the type of the value
while it is edited, `output` the type the form produces: `required` turns a
`Maybe a` output into `a`.

### `Builder`

```elm
type Builder step fields values  -- opaque: no constructors are exposed
```

The declaration while it is being built with `with`. Start it with `define`
and finish it with `build`.

### `View`

```elm
type View msg  -- opaque: no constructors are exposed
```

A form, a state and a message wrapper, bound once per view with `bind`.
Every control of the form is drawn from it.

## Declaring a form

### `define`

```elm
define : String -> fields -> values -> Builder step fields values
```

Starts a declaration. The text is the prefix of the DOM ids of the fields
(`"supplier"` gives `supplier-name`, `supplier-legal-name` ...) and of the
summary; it must be different for every form on the page. The other two
arguments are the record constructors `Fields` and `Values`.

    Fm.define "supplier" Fields Values
        |> Fm.with (Fm.text "Name")
        |> Fm.build

### `with`

```elm
with : Spec control output -> Builder step (Field control -> f) (output -> v) -> Builder step f v
```

Adds the next field. It fills the next argument of `Fields` with its handle
and the next argument of `Values` with its output. The DOM id is made from the
form's prefix and the label (`Legal name` becomes `supplier-legal-name`); a
repeated label gets `-2`, `-3` ... so two ids never clash.

### `build`

```elm
build : Builder step fields values -> Form step fields values
```

Finishes the declaration. The result only has the type
`Form step Fields Values` when every `with` matched an argument of both records;
a field missing from one of them is a compile error.

### `fields`

```elm
fields : Form step fields values -> fields
```

The handles of the form's fields, as the `Fields` record. A constant: bind
it once at the top level of the module.

### `ids`

```elm
ids : { toKey : id -> String, fromKey : String -> Maybe id } -> Ids id
```

How an id type is written as text and read back. The same pair of functions
as `Table.rowIds`.

## Kinds of field

### `text`

```elm
text : String -> Spec String (Maybe String)
```

A line of text. Blank is `Nothing` in the output, and the output is trimmed
(the display is not: nothing is changed behind the user's back). Add `required`
to get a `String`.

### `number`

```elm
number : String -> Spec (Maybe Float) (Maybe Float)
```

A number. Empty is `Nothing`. Add `required`, `range` or `whole`.

### `choice`

```elm
choice : Ids id -> String -> Spec (Maybe id) (Maybe id)
```

One of the application's values, chosen in a `select`. Empty is `Nothing`.
Add `required` to get the id itself.

### `choices`

```elm
choices : Ids id -> String -> Spec (List id) (List id)
```

Several of the application's values, chosen in a `multiSelect`, in the order
they were chosen. Empty is `[]`. Add `atLeast 1` to make it required.

### `toggle`

```elm
toggle : String -> Spec Bool Bool
```

An on/off choice, drawn by `switch`. Off is the empty value.

## Rules

### `required`

```elm
required : Spec c (Maybe a) -> Spec c a
```

The field must have a value: the output loses its `Maybe`. A text must not
be blank, a choice must be made. The label gets the `*` of a required field.

    Fm.text "Name" |> Fm.required -- Spec String String

### `atLeast`

```elm
atLeast : Int -> Spec c (List a) -> Spec c (List a)
```

A list with at least this many items. It is required, and the message says
how many.

    Fm.choices categoryIds "Categories" |> Fm.atLeast 1

### `one`

```elm
one : Spec c (List a) -> Spec c (Maybe a)
```

At most one item: the output is `Maybe a` instead of a list.

### `rules`

```elm
rules : List Validate.Validator -> Spec String o -> Spec String o
```

The existing validators of [Klar.Validate](Klar.Validate.md) on a text, run on
the text as typed. The first problem wins. Like there, an empty text passes
every validator except `Validate.required`.

    Fm.text "Name" |> Fm.rules [ Validate.maxLength 80 ]

### `range`

```elm
range : Float -> Float -> Spec (Maybe Float) o -> Spec (Maybe Float) o
```

A number from `low` to `high`, both included. The control shows the limits
and keeps a number outside them as typed (it shows the problem, it does not move
the number).

### `whole`

```elm
whole : Spec (Maybe Float) o -> Spec (Maybe Float) o
```

A whole number: no decimals, shown and checked.

### `hint`

```elm
hint : String -> Spec c o -> Spec c o
```

A short help text under the field.

### `withMessage`

```elm
withMessage : (Locale.Locale -> String) -> Spec c o -> Spec c o
```

Replaces the message of the rule that was added last, in every language: a
function from the locale to the text, so the declaration (a constant) does not
fix the set of languages.

    Fm.text "Name"
        |> Fm.required
        |> Fm.withMessage (\locale -> Locale.pick locale { nb = "Oppgi navn", en = "Enter a name" })

## Values and state

### `init`

```elm
init : Form step fields values -> State step
```

A form with every field empty, nothing touched, and that empty state as the
baseline. Each field's component gets its DOM id here.

### `set`

```elm
set : Field c -> c -> State step -> State step
```

Puts a value in a field, for every kind of field. The type of the handle
decides what is accepted: a select takes a `Maybe CountryId`, a switch a `Bool`.
Use it to load a record. A select shows its label as soon as its options have
arrived; `get` returns the value at once.

    Fm.init form
        |> Fm.set f.name "Acme Supplies"
        |> Fm.set f.country (Just (CountryId "no"))
        |> Fm.markClean

### `get`

```elm
get : Field c -> State step -> c
```

The value of a field as it is edited: `Nothing` for an empty select, `[]` for
an empty multi select, the text as typed.

### `toValues`

```elm
toValues : Locale.Locale -> Form step fields values -> State step -> Result (List Problem) values
```

The record the form produces, or all the problems, in the order of the
declaration, in the given language. An invalid form cannot produce a record.
Rules and `required` run on every field, whether or not the user has been
there.

    case Fm.toValues Locale.default form model.form of
        Ok values ->
            save values

        Err problems ->
            ...

### `isDirty`

```elm
isDirty : State step -> Bool
```

`True` when the values differ from the baseline. Typing a letter and
deleting it again is clean again. Only values count: an open list, a search
text or a server problem do not.

### `markClean`

```elm
markClean : State step -> State step
```

The values now become the baseline, after a load or a successful save.

### `revert`

```elm
revert : State step -> State step
```

Every field goes back to the baseline. Problems and what was touched are
forgotten.

### `update`

```elm
update : Msg -> State step -> ( State step, Cmd Msg )
```

Handles a message of the form's controls. A change in a field clears the
server problem of that field.

    FormMsg inner ->
        let
            ( form, cmd ) =
                Fm.update inner model.form
        in
        ( { model | form = form }, Cmd.map FormMsg cmd )

## Problems from the server

### `problem`

```elm
problem : Field c -> String -> Problem
```

A message from the server tied to a field. Map the backend's own field type
to a handle once, in the application:

    fromBackend : Backend.Problem -> Fm.Problem
    fromBackend p =
        case p.field of
            Backend.Name ->
                Fm.problem f.name p.message

            Backend.Country ->
                Fm.problem f.country p.message

### `rejected`

```elm
rejected : List Problem -> Form step fields values -> State step -> ( State step, Cmd Msg )
```

Gives the form the problems of a failed save. Each is shown at its field
and in the summary until that field is edited. All the problems of the form show
from now on, and the focus moves to the summary. A problem for a field the form
does not have is ignored.

### `reveal`

```elm
reveal : Form step fields values -> State step -> ( State step, Cmd Msg )
```

Shows every problem now, also for fields the user has not been in, and moves
the focus to the summary. Call it when the user presses Save and `toValues`
returned problems.

## Views

### `bind`

```elm
bind : Locale.Locale -> (Msg -> msg) -> Form step fields values -> State step -> View msg
```

Binds the form, the state, the language and the message wrapper for one
view. The result carries everything the controls need, so each control is one
call.

### `textInput`

```elm
textInput : View msg -> Field String -> List (TextInput.Attribute msg) -> Html msg
```

A text input for a `text` field. The id, label, hint, required mark, value,
error and messages are set by the form and win over the application's
attributes; the others (a placeholder, `TextInput.url`, a suffix) are the
application's.

### `numberInput`

```elm
numberInput : View msg -> Field (Maybe Float) -> List (NumberInput.Attribute msg) -> Html msg
```

A number input for a `number` field. The limits of `range` and the decimals
of `whole` are applied for you.

### `select`

```elm
select :
    View msg
    -> Field (Maybe id)
    -> Remote.Remote (List (Select.Option id))
    -> List (Select.Attribute String msg)
    -> Html msg
```

A select for a `choice` field. The options are an argument, not an
attribute, so a select without options cannot be drawn.

### `multiSelect`

```elm
multiSelect :
    View msg
    -> Field (List id)
    -> Remote.Remote (List (Select.Option id))
    -> List (MultiSelect.Attribute String msg)
    -> Html msg
```

A multi select for a `choices` field.

### `switch`

```elm
switch : View msg -> Field Bool -> List (Switch.Attribute msg) -> Html msg
```

A switch for a `toggle` field. The hint of the declaration is its
description.

### `summary`

```elm
summary : View msg -> Html msg
```

The list of problems that are showing, with the labels of the declaration,
as `Form.errorSummary`. Each line moves the focus to its field. Nothing is
drawn while no problem is showing.

## Tests

### `roundTrip`

```elm
roundTrip :
    Form step fields values
    -> (values -> State step -> State step)
    -> values
    -> Result (List Problem) values
```

For a test: loads a record with your `fill` function into a new form and
reads it back. A form that loses a value, or two fields of the same type that
were swapped in `Fields` or `Values`, gives something else than the record. Use
a sample with a different value in every field.

    Fm.roundTrip form fill sample
        |> Expect.equal (Ok sample)

### `lostIds`

```elm
lostIds : Ids id -> List id -> List id
```

For a test: the values that do not survive `toKey` and `fromKey`. An empty
list is what you want.

    Fm.lostIds countryIds [ CountryId "no", CountryId "se" ]
        |> Expect.equal []
