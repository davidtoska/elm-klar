module J_NumberHandleToTextInput exposing (form)

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
    { age : Form.Field (Maybe Float)
    }


type alias Values =
    { age : Maybe Float
    }


form : Form.Form () Fields Values
form =
    Spec.define "p" Fields Values
        |> Spec.with (Spec.number "Age")
        |> Spec.build


f : Fields
f =
    Form.fields form


page : Form.View msg -> Html.Html msg
page v =
    Form.textInput v f.age []

