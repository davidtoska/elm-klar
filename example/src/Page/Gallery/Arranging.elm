module Page.Gallery.Arranging exposing (Model, Msg, init, subscriptions, update, view)

{-| Gallery page: arranging and resizing. A list the user puts in a new order, and
panes the user makes larger and smaller. Each of the two has a module of its own in
`Page.Gallery.Arranging.*`. Neither needs a subscription: both follow the mouse on a
layer of their own while it drags.
-}

import Html exposing (Html)
import Klar.Locale exposing (Locale)
import Page.Gallery.Arranging.Sortables as Sortables
import Page.Gallery.Arranging.Splitters as Splitters
import Showcase.Config as Config
import Showcase.Doc as Doc
import Showcase.Options as Options



-- MODEL


type alias Model =
    { sortables : Sortables.Model
    , splitters : Splitters.Model
    }


type Msg
    = SortablesMsg Sortables.Msg
    | SplittersMsg Splitters.Msg


init : ( Model, Cmd Msg )
init =
    ( { sortables = Sortables.init
      , splitters = Splitters.init
      }
    , Cmd.none
    )



-- UPDATE


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        SortablesMsg inner ->
            let
                ( sortables, cmd ) =
                    Sortables.update inner model.sortables
            in
            ( { model | sortables = sortables }, Cmd.map SortablesMsg cmd )

        SplittersMsg inner ->
            let
                ( splitters, cmd ) =
                    Splitters.update inner model.splitters
            in
            ( { model | splitters = splitters }, Cmd.map SplittersMsg cmd )


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none



-- VIEW


view : Config.Config -> Locale -> Model -> Html Msg
view playground locale model =
    Doc.configuredPage playground
        { title = "Arranging and resizing"
        , description = "Drag or key a list into a new order, and resize panes by dragging or with the keyboard. Both work with the mouse, a finger and the keyboard alone, and neither needs a subscription: the page only passes the messages on."
        }
        [ Html.map SortablesMsg (Sortables.view playground locale model.sortables)
        , Html.map SplittersMsg (Splitters.view playground locale model.splitters)
        ]
