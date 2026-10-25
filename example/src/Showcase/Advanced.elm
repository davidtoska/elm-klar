module Showcase.Advanced exposing (Model, Msg(..), command, componentOf, editor, hasChanges, init, isEnabled, load, preview, subscriptions, toolbar, update)

import Dict exposing (Dict)
import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Events
import Json.Decode as Decode
import Json.Encode as Encode
import Set exposing (Set)
import Showcase.Compiler as Compiler
import Showcase.Config as Config exposing (Option)


type alias Target =
    { id : String, label : String, alias : String, imports : List String, constructors : List String, options : List SourceOption, arguments : List ViewArgument }


type alias ViewArgument =
    { key : String, name : String, type_ : String, sample : String }


type alias SourceOption =
    { name : String, sample : String, trace : String }


type alias Page =
    { targets : List Target
    , target : String
    , code : Dict String String
    , enabled : Set String
    , imports : String
    , definitions : String
    , loading : Bool
    , building : Bool
    , contextRequest : Int
    , request : Int
    , url : String
    , error : String
    , unavailable : String
    , dirty : Bool
    , events : List String
    }


type alias Model =
    { pages : Dict String Page, serial : Int }


init : Model
init =
    { pages = Dict.empty, serial = 0 }


empty : Page
empty =
    { targets = [], target = "", code = Dict.empty, enabled = Set.empty, imports = "", definitions = "", loading = False, building = False, contextRequest = 0, request = 0, url = "", error = "", unavailable = "", dirty = False, events = [] }


type Msg
    = Load String
    | TargetChanged String String
    | Edit String String String
    | Enable String String Bool
    | Trace String String String
    | Imports String String
    | Definitions String String
    | Apply String
    | Reset String
    | ClearOption String String
    | ClearEvents String
    | ControlsChanged String
    | Received Decode.Value


componentOf : Msg -> String
componentOf msg =
    case msg of
        Load component ->
            component

        TargetChanged component _ ->
            component

        Edit component _ _ ->
            component

        Enable component _ _ ->
            component

        Trace component _ _ ->
            component

        Imports component _ ->
            component

        Definitions component _ ->
            component

        Apply component ->
            component

        Reset component ->
            component

        ClearOption component _ ->
            component

        ClearEvents component ->
            component

        ControlsChanged component ->
            component

        Received value ->
            field "component" Decode.string "" value


pageOf : String -> Model -> Page
pageOf component model =
    Dict.get component model.pages |> Maybe.withDefault empty


isEnabled : String -> String -> Model -> Bool
isEnabled component name model =
    Set.member name (pageOf component model).enabled


hasChanges : String -> Model -> Bool
hasChanges component model =
    let
        page =
            pageOf component model
    in
    not (Set.isEmpty page.enabled) || not (Dict.isEmpty page.code) || page.imports /= "" || page.definitions /= "" || page.url /= ""


load : String -> Model -> ( Model, Cmd Msg )
load component model =
    if component == "" then
        ( model, Cmd.none )

    else
        ( update (Load component) model, command (Load component) Dict.empty model )


command : Msg -> Dict String String -> Model -> Cmd Msg
command msg values model =
    let
        component =
            componentOf msg

        page =
            pageOf component model

        request action extra =
            Compiler.request
                (Encode.object
                    ([ ( "action", Encode.string action ), ( "component", Encode.string component ), ( "id", Encode.int (model.serial + 1) ) ] ++ extra)
                )
    in
    case msg of
        Load _ ->
            if page.loading || not (List.isEmpty page.targets) then
                Cmd.none

            else
                request "describe" []

        Apply _ ->
            if Set.isEmpty page.enabled || page.target == "" || page.building then
                Cmd.none

            else
                request "compile"
                    [ ( "target", Encode.string page.target )
                    , ( "expressions", Encode.dict identity Encode.string (expressions page) )
                    , ( "values", Encode.dict identity Encode.string (Dict.filter (\key _ -> not (Set.member key page.enabled)) values) )
                    , ( "imports", Encode.string page.imports )
                    , ( "definitions", Encode.string page.definitions )
                    , ( "slug", Encode.string (slug component) )
                    ]

        _ ->
            Cmd.none


slug : String -> String
slug name =
    name
        |> String.toList
        |> List.indexedMap
            (\index char ->
                if char == '.' then
                    "-"

                else if Char.isUpper char && index > 0 && String.slice (index - 1) index name /= "." then
                    "-" ++ String.fromChar (Char.toLower char)

                else
                    String.fromChar (Char.toLower char)
            )
        |> String.concat


expressions : Page -> Dict String String
expressions page =
    page.enabled |> Set.toList |> List.map (\name -> ( name, codeFor name page )) |> Dict.fromList


codeFor : String -> Page -> String
codeFor name page =
    Dict.get name page.code |> Maybe.withDefault (sourceOption name page).sample


sourceOption : String -> Page -> SourceOption
sourceOption name page =
    page.targets |> List.filter (.id >> (==) page.target) |> List.head |> Maybe.map (\target -> target.options ++ List.map (\argument -> { name = argument.key, sample = argument.sample, trace = "" }) target.arguments) |> Maybe.withDefault [] |> List.filter (.name >> (==) name) |> List.head |> Maybe.withDefault { name = name, sample = "", trace = "" }


update : Msg -> Model -> Model
update msg model =
    let
        component =
            componentOf msg

        page =
            pageOf component model

        save next =
            { model | pages = Dict.insert component next model.pages }

        dirty next =
            invalidate { next | dirty = True }

        invalidate next =
            { model | pages = Dict.insert component { next | request = model.serial + 1, building = False } model.pages, serial = model.serial + 1 }
    in
    case msg of
        Load _ ->
            if page.loading || not (List.isEmpty page.targets) then
                model

            else
                { model | pages = Dict.insert component { page | loading = True, unavailable = "", contextRequest = model.serial + 1 } model.pages, serial = model.serial + 1 }

        TargetChanged _ target ->
            invalidate { page | target = target, dirty = True, error = "" }

        Edit _ name code ->
            dirty { page | code = Dict.insert name code page.code, enabled = Set.insert name page.enabled }

        Enable _ name enabled ->
            let
                enabledOptions =
                    if enabled then
                        Set.insert name page.enabled

                    else
                        Set.remove name page.enabled
            in
            invalidate
                { page
                    | enabled = enabledOptions
                    , dirty = True
                    , url =
                        if Set.isEmpty enabledOptions then
                            ""

                        else
                            page.url
                }

        Trace _ name code ->
            dirty { page | code = Dict.insert name code page.code, enabled = Set.insert name page.enabled }

        Imports _ code ->
            dirty { page | imports = code }

        Definitions _ code ->
            dirty { page | definitions = code }

        Apply _ ->
            if Set.isEmpty page.enabled || page.target == "" || page.building then
                model

            else
                { model | pages = Dict.insert component { page | building = True, request = model.serial + 1, error = "" } model.pages, serial = model.serial + 1 }

        Reset _ ->
            invalidate { page | code = Dict.empty, enabled = Set.empty, imports = "", definitions = "", url = "", error = "", dirty = False, events = [] }

        ClearOption _ name ->
            let
                enabledOptions =
                    Set.remove name page.enabled
            in
            invalidate
                { page
                    | code = Dict.remove name page.code
                    , enabled = enabledOptions
                    , dirty = True
                    , url =
                        if Set.isEmpty enabledOptions then
                            ""

                        else
                            page.url
                }

        ClearEvents _ ->
            save { page | events = [] }

        ControlsChanged _ ->
            dirty page

        Received value ->
            let
                action =
                    field "action" Decode.string "" value

                id =
                    field "id" Decode.int -1 value
            in
            if action == "described" && id == page.contextRequest then
                let
                    targets =
                        field "targets" (Decode.list targetDecoder) [] value
                in
                save
                    { page
                        | targets = targets
                        , target =
                            if page.target == "" then
                                targets |> List.head |> Maybe.map .id |> Maybe.withDefault ""

                            else
                                page.target
                        , loading = False
                    }

            else if action == "compiled" && id == page.request then
                if field "ok" Decode.bool False value then
                    save { page | building = False, url = field "url" Decode.string "" value, error = "", dirty = False, events = [] }

                else
                    save { page | building = False, error = field "diagnostics" Decode.string "Compilation failed." value }

            else if action == "callback" && id == page.request && not (String.isEmpty page.url) then
                save { page | events = List.take 100 (field "payload" Decode.string "" value :: page.events) }

            else if action == "compiler-error" && id == page.contextRequest then
                save { page | loading = False, unavailable = field "diagnostics" Decode.string "Compiler unavailable." value }

            else if action == "compiler-error" && id == page.request then
                save { page | building = False, error = field "diagnostics" Decode.string "Compiler unavailable." value }

            else
                model


field : String -> Decode.Decoder a -> a -> Decode.Value -> a
field name decoder fallback value =
    Decode.decodeValue (Decode.field name decoder) value |> Result.withDefault fallback


targetDecoder : Decode.Decoder Target
targetDecoder =
    Decode.map7 Target
        (Decode.field "id" Decode.string)
        (Decode.field "label" Decode.string)
        (Decode.field "alias" Decode.string)
        (Decode.field "imports" (Decode.list Decode.string))
        (Decode.field "constructors" (Decode.list Decode.string))
        (Decode.field "options" (Decode.list (Decode.map3 SourceOption (Decode.field "name" Decode.string) (Decode.field "sample" Decode.string) (Decode.field "trace" Decode.string))))
        (Decode.oneOf [ Decode.field "arguments" (Decode.list (Decode.map4 ViewArgument (Decode.field "key" Decode.string) (Decode.field "name" Decode.string) (Decode.field "type" Decode.string) (Decode.field "sample" Decode.string))), Decode.succeed [] ])


subscriptions : Sub Msg
subscriptions =
    Compiler.responses Received


preview : String -> Bool -> Model -> Html msg -> Html msg
preview component baseline model original =
    let
        page =
            pageOf component model
    in
    if baseline || String.isEmpty page.url then
        original

    else
        Html.div [ Attr.class "playground-compiled" ]
            [ if page.dirty then
                Html.p [ Attr.class "playground-pending", Attr.attribute "role" "status" ] [ Html.text "Showing the last compiled configuration. Apply your changes to update this preview." ]

              else
                Html.text ""
            , Html.iframe [ Attr.class "playground-compiled-preview", Attr.src page.url, Attr.title ("Custom " ++ component ++ " preview"), Attr.attribute "data-component" component, Attr.attribute "data-request" (String.fromInt page.request), Attr.attribute "sandbox" "allow-scripts allow-same-origin" ] []
            ]


toolbar : (Msg -> msg) -> String -> Model -> Html msg
toolbar toMsg component model =
    let
        page =
            pageOf component model
    in
    Html.div [ Attr.class "playground-advanced" ]
        [ Html.h3 [] [ Html.text "Custom Elm" ]
        , Html.p [ Attr.class "playground-help" ] [ Html.text "Write any public attribute expression below. The local Elm compiler checks callbacks, records, lists and render functions in the selected example's scope." ]
        , if page.loading then
            Html.p [] [ Html.text "Loading expression context…" ]

          else
            Html.text ""
        , if page.unavailable /= "" then
            Html.div [ Attr.attribute "role" "status", Attr.class "playground-pending" ] [ Html.text page.unavailable, Html.button [ Attr.type_ "button", Events.onClick (toMsg (Load component)) ] [ Html.text "Retry compiler" ] ]

          else
            Html.text ""
        , Html.label [ Attr.for "playground-target" ] [ Html.text "Target example" ]
        , Html.select [ Attr.id "playground-target", Events.onInput (TargetChanged component >> toMsg), Attr.disabled (List.isEmpty page.targets || page.building) ]
            (List.map (\target -> Html.option [ Attr.value target.id, Attr.selected (page.target == target.id) ] [ Html.text target.label ]) page.targets)
        , Html.details [ Attr.class "playground-context" ]
            [ Html.summary [] [ Html.text "Scope, imports and helper definitions" ]
            , Html.p [] [ Html.text "Expressions use the same aliases, model, local values and messages as this example. Extra definitions can provide your own typed fixtures and functions." ]
            , Html.pre [] [ Html.code [] [ Html.text (page.targets |> List.filter (.id >> (==) page.target) |> List.head |> Maybe.map (\target -> String.join "\n" target.imports ++ "\n\nMessages: " ++ String.join ", " target.constructors) |> Maybe.withDefault "") ] ]
            , Html.label [ Attr.for "playground-imports" ] [ Html.text "Additional imports" ]
            , Html.textarea [ Attr.id "playground-imports", Attr.rows 3, Attr.value page.imports, Events.onInput (Imports component >> toMsg), Attr.spellcheck False ] []
            , Html.label [ Attr.for "playground-definitions" ] [ Html.text "Helper definitions and typed data" ]
            , Html.textarea [ Attr.id "playground-definitions", Attr.rows 7, Attr.value page.definitions, Events.onInput (Definitions component >> toMsg), Attr.spellcheck False ] []
            ]
        , viewArguments toMsg component page
        , Html.button [ Attr.class "playground-apply", Attr.type_ "button", Attr.disabled (Set.isEmpty page.enabled || page.target == "" || page.building), Events.onClick (toMsg (Apply component)) ]
            [ Html.text
                (if page.building then
                    "Compiling…"

                 else
                    "Apply Elm expressions"
                )
            ]
        , Html.p [ Attr.class "playground-help", Attr.attribute "role" "status" ]
            [ Html.text
                (String.fromInt (Set.size page.enabled)
                    ++ " custom expressions"
                    ++ (if page.dirty && not (Set.isEmpty page.enabled) then
                            " · unapplied changes"

                        else
                            ""
                       )
                )
            ]
        , if page.error == "" then
            Html.text ""

          else
            Html.div [ Attr.class "playground-diagnostics", Attr.attribute "role" "alert" ] [ Html.strong [] [ Html.text "Elm could not compile this configuration" ], Html.pre [] [ Html.text page.error ] ]
        , if String.isEmpty page.url && List.isEmpty page.events then
            Html.text ""

          else
            Html.details [ Attr.class "playground-events", Attr.attribute "open" "" ]
                [ Html.summary [] [ Html.text "Callback events" ]
                , Html.button [ Attr.type_ "button", Events.onClick (toMsg (ClearEvents component)) ] [ Html.text "Clear events" ]
                , if List.isEmpty page.events then
                    Html.p [] [ Html.text "Use Trace callback on an option, apply, and interact with the preview." ]

                  else
                    Html.ol [] (List.map (\event -> Html.li [] [ Html.code [] [ Html.text event ] ]) page.events)
                ]
        ]


viewArguments : (Msg -> msg) -> String -> Page -> Html msg
viewArguments toMsg component page =
    let
        arguments =
            page.targets |> List.filter (.id >> (==) page.target) |> List.head |> Maybe.map .arguments |> Maybe.withDefault []

        argumentControl argument =
            let
                id =
                    "view-expression-" ++ component ++ argument.key

                enabled =
                    Set.member argument.key page.enabled
            in
            Html.div [ Attr.class "playground-expression" ]
                [ Html.label [ Attr.class "playground-enable" ]
                    [ Html.input [ Attr.type_ "checkbox", Attr.checked enabled, Events.onCheck (Enable component argument.key >> toMsg) ] []
                    , Html.text ("Use custom " ++ String.toLower argument.name)
                    ]
                , Html.label [ Attr.for id ] [ Html.text (argument.name ++ " Elm expression") ]
                , Html.code [] [ Html.text argument.type_ ]
                , Html.textarea [ Attr.id id, Attr.rows 6, Attr.value (codeFor argument.key page), Attr.spellcheck False, Events.onInput (Edit component argument.key >> toMsg) ] []
                , Html.button [ Attr.type_ "button", Events.onClick (toMsg (ClearOption component argument.key)), Attr.disabled (not enabled && not (Dict.member argument.key page.code)) ] [ Html.text ("Reset " ++ String.toLower argument.name) ]
                ]
    in
    if List.isEmpty arguments then
        Html.text ""

    else
        Html.details [ Attr.class "playground-view-arguments" ]
            (Html.summary [] [ Html.text "View data, state and event mapping" ]
                :: Html.p [ Attr.class "playground-help" ] [ Html.text "Edit the arguments passed to the view itself, including data records, component state and internal event mapping." ]
                :: List.map argumentControl arguments
            )


editor : (Msg -> msg) -> String -> Option -> Model -> Html msg
editor toMsg component option model =
    let
        page =
            pageOf component model

        enabled =
            Set.member option.name page.enabled

        source =
            sourceOption option.name page

        id =
            "elm-expression-" ++ component ++ "-" ++ option.name

        virtual =
            option.name == "content" && List.member component [ "Button", "Badge", "Tag", "Alert" ]
    in
    if virtual then
        Html.text ""

    else
        Html.details
            ([ Attr.class "playground-expression", Attr.attribute "data-option" option.name ]
                ++ (if enabled || option.control == Config.Example then
                        [ Attr.attribute "open" "" ]

                    else
                        []
                   )
            )
            [ Html.summary []
                [ Html.text
                    (if enabled then
                        "Elm expression · enabled"

                     else
                        "Elm expression"
                    )
                ]
            , Html.label [ Attr.class "playground-enable" ]
                [ Html.input [ Attr.type_ "checkbox", Attr.checked enabled, Events.onCheck (Enable component option.name >> toMsg) ] []
                , Html.text ("Use custom " ++ option.name)
                ]
            , Html.label [ Attr.for id ] [ Html.text (option.name ++ " Elm expression") ]
            , Html.textarea [ Attr.id id, Attr.rows 5, Attr.value (codeFor option.name page), Attr.placeholder (component ++ "." ++ option.name ++ " …"), Attr.spellcheck False, Events.onInput (Edit component option.name >> toMsg) ] []
            , if source.trace == "" then
                Html.text ""

              else
                Html.button [ Attr.type_ "button", Events.onClick (toMsg (Trace component option.name source.trace)) ] [ Html.text "Trace callback" ]
            , Html.p [ Attr.class "playground-help" ] [ Html.text "Enter the complete attribute, including its module and arguments. Invalid expressions keep the last successful preview." ]
            ]
