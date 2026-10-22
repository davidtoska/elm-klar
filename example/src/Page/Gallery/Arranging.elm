module Page.Gallery.Arranging exposing (Model, Msg, init, subscriptions, update, view)

{-| Gallery page: arranging and resizing.
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
        { title = "Arranging and resizing"
        , description = "Drag or key a list into a new order, and resize panes by dragging or with the keyboard."
        }
        []
