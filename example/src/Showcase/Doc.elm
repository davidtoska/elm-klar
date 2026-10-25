module Showcase.Doc exposing
    ( configuredExample
    , configuredPage
    , configuredSection
    , example
    , page
    , props
    , section
    , swatch
    )

{-| Building blocks for the documentation pages of the component gallery: a page
header, titled sections, and "examples" - a live component on a stage with an
optional code snippet that opens underneath.

    Doc.page { title = "Buttons", description = "..." }
        [ Doc.section "Variants"
            "Four looks, one for each role."
            [ Doc.example
                { title = "Primary", description = Nothing, code = Just "Button.view [ Button.primary ] \"Save\"" }
                (Button.view [ Button.primary ] "Save")
            ]
        ]

The styles are in `showcase.css`; they use the design tokens of the library.

-}

import Html exposing (Html)
import Html.Attributes as Attr
import Showcase.Config as Config exposing (Config)


configuredExample : Config -> List String -> { title : String, description : Maybe String, code : Maybe String } -> Html msg -> Html msg
configuredExample config components options content =
    Config.only config components (example options content)


configuredPage : Config -> { title : String, description : String } -> List (Html msg) -> Html msg
configuredPage config options sections =
    if config.component == "" then
        page options sections

    else
        Html.div [ Attr.class "showcase-doc" ] sections


configuredSection : Config -> List String -> String -> String -> List (Html msg) -> Html msg
configuredSection config components title description children =
    if Config.include config components then
        section title description children

    else
        Html.text ""


{-| A documentation page: title, short description, then sections.
-}
page : { title : String, description : String } -> List (Html msg) -> Html msg
page options sections =
    Html.article [ Attr.class "showcase-doc" ]
        (Html.header [ Attr.class "showcase-doc__header" ]
            [ Html.h1 [ Attr.class "showcase-doc__title" ] [ Html.text options.title ]
            , Html.p [ Attr.class "showcase-doc__description" ] [ Html.text options.description ]
            ]
            :: sections
        )


{-| A titled group of examples.
-}
section : String -> String -> List (Html msg) -> Html msg
section title description children =
    Html.section [ Attr.class "showcase-doc__section" ]
        [ Html.div [ Attr.class "showcase-doc__section-head" ]
            [ Html.h2 [ Attr.class "showcase-doc__section-title" ] [ Html.text title ]
            , if description == "" then
                Html.text ""

              else
                Html.p [ Attr.class "showcase-doc__section-description" ] [ Html.text description ]
            ]
        , Html.div [ Attr.class "showcase-doc__examples" ] children
        ]


{-| A live example on a stage, with an optional code snippet that can be opened
underneath.
-}
example : { title : String, description : Maybe String, code : Maybe String } -> Html msg -> Html msg
example options content =
    Html.div [ Attr.class "showcase-doc__example" ]
        [ Html.div [ Attr.class "showcase-doc__example-head" ]
            ([ Html.h3 [ Attr.class "showcase-doc__example-title" ] [ Html.text options.title ] ]
                ++ (case options.description of
                        Just text ->
                            [ Html.p [ Attr.class "showcase-doc__example-description" ] [ Html.text text ] ]

                        Nothing ->
                            []
                   )
            )
        , Html.div [ Attr.class "showcase-doc__stage" ] [ content ]
        , case options.code of
            Just code ->
                Html.details [ Attr.class "showcase-doc__code" ]
                    [ Html.summary [] [ Html.text "Show code" ]
                    , Html.pre [] [ Html.code [] [ Html.text code ] ]
                    ]

            Nothing ->
                Html.text ""
        ]


{-| A table of the options a component accepts: name, type, description.
-}
props : List { name : String, type_ : String, description : String } -> Html msg
props rows =
    Html.table [ Attr.class "showcase-doc__props" ]
        [ Html.thead []
            [ Html.tr []
                [ Html.th [] [ Html.text "Name" ]
                , Html.th [] [ Html.text "Type" ]
                , Html.th [] [ Html.text "Description" ]
                ]
            ]
        , Html.tbody []
            (List.map
                (\row ->
                    Html.tr []
                        [ Html.td [] [ Html.code [] [ Html.text row.name ] ]
                        , Html.td [] [ Html.code [] [ Html.text row.type_ ] ]
                        , Html.td [] [ Html.text row.description ]
                        ]
                )
                rows
            )
        ]


{-| A color swatch with its token name and value. `textOnColor` says the color is
strong enough for white text, so the "Aa" sample on it is white; on a light color
it is the normal text color.
-}
swatch : { token : String, value : String, textOnColor : Bool } -> Html msg
swatch options =
    Html.div [ Attr.class "showcase-doc__swatch" ]
        [ Html.div
            [ Attr.class "showcase-doc__swatch-color"
            , Attr.style "background" ("var(" ++ options.token ++ ")")
            , Attr.style "color"
                (if options.textOnColor then
                    "var(--klar-on-solid)"

                 else
                    "var(--klar-text)"
                )
            ]
            [ Html.text "Aa" ]
        , Html.div [ Attr.class "showcase-doc__swatch-token" ] [ Html.text options.token ]
        , Html.div [ Attr.class "showcase-doc__swatch-value" ] [ Html.text options.value ]
        ]
