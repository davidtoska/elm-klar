module Klar.Ids exposing (Ids, make, toKey, fromKey)

{-| How the application's own id type is written as text and read back, once.

Use when: the application's own id type must be written as text and read back for components that keep text keys.
Do not use when: the id is already a `String`; no `Ids` is needed.
Quick path: `make`, `toKey`, `fromKey`

Several components keep their values as text keys internally (the form model's
selects, the choices of a rule): an application with `CountryId` and
`CategoryId` types writes the two functions once per type and hands the `Ids`
to every component that needs them.

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

@docs Ids, make, toKey, fromKey

-}


{-| The two functions that write an id as text and read it back. Make one with
`make` and keep it as a constant of the module that owns the id type.
-}
type Ids id
    = Ids
        { toKey : id -> String
        , fromKey : String -> Maybe id
        }


{-| Both directions of an id type. The same pair of functions as
`Table.rowIds` and `Tree.nodeIds` take.

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
