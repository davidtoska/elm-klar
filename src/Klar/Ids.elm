module Klar.Ids exposing (Ids, make, list, string, int, toKey, fromKey)

{-| How the application's own id type is written as text and read back, once.

Use when: a component keeps your own ids or keys (rows, nodes, items, pages, choices) and needs them as text inside.
Do not use when: the value is not an id of yours (a label, a search text); plain text and whole-number ids take `Ids.string` and `Ids.int`.
Quick path: `make`, `list`, `string`, `int`

Components keep their values as text keys internally (a table's selection, the open
nodes of a tree, the choices of a rule). An application writes the two functions once
per id type, as a constant next to the type, and gives the same `Ids` to every
component that holds that type: `Table.rowId`, `Tree.leaf`, `Picking.leaf`,
`Sortable.view`, `SideNav.item`, `Spec.choice` and `Spec.choices` of a form,
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
is not an id of yours. [`Klar.Form.Check.lostIds`](Klar-Form-Check#lostIds)
tests that in one line.

@docs Ids, make, list, string, int, toKey, fromKey

-}


{-| The two functions that write an id as text and read it back. Make one with
`make` and keep it as a constant of the module that owns the id type.
-}
type Ids id
    = Ids
        { toKey : id -> String
        , fromKey : String -> Maybe id
        }


{-| Both directions of an id type.

    categoryIds : Ids CategoryId
    categoryIds =
        Ids.make
            { toKey = \(CategoryId n) -> String.fromInt n
            , fromKey = Maybe.map CategoryId << String.toInt
            }

-}
make : { toKey : id -> String, fromKey : String -> Maybe id } -> Ids id
make =
    Ids


{-| The ids of a small closed set, such as the pages of an application: the function
that writes one as text and the list of all of them. The way back is found in the list,
so there is no parser to write.

    type Page
        = Orders
        | Settings

    pageIds : Ids Page
    pageIds =
        Ids.list pageToString [ Orders, Settings ]

A value left out of the list is written as usual but never read back.

-}
list : (id -> String) -> List id -> Ids id
list write all =
    Ids
        { toKey = write
        , fromKey = \key -> List.head (List.filter (\one -> write one == key) all)
        }


{-| Ids that are plain text (a SKU, a code), used as they are.

    Table.rowId Ids.string .sku

-}
string : Ids String
string =
    Ids { toKey = identity, fromKey = Just }


{-| Ids that are whole numbers (a database id).

    Table.rowId Ids.int .id

-}
int : Ids Int
int =
    Ids { toKey = String.fromInt, fromKey = String.toInt }


{-| The text an id is written as.
-}
toKey : Ids id -> id -> String
toKey (Ids codec) =
    codec.toKey


{-| The id a text stands for, or `Nothing` when it is none of yours.
-}
fromKey : Ids id -> String -> Maybe id
fromKey (Ids codec) =
    codec.fromKey
