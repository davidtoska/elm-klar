module Page.Gallery.Actions exposing (Model, Msg, init, subscriptions, update, view)

{-| Gallery page: actions and links. The previews are grouped by what they show,
and each group keeps its state in a module of its own below
`Page.Gallery.Actions`.
-}

import Html exposing (Html)
import Klar.Locale exposing (Locale)
import Page.Gallery.Actions.Groups as Groups
import Page.Gallery.Actions.Keys as Keys
import Page.Gallery.Actions.Links as Links
import Page.Gallery.Actions.Split as Split
import Showcase.Config as Config
import Showcase.Doc as Doc
import Showcase.Options as Options



-- MODEL


type alias Model =
    { groups : Groups.Model
    , split : Split.Model
    , links : Links.Model
    , keys : Keys.Model
    }


init : ( Model, Cmd Msg )
init =
    ( { groups = Groups.init
      , split = Split.init
      , links = Links.init
      , keys = Keys.init
      }
    , Cmd.none
    )



-- UPDATE


type Msg
    = GroupsMsg Groups.Msg
    | SplitMsg Split.Msg
    | LinksMsg Links.Msg
    | KeysMsg Keys.Msg


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        GroupsMsg inner ->
            Groups.update inner model.groups
                |> Tuple.mapBoth (\groups -> { model | groups = groups }) (Cmd.map GroupsMsg)

        SplitMsg inner ->
            Split.update inner model.split
                |> Tuple.mapBoth (\split -> { model | split = split }) (Cmd.map SplitMsg)

        LinksMsg inner ->
            Links.update inner model.links
                |> Tuple.mapBoth (\links -> { model | links = links }) (Cmd.map LinksMsg)

        KeysMsg inner ->
            Keys.update inner model.keys
                |> Tuple.mapBoth (\keys -> { model | keys = keys }) (Cmd.map KeysMsg)


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none



-- VIEW


view : Config.Config -> Locale -> Model -> Html Msg
view playground locale model =
    Doc.configuredPage playground
        { title = "Actions and links"
        , description = "Button groups, toggle groups, split buttons, links and keyboard keys."
        }
        [ Html.map GroupsMsg (Groups.buttonGroupSection playground locale model.groups)
        , Html.map GroupsMsg (Groups.toggleGroupSection playground locale model.groups)
        , Html.map SplitMsg (Split.section playground locale model.split)
        , Html.map LinksMsg (Links.section playground locale model.links)
        , Html.map KeysMsg (Keys.section playground locale model.keys)
        ]
