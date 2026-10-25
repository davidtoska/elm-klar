module Page.Gallery.Workbench exposing (Model, Msg, init, subscriptions, update, view)

{-| Five workbench components exercised together in a complete application.
-}

import Html exposing (Html)
import Klar.Locale exposing (Locale)
import Klar.Settings exposing (Settings)
import Page.Gallery.Workbench.Demo as ReviewDesk
import Showcase.Config as Config
import Showcase.Doc as Doc
import Showcase.Options as Options


type alias Model =
    ReviewDesk.Model


type alias Msg =
    ReviewDesk.Msg


init : ( Model, Cmd Msg )
init =
    ReviewDesk.init


update : Msg -> Model -> ( Model, Cmd Msg )
update =
    ReviewDesk.update


subscriptions : Model -> Sub Msg
subscriptions =
    ReviewDesk.subscriptions


view : Config.Config -> Settings -> Locale -> Model -> Html Msg
view playground settings locale model =
    Doc.configuredPage playground
        { title = "Data workbench"
        , description = "CardList, WorkQueue, ConflictResolver, AuditLog and NotificationCenter in one connected review desk. Approve an order to see every panel respond; inspect all remote states with the controls. The complete program is example/src/Examples/ReviewDesk.elm."
        }
        [ ReviewDesk.view playground locale { model | settings = settings } ]
