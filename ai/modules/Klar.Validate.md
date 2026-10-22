# Klar.Validate

Pure, composable validators for text values.

Import: `import Klar.Validate as Validate` | Group: Forms

Types: `Validator`, `Error`

## Signatures

```elm
-- Running validators
type Validator  -- opaque: no constructors are exposed
type alias Error = { field : String, message : String }
run : Locale.Locale -> Validator -> String -> Maybe String
firstError : Locale.Locale -> List Validator -> String -> Maybe String
collect : Locale.Locale -> List ( String, List Validator, String ) -> List Error
errorFor : String -> List Error -> Maybe String

-- Checks
required : Validator
minLength : Int -> Validator
maxLength : Int -> Validator
email : Validator
phone : Validator
norwegianPhone : Validator
integerBetween : Int -> Int -> Validator
matches : String -> Validator
oneOf : List String -> Validator
date : Validator
notInFuture : Date.Date -> Validator

-- Combining and customizing
all : List Validator -> Validator
when : Bool -> Validator -> Validator
withMessage : { nb : String, en : String } -> Validator -> Validator
custom : (String -> Bool) -> { nb : String, en : String } -> Validator
customWith : (Locale.Locale -> String -> Maybe String) -> Validator

-- Dates as text
parseDate : String -> Maybe Date.Date
```

## Documentation

Pure, composable validators for text values. A validator returns the
problem as a message in the given `Locale`, or `Nothing` when the value is fine.

Use when: you check text values by hand and want messages in the user's language.
Do not use when: you declare a form with `Klar.Form.Spec`, which takes the same validators as its rules.
Quick path: `run`, `firstError`, `collect`, `errorFor`

    import Klar.Locale exposing (Locale(..))
    import Klar.Validate as Validate

    Validate.run Locale.en Validate.email "ada@" -- Just "Invalid email address"

    Validate.firstError Locale.en [ Validate.required, Validate.minLength 3 ] "ab"
    -- Just "Must be at least 3 characters"

Every validator except `required` and `custom` accepts an empty value: a field is
optional unless you add `required`. That keeps "optional, but valid when filled
in" fields simple.

Validate a whole form at once with `collect`, which turns
`( fieldId, validators, value )` triples into the list of problems, one per field,
in the order given:

    Validate.collect model.locale
        [ ( "customer-name", [ Validate.required ], model.name )
        , ( "customer-email", [ Validate.required, Validate.email ], model.email )
        ]

The `field` of an `Error` is the DOM id of the control, so
[`FormLayout.errorSummary`](Klar.Form.Layout.md) can move focus to it.

The messages are built in; use `withMessage` to say it your way. Lengths are
counted the way Elm counts them (`String.length`), in UTF-16 units.

## Running validators

### `Validator`

```elm
type Validator  -- opaque: no constructors are exposed
```

Something that checks a text value. Build one with the functions below.

### `Error`

```elm
type alias Error = { field : String, message : String }
```

A problem found in a field: the DOM id of the control (`field`) and what to
tell the user (`message`).

### `run`

```elm
run : Locale.Locale -> Validator -> String -> Maybe String
```

Runs one validator and returns its message, or `Nothing` when the value is
fine.

    Validate.run Locale.en Validate.required "  " -- Just "Required"

### `firstError`

```elm
firstError : Locale.Locale -> List Validator -> String -> Maybe String
```

Runs a list of validators in order and returns the first problem.

    Validate.firstError Locale.en [ Validate.required, Validate.email ] ""
    -- Just "Required"

### `collect`

```elm
collect : Locale.Locale -> List ( String, List Validator, String ) -> List Error
```

Validates several fields. Returns at most one `Error` per field (the first
problem), in the order the fields were given.

### `errorFor`

```elm
errorFor : String -> List Error -> Maybe String
```

The message for one field, if it has a problem. Use it to show the error
under the field.

    Validate.errorFor "customer-email" errors -- Maybe String

## Checks

### `required`

```elm
required : Validator
```

The value must not be empty. Spaces only count as empty.

### `minLength`

```elm
minLength : Int -> Validator
```

At least this many characters.

### `maxLength`

```elm
maxLength : Int -> Validator
```

At most this many characters.

### `email`

```elm
email : Validator
```

A plausible email address: one `@`, a local part, and a domain with at least
one dot. It cannot know whether the mailbox exists.

### `phone`

```elm
phone : Validator
```

A phone number written for people: an optional `+`, then 7 to 15 digits.
Spaces, dashes, dots and parentheses are fine anywhere. It checks the shape, not
whether the number exists.

    Validate.run Locale.en Validate.phone "+44 20 7946 0958" -- Nothing

### `norwegianPhone`

```elm
norwegianPhone : Validator
```

A Norwegian phone number: 8 digits. Spaces and dashes are fine, and so is a
`+47` or `0047` prefix.

### `integerBetween`

```elm
integerBetween : Int -> Int -> Validator
```

A whole number from `low` to `high`, both included.

    Validate.integerBetween 1 99

### `matches`

```elm
matches : String -> Validator
```

The value must equal another value, like "repeat password".

    Validate.matches model.password

### `oneOf`

```elm
oneOf : List String -> Validator
```

The value must be one of these.

    Validate.oneOf [ "open", "paid", "void" ]

### `date`

```elm
date : Validator
```

A calendar date written as `dd.mm.yyyy` or `yyyy-mm-dd`. 31 February is not
a date. The message names the form of the language, as `Klar.Format.date` writes
it: `yyyy-mm-dd` in English and `dd.mm.åååå` in Norwegian. See `parseDate` for
everything that is accepted.

### `notInFuture`

```elm
notInFuture : Date.Date -> Validator
```

The date may not be after the given day ("today", from the application).
Text that is not a date passes, so combine it with `date`.

    Validate.all [ Validate.date, Validate.notInFuture model.today ]

## Combining and customizing

### `all`

```elm
all : List Validator -> Validator
```

Several validators as one; the first problem wins.

    Validate.all [ Validate.required, Validate.maxLength 40 ]

### `when`

```elm
when : Bool -> Validator -> Validator
```

Only checks when the condition holds, like a phone number that is only
required when SMS notifications are switched on.

    Validate.when model.smsNotifications Validate.required

### `withMessage`

```elm
withMessage : { nb : String, en : String } -> Validator -> Validator
```

Replaces the message of a validator, in both languages.

    Validate.required |> Validate.withMessage { nb = "Oppgi navn", en = "Enter a name" }

### `custom`

```elm
custom : (String -> Bool) -> { nb : String, en : String } -> Validator
```

A validator from a yes/no test and a message in both languages. The test
sees the value as typed, also when it is empty.

    Validate.custom (String.startsWith "ORD-") { nb = "Må starte med ORD-", en = "Must start with ORD-" }

### `customWith`

```elm
customWith : (Locale.Locale -> String -> Maybe String) -> Validator
```

A validator that builds its own message, for messages that depend on the
value or on the language in ways `custom` cannot say.

## Dates as text

### `parseDate`

```elm
parseDate : String -> Maybe Date.Date
```

Reads `20.10.2026`, `1.2.1990` (day, month, four-digit year, separated by
dots) or `2026-10-20` into a `Date`. Anything else, and every date that does not
exist, is `Nothing`.
