module Page.Gallery.Flow exposing (Model, Msg, init, subscriptions, update, view)

{-| Gallery page: pages and flow.
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
        { title = "Pages and flow"
        , description = "Result pages, the bulk action bar, the leave guard and undo history."
        }
        []
