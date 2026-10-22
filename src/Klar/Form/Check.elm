module Klar.Form.Check exposing (roundTrip, lostIds)

{-| Tests for a form: what an `elm-test` file needs to be sure that a
declaration is right, in one line each.

Use when: you write an `elm-test` file for a form declared with `Klar.Form.Spec`.
Do not use when: you declare or draw a form (use `Klar.Form.Spec` and `Klar.Form`); this module is for tests only.

    import Expect
    import Klar.Form.Check as Check

    suite : Test
    suite =
        describe "the supplier form"
            [ test "a record survives the form" <|
                \_ -> Check.roundTrip form fill sample |> Expect.equal (Ok sample)
            , test "the ids survive their keys" <|
                \_ -> Check.lostIds countryIds [ CountryId "no", CountryId "se" ] |> Expect.equal []
            ]

`roundTrip` catches what the compiler cannot: two fields of the same type that
were swapped in `Fields` or `Values`, and a `fill` function that forgets a field.
Use a sample with a different value in every field.

@docs roundTrip, lostIds

-}

import Klar.Form as Form
import Klar.Form.Core as Core
import Klar.Ids exposing (Ids)
import Klar.Locale exposing (Locale)


{-| For a test: loads a record with your `fill` function into a new form and
reads it back. A form that loses a value, or two fields of the same type that
were swapped in `Fields` or `Values`, gives something else than the record. Use
a sample with a different value in every field.

    Check.roundTrip form fill sample
        |> Expect.equal (Ok sample)

-}
roundTrip : Form.Form step fields values -> (values -> Form.State step -> Form.State step) -> values -> Result (List (Form.Problem step)) values
roundTrip =
    Core.roundTrip


{-| For a test: the values that do not survive `toKey` and `fromKey`. An empty
list is what you want.

    Check.lostIds countryIds [ CountryId "no", CountryId "se" ]
        |> Expect.equal []

-}
lostIds : Ids id -> List id -> List id
lostIds =
    Core.lostIds
