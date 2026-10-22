module C_DifferentTypesSwapped exposing (form)

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
    , country : Form.Field (Maybe Country)
    , nickname : Form.Field String
    }


type alias Values =
    { name : String
    , country : Country
    , nickname : Maybe String
    }


form : Form.Form () Fields Values
form =
    Spec.define "p" Fields Values
        |> Spec.with (Spec.text "Name" |> Spec.required)
        |> Spec.with (Spec.text "Nickname")
        |> Spec.with (Spec.choice countries "Country" |> Spec.required)
        |> Spec.build

