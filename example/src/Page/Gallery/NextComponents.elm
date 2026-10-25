module Page.Gallery.NextComponents exposing (Model, Msg, init, subscriptions, update, view)

{-| Workflows, uploads, discussion, source and typed quantities.
-}

import Html exposing (Html)
import Klar.Locale exposing (Locale)
import Klar.Settings exposing (Settings)
import Page.Gallery.NextComponents.CodeQuantity as CodeQuantity
import Page.Gallery.NextComponents.Comments as Comments
import Page.Gallery.NextComponents.Kanban as Kanban
import Page.Gallery.NextComponents.Uploads as Uploads
import Showcase.Config as Config
import Showcase.Doc as Doc
import Showcase.Options as Options


type alias Model =
    { kanban : Kanban.Model, uploads : Uploads.Model, comments : Comments.Model, codeQuantity : CodeQuantity.Model }


type Msg
    = KanbanMsg Kanban.Msg
    | UploadsMsg Uploads.Msg
    | CommentsMsg Comments.Msg
    | CodeQuantityMsg CodeQuantity.Msg


init : ( Model, Cmd Msg )
init =
    let
        ( kanban, kanbanCmd ) =
            Kanban.init

        ( uploads, uploadCmd ) =
            Uploads.init

        ( comments, commentCmd ) =
            Comments.init

        ( codeQuantity, codeCmd ) =
            CodeQuantity.init
    in
    ( { kanban = kanban, uploads = uploads, comments = comments, codeQuantity = codeQuantity }
    , Cmd.batch [ Cmd.map KanbanMsg kanbanCmd, Cmd.map UploadsMsg uploadCmd, Cmd.map CommentsMsg commentCmd, Cmd.map CodeQuantityMsg codeCmd ]
    )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        KanbanMsg inner ->
            let
                ( next, cmd ) =
                    Kanban.update inner model.kanban
            in
            ( { model | kanban = next }, Cmd.map KanbanMsg cmd )

        UploadsMsg inner ->
            let
                ( next, cmd ) =
                    Uploads.update inner model.uploads
            in
            ( { model | uploads = next }, Cmd.map UploadsMsg cmd )

        CommentsMsg inner ->
            let
                ( next, cmd ) =
                    Comments.update inner model.comments
            in
            ( { model | comments = next }, Cmd.map CommentsMsg cmd )

        CodeQuantityMsg inner ->
            let
                ( next, cmd ) =
                    CodeQuantity.update inner model.codeQuantity
            in
            ( { model | codeQuantity = next }, Cmd.map CodeQuantityMsg cmd )


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch [ Sub.map KanbanMsg (Kanban.subscriptions model.kanban), Sub.map UploadsMsg (Uploads.subscriptions model.uploads), Sub.map CommentsMsg (Comments.subscriptions model.comments), Sub.map CodeQuantityMsg (CodeQuantity.subscriptions model.codeQuantity) ]


view : Config.Config -> Settings -> Locale -> Model -> Html Msg
view playground settings locale model =
    Doc.configuredPage playground
        { title = "Workflow toolkit", description = "Five additions for precise operational interfaces: Kanban, CommentThread, UploadQueue, CodeBlock and QuantityInput. Each demonstration exercises meaningful edge cases with the same public API an application uses." }
        [ Doc.configuredSection playground
            [ "Kanban" ]
            "Kanban"
            "Ordered work stages with explicit, validated moves."
            [ Html.map KanbanMsg (Kanban.view playground settings locale model.kanban) ]
        , Html.map CommentsMsg (Comments.view playground settings locale model.comments)
        , Html.map UploadsMsg (Uploads.view playground settings locale model.uploads)
        , Html.map CodeQuantityMsg (CodeQuantity.view playground settings locale model.codeQuantity)
        ]
