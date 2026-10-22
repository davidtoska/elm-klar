module E_TextHandleToSelect exposing (form)

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
    , nickname : Fm.Field String
    , country : Fm.Field (Maybe Country)
    }


type alias Values =
    { name : String
    , nickname : Maybe String
    , country : Country
    }


form : Fm.Form () Fields Values
form =
    Fm.define "p" Fields Values
        |> Fm.with (Fm.text "Name" |> Fm.required)
        |> Fm.with (Fm.text "Nickname")
        |> Fm.with (Fm.choice countries "Country" |> Fm.required)
        |> Fm.build


f : Fields
f =
    Fm.fields form


page : Fm.View msg -> Html.Html msg
page v =
    Fm.select v f.name (Remote.Loaded []) []

