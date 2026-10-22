module H_RequiredOnToggle exposing (form)

import Html
import Klar.Form.Model as Fm
import Klar.Remote as Remote


type Country
    = Country String


countries : Fm.Ids Country
countries =
    Fm.ids { toKey = \(Country c) -> c, fromKey = Just << Country }

type alias Fields =
    { agree : Fm.Field Bool
    }


type alias Values =
    { agree : Bool
    }


form : Fm.Form () Fields Values
form =
    Fm.define "p" Fields Values
        |> Fm.with (Fm.toggle "Agree" |> Fm.required)
        |> Fm.build

