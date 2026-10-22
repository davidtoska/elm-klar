module I_OneFieldForgotValues exposing (form)

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
    { name : Form.Field String
    }


form : Form.Form () Fields String
form =
    Spec.define "p" Fields
        |> Spec.with (Spec.text "Name" |> Spec.required)
        |> Spec.build

