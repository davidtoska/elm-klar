module Page.Gallery.Navigation exposing (Model, Msg, init, subscriptions, update, view)

{-| Gallery page: navigation and structure. The previews are grouped by what they
show, and each group keeps its state in a module of its own below
`Page.Gallery.Navigation`.
-}

import Html exposing (Html)
import Klar.Locale exposing (Locale)
import Page.Gallery.Navigation.Content as Content
import Page.Gallery.Navigation.Edge as Edge
import Page.Gallery.Navigation.Frame as Frame
import Page.Gallery.Navigation.Header as Header
import Showcase.Config as Config
import Showcase.Doc as Doc
import Showcase.Options as Options



-- MODEL


type alias Model =
    { frame : Frame.Model
    , header : Header.Model
    , content : Content.Model
    , edge : Edge.Model
    }


init : Config.Config -> ( Model, Cmd Msg )
init playground =
    ( { frame = Frame.init playground
      , header = Header.init
      , content = Content.init
      , edge = Edge.init
      }
    , Cmd.none
    )



-- UPDATE


type Msg
    = FrameMsg Frame.Msg
    | HeaderMsg Header.Msg
    | ContentMsg Content.Msg
    | EdgeMsg Edge.Msg


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        FrameMsg inner ->
            Frame.update inner model.frame
                |> Tuple.mapBoth (\frame -> { model | frame = frame }) (Cmd.map FrameMsg)

        HeaderMsg inner ->
            Header.update inner model.header
                |> Tuple.mapBoth (\header -> { model | header = header }) (Cmd.map HeaderMsg)

        ContentMsg inner ->
            Content.update inner model.content
                |> Tuple.mapBoth (\content -> { model | content = content }) (Cmd.map ContentMsg)

        EdgeMsg inner ->
            Edge.update inner model.edge
                |> Tuple.mapBoth (\edge -> { model | edge = edge }) (Cmd.map EdgeMsg)


{-| Nothing listens: the keyboard shortcut that the shell advertises (Ctrl K)
belongs to the showcase application, not to this page.
-}
subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none



-- VIEW


view : Config.Config -> Locale -> Model -> Html Msg
view playground locale model =
    Doc.configuredPage playground
        { title = "Navigation and structure"
        , description = "The frame around a whole application, the side menu, page headers, breadcrumbs, tabs, accordions, toolbars, description lists and steppers."
        }
        [ Html.map FrameMsg (Frame.shellSection playground locale model.frame)
        , Html.map FrameMsg (Frame.sideNavSection playground locale model.frame)
        , Html.map HeaderMsg (Header.pageHeaderSection playground locale model.header)
        , Html.map HeaderMsg (Header.breadcrumbsSection playground locale model.header)
        , Html.map HeaderMsg (Header.tabsSection playground locale model.header)
        , Html.map ContentMsg (Content.accordionSection playground locale model.content)
        , Html.map ContentMsg (Content.toolbarSection playground locale model.content)
        , Content.descriptionListSection playground locale
        , Html.map ContentMsg (Content.stepperSection playground locale model.content)
        , Html.map EdgeMsg (Edge.section playground locale model.edge)
        ]
