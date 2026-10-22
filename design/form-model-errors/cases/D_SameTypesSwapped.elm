module D_SameTypesSwapped exposing (form)

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
    { first : Form.Field String
    , second : Form.Field String
    }


type alias Values =
    { second : Maybe String
    , first : Maybe String
    }


form : Form.Form () Fields Values
form =
    Spec.define "p" Fields Values
        |> Spec.with (Spec.text "First")
        |> Spec.with (Spec.text "Second")
        |> Spec.build

