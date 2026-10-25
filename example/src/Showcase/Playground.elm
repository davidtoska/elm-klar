module Showcase.Playground exposing (Model, Msg(..), command, config, current, init, load, select, subscriptions, update, view)

import Dict exposing (Dict)
import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Events
import Html.Keyed
import Showcase.Advanced as Advanced
import Showcase.Config as Config exposing (Config, Control(..), Option)
import Showcase.Options as Options


type alias Model =
    { selected : String
    , components : Dict String (Dict String String)
    , query : String
    , baseline : Bool
    , advanced : Advanced.Model
    , live : Config
    }


init : Model
init =
    { selected = "", components = Dict.empty, query = "", baseline = False, advanced = Advanced.init, live = Config.empty }


type Msg
    = Set String String String
    | Clear String String
    | Reset String
    | Search String
    | Baseline Bool
    | AdvancedMsg Advanced.Msg


select : String -> Model -> Model
select component model =
    cache { model | selected = component, query = "", baseline = False }


config : String -> Model -> Config
config component model =
    if component == model.selected then
        model.live

    else
        { component = component
        , values =
            if model.baseline then
                Dict.empty

            else
                Dict.get component model.components |> Maybe.withDefault Dict.empty
        }


cache : Model -> Model
cache model =
    { model
        | live =
            { component = model.selected
            , values =
                if model.baseline then
                    Dict.empty

                else
                    Dict.get model.selected model.components |> Maybe.withDefault Dict.empty
            }
    }


current : Model -> Config
current model =
    config model.selected model


command : Msg -> Model -> Cmd Msg
command msg model =
    case msg of
        AdvancedMsg inner ->
            Advanced.command inner (Dict.get (Advanced.componentOf inner) model.components |> Maybe.withDefault Dict.empty) model.advanced |> Cmd.map AdvancedMsg

        _ ->
            Cmd.none


load : String -> Model -> ( Model, Cmd Msg )
load component model =
    let
        ( advanced, cmd ) =
            Advanced.load component model.advanced
    in
    ( { model | advanced = advanced }, Cmd.map AdvancedMsg cmd )


subscriptions : Sub Msg
subscriptions =
    Sub.map AdvancedMsg Advanced.subscriptions


update : Msg -> Model -> Model
update msg model =
    let
        next =
            updateInternal msg model
    in
    case msg of
        Set _ _ _ ->
            cache next

        Clear _ _ ->
            cache next

        Reset _ ->
            cache next

        Baseline _ ->
            cache next

        _ ->
            next


updateInternal : Msg -> Model -> Model
updateInternal msg model =
    case msg of
        Set component key value ->
            { model | components = Dict.update component (Maybe.withDefault Dict.empty >> Dict.insert key value >> Just) model.components, baseline = False, advanced = Advanced.update (Advanced.ControlsChanged component) model.advanced }

        Clear component key ->
            { model | components = Dict.update component (Maybe.map (Dict.remove key)) model.components, advanced = Advanced.update (Advanced.ClearOption component key) model.advanced }

        Reset component ->
            { model | components = Dict.remove component model.components, baseline = False, advanced = Advanced.update (Advanced.Reset component) model.advanced }

        Search query ->
            { model | query = query }

        Baseline value ->
            { model | baseline = value }

        AdvancedMsg inner ->
            { model | advanced = Advanced.update inner model.advanced, baseline = False }


view : (Msg -> msg) -> String -> String -> Model -> Html msg -> Html msg
view toMsg component category model examples =
    let
        saved =
            Dict.get component model.components |> Maybe.withDefault Dict.empty

        options =
            Options.forComponent component

        matches option =
            String.contains (String.toLower model.query) (String.toLower (option.name ++ " " ++ option.type_ ++ " " ++ option.description))
    in
    Html.article [ Attr.class "playground" ]
        [ Html.header [ Attr.class "playground-header" ]
            [ Html.a [ Attr.href "#/components", Attr.class "playground-back" ] [ Html.text "Components" ]
            , Html.span [ Attr.class "playground-category" ] [ Html.text (" / " ++ category) ]
            , Html.h1 [] [ Html.text component ]
            , Html.p [] [ Html.text "Explore the states below. Change options to try your own combinations; your choices stay here when you visit another component." ]
            ]
        , Html.div [ Attr.class "playground-layout" ]
            [ Html.div [ Attr.class "playground-preview" ]
                [ Html.div [ Attr.class "playground-preview-toolbar" ]
                    [ Html.div [ Attr.class "playground-tabs", Attr.attribute "role" "group", Attr.attribute "aria-label" "Preview configuration" ]
                        [ Html.button [ Attr.type_ "button", Attr.attribute "aria-pressed" (bool (not model.baseline)), Events.onClick (toMsg (Baseline False)) ] [ Html.text "Configured examples" ]
                        , Html.button [ Attr.type_ "button", Attr.attribute "aria-pressed" (bool model.baseline), Events.onClick (toMsg (Baseline True)) ] [ Html.text "Original states" ]
                        ]
                    , Html.span [ Attr.class "playground-count", Attr.attribute "aria-live" "polite" ] [ Html.text (String.fromInt (Dict.size saved) ++ " overrides") ]
                    ]
                , Advanced.preview component model.baseline model.advanced examples
                ]
            , Html.aside [ Attr.class "playground-panel", Attr.attribute "aria-label" (component ++ " options") ]
                [ Html.div [ Attr.class "playground-panel-heading" ]
                    [ Html.h2 [] [ Html.text "Options" ]
                    , Html.button [ Attr.type_ "button", Events.onClick (toMsg (Reset component)), Attr.disabled (Dict.isEmpty saved && not (Advanced.hasChanges component model.advanced)) ] [ Html.text "Reset all" ]
                    ]
                , Html.p [ Attr.class "playground-help" ] [ Html.text "Quick controls preserve each example's defaults. Every attribute also accepts custom Elm expressions, including callbacks and complex typed data." ]
                , Advanced.toolbar (AdvancedMsg >> toMsg) component model.advanced
                , Html.input [ Attr.type_ "search", Attr.placeholder "Find an option…", Attr.attribute "aria-label" "Find an option", Attr.value model.query, Events.onInput (Search >> toMsg), Attr.class "playground-search" ] []
                , if List.isEmpty options then
                    Html.p [ Attr.class "playground-help" ] [ Html.text "This module uses functions and typed values rather than an attribute list. Use its interactive examples below to explore the API." ]

                  else
                    Html.Keyed.node "div"
                        [ Attr.class "playground-controls" ]
                        (List.map (\option -> ( option.name, control toMsg component saved model.advanced option )) (List.filter matches options))
                , Html.details [ Attr.class "playground-recipe" ]
                    [ Html.summary [] [ Html.text "Configuration" ]
                    , Html.pre [] [ Html.code [] [ Html.text (recipe component saved) ] ]
                    ]
                ]
            ]
        ]


bool : Bool -> String
bool value =
    if value then
        "true"

    else
        "false"


control : (Msg -> msg) -> String -> Dict String String -> Advanced.Model -> Option -> Html msg
control toMsg component values advanced option =
    let
        selected =
            Dict.get option.name values

        custom =
            Advanced.isEnabled component option.name advanced

        id =
            "option-" ++ component ++ "-" ++ option.name

        set value =
            toMsg (Set component option.name value)

        attrs =
            [ Attr.id id, Attr.value (Maybe.withDefault "" selected), Attr.disabled custom, Events.onInput set ]

        selectControl choices =
            Html.select
                [ Attr.id id
                , Attr.disabled custom
                , Events.onInput
                    (\value ->
                        if value == "" then
                            toMsg (Clear component option.name)

                        else
                            set value
                    )
                ]
                (Html.option [ Attr.value "", Attr.selected (selected == Nothing) ] [ Html.text "Example default" ]
                    :: List.map
                        (\value -> Html.option [ Attr.value value, Attr.selected (selected == Just value) ] [ Html.text value ])
                        choices
                )
    in
    Html.div [ Attr.classList [ ( "playground-control", True ), ( "playground-control--changed", selected /= Nothing || custom ) ] ]
        [ Html.div [ Attr.class "playground-control-label" ]
            [ Html.label [ Attr.for id ] [ Html.text option.name ]
            , Html.button [ Attr.type_ "button", Attr.title ("Reset " ++ option.name), Attr.attribute "aria-label" ("Reset " ++ option.name), Attr.disabled (selected == Nothing && not custom), Events.onClick (toMsg (Clear component option.name)) ] [ Html.text "↺" ]
            ]
        , case option.control of
            Text ->
                Html.input (Attr.type_ "text" :: Attr.placeholder "Example default" :: attrs) []

            Number ->
                Html.input (Attr.type_ "number" :: Attr.step "any" :: Attr.placeholder "Example default" :: attrs) []

            Choice choices ->
                selectControl choices

            Example ->
                selectControl [ "omit" ]
        , Html.details [ Attr.class "playground-option-doc" ]
            [ Html.summary [] [ Html.code [] [ Html.text option.type_ ] ]
            , Html.p [] [ Html.text option.description ]
            ]
        , Advanced.editor (AdvancedMsg >> toMsg) component option advanced
        ]


recipe : String -> Dict String String -> String
recipe component values =
    if Dict.isEmpty values then
        "Using the original " ++ component ++ " examples."

    else
        values |> Dict.toList |> List.map (\( key, value ) -> component ++ "." ++ key ++ " = " ++ value) |> String.join "\n"
