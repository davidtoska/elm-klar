module Page.Gallery.Forms exposing (Model, Msg, init, subscriptions, update, view)

{-| Gallery page: form controls, validation and form layout, ending with a
complete order form that uses them together. The sections live in
`Page.Gallery.Forms.*`; this module only puts them on one page.
-}

import Html exposing (Html)
import Klar.Locale exposing (Locale)
import Page.Gallery.Forms.Choices as Choices
import Page.Gallery.Forms.Content as Content
import Page.Gallery.Forms.NewOrder as NewOrder
import Page.Gallery.Forms.Structure as Structure
import Page.Gallery.Forms.Typing as Typing
import Page.Gallery.Forms.Validation as Validation
import Showcase.Config as Config
import Showcase.Doc as Doc
import Showcase.Options as Options


type alias Model =
    { typing : Typing.Model
    , choices : Choices.Model
    , content : Content.Model
    , validation : Validation.Model
    , structure : Structure.Model
    , newOrder : NewOrder.Model
    }


type Msg
    = TypingMsg Typing.Msg
    | ChoicesMsg Choices.Msg
    | ContentMsg Content.Msg
    | ValidationMsg Validation.Msg
    | StructureMsg Structure.Msg
    | NewOrderMsg NewOrder.Msg


init : ( Model, Cmd Msg )
init =
    ( { typing = Typing.init
      , choices = Choices.init
      , content = Content.init
      , validation = Validation.init
      , structure = Structure.init
      , newOrder = NewOrder.init
      }
    , Cmd.none
    )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        TypingMsg inner ->
            let
                ( typing, cmd ) =
                    Typing.update inner model.typing
            in
            ( { model | typing = typing }, Cmd.map TypingMsg cmd )

        ChoicesMsg inner ->
            let
                ( choices, cmd ) =
                    Choices.update inner model.choices
            in
            ( { model | choices = choices }, Cmd.map ChoicesMsg cmd )

        ContentMsg inner ->
            let
                ( content, cmd ) =
                    Content.update inner model.content
            in
            ( { model | content = content }, Cmd.map ContentMsg cmd )

        ValidationMsg inner ->
            let
                ( validation, cmd ) =
                    Validation.update inner model.validation
            in
            ( { model | validation = validation }, Cmd.map ValidationMsg cmd )

        StructureMsg inner ->
            let
                ( structure, cmd ) =
                    Structure.update inner model.structure
            in
            ( { model | structure = structure }, Cmd.map StructureMsg cmd )

        NewOrderMsg inner ->
            let
                ( newOrder, cmd ) =
                    NewOrder.update inner model.newOrder
            in
            ( { model | newOrder = newOrder }, Cmd.map NewOrderMsg cmd )


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none


view : Config.Config -> Locale -> Model -> Html Msg
view playground locale model =
    Doc.configuredPage playground
        { title = "Forms"
        , description = "Form fields, validation and form layout. Every control has a label, a hint and an error message that are connected to the field, works with the keyboard, and has built-in texts in English and Norwegian (switch the language in the top bar). The complete order form at the bottom puts it all together."
        }
        (List.map (Html.map TypingMsg) (Typing.sections playground locale model.typing)
            ++ List.map (Html.map ChoicesMsg) (Choices.sections playground locale model.choices)
            ++ List.map (Html.map ContentMsg) (Content.sections playground locale model.content)
            ++ List.map (Html.map ValidationMsg) (Validation.sections playground locale model.validation)
            ++ List.map (Html.map StructureMsg) (Structure.sections playground locale model.structure)
            ++ List.map (Html.map NewOrderMsg) (NewOrder.sections playground locale model.newOrder)
        )
