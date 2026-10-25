# Klar.Ids

How the application's own id type is written as text and read back, once.

Import: `import Klar.Ids as Ids` | Group: Choosing

Types: `Ids`

## Signatures

```elm
type Ids id  -- opaque: no constructors are exposed
make : { toKey : id -> String, fromKey : String -> Maybe id } -> Ids id
list : (id -> String) -> List id -> Ids id
string : Ids String
int : Ids Int
toKey : Ids id -> id -> String
fromKey : Ids id -> String -> Maybe id
```

## Documentation

How the application's own id type is written as text and read back, once.

Use when: a component keeps your own ids or keys (rows, nodes, items, pages, choices) and needs them as text inside.
Do not use when: the value is not an id of yours (a label, a search text); plain text and whole-number ids take `Ids.string` and `Ids.int`.
Quick path: `make`, `list`, `string`, `int`

Components keep their values as text keys internally (a table's selection, the open
nodes of a tree, the choices of a rule). An application writes the two functions once
per id type, as a constant next to the type, and gives the same `Ids` to every
component that holds that type: `Table.rowId`, `Tree.leaf`, `Picking.leaf`,
`Sortable.item`, `Accordion.section`, `SideNav.item`, `Spec.choice` and `Spec.choices` of a form,
`Rule.choiceFieldOf` and `Form.Check.lostIds`.

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

Both directions of an id type.

    categoryIds : Ids CategoryId
    categoryIds =
        Ids.make
            { toKey = \(CategoryId n) -> String.fromInt n
            , fromKey = Maybe.map CategoryId << String.toInt
            }

### `list`

```elm
list : (id -> String) -> List id -> Ids id
```

The ids of a small closed set, such as the pages of an application: the function
that writes one as text and the list of all of them. The way back is found in the list,
so there is no parser to write.

    type Page
        = Orders
        | Settings

    pageIds : Ids Page
    pageIds =
        Ids.list pageToString [ Orders, Settings ]

A value left out of the list is written as usual but never read back.

### `string`

```elm
string : Ids String
```

Ids that are plain text (a SKU, a code), used as they are.

    Table.rowId Ids.string .sku

### `int`

```elm
int : Ids Int
```

Ids that are whole numbers (a database id).

    Table.rowId Ids.int .id

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
