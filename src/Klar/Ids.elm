module Klar.Ids exposing (Ids, make, list, string, int, map, toKey, fromKey)

{-| How the application's own id type is written as text and read back, once.

Use when: a component keeps your own ids or keys (rows, nodes, items, pages, choices) and needs them as text inside.
Do not use when: the value is not an id of yours (a label, a search text); plain text and whole-number ids take `Ids.string` and `Ids.int`.
Quick path: `make`, `list`, `string`, `int`, `map`

Components keep their values as text keys internally (a table's selection, the open
nodes of a tree, the choices of a rule). An application writes the two functions once
per id type, as a constant next to the type, and gives the same `Ids` to every
component that holds that type: `Table.rowId`, `Tree.leaf`, `Picking.leaf` (and so
`TreeSelect` and `Cascader`), `Transfer.options`, `Sortable.view`, `SideNav.item`,
`ServerList.target`, `Spec.choice` and `Spec.choices` of a form, `Rule.choiceFieldOf`
and `Form.Check.lostIds`. `Select`, `MultiSelect` and `Autocomplete` compare their
values with `==` and take no `Ids`.

    import Klar.Ids as Ids exposing (Ids)

    type CountryId
        = CountryId String

    countryIds : Ids CountryId
    countryIds =
        Ids.make
            { toKey = \(CountryId code) -> code
            , fromKey = Just << CountryId
            }

An id that wraps a number or a text needs no parser of its own: `map` puts the
wrapper around `Ids.int` or `Ids.string`.

    type CustomerId
        = CustomerId Int

    customerIds : Ids CustomerId
    customerIds =
        Ids.int |> Ids.map CustomerId (\(CustomerId n) -> n)

`fromKey` must give back what `toKey` wrote, and give `Nothing` for text that
is not an id of yours. [`Klar.Form.Check.lostIds`](Klar-Form-Check#lostIds)
tests that in one line.

@docs Ids, make, list, string, int, map, toKey, fromKey

-}

import Dict


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

A value left out of the list is written as usual but never read back. Two values
that are written as the same text read back as the first of them, so give each its
own text. The list is read once, when the `Ids` is made: keep it as a constant, and
reading a key back stays fast for a long list too.

-}
list : (id -> String) -> List id -> Ids id
list write all =
    let
        -- the first value wins when two are written alike
        table =
            Dict.fromList (List.reverse (List.map (\one -> ( write one, one )) all))
    in
    Ids
        { toKey = write
        , fromKey = \key -> Dict.get key table
        }


{-| Ids that are plain text (a SKU, a code), used as they are.

    Table.rowId Ids.string .sku

-}
string : Ids String
string =
    Ids { toKey = identity, fromKey = Just }


{-| Ids that are whole numbers (a database id). A key is read back only in the
form `toKey` writes it: `"7"` is 7, but `"007"`, `"+7"` and `"7.0"` are no id (so a
key from an address or a saved view has one spelling).

    Table.rowId Ids.int .id

-}
int : Ids Int
int =
    Ids
        { toKey = String.fromInt
        , fromKey =
            \key ->
                String.toInt key
                    |> Maybe.andThen
                        (\n ->
                            if String.fromInt n == key then
                                Just n

                            else
                                Nothing
                        )
        }


{-| The ids of a type that wraps another, from the `Ids` of the inner type: the
function that wraps a value and the one that unwraps it.

    customerIds : Ids CustomerId
    customerIds =
        Ids.int |> Ids.map CustomerId (\(CustomerId n) -> n)

-}
map : (a -> id) -> (id -> a) -> Ids a -> Ids id
map wrap unwrap (Ids codec) =
    Ids
        { toKey = unwrap >> codec.toKey
        , fromKey = codec.fromKey >> Maybe.map wrap
        }


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
