module K_RowsHandleToTextInput exposing (form)

import Html
import Klar.Form as Form
import Klar.Form.Spec as Spec


type alias ContactFields =
    { name : Form.Field String
    }


type alias Contact =
    { name : String
    }


contact : Form.Form () ContactFields Contact
contact =
    Spec.define "contact" ContactFields Contact
        |> Spec.with (Spec.text "Name" |> Spec.required)
        |> Spec.build


type alias Fields =
    { contacts : Form.Field (Form.Rows ContactFields)
    }


type alias Values =
    { contacts : List Contact
    }


form : Form.Form () Fields Values
form =
    Spec.define "p" Fields Values
        |> Spec.with (Spec.rows { label = "Contacts", item = "Contact" } contact)
        |> Spec.build


f : Fields
f =
    Form.fields form


page : Form.View msg -> Html.Html msg
page v =
    Form.textInput v f.contacts []
