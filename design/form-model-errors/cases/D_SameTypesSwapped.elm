module D_SameTypesSwapped exposing (form)

import Html
import Klar.Form.Model as Fm
import Klar.Remote as Remote


type Country
    = Country String


countries : Fm.Ids Country
countries =
    Fm.ids { toKey = \(Country c) -> c, fromKey = Just << Country }

type alias Fields =
    { first : Fm.Field String
    , second : Fm.Field String
    }


type alias Values =
    { second : Maybe String
    , first : Maybe String
    }


form : Fm.Form () Fields Values
form =
    Fm.define "p" Fields Values
        |> Fm.with (Fm.text "First")
        |> Fm.with (Fm.text "Second")
        |> Fm.build

