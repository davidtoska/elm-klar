# Form model: what the compiler says

*Updated for the module split (`Klar.Form`, `Klar.Form.Spec`): the cases are ported and the output below is the compiler's output on the new names. Cases K and L are new (a rows handle given to a text input; a `check` before the last field).*

Owner amendment 4 of `design/FORM-MODEL.md`: the type `Form step fields values` has four
parameters (with `Builder step fields values` and `Spec control output` next to it), and the
Elm errors might be unreadable. This is the test. Every case is a real file in
[`form-model-errors/cases/`](form-model-errors/cases); `node design/form-model-errors/run.mjs`
compiles them all with Elm 0.19.3 and prints what the compiler says. The complete,
unedited output is [`form-model-errors/OUTPUT.txt`](form-model-errors/OUTPUT.txt); below, the
essential part of each message, copied from it (the code frame is cut to the lines that
matter). `Good.elm` is the correct form the other cases are mutations of: three fields
(`name` required text, `nickname` optional text, `country` required choice), the records
`Fields` and `Values`, and a four-line pipeline.

The judge is "an AI that sees only the compiler output" (and the file it just wrote).
For each case: *where* the compiler points, *what* it says, and whether the fix can be
read out of it.

## The cases

### (a) A field in the pipeline but not in `Fields` (A) or not in `Values` (A2)

```elm
type alias Fields = { name : Form.Field String, nickname : Form.Field String }   -- 2 fields; the pipeline has 3
```

```
-- TYPE MISMATCH -- cases\A_FieldNotInFields.elm
This function cannot handle the argument sent through the (|>) pipe:

31|     Spec.define "p" Fields Values
32|         |> Spec.with (Spec.text "Name" |> Spec.required)
33|         |> Spec.with (Spec.text "Nickname")
34|         |> Spec.with (Spec.choice countries "Country" |> Spec.required)
               ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
The argument is:
    Spec.Builder step Fields (Country -> Values)
But (|>) is piping it to a function that expects:
    Spec.Builder step (Form.Field (Maybe Country) -> f) (Country -> Values)
```

Same shape for A2 (`Values` has two fields): the argument is `Builder step (Field (Maybe
Country) -> Fields) Values`, the function expects `... (Country -> v)`.

* **Where:** the *last* `with`, which is the field that has nowhere to go. Correct.
* **What:** the third `with` wants a `Fields` that still waits for a `Field (Maybe Country)`;
  it got a `Fields` that is already complete. The name of the missing slot is in the type
  (`Field (Maybe Country)`), the name of the record (`Fields` or `Values`) is in the type
  too, and the side that is wrong is the side where the type is a plain record name.
* **Verdict: readable.** An AI has to know that `Builder step A B` means "A is the fields,
  B the values" (the module doc and the `with` signature say so). It does not need to know
  anything else. It does not say "add `country` to `Fields`" and cannot.

### (b) A field in `Fields` but not in the pipeline

```
-- TYPE MISMATCH -- cases\B_FieldNotInPipeline.elm
Something is off with the body of the `form` definition:
32|>    Spec.define "p" Fields Values
33|>        |> Spec.with (Spec.text "Name" |> Spec.required)
34|>        |> Spec.with (Spec.text "Nickname")
35|>        |> Spec.build
The body is:
    Form.Form () (Form.Field (Maybe Country) -> Fields) (Country -> Values)
But the type annotation on `form` says it should be:
    Form.Form () Fields Values
```

* **Where:** the whole definition (it is the annotation that disagrees). Correct, and the only
  place that *can* be named: the compiler does not know which `with` is missing.
* **What:** `Field (Maybe Country) -> Fields` and `Country -> Values` are the unfilled
  slots, so the missing field has type `Maybe Country` / `Country`. That is enough to find it.
* **Verdict: readable.** This is the best of the structural errors: the missing argument is
  shown as a function type that still waits for it.

### (c) Two differently typed fields swapped

`Fields` and `Values` list `country` before `nickname`; the pipeline lists `nickname`
first.

```
-- TYPE MISMATCH -- cases\C_DifferentTypesSwapped.elm
This function cannot handle the argument sent through the (|>) pipe:
32|     Spec.define "p" Fields Values
33|         |> Spec.with (Spec.text "Name" |> Spec.required)
34|         |> Spec.with (Spec.text "Nickname")
               ^^^^^^^^^^^^^^^^^^^^^^^^^^^
The argument is:
    Spec.Builder
        step
        (Form.Field (Maybe Country) -> Form.Field String -> Fields)
        (Country -> Maybe String -> Values)
But (|>) is piping it to a function that expects:
    Spec.Builder step (Form.Field String -> f) (Maybe String -> v)
Hint: It looks like it takes too many arguments. I see 1 extra.
```

* **Where:** the field that is in the wrong place in the *records* (`Nickname`), correct
  line, but the message is about the records, not about the line.
* **What:** the two function types `Field (Maybe Country) -> Field String -> Fields` against
  a `with` that offers `Field String` first: the order is visible if one reads both types, but
  nothing says "the order of `Fields` differs from the order of the pipeline".
  The compiler's **hint is wrong** ("takes too many arguments, 1 extra"); an AI that trusts it
  deletes an argument.
* **Verdict: readable with effort, and the hint misleads.** This is the case where "the
  n-th `with` fills the n-th slot" must be in the documentation, because the message does not
  say it. The module doc does say it (and in the first paragraph after the example).

### (d) Two same-typed fields swapped (expected: compiles)

`Fields` has `first` and `second` (both `Field String`); `Values` lists `second` before
`first`; the pipeline is `First`, `Second`.

```
Success! Compiled 1 module.
```

It compiles, as designed. It is caught at run time by `Check.roundTrip`, a one-line test; see
`tests/FormModelTest.elm`, "two same-typed fields swapped in Values compile but roundTrip
catches them": the sample `{ first = Just "one", second = Just "two" }` comes back as
`{ first = Just "two", second = Just "one" }`, and
`Check.roundTrip swapped fill sample |> Expect.equal (Ok sample)` fails with elm-test's diff of the two
records, naming the fields. That is as good as a runtime check gets, and it needs the one
test line. **This is the one hole in design A** (risk 1 of the design); it is a hole in B too
for a different reason (B has no pipeline, but a value read as the wrong kind compiles).

### (e) A text handle given to a select view

```
-- TYPE MISMATCH -- cases\E_TextHandleToSelect.elm
The 2nd argument to `select` is not what I expect:
46|     Form.select v f.name (Remote.Loaded []) []
                    ^^^^^^
The value at .name is a:
    Form.Field String
But `select` needs the 2nd argument to be:
    Form.Field (Maybe id)
```

(a number handle given to `textInput`, case J, reads the same: `Form.Field (Maybe Float)`
against `Form.Field String`.) **Verdict: excellent.** Points at the argument, names the field
(`.name`), says what a select needs. The word `id` in `Maybe id` tells the AI that a select
wants a choice.

### (f) A required choice read as optional

F1 declares `country : Maybe Country` in `Values` although the pipeline says `required`:

```
-- TYPE MISMATCH -- cases\F1_RequiredChoiceDeclaredOptional.elm
This function cannot handle the argument sent through the (|>) pipe:
35|         |> Spec.with (Spec.choice countries "Country" |> Spec.required)
               ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
The argument is:
    Spec.Builder step (Form.Field (Maybe Country) -> Fields) (Maybe Country -> Values)
But (|>) is piping it to a function that expects:
    Spec.Builder step (Form.Field (Maybe Country) -> Fields) (Country -> v)
Hint: Use Maybe.withDefault to handle possible errors. ...
```

F2 reads `Form.get f.country state` where a `Country` is wanted:

```
Something is off with the body of the `country` definition:
46|     Form.get f.country state
This `get` call produces:
    Maybe Country
But the type annotation on `country` says it should be:
    Country
```

* **Where:** F1 the `with` of the `required` field (correct); F2 the call.
* **Verdict:** F2 is as clear as Elm gets. F1 is readable (`Maybe Country -> Values`
  against `Country -> v`), but the hint ("use `Maybe.withDefault`") would send an AI the wrong
  way: the right fix is `Values.country : Country`, because the field is required. The
  message never says "required" or "`Spec.required` removes the `Maybe`"; the documentation
  of `required` must say it, and the module doc does.

### Extra cases found while building

| Case | Mistake | Where / what it says | Verdict |
|---|---|---|---|
| G | forgot `Spec.build` | the definition; body is `Spec.Builder step Fields Values`, annotation says `Form.Form () Fields Values` | clear: the name `Builder` says "not finished" |
| H | `Spec.required` on a `toggle` | `Spec Bool Bool` piped to a function that expects `Spec Bool (Maybe a)` | clear; the second `Bool` is the output that cannot be empty |
| I | one field, forgot the `Values` constructor: `Spec.define "p" Fields` | `values -> Builder step (Field String -> Fields) values` against `Builder step (Field String -> f) (String -> v)` | poor: `values ->` is the unapplied argument, nothing says "`define` takes the values constructor third"; it happened to the author of the tests once |
| K | a rows handle given to `Form.textInput` | `Form.Field (Form.Rows ContactFields)` where `Form.Field String` is wanted | clear: the type of the handle names the kind, and a group is not a text |
| L | `Spec.check` before the last `with` | the `check` function wants `Fields` but the pipeline has not finished it: `Spec.Builder step { a \| nickname : Form.Field c } ...` against `Spec.Builder step (Form.Field String -> Fields) ...` | readable: it is a compile error to put `check` early, which is the point |

## Verdict on readability

**Readable enough: yes, with two blemishes. Design A is not made unreadable by its four
parameters.** The reasons:

1. The compiler prints the types in the user's own words: `Form.Field (Maybe Country)`,
   `Form.Form () Fields Values`, `Spec.Builder step Fields (Country -> Values)`. The
   unresolved `step` is noise (a lower-case variable in a message), but it is always the
   first parameter, and it is `()` in a finished form.
2. In 9 of the first 11 mistakes tried (A, A2, B, E, F1, F2, G, H, J; K and L came later, their
   output is in `OUTPUT.txt`) the location is the right line and
   the types name the missing or wrong thing. In 2 (C, I) the message is about the
   records or the missing argument and the location is only close.
3. What an AI needs to know is a rule it can read in the module doc: "the n-th `with` fills the
   n-th argument of `Fields` and `Values`; `Builder step A B` is A the fields and B the
   values; `required` removes `Maybe`". All three are in the documentation of `Klar.Form.Spec`.
4. The two blemishes: the compiler's hints in C ("takes too many arguments") and F1 ("use
   `Maybe.withDefault`") point the wrong way, so an AI that follows the hint instead of the
   types makes it worse. Nothing in Klar can change that; the documentation can only warn.
5. The one mistake the compiler does not see (d) is caught by `roundTrip` in one line.

**What would raise the score without changing the design:** (i) a "the compiler says X, it
means Y" table in the recipe for the five messages above (it is what this file is); (ii)
case I is avoidable if `define` took a record `{ fields = Fields, values = Values }`, which
makes the two roles named instead of positional (the cost: one more brace pair, and a swapped
record is still a wrong-order mistake the compiler cannot see when both have the same field
types); (iii) the rename of the type variable `step` in `Builder` to a phantom that is
`()` is not worth it.

### What design B would look like, in the same page (for the owner's comparison only)

A does not need B on this evidence, so B is sketched, not built. The application writes the
key type and one exhaustive function; the type of the value of a field is not in the key:

```elm
type FieldKey = Name | LegalName | Registration | Website | Country | Segments

spec : FieldKey -> Spec.Spec            -- a `case` that is exhaustive: a key without a spec does not compile
spec key =
    case key of
        Name -> Spec.text "Name" |> Spec.required |> Form.maxLength 80
        Country -> Spec.choice "Country" |> Spec.required
        ...

-- the view, the getters
Form.textInput v Name []
Form.select v Country options []
Spec.text Name state            -- : String   (a number key here compiles and is a run-time "wrong kind")
Spec.choice countryIds Country state   -- : Maybe CountryId
```

What B gains on the error messages: they are *plain Elm errors* (a missing `case` branch:
"This `case` does not have branches for all possibilities: Segments"), the best messages Elm
has. What it loses: cases (c), (e), (f) stop being compile errors and become wrong-kind
values at run time (`Spec.text Country state`), which is exactly what design A removes. So the
choice is: A, with two blemishes in the messages and one hole (d) closed by a test line; or B, with the best
messages and three kinds of mistake that move to run time. On this evidence, A.
