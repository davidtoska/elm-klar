module H_RequiredOnToggle exposing (form)

import Html
import Klar.Form as Form
import Klar.Form.Spec as Spec
import Klar.Ids as Ids exposing (Ids)
import Klar.Remote as Remote


type Country
    = Country String


countries : Ids Country
countries =
    Ids.make { toKey = \(Country c) -> c, fromKey = Just << Country }

type alias Fields =
    { agree : Form.Field Bool
    }


type alias Values =
    { agree : Bool
    }


form : Form.Form () Fields Values
form =
    Spec.define "p" Fields Values
        |> Spec.with (Spec.toggle "Agree" |> Spec.required)
        |> Spec.build

