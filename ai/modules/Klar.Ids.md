# Klar.Ids

How the application's own id type is written as text and read back, once.

Import: `import Klar.Ids as Ids` | Group: Choosing

Types: `Ids`

## Signatures

```elm
type Ids id  -- opaque: no constructors are exposed
make : { toKey : id -> String, fromKey : String -> Maybe id } -> Ids id
toKey : Ids id -> id -> String
fromKey : Ids id -> String -> Maybe id
```

## Documentation

How the application's own id type is written as text and read back, once.

Use when: the application's own id type must be written as text and read back for components that keep text keys.
Do not use when: the id is already a `String`; no `Ids` is needed.
Quick path: `make`, `toKey`, `fromKey`

Several components keep their values as text keys internally (the form model's
selects, the choices of a rule): an application with `CountryId` and
`CategoryId` types writes the two functions once per type and hands the `Ids`
to the parts that take one: `Spec.choice` and `Spec.choices` of a form, `Rule.choiceFieldOf`
and `Form.Check.lostIds`. A table, a tree, the pickers, a sortable list and the side menu
take their own small id type instead (`Table.rowIds`, `Tree.nodeIds`, `Picking.ids`,
`Sortable.itemIds`, `SideNav.keys`).

    import Klar.Ids as Ids exposing (Ids)

    type CountryId
        = CountryId String

    countryIds : Ids CountryId
    countryIds =
        Ids.make
            { toKey = \(CountryId code) -> code
            , fromKey = Just << CountryId
            }

`fromKey` must give back what `toKey` wrote, and give `Nothing` for text that
is not an id of yours. [`Klar.Form.Check.lostIds`](Klar.Form.Check.md#lostids)
tests that in one line.

### `Ids`

```elm
type Ids id  -- opaque: no constructors are exposed
```

The two functions that write an id as text and read it back. Make one with
`make` and keep it as a constant of the module that owns the id type.

### `make`

```elm
make : { toKey : id -> String, fromKey : String -> Maybe id } -> Ids id
```

Both directions of an id type. The same pair of functions as
`Table.rowIds` and `Tree.nodeIds` take.

    categoryIds : Ids CategoryId
    categoryIds =
        Ids.make
            { toKey = \(CategoryId n) -> String.fromInt n
            , fromKey = Maybe.map CategoryId << String.toInt
            }

### `toKey`

```elm
toKey : Ids id -> id -> String
```

The text an id is written as.

### `fromKey`

```elm
fromKey : Ids id -> String -> Maybe id
```

The id a text stands for, or `Nothing` when it is none of yours.
