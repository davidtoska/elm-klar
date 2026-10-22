module Page.Gallery.Markdown exposing (Model, Msg, init, subscriptions, update, view)

{-| Gallery page: markdown.
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
        { title = "Markdown"
        , description = "A safe Markdown renderer that copes with unfinished text, and an editor with preview."
        }
        []
