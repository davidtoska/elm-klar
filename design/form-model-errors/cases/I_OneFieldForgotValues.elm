module I_OneFieldForgotValues exposing (form)

import Html
import Klar.Form.Model as Fm
import Klar.Remote as Remote


type Country
    = Country String


countries : Fm.Ids Country
countries =
    Fm.ids { toKey = \(Country c) -> c, fromKey = Just << Country }

type alias Fields =
    { name : Fm.Field String
    }


form : Fm.Form () Fields String
form =
    Fm.define "p" Fields
        |> Fm.with (Fm.text "Name" |> Fm.required)
        |> Fm.build

