module Page.Gallery.Processes exposing (Model, Msg, init, leave, subscriptions, update, view)

{-| Dedicated component pages backed by the same working process studio.
-}

import Html exposing (Html)
import Klar.Locale exposing (Locale)
import Klar.Settings exposing (Settings)
import Page.Applications.Processes as Studio
import Showcase.Config exposing (Config)


type alias Model =
    Studio.Model


type alias Msg =
    Studio.Msg


init : ( Model, Cmd Msg )
init =
    ( Studio.init, Cmd.none )


update : Msg -> Model -> ( Model, Cmd Msg )
update =
    Studio.update


view : Config -> Settings -> Locale -> Model -> Html Msg
view config _ locale model =
    Studio.componentView config locale model


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none


leave : Model -> Model
leave =
    Studio.leave
