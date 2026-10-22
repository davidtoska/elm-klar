module Main exposing (main)

import Browser
import Html exposing (Html)
import Klar


main : Program () () ()
main =
    Browser.sandbox { init = (), update = \_ model -> model, view = view }


view : () -> Html ()
view _ =
    Html.div [] [ Klar.stylesheet, Html.text "Supplier onboarding" ]
