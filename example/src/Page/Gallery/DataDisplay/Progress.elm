module Page.Gallery.DataDisplay.Progress exposing (Model, Msg, init, update, view)

{-| The progress section: bars, steps and rings.
-}

import Html exposing (Html)
import Klar.Button as Button
import Klar.Layout as Layout
import Klar.Locale exposing (Locale)
import Klar.Progress as Progress
import Klar.Theme exposing (Size(..), Tone(..))
import Showcase.Config as Config
import Showcase.Doc as Doc
import Showcase.Options as Options


type alias Model =
    { value : Float
    }


type Msg
    = SetValue Float


init : Model
init =
    { value = 62 }


update : Msg -> Model -> Model
update msg model =
    case msg of
        SetValue value ->
            { model | value = clamp 0 100 value }


view : Config.Config -> Locale -> Model -> Html Msg
view playground locale model =
    let
        bar attributes =
            Progress.view (Progress.locale locale :: attributes)

        ring attributes =
            Progress.ring (Progress.locale locale :: attributes)
    in
    Doc.configuredSection playground
        [ "Progress" ]
        "Progress"
        "Bars, steps and rings. All of them are role=progressbar with aria-valuenow (left out when the length is unknown) and a text for screen readers. The track is a lighter step of the color of the bar."
        [ Doc.configuredExample playground
            [ "Progress" ]
            { title = "Bar"
            , description = Just "The value is a percentage. outOf 3 5 sets the value and the text to “3 of 5”."
            , code = Nothing
            }
            (Layout.stack (Options.klarLayout playground (List.concat [ Config.keep playground "Layout" "gap" (Layout.gap 5) ]))
                [ Layout.stack (Options.klarLayout playground (List.concat [ Config.keep playground "Layout" "gap" (Layout.gap 2) ]))
                    [ bar (Options.klarProgress playground (List.concat [ Config.keep playground "Progress" "label" (Progress.label "Order import"), Config.keep playground "Progress" "value" (Progress.value model.value), Config.keep playground "Progress" "showValue" Progress.showValue ]))
                    , Layout.row (Options.klarLayout playground (List.concat [ Config.keep playground "Layout" "gap" (Layout.gap 2) ]))
                        [ Options.buttonView playground (Options.klarButton playground (List.concat [ Config.keep playground "Button" "small" Button.small, Config.keep playground "Button" "onClick" (Button.onClick (SetValue (model.value - 10))) ])) "-10%"
                        , Options.buttonView playground (Options.klarButton playground (List.concat [ Config.keep playground "Button" "small" Button.small, Config.keep playground "Button" "onClick" (Button.onClick (SetValue (model.value + 10))) ])) "+10%"
                        ]
                    ]
                , bar (Options.klarProgress playground (List.concat [ Config.keep playground "Progress" "label" (Progress.label "Importing orders"), Config.keep playground "Progress" "indeterminate" Progress.indeterminate ]))
                , bar (Options.klarProgress playground (List.concat [ Config.keep playground "Progress" "label" (Progress.label "Checkout"), Config.keep playground "Progress" "outOf" (Progress.outOf 3 5), Config.keep playground "Progress" "segments" (Progress.segments 5), Config.keep playground "Progress" "showValue" Progress.showValue ]))
                , bar (Options.klarProgress playground (List.concat [ Config.keep playground "Progress" "label" (Progress.label "Striped"), Config.keep playground "Progress" "value" (Progress.value 45), Config.keep playground "Progress" "striped" Progress.striped, Config.keep playground "Progress" "tone" (Progress.tone Success), Config.keep playground "Progress" "showValue" Progress.showValue ]))
                ]
            )
        , Doc.configuredExample playground
            [ "Progress" ]
            { title = "Tones and thicknesses"
            , description = Nothing
            , code = Just "Progress.view [ Progress.tone Warning, Progress.size Large, Progress.value 80 ]"
            }
            (Layout.grid (Options.klarLayout playground (List.concat [ Config.keep playground "Layout" "minColumn" (Layout.minColumn 260), Config.keep playground "Layout" "gap" (Layout.gap 5) ]))
                [ bar (Options.klarProgress playground (List.concat [ Config.keep playground "Progress" "label" (Progress.label "Primary, thin"), Config.keep playground "Progress" "value" (Progress.value 30), Config.keep playground "Progress" "size" (Progress.size Small), Config.keep playground "Progress" "showValue" Progress.showValue ]))
                , bar (Options.klarProgress playground (List.concat [ Config.keep playground "Progress" "label" (Progress.label "Neutral"), Config.keep playground "Progress" "value" (Progress.value 55), Config.keep playground "Progress" "tone" (Progress.tone Neutral), Config.keep playground "Progress" "showValue" Progress.showValue ]))
                , bar (Options.klarProgress playground (List.concat [ Config.keep playground "Progress" "label" (Progress.label "Success"), Config.keep playground "Progress" "value" (Progress.value 100), Config.keep playground "Progress" "tone" (Progress.tone Success), Config.keep playground "Progress" "showValue" Progress.showValue ]))
                , bar (Options.klarProgress playground (List.concat [ Config.keep playground "Progress" "label" (Progress.label "Warning, thick"), Config.keep playground "Progress" "value" (Progress.value 80), Config.keep playground "Progress" "tone" (Progress.tone Warning), Config.keep playground "Progress" "size" (Progress.size Large), Config.keep playground "Progress" "showValue" Progress.showValue ]))
                , bar (Options.klarProgress playground (List.concat [ Config.keep playground "Progress" "label" (Progress.label "Danger"), Config.keep playground "Progress" "value" (Progress.value 96), Config.keep playground "Progress" "tone" (Progress.tone Danger), Config.keep playground "Progress" "showValue" Progress.showValue ]))
                , bar (Options.klarProgress playground (List.concat [ Config.keep playground "Progress" "label" (Progress.label "Own text"), Config.keep playground "Progress" "value" (Progress.value 30), Config.keep playground "Progress" "valueText" (Progress.valueText "12 of 40 hours") ]))
                , bar (Options.klarProgress playground (List.concat [ Config.keep playground "Progress" "label" (Progress.label "Outside 0-100 is clipped"), Config.keep playground "Progress" "value" (Progress.value 140), Config.keep playground "Progress" "showValue" Progress.showValue ]))
                , bar (Options.klarProgress playground (List.concat [ Config.keep playground "Progress" "ariaLabel" (Progress.ariaLabel "Without a visible label"), Config.keep playground "Progress" "value" (Progress.value 70) ]))
                ]
            )
        , Doc.configuredExample playground
            [ "Progress" ]
            { title = "Ring"
            , description = Just "The text in the middle is the value, and a short label when there is room for it."
            , code = Nothing
            }
            (Layout.row (Options.klarLayout playground (List.concat [ Config.keep playground "Layout" "gap" (Layout.gap 6), Config.keep playground "Layout" "alignCenter" Layout.alignCenter, Config.keep playground "Layout" "wrap" Layout.wrap ]))
                [ ring (Options.klarProgress playground (List.concat [ Config.keep playground "Progress" "value" (Progress.value model.value), Config.keep playground "Progress" "size" (Progress.size Small) ]))
                , ring (Options.klarProgress playground (List.concat [ Config.keep playground "Progress" "value" (Progress.value model.value), Config.keep playground "Progress" "label" (Progress.label "Import") ]))
                , ring (Options.klarProgress playground (List.concat [ Config.keep playground "Progress" "value" (Progress.value 80), Config.keep playground "Progress" "tone" (Progress.tone Success), Config.keep playground "Progress" "label" (Progress.label "Done") ]))
                , ring (Options.klarProgress playground (List.concat [ Config.keep playground "Progress" "value" (Progress.value 35), Config.keep playground "Progress" "tone" (Progress.tone Warning), Config.keep playground "Progress" "size" (Progress.size Large), Config.keep playground "Progress" "label" (Progress.label "Capacity") ]))
                , ring (Options.klarProgress playground (List.concat [ Config.keep playground "Progress" "value" (Progress.value 96), Config.keep playground "Progress" "tone" (Progress.tone Danger), Config.keep playground "Progress" "size" (Progress.size Large), Config.keep playground "Progress" "label" (Progress.label "Filled") ]))
                , ring (Options.klarProgress playground (List.concat [ Config.keep playground "Progress" "indeterminate" Progress.indeterminate, Config.keep playground "Progress" "ariaLabel" (Progress.ariaLabel "Loading") ]))
                , ring (Options.klarProgress playground (List.concat [ Config.keep playground "Progress" "indeterminate" Progress.indeterminate, Config.keep playground "Progress" "size" (Progress.size Large), Config.keep playground "Progress" "ariaLabel" (Progress.ariaLabel "Loading") ]))
                ]
            )
        ]
