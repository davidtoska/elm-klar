module J_NumberHandleToTextInput exposing (form)

import Html
import Klar.Form.Model as Fm
import Klar.Remote as Remote


type Country
    = Country String


countries : Fm.Ids Country
countries =
    Fm.ids { toKey = \(Country c) -> c, fromKey = Just << Country }

type alias Fields =
    { age : Fm.Field (Maybe Float)
    }


type alias Values =
    { age : Maybe Float
    }


form : Fm.Form () Fields Values
form =
    Fm.define "p" Fields Values
        |> Fm.with (Fm.number "Age")
        |> Fm.build


f : Fields
f =
    Fm.fields form


page : Fm.View msg -> Html.Html msg
page v =
    Fm.textInput v f.age []

