module Page.Gallery.Actions exposing (Model, Msg, init, subscriptions, update, view)

{-| Gallery page: actions and links.
-}

import Html exposing (Html)
import Klar.Locale exposing (Locale)
import Showcase.Doc as Doc



-- MODEL


type alias Model =
    {}


type Msg
    = NoOp


init : ( Model, Cmd Msg )
init =
    ( {}, Cmd.none )


update : Msg -> Model -> ( Model, Cmd Msg )
update _ model =
    ( model, Cmd.none )


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none



-- VIEW


view : Locale -> Model -> Html Msg
view _ _ =
    Doc.page
        { title = "Actions and links"
        , description = "Button groups, toggle groups, split buttons, links and keyboard keys."
        }
        []
