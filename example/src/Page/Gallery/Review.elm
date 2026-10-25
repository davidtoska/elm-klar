module Page.Gallery.Review exposing (Model, Msg, init, subscriptions, update, view)

{-| Gallery page: diff and compare. Every part is a module of its own in
`Page.Gallery.Review.*`; this one puts them on the page.
-}

import Html exposing (Html)
import Klar.Locale exposing (Locale)
import Page.Gallery.Review.Compares as Compares
import Page.Gallery.Review.Diffs as Diffs
import Showcase.Config as Config
import Showcase.Doc as Doc
import Showcase.Options as Options



-- MODEL


type alias Model =
    { diffs : Diffs.Model
    , compares : Compares.Model
    }


type Msg
    = DiffsMsg Diffs.Msg
    | ComparesMsg Compares.Msg


init : ( Model, Cmd Msg )
init =
    ( { diffs = Diffs.init
      , compares = Compares.init
      }
    , Cmd.none
    )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        DiffsMsg inner ->
            let
                ( diffs, cmd ) =
                    Diffs.update inner model.diffs
            in
            ( { model | diffs = diffs }, Cmd.map DiffsMsg cmd )

        ComparesMsg inner ->
            let
                ( compares, cmd ) =
                    Compares.update inner model.compares
            in
            ( { model | compares = compares }, Cmd.map ComparesMsg cmd )


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none



-- VIEW


view : Config.Config -> Locale -> Model -> Html Msg
view playground locale model =
    Doc.configuredPage playground
        { title = "Diff and compare"
        , description = "What changed: text, JSON and record diffs, and records side by side."
        }
        [ Html.map DiffsMsg (Diffs.view playground locale model.diffs)
        , Html.map ComparesMsg (Compares.view playground locale model.compares)
        ]
