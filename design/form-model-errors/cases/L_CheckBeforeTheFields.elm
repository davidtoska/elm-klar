module L_CheckBeforeTheFields exposing (form)

import Klar.Form as Form
import Klar.Form.Spec as Spec


type alias Fields =
    { name : Form.Field String
    , nickname : Form.Field String
    }


type alias Values =
    { name : String
    , nickname : Maybe String
    }


form : Form.Form () Fields Values
form =
    Spec.define "p" Fields Values
        |> Spec.with (Spec.text "Name" |> Spec.required)
        |> Spec.check (\fields _ values -> [ Form.problem fields.nickname "Too long" ])
        |> Spec.with (Spec.text "Nickname")
        |> Spec.build
