# Klar.Select.Option

The option model shared by Klar.Select, Klar.MultiSelect and Klar.Autocomplete.

Import: `import Klar.Select.Option as Option` | Group: Choosing

Types: `Option`

## Signatures

```elm
-- Options
type alias Option id =
    { value : id
    , label : String
    , description : Maybe String
    , group : Maybe String
    , disabled : Bool
    , icon : Maybe Icon.Icon
    , keywords : List String
    }
option : id -> String -> Option id
withDescription : String -> Option id -> Option id
withGroup : String -> Option id -> Option id
withIcon : Icon.Icon -> Option id -> Option id
withKeywords : List String -> Option id -> Option id
disabledOption : Option id -> Option id
mapOption : (a -> b) -> Option a -> Option b
```

## Documentation

The option model shared by [Klar.Select](Klar.Select.md),
[Klar.MultiSelect](Klar.MultiSelect.md) and [Klar.Autocomplete](Klar.Autocomplete.md).

Use when: options for a select are built in a module that has no select of its own, such as a data module or a simulated backend.
Do not use when: the options are built next to the select itself; `Klar.Select` re-exports the same functions.
Quick path: `option`, `withDescription`, `withGroup`, `withKeywords`

Most applications do not import this module. `Klar.Select` re-exports `Option`,
`option` and the `with*` helpers, and the other two components take the same
`Option` values. Import it when you build options in a module that has no select
of its own (a data module, a simulated backend).

    import Klar.Select.Option as Option

    suppliers : List (Option.Option String)
    suppliers =
        [ Option.option "acme" "Acme Supplies"
            |> Option.withDescription "Berlin"
            |> Option.withGroup "Preferred"
        , Option.option "globex" "Globex"
            |> Option.withKeywords [ "Globex Corporation" ]
        , Option.option "initech" "Initech"
            |> Option.disabledOption
        ]

The value of an option is of whatever type you choose: a `String`, an `Int`, an id
type of your own. To search a list of options the way a select does, use
`Klar.Select.filter`.

## Options

### `Option`

```elm
type alias Option id =
    { value : id
    , label : String
    , description : Maybe String
    , group : Maybe String
    , disabled : Bool
    , icon : Maybe Icon.Icon
    , keywords : List String
    }
```

One choice in a list. It is plain data: make it with `option` and the
`with*` functions, or write the record yourself.

  - `value` is what the application stores: its own id type (a `CustomerId`, a code, an `Int`).
    Values are compared with `==`, so use data, not functions, and keep it unique within one list
  - `label` is what the user sees and searches
  - `description` is a short secondary text, shown dimmed after the label and searched too
  - `group` lists the option under a heading, together with the options of the same group
  - `disabled` shows the option dimmed and keeps it from being chosen
  - `icon` is drawn before the label
  - `keywords` are extra words that also match but are never shown (synonyms, codes, old names)

### `option`

```elm
option : id -> String -> Option id
```

An option with a value (what the application stores) and a label (what the
user sees and searches), and nothing else: no description, group or icon, not
disabled, no keywords. Add those with the `with*` functions.

    Option.option "de" "Germany"
        |> Option.withDescription "DE"
        |> Option.withGroup "Europe"

### `withDescription`

```elm
withDescription : String -> Option id -> Option id
```

A short secondary text, shown dimmed after the label and in the tooltip of
the option. It is searched too, but a match in the description ranks below the
same match in the label.

### `withGroup`

```elm
withGroup : String -> Option id -> Option id
```

Lists the option under a heading with this name. Options with the same
group are shown together, in the order the groups first appear, and options
without a group come first, under no heading. While the user searches, the
group with the best match comes first.

### `withIcon`

```elm
withIcon : Icon.Icon -> Option id -> Option id
```

An icon drawn before the label of the option in the list. `Klar.Select` also
shows it in the closed field next to the chosen label.

### `withKeywords`

```elm
withKeywords : List String -> Option id -> Option id
```

Extra words that also match the option, for example a synonym, an old name
or a code. They are searched but never shown. Calling it again adds to the
keywords.

### `disabledOption`

```elm
disabledOption : Option id -> Option id
```

Shows the option dimmed and keeps it from being chosen: it cannot be clicked,
highlighted or reached with the arrow keys. It is still searched and counted.

### `mapOption`

```elm
mapOption : (a -> b) -> Option a -> Option b
```

Gives the option another kind of value and keeps everything else (label,
description, group, icon, keywords, disabled). It is how an option over an
application's id type becomes an option over its text key.

    Option.option (CountryId "de") "Germany"
        |> Option.mapOption (\(CountryId code) -> code)
    -- an option over "de", still labelled "Germany"
